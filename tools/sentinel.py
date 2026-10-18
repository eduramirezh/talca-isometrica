"""Sentinel-2 L2A sobre la comuna: lo que hay hoy, a 10 m (solo consulta; los datos quedan en raw/, fuera de git).

La imagen de Esri de la ciudad es de 2015 (z18) o 2020 (z17); Sentinel-2 pasa cada 2–3 días. A 10 m no se ven casas,
techos ni hileras de un huerto, pero sí si un potrero ya es una villa o un sitio quedó pelado. Usa el catálogo STAC
earth-search de Element84 (COG en AWS, sin cuenta) y rasterio para leer solo la ventana de la comuna.

  uv run --with rasterio --with pillow python tools/sentinel.py buscar [--desde 2026-01-01] [--hasta …] [--nubes 5] [--n 8]
      # escenas de la tesela 19HBA (cubre la comuna entera), de la más nueva a la más vieja, con las nubes de la
      # tesela y, para las primeras --n, las de la comuna (de la capa SCL); --nubes: el máximo sobre la comuna
  uv run --with rasterio --with pillow python tools/sentinel.py bajar <id|ultima> [--nubes 5]
      # la ventana de la comuna de color (TCI), rojo (B04), infrarrojo (B08) y clases (SCL) -> raw/satelite/sentinel2/<AAAAMMDD>/
      # (ultima: la escena más nueva con menos de --nubes % de nubes sobre la comuna; ~10 MB)
  uv run --with rasterio --with pillow python tools/sentinel.py caja x0 x1 y0 y1 [nombre] [--fecha AAAAMMDD] [--esri[=z]]
      # una caja de metros de grilla, al norte arriba: el color y el NDVI lado a lado, a 2 m por píxel, con la caja y los
      # usos de suelo de config/usos.json encima; --esri agrega la imagen de Esri (z17 por omisión: 2020 en la ciudad)
      # -> diagnostics/s2-<nombre>.png
  uv run --with rasterio --with pillow python tools/sentinel.py usos [--fecha AAAAMMDD] [--todos]
      # cada entrada de config/usos.json: NDVI medio y la parte que hoy se ve verde, pelada o construida; lista las de
      # campo (potrero, eriazo, huerto, viña, parcelas, bosque) que se ven construidas y las de vivienda que se ven
      # peladas o verdes, para revisarlas en la imagen (solo lee config/usos.json)

Sin --fecha, caja y usos usan la última escena bajada. «Construido» es una prueba gruesa: NDVI bajo (< 0,3) y textura
(la desviación del rojo en 3 × 3 píxeles sobre 0,018 de reflectancia: techos y calles alternan, un potrero arado
no). Calibrada en la escena del 14 de septiembre de 2026: las villas nuevas dan NDVI 0,1–0,2 y textura ~0,025; los
potreros, huertos y viñas, NDVI 0,45–0,8 y textura < 0,01. Un sitio eriazo de la ciudad (tierra junto a calles y
casas) se confunde con lo construido. Una entrada marcada es para mirar en la imagen, no para cambiar sola.

Licencia: datos Copernicus Sentinel, libres y abiertos; una imagen o un dato derivado publicado debe decir
«Contiene datos modificados de Copernicus Sentinel <año>» (lo escribe en cada imagen y en el listado).
"""
import json, math, sys, urllib.request
from pathlib import Path
ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / 'pipeline'))
from common import RAW, EXT, DATA, unloc

STAC = 'https://earth-search.aws.element84.com/v1/search'
TILE = '19HBA'                                 # la tesela MGRS que cubre toda la comuna (UTM 19 S, EPSG:32719)
OUT = RAW / 'satelite' / 'sentinel2'
BANDS = {'tci': 'visual', 'b04': 'red', 'b08': 'nir', 'scl': 'scl'}
CLOUD = {3, 8, 9, 10}                          # SCL: sombra de nube, nubes de probabilidad media y alta, cirros
UA = {'User-Agent': 'talca-isometrica', 'Content-Type': 'application/json'}
CAMPO = {'potrero', 'eriazo', 'huerto', 'vina', 'parcelas', 'bosque'}
CASAS = {'vivienda', 'conjunto'}

def attribution(fecha): return f'Contiene datos modificados de Copernicus Sentinel {fecha[:4]}'

def comuna_ll():
    """La caja de lat/lon de la comuna (common.EXT, girada: sus cuatro esquinas)."""
    cs = [unloc(x, y) for x in EXT[:2] for y in EXT[2:]]
    return min(c[0] for c in cs), max(c[0] for c in cs), min(c[1] for c in cs), max(c[1] for c in cs)

def search(desde, hasta, ids=None):
    la0, la1, lo0, lo1 = comuna_ll(); items, body = [], {
        'collections': ['sentinel-2-l2a'], 'bbox': [lo0, la0, lo1, la1], 'datetime': f'{desde}T00:00:00Z/{hasta}T23:59:59Z',
        'limit': 100, 'sortby': [{'field': 'properties.datetime', 'direction': 'desc'}]}
    if ids: body = {'collections': ['sentinel-2-l2a'], 'ids': ids}
    url = STAC
    while url and len(items) < 500:
        r = json.loads(urllib.request.urlopen(urllib.request.Request(url, json.dumps(body).encode(), UA), timeout=60).read())
        items += [f for f in r['features'] if f['properties'].get('grid:code') == f'MGRS-{TILE}']
        nxt = next((l for l in r.get('links', []) if l.get('rel') == 'next'), None)
        url, body = (nxt['href'], nxt.get('body', body)) if nxt else (None, None)
    return items

def window(href, item):
    """La ventana de la comuna de un asset: (arreglo, transformación afín)."""
    import rasterio
    from rasterio.windows import from_bounds
    from rasterio.warp import transform
    la0, la1, lo0, lo1 = comuna_ll()
    with rasterio.open(href) as src:
        xs, ys = transform('EPSG:4326', src.crs, [lo0, lo1, lo0, lo1], [la0, la0, la1, la1])
        w = from_bounds(min(xs) - 50, min(ys) - 50, max(xs) + 50, max(ys) + 50, src.transform).round_offsets().round_lengths()
        return src.read(window=w), src.window_transform(w), str(src.crs)

def comuna_clouds(item):
    """La parte de la comuna con nubes o sombras según la capa SCL (20 m)."""
    import numpy as np
    a, _, _ = window(item['assets']['scl']['href'], item); a = a[0]
    valid = a > 0
    return float(np.isin(a, list(CLOUD)).sum() / max(1, valid.sum()))

def flag(argv, name, default=None):
    for a in argv:
        if a.startswith(f'--{name}='): return a.split('=', 1)[1]
    if f'--{name}' in argv:
        i = argv.index(f'--{name}')
        if i + 1 < len(argv) and not argv[i + 1].startswith('--'): return argv[i + 1]
        return True
    return default

def buscar(argv):
    import datetime
    hoy = datetime.date.today().isoformat()
    items = search(flag(argv, 'desde', f'{int(hoy[:4]) - 1}{hoy[4:]}'), flag(argv, 'hasta', hoy))
    n, lim = int(flag(argv, 'n', 8)), float(flag(argv, 'nubes', 100))
    print(f'{len(items)} escenas de la tesela {TILE}; las nubes sobre la comuna, en las {n} más nuevas con menos de 60 % en la tesela')
    for f in items:
        p = f['properties']; c, c_txt = None, ''
        if n > 0 and p['eo:cloud_cover'] < 60: c = comuna_clouds(f) * 100; c_txt = f'{c:5.1f} % en la comuna'; n -= 1
        if (c if c is not None else p['eo:cloud_cover']) > lim: continue
        print(f"  {f['id']:28s} {p['datetime'][:10]}  nubes {p['eo:cloud_cover']:5.1f} % en la tesela  {c_txt}")

def bajar(argv):
    import numpy as np
    sel = argv[0] if argv else 'ultima'
    lim = float(flag(argv, 'nubes', 5))
    if sel == 'ultima':
        import datetime
        hoy = datetime.date.today()
        items = search((hoy - datetime.timedelta(days=120)).isoformat(), hoy.isoformat())
        item = next((f for f in items if f['properties']['eo:cloud_cover'] < 60 and comuna_clouds(f) * 100 < lim), None)
        if not item: raise SystemExit(f'no hay escenas con menos de {lim} % de nubes sobre la comuna en 120 días')
    else:
        item = next(iter(search(None, None, [sel])), None)
        if not item: raise SystemExit(f'no encontré {sel}')
    fecha = item['properties']['datetime'][:10].replace('-', ''); d = OUT / fecha
    if (d / 'meta.json').exists() or (d / 'tci.npy').exists():
        print(f'{d.relative_to(ROOT)} ya existe, se omite'); return
    d.mkdir(parents=True, exist_ok=True); meta = {'id': item['id'], 'datetime': item['properties']['datetime'], 'bands': {}}
    for k, a in BANDS.items():
        asset = item['assets'][a]; arr, t, crs = window(asset['href'], item)
        np.save(d / f'{k}.npy', arr); (d / f'{k}.tf').write_text(','.join(map(str, t[:6])))
        rb = (asset.get('raster:bands') or [{}])[0]
        # earth-search ya restó el desfase de la línea base 04.00 cuando dice boa_offset_applied: el offset −0,1 que
        # declara la banda no se aplica (con él, el rojo de un potrero sale negativo)
        off = 0 if item['properties'].get('earthsearch:boa_offset_applied') else rb.get('offset', 0)
        meta['bands'][k] = {'crs': crs, 'scale': rb.get('scale', 1), 'offset': off}
        print(k, arr.shape, arr.dtype)
    (d / 'meta.json').write_text(json.dumps(meta, indent=1))
    print(f"{d.relative_to(ROOT)}: {item['id']}; {attribution(fecha)}")

class Scene:
    """Una escena bajada: bands[k] = (arreglo, transformación) y pix(k, lat, lon) -> (fila, columna) de cada banda."""
    def __init__(self, fecha=None):
        import numpy as np
        ds = sorted(p for p in OUT.glob('[0-9]' * 8) if (p / 'tci.npy').exists())
        if not ds: raise SystemExit('no hay escenas bajadas: tools/sentinel.py bajar ultima')
        d = OUT / fecha if fecha else ds[-1]
        if not (d / 'tci.npy').exists(): raise SystemExit(f'no está {d}: ' + ', '.join(p.name for p in ds))
        self.fecha = d.name; self.meta = json.loads((d / 'meta.json').read_text()) if (d / 'meta.json').exists() else {}
        self.b = {k: (np.load(d / f'{k}.npy', allow_pickle=False), [float(v) for v in (d / f'{k}.tf').read_text().split(',')]) for k in BANDS}
        bm = self.meta.get('bands', {})
        # las escenas bajadas antes de meta.json (la evaluación): UTM 19 S, de earth-search con el desfase ya restado
        self.crs = bm.get('b04', {}).get('crs', 'EPSG:32719')
        self.scale = bm.get('b04', {}).get('scale', 1e-4); self.offset = bm.get('b04', {}).get('offset', 0)

    def utm(self, lats, lons):
        from rasterio.warp import transform
        return transform('EPSG:4326', self.crs, list(lons), list(lats))

    def sample(self, k, xs, ys):
        """Los valores de la banda k (vecino más cercano) en puntos UTM; fuera de la ventana, 0."""
        import numpy as np
        a, t = self.b[k]; a = a if a.ndim == 2 else np.moveaxis(a, 0, -1)
        c = np.floor((np.asarray(xs) - t[2]) / t[0]).astype(int); r = np.floor((np.asarray(ys) - t[5]) / t[4]).astype(int)
        ok = (r >= 0) & (r < a.shape[0]) & (c >= 0) & (c < a.shape[1])
        out = np.zeros((len(c),) + a.shape[2:], a.dtype); out[ok] = a[r[ok], c[ok]]
        return out

    def refl(self, k, xs, ys):
        return self.sample(k, xs, ys).astype(float) * self.scale + self.offset

    def texture(self, xs, ys):
        """La desviación del rojo en los 3 × 3 píxeles de 10 m alrededor de cada punto."""
        import numpy as np
        t = self.b['b04'][1]; vs = [self.refl('b04', np.asarray(xs) + dx * t[0], np.asarray(ys) + dy * t[4])
                                    for dx in (-1, 0, 1) for dy in (-1, 0, 1)]
        return np.std(np.stack(vs), axis=0)

def classes(sc, xs, ys):
    """Por punto: 0 sin dato o nube, 1 verde, 2 pelado, 3 construido; y el NDVI."""
    import numpy as np
    red, nir = sc.refl('b04', xs, ys), sc.refl('b08', xs, ys); scl = sc.sample('scl', xs, ys)
    ndvi = (nir - red) / np.maximum(1e-6, nir + red)
    cls = np.where(ndvi >= 0.3, 1, np.where(sc.texture(xs, ys) > 0.018, 3, 2))
    bad = (scl == 0) | np.isin(scl, list(CLOUD)) | (sc.sample('b04', xs, ys) == 0) | (sc.sample('b08', xs, ys) == 0)
    cls[bad] = 0; ndvi[bad] = 0
    return cls, ndvi

def caja(argv):
    import numpy as np
    from PIL import Image, ImageDraw
    pos = [a for a in argv if not a.startswith('--')]
    x0, x1, y0, y1 = map(float, pos[:4]); name = pos[4] if len(pos) > 4 else 'caja'
    sc = Scene(flag(argv, 'fecha')); m = 2.0                              # metros por píxel de salida
    cs = [unloc(x, y) for x in (x0, x1) for y in (y0, y1)]
    la0, la1, lo0, lo1 = min(c[0] for c in cs), max(c[0] for c in cs), min(c[1] for c in cs), max(c[1] for c in cs)
    ky = 111320.0; kx = ky * math.cos(math.radians((la0 + la1) / 2))
    W, H = int((lo1 - lo0) * kx / m), int((la1 - la0) * ky / m)
    lons = lo0 + (np.arange(W) + .5) * m / kx; lats = la1 - (np.arange(H) + .5) * m / ky
    LO, LA = np.meshgrid(lons, lats); xs, ys = sc.utm(LA.ravel(), LO.ravel())
    tci = sc.sample('tci', xs, ys).reshape(H, W, 3)
    _, ndvi = classes(sc, xs, ys); nd = np.clip(ndvi.reshape(H, W) / 0.6, 0, 1)
    ndimg = np.stack([(255 * (1 - nd)).astype(np.uint8), (60 + 160 * nd).astype(np.uint8), (60 * (1 - nd)).astype(np.uint8)], -1)
    P = lambda q: ((unloc(*q)[1] - lo0) * kx / m, (la1 - unloc(*q)[0]) * ky / m)
    panels = [Image.fromarray(tci, 'RGB'), Image.fromarray(ndimg, 'RGB')]
    if flag(argv, 'esri'):
        from satellite import mosaic
        z = int(flag(argv, 'esri')) if flag(argv, 'esri') is not True else 17
        img, Pe = mosaic(x0, x1, y0, y1, z)                                # la misma caja de lat/lon, a la escala de las otras
        tl = [Pe(c) for c in [(x0, y0), (x0, y1), (x1, y0), (x1, y1)]]
        X0, Y0, X1, Y1 = min(p[0] for p in tl), min(p[1] for p in tl), max(p[0] for p in tl), max(p[1] for p in tl)
        panels.insert(0, img.crop((int(X0), int(Y0), int(X1), int(Y1))).resize((W, H)))
    usos = []
    if (ROOT / 'config' / 'usos.json').exists():
        from usos import entries
        g = json.load(open(DATA / 'geometry.json'))
        for k, (u, rings) in enumerate(entries(g)):
            r = rings[0]
            if max(q[0] for q in r) < x0 or min(q[0] for q in r) > x1 or max(q[1] for q in r) < y0 or min(q[1] for q in r) > y1: continue
            usos.append((k, u, rings))
    for im in panels:
        d = ImageDraw.Draw(im)
        d.polygon([P(q) for q in [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]], outline=(255, 255, 255))
        for k, u, rings in usos:
            for r in rings: d.polygon([P(q) for q in r], outline=(255, 150, 0))
            c = (sum(q[0] for q in rings[0]) / len(rings[0]), sum(q[1] for q in rings[0]) / len(rings[0]))
            d.text(P(c), f"{k} {u['uso']}", fill=(255, 150, 0))
    out = Image.new('RGB', (len(panels) * (W + 4) - 4, H + 16), (0, 0, 0)); x = 0
    for im in panels: out.paste(im, (x, 16)); x += W + 4
    ImageDraw.Draw(out).text((4, 2), ('Esri World Imagery (solo consulta) | ' if len(panels) > 2 else '')
                             + f"Sentinel-2 L2A {sc.meta.get('id', sc.fecha)}: color | NDVI (rojo < 0, verde > 0,6). {attribution(sc.fecha)}", fill=(255, 255, 255))
    f = ROOT / 'diagnostics' / f's2-{name}.png'; f.parent.mkdir(exist_ok=True); out.save(f); print(f.relative_to(ROOT), out.size)

def pip(x, y, ring):
    inside = False
    for (ax, ay), (bx, by) in zip(ring, ring[1:] + ring[:1]):
        if (ay > y) != (by > y) and x < ax + (bx - ax) * (y - ay) / (by - ay): inside = not inside
    return inside

def usos(argv):
    import numpy as np
    from usos import entries
    sc = Scene(flag(argv, 'fecha')); g = json.load(open(DATA / 'geometry.json')); rows = []
    for k, (u, rings) in enumerate(entries(g)):
        r = rings[0]; bx0, bx1 = min(q[0] for q in r), max(q[0] for q in r); by0, by1 = min(q[1] for q in r), max(q[1] for q in r)
        st = max(5.0, math.sqrt((bx1 - bx0) * (by1 - by0) / 4000))     # unos miles de puntos por entrada, cada 5 m o más
        pts = [(x, y) for x in np.arange(bx0 + st / 2, bx1, st) for y in np.arange(by0 + st / 2, by1, st)
               if pip(x, y, r) and not any(pip(x, y, h) for h in rings[1:])]
        if len(pts) < 4: continue
        ll = [unloc(x, y) for x, y in pts]; xs, ys = sc.utm([p[0] for p in ll], [p[1] for p in ll])
        cls, ndvi = classes(sc, xs, ys); ok = cls > 0
        if ok.sum() < 4: continue
        f = [float((cls[ok] == c).mean()) for c in (1, 2, 3)]
        uso = u['uso']; mark = ''
        if uso in CAMPO and f[2] > 0.5: mark = 'se ve construido'
        elif uso in CASAS and f[2] < 0.3: mark = 'se ve pelado' if f[1] > f[0] else 'se ve verde'
        rows.append((k, u, float(ndvi[ok].mean()), f, mark, len(pts) * st * st / 1e4))
    print(f"config/usos.json contra Sentinel-2 {sc.meta.get('id', sc.fecha)} (verde: NDVI ≥ 0,3; construido: NDVI < 0,3 con textura)")
    print(f'{"#":>4} {"uso":12s} {"ha":>6} {"NDVI":>5} {"verde":>6} {"pelado":>6} {"constr.":>7}  nombre / fuente')
    for k, u, nd, f, mark, ha in rows:
        if not mark and '--todos' not in argv: continue
        nombre = u.get('nombre') or (u.get('fuente') or '')[:50]
        print(f"{k:4d} {u['uso']:12s} {ha:6.1f} {nd:5.2f} {f[0]*100:5.0f}% {f[1]*100:5.0f}% {f[2]*100:6.0f}%  {nombre}" + (f'  <- {mark}' if mark else ''))
    n = sum(1 for r in rows if r[4])
    print(f'{n} entradas para revisar de {len(rows)} medidas. {attribution(sc.fecha)}')

def main(argv):
    if not argv: raise SystemExit(__doc__)
    cmd, rest = argv[0], argv[1:]
    {'buscar': buscar, 'bajar': bajar, 'caja': caja, 'usos': usos}.get(cmd, lambda a: (_ for _ in ()).throw(SystemExit(__doc__)))(rest)

if __name__ == '__main__':
    main(sys.argv[1:])
