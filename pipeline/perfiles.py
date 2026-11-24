"""Los perfiles de calles medidos en fotos (config/perfiles.json) y sus cruces (config/cruces.json), completados con OSM y
el mapa: data/perfiles.json y data/cruces.json, que leen la página (DATA.perfiles y DATA.cruces: src/js/12-perfiles.js
dibuja las bandas sobre la calle, ensancha las del mapa hasta sus líneas de cierre y pone el suelo de los cruces;
src/js/hitos/cruces.js, sus palmeras, letreros, banderas y cierros) y la maqueta en 3D (modelo3d/modelos/perfiles.gd,
de la copia en modelo3d/datos/ que hace make modelo3d: cada calle y cada cruce de cerca, con soleras, pintura, postes,
cables, semáforos y paraderos). Hoy, la Avenida Las Rastras, la Avenida San Miguel a cada lado de ella, la Ruta K-353,
el enlace de San Miguel a Las Rastras y el cruce de las cuatro.

  python pipeline/perfiles.py            -> data/perfiles.json y data/cruces.json (requiere raw/osm/map-comuna.json y
                                            data/geometry.json; make perfiles)
  python pipeline/perfiles.py check      -> lo mismo sin escribir: dónde corta cada cruce a sus brazos y, de cada
                                            perfil, su largo, lo que se dibuja, las calles del mapa, bocas, postes,
                                            faroles del bandejón y árboles
  uv run --with pillow python pipeline/perfiles.py panel <clave> [s0 s1] [--ancho 20 --z 19 --escala 8 --release R]
      -> diagnostics/perfil-<clave>-<s0>-<s1>.png: la imagen de Esri enderezada a lo largo del eje, con una grilla
         punteada cada 5 m (y marcas cada 1 m) y, cada 6 m, el eje de OSM (cian), el borde de la calzada (rojo), la
         solera (naranjo) y la línea de cierre (magenta) del perfil: así se mide «desplazar» (cuánto está corrido el eje
         de OSM respecto de la imagen, que es la de los edificios del mapa) y se revisan los anchos
  uv run --with pillow python pipeline/perfiles.py plano <cruce> [--lado 160 --z 19 --escala 3 --alfa 150]
      -> diagnostics/cruce-<cruce>.png: lo que arma un cruce (suelo, pintura, soleras, objetos y vanos) sobre la imagen

Lo que agrega a cada perfil de config/perfiles.json:
  eje      el eje en metros de grilla (polilínea codificada en delta, de a 0,1 m): las vías de OSM de «osm» encadenadas
           (la primera, desde su punta más cercana a «inicio»), corridas a la imagen según «desplazar» ([[s, m], …]:
           m a la derecha, lineal entre estaciones); un par [ida, vuelta] (dos calzadas de un sentido) aporta la línea
           del medio entre las dos
  largo    el largo del eje (m); s va de 0 a largo
  desde, hasta, nariz   lo que se dibuja (de «dibujar», o desde el corte de su cruce: antes, el cruce) y dónde empieza
           su bandejón (la nariz que pone el cruce; antes de ella el bandejón está abierto)
  nivel    lo que sube toda la calle (un enlace sobre la calzada de la que sale; el 3D)
  calles   [[i, s0, s1, a, b, nombre(, 1)], …]: las calles del mapa (índice en data/geometry.json) que son la avenida
           (uno de sus «nombres», y todos sus puntos a menos de 12 m del eje): la página reemplaza cada una por el tramo
           del eje de s0 a s1, corrido para que su calle y su margen de lotes (WALK_OUT) cubran de a a b (m a la derecha
           del eje; a < 0 a la izquierda): de una línea de cierre a la otra, o en un par, de su lado hasta el medio. Con
           un 1 al final, la calle cae entera en un cruce: no se dibuja (s.bridge), el cruce pone su suelo
  bocas    [[s0, s1, lado], …]: donde llega una calle del mapa (lado -1 izquierda, 1 derecha), de solera a solera más
           1 m de redondeo: ahí no van soleras, veredas, pasto ni la línea de borde, y el bandejón se abre si llega de
           los dos lados
  postes   [[x, y, nx, ny, tipo, farol, telecom], …]: los postes de la luz y los cables (n: hacia la calzada, el brazo
           del farol; tipo «media», «alta» o «simple»; farol 0 o 1; telecom: los cables de telecomunicaciones), cada
           «paso» m del lado de «postes» de cada sección, en el borde exterior de la solera (o a 1 m de la calzada sin
           solera), sin caer en una boca, y la segunda línea de «postes2»
  vanos    [[i, j], …]: los postes vecinos de una misma línea a menos de 60 m (un cable entre ellos)
  faroles  [[x, y, tx, ty, brazo], …]: las columnas de luz del bandejón (faroles «centro»), cada «paso_faroles» m
  paraderos [[x, y, nx, ny, tipo], …], cebras [[s, x, y, tx, ty, ancho]], lomos [[s, x, y, tx, ty, ancho]],
  semaforos [[x, y, nx, ny], …] (uno en cada esquina derecha de la avenida), hileras [[x, y, especie], …]: los
           puntos de cada cosa, ya en metros de grilla

Y de cada cruce de config/cruces.json (sus brazos son perfiles; cada esquina, un arco tangente a las soleras de dos
brazos vecinos), en data/cruces.json:
  brazos   {perfil: {desde, nariz}}: dónde empieza a dibujarse cada brazo (las tangentes de sus esquinas; lo de antes es
           del cruce) y la nariz de su bandejón
  suelo    [[tipo, alto, anillo], …]: el asfalto entre las esquinas y las bandas de cada esquina (solera, vereda,
           pasto, tierra, hasta los cierros), la isla de un enlace; anillo [x0, y0, x1, y1, …] antihorario, alto sobre
           el relieve
  bordes   [[h0, h1, color, polilínea], …]: las caras de las soleras y los faldones (la cara mira a la izquierda)
  pintura  [[color, anillo], …]: cruces peatonales, líneas de detención, flechas, el arco y el achurado de una isla
  objetos  [[tipo, x, y, ángulo, {…}], …] (semáforos, postes, letreros, banderas, palmeras, señales; el ángulo, hacia
           donde miran) y [«cerco», forma, alto, color, polilínea]
  vanos    [[poste a, poste b, cables de telecomunicaciones], …]: los cables que cruzan el cruce, entre sus postes y
           los primeros de las líneas de los brazos

Los anchos de las secciones son estimados en las fotos (config/perfiles.json dice de cuáles; pipeline/mapillary.py eje
baja las de un eje); las calles del mapa son las del grafo de cicloconecta (data/geometry.json), y si cambian (make
data) hay que correr esto de nuevo: la página revisa el nombre de cada calle que toma y avisa si no calza.
"""
import json, math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cli, osm
from common import CONFIG, DATA, ROOT
from geom import dec, enc, seg_point


def seg_t(p, a, b):
    """The point of segment ab nearest to p, and its parameter t (0 at a, 1 at b)."""
    dx, dy = b[0] - a[0], b[1] - a[1]
    L = dx * dx + dy * dy or 1e-9
    t = max(0.0, min(1.0, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / L))
    return (a[0] + t * dx, a[1] + t * dy), t

SRC, OUT = CONFIG / 'perfiles.json', DATA / 'perfiles.json'
CRUCES_SRC, CRUCES_OUT = CONFIG / 'cruces.json', DATA / 'cruces.json'
# heights over the relief (E) of what the junctions lay down, as in modelo3d/modelos/entorno/perfil.gd: the carriageway of the page at
# 0.12, paint 12 mm over it, the kerb 15 cm over it, sidewalks at the kerb's top, grass and dirt behind a kerb 3 cm
# lower, without one at 0.10, and a raised island 1.5 cm over a sidewalk (so they never share a plane)
H = {'calzada': 0.12, 'pintura': 0.132, 'solera': 0.27, 'vereda': 0.27, 'tras': 0.24, 'bajo': 0.10, 'isla': 0.285}
SW = [16, 13, 11, 9.5, 7, 5, 3.5, 3.5]     # the map's street widths per class (src/js/10-decode.js)
CERCA = 12.0                                # m: a map street within this of the axis all along is the avenue itself
INNER = 0.6                                 # m: how far past the axis a carriageway of a pair reaches (the median)
CALZADA = {'pista', 'ciclo', 'berma'}


class Eje:
    """A polyline by distance: point, tangent and normal (to the right) at s, and the station of a point."""
    def __init__(self, P):
        self.P, self.S = P, [0.0]
        for a, b in zip(P, P[1:]): self.S.append(self.S[-1] + math.dist(a, b))
        self.L = self.S[-1]

    def seg(self, s):
        s = min(max(s, 0.0), self.L)
        i = max(0, min(len(self.P) - 2, next((k for k in range(len(self.S) - 1) if self.S[k + 1] >= s), len(self.P) - 2)))
        a, b = self.P[i], self.P[i + 1]
        L = (self.S[i + 1] - self.S[i]) or 1.0
        t = (b[0] - a[0]) / L, (b[1] - a[1]) / L
        return i, a, t, s - self.S[i]

    def at(self, s, d=0.0):
        """The point at station s, d m to the right of the axis, and the unit tangent there."""
        _, a, t, u = self.seg(s)
        return (a[0] + t[0] * u + t[1] * d, a[1] + t[1] * u - t[0] * d), t

    def proj(self, p):
        """(station, signed distance to the right) of the closest point of the axis to p."""
        best = None
        for i, (a, b) in enumerate(zip(self.P, self.P[1:])):
            q, t = seg_t(p, a, b)
            d = math.dist(p, q)
            if best is None or d < best[0]:
                L = math.dist(a, b) or 1.0
                cr = ((b[0] - a[0]) * (p[1] - a[1]) - (b[1] - a[1]) * (p[0] - a[0])) / L
                # the distance to the axis itself, with the side's sign: past an end of the axis, the distance to the
                # end, not to the line of its last segment (a street far along that line is not next to the axis)
                best = (d, self.S[i] + t * L, math.copysign(d, -cr))
        return best[1], best[2]

    def tramo(self, s0, s1, d=0.0):
        """The axis from s0 to s1 (its vertices in between), d m to the right."""
        out = [self.at(s0, d)[0]]
        for k, s in enumerate(self.S):
            if s0 + 0.5 < s < s1 - 0.5:
                i = min(k, len(self.P) - 2)
                n = _normal(self.P, k)
                out.append((self.P[k][0] + n[0] * d, self.P[k][1] + n[1] * d))
        out.append(self.at(s1, d)[0])
        return out


def _normal(P, k):
    """The mitred normal (to the right) at vertex k."""
    tt = []
    if k > 0: tt.append((P[k - 1], P[k]))
    if k < len(P) - 1: tt.append((P[k], P[k + 1]))
    tx = ty = 0.0
    for a, b in tt:
        L = math.dist(a, b) or 1.0
        tx += (b[0] - a[0]) / L; ty += (b[1] - a[1]) / L
    L = math.hypot(tx, ty) or 1.0
    return ty / L, -tx / L


def chain(m, ids, end=None):
    """The points of ways `ids` chained in order, each turned to continue from the last (or from `end`)."""
    out = []
    for wid in ids:
        p = m.pts(m.W[wid])
        ref = out[-1] if out else end
        if ref and math.dist(p[-1], ref) < math.dist(p[0], ref): p = p[::-1]
        out += p[1:] if out and math.dist(out[-1], p[0]) < 0.5 else p
    return out


def eje_de(m, spec, inicio=None):
    """The axis of a profile: its two-way ways in order; a pair [ida, vuelta] gives the line midway between them.
    inicio: a point the axis starts near (its first way is turned to start at the end nearest to it)."""
    P = []
    for it in spec:
        if isinstance(it, int):
            P += [q for q in chain(m, [it], P[-1] if P else inicio) if not P or math.dist(P[-1], q) > 0.3]
            continue
        ida = chain(m, it[0], P[-1] if P else inicio)
        vuelta = Eje(chain(m, it[1], ida[0]))
        for q in ida:
            s, d = vuelta.proj(q)
            r = vuelta.at(s)[0]
            mid = ((q[0] + r[0]) / 2, (q[1] + r[1]) / 2)
            if not P or math.dist(P[-1], mid) > 0.3: P.append(mid)
    # thin the vertices to ~0.1 m of the chained line (the median line of a pair zigzags by a few cm)
    out = [P[0]]
    for a, b in zip(P[1:], P[2:]):
        q = seg_point(a, out[-1], b)
        if math.dist(a, q) > 0.1: out.append(a)
    out.append(P[-1])
    return Eje([(round(x, 1), round(y, 1)) for x, y in out])


def ancho(bandas):
    return sum(b[1] for b in bandas)


def seccion(pf, s):
    for sec in pf['secciones']:
        if sec['s'][0] <= s < sec['s'][1]: return sec
    return pf['secciones'][-1]


def mitad(sec, lado):
    """The half of the profile on one side: the carriageway's edge (with the median), the kerb's outer edge, the fence."""
    med = sec.get('bandejon', 0) / 2
    b = sec['O' if lado < 0 else 'E']
    calz = med + sum(w for t, w, *_ in b if t in CALZADA)
    sol = calz + sum(w for t, w, *_ in b if t == 'solera')
    return calz, sol, med + ancho(b)


def corrimiento(pf, s):
    """How far to the right of OSM's axis the real one is at s (the profile's «desplazar»: [[s, d], …], linear in
    between and constant past its ends; 0 without it)."""
    D = pf.get('desplazar') or [[0, 0]]
    if s <= D[0][0]: return D[0][1]
    for (sa, da), (sb, db) in zip(D, D[1:]):
        if s <= sb: return da + (db - da) * (s - sa) / ((sb - sa) or 1)
    return D[-1][1]


def corrido(E, pf):
    """The axis moved to where the road is: OSM's lines can be metres off the imagery that the buildings of OSM match
    (and the photos); «desplazar» says by how much, measured with `perfiles.py panel`."""
    if not pf.get('desplazar'): return E
    ss = sorted({*E.S, *(min(max(s, 0), E.L) for s, _ in pf['desplazar'])})
    return Eje([tuple(round(v, 1) for v in E.at(s, corrimiento(pf, s))[0]) for s in ss])


def ejes(m, cfg):
    """{key: (axis as drawn, OSM's axis)} of every profile in cfg."""
    out = {}
    for key, pf in cfg.items():
        if key.startswith('_'): continue
        E0 = eje_de(m, pf['osm'], pf.get('inicio'))
        out[key] = corrido(E0, pf), E0
    return out


def build(m, cfg, ejes_, cortes):
    """The profiles of data/perfiles.json; cortes: {key: {desde, hasta, nariz}} from the junctions."""
    g = json.loads((DATA / 'geometry.json').read_text())
    out = {}
    for key, (E, _) in ejes_.items():
        pf = cfg[key]
        secs = pf['secciones']
        assert secs[0]['s'][0] == 0 and all(a['s'][1] == b['s'][0] for a, b in zip(secs, secs[1:])), f'{key}: secciones con huecos'
        secs[-1]['s'][1] = round(E.L)
        # the map's streets that are the avenue, and the side streets that reach it
        calles, bocas = [], []
        for i, (c, ni, enc_pts) in enumerate(g['streets']):
            P = dec(enc_pts)
            name = g['names'][ni]
            pr = [E.proj(p) for p in P]
            if name in pf.get('nombres', [pf['nombre']]) and all(abs(d) < CERCA and -2 < s < E.L + 2 for s, d in pr):
                s0, s1 = max(0.0, min(s for s, _ in pr)), min(E.L, max(s for s, _ in pr))
                # which carriageway of a pair it is: by its side of OSM's axis (the moved one can pass over it)
                dm = sum(d + corrimiento(pf, s) for s, d in pr) / len(pr)
                lo = min(-mitad(seccion(pf, s), -1)[2] for s in (s0, (s0 + s1) / 2, s1))
                hi = max(mitad(seccion(pf, s), 1)[2] for s in (s0, (s0 + s1) / 2, s1))
                a, b = (lo, hi) if abs(dm) < 2 else ((-INNER, hi) if dm > 0 else (lo, INNER))
                calles.append([i, round(s0, 1), round(s1, 1), round(a, 2), round(b, 2), name])
                continue
            w = SW[c]
            for lado in (-1, 1):
                # where the street enters this side of the band: a segment crossing the line at the kerb, or an end on it
                for p, q in zip(P, P[1:]):
                    (sp, dp), (sq, dq) = E.proj(p), E.proj(q)
                    if not (-1 < sp < E.L + 1 and -1 < sq < E.L + 1): continue
                    lim = mitad(seccion(pf, (sp + sq) / 2), lado)[2] + 2
                    din, dout = (dp, dq) if abs(dp) < abs(dq) else (dq, dp)
                    if din * lado < -1.5 or dout * lado < 1 or abs(din) > lim: continue
                    if abs(dout - din) < 0.5: continue
                    t = (lado * mitad(seccion(pf, sp), lado)[1] - din) / (dout - din) if abs(dout) > abs(din) else 0
                    sc = sp + (sq - sp) * max(0.0, min(1.0, t))
                    L = math.dist(p, q) or 1.0
                    sin = abs(dout - din) / L
                    h = w / 2 / max(sin, 0.5) + 1.0
                    bocas.append([round(sc - h, 1), round(sc + h, 1), lado, name])
                    break
        bocas.sort()
        boca = lambda s, lado, r=0.0: any(b[0] - r <= s <= b[1] + r and b[2] == lado for b in bocas)
        # what is drawn of the axis: from where a junction ends (its cut) or «dibujar»
        dib = pf.get('dibujar', [0, E.L])
        desde, hasta = max(dib[0], cortes.get(key, {}).get('desde', 0)), min(dib[1], cortes.get(key, {}).get('hasta', E.L))
        dentro = lambda s, r=0.0: desde + r <= s <= hasta - r
        calles = [c[:1] + [round(max(c[1], desde), 1), round(min(c[2], hasta), 1)] + c[3:] + ([1] if min(c[2], hasta) - max(c[1], desde) < 0.5 else [])
                  for c in calles]
        def punto(s, lado, d):
            """[x, y, nx, ny]: d m to side `lado` of the axis at s, with n pointing back to the axis."""
            (x, y), t = E.at(s, lado * d)
            return [round(x, 2), round(y, 2), round(-lado * t[1], 3), round(lado * t[0], 3)]
        # poles: at the back of the kerb (or 1 m off the carriageway without one), out of the side streets' mouths;
        # each [x, y, nx, ny, type, lamp, telecom cables]. The main line («postes», «paso») carries the lamps unless
        # they stand in the median («faroles»: «centro»); a second line («postes2»: [side, spacing, type]) never does.
        # vanos: the spans of cable, between poles of the same line less than 60 m apart
        postes, vanos, ultimo = [], [], {}
        for sec in secs:
            lineas = [('1', sec.get('postes', 'O'), sec.get('paso', 35), 'media', sec.get('faroles', 'postes') == 'postes', sec.get('telecom', 0))]
            if sec.get('postes2'):
                l2 = sec['postes2']; lineas.append(('2', l2[0], l2[1], l2[2] if len(l2) > 2 else 'media', False, 0))
            for linea, lado_, paso, tipo, farol, tel in lineas:
                lado = -1 if lado_ == 'O' else 1
                s = sec['s'][0] + paso / 2
                while s < sec['s'][1]:
                    if not boca(s, lado, 2.5) and dentro(s, 2):
                        calz, sol, _ = mitad(sec, lado)
                        p = punto(s, lado, (sol + 0.45) if sol > calz else calz + 1.0) + [tipo, int(farol), tel]
                        k = (linea, lado)
                        if k in ultimo and math.dist(postes[ultimo[k]][:2], p[:2]) < 60: vanos.append([ultimo[k], len(postes)])
                        ultimo[k] = len(postes); postes.append(p)
                    s += paso
        # the lamps in the median: a double-armed column on the axis every «paso_faroles» m, where there is a median
        faroles = []
        for sec in secs:
            if sec.get('faroles') != 'centro': continue
            s = sec['s'][0] + sec.get('paso_faroles', 40) / 2
            while s < sec['s'][1]:
                if sec['centro'] == 'bandejon' and sec.get('bandejon', 0) >= 1 and dentro(s, 4) and s >= cortes.get(key, {}).get('nariz', 0) + 3 \
                        and not (boca(s, -1, 3) and boca(s, 1, 3)):
                    (x, y), t = E.at(s)
                    faroles.append([round(x, 2), round(y, 2), round(t[0], 3), round(t[1], 3), round(sec['bandejon'] / 2 + 1.9, 2)])
                s += sec.get('paso_faroles', 40)
        paraderos = []
        for s, l, tipo in pf.get('paraderos', []):
            if not dentro(s, 3): continue
            lado = -1 if l == 'O' else 1
            calz, sol, fin = mitad(seccion(pf, s), lado)
            paraderos.append(punto(s, lado, min(fin - 0.8, max(sol, calz + 0.5) + 1.8)) + [tipo])
        def cruza(s):
            sec = seccion(pf, s)
            w = mitad(sec, -1)[0] + mitad(sec, 1)[0]
            (x, y), t = E.at(s, (mitad(sec, 1)[0] - mitad(sec, -1)[0]) / 2)
            return [s, round(x, 2), round(y, 2), round(t[0], 4), round(t[1], 4), round(w, 2)]
        semaforos = []
        for s in pf.get('semaforos', []):
            for lado in (-1, 1):
                sec = seccion(pf, s)
                for ds in (-12, 12):
                    if 0 <= s + ds <= E.L and (ds < 0) == (lado > 0):
                        semaforos.append(punto(s + ds, lado, mitad(sec, lado)[1] + 0.6))
        hileras = []
        for s0, s1, l, esp, d, paso in pf.get('hileras', []):
            lado = -1 if l == 'O' else 1
            s = s0 + paso / 2
            while s < s1:
                if not boca(s, lado, 3) and dentro(s):
                    hileras.append(punto(s, lado, d)[:2] + [esp])
                s += paso
        out[key] = {
            'nombre': pf['nombre'], 'fuente': pf['fuente'], 'eje': enc(E.P, 10), 'largo': round(E.L, 1),
            'desde': round(desde, 2), 'hasta': round(hasta, 2), 'nariz': cortes.get(key, {}).get('nariz', 0), 'nivel': pf.get('nivel', 0),
            'secciones': secs, 'calles': calles, 'bocas': bocas, 'postes': postes, 'vanos': vanos, 'faroles': faroles,
            'paraderos': paraderos,
            'cebras': [cruza(s) for s in pf.get('cebras', []) if dentro(s)], 'lomos': [cruza(s) for s in pf.get('lomos', []) if dentro(s)],
            'semaforos': [p for p in semaforos], 'achurados': pf.get('achurados', []), 'hileras': hileras}
    return out


# ---- junctions (config/cruces.json -> data/cruces.json) ----------------------------------------------------------
#
# A junction is where some profiles start (their s = 0 is at it). Each corner between two arms next to each other is a
# kerb arc of a measured radius tangent to their kerb lines (the edges of their carriageways); the asphalt is what the
# arcs and the arms' cuts enclose, and each arm is drawn from where its corners end (its cut). Everything is computed
# here and written as polygons, kerb faces and objects in grid metres: the page and modelo3d/modelos/entorno/cruce.gd only draw them.

def en(E, s, d=0.0):
    """The point d m right of the axis at s; before s = 0 (or past the end) along the end's tangent."""
    if 0 <= s <= E.L: return E.at(s, d)[0]
    s0 = 0.0 if s < 0 else E.L
    (x, y), t = E.at(s0)
    u = s - s0
    return (x + t[0] * u + t[1] * d, y + t[1] * u - t[0] * d)


def tangente(E, s):
    return E.at(min(max(s, 0), E.L))[1]


def corte_rectas(p, u, q, v):
    """The parameters (a, b) with p + a·u = q + b·v, or None for parallel lines."""
    den = u[0] * v[1] - u[1] * v[0]
    if abs(den) < 1e-9: return None
    w = (q[0] - p[0], q[1] - p[1])
    return (w[0] * v[1] - w[1] * v[0]) / den, (w[0] * u[1] - w[1] * u[0]) / den


def nrm(v):
    L = math.hypot(*v) or 1.0
    return (v[0] / L, v[1] / L)


class Esquina:
    """The corner between arm A and arm B (B counter-clockwise from A): A's left kerb, B's right kerb and the arc of
    radius r tangent to both. curva(d) is the kerb line moved d m away from the asphalt (the arc's radius r − d)."""
    def __init__(self, A, B, r, ref=25.0):
        self.A, self.B, self.r = A, B, r
        ta, tb = tangente(A.E, ref), tangente(B.E, ref)
        self.pa, self.pb = en(A.E, ref, -A.calz(-1, ref)), en(B.E, ref, B.calz(1, ref))
        k = corte_rectas(self.pa, ta, self.pb, tb)
        if k is None: raise SystemExit(f'esquina {A.key}–{B.key}: los bordes de sus calzadas son paralelos')
        self.X = (self.pa[0] + ta[0] * k[0], self.pa[1] + ta[1] * k[0])
        self.a, self.b = ta, tb
        th = math.acos(max(-1.0, min(1.0, ta[0] * tb[0] + ta[1] * tb[1])))
        self.th = th
        self.bis = nrm((ta[0] + tb[0], ta[1] + tb[1]))
        self.dt = r / math.tan(th / 2)
        self.C = (self.X[0] + self.bis[0] * r / math.sin(th / 2), self.X[1] + self.bis[1] * r / math.sin(th / 2))
        # the stations of the tangent points on each arm (how far each arm's straight kerb comes in)
        self.sa = ref + k[0] + self.dt
        self.sb = ref + k[1] + self.dt

    def curva(self, d, ca, cb, r=None):
        """The kerb line moved d away from the asphalt, from A's cut (station ca) to B's cut (cb), with an arc of radius
        r (the corner's, by default) − d, or the corner of the moved lines when that is ≤ 0."""
        r = self.r if r is None else r
        A, B = self.A, self.B
        X = self.X
        if r - d > 0.05:
            dt = r / math.tan(self.th / 2)
            C = (X[0] + self.bis[0] * r / math.sin(self.th / 2), X[1] + self.bis[1] * r / math.sin(self.th / 2))
            TA = (X[0] + self.a[0] * dt, X[1] + self.a[1] * dt)
            TB = (X[0] + self.b[0] * dt, X[1] + self.b[1] * dt)
            k = (r - d) / r
            ta = (C[0] + (TA[0] - C[0]) * k, C[1] + (TA[1] - C[1]) * k)
            tb = (C[0] + (TB[0] - C[0]) * k, C[1] + (TB[1] - C[1]) * k)
            f0, f1 = math.atan2(ta[1] - C[1], ta[0] - C[0]), math.atan2(tb[1] - C[1], tb[0] - C[0])
            df = (f1 - f0 + math.pi) % (2 * math.pi) - math.pi
            n = max(2, int(abs(df) * (r - d) / 0.5))
            arco = [(C[0] + (r - d) * math.cos(f0 + df * i / n), C[1] + (r - d) * math.sin(f0 + df * i / n)) for i in range(n + 1)]
        else:
            q = d / math.sin(self.th / 2)
            arco = [(X[0] + self.bis[0] * q, X[1] + self.bis[1] * q)]
        # the straight kerbs from the cuts to the arc, each at its sections' carriageway edge (they can change width)
        def recta(Br, lado, c, p):
            s1 = Br.E.proj(p)[0] if 0 < Br.E.proj(p)[0] < Br.E.L else max(0.0, c - 30)
            ss, s = [], c
            while s > s1 + 0.5:
                ss.append(en(Br.E, s, lado * (Br.calz(lado, s) + d))); s -= 2.0
            return ss
        return recta(A, -1, ca, arco[0]) + arco + recta(B, 1, cb, arco[-1])[::-1]


class Brazo:
    """An arm of a junction: a profile whose s = 0 is at the junction."""
    def __init__(self, key, E, pf, opc):
        self.key, self.E, self.pf, self.opc = key, E, pf, opc
        self.c = float(opc.get('corte', 0))          # where the arm starts to be drawn (raised to its corners' tangents)
        self.ang = math.atan2(*reversed(tangente(E, 15)))

    def sec(self, s=None):
        return seccion(self.pf, self.c + 1 if s is None else s)

    def calz(self, lado, s=None):
        return mitad(self.sec(s), lado)[0]

    def sol(self, lado, s=None):
        return mitad(self.sec(s), lado)[1]

    def fin(self, lado, s=None):
        return mitad(self.sec(s), lado)[2]


def _armar(c, E, cfg):
    """The arms of junction c in counter-clockwise order, and its corners (each with its spec)."""
    brazos = sorted((Brazo(k, E[k][0], cfg[k], o) for k, o in c['brazos'].items()), key=lambda b: b.ang)
    esq = []
    for i, A in enumerate(brazos):
        B = brazos[(i + 1) % len(brazos)]
        spec = next((e for e in c['esquinas'] if set(e['entre']) == {A.key, B.key}), None)
        if spec is None: raise SystemExit(f'cruce: falta la esquina entre {A.key} y {B.key}')
        esq.append((Esquina(A, B, spec['radio']), spec))
    # each arm starts past the tangent points of its two corners (and past any island's)
    for e, spec in esq:
        e.A.c = max(e.A.c, e.sa + 0.3)
        e.B.c = max(e.B.c, e.sb + 0.3)
    return brazos, esq


def cortes(ccfg, E, cfg):
    """{profile: {desde, nariz}}: where each arm of a junction starts to be drawn and its median starts."""
    out = {}
    for key, c in ccfg.items():
        if key.startswith('_'): continue
        brazos, _ = _armar(c, E, cfg)
        for b in brazos:
            out[b.key] = {'desde': round(b.c, 2), 'nariz': max(round(b.c, 2), float(b.opc.get('nariz', 0)))}
    return out


def anillo(pts):
    """A ring as a flat list, rounded to cm, counter-clockwise."""
    a = sum(p[0] * q[1] - q[0] * p[1] for p, q in zip(pts, pts[1:] + pts[:1]))
    if a < 0: pts = pts[::-1]
    return [round(v, 2) for p in pts for v in p]


def linea(pts):
    return [round(v, 2) for p in pts for v in p]


def franja(a, b, w):
    """The quad of width w along segment ab."""
    t = nrm((b[0] - a[0], b[1] - a[1])); n = (-t[1] * w / 2, t[0] * w / 2)
    return [(a[0] + n[0], a[1] + n[1]), (b[0] + n[0], b[1] + n[1]), (b[0] - n[0], b[1] - n[1]), (a[0] - n[0], a[1] - n[1])]


def achurar(poli, ang, paso, w):
    """Hatch stripes of width w every `paso` m at angle ang (radians), cut by polygon poli: their quads."""
    t = (math.cos(ang), math.sin(ang)); n = (-t[1], t[0])
    ks = [p[0] * n[0] + p[1] * n[1] for p in poli]
    out = []
    k = math.floor(min(ks) / paso) * paso + paso / 2
    while k < max(ks):
        o = (n[0] * k, n[1] * k)
        hits = []
        for p, q in zip(poli, poli[1:] + poli[:1]):
            r = corte_rectas(o, t, p, (q[0] - p[0], q[1] - p[1]))
            if r and 0 <= r[1] < 1: hits.append(r[0])
        hits.sort()
        for u0, u1 in zip(hits[::2], hits[1::2]):
            if u1 - u0 > 0.3:
                out.append(franja((o[0] + t[0] * (u0 + 0.15), o[1] + t[1] * (u0 + 0.15)), (o[0] + t[0] * (u1 - 0.15), o[1] + t[1] * (u1 - 0.15)), w))
        k += paso
    return out


def polilinea_corte(P, Q):
    """The first crossing of polyline P with polyline Q: (point, index into P, t), or None."""
    for i, (p, p2) in enumerate(zip(P, P[1:])):
        for q, q2 in zip(Q, Q[1:]):
            r = corte_rectas(p, (p2[0] - p[0], p2[1] - p[1]), q, (q2[0] - q[0], q2[1] - q[1]))
            if r and 0 <= r[0] <= 1 and 0 <= r[1] <= 1:
                return (p[0] + (p2[0] - p[0]) * r[0], p[1] + (p2[1] - p[1]) * r[0]), i, r[0]
    return None


FLECHAS = {   # arrows painted on a lane, in (lateral, along) metres from the arrow's foot, pointing along +v
    'recta': [(-0.15, 0), (0.15, 0), (0.15, 3.4), (0.45, 3.4), (0, 5.0), (-0.45, 3.4), (-0.15, 3.4)],
    'izquierda': [(-0.15, 0), (0.15, 0), (0.15, 3.2), (-0.6, 3.6), (-0.55, 4.1), (-1.5, 3.4), (-0.4, 2.6), (-0.45, 3.1), (-0.15, 2.9)],
    'derecha': [(0.15, 0), (-0.15, 0), (-0.15, 3.2), (0.6, 3.6), (0.55, 4.1), (1.5, 3.4), (0.4, 2.6), (0.45, 3.1), (0.15, 2.9)],
}


def cruces(ccfg, E, cfg, cor, perfiles):
    out = {}
    for key, c in ccfg.items():
        if key.startswith('_'): continue
        brazos, esq = _armar(c, E, cfg)
        by = {b.key: b for b in brazos}
        suelo, pintura, bordes, objetos, vanos = [], [], [], [], []
        # the asphalt: each arm's cut, then the corner to the next arm
        anillo_c = []
        for (e, spec), A in zip(esq, brazos):
            anillo_c += [en(A.E, A.c, A.calz(1)), en(A.E, A.c, -A.calz(-1))]
            anillo_c += e.curva(0, A.c, e.B.c)[1:-1]
        suelo.append(['calzada', H['calzada'], anillo(anillo_c)])
        # the corners: their bands from the kerb out (the last one to the fences), or an island
        for e, spec in esq:
            A, B = e.A, e.B
            if spec.get('isla'):
                isla(e, spec, by, E, cfg, perfiles, suelo, pintura, bordes, objetos)
                continue
            bandas = spec.get('bandas', [['solera', 0.15], ['vereda', 2.0], ['tierra', 0]])
            d = 0.0
            tras = False
            for i, b in enumerate(bandas):
                tipo, w = b[0], b[1]
                ultima = i == len(bandas) - 1
                c0 = e.curva(d, A.c, B.c)
                if ultima:
                    # to the fences: at the cuts, each arm's; around the corner, the kerb's curve moved out as far as
                    # the nearer fence (a lot's corner follows the street's: the fences' own corner can fall in the
                    # asphalt of a wide curve), and at least 0.8 m
                    fa, fb = A.fin(-1, A.c), B.fin(1, B.c)
                    dF = max(d + 0.8, min(fa - A.calz(-1, A.c), fb - B.calz(1, B.c)))
                    afuera = [p for p in e.curva(dF, A.c, B.c) if A.E.proj(p)[0] < A.c - 0.5 and B.E.proj(p)[0] < B.c - 0.5]
                    cierro = [en(B.E, B.c, fb)] + afuera[::-1] + [en(A.E, A.c, -fa)]
                    poli = c0 + cierro
                    # the skirt at the fences, down under the page's ground
                    bordes.append([alto(tipo, tras), -0.3, 'tierra', linea(cierro)])
                else:
                    poli = c0 + e.curva(d + w, A.c, B.c)[::-1]
                col = (tipo + ('-amarilla' if len(b) > 2 and b[2] == 'amarilla' else '')) if tipo == 'solera' else tipo
                suelo.append([col, alto(tipo, tras), anillo(poli)])
                if tipo == 'solera':
                    # its face to the street (toward the asphalt: the left of the line from A to B)
                    bordes.append([H['calzada'], H['solera'], 'solera-amarilla' if col.endswith('amarilla') else 'solera', linea(c0)])
                    tras = True
                d += w
        # the arms' crossings, stop lines and arrows
        for p in c.get('pasos', []):
            b = by[p['brazo']]; s = p['s']
            d0, d1 = -b.calz(-1, s), b.calz(1, s)
            if p.get('tipo', 'lineas') == 'cebra':
                d = d0 + 0.5
                while d < d1 - 0.5:
                    pintura.append(['blanco', anillo([en(b.E, s - 1.5, d), en(b.E, s + 1.5, d), en(b.E, s + 1.5, d + 0.5), en(b.E, s - 1.5, d + 0.5)])])
                    d += 1.0
            else:   # two lines across, 3 m apart: a crossing at a signal
                for ds in (-1.5, 1.5):
                    pintura.append(['blanco', anillo(franja(en(b.E, s + ds, d0), en(b.E, s + ds, d1), 0.3))])
        for p in c.get('detenciones', []):
            b = by[p['brazo']]; s = p['s']; sec = b.sec(s)
            med = sec.get('bandejon', 0) / 2 if sec['centro'] == 'bandejon' else 0.1
            pintura.append(['blanco', anillo(franja(en(b.E, s, -med), en(b.E, s, -b.calz(-1, s)), 0.4))])
        for p in c.get('flechas', []):
            b = by[p['brazo']]; s = p['s']; sec = b.sec(s)
            med = sec.get('bandejon', 0) / 2 if sec['centro'] == 'bandejon' else 0.0
            w = [x[1] for x in sec['O'] if x[0] == 'pista']
            d = -(med + sum(w[:p['pista']]) + w[p['pista']] / 2)
            (x, y), t = b.E.at(s, d)
            v = (-t[0], -t[1])      # toward the junction: the approach (the left side of the arm) runs that way
            u = (v[1], -v[0])       # and its right
            pintura.append(['blanco', anillo([(x + u[0] * a + v[0] * l, y + u[1] * a + v[1] * l) for a, l in FLECHAS[p['tipo']]])])
        # the objects, and the spans of cable between poles
        ids = {}
        for o in c.get('objetos', []):
            r = objeto(o, by, E, cfg, perfiles)
            if 'id' in o: ids[o['id']] = r
            objetos.append(r)
        for a, b, *n in c.get('vanos', []):
            pa, pb = poste_de(a, ids, perfiles), poste_de(b, ids, perfiles)
            vanos.append([pa, pb, n[0] if n else 0])
        out[key] = {'nombre': c['nombre'], 'fuente': c['fuente'],
                    'brazos': {b.key: {'desde': round(b.c, 2)} for b in brazos},
                    'suelo': suelo, 'pintura': pintura, 'bordes': bordes, 'objetos': objetos, 'vanos': vanos}
    return out


def alto(tipo, tras):
    """The height of a band, as perfil.gd alto()."""
    if tipo == 'solera': return H['solera']
    if tipo in CALZADA: return H['calzada']
    if tras: return H['tras'] if tipo in ('pasto', 'tierra') else H['vereda']
    return H['bajo'] if tipo in ('pasto', 'tierra') else H['calzada'] + 0.02


def isla(e, spec, by, E, cfg, perfiles, suelo, pintura, bordes, objetos):
    """A corner that is a painted line (the corner's arc) with a raised island behind it, between the two arms and a
    slip road («rampa»): the island's kerb is an arc of a smaller radius tangent to the same kerb lines, the crescent
    between the two is hatched, and the island's far side is the slip road's left kerb."""
    A, B = e.A, e.B
    sp = spec['isla']
    rk = sp['rampa']
    R = E[rk][0]; pr = cfg[rk]
    pmr = perfiles[rk]
    # the slip road's left kerb (its carriageway's edge), where it is drawn
    s, borde_r = pmr['desde'], []
    while s <= pmr['hasta']:
        borde_r.append(en(R, s, -mitad(seccion(pr, s), -1)[0])); s += 1.0
    # the island's kerb along A, around its arc and along B, long enough to meet the slip road
    larga = e.curva(0, A.c + 120, B.c + 120, sp['radio'])
    # where the slip road's kerb crosses the island's: its first and last crossing along the slip road, each with the
    # segment of both lines it is on (at a shallow angle the nearest vertices can lie on the wrong side)
    c1 = polilinea_corte(borde_r, larga)
    c2 = polilinea_corte(borde_r[::-1], larga)
    if not (c1 and c2): raise SystemExit(f'isla {A.key}–{B.key}: su borde no encuentra la calzada de {rk}')
    j1, j2 = c1[1], len(borde_r) - 2 - c2[1]
    k1 = polilinea_corte(larga, borde_r[j1:j1 + 2])[1]
    k2 = polilinea_corte(larga, borde_r[j2:j2 + 2])[1]
    n1, n2 = c1[0], c2[0]
    if k1 > k2: (k1, n1, j1), (k2, n2, j2) = (k2, n2, j2), (k1, n1, j1)
    if 'nariz' in sp and j1 < j2:
        # the island's nose where the slip road has left (from its station «nariz» on, where the two kerbs are 1.2 m
        # apart): before it they run side by side, a sliver the photos show as painted asphalt
        lejos = lambda p: min(math.dist(p, cerca_seg(p, larga[k], larga[k + 1])) for k in range(len(larga) - 1))
        j1 = max(j1, min(j2 - 2, int(round(sp['nariz'] - pmr['desde']))))
        while j1 < j2 - 2 and lejos(borde_r[j1]) < 1.2: j1 += 1
        p = borde_r[j1]
        k1, n1 = min(((k, cerca_seg(p, larga[k], larga[k + 1])) for k in range(len(larga) - 1)), key=lambda kq: math.dist(p, kq[1]))
        tramo = borde_r[j1:j2 + 1][::-1]
    else:
        tramo = borde_r[j1 + 1:j2 + 1][::-1] if j1 < j2 else borde_r[j2 + 1:j1 + 1]
    contorno = [n1] + larga[k1 + 1:k2 + 1] + [n2]
    poli = contorno + tramo
    sol = 'solera-amarilla' if sp.get('solera') == 'amarilla' else 'solera'
    # the kerb: a band of 15 cm inside the ring, its faces outward; the island's ground inside it
    suelo.append([sp.get('suelo', 'pasto'), H['isla'], anillo(poli)])
    ring = poli + [poli[0]]
    bordes.append([H['calzada'], H['isla'] + 0.005, sol, linea(ring[::-1] if area_(poli) > 0 else ring)])
    suelo += [[sol, H['isla'] + 0.005, q] for q in banda_interior(poli, 0.15)]
    # the hatched crescent between the painted line (the corner's arc) and the island's kerb
    pint = e.curva(0, A.c, B.c)
    kerb = e.curva(0, A.c, B.c, sp['radio'])
    luna = pint[1:-1] + kerb[1:-1][::-1]
    pintura += [['blanco', anillo(franja(p, q, 0.15))] for p, q in zip(pint[1:-2], pint[2:-1])]
    ang = math.atan2(*reversed(e.bis)) + math.radians(sp.get('achurado_giro', 45))
    pintura += [['blanco', anillo(q)] for q in achurar(luna, ang, 1.6, 0.35)]
    if sp.get('baranda'):
        # a pipe railing 0.6 m inside the island's kerb, along its arc
        ins = e.curva(0.6, A.c, B.c, sp['radio'])
        objetos.append(['cerco', 'tubo', 1.0, 'e6cf4a', linea([p for p in ins[1:-1]])])


def cerca_seg(p, a, b):
    """The point of segment ab nearest to p."""
    return seg_t(p, a, b)[0]


def area_(P):
    return sum(p[0] * q[1] - q[0] * p[1] for p, q in zip(P, P[1:] + P[:1])) / 2


def banda_interior(P, w):
    """A band of width w inside ring P (counter-clockwise or not), as one quad per side (rings)."""
    if area_(P) < 0: P = P[::-1]
    n = len(P)
    ins = []
    for i in range(n):
        a, p, b = P[i - 1], P[i], P[(i + 1) % n]
        t1, t2 = nrm((p[0] - a[0], p[1] - a[1])), nrm((b[0] - p[0], b[1] - p[1]))
        n1, n2 = (-t1[1], t1[0]), (-t2[1], t2[0])
        m = nrm((n1[0] + n2[0], n1[1] + n2[1])); k = max(0.35, m[0] * n1[0] + m[1] * n1[1])
        ins.append((p[0] + m[0] * w / k, p[1] + m[1] * w / k))
    def convexo(q):   # at an acute tip the inset crosses over: that quad is left out
        cr = [(b[0] - a[0]) * (c[1] - b[1]) - (b[1] - a[1]) * (c[0] - b[0]) for a, b, c in zip(q, q[1:] + q[:1], q[2:] + q[:2])]
        return all(v > 1e-5 for v in cr) or all(v < -1e-5 for v in cr)
    quads = [[P[i], P[(i + 1) % n], ins[(i + 1) % n], ins[i]] for i in range(n) if math.dist(P[i], P[(i + 1) % n]) > 0.02]
    return [anillo(q) for q in quads if convexo(q)]


def objeto(o, by, E, cfg, perfiles):
    """An object of a junction, where it stands: [type, x, y, ang (where it faces, radians from +x), params]; a fence
    along an arm («a_lo_largo»: [profile, s0, s1, side(, m beyond the kerb)]; without the distance, at the fence line):
    ['cerco', form, height, colour, polyline]."""
    if 'a_lo_largo' in o:
        k, s0, s1, l, *mas = o['a_lo_largo']
        Ek, pk = E[k][0], cfg[k]
        lado = -1 if l == 'O' else 1
        pts, s = [], s0
        while True:
            m_ = mitad(seccion(pk, s), lado)
            pts.append(en(Ek, s, lado * ((m_[1] + mas[0]) if mas else m_[2] - 0.1)))
            if s >= s1: break
            s = min(s1, s + 2.0)
        return ['cerco', o['forma'], o['alto'], o.get('color', '888888'), linea(pts)]
    key = o['en'][0]
    Eo, pf = E[key][0], cfg[key]
    s, d = o['en'][1], o['en'][2]
    if isinstance(d, list):   # [side, m beyond the kerb]
        lado = -1 if d[0] == 'O' else 1
        d = lado * (mitad(seccion(pf, s), lado)[1] + d[1])
    x, y = en(Eo, s, d)
    t = tangente(Eo, s)
    mira = o.get('mira', 'calzada')
    if mira == 'llegada': f = t                       # faces the traffic coming to the junction along the arm
    elif mira == 'salida': f = (-t[0], -t[1])
    elif mira == 'calzada': f = (t[1], -t[0]) if d < 0 else (-t[1], t[0])   # toward the axis
    elif mira == 'afuera': f = (-t[1], t[0]) if d < 0 else (t[1], -t[0])
    else:
        a = math.radians(float(mira)) + math.atan2(t[1], t[0]); f = (math.cos(a), math.sin(a))
    p = {k: v for k, v in o.items() if k not in ('en', 'mira', 'tipo', 'id', 'nota')}
    return [o['tipo'], round(x, 2), round(y, 2), round(math.atan2(f[1], f[0]), 3), p]


def poste_de(ref, ids, perfiles):
    """A pole for a span: a junction object's id, or [profile, side, line] (the first pole of that line)."""
    if isinstance(ref, str):
        o = ids[ref]
        return [o[1], o[2], round(math.cos(o[3]), 3), round(math.sin(o[3]), 3), o[4].get('poste', 'media'), 0, o[4].get('telecom', 0)]
    k, lado_, cual = ref
    pm = perfiles[k]
    lado = -1 if lado_ == 'O' else 1
    E = Eje([(x / 10, y / 10) for x, y in dec(pm['eje'])])
    cand = [(E.proj(p[:2])[0], p) for p in pm['postes'] if E.proj(p[:2])[1] * lado > 0 and (p[4] == cual)]
    return min(cand, key=lambda c: c[0])[1]


def todo():
    """(profiles, junctions): data/perfiles.json and data/cruces.json. The junctions first say where each of their
    arms starts to be drawn (cortes), then the profiles are built with that, then the junctions with the profiles."""
    m = osm.load('comuna')
    cfg = json.loads(SRC.read_text())
    ccfg = json.loads(CRUCES_SRC.read_text()) if CRUCES_SRC.exists() else {}
    E = ejes(m, cfg)
    cor = cortes(ccfg, E, cfg)
    perfiles = build(m, cfg, E, cor)
    return perfiles, cruces(ccfg, E, cfg, cor, perfiles)


def cmd_write():
    out, cr = todo()
    OUT.write_text(json.dumps(out, separators=(',', ':'), ensure_ascii=False))
    CRUCES_OUT.write_text(json.dumps(cr, separators=(',', ':'), ensure_ascii=False))
    for k, v in out.items():
        print(f'{k}: {v["largo"]:.0f} m (dibujado de {v["desde"]:.0f} a {v["hasta"]:.0f}), {len(v["calles"])} calles del mapa, '
              f'{len(v["bocas"])} bocas, {len(v["postes"])} postes, {len(v["faroles"])} faroles al medio, {len(v["hileras"])} árboles')
    for k, c in cr.items():
        print(f'cruce {k}: {len(c["suelo"])} superficies, {len(c["pintura"])} marcas, {len(c["objetos"])} objetos, {len(c["vanos"])} vanos')
    print(f'{OUT}: {OUT.stat().st_size / 1e3:.1f} KB; {CRUCES_OUT}: {CRUCES_OUT.stat().st_size / 1e3:.1f} KB')


def cmd_check():
    out, cr = todo()
    for k, c in cr.items():
        print(f'cruce {k}: ' + ', '.join(f'{b} desde s = {v["desde"]:.1f}' for b, v in c['brazos'].items()))
    for k, v in out.items():
        print(f'{k}: eje de {v["largo"]:.0f} m ({len(dec(v["eje"]))} puntos)')
        for sec in v['secciones']:
            o, e = mitad(sec, -1), mitad(sec, 1)
            print(f'  s {sec["s"][0]:5}–{sec["s"][1]:<5} calzada {o[0]:.1f} + {e[0]:.1f} m, cierres a {o[2]:.1f} y {e[2]:.1f} m; {sec["centro"]}')
        for c in v['calles']: print(f'  calle {c[0]:5} {c[5]}: s {c[1]:.0f}–{c[2]:.0f}, de {c[3]:+.1f} a {c[4]:+.1f} m')
        for b in v['bocas']: print(f'  boca s {b[0]:.0f}–{b[1]:.0f} {"izquierda" if b[2] < 0 else "derecha"}: {b[3]}')
        print(f'  {len(v["postes"])} postes, {len(v["paraderos"])} paraderos, {len(v["cebras"])} cebras, {len(v["lomos"])} lomos, '
              f'{len(v["semaforos"])} semáforos, {len(v["hileras"])} árboles')


def cmd_panel(clave, s0: float = 0, s1: float = 200, *, ancho: float = 20, z: int = 19, escala: int = 8, release=None):
    """panel CLAVE [s0 s1]: la imagen de Esri enderezada a lo largo del eje, con lo que dice el perfil encima."""
    from PIL import Image, ImageDraw
    import satellite
    m = osm.load('comuna')
    cfg = json.loads(SRC.read_text())
    if clave not in cfg: raise SystemExit(f'config/perfiles.json no tiene «{clave}»')
    E, E0 = ejes(m, {clave: cfg[clave]})[clave]
    pf = cfg[clave]
    s1 = min(s1, E.L)
    pts = [E.at(s, d)[0] for s in (s0, (s0 + s1) / 2, s1) for d in (-ancho, ancho)] + [p for p, s in zip(E.P, E.S) if s0 <= s <= s1]
    img, P = satellite.mosaic(min(p[0] for p in pts) - 5, max(p[0] for p in pts) + 5, min(p[1] for p in pts) - 5,
                              max(p[1] for p in pts) + 5, z, release)
    src = img.load()
    W, H = int(2 * ancho * escala), int((s1 - s0) * escala)
    out = Image.new('RGB', (W + 60, H + 20), 'white')
    px = out.load()
    for v in range(H):
        s = s1 - (v + 0.5) / escala
        (ax, ay), t = E.at(s)
        for u in range(W):
            d = -ancho + (u + 0.5) / escala
            x, y = P((ax + t[1] * d, ay - t[0] * d))
            if 0 <= x < img.width and 0 <= y < img.height: px[u + 50, v + 10] = src[int(x), int(y)]
    dr = ImageDraw.Draw(out)
    X = lambda d: 50 + (d + ancho) * escala
    Y = lambda s: 10 + (s1 - s) * escala
    # a line every 5 m of d (1 m ticks along the top and bottom) and every 10 m of s: the image stays readable
    for d in range(-int(ancho), int(ancho) + 1):
        for yy in (Y(s1), Y(s0) - 4):
            dr.line([X(d), yy, X(d), yy + 4], fill=(0, 0, 0))
        if d % 5 == 0:
            for v in range(int(Y(s1)), int(Y(s0)), 3): dr.point((X(d), v), fill=(255, 255, 0))
            dr.text((X(d) + 2, 0), f'{d:+d}', fill=(0, 0, 0))
    for s in range(int(s0 // 10 * 10), int(s1) + 1, 10):
        if s >= s0:
            for u in range(int(X(-ancho)), int(X(ancho)), 3): dr.point((u, Y(s)), fill=(255, 255, 0))
            dr.text((2, Y(s) - 6), f's {s}', fill=(0, 0, 0))
    # every 6 m of s: OSM's axis (cyan), and the edges the profile draws: carriageway (red), kerb (orange), fence (magenta)
    for k in range(int((s1 - s0) / 6) + 1):
        s = s0 + 3 + 6 * k
        if s > s1: break
        sec = seccion(pf, s)
        marcas = [(-corrimiento(pf, s), (0, 255, 255))] + [(lado * d, c) for lado in (-1, 1)
                  for d, c in zip(mitad(sec, lado), ((255, 0, 0), (255, 140, 0), (255, 0, 255)))]
        for d, c in marcas:
            if abs(d) <= ancho: dr.line([X(d), Y(s) - 6, X(d), Y(s) + 6], fill=c, width=2)
    f = ROOT / 'diagnostics' / f'perfil-{clave}-{s0:.0f}-{s1:.0f}.png'
    out.save(f)
    print(f'{f.relative_to(ROOT)}: {W}×{H} px, {escala} px por m; z{z} (satellite.py --fecha dice de cuándo es)')


COLORES = {'calzada': (90, 90, 88), 'vereda': (190, 186, 176), 'pasto': (111, 138, 69), 'tierra': (156, 134, 100),
           'solera': (230, 230, 230), 'solera-amarilla': (224, 181, 46), 'blanco': (255, 255, 255)}


def cmd_plano(clave, *, lado: float = 160, z: int = 19, escala: float = 3, alfa: int = 150, release=None):
    """plano CRUCE: lo que arma un cruce, dibujado sobre la imagen de Esri."""
    from PIL import Image, ImageDraw
    import satellite
    out, cr = todo()
    if clave not in cr: raise SystemExit(f'config/cruces.json no tiene «{clave}»')
    c = cr[clave]
    xs = [v for t, h, r in c['suelo'] for v in r[0::2]]; ys = [v for t, h, r in c['suelo'] for v in r[1::2]]
    cx, cy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
    img, P = satellite.mosaic(cx - lado / 2, cx + lado / 2, cy - lado / 2, cy + lado / 2, z, release)
    img = img.resize((int(img.width * escala), int(img.height * escala)), Image.LANCZOS).convert('RGBA')
    Q = lambda x, y: tuple(v * escala for v in P((x, y)))
    capa = Image.new('RGBA', img.size, (0, 0, 0, 0)); d = ImageDraw.Draw(capa)
    pares = lambda r: [Q(r[i], r[i + 1]) for i in range(0, len(r), 2)]
    for t, h, r in c['suelo']:
        d.polygon(pares(r), fill=COLORES.get(t, (200, 0, 200)) + (alfa,))
    for col, r in c['pintura']:
        d.polygon(pares(r), fill=(255, 255, 255, 255))
    for h0, h1, col, r in c['bordes']:
        d.line(pares(r), fill=(255, 140, 0, 255) if h1 > 0 else (255, 0, 255, 255), width=2)
    # the arms' bands near the junction: their carriageway (red) and fence (magenta) edges
    for k in c['brazos']:
        v = out[k]; E = Eje([(x / 10, y / 10) for x, y in dec(v['eje'])])
        for lado_ in (-1, 1):
            for j, col in ((0, (255, 0, 0, 255)), (2, (255, 0, 255, 255))):
                pts = [Q(*E.at(s, lado_ * mitad(seccion(v, s), lado_)[j])[0]) for s in range(int(v['desde']), int(min(v['desde'] + 70, v['largo'])))]
                d.line(pts, fill=col, width=1)
    for o in c['objetos']:
        if o[0] == 'cerco':
            d.line(pares(o[4]), fill=(0, 255, 255, 255), width=2); continue
        p = Q(o[1], o[2]); f = (math.cos(o[3]) * 12, -math.sin(o[3]) * 12)
        d.ellipse([p[0] - 4, p[1] - 4, p[0] + 4, p[1] + 4], outline=(255, 255, 0, 255), width=2)
        d.line([p, (p[0] + f[0], p[1] + f[1])], fill=(255, 255, 0, 255), width=2)
        d.text((p[0] + 5, p[1] + 3), o[0][:4], fill=(255, 255, 0, 255))
    for pa, pb, n in c['vanos']:
        d.line([Q(pa[0], pa[1]), Q(pb[0], pb[1])], fill=(0, 0, 0, 255), width=1)
    img = Image.alpha_composite(img, capa).convert('RGB')
    f = ROOT / 'diagnostics' / f'cruce-{clave}.png'
    img.save(f)
    print(f'{f.relative_to(ROOT)}: {img.size[0]}×{img.size[1]} px, {escala / (P((1, 0))[0] - P((0, 0))[0]) if False else ""}z{z}')


if __name__ == '__main__':
    cli.run({'write': cmd_write, 'check': cmd_check, 'panel': cmd_panel, 'plano': cmd_plano}, __doc__, default=cmd_write)
