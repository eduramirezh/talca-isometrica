"""Las copas de los árboles de un barrio desde la imagen de Esri, para plantar los árboles donde están.

Los árboles de los patios (blockTrees, 50-city.js) y de los parques (el uso «parque», 76-usos.js) salen al azar: una
cuota por manzana sacada del censo y grupos sueltos cada ~25 m. En un barrio arbolado, como la Villa Parque
Universitario, eso deja patios pelados y un parque lineal con media docena de árboles donde la imagen muestra un
bosque. Este script clasifica el color de cada celda de 2,5 m dentro de las cajas de config/copas.json con el mismo
criterio que pipeline/golf.py (HSV de Esri: copa o su sombra), salta las plantas de los edificios de
data/edificios.json (un techo de pizarra oscura saldría copa), y escribe data/copas.json:

  areas  [[x0, x1, y0, y1], …] las cajas (metros de grilla): dentro de ellas, la página planta solo estas copas en los
         patios y en los parques, y no los de la cuota
  trees  una copa cada 7,5 m donde la imagen muestra copas: [x, y, tamaño] en decímetros de grilla (x, y) y décimas (tamaño)
  imagen de qué imagen salió cada caja (satellite.provenance)

La imagen puede tener años (a z19 en la ciudad, 2015: trampa «La imagen satelital puede ser vieja»), y la sombra de
cada árbol queda pegada a su copa: las copas son aproximadas, como las del club de golf. Una casa posterior a la imagen
puede quedar con una copa de entonces en su planta: la página no planta donde hay un edificio (occAt).

  python pipeline/copas.py           # escribe data/copas.json (make copas; requiere internet la primera vez: teselas de Esri)
  python pipeline/copas.py --release=<id|AAAA-MM-DD|ultima>   # con las teselas de una publicación de Esri Wayback
  uv run --with pillow python pipeline/copas.py panel [nombre]   # diagnostics/copas-<nombre>.png: la imagen de cada caja
                                     # con las copas encima (círculos amarillos) y las plantas que se saltan (celeste)

Una caja nueva va en config/copas.json con su nombre y una nota de por qué (un barrio que la imagen muestra arbolado y
la página pelado); elija una construida antes de la fecha de la imagen. El trazado desde Esri es lo que permite OSM como
fondo de dibujo; la imagen en sí no entra en el repositorio.
"""
import colorsys, json
import cli
from common import CONFIG, DATA, ROOT, require
from geom import dec, near_ring
from satellite import mosaic, provenance, release_of

C = 2.5                         # cell side in metres
Z = 19
SAMPLES = (-1, -.33, .33, 1)    # 4 × 4 samples per cell

def areas():
    return json.load(open(CONFIG / 'copas.json'))['areas']

def is_crown(r, g, b):
    """Copa o su sombra en la imagen de Esri (el criterio 'k' de golf.py, más un verde oscuro algo más claro: en los
    patios el sol de la tarde aclara las copas que miran al poniente)."""
    h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255); h *= 360
    if v < .22 and g >= r: return True
    return v < .36 and 70 < h < 170 and s > .28

def footprints(box):
    """The building outlines of data/edificios.json (OSM and machine-learning footprints) whose box meets `box`,
    with their box grown 0.6 m (the eaves, which cells() also skips): [(bbox, ring)]."""
    import edificios
    ed = json.load(open(require(DATA / 'edificios.json', 'Ejecute: make edificios')))
    rings = [[(x / 10, y / 10) for x, y in dec(r[0])] for _, r, *_ in ed['e']]
    rings += [R for R, _ in edificios.h_decode(ed['h'])]
    x0, x1, y0, y1 = box; out = []
    for R in rings:
        bx = (min(p[0] for p in R) - .6, min(p[1] for p in R) - .6, max(p[0] for p in R) + .6, max(p[1] for p in R) + .6)
        if bx[2] < x0 or bx[0] > x1 or bx[3] < y0 or bx[1] > y1: continue
        out.append((bx, R))
    return out

def cells(box, rel=None):
    """The crown cells of a box: (ox, oy, nx, ny, grid of the number of crown samples, or None under a building),
    plus the footprints and the image with its projection, for the panel."""
    x0, x1, y0, y1 = box; img, P = mosaic(x0, x1, y0, y1, Z, rel); px = img.load(); W, H = img.size
    nx, ny = int((x1 - x0) / C), int((y1 - y0) / C); fp = footprints(box)
    idx = {}
    for k, (bx, _) in enumerate(fp):
        for i in range(max(0, int((bx[0] - x0) // C)), min(nx, int((bx[2] - x0) // C) + 1)):
            for j in range(max(0, int((bx[1] - y0) // C)), min(ny, int((bx[3] - y0) // C) + 1)): idx.setdefault((i, j), []).append(k)
    grid = []
    for j in range(ny):
        row = []
        for i in range(nx):
            x, y = x0 + (i + .5) * C, y0 + (j + .5) * C
            if any(near_ring((x, y), fp[k][1], .6) for k in idx.get((i, j), ())): row.append(None); continue
            n = 0
            for a in SAMPLES:
                for b in SAMPLES:
                    p = P((x + a * C / 2.2, y + b * C / 2.2)); X, Y = int(p[0]), int(p[1])
                    if 0 <= X < W and 0 <= Y < H and is_crown(*px[X, Y][:3]): n += 1
            row.append(n)
        grid.append(row)
    return x0, y0, nx, ny, grid, fp, img, P

def crowns(ox, oy, nx, ny, grid):
    """One tree per 3 × 3 cells (7.5 m: the crowns here are 8–12 m wide; one per 5 m was a carpet of small trees) where
    at least four cells are mostly crown, at the middle of its crown cells; it grows with how many are."""
    dark = [[c is not None and c >= 9 for c in row] for row in grid]
    out = []
    for j in range(0, ny - 2, 3):
        for i in range(0, nx - 2, 3):
            k = [(ii, jj) for jj in range(j, j + 3) for ii in range(i, i + 3) if dark[jj][ii]]
            if len(k) < 4: continue
            x = ox + (sum(a for a, _ in k) / len(k) + .5) * C; y = oy + (sum(b for _, b in k) / len(k) + .5) * C
            out.append([round(x * 10), round(y * 10), round((.85 + .08 * len(k)) * 10)])
    return out

def main(*, release=None):
    """data/copas.json from the current imagery or, with --release, from a Wayback release."""
    rel = release_of(release); A, T, I = [], [], []
    for a in areas():
        box = a['caja']; ox, oy, nx, ny, grid, *_ = cells(box, rel)
        # the boxes may overlap (a census block sticks out of the box that holds most of it): a crown in an earlier box is
        # already there
        t = [c for c in crowns(ox, oy, nx, ny, grid) if not any(b[0] <= c[0] / 10 <= b[1] and b[2] <= c[1] / 10 <= b[3] for b in A)]
        A.append(box); T += t; I.append(provenance(*box, Z, rel))
        print(f"{a['nombre']}: {len(t)} copas en {(box[1] - box[0]) * (box[3] - box[2]) / 1e4:.0f} ha")
    (DATA / 'copas.json').write_text(json.dumps({'areas': A, 'trees': T, 'imagen': I}, separators=(',', ':')))
    print(f'data/copas.json: {len(T)} copas en {len(A)} cajas')

def panel(nombre=''):
    from PIL import ImageDraw
    for a in areas():
        if nombre and nombre.lower() not in a['nombre'].lower(): continue
        ox, oy, nx, ny, grid, fp, img, P = cells(a['caja'])
        img = img.convert('RGB'); d = ImageDraw.Draw(img)
        for _, R in fp: d.polygon([P(p) for p in R], outline=(0, 220, 255))
        for x, y, s in crowns(ox, oy, nx, ny, grid):
            p = P((x / 10, y / 10)); r = s / 10 * 2.2 * (P((1, 0))[0] - P((0, 0))[0])
            d.ellipse([p[0] - r, p[1] - r, p[0] + r, p[1] + r], outline=(255, 230, 0), width=2)
        slug = a['nombre'].lower().replace(' ', '-')
        out = ROOT / 'diagnostics' / f'copas-{slug}.png'; out.parent.mkdir(exist_ok=True); img.save(out)
        print(out.relative_to(ROOT), img.size)

if __name__ == '__main__':
    cli.run({'panel': panel}, __doc__, default=main)
