import asyncore
from cassandra.cluster import Cluster
import pandas as pd

cluster = Cluster(['127.0.0.1'], port=9042)
session = cluster.connect('universia_postulaciones')

rows = session.execute("""
    SELECT carrera, region, periodo, cedula, puntaje
    FROM postulantes_ici_maule_por_periodo
    WHERE carrera = 'INGENIERÍA CIVIL INFORMÁTICA'
    AND region = 'MAULE' AND matriculado = 'SI'
""")
df = pd.DataFrame(list(rows))
cluster.shutdown()
