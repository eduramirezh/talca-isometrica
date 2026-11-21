# /// script
# requires-python = ">=3.10"
# dependencies = ["pillow==13.0.0"]
# ///
"""Vistas del juego frente a las fachadas de la ciudad (juego/fachadas_ciudad.gd), para revisarlas antes y después de
un cambio: dónde pararse frente a un edificio, las capturas y una hoja para compararlas.

  python3 tools/juego_vistas.py punto 313 110 [--dist 8 --lado 0 --tipo adobe]
      --desde x,y --girar G frente al lado a la calle más largo del edificio más cercano a (x, y), a --dist m de él y
      corrido --lado m a lo largo (de juego/mapa/f_<i>_<j>.json: make juego); con --tipo, el más cercano de ese tipo
  python3 tools/juego_vistas.py buscar poblacion [--techo x --lados 0,2 -n 3 --fuente ms]
      vistas frente a edificios de un tipo (con ese techo, k de FACH: f, g, x, h, s; cuyo lado a la calle es uno de
      --lados; de esa fuente: city, osm, ms, google), repartidas de la plaza hacia afuera
  python3 tools/juego_vistas.py tomar shots/antes [--solo adobe,pobl] [--vista "x=--desde 10,20 --girar 30" …]
      [--vistas archivo]
      una captura por vista (tools/godot_oculto.sh --png, en primera persona: --camara 0.01 --mirar 4 si la vista no
      dice otra cosa; lo que dice cada vista va primero y gana), e imprime la línea de fachadas_ciudad.gd (celdas,
      edificios, triángulos, ms). Sin --vista ni --vistas, las de VISTAS (un tipo de edificio cada una, algunas
      esquinas del centro, dos techos y una de noche: ~8 min); --vistas: un archivo con una vista por línea
      (nombre=argumentos; # comenta)
  uv run tools/juego_vistas.py hoja shots/hoja.jpg shots/antes shots/despues -- adobe pobl [--ancho 800]
      una hoja con las capturas sin la ayuda de arriba: con un directorio, de a dos por fila; con varios, una columna
      por vista y una fila por directorio (antes sobre después)

Así se revisó en noviembre de 2026 la fachada gruesa, los aleros y el repertorio del centro de fachadas_ciudad.gd
(docs/METODOLOGIA.md §16). Una captura tarda ~17 s con la GPU de NVIDIA en Linux (Xvfb); sin ella, con
GODOT_OCULTO_VK=lavapipe, minutos. Los cuadros por segundo se miden aparte, con --fps (fps.gd).
"""
import argparse, glob, json, math, subprocess, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MAPA = ROOT / 'juego' / 'mapa'
# las vistas de la revisión de noviembre de 2026 (de punto y buscar): una por tipo de edificio y de fuente, esquinas del
# centro con locales, casas con el hastial a la calle, dos techos (pretiles, aleros) y la noche
VISTAS = [
    ('centro', '--desde 313,110 --girar 65'), ('adobe', '--desde -232,-313 --girar -33'),
    ('adobe2', '--desde -53,-465 --girar 123'), ('adobe-cerca', '--desde -57.3,-467.7 --girar 117 --mirar 3'),
    ('adobe-ms', '--desde -1381,-513 --girar -106'), ('continua', '--desde 308,396 --girar -58'),
    ('local', '--desde 577,-509 --girar -56'), ('pobl', '--desde 403,-2176 --girar 46'),
    ('pobl-ms', '--desde -431,-1807 --girar 0'), ('pobl-x', '--desde -419.7,-481.4 --girar 101'),
    ('pareada', '--desde 438,-855 --girar -123'), ('pareada-ms', '--desde 1934,326 --girar -56'),
    ('fila', '--desde -61,-1540 --girar 34'), ('condominio', '--desde 241,-2024 --girar 4'),
    ('block', '--desde 381,-712 --girar 28'), ('block-x', '--desde 360.4,-662.1 --girar -117'),
    ('edificio', '--desde -492,-152 --girar 138'), ('galpon', '--desde -804,1085 --girar 98'),
    ('esq1', '--desde 168.2,17.8 --girar -146'), ('esq2', '--desde -114.1,257.2 --girar -145'),
    ('esq3', '--desde 63.6,-301.8 --girar -56'), ('esq4', '--desde 187.5,-105.2 --girar -55'),
    ('techo-esq4', '--desde 207.1,-99.0 --girar -55 --mirar -32 --camara 11'),
    ('techo-fila', '--desde -66.4,-1529.1 --girar 34 --mirar -32 --camara 11'),
    ('noche', '--desde 168.2,17.8 --girar -146 --hora 21.5'),
]


def centro(q):
    return sum(p[0] for p in q) / len(q), sum(p[1] for p in q) / len(q)


def frente(e, lado_i, dist, lado):
    """--desde/--girar a dist m del lado lado_i de e, corrido lado m a lo largo, mirando a su medio"""
    q = e['q']
    n = len(q)
    A = sum(q[k][0] * q[(k + 1) % n][1] - q[(k + 1) % n][0] * q[k][1] for k in range(n))
    a, b = q[lado_i], q[(lado_i + 1) % n]
    L = math.dist(a, b)
    dx, dy = (b[0] - a[0]) / L, (b[1] - a[1]) / L
    o = (dy, -dx) if A > 0 else (-dy, dx)  # hacia afuera
    m = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
    p = (m[0] + o[0] * dist + dx * lado, m[1] + o[1] * dist + dy * lado)
    g = math.degrees(math.atan2(-(m[0] - p[0]), m[1] - p[1]))  # --girar: 0 al norte, a la izquierda
    return f'--desde {p[0]:.1f},{p[1]:.1f} --girar {g:.0f}', L


def tesela(x, y):
    """los edificios de las nueve teselas de 500 m alrededor de (x, y)"""
    i, j = math.floor(x / 500), math.floor(y / 500)
    out = []
    for di in (-1, 0, 1):
        for dj in (-1, 0, 1):
            f = MAPA / f'f_{i + di}_{j + dj}.json'
            if f.exists():
                out += json.loads(f.read_text())
    return out


def punto(a):
    cands = [e for e in tesela(a.x, a.y) if e.get('f') and (not a.tipo or e['t'] == a.tipo)]
    if not cands:
        sys.exit(f'juego_vistas.py: no hay edificios con lado a la calle cerca de ({a.x}, {a.y}) en {MAPA} (make juego)')
    e = min(cands, key=lambda e: math.dist(centro(e['q']), (a.x, a.y)))
    q = e['q']
    i = max((int(k) for k in e['f']), key=lambda k: math.dist(q[k], q[(k + 1) % len(q)]))
    args, L = frente(e, i, a.dist, a.lado)
    print(args)
    print(f"{e['t']} ({e.get('osm', 'city')}), {e['p']} pisos, alero a {e['h']} m, techo {e['k']}, lado de {L:.1f} m",
          file=sys.stderr)


def buscar(a):
    lados = {int(x) for x in a.lados.split(',')} if a.lados else None
    out = []
    for f in sorted(glob.glob(str(MAPA / 'f_*.json'))):
        for e in json.loads(Path(f).read_text()):
            if e['t'] != a.tipo or (a.techo and e['k'] != a.techo) or (a.fuente and e.get('osm', 'city') != a.fuente):
                continue
            fs = [int(k) for k in e.get('f', []) if lados is None or int(k) in lados]
            if not fs:
                continue
            args, L = frente(e, fs[0], 9, 4)
            out.append((math.hypot(*centro(e['q'])), args, e.get('osm', 'city'), e['p'], L))
    if not out:
        sys.exit('juego_vistas.py: ninguno')
    out.sort()
    for x in out[::max(1, len(out) // a.n)][:a.n]:
        print(f'{x[1]}   # {x[2]}, {x[3]} pisos, lado de {x[4]:.1f} m, a {x[0]:.0f} m de la plaza')


def tomar(a):
    vistas = list(a.vista or [])
    if not vistas and not a.vistas:
        vistas = [f'{n}={x}' for n, x in VISTAS]
    if a.vistas:
        for l in Path(a.vistas).read_text().splitlines():
            if l.strip() and not l.lstrip().startswith('#'):
                vistas.append(l.strip())
    solo = set(a.solo.split(',')) if a.solo else None
    d = Path(a.dir)
    d.mkdir(parents=True, exist_ok=True)
    mal = 0
    for v in vistas:
        nombre, _, args = v.partition('=')
        nombre = nombre.strip()
        if solo and nombre not in solo:
            continue
        cmd = [str(ROOT / 'tools' / 'godot_oculto.sh'), '--path', str(ROOT / 'juego'), '--', '--png',
               str((d / f'{nombre}.png').resolve()), *args.split(), '--camara', '0.01', '--mirar', '4']
        r = subprocess.run(cmd, capture_output=True, text=True)
        lineas = [l for l in (r.stdout + r.stderr).splitlines() if 'fachadas_ciudad.gd' in l or 'ERROR' in l]
        print(f'{nombre}: ' + ('; '.join(lineas) or '(sin fachadas)'))
        mal |= r.returncode != 0
    sys.exit(1 if mal else 0)


def hoja(a):
    from PIL import Image, ImageDraw
    celdas = []
    for n in a.nombres:
        col = []
        for d in a.dirs:
            p = Path(d) / f'{n}.png'
            im = Image.open(p).convert('RGB') if p.exists() else Image.new('RGB', (1600, 1000), 'gray')
            im = im.crop((0, 170, im.width, im.height - 60))  # sin la ayuda de arriba ni la barra de vida
            im.thumbnail((a.ancho, a.ancho))
            ImageDraw.Draw(im).text((6, 4), f'{Path(d).name}/{n}', fill='yellow')
            col.append(im)
        celdas.append(col)
    w, h = celdas[0][0].size
    C = 2 if len(a.dirs) == 1 else len(celdas)
    R = -(-len(celdas) // C)
    H = Image.new('RGB', (w * C, h * len(a.dirs) * R), 'black')
    for k, col in enumerate(celdas):
        for y, im in enumerate(col):
            H.paste(im, ((k % C) * w, ((k // C) * len(a.dirs) + y) * h))
    H.save(a.out, quality=85)
    print(a.out, H.size)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest='cmd', required=True)
    p = sub.add_parser('punto')
    p.add_argument('x', type=float)
    p.add_argument('y', type=float)
    p.add_argument('--dist', type=float, default=8.0)
    p.add_argument('--lado', type=float, default=0.0)
    p.add_argument('--tipo')
    p = sub.add_parser('buscar')
    p.add_argument('tipo')
    p.add_argument('--techo')
    p.add_argument('--lados')
    p.add_argument('--fuente')
    p.add_argument('-n', type=int, default=3)
    p = sub.add_parser('tomar')
    p.add_argument('dir')
    p.add_argument('--vista', action='append')
    p.add_argument('--vistas')
    p.add_argument('--solo')
    p = sub.add_parser('hoja')
    p.add_argument('out')
    p.add_argument('dirs', nargs='+')
    p.add_argument('--ancho', type=int, default=800)
    argv = sys.argv[1:]
    nombres = []
    if argv and argv[0] == 'hoja' and '--' in argv:
        i = argv.index('--')
        argv, nombres = argv[:i], argv[i + 1:]
    a = ap.parse_args(argv)
    if a.cmd == 'hoja':
        if not nombres:
            ap.error('hoja: faltan los nombres de las vistas después de --')
        a.nombres = nombres
    {'punto': punto, 'buscar': buscar, 'tomar': tomar, 'hoja': hoja}[a.cmd](a)


if __name__ == '__main__':
    main()
