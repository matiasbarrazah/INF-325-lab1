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
