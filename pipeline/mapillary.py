"""Mapillary: dónde hay fotos a nivel de calle en la comuna y cuáles miran a un lugar, para modelar con ellas.

  python mapillary.py clave                       # dice de dónde se lee la clave y la prueba con una consulta
  python mapillary.py cobertura [--refrescar]     # las fotos de la comuna, de las teselas vectoriales de Mapillary (z14)
                                                  # -> raw/mapillary/imagenes.json; resumen por año y por autor, y
                                                  # con Pillow el panel diagnostics/mapillary-cobertura.png
  python mapillary.py cobertura --caja -800 900 -700 800   # el panel de una caja de grilla (x0 x1 y0 y1), 1 m por píxel
  python mapillary.py lugares [80] [--todos]      # cada lugar de data/pois.json con fotos a menos de 80 m: cuántas,
                                                  # cuántas lo miran (±40°), de cuántas pasadas y la más nueva
  python landmark.py photos <lugar|x,y> --mapillary [r]   # las fotos que miran al lugar, una por pasada, con su índice
  python mapillary.py fachada w813330085 [w…] [--fotos 2]   # las fotos que ven de frente cada edificio de OSM, con su
                                                  # planta y una regla de alturas dibujadas encima, en hojas
  python mapillary.py fachada w941980866 --fotos 3 --entera --nombre w941980866   # la foto entera, con los vecinos
                                                  # como cajas de su alto en el mapa (naranja): para saber cuál es cuál
  python mapillary.py fachada --caja -318 318 -318 318 [--todos] [--saltar @ids.txt] [--nombre centro]
                                                  # los de una caja de grilla que no están en config/fachadas.json
  python mapillary.py punto -0.8 29.7 [2.6] [--fotos 8] [--radio 45]   # las que miran a un punto (una pila, una
                                                  # estatua): un círculo de r m en el suelo y una regla vertical

clave: Mapillary pide una clave de cliente para todo, también para las teselas. Es gratis: con una cuenta de
mapillary.com, https://www.mapillary.com/dashboard/developers → «Register application» (nombre y descripción
cualquiera, permiso «Read»); el «Client Token» empieza con MLY|. Se lee de la variable MAPILLARY_TOKEN o, si no
está, de ~/.config/mapillary.key (una línea; chmod 600). No va en el repo ni en la línea de comandos.

cobertura: baja las teselas de mly1_computed_public (las posiciones y rumbos corregidos por Mapillary; el rumbo de
la cámara suele errar en 100° o más) que cubren la comuna (168 a z14; el límite es de 50 mil teselas al día): quedan
en raw/mapillary/teselas/, y se vuelven a bajar a los 30 días o con --refrescar. De la capa «image» guarda cada foto
dentro del límite de la comuna: id, x, y en metros de grilla, fecha, rumbo (grados desde el norte verdadero),
panorámica, pasada (sequence) y autor (creator_id). landmark.py photos --mapillary elige de las mismas teselas y pide
a la API solo la miniatura y el autor de las elegidas: la búsqueda por caja de la API se salta fotos sin avisar.

lugares: lee raw/mapillary/imagenes.json (corra antes cobertura). «De frente» es una foto cuya cámara apunta al
punto del lugar ±40° (un lente de auto ve ±35°), o una panorámica. El punto del lugar es su dirección, no el centro
del hito (trampa «El punto del lugar no es el centro del hito»): en un recinto grande, use un radio mayor o
landmark.py photos con un punto de grilla. Y no sabe qué hay en medio: desde el otro lado de la plaza, la cámara mira
a la Catedral a través de los árboles.

fachada: para medir alto, pisos y color de los edificios de OSM (config/fachadas.json) en fotos. De las teselas elige,
para cada lado de 3 m o más de la planta (data/edificios.json), las fotos tomadas delante de él (a 4–45 m, a menos de
60° de su normal, una cámara de perspectiva mirando a su centro ±30°) cuya línea de vista a su centro no cruza otro
edificio de OSM; prefiere las de frente, a ~16 m, del lado más largo y de 2022 o después, una por pasada. Pide a la API
la cámara de esas (rotación computed_rotation, lente, tamaño, autor; caché en raw/mapillary/camaras.json), descarta
las de reconstrucción torcida (más de 15° de cabeceo o 10° de alabeo) y las que no muestran el 60 % del lado, baja la
miniatura (raw/mapillary/fotos/) y dibuja con la cámara: la planta al nivel de la calle (amarillo), una regla en cada
extremo del lado (una marca por metro, el número cada 5), líneas a través del lado cada 5 m (blanco), el alto que
dibuja el mapa (el de OSM más el pretil de 0,6 m, celeste) y el de config/fachadas.json (magenta). Recorta al lado y
las junta de a --por-hoja (6) en diagnostics/fachadas/<nombre>-NN.jpg, cada una con el alto y los pisos de OSM, la
fecha, el largo del lado, la distancia y un color sugerido (la mediana de los píxeles del muro entre el 45 y el 85 %
de brillo: sin ventanas ni cielo; a la sombra sale oscuro); las fuentes, en diagnostics/fachadas/<nombre>.txt. La
calle se toma plana y la cámara a 1,5 m (un auto por dentro, 2018; --alto) o a 2,2 m (una panorámica). Con --caja,
los edificios de la caja (por filas de manzanas, de norte a sur) que no están en config/fachadas.json (--todos: también
esos) ni en --saltar (ids separados por comas, o @archivo: los que dibuja un hito, `tools/probe.py "__ed.landmark"`).
La posición de Mapillary yerra en algunas pasadas de 2018 hasta ~10 m (una cámara que andaba por 1 Oriente queda
dentro de la plaza), y el rumbo unos grados: la planta puede caer corrida o sobre el vecino, y la regla, que mide bien
si la distancia está bien, puede exagerar o achicar un 30–40 %. El cabeceo sí calza (la calle se pierde donde la
dibuja). Mida el alto por los pisos y, de frente, por la proporción con el largo del lado (exacto, de OSM); la regla
solo lo comprueba. Y una foto de 2018 puede ser anterior al edificio.

punto: lo mismo para un punto de la grilla, con un círculo de r m en el suelo y una regla vertical en él: las fotos
que lo miran (±40°, o panorámicas) sin un edificio de OSM en medio, la más cercana de cada pasada.

Licencia: las fotos son CC BY-SA 4.0 («© <autor>, Mapillary, CC BY-SA 4.0»). Se bajan para mirarlas al modelar
(diagnostics/, fuera de git), como las de Commons; los términos de Mapillary piden su logo y un enlace si se publican.
"""
import gzip, json, math, os, struct, time, urllib.error, urllib.parse
from pathlib import Path
import cli, net
from common import ROOT, DATA, CONFIG, RAW, KX, KY, loc, unloc
from geom import area, dec, in_ring

GRAPH = 'https://graph.mapillary.com'
TILES = 'https://tiles.mapillary.com/maps/vtp/mly1_computed_public/2/{z}/{x}/{y}'
KEYFILE = Path.home() / '.config' / 'mapillary.key'
OUT = RAW / 'mapillary'
FRONT = 40                    # degrees: a camera pointing at the place within this is «de frente»
HELP = ('Falta la clave de Mapillary. Es gratis: con una cuenta de mapillary.com, entre a\n'
        'https://www.mapillary.com/dashboard/developers → «Register application» (permiso «Read») y copie el\n'
        '«Client Token» (MLY|…). Guárdelo en ~/.config/mapillary.key (chmod 600) o expórtelo como MAPILLARY_TOKEN.')

def token(required=True):
    """The client token: MAPILLARY_TOKEN, else the first line of ~/.config/mapillary.key; None (or exit with how to
    get one) when there is neither."""
    t = os.environ.get('MAPILLARY_TOKEN', '').strip()
    if not t and KEYFILE.exists(): t = KEYFILE.read_text().strip().split('\n')[0].strip()
    if not t and required: raise SystemExit(HELP)
    return t or None

def graph(path, params, tok):
    """GET graph.mapillary.com/<path>?<params> as JSON; the token goes in the header, never in the URL (which the
    retries print). Mapillary answers 500 to a search that takes too long: that is retried like a 429."""
    url = f'{GRAPH}/{path}?' + urllib.parse.urlencode(params)
    try: return json.loads(net.get(url, headers={'Authorization': f'OAuth {tok}'}, timeout=90))
    except urllib.error.HTTPError as e:
        body = e.read()[:300].decode('utf-8', 'replace')
        if e.code in (400, 401, 403): raise SystemExit(f'Mapillary respondió {e.code}: {body}\n(¿la clave está bien copiada, con el MLY| del comienzo?)')
        raise

# ---- Mapbox vector tiles (protobuf), standard library only --------------------------------------------------------

def _varint(b, i):
    v = s = 0
    while True:
        c = b[i]; i += 1; v |= (c & 0x7f) << s; s += 7
        if c < 0x80: return v, i

def _fields(b):
    """(field number, wire type, value) of a protobuf message: varints as int, length-delimited as bytes, fixed32 and
    fixed64 as their raw 4 or 8 bytes."""
    i = 0
    while i < len(b):
        key, i = _varint(b, i); f, w = key >> 3, key & 7
        if w == 0: v, i = _varint(b, i)
        elif w == 2: n, i = _varint(b, i); v = b[i:i+n]; i += n
        elif w == 1: v = b[i:i+8]; i += 8
        elif w == 5: v = b[i:i+4]; i += 4
        else: raise ValueError(f'tipo de campo protobuf {w} no soportado')
        yield f, w, v

def _packed(b):
    out, i = [], 0
    while i < len(b): v, i = _varint(b, i); out.append(v)
    return out

def _value(b):
    for f, w, v in _fields(b):
        if f == 1: return v.decode('utf-8')
        if f == 2: return struct.unpack('<f', v)[0]
        if f == 3: return struct.unpack('<d', v)[0]
        if f == 4: return v - (1 << 64) if v >= 1 << 63 else v           # int64
        if f == 5: return v                                               # uint64
        if f == 6: return (v >> 1) ^ -(v & 1)                             # sint64 (zigzag)
        if f == 7: return bool(v)
    return None

def _geometry(cmds):
    """The command stream of a feature -> its parts, each a list of (x, y) in tile units (MoveTo starts a part)."""
    parts, x, y, i = [], 0, 0, 0
    while i < len(cmds):
        c, n = cmds[i] & 7, cmds[i] >> 3; i += 1
        if c == 7: parts[-1].append(parts[-1][0]); continue              # ClosePath
        for _ in range(n):
            dx, dy = cmds[i], cmds[i+1]; i += 2
            x += (dx >> 1) ^ -(dx & 1); y += (dy >> 1) ^ -(dy & 1)
            if c == 1: parts.append([(x, y)])
            else: parts[-1].append((x, y))
    return parts

def mvt(b):
    """A vector tile -> {layer name: (extent, [(properties, geometry type, parts)])}; gzip is undone if present.
    Geometry types: 1 point, 2 line, 3 polygon; parts in tile units (0..extent, y downwards)."""
    if b[:2] == b'\x1f\x8b': b = gzip.decompress(b)
    out = {}
    for f, _, layer in _fields(b):
        if f != 3: continue
        name, extent, keys, vals, feats = '', 4096, [], [], []
        for g, _, v in _fields(layer):
            if g == 1: name = v.decode('utf-8')
            elif g == 2: feats.append(v)
            elif g == 3: keys.append(v.decode('utf-8'))
            elif g == 4: vals.append(_value(v))
            elif g == 5: extent = v
        rows = []
        for ft in feats:
            tags, typ, geo, fid = [], 0, [], None
            for g, w, v in _fields(ft):
                if g == 1: fid = v
                elif g == 2: tags = _packed(v) if w == 2 else [v]
                elif g == 3: typ = v
                elif g == 4: geo = _packed(v) if w == 2 else [v]
            props = {keys[tags[k]]: vals[tags[k+1]] for k in range(0, len(tags) - 1, 2)}
            if fid is not None: props.setdefault('id', fid)
            rows.append((props, typ, _geometry(geo)))
        out[name] = (extent, rows)
    return out

def tile_lonlat(z, tx, ty, px, py, extent):
    """A point in tile units of tile (z, tx, ty) -> (lon, lat)."""
    n = 2 ** z; X, Y = (tx + px / extent) / n, (ty + py / extent) / n
    return X * 360 - 180, math.degrees(math.atan(math.sinh(math.pi * (1 - 2 * Y))))

def tiles_of(z, x0, x1, y0, y1):
    """The tiles (tx, ty) of zoom z that cover the grid box x0..x1, y0..y1 (its corners, turned to lon/lat)."""
    ll = [unloc(x, y) for x in (x0, x1) for y in (y0, y1)]
    n = 2 ** z
    col = lambda lon: int((lon + 180) / 360 * n)
    row = lambda lat: int((1 - math.asinh(math.tan(math.radians(lat))) / math.pi) / 2 * n)
    return [(tx, ty) for tx in range(col(min(q[1] for q in ll)), col(max(q[1] for q in ll)) + 1)
            for ty in range(row(max(q[0] for q in ll)), row(min(q[0] for q in ll)) + 1)]

# ---- what is shared with landmark.py ------------------------------------------------------------------------------

def bearing(x, y, tx, ty):
    """Degrees from true north of the direction from grid point (x, y) to (tx, ty): the grid's +y points 5° east of
    true north (its streets are turned 5° clockwise)."""
    return (math.degrees(math.atan2(tx - x, ty - y)) + 5) % 360

def off(az, b):
    return min(abs(b - az) % 360, 360 - abs(b - az) % 360)

def limit():
    """The commune's limit (data/geometry.json): one ring in grid metres."""
    return dec(json.load(open(DATA / 'geometry.json'))['limit'])

def facing(im, x, y, r):
    """(distance, degrees off) of an image of imagenes.json or of near() towards (x, y); None beyond r or looking away.
    A panorama sees every way: 0°."""
    d = math.dist((im[1], im[2]), (x, y))
    if d > r: return None
    o = 0 if im[5] or im[4] is None else off(im[4], bearing(im[1], im[2], x, y))
    return (d, o) if o <= FRONT else None

def tile_images(z, tx, ty, tok, refresh=False):
    """The images of one coverage tile, each [id, x, y, captured_at, heading, panorama, sequence, creator_id] in grid
    metres (the heading is Mapillary's computed one: the camera's own is often off by 100° or more). The tile is kept
    in raw/mapillary/teselas/<z>/ and downloaded again with `refresh` or when it is over 30 days old."""
    f = OUT / 'teselas' / str(z) / f'{tx}-{ty}.pbf'
    tiles = None
    if not refresh and f.exists() and time.time() - f.stat().st_mtime <= 30 * 86400:
        try: tiles = mvt(f.read_bytes()) if f.stat().st_size else {}
        except Exception: tiles = None                    # truncated or not a tile: download it again
    if tiles is None:
        f.parent.mkdir(parents=True, exist_ok=True)
        url = TILES.format(z=z, x=tx, y=ty) + '?' + urllib.parse.urlencode({'access_token': tok})
        # never print or re-raise with the URL (e.url, e.filename): it carries the token
        try: b = net.get(url, timeout=60, quiet=True)   # quiet: the retries would print the token
        except urllib.error.HTTPError as e:
            if e.code in (401, 403): raise SystemExit(f'Mapillary respondió {e.code} a una tesela: ¿la clave está bien?')
            if e.code != 404: raise SystemExit(f'Mapillary respondió {e.code} a la tesela {z}/{tx}/{ty}')
            b = b''                                      # a tile without coverage
        try: tiles = mvt(b) if b else {}
        except Exception: raise SystemExit(f'la tesela {z}/{tx}/{ty} de Mapillary no se pudo leer ({len(b)} bytes)')
        # read before it is kept, and written whole: a cut download or an error page never stays cached for 30 days
        tmp = f.with_suffix('.tmp'); tmp.write_bytes(b); os.replace(tmp, f)
    layer = tiles.get('image')
    if not layer: return []
    ext, feats = layer; out = []
    for p, typ, parts in feats:
        if typ != 1: continue
        for part in parts:
            for px, py in part:
                x, y = loc(*tile_lonlat(z, tx, ty, px, py, ext)); ca = p.get('compass_angle')
                out.append([str(p['id']), round(x, 1), round(y, 1), int(p.get('captured_at') or 0),
                            None if ca is None else round(ca, 1), int(bool(p.get('is_pano'))),
                            str(p.get('sequence_id', '')), str(p.get('creator_id', ''))])
    return out

def near(lat, lon, x, y, r, n=30):
    """The Mapillary images that look at grid point (x, y) from less than r m: the closest of each sequence (a car
    takes one every 2–3 m), newest first, at most n, each with its 2048-px thumbnail. Rows (date, id, description,
    author, page, thumb, note) for landmark.py. The images come from the coverage tiles, which hold all of them: the
    API's bbox search drops some silently (1817 of 2225 within 250 m of the plaza, November 2026)."""
    tok = token(required=False)
    if not tok: print('  --mapillary: ' + HELP.replace('\n', '\n  ')); return []
    best = {}
    for tx, ty in tiles_of(14, x - r, x + r, y - r, y + r):
        for im in tile_images(14, tx, ty, tok):
            f = facing(im, x, y, r)
            if f is None: continue
            k = im[6] or im[0]
            if k not in best or f < best[k][0]: best[k] = (f, im)
    pick = sorted(best.values(), key=lambda v: -v[1][3])[:n]
    info = {}
    for k in range(0, len(pick), 50):                    # the thumbnails and authors, only of the chosen ones
        for im in graph('images', {'image_ids': ','.join(v[1][0] for v in pick[k:k+50]),
                                   'fields': 'id,thumb_2048_url,creator,camera_type'}, tok).get('data', []):
            info[im['id']] = im
    rows = []
    for (dist, o), (iid, ix, iy, t, az, pano, seq, user) in pick:
        im = info.get(iid, {})
        if not im.get('thumb_2048_url'): continue
        pano = pano or im.get('camera_type') in ('spherical', 'equirectangular')
        note = f'a {dist:.0f} m, ' + ('panorámica' if pano else f'de frente ({o:.0f}° del eje)')
        rows.append((time.strftime('%Y-%m-%d', time.gmtime(t / 1000)), iid, f'rumbo {az:.0f}°' if az is not None else 'sin rumbo',
                     (im.get('creator') or {}).get('username', ''), f'https://www.mapillary.com/app/?pKey={iid}', im['thumb_2048_url'], note))
    return rows

# ---- commands -------------------------------------------------------------------------------------------------------

def cmd_clave():
    tok = token()
    src = 'MAPILLARY_TOKEN' if os.environ.get('MAPILLARY_TOKEN', '').strip() else str(KEYFILE)
    lat, lon = unloc(0, 0)
    d = graph('images', {'bbox': f'{lon-0.001:.6f},{lat-0.001:.6f},{lon+0.001:.6f},{lat+0.001:.6f}', 'limit': 2000, 'fields': 'id'}, tok)
    print(f'clave: {src} ({tok[:4]}…, {len(tok)} caracteres); responde: {len(d.get("data", []))} fotos a menos de ~100 m de la plaza')

YEARS = [(2014, (150, 150, 150)), (2018, (91, 141, 214)), (2021, (60, 170, 110)), (2023, (232, 160, 40)), (2025, (220, 50, 60))]

def cmd_cobertura(*, refrescar=False, caja: (float, float, float, float) = None, z: int = 14):
    tok = token()
    ring = limit()
    xs, ys = [q[0] for q in ring], [q[1] for q in ring]
    tiles = tiles_of(z, min(xs), max(xs), min(ys), max(ys))
    imgs = {}
    for k, (tx, ty) in enumerate(tiles):
        for im in tile_images(z, tx, ty, tok, refresh=refrescar):
            if in_ring((im[1], im[2]), ring): imgs[im[0]] = im
        if k % 40 == 39: print(f'  {k+1}/{len(tiles)} teselas', flush=True)
    rows = sorted(imgs.values(), key=lambda r: r[3])
    out = OUT / 'imagenes.json'
    out.write_text(json.dumps({'z': z, 'bajadas': time.strftime('%Y-%m-%d'), 'campos': ['id', 'x', 'y', 'captured_at', 'rumbo', 'pano', 'pasada', 'autor'],
                               'imagenes': rows}, separators=(',', ':')))
    print(f'{len(tiles)} teselas z{z} -> {out.relative_to(ROOT) if out.is_relative_to(ROOT) else out}')
    if not rows: print('Sin fotos de Mapillary en la comuna.'); return
    seqs = {r[6] for r in rows}; users = {}
    for r in rows: users[r[7]] = users.get(r[7], 0) + 1
    print(f'{len(rows)} fotos dentro de la comuna, {sum(r[5] for r in rows)} panorámicas, {len(seqs)} pasadas, {len(users)} autores')
    yr = {}
    for r in rows: y = time.gmtime(r[3] / 1000).tm_year; yr[y] = yr.get(y, 0) + 1
    print('por año: ' + ', '.join(f'{y}: {n}' for y, n in sorted(yr.items())))
    print('autores con más fotos (creator_id): ' + ', '.join(f'{u} ({n})' for u, n in sorted(users.items(), key=lambda v: -v[1])[:8]))
    panel(rows, ring, caja)

def panel(rows, ring, caja=None):
    """diagnostics/mapillary-cobertura.png: the streets of the map and each photo, coloured by year."""
    try: from PIL import Image, ImageDraw
    except ImportError: print('(sin Pillow no hay panel: uv run --with pillow python pipeline/mapillary.py cobertura)'); return
    g = json.load(open(DATA / 'geometry.json'))
    if caja: x0, x1, y0, y1 = caja; s = 1.0
    else: x0, x1, y0, y1 = (min(q[0] for q in ring), max(q[0] for q in ring), min(q[1] for q in ring), max(q[1] for q in ring)); s = 0.1
    W, H = int((x1 - x0) * s), int((y1 - y0) * s)
    img = Image.new('RGB', (W, H + 40), (250, 248, 242)); d = ImageDraw.Draw(img)
    P = lambda q: ((q[0] - x0) * s, (y1 - q[1]) * s)
    d.line([P(q) for q in ring + ring[:1]], fill=(120, 120, 120), width=2)
    for c, _, pl in g['streets']:
        d.line([P(q) for q in dec(pl)], fill=(205, 200, 190) if c > 4 else (170, 165, 155), width=1 if s < 0.5 or c > 4 else 3)
    col = lambda t: next((c for y, c in reversed(YEARS) if time.gmtime(t / 1000).tm_year >= y), YEARS[0][1])
    rr = 1 if s < 0.5 else 2
    for r in rows:
        if x0 <= r[1] <= x1 and y0 <= r[2] <= y1:
            px, py = P(r[1:3]); d.ellipse([px - rr, py - rr, px + rr, py + rr], fill=col(r[3]))
    x = 8
    for i, (y, c) in enumerate(YEARS):
        lab = f'{y}-{YEARS[i+1][0]-1}' if i + 1 < len(YEARS) else f'desde {y}'   # ASCII: Pillow's default font
        if i == 0: lab = f'antes de {YEARS[1][0]}'
        d.rectangle([x, H + 14, x + 12, H + 26], fill=c); d.text((x + 16, H + 14), lab, fill=(0, 0, 0)); x += 24 + 7 * len(lab)
    fn = ROOT / 'diagnostics' / ('mapillary-cobertura.png' if not caja else f'mapillary-{x0:.0f}_{y0:.0f}.png')
    fn.parent.mkdir(exist_ok=True); img.save(fn); print(fn.relative_to(ROOT), img.size)

def cmd_lugares(r: float = 80, *, todos=False):
    f = OUT / 'imagenes.json'
    if not f.exists(): raise SystemExit(f'Falta {f}: corra antes python pipeline/mapillary.py cobertura')
    D = json.load(open(f)); rows = D['imagenes']
    hitos = {ln.split('#')[0].strip() for ln in open(ROOT / 'src' / 'js' / 'hitos' / 'ORDER')} - {''}
    cell = {}                                            # a 100-m index, not to test every photo for every place
    for im in rows: cell.setdefault((int(im[1] // 100), int(im[2] // 100)), []).append(im)
    out = []
    for p in json.load(open(DATA / 'pois.json'))['pois']:
        x, y = p['x'], p['y']; k = int(r // 100) + 1
        cand = [im for i in range(int(x // 100) - k, int(x // 100) + k + 1) for j in range(int(y // 100) - k, int(y // 100) + k + 1)
                for im in cell.get((i, j), ())]
        near_ = [im for im in cand if math.dist(im[1:3], (x, y)) <= r]
        front = [im for im in near_ if facing(im, x, y, r)]
        if not near_ and not todos: continue
        last = max((im[3] for im in front or near_), default=0)
        out.append((len({im[6] for im in front}), len(front), len(near_), last, p['id'], p['id'] in hitos))
    out.sort(key=lambda v: (-v[0], -v[1], -v[2]))
    print(f'fotos de Mapillary a menos de {r:.0f} m (de raw/mapillary/imagenes.json, bajado el {D["bajadas"]}); '
          f'«de frente»: la cámara mira al punto ±{FRONT}° o es panorámica')
    print(f'{"pasadas":>8} {"de frente":>9} {"cerca":>6}  {"la más nueva":12}  lugar')
    for seq, fr, nr, t, pid, h in out:
        print(f'{seq:8d} {fr:9d} {nr:6d}  {time.strftime("%Y-%m-%d", time.gmtime(t / 1000)) if t else "—":12}  {pid}{"  (hito)" if h else ""}')
    print(f'{len(out)} lugares' + ('' if todos else ' con fotos cerca (--todos: también los que no tienen)'))

# ---- fachada: the photos that see a building, with its plan and a height ruler drawn on them -----------------------

CAMS = OUT / 'camaras.json'          # the camera of each image asked for (rotation, lens, size, author, date), by id
FOTOS = OUT / 'fotos'                # their 2048-px thumbnails, <id>.jpg
HCAM = 1.5                           # metres from the street to the camera: a dashcam (2018) or a hand
HPANO = 2.2                          # a panorama's camera, over a car's roof or a helmet (2025)
CAMF = 'id,camera_type,camera_parameters,computed_rotation,computed_geometry,width,height,creator,captured_at,sequence'

def rotation(v):
    """Mapillary's computed_rotation (OpenSfM's angle-axis) -> the 3x3 matrix from the world (east, north, up, in
    metres) to the camera (x right, y down, z forward). Its third row is where the camera looks: atan2 of its east and
    north parts is computed_compass_angle (checked to 0.1° on the plaza's images, November 2026)."""
    t = math.sqrt(sum(c * c for c in v)) or 1e-12
    x, y, z = (c / t for c in v); c, s, C = math.cos(t), math.sin(t), 1 - math.cos(t)
    return [[c + x*x*C, x*y*C - z*s, x*z*C + y*s], [y*x*C + z*s, c + y*y*C, y*z*C - x*s], [z*x*C - y*s, z*y*C + x*s, c + z*z*C]]

class Camera:
    """One image's camera, to draw points of the grid on it: (x, y) in grid metres, z in metres over the street, which
    is taken as flat and `h` under the camera. Perspective cameras with OpenSfM's lens (focal over the image's longer
    side, k1, k2), or panoramas (equirectangular)."""
    def __init__(self, c, size, h=HCAM):
        self.R = rotation(c['computed_rotation']); self.lon, self.lat = c['computed_geometry']['coordinates']
        self.pano = c.get('camera_type') in ('spherical', 'equirectangular')
        p = list(c.get('camera_parameters') or []) + [0, 0, 0]
        self.f, self.k1, self.k2 = p[0] or .6, p[1], p[2]
        self.W, self.H = size; self.h = h; self.x, self.y = loc(self.lon, self.lat)
        self.pitch = math.degrees(math.asin(max(-1, min(1, self.R[2][2]))))   # up from the horizon
        self.roll = math.degrees(math.asin(max(-1, min(1, self.R[0][2]))))    # the image's x axis out of the horizon

    def cam(self, x, y, z):
        la, lo = unloc(x, y); w = ((lo - self.lon) * KX, (la - self.lat) * KY, z - self.h)
        return [sum(r[j] * w[j] for j in range(3)) for r in self.R]

    def px(self, p):
        """Camera coordinates -> the pixel, or None (behind the camera, or past the edge of the lens)."""
        X, Y, Z = p
        if self.pano: return (self.W * (.5 + math.atan2(X, Z) / (2 * math.pi)), self.H * (.5 - math.atan2(-Y, math.hypot(X, Z)) / math.pi))
        if Z < .3: return None
        u, v = X / Z, Y / Z; r2 = u * u + v * v
        if r2 > 1.4: return None                                              # past it, k1 and k2 fold the image back
        s = self.f * (1 + self.k1 * r2 + self.k2 * r2 * r2) * max(self.W, self.H)
        return (self.W / 2 + u * s, self.H / 2 + v * s)

    def at(self, x, y, z): return self.px(self.cam(x, y, z))

    def line(self, a, b, n=24):
        """The segment a-b (each (x, y, z)) as polylines of pixels: its part in front of the camera, bent by the lens
        (a panorama's, cut where it wraps round)."""
        A, B = self.cam(*a), self.cam(*b)
        if not self.pano:
            if A[2] < .3 and B[2] < .3: return []
            if A[2] < .3 or B[2] < .3:
                t = (.3 - A[2]) / (B[2] - A[2]); M = [A[i] + (B[i] - A[i]) * t for i in range(3)]
                A, B = (M, B) if A[2] < .3 else (A, M)
        out, cur, last = [], [], None
        for k in range(n + 1):
            q = self.px([A[i] + (B[i] - A[i]) * k / n for i in range(3)])
            if q is None or last is not None and abs(q[0] - last[0]) > self.W / 3:
                if len(cur) > 1: out.append(cur)
                cur = [] if q is None else [q]
            else: cur.append(q)
            last = q
        if len(cur) > 1: out.append(cur)
        return out

def buildings():
    """The OSM buildings of data/edificios.json: {id: (outline in grid metres, counter-clockwise; the walls' height
    in m as the map draws it, floors, kind)}."""
    d = json.load(open(DATA / 'edificios.json')); out = {}
    for b in d['e']:
        R = [(p[0] / 10, p[1] / 10) for p in dec(b[1][0])]
        if area(R) < 0: R = R[::-1]
        out[b[0]] = (R, b[2] / 10, b[4], d['tipos'][b[3]])
    return out

def _cross(p, q, a, b):
    d = lambda o, s, t: (s[0] - o[0]) * (t[1] - o[1]) - (s[1] - o[1]) * (t[0] - o[0])
    return d(p, q, a) * d(p, q, b) < 0 and d(a, b, p) * d(a, b, q) < 0

def _lerp(a, b, t): return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)

def sightings(R, imgs, walls, r=45):
    """The images that see a side of outline R (counter-clockwise) of 3 m or more from in front of it: (score: lower
    is better, side, image row, distance, degrees off the side's normal). The camera is 3 m or more in front of the
    side and within 60° of its normal; a perspective one looks at the side's middle (±30°); the lines of sight to its
    middle and to its quarters do not cross the edges in `walls` (the other buildings' and this one's other sides), and
    each one that does costs. Trees, poles and buses are not known: look at two photos."""
    out = []
    for i in range(len(R)):
        a, b = R[i], R[(i + 1) % len(R)]; L = math.dist(a, b)
        if L < 3: continue
        n = ((b[1] - a[1]) / L, -(b[0] - a[0]) / L); m = _lerp(a, b, .5)
        near_ = [w for w in walls if w[2] != (a, b) and min(math.dist(w[0], m), math.dist(w[1], m)) < r + 30]
        for im in imgs:
            c = (im[1], im[2]); d = math.dist(c, m)
            if not 4 <= d <= r: continue
            front = (c[0] - m[0]) * n[0] + (c[1] - m[1]) * n[1]
            if front < 3: continue
            ob = math.degrees(math.acos(min(1, front / d)))
            if ob > 60 or not im[5] and (im[4] is None or off(im[4], bearing(c[0], c[1], *m)) > 30): continue
            hid = [any(_cross(c, t, w[0], w[1]) for w in near_) for t in (m, _lerp(a, b, .25), _lerp(a, b, .75))]
            if hid[0] or all(hid[1:]): continue
            year = time.gmtime(im[3] / 1000).tm_year
            score = ob / 45 + abs(d - 16) / 20 + .5 * sum(hid) + (.8 if im[5] else 0) - min(L, 30) / 30 - (.3 if year >= 2022 else 0)
            out.append((score, i, im, d, ob))
    return sorted(out, key=lambda v: v[0])

def cameras(ids, tok):
    """The cameras of these images, from raw/mapillary/camaras.json or the API (50 at a time), by id."""
    have = json.load(open(CAMS)) if CAMS.exists() else {}
    need = [i for i in dict.fromkeys(ids) if i not in have]
    for k in range(0, len(need), 50):
        for c in graph('images', {'image_ids': ','.join(need[k:k + 50]), 'fields': CAMF}, tok).get('data', []):
            have[c['id']] = c
        for i in need[k:k + 50]: have.setdefault(i, None)          # not served: do not ask again
        tmp = CAMS.with_suffix(f'.{os.getpid()}.tmp'); tmp.write_text(json.dumps(have, separators=(',', ':'))); os.replace(tmp, CAMS)   # whole: another run may be reading it
    return {i: have.get(i) for i in ids}

def photo(iid, tok):
    """The 2048-px thumbnail of an image, kept in raw/mapillary/fotos/ (its URL is signed and expires: asked each time)."""
    f = FOTOS / f'{iid}.jpg'
    if not f.exists() or not f.stat().st_size:
        u = graph(iid, {'fields': 'thumb_2048_url'}, tok).get('thumb_2048_url')
        if not u: return None
        f.parent.mkdir(parents=True, exist_ok=True)
        tmp = f.with_suffix('.tmp'); tmp.write_bytes(net.get(u, timeout=90, quiet=True)); os.replace(tmp, f)
    return f

def wall_colour(img, cam, a, b, h):
    """A guess of the wall's colour: in the side's face from 1.2 m to its top (at most 12 m), the median of the pixels
    between the 45th and the 85th percentile of brightness (windows and shadows are darker, the sky brighter)."""
    from PIL import Image, ImageDraw
    top = max(2.5, min(h, 12) - .4); q = [cam.at(*a, 1.2), cam.at(*b, 1.2), cam.at(*b, top), cam.at(*a, top)]
    if any(p is None for p in q): return None
    mask = Image.new('L', img.size, 0); ImageDraw.Draw(mask).polygon(q, fill=255)
    px = [p for p, m in zip(img.getdata(), mask.getdata()) if m]
    if len(px) < 200: return None
    px.sort(key=lambda p: p[0] * .3 + p[1] * .59 + p[2] * .11); px = px[int(len(px) * .45):int(len(px) * .85)]
    return '%02x%02x%02x' % tuple(sorted(p[c] for p in px)[len(px) // 2] for c in range(3))

def overlay(img, cam, R, i, h, alto=None):
    """Draws on img the outline R at street level (yellow), rulers at both ends of side i (a tick every metre, longer
    every 5 with its number), lines across the side every 5 m (white), at the top of the walls as the map draws them
    (h plus the 0.6 m parapet, cyan) and at the height measured in config/fachadas.json (magenta). Returns the box of
    the side's face up to the rulers' top."""
    from PIL import ImageDraw, ImageFont
    a, b = R[i], R[(i + 1) % len(R)]; L = math.dist(a, b); u = ((b[0] - a[0]) / L, (b[1] - a[1]) / L)
    top = max(15, (alto or h) + 8)
    q0, q1 = cam.at(*a, 0), cam.at(*a, top); hpx = math.dist(q0, q1) if q0 and q1 else img.height / 2
    d = ImageDraw.Draw(img, 'RGBA'); w = max(1, min(img.width // 900, int(hpx / 150)) or 1)
    try: font = ImageFont.load_default(size=int(max(11, min(img.width / 70, hpx / 16))))   # the numbers as large as a metre or two
    except TypeError: font = ImageFont.load_default()
    Y, C, M, Wt = (255, 214, 0, 235), (0, 230, 255, 235), (255, 60, 220, 235), (255, 255, 255, 150)
    for k in range(len(R)):
        for pl in cam.line((*R[k], 0), (*R[(k + 1) % len(R)], 0)): d.line(pl, fill=Y, width=w)
    for z in range(5, int(top) + 1, 5):
        for pl in cam.line((*a, z), (*b, z)): d.line(pl, fill=Wt, width=1)
    for z, col in ((h + .6, C), (alto, M)):
        if z:
            for pl in cam.line((*a, z), (*b, z)): d.line(pl, fill=col, width=w)
    for p, s in ((a, 1), (b, -1)):
        for pl in cam.line((*p, 0), (*p, top)): d.line(pl, fill=Y, width=w)
        for z in range(1, int(top) + 1):
            t = 1.6 if z % 5 == 0 else .6; q = (p[0] + u[0] * t * s, p[1] + u[1] * t * s)
            for pl in cam.line((*p, z), (*q, z), 4): d.line(pl, fill=Y, width=w)
            if z % 5 == 0 and (o := cam.at(*q, z)): d.text((o[0] + 3 * s, o[1]), str(z), fill=Y, font=font, anchor='lm' if s > 0 else 'rm', stroke_width=max(1, w), stroke_fill=(0, 0, 0))
    pts = [q for z in (0, top) for p in (a, b) for q in [cam.at(*p, z)] if q]
    for pl in cam.line((*a, 0), (*b, 0)) + cam.line((*a, top), (*b, top)): pts += pl
    if not pts: return None
    xs, ys = [p[0] for p in pts], [p[1] for p in pts]
    return (min(xs), min(ys), max(xs), max(ys))

def cmd_fachada(*ids, caja: (float, float, float, float) = None, fotos: int = 2, todos=False, saltar: str = '',
                alto: float = HCAM, por_hoja: int = 6, nombre: str = 'hoja', entera=False):
    """The photos that see each building, with its plan, a ruler and the heights drawn on them, cut to its side, in
    sheets of por_hoja: diagnostics/fachadas/<nombre>-NN.jpg, and their sources in diagnostics/fachadas/<nombre>.txt."""
    from PIL import Image, ImageDraw, ImageFont
    tok = token(); B = buildings(); FA = json.load(open(CONFIG / 'fachadas.json'))
    skip = set(); s = saltar
    if s.startswith('@'): s = Path(s[1:]).read_text()
    skip = {t.strip() for t in s.replace('\n', ',').split(',') if t.strip()}
    if caja:
        x0, x1, y0, y1 = caja
        cen = {k: (sum(p[0] for p in v[0]) / len(v[0]), sum(p[1] for p in v[0]) / len(v[0])) for k, v in B.items() if k[0] in 'wr'}
        ids = [k for k, c in cen.items() if x0 <= c[0] <= x1 and y0 <= c[1] <= y1 and k not in skip and (todos or k not in FA)]
        ids.sort(key=lambda k: (-round(cen[k][1] / 125), cen[k][0], -cen[k][1]))   # by rows of blocks, north first
    bad = [k for k in ids if k not in B]
    if bad: raise SystemExit(f'No están en data/edificios.json: {", ".join(bad)}')
    if not ids: raise SystemExit('Ningún edificio que mirar (¿ya medidos? --todos los incluye)')
    xs = [p[0] for k in ids for p in B[k][0]]; ys = [p[1] for k in ids for p in B[k][0]]
    imgs = {}
    for tx, ty in tiles_of(14, min(xs) - 60, max(xs) + 60, min(ys) - 60, max(ys) + 60):
        for im in tile_images(14, tx, ty, tok): imgs[im[0]] = im
    imgs = list(imgs.values())
    grid = {}
    for im in imgs: grid.setdefault((int(im[1] // 50), int(im[2] // 50)), []).append(im)
    egrid = {}
    for k, (R, *_) in B.items():
        for j in range(len(R)):
            e = (R[j], R[(j + 1) % len(R)], (R[j], R[(j + 1) % len(R)]))
            egrid.setdefault((int(e[0][0] // 50), int(e[0][1] // 50)), []).append(e)
    near_ = lambda g, x, y, r: [v for i in range(int((x - r) // 50), int((x + r) // 50) + 1) for j in range(int((y - r) // 50), int((y + r) // 50) + 1) for v in g.get((i, j), ())]
    plan = {}
    for k in ids:
        R = B[k][0]; cx, cy = sum(p[0] for p in R) / len(R), sum(p[1] for p in R) / len(R); rad = max(math.dist((cx, cy), p) for p in R)
        plan[k] = sightings(R, near_(grid, cx, cy, rad + 50), near_(egrid, cx, cy, rad + 120))[:8]
    C = cameras([v[2][0] for k in ids for v in plan[k]], tok)
    tiles, rows = [], []
    for n, k in enumerate(ids):
        R, h, lv, t = B[k]; fa = FA.get(k, {}); got, seqs = [], set()
        for score, i, im, dist, ob in plan[k]:
            c = C.get(im[0])
            if not c or not c.get('computed_rotation') or im[6] in seqs: continue
            pano = c.get('camera_type') in ('spherical', 'equirectangular')
            cam = Camera(c, (2048, 1024) if pano else (c['width'], c['height']), HPANO if pano and alto == HCAM else alto)
            if not pano and (abs(cam.pitch) > 15 or abs(cam.roll) > 10): continue      # a reconstruction gone wrong
            a, b = R[i], R[(i + 1) % len(R)]
            seen = [cam.at(*_lerp(a, b, j / 10), z) for j in range(11) for z in (0, min(h + .6, 20))]
            if sum(1 for q in seen if q and 0 <= q[0] < cam.W and 0 <= q[1] < cam.H) < 13: continue   # 60 % of the side
            f = photo(im[0], tok)
            if not f: continue
            img = Image.open(f).convert('RGB'); cam.W, cam.H = img.size
            col = wall_colour(img, cam, a, b, fa.get('alto') or h)
            if entera:                                   # the neighbours as boxes of their height (orange), to tell which is which
                dn = ImageDraw.Draw(img); cx, cy = _lerp(a, b, .5)
                for k2, (R2, h2, *_) in B.items():
                    if k2 != k and min(math.dist(p, (cx, cy)) for p in R2) < 40:
                        for j in range(len(R2)):
                            p, q = R2[j], R2[(j + 1) % len(R2)]
                            for pl in cam.line((*p, 0), (*q, 0)) + cam.line((*p, h2 + .6), (*q, h2 + .6)) + cam.line((*p, 0), (*p, h2 + .6), 6):
                                dn.line(pl, fill=(255, 130, 0), width=2)
            box = overlay(img, cam, R, i, h, fa.get('alto'))
            if not box: continue
            bx0, by0, bx1, by1 = box; m = .12 * max(bx1 - bx0, by1 - by0)
            crop = img if entera else img.crop((int(max(0, bx0 - m)), int(max(0, by0 - m)), int(min(img.width, bx1 + m)), int(min(img.height, by1 + m))))
            when = time.strftime('%Y-%m-%d', time.gmtime(c['captured_at'] / 1000))
            who = (c.get('creator') or {}).get('username', '')
            got.append((crop, col, when, dist, ob, i)); seqs.add(im[6])
            rows.append(f'{k}\t{im[0]}\t{when}\t{who}\thttps://www.mapillary.com/app/?pKey={im[0]}\tlado {i}, a {dist:.0f} m, {ob:.0f}° de su normal, color {col}')
            if len(got) >= fotos: break
        if not got: print(f'{k}: ninguna foto lo ve de frente'); continue
        for j, (crop, col, when, dist, ob, i) in enumerate(got):
            head = f'{k}  OSM {h:.1f} m {lv} p {t}' + (f'  medido {fa.get("alto")} m {fa.get("pisos", "")} p' if fa else '')
            tiles.append((crop, head, f'{when}  lado {i} de {math.dist(R[i], R[(i + 1) % len(R)]):.0f} m  a {dist:.0f} m  {ob:.0f} grados  color {col}', col))
        print(f'{k}: {len(got)} foto(s); color {", ".join(str(g[1]) for g in got)}', flush=True)
    sheets(tiles, rows, nombre, por_hoja)

def sheets(tiles, rows, nombre, por_hoja=6, head='edificio'):
    """Tiles (crop, title, subtitle, colour) in sheets of por_hoja, two columns: diagnostics/fachadas/<nombre>-NN.jpg;
    the photos' sources (rows) in diagnostics/fachadas/<nombre>.txt."""
    from PIL import Image, ImageDraw, ImageFont
    if not tiles: return
    out = ROOT / 'diagnostics' / 'fachadas'; out.mkdir(parents=True, exist_ok=True)
    TW, TH = 760, 560
    try: font = ImageFont.load_default(size=17)
    except TypeError: font = ImageFont.load_default()
    for s in range(0, len(tiles), por_hoja):
        part = tiles[s:s + por_hoja]; cols = 2; nrow = (len(part) + 1) // 2
        sheet = Image.new('RGB', (TW * cols, (TH + 48) * nrow), (30, 30, 30)); d = ImageDraw.Draw(sheet)
        for j, (crop, title, sub, col) in enumerate(part):
            x, y = (j % cols) * TW, (j // cols) * (TH + 48)
            sc = min(TW / crop.width, TH / crop.height); im = crop.resize((max(1, int(crop.width * sc)), max(1, int(crop.height * sc))))
            sheet.paste(im, (x + (TW - im.width) // 2, y + 48))
            d.text((x + 6, y + 4), f'{s + j + 1}. {title}', fill=(255, 255, 255), font=font)
            d.text((x + 6, y + 25), sub, fill=(200, 200, 200), font=font)
            if col: d.rectangle((x + TW - 44, y + 6, x + TW - 8, y + 40), fill='#' + col, outline=(255, 255, 255))
        fn = out / f'{nombre}-{s // por_hoja + 1:02d}.jpg'; sheet.save(fn, quality=88); print(fn.relative_to(ROOT), sheet.size)
    (out / f'{nombre}.txt').write_text(f'{head}\tfoto\tfecha\tautor\tenlace\tnota\n' + ''.join(r + '\n' for r in rows))
    print(f'{len(tiles)} fotos; fuentes en diagnostics/fachadas/{nombre}.txt (© <autor>, Mapillary, CC BY-SA 4.0)')

def cmd_punto(x: float, y: float, r: float = 3, *, fotos: int = 8, radio: float = 45, alto: float = HCAM, nombre: str = 'punto'):
    """The photos that look at a point of the grid (a fountain, a statue, a kiosk): a circle of r m round it on the
    ground and a ruler up from it, cut round them, one per sequence, the closest first."""
    from PIL import Image, ImageDraw, ImageFont
    tok = token(); B = buildings()
    walls = [(R[j], R[(j + 1) % len(R)]) for R, *_ in B.values() if min(math.dist(p, (x, y)) for p in R) < radio + 20 for j in range(len(R))]
    cand = []
    for tx, ty in tiles_of(14, x - radio, x + radio, y - radio, y + radio):
        for im in tile_images(14, tx, ty, tok):
            f = facing(im, x, y, radio)
            if f and f[0] >= 2.5 and not any(_cross((im[1], im[2]), (x, y), a, b) for a, b in walls): cand.append((f[0], im))
    best = {}
    for d, im in sorted(cand, key=lambda v: v[0]):
        best.setdefault(im[6], (d, im))
    pick = sorted(best.values(), key=lambda v: v[0])[:fotos * 3]
    C = cameras([im[0] for _, im in pick], tok)
    tiles, rows = [], []
    for d, im in pick:
        c = C.get(im[0])
        if not c or not c.get('computed_rotation'): continue
        pano = c.get('camera_type') in ('spherical', 'equirectangular')
        cam = Camera(c, (2048, 1024) if pano else (c['width'], c['height']), HPANO if pano and alto == HCAM else alto)
        if not pano and (abs(cam.pitch) > 15 or abs(cam.roll) > 10): continue
        q = cam.at(x, y, 1)
        if not q or not (0 <= q[0] < cam.W and 0 <= q[1] < cam.H): continue
        f = photo(im[0], tok)
        if not f: continue
        img = Image.open(f).convert('RGB'); cam.W, cam.H = img.size
        dr = ImageDraw.Draw(img, 'RGBA'); w = max(2, img.width // 900); Y = (255, 214, 0, 235)
        try: font = ImageFont.load_default(size=max(14, img.width // 70))
        except TypeError: font = ImageFont.load_default()
        ring = [(x + r * math.cos(t * math.pi / 16), y + r * math.sin(t * math.pi / 16)) for t in range(33)]
        pts = []
        for a, b in zip(ring, ring[1:]):
            for pl in cam.line((*a, 0), (*b, 0), 3): dr.line(pl, fill=Y, width=w); pts += pl
        top = max(8, 2 * r)
        for pl in cam.line((x, y, 0), (x, y, top)): dr.line(pl, fill=Y, width=w); pts += pl
        for z in range(1, int(top) + 1):
            t = .4 if z % 5 else 1
            for pl in cam.line((x - t, y, z), (x + t, y, z), 4): dr.line(pl, fill=Y, width=w)
            if z % 5 == 0 and (o := cam.at(x + t, y, z)): dr.text((o[0] + 4, o[1]), str(z), fill=Y, font=font, anchor='lm', stroke_width=2, stroke_fill=(0, 0, 0))
        if not pts: continue
        xs, ys = [p[0] for p in pts], [p[1] for p in pts]; m = .35 * max(max(xs) - min(xs), max(ys) - min(ys), 80)
        crop = img.crop((int(max(0, min(xs) - m)), int(max(0, min(ys) - m)), int(min(img.width, max(xs) + m)), int(min(img.height, max(ys) + m))))
        when = time.strftime('%Y-%m-%d', time.gmtime(c['captured_at'] / 1000)); who = (c.get('creator') or {}).get('username', '')
        tiles.append((crop, f'{x:g},{y:g}  r {r:g} m  {"panoramica" if pano else "perspectiva"}', f'{when}  a {d:.0f} m  {who}', None))
        rows.append(f'{x:g},{y:g}\t{im[0]}\t{when}\t{who}\thttps://www.mapillary.com/app/?pKey={im[0]}\ta {d:.0f} m')
        if len(tiles) >= fotos: break
    if not tiles: print('Ninguna foto mira a ese punto sin un edificio en medio.'); return
    sheets(tiles, rows, nombre, 6, 'punto')

if __name__ == '__main__':
    cli.run({'clave': cmd_clave, 'cobertura': cmd_cobertura, 'lugares': cmd_lugares, 'fachada': cmd_fachada, 'punto': cmd_punto}, __doc__)
