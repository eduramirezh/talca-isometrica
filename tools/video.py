"""Video vertical del mapa para una historia de Instagram (1080x1920, H.264, 30 cuadros por segundo): se acerca a un punto
mientras empieza a girar, da una vuelta de día, pasa a la noche con un fundido sin dejar de girar y se aleja de noche
para mostrar las luces de la ciudad; el giro se detiene suave al final. Es el GIF de tools/gif.py, en alta calidad.

  uv run --with "playwright==1.63" --with pillow python tools/video.py shots/historia.mp4
  uv run --with "playwright==1.63" --with pillow python tools/video.py shots/historia.mp4 --center 0,0 --from 1.6 \\
      --zoom 6 --to 2.6 --intro 3.5 --day 8 --fade 1.5 --night 5 --speed 36 [--url ''] [--labels] [--no-brand]
  uv run --with "playwright==1.63" --with pillow python tools/video.py shots/h/ --stills   # solo cuadros sueltos (PNG)

--size es la ventana en píxeles CSS y --dpr su densidad: 540x960 a 2 da 1080x1920, con la interfaz de teléfono de la
página. Sin la interfaz (panel, ficha, controles, escala) y, salvo --labels, sin marcadores ni nombres de calles; el
título va centrado y la dirección del sitio (--url; '' la quita) abajo, los dos dentro de la zona que no tapan los
controles de Instagram (~250 px arriba y ~340 abajo de 1920). Los tiempos van en segundos: --intro (acercarse de
--from a --zoom), --day, --fade (el fundido de día a noche: cada cuadro se dibuja de día y de noche y se mezclan) y
--night (alejarse a --to); --speed son grados de giro por segundo. --stills escribe un PNG cada --every cuadros en
vez del video, para revisar el encuadre en segundos. --crf 18 con --maxrate 16 (Mbit/s) dan ~35 MB por 18 s: Instagram
lo vuelve a comprimir a unos pocos Mbit/s, y sin tope un giro de pixel art pasa de 90 MB.
Usa la GPU del Mac (Chromium con ANGLE sobre Metal, ~0,2 s por cuadro; --gl swiftshader sin GPU, ~6 veces más lento)
y ffmpeg (brew install ffmpeg). Abre la página con open_page() de screenshot.py (necesita dist/: make build). Los
trenes corren con el reloj: entre dos cuadros pasa más tiempo que en el video, así que saltan.
"""
import argparse, asyncio, io, math, subprocess
from pathlib import Path
from playwright.async_api import async_playwright
from screenshot import open_page

HIDE = '#panel,#card,#more,#scale,.ctrls{display:none!important}'
# El título centrado bajo la zona del nombre de la cuenta y la barra de progreso; la dirección sobre la de responder.
STORY = ('.brand{left:50%;top:13%;transform:translateX(-50%);text-align:center;max-width:none;white-space:nowrap;padding:12px 20px 13px}'
         '.brand h1{font-size:44px}.brand p{font-size:12px;margin-top:8px}'
         '#story-url{position:absolute;left:50%;bottom:21%;transform:translateX(-50%);z-index:5;font-family:var(--mono);font-size:15px;'
         'letter-spacing:.06em;color:var(--ink);background:color-mix(in srgb,var(--paper) 86%,transparent);padding:7px 14px;border-radius:4px;'
         'backdrop-filter:blur(3px)}')

def ease(t): t = min(max(t, 0), 1); return t * t * (3 - 2 * t)
def logz(a, b, t): return math.exp(math.log(a) + (math.log(b) - math.log(a)) * ease(t))

def timeline(a):
    """(zoom, giro, noche 0..1) de cada cuadro. El giro acelera en los primeros 2 s y frena en los últimos 2 s."""
    t1 = a.intro; t2 = t1 + a.day; t3 = t2 + a.fade; T = t3 + a.night
    n = round(T * a.fps); ramp = min(2, T / 4); w = math.radians(a.speed)
    out, az = [], math.pi / 4
    for i in range(n):
        t = i / a.fps
        z = logz(a.start, a.zoom, t / t1) if t < t1 else a.zoom if t < t3 else logz(a.zoom, a.end, (t - t3) / a.night)
        night = 0 if t < t2 else 1 if t >= t3 else ease((t - t2) / a.fade)
        out.append((z, az, night))
        az += w / a.fps * ease(t / ramp) * ease((T - t) / ramp)
    return out

async def main(a):
    from PIL import Image
    x, y = map(float, a.center.split(','))
    css = HIDE + STORY + ('' if a.labels else '#overlay{display:none!important}') + ('.brand{display:none!important}' if a.no_brand else '')
    frames = timeline(a)
    w, h = (round(int(v) * a.dpr) for v in a.size.split('x'))
    out = Path(a.out)
    if a.stills: out.mkdir(parents=True, exist_ok=True)
    else:
        out.parent.mkdir(parents=True, exist_ok=True)
        enc = subprocess.Popen(['ffmpeg', '-v', 'error', '-y', '-f', 'image2pipe', '-framerate', str(a.fps), '-c:v', 'png', '-i', '-',
                                '-c:v', 'libx264', '-preset', 'slow', '-crf', str(a.crf), '-maxrate', f'{a.maxrate}M', '-bufsize', f'{2 * a.maxrate}M', '-pix_fmt', 'yuv420p', '-profile:v', 'high',
                                '-vf', f'scale={w}:{h}:flags=neighbor', '-movflags', '+faststart', str(out)], stdin=subprocess.PIPE)
    async with async_playwright() as p:
        b, pg, logs = await open_page(p, a.size, dpr=a.dpr, gl=a.gl)
        await pg.add_style_tag(content=css)
        if a.url: await pg.evaluate('u=>{const d=document.createElement("div");d.id="story-url";d.textContent=u;document.body.append(d)}', a.url)
        await pg.evaluate('document.fonts.ready')
        state = {'night': False}
        async def shot(zoom, az, night):
            if night != state['night']:
                await pg.evaluate("document.querySelector('#night').click()"); state['night'] = night
            await pg.evaluate(f'__look({x},{y},{zoom},{az})')
            await pg.evaluate('new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r)))')
            return await pg.screenshot()
        for i, (z, az, n) in enumerate(frames):
            if a.stills and i % a.every and i != len(frames) - 1: continue
            if n in (0, 1): png = await shot(z, az, n == 1)
            else:  # el fundido: el mismo cuadro de día y de noche, mezclados
                day = Image.open(io.BytesIO(await shot(z, az, False))).convert('RGB')
                nig = Image.open(io.BytesIO(await shot(z, az, True))).convert('RGB')
                buf = io.BytesIO(); Image.blend(day, nig, n).save(buf, 'PNG', compress_level=1); png = buf.getvalue()
            if a.stills: (out / f'{i:04d}.png').write_bytes(png)
            else: enc.stdin.write(png)
            if i % 60 == 0: print(f'{i}/{len(frames)}', flush=True)
        for l in logs:
            if l.startswith(('ERROR:', 'error:')): print(l)
        await b.close()
    if a.stills: print(f'-> {out}/'); return
    enc.stdin.close()
    if enc.wait(): raise SystemExit('ffmpeg falló')
    print(f'-> {out}: {len(frames)} cuadros, {len(frames) / a.fps:.1f} s, {w}x{h}, {out.stat().st_size / 1e6:.1f} MB')

if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('out'); ap.add_argument('--size', default='540x960'); ap.add_argument('--dpr', type=float, default=2)
    ap.add_argument('--center', default='0,0', help='x,y de grilla del punto al que se acerca y alrededor del que gira')
    ap.add_argument('--from', dest='start', type=float, default=1.6, help='zoom inicial')
    ap.add_argument('--zoom', type=float, default=6, help='zoom de la vuelta de día')
    ap.add_argument('--to', dest='end', type=float, default=2.6, help='zoom final, de noche')
    ap.add_argument('--intro', type=float, default=3.5); ap.add_argument('--day', type=float, default=8)
    ap.add_argument('--fade', type=float, default=1.5); ap.add_argument('--night', type=float, default=5)
    ap.add_argument('--speed', type=float, default=36, help='grados de giro por segundo')
    ap.add_argument('--fps', type=int, default=30); ap.add_argument('--crf', type=int, default=18)
    ap.add_argument('--maxrate', type=float, default=16, help='Mbit/s como máximo')
    ap.add_argument('--url', default='talca.eduramirez.com'); ap.add_argument('--gl', default='metal', choices=['metal', 'swiftshader'])
    ap.add_argument('--labels', action='store_true'); ap.add_argument('--no-brand', action='store_true')
    ap.add_argument('--stills', action='store_true'); ap.add_argument('--every', type=int, default=45)
    asyncio.run(main(ap.parse_args()))
