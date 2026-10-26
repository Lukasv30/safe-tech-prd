-- Cria o banco de dados do SafeTech (executar conectado ao banco "postgres").
-- psql -U postgres -f database/scripts/create_db.sql
-- O locale é herdado do template do servidor para funcionar em Windows e Linux sem ajustes.
CREATE DATABASE safetech WITH ENCODING = 'UTF8';
