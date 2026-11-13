"""Lo de OpenStreetMap que el juego (juego/modelos/) necesita alrededor de la Plaza de Armas, en metros de grilla.

  python3 tools/juego_osm.py            # raw/osm/map-comuna.json (make osm) -> juego/modelos/entorno/osm.json
  python3 tools/juego_osm.py --lista    # además imprime cada edificio y nodo, para elegir qué modelar

Escribe los edificios que tocan la caja ENTORNO (las cuatro caras de manzana frente a la plaza y las esquinas), con su
contorno (x, y de grilla: x al oriente, y al norte; en Godot X = x, Z = -y) y las etiquetas que sirven para modelarlos
(nombre, pisos, altura, dirección), y los nodos de la calle: semáforos, cruces, paraderos, árboles, hidrantes. Lo lee
juego/modelos/entorno/plano.gd. Solo biblioteca estándar. Los datos son © colaboradores de OpenStreetMap (ODbL 1.0).
"""
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / 'pipeline'))
import common  # noqa: E402

ENTORNO = (-140, 140, -140, 135)   # x0, x1, y0, y1: la caja de lo que modela juego/modelos/
TAGS = ('name', 'old_name', 'building', 'building:levels', 'height', 'addr:street', 'addr:housenumber', 'amenity',
        'shop', 'office', 'brand', 'man_made', 'layer', 'roof:shape', 'roof:colour', 'building:colour')
NODOS = {'highway': ('traffic_signals', 'crossing', 'bus_stop', 'street_lamp', 'give_way', 'stop'),
         'natural': ('tree',), 'emergency': ('fire_hydrant',), 'amenity': ('bench', 'waste_basket', 'bicycle_parking',
                                                                          'telephone', 'post_box', 'taxi')}


def dentro(x, y, m=0):
    return ENTORNO[0] - m <= x <= ENTORNO[1] + m and ENTORNO[2] - m <= y <= ENTORNO[3] + m


def main():
    src = ROOT / 'raw' / 'osm' / 'map-comuna.json'
    common.require(src, 'Ejecute primero: make osm')
    els = json.load(open(src))['elements']
    pos = {e['id']: common.loc(e['lon'], e['lat']) for e in els if e['type'] == 'node'}
    out = {'fuente': '© colaboradores de OpenStreetMap (ODbL 1.0), raw/osm/map-comuna.json', 'caja': ENTORNO,
           'edificios': [], 'nodos': [], 'vias': []}
    for e in els:
        t = e.get('tags', {})
        if e['type'] == 'node':
            x, y = pos[e['id']]
            if not dentro(x, y):
                continue
            for k, vs in NODOS.items():
                if t.get(k) in vs:
                    n = {'id': e['id'], 'tipo': t[k], 'x': round(x, 2), 'y': round(y, 2)}
                    for kk in ('crossing', 'species', 'genus', 'leaf_type', 'name', 'traffic_signals:direction'):
                        if kk in t:
                            n[kk] = t[kk]
                    out['nodos'].append(n)
            continue
        if e['type'] != 'way':
            continue
        pts = [pos[n] for n in e['nodes'] if n in pos]
        if not pts or not any(dentro(x, y) for x, y in pts):
            continue
        ring = [[round(x, 2), round(y, 2)] for x, y in pts]
        if 'building' in t or 'building:part' in t:
            if ring[0] == ring[-1]:
                ring = ring[:-1]
            out['edificios'].append({'id': e['id'], 'tags': {k: t[k] for k in TAGS if k in t}, 'anillo': ring})
        elif 'highway' in t:
            out['vias'].append({'id': e['id'], 'highway': t['highway'], 'name': t.get('name', ''),
                                'footway': t.get('footway', ''), 'puntos': ring})
    dst = ROOT / 'juego' / 'modelos' / 'entorno' / 'osm.json'
    dst.parent.mkdir(parents=True, exist_ok=True)
    dst.write_text(json.dumps(out, ensure_ascii=False, separators=(',', ':')))
    print(f'{dst.relative_to(ROOT)}: {len(out["edificios"])} edificios, {len(out["nodos"])} nodos, {len(out["vias"])} vías')
    if '--lista' in sys.argv:
        for b in out['edificios']:
            xs = [p[0] for p in b['anillo']]; ys = [p[1] for p in b['anillo']]
            print(f"w{b['id']} x[{min(xs):.0f},{max(xs):.0f}] y[{min(ys):.0f},{max(ys):.0f}] {b['tags']}")
        for n in out['nodos']:
            print(n)


if __name__ == '__main__':
    main()
