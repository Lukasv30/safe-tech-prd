GRANT USAGE ON SCHEMA safetech TO anon, authenticated, service_role;

-- Leitura pública (sem login): catálogo e resumo das praças
GRANT SELECT ON safetech.praca, safetech.categoria_ocorrencia, safetech.vw_praca_resumo TO anon;

-- Usuário logado: acesso às tabelas; o que cada um pode ver/alterar é definido pelo RLS (09_rls.sql)
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA safetech TO authenticated;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA safetech TO authenticated;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA safetech TO authenticated;

-- Chave service_role (usada só no servidor / Edge Functions): acesso total, ignora RLS
GRANT ALL ON ALL TABLES IN SCHEMA safetech TO service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA safetech TO service_role;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA safetech TO service_role;

-- Objetos criados no futuro herdam as permissões
ALTER DEFAULT PRIVILEGES IN SCHEMA safetech GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA safetech GRANT USAGE, SELECT ON SEQUENCES TO authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA safetech GRANT EXECUTE ON FUNCTIONS TO authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA safetech GRANT ALL ON TABLES TO service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA safetech GRANT ALL ON SEQUENCES TO service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA safetech GRANT EXECUTE ON FUNCTIONS TO service_role;