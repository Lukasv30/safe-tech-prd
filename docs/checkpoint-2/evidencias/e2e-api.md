# Evidências — teste ponta a ponta da API (Checkpoint 2)

Executado em 16/11/2026 com `node database/scripts/e2e.mjs --md` contra o projeto Supabase do SafeTech
(REST/PostgREST no schema `safetech`, RPCs, Supabase Auth, RLS, Storage e Edge Function).

**== Resultado: 63/65 OK, 2 FALHAS**

Cobertura: leitura pública sem login; bloqueios do RLS por perfil; login dos 4 usuários demo
(`cidadao`, `agente`, `gestor`, `admin` `.demo@safetech.app`); as 8 RPCs (`registrar_ocorrencia`,
`consultar_protocolo`, `atualizar_status_ocorrencia`, `atribuir_atendimento`, `finalizar_atendimento`,
`reconhecer_alerta`, `acionar_botao_panico`, `minhas_ocorrencias`); triggers (protocolo, histórico,
EM_ATENDIMENTO, resolvida_em); views; bucket `anexos`; Edge Function `evento-equipamento`.

## Pendências encontradas

| Item | Causa | Correção |
|------|-------|----------|
| Leitura pública do anexo retorna "Bucket not found" | Bucket `anexos` criado sem *Public bucket* | Rodar `database/supabase/04_storage.sql` atualizado (faz `UPDATE storage.buckets SET public = TRUE`) ou marcar no painel |
| Dono não consegue apagar o próprio anexo | Política usava `owner` (coluna obsoleta, fica vazia); o Storage atual preenche `owner_id` | Mesmo arquivo: política recriada com `owner_id = auth.uid()::text` |
| Testes de sucesso da Edge Function pulados | `DEVICE_SECRET` não está no `.env` de quem rodou | Rodar com `DEVICE_SECRET=<segredo> node database/scripts/e2e.mjs` (evidências manuais em `davi-rpc.md`) |

## Como reproduzir

```bash
cp .env.example .env     # SUPABASE_URL e SUPABASE_ANON_KEY
node database/scripts/e2e.mjs          # saída em texto; código de saída 1 se houver falha
node database/scripts/e2e.mjs --md     # adiciona a tabela abaixo
```

O script cria dados prefixados com `[E2E]` (duas ocorrências e um alerta de botão de pânico por execução) e
remove o que consegue (avaliação, praça temporária, arquivo do bucket).

## Resultado por teste

| # | Grupo | Teste | Resultado | Detalhe |
|---|-------|-------|-----------|---------|
| 1 | anon | GET praca (leitura pública) | ✅ | 200 / 3 praças |
| 2 | anon | GET categoria_ocorrencia | ✅ | 200 / 9 categorias |
| 3 | anon | GET vw_praca_resumo (dashboard) | ✅ | 200 / {"nome":"Praça do Derby","ocorrencias_abertas":10,"alertas_novos":5} |
| 4 | anon | GET equipamento bloqueado sem login | ✅ | 401 |
| 5 | anon | GET ocorrencia bloqueado sem login | ✅ | 401 |
| 6 | anon | GET vw_alerta_pendente bloqueado sem login | ✅ | 401 |
| 7 | anon | RPC consultar_protocolo (seed) | ✅ | 200 / EM_ATENDIMENTO |
| 8 | anon | RPC consultar_protocolo inexistente → null | ✅ | 200 / null |
| 9 | anon | RPC registrar_ocorrencia anônima | ✅ | 200 / STC-2026-000015 |
| 10 | anon | RPC registrar_ocorrencia identificada sem login → 42501 | ✅ | 401 / É necessário estar autenticado para registrar uma ocorrência identificada |
| 11 | anon | RPC acionar_botao_panico (BTN-DERBY-01) | ✅ | 200 / NOVO |
| 12 | anon | RPC acionar_botao_panico em câmera → erro | ✅ | 400 / Equipamento CAM-DERBY-01 não é um botão de pânico operante |
| 13 | anon | RPC minhas_ocorrencias sem login → bloqueado | ✅ | 401 / É necessário estar autenticado para listar suas ocorrências |
| 14 | anon | RPC atualizar_status_ocorrencia sem login → bloqueado | ✅ | 401 / Apenas agentes, gestores ou administradores podem alterar o status |
| 15 | auth | login cidadao.demo@safetech.app | ✅ | token ok |
| 16 | auth | login agente.demo@safetech.app | ✅ | token ok |
| 17 | auth | login gestor.demo@safetech.app | ✅ | token ok |
| 18 | auth | login admin.demo@safetech.app | ✅ | token ok |
| 19 | auth | perfil_atual() de cidadao = CIDADAO | ✅ | 200 / "CIDADAO" |
| 20 | auth | perfil_atual() de agente = AGENTE | ✅ | 200 / "AGENTE" |
| 21 | auth | perfil_atual() de gestor = GESTOR | ✅ | 200 / "GESTOR" |
| 22 | auth | perfil_atual() de admin = ADMIN | ✅ | 200 / "ADMIN" |
| 23 | auth | trigger Auth → usuario: cidadão vê só o próprio perfil | ✅ | 200 / {"id":"8e9aa920-1740-429d-b282-0c0ed3b0cad8","nome":"Cidad�o Demo","email":"cidadao. |
| 24 | auth | gestor vê todos os usuários | ✅ | 200 / 10 usuários |
| 25 | cidadao | RPC registrar_ocorrencia identificada | ✅ | 200 / STC-2026-000016 |
| 26 | cidadao | RPC minhas_ocorrencias contém a recém-criada | ✅ | 200 / 3 ocorrências |
| 27 | cidadao | RLS: GET ocorrencia mostra só não anônimas + as próprias (nenhuma anônima vaza) | ✅ | 200 / 6 visíveis |
| 28 | cidadao | trigger histórico: 1 registro ABERTA na criação | ✅ | 200 / [{"status_novo":"ABERTA"}] |
| 29 | cidadao | RPC consultar_protocolo do próprio registro | ✅ | 200 / ABERTA |
| 30 | cidadao | RPC atualizar_status_ocorrencia → bloqueado (42501) | ✅ | 403 / Apenas agentes, gestores ou administradores podem alterar o status |
| 31 | cidadao | RPC atribuir_atendimento → bloqueado | ✅ | 403 / Apenas a equipe pode atribuir atendimentos |
| 32 | cidadao | RPC reconhecer_alerta → bloqueado | ✅ | 403 / Apenas a equipe pode tratar alertas |
| 33 | cidadao | RLS: GET alerta vazio | ✅ | 200 / 0 |
| 34 | cidadao | GET equipamento logado lista | ✅ | 200 / 7 equipamentos |
| 35 | cidadao | RLS: PATCH praca ignorado (0 linhas) | ✅ | 200 / 0 linhas |
| 36 | cidadao | POST avaliacao_praca como eu mesmo | ✅ | 201 / bda142fe-11d3-42fd-bdb4-efaf49f1e9f4 |
| 37 | cidadao | RLS: POST avaliacao_praca como outro usuário → bloqueado | ✅ | 403 / new row violates row-level security policy for table "avaliacao_praca" |
| 38 | cidadao | DELETE da própria avaliação (limpeza) | ✅ | 200 |
| 39 | storage | upload no bucket anexos logado | ✅ | 200 / {"Key":"anexos/e2e/1794829323315.txt","Id":"a77761a4-865d-4acb-a1e7-0ba771d3c5bc","v |
| 40 | storage | leitura pública do arquivo | ❌ | 400 |
| 41 | storage | upload sem login → bloqueado | ✅ | 400 / headers must have required property 'authorization' |
| 42 | storage | DELETE por outro usuário → bloqueado | ✅ | 400 |
| 43 | storage | DELETE pelo dono (limpeza) | ❌ | 400 / Access denied |
| 44 | agente | RLS: GET alerta lista (inclui o do botão de pânico) | ✅ | 200 / 10 alertas |
| 45 | agente | GET vw_alerta_pendente | ✅ | 200 / 6 pendentes |
| 46 | agente | notificação do botão de pânico recebida | ✅ | 200 / {"titulo":"Botão de pânico acionado"} |
| 47 | agente | RPC atribuir_atendimento (assume a ocorrência do cidadão) | ✅ | 200 / d7441fa0-c866-4ee0-b7af-4d6e6ad4c471 |
| 48 | agente | trigger: ocorrência foi para EM_ATENDIMENTO | ✅ | 200 / EM_ATENDIMENTO |
| 49 | agente | RPC finalizar_atendimento | ✅ | 200 / 2026-11-16T11:42:08.351625+00:00 |
| 50 | agente | ocorrência RESOLVIDA com resolvida_em preenchido | ✅ | 200 / {"status":"RESOLVIDA","resolvida_em":"2026-11-16T11:42:08.351625+00:00"} |
| 51 | agente | histórico: ABERTA → EM_ATENDIMENTO → RESOLVIDA | ✅ | 200 / ABERTA>EM_ATENDIMENTO>RESOLVIDA |
| 52 | agente | RPC finalizar_atendimento repetido → erro | ✅ | 500 / Atendimento d7441fa0-c866-4ee0-b7af-4d6e6ad4c471 não encontrado ou já finalizado |
| 53 | agente | RPC reconhecer_alerta → RECONHECIDO | ✅ | 200 / RECONHECIDO |
| 54 | agente | RPC reconhecer_alerta com NOVO → erro | ✅ | 400 / Status inválido para reconhecimento |
| 55 | agente | RLS: POST praca por agente → bloqueado | ✅ | 403 / new row violates row-level security policy for table "praca" |
| 56 | gestor | RPC atualizar_status_ocorrencia (anônima → EM_ANALISE) | ✅ | 200 / EM_ANALISE |
| 57 | gestor | RPC atualizar_status_ocorrencia inexistente → P0002 | ✅ | 500 / Ocorrência 00000000-0000-0000-0000-000000000000 não encontrada |
| 58 | gestor | RPC reconhecer_alerta → ENCERRADO com encerrado_em | ✅ | 200 / ENCERRADO |
| 59 | gestor | POST praca por gestor | ✅ | 201 / a17f9dc7-6ca0-4add-9991-1dba6b34d3fe |
| 60 | gestor | PATCH praca por gestor | ✅ | 200 |
| 61 | admin | DELETE praca por admin (limpeza) | ✅ | 200 / [{"id":"a17f9dc7-6ca0-4add-9991-1dba6b34d3fe","nome":"[E2E] Praça temporária","descr |
| 62 | gestor | RLS: gestor vê ocorrências anônimas | ✅ | 200 / 16 ocorrências |
| 63 | gestor | GET vw_ocorrencia_aberta | ✅ | 200 / 11 abertas |
| 64 | edge | POST sem x-device-secret → 401 | ✅ | 401 / Não autorizado |
| 65 | edge | GET → 405 | ✅ | 405 / Use POST |
