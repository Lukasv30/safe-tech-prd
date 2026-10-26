#!/usr/bin/env bash
# Executa DDL + seeds em ordem no banco safetech.
# Uso: ./run_all.sh [--no-seed]
set -euo pipefail

cd "$(dirname "$0")/.."

export PGHOST="${PGHOST:-localhost}"
export PGPORT="${PGPORT:-5432}"
export PGUSER="${PGUSER:-postgres}"
export PGDATABASE="${PGDATABASE:-safetech}"

run() {
  echo ">> $1"
  psql -v ON_ERROR_STOP=1 -q -f "$1"
}

for f in ddl/*.sql; do
  run "$f"
done

if [[ "${1:-}" != "--no-seed" ]]; then
  for f in seeds/*.sql; do
    run "$f"
  done
fi

echo "Concluído."
