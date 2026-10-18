"""Arma el sitio (talca.eduramirez.com) en dist/: la página (src/page.html, con src/style.css en línea), el script
(src/js/, ver script_pieces()) en su propio archivo, three.js y los datos, con un hash de su contenido en el nombre
(dist/assets/), y los archivos de src/site/ (ícono, imagen de Open Graph, pósters, _headers).

Los datos son data/geometry.json (más config/usos.json como `usos`; config/manzanas.json reclasifica como construidas,
tipo 3, manzanas «sin información» del Censo, y las entradas `vivienda` de los usos agregan manzanas construidas donde el
Censo no tiene), data/elevation.json, data/ruta5.json, data/edificios.json, data/golf.json y data/pois.json: un archivo
cada uno, que la página pide con fetch apenas empieza (src/page.html, el marcador /*DATA*/) y el script espera
(src/js/00-start.js). Con el hash en el nombre se guardan en la caché del navegador sin fecha de vencimiento
(src/site/_headers): un cambio del código no vuelve a bajar los datos, ni al revés.

  python pipeline/build.py                       -> dist/index.html, dist/assets/, los archivos de src/site/
  python pipeline/build.py --where app.js:4026   -> el archivo de src/ y la línea que dan esa línea del script
                                                    (app.<hash>.js:N como en la consola del navegador, o solo N);
                                                    index.html:N o (index):N para una línea de la página
"""
import hashlib, json, re, shutil, sys
from common import ROOT, DATA, CONFIG, require, loc

SRC = ROOT / 'src'
DIST = ROOT / 'dist'
THREE = ROOT / 'node_modules' / 'three' / 'build' / 'three.min.js'   # r128, fijado en package.json (npm install)

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

def page_pieces():
    """The page as [(source file, its first line, text)], in order: src/page.html with src/style.css at /*STYLE*/."""
    (a, page0), (b, page1) = cut(SRC / 'page.html', '/*STYLE*/')
    return [(SRC / 'page.html', a, page0), (SRC / 'style.css', 1, (SRC / 'style.css').read_text()), (SRC / 'page.html', b, page1)]

def script_pieces():
    """The script as [(source file, its first line, text)]: the files src/js/*.js in the order of their names;
    src/js/45-landmarks.js holds /*HITOS*/ inside buildModels(B,S), where the landmarks src/js/hitos/<id>.js go in the
    order of hitos/ORDER. Each piece comes after a line `// ---- src/js/<file>[:line] ----` (its first line is 0), so
    that the browser's sources show where the code comes from."""
    def js(f, a, text, ind=''):
        return [(f, 0, f'{ind}// ---- {f.relative_to(ROOT)}{f":{a}" if a > 1 else ""} ----\n'), (f, a, text)]
    out = []
    for f in sorted((SRC / 'js').glob('*.js')):
        if f.name != '45-landmarks.js': out += js(f, 1, f.read_text()); continue
        (a, head), (b, tail) = cut(f, '/*HITOS*/')
        out += js(f, a, head)
        for h in hito_ids(): out += js(SRC / 'js' / 'hitos' / f'{h}.js', 1, (SRC / 'js' / 'hitos' / f'{h}.js').read_text(), '  ')
        out += js(f, b, tail, '  ')
    return out

def page():
    """The page's HTML, before build.py fills its markers (/*DATA*/, <!--SCRIPTS-->)."""
    return ''.join(t for _, _, t in page_pieces())

def script():
    """The script, one file (dist/assets/app.<hash>.js): a single function that the files of src/js/ open and close."""
    return ''.join(t for _, _, t in script_pieces())

def where(line, pieces=script_pieces):
    """A line of the script (or of the page, with pieces=page_pieces: the markers that build.py fills take one line)
    -> (source file relative to ROOT, its line; 0 for the `// ---- <file> ----` line before it)."""
    n = 1
    for f, a, t in pieces():
        k = t.count('\n')
        if line < n + k: return f.relative_to(ROOT), a + line - n
        n += k
    raise ValueError(f'tiene {n - 1} líneas: no hay línea {line}')

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

def cmd_where(arg):
    """`--where 4021`, `--where app.js:4021` or `--where app.3fa2c1d4e5.js:4021` (as the browser's console gives it), a
    line of the script; `--where index.html:120` or `(index):120`, a line of the page: the source file and line."""
    f, _, n = arg.rpartition(':'); n = int(n)
    src, k = where(n, page_pieces if 'index' in f else script_pieces)
    if not k: return print(f'{src}: la línea `// ---- … ----` que build.py pone antes de un trozo de ese archivo')
    print(f'{src}:{k}'); print((ROOT / src).read_text().split('\n')[k-1][:160])

def asset(name, data):
    """dist/assets/<name>.<hash of data>.<ext> -> its path relative to dist/ (as the page asks for it)."""
    stem, ext = name.rsplit('.', 1)
    f = DIST / 'assets' / f'{stem}.{hashlib.sha256(data).hexdigest()[:10]}.{ext}'
    f.write_bytes(data); return f.relative_to(DIST).as_posix()

def main():
    if '--where' in sys.argv: return cmd_where(sys.argv[sys.argv.index('--where') + 1])
    geo = json.load(open(require(DATA / 'geometry.json', 'Ejecute: make data')))
    mark_built(geo['blocks'])
    land_uses(geo)
    files = {'geo': ('geometry.json', geo),
             'elev': ('elevation.json', json.load(open(require(DATA / 'elevation.json', 'Ejecute: make elevation')))),
             'r5': ('ruta5.json', json.load(open(require(DATA / 'ruta5.json', 'Ejecute: make ruta5')))),   # las calzadas y ramales de la Ruta 5 (R5)
             'ed': ('edificios.json', json.load(open(require(DATA / 'edificios.json', 'Ejecute: make edificios')))),   # los edificios de OSM (ED)
             'golf': ('golf.json', json.load(open(require(DATA / 'golf.json', 'Ejecute: make golf')))),   # el pasto y las copas del Talca Country Club (pipeline/golf.py)
             'pois': ('pois.json', json.load(open(require(DATA / 'pois.json', 'Ejecute: make pois'))))}
    require(THREE, 'Ejecute: npm install')
    # dist/assets/ only holds this build's files; the rest of dist/ is overwritten (make serve may be serving it)
    shutil.rmtree(DIST / 'assets', ignore_errors=True); (DIST / 'assets').mkdir(parents=True)
    (DIST / 'talca.html').unlink(missing_ok=True)   # the old fragment for Claude's artifacts (until October 2026)
    dump = lambda o: json.dumps(o, separators=(',', ':'), ensure_ascii=False).encode()
    urls = {k: asset(name, dump(o)) for k, (name, o) in files.items()}
    three, app = asset('three-r128.js', THREE.read_bytes()), asset('app.js', script().encode())
    t = page()
    for m in ('/*DATA*/', '<!--SCRIPTS-->'): assert t.count(m) == 1, f'src/page.html: el marcador {m} debe aparecer una vez'
    html = (t.replace('/*DATA*/', json.dumps(urls))
             .replace('<!--SCRIPTS-->', '<script>window.__go.then(()=>{for(const u of %s){const s=document.createElement("script");'
                      's.src=u;s.async=false;document.body.append(s);}});</script>' % json.dumps([three, app])))
    (DIST / 'index.html').write_text(html)
    for f in sorted((SRC / 'site').iterdir()): shutil.copy(f, DIST / f.name)
    size = lambda u: (DIST / u).stat().st_size
    print('dist/index.html:', len(html.encode()), 'bytes;', ', '.join(f'{u.split("/")[-1]}: {size(u)}' for u in [app, three, *urls.values()]))

if __name__ == '__main__':
    main()
