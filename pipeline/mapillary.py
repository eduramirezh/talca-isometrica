"""Mapillary: dónde hay fotos a nivel de calle en la comuna y cuáles miran a un lugar, para modelar con ellas.

  python mapillary.py clave                       # dice de dónde se lee la clave y la prueba con una consulta
  python mapillary.py cobertura [--refrescar]     # las fotos de la comuna, de las teselas vectoriales de Mapillary (z14)
                                                  # -> raw/mapillary/imagenes.json; resumen por año y por autor, y
                                                  # con Pillow el panel diagnostics/mapillary-cobertura.png
  python mapillary.py cobertura --caja -800 900 -700 800   # el panel de una caja de grilla (x0 x1 y0 y1), 1 m por píxel
  python mapillary.py lugares [80] [--todos]      # cada lugar de data/pois.json con fotos a menos de 80 m: cuántas,
                                                  # cuántas lo miran (±40°), de cuántas pasadas y la más nueva
  python landmark.py photos <lugar|x,y> --mapillary [r]   # las fotos que miran al lugar, una por pasada, con su índice
  uv run --with pillow python mapillary.py mirar 275 747 [--radio 450] [--desde 2021] [--n 12] [--nombre raices]
                                                  # lo que dejan ver de un punto las fotos lejanas: las originales de las
                                                  # panorámicas recortadas hacia él -> diagnostics/fotos/<nombre>/
  … mirar 275 747 --ids 873538511416209,2445007295696620 [--ancho 14 --alto 40 --bajo 4 --escala 7]   # esas, más de cerca

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

mirar: para lo que no tiene fotos cerca, o solo viejas (el Edificio Raíces, terminado después de 2020: a menos de
150 m solo hay fotos de 2018, del sitio vacío), pero es alto y se ve de lejos entre casas y árboles. Elige de
raw/mapillary/imagenes.json las fotos desde --desde (el año) a menos de --radio m que lo miran (las panorámicas
siempre), hasta cuatro por pasada separadas 6 m (de lejos, unos metros cambian qué árbol tapa), las pasadas más cercanas
primero, y baja la original (4096 × 2048 en una panorámica; landmark.py baja la miniatura de 2048). De una panorámica
recorta --ancho grados alrededor del rumbo al punto (computed_compass_angle: la columna del medio es ese rumbo) y de
--bajo grados (4) bajo el horizonte hasta lo que mide --alto m a esa distancia, más 3°, agrandado --escala veces; una foto plana va
entera. Escribe los recortes, indice.txt (fecha, autor, licencia, enlace: para FUENTES) y hoja.png, todos juntos.
El horizonte de una panorámica puede estar corrido unos grados (la cámara inclinada en el auto; las de 2023 de
SolutivaSistemas): si el edificio sale cortado abajo, suba --bajo; arriba, --alto. A más de ~150 m la imagen es borrosa: da la
silueta, las alturas (el ángulo sobre el horizonte por la distancia) y el ritmo de las ventanas, no el detalle.

Licencia: las fotos son CC BY-SA 4.0 («© <autor>, Mapillary, CC BY-SA 4.0»). Se bajan para mirarlas al modelar
(diagnostics/, fuera de git), como las de Commons; los términos de Mapillary piden su logo y un enlace si se publican.
"""
import gzip, json, math, os, struct, time, urllib.error, urllib.parse
from pathlib import Path
import cli, net
from common import ROOT, DATA, RAW, loc, unloc
from geom import dec, in_ring

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

def pick_far(x, y, radio, desde, n, per_seq=4, gap=6.0):
    """The images of imagenes.json from year `desde` on that could see grid point (x, y) from less than `radio` m:
    panoramas, or photos pointing at it ±FRONT. Up to per_seq of each sequence, closest first and at least `gap` m
    apart (from afar a few metres change which tree is in the way), the closest sequences first, at most n."""
    D = json.load(open(OUT / 'imagenes.json'))
    t0 = time.mktime((desde, 1, 1, 0, 0, 0, 0, 0, 0)) * 1000
    seqs = {}
    for im in D['imagenes']:
        if im[3] < t0: continue
        fc = facing(im, x, y, radio)
        if fc: seqs.setdefault(im[6] or im[0], []).append((fc[0], im))
    out = []
    for seq in sorted(seqs.values(), key=lambda s: min(d for d, _ in s)):
        kept = []
        for d, im in sorted(seq, key=lambda v: v[0]):
            if all(math.dist(im[1:3], k[1:3]) >= gap for k in kept): kept.append(im)
            if len(kept) == per_seq: break
        out += kept
    return out[:n]

def cmd_mirar(x: float, y: float, *, radio: float = 450, desde: int = 2021, n: int = 16, ancho: float = 24,
              alto: float = 40, bajo: float = 4, escala: int = 3, nombre: str = '', ids: str = ''):
    """mirar X Y: lo que dejan ver de un punto las fotos lejanas (un edificio alto entre casas y árboles)."""
    from PIL import Image, ImageDraw
    tok = token()
    D = json.load(open(OUT / 'imagenes.json'))
    pos = {im[0]: im for im in D['imagenes']}
    pick = [pos[i] for i in ids.split(',') if i in pos] if ids else pick_far(x, y, radio, desde, n)
    if not pick: raise SystemExit(f'Sin fotos desde {desde} a menos de {radio:.0f} m de ({x:.0f}, {y:.0f}) que lo miren.')
    info = {}
    for k in range(0, len(pick), 50):
        for r in graph('images', {'image_ids': ','.join(im[0] for im in pick[k:k+50]),
                                  'fields': 'id,thumb_original_url,computed_compass_angle,camera_type,creator,captured_at'}, tok).get('data', []):
            info[r['id']] = r
    out = ROOT / 'diagnostics' / 'fotos' / (nombre or f'mirar-{x:.0f},{y:.0f}')
    (out / 'originales').mkdir(parents=True, exist_ok=True)
    rows, crops = [], []
    for im in pick:
        r = info.get(im[0], {})
        if not r.get('thumb_original_url'): continue
        f = out / 'originales' / f'{im[0]}.jpg'
        if not f.exists(): f.write_bytes(net.get(r['thumb_original_url'], timeout=90))
        img = Image.open(f).convert('RGB'); W, H = img.size
        dist, b = math.dist(im[1:3], (x, y)), bearing(im[1], im[2], x, y)
        pano = im[5] or r.get('camera_type') in ('spherical', 'equirectangular')
        cca = r.get('computed_compass_angle', im[4])
        if pano and cca is not None:
            px = W / 360                                       # equirectangular: the centre column is the heading
            c = W * ((b - cca) / 360 + .5)
            top = math.degrees(math.atan2(alto, dist)) + 3
            x0 = int(c - ancho / 2 * px)
            band = Image.new('RGB', (W * 3, H))                # three copies side by side: the crop may wrap round 0°
            for i in range(3): band.paste(img, (W * i, 0))
            crop = band.crop((x0 + W, int(H / 2 - top * px), x0 + W + int(ancho * px), int(H / 2 + bajo * px)))
            note = f'panorámica, recortada al rumbo {b:.0f}° ±{ancho / 2:.0f}° y de -{bajo:.0f}° a +{top:.0f}°'
        else:
            crop = img; note = f'foto de rumbo {cca if cca is not None else "?"}°: entera (el punto está a {b:.0f}°)'
        crop = crop.resize((crop.width * escala, crop.height * escala), Image.LANCZOS)
        name = f'{len(rows):02d}.png'; crop.save(out / name); crops.append((name, crop))
        user = (r.get('creator') or {}).get('username', '')
        rows.append(f'{name}  {time.strftime("%Y-%m-%d", time.gmtime(im[3] / 1000))}  [Mapillary] {im[0]}  [CC BY-SA 4.0] {user}  '
                    f'(en {im[1]:.0f},{im[2]:.0f}: a {dist:.0f} m)\n    {note}\n    https://www.mapillary.com/app/?pKey={im[0]}')
    (out / 'indice.txt').write_text('\n'.join(rows) + '\n')
    cw = max(c.width for _, c in crops); ch = max(c.height for _, c in crops); cols = min(4, len(crops))
    sheet = Image.new('RGB', (cw * cols, ch * ((len(crops) + cols - 1) // cols)), 'white'); d = ImageDraw.Draw(sheet)
    for i, (name, c) in enumerate(crops):
        sheet.paste(c, ((i % cols) * cw, (i // cols) * ch)); d.text(((i % cols) * cw + 6, (i // cols) * ch + 4), name, fill=(255, 0, 0))
    if sheet.width > 1600: sheet = sheet.resize((1600, sheet.height * 1600 // sheet.width))
    sheet.save(out / 'hoja.png')
    print('\n'.join(rows)); print(f'-> {out.relative_to(ROOT)}/ (hoja.png: todos los recortes)')

if __name__ == '__main__':
    cli.run({'clave': cmd_clave, 'cobertura': cmd_cobertura, 'lugares': cmd_lugares, 'mirar': cmd_mirar}, __doc__)
