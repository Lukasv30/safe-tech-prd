-- =============================================================================
-- 08_rpc.sql : funções de negócio expostas como RPC (POST /rest/v1/rpc/<nome>)
-- Todas rodam como SECURITY DEFINER e validam o usuário com auth.uid()/perfil.
-- =============================================================================

SET search_path TO safetech, public;

-- -----------------------------------------------------------------------------
-- registrar_ocorrencia : cidadão ou agente registra uma ocorrência
-- Retorna id e protocolo gerado.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION safetech.registrar_ocorrencia(
    p_praca_id      UUID,
    p_categoria_id  INTEGER,
    p_titulo        TEXT,
    p_descricao     TEXT,
    p_gravidade     nivel_gravidade DEFAULT NULL,
    p_anonima       BOOLEAN DEFAULT FALSE,
    p_latitude      NUMERIC DEFAULT NULL,
    p_longitude     NUMERIC DEFAULT NULL,
    p_ocorrida_em   TIMESTAMPTZ DEFAULT NOW()
)
RETURNS TABLE (id UUID, protocolo VARCHAR, status status_ocorrencia)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = safetech, public
AS $$
DECLARE
    v_autor     UUID := auth.uid();
    v_gravidade nivel_gravidade;
BEGIN
    IF v_autor IS NULL AND NOT p_anonima THEN
        RAISE EXCEPTION 'É necessário estar autenticado para registrar uma ocorrência identificada'
            USING ERRCODE = '42501';
    END IF;

    SELECT COALESCE(p_gravidade, c.gravidade_padrao) INTO v_gravidade
      FROM categoria_ocorrencia c WHERE c.id = p_categoria_id AND c.ativa;

    IF v_gravidade IS NULL THEN
        RAISE EXCEPTION 'Categoria % inexistente ou inativa', p_categoria_id USING ERRCODE = '22023';
    END IF;

    PERFORM set_config('safetech.usuario_id', COALESCE(v_autor::text, ''), true);

    RETURN QUERY
    INSERT INTO ocorrencia (praca_id, categoria_id, autor_id, titulo, descricao, gravidade, anonima, latitude, longitude, ocorrida_em)
    VALUES (p_praca_id, p_categoria_id, v_autor, p_titulo, p_descricao, v_gravidade, p_anonima, p_latitude, p_longitude, p_ocorrida_em)
    RETURNING ocorrencia.id, ocorrencia.protocolo, ocorrencia.status;
END;
$$;

-- -----------------------------------------------------------------------------
-- consultar_protocolo : consulta pública do andamento pelo número do protocolo
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION safetech.consultar_protocolo(p_protocolo TEXT)
RETURNS JSONB
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = safetech, public
AS $$
    SELECT jsonb_build_object(
        'protocolo',   o.protocolo,
        'titulo',      o.titulo,
        'status',      o.status,
        'gravidade',   o.gravidade,
        'praca',       p.nome,
        'categoria',   c.nome,
        'ocorrida_em', o.ocorrida_em,
        'resolvida_em',o.resolvida_em,
        'historico',   COALESCE((
            SELECT jsonb_agg(jsonb_build_object(
                       'de', h.status_anterior, 'para', h.status_novo,
                       'observacao', h.observacao, 'em', h.alterado_em)
                   ORDER BY h.alterado_em)
              FROM historico_ocorrencia h WHERE h.ocorrencia_id = o.id), '[]'::jsonb)
    )
    FROM ocorrencia o
    JOIN praca p ON p.id = o.praca_id
    JOIN categoria_ocorrencia c ON c.id = o.categoria_id
    WHERE o.protocolo = upper(trim(p_protocolo));
$$;

-- -----------------------------------------------------------------------------
-- atualizar_status_ocorrencia : equipe muda o status (gera histórico com autor)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION safetech.atualizar_status_ocorrencia(
    p_ocorrencia_id UUID,
    p_status        status_ocorrencia,
    p_observacao    TEXT DEFAULT NULL
)
RETURNS SETOF ocorrencia
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = safetech, public
AS $$
BEGIN
    IF NOT eh_equipe() THEN
        RAISE EXCEPTION 'Apenas agentes, gestores ou administradores podem alterar o status' USING ERRCODE = '42501';
    END IF;

    PERFORM set_config('safetech.usuario_id', auth.uid()::text, true);

    UPDATE ocorrencia SET status = p_status WHERE id = p_ocorrencia_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Ocorrência % não encontrada', p_ocorrencia_id USING ERRCODE = 'P0002';
    END IF;

    IF p_observacao IS NOT NULL THEN
        UPDATE historico_ocorrencia h SET observacao = p_observacao
         WHERE h.id = (SELECT max(id) FROM historico_ocorrencia WHERE ocorrencia_id = p_ocorrencia_id);
    END IF;

    RETURN QUERY SELECT * FROM ocorrencia WHERE id = p_ocorrencia_id;
END;
$$;

-- -----------------------------------------------------------------------------
-- atribuir_atendimento : gestor/agente atribui a ocorrência a um agente
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION safetech.atribuir_atendimento(
    p_ocorrencia_id UUID,
    p_agente_id     UUID DEFAULT NULL   -- NULL = o próprio usuário logado assume
)
RETURNS SETOF atendimento
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = safetech, public
AS $$
DECLARE
    v_id UUID;
BEGIN
    IF NOT eh_equipe() THEN
        RAISE EXCEPTION 'Apenas a equipe pode atribuir atendimentos' USING ERRCODE = '42501';
    END IF;

    PERFORM set_config('safetech.usuario_id', auth.uid()::text, true);

    INSERT INTO atendimento (ocorrencia_id, agente_id, atribuido_por)
    VALUES (p_ocorrencia_id, COALESCE(p_agente_id, auth.uid()), auth.uid())
    RETURNING id INTO v_id;

    RETURN QUERY SELECT * FROM atendimento WHERE id = v_id;
END;
$$;

-- -----------------------------------------------------------------------------
-- finalizar_atendimento : agente encerra o atendimento com relato
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION safetech.finalizar_atendimento(
    p_atendimento_id UUID,
    p_relato         TEXT,
    p_resolver       BOOLEAN DEFAULT TRUE
)
RETURNS SETOF atendimento
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = safetech, public
AS $$
DECLARE
    v_ocorrencia UUID;
BEGIN
    IF NOT eh_equipe() THEN
        RAISE EXCEPTION 'Apenas a equipe pode finalizar atendimentos' USING ERRCODE = '42501';
    END IF;

    UPDATE atendimento
       SET finalizado_em = NOW(), relato = p_relato
     WHERE id = p_atendimento_id AND finalizado_em IS NULL
    RETURNING ocorrencia_id INTO v_ocorrencia;

    IF v_ocorrencia IS NULL THEN
        RAISE EXCEPTION 'Atendimento % não encontrado ou já finalizado', p_atendimento_id USING ERRCODE = 'P0002';
    END IF;

    IF p_resolver THEN
        PERFORM set_config('safetech.usuario_id', auth.uid()::text, true);
        UPDATE ocorrencia SET status = 'RESOLVIDA' WHERE id = v_ocorrencia;
    END IF;

    RETURN QUERY SELECT * FROM atendimento WHERE id = p_atendimento_id;
END;
$$;

-- -----------------------------------------------------------------------------
-- reconhecer_alerta : equipe reconhece / encerra / marca falso positivo
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION safetech.reconhecer_alerta(
    p_alerta_id UUID,
    p_status    status_alerta DEFAULT 'RECONHECIDO'
)
RETURNS SETOF alerta
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = safetech, public
AS $$
BEGIN
    IF NOT eh_equipe() THEN
        RAISE EXCEPTION 'Apenas a equipe pode tratar alertas' USING ERRCODE = '42501';
    END IF;

    IF p_status = 'NOVO' THEN
        RAISE EXCEPTION 'Status inválido para reconhecimento' USING ERRCODE = '22023';
    END IF;

    UPDATE alerta
       SET status          = p_status,
           reconhecido_por = COALESCE(reconhecido_por, auth.uid()),
           reconhecido_em  = COALESCE(reconhecido_em, NOW()),
           encerrado_em    = CASE WHEN p_status IN ('ENCERRADO', 'FALSO_POSITIVO') THEN NOW() ELSE encerrado_em END
     WHERE id = p_alerta_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Alerta % não encontrado', p_alerta_id USING ERRCODE = 'P0002';
    END IF;

    RETURN QUERY SELECT * FROM alerta WHERE id = p_alerta_id;
END;
$$;

-- -----------------------------------------------------------------------------
-- acionar_botao_panico : qualquer pessoa (até sem login) aciona o botão de um
-- equipamento; cria alerta CRITICO e notifica toda a equipe.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION safetech.acionar_botao_panico(
    p_equipamento_codigo TEXT,
    p_mensagem           TEXT DEFAULT NULL
)
RETURNS SETOF alerta
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = safetech, public
AS $$
DECLARE
    v_equip   equipamento%ROWTYPE;
    v_alerta  UUID;
BEGIN
    SELECT * INTO v_equip FROM equipamento
     WHERE codigo = p_equipamento_codigo AND tipo IN ('BOTAO_PANICO', 'TOTEM') AND status = 'OPERANTE';

    IF v_equip.id IS NULL THEN
        RAISE EXCEPTION 'Equipamento % não é um botão de pânico operante', p_equipamento_codigo USING ERRCODE = '22023';
    END IF;

    INSERT INTO alerta (praca_id, equipamento_id, origem, gravidade, mensagem)
    VALUES (v_equip.praca_id, v_equip.id, 'BOTAO_PANICO', 'CRITICA',
            COALESCE(p_mensagem, 'Botão de pânico acionado em ' || COALESCE(v_equip.localizacao, v_equip.codigo)))
    RETURNING id INTO v_alerta;

    INSERT INTO notificacao (usuario_id, alerta_id, titulo, mensagem)
    SELECT u.id, v_alerta, 'Botão de pânico acionado',
           (SELECT p.nome || ': ' || a.mensagem FROM alerta a JOIN praca p ON p.id = a.praca_id WHERE a.id = v_alerta)
      FROM usuario u WHERE u.perfil IN ('AGENTE', 'GESTOR') AND u.ativo;

    RETURN QUERY SELECT * FROM alerta WHERE id = v_alerta;
END;
$$;

-- -----------------------------------------------------------------------------
-- minhas_ocorrencias (contribuição própria) : ocorrências do usuário logado,
-- mais recentes primeiro. Exige autenticação.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION safetech.minhas_ocorrencias()
RETURNS SETOF ocorrencia
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = safetech, public
AS $$
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'É necessário estar autenticado para listar suas ocorrências' USING ERRCODE = '42501';
    END IF;

    RETURN QUERY
    SELECT o.* FROM ocorrencia o
     WHERE o.autor_id = auth.uid()
     ORDER BY o.ocorrida_em DESC;
END;
$$;

-- -----------------------------------------------------------------------------
-- Permissões: quem pode chamar cada RPC
-- -----------------------------------------------------------------------------
GRANT EXECUTE ON FUNCTION safetech.consultar_protocolo(TEXT)              TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION safetech.acionar_botao_panico(TEXT, TEXT)       TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION safetech.registrar_ocorrencia(UUID, INTEGER, TEXT, TEXT, nivel_gravidade, BOOLEAN, NUMERIC, NUMERIC, TIMESTAMPTZ)
                                                                            TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION safetech.atualizar_status_ocorrencia(UUID, status_ocorrencia, TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION safetech.atribuir_atendimento(UUID, UUID)       TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION safetech.finalizar_atendimento(UUID, TEXT, BOOLEAN) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION safetech.reconhecer_alerta(UUID, status_alerta) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION safetech.minhas_ocorrencias()                   TO authenticated, service_role;
