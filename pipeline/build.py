"""Ensambla dist/talca.html: la plantilla (src/, ver template()) + data/geometry.json + data/elevation.json + data/ruta5.json
+ config/grid_lines.json + config/usos.json + data/pois.json. config/manzanas.json reclasifica como construidas (tipo 3) manzanas «sin
información» del Censo; config/usos.json va como DATA.usos (usos de suelo; sus entradas `vivienda` agregan manzanas
construidas donde el Censo no tiene).

La plantilla se arma con los fuentes de src/ (template()) y tiene dos marcadores, /*DATA*/ y /*POIS*/, que se
reemplazan por JSON literal.
El resultado es un único HTML autocontenido (~670 KB) que solo carga three.js r128 desde cdnjs y
las fuentes de Google Fonts.

  python pipeline/build.py             -> dist/talca.html (fragmento, como se publica en Claude)
  python pipeline/build.py --standalone -> además dist/index.html con <!doctype>, <head> y <body>,
                                           para abrir directo en el navegador o servir con un hosting estático.
  python pipeline/build.py --where index.html:4026
                                        -> el archivo de src/ y la línea que dan esa línea de dist/ (index.html:N o
                                           (index):N como en la consola del navegador; talca.html:N o N para
                                           dist/talca.html y los errores de make check)
"""
import json, re, sys
from common import ROOT, DATA, CONFIG, require, loc

SRC = ROOT / 'src'

def cut(path, *markers):
    """A source file cut at the lines holding only each marker (and its indentation), in that order: [(first line, text)]
    for the pieces between them, so that the line numbers of each piece are known."""
    t, out, pos = path.read_text(), [], 0
    for marker in markers:
        m = list(re.finditer(rf'^[ \t]*{re.escape(marker)}\n', t, re.M))
        assert len(m) == 1 and m[0].start() >= pos, f'{path.relative_to(ROOT)}: el marcador {marker} aparece {len(m)} veces o fuera de orden (debe ser 1)'
        out.append((t.count('\n', 0, pos) + 1, t[pos:m[0].start()])); pos = m[0].end()
    return out + [(t.count('\n', 0, pos) + 1, t[pos:])]

def hito_ids():
    """The landmarks' ids in src/js/hitos/ORDER, in their order (one per line; # starts a comment)."""
    ids = [l.split('#')[0].strip() for l in (SRC / 'js' / 'hitos' / 'ORDER').read_text().splitlines()]
    return [i for i in ids if i]

def sources():
    """The template's source files: the page, the style, the script's sections and the landmarks in ORDER."""
    return [SRC / 'page.html', SRC / 'style.css', *sorted((SRC / 'js').glob('*.js')),
            *(SRC / 'js' / 'hitos' / f'{h}.js' for h in hito_ids())]

def pieces():
    """The template as [(source file, its first line, text)], in order: src/page.html with src/style.css at /*STYLE*/
    and the script at /*SCRIPT*/, the files src/js/*.js in the order of their names; src/js/45-landmarks.js holds
    /*HITOS*/ inside buildModels(B,S), where the landmarks src/js/hitos/<id>.js go in the order of hitos/ORDER."""
    (a, page0), (b, page1), (c, page2) = cut(SRC / 'page.html', '/*STYLE*/', '/*SCRIPT*/')
    out = [(SRC / 'page.html', a, page0), (SRC / 'style.css', 1, (SRC / 'style.css').read_text()), (SRC / 'page.html', b, page1)]
    for f in sorted((SRC / 'js').glob('*.js')):
        if f.name != '45-landmarks.js': out.append((f, 1, f.read_text())); continue
        (a, head), (b, tail) = cut(f, '/*HITOS*/')
        out.append((f, a, head))
        out += [(SRC / 'js' / 'hitos' / f'{h}.js', 1, (SRC / 'js' / 'hitos' / f'{h}.js').read_text()) for h in hito_ids()]
        out.append((f, b, tail))
    return out + [(SRC / 'page.html', c, page2)]

def template():
    """The template, a single HTML fragment (src/template.html until it was split): the pieces() joined."""
    return ''.join(t for _, _, t in pieces())

def where(line):
    """A line of the template, which is also a line of dist/talca.html (the JSON of /*DATA*/ and /*POIS*/ has no line
    breaks) -> (source file relative to ROOT, its line)."""
    n = 1
    for f, a, t in pieces():
        k = t.count('\n')
        if line < n + k: return f.relative_to(ROOT), a + line - n
        n += k
    raise ValueError(f'la plantilla tiene {n - 1} líneas: no hay línea {line}')

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

def enc(pts):
    out = []; px = py = 0
    for x, y in pts:
        xi, yi = int(round(x)), int(round(y)); out += [xi-px, yi-py]; px, py = xi, yi
    return out

USO_OPTS = {'rumbo': 'r', 'cancha': 'c', 'tipo': 't', 'arboles': 'a', 'matorral': 'm'}

def land_uses(geo):
    """config/usos.json -> DATA.usos = {k: [uso, …], u: [[uso index, ring (delta-encoded), {opts} | 0], …]}.
    A `vivienda` entry is housing the Censo does not have: with `bi`, that block becomes built (type 3, as with
    manzanas.json); with `poly` (ground without a census block), a new built block is appended, ~35 dwellings/ha,
    so that cityGen lays houses along the map's streets inside it."""
    names, out = [], []
    for u in json.load(open(CONFIG / 'usos.json'))['usos']:
        if u['uso'] == 'vivienda':
            if 'poly' in u:
                r = u['poly']; A = abs(sum(r[i-1][0]*r[i][1]-r[i][0]*r[i-1][1] for i in range(len(r))))/2
                viv = max(1, round(A/1e4*35)); geo['blocks'].append([3, viv*3, viv, enc(r)])
            elif geo['blocks'][u['bi']][0] == 1: geo['blocks'][u['bi']][0] = 3
            continue
        if u['uso'] not in names: names.append(u['uso'])
        ring = u['poly'] if 'poly' in u else dec(geo['blocks'][u['bi']][3])
        o = {USO_OPTS[k]: v for k, v in u.items() if k in USO_OPTS}
        out.append([names.index(u['uso']), enc(ring), o or 0])
    geo['usos'] = {'k': names, 'u': out}

# What --standalone puts before the fragment in dist/index.html: its lines are this many lines further down.
STANDALONE = ('<!doctype html>\n<html lang="es"><head><meta charset="utf-8">\n'
              '<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">\n'
              '<style>:root{color-scheme:light}body{margin:0}[hidden]{display:none!important}</style>\n'
              '</head><body>\n')

def cmd_where(arg):
    """`--where 4021`, `--where talca.html:4021` or `--where index.html:4026` (as the browser's console gives it,
    also `(index):4026`): the source file and line of that line of dist/."""
    f, _, n = arg.rpartition(':'); n = int(n)
    if 'index' in f: n -= STANDALONE.count('\n')
    src, k = where(n)
    print(f'{src}:{k}'); print((ROOT / src).read_text().split('\n')[k-1][:160])

def main():
    if '--where' in sys.argv: return cmd_where(sys.argv[sys.argv.index('--where') + 1])
    geo = json.load(open(require(DATA / 'geometry.json', 'Ejecute: make data')))
    mark_built(geo['blocks'])
    land_uses(geo)
    geo['elev'] = json.load(open(require(DATA / 'elevation.json', 'Ejecute: make elevation')))
    geo['r5'] = json.load(open(require(DATA / 'ruta5.json', 'Ejecute: make ruta5')))   # las calzadas y ramales de la Ruta 5 (R5)
    geo['lines'] = {k: v for k, v in json.load(open(CONFIG / 'grid_lines.json')).items() if not k.startswith('_')}
    pois = json.load(open(require(DATA / 'pois.json', 'Ejecute: make pois')))
    t = template()
    assert '/*DATA*/' in t and '/*POIS*/' in t, 'faltan los marcadores en la plantilla'
    js = lambda o: json.dumps(o, separators=(',', ':'), ensure_ascii=False).replace('</', '<\\/')
    out = t.replace('/*DATA*/', js(geo)).replace('/*POIS*/', js(pois))
    (ROOT / 'dist').mkdir(exist_ok=True)
    (ROOT / 'dist' / 'talca.html').write_text(out)
    print('dist/talca.html:', len(out.encode()), 'bytes')
    if '--standalone' in sys.argv:
        page = STANDALONE + out + '\n</body></html>\n'
        (ROOT / 'dist' / 'index.html').write_text(page); print('dist/index.html:', len(page.encode()), 'bytes')

if __name__ == '__main__':
    main()
