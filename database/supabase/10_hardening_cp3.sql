-- =============================================================================
-- 10_hardening_cp3.sql : ajustes de segurança e infraestrutura do Checkpoint 3
-- =============================================================================

SET search_path TO safetech, public;

-- 1. Views que listam dados sensíveis passam a respeitar o RLS de quem consulta.
--    Sem isso, qualquer usuário logado lê alertas e todas as ocorrências abertas pela view,
--    porque a view roda com as permissões do dono (postgres). vw_praca_resumo continua
--    como está: só traz contagens e precisa ser lida por anônimos.
ALTER VIEW vw_ocorrencia_aberta SET (security_invoker = true);
ALTER VIEW vw_alerta_pendente   SET (security_invoker = true);

-- 2. Uma avaliação por usuário em cada praça (a RPC avaliar_praca atualiza em vez de duplicar).
CREATE UNIQUE INDEX IF NOT EXISTS uk_avaliacao_praca_usuario ON avaliacao_praca (praca_id, usuario_id);

-- 3. Cidadão pode apagar o próprio anexo (ex.: enviou a foto errada).
DROP POLICY IF EXISTS anexo_delete ON anexo_ocorrencia;
CREATE POLICY anexo_delete ON anexo_ocorrencia FOR DELETE TO authenticated
    USING (enviado_por = auth.uid() OR eh_equipe());

-- 4. Realtime: a tela "Alertas" assina INSERT/UPDATE em alerta e ocorrencia.
--    Só funciona no Supabase (a publicação não existe em um Postgres comum), por isso o DO.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
        IF NOT EXISTS (SELECT 1 FROM pg_publication_tables
                        WHERE pubname = 'supabase_realtime' AND schemaname = 'safetech' AND tablename = 'alerta') THEN
            ALTER PUBLICATION supabase_realtime ADD TABLE safetech.alerta;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM pg_publication_tables
                        WHERE pubname = 'supabase_realtime' AND schemaname = 'safetech' AND tablename = 'ocorrencia') THEN
            ALTER PUBLICATION supabase_realtime ADD TABLE safetech.ocorrencia;
        END IF;
    END IF;
END $$;

-- Realtime envia o registro completo em UPDATE/DELETE só com REPLICA IDENTITY FULL
ALTER TABLE alerta     REPLICA IDENTITY FULL;
ALTER TABLE ocorrencia REPLICA IDENTITY FULL;
