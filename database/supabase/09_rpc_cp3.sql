-- =============================================================================
-- 09_rpc_cp3.sql : funções de negócio do Checkpoint 3 (MVP)
-- Expostas como RPC em POST /rest/v1/rpc/<nome>. SECURITY DEFINER + validação por auth.uid()/perfil.
-- =============================================================================
SET search_path TO safetech, public;

-- -----------------------------------------------------------------------------
-- detalhe_praca : tudo que a tela "Detalhe da praça" precisa em uma chamada (pública).
-- Nunca expõe autor de ocorrência (anonimato) nem dados pessoais além do primeiro nome do avaliador.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION safetech.detalhe_praca(p_praca_id UUID)
RETURNS JSONB
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = safetech, public
AS $$
    SELECT jsonb_build_object(
        'praca', (SELECT to_jsonb(p) - 'criado_em' - 'atualizado_em' FROM praca p WHERE p.id = p_praca_id),
        'resumo', (SELECT to_jsonb(r) FROM vw_praca_resumo r WHERE r.id = p_praca_id),
        'equipamentos', COALESCE((
            SELECT jsonb_agg(jsonb_build_object(
                       'id', e.id, 'tipo', e.tipo, 'codigo', e.codigo, 'descricao', e.descricao,
                       'localizacao', e.localizacao, 'status', e.status) ORDER BY e.tipo, e.codigo)
              FROM equipamento e WHERE e.praca_id = p_praca_id), '[]'::jsonb),
        'ocorrencias_abertas', COALESCE((
            SELECT jsonb_agg(jsonb_build_object(
                       'protocolo', o.protocolo, 'titulo', o.titulo, 'categoria', c.nome,
                       'gravidade', o.gravidade, 'status', o.status, 'ocorrida_em', o.ocorrida_em) ORDER BY o.ocorrida_em DESC)
              FROM ocorrencia o JOIN categoria_ocorrencia c ON c.id = o.categoria_id
             WHERE o.praca_id = p_praca_id AND o.status IN ('ABERTA', 'EM_ANALISE', 'EM_ATENDIMENTO')), '[]'::jsonb),
        'avaliacoes', COALESCE((
            SELECT jsonb_agg(jsonb_build_object(
                       'nota', a.nota, 'comentario', a.comentario, 'criado_em', a.criado_em,
                       'autor', split_part(u.nome, ' ', 1),
                       'minha', a.usuario_id = auth.uid()) ORDER BY a.criado_em DESC)
              FROM (SELECT * FROM avaliacao_praca av WHERE av.praca_id = p_praca_id ORDER BY av.criado_em DESC LIMIT 10) a
              JOIN usuario u ON u.id = a.usuario_id), '[]'::jsonb)
    )
    WHERE EXISTS (SELECT 1 FROM praca WHERE id = p_praca_id);
$$;

-- -----------------------------------------------------------------------------
-- avaliar_praca : cidadão logado dá nota 1..5 à praça. Uma avaliação por usuário/praça:
-- se já existir, atualiza. Retorna a avaliação gravada.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION safetech.avaliar_praca(
    p_praca_id   UUID,
    p_nota       SMALLINT,
    p_comentario TEXT DEFAULT NULL
)
RETURNS SETOF avaliacao_praca
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = safetech, public
AS $$
DECLARE
    v_usuario UUID := auth.uid();
    v_id      UUID;
BEGIN
    IF v_usuario IS NULL THEN
        RAISE EXCEPTION 'É necessário estar autenticado para avaliar uma praça' USING ERRCODE = '42501';
    END IF;
    IF p_nota IS NULL OR p_nota NOT BETWEEN 1 AND 5 THEN
        RAISE EXCEPTION 'A nota deve ser um inteiro de 1 a 5' USING ERRCODE = '22023';
    END IF;

    SELECT id INTO v_id FROM avaliacao_praca WHERE praca_id = p_praca_id AND usuario_id = v_usuario;

    IF v_id IS NULL THEN
        INSERT INTO avaliacao_praca (praca_id, usuario_id, nota, comentario)
        VALUES (p_praca_id, v_usuario, p_nota, NULLIF(TRIM(p_comentario), ''))
        RETURNING id INTO v_id;
    ELSE
        UPDATE avaliacao_praca
           SET nota = p_nota, comentario = NULLIF(TRIM(p_comentario), ''), criado_em = NOW()
         WHERE id = v_id;
    END IF;

    RETURN QUERY SELECT * FROM avaliacao_praca WHERE id = v_id;
END;
$$;

-- -----------------------------------------------------------------------------
-- registrar_anexo : vincula um arquivo já enviado ao Storage (bucket anexos) a uma ocorrência.
-- Só o autor da ocorrência ou a equipe podem anexar.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION safetech.registrar_anexo(
    p_ocorrencia_id UUID,
    p_url           TEXT,
    p_nome_arquivo  TEXT DEFAULT NULL,
    p_tamanho_bytes BIGINT DEFAULT NULL,
    p_tipo          tipo_midia DEFAULT 'IMAGEM'
)
RETURNS SETOF anexo_ocorrencia
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = safetech, public
AS $$
DECLARE
    v_usuario UUID := auth.uid();
    v_autor   UUID;
    v_id      UUID;
BEGIN
    IF v_usuario IS NULL THEN
        RAISE EXCEPTION 'É necessário estar autenticado para anexar arquivos' USING ERRCODE = '42501';
    END IF;

    SELECT autor_id INTO v_autor FROM ocorrencia WHERE id = p_ocorrencia_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Ocorrência % não encontrada', p_ocorrencia_id USING ERRCODE = 'P0002';
    END IF;
    IF v_autor IS DISTINCT FROM v_usuario AND NOT eh_equipe() THEN
        RAISE EXCEPTION 'Apenas o autor da ocorrência ou a equipe podem anexar arquivos' USING ERRCODE = '42501';
    END IF;

    INSERT INTO anexo_ocorrencia (ocorrencia_id, tipo, url, nome_arquivo, tamanho_bytes, enviado_por)
    VALUES (p_ocorrencia_id, p_tipo, p_url, p_nome_arquivo, p_tamanho_bytes, v_usuario)
    RETURNING id INTO v_id;

    RETURN QUERY SELECT * FROM anexo_ocorrencia WHERE id = v_id;
END;
$$;

-- -----------------------------------------------------------------------------
-- dashboard_resumo : indicadores do gestor em uma chamada (totais, séries e rankings).
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION safetech.dashboard_resumo(p_dias INTEGER DEFAULT 30)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = safetech, public
AS $$
DECLARE
    v_inicio TIMESTAMPTZ := NOW() - make_interval(days => GREATEST(COALESCE(p_dias, 30), 1));
    v_json   JSONB;
BEGIN
    IF NOT eh_gestor() THEN
        RAISE EXCEPTION 'Apenas gestores ou administradores acessam o dashboard' USING ERRCODE = '42501';
    END IF;

    SELECT jsonb_build_object(
        'periodo_dias', GREATEST(COALESCE(p_dias, 30), 1),
        'totais', jsonb_build_object(
            'pracas',                    (SELECT COUNT(*) FROM praca WHERE ativa),
            'ocorrencias_abertas',       (SELECT COUNT(*) FROM ocorrencia WHERE status IN ('ABERTA', 'EM_ANALISE', 'EM_ATENDIMENTO')),
            'ocorrencias_periodo',       (SELECT COUNT(*) FROM ocorrencia WHERE ocorrida_em >= v_inicio),
            'resolvidas_periodo',        (SELECT COUNT(*) FROM ocorrencia WHERE status = 'RESOLVIDA' AND resolvida_em >= v_inicio),
            'alertas_novos',             (SELECT COUNT(*) FROM alerta WHERE status = 'NOVO'),
            'equipamentos_com_problema', (SELECT COUNT(*) FROM equipamento WHERE status <> 'OPERANTE'),
            'tempo_medio_resolucao_h',   (SELECT ROUND(AVG(EXTRACT(EPOCH FROM (resolvida_em - criado_em)) / 3600)::numeric, 1)
                                            FROM ocorrencia WHERE status = 'RESOLVIDA' AND resolvida_em >= v_inicio),
            'nota_media_seguranca',      (SELECT ROUND(AVG(nota)::numeric, 2) FROM avaliacao_praca)
        ),
        'por_status', COALESCE((
            SELECT jsonb_agg(jsonb_build_object('status', s.status, 'qtd', s.qtd) ORDER BY s.qtd DESC)
              FROM (SELECT status, COUNT(*) qtd FROM ocorrencia WHERE ocorrida_em >= v_inicio GROUP BY status) s), '[]'::jsonb),
        'por_categoria', COALESCE((
            SELECT jsonb_agg(jsonb_build_object('categoria', s.nome, 'qtd', s.qtd) ORDER BY s.qtd DESC)
              FROM (SELECT c.nome, COUNT(*) qtd FROM ocorrencia o JOIN categoria_ocorrencia c ON c.id = o.categoria_id
                     WHERE o.ocorrida_em >= v_inicio GROUP BY c.nome) s), '[]'::jsonb),
        'por_gravidade', COALESCE((
            SELECT jsonb_agg(jsonb_build_object('gravidade', s.gravidade, 'qtd', s.qtd) ORDER BY s.gravidade)
              FROM (SELECT gravidade, COUNT(*) qtd FROM ocorrencia WHERE ocorrida_em >= v_inicio GROUP BY gravidade) s), '[]'::jsonb),
        'por_dia', COALESCE((
            SELECT jsonb_agg(jsonb_build_object('dia', d.dia, 'qtd', COALESCE(s.qtd, 0)) ORDER BY d.dia)
              FROM generate_series(date_trunc('day', v_inicio)::date, CURRENT_DATE, '1 day') d(dia)
              LEFT JOIN (SELECT ocorrida_em::date dia, COUNT(*) qtd FROM ocorrencia WHERE ocorrida_em >= v_inicio GROUP BY 1) s
                     ON s.dia = d.dia), '[]'::jsonb),
        'por_praca', COALESCE((
            SELECT jsonb_agg(to_jsonb(r) ORDER BY r.ocorrencias_abertas DESC, r.nome) FROM vw_praca_resumo r), '[]'::jsonb),
        'alertas_recentes', COALESCE((
            SELECT jsonb_agg(to_jsonb(a) ORDER BY a.criado_em DESC)
              FROM (SELECT * FROM vw_alerta_pendente ORDER BY criado_em DESC LIMIT 10) a), '[]'::jsonb)
    ) INTO v_json;

    RETURN v_json;
END;
$$;

-- -----------------------------------------------------------------------------
-- Permissões
-- -----------------------------------------------------------------------------
GRANT EXECUTE ON FUNCTION safetech.detalhe_praca(UUID)                                  TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION safetech.avaliar_praca(UUID, SMALLINT, TEXT)                 TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION safetech.registrar_anexo(UUID, TEXT, TEXT, BIGINT, tipo_midia) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION safetech.dashboard_resumo(INTEGER)                            TO authenticated, service_role;
