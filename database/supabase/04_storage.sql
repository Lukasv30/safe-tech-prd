CREATE POLICY "anexos_upload_logado" ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'anexos');

-- Cada um apaga só o que enviou
CREATE POLICY "anexos_delete_dono" ON storage.objects
    FOR DELETE TO authenticated
    USING (bucket_id = 'anexos' AND owner = auth.uid());