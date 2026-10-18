"""Usos de suelo: qué hay en los terrenos que el Censo deja en blanco (config/usos.json), y su revisión contra OSM.

La maqueta pinta como arena o parque las manzanas «sin información» del Censo, deja el color del terreno donde no
hay manzanas ni potreros y llena de casas o galpones las manzanas con datos que no son vivienda (el regimiento, los
cementerios, los colegios). config/usos.json dice qué es cada uno de esos terrenos con su polígono, su fuente y una
confianza como la de pois.py; build.py lo inyecta como DATA.usos y la sección «usos de suelo» de la plantilla lo
dibuja (METODOLOGIA §13).

  python pipeline/usos.py importar comuna
      Rehace las entradas automáticas (`"auto": true`) desde raw/osm/map-comuna.json (`make osm`): cada polígono de
      OSM con una etiqueta de MAPA (abajo) con su centro en la comuna, salvo los que contienen el punto de un hito, los de `excluir`, los
      potreros, huertos, viñas, bosques y eriazos sobre manzanas con datos, y los que pisan más de 40 % de agua. Si
      dos se superponen, el que está dentro del otro queda como hijo (su suelo se recorta del padre) y si no, gana el
      de más prioridad. Las entradas a mano (sin `auto`) se conservan y mandan: lo automático que no es un recinto y
      las cubre en más de 30 % se descarta. Todas quedan con confianza media hasta revisarlas en la imagen. Con
      `todo` (raw/osm/map-todo.json, el rectángulo anterior a la comuna) se perderían las del campo.
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
  python -I pipeline/usos.py importar ciren | censo2024 | areasverdes
      Las fuentes chilenas (pipeline/fuentes_cl.py, raw/cl/), cada una a su archivo: los huertos del Catastro Frutícola
      2024 de CIREN–ODEPA con su especie, año de plantación, conducción y árboles por hectárea (config/usos-ciren.json);
      las manzanas del Censo 2024 construidas desde 2017 que el mapa no tiene, como `vivienda` con sus viviendas y
      personas (config/usos-censo2024.json, CC BY-SA 4.0); las plazas y parques del Catastro de Áreas Verdes 2023 de
      MINVU–INE que ninguna entrada cubre (config/usos-minvu.json). Cada una reescribe solo sus entradas (`importado`),
      anida o recorta las suyas contra las entradas con suelo y quita de config/usos.json las de OSM que reemplaza.
  python -I pipeline/usos.py escuelas [matrícula mínima] | salud
      Los colegios abiertos del Directorio 2025 de MINEDUC (o los hospitales, clínicas, CESFAM, CECOSF y SAPU de DEIS)
      sin entrada educacional (salud) a 30 m: su manzana, el polígono de OSM que los contiene y la línea de satellite.py.
  python pipeline/usos.py check
      Revisa los archivos de usos (config/usos.json y los de las fuentes chilenas): que cada entrada tenga uso conocido, polígono, fuente y confianza; que no contenga el
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
`tipo` (cementerio «parque»: de prados; industrial «corral»: patio de vehículos; «aserradero»: rumas de madera y
troncos entre pocos galpones largos), `arboles` (árboles por hectárea en bosque y eriazo) y `matorral` (0–1, densidad
de matorral del eriazo); los huertos de CIREN, `especie`, `plantacion` (año), `conduccion` (alambrada, parronal,
espaldera, libre) y `arboles_ha`; las `vivienda` del Censo 2024, `viviendas` y `personas`. Las entradas de los archivos
de las fuentes chilenas llevan `importado` (el comando que las escribió).

Usos: industrial, cementerio, militar, educacional, salud, deportivo (canchas y recintos), golf, parque, huerto, vina,
potrero, feria, bosque y eriazo (sin suelo propio: matorral, huellas y árboles sobre la arena de la manzana o el
terreno), conjunto (viviendas iguales en hileras, donde el mapa no tiene calles), parcelas (casas sueltas en sitios
grandes a lo largo de los caminos) y vivienda (no se dibuja aquí: build.py agrega una manzana construida, tipo 3,
para que la ciudad generada ponga casas a lo largo de las calles del mapa; con `bi`, marca esa manzana como
construida, igual que config/manzanas.json).
"""
import json, math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))   # python -I pipeline/usos.py (raw/cl/ is not trusted)
from common import ROOT, DATA, CONFIG, RAW, loc, require, comuna
from build import hito_ids, usos_entries, USOS_FILES

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
    """The land-use files (build.USOS_FILES: config/usos.json and those of the Chilean sources) -> [(entry, [outer
    ring, hole, …]), …] in grid metres."""
    if g is None: g = json.load(open(DATA / 'geometry.json'))
    out = []
    for u in usos_entries():
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

def cmd_importar(name='comuna'):
    """Entries from OSM for every mapped feature in the model; hand entries (no `auto`) and `excluir` are kept."""
    if name in CL_FILE: return CL_IMPORT[name]()
    cfg = json.load(open(CONFIG / 'usos.json')); hand = [u for u in cfg['usos'] if not u.get('auto')]
    excl = {e['osm'] for e in cfg.get('excluir', [])}
    g, blocks = geometry(); bix = BlockIndex(blocks); wet = river_tests(g)
    hitos = hito_ids()
    pois = {p['id']: p for p in json.load(open(DATA / 'pois.json'))['pois']}
    hp = [(pois[h]['x'], pois[h]['y']) for h in hitos if h in pois]
    lim = comuna(); N, W, R = load_map(name); cands = []
    for obj in list(W.values()) + list(R.values()):
        t = obj.get('tags', {}); oid = f"{obj['type'][0]}{obj['id']}"
        uso = next((u for u, f in MAPA if f(t)), None)
        if not uso or oid in excl: continue
        s = shape(obj, N, W)
        if not s: continue
        r = simplify(max(s[0], key=area), 1.0); A = area(r)
        c = centroid(r)
        if A < MINA.get(uso, 5000) or not pip(c, lim): continue   # in the commune (its centre)
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

def write(cfg, name='usos.json'):
    """config/<name> (config/usos.json or one of the Chilean sources' files) with one entry per line (diffs stay readable)."""
    j = lambda o: json.dumps(o, ensure_ascii=False, separators=(', ', ': '))
    head = {k: v for k, v in cfg.items() if k not in ('usos', 'excluir')}
    s = '{\n' + ''.join(f'  {j(k)}: {j(v)},\n' for k, v in head.items())
    if 'excluir' in cfg or name == 'usos.json':
        s += '  "excluir": [\n' + ',\n'.join('    ' + j(e) for e in cfg.get('excluir', [])) + '\n  ],\n'
    s += '  "usos": [\n' + ',\n'.join('    ' + j(e) for e in cfg['usos']) + '\n  ]\n}\n'
    (CONFIG / name).write_text(s)

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
    hitos = hito_ids()
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

# ---------------------------------------------------------------- Chilean sources (pipeline/fuentes_cl.py)
# Each goes to a file of its own (build.USOS_FILES), for its licence: CIREN–ODEPA (usos-ciren.json), INE Censo 2024
# (usos-censo2024.json, CC BY-SA 4.0) and MINVU–INE (usos-minvu.json). Their entries carry `importado` (the command that
# wrote them, which rewrites only those) and count as hand entries for `importar comuna`: an OSM field, orchard,
# vineyard, wood or vacant lot (REEMPLAZABLES) that a newer source covers by more than 30 % is dropped from
# config/usos.json, the same rule `importar comuna` applies to hand entries.
REEMPLAZABLES = {'huerto', 'vina', 'potrero', 'eriazo', 'bosque'}
CL_FILE = {'ciren': 'usos-ciren.json', 'censo2024': 'usos-censo2024.json', 'areasverdes': 'usos-minvu.json'}
CL_HEAD = {
    'usos-ciren.json': {'_comentario': 'Huertos del Catastro Frutícola Maule 2024 de CIREN–ODEPA, con su especie, año de plantación, conducción y árboles por hectárea: `python -I pipeline/usos.py importar ciren` los rehace. Las viñas del Uso de la Tierra 2022 de CIREN no entraron: no calzan con la imagen (docs/METODOLOGIA.md §13). Formato: pipeline/usos.py.',
                        '_licencia': 'Información pública del Estado (IDE Minagri), sin licencia declarada; cite «CIREN–ODEPA, Catastro Frutícola Región del Maule 2024». Ver docs/FUENTES.md.'},
    'usos-censo2024.json': {'_comentario': 'Manzanas del Censo 2024 construidas desde 2017 que el mapa (manzanas de 2017) no tiene: `python pipeline/usos.py importar censo2024` las rehace. Formato: pipeline/usos.py.',
                            '_licencia': 'CC BY-SA 4.0. Fuente: INE, Censo de Población y Vivienda 2024 (cartografía, publicada el 15-12-2025). Este archivo es una adaptación y se comparte con la misma licencia.'},
    'usos-minvu.json': {'_comentario': 'Plazas y parques del Catastro Nacional de Áreas Verdes 2023 (MINVU–INE) que ninguna otra entrada cubre: `python pipeline/usos.py importar areasverdes` las rehace. Formato: pipeline/usos.py.',
                        '_licencia': 'Información de carácter referencial (MINVU, IDE geoide.minvu.cl); cite «MINVU–INE, Catastro Nacional de Áreas Verdes 2023». Ver docs/FUENTES.md.'},
}

class RingIndex:
    """Rings with their boxes in 200 m cells: frac(pts) is the share of pts inside any of them."""
    def __init__(self, rings, cell=200):
        self.c, self.g = cell, {}
        for r in rings:
            xs, ys = [p[0] for p in r], [p[1] for p in r]; bb = (min(xs), min(ys), max(xs), max(ys))
            for gx in range(int(bb[0]//cell), int(bb[2]//cell)+1):
                for gy in range(int(bb[1]//cell), int(bb[3]//cell)+1): self.g.setdefault((gx, gy), []).append((bb, r))
    def has(self, p):
        return any(bb[0] <= p[0] <= bb[2] and bb[1] <= p[1] <= bb[3] and pip(p, r) for bb, r in self.g.get((int(p[0]//self.c), int(p[1]//self.c)), ()))
    def frac(self, pts):
        return sum(1 for p in pts if self.has(p)) / len(pts) if pts else 0

def cl_context(tag):
    """What every Chilean import checks against: the census blocks, the rivers, the commune, the landmarks' points, and
    the entries of every file but those this import rewrites."""
    g, blocks = geometry()
    pois = {p['id']: p for p in json.load(open(DATA / 'pois.json'))['pois']}
    others = [(u, rs) for u, rs in entries(g) if u.get('importado') != tag]
    return {'g': g, 'blocks': blocks, 'bix': BlockIndex(blocks), 'wet': river_tests(g), 'lim': comuna(), 'others': others,
            'hp': [(pois[h]['x'], pois[h]['y']) for h in hito_ids() if h in pois]}

def cl_write(tag, new):
    """Write the entries of import `tag` (its file keeps any others), then drop the OSM entries they replace."""
    name = CL_FILE[tag]; f = CONFIG / name
    cfg = json.load(open(f)) if f.exists() else dict(CL_HEAD[name], usos=[])
    cfg['usos'] = [u for u in cfg['usos'] if u.get('importado') != tag] + new
    write(cfg, name)
    print(f'{len(new)} entradas de {tag} -> config/{name}')
    drop_replaced()

def drop_replaced():
    """The automatic REEMPLAZABLES of config/usos.json that the entries of the Chilean files cover by more than 30 %."""
    g = json.load(open(DATA / 'geometry.json'))
    newer = RingIndex([rs[0] for f in USOS_FILES[1:] if (CONFIG / f).exists()
                       for u in json.load(open(CONFIG / f))['usos'] for rs in [[[tuple(p) for p in u['poly']]] if 'poly' in u else [dec(g['blocks'][u['bi']][3])]]])
    cfg = json.load(open(CONFIG / 'usos.json')); keep, gone = [], []
    for u in cfg['usos']:
        if u.get('auto') and u['uso'] in REEMPLAZABLES:
            r = [tuple(p) for p in u['poly']]; pts = samples(r, max(6, math.sqrt(area(r))/10))
            if newer.frac(pts) > .3: gone.append(u); continue
        keep.append(u)
    if gone:
        cfg['usos'] = keep; write(cfg)
        print(f'config/usos.json: {len(gone)} entradas de OSM reemplazadas:', ', '.join(f"{u['uso']} {u['fuente'].split()[1]} ({area(u['poly'])/1e4:.1f} ha)" for u in gone))

GROUND = {'industrial', 'cementerio', 'militar', 'educacional', 'salud', 'deportivo', 'golf', 'parque', 'huerto', 'vina',
          'potrero', 'feria', 'conjunto', 'terminal'}   # the uses that lay ground of their own (USO_GROUND in 76-usos.js)

def rfill(rings, x0, y0, nx, ny, c=1.0):
    """The cells (c m, from (x0, y0), nx × ny) whose centres lie inside any of the rings: a bytearray, row by row."""
    g = bytearray(nx*ny)
    for j in range(ny):
        y = y0 + (j+.5)*c
        for r in rings:
            xs = sorted(r[i-1][0] + (y-r[i-1][1])*(r[i][0]-r[i-1][0])/(r[i][1]-r[i-1][1]) for i in range(len(r)) if (r[i-1][1] > y) != (r[i][1] > y))
            for k in range(0, len(xs)-1, 2):
                for i in range(max(0, math.ceil((xs[k]-x0)/c-.5)), min(nx-1, math.floor((xs[k+1]-x0)/c-.5))+1): g[j*nx+i] = 1
    return g

def rgrow(g, nx, ny, n):
    """g dilated (n > 0) or eroded (n < 0) by |n| cells (4-neighbours)."""
    for _ in range(abs(n)):
        h = bytearray(g); v = 1 if n > 0 else 0
        for j in range(ny):
            for i in range(nx):
                if g[j*nx+i] != v and ((i > 0 and g[j*nx+i-1] == v) or (i < nx-1 and g[j*nx+i+1] == v) or (j > 0 and g[(j-1)*nx+i] == v) or (j < ny-1 and g[(j+1)*nx+i] == v)): h[j*nx+i] = v
        g = h
    return g

def rtrace(g, nx, ny, x0, y0, c=1.0):
    """The outline of the cells set in g: rings (counter-clockwise outside), along the cell edges."""
    nxt = {}
    for j in range(ny):
        for i in range(nx):
            if not g[j*nx+i]: continue
            if j == 0 or not g[(j-1)*nx+i]: nxt.setdefault((i, j), []).append((i+1, j))          # bottom, eastwards
            if i == nx-1 or not g[j*nx+i+1]: nxt.setdefault((i+1, j), []).append((i+1, j+1))  # right, northwards
            if j == ny-1 or not g[(j+1)*nx+i]: nxt.setdefault((i+1, j+1), []).append((i, j+1))  # top, westwards
            if i == 0 or not g[j*nx+i-1]: nxt.setdefault((i, j+1), []).append((i, j))          # left, southwards
    rings = []
    while nxt:
        s = next(iter(nxt)); ring = [s]; p = s
        while True:
            q = nxt[p].pop()
            if not nxt[p]: del nxt[p]
            if q == s: break
            ring.append(q); p = q
            if p not in nxt: break
        if len(ring) > 3: rings.append([(x0+i*c, y0+j*c) for i, j in ring])
    return rings

def rclip(r, inside=(), outside=(), c=1.0):
    """Ring r cut to lie 2 m inside each ring of `inside` and 2 m off each ring of `outside` (raster at c m): its largest
    remaining part, simplified to 1 m, or None."""
    xs, ys = [p[0] for p in r], [p[1] for p in r]; x0, y0 = min(xs)-3, min(ys)-3
    nx, ny = int((max(xs)-x0)/c)+4, int((max(ys)-y0)/c)+4
    g = rfill([r], x0, y0, nx, ny, c)
    for k in inside:
        h = rgrow(rfill([k], x0, y0, nx, ny, c), nx, ny, -2); g = bytearray(a & b for a, b in zip(g, h))
    for k in outside:
        h = rgrow(rfill([k], x0, y0, nx, ny, c), nx, ny, 2); g = bytearray(a & (1-b) for a, b in zip(g, h))
    rs = rtrace(g, nx, ny, x0, y0, c)
    if not rs: return None
    o = simplify(max(rs, key=area), 1.0)
    return o if len(o) >= 3 and area(o) > 1000 else None

def nest(r, others):
    """Ring r of a new ground entry against the ground entries `others` [(entry, rings)]: mostly (> 50 %) inside one,
    it is cut 2 m inside it (it becomes its kid, which the template cuts out of its ground); partly over one, the
    overlap is cut out (two grounds over each other flicker, or the rows of one show over the other). (r, note) or
    (None, why)."""
    pts = samples(r, max(5, math.sqrt(area(r))/12)); ins, outs = [], []
    for u, rs in others:
        if u['uso'] not in GROUND: continue
        o = rs[0]; xs = [p[0] for p in o]; ys = [p[1] for p in o]
        if max(p[0] for p in r) < min(xs) or min(p[0] for p in r) > max(xs) or max(p[1] for p in r) < min(ys) or min(p[1] for p in r) > max(ys): continue
        n = sum(1 for p in pts if pip(p, o)) / len(pts)
        if n <= .01 and not any(pip(p, o) for p in r): continue
        if all(pip(p, o) for p in r): continue                                           # nested already
        if all(pip(p, r) for p in o) and n < .99: continue                               # it holds the other
        (ins if n > .5 else outs).append(o)
    if not ins and not outs: return r, ''
    q = rclip(r, ins, outs)
    return (q, f'recortado a {len(ins)} entrada(s) que lo contiene(n) y fuera de {len(outs)}') if q else (None, 'no queda nada al recortar')

def cl_nest(ctx, cands, why):
    """[(ring, entry without its poly)] -> the entries, each ring nested (nest()) in what stays of the other files'
    ground entries once the OSM ones that the new rings and the Chilean files cover by more than 30 % are dropped."""
    idx = RingIndex([r for r, _ in cands] + [rs[0] for u, rs in ctx['others'] if u.get('importado')])
    stay = [(u, rs) for u, rs in ctx['others'] if not (u.get('auto') and u['uso'] in REEMPLAZABLES
            and idx.frac(samples(rs[0], max(6, math.sqrt(area(rs[0]))/10))) > .3)]
    out = []
    for r, e in cands:
        if e['uso'] in GROUND:
            r, note = nest(r, stay)
            if note: k = note.split(' a ')[0].split(' al ')[0]; why[k] = why.get(k, 0) + 1
            if r is None: continue
        e['poly'] = [[round(p[0]), round(p[1])] for p in r]; out.append(e)
    return out

def cl_place(ctx, r):
    """Can a new entry with ring r go in? None, or why not."""
    A = area(r); c = centroid(r)
    if not pip(c, ctx['lim']): return 'fuera de la comuna'
    if any(pip(p, r) for p in ctx['hp']): return 'contiene el punto de un hito'
    pts = samples(r, max(6, math.sqrt(A)/10))
    if sum(1 for p in pts if ctx['wet'](p)) > len(pts)*.4: return 'sobre el agua'
    return None

CIREN_ESP = {'MANZANO ROJO': 'manzano', 'MANZANO VERDE': 'manzano', 'CEREZO': 'cerezo', 'OLIVO': 'olivo', 'CIRUELO EUROPEO': 'ciruelo',
             'CIRUELO JAPONES': 'ciruelo', 'KIWI': 'kiwi', 'NOGAL': 'nogal', 'AVELLANO': 'avellano', 'VID DE MESA': 'uva', 'PERAL': 'peral',
             'MORAS CULTIVADAS E HIBRIDOS': 'mora', 'PALTO': 'palto', 'CAQUI': 'caqui', 'MEMBRILLO': 'membrillo', 'ARANDANO AMERICANO': 'arandano'}
CIREN_COND = {'ALAMBRADA': 'alambrada', 'PARRONAL ESPANOL': 'parronal', 'ESPALDERA': 'espaldera', 'V_TRELLIS': 'espaldera', 'SIN SISTEMA': 'libre'}

def imp_ciren():
    """CIREN–ODEPA Catastro Frutícola Maule 2024: an orchard (huerto) per predio polygon, with the dominant species of
    its blocks (by area), their area-weighted planting year, trellis system and trees per hectare. A polygon that
    falls mostly on census blocks with data, on a landmark or on the water, or over an entry that is not an OSM
    field, is left out."""
    from fuentes_cl import FILES, polys, table
    rows = {}
    for b in table(FILES['ciren-tabla']):
        if b['anoinfor'] == 2024 and b['supbloq_ha']: rows.setdefault(b['mslink'], []).append(b)
    ctx = cl_context('ciren'); keep = RingIndex([rs[0] for u, rs in ctx['others'] if not (u.get('auto') and u['uso'] in REEMPLAZABLES)])
    cands, why = [], {}
    for props, rings in polys(FILES['ciren']):
        bl = rows.get(props['mslink'])
        if not bl: continue                                         # a predio of another commune (the box is larger)
        r = simplify(rings[0], 1.0); A = area(r)
        if A < 5000: why['menos de 0,5 ha'] = why.get('menos de 0,5 ha', 0) + 1; continue
        no = cl_place(ctx, r)
        if not no:
            pts = samples(r, max(6, math.sqrt(A)/10))
            if sum(1 for p in pts if (b := ctx['bix'].at(p)) and b['t'] in (0, 3)) > len(pts)*.5: no = 'sobre manzanas con datos'
            elif keep.frac(pts) > .3: no = 'sobre otra entrada'
        if no: why[no] = why.get(no, 0) + 1; continue
        sp = {}
        for b in bl: sp[b['descespe']] = sp.get(b['descespe'], 0) + b['supbloq_ha']
        top = max(sp, key=sp.get); bs = [b for b in bl if b['descespe'] == top]; ha = sum(b['supbloq_ha'] for b in bs)
        cond = {}
        for b in bs: cond[b['descsico']] = cond.get(b['descsico'], 0) + b['supbloq_ha']
        e = {'uso': 'huerto', 'nombre': '', 'poly': None,
             'especie': CIREN_ESP.get(top, top.lower()), 'plantacion': round(sum(b['anoplant']*b['supbloq_ha'] for b in bs)/ha),
             'conduccion': CIREN_COND.get(max(cond, key=cond.get), 'libre'), 'arboles_ha': round(sum(b['numearbo'] for b in bs)/ha),
             'fuente': f"CIREN–ODEPA Catastro Frutícola Maule 2024, mslink {props['mslink']} ({len(bl)} cuarteles: {', '.join(f'{k.lower()} {v:.1f} ha' for k, v in sorted(sp.items(), key=lambda kv: -kv[1]))})",
             'confianza': 'alta', 'importado': 'ciren'}
        cands.append((r, e))
    new = cl_nest(ctx, cands, why)
    new.sort(key=lambda e: -area(e['poly']))
    print('fuera:', ', '.join(f'{k} {v}' for k, v in why.items()) or 'ninguno')
    cnt = {}
    for e in new: cnt[e['especie']] = cnt.get(e['especie'], 0) + area(e['poly'])
    print(f"{len(new)} huertos, {sum(cnt.values())/1e4:.0f} ha:", ', '.join(f'{k} {v/1e4:.0f} ha' for k, v in sorted(cnt.items(), key=lambda kv: -kv[1])))
    cl_write('ciren', new)

def imp_censo2024():
    """INE Censo 2024: the populated blocks (dwellings or people) built since 2017, which the map's blocks (Censo 2017)
    lack, as `vivienda` with their dwellings and people (build.py appends them as built blocks for cityGen). A block
    goes in when it has 8 dwellings per hectare or more, or 2 or more on 2 ha or less: the larger, sparser ones are
    rural pseudo-blocks of a few houses among fields and orchards (the 46 ha east of the Ruta 5 have 46 dwellings), and
    a built block of 2 ha or more with fewer than 8 per hectare gets sheds (recipeOf). One partly on 2017 blocks is
    cut 2 m off them (and keeps the share of its dwellings of what is left); one mostly on them, a hand entry of
    housing or a CIREN orchard is left out. A 2017 block «sin información» that dense 2024 blocks cover by more than
    60 % (and no entry does) becomes built: `bi`. The 2017 blocks stay the map's (their `bi` index config/usos.json)."""
    from fuentes_cl import FILES, polys
    ctx = cl_context('censo2024'); blocks = ctx['blocks']
    b17 = BlockIndex(blocks)
    hand = RingIndex([rs[0] for u, rs in ctx['others'] if u['uso'] in ('vivienda', 'conjunto', 'parcelas') or u.get('importado') == 'ciren'])
    anyu = RingIndex([rs[0] for u, rs in ctx['others'] if not (u.get('auto') and u['uso'] in REEMPLAZABLES)])
    new, why, dense = [], {}, []
    for p, rings in polys(FILES['censo2024']):
        viv, per = round(p.get('n_vp') or 0), round(p.get('n_per') or 0)
        if viv <= 0: continue
        r = simplify(rings[0], 1.0); A = area(r)
        if A < 400: continue
        d = viv / (A/1e4)
        if d >= 8: dense.append(r)
        pts = samples(r, max(4, math.sqrt(A)/10))
        on17 = [b for b in {id(b): b for q in pts for b in [b17.at(q)] if b}.values()]
        f17 = sum(1 for q in pts if b17.at(q)) / len(pts)
        no = None
        if f17 > .9: continue                                         # a 2017 block (or most of it): the map has it
        if d < 2 or (d < 8 and A > 2e4): no = f'menos de {"2" if d < 2 else "8"} viviendas por hectárea'
        elif (w := cl_place(ctx, r)): no = w
        elif hand.frac(pts) > .3: no = 'sobre una entrada de vivienda o un huerto'
        elif anyu.frac(pts) > .6: no = 'sobre otra entrada'
        if not no and f17 > .01:
            r2 = rclip(r, outside=[b['r'] for b in on17])
            if r2 is None: no = 'no queda nada fuera de las manzanas de 2017'
            else: k = area(r2)/A; r, viv, per = r2, max(1, round(viv*k)), max(1, round(per*k)); why['recortada'] = why.get('recortada', 0) + 1
        if no: why[no] = why.get(no, 0) + 1; continue
        new.append({'uso': 'vivienda', 'nombre': '', 'poly': [[round(q[0]), round(q[1])] for q in r], 'viviendas': viv, 'personas': per,
                    'fuente': f"INE Censo 2024, manzana {int(p['MANZENT'])} ({round(p.get('n_vp') or 0)} viviendas, {round(p.get('n_per') or 0)} personas)",
                    'confianza': 'alta', 'importado': 'censo2024'})
    # the 2017 blocks «sin información» that the census of 2024 finds built
    di = RingIndex(dense); nb = 0
    for b in blocks:
        if b['t'] != 1 or b['A'] < 1000: continue
        pts = samples(b['r'], max(4, math.sqrt(b['A'])/10))
        if di.frac(pts) > .6 and anyu.frac(pts) < .3 and hand.frac(pts) < .3:
            new.append({'uso': 'vivienda', 'nombre': '', 'bi': b['i'], 'fuente': 'INE Censo 2024: manzanas con 8 viviendas por hectárea o más sobre esta manzana «sin información» de 2017',
                        'confianza': 'alta', 'importado': 'censo2024'}); nb += 1
    print('fuera:', ', '.join(f'{k} {v}' for k, v in why.items()))
    ha = sum(area(e['poly']) for e in new if 'poly' in e)/1e4
    print(f"{len(new)-nb} manzanas nuevas ({ha:.0f} ha, {sum(e.get('viviendas', 0) for e in new)} viviendas) y {nb} manzanas «sin información» de 2017 construidas")
    cl_write('censo2024', new)

def titulo(s):
    """«VILLA DON SEBASTIÁN» -> «Villa Don Sebastián» (the particles in lower case)."""
    low = {'de', 'del', 'la', 'las', 'los', 'el', 'y', 'e'}
    return ' '.join(w.lower() if k and w.lower() in low else w.capitalize() for k, w in enumerate(s.split()))

def imp_areasverdes():
    """MINVU–INE Catastro Nacional de Áreas Verdes 2023: a `parque` for each plaza or park of 300 m² or more that no
    entry but housing covers yet (5 % of it at most; the rest is nested like CIREN's orchards), on no landmark and no
    water. The
    template still leaves out one on the Alameda or in a landmark's grounds (usosPlan)."""
    from fuentes_cl import FILES, polys
    ctx = cl_context('areasverdes')   # (vivienda and parcelas lay no ground: a plaza in a villa is fine)
    cands, why = [], {}
    for p, rings in polys(FILES['minvu']):
        r = simplify(rings[0], 0.7); A = area(r)
        if A < 300: why['menos de 300 m²'] = why.get('menos de 300 m²', 0) + 1; continue
        no = cl_place(ctx, r)
        if not no:   # what other entries cover of it, but those wholly inside it (a pitch in the park: its kid)
            xs, ys = [q[0] for q in r], [q[1] for q in r]; bb = (min(xs), min(ys), max(xs), max(ys))
            near = [o[0] for u, o in ctx['others'] if u['uso'] not in ('vivienda', 'parcelas') and not (max(q[0] for q in o[0]) < bb[0] or min(q[0] for q in o[0]) > bb[2]
                    or max(q[1] for q in o[0]) < bb[1] or min(q[1] for q in o[0]) > bb[3]) and not all(pip(q, r) for q in o[0])]
            if near and RingIndex(near).frac(samples(r, max(3, math.sqrt(A)/10))) > .05: no = 'sobre otra entrada'
        if no: why[no] = why.get(no, 0) + 1; continue
        nm = titulo(p.get('NOMBRE_EP') or '').strip(); tipo = (p.get('TIPO_EP') or 'PLAZA').capitalize()
        cands.append((r, {'uso': 'parque', 'nombre': f'{tipo} {nm}' if nm and not nm.lower().startswith(tipo.lower()) else nm or tipo, 'poly': None,
                          'fuente': f"MINVU–INE Catastro Nacional de Áreas Verdes 2023, ID_AV {p.get('ID_AV')}", 'confianza': 'media', 'importado': 'areasverdes'}))
    new = cl_nest(ctx, cands, why)
    print('fuera:', ', '.join(f'{k} {v}' for k, v in why.items()))
    print(f"{len(new)} plazas y parques, {sum(area(e['poly']) for e in new)/1e4:.0f} ha")
    cl_write('areasverdes', new)

# ---- checklists: the schools of MINEDUC and the health centres of DEIS that no entry covers
SALUD_TIPOS = ('Hospital', 'Clínica', 'Centro de Salud Familiar', 'Centro Comunitario de Salud Familiar', 'Servicio de Atención Primaria de Urgencia',
               'Centro de Especialidades', 'Centro Comunitario de Salud Mental', 'Centro de Referencia de Salud', 'Centro de Diagnóstico Terapéutico',
               'Centro de Rehabilitación')

def establecimientos(kind):
    """MINEDUC's directory 2025 (open schools) or DEIS's establishments (operating hospitals, clinics, CESFAM, CECOSF,
    SAPU/SAR, specialty and mental-health centres) in the commune -> [{'p', 'n', 'id', 'mat' (students; 0 in DEIS), 't'}]."""
    import csv
    from fuentes_cl import FILES
    lim, out = comuna(), []
    if kind == 'escuelas':
        for r in csv.DictReader(open(FILES['mineduc'], encoding='utf-8-sig'), delimiter=';'):
            if r['COD_COM_RBD'] != '7101' or r['ESTADO_ESTAB'] != '1' or not r['LATITUD'].strip(): continue
            p = loc(float(r['LONGITUD'].replace(',', '.')), float(r['LATITUD'].replace(',', '.')))
            if pip(p, lim): out.append({'p': p, 'n': r['NOM_RBD'], 'id': f"MINEDUC Directorio 2025 RBD {r['RBD']}", 'mat': int(r['MAT_TOTAL'] or 0), 't': 'rural' if r['RURAL_RBD'] == '1' else ''})
    else:
        for r in csv.DictReader(open(FILES['deis'], encoding='utf-8-sig'), delimiter=';'):
            if r['ComunaCodigo'].lstrip('0') != '7101' or not r['Latitud'].strip() or 'Vigente' not in r['EstadoFuncionamiento']: continue
            if not r['TipoEstablecimientoGlosa'].startswith(SALUD_TIPOS) or r['TipoEstablecimientoGlosa'].startswith('Clínica Dental'): continue
            p = loc(float(r['Longitud']), float(r['Latitud']))
            if pip(p, lim): out.append({'p': p, 'n': r['EstablecimientoGlosa'], 'id': f"DEIS establecimientos 2026-10-14, código {r['EstablecimientoCodigo']}", 'mat': 0, 't': r['TipoEstablecimientoGlosa']})
    return out

def cmd_lista(kind, minimo='0'):
    """`usos.py escuelas [matrícula mínima]` or `usos.py salud`: the establishments without an educacional (salud) entry
    within 30 m, from the largest: their block, what entries are there, the OSM polygon that holds the point (with
    the `usos.py osm` line to take it) and the `satellite.py` line to trace it by hand."""
    want, keys = ('educacional', {'amenity=school', 'amenity=college', 'amenity=university', 'amenity=kindergarten', 'building=school'}) if kind == 'escuelas' \
        else ('salud', {'amenity=hospital', 'amenity=clinic', 'building=hospital'})
    g, blocks = geometry(); bix = BlockIndex(blocks); E = entries(g)
    feats = [f for f in features('comuna') if set(f['lab'].split()) & keys]
    pois = {p['id']: p for p in json.load(open(DATA / 'pois.json'))['pois']}; hp = {h: pois[h] for h in hito_ids() if h in pois}
    near = lambda p, r, m: pip(p, r) or any(math.hypot(*(lambda a, b: (p[0]-a[0]-max(0, min(1, ((p[0]-a[0])*(b[0]-a[0])+(p[1]-a[1])*(b[1]-a[1]))/((b[0]-a[0])**2+(b[1]-a[1])**2 or 1)))*(b[0]-a[0]),
                                                                     p[1]-a[1]-max(0, min(1, ((p[0]-a[0])*(b[0]-a[0])+(p[1]-a[1])*(b[1]-a[1]))/((b[0]-a[0])**2+(b[1]-a[1])**2 or 1)))*(b[1]-a[1])))(r[i-1], r[i])) < m for i in range(len(r)))
    rows = establecimientos(kind); miss = []
    for e in rows:
        p = e['p']; box = lambda r: min(q[0] for q in r)-30 <= p[0] <= max(q[0] for q in r)+30 and min(q[1] for q in r)-30 <= p[1] <= max(q[1] for q in r)+30
        here = [u['uso'] for u, rs in E if box(rs[0]) and near(p, rs[0], 30)]
        if want in here or e['mat'] < int(minimo): continue
        b = bix.at(p); f = [x for x in feats if any(pip(p, o) for o in x['outer'])]
        h = [k for k, q in hp.items() if math.hypot(q['x']-p[0], q['y']-p[1]) < 120]
        miss.append((e, b, here, f, h))
    miss.sort(key=lambda m: (-m[0]['mat'], m[0]['n']))
    print(f'{len(rows)} establecimientos en la comuna; {len(miss)} sin entrada {want} a 30 m' + (f' (con {minimo} alumnos o más)' if int(minimo) else '') + ':')
    for e, b, here, f, h in miss:
        print(f"{(str(e['mat']) + ' al.') if kind == 'escuelas' else e['t'][:30]:>{10 if kind == 'escuelas' else 30}} {e['n'][:44]:44} ({e['p'][0]:6.0f},{e['p'][1]:6.0f}) {e['id'].split(', ')[-1].split(' 2025 ')[-1]:>14}"
              f"  manzana {b['i'] if b else '-'}{' t' + str(b['t']) if b else ''}{'  usos: ' + ','.join(here) if here else ''}{'  hito cerca: ' + ','.join(h) if h else ''}")
        print(' ' * 12 + (f"OSM {f[0]['id']} {f[0]['name'][:30]} ({f[0]['A']/1e4:.2f} ha): python pipeline/usos.py osm comuna {f[0]['id']}" if f else
                          f"sin polígono de OSM: uv run --with pillow python pipeline/satellite.py punto {e['p'][0]:.0f} {e['p'][1]:.0f} 250 19 --calles"))

CL_IMPORT = {'ciren': imp_ciren, 'censo2024': imp_censo2024, 'areasverdes': imp_areasverdes}

if __name__ == '__main__':
    cmds = {'survey': cmd_survey, 'osm': cmd_osm, 'blancos': cmd_blancos, 'check': cmd_check, 'importar': cmd_importar,
            'escuelas': lambda *a: cmd_lista('escuelas', *a), 'salud': lambda *a: cmd_lista('salud', *a)}
    if len(sys.argv) < 2 or sys.argv[1] not in cmds: raise SystemExit(__doc__)
    cmds[sys.argv[1]](*sys.argv[2:])
