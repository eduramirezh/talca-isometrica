"""El giro de la grilla de una ciudad: el rumbo dominante de sus calles alrededor de un punto (su plaza).

Uso:
  python -I pipeline/grilla.py <grafo.json|map-*.json> <lat> <lon> [radio ...]
  python -I pipeline/grilla.py raw/cicloconecta/data/cities/talca/nav_graph.json -35.42653 -71.66600
  python -I pipeline/grilla.py curico/nav_graph.json -34.9854 -71.2394 600 1200

Lee un grafo de cicloconecta (`nodes` con lat/lon, `edges` con u/v) o un JSON de la API map de OpenStreetMap
(`elements`: nodos y vías con `highway`). Para cada radio (por omisión 600, 1200 y 2500 m) arma el histograma de los
rumbos de los tramos, plegado a [0°, 90°) y ponderado por largo, y da el pico y la parte del largo que cae a ±2° de él.
Es la medición de docs/METODOLOGIA.md §3: en Talca da 85° (las calles a −5°: `common.TH` = +5°). El giro que alinea la
grilla con los ejes es el pico con el signo cambiado, llevado a (−45°, 45°]. Un pico con menos de ~40 % del largo a
±2° dentro de 1 km es una grilla irregular: no hay un giro que la alinee. Ver docs/PLAN-COMUNAS.md.
"""
import json, math, sys, collections


def segments(path, lat0, lon0):
    """The street segments of a graph or an OSM map file, in metres east and north of (lat0, lon0)."""
    d = json.load(open(path))
    KX, KY = 111320 * math.cos(math.radians(abs(lat0))), 110950
    P = lambda lon, lat: ((lon - lon0) * KX, (lat - lat0) * KY)
    if 'edges' in d:
        N = {n['id']: P(n['lon'], n['lat']) for n in d['nodes']}
        seen = set()
        for e in d['edges']:
            k = frozenset((e['u'], e['v']))
            if k in seen or e['u'] not in N or e['v'] not in N: continue
            seen.add(k); yield N[e['u']], N[e['v']]
    else:
        N = {e['id']: P(e['lon'], e['lat']) for e in d['elements'] if e['type'] == 'node'}
        for e in d['elements']:
            if e['type'] != 'way' or 'highway' not in e.get('tags', {}) or e['tags'].get('area') == 'yes': continue
            ns = [N[n] for n in e['nodes'] if n in N]
            yield from zip(ns, ns[1:])


def main(a):
    if len(a) < 3: raise SystemExit(__doc__)
    path, lat0, lon0 = a[0], float(a[1]), float(a[2])
    radii = [float(r) for r in a[3:]] or [600, 1200, 2500]
    segs = list(segments(path, lat0, lon0))
    for R in radii:
        H, tot, A = collections.Counter(), 0.0, []
        for p, q in segs:
            if math.hypot(*p) > R: continue
            dx, dy = q[0] - p[0], q[1] - p[1]; L = math.hypot(dx, dy)
            if L < 5: continue
            a = math.degrees(math.atan2(dy, dx)) % 90
            H[round(a) % 90] += L; A.append((a, L)); tot += L
        if not tot: print(f'{R:.0f} m: sin calles'); continue
        pk = max(range(90), key=lambda d: sum(H[(d + k) % 90] for k in (-1, 0, 1)))
        near = [((a - pk + 45) % 90 - 45, L) for a, L in A if abs((a - pk + 45) % 90 - 45) <= 2]   # offsets from pk, ±2°
        share = sum(L for _, L in near) / tot
        ang = (pk + sum(o * L for o, L in near) / sum(L for _, L in near)) % 90   # the peak, refined by the mean angle
        giro = -ang if ang <= 45 else 90 - ang
        print(f'{R:.0f} m: pico en {ang:.1f}°, {share:.0%} del largo a ±2° ({tot / 1000:.0f} km de calles); giro de la grilla {giro:+.1f}°')


if __name__ == '__main__':
    main(sys.argv[1:])
