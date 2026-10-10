"""Fuentes crudas -> data/geometry.json (geometría compacta que se incrusta en el HTML).

Entradas:
  raw/chile_geojson/manzanas/R07_MANZANA_{IND,SIN_INF,ALDEA}_C17.shp.geojson  (Censo 2017, INE)
  raw/cicloconecta/data/cities/talca/nav_graph.json                         (OSM, vía cicloconecta)
  config/trazados.json                                                      (ríos, vía férrea, Ruta 5)

Salida (todas las coordenadas en metros de grilla enteros, codificadas en delta:
[x0, y0, dx1, dy1, ...]):
  ext      [xmin, xmax, ymin, ymax] recorte de la maqueta
  blocks   [[tipo, personas, viviendas, anillo]]  tipo 0=con datos, 1=sin información, 2=aldea
                                                  (build.py marca 3=construida según config/manzanas.json)
  streets  [[clase, idx_nombre, polilínea]]       clase 0 troncal ... 7 servicio
  names    nombres de calle
  water    {claro, lircay, piduco}  + rail, ruta5 + widths
"""
import json, math, collections
from common import loc, MANZANAS_DIR, NAV_GRAPH, CONFIG, DATA, require

XMIN, XMAX, YMIN, YMAX = -4000, 5600, -4200, 4700     # ≈ lon -71.712..-71.598, lat -35.468..-35.380
EPS_BLOCK, EPS_STREET = 1.2, 0.8                      # tolerancia Douglas-Peucker (m)

def rdp(pts, eps):
    if len(pts) < 3: return pts
    a, b = pts[0], pts[-1]; dx, dy = b[0]-a[0], b[1]-a[1]; L = math.hypot(dx, dy) or 1e-9
    dmax, idx = 0, 0
    for i in range(1, len(pts)-1):
        p = pts[i]; d = abs(dy*(p[0]-a[0]) - dx*(p[1]-a[1])) / L
        if d > dmax: dmax, idx = d, i
    if dmax > eps: return rdp(pts[:idx+1], eps)[:-1] + rdp(pts[idx:], eps)
    return [a, b]

def rdp_ring(ring, eps):
    # un anillo cerrado tiene inicio == fin, así que se simplifica en dos mitades
    if len(ring) <= 4: return ring
    m = len(ring) // 2
    return rdp(ring[:m+1], eps)[:-1] + rdp(ring[m:] + [ring[0]], eps)[:-1]

def clip_poly(P):
    """Sutherland-Hodgman contra el rectángulo de la maqueta."""
    for axis, val, sgn in [(0, XMIN, 1), (0, XMAX, -1), (1, YMIN, 1), (1, YMAX, -1)]:
        if not P: return P
        ins = lambda q: (q[axis]-val)*sgn >= 0
        def cut(p, c):
            t = (val-p[axis])/(c[axis]-p[axis]); return (p[0]+(c[0]-p[0])*t, p[1]+(c[1]-p[1])*t)
        out = []
        for i in range(len(P)):
            c, p = P[i], P[i-1]
            if ins(c):
                if not ins(p): out.append(cut(p, c))
                out.append(c)
            elif ins(p): out.append(cut(p, c))
        P = out
    return P

def enc(pts):
    out = []; px = py = 0
    for x, y in pts:
        xi, yi = int(round(x)), int(round(y)); out += [xi-px, yi-py]; px, py = xi, yi
    return out

def load_blocks():
    blocks, count = [], collections.Counter()
    for fn, t in [('R07_MANZANA_IND_C17', 0), ('R07_MANZANA_SIN_INF_C17', 1), ('R07_MANZANA_ALDEA_C17', 2)]:
        d = json.load(open(require(MANZANAS_DIR / f'{fn}.shp.geojson')))
        for f in d['features']:
            g = f['geometry']; polys = g['coordinates'] if g['type'] == 'MultiPolygon' else [g['coordinates']]
            pr = f['properties']
            for p in polys:
                ring = [loc(x, y) for x, y in p[0]]
                xs = [q[0] for q in ring]; ys = [q[1] for q in ring]
                if max(xs) < XMIN or min(xs) > XMAX or max(ys) < YMIN or min(ys) > YMAX: continue
                if ring[0] == ring[-1]: ring = ring[:-1]
                ring = clip_poly(rdp_ring(ring, EPS_BLOCK))
                if len(ring) < 3: continue
                A = 0.5*sum(ring[i-1][0]*ring[i][1] - ring[i][0]*ring[i-1][1] for i in range(len(ring)))
                if abs(A) < 30: continue
                if A < 0: ring = ring[::-1]          # siempre antihorario
                blocks.append([t, pr.get('TOTAL_PERS') or 0, pr.get('TOTAL_VIVI') or 0, enc(ring)])
                count[t] += 1
    print('manzanas por tipo (0 datos, 1 sin info, 2 aldea):', dict(count))
    return blocks

CLS = {'trunk':0,'trunk_link':0,'primary':1,'primary_link':1,'secondary':2,'secondary_link':2,'tertiary':3,
       'tertiary_link':3,'unclassified':4,'residential':4,'living_street':5,'pedestrian':6,'service':7}

def load_streets():
    """Encadena las aristas del grafo (dirigidas, duplicadas) en polilíneas por way de OSM."""
    g = json.load(open(require(NAV_GRAPH)))
    NN = {n['id']: loc(n['lon'], n['lat']) for n in g['nodes']}
    seen = set(); ways = collections.defaultdict(list); winfo = {}
    for e in g['edges']:
        c = CLS.get(e['highway'])
        if c is None: continue                     # sin ciclovías, senderos ni huellas
        k = frozenset((e['u'], e['v']))
        if k in seen: continue
        seen.add(k); ways[e['way_id']].append((e['u'], e['v'])); winfo[e['way_id']] = (c, e['name'] or '')
    names, nidx, streets = [], {}, []
    key = lambda a, b: (a, b) if a < b else (b, a)
    for wid, es in ways.items():
        adj = collections.defaultdict(list)
        for u, v in es: adj[u].append(v); adj[v].append(u)
        used = set()
        for s in [n for n in adj if len(adj[n]) != 2] + list(adj):
            for nb in adj[s]:
                if key(s, nb) in used: continue
                chain = [s, nb]; used.add(key(s, nb)); cur, prev = nb, s
                while len(adj[cur]) == 2:
                    nx = [w for w in adj[cur] if w != prev][0]
                    if key(cur, nx) in used: break
                    used.add(key(cur, nx)); chain.append(nx); prev, cur = cur, nx
                pts = rdp([NN[i] for i in chain], EPS_STREET)
                if all(not (XMIN < p[0] < XMAX and YMIN < p[1] < YMAX) for p in pts): continue
                c, nm = winfo[wid]
                if nm not in nidx: nidx[nm] = len(names); names.append(nm)
                streets.append([c, nidx[nm], enc(pts)])
    print('calles:', len(streets), 'polilíneas,', sum(len(s[2])//2 for s in streets), 'vértices')
    return streets, names

def main():
    tz = json.load(open(CONFIG / 'trazados.json'))
    L = lambda pts: enc([loc(lo, la) for la, lo in pts])
    blocks = load_blocks(); streets, names = load_streets()
    data = {'ext': [XMIN, XMAX, YMIN, YMAX], 'blocks': blocks, 'streets': streets, 'names': names,
            'water': {k: L(v['puntos']) for k, v in tz['rios'].items()},
            'widths': {k: [v['ancho_m'], v['ribera_m']] for k, v in tz['rios'].items()},
            'rail': L(tz['ferrocarril']['puntos']), 'ruta5': L(tz['ruta5']['puntos'])}
    DATA.mkdir(exist_ok=True)
    s = json.dumps(data, separators=(',', ':'), ensure_ascii=False)
    (DATA / 'geometry.json').write_text(s); print('data/geometry.json:', len(s), 'bytes')

if __name__ == '__main__':
    main()
