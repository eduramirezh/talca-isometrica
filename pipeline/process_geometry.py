"""Fuentes crudas -> data/geometry.json (geometría compacta que se incrusta en el HTML).

Entradas:
  raw/chile_geojson/manzanas/R07_MANZANA_{IND,SIN_INF,ALDEA}_C17.shp.geojson  (Censo 2017, INE)
  raw/cicloconecta/data/cities/talca/nav_graph.json                         (OSM, vía cicloconecta)
  config/trazados.json                                                      (ríos, vía férrea, Ruta 5)
  raw/osm/rio-claro.json      (eje y agua del Río Claro, de la API de OSM; se baja solo la primera vez)

Salida (todas las coordenadas en metros de grilla enteros, codificadas en delta:
[x0, y0, dx1, dy1, ...]):
  ext      [xmin, xmax, ymin, ymax] recorte de la maqueta
  blocks   [[tipo, personas, viviendas, anillo]]  tipo 0=con datos, 1=sin información, 2=aldea
                                                  (build.py marca 3=construida según config/manzanas.json)
  streets  [[clase, idx_nombre, polilínea]]       clase 0 troncal ... 7 servicio
  names    nombres de calle
  water    {claro, lircay, piduco}  ejes de los ríos (el Claro, de OSM; los otros, a mano)
  area     {claro: [contorno, isla, ...]}  agua del Claro según OSM (anillos codificados)
  rail, ruta5, widths
"""
import json, math, collections
from common import loc, MANZANAS_DIR, NAV_GRAPH, CONFIG, DATA, RAW, require

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

def osm_river(name, r):
    """Centreline and water area of a river from OpenStreetMap: the way r['osm']['via'] (waterway=river) and the
    multipolygon r['osm']['agua'] (natural=water, outer ring and islands as inner rings). The download is cached
    in raw/osm/rio-<name>.json; delete it to fetch it again. Returns (centreline, [outer, island, ...]) in grid
    metres, cut to the model with a 300 m margin (centreline) or exactly (area)."""
    from landmark import get
    f = RAW / 'osm' / f'rio-{name}.json'
    if not f.exists():
        api = 'https://api.openstreetmap.org/api/0.6/'
        d = {'via': json.loads(get(f"{api}way/{r['osm']['via']}/full.json")),
             'agua': json.loads(get(f"{api}relation/{r['osm']['agua']}/full.json"))}
        f.parent.mkdir(parents=True, exist_ok=True); f.write_text(json.dumps(d))
    d = json.load(open(f))
    def parts(k):
        el = d[k]['elements']; N = {e['id']: e for e in el if e['type'] == 'node'}
        ways = {e['id']: [loc(N[n]['lon'], N[n]['lat']) for n in e['nodes']] for e in el if e['type'] == 'way'}
        return el, ways
    _, ways = parts('via')
    cl = ways[r['osm']['via']]
    inside = [XMIN-300 < x < XMAX+300 and YMIN-300 < y < YMAX+300 for x, y in cl]
    i0, i1 = inside.index(True), len(inside) - inside[::-1].index(True)
    cl = rdp(cl[max(0, i0-1):i1+1], 3)
    el, ways = parts('agua')
    rel = [e for e in el if e['type'] == 'relation'][0]
    rings = []
    for m in sorted(rel['members'], key=lambda m: m['role'] != 'outer'):   # outer first
        ring = ways[m['ref']]
        assert ring[0] == ring[-1], f"anillo abierto en la vía {m['ref']}"  # each ring is one closed way here
        ring = clip_poly(rdp_ring(ring[:-1], 1.5))
        if len(ring) < 3: continue
        A = 0.5*sum(ring[i-1][0]*ring[i][1] - ring[i][0]*ring[i-1][1] for i in range(len(ring)))
        if abs(A) < 30: continue
        rings.append(ring)
    print(f'río {name} (OSM): eje de {len(cl)} puntos, agua en {len(rings)} anillos ({len(rings)-1} islas)')
    return cl, rings

def main():
    tz = json.load(open(CONFIG / 'trazados.json'))
    L = lambda pts: enc([loc(lo, la) for la, lo in pts])
    blocks = load_blocks(); streets, names = load_streets()
    water, area = {}, {}
    for k, v in tz['rios'].items():
        if 'osm' in v:
            cl, rings = osm_river(k, v); water[k] = enc(cl); area[k] = [enc(r) for r in rings]
        else: water[k] = L(v['puntos'])
    data = {'ext': [XMIN, XMAX, YMIN, YMAX], 'blocks': blocks, 'streets': streets, 'names': names,
            'water': water, 'area': area,
            'widths': {k: [v['ancho_m'], v['ribera_m']] for k, v in tz['rios'].items()},
            'rail': L(tz['ferrocarril']['puntos']), 'ruta5': L(tz['ruta5']['puntos'])}
    DATA.mkdir(exist_ok=True)
    s = json.dumps(data, separators=(',', ':'), ensure_ascii=False)
    (DATA / 'geometry.json').write_text(s); print('data/geometry.json:', len(s), 'bytes')

if __name__ == '__main__':
    main()
