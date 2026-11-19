# /// script
# requires-python = ">=3.10"
# dependencies = ["playwright==1.63", "pillow==13.0.0"]
# ///
"""Imágenes del sitio publicado (talca.eduramirez.com) en src/site/, que build.py copia a dist/.

  uv run tools/site_assets.py og      # src/site/og.jpg: la imagen de Open Graph (1200 × 630) desde el mapa, sin el panel
  uv run tools/site_assets.py icon    # src/site/apple-touch-icon.png (180 × 180) desde src/site/favicon.svg
  uv run tools/site_assets.py poster  # src/site/poster-movil.webp y poster-escritorio.webp: la vista inicial, sin interfaz
  uv run tools/site_assets.py         # las tres (make site-assets); varias: og poster

El póster es la imagen que la página muestra mientras genera la maqueta (trampa «El póster del arranque» en CLAUDE.md):
la vista inicial (homeView()) sin panel, marcadores ni etiquetas, con la Plaza de Armas al centro de la imagen. La
página lo escala a la altura del mapa (la vista inicial muestra los mismos metros de alto en cualquier pantalla) y
lo corre a la derecha del panel como homeView(); src/page.html lo enlaza. Vuelva a correrlo cuando cambie lo que se
ve desde la vista inicial, o la página mostrará un póster viejo durante el arranque. Necesita Pillow para el WebP
(`uv run` lo trae, del encabezado).

Usa dist/index.html (make build) y Map de tools/page.py (cada imagen se toma cuando el mapa quedó quieto). Vuelva a
correrlo cuando cambie la vista de la imagen (OG_VIEW) o el ícono, y suba el resultado: las imágenes van en git, no
se generan al publicar. Sale con 1 si hubo errores de consola.
"""
import argparse, asyncio, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from page import Map, ROOT, add_page_args, launch

SITE = ROOT / 'src' / 'site'
# la vista de la imagen: la Plaza de Armas y el barrio cívico de la Alameda, sin nombres de calles; con el encabezado y los marcadores, sin panel
OG_VIEW = "document.querySelector('#streets').click(),__look(-40,230,5.5)"

async def og(p, gl):
    async with Map('1200x630', gl=gl, p=p) as m:
        await m.hide(); await m.run(OG_VIEW)
        await m.page.screenshot(path=str(SITE / 'og.jpg'), type='jpeg', quality=80)
    print('->', (SITE / 'og.jpg').relative_to(ROOT))
    return m.print_logs()

# the posters: (name, CSS viewport, device pixel ratio, WebP quality). The page scales them to the map's height, so
# each one is wider than the screens it covers: the phone's up to 430 × 932 (and narrower), the desktop's up to an
# aspect of 2.2 with the panel (21:9 shows the stage's background at the left edge)
POSTERS = [('movil', '480x900', 2, 72), ('escritorio', '2400x1000', 1, 76)]
async def poster(p, gl):
    import io
    from PIL import Image
    bad = []
    for name, size, dpr, q in POSTERS:
        async with Map(size, dpr, gl=gl, p=p) as m:
            # without the panel, homeView() leaves the plaza in the middle of the screen (the page moves the image, ox)
            await m.hide(overlay=True, brand=True); await m.run('__home()')
            png = await m.page.screenshot()
        f = SITE / f'poster-{name}.webp'
        Image.open(io.BytesIO(png)).convert('RGB').save(f, 'WEBP', quality=q, method=6)
        print('->', f.relative_to(ROOT), f'{f.stat().st_size // 1024} KB')
        bad += m.print_logs()
    return bad

async def icon(p, gl):
    b = await launch(p, gl); pg = await b.new_page(viewport={'width': 180, 'height': 180})
    svg = (SITE / 'favicon.svg').read_text()
    # fondo opaco (iOS no acepta transparencia) y el ícono en 160 px, múltiplo de 16 para que los píxeles queden enteros
    await pg.set_content(f'<body style="margin:0;background:#F3F4EF;display:grid;place-items:center;height:180px">'
                         f'<div style="width:160px;height:160px">{svg.replace("<svg ", "<svg width=160 height=160 ")}</div>')
    await pg.screenshot(path=str(SITE / 'apple-touch-icon.png')); await b.close()
    print('->', (SITE / 'apple-touch-icon.png').relative_to(ROOT))
    return []

TARGETS = {'icon': icon, 'og': og, 'poster': poster}

async def main(a):
    from playwright.async_api import async_playwright
    bad = []
    async with async_playwright() as p:
        for t in a.que or list(TARGETS): bad += await TARGETS[t](p, a.gl)
    if bad: raise SystemExit(f'site_assets: {len(bad)} errores de consola')

if __name__ == '__main__':
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('que', nargs='*', choices=list(TARGETS), help='qué imágenes (por omisión, todas)')
    add_page_args(ap, only=('gl',))
    asyncio.run(main(ap.parse_args()))
