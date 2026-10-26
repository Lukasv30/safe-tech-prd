# Modelo Lógico — SafeTech

SGBD: **PostgreSQL 15+** · Schema: **`safetech`** · DDL: [`database/ddl/`](../../database/ddl/)

Convenções: tabelas no singular em `snake_case`; chave primária `id` (UUID, exceto catálogos com `SERIAL`);
chaves estrangeiras `<tabela>_id`; colunas de auditoria `criado_em` / `atualizado_em` (`TIMESTAMPTZ`).

## 1. Tipos enumerados

| Tipo | Valores |
|------|---------|
| `perfil_usuario` | CIDADAO, AGENTE, GESTOR, ADMIN |
| `status_ocorrencia` | ABERTA, EM_ANALISE, EM_ATENDIMENTO, RESOLVIDA, CANCELADA |
| `nivel_gravidade` | BAIXA, MEDIA, ALTA, CRITICA |
| `tipo_equipamento` | CAMERA, ILUMINACAO, BOTAO_PANICO, TOTEM, SENSOR_PRESENCA, SENSOR_RUIDO |
| `status_equipamento` | OPERANTE, INOPERANTE, EM_MANUTENCAO, DESATIVADO |
| `origem_alerta` | EQUIPAMENTO, BOTAO_PANICO, MANUAL |
| `status_alerta` | NOVO, RECONHECIDO, ENCERRADO, FALSO_POSITIVO |
| `tipo_midia` | IMAGEM, VIDEO, AUDIO, DOCUMENTO |
| `status_ronda` | AGENDADA, EM_ANDAMENTO, CONCLUIDA, CANCELADA |

## 2. Tabelas

Legenda: **PK** chave primária · **FK** chave estrangeira · **UK** única · **NN** not null

### usuario
| Coluna | Tipo | Restrições |
|--------|------|------------|
| id | UUID | PK, default `gen_random_uuid()` |
| nome | VARCHAR(120) | NN |
| email | VARCHAR(160) | NN, UK, formato validado |
| senha_hash | VARCHAR(255) | NN |
| telefone | VARCHAR(20) | |
| cpf | CHAR(11) | UK, apenas dígitos |
| perfil | perfil_usuario | NN, default CIDADAO |
| matricula | VARCHAR(30) | UK |
| ativo | BOOLEAN | NN, default TRUE |
| criado_em / atualizado_em | TIMESTAMPTZ | NN, default NOW() |

### praca
| Coluna | Tipo | Restrições |
|--------|------|------------|
| id | UUID | PK |
| nome | VARCHAR(150) | NN |
| descricao | TEXT | |
| logradouro | VARCHAR(150) | NN |
| numero | VARCHAR(10) | |
| bairro | VARCHAR(100) | NN |
| cidade | VARCHAR(100) | NN |
| uf | CHAR(2) | NN, `^[A-Z]{2}$` |
| cep | CHAR(8) | apenas dígitos |
| latitude | NUMERIC(9,6) | NN, −90..90 |
| longitude | NUMERIC(9,6) | NN, −180..180 |
| area_m2 | NUMERIC(10,2) | > 0 |
| horario_abertura / horario_fechamento | TIME | |
| ativa | BOOLEAN | NN, default TRUE |
| criado_em / atualizado_em | TIMESTAMPTZ | NN |

### equipamento
| Coluna | Tipo | Restrições |
|--------|------|------------|
| id | UUID | PK |
| praca_id | UUID | FK → praca (ON DELETE CASCADE), NN |
| tipo | tipo_equipamento | NN |
| codigo | VARCHAR(50) | NN, UK |
| descricao | VARCHAR(255) | |
| localizacao | VARCHAR(255) | |
| latitude / longitude | NUMERIC(9,6) | faixa validada |
| status | status_equipamento | NN, default OPERANTE |
| instalado_em / ultima_manutencao | DATE | |
| criado_em / atualizado_em | TIMESTAMPTZ | NN |

### categoria_ocorrencia
| Coluna | Tipo | Restrições |
|--------|------|------------|
| id | SERIAL | PK |
| nome | VARCHAR(80) | NN, UK |
| descricao | VARCHAR(255) | |
| gravidade_padrao | nivel_gravidade | NN, default MEDIA |
| ativa | BOOLEAN | NN, default TRUE |

### ocorrencia
| Coluna | Tipo | Restrições |
|--------|------|------------|
| id | UUID | PK |
| protocolo | VARCHAR(20) | NN, UK, gerado por trigger (`STC-AAAA-NNNNNN`) |
| praca_id | UUID | FK → praca, NN |
| categoria_id | INTEGER | FK → categoria_ocorrencia, NN |
| autor_id | UUID | FK → usuario (ON DELETE SET NULL); obrigatório se `anonima = FALSE` |
| titulo | VARCHAR(150) | NN |
| descricao | TEXT | NN |
| gravidade | nivel_gravidade | NN, default MEDIA |
| status | status_ocorrencia | NN, default ABERTA |
| anonima | BOOLEAN | NN, default FALSE |
| latitude / longitude | NUMERIC(9,6) | faixa validada |
| ocorrida_em | TIMESTAMPTZ | NN, default NOW() |
| resolvida_em | TIMESTAMPTZ | preenchido somente quando status = RESOLVIDA (trigger) |
| criado_em / atualizado_em | TIMESTAMPTZ | NN |

### anexo_ocorrencia
| Coluna | Tipo | Restrições |
|--------|------|------------|
| id | UUID | PK |
| ocorrencia_id | UUID | FK → ocorrencia (CASCADE), NN |
| tipo | tipo_midia | NN, default IMAGEM |
| url | VARCHAR(500) | NN |
| nome_arquivo | VARCHAR(255) | |
| tamanho_bytes | BIGINT | ≥ 0 |
| enviado_por | UUID | FK → usuario (SET NULL) |
| enviado_em | TIMESTAMPTZ | NN |

### historico_ocorrencia
| Coluna | Tipo | Restrições |
|--------|------|------------|
| id | BIGSERIAL | PK |
| ocorrencia_id | UUID | FK → ocorrencia (CASCADE), NN |
| status_anterior | status_ocorrencia | NULL na criação |
| status_novo | status_ocorrencia | NN |
| usuario_id | UUID | FK → usuario (SET NULL); NULL = sistema |
| observacao | TEXT | |
| alterado_em | TIMESTAMPTZ | NN |

### atendimento
| Coluna | Tipo | Restrições |
|--------|------|------------|
| id | UUID | PK |
| ocorrencia_id | UUID | FK → ocorrencia (CASCADE), NN |
| agente_id | UUID | FK → usuario, NN; perfil ≠ CIDADAO (trigger) |
| atribuido_por | UUID | FK → usuario (SET NULL) |
| iniciado_em | TIMESTAMPTZ | NN, default NOW() |
| finalizado_em | TIMESTAMPTZ | ≥ iniciado_em |
| relato | TEXT | |

### alerta
| Coluna | Tipo | Restrições |
|--------|------|------------|
| id | UUID | PK |
| praca_id | UUID | FK → praca, NN |
| equipamento_id | UUID | FK → equipamento (SET NULL); NN se origem ∈ {EQUIPAMENTO, BOTAO_PANICO} |
| ocorrencia_id | UUID | FK → ocorrencia (SET NULL) |
| origem | origem_alerta | NN |
| gravidade | nivel_gravidade | NN, default ALTA |
| status | status_alerta | NN, default NOVO |
| mensagem | VARCHAR(500) | NN |
| criado_por | UUID | FK → usuario (SET NULL); NN se origem = MANUAL |
| reconhecido_por | UUID | FK → usuario (SET NULL); par com reconhecido_em |
| reconhecido_em / encerrado_em | TIMESTAMPTZ | |
| criado_em | TIMESTAMPTZ | NN |

### ronda
| Coluna | Tipo | Restrições |
|--------|------|------------|
| id | UUID | PK |
| praca_id | UUID | FK → praca, NN |
| agente_id | UUID | FK → usuario, NN; perfil ≠ CIDADAO (trigger) |
| status | status_ronda | NN, default AGENDADA |
| agendada_para | TIMESTAMPTZ | NN |
| iniciada_em / finalizada_em | TIMESTAMPTZ | finalizada ≥ iniciada |
| observacoes | TEXT | |
| criado_em | TIMESTAMPTZ | NN |

### avaliacao_praca
| Coluna | Tipo | Restrições |
|--------|------|------------|
| id | UUID | PK |
| praca_id | UUID | FK → praca (CASCADE), NN |
| usuario_id | UUID | FK → usuario (CASCADE), NN |
| nota | SMALLINT | NN, 1..5 |
| comentario | VARCHAR(500) | |
| criado_em | TIMESTAMPTZ | NN |

### notificacao
| Coluna | Tipo | Restrições |
|--------|------|------------|
| id | UUID | PK |
| usuario_id | UUID | FK → usuario (CASCADE), NN |
| ocorrencia_id | UUID | FK → ocorrencia (CASCADE) |
| alerta_id | UUID | FK → alerta (CASCADE) |
| titulo | VARCHAR(120) | NN |
| mensagem | VARCHAR(500) | NN |
| lida | BOOLEAN | NN, default FALSE; par com lida_em |
| lida_em | TIMESTAMPTZ | |
| criado_em | TIMESTAMPTZ | NN |

## 3. Triggers e automações

| Trigger | Tabela | Efeito |
|---------|--------|--------|
| `trg_*_atualizado_em` | usuario, praca, equipamento, ocorrencia | Atualiza `atualizado_em` a cada UPDATE |
| `trg_ocorrencia_protocolo` | ocorrencia | Gera `protocolo` no INSERT (`STC-AAAA-NNNNNN`) |
| `trg_ocorrencia_resolvida_em` | ocorrencia | Preenche/limpa `resolvida_em` conforme o status |
| `trg_ocorrencia_historico` | ocorrencia | Grava em `historico_ocorrencia` na criação e a cada mudança de status |
| `trg_atendimento_validar_agente` / `trg_ronda_validar_agente` | atendimento, ronda | Impede que CIDADAO seja agente responsável |
| `trg_atendimento_atualiza_ocorrencia` | atendimento | Ao criar atendimento, ocorrência vai para EM_ATENDIMENTO |

## 4. Views

| View | Uso |
|------|-----|
| `vw_ocorrencia_aberta` | Listagem de ocorrências em aberto com praça, categoria, autor (respeitando anonimato) e quantidade de anexos |
| `vw_praca_resumo` | Indicadores por praça para o dashboard: ocorrências abertas, últimos 30 dias, alertas novos, equipamentos com problema, nota média |
| `vw_alerta_pendente` | Alertas com status NOVO, com equipamento e praça |

## 5. Diagrama ER (lógico)

```mermaid
erDiagram
    usuario {
        uuid id PK
        varchar nome
        varchar email UK
        varchar senha_hash
        varchar telefone
        char cpf UK
        perfil_usuario perfil
        varchar matricula UK
        boolean ativo
        timestamptz criado_em
        timestamptz atualizado_em
    }

    praca {
        uuid id PK
        varchar nome
        text descricao
        varchar logradouro
        varchar numero
        varchar bairro
        varchar cidade
        char uf
        char cep
        numeric latitude
        numeric longitude
        numeric area_m2
        time horario_abertura
        time horario_fechamento
        boolean ativa
        timestamptz criado_em
        timestamptz atualizado_em
    }

    equipamento {
        uuid id PK
        uuid praca_id FK
        tipo_equipamento tipo
        varchar codigo UK
        varchar descricao
        varchar localizacao
        numeric latitude
        numeric longitude
        status_equipamento status
        date instalado_em
        date ultima_manutencao
    }

    categoria_ocorrencia {
        serial id PK
        varchar nome UK
        varchar descricao
        nivel_gravidade gravidade_padrao
        boolean ativa
    }

    ocorrencia {
        uuid id PK
        varchar protocolo UK
        uuid praca_id FK
        int categoria_id FK
        uuid autor_id FK
        varchar titulo
        text descricao
        nivel_gravidade gravidade
        status_ocorrencia status
        boolean anonima
        numeric latitude
        numeric longitude
        timestamptz ocorrida_em
        timestamptz resolvida_em
    }

    anexo_ocorrencia {
        uuid id PK
        uuid ocorrencia_id FK
        tipo_midia tipo
        varchar url
        varchar nome_arquivo
        bigint tamanho_bytes
        uuid enviado_por FK
        timestamptz enviado_em
    }

    historico_ocorrencia {
        bigserial id PK
        uuid ocorrencia_id FK
        status_ocorrencia status_anterior
        status_ocorrencia status_novo
        uuid usuario_id FK
        text observacao
        timestamptz alterado_em
    }

    atendimento {
        uuid id PK
        uuid ocorrencia_id FK
        uuid agente_id FK
        uuid atribuido_por FK
        timestamptz iniciado_em
        timestamptz finalizado_em
        text relato
    }

    alerta {
        uuid id PK
        uuid praca_id FK
        uuid equipamento_id FK
        uuid ocorrencia_id FK
        origem_alerta origem
        nivel_gravidade gravidade
        status_alerta status
        varchar mensagem
        uuid criado_por FK
        uuid reconhecido_por FK
        timestamptz reconhecido_em
        timestamptz encerrado_em
        timestamptz criado_em
    }

    ronda {
        uuid id PK
        uuid praca_id FK
        uuid agente_id FK
        status_ronda status
        timestamptz agendada_para
        timestamptz iniciada_em
        timestamptz finalizada_em
        text observacoes
    }

    avaliacao_praca {
        uuid id PK
        uuid praca_id FK
        uuid usuario_id FK
        smallint nota
        varchar comentario
        timestamptz criado_em
    }

    notificacao {
        uuid id PK
        uuid usuario_id FK
        uuid ocorrencia_id FK
        uuid alerta_id FK
        varchar titulo
        varchar mensagem
        boolean lida
        timestamptz lida_em
        timestamptz criado_em
    }

    praca ||--o{ equipamento : praca_id
    praca ||--o{ ocorrencia : praca_id
    praca ||--o{ alerta : praca_id
    praca ||--o{ ronda : praca_id
    praca ||--o{ avaliacao_praca : praca_id

    categoria_ocorrencia ||--o{ ocorrencia : categoria_id

    usuario o|--o{ ocorrencia : autor_id
    usuario ||--o{ atendimento : agente_id
    usuario o|--o{ atendimento : atribuido_por
    usuario ||--o{ ronda : agente_id
    usuario ||--o{ avaliacao_praca : usuario_id
    usuario ||--o{ notificacao : usuario_id
    usuario o|--o{ historico_ocorrencia : usuario_id
    usuario o|--o{ anexo_ocorrencia : enviado_por
    usuario o|--o{ alerta : criado_por
    usuario o|--o{ alerta : reconhecido_por

    ocorrencia ||--o{ anexo_ocorrencia : ocorrencia_id
    ocorrencia ||--o{ historico_ocorrencia : ocorrencia_id
    ocorrencia ||--o{ atendimento : ocorrencia_id
    ocorrencia o|--o{ alerta : ocorrencia_id
    ocorrencia o|--o{ notificacao : ocorrencia_id

    equipamento o|--o{ alerta : equipamento_id
    alerta o|--o{ notificacao : alerta_id
```
