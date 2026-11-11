# Roteiro — Lucas Victor (Engenheiro de Dados)

**Objetivo:** colocar o banco do SafeTech no Supabase e deixar a API pronta para os outros três usarem.
**Prazo:** terça 11/11 até 20h (parte 1). Quarta 12/11 (parte 2).
**Branch:** `feat/cp2-lucas`

## Parte 1 — Hoje (destrava a equipe)

### 1. Criar o projeto no Supabase

1. Acesse https://supabase.com/dashboard, crie a organização `SafeTech` (plano Free) e o projeto `safetech-prd`,
   região **South America (São Paulo)**. Guarde a senha do banco no gerenciador de senhas (não no repo).
2. Em **Project Settings → API** anote: `Project URL`, `anon public key`, `service_role key`.
3. Convide os outros membros em **Organization → Team** (papel *Developer*).

### 2. Aplicar a DDL do Checkpoint 1

No **SQL Editor** execute, nesta ordem, o conteúdo de cada arquivo do repositório (um por vez, "Run"):

1. `database/ddl/01_schema.sql`
2. `database/ddl/02_tables.sql`
3. `database/ddl/03_indexes.sql`
4. `database/ddl/04_triggers.sql`
5. `database/ddl/05_views.sql`
6. `database/seeds/01_seed_dev.sql`

Verifique em **Table Editor** (selecione o schema `safetech` no topo) que as 12 tabelas existem e `praca` tem 3 linhas.

### 3. Expor o schema `safetech` na API

1. **Project Settings → Data API (ou API) → Exposed schemas**: adicione `safetech` (mantenha `public`). Salve.
2. Crie o arquivo `database/supabase/06_supabase_grants.sql` com o conteúdo abaixo e execute no SQL Editor.

```sql
-- =============================================================================
-- 06_supabase_grants.sql : permissões para a API do Supabase (PostgREST)
-- Pré-requisito: adicionar "safetech" em Settings > API > Exposed schemas.
-- =============================================================================
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
```

3. Teste no terminal (troque URL e chave):

```bash
curl "https://SEU-REF.supabase.co/rest/v1/praca?select=nome,bairro" \
  -H "apikey: SUA_ANON_KEY" -H "Accept-Profile: safetech"
```

Deve retornar as 3 praças em JSON. Se vier `permission denied`, o schema não foi exposto ou o grant não rodou.

### 4. Integrar o Supabase Auth com a tabela `usuario`

Com Supabase a senha fica em `auth.users`; nossa tabela `usuario` passa a ser o *perfil* e é preenchida por trigger
no cadastro. Crie `database/supabase/07_supabase_auth.sql` e execute:

```sql
-- =============================================================================
-- 07_supabase_auth.sql : integração com o Supabase Auth
-- A senha passa a ser gerenciada pelo Supabase Auth (auth.users); a tabela
-- safetech.usuario vira o "perfil" do usuário e é preenchida automaticamente.
-- =============================================================================
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
```

Teste: **Authentication → Users → Add user** (e-mail `cidadao.demo@safetech.app`, senha `Senha@123`, marque
*Auto confirm*). Depois, no SQL Editor: `SELECT * FROM safetech.usuario WHERE email = 'cidadao.demo@safetech.app';`
deve mostrar o perfil criado com `perfil = CIDADAO`.

> Use e-mails `@safetech.app` para contas do Auth. Os `@safetech.local` dos seeds são apenas dados de exemplo
> (não têm login); se criar no Auth um e-mail que já existe nos seeds o cadastro falha por e-mail duplicado.

### 5. Ativar o RLS

A `anon key` vai no front-end e é pública, então sem RLS qualquer pessoa leria/alteraria tudo. Crie
`database/supabase/09_supabase_rls.sql` e execute:

```sql
-- =============================================================================
-- 09_rls.sql : Row Level Security
-- A chave "anon" é pública (vai no front), então toda tabela exposta precisa
-- de RLS. As RPCs (SECURITY DEFINER) continuam funcionando normalmente.
-- =============================================================================
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
```

Teste rápido (deve dar erro de permissão):

```bash
curl "https://SEU-REF.supabase.co/rest/v1/ocorrencia" -H "apikey: SUA_ANON_KEY" -H "Accept-Profile: safetech"
```

### 6. Desativar a confirmação de e-mail (ambiente de desenvolvimento)

**Authentication → Providers → Email → "Confirm email"**: desligue. Assim o cadastro pelo front já loga na hora.

### 7. Publicar as credenciais para a equipe

No grupo privado da equipe envie: `Project URL`, `anon key`, e-mail/senha dos usuários de teste (item 9).
**Nunca** envie a `service_role key` no grupo; ela só é usada pelo Davi via secrets da Edge Function e, se ele
precisar, você a configura junto com ele.

Crie também `src/frontend/.env.example` (sem valores reais):

```env
VITE_SUPABASE_URL=https://SEU-REF.supabase.co
VITE_SUPABASE_ANON_KEY=sua-anon-key
```

Abra o PR da parte 1 com: `database/supabase/06_*.sql`, `07_*.sql`, `09_*.sql`, `.env.example`.
Avise no grupo: "Supabase no ar, schema exposto, podem começar".

## Parte 2 — Quarta 12/11

### 8. Storage para anexos

1. **Storage → New bucket**: nome `anexos`, *Public bucket* ligado (leitura pública; upload só logado).
2. SQL Editor (salve em `database/supabase/10_storage.sql`):

```sql
-- Upload apenas para usuários logados, dentro do bucket anexos
CREATE POLICY "anexos_upload_logado" ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'anexos');

-- Cada um apaga só o que enviou
CREATE POLICY "anexos_delete_dono" ON storage.objects
    FOR DELETE TO authenticated
    USING (bucket_id = 'anexos' AND owner = auth.uid());
```

### 9. Usuários de teste por perfil

Crie no **Authentication → Users** (com *Auto confirm*) e depois promova via SQL:

| E-mail | Senha | Perfil |
|--------|-------|--------|
| cidadao.demo@safetech.app | Senha@123 | CIDADAO (padrão) |
| agente.demo@safetech.app | Senha@123 | AGENTE |
| gestor.demo@safetech.app | Senha@123 | GESTOR |
| admin.demo@safetech.app | Senha@123 | ADMIN |

```sql
UPDATE safetech.usuario SET perfil = 'AGENTE', matricula = 'AGT-DEMO' WHERE email = 'agente.demo@safetech.app';
UPDATE safetech.usuario SET perfil = 'GESTOR', matricula = 'GST-DEMO' WHERE email = 'gestor.demo@safetech.app';
UPDATE safetech.usuario SET perfil = 'ADMIN',  matricula = 'ADM-DEMO' WHERE email = 'admin.demo@safetech.app';
```

Salve esse UPDATE em `database/supabase/11_usuarios_demo.sql` com um comentário explicando que os usuários são
criados no painel.

### 10. Healthcheck da conexão

Crie `database/scripts/healthcheck.sh`:

```bash
#!/usr/bin/env bash
# Uso: SUPABASE_URL=... SUPABASE_ANON_KEY=... ./healthcheck.sh
set -e
echo "praças:"; curl -s "$SUPABASE_URL/rest/v1/praca?select=nome" -H "apikey: $SUPABASE_ANON_KEY" -H "Accept-Profile: safetech"
echo; echo "resumo:"; curl -s "$SUPABASE_URL/rest/v1/vw_praca_resumo?select=nome,ocorrencias_abertas" -H "apikey: $SUPABASE_ANON_KEY" -H "Accept-Profile: safetech"
echo; echo "protocolo:"; curl -s "$SUPABASE_URL/rest/v1/rpc/consultar_protocolo" -X POST -H "apikey: $SUPABASE_ANON_KEY" -H "Content-Profile: safetech" -H "Content-Type: application/json" -d '{"p_protocolo":"STC-2026-000001"}'
echo
```

### 11. Atualizar documentação

- No `README.md`, seção **Banco de dados**: adicionar "Ambiente Supabase" com a ordem de aplicação
  (`ddl/01..05` → `seeds` → `supabase/06..11`) e o link para `docs/checkpoint-2/README.md`.
- Em `docs/modelagem/modelo-logico.md`: registrar que `usuario.senha_hash` ficou opcional (Auth) e listar as
  funções `perfil_atual()`, `eh_equipe()`, `eh_gestor()`.
- Revisar os PRs do Davi e do Santhiago (teste rodando a coleção `.http` da Ana contra o projeto).

### 12. Fechamento (13/11)

Após os merges: `git tag -a checkpoint-2 -m "Checkpoint 2: endpoints e conexão com o banco" && git push --tags`.

## Problemas comuns

| Sintoma | Causa provável | Solução |
|---------|----------------|---------|
| `permission denied for schema safetech` | Grants (06) não executados | Rode `06_supabase_grants.sql` |
| `relation "praca" does not exist` via REST | Schema não exposto ou falta `Accept-Profile` | Exposed schemas + cabeçalho |
| Cadastro retorna "Database error saving new user" | Trigger de perfil falhou (e-mail duplicado com seed) | Use e-mail `@safetech.app` |
| Front vê tudo mesmo sem login | RLS não ativado | Rode `09_supabase_rls.sql` |
| RPC retorna 404 | Função criada em `public` ou falta `Content-Profile` | Confirme `safetech.` no nome e o cabeçalho |
