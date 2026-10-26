-- Remove completamente o schema safetech (tabelas, tipos, funções e views).
-- USO EXCLUSIVO EM DESENVOLVIMENTO.
-- psql -U postgres -d safetech -f database/scripts/drop_all.sql
DROP SCHEMA IF EXISTS safetech CASCADE;
