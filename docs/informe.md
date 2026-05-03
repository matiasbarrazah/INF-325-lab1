# INF-325 Bases de Datos Avanzadas
## Laboratorio 1: Cassandra — Postulaciones Universia

**Autores:** _(completar con nombre(s) y e-mail(s))_

**Fecha:** viernes, 08 de abril de 2026

---

## Resumen

Este laboratorio implementa una base de datos NoSQL distribuida en Apache Cassandra para almacenar y consultar registros de postulaciones universitarias (DEMRE, períodos 2018–2020). Se desplegó un clúster de tres nodos sobre Docker con factor de replicación 3, se diseñó el modelo físico orientado a consultas según las reglas de distribución y minimización de particiones, se ejecutaron las tres consultas de negocio requeridas y se integró el clúster con Power BI Desktop. Se demostró la consistencia de los datos con nivel `THREE` y la alta disponibilidad del sistema al derribar un nodo sin que las consultas fallaran.

---

## 1 Introducción

Apache Cassandra es un sistema gestor de bases de datos NoSQL distribuido, orientado a columnas, diseñado para soportar grandes volúmenes de escritura y lectura con alta disponibilidad y tolerancia a partición. A diferencia de los motores relacionales, Cassandra no permite consultas ad-hoc arbitrarias; en su lugar, el modelo de datos se diseña a partir de los patrones de acceso conocidos (query-driven design).

El dataset de postulaciones contiene 16 campos —categóricos y numéricos— que representan información demográfica, académica, geográfica y de beneficios de los postulantes a la Universidad de Curicó (UCM) en los períodos 2018, 2019 y 2020. El objetivo del laboratorio es demostrar las capacidades de Cassandra en un escenario OLAP real: diseño físico eficiente, consistencia configurable y alta disponibilidad ante falla de nodo.

---

## 2 Desarrollo

### 2.1 Requisito 1 — Arquitectura Cassandra en Docker

Se implementó un clúster con tres contenedores Docker usando la imagen oficial `cassandra:4.1.5`. La configuración cumple exactamente los requisitos del enunciado:

| Parámetro | Valor |
|-----------|-------|
| Data center | `datacenter1` |
| Estrategia de replicación | `SimpleStrategy` |
| Factor de replicación | `3` |
| Nodos | `cassandra-1` (seed), `cassandra-2`, `cassandra-3` |
| Puertos host | 9042, 9142, 9242 |

El archivo `docker-compose.yml` define los tres servicios con volúmenes persistentes por nodo y healthchecks que garantizan que `cassandra-2` y `cassandra-3` solo arrancan una vez que `cassandra-1` está operativo (evitando la race condition de bootstrap simultáneo).

**Evidencia — ring completo con 3 nodos `UN` (Up/Normal):**

```
Datacenter: datacenter1
=======================
Status=Up/Down
|/ State=Normal/Leaving/Joining/Moving
--  Address     Load        Tokens  Owns (effective)  Host ID                               Rack
UN  172.21.0.4  76.97 KiB   16      100.0%            f44e5bae-cfd1-4f49-9778-346358b04989  rack1
UN  172.21.0.2  101.64 KiB  16      100.0%            676aef73-da3e-4113-94cb-46a812cbd77e  rack1
UN  172.21.0.3  136.72 KiB  16      100.0%            7490a6c7-3e16-48d8-8fbb-ea7607cfe29b  rack1
```

Cada nodo posee el 100 % efectivo de los datos gracias al factor de replicación 3.

> **[CAPTURA]** Insertar aquí captura de pantalla de `docker compose ps` (3 nodos `healthy`) y `nodetool status` (3 nodos `UN`).

---

### 2.2 Requisito 2 — Diseño físico de la base de datos

El modelo físico se diseñó orientado a las tres consultas de negocio. Se usaron **tablas desnormalizadas** (una por patrón de acceso), lo que permite que cada consulta se resuelva leyendo una única partición.

#### Tabla 1: `postulantes_medicina_por_periodo`

```cql
CREATE TABLE IF NOT EXISTS postulantes_medicina_por_periodo (
  carrera text, matriculado text, periodo int, cedula text,
  sexo text, preferencia int, facultad text, puntaje int,
  grupo_depen text, region text, latitud double, longitud double,
  ptje_nem int, psu_promlm int, pace text, gratuidad text,
  PRIMARY KEY ((carrera, matriculado), periodo, cedula)
) WITH CLUSTERING ORDER BY (periodo ASC, cedula ASC);
```

- **Consulta objetivo:** postulantes matriculados en Medicina, ordenados por período.
- **Partition key:** `(carrera, matriculado)` — la combinación concentra exactamente el subconjunto requerido en una partición.
- **Clustering key:** `periodo, cedula` — el orden por período se obtiene nativamente sin `ALLOW FILTERING`.

#### Tabla 2: `postulantes_ici_maule_por_periodo`

```cql
CREATE TABLE IF NOT EXISTS postulantes_ici_maule_por_periodo (
  carrera text, region text, matriculado text, periodo int, cedula text,
  ...
  PRIMARY KEY ((carrera, region, matriculado), periodo, cedula)
) WITH CLUSTERING ORDER BY (periodo ASC, cedula ASC);
```

- **Consulta objetivo:** postulantes matriculados de la Región del Maule en Ingeniería Civil Informática, ordenados por período.
- **Partition key:** `(carrera, region, matriculado)` — filtra por los tres criterios de igualdad de la consulta en una sola partición.

#### Tabla 3: `postulantes_ciencias_salud_por_psu`

```cql
CREATE TABLE IF NOT EXISTS postulantes_ciencias_salud_por_psu (
  facultad text, matriculado text, puntaje int, cedula text,
  ...
  PRIMARY KEY ((facultad, matriculado), puntaje, cedula)
) WITH CLUSTERING ORDER BY (puntaje DESC, cedula ASC);
```

- **Consulta objetivo:** postulantes matriculados en la Facultad de Ciencias de la Salud, ordenados por puntaje PSU descendente.
- **Partition key:** `(facultad, matriculado)` — agrupa exactamente el subconjunto requerido.
- **Clustering key:** `puntaje DESC` — el ordenamiento por puntaje se almacena físicamente, sin costo en tiempo de consulta.

#### Justificación por reglas

**Regla 1 — Distribuir los datos por todo el clúster:**
Las partition keys usan columnas con cardinalidad útil para el negocio (`carrera`, `region`, `facultad`, `matriculado`). Esto evita que todos los datos caigan en una sola partición y reparte la carga entre los nodos mediante el hash del token.

**Regla 2 — Minimizar el número de particiones a leer:**
Cada tabla fue diseñada para que la consulta pueda especificar igualdad sobre toda la partition key, resolviendo la lectura con exactamente **una partición** por consulta.

> **[CAPTURA]** Insertar aquí captura de `cqlsh` ejecutando `DESCRIBE TABLES;` dentro del keyspace `universia_postulaciones`, mostrando las 3 tablas creadas.

---

### 2.3 Requisito 3 — Consultas CQL del negocio

Las tres consultas se ejecutan directamente contra las tablas diseñadas, aprovechando el clustering order para evitar ordenamientos en memoria.

#### Consulta a — Postulantes matriculados en Medicina, por período

```cql
SELECT carrera, periodo, cedula, facultad, puntaje
FROM universia_postulaciones.postulantes_medicina_por_periodo
WHERE carrera = 'MEDICINA' AND matriculado = 'SI'
ORDER BY periodo ASC;
```

**Resultado (muestra):**

```
 carrera  | periodo | cedula   | facultad | puntaje
----------+---------+----------+----------+---------
 MEDICINA |    2018 | 17107577 | MEDICINA |   72895
 MEDICINA |    2018 | 17187165 | MEDICINA |   74490
 MEDICINA |    2018 | 18570377 | MEDICINA |   75230
 ...
(182 rows)
```

#### Consulta b — Postulantes matriculados del Maule en ICI, por período

```cql
SELECT carrera, region, periodo, cedula, facultad, puntaje
FROM universia_postulaciones.postulantes_ici_maule_por_periodo
WHERE carrera = 'INGENIERÍA CIVIL INFORMÁTICA'
  AND region = 'MAULE'
  AND matriculado = 'SI'
ORDER BY periodo ASC;
```

**Resultado (muestra):**

```
 carrera                      | region | periodo | cedula   | puntaje
------------------------------+--------+---------+----------+---------
 INGENIERÍA CIVIL INFORMÁTICA |  MAULE |    2018 | 18331313 |   60225
 INGENIERÍA CIVIL INFORMÁTICA |  MAULE |    2018 | 18476544 |   59130
 ...
(92 rows)
```

#### Consulta c — Postulantes matriculados en Ciencias de la Salud, por puntaje PSU

```cql
SELECT facultad, periodo, cedula, carrera, puntaje
FROM universia_postulaciones.postulantes_ciencias_salud_por_psu
WHERE facultad = 'CIENCIAS DE LA SALUD' AND matriculado = 'SI'
ORDER BY puntaje DESC;
```

**Resultado (muestra — top 5 por puntaje):**

```
 facultad             | periodo | cedula   | carrera    | puntaje
----------------------+---------+----------+------------+---------
 CIENCIAS DE LA SALUD |    2020 | 20228897 | ENFERMERÍA |   74315
 CIENCIAS DE LA SALUD |    2020 | 19696770 | ENFERMERÍA |   73870
 CIENCIAS DE LA SALUD |    2020 | 19697810 | ENFERMERÍA |   73730
 ...
(824 rows)
```

> **[CAPTURA]** Insertar aquí capturas de `cqlsh` ejecutando cada una de las 3 consultas y mostrando los primeros resultados con el conteo total de filas.

---

### 2.4 Requisito 4 — Integración con Power BI Desktop

La integración se realizó mediante una conexión directa al clúster Cassandra corriendo localmente en `localhost:9042`, utilizando el conector nativo de Python de Power BI Desktop. Este método no requiere archivos intermedios — los datos fluyen directamente desde Cassandra a través de scripts Python hacia el modelo de Power BI.

**Pasos realizados:**

1. Se instalaron las dependencias Python necesarias: `cassandra-driver 3.30.0`, `pandas` y `pyasyncore` (compatibilidad con Python 3.13, que eliminó el módulo `asyncore`).
2. En Power BI Desktop se configuró la ruta Python en **Archivo → Opciones → Creación de scripts de Python**, apuntando a `C:\Users\jmeza\AppData\Local\Programs\Python\Python313`.
3. Se cargaron las tres tablas usando **Obtener datos → Script de Python**, ejecutando un script por cada consulta de negocio que conecta directamente a `127.0.0.1:9042` y retorna un DataFrame.
4. Se construyó un tablero interactivo con:
   - Tabla de postulantes matriculados en **Medicina** (182 registros) filtrable por período.
   - Tabla de postulantes matriculados en **Ingeniería Civil Informática** del Maule (92 registros).
   - Gráfico de columnas de postulantes de **Ciencias de la Salud** por carrera y puntaje PSU (824 registros).
   - Segmentador de período (2018, 2019, 2020) que filtra interactivamente la tabla de Medicina.

**Scripts utilizados** (disponibles en `scripts/powerbi_*.py`):

```python
import asyncore
from cassandra.cluster import Cluster
import pandas as pd

cluster = Cluster(['127.0.0.1'], port=9042)
session = cluster.connect('universia_postulaciones')
rows = session.execute("""
    SELECT carrera, periodo, cedula, facultad, puntaje
    FROM postulantes_medicina_por_periodo
    WHERE carrera = 'MEDICINA' AND matriculado = 'SI'
""")
df = pd.DataFrame(list(rows))
cluster.shutdown()
```

> **[CAPTURA 1]** Insertar aquí captura del dashboard completo con los 3 visuales y el segmentador (período sin filtro).
>
> **[CAPTURA 2]** Insertar aquí captura del dashboard con período **2018** seleccionado.
>
> **[CAPTURA 3]** Insertar aquí captura del dashboard con período **2019** seleccionado.
>
> **[CAPTURA 4]** Insertar aquí captura del dashboard con período **2020** seleccionado.

---

### 2.5 Requisito 5 — Consistencia y alta disponibilidad

#### 5.1 Consistencia con nivel THREE

El nivel de consistencia `THREE` en Cassandra exige que el coordinador reciba confirmación de las 3 réplicas antes de retornar el resultado al cliente. Con factor de replicación 3 y 3 nodos, esto equivale a `ALL`: todos los nodos deben responder, lo que garantiza que los datos son idénticos en todo el clúster.

**Prueba realizada:**

```cql
CONSISTENCY THREE;

SELECT carrera, periodo, cedula, puntaje
FROM universia_postulaciones.postulantes_medicina_por_periodo
WHERE carrera = 'MEDICINA' AND matriculado = 'SI'
LIMIT 5;
```

**Output obtenido:**

```
Consistency level set to THREE.

 carrera  | periodo | cedula   | puntaje
----------+---------+----------+---------
 MEDICINA |    2018 | 17107577 |   72895
 MEDICINA |    2018 | 17187165 |   74490
 MEDICINA |    2018 | 18570377 |   75230
 MEDICINA |    2018 | 18618861 |   73790
 MEDICINA |    2018 | 18656110 |   72760

(5 rows)
```

La línea `Consistency level set to THREE.` confirma que los 3 nodos participaron en la lectura. Las mismas consultas se ejecutaron para las tablas de ICI Maule y Ciencias de la Salud con idénticos resultados, evidenciando que los datos están replicados y son consistentes en todo el clúster. El archivo completo con las 3 consultas se encuentra en `outputs/consistency/consistency_three_output.txt`.

> **[CAPTURA]** Insertar aquí captura del terminal `cqlsh` mostrando `Consistency level set to THREE.` seguido de los resultados de las consultas.

#### 5.2 Alta disponibilidad

Se realizó una prueba de falla de nodo ejecutando el script `scripts/run_ha_test.sh`. La prueba detuvo `cassandra-2` y verificó que las consultas continuaban respondiendo correctamente desde los dos nodos restantes.

**Estado antes de la falla (3 nodos `UN`):**

```
Datacenter: datacenter1
=======================
--  Address     Load        Tokens  Owns (effective)  Rack
UN  172.21.0.4  76.97 KiB   16      100.0%            rack1
UN  172.21.0.2  101.64 KiB  16      100.0%            rack1
UN  172.21.0.3  136.5 KiB   16      100.0%            rack1
```

**Estado con `cassandra-2` detenido (nodo `DN`):**

```
Datacenter: datacenter1
=======================
--  Address     Load        Tokens  Owns (effective)  Rack
UN  172.21.0.4  76.97 KiB   16      100.0%            rack1
UN  172.21.0.2  101.64 KiB  16      100.0%            rack1
DN  172.21.0.3  136.5 KiB   16      100.0%            rack1
```

**Resultado de las consultas con nodo caído:**

Las tres consultas retornaron exactamente el mismo número de filas (182 / 92 / 824) que con todos los nodos activos, sin errores. Cassandra redirigió automáticamente las lecturas a las réplicas disponibles (`cassandra-1` y `cassandra-3`), haciendo transparente la falla para el cliente.

**Recuperación:** Al reiniciar `cassandra-2`, el nodo se reintegró al ring y sincronizó automáticamente, volviendo al estado `UN`.

> **[CAPTURA 1]** Insertar aquí `nodetool status` con los 3 nodos `UN` (antes de la falla) — disponible en `outputs/ha/status_before.txt`.
>
> **[CAPTURA 2]** Insertar aquí `nodetool status` con 1 nodo `DN` (cassandra-2 detenido) — disponible en `outputs/ha/status_after_stop.txt`.
>
> **[CAPTURA 3]** Insertar aquí captura del dashboard Power BI mostrando datos correctos con el nodo caído.
>
> **[CAPTURA 4]** Insertar aquí `nodetool status` con los 3 nodos `UN` recuperados — disponible en `outputs/ha/status_after_start.txt`.

---

## 3 Conclusiones

1. **El modelo físico orientado a consultas es fundamental en Cassandra.** A diferencia de los RDBMS, el diseño comienza desde los patrones de acceso: una tabla por consulta frecuente, con la partition key alineada a los filtros de igualdad y el clustering key al ordenamiento requerido. Esto elimina el `ALLOW FILTERING` y garantiza lecturas de O(1) partición.

2. **La replicación con `SimpleStrategy` y factor 3 garantiza tanto consistencia como disponibilidad.** Con `CONSISTENCY THREE` se prueba que los datos son idénticos en los 3 nodos; con `CONSISTENCY ONE` o `QUORUM` se privilegia la disponibilidad, permitiendo tolerar la caída de hasta un nodo sin interrupción del servicio.

3. **Docker simplifica significativamente el despliegue de clústeres multi-nodo locales.** La configuración de healthchecks y dependencias entre contenedores es clave para evitar race conditions durante el bootstrap, ya que Cassandra requiere que los nodos se unan al ring de forma secuencial.

4. **La integración de Cassandra con Power BI es directa mediante el conector Python nativo.** Sin necesidad de drivers ODBC adicionales, el conector Python de Power BI permite construir tableros de control sobre datos distribuidos en tiempo real, con la ventaja de que la capa de almacenamiento es transparente para el analista de datos.

5. **La alta disponibilidad de Cassandra es operacional sin configuración adicional.** La falla de un nodo fue completamente transparente para el cliente: las consultas continuaron respondiendo con resultados idénticos, lo que valida la arquitectura propuesta para escenarios de producción con requisitos de disponibilidad continua.

---

## 4 Referencias Bibliográficas

|     |                                                                                                               |
|-----|---------------------------------------------------------------------------------------------------------------|
| [1] | E. Hewitt, *Cassandra: The Definitive Guide*, 2nd ed., O'Reilly Media Inc., 2016.                            |
| [2] | G. Harrison, *Next Generation Databases: NoSQL, NewSQL, and Big Data*, 2nd ed., Apress, 2015.                |
| [3] | Apache Cassandra Documentation, "Data Consistency," cassandra.apache.org, 2024.                              |
| [4] | L. Perkins, *Seven Databases in Seven Weeks*, Pragmatic Bookshelf, 2018.                                     |
| [5] | DataStax, "Cassandra Query Language (CQL) Reference," docs.datastax.com, 2024.                               |
