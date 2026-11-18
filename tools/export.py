# /// script
# requires-python = ">=3.10"
# dependencies = ["playwright==1.63"]
# ///
"""Exporta la maqueta generada a glTF (Blender, Godot) y a STL (impresión 3D).

  uv run tools/export.py --glb shots/centro.glb                  # 1 km alrededor de la plaza
  uv run tools/export.py --glb shots/x.glb --centro 1722,-262 --lado 600
  uv run tools/export.py --glb shots/x.glb --caja=-500,-500,500,500 --sin arboles,autos
  uv run tools/export.py --stl shots/centro.stl                  # sólido de 200 mm de lado
  uv run tools/export.py --stl shots/comuna.stl --comuna --paso 25 --escala 100000
  uv run tools/export.py --glb shots/c.glb --stl shots/c.stl --vista shots/c.png
  uv run tools/export.py --teselas shots/teselas --comuna        # un glb por km² e indice.json (Godot)
  uv run tools/export.py --teselas juego/mapa --comuna --tam 500 --instancias arboles,alamos --faroles --letreros --lejos --medio --liviano   # make juego

Carga dist/ en Chromium (Map de tools/page.py, ~1 min; --gl gpu, la GPU del equipo) con window.__KEEP, para que las
mallas conserven sus arreglos después de subir a la GPU, espera la generación completa e inyecta tools/export.js, que
lee la escena. Sale con 1 si hubo errores de consola.

glTF (--glb): un nodo y un material por capa (terreno, borde, suelo, agua, usos, ciudad, edificios, hitos, cerro,
patios, veredas, via, ruta5, arboles, alamos, autos, autos-ruta5, trenes; otros, lo que no tiene nombre), con colores por vértice
(COLOR_0, lineales). Coordenadas de three.js en metros: X al oriente, Y arriba, -Z al norte, con el origen en la Plaza
de Armas y la grilla girada +5° (las calles numeradas van por los ejes); el relieve es el exagerado de la maqueta. Los
triángulos que cruzan el borde de la caja se cortan en él, así dos cajas vecinas calzan; los árboles y autos entran
enteros si su centro cae dentro. Las ventanas de los edificios no son geometría (las pinta el sombreador de la página,
winMat): el material «edificios» lleva extras.ventanas para ponerlas con un material propio. Al lado, <salida>.json:
la caja, el sistema de coordenadas, las capas que puede tener (LAYERS de tools/export.js: el tipo de cada una y si es
sólida; una malla de un grupo que no está ahí hace fallar la exportación), los lugares que caen en la caja y las luces
de noche de los hitos (GLOW de la página: [x, y, altura] de cada lámpara).

STL (--stl): un sólido cerrado (cada arista en dos caras) de la superficie más alta de lo dibujado, muestreada en una
grilla de --paso metros (techos, copas, puentes: lo de abajo de un puente queda relleno), con una base plana y,
con --comuna o una caja que cruza el límite, recortado al contorno de la comuna. En milímetros a escala 1:--escala
(por omisión, el lado mayor mide 200 mm); --vert exagera la altura además del relieve de la maqueta. Sin autos.

--teselas escribe un glb por tesela de --tam metros alineada con la plaza (t_<i>_<j>.glb: x de i·tam a (i+1)·tam, y
de j·tam a (j+1)·tam), solo las que tienen algo, e indice.json con su lista, los lugares, las luces de los hitos y el
límite de la comuna (un anillo de grilla). La comuna entera en un solo glb pesa ~400 MB sin árboles ni edificios: para
un motor de juegos van por teselas (make juego: juego/mapa/, 500 m). Con --instancias arboles,alamos esas capas no van
como triángulos sino como datos, en t_<i>_<j>.json (__exInst de tools/export.js: x, y, altura del pie, escala, giro y
tinte de cada árbol; el juego pone los suyos, juego/arboleda.gd); con --lejos, además lejos.glb: un nodo por tesela
con solo el relieve, el agua y el borde, para lo que está más allá de lo cargado; con --medio, m_<i>_<j>.glb: los
edificios de la tesela solos (edificios, hitos, ciudad), que el juego carga hasta 3 km (juego/mapa.gd, MEDIO). Con
--liviano (make juego) las normales y los colores van en un byte por componente y los índices en 16 bits donde caben
(__exLiviano de tools/export.js; las normales en BYTE piden KHR_mesh_quantization, que el juego declara en
juego/cuantizado.gd): de 36 a 20 bytes por vértice, ~800 MB a ~430 MB, y lo que Godot guarda es lo mismo salvo las
normales, hasta 0,6° (tools/godot/comparar.gd).

--vista dibuja el glb exportado, cargado de vuelta con el GLTFLoader de three.js, en un PNG (para revisarlo), y el STL\nen <vista>-stl.png.
"""
import argparse, asyncio, base64, json, math, struct, sys, time
from array import array
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from page import Map, ROOT, add_page_args, alias, launch
sys.path.insert(0, str(ROOT / 'pipeline'))
import common  # noqa: E402

ORIGEN = (common.LAT0, common.LON0)  # la Plaza de Armas (loc/unloc)
GIRO = round(math.degrees(common.TH), 6)  # el giro de la grilla
MAT = {  # rugosidad por capa (el resto, 1): la página es Lambert, sin brillos
    'agua': 0.35}


def unb64(s, t):
    a = array(t); a.frombytes(base64.b64decode(s)); return a


# ---------- glTF ----------
def write_glb(path, res, nodos=None):
    """res['layers'] en un glb: un nodo y una malla por capa. Con nodos ([(nombre, layers)], --lejos), un nodo por
    elemento con una malla de una primitiva por capa (los materiales, uno por capa, compartidos)"""
    bin_, views, accs, meshes, mats, nodes, mat_of, liviano = bytearray(), [], [], [], [], [], {}, []

    def view(data, target, stride=None):
        while len(bin_) % 4: bin_.append(0)
        views.append({'buffer': 0, 'byteOffset': len(bin_), 'byteLength': len(data), 'target': target})
        if stride: views[-1]['byteStride'] = stride
        bin_.extend(data); return len(views) - 1

    def acc(data, ctype, count, typ, target, mn=None, mx=None, stride=None):
        a = {'bufferView': view(data, target, stride), 'componentType': ctype, 'count': count, 'type': typ}
        if mn is not None: a['min'], a['max'] = mn, mx
        if ctype in (5120, 5121) and target == 34962: a['normalized'] = True
        accs.append(a); return len(accs) - 1

    def material(name, L):
        if name not in mat_of:
            mat = {'name': name, 'pbrMetallicRoughness': {'baseColorFactor': [1, 1, 1, 1], 'metallicFactor': 0, 'roughnessFactor': MAT.get(name, 1)}}
            if name == 'borde': mat['doubleSided'] = True
            if L['win']: mat['extras'] = {'ventanas': {'cada_m': [3.4, 3.0], 'desde_m': 1.0, 'nota': 'la página las pinta en toda cara vertical (winMat, src/js/40-three.js)'}}
            mats.append(mat); mat_of[name] = len(mats) - 1
        return mat_of[name]

    def primitive(name, L):
        P = array('f'); P.frombytes(L['P'])
        mn = [min(P[i::3]) for i in range(3)]; mx = [max(P[i::3]) for i in range(3)]
        if L.get('liviano'):  # __exLiviano: normales BYTE y colores UNSIGNED_BYTE de a 4 bytes, índices de 16 bits si caben
            liviano.append(name)
            attrs = {'POSITION': acc(P.tobytes(), 5126, L['nv'], 'VEC3', 34962, mn, mx),
                     'NORMAL': acc(L['N'], 5120, L['nv'], 'VEC3', 34962, stride=4),
                     'COLOR_0': acc(L['C'], 5121, L['nv'], 'VEC3', 34962, stride=4)}
            ind = acc(L['I'], 5123 if L['i16'] else 5125, L['ni'], 'SCALAR', 34963)
        else:
            attrs = {'POSITION': acc(P.tobytes(), 5126, L['nv'], 'VEC3', 34962, mn, mx),
                     'NORMAL': acc(L['N'], 5126, L['nv'], 'VEC3', 34962),
                     'COLOR_0': acc(L['C'], 5126, L['nv'], 'VEC3', 34962)}
            ind = acc(L['I'], 5125, L['ni'], 'SCALAR', 34963)
        return {'attributes': attrs, 'indices': ind, 'material': material(name, L)}

    for nombre, layers in (nodos if nodos is not None else [(None, res['layers'])]):
        if nombre is None:
            for name, L in layers.items():
                meshes.append({'name': name, 'primitives': [primitive(name, L)]})
                nodes.append({'name': name, 'mesh': len(meshes) - 1})
        elif layers:
            meshes.append({'name': nombre, 'primitives': [primitive(name, L) for name, L in layers.items()]})
            nodes.append({'name': nombre, 'mesh': len(meshes) - 1})
    root = {'name': 'talca', 'children': list(range(len(nodes))), 'extras': meta(res, None)}
    nodes.append(root)
    gl = {'asset': {'version': '2.0', 'generator': 'talca-isometrica tools/export.py'}, 'scene': 0,
          'scenes': [{'nodes': [len(nodes) - 1]}], 'nodes': nodes, 'meshes': meshes, 'materials': mats,
          'accessors': accs, 'bufferViews': views, 'buffers': [{'byteLength': len(bin_)}]}
    if liviano:  # las normales en BYTE: Godot 4.7 las lee si se declara la extensión (juego/cuantizado.gd)
        gl['extensionsUsed'] = gl['extensionsRequired'] = ['KHR_mesh_quantization']
    js = json.dumps(gl, ensure_ascii=False, separators=(',', ':')).encode()
    js += b' ' * (-len(js) % 4)
    while len(bin_) % 4: bin_.append(0)
    with open(path, 'wb') as f:
        f.write(struct.pack('<III', 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(bin_)))
        f.write(struct.pack('<II', len(js), 0x4E4F534A)); f.write(js)
        f.write(struct.pack('<II', len(bin_), 0x004E4942)); f.write(bin_)


def meta(res, stl):
    m = {'caja_m': res['box'],
         'coordenadas': 'metros de grilla: origen en la Plaza de Armas, grilla girada +5° (calles numeradas por los ejes); '
                        'glTF: X = x (oriente), Y = altura (relieve exagerado, 0 en la plaza), Z = -y (norte)',
         'origen_latlon': ORIGEN, 'giro_grilla_grados': GIRO,
         'atribucion': '© colaboradores de OpenStreetMap, Overture Maps Foundation, Microsoft, Google, INE, CONAF, CIREN, '
                       'MINVU, Copernicus DEM GLO-30 (ESA); las licencias de cada fuente, en LICENSE-DATA del repositorio '
                       'talca-isometrica (lo derivado de OSM, bajo ODbL 1.0)'}
    if stl: m['stl'] = stl
    return m


# ---------- STL ----------
def write_stl(path, hm, box, escala, base_mm, vert):
    nx, ny, c = hm['nx'], hm['ny'], hm['c']
    H, M = unb64(hm['H'], 'f'), unb64(hm['M'], 'B')
    W = nx + 1
    full = all(M)
    inside = lambda i, j: 0 <= i < nx and 0 <= j < ny and M[j * nx + i]
    used = [False] * (W * (ny + 1))
    for j in range(ny):
        for i in range(nx):
            if M[j * nx + i]:
                for k in (j * W + i, j * W + i + 1, (j + 1) * W + i, (j + 1) * W + i + 1): used[k] = True
    hmin = min(H[k] for k in range(len(H)) if used[k])
    k = 1000.0 / escala  # mm por metro
    top = lambda n: ((n % W) * c * k, (n // W) * c * k, (H[n] - hmin) * k * vert + base_mm)
    bot = lambda n: ((n % W) * c * k, (n // W) * c * k, 0.0)
    NB = W * (ny + 1)  # ids: top n, bottom NB + n, centro de la base 2 NB
    pos = lambda v: top(v) if v < NB else bot(v - NB) if v < 2 * NB else (nx * c * k / 2, ny * c * k / 2, 0.0)
    T = []
    for j in range(ny):
        for i in range(nx):
            if not M[j * nx + i]: continue
            a, b, cc, d = j * W + i, j * W + i + 1, (j + 1) * W + i + 1, (j + 1) * W + i  # en sentido antihorario
            T += [(a, b, cc), (a, cc, d)]
            if not full: T += [(NB + a, NB + cc, NB + b), (NB + a, NB + d, NB + cc)]
            # los muros: el borde de la celda con afuera, recorrido con la celda a la izquierda (p -> q)
            for p, q, di, dj in ((a, b, 0, -1), (b, cc, 1, 0), (cc, d, 0, 1), (d, a, -1, 0)):
                if not inside(i + di, j + dj): T += [(p, NB + q, q), (p, NB + p, NB + q)]
    if full:  # la base de una caja entera: un abanico desde su centro sobre los nodos del contorno
        ring = [n for n in range(nx)] + [i + j * W for j in range(ny) for i in (nx,)] + \
               [nx - i + ny * W for i in range(nx)] + [(ny - j) * W for j in range(ny)]
        C0 = 2 * NB
        for s in range(len(ring)):
            T.append((C0, NB + ring[(s + 1) % len(ring)], NB + ring[s]))
    out = bytearray(80 + 4 + 50 * len(T))
    out[:80] = b'talca-isometrica tools/export.py (mm)'.ljust(80)
    struct.pack_into('<I', out, 80, len(T))
    o, vol = 84, 0.0
    for t in T:
        A, B, C = pos(t[0]), pos(t[1]), pos(t[2])
        ux, uy, uz = B[0] - A[0], B[1] - A[1], B[2] - A[2]; vx, vy, vz = C[0] - A[0], C[1] - A[1], C[2] - A[2]
        n = (uy * vz - uz * vy, uz * vx - ux * vz, ux * vy - uy * vx); L = math.sqrt(n[0] ** 2 + n[1] ** 2 + n[2] ** 2) or 1
        vol += (A[0] * (B[1] * C[2] - B[2] * C[1]) - A[1] * (B[0] * C[2] - B[2] * C[0]) + A[2] * (B[0] * C[1] - B[1] * C[0])) / 6
        struct.pack_into('<12fH', out, o, n[0] / L, n[1] / L, n[2] / L, *A, *B, *C, 0); o += 50
    Path(path).write_bytes(out)
    # cada arista dirigida una vez y su inversa una vez: cerrado y orientado
    bad = None
    if len(T) < 4_000_000:
        E = {}
        for a, b, cc in T:
            for e in ((a, b), (b, cc), (cc, a)): E[e] = E.get(e, 0) + 1
        bad = sum(1 for (a, b), n in E.items() if n != 1 or E.get((b, a)) != 1)
    size = (nx * c * k, ny * c * k, (max(H[n] for n in range(len(H)) if used[n]) - hmin) * k * vert + base_mm)
    return {'triangulos': len(T), 'mm': [round(s, 1) for s in size], 'escala': f'1:{escala:g}', 'paso_m': c,
            'volumen_cm3': round(vol / 1000, 1), 'aristas_malas': bad, 'altura_min_m': round(hmin, 2)}


# ---------- revisión ----------
VIEW_HTML = '''<!doctype html><meta charset=utf-8><body style="margin:0;background:#E9E4D6"><canvas id=c></canvas>'''
VIEW_JS = '''async ([b64, stl]) => {
  const T = THREE, buf = Uint8Array.from(atob(b64), c => c.charCodeAt(0)).buffer;
  let g;
  if (stl) { const geo = new T.STLLoader().parse(buf), m = new T.Mesh(geo, new T.MeshStandardMaterial({color: 0xA89F90, roughness: 0.8}));
    m.rotation.x = -Math.PI / 2; g = {scene: new T.Group()}; g.scene.add(m); m.name = 'stl'; geo.setIndex([...Array(geo.attributes.position.count).keys()]); }
  else g = await new Promise((ok, ko) => new T.GLTFLoader().parse(buf, '', ok, ko));
  const r = new T.WebGLRenderer({canvas: document.getElementById('c'), antialias: true});
  r.setSize(innerWidth, innerHeight); r.outputEncoding = T.sRGBEncoding;
  const s = new T.Scene(); s.background = new T.Color(0xE9E4D6); s.add(g.scene);
  s.add(new T.HemisphereLight(0xF4F1E6, 0x8E8A70, 0.9)); const d = new T.DirectionalLight(0xFFF3DD, 1.4); d.position.set(0.36, 0.707, -0.61); s.add(d);
  const box = new T.Box3().setFromObject(g.scene), c = box.getCenter(new T.Vector3()), R = box.getSize(new T.Vector3()).length() / 2;
  const a = innerWidth / innerHeight, k = R * 0.75, cam = new T.OrthographicCamera(-k * a, k * a, k, -k, -1e5, 1e5);
  cam.position.set(c.x + R, c.y + R * 0.9, c.z + R); cam.lookAt(c); r.render(s, cam);
  const n = {}; g.scene.traverse(o => { if (o.isMesh) n[o.name] = o.geometry.index.count / 3; }); return n; }'''


async def vista(p, glb, png, stl=False, gl='swiftshader'):
    b = await launch(p, gl)
    pg = await b.new_page(viewport={'width': 1400, 'height': 900})
    await pg.set_content(VIEW_HTML)
    ex = ROOT / 'node_modules/three/examples/js/loaders/GLTFLoader.js'
    await pg.add_script_tag(path=str(ROOT / 'node_modules/three/build/three.min.js'))
    await pg.add_script_tag(path=str(ex))
    await pg.add_script_tag(path=str(ex.with_name('STLLoader.js')))
    n = await pg.evaluate(VIEW_JS, [base64.b64encode(Path(glb).read_bytes()).decode(), stl])
    await pg.wait_for_timeout(500); await pg.screenshot(path=png); await b.close()
    return n


async def geom(pg, box, skip, liviano=False):
    """las mallas de la caja (__exGeom), con sus arreglos traídos de la página; None si no hay nada"""
    res = await pg.evaluate('([b, s]) => __exGeom(b, {skip: s})', [box, skip])
    res['capas'] = await pg.evaluate('__exLayers')  # all of them: the contract, not only this box's
    if res['unknown']: raise SystemExit(f"export: capas sin entrada en LAYERS de tools/export.js: {', '.join(res['unknown'])}")
    if not res['tris']: return None
    return await traer(pg, res, liviano)


async def traer(pg, res, liviano=False):
    """los arreglos de window.__exBuf (lo que dejó __exGeom) en res['layers']; con liviano, antes en el formato de
    __exLiviano"""
    if liviano:
        for k, i16 in (await pg.evaluate('__exLiviano()')).items():
            res['layers'][k].update(liviano=True, i16=i16)
    for k, L in res['layers'].items():  # los arreglos, por trozos de 32 MB
        for key in 'PNCI':
            n, buf = await pg.evaluate('([k, a]) => __exLen(k, a)', [k, key]), bytearray()
            for o in range(0, n, 1 << 25):
                buf += base64.b64decode(await pg.evaluate('([k, a, o, n]) => __exChunk(k, a, o, n)', [k, key, o, 1 << 25]))
            L[key] = bytes(buf)
    return res


async def export_glb(pg, box, skip, path, lugares=True, liviano=False, medio=None):
    """las mallas de la caja en un glb (y, con lugares, su JSON al lado); None si no hay nada. Con medio, (ruta,
    capas): además, esas capas solas en otro glb (m_<i>_<j>.glb de --medio)"""
    res = await geom(pg, box, skip, liviano)
    if res is None: return None
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    write_glb(path, res)
    m = None
    if medio:
        sub = {k: L for k, L in res['layers'].items() if k in medio[1]}
        if sub:
            write_glb(medio[0], {'box': box, 'layers': sub})
            m = {'archivo': Path(medio[0]).name, 'triangulos': sum(L['ni'] // 3 for L in sub.values()),
                 'MB': round(Path(medio[0]).stat().st_size / 1e6, 2)}
    if lugares: Path(path).with_suffix('.json').write_text(json.dumps({**meta(res, None), 'capas': res['capas'], 'lugares': res['pois'], 'luces': res['luces']}, ensure_ascii=False, indent=1))
    return {'archivo': path, 'triangulos': res['tris'], 'MB': round(Path(path).stat().st_size / 1e6, 1),
            'capas': {k: L['ni'] // 3 for k, L in res['layers'].items()}, 'medio': m}


async def datos_tesela(pg, caja, inst, faroles, sin_poste, letreros=False):
    """los objetos de una tesela como datos (t_<i>_<j>.json): {capa: números} de las capas instanciadas (__exInst: 9 por
    árbol, 10 por auto, __exInstN) y, con faroles, los de las calles (__exLamps: «faroles», 6 por farol, y «luces», los
    de la Alameda, 3); con letreros, los nombres de las calles en los cruces (__exSigns: «letreros», 11 por letrero, y
    «nombres», sus rótulos); y cuántos hay de cada uno, para indice.json"""
    o, n = {}, {}
    if inst:
        r = await pg.evaluate('([b, c]) => { const o = __exInst(b, c), n = {}; for (const k in o) n[k] = __exInstN(k); return [o, n]; }', [caja, inst])
        for k, v in r[0].items():
            if v: o[k], n[k] = v, len(v) // r[1][k]
    if faroles:
        r = await pg.evaluate('b => __exLamps(b)', caja)
        for k, m in (('faroles', 6), ('luces', 3)):
            if r[k]: o[k], n[k] = r[k], len(r[k]) // m
        for k, v in r['sin'].items(): sin_poste[k] = sin_poste.get(k, 0) + v
    if letreros:
        r = await pg.evaluate('b => __exSigns(b)', caja)
        if r['letreros']: o['letreros'], o['nombres'], n['letreros'] = r['letreros'], r['nombres'], len(r['letreros']) // 11
    return o, n


async def main(a):
    if a.comuna and (a.caja or a.centro): raise SystemExit('--comuna va sin --caja ni --centro')
    t0 = time.time()
    async with Map.from_args(a, init='window.__KEEP=1', ready='full') as m:
        pg = m.page
        await pg.add_script_tag(path=str(Path(__file__).with_name('export.js')))
        if a.letreros:  # el sentido de las calles de un sentido, para las flechas de los letreros (pipeline/sentidos.py)
            f = ROOT / 'data' / 'sentidos.json'
            if f.exists(): await pg.evaluate('v => { window.__exOneway = v; }', json.loads(f.read_text())['v'])
            else: print('aviso: no está data/sentidos.json (make sentidos): los letreros van sin flechas', file=sys.stderr)
        if a.comuna:
            x0, x1, y0, y1 = await pg.evaluate('__export.ext')
        elif a.caja:
            x0, y0, x1, y1 = map(float, a.caja.split(','))
        else:
            cx, cy = map(float, (a.centro or '0,0').split(',')); h = a.lado / 2
            x0, y0, x1, y1 = cx - h, cy - h, cx + h, cy + h
        box = [x0, y0, x1, y1]
        print(f'página lista en {time.time() - t0:.0f} s; caja {box}')
        info = {}
        skip_g = [s for s in (a.sin or '').split(',') if s]
        if a.glb:
            info['glb'] = await export_glb(pg, box, skip_g, a.glb)
            print('->', a.glb, json.dumps(info['glb'], ensure_ascii=False))
        if a.teselas:  # una tesela por archivo, en la grilla de --tam metros desde la plaza, y un índice
            d, t = Path(a.teselas), a.tam; d.mkdir(parents=True, exist_ok=True); lista = []
            inst = [s for s in (a.instancias or '').split(',') if s]
            capas = await pg.evaluate('__exLayers')
            if a.lejos is not None:
                solo = [s for s in a.lejos.split(',') if s]
                if set(solo) - set(capas): raise SystemExit(f"export: --lejos con capas que no existen: {', '.join(set(solo) - set(capas))}")
                skip_l, lejos = [k for k in capas if k not in solo] + ['otros'], []
            medio = [s for s in (a.medio or '').split(',') if s]
            if set(medio) - set(capas): raise SystemExit(f"export: --medio con capas que no existen: {', '.join(set(medio) - set(capas))}")
            for f in [*d.glob('t_*.glb'), *d.glob('t_*.json'), *d.glob('m_*.glb')]: f.unlink()  # las de una exportación anterior (otra caja)
            sin_poste = {}  # los faroles sin poste (__exLamps: sin.cruce), para el resumen
            for j in range(math.floor(y0 / t), math.ceil(y1 / t)):
                for i in range(math.floor(x0 / t), math.ceil(x1 / t)):
                    f, caja = d / f't_{i}_{j}.glb', [i * t, j * t, (i + 1) * t, (j + 1) * t]
                    r = await export_glb(pg, caja, skip_g + inst, str(f), lugares=False, liviano=a.liviano,
                                         medio=(str(d / f'm_{i}_{j}.glb'), medio) if medio else None)
                    if r:
                        e = {'archivo': f.name, 'i': i, 'j': j, 'caja_m': caja, 'triangulos': r['triangulos'], 'MB': r['MB']}
                        if r['medio']: e['medio'] = r['medio']
                        o, cuenta = await datos_tesela(pg, caja, inst, a.faroles, sin_poste, a.letreros)
                        if o:  # los árboles, autos, faroles y letreros como datos: t_<i>_<j>.json
                            f.with_suffix('.json').write_text(json.dumps(o, separators=(',', ':')))
                            e['instancias'] = cuenta
                        lista.append(e)
                        if a.lejos is not None:
                            rl = await geom(pg, caja, skip_l, a.liviano)
                            if rl: lejos.append((f't_{i}_{j}', rl['layers']))
                    print(f'  t_{i}_{j}:', r and r['triangulos'], 'triángulos', flush=True)
            pois = await pg.evaluate('b => __export.PD.pois.filter(p => p.x >= b[0] && p.x < b[2] && p.y >= b[1] && p.y < b[3]).map(p => ({id: p.id, nombre: p.n, cat: p.c, lat: p.lat, lon: p.lon, x: p.x, y: p.y, h: +__export.E(p.x, p.y).toFixed(2)}))', box)
            luces = await pg.evaluate('b => { const G = __export.GLOW || [], o = []; for (let i = 0; i + 2 < G.length; i += 3) if (G[i] >= b[0] && G[i] < b[2] && G[i + 2] >= b[1] && G[i + 2] < b[3]) o.push([+G[i].toFixed(2), +G[i + 2].toFixed(2), +G[i + 1].toFixed(2)]); return o; }', box)
            limite = await pg.evaluate('__export.LIM.map(p => [+p[0].toFixed(1), +p[1].toFixed(1)])')
            ind = {**meta({'box': box}, None), 'capas': capas, 'tesela_m': t, 'teselas': lista, 'lugares': pois, 'luces': luces,
                   'limite': limite, 'instancias': inst, 'liviano': a.liviano}
            if medio: ind['medio'] = {'capas': medio, 'MB': round(sum(x['medio']['MB'] for x in lista if 'medio' in x), 1)}
            if a.lejos is not None:  # lo de lejos: un nodo por tesela (t_<i>_<j>), con las capas de --lejos
                write_glb(str(d / 'lejos.glb'), {'box': box}, lejos)
                ind['lejos'] = {'archivo': 'lejos.glb', 'capas': solo, 'MB': round((d / 'lejos.glb').stat().st_size / 1e6, 1)}
                print('->', d / 'lejos.glb', ind['lejos']['MB'], 'MB')
            if a.faroles:
                ind['faroles'] = {'datos': 'x, y y altura del pie del poste, dirección del brazo (ax, ay) y su largo (tools/export.js __exLamps)',
                                  'n': sum(x.get('instancias', {}).get('faroles', 0) for x in lista), 'sin_poste': sin_poste}
                print('faroles:', ind['faroles']['n'], '; sin poste (en un cruce):', sin_poste.get('cruce', 0))
            if a.letreros:
                ind['letreros'] = {'datos': 'x, y y altura del pie del poste y, de cada una de sus dos calles, la dirección desde el cruce hacia la esquina (ax, ay) y su rótulo en «nombres» (tools/export.js __exSigns)',
                                   'n': sum(x.get('instancias', {}).get('letreros', 0) for x in lista)}
                print('letreros:', ind['letreros']['n'], await pg.evaluate('__exSignsN()'))
            (d / 'indice.json').write_text(json.dumps(ind, ensure_ascii=False, indent=1))
            print('->', d / 'indice.json', len(lista), 'teselas,', round(sum(x['MB'] for x in lista)), 'MB' +
                  (f", {sum(1 for x in lista if 'medio' in x)} medias, {ind['medio']['MB']} MB" if medio else ''))
        if a.stl:
            paso = a.paso or max(1.0, max(x1 - x0, y1 - y0) / 500)
            skip = [s for s in (a.sin if a.sin is not None else 'autos,autos-ruta5,trenes').split(',') if s]
            hm = await pg.evaluate('([b, c, s]) => __exHeight(b, c, {skip: s})', [box, paso, skip])
            escala = a.escala or max(x1 - x0, y1 - y0) * 1000 / 200
            Path(a.stl).parent.mkdir(parents=True, exist_ok=True)
            info['stl'] = write_stl(a.stl, hm, box, escala, a.base, a.vert)
            info['stl']['MB'] = round(Path(a.stl).stat().st_size / 1e6, 1)
            print('->', a.stl, json.dumps(info['stl'], ensure_ascii=False))
        bad = m.print_logs()
    if a.vista:
        from playwright.async_api import async_playwright
        async with async_playwright() as p:
            if a.glb and Path(a.glb).stat().st_size > 150e6:
                print('vista: el glb pesa más de 150 MB, no se dibuja')
            elif a.glb:
                print('vista:', await vista(p, a.glb, a.vista, gl=a.gl), '->', a.vista)
            if a.stl:
                f = str(Path(a.vista).with_name(Path(a.vista).stem + '-stl.png'))
                await vista(p, a.stl, f, True, gl=a.gl); print('vista del STL ->', f)
    if bad: raise SystemExit(f'export: {len(bad)} errores de consola')


if __name__ == '__main__':
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--glb', help='salida glTF binaria (.glb)')
    ap.add_argument('--stl', help='salida STL binaria (milímetros)')
    ap.add_argument('--centro', help='x,y de grilla (metros; por omisión la plaza, 0,0)')
    alias(ap, '--center', '--centro')
    ap.add_argument('--lado', type=float, default=1000, help='lado de la caja alrededor de --centro (m)')
    ap.add_argument('--caja', help='x0,y0,x1,y1 de grilla (m)')
    ap.add_argument('--comuna', action='store_true', help='toda la comuna')
    ap.add_argument('--sin', help='capas que no van, separadas por comas (STL, por omisión: autos,autos-ruta5,trenes)')
    ap.add_argument('--paso', type=float, help='STL: metros entre muestras (por omisión, el lado / 500, al menos 1)')
    ap.add_argument('--escala', type=float, help='STL: 1:N (por omisión, el lado mayor mide 200 mm)')
    ap.add_argument('--base', type=float, default=3, help='STL: grosor de la base bajo el punto más bajo (mm)')
    ap.add_argument('--vert', type=float, default=1, help='STL: exageración vertical extra')
    ap.add_argument('--teselas', help='directorio: un glb por tesela de --tam metros (t_<i>_<j>.glb, la caja x de i·tam a (i+1)·tam) e indice.json')
    ap.add_argument('--tam', type=float, default=1000, help='lado de las teselas (m)')
    ap.add_argument('--instancias', help='--teselas: capas de objetos instanciados (arboles,alamos) que van como datos en t_<i>_<j>.json y no en el glb')
    ap.add_argument('--faroles', action='store_true', help='--teselas: los faroles de las calles como datos en t_<i>_<j>.json (el poste en la vereda; la página solo dibuja su brillo): juego/faroles.gd')
    ap.add_argument('--letreros', action='store_true', help='--teselas: los letreros con el nombre de las calles en los cruces como datos en t_<i>_<j>.json (la página no los dibuja): juego/letreros.gd')
    ap.add_argument('--lejos', nargs='?', const='terreno,agua,borde', help='--teselas: además, lejos.glb con un nodo por tesela y solo estas capas (por omisión terreno,agua,borde): lo que el juego muestra donde no cargó la tesela')
    ap.add_argument('--medio', nargs='?', const='edificios,hitos,ciudad', help='--teselas: además, m_<i>_<j>.glb con solo estas capas de cada tesela (por omisión edificios,hitos,ciudad): lo que el juego carga entre las teselas completas y lejos.glb, para la silueta de la ciudad')
    ap.add_argument('--liviano', action='store_true', help='--teselas: normales y colores de un byte por componente (KHR_mesh_quantization, que el juego declara en juego/cuantizado.gd) e índices de 16 bits donde caben (make juego)')
    ap.add_argument('--vista', help='PNG del glb exportado, cargado de vuelta (revisión)')
    add_page_args(ap, size='1200x800', only=('size', 'gl'))
    a = ap.parse_args()
    if not (a.glb or a.stl or a.teselas): ap.error('falta --glb, --stl o --teselas')
    asyncio.run(main(a))
