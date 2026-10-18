"""Lector mínimo de GeoTIFF para los modelos de elevación (solo biblioteca estándar).

Lee una tesela de 1° × 1° en float32 o int16, en bloques (tiles) o en franjas, sin compresión o con DEFLATE y
predictor 1, 2 o 3, como las de Copernicus GLO-30 (float32, DEFLATE, predictor 3, bloques de 1024) y FABDEM.
Devuelve solo la ventana que cubre una caja de latitud y longitud, para que elevation.py la muestree igual que
la tesela .hgt del SRTM. No es un lector general: un GeoTIFF con otra proyección que lat/lon (EPSG:4326), varias
bandas o BigTIFF se rechaza con un error.

  python -I pipeline/geotiff.py info <tesela.tif>                              # tamaño, bloques, compresión, georreferencia
  python -I pipeline/geotiff.py punto <tesela.tif> <lat> <lon>                 # el valor en un punto (bilineal)
  python -I pipeline/geotiff.py recorte <tesela.tif> <salida.bin.gz> [lat_n lat_s lon_w lon_e]
      # la ventana en decímetros enteros (int16, big-endian, como el .hgt), comprimida, con una línea de cabecera JSON

El archivo es un dato descargado: se lee con `python -I` y la ruta como argumento.
"""
import array, gzip, json, math, struct, sys, zlib
from itertools import accumulate

TYPES = {1: 'B', 2: 's', 3: 'H', 4: 'I', 5: 'II', 6: 'b', 8: 'h', 9: 'i', 11: 'f', 12: 'd', 16: 'Q'}
SIZE = {1: 1, 2: 1, 3: 2, 4: 4, 5: 8, 6: 1, 8: 2, 9: 4, 11: 4, 12: 8, 16: 8}

def tags(buf):
    """Byte order y etiquetas de la primera IFD (la imagen a resolución completa en un COG)."""
    bo = {b'II': '<', b'MM': '>'}.get(buf[:2])
    if not bo: raise SystemExit('no es un TIFF')
    if struct.unpack(bo + 'H', buf[2:4])[0] != 42: raise SystemExit('BigTIFF o TIFF desconocido: no se lee')
    off = struct.unpack(bo + 'I', buf[4:8])[0]; n = struct.unpack(bo + 'H', buf[off:off + 2])[0]; T = {}
    for k in range(n):
        tag, typ, cnt, val = struct.unpack(bo + 'HHI4s', buf[off + 2 + 12 * k: off + 14 + 12 * k])
        if typ not in TYPES: continue
        size = SIZE[typ] * cnt
        data = val if size <= 4 else buf[struct.unpack(bo + 'I', val)[0]:][:size]
        if typ == 2: T[tag] = data[:cnt].rstrip(b'\0').decode('ascii', 'replace')
        else: T[tag] = list(struct.unpack(bo + TYPES[typ][-1] * (cnt * (2 if typ == 5 else 1)), data[:size]))
    return bo, T

class Grid:
    """Una grilla de alturas con fila 0 al norte: v[r * nx + c], lat_n y lon_w del centro del píxel (0, 0), k píxeles por grado."""
    nodata = None
    def at(self, lat, lon):
        """Interpolación bilineal entre los cuatro centros de píxel vecinos."""
        r = (self.lat_n - lat) * self.k; c = (lon - self.lon_w) * self.k
        i, j = int(r), int(c); fr, fc = r - i, c - j
        if not (0 <= i < self.ny - 1 and 0 <= j < self.nx - 1): raise SystemExit(f'{lat:.5f}, {lon:.5f} fuera del recorte')
        n, v = self.nx, self.v
        q = [v[i * n + j], v[i * n + j + 1], v[(i + 1) * n + j], v[(i + 1) * n + j + 1]]
        if min(q) < -1000 or (self.nodata is not None and self.nodata in q):
            raise SystemExit(f'vacío en el modelo de elevación cerca de {lat:.5f}, {lon:.5f}')
        return q[0] * (1 - fr) * (1 - fc) + q[1] * (1 - fr) * fc + q[2] * fr * (1 - fc) + q[3] * fr * fc

class Raster(Grid):
    """La ventana de una tesela que cubre [lat_s, lat_n] × [lon_w, lon_e], con un píxel de margen para que la
    interpolación bilineal tenga sus cuatro vecinos en el borde. Sin caja, la tesela entera."""
    def __init__(self, path, lat_n=None, lat_s=None, lon_w=None, lon_e=None):
        buf = open(path, 'rb').read(); bo, T = tags(buf)
        W, H = T[256][0], T[257][0]; bits = T[258][0]; fmt = T.get(339, [1])[0]
        comp = T.get(259, [1])[0]; pred = T.get(317, [1])[0]
        if T.get(277, [1])[0] != 1: raise SystemExit('el GeoTIFF tiene más de una banda')
        code = {(32, 3): 'f', (16, 2): 'h', (16, 1): 'H'}.get((bits, fmt))
        if not code: raise SystemExit(f'tipo de dato no soportado: {bits} bits, formato {fmt}')
        if comp not in (1, 8, 32946): raise SystemExit(f'compresión no soportada: {comp}')
        gk = T.get(34735, []); keys = {gk[i]: gk[i + 3] for i in range(4, len(gk), 4)}
        if keys.get(2048, 4326) != 4326 or 3072 in keys: raise SystemExit('el GeoTIFF no está en lat/lon WGS84')
        sx, sy = T[33550][0], T[33550][1]; tie = T[33922]
        if abs(sx - sy) > 1e-12: raise SystemExit('píxeles no cuadrados')
        self.k = round(1 / sx)
        off = 0.0 if keys.get(1025, 1) == 2 else 0.5          # PixelIsPoint: el centro del píxel (0, 0) en el punto de amarre
        lat0, lon0 = tie[4] - (off * sy), tie[3] + (off * sx) # centro del píxel (0, 0)
        lat_n = lat0 if lat_n is None else lat_n; lat_s = lat0 - H * sy if lat_s is None else lat_s
        lon_w = lon0 if lon_w is None else lon_w; lon_e = lon0 + W * sx if lon_e is None else lon_e
        r0 = max(0, math.floor((lat0 - lat_n) * self.k) - 1); r1 = min(H, math.ceil((lat0 - lat_s) * self.k) + 2)
        c0 = max(0, math.floor((lon_w - lon0) * self.k) - 1); c1 = min(W, math.ceil((lon_e - lon0) * self.k) + 2)
        if r0 >= r1 or c0 >= c1: raise SystemExit('la caja no cae en la tesela')
        self.nx, self.ny = c1 - c0, r1 - r0
        self.lat_n, self.lon_w = lat0 - r0 / self.k, lon0 + c0 / self.k
        self.nodata = float(T[42113]) if isinstance(T.get(42113), str) and T[42113].strip() else None
        self.v = array.array(code, bytes(array.array(code, [0]).itemsize * self.nx * self.ny))
        if 322 in T: tw, th, offs, cnts = T[322][0], T[323][0], T[324], T[325]
        else: tw, th, offs, cnts = W, T.get(278, [H])[0], T[273], T[279]   # franjas: bloques del ancho de la imagen
        per_row = math.ceil(W / tw); isz = self.v.itemsize
        for by in range(r0 // th, (r1 - 1) // th + 1):
            for bx in range(c0 // tw, (c1 - 1) // tw + 1):
                i = by * per_row + bx; raw = buf[offs[i]: offs[i] + cnts[i]]
                if comp != 1: raw = zlib.decompress(raw)
                blk = decode(raw, tw, th, isz, code, bo, pred)
                for r in range(max(r0, by * th), min(r1, by * th + th)):
                    a, b = max(c0, bx * tw), min(c1, bx * tw + tw)
                    s = (r - by * th) * tw + (a - bx * tw); d = (r - r0) * self.nx + (a - c0)
                    self.v[d: d + b - a] = blk[s: s + b - a]

def decode(raw, tw, th, isz, code, bo, pred):
    """Un bloque descomprimido -> array en el orden de bytes de esta máquina, deshaciendo el predictor."""
    native = '<' if sys.byteorder == 'little' else '>'
    if pred == 3:   # predictor de punto flotante: por fila, los bytes de cada valor separados (el más significativo primero) y diferenciados
        out = bytearray(len(raw)); n = tw * isz
        for r in range(th):
            # suma acumulada módulo 256: en enteros de 32 bits y luego el byte bajo de cada uno
            acc = array.array('I', accumulate(raw[r * n:(r + 1) * n]))
            if sys.byteorder == 'big': acc.byteswap()
            row = acc.tobytes()[0::4]
            for q in range(isz):    # el byte q (0 = más significativo) va a la posición que le toca en esta máquina
                pos = q if native == '>' else isz - 1 - q
                out[r * n + pos: (r + 1) * n: isz] = row[q * tw:(q + 1) * tw]
        return array.array(code, bytes(out))
    a = array.array({'f': 'I', 'h': 'H', 'H': 'H'}[code] if pred == 2 else code, raw)
    if bo != native: a.byteswap()
    if pred == 2:   # diferencias horizontales sobre los enteros sin signo del ancho del dato
        mask = (1 << (8 * isz)) - 1; u = a
        for r in range(th):
            u[r * tw:(r + 1) * tw] = array.array(u.typecode, (x & mask for x in accumulate(u[r * tw:(r + 1) * tw])))
        a = array.array(code, u.tobytes())
    return a

def main():
    if len(sys.argv) < 3: raise SystemExit(__doc__)
    cmd, path = sys.argv[1], sys.argv[2]
    if cmd == 'info':
        buf = open(path, 'rb').read(); bo, T = tags(buf)
        g = Raster(path)
        print(f'{T[256][0]}×{T[257][0]} px, {T[258][0]} bits (formato {T.get(339, [1])[0]}), compresión {T.get(259, [1])[0]}, '
              f'predictor {T.get(317, [1])[0]}, bloques {T.get(322, ["-"])[0]}×{T.get(323, ["-"])[0]}, {g.k} px/grado; '
              f'centro del píxel (0, 0) en {g.lat_n:.6f}, {g.lon_w:.6f}; sin dato: {g.nodata}')
    elif cmd == 'punto':
        lat, lon = float(sys.argv[3]), float(sys.argv[4]); d = 2 / 3600
        print(f'{Raster(path, lat + d, lat - d, lon - d, lon + d).at(lat, lon):.2f}')
    elif cmd == 'recorte':
        out = sys.argv[3]
        box = list(map(float, sys.argv[4:8])) if len(sys.argv) > 7 else [-35.28, -35.56, -71.76, -71.45]
        g = Raster(path, *box)
        hdr = {'lat_n': g.lat_n, 'lon_w': g.lon_w, 'k': g.k, 'nx': g.nx, 'ny': g.ny, 'scale': 0.1, 'src': path.rsplit('/', 1)[-1]}
        dm = array.array('h', (-32768 if x < -1000 else max(-32767, min(32767, round(x * 10))) for x in g.v))
        if sys.byteorder == 'little': dm.byteswap()
        with gzip.open(out, 'wb') as f: f.write((json.dumps(hdr) + '\n').encode()); f.write(dm.tobytes())
        print(hdr)
    else: raise SystemExit(__doc__)

if __name__ == '__main__':
    main()
