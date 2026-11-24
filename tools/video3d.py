# /// script
# requires-python = ">=3.10"
# dependencies = ["pillow==13.0.0"]
# ///
"""Un video de la maqueta en 3D por un recorrido de cámara escrito como datos: shots/video3d/talca-3d.mp4 (H.264,
yuv420p, sin audio, 1920x1080 a 30 cuadros por segundo; --vertical, además, talca-3d-vertical.mp4 de 1080x1920).

  uv run tools/video3d.py                      # graba las tomas que falten o cambiaron, y arma el video (make video3d)
  uv run tools/video3d.py --cuadros            # solo cuadros sueltos de cada toma (PNG) y una hoja, en segundos
  uv run tools/video3d.py --cuadros --solo autos --instantes 0,2.5,5.5   # los de una toma, en esos segundos
  uv run tools/video3d.py --solo plaza,torre   # vuelve a grabar esas tomas (las demás, de shots/video3d/tomas/)
  uv run tools/video3d.py --montar             # solo arma el video con las tomas ya grabadas
  uv run tools/video3d.py --vertical           # además, el corte vertical (otras tomas: más altas que anchas)

El corte vertical graba cada toma otra vez a 1080x1920, con el mismo ancho de vista que el horizontal y las claves de
«claves_vertical» si la toma las tiene (si no, las de 16:9). En noviembre de 2026 ninguna las tiene y el encuadre de
16:9 no sirve tal cual (la Torre Talca queda fuera del cuadro): falta encuadrarlo con --cuadros --vertical.

Lo que se ve está en config/video3d.json: la apertura (el mapa isométrico de la página, con tools/video.py), las tomas
en orden, cada una con sus claves de cámara (el punto que se mira en metros de grilla, giro, inclinación, distancia),
su duración, la hora al comenzar y al terminar y su texto, y el cierre. Editar el video es editar ese archivo; el
formato de una toma está en el encabezado de modelo3d/recorrido.gd.

Cada toma es una corrida de Godot con Movie Maker (`--write-movie toma.avi --fixed-fps 30 -- --recorrido toma.json`),
por tools/godot_oculto.sh (Godot nunca a la vista). El tamaño de lo que graba es el de la ventana del proyecto
(--resolution no lo cambia): este script escribe modelo3d/override.cfg con el tamaño y la calidad del MJPEG (1,0: con
la de omisión, 0,75, las copas oscuras y el cielo de noche salen con una grilla de 8 × 8) y lo borra al terminar.
Movie Maker graba también los cuadros de la carga: recorrido.gd imprime cuántos son de la toma y se toman esos, del
final. Cada toma se revisa (congelada(): tramos sin cambio; tirones(): saltos y cuadros repetidos) y, si algo salió mal,
se graba otra vez. Cada toma queda en shots/video3d/tomas/<id>.mp4 (H.264 casi sin pérdida) con un .json que dice con qué se grabó:
se vuelve a grabar solo si cambió su entrada en config/video3d.json (salvo el texto), el tamaño, la exportación del
mapa (modelo3d/mapa/indice.json) o el código de modelo3d/ (los .gd y los sombreadores). El montaje pone el texto de cada toma (Pillow), la une con la siguiente con un fundido
cruzado de «fundido» s y comprime el video a CRF 20 con un tope de 9 Mbit/s (~45 MB por 50 s).

Las tipografías son las del sitio (Alegreya SC para títulos, Alegreya Sans para el texto, IBM Plex Mono para datos;
SIL Open Font License, que permite usarlas e incrustarlas en un video): la página las pide a Google Fonts, y aquí se
bajan una vez, del repositorio google/fonts en un commit fijo y con su SHA-256, a raw/tipografias/ (fuera de git).

Requiere modelo3d/mapa/ (make modelo3d), dist/ para la apertura (make build), ffmpeg y uv. Con la GPU de un M3 Pro
(noviembre de 2026), una toma de 6 s tarda ~35–100 s (la carga de su camino, 6–19 s, y los árboles de cerca en todos);
el video entero, ~11 min, y --cuadros, ~20 s por toma. Al terminar escribe también una hoja con un cuadro cada 2 s del
video (talca-3d-hoja.jpg), para revisar los fundidos y los textos.
"""
import argparse, hashlib, json, os, re, shutil, subprocess, sys, time, urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONF = ROOT / 'config' / 'video3d.json'
OUT = ROOT / 'shots' / 'video3d'
M3D = ROOT / 'modelo3d'
GODOT = ROOT / 'tools' / 'godot_oculto.sh'
FFMPEG = shutil.which('ffmpeg') or '/opt/homebrew/bin/ffmpeg'
FFPROBE = shutil.which('ffprobe') or '/opt/homebrew/bin/ffprobe'

# las tipografías del sitio (src/page.html), de google/fonts en un commit fijo (30 de octubre de 2026)
FONTS_COMMIT = '6c1dbe27dcf7d817d4b62cec033ba77fa8e2a5ec'
FONTS_DIR = ROOT / 'raw' / 'tipografias'
FONTS = {  # nombre -> (ruta en google/fonts, sha256)
    'titulo': ('ofl/alegreyasc/AlegreyaSC-Bold.ttf', '3ef96cbf3be7b84d9dff9b1aa1e2ac40eec0cf323ccd0638395cdef9c5a91528'),
    'texto': ('ofl/alegreyasans/AlegreyaSans-Medium.ttf', '4b89fe7804fd1485ec2757795a53ffdb66e1206dd56f844c2d72b3c944815b43'),
    'dato': ('ofl/ibmplexmono/IBMPlexMono-Medium.ttf', 'a9b4c49bb299e05b5f6c481e7fb5e78943d2793249a0c8874ab574a2d1ea6755'),
}

# lo de una toma que cambia lo que graba Godot (el texto no: va en el montaje)
GRABA = ('dur', 'hora', 'dia', 'fov', 'suave', 'toda_la_comuna', 'claves', 'claves_vertical')


def sh(cmd, **kw):
    print('$', ' '.join(str(c) for c in cmd)[:300], flush=True)
    return subprocess.run([str(c) for c in cmd], check=True, **kw)


def conf():
    return json.loads(CONF.read_text())


# ---------- las tipografías ----------

def fuente(cual, px):
    from PIL import ImageFont
    ruta, sha = FONTS[cual]
    f = FONTS_DIR / Path(ruta).name
    if not f.exists():
        FONTS_DIR.mkdir(parents=True, exist_ok=True)
        url = f'https://raw.githubusercontent.com/google/fonts/{FONTS_COMMIT}/{ruta}'
        req = urllib.request.Request(url, headers={'User-Agent': 'talca-isometrica'})
        datos = urllib.request.urlopen(req, timeout=60).read()
        if sha and hashlib.sha256(datos).hexdigest() != sha:
            sys.exit(f'video3d.py: {f.name} no es la esperada (sha256)')
        f.write_bytes(datos)
        (FONTS_DIR / f'OFL-{Path(ruta).parent.name}.txt').write_bytes(urllib.request.urlopen(urllib.request.Request(
            url.rsplit('/', 1)[0] + '/OFL.txt', headers={'User-Agent': 'talca-isometrica'}), timeout=60).read())
    return ImageFont.truetype(str(f), int(px))


# ---------- las tomas ----------

def toma_json(t, c, vertical):
    d = {k: t[k] for k in GRABA if k in t}
    d['id'] = t['id']
    d.setdefault('dia', c.get('dia', 15))
    if vertical:  # las claves del corte vertical, si la toma las tiene (las de 16:9 no siempre sirven: otro encuadre)
        d['vertical'] = True
        d['claves'] = t.get('claves_vertical', t['claves'])
    return d


def huella(d, size):
    """Lo que cambia lo que graba una toma: su entrada, el tamaño, la exportación del mapa y el código de modelo3d/."""
    m = M3D / 'mapa' / 'indice.json'
    h = hashlib.sha256(json.dumps([d, size, m.stat().st_mtime if m.exists() else 0], sort_keys=True).encode())
    for f in sorted(M3D.rglob('*.gd*')):
        if f.suffix in ('.gd', '.gdshader') and not {'mapa', 'datos', '.godot'} & set(f.relative_to(M3D).parts):
            h.update(f.read_bytes())
    return h.hexdigest()[:16]


def override(size):
    w, h = size
    (M3D / 'override.cfg').write_text(f'[display]\nwindow/size/viewport_width={w}\nwindow/size/viewport_height={h}\n'
                                      '[editor]\nmovie_writer/video_quality=1.0\n')


def godot(args, plazo=600):
    """Godot oculto con esos argumentos; devuelve su salida (y la imprime si falló). Antes de la salida adicional de
    recorrido.gd, una captura esperaba para siempre cuadros que no llegaban: pasado el plazo (s) se mata y se corre otra
    vez."""
    # Godot no dibuja si ninguna de sus ventanas está a la vista, y en el Mac la de godot_oculto.sh queda tapada a ratos:
    # recorrido.gd se registra como salida adicional y lo hace dibujar igual. caffeinate (que el Mac no se duerma ni
    # apague la pantalla mientras graba) queda de respaldo.
    pre = ['caffeinate', '-d', '-i'] if sys.platform == 'darwin' and shutil.which('caffeinate') else []
    for intento in (1, 2):
        try:
            r = subprocess.run([*pre, str(GODOT), '--path', str(M3D), *map(str, args)], cwd=ROOT, capture_output=True,
                               text=True, timeout=plazo)
            break
        except subprocess.TimeoutExpired:
            subprocess.run(['pkill', '-f', f'Godot.*--path {M3D}'], check=False)
            # godot_oculto.sh junta la salida de Godot en un archivo temporal y la imprime al terminar: lo último de él
            tmp = Path(os.environ.get('TMPDIR', '/tmp'))
            logs = sorted(tmp.glob('godot_oculto.*'), key=lambda p: p.stat().st_mtime)
            if logs:
                print('\n'.join(l for l in logs[-1].read_text(errors='replace').splitlines() if l.strip())[-3000:])
            print(f'video3d.py: Godot no terminó en {plazo} s' + (': otra vez' if intento == 1 else ''), flush=True)
    else:
        sys.exit('video3d.py: Godot no terminó dos veces')
    log = r.stdout + r.stderr
    if r.returncode:
        print(log[-6000:])
        sys.exit(f'video3d.py: Godot salió con {r.returncode}')
    return log


def congelada(video):
    """Los tramos de más de 0,5 s en que el video no cambia (freezedetect de ffmpeg): una toma se mueve siempre, así que
    uno así es Godot que dejó de dibujar y Movie Maker que grabó el último cuadro otra vez: pasaba con la ventana oculta
    tapada (Godot no dibuja si ninguna ventana está a la vista; en una corrida, la Catedral cuatro veces seguidas), hasta
    que recorrido.gd se registró como salida adicional (DisplayServer.register_additional_output()). Queda como revisión."""
    r = subprocess.run([FFMPEG, '-hide_banner', '-i', str(video), '-vf', 'freezedetect=n=-60dB:d=0.5', '-map', '0:v',
                        '-f', 'null', '-'], capture_output=True, text=True)
    return [float(s) for s in re.findall(r'freeze_start: ([\d.]+)', r.stderr)]


def tirones(video, fps=30):
    """Los cuadros de una toma que no siguen el movimiento de sus vecinos: un salto (el cambio con el anterior, más de
    tres veces el de los cuadros de alrededor) o un cuadro repetido (menos de un sexto, con la cámara en movimiento).
    Una toma es un movimiento continuo; así salieron la cámara que partía fuera de lugar y saltaba a su sitio (un salto) y los cuadros
    que Godot no dibujó (repetidos, más cortos que los que ve congelada()). El cambio, en grises a 160 × 90."""
    w, h = 160, 90
    raw = subprocess.run([FFMPEG, '-v', 'error', '-i', str(video), '-vf', f'scale={w}:{h},format=gray', '-f', 'rawvideo', '-'],
                         capture_output=True, check=True).stdout
    fr = [raw[i:i + w * h] for i in range(0, len(raw) - w * h + 1, w * h)]
    d = [sum(abs(a - b) for a, b in zip(fr[i], fr[i + 1])) / (w * h) for i in range(len(fr) - 1)]
    malos = []
    for i, x in enumerate(d):
        vecinos = sorted(d[max(0, i - 6):i] + d[i + 1:i + 7])
        med = vecinos[len(vecinos) // 2] if vecinos else 0.0
        if (x > 3 * med and x > 4.0) or (med > 0.8 and x < med / 6):
            malos.append((i + 1) / fps)
    return malos


def grabar(t, c, size, dirt, vertical=False, intentos=4):
    """Una toma con Movie Maker -> dirt/<id>.mp4 (los cuadros de la toma, sin los de la carga); si sale congelada o con
    tirones, otra vez (hasta `intentos`)."""
    for i in range(intentos):
        _grabar(t, c, size, dirt, vertical)
        mp4 = dirt / f'{t["id"]}.mp4'
        tramos = congelada(mp4)
        saltos = tirones(mp4, c.get('fps', 30))
        if not tramos and not saltos:
            return
        malo = (f'congelada desde {", ".join(f"{s:.1f}" for s in tramos)} s' if tramos else
                f'tirones en {", ".join(f"{s:.2f}" for s in saltos[:8])} s')
        print(f'video3d.py: {t["id"]}: {malo}' + (': otra vez' if i + 1 < intentos else ''), flush=True)
    meta = dirt / f'{t["id"]}.meta.json'
    meta.unlink(missing_ok=True)  # que la próxima corrida la vuelva a grabar
    sys.exit(f'video3d.py: la toma {t["id"]} salió congelada {intentos} veces (¿la pantalla apagada?)')


def _grabar(t, c, size, dirt, vertical=False):
    d = toma_json(t, c, vertical)
    tid = t['id']
    j = dirt / f'{tid}.json'
    j.write_text(json.dumps(d, ensure_ascii=False))
    avi = dirt / f'{tid}.avi'
    fps = c.get('fps', 30)
    override(size)
    t0 = time.time()
    try:
        log = godot(['--write-movie', avi, '--fixed-fps', fps, '--', '--recorrido', j])
    finally:
        (M3D / 'override.cfg').unlink(missing_ok=True)
    m = re.search(r'recorrido\.gd: toma \S+ cuadros (\d+) \+ (\d+)', log)
    if not m or not avi.exists():
        print(log[-6000:])
        sys.exit(f'video3d.py: la toma {tid} no terminó')
    n, cola = int(m[1]), int(m[2])
    total = cuadros(avi)
    a = total - cola - n
    for l in log.splitlines():
        if l.startswith('recorrido.gd') or 'ERROR' in l:
            print('  ', l)
    mp4 = dirt / f'{tid}.mp4'
    # el MJPEG de Movie Maker es de rango completo (yuvj420p): al rango de video, como lo esperan los reproductores
    sh([FFMPEG, '-y', '-loglevel', 'error', '-i', avi, '-vf', f'select=between(n\\,{a}\\,{a + n - 1}),setpts=N/{fps}/TB,'
        'scale=in_range=full:out_range=tv,format=yuv420p',
        '-r', fps, '-c:v', 'libx264', '-preset', 'medium', '-crf', '12', '-pix_fmt', 'yuv420p', '-an', mp4])
    avi.unlink()
    aviso = re.search(r'como mínimo; el punto tapado en (\d+) de', log)
    alto = re.search(r'la cámara a (-?[\d.]+|inf) m sobre', log)
    meta = {'huella': huella(d, size), 'cuadros': n, 'de': total, 'segundos': round(time.time() - t0, 1),
            'alto_min': alto[1] if alto else None, 'tapado': int(aviso[1]) if aviso else None}
    (dirt / f'{tid}.meta.json').write_text(json.dumps(meta))
    print(f'video3d.py: {tid}: {n} cuadros (de {total}) en {meta["segundos"]} s; la cámara a {meta["alto_min"]} m '
          f'como mínimo sobre lo que tiene debajo; el punto tapado en {meta["tapado"]} cuadros')


def cuadros(video):
    r = subprocess.run([FFPROBE, '-v', 'error', '-count_packets', '-select_streams', 'v:0', '-show_entries',
                        'stream=nb_read_packets', '-of', 'csv=p=0', str(video)], capture_output=True, text=True, check=True)
    return int(r.stdout.strip())


def al_dia(t, c, size, dirt, vertical):
    m = dirt / f'{t["id"]}.meta.json'
    if not (dirt / f'{t["id"]}.mp4').exists() or not m.exists():
        return False
    return json.loads(m.read_text()).get('huella') == huella(toma_json(t, c, vertical), size)


def fotos(t, c, size, dirt, instantes, vertical=False):
    """Cuadros sueltos de una toma: dirt/<id>-t<s>.png, de una sola carga."""
    d = toma_json(t, c, vertical)
    j = dirt / f'{t["id"]}.json'
    j.write_text(json.dumps(d, ensure_ascii=False))
    if not instantes:
        dur = float(t['dur'])
        instantes = [0, dur / 2, dur]
    override(size)
    try:
        log = godot(['--', '--recorrido', j, '--png', dirt / f'{t["id"]}.png', '--instantes', ','.join(f'{s:g}' for s in instantes)])
    finally:
        (M3D / 'override.cfg').unlink(missing_ok=True)
    for l in log.splitlines():
        if l.startswith('recorrido.gd'):
            print('  ', l.replace(str(ROOT) + '/', ''))
    return [dirt / f'{t["id"]}-t{s:.2f}.png' for s in instantes]


# ---------- lo que va encima (Pillow) ----------

def capa_texto(size, lineas, path, vertical=False):
    """El texto de una toma abajo a la izquierda (en el vertical, sobre la zona de los controles de la aplicación),
    con una sombra suave: el título en Alegreya SC y la línea en Alegreya Sans, legibles con el video a 390 px."""
    from PIL import Image, ImageDraw, ImageFilter
    W, H = size
    img = Image.new('RGBA', size, (0, 0, 0, 0))
    if not lineas:
        img.save(path)
        return
    u = min(W, H) / 1080  # la escala: 1 en 1080p
    margen = W * 0.06
    base = H * (0.78 if vertical else 0.88)  # la línea de base de la última
    tit, txt = 96 * u, 64 * u
    if vertical:
        tit, txt = 100 * u, 66 * u
    fts = [fuente('titulo', tit)] + [fuente('texto', txt)] * (len(lineas) - 1)
    alto = [tit * 1.15] + [txt * 1.3] * (len(lineas) - 1)
    y = base - sum(alto[1:])
    sombra = Image.new('RGBA', size, (0, 0, 0, 0))
    ds = ImageDraw.Draw(sombra)
    d = ImageDraw.Draw(img)
    pos = []
    for i, (s, f) in enumerate(zip(lineas, fts)):
        pos.append((margen, y, s, f))
        y += alto[i + 1] if i + 1 < len(alto) else 0
    for x, yy, s, f in pos:
        ds.text((x, yy), s, font=f, fill=(0, 0, 0, 200), anchor='ls', stroke_width=int(10 * u), stroke_fill=(0, 0, 0, 200))
    sombra = sombra.filter(ImageFilter.GaussianBlur(14 * u))
    img.alpha_composite(sombra)
    for i, (x, yy, s, f) in enumerate(pos):
        d.text((x, yy), s, font=f, fill=(255, 250, 240, 255) if i == 0 else (240, 236, 226, 255), anchor='ls',
               stroke_width=max(1, int(1.5 * u)), stroke_fill=(20, 16, 12, 160))
    img.save(path)


def carta_cierre(size, cierre, path):
    from PIL import Image, ImageDraw
    W, H = size
    u = min(W, H) / 1080
    img = Image.new('RGB', size, (22, 20, 18))
    d = ImageDraw.Draw(img)
    d.text((W / 2, H * 0.42), cierre['titulo'], font=fuente('titulo', 120 * u), fill=(246, 240, 228), anchor='mm')
    d.text((W / 2, H * 0.56), cierre['url'], font=fuente('dato', 56 * u), fill=(232, 182, 120), anchor='mm')
    if cierre.get('nota'):
        d.text((W / 2, H * 0.86), cierre['nota'], font=fuente('texto', 40 * u), fill=(170, 164, 152), anchor='mm')
    img.save(path)


# ---------- la apertura: el mapa isométrico ----------

def apertura(c, size, dirt, vertical):
    a = c['apertura']
    mp4 = dirt / 'apertura.mp4'
    meta = dirt / 'apertura.meta.json'
    h = hashlib.sha256(json.dumps([a, size, (ROOT / 'dist' / 'index.html').stat().st_mtime if (ROOT / 'dist' / 'index.html').exists() else 0],
                                  sort_keys=True).encode()).hexdigest()[:16]
    if mp4.exists() and meta.exists() and json.loads(meta.read_text()).get('huella') == h:
        return mp4
    if not (ROOT / 'dist' / 'index.html').exists():
        sys.exit('video3d.py: la apertura necesita dist/: corra `make build`')
    W, H = size
    x, y = a.get('centro', [0, 0])
    z0, z1 = a.get('zoom', [3.2, 5.6])
    sh(['uv', 'run', ROOT / 'tools' / 'video.py', mp4, '--size', f'{W // 2}x{H // 2}', '--dpr', '2', '--centro', f'{x},{y}',
        '--from', z0, '--zoom', z1, '--intro', a['dur'], '--day', 0, '--fade', 0, '--night', 0, '--speed', a.get('giro', 6),
        '--url', '', '--no-brand', '--crf', 12, '--maxrate', 60], cwd=ROOT)
    meta.write_text(json.dumps({'huella': h}))
    return mp4


# ---------- el montaje ----------

def montar(c, size, dirt, out, vertical=False):
    W, H = size
    fps = c.get('fps', 30)
    fun = float(c.get('fundido', 0.6))
    tmp = dirt / 'montaje'
    shutil.rmtree(tmp, ignore_errors=True)
    tmp.mkdir(parents=True)
    piezas = []  # (archivo de video o None para una imagen fija, segundos, texto)
    if c.get('apertura'):
        piezas.append((apertura(c, size, dirt, vertical), float(c['apertura']['dur']), c['apertura'].get('texto')))
    for t in c['tomas']:
        piezas.append((dirt / f'{t["id"]}.mp4', float(t['dur']), t.get('texto')))
    cierre = tmp / 'cierre.png'
    carta_cierre(size, c['cierre'], cierre)
    piezas.append((cierre, float(c['cierre']['dur']), None))
    args, filtros = [], []
    for i, (f, dur, texto) in enumerate(piezas):
        if f.suffix == '.png':
            args += ['-loop', '1', '-framerate', fps, '-t', f'{dur:.3f}', '-i', f]
        else:
            args += ['-i', f]
        capa = tmp / f'texto-{i:02d}.png'
        capa_texto(size, texto, capa, vertical)
        args += ['-loop', '1', '-framerate', fps, '-t', f'{dur:.3f}', '-i', capa]
        # el texto entra 0,5 s después del fundido de entrada y se va antes del de salida
        ent = (fun if i else 0) + 0.5
        sal = max(ent + 0.5, dur - fun - 0.6)
        filtros.append(f'[{2 * i}:v]scale={W}:{H},fps={fps},format=yuv420p,trim=duration={dur:.3f},setpts=PTS-STARTPTS[v{i}];'
                       f'[{2 * i + 1}:v]format=rgba,fade=in:st={ent:.2f}:d=0.4:alpha=1,fade=out:st={sal:.2f}:d=0.4:alpha=1[c{i}];'
                       f'[v{i}][c{i}]overlay=0:0:shortest=1,format=yuv420p[p{i}]')
    # los fundidos cruzados, en cadena
    prev, t = 'p0', piezas[0][1]
    for i in range(1, len(piezas)):
        off = t - fun
        filtros.append(f'[{prev}][p{i}]xfade=transition=fade:duration={fun}:offset={off:.3f}[x{i}]')
        prev, t = f'x{i}', off + piezas[i][1]
    filtros.append(f'[{prev}]fade=out:st={t - 0.8:.3f}:d=0.8[fin]')
    sh([FFMPEG, '-y', '-loglevel', 'error', *args, '-filter_complex', ';'.join(filtros), '-map', '[fin]', '-r', fps,
        '-c:v', 'libx264', '-preset', 'slow', '-crf', '20', '-maxrate', '9M', '-bufsize', '18M', '-pix_fmt', 'yuv420p',
        '-profile:v', 'high', '-movflags', '+faststart', '-an', out])
    print(f'-> {out.relative_to(ROOT)} ({t:.1f} s, {out.stat().st_size / 1e6:.1f} MB)')
    return t


def hoja(pngs, path, cols=3, ancho=640):
    """Una hoja de cuadros sueltos, con el nombre de cada uno."""
    from PIL import Image, ImageDraw
    ims = [Image.open(p).convert('RGB') for p in pngs if Path(p).exists()]
    if not ims:
        return
    w = ancho
    h = round(ims[0].height * w / ims[0].width)
    filas = (len(ims) + cols - 1) // cols
    out = Image.new('RGB', (cols * w, filas * (h + 28)), (16, 16, 16))
    d = ImageDraw.Draw(out)
    for i, (im, p) in enumerate(zip(ims, [p for p in pngs if Path(p).exists()])):
        x, y = (i % cols) * w, (i // cols) * (h + 28)
        out.paste(im.resize((w, h)), (x, y + 28))
        d.text((x + 8, y + 4), Path(p).stem, fill=(230, 230, 230), font=fuente('dato', 18))
    out.save(path, quality=88)
    print(f'-> {path.relative_to(ROOT)}')


def hoja_video(mp4, path, cada=2.0):
    """Un cuadro cada `cada` s del video terminado, en una hoja con su segundo: para revisar los fundidos y los textos."""
    tmp = path.parent / f'{path.stem}-cuadros'
    shutil.rmtree(tmp, ignore_errors=True)
    tmp.mkdir()
    n = round(cada * conf().get('fps', 30))  # por número de cuadro: fps=1/2 los toma corridos hasta 1 s
    sh([FFMPEG, '-y', '-loglevel', 'error', '-i', mp4, '-vf', f"select='not(mod(n\\,{n}))',scale=640:-1", '-fps_mode', 'vfr',
        tmp / 's%03d.png'])
    pngs = sorted(tmp.glob('s*.png'))
    for i, p in enumerate(pngs):  # s001.png es el cuadro del segundo 0
        p.rename(tmp / f't{i * cada:04.1f}s.png')
    hoja(sorted(tmp.glob('t*.png')), path, cols=4, ancho=480)
    shutil.rmtree(tmp)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--solo', default='', help='tomas que se vuelven a grabar (o, con --cuadros, las únicas)')
    ap.add_argument('--montar', action='store_true', help='no graba: solo arma el video con las tomas ya grabadas')
    ap.add_argument('--cuadros', action='store_true', help='solo cuadros sueltos de cada toma, con su texto, y una hoja')
    ap.add_argument('--instantes', default='', help='con --cuadros: los segundos de cada toma (por omisión, el comienzo, la mitad y el final)')
    ap.add_argument('--vertical', action='store_true', help='además (o con --cuadros, en vez del horizontal), el corte de 1080x1920')
    ap.add_argument('--salida', default='', help='el video (por omisión shots/video3d/talca-3d.mp4)')
    a = ap.parse_args()
    for exe in (FFMPEG, FFPROBE):
        if not Path(exe).exists():
            sys.exit('video3d.py: falta ffmpeg (brew install ffmpeg)')
    if not (M3D / 'mapa' / 'indice.json').exists():
        sys.exit('video3d.py: falta modelo3d/mapa/: corra `make modelo3d` (o python3 tools/bajar_mapa.py)')
    c = conf()
    ids = [t['id'] for t in c['tomas']]
    solo = [s for s in a.solo.split(',') if s]
    for s in solo:
        if s not in ids:
            sys.exit(f'video3d.py: no hay una toma «{s}» ({", ".join(ids)})')
    W, H = c.get('tamano', [1920, 1080])
    cortes = [((W, H), OUT / 'tomas', False)]
    if a.vertical:
        cortes = ([] if a.cuadros else cortes) + [((H, W), OUT / 'tomas-vertical', True)]
    t0 = time.time()
    for size, dirt, vertical in cortes:
        dirt.mkdir(parents=True, exist_ok=True)
        tomas = [t for t in c['tomas'] if not solo or t['id'] in solo or not a.cuadros]
        if a.cuadros:
            pngs = []
            inst = [float(s) for s in a.instantes.split(',') if s]
            for t in tomas:
                for p in fotos(t, c, size, dirt, inst, vertical):
                    capa = dirt / 'texto.png'
                    capa_texto(size, t.get('texto'), capa, vertical)
                    from PIL import Image
                    im = Image.open(p).convert('RGBA')
                    im.alpha_composite(Image.open(capa))
                    im.convert('RGB').save(p)
                    pngs.append(p)
            hoja(pngs, dirt / 'hoja.jpg', cols=3 if not vertical else 6)
            continue
        if not a.montar:
            for t in tomas:
                if t['id'] in solo or not al_dia(t, c, size, dirt, vertical):
                    grabar(t, c, size, dirt, vertical)
        out = Path(a.salida) if a.salida and not vertical else OUT / ('talca-3d-vertical.mp4' if vertical else 'talca-3d.mp4')
        montar(c, size, dirt, out, vertical)
        hoja_video(out, out.with_name(out.stem + '-hoja.jpg'))
    print(f'video3d.py: {time.time() - t0:.0f} s')


if __name__ == '__main__':
    main()
