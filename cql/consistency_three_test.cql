-- Prueba de consistencia con nivel THREE
-- CONSISTENCY THREE exige que los 3 nodos repliquen la respuesta antes de retornar
CONSISTENCY THREE;

-- Consulta a: medicina
SELECT carrera, periodo, cedula, puntaje
FROM universia_postulaciones.postulantes_medicina_por_periodo
WHERE carrera = 'MEDICINA' AND matriculado = 'SI'
LIMIT 5;

-- Consulta b: ICI Maule
SELECT carrera, region, periodo, cedula, puntaje
FROM universia_postulaciones.postulantes_ici_maule_por_periodo
WHERE carrera = 'INGENIERÍA CIVIL INFORMÁTICA' AND region = 'MAULE' AND matriculado = 'SI'
LIMIT 5;

-- Consulta c: Ciencias de la Salud
SELECT facultad, periodo, cedula, carrera, puntaje
FROM universia_postulaciones.postulantes_ciencias_salud_por_psu
WHERE facultad = 'CIENCIAS DE LA SALUD' AND matriculado = 'SI'
LIMIT 5;
