# Roteiro — QA / Testes (5º membro, se houver)

**Objetivo:** provar que os endpoints fazem o que prometem e que as permissões (RLS) estão corretas.
Se a equipe ficar com 4 pessoas, a Ana executa este roteiro junto com o dela.
**Branch:** `docs/cp2-qa`

## Passo 1 — Preparar

1. Instale a extensão **REST Client** no VS Code e abra `docs/api/safetech.http` (criado pela Ana).
2. Peça ao Lucas as credenciais dos 4 usuários de teste (`cidadao`, `agente`, `gestor`, `admin` `.demo@safetech.app`).

## Passo 2 — Matriz de permissões

Crie `docs/checkpoint-2/testes/matriz-permissoes.md` e preencha executando cada requisição com cada usuário.
Marque ✅ (funcionou), ⛔ (bloqueado como esperado) ou ❌ (comportamento errado → abra issue).

| Requisição | Anônimo | Cidadão | Agente | Gestor | Esperado |
|------------|---------|---------|--------|--------|----------|
| GET praca | | | | | todos ✅ |
| GET vw_praca_resumo | | | | | todos ✅ |
| GET ocorrencia | | | | | anônimo ⛔; cidadão só não-anônimas + suas; equipe todas |
| GET usuario | | | | | anônimo ⛔; cidadão só o próprio; equipe todos |
| GET vw_alerta_pendente | | | | | anônimo ⛔; cidadão 0 linhas; equipe ✅ |
| GET atendimento | | | | | cidadão 0 linhas; equipe ✅ |
| POST avaliacao_praca (próprio id) | | | | | logados ✅ |
| POST avaliacao_praca (id de outro) | | | | | todos ⛔ |
| PATCH praca | | | | | só gestor/admin ✅ (cidadão: 0 linhas) |
| rpc consultar_protocolo | | | | | todos ✅ |
| rpc registrar_ocorrencia anônima | | | | | todos ✅ |
| rpc registrar_ocorrencia identificada | | | | | anônimo ⛔; logados ✅ |
| rpc atualizar_status_ocorrencia | | | | | cidadão ⛔; equipe ✅ |
| rpc atribuir_atendimento | | | | | cidadão ⛔; equipe ✅ |
| rpc finalizar_atendimento (2ª vez) | | | | | ⛔ "já finalizado" |
| rpc reconhecer_alerta | | | | | cidadão ⛔; equipe ✅ |
| rpc acionar_botao_panico (CAM-...) | | | | | ⛔ "não é um botão de pânico" |
| Edge Function sem x-device-secret | | | | | 401 |

## Passo 3 — Casos funcionais

Crie `docs/checkpoint-2/testes/casos-de-teste.md` com, no mínimo:

| ID | Cenário | Passos | Resultado esperado |
|----|---------|--------|--------------------|
| CT01 | Cadastro cria perfil | signup → SELECT usuario | linha com perfil CIDADAO |
| CT02 | Protocolo gerado | registrar_ocorrencia | formato `STC-2026-NNNNNN` único |
| CT03 | Histórico automático | registrar → atualizar status → GET historico | 2 linhas, com usuario_id do gestor na 2ª |
| CT04 | Atribuição muda status | atribuir_atendimento | ocorrência em EM_ATENDIMENTO |
| CT05 | Resolução preenche data | finalizar_atendimento com p_resolver=true | status RESOLVIDA e resolvida_em preenchido |
| CT06 | Pânico notifica equipe | acionar_botao_panico → GET notificacao como gestor | notificação "Botão de pânico acionado" |
| CT07 | Equipamento sem sinal | Edge Function SEM_SINAL → GET equipamento | status INOPERANTE + alerta MEDIA |
| CT08 | Normalização | Edge Function NORMALIZADO | status OPERANTE, sem alerta novo |
| CT09 | Anonimato | ocorrência anônima → vw_ocorrencia_aberta | autor = "Anônimo" |
| CT10 | Resumo atualiza | registrar ocorrência → vw_praca_resumo | ocorrencias_abertas +1 |

Para cada caso, cole a resposta (JSON) como evidência. Bugs viram issues no quadro com label `bug` e o responsável da área.

## Passo 4 — Pull Request

Inclua os dois arquivos de `docs/checkpoint-2/testes/`. No checkpoint, apresente a matriz: ela mostra que a
persistência e as permissões estão corretas (critério "Estrutura e Persistência de Dados", 2,0 pts).
