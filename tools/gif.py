"""GIF animado del mapa para mostrarlo (un correo, una presentación): se acerca a un punto, da una vuelta completa de
día, pasa a la noche con un fundido, sigue girando de noche y vuelve fundido al primer cuadro, para que el GIF se repita
sin salto.

  uv run --with "playwright==1.63" --with pillow python tools/gif.py shots/talca.gif
  uv run --with "playwright==1.63" --with pillow python tools/gif.py shots/talca.gif --center 0,0 --zoom 9 --from 2.2 \\
      --size 640x400 --turn 32 --night 90 --fps 10 --colors 256 [--labels] [--no-brand]

Cada cuadro mueve la cámara con __look(x, y, zoom, giro) y espera dos cuadros de la página antes de capturar; la noche
es el botón #night. Sin la interfaz (panel, ficha, controles, escala) y, salvo --labels, sin marcadores ni nombres de
calles; --no-brand quita también el título. --turn: cuadros por vuelta de día; --night: grados de giro de noche (a la
misma velocidad). Cada cuadro lleva su propia paleta (--colors), sin tramado (el pixel art se comprime mejor así). El peso va con los
píxeles por los cuadros (un giro cambia la imagen entera; menos colores casi no lo baja): 800x500 con 48 cuadros por
vuelta pesa ~22 MB, 640x400 con 32, ~7 MB.
Abre la página con open_page() de screenshot.py (necesita dist/: make build); ~1 s por cuadro con SwiftShader.
"""
import argparse, asyncio, io, math
from pathlib import Path
from playwright.async_api import async_playwright
from screenshot import open_page

HIDE = '#panel,#card,#more,#scale,.ctrls{display:none!important}'
FADE = 5  # cuadros de cada fundido

def ease(t): return t * t * (3 - 2 * t)

async def main(a):
    from PIL import Image
    x, y = map(float, a.center.split(','))
    hide = HIDE + ('' if a.labels else '#overlay{display:none!important}') + ('.brand{display:none!important}' if a.no_brand else '')
    az0 = math.pi / 4
    async with async_playwright() as p:
        b, pg, logs = await open_page(p, a.size)
        await pg.add_style_tag(content=hide)
        async def shot(zoom, az):
            await pg.evaluate(f'__look({x},{y},{zoom},{az})')
            await pg.evaluate('new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r)))')
            return Image.open(io.BytesIO(await pg.screenshot())).convert('RGB')
        frames, hold = [], []  # hold: cuadros que duran más (el comienzo de cada parte)
        n = a.zoom_frames
        for i in range(n):  # acercarse: el zoom en escala logarítmica, suavizado
            z = math.exp(math.log(a.start) + (math.log(a.zoom) - math.log(a.start)) * ease(i / (n - 1)))
            frames.append(await shot(z, az0))
            if i in (0, n - 1): hold.append(len(frames) - 1)
        for i in range(1, a.turn + 1):  # una vuelta de día
            frames.append(await shot(a.zoom, az0 + 2 * math.pi * i / a.turn))
        day = frames[-1]
        await pg.evaluate("document.querySelector('#night').click()")
        night = await shot(a.zoom, az0)
        frames += [Image.blend(day, night, (k + 1) / (FADE + 1)) for k in range(FADE)]
        frames.append(night); hold.append(len(frames) - 1)
        steps = round(a.turn * a.night / 360)
        for i in range(1, steps + 1):  # de noche
            frames.append(await shot(a.zoom, az0 + math.radians(a.night) * i / steps))
        last = frames[-1]
        frames += [Image.blend(last, frames[0], (k + 1) / (FADE + 1)) for k in range(FADE)]
        for l in logs:
            if l.startswith(('ERROR:', 'error:')): print(l)
        await b.close()
    ms = round(1000 / a.fps)
    dur = [ms * 8 if i in hold else ms for i in range(len(frames))]
    pal = [f.quantize(a.colors, dither=Image.Dither.NONE) for f in frames]
    Path(a.out).parent.mkdir(parents=True, exist_ok=True)
    pal[0].save(a.out, save_all=True, append_images=pal[1:], duration=dur, loop=0, optimize=True, disposal=1)
    print(f'-> {a.out}: {len(frames)} cuadros, {sum(dur) / 1000:.1f} s, {Path(a.out).stat().st_size / 1e6:.1f} MB')

if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('out'); ap.add_argument('--size', default='640x400')
    ap.add_argument('--center', default='0,0', help='x,y de grilla del punto al que se acerca y alrededor del que gira')
    ap.add_argument('--zoom', type=float, default=9); ap.add_argument('--from', dest='start', type=float, default=2.2, help='zoom inicial')
    ap.add_argument('--zoom-frames', type=int, default=12); ap.add_argument('--turn', type=int, default=32)
    ap.add_argument('--night', type=float, default=90, help='grados de giro de noche')
    ap.add_argument('--fps', type=float, default=10); ap.add_argument('--colors', type=int, default=256)
    ap.add_argument('--labels', action='store_true'); ap.add_argument('--no-brand', action='store_true')
    asyncio.run(main(ap.parse_args()))
