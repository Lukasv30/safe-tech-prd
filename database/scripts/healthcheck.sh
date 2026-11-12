#!/usr/bin/env bash
# Uso: SUPABASE_URL=... SUPABASE_ANON_KEY=... ./healthcheck.sh
set -e
echo "praças:"; curl -s "$SUPABASE_URL/rest/v1/praca?select=nome" -H "apikey: $SUPABASE_ANON_KEY" -H "Accept-Profile: safetech"
echo; echo "resumo:"; curl -s "$SUPABASE_URL/rest/v1/vw_praca_resumo?select=nome,ocorrencias_abertas" -H "apikey: $SUPABASE_ANON_KEY" -H "Accept-Profile: safetech"
echo; echo "protocolo:"; curl -s "$SUPABASE_URL/rest/v1/rpc/consultar_protocolo" -X POST -H "apikey: $SUPABASE_ANON_KEY" -H "Content-Profile: safetech" -H "Content-Type: application/json" -d '{"p_protocolo":"STC-2026-000001"}'
echo