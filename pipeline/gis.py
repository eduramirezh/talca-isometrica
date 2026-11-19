"""Las capas del mapa en un GeoPackage y un proyecto de QGIS, y de vuelta los usos de suelo que se editen ahí.

  python pipeline/gis.py exportar [carpeta] [--wgs84]
      data/ y config/ -> <carpeta>/talca.gpkg (gis/ por omisión, fuera de git) y <carpeta>/talca.qgs, el proyecto
      que lo abre en QGIS con estilos y la imagen de Esri de fondo. No necesita raw/. Capas: limite, manzanas (bi,
      tipo del Censo y tipo con config/manzanas.json), agua, rios (ejes y ramas), calles (clase y nombre), via_ferrea,
      ruta5 (calzadas y ramales), usos (las entradas de los cuatro archivos de USOS_FILES, editables), edificios (los
      de OSM de data/edificios.json), huellas (las de aprendizaje automático, como las decodifica la página),
      superficies y lugares (data/pois.json).
      Las coordenadas quedan en metros de grilla (los de config/ y data/, sin redondeos nuevos): el sistema de
      referencia del archivo es la grilla misma, escrita en WKT2 (`crs`), y QGIS reproyecta a ella la imagen
      satelital y cualquier otra capa. Con el proyecto en ese sistema las calles numeradas quedan paralelas a los
      bordes de la pantalla, como en la maqueta. Con --wgs84 van en longitud y latitud (EPSG:4326, para otro programa
      que no lea WKT2; la vuelta con loc() y el redondeo a enteros da los mismos números).
  python pipeline/gis.py importar [archivo.gpkg] [--escribir]
      La capa `usos` del GeoPackage (editada en QGIS) contra config/usos*.json: qué entradas cambiaron de polígono o
      de atributos, cuáles son nuevas y cuáles se borraron. Sin --escribir solo lo lista; con --escribir aplica los
      cambios y las nuevas (al final de config/usos.json: el lugar de cada entrada siembra su dibujo) con el formato
      de usos.py. Los vértices se redondean a metros enteros. Una entrada de OSM (`auto`) que cambia de polígono
      deja de serlo (pasa a mandar sobre `usos.py importar comuna`); una con `bi` toma el polígono en `poly` (que
      manda) salvo las `vivienda`, cuyo `bi` marca la manzana y no se cambia. Las borradas no se quitan (correría
      las semillas de todas las que siguen): se quitan a mano, con TALCA_USOS_ORDEN=ok para make check. Una
      entrada nueva necesita `uso`, `fuente` y `confianza`. Si un archivo de usos cambió desde la exportación, sus
      entradas no se tocan (la columna `huella` no calza): exporte de nuevo. Después: usos.py check y make build.
  python pipeline/gis.py crs [--proj]
      El sistema de referencia de la grilla en WKT2 (o con --proj, la operación de PROJ de longitud y latitud a la
      grilla, para cct o cs2cs), exactos: common.loc() es lineal en los grados.

Biblioteca estándar (sqlite3 y struct escriben el GeoPackage, OGC 12-128r18). docs/METODOLOGIA.md §17.
"""
import copy, datetime, hashlib, json, math, os, sqlite3, struct, sys
from pathlib import Path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cli
from common import ROOT, DATA, CONFIG, LAT0, LON0, KX, KY, TH, loc, unloc, require
from geom import dec

OUT = ROOT / 'gis'
SRS = 107101                    # the grid's srs_id in the GeoPackage (the commune's code); any free id would do
DEG = '0.0174532925199433'

# ------------------------------------------------------------------------------------------------ the grid as a CRS
def grid_wkt():
    """common.loc() as a WKT2 derived projected CRS: an equidistant cylindrical projection on a sphere of radius
    KY·180/π (y = KY·(lat − LAT0)), whose standard parallel gives KX m per degree of longitude, then the grid's turn
    (an affine conversion, EPSG method 9624). The sphere's latitude and longitude are WGS 84's: PROJ goes from one to
    the other without a shift, and pyproj gives loc() back to ~1e-9 m. Exact because loc() is linear in degrees."""
    R = KY * 180 / math.pi; ts = math.degrees(math.acos(KX / KY)); c, s = math.cos(TH), math.sin(TH)
    return ('DERIVEDPROJCRS["Talca, metros de grilla",'
            f'BASEPROJCRS["Talca, equirectangular",BASEGEOGCRS["Talca, esfera",DATUM["Talca, esfera",ELLIPSOID["esfera",{R!r},0,LENGTHUNIT["metre",1]]],'
            f'PRIMEM["Greenwich",0,ANGLEUNIT["degree",{DEG}]]],'
            'CONVERSION["equirectangular",METHOD["Equidistant Cylindrical",ID["EPSG",1028]],'
            f'PARAMETER["Latitude of 1st standard parallel",{ts!r},ANGLEUNIT["degree",{DEG}]],'
            f'PARAMETER["Longitude of natural origin",{LON0!r},ANGLEUNIT["degree",{DEG}]],'
            'PARAMETER["False easting",0,LENGTHUNIT["metre",1]],'
            f'PARAMETER["False northing",{-R * math.radians(LAT0)!r},LENGTHUNIT["metre",1]]]],'
            'DERIVINGCONVERSION["giro de la grilla (+5 grados)",METHOD["Affine parametric transformation",ID["EPSG",9624]],'
            f'PARAMETER["A0",0,LENGTHUNIT["metre",1]],PARAMETER["A1",{c!r},SCALEUNIT["coefficient",1]],PARAMETER["A2",{-s!r},SCALEUNIT["coefficient",1]],'
            f'PARAMETER["B0",0,LENGTHUNIT["metre",1]],PARAMETER["B1",{s!r},SCALEUNIT["coefficient",1]],PARAMETER["B2",{c!r},SCALEUNIT["coefficient",1]]],'
            'CS[Cartesian,2],AXIS["x (oriente)",east,ORDER[1],LENGTHUNIT["metre",1]],AXIS["y (norte)",north,ORDER[2],LENGTHUNIT["metre",1]],'
            'REMARK["El origen es la Plaza de Armas de Talca; la grilla de calles numeradas, girada +5 grados, queda paralela a los ejes (pipeline/common.py)."]]')

def grid_proj():
    """The PROJ operation lon, lat (degrees) -> x, y (grid metres): loc() as one affine step."""
    c, s = math.cos(TH), math.sin(TH)
    a, b, d, e = c*KX, -s*KY, s*KX, c*KY
    return (f'+proj=affine +xoff={-(a*LON0 + b*LAT0)!r} +yoff={-(d*LON0 + e*LAT0)!r} '
            f'+s11={a!r} +s12={b!r} +s21={d!r} +s22={e!r}')

WGS84_WKT1 = ('GEOGCS["WGS 84",DATUM["WGS_1984",SPHEROID["WGS 84",6378137,298.257223563,AUTHORITY["EPSG","7030"]],'
              'AUTHORITY["EPSG","6326"]],PRIMEM["Greenwich",0,AUTHORITY["EPSG","8901"]],UNIT["degree",0.0174532925199433,'
              'AUTHORITY["EPSG","9122"]],AXIS["Latitude",NORTH],AXIS["Longitude",EAST],AUTHORITY["EPSG","4326"]]')

# ------------------------------------------------------------------------------------- GeoPackage geometry (WKB)
def _pts(P): return b''.join(struct.pack('<dd', x, y) for x, y in P)
def _ring(r):
    r = list(r)
    if r[0] != r[-1]: r = r + [r[0]]
    return struct.pack('<I', len(r)) + _pts(r)

def wkb(kind, g):
    """kind: 'POINT' (x, y), 'LINESTRING' [pts], 'POLYGON' [ring, hole…], 'MULTIPOLYGON' [[ring, hole…], …]."""
    if kind == 'POINT': return struct.pack('<BIdd', 1, 1, *g)
    if kind == 'LINESTRING': return struct.pack('<BII', 1, 2, len(g)) + _pts(g)
    if kind == 'POLYGON': return struct.pack('<BII', 1, 3, len(g)) + b''.join(_ring(r) for r in g)
    if kind == 'MULTIPOLYGON': return struct.pack('<BII', 1, 6, len(g)) + b''.join(wkb('POLYGON', p) for p in g)
    raise ValueError(kind)

def gpb(srs, kind, g, xy):
    """A GeoPackage geometry blob: header (little-endian, xy envelope) + WKB. xy: every vertex, for the envelope."""
    X = [p[0] for p in xy]; Y = [p[1] for p in xy]
    return b'GP\x00\x03' + struct.pack('<i4d', srs, min(X), max(X), min(Y), max(Y)) + wkb(kind, g)

def read_gpb(blob):
    """A GeoPackage geometry blob -> ('POLYGON', [ring, hole…]) or ('MULTIPOLYGON', [[ring, …], …]) or other kinds,
    rings without their closing vertex. 2D only (what QGIS writes into a 2D layer)."""
    if blob is None: return None, None
    if blob[:2] != b'GP': raise ValueError('no es una geometría de GeoPackage')
    fl = blob[3]; env = {0: 0, 1: 32, 2: 48, 3: 48, 4: 64}[(fl >> 1) & 7]
    if fl & 16: return None, None                                   # empty
    b, i = blob[8 + env:], 0
    def u32(o): return struct.unpack_from(o + 'I', b, i)[0]
    def geom():
        nonlocal i
        o = '<' if b[i] == 1 else '>'; i += 1; t = u32(o); i += 4
        def pts(n):
            nonlocal i
            P = [struct.unpack_from(o + 'dd', b, i + 16*k) for k in range(n)]; i += 16*n; return P
        def ring():
            nonlocal i
            n = u32(o); i += 4; P = pts(n)
            return P[:-1] if len(P) > 1 and P[0] == P[-1] else P
        if t == 1: return 'POINT', pts(1)[0]
        if t == 2: n = u32(o); i += 4; return 'LINESTRING', pts(n)
        if t == 3: n = u32(o); i += 4; return 'POLYGON', [ring() for _ in range(n)]
        if t in (4, 5, 6):
            n = u32(o); i += 4; parts = [geom()[1] for _ in range(n)]
            return {4: 'MULTIPOINT', 5: 'MULTILINESTRING', 6: 'MULTIPOLYGON'}[t], parts
        raise ValueError(f'tipo de geometría WKB {t} (¿con Z o M?): la capa tiene que ser 2D')
    return geom()

# ------------------------------------------------------------------------------------------------ GeoPackage file
class GPKG:
    """A GeoPackage written with sqlite3: the required tables, the CRS-WKT extension (the grid has no WKT1), one
    feature table per layer and a QGIS style per layer (layer_styles: QGIS takes it as the layer's default)."""
    def __init__(self, path, wgs84):
        self.path, self.wgs84 = Path(path), wgs84
        self.srs = 4326 if wgs84 else SRS
        if self.path.exists(): self.path.unlink()
        self.db = db = sqlite3.connect(self.path)
        db.execute('PRAGMA application_id = 1196444487'); db.execute('PRAGMA user_version = 10400')   # 'GPKG', 1.4
        db.executescript('''
          CREATE TABLE gpkg_spatial_ref_sys (srs_name TEXT NOT NULL, srs_id INTEGER PRIMARY KEY, organization TEXT NOT NULL,
            organization_coordsys_id INTEGER NOT NULL, definition TEXT NOT NULL, description TEXT,
            definition_12_063 TEXT NOT NULL DEFAULT 'undefined');
          CREATE TABLE gpkg_contents (table_name TEXT NOT NULL PRIMARY KEY, data_type TEXT NOT NULL, identifier TEXT UNIQUE,
            description TEXT DEFAULT '', last_change DATETIME NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
            min_x DOUBLE, min_y DOUBLE, max_x DOUBLE, max_y DOUBLE, srs_id INTEGER,
            CONSTRAINT fk_gc_r_srs_id FOREIGN KEY (srs_id) REFERENCES gpkg_spatial_ref_sys(srs_id));
          CREATE TABLE gpkg_geometry_columns (table_name TEXT NOT NULL, column_name TEXT NOT NULL, geometry_type_name TEXT NOT NULL,
            srs_id INTEGER NOT NULL, z TINYINT NOT NULL, m TINYINT NOT NULL, CONSTRAINT pk_geom_cols PRIMARY KEY (table_name, column_name),
            CONSTRAINT fk_gc_tn FOREIGN KEY (table_name) REFERENCES gpkg_contents(table_name),
            CONSTRAINT fk_gc_srs FOREIGN KEY (srs_id) REFERENCES gpkg_spatial_ref_sys (srs_id));
          CREATE TABLE gpkg_extensions (table_name TEXT, column_name TEXT, extension_name TEXT NOT NULL, definition TEXT NOT NULL,
            scope TEXT NOT NULL, CONSTRAINT ge_tce UNIQUE (table_name, column_name, extension_name));
          CREATE TABLE layer_styles (id INTEGER PRIMARY KEY AUTOINCREMENT, f_table_catalog TEXT(256), f_table_schema TEXT(256),
            f_table_name TEXT(256), f_geometry_column TEXT(256), styleName TEXT(30), styleQML TEXT, styleSLD TEXT,
            useAsDefault BOOLEAN, description TEXT, owner TEXT(30), ui TEXT(30), update_time DATETIME DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')));''')
        db.executemany('INSERT INTO gpkg_spatial_ref_sys VALUES (?,?,?,?,?,?,?)', [
            ('Undefined cartesian SRS', -1, 'NONE', -1, 'undefined', 'undefined cartesian coordinate reference system', 'undefined'),
            ('Undefined geographic SRS', 0, 'NONE', 0, 'undefined', 'undefined geographic coordinate reference system', 'undefined'),
            ('WGS 84 geodetic', 4326, 'EPSG', 4326, WGS84_WKT1, 'longitude/latitude coordinates in decimal degrees on the WGS 84 spheroid', 'undefined'),
            ('Talca, metros de grilla', SRS, 'TALCA', 1, 'undefined', 'pipeline/common.py loc(): origen en la Plaza de Armas, girado +5°', grid_wkt())])
        db.execute("INSERT INTO gpkg_extensions VALUES ('gpkg_spatial_ref_sys', 'definition_12_063', 'gpkg_crs_wkt', "
                   "'http://www.geopackage.org/spec/#extension_crs_wkt', 'read-write')")
        self.layers = []

    def xy(self, p):
        """A grid point as the file stores it."""
        if not self.wgs84: return (float(p[0]), float(p[1]))
        lat, lon = unloc(*p); return (lon, lat)

    def layer(self, name, kind, cols, rows, title, qml):
        """rows: [(geometry in grid metres, {col: value})]. cols: [(name, 'TEXT' | 'INTEGER' | 'REAL')]."""
        db, n = self.db, 0
        db.execute(f'CREATE TABLE "{name}" (fid INTEGER PRIMARY KEY AUTOINCREMENT, geom {kind}'
                   + ''.join(f', "{c}" {t}' for c, t in cols) + ')')
        X0 = Y0 = math.inf; X1 = Y1 = -math.inf
        sql = f'INSERT INTO "{name}" (geom' + ''.join(f', "{c}"' for c, _ in cols) + ') VALUES (?' + ', ?'*len(cols) + ')'
        for g, a in rows:
            if kind == 'POINT': g = self.xy(g); xy = [g]
            elif kind == 'LINESTRING': g = [self.xy(p) for p in g]; xy = g
            elif kind == 'POLYGON': g = [[self.xy(p) for p in r] for r in g]; xy = g[0]
            else: g = [[[self.xy(p) for p in r] for r in pg] for pg in g]; xy = [p for pg in g for p in pg[0]]
            db.execute(sql, [gpb(self.srs, kind, g, xy)] + [a.get(c) for c, _ in cols]); n += 1
            X0 = min(X0, *(p[0] for p in xy)); X1 = max(X1, *(p[0] for p in xy)); Y0 = min(Y0, *(p[1] for p in xy)); Y1 = max(Y1, *(p[1] for p in xy))
        db.execute('INSERT INTO gpkg_contents (table_name, data_type, identifier, description, min_x, min_y, max_x, max_y, srs_id) '
                   'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)', (name, 'features', name, title, X0, Y0, X1, Y1, self.srs))
        db.execute('INSERT INTO gpkg_geometry_columns VALUES (?, ?, ?, ?, 0, 0)', (name, 'geom', kind, self.srs))
        db.execute('INSERT INTO layer_styles (f_table_catalog, f_table_schema, f_table_name, f_geometry_column, styleName, styleQML, '
                   "styleSLD, useAsDefault, description) VALUES ('', '', ?, 'geom', ?, ?, '', 1, 'pipeline/gis.py')",
                   (name, name, qml_doc(qml)))
        self.layers.append((name, kind, title, qml)); return n

    def close(self): self.db.commit(); self.db.close()

# ------------------------------------------------------------------------------------------------ QGIS styles
def _opts(**o): return '<Option type="Map">' + ''.join(f'<Option name="{k}" type="QString" value="{v}"/>' for k, v in o.items()) + '</Option>'
def _rgba(h, a=255): return f'{int(h[1:3], 16)},{int(h[3:5], 16)},{int(h[5:7], 16)},{a}'

def fill(col, a=255, line='#000000', lw=0.1, la=255, style='solid'):
    return ('<symbol type="fill" name="{n}" alpha="1" clip_to_extent="1" force_rhr="0"><layer class="SimpleFill" enabled="1" pass="0" locked="0">'
            + _opts(color=_rgba(col, a), outline_color=_rgba(line, la), outline_width=lw, outline_width_unit='MM', outline_style='solid',
                    style=style, joinstyle='miter') + '</layer></symbol>')
def line(col, w, a=255, dash=False):
    return ('<symbol type="line" name="{n}" alpha="1" clip_to_extent="1" force_rhr="0"><layer class="SimpleLine" enabled="1" pass="0" locked="0">'
            + _opts(line_color=_rgba(col, a), line_width=w, line_width_unit='MM', line_style='dash' if dash else 'solid',
                    capstyle='round', joinstyle='round') + '</layer></symbol>')
def marker(col, size):
    return ('<symbol type="marker" name="{n}" alpha="1" clip_to_extent="1" force_rhr="0"><layer class="SimpleMarker" enabled="1" pass="0" locked="0">'
            + _opts(color=_rgba(col), outline_color='255,255,255,255', outline_width=0.4, outline_width_unit='MM', name='circle',
                    size=size, size_unit='MM') + '</layer></symbol>')

def single(sym): return f'<renderer-v2 type="singleSymbol" symbollevels="0" enableorderby="0" forceraster="0"><symbols>{sym.format(n=0)}</symbols></renderer-v2>'
def categorized(attr, cats, default=None):
    """cats: [(value, label, symbol)]; default: the symbol of every other value."""
    c = ''.join(f'<category value="{v}" symbol="{i}" label="{l}" render="true"/>' for i, (v, l, _) in enumerate(cats))
    s = ''.join(sym.format(n=i) for i, (_, _, sym) in enumerate(cats))
    if default: c += f'<category value="" symbol="{len(cats)}" label="otro" render="true"/>'; s += default.format(n=len(cats))
    return (f'<renderer-v2 type="categorizedSymbol" attr="{attr}" symbollevels="0" enableorderby="0" forceraster="0">'
            f'<categories>{c}</categories><symbols>{s}</symbols></renderer-v2>')
def labels(field, size=8, scale=None):
    """Simple labels of `field` (an expression when it is not a bare name), shown below 1:scale."""
    vis = f' scaleVisibility="1" scaleMin="1" scaleMax="{scale}"' if scale else ''
    return (f'<labeling type="simple"><settings calloutType="simple"><text-style fieldName="{_x(field)}" fontSize="{size}" fontFamily="Sans Serif" '
            f'textColor="30,30,30,255" isExpression="{int(not field.isidentifier())}" fontWeight="50" textOpacity="1"><text-buffer bufferDraw="1" bufferSize="0.8" '
            f'bufferColor="255,255,255,255" bufferOpacity="0.85" bufferSizeUnits="MM"/></text-style><placement placement="2" dist="1" '
            f'distUnits="MM"/><rendering{vis} obstacle="1" drawLabels="1"/></settings></labeling>')
def qml_doc(body): return f"<!DOCTYPE qgis PUBLIC 'http://mrcc.com/qgis.dtd' 'SYSTEM'><qgis version=\"3.34\" styleCategories=\"Symbology|Labeling\">{body}</qgis>"

USO_COL = {'industrial': '#8E7CC3', 'cementerio': '#93A27E', 'militar': '#6B7A3A', 'educacional': '#E6B33A', 'salud': '#E06666',
           'deportivo': '#5DAA5A', 'parque': '#8CCB6A', 'huerto': '#3E8E41', 'vina': '#A64D79', 'potrero': '#D9D27A',
           'eriazo': '#C9A46A', 'bosque': '#2F6B3A', 'feria': '#F39C4A', 'golf': '#77C977', 'vivienda': '#E8A090',
           'conjunto': '#D97A5A', 'parcelas': '#BFA77A', 'terminal': '#5B7DB1'}
TIPO_MZ = ['con datos del Censo', 'sin información', 'aldea', 'construida (config/manzanas.json)']
CLASES = ['troncal', 'primaria', 'secundaria', 'terciaria', 'local', 'compartida', 'peatonal', 'servicio o pista']

# ------------------------------------------------------------------------------------------------ the layers
def entry_hash(u): return hashlib.sha1(json.dumps(u, sort_keys=True, ensure_ascii=False).encode()).hexdigest()[:12]
USO_COLS = ['uso', 'nombre', 'fuente', 'confianza', 'nota']        # columns of their own; every other key goes in `otros`
USO_GEOM = ('poly', 'bi', 'bc', 'auto')                              # keys the importer manages

def uso_files():
    from build import USOS_FILES
    return [(f, json.load(open(CONFIG / f))) for f in USOS_FILES if (CONFIG / f).exists()]

def cmd_exportar(carpeta=None, *, wgs84=False):
    """`gis.py exportar [carpeta] [--wgs84]`: the GeoPackage and the QGIS project."""
    import edificios
    from build import mark_built
    out = Path(carpeta) if carpeta else OUT; out.mkdir(parents=True, exist_ok=True)
    g = json.load(open(require(DATA / 'geometry.json', 'Ejecute: make data')))
    G = GPKG(out / 'talca.gpkg', wgs84); N = {}

    N['limite'] = G.layer('limite', 'POLYGON', [('nombre', 'TEXT')], [([dec(g['limit'])], {'nombre': 'Comuna de Talca (OSM r541797)'})],
                          'El límite de la comuna (OSM), el borde de la maqueta', single(fill('#FFFFFF', 0, '#C0392B', 0.6)))
    mz = copy.deepcopy(g['blocks']); mark_built(mz)
    N['manzanas'] = G.layer('manzanas', 'POLYGON', [('bi', 'INTEGER'), ('tipo', 'INTEGER'), ('tipo_censo', 'INTEGER'), ('descripcion', 'TEXT'),
                                                    ('personas', 'INTEGER'), ('viviendas', 'INTEGER')],
        [([dec(b[3])], {'bi': i, 'tipo': m[0], 'tipo_censo': b[0], 'descripcion': TIPO_MZ[m[0]], 'personas': b[1], 'viviendas': b[2]})
         for i, (b, m) in enumerate(zip(g['blocks'], mz))],
        'Las manzanas del Censo 2017 (data/geometry.json); bi es el índice que usan config/usos.json y satellite.py',
        categorized('tipo', [(0, TIPO_MZ[0], fill('#E8DCC8', 150, '#8D7B68', 0.15)), (1, TIPO_MZ[1], fill('#CFE3B4', 150, '#8D7B68', 0.15)),
                             (2, TIPO_MZ[2], fill('#E8DCC8', 150, '#8D7B68', 0.15)), (3, TIPO_MZ[3], fill('#F2C9A0', 170, '#8D7B68', 0.15))]))
    N['agua'] = G.layer('agua', 'MULTIPOLYGON', [('rio', 'TEXT')],
        [([[dec(r) for r in p] for p in A], {'rio': k}) for k, A in g['area'].items() if A],
        'El agua de los ríos de OSM, con sus islas', single(fill('#7FB3D5', 220, '#2E86C1', 0.15)))
    N['rios'] = G.layer('rios', 'LINESTRING', [('rio', 'TEXT'), ('parte', 'TEXT'), ('ancho_m', 'REAL')],
        [(dec(l), {'rio': k, 'parte': 'eje', 'ancho_m': g['widths'][k][0]}) for k, l in g['water'].items()]
        + [(dec(l), {'rio': k, 'parte': 'rama', 'ancho_m': g['widths'][k][0]}) for k, B in g.get('branch', {}).items() for l in B],
        'Los ejes de los ríos y canales (config/trazados.json, OSM)', single(line('#1F618D', 0.5)))
    N['calles'] = G.layer('calles', 'LINESTRING', [('clase', 'INTEGER'), ('tipo', 'TEXT'), ('nombre', 'TEXT')],
        [(dec(s[2]), {'clase': s[0], 'tipo': CLASES[s[0]], 'nombre': g['names'][s[1]]}) for s in g['streets']],
        'Las calles del mapa (el grafo de cicloconecta y OSM), por clase',
        categorized('clase', [(i, CLASES[i], line('#5D6D7E', w)) for i, w in enumerate([1.1, 0.9, 0.7, 0.6, 0.35, 0.3, 0.3, 0.2])])
        + labels("nullif(\"nombre\", 'Calle sin nombre')", 7, 8000))
    N['via_ferrea'] = G.layer('via_ferrea', 'LINESTRING', [('linea', 'TEXT')],
        [(dec(g['rail']), {'linea': 'Línea Central'}), (dec(g['ramal']), {'linea': 'Ramal Talca–Constitución'})],
        'La vía férrea (OSM, pipeline/railway.py)', single(line('#4A235A', 0.6, dash=True)))
    r5 = json.load(open(DATA / 'ruta5.json'))
    def dm(a): return [(x/10, y/10) for x, y in dec(a)]
    N['ruta5'] = G.layer('ruta5', 'LINESTRING', [('parte', 'TEXT'), ('pistas', 'INTEGER')],
        [(dm(c['p']), {'parte': 'calzada'}) for c in r5['c']] + [(dm(k[1:]), {'parte': 'ramal', 'pistas': k[0]}) for k in r5['k']],
        'La Ruta 5: las dos calzadas y los ramales (data/ruta5.json)', single(line('#B9770E', 0.7)))

    rows = []
    for f, cfg in uso_files():
        for i, u in enumerate(cfg['usos']):
            r = u['poly'] if 'poly' in u else dec(g['blocks'][u['bi']][3])
            otros = {k: v for k, v in u.items() if k not in USO_COLS and k not in USO_GEOM}
            rows.append(([r], {'archivo': f, 'i': i, 'huella': entry_hash(u), **{c: u.get(c) for c in USO_COLS},
                               'auto': int(bool(u.get('auto'))), 'bi': u.get('bi'), 'otros': json.dumps(otros, ensure_ascii=False) if otros else None}))
    N['usos'] = G.layer('usos', 'POLYGON', [('archivo', 'TEXT'), ('i', 'INTEGER'), ('huella', 'TEXT')] + [(c, 'TEXT') for c in USO_COLS]
                        + [('auto', 'INTEGER'), ('bi', 'INTEGER'), ('otros', 'TEXT')], rows,
        'Usos de suelo (config/usos*.json), editables: pipeline/gis.py importar',
        categorized('uso', [(k, k, fill(c, 110, c, 0.4)) for k, c in USO_COL.items()], fill('#FF00FF', 110, '#FF00FF', 0.4)) + labels('nombre', 7, 6000))

    ed = json.load(open(DATA / 'edificios.json'))
    def rings_dm(R): return [[(x/10, y/10) for x, y in dec(r)] for r in R]
    N['edificios'] = G.layer('edificios', 'POLYGON', [('osm', 'TEXT'), ('alto_m', 'REAL'), ('tipo', 'TEXT'), ('pisos', 'INTEGER'),
                                                    ('techo', 'TEXT'), ('alto_estimado', 'INTEGER')],
        [(rings_dm(e[1]), {'osm': e[0], 'alto_m': e[2]/10, 'tipo': ed['tipos'][e[3]], 'pisos': e[4],
                           'techo': ed['techos'][e[5]] if e[5] >= 0 else None, 'alto_estimado': e[6]}) for e in ed['e']],
        'Los edificios de OSM que dibuja la página (data/edificios.json)', single(fill('#C0846A', 230, '#5B3A29', 0.1)))
    H = ed['h']; dec_h = edificios.h_decode(H)
    N['huellas'] = G.layer('huellas', 'POLYGON', [('fuente', 'TEXT'), ('alto_m', 'REAL'), ('tipo', 'TEXT'), ('pisos', 'INTEGER'), ('alto_estimado', 'INTEGER')],
        [([R], {'fuente': ed['fuentes'][H['c'][ci][4]], 'alto_m': H['c'][ci][0]/10, 'tipo': ed['tipos'][H['c'][ci][1]],
                'pisos': H['c'][ci][2], 'alto_estimado': H['c'][ci][3]}) for (R, _), ci in zip(dec_h, H['i'])],
        'Las huellas de Microsoft y Google (Overture) donde OSM no tiene el edificio, redondeadas como en la página',
        categorized('fuente', [('ms', 'Microsoft', fill('#D4A373', 200, '#7F5539', 0.1)), ('google', 'Google', fill('#CCD5AE', 200, '#606C38', 0.1))]))
    N['superficies'] = G.layer('superficies', 'POLYGON', [('tipo', 'TEXT')],
        [(rings_dm([s[0]]), {'tipo': ed['superficies'][s[1]]}) for s in ed['s']],
        'Estacionamientos, pasto, jardines, piscinas y juegos de OSM en las manzanas de edificios', single(fill('#A9CCE3', 120, '#5D6D7E', 0.1)))

    P = json.load(open(DATA / 'pois.json'))['pois']
    N['lugares'] = G.layer('lugares', 'POINT', [('id', 'TEXT'), ('nombre', 'TEXT'), ('categoria', 'TEXT'), ('capas', 'TEXT'),
                                                ('direccion', 'TEXT'), ('confianza', 'TEXT'), ('ficha', 'TEXT')],
        [((p['x'], p['y']), {'id': p['id'], 'nombre': p['n'], 'categoria': p['c'], 'capas': ', '.join(p.get('cs') or []),
                             'direccion': p.get('a'), 'confianza': p.get('conf'), 'ficha': p.get('d')}) for p in P],
        'Los lugares del mapa (pipeline/pois.py; x, y: la dirección, no el centro del hito)', single(marker('#C0392B', 2.6)) + labels('nombre', 8))
    G.close()
    write_project(out, G, wgs84)
    print(f"{out / 'talca.gpkg'} ({(out / 'talca.gpkg').stat().st_size / 1e6:.0f} MB, {'EPSG:4326' if wgs84 else 'metros de grilla'}) y {out / 'talca.qgs'}:")
    print('  ' + ', '.join(f'{k} {v}' for k, v in N.items()))

# ------------------------------------------------------------------------------------------------ the QGIS project
ORDER = ['lugares', 'calles', 'via_ferrea', 'ruta5', 'rios', 'edificios', 'huellas', 'superficies', 'usos', 'agua', 'manzanas', 'limite']
HIDDEN = {'huellas', 'superficies', 'manzanas'}                  # in the project but off: the city is dense
WKBT = {'POINT': 'Point', 'LINESTRING': 'LineString', 'POLYGON': 'Polygon', 'MULTIPOLYGON': 'MultiPolygon'}
GEOM = {'POINT': 'Point', 'LINESTRING': 'Line', 'POLYGON': 'Polygon', 'MULTIPOLYGON': 'Polygon'}
XYZ = [('esri', 'Esri World Imagery (Maxar; en la ciudad z18–19 es de 2015: CLAUDE.md)',
        'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}', 19, True),
       ('osm', 'OpenStreetMap', 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', 19, False)]

def _x(s): return s.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;').replace('"', '&quot;')

def write_project(out, G, wgs84):
    """talca.qgs next to the GeoPackage (relative paths): the layers with their styles, the Esri imagery and OSM below,
    in the grid's CRS (or EPSG:4326), opening on the Plaza de Armas."""
    def srs(wkt, desc, auth='', sid=0, geo=False, proj4=''):
        # every field QGIS writes: with only <wkt> the project's CRS reads as invalid
        return (f'<spatialrefsys nativeFormat="Wkt"><wkt>{_x(wkt)}</wkt><proj4>{proj4}</proj4><srsid>{sid}</srsid><srid>{sid}</srid>'
                f'<authid>{auth}</authid><description>{_x(desc)}</description><projectionacronym></projectionacronym>'
                f'<ellipsoidacronym></ellipsoidacronym><geographicflag>{"true" if geo else "false"}</geographicflag></spatialrefsys>')
    crs = srs(WGS84_WKT1, 'WGS 84', 'EPSG:4326', 3452, True, '+proj=longlat +datum=WGS84 +no_defs') if wgs84 else srs(grid_wkt(), 'Talca, metros de grilla')
    merc = srs('', 'WGS 84 / Pseudo-Mercator', 'EPSG:3857', 3857, False,
               '+proj=merc +a=6378137 +b=6378137 +lat_ts=0 +lon_0=0 +x_0=0 +y_0=0 +k=1 +units=m +nadgrids=@null +wktext +no_defs')
    lid = lambda n: f'talca_{n}_capa'                          # QGIS 3.34 replaces a layer id of 10 characters or fewer
    L = {name: (kind, title, qml) for name, kind, title, qml in G.layers}
    tree, maps = [], []
    for name in ORDER:
        kind, title, qml = L[name]
        on = 'Qt::Unchecked' if name in HIDDEN else 'Qt::Checked'
        tree.append(f'<layer-tree-layer id="{lid(name)}" name="{name}" source="./talca.gpkg|layername={name}" providerKey="ogr" checked="{on}" expanded="0"/>')
        maps.append(f'<maplayer type="vector" geometry="{GEOM[kind]}" wkbType="{WKBT[kind]}" '
                    f'labelsEnabled="{int("<labeling" in qml)}" autoRefreshMode="Disabled" styleCategories="AllStyleCategories" hasScaleBasedVisibilityFlag="0">'
                    f'<id>{lid(name)}</id><datasource>./talca.gpkg|layername={name}</datasource><layername>{name}</layername>'
                    f'<abstract>{_x(title)}</abstract><srs>{crs}</srs><provider encoding="UTF-8">ogr</provider>{qml}</maplayer>')
    for key, title, url, zmax, on in XYZ:
        src = _x(f'type=xyz&url={url}&zmax={zmax}&zmin=0')
        tree.append(f'<layer-tree-layer id="{lid(key)}" name="{_x(title)}" source="{src}" providerKey="wms" checked="{"Qt::Checked" if on else "Qt::Unchecked"}" expanded="0"/>')
        maps.append(f'<maplayer type="raster" autoRefreshMode="Disabled"><id>{lid(key)}</id><datasource>{src}</datasource>'
                    f'<layername>{_x(title)}</layername><srs>{merc}</srs><provider>wms</provider></maplayer>')
    if wgs84:
        (la0, lo0), (la1, lo1) = unloc(-1200, -900), unloc(1200, 900); ext = (lo0, la0, lo1, la1)
    else: ext = (-1200, -900, 1200, 900)
    order = ''.join(f'<item>{lid(n)}</item>' for n in ORDER + [x[0] for x in XYZ])
    (out / 'talca.qgs').write_text(
        f'<!DOCTYPE qgis PUBLIC \'http://mrcc.com/qgis.dtd\' \'SYSTEM\'>\n<qgis projectname="Talca isométrica" version="3.34.0">\n'
        f'<title>Talca isométrica</title><projectCrs>{crs}</projectCrs>\n'
        f'<layer-tree-group>{"".join(tree)}<custom-order enabled="0">{order}</custom-order></layer-tree-group>\n'
        f'<mapcanvas name="theMapCanvas"><units>{"degrees" if wgs84 else "meters"}</units><extent><xmin>{ext[0]}</xmin><ymin>{ext[1]}</ymin>'
        f'<xmax>{ext[2]}</xmax><ymax>{ext[3]}</ymax></extent><rotation>0</rotation><destinationsrs>{crs}</destinationsrs></mapcanvas>\n'
        f'<projectlayers>{"".join(maps)}</projectlayers>\n'
        '<properties><Paths><Absolute type="bool">false</Absolute></Paths><SpatialRefSys><ProjectionsEnabled type="int">1</ProjectionsEnabled></SpatialRefSys>'
        '<Measurement><DistanceUnits type="QString">meters</DistanceUnits><AreaUnits type="QString">m2</AreaUnits></Measurement></properties>\n'
        '</qgis>\n')

# ------------------------------------------------------------------------------------------------ the way back
def ring_back(R, wgs84):
    """A ring read from the GeoPackage -> integer grid metres, without repeated vertices."""
    out = []
    for p in R:
        x, y = loc(p[0], p[1]) if wgs84 else p
        q = [int(math.floor(x + 0.5)), int(math.floor(y + 0.5))]
        if not out or q != out[-1]: out.append(q)
    while len(out) > 1 and out[0] == out[-1]: out.pop()
    return out

def cmd_importar(archivo=None, *, escribir=False):
    """`gis.py importar [archivo.gpkg] [--escribir]`: the `usos` layer back into config/usos*.json."""
    from usos import USOS, write
    path = Path(archivo) if archivo else OUT / 'talca.gpkg'
    db = sqlite3.connect(f'file:{require(path, "Ejecute primero: python pipeline/gis.py exportar")}?mode=ro', uri=True)
    srs = db.execute("SELECT srs_id FROM gpkg_geometry_columns WHERE table_name = 'usos'").fetchone()
    if not srs: raise SystemExit(f'{path} no tiene la capa usos')
    wgs84 = srs[0] == 4326
    if srs[0] not in (4326, SRS): raise SystemExit(f'la capa usos está en el srs_id {srs[0]}: guárdela en la grilla o en EPSG:4326')
    cols = [r[1] for r in db.execute('PRAGMA table_info(usos)')]
    feats = [dict(zip(cols, r)) for r in db.execute('SELECT * FROM usos')]
    g = json.load(open(DATA / 'geometry.json')); files = dict(uso_files())
    seen, changed, new, errors, stale = set(), [], [], [], set()
    for f in feats:
        kind, geo = read_gpb(f['geom'])
        tag = f"fid {f['fid']}" + (f" ({f['archivo']} #{f['i']}, «{f.get('nombre') or ''}»)" if f.get('archivo') else f" («{f.get('nombre') or ''}»)")
        if kind == 'MULTIPOLYGON':
            if len(geo) != 1: errors.append(f'{tag}: {len(geo)} polígonos; un uso es uno solo'); continue
            kind, geo = 'POLYGON', geo[0]
        if kind != 'POLYGON': errors.append(f'{tag}: sin polígono'); continue
        if len(geo) > 1: errors.append(f'{tag}: tiene {len(geo) - 1} hueco(s); un uso no lleva huecos (un uso dentro de otro es su hijo)'); continue
        ring = ring_back(geo[0], wgs84)
        if len(ring) < 3: errors.append(f'{tag}: menos de tres vértices'); continue
        try: otros = json.loads(f['otros']) if f.get('otros') else {}
        except json.JSONDecodeError as e: errors.append(f'{tag}: `otros` no es JSON ({e})'); continue
        attrs = {c: f[c] for c in USO_COLS if f.get(c) not in (None, '')}
        if attrs.get('uso') not in USOS: errors.append(f"{tag}: uso «{attrs.get('uso')}» desconocido (usos.py: {', '.join(USOS)})"); continue
        if f.get('archivo') is None:
            miss = [c for c in ('fuente', 'confianza') if c not in attrs]
            if miss: errors.append(f"{tag}: entrada nueva sin {' ni '.join(miss)}"); continue
            if attrs['confianza'] not in ('alta', 'media', 'baja'): errors.append(f'{tag}: confianza alta, media o baja'); continue
            new.append((tag, {**{k: attrs[k] for k in ('uso', 'nombre') if k in attrs}, 'poly': ring,
                              **{k: attrs[k] for k in ('fuente', 'confianza', 'nota') if k in attrs}, **otros})); continue
        fn, i = f['archivo'], f['i']
        if fn not in files or i is None or i >= len(files[fn]['usos']): errors.append(f'{tag}: no está en config/'); continue
        if (fn, i) in seen: errors.append(f'{tag}: repetida (¿copió el polígono? una copia nueva va sin archivo ni i)'); continue
        seen.add((fn, i)); u = files[fn]['usos'][i]
        if entry_hash(u) != f['huella']: stale.add(fn); continue
        v = {k: x for k, x in u.items()}
        old = u['poly'] if 'poly' in u else dec(g['blocks'][u['bi']][3])
        what = []
        if ring != ring_back(old, False):                         # the same cleaning on both sides (some rings repeat vertices)
            if u['uso'] == 'vivienda' and 'bi' in u and 'poly' not in u:
                errors.append(f'{tag}: una vivienda con bi marca su manzana; su polígono no se cambia aquí'); continue
            v['poly'] = ring; what.append(f'polígono ({len(old)} -> {len(ring)} vértices)')
            if v.pop('auto', None): what.append('deja de ser de OSM (auto)')
        for c in USO_COLS:
            if (attrs.get(c) or None) != (u.get(c) or None):           # '' and NULL are the same (QGIS turns one into the other)
                what.append(f'{c}: {u.get(c)!r} -> {attrs.get(c)!r}')
                if c in attrs: v[c] = attrs[c]
                else: v.pop(c, None)
        cur = {k: x for k, x in u.items() if k not in USO_COLS and k not in USO_GEOM}
        if otros != cur:
            what.append(f'otros: {json.dumps(cur, ensure_ascii=False)} -> {json.dumps(otros, ensure_ascii=False)}')
            for k in cur: v.pop(k)
            v.update(otros)
        if what:
            order = [k for k in u if k in v] + [k for k in v if k not in u]
            changed.append((tag, fn, i, {k: v[k] for k in order}, what))
    gone = [(fn, i, u.get('nombre') or u['uso']) for fn, cfg in files.items() for i, u in enumerate(cfg['usos'])
            if (fn, i) not in seen and fn not in stale]
    for fn in sorted(stale): print(f'{fn} cambió desde la exportación: sus entradas no se tocan (exporte de nuevo y rehaga la edición)')
    for tag, fn, i, v, what in changed: print(f'cambia {tag}: ' + '; '.join(what))
    for tag, v in new: print(f"nueva {tag}: {v['uso']}, {len(v['poly'])} vértices -> al final de usos.json")
    for fn, i, n in gone: print(f'borrada en QGIS: {fn} #{i} «{n}» (no se quita: hágalo a mano, con TALCA_USOS_ORDEN=ok para make check)')
    for e in errors: print(f'error {e}')
    if not (changed or new): print('nada que cambiar' if not errors else ''); return 1 if errors else 0
    if not escribir: print('(sin --escribir: no se cambió nada)'); return 1 if errors else 0
    from usos import with_bc
    touched = set()
    for tag, fn, i, v, what in changed: files[fn]['usos'][i] = v; touched.add(fn)
    if new: files['usos.json']['usos'] += [v for _, v in new]; touched.add('usos.json')
    for fn in touched: with_bc(files[fn]['usos'], g); write(files[fn], fn)
    print(f"escrito: {', '.join(f'config/{f}' for f in sorted(touched))}. Siga con: python pipeline/usos.py check && make build")
    return 1 if errors else 0

def cmd_crs(*, proj=False):
    """`gis.py crs [--proj]`."""
    print(grid_proj() if proj else grid_wkt())

if __name__ == '__main__':
    r = cli.run({'exportar': cmd_exportar, 'importar': cmd_importar, 'crs': cmd_crs}, __doc__)
    sys.exit(r or 0)
