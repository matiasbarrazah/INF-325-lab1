#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

OUT=outputs/ha
mkdir -p "$OUT"

echo "Guardando nodetool status antes..."
docker exec -it cassandra-1 nodetool status > "$OUT/status_before.txt" 2>&1 || true

echo "Ejecutando consultas antes de apagar nodo..."
docker exec -i cassandra-1 cqlsh -f /tmp/queries.cql > "$OUT/queries_before.txt" 2>&1 || true

echo "Deteniendo cassandra-2"
docker compose stop cassandra-2

echo "Esperando 8s"
sleep 8

echo "Guardando nodetool status despues de apagar cassandra-2..."
docker exec -it cassandra-1 nodetool status > "$OUT/status_after_stop.txt" 2>&1 || true

echo "Ejecutando consultas con nodo 2 caido..."
docker exec -i cassandra-1 cqlsh -f /tmp/queries.cql > "$OUT/queries_after_stop.txt" 2>&1 || true

echo "Recopilando logs (ultimas 200 lineas)"
docker compose logs --tail=200 cassandra-1 > "$OUT/log_cassandra1.txt" 2>&1 || true
docker compose logs --tail=200 cassandra-2 > "$OUT/log_cassandra2.txt" 2>&1 || true
docker compose logs --tail=200 cassandra-3 > "$OUT/log_cassandra3.txt" 2>&1 || true

echo "Volviendo a levantar cassandra-2"
docker compose start cassandra-2

echo "Esperando 20s para que el nodo arranque"
sleep 20

echo "Guardando nodetool status despues de arrancar cassandra-2"
docker exec -it cassandra-1 nodetool status > "$OUT/status_after_start.txt" 2>&1 || true

echo "Hecho. Resultados en $OUT"
