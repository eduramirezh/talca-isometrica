"""El sentido del tránsito de las calles de un solo sentido, de OpenStreetMap: data/sentidos.json, que tools/export.py
--letreros pasa a la página para que la placa de cada calle en los letreros del juego (juego/letreros.gd) lleve su
flecha, como las del centro de Talca (fotos de 2005 a 2017: un módulo con la flecha junto al nombre).

  python pipeline/sentidos.py          -> data/sentidos.json (requiere raw/osm/map-comuna.json: make osm)
  python pipeline/sentidos.py stats    -> cuántas vías y kilómetros de un sentido hay, por clase de calle

Va una vía de OSM si su highway es de las calles del mapa (CLS de process_geometry.py: de trunk a service) y su oneway
dice que es de un sentido (yes, true o 1; -1 o reverse, al revés de sus nodos) o es una rotonda (junction=roundabout o
circular, de un sentido aunque no lo diga, salvo oneway=no). Las de sentido variable (alternating, reversible) no van.

Formato: {"v": [[x0, y0, dx1, dy1, …], …]}: cada vía como polilínea en metros de grilla, codificada en delta (geom.enc,
enteros de 1 m) y en el sentido del tránsito. Los datos son de OSM: ODbL, como data/geometry.json.
"""
import json, math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cli, osm
from common import DATA
from geom import enc
from process_geometry import CLS

OUT = DATA / 'sentidos.json'
ADELANTE, ATRAS = {'yes', 'true', '1'}, {'-1', 'reverse'}


def sentido(t):
    """Las etiquetas de una vía -> 1 (el tránsito va en el orden de sus nodos), -1 (al revés) o 0 (los dos, o no se sabe)."""
    if t.get('highway') not in CLS: return 0
    o = t.get('oneway', '').lower()
    if o in ADELANTE: return 1
    if o in ATRAS: return -1
    if o == '' and t.get('junction') in ('roundabout', 'circular'): return 1
    return 0


def vias():
    """[(clase, puntos en el sentido del tránsito)] de las vías de un sentido de raw/osm/map-comuna.json."""
    m = osm.load('comuna')
    out = []
    for w in m.W.values():
        t = w.get('tags', {})
        s = sentido(t)
        p = m.pts(w)
        if s and len(p) > 1: out.append((CLS[t['highway']], p if s > 0 else p[::-1]))
    return out


def cmd_write():
    v = vias()
    OUT.write_text(json.dumps({'v': [enc(p) for _, p in v]}, separators=(',', ':')))
    print(f'{OUT}: {len(v)} vías de un sentido, {OUT.stat().st_size / 1e3:.0f} KB')


def cmd_stats():
    por = {}
    for c, p in vias():
        n, km = por.get(c, (0, 0.0))
        por[c] = (n + 1, km + sum(math.dist(a, b) for a, b in zip(p, p[1:])) / 1000)
    nombres = {v: k for k, v in CLS.items() if not k.endswith('_link')}
    for c in sorted(por): print(f'  clase {c} ({nombres.get(c, "?")}): {por[c][0]} vías, {por[c][1]:.1f} km')


if __name__ == '__main__':
    cli.run({'write': cmd_write, 'stats': cmd_stats}, __doc__, default=cmd_write)
