# Roteiro — Davi Mendes (Desenvolvedor Back-end)

**Objetivo:** criar as regras de negócio como endpoints RPC e a Edge Function de eventos de equipamentos.
**Prazo:** quarta 12/11, PR aberto até 18h.
**Branch:** `feat/cp2-davi`
**Depende de:** Lucas publicar a URL e a anon key (parte 1 do roteiro dele). Até lá, você pode escrever e revisar o SQL.

## Conceitos em 2 minutos

- Uma função SQL criada no schema `safetech` vira automaticamente o endpoint `POST /rest/v1/rpc/<nome>`.
  O corpo JSON usa os nomes dos parâmetros (`{"p_praca_id": "...", "p_titulo": "..."}`).
- `SECURITY DEFINER` faz a função rodar com permissão do dono (ignora RLS), por isso **cada função valida
  quem está chamando** com `auth.uid()` (id do usuário logado, `NULL` se anônimo) e `eh_equipe()`.
- `set_config('safetech.usuario_id', ...)` avisa a trigger de histórico quem fez a mudança.
- Edge Function = código TypeScript (Deno) hospedado no Supabase, com acesso à `service_role key` para
  gravar no banco sem RLS. Usamos para receber eventos de câmeras/sensores (simulados).

## Passo 1 — Criar as funções RPC

Crie `database/supabase/08_supabase_rpc.sql` com o conteúdo abaixo. Leia cada função antes de rodar: você vai
explicá-las no checkpoint. Execute no **SQL Editor** do projeto (depois que o Lucas aplicar 06 e 07).

```sql
-- =============================================================================
-- 08_rpc.sql : funções de negócio expostas como RPC (POST /rest/v1/rpc/<nome>)
-- Todas rodam como SECURITY DEFINER e validam o usuário com auth.uid()/perfil.
-- =============================================================================
SET search_path TO safetech, public;

-- -----------------------------------------------------------------------------
-- registrar_ocorrencia : cidadão ou agente registra uma ocorrência
-- Retorna id e protocolo gerado.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION safetech.registrar_ocorrencia(
    p_praca_id      UUID,
    p_categoria_id  INTEGER,
    p_titulo        TEXT,
    p_descricao     TEXT,
    p_gravidade     nivel_gravidade DEFAULT NULL,
    p_anonima       BOOLEAN DEFAULT FALSE,
    p_latitude      NUMERIC DEFAULT NULL,
    p_longitude     NUMERIC DEFAULT NULL,
    p_ocorrida_em   TIMESTAMPTZ DEFAULT NOW()
)
RETURNS TABLE (id UUID, protocolo VARCHAR, status status_ocorrencia)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = safetech, public
AS $$
DECLARE
    v_autor     UUID := auth.uid();
    v_gravidade nivel_gravidade;
BEGIN
    IF v_autor IS NULL AND NOT p_anonima THEN
        RAISE EXCEPTION 'É necessário estar autenticado para registrar uma ocorrência identificada'
            USING ERRCODE = '42501';
    END IF;

    SELECT COALESCE(p_gravidade, c.gravidade_padrao) INTO v_gravidade
      FROM categoria_ocorrencia c WHERE c.id = p_categoria_id AND c.ativa;
    IF v_gravidade IS NULL THEN
        RAISE EXCEPTION 'Categoria % inexistente ou inativa', p_categoria_id USING ERRCODE = '22023';
    END IF;

    PERFORM set_config('safetech.usuario_id', COALESCE(v_autor::text, ''), true);

    RETURN QUERY
    INSERT INTO ocorrencia (praca_id, categoria_id, autor_id, titulo, descricao, gravidade, anonima, latitude, longitude, ocorrida_em)
    VALUES (p_praca_id, p_categoria_id, v_autor, p_titulo, p_descricao, v_gravidade, p_anonima, p_latitude, p_longitude, p_ocorrida_em)
    RETURNING ocorrencia.id, ocorrencia.protocolo, ocorrencia.status;
END;
$$;

-- -----------------------------------------------------------------------------
-- consultar_protocolo : consulta pública do andamento pelo número do protocolo
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION safetech.consultar_protocolo(p_protocolo TEXT)
RETURNS JSONB
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = safetech, public
AS $$
    SELECT jsonb_build_object(
        'protocolo',   o.protocolo,
        'titulo',      o.titulo,
        'status',      o.status,
        'gravidade',   o.gravidade,
        'praca',       p.nome,
        'categoria',   c.nome,
        'ocorrida_em', o.ocorrida_em,
        'resolvida_em',o.resolvida_em,
        'historico',   COALESCE((
            SELECT jsonb_agg(jsonb_build_object(
                       'de', h.status_anterior, 'para', h.status_novo,
                       'observacao', h.observacao, 'em', h.alterado_em)
                   ORDER BY h.alterado_em)
              FROM historico_ocorrencia h WHERE h.ocorrencia_id = o.id), '[]'::jsonb)
    )
    FROM ocorrencia o
    JOIN praca p ON p.id = o.praca_id
    JOIN categoria_ocorrencia c ON c.id = o.categoria_id
    WHERE o.protocolo = upper(trim(p_protocolo));
$$;

-- -----------------------------------------------------------------------------
-- atualizar_status_ocorrencia : equipe muda o status (gera histórico com autor)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION safetech.atualizar_status_ocorrencia(
    p_ocorrencia_id UUID,
    p_status        status_ocorrencia,
    p_observacao    TEXT DEFAULT NULL
)
RETURNS SETOF ocorrencia
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = safetech, public
AS $$
BEGIN
    IF NOT eh_equipe() THEN
        RAISE EXCEPTION 'Apenas agentes, gestores ou administradores podem alterar o status' USING ERRCODE = '42501';
    END IF;

    PERFORM set_config('safetech.usuario_id', auth.uid()::text, true);

    UPDATE ocorrencia SET status = p_status WHERE id = p_ocorrencia_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Ocorrência % não encontrada', p_ocorrencia_id USING ERRCODE = 'P0002';
    END IF;

    IF p_observacao IS NOT NULL THEN
        UPDATE historico_ocorrencia h SET observacao = p_observacao
         WHERE h.id = (SELECT max(id) FROM historico_ocorrencia WHERE ocorrencia_id = p_ocorrencia_id);
    END IF;

    RETURN QUERY SELECT * FROM ocorrencia WHERE id = p_ocorrencia_id;
END;
$$;

-- -----------------------------------------------------------------------------
-- atribuir_atendimento : gestor/agente atribui a ocorrência a um agente
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION safetech.atribuir_atendimento(
    p_ocorrencia_id UUID,
    p_agente_id     UUID DEFAULT NULL   -- NULL = o próprio usuário logado assume
)
RETURNS SETOF atendimento
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = safetech, public
AS $$
DECLARE
    v_id UUID;
BEGIN
    IF NOT eh_equipe() THEN
        RAISE EXCEPTION 'Apenas a equipe pode atribuir atendimentos' USING ERRCODE = '42501';
    END IF;

    PERFORM set_config('safetech.usuario_id', auth.uid()::text, true);

    INSERT INTO atendimento (ocorrencia_id, agente_id, atribuido_por)
    VALUES (p_ocorrencia_id, COALESCE(p_agente_id, auth.uid()), auth.uid())
    RETURNING id INTO v_id;

    RETURN QUERY SELECT * FROM atendimento WHERE id = v_id;
END;
$$;

-- -----------------------------------------------------------------------------
-- finalizar_atendimento : agente encerra o atendimento com relato
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION safetech.finalizar_atendimento(
    p_atendimento_id UUID,
    p_relato         TEXT,
    p_resolver       BOOLEAN DEFAULT TRUE
)
RETURNS SETOF atendimento
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = safetech, public
AS $$
DECLARE
    v_ocorrencia UUID;
BEGIN
    IF NOT eh_equipe() THEN
        RAISE EXCEPTION 'Apenas a equipe pode finalizar atendimentos' USING ERRCODE = '42501';
    END IF;

    UPDATE atendimento
       SET finalizado_em = NOW(), relato = p_relato
     WHERE id = p_atendimento_id AND finalizado_em IS NULL
    RETURNING ocorrencia_id INTO v_ocorrencia;

    IF v_ocorrencia IS NULL THEN
        RAISE EXCEPTION 'Atendimento % não encontrado ou já finalizado', p_atendimento_id USING ERRCODE = 'P0002';
    END IF;

    IF p_resolver THEN
        PERFORM set_config('safetech.usuario_id', auth.uid()::text, true);
        UPDATE ocorrencia SET status = 'RESOLVIDA' WHERE id = v_ocorrencia;
    END IF;

    RETURN QUERY SELECT * FROM atendimento WHERE id = p_atendimento_id;
END;
$$;

-- -----------------------------------------------------------------------------
-- reconhecer_alerta : equipe reconhece / encerra / marca falso positivo
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION safetech.reconhecer_alerta(
    p_alerta_id UUID,
    p_status    status_alerta DEFAULT 'RECONHECIDO'
)
RETURNS SETOF alerta
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = safetech, public
AS $$
BEGIN
    IF NOT eh_equipe() THEN
        RAISE EXCEPTION 'Apenas a equipe pode tratar alertas' USING ERRCODE = '42501';
    END IF;
    IF p_status = 'NOVO' THEN
        RAISE EXCEPTION 'Status inválido para reconhecimento' USING ERRCODE = '22023';
    END IF;

    UPDATE alerta
       SET status          = p_status,
           reconhecido_por = COALESCE(reconhecido_por, auth.uid()),
           reconhecido_em  = COALESCE(reconhecido_em, NOW()),
           encerrado_em    = CASE WHEN p_status IN ('ENCERRADO', 'FALSO_POSITIVO') THEN NOW() ELSE encerrado_em END
     WHERE id = p_alerta_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Alerta % não encontrado', p_alerta_id USING ERRCODE = 'P0002';
    END IF;

    RETURN QUERY SELECT * FROM alerta WHERE id = p_alerta_id;
END;
$$;

-- -----------------------------------------------------------------------------
-- acionar_botao_panico : qualquer pessoa (até sem login) aciona o botão de um
-- equipamento; cria alerta CRITICO e notifica toda a equipe.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION safetech.acionar_botao_panico(
    p_equipamento_codigo TEXT,
    p_mensagem           TEXT DEFAULT NULL
)
RETURNS SETOF alerta
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = safetech, public
AS $$
DECLARE
    v_equip   equipamento%ROWTYPE;
    v_alerta  UUID;
BEGIN
    SELECT * INTO v_equip FROM equipamento
     WHERE codigo = p_equipamento_codigo AND tipo IN ('BOTAO_PANICO', 'TOTEM') AND status = 'OPERANTE';
    IF v_equip.id IS NULL THEN
        RAISE EXCEPTION 'Equipamento % não é um botão de pânico operante', p_equipamento_codigo USING ERRCODE = '22023';
    END IF;

    INSERT INTO alerta (praca_id, equipamento_id, origem, gravidade, mensagem)
    VALUES (v_equip.praca_id, v_equip.id, 'BOTAO_PANICO', 'CRITICA',
            COALESCE(p_mensagem, 'Botão de pânico acionado em ' || COALESCE(v_equip.localizacao, v_equip.codigo)))
    RETURNING id INTO v_alerta;

    INSERT INTO notificacao (usuario_id, alerta_id, titulo, mensagem)
    SELECT u.id, v_alerta, 'Botão de pânico acionado',
           (SELECT 'Praça ' || p.nome || ': ' || a.mensagem FROM alerta a JOIN praca p ON p.id = a.praca_id WHERE a.id = v_alerta)
      FROM usuario u WHERE u.perfil IN ('AGENTE', 'GESTOR') AND u.ativo;

    RETURN QUERY SELECT * FROM alerta WHERE id = v_alerta;
END;
$$;

-- -----------------------------------------------------------------------------
-- Permissões: quem pode chamar cada RPC
-- -----------------------------------------------------------------------------
GRANT EXECUTE ON FUNCTION safetech.consultar_protocolo(TEXT)              TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION safetech.acionar_botao_panico(TEXT, TEXT)       TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION safetech.registrar_ocorrencia(UUID, INTEGER, TEXT, TEXT, nivel_gravidade, BOOLEAN, NUMERIC, NUMERIC, TIMESTAMPTZ)
                                                                            TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION safetech.atualizar_status_ocorrencia(UUID, status_ocorrencia, TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION safetech.atribuir_atendimento(UUID, UUID)       TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION safetech.finalizar_atendimento(UUID, TEXT, BOOLEAN) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION safetech.reconhecer_alerta(UUID, status_alerta) TO authenticated, service_role;
```

## Passo 2 — Testar cada RPC

Pegue um token de usuário logado (o Lucas criou `gestor.demo@safetech.app` / `Senha@123`):

```bash
curl -s "$SUPABASE_URL/auth/v1/token?grant_type=password" \
  -H "apikey: $ANON" -H "Content-Type: application/json" \
  -d '{"email":"gestor.demo@safetech.app","password":"Senha@123"}'
# copie o campo access_token para a variável TOKEN
```

Chamadas (sempre com `Content-Profile: safetech`):

```bash
# público: consulta de protocolo
curl -s -X POST "$SUPABASE_URL/rest/v1/rpc/consultar_protocolo" \
  -H "apikey: $ANON" -H "Content-Profile: safetech" -H "Content-Type: application/json" \
  -d '{"p_protocolo":"STC-2026-000001"}'

# público: ocorrência anônima
curl -s -X POST "$SUPABASE_URL/rest/v1/rpc/registrar_ocorrencia" \
  -H "apikey: $ANON" -H "Content-Profile: safetech" -H "Content-Type: application/json" \
  -d '{"p_praca_id":"aaaaaaaa-0000-0000-0000-000000000001","p_categoria_id":3,"p_titulo":"Assalto","p_descricao":"Relato anônimo","p_anonima":true}'

# público: botão de pânico
curl -s -X POST "$SUPABASE_URL/rest/v1/rpc/acionar_botao_panico" \
  -H "apikey: $ANON" -H "Content-Profile: safetech" -H "Content-Type: application/json" \
  -d '{"p_equipamento_codigo":"BTN-DERBY-01"}'

# gestor: muda status (use o id retornado acima)
curl -s -X POST "$SUPABASE_URL/rest/v1/rpc/atualizar_status_ocorrencia" \
  -H "apikey: $ANON" -H "Authorization: Bearer $TOKEN" -H "Content-Profile: safetech" -H "Content-Type: application/json" \
  -d '{"p_ocorrencia_id":"<id>","p_status":"EM_ANALISE","p_observacao":"Triagem feita"}'

# gestor: atribui ao próprio usuário (p_agente_id omitido)
curl -s -X POST "$SUPABASE_URL/rest/v1/rpc/atribuir_atendimento" \
  -H "apikey: $ANON" -H "Authorization: Bearer $TOKEN" -H "Content-Profile: safetech" -H "Content-Type: application/json" \
  -d '{"p_ocorrencia_id":"<id>"}'

# gestor: reconhece alerta
curl -s -X POST "$SUPABASE_URL/rest/v1/rpc/reconhecer_alerta" \
  -H "apikey: $ANON" -H "Authorization: Bearer $TOKEN" -H "Content-Profile: safetech" -H "Content-Type: application/json" \
  -d '{"p_alerta_id":"<id do alerta>"}'
```

Checklist do que deve acontecer:

- [ ] Sem token, `atualizar_status_ocorrencia` retorna erro "Apenas agentes, gestores...".
- [ ] Com token de `cidadao.demo`, o mesmo erro.
- [ ] Com token de `gestor.demo`, status muda e aparece linha nova em `historico_ocorrencia` com `usuario_id` do gestor.
- [ ] `atribuir_atendimento` coloca a ocorrência em `EM_ATENDIMENTO`.
- [ ] `acionar_botao_panico` cria alerta `CRITICA` e uma notificação para cada AGENTE/GESTOR.
- [ ] `consultar_protocolo` funciona sem login e aceita minúsculas (`stc-2026-000001`).

Anote esses resultados: a Ana vai transformá-los na coleção `.http` oficial.

## Passo 3 — Edge Function `evento-equipamento`

Simula a integração com câmeras e sensores: um dispositivo envia um evento e a função cria o alerta,
atualiza o status do equipamento e notifica a equipe.

### 3.1 Instalar a CLI e vincular o projeto

```bash
npm install -g supabase          # ou use npx supabase ...
supabase login                   # abre o navegador
supabase init                    # cria a pasta supabase/ na raiz do repo (commite config.toml)
supabase link --project-ref SEU-REF
supabase functions new evento-equipamento
```

### 3.2 Código: `supabase/functions/evento-equipamento/index.ts`

```ts
import { createClient } from 'npm:@supabase/supabase-js@2';

type Evento = 'SEM_SINAL' | 'FALHA' | 'MOVIMENTO_SUSPEITO' | 'RUIDO_ALTO' | 'NORMALIZADO';

const REGRAS: Record<Evento, { gravidade: 'BAIXA' | 'MEDIA' | 'ALTA' | 'CRITICA' | null; statusEquip: string | null }> = {
  SEM_SINAL:          { gravidade: 'MEDIA', statusEquip: 'INOPERANTE' },
  FALHA:              { gravidade: 'ALTA',  statusEquip: 'INOPERANTE' },
  MOVIMENTO_SUSPEITO: { gravidade: 'ALTA',  statusEquip: null },
  RUIDO_ALTO:         { gravidade: 'MEDIA', statusEquip: null },
  NORMALIZADO:        { gravidade: null,    statusEquip: 'OPERANTE' },
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });

Deno.serve(async (req) => {
  if (req.method !== 'POST') return json({ erro: 'Use POST' }, 405);

  // Autenticação do dispositivo: segredo compartilhado no cabeçalho
  const segredo = req.headers.get('x-device-secret');
  if (!segredo || segredo !== Deno.env.get('DEVICE_SECRET')) return json({ erro: 'Não autorizado' }, 401);

  let corpo: { codigo?: string; evento?: Evento; mensagem?: string };
  try { corpo = await req.json(); } catch { return json({ erro: 'JSON inválido' }, 400); }

  const { codigo, evento, mensagem } = corpo;
  if (!codigo || !evento || !(evento in REGRAS)) {
    return json({ erro: 'Informe codigo e evento (SEM_SINAL, FALHA, MOVIMENTO_SUSPEITO, RUIDO_ALTO, NORMALIZADO)' }, 400);
  }

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,   // injetado automaticamente pelo Supabase
    { db: { schema: 'safetech' } },
  );

  const { data: equip, error: errEquip } = await supabase
    .from('equipamento').select('id, praca_id, codigo, tipo, localizacao').eq('codigo', codigo).single();
  if (errEquip || !equip) return json({ erro: `Equipamento ${codigo} não encontrado` }, 404);

  const regra = REGRAS[evento];

  if (regra.statusEquip) {
    await supabase.from('equipamento').update({ status: regra.statusEquip }).eq('id', equip.id);
  }

  if (!regra.gravidade) return json({ ok: true, alerta: null, equipamento: equip.codigo, status: regra.statusEquip });

  const texto = mensagem ?? `${evento.replace('_', ' ')} em ${equip.tipo} ${equip.codigo}${equip.localizacao ? ' (' + equip.localizacao + ')' : ''}`;

  const { data: alerta, error: errAlerta } = await supabase
    .from('alerta')
    .insert({ praca_id: equip.praca_id, equipamento_id: equip.id, origem: 'EQUIPAMENTO', gravidade: regra.gravidade, mensagem: texto })
    .select().single();
  if (errAlerta) return json({ erro: errAlerta.message }, 500);

  const { data: equipe } = await supabase.from('usuario').select('id').in('perfil', ['AGENTE', 'GESTOR']).eq('ativo', true);
  if (equipe?.length) {
    await supabase.from('notificacao').insert(
      equipe.map((u) => ({ usuario_id: u.id, alerta_id: alerta.id, titulo: 'Alerta de equipamento', mensagem: texto })),
    );
  }

  return json({ ok: true, alerta }, 201);
});
```

### 3.3 Segredo, deploy e teste

```bash
supabase secrets set DEVICE_SECRET=troque-por-um-segredo-forte
supabase functions deploy evento-equipamento --no-verify-jwt   # dispositivos não têm JWT; usam o segredo

curl -s -X POST "$SUPABASE_URL/functions/v1/evento-equipamento" \
  -H "x-device-secret: troque-por-um-segredo-forte" -H "Content-Type: application/json" \
  -d '{"codigo":"CAM-DERBY-01","evento":"SEM_SINAL"}'
```

Esperado: resposta `201` com o alerta; em `vw_alerta_pendente` aparece o alerta; `CAM-DERBY-01` fica `INOPERANTE`;
gestores recebem notificação. Depois mande `{"codigo":"CAM-DERBY-01","evento":"NORMALIZADO"}` e confira que
voltou a `OPERANTE`.

> Sem CLI: o painel do Supabase também permite criar a função em **Edge Functions → Deploy a new function →
> Via Editor**; cole o código, e em **Secrets** cadastre `DEVICE_SECRET`. Mesmo assim, commite o arquivo no repo.

## Passo 4 — Sua contribuição própria

Escolha **uma** função extra e implemente no mesmo padrão (valide permissão, use `set_config` se mexer em status):

- `safetech.minhas_ocorrencias()` → `RETURNS SETOF ocorrencia` com as ocorrências do usuário logado, mais recentes primeiro; ou
- `safetech.avaliar_praca(p_praca_id, p_nota, p_comentario)` → cria ou atualiza a avaliação do usuário logado na praça (um usuário, uma avaliação por praça).

## Passo 5 — Pull Request

Inclua: `database/supabase/08_supabase_rpc.sql`, `supabase/config.toml`, `supabase/functions/evento-equipamento/index.ts`,
e um `docs/checkpoint-2/evidencias/davi-rpc.md` com os comandos usados e as respostas (pode colar o JSON).
Peça revisão ao Lucas. No checkpoint, você apresenta os RPCs e a Edge Function.
