"""Imagen satelital con las manzanas del Censo encima, para revisar qué hay de verdad en una manzana.

Dibuja el contorno de cada manzana de data/geometry.json (rosado = con datos, celeste = sin
información, verde = marcada como construida en config/manzanas.json) y su índice, sobre las
teselas de Esri World Imagery. Así se decidió qué manzanas «sin información» están construidas. Los usos de
suelo de config/usos.json van encima en naranjo, con su número de entrada y su uso.

  python pipeline/satellite.py plaza-de-armas            # 900 × 900 m alrededor de un lugar (id de pois.py)
  python pipeline/satellite.py mercado-central 400       # caja de 400 m
  python pipeline/satellite.py -450 450 -450 450 [z] [nombre]   # caja libre en metros de grilla (x0 x1 y0 y1), zoom 15–19
  python pipeline/satellite.py punto 3755 1414 [lado] [z]       # caja de `lado` m (900) centrada en (x, y) de grilla
  … --calles                                                    # además las calles del mapa y una cruz cada 100 m
                                                                # (rotulada cada 200 m), para dibujar polígonos a mano

Salida: diagnostics/sat-<nombre>.png (caja libre: sat-caja.png o el nombre dado; punto: sat-<x>_<y>.png). Las teselas quedan en raw/satelite/. Requiere Pillow
(viene con matplotlib) e internet la primera vez.
"""
import json, math, sys, urllib.request
from PIL import Image, ImageDraw
from common import ROOT, DATA, RAW, unloc, require

URL = 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'

def dec(a):
    pts, x, y = [], 0, 0
    for i in range(0, len(a), 2): x += a[i]; y += a[i+1]; pts.append((x, y))
    return pts

def mosaic(x0, x1, y0, y1, z=18):
    """The Esri tiles over the box x0..x1, y0..y1 (grid metres) at zoom z, as one image (cached in raw/satelite/),
    and P((x, y)): the pixel of a grid point in it. pipeline/edificios.py uses it too."""
    n = 2 ** z
    def px(x, y):                                  # metros de grilla -> píxel global de la tesela
        la, lo = unloc(x, y); s = math.radians(la)
        return (lo+180)/360*n*256, (1-math.log(math.tan(s)+1/math.cos(s))/math.pi)/2*n*256
    cs = [px(x, y) for x in (x0, x1) for y in (y0, y1)]
    X0, X1 = min(c[0] for c in cs), max(c[0] for c in cs); Y0, Y1 = min(c[1] for c in cs), max(c[1] for c in cs)
    img = Image.new('RGB', (int(X1-X0), int(Y1-Y0)))
    cache = RAW / 'satelite'; cache.mkdir(parents=True, exist_ok=True)
    for tx in range(int(X0//256), int(X1//256)+1):
        for ty in range(int(Y0//256), int(Y1//256)+1):
            f = cache / f'{z}_{tx}_{ty}.jpg'
            if not f.exists():
                req = urllib.request.Request(URL.format(z=z, x=tx, y=ty), headers={'User-Agent': 'talca-isometrica'})
                f.write_bytes(urllib.request.urlopen(req).read())
            img.paste(Image.open(f), (int(tx*256-X0), int(ty*256-Y0)))
    return img, lambda q: tuple(a-b for a, b in zip(px(*q), (X0, Y0)))

def main(argv):
    flags = [a for a in argv if a.startswith('--')]; argv = [a for a in argv if not a.startswith('--')]
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

    img, P = mosaic(x0, x1, y0, y1, z)
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
    if (ROOT / 'config' / 'usos.json').exists():              # los usos de suelo, en naranjo
        from usos import entries
        for k, (u, rings) in enumerate(entries(g)):
            r = rings[0]
            if max(q[0] for q in r) < x0 or min(q[0] for q in r) > x1 or max(q[1] for q in r) < y0 or min(q[1] for q in r) > y1: continue
            for r in rings: d.polygon([P(q) for q in r], outline=(255, 150, 0), width=3)
            r = rings[0]; c = (sum(q[0] for q in r)/len(r), sum(q[1] for q in r)/len(r)); q = P(c)
            d.text((q[0]-20, q[1]+6), f"{k} {u['uso']}", fill=(255, 150, 0))
    out = ROOT / 'diagnostics' / f'sat-{name}.png'; out.parent.mkdir(exist_ok=True)
    img.save(out); print(out.relative_to(ROOT), img.size)

if __name__ == '__main__':
    main(sys.argv[1:] or ['plaza-de-armas'])
