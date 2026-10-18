"""Perfil de CPU del arranque del mapa: en qué funciones de src/ se van los ms de la carga.

  uv run --with "playwright==1.63" python tools/profile.py --android            # en el teléfono por USB (como perf.py)
  uv run --with "playwright==1.63" python tools/profile.py                      # Chromium sin interfaz, 390x844
  uv run --with "playwright==1.63" python tools/profile.py --android --top 40 --under cityGen   # dentro de una función
  python tools/profile.py --from arranque.cpuprofile --callers pip --depth 2    # quién llama a pip, en un perfil guardado
  uv run --with "playwright==1.63" python tools/profile.py --etapa 1            # solo lo que va antes del primer cuadro
  uv run --with "playwright==1.63" python tools/profile.py --etapa 2 --tareas 8 # la segunda etapa y sus tareas de más de 8 ms

Abre una pestaña (con --android, en el Chrome del teléfono, igual que tools/perf.py --android), enciende el perfilador
de V8 por CDP (una muestra cada --interval µs), la carga (en Chromium, la primera carga de un navegador nuevo; en el
teléfono, de nuevo, pasando por una página en blanco), espera el final de la generación (window.__stats, que
aparece cuando termina la segunda etapa, rest()) y lo apaga. Imprime dos tablas, con la función, su archivo y línea de src/ (pipeline/build.py where()) y los ms:
  propio   el tiempo en el cuerpo de la función, sin las que llama (dónde se gasta de verdad)
  total    con lo que llama, contado una vez por pila (cityGen incluye a lotFree, etc.)
--under F se queda con las muestras que tienen a F en su pila (los totales y propios dentro de ella). El perfilador
hace más lenta la página (~10-20 %): sirve para comparar funciones, no para la cifra del arranque (perf.py --arranque).
--callers F da quién llama a F: los ms de F (con lo que llama) por cada camino de --depth llamadores. --from lee un
perfil guardado con --save en vez de cargar la página.
Con --save guarda el perfil crudo (.cpuprofile, se abre en la pestaña Performance de las DevTools de Chrome).
--etapa 1 se queda con las muestras de antes del primer cuadro o la primera tajada de rest() (el script, three.js, boot
hasta la primera vista); --etapa 2, con las de después (rest() en tajadas y los cuadros que se dibujan entre ellas).
Sirve con --under, --callers y --from.
--tareas MS además graba una traza del navegador (la categoría toplevel: cada tarea del hilo principal, con su duración
exacta) y lista las tareas de la segunda etapa de más de MS ms: cuánto duró cada una y qué hizo, la parte de rest()
que corrió en ella (la función que rest() llama, o lo que esa llama si es un ayudante de boot como streetsOf), o
«cuadro» si fue loop(). Así se ve qué tajadas pasan de SLICE_BUSY (8 ms) o de SLICE_MS (40 ms) y en qué fase. No sirve
con --from (el perfil guardado no lleva la traza). También da los ms entre cuadros (requestAnimationFrame) mientras
corre la segunda etapa: mediana, percentil 90, máximo y cuántos pasan de 50 ms.
--gesto desplaza el mapa en cada cuadro desde el primero hasta el final de rest() (__three.pan, 4 px de ida y vuelta),
como quien lo arrastra mientras carga: sliced() usa entonces tajadas de SLICE_BUSY y la lista de tareas muestra cuánto
dura cada pieza de rest() que no se puede partir.
"""
import argparse, asyncio, json, re, sys

# the ms between frames while stage 2 runs (from window.__three, at the end of stage 1, to window.__stats); with
# PAN, the map moves 4 px each frame meanwhile, back and forth
FRAMES = r"""(()=>{const d=window.__frames=[];let last=0,n=0,dir=1;const PAN=%s;
 const f=()=>{if(window.__stats)return;const t=performance.now();
  if(window.__three){if(last)d.push(t-last);last=t;if(PAN){__three.pan(4*dir,0);if(++n%%60===0)dir=-dir;}}
  requestAnimationFrame(f);};requestAnimationFrame(f);})()"""
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / 'pipeline'))
import build  # noqa: E402

_PIECES = {}
def pieces(kind):
    """build.script_pieces() or build.page_pieces(), read once."""
    if kind not in _PIECES: _PIECES[kind] = getattr(build, f'{kind}_pieces')()
    return lambda: _PIECES[kind]

def src_of(frame):
    """callFrame -> 'src/js/50-city.js:123' (or the URL's last part, for three.js and the rest)."""
    url, n = frame['url'], frame['lineNumber'] + 1
    if not url: return '(nativo)'
    name = url.split('#')[0].rsplit('/', 1)[-1]
    kind = 'script' if re.fullmatch(r'app\.\w+\.js', name) else 'page' if name in ('index.html', '') else None
    if not kind: return name
    try:
        f, k = build.where(n, pieces(kind))
        return f'{f}:{k}'
    except ValueError: return f'{name or "index.html"}:{n}'

def samples(prof):
    """[(µs since the profile's start, ms, [node, its caller, …])] for each sample, in order."""
    nodes = {n['id']: n for n in prof['nodes']}
    parent = {}
    for n in prof['nodes']:
        for c in n.get('children', []): parent[c] = n['id']
    memo, t, out = {}, prof['startTime'], []
    deltas = prof['timeDeltas']
    for k, nid in enumerate(prof['samples']):
        t += deltas[k]
        if nid not in memo:
            stack, i = [], nid
            while i in nodes: stack.append(nodes[i]); i = parent.get(i)
            memo[nid] = stack
        out.append((t, (deltas[k + 1] if k + 1 < len(deltas) else 0) / 1000, memo[nid]))
    return out

name = lambda n: n['callFrame']['functionName']

def stage_start(smp):
    """When stage 2 starts: the first sample of a frame (loop) or of rest()."""
    return next((t for t, ms, st in smp if any(name(n) in ('loop', 'rest') for n in st)), smp[-1][0] + 1)

def staged(prof, etapa):
    """The profile with only the samples of stage 1 (before the first frame or slice) or 2 (from then on)."""
    if not etapa: return prof
    smp = samples(prof); t2 = stage_start(smp)
    keep = [(t < t2) == (etapa == 1) for t, ms, st in smp]
    # a sample that is dropped becomes (idle) time: the timing of the rest stays the same
    idle = next((n['id'] for n in prof['nodes'] if name(n) == '(idle)'), None)
    if idle is None:
        idle = max(n['id'] for n in prof['nodes']) + 1
        root = prof['nodes'][0]
        prof['nodes'].append({'id': idle, 'callFrame': {'functionName': '(idle)', 'url': '', 'lineNumber': -1}})
        root.setdefault('children', []).append(idle)
    prof['samples'] = [nid if k else idle for nid, k in zip(prof['samples'], keep)]
    return prof

def piece(st):
    """What part of rest() a sample is in: the function rest() calls (one level deeper for boot's helpers), or 'cuadro'."""
    names = [name(n) for n in st]
    if 'rest' in names:
        j = names.index('rest')
        if j == 0: return 'rest'
        f = names[j - 1]
        if f.endswith('Of') and j >= 2: f += ' > ' + names[j - 2]  # streetsOf > cityGen, walksOf > streetTrees…
        return f
    if 'loop' in names: return 'cuadro'
    return names[0] or '(anónima)'

def tasks(prof, trace, min_ms):
    """The main thread's tasks of stage 2 longer than min_ms, with the ms of each part of rest() in them."""
    ev = trace['traceEvents'] if isinstance(trace, dict) else trace
    main = [(e['pid'], e['tid']) for e in ev if e.get('ph') == 'M' and e.get('name') == 'thread_name' and e['args'].get('name') == 'CrRendererMain']
    smp = samples(prof); t2 = stage_start(smp)
    # the renderer whose main thread ran the profiled samples
    best = None
    for pt in set(main):
        run = sorted((e['ts'], e['ts'] + e['dur']) for e in ev if (e.get('pid'), e.get('tid')) == pt and e.get('ph') == 'X' and e.get('dur') and e['name'] in ('ThreadControllerImpl::RunTask', 'RunTask'))
        top, end = [], -1
        for a, b in run:
            if a >= end: top.append([a, b]); end = b
        n = sum(1 for a, b in top if a <= t2 <= b)
        if best is None or n > best[0]: best = (n, top)
    if not best: raise SystemExit('la traza no tiene el hilo principal del renderizador')
    top = [x for x in best[1] if x[1] > t2]
    i, out = 0, []
    for a, b in top:
        while i < len(smp) and smp[i][0] < a: i += 1
        parts = defaultdict(float); j = i
        while j < len(smp) and smp[j][0] <= b:
            ms, st = smp[j][1], smp[j][2]
            if name(st[0]) not in ('(idle)', '(root)'): parts[piece(st) if name(st[0]) != '(program)' else '(navegador)'] += ms
            j += 1
        out.append(((b - a) / 1000, parts, (a - t2) / 1000))
    durs = sorted(d for d, p, t in out)
    q = lambda f: durs[min(len(durs) - 1, int(f * len(durs)))] if durs else 0
    print(f'\ntareas de la segunda etapa: {len(out)}, {sum(durs):.0f} ms; mediana {q(.5):.1f}, p90 {q(.9):.1f}, máx. {q(1):.1f} ms;'
          f' > 8 ms: {sum(d > 8 for d in durs)}, > 16,7: {sum(d > 16.7 for d in durs)}, > 40: {sum(d > 40 for d in durs)}, > 100: {sum(d > 100 for d in durs)}')
    by = defaultdict(lambda: [0, 0.0, 0.0])  # the biggest part of each long task -> [tasks, ms, longest]
    print(f'las de más de {min_ms:g} ms (cuándo empieza, ms desde el comienzo de la segunda etapa; ms de la tarea: ms de cada parte, perfilador incluido):')
    for d, parts, t in out:
        if d <= min_ms: continue
        main_part = max(parts, key=parts.get) if parts else '?'
        b_ = by[main_part]; b_[0] += 1; b_[1] += d; b_[2] = max(b_[2], d)
        print(f'{t:+8.0f} {d:8.1f}  ' + ', '.join(f'{k} {v:.0f}' for k, v in sorted(parts.items(), key=lambda kv: -kv[1])[:4]))
    print(f'\npor parte principal (tareas de más de {min_ms:g} ms: cuántas, ms, la más larga):')
    for k, (n, ms, mx) in sorted(by.items(), key=lambda kv: -kv[1][1]): print(f'{n:5d} {ms:8.0f} {mx:8.1f}  {k}')

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
        prof = staged(json.load(open(a.from_)), a.etapa)
        return callers(prof, a.callers, a.depth, a.top) if a.callers else report(prof, a.top, a.under)
    from playwright.async_api import async_playwright  # --from works without Playwright
    from screenshot import open_page, serve
    from perf import android_page
    async with async_playwright() as p:
        # locally, a page that has loaded nothing: after another load of the map (a reload, or about:blank in between)
        # the old page's compositor is torn down (LayerTreeHost) in the middle of the profiled load, ~1 s on the main
        # thread with SwiftShader. On the phone, a blank page in between
        if a.android:
            b, pg, logs, srv = await android_page(p, a.port)
            url = pg.url; await pg.goto('about:blank'); await pg.wait_for_timeout(3000)
        else:
            b, pg, logs = await open_page(p, a.size, dpr=a.dpr, go=False, init=FRAMES % ('true' if a.gesto else 'false'))
            url = serve()
        cdp = await pg.context.new_cdp_session(pg)
        await cdp.send('Profiler.enable'); await cdp.send('Profiler.setSamplingInterval', {'interval': a.interval})
        if a.tareas is not None: await b.start_tracing(page=pg, categories=['toplevel'])
        await cdp.send('Profiler.start')
        await pg.goto(url)
        await pg.wait_for_function('window.__stats&&window.__stats.load.shown', timeout=300000)
        prof = (await cdp.send('Profiler.stop'))['profile']
        trace = json.loads(await b.stop_tracing()) if a.tareas is not None else None
        print('arranque:', await pg.evaluate('JSON.stringify(window.__stats.load)'))
        print('fases:', await pg.evaluate('JSON.stringify(window.__stats.t)'))
        if a.save: open(a.save, 'w').write(json.dumps(prof)); print('->', a.save)
        if trace: tasks(prof, trace, a.tareas)
        fr = sorted(await pg.evaluate('window.__frames||[]'))
        if fr:
            q = lambda f: fr[min(len(fr) - 1, int(f * len(fr)))]
            print(f'cuadros en la segunda etapa{" (con --gesto)" if a.gesto else ""}: {len(fr)}; ms entre cuadros: mediana {q(.5):.1f},'
                  f' p90 {q(.9):.1f}, máx. {fr[-1]:.1f}; > 50 ms: {sum(x > 50 for x in fr)}, > 100 ms: {sum(x > 100 for x in fr)}')
        prof = staged(prof, a.etapa)
        if a.callers: callers(prof, a.callers, a.depth, a.top)
        else: report(prof, a.top, a.under)
        if a.android: await pg.close()
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
    ap.add_argument('--etapa', type=int, choices=(1, 2), help='1: antes del primer cuadro; 2: rest() y los cuadros entre sus tajadas')
    ap.add_argument('--gesto', action='store_true', help='desplaza el mapa en cada cuadro de la segunda etapa (sin --android)')
    ap.add_argument('--tareas', type=float, metavar='MS', help='lista las tareas de la segunda etapa de más de MS ms (con una traza)')
    asyncio.run(main(ap.parse_args()))
