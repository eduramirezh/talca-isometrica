"""Unit tests of the pipeline's shared code (make check runs them: python3 -m unittest discover -s tests).

  - the machine-learning footprints (data/edificios.json "h"): pipeline/edificios.py h_encode -> h_decode gives back
    the rings h_encode says it wrote, and the template's decoder (edDecodeH in src/js/52-edificios.js, run with node)
    gives the same numbers and seeds as h_decode: a guard between the two languages (trap «Las huellas de aprendizaje
    automático»);
  - geom.py: dec(enc()), in_ring against pip over 10 000 random points of the commune, clip_line's cut points on the
    ring; common.loc/unloc are inverse;
  - cli.py: arguments, flags and the errors that end with the usage;
  - gis.py: GeoPackage geometries written and read back, the grid's PROJ operation is common.loc, and a vertex taken
    to EPSG:4326 and back rounds to the same integer metre.
Standard library only; ~0.2 s. The tests that need raw/ (the commune's limit) or node are skipped without them.
"""
import contextlib, io, json, math, random, shutil, subprocess, sys, unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / 'pipeline'))
import cli, geom, common, edificios, gis

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

if __name__ == '__main__':
    unittest.main()
