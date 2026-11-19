# /// script
# requires-python = ">=3.10"
# dependencies = ["playwright==1.63", "pillow==13.0.0"]
# ///
"""Captura de pantalla del mapa con Chromium sin interfaz (Playwright), para revisar cambios.

  uv run tools/screenshot.py shots/centro.png                       # 1440x900, vista inicial
  uv run tools/screenshot.py shots/corte.png --hash corte-apelaciones
  uv run tools/screenshot.py shots/movil.png --size 390x844 --dark --dpr 3
  uv run tools/screenshot.py shots/noche.png --js "document.querySelector('#night').click()"
  uv run tools/screenshot.py shots/ruta.png --hash justicia          # inicia un recorrido
  uv run tools/screenshot.py shots/puente.png --js "__look(-1640,533,6,Math.PI/4+Math.PI)"  # cámara en (x, y) de grilla, zoom, giro
  uv run tools/screenshot.py shots/ --view "plaza=__look(-60,30,14.2)" --view "giro=__look(-60,30,14.2,Math.PI/4+Math.PI/2)"
      # varias vistas de una sola carga (shots/plaza.png, shots/giro.png): genera una vez, no una por captura
  uv run tools/screenshot.py shots/x.png --gl gpu                   # con la GPU del equipo (metal en un Mac; en Linux, egl
                                                                     # o la NVIDIA si está su driver); la carga sigue en la CPU
  uv run tools/screenshot.py shots/smoke.png --strict             # además falla si la generación sale vacía (sin
      # edificios, árboles o vértices) o perdió polígonos (__stats.triFail): es `make smoke`, la prueba de humo del repo

(`uv run tools/x.py` lee las dependencias del encabezado; `uv run --with "playwright==1.63" python tools/x.py` y
`python tools/x.py`, con Playwright instalado, también sirven.)
Sirve dist/ (make build) en un puerto local (la página pide sus datos con fetch, que no funciona desde file://); todo
lo que necesita, three.js incluido, está ahí, así que funciona sin internet salvo las fuentes de Google. --js
(repetible) corre antes de las capturas; después de cada --js y de cada --view espera a que el mapa quede quieto
(window.__idle, Map.settle() de tools/page.py). Imprime las estadísticas de generación (edificios, vértices,
árboles, ms) y la consola. Sale con 1 si hubo errores de consola.
"""
import argparse, asyncio, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from page import Map, add_page_args, parse_views, serve, open_page, GL, ROOT  # noqa: F401 (serve, open_page, GL, ROOT: los importaban otras herramientas)

async def main(a):
    async with Map.from_args(a, dark=a.dark, offline=a.offline, hash=a.hash) as m:
        for js in a.js or []: await m.run(js)
        if a.view:
            out = Path(a.out); out.mkdir(parents=True, exist_ok=True)
            for name, js in parse_views(a.view):
                await m.run(js)
                f = out / f'{name}.png'; await m.page.screenshot(path=str(f)); print('->', f)
        else:
            Path(a.out).parent.mkdir(parents=True, exist_ok=True)
            await m.page.screenshot(path=a.out); print('->', a.out)
        bad = [f'{len(m.errors())} errores de consola'] if m.print_logs(everything=True) else []
        if a.strict:
            st = await m.stats() or {}
            bad += [f'stats.{k} = {st.get(k)}' for k in ('buildings', 'trees', 'verts', 'ground') if not st.get(k)]
            if st.get('triFail'): bad.append(f"stats.triFail = {st['triFail']} (polígonos que triangulate() no pudo dibujar)")
    if bad: raise SystemExit(('smoke: ' if a.strict else 'screenshot: ') + '; '.join(bad))
    if a.strict: print('smoke: ok')

if __name__ == '__main__':
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('out'); ap.add_argument('--hash')
    add_page_args(ap)
    ap.add_argument('--js', action='append', help='JS que corre antes de las capturas (repetible; espera a que el mapa quede quieto)')
    ap.add_argument('--dark', action='store_true')
    ap.add_argument('--view', action='append', help='nombre=expresión JS; varias capturas de una carga (out es un directorio)')
    ap.add_argument('--offline', action='store_true', help='bloquea las fuentes web y todo lo que no sea dist/')
    ap.add_argument('--strict', action='store_true', help='además, código 1 si la generación sale vacía o perdió polígonos (make smoke)')
    asyncio.run(main(ap.parse_args()))
