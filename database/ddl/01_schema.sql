-- =============================================================================
-- SafeTech — Segurança em Praças Públicas
-- 01_schema.sql : schema, extensões e tipos enumerados
-- SGBD alvo: PostgreSQL 15+
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS safetech;
SET search_path TO safetech, public;

-- Observação: gen_random_uuid() é nativo a partir do PostgreSQL 13; nenhuma extensão é necessária.
-- O hash de senha é responsabilidade da aplicação (bcrypt/argon2), não do banco.

-- -----------------------------------------------------------------------------
-- Tipos enumerados
-- -----------------------------------------------------------------------------

-- Perfis de acesso da plataforma
CREATE TYPE safetech.perfil_usuario AS ENUM (
    'CIDADAO',      -- registra ocorrências e avalia praças
    'AGENTE',       -- guarda municipal / equipe de campo: atende ocorrências e faz rondas
    'GESTOR',       -- gestor público: acompanha indicadores e distribui atendimentos
    'ADMIN'         -- administra usuários, praças e equipamentos
);

-- Ciclo de vida de uma ocorrência
CREATE TYPE safetech.status_ocorrencia AS ENUM (
    'ABERTA',
    'EM_ANALISE',
    'EM_ATENDIMENTO',
    'RESOLVIDA',
    'CANCELADA'
);

-- Gravidade de ocorrências e alertas
CREATE TYPE safetech.nivel_gravidade AS ENUM (
    'BAIXA',
    'MEDIA',
    'ALTA',
    'CRITICA'
);

-- Tipos de equipamentos de segurança instalados nas praças
CREATE TYPE safetech.tipo_equipamento AS ENUM (
    'CAMERA',
    'ILUMINACAO',
    'BOTAO_PANICO',
    'TOTEM',
    'SENSOR_PRESENCA',
    'SENSOR_RUIDO'
);

-- Situação operacional de um equipamento
CREATE TYPE safetech.status_equipamento AS ENUM (
    'OPERANTE',
    'INOPERANTE',
    'EM_MANUTENCAO',
    'DESATIVADO'
);

-- Origem de um alerta
CREATE TYPE safetech.origem_alerta AS ENUM (
    'EQUIPAMENTO',  -- gerado automaticamente por sensor/câmera/iluminação
    'BOTAO_PANICO', -- acionado por cidadão no local
    'MANUAL'        -- registrado por agente/gestor
);

-- Situação de um alerta
CREATE TYPE safetech.status_alerta AS ENUM (
    'NOVO',
    'RECONHECIDO',
    'ENCERRADO',
    'FALSO_POSITIVO'
);

-- Tipo de mídia anexada a uma ocorrência
CREATE TYPE safetech.tipo_midia AS ENUM (
    'IMAGEM',
    'VIDEO',
    'AUDIO',
    'DOCUMENTO'
);

-- Situação de uma ronda
CREATE TYPE safetech.status_ronda AS ENUM (
    'AGENDADA',
    'EM_ANDAMENTO',
    'CONCLUIDA',
    'CANCELADA'
);
