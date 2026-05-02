#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "Arrancando docker compose..."
docker compose up -d

echo "Esperando que cassandra-1 acepte conexiones CQL (max 5 min)..."
RETRY=0
MAX=60
until docker exec -it cassandra-1 cqlsh -e "DESC KEYSPACES" >/dev/null 2>&1 || [ $RETRY -ge $MAX ]; do
  sleep 5
  RETRY=$((RETRY+1))
  echo "esperando... ($RETRY/$MAX)"
done
if [ $RETRY -ge $MAX ]; then
  echo "cqlsh no responde en cassandra-1. Revisa logs con: docker compose logs --tail=200 cassandra-1"
  exit 1
fi

echo "Cargando schema..."
docker cp cql/schema.cql cassandra-1:/tmp/schema.cql
docker exec -it cassandra-1 cqlsh -f /tmp/schema.cql

for f in cql/inserts_*.cql; do
  echo "Cargando $f"
  docker cp "$f" cassandra-1:/tmp/$(basename "$f")
  docker exec -it cassandra-1 cqlsh -f /tmp/$(basename "$f")
done

echo "Verificando conteos..."
docker exec -it cassandra-1 cqlsh -e "SELECT keyspace_name FROM system_schema.keyspaces;"
docker exec -it cassandra-1 cqlsh -e "SELECT count(*) FROM universia_postulaciones.postulantes_medicina_por_periodo;"

echo "Hecho. Si necesitas ver logs: docker compose logs -f --tail=200 cassandra-1"
