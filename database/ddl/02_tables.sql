-- =============================================================================
-- SafeTech — Segurança em Praças Públicas
-- 02_tables.sql : criação das tabelas
-- =============================================================================
SET search_path TO safetech, public;

-- -----------------------------------------------------------------------------
-- USUARIO
-- Cidadãos, agentes de campo, gestores públicos e administradores.
-- -----------------------------------------------------------------------------
CREATE TABLE usuario (
    id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    nome            VARCHAR(120)    NOT NULL,
    email           VARCHAR(160)    NOT NULL,
    senha_hash      VARCHAR(255)    NOT NULL,
    telefone        VARCHAR(20),
    cpf             CHAR(11),
    perfil          perfil_usuario  NOT NULL DEFAULT 'CIDADAO',
    matricula       VARCHAR(30),                    -- apenas para AGENTE / GESTOR
    ativo           BOOLEAN         NOT NULL DEFAULT TRUE,
    criado_em       TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    atualizado_em   TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_usuario_email      UNIQUE (email),
    CONSTRAINT uq_usuario_cpf        UNIQUE (cpf),
    CONSTRAINT uq_usuario_matricula  UNIQUE (matricula),
    CONSTRAINT ck_usuario_email      CHECK (email ~* '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'),
    CONSTRAINT ck_usuario_cpf        CHECK (cpf IS NULL OR cpf ~ '^[0-9]{11}$')
);

COMMENT ON TABLE  usuario            IS 'Usuários da plataforma (cidadãos, agentes, gestores e administradores).';
COMMENT ON COLUMN usuario.senha_hash IS 'Hash da senha (bcrypt/argon2). Nunca armazenar senha em texto puro.';
COMMENT ON COLUMN usuario.matricula  IS 'Matrícula funcional, obrigatória na aplicação para AGENTE e GESTOR.';

-- -----------------------------------------------------------------------------
-- PRACA
-- Praças públicas monitoradas pela plataforma.
-- -----------------------------------------------------------------------------
CREATE TABLE praca (
    id                  UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    nome                VARCHAR(150)    NOT NULL,
    descricao           TEXT,
    logradouro          VARCHAR(150)    NOT NULL,
    numero              VARCHAR(10),
    bairro              VARCHAR(100)    NOT NULL,
    cidade              VARCHAR(100)    NOT NULL,
    uf                  CHAR(2)         NOT NULL,
    cep                 CHAR(8),
    latitude            NUMERIC(9,6)    NOT NULL,
    longitude           NUMERIC(9,6)    NOT NULL,
    area_m2             NUMERIC(10,2),
    horario_abertura    TIME,
    horario_fechamento  TIME,
    ativa               BOOLEAN         NOT NULL DEFAULT TRUE,
    criado_em           TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    atualizado_em       TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    CONSTRAINT ck_praca_uf        CHECK (uf ~ '^[A-Z]{2}$'),
    CONSTRAINT ck_praca_cep       CHECK (cep IS NULL OR cep ~ '^[0-9]{8}$'),
    CONSTRAINT ck_praca_latitude  CHECK (latitude  BETWEEN -90  AND 90),
    CONSTRAINT ck_praca_longitude CHECK (longitude BETWEEN -180 AND 180),
    CONSTRAINT ck_praca_area      CHECK (area_m2 IS NULL OR area_m2 > 0)
);

COMMENT ON TABLE praca IS 'Praças públicas cadastradas, com endereço e geolocalização.';

-- -----------------------------------------------------------------------------
-- EQUIPAMENTO
-- Equipamentos de segurança instalados em uma praça.
-- -----------------------------------------------------------------------------
CREATE TABLE equipamento (
    id                  UUID                PRIMARY KEY DEFAULT gen_random_uuid(),
    praca_id            UUID                NOT NULL,
    tipo                tipo_equipamento    NOT NULL,
    codigo              VARCHAR(50)         NOT NULL,   -- identificador físico / patrimônio
    descricao           VARCHAR(255),
    localizacao         VARCHAR(255),                   -- ponto de referência dentro da praça
    latitude            NUMERIC(9,6),
    longitude           NUMERIC(9,6),
    status              status_equipamento  NOT NULL DEFAULT 'OPERANTE',
    instalado_em        DATE,
    ultima_manutencao   DATE,
    criado_em           TIMESTAMPTZ         NOT NULL DEFAULT NOW(),
    atualizado_em       TIMESTAMPTZ         NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_equipamento_praca     FOREIGN KEY (praca_id) REFERENCES praca (id) ON DELETE CASCADE,
    CONSTRAINT uq_equipamento_codigo    UNIQUE (codigo),
    CONSTRAINT ck_equipamento_latitude  CHECK (latitude  IS NULL OR latitude  BETWEEN -90  AND 90),
    CONSTRAINT ck_equipamento_longitude CHECK (longitude IS NULL OR longitude BETWEEN -180 AND 180)
);

COMMENT ON TABLE equipamento IS 'Câmeras, iluminação, botões de pânico, totens e sensores instalados nas praças.';

-- -----------------------------------------------------------------------------
-- CATEGORIA_OCORRENCIA
-- Tipos de ocorrência que podem ser registradas.
-- -----------------------------------------------------------------------------
CREATE TABLE categoria_ocorrencia (
    id                  SERIAL          PRIMARY KEY,
    nome                VARCHAR(80)     NOT NULL,
    descricao           VARCHAR(255),
    gravidade_padrao    nivel_gravidade NOT NULL DEFAULT 'MEDIA',
    ativa               BOOLEAN         NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_categoria_ocorrencia_nome UNIQUE (nome)
);

COMMENT ON TABLE categoria_ocorrencia IS 'Catálogo de tipos de ocorrência (iluminação, vandalismo, assalto, ...).';

-- -----------------------------------------------------------------------------
-- OCORRENCIA
-- Ocorrência registrada por um cidadão ou agente em uma praça.
-- -----------------------------------------------------------------------------
CREATE TABLE ocorrencia (
    id              UUID                PRIMARY KEY DEFAULT gen_random_uuid(),
    protocolo       VARCHAR(20),                        -- gerado por trigger: STC-AAAA-NNNNNN
    praca_id        UUID                NOT NULL,
    categoria_id    INTEGER             NOT NULL,
    autor_id        UUID,                               -- NULL apenas quando anônima
    titulo          VARCHAR(150)        NOT NULL,
    descricao       TEXT                NOT NULL,
    gravidade       nivel_gravidade     NOT NULL DEFAULT 'MEDIA',
    status          status_ocorrencia   NOT NULL DEFAULT 'ABERTA',
    anonima         BOOLEAN             NOT NULL DEFAULT FALSE,
    latitude        NUMERIC(9,6),
    longitude       NUMERIC(9,6),
    ocorrida_em     TIMESTAMPTZ         NOT NULL DEFAULT NOW(),
    resolvida_em    TIMESTAMPTZ,
    criado_em       TIMESTAMPTZ         NOT NULL DEFAULT NOW(),
    atualizado_em   TIMESTAMPTZ         NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_ocorrencia_praca     FOREIGN KEY (praca_id)     REFERENCES praca (id),
    CONSTRAINT fk_ocorrencia_categoria FOREIGN KEY (categoria_id) REFERENCES categoria_ocorrencia (id),
    CONSTRAINT fk_ocorrencia_autor     FOREIGN KEY (autor_id)     REFERENCES usuario (id) ON DELETE SET NULL,
    CONSTRAINT uq_ocorrencia_protocolo UNIQUE (protocolo),
    CONSTRAINT ck_ocorrencia_autor     CHECK (anonima OR autor_id IS NOT NULL),
    CONSTRAINT ck_ocorrencia_latitude  CHECK (latitude  IS NULL OR latitude  BETWEEN -90  AND 90),
    CONSTRAINT ck_ocorrencia_longitude CHECK (longitude IS NULL OR longitude BETWEEN -180 AND 180),
    CONSTRAINT ck_ocorrencia_resolvida CHECK (
        (status = 'RESOLVIDA' AND resolvida_em IS NOT NULL) OR
        (status <> 'RESOLVIDA' AND resolvida_em IS NULL)
    )
);

COMMENT ON TABLE  ocorrencia           IS 'Ocorrências de segurança registradas nas praças.';
COMMENT ON COLUMN ocorrencia.protocolo IS 'Número de protocolo público, gerado automaticamente (STC-AAAA-NNNNNN).';
COMMENT ON COLUMN ocorrencia.anonima   IS 'Quando TRUE o autor não é exibido e autor_id pode ser NULL.';

-- -----------------------------------------------------------------------------
-- ANEXO_OCORRENCIA
-- Mídias anexadas a uma ocorrência.
-- -----------------------------------------------------------------------------
CREATE TABLE anexo_ocorrencia (
    id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    ocorrencia_id   UUID            NOT NULL,
    tipo            tipo_midia      NOT NULL DEFAULT 'IMAGEM',
    url             VARCHAR(500)    NOT NULL,
    nome_arquivo    VARCHAR(255),
    tamanho_bytes   BIGINT,
    enviado_por     UUID,
    enviado_em      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_anexo_ocorrencia FOREIGN KEY (ocorrencia_id) REFERENCES ocorrencia (id) ON DELETE CASCADE,
    CONSTRAINT fk_anexo_usuario    FOREIGN KEY (enviado_por)   REFERENCES usuario (id) ON DELETE SET NULL,
    CONSTRAINT ck_anexo_tamanho    CHECK (tamanho_bytes IS NULL OR tamanho_bytes >= 0)
);

COMMENT ON TABLE anexo_ocorrencia IS 'Fotos, vídeos e documentos anexados às ocorrências.';

-- -----------------------------------------------------------------------------
-- HISTORICO_OCORRENCIA
-- Trilha de auditoria das mudanças de status.
-- -----------------------------------------------------------------------------
CREATE TABLE historico_ocorrencia (
    id              BIGSERIAL           PRIMARY KEY,
    ocorrencia_id   UUID                NOT NULL,
    status_anterior status_ocorrencia,
    status_novo     status_ocorrencia   NOT NULL,
    usuario_id      UUID,                               -- quem alterou (NULL = sistema)
    observacao      TEXT,
    alterado_em     TIMESTAMPTZ         NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_historico_ocorrencia FOREIGN KEY (ocorrencia_id) REFERENCES ocorrencia (id) ON DELETE CASCADE,
    CONSTRAINT fk_historico_usuario    FOREIGN KEY (usuario_id)    REFERENCES usuario (id) ON DELETE SET NULL
);

COMMENT ON TABLE historico_ocorrencia IS 'Histórico de transições de status das ocorrências (preenchido por trigger).';

-- -----------------------------------------------------------------------------
-- ATENDIMENTO
-- Agente(s) responsável(is) pelo atendimento de uma ocorrência.
-- -----------------------------------------------------------------------------
CREATE TABLE atendimento (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    ocorrencia_id   UUID        NOT NULL,
    agente_id       UUID        NOT NULL,
    atribuido_por   UUID,                               -- gestor que fez a atribuição
    iniciado_em     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    finalizado_em   TIMESTAMPTZ,
    relato          TEXT,

    CONSTRAINT fk_atendimento_ocorrencia FOREIGN KEY (ocorrencia_id) REFERENCES ocorrencia (id) ON DELETE CASCADE,
    CONSTRAINT fk_atendimento_agente     FOREIGN KEY (agente_id)     REFERENCES usuario (id),
    CONSTRAINT fk_atendimento_gestor     FOREIGN KEY (atribuido_por) REFERENCES usuario (id) ON DELETE SET NULL,
    CONSTRAINT ck_atendimento_periodo    CHECK (finalizado_em IS NULL OR finalizado_em >= iniciado_em)
);

COMMENT ON TABLE atendimento IS 'Atribuição de agentes a ocorrências e relato do atendimento.';

-- -----------------------------------------------------------------------------
-- ALERTA
-- Alertas em tempo real gerados por equipamentos, botão de pânico ou manualmente.
-- -----------------------------------------------------------------------------
CREATE TABLE alerta (
    id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    praca_id        UUID            NOT NULL,
    equipamento_id  UUID,                               -- obrigatório para origem EQUIPAMENTO / BOTAO_PANICO
    ocorrencia_id   UUID,                               -- ocorrência aberta a partir do alerta
    origem          origem_alerta   NOT NULL,
    gravidade       nivel_gravidade NOT NULL DEFAULT 'ALTA',
    status          status_alerta   NOT NULL DEFAULT 'NOVO',
    mensagem        VARCHAR(500)    NOT NULL,
    criado_por      UUID,                               -- obrigatório para origem MANUAL
    reconhecido_por UUID,
    reconhecido_em  TIMESTAMPTZ,
    encerrado_em    TIMESTAMPTZ,
    criado_em       TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_alerta_praca        FOREIGN KEY (praca_id)        REFERENCES praca (id),
    CONSTRAINT fk_alerta_equipamento  FOREIGN KEY (equipamento_id)  REFERENCES equipamento (id) ON DELETE SET NULL,
    CONSTRAINT fk_alerta_ocorrencia   FOREIGN KEY (ocorrencia_id)   REFERENCES ocorrencia (id)  ON DELETE SET NULL,
    CONSTRAINT fk_alerta_criador      FOREIGN KEY (criado_por)      REFERENCES usuario (id)     ON DELETE SET NULL,
    CONSTRAINT fk_alerta_reconhecedor FOREIGN KEY (reconhecido_por) REFERENCES usuario (id)     ON DELETE SET NULL,
    CONSTRAINT ck_alerta_origem CHECK (
        (origem IN ('EQUIPAMENTO', 'BOTAO_PANICO') AND equipamento_id IS NOT NULL) OR
        (origem = 'MANUAL' AND criado_por IS NOT NULL)
    ),
    CONSTRAINT ck_alerta_reconhecido CHECK (
        (reconhecido_por IS NULL AND reconhecido_em IS NULL) OR
        (reconhecido_por IS NOT NULL AND reconhecido_em IS NOT NULL)
    )
);

COMMENT ON TABLE alerta IS 'Alertas em tempo real; podem originar uma ocorrência.';

-- -----------------------------------------------------------------------------
-- RONDA
-- Rondas / patrulhas realizadas por agentes nas praças.
-- -----------------------------------------------------------------------------
CREATE TABLE ronda (
    id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    praca_id        UUID            NOT NULL,
    agente_id       UUID            NOT NULL,
    status          status_ronda    NOT NULL DEFAULT 'AGENDADA',
    agendada_para   TIMESTAMPTZ     NOT NULL,
    iniciada_em     TIMESTAMPTZ,
    finalizada_em   TIMESTAMPTZ,
    observacoes     TEXT,
    criado_em       TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_ronda_praca   FOREIGN KEY (praca_id)  REFERENCES praca (id),
    CONSTRAINT fk_ronda_agente  FOREIGN KEY (agente_id) REFERENCES usuario (id),
    CONSTRAINT ck_ronda_periodo CHECK (
        finalizada_em IS NULL OR iniciada_em IS NULL OR finalizada_em >= iniciada_em
    )
);

COMMENT ON TABLE ronda IS 'Rondas agendadas e realizadas por agentes em cada praça.';

-- -----------------------------------------------------------------------------
-- AVALIACAO_PRACA
-- Avaliação da sensação de segurança de uma praça por um cidadão.
-- -----------------------------------------------------------------------------
CREATE TABLE avaliacao_praca (
    id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    praca_id        UUID            NOT NULL,
    usuario_id      UUID            NOT NULL,
    nota            SMALLINT        NOT NULL,           -- 1 (muito insegura) a 5 (muito segura)
    comentario      VARCHAR(500),
    criado_em       TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_avaliacao_praca   FOREIGN KEY (praca_id)   REFERENCES praca (id)   ON DELETE CASCADE,
    CONSTRAINT fk_avaliacao_usuario FOREIGN KEY (usuario_id) REFERENCES usuario (id) ON DELETE CASCADE,
    CONSTRAINT ck_avaliacao_nota    CHECK (nota BETWEEN 1 AND 5)
);

COMMENT ON TABLE avaliacao_praca IS 'Avaliações da sensação de segurança das praças (1 a 5).';

-- -----------------------------------------------------------------------------
-- NOTIFICACAO
-- Notificações enviadas aos usuários (status de ocorrência, alertas, etc.).
-- -----------------------------------------------------------------------------
CREATE TABLE notificacao (
    id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id      UUID            NOT NULL,
    ocorrencia_id   UUID,
    alerta_id       UUID,
    titulo          VARCHAR(120)    NOT NULL,
    mensagem        VARCHAR(500)    NOT NULL,
    lida            BOOLEAN         NOT NULL DEFAULT FALSE,
    lida_em         TIMESTAMPTZ,
    criado_em       TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_notificacao_usuario    FOREIGN KEY (usuario_id)    REFERENCES usuario (id)    ON DELETE CASCADE,
    CONSTRAINT fk_notificacao_ocorrencia FOREIGN KEY (ocorrencia_id) REFERENCES ocorrencia (id) ON DELETE CASCADE,
    CONSTRAINT fk_notificacao_alerta     FOREIGN KEY (alerta_id)     REFERENCES alerta (id)     ON DELETE CASCADE,
    CONSTRAINT ck_notificacao_lida CHECK ((lida AND lida_em IS NOT NULL) OR (NOT lida AND lida_em IS NULL))
);

COMMENT ON TABLE notificacao IS 'Notificações in-app enviadas aos usuários.';
