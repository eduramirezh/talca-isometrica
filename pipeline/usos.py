"""Usos de suelo: qué hay en los terrenos que el Censo deja en blanco (config/usos.json), y su revisión contra OSM.

La maqueta pinta como arena o parque las manzanas «sin información» del Censo, deja el color del terreno donde no
hay manzanas ni potreros y llena de casas o galpones las manzanas con datos que no son vivienda (el regimiento, los
cementerios, los colegios). config/usos.json dice qué es cada uno de esos terrenos con su polígono, su fuente y una
confianza como la de pois.py; build.py lo inyecta como DATA.usos y la sección «usos de suelo» de la plantilla lo
dibuja (METODOLOGIA §13).

  python pipeline/usos.py importar todo
      Rehace las entradas automáticas (`"auto": true`) desde raw/osm/map-todo.json: cada polígono de OSM con una
      etiqueta de MAPA (abajo) dentro de la maqueta, salvo los que contienen el punto de un hito, los de `excluir`, los
      potreros, huertos, viñas, bosques y eriazos sobre manzanas con datos, y los que pisan más de 40 % de agua. Si
      dos se superponen, el que está dentro del otro queda como hijo (su suelo se recorta del padre) y si no, gana el
      de más prioridad. Las entradas a mano (sin `auto`) se conservan y mandan: lo automático que no es un recinto y
      las cubre en más de 30 % se descarta. Todas quedan con confianza media hasta revisarlas en la imagen.
  python pipeline/usos.py survey todo [x0 x1 y0 y1] [--todo]
      Los polígonos etiquetados de raw/osm/map-todo.json (landuse, amenity, leisure, natural, military…) en la caja,
      del más grande al más chico, con su área, su centro, las manzanas que pisan (t1: «sin información»; t0: con
      datos; t3: construida según manzanas.json) y si ya hay un uso en config/usos.json que los cubre. Por defecto
      solo los que caen en terreno en blanco (manzanas t1 o sin manzana); --todo los lista todos.
      raw/osm/map-todo.json sale de `python pipeline/traces.py tiles -4000 5600 -4200 4700 todo`.
  python pipeline/usos.py osm todo w123 [r456 …] [--eps 1.5]
      El polígono de esas vías o relaciones (multipolígono: el anillo exterior más grande) en metros de grilla,
      simplificado a --eps m, como lista JSON para el campo `poly` de config/usos.json.
  python pipeline/usos.py blancos [ha] [--osm todo]
      Las manzanas «sin información» de más de `ha` hectáreas (0,3) que ningún uso cubre todavía, de la más grande
      a la más chica, con lo que OSM dice que hay en su centro (con --osm). Es la lista de lo que falta revisar.
  python pipeline/usos.py check
      Revisa config/usos.json: que cada entrada tenga uso conocido, polígono, fuente y confianza; que no contenga el
      punto de un hito ni se superponga con otra entrada sin contenerla; cuánta agua pisa (la plantilla no dibuja
      suelo ahí, así que es solo un aviso); que las `vivienda` con `poly` no pisen manzanas del Censo; y cuánto de
      las manzanas en blanco de 4 ha o más queda cubierto.

Formato de config/usos.json: {"excluir": [{"osm": "w123", "motivo": …}, …], "usos": [entrada, …]}. Una entrada tiene
`uso`, `nombre` (opcional), el polígono en una de dos formas: `bi` (el índice de una manzana del Censo, como lo
muestra satellite.py) o `poly` ([[x, y], …] en metros de grilla enteros, sacado de OSM con `usos.py osm` o dibujado
sobre la imagen satelital con `satellite.py punto x y lado z --calles`; con ambos, manda poly); `fuente` (ids de OSM
o «imagen satelital Esri»), `confianza` (alta: OSM y la imagen calzan, o la imagen es clara; media: OSM sin revisar
en la imagen; baja: dudoso), `nota`, y atributos: `rumbo` (grados desde +x de la grilla: dirección de las hileras,
los galpones o las canchas; por defecto, el lado largo del polígono), `cancha` (el deporte de una cancha de OSM),
`tipo` (cementerio «parque»: de prados; industrial «corral»: patio de vehículos), `arboles` (árboles por hectárea en
bosque y eriazo) y `matorral` (0–1, densidad de matorral del eriazo).

Usos: industrial, cementerio, militar, educacional, salud, deportivo (canchas y recintos), golf, parque, huerto, vina,
potrero, feria, bosque y eriazo (sin suelo propio: matorral, huellas y árboles sobre la arena de la manzana o el
terreno), conjunto (viviendas iguales en hileras, donde el mapa no tiene calles), parcelas (casas sueltas en sitios
grandes a lo largo de los caminos) y vivienda (no se dibuja aquí: build.py agrega una manzana construida, tipo 3,
para que la ciudad generada ponga casas a lo largo de las calles del mapa; con `bi`, marca esa manzana como
construida, igual que config/manzanas.json).
"""
import json, math, sys
from common import ROOT, DATA, CONFIG, RAW, loc, require

USOS = ['industrial', 'cementerio', 'militar', 'educacional', 'salud', 'deportivo', 'parque', 'huerto', 'vina',
        'potrero', 'eriazo', 'bosque', 'feria', 'golf', 'vivienda', 'conjunto', 'parcelas', 'terminal']

def dec(a):
    pts, x, y = [], 0, 0
    for i in range(0, len(a), 2): x += a[i]; y += a[i+1]; pts.append((x, y))
    return pts

def pip(p, r):
    inside = False
    for i in range(len(r)):
        (x0, y0), (x1, y1) = r[i-1], r[i]
        if (y0 > p[1]) != (y1 > p[1]) and p[0] < x0 + (p[1]-y0)*(x1-x0)/(y1-y0): inside = not inside
    return inside

def area(r): return abs(sum(r[i-1][0]*r[i][1]-r[i][0]*r[i-1][1] for i in range(len(r))))/2

def centroid(r):
    A = cx = cy = 0
    for i in range(len(r)):
        (x0, y0), (x1, y1) = r[i-1], r[i]; c = x0*y1-x1*y0; A += c; cx += (x0+x1)*c; cy += (y0+y1)*c
    return (cx/(3*A), cy/(3*A)) if A else r[0]

def rdp(pts, eps):
    if len(pts) < 3: return pts
    a, b = pts[0], pts[-1]; dx, dy = b[0]-a[0], b[1]-a[1]; L = math.hypot(dx, dy) or 1e-9
    d = [abs(dy*(p[0]-a[0])-dx*(p[1]-a[1]))/L for p in pts[1:-1]]; i = max(range(len(d)), key=d.__getitem__)
    return rdp(pts[:i+2], eps)[:-1] + rdp(pts[i+1:], eps) if d[i] > eps else [a, b]

def simplify(ring, eps):
    r = rdp(list(ring) + [ring[0]], eps)[:-1]
    return r if len(r) >= 3 else list(ring)

def samples(r, step=20):
    """Points on a grid inside ring r (and its centroid)."""
    xs, ys = [p[0] for p in r], [p[1] for p in r]; out = []
    x = min(xs)+step/2
    while x < max(xs):
        y = min(ys)+step/2
        while y < max(ys):
            if pip((x, y), r): out.append((x, y))
            y += step
        x += step
    c = centroid(r)
    return out or ([c] if pip(c, r) else [r[0]])

# ---------------------------------------------------------------- data
def geometry():
    g = json.load(open(require(DATA / 'geometry.json', 'Ejecute: make data')))
    from build import mark_built
    t0 = [b[0] for b in g['blocks']]; mark_built(g['blocks'])
    blocks = []
    for i, b in enumerate(g['blocks']):
        r = dec(b[3]); xs, ys = [p[0] for p in r], [p[1] for p in r]
        blocks.append({'i': i, 't': b[0], 't0': t0[i], 'r': r, 'A': area(r), 'bb': (min(xs), min(ys), max(xs), max(ys))})
    return g, blocks

class BlockIndex:
    def __init__(self, blocks, cell=100):
        self.b, self.c, self.g = blocks, cell, {}
        for b in blocks:
            x0, y0, x1, y1 = b['bb']
            for gx in range(int(x0//cell), int(x1//cell)+1):
                for gy in range(int(y0//cell), int(y1//cell)+1): self.g.setdefault((gx, gy), []).append(b)
    def at(self, p):
        for b in self.g.get((int(p[0]//self.c), int(p[1]//self.c)), []):
            x0, y0, x1, y1 = b['bb']
            if x0 <= p[0] <= x1 and y0 <= p[1] <= y1 and pip(p, b['r']): return b
        return None

def entries(g=None):
    """config/usos.json -> [(entry, [outer ring, hole, …]), …] in grid metres."""
    if g is None: g = json.load(open(DATA / 'geometry.json'))
    out = []
    for u in json.load(open(CONFIG / 'usos.json'))['usos']:
        if 'poly' in u: rings = [[tuple(p) for p in u['poly']]] + [[tuple(p) for p in h] for h in u.get('huecos', [])]
        else: rings = [dec(g['blocks'][u['bi']][3])]
        out.append((u, rings))
    return out

def load_map(name):
    d = json.load(open(require(RAW / 'osm' / f'map-{name}.json', f'Ejecute: python pipeline/traces.py tiles … {name}')))
    N, W, R = {}, {}, {}
    for e in d['elements']:
        if e['type'] == 'node': N[e['id']] = loc(e['lon'], e['lat'])
        elif e['type'] == 'way': W[e['id']] = e
        else: R[e['id']] = e
    return N, W, R

def join(ways):
    """Chain open ways (lists of node ids) into closed rings."""
    ways, rings = [list(w) for w in ways if len(w) > 1], []
    while ways:
        cur = ways.pop()
        while cur[0] != cur[-1]:
            for k, w in enumerate(ways):
                if w[0] == cur[-1]: cur += w[1:]
                elif w[-1] == cur[-1]: cur += w[-2::-1]
                elif w[-1] == cur[0]: cur = w[:-1] + cur
                elif w[0] == cur[0]: cur = w[:0:-1] + cur
                else: continue
                ways.pop(k); break
            else: break
        if cur[0] == cur[-1] and len(cur) > 3: rings.append(cur[:-1])
    return rings

def shape(obj, N, W):
    """[outer rings], [inner rings] of a closed way or a multipolygon, in grid metres (None if incomplete)."""
    if obj['type'] == 'way':
        nd = obj['nodes']
        if nd[0] != nd[-1] or len(nd) < 4 or any(n not in N for n in nd): return None
        return [[N[n] for n in nd[:-1]]], []
    if obj.get('tags', {}).get('type') not in ('multipolygon', 'boundary'): return None
    parts = {'outer': [], 'inner': []}
    for m in obj['members']:
        if m['type'] != 'way': continue
        w = W.get(m['ref'])
        if not w or any(n not in N for n in w['nodes']): return None
        parts['inner' if m['role'] == 'inner' else 'outer'].append(w['nodes'])
    outer = [[N[n] for n in r] for r in join(parts['outer'])]
    return (outer, [[N[n] for n in r] for r in join(parts['inner'])]) if outer else None

KEYS = {'landuse': None, 'amenity': {'school', 'college', 'university', 'hospital', 'clinic', 'marketplace', 'prison',
        'grave_yard', 'kindergarten', 'parking', 'bus_station', 'fire_station', 'police', 'social_facility'},
        'leisure': {'park', 'pitch', 'stadium', 'sports_centre', 'garden', 'playground', 'golf_course', 'track',
        'recreation_ground', 'nature_reserve', 'common'}, 'natural': {'wood', 'scrub', 'grassland', 'heath',
        'wetland', 'sand', 'bare_rock'}, 'military': None, 'aeroway': {'aerodrome'}, 'man_made': {'wastewater_plant',
        'works', 'silo', 'storage_tank'}, 'power': {'substation', 'plant'}, 'building': {'industrial', 'warehouse',
        'school', 'hospital', 'barracks', 'greenhouse', 'farm_auxiliary', 'hangar'}, 'place': {'neighbourhood'}}

def label(t):
    ks = [f'{k}={t[k]}' for k in KEYS if k in t and (KEYS[k] is None or t[k] in KEYS[k])]
    return ' '.join(ks), t.get('name', '')

def features(name, box=None):
    N, W, R = load_map(name)
    out = []
    for obj in list(W.values()) + list(R.values()):
        t = obj.get('tags', {}); lab, nm = label(t)
        if not lab: continue
        s = shape(obj, N, W)
        if not s: continue
        outer, inner = s
        r = max(outer, key=area); A = sum(area(o) for o in outer) - sum(area(i) for i in inner)
        c = centroid(r)
        if box and not (box[0] <= c[0] <= box[1] and box[2] <= c[1] <= box[3]): continue
        out.append({'id': f"{obj['type'][0]}{obj['id']}", 'lab': lab, 'name': nm, 'A': A, 'c': c, 'r': r, 'outer': outer, 'inner': inner})
    return out

# ---------------------------------------------------------------- commands
def cmd_survey(name, *args):
    flags = [a for a in args if a.startswith('--')]; args = [a for a in args if not a.startswith('--')]
    box = tuple(map(float, args[:4])) if len(args) >= 4 else None
    g, blocks = geometry(); bix = BlockIndex(blocks)
    used = [(u, rs) for u, rs in entries(g)] if (CONFIG / 'usos.json').exists() else []
    for f in sorted(features(name, box), key=lambda f: -f['A']):
        if f['A'] < 1500: continue
        pts = samples(f['r'], max(10, math.sqrt(f['A'])/6)); n = len(pts)
        cnt = {}
        for p in pts:
            b = bix.at(p); k = 'sin manzana' if b is None else f"t{b['t']}"
            cnt[k] = cnt.get(k, 0) + 1
        blank = (cnt.get('t1', 0) + cnt.get('sin manzana', 0)) / n
        if blank < .3 and '--todo' not in flags: continue
        cov = sum(1 for p in pts if any(pip(p, rs[0]) for _, rs in used)) / n
        bis = sorted({b['i'] for p in pts for b in [bix.at(p)] if b and b['t'] == 1})
        print(f"{f['id']:>12} {f['A']/1e4:6.2f} ha ({f['c'][0]:6.0f},{f['c'][1]:6.0f}) {f['lab']:<34} {f['name'][:32]:<32}"
              f" {' '.join(f'{k}:{v*100//n}%' for k, v in sorted(cnt.items()))}{'  usado:%d%%' % (cov*100) if cov else ''}"
              f"{'  bi ' + ','.join(map(str, bis[:6])) if bis else ''}")

def cmd_osm(name, *ids):
    eps = 1.5
    if '--eps' in ids: k = ids.index('--eps'); eps = float(ids[k+1]); ids = ids[:k] + ids[k+2:]
    N, W, R = load_map(name)
    for i in ids:
        obj = (W if i[0] == 'w' else R).get(int(i[1:]))
        s = obj and shape(obj, N, W)
        if not s: print(i, 'no está completo en la descarga', file=sys.stderr); continue
        r = simplify(max(s[0], key=area), eps)
        print(json.dumps([[round(p[0]), round(p[1])] for p in r], separators=(',', ':')))

def cmd_blancos(ha='0.3', *args):
    g, blocks = geometry(); used = entries(g)
    feats = None
    if '--osm' in args:
        feats = features(args[args.index('--osm')+1])
    for b in sorted(blocks, key=lambda b: -b['A']):
        if b['t'] != 1 or b['A'] < float(ha)*1e4: continue
        pts = samples(b['r'], max(8, math.sqrt(b['A'])/5))
        cov = sum(1 for p in pts if any(pip(p, rs[0]) for _, rs in used)) / len(pts)
        if cov > .5: continue
        c = centroid(b['r']); what = ''
        if feats:
            hits = {}
            for p in pts:
                for f in feats:
                    if f['A'] < 2e5 and min(q[0] for q in f['r']) <= p[0] <= max(q[0] for q in f['r']) and pip(p, f['r']):
                        hits[f['id']] = hits.get(f['id'], (f, 0))[0], hits.get(f['id'], (f, 0))[1] + 1
            what = '; '.join(f"{f['id']} {f['lab']} {f['name'][:24]} {n*100//len(pts)}%" for f, n in sorted(hits.values(), key=lambda h: -h[1])[:3])
        print(f"bi {b['i']:5} {b['A']/1e4:5.2f} ha ({c[0]:6.0f},{c[1]:6.0f}) cubierto {cov*100:3.0f}%  {what}")

# OSM tags -> uso, in priority order: where two features overlap without one holding the other, the first wins
MAPA = [('militar', lambda t: t.get('landuse') == 'military' or 'military' in t),
        ('cementerio', lambda t: t.get('landuse') == 'cemetery' or t.get('amenity') == 'grave_yard'),
        ('salud', lambda t: t.get('amenity') in ('hospital', 'clinic')),
        ('educacional', lambda t: t.get('amenity') in ('school', 'college', 'university', 'kindergarten')),
        ('feria', lambda t: t.get('amenity') == 'marketplace'),
        ('terminal', lambda t: t.get('amenity') == 'bus_station'),
        ('deportivo', lambda t: t.get('leisure') in ('stadium', 'sports_centre', 'pitch', 'track', 'golf_course')),
        ('industrial', lambda t: t.get('landuse') == 'industrial' or t.get('man_made') == 'works'),
        ('parque', lambda t: t.get('leisure') in ('park', 'garden', 'recreation_ground') or t.get('landuse') in ('recreation_ground', 'village_green')),
        ('huerto', lambda t: t.get('landuse') == 'orchard'),
        ('vina', lambda t: t.get('landuse') == 'vineyard'),
        ('potrero', lambda t: t.get('landuse') in ('farmland', 'meadow')),
        ('bosque', lambda t: t.get('natural') == 'wood' or t.get('landuse') == 'forest'),
        ('eriazo', lambda t: t.get('natural') in ('scrub', 'grassland', 'heath') or t.get('landuse') in ('brownfield', 'greenfield', 'construction'))]
MINA = {'educacional': 2000, 'salud': 2000, 'terminal': 2000, 'deportivo': 600, 'parque': 2500, 'feria': 1000}  # m², 5000 otherwise
RECINTO = {'militar', 'cementerio', 'salud', 'educacional', 'feria', 'terminal', 'deportivo', 'industrial', 'parque'}
TERRAIN = (-4000, 5600, -4200, 4720)

def cmd_importar(name='todo'):
    """Entries from OSM for every mapped feature in the model; hand entries (no `auto`) and `excluir` are kept."""
    cfg = json.load(open(CONFIG / 'usos.json')); hand = [u for u in cfg['usos'] if not u.get('auto')]
    excl = {e['osm'] for e in cfg.get('excluir', [])}
    g, blocks = geometry(); bix = BlockIndex(blocks); wet = river_tests(g)
    hitos = __import__('re').findall(r'// ==== hito: ([\w-]+) ====', (ROOT / 'src' / 'template.html').read_text())
    pois = {p['id']: p for p in json.load(open(DATA / 'pois.json'))['pois']}
    hp = [(pois[h]['x'], pois[h]['y']) for h in hitos if h in pois]
    N, W, R = load_map(name); cands = []
    for obj in list(W.values()) + list(R.values()):
        t = obj.get('tags', {}); oid = f"{obj['type'][0]}{obj['id']}"
        uso = next((u for u, f in MAPA if f(t)), None)
        if not uso or oid in excl: continue
        s = shape(obj, N, W)
        if not s: continue
        r = simplify(max(s[0], key=area), 1.0); A = area(r)
        c = centroid(r)
        if A < MINA.get(uso, 5000) or not (TERRAIN[0] < c[0] < TERRAIN[1] and TERRAIN[2] < c[1] < TERRAIN[3]): continue
        if any(pip(p, r) for p in hp): continue                         # a landmark models it
        pts = samples(r, max(6, math.sqrt(A)/10))
        kinds = [bix.at(p) for p in pts]; blank = sum(1 for b in kinds if b is None or b['t'] == 1) / len(pts)
        if uso not in RECINTO and blank < .8: continue                  # fields and woods only on blank ground
        if sum(1 for p in pts if wet(p)) > len(pts)*.4: continue        # mostly water (the template lays no ground there)
        if t.get('leisure') == 'golf_course': uso = 'golf'
        nm = t.get('name', '')
        e = {'uso': uso, 'nombre': nm, 'poly': [[round(p[0]), round(p[1])] for p in r], 'fuente': f"OSM {oid} " + label(t)[0],
             'confianza': 'media', 'auto': True}
        if t.get('leisure') == 'pitch': e['cancha'] = t.get('sport', 'soccer')
        if uso == 'cementerio' and 'parque' in nm.lower(): e['tipo'] = 'parque'    # a lawn cemetery
        cands.append((e, r, pts, A))
    # overlaps: a feature inside another (98 % of it) stays as its child; otherwise the higher priority one wins
    order = [u for u, _ in MAPA] + ['golf']
    pri = lambda e: order.index(e['uso']) if e['uso'] != 'golf' else order.index('deportivo')
    hand_r = [(u, rs[0]) for u, rs in entries(g) if not u.get('auto')]
    cands.sort(key=lambda c: (pri(c[0]), -c[3])); kept = []
    for e, r, pts, A in cands:
        if e['uso'] not in RECINTO and any(sum(1 for p in pts if pip(p, hr)) > len(pts)*.3 for _, hr in hand_r): continue
        ok = True
        for e2, r2, pts2, A2 in kept:
            n = sum(1 for p in pts if pip(p, r2)); m = sum(1 for p in pts2 if pip(p, r))
            if n <= len(pts)*.03 and m <= len(pts2)*.03: continue
            if n >= len(pts)*.98 and all(pip(p, r2) for p in r): continue   # child of e2
            if m >= len(pts2)*.98 and all(pip(p, r) for p in r2): continue  # e2 is its child
            ok = False; break
        if ok: kept.append((e, r, pts, A))
    kept.sort(key=lambda c: -c[3])
    cfg['usos'] = hand + [c[0] for c in kept]
    write(cfg)
    cnt = {}
    for e, *_ , A in kept: cnt[e['uso']] = cnt.get(e['uso'], (0, 0)); cnt[e['uso']] = (cnt[e['uso']][0]+1, cnt[e['uso']][1]+A)
    print(f'{len(hand)} entradas a mano, {len(kept)} de OSM:', ', '.join(f'{k} {n} ({a/1e4:.0f} ha)' for k, (n, a) in sorted(cnt.items(), key=lambda kv: -kv[1][1])))

def write(cfg):
    """config/usos.json with one entry per line (diffs stay readable)."""
    j = lambda o: json.dumps(o, ensure_ascii=False, separators=(', ', ': '))
    head = {k: v for k, v in cfg.items() if k not in ('usos', 'excluir')}
    s = '{\n' + ''.join(f'  {j(k)}: {j(v)},\n' for k, v in head.items())
    s += '  "excluir": [\n' + ',\n'.join('    ' + j(e) for e in cfg.get('excluir', [])) + '\n  ],\n'
    s += '  "usos": [\n' + ',\n'.join('    ' + j(e) for e in cfg['usos']) + '\n  ]\n}\n'
    (CONFIG / 'usos.json').write_text(s)

def river_tests(g):
    """(x, y) -> name of the river whose water (area, or axis ribbon) holds the point, or None."""
    areas = {k: [[dec(r) for r in p] for p in v] for k, v in g.get('area', {}).items()}
    def wet(p):
        for k, P in areas.items():
            for poly in P:
                if pip(p, poly[0]) and not any(pip(p, h) for h in poly[1:]): return k
        return None
    return wet

def cmd_check():
    g, blocks = geometry(); E = entries(g); wet = river_tests(g); bix = BlockIndex(blocks); bad = 0
    pois = {p['id']: p for p in json.load(open(DATA / 'pois.json'))['pois']}
    import re
    hitos = re.findall(r'// ==== hito: ([\w-]+) ====', (ROOT / 'src' / 'template.html').read_text())
    tot = {}
    for k, (u, rings) in enumerate(E):
        tag = f"{k:3} {u['uso']:<11} {u.get('nombre', '')[:30]:<30}"
        miss = [f for f in ('uso', 'fuente', 'confianza') if not u.get(f)]
        if u.get('uso') not in USOS: miss.append(f"uso desconocido «{u.get('uso')}»")
        if u.get('confianza') not in ('alta', 'media', 'baja'): miss.append('confianza alta/media/baja')
        A = area(rings[0]) - sum(area(h) for h in rings[1:]); tot[u['uso']] = tot.get(u['uso'], 0) + A
        pts = [p for p in samples(rings[0], 10) if not any(pip(p, h) for h in rings[1:])]
        w = {}
        for p in pts:
            r = wet(p)
            if r: w[r] = w.get(r, 0) + 1
        if w and u['uso'] not in ('eriazo', 'bosque') and sum(w.values()) > len(pts)*.4: miss.append('pisa el agua: ' + ', '.join(f'{r} {n*100/len(pts):.1f}%' for r, n in w.items()))
        if u['uso'] == 'vivienda' and 'poly' in u:
            n = sum(1 for p in pts if bix.at(p))
            if n > len(pts)*.05: miss.append(f'vivienda sobre manzanas del Censo ({n*100//len(pts)}%): use bi o recorte el polígono')
        for h in hitos:
            p = pois.get(h)
            if p and pip((p['x'], p['y']), rings[0]): miss.append(f'contiene el punto del hito {h}')
        for j, (v, rs) in enumerate(E[:k]):
            if {u['uso'], v['uso']} & {'eriazo', 'bosque', 'parcelas', 'vivienda'}: continue   # no ground of their own
            n = sum(1 for p in pts if pip(p, rs[0]))
            if n <= len(pts)*.02: continue
            if all(pip(p, rs[0]) for p in rings[0]) or all(pip(p, rings[0]) for p in rs[0]): continue  # nested
            miss.append(f'se superpone con la entrada {j} ({n*100//len(pts)}%)')
        if miss: bad += 1
        print(f"{tag} {A/1e4:6.2f} ha" + ('  ' + '; '.join(miss) if miss else ''))
    print('\npor uso:', ', '.join(f'{k} {v/1e4:.1f} ha' for k, v in sorted(tot.items(), key=lambda kv: -kv[1])))
    big = [b for b in blocks if b['t'] == 1 and b['A'] >= 4e4]
    cov = 0
    for b in big:
        pts = samples(b['r'], 25); n = sum(1 for p in pts if any(pip(p, rs[0]) for _, rs in E))
        cov += b['A']*n/len(pts)
        if n < len(pts)*.8: print(f"manzana en blanco bi {b['i']} ({b['A']/1e4:.1f} ha): cubierta {n*100//len(pts)}%")
    print(f"manzanas en blanco de 4 ha o más: {len(big)}, {sum(b['A'] for b in big)/1e4:.0f} ha, cubiertas {cov/1e4:.0f} ha")
    if bad: print(f'\n{bad} entradas con observaciones')

if __name__ == '__main__':
    cmds = {'survey': cmd_survey, 'osm': cmd_osm, 'blancos': cmd_blancos, 'check': cmd_check, 'importar': cmd_importar}
    if len(sys.argv) < 2 or sys.argv[1] not in cmds: raise SystemExit(__doc__)
    cmds[sys.argv[1]](*sys.argv[2:])
