#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

OUT=outputs
mkdir -p "$OUT"

echo "Ejecutando consultas y guardando en $OUT"
docker exec -i cassandra-1 cqlsh -f cql/queries.cql > "$OUT/queries_raw.txt" 2>&1 || true

echo "Salida completa en $OUT/queries_raw.txt"
