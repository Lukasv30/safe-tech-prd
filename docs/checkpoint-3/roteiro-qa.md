# Roteiro — QA (5º membro ou Ana) · Checkpoint 3

**Entrega:** plano de testes manuais do MVP por perfil (CT11–CT30), execução na URL da Vercel na quinta e na
sexta, bugs registrados como issues, evidências.

**Depende de:** URL da Vercel (Lucas, quarta à tarde) e PRs de quinta. Na quarta você escreve o plano.

## Matriz de permissões (o que cada perfil deve conseguir)

| Recurso | Anônimo | Cidadão | Agente | Gestor / Admin |
|---------|---------|---------|--------|----------------|
| Lista e detalhe de praças, consulta de protocolo | ✅ | ✅ | ✅ | ✅ |
| Registrar ocorrência | só anônima, via API | ✅ | ✅ | ✅ |
| Anexar foto, avaliar praça, minhas ocorrências | ❌ | ✅ | ✅ | ✅ |
| Ver ocorrências anônimas de outros | ❌ | ❌ | ✅ | ✅ |
| Painel, assumir, finalizar, mudar status | ❌ | ❌ | ✅ | ✅ |
| Alertas (ver, reconhecer, encerrar) | ❌ | ❌ | ✅ | ✅ |
| Dashboard | ❌ | ❌ | ❌ | ✅ |
| Criar/editar praça | ❌ | ❌ | ❌ | ✅ (via API) |

## Casos de teste

Contas: `cidadao.demo`, `agente.demo`, `gestor.demo` `@safetech.app`, senha `Senha@123`. Use aba anônima do
navegador para trocar de usuário sem conflito de sessão. Registre resultado, navegador e print.

| CT | Perfil | Passos | Resultado esperado |
|----|--------|--------|--------------------|
| CT11 | Anônimo | Abrir a URL raiz | Redireciona para `/pracas`; 3+ praças com números; sem erro no console |
| CT12 | Anônimo | Clicar numa praça | Detalhe com endereço, indicadores, equipamentos, ocorrências abertas, avaliações; texto "Entre para avaliar" |
| CT13 | Anônimo | Menu Protocolo → digitar `STC-2026-000001` | Linha do tempo com ≥ 1 passo; URL vira `/protocolo?p=STC-2026-000001` |
| CT14 | Anônimo | Digitar `/painel`, `/alertas`, `/dashboard`, `/minhas-ocorrencias` na URL | Todas redirecionam para `/login` |
| CT15 | Novo usuário | Cadastro com e-mail inédito | Entra logado; nome e tag CIDADAO no topo; menu mostra "Minhas ocorrências" |
| CT16 | Cidadão | Login | Cai em `/pracas`; recarregar a página mantém logado |
| CT17 | Cidadão | Detalhe da praça → 4 estrelas → Avaliar; depois 2 estrelas → Avaliar | Após a 1ª, "Sua nota atual: 4"; após a 2ª, nota 2 e **só uma** avaliação sua na lista |
| CT18 | Cidadão | Nova ocorrência com 1 foto (< 5 MB) | Tela de sucesso com protocolo `STC-…` e "1 anexo(s) enviado(s)" |
| CT19 | Cidadão | Nova ocorrência com arquivo > 5 MB | Ocorrência registrada; aviso "Alguns anexos falharam: … excede 5 MB" |
| CT20 | Cidadão | Nova ocorrência marcada "anônima" | Protocolo gerado; em Minhas ocorrências aparece com tag "anônima" |
| CT21 | Cidadão | Minhas ocorrências → detalhes da CT18 | Descrição e miniatura da foto; clicar abre a imagem |
| CT22 | Cidadão | Digitar `/painel`, `/alertas`, `/dashboard` | Mensagem "Seu perfil (CIDADAO) não tem acesso"; menu não mostra esses links |
| CT23 | Agente | Login | Cai em `/painel`; menu mostra Painel e Alertas, não Dashboard |
| CT24 | Agente | Painel → "tratar" na ocorrência da CT18 → Assumir atendimento | Status vira EM ATENDIMENTO; filtro "Minhas" conta 1; histórico ganha um passo |
| CT25 | Agente | Escrever relato (≥ 5 caracteres) → Finalizar e resolver | Ocorrência sai da fila; em outra aba, protocolo da CT18 mostra ABERTA → EM ATENDIMENTO → RESOLVIDA |
| CT26 | Agente | Painel → ocorrência **anônima** da CT20 | Aparece com autor "Anônimo" (equipe vê anônimas, mas nunca o nome) |
| CT27 | Agente | Alertas aberto; Davi/Lucas dispara `acionar_botao_panico` via curl | Alerta aparece **sem recarregar** em até 5 s, piscando; indicador "● ao vivo" |
| CT28 | Agente | Reconhecer o alerta da CT27 → depois Encerrar na lista "Tratados" | Sai de Pendentes; aparece em Tratados como RECONHECIDO, depois ENCERRADO |
| CT29 | Gestor | Login → Dashboard → trocar 7 / 30 / 90 dias | Cai em `/dashboard`; indicadores e gráficos mudam com o período; ranking com 3 praças |
| CT30 | Gestor | Painel → "Cancelar ocorrência" numa ABERTA | Sai da fila; protocolo mostra CANCELADA; cidadão autor ainda a vê em Minhas ocorrências |
| CT31 | Todos | Abrir a URL no celular (ou DevTools 390 px) | Menu quebra em linhas, tabelas roláveis, formulários usáveis, sem rolagem horizontal da página |
| CT32 | API | `node database/scripts/e2e.mjs` (pedir ao Lucas a saída) | 82/82 OK |

## Como registrar

1. Planilha simples em `docs/checkpoint-3/evidencias/qa-execucao.md`: CT, data, navegador, resultado (✅/❌), print.
2. Cada ❌ vira uma issue com título `[bug] CTxx — <resumo>`, etiqueta `bug` + área (`front`, `back`,
   `painel`, `alertas`, `dashboard`), passos, esperado × obtido, print, URL testada. Atribua ao dono do arquivo
   (ver "Donos de arquivo" no README do checkpoint).
3. Sexta de manhã, reexecute só os CTs que falharam e feche as issues corrigidas.

Modelo de issue:

```markdown
**CT:** CT24 · **URL:** https://…vercel.app/painel · **Navegador:** Chrome 131
**Passos:** login agente.demo → Painel → tratar STC-2026-000019 → Assumir atendimento
**Esperado:** status EM ATENDIMENTO
**Obtido:** erro "Apenas a equipe pode atribuir atendimentos"
**Print:** (anexar)
```

## Prioridade se faltar tempo

Rode primeiro CT11, CT15, CT18, CT24, CT25, CT27, CT29: é exatamente o fluxo da demo. Se esses sete passam,
a apresentação está segura.
