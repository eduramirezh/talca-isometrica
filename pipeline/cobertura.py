"""La cobertura vegetal de CONAF (Catastro de Uso de Suelo y Vegetación, Región del Maule, actualización 2024) como un
raster de clases cada 40 m: data/cobertura.json, que la plantilla lee junto a la pendiente (src/js/26-cobertura.js).

La plantilla decide dónde hay matorral y bosque por la pendiente real (`wildAt`, src/js/25-terrain.js): atrapa el
93 % del bosque nativo de CONAF pero solo el 17 % de las plantaciones, que están en el plano (raw/eval/chile.md §2).
Este raster dice qué hay en cada punto: bosque nativo (por densidad), bosque mixto, plantación (adulta, joven o
asilvestrada, con si es de eucalipto o pino), matorral arborescente, matorral, matorral con pradera, pradera,
humedal, agua, urbano o agrícola; la plantilla toma el mayor entre la pendiente y el peso de la clase.

  python -I pipeline/cobertura.py            -> data/cobertura.json (raw/cl/conaf/, python -I pipeline/fuentes_cl.py fetch conaf)
  python -I pipeline/cobertura.py stats      -> hectáreas por clase en la comuna, y cuánto de cada una ya marca la pendiente

Formato: {"o": [x0, y0], "s": 40, "n": [nx, ny], "k": [nombre de cada clase], "c": [clase, largo, clase, largo, …]}:
los nodos fila por fila desde (x0, y0) (la misma grilla de data/elevation.json hoy; la plantilla la muestrea por
coordenadas, así que no depende de ella), en corridas.
"""
import json, math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import DATA, EXT, comuna, require
from fuentes_cl import FILES, polys

S = 40
CLASES = ['agricola', 'urbano', 'agua', 'pradera', 'matorral-pradera', 'matorral', 'matorral-arborescente',
          'nativo-abierto', 'nativo-semidenso', 'nativo-denso', 'mixto', 'asilvestrada', 'plantacion', 'plantacion-joven', 'humedal']
TALL = ('Eucalyptus', 'Pinus', 'Populus')   # plantations of these look like columns (the template's poplar), the rest round

def clase(p):
    """A CONAF polygon's properties -> a class of CLASES (and whether its trees are tall, columnar ones)."""
    su, es, co = p.get('subuso') or '', p.get('estructura') or '', p.get('cobertura') or ''
    sp = ' '.join(p.get(f'especi{i}_ci') or '' for i in (1, 2))
    tall = any(t in (p.get('especi1_ci') or '') for t in TALL)
    if su == 'Bosque Nativo': return {'Denso': 'nativo-denso', 'Abierto': 'nativo-abierto'}.get(co, 'nativo-semidenso'), False
    if su == 'Bosque Mixto': return 'mixto', False
    if su == 'Plantación':
        if 'Asilvestradas' in es: return 'asilvestrada', tall
        return ('plantacion-joven' if 'Joven' in es else 'plantacion'), tall or not sp.strip()
    if su == 'Matorral Arborescente': return 'matorral-arborescente', False
    if su == 'Matorral': return 'matorral', False
    if su == 'Matorral-Pradera': return 'matorral-pradera', False
    if su == 'Praderas': return 'pradera', False
    if su in ('Ríos', 'Lagos, Lagunas, Embalses, Tranques', 'Cajas de Ríos'): return 'agua', False
    if su.startswith('Otros Terrenos Húmedos'): return 'humedal', False
    if su in ('Ciudades, Pueblos, Zonas Industriales', 'Minería Industrial'): return 'urbano', False
    return 'agricola', False

def raster():
    """The node grid of the commune's box (common.EXT, every S m) -> (nx, ny, bytearray of class indices, bytearray of
    tall flags). Each polygon (with its holes) is filled by scanlines over the node rows, its edges bucketed by row."""
    x0, x1, y0, y1 = EXT; nx, ny = int((x1-x0)//S)+1, int((y1-y0)//S)+1
    c, t = bytearray(nx*ny), bytearray(nx*ny)
    for p, rings in polys(require(FILES['conaf'], 'Ejecute: python -I pipeline/fuentes_cl.py fetch conaf')):
        k, tall = clase(p); k = CLASES.index(k)
        if not k: continue
        rows = {}
        for r in rings:
            for i in range(len(r)):
                (ax, ay), (bx, by) = r[i-1], r[i]
                if ay == by: continue
                lo, hi = (ay, by) if ay < by else (by, ay)
                for j in range(max(0, math.ceil((lo-y0)/S)), min(ny-1, math.floor((hi-y0)/S))+1):
                    y = y0 + j*S
                    if lo <= y < hi: rows.setdefault(j, []).append(ax + (y-ay)*(bx-ax)/(by-ay))
        for j, xs in rows.items():
            xs.sort()
            for m in range(0, len(xs)-1, 2):
                for i in range(max(0, math.ceil((xs[m]-x0)/S)), min(nx-1, math.floor((xs[m+1]-x0)/S))+1):
                    c[j*nx+i] = k; t[j*nx+i] = tall
    return nx, ny, c, t

def rle(a):
    out, i = [], 0
    while i < len(a):
        j = i
        while j < len(a) and a[j] == a[i]: j += 1
        out += [a[i], j-i]; i = j
    return out

def main():
    nx, ny, c, t = raster()
    # the tall flag rides on the class: plantations of eucalyptus or pine get their own names
    k = CLASES + [n + '-alta' for n in ('asilvestrada', 'plantacion', 'plantacion-joven')]
    a = bytearray(c)
    for i in range(len(a)):
        if t[i] and CLASES[a[i]] in ('asilvestrada', 'plantacion', 'plantacion-joven'): a[i] = k.index(CLASES[a[i]] + '-alta')
    out = {'fuente': 'CONAF, Catastro de los Recursos Vegetacionales y Uso de la Tierra, Región del Maule, actualización 2024 (IDE Minagri)',
           'o': [EXT[0], EXT[2]], 's': S, 'n': [nx, ny], 'k': k, 'c': rle(a)}
    f = DATA / 'cobertura.json'; f.write_text(json.dumps(out, separators=(',', ':')))
    print(f'{f.relative_to(DATA.parent)}: {nx} × {ny} nodos, {len(out["c"])//2} corridas, {f.stat().st_size//1024} KB')

def stats():
    """Hectares per class in the commune, and the share of each that the slope rule (wildAt > 0.35) already marks."""
    from usos import pip
    nx, ny, c, t = raster(); lim = comuna(); e = json.load(open(DATA / 'elevation.json'))
    (ex, ey), es, (enx, eny) = e['o'], e['s'], e['n']
    h, v = [0.0]*(enx*eny), 0
    for i, d in enumerate(e['h']): v += d; h[i] = v/10
    node = lambda i, j: min(eny-1, max(0, j))*enx + min(enx-1, max(0, i))
    def wild(i, j):
        m = 0
        for dj in (-1, 0, 1):
            for di in (-1, 0, 1):
                a, b = i+di, j+dj; m += math.hypot(h[node(a+1, b)]-h[node(a-1, b)], h[node(a, b+1)]-h[node(a, b-1)])/(2*es)
        s = max(0, min(1, (m/9-0.04)/0.07)); return s*s*(3-2*s)
    x0, y0 = EXT[0], EXT[2]; ha, wa = [0]*len(CLASES), [0]*len(CLASES)
    for j in range(ny):
        y = y0 + j*S; xs = sorted(lim[i-1][0] + (y-lim[i-1][1])*(lim[i][0]-lim[i-1][0])/(lim[i][1]-lim[i-1][1]) for i in range(len(lim)) if (lim[i-1][1] > y) != (lim[i][1] > y))
        for i in range(nx):
            x = x0 + i*S
            if not any(xs[m] <= x < xs[m+1] for m in range(0, len(xs)-1, 2)): continue
            k = c[j*nx+i]; ha[k] += S*S/1e4
            if wild(round((x-ex)/es), round((y-ey)/es)) > .35: wa[k] += S*S/1e4
    for k, n in enumerate(CLASES): print(f'{n:22} {ha[k]:8.0f} ha   pendiente > 0,35: {wa[k]/max(ha[k], 1e-9)*100:4.0f} %')

if __name__ == '__main__':
    if len(sys.argv) > 1 and sys.argv[1] == 'stats': stats()
    elif len(sys.argv) > 1: raise SystemExit(__doc__)
    else: main()
