"""¿Sale el mismo mapa? Capturas de referencia y comparación píxel a píxel, para cambios que no deben cambiar la imagen.

  uv run --with "playwright==1.63" --with pillow python tools/regress.py --save shots/ref          # antes del cambio
  uv run --with "playwright==1.63" --with pillow python tools/regress.py --against shots/ref       # después
  uv run --with "playwright==1.63" --with pillow python tools/regress.py --against shots/ref --only telefono
  uv run --with "playwright==1.63" --with pillow python tools/regress.py --save shots/once --init "window.__STAGE=0"   # sin arranque progresivo
  uv run --with "playwright==1.63" --with pillow python tools/regress.py --save shots/ref --view "terminal=__look(1722,-262,16)"   # más vistas (repetible), p. ej. las de un hito nuevo

Carga el mapa en Chromium sin interfaz (SwiftShader, open_page() de screenshot.py) en dos tamaños, teléfono (390x844,
densidad 2) y escritorio (1440x900), una carga por tamaño (~1 min cada una), deja quieto un tren (__train('main',
11261): los demás se esconden y el horario se detiene) y toma las vistas de VIEWS con la cámara en lugares fijos
(no la vista inicial, para que un cambio de ella no cuente). Guarda <tamaño>-<vista>.png y stats.json: __stats sin
los tiempos (t, load y todo lo que se llame ms o termine en Ms).
Con --against compara con una referencia guardada: imprime, por vista, la parte de los píxeles distintos (un canal
por más de 8, como variants.py --diff) y deja en --out (por omisión shots/regress) las capturas nuevas y, donde
difieren, <vista>-diff.png en magenta sobre gris; luego las estadísticas que cambiaron. Sale con 1 si algo cambió.
"""
import argparse, asyncio, json, sys
from pathlib import Path
from playwright.async_api import async_playwright
from screenshot import open_page, ROOT

SIZES = {'telefono': ('390x844', 2), 'escritorio': ('1440x900', 1)}
VIEWS = ['plaza=__look(-60,30,4)', 'plaza-z14=__look(-60,30,14.2,Math.PI/4+Math.PI)', 'ciudad=__look(-60,30,1.5)',
         'comuna=__look(3000,1000,0.12)', 'estacion=(p=__train("main",11261),__look(p[0],p[1],8))',
         'oriente=__look(2600,-400,3)', 'norte=__look(800,2400,2.2,Math.PI/4+Math.PI/2)']
SETUP = '__train("main",11261)'

def clean(o):
    if isinstance(o, dict): return {k: clean(v) for k, v in o.items() if k not in ('t', 'load', 'ms') and not k.endswith('Ms')}
    return o

def flat(o, pre=''):
    if isinstance(o, dict):
        for k, v in o.items(): yield from flat(v, f'{pre}{k}.')
    else: yield pre[:-1], o

async def capture(out, only, init=None, extra=()):
    out.mkdir(parents=True, exist_ok=True); stats = {}
    async with async_playwright() as p:
        for name, (size, dpr) in SIZES.items():
            if only and name not in only: continue
            b, pg, logs = await open_page(p, size, dpr=dpr, init=init)
            stats[name] = clean(json.loads(await pg.evaluate('JSON.stringify(window.__stats)')))
            await pg.evaluate(SETUP)
            for v in [*VIEWS, *extra]:
                vn, _, js = v.partition('=')
                await pg.evaluate(js); await pg.wait_for_timeout(2500)
                await pg.screenshot(path=str(out / f'{name}-{vn}.png'))
            for l in logs:
                if l.startswith(('ERROR:', 'error:')): print(l)
            await b.close()
    (out / 'stats.json').write_text(json.dumps(stats, indent=1, ensure_ascii=False))
    return stats

def compare(ref, out):
    from PIL import Image, ImageChops
    same = True
    for f in sorted(out.glob('*.png')):
        if f.name.endswith('-diff.png'): continue
        r = ref / f.name
        if not r.exists(): print(f'{f.stem}: sin referencia'); continue
        a, b = Image.open(r).convert('RGB'), Image.open(f).convert('RGB')
        if a.size != b.size: print(f'{f.stem}: otro tamaño {a.size} {b.size}'); same = False; continue
        m = ImageChops.difference(a, b).convert('L').point(lambda v: 255 if v > 8 else 0)
        n = sum(m.histogram()[255:]); share = 100 * n / (a.size[0] * a.size[1])
        print(f'{f.stem}: {share:.3f} % de píxeles distintos ({n})')
        if n:
            same = False
            Image.composite(Image.new('RGB', a.size, (255, 0, 200)), a.convert('L').convert('RGB'), m).save(out / f'{f.stem}-diff.png')
    rs, ns = json.loads((ref / 'stats.json').read_text()), json.loads((out / 'stats.json').read_text())
    for size in ns:
        a, b = dict(flat(rs.get(size, {}))), dict(flat(ns[size]))
        diff = [(k, a.get(k), b.get(k)) for k in sorted(set(a) | set(b)) if a.get(k) != b.get(k)]
        for k, x, y in diff: print(f'stats {size} {k}: {x} -> {y}')
        if diff: same = False
        else: print(f'stats {size}: iguales ({len(b)} valores)')
    return same

if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument('--save', help='guarda la referencia en este directorio')
    g.add_argument('--against', help='compara con la referencia de este directorio')
    ap.add_argument('--out', default=str(ROOT / 'shots' / 'regress'), help='dónde quedan las capturas nuevas con --against')
    ap.add_argument('--only', action='append', choices=list(SIZES), help='solo este tamaño (repetible)')
    ap.add_argument('--init', help='JS que corre antes que la página (window.__STAGE=0: la generación de una vez)')
    ap.add_argument('--view', action='append', default=[], help='una vista más, nombre=expresión (repetible); va igual con --save y --against')
    a = ap.parse_args()
    if a.save: asyncio.run(capture(Path(a.save), a.only, a.init, a.view))
    else:
        out = Path(a.out); asyncio.run(capture(out, a.only, a.init, a.view))
        sys.exit(0 if compare(Path(a.against), out) else 1)
