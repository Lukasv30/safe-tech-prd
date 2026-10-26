-- =============================================================================
-- SafeTech — Segurança em Praças Públicas
-- 04_triggers.sql : funções e triggers
-- =============================================================================
SET search_path TO safetech, public;

-- -----------------------------------------------------------------------------
-- atualizado_em automático
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_set_atualizado_em()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.atualizado_em := NOW();
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_usuario_atualizado_em
    BEFORE UPDATE ON usuario
    FOR EACH ROW EXECUTE FUNCTION fn_set_atualizado_em();

CREATE TRIGGER trg_praca_atualizado_em
    BEFORE UPDATE ON praca
    FOR EACH ROW EXECUTE FUNCTION fn_set_atualizado_em();

CREATE TRIGGER trg_equipamento_atualizado_em
    BEFORE UPDATE ON equipamento
    FOR EACH ROW EXECUTE FUNCTION fn_set_atualizado_em();

CREATE TRIGGER trg_ocorrencia_atualizado_em
    BEFORE UPDATE ON ocorrencia
    FOR EACH ROW EXECUTE FUNCTION fn_set_atualizado_em();

-- -----------------------------------------------------------------------------
-- Geração do protocolo da ocorrência: STC-AAAA-NNNNNN
-- -----------------------------------------------------------------------------
CREATE SEQUENCE IF NOT EXISTS seq_ocorrencia_protocolo START 1;

CREATE OR REPLACE FUNCTION fn_gerar_protocolo_ocorrencia()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.protocolo IS NULL OR NEW.protocolo = '' THEN
        NEW.protocolo := 'STC-' || TO_CHAR(NOW(), 'YYYY') || '-' ||
                         LPAD(NEXTVAL('seq_ocorrencia_protocolo')::TEXT, 6, '0');
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_ocorrencia_protocolo
    BEFORE INSERT ON ocorrencia
    FOR EACH ROW EXECUTE FUNCTION fn_gerar_protocolo_ocorrencia();

-- Depois da trigger existir, o protocolo passa a ser obrigatório.
ALTER TABLE ocorrencia ALTER COLUMN protocolo SET NOT NULL;

-- -----------------------------------------------------------------------------
-- Preenche resolvida_em automaticamente ao mudar para RESOLVIDA
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_ocorrencia_resolvida_em()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.status = 'RESOLVIDA' AND NEW.resolvida_em IS NULL THEN
        NEW.resolvida_em := NOW();
    ELSIF NEW.status <> 'RESOLVIDA' THEN
        NEW.resolvida_em := NULL;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_ocorrencia_resolvida_em
    BEFORE INSERT OR UPDATE OF status ON ocorrencia
    FOR EACH ROW EXECUTE FUNCTION fn_ocorrencia_resolvida_em();

-- -----------------------------------------------------------------------------
-- Histórico de status da ocorrência
-- Grava uma linha em historico_ocorrencia na criação e a cada mudança de status.
-- A aplicação pode informar o usuário responsável pela alteração com:
--   SET LOCAL safetech.usuario_id = '<uuid>';
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_registrar_historico_ocorrencia()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_usuario UUID;
BEGIN
    BEGIN
        v_usuario := NULLIF(current_setting('safetech.usuario_id', TRUE), '')::UUID;
    EXCEPTION WHEN OTHERS THEN
        v_usuario := NULL;
    END;

    IF TG_OP = 'INSERT' THEN
        INSERT INTO historico_ocorrencia (ocorrencia_id, status_anterior, status_novo, usuario_id, observacao)
        VALUES (NEW.id, NULL, NEW.status, COALESCE(v_usuario, NEW.autor_id), 'Ocorrência registrada');
    ELSIF TG_OP = 'UPDATE' AND NEW.status IS DISTINCT FROM OLD.status THEN
        INSERT INTO historico_ocorrencia (ocorrencia_id, status_anterior, status_novo, usuario_id)
        VALUES (NEW.id, OLD.status, NEW.status, v_usuario);
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_ocorrencia_historico
    AFTER INSERT OR UPDATE OF status ON ocorrencia
    FOR EACH ROW EXECUTE FUNCTION fn_registrar_historico_ocorrencia();

-- -----------------------------------------------------------------------------
-- Garante que apenas AGENTE / GESTOR / ADMIN atendam ocorrências e façam rondas
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_validar_agente()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_perfil perfil_usuario;
BEGIN
    SELECT perfil INTO v_perfil FROM usuario WHERE id = NEW.agente_id;
    IF v_perfil IS NULL OR v_perfil = 'CIDADAO' THEN
        RAISE EXCEPTION 'Usuário % não possui perfil de agente/gestor/admin', NEW.agente_id;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_atendimento_validar_agente
    BEFORE INSERT OR UPDATE OF agente_id ON atendimento
    FOR EACH ROW EXECUTE FUNCTION fn_validar_agente();

CREATE TRIGGER trg_ronda_validar_agente
    BEFORE INSERT OR UPDATE OF agente_id ON ronda
    FOR EACH ROW EXECUTE FUNCTION fn_validar_agente();

-- -----------------------------------------------------------------------------
-- Ao atribuir um atendimento, a ocorrência passa para EM_ATENDIMENTO
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_atendimento_atualiza_ocorrencia()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE ocorrencia
       SET status = 'EM_ATENDIMENTO'
     WHERE id = NEW.ocorrencia_id
       AND status IN ('ABERTA', 'EM_ANALISE');
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_atendimento_atualiza_ocorrencia
    AFTER INSERT ON atendimento
    FOR EACH ROW EXECUTE FUNCTION fn_atendimento_atualiza_ocorrencia();
