"""Insumos para modelar un hito: planta de OpenStreetMap, marco local y fotos de Wikimedia Commons.

  python landmark.py osm estadio [250]          # baja OSM alrededor del lugar (caja de ±250 m), lista lo
                                                # etiquetado y dibuja diagnostics/plan-estadio.png
  python landmark.py frame estadio 815575960 1073859992 [--origin X Y --angle A]
                                                # coordenadas de esas vías en el marco local del modelo
  python landmark.py photos estadio ["consulta"]  # fotos de Commons en diagnostics/fotos/estadio/
  python landmark.py photos diagonal "Isidoro del Solar Talca"   # algo que no es un lugar: el nombre es la carpeta

osm: el plano muestra, en metros de grilla, las calles del mapa con su ancho de render (gris), las manzanas
con su índice (rosado: con datos; celeste: sin información; verde: construida según config/manzanas.json),
los polígonos de OSM numerados con su id de vía (colores por tipo) y el punto del lugar (negro). Sirve para
ver si el punto de la dirección cae en el hito o en su borde, y si la huella real choca con calles del mapa.
Lista también los nodos etiquetados (torres, entradas, puertas) y las relaciones (pistas, edificios con
patio). La descarga queda en raw/osm/<id>.json; bórrela para volver a bajarla.

frame: el marco local del modelo tiene el origen y el giro de la primera vía (centroide de sus vértices y
dirección de su lado más largo, que pasa a ser el eje v), salvo que se den --origin y --angle (grados desde
+x de la grilla). u es perpendicular a v, hacia la derecha de v. En la plantilla:
  G(u,v) = [X + u·sin(A) + v·cos(A), Y − u·cos(A) + v·sin(A)]
Imprime los lados de la primera vía y, para cada vía, su extensión en u y v y sus vértices.

photos: sin consulta, busca en Commons el nombre del lugar (solo archivos). Guarda miniaturas de 960 px (un
ancho estándar: con otros, Commons responde 429) y un indice.txt con título, fecha, descripción, licencia, autor
y enlace, para citar las que se usen. Las fotos con fecha importan: la imagen satelital puede ser de antes de
una remodelación.

Requiere internet y Pillow para el plano (uv run --with pillow python landmark.py osm …).
"""
import json, math, re, sys, time, urllib.error, urllib.parse, urllib.request
from common import ROOT, DATA, RAW, loc, require

UA = {'User-Agent': 'talca-isometrica/1.0 (maqueta isometrica de Talca)'}
OSM = 'https://api.openstreetmap.org/api/0.6/map.json?bbox={},{},{},{}'
COMMONS = 'https://commons.wikimedia.org/w/api.php?'
SW = [16, 13, 11, 9.5, 7, 5, 3.5, 3.5]   # ancho de calle por clase, como en la plantilla

def get(url, tries=6):
    # Commons answers 429 when several sessions download at once: wait and retry
    for k in range(tries):
        try: return urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=60).read()
        except urllib.error.HTTPError as e:
            if e.code != 429 or k == tries - 1: raise
            time.sleep(10 * (k + 1))

def poi(pid):
    pois = {p['id']: p for p in json.load(open(require(DATA / 'pois.json', 'Ejecute: make pois')))['pois']}
    if pid not in pois: raise SystemExit(f'No existe el lugar {pid!r} en data/pois.json')
    return pois[pid]

def dec(a):
    pts, x, y = [], 0, 0
    for i in range(0, len(a), 2): x += a[i]; y += a[i+1]; pts.append((x, y))
    return pts

def load_osm(pid, half=250):
    f = RAW / 'osm' / f'{pid}.json'
    if not f.exists():
        p = poi(pid); dla, dlo = half / 110950, half / (111320 * math.cos(math.radians(-p['lat'])))
        f.parent.mkdir(parents=True, exist_ok=True)
        f.write_bytes(get(OSM.format(p['lon']-dlo, p['lat']-dla, p['lon']+dlo, p['lat']+dla)))
    d = json.load(open(f))
    nodes = {e['id']: e for e in d['elements'] if e['type'] == 'node'}
    ways = {e['id']: e for e in d['elements'] if e['type'] == 'way'}
    rels = [e for e in d['elements'] if e['type'] == 'relation']
    xy = lambda w: [loc(nodes[n]['lon'], nodes[n]['lat']) for n in w['nodes'] if n in nodes]
    return nodes, ways, rels, xy

SKIP = {'footway', 'path', 'steps', 'crossing', 'cycleway', 'service', 'track'}
def interesting(t):
    return t and not (t.get('highway') in SKIP or 'barrier' in t and len(t) == 1)

def cmd_osm(pid, half='250'):
    half = float(half); p = poi(pid)
    nodes, ways, rels, xy = load_osm(pid, half)
    inrel = {m['ref'] for r in rels for m in r['members'] if m['type'] == 'way'}
    keys = ('name', 'leisure', 'building', 'amenity', 'landuse', 'man_made', 'sport', 'surface', 'highway',
            'building:levels', 'height', 'roof:shape', 'roof:colour', 'building:colour', 'wikimedia_commons')
    print(f"lugar {pid}: ({p['x']:.0f}, {p['y']:.0f}) m de grilla\n\nvías (id, etiquetas, centroide, caja en metros de grilla):")
    shown = []
    for w in ways.values():
        t = w.get('tags', {}); pts = xy(w)
        if not pts or not (interesting(t) or w['id'] in inrel): continue
        cx, cy = sum(q[0] for q in pts)/len(pts), sum(q[1] for q in pts)/len(pts)
        if abs(cx-p['x']) > half or abs(cy-p['y']) > half: continue
        shown.append(w['id'])
        print(f"  {w['id']:>11} {json.dumps({k: t[k] for k in keys if k in t}, ensure_ascii=False) if t else '(sin etiquetas: miembro de relación)'}"
              f"  c ({cx:.0f}, {cy:.0f})  x {min(q[0] for q in pts):.0f}..{max(q[0] for q in pts):.0f}"
              f"  y {min(q[1] for q in pts):.0f}..{max(q[1] for q in pts):.0f}")
    print('\nrelaciones:')
    for r in rels:
        if any(m['ref'] in shown for m in r['members']):
            print(f"  {r['id']:>11} {r.get('tags', {})}  {[(m['ref'], m['role']) for m in r['members'] if m['ref'] in ways]}")
    print('\nnodos etiquetados:')
    for n in nodes.values():
        t = n.get('tags', {})
        if not t or set(t) <= {'natural', 'highway', 'crossing', 'crossing:markings'}: continue
        x, y = loc(n['lon'], n['lat'])
        if abs(x-p['x']) < half and abs(y-p['y']) < half: print(f"  ({x:.0f}, {y:.0f}) {t}")
    plan(pid, p, half, ways, shown, xy)

def plan(pid, p, half, ways, shown, xy):
    try: from PIL import Image, ImageDraw
    except ImportError: print('\n(sin Pillow no hay plano: uv run --with pillow python landmark.py osm …)'); return
    sys.path.insert(0, str(ROOT / 'pipeline')); from build import mark_built
    g = json.load(open(require(DATA / 'geometry.json', 'Ejecute: make data')))
    t0 = [b[0] for b in g['blocks']]; mark_built(g['blocks'])
    S = 2; X0, Y1 = p['x']-half, p['y']+half; N = int(2*half*S)
    img = Image.new('RGB', (N, N), 'white'); d = ImageDraw.Draw(img)
    P = lambda q: ((q[0]-X0)*S, (Y1-q[1])*S)
    inbox = lambda pts, m=0: any(abs(q[0]-p['x']) < half+m and abs(q[1]-p['y']) < half+m for q in pts)
    for k in range(-int(half)//50*50, int(half)+1, 50):
        d.line([P((p['x']+k, Y1)), P((p['x']+k, Y1-2*half))], fill=(235, 235, 235))
        d.line([P((X0, p['y']+k)), P((X0+2*half, p['y']+k))], fill=(235, 235, 235))
    for s in g['streets']:
        pts = dec(s[2])
        if inbox(pts, 60): d.line([P(q) for q in pts], fill=(150, 150, 150), width=max(1, int(SW[s[0]]*S)))
    for i, b in enumerate(g['blocks']):
        r = dec(b[3])
        if not inbox(r): continue
        col = (60, 180, 60) if b[0] != t0[i] else (220, 90, 190) if b[0] == 0 else (0, 170, 220)
        d.polygon([P(q) for q in r], outline=col)
        d.text(P((sum(q[0] for q in r)/len(r), sum(q[1] for q in r)/len(r))), str(i), fill=col)
    for s in g['streets']:
        pts = dec(s[2])
        if inbox(pts): d.text(P(pts[len(pts)//2]), g['names'][s[1]][:18], fill=(60, 60, 60))
    for wid in shown:
        w = ways[wid]; t = w.get('tags', {}); pts = xy(w)
        col = ((0, 0, 220) if t.get('leisure') in ('sports_centre', 'stadium') or 'amenity' in t else
               (220, 0, 0) if 'building' in t else (0, 150, 0) if 'leisure' in t or 'landuse' in t else
               (90, 90, 90) if 'highway' in t else (240, 130, 0))
        d.line([P(q) for q in pts], fill=col, width=2)
        d.text(P(pts[0]), str(wid), fill=col)
    q = P((p['x'], p['y'])); d.ellipse([q[0]-5, q[1]-5, q[0]+5, q[1]+5], fill='black')
    out = ROOT / 'diagnostics' / f'plan-{pid}.png'; out.parent.mkdir(exist_ok=True)
    img.save(out); print(f'\n-> {out.relative_to(ROOT)} ({N} px = {2*half:.0f} m; norte de grilla arriba)')

def cmd_frame(pid, *args):
    args = list(args); origin = angle = None
    if '--origin' in args:
        i = args.index('--origin'); origin = (float(args[i+1]), float(args[i+2])); del args[i:i+3]
    if '--angle' in args:
        i = args.index('--angle'); angle = float(args[i+1]); del args[i:i+2]
    if not args: raise SystemExit('Indique al menos un id de vía')
    nodes, ways, rels, xy = load_osm(pid)
    ids = [int(a) for a in args]
    for wid in ids:
        if wid not in ways: raise SystemExit(f'La vía {wid} no está en raw/osm/{pid}.json')
    ref = xy(ways[ids[0]]); ring = ref[:-1] if ref[0] == ref[-1] else ref
    print(f'vía {ids[0]}: lados')
    for i in range(len(ring)):
        a, b = ring[i], ring[(i+1) % len(ring)]
        print(f'  {math.dist(a, b):7.1f} m  {math.degrees(math.atan2(b[1]-a[1], b[0]-a[0])):7.1f}°')
    if origin is None: origin = (sum(q[0] for q in ring)/len(ring), sum(q[1] for q in ring)/len(ring))
    if angle is None:
        i = max(range(len(ring)), key=lambda i: math.dist(ring[i], ring[(i+1) % len(ring)]))
        a, b = ring[i], ring[(i+1) % len(ring)]; angle = math.degrees(math.atan2(b[1]-a[1], b[0]-a[0])) % 180
    A = math.radians(angle); sa, ca = math.sin(A), math.cos(A); X, Y = origin
    L = lambda q: ((q[0]-X)*sa - (q[1]-Y)*ca, (q[0]-X)*ca + (q[1]-Y)*sa)
    print(f'\nmarco: X={X:.1f} Y={Y:.1f} A={angle:.1f}°   G(u,v) = [X+u·sin A+v·cos A, Y−u·cos A+v·sin A]')
    for wid in ids:
        pts = [L(q) for q in xy(ways[wid])]
        print(f"\n{wid} {ways[wid].get('tags', {})}\n  u {min(q[0] for q in pts):.1f}..{max(q[0] for q in pts):.1f}"
              f"  v {min(q[1] for q in pts):.1f}..{max(q[1] for q in pts):.1f}\n  " +
              ' '.join(f'({u:.0f},{v:.0f})' for u, v in pts))
    tagged = [(n['tags'], L(loc(n['lon'], n['lat']))) for n in nodes.values()
              if n.get('tags') and set(n['tags']) - {'natural', 'highway', 'crossing', 'crossing:markings'}]
    near = [(t, q) for t, q in tagged if abs(q[0]) < 150 and abs(q[1]) < 150]
    if near:
        print('\nnodos etiquetados a menos de 150 m (u, v):')
        for t, q in near: print(f'  ({q[0]:.1f}, {q[1]:.1f}) {t}')

def cmd_photos(pid, query=None):
    q = query or poi(pid)['n']   # con consulta, pid puede ser cualquier nombre (una calle): solo nombra la carpeta
    r = json.loads(get(COMMONS + urllib.parse.urlencode({'action': 'query', 'list': 'search', 'srsearch': q,
                                                         'srnamespace': 6, 'srlimit': 30, 'format': 'json'})))
    titles = [s['title'] for s in r['query']['search'] if s['title'].lower().endswith(('.jpg', '.jpeg', '.png'))]
    if not titles: raise SystemExit(f'Sin fotos en Commons para {q!r}; pruebe otra consulta')
    out = ROOT / 'diagnostics' / 'fotos' / pid; out.mkdir(parents=True, exist_ok=True)
    rows = []
    for k in range(0, len(titles), 20):
        info = json.loads(get(COMMONS + urllib.parse.urlencode({'action': 'query', 'titles': '|'.join(titles[k:k+20]),
              'prop': 'imageinfo', 'iiprop': 'url|extmetadata', 'iiurlwidth': 960, 'format': 'json'})))
        for pg in info['query']['pages'].values():
            if 'imageinfo' not in pg: continue
            ii = pg['imageinfo'][0]; m = ii.get('extmetadata', {})
            val = lambda k: ' '.join(str(m.get(k, {}).get('value', '')).split())
            date = re.search(r'\d{4}(-\d\d-\d\d)?', val('DateTimeOriginal'))
            rows.append((date.group(0) if date else '?', pg['title'], val('ImageDescription')[:160],
                         val('LicenseShortName'), re.sub('<[^>]+>', '', val('Artist'))[:60], ii['descriptionurl'], ii['thumburl']))
    rows.sort(key=lambda r: r[0] if r[0] != '?' else '0', reverse=True)   # sin fecha al final
    with open(out / 'indice.txt', 'w') as f:
        for i, (date, title, desc, lic, author, page, thumb) in enumerate(rows):
            name = f'{i:02d}.jpg'; (out / name).write_bytes(get(thumb)); time.sleep(1)
            line = f'{name}  {date}  {title}  [{lic}] {author}\n    {desc}\n    {page}\n'
            f.write(line); print(line, end='')
    print(f'-> {out.relative_to(ROOT)}/ (más recientes primero)')

if __name__ == '__main__':
    cmds = {'osm': cmd_osm, 'frame': cmd_frame, 'photos': cmd_photos}
    if len(sys.argv) < 3 or sys.argv[1] not in cmds: raise SystemExit(__doc__)
    cmds[sys.argv[1]](*sys.argv[2:])
