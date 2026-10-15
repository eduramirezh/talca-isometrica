"""Revisión de trazados (ríos, vía férrea, Ruta 5) contra OpenStreetMap y el mapa, antes de reemplazarlos.

  python traces.py check piduco [--osm '{"via": [...], "agua": [...]}'] [--pads pads.txt] [--map comuna]
      Para un río de config/trazados.json (o la clave `osm` que se prueba con --osm): las calles del mapa, la vía
      y la Ruta 5 que cruzan el eje, cada una con el puente de OSM más cercano; las vías de OSM que cruzan el eje
      (puentes o no); las manzanas que entran en el agua y cuánto; las calles cuyo pavimento corre dentro del agua
      más allá de un cruce; y, con --pads, las explanadas a menos de 120 m del agua. Regla (METODOLOGIA §5): toda
      calle que cruza el eje debe ser un puente en OSM (en un canal o un estero chico, una alcantarilla: el cauce
      con tunnel=culvert, que también se cuenta), y si OSM y el mapa difieren en más de ~15 m se mira la imagen
      (panel) antes de reemplazar. Las vías de OSM salen de cajas de la API `map` sobre el eje; con --map <nombre>,
      de raw/osm/map-<nombre>.json (un canal de 24 km serían cientos de cajas). Las explanadas salen de la página:
        python tools/screenshot.py diagnostics/x.png --js "console.log('PADS '+JSON.stringify(__pads))" > pads.txt
  uv run --with pillow python traces.py panel piduco x0 x1 y0 y1 [zoom]
      Panel sobre la imagen de Esri (caja en metros de grilla, zoom 17–18): eje y agua de OSM (rojo, azul),
      puentes de OSM (amarillo), calles con su ancho de render (gris), manzanas con su índice (rosado: con datos;
      celeste: sin información), vía (negro) y Ruta 5 (naranja) con su ancho, y los `puntos` a mano del río si
      todavía los tiene (magenta, a trazos, con su ancho). -> diagnostics/traza-<río>-<x0>_<y0>.png
  python traces.py tiles x0 x1 y0 y1 <nombre>
      Baja la API `map` de OSM en cajas de 0,01° (las que pasan los 50 mil nodos se dividen en cuatro), las guarda
      en raw/osm/tiles/ y las junta en raw/osm/map-<nombre>.json. Sirve cuando Overpass no responde.
  python traces.py tiles-comuna [nombre] [base ...]
      Lo mismo sobre toda la comuna (cajas de 0,01° alineadas a los grados, solo las que tocan el límite con 300 m de
      margen y no caen dentro de la caja de map-todo), juntas con raw/osm/map-<base>.json (por omisión todo y este)
      en raw/osm/map-<nombre>.json (por omisión comuna). Es la fuente de las calles rurales, la Ruta 5 y la vía.
  python traces.py line <nombre> clave=regex [...] [--mid] [--eps 2]
      Encadena las vías de raw/osm/map-<nombre>.json cuyas etiquetas calzan con todas las condiciones y escribe a
      stdout los `puntos` [lat, lon] de norte a sur de la cadena más larga, recortada a la comuna con 300 m de
      margen y simplificada a --eps m; --mid: el eje medio de las dos cadenas más largas (las dos calzadas de una
      autopista). Así salieron la Ruta 5 (highway=^motorway$ "name=^Ruta 5 Sur$" --mid) y el tramo norte de la
      vía (railway=^rail$ usage=^main$).

  python traces.py cruces [nombre]
      Los cruces de la Ruta 5 en la comuna, de norte a sur, desde raw/osm/map-<nombre>.json (por omisión `este`;
      `comuna` para toda la comuna):
      cada vía de OSM (calle, vía férrea, agua) que cruza una calzada de la autopista, agrupada por estructura y con
      su tipo (paso superior, paso inferior, pasarela, puente sobre agua o sobre la vía, alcantarilla, a nivel) y
      los ramales a menos de 350 m; luego los tramos de la autopista con sus pistas, `lit` y puentes.
  python traces.py calzadas [nombre]
      Las dos calzadas de la Ruta 5 (las dos cadenas más largas de vías highway=motorway, cada una en su sentido,
      simplificadas a 0,3 m, con pistas, `lit` y `bridge` por tramo) y sus ramales (motorway_link), en
      data/ruta5.json (décimos de metro, en delta), que build.py inyecta como DATA.r5 (R5 en src/js/66-ruta5.js).
  uv run --with pillow python traces.py vial x0 x1 y0 y1 [zoom] [nombre]
      Panel de la Ruta 5 sobre la imagen de Esri: calzadas de OSM (rojo; amarillo en puente), ramales (ámbar), vías
      de OSM en puente (celeste) o en túnel (magenta), el eje del mapa con 26 m (naranja) y las calles del mapa.
      -> diagnostics/vial-<x0>_<y0>.png

El río se arma con process_geometry.osm_river() (caché raw/osm/rio-<río>.json; con --osm, rio-<río>-prueba.json).
Las cajas de `check` se bajan solas alrededor del eje (raw/osm/map-rio-<río>.json).
"""
import json, math, re, sys, time, urllib.error, urllib.request
from common import ROOT, DATA, RAW, CONFIG, loc, unloc, require
import process_geometry as pg

SW = [16, 13, 11, 9.5, 7, 5, 3.5, 3.5]               # ancho de calle por clase, como en la plantilla
CLS = ['troncal', 'primaria', 'secundaria', 'terciaria', 'residencial', 'peatonal', 'peatonal', 'servicio']
R5W, RAILW = 26, 6                                  # anchos de la Ruta 5 y de la vía en la plantilla
UA = {'User-Agent': 'talca-isometrica/1.0 (maqueta isometrica de Talca)'}

def dec(a):
    pts, x, y = [], 0, 0
    for i in range(0, len(a), 2): x += a[i]; y += a[i+1]; pts.append((x, y))
    return pts

def segd(p, a, b):
    dx, dy = b[0]-a[0], b[1]-a[1]; L = dx*dx+dy*dy or 1e-9
    t = max(0, min(1, ((p[0]-a[0])*dx+(p[1]-a[1])*dy)/L)); return math.hypot(p[0]-a[0]-t*dx, p[1]-a[1]-t*dy)

def segp(p, a, b):
    dx, dy = b[0]-a[0], b[1]-a[1]; L = dx*dx+dy*dy or 1e-9
    t = max(0, min(1, ((p[0]-a[0])*dx+(p[1]-a[1])*dy)/L)); return (a[0]+t*dx, a[1]+t*dy)

def pld(p, pl): return min(segd(p, pl[i], pl[i+1]) for i in range(len(pl)-1))

def crossings(pl, ql):
    out = []
    for i in range(len(pl)-1):
        a, b = pl[i], pl[i+1]; r = (b[0]-a[0], b[1]-a[1])
        for j in range(len(ql)-1):
            c, d = ql[j], ql[j+1]; s = (d[0]-c[0], d[1]-c[1]); den = r[0]*s[1]-r[1]*s[0]
            if abs(den) < 1e-12: continue
            t = ((c[0]-a[0])*s[1]-(c[1]-a[1])*s[0])/den; u = ((c[0]-a[0])*r[1]-(c[1]-a[1])*r[0])/den
            if 0 <= t <= 1 and 0 <= u <= 1: out.append((a[0]+t*r[0], a[1]+t*r[1]))
    return out

# ---------------------------------------------------------------- tiles
def get(url):
    for k in range(4):
        try: return urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=120).read()
        except urllib.error.HTTPError as e:
            if e.code == 400: raise                    # demasiados nodos: quien llama divide la caja
            if k == 3: raise
            time.sleep(5*(k+1))

def tiles(x0, x1, y0, y1, name, step=0.01):
    """OSM `map` boxes over a grid-metre box, cached per box and merged into raw/osm/map-<name>.json."""
    cs = [unloc(x, y) for x in (x0, x1) for y in (y0, y1)]
    la0, la1 = min(c[0] for c in cs), max(c[0] for c in cs); lo0, lo1 = min(c[1] for c in cs), max(c[1] for c in cs)
    els = {}
    def fetch(a, b, c, d):
        for e in tiles_box(a, b, c, d): els[(e['type'], e['id'])] = e
    lo = lo0
    while lo < lo1:
        la = la0
        while la < la1: fetch(lo, la, min(lo+step, lo1), min(la+step, la1)); la += step
        lo += step
    out = RAW / 'osm' / f'map-{name}.json'; out.write_text(json.dumps({'elements': list(els.values())}))
    print(f'raw/osm/{out.name}: {len(els)} elementos', file=sys.stderr)
    return list(els.values())

def cmd_tiles(x0, x1, y0, y1, name):
    tiles(*map(float, (x0, x1, y0, y1)), name)

def cmd_tiles_comuna(name='comuna', *bases):
    """The OSM `map` boxes over the whole commune: a 0,01° grid aligned to whole degrees, skipping the boxes that do
    not reach the commune (300 m margin) and, when raw/osm/map-todo.json exists, those inside its box (the old model,
    -4000 5600 -4200 4700); merged with raw/osm/map-<base>.json for each base there is (by default todo and este)."""
    from common import comuna, in_ring
    R = comuna(); xs, ys = [p[0] for p in R], [p[1] for p in R]
    cs = [unloc(x, y) for x in (min(xs)-300, max(xs)+300) for y in (min(ys)-300, max(ys)+300)]
    la0, la1 = min(c[0] for c in cs), max(c[0] for c in cs); lo0, lo1 = min(c[1] for c in cs), max(c[1] for c in cs)
    have = [b for b in bases or ('todo', 'este') if (RAW / 'osm' / f'map-{b}.json').exists()]
    old = lambda p: 'todo' in have and -4000 <= p[0] <= 5600 and -4200 <= p[1] <= 4700
    def near(p, m=300):
        if in_ring(p, R): return True
        return min(segd(p, R[i-1], R[i]) for i in range(len(R))) < m
    els, n, k0 = {}, 0, math.floor(lo0*100)
    for b in have:
        for e in json.load(open(RAW / 'osm' / f'map-{b}.json'))['elements']: els[(e['type'], e['id'])] = e
    for i in range(k0, math.ceil(lo1*100)):
        for j in range(math.floor(la0*100), math.ceil(la1*100)):
            a, b, c, d = i/100, j/100, (i+1)/100, (j+1)/100
            corners = [loc(x, y) for x in (a, c) for y in (b, d)]
            if all(old(q) for q in corners): continue
            pts = corners + [loc((a+c)/2, (b+d)/2)] + [loc(a+(c-a)*u/4, b+(d-b)*v/4) for u in range(5) for v in range(5)]
            if not any(near(q) for q in pts) and not any(a <= unloc(*q)[1] <= c and b <= unloc(*q)[0] <= d for q in R): continue
            n += 1
            for e in tiles_box(a, b, c, d): els[(e['type'], e['id'])] = e
    out = RAW / 'osm' / f'map-{name}.json'; out.write_text(json.dumps({'elements': list(els.values())}))
    print(f'{n} cajas; raw/osm/{out.name}: {len(els)} elementos', file=sys.stderr)

def tiles_box(a, b, c, d):
    """One OSM `map` box (lon a..c, lat b..d), cached in raw/osm/tiles/ and split in four when it has too many nodes."""
    T = RAW / 'osm' / 'tiles'; T.mkdir(parents=True, exist_ok=True)
    f = T / f'{a:.4f}_{b:.4f}_{c:.4f}_{d:.4f}.json'
    if not f.exists():
        try: data = get(f'https://api.openstreetmap.org/api/0.6/map.json?bbox={a:.5f},{b:.5f},{c:.5f},{d:.5f}')
        except urllib.error.HTTPError as e:
            if e.code != 400: raise
            mx, my = (a+c)/2, (b+d)/2
            return [e for q in [(a, b, mx, my), (mx, b, c, my), (a, my, mx, d), (mx, my, c, d)] for e in tiles_box(*q)]
        f.write_bytes(data)
    return json.load(open(f))['elements']

# ---------------------------------------------------------------- river
def river(name, osm=None):
    tz = json.load(open(CONFIG / 'trazados.json')); r = dict(tz['rios'].get(name, {}))
    if osm: r['osm'] = json.loads(osm); r.setdefault('ancho_m', 12); r.setdefault('ribera_m', 5)
    if 'osm' not in r: raise SystemExit(f'El río {name!r} no tiene clave `osm` en config/trazados.json: use --osm')
    cl, polys, br = pg.osm_river(f'{name}-prueba' if osm else name, r)
    return r, cl, polys, br

def opts(args, flags):
    pos, kw = [], {}
    it = iter(args)
    for a in it:
        if a in flags: kw[a] = next(it) if flags[a] else True
        else: pos.append(a)
    return pos, kw

def cmd_check(name, *args):
    _, kw = opts(args, {'--osm': 1, '--pads': 1, '--map': 1})
    r, cl, polys, br = river(name, kw.get('--osm')); w = r['ancho_m']
    g = json.load(open(require(DATA / 'geometry.json', 'Ejecute: make data')))
    lines = [cl] + br
    inA = lambda q: any(pg.pip_xy(q, p[0]) and not any(pg.pip_xy(q, h) for h in p[1:]) for p in polys)
    edges = [(rg[i-1], rg[i]) for p in polys for rg in p for i in range(len(rg))]
    inbox = lambda p: pg.XMIN <= p[0] <= pg.XMAX and pg.YMIN <= p[1] <= pg.YMAX
    cin = [p for p in cl if inbox(p)]
    print(f'eje en la maqueta: {len(cin)} puntos, de ({cin[0][0]:.0f}, {cin[0][1]:.0f}) a ({cin[-1][0]:.0f}, {cin[-1][1]:.0f}); '
          f'{sum(map(inA, cin))} dentro del agua de OSM')
    for k, p in enumerate(polys):
        xs = [q[0] for q in p[0]]; ys = [q[1] for q in p[0]]
        print(f'agua {k}: {len(p)-1} islas, x {min(xs):.0f}..{max(xs):.0f}, y {min(ys):.0f}..{max(ys):.0f}')
    if 'puntos' in r:
        hand = [loc(lo, la) for la, lo in r['puntos']]
        print('trazado a mano -> eje de OSM (m):', ', '.join(f'{pld(h, cl):.0f}' for h in hand if inbox(h)))
    # OSM ways that cross the axis
    xs = [p[0] for l in lines for p in l if inbox(p)]; ys = [p[1] for l in lines for p in l if inbox(p)]
    el = (json.load(open(require(RAW / 'osm' / f"map-{kw['--map']}.json", 'Ejecute: make osm')))['elements'] if '--map' in kw
          else tiles(min(xs)-150, max(xs)+150, min(ys)-150, max(ys)+150, f'rio-{name}'))
    N = {e['id']: e for e in el if e['type'] == 'node'}
    pt = lambda e: [loc(N[n]['lon'], N[n]['lat']) for n in e['nodes'] if n in N]
    # culverts: the stream or canal itself under the road (tunnel=culvert on a waterway)
    culv = [pt(e) for e in el if e['type'] == 'way' and 'waterway' in (e.get('tags') or {}) and e['tags'].get('tunnel') == 'culvert']
    osmx = []
    for e in el:
        t = e.get('tags') or {}
        if e['type'] != 'way' or not ('highway' in t or 'railway' in t): continue
        pts = pt(e)
        for l in lines:
            for p in crossings(pts, l):
                kind = ('puente' if t.get('bridge') and t['bridge'] != 'no' else 'túnel' if t.get('tunnel') else
                        'alcantarilla' if any(crossings(pts, c) for c in culv) else 'SIN PUENTE')
                osmx.append((e['id'], t.get('highway') or 'vía:' + t.get('railway', ''), t.get('name', ''), kind, p))
    print(f'\nvías de OSM que cruzan el eje ({len(osmx)}; sin senderos ni servicio a nivel):')
    for b in sorted(osmx, key=lambda b: b[4][0]):
        if b[1] in ('footway', 'path', 'track', 'steps', 'cycleway', 'service') and b[3] == 'SIN PUENTE': continue
        print(f'  w{b[0]:<11} {b[1]:<14} {b[2][:30]:<30} {b[3]:<10} ({b[4][0]:.0f}, {b[4][1]:.0f})')
    def near(p):
        if not osmx: return 'sin vías de OSM'
        b = min(osmx, key=lambda b: math.dist(b[4], p))
        return f'w{b[0]} {b[2][:25]} ({b[3]}) a {math.dist(b[4], p):.0f} m'
    print('\ncalles del mapa, vía y Ruta 5 que cruzan el eje (y la vía de OSM más cercana al cruce):')
    for s in g['streets']:
        for l in lines:
            for p in crossings(dec(s[2]), l):
                print(f'  {g["names"][s[1]][:32]:<32} {CLS[s[0]]:<11} ({p[0]:.0f}, {p[1]:.0f})  {near(p)}')
    for k, nm in (('rail', 'vía férrea'), ('ramal', 'ramal a Constitución'), ('ruta5', 'Ruta 5')):
        for l in lines:
            for p in crossings(dec(g.get(k, [])), l): print(f'  {nm:<44} ({p[0]:.0f}, {p[1]:.0f})  {near(p)}')
    # blocks in the water: the area, or the ribbon of ancho_m on the axis where there is no area
    runs = [(l[i], l[i+1]) for l in lines for i in range(len(l)-1) if not (inA(l[i]) and inA(l[i+1]))]
    def depth(q):
        if inA(q): return min(segd(q, a, c) for a, c in edges)
        d = min((segd(q, a, c) for a, c in runs), default=1e9)
        return w/2 - d if d < w/2 else None
    print('\nmanzanas que entran en el agua (profundidad: el punto de la manzana más lejos de la orilla, dentro del agua):')
    S = 2.0
    for bi, b in enumerate(g['blocks']):
        rg = dec(b[3]); bx = [q[0] for q in rg]; by = [q[1] for q in rg]
        if min(pld(q, l) for q in rg for l in lines) > 400: continue
        n, dmax = 0, 0; x = min(bx)
        while x <= max(bx):
            y = min(by)
            while y <= max(by):
                if pg.pip_xy((x, y), rg):
                    d = depth((x, y))
                    if d is not None: n += 1; dmax = max(dmax, d)
                y += S
            x += S
        if n: print(f'  manzana {bi} ({"con datos" if b[0] == 0 else "sin información" if b[0] == 1 else "aldea"}, {b[1]} personas): '
                    f'{n*S*S:.0f} m² en el agua, {dmax:.0f} m adentro, centroide ({sum(bx)/len(bx):.0f}, {sum(by)/len(by):.0f})')
    # streets whose pavement runs in the water beyond a crossing
    print('\ncalles con pavimento dentro del agua (cada 2 m de eje; un cruce suma ~20–60 m):')
    acc = {}
    lx = [p[0] for l in lines for p in l]
    for s in g['streets']:
        pts = dec(s[2]); hw = SW[s[0]]/2
        if min(q[0] for q in pts) > max(lx)+100 or max(q[0] for q in pts) < min(lx)-100: continue
        for i in range(len(pts)-1):
            a, b = pts[i], pts[i+1]; L = math.dist(a, b)
            for k in range(int(L/2)+1):
                q = (a[0]+(b[0]-a[0])*k*2/max(L, 1e-9), a[1]+(b[1]-a[1])*k*2/max(L, 1e-9))
                if min(pld(q, l) for l in lines) > 400: continue
                if inA(q) or (edges and min(segd(q, e0, e1) for e0, e1 in edges) < hw) or min((segd(q, a2, c2) for a2, c2 in runs), default=1e9) < w/2 + hw:
                    acc.setdefault((g['names'][s[1]], s[0]), []).append(q)
    for (nm, c), qs in sorted(acc.items(), key=lambda kv: -len(kv[1])):
        print(f'  {nm[:35]:<35} {CLS[c]:<11} {len(qs)*2} m, en torno a ({sum(q[0] for q in qs)/len(qs):.0f}, {sum(q[1] for q in qs)/len(qs):.0f})')
    if '--pads' in kw:
        pads = json.loads(open(kw['--pads']).read().split('PADS ', 1)[1].splitlines()[0])
        pois = {p['id']: p for p in json.load(open(DATA / 'pois.json'))['pois']}
        print('\nexplanadas a menos de 120 m del agua:')
        for x0, y0, x1, y1, h in pads:
            pts = [(x0+(x1-x0)*a/8, y0+(y1-y0)*b/8) for a in range(9) for b in range(9)]
            d = min(min((min(segd(q, a, c) for a, c in edges) for q in pts), default=1e9),
                    min((segd(q, a, c) for q in pts for a, c in runs), default=1e9) - w/2)
            if d < 120:
                c = ((x0+x1)/2, (y0+y1)/2); p = min(pois.values(), key=lambda p: math.dist((p['x'], p['y']), c))
                print(f'  [{x0}, {y0}, {x1}, {y1}] a {d:.0f} m; lugar más cercano: {p["id"]}')

# ---------------------------------------------------------------- panel
def cmd_panel(name, *args):
    from PIL import Image, ImageDraw
    pos, kw = opts(args, {'--osm': 1})
    if len(pos) < 4: raise SystemExit(__doc__)
    x0, x1, y0, y1 = map(float, pos[:4]); z = int(pos[4]) if len(pos) > 4 else 18
    r, cl, polys, br = river(name, kw.get('--osm'))
    g = json.load(open(require(DATA / 'geometry.json', 'Ejecute: make data')))
    n = 2 ** z
    def px(x, y):
        la, lo = unloc(x, y); s = math.radians(la)
        return (lo+180)/360*n*256, (1-math.log(math.tan(s)+1/math.cos(s))/math.pi)/2*n*256
    cs = [px(x, y) for x in (x0, x1) for y in (y0, y1)]
    X0, X1 = min(c[0] for c in cs), max(c[0] for c in cs); Y0, Y1 = min(c[1] for c in cs), max(c[1] for c in cs)
    img = Image.new('RGB', (int(X1-X0), int(Y1-Y0)))
    URL = 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
    cache = RAW / 'satelite'; cache.mkdir(parents=True, exist_ok=True)
    for tx in range(int(X0//256), int(X1//256)+1):
        for ty in range(int(Y0//256), int(Y1//256)+1):
            f = cache / f'{z}_{tx}_{ty}.jpg'
            if not f.exists(): f.write_bytes(get(URL.format(z=z, x=tx, y=ty)))
            img.paste(Image.open(f), (int(tx*256-X0), int(ty*256-Y0)))
    img = img.convert('RGBA'); ov = Image.new('RGBA', img.size, (0, 0, 0, 0)); d = ImageDraw.Draw(ov)
    P = lambda q: tuple(a-b for a, b in zip(px(*q), (X0, Y0)))
    mpp = math.dist(px(0, 0), px(100, 0)) / 100
    inb = lambda pts, m=100: any(x0-m < q[0] < x1+m and y0-m < q[1] < y1+m for q in pts)
    for s in g['streets']:
        pts = dec(s[2])
        if inb(pts): d.line([P(q) for q in pts], fill=(200, 200, 200, 110), width=max(1, int(SW[s[0]]*mpp)))
    for p in polys:
        for k, rg in enumerate(p):
            d.polygon([P(q) for q in rg], fill=(40, 120, 255, 60) if k == 0 else (0, 0, 0, 0), outline=(60, 160, 255, 255))
    sys.path.insert(0, str(ROOT / 'pipeline')); from build import mark_built
    t0 = [b[0] for b in g['blocks']]; mark_built(g['blocks'])
    for i, b in enumerate(g['blocks']):
        rg = dec(b[3])
        if not inb(rg, 0): continue
        d.polygon([P(q) for q in rg], outline=(80, 255, 80, 255) if b[0] != t0[i] else (255, 60, 200, 255) if b[0] == 0 else (0, 230, 255, 255))
        c = (sum(q[0] for q in rg)/len(rg), sum(q[1] for q in rg)/len(rg))
        if pg.pip_xy(c, rg): q = P(c); d.text((q[0]-10, q[1]-5), str(i), fill=(255, 255, 0, 255))
    if 'puntos' in r:
        hand = [loc(lo, la) for la, lo in r['puntos']]; hw = r['ancho_m']/2
        for i in range(len(hand)-1):
            a, b = hand[i], hand[i+1]; L = math.dist(a, b) or 1; nx, ny = -(b[1]-a[1])/L*hw, (b[0]-a[0])/L*hw
            for sd in (1, -1):
                A, B = P((a[0]+nx*sd, a[1]+ny*sd)), P((b[0]+nx*sd, b[1]+ny*sd))
                for t in range(0, 20, 2):
                    d.line([(A[0]+(B[0]-A[0])*t/20, A[1]+(B[1]-A[1])*t/20), (A[0]+(B[0]-A[0])*(t+1)/20, A[1]+(B[1]-A[1])*(t+1)/20)], fill=(255, 0, 255, 255), width=2)
    for l in [cl] + br: d.line([P(q) for q in l], fill=(255, 40, 40, 255), width=3)
    for k, col, wd in (('rail', (20, 20, 20), RAILW), ('ramal', (90, 40, 20), 4), ('ruta5', (255, 140, 0), R5W)):
        pts = [P(q) for q in dec(g.get(k, []))]
        if len(pts) < 2: continue
        d.line(pts, fill=col+(90,), width=max(1, int(wd*mpp))); d.line(pts, fill=col+(255,), width=2)
    m = RAW / 'osm' / f'map-rio-{name}.json'
    if m.exists():
        el = json.load(open(m))['elements']; N = {e['id']: e for e in el if e['type'] == 'node'}
        for e in el:
            t = e.get('tags') or {}
            if e['type'] == 'way' and t.get('bridge') and t['bridge'] != 'no' and ('highway' in t or 'railway' in t):
                pts = [loc(N[k]['lon'], N[k]['lat']) for k in e['nodes'] if k in N]
                if len(pts) > 1 and inb(pts): d.line([P(q) for q in pts], fill=(255, 230, 0, 255), width=3)
    for gx in range(int(x0//250)*250, int(x1)+1, 250):
        for gy in range(int(y0//250)*250, int(y1)+1, 250):
            q = P((gx, gy)); d.text((q[0]+2, q[1]+2), f'{gx},{gy}', fill=(255, 255, 255, 230))
    img = Image.alpha_composite(img, ov); dl = ImageDraw.Draw(img)
    dl.rectangle([0, 0, 600, 34], fill=(0, 0, 0, 200))
    dl.text((6, 4), f'{name}: rojo eje de OSM, azul agua de OSM, amarillo puentes de OSM, magenta trazado a mano', fill='white')
    dl.text((6, 18), 'gris calles con su ancho, negro vía, naranja Ruta 5, rosado/celeste/verde manzanas', fill='white')
    out = ROOT / 'diagnostics' / f'traza-{name}-{x0:.0f}_{y0:.0f}.png'; out.parent.mkdir(exist_ok=True)
    img.convert('RGB').save(out); print(out.relative_to(ROOT), img.size)

# ---------------------------------------------------------------- line
def cmd_line(name, *args):
    _, kw = opts(args, {'--mid': 0, '--eps': 1})
    conds = [a.split('=', 1) for a in args if '=' in a and not a.startswith('--')]
    el = json.load(open(require(RAW / 'osm' / f'map-{name}.json', f'Ejecute: python traces.py tiles x0 x1 y0 y1 {name}')))['elements']
    N = {e['id']: e for e in el if e['type'] == 'node'}
    W = [e['nodes'] for e in el if e['type'] == 'way' and all(re.search(v, (e.get('tags') or {}).get(k, '')) for k, v in conds)
         and all(n in N for n in e['nodes'])]
    if not W: raise SystemExit('ninguna vía calza con ' + ' '.join(f'{k}={v}' for k, v in conds))
    P = lambda n: loc(N[n]['lon'], N[n]['lat'])
    # chain through nodes where exactly one way ends and one begins (keeps each carriageway of a motorway apart)
    st, en = {}, {}
    for k, w in enumerate(W): st.setdefault(w[0], []).append(k); en.setdefault(w[-1], []).append(k)
    used, chains = set(), []
    for k in range(len(W)):
        if k in used: continue
        h, seen = k, {k}
        while len(en.get(W[h][0], [])) == 1 and len(st.get(W[h][0], [])) == 1 and en[W[h][0]][0] not in seen:
            h = en[W[h][0]][0]; seen.add(h)
        ch = list(W[h]); used.add(h)
        while len(st.get(ch[-1], [])) == 1 and len(en.get(ch[-1], [])) == 1 and st[ch[-1]][0] not in used:
            nx = st[ch[-1]][0]; used.add(nx); ch += W[nx][1:]
        chains.append([P(n) for n in ch])
    length = lambda c: sum(math.dist(c[i], c[i+1]) for i in range(len(c)-1))
    chains.sort(key=length, reverse=True)
    print(f'{len(W)} vías -> {len(chains)} cadenas; las más largas: ' + ', '.join(f'{length(c):.0f} m' for c in chains[:4]), file=sys.stderr)
    from common import comuna, near_ring
    R = comuna(); inm = lambda p: near_ring(p, R, 300)   # the commune, with a 300 m margin
    A = chains[0]
    if '--mid' in kw:
        B = chains[1]; mid, seps = [], []
        out, acc = [A[0]], 0                           # A resampled every 15 m
        for i in range(len(A)-1):
            a, b = A[i], A[i+1]; L = math.dist(a, b); t = 15 - acc
            while t <= L: out.append((a[0]+(b[0]-a[0])*t/L, a[1]+(b[1]-a[1])*t/L)); t += 15
            acc = L - (t - 15)
        for p in out + [A[-1]]:
            if not inm(p): continue
            q = min((segp(p, B[i], B[i+1]) for i in range(len(B)-1)), key=lambda q: math.dist(p, q))
            seps.append(math.dist(p, q)); mid.append(((p[0]+q[0])/2, (p[1]+q[1])/2))
        print(f'separación entre cadenas: {min(seps):.0f}–{max(seps):.0f} m (mediana {sorted(seps)[len(seps)//2]:.0f})', file=sys.stderr)
        A = mid
    else: A = [p for p in A if inm(p)]
    A = pg.rdp(A, float(kw.get('--eps', 2)))
    if A[0][1] < A[-1][1]: A = A[::-1]
    print(json.dumps([[round(c, 5) for c in unloc(*p)] for p in A]))

# ---------------------------------------------------------------- cruces / vial (the Ruta 5)
def motorway(name='este'):
    """The motorway ways of raw/osm/map-<name>.json (both carriageways), every other way, and a node lookup."""
    el = json.load(open(require(RAW / 'osm' / f'map-{name}.json', 'Ejecute: python traces.py tiles 1300 5200 -4400 4900 este')))['elements']
    N = {e['id']: e for e in el if e['type'] == 'node'}
    P = lambda e: [loc(N[n]['lon'], N[n]['lat']) for n in e['nodes'] if n in N]
    ways = [(e, e.get('tags') or {}, P(e)) for e in el if e['type'] == 'way']
    ways = [w for w in ways if len(w[2]) > 1]
    return [w for w in ways if w[1].get('highway') == 'motorway'], [w for w in ways if w[1].get('highway') != 'motorway']

def crossing_kind(t, mt):
    """What a way with tags t does where it crosses a motorway way with tags mt."""
    up = t.get('bridge', 'no') != 'no' and t.get('layer', '1') not in ('0', '-1', '-2')
    under = t.get('tunnel', 'no') != 'no' or t.get('layer', '0').startswith('-') or mt.get('bridge', 'no') != 'no'
    if 'waterway' in t: return 'alcantarilla' if t.get('tunnel') == 'culvert' else 'puente (agua)' if mt.get('bridge') else 'agua bajo la autopista'
    if 'railway' in t: return 'puente sobre la vía' if under else 'vía sobre la autopista' if up else 'vía a nivel'
    if t.get('highway') in ('footway', 'path', 'cycleway', 'steps', 'pedestrian'):
        return 'pasarela' if up else 'paso peatonal inferior' if under else None
    if t.get('highway') == 'motorway_link': return None                   # a ramp leaving or joining: not a crossing
    return 'paso superior' if up else 'paso inferior' if under else 'a nivel'

def cmd_cruces(*args):
    """Every way of OSM that crosses the Ruta 5 inside the model, grouped by structure, with its type."""
    name = args[0] if args else 'este'
    mw, other = motorway(name)
    from common import comuna, in_ring
    R = comuna(); inside = lambda p: in_ring(p, R)    # the model is the commune
    links = [(t, pts) for e, t, pts in other if t.get('highway') in ('motorway_link', 'trunk_link')]
    found = []
    for e, t, pts in other:
        if not ('highway' in t or 'railway' in t or 'waterway' in t): continue
        for m, mt, mp in mw:
            for p in crossings(pts, mp):
                if not inside(p): continue
                if any(math.dist(p, q) < 0.5 for q in pts) and any(math.dist(p, q) < 0.5 for q in mp): continue   # a shared node: a junction
                k = crossing_kind(t, mt)
                if k is None or (k == 'a nivel' and t.get('highway') in ('service', 'track', 'unclassified') and not t.get('name')): continue
                found.append(dict(p=p, kind=k, way=e['id'], mway=m['id'], name=t.get('name', ''), hw=t.get('highway') or t.get('railway') or t.get('waterway') or '?',
                                  layer=t.get('layer', ''), mbridge=mt.get('bridge', '')))
    groups = []                                        # both carriageways of one structure (or two parallel decks) together
    for f in sorted(found, key=lambda f: -f['p'][1]):
        g = next((g for g in groups if g['kind'] == f['kind'] and g['name'] == f['name'] and min(math.dist(f['p'], q['p']) for q in g['xs']) < 45), None)
        if g: g['xs'].append(f)
        else: groups.append(dict(kind=f['kind'], name=f['name'], xs=[f]))
    print(f'{len(groups)} cruces de la Ruta 5 en la maqueta (de norte a sur):')
    for g in groups:
        c = (sum(f['p'][0] for f in g['xs'])/len(g['xs']), sum(f['p'][1] for f in g['xs'])/len(g['xs']))
        ws = sorted({f['way'] for f in g['xs']}); ms = sorted({f['mway'] for f in g['xs'] if f['mbridge']})
        en = sorted({t.get('destination', '') for t, pts in links if pld(c, pts) < 350 and t.get('destination')})
        nl = sum(1 for t, pts in links if pld(c, pts) < 350)
        print(f'  ({c[0]:.0f}, {c[1]:.0f})  {g["kind"]:<22} {(g["name"] or g["xs"][0]["hw"])[:28]:<28} '
              f'vías {",".join(f"w{w}" for w in ws)}' + (f'; autopista en puente {",".join(f"w{w}" for w in ms)}' if ms else '')
              + (f'; {nl} ramales a <350 m' + (f' ({"; ".join(en)})' if en else '') if nl else ''))
    print('\ntramos de la autopista (de norte a sur): pistas, iluminación, puentes')
    for m, mt, mp in sorted(mw, key=lambda w: -max(p[1] for p in w[2])):
        if not any(inside(p) for p in mp): continue
        L = sum(math.dist(mp[i], mp[i+1]) for i in range(len(mp)-1))
        print(f'  w{m["id"]:<11} ({mp[0][0]:.0f}, {mp[0][1]:.0f})->({mp[-1][0]:.0f}, {mp[-1][1]:.0f}) {L:5.0f} m  pistas {mt.get("lanes", "?")}'
              f'  lit={mt.get("lit", "-")}  {mt.get("maxspeed", "")} km/h' + ('  PUENTE' if mt.get('bridge') else '') + (f'  ancho {mt["width"]}' if 'width' in mt else ''))

def cmd_calzadas(*args):
    """The Ruta 5's two carriageways and its motorway_link ramps -> data/ruta5.json (R5 in src/js/66-ruta5.js, via build.py)."""
    name = args[0] if args else 'este'
    mw, other = motorway(name)
    from common import comuna, near_ring
    R = comuna(); near = lambda p, m=150: near_ring(p, R, m)    # the model is the commune
    mw = [w for w in mw if any(near(p, 300) for p in w[2])]
    nid = lambda w: (w[0]['nodes'][0], w[0]['nodes'][-1])
    st, en = {}, {}
    for k, w in enumerate(mw): st.setdefault(nid(w)[0], []).append(k); en.setdefault(nid(w)[1], []).append(k)
    chains, used = [], set()
    for k in range(len(mw)):                          # chains of ways, each in its direction of travel
        if k in used: continue
        h = k
        while len(en.get(nid(mw[h])[0], [])) == 1 and en[nid(mw[h])[0]][0] not in used and en[nid(mw[h])[0]][0] != k: h = en[nid(mw[h])[0]][0]
        ch = [h]; used.add(h)
        while len(st.get(nid(mw[ch[-1]])[1], [])) == 1 and st[nid(mw[ch[-1]])[1]][0] not in used: ch.append(st[nid(mw[ch[-1]])[1]][0]); used.add(ch[-1])
        chains.append(ch)
    length = lambda ch: sum(math.dist(mw[k][2][i], mw[k][2][i+1]) for k in ch for i in range(len(mw[k][2])-1))
    chains.sort(key=length, reverse=True)
    print(f'{len(mw)} vías de autopista -> {len(chains)} cadenas: ' + ', '.join(f'{length(c):.0f} m' for c in chains[:4]), file=sys.stderr)
    enc = lambda pts: [v for i, p in enumerate(pts) for v in ((round(p[0]*10), round(p[1]*10)) if i == 0 else
                       (round(p[0]*10)-round(pts[i-1][0]*10), round(p[1]*10)-round(pts[i-1][1]*10)))]
    out = {'c': [], 'k': []}
    for ch in chains[:2]:
        pts, ln, lit, br, ids = [], '', '', '', []
        for k in ch:
            e, t, P = mw[k]; q = pg.rdp(P, 0.3)
            if not any(near(p) for p in q): continue
            q = q if not pts else q[1:]
            pts += q; n = len(q) - (1 if len(pts) == len(q) else 0)
            ln += t.get('lanes', '2')[0]*n; lit += ('1' if t.get('lit') == 'yes' else '0')*n; br += ('1' if t.get('bridge') else '0')*n; ids.append(e['id'])
        out['c'].append({'p': enc(pts), 'l': ln, 'lit': lit, 'br': br})
        print(f'calzada de ({pts[0][0]:.0f}, {pts[0][1]:.0f}) a ({pts[-1][0]:.0f}, {pts[-1][1]:.0f}): {len(pts)} puntos, vías '
              + ' '.join(f'w{i}' for i in ids), file=sys.stderr)
    for e, t, P in other:
        if t.get('highway') != 'motorway_link' or not any(near(p, 0) for p in P): continue
        out['k'].append([int(t.get('lanes', '1')[0])] + enc(pg.rdp(P, 0.3)))
    print(f'{len(out["k"])} ramales (motorway_link): ' + ' '.join(f'w{e["id"]}' for e, t, P in other
          if t.get('highway') == 'motorway_link' and any(near(p, 0) for p in P)), file=sys.stderr)
    # the median: distance between the two lines along the first one
    A, B = [dec(c['p']) for c in out['c']]
    sep = [min(segd(((p[0]/10), (p[1]/10)), (B[i][0]/10, B[i][1]/10), (B[i+1][0]/10, B[i+1][1]/10)) for i in range(len(B)-1)) for p in A[::3]]
    print(f'separación entre las líneas de las calzadas: {min(sep):.1f}–{max(sep):.1f} m (mediana {sorted(sep)[len(sep)//2]:.1f})', file=sys.stderr)
    (DATA / 'ruta5.json').write_text(json.dumps(out, separators=(',', ':')) + '\n')
    print(f'-> {DATA / "ruta5.json"} (build.py lo inyecta como DATA.r5; luego make build)', file=sys.stderr)

def cmd_vial(*args):
    """Panel of the Ruta 5 over the Esri image: OSM's carriageways, ramps, crossings, and the map's axis and streets."""
    from PIL import Image, ImageDraw
    if len(args) < 4: raise SystemExit(__doc__)
    x0, x1, y0, y1 = map(float, args[:4]); z = int(args[4]) if len(args) > 4 else 18; name = args[5] if len(args) > 5 else 'este'
    g = json.load(open(require(DATA / 'geometry.json', 'Ejecute: make data')))
    n = 2 ** z
    def px(x, y):
        la, lo = unloc(x, y); s = math.radians(la)
        return (lo+180)/360*n*256, (1-math.log(math.tan(s)+1/math.cos(s))/math.pi)/2*n*256
    cs = [px(x, y) for x in (x0, x1) for y in (y0, y1)]
    X0, X1 = min(c[0] for c in cs), max(c[0] for c in cs); Y0, Y1 = min(c[1] for c in cs), max(c[1] for c in cs)
    img = Image.new('RGB', (int(X1-X0), int(Y1-Y0)))
    URL = 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
    cache = RAW / 'satelite'; cache.mkdir(parents=True, exist_ok=True)
    for tx in range(int(X0//256), int(X1//256)+1):
        for ty in range(int(Y0//256), int(Y1//256)+1):
            f = cache / f'{z}_{tx}_{ty}.jpg'
            if not f.exists(): f.write_bytes(get(URL.format(z=z, x=tx, y=ty)))
            img.paste(Image.open(f), (int(tx*256-X0), int(ty*256-Y0)))
    img = img.convert('RGBA'); ov = Image.new('RGBA', img.size, (0, 0, 0, 0)); d = ImageDraw.Draw(ov)
    P = lambda q: tuple(a-b for a, b in zip(px(*q), (X0, Y0)))
    mpp = math.dist(px(0, 0), px(100, 0)) / 100
    inb = lambda pts, m=100: any(x0-m < q[0] < x1+m and y0-m < q[1] < y1+m for q in pts)
    for s in g['streets']:
        pts = dec(s[2])
        if inb(pts): d.line([P(q) for q in pts], fill=(200, 200, 200, 90), width=max(1, int(SW[s[0]]*mpp)))
    r5 = [P(q) for q in dec(g['ruta5'])]
    d.line(r5, fill=(255, 140, 0, 60), width=max(1, int(R5W*mpp))); d.line(r5, fill=(255, 140, 0, 255), width=1)
    mw, other = motorway(name)
    for e, t, pts in other:
        if not inb(pts): continue
        if t.get('highway') in ('motorway_link', 'trunk_link'): d.line([P(q) for q in pts], fill=(255, 200, 0, 230), width=2)
        elif t.get('bridge', 'no') != 'no' and ('highway' in t or 'railway' in t): d.line([P(q) for q in pts], fill=(0, 255, 255, 255), width=3)
        elif t.get('tunnel', 'no') != 'no' and 'highway' in t: d.line([P(q) for q in pts], fill=(255, 0, 255, 255), width=3)
    for e, t, pts in mw:
        if inb(pts): d.line([P(q) for q in pts], fill=(255, 255, 0, 255) if t.get('bridge') else (255, 60, 40, 255), width=2)
    for gx in range(int(x0//100)*100, int(x1)+1, 100):
        for gy in range(int(y0//100)*100, int(y1)+1, 100):
            q = P((gx, gy)); d.ellipse([q[0]-2, q[1]-2, q[0]+2, q[1]+2], fill=(255, 255, 255, 200)); d.text((q[0]+3, q[1]+2), f'{gx},{gy}', fill=(255, 255, 255, 220))
    img = Image.alpha_composite(img, ov); dl = ImageDraw.Draw(img)
    dl.rectangle([0, 0, 640, 34], fill=(0, 0, 0, 200))
    dl.text((6, 4), 'Ruta 5: rojo calzadas de OSM (amarillo: en puente), naranja eje del mapa con 26 m, ámbar ramales', fill='white')
    dl.text((6, 18), 'celeste vías de OSM en puente (pasos superiores, pasarelas), magenta en túnel; gris calles del mapa', fill='white')
    out = ROOT / 'diagnostics' / f'vial-{x0:.0f}_{y0:.0f}.png'; out.parent.mkdir(exist_ok=True)
    img.convert('RGB').save(out); print(out.relative_to(ROOT), img.size)

if __name__ == '__main__':
    cmds = {'check': cmd_check, 'panel': cmd_panel, 'tiles': cmd_tiles, 'tiles-comuna': cmd_tiles_comuna, 'line': cmd_line, 'cruces': cmd_cruces, 'calzadas': cmd_calzadas, 'vial': cmd_vial}
    if len(sys.argv) < 2 or sys.argv[1] not in cmds: raise SystemExit(__doc__)
    cmds[sys.argv[1]](*sys.argv[2:])
