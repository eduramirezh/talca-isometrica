"""Geocodificador de la grilla numerada de Talca y validador de ubicaciones.

Numeración (sistema de Daniel Barros Grez, 1869):
  * Calles Norte/Sur (corren oriente-poniente): los números crecen hacia el oriente,
    100 por cuadra. La cuadra entre 1 Poniente y 1 Oriente es la 700.
      k Poniente = 800 - 100k   ·   k Oriente = 700 + 100k
  * Calles Oriente/Poniente (corren norte-sur): crecen hacia el norte. La cuadra entre
    1 Sur y 1 Norte es la 1100.   k Sur = 1200 - 100k   ·   k Norte = 1100 + 100k
  * En 1 Norte los impares están al lado norte (verificado). En las demás calles es una
    suposición.

Uso:
  python pipeline/geocode.py address "2 Norte 781"      # coordenadas de una dirección
  python pipeline/geocode.py validate                   # compara data/pois.json con su dirección
  python pipeline/geocode.py lines                      # mediana de cada calle (candidatos para config/grid_lines.json)
"""
import json, re, sys, statistics, collections
from common import loc, unloc, NAV_GRAPH, DATA, require

PAT = re.compile(r'^(?:Avenida |Calle )?(\d+) (Norte|Sur|Oriente|Poniente)$')

def norm(nm):
    if not nm: return None
    if 'Alameda' in nm: return '4 Norte'          # la Alameda es la 4 Norte
    m = PAT.match(nm)
    return f'{m.group(1)} {m.group(2)}' if m else None

_cache = {}
def graph():
    if 'g' not in _cache:
        g = json.load(open(require(NAV_GRAPH)))
        N = {n['id']: loc(n['lon'], n['lat']) for n in g['nodes']}
        sn = collections.defaultdict(set)
        for e in g['edges']:
            s = norm(e['name'])
            if s: sn[s].add(e['u']); sn[s].add(e['v'])
        _cache['g'] = (N, sn)
    return _cache['g']

def lines(window=900):
    """Posición mediana de cada calle numerada cerca del centro."""
    N, sn = graph(); out = {}
    for s, ns in sn.items():
        d = s.split(' ', 1)[1]
        pts = [N[i] for i in ns]
        vals = [p[1] for p in pts if abs(p[0]) < window] if d in ('Norte', 'Sur') else [p[0] for p in pts if abs(p[1]) < window]
        if len(vals) >= 3: out[s] = statistics.median(vals)
    return out

def cross_for(street, number):
    """Calles transversales que encierran el número, fracción dentro de la cuadra y lado."""
    k, d = street.split(' ', 1); number = int(number); h = number // 100
    if d in ('Norte', 'Sur'):
        name = lambda h: f'{h-7} Oriente' if h >= 8 else f'{8-h} Poniente'
        return name(h), name(h + 1), (number % 100) / 100, (1 if number % 2 else -1)
    name = lambda h: f'{h-11} Norte' if h >= 12 else f'{12-h} Sur'
    return name(h), name(h + 1), (number % 100) / 100, (-1 if number % 2 else 1)

def geocode(street, number, side_off=14, table=None):
    """Devuelve ((x, y), (cruce_a, cruce_b)) en metros de grilla, o (None, ...) si falta una calle.
    side_off: metros desde el eje de la calle hacia el lado del número (usar ~45-95 en la Alameda)."""
    L = table or lines()
    a, b, f, side = cross_for(street, number)
    def inter(s1, s2):
        if s1.split(' ')[1] in ('Norte', 'Sur'): y, x = L.get(s1), L.get(s2)
        else: x, y = L.get(s1), L.get(s2)
        return None if x is None or y is None else (x, y)
    p, q = inter(street, a), inter(street, b)
    if not p or not q: return None, (a, b)
    x = p[0] + (q[0] - p[0]) * f; y = p[1] + (q[1] - p[1]) * f
    if street.split(' ')[1] in ('Norte', 'Sur'): y += side * side_off
    else: x += side * side_off
    return (x, y), (a, b)

ADDR = re.compile(r'^(\d+ (?:Norte|Sur|Oriente|Poniente))(?: \(Alameda\))? (\d+)')

def validate():
    L = lines(); pois = json.load(open(DATA / 'pois.json'))['pois']
    print(f'{"id":26s} {"dirección":28s} {"conf":6s} {"dist_m":>7s}')
    for p in pois:
        m = ADDR.match(p['a'])
        if not m: continue
        st, n = m.group(1), m.group(2)
        g, cr = geocode(st, n, 45 if st == '4 Norte' else 14, L)
        if not g: print(f'{p["id"]:26s} {p["a"][:28]:28s} {p["conf"]:6s}   (sin cruce {cr})'); continue
        d = ((g[0] - p['x']) ** 2 + (g[1] - p['y']) ** 2) ** .5
        flag = '  <-- revisar' if d > 80 else ''
        print(f'{p["id"]:26s} {p["a"][:28]:28s} {p["conf"]:6s} {d:7.0f}{flag}')

if __name__ == '__main__':
    cmd = sys.argv[1] if len(sys.argv) > 1 else 'validate'
    if cmd == 'address':
        m = re.match(r'(\d+ \w+) (\d+)', sys.argv[2]); g, cr = geocode(m.group(1), m.group(2))
        print('entre', cr, '->', g and unloc(*g))
    elif cmd == 'lines':
        for k, v in sorted(lines().items(), key=lambda kv: kv[1]): print(f'{k:12s} {v:8.0f}')
    else: validate()
