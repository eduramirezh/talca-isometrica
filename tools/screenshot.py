"""Captura de pantalla del mapa con Chromium sin interfaz (Playwright), para revisar cambios.

  python tools/screenshot.py shots/centro.png                       # 1440x900, vista inicial
  python tools/screenshot.py shots/corte.png --hash corte-apelaciones
  python tools/screenshot.py shots/movil.png --size 390x844 --dark --dpr 3
  python tools/screenshot.py shots/noche.png --js "document.querySelector('#night').click()"
  python tools/screenshot.py shots/ruta.png --hash justicia          # inicia un recorrido
  python tools/screenshot.py shots/puente.png --js "__look(-1640,533,6,Math.PI/4+Math.PI)"  # cámara en (x, y) de grilla, zoom, giro
  python tools/screenshot.py shots/ --view "plaza=__look(-60,30,14.2)" --view "giro=__look(-60,30,14.2,Math.PI/4+Math.PI/2)"
      # varias vistas de una sola carga (shots/plaza.png, shots/giro.png): genera una vez, no una por captura
  python tools/screenshot.py shots/smoke.png --strict             # termina con código 1 si hay errores de consola o la
      # generación sale vacía (sin edificios, árboles o vértices): es `make smoke`, la prueba de humo del repo

Usa dist/index.html (make build) y sirve three.js r128 desde node_modules (npm install), así funciona
sin internet. Imprime las estadísticas de generación (edificios, vértices, árboles, ms) y los
errores de consola.
"""
import argparse, asyncio, os
from pathlib import Path
from playwright.async_api import async_playwright

ROOT = Path(__file__).resolve().parent.parent

async def open_page(p, size='1440x900', dark=False, offline=False, hash=None, dpr=1):
    """Abre el mapa en Chromium (SwiftShader) y espera la generación. Devuelve (navegador, página, logs).
    También la usa tools/variants.py."""
    three = (ROOT / 'node_modules/three/build/three.min.js')
    if not three.exists(): raise SystemExit('Falta three.js local. Ejecute: npm install')
    THREE = three.read_text()
    page_file = ROOT / 'dist' / 'index.html'
    if not page_file.exists(): raise SystemExit('Falta dist/index.html. Ejecute: make build')
    w, h = map(int, size.split('x'))
    b = await p.chromium.launch(args=['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'])
    pg = await b.new_page(viewport={'width': w, 'height': h}, color_scheme='dark' if dark else 'light',
                          has_touch=w < 800, is_mobile=w < 800, device_scale_factor=dpr)
    logs = []
    pg.on('console', lambda m: logs.append(f'{m.type}: {m.text}'))
    pg.on('pageerror', lambda e: logs.append(f'ERROR: {e}'))
    async def route(r):
        u = r.request.url
        if 'three' in u and u.endswith('.js'): await r.fulfill(body=THREE, content_type='application/javascript')
        elif u.startswith('file:'): await r.continue_()
        elif offline: await r.abort()
        else: await r.continue_()
    await pg.route('**/*', route)
    await pg.goto(page_file.as_uri() + (f'#{hash}' if hash else ''))
    await pg.wait_for_function('window.__stats', timeout=180000)
    await pg.wait_for_timeout(2500)
    print('stats:', await pg.evaluate('JSON.stringify(window.__stats)'))
    return b, pg, logs

async def main(a):
    async with async_playwright() as p:
        b, pg, logs = await open_page(p, a.size, a.dark, a.offline, a.hash, a.dpr)
        if a.js:
            await pg.evaluate(a.js); await pg.wait_for_timeout(3000)
        if a.view:
            out = Path(a.out); out.mkdir(parents=True, exist_ok=True)
            for v in a.view:
                name, _, js = v.partition('=')
                if not js: raise SystemExit(f'--view espera nombre=expresión: {v}')
                await pg.evaluate(js); await pg.wait_for_timeout(2500)
                f = out / f'{name}.png'; await pg.screenshot(path=str(f)); print('->', f)
        else:
            Path(a.out).parent.mkdir(parents=True, exist_ok=True)
            await pg.screenshot(path=a.out); print('->', a.out)
        for l in logs: print(l)
        bad = []
        if a.strict:
            bad = [l for l in logs if l.startswith(('ERROR:', 'error:'))]
            st = await pg.evaluate('window.__stats') or {}
            bad += [f'stats.{k} = {st.get(k)}' for k in ('buildings', 'trees', 'verts', 'ground') if not st.get(k)]
        await b.close()
        if bad: raise SystemExit('smoke: ' + '; '.join(bad))
        if a.strict: print('smoke: ok')

if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('out'); ap.add_argument('--size', default='1440x900'); ap.add_argument('--hash')
    ap.add_argument('--js'); ap.add_argument('--dark', action='store_true')
    ap.add_argument('--view', action='append', help='nombre=expresión JS; varias capturas de una carga (out es un directorio)')
    ap.add_argument('--dpr', type=float, default=1, help='densidad de pantalla (2: Retina)')
    ap.add_argument('--offline', action='store_true', help='bloquea fuentes web y todo lo externo salvo three.js')
    ap.add_argument('--strict', action='store_true', help='código 1 si hay errores de consola o la generación sale vacía (make smoke)')
    asyncio.run(main(ap.parse_args()))
