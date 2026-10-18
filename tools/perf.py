"""Mide lo que cuesta un cuadro del mapa, pasada por pasada, en Chromium sin interfaz (SwiftShader).

  uv run --with "playwright==1.63" python tools/perf.py                      # teléfono: 390x844, densidad 2
  uv run --with "playwright==1.63" python tools/perf.py --size 1440x900 --dpr 1
  uv run --with "playwright==1.63" python tools/perf.py --view "estadio=__look(-560,1000,4)"   # vistas propias (repetible)
  uv run --with "playwright==1.63" python tools/perf.py --android     # en el Chrome de un teléfono Android por USB
  uv run --with "playwright==1.63" python tools/perf.py --android --arranque 3   # solo el arranque, en tres cargas
  uv run --with "playwright==1.63" python tools/perf.py --arranque 3 --red lenta --frio   # en una red móvil lenta, sin caché
  uv run --with "playwright==1.63" python tools/perf.py --android --arranque 3 --url https://e951faec.talca-isometrica.pages.dev/
      # el sitio publicado (o una publicación anterior de Cloudflare Pages: wrangler pages deployment list), por la red del teléfono
  TALCA_DIST=shots/dist-antes uv run --with "playwright==1.63" python tools/perf.py --arranque 3   # otra copia de dist/, para comparar

Para cada vista (JS que mueve la cámara, como en screenshot.py) da tres cuadros que pasan por el loop() real:
  refit   el mapa de sombras rehecho (fitShadow(true)): lo que cuesta un salto o un zoom grande
  pan     la mediana de seis desplazamientos de 6 px, uno por cuadro: sin sombras si la caja alcanza
  settle  el cuadro siguiente a que la cámara se detiene: solo con __pixelArt({crease:'normals'}), que salta la
          pasada de normales mientras la cámara se mueve (0: no hace falta un cuadro más)
cada uno como [ms, llamadas de dibujo, triángulos, veces que se dibujó el mapa de sombras, ms de CPU], sumados sobre
las pasadas del cuadro (los triángulos no cuentan los del mapa de sombras), con la k y el contorno (ol) del pixel art.
Cada medida espera a la GPU (readPixels), así que los ms son de SwiftShader: sirven para comparar, no son los de un
teléfono. Los ms de CPU son lo que tarda renderer.render() en volver, sin esperar a la GPU: el trabajo de three.js y
del navegador por cada llamada (recorrer la escena, recortar, ordenar, mandar los comandos), que en un teléfono pesa
aunque SwiftShader lo esconda tras los triángulos.
Además da gesto: [mediana, percentil 90] del intervalo entre cuadros (ms) durante ~2 s de desplazamiento continuo,
sin esperar a la GPU en cada pasada: lo que se siente al arrastrar (16,7 = 60 cuadros por segundo).
Antes de las vistas imprime el arranque (window.__stats.load, ms desde el comienzo de la navegación): html (llega
el HTML), three (llega three.js), dcl (DOMContentLoaded), script (empieza el script), boot (empieza la generación),
gen (termina la parte de la primera vista), frame (termina de dibujarse el primer cuadro, que tarda frameMs:
compila los sombreadores y dibuja el primer mapa de sombras), shown (empieza el cuadro siguiente: el primero ya está en
la pantalla) y full (termina el resto de la generación, en tajadas después del primer cuadro). Con --arranque N carga la página N veces, imprime cada arranque y la
mediana (también de las fases: los ms de __stats.t, y edDecode y edHulls de window.__ed), y no mide las vistas: la primera sin caché y las siguientes recargando, con lo que el navegador guardó (dist/
se sirve como Cloudflare Pages, con assets/ en la caché y el texto comprimido: serve() de screenshot.py), o cada una
sin caché con --frio (una página nueva en un contexto nuevo del mismo navegador). --red emula una red (CDP, también para
lo que no viene de dist/: las fuentes de Google, o three.js desde cdnjs en una versión vieja): lenta, la de los
teléfonos de Lighthouse (150 ms de ida y vuelta, 1,6 Mbit/s de bajada, 750 kbit/s de subida), o 4g (60 ms, 9 Mbit/s,
1,5 Mbit/s). No sirve con --android, que va por USB; para medir en la red del teléfono, --url abre una página publicada en
vez de dist/ (con --android o sin él).
Usa window.__three (99-boot.js) y abre la página con open_page() de screenshot.py (una carga, ~1 min).

Con --android mide en un teléfono de verdad: con la depuración USB activada, el teléfono conectado y Chrome abierto
en él, sirve dist/ en el puerto --port, lo lleva al teléfono (adb reverse), se conecta a su Chrome por CDP (adb
forward a chrome_devtools_remote) y abre la página en una pestaña nueva, del tamaño y la densidad del teléfono
(--size y --dpr no cuentan), con todo desde dist/, como en screenshot.py. Imprime el modelo, la GPU y la
pantalla. Deja la pantalla del teléfono encendida y la pestaña al frente: una pestaña oculta no dibuja.
"""
import argparse, asyncio, json, subprocess
from playwright.async_api import async_playwright
from screenshot import open_page, serve, ROOT

FRAME = r"""(async (look)=>{const {renderer}=__three;const gl=renderer.getContext(),px=new Uint8Array(4),SM=renderer.shadowMap;
 const render=renderer.render.bind(renderer),smr=SM.render.bind(SM);let ms=0,calls=0,tri=0,shadow=0,cpu=0;
 SM.render=(...a)=>{if(SM.needsUpdate)shadow++;smr(...a);};
 renderer.render=(s,c)=>{const t=performance.now();render(s,c);cpu+=performance.now()-t;gl.readPixels(0,0,1,1,gl.RGBA,gl.UNSIGNED_BYTE,px);ms+=performance.now()-t;calls+=renderer.info.render.calls;tri+=renderer.info.render.triangles;};
 const frame=()=>new Promise(r=>requestAnimationFrame(r)),rest=()=>new Promise(r=>setTimeout(r,400));
 const take=()=>{const r=[Math.round(ms),calls,tri,shadow,Math.round(cpu*10)/10];ms=calls=tri=shadow=cpu=0;return r;};
 try{eval(look);await frame();await frame();await rest();await frame();await frame();take(); // new tiles uploaded, settled
  __three.fitShadow(true);__three.placeCam();await frame();const refit=take();await rest();await frame();take();
  const pans=[];for(let i=0;i<6;i++){__three.pan(6,0);await frame();pans.push(take());}
  await rest();await frame();const settle=take();pans.sort((a,b)=>a[0]-b[0]);
  return {refit,pan:pans[3],settle,k:__three.PA.k,ol:__three.PA.ol};}
 finally{renderer.render=render;SM.render=smr;}})"""

GESTURE = r"""(async ()=>{const frame=()=>new Promise(r=>requestAnimationFrame(r)),d=[];await frame();let t=performance.now();
 for(let i=0;i<120&&d.reduce((a,b)=>a+b,0)<2000;i++){__three.pan(5,0);await frame();const n=performance.now();d.push(n-t);t=n;}
 d.sort((a,b)=>a-b);const q=f=>Math.round(d[Math.min(d.length-1,Math.floor(f*d.length))]*10)/10;return [q(.5),q(.9)];})"""

DEVICE = r"""(()=>{const gl=__three.renderer.getContext(),x=gl.getExtension('WEBGL_debug_renderer_info');
 return {ua:navigator.userAgent,gpu:x?gl.getParameter(x.UNMASKED_RENDERER_WEBGL):gl.getParameter(gl.RENDERER),
  css:[innerWidth,innerHeight],dpr:devicePixelRatio,webgl2:!!__three.renderer.capabilities.isWebGL2};})()"""

LOAD = 'JSON.stringify(window.__stats.load)'
# the ms of each phase of the generation (__stats.t) and of the OSM buildings' decoding and plan (__ed)
PHASES = 'JSON.stringify(Object.assign({},window.__stats.t,window.__ed?{edDecode:__ed.decodeMs,edHulls:Math.round(__ed.hullMs||0)}:{}))'

async def android_page(p, port, url=None):
    """La página en el Chrome del teléfono por adb: (navegador, página, logs, URL de dist/ servido en el puerto)."""
    adb = lambda *a: subprocess.run(['adb', *a], check=True, capture_output=True, text=True).stdout
    if 'device' not in adb('devices').split('\n', 1)[1]: raise SystemExit('adb no ve el teléfono: conéctelo, desbloquéelo y acepte la depuración USB')
    srv = None if url else serve(port)
    adb('reverse', f'tcp:{port}', f'tcp:{port}'); adb('forward', 'tcp:9222', 'localabstract:chrome_devtools_remote')
    b = await p.chromium.connect_over_cdp('http://127.0.0.1:9222')
    pg = await b.contexts[0].new_page(); await pg.bring_to_front()
    logs = []
    pg.on('console', lambda m: logs.append(f'{m.type}: {m.text}')); pg.on('pageerror', lambda e: logs.append(f'ERROR: {e}'))
    await android_load(pg, port, url)
    print('stats:', await pg.evaluate('JSON.stringify(window.__stats)'))
    return b, pg, logs, srv

async def android_load(pg, port, url=None):
    await pg.goto(url or f'http://localhost:{port}/index.html')
    await pg.wait_for_function('window.__stats&&window.__stats.load.shown', timeout=300000); await pg.wait_for_timeout(2500)

VIEWS = ['inicial=0', 'comuna=__look(3000,1000,0.12)', 'ciudad=__look(-60,30,1.5)', 'plaza-z4=__look(-60,30,4)', 'plaza-z14=__look(-60,30,14.2)']

# network conditions for --red (CDP Network.emulateNetworkConditions: ms of latency, bytes per second)
RED = {'lenta': (150, 1.6e6 / 8, 750e3 / 8), '4g': (60, 9e6 / 8, 1.5e6 / 8)}

async def fresh(b, a, pg=None):
    """A page that loads the map with --red's network: in a new context (an empty cache) unless pg is given."""
    if pg is None:
        w, h = map(int, a.size.split('x'))
        pg = await b.new_page(viewport={'width': w, 'height': h}, has_touch=w < 800, is_mobile=w < 800, device_scale_factor=a.dpr)
    if a.red:
        cdp = await pg.context.new_cdp_session(pg); lat, down, up = RED[a.red]
        await cdp.send('Network.enable')
        await cdp.send('Network.emulateNetworkConditions', {'offline': False, 'latency': lat, 'downloadThroughput': down, 'uploadThroughput': up})
    await pg.goto(a.url or serve()); await pg.wait_for_function('window.__stats&&window.__stats.load.shown', timeout=300000)
    return pg

async def main(a):
    async with async_playwright() as p:
        if a.android: b, pg, logs, srv = await android_page(p, a.port, a.url)
        elif a.red or a.frio or a.url: b, pg, logs = await open_page(p, a.size, dpr=a.dpr, go=False); pg = await fresh(b, a, pg)
        else: b, pg, logs = await open_page(p, a.size, dpr=a.dpr)
        print('dispositivo:', json.dumps(await pg.evaluate(DEVICE), ensure_ascii=False))
        await pg.wait_for_function('window.__stats.load.shown', timeout=60000)
        async def run():
            if a.arranque: await pg.wait_for_function('window.__stats&&window.__stats.load.full', timeout=300000)
            r, f = json.loads(await pg.evaluate(LOAD)), json.loads(await pg.evaluate(PHASES))
            print('arranque:', json.dumps(r)); a.arranque and print('fases:', json.dumps(f)); return r, f
        runs, fases = map(list, zip(await run()))
        for i in range(1, a.arranque or 0):
            if a.android: await android_load(pg, a.port, a.url)
            elif a.frio: await pg.context.close(); pg = await fresh(b, a)
            else: await pg.reload(); await pg.wait_for_function('window.__stats&&window.__stats.load.shown', timeout=300000)
            r, f = await run(); runs.append(r); fases.append(f)
        if a.arranque:
            med = lambda rs: {k: sorted(r[k] for r in rs)[len(rs) // 2] for k in rs[0] if all(isinstance(r.get(k), int) for r in rs)}
            print('mediana:', json.dumps(med(runs))); print('mediana de las fases:', json.dumps(med(fases)))
        print('[ms, llamadas, triángulos, mapas de sombra, ms de CPU] por cuadro; gesto: [mediana, p90] ms entre cuadros')
        for v in [] if a.arranque else a.view or VIEWS:
            name, _, js = v.partition('=')
            r = await pg.evaluate(FRAME, js or '0'); r['gesto'] = await pg.evaluate(GESTURE)
            print(name, json.dumps(r))
        for l in logs:
            if l.startswith(('ERROR:', 'error:')): print(l)
        if a.android: await pg.close()
        else: await b.close()

if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('--size', default='390x844'); ap.add_argument('--dpr', type=float, default=2)
    ap.add_argument('--view', action='append', help='nombre=expresión JS que mueve la cámara (repetible)')
    ap.add_argument('--android', action='store_true', help='en el Chrome de un teléfono Android conectado por adb')
    ap.add_argument('--arranque', type=int, metavar='N', help='solo el arranque, en N cargas de la página')
    ap.add_argument('--port', type=int, default=8766, help='puerto en que se sirve dist/ con --android')
    ap.add_argument('--url', help='una página publicada en vez de dist/ servido en local (el sitio, una publicación anterior)')
    ap.add_argument('--red', choices=RED, help='emula una red: lenta (150 ms, 1,6 Mbit/s) o 4g (60 ms, 9 Mbit/s)')
    ap.add_argument('--frio', action='store_true', help='con --arranque, cada carga sin caché (por omisión, solo la primera)')
    asyncio.run(main(ap.parse_args()))
