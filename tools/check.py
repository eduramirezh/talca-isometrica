"""Revisión rápida del repo (menos de un segundo): la corre `make check`, y el hook de pre-commit (`make hooks`).

  python tools/check.py            # config/, data/, los fuentes de src/ y dist/talca.html (make build)
  python tools/check.py --no-dist  # sin dist/ (antes de make build)

Comprueba:
  - que todos los JSON de config/ y data/ se lean;
  - que la plantilla (src/, unida por pipeline/build.py) tenga los marcadores /*DATA*/ y /*POIS*/ una sola vez y que
    los bloques `// ==== hito:` no repitan id; que cada archivo de src/js/hitos/ esté en su ORDER, empiece con su
    línea `// ==== hito: <id> ====` y no tenga otra, y que cada fuente termine en un salto de línea;
  - las restricciones de los artifacts de Claude: scripts solo de cdnjs, jsdelivr o unpkg; estilos solo de Google Fonts;
    sin fetch, alert, confirm ni prompt;
  - que data/pois.json tenga ids únicos y que cada recorrido apunte a lugares que existen;
  - que cada script de dist/talca.html compile (node --check) y que la página pese menos de 16 MB.
Termina con código 1 y una línea por falla. No reemplaza a `make smoke` (carga la página en Chromium y revisa la
generación) ni a `python pipeline/usos.py check` (14 s; avisos sobre los usos de suelo).
"""
import json, re, shutil, subprocess, sys, tempfile, time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / 'pipeline'))
import build
SCRIPT_HOSTS = ('https://cdnjs.cloudflare.com/', 'https://cdn.jsdelivr.net/npm/', 'https://unpkg.com/')
STYLE_HOSTS = ('https://fonts.googleapis.com', 'https://fonts.gstatic.com')
MAX_BYTES = 16 * 1024 * 1024

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
    try: tpl = build.template()
    except (AssertionError, OSError) as e: fail(f'src/: no se pudo unir la plantilla: {e}'); tpl = None
    for m in ('/*DATA*/', '/*POIS*/') if tpl is not None else ():
        if tpl.count(m) != 1: fail(f'src/: el marcador {m} aparece {tpl.count(m)} veces (debe ser 1)')
    hitos = re.findall(r'// ==== hito: ([\w-]+) ====', tpl or '')
    for h in sorted({h for h in hitos if hitos.count(h) > 1}): fail(f'src/: bloque de hito repetido: {h}')
    for f in build.sources():
        if not f.exists(): continue
        t, name = f.read_text(), f.relative_to(ROOT)
        if not t.endswith('\n'): fail(f'{name}: no termina en un salto de línea (build.py lo pegaría al siguiente)')
        for src in re.findall(r'<script[^>]*\ssrc="([^"]+)"', t):
            if not src.startswith(SCRIPT_HOSTS): fail(f'{name}: script fuera de cdnjs/jsdelivr/unpkg: {src}')
        for href in re.findall(r'<link[^>]*\shref="([^"]+)"', t):
            if not href.startswith(STYLE_HOSTS): fail(f'{name}: enlace fuera de Google Fonts: {href}')
        for fn in ('fetch', 'alert', 'confirm', 'prompt'):
            for m in re.finditer(rf'(?<![\w.$]){fn}\(', t):
                fail(f'{name}:{t.count(chr(10), 0, m.start()) + 1}: {fn}() no está permitido en un artifact')

    pois = json.load(open(ROOT / 'data' / 'pois.json'))
    ids = [p['id'] for p in pois['pois']]
    for i in sorted({i for i in ids if ids.count(i) > 1}): fail(f'data/pois.json: id repetido: {i}')
    for k, t in pois['tours'].items():
        for s in t['s']:
            if s not in ids: fail(f'data/pois.json: el recorrido {k} apunta a un lugar que no existe: {s}')

    if dist:
        page = ROOT / 'dist' / 'talca.html'
        if not page.exists(): fail('dist/talca.html no existe (make build)')
        else:
            html = page.read_text()
            if len(html.encode()) > MAX_BYTES: fail(f'dist/talca.html pesa {len(html.encode())/2**20:.1f} MB (máximo 16)')
            node = shutil.which('node')
            if not node: fail('node no está en el PATH: hace falta para node --check (nodenv / brew install node)')
            else:
                for n, js in enumerate(re.findall(r'<script>(.*?)</script>', html, re.S), 1):
                    with tempfile.NamedTemporaryFile('w', suffix='.js', delete=False) as f: f.write(js); tmp = f.name
                    r = subprocess.run([node, '--check', tmp], capture_output=True, text=True); Path(tmp).unlink()
                    if r.returncode:
                        err = next((l for l in r.stderr.splitlines() if 'Error' in l), r.stderr.strip())
                        where = re.search(r':(\d+)\n', r.stderr)
                        fail(f'dist/talca.html: el script {n} no compila' + (f' (línea {where.group(1)} del script)' if where else '') + f': {err}')

    for m in bad: print('FALLA:', m)
    print(f'check: {len(bad)} fallas' if bad else f'check: ok ({(time.time()-t0)*1000:.0f} ms)')
    return 1 if bad else 0

if __name__ == '__main__':
    if '-h' in sys.argv or '--help' in sys.argv: raise SystemExit(__doc__)
    sys.exit(main(dist='--no-dist' not in sys.argv))
