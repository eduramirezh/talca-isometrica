"""Imagen satelital con las manzanas del Censo encima, para revisar qué hay de verdad en una manzana.

Dibuja el contorno de cada manzana de data/geometry.json (rosado = con datos, celeste = sin
información, verde = marcada como construida en config/manzanas.json) y su índice, sobre las
teselas de Esri World Imagery. Así se decidió qué manzanas «sin información» están construidas. Los usos de
suelo (config/usos.json y los archivos de las fuentes chilenas, usos.entries()) van encima en naranjo, con su número
de entrada y su uso.

  python pipeline/satellite.py plaza-de-armas            # 900 × 900 m alrededor de un lugar (id de pois.py)
  python pipeline/satellite.py mercado-central 400       # caja de 400 m
  python pipeline/satellite.py -450 450 -450 450 [z] [nombre]   # caja libre en metros de grilla (x0 x1 y0 y1), zoom 15–19
  python pipeline/satellite.py punto 3755 1414 [lado] [z]       # caja de `lado` m (900) centrada en (x, y) de grilla
  … --calles                                                    # además las calles del mapa y una cruz cada 100 m
                                                                # (rotulada cada 200 m), para dibujar polígonos a mano
  python pipeline/satellite.py marco X Y A u0 u1 v0 v1 [z] [nombre]   # la imagen en el marco local de un hito (landmark.py frame),
                                                                # girada para que v apunte arriba, con cruces cada 10 m en (u,v)
  … --rejilla[=N]                                             # una cruz cada N m (10), rotulada cada 5 cruces (coordenadas de grilla)

Salida: diagnostics/sat-<nombre>.png (caja libre: sat-caja.png o el nombre dado; punto: sat-<x>_<y>.png). Las teselas quedan en raw/satelite/. Requiere Pillow
(viene con matplotlib) e internet la primera vez.

La imagen de Esri no es una sola: cada zoom tiene sus propias capturas. En la ciudad, z18 y z19 son una de
2015-03-31 (WorldView-3, 0,31 m) y z17 una de 2020-04-06 (WorldView-2, 0,5 m); el campo, de 2024 a 2026. Estas
opciones dicen de cuándo es lo que se mira y muestran las versiones anteriores (Esri World Imagery Wayback: las
publicaciones de la imagen desde 2014, con los mismos términos que la actual: solo consulta):

  … --fecha                    # imprime la fecha, el sensor y la resolución de las capturas del área dibujada (y qué
                               # parte cubre cada una), la escribe en una esquina de la imagen y avisa si a z17 hay
                               # una captura más nueva
  … --release=<id|AAAA-MM-DD|ultima>   # las teselas de una publicación de Wayback (una fecha: la última publicada ese
                               # día o antes), en raw/satelite/wayback/<id>/; sin la opción, la imagen actual
  python pipeline/satellite.py historia X Y [z]                 # cada versión de la tesela bajo (x, y) de grilla (z 17 por
                               # omisión): publicación, su fecha y la captura que trae (fecha, sensor, resolución)
  python pipeline/satellite.py tiempo x0 x1 y0 y1 [z] [nombre] [--todas | --release=a,b,c]
                               # la caja en cada captura distinta bajo su centro (z 17), lado a lado y con la fecha
                               # -> diagnostics/tiempo-<nombre>.png; --todas: cada versión de la tesela, aunque
                               # repita la captura (reprocesos); --release: esas publicaciones

El servicio rechaza el User-Agent de Python (403): las consultas llevan uno propio.
"""
import functools, json, math, sys, time, urllib.parse, urllib.request
from common import ROOT, DATA, RAW, unloc, require

URL = 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
WB_CONFIG = 'https://s3-us-west-2.amazonaws.com/config.maptiles.arcgis.com/waybackconfig.json'
WB_TILE = 'https://wayback.maptiles.arcgis.com/arcgis/rest/services/World_Imagery/WMTS/1.0.0/default028mm/MapServer/tile/{r}/{z}/{y}/{x}'
WB_TILEMAP = 'https://wayback.maptiles.arcgis.com/arcgis/rest/services/World_Imagery/MapServer/tilemap/{r}/{z}/{y}/{x}'
UA = {'User-Agent': 'talca-isometrica'}

def get(url):
    return urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=60).read()

def dec(a):
    pts, x, y = [], 0, 0
    for i in range(0, len(a), 2): x += a[i]; y += a[i+1]; pts.append((x, y))
    return pts

def tile_of(lat, lon, z):
    """La tesela (columna, fila) de un punto a zoom z (Web Mercator)."""
    n = 2 ** z; s = math.radians(lat)
    return int((lon+180)/360*n), int((1-math.log(math.tan(s)+1/math.cos(s))/math.pi)/2*n)

def mosaic(x0, x1, y0, y1, z=18, release=None):
    """The Esri tiles over the box x0..x1, y0..y1 (grid metres) at zoom z, as one image (cached in raw/satelite/),
    and P((x, y)): the pixel of a grid point in it. pipeline/edificios.py and golf.py use it too. release: a Wayback
    release id (cached in raw/satelite/wayback/<id>/); None is the current imagery."""
    from PIL import Image
    n = 2 ** z
    def px(x, y):                                  # metros de grilla -> píxel global de la tesela
        la, lo = unloc(x, y); s = math.radians(la)
        return (lo+180)/360*n*256, (1-math.log(math.tan(s)+1/math.cos(s))/math.pi)/2*n*256
    cs = [px(x, y) for x in (x0, x1) for y in (y0, y1)]
    X0, X1 = min(c[0] for c in cs), max(c[0] for c in cs); Y0, Y1 = min(c[1] for c in cs), max(c[1] for c in cs)
    img = Image.new('RGB', (int(X1-X0), int(Y1-Y0)))
    cache = RAW / 'satelite' if release is None else RAW / 'satelite' / 'wayback' / str(release)
    cache.mkdir(parents=True, exist_ok=True)
    for tx in range(int(X0//256), int(X1//256)+1):
        for ty in range(int(Y0//256), int(Y1//256)+1):
            f = cache / f'{z}_{tx}_{ty}.jpg'
            if not f.exists():                     # Wayback responde con un 301 a la publicación que tiene la tesela
                f.write_bytes(get(URL.format(z=z, x=tx, y=ty) if release is None else WB_TILE.format(r=release, z=z, x=tx, y=ty)))
            img.paste(Image.open(f), (int(tx*256-X0), int(ty*256-Y0)))
    return img, lambda q: tuple(a-b for a, b in zip(px(*q), (X0, Y0)))

# ---- Esri World Imagery Wayback: fechas de captura y versiones anteriores ----

def releases():
    """Las publicaciones de Wayback, de la más nueva a la más vieja: [(id, 'AAAA-MM-DD', metadataLayerUrl)]. La lista
    se guarda en raw/satelite/wayback/waybackconfig.json y se vuelve a bajar cuando tiene más de 30 días."""
    f = RAW / 'satelite' / 'wayback' / 'waybackconfig.json'
    if not f.exists() or time.time() - f.stat().st_mtime > 30 * 86400:
        f.parent.mkdir(parents=True, exist_ok=True); f.write_bytes(get(WB_CONFIG))
    cfg = json.loads(f.read_text())
    out = [(int(k), v['itemTitle'].rsplit(' ', 1)[-1].strip(')'), v['metadataLayerUrl']) for k, v in cfg.items()]
    return sorted(out, key=lambda r: r[1], reverse=True)

def pick_release(spec, rels=None):
    """--release=<id|AAAA-MM-DD|ultima> -> (id, fecha, metadataLayerUrl)."""
    rels = rels or releases()
    if spec in ('ultima', 'última'): return rels[0]
    if spec.isdigit():
        for r in rels:
            if r[0] == int(spec): return r
        raise SystemExit(f'no hay una publicación {spec} en Wayback')
    older = [r for r in rels if r[1] <= spec]
    if not older: raise SystemExit(f'Wayback empieza el {rels[-1][1]}')
    return older[0]

def release_of(flags):
    """--release=<id|AAAA-MM-DD|ultima> -> el id de la publicación, o None (la imagen actual)."""
    spec = next((f.split('=', 1)[1] for f in flags if f.startswith('--release=')), None)
    return None if spec is None else pick_release(spec)[0]

def layer(z):
    """La capa de metadatos de un zoom: 4 = 30 cm (z19), 5 = 60 cm (z18), 6 = 1,2 m (z17)…"""
    return 23 - min(z, 23)

def fmt_date(d): d = str(d); return f'{d[:4]}-{d[4:6]}-{d[6:]}'
def fmt_cap(a): return f"{fmt_date(a['SRC_DATE'])} {a['SRC_DESC']} {str(a['SRC_RES']).replace('.', ',')} m ({a['NICE_NAME']})"

def query(meta_url, z, **p):
    p = dict(p, inSR=4326, spatialRel='esriSpatialRelIntersects', outFields='SRC_DATE,SRC_DESC,SRC_RES,NICE_NAME', f='json')
    return [dict(f['attributes'], rings=f.get('geometry', {}).get('rings', []))
            for f in json.loads(get(f'{meta_url}/{layer(z)}/query?' + urllib.parse.urlencode(p))).get('features', [])]

def in_rings(lon, lat, rings):
    inside = False
    for r in rings:
        for (ax, ay), (bx, by) in zip(r, r[1:] + r[:1]):
            if (ay > lat) != (by > lat) and lon < ax + (bx - ax) * (lat - ay) / (by - ay): inside = not inside
    return inside

def dates(x0, x1, y0, y1, z, release=None):
    """Las capturas del área x0..x1, y0..y1 (grilla) a zoom z en una publicación (None: la última), con la parte que
    cubre cada una (21 × 21 puntos): [(atributos, fracción)], la más nueva primero."""
    rel = pick_release(str(release)) if release is not None else releases()[0]
    ll = [unloc(x, y) for x in (x0, x1) for y in (y0, y1)]
    fs = query(rel[2], z, geometry=f'{min(p[1] for p in ll)},{min(p[0] for p in ll)},{max(p[1] for p in ll)},{max(p[0] for p in ll)}',
               geometryType='esriGeometryEnvelope', outSR=4326, returnGeometry='true', maxAllowableOffset=0.0001, geometryPrecision=6)
    fs.sort(key=lambda a: -a['SRC_DATE']); n = [0] * len(fs); N = 21
    for i in range(N):
        for j in range(N):
            la, lo = unloc(x0 + (x1 - x0) * i / (N - 1), y0 + (y1 - y0) * j / (N - 1))
            k = next((k for k, f in enumerate(fs) if in_rings(lo, la, f['rings'])), None)   # la más nueva tapa a las otras
            if k is not None: n[k] += 1
    out = {}                                                      # una línea por captura, aunque venga en varios polígonos
    for f, c in zip(fs, n):
        if c: k = fmt_cap(f); out[k] = (f, out.get(k, (f, 0))[1] + c / N / N)
    return list(out.values())

def print_dates(x0, x1, y0, y1, z, release=None):
    """--fecha: imprime las capturas del área y avisa si a z17 hay una más nueva. Devuelve las líneas."""
    d = dates(x0, x1, y0, y1, z, release)
    lines = [f'z{z}: {fmt_cap(a)} {round(f * 100)} %' for a, f in d] or [f'z{z}: sin metadatos']
    for l in lines: print(l)
    if z > 17 and d:
        low = dates(x0, x1, y0, y1, 17, release)
        if low and low[0][0]['SRC_DATE'] > d[0][0]['SRC_DATE']:
            a = low[0][0]
            print(f"a z17 hay una imagen de {fmt_date(a['SRC_DATE'])} ({str(a['SRC_RES']).replace('.', ',')} m, {a['SRC_DESC']}): "
                  f'más nueva que la de z{z}')
    return lines

def stamp(img, lines):
    """Escribe las líneas en la esquina superior izquierda, sobre un fondo negro."""
    from PIL import ImageDraw
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, 8 + 6 * max(map(len, lines)), 12 * len(lines) + 6], fill=(0, 0, 0))
    for i, l in enumerate(lines): d.text((4, 3 + 12 * i), l, fill=(255, 255, 255))

def versions(x, y, z=17, rels=None):
    """Las versiones de la tesela bajo (x, y), de la más nueva a la más vieja: [(id, fecha de la publicación,
    metadataLayerUrl)]. Recorre hacia atrás con tilemap, que dice en qué publicación cambió la tesela por última vez
    (~6–13 consultas)."""
    rels = rels or releases(); la, lo = unloc(x, y); col, row = tile_of(la, lo, z)
    idx = {r[0]: k for k, r in enumerate(rels)}; out = []; i = 0
    while i < len(rels):
        t = json.loads(get(WB_TILEMAP.format(r=rels[i][0], z=z, y=row, x=col)))
        if not t.get('data', [0])[0]: break                       # no hay tesela en esta publicación ni antes
        sel = (t.get('select') or [rels[i][0]])[0]
        if sel not in idx: break
        out.append(rels[idx[sel]]); i = idx[sel] + 1
    return out

@functools.lru_cache(maxsize=None)
def capture_at(rel, x, y, z):
    """Los atributos de la captura de una publicación en un punto, o None."""
    la, lo = unloc(x, y)
    fs = query(rel[2], z, geometry=f'{lo},{la}', geometryType='esriGeometryPoint', returnGeometry='false')
    return max(fs, key=lambda a: a['SRC_DATE']) if fs else None

def historia(argv):
    """historia X Y [z]: cada versión de la tesela bajo (x, y), con su captura."""
    x, y = float(argv[0]), float(argv[1]); z = int(argv[2]) if len(argv) > 2 else 17
    vs = versions(x, y, z); col, row = tile_of(*unloc(x, y), z)
    print(f'({x:.0f}, {y:.0f}), z{z}, tesela {row}/{col}: {len(vs)} versiones')
    for r in vs:
        c = capture_at(r, x, y, z)
        print(f'  publicación {r[0]:>6} del {r[1]}: ' + (f'captura {fmt_cap(c)}' if c else 'sin metadatos'))

def tiempo(argv, flags):
    """tiempo x0 x1 y0 y1 [z] [nombre]: la caja en cada captura distinta bajo su centro, lado a lado."""
    from PIL import Image
    x0, x1, y0, y1 = map(float, argv[:4]); z = int(argv[4]) if len(argv) > 4 else 17
    name = argv[5] if len(argv) > 5 else 'caja'; cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    spec = next((f.split('=', 1)[1] for f in flags if f.startswith('--release=')), None); rels = releases()
    if spec: vs = [pick_release(r, rels) for r in spec.split(',')]
    else:
        vs, seen = [], set()
        for r in versions(cx, cy, z, rels):
            c = capture_at(r, cx, cy, z); key = c and c['SRC_DATE']
            if '--todas' in flags or key not in seen: vs.append(r); seen.add(key)
    imgs = []
    caps = [(r, capture_at(r, cx, cy, z)) for r in vs]            # de la captura más vieja a la más nueva, de izquierda a derecha
    for r, c in sorted(caps, key=lambda rc: ((rc[1] or {}).get('SRC_DATE', 0), rc[0][1])):
        img, _ = mosaic(x0, x1, y0, y1, z, r[0])
        stamp(img, [fmt_cap(c) if c else 'sin metadatos', f'publicación {r[0]} ({r[1]})'])
        imgs.append(img); print(f'publicación {r[0]} ({r[1]}): ' + (f'captura {fmt_cap(c)}' if c else 'sin metadatos'))
    if not imgs: raise SystemExit('no hay versiones de esa tesela')
    out = Image.new('RGB', (sum(i.size[0] for i in imgs) + 4 * (len(imgs) - 1), max(i.size[1] for i in imgs)), (255, 255, 255)); x = 0
    for i in imgs: out.paste(i, (x, 0)); x += i.size[0] + 4
    f = ROOT / 'diagnostics' / f'tiempo-{name}.png'; f.parent.mkdir(exist_ok=True); out.save(f); print(f.relative_to(ROOT), out.size)

def marco(argv, flags=()):
    """satellite.py marco X Y A u0 u1 v0 v1 [z] [nombre]: la imagen en el marco local de un hito (landmark.py frame:
    origen (X, Y) de grilla, v hacia el ángulo A en grados desde +x, u a la derecha de v), girada para que v apunte
    hacia arriba, con una cruz cada 10 m rotulada cada 50 (u,v). Sirve para leer las medidas de un recinto tal como
    lo escribe el modelo (G(u,v) = [X+u·sinA+v·cosA, Y−u·cosA+v·sinA]). Salida: diagnostics/marco-<nombre>.png."""
    from PIL import Image, ImageDraw
    X, Y, A = float(argv[0]), float(argv[1]), math.radians(float(argv[2])); u0, u1, v0, v1 = map(float, argv[3:7])
    z = int(argv[7]) if len(argv) > 7 else 19; name = argv[8] if len(argv) > 8 else 'caja'; sa, ca = math.sin(A), math.cos(A)
    G = lambda u, v: (X + u*sa + v*ca, Y - u*ca + v*sa)
    cs = [G(u, v) for u in (u0, u1) for v in (v0, v1)]
    box = (min(c[0] for c in cs), max(c[0] for c in cs), min(c[1] for c in cs), max(c[1] for c in cs)); rel = release_of(flags)
    img, P = mosaic(*box, z, rel)
    s = 4; W, H = int((u1-u0)*s), int((v1-v0)*s)              # 4 px per metre: P is affine to well under a pixel over a few hundred metres
    o, pu, pv = P(G(u0, v1)), P(G(u0+1, v1)), P(G(u0, v1-1))   # source pixel of the output's top-left, one metre along u, one metre down
    a, b, c, d = (pu[0]-o[0])/s, (pv[0]-o[0])/s, (pu[1]-o[1])/s, (pv[1]-o[1])/s
    out = img.transform((W, H), Image.AFFINE, (a, b, o[0], c, d, o[1]), Image.BICUBIC); dr = ImageDraw.Draw(out)
    for u in range(int(u0//10+1)*10, int(u1)+1, 10):
        for v in range(int(v0//10+1)*10, int(v1)+1, 10):
            x, y = (u-u0)*s, (v1-v)*s; big = u % 50 == 0 and v % 50 == 0
            dr.line([(x-2, y), (x+2, y)], fill=(255, 255, 0) if big else 'white'); dr.line([(x, y-2), (x, y+2)], fill=(255, 255, 0) if big else 'white')
            if big: dr.text((x+3, y+2), f'{u},{v}', fill=(255, 255, 0))
    if '--fecha' in flags: stamp(out, print_dates(*box, z, rel))
    f = ROOT / 'diagnostics' / f'marco-{name}.png'; f.parent.mkdir(exist_ok=True); out.save(f); print(f.relative_to(ROOT), out.size)

def main(argv):
    flags = [a for a in argv if a.startswith('--')]; argv = [a for a in argv if not a.startswith('--')]
    if argv[0] == 'marco': return marco(argv[1:], flags)
    if argv[0] == 'historia': return historia(argv[1:])
    if argv[0] == 'tiempo': return tiempo(argv[1:], flags)
    from PIL import ImageDraw                 # Pillow solo para dibujar (historia no lo necesita)
    if argv[0] == 'punto':
        x, y = float(argv[1]), float(argv[2]); h = float(argv[3]) / 2 if len(argv) > 3 else 450
        x0, x1, y0, y1, z, name = x-h, x+h, y-h, y+h, int(argv[4]) if len(argv) > 4 else 18, f'{x:.0f}_{y:.0f}'
    elif len(argv) >= 4:
        (x0, x1, y0, y1), z = map(float, argv[:4]), int(argv[4]) if len(argv) > 4 else 18
        name = argv[5] if len(argv) > 5 else 'caja'
    else:
        pois = {p['id']: p for p in json.load(open(require(DATA / 'pois.json', 'Ejecute: make pois')))['pois']}
        p = pois[argv[0]]; h = float(argv[1]) / 2 if len(argv) > 1 else 450
        x0, x1, y0, y1, z, name = p['x']-h, p['x']+h, p['y']-h, p['y']+h, 18, argv[0]
    g = json.load(open(require(DATA / 'geometry.json', 'Ejecute: make data')))
    sys.path.insert(0, str(ROOT / 'pipeline')); from build import mark_built, pip
    t0 = [b[0] for b in g['blocks']]; mark_built(g['blocks'])

    rel = release_of(flags); img, P = mosaic(x0, x1, y0, y1, z, rel)
    d = ImageDraw.Draw(img)
    for i, b in enumerate(g['blocks']):
        r = dec(b[3])
        if max(q[0] for q in r) < x0 or min(q[0] for q in r) > x1 or max(q[1] for q in r) < y0 or min(q[1] for q in r) > y1: continue
        col = (80, 255, 80) if b[0] != t0[i] else (255, 60, 200) if b[0] == 0 else (0, 230, 255)
        d.polygon([P(q) for q in r], outline=col, width=2)
        c = (sum(q[0] for q in r)/len(r), sum(q[1] for q in r)/len(r))
        if pip(c, r): q = P(c); d.text((q[0]-10, q[1]-5), str(i), fill=(255, 255, 0))
    if '--calles' in flags:                                   # calles del mapa (gris) y cruces de grilla cada 100 m
        for s in g['streets']:
            pts = dec(s[2])
            if any(x0-50 < q[0] < x1+50 and y0-50 < q[1] < y1+50 for q in pts): d.line([P(q) for q in pts], fill=(170, 170, 170), width=1)
        for gx in range(int(x0//100+1)*100, int(x1)+1, 100):
            for gy in range(int(y0//100+1)*100, int(y1)+1, 100):
                q = P((gx, gy)); d.line([(q[0]-4, q[1]), (q[0]+4, q[1])], fill='white'); d.line([(q[0], q[1]-4), (q[0], q[1]+4)], fill='white')
                if gx % 200 == 0 and gy % 200 == 0: d.text((q[0]+3, q[1]+2), f'{gx},{gy}', fill='white')
    for fl in flags:                                          # --rejilla[=N]: una cruz cada N m (10), rotulada cada 5, para leer coordenadas
        if not fl.startswith('--rejilla'): continue
        n = int(fl.split('=')[1]) if '=' in fl else 10
        for gx in range(int(x0//n+1)*n, int(x1)+1, n):
            for gy in range(int(y0//n+1)*n, int(y1)+1, n):
                q = P((gx, gy)); big = gx % (5*n) == 0 and gy % (5*n) == 0
                d.line([(q[0]-2, q[1]), (q[0]+2, q[1])], fill=(255, 255, 0) if big else 'white'); d.line([(q[0], q[1]-2), (q[0], q[1]+2)], fill=(255, 255, 0) if big else 'white')
                if big: d.text((q[0]+3, q[1]+2), f'{gx},{gy}', fill=(255, 255, 0))
    if (ROOT / 'config' / 'usos.json').exists():              # los usos de suelo, en naranjo
        from usos import entries
        for k, (u, rings) in enumerate(entries(g)):
            r = rings[0]
            if max(q[0] for q in r) < x0 or min(q[0] for q in r) > x1 or max(q[1] for q in r) < y0 or min(q[1] for q in r) > y1: continue
            for r in rings: d.polygon([P(q) for q in r], outline=(255, 150, 0), width=3)
            r = rings[0]; c = (sum(q[0] for q in r)/len(r), sum(q[1] for q in r)/len(r)); q = P(c)
            d.text((q[0]-20, q[1]+6), f"{k} {u['uso']}", fill=(255, 150, 0))
    if '--fecha' in flags: stamp(img, print_dates(x0, x1, y0, y1, z, rel))
    out = ROOT / 'diagnostics' / f'sat-{name}.png'; out.parent.mkdir(exist_ok=True)
    img.save(out); print(out.relative_to(ROOT), img.size)

if __name__ == '__main__':
    main(sys.argv[1:] or ['plaza-de-armas'])
