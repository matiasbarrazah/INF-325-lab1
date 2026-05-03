import asyncore
from cassandra.cluster import Cluster
import pandas as pd

cluster = Cluster(['127.0.0.1'], port=9042)
session = cluster.connect('universia_postulaciones')

rows = session.execute("""
    SELECT facultad, periodo, cedula, carrera, puntaje
    FROM postulantes_ciencias_salud_por_psu
    WHERE facultad = 'CIENCIAS DE LA SALUD' AND matriculado = 'SI'
""")
df = pd.DataFrame(list(rows))
cluster.shutdown()
