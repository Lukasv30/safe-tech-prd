-- =============================================================================
-- SafeTech — Segurança em Praças Públicas
-- 05_views.sql : views de apoio ao dashboard e às listagens
-- =============================================================================
SET search_path TO safetech, public;

-- Ocorrências em aberto com dados da praça, categoria e autor (respeita anonimato)
CREATE OR REPLACE VIEW vw_ocorrencia_aberta AS
SELECT
    o.id,
    o.protocolo,
    o.titulo,
    o.gravidade,
    o.status,
    o.ocorrida_em,
    o.criado_em,
    p.id            AS praca_id,
    p.nome          AS praca_nome,
    p.bairro,
    p.cidade,
    c.nome          AS categoria,
    CASE WHEN o.anonima THEN 'Anônimo' ELSE u.nome END AS autor,
    (SELECT COUNT(*) FROM anexo_ocorrencia a WHERE a.ocorrencia_id = o.id) AS qtd_anexos
FROM ocorrencia o
JOIN praca p                ON p.id = o.praca_id
JOIN categoria_ocorrencia c ON c.id = o.categoria_id
LEFT JOIN usuario u         ON u.id = o.autor_id
WHERE o.status IN ('ABERTA', 'EM_ANALISE', 'EM_ATENDIMENTO');

-- Resumo por praça para o dashboard do gestor
CREATE OR REPLACE VIEW vw_praca_resumo AS
SELECT
    p.id,
    p.nome,
    p.bairro,
    p.cidade,
    p.latitude,
    p.longitude,
    p.ativa,
    (SELECT COUNT(*) FROM ocorrencia o
      WHERE o.praca_id = p.id
        AND o.status IN ('ABERTA', 'EM_ANALISE', 'EM_ATENDIMENTO'))                     AS ocorrencias_abertas,
    (SELECT COUNT(*) FROM ocorrencia o
      WHERE o.praca_id = p.id
        AND o.ocorrida_em >= NOW() - INTERVAL '30 days')                               AS ocorrencias_30_dias,
    (SELECT COUNT(*) FROM alerta a
      WHERE a.praca_id = p.id AND a.status = 'NOVO')                                   AS alertas_novos,
    (SELECT COUNT(*) FROM equipamento e
      WHERE e.praca_id = p.id)                                                         AS equipamentos,
    (SELECT COUNT(*) FROM equipamento e
      WHERE e.praca_id = p.id AND e.status <> 'OPERANTE')                              AS equipamentos_com_problema,
    (SELECT ROUND(AVG(av.nota), 2) FROM avaliacao_praca av
      WHERE av.praca_id = p.id)                                                        AS nota_media_seguranca,
    (SELECT COUNT(*) FROM avaliacao_praca av
      WHERE av.praca_id = p.id)                                                        AS qtd_avaliacoes
FROM praca p;

-- Alertas pendentes (NOVO) com equipamento e praça
CREATE OR REPLACE VIEW vw_alerta_pendente AS
SELECT
    a.id,
    a.origem,
    a.gravidade,
    a.mensagem,
    a.criado_em,
    p.id        AS praca_id,
    p.nome      AS praca_nome,
    e.tipo      AS equipamento_tipo,
    e.codigo    AS equipamento_codigo
FROM alerta a
JOIN praca p            ON p.id = a.praca_id
LEFT JOIN equipamento e ON e.id = a.equipamento_id
WHERE a.status = 'NOVO';
