"""Fuentes crudas -> data/geometry.json (geometría compacta que se incrusta en el HTML).

Entradas:
  raw/chile_geojson/manzanas/R07_MANZANA_{IND,SIN_INF,ALDEA}_C17.shp.geojson  (Censo 2017, INE)
  raw/cicloconecta/data/cities/talca/nav_graph.json                         (OSM, vía cicloconecta)
  config/trazados.json                                                      (ríos, vía férrea, Ruta 5)
  raw/osm/comuna-talca.json   límite de la comuna (OSM, relación 541797; common.comuna() lo baja la primera vez)
  raw/osm/map-comuna.json     calles de OSM donde el grafo no llega (python traces.py tiles-comuna)
  raw/osm/rio-<río>.json      (eje y agua de cada río con clave `osm`, de la API de OSM; se baja solo la primera vez)

Salida (todas las coordenadas en metros de grilla enteros, codificadas en delta:
[x0, y0, dx1, dy1, ...]):
  ext      [xmin, xmax, ymin, ymax] caja de la maqueta (common.EXT: la comuna, ajustada a la grilla del relieve)
  limit    límite de la comuna (anillo antihorario): la plantilla recorta todo a él
  blocks   [[tipo, personas, viviendas, anillo]]  tipo 0=con datos, 1=sin información, 2=aldea; solo las manzanas
                                                  de la comuna de Talca (COMUNA 7101 del Censo)
                                                  (build.py marca 3=construida según config/manzanas.json)
  streets  [[clase, idx_nombre, polilínea]]       clase 0 troncal ... 7 servicio, recortadas al límite: las del
                                                  grafo de cicloconecta y, donde no llega, las de OSM
  names    nombres de calle
  water    {claro, lircay, piduco}  ejes de los ríos (de OSM los que tienen clave `osm`; los otros, a mano)
  area     {río: [[contorno, isla, ...], ...]}  agua de cada río de OSM: polígonos de anillos codificados
  branch   {río: [rama, ...]}  ramas laterales de un río de OSM (el Piduco Norte)
  rail     eje de la Línea Central (config/trazados.json -> ferrocarril; pipeline/railway.py)
  ramal    eje del ramal a Constitución (ferrocarril -> ramal)
  railx    [[tipo, línea, x, y]] cruces de calles con la vía: tipo 0 la calle pasa bajo la vía, 1 a nivel con
           barreras, 2 a nivel sin barreras; línea 0 la Línea Central, 1 el ramal
  rmast    postes de la catenaria (polilínea codificada: solo los puntos), rsig  señales luminosas (ídem)
  rgauge   [trocha de la Línea Central, trocha del ramal] en metros
  ruta5, widths
"""
import json, math, collections
from common import loc, MANZANAS_DIR, NAV_GRAPH, CONFIG, DATA, RAW, require, EXT, comuna, clip_line

XMIN, XMAX, YMIN, YMAX = EXT                          # ≈ lon -71.722..-71.492, lat -35.532..-35.311
COMUNA = '7101'                                       # código del Censo de la comuna de Talca
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
            if pr.get('COMUNA') != COMUNA: continue
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

def load_streets(R):
    """Encadena las aristas del grafo (dirigidas, duplicadas) en polilíneas por way de OSM; luego agrega las vías de
    OSM (raw/osm/map-comuna.json) que el grafo no tiene: el grafo es de una caja alrededor de la ciudad, sin el campo.
    Todo se recorta al límite de la comuna R."""
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
    def add(c, nm, pts):
        for part in clip_line(pts, R):
            if nm not in nidx: nidx[nm] = len(names); names.append(nm)
            streets.append([c, nidx[nm], enc(part)])
    key = lambda a, b: (a, b) if a < b else (b, a)
    graph = []
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
                pts = [NN[i] for i in chain]; graph.append(pts)
                add(*winfo[wid], rdp(pts, EPS_STREET))
    ng = len(streets)
    osm = osm_streets(graph)
    for c, nm, pts in osm: add(c, nm, pts)
    print('calles:', len(streets), 'polilíneas,', sum(len(s[2])//2 for s in streets), 'vértices;',
          len(streets) - ng, f'de OSM ({len(osm)} tramos donde el grafo no llega)')
    return streets, names

def osm_streets(graph, near=6, cell=50):
    """The highway ways of raw/osm/map-comuna.json (the classes of CLS, no areas) where the graph has no street: a
    segment is left out when both ends and its middle lie within `near` m of a graph segment. Returns
    [(class, name, polyline)], the runs of segments kept, simplified like the graph's."""
    f = RAW / 'osm' / 'map-comuna.json'
    if not f.exists():
        print('(sin raw/osm/map-comuna.json: solo las calles del grafo; python traces.py tiles-comuna)'); return []
    H = collections.defaultdict(list)
    for pl in graph:
        for i in range(len(pl)-1):
            a, b = pl[i], pl[i+1]
            for gx in range(int(min(a[0], b[0])-near)//cell, int(max(a[0], b[0])+near)//cell+1):
                for gy in range(int(min(a[1], b[1])-near)//cell, int(max(a[1], b[1])+near)//cell+1): H[(gx, gy)].append((a, b))
    def covered(p):
        for a, b in H.get((int(p[0])//cell, int(p[1])//cell), ()):
            dx, dy = b[0]-a[0], b[1]-a[1]; L = dx*dx+dy*dy or 1e-9
            t = max(0, min(1, ((p[0]-a[0])*dx+(p[1]-a[1])*dy)/L))
            if math.hypot(p[0]-a[0]-t*dx, p[1]-a[1]-t*dy) < near: return True
        return False
    el = json.load(open(f))['elements']
    N = {e['id']: loc(e['lon'], e['lat']) for e in el if e['type'] == 'node'}
    out = []
    for e in el:
        t = e.get('tags') or {}
        if e['type'] != 'way' or CLS.get(t.get('highway')) is None or t.get('area') == 'yes': continue
        if not all(n in N for n in e['nodes']): continue
        P = [N[n] for n in e['nodes']]
        if all(not (XMIN < p[0] < XMAX and YMIN < p[1] < YMAX) for p in P): continue
        c, nm, run = CLS[t['highway']], t.get('name', ''), []
        for i in range(len(P)-1):
            a, b = P[i], P[i+1]
            if covered(a) and covered(b) and covered(((a[0]+b[0])/2, (a[1]+b[1])/2)):
                if len(run) > 1: out.append((c, nm, rdp(run, EPS_STREET)))
                run = []
            else: run = run + [b] if run else [a, b]
        if len(run) > 1: out.append((c, nm, rdp(run, EPS_STREET)))
    return out

def osm_objs(v, kind):
    """'osm' config value -> [(type, id)]: a number or a list; numbers are `kind`, 'w<id>'/'r<id>' say it."""
    out = []
    for o in (v if isinstance(v, list) else [v]):
        if isinstance(o, int): out.append((kind, o))
        else: out.append(({'w': 'way', 'r': 'relation'}[o[0]], int(o[1:])))
    return out

def osm_river(name, r):
    """Centreline and water area of a river from OpenStreetMap. r['osm']['via']: the waterway way, or a list of
    them in downstream order, chained into one line. r['osm']['ramas'] (optional): ways of side branches, each a
    line of its own (the Piduco Norte, an arm of the Piduco into the Claro). r['osm']['agua']: the natural=water multipolygon (a number),
    or a list of multipolygons and closed ways ('w<id>'). Outer rings that share an edge (OSM splits long water
    areas into pieces) are merged into one; inner rings are the islands. The download is cached in
    raw/osm/rio-<name>.json (fetched again when an object is missing); delete it to fetch it again. Returns
    (centreline, [[outer, island, ...], ...], [branch, ...]) in grid metres, cut to the model with a 300 m margin
    (lines) or exactly (area)."""
    from landmark import get
    f = RAW / 'osm' / f'rio-{name}.json'
    via, agua = osm_objs(r['osm']['via'], 'way'), osm_objs(r['osm']['agua'], 'relation')
    ramas = osm_objs(r['osm'].get('ramas', []), 'way')
    have = lambda d, k, objs: {(e['type'], e['id']) for e in d[k]['elements']} >= set(objs)
    d = json.load(open(f)) if f.exists() else None
    if not d or not have(d, 'via', via + ramas) or not have(d, 'agua', agua):
        api = 'https://api.openstreetmap.org/api/0.6/'
        fetch = lambda objs: {'elements': [e for t, i in objs for e in json.loads(get(f'{api}{t}/{i}/full.json'))['elements']]}
        d = {'via': fetch(via + ramas), 'agua': fetch(agua)}
        f.parent.mkdir(parents=True, exist_ok=True); f.write_text(json.dumps(d))
    def parts(k):
        el = d[k]['elements']; N = {e['id']: e for e in el if e['type'] == 'node'}
        P = {i: loc(e['lon'], e['lat']) for i, e in N.items()}
        return el, {e['id']: e['nodes'] for e in el if e['type'] == 'way'}, P
    _, ways, P = parts('via')
    ch = list(ways[via[0][1]])
    for k, (_, i) in enumerate(via[1:]):                 # chain the ways, each turned to follow the previous one
        w = ways[i]
        if k == 0 and ch[0] in (w[0], w[-1]): ch.reverse()
        if w[-1] == ch[-1]: w = w[::-1]
        assert w[0] == ch[-1], f'la vía {i} no sigue a la anterior'
        ch += w[1:]
    def crop(cl):
        inside = [XMIN-300 < x < XMAX+300 and YMIN-300 < y < YMAX+300 for x, y in cl]
        i0, i1 = inside.index(True), len(inside) - inside[::-1].index(True)
        return rdp(cl[max(0, i0-1):i1+1], 3)
    cl = crop([P[n] for n in ch])
    br = [crop([P[n] for n in ways[i]]) for _, i in ramas]
    el, ways, P = parts('agua')
    area2 = lambda ring: sum(P[ring[i-1]][0]*P[ring[i]][1] - P[ring[i]][0]*P[ring[i-1]][1] for i in range(len(ring)))
    outers, inners = [], []
    for t, i in agua:
        if t == 'way': outers.append(ways[i]); continue
        rel = [e for e in el if e['type'] == 'relation' and e['id'] == i][0]
        for m in sorted(rel['members'], key=lambda m: m['role'] != 'outer'):   # outer first
            ring = ways[m['ref']]
            assert ring[0] == ring[-1], f"anillo abierto en la vía {m['ref']}"  # each ring is one closed way here
            (outers if m['role'] == 'outer' else inners).append(ring)
    if len(outers) > 1:
        # merge outers along their shared edges: with every ring counter-clockwise, a shared edge runs both ways
        # and cancels; the edges left chain into the merged rings. Only rings that share an edge are merged (two
        # pieces that only touch at a node, like the Claro's at y ≈ −629, stay apart), and a group whose edges do not
        # chain into rings is left as it was
        rings = [r[:-1] if area2(r[:-1]) > 0 else r[:-1][::-1] for r in outers]
        owner, grp = {}, list(range(len(rings)))
        find = lambda i: i if grp[i] == i else find(grp[i])
        for i, r in enumerate(rings):
            for k in range(len(r)): owner[(r[k], r[(k+1) % len(r)])] = i
        for (u, v), i in owner.items():
            if (v, u) in owner: grp[find(i)] = find(owner[(v, u)])
        outers = []
        for g in {find(i) for i in range(len(rings))}:
            members = [rings[i] for i in range(len(rings)) if find(i) == g]
            es = {(r[k], r[(k+1) % len(r)]) for r in members for k in range(len(r))}
            nxt, ok = {}, True
            for u, v in es:
                if (v, u) in es: continue
                if u in nxt: ok = False
                nxt[u] = v
            merged = []
            while ok and nxt:
                s = next(iter(nxt)); ring = [s]
                while nxt.get(ring[-1], s) != s and len(ring) <= len(es): ring.append(nxt.pop(ring[-1]))
                if nxt.pop(ring[-1], None) != s: ok = False
                merged.append(ring + [s])
            outers += merged if ok else [r + [r[0]] for r in members]
    def clean(ring):
        ring = clip_poly(rdp_ring([P[n] for n in ring[:-1]], 1.5))
        if len(ring) < 3: return None
        A = 0.5*sum(ring[i-1][0]*ring[i][1] - ring[i][0]*ring[i-1][1] for i in range(len(ring)))
        return ring if abs(A) >= 30 else None
    polys = []
    for o in outers:
        oc = clean(o)
        if not oc: continue
        po = [P[n] for n in o]
        holes = [h for h in inners if pip_xy(P[h[0]], po)]
        polys.append([oc] + [hc for hc in map(clean, holes) if hc])
    n = sum(len(p) for p in polys)
    print(f'río {name} (OSM): eje de {len(cl)} puntos, {len(br)} ramas, agua en {len(polys)} polígonos y {n} anillos ({n-len(polys)} islas)')
    return cl, polys, br

def pip_xy(p, ring):
    c = False; x, y = p
    for i in range(len(ring)):
        a, b = ring[i-1], ring[i]
        if (a[1] > y) != (b[1] > y) and x < a[0] + (y-a[1])*(b[0]-a[0])/(b[1]-a[1]): c = not c
    return c

def rail_extras(fe, L):
    """The ramal, the crossings, the catenary masts and the signals of `ferrocarril` (pipeline/railway.py writes them)."""
    if 'ramal' not in fe: return {}
    x = [[0 if e['tipo'] == 'bajo' else 1 if e.get('barreras') else 2, k] + [round(c) for c in loc(e['punto'][1], e['punto'][0])]
         for k, ps in enumerate((fe.get('pasos', []), fe['ramal'].get('pasos', []))) for e in ps]
    return {'ramal': L(fe['ramal']['puntos']), 'railx': x, 'rmast': L(fe.get('postes', [])), 'rsig': L(fe.get('senales', [])),
            'rgauge': [fe.get('trocha_m', 1.676), fe['ramal'].get('trocha_m', 1.0)]}

def main():
    tz = json.load(open(CONFIG / 'trazados.json'))
    L = lambda pts: enc([loc(lo, la) for la, lo in pts])
    R = comuna(); blocks = load_blocks(); streets, names = load_streets(R)
    water, area, branch = {}, {}, {}
    for k, v in tz['rios'].items():
        if 'osm' in v:
            cl, polys, br = osm_river(k, v); water[k] = enc(cl); area[k] = [[enc(r) for r in p] for p in polys]
            if br: branch[k] = [enc(b) for b in br]
        else: water[k] = L(v['puntos'])
    data = {'ext': [XMIN, XMAX, YMIN, YMAX], 'limit': enc(R), 'blocks': blocks, 'streets': streets, 'names': names,
            'water': water, 'area': area, 'branch': branch,
            'widths': {k: [v['ancho_m'], v['ribera_m']] for k, v in tz['rios'].items()},
            'rail': L(tz['ferrocarril']['puntos']), 'ruta5': L(tz['ruta5']['puntos'])}
    fe = tz['ferrocarril']; data.update(rail_extras(fe, L))
    DATA.mkdir(exist_ok=True)
    s = json.dumps(data, separators=(',', ':'), ensure_ascii=False)
    (DATA / 'geometry.json').write_text(s); print('data/geometry.json:', len(s), 'bytes')

if __name__ == '__main__':
    main()
