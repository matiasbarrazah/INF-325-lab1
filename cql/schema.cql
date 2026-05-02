CREATE KEYSPACE IF NOT EXISTS universia_postulaciones
WITH replication = {
  'class': 'SimpleStrategy',
  'replication_factor': 3
};

USE universia_postulaciones;

CREATE TABLE IF NOT EXISTS postulantes_medicina_por_periodo (
  carrera text,
  matriculado text,
  periodo int,
  cedula text,
  sexo text,
  preferencia int,
  facultad text,
  puntaje int,
  grupo_depen text,
  region text,
  latitud double,
  longitud double,
  ptje_nem int,
  psu_promlm int,
  pace text,
  gratuidad text,
  PRIMARY KEY ((carrera, matriculado), periodo, cedula)
) WITH CLUSTERING ORDER BY (periodo ASC, cedula ASC);

CREATE TABLE IF NOT EXISTS postulantes_ici_maule_por_periodo (
  carrera text,
  region text,
  matriculado text,
  periodo int,
  cedula text,
  sexo text,
  preferencia int,
  facultad text,
  puntaje int,
  grupo_depen text,
  latitud double,
  longitud double,
  ptje_nem int,
  psu_promlm int,
  pace text,
  gratuidad text,
  PRIMARY KEY ((carrera, region, matriculado), periodo, cedula)
) WITH CLUSTERING ORDER BY (periodo ASC, cedula ASC);

CREATE TABLE IF NOT EXISTS postulantes_ciencias_salud_por_psu (
  facultad text,
  matriculado text,
  puntaje int,
  cedula text,
  periodo int,
  carrera text,
  sexo text,
  preferencia int,
  grupo_depen text,
  region text,
  latitud double,
  longitud double,
  ptje_nem int,
  psu_promlm int,
  pace text,
  gratuidad text,
  PRIMARY KEY ((facultad, matriculado), puntaje, cedula)
) WITH CLUSTERING ORDER BY (puntaje DESC, cedula ASC);