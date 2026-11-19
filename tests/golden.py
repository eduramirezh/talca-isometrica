"""The pipeline's outputs before and after a change that must not change them (a refactor of pipeline/): every
generator that runs without the network (it reads raw/, the caches included) and every report command, with what
each prints and the files it writes, compared byte for byte.

  python3 tests/golden.py --save shots/golden-ref            # before: run every command, keep its output
  python3 tests/golden.py --against shots/golden-ref         # after: run them again, list what changed (exit 1)
  python3 tests/golden.py --against shots/golden-ref usos    # only the commands whose name contains «usos»
  python3 tests/golden.py --list                             # the commands

Each command runs from pipeline/ (the Pillow ones with `uv run --with pillow`); the files it writes are copied
aside first and put back after it, so that a generator that differs does not feed the next command, and the working
tree ends as it began. A line that holds a time in ms or s is compared without the number. Needs raw/ (make fetch
and the caches: Esri tiles, raw/osm/, raw/cl/, raw/edificios-ml/); a command whose input is missing fails in both
runs alike. ~4 min.
"""
import hashlib, json, re, shutil, subprocess, sys, tempfile, time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PY = [sys.executable]
PILLOW = re.search(r'^pillow==\S+', (ROOT / 'requirements.txt').read_text(), re.M).group(0)   # the pinned version
PIL = ['uv', 'run', '--offline', '-q', '--with', PILLOW, 'python']   # --offline: Pillow from uv's cache (resolving online took minutes)

# (name, argv run from pipeline/, files it writes relative to ROOT)
CMDS = [
    ('process_geometry', PY + ['process_geometry.py'], ['data/geometry.json']),
    ('elevation', PY + ['elevation.py', 'stats'], ['data/elevation.json']),
    ('ruta5', PY + ['traces.py', 'calzadas', 'comuna'], ['data/ruta5.json']),
    ('pois', PY + ['pois.py'], ['data/pois.json', 'data/pois.csv']),
    ('edificios', PY + ['edificios.py'], ['data/edificios.json']),
    ('edificios-solo-osm', PY + ['edificios.py', 'solo-osm'], ['data/edificios.json']),
    ('edificios-manzanas', PY + ['edificios.py', 'manzanas', '20'], []),
    ('golf', PIL + ['golf.py'], ['data/golf.json']),
    ('cobertura', PY + ['-I', 'cobertura.py'], ['data/cobertura.json']),
    ('cobertura-stats', PY + ['-I', 'cobertura.py', 'stats'], []),
    ('railway-write', PY + ['railway.py', 'write', 'comuna'], ['config/trazados.json']),
    ('railway-check', PY + ['railway.py', 'check', 'comuna'], []),
    ('usos-check', PY + ['usos.py', 'check'], []),
    ('usos-importar-ciren', PY + ['-I', 'usos.py', 'importar', 'ciren'], ['config/usos-ciren.json', 'config/usos.json']),
    ('usos-importar-censo2024', PY + ['-I', 'usos.py', 'importar', 'censo2024'], ['config/usos-censo2024.json', 'config/usos.json']),
    ('usos-importar-areasverdes', PY + ['-I', 'usos.py', 'importar', 'areasverdes'], ['config/usos-minvu.json', 'config/usos.json']),
    ('usos-blancos', PY + ['usos.py', 'blancos', '0.5', '--osm', 'comuna'], []),
    ('usos-survey', PY + ['usos.py', 'survey', 'todo', '-1000', '1000', '-1000', '1000'], []),
    ('usos-osm', PY + ['usos.py', 'osm', 'comuna', 'w101587762', '--eps', '2'], []),
    ('usos-salud', PY + ['-I', 'usos.py', 'salud'], []),
    ('rutas-check', PY + ['-I', 'rutas.py', 'check'], []),
    ('traces-cruces', PY + ['traces.py', 'cruces', 'comuna'], []),
    ('traces-check', PY + ['traces.py', 'check', 'piduco', '--map', 'comuna'], []),
    ('traces-line', PY + ['traces.py', 'line', 'comuna', 'railway=^rail$', 'usage=^main$', '--eps', '1.5'], []),
    ('geocode-validate', PY + ['geocode.py', 'validate'], []),
    ('geocode-lines', PY + ['geocode.py', 'lines'], []),
    ('geocode-address', PY + ['geocode.py', 'address', '2 Norte 781'], []),
    ('grilla', PY + ['-I', 'grilla.py', '../raw/cicloconecta/data/cities/talca/nav_graph.json', '-35.42653', '-71.66600'], []),
    ('fuentes-info', PY + ['-I', 'fuentes_cl.py', 'info'], []),
    ('wikidata-check', PY + ['wikidata.py', 'check'], []),
    ('landmark-frame', PY + ['landmark.py', 'frame', 'estadio', '89069046'], []),
    ('geotiff-info', PY + ['-I', 'geotiff.py', 'info', '../raw/dem/copernicus/Copernicus_DSM_COG_10_S36_00_W072_00_DEM.tif'], []),
    ('build', PY + ['build.py'], []),
    ('build-where', PY + ['build.py', '--where', 'app.js:4026'], []),
    # Pillow: the panels (PNG), from cached tiles
    ('landmark-osm', PIL + ['landmark.py', 'osm', 'estadio', '250'], ['diagnostics/plan-estadio.png']),
    ('satellite-punto', PIL + ['satellite.py', 'punto', '0', '0', '400', '17', '--calles'], ['diagnostics/sat-0_0.png']),
    ('satellite-lugar', PIL + ['satellite.py', 'estadio', '400'], ['diagnostics/sat-estadio.png']),
    ('traces-panel', PIL + ['traces.py', 'panel', 'claro', '-900', '-300', '-700', '-100', '17'], ['diagnostics/traza-claro--900_-700.png']),
    ('traces-vial', PIL + ['traces.py', 'vial', '2200', '2700', '-300', '200', '17', 'comuna'], ['diagnostics/vial-2200_-300.png']),
    ('edificios-panel', PIL + ['edificios.py', 'panel', '-300', '300', '-300', '300', '17'], ['diagnostics/edificios.png']),
    ('edificios-techos', PIL + ['edificios.py', 'techos', '19'], ['config/techos.json']),
    ('golf-panel', PIL + ['golf.py', 'panel'], ['diagnostics/golf-clases.png']),
    ('fuentes-panel', PIL + ['-I', 'fuentes_cl.py', 'panel', 'conaf', '5295', '3596', '800', '15'], ['diagnostics/cl-conaf-5295_3596.png']),
]

TIME = re.compile(r'\d+(?:[.,]\d+)?\s*(?:ms|s)\b')

def norm(text):
    """The output without times (`(178 ms)`, `2.1 s`) and without uv's own lines."""
    return '\n'.join(TIME.sub('<t>', l) for l in text.splitlines() if not l.startswith(('Installed ', 'Resolved ', 'Prepared ', 'Audited ')))

def run(name, argv, files):
    """Run one command with its files set aside: (output, {file: sha256 or None}, seconds)."""
    keep = tempfile.mkdtemp()
    saved = {f: (ROOT / f).exists() and shutil.copy2(ROOT / f, Path(keep) / f.replace('/', '__')) for f in files}
    for f in files:   # a panel that is not written must not pass as unchanged
        if f.startswith('diagnostics/'): (ROOT / f).unlink(missing_ok=True)
    t = time.time()
    r = subprocess.run(argv, cwd=ROOT / 'pipeline', capture_output=True, text=True)
    dt = time.time() - t
    out = f'exit {r.returncode}\n--- stdout\n{norm(r.stdout)}\n--- stderr\n{norm(r.stderr)}\n'
    got = {}
    for f in files:
        p = ROOT / f
        got[f] = hashlib.sha256(p.read_bytes()).hexdigest() if p.exists() else None
        if got[f]: shutil.copy2(p, Path(keep) / ('new__' + f.replace('/', '__')))
        if saved[f]: shutil.copy2(saved[f], p)
        elif p.exists() and not f.startswith('diagnostics/'): p.unlink()
    return out, got, dt, keep

def main(a):
    if '--list' in a:
        for n, argv, files in CMDS: print(f"{n:28} {' '.join(argv[len(PIL) if argv[:2] == PIL[:2] else 1:])}  -> {', '.join(files) or '-'}")
        return 0
    mode = next((m for m in ('--save', '--against') if m in a), None)
    if not mode or a.index(mode) + 1 >= len(a): raise SystemExit(__doc__)
    ref = Path(a[a.index(mode) + 1]); only = [x for x in a if not x.startswith('--') and x != str(ref)]
    cmds = [c for c in CMDS if not only or any(o in c[0] for o in only)]
    if mode == '--save': ref.mkdir(parents=True, exist_ok=True)
    elif not (ref / 'golden.json').exists(): raise SystemExit(f'{ref}/golden.json no existe: corra antes --save {ref}')
    db = json.loads((ref / 'golden.json').read_text()) if (ref / 'golden.json').exists() else {}
    bad = 0
    for name, argv, files in cmds:
        out, got, dt, keep = run(name, argv, files)
        if mode == '--save':
            (ref / f'{name}.txt').write_text(out); db[name] = got
            for f, h in got.items():
                if h: shutil.copy2(Path(keep) / ('new__' + f.replace('/', '__')), ref / f'{name}__{Path(f).name}')
            print(f'{name:28} {dt:6.1f} s  {out.splitlines()[0]}  {sum(1 for h in got.values() if h)} archivos')
        else:
            was = (ref / f'{name}.txt').read_text() if (ref / f'{name}.txt').exists() else None
            diff = [f for f in files if db.get(name, {}).get(f) != got[f]]
            same = out == was
            if not same:
                (ref / f'{name}.nuevo.txt').write_text(out)
            for f in diff:
                if got[f]: shutil.copy2(Path(keep) / ('new__' + f.replace('/', '__')), ref / f'{name}__nuevo__{Path(f).name}')
            ok = same and not diff
            bad += not ok
            print(f'{name:28} {dt:6.1f} s  ' + ('igual' if ok else 'DISTINTO: ' + ', '.join((['salida (diff ' + str(ref / f'{name}.txt') + ' ' + str(ref / f'{name}.nuevo.txt') + ')'] if not same else []) + diff)))
        shutil.rmtree(keep, ignore_errors=True)
    if mode == '--save': (ref / 'golden.json').write_text(json.dumps(db, indent=1, sort_keys=True))
    else: print(f'\n{bad} comandos distintos' if bad else '\ntodos iguales')
    return 1 if bad else 0

if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
