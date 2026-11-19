# /// script
# requires-python = ">=3.10"
# dependencies = ["pillow==13.0.0", "numpy==2.5.5"]
# ///
"""Un avance («trailer») corto del juego de Godot, con cortes secos al ritmo de la música, cuadros congelados con
color y títulos grandes: shots/trailer/talca.mp4 (H.264 y AAC, ~44 s).

  uv run tools/trailer.py                      # graba las tomas que falten, y arma el video
  uv run tools/trailer.py --solo auto,saltos   # vuelve a grabar esas tomas (las demás, de shots/trailer/<toma>.avi)
  uv run tools/trailer.py --montar             # solo arma el video con las tomas ya grabadas
  uv run tools/trailer.py --size 1920x1080     # otra resolución (1280x720 por omisión; las tomas se vuelven a grabar)

Cada toma es una corrida de Godot con Movie Maker (`--write-movie … --fixed-fps 30 -- --trailer <toma>`), por
tools/godot_oculto.sh (en Linux sin GPU de NVIDIA: GODOT_OCULTO_VK=lavapipe, que este script pone si no hay
nvidia-smi). Las tomas están en juego/trailer.gd (TOMAS); el montaje, en MONTAJE abajo: cada pieza dura un número de
golpes de la música (BPM), y una toma puede terminar en un cuadro congelado con su palabra. La música es propia: un
ritmo sintetizado aquí (bombo, caja, platillo, bajo y un acorde), sin muestras. La tipografía es Anton (SIL OFL), que
se baja una vez a raw/tipografias/. Requiere juego/mapa/ (make juego) y ffmpeg.
"""
import argparse, json, math, os, re, shutil, subprocess, sys, urllib.request, wave
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / 'shots' / 'trailer'
FONT = ROOT / 'raw' / 'tipografias' / 'Anton-Regular.ttf'
FONT_URL = 'https://raw.githubusercontent.com/google/fonts/main/ofl/anton/Anton-Regular.ttf'
FPS = 30
BPM = 96
GOLPE = 60 / BPM  # s

# el montaje: (tipo, golpes, …). «toma»: (toma, golpes de la toma, congelado en golpes o 0, palabra del congelado,
# color del congelado, título encima de la toma o None). «carta»: texto sobre negro (líneas: (texto, tamaño)).
MONTAJE = [
    ('carta', 4, [('UNA CIUDAD ENTERA', 0.11)]),
    ('toma', 'ciudad', 8, 0, None, None, ('TALCA', 'REGIÓN DEL MAULE · CHILE')),
    ('toma', 'auto', 6, 2, 'MANEJA', (230, 70, 60), None),
    ('toma', 'bici', 4, 2, 'PEDALEA', (60, 170, 220), None),
    ('carta', 2, [('232 KM²', 0.13), ('DE CALLES, RÍOS Y CERROS', 0.05)]),
    ('toma', 'saltos', 6, 2, 'SALTA', (245, 190, 40), None),
    ('toma', 'estadio', 6, 0, None, None, ('EL ESTADIO FISCAL', None)),
    ('toma', 'rio', 6, 0, None, None, ('EL RÍO CLARO', None)),
    ('toma', 'cerro', 6, 2, 'EXPLORA', (150, 90, 210), None),
    ('toma', 'noche', 8, 0, None, None, ('DE DÍA Y DE NOCHE', None)),
    ('fin', 8),
]


def sh(cmd, **kw):
    print('$', ' '.join(str(c) for c in cmd)[:240], flush=True)
    return subprocess.run([str(c) for c in cmd], check=True, **kw)


# ---------- las tomas ----------

def grabar(toma, size):
    """Graba una toma con Movie Maker y guarda en <toma>.json los cuadros de la toma (sin los de la carga)."""
    avi = OUT / f'{toma}.avi'
    w, h = size.split('x')
    cfg = ROOT / 'juego' / 'override.cfg'
    cfg.write_text(f'[display]\nwindow/size/viewport_width={w}\nwindow/size/viewport_height={h}\n'
                   '[editor]\nmovie_writer/video_quality=1.0\n')
    env = dict(os.environ)
    if sys.platform.startswith('linux') and not shutil.which('nvidia-smi'):
        env.setdefault('GODOT_OCULTO_VK', 'lavapipe')
    try:
        r = subprocess.run([str(ROOT / 'tools' / 'godot_oculto.sh'), '--path', 'juego', '--write-movie', str(avi),
                            '--fixed-fps', str(FPS), '--', '--trailer', toma, '--sin', 'plano'],
                           cwd=ROOT, env=env, capture_output=True, text=True)
    finally:
        cfg.unlink(missing_ok=True)
    log = r.stdout + r.stderr
    m = re.search(r'trailer\.gd: toma \S+ cuadros (\d+)…(\d+)', log)
    if not m or not avi.exists():
        print(log[-4000:])
        sys.exit(f'trailer.py: la toma {toma} no terminó')
    total = cuadros(avi)
    a, b = int(m[1]), int(m[2])
    # Engine.get_frames_drawn() cuenta desde el primer cuadro dibujado; Movie Maker graba desde el primero también,
    # pero puede haber uno o dos de diferencia: se toma el final del archivo y el largo de la toma
    n = b - a
    meta = {'size': size, 'inicio': max(0, total - n), 'cuadros': n, 'total': total, 'engine': [a, b]}
    (OUT / f'{toma}.json').write_text(json.dumps(meta))
    print(f'trailer.py: {toma}: {n} cuadros (de {total}; Engine {a}…{b})')


def cuadros(video):
    r = subprocess.run(['ffprobe', '-v', 'error', '-count_packets', '-select_streams', 'v:0', '-show_entries',
                        'stream=nb_read_packets', '-of', 'csv=p=0', str(video)], capture_output=True, text=True, check=True)
    return int(r.stdout.strip())


# ---------- lo que va encima (Pillow) ----------

def fuente(px):
    from PIL import ImageFont
    return ImageFont.truetype(str(FONT), int(px))


def barras(img):
    """Las barras de cine (2,39:1)."""
    from PIL import ImageDraw
    W, H = img.size
    b = int((H - W / 2.39) / 2)
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, W, b], fill=(0, 0, 0, 255))
    d.rectangle([0, H - b, W, H], fill=(0, 0, 0, 255))
    return b


def texto(d, xy, s, px, fill=(255, 255, 255), stroke=0.06, anchor='la'):
    f = fuente(px)
    d.text(xy, s, font=f, fill=fill, stroke_width=max(2, int(px * stroke)), stroke_fill=(0, 0, 0), anchor=anchor)


def capa_toma(size, titulo, path):
    from PIL import Image, ImageDraw
    W, H = size
    img = Image.new('RGBA', size, (0, 0, 0, 0))
    b = barras(img)
    if titulo:
        d = ImageDraw.Draw(img)
        grande, chico = titulo
        texto(d, (W * 0.05, H - b - H * 0.05 - (H * 0.05 if chico else 0)), grande, H * 0.11, anchor='ls')
        if chico:
            texto(d, (W * 0.053, H - b - H * 0.04), chico, H * 0.04, fill=(255, 225, 150), anchor='ls')
    img.save(path)


def capa_congelado(size, palabra, color, path):
    """Una franja diagonal del color de la toma con la palabra, como un cartel: sobre el cuadro congelado."""
    from PIL import Image, ImageDraw
    W, H = size
    img = Image.new('RGBA', size, (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    y0, y1 = H * 0.56, H * 0.80
    k = H * 0.10  # la inclinación
    d.polygon([(0, y0 + k), (W, y0 - k), (W, y1 - k), (0, y1 + k)], fill=(*color, 235))
    d.line([(0, y0 + k), (W, y0 - k)], fill=(0, 0, 0, 255), width=max(3, H // 120))
    d.line([(0, y1 + k), (W, y1 - k)], fill=(0, 0, 0, 255), width=max(3, H // 120))
    # la palabra, girada como la franja
    t = Image.new('RGBA', size, (0, 0, 0, 0))
    texto(ImageDraw.Draw(t), (W / 2, (y0 + y1) / 2), palabra, H * 0.2, anchor='mm', stroke=0.05)
    t = t.rotate(math.degrees(math.atan2(2 * k, W)), resample=Image.BICUBIC, center=(W / 2, (y0 + y1) / 2))
    img.alpha_composite(t)
    barras(img)
    img.save(path)


def capa_carta(size, lineas, path):
    from PIL import Image, ImageDraw
    W, H = size
    img = Image.new('RGB', size, (0, 0, 0))
    d = ImageDraw.Draw(img)
    alto = sum(H * t * 1.25 for _, t in lineas)
    y = H / 2 - alto / 2
    for s, t in lineas:
        texto(d, (W / 2, y + H * t * 0.6), s, H * t, anchor='mm', stroke=0)
        y += H * t * 1.25
    img.save(path)


def capa_fin(size, path):
    from PIL import Image, ImageDraw
    W, H = size
    img = Image.new('RGB', size, (0, 0, 0))
    d = ImageDraw.Draw(img)
    texto(d, (W / 2, H * 0.43), 'TALCA', H * 0.30, anchor='mm', stroke=0)
    texto(d, (W / 2, H * 0.62), 'ISOMÉTRICA', H * 0.085, fill=(245, 190, 40), anchor='mm', stroke=0)
    texto(d, (W / 2, H * 0.80), 'talca.eduramirez.com', H * 0.045, fill=(200, 200, 200), anchor='mm', stroke=0)
    img.save(path)


# ---------- la música ----------

def musica(seg, path):
    """Un ritmo de 96 BPM en la menor: bombo, caja, platillo cerrado, bajo de sierra filtrado y un acorde de fondo."""
    import numpy as np
    sr = 44100
    n = int(seg * sr)
    out = np.zeros(n)
    t = np.arange(n) / sr
    rng = np.random.default_rng(7)

    def at(s, sig, g=1.0):
        i = int(s * sr)
        if i >= n:
            return
        m = min(len(sig), n - i)
        out[i:i + m] += sig[:m] * g

    def bombo():
        d = np.arange(int(0.45 * sr)) / sr
        f = 45 + 110 * np.exp(-d * 30)
        return np.sin(2 * np.pi * np.cumsum(f) / sr) * np.exp(-d * 7)

    def caja():
        d = np.arange(int(0.25 * sr)) / sr
        ruido = rng.standard_normal(len(d))
        ruido = np.convolve(ruido, [1, -0.9], 'same')
        return (0.7 * ruido * np.exp(-d * 18) + 0.5 * np.sin(2 * np.pi * 190 * d) * np.exp(-d * 25))

    def platillo(largo=0.05):
        d = np.arange(int(largo * sr)) / sr
        ruido = np.convolve(rng.standard_normal(len(d)), [1, -1], 'same')
        return ruido * np.exp(-d * (60 if largo < 0.1 else 8))

    def nota(f, largo, forma='sierra'):
        d = np.arange(int(largo * sr)) / sr
        if forma == 'sierra':
            s = 2 * ((d * f) % 1) - 1
            s = np.convolve(s, np.ones(18) / 18, 'same')  # un filtro pasa bajos simple
        else:
            s = np.sin(2 * np.pi * f * d) + 0.3 * np.sin(4 * np.pi * f * d)
        env = np.minimum(1, d / 0.01) * np.exp(-d * 1.5)
        return s * env

    hz = lambda m: 440 * 2 ** ((m - 69) / 12)
    # i – VI – III – VII en la menor (La, Fa, Do, Sol), un compás cada uno
    acordes = [(45, [57, 60, 64]), (41, [53, 57, 60]), (48, [55, 60, 64]), (43, [55, 59, 62])]
    golpes = int(seg / GOLPE)
    intro = 4  # el primer compás, solo el acorde
    for g in range(golpes):
        s = g * GOLPE
        bajo, acorde = acordes[(g // 4) % 4]
        final = g >= golpes - 8
        if g % 4 == 0:
            for m in acorde:
                at(s, nota(hz(m), GOLPE * 4, 'seno'), 0.10)
        if g < intro or final and g >= golpes - 4:
            continue
        if g % 2 == 0:
            at(s, bombo(), 0.9)
        if g % 4 == 2:
            at(s + GOLPE * 0.75, bombo(), 0.6)
        if g % 2 == 1:
            at(s, caja(), 0.45)
        for k in range(2):
            at(s + k * GOLPE / 2, platillo(), 0.12 if k else 0.18)
        patron = [0, 0, 12, 0] if g % 4 < 2 else [0, 7, 0, 10]
        at(s, nota(hz(bajo - 12 + patron[g % 4]), GOLPE * 0.9), 0.35)
    at((golpes - 8) * GOLPE, platillo(1.5), 0.25)
    # un golpe final
    at((golpes - 4) * GOLPE, bombo(), 1.0)
    at((golpes - 4) * GOLPE, platillo(1.5), 0.3)
    fin = np.minimum(1, (seg - t) / 1.5).clip(0, 1)
    out *= fin
    out /= max(1e-9, np.abs(out).max()) / 0.85
    pcm = (out * 32767).astype('<i2')
    with wave.open(str(path), 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(sr)
        w.writeframes(pcm.tobytes())


# ---------- el montaje ----------

def montar(size):
    W, H = map(int, size.split('x'))
    tmp = OUT / 'piezas'
    shutil.rmtree(tmp, ignore_errors=True)
    tmp.mkdir(parents=True)
    piezas = []
    enc = ['-c:v', 'libx264', '-preset', 'medium', '-crf', '18', '-pix_fmt', 'yuv420p', '-r', str(FPS), '-an']
    total = 0.0
    for i, p in enumerate(MONTAJE):
        tipo = p[0]
        if tipo in ('carta', 'fin'):
            seg = p[1] * GOLPE
            png = tmp / f'{i:02d}.png'
            capa_carta((W, H), p[2], png) if tipo == 'carta' else capa_fin((W, H), png)
            mp4 = tmp / f'{i:02d}.mp4'
            fade = (f'fade=in:0:d=0.25' if tipo == 'carta' else f'fade=in:0:d=0.4,fade=out:st={seg - 1.5}:d=1.5')
            sh(['ffmpeg', '-y', '-loglevel', 'error', '-loop', '1', '-i', png, '-t', f'{seg:.4f}', '-vf', fade, *enc, mp4])
            piezas.append(mp4); total += seg
            continue
        _, toma, golpes, cong, palabra, color, titulo = p
        meta = json.loads((OUT / f'{toma}.json').read_text())
        avi = OUT / f'{toma}.avi'
        n = round(golpes * GOLPE * FPS)
        fin = meta['inicio'] + meta['cuadros']
        a = max(meta['inicio'], fin - n)  # los últimos n cuadros de la toma
        capa = tmp / f'{i:02d}-capa.png'
        capa_toma((W, H), titulo, capa)
        mp4 = tmp / f'{i:02d}.mp4'
        seg = n / FPS
        # el título entra a la mitad del primer golpe y se va antes del corte
        sh(['ffmpeg', '-y', '-loglevel', 'error', '-i', avi, '-loop', '1', '-i', capa, '-filter_complex',
            f'[0:v]select=between(n\\,{a}\\,{a + n - 1}),setpts=N/{FPS}/TB,scale={W}:{H},'
            f'eq=contrast=1.08:saturation=1.15[v];[1:v]format=rgba,fade=in:st={0.4 if titulo else 0}:d=0.3:alpha=1[c];'
            f'[v][c]overlay=0:0:shortest=1[o]', '-map', '[o]', '-frames:v', n, *enc, mp4])
        piezas.append(mp4); total += seg
        if cong:
            seg = cong * GOLPE
            ult = tmp / f'{i:02d}-ultimo.png'
            sh(['ffmpeg', '-y', '-loglevel', 'error', '-i', avi, '-vf', f'select=eq(n\\,{a + n - 1}),scale={W}:{H}',
                '-frames:v', '1', ult])
            capa = tmp / f'{i:02d}-congelado.png'
            capa_congelado((W, H), palabra, color, capa)
            mp4 = tmp / f'{i:02d}-c.mp4'
            fr = round(seg * FPS)
            # el cuadro congelado: más contraste y color, un acercamiento lento, y la franja que entra de golpe
            sh(['ffmpeg', '-y', '-loglevel', 'error', '-loop', '1', '-i', ult, '-loop', '1', '-i', capa, '-filter_complex',
                f'[0:v]eq=contrast=1.35:saturation=1.7:brightness=0.02,unsharp=5:5:0.8,'
                f'scale={W * 2}:{H * 2},zoompan=z=\'1+0.04*on/{fr}\':x=\'iw/2-iw/zoom/2\':y=\'ih/2-ih/zoom/2\':d=1:s={W}x{H}:fps={FPS}[v];'
                f'[v][1:v]overlay=0:0[o]', '-map', '[o]', '-frames:v', fr, *enc, mp4])
            piezas.append(mp4); total += fr / FPS
    lista = tmp / 'lista.txt'
    lista.write_text(''.join(f"file '{p.name}'\n" for p in piezas))
    video = tmp / 'video.mp4'
    sh(['ffmpeg', '-y', '-loglevel', 'error', '-f', 'concat', '-safe', '0', '-i', lista, '-c', 'copy', video])
    wav = tmp / 'musica.wav'
    musica(total, wav)
    out = OUT / 'talca.mp4'
    sh(['ffmpeg', '-y', '-loglevel', 'error', '-i', video, '-i', wav, '-c:v', 'copy', '-c:a', 'aac', '-b:a', '160k',
        '-shortest', '-movflags', '+faststart', out])
    print(f'-> {out.relative_to(ROOT)} ({total:.1f} s, {out.stat().st_size / 1e6:.1f} MB)')


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--solo', default='', help='tomas que se vuelven a grabar (separadas por comas)')
    ap.add_argument('--montar', action='store_true', help='no graba: solo arma el video')
    ap.add_argument('--size', default='1280x720')
    a = ap.parse_args()
    if not shutil.which('ffmpeg'):
        sys.exit('trailer.py: falta ffmpeg')
    if not (ROOT / 'juego' / 'mapa' / 'indice.json').exists():
        sys.exit('trailer.py: falta juego/mapa/: corra `make juego`')
    OUT.mkdir(parents=True, exist_ok=True)
    if not FONT.exists():
        FONT.parent.mkdir(parents=True, exist_ok=True)
        req = urllib.request.Request(FONT_URL, headers={'User-Agent': 'talca-isometrica'})
        FONT.write_bytes(urllib.request.urlopen(req, timeout=60).read())
    tomas = [p[1] for p in MONTAJE if p[0] == 'toma']
    solo = [s for s in a.solo.split(',') if s]
    for s in solo:
        if s not in tomas:
            sys.exit(f'trailer.py: no hay una toma «{s}» ({", ".join(tomas)})')
    if not a.montar:
        for t in tomas:
            meta = OUT / f'{t}.json'
            vieja = meta.exists() and json.loads(meta.read_text()).get('size') != a.size
            if t in solo or not meta.exists() or vieja:
                grabar(t, a.size)
    montar(a.size)


if __name__ == '__main__':
    main()
