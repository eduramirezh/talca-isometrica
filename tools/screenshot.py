"""Captura de pantalla del mapa con Chromium sin interfaz (Playwright), para revisar cambios.

  python tools/screenshot.py shots/centro.png                       # 1440x900, vista inicial
  python tools/screenshot.py shots/corte.png --hash corte-apelaciones
  python tools/screenshot.py shots/movil.png --size 390x844 --dark
  python tools/screenshot.py shots/noche.png --js "document.querySelector('#night').click()"
  python tools/screenshot.py shots/ruta.png --hash justicia          # inicia un recorrido
  python tools/screenshot.py shots/puente.png --js "__look(-1640,533,6,Math.PI/4+Math.PI)"  # cámara en (x, y) de grilla, zoom, giro

Usa dist/index.html (make build) y sirve three.js r128 desde node_modules (npm install), así funciona
sin internet. Imprime las estadísticas de generación (edificios, vértices, árboles, ms) y los
errores de consola.
"""
import argparse, asyncio, os
from pathlib import Path
from playwright.async_api import async_playwright

ROOT = Path(__file__).resolve().parent.parent

async def main(a):
    three = (ROOT / 'node_modules/three/build/three.min.js')
    if not three.exists(): raise SystemExit('Falta three.js local. Ejecute: npm install')
    THREE = three.read_text()
    page_file = ROOT / 'dist' / 'index.html'
    if not page_file.exists(): raise SystemExit('Falta dist/index.html. Ejecute: make build')
    w, h = map(int, a.size.split('x'))
    async with async_playwright() as p:
        b = await p.chromium.launch(args=['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'])
        pg = await b.new_page(viewport={'width': w, 'height': h}, color_scheme='dark' if a.dark else 'light',
                              has_touch=w < 800, is_mobile=w < 800)
        logs = []
        pg.on('console', lambda m: logs.append(f'{m.type}: {m.text}'))
        pg.on('pageerror', lambda e: logs.append(f'ERROR: {e}'))
        async def route(r):
            u = r.request.url
            if 'three' in u and u.endswith('.js'): await r.fulfill(body=THREE, content_type='application/javascript')
            elif u.startswith('file:'): await r.continue_()
            elif a.offline: await r.abort()
            else: await r.continue_()
        await pg.route('**/*', route)
        await pg.goto(page_file.as_uri() + (f'#{a.hash}' if a.hash else ''))
        await pg.wait_for_function('window.__stats', timeout=180000)
        await pg.wait_for_timeout(2500)
        print('stats:', await pg.evaluate('JSON.stringify(window.__stats)'))
        if a.js:
            await pg.evaluate(a.js); await pg.wait_for_timeout(3000)
        Path(a.out).parent.mkdir(parents=True, exist_ok=True)
        await pg.screenshot(path=a.out); print('->', a.out)
        for l in logs: print(l)
        await b.close()

if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('out'); ap.add_argument('--size', default='1440x900'); ap.add_argument('--hash')
    ap.add_argument('--js'); ap.add_argument('--dark', action='store_true')
    ap.add_argument('--offline', action='store_true', help='bloquea fuentes web y todo lo externo salvo three.js')
    asyncio.run(main(ap.parse_args()))
