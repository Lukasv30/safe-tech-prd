# Roteiro — Lucas Victor (Engenheiro de Dados) · Checkpoint 3

**Entrega:** hardening do banco (`10_hardening_cp3.sql`), seed de demonstração, **dashboard do gestor**,
**deploy na Vercel**, **CI no GitHub**, e2e ampliado, limpeza dos dados de teste e tag `checkpoint-3`.

**Depende de:** o SQL pode ser aplicado já na manhã de quarta. O dashboard espera a base do Santhiago em `main`
(14h). A Vercel pode ser configurada a qualquer hora (ela publica o que estiver em `main`).

## Passo 1 — Hardening e Realtime (manhã de quarta)

```bash
git checkout main && git pull && git checkout -b feat/cp3-lucas
```

Crie `database/supabase/10_hardening_cp3.sql` e rode no SQL Editor. Ele fecha uma brecha real encontrada nos
testes: **qualquer cidadão logado lia os alertas e todas as ocorrências abertas pelas views**, porque views rodam
com a permissão do dono. Com `security_invoker` elas passam a respeitar o RLS de quem consulta.

```sql
-- =============================================================================
-- 10_hardening_cp3.sql : ajustes de segurança e infraestrutura do Checkpoint 3
-- =============================================================================

SET search_path TO safetech, public;

-- 1. Views que listam dados sensíveis passam a respeitar o RLS de quem consulta.
--    Sem isso, qualquer usuário logado lê alertas e todas as ocorrências abertas pela view,
--    porque a view roda com as permissões do dono (postgres). vw_praca_resumo continua
--    como está: só traz contagens e precisa ser lida por anônimos.
ALTER VIEW vw_ocorrencia_aberta SET (security_invoker = true);
ALTER VIEW vw_alerta_pendente   SET (security_invoker = true);

-- 2. Uma avaliação por usuário em cada praça (a RPC avaliar_praca atualiza em vez de duplicar).
CREATE UNIQUE INDEX IF NOT EXISTS uk_avaliacao_praca_usuario ON avaliacao_praca (praca_id, usuario_id);

-- 3. Cidadão pode apagar o próprio anexo (ex.: enviou a foto errada).
DROP POLICY IF EXISTS anexo_delete ON anexo_ocorrencia;
CREATE POLICY anexo_delete ON anexo_ocorrencia FOR DELETE TO authenticated
    USING (enviado_por = auth.uid() OR eh_equipe());

-- 4. Realtime: a tela "Alertas" assina INSERT/UPDATE em alerta e ocorrencia.
--    Só funciona no Supabase (a publicação não existe em um Postgres comum), por isso o DO.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
        IF NOT EXISTS (SELECT 1 FROM pg_publication_tables
                        WHERE pubname = 'supabase_realtime' AND schemaname = 'safetech' AND tablename = 'alerta') THEN
            ALTER PUBLICATION supabase_realtime ADD TABLE safetech.alerta;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM pg_publication_tables
                        WHERE pubname = 'supabase_realtime' AND schemaname = 'safetech' AND tablename = 'ocorrencia') THEN
            ALTER PUBLICATION supabase_realtime ADD TABLE safetech.ocorrencia;
        END IF;
    END IF;
END $$;

-- Realtime envia o registro completo em UPDATE/DELETE só com REPLICA IDENTITY FULL
ALTER TABLE alerta     REPLICA IDENTITY FULL;
ALTER TABLE ocorrencia REPLICA IDENTITY FULL;
```

Confirme no painel: **Database → Replication → supabase_realtime** lista `safetech.alerta` e
`safetech.ocorrencia`. Se o `DO` não as adicionou, marque as duas manualmente ali.

Depois, no terminal:

```bash
node database/scripts/e2e.mjs      # os 65 do CP2 continuam verdes?
```

## Passo 2 — Seed de demonstração

A base atual tem 3 ocorrências do seed e os registros `[E2E]`. Para o dashboard contar uma história, crie
`database/seeds/02_seed_demo_cp3.sql` e rode no SQL Editor (idempotente, pode rodar de novo):

```sql
-- =============================================================================
-- SafeTech — 02_seed_demo_cp3.sql : massa de dados para a demonstração do MVP
-- Idempotente (IDs fixos + ON CONFLICT DO NOTHING). Aplicar DEPOIS de 01_seed_dev.sql.
-- Objetivo: dashboard com séries de 30 dias, painel com fila variada, alertas em vários status.
-- =============================================================================
SET search_path TO safetech, public;

-- Dois cidadãos a mais (senha "123456", igual ao seed 01; não usados para login no Supabase)
INSERT INTO usuario (id, nome, email, senha_hash, telefone, perfil) VALUES
    ('66666666-6666-6666-6666-666666666666', 'Beatriz Cidadã', 'beatriz@exemplo.com',
     '$2b$10$Z2F7BxkNYyVFmcHZrUKxH.MiILg6Snfq/3bY2HYF96lVR/y2Pjs5i', '81999990006', 'CIDADAO'),
    ('77777777-7777-7777-7777-777777777777', 'Rafael Cidadão', 'rafael@exemplo.com',
     '$2b$10$Z2F7BxkNYyVFmcHZrUKxH.MiILg6Snfq/3bY2HYF96lVR/y2Pjs5i', '81999990007', 'CIDADAO')
ON CONFLICT (email) DO NOTHING;

-- -----------------------------------------------------------------------------
-- Ocorrências dos últimos 30 dias (protocolo e histórico vêm das triggers).
-- criado_em acompanha ocorrida_em para o tempo médio de resolução fazer sentido.
-- -----------------------------------------------------------------------------
WITH dados (id, praca, categoria, autor, titulo, descricao, gravidade, anonima, dias_atras) AS (VALUES
    ('dddddddd-0000-0000-0000-000000000001'::uuid, 'aaaaaaaa-0000-0000-0000-000000000001'::uuid, 'Iluminação precária',       '66666666-6666-6666-6666-666666666666'::uuid, 'Poste piscando na entrada norte',          'O poste da entrada norte pisca e apaga por minutos.',                  'MEDIA'::nivel_gravidade,   FALSE, 28),
    ('dddddddd-0000-0000-0000-000000000002', 'aaaaaaaa-0000-0000-0000-000000000001', 'Vandalismo',                '77777777-7777-7777-7777-777777777777', 'Brinquedo do playground quebrado',          'Balanço com corrente arrebentada, risco para crianças.',               'MEDIA',   FALSE, 26),
    ('dddddddd-0000-0000-0000-000000000003', 'aaaaaaaa-0000-0000-0000-000000000002', 'Infraestrutura danificada', '44444444-4444-4444-4444-444444444444', 'Buraco na pista de caminhada',              'Buraco de uns 40 cm perto da quadra.',                                  'BAIXA',   FALSE, 25),
    ('dddddddd-0000-0000-0000-000000000004', 'aaaaaaaa-0000-0000-0000-000000000003', 'Pessoa suspeita',           NULL,                                   'Grupo abordando turistas',                  'Grupo aborda turistas insistentemente perto do píer.',                 'MEDIA',   TRUE,  22),
    ('dddddddd-0000-0000-0000-000000000005', 'aaaaaaaa-0000-0000-0000-000000000001', 'Uso de drogas',             NULL,                                   'Uso de drogas atrás do coreto',             'Toda noite, após as 22h.',                                              'ALTA',    TRUE,  20),
    ('dddddddd-0000-0000-0000-000000000006', 'aaaaaaaa-0000-0000-0000-000000000002', 'Iluminação precária',       '55555555-5555-5555-5555-555555555555', 'Quadra sem iluminação',                     'Os refletores da quadra não acendem há 3 dias.',                       'MEDIA',   FALSE, 18),
    ('dddddddd-0000-0000-0000-000000000007', 'aaaaaaaa-0000-0000-0000-000000000003', 'Equipamento de segurança',  '66666666-6666-6666-6666-666666666666', 'Câmera do Marco Zero virada para o chão',   'A câmera PTZ parece ter sido movida e filma só o piso.',               'ALTA',    FALSE, 15),
    ('dddddddd-0000-0000-0000-000000000008', 'aaaaaaaa-0000-0000-0000-000000000001', 'Assalto / Roubo',           NULL,                                   'Roubo de celular na pista',                 'Dois homens em moto levaram o celular de uma corredora às 6h.',        'ALTA',    TRUE,  12),
    ('dddddddd-0000-0000-0000-000000000009', 'aaaaaaaa-0000-0000-0000-000000000002', 'Aglomeração / Briga',       '77777777-7777-7777-7777-777777777777', 'Briga após jogo na quadra',                 'Confusão generalizada depois de partida de futsal.',                   'CRITICA', FALSE, 10),
    ('dddddddd-0000-0000-0000-000000000010', 'aaaaaaaa-0000-0000-0000-000000000001', 'Infraestrutura danificada', '44444444-4444-4444-4444-444444444444', 'Banco de concreto rachado',                 'Banco perto do lago com rachadura grande.',                            'BAIXA',   FALSE, 8),
    ('dddddddd-0000-0000-0000-000000000011', 'aaaaaaaa-0000-0000-0000-000000000003', 'Vandalismo',                '55555555-5555-5555-5555-555555555555', 'Pichação no monumento',                     'Pichação nova na base do marco.',                                      'MEDIA',   FALSE, 6),
    ('dddddddd-0000-0000-0000-000000000012', 'aaaaaaaa-0000-0000-0000-000000000001', 'Iluminação precária',       '66666666-6666-6666-6666-666666666666', 'Trecho escuro perto do estacionamento',     'Três postes seguidos apagados.',                                        'MEDIA',   FALSE, 4),
    ('dddddddd-0000-0000-0000-000000000013', 'aaaaaaaa-0000-0000-0000-000000000002', 'Pessoa suspeita',           NULL,                                   'Homem observando crianças no playground',   'Permanece horas sem criança acompanhando.',                            'ALTA',    TRUE,  2),
    ('dddddddd-0000-0000-0000-000000000014', 'aaaaaaaa-0000-0000-0000-000000000003', 'Outros',                    '77777777-7777-7777-7777-777777777777', 'Ambulante bloqueando acesso',               'Barracas fechando a rampa de acessibilidade.',                         'BAIXA',   FALSE, 1),
    ('dddddddd-0000-0000-0000-000000000015', 'aaaaaaaa-0000-0000-0000-000000000001', 'Equipamento de segurança',  '44444444-4444-4444-4444-444444444444', 'Botão de pânico sem resposta',              'Apertei o botão do totem e nada aconteceu.',                           'CRITICA', FALSE, 0)
)
INSERT INTO ocorrencia (id, praca_id, categoria_id, autor_id, titulo, descricao, gravidade, anonima, ocorrida_em, criado_em)
SELECT d.id, d.praca, c.id, d.autor, d.titulo, d.descricao, d.gravidade, d.anonima,
       NOW() - make_interval(days => d.dias_atras, hours => 3),
       NOW() - make_interval(days => d.dias_atras, hours => 2)
  FROM dados d JOIN categoria_ocorrencia c ON c.nome = d.categoria
ON CONFLICT (id) DO NOTHING;

-- Fluxo de atendimento: algumas em análise, algumas atendidas e resolvidas, uma cancelada
UPDATE ocorrencia SET status = 'EM_ANALISE'
 WHERE id IN ('dddddddd-0000-0000-0000-000000000011', 'dddddddd-0000-0000-0000-000000000013') AND status = 'ABERTA';

INSERT INTO atendimento (ocorrencia_id, agente_id, atribuido_por, iniciado_em, finalizado_em, relato)
SELECT o.id, '33333333-3333-3333-3333-333333333333', '22222222-2222-2222-2222-222222222222',
       o.criado_em + INTERVAL '5 hours', o.criado_em + INTERVAL '2 days', 'Equipe da manutenção acionada e problema sanado.'
  FROM ocorrencia o
 WHERE o.id IN ('dddddddd-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-000000000002', 'dddddddd-0000-0000-0000-000000000003',
                'dddddddd-0000-0000-0000-000000000006', 'dddddddd-0000-0000-0000-000000000007', 'dddddddd-0000-0000-0000-000000000010')
   AND NOT EXISTS (SELECT 1 FROM atendimento a WHERE a.ocorrencia_id = o.id);

UPDATE ocorrencia SET status = 'RESOLVIDA'
 WHERE id IN ('dddddddd-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-000000000002', 'dddddddd-0000-0000-0000-000000000003',
              'dddddddd-0000-0000-0000-000000000006', 'dddddddd-0000-0000-0000-000000000010')
   AND status <> 'RESOLVIDA';

-- Atendimento ainda em curso (câmera do Marco Zero): fica EM_ATENDIMENTO
UPDATE atendimento SET finalizado_em = NULL, relato = NULL WHERE ocorrencia_id = 'dddddddd-0000-0000-0000-000000000007';

UPDATE ocorrencia SET status = 'CANCELADA' WHERE id = 'dddddddd-0000-0000-0000-000000000004' AND status <> 'CANCELADA';

-- -----------------------------------------------------------------------------
-- Alertas em vários estados
-- -----------------------------------------------------------------------------
INSERT INTO alerta (id, praca_id, equipamento_id, origem, gravidade, status, mensagem, reconhecido_por, reconhecido_em, encerrado_em, criado_em) VALUES
    ('eeeeeeee-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000002', 'bbbbbbbb-0000-0000-0000-000000000005', 'EQUIPAMENTO', 'MEDIA',   'ENCERRADO',   'SEM SINAL em CAMERA CAM-CFORTE-01 (Quadra)',          '33333333-3333-3333-3333-333333333333', NOW() - INTERVAL '9 days', NOW() - INTERVAL '9 days', NOW() - INTERVAL '9 days 1 hour'),
    ('eeeeeeee-0000-0000-0000-000000000002', 'aaaaaaaa-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-000000000004', 'EQUIPAMENTO', 'BAIXA',   'FALSO_POSITIVO', 'FALHA em ILUMINACAO ILU-DERBY-01 (Pista de caminhada)', '22222222-2222-2222-2222-222222222222', NOW() - INTERVAL '6 days', NOW() - INTERVAL '6 days', NOW() - INTERVAL '6 days 2 hours'),
    ('eeeeeeee-0000-0000-0000-000000000003', 'aaaaaaaa-0000-0000-0000-000000000003', 'bbbbbbbb-0000-0000-0000-000000000007', 'EQUIPAMENTO', 'ALTA',    'RECONHECIDO', 'MOVIMENTO SUSPEITO em CAMERA CAM-MZERO-01 (Marco Zero)', '33333333-3333-3333-3333-333333333333', NOW() - INTERVAL '3 hours', NULL, NOW() - INTERVAL '4 hours'),
    ('eeeeeeee-0000-0000-0000-000000000004', 'aaaaaaaa-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-000000000001', 'EQUIPAMENTO', 'ALTA',    'NOVO',        'RUIDO ALTO em CAMERA CAM-DERBY-01 (Entrada principal)', NULL, NULL, NULL, NOW() - INTERVAL '40 minutes'),
    ('eeeeeeee-0000-0000-0000-000000000005', 'aaaaaaaa-0000-0000-0000-000000000002', 'bbbbbbbb-0000-0000-0000-000000000006', 'BOTAO_PANICO', 'CRITICA', 'NOVO',       'Botão de pânico acionado em Entrada lateral',           NULL, NULL, NULL, NOW() - INTERVAL '12 minutes')
ON CONFLICT (id) DO NOTHING;

-- -----------------------------------------------------------------------------
-- Rondas e avaliações
-- -----------------------------------------------------------------------------
INSERT INTO ronda (id, praca_id, agente_id, status, agendada_para, iniciada_em, finalizada_em, observacoes) VALUES
    ('ffffffff-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000002', '33333333-3333-3333-3333-333333333333', 'CONCLUIDA', NOW() - INTERVAL '5 days', NOW() - INTERVAL '5 days', NOW() - INTERVAL '5 days' + INTERVAL '50 minutes', 'Quadra escura confirmada; refletores com disjuntor desarmado.'),
    ('ffffffff-0000-0000-0000-000000000002', 'aaaaaaaa-0000-0000-0000-000000000001', '33333333-3333-3333-3333-333333333333', 'CONCLUIDA', NOW() - INTERVAL '2 days', NOW() - INTERVAL '2 days', NOW() - INTERVAL '2 days' + INTERVAL '35 minutes', 'Sem intercorrências.'),
    ('ffffffff-0000-0000-0000-000000000003', 'aaaaaaaa-0000-0000-0000-000000000003', '33333333-3333-3333-3333-333333333333', 'EM_ANDAMENTO', NOW() - INTERVAL '1 hour', NOW() - INTERVAL '50 minutes', NULL, NULL),
    ('ffffffff-0000-0000-0000-000000000004', 'aaaaaaaa-0000-0000-0000-000000000001', '33333333-3333-3333-3333-333333333333', 'AGENDADA', NOW() + INTERVAL '1 day', NULL, NULL, NULL)
ON CONFLICT (id) DO NOTHING;

INSERT INTO avaliacao_praca (praca_id, usuario_id, nota, comentario)
SELECT v.praca, v.usuario, v.nota, v.comentario
  FROM (VALUES
    ('aaaaaaaa-0000-0000-0000-000000000001'::uuid, '66666666-6666-6666-6666-666666666666'::uuid, 2, 'Evito passar depois das 20h.'),
    ('aaaaaaaa-0000-0000-0000-000000000001', '77777777-7777-7777-7777-777777777777', 3, 'Melhorou com as câmeras, mas ainda tem trechos escuros.'),
    ('aaaaaaaa-0000-0000-0000-000000000002', '66666666-6666-6666-6666-666666666666', 4, 'Movimentada, me sinto segura.'),
    ('aaaaaaaa-0000-0000-0000-000000000002', '77777777-7777-7777-7777-777777777777', 4, NULL),
    ('aaaaaaaa-0000-0000-0000-000000000003', '44444444-4444-4444-4444-444444444444', 3, 'De dia ótima, à noite depende do evento.'),
    ('aaaaaaaa-0000-0000-0000-000000000003', '66666666-6666-6666-6666-666666666666', 4, 'Muita polícia por perto.')
  ) AS v(praca, usuario, nota, comentario)
 WHERE NOT EXISTS (SELECT 1 FROM avaliacao_praca a WHERE a.praca_id = v.praca AND a.usuario_id = v.usuario);
```

Resultado esperado em `SELECT status, COUNT(*) FROM safetech.ocorrencia GROUP BY 1`: ~7 ABERTA, 2 EM_ANALISE,
2 EM_ATENDIMENTO, 6 RESOLVIDA, 1 CANCELADA (mais o que o e2e criou). Dashboard com 16 dos 31 dias preenchidos.

Limpeza dos registros de teste antes da apresentação (os `[E2E]` não têm política de DELETE para ninguém, então
só por SQL):

```sql
SET search_path TO safetech;
DELETE FROM notificacao WHERE alerta_id IN (SELECT id FROM alerta WHERE mensagem LIKE '[E2E]%');
DELETE FROM alerta WHERE mensagem LIKE '[E2E]%';
DELETE FROM ocorrencia WHERE titulo LIKE '[E2E]%';   -- anexos e histórico caem em cascata
DELETE FROM storage.objects WHERE bucket_id = 'anexos' AND name LIKE 'e2e/%';
```

```bash
git add database/supabase/10_hardening_cp3.sql database/seeds/02_seed_demo_cp3.sql
git commit -m "feat(db): hardening das views, realtime, indice de avaliacao e seed de demonstracao"
git push -u origin feat/cp3-lucas
```

PR → revisora Ana. Avise no grupo: **"Realtime ligado e seed de demo aplicado"** (Davi precisa para testar alertas).

## Passo 3 — Deploy na Vercel (tarde de quarta)

1. Acesse vercel.com, entre com o GitHub, **Add New → Project**, importe `Lukasv30/safe-tech-prd`.
2. **Root Directory:** `src/frontend`. Framework: Vite (detecta sozinho).
3. **Environment Variables:** `VITE_SUPABASE_URL` e `VITE_SUPABASE_ANON_KEY` (os mesmos do seu `.env`).
4. Deploy. Anote a URL (`https://safe-tech-prd.vercel.app` ou parecida) e publique no grupo e no README.

Para o `react-router` funcionar ao recarregar `/pracas/<id>`, crie `src/frontend/vercel.json`:

```json
{
  "$schema": "https://openapi.vercel.sh/vercel.json",
  "framework": "vite",
  "installCommand": "npm ci",
  "buildCommand": "npm run build",
  "outputDirectory": "dist",
  "rewrites": [{ "source": "/(.*)", "destination": "/index.html" }]
}
```

Supabase: em **Authentication → URL Configuration**, coloque a URL da Vercel em *Site URL* e em *Redirect URLs*
(senão o link de confirmação de e-mail, se for reativado, aponta para localhost).

A partir daí **todo merge em `main` publica sozinho** e cada PR ganha uma URL de preview (ótimo para o QA testar
antes do merge).

## Passo 4 — CI no GitHub

Crie `.github/workflows/ci.yml`:

```yaml
name: CI

on:
  pull_request:
  push:
    branches: [main]

jobs:
  front:
    name: Front-end (lint + tipos + build)
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: src/frontend
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 24
          cache: npm
          cache-dependency-path: src/frontend/package-lock.json
      - run: npm ci
      - run: npm run lint
      - run: npm run build
        env:
          # Valores de exemplo: o build não chama a API, só precisa que as variáveis existam
          VITE_SUPABASE_URL: https://exemplo.supabase.co
          VITE_SUPABASE_ANON_KEY: exemplo

  api:
    name: API (testes ponta a ponta contra o Supabase)
    runs-on: ubuntu-latest
    # Só roda quando os secrets existem (PRs de forks não têm acesso a eles)
    if: github.event_name == 'push' || github.event.pull_request.head.repo.full_name == github.repository
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 24
      - name: Healthcheck
        run: bash database/scripts/healthcheck.sh
        env:
          SUPABASE_URL: ${{ secrets.SUPABASE_URL }}
          SUPABASE_ANON_KEY: ${{ secrets.SUPABASE_ANON_KEY }}
      - name: E2E
        run: node database/scripts/e2e.mjs
        env:
          SUPABASE_URL: ${{ secrets.SUPABASE_URL }}
          SUPABASE_ANON_KEY: ${{ secrets.SUPABASE_ANON_KEY }}
          DEVICE_SECRET: ${{ secrets.DEVICE_SECRET }}
```

No repositório, **Settings → Secrets and variables → Actions**, crie `SUPABASE_URL`, `SUPABASE_ANON_KEY` e
`DEVICE_SECRET` (peça o último ao Davi em privado). Depois, em **Settings → Branches**, proteja `main`
exigindo o check "Front-end" verde antes do merge.

```bash
git add src/frontend/vercel.json .github/workflows/ci.yml
git commit -m "ci: lint, build e e2e em todo PR; deploy continuo na Vercel"
git push
```

## Passo 5 — Dashboard do gestor (quinta, após a base do Santhiago)

```bash
git pull origin main && cd src/frontend && npm ci
```

Crie `src/api/dashboard.ts`:

```ts
import { supabase } from '../lib/supabase';
import type { PracaResumo } from './pracas';
import type { AlertaPendente } from './alertas';

export type DashboardResumo = {
  periodo_dias: number;
  totais: {
    pracas: number; ocorrencias_abertas: number; ocorrencias_periodo: number; resolvidas_periodo: number;
    alertas_novos: number; equipamentos_com_problema: number; tempo_medio_resolucao_h: number | null; nota_media_seguranca: number | null;
  };
  por_status: { status: string; qtd: number }[];
  por_categoria: { categoria: string; qtd: number }[];
  por_gravidade: { gravidade: string; qtd: number }[];
  por_dia: { dia: string; qtd: number }[];
  por_praca: (PracaResumo & { ocorrencias_30_dias: number; equipamentos: number; equipamentos_com_problema: number; qtd_avaliacoes: number })[];
  alertas_recentes: AlertaPendente[];
};

/** Indicadores do gestor (RPC dashboard_resumo; só GESTOR/ADMIN). */
export async function carregarDashboard(dias = 30): Promise<DashboardResumo> {
  const { data, error } = await supabase.rpc('dashboard_resumo', { p_dias: dias });
  if (error) throw error;
  return data as DashboardResumo;
}
```

Substitua o stub `src/pages/Dashboard.tsx`. Gráficos em CSS puro (sem biblioteca): barras por dia, barras
horizontais por categoria/status/gravidade, ranking de praças, alertas pendentes. Seletor 7/30/90 dias.

```tsx
import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { carregarDashboard, type DashboardResumo } from '../api/dashboard';

const ROTULO_STATUS: Record<string, string> = {
  ABERTA: 'Aberta', EM_ANALISE: 'Em análise', EM_ATENDIMENTO: 'Em atendimento', RESOLVIDA: 'Resolvida', CANCELADA: 'Cancelada',
};

export function Dashboard() {
  const [dias, setDias] = useState(30);
  const [dados, setDados] = useState<DashboardResumo | null>(null);
  const [erro, setErro] = useState<string | null>(null);

  useEffect(() => {
    carregarDashboard(dias).then(setDados).catch((e) => setErro(e.message));
  }, [dias]);

  function trocarPeriodo(d: number) {
    setDados(null);
    setDias(d);
  }

  if (erro) return <p className="aviso erro">Erro: {erro}</p>;
  if (!dados) return <p className="aviso">Carregando indicadores...</p>;

  const { totais } = dados;
  const maxDia = Math.max(1, ...dados.por_dia.map((d) => d.qtd));
  const totalPeriodo = Math.max(1, totais.ocorrencias_periodo);

  return (
    <section>
      <div className="titulo-com-acoes">
        <h1>Dashboard do gestor</h1>
        <div className="filtros">
          {[7, 30, 90].map((d) => (
            <button key={d} className={dias === d ? 'chip ativo' : 'chip'} onClick={() => trocarPeriodo(d)}>{d} dias</button>
          ))}
        </div>
      </div>

      <div className="cartoes">
        <Indicador rotulo="Praças monitoradas" valor={totais.pracas} />
        <Indicador rotulo="Ocorrências abertas" valor={totais.ocorrencias_abertas} destaque={totais.ocorrencias_abertas > 0} />
        <Indicador rotulo={`Registradas (${dias} d)`} valor={totais.ocorrencias_periodo} />
        <Indicador rotulo={`Resolvidas (${dias} d)`} valor={totais.resolvidas_periodo} />
        <Indicador rotulo="Alertas novos" valor={totais.alertas_novos} destaque={totais.alertas_novos > 0} />
        <Indicador rotulo="Equipamentos c/ problema" valor={totais.equipamentos_com_problema} destaque={totais.equipamentos_com_problema > 0} />
        <Indicador rotulo="Tempo médio de resolução" valor={totais.tempo_medio_resolucao_h != null ? `${totais.tempo_medio_resolucao_h} h` : '—'} />
        <Indicador rotulo="Sensação de segurança" valor={totais.nota_media_seguranca != null ? `${Number(totais.nota_media_seguranca).toFixed(2)} / 5` : '—'} />
      </div>

      <div className="duas-colunas">
        <div className="cartao-largo">
          <h2>Ocorrências por dia</h2>
          <div className="grafico-barras" role="img" aria-label="Ocorrências registradas por dia">
            {dados.por_dia.map((d) => (
              <div key={d.dia} className="barra" style={{ height: `${(d.qtd / maxDia) * 100}%` }} title={`${new Date(d.dia).toLocaleDateString('pt-BR')}: ${d.qtd}`}>
                {d.qtd > 0 && <span>{d.qtd}</span>}
              </div>
            ))}
          </div>
          <div className="eixo suave">
            <span>{new Date(dados.por_dia[0]?.dia).toLocaleDateString('pt-BR')}</span>
            <span>hoje</span>
          </div>
        </div>

        <div className="cartao-largo">
          <h2>Por categoria</h2>
          <BarrasHorizontais itens={dados.por_categoria.map((c) => ({ rotulo: c.categoria, qtd: c.qtd }))} total={totalPeriodo} />
          <h2>Por status</h2>
          <BarrasHorizontais itens={dados.por_status.map((s) => ({ rotulo: ROTULO_STATUS[s.status] ?? s.status, qtd: s.qtd, classe: `st-${s.status.toLowerCase()}` }))} total={totalPeriodo} />
          <h2>Por gravidade</h2>
          <BarrasHorizontais itens={dados.por_gravidade.map((g) => ({ rotulo: g.gravidade, qtd: g.qtd, classe: `grav-${g.gravidade.toLowerCase()}` }))} total={totalPeriodo} />
        </div>
      </div>

      <h2>Praças</h2>
      <table>
        <thead><tr><th>Praça</th><th>Bairro</th><th>Abertas</th><th>30 dias</th><th>Alertas novos</th><th>Equipamentos c/ problema</th><th>Nota</th></tr></thead>
        <tbody>
          {dados.por_praca.map((p) => (
            <tr key={p.id}>
              <td><Link to={`/pracas/${p.id}`}>{p.nome}</Link></td><td>{p.bairro}</td>
              <td>{p.ocorrencias_abertas}</td><td>{p.ocorrencias_30_dias}</td>
              <td>{p.alertas_novos > 0 ? <strong className="perigo-texto">{p.alertas_novos}</strong> : 0}</td>
              <td>{p.equipamentos_com_problema}/{p.equipamentos}</td>
              <td>{p.nota_media_seguranca != null ? Number(p.nota_media_seguranca).toFixed(1) : '—'} <small className="suave">({p.qtd_avaliacoes})</small></td>
            </tr>
          ))}
        </tbody>
      </table>

      <h2>Alertas pendentes <Link to="/alertas" className="suave">ver todos →</Link></h2>
      {dados.alertas_recentes.length === 0 ? <p className="suave">Nenhum alerta pendente.</p> : (
        <ul className="lista-compacta">
          {dados.alertas_recentes.map((a) => (
            <li key={a.id}><span className={`tag tag-${a.gravidade.toLowerCase()}`}>{a.gravidade}</span> {a.praca_nome}: {a.mensagem}
              <span className="suave"> · {new Date(a.criado_em).toLocaleString('pt-BR')}</span></li>
          ))}
        </ul>
      )}
    </section>
  );
}

function Indicador({ rotulo, valor, destaque }: { rotulo: string; valor: number | string; destaque?: boolean }) {
  return (
    <div className={destaque ? 'cartao destaque' : 'cartao'}>
      <div className="cartao-valor">{valor}</div>
      <div className="cartao-rotulo">{rotulo}</div>
    </div>
  );
}

function BarrasHorizontais({ itens, total }: { itens: { rotulo: string; qtd: number; classe?: string }[]; total: number }) {
  if (itens.length === 0) return <p className="suave">Sem dados no período.</p>;
  return (
    <ul className="barras-h">
      {itens.map((i) => (
        <li key={i.rotulo}>
          <span className="barras-h-rotulo">{i.rotulo}</span>
          <span className="barras-h-trilho"><span className={`barras-h-preenchimento ${i.classe ?? ''}`} style={{ width: `${Math.round((i.qtd / total) * 100)}%` }} /></span>
          <span className="barras-h-valor">{i.qtd}</span>
        </li>
      ))}
    </ul>
  );
}
```

Teste como `gestor.demo`: 8 indicadores, gráfico com barras, ranking com 3 praças. Como `agente.demo`,
`/dashboard` mostra "perfil sem acesso" e o menu não exibe o link.

```bash
npm run lint && npm run build
git add -A && git commit -m "feat(front): dashboard do gestor com indicadores e graficos"
git push
```

## Passo 6 — e2e ampliado

Em `database/scripts/e2e.mjs`, cole o bloco abaixo **antes** da seção `// Resumo`. São 17 testes a mais
(RPCs novas e hardening).

```js
// -----------------------------------------------------------------------------
// 7. Checkpoint 3: detalhe_praca, avaliar_praca, registrar_anexo, dashboard_resumo, hardening
//    (cole este bloco em database/scripts/e2e.mjs antes da seção "Resumo")
// -----------------------------------------------------------------------------
r = await rpc('detalhe_praca', { p_praca_id: PRACA_DERBY });
check('cp3', 'RPC detalhe_praca sem login', r.status === 200 && r.json?.praca?.nome && Array.isArray(r.json.equipamentos) && Array.isArray(r.json.avaliacoes), `${r.status} / ${r.json?.praca?.nome ?? msg(r)}`);
check('cp3', 'detalhe_praca não expõe autor das ocorrências', r.status === 200 && (r.json.ocorrencias_abertas ?? []).every((o) => !('autor' in o) && !('autor_id' in o)), `${(r.json?.ocorrencias_abertas ?? []).length} abertas`);
r = await rpc('detalhe_praca', { p_praca_id: '00000000-0000-0000-0000-000000000000' });
check('cp3', 'detalhe_praca inexistente → null', r.status === 200 && r.json === null, `${r.status}`);

r = await rpc('avaliar_praca', { p_praca_id: PRACA_DERBY, p_nota: 4, p_comentario: '[E2E] avaliação' });
check('cp3', 'RPC avaliar_praca sem login → bloqueado', r.status >= 400, `${r.status} / ${msg(r)}`);
r = await rpc('avaliar_praca', { p_praca_id: PRACA_DERBY, p_nota: 4, p_comentario: '[E2E] primeira' }, tk.cidadao);
check('cp3', 'RPC avaliar_praca como cidadão', r.status === 200 && r.json?.[0]?.nota === 4, `${r.status} / ${r.json?.[0]?.nota ?? msg(r)}`);
r = await rpc('avaliar_praca', { p_praca_id: PRACA_DERBY, p_nota: 2, p_comentario: '[E2E] atualizada' }, tk.cidadao);
check('cp3', 'avaliar_praca de novo atualiza (não duplica)', r.status === 200 && r.json?.[0]?.nota === 2, `${r.status}`);
r = await rest(`avaliacao_praca?select=id&praca_id=eq.${PRACA_DERBY}&usuario_id=eq.${meuId}`, { token: tk.cidadao });
check('cp3', 'só existe 1 avaliação minha nesta praça', r.status === 200 && r.json.length === 1, `${r.json?.length}`);
r = await rpc('avaliar_praca', { p_praca_id: PRACA_DERBY, p_nota: 9 }, tk.cidadao);
check('cp3', 'avaliar_praca nota 9 → erro', r.status >= 400, `${r.status} / ${msg(r)}`);
r = await write('DELETE', `avaliacao_praca?praca_id=eq.${PRACA_DERBY}&usuario_id=eq.${meuId}`, undefined, tk.cidadao);
check('cp3', 'limpeza da avaliação', r.status === 200, `${r.status}`);

r = await rpc('registrar_anexo', { p_ocorrencia_id: ocCid?.id, p_url: 'https://exemplo/anexos/e2e.jpg', p_nome_arquivo: 'e2e.jpg', p_tamanho_bytes: 10 }, tk.cidadao);
const anexoId = r.json?.[0]?.id;
check('cp3', 'RPC registrar_anexo na própria ocorrência', r.status === 200 && anexoId, `${r.status} / ${anexoId ?? msg(r)}`);
r = await rpc('registrar_anexo', { p_ocorrencia_id: ocAnon?.id, p_url: 'https://exemplo/anexos/x.jpg' }, tk.cidadao);
check('cp3', 'registrar_anexo em ocorrência de outro → bloqueado', r.status >= 400, `${r.status} / ${msg(r)}`);
r = await rpc('registrar_anexo', { p_ocorrencia_id: ocAnon?.id, p_url: 'https://exemplo/anexos/laudo.pdf', p_tipo: 'DOCUMENTO' }, tk.agente);
check('cp3', 'registrar_anexo pela equipe em qualquer ocorrência', r.status === 200 && r.json?.[0]?.tipo === 'DOCUMENTO', `${r.status}`);
if (anexoId) { r = await write('DELETE', `anexo_ocorrencia?id=eq.${anexoId}`, undefined, tk.cidadao); check('cp3', 'cidadão apaga o próprio anexo (limpeza)', r.status === 200 && r.json.length === 1, `${r.status}`); }

r = await rpc('dashboard_resumo', { p_dias: 30 }, tk.cidadao);
check('cp3', 'RPC dashboard_resumo como cidadão → bloqueado', r.status >= 400, `${r.status} / ${msg(r)}`);
r = await rpc('dashboard_resumo', { p_dias: 30 }, tk.gestor);
check('cp3', 'RPC dashboard_resumo como gestor', r.status === 200 && r.json?.totais?.pracas >= 3 && r.json?.por_dia?.length === 31, `${r.status} / ${JSON.stringify(r.json?.totais).slice(0, 90)}`);

r = await rest('vw_alerta_pendente?select=id', { token: tk.cidadao });
check('cp3', 'hardening: cidadão não lê vw_alerta_pendente', r.status === 200 && r.json.length === 0, `${r.status} / ${r.json?.length}`);
r = await rest('vw_ocorrencia_aberta?select=id', { token: tk.cidadao });
check('cp3', 'hardening: cidadão não vê anônimas em vw_ocorrencia_aberta', r.status === 200 && !r.json.some((o) => o.id === ocAnon?.id), `${r.status} / ${r.json?.length}`);
```

```bash
node database/scripts/e2e.mjs --md > /tmp/e2e.txt; tail -3 /tmp/e2e.txt     # esperado: 82/82 OK
```

Atualize `docs/checkpoint-2/evidencias/e2e-api.md` → copie para `docs/checkpoint-3/evidencias/e2e-api.md`
com a nova tabela. Commit, push, PR → revisora Ana.

## Passo 7 — Sexta: fechamento

1. Revisar e mergear os PRs pendentes (ordem: Davi → Santhiago → seu).
2. Rodar a limpeza dos `[E2E]` (Passo 2) **depois** do último e2e, para a demo começar limpa.
3. Conferir a URL da Vercel em aba anônima: lista de praças carrega.
4. `git tag -a checkpoint-3 -m "Checkpoint 3: MVP integrado" && git push --tags`.
5. Atualizar a linha do CP3 no README para 🟢 e a URL do deploy.

## Erros comuns

| Sintoma | Causa / solução |
|---------|-----------------|
| `ALTER VIEW ... security_invoker` dá erro de sintaxe | Postgres < 15. O Supabase é 15+; confira em Settings → Infrastructure. |
| Após o hardening, `vw_praca_resumo` some para anônimo | Você aplicou `security_invoker` nela também. Só as duas views do arquivo devem ter. `ALTER VIEW vw_praca_resumo RESET (security_invoker);` |
| Vercel: página branca | Variáveis `VITE_*` não definidas no projeto Vercel (o `createClient` lança erro). Settings → Environment Variables → Redeploy. |
| Vercel: 404 ao recarregar rota interna | Falta `vercel.json` na pasta `src/frontend`. |
| CI falha no job API em PR de fork | Esperado: forks não têm secrets. O job `front` é o que protege o merge. |
| Realtime não aparece na lista de Replication | Habilite em Project Settings → API → Realtime e rode o `DO` de novo. |
