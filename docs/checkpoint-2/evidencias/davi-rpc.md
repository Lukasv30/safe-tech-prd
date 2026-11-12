# Evidências — RPCs e Edge Function (Davi Mendes)

> Preencher colando as respostas reais após executar cada comando.
> Variáveis: `SUPABASE_URL`, `ANON`, `TOKEN` (access_token do gestor.demo).

## Login (gestor.demo)

```bash
curl -s "$SUPABASE_URL/auth/v1/token?grant_type=password" \
  -H "apikey: $ANON" -H "Content-Type: application/json" \
  -d '{"email":"gestor.demo@safetech.app","password":"Senha@123"}'
```
Resposta: _(colar)_

## RPCs

Todas com `-H "apikey: $ANON" -H "Content-Profile: safetech" -H "Content-Type: application/json"`
(as que exigem login também com `-H "Authorization: Bearer $TOKEN"`).

| RPC | Corpo | Resposta |
|---|---|---|
| consultar_protocolo | `{"p_protocolo":"STC-2026-000001"}` | _(colar)_ |
| consultar_protocolo (minúsculas) | `{"p_protocolo":"stc-2026-000001"}` | _(colar)_ |
| registrar_ocorrencia (anônima) | `{"p_praca_id":"aaaaaaaa-0000-0000-0000-000000000001","p_categoria_id":3,"p_titulo":"Assalto","p_descricao":"Relato anônimo","p_anonima":true}` | _(colar)_ |
| acionar_botao_panico | `{"p_equipamento_codigo":"BTN-DERBY-01"}` | _(colar)_ |
| atualizar_status_ocorrencia (sem token) | `{"p_ocorrencia_id":"<id>","p_status":"EM_ANALISE"}` | _(colar erro)_ |
| atualizar_status_ocorrencia (cidadao.demo) | idem | _(colar erro)_ |
| atualizar_status_ocorrencia (gestor.demo) | `{"p_ocorrencia_id":"<id>","p_status":"EM_ANALISE","p_observacao":"Triagem feita"}` | _(colar)_ |
| atribuir_atendimento | `{"p_ocorrencia_id":"<id>"}` | _(colar)_ |
| reconhecer_alerta | `{"p_alerta_id":"<id do alerta>"}` | _(colar)_ |
| minhas_ocorrencias | `{}` | _(colar)_ |

## Checklist

- [ ] Sem token, `atualizar_status_ocorrencia` retorna "Apenas agentes, gestores..."
- [ ] Com `cidadao.demo`, o mesmo erro
- [ ] Com `gestor.demo`, status muda e `historico_ocorrencia` ganha linha com `usuario_id` do gestor
- [ ] `atribuir_atendimento` coloca a ocorrência em `EM_ATENDIMENTO`
- [ ] `acionar_botao_panico` cria alerta `CRITICA` e uma notificação por AGENTE/GESTOR
- [ ] `consultar_protocolo` funciona sem login e aceita minúsculas

## Edge Function `evento-equipamento`

```bash
supabase secrets set DEVICE_SECRET=<segredo>
supabase functions deploy evento-equipamento --no-verify-jwt

curl -s -X POST "$SUPABASE_URL/functions/v1/evento-equipamento" \
  -H "x-device-secret: <segredo>" -H "Content-Type: application/json" \
  -d '{"codigo":"CAM-DERBY-01","evento":"SEM_SINAL"}'
```
Resposta (201 esperado): _(colar)_

```bash
curl -s -X POST "$SUPABASE_URL/functions/v1/evento-equipamento" \
  -H "x-device-secret: <segredo>" -H "Content-Type: application/json" \
  -d '{"codigo":"CAM-DERBY-01","evento":"NORMALIZADO"}'
```
Resposta: _(colar; equipamento volta a OPERANTE)_

- [ ] Alerta aparece em `vw_alerta_pendente`
- [ ] `CAM-DERBY-01` fica `INOPERANTE` e depois `OPERANTE`
- [ ] Gestores recebem notificação
