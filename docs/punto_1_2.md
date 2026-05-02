# Punto 1 y 2

## Punto 1: arquitectura Cassandra

Se implementa un clúster Cassandra con tres nodos en Docker:

- Un solo data center lógico: `datacenter1`.
- `SimpleStrategy` con `replication_factor = 3`.
- Tres contenedores independientes: `cassandra-1`, `cassandra-2` y `cassandra-3`.
- Un volumen persistente por nodo para no perder datos al recrear contenedores.
- El nodo `cassandra-1` actúa como seed inicial.

Esta configuración cumple el requisito porque cada nodo corre localmente en el computador del estudiante y el factor de replicación 3 deja una copia en cada nodo del clúster.

## Punto 2: diseño físico

El modelo físico se diseñó en función de las consultas del negocio y no con enfoque relacional. En Cassandra, la clave está en elegir correctamente la partition key para:

- distribuir la carga entre nodos,
- reducir el número de particiones leídas,
- evitar filtros globales y lecturas innecesarias.

### Criterio general

Se usaron tablas desnormalizadas, una por patrón de acceso frecuente. Esto permite que cada consulta resuelva su resultado con una sola lectura lógica por partición.

### Tablas definidas

1. `postulantes_medicina_por_periodo`
   - Consulta objetivo: postulantes matriculados en Medicina ordenados por período.
   - Partition key: `(carrera, matriculado)`.
   - Clustering key: `periodo, cedula`.
   - Ventaja: la consulta se resuelve en una sola partición y el orden por período se obtiene directamente desde el clustering.

2. `postulantes_ici_maule_por_periodo`
   - Consulta objetivo: postulantes matriculados de Maule en Ingeniería Civil Informática ordenados por período.
   - Partition key: `(carrera, region, matriculado)`.
   - Clustering key: `periodo, cedula`.
   - Ventaja: se concentra exactamente el subconjunto requerido y se ordena por período sin leer particiones adicionales.

3. `postulantes_ciencias_salud_por_psu`
   - Consulta objetivo: postulantes matriculados en Ciencias de la Salud ordenados por puntaje PSU.
   - Partition key: `(facultad, matriculado)`.
   - Clustering key: `puntaje, cedula` con orden descendente.
   - Ventaja: la consulta se responde con una sola partición y el orden por puntaje se obtiene nativamente en Cassandra.

### Justificación respecto a las reglas

#### Regla 1: distribuir los datos por todo el clúster

Las particiones se forman a partir de combinaciones de columnas con cardinalidad útil para el negocio, como `carrera`, `region`, `facultad` y `matriculado`. Eso evita concentrar todos los datos en una sola partición y reparte las escrituras y lecturas entre los nodos.

#### Regla 2: minimizar el número de particiones a leer

Cada tabla fue diseñada para responder una consulta específica con igualdad sobre la partition key. Así, la lectura queda acotada a una sola partición por consulta, lo que reduce latencia y evita escaneos innecesarios.

### Archivos asociados

- `docker-compose.yml`: despliegue del clúster.
- `cql/schema.cql`: keyspace y tablas del modelo físico.

## Evidencia de alta disponibilidad y consistencia

Se ejecuto una prueba que detuvo el nodo `cassandra-2` y se verificaron consultas antes y despues sin que fallara la lectura de los datos replicados.

- Resultados de consultas antes: [outputs/ha/queries_before.txt](outputs/ha/queries_before.txt)
- Resultados de consultas con nodo caido: [outputs/ha/queries_after_stop.txt](outputs/ha/queries_after_stop.txt)
- Estado del clúster (nodetool) antes: [outputs/ha/status_before.txt](outputs/ha/status_before.txt)
- Estado del clúster (nodetool) despues de apagar cassandra-2: [outputs/ha/status_after_stop.txt](outputs/ha/status_after_stop.txt)
- Logs resumidos: [outputs/ha/log_cassandra1.txt](outputs/ha/log_cassandra1.txt) (ver otros en la carpeta `outputs/ha`).

Observacion: la consulta retorna resultados aun con `cassandra-2` detenido gracias al factor de replicacion 3; los archivos anteriores contienen capturas de la salida.