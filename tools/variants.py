"""Hoja de comparación: varias vistas por varias variantes de render, en una sola carga del mapa.

  uv run --with playwright --with pillow python tools/variants.py shots/hoja.png \\
      --view "Plaza:__look(-40,20,14.2)" --view "Barrio:__look(1300,-700,14.2)" \\
      --variant "0,5 m:" --variant "Sin contorno:__pixelArt({m:0.5,outline:0})" --variant "Sin pixel art:__pixelArt(null)" \\
      --reset "__pixelArt({m:0.5})" [--clip 380,0,1060,900] [--scale 0.5] [--no-labels]

Cada fila es una vista (JS que mueve la cámara) y cada columna una variante (JS que cambia el render);
antes de cada variante corre --reset. La hoja lleva los nombres de filas y columnas, y recorta cada
captura a --clip (x,y,ancho,alto) sin la interfaz (panel, ficha, controles, lector; --no-labels quita
también marcadores y nombres de calles). Abre la página con open_page() de screenshot.py.
"""
import argparse, asyncio
from pathlib import Path
from playwright.async_api import async_playwright
from screenshot import open_page

HIDE = '#panel,#card,#readout,#scale,.ctrls{display:none!important}'

async def main(a):
    from PIL import Image, ImageDraw, ImageFont
    views = [v.split(':', 1) for v in a.view]; variants = [v.split(':', 1) for v in a.variant]
    x, y, w, h = map(int, a.clip.split(','))
    shots = {}
    async with async_playwright() as p:
        b, pg, logs = await open_page(p, a.size)
        await pg.add_style_tag(content=HIDE + ('#overlay{display:none!important}' if a.no_labels else ''))
        for vi, (vn, vjs) in enumerate(views):
            for ci, (cn, cjs) in enumerate(variants):
                if a.reset: await pg.evaluate(a.reset)
                await pg.evaluate(vjs); await pg.wait_for_timeout(800)
                if cjs:
                    r = await pg.evaluate(cjs)
                    if isinstance(r, (int, float)) and r: print(f'{vn} / {cn}: {r:.2f} m por píxel')
                await pg.wait_for_timeout(a.wait)
                path = Path(a.out).with_suffix(f'.{vi}-{ci}.png')
                await pg.screenshot(path=str(path), clip={'x': x, 'y': y, 'width': w, 'height': h})
                shots[vi, ci] = path; print('·', vn, '/', cn)
        for l in logs:
            if 'GL Driver' not in l: print(l)
        await b.close()
    tw, th = int(w * a.scale), int(h * a.scale); left, top, gap = 110, 34, 8
    sheet = Image.new('RGB', (left + len(variants) * (tw + gap), top + len(views) * (th + gap)), '#F4F1E8')
    d = ImageDraw.Draw(sheet)
    try: font = ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial.ttf', 16)
    except OSError: font = ImageFont.load_default()
    for ci, (cn, _) in enumerate(variants): d.text((left + ci * (tw + gap) + 4, 8), cn, fill='#222', font=font)
    for vi, (vn, _) in enumerate(views):
        d.text((8, top + vi * (th + gap) + th // 2 - 8), vn, fill='#222', font=font)
        for ci in range(len(variants)):
            im = Image.open(shots[vi, ci]).convert('RGB').resize((tw, th), Image.NEAREST)
            sheet.paste(im, (left + ci * (tw + gap), top + vi * (th + gap)))
            if not a.keep: shots[vi, ci].unlink()
    Path(a.out).parent.mkdir(parents=True, exist_ok=True); sheet.save(a.out); print('->', a.out, sheet.size)

if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('out'); ap.add_argument('--size', default='1440x900')
    ap.add_argument('--view', action='append', required=True, help='"Nombre:JS que mueve la cámara"')
    ap.add_argument('--variant', action='append', required=True, help='"Nombre:JS que cambia el render" (vacío: tal cual)')
    ap.add_argument('--reset', help='JS que deshace las variantes, antes de cada una')
    ap.add_argument('--clip', default='380,0,1060,900'); ap.add_argument('--scale', type=float, default=0.5)
    ap.add_argument('--wait', type=int, default=1500, help='ms tras cada variante')
    ap.add_argument('--no-labels', action='store_true'); ap.add_argument('--keep', action='store_true', help='guarda también cada captura')
    asyncio.run(main(ap.parse_args()))
