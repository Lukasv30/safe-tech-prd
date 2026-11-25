-- =============================================================================
-- limpar_e2e.sql : remove os registros criados pelo teste ponta a ponta (prefixo [E2E])
-- Rodar no SQL Editor do Supabase ANTES de uma apresentação, depois do último e2e.
-- Nenhuma política RLS permite apagar ocorrências/alertas pela API, por isso é só por SQL.
-- =============================================================================
SET search_path TO safetech, public;

DELETE FROM notificacao
 WHERE alerta_id IN (SELECT id FROM alerta WHERE mensagem LIKE '[E2E]%')
    OR ocorrencia_id IN (SELECT id FROM ocorrencia WHERE titulo LIKE '[E2E]%');

DELETE FROM alerta     WHERE mensagem LIKE '[E2E]%';
DELETE FROM ocorrencia WHERE titulo   LIKE '[E2E]%';   -- anexos, histórico e atendimentos caem em cascata
DELETE FROM avaliacao_praca WHERE comentario LIKE '[E2E]%';
DELETE FROM praca      WHERE nome     LIKE '[E2E]%';

-- Arquivos de teste no bucket: o Storage não permite DELETE direto em storage.objects.
-- Apague a pasta e2e/ pelo painel (Storage > anexos) se sobrar algo; o e2e já remove o que envia.

-- Conferência: tudo deve dar 0
SELECT (SELECT COUNT(*) FROM ocorrencia WHERE titulo LIKE '[E2E]%')   AS ocorrencias,
       (SELECT COUNT(*) FROM alerta     WHERE mensagem LIKE '[E2E]%') AS alertas;
