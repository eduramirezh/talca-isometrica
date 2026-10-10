"""Ensambla dist/talca.html: src/template.html + data/geometry.json + data/elevation.json + config/grid_lines.json
+ data/pois.json. config/manzanas.json reclasifica como construidas (tipo 3) manzanas «sin información» del Censo.

La plantilla tiene dos marcadores, /*DATA*/ y /*POIS*/, que se reemplazan por JSON literal.
El resultado es un único HTML autocontenido (~670 KB) que solo carga three.js r128 desde cdnjs y
las fuentes de Google Fonts.

  python pipeline/build.py             -> dist/talca.html (fragmento, como se publica en Claude)
  python pipeline/build.py --standalone -> además dist/index.html con <!doctype>, <head> y <body>,
                                           para abrir directo en el navegador o servir con un hosting estático.
"""
import json, sys
from common import ROOT, DATA, CONFIG, require, loc

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

def mark_built(blocks):
    """Manzanas tipo 1 (sin información) que config/manzanas.json señala como construidas -> tipo 3."""
    for m in json.load(open(CONFIG / 'manzanas.json'))['construidas']:
        p = loc(m['punto'][1], m['punto'][0])
        hit = [b for b in blocks if b[0] in (1, 3) and pip(p, dec(b[3]))]
        assert hit, f"manzanas.json: ninguna manzana sin información contiene «{m['nombre']}»"
        for b in hit: b[0] = 3

def main():
    geo = json.load(open(require(DATA / 'geometry.json', 'Ejecute: make data')))
    mark_built(geo['blocks'])
    geo['elev'] = json.load(open(require(DATA / 'elevation.json', 'Ejecute: make elevation')))
    geo['lines'] = {k: v for k, v in json.load(open(CONFIG / 'grid_lines.json')).items() if not k.startswith('_')}
    pois = json.load(open(require(DATA / 'pois.json', 'Ejecute: make pois')))
    t = (ROOT / 'src' / 'template.html').read_text()
    assert '/*DATA*/' in t and '/*POIS*/' in t, 'faltan los marcadores en la plantilla'
    js = lambda o: json.dumps(o, separators=(',', ':'), ensure_ascii=False).replace('</', '<\\/')
    out = t.replace('/*DATA*/', js(geo)).replace('/*POIS*/', js(pois))
    (ROOT / 'dist').mkdir(exist_ok=True)
    (ROOT / 'dist' / 'talca.html').write_text(out)
    print('dist/talca.html:', len(out.encode()), 'bytes')
    if '--standalone' in sys.argv:
        page = ('<!doctype html>\n<html lang="es"><head><meta charset="utf-8">\n'
                '<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">\n'
                '<style>:root{color-scheme:light}body{margin:0}[hidden]{display:none!important}</style>\n'
                '</head><body>\n' + out + '\n</body></html>\n')
        (ROOT / 'dist' / 'index.html').write_text(page); print('dist/index.html:', len(page.encode()), 'bytes')

if __name__ == '__main__':
    main()
