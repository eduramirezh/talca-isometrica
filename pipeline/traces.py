"""Revisión de trazados (ríos, vía férrea, Ruta 5) contra OpenStreetMap y el mapa, antes de reemplazarlos.

  python traces.py check piduco [--osm '{"via": [...], "agua": [...]}'] [--pads pads.txt]
      Para un río de config/trazados.json (o la clave `osm` que se prueba con --osm): las calles del mapa, la vía
      y la Ruta 5 que cruzan el eje, cada una con el puente de OSM más cercano; las vías de OSM que cruzan el eje
      (puentes o no); las manzanas que entran en el agua y cuánto; las calles cuyo pavimento corre dentro del agua
      más allá de un cruce; y, con --pads, las explanadas a menos de 120 m del agua. Regla (METODOLOGIA §5): toda
      calle que cruza el eje debe ser un puente en OSM, y si OSM y el mapa difieren en más de ~15 m se mira la
      imagen (panel) antes de reemplazar. Las explanadas salen de la página:
        python tools/screenshot.py diagnostics/x.png --js "console.log('PADS '+JSON.stringify(__pads))" > pads.txt
  uv run --with pillow python traces.py panel piduco x0 x1 y0 y1 [zoom]
      Panel sobre la imagen de Esri (caja en metros de grilla, zoom 17–18): eje y agua de OSM (rojo, azul),
      puentes de OSM (amarillo), calles con su ancho de render (gris), manzanas con su índice (rosado: con datos;
      celeste: sin información), vía (negro) y Ruta 5 (naranja) con su ancho, y los `puntos` a mano del río si
      todavía los tiene (magenta, a trazos, con su ancho). -> diagnostics/traza-<río>-<x0>_<y0>.png
  python traces.py tiles x0 x1 y0 y1 <nombre>
      Baja la API `map` de OSM en cajas de 0,01° (las que pasan los 50 mil nodos se dividen en cuatro), las guarda
      en raw/osm/tiles/ y las junta en raw/osm/map-<nombre>.json. Sirve cuando Overpass no responde.
  python traces.py line <nombre> clave=regex [...] [--mid] [--eps 2]
      Encadena las vías de raw/osm/map-<nombre>.json cuyas etiquetas calzan con todas las condiciones y escribe a
      stdout los `puntos` [lat, lon] de norte a sur de la cadena más larga, recortada a la maqueta con 300 m de
      margen y simplificada a --eps m; --mid: el eje medio de las dos cadenas más largas (las dos calzadas de una
      autopista). Así salieron la Ruta 5 (highway=^motorway$ "name=^Ruta 5 Sur$" --mid) y el tramo norte de la
      vía (railway=^rail$ usage=^main$).

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
    T = RAW / 'osm' / 'tiles'; T.mkdir(parents=True, exist_ok=True)
    els = {}
    def fetch(a, b, c, d):
        f = T / f'{a:.4f}_{b:.4f}_{c:.4f}_{d:.4f}.json'
        if not f.exists():
            try: data = get(f'https://api.openstreetmap.org/api/0.6/map.json?bbox={a:.5f},{b:.5f},{c:.5f},{d:.5f}')
            except urllib.error.HTTPError as e:
                if e.code != 400: raise
                mx, my = (a+c)/2, (b+d)/2
                for q in [(a, b, mx, my), (mx, b, c, my), (a, my, mx, d), (mx, my, c, d)]: fetch(*q)
                return
            f.write_bytes(data)
        for e in json.load(open(f))['elements']: els[(e['type'], e['id'])] = e
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
    _, kw = opts(args, {'--osm': 1, '--pads': 1})
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
    el = tiles(min(xs)-150, max(xs)+150, min(ys)-150, max(ys)+150, f'rio-{name}')
    N = {e['id']: e for e in el if e['type'] == 'node'}
    osmx = []
    for e in el:
        t = e.get('tags') or {}
        if e['type'] != 'way' or not ('highway' in t or 'railway' in t): continue
        pts = [loc(N[n]['lon'], N[n]['lat']) for n in e['nodes'] if n in N]
        for l in lines:
            for p in crossings(pts, l):
                osmx.append((e['id'], t.get('highway') or 'vía:' + t.get('railway', ''), t.get('name', ''),
                             'puente' if t.get('bridge') and t['bridge'] != 'no' else 'túnel' if t.get('tunnel') else 'SIN PUENTE', p))
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
    for k, nm in (('rail', 'vía férrea'), ('ruta5', 'Ruta 5')):
        for l in lines:
            for p in crossings(dec(g[k]), l): print(f'  {nm:<44} ({p[0]:.0f}, {p[1]:.0f})  {near(p)}')
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
    for k, col, wd in (('rail', (20, 20, 20), RAILW), ('ruta5', (255, 140, 0), R5W)):
        pts = [P(q) for q in dec(g[k])]
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
    inm = lambda p: pg.XMIN-300 < p[0] < pg.XMAX+300 and pg.YMIN-300 < p[1] < pg.YMAX+300
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

if __name__ == '__main__':
    cmds = {'check': cmd_check, 'panel': cmd_panel, 'tiles': cmd_tiles, 'line': cmd_line}
    if len(sys.argv) < 3 or sys.argv[1] not in cmds: raise SystemExit(__doc__)
    cmds[sys.argv[1]](*sys.argv[2:])
