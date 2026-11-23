"""El plano de las calles: lo que dibujan los mapas de un proyecto de Godot que use la maqueta (un mapa en
miniatura, uno grande) y la red de calles para buscar el camino a un punto, de data/geometry.json y
data/ruta5.json -> modelo3d/datos/plano.json
(lo corre `make modelo3d`; no necesita modelo3d/mapa/ ni el navegador).

  python pipeline/plano.py [salida]   -> modelo3d/datos/plano.json (o salida)
  python pipeline/plano.py stats      -> la red: nodos, aristas, uniones en T, componentes y dónde están las mayores

La red: los vértices de las calles del mapa (las del grafo de cicloconecta y las de OSM fuera de él), juntados a menos
de JUNTAR m (las polilíneas comparten vértices en los cruces, pero no siempre al metro), más las uniones en T: el
extremo suelto de una calle a menos de T_CALLE m del tramo de otra (sin ellas, la red más grande tenía el 46 % de los
nodos; con ellas y la Ruta 5, ~96 %: lo demás son pistas y pasajes sueltos del campo y de las villas). La Ruta 5 entra con sus dos
calzadas y sus ramales, cada uno en su sentido (aristas dirigidas), y los extremos de los ramales se unen a menos de
T_RAMAL m de una calzada o de una calle: así el camino puede tomar la autopista entre dos enlaces.

Formato (enteros de 1 m de grilla, absolutos, no en delta: el juego los lee tal cual):
  calles    [[clase, índice del nombre, [x0, y0, x1, y1, …]], …]   clase 0 troncal … 7 servicio (SW de la página)
  nombres   los nombres de las calles
  manzanas  [[x0, y0, …], …]   anillos de las manzanas del Censo, simplificados a SIMPLE m
  agua      [[x0, y0, …], …]   el contorno del agua de cada río (DATA.area); islas: los huecos
  rios      [[ancho, [x0, y0, …]], …]   los ejes de los ríos y canales (con área, a lo más EJE_CON_AREA m de ancho)
  via       [[x0, y0, …], …]   la vía férrea y el ramal
  ruta5     [[x0, y0, …], …]   las dos calzadas; ramales: los enlaces
  limite    [x0, y0, …]        el límite de la comuna
  red       {"p": [x, y, …] los nodos, "a": [i, j, …] aristas de doble sentido, "d": [i, j, …] de un sentido (i -> j)}

Los datos son de OSM y del Censo (INE): ODbL, como data/geometry.json.
"""
import json, math, os, sys
from collections import defaultdict
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cli
from common import DATA, ROOT
from geom import dec, seg_dist, simplify_ring

OUT = ROOT / 'modelo3d' / 'datos' / 'plano.json'
JUNTAR = 2.0      # m: dos vértices de calle a menos de esto son el mismo nodo
T_CALLE = 3.0     # m: el extremo suelto de una calle sobre el tramo de otra
T_RAMAL = 12.0    # m: el extremo de un ramal de la Ruta 5 sobre una calzada o una calle
SIMPLE = 1.0      # m: la simplificación de las manzanas
EJE_CON_AREA = 8  # m: el ancho del eje de un río que tiene área (la tapa donde el área no llega)


def dec10(a):
    """La codificación de data/ruta5.json: en delta y en décimos de metro."""
    return [(x / 10, y / 10) for x, y in dec(a)]


def flat(pts):
    return [v for p in pts for v in (round(p[0]), round(p[1]))]


def cruce(a, b, c, d):
    """El punto donde se cruzan los segmentos ab y cd (sin contar las puntas), o None."""
    r = (b[0] - a[0], b[1] - a[1]); q = (d[0] - c[0], d[1] - c[1])
    den = r[0] * q[1] - r[1] * q[0]
    if abs(den) < 1e-9: return None
    t = ((c[0] - a[0]) * q[1] - (c[1] - a[1]) * q[0]) / den
    u = ((c[0] - a[0]) * r[1] - (c[1] - a[1]) * r[0]) / den
    if 1e-6 < t < 1 - 1e-6 and 1e-6 < u < 1 - 1e-6: return (a[0] + t * r[0], a[1] + t * r[1])
    return None


def param(p, a, b):
    dx, dy = b[0] - a[0], b[1] - a[1]
    return max(0.0, min(1.0, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / ((dx * dx + dy * dy) or 1)))


def red(lineas):
    """lineas: [(puntos, dirigida, tipo)] (tipo: 'calle', 'calzada', 'ramal') -> (nodos, aristas dobles, dirigidas,
    cortes: cuántos puntos se agregaron en medio de un tramo).

    Las calles se cruzan en un nodo aunque sus polilíneas no compartan un vértice: el grafo de cicloconecta deja tramos
    rectos largos (1 Oriente va de 1 Norte a 7 Norte en uno solo), y las calles que lo cruzan o llegan a él lo tocan en
    medio. Así, cada tramo de calle se corta donde lo cruza otra calle y donde un vértice de otra calle cae a menos de
    T_CALLE m de él. La autopista no se cruza con las calles (va en trinchera o en puente): sus calzadas se unen solo
    por los extremos de los ramales, cortadas en el punto de la calzada o de la calle a menos de T_RAMAL m."""
    segs = []   # [a, b, dirigida, tipo, línea]
    for li, (pts, dirigida, tipo) in enumerate(lineas):
        for a, b in zip(pts, pts[1:]):
            if math.dist(a, b) > 1e-6: segs.append((tuple(a), tuple(b), dirigida, tipo, li))
    C = 50.0
    rej = defaultdict(list)
    for k, (a, b, _, _, _) in enumerate(segs):
        for cx in range(int(min(a[0], b[0]) // C), int(max(a[0], b[0]) // C) + 1):
            for cy in range(int(min(a[1], b[1]) // C), int(max(a[1], b[1]) // C) + 1):
                rej[(cx, cy)].append(k)
    cortes = defaultdict(list)   # tramo -> [(t, punto)]
    vistos = set()
    for ks in rej.values():   # calle con calle: los cruces
        for i in range(len(ks)):
            si = segs[ks[i]]
            if si[3] != 'calle': continue
            for j in range(i + 1, len(ks)):
                sj = segs[ks[j]]
                if sj[3] != 'calle' or sj[4] == si[4]: continue
                par = (ks[i], ks[j]) if ks[i] < ks[j] else (ks[j], ks[i])
                if par in vistos: continue
                vistos.add(par)
                x = cruce(si[0], si[1], sj[0], sj[1])
                if x:
                    cortes[ks[i]].append((param(x, si[0], si[1]), x)); cortes[ks[j]].append((param(x, sj[0], sj[1]), x))

    def cerca(p, tol, ok):
        """Los tramos a menos de tol de p (sin contar sus puntas, que junta nodo()) que ok() acepta: [(d, k)]."""
        out = []; r = int(tol // C) + 1
        for cx in range(int(p[0] // C) - r, int(p[0] // C) + r + 1):
            for cy in range(int(p[1] // C) - r, int(p[1] // C) + r + 1):
                for k in rej.get((cx, cy), ()):
                    a, b = segs[k][0], segs[k][1]
                    if not ok(k) or math.dist(p, a) <= JUNTAR or math.dist(p, b) <= JUNTAR: continue
                    d = seg_dist(p, a, b)
                    if d <= tol: out.append((d, k))
        return out

    for li, (pts, _, tipo) in enumerate(lineas):   # el vértice de una calle sobre el tramo de otra
        if tipo != 'calle': continue
        for p in pts:
            p = tuple(p); hechos = set()
            for d, k in cerca(p, T_CALLE, lambda k: segs[k][3] == 'calle' and segs[k][4] != li):
                if k not in hechos:
                    hechos.add(k); cortes[k].append((param(p, segs[k][0], segs[k][1]), p))
    for li, (pts, _, tipo) in enumerate(lineas):   # los extremos de los ramales
        if tipo != 'ramal': continue
        for p in (tuple(pts[0]), tuple(pts[-1])):
            c = cerca(p, T_RAMAL, lambda k: segs[k][3] != 'ramal')
            if c:
                d, k = min(c); cortes[k].append((param(p, segs[k][0], segs[k][1]), p))

    nodos, celdas = [], defaultdict(list)

    def nodo(p):
        cx, cy = int(p[0] // JUNTAR), int(p[1] // JUNTAR)
        best = None
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                for i in celdas[(cx + dx, cy + dy)]:
                    d = math.dist(p, nodos[i])
                    if d <= JUNTAR and (best is None or d < best[0]): best = (d, i)
        if best: return best[1]
        nodos.append((round(p[0]), round(p[1]))); celdas[(cx, cy)].append(len(nodos) - 1)
        return len(nodos) - 1

    dobles, dirigidas = set(), set()
    n_cortes = 0
    for k, (a, b, dirigida, _, _) in enumerate(segs):
        cs = sorted(cortes.get(k, []))
        n_cortes += len(cs)
        cadena = [nodo(a)] + [nodo(p) for _, p in cs] + [nodo(b)]
        for u, v in zip(cadena, cadena[1:]):
            if u == v: continue
            if dirigida: dirigidas.add((u, v))
            else: dobles.add((min(u, v), max(u, v)))
    dirigidas -= {(u, v) for u, v in dirigidas if (min(u, v), max(u, v)) in dobles}
    return nodos, sorted(dobles), sorted(dirigidas), n_cortes


def lineas_de_red(g, r5):
    out = [(dec(s[2]), False, 'calle') for s in g['streets']]
    out += [(dec10(c['p']), True, 'calzada') for c in r5.get('c', [])]
    out += [(dec10(k[1:]), True, 'ramal') for k in r5.get('k', [])]
    return out


def cargar():
    g = json.loads((DATA / 'geometry.json').read_text())
    r5p = DATA / 'ruta5.json'
    r5 = json.loads(r5p.read_text()) if r5p.exists() else {}
    return g, r5


def componentes(n, dobles, dirigidas):
    adj = defaultdict(set)
    for a, b in list(dobles) + list(dirigidas): adj[a].add(b); adj[b].add(a)
    comp, cs = {}, []
    for s in range(n):
        if s in comp: continue
        comp[s] = len(cs); pila, m = [s], 0
        while pila:
            u = pila.pop(); m += 1
            for v in adj[u]:
                if v not in comp: comp[v] = len(cs); pila.append(v)
        cs.append(m)
    return comp, cs


def cmd_plano(salida: str = ''):
    """El plano de las calles -> modelo3d/datos/plano.json (o salida)."""
    g, r5 = cargar()
    nodos, dobles, dirigidas, n_t = red(lineas_de_red(g, r5))
    W = g.get('widths', {})
    out = {
        'calles': [[s[0], s[1], flat(dec(s[2]))] for s in g['streets']],
        'nombres': g['names'],
        'manzanas': [flat(simplify_ring(dec(b[3]), SIMPLE)) for b in g['blocks']],
        'agua': [], 'islas': [],
        'rios': [],
        'via': [flat(dec(g[k])) for k in ('rail', 'ramal') if g.get(k)],
        'ruta5': [flat(dec10(c['p'])) for c in r5.get('c', [])],
        'ramales': [flat(dec10(k[1:])) for k in r5.get('k', [])],
        'limite': flat(dec(g['limit'])),
        'red': {'p': [v for p in nodos for v in p], 'a': [v for e in dobles for v in e], 'd': [v for e in dirigidas for v in e]},
    }
    for k, polys in g.get('area', {}).items():
        for poly in polys:
            out['agua'].append(flat(dec(poly[0])))
            out['islas'] += [flat(dec(r)) for r in poly[1:]]
    for k, eje in g.get('water', {}).items():
        ancho = W.get(k, [6])[0]
        if g.get('area', {}).get(k): ancho = min(ancho, EJE_CON_AREA)
        out['rios'].append([ancho, flat(dec(eje))])
        for b in g.get('branch', {}).get(k, []): out['rios'].append([min(ancho, EJE_CON_AREA), flat(dec(b))])
    dest = ROOT / salida if salida and not os.path.isabs(salida) else (salida or OUT)
    dest = type(OUT)(dest); dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(json.dumps(out, separators=(',', ':'), ensure_ascii=False))
    _, cs = componentes(len(nodos), dobles, dirigidas)
    print(f'{dest.relative_to(ROOT) if dest.is_relative_to(ROOT) else dest}: {len(out["calles"])} calles, '
          f'{len(nodos)} nodos, {len(dobles)} + {len(dirigidas)} aristas ({n_t} cortes en medio de un tramo; la red mayor, '
          f'{100 * max(cs) / len(nodos):.0f} % de los nodos), {dest.stat().st_size / 1e6:.2f} MB')


def cmd_stats():
    """La red: nodos, aristas, uniones en T y las componentes mayores con su caja."""
    g, r5 = cargar()
    nodos, dobles, dirigidas, n_t = red(lineas_de_red(g, r5))
    comp, cs = componentes(len(nodos), dobles, dirigidas)
    print(f'{len(nodos)} nodos, {len(dobles)} aristas de doble sentido, {len(dirigidas)} de un sentido, {n_t} cortes en medio de un tramo')
    print(f'{len(cs)} componentes; la mayor: {max(cs)} nodos ({100 * max(cs) / len(nodos):.1f} %)')
    orden = sorted(range(len(cs)), key=lambda c: -cs[c])[:6]
    caja = {c: [1e9, 1e9, -1e9, -1e9] for c in orden}
    for i, c in comp.items():
        if c in caja:
            b, p = caja[c], nodos[i]
            b[0], b[1], b[2], b[3] = min(b[0], p[0]), min(b[1], p[1]), max(b[2], p[0]), max(b[3], p[1])
    for c in orden:
        b = caja[c]
        print(f'  {cs[c]:6d} nodos  x {b[0]:.0f} … {b[2]:.0f}  y {b[1]:.0f} … {b[3]:.0f}')


if __name__ == '__main__':
    cli.run({'stats': cmd_stats}, __doc__, default=cmd_plano)
