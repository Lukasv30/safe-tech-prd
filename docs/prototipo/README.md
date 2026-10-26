# Protótipo — SafeTech

**Figma Make:** https://www.figma.com/make/ILamNGNr7s2SHJDX4IiLkn/SafeTech-%E2%80%94-Seguran%C3%A7a-em-Pra%C3%A7as-P%C3%BAblicas

## Mapa de telas

Preencher conforme o protótipo, salvando as capturas em [`telas/`](telas/).

| Tela | Perfil | Entidades envolvidas | Captura |
|------|--------|----------------------|---------|
| Login / Cadastro | Todos | usuario | `telas/login.png` |
| Mapa / Lista de praças | Todos | praca, vw_praca_resumo | `telas/mapa.png` |
| Detalhe da praça | Todos | praca, equipamento, avaliacao_praca, ocorrencia | `telas/praca.png` |
| Registrar ocorrência | Cidadão, Agente | ocorrencia, categoria_ocorrencia, anexo_ocorrencia | `telas/nova-ocorrencia.png` |
| Minhas ocorrências / Protocolo | Cidadão | ocorrencia, historico_ocorrencia | `telas/minhas-ocorrencias.png` |
| Painel de ocorrências | Agente, Gestor | vw_ocorrencia_aberta, atendimento | `telas/painel-ocorrencias.png` |
| Alertas em tempo real | Agente, Gestor | alerta, vw_alerta_pendente | `telas/alertas.png` |
| Rondas | Agente, Gestor | ronda | `telas/rondas.png` |
| Dashboard do gestor | Gestor, Admin | vw_praca_resumo | `telas/dashboard.png` |
| Administração (praças, equipamentos, usuários) | Admin | praca, equipamento, usuario | `telas/admin.png` |

## Como contribuir

1. Exporte a tela do Figma Make como PNG e salve em `telas/` com o nome indicado acima.
2. Se a tela usar um campo que não existe no modelo, abra uma issue ou PR ajustando
   [`docs/modelagem/modelo-logico.md`](../modelagem/modelo-logico.md) e a DDL correspondente.
