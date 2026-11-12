# API SafeTech — Contrato (Checkpoint 2)

**Base URL:** `https://<ref>.supabase.co`  
**Schema:** `safetech`  

**Cabeçalhos obrigatórios:**
* `apikey`: Chave pública anônima (`anon key`).
* `Authorization`: Bearer `<jwt>` (necessário para rotas autenticadas).
* `Accept-Profile: safetech` (em requisições GET).
* `Content-Profile: safetech` (em requisições POST, PATCH, RPC).

---

## Tabela de Endpoints

| # | Endpoint | Método | Acesso | Descrição |
|---|---|---|---|---|
| 1 | `/auth/v1/signup` | POST | Público | Cadastro de novos usuários no sistema. |
| 2 | `/auth/v1/token?grant_type=password` | POST | Público | Autenticação (Login) para obtenção do token JWT. |
| 3 | `/auth/v1/user` | GET | Logado | Retorna os dados do usuário autenticado no momento. |
| 4 | `/rest/v1/praca` | GET | Público | Lista todas as praças cadastradas em ordem alfabética. |
| 5 | `/rest/v1/vw_praca_resumo` | GET | Público | Resumo em formato de dashboard por praça (ocorrências abertas, alertas, nota média). |
| 6 | `/rest/v1/categoria_ocorrencia` | GET | Público | Lista as categorias de ocorrências ativas. |
| 7 | `/rest/v1/ocorrencia` | GET | Público (Bloqueado) | Consulta de ocorrências (exige autenticação, retorna erro 401 se anônimo). |
| 8 | `/rest/v1/usuario` | GET | Logado | Retorna o perfil detalhado do usuário atual. |
| 9 | `/rest/v1/vw_ocorrencia_aberta` | GET | Logado | Lista todas as ocorrências que estão abertas ordenadas por data. |
| 10 | `/rest/v1/historico_ocorrencia` | GET | Logado | Histórico de alterações de uma ocorrência específica. |
| 11 | `/rest/v1/equipamento` | GET | Logado | Lista os equipamentos vinculados a uma praça. |
| 12 | `/rest/v1/vw_alerta_pendente` | GET | Equipe | Lista os alertas que estão pendentes de atendimento. |
| 13 | `/rest/v1/atendimento` | GET | Equipe | Lista os atendimentos que ainda não foram finalizados. |
| 14 | `/rest/v1/ronda` | GET | Equipe | Lista as rondas agendadas no sistema. |
| 15 | `/rest/v1/avaliacao_praca` | POST | Logado | Envia uma avaliação de nota e comentário para uma praça. |
| 16 | `/rest/v1/notificacao` | GET | Logado | Lista as notificações não lidas do usuário. |
| 17 | `/rest/v1/notificacao?id=eq.<id>` | PATCH | Logado | Marca uma notificação específica como lida. |
| 18 | `/rest/v1/rpc/consultar_protocolo` | POST | Público | Consulta o status de uma ocorrência através do número de protocolo. |
| 19 | `/rest/v1/rpc/registrar_ocorrencia` | POST | Público | Registra uma nova ocorrência de forma anônima. |
| 20 | `/rest/v1/rpc/registrar_ocorrencia` | POST | Logado | Registra uma nova ocorrência vinculada ao usuário logado. |
| 21 | `/rest/v1/rpc/atualizar_status_ocorrencia` | POST | Equipe | Atualiza o status de uma ocorrência em andamento. |
| 22 | `/rest/v1/rpc/atribuir_atendimento` | POST | Equipe | Atribui um responsável para o atendimento de uma ocorrência. |
| 23 | `/rest/v1/rpc/finalizar_atendimento` | POST | Equipe | Conclui e encerra o atendimento de uma ocorrência. |
| 24 | `/rest/v1/rpc/acionar_botao_panico` | POST | Público | Aciona um alerta de pânico em um equipamento físico. |
| 25 | `/rest/v1/rpc/reconhecer_alerta` | POST | Equipe | Reconhece formalmente um alerta disparado no sistema. |
| 26 | `/functions/v1/evento-equipamento` | POST | Edge Function | Recebe eventos automatizados vindos de equipamentos IoT externos. |