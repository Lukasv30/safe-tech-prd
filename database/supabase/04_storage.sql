-- =============================================================================
-- 04_storage.sql : bucket "anexos" (fotos/vídeos das ocorrências)
-- O bucket é criado no painel (Storage > New bucket > "anexos", Public bucket LIGADO).
-- Leitura pública pela URL /storage/v1/object/public/anexos/<caminho>; upload só logado.
-- =============================================================================

-- Garante que o bucket é público (equivale a marcar "Public bucket" no painel)
UPDATE storage.buckets SET public = TRUE WHERE id = 'anexos';

-- Upload apenas para usuários logados, dentro do bucket anexos
DROP POLICY IF EXISTS "anexos_upload_logado" ON storage.objects;
CREATE POLICY "anexos_upload_logado" ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'anexos');

-- Cada um apaga só o que enviou.
-- Obs.: a coluna "owner" (uuid) está obsoleta no Storage e fica vazia; o Storage atual preenche "owner_id" (text).
DROP POLICY IF EXISTS "anexos_delete_dono" ON storage.objects;
CREATE POLICY "anexos_delete_dono" ON storage.objects
    FOR DELETE TO authenticated
    USING (bucket_id = 'anexos' AND owner_id = auth.uid()::text);

-- O Storage exige SELECT além de DELETE para apagar (e para listar) objetos; leitura pública já vem pelo bucket público.
DROP POLICY IF EXISTS "anexos_select_logado" ON storage.objects;
CREATE POLICY "anexos_select_logado" ON storage.objects
    FOR SELECT TO authenticated
    USING (bucket_id = 'anexos');
