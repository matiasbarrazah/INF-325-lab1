# INF-325 Lab 1

Base del laboratorio de Cassandra para el dataset de postulaciones.

## Contenido inicial

- `docker-compose.yml`: clúster Cassandra de 3 nodos con `SimpleStrategy` y `RF=3`.
- `cql/schema.cql`: keyspace y tablas del diseño físico para los puntos 1 y 2.
- `docs/punto_1_2.md`: justificación técnica del diseño.

## Ejecución

1. Levantar el clúster:

```bash
docker compose up -d
```

2. Verificar estado:

```bash
docker compose ps
```

3. Cargar el esquema:

```bash
cqlsh localhost 9042 -f cql/schema.cql
```

## Notas de diseño

- Se priorizó una modelación orientada a consultas.
- Las tablas están desnormalizadas para evitar lecturas de múltiples particiones.
- El factor de replicación es 3 para mantener una copia en cada nodo.