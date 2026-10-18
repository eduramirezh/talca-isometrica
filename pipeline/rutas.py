"""Los nombres de las rutas del mapa contra la Red Vial de la Dirección de Vialidad (MOP), que es la autoridad de los roles.

Los rótulos de las rutas del campo («Ruta K-355», src/js/90-overlay.js) son el `name` de OSM de cada vía, que
process_geometry.py guarda en data/geometry.json. Cuando OSM tiene mal un rol, config/rutas.json lo corrige con un
reemplazo que lleva su fuente; process_geometry.py lo aplica al armar las calles (y lo ideal es corregir también OSM:
la próxima `make osm` lo traería bien).

  python -I pipeline/rutas.py check [m]
      Cada nombre «Ruta …» del mapa (después de los reemplazos): su largo en la comuna y los roles del MOP que corren a
      menos de m metros (25) de él, con la parte de su largo que cubre cada uno. Avisa cuando el rol que más cubre no es
      el del nombre. La Red Vial está en raw/cl/vialidad/red_vial.geojson (ArcGIS 10.2:
      https://rest-sit.mop.gob.cl/arcgis/rest/services/VIALIDAD/Red_Vial_Chile/MapServer/3, raw/eval/chile.md §7).

Formato de config/rutas.json: {"reemplazos": [{"de": nombre en OSM, "a": nombre corregido, "fuente": …, "nota": …}]}.
"""
import json, math, os, re, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import CONFIG, DATA, RAW, loc

def reemplazos():
    """config/rutas.json -> {name in OSM: corrected name}."""
    f = CONFIG / 'rutas.json'
    return {r['de']: r['a'] for r in json.load(open(f))['reemplazos']} if f.exists() else {}

def dec(a):
    pts, x, y = [], 0, 0
    for i in range(0, len(a), 2): x += a[i]; y += a[i+1]; pts.append((x, y))
    return pts

def seg_d(p, a, b):
    dx, dy = b[0]-a[0], b[1]-a[1]; L = dx*dx+dy*dy or 1e-9
    t = max(0, min(1, ((p[0]-a[0])*dx+(p[1]-a[1])*dy)/L))
    return math.hypot(p[0]-a[0]-t*dx, p[1]-a[1]-t*dy)

def check(m='25'):
    m = float(m); g = json.load(open(DATA / 'geometry.json'))
    mop, cell = {}, 100
    for f in json.load(open(RAW / 'cl' / 'vialidad' / 'red_vial.geojson'))['features']:
        geo = f.get('geometry') or {}; rol = f['properties']['ROL']
        lines = geo.get('coordinates', []) if geo.get('type') == 'MultiLineString' else [geo.get('coordinates', [])]
        for ln in lines:
            P = [loc(p[0], p[1]) for p in ln]
            for a, b in zip(P, P[1:]):
                for gx in range(int(min(a[0], b[0])-m)//cell, int(max(a[0], b[0])+m)//cell+1):
                    for gy in range(int(min(a[1], b[1])-m)//cell, int(max(a[1], b[1])+m)//cell+1): mop.setdefault((gx, gy), []).append((a, b, rol))
    names = {}
    for s in g['streets']:
        nm = g['names'][s[1]]
        if not nm.startswith('Ruta '): continue
        P = dec(s[2])
        for a, b in zip(P, P[1:]):
            L = math.dist(a, b); n = max(1, int(L//10))
            for k in range(n):
                p = (a[0]+(b[0]-a[0])*(k+.5)/n, a[1]+(b[1]-a[1])*(k+.5)/n); hit = set()
                for q0, q1, rol in mop.get((int(p[0]//cell), int(p[1]//cell)), ()):
                    if seg_d(p, q0, q1) < m: hit.add(rol)
                c = names.setdefault(nm, {'L': 0, 'r': {}}); c['L'] += L/n
                for rol in hit: c['r'][rol] = c['r'].get(rol, 0) + L/n
    norm = lambda s: re.sub(r'[^0-9A-Z]', '', s.upper().replace('RUTA', ''))
    for nm, c in sorted(names.items(), key=lambda kv: -kv[1]['L']):
        top = sorted(c['r'].items(), key=lambda kv: -kv[1])
        warn = top and norm(top[0][0]) != norm(nm) and top[0][1] > c['L']*.5
        print(f"{nm:24} {c['L']/1000:6.1f} km  " + ', '.join(f'{r} {v*100/c["L"]:.0f} %' for r, v in top[:3]) + ('   <- el MOP dice otro rol' if warn else ''))

if __name__ == '__main__':
    if len(sys.argv) < 2 or sys.argv[1] != 'check': raise SystemExit(__doc__)
    check(*sys.argv[2:])
