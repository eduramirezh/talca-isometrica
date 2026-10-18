"""Las huellas de edificios por aprendizaje automático y las alturas de Google 2.5D, en archivos simples para
pipeline/edificios.py (que es de biblioteca estándar): raw/edificios-ml/ (METODOLOGIA §14).

  uv run --with duckdb --with shapely --with numpy --with rasterio --with pyproj python -I tools/ml_buildings.py

Lee lo bajado y recortado a la caja de la comuna (raw/eval/buildings.md dice de dónde sale cada archivo):
  raw/overture/talca-buildings-<release>.parquet         Overture Maps, tema buildings: las filas de Microsoft y Google
  raw/msbuildings/talca-ms-buildings.geojsonl            Microsoft Global ML Building Footprints (la descarga pública)
  raw/google-open-buildings/talca-open-buildings-v3.geojsonl   Google Open Buildings v3, con su confianza
  raw/google-open-buildings-temporal/talca-urbano-2023-2m.tif  Google Open Buildings 2.5D Temporal (alto y presencia)
  raw/google-open-buildings-temporal/talca-urbano-2016-2m.tif  (UTM 19S, 2 m, la ventana urbana)
y escribe, con el centro de cada huella dentro de la comuna:
  raw/edificios-ml/huellas.jsonl   una línea por fila de aprendizaje automático de Overture (Overture ya quitó las que
      pisan un edificio de su OSM y las de Google que pisan una de Microsoft): {"id": GERS, "f": "ms" | "google",
      "c": confianza, "r": [anillo, …] en [lon, lat], "g8": 1 si es de Microsoft y una de Google v3 con confianza
      >= 0,8 cubre al menos un 30 % de la menor de las dos, "h": la mediana del alto de 2023 dentro de la huella (m)
      o null fuera de la ventana, "p16", "p23": la presencia máxima dentro de la huella en 2016 y 2023}
  raw/edificios-ml/ajuste-ms.jsonl, ajuste-google.jsonl   las huellas de los archivos de Microsoft y de Google v3
      (>= 0,8) cerca de un edificio de OSM, {"r": anillo}: edificios.py mide con ellas el corrimiento de cada fuente
      contra OSM (Overture ya quitó justo esas)
  raw/edificios-ml/alturas-osm.json   {id de OSM: [alto, p16, p23]} de cada edificio de OSM dentro de la ventana
  raw/edificios-ml/fuente.json        las versiones, los conteos y los corrimientos con que se muestrearon los altos
El alto se muestrea con la huella corrida a OSM (edificios.shifts(), el mismo corrimiento que aplica edificios.py).
Luego: make edificios build. Los archivos descargados son datos no confiables: se corre con python -I.
"""
import json, sys, time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / 'pipeline'))
from common import RAW, loc, unloc, comuna, in_ring
import edificios as E

OUT = RAW / 'edificios-ml'
TEMPORAL = RAW / 'google-open-buildings-temporal'

def lonlat_rings(geom):
    """Un Polygon o MultiPolygon de shapely -> [[anillo exterior, hueco, …], …] en [lon, lat] con 7 decimales."""
    polys = getattr(geom, 'geoms', [geom])
    r = lambda c: [[round(x, 7), round(y, 7)] for x, y in c.coords]
    return [[r(p.exterior)] + [r(i) for i in p.interiors] for p in polys]

def grid(ring): return [loc(x, y) for x, y in ring]

def centroid(ring): return (sum(p[0] for p in ring) / len(ring), sum(p[1] for p in ring) / len(ring))

def main():
    import duckdb, shapely, numpy as np
    from shapely.geometry import shape
    from shapely.strtree import STRtree
    t0 = time.time(); OUT.mkdir(exist_ok=True)
    CM = comuna()
    in_cm = lambda ring: in_ring(centroid(grid(ring)), CM)
    pq = sorted((RAW / 'overture').glob('talca-buildings-*.parquet'))[-1]
    rel = pq.stem.replace('talca-buildings-', '')
    con = duckdb.connect(); con.execute('INSTALL spatial; LOAD spatial;')
    rows = con.execute("select id, sources[1].dataset, sources[1].confidence, sources[1].version, ST_AsWKB(geometry) "
                       "from read_parquet(?) where sources[1].dataset <> 'OpenStreetMap'", [str(pq)]).fetchall()
    ml, ver = [], {}
    for gid, ds, conf, v, wkb in rows:
        g = shapely.from_wkb(bytes(wkb)); f = 'ms' if ds.startswith('Microsoft') else 'google'
        for part in getattr(g, 'geoms', [g]):
            rings = lonlat_rings(part)[0]
            if in_cm(rings[0]): ml.append({'id': gid, 'f': f, 'c': None if conf is None else round(conf, 3), 'r': rings, 'g': part})
        ver[f] = v
    print(f'Overture {rel}: {sum(m["f"] == "ms" for m in ml)} de Microsoft y {sum(m["f"] == "google" for m in ml)} de Google en la comuna')

    # Google v3 >= 0,8: la segunda opinión sobre cada huella de Microsoft
    G8 = []
    for l in open(RAW / 'google-open-buildings' / 'talca-open-buildings-v3.geojsonl'):
        d = json.loads(l)
        if d['properties']['confidence'] >= 0.8: G8.append(shape(d['geometry']))
    tree = STRtree(G8)
    for m in ml:
        if m['f'] != 'ms': continue
        g = m['g']; best = 0
        for j in tree.query(g):
            o = G8[j]
            if o.intersects(g): best = max(best, g.intersection(o).area / min(g.area, o.area))
        m['g8'] = int(best >= 0.3)
    print(f'  {sum(m.get("g8", 0) for m in ml)} de Microsoft confirmadas por Google v3 >= 0,8')

    # las huellas de los archivos crudos cerca de un edificio de OSM, para medir el corrimiento
    bld = E.osm()[0]; cells = set()
    for _, rings, _ in bld:
        xs = [p[0] for p in rings[0]]; ys = [p[1] for p in rings[0]]
        for gx in range(int((min(xs) - 5) // 10), int((max(xs) + 5) // 10) + 1):
            for gy in range(int((min(ys) - 5) // 10), int((max(ys) + 5) // 10) + 1): cells.add((gx, gy))
    def near_osm(ring):
        c = centroid(grid(ring)); return (int(c[0] // 10), int(c[1] // 10)) in cells
    for name, path, ok in (('ms', RAW / 'msbuildings' / 'talca-ms-buildings.geojsonl', lambda p: True),
                           ('google', RAW / 'google-open-buildings' / 'talca-open-buildings-v3.geojsonl', lambda p: p['confidence'] >= 0.8)):
        n = 0
        with open(OUT / f'ajuste-{name}.jsonl', 'w') as fo:
            for l in open(path):
                d = json.loads(l)
                if not ok(d['properties']) or d['geometry']['type'] != 'Polygon': continue
                ring = [[round(x, 7), round(y, 7)] for x, y, *_ in d['geometry']['coordinates'][0]]
                if near_osm(ring): fo.write(json.dumps({'r': ring}) + '\n'); n += 1
        print(f'  ajuste-{name}.jsonl: {n} huellas cerca de un edificio de OSM')
    sh = E.shifts(bld)
    print('  corrimiento contra OSM (x, y en m de grilla; lo que se resta):', {k: (round(v[0], 2), round(v[1], 2), v[2]) for k, v in sh.items()})

    # los altos y la presencia de Google 2.5D Temporal, con la huella corrida a OSM
    import rasterio
    from rasterio.features import geometry_mask
    from rasterio.windows import Window, from_bounds
    from pyproj import Transformer
    T = Transformer.from_crs(4326, 32719, always_xy=True)
    ds = {y: rasterio.open(TEMPORAL / f'talca-urbano-{y}-2m.tif') for y in ('2016', '2023')}
    A = {y: d.read() for y, d in ds.items()}; d0 = ds['2023']
    assert all(d.transform == d0.transform and d.shape == d0.shape for d in ds.values())
    def utm(gring):
        lat, lon = zip(*(unloc(x, y) for x, y in gring)); e, n = T.transform(lon, lat); return shapely.Polygon(list(zip(e, n)))
    def sample(gring):
        """(mediana del alto en 2023, presencia máxima 2016, 2023) dentro del anillo (metros de grilla), o None."""
        g = utm(gring)
        if not g.is_valid: g = g.buffer(0)
        if g.is_empty: return None
        w = from_bounds(*g.bounds, d0.transform).round_offsets().round_lengths()
        r0, c0 = int(w.row_off), int(w.col_off); h, wd = max(1, int(w.height) + 1), max(1, int(w.width) + 1)
        if r0 < 0 or c0 < 0 or r0 + h > d0.height or c0 + wd > d0.width: return None
        tr = rasterio.windows.transform(Window(c0, r0, wd, h), d0.transform)
        m = ~geometry_mask([g], (h, wd), tr, all_touched=False)
        if not m.any(): m = ~geometry_mask([g], (h, wd), tr, all_touched=True)
        hh = A['2023'][0][r0:r0+h, c0:c0+wd][m]; ok = hh > -99
        if not ok.any(): return None
        p16 = A['2016'][1][r0:r0+h, c0:c0+wd][m]; p23 = A['2023'][1][r0:r0+h, c0:c0+wd][m]
        return round(float(np.median(hh[ok])), 1), round(float(p16[p16 > -99].max(initial=0)), 2), round(float(p23[ok].max()), 2)
    nh = 0
    with open(OUT / 'huellas.jsonl', 'w') as fo:
        for m in ml:
            dx, dy, _ = sh[m['f']]
            s = sample([(x - dx, y - dy) for x, y in grid(m['r'][0])])
            m['h'], m['p16'], m['p23'] = s if s else (None, None, None); nh += s is not None
            del m['g']; fo.write(json.dumps(m, separators=(',', ':')) + '\n')
    alt = {}
    for oid, rings, _ in bld:
        s = sample(rings[0])
        if s: alt[oid] = list(s)
    (OUT / 'alturas-osm.json').write_text(json.dumps(alt, separators=(',', ':')))
    (OUT / 'fuente.json').write_text(json.dumps({
        'overture': rel, 'versiones': ver, 'google_v3': 'v3 (2023-05)', 'temporal': 'Google Open Buildings 2.5D Temporal v1, 2016-06-30 y 2023-06-30',
        'huellas': len(ml), 'con_alto': nh, 'osm_con_alto': len(alt),
        'corrimiento': {k: [round(v[0], 2), round(v[1], 2), v[2]] for k, v in sh.items()}}, indent=1, ensure_ascii=False))
    print(f'raw/edificios-ml/huellas.jsonl: {len(ml)} huellas, {nh} con alto; alturas-osm.json: {len(alt)} edificios de OSM ({time.time() - t0:.0f} s)')

if __name__ == '__main__':
    main()
