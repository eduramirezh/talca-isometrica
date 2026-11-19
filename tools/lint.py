"""ESLint sobre el script unido (make lint; make smoke lo corre antes de cargar la página).

  python3 tools/lint.py            # todos los avisos, con el archivo y la línea de src/
  python3 tools/lint.py --json     # lo mismo en JSON: [{"file", "line", "col", "rule", "msg"}]

Los src/js/*.js no son módulos sino trozos de una sola función (trampa «Un solo script en muchos archivos»): solo el
script unido (build.script(), el de dist/assets/app.<hash>.js) es JavaScript, con unos 500 nombres de primer nivel en
un ámbito. ESLint (la versión fija de package.json, en node_modules/: npm install) lo revisa con las reglas de
tools/eslint.config.mjs: no-undef, no-redeclare, no-shadow (también un nombre de primer nivel declarado después: un
`const H` dentro de una función de 50-city.js tapa el H de 86-camera.js) y no-unused-vars. Cada aviso se traduce a archivo y línea de src/ con
build.where(), como tools/check.py. Sale con 1 si hay avisos. Unos 3 s (por eso no va en make check).
"""
import json, subprocess, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / 'pipeline'))
import build

ESLINT = ROOT / 'node_modules' / '.bin' / 'eslint'   # package.json (exact version, package-lock.json)
CONFIG = ROOT / 'tools' / 'eslint.config.mjs'

def lint():
    """[(src file, line, column, rule, message)] for the joined script."""
    if not ESLINT.exists(): raise SystemExit('lint: falta node_modules/.bin/eslint: npm install (package.json lo fija)')
    r = subprocess.run([str(ESLINT), '-c', str(CONFIG), '-f', 'json', '--stdin', '--stdin-filename', 'app.js'],
                       input=build.script(), capture_output=True, text=True, cwd=ROOT)
    try: msgs = json.loads(r.stdout)[0]['messages']
    except (ValueError, IndexError, KeyError):
        raise SystemExit(f'lint: eslint no respondió (código {r.returncode}):\n{r.stderr.strip()}')
    out = []
    for m in msgs:
        try: f, k = build.where(m.get('line', 0))
        except ValueError: f, k = Path('app.js'), m.get('line', 0)
        out.append((str(f), k, m.get('column', 0), m.get('ruleId') or 'parse', m['message']))
    return out

def main():
    found = lint()
    if '--json' in sys.argv:
        print(json.dumps([dict(zip(('file', 'line', 'col', 'rule', 'msg'), a)) for a in found], ensure_ascii=False, indent=1))
    else:
        for f, k, c, rule, msg in found: print(f'{f}:{k}:{c}: {rule}: {msg}')
        print(f'lint: {len(found)} avisos' if found else 'lint: ok')
    return 1 if found else 0

if __name__ == '__main__':
    if '-h' in sys.argv or '--help' in sys.argv: raise SystemExit(__doc__)
    sys.exit(main())
