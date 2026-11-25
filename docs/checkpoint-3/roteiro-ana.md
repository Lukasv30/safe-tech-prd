# Roteiro — Ana Carolina (Product Manager) · Checkpoint 3

**Entrega:** gestão do checkpoint (issues, quadro, acompanhamento), **matriz de aderência protótipo × MVP** com
capturas, `docs/api/endpoints.md` v2, `docs/arquitetura/arquitetura.md` v2, **manual do usuário**, roteiro da
apresentação do CP3 e esboço do pitch da AV2. Se não houver 5º membro, você também executa o
[roteiro-qa.md](roteiro-qa.md) na quinta.

**Depende de:** nada para começar. Para as capturas das telas novas, espere os PRs de quinta (ou use a URL de
preview que a Vercel gera em cada PR).

## Passo 1 — Issues e quadro (manhã de quarta)

Crie no GitHub Projects uma view "Checkpoint 3" e as issues abaixo (etiquetas `cp3` + área). Cada uma com o link
para o passo do roteiro correspondente.

| # | Título | Dono | Etiqueta |
|---|--------|------|----------|
| CP3-01 | Front: contexto de auth com perfil, layout e rotas protegidas | Santhiago | front |
| CP3-02 | Front: detalhe da praça com avaliação | Santhiago | front |
| CP3-03 | Front: anexo de foto/vídeo na nova ocorrência | Santhiago | front |
| CP3-04 | Front: minhas ocorrências e protocolo com linha do tempo | Santhiago | front |
| CP3-05 | DB: RPCs detalhe_praca, avaliar_praca, registrar_anexo, dashboard_resumo | Davi | back |
| CP3-06 | Front: painel de ocorrências da equipe | Davi | front |
| CP3-07 | Front: alertas em tempo real | Davi | front |
| CP3-08 | DB: hardening das views (security_invoker), Realtime, índice de avaliação | Lucas | back |
| CP3-09 | DB: seed de demonstração | Lucas | back |
| CP3-10 | Deploy na Vercel + vercel.json | Lucas | infra |
| CP3-11 | CI no GitHub Actions (lint, build, e2e) | Lucas | infra |
| CP3-12 | Front: dashboard do gestor | Lucas | front |
| CP3-13 | e2e ampliado com os casos do CP3 | Lucas | test |
| CP3-14 | Docs: matriz de aderência protótipo × MVP com capturas | Ana | docs |
| CP3-15 | Docs: endpoints.md v2 e arquitetura.md v2 | Ana | docs |
| CP3-16 | Docs: manual do usuário | Ana | docs |
| CP3-17 | QA: plano de testes CT11–CT30 e execução | QA/Ana | test |
| CP3-18 | Apresentação do CP3 e esboço do pitch da AV2 | Ana | docs |

Colunas: A fazer → Em andamento → Em revisão (PR aberto) → Pronto. Às 18h de cada dia, poste no grupo um resumo
de 3 linhas: o que entrou em `main`, o que está em PR, o que está travado.

## Passo 2 — Matriz de aderência protótipo × MVP

O critério "Funcionalidade e Aderência" vale **3,0 pontos** e é julgado contra o protótipo da AV1. Este documento
é a prova. Edite `docs/prototipo/README.md` substituindo a tabela "Mapa de telas" por:

```markdown
## Aderência protótipo (AV1) × MVP (Checkpoint 3)

| Tela do protótipo | Rota no MVP | Perfil | O que funciona | Fora do MVP | Captura |
|-------------------|-------------|--------|----------------|-------------|---------|
| Login / Cadastro | `/login`, `/cadastro` | todos | Cadastro cria conta no Auth e perfil em `usuario`; login redireciona por perfil | Login social | `telas/mvp-login.png` |
| Lista de praças | `/pracas` | público | Cartões com ocorrências abertas, alertas e nota; busca por nome/bairro | Mapa interativo (link para OpenStreetMap no detalhe) | `telas/mvp-pracas.png` |
| Detalhe da praça | `/pracas/:id` | público | Endereço, horário, indicadores, equipamentos e status, ocorrências abertas, avaliações com estrelas | — | `telas/mvp-praca.png` |
| Registrar ocorrência | `/ocorrencias/nova` | logado | Praça, categoria, gravidade, anônima, até 3 fotos/vídeos; protocolo gerado | Geolocalização automática | `telas/mvp-nova-ocorrencia.png` |
| Minhas ocorrências / Protocolo | `/minhas-ocorrencias`, `/protocolo` | cidadão / público | Lista com status e anexos; linha do tempo pelo protocolo sem login | Notificações push | `telas/mvp-protocolo.png` |
| Painel de ocorrências | `/painel` | equipe | Fila por gravidade, filtros, histórico, assumir, em análise, finalizar, cancelar | Atribuir a outro agente pela tela (RPC existe) | `telas/mvp-painel.png` |
| Alertas em tempo real | `/alertas` | equipe | Pendentes chegam ao vivo (Realtime); reconhecer, encerrar, falso positivo; histórico | Som/notificação do navegador | `telas/mvp-alertas.png` |
| Rondas | — | — | — | Toda a tela (tabela `ronda` e RLS existem) | — |
| Dashboard do gestor | `/dashboard` | gestor/admin | 8 indicadores, série por dia, por categoria/status/gravidade, ranking de praças, alertas pendentes | Exportar relatório | `telas/mvp-dashboard.png` |
| Administração | — | — | Gestor cria/edita praça via API (RLS); demais via SQL | Toda a tela | — |
```

Capturas: na quinta à tarde, logue em cada perfil na URL da Vercel, tire um print por linha (janela ~1280 px) e
salve em `docs/prototipo/telas/` com os nomes acima. Se tiver os prints do Figma, coloque lado a lado
(`telas/figma-<tela>.png`) — é o argumento visual mais forte da aderência.

## Passo 3 — `docs/api/endpoints.md` v2

Acrescente ao contrato as 4 RPCs novas e as mudanças de segurança. Modelo de linha (mesmo formato do CP2):

```markdown
### RPC `detalhe_praca`
`POST /rest/v1/rpc/detalhe_praca` · **Acesso:** público · **Dono:** Davi
Corpo: `{"p_praca_id": "<uuid>"}` → JSON `{praca, resumo, equipamentos[], ocorrencias_abertas[], avaliacoes[]}` ou `null`.
Regras: nunca retorna autor de ocorrência; avaliador aparece só pelo primeiro nome; `minha=true` marca a avaliação do usuário logado.

### RPC `avaliar_praca`
`POST /rest/v1/rpc/avaliar_praca` · **Acesso:** logado · **Dono:** Davi
Corpo: `{"p_praca_id","p_nota" (1–5),"p_comentario"?}` → linha de `avaliacao_praca`. Uma por usuário/praça: repetir atualiza. Erros: 401 sem login; 400 nota fora de 1–5.

### RPC `registrar_anexo`
`POST /rest/v1/rpc/registrar_anexo` · **Acesso:** autor da ocorrência ou equipe · **Dono:** Davi
Corpo: `{"p_ocorrencia_id","p_url","p_nome_arquivo"?,"p_tamanho_bytes"?,"p_tipo"? (IMAGEM|VIDEO|AUDIO|DOCUMENTO)}` → linha de `anexo_ocorrencia`. O arquivo é enviado antes ao Storage (`POST /storage/v1/object/anexos/<ocorrencia_id>/<arquivo>`).

### RPC `dashboard_resumo`
`POST /rest/v1/rpc/dashboard_resumo` · **Acesso:** GESTOR/ADMIN · **Dono:** Davi
Corpo: `{"p_dias": 30}` → `{periodo_dias, totais{...}, por_status[], por_categoria[], por_gravidade[], por_dia[], por_praca[], alertas_recentes[]}`.

### Realtime
Canal `postgres_changes` em `schema: safetech, table: alerta` (e `ocorrencia`). Respeita o RLS: cidadão não recebe eventos de alerta.

### Mudanças de segurança (CP3)
- `vw_ocorrencia_aberta` e `vw_alerta_pendente` com `security_invoker`: respeitam o RLS do usuário (antes, qualquer logado lia alertas pela view).
- Índice único `avaliacao_praca(praca_id, usuario_id)`.
- Política `anexo_delete`: dono ou equipe.
```

Adicione na coleção `docs/api/safetech.http` as 4 requisições (copie os `curl` do roteiro do Davi).

## Passo 4 — `docs/arquitetura/arquitetura.md` v2 (quinta)

Seções a acrescentar ou atualizar (mantenha o que já existe do CP2):

1. **Visão geral** — trocar "endpoints" por "MVP integrado": fluxo cidadão → equipe → gestor em 1 parágrafo.
2. **Arquitetura** — colar o diagrama Mermaid do [README.md](README.md) deste checkpoint; explicar Vercel
   (front estático + CDN), Realtime (websocket), Storage (bucket público com upload autenticado).
3. **Front-end** — estrutura de pastas (`contexts`, `components`, `api`, `pages`), `AuthContext` com perfil,
   `RotaProtegida`, convenção "uma função por endpoint em `api/*.ts`".
4. **Segurança** — tabela perfil × recurso (pegue do roteiro de QA), `security_invoker`, anonimato, chaves fora
   do código, CI sem segredos em forks.
5. **Qualidade** — CI (lint, build, e2e), 82 testes de API, PGlite para validar SQL antes de aplicar, PR com
   revisão cruzada.
6. **Decisões (ADR curto)** — por que Supabase, por que RPC em vez de back-end próprio, por que gráficos em CSS
   (sem dependência), por que Vercel.
7. **Limitações e próximos passos** — rondas, administração, geolocalização, notificações, mapa.

## Passo 5 — Manual do usuário

Crie `docs/manual-do-usuario.md`, 1 página por perfil, com a URL da Vercel e os logins de demonstração:

```markdown
# SafeTech — Manual do usuário

Acesse: <URL da Vercel>

## Contas de demonstração
| Perfil | E-mail | Senha |
|--------|--------|-------|
| Cidadão | cidadao.demo@safetech.app | Senha@123 |
| Agente | agente.demo@safetech.app | Senha@123 |
| Gestor | gestor.demo@safetech.app | Senha@123 |

## Cidadão
1. **Praças**: veja a situação de cada praça. Clique para ver detalhes, equipamentos e avaliações.
2. **Registrar ocorrência**: escolha praça e categoria, descreva, anexe fotos. Guarde o protocolo.
3. **Acompanhar**: em *Protocolo* (sem login) ou *Minhas ocorrências*.
4. **Avaliar**: no detalhe da praça, dê uma nota de 1 a 5 para a sensação de segurança.

## Agente
1. **Painel**: fila de ocorrências por gravidade. *Tratar* → *Assumir atendimento*.
2. Ao concluir, escreva o relato e *Finalizar e resolver*. O cidadão vê isso na linha do tempo.
3. **Alertas**: botões de pânico e sensores aparecem em tempo real. *Reconhecer* avisa a equipe; *Encerrar* fecha.

## Gestor
1. **Dashboard**: indicadores, ocorrências por dia/categoria/status, ranking de praças.
2. Tem tudo que o agente tem. Pode também mudar status e cancelar ocorrências no Painel.
```

## Passo 6 — Apresentação do CP3 (sexta) e pitch da AV2

Roteiro de 10 min para sexta (quem fala em cada parte):

| Min | Quem | O quê |
|-----|------|-------|
| 0–1 | Ana | Problema, o que era o CP2, o que é o MVP agora. Mostra a matriz de aderência. |
| 1–4 | Santhiago | Cidadão na URL pública: cadastro → praça → ocorrência com foto → protocolo. |
| 4–7 | Davi | Agente: painel → assume → resolve (volta no protocolo do Santhiago: linha do tempo). Dispara botão de pânico → alerta chega ao vivo → reconhece. |
| 7–8,5 | Lucas | Gestor: dashboard. Mostra CI verde e e2e 82/82. |
| 8,5–10 | Ana | Arquitetura em 1 slide, limitações, o que vem para a AV2. Perguntas. |

Para a AV2 (01–08/12), comece `docs/apresentacao/pitch.md`: problema (dados de insegurança em praças do Recife),
solução, demo (mesmo roteiro, mais curto), arquitetura, diferenciais (anonimato, tempo real, RLS), equipe,
próximos passos. 8 slides no máximo.

```bash
git checkout -b docs/cp3-ana
git add docs/ && git commit -m "docs(cp3): aderencia prototipo x MVP, endpoints v2, arquitetura v2, manual e roteiro da apresentacao"
git push -u origin docs/cp3-ana
```

PR → revisor Lucas.
