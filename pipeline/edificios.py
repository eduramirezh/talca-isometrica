"""Edificios de OpenStreetMap, donde OSM los tiene todos o algunos, y huellas de aprendizaje automático donde OSM no
tiene el edificio: data/edificios.json (METODOLOGIA §14).

La ciudad de la maqueta es generada (cityGen, en la plantilla): casas sobre lotes a lo largo de las calles, con
recetas por barrio. En el centro OSM tiene casi todos los edificios con sus pisos, y ahí la planta real se ve mejor
que cualquier receta: las torres donde están, las galerías, los patios y los estacionamientos de verdad. Este script
clasifica las manzanas construidas de las `areas` de config/edificios.json: enteras, cuya superficie cubren los
edificios de OSM (en `cobertura`, o en `cobertura_pisos` contando solo los que tienen pisos o altura, que en el centro
vienen de una importación que levantó manzanas enteras; cada área puede tener sus umbrales, y null apaga el segundo),
y mixtas, con al menos un edificio de `mixto.m2` o más. Escribe sus edificios, con su planta, su altura y su tipo
(en las mixtas, los de `mixto.m2` o más), y las superficies que OSM dibuja dentro de ellas (estacionamientos, pasto,
jardines, piscinas, juegos). build.py lo inyecta como DATA.ed y la sección «edificios de OSM» de la plantilla
(src/js/52-edificios.js) los dibuja; cityGen() no pone lotes en las enteras y en las mixtas llena los frentes libres.
`forzar` (entera), `quitar` (mixta) y `generar` (sin OSM) son puntos dentro de una manzana, para corregir a mano.

Donde OSM no tiene el edificio entran las huellas de aprendizaje automático de Microsoft y Google (Overture Maps), que
tools/ml_buildings.py deja en raw/edificios-ml/ (METODOLOGIA §14): OSM gana siempre (fuera la huella con un 10 % sobre
un edificio de OSM), solo OSM hace una manzana entera, y no entran en las áreas con `"ml": false` (el centro). Una
manzana construida con huellas que entran es mixta. Las huellas fuera de toda manzana (villas posteriores al Censo,
galpones y casas del campo) van sueltas, en grupos por celdas de 500 m, sin suelo de manzana. Cada huella se corre por
la mediana de su desfase contra OSM (shifts(), medido en cada corrida), y se quitan las de Google con confianza bajo
0,8, las de menos de `mixto.m2`, las de centro en una calzada del mapa o en el agua, las que otra mayor cubre en más
de la mitad (duplicadas: dups()), y las sueltas rurales aisladas
(sin landuse residencial, industrial, comercial o de granja y a más de 100 m de una vía de OSM) que no confirma una
segunda fuente (Google v3 sobre una de Microsoft, o la presencia de Google 2.5D en 2023). Los pisos de las huellas y de
los edificios de OSM sin dato salen del alto de Google 2.5D Temporal 2023 desde 11 m (raster_floors); bajo eso siguen
estimados (la plantilla les da uno o dos pisos).

  python pipeline/edificios.py                 # escribe data/edificios.json e imprime las manzanas elegidas (make edificios)
  python pipeline/edificios.py solo-osm        # lo mismo sin las huellas de aprendizaje automático (como hasta octubre de 2026)
  python pipeline/edificios.py manzanas [n]    # las n manzanas más cercanas al umbral, con su cobertura y un punto
  uv run --with pillow python pipeline/edificios.py panel [x0 x1 y0 y1] [z]
      diagnostics/edificios.png: la imagen satelital con las manzanas (verde: entera, amarillo: mixta, rojo: sin
      OSM, con su cobertura) y
      los edificios de OSM coloreados por pisos (verde 1, amarillo 2, naranjo 3–5, rojo 6 o más, magenta sin dato) y las
      huellas de aprendizaje automático que entran, ya corridas, sin relleno (celeste: Microsoft; azul: Google);
      en cada manzana, su cobertura y la de los edificios con pisos (solo OSM)
  uv run --with pillow python pipeline/edificios.py techos [z]
      config/techos.json: la familia del techo de cada edificio de data/edificios.json (CP.roof de la plantilla:
      teja, óxido, zinc, claro…), clasificada con la imagen satelital de Esri (la mediana de los píxeles claros dentro
      de su planta, sin el borde; solo se guarda la familia). Luego `make edificios build`.

Lo que hace con OSM:
  - Plantas: vías y multipolígonos con `building` (no `building:part`), simplificadas a 0,25 m, en sentido
    antihorario, sin las de menos de 4 m². Cada edificio va a la manzana que contiene su centro.
  - Altura: `building:levels` (3 m por piso más 0,5) salvo que `height` diga otra cosa que 2,8 m por piso (el valor
    por omisión de la importación de Talca); sin dato, un piso (y la marca «estimada»).
  - Tipo: el valor de `building` (casa, comercio, público, iglesia, techo, ruina, galpón, departamentos, otro).
  - Las plantas de OSM pueden quedar unos metros corridas respecto de las calles del mapa (trampa «Calzadas del mapa
    y plantas de OSM»): la plantilla las recorta a la línea de las veredas.

Formato de data/edificios.json (los edificios de OSM y las superficies en decímetros, con los anillos codificados en
delta como geometry.json; las huellas, en "h"):
  {"m": [[x, y], …] un punto dentro de cada manzana entera (metros de grilla, con un decimal), "x": lo mismo, mixtas,
   "z": [[x0, y0, x1, y1], …] la caja de cada grupo de huellas sueltas,
   "e": [[id, [anillo, hueco, …], alto, tipo, pisos, techo, estimada, manzana], …] los edificios de OSM,
   "s": [[anillo, superficie, manzana], …],
   "h": {"q": HQ, "K": HK, "k": [manzana, cuántas, …], "c": [[alto, tipo, pisos, estimada, fuente], …], "i": [fila de c, …],
         "n": […], "o": […], "l": […]} las huellas de aprendizaje automático (h_encode),
   "tipos": [...], "superficies": [...], "techos": [...], "fuentes": [...]}
techo es el índice en "techos" de la familia de config/techos.json, o -1 sin dato; estimada, 0 con pisos de OSM, 1 sin
dato (la plantilla elige uno o dos pisos), 2 con pisos de Google 2.5D; manzana, su lugar en m, luego x y luego z;
fuente, el índice en "fuentes" (ms, google). Las huellas van de a corridas de una manzana ("k"), en el orden de las
manzanas, y en cada una después de sus edificios de OSM; sus plantas, sin huecos, como las describe h_encode().
"""
import json, math, sys
from common import ROOT, RAW, DATA, CONFIG, loc, require
from build import dec, pip, mark_built, land_uses

TIPOS = ['otro', 'casa', 'comercio', 'publico', 'iglesia', 'techo', 'ruina', 'galpon', 'departamentos']
TIPO = {'house': 1, 'residential': 1, 'detached': 1, 'semidetached_house': 1, 'terrace': 1, 'bungalow': 1,
        'commercial': 2, 'retail': 2, 'office': 2, 'supermarket': 2, 'hotel': 2, 'kiosk': 2,
        'public': 3, 'civic': 3, 'government': 3, 'school': 3, 'university': 3, 'college': 3, 'hospital': 3,
        'kindergarten': 3, 'train_station': 3, 'fire_station': 3,
        'church': 4, 'cathedral': 4, 'chapel': 4, 'religious': 4,
        'roof': 5, 'carport': 5, 'ruins': 6,
        'industrial': 7, 'warehouse': 7, 'garage': 7, 'garages': 7, 'shed': 7, 'service': 7,
        'apartments': 8, 'dormitory': 8}
SUPERFICIES = ['estacionamiento', 'pasto', 'jardin', 'piscina', 'juegos']
def superficie(t):
    if t.get('amenity') == 'parking' and t.get('parking') not in ('underground', 'multi-storey'): return 0
    if t.get('landuse') in ('grass', 'village_green'): return 1
    if t.get('leisure') == 'garden': return 2
    if t.get('leisure') == 'swimming_pool': return 3
    if t.get('leisure') == 'playground': return 4
    return None
TECHOS = ['tile', 'tileOld', 'rust', 'red', 'zinc', 'zincOld', 'light', 'green', 'blue']   # las familias de CP.roof

def num(v):
    try: return float(str(v).replace(',', '.').split()[0])
    except (TypeError, ValueError, IndexError): return None

def area(r): return sum(r[i-1][0]*r[i][1]-r[i][0]*r[i-1][1] for i in range(len(r)))/2

def simplify(pts, eps):
    """Douglas-Peucker sobre una polilínea abierta."""
    if len(pts) < 3: return pts
    a, b = pts[0], pts[-1]; dx, dy = b[0]-a[0], b[1]-a[1]; L = math.hypot(dx, dy)
    best, k = -1, 0
    for i in range(1, len(pts)-1):
        p = pts[i]
        d = abs(dy*(p[0]-a[0])-dx*(p[1]-a[1]))/L if L > 1e-9 else math.hypot(p[0]-a[0], p[1]-a[1])
        if d > best: best, k = d, i
    if best <= eps: return [a, b]
    return simplify(pts[:k+1], eps)[:-1] + simplify(pts[k:], eps)

def ring_of(pts, eps=0.25, ccw=True):
    """Un anillo cerrado de OSM -> sin el nodo repetido, simplificado, en el sentido pedido; None si queda chico."""
    if len(pts) > 1 and pts[0] == pts[-1]: pts = pts[:-1]
    if len(pts) < 3: return None
    # simplificado como dos mitades abiertas, para que el primer vértice no quede fijo en una arista recta
    h = len(pts)//2; r = simplify(pts[:h+1], eps)[:-1] + simplify(pts[h:] + [pts[0]], eps)[:-1]
    if len(r) < 3 or abs(area(r)) < 1: return None
    if (area(r) > 0) != ccw: r.reverse()
    return r

def assemble(ways):
    """Las vías de un multipolígono (listas de puntos) unidas por sus extremos en anillos cerrados."""
    ways = [w[:] for w in ways if len(w) > 1]; rings = []
    while ways:
        cur = ways.pop(0)
        while cur[0] != cur[-1]:
            for i, w in enumerate(ways):
                if w[0] == cur[-1]: cur += w[1:]
                elif w[-1] == cur[-1]: cur += w[::-1][1:]
                elif w[-1] == cur[0]: cur = w + cur[1:]
                elif w[0] == cur[0]: cur = w[::-1] + cur[1:]
                else: continue
                ways.pop(i); break
            else: break
        if cur[0] == cur[-1]: rings.append(cur)
    return rings

def enc(pts):
    """[(x, y), …] en metros -> enteros en decímetros, en delta."""
    out = []; px = py = 0
    for x, y in pts:
        xi, yi = int(round(x*10)), int(round(y*10)); out += [xi-px, yi-py]; px, py = xi, yi
    return out

# Las huellas de aprendizaje automático ("h" de data/edificios.json; METODOLOGIA §14). Casi todas tienen solo ángulos
# rectos (Microsoft las regulariza): se guardan como una dirección y los largos de sus lados sobre una grilla de HQ m
# girada a esa dirección, y las demás como polígono sobre la grilla de la maqueta. HQ es el píxel de arte (ESTETICA §2):
# cada lado se mueve hasta HQ/2 en su perpendicular, y dos casas pareadas en la misma dirección siguen compartiendo el
# muro (los dos redondean la misma línea). Una huella que se movería más de HTOL m va como polígono.
HQ, HK, HTOL = 0.5, 115, 0.5

def h_dir(k):
    """La dirección k (0 ≤ k < 2·HK): (HK, k) hasta 45° y (2·HK − k, HK) desde ahí, normalizada (~0,5° entre una y otra
    junto a los ejes, ~0,25° a 45°). Solo enteros y una raíz: la plantilla obtiene exactamente los mismos números."""
    a, b = (HK, k) if k < HK else (2*HK - k, HK); s = math.sqrt(a*a + b*b); return a/s, b/s

def h_round(v): return math.floor(v + 0.5)                   # Math.floor(v + .5) en la plantilla (no el round de Python)

def h_k(r):
    """La dirección más cercana a la de los lados de r: su ángulo medio módulo 90°, pesado por el largo."""
    s = c = 0
    for i in range(len(r)):
        (ax, ay), (bx, by) = r[i-1], r[i]; L = math.hypot(bx-ax, by-ay); t = 4*math.atan2(by-ay, bx-ax); s += L*math.sin(t); c += L*math.cos(t)
    th = math.atan2(s, c)/4 % (math.pi/2)
    if th < math.pi/4: return h_round(HK*math.tan(th)) % (2*HK)
    return (2*HK - h_round(HK*math.tan(math.pi/2 - th))) % (2*HK)

def h_clean(V):
    """Sin vértices repetidos ni alineados con sus vecinos (lo que deja el redondeo), o None si queda menos de un triángulo."""
    V = list(V)
    while True:
        n = len(V)
        if n < 3: return None
        for i in range(n):
            a, b, c = V[i-1], V[i], V[(i+1) % n]
            if b == a or (b[0]-a[0])*(c[1]-a[1]) == (b[1]-a[1])*(c[0]-a[0]): del V[i]; break
        else: return V

def h_ok(V):
    """Un anillo de enteros antihorario y simple (ningún par de lados no vecinos se toca)."""
    n = len(V)
    if sum(V[i-1][0]*V[i][1] - V[i][0]*V[i-1][1] for i in range(n)) <= 0: return False
    X = lambda o, a, b: (a[0]-o[0])*(b[1]-o[1]) - (a[1]-o[1])*(b[0]-o[0])
    def meet(a, b, c, d):
        d1, d2, d3, d4 = X(a, b, c), X(a, b, d), X(c, d, a), X(c, d, b)
        if ((d1 > 0) != (d2 > 0) and d1 and d2) and ((d3 > 0) != (d4 > 0) and d3 and d4): return True
        on = lambda p, q, r: min(p[0], q[0]) <= r[0] <= max(p[0], q[0]) and min(p[1], q[1]) <= r[1] <= max(p[1], q[1])
        return (not d1 and on(a, b, c)) or (not d2 and on(a, b, d)) or (not d3 and on(c, d, a)) or (not d4 and on(c, d, b))
    for i in range(n):
        for j in range(i+2, n):
            if i == 0 and j == n-1: continue
            if meet(V[i], V[(i+1) % n], V[j], V[(j+1) % n]): return False
    return True

def h_rect(r, k):
    """r como polígono rectilíneo en la dirección k: sus vértices en enteros de la grilla girada (u a lo largo de k, v a
    90°), el primer lado hacia +u; None si r no lo es (un lado a más de 12° de los ejes, dos seguidos paralelos)."""
    cu, su = h_dir(k); n = len(r)
    if n < 4 or n % 2: return None
    P = [((x*cu + y*su)/HQ, (-x*su + y*cu)/HQ) for x, y in r]; ax = []
    for i in range(n):
        (au, av), (bu, bv) = P[i], P[(i+1) % n]; du, dv = abs(bu-au), abs(bv-av)
        if min(du, dv) > 0.2126*max(du, dv): return None     # tan 12°
        ax.append(0 if du >= dv else 1)
    if any(ax[i] == ax[i-1] for i in range(n)): return None
    # la línea de cada lado (su v si va a lo largo de u, su u si va a lo largo de v), redondeada; el vértice i, entre el
    # lado i − 1 y el i
    L = [h_round((P[i][1] + P[(i+1) % n][1])/2 if ax[i] == 0 else (P[i][0] + P[(i+1) % n][0])/2) for i in range(n)]
    V = h_clean([(L[i-1], L[i]) if ax[i] == 0 else (L[i], L[i-1]) for i in range(n)])
    if not V or len(V) < 4 or not h_ok(V): return None
    i0 = next(i for i in range(len(V)) if V[(i+1) % len(V)][1] == V[i][1] and V[(i+1) % len(V)][0] > V[i][0])
    return V[i0:] + V[:i0]

def h_dev(r, G):
    """Cuánto se aleja G de r (m): el mayor de las distancias de cada vértice de uno al contorno del otro."""
    def far(A, B): return max(min(math.sqrt(seg_d2(p, B[j-1], B[j])) for j in range(len(B))) for p in A)
    return max(far(r, G), far(G, r))

def seg_d2(p, a, b):
    dx, dy = b[0]-a[0], b[1]-a[1]; L = dx*dx + dy*dy; t = ((p[0]-a[0])*dx + (p[1]-a[1])*dy)/L if L else 0; t = min(1, max(0, t))
    return (a[0]+t*dx-p[0])**2 + (a[1]+t*dy-p[1])**2

def h_encode(rings):
    """Las huellas (anillos antihorarios, en metros de grilla, en el orden de la plantilla) -> ({"n", "o", "l"}: tres
    listas de enteros, los anillos como los decodifica la plantilla, cuántas rectilíneas). Por huella: en "n", k + 2·HK·(n/2 − 2)
    si es rectilínea con n vértices en la dirección k (un rectángulo, solo k), −n si es otra; en "o", su primer vértice
    relativo al de la anterior, llevado a su grilla (Math.floor(… + .5), con las mismas operaciones que la plantilla); en
    "l", una rectilínea, los largos de sus lados alternando u y v menos los dos últimos, que cierran el polígono; otra, los
    otros vértices en delta sobre la grilla de la maqueta de HQ m. Una que el redondeo deja sin superficie o cruzada no se
    escribe (None en su lugar)."""
    N, O, L, out = [], [], [], []; px = py = 0.0; pk = 0; nr = 0
    for r in rings:
        kn = h_k(r); best = None
        near = lambda a, b: min((a-b) % (2*HK), (b-a) % (2*HK))
        for k in ([pk] if near(pk, kn) <= 4 else []) + [kn, (kn+1) % (2*HK), (kn-1) % (2*HK)]:
            V = h_rect(r, k)
            if not V: continue
            cu, su = h_dir(k); G = [((u*cu - v*su)*HQ, (u*su + v*cu)*HQ) for u, v in V]; d = h_dev(r, G)
            if d <= HTOL and (best is None or (d < best[0] - 0.05 and k != pk)): best = (d, k, V, G)
            if best and best[1] == pk: break                # la dirección de la anterior, si sirve: muros compartidos
        if best:
            d, k, V, G = best; cu, su = h_dir(k); n = len(V)
            N.append(k + 2*HK*(n//2 - 2)); O += [V[0][0] - h_round((px*cu + py*su)/HQ), V[0][1] - h_round((-px*su + py*cu)/HQ)]
            L += [V[i+1][i % 2] - V[i][i % 2] for i in range(n-2)]
            pk = k; nr += 1
        else:
            V = h_clean([(h_round(x/HQ), h_round(y/HQ)) for x, y in r])
            if not V or not h_ok(V): out.append(None); continue
            N.append(-len(V)); O += [V[0][0] - h_round(px/HQ), V[0][1] - h_round(py/HQ)]
            for i in range(1, len(V)): L += [V[i][0] - V[i-1][0], V[i][1] - V[i-1][1]]
            G = [(u*HQ, v*HQ) for u, v in V]
        out.append(G); px, py = G[0]
    return {'n': N, 'o': O, 'l': L}, out, nr

_ELS = {}
def elements(name='comuna'):
    if name not in _ELS: _ELS[name] = json.load(open(require(RAW / 'osm' / f'map-{name}.json', 'Ejecute: make osm')))['elements']
    return _ELS[name]

_NODES = {}
def node_locs(name='comuna'):
    if name not in _NODES: _NODES[name] = {e['id']: loc(e['lon'], e['lat']) for e in elements(name) if e['type'] == 'node'}
    return _NODES[name]

def osm(name='comuna'):
    """Los edificios y las superficies de raw/osm/map-<name>.json: ([(id, [anillo, hueco…], tags)], [(anillo, tipo)])."""
    els = elements(name); nodes = node_locs(name)
    ways = {e['id']: e for e in els if e['type'] == 'way'}
    pts = lambda w: [nodes[n] for n in w['nodes'] if n in nodes]
    bld, srf = [], []
    for e in els:
        t = e.get('tags') or {}
        if e['type'] == 'way' and e['nodes'][0] == e['nodes'][-1]:
            if 'building' in t and t['building'] != 'no':
                r = ring_of(pts(e))
                if r: bld.append((f"w{e['id']}", [r], t))
            elif superficie(t) is not None:
                r = ring_of(pts(e), 0.4)
                if r: srf.append((r, superficie(t)))
        elif e['type'] == 'relation' and t.get('type') == 'multipolygon' and 'building' in t:
            outer = assemble([pts(ways[m['ref']]) for m in e['members'] if m['type'] == 'way' and m.get('role') == 'outer' and m['ref'] in ways])
            inner = assemble([pts(ways[m['ref']]) for m in e['members'] if m['type'] == 'way' and m.get('role') == 'inner' and m['ref'] in ways])
            for o in outer:
                r = ring_of(o)
                if not r: continue
                holes = [h for h in (ring_of(i, ccw=False) for i in inner) if h and pip(h[0], r)]
                bld.append((f"r{e['id']}", [r] + holes, t))
    return bld, srf

def height(t):
    """(alto en m, pisos, estimada)."""
    lv, h = num(t.get('building:levels')), num(t.get('height'))
    if h and lv and abs(h - 2.8*lv) < 0.05: h = None      # el valor por omisión de la importación: 2,8 m por piso
    if t.get('building') in ('roof', 'carport'): return (h or 4.0), 1, h is None
    if h: return h, lv or max(1, round(h/3)), False
    if lv: return lv*3.0 + 0.5, lv, False
    return 3.5, 1, True

def blocks():
    """Las manzanas como las ve la plantilla: las del Censo (data/geometry.json) reclasificadas por config/manzanas.json y
    por las entradas `vivienda` de config/usos.json, más las que esas entradas agregan donde el Censo no tiene manzana
    (build.land_uses), al final: las villas posteriores al Censo."""
    g = json.load(open(require(DATA / 'geometry.json', 'Ejecute: make data'))); mark_built(g['blocks']); land_uses(g)
    out = []
    for i, b in enumerate(g['blocks']):
        r = dec(b[3]); xs = [p[0] for p in r]; ys = [p[1] for p in r]
        out.append({'i': i, 'built': b[0] in (0, 3), 'r': r, 'A': abs(area(r)), 'bb': (min(xs), min(ys), max(xs), max(ys))})
    return out

def inside(b, p): bb = b['bb']; return bb[0] <= p[0] <= bb[2] and bb[1] <= p[1] <= bb[3] and pip(p, b['r'])

def point_in(b):
    """Un punto dentro de la manzana: su centroide, o el medio del tramo más largo de la fila central."""
    r = b['r']; A = area(r)
    cx = sum((r[i-1][0]+r[i][0])*(r[i-1][0]*r[i][1]-r[i][0]*r[i-1][1]) for i in range(len(r)))/(6*A)
    cy = sum((r[i-1][1]+r[i][1])*(r[i-1][0]*r[i][1]-r[i][0]*r[i-1][1]) for i in range(len(r)))/(6*A)
    if pip((cx, cy), r): return (cx, cy)
    y = (b['bb'][1]+b['bb'][3])/2
    xs = sorted(r[i-1][0]+(y-r[i-1][1])*(r[i][0]-r[i-1][0])/(r[i][1]-r[i-1][1]) for i in range(len(r)) if (r[i-1][1] > y) != (r[i][1] > y))
    a, c = max(((xs[k], xs[k+1]) for k in range(0, len(xs)-1, 2)), key=lambda s: s[1]-s[0])
    return ((a+c)/2, y)

def centroid(r): return (sum(p[0] for p in r)/len(r), sum(p[1] for p in r)/len(r))

def centre(r):
    """El centroide de área de un anillo (el de vértices se corre hacia las esquinas con muchos puntos)."""
    A = area(r)
    if abs(A) < 1e-9: return centroid(r)
    cx = sum((r[i-1][0]+r[i][0])*(r[i-1][0]*r[i][1]-r[i][0]*r[i-1][1]) for i in range(len(r)))/(6*A)
    cy = sum((r[i-1][1]+r[i][1])*(r[i-1][0]*r[i][1]-r[i][0]*r[i-1][1]) for i in range(len(r)))/(6*A)
    return (cx, cy)

def median(v):
    v = sorted(v); n = len(v)
    return (v[n//2] if n % 2 else (v[n//2-1]+v[n//2])/2) if n else 0.0

ML = RAW / 'edificios-ml'                                    # tools/ml_buildings.py

def shifts(bld=None):
    """El corrimiento de cada fuente de aprendizaje automático contra OSM: {fuente: (dx, dy, pares)}, la mediana de la
    diferencia entre los centros de los pares 1:1: una huella de raw/edificios-ml/ajuste-<fuente>.jsonl y el edificio de
    OSM más cercano, a menos de 6 m, con un área de 0,6 a 1,6 veces la suya y sin otra huella que lo elija."""
    if bld is None: bld = osm()[0]
    O = [(centre(r[0]), abs(area(r[0]))) for _, r, _ in bld]; G = {}
    for k, (c, _) in enumerate(O): G.setdefault((int(c[0]//10), int(c[1]//10)), []).append(k)
    out = {}
    for f in ('ms', 'google'):
        path = ML / f'ajuste-{f}.jsonl'
        if not path.exists(): continue
        pairs = {}
        for l in open(path):
            r = [loc(*p) for p in json.loads(l)['r']]; c, a = centre(r), abs(area(r)); best = None
            for gx in range(int(c[0]//10)-1, int(c[0]//10)+2):
                for gy in range(int(c[1]//10)-1, int(c[1]//10)+2):
                    for k in G.get((gx, gy), ()):
                        d = math.hypot(c[0]-O[k][0][0], c[1]-O[k][0][1])
                        if d < 6 and 0.6 <= a/O[k][1] <= 1.6 and (best is None or d < best[0]): best = (d, k)
            if best: pairs.setdefault(best[1], []).append((c[0]-O[best[1]][0][0], c[1]-O[best[1]][0][1]))
        one = [v[0] for v in pairs.values() if len(v) == 1]
        out[f] = (median([d[0] for d in one]), median([d[1] for d in one]), len(one))
    return out

SW = [16, 13, 11, 9.5, 7, 5, 3.5, 3.5]                        # el ancho de las calles del mapa por clase (SW de la plantilla)
FUENTES = ['osm', 'ms', 'google']
LANDUSE = {'residential', 'industrial', 'commercial', 'retail', 'farmyard'}   # donde una huella rural no está aislada

class Cells:
    """Un índice por celdas de c m: add(caja, v) pone v en las celdas de la caja; at(x, y, m) da lo de las celdas a
    menos de m de (x, y), y over(caja), sin repetir, lo de las celdas de la caja."""
    def __init__(self, c): self.c, self.d = c, {}
    def add(self, bb, v):
        c = self.c
        for gx in range(int(bb[0]//c), int(bb[2]//c)+1):
            for gy in range(int(bb[1]//c), int(bb[3]//c)+1): self.d.setdefault((gx, gy), []).append(v)
    def at(self, x, y, m=0):
        c = self.c; out = []
        for gx in range(int((x-m)//c), int((x+m)//c)+1):
            for gy in range(int((y-m)//c), int((y+m)//c)+1): out += self.d.get((gx, gy), ())
        return out
    def over(self, bb):
        c = self.c; out = set()
        for gx in range(int(bb[0]//c), int(bb[2]//c)+1):
            for gy in range(int(bb[1]//c), int(bb[3]//c)+1): out.update(self.d.get((gx, gy), ()))
        return out

def bbox(r): xs = [p[0] for p in r]; ys = [p[1] for p in r]; return (min(xs), min(ys), max(xs), max(ys))

def seg_dist(p, a, b):
    dx, dy = b[0]-a[0], b[1]-a[1]; L = dx*dx+dy*dy
    t = max(0, min(1, ((p[0]-a[0])*dx+(p[1]-a[1])*dy)/L)) if L else 0
    return math.hypot(p[0]-a[0]-t*dx, p[1]-a[1]-t*dy)

def context():
    """Lo que filtra las huellas de aprendizaje automático: las calzadas del mapa (data/geometry.json, el 80 % del
    medio ancho de su clase), el agua de los ríos y el límite de la comuna, y de raw/osm/map-comuna.json los landuse
    de LANDUSE y las vías (highway, también las huellas y senderos)."""
    g = json.load(open(DATA / 'geometry.json'))
    road = Cells(50)
    for s in g['streets']:
        pts = dec(s[2]); w = SW[s[0]]*0.4
        for a, b in zip(pts, pts[1:]): road.add((min(a[0], b[0])-w, min(a[1], b[1])-w, max(a[0], b[0])+w, max(a[1], b[1])+w), (a, b, w))
    water = [[dec(r) for r in p] for polys in g['area'].values() for p in polys]
    els, N = elements(), node_locs(); W = {e['id']: e for e in els if e['type'] == 'way'}
    lu, hw = Cells(200), Cells(100)
    for e in els:
        t = e.get('tags') or {}
        if e['type'] == 'way' and 'highway' in t:
            pts = [N[n] for n in e['nodes'] if n in N]
            for a, b in zip(pts, pts[1:]): hw.add((min(a[0], b[0]), min(a[1], b[1]), max(a[0], b[0]), max(a[1], b[1])), (a, b))
        if t.get('landuse') in LANDUSE:
            if e['type'] == 'way' and e['nodes'][0] == e['nodes'][-1]: rings = [[N[n] for n in e['nodes'] if n in N]]
            elif e['type'] == 'relation':
                rings = assemble([[N[n] for n in W[m['ref']]['nodes'] if n in N] for m in e['members'] if m['type'] == 'way' and m.get('role') == 'outer' and m['ref'] in W])
            else: continue
            for r in rings:
                if len(r) > 3: lu.add(bbox(r), (r, t['landuse']))
    return {'road': road, 'water': water, 'lu': lu, 'hw': hw, 'limit': dec(g['limit'])}

def landuse_at(ctx, p): return next((k for r, k in ctx['lu'].at(*p) if pip(p, r)), None)

def isolated(ctx, p):
    """Sin landuse de LANDUSE y a más de 100 m de toda vía de OSM."""
    return not landuse_at(ctx, p) and not any(seg_dist(p, a, b) < 100 for a, b in ctx['hw'].at(*p, 100))

def ml(cfg, bld, ctx):
    """Las huellas de aprendizaje automático (raw/edificios-ml/huellas.jsonl, de tools/ml_buildings.py) que pueden
    entrar, corridas a OSM: ([{'id', 'f': fuente, 'r': [anillo, hueco…], 'A': área, 'c': centro, 'h': alto de Google
    2.5D, 'g8', 'p23'}], lo quitado por motivo, el corrimiento de cada fuente). Se quitan las de Google con confianza
    bajo 0,8, las de menos de `mixto.m2`, las que tienen un 10 % o más sobre un edificio de OSM (OSM gana), las de
    centro en una calzada del mapa o en el agua, las que salen de la comuna, las de `excluir` (por su id GERS) y las
    que otra mayor cubre en más de la mitad (dups())."""
    from collections import Counter
    from common import in_ring
    path = ML / 'huellas.jsonl'
    if not path.exists(): return [], Counter(), {}
    sh = shifts(bld); excl = {e['id'] for e in cfg['excluir'] if 'id' in e}; mn = cfg['mixto']['m2']
    OR = [r[0] for _, r, _ in bld]; O = Cells(20)
    for k, r in enumerate(OR): O.add(bbox(r), k)
    gone, out = Counter(), []
    for l in open(path):
        d = json.loads(l); f = d['f']; dx, dy = sh[f][:2]
        if d['id'] in excl: gone['excluir'] += 1; continue
        if f == 'google' and (d['c'] or 0) < 0.8: gone['Google bajo 0,8'] += 1; continue
        rings = [ring_of([(x-dx, y-dy) for x, y in (loc(*q) for q in r)], ccw=(i == 0)) for i, r in enumerate(d['r'])]
        if not rings[0]: gone['chica'] += 1; continue
        R = rings[0]; rings = [R] + [h for h in rings[1:] if h and pip(h[0], R)]
        A = abs(area(R)) - sum(abs(area(h)) for h in rings[1:])
        if A < mn: gone[f'bajo {mn} m²'] += 1; continue
        c, bb = centre(R), bbox(R); cand = O.over(bb)
        if cand:                                            # OSM gana: la parte sobre sus edificios, en 5 × 5 puntos
            pts = [p for p in ((bb[0]+(bb[2]-bb[0])*(i+.5)/5, bb[1]+(bb[3]-bb[1])*(j+.5)/5) for i in range(5) for j in range(5)) if pip(p, R)]
            if pts and sum(any(pip(p, OR[k]) for k in cand) for p in pts) >= 0.1*len(pts): gone['sobre OSM'] += 1; continue
        if any(seg_dist(c, a, b) < w for a, b, w in ctx['road'].at(*c)): gone['en una calzada'] += 1; continue
        if any(in_ring(c, w[0]) and not any(in_ring(c, i) for i in w[1:]) for w in ctx['water']): gone['en el agua'] += 1; continue
        if not all(in_ring(p, ctx['limit']) for p in R): gone['fuera de la comuna'] += 1; continue
        out.append({'id': d['id'], 'f': f, 'r': rings, 'A': A, 'c': c, 'h': d.get('h'), 'g8': d.get('g8', 0), 'p23': d.get('p23')})
    n = len(out); out = dups(out); gone['duplicada'] += n - len(out)
    return out, gone, sh

def overlap(a, b, bb):
    """El área común de dos huellas (anillos con huecos) dentro de la caja bb, contando puntos de una grilla de a lo más
    40 × 40 (y no más fina que 0,25 m)."""
    w, h = bb[2]-bb[0], bb[3]-bb[1]; s = max(0.25, w/40, h/40); nx, ny = max(1, round(w/s)), max(1, round(h/s))
    def ins(p, R): return pip(p, R[0]) and not any(pip(p, q) for q in R[1:])
    n = sum(ins(p, a) and ins(p, b) for p in ((bb[0]+(i+.5)*w/nx, bb[1]+(j+.5)*h/ny) for i in range(nx) for j in range(ny)))
    return n * w*h / (nx*ny)

def dups(M):
    """Sin las huellas que otra mayor cubre en más de la mitad: Overture deja duplicadas (sobre todo de Microsoft con
    Microsoft) y huellas dentro de otras, que se dibujaban como un segundo volumen dentro del primero o un techo
    coplanar. De la mayor a la menor, una huella entra si ninguna de las que ya entraron cubre más de la mitad de ella;
    el orden de M no cambia."""
    I = Cells(20); keep = set()
    for k in sorted(range(len(M)), key=lambda k: (-M[k]['A'], k)):
        m = M[k]; bb = bbox(m['r'][0])
        for j in I.over(bb):
            o = M[j]; ob = bbox(o['r'][0])
            c = (max(bb[0], ob[0]), max(bb[1], ob[1]), min(bb[2], ob[2]), min(bb[3], ob[3]))
            if c[2] > c[0] and c[3] > c[1] and (c[2]-c[0])*(c[3]-c[1]) > 0.5*m['A'] and overlap(m['r'], o['r'], c) > 0.5*m['A']: break
        else: keep.add(k); I.add(bb, k)
    return [m for k, m in enumerate(M) if k in keep]

def raster_floors(h, A=0):
    """Los pisos de un edificio con el alto de Google 2.5D Temporal (m), o None donde el alto no los separa. Contra los
    1.023 edificios de OSM con pisos: bajo 11 m el raster no distingue uno de dos (un 3 % de los de uno o dos pisos
    pasa de 11 m, la mitad de los de tres a cinco no llega), así que ahí siguen estimados; de 11 a 14 m, tres; desde 14,
    un piso cada 3,2 m, hasta 15. Nada sobre los 2.500 m² (A): ahí son naves (el Gimnasio Regional leía 29 m, nueve pisos)."""
    if h is None or h < 11 or A > 2500: return None
    return 3 if h < 14 else min(15, round(h/3.2))

def analyse(with_ml=True):
    """Las manzanas con su cobertura y los edificios que caen en ellas: (cfg, manzanas, excluidos de OSM, info), con info
    = {'loose': las huellas fuera de las manzanas que entran, 'gone': lo quitado por motivo, 'sh': los corrimientos,
    'ctx': context()}. La cobertura y las manzanas enteras son solo de OSM; una manzana construida de un área sin
    `ml: false` con huellas de aprendizaje automático que entran es mixta (si no es entera)."""
    from collections import Counter
    cfg = json.load(open(CONFIG / 'edificios.json'))
    bld, srf = osm(); B = blocks()
    G = {}                                                   # índice de manzanas por celda de 100 m
    for b in B:
        for gx in range(int(b['bb'][0]//100), int(b['bb'][2]//100)+1):
            for gy in range(int(b['bb'][1]//100), int(b['bb'][3]//100)+1): G.setdefault((gx, gy), []).append(b)
    def block_of(p): return next((b for b in G.get((int(p[0]//100), int(p[1]//100)), []) if inside(b, p)), None)
    excl = {e['osm'] for e in cfg['excluir'] if 'osm' in e}
    for b in B: b['cov'] = b['covp'] = 0; b['eds'] = []; b['srf'] = []; b['ml'] = []
    for e in bld:
        b = block_of(centroid(e[1][0]))
        if not b: continue
        a = abs(area(e[1][0])) - sum(abs(area(h)) for h in e[1][1:]); b['cov'] += a; b['eds'].append(e)
        if 'building:levels' in e[2] or 'height' in e[2]: b['covp'] += a
    for s in srf:
        b = block_of(centroid(s[0]))
        if b: b['srf'].append(s)
    ctx = context() if with_ml else None
    M, gone, sh = ml(cfg, bld, ctx) if with_ml else ([], Counter(), {})
    loose = []
    for m in M:
        b = block_of(m['c'])
        if b: b['ml'].append(m)
        else: loose.append(m)
    in_area = lambda c: next((a for a in cfg['areas'] if a['caja'][0] <= c[0] <= a['caja'][2] and a['caja'][1] <= c[1] <= a['caja'][3]), None)
    def area_of(b): return in_area(point_in(b))
    mn = cfg['mixto']['m2']
    big = lambda b: any(abs(area(e[1][0])) >= mn for e in b['eds'])
    for b in B:
        b['cov'] /= b['A']; b['covp'] /= b['A']; a = area_of(b) if b['built'] and (b['eds'] or b['ml']) else None
        th, thp = (a.get('cobertura', cfg['cobertura']), a.get('cobertura_pisos', cfg['cobertura_pisos'])) if a else (0, 0)
        b['mlok'] = bool(a) and a.get('ml', True)
        b['sel'] = bool(a) and bool(b['eds']) and (b['cov'] >= th or (thp is not None and b['covp'] >= thp))
        b['mix'] = bool(a) and not b['sel'] and (big(b) or (b['mlok'] and bool(b['ml'])))
    for k, sel, mix in (('forzar', True, False), ('quitar', False, None), ('generar', False, False)):
        for p in cfg[k]:
            b = block_of(p); assert b, f'edificios.json: {k} {p} no cae en una manzana'
            b['sel'] = sel; b['mix'] = (b['built'] and (big(b) or (b['mlok'] and bool(b['ml'])))) if mix is None else mix
    for b in B:                                              # OSM gana: las huellas solo en las mixtas
        if b['ml'] and not (b['mix'] and b['mlok']):
            gone['en manzana entera de OSM' if b['sel'] else 'en manzana sin construir' if not b['built']
                 else 'en el área sin ml (el centro)' if not b['mlok'] and area_of(b) else 'en manzana generada (generar)'] += len(b['ml'])
            b['ml'] = []
    keep = []
    for m in loose:
        a = in_area(m['c'])
        if not a or not a.get('ml', True): gone['suelta, en el área sin ml'] += 1
        elif isolated(ctx, m['c']) and not (m['g8'] or (m['p23'] or 0) >= 0.65): gone['suelta rural aislada, sin segunda fuente'] += 1
        else: keep.append(m)
    return cfg, B, excl, {'loose': keep, 'gone': gone, 'sh': sh, 'ctx': ctx}

def techos():
    f = CONFIG / 'techos.json'
    return json.load(open(f))['techos'] if f.exists() else {}

LOOSE_C = 500                                                # las huellas sueltas van en grupos por celdas de 500 m

def ml_row(m, k, kind):
    """Una huella de aprendizaje automático -> (su manzana, sus datos en "c" de "h": alto, tipo, pisos, estimada, fuente,
    y su anillo, que h_encode() escribe en "g"). Tipo:
    departamentos con tres pisos o más (Google 2.5D) y 150 m²; casa bajo 600 m² (250 suelta o en un landuse de granja; ninguna en uno industrial: las
    de 250 a 600 m² suelen ser casas pareadas o en fila que la huella junta, y como «otro» eran cajas grises); galpón en un landuse industrial o de
    granja, suelta (fuera de las manzanas) o desde 1.500 m²; si no, otro. Un galpón toma el alto del raster (de 4 a 10 m)."""
    A = m['A']; fl = raster_floors(m['h'], A)
    t = 'departamentos' if fl and A >= 150 else 'casa' if A < (250 if kind in ('suelta', 'farmyard') else 600) and kind != 'industrial' else 'galpon' if kind in ('industrial', 'farmyard', 'suelta') or A >= 1500 else 'otro'
    if fl: h, lv, est = fl*3.0 + 0.5, fl, 2
    elif t == 'galpon': h, lv, est = max(4.0, min(10.0, m['h'] or 5.0)), 1, 1
    else: h, lv, est = 3.5, 1, 1
    return k, (int(round(h*10)), TIPOS.index(t), lv, est, FUENTES.index(m['f'])), m['r'][0]

def main(with_ml=True):
    from collections import Counter
    cfg, B, excl, info = analyse(with_ml); T = techos(); mn = cfg['mixto']['m2']; ctx = info['ctx']
    alt = json.load(open(ML / 'alturas-osm.json')) if with_ml and (ML / 'alturas-osm.json').exists() else {}
    sel, mix = [b for b in B if b['sel']], [b for b in B if b['mix']]
    groups = {}
    for m in info['loose']: groups.setdefault((int(m['c'][0]//LOOSE_C), int(m['c'][1]//LOOSE_C)), []).append(m)
    groups = [groups[g] for g in sorted(groups)]
    out = {'tipos': TIPOS, 'superficies': SUPERFICIES, 'techos': TECHOS, 'fuentes': FUENTES, 'm': [], 'x': [], 'z': [], 'e': [], 's': []}
    nt = ne = nm = nr = 0; nf = Counter(); H = []
    for k, b in enumerate(sel + mix):
        out['m' if b['sel'] else 'x'].append([round(c, 1) for c in point_in(b)])
        for oid, rings, t in b['eds']:
            if oid in excl or (b['mix'] and abs(area(rings[0])) < mn): continue
            h, lv, est = height(t)
            if est and t['building'] not in ('roof', 'carport', 'ruins') and 'leisure' not in t and 'sport' not in t and oid in alt:
                fl = raster_floors(alt[oid][0], abs(area(rings[0])))
                if fl: h, lv, est = fl*3.0 + 0.5, fl, 2; nr += 1
            fam = T.get(oid); nt += fam is not None; nm += b['mix']
            out['e'].append([oid, [enc(r) for r in rings], int(round(h*10)), TIPO.get(t['building'], 0), int(lv), TECHOS.index(fam) if fam in TECHOS else -1, int(est), k])
            ne += est == 1; nf['osm'] += 1
        for m in b['ml']: H.append(ml_row(m, k, landuse_at(ctx, m['c']))); nf[m['f']] += 1
        for r, s in b['srf']: out['s'].append([enc(r), s, k])
    for z, g in enumerate(groups):
        for m in g: H.append(ml_row(m, len(sel) + len(mix) + z, 'suelta')); nf[m['f'] + ' sueltas'] += 1
    # las huellas, en "h", en el orden de las manzanas (en cada una, después de las de OSM de "e")
    G, dec_rings, nrect = h_encode([r for _, _, r in H]); C = sorted({a for _, a, _ in H}); ci = {a: i for i, a in enumerate(C)}
    runs, idx = [], []
    for (k, a, _), r in zip(H, dec_rings):
        if r is None: nf['quitadas al redondear'] += 1; continue
        if runs and runs[-2] == k: runs[-1] += 1
        else: runs += [k, 1]
        idx.append(ci[a])
    out['h'] = {'q': HQ, 'K': HK, 'k': runs, 'c': [list(a) for a in C], 'i': idx, **G}
    for z in range(len(groups)):                            # la caja de cada grupo suelto, con las plantas redondeadas
        bb = [bbox(r) for (k, _, _), r in zip(H, dec_rings) if r and k == len(sel) + len(mix) + z] or [bbox(m['r'][0]) for m in groups[z]]
        out['z'].append([math.floor(min(v[0] for v in bb)*10)/10, math.floor(min(v[1] for v in bb)*10)/10, math.ceil(max(v[2] for v in bb)*10)/10, math.ceil(max(v[3] for v in bb)*10)/10])
    (DATA / 'edificios.json').write_text(json.dumps(out, separators=(',', ':')))
    kb = (DATA / 'edificios.json').stat().st_size / 1024
    print(f"data/edificios.json: {len(sel)} manzanas enteras, {len(mix)} mixtas y {len(groups)} grupos de huellas sueltas, "
          f"{len(out['e'])} edificios de OSM y {len(idx)} huellas ({nrect} rectilíneas; {nm} de OSM en las mixtas, {ne} de OSM sin altura, {nr} de OSM con pisos de Google 2.5D, "
          f"{nt} con color de techo; por fuente: {dict(nf)}), {len(out['s'])} superficies, {kb:.0f} KB")
    if with_ml:
        print('corrimiento contra OSM (m de grilla, lo que se resta; pares):', {k: (round(v[0], 2), round(v[1], 2), v[2]) for k, v in info['sh'].items()})
        print('huellas quitadas:', dict(info['gone'].most_common()))
        print('pisos de Google 2.5D (pisos: edificios):', dict(sorted(Counter([e[4] for e in out['e'] if e[6] == 2] + [a[2] for _, a, _ in H if a[3] == 2]).items())))

def cmd_manzanas(n='20'):
    cfg, B, _, _ = analyse(False); th = cfg['cobertura']
    near = sorted((b for b in B if b['built'] and len(b['eds'])), key=lambda b: abs(b['cov']-th))[:int(n)]
    for b in sorted(near, key=lambda b: -b['cov']):
        p = point_in(b)
        print(f"{'✓' if b['sel'] else '½' if b['mix'] else '·'} manzana {b['i']:5d}  cobertura {b['cov']:.2f} (con pisos {b['covp']:.2f})  "
              f"{len(b['eds']):3d} edificios  punto [{p[0]:.0f}, {p[1]:.0f}]")

def cmd_panel(*args):
    from PIL import Image, ImageDraw
    from satellite import mosaic
    a = [float(v) for v in args[:4]] if len(args) >= 4 else [-700, 800, -650, 650]
    z = int(args[4]) if len(args) > 4 else 18
    cfg, B, _, info = analyse(); x0, x1, y0, y1 = a
    img, P = mosaic(x0, x1, y0, y1, z); img = img.convert('RGBA')
    ov = Image.new('RGBA', img.size, (0, 0, 0, 0)); d = ImageDraw.Draw(ov)
    vis = lambda bb: bb[2] > x0 and bb[0] < x1 and bb[3] > y0 and bb[1] < y1
    for b in B:
        if not vis(b['bb']): continue
        for oid, rings, t in b['eds']:
            lv = num(t.get('building:levels')) or (num(t.get('height')) or 0)/2.8
            col = (255, 0, 255, 90) if not lv else (60, 200, 60, 90) if lv <= 1 else (240, 200, 0, 100) if lv <= 2 else (255, 120, 0, 110) if lv <= 5 else (220, 0, 0, 130)
            d.polygon([P(p) for p in rings[0]], fill=col, outline=(255, 255, 255, 200))
    for m in [m for b in B if vis(b['bb']) for m in b['ml']] + info['loose']:   # las de aprendizaje automático, sin relleno
        d.polygon([P(p) for p in m['r'][0]], outline=(0, 220, 255, 230) if m['f'] == 'ms' else (60, 120, 255, 230), width=2)
    for b in B:
        if not vis(b['bb']) or not b['built']: continue
        d.polygon([P(p) for p in b['r']], outline=(60, 255, 60, 255) if b['sel'] else (255, 200, 0, 255) if b['mix'] else (255, 60, 60, 255), width=3)
        q = P(point_in(b)); d.text((q[0]-12, q[1]-10), f"{b['cov']:.2f}\n{b['covp']:.2f}", fill=(255, 255, 255, 255))
    img = Image.alpha_composite(img, ov).convert('RGB')
    out = ROOT / 'diagnostics' / 'edificios.png'; out.parent.mkdir(exist_ok=True); img.save(out)
    print(out.relative_to(ROOT), img.size)

def roof_family(c):
    """Un color RGB (0–255) de la imagen -> la familia de techo de la plantilla, o None (árboles, sombra). La imagen de
    Esri es muy desaturada: en el centro, la teja y el óxido salen como cafés de saturación 0,1–0,2 (umbrales
    calibrados con el histograma de los techos del centro, octubre de 2026)."""
    r, g, b = (v/255 for v in c); mx, mn = max(r, g, b), min(r, g, b); l = (mx+mn)/2; s = (mx-mn)/(1-abs(2*l-1)) if mx > mn else 0
    h = 0 if mx == mn else (60*((g-b)/(mx-mn)) % 360 if mx == r else 60*((b-r)/(mx-mn))+120 if mx == g else 60*((r-g)/(mx-mn))+240)
    if l < .2: return None                                                # sombra de un edificio vecino
    if s > .14 and 70 < h < 170: return None                              # verde: copas de árboles sobre el techo
    if (h < 50 or h > 330) and s >= .08 and l < .66:                       # cafés y rojos: teja, pintura, óxido
        if s >= .25: return 'red' if l > .45 else 'tile'
        if s >= .15: return 'tile' if l >= .45 else 'tileOld'
        return 'tileOld' if l >= .42 else 'rust'
    if s > .2 and 180 < h < 260: return 'blue'
    return 'light' if l > .68 else 'zinc' if l > .5 else 'zincOld'

def cmd_techos(z='19'):
    from PIL import Image, ImageDraw
    from satellite import mosaic
    z = int(z); ed = json.load(open(require(DATA / 'edificios.json', 'Ejecute: make edificios')))
    eds = []
    for oid, rings, *_ in ed['e']:
        r = [(x/10, y/10) for x, y in dec(rings[0])]; eds.append((oid, r))
    res, C = {}, 400                                          # por cajas de C m, para no armar una imagen enorme
    xs = [p[0] for _, r in eds for p in r]; ys = [p[1] for _, r in eds for p in r]
    for cx in range(int(min(xs)//C), int(max(xs)//C)+1):
        for cy in range(int(min(ys)//C), int(max(ys)//C)+1):
            mine = [(oid, r) for oid, r in eds if cx*C <= centroid(r)[0] < (cx+1)*C and cy*C <= centroid(r)[1] < (cy+1)*C]
            if not mine: continue
            x0 = min(p[0] for _, r in mine for p in r)-5; x1 = max(p[0] for _, r in mine for p in r)+5
            y0 = min(p[1] for _, r in mine for p in r)-5; y1 = max(p[1] for _, r in mine for p in r)+5
            img, P = mosaic(x0, x1, y0, y1, z); px = img.load()
            for oid, r in mine:
                m = Image.new('L', img.size, 0); ImageDraw.Draw(m).polygon([P(p) for p in r], fill=255)
                from PIL import ImageFilter
                bx = m.getbbox()
                if not bx: continue
                m = m.crop(bx).filter(ImageFilter.MinFilter(5)); mp = m.load()      # sin el borde (~1 m): aleros, vecinos
                pix = [px[bx[0]+i, bx[1]+j] for i in range(m.size[0]) for j in range(m.size[1]) if mp[i, j]]
                if len(pix) < 6: continue
                pix.sort(key=sum); pix = pix[len(pix)*2//5:]                       # los más claros: fuera la sombra
                med = tuple(sorted(p[k] for p in pix)[len(pix)//2] for k in range(3))
                fam = roof_family(med)
                if fam: res[oid] = fam
    out = {'_comentario': f'La familia del techo (CP.roof de la plantilla: teja, óxido, zinc, claro…) de cada edificio de OSM de '
           f'data/edificios.json, clasificada por pipeline/edificios.py techos con la imagen satelital de Esri (zoom {z}): la '
           'mediana de los píxeles más claros dentro de la planta, sin su borde. Solo la familia: ni píxeles ni colores de la '
           'imagen (docs/FUENTES.md). La imagen puede tener años (trampa «La imagen satelital puede ser vieja»). Sin entrada: '
           'árboles o sombra sobre el techo, o una planta chica.', 'z': z, 'techos': dict(sorted(res.items()))}
    (CONFIG / 'techos.json').write_text(json.dumps(out, ensure_ascii=False, indent=0))
    from collections import Counter
    print(f'config/techos.json: {len(res)} de {len(eds)} edificios', dict(Counter(res.values()).most_common()))

if __name__ == '__main__':
    a = sys.argv[1:]
    if not a: main()
    elif a[0] == 'solo-osm': main(False)
    elif a[0] == 'manzanas': cmd_manzanas(*a[1:])
    elif a[0] == 'panel': cmd_panel(*a[1:])
    elif a[0] == 'techos': cmd_techos(*a[1:])
    else: sys.exit(__doc__)
