-- =============================================================================
-- SafeTech — Segurança em Praças Públicas
-- 03_indexes.sql : índices de apoio às consultas mais frequentes
-- =============================================================================
SET search_path TO safetech, public;

-- usuario
CREATE INDEX idx_usuario_perfil             ON usuario (perfil) WHERE ativo;

-- praca
CREATE INDEX idx_praca_cidade_bairro        ON praca (cidade, bairro);
CREATE INDEX idx_praca_geo                  ON praca (latitude, longitude);

-- equipamento
CREATE INDEX idx_equipamento_praca          ON equipamento (praca_id);
CREATE INDEX idx_equipamento_tipo_status    ON equipamento (tipo, status);

-- ocorrencia
CREATE INDEX idx_ocorrencia_praca           ON ocorrencia (praca_id);
CREATE INDEX idx_ocorrencia_categoria       ON ocorrencia (categoria_id);
CREATE INDEX idx_ocorrencia_autor           ON ocorrencia (autor_id);
CREATE INDEX idx_ocorrencia_status          ON ocorrencia (status);
CREATE INDEX idx_ocorrencia_ocorrida_em     ON ocorrencia (ocorrida_em DESC);
CREATE INDEX idx_ocorrencia_abertas         ON ocorrencia (praca_id, gravidade)
    WHERE status IN ('ABERTA', 'EM_ANALISE', 'EM_ATENDIMENTO');

-- anexo_ocorrencia
CREATE INDEX idx_anexo_ocorrencia           ON anexo_ocorrencia (ocorrencia_id);

-- historico_ocorrencia
CREATE INDEX idx_historico_ocorrencia       ON historico_ocorrencia (ocorrencia_id, alterado_em);

-- atendimento
CREATE INDEX idx_atendimento_ocorrencia     ON atendimento (ocorrencia_id);
CREATE INDEX idx_atendimento_agente_ativo   ON atendimento (agente_id) WHERE finalizado_em IS NULL;

-- alerta
CREATE INDEX idx_alerta_praca_status        ON alerta (praca_id, status);
CREATE INDEX idx_alerta_equipamento         ON alerta (equipamento_id);
CREATE INDEX idx_alerta_criado_em           ON alerta (criado_em DESC);

-- ronda
CREATE INDEX idx_ronda_praca_agendada       ON ronda (praca_id, agendada_para);
CREATE INDEX idx_ronda_agente_status        ON ronda (agente_id, status);

-- avaliacao_praca
CREATE INDEX idx_avaliacao_praca            ON avaliacao_praca (praca_id);

-- notificacao
CREATE INDEX idx_notificacao_usuario_nao_lida ON notificacao (usuario_id, criado_em DESC) WHERE NOT lida;
