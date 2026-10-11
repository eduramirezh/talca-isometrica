"""Paneles de diagnóstico (PNG) para trazar o revisar ríos, vía férrea y Ruta 5.

Dibuja las manzanas del Censo (rosado = con datos, celeste = sin información), las calles OSM
(gris; troncales en rojo) y los trazados de config/trazados.json (azul), con una grilla de
lat/lon fina para leer coordenadas. Los ríos se trazaron mirando estos paneles: un río aparece
como un hueco continuo entre manzanas.

  python pipeline/diagnostics.py                 # todos los paneles -> diagnostics/
  python pipeline/diagnostics.py centro          # un panel
  python pipeline/diagnostics.py -71.70 -71.66 -35.445 -35.412   # caja libre (lon0 lon1 lat0 lat1)
Requiere matplotlib y numpy.
"""
import json, sys
import matplotlib; matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np
from matplotlib.collections import PolyCollection, LineCollection
from common import ROOT, MANZANAS_DIR, NAV_GRAPH, CONFIG, require

VIEWS = {  # lon0, lon1, lat0, lat1
    'ciudad': (-71.72, -71.58, -35.475, -35.37),
    'noroeste': (-71.70, -71.62, -35.425, -35.375),
    'poniente': (-71.715, -71.66, -35.46, -35.41),
    'sur': (-71.68, -71.60, -35.465, -35.425),
    'estacion': (-71.665, -71.62, -35.46, -35.395),
    'centro': (-71.695, -71.655, -35.445, -35.412),
}

def main(views):
    blocks = []
    for fn, c in [('R07_MANZANA_IND_C17', '#e8c8d8'), ('R07_MANZANA_SIN_INF_C17', '#bcd'), ('R07_MANZANA_ALDEA_C17', '#cdb')]:
        for f in json.load(open(require(MANZANAS_DIR / f'{fn}.shp.geojson')))['features']:
            if f['properties'].get('NOM_COMUNA') not in ('TALCA', 'MAULE', 'PENCAHUE', 'SAN CLEMENTE'): continue
            g = f['geometry']
            for p in (g['coordinates'] if g['type'] == 'MultiPolygon' else [g['coordinates']]): blocks.append((p[0], c))
    g = json.load(open(require(NAV_GRAPH)))
    N = {n['id']: (n['lon'], n['lat']) for n in g['nodes']}
    thin, major, trunk = [], [], []
    for e in g['edges']:
        seg = [N[e['u']], N[e['v']]]
        (trunk if e['highway'].startswith('trunk') else major if e['highway'] in ('primary', 'secondary') else thin).append(seg)
    tz = json.load(open(CONFIG / 'trazados.json'))
    traces = [v['puntos'] for v in tz['rios'].values() if 'puntos' in v] + [tz['ferrocarril']['puntos'], tz['ruta5']['puntos']]
    out = ROOT / 'diagnostics'; out.mkdir(exist_ok=True)
    for name, (x0, x1, y0, y1) in views.items():
        fig, ax = plt.subplots(figsize=(16, 16*(y1-y0)/((x1-x0)*0.815)), dpi=90)
        ax.add_collection(PolyCollection([p for p, _ in blocks], facecolors=[c for _, c in blocks], edgecolors='#a88', linewidths=0.2))
        ax.add_collection(LineCollection(thin, colors='#777', linewidths=0.3))
        ax.add_collection(LineCollection(major, colors='#222', linewidths=1))
        ax.add_collection(LineCollection(trunk, colors='red', linewidths=1.6))
        for t in traces: ax.plot([p[1] for p in t], [p[0] for p in t], color='#1f5fd6', lw=2, alpha=.8)
        step = 0.0025 if (x1 - x0) > 0.05 else 0.001
        ax.set_xlim(x0, x1); ax.set_ylim(y0, y1); ax.set_aspect(1/0.815)
        ax.set_xticks(np.arange(x0, x1+1e-9, step)); ax.set_yticks(np.arange(y0, y1+1e-9, step))
        ax.grid(True, lw=0.4, color='#48f', alpha=0.6)
        plt.xticks(rotation=90, fontsize=7); plt.yticks(fontsize=7)
        fn = out / f'panel_{name}.png'; plt.savefig(fn, bbox_inches='tight'); plt.close(); print(fn)

if __name__ == '__main__':
    a = sys.argv[1:]
    if len(a) == 4: main({'caja': tuple(map(float, a))})
    elif a: main({k: VIEWS[k] for k in a})
    else: main(VIEWS)
