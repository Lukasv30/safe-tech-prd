SET search_path TO safetech, public;

ALTER TABLE usuario ALTER COLUMN senha_hash DROP NOT NULL;
COMMENT ON COLUMN usuario.senha_hash IS 'Não utilizado com Supabase Auth (senha fica em auth.users). Mantido para compatibilidade.';

-- Cria o perfil em safetech.usuario quando alguém se cadastra no Auth.
-- O front envia { nome, telefone } em options.data no signUp.
CREATE OR REPLACE FUNCTION safetech.handle_new_auth_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = safetech, public
AS $$
BEGIN
    INSERT INTO usuario (id, nome, email, telefone, perfil)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data ->> 'nome', split_part(NEW.email, '@', 1)),
        NEW.email,
        NEW.raw_user_meta_data ->> 'telefone',
        'CIDADAO'
    )
    ON CONFLICT (id) DO UPDATE SET email = EXCLUDED.email;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_auth_user_created ON auth.users;
CREATE TRIGGER trg_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION safetech.handle_new_auth_user();

-- Funções auxiliares usadas pelo RLS e pelas RPCs
CREATE OR REPLACE FUNCTION safetech.perfil_atual()
RETURNS perfil_usuario
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = safetech, public
AS $$
    SELECT perfil FROM usuario WHERE id = auth.uid() AND ativo;
$$;

CREATE OR REPLACE FUNCTION safetech.eh_equipe()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = safetech, public
AS $$
    SELECT COALESCE(perfil_atual() IN ('AGENTE', 'GESTOR', 'ADMIN'), FALSE);
$$;

CREATE OR REPLACE FUNCTION safetech.eh_gestor()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = safetech, public
AS $$
    SELECT COALESCE(perfil_atual() IN ('GESTOR', 'ADMIN'), FALSE);
$$;

GRANT EXECUTE ON FUNCTION safetech.perfil_atual(), safetech.eh_equipe(), safetech.eh_gestor() TO anon, authenticated, service_role;