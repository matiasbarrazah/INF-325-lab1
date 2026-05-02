#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"


OUT=outputs
mkdir -p "$OUT"

echo "Copiando cql/queries.cql a container cassandra-1"
docker cp cql/queries.cql cassandra-1:/tmp/queries.cql

echo "Ejecutando consultas y guardando en $OUT"
docker exec -i cassandra-1 cqlsh -f /tmp/queries.cql > "$OUT/queries_raw.txt" 2>&1 || true

echo "Salida completa en $OUT/queries_raw.txt"
