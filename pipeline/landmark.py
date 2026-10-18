"""Insumos para modelar un hito: planta de OpenStreetMap, marco local y fotos de Wikimedia Commons.

  python landmark.py osm estadio [250]          # baja OSM alrededor del lugar (caja de ±250 m), lista lo
                                                # etiquetado y dibuja diagnostics/plan-estadio.png
  python landmark.py osm 4170,3725 [120]        # lo mismo alrededor de un punto de la grilla (x,y en metros),
                                                # para lo que no es un lugar: un puente, un paso bajo nivel
  python landmark.py frame estadio 815575960 1073859992 [--origin X Y --angle A]
                                                # coordenadas de esas vías en el marco local del modelo
  python landmark.py photos estadio ["consulta"]  # fotos de Commons en diagnostics/fotos/estadio/
  python landmark.py photos diagonal "Isidoro del Solar Talca"   # algo que no es un lugar: el nombre es la carpeta
  python landmark.py photos estacion --geo 150 --cat    # además, las fotos con coordenadas a menos de 150 m (100 por
                                                # omisión) y las de la categoría de Commons de su elemento de Wikidata
                                                # (wd= en pois.py; --cat "Categoría" da otra)
  python landmark.py photos estacion --panoramax 150 [--mapillary 100] [--flickr 100]   # otras fuentes en ese radio

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
una remodelación. Las opciones suman fuentes a la misma lista (sin repetir), en el mismo indice.txt con la fuente y,
si la foto tiene coordenadas, su distancia al lugar («de frente» si la cámara lo mira, ±45°):
  --geo [r]        Commons por ubicación: encuentra lo que el nombre no (la Estación: 40 archivos a menos de 150 m
                   contra 6 por nombre).
  --cat [cat]      los archivos de una categoría de Commons: la P373 del elemento de Wikidata del lugar, o la dada.
  --panoramax [r]  fotos a nivel de calle de Panoramax (sin clave, CC BY-SA 4.0; en 2026 casi nada en Talca).
  --mapillary [r]  Mapillary (CC BY-SA 4.0): necesita la clave en MAPILLARY_TOKEN; sin ella dice cómo pedirla.
  --flickr [r]     Flickr, solo licencias libres: necesita la clave en FLICKR_KEY; sin ella dice cómo pedirla.
La consulta puede ir en cualquier lugar salvo justo después de --cat, que la tomaría como categoría.

Requiere internet y Pillow para el plano (uv run --with pillow python landmark.py osm …).
"""
import json, math, os, re, sys, time, urllib.error, urllib.parse, urllib.request
from common import ROOT, DATA, RAW, loc, unloc, require

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
    m = re.fullmatch(r'(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)', pid)
    if m:                                # a point of the grid, not a place: «4170,3725» (a bridge, a crossing)
        x, y = map(float, m.groups()); la, lo = unloc(x, y)
        return {'id': pid, 'n': pid, 'x': x, 'y': y, 'lat': la, 'lon': lo}
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
            'building:levels', 'height', 'roof:shape', 'roof:colour', 'building:colour', 'wikimedia_commons',
            'railway', 'usage', 'gauge', 'bridge', 'tunnel', 'layer', 'waterway')
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

def where(pid):
    """(lat, lon, x, y) of a place or a grid point, or None for a free name (a street) that is neither."""
    try: p = poi(pid)
    except SystemExit: return None
    return p['lat'], p['lon'], p['x'], p['y']

def bbox(lat, lon, r):
    dla, dlo = r / 110950, r / (111320 * math.cos(math.radians(-lat)))
    return lon - dlo, lat - dla, lon + dlo, lat + dla

def facing(lat, lon, at, az):
    """Whether a camera at (lat, lon) looking at azimuth az (degrees from true north) faces the place at `at`, ±45°."""
    if az is None: return False
    x, y = loc(lon, lat)
    b = (math.degrees(math.atan2(at[2] - x, at[3] - y)) - 5) % 360   # the grid is turned +5°: back to true north
    return min(abs(b - az), 360 - abs(b - az)) < 45

def commons_rows(titles, at=None):
    """Commons files -> rows (date, source, title, description, licence, author, page, thumb, note)."""
    rows = []
    for k in range(0, len(titles), 20):
        info = json.loads(get(COMMONS + urllib.parse.urlencode({'action': 'query', 'titles': '|'.join(titles[k:k+20]),
              'prop': 'imageinfo|coordinates', 'iiprop': 'url|extmetadata', 'iiurlwidth': 960, 'format': 'json'})))
        for pg in info['query']['pages'].values():
            if 'imageinfo' not in pg: continue
            ii = pg['imageinfo'][0]; m = ii.get('extmetadata', {})
            val = lambda k: ' '.join(str(m.get(k, {}).get('value', '')).split())
            date = re.search(r'\d{4}(-\d\d-\d\d)?', val('DateTimeOriginal'))
            note = ''
            if at and pg.get('coordinates'):
                c = pg['coordinates'][0]; note = f'a {math.dist(loc(c["lon"], c["lat"]), at[2:]):.0f} m'
            rows.append((date.group(0) if date else '?', 'Commons', pg['title'], val('ImageDescription')[:160],
                         val('LicenseShortName'), re.sub('<[^>]+>', '', val('Artist'))[:60], ii['descriptionurl'], ii['thumburl'], note))
    return rows

def commons_search(q):
    r = json.loads(get(COMMONS + urllib.parse.urlencode({'action': 'query', 'list': 'search', 'srsearch': q,
                                                         'srnamespace': 6, 'srlimit': 30, 'format': 'json'})))
    return [s['title'] for s in r['query']['search']]

def commons_geo(at, r):
    # files with coordinates within r m (Commons caps the radius at 10 km and the list at 500)
    g = json.loads(get(COMMONS + urllib.parse.urlencode({'action': 'query', 'list': 'geosearch', 'gscoord': f'{at[0]}|{at[1]}',
                       'gsradius': int(min(r, 10000)), 'gsnamespace': 6, 'gslimit': 500, 'format': 'json'})))
    return [x['title'] for x in g['query']['geosearch']]

def commons_cat(cat):
    titles, cont = [], {}
    while True:
        r = json.loads(get(COMMONS + urllib.parse.urlencode({'action': 'query', 'list': 'categorymembers', 'cmtype': 'file',
                           'cmtitle': 'Category:' + cat, 'cmlimit': 500, 'format': 'json', **cont})))
        titles += [x['title'] for x in r['query']['categorymembers']]
        if 'continue' not in r: return titles
        cont = r['continue']

def wikidata_cat(pid):
    """The Commons category (P373) of the place's Wikidata item (wd= in pois.py), or None."""
    try: q = poi(pid).get('wd')
    except SystemExit: return None
    if not q: return None
    e = json.loads(get('https://www.wikidata.org/wiki/Special:EntityData/' + q.split(',')[0] + '.json'))['entities']
    c = next(iter(e.values())).get('claims', {}).get('P373', [])
    return c[0]['mainsnak']['datavalue']['value'] if c else None

PANORAMAX = ['https://panoramax.mapcomplete.org', 'https://panoramax.openstreetmap.fr', 'https://panoramax.ign.fr']

def panoramax_rows(at, r):
    # keyless STAC search on each instance (the federated api.panoramax.xyz answered 500 in October 2026)
    rows = []
    for inst in PANORAMAX:
        b = ','.join(f'{v:.6f}' for v in bbox(at[0], at[1], r))
        try: d = json.loads(get(f'{inst}/api/search?bbox={b}&limit=100', tries=2))
        except (urllib.error.URLError, TimeoutError) as e: print(f'  {inst}: {e}'); continue
        for ft in d.get('features', []):
            p = ft.get('properties', {}); lo, la = ft['geometry']['coordinates'][:2]
            th = ft.get('assets', {}).get('thumb', {}).get('href')
            if not th: continue
            by = ', '.join(x.get('name', '') for x in p.get('providers') or [])
            note = f'a {math.dist(loc(lo, la), at[2:]):.0f} m' + (', de frente' if facing(la, lo, at, p.get('view:azimuth')) else '')
            rows.append(((p.get('datetime') or '?')[:10], 'Panoramax', ft['id'], f'azimut {p.get("view:azimuth")}°',
                         p.get('license', '?'), by[:60], f'{inst}/#focus=pic&pic={ft["id"]}', th, note))
    return rows

def mapillary_rows(at, r):
    tok = os.environ.get('MAPILLARY_TOKEN')
    if not tok:
        print('  --mapillary: falta MAPILLARY_TOKEN. Es gratis: entre a mapillary.com, Dashboard → Developers → Register\n'
              '  application (permiso «Read») y copie el «Client Token» (MLY|…); guárdelo en el llavero y expórtelo como\n'
              '  MAPILLARY_TOKEN. Fotos CC BY-SA 4.0: «© usuario, Mapillary, CC BY-SA 4.0».')
        return []
    b = ','.join(f'{v:.6f}' for v in bbox(at[0], at[1], r))
    url = 'https://graph.mapillary.com/images?' + urllib.parse.urlencode({'bbox': b, 'limit': 200,
          'fields': 'id,captured_at,compass_angle,computed_compass_angle,computed_geometry,geometry,is_pano,creator,thumb_1024_url'})
    d = json.loads(urllib.request.urlopen(urllib.request.Request(url, headers={**UA, 'Authorization': f'OAuth {tok}'}), timeout=60).read())
    rows = []
    for im in d.get('data', []):
        g = (im.get('computed_geometry') or im.get('geometry') or {}).get('coordinates')
        if not g or not im.get('thumb_1024_url'): continue
        az = im.get('computed_compass_angle', im.get('compass_angle'))
        note = f'a {math.dist(loc(*g[:2]), at[2:]):.0f} m' + (', panorámica' if im.get('is_pano') else ', de frente' if facing(g[1], g[0], at, az) else '')
        rows.append((time.strftime('%Y-%m-%d', time.gmtime(im['captured_at'] / 1000)), 'Mapillary', im['id'], f'azimut {az}°',
                     'CC BY-SA 4.0', (im.get('creator') or {}).get('username', ''), f'https://www.mapillary.com/app/?pKey={im["id"]}',
                     im['thumb_1024_url'], note))
    return rows

FLICKR_LIC = {'4': 'CC BY 2.0', '5': 'CC BY-SA 2.0', '7': 'sin derechos conocidos', '9': 'CC0', '10': 'dominio público'}

def flickr_rows(at, r):
    key = os.environ.get('FLICKR_KEY')
    if not key:
        print('  --flickr: falta FLICKR_KEY. Es gratis: con una cuenta de flickr.com, App Garden → Create an App →\n'
              '  Non-commercial; exporte la «Key» como FLICKR_KEY. Solo se listan fotos CC BY, CC BY-SA, CC0 o de dominio público.')
        return []
    b = ','.join(f'{v:.6f}' for v in bbox(at[0], at[1], r))
    d = json.loads(get('https://api.flickr.com/services/rest/?' + urllib.parse.urlencode({'method': 'flickr.photos.search',
        'api_key': key, 'bbox': b, 'license': ','.join(FLICKR_LIC), 'has_geo': 1, 'per_page': 100, 'format': 'json',
        'nojsoncallback': 1, 'extras': 'license,date_taken,geo,owner_name,url_m,description'})))
    rows = []
    for ph in d.get('photos', {}).get('photo', []):
        if not ph.get('url_m'): continue
        note = f'a {math.dist(loc(float(ph["longitude"]), float(ph["latitude"])), at[2:]):.0f} m'
        rows.append(((ph.get('datetaken') or '?')[:10], 'Flickr', ph.get('title', ''), ' '.join(str(ph.get('description', {}).get('_content', '')).split())[:160],
                     FLICKR_LIC.get(str(ph.get('license')), '?'), ph.get('ownername', ''), f'https://www.flickr.com/photos/{ph["owner"]}/{ph["id"]}',
                     ph['url_m'], note))
    return rows

def cmd_photos(pid, *args):
    args = list(args); opts = {}
    for o in ('--geo', '--cat', '--panoramax', '--mapillary', '--flickr'):
        if o in args:
            # the value: a radius in m, or for --cat a category; anything else is the query
            i = args.index(o); v = args[i+1] if i + 1 < len(args) and not args[i+1].startswith('--') else None
            if v and o != '--cat' and not re.fullmatch(r'\d+(\.\d+)?', v): v = None
            opts[o] = v; del args[i:i+(2 if v else 1)]
    query = args[0] if args else None
    at = where(pid)   # con consulta, pid puede ser cualquier nombre (una calle): solo nombra la carpeta
    if not at and set(opts) - {'--cat'}: raise SystemExit(f'{pid!r} no es un lugar ni un punto de grilla: --geo y las demás fuentes necesitan uno')
    rows, seen = [], set()
    def add(rs, what):
        n = 0
        for r in rs:
            if r[2] in seen: continue
            seen.add(r[2]); rows.append(r); n += 1
        print(f'{what}: {n}')
    if query or not opts:
        q = query or poi(pid)['n']
        add(commons_rows([t for t in commons_search(q) if t.lower().endswith(('.jpg', '.jpeg', '.png'))], at), f'Commons, «{q}»')
    if '--geo' in opts:
        r = float(opts['--geo'] or 100)
        add(commons_rows([t for t in commons_geo(at, r) if t.lower().endswith(('.jpg', '.jpeg', '.png'))], at), f'Commons a menos de {r:.0f} m')
    if '--cat' in opts:
        cat = opts['--cat'] or wikidata_cat(pid)
        if not cat: print('--cat: el lugar no tiene wd= en pois.py o su elemento no tiene categoría de Commons (P373); dé la categoría')
        else: add(commons_rows([t for t in commons_cat(cat) if t.lower().endswith(('.jpg', '.jpeg', '.png'))], at), f'Commons, categoría «{cat}»')
    for o, f, n in (('--panoramax', panoramax_rows, 'Panoramax'), ('--mapillary', mapillary_rows, 'Mapillary'), ('--flickr', flickr_rows, 'Flickr')):
        if o in opts: add(f(at, float(opts[o] or 100)), n)
    if not rows: raise SystemExit('Sin fotos; pruebe otra consulta, --geo con un radio mayor o --cat')
    out = ROOT / 'diagnostics' / 'fotos' / pid; out.mkdir(parents=True, exist_ok=True)
    rows.sort(key=lambda r: r[0] if r[0] != '?' else '0', reverse=True)   # sin fecha al final
    with open(out / 'indice.txt', 'w') as f:
        for i, (date, src, title, desc, lic, author, page, thumb, note) in enumerate(rows):
            name = f'{i:02d}.jpg'
            try: (out / name).write_bytes(get(thumb)); time.sleep(1)
            except (urllib.error.URLError, TimeoutError) as e: name = f'{i:02d} (sin miniatura: {e})'
            line = f'{name}  {date}  [{src}] {title}  [{lic}] {author}{"  (" + note + ")" if note else ""}\n    {desc}\n    {page}\n'
            f.write(line); print(line, end='')
    print(f'-> {out.relative_to(ROOT)}/ (más recientes primero)')

if __name__ == '__main__':
    cmds = {'osm': cmd_osm, 'frame': cmd_frame, 'photos': cmd_photos}
    if len(sys.argv) < 3 or sys.argv[1] not in cmds: raise SystemExit(__doc__)
    cmds[sys.argv[1]](*sys.argv[2:])
