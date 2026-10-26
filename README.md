# SafeTech — Segurança em Praças Públicas

Plataforma para monitoramento e gestão da segurança em praças públicas. Cidadãos registram ocorrências
(iluminação precária, vandalismo, assaltos, uso de drogas, infraestrutura danificada etc.), agentes e
gestores públicos acompanham, atendem e resolvem essas ocorrências, e equipamentos de segurança
instalados nas praças (câmeras, iluminação inteligente, botões de pânico, totens) geram alertas em
tempo real.

> Projeto Prático **AV2 — Desafios do Banco de Oportunidades (Implementação)**, Edital de Convocação nº 02/2026.2.
> Centro Universitário Maurício de Nassau (UNINASSAU) — Campus Recife (Graças) · Semestre 2026.2 · Prof. Breno Holanda.
> A AV2 transforma o protótipo validado na AV1 em uma aplicação real e funcional, com código-fonte estruturado,
> banco de dados e integrações, resolvendo um desafio do Banco de Oportunidades da Prefeitura do Recife.
>
> Protótipo da AV1 (Figma Make): https://www.figma.com/make/ILamNGNr7s2SHJDX4IiLkn/SafeTech-%E2%80%94-Seguran%C3%A7a-em-Pra%C3%A7as-P%C3%BAblicas

## Equipe

| Nome | GitHub | Papel técnico |
|------|--------|---------------|
| Lucas Victor | [@Lukasv30](https://github.com/Lukasv30) | _definir_ |
| _preencher_ | [@carolssgalvao-ai](https://github.com/carolssgalvao-ai) | _definir_ |
| _preencher_ | [@davi-vini-01](https://github.com/davi-vini-01) | _definir_ |
| _preencher_ | [@santhiagoagst](https://github.com/santhiagoagst) | _definir_ |
| _preencher_ | _preencher_ | _definir_ |

Papéis sugeridos pelo edital: Desenvolvedor Front-end, Desenvolvedor Back-end, DBA, QA/Testes e Líder Técnico.

## Cronograma oficial (Edital nº 02/2026.2)

| Data | Etapa | Entregáveis | Status |
|------|-------|-------------|--------|
| 30/10/2026 | Checkpoint 1 | Repositório criado (com todos os membros adicionados) e Modelagem Lógica do Banco de Dados / DDL inicial | 🟡 Em andamento |
| 13/11/2026 | Checkpoint 2 | Endpoints principais criados e conexão com o banco de dados funcionando | ⚪ Não iniciado |
| 27/11/2026 | Checkpoint 3 | Aplicação funcional ("MVP" integrado). Front-end consumindo o Back-end | ⚪ Não iniciado |
| 01/12 a 08/12/2026 | AV2 — Apresentação Oficial | Pitch Técnico, entrega do repositório final e demonstração do software ao vivo | ⚪ Não iniciado |

### Entregáveis obrigatórios

- **Repositório de código-fonte:** este repositório, com o código da aplicação.
- **Banco de dados:** scripts de criação e inserção de dados — [database/](database/).
- **Documentação técnica:** atualização do Template de Documentação, focado na Arquitetura da Solução — [docs/](docs/).
- **Apresentação final:** demonstração da aplicação rodando ao vivo e pitch.

### Critérios de avaliação

| Critério | Pontuação | O que é avaliado |
|----------|-----------|------------------|
| Funcionalidade e Aderência | 3,0 | A aplicação funciona sem erros críticos e faz o que o protótipo da AV1 propôs |
| Qualidade do Código e Boas Práticas | 3,0 | Organização, legibilidade e uso adequado de padrões no repositório |
| Estrutura e Persistência de Dados | 2,0 | Modelagem correta e capacidade de salvar/recuperar informações |
| Pitch e Domínio Técnico | 2,0 | Clareza na explicação, segurança da equipe nas tecnologias e demonstração fluida |

## Estrutura do repositório

```text
safe-tech-prd/
├── README.md
├── .gitignore
├── docs/
│   ├── arquitetura/                 # Template de Documentação (Arquitetura da Solução) — checkpoints 2 e 3
│   ├── requisitos/
│   │   └── requisitos.md            # Requisitos funcionais e não funcionais
│   ├── modelagem/
│   │   ├── modelo-conceitual.md     # Entidades, relacionamentos e regras de negócio
│   │   ├── modelo-logico.md         # Tabelas, colunas, chaves e diagrama ER (Mermaid)
│   │   └── dicionario-de-dados.md   # Descrição campo a campo
│   └── prototipo/
│       ├── README.md                # Link do Figma e mapa de telas
│       └── telas/                   # Capturas de tela do protótipo
├── database/
│   ├── ddl/
│   │   ├── 01_schema.sql            # Schema, extensões e tipos (ENUMs)
│   │   ├── 02_tables.sql            # Criação das tabelas
│   │   ├── 03_indexes.sql           # Índices
│   │   ├── 04_triggers.sql          # Triggers (atualizado_em, histórico de status)
│   │   └── 05_views.sql             # Views de apoio (dashboard, ocorrências abertas)
│   ├── seeds/
│   │   └── 01_seed_dev.sql          # Dados iniciais para desenvolvimento
│   └── scripts/
│       ├── create_db.sql            # Cria o banco de dados
│       ├── drop_all.sql             # Remove o schema (reset)
│       └── run_all.ps1 / run_all.sh # Executa DDL + seeds em ordem
└── src/
    ├── backend/                     # API (checkpoints futuros)
    └── frontend/                    # Interface web/mobile (checkpoints futuros)
```

## Banco de dados

- **SGBD:** PostgreSQL 15+ (compatível com Supabase).
- **Schema:** `safetech`.
- **Modelagem completa:** [docs/modelagem/modelo-logico.md](docs/modelagem/modelo-logico.md).

### Executando a DDL

Com o `psql` instalado e um servidor PostgreSQL rodando:

```bash
# 1. Criar o banco (apenas uma vez)
psql -U postgres -f database/scripts/create_db.sql

# 2. Criar schema, tabelas, índices, triggers, views e carregar seeds
cd database/scripts
./run_all.sh            # Linux / macOS / Git Bash
.\run_all.ps1           # Windows PowerShell
```

Para resetar o banco em desenvolvimento:

```bash
psql -U postgres -d safetech -f database/scripts/drop_all.sql
```

Variáveis de conexão aceitas pelos scripts: `PGHOST`, `PGPORT`, `PGUSER`, `PGPASSWORD`, `PGDATABASE`
(padrão: `localhost`, `5432`, `postgres`, vazio, `safetech`).

## Visão geral do modelo

| Tabela | Descrição |
|--------|-----------|
| `usuario` | Cidadãos, agentes, gestores e administradores da plataforma |
| `praca` | Praças públicas monitoradas (endereço e geolocalização) |
| `equipamento` | Equipamentos de segurança instalados nas praças (câmera, iluminação, botão de pânico, totem, sensor) |
| `categoria_ocorrencia` | Tipos de ocorrência (iluminação, vandalismo, assalto, ...) com gravidade padrão |
| `ocorrencia` | Registro de ocorrências feitas por cidadãos ou agentes |
| `anexo_ocorrencia` | Fotos/vídeos anexados a uma ocorrência |
| `historico_ocorrencia` | Trilha de mudanças de status de cada ocorrência |
| `atendimento` | Vínculo entre agente responsável e ocorrência |
| `alerta` | Alertas gerados por equipamentos, botão de pânico ou manualmente |
| `ronda` | Rondas/patrulhas realizadas por agentes em uma praça |
| `avaliacao_praca` | Avaliação da sensação de segurança da praça pelos cidadãos |
| `notificacao` | Notificações enviadas aos usuários |

## Convenções de colaboração

- **Branches:** `main` (estável) ← `feature/<descricao-curta>`, `fix/<descricao-curta>`, `docs/<descricao-curta>`.
- **Commits:** [Conventional Commits](https://www.conventionalcommits.org/pt-br/) — ex.: `feat(db): adiciona tabela alerta`, `docs: atualiza dicionário de dados`.
- **Pull Requests:** toda alteração em `main` passa por PR com revisão de pelo menos um membro.
- **SQL:** nomes em `snake_case`, singular para tabelas, chaves primárias `id`, chaves estrangeiras `<tabela>_id`.
