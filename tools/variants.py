# /// script
# requires-python = ">=3.10"
# dependencies = ["playwright==1.63", "pillow==13.0.0"]
# ///
"""Hoja de comparación: varias vistas por varias variantes de render, en una sola carga del mapa.

  uv run tools/variants.py shots/hoja.png \\
      --view "Plaza=__look(-40,20,14.2)" --view "Barrio=__look(1300,-700,14.2)" \\
      --variant "0,5 m=" --variant "Sin contorno=__pixelArt({m:0.5,outline:0})" --variant "Sin pixel art=__pixelArt(null)" \\
      --reset "__pixelArt({m:0.5})" [--clip 380,0,1060,900] [--scale 0.5] [--no-labels]
  uv run tools/variants.py shots/pliegues.png --size 390x844 --dpr 2 --clip 0,0,390,844 \\
      --view "Plaza=__look(-60,30,4)" --variant "Normales=__pixelArt({m:0.5,crease:'normals'})" --variant "Profundidad=" --diff

Cada fila es una vista (nombre=JS que mueve la cámara) y cada columna una variante (nombre=JS que cambia el render;
la forma vieja «Nombre:JS» sirve, con un aviso); antes de cada variante corre --reset, y cada captura espera a que el
mapa quede quieto (Map.settle() de tools/page.py; --wait agrega ms). La hoja lleva los nombres de filas y columnas, y recorta cada
captura a --clip (x,y,ancho,alto, en píxeles CSS) sin la interfaz (panel, ficha, controles, lector; --no-labels quita
también marcadores y nombres de calles). --dpr da la densidad de la pantalla (un teléfono: 2 o 3). Con --diff, cada
variante después de la primera se compara píxel a píxel con la primera de su fila: imprime el porcentaje de píxeles
distintos (algún canal difiere en más de 8) y agrega una columna «Δ» con esos píxeles en magenta sobre la captura en
gris (diff() de page.py). Abre la página con Map de tools/page.py (--gl gpu: la GPU del equipo). Sale con 1 si hubo
errores de consola.
"""
import argparse, asyncio, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from page import Map, add_page_args, parse_views, diff

# the sheet's labels: Arial on a Mac, DejaVu or Liberation on Linux; Pillow's own font, tiny, if none is there
FONTS = ['/System/Library/Fonts/Supplemental/Arial.ttf', '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
         '/usr/share/fonts/dejavu-sans-fonts/DejaVuSans.ttf', '/usr/share/fonts/TTF/DejaVuSans.ttf',
         '/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf']

def diff_tile(a, b, name):
    """The pixels where b differs from a, in magenta over a in grey (diff()); prints their share."""
    share, n, img = diff(a, b)
    print(f'{name}: ' + ('tamaños distintos' if n is None else f'{share:.2f} % de píxeles distintos'))
    return img

async def main(a):
    from PIL import Image, ImageDraw, ImageFont
    views, variants = parse_views(a.view), parse_views(a.variant, '--variant')
    x, y, w, h = map(int, a.clip.split(','))
    shots = {}
    async with Map.from_args(a) as m:
        await m.hide(overlay=a.no_labels)
        for vi, (vn, vjs) in enumerate(views):
            for ci, (cn, cjs) in enumerate(variants):
                if a.reset: await m.page.evaluate(a.reset)
                await m.page.evaluate(vjs)
                if cjs:
                    r = await m.page.evaluate(cjs)
                    if isinstance(r, (int, float)) and r: print(f'{vn} / {cn}: {r:.2f} m por píxel')
                await m.settle()
                if a.wait: await m.page.wait_for_timeout(a.wait)
                path = Path(a.out).with_suffix(f'.{vi}-{ci}.png')
                await m.page.screenshot(path=str(path), clip={'x': x, 'y': y, 'width': w, 'height': h})
                shots[vi, ci] = path; print('·', vn, '/', cn)
        bad = m.print_logs()
    tw, th = int(w * a.dpr * a.scale), int(h * a.dpr * a.scale); left, top, gap = 110, 34, 8
    cols = [cn for cn, _ in variants] + ([f'Δ {cn}' for cn, _ in variants[1:]] if a.diff else [])
    sheet = Image.new('RGB', (left + len(cols) * (tw + gap), top + len(views) * (th + gap)), '#F4F1E8')
    d = ImageDraw.Draw(sheet)
    font = None
    for f in FONTS:
        try: font = ImageFont.truetype(f, 16); break
        except OSError: pass
    font = font or ImageFont.load_default()
    for ci, cn in enumerate(cols): d.text((left + ci * (tw + gap) + 4, 8), cn, fill='#222', font=font)
    for vi, (vn, _) in enumerate(views):
        d.text((8, top + vi * (th + gap) + th // 2 - 8), vn, fill='#222', font=font)
        ims = [Image.open(shots[vi, ci]).convert('RGB') for ci in range(len(variants))]
        tiles = [im.resize((tw, th), Image.NEAREST) for im in ims]
        if a.diff:
            for ci in range(1, len(variants)):
                tiles.append(diff_tile(ims[0], ims[ci], f'{vn} / {variants[ci][0]}').resize((tw, th), Image.NEAREST))
        for ci, im in enumerate(tiles): sheet.paste(im, (left + ci * (tw + gap), top + vi * (th + gap)))
        if not a.keep:
            for ci in range(len(variants)): shots[vi, ci].unlink()
    Path(a.out).parent.mkdir(parents=True, exist_ok=True); sheet.save(a.out); print('->', a.out, sheet.size)
    if bad: raise SystemExit(f'variants: {len(bad)} errores de consola')

if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('out'); add_page_args(ap)
    ap.add_argument('--view', action='append', required=True, help='"Nombre=JS que mueve la cámara"')
    ap.add_argument('--variant', action='append', required=True, help='"Nombre=JS que cambia el render" (vacío: tal cual)')
    ap.add_argument('--reset', help='JS que deshace las variantes, antes de cada una')
    ap.add_argument('--clip', default='380,0,1060,900'); ap.add_argument('--scale', type=float, default=0.5)
    ap.add_argument('--wait', type=int, default=0, help='ms más tras cada variante, después de que el mapa quedó quieto')
    ap.add_argument('--diff', action='store_true', help='compara cada variante con la primera de su fila')
    ap.add_argument('--no-labels', action='store_true'); ap.add_argument('--keep', action='store_true', help='guarda también cada captura')
    asyncio.run(main(ap.parse_args()))
