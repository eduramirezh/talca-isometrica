"""Revisión rápida del repo (menos de un segundo): la corre `make check`, y el hook de pre-commit (`make hooks`).

  python tools/check.py            # config/, data/, los fuentes de src/ y dist/ (make build)
  python tools/check.py --no-dist  # sin dist/ (antes de make build)

Comprueba:
  - que todos los JSON de config/ y data/ se lean;
  - que src/page.html tenga los marcadores /*STYLE*/, /*DATA*/ y <!--SCRIPTS--> una sola vez y que los bloques
    `// ==== hito:` no repitan id; que cada archivo de src/js/hitos/ esté en su ORDER, empiece con su línea
    `// ==== hito: <id> ====` y no tenga otra, y que cada fuente termine en un salto de línea;
  - que data/pois.json tenga ids únicos y que cada recorrido apunte a lugares que existen;
  - que el script de dist/assets/ compile (node --check; el error da el archivo de src/ y la línea, con build.where()),
    que cada archivo que pide dist/index.html (src, href, srcset y lo que pide desde JS en assets/) exista en dist/, y que
    dist/assets/ no tenga otros.
Termina con código 1 y una línea por falla. No reemplaza a `make smoke` (carga la página en Chromium y revisa la
generación) ni a `python pipeline/usos.py check` (14 s; avisos sobre los usos de suelo).
"""
import json, re, shutil, subprocess, sys, time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / 'pipeline'))
import build
SRC_PAGE = build.SRC / 'page.html'

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
            elif not node: fail('node no está en el PATH: hace falta para node --check (nodenv / brew install node)')
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

    for m in bad: print('FALLA:', m)
    print(f'check: {len(bad)} fallas' if bad else f'check: ok ({(time.time()-t0)*1000:.0f} ms)')
    return 1 if bad else 0

if __name__ == '__main__':
    if '-h' in sys.argv or '--help' in sys.argv: raise SystemExit(__doc__)
    sys.exit(main(dist='--no-dist' not in sys.argv))
