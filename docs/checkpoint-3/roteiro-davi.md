# Roteiro — Davi Mendes (Back-end) · Checkpoint 3

**Entrega:** 4 RPCs novas no banco (`database/supabase/09_rpc_cp3.sql`) e as duas telas da equipe no front:
**Painel de ocorrências** e **Alertas em tempo real**.

**Depende de:** nada para o SQL (faça primeiro, de manhã: Santhiago precisa de `detalhe_praca`, `avaliar_praca` e
`registrar_anexo` à tarde). Para as telas, espere o PR da base do Santhiago entrar em `main` (até 14h).

**Como está o código:** o SQL passou em 36 testes no PGlite (anônimo, cidadão, agente, gestor), e o TypeScript
compila, passa no lint e no build com o `package.json` atual.

## Passo 1 — RPCs do MVP (manhã de quarta)

```bash
git checkout main && git pull && git checkout -b feat/cp3-davi
```

Crie `database/supabase/09_rpc_cp3.sql` com o conteúdo abaixo e rode no **SQL Editor** do Supabase:

```sql
-- =============================================================================
-- 09_rpc_cp3.sql : funções de negócio do Checkpoint 3 (MVP)
-- Expostas como RPC em POST /rest/v1/rpc/<nome>. SECURITY DEFINER + validação por auth.uid()/perfil.
-- =============================================================================

SET search_path TO safetech, public;

-- -----------------------------------------------------------------------------
-- detalhe_praca : tudo que a tela "Detalhe da praça" precisa em uma chamada (pública).
-- Nunca expõe autor de ocorrência (anonimato) nem dados pessoais além do primeiro nome do avaliador.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION safetech.detalhe_praca(p_praca_id UUID)
RETURNS JSONB
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = safetech, public
AS $$
    SELECT jsonb_build_object(
        'praca', (SELECT to_jsonb(p) - 'criado_em' - 'atualizado_em' FROM praca p WHERE p.id = p_praca_id),
        'resumo', (SELECT to_jsonb(r) FROM vw_praca_resumo r WHERE r.id = p_praca_id),
        'equipamentos', COALESCE((
            SELECT jsonb_agg(jsonb_build_object(
                       'id', e.id, 'tipo', e.tipo, 'codigo', e.codigo, 'descricao', e.descricao,
                       'localizacao', e.localizacao, 'status', e.status) ORDER BY e.tipo, e.codigo)
              FROM equipamento e WHERE e.praca_id = p_praca_id), '[]'::jsonb),
        'ocorrencias_abertas', COALESCE((
            SELECT jsonb_agg(jsonb_build_object(
                       'protocolo', o.protocolo, 'titulo', o.titulo, 'categoria', c.nome,
                       'gravidade', o.gravidade, 'status', o.status, 'ocorrida_em', o.ocorrida_em) ORDER BY o.ocorrida_em DESC)
              FROM ocorrencia o JOIN categoria_ocorrencia c ON c.id = o.categoria_id
             WHERE o.praca_id = p_praca_id AND o.status IN ('ABERTA', 'EM_ANALISE', 'EM_ATENDIMENTO')), '[]'::jsonb),
        'avaliacoes', COALESCE((
            SELECT jsonb_agg(jsonb_build_object(
                       'nota', a.nota, 'comentario', a.comentario, 'criado_em', a.criado_em,
                       'autor', split_part(u.nome, ' ', 1),
                       'minha', a.usuario_id = auth.uid()) ORDER BY a.criado_em DESC)
              FROM (SELECT * FROM avaliacao_praca av WHERE av.praca_id = p_praca_id ORDER BY av.criado_em DESC LIMIT 10) a
              JOIN usuario u ON u.id = a.usuario_id), '[]'::jsonb)
    )
    WHERE EXISTS (SELECT 1 FROM praca WHERE id = p_praca_id);
$$;

-- -----------------------------------------------------------------------------
-- avaliar_praca : cidadão logado dá nota 1..5 à praça. Uma avaliação por usuário/praça:
-- se já existir, atualiza. Retorna a avaliação gravada.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION safetech.avaliar_praca(
    p_praca_id   UUID,
    p_nota       SMALLINT,
    p_comentario TEXT DEFAULT NULL
)
RETURNS SETOF avaliacao_praca
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = safetech, public
AS $$
DECLARE
    v_usuario UUID := auth.uid();
    v_id      UUID;
BEGIN
    IF v_usuario IS NULL THEN
        RAISE EXCEPTION 'É necessário estar autenticado para avaliar uma praça' USING ERRCODE = '42501';
    END IF;
    IF p_nota IS NULL OR p_nota NOT BETWEEN 1 AND 5 THEN
        RAISE EXCEPTION 'A nota deve ser um inteiro de 1 a 5' USING ERRCODE = '22023';
    END IF;

    SELECT id INTO v_id FROM avaliacao_praca WHERE praca_id = p_praca_id AND usuario_id = v_usuario;

    IF v_id IS NULL THEN
        INSERT INTO avaliacao_praca (praca_id, usuario_id, nota, comentario)
        VALUES (p_praca_id, v_usuario, p_nota, NULLIF(TRIM(p_comentario), ''))
        RETURNING id INTO v_id;
    ELSE
        UPDATE avaliacao_praca
           SET nota = p_nota, comentario = NULLIF(TRIM(p_comentario), ''), criado_em = NOW()
         WHERE id = v_id;
    END IF;

    RETURN QUERY SELECT * FROM avaliacao_praca WHERE id = v_id;
END;
$$;

-- -----------------------------------------------------------------------------
-- registrar_anexo : vincula um arquivo já enviado ao Storage (bucket anexos) a uma ocorrência.
-- Só o autor da ocorrência ou a equipe podem anexar.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION safetech.registrar_anexo(
    p_ocorrencia_id UUID,
    p_url           TEXT,
    p_nome_arquivo  TEXT DEFAULT NULL,
    p_tamanho_bytes BIGINT DEFAULT NULL,
    p_tipo          tipo_midia DEFAULT 'IMAGEM'
)
RETURNS SETOF anexo_ocorrencia
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = safetech, public
AS $$
DECLARE
    v_usuario UUID := auth.uid();
    v_autor   UUID;
    v_id      UUID;
BEGIN
    IF v_usuario IS NULL THEN
        RAISE EXCEPTION 'É necessário estar autenticado para anexar arquivos' USING ERRCODE = '42501';
    END IF;

    SELECT autor_id INTO v_autor FROM ocorrencia WHERE id = p_ocorrencia_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Ocorrência % não encontrada', p_ocorrencia_id USING ERRCODE = 'P0002';
    END IF;
    IF v_autor IS DISTINCT FROM v_usuario AND NOT eh_equipe() THEN
        RAISE EXCEPTION 'Apenas o autor da ocorrência ou a equipe podem anexar arquivos' USING ERRCODE = '42501';
    END IF;

    INSERT INTO anexo_ocorrencia (ocorrencia_id, tipo, url, nome_arquivo, tamanho_bytes, enviado_por)
    VALUES (p_ocorrencia_id, p_tipo, p_url, p_nome_arquivo, p_tamanho_bytes, v_usuario)
    RETURNING id INTO v_id;

    RETURN QUERY SELECT * FROM anexo_ocorrencia WHERE id = v_id;
END;
$$;

-- -----------------------------------------------------------------------------
-- dashboard_resumo : indicadores do gestor em uma chamada (totais, séries e rankings).
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION safetech.dashboard_resumo(p_dias INTEGER DEFAULT 30)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = safetech, public
AS $$
DECLARE
    v_inicio TIMESTAMPTZ := NOW() - make_interval(days => GREATEST(COALESCE(p_dias, 30), 1));
    v_json   JSONB;
BEGIN
    IF NOT eh_gestor() THEN
        RAISE EXCEPTION 'Apenas gestores ou administradores acessam o dashboard' USING ERRCODE = '42501';
    END IF;

    SELECT jsonb_build_object(
        'periodo_dias', GREATEST(COALESCE(p_dias, 30), 1),
        'totais', jsonb_build_object(
            'pracas',                    (SELECT COUNT(*) FROM praca WHERE ativa),
            'ocorrencias_abertas',       (SELECT COUNT(*) FROM ocorrencia WHERE status IN ('ABERTA', 'EM_ANALISE', 'EM_ATENDIMENTO')),
            'ocorrencias_periodo',       (SELECT COUNT(*) FROM ocorrencia WHERE ocorrida_em >= v_inicio),
            'resolvidas_periodo',        (SELECT COUNT(*) FROM ocorrencia WHERE status = 'RESOLVIDA' AND resolvida_em >= v_inicio),
            'alertas_novos',             (SELECT COUNT(*) FROM alerta WHERE status = 'NOVO'),
            'equipamentos_com_problema', (SELECT COUNT(*) FROM equipamento WHERE status <> 'OPERANTE'),
            'tempo_medio_resolucao_h',   (SELECT ROUND(AVG(EXTRACT(EPOCH FROM (resolvida_em - criado_em)) / 3600)::numeric, 1)
                                            FROM ocorrencia WHERE status = 'RESOLVIDA' AND resolvida_em >= v_inicio),
            'nota_media_seguranca',      (SELECT ROUND(AVG(nota)::numeric, 2) FROM avaliacao_praca)
        ),
        'por_status', COALESCE((
            SELECT jsonb_agg(jsonb_build_object('status', s.status, 'qtd', s.qtd) ORDER BY s.qtd DESC)
              FROM (SELECT status, COUNT(*) qtd FROM ocorrencia WHERE ocorrida_em >= v_inicio GROUP BY status) s), '[]'::jsonb),
        'por_categoria', COALESCE((
            SELECT jsonb_agg(jsonb_build_object('categoria', s.nome, 'qtd', s.qtd) ORDER BY s.qtd DESC)
              FROM (SELECT c.nome, COUNT(*) qtd FROM ocorrencia o JOIN categoria_ocorrencia c ON c.id = o.categoria_id
                     WHERE o.ocorrida_em >= v_inicio GROUP BY c.nome) s), '[]'::jsonb),
        'por_gravidade', COALESCE((
            SELECT jsonb_agg(jsonb_build_object('gravidade', s.gravidade, 'qtd', s.qtd) ORDER BY s.gravidade)
              FROM (SELECT gravidade, COUNT(*) qtd FROM ocorrencia WHERE ocorrida_em >= v_inicio GROUP BY gravidade) s), '[]'::jsonb),
        'por_dia', COALESCE((
            SELECT jsonb_agg(jsonb_build_object('dia', d.dia, 'qtd', COALESCE(s.qtd, 0)) ORDER BY d.dia)
              FROM generate_series(date_trunc('day', v_inicio)::date, CURRENT_DATE, '1 day') d(dia)
              LEFT JOIN (SELECT ocorrida_em::date dia, COUNT(*) qtd FROM ocorrencia WHERE ocorrida_em >= v_inicio GROUP BY 1) s
                     ON s.dia = d.dia), '[]'::jsonb),
        'por_praca', COALESCE((
            SELECT jsonb_agg(to_jsonb(r) ORDER BY r.ocorrencias_abertas DESC, r.nome) FROM vw_praca_resumo r), '[]'::jsonb),
        'alertas_recentes', COALESCE((
            SELECT jsonb_agg(to_jsonb(a) ORDER BY a.criado_em DESC)
              FROM (SELECT * FROM vw_alerta_pendente ORDER BY criado_em DESC LIMIT 10) a), '[]'::jsonb)
    ) INTO v_json;

    RETURN v_json;
END;
$$;

-- -----------------------------------------------------------------------------
-- Permissões
-- -----------------------------------------------------------------------------
GRANT EXECUTE ON FUNCTION safetech.detalhe_praca(UUID)                                  TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION safetech.avaliar_praca(UUID, SMALLINT, TEXT)                 TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION safetech.registrar_anexo(UUID, TEXT, TEXT, BIGINT, tipo_midia) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION safetech.dashboard_resumo(INTEGER)                            TO authenticated, service_role;
```

O que cada uma faz e por que é RPC e não REST direto:

| Função | Quem chama | Por que RPC |
|--------|-----------|-------------|
| `detalhe_praca(p_praca_id)` | público | Monta a tela inteira em 1 chamada (praça, resumo, equipamentos, ocorrências abertas, avaliações) sem expor autor nem dados pessoais. Com REST seriam 5 requisições e o anônimo não tem permissão em `ocorrencia`. |
| `avaliar_praca(p_praca_id, p_nota, p_comentario)` | logado | Regra "uma avaliação por pessoa por praça": atualiza se já existe. Valida nota 1–5. |
| `registrar_anexo(p_ocorrencia_id, p_url, ...)` | logado | Só o **autor** da ocorrência ou a equipe podem anexar. A política RLS sozinha não consegue checar isso. |
| `dashboard_resumo(p_dias)` | gestor/admin | Agrega totais, série por dia, por categoria/status/gravidade, ranking de praças e alertas pendentes em 1 JSON. |

### 1.1 Testar com curl (ou com a coleção `.http` da Ana)

```bash
set -a; . ./.env; set +a   # SUPABASE_URL e SUPABASE_ANON_KEY
H=(-H "apikey: $SUPABASE_ANON_KEY" -H "Content-Profile: safetech" -H "Content-Type: application/json")

# 1. público
curl -s -X POST "$SUPABASE_URL/rest/v1/rpc/detalhe_praca" "${H[@]}" -d '{"p_praca_id":"aaaaaaaa-0000-0000-0000-000000000001"}' | head -c 400

# 2. login como cidadão e gestor
TKC=$(curl -s "$SUPABASE_URL/auth/v1/token?grant_type=password" -H "apikey: $SUPABASE_ANON_KEY" -H "Content-Type: application/json" -d '{"email":"cidadao.demo@safetech.app","password":"Senha@123"}' | sed -n 's/.*"access_token":"\([^"]*\)".*/\1/p')
TKG=$(curl -s "$SUPABASE_URL/auth/v1/token?grant_type=password" -H "apikey: $SUPABASE_ANON_KEY" -H "Content-Type: application/json" -d '{"email":"gestor.demo@safetech.app","password":"Senha@123"}' | sed -n 's/.*"access_token":"\([^"]*\)".*/\1/p')

# 3. avaliar duas vezes: a segunda atualiza (mesmo id)
curl -s -X POST "$SUPABASE_URL/rest/v1/rpc/avaliar_praca" "${H[@]}" -H "Authorization: Bearer $TKC" -d '{"p_praca_id":"aaaaaaaa-0000-0000-0000-000000000001","p_nota":4,"p_comentario":"teste"}'
curl -s -X POST "$SUPABASE_URL/rest/v1/rpc/avaliar_praca" "${H[@]}" -H "Authorization: Bearer $TKC" -d '{"p_praca_id":"aaaaaaaa-0000-0000-0000-000000000001","p_nota":2}'

# 4. dashboard: cidadão bloqueado (403), gestor ok
curl -s -X POST "$SUPABASE_URL/rest/v1/rpc/dashboard_resumo" "${H[@]}" -H "Authorization: Bearer $TKC" -d '{"p_dias":30}'
curl -s -X POST "$SUPABASE_URL/rest/v1/rpc/dashboard_resumo" "${H[@]}" -H "Authorization: Bearer $TKG" -d '{"p_dias":30}' | head -c 500
```

Checklist: detalhe retorna JSON com `praca`, `equipamentos` (4) e `avaliacoes`; segunda avaliação devolve o
mesmo `id`; dashboard como cidadão dá `Apenas gestores...`; como gestor devolve `totais`.

```bash
git add database/supabase/09_rpc_cp3.sql
git commit -m "feat(db): RPCs do MVP - detalhe_praca, avaliar_praca, registrar_anexo, dashboard_resumo"
git push -u origin feat/cp3-davi
```

PR → revisor Lucas. Avise no grupo: **"RPCs do CP3 aplicadas"**.

## Passo 2 — Camada de API da equipe (tarde de quarta, após a base do Santhiago)

```bash
git pull origin main        # traz AuthContext, Layout, RotaProtegida, CSS
cd src/frontend && npm ci
```

Crie `src/api/equipe.ts`:

```ts
import { supabase } from '../lib/supabase';

export type StatusOcorrencia = 'ABERTA' | 'EM_ANALISE' | 'EM_ATENDIMENTO' | 'RESOLVIDA' | 'CANCELADA';

export type OcorrenciaAberta = {
  id: string; protocolo: string; titulo: string; gravidade: string; status: StatusOcorrencia;
  ocorrida_em: string; criado_em: string; praca_id: string; praca_nome: string; bairro: string;
  categoria: string; autor: string; qtd_anexos: number;
};

export type Atendimento = {
  id: string; ocorrencia_id: string; agente_id: string; atribuido_por: string | null;
  iniciado_em: string; finalizado_em: string | null; relato: string | null;
};

export type Historico = { id: number; status_anterior: StatusOcorrencia | null; status_novo: StatusOcorrencia; observacao: string | null; alterado_em: string };

/** Painel: ocorrências ABERTA / EM_ANALISE / EM_ATENDIMENTO (view respeita o RLS: só a equipe vê tudo). */
export async function listarOcorrenciasAbertas(): Promise<OcorrenciaAberta[]> {
  const { data, error } = await supabase
    .from('vw_ocorrencia_aberta').select('*')
    .order('gravidade', { ascending: false }).order('ocorrida_em', { ascending: true });
  if (error) throw error;
  return data as OcorrenciaAberta[];
}

/** Atendimentos em aberto (sem finalizado_em). Se agenteId for informado, só os dele. */
export async function listarAtendimentosAbertos(agenteId?: string): Promise<Atendimento[]> {
  let q = supabase.from('atendimento').select('*').is('finalizado_em', null);
  if (agenteId) q = q.eq('agente_id', agenteId);
  const { data, error } = await q;
  if (error) throw error;
  return data as Atendimento[];
}

export async function historicoOcorrencia(ocorrenciaId: string): Promise<Historico[]> {
  const { data, error } = await supabase
    .from('historico_ocorrencia').select('id, status_anterior, status_novo, observacao, alterado_em')
    .eq('ocorrencia_id', ocorrenciaId).order('id');
  if (error) throw error;
  return data as Historico[];
}

/** Agente assume a ocorrência (p_agente_id omitido = eu). Trigger move a ocorrência para EM_ATENDIMENTO. */
export async function atribuirAtendimento(ocorrenciaId: string, agenteId?: string): Promise<Atendimento> {
  const { data, error } = await supabase.rpc('atribuir_atendimento', { p_ocorrencia_id: ocorrenciaId, p_agente_id: agenteId ?? null });
  if (error) throw error;
  return (data as Atendimento[])[0];
}

export async function atualizarStatus(ocorrenciaId: string, status: StatusOcorrencia, observacao?: string) {
  const { data, error } = await supabase.rpc('atualizar_status_ocorrencia', {
    p_ocorrencia_id: ocorrenciaId, p_status: status, p_observacao: observacao?.trim() || null,
  });
  if (error) throw error;
  return data[0];
}

/** Fecha o atendimento com relato; resolver=true também marca a ocorrência como RESOLVIDA. */
export async function finalizarAtendimento(atendimentoId: string, relato: string, resolver = true): Promise<Atendimento> {
  const { data, error } = await supabase.rpc('finalizar_atendimento', { p_atendimento_id: atendimentoId, p_relato: relato, p_resolver: resolver });
  if (error) throw error;
  return (data as Atendimento[])[0];
}
```

Crie `src/api/alertas.ts`:

```ts
import type { RealtimeChannel, RealtimePostgresChangesPayload } from '@supabase/supabase-js';
import { supabase } from '../lib/supabase';

export type StatusAlerta = 'NOVO' | 'RECONHECIDO' | 'ENCERRADO' | 'FALSO_POSITIVO';

export type AlertaPendente = {
  id: string; origem: 'EQUIPAMENTO' | 'BOTAO_PANICO' | 'MANUAL'; gravidade: string; mensagem: string; criado_em: string;
  praca_id: string; praca_nome: string; equipamento_tipo: string | null; equipamento_codigo: string | null;
};

export type Alerta = {
  id: string; praca_id: string; equipamento_id: string | null; ocorrencia_id: string | null; origem: string;
  gravidade: string; status: StatusAlerta; mensagem: string; criado_por: string | null;
  reconhecido_por: string | null; reconhecido_em: string | null; encerrado_em: string | null; criado_em: string;
};

/** Alertas com status NOVO (view respeita o RLS: só a equipe). */
export async function listarAlertasPendentes(): Promise<AlertaPendente[]> {
  const { data, error } = await supabase.from('vw_alerta_pendente').select('*').order('criado_em', { ascending: false });
  if (error) throw error;
  return data as AlertaPendente[];
}

/** Últimos alertas tratados (para a aba "Histórico"). */
export async function listarAlertasTratados(limite = 20): Promise<Alerta[]> {
  const { data, error } = await supabase
    .from('alerta').select('*').neq('status', 'NOVO').order('criado_em', { ascending: false }).limit(limite);
  if (error) throw error;
  return data as Alerta[];
}

export async function reconhecerAlerta(alertaId: string, status: Exclude<StatusAlerta, 'NOVO'> = 'RECONHECIDO'): Promise<Alerta> {
  const { data, error } = await supabase.rpc('reconhecer_alerta', { p_alerta_id: alertaId, p_status: status });
  if (error) throw error;
  return (data as Alerta[])[0];
}

/**
 * Assina mudanças na tabela alerta em tempo real (INSERT/UPDATE). Exige que Lucas tenha adicionado
 * safetech.alerta à publicação supabase_realtime (10_hardening_cp3.sql). Retorne o channel e chame
 * supabase.removeChannel(channel) no cleanup do useEffect.
 */
export function assinarAlertas(aoMudar: (p: RealtimePostgresChangesPayload<Alerta>) => void): RealtimeChannel {
  return supabase
    .channel('alertas-tempo-real')
    .on<Alerta>('postgres_changes', { event: '*', schema: 'safetech', table: 'alerta' }, aoMudar)
    .subscribe();
}
```

## Passo 3 — Painel de ocorrências

Substitua o stub `src/pages/Painel.tsx`. Fila ordenada por gravidade, filtros (todas / minhas / por status),
linha expansível com histórico e ações: **assumir** (RPC `atribuir_atendimento` → trigger põe EM ATENDIMENTO),
**em análise**, **finalizar e resolver / sem resolver** (RPC `finalizar_atendimento`, só para quem assumiu),
**cancelar**.

```tsx
import { Fragment, useCallback, useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';
import {
  listarOcorrenciasAbertas, listarAtendimentosAbertos, historicoOcorrencia,
  atribuirAtendimento, atualizarStatus, finalizarAtendimento,
  type OcorrenciaAberta, type Atendimento, type Historico, type StatusOcorrencia,
} from '../api/equipe';

type Filtro = 'TODAS' | 'MINHAS' | StatusOcorrencia;

export function Painel() {
  const { usuario } = useAuth();
  const [ocorrencias, setOcorrencias] = useState<OcorrenciaAberta[] | null>(null);
  const [atendimentos, setAtendimentos] = useState<Atendimento[]>([]);
  const [filtro, setFiltro] = useState<Filtro>('TODAS');
  const [aberta, setAberta] = useState<string | null>(null);
  const [historico, setHistorico] = useState<Record<string, Historico[]>>({});
  const [texto, setTexto] = useState('');
  const [erro, setErro] = useState<string | null>(null);
  const [ocupado, setOcupado] = useState(false);

  const carregar = useCallback(() =>
    Promise.all([listarOcorrenciasAbertas(), listarAtendimentosAbertos()])
      .then(([oc, at]) => { setOcorrencias(oc); setAtendimentos(at); })
      .catch((e: Error) => setErro(e.message)), []);

  useEffect(() => { carregar(); }, [carregar]);

  const meuAtendimento = (ocorrenciaId: string) => atendimentos.find((a) => a.ocorrencia_id === ocorrenciaId && a.agente_id === usuario?.id);
  const atendimentoDe = (ocorrenciaId: string) => atendimentos.find((a) => a.ocorrencia_id === ocorrenciaId);

  async function abrir(id: string) {
    if (aberta === id) { setAberta(null); return; }
    setAberta(id); setTexto('');
    if (!historico[id]) {
      try { setHistorico((h) => ({ ...h, [id]: [] })); const lst = await historicoOcorrencia(id); setHistorico((h) => ({ ...h, [id]: lst })); }
      catch (e) { setErro((e as Error).message); }
    }
  }

  async function acao(fn: () => Promise<unknown>, id: string) {
    setOcupado(true); setErro(null);
    try {
      await fn();
      await carregar();
      const lst = await historicoOcorrencia(id);
      setHistorico((h) => ({ ...h, [id]: lst }));
      setTexto('');
    } catch (e) { setErro((e as Error).message); }
    finally { setOcupado(false); }
  }

  if (erro && !ocorrencias) return <p className="aviso erro">Erro: {erro}</p>;
  if (!ocorrencias) return <p className="aviso">Carregando...</p>;

  const visiveis = ocorrencias.filter((o) =>
    filtro === 'TODAS' ? true : filtro === 'MINHAS' ? Boolean(meuAtendimento(o.id)) : o.status === filtro);

  return (
    <section>
      <h1>Painel de ocorrências</h1>
      <p className="suave">Ocorrências em aberto de todas as praças, mais graves primeiro. Assuma uma para passar a EM ATENDIMENTO.</p>
      <div className="filtros">
        {(['TODAS', 'MINHAS', 'ABERTA', 'EM_ANALISE', 'EM_ATENDIMENTO'] as Filtro[]).map((f) => (
          <button key={f} className={filtro === f ? 'chip ativo' : 'chip'} onClick={() => setFiltro(f)}>
            {f === 'MINHAS' ? 'Minhas' : f.replace('_', ' ')}
            {' '}<small>({f === 'TODAS' ? ocorrencias.length : f === 'MINHAS' ? ocorrencias.filter((o) => meuAtendimento(o.id)).length : ocorrencias.filter((o) => o.status === f).length})</small>
          </button>
        ))}
        <button className="link" onClick={carregar}>↻ atualizar</button>
      </div>
      {erro && <p className="aviso erro">{erro}</p>}
      {visiveis.length === 0 ? <p className="aviso">Nada por aqui.</p> : (
        <table className="painel">
          <thead><tr><th>Gravidade</th><th>Protocolo</th><th>Título</th><th>Praça</th><th>Categoria</th><th>Autor</th><th>Status</th><th>Quando</th><th></th></tr></thead>
          <tbody>
            {visiveis.map((o) => {
              const meu = meuAtendimento(o.id);
              const alguem = atendimentoDe(o.id);
              return (
                <Fragment key={o.id}>
                  <tr className={aberta === o.id ? 'selecionada' : ''}>
                    <td><span className={`tag tag-${o.gravidade.toLowerCase()}`}>{o.gravidade}</span></td>
                    <td><Link to={`/protocolo?p=${o.protocolo}`}>{o.protocolo}</Link></td>
                    <td>{o.titulo}{o.qtd_anexos > 0 && <small className="suave"> 📎{o.qtd_anexos}</small>}</td>
                    <td><Link to={`/pracas/${o.praca_id}`}>{o.praca_nome}</Link></td>
                    <td>{o.categoria}</td>
                    <td>{o.autor}</td>
                    <td>{o.status.replace('_', ' ')}{alguem && !meu && <small className="suave"> (outro agente)</small>}</td>
                    <td>{new Date(o.ocorrida_em).toLocaleDateString('pt-BR')}</td>
                    <td><button className="link" onClick={() => abrir(o.id)}>{aberta === o.id ? 'fechar' : 'tratar'}</button></td>
                  </tr>
                  {aberta === o.id && (
                    <tr className="detalhe">
                      <td colSpan={9}>
                        <div className="duas-colunas">
                          <div>
                            <h3>Histórico</h3>
                            <ol className="linha-tempo">
                              {(historico[o.id] ?? []).map((h) => (
                                <li key={h.id}>
                                  <time>{new Date(h.alterado_em).toLocaleString('pt-BR')}</time>
                                  <div>{h.status_anterior ? `${h.status_anterior.replace('_', ' ')} → ` : ''}<strong>{h.status_novo.replace('_', ' ')}</strong>
                                    {h.observacao && <div className="suave">{h.observacao}</div>}</div>
                                </li>
                              ))}
                            </ol>
                          </div>
                          <div>
                            <h3>Ações</h3>
                            <textarea rows={3} placeholder="Observação / relato (opcional para status, obrigatório para finalizar)" value={texto} onChange={(e) => setTexto(e.target.value)} />
                            <div className="acoes">
                              {!alguem && (
                                <button disabled={ocupado} onClick={() => acao(() => atribuirAtendimento(o.id), o.id)}>Assumir atendimento</button>
                              )}
                              {o.status === 'ABERTA' && (
                                <button disabled={ocupado} className="secundario" onClick={() => acao(() => atualizarStatus(o.id, 'EM_ANALISE', texto), o.id)}>Marcar em análise</button>
                              )}
                              {meu && (
                                <>
                                  <button disabled={ocupado || texto.trim().length < 5} onClick={() => acao(() => finalizarAtendimento(meu.id, texto, true), o.id)}>Finalizar e resolver</button>
                                  <button disabled={ocupado || texto.trim().length < 5} className="secundario" onClick={() => acao(() => finalizarAtendimento(meu.id, texto, false), o.id)}>Finalizar sem resolver</button>
                                </>
                              )}
                              <button disabled={ocupado} className="perigo" onClick={() => acao(() => atualizarStatus(o.id, 'CANCELADA', texto || 'Cancelada pela equipe'), o.id)}>Cancelar ocorrência</button>
                            </div>
                          </div>
                        </div>
                      </td>
                    </tr>
                  )}
                </Fragment>
              );
            })}
          </tbody>
        </table>
      )}
    </section>
  );
}
```

Teste como `agente.demo`: a fila aparece; "tratar" numa ABERTA → "Assumir atendimento" → status vira
EM ATENDIMENTO e o filtro "Minhas" passa a contar 1 → escreva um relato → "Finalizar e resolver" → a ocorrência
sai da fila. Como `cidadao.demo`, `/painel` mostra "perfil sem acesso".

## Passo 4 — Alertas em tempo real (quinta)

Substitua o stub `src/pages/Alertas.tsx`. Lista pendentes e tratados; assina `postgres_changes` em
`safetech.alerta`; um alerta novo entra piscando sem recarregar. Depende do Lucas ter rodado o
`10_hardening_cp3.sql` (adiciona a tabela à publicação do Realtime).

```tsx
import { useCallback, useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { supabase } from '../lib/supabase';
import {
  listarAlertasPendentes, listarAlertasTratados, reconhecerAlerta, assinarAlertas,
  type AlertaPendente, type Alerta, type StatusAlerta,
} from '../api/alertas';

const ORIGEM: Record<string, string> = { EQUIPAMENTO: 'Equipamento', BOTAO_PANICO: 'Botão de pânico', MANUAL: 'Manual' };

export function Alertas() {
  const [pendentes, setPendentes] = useState<AlertaPendente[] | null>(null);
  const [tratados, setTratados] = useState<Alerta[]>([]);
  const [erro, setErro] = useState<string | null>(null);
  const [conectado, setConectado] = useState(false);
  const [novos, setNovos] = useState<string[]>([]); // ids que chegaram ao vivo (pisca)
  const [ocupado, setOcupado] = useState<string | null>(null);

  const carregar = useCallback(() =>
    Promise.all([listarAlertasPendentes(), listarAlertasTratados()])
      .then(([p, t]) => { setPendentes(p); setTratados(t); })
      .catch((e: Error) => setErro(e.message)), []);

  useEffect(() => {
    carregar();
    // Tempo real: qualquer INSERT/UPDATE em alerta recarrega a lista (a view já traz praça e equipamento)
    const canal = assinarAlertas((payload) => {
      if (payload.eventType === 'INSERT') {
        const id = (payload.new as Alerta).id;
        setNovos((n) => [...n, id]);
        setTimeout(() => setNovos((n) => n.filter((x) => x !== id)), 8000);
      }
      carregar();
    });
    const timer = setInterval(() => setConectado(canal.state === 'joined'), 1000);
    return () => { clearInterval(timer); supabase.removeChannel(canal); };
  }, [carregar]);

  async function tratar(id: string, status: Exclude<StatusAlerta, 'NOVO'>) {
    setOcupado(id); setErro(null);
    try { await reconhecerAlerta(id, status); await carregar(); }
    catch (e) { setErro((e as Error).message); }
    finally { setOcupado(null); }
  }

  if (erro && !pendentes) return <p className="aviso erro">Erro: {erro}</p>;
  if (!pendentes) return <p className="aviso">Carregando...</p>;

  return (
    <section>
      <h1>Alertas <span className={conectado ? 'tag tag-operante' : 'tag'} title="Conexão em tempo real">{conectado ? '● ao vivo' : '○ reconectando'}</span></h1>
      <p className="suave">Botões de pânico, câmeras e sensores geram alertas aqui em tempo real. Reconheça para avisar a equipe que alguém está tratando.</p>
      {erro && <p className="aviso erro">{erro}</p>}

      <h2>Pendentes ({pendentes.length})</h2>
      {pendentes.length === 0 ? <p className="aviso">Nenhum alerta pendente. 🎉</p> : (
        <ul className="alertas">
          {pendentes.map((a) => (
            <li key={a.id} className={`alerta grav-${a.gravidade.toLowerCase()} ${novos.includes(a.id) ? 'novo' : ''}`}>
              <div className="alerta-topo">
                <span className={`tag tag-${a.gravidade.toLowerCase()}`}>{a.gravidade}</span>
                <strong>{ORIGEM[a.origem] ?? a.origem}</strong>
                {a.equipamento_codigo && <code>{a.equipamento_codigo}</code>}
                <span className="suave">{new Date(a.criado_em).toLocaleString('pt-BR')}</span>
              </div>
              <div className="alerta-msg">{a.mensagem}</div>
              <div className="alerta-rodape">
                <Link to={`/pracas/${a.praca_id}`}>{a.praca_nome}</Link>
                <div className="acoes">
                  <button disabled={ocupado === a.id} onClick={() => tratar(a.id, 'RECONHECIDO')}>Reconhecer</button>
                  <button disabled={ocupado === a.id} className="secundario" onClick={() => tratar(a.id, 'ENCERRADO')}>Encerrar</button>
                  <button disabled={ocupado === a.id} className="secundario" onClick={() => tratar(a.id, 'FALSO_POSITIVO')}>Falso positivo</button>
                </div>
              </div>
            </li>
          ))}
        </ul>
      )}

      <h2>Tratados recentemente</h2>
      {tratados.length === 0 ? <p className="suave">Nenhum.</p> : (
        <table>
          <thead><tr><th>Quando</th><th>Origem</th><th>Gravidade</th><th>Mensagem</th><th>Status</th></tr></thead>
          <tbody>
            {tratados.map((t) => (
              <tr key={t.id}>
                <td>{new Date(t.criado_em).toLocaleString('pt-BR')}</td>
                <td>{ORIGEM[t.origem] ?? t.origem}</td>
                <td><span className={`tag tag-${t.gravidade.toLowerCase()}`}>{t.gravidade}</span></td>
                <td>{t.mensagem}</td>
                <td>{t.status.replace('_', ' ')}{t.status === 'RECONHECIDO' && (
                  <> · <button className="link" onClick={() => tratar(t.id, 'ENCERRADO')}>encerrar</button></>
                )}</td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </section>
  );
}
```

Teste ao vivo (é a cena mais forte da demo): abra `/alertas` como agente em uma aba; em outra, dispare um
botão de pânico sem login:

```bash
curl -s -X POST "$SUPABASE_URL/rest/v1/rpc/acionar_botao_panico" "${H[@]}" -d '{"p_equipamento_codigo":"BTN-DERBY-01","p_mensagem":"Teste da demo"}'
```

ou um evento da sua Edge Function:

```bash
curl -s -X POST "$SUPABASE_URL/functions/v1/evento-equipamento" -H "x-device-secret: $DEVICE_SECRET" -H "Content-Type: application/json" -d '{"codigo":"CAM-DERBY-01","evento":"MOVIMENTO_SUSPEITO"}'
```

O alerta deve aparecer em até 2 s com o indicador "● ao vivo". Clique em "Reconhecer" → vai para "Tratados".

Se não aparecer: (1) `○ reconectando` fixo → Realtime não habilitado para a tabela, chame o Lucas; (2) aparece só
após F5 → confira `schema: 'safetech'` na assinatura; (3) erro 401 no console → a sessão expirou, faça login de novo.

```bash
npm run lint && npm run build
git add -A && git commit -m "feat(front): painel de ocorrencias e alertas em tempo real para a equipe"
git push
```

PR → revisor Santhiago. Evidências (prints: fila, assumir, resolver, alerta chegando ao vivo) em
`docs/checkpoint-3/evidencias/davi-equipe.md`.

## Passo 5 — Sexta: correções e ensaio

Bugs do QA com etiqueta `back` ou `painel`/`alertas`. Ensaio da sua parte da demo (3 min): painel → assumir →
resolver → alerta ao vivo via botão de pânico → reconhecer.

## Erros comuns

| Sintoma | Causa / solução |
|---------|-----------------|
| `function safetech.detalhe_praca(...) does not exist` ao rodar o SQL | Rode o arquivo inteiro de uma vez; os `GRANT` do final referenciam as funções criadas acima. |
| `permission denied for table avaliacao_praca` dentro da RPC | A função precisa ser `SECURITY DEFINER` (já está). Se editou e perdeu, recrie. |
| Painel vazio para o agente, mas há ocorrências | `vw_ocorrencia_aberta` com `security_invoker` exige que o agente tenha a política `ocorrencia_select` (tem, via `eh_equipe()`). Confira se o usuário demo foi promovido (`05_users_teste.sql`). |
| `Assumir` dá `Apenas a equipe pode atribuir` | Está logado como cidadão, ou o perfil não foi promovido. |
| Realtime não conecta | Tabela fora da publicação (`10_hardening_cp3.sql`) ou Realtime desligado em Project Settings → API. |
