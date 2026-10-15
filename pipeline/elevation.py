"""Modelo de elevación SRTM -> data/elevation.json (relieve que se incrusta en el HTML).

Entrada:
  raw/dem/S36W072.hgt.gz   SRTM 1 segundo de arco (~30 m), tesela de los Terrain Tiles de AWS (make fetch)

El SRTM es un modelo de superficie: mide techos y copas de árboles, no el suelo. Para acercarlo al
terreno se muestrea a 20 m, se aplica una apertura morfológica (mínimo y luego máximo en una ventana
de ~100 m, que borra objetos más angostos que eso sin tocar los valles) y un suavizado gaussiano, y
después se baja a la grilla de salida de 40 m.

Salida (metros de grilla; nodos de la grilla, no celdas):
  o    [x0, y0]  nodo (0, 0), esquina suroeste
  s    distancia entre nodos (m)
  n    [nx, ny]  nodos por fila y número de filas (filas de sur a norte)
  z0   altura de la Plaza de Armas sobre el nivel del mar (m); las alturas son relativas a ella
  h    alturas en decímetros, por filas, codificadas en delta respecto del valor anterior. Los nodos a más de
       KEEP celdas fuera del límite de la comuna repiten el valor anterior (delta 0): la plantilla no los usa

  python elevation.py            -> data/elevation.json
  python elevation.py stats      -> además compara bruto y filtrado por zonas
"""
import gzip, json, math, struct, sys
from common import RAW, DATA, unloc, require, EXT, comuna, in_ring

HGT = RAW / 'dem' / 'S36W072.hgt.gz'
XMIN, XMAX, YMIN, YMAX = EXT                          # la caja de la comuna (common.EXT), como process_geometry.py
KEEP = 4                                               # nodos fuera del límite que se guardan (celdas de margen)
S, FINE = 40, 20                                       # grilla de salida y grilla de trabajo (m)
OPEN_R = 2                                             # radio de la apertura, en celdas de FINE (ventana 5x5 = 100 m)
SIGMA = 1.5                                            # suavizado gaussiano, en celdas de FINE (30 m)

class Tile:
    """Tesela SRTM .hgt: 3601x3601 enteros de 16 bits big-endian, fila 0 en el borde norte."""
    def __init__(self, path, lat_n=-35, lon_w=-72):
        self.raw = gzip.open(path).read(); self.N = int(math.isqrt(len(self.raw) // 2))
        self.lat_n, self.lon_w, self.k = lat_n, lon_w, self.N - 1
    def at(self, lat, lon):
        r = (self.lat_n - lat) * self.k; c = (lon - self.lon_w) * self.k
        i, j = int(r), int(c); fr, fc = r - i, c - j
        g = lambda a, b: struct.unpack_from('>h', self.raw, (a * self.N + b) * 2)[0]
        v = [g(i, j), g(i, j + 1), g(i + 1, j), g(i + 1, j + 1)]
        if min(v) < -1000: raise SystemExit(f'vacío en el SRTM cerca de {lat:.5f}, {lon:.5f}')
        return v[0]*(1-fr)*(1-fc) + v[1]*(1-fr)*fc + v[2]*fr*(1-fc) + v[3]*fr*fc

def filt1d(row, r, f):
    n = len(row); return [f(row[max(0, i - r):min(n, i + r + 1)]) for i in range(n)]

def sep(G, fn):
    """Aplica fn(fila) por filas y luego por columnas."""
    G = [fn(row) for row in G]
    cols = [fn([G[j][i] for j in range(len(G))]) for i in range(len(G[0]))]
    return [[cols[i][j] for i in range(len(cols))] for j in range(len(G))]

def gauss(row, sigma=SIGMA):
    r = int(3 * sigma); w = [math.exp(-k * k / (2 * sigma * sigma)) for k in range(-r, r + 1)]; n = len(row); out = []
    for i in range(n):
        acc = ws = 0.0
        for k in range(-r, r + 1):
            j = min(n - 1, max(0, i + k)); acc += row[j] * w[k + r]; ws += w[k + r]
        out.append(acc / ws)
    return out

def main():
    t = Tile(require(HGT))
    # grilla fina con un margen para que los filtros no se recorten en el borde
    m = (OPEN_R + 3 * SIGMA) * FINE * 2
    fx0, fy0 = XMIN - m, YMIN - m
    fnx, fny = int((XMAX - XMIN + 2 * m) / FINE) + 1, int((YMAX - YMIN + 2 * m) / FINE) + 1
    raw = [[t.at(*unloc(fx0 + i * FINE, fy0 + j * FINE)) for i in range(fnx)] for j in range(fny)]
    opened = sep(sep(raw, lambda r: filt1d(r, OPEN_R, min)), lambda r: filt1d(r, OPEN_R, max))
    smooth = sep(opened, gauss)
    fine = lambda G, x, y: G[round((y - fy0) / FINE)][round((x - fx0) / FINE)]

    nx, ny = math.ceil((XMAX - XMIN) / S) + 1, math.ceil((YMAX - YMIN) / S) + 1
    z0 = fine(smooth, 0, 0)
    R = comuna(); keep = bytearray(nx * ny)          # the nodes the template uses: inside the limit or near it
    for j in range(ny):
        for i in range(nx): keep[j*nx+i] = in_ring((XMIN + i * S, YMIN + j * S), R)
    for k in range(len(R)):
        a, b = R[k-1], R[k]; n = int(math.dist(a, b) / (S / 2)) + 1
        for t in range(n + 1):
            ci, cj = round((a[0] + (b[0]-a[0])*t/n - XMIN) / S), round((a[1] + (b[1]-a[1])*t/n - YMIN) / S)
            for j in range(max(0, cj-KEEP), min(ny, cj+KEEP+1)):
                for i in range(max(0, ci-KEEP), min(nx, ci+KEEP+1)): keep[j*nx+i] = 1
    h, prev = [], 0
    for j in range(ny):
        for i in range(nx):
            if keep[j*nx+i]: v = round((fine(smooth, XMIN + i * S, YMIN + j * S) - z0) * 10)
            else: v = prev
            h.append(v - prev); prev = v
    out = {'o': [XMIN, YMIN], 's': S, 'n': [nx, ny], 'z0': round(z0, 1), 'h': h}
    s = json.dumps(out, separators=(',', ':'))
    (DATA / 'elevation.json').write_text(s)
    vals = [fine(smooth, XMIN + i * S, YMIN + j * S) for j in range(ny) for i in range(nx) if keep[j*nx+i]]
    print(f'data/elevation.json: {len(s)} bytes, {nx}x{ny} nodos de {S} m ({sum(keep)} en la comuna), '
          f'{min(vals):.0f}–{max(vals):.0f} m s.n.m., plaza {z0:.1f} m')

    if 'stats' in sys.argv:   # cuánto quita el filtro: debería ser poco en el campo y algo más en el centro
        for name, (x0, x1, y0, y1) in {'centro': (-800, 800, -800, 800), 'campo oriente': (4200, 5500, 2500, 4500),
                                       'cerros poniente': (-3900, -2600, -1500, 1500)}.items():
            d = [fine(raw, x, y) - fine(smooth, x, y) for x in range(x0, x1, FINE) for y in range(y0, y1, FINE)]
            mu = sum(d) / len(d); sd = math.sqrt(sum((v - mu) ** 2 for v in d) / len(d))
            print(f'  {name:16s} bruto − filtrado: media {mu:+.1f} m, desv. {sd:.1f} m, máx. {max(d):+.1f} m')

if __name__ == '__main__':
    main()
