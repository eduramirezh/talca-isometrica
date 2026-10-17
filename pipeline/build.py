"""Ensambla dist/talca.html: la plantilla (src/, ver template()) + data/geometry.json + data/elevation.json + data/ruta5.json
+ config/usos.json + data/pois.json. config/manzanas.json reclasifica como construidas (tipo 3) manzanas «sin
información» del Censo; config/usos.json va como DATA.usos (usos de suelo; sus entradas `vivienda` agregan manzanas
construidas donde el Censo no tiene).

La plantilla se arma con los fuentes de src/ (template()) y tiene dos marcadores, /*DATA*/ y /*POIS*/, que se
reemplazan por JSON literal.
El resultado es un único HTML autocontenido (~670 KB) que solo carga three.js r128 desde cdnjs y
las fuentes de Google Fonts.

  python pipeline/build.py             -> dist/talca.html (fragmento, como se publica en Claude)
  python pipeline/build.py --standalone -> además dist/index.html con <!doctype>, <head> (título, descripción,
                                           canónica, Open Graph, ícono) y <body>, más los archivos de src/site/: el sitio
                                           que se publica en talca.eduramirez.com (make deploy) o se abre directo.
  python pipeline/build.py --where index.html:4026
                                        -> el archivo de src/ y la línea que dan esa línea de dist/ (index.html:N o
                                           (index):N como en la consola del navegador; talca.html:N o N para
                                           dist/talca.html y los errores de make check)
"""
import json, re, shutil, sys
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
    /*HITOS*/ inside buildModels(B,S), where the landmarks src/js/hitos/<id>.js go in the order of hitos/ORDER.
    Each piece of the script comes after a line `// ---- src/js/<file>[:line] ----` (its first line is 0), so that the
    browser's sources show where the code comes from."""
    def js(f, a, text, ind=''):
        return [(f, 0, f'{ind}// ---- {f.relative_to(ROOT)}{f":{a}" if a > 1 else ""} ----\n'), (f, a, text)]
    (a, page0), (b, page1), (c, page2) = cut(SRC / 'page.html', '/*STYLE*/', '/*SCRIPT*/')
    out = [(SRC / 'page.html', a, page0), (SRC / 'style.css', 1, (SRC / 'style.css').read_text()), (SRC / 'page.html', b, page1)]
    for f in sorted((SRC / 'js').glob('*.js')):
        if f.name != '45-landmarks.js': out += js(f, 1, f.read_text()); continue
        (a, head), (b, tail) = cut(f, '/*HITOS*/')
        out += js(f, a, head)
        for h in hito_ids(): out += js(SRC / 'js' / 'hitos' / f'{h}.js', 1, (SRC / 'js' / 'hitos' / f'{h}.js').read_text(), '  ')
        out += js(f, b, tail, '  ')
    return out + [(SRC / 'page.html', c, page2)]

def template():
    """The template, a single HTML fragment (src/template.html until it was split): the pieces() joined."""
    return ''.join(t for _, _, t in pieces())

def where(line):
    """A line of the template, which is also a line of dist/talca.html (the JSON of /*DATA*/ and /*POIS*/ has no line
    breaks) -> (source file relative to ROOT, its line; 0 for the `// ---- <file> ----` line before it)."""
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
    """Manzanas tipo 1 (sin información) que config/manzanas.json señala como construidas -> tipo 3; y al revés, las
    manzanas con datos (tipo 0) que señala como parques (el bandejón de la Alameda) -> tipo 1, sin lotes."""
    cfg = json.load(open(CONFIG / 'manzanas.json'))
    for key, src, dst in (('construidas', (1, 3), 3), ('parques', (0, 1), 1)):
        for m in cfg.get(key, []):
            p = loc(m['punto'][1], m['punto'][0])
            hit = [b for b in blocks if b[0] in src and pip(p, dec(b[3]))]
            assert hit, f"manzanas.json ({key}): ninguna manzana {'sin información' if dst == 3 else 'con datos'} contiene «{m['nombre']}»"
            for b in hit: b[0] = dst

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
    so that cityGen lays houses along the map's streets inside it. Entries with most of their vertices outside the
    commune's limit (DATA.limit) are left out."""
    names, out, lim = [], [], dec(geo['limit'])
    for u in json.load(open(CONFIG / 'usos.json'))['usos']:
        r = u['poly'] if 'poly' in u else dec(geo['blocks'][u['bi']][3])
        if sum(pip(p, lim) for p in r) < len(r) / 2: continue   # mostly outside the commune (in Maule): not drawn
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

# The published site (talca.eduramirez.com, Cloudflare Pages): its <head>, which the fragment cannot carry (the artifact
# platform supplies its own), and the files of src/site/ (favicon, og.jpg: tools/site_assets.py) copied next to it.
SITE = 'https://talca.eduramirez.com/'
TITLE = 'Talca Isométrica'
DESC = ('Maqueta isométrica interactiva de Talca, Chile: sus tribunales, notarías e historia legal junto a los hitos '
        'de la ciudad, sobre datos reales del Censo 2017 y OpenStreetMap.')
OG_ALT = 'La Plaza de Armas y el barrio cívico de la Alameda de Talca en la maqueta isométrica, con los marcadores de los lugares.'
# What --standalone puts before the fragment in dist/index.html: its lines are this many lines further down.
STANDALONE = ('<!doctype html>\n<html lang="es-CL"><head><meta charset="utf-8">\n'
              '<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">\n'
              f'<title>{TITLE}</title><meta name="description" content="{DESC}"><meta name="author" content="Edu Ramírez">\n'
              f'<link rel="canonical" href="{SITE}"><link rel="icon" href="favicon.svg" type="image/svg+xml">'
              '<link rel="apple-touch-icon" href="apple-touch-icon.png"><meta name="theme-color" content="#F3F4EF">\n'
              f'<meta property="og:type" content="website"><meta property="og:site_name" content="{TITLE}"><meta property="og:locale" content="es_CL">'
              f'<meta property="og:url" content="{SITE}"><meta property="og:title" content="{TITLE}"><meta property="og:description" content="{DESC}">\n'
              f'<meta property="og:image" content="{SITE}og.jpg"><meta property="og:image:width" content="1200"><meta property="og:image:height" content="630">'
              f'<meta property="og:image:alt" content="{OG_ALT}">\n'
              f'<meta name="twitter:card" content="summary_large_image"><meta name="twitter:title" content="{TITLE}"><meta name="twitter:description" content="{DESC}">'
              f'<meta name="twitter:image" content="{SITE}og.jpg"><meta name="twitter:image:alt" content="{OG_ALT}">\n'
              '<style>:root{color-scheme:light}body{margin:0}[hidden]{display:none!important}</style>\n'
              '</head><body>\n')

# The poster (tools/site_assets.py poster: src/site/poster-*.webp), the initial view shown while the map is generated:
# a <picture> at the line <!--POSTER--> of src/page.html, so that the browser fetches the phone's or the desktop's as
# soon as it reads the HTML; the inline script after #app places it. Only in dist/index.html: in the fragment (the
# artifact, which carries no other files) the ~1 MB of both as data: URIs would delay the map's data behind them.
POSTER_MARK = '<!--POSTER-->'
def poster():
    if not all((SRC / 'site' / f'poster-{n}.webp').exists() for n in ('movil', 'escritorio')): return ''
    return ('<picture><source media="(max-width:760px)" srcset="poster-movil.webp">'
            '<img id="poster" src="poster-escritorio.webp" alt="" aria-hidden="true" elementtiming="poster" fetchpriority="high"></picture>')

def cmd_where(arg):
    """`--where 4021`, `--where talca.html:4021` or `--where index.html:4026` (as the browser's console gives it,
    also `(index):4026`): the source file and line of that line of dist/."""
    f, _, n = arg.rpartition(':'); n = int(n)
    if 'index' in f: n -= STANDALONE.count('\n')
    src, k = where(n)
    if not k: return print(f'{src}: la línea `// ---- … ----` que build.py pone antes de un trozo de ese archivo')
    print(f'{src}:{k}'); print((ROOT / src).read_text().split('\n')[k-1][:160])

def main():
    if '--where' in sys.argv: return cmd_where(sys.argv[sys.argv.index('--where') + 1])
    geo = json.load(open(require(DATA / 'geometry.json', 'Ejecute: make data')))
    mark_built(geo['blocks'])
    land_uses(geo)
    geo['elev'] = json.load(open(require(DATA / 'elevation.json', 'Ejecute: make elevation')))
    geo['r5'] = json.load(open(require(DATA / 'ruta5.json', 'Ejecute: make ruta5')))   # las calzadas y ramales de la Ruta 5 (R5)
    geo['ed'] = json.load(open(require(DATA / 'edificios.json', 'Ejecute: make edificios')))   # los edificios de OSM (ED)
    geo['golf'] = json.load(open(require(DATA / 'golf.json', 'Ejecute: make golf')))   # el pasto y las copas del Talca Country Club (pipeline/golf.py)
    pois = json.load(open(require(DATA / 'pois.json', 'Ejecute: make pois')))
    t = template()
    assert '/*DATA*/' in t and '/*POIS*/' in t, 'faltan los marcadores en la plantilla'
    js = lambda o: json.dumps(o, separators=(',', ':'), ensure_ascii=False).replace('</', '<\\/')
    out = t.replace('/*DATA*/', js(geo)).replace('/*POIS*/', js(pois))
    (ROOT / 'dist').mkdir(exist_ok=True)
    (ROOT / 'dist' / 'talca.html').write_text(out.replace(POSTER_MARK, ''))
    print('dist/talca.html:', len(out.encode()), 'bytes')
    if '--standalone' in sys.argv:
        # the fragment's own <title> and description stay in it for the artifact; here the <head> has them: the lines
        # are emptied, not removed, so --where still counts right
        body = re.sub(r'^<title>.*</title>$|^<meta name="description"[^\n]*>$', '', out, count=2, flags=re.M)
        page = STANDALONE + body.replace(POSTER_MARK, poster()) + '\n</body></html>\n'
        (ROOT / 'dist' / 'index.html').write_text(page); print('dist/index.html:', len(page.encode()), 'bytes')
        for f in sorted((SRC / 'site').iterdir()): shutil.copy(f, ROOT / 'dist' / f.name)

if __name__ == '__main__':
    main()
