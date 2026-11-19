"""Revisión rápida del repo (menos de un segundo): la corre `make check`, y el hook de pre-commit (`make hooks`).

  python tools/check.py            # config/, data/, los fuentes de src/ y dist/ (make build)
  python tools/check.py --no-dist  # sin dist/ (antes de make build)

Comprueba:
  - que todos los JSON de config/ y data/ se lean;
  - que src/page.html tenga los marcadores /*STYLE*/, /*DATA*/ y <!--SCRIPTS--> una sola vez y que los bloques
    `// ==== hito:` no repitan id; que cada archivo de src/js/hitos/ esté en su ORDER, empiece con su línea
    `// ==== hito: <id> ====` y no tenga otra, y que cada fuente termine en un salto de línea;
  - que un hito no use un nombre que declara otro (lo que comparten va en la cabecera de buildModels) ni lea
    MODELS['<id>'] antes del hito que lo pone (hitos_deps());
  - que las capas planas que se tocan (Y_OVER de src/js/30-geometry.js) queden separadas al menos Y_STEP (layer_heights);
  - que las secciones del script empiecen con «// ==== nombre ====» (section_headers);
  - que src/style.css no tenga colores fijos fuera de los tokens y que sus dos bloques oscuros coincidan (css_tokens);
  - que las dependencias tengan versiones fijas: == en requirements*.txt, iguales en los encabezados PEP 723 de tools/ y
    pipeline/, y exactas en package.json y scripts/deploy/package.json, como las resuelve su package-lock.json (pins);
  - que data/pois.json tenga ids únicos y que cada recorrido apunte a lugares que existen;
  - que lo que el juego y tools/ copian de la página siga igual (juego_contratos: el contorno y los prados de la plaza,
    LEJOS, config/fachadas.json, data/plaza-osm.json, las fórmulas del relieve de tools/relieve.py);
  - que el script de dist/assets/ compile (node --check; el error da el archivo de src/ y la línea, con build.where()),
    que cada archivo que pide dist/index.html (src, href, srcset y lo que pide desde JS en assets/) exista en dist/, y que
    dist/assets/ no tenga otros;
  - trampas de config/ y data/ (PIPELINE, al final): que la manzana `bi` de cada entrada de usos contenga su `bc`
    (usos_bi), que ninguna entrada de usos que ya estaba en HEAD haya cambiado de lugar (usos_order; a propósito:
    TALCA_USOS_ORDEN=ok) y que cada calle que cruza la vía tenga su entrada en railx y al revés (railx).
Termina con código 1 y una línea por falla. No reemplaza a `make smoke` (carga la página en Chromium y revisa la
generación) ni a `python pipeline/usos.py check` (~8 s; avisos sobre los usos de suelo). `make check` corre además las
pruebas de tests/ y compileall.
"""
import json, re, shutil, subprocess, sys, time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / 'pipeline'))
import build
SRC_PAGE = build.SRC / 'page.html'

def js_depth(t):
    """For each character of JavaScript text t, the nesting depth of (), [] and {} it is at, and whether it is code
    (not inside a string, a template, a comment or a regex literal); a light scanner, enough for src/js/hitos/."""
    depth, code, d, i, n = [0] * len(t), [False] * len(t), 0, 0, len(t)
    prev = ''  # the last code character that is not a space: a / after it starts a regex literal or divides
    while i < n:
        c = t[i]
        if c in '"\'`' or t.startswith('//', i) or t.startswith('/*', i) or (c == '/' and prev not in ')]}' and not (prev.isalnum() or prev in '_$')):
            if t.startswith('//', i): j = t.find('\n', i); j = n if j < 0 else j
            elif t.startswith('/*', i): j = t.find('*/', i + 2) + 2
            else:
                j, end = i + 1, c
                while j < n and t[j] != end:
                    if t[j] == '\\': j += 1
                    elif end == '/' and t[j] == '[':  # a character class may hold a /
                        while j < n and t[j] != ']': j += 2 if t[j] == '\\' else 1
                    j += 1
                j += 1
            for k in range(i, min(j, n)): depth[k] = d
            i = j; continue
        if c in ')]}': d -= 1
        depth[i], code[i] = d, True
        if c in '([{': d += 1
        if not c.isspace(): prev = c
        i += 1
    return depth, code, d

def hitos_deps(fail):
    """The landmarks share nothing among themselves: build.py pastes them one after another into buildModels, so a
    name one of them declares at its top level (a const, a let, a function) exists only for the code after it, and a
    landmark that uses another's name depends on their order in ORDER, which nothing says (a mistake is a
    ReferenceError that only make smoke sees). What they share goes in the header of buildModels (src/js/45-landmarks.js).
    So: a landmark may not use a name another one declares at its top level, and MODELS['<id>'] may be read only by the
    landmarks after the one that sets it."""
    order = build.hito_ids(); hdir = build.SRC / 'js' / 'hitos'
    files = {h: (hdir / f'{h}.js').read_text() for h in order if (hdir / f'{h}.js').exists()}
    decl, scans = {}, {}
    for h, t in files.items():
        depth, code, end = js_depth(t); scans[h] = (depth, code)
        if end: fail(f'src/js/hitos/{h}.js: los paréntesis o llaves no cierran ({end:+d}): no se pudo revisar'); continue
        for m in re.finditer(r'\b(?:const|let|var|function)\s+([A-Za-z_$][\w$]*)', t):
            if code[m.start()] and depth[m.start()] == 0: decl.setdefault(m.group(1), (h, t.count('\n', 0, m.start()) + 1))
            # the other declarators of the same statement: `, name =` at depth 0
            if code[m.start()] and depth[m.start()] == 0 and m.group(0).startswith(('const', 'let', 'var')):
                j = m.end()
                while j < len(t) and not (code[j] and depth[j] == 0 and t[j] == ';'):
                    if code[j] and depth[j] == 0 and t[j] == ',':
                        k = re.match(r',\s*([A-Za-z_$][\w$]*)\s*=', t[j:])
                        if k: decl.setdefault(k.group(1), (h, t.count('\n', 0, j) + 1))
                    j += 1
    pos = {h: i for i, h in enumerate(order)}
    for h, t in files.items():
        if h not in scans: continue
        depth, code = scans[h]
        for name, (dh, dl) in decl.items():
            if dh == h or re.search(rf'\b(?:const|let|var|function)\s+{re.escape(name)}\b', t): continue
            for m in re.finditer(rf'(?<![\w$.]){re.escape(name)}(?![\w$])', t):
                if not code[m.start()] or re.match(r'\s*:', t[m.end():]): continue  # a string, a comment or an object key
                fail(f'src/js/hitos/{h}.js:{t.count(chr(10), 0, m.start()) + 1}: usa {name}, que declara src/js/hitos/{dh}.js:{dl} '
                     f'({"más abajo en ORDER: sería un ReferenceError" if pos[dh] > pos[h] else "otro hito"}); lo que comparten los hitos va en la cabecera de buildModels (src/js/45-landmarks.js)')
                break
    sets = {}
    for h, t in files.items():
        for m in re.finditer(r"MODELS\[['\"]([\w-]+)['\"]\]\s*=(?!=)", t): sets.setdefault(m.group(1), h)
    for h, t in files.items():
        for m in re.finditer(r"MODELS\[['\"]([\w-]+)['\"]\](?!\s*=(?!=))", t):
            s = sets.get(m.group(1))
            if s and s != h and pos[s] > pos[h]:
                fail(f'src/js/hitos/{h}.js:{t.count(chr(10), 0, m.start()) + 1}: lee MODELS[\'{m.group(1)}\'], que src/js/hitos/{s}.js pone más abajo en ORDER (todavía no existe)')
# ---- calidad-tools: the game and the tools against the page (juego/, tools/) ----
HEX = re.compile(r'[0-9a-fA-F]{6}')
# config/fachadas.json: each key of an entry and its value (juego/modelos/fachadas.gd spec(), CLAVES; build.py FACHADA)
FACHADAS = {'estilo': {'comercial', 'clasico', 'deco', 'torre', 'moderno', 'colonial', 'intendencia', 'municipal', 'vidrio'},
            'pb': {'vitrinas', 'ventanas', 'vidrio'}, 'techo': {'plano', 'teja'}, 'pisos': int, 'alto': float,
            'zocalo_alto': float, 'bahia': float, 'corte_y': float, 'alto_basamento': float, 'fronton': bool,
            'pilastras': bool, 'color': 'hex', 'zocalo': 'hex', 'toldo': 'hex', 'marco': 'hex', 'friso': str,
            'letreros': 'letreros'}

def _nums(text, name, src):
    """The numbers of the array literal `name` (GDScript `const name := [...]`, JS `const name=[...]` or `=f([...])`)."""
    m = re.search(r'\b' + name + r'\s*:?=\s*(?:\w+\()?\[([^\[\]]*)\]', text)
    if not m: raise ValueError(f'{src}: no encuentro {name}')
    return [float(x) for x in re.findall(r'-?\d+(?:\.\d+)?', m.group(1))]

def juego_contratos(fail):
    """What the game (juego/) and the tools copy from the page, compared with it: the plaza's outline and lawns, how
    far the street models go, config/fachadas.json and data/plaza-osm.json, and the relief formulas of tools/relieve.py."""
    js = lambda f: (ROOT / 'src' / 'js' / 'hitos' / f).read_text()
    gd = lambda f: (ROOT / 'juego' / f).read_text()
    try:
        hito, plano, plaza = js('plaza-de-armas.js'), gd('modelos/entorno/plano.gd'), gd('modelos/plaza.gd')
        if _nums(plano, 'PZ', 'plano.gd') != _nums(hito, 'PZ', 'plaza-de-armas.js'):
            fail('juego/modelos/entorno/plano.gd: PZ no es el contorno PZ de src/js/hitos/plaza-de-armas.js')
        lawns = re.search(r'const LAWNS=\[(\[.*?\])\]', hito, re.S).group(1)
        prados = re.search(r'const PRADOS := \[(.*?)\]\]', plaza, re.S).group(1)
        n = lambda t: [float(x) for x in re.findall(r'-?\d+(?:\.\d+)?', t)]
        if n(lawns) != n(prados): fail('juego/modelos/plaza.gd: PRADOS no son los LAWNS de src/js/hitos/plaza-de-armas.js')
        lejos = float(re.search(r'const LEJOS := ([\d.]+)', plano).group(1))
        z0 = float(re.search(r'const Z0=(\d+(?:\.\d+)?)', js('calles-plaza.js')).group(1))
        if lejos != z0: fail(f'juego/modelos/entorno/plano.gd: LEJOS = {lejos:g} y src/js/hitos/calles-plaza.js: Z0 = {z0:g} (deben ser iguales)')
    except (OSError, ValueError, AttributeError) as e: fail(f'juego/ contra los hitos: {e}')

    fach = json.load(open(ROOT / 'config' / 'fachadas.json'))
    for k, e in fach.items():
        if k.startswith('_'): continue
        if not re.fullmatch(r'w\d+', k) or not isinstance(e, dict): fail(f'config/fachadas.json: «{k}» no es w<id de OSM> con un objeto'); continue
        for c, v in e.items():
            t = FACHADAS.get(c)
            ok = (t is not None and (v in t if isinstance(t, set) else isinstance(v, str) if t is str else isinstance(v, (int, float)) and not isinstance(v, bool) if t is float
                  else isinstance(v, int) and not isinstance(v, bool) and v > 0 if t is int else isinstance(v, bool) if t is bool
                  else isinstance(v, str) and (v == '' or HEX.fullmatch(v)) if t == 'hex'
                  else isinstance(v, list) and all(isinstance(l, list) and len(l) == 3 and all(isinstance(x, str) for x in l) and HEX.fullmatch(l[1]) and HEX.fullmatch(l[2]) for l in v)))
            if t is None: fail(f'config/fachadas.json: {k}: clave desconocida «{c}» (las que hay: tools/check.py FACHADAS)')
            elif not ok: fail(f'config/fachadas.json: {k}.{c} = {v!r} no vale')
        if ('corte_y' in e) != ('alto_basamento' in e): fail(f'config/fachadas.json: {k}: corte_y y alto_basamento van juntos')

    osm = json.load(open(ROOT / 'data' / 'plaza-osm.json'))
    if set(osm) < {'caja', 'edificios', 'nodos', 'vias'}: fail(f'data/plaza-osm.json: le faltan {sorted({"caja", "edificios", "nodos", "vias"} - set(osm))}')
    for b in osm.get('edificios', []):
        if not (isinstance(b.get('id'), int) and isinstance(b.get('tags'), dict) and isinstance(b.get('anillo'), list) and len(b['anillo']) >= 3):
            fail(f'data/plaza-osm.json: edificio sin id, tags o anillo: {str(b)[:80]}'); break
    for nd in osm.get('nodos', []):
        if not ({'id', 'tipo', 'x', 'y'} <= set(nd)): fail(f'data/plaza-osm.json: nodo sin id, tipo, x o y: {nd}'); break

    try:
        sys.path.insert(0, str(ROOT / 'tools')); import relieve; relieve.formulas()
    except ValueError as e: fail(str(e))
# ---- end of calidad-tools ----

def css_tokens(fail):
    """The colours of src/style.css are tokens (CLAUDE.md, Convenciones → Tema): no colour literal outside a `--token:`
    definition, and the two dark blocks (the media query and [data-theme="dark"]) define the same tokens with the same
    values, so that the dark theme does not depend on which of the two applies."""
    css = (build.SRC / 'style.css').read_text()
    body = re.sub(r'--[\w-]+:[^;}]*', '', re.sub(r'/\*.*?\*/', '', css, flags=re.S))
    for m in re.finditer(r'#[0-9A-Fa-f]{3,8}\b|\b(?:rgba?|hsla?)\(', body):
        fail(f'src/style.css: color fijo «{m.group(0)}» fuera de un token: defínalo en :root y en los dos bloques oscuros')
    def block(start):
        i = css.find(start)
        if i < 0: return None
        i = css.index('{', i + len(start) - 1) + 1; depth = 1; j = i
        while depth:
            depth += {'{': 1, '}': -1}.get(css[j], 0); j += 1
        return dict(re.findall(r'(--[\w-]+):\s*([^;]+?)\s*;', css[i:j - 1]))
    a, b = block(':root:not([data-theme="light"])'), block(':root[data-theme="dark"]')
    if a is None or b is None: fail('src/style.css: falta uno de los dos bloques del tema oscuro'); return
    for k in sorted(set(a) | set(b)):
        if a.get(k) != b.get(k): fail(f'src/style.css: {k} difiere entre los dos bloques oscuros ({a.get(k)} / {b.get(k)})')

def section_headers(fail):
    """A section of the script starts with a line `// ==== name ====` (the hitos' `// ==== hito: <id> ====` too):
    one style, so that a search for `// ====` lists them all; the block comment /* ==== */ is not used."""
    for f in sorted((build.SRC / 'js').rglob('*.js')):
        for k, line in enumerate(f.read_text().splitlines(), 1):
            if re.match(r'\s*/\*\s*=+', line):
                fail(f'{f.relative_to(ROOT)}:{k}: encabezado de sección como /* ==== */: use una línea «// ==== nombre ====»')

def layer_heights(fail):
    """The flat layers' heights (Y_LAYER in src/js/30-geometry.js): every pair of Y_OVER, [upper, lower], is in that order
    and at least Y_STEP apart (a step of half a centimetre flickers: CLAUDE.md, «Capas planas sin explanada»);
    street_top is the top class of street (street + 7 street_step)."""
    src = (build.SRC / 'js' / '30-geometry.js').read_text()
    m = re.search(r'const Y_LAYER=\{(.*?)\};', src, re.S); s = re.search(r'Y_STEP=([\d.]+)', src); o = re.search(r'Y_OVER=\[(.*?)\];', src, re.S)
    if not (m and s and o): fail('src/js/30-geometry.js: no se encuentran Y_LAYER, Y_STEP o Y_OVER'); return
    Y = {k: float(v) for k, v in re.findall(r'(\w+):([\d.]+)', m.group(1))}
    if 'street' in Y and 'street_step' in Y: Y['street_top'] = Y['street'] + 7 * Y['street_step']
    step = float(s.group(1))
    for up, lo in re.findall(r"\['(\w+)','(\w+)'\]", o.group(1)):
        if up not in Y or lo not in Y: fail(f'src/js/30-geometry.js: Y_OVER nombra una capa que Y_LAYER no tiene: {up if up not in Y else lo}'); continue
        if Y[up] - Y[lo] < step - 1e-9:
            fail(f'src/js/30-geometry.js: la capa {up} ({Y[up]}) debe quedar al menos {step} m sobre {lo} ({Y[lo]})')

def main(dist=True):
    t0 = time.time(); bad = []
    fail = lambda m: bad.append(m)

    for f in sorted((ROOT / 'config').glob('*.json')) + sorted((ROOT / 'data').glob('*.json')):
        try: json.load(open(f))
        except ValueError as e: fail(f'{f.relative_to(ROOT)}: JSON inválido: {e}')

    order = build.hito_ids(); hdir = build.SRC / 'js' / 'hitos'
    for h in sorted({h for h in order if order.count(h) > 1}): fail(f'src/js/hitos/ORDER: hito repetido: {h}')
    for h in order:
        if not (hdir / f'{h}.js').exists(): fail(f'src/js/hitos/ORDER: no existe src/js/hitos/{h}.js')
    for f in sorted(hdir.glob('*.js')):
        if f.stem not in order: fail(f'src/js/hitos/{f.name}: no está en ORDER (build.py no lo incluye)')
        else:
            t = f.read_text()
            if not t.startswith(f'  // ==== hito: {f.stem} ====\n') or re.findall(r'// ==== hito: ([\w-]+) ====', t) != [f.stem]:
                fail(f'src/js/hitos/{f.name}: debe empezar con «  // ==== hito: {f.stem} ====» y no tener otro bloque')
    try: page, tpl = build.page(), build.script()
    except (AssertionError, OSError) as e: fail(f'src/: no se pudo unir la página o el script: {e}'); page = tpl = None
    for m in ('/*STYLE*/', '/*DATA*/', '<!--SCRIPTS-->') if page is not None else ():
        n = (SRC_PAGE.read_text() if m == '/*STYLE*/' else page).count(m)
        if n != 1: fail(f'src/page.html: el marcador {m} aparece {n} veces (debe ser 1)')
    hitos = re.findall(r'// ==== hito: ([\w-]+) ====', tpl or '')
    for h in sorted({h for h in hitos if hitos.count(h) > 1}): fail(f'src/: bloque de hito repetido: {h}')
    for f in build.sources():
        if not f.exists(): continue
        t, name = f.read_text(), f.relative_to(ROOT)
        if not t.endswith('\n'): fail(f'{name}: no termina en un salto de línea (build.py lo pegaría al siguiente)')

    css_tokens(fail); section_headers(fail); layer_heights(fail); pins(fail)

    pois = json.load(open(ROOT / 'data' / 'pois.json'))
    ids = [p['id'] for p in pois['pois']]
    for i in sorted({i for i in ids if ids.count(i) > 1}): fail(f'data/pois.json: id repetido: {i}')
    for k, t in pois['tours'].items():
        for s in t['s']:
            if s not in ids: fail(f'data/pois.json: el recorrido {k} apunta a un lugar que no existe: {s}')

    if dist:
        index = ROOT / 'dist' / 'index.html'
        if not index.exists(): fail('dist/index.html no existe (make build)')
        else:
            html = index.read_text()
            asked = set(re.findall(r'\s(?:src|href|srcset)="([^"]+)"', html))
            asked |= set(re.findall(r'"(assets/[^"]+)"', html))   # the data (/*DATA*/) and the scripts, asked for from JS
            if not re.search(r'"assets/geometry\.\w+\.json"', html): fail('dist/index.html: no pide los datos (/*DATA*/ en src/page.html)')
            local = {u.split('#')[0] for u in asked if not re.match(r'[a-z]+:|//|#', u)}
            for u in sorted(local):
                if not (ROOT / 'dist' / u).is_file(): fail(f'dist/index.html pide {u}, que no está en dist/')
            for f in sorted((ROOT / 'dist' / 'assets').glob('*')):
                if f'assets/{f.name}' not in local: fail(f'dist/assets/{f.name}: ningún archivo lo pide (¿quedó de otro build?)')
            app = [u for u in local if re.fullmatch(r'assets/app\.\w+\.js', u)]
            node = shutil.which('node')
            if len(app) != 1: fail(f'dist/index.html: debe pedir un script assets/app.<hash>.js (pide {len(app)})')
            elif not node: fail('node no está en el PATH: hace falta para node --check (nodenv / brew install node; Linux: apt install nodejs o nvm)')
            else:
                r = subprocess.run([node, '--check', str(ROOT / 'dist' / app[0])], capture_output=True, text=True)
                if r.returncode:
                    err = next((l for l in r.stderr.splitlines() if 'Error' in l), r.stderr.strip())
                    where = re.search(r':(\d+)\n', r.stderr)
                    at = ''
                    if where:
                        try: src, k = build.where(int(where.group(1))); at = f' en {src}:{k}'
                        except ValueError: at = f' (línea {where.group(1)} del script)'
                    fail(f'dist/{app[0]}: el script no compila{at}: {err}')

    for check in PIPELINE: check(fail)
    juego_contratos(fail)  # calidad-tools

    for m in bad: print('FALLA:', m)
    print(f'check: {len(bad)} fallas' if bad else f'check: ok ({(time.time()-t0)*1000:.0f} ms)')
    return 1 if bad else 0

# ---- pipeline/ and config/: traps of CLAUDE.md made into checks
def usos_bi(fail):
    """Each entry of the land-use files given by a census block (`bi`, an index into data/geometry.json) carries `bc`, a
    point inside that block when the entry was written (usos.py writes it): if the blocks change (another clip, another
    filter, trap «Los bi de config/usos.json»), the index points elsewhere and the block no longer holds bc."""
    from geom import dec, pip
    blocks = json.load(open(ROOT / 'data' / 'geometry.json'))['blocks']
    for f in build.USOS_FILES:
        if not (build.CONFIG / f).exists(): continue
        for k, u in enumerate(json.load(open(build.CONFIG / f))['usos']):
            if 'bi' not in u: continue
            where = f"config/{f}: la entrada {k} ({u['uso']} {u.get('nombre') or ''}, bi {u['bi']})".replace(' ,', ',')
            if 'bc' not in u: fail(f'{where} no tiene bc (un punto de su manzana): python pipeline/usos.py bc lo agrega'); continue
            if not (0 <= u['bi'] < len(blocks)) or not pip(u['bc'], dec(blocks[u['bi']][3])):
                fail(f"{where}: la manzana {u['bi']} de data/geometry.json ya no contiene bc {u['bc']}: cambiaron las manzanas; "
                     'busque la que lo contiene (python pipeline/usos.py bc --rehacer)')

def usos_order(fail):
    """An entry's place in DATA.usos (config/usos.json, then the files of build.USOS_FILES) seeds its drawing: an entry of
    HEAD that is still there (the same JSON) must keep its place, so that nothing goes in or out in the middle (trap «Los
    usos están en varios archivos»). Edits in place and new entries at the end pass. On purpose (an `importar` that
    rewrites a file): TALCA_USOS_ORDEN=ok. Skipped without git."""
    import collections, os
    if os.environ.get('TALCA_USOS_ORDEN') == 'ok': return
    def entries(read):
        out = []
        for f in build.USOS_FILES:
            t = read(f)
            if t: out += [(f, json.dumps(u, sort_keys=True, ensure_ascii=False)) for u in json.loads(t)['usos']]
        return out
    def head(f):
        r = subprocess.run(['git', 'show', f'HEAD:config/{f}'], cwd=ROOT, capture_output=True, text=True)
        return r.stdout if r.returncode == 0 else None
    try: old = entries(head)
    except OSError: return                                # no git
    new = entries(lambda f: (build.CONFIG / f).read_text() if (build.CONFIG / f).exists() else None)
    at = collections.defaultdict(list)
    for i, (_, u) in enumerate(new): at[u].append(i)
    moved = []
    for i, (f, u) in enumerate(old):
        if at[u]:
            j = at[u].pop(0)
            if j != i: moved.append((i, j, f, json.loads(u)))
    if moved:
        i, j, f, u = moved[0]
        fail(f"config/{f}: {len(moved)} entradas de usos cambiaron de lugar en DATA.usos (la primera, {u['uso']} «{u.get('nombre') or u.get('fuente', '')[:40]}», "
             f'de {i} a {j}): su lugar siembra su dibujo y el de todas las que siguen. Lo nuevo va al final; si es a propósito, TALCA_USOS_ORDEN=ok')

def railx(fail):
    """Every street of data/geometry.json that crosses the railway (rail, ramal) inside the commune has its entry in
    railx, and every entry its crossing (trap «Cada calle del mapa que cruza la vía está en DATA.railx»): without it the
    street crosses at grade with no barriers and the ballast lies on the asphalt. railway.py write makes them."""
    import math
    from geom import dec, crossings, in_ring
    g = json.load(open(ROOT / 'data' / 'geometry.json'))
    if 'railx' not in g: return
    lim = dec(g['limit']); used = set()
    for k, key in enumerate(('rail', 'ramal')):
        line = dec(g.get(key, [])); cell = {}
        for i in range(len(line) - 1):
            a, b = line[i], line[i+1]
            for gx in range(int(min(a[0], b[0]) // 100), int(max(a[0], b[0]) // 100) + 1):
                for gy in range(int(min(a[1], b[1]) // 100), int(max(a[1], b[1]) // 100) + 1): cell.setdefault((gx, gy), set()).add(i)
        X = [(n, x) for n, x in enumerate(g['railx']) if x[1] == k]
        for s in g['streets']:
            P = dec(s[2])
            for a, b in zip(P, P[1:]):
                near = set()
                for gx in range(int(min(a[0], b[0]) // 100), int(max(a[0], b[0]) // 100) + 1):
                    for gy in range(int(min(a[1], b[1]) // 100), int(max(a[1], b[1]) // 100) + 1): near |= cell.get((gx, gy), set())
                for i in near:
                    for p in crossings([a, b], line[i:i+2]):
                        if not in_ring(p, lim): continue
                        d, n = min(((math.dist(p, x[2:]), n) for n, x in X), default=(1e9, None))
                        if d > 3: fail(f"data/geometry.json: {g['names'][s[1]] or 'una calle'} cruza la vía ({key}) en ({p[0]:.0f}, {p[1]:.0f}) sin entrada en railx: "
                                       'python pipeline/railway.py write comuna y make data')
                        else: used.add(n)
    for n, x in enumerate(g['railx']):
        if n not in used: fail(f'data/geometry.json: la entrada {n} de railx ({x[2]}, {x[3]}) no está en el cruce de una calle con la vía: python pipeline/railway.py write comuna')

# ---- dependencies: exact versions, one source for each (Dependabot bumps requirements*.txt and the package.json files)

def pins(fail):
    """Every Python dependency is pinned with == in requirements*.txt, the same version wherever two files name it, and
    the PEP 723 headers of tools/ and pipeline/ (which Dependabot does not read) repeat those pins exactly; package.json
    (the root and scripts/deploy/) uses exact versions that its package-lock.json resolves."""
    norm = lambda n: re.sub(r'[-_.]+', '-', n).lower()
    req = {}
    for f in sorted(ROOT.glob('requirements*.txt'), key=lambda f: (f.name != 'requirements.txt', f.name)):
        for k, line in enumerate(f.read_text().splitlines(), 1):
            spec = line.split('#')[0].strip()
            if not spec: continue
            m = re.fullmatch(r'([A-Za-z0-9._-]+)==([^\s;]+)', spec)
            if not m: fail(f'{f.name}:{k}: «{spec}» no es una versión fija (paquete==versión)'); continue
            name, ver = norm(m[1]), m[2]
            if name in req and req[name][0] != ver:
                fail(f'{f.name}:{k}: {m[1]}=={ver}, pero {req[name][1]} dice {req[name][0]}')
            req.setdefault(name, (ver, f.name))
    for f in sorted((ROOT / 'tools').glob('*.py')) + sorted((ROOT / 'pipeline').glob('*.py')):
        h = re.search(r'^# /// script\n(.*?)^# ///$', f.read_text(), re.M | re.S)
        d = h and re.search(r'^# dependencies = (\[.*?\])$', h[1], re.M)
        for spec in json.loads(d[1]) if d else ():
            m = re.fullmatch(r'([A-Za-z0-9._-]+)==(\S+)', spec)
            pin = m and req.get(norm(m[1]))
            if not pin: fail(f'{f.relative_to(ROOT)}: «{spec}» no está fijo en un requirements*.txt')
            elif pin[0] != m[2]:
                fail(f'{f.relative_to(ROOT)}: {spec}, pero {pin[1]} fija {m[1]}=={pin[0]} (cambie el encabezado PEP 723)')
    for pj in (ROOT / 'package.json', ROOT / 'scripts' / 'deploy' / 'package.json'):
        name, lock = pj.relative_to(ROOT), pj.with_name('package-lock.json')
        try: deps = {k: v for s in ('dependencies', 'devDependencies') for k, v in json.load(open(pj)).get(s, {}).items()}
        except (OSError, ValueError) as e: fail(f'{name}: no se pudo leer: {e}'); continue
        try: got = json.load(open(lock)).get('packages', {})
        except (OSError, ValueError): got = None; fail(f'{lock.relative_to(ROOT)}: falta o no se lee (npm install)')
        for k, v in sorted(deps.items()):
            if not re.fullmatch(r'\d+\.\d+\.\d+', v): fail(f'{name}: {k} «{v}» no es una versión exacta (sin ^ ni ~)')
            elif got is not None and got.get(f'node_modules/{k}', {}).get('version') != v:
                fail(f'{lock.relative_to(ROOT)}: no resuelve {k} {v} (npm install --prefix {pj.parent.relative_to(ROOT)})')

PIPELINE = (usos_bi, usos_order, railx)

if __name__ == '__main__':
    if '-h' in sys.argv or '--help' in sys.argv: raise SystemExit(__doc__)
    sys.exit(main(dist='--no-dist' not in sys.argv))
