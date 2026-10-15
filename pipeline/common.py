"""Rutas y proyección compartidas por todo el pipeline.

Sistema de coordenadas local ("metros de grilla"):
  * Origen: centro de la Plaza de Armas de Talca (-35.42653, -71.66600).
  * Proyección equirectangular local (suficiente a escala de ciudad, error < 0,1 %).
  * Rotación de +5°: la grilla de calles numeradas de Talca está girada ~5° en sentido
    horario respecto del norte; al girar las coordenadas +5° las calles Norte/Sur quedan
    paralelas al eje x y las Oriente/Poniente al eje y. Así la grilla calza con los ejes
    isométricos del render.
  * x crece hacia el oriente, y hacia el norte. En three.js: X = x, Z = -y.
"""
import math, os
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RAW = Path(os.environ.get('TALCA_RAW', ROOT / 'raw'))        # fuentes descargadas (no versionadas)
DATA = ROOT / 'data'                                           # datos procesados (versionados)
CONFIG = ROOT / 'config'

MANZANAS_DIR = RAW / 'chile_geojson' / 'manzanas'
NAV_GRAPH = RAW / 'cicloconecta' / 'data' / 'cities' / 'talca' / 'nav_graph.json'

LAT0, LON0 = -35.42653, -71.66600
KX = 111320 * math.cos(math.radians(35.4265))   # metros por grado de longitud
KY = 110950                                      # metros por grado de latitud
TH = math.radians(5.0)                           # giro de la grilla

def loc(lon, lat):
    """(lon, lat) -> (x, y) en metros de grilla."""
    x = (lon - LON0) * KX
    y = (lat - LAT0) * KY
    return (x * math.cos(TH) - y * math.sin(TH), x * math.sin(TH) + y * math.cos(TH))

def unloc(x, y):
    """(x, y) en metros de grilla -> (lat, lon)."""
    xr = x * math.cos(-TH) - y * math.sin(-TH)
    yr = x * math.sin(-TH) + y * math.cos(-TH)
    return (LAT0 + yr / KY, LON0 + xr / KX)

# La maqueta es la comuna de Talca: su límite (relación de OSM 541797, admin_level=8, dpachile:id 07101), en
# raw/osm/comuna-talca.json. EXT es la caja que lo contiene, ajustada a la grilla del relieve (40 m) con una celda
# de margen; todo lo que va fuera del límite se recorta (la plantilla, con DATA.limit).
COMUNA_OSM = 541797
EXT = (-4920, 15800, -10840, 13000)                      # xmin, xmax, ymin, ymax en metros de grilla

def comuna(eps=2.0):
    """The commune's boundary: one ring [(x, y), ...] in grid metres, counter-clockwise, simplified to `eps` m.
    Downloaded once from the OSM API (relation/<id>/full) and cached in raw/osm/comuna-talca.json."""
    import json, urllib.request
    f = RAW / 'osm' / 'comuna-talca.json'
    if not f.exists():
        url = f'https://api.openstreetmap.org/api/0.6/relation/{COMUNA_OSM}/full.json'
        req = urllib.request.Request(url, headers={'User-Agent': 'talca-isometrica/1.0 (maqueta isometrica de Talca)'})
        f.parent.mkdir(parents=True, exist_ok=True); f.write_bytes(urllib.request.urlopen(req, timeout=120).read())
    d = json.load(open(f))
    rel = [e for e in d['elements'] if e['type'] == 'relation' and e['id'] == COMUNA_OSM][0]
    N = {e['id']: (e['lon'], e['lat']) for e in d['elements'] if e['type'] == 'node'}
    W = {e['id']: e['nodes'] for e in d['elements'] if e['type'] == 'way'}
    segs = [list(W[m['ref']]) for m in rel['members'] if m['type'] == 'way' and m['role'] == 'outer']
    ring = segs.pop(0)
    while segs:                                         # chain the outer ways, each turned to follow the previous one
        for i, s in enumerate(segs):
            if s[0] == ring[-1]: ring += s[1:]; segs.pop(i); break
            if s[-1] == ring[-1]: ring += s[::-1][1:]; segs.pop(i); break
        else: raise SystemExit('el límite de la comuna no cierra')
    assert ring[0] == ring[-1], 'el límite de la comuna no cierra'
    R = [loc(*N[n]) for n in ring[:-1]]
    def rdp(pts):
        if len(pts) < 3: return pts
        a, b = pts[0], pts[-1]; dx, dy = b[0]-a[0], b[1]-a[1]; L = math.hypot(dx, dy) or 1e-9
        d, i = max((abs(dy*(p[0]-a[0]) - dx*(p[1]-a[1])) / L, i) for i, p in enumerate(pts))
        return rdp(pts[:i+1])[:-1] + rdp(pts[i:]) if d > eps else [a, b]
    m = len(R) // 2
    R = rdp(R[:m+1])[:-1] + rdp(R[m:] + [R[0]])[:-1]
    if sum(R[i-1][0]*R[i][1] - R[i][0]*R[i-1][1] for i in range(len(R))) < 0: R = R[::-1]
    return R

_IDX = {}
def _index(ring, band=100):
    """Ring edges by horizontal bands of `band` m (cached per ring): in_ring and clip_line test only nearby edges."""
    k = id(ring)
    if k not in _IDX or _IDX[k][0] is not ring:
        B = {}
        for i in range(len(ring)):
            a, b = ring[i-1], ring[i]
            for j in range(int(min(a[1], b[1]) // band), int(max(a[1], b[1]) // band) + 1): B.setdefault(j, []).append((a, b))
        _IDX[k] = (ring, B, band)
    return _IDX[k][1], _IDX[k][2]

def in_ring(p, ring):
    """Point in polygon (even-odd)."""
    B, band = _index(ring); c = False; x, y = p
    for a, b in B.get(int(y // band), ()):
        if (a[1] > y) != (b[1] > y) and x < a[0] + (y-a[1])*(b[0]-a[0])/(b[1]-a[1]): c = not c
    return c

def near_ring(p, ring, m):
    """Is p inside the polygon or less than m metres from its edge?"""
    if in_ring(p, ring): return True
    B, band = _index(ring); x, y = p
    for j in range(int((y - m) // band), int((y + m) // band) + 1):
        for a, b in B.get(j, ()):
            dx, dy = b[0]-a[0], b[1]-a[1]; L = dx*dx+dy*dy or 1e-9
            t = max(0, min(1, ((x-a[0])*dx+(y-a[1])*dy)/L))
            if math.hypot(x-a[0]-t*dx, y-a[1]-t*dy) < m: return True
    return False

def clip_line(pts, ring):
    """The parts of a polyline inside a polygon: a list of polylines, cut exactly where they cross its edges."""
    B, band = _index(ring); out, cur = [], []
    for k in range(len(pts)):
        p = pts[k]
        if k:
            a = pts[k-1]; ts = []
            edges = {e for j in range(int(min(a[1], p[1]) // band), int(max(a[1], p[1]) // band) + 1) for e in B.get(j, ())}
            for c, d in edges:
                den = (p[0]-a[0])*(d[1]-c[1]) - (p[1]-a[1])*(d[0]-c[0])
                if den == 0: continue
                t = ((c[0]-a[0])*(d[1]-c[1]) - (c[1]-a[1])*(d[0]-c[0])) / den
                u = ((c[0]-a[0])*(p[1]-a[1]) - (c[1]-a[1])*(p[0]-a[0])) / den
                if 0 < t < 1 and 0 <= u < 1: ts.append(t)
            for t in sorted(ts):
                q = (a[0]+(p[0]-a[0])*t, a[1]+(p[1]-a[1])*t)
                if cur: cur.append(q); out.append(cur); cur = []
                else: cur = [q]
        if in_ring(p, ring): cur.append(p)
    if len(cur) > 1: out.append(cur)
    return [l for l in out if len(l) > 1]

def require(path, hint='Ejecute primero: make fetch'):
    if not Path(path).exists():
        raise SystemExit(f'Falta {path}.\n{hint}')
    return path
