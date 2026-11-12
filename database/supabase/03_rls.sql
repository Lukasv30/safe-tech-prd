SET search_path TO safetech, public;

ALTER TABLE usuario              ENABLE ROW LEVEL SECURITY;
ALTER TABLE praca                ENABLE ROW LEVEL SECURITY;
ALTER TABLE equipamento          ENABLE ROW LEVEL SECURITY;
ALTER TABLE categoria_ocorrencia ENABLE ROW LEVEL SECURITY;
ALTER TABLE ocorrencia           ENABLE ROW LEVEL SECURITY;
ALTER TABLE anexo_ocorrencia     ENABLE ROW LEVEL SECURITY;
ALTER TABLE historico_ocorrencia ENABLE ROW LEVEL SECURITY;
ALTER TABLE atendimento          ENABLE ROW LEVEL SECURITY;
ALTER TABLE alerta               ENABLE ROW LEVEL SECURITY;
ALTER TABLE ronda                ENABLE ROW LEVEL SECURITY;
ALTER TABLE avaliacao_praca      ENABLE ROW LEVEL SECURITY;
ALTER TABLE notificacao          ENABLE ROW LEVEL SECURITY;

-- usuario: vê o próprio perfil; equipe vê todos; cada um edita o próprio; admin edita todos
CREATE POLICY usuario_select ON usuario FOR SELECT TO authenticated
    USING (id = auth.uid() OR eh_equipe());
CREATE POLICY usuario_update ON usuario FOR UPDATE TO authenticated
    USING (id = auth.uid() OR perfil_atual() = 'ADMIN')
    WITH CHECK (id = auth.uid() OR perfil_atual() = 'ADMIN');

-- praca / categoria: leitura pública; escrita só gestor/admin
CREATE POLICY praca_select ON praca FOR SELECT TO anon, authenticated USING (TRUE);
CREATE POLICY praca_write  ON praca FOR ALL    TO authenticated USING (eh_gestor()) WITH CHECK (eh_gestor());

CREATE POLICY categoria_select ON categoria_ocorrencia FOR SELECT TO anon, authenticated USING (TRUE);
CREATE POLICY categoria_write  ON categoria_ocorrencia FOR ALL    TO authenticated USING (eh_gestor()) WITH CHECK (eh_gestor());

-- equipamento: logados leem; gestor/admin escreve
CREATE POLICY equipamento_select ON equipamento FOR SELECT TO authenticated USING (TRUE);
CREATE POLICY equipamento_write  ON equipamento FOR ALL    TO authenticated USING (eh_gestor()) WITH CHECK (eh_gestor());

-- ocorrencia: cidadão vê as não anônimas e as suas; equipe vê todas.
-- Inserção direta: só identificada e como autor (anônimas passam pela RPC). Alteração: equipe.
CREATE POLICY ocorrencia_select ON ocorrencia FOR SELECT TO authenticated
    USING (NOT anonima OR autor_id = auth.uid() OR eh_equipe());
CREATE POLICY ocorrencia_insert ON ocorrencia FOR INSERT TO authenticated
    WITH CHECK (autor_id = auth.uid() AND NOT anonima);
CREATE POLICY ocorrencia_update ON ocorrencia FOR UPDATE TO authenticated
    USING (eh_equipe()) WITH CHECK (eh_equipe());

-- anexo: quem vê a ocorrência vê o anexo; quem envia é o próprio usuário
CREATE POLICY anexo_select ON anexo_ocorrencia FOR SELECT TO authenticated
    USING (EXISTS (SELECT 1 FROM ocorrencia o WHERE o.id = ocorrencia_id));
CREATE POLICY anexo_insert ON anexo_ocorrencia FOR INSERT TO authenticated
    WITH CHECK (enviado_por = auth.uid());

-- historico: quem vê a ocorrência vê o histórico (a trigger grava via sistema)
CREATE POLICY historico_select ON historico_ocorrencia FOR SELECT TO authenticated
    USING (EXISTS (SELECT 1 FROM ocorrencia o WHERE o.id = ocorrencia_id));

-- atendimento / ronda / alerta: somente equipe
CREATE POLICY atendimento_equipe ON atendimento FOR ALL TO authenticated USING (eh_equipe()) WITH CHECK (eh_equipe());
CREATE POLICY ronda_equipe       ON ronda       FOR ALL TO authenticated USING (eh_equipe()) WITH CHECK (eh_equipe());
CREATE POLICY alerta_equipe      ON alerta      FOR ALL TO authenticated USING (eh_equipe()) WITH CHECK (eh_equipe());

-- avaliacao: leitura pública; cada cidadão insere/edita a própria
CREATE POLICY avaliacao_select ON avaliacao_praca FOR SELECT TO anon, authenticated USING (TRUE);
CREATE POLICY avaliacao_insert ON avaliacao_praca FOR INSERT TO authenticated WITH CHECK (usuario_id = auth.uid());
CREATE POLICY avaliacao_update ON avaliacao_praca FOR UPDATE TO authenticated USING (usuario_id = auth.uid());
CREATE POLICY avaliacao_delete ON avaliacao_praca FOR DELETE TO authenticated USING (usuario_id = auth.uid());

-- notificacao: cada um vê e marca como lida as suas
CREATE POLICY notificacao_select ON notificacao FOR SELECT TO authenticated USING (usuario_id = auth.uid());
CREATE POLICY notificacao_update ON notificacao FOR UPDATE TO authenticated
    USING (usuario_id = auth.uid()) WITH CHECK (usuario_id = auth.uid());

-- Views: vw_alerta_pendente só para logados (dados sensíveis); as outras já estão em 06.
GRANT SELECT ON safetech.vw_ocorrencia_aberta, safetech.vw_alerta_pendente TO authenticated;
REVOKE SELECT ON safetech.vw_alerta_pendente FROM anon;