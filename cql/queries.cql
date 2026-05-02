-- Consultas punto 3
-- a) Postulantes matriculados en MEDICINA ordenados por periodo
SELECT carrera, periodo, cedula, facultad, puntaje FROM universia_postulaciones.postulantes_medicina_por_periodo
WHERE carrera = 'MEDICINA' AND matriculado = 'SI' ORDER BY periodo ASC;

-- b) Postulantes matriculados de la region MAULE en INGENIERIA CIVIL INFORMATICA ordenados por periodo
SELECT carrera, region, periodo, cedula, facultad, puntaje FROM universia_postulaciones.postulantes_ici_maule_por_periodo
WHERE carrera = 'INGENIERÍA CIVIL INFORMÁTICA' AND region = 'MAULE' AND matriculado = 'SI' ORDER BY periodo ASC;

-- c) Postulantes matriculados en la facultad CIENCIAS DE LA SALUD ordenado por puntaje PSU
SELECT facultad, periodo, cedula, carrera, puntaje FROM universia_postulaciones.postulantes_ciencias_salud_por_psu
WHERE facultad = 'CIENCIAS DE LA SALUD' AND matriculado = 'SI' ORDER BY puntaje DESC;
