"""El Talca Country Club desde la imagen de Esri: el pasto cortado (calles y greens) y las copas de los árboles.

OpenStreetMap solo tiene el contorno del club (w101587762, leisure=golf_course): ni calles de juego, ni greens, ni
árboles. La imagen de Esri los muestra bien (verano, sol alto), así que este script clasifica el color de cada celda de
3 m dentro del contorno, con el mismo criterio que se calibró mirando la imagen (HSV de Esri), y escribe data/golf.json:

  turf   rectángulos de celdas de pasto cortado: [fila, x0, x1, filas] (celdas desde el origen `o`, lado `c` en m)
  trees  una copa cada 6 m donde la celda es oscura (copas y su sombra): [x, y, tamaño] en metros de grilla

Lo demás del modelo (greens, búnkeres, estanques, casas, canchas) está puesto a mano en src/js/hitos/talca-country-club.js,
leído de la misma imagen con `satellite.py punto … --calles`. La imagen puede tener años (ESTETICA, trampa «La imagen
satelital puede ser vieja») y las sombras de los árboles quedan pegadas a sus copas: las copas son aproximadas.

  python pipeline/golf.py            # escribe data/golf.json (make golf; requiere internet la primera vez: teselas de Esri)
  python pipeline/golf.py panel      # diagnostics/golf-clases.png: pasto (verde claro), copas (verde oscuro), agua, arena (con Pillow)

El trazado desde Esri es lo que permite OSM como fondo de dibujo; la imagen en sí no entra en el repositorio.
"""
import colorsys, json, sys
from common import CONFIG, DATA, ROOT
from satellite import mosaic

BOX = (3240, 4350, 720, 1270)   # grid metres around the club's outline (w101587762)
C = 3                           # cell side in metres
Z = 19

def outline():
    for u in json.load(open(CONFIG / 'usos.json'))['usos']:
        if 'w101587762' in u.get('fuente', ''): return [tuple(p) for p in u['poly']]
    raise SystemExit('No está el contorno w101587762 en config/usos.json')

def pip(p, r):
    x, y = p; ins = False; j = len(r) - 1
    for i in range(len(r)):
        if (r[i][1] > y) != (r[j][1] > y) and x < (r[j][0] - r[i][0]) * (y - r[i][1]) / (r[j][1] - r[i][1]) + r[i][0]: ins = not ins
        j = i
    return ins

def classify(r, g, b):
    """'t' pasto cortado, 'k' copa o sombra, 'w' agua, 's' arena, '.' otro (HSV de la imagen de Esri, calibrado a ojo)."""
    h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255); h *= 360
    if v < .22 and g >= r: return 'k'
    if v < .31 and 100 < h < 170 and s > .3: return 'k'
    if v > .62 and s < .5 and 25 < h < 70: return 's'
    if s < .12 and .28 < v < .55 and 70 < h < 140: return 'w'
    if v >= .31 and 80 < h < 150 and s > .25: return 't'
    return '.'

def cells():
    ring = outline(); img, P = mosaic(*BOX, Z); px = img.load(); W, H = img.size
    ox, oy = BOX[0], BOX[2]; nx, ny = int((BOX[1] - BOX[0]) / C), int((BOX[3] - BOX[2]) / C)
    grid = []
    for j in range(ny):
        row = []
        for i in range(nx):
            x, y = ox + (i + .5) * C, oy + (j + .5) * C
            if not pip((x, y), ring): row.append(None); continue
            n = {}
            for a in (-1, -.33, .33, 1):
                for b in (-1, -.33, .33, 1):
                    p = P((x + a * C / 2.2, y + b * C / 2.2)); X, Y = int(p[0]), int(p[1])
                    if 0 <= X < W and 0 <= Y < H:
                        k = classify(*px[X, Y]); n[k] = n.get(k, 0) + 1
            row.append(n)
        grid.append(row)
    return ox, oy, nx, ny, grid

def main():
    ox, oy, nx, ny, grid = cells()
    # turf: a cell is turf when most of its samples are (crowns and water are left to the layers above)
    t = [[bool(c) and c.get('t', 0) >= 8 for c in row] for row in grid]
    rects, open_ = [], {}
    for j in range(ny):                      # runs per row, merged downward when the same run repeats
        runs, i = [], 0
        while i < nx:
            if t[j][i]:
                k = i
                while k + 1 < nx and t[j][k + 1]: k += 1
                runs.append((i, k)); i = k + 1
            else: i += 1
        now = {}
        for run in runs:
            if run in open_: now[run] = open_.pop(run); now[run][3] += 1
            else: now[run] = [j, run[0], run[1], 1]
        rects += open_.values(); open_ = now
    rects += open_.values()
    # trees: one per 6 m (every other cell in both directions) where the cell is mostly crown or shade; the size
    # grows with how dark its neighbourhood is
    dark = [[bool(c) and c.get('k', 0) >= 9 for c in row] for row in grid]
    trees = []
    for j in range(0, ny, 2):
        for i in range(0, nx, 2):
            n = sum(dark[jj][ii] for jj in range(j, min(ny, j + 2)) for ii in range(i, min(nx, i + 2)))
            if n >= 2:
                s = 1.0 + .15 * n
                trees.append([round(ox + (i + 1) * C), round(oy + (j + 1) * C), round(s, 2)])
    out = {'o': [ox, oy], 'c': C, 'turf': rects, 'trees': trees}
    (DATA / 'golf.json').write_text(json.dumps(out, separators=(',', ':')))
    print(f'data/golf.json: {len(rects)} rectángulos de pasto, {len(trees)} copas, '
          f'{sum(c["t"] for row in grid for c in row if c and "t" in c) // 16} celdas de pasto aprox.')

def panel():
    from PIL import Image
    ox, oy, nx, ny, grid = cells()
    col = {'t': (150, 230, 90), 'k': (10, 50, 10), 'w': (80, 150, 220), 's': (255, 230, 120), '.': (150, 150, 150)}
    im = Image.new('RGB', (nx, ny), (255, 255, 255)); pxo = im.load()
    for j in range(ny):
        for i in range(nx):
            c = grid[j][i]
            if c: pxo[i, ny - 1 - j] = col[max(c, key=c.get)]
    im = im.resize((nx * 3, ny * 3), Image.NEAREST)
    (ROOT / 'diagnostics').mkdir(exist_ok=True); im.save(ROOT / 'diagnostics' / 'golf-clases.png')
    print('diagnostics/golf-clases.png', im.size)

if __name__ == '__main__':
    panel() if sys.argv[1:] == ['panel'] else main()
