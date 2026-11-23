"""Los perfiles de calles medidos en fotos (config/perfiles.json), completados con OSM y el mapa: data/perfiles.json, que
leen la página (DATA.perfiles: src/js/12-perfiles.js dibuja las bandas sobre la calle y ensancha las del mapa hasta sus
líneas de cierre) y la maqueta en 3D (modelo3d/modelos/las_rastras.gd, de la copia en modelo3d/datos/ que hace
make modelo3d: la calle de cerca, con soleras, pintura, postes y paraderos). Hoy, uno: la Avenida Las Rastras.

  python pipeline/perfiles.py            -> data/perfiles.json (requiere raw/osm/map-comuna.json y data/geometry.json)
  python pipeline/perfiles.py check      -> lo mismo sin escribir: cada sección con sus anchos, las calles del mapa que
                                            toma, los cruces y los postes

Lo que agrega a cada perfil de config/perfiles.json:
  eje      el eje en metros de grilla (polilínea codificada en delta, de a 0,1 m): las vías de OSM de «osm» encadenadas;
           un par [ida, vuelta] (dos calzadas de un sentido) aporta la línea del medio entre las dos
  largo    el largo del eje (m); s va de 0 a largo
  calles   [[i, s0, s1, a, b], …]: las calles del mapa (índice en data/geometry.json) que son la avenida (su nombre,
           y todos sus puntos a menos de 12 m del eje): la página reemplaza cada una por el tramo del eje de s0 a s1,
           corrido para que su calle y su margen de lotes (WALK_OUT) cubran de a a b (m a la derecha del eje; a < 0
           a la izquierda): de una línea de cierre a la otra, o en un par, de su lado hasta el medio
  bocas    [[s0, s1, lado], …]: donde llega una calle del mapa (lado -1 izquierda, 1 derecha), de solera a solera más
           1 m de redondeo: ahí no van soleras, veredas, pasto ni la línea de borde, y el bandejón se abre si llega de
           los dos lados
  postes   [[x, y, nx, ny], …]: los postes de la luz y los cables (n: hacia la calzada, el brazo del farol), cada «paso»
           m del lado de «postes» de cada sección, en su borde exterior de la solera (o a 1 m de la calzada sin
           solera), sin caer en una boca
  paraderos [[x, y, nx, ny, tipo], …], cebras [[s, x, y, tx, ty, ancho]], lomos [[s, x, y, tx, ty, ancho]],
  semaforos [[x, y, nx, ny], …] (uno en cada esquina derecha de la avenida), hileras [[x, y, especie], …]: los
           puntos de cada cosa, ya en metros de grilla

Los anchos de las secciones son estimados en las fotos (config/perfiles.json dice de cuáles); las calles del mapa son
las del grafo de cicloconecta (data/geometry.json), y si cambian (make data) hay que correr esto de nuevo: la página
revisa el nombre de cada calle que toma y avisa si no calza.
"""
import json, math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cli, osm
from common import CONFIG, DATA
from geom import dec, enc, seg_point


def seg_t(p, a, b):
    """The point of segment ab nearest to p, and its parameter t (0 at a, 1 at b)."""
    dx, dy = b[0] - a[0], b[1] - a[1]
    L = dx * dx + dy * dy or 1e-9
    t = max(0.0, min(1.0, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / L))
    return (a[0] + t * dx, a[1] + t * dy), t

SRC, OUT = CONFIG / 'perfiles.json', DATA / 'perfiles.json'
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
                best = (d, self.S[i] + t * L, -cr)
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


def eje_de(m, spec):
    """The axis of a profile: its two-way ways in order; a pair [ida, vuelta] gives the line midway between them."""
    P = []
    for it in spec:
        if isinstance(it, int):
            P += [q for q in chain(m, [it], P[-1] if P else None) if not P or math.dist(P[-1], q) > 0.3]
            continue
        ida = chain(m, it[0], P[-1] if P else None)
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


def build():
    m = osm.load('comuna')
    g = json.loads((DATA / 'geometry.json').read_text())
    cfg = json.loads(SRC.read_text())
    out = {}
    for key, pf in cfg.items():
        if key.startswith('_'): continue
        E = eje_de(m, pf['osm'])
        secs = pf['secciones']
        assert secs[0]['s'][0] == 0 and all(a['s'][1] == b['s'][0] for a, b in zip(secs, secs[1:])), f'{key}: secciones con huecos'
        secs[-1]['s'][1] = round(E.L)
        # the map's streets that are the avenue, and the side streets that reach it
        calles, bocas = [], []
        for i, (c, ni, enc_pts) in enumerate(g['streets']):
            P = dec(enc_pts)
            name = g['names'][ni]
            pr = [E.proj(p) for p in P]
            if name == pf['nombre'] and all(abs(d) < CERCA and -2 < s < E.L + 2 for s, d in pr):
                s0, s1 = max(0.0, min(s for s, _ in pr)), min(E.L, max(s for s, _ in pr))
                dm = sum(d for _, d in pr) / len(pr)
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
        def punto(s, lado, d):
            """[x, y, nx, ny]: d m to side `lado` of the axis at s, with n pointing back to the axis."""
            (x, y), t = E.at(s, lado * d)
            return [round(x, 2), round(y, 2), round(-lado * t[1], 3), round(lado * t[0], 3)]
        # poles: at the back of the kerb (or 1 m off the carriageway without one), out of the side streets' mouths
        postes = []
        for sec in secs:
            lado = -1 if sec.get('postes', 'O') == 'O' else 1
            s = sec['s'][0] + sec.get('paso', 35) / 2
            while s < sec['s'][1]:
                if not boca(s, lado, 2.5):
                    calz, sol, _ = mitad(sec, lado)
                    postes.append(punto(s, lado, (sol + 0.45) if sol > calz else calz + 1.0))
                s += sec.get('paso', 35)
        paraderos = []
        for s, l, tipo in pf.get('paraderos', []):
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
                if not boca(s, lado, 3):
                    hileras.append(punto(s, lado, d)[:2] + [esp])
                s += paso
        out[key] = {
            'nombre': pf['nombre'], 'fuente': pf['fuente'], 'eje': enc(E.P, 10), 'largo': round(E.L, 1),
            'secciones': secs, 'calles': calles, 'bocas': bocas, 'postes': postes, 'paraderos': paraderos,
            'cebras': [cruza(s) for s in pf.get('cebras', [])], 'lomos': [cruza(s) for s in pf.get('lomos', [])],
            'semaforos': semaforos, 'achurados': pf.get('achurados', []), 'hileras': hileras}
    return out


def cmd_write():
    out = build()
    OUT.write_text(json.dumps(out, separators=(',', ':'), ensure_ascii=False))
    for k, v in out.items():
        print(f'{k}: {v["largo"]:.0f} m, {len(v["calles"])} calles del mapa, {len(v["bocas"])} bocas, {len(v["postes"])} postes, '
              f'{len(v["hileras"])} árboles')
    print(f'{OUT}: {OUT.stat().st_size / 1e3:.1f} KB')


def cmd_check():
    for k, v in build().items():
        print(f'{k}: eje de {v["largo"]:.0f} m ({len(dec(v["eje"]))} puntos)')
        for sec in v['secciones']:
            o, e = mitad(sec, -1), mitad(sec, 1)
            print(f'  s {sec["s"][0]:5}–{sec["s"][1]:<5} calzada {o[0]:.1f} + {e[0]:.1f} m, cierres a {o[2]:.1f} y {e[2]:.1f} m; {sec["centro"]}')
        for c in v['calles']: print(f'  calle {c[0]:5} {c[5]}: s {c[1]:.0f}–{c[2]:.0f}, de {c[3]:+.1f} a {c[4]:+.1f} m')
        for b in v['bocas']: print(f'  boca s {b[0]:.0f}–{b[1]:.0f} {"izquierda" if b[2] < 0 else "derecha"}: {b[3]}')
        print(f'  {len(v["postes"])} postes, {len(v["paraderos"])} paraderos, {len(v["cebras"])} cebras, {len(v["lomos"])} lomos, '
              f'{len(v["semaforos"])} semáforos, {len(v["hileras"])} árboles')


if __name__ == '__main__':
    cli.run({'write': cmd_write, 'check': cmd_check}, __doc__, default=cmd_write)
