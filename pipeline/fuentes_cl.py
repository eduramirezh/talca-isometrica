"""Fuentes públicas chilenas de usos de suelo (raw/cl/<fuente>/): su descarga y su lectura en metros de grilla.

Las evaluó raw/eval/chile.md (octubre de 2026). Todas se bajan por HTTP sin cuenta; las de ArcGIS, con la caja de la
comuna. Lo bajado son datos no confiables: los scripts que los leen van con `python -I` y reciben las rutas.

  python -I pipeline/fuentes_cl.py fetch <fuente> [carpeta]
      Baja una fuente a raw/cl/<fuente>/ (o a la carpeta dada; no reemplaza un archivo que ya existe):
        ciren        CIREN–ODEPA, Catastro Frutícola Maule 2024: los polígonos de cada predio (productores frutícolas)
        ciren-tabla  la tabla de cuarteles del mismo catastro (especie, variedad, año de plantación, conducción,
                     árboles, superficie), filtrada a la comuna; se une a los polígonos por `mslink`
        ciren-uso    CIREN, Uso de la Tierra Maule 2022 (con las viñas y parronales y su origen)
        conaf        CONAF, Catastro de Uso de Suelo y Vegetación, Región del Maule, actualización 2024
        minvu        MINVU–INE, Catastro Nacional de Áreas Verdes 2023 (CUT 7101)
        censo2024    INE, Censo 2024: la cartografía de la Región del Maule (GeoPackage) y sus manzanas de la comuna
                     en GeoJSON (manzanas_2024_talca.geojson)
      El Directorio de establecimientos de MINEDUC (un .rar) y el de DEIS (un CSV de datos.gob.cl) se bajan a mano:
      `fetch mineduc` y `fetch deis` dicen de dónde.
  python -I pipeline/fuentes_cl.py info
      Lo que hay en raw/cl/ y cuántos objetos caen en la comuna.
  uv run --with pillow python -I pipeline/fuentes_cl.py panel ciren-uso|conaf|censo2024|ciren|minvu x y [lado] [z]
      La imagen de Esri alrededor de (x, y) de grilla (lado 1200 m, zoom 16) con los polígonos de la fuente encima, en
      colores por clase (cmd_panel), y los usos de suelo en naranjo -> diagnostics/cl-<fuente>-<x>_<y>.png. Así se
      revisaron las viñas de CIREN 2022, los bosques asilvestrados de CONAF y la densidad de las manzanas de 2024.

Las demás herramientas leen estas fuentes con polys() (polígonos en metros de grilla) y con las rutas de FILES:
usos.py importar ciren|ciren-vinas|censo2024|areasverdes, usos.py escuelas|salud y cobertura.py.
"""
import json, os, sqlite3, struct, sys, time, urllib.parse, urllib.request, zipfile
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import RAW, loc

CL = RAW / 'cl'
BBOX = '-71.76,-35.535,-71.45,-35.31'   # lon0,lat0,lon1,lat1: la caja de la comuna (common.EXT) con margen
ARC = 'https://esri.ciren.cl/server/rest/services/'
FILES = {
    'ciren': CL / 'ciren' / 'productores_fruticolas_maule_2024.geojson',
    'ciren-tabla': CL / 'ciren' / 'catfru_maule_talca_tabla.json',
    'ciren-uso': CL / 'ciren' / 'uso_tierra_maule_2022.geojson',
    'conaf': CL / 'conaf' / 'catastro_maule_2024.geojson',
    'minvu': CL / 'minvu' / 'areas_verdes_2023.geojson',
    'censo2024': CL / 'ine' / 'manzanas_2024_talca.geojson',
    'mineduc': CL / 'mineduc' / 'x' / '20250926_Directorio_Oficial_EE_2025_20250430_WEB.csv',
    'deis': CL / 'minsal' / 'establecimientos_20261014.csv',
}
LAYERS = {   # fuente -> (ArcGIS layer, where, bbox?)
    'ciren': (ARC + 'IDEMINAGRI/CATASTRO_FRUTICOLA/MapServer/62', '1=1', True),
    'ciren-tabla': ('https://services3.arcgis.com/DmlBJVTrQbCmoXcR/arcgis/rest/services/vista_tb_catastro_fruticola_maule/FeatureServer/0',
                    "desccomu='TALCA'", False),
    'ciren-uso': (ARC + 'IDEMINAGRI/USO_DE_LA_TIERRA_CIREN_2/MapServer/5', '1=1', True),
    'conaf': (ARC + 'USOS_DE_LA_TIERRA__CONAF/MapServer/8', '1=1', True),
    'minvu': ('https://geoide.minvu.cl/server/rest/services/Catastros/%C3%81reas_Verdes_MINVU_INE_2023/FeatureServer/0', 'CUT=7101', False),
}
CENSO_ZIP = 'https://storage.googleapis.com/bktdescargascenso2024/Cartografia/GPKG/Cartografia_censo2024_R07.zip'
MANUAL = {
    'mineduc': 'https://datosabiertos.mineduc.cl/wp-content/uploads/2025/11/Directorio-Oficial-EE-2025.rar (bsdtar -xf extrae el CSV a raw/cl/mineduc/x/)',
    'deis': 'https://datos.gob.cl/dataset/3bf4cf7c-f638-4735-9a01-f65faae4beca (el CSV de establecimientos, a raw/cl/minsal/)',
}

# ---------------------------------------------------------------- lectura
def polys(path):
    """GeoJSON (lon, lat) -> [(properties, [outer ring, hole, …]), …] in grid metres, one item per polygon part."""
    out = []
    for f in json.load(open(path))['features']:
        g = f.get('geometry')
        if not g: continue
        parts = [g['coordinates']] if g['type'] == 'Polygon' else g['coordinates'] if g['type'] == 'MultiPolygon' else []
        for P in parts:
            rings = [[loc(p[0], p[1]) for p in r[:-1] if len(p) >= 2] for r in P]
            if rings and len(rings[0]) >= 3: out.append((f.get('properties') or {}, rings))
    return out

def table(path):
    """A downloaded ArcGIS table (a list of attribute dicts)."""
    return json.load(open(path))

# ---------------------------------------------------------------- descarga
def _get(url, params):
    q = urllib.parse.urlencode(params).encode()
    for i in range(4):
        try:
            req = urllib.request.Request(url + '/query', data=q, headers={'User-Agent': 'talca-isometrica/1.0'})
            with urllib.request.urlopen(req, timeout=180) as r: return json.loads(r.read().decode('utf-8'))
        except Exception as e:
            print('reintento', i + 1, e, file=sys.stderr); time.sleep(3)
    raise SystemExit(f'no responde: {url}')

def arcgis(url, where, bbox):
    """All the features of an ArcGIS layer (where, and the commune's box if bbox), paged: a GeoJSON dict, or a list of
    attribute dicts for a table without geometry."""
    base = dict(where=where, outFields='*', returnGeometry='true', outSR=4326, f='geojson')
    if bbox: base.update(geometry=BBOX, geometryType='esriGeometryEnvelope', inSR=4326, spatialRel='esriSpatialRelIntersects')
    feats, off = [], 0
    while True:
        d = _get(url, dict(base, resultOffset=off, resultRecordCount=1000))
        if 'error' in d: raise SystemExit(f"{url}: {d['error']}")
        fs = d.get('features', []); feats += fs; off += len(fs)
        print(off, file=sys.stderr)
        more = d.get('exceededTransferLimit') or d.get('properties', {}).get('exceededTransferLimit')
        if not fs or (not more and len(fs) < 1000): break
    if feats and not feats[0].get('geometry'): return [f['properties'] for f in feats]
    return {'type': 'FeatureCollection', 'features': feats}

def _wkb(b, o=0):
    """A WKB geometry at offset o -> (GeoJSON geometry, next offset). Polygons, multipolygons and the curve types of the
    INE's GeoPackage (arcs are kept as their control points)."""
    bo = '<' if b[o] == 1 else '>'; t = struct.unpack_from(bo + 'I', b, o + 1)[0]; o += 5; dim = 2
    if t & 0x80000000: dim += 1; t &= 0xFFFF
    if t & 0x40000000: dim += 1; t &= 0xFFFF
    if t >= 1000: dim, t = (4 if t >= 3000 else 3), t % 1000
    n = struct.unpack_from(bo + 'I', b, o)[0]; o += 4
    if t in (2, 8):   # LineString, CircularString
        pts = [[round(v, 7) for v in struct.unpack_from(bo + 'dd', b, o + i*8*dim)] for i in range(n)]
        return {'type': 'Line', 'coordinates': pts}, o + n*8*dim
    if t == 3:
        rs = []
        for _ in range(n):
            m = struct.unpack_from(bo + 'I', b, o)[0]; o += 4
            rs.append([[round(v, 7) for v in struct.unpack_from(bo + 'dd', b, o + i*8*dim)] for i in range(m)]); o += m*8*dim
        return {'type': 'Polygon', 'coordinates': rs}, o
    parts = []
    for _ in range(n): g, o = _wkb(b, o); parts.append(g['coordinates'])
    if t == 9: return {'type': 'Line', 'coordinates': [p for k, c in enumerate(parts) for p in (c if k == 0 else c[1:])]}, o
    if t == 10: return {'type': 'Polygon', 'coordinates': parts}, o
    if t in (6, 12): return {'type': 'MultiPolygon', 'coordinates': parts}, o
    raise ValueError(f'tipo de geometría WKB {t}')

def gpkg(path, layer, where='1=1'):
    """A GeoPackage layer -> GeoJSON dict (stdlib sqlite3, read-only)."""
    c = sqlite3.connect(f'file:{path}?mode=ro', uri=True)
    geom = c.execute('select column_name from gpkg_geometry_columns where table_name=?', (layer,)).fetchone()[0]
    cols = [r[1] for r in c.execute(f'pragma table_info("{layer}")') if r[1] != geom]
    feats = []
    for row in c.execute(f'select "{geom}",' + ','.join(f'"{k}"' for k in cols) + f' from "{layer}" where {where}'):
        g = None
        if row[0]:
            b = row[0]; env = (b[3] >> 1) & 7
            g = _wkb(b, 8 + {0: 0, 1: 32, 2: 48, 3: 48, 4: 64}[env])[0]
        feats.append({'type': 'Feature', 'properties': dict(zip(cols, row[1:])), 'geometry': g})
    return {'type': 'FeatureCollection', 'features': feats}

def save(path, obj):
    if path.exists(): raise SystemExit(f'{path} ya existe: no se reemplaza (bórrelo o baje a otra carpeta)')
    path.parent.mkdir(parents=True, exist_ok=True); path.write_text(json.dumps(obj, ensure_ascii=False))
    n = len(obj['features']) if isinstance(obj, dict) else len(obj)
    print(f'{n} objetos -> {path}')

def cmd_fetch(name, folder=None):
    if name in MANUAL: return print(f'{name}: a mano, desde {MANUAL[name]}')
    if name not in FILES: raise SystemExit(f'fuente desconocida: {name} ({", ".join(FILES)})')
    out = (os.path.join(folder, FILES[name].name) if folder else None)
    from pathlib import Path
    out = Path(out) if out else FILES[name]
    if name == 'censo2024':
        z = out.parent / 'Cartografia_censo2024_R07.zip'
        if not z.exists():
            z.parent.mkdir(parents=True, exist_ok=True)
            urllib.request.urlretrieve(CENSO_ZIP, z); print('->', z)
        with zipfile.ZipFile(z) as zf:
            g = [n for n in zf.namelist() if n.endswith('.gpkg')][0]
            dst = out.parent / os.path.basename(g)
            if not dst.exists(): dst.write_bytes(zf.read(g))
        return save(out, gpkg(dst, 'Manzanas_CPV24', 'CUT=7101'))
    save(out, arcgis(*LAYERS[name]))

def tono(name, p, rings):
    """The colour of a source's polygon in the panel (None: not drawn)."""
    if name == 'ciren-uso':
        u = p.get('uso_actual')
        return ((255, 40, 40) if p.get('origen') == 'CLASIFICACION' else (255, 240, 0)) if u == 'VINA Y PARRONAL' else (0, 200, 255) if u == 'FRUTAL' else None
    if name == 'conaf':
        su = p.get('subuso') or ''
        return ((255, 40, 40) if 'Asilv' in (p.get('estructura') or '') else (255, 0, 255) if su == 'Plantación' else (255, 240, 0) if su.startswith('Bosque')
                else (255, 255, 255) if su.startswith('Matorral') else None)
    if name == 'censo2024':
        from usos import area
        viv = p.get('n_vp') or 0; d = viv / (area(rings[0]) / 1e4)
        return None if viv <= 0 else (255, 40, 40) if d >= 8 else (255, 240, 0) if d >= 2 else (60, 120, 255)
    return (0, 230, 255) if name == 'ciren' else (40, 220, 90)

def cmd_panel(name, x, y, side='1200', z='16'):
    """The Esri image (satellite.mosaic) around grid point (x, y) with the polygons of a source over it, and the entries
    of the land-use files in orange (CIREN's in cyan): ciren-uso (vines: red from image classification, yellow from the
    Catastro Vitivinícola; orchards blue), conaf (red feral woods, magenta plantations, yellow native forest, white
    scrub), censo2024 (populated blocks: red 8 dwellings/ha or more, yellow 2-8, blue fewer), ciren, minvu.
    -> diagnostics/cl-<source>-<x>_<y>.png. Needs Pillow (uv run --with pillow)."""
    from PIL import ImageDraw
    import satellite, usos
    cx, cy, s = float(x), float(y), float(side)
    im, P = satellite.mosaic(cx-s/2, cx+s/2, cy-s/2, cy+s/2, int(z)); d = ImageDraw.Draw(im)
    def ring(r, col, w): q = [P(p) for p in r]; d.line(q + [q[0]], fill=col, width=w)
    for u, rs in usos.entries(): ring(rs[0], (0, 230, 255) if u.get('importado') == 'ciren' else (255, 150, 0), 2)
    for p, rings in polys(FILES[name]):
        col = tono(name, p, rings)
        if col: ring(rings[0], col, 3)
    from common import ROOT
    out = ROOT / 'diagnostics' / f'cl-{name}-{x}_{y}.png'; out.parent.mkdir(exist_ok=True); im.save(out); print(out.relative_to(ROOT), im.size)

def cmd_info():
    from common import comuna
    from usos import pip
    lim = comuna()
    for name, f in FILES.items():
        if not f.exists(): print(f'{name:12} (falta {f.relative_to(RAW.parent) if f.is_relative_to(RAW.parent) else f})'); continue
        if f.suffix == '.geojson':
            P = polys(f); n = sum(1 for _, r in P if pip(r[0][0], lim))
            print(f'{name:12} {len(P):6} polígonos, {n} en la comuna  {f.name}')
        else: print(f'{name:12} {f.stat().st_size//1024:6} KB  {f.name}')

if __name__ == '__main__':
    cmds = {'fetch': cmd_fetch, 'info': cmd_info, 'panel': cmd_panel}
    if len(sys.argv) < 2 or sys.argv[1] not in cmds: raise SystemExit(__doc__)
    cmds[sys.argv[1]](*sys.argv[2:])
