"""Perfil de CPU del arranque del mapa: en qué funciones de src/ se van los ms de la carga.

  uv run --with "playwright==1.63" python tools/profile.py --android            # en el teléfono por USB (como perf.py)
  uv run --with "playwright==1.63" python tools/profile.py                      # Chromium sin interfaz, 390x844
  uv run --with "playwright==1.63" python tools/profile.py --android --top 40 --under cityGen   # dentro de una función
  python tools/profile.py --from arranque.cpuprofile --callers pip --depth 2    # quién llama a pip, en un perfil guardado

Abre la página (con --android, en el Chrome del teléfono, igual que tools/perf.py --android), enciende el perfilador
de V8 por CDP (una muestra cada --interval µs), la recarga, espera el primer cuadro en pantalla (__stats.load.shown)
y lo apaga. Imprime dos tablas, con la función, su archivo y línea de src/ (pipeline/build.py where()) y los ms:
  propio   el tiempo en el cuerpo de la función, sin las que llama (dónde se gasta de verdad)
  total    con lo que llama, contado una vez por pila (cityGen incluye a lotFree, etc.)
--under F se queda con las muestras que tienen a F en su pila (los totales y propios dentro de ella). El perfilador
hace más lenta la página (~10-20 %): sirve para comparar funciones, no para la cifra del arranque (perf.py --arranque).
--callers F da quién llama a F: los ms de F (con lo que llama) por cada camino de --depth llamadores. --from lee un
perfil guardado con --save en vez de cargar la página.
Con --save guarda el perfil crudo (.cpuprofile, se abre en la pestaña Performance de las DevTools de Chrome).
"""
import argparse, asyncio, json, sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / 'pipeline'))
import build  # noqa: E402

STANDALONE = build.STANDALONE.count('\n')

def src_of(frame):
    """callFrame -> 'src/js/50-city.js:123' (or the URL's last part, for three.js and the rest)."""
    url, n = frame['url'], frame['lineNumber'] + 1
    if not url: return '(nativo)'
    if not url.split('#')[0].endswith(('index.html', '/')): return url.rsplit('/', 1)[-1]
    try:
        f, k = build.where(n - STANDALONE)
        return f'{f}:{k}'
    except ValueError: return f'index.html:{n}'

def stacks(prof):
    """[(ms, [node, its caller, …])] for each sampled node of the profile."""
    nodes = {n['id']: n for n in prof['nodes']}
    parent = {}
    for n in prof['nodes']:
        for c in n.get('children', []): parent[c] = n['id']
    dt = defaultdict(float)  # ms per sample's node
    for nid, d in zip(prof['samples'], prof['timeDeltas'][1:] + [0]): dt[nid] += d / 1000
    for nid, ms in dt.items():
        stack, i = [], nid
        while i in nodes: stack.append(nodes[i]); i = parent.get(i)
        yield ms, stack

def callers(prof, fn, depth, top):
    out = defaultdict(float)
    for ms, stack in stacks(prof):
        for j, n in enumerate(stack):
            if n['callFrame']['functionName'] == fn:
                out[' < '.join(f"{m['callFrame']['functionName'] or '(anónima)'} {src_of(m['callFrame'])}" for m in stack[j+1:j+1+depth])] += ms
                break
    print(f'{fn}: {sum(out.values()):.0f} ms, por llamadores (ms):')
    for k, ms in sorted(out.items(), key=lambda kv: -kv[1])[:top]: print(f'{ms:8.0f}  {k}')

def report(prof, top, under):
    key = lambda n: (n['callFrame']['functionName'] or '(anónima)', src_of(n['callFrame']))
    self_t, total_t, kept = defaultdict(float), defaultdict(float), 0.0
    for ms, stack in stacks(prof):
        stack = [key(n) for n in stack]
        if under and not any(k[0] == under for k in stack): continue
        kept += ms; self_t[stack[0]] += ms
        for k in set(stack): total_t[k] += ms
    print(f'muestras: {kept:.0f} ms' + (f' con {under} en la pila' if under else ''))
    for title, t in (('propio', self_t), ('total', total_t)):
        print(f'\n{title} (ms):')
        for (fn, src), ms in sorted(t.items(), key=lambda kv: -kv[1])[:top]:
            if fn in ('(root)', '(program)', '(idle)') and title == 'total': continue
            print(f'{ms:8.0f}  {fn:28s} {src}')

async def main(a):
    if a.from_:
        prof = json.load(open(a.from_))
        return callers(prof, a.callers, a.depth, a.top) if a.callers else report(prof, a.top, a.under)
    from playwright.async_api import async_playwright  # --from works without Playwright
    from screenshot import open_page
    from perf import android_page
    async with async_playwright() as p:
        if a.android: b, pg, logs, srv = await android_page(p, a.port)
        else: b, pg, logs = await open_page(p, a.size, dpr=a.dpr)
        cdp = await pg.context.new_cdp_session(pg)
        await cdp.send('Profiler.enable'); await cdp.send('Profiler.setSamplingInterval', {'interval': a.interval})
        await cdp.send('Profiler.start')
        await pg.reload()
        await pg.wait_for_function('window.__stats&&window.__stats.load.shown', timeout=300000)
        prof = (await cdp.send('Profiler.stop'))['profile']
        print('arranque:', await pg.evaluate('JSON.stringify(window.__stats.load)'))
        print('fases:', await pg.evaluate('JSON.stringify(window.__stats.t)'))
        if a.save: open(a.save, 'w').write(json.dumps(prof)); print('->', a.save)
        if a.callers: callers(prof, a.callers, a.depth, a.top)
        else: report(prof, a.top, a.under)
        if a.android: await pg.close(); srv.shutdown()
        else: await b.close()

if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('--android', action='store_true', help='en el Chrome de un teléfono Android conectado por adb')
    ap.add_argument('--port', type=int, default=8766)
    ap.add_argument('--size', default='390x844'); ap.add_argument('--dpr', type=float, default=2)
    ap.add_argument('--interval', type=int, default=200, help='µs entre muestras')
    ap.add_argument('--top', type=int, default=30); ap.add_argument('--under', help='solo las muestras con esta función en la pila')
    ap.add_argument('--callers', metavar='F', help='quién llama a la función F'); ap.add_argument('--depth', type=int, default=1)
    ap.add_argument('--from', dest='from_', metavar='ARCHIVO', help='un perfil guardado con --save, sin cargar la página')
    ap.add_argument('--save', help='guarda el perfil crudo (.cpuprofile)')
    asyncio.run(main(ap.parse_args()))
