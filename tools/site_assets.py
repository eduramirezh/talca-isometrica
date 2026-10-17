"""Imágenes del sitio publicado (talca.eduramirez.com) en src/site/, que build.py --standalone copia a dist/.

  python tools/site_assets.py og      # src/site/og.jpg: la imagen de Open Graph (1200 × 630) desde el mapa, sin el panel
  python tools/site_assets.py icon    # src/site/apple-touch-icon.png (180 × 180) desde src/site/favicon.svg
  python tools/site_assets.py poster  # src/site/poster-movil.webp y poster-escritorio.webp: la vista inicial, sin interfaz
  python tools/site_assets.py         # las tres (make site-assets)

El póster es la imagen que la página muestra mientras genera la maqueta (trampa «El póster del arranque» en CLAUDE.md):
la vista inicial (homeView()) sin panel, marcadores ni etiquetas, con la Plaza de Armas al centro de la imagen. La
página lo escala a la altura del mapa (la vista inicial muestra los mismos metros de alto en cualquier pantalla) y
lo corre a la derecha del panel como homeView(). build.py lo enlaza en dist/index.html y lo incrusta (data:) en
dist/talca.html. Vuelva a correrlo cuando cambie lo que se ve desde la vista inicial, o la página mostrará un
póster viejo durante el arranque. Necesita Pillow para el WebP: uv run --with "playwright==1.63" --with pillow …

Usa dist/index.html (make build) y Playwright, como tools/screenshot.py (sin Playwright en el Python del sistema:
uv run --with "playwright==1.63" python tools/site_assets.py). Vuelva a correrlo cuando cambie la vista de la
imagen (OG_VIEW) o el ícono, y suba el resultado: las imágenes van en git, no se generan al publicar.
"""
import asyncio, sys
from pathlib import Path
from playwright.async_api import async_playwright
sys.path.insert(0, str(Path(__file__).resolve().parent))
from screenshot import open_page

ROOT = Path(__file__).resolve().parent.parent
SITE = ROOT / 'src' / 'site'
# la vista de la imagen: la Plaza de Armas y el barrio cívico de la Alameda, sin nombres de calles; con el encabezado y los marcadores, sin panel
OG_VIEW = "document.querySelector('#streets').click(),__look(-40,230,5.5)"
HIDE = "for(const s of ['#panel','.ctrls','#more','#scale','#card'])for(const e of document.querySelectorAll(s))e.style.display='none'"

async def og(p):
    b, pg, logs = await open_page(p, '1200x630')
    await pg.evaluate(HIDE); await pg.evaluate(OG_VIEW); await pg.wait_for_timeout(3000)
    await pg.screenshot(path=str(SITE / 'og.jpg'), type='jpeg', quality=80); await b.close()
    for l in logs:
        if l.startswith(('error', 'ERROR')): print(l)
    print('->', (SITE / 'og.jpg').relative_to(ROOT))

# the posters: (name, CSS viewport, device pixel ratio, WebP quality). The page scales them to the map's height, so
# each one is wider than the screens it covers: the phone's up to 430 × 932 (and narrower), the desktop's up to an
# aspect of 2.2 with the panel (21:9 shows the stage's background at the left edge)
POSTERS = [('movil', '480x900', 2, 72), ('escritorio', '2400x1000', 1, 76)]
HIDE_ALL = HIDE.replace("'#card'", "'#card','#overlay','.brand'")

async def poster(p):
    import io
    from PIL import Image
    for name, size, dpr, q in POSTERS:
        b, pg, logs = await open_page(p, size, dpr=dpr)
        # without the panel, homeView() leaves the plaza in the middle of the screen (the page moves the image, ox)
        await pg.evaluate(HIDE_ALL); await pg.evaluate('__home()'); await pg.wait_for_timeout(3000)
        png = await pg.screenshot(); await b.close()
        f = SITE / f'poster-{name}.webp'
        Image.open(io.BytesIO(png)).convert('RGB').save(f, 'WEBP', quality=q, method=6)
        for l in logs:
            if l.startswith(('error', 'ERROR')): print(l)
        print('->', f.relative_to(ROOT), f'{f.stat().st_size // 1024} KB')

async def icon(p):
    b = await p.chromium.launch(); pg = await b.new_page(viewport={'width': 180, 'height': 180})
    svg = (SITE / 'favicon.svg').read_text()
    # fondo opaco (iOS no acepta transparencia) y el ícono en 160 px, múltiplo de 16 para que los píxeles queden enteros
    await pg.set_content(f'<body style="margin:0;background:#F3F4EF;display:grid;place-items:center;height:180px">'
                         f'<div style="width:160px;height:160px">{svg.replace("<svg ", "<svg width=160 height=160 ")}</div>')
    await pg.screenshot(path=str(SITE / 'apple-touch-icon.png')); await b.close()
    print('->', (SITE / 'apple-touch-icon.png').relative_to(ROOT))

async def main(what):
    async with async_playwright() as p:
        if what in ('icon', 'all'): await icon(p)
        if what in ('og', 'all'): await og(p)
        if what in ('poster', 'all'): await poster(p)

if __name__ == '__main__':
    asyncio.run(main(sys.argv[1] if len(sys.argv) > 1 else 'all'))
