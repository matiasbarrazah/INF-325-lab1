#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

OUT=outputs/ha
mkdir -p "$OUT"

echo "=== 1. Estado del cluster ANTES (3 nodos UP) ==="
docker exec cassandra-1 nodetool status > "$OUT/status_before.txt" 2>&1
cat "$OUT/status_before.txt"

echo ""
echo "=== 2. Consultas ANTES de apagar nodo (CONSISTENCY ONE) ==="
docker exec -i cassandra-1 cqlsh < cql/queries.cql > "$OUT/queries_before.txt" 2>&1
cat "$OUT/queries_before.txt"

echo ""
echo "=== 3. Deteniendo cassandra-2 ==="
docker compose stop cassandra-2

echo "Esperando 10s para que el cluster detecte la caida..."
sleep 10

echo ""
echo "=== 4. Estado del cluster CON nodo 2 caido ==="
docker exec cassandra-1 nodetool status > "$OUT/status_after_stop.txt" 2>&1
cat "$OUT/status_after_stop.txt"

echo ""
echo "=== 5. Consultas CON nodo 2 caido (CONSISTENCY ONE) ==="
docker exec -i cassandra-1 cqlsh < cql/queries.cql > "$OUT/queries_after_stop.txt" 2>&1
cat "$OUT/queries_after_stop.txt"

echo ""
echo "=== 6. Recopilando logs ==="
docker compose logs --tail=100 cassandra-1 > "$OUT/log_cassandra1.txt" 2>&1
docker compose logs --tail=100 cassandra-3 > "$OUT/log_cassandra3.txt" 2>&1

echo ""
echo "=== 7. Volviendo a levantar cassandra-2 ==="
docker compose start cassandra-2

echo "Esperando 30s para que el nodo se reintegre..."
sleep 30

docker exec cassandra-1 nodetool status > "$OUT/status_after_start.txt" 2>&1
echo ""
echo "=== Estado final (cassandra-2 reintegrado) ==="
cat "$OUT/status_after_start.txt"

echo ""
echo "DONE — evidencia en $OUT/"
