"""Edificios de OpenStreetMap, donde OSM los tiene todos o algunos: data/edificios.json (METODOLOGIA §14).

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

  python pipeline/edificios.py                 # escribe data/edificios.json e imprime las manzanas elegidas (make edificios)
  python pipeline/edificios.py manzanas [n]    # las n manzanas más cercanas al umbral, con su cobertura y un punto
  uv run --with pillow python pipeline/edificios.py panel [x0 x1 y0 y1] [z]
      diagnostics/edificios.png: la imagen satelital con las manzanas (verde: entera, amarillo: mixta, rojo: sin
      OSM, con su cobertura) y
      los edificios de OSM coloreados por pisos (verde 1, amarillo 2, naranjo 3–5, rojo 6 o más, magenta sin dato);
      en cada manzana, su cobertura y la de los edificios con pisos
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

Formato de data/edificios.json (enteros en decímetros, anillos codificados en delta como geometry.json):
  {"m": [[x, y], …] un punto dentro de cada manzana entera (metros de grilla, con un decimal), "x": lo mismo, mixtas,
   "e": [[id, [anillo, hueco, …], alto, tipo, pisos, techo, estimada, manzana], …],
   "s": [[anillo, superficie, manzana], …], "tipos": [...], "superficies": [...], "techos": [...]}
techo es el índice en "techos" de la familia de config/techos.json, o -1 sin dato; manzana, su lugar en m y luego x.
"""
import json, math, sys
from common import ROOT, RAW, DATA, CONFIG, loc, require
from build import dec, pip, mark_built

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

def osm(name='comuna'):
    """Los edificios y las superficies de raw/osm/map-<name>.json: ([(id, [anillo, hueco…], tags)], [(anillo, tipo)])."""
    els = json.load(open(require(RAW / 'osm' / f'map-{name}.json', 'Ejecute: make osm')))['elements']
    nodes = {e['id']: loc(e['lon'], e['lat']) for e in els if e['type'] == 'node'}
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
    g = json.load(open(require(DATA / 'geometry.json', 'Ejecute: make data'))); mark_built(g['blocks'])
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

def analyse():
    """Las manzanas con su cobertura y los edificios que caen en ellas: (cfg, manzanas, edificios, superficies)."""
    cfg = json.load(open(CONFIG / 'edificios.json'))
    bld, srf = osm(); B = blocks()
    G = {}                                                   # índice de manzanas por celda de 100 m
    for b in B:
        for gx in range(int(b['bb'][0]//100), int(b['bb'][2]//100)+1):
            for gy in range(int(b['bb'][1]//100), int(b['bb'][3]//100)+1): G.setdefault((gx, gy), []).append(b)
    def block_of(p): return next((b for b in G.get((int(p[0]//100), int(p[1]//100)), []) if inside(b, p)), None)
    excl = {e['osm'] for e in cfg['excluir']}
    for b in B: b['cov'] = b['covp'] = 0; b['eds'] = []; b['srf'] = []
    for e in bld:
        b = block_of(centroid(e[1][0]))
        if not b: continue
        a = abs(area(e[1][0])) - sum(abs(area(h)) for h in e[1][1:]); b['cov'] += a; b['eds'].append(e)
        if 'building:levels' in e[2] or 'height' in e[2]: b['covp'] += a
    for s in srf:
        b = block_of(centroid(s[0]))
        if b: b['srf'].append(s)
    def area_of(b):
        c = point_in(b)
        return next((a for a in cfg['areas'] if a['caja'][0] <= c[0] <= a['caja'][2] and a['caja'][1] <= c[1] <= a['caja'][3]), None)
    mn = cfg['mixto']['m2']
    for b in B:
        b['cov'] /= b['A']; b['covp'] /= b['A']; a = area_of(b) if b['built'] and b['eds'] else None
        th, thp = (a.get('cobertura', cfg['cobertura']), a.get('cobertura_pisos', cfg['cobertura_pisos'])) if a else (0, 0)
        b['sel'] = bool(a) and (b['cov'] >= th or (thp is not None and b['covp'] >= thp))
        b['mix'] = bool(a) and not b['sel'] and any(abs(area(e[1][0])) >= mn for e in b['eds'])
    for k, sel, mix in (('forzar', True, False), ('quitar', False, None), ('generar', False, False)):
        for p in cfg[k]:
            b = block_of(p); assert b, f'edificios.json: {k} {p} no cae en una manzana'
            b['sel'] = sel; b['mix'] = (b['built'] and any(abs(area(e[1][0])) >= mn for e in b['eds'])) if mix is None else mix
    return cfg, B, excl

def techos():
    f = CONFIG / 'techos.json'
    return json.load(open(f))['techos'] if f.exists() else {}

def main():
    cfg, B, excl = analyse(); T = techos(); mn = cfg['mixto']['m2']
    sel, mix = [b for b in B if b['sel']], [b for b in B if b['mix']]
    out = {'tipos': TIPOS, 'superficies': SUPERFICIES, 'techos': TECHOS, 'm': [], 'x': [], 'e': [], 's': []}
    nt = ne = nm = 0
    for k, b in enumerate(sel + mix):
        out['m' if b['sel'] else 'x'].append([round(c, 1) for c in point_in(b)])
        for oid, rings, t in b['eds']:
            if oid in excl or (b['mix'] and abs(area(rings[0])) < mn): continue
            h, lv, est = height(t)
            fam = T.get(oid); nt += fam is not None; nm += b['mix']
            out['e'].append([oid, [enc(r) for r in rings], int(round(h*10)), TIPO.get(t['building'], 0), int(lv), TECHOS.index(fam) if fam in TECHOS else -1, int(est), k])
            ne += est
        for r, s in b['srf']: out['s'].append([enc(r), s, k])
    (DATA / 'edificios.json').write_text(json.dumps(out, separators=(',', ':')))
    kb = (DATA / 'edificios.json').stat().st_size / 1024
    print(f"data/edificios.json: {len(sel)} manzanas enteras y {len(mix)} mixtas, {len(out['e'])} edificios ({nm} en las mixtas, "
          f"{ne} sin altura, {nt} con color de techo), {len(out['s'])} superficies, {kb:.0f} KB")

def cmd_manzanas(n='20'):
    cfg, B, _ = analyse(); th = cfg['cobertura']
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
    cfg, B, _ = analyse(); x0, x1, y0, y1 = a
    img, P = mosaic(x0, x1, y0, y1, z); img = img.convert('RGBA')
    ov = Image.new('RGBA', img.size, (0, 0, 0, 0)); d = ImageDraw.Draw(ov)
    vis = lambda bb: bb[2] > x0 and bb[0] < x1 and bb[3] > y0 and bb[1] < y1
    for b in B:
        if not vis(b['bb']): continue
        for oid, rings, t in b['eds']:
            lv = num(t.get('building:levels')) or (num(t.get('height')) or 0)/2.8
            col = (255, 0, 255, 90) if not lv else (60, 200, 60, 90) if lv <= 1 else (240, 200, 0, 100) if lv <= 2 else (255, 120, 0, 110) if lv <= 5 else (220, 0, 0, 130)
            d.polygon([P(p) for p in rings[0]], fill=col, outline=(255, 255, 255, 200))
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
    elif a[0] == 'manzanas': cmd_manzanas(*a[1:])
    elif a[0] == 'panel': cmd_panel(*a[1:])
    elif a[0] == 'techos': cmd_techos(*a[1:])
    else: sys.exit(__doc__)
