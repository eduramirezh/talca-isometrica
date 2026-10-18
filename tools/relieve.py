"""Compara dos versiones de data/elevation.json: lo que el cambio de modelo de elevación mueve en la maqueta.

  python tools/relieve.py <antes.json> <después.json>
  git show HEAD:data/elevation.json > /tmp/antes.json && python tools/relieve.py /tmp/antes.json data/elevation.json

Imprime, sobre los nodos dentro de la comuna:
  - la diferencia de altura relativa a la plaza (real y exagerada con relief(), como 25-terrain.js), por zonas;
  - el matorral de la pendiente real (EW, el wildAt de 25-terrain.js: la misma pendiente y el mismo umbral), en km²;
  - la altura sobre la plaza de algunos puntos de referencia (el santuario del Cerro, la Estación, el Claro…).
Con --png <archivo> dibuja además la diferencia real sin su mediana (el cambio de la plaza, que mueve todo; rojo:
sube, azul: baja; ±5 m satura) y el matorral que aparece (verde) o desaparece (magenta) (requiere Pillow:
uv run --with pillow python tools/relieve.py …).
"""
import json, math, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent / 'pipeline'))
from common import comuna, in_ring

RELIEF_A, RELIEF_K = 3, 50                       # los de 25-terrain.js
relief = lambda d: math.copysign(RELIEF_A * RELIEF_K * math.log1p(abs(d) / RELIEF_K), d)
POINTS = {'santuario del Cerro': (-3401, 118), 'cumbre norte del Cerro': (-3237, 929), 'Estación': (1500, -100),
          'Río Claro, puentes': (-1580, 525), 'Viejas Cochinas': (-1696, 788), 'Alameda (4 Norte)': (0, 540), 'Colegio De La Salle': (0, 410),
          'Ruta 5 en el Lircay': (4100, 3680), 'Ruta 5 en el Piduco': (2330, -1850)}

def load(p):
    d = json.load(open(p)); nx, ny = d['n']; v = 0; R = []
    for x in d['h']: v += x; R.append(v / 10)
    return d, nx, ny, R

def wild(nx, ny, R, S):
    node = lambda i, j: min(ny - 1, max(0, j)) * nx + min(nx - 1, max(0, i))
    s = [math.hypot(R[node(i + 1, j)] - R[node(i - 1, j)], R[node(i, j + 1)] - R[node(i, j - 1)]) / (2 * S)
         for j in range(ny) for i in range(nx)]
    out = []
    for j in range(ny):
        for i in range(nx):
            m = sum(s[node(i + di, j + dj)] for dj in (-1, 0, 1) for di in (-1, 0, 1)) / 9
            t = max(0, min(1, (m - 0.04) / 0.07)); out.append(t * t * (3 - 2 * t))
    return out

def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    if len(args) < 2: raise SystemExit(__doc__)
    (da, nx, ny, Ra), (db, nx2, ny2, Rb) = load(args[0]), load(args[1])
    if (nx, ny, da['o'], da['s']) != (nx2, ny2, db['o'], db['s']): raise SystemExit('las dos grillas no coinciden')
    x0, y0 = da['o']; S = da['s']; RING = comuna()
    xy = lambda k: (x0 + (k % nx) * S, y0 + (k // nx) * S)
    mask = [in_ring(xy(k), RING) for k in range(nx * ny)]
    Wa, Wb = wild(nx, ny, Ra, S), wild(nx, ny, Rb, S)
    print(f"plaza: {da['z0']} -> {db['z0']} m s.n.m.; {sum(mask)} nodos en la comuna")
    zones = {'ciudad (|x|, |y| < 2,5 km)': lambda x, y: abs(x) < 2500 and abs(y) < 2500,
             'cerros del poniente (x < −2 km)': lambda x, y: x < -2000,
             'el resto del campo': lambda x, y: x >= -2000 and not (abs(x) < 2500 and abs(y) < 2500)}
    km2 = S * S / 1e6
    for name, f in zones.items():
        ks = [k for k in range(nx * ny) if mask[k] and f(*xy(k))]
        d = sorted(Rb[k] - Ra[k] for k in ks); de = sorted(relief(Rb[k]) - relief(Ra[k]) for k in ks)
        q = lambda a, p: a[min(len(a) - 1, int(p * len(a)))]
        print(f'{name}: {len(ks)} nodos')
        print(f'  altura real sobre la plaza, después − antes: media {sum(d)/len(d):+.1f} m, p5 {q(d,.05):+.1f}, p95 {q(d,.95):+.1f}')
        print(f'  en la maqueta (relief): media {sum(de)/len(de):+.1f} m, p5 {q(de,.05):+.1f}, p95 {q(de,.95):+.1f}')
        print(f'  matorral (EW > 0,5): {sum(1 for k in ks if Wa[k] > .5) * km2:.2f} -> {sum(1 for k in ks if Wb[k] > .5) * km2:.2f} km²; '
              f'EW medio {sum(Wa[k] for k in ks)/len(ks):.3f} -> {sum(Wb[k] for k in ks)/len(ks):.3f}')
    print('sobre la plaza (real; en la maqueta):')
    for name, (x, y) in POINTS.items():
        k = round((y - y0) / S) * nx + round((x - x0) / S)
        print(f'  {name:24s} {Ra[k]:7.1f} -> {Rb[k]:7.1f} m   ({relief(Ra[k]):6.1f} -> {relief(Rb[k]):6.1f})')
    if '--png' in sys.argv:
        from PIL import Image
        out = sys.argv[sys.argv.index('--png') + 1]
        im = Image.new('RGB', (nx, ny), (240, 240, 235)); px = im.load()
        med = sorted(Rb[k] - Ra[k] for k in range(nx * ny) if mask[k])[sum(mask) // 2]
        for k in range(nx * ny):
            if not mask[k]: continue
            i, j = k % nx, ny - 1 - k // nx; d = max(-1, min(1, (Rb[k] - Ra[k] - med) / 5))
            c = (255, int(255 * (1 - d)), int(255 * (1 - d))) if d > 0 else (int(255 * (1 + d)), int(255 * (1 + d)), 255)
            if Wb[k] > .5 >= Wa[k]: c = (40, 160, 60)
            elif Wa[k] > .5 >= Wb[k]: c = (200, 40, 200)
            px[i, j] = c
        im.save(out); print(f'{out} (mediana {med:+.1f} m)')

if __name__ == '__main__':
    main()
