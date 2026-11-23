"""Unit tests of the pipeline's shared code (make check runs them: python3 -m unittest discover -s tests).

  - the machine-learning footprints (data/edificios.json "h"): pipeline/edificios.py h_encode -> h_decode gives back
    the rings h_encode says it wrote, and the template's decoder (edDecodeH in src/js/52-edificios.js, run with node)
    gives the same numbers and seeds as h_decode: a guard between the two languages (trap «Las huellas de aprendizaje
    automático»);
  - geom.py: dec(enc()), in_ring against pip over 10 000 random points of the commune, clip_line's cut points on the
    ring; common.loc/unloc are inverse;
  - cli.py: arguments, flags and the errors that end with the usage;
  - gis.py: GeoPackage geometries written and read back, the grid's PROJ operation is common.loc, and a vertex taken
    to EPSG:4326 and back rounds to the same integer metre;
  - mapillary.py: a vector tile written here is read back (properties of every type, points and lines), a point of a
    tile lands in that tile, the bearing from the grid to true north (the grid's +y points 5° east of north), and the
    poles of postes along a segment and where the lines of cruce meet.
Standard library only; ~0.2 s. The tests that need raw/ (the commune's limit) or node are skipped without them.
"""
import contextlib, io, json, math, random, shutil, subprocess, sys, unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / 'pipeline'))
import cli, geom, common, edificios, gis, mapillary

LIMIT = common.RAW / 'osm' / 'comuna-talca.json'

def footprints():
    """A fixed set of footprints, in the order of the template, that exercises every branch of h_encode: rectangles in
    a row (the direction of the one before), an L, a rotated rectangle, a non-rectilinear one, a tiny one."""
    rot = lambda pts, a, o: [(o[0] + x*math.cos(a) - y*math.sin(a), o[1] + x*math.sin(a) + y*math.cos(a)) for x, y in pts]
    R = [[(0, 0), (8.1, 0.1), (8.0, 10.2), (-0.1, 10)],
         [(8.0, 0.1), (16.2, 0.2), (16.1, 10.3), (8.0, 10.2)],
         [(30, 0), (42, 0), (42, 5), (36, 5), (36, 12), (30, 12)],
         rot([(0, 0), (12, 0), (12, 7), (0, 7)], math.radians(31.7), (100.3, -50.8)),
         rot([(0, 0), (20, 0), (20, 9), (0, 9)], math.radians(-12.4), (-2000.4, 3300.9)),
         [(200, 200), (215, 203), (209, 214), (198, 211)],
         [(-500.2, -700.1), (-490.1, -699.7), (-489.9, -689.6), (-495, -684), (-500.1, -690.2)],
         rot([(0, 0), (9, 0), (9, 4), (5, 4), (5, 9), (0, 9)], math.radians(77.0), (5100, 2400))]
    return R

def js_decoder():
    """The source of edDecodeH(H) in src/js/52-edificios.js (a pure function: it reads nothing else)."""
    t = (ROOT / 'src' / 'js' / '52-edificios.js').read_text()
    i = t.index('function edDecodeH('); k = t.index('{', i); depth = 0
    for j in range(k, len(t)):
        depth += {'{': 1, '}': -1}.get(t[j], 0)
        if not depth: return t[i:j+1]
    raise AssertionError('edDecodeH sin cerrar')

def node_decode(Hs):
    """edDecodeH of each "h" of Hs, run by node in one process: [[[ring, seed], …], …], or None without node."""
    node = shutil.which('node')
    if not node: return None
    js = js_decoder() + '\nconst Hs=JSON.parse(require("fs").readFileSync(0,"utf8"));process.stdout.write(JSON.stringify(Hs.map(H=>edDecodeH(H).map(f=>[f.R,f.s]))));'
    r = subprocess.run([node, '-e', js], input=json.dumps(Hs), capture_output=True, text=True, check=True)
    return json.loads(r.stdout)

def head(H, n):
    """The first n footprints of an "h" (n, o and l cut where they end)."""
    l = sum(N - 2 if N >= 0 else 2*(-N - 1) for N in ((2*(k // (2*H['K'])) + 4) if k >= 0 else k for k in H['n'][:n]))
    return dict(H, n=H['n'][:n], o=H['o'][:2*n], l=H['l'][:l])

class Huellas(unittest.TestCase):
    def test_round_trip(self):
        G, rings, nr = edificios.h_encode(footprints())
        self.assertGreaterEqual(nr, 5)
        self.assertEqual([r for r in rings if r], [list(map(tuple, r)) for r, _ in edificios.h_decode(dict(G, q=edificios.HQ, K=edificios.HK))])
        for r, g in zip(footprints(), rings):   # each within HTOL of its source
            if g: self.assertLessEqual(edificios.h_dev(r, g), edificios.HTOL + 1e-9)

    def test_template_decodes_the_same(self):
        G, _, _ = edificios.h_encode(footprints()); H = dict(G, q=edificios.HQ, K=edificios.HK)
        cases = [H]
        ed = ROOT / 'data' / 'edificios.json'
        if ed.exists():   # the real thing: rows, shared walls, polygons
            with open(ed) as f: cases.append(head(json.load(f)['h'], 400))
        out = node_decode(cases)
        if out is None: self.skipTest('sin node')
        for H, js in zip(cases, out):
            py = edificios.h_decode(H)
            self.assertEqual(len(js), len(py))
            for (jr, js_), (pr, ps) in zip(js, py):
                self.assertEqual(js_, ps)
                self.assertEqual([tuple(p) for p in jr], [tuple(p) for p in pr])

class Geom(unittest.TestCase):
    def test_enc_dec(self):
        rnd = random.Random(7); pts = [(rnd.randint(-9000, 9000), rnd.randint(-9000, 9000)) for _ in range(500)]
        self.assertEqual(geom.dec(geom.enc(pts)), pts)
        dm = [(x/10, y/10) for x, y in pts]
        self.assertEqual([(x/10, y/10) for x, y in geom.dec(geom.enc(dm, 10))], dm)

    def test_loc_unloc(self):
        rnd = random.Random(3)
        for _ in range(2000):
            x, y = rnd.uniform(-5000, 16000), rnd.uniform(-11000, 13000)
            la, lo = common.unloc(x, y); X, Y = common.loc(lo, la)
            self.assertLess(math.hypot(X - x, Y - y), 1e-6)

    @unittest.skipUnless(LIMIT.exists(), 'sin raw/osm/comuna-talca.json')
    def test_in_ring_is_pip(self):
        R = common.comuna(); x0, y0, x1, y1 = geom.bbox(R); rnd = random.Random(11)
        pts = [(rnd.uniform(x0, x1), rnd.uniform(y0, y1)) for _ in range(10000)]
        pts += [R[k] for k in range(0, len(R), 7)] + [(p[0], R[k][1]) for k, p in zip(range(0, len(R), 5), pts)]   # on vertices and their rows
        ref = [geom.pip(p, R) for p in pts]
        self.assertEqual([geom.in_ring(p, R) for p in pts], ref)
        self.assertTrue(500 < sum(ref) < 9500)

    @unittest.skipUnless(LIMIT.exists(), 'sin raw/osm/comuna-talca.json')
    def test_clip_line(self):
        R = common.comuna(); x0, y0, x1, y1 = geom.bbox(R); rnd = random.Random(5)
        edge = lambda q: min(geom.seg_dist(q, R[i-1], R[i]) for i in range(len(R)))
        for _ in range(15):
            line = [(rnd.uniform(x0 - 2000, x1 + 2000), rnd.uniform(y0 - 2000, y1 + 2000)) for _ in range(6)]
            for part in geom.clip_line(line, R):
                for q in (part[0], part[-1]):   # each end: a vertex of the line inside, or a point on the limit
                    self.assertTrue(q in line and geom.in_ring(q, R) or edge(q) < 1e-6, q)
                for a, b in zip(part, part[1:]):   # each stretch inside
                    self.assertTrue(geom.in_ring(((a[0]+b[0])/2, (a[1]+b[1])/2), R))

    def test_scanlines(self):
        r = [(0, 0), (10, 0), (10, 10), (5, 4), (0, 10)]
        rows = geom.scanlines([r], -0.5, 1, 12)
        for j in range(12):
            self.assertEqual(rows.get(j, []), geom.crossings_at(r, -0.5 + j) if -0.5 + j >= 0 else [])

class Gis(unittest.TestCase):
    def test_geometry_blobs(self):
        ring = [(0.0, 0.0), (10.5, 0.0), (10.5, 7.0), (0.0, 7.0)]; hole = [(2.0, 2.0), (3.0, 2.0), (3.0, 3.0)]
        for kind, g, back in [('POINT', (1.5, -2.0), (1.5, -2.0)), ('LINESTRING', ring, ring), ('POLYGON', [ring, hole], [ring, hole]),
                              ('MULTIPOLYGON', [[ring], [hole]], [[ring], [hole]])]:
            xy = [g] if kind == 'POINT' else ring
            self.assertEqual(gis.read_gpb(gis.gpb(gis.SRS, kind, g, xy)), (kind, back))

    def test_grid_operation_is_loc(self):
        o = dict(kv.split('=') for kv in gis.grid_proj().split()[1:]); o = {k[1:]: float(v) for k, v in o.items()}
        rnd = random.Random(5)
        for _ in range(500):
            lon, lat = rnd.uniform(-71.75, -71.45), rnd.uniform(-35.55, -35.3); x, y = common.loc(lon, lat)
            self.assertLess(abs(o['xoff'] + o['s11']*lon + o['s12']*lat - x), 1e-6)
            self.assertLess(abs(o['yoff'] + o['s21']*lon + o['s22']*lat - y), 1e-6)

    def test_wgs84_round_trip(self):
        rnd = random.Random(9); R = [[rnd.randint(-4900, 15800), rnd.randint(-10800, 13000)] for _ in range(2000)]
        ll = [common.unloc(x, y) for x, y in R]
        self.assertEqual(gis.ring_back([(lo, la) for la, lo in ll], True), R)

class Cli(unittest.TestCase):
    """pipeline/cli.py: a command's signature is its syntax."""
    def call(self, f, *args): return cli.call(f, list(args), 'uso')

    def test_arguments_and_flags(self):
        def f(name, x: float, z: int = 18, *, eps: float = 1.5, todo=False, map_=None, origin: (float, float) = None,
              geo: cli.maybe(float, 100) = None): return name, x, z, eps, todo, map_, origin, geo
        self.assertEqual(self.call(f, 'a', '-2.5'), ('a', -2.5, 18, 1.5, False, None, None, None))
        self.assertEqual(self.call(f, 'a', '1', '17', '--eps', '2', '--todo', '--map=comuna', '--origin', '1', '-2', '--geo'),
                         ('a', 1.0, 17, 2.0, True, 'comuna', (1.0, -2.0), 100))
        self.assertEqual(self.call(f, '--geo', '150', 'a', '1')[-1], 150.0)
        self.assertEqual(self.call(f, '--geo', 'a', '1')[:2], ('a', 1.0))   # not a number: the next argument stays positional
        def g(*conds): return conds
        self.assertEqual(self.call(g, 'k=v', 'j=w'), ('k=v', 'j=w'))

    def test_errors_exit_with_the_usage(self):
        def f(name, x: float, z=18, *, eps: float = 1.5, todo=False): pass
        for args in (['a'], ['a', '1', '2', '3'], ['a', '1', '--bogus'], ['a', 'uno'], ['a', '1', '--eps'], ['a', '1', '--todo=1']):
            with self.assertRaises(SystemExit) as e: self.call(f, *args)
            self.assertIsInstance(e.exception.code, str)   # a message: exit code 1
            self.assertTrue(e.exception.code.endswith('uso'))

    def test_run(self):
        out = []
        cli.run({'a': lambda *, k=False: out.append(('a', k))}, 'uso', ['a', '--k'])
        cli.run({}, 'uso', ['x', 'y'], default=lambda *v: out.append(v))
        self.assertEqual(out, [('a', True), ('x', 'y')])
        with self.assertRaises(SystemExit) as e: cli.run({'a': print}, 'uso', ['b'])
        self.assertIn('comando desconocido', e.exception.code)
        with self.assertRaises(SystemExit) as e, contextlib.redirect_stdout(io.StringIO()): cli.run({'a': print}, 'uso', ['--help'])
        self.assertEqual(e.exception.code, 0)

def _pb(field, wire, v):
    """One protobuf field (a test writer for mapillary.mvt): varint (0) or length-delimited (2) or fixed64 (1)."""
    def var(n):
        out = bytearray()
        while True:
            b = n & 0x7f; n >>= 7
            if n: out.append(b | 0x80)
            else: out.append(b); return bytes(out)
    key = var(field << 3 | wire)
    if wire == 0: return key + var(v)
    if wire == 1: return key + v
    return key + var(len(v)) + v

def _packed(vals):
    return b''.join(_pb(0, 0, v)[1:] for v in vals)     # the key byte of field 0 is a single 0: drop it

class Mapillary(unittest.TestCase):
    def tile(self):
        import struct
        zz = lambda n: (n << 1) ^ (n >> 63)
        keys = ['id', 'captured_at', 'compass_angle', 'is_pano', 'sequence_id']
        vals = [_pb(5, 0, 4321987654321), _pb(4, 0, 1700000000000), _pb(3, 1, struct.pack('<d', 271.5)), _pb(7, 0, 1),
                _pb(1, 2, b'seqA'), _pb(6, 0, zz(-3))]
        pt = _pb(1, 0, 7) + _pb(2, 2, _packed([0, 0, 1, 1, 2, 2, 3, 3, 4, 4])) + _pb(3, 0, 1) + \
             _pb(4, 2, _packed([1 << 3 | 1, zz(100), zz(4000)]))
        ln = _pb(2, 2, _packed([4, 5])) + _pb(3, 0, 2) + \
             _pb(4, 2, _packed([1 << 3 | 1, zz(10), zz(20), 2 << 3 | 2, zz(5), zz(-5), zz(-15), zz(0)]))
        layer = _pb(15, 0, 2) + _pb(1, 2, b'image') + _pb(2, 2, pt) + _pb(2, 2, ln) + \
                b''.join(_pb(3, 2, k.encode()) for k in keys) + b''.join(_pb(4, 2, v) for v in vals) + _pb(5, 0, 4096)
        return _pb(3, 2, layer)

    def test_mvt(self):
        import gzip
        for b in (self.tile(), gzip.compress(self.tile())):
            ext, feats = mapillary.mvt(b)['image']
            self.assertEqual(ext, 4096)
            (p, typ, parts), (q, typ2, parts2) = feats
            self.assertEqual((typ, parts), (1, [[(100, 4000)]]))
            self.assertEqual(p, {'id': 4321987654321, 'captured_at': 1700000000000, 'compass_angle': 271.5,
                                 'is_pano': True, 'sequence_id': 'seqA'})
            self.assertEqual((typ2, parts2), (2, [[(10, 20), (15, 15), (0, 15)]]))
            self.assertEqual(q, {'sequence_id': -3})                  # no id field: none is made up

    def test_along_meet(self):
        self.assertEqual(mapillary.along(320, 511, 425, 511, 370), (370.0, 511.0))     # along x: the pole at x 370
        self.assertEqual(mapillary.along(0, 0, 10, 40, 20), (5.0, 20.0))              # mostly along y: read as y
        s = math.sqrt(.5)
        p, ang = mapillary.meet([(0, 0, s, s), (10, 0, -s, s)])                         # two lines at right angles
        self.assertAlmostEqual(p[0], 5); self.assertAlmostEqual(p[1], 5); self.assertAlmostEqual(ang, 90)
        p, ang = mapillary.meet([(0, 0, 1, 0), (0, 2, 0, -1), (4, 0, 0, 1)])           # three: the nearest point
        self.assertAlmostEqual(p[1], 0); self.assertAlmostEqual(ang, 90)
        self.assertEqual(mapillary.meet([(0, 0, 1, 0), (0, 3, -1, 0)]), (None, 0.0))   # parallel

    def test_tiles(self):
        tiles = mapillary.tiles_of(14, -500, 500, -400, 400)
        self.assertTrue(1 <= len(tiles) <= 4)               # a z14 tile is ~2 km wide here
        lat, lon = common.unloc(0, 0)
        t = mapillary.tiles_of(14, 0, 0, 0, 0)[0]
        self.assertEqual(t, geom.tile_of(lat, lon, 14))
        lo0, la0 = mapillary.tile_lonlat(14, *t, 0, 0, 4096)          # the north-west corner (y runs south)
        lo1, la1 = mapillary.tile_lonlat(14, *t, 4096, 4096, 4096)    # the south-east one
        self.assertTrue(lo0 < lon < lo1 and la1 < lat < la0)
        self.assertAlmostEqual(lo1 - lo0, 360 / 2 ** 14)

    def test_cache(self):
        import tempfile
        from unittest import mock
        with tempfile.TemporaryDirectory() as d:
            f = Path(d) / 'teselas' / '14' / '1-2.pbf'
            f.parent.mkdir(parents=True); f.write_bytes(self.tile()[:-9])   # a download cut short
            with mock.patch.object(mapillary, 'OUT', Path(d)), \
                 mock.patch.object(mapillary.net, 'get', return_value=self.tile()) as get:
                ims = mapillary.tile_images(14, 1, 2, 'k')
                self.assertEqual((get.call_count, len(ims), ims[0][0]), (1, 1, '4321987654321'))
                self.assertEqual(f.read_bytes(), self.tile())             # downloaded again and kept whole
                mapillary.tile_images(14, 1, 2, 'k')
                self.assertEqual(get.call_count, 1)                       # then read from the cache
                get.return_value = b'<html>error</html>'
                with self.assertRaises(SystemExit): mapillary.tile_images(14, 1, 2, 'k', refresh=True)
                self.assertEqual(f.read_bytes(), self.tile())             # a page that is not a tile is not kept

    def test_bearing(self):
        lat, lon = common.unloc(0, 0)
        x, y = common.loc(lon, lat + 0.01)               # a point true north of the plaza
        self.assertAlmostEqual(mapillary.bearing(0, 0, x, y), 0, places=6)
        self.assertAlmostEqual(mapillary.bearing(0, 0, 0, 100), 5, places=6)
        self.assertAlmostEqual(mapillary.off(355, 10), 15)
        cam = ['i', 0, -50, 0, 5.0, 0, 's', 'u']           # 50 m south of the point on the grid, looking along +y
        self.assertEqual(mapillary.facing(cam, 0, 0, 80), (50, 0))
        self.assertIsNone(mapillary.facing(cam[:4] + [185.0] + cam[5:], 0, 0, 80))   # looking away
        self.assertIsNotNone(mapillary.facing(cam[:4] + [185.0, 1] + cam[6:], 0, 0, 80))   # a panorama sees it
        self.assertIsNone(mapillary.facing(cam, 0, 0, 40))  # too far

    def test_camera(self):
        # a level camera 50 m south of the plaza on the grid, looking along +y (5° east of true north): its matrix from
        # the world (east, north, up) to the camera (right, down, forward), as Mapillary's angle-axis
        t = math.radians(5)
        R = [[math.cos(t), -math.sin(t), 0], [0, 0, -1], [math.sin(t), math.cos(t), 0]]
        a = math.acos((R[0][0] + R[1][1] + R[2][2] - 1) / 2)
        v = [(R[2][1] - R[1][2]) * a / (2 * math.sin(a)), (R[0][2] - R[2][0]) * a / (2 * math.sin(a)), (R[1][0] - R[0][1]) * a / (2 * math.sin(a))]
        for row, want in zip(mapillary.rotation(v), R):
            for p, q in zip(row, want): self.assertAlmostEqual(p, q)
        lat, lon = common.unloc(0, -50)
        c = {'computed_rotation': v, 'computed_geometry': {'coordinates': [lon, lat]}, 'camera_type': 'perspective', 'camera_parameters': [0.6, 0, 0]}
        cam = mapillary.Camera(c, (1920, 1080), 1.5)
        self.assertAlmostEqual(cam.pitch, 0); self.assertAlmostEqual(cam.roll, 0)
        f = .6 * 1920 / 50                                  # pixels per metre at 50 m
        for (x, y, z), (u, w) in [((0, 0, 1.5), (960, 540)), ((0, 0, 6.5), (960, 540 - 5 * f)), ((5, 0, 1.5), (960 + 5 * f, 540))]:
            px = cam.at(x, y, z)
            self.assertAlmostEqual(px[0], u, delta=.5); self.assertAlmostEqual(px[1], w, delta=.5)
        self.assertIsNone(cam.at(0, -80, 1.5))              # behind it
        self.assertEqual(cam.line((0, -80, 0), (0, -60, 0)), [])
        (pl,) = cam.line((-3, -20, 0), (-3, 20, 0))          # a kerb from beside the camera to ahead of it: cut at its plane
        self.assertTrue(pl[-1][0] < 960 and pl[-1][1] > 540)  # left of and under the centre
        pano = mapillary.Camera({**c, 'camera_type': 'spherical'}, (2048, 1024), 1.5)
        self.assertAlmostEqual(pano.at(0, 0, 1.5)[0], 1024)
        u = pano.at(0, -100, 1.5)[0]; self.assertAlmostEqual(min(u, 2048 - u), 0, delta=.01)   # behind it: the seam


if __name__ == '__main__':
    unittest.main()
