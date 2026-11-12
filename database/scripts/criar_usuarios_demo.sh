#!/usr/bin/env bash
# Cria os usuários demo no Supabase Auth via API pública de cadastro (signup).
# Pré-requisito: Authentication > Sign In / Providers > Email > "Confirm email" DESLIGADO
# (ambiente de desenvolvimento). Depois rode database/supabase/05_users_teste.sql no SQL Editor
# para promover os perfis AGENTE/GESTOR/ADMIN.
# Uso: bash database/scripts/criar_usuarios_demo.sh   (lê SUPABASE_URL e SUPABASE_ANON_KEY do .env na raiz)
set -e
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
[ -f "$ROOT/.env" ] && { set -a; . "$ROOT/.env"; set +a; }
: "${SUPABASE_URL:?defina SUPABASE_URL}"; : "${SUPABASE_ANON_KEY:?defina SUPABASE_ANON_KEY}"

SENHA="Senha@123"
declare -A NOMES=( [cidadao]="Cidadão Demo" [agente]="Agente Demo" [gestor]="Gestor Demo" [admin]="Admin Demo" )

for u in cidadao agente gestor admin; do
  email="$u.demo@safetech.app"
  printf "%-28s " "$email"
  resp=$(curl -s "$SUPABASE_URL/auth/v1/signup" -H "apikey: $SUPABASE_ANON_KEY" -H "Content-Type: application/json" \
    -d "{\"email\":\"$email\",\"password\":\"$SENHA\",\"data\":{\"nome\":\"${NOMES[$u]}\"}}")
  if echo "$resp" | grep -q '"access_token"'; then echo "criado e logado OK"
  elif echo "$resp" | grep -q 'already registered\|user_already_exists'; then echo "já existe"
  else echo "ERRO: $(echo "$resp" | head -c 200)"; fi
done

echo; echo "Agora rode no SQL Editor: database/supabase/05_users_teste.sql"
