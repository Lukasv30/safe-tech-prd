# Evidências — RPCs e Edge Function (Davi Mendes)

Testes executados em 12/11/2026 contra o projeto Supabase `safe-tech`, via REST (`curl`).

Cabeçalhos usados em todas as chamadas RPC:

```
apikey: <anon key>
Content-Profile: safetech
Content-Type: application/json
Authorization: Bearer <access_token>   # só nas chamadas logadas
```

Login (token de `gestor.demo@safetech.app` e `cidadao.demo@safetech.app`):

```bash
curl -s "$SUPABASE_URL/auth/v1/token?grant_type=password" \
  -H "apikey: $ANON" -H "Content-Type: application/json" \
  -d '{"email":"gestor.demo@safetech.app","password":"Senha@123"}'
```

Resultado: login OK para os dois usuários (gestor `08e61850-ea65-409b-9ce2-3d37843b3af7`, cidadão `8e9aa920-1740-429d-b282-0c0ed3b0cad8`).

> Observação: na primeira rodada o `gestor.demo` ainda estava com perfil `CIDADAO` e todas as RPCs de equipe
> foram bloqueadas (comportamento correto). Após rodar o UPDATE de `11_usuarios_demo.sql` o perfil passou a
> `GESTOR` e os testes abaixo foram refeitos.

---

## 1. consultar_protocolo (público, minúsculas)

```bash
curl -s -X POST "$SUPABASE_URL/rest/v1/rpc/consultar_protocolo" \
  -H "apikey: $ANON" -H "Content-Profile: safetech" -H "Content-Type: application/json" \
  -d '{"p_protocolo":"stc-2026-000001"}'
```

HTTP 200

```json
{
  "praca": "Praça do Derby", "status": "EM_ATENDIMENTO", "titulo": "Postes apagados perto do playground",
  "categoria": "Iluminação precária", "gravidade": "MEDIA", "protocolo": "STC-2026-000001",
  "ocorrida_em": "2026-11-09T12:55:49.692099+00:00", "resolvida_em": null,
  "historico": [
    {"de": null, "para": "ABERTA", "observacao": "Ocorrência registrada", "em": "2026-11-12T12:55:49.692099+00:00"},
    {"de": "ABERTA", "para": "EM_ATENDIMENTO", "observacao": null, "em": "2026-11-12T12:55:49.692099+00:00"}
  ]
}
```

## 2. registrar_ocorrencia (anônima, sem login)

```bash
curl -s -X POST "$SUPABASE_URL/rest/v1/rpc/registrar_ocorrencia" \
  -H "apikey: $ANON" -H "Content-Profile: safetech" -H "Content-Type: application/json" \
  -d '{"p_praca_id":"aaaaaaaa-0000-0000-0000-000000000001","p_categoria_id":3,"p_titulo":"Assalto","p_descricao":"Relato anônimo","p_anonima":true}'
```

HTTP 200

```json
[{"id":"67a090ed-2bd4-4967-af40-d8d557147ea8","protocolo":"STC-2026-000005","status":"ABERTA"}]
```

## 3. acionar_botao_panico (público)

```bash
curl -s -X POST "$SUPABASE_URL/rest/v1/rpc/acionar_botao_panico" \
  -H "apikey: $ANON" -H "Content-Profile: safetech" -H "Content-Type: application/json" \
  -d '{"p_equipamento_codigo":"BTN-DERBY-01"}'
```

HTTP 200

```json
[{"id":"0707e498-7eb0-4ced-abfc-4332ea309360","praca_id":"aaaaaaaa-0000-0000-0000-000000000001",
  "equipamento_id":"bbbbbbbb-0000-0000-0000-000000000003","origem":"BOTAO_PANICO","gravidade":"CRITICA",
  "status":"NOVO","mensagem":"Botão de pânico acionado em Totem central","criado_em":"2026-11-12T13:48:17.649451+00:00"}]
```

Notificação recebida pelo gestor (`GET /rest/v1/notificacao`, logado como gestor), HTTP 200:

```json
[{"titulo":"Botão de pânico acionado","mensagem":"Praça Praça do Derby: Botão de pânico acionado em Totem central",
  "alerta_id":"0707e498-7eb0-4ced-abfc-4332ea309360"}]
```

> O prefixo duplicado "Praça Praça" foi corrigido no SQL após o teste (a mensagem agora usa só o nome da praça).

## 4. atualizar_status_ocorrencia

Corpo: `{"p_ocorrencia_id":"67a090ed-2bd4-4967-af40-d8d557147ea8","p_status":"EM_ANALISE","p_observacao":"Triagem feita"}`

| Chamada | HTTP | Resposta |
|---|---|---|
| Sem token | 401 | `{"code":"42501","message":"Apenas agentes, gestores ou administradores podem alterar o status"}` |
| Token `cidadao.demo` | 403 | `{"code":"42501","message":"Apenas agentes, gestores ou administradores podem alterar o status"}` |
| Token `gestor.demo` | 200 | ocorrência com `"status":"EM_ANALISE"` |

Histórico gerado (`GET /rest/v1/historico_ocorrencia?ocorrencia_id=eq.67a090ed-...`), HTTP 200:

```json
[
  {"id":7,"status_anterior":null,"status_novo":"ABERTA","usuario_id":null,"observacao":"Ocorrência registrada"},
  {"id":8,"status_anterior":"ABERTA","status_novo":"EM_ANALISE","usuario_id":"08e61850-ea65-409b-9ce2-3d37843b3af7","observacao":"Triagem feita"}
]
```

## 5. atribuir_atendimento (gestor, `p_agente_id` omitido)

Corpo: `{"p_ocorrencia_id":"67a090ed-2bd4-4967-af40-d8d557147ea8"}`. HTTP 200:

```json
[{"id":"508bd96e-684c-4933-8b9a-0ca623b1f861","ocorrencia_id":"67a090ed-2bd4-4967-af40-d8d557147ea8",
  "agente_id":"08e61850-ea65-409b-9ce2-3d37843b3af7","atribuido_por":"08e61850-ea65-409b-9ce2-3d37843b3af7",
  "iniciado_em":"2026-11-12T13:47:39.283146+00:00","finalizado_em":null,"relato":null}]
```

Status da ocorrência depois: `[{"protocolo":"STC-2026-000005","status":"EM_ATENDIMENTO"}]`

## 6. reconhecer_alerta (gestor)

Corpo: `{"p_alerta_id":"0707e498-7eb0-4ced-abfc-4332ea309360"}`. HTTP 200:

```json
[{"id":"0707e498-7eb0-4ced-abfc-4332ea309360","status":"RECONHECIDO",
  "reconhecido_por":"08e61850-ea65-409b-9ce2-3d37843b3af7","reconhecido_em":"2026-11-12T13:48:31.12885+00:00","encerrado_em":null}]
```

## 7. finalizar_atendimento (gestor)

Corpo: `{"p_atendimento_id":"508bd96e-684c-4933-8b9a-0ca623b1f861","p_relato":"Atendimento concluido","p_resolver":true}`. HTTP 200:

```json
[{"id":"508bd96e-684c-4933-8b9a-0ca623b1f861","finalizado_em":"2026-11-12T13:48:31.614287+00:00","relato":"Atendimento concluido"}]
```

## 8. minhas_ocorrencias (contribuição própria)

| Chamada | HTTP | Resposta |
|---|---|---|
| Sem token | 401 | `{"code":"42501","message":"É necessário estar autenticado para listar suas ocorrências"}` |
| Token `cidadao.demo` | 200 | `[]` (o cidadão demo ainda não registrou ocorrências identificadas) |

---

## Checklist

- [x] Sem token, `atualizar_status_ocorrencia` retorna "Apenas agentes, gestores..."
- [x] Com `cidadao.demo`, o mesmo erro
- [x] Com `gestor.demo`, status muda e `historico_ocorrencia` ganha linha com `usuario_id` do gestor
- [x] `atribuir_atendimento` coloca a ocorrência em `EM_ATENDIMENTO`
- [x] `acionar_botao_panico` cria alerta `CRITICA` e uma notificação por AGENTE/GESTOR
- [x] `consultar_protocolo` funciona sem login e aceita minúsculas

## Edge Function `evento-equipamento`

_Pendente: deploy e teste._

```bash
supabase secrets set DEVICE_SECRET=<segredo>
supabase functions deploy evento-equipamento --no-verify-jwt

curl -s -X POST "$SUPABASE_URL/functions/v1/evento-equipamento" \
  -H "x-device-secret: <segredo>" -H "Content-Type: application/json" \
  -d '{"codigo":"CAM-DERBY-01","evento":"SEM_SINAL"}'
```
