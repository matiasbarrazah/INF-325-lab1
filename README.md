# INF-325 Lab 1: Cassandra + Postulaciones

Laboratorio de Bases de Datos Avanzadas. Implementa un **clúster Cassandra de 3 nodos** (Docker) para almacenar y consultar ~16k registros de postulaciones universitarias (2018-2020).

## Propósito

Demostrar:
- Arquitectura distribuida de Cassandra (3 nodos, RF=3).
- Diseño físico orientado a consultas (desnormalización).
- Replicación y alta disponibilidad.
- Integración con herramientas (Power BI).

## Estructura

```
├── docker-compose.yml          # Cluster 3 nodos Cassandra en Docker
├── cql/
│   ├── schema.cql              # Keyspace + 3 tablas (modelo fisico)
│   ├── inserts_*.cql           # ~3k inserts por tabla (generados)
│   └── queries.cql             # 3 consultas del negocio (punto 3)
├── scripts/
│   ├── run_local.sh            # Deploy cluster + carga esquema y datos
│   ├── generate_inserts.py     # Genera inserts desde postulaciones.xlsx
│   ├── run_queries.sh          # Ejecuta consultas, guarda en outputs/
│   └── test_ha.sh              # Prueba alta disponibilidad (apagar nodo)
├── docs/
│   └── punto_1_2.md            # Justificacion arquitectura + diseño
├── postulaciones.xlsx          # Dataset original (16k filas, 16 columnas)
└── outputs/                    # Resultados: queries_raw.txt, ha/ (logs, status)
```

## Ejecución rápida

**1) Levantar clúster e insertar datos:**
```bash
./scripts/run_local.sh
```
Arranca 3 nodos, espera healthy, carga esquema e inserts. (~5-10 min).

**2) Ejecutar consultas del negocio:**
```bash
./scripts/run_queries.sh
```
Salida → `outputs/queries_raw.txt` (182 resultados medicina, 92 ICI Maule, 824 Ciencias Salud).

**3) Probar alta disponibilidad (detener nodo 2):**
```bash
./scripts/test_ha.sh
```
Verifica que consultas sigan respondiendo con un nodo caido. Resultados en `outputs/ha/`.

## Puntos del laboratorio

| # | Descripcion | Estado |
|---|---|---|
| 1 | Cluster 3 nodos, SimpleStrategy, RF=3 | ✅ docker-compose.yml |
| 2 | Diseño fisico (3 tablas + justificacion) | ✅ cql/schema.cql, docs/punto_1_2.md |
| 3 | Consultas CQL (3 queries negocio) | ✅ cql/queries.cql, outputs/queries_raw.txt |
| 4 | Integracion Power BI | 🔴 Datos disponibles para carga en Power BI Desktop |
| 5 | Evidencia HA + consistencia | ✅ scripts/test_ha.sh, outputs/ha/ |

## Tablas del modelo

1. **postulantes_medicina_por_periodo**: matriculados carrera MEDICINA, ordenados por periodo.
2. **postulantes_ici_maule_por_periodo**: matriculados region MAULE carrera ICI, ordenados por periodo.
3. **postulantes_ciencias_salud_por_psu**: matriculados facultad Ciencias Salud, ordenados por puntaje PSU.

Cada tabla esta optimizada para una consulta especifica (partition key + clustering key apropiados).

## Requisitos previos

- Docker + Docker Compose
- Python 3.7+
- (Opcional) cqlsh local o acceso ssh a contenedores

## Notas de diseño

- Modelacion orientada a **consultas**, no a normalización relacional.
- Tablas **desnormalizadas** (datos replicados) para evitar lecturas multi-particion.
- Partition keys (carrera, region, facultad) distribuyen carga; clustering keys (periodo, puntaje) permiten orden nativo.
- RF=3: cada fila en 3 nodos → alta disponibilidad local sin percepcion de caida (comprobado en test_ha.sh).