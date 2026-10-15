"""Evalúa expresiones JavaScript en el mapa cargado (Chromium sin interfaz) e imprime el resultado.

  python tools/probe.py "__stats.ms" "Object.keys(__rail)"
  python tools/probe.py "(()=>{const r=__rail.main;return [r.s[r.s.length-1], r.x[0], r.y[0]]})()"
  python tools/probe.py --js "__train('main',6200)" "__trains()"      # --js corre antes (y espera 1 s)

Cada argumento es una expresión (o una IIFE) que se evalúa con page.evaluate; el resultado se
imprime como JSON, una línea por expresión. Sirve para mirar lo que la página expone en window.__*
(__rail, __stats, __usos, __pads, __trains) sin tomar capturas. Abre la página con open_page() de
screenshot.py (una sola carga, ~1 min con SwiftShader).
"""
import argparse, asyncio, json
from playwright.async_api import async_playwright
from screenshot import open_page

async def main(a):
    async with async_playwright() as p:
        b, pg, logs = await open_page(p, a.size)
        for js in a.js or []:
            await pg.evaluate(js); await pg.wait_for_timeout(1000)
        for e in a.expr:
            try: print(json.dumps(await pg.evaluate(e), ensure_ascii=False))
            except Exception as x: print('ERROR', e, '->', str(x).splitlines()[0])
        for l in logs:
            if 'error' in l.lower(): print(l)
        await b.close()

if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('expr', nargs='+', help='expresiones JS; cada una se imprime como JSON')
    ap.add_argument('--js', action='append', help='JS que corre antes de evaluar (repetible)')
    ap.add_argument('--size', default='1440x900')
    asyncio.run(main(ap.parse_args()))
