#!/usr/bin/env python3
from pathlib import Path
import zipfile
from xml.etree import ElementTree as ET

def read_xlsx(path):
    with zipfile.ZipFile(path) as zf:
        shared = []
        if 'xl/sharedStrings.xml' in zf.namelist():
            ss = ET.fromstring(zf.read('xl/sharedStrings.xml'))
            for si in ss.findall('{http://schemas.openxmlformats.org/spreadsheetml/2006/main}si'):
                shared.append(''.join(t.text or '' for t in si.iter('{http://schemas.openxmlformats.org/spreadsheetml/2006/main}t')))
        rels = ET.fromstring(zf.read('xl/_rels/workbook.xml.rels'))
        rid_to_target = {rel.attrib['Id']: rel.attrib['Target'] for rel in rels}
        wb = ET.fromstring(zf.read('xl/workbook.xml'))
        sheets = wb.findall('{http://schemas.openxmlformats.org/spreadsheetml/2006/main}sheets/{http://schemas.openxmlformats.org/spreadsheetml/2006/main}sheet')
        target = rid_to_target[sheets[0].attrib['{http://schemas.openxmlformats.org/officeDocument/2006/relationships}id']]
        sheet = ET.fromstring(zf.read('xl/' + target))
        rows = sheet.findall('.//{http://schemas.openxmlformats.org/spreadsheetml/2006/main}row')
        header = []
        data = []
        def cell_value(c):
            t = c.attrib.get('t')
            v = c.find('{http://schemas.openxmlformats.org/spreadsheetml/2006/main}v')
            if v is None:
                return ''
            if t == 's':
                return shared[int(v.text)]
            return v.text
        for i, row in enumerate(rows):
            vals = [cell_value(c) for c in row.findall('{http://schemas.openxmlformats.org/spreadsheetml/2006/main}c')]
            if i == 0:
                header = vals
            else:
                data.append(dict(zip(header, vals)))
    return header, data

def q(v, is_text=True):
    if v is None or v == '':
        return 'NULL'
    if not is_text:
        try:
            if '.' in v:
                return str(float(v))
            return str(int(v))
        except Exception:
            pass
    # escape single quotes
    return "'" + v.replace("'", "''") + "'"

def generate(data, out_dir):
    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    f_med = out_dir / 'inserts_medicina.cql'
    f_ici = out_dir / 'inserts_ici_maule.cql'
    f_salud = out_dir / 'inserts_ciencias_salud.cql'
    with f_med.open('w', encoding='utf8') as m, f_ici.open('w', encoding='utf8') as i, f_salud.open('w', encoding='utf8') as s:
        for row in data:
            carrera = row.get('CARRERA','')
            region = row.get('REGION','')
            matriculado = row.get('MATRICULADO','')
            # common values
            cols = ['CARRERA','MATRICULADO','PERIODO','CEDULA','SEXO','PREFERENCIA','FACULTAD','PUNTAJE','GRUPO_DEPEN','REGION','LATITUD','LONGITUD','PTJE_NEM','PSU_PROMLM','PACE','GRATUIDAD ']
            # prepare value list function
            def row_vals(r):
                vals = []
                for c in cols:
                    is_text = c in {'CEDULA','CARRERA','SEXO','FACULTAD','GRUPO_DEPEN','REGION','PACE','GRATUIDAD ','MATRICULADO'}
                    vals.append(q(r.get(c,''), is_text))
                return vals

            # medicine
            if carrera.upper() == 'MEDICINA' and matriculado.upper() == 'SI':
                vals = row_vals(row)
                m.write('INSERT INTO universia_postulaciones.postulantes_medicina_por_periodo (' + ','.join(cols) + ') VALUES (' + ','.join(vals) + ');\n')

            # ici maule
            if carrera.upper() == 'INGENIERÍA CIVIL INFORMÁTICA' and region.upper() == 'MAULE' and matriculado.upper() == 'SI':
                vals = row_vals(row)
                i.write('INSERT INTO universia_postulaciones.postulantes_ici_maule_por_periodo (' + ','.join(cols) + ') VALUES (' + ','.join(vals) + ');\n')

            # ciencias salud
            if row.get('FACULTAD','').upper() == 'CIENCIAS DE LA SALUD' and matriculado.upper() == 'SI':
                vals = row_vals(row)
                s.write('INSERT INTO universia_postulaciones.postulantes_ciencias_salud_por_psu (' + ','.join(cols) + ') VALUES (' + ','.join(vals) + ');\n')

if __name__ == '__main__':
    path = Path(__file__).parents[1] / 'postulaciones.xlsx'
    header, data = read_xlsx(path)
    print('rows', len(data))
    generate(data, Path(__file__).parents[1] / 'cql')
    print('generated cql inserts in cql/')
