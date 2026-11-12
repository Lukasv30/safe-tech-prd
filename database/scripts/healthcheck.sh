#!/usr/bin/env bash
# Healthcheck da conexão com o Supabase (API REST / PostgREST, schema safetech).
# Uso:
#   SUPABASE_URL=... SUPABASE_ANON_KEY=... ./healthcheck.sh
# ou crie um .env na raiz do repositório (copie de .env.example) e rode:
#   ./database/scripts/healthcheck.sh
set -e

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
if [ -f "$ROOT/.env" ]; then
  set -a; . "$ROOT/.env"; set +a
fi
: "${SUPABASE_URL:?defina SUPABASE_URL (ou crie .env na raiz)}"
: "${SUPABASE_ANON_KEY:?defina SUPABASE_ANON_KEY (ou crie .env na raiz)}"

echo "praças:"; curl -s "$SUPABASE_URL/rest/v1/praca?select=nome" -H "apikey: $SUPABASE_ANON_KEY" -H "Accept-Profile: safetech"
echo; echo "resumo:"; curl -s "$SUPABASE_URL/rest/v1/vw_praca_resumo?select=nome,ocorrencias_abertas" -H "apikey: $SUPABASE_ANON_KEY" -H "Accept-Profile: safetech"
echo; echo "protocolo:"; curl -s "$SUPABASE_URL/rest/v1/rpc/consultar_protocolo" -X POST -H "apikey: $SUPABASE_ANON_KEY" -H "Content-Profile: safetech" -H "Content-Type: application/json" -d '{"p_protocolo":"STC-2026-000001"}'
echo
