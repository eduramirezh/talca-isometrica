# /// script
# requires-python = ">=3.10"
# dependencies = ["playwright==1.63", "pillow==13.0.0"]
# ///
"""El mapa en Chromium (Playwright), para las herramientas de tools/: lo que todas comparten.

  from page import Map, add_page_args, parse_views
  async with Map(size='390x844', dpr=2) as m:          # sirve dist/, abre Chromium, carga y espera a que esté quieto
      await m.run('__look(-60,30,4)')                 # corre JS (o una promesa) y espera el cuadro siguiente
      await m.page.screenshot(path='x.png')
  if m.errors(): raise SystemExit(1)                  # los errores de consola: el único filtro

No es una herramienta: lo importan screenshot, regress, variants, probe, perf, profile, gif, video, export y
site_assets. Tiene:
  serve()        dist/ (o TALCA_DIST) servido en 127.0.0.1 como lo sirve Cloudflare Pages (Site)
  GL             las banderas de Chromium para WebGL: swiftshader (sin GPU, por omisión), metal (la GPU de un Mac),
                 egl (la GPU de Linux), nvidia (la NVIDIA de un notebook Linux con dos GPU; GL_ENV) o gpu (metal en
                 un Mac; en Linux, nvidia si está su driver y si no egl): con GPU, cada cuadro se dibuja decenas de
                 veces más rápido (la carga no: es de la CPU); las imágenes pueden diferir de SwiftShader en algunos
                 píxeles
  launch()       un Chromium con esas banderas y su entorno (para una página que no es el mapa: export.py --vista, el ícono)
  Map            el mapa en una pestaña, como contexto async que cierra el navegador al salir: tamaño, densidad,
                 tema oscuro, GL, JS antes de la página (init), #hash, sin red externa (offline), una red emulada
                 (red: lenta, 4g), --android (el Chrome de un teléfono por adb) y cuándo está lista (ready):
                   'idle'   la generación terminó (window.__stats) y el mapa está quieto (window.__idle(), 99-boot.js)
                   'full'   la generación terminó (window.__stats; es cuando se llena __stats.load.full), sin esperar
                   'shown'  el primer cuadro está en pantalla (window.__three): la segunda etapa sigue en tajadas
                   None     no carga la página (m.url; luego m.load())
                 La carga espera hasta 300 s (TALCA_ESPERA=<s> la cambia); settle() espera a window.__idle() (con un dist/ anterior a él, 2,5 s); run(js) corre JS y espera;
                 hide() esconde la interfaz (HIDE); errors(), los errores de consola y de la página.
  add_page_args  --size --dpr --gl --init, iguales en todas; Map.from_args(a) los lee
  parse_views    las vistas y variantes «nombre=js» (la forma vieja «Nombre:js» sirve, con un aviso)
  diff()         los píxeles que difieren entre dos imágenes (un canal por más de 8) y su imagen en magenta
  ease()         0..1 suavizado (smoothstep), acotado
"""
import asyncio, email.utils, functools, gzip, http.server, mimetypes, os, subprocess, sys, threading
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
# the longest a load may take (a phone, a slow network, SwiftShader with a cold cache, a machine busy with other
# sessions): TALCA_ESPERA=<s> changes it
LOAD_MS = int(float(os.environ.get('TALCA_ESPERA', 300)) * 1000)
_SERVED = {}


class Site(http.server.SimpleHTTPRequestHandler):
    """dist/ as Cloudflare Pages serves it, so that the downloads weigh what they weigh on the site: text compressed
    (gzip; the site uses brotli, ~15 % smaller), assets/ cached without asking again (src/site/_headers), the rest
    revalidated (Last-Modified / If-Modified-Since)."""
    _gz = {}
    def log_message(self, *a): pass
    def end_headers(self):
        if self.path.startswith('/assets/'): self.send_header('Cache-Control', 'public, max-age=31536000, immutable')
        super().end_headers()
    def do_GET(self):
        f = Path(self.translate_path(self.path))
        if f.is_dir(): f = f / 'index.html'
        if not f.is_file() or f.suffix not in ('.html', '.js', '.json', '.css', '.svg') or 'gzip' not in self.headers.get('Accept-Encoding', ''):
            return super().do_GET()
        st = f.stat(); since = self.headers.get('If-Modified-Since')
        if since and not self.path.startswith('/assets/'):
            try:
                if int(st.st_mtime) <= email.utils.parsedate_to_datetime(since).timestamp():
                    self.send_response(304); self.end_headers(); return
            except (TypeError, ValueError): pass
        key = (f, st.st_mtime_ns)
        if key not in self._gz: self._gz[key] = gzip.compress(f.read_bytes(), 6)
        body = self._gz[key]
        self.send_response(200)
        self.send_header('Content-Type', mimetypes.guess_type(f.name)[0] or 'application/octet-stream')
        self.send_header('Content-Encoding', 'gzip'); self.send_header('Content-Length', str(len(body)))
        self.send_header('Last-Modified', email.utils.formatdate(st.st_mtime, usegmt=True))
        self.end_headers(); self.wfile.write(body)


def serve(port=0, root=None):
    """Sirve dist/ (u otro directorio, `root`; por omisión TALCA_DIST o dist/) en 127.0.0.1 como lo sirve Cloudflare
    Pages (Site), en un hilo, una vez por proceso y puerto (0: uno libre): devuelve la URL de la página."""
    root = Path(root or os.environ.get('TALCA_DIST') or ROOT / 'dist')
    if not (root / 'index.html').exists(): raise SystemExit(f'Falta {root}/index.html. Ejecute: make build')
    key = (port, str(root))
    if key not in _SERVED:
        srv = http.server.ThreadingHTTPServer(('127.0.0.1', port), functools.partial(Site, directory=str(root)))
        threading.Thread(target=srv.serve_forever, daemon=True).start()
        _SERVED[key] = f'http://localhost:{srv.server_address[1]}/index.html'
    return _SERVED[key]


# WebGL in Chromium without a window. swiftshader: no GPU (the default, and the one regress.py's and hitos.py's
# references are taken with); metal: a Mac's GPU, ~6 times faster; egl: Linux's default GPU through EGL (on a laptop
# with two, the integrated one); nvidia: the NVIDIA GPU of a Linux laptop with two (the same flags, with glvnd's NVIDIA
# EGL vendor, GL_ENV); gpu: metal on a Mac and egl elsewhere. --use-angle=vulkan gives no WebGL at all in
# chromium-headless-shell on Linux (Playwright 1.63, November 2026), and --use-gl=egl falls back to SwiftShader.
_EGL = ['--use-gl=angle', '--use-angle=gl-egl', '--enable-gpu', '--ignore-gpu-blocklist']
GL = {'swiftshader': ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'],
      'metal': ['--use-angle=metal', '--enable-gpu', '--ignore-gpu-blocklist'],
      'egl': _EGL, 'nvidia': _EGL}
NVIDIA_EGL = '/usr/share/glvnd/egl_vendor.d/10_nvidia.json'   # where Debian, Ubuntu, Fedora and Arch put it
GL_ENV = {'nvidia': {'__EGL_VENDOR_LIBRARY_FILENAMES': NVIDIA_EGL}}
# gpu: the fastest there is. On Linux, the NVIDIA one when its driver is there: in a laptop with an Intel UHD 630 and
# a GTX 1650 (November 2026, tools/perf.py, 1440x900), a frame of the whole comuna took 4980 ms with SwiftShader,
# 71 ms on the Intel and 15 ms on the NVIDIA (the plaza at zoom 4: 1275, 33 and 5 ms); the load, ~14 s, is the CPU's
GL['gpu'] = GL['metal' if sys.platform == 'darwin' else 'egl']
if sys.platform != 'darwin' and Path(NVIDIA_EGL).exists(): GL_ENV['gpu'] = GL_ENV['nvidia']
GL_HELP = ('WebGL: swiftshader (sin GPU), gpu (la del equipo: metal en un Mac; en Linux, nvidia si está su driver y si '
           'no egl), metal (la GPU del Mac), '
           'egl (la GPU de Linux por omisión; en un notebook con dos, la integrada) o nvidia (la NVIDIA de un notebook '
           'Linux con dos); con GPU, ~6 veces más rápido, pero las imágenes difieren de SwiftShader en algunos píxeles')

# network conditions (CDP Network.emulateNetworkConditions: ms of latency, bytes per second down and up): lenta, the
# phones' of Lighthouse; 4g
RED = {'lenta': (150, 1.6e6 / 8, 750e3 / 8), '4g': (60, 9e6 / 8, 1.5e6 / 8)}

# the interface over the map: the panel, the card, the loading notice, the scale and the controls; the markers and
# street names (#overlay) and the title (.brand) go too with hide(overlay=True, brand=True)
HIDE = '#panel,#card,#more,#scale,.ctrls{display:none!important}'

FRAME_JS = 'new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r)))'


async def launch(p, gl='swiftshader', args=()):
    """Chromium with GL's flags (WebGL on SwiftShader or a GPU) and GL_ENV's environment, plus args (heap.py:
    --enable-precise-memory-info)."""
    env = GL_ENV.get(gl)
    if env and not Path(NVIDIA_EGL).exists():
        raise SystemExit(f'--gl {gl}: no está {NVIDIA_EGL} (el EGL de NVIDIA de glvnd): ¿driver propietario instalado?')
    return await p.chromium.launch(args=GL[gl] + list(args), env={**os.environ, **env} if env else None)


def errors(logs):
    """The console's errors and the page's uncaught exceptions among logs ('tipo: texto' lines): the one filter."""
    return [l for l in logs if l.startswith(('error:', 'ERROR:'))]


def noise(l):
    """Lines of the log not worth printing: the GPU driver's performance notes (ReadPixels stalls and the like)."""
    return 'GL Driver Message' in l


class Map:
    """El mapa en una pestaña de Chromium (o del Chrome de un teléfono, android=True). Como contexto async:

        async with Map(size='390x844', dpr=2) as m: ...

    abre Playwright (o usa `p`, uno abierto), el navegador y la página, la carga según `ready` y al salir cierra el
    navegador (en el teléfono, solo la pestaña). m.page, m.logs ('tipo: texto'), m.url."""

    def __init__(self, size='1440x900', dpr=1, dark=False, gl='swiftshader', init=None, hash=None, offline=False,
                 ready='idle', url=None, red=None, android=False, port=8766, quiet=False, p=None, args=()):
        if ready not in ('idle', 'full', 'shown', None): raise ValueError(f'ready: {ready}')
        if red and android: raise SystemExit('--red no sirve con --android (va por USB): use --url para la red del teléfono')
        self.size, self.dpr, self.dark, self.gl, self.init, self.hash = size, dpr, dark, gl, init, hash
        self.offline, self.ready, self.red, self.android, self.port, self.quiet = offline, ready, red, android, port, quiet
        self._url, self._p, self._pw, self.browser, self.page, self.logs = url, p, None, None, None, []
        self.args = args  # more Chromium flags

    @classmethod
    def from_args(cls, a, **kw):
        """A Map with add_page_args()'s flags (--size --dpr --gl --init, those the tool has), plus keyword arguments
        (which win)."""
        base = {k: getattr(a, k) for k in ('size', 'dpr', 'gl', 'init') if getattr(a, k, None) is not None}
        return cls(**{**base, **kw})

    async def __aenter__(self):
        if self._p is None:
            from playwright.async_api import async_playwright
            self._pw = await async_playwright().start(); self._p = self._pw
        if self.android: self.browser = await self._android()
        else: self.browser = await launch(self._p, self.gl, self.args)
        self.page = await self.new_page()
        if self.ready: await self.load()
        return self

    async def __aexit__(self, *exc):
        await self.close()

    async def close(self):
        if self.android and self.page: await self.page.close()
        elif self.browser: await self.browser.close()
        self.browser = self.page = None
        if self._pw: await self._pw.stop(); self._pw = self._p = None

    @property
    def url(self):
        if self._url is None: self._url = serve(self.port if self.android else 0)
        return self._url + (f'#{self.hash}' if self.hash else '')

    async def _android(self):
        """The phone's Chrome over adb (USB debugging on, Chrome open): dist/ served on `port` and reversed to it."""
        adb = lambda *a: subprocess.run(['adb', *a], check=True, capture_output=True, text=True).stdout
        if 'device' not in adb('devices').split('\n', 1)[1]: raise SystemExit('adb no ve el teléfono: conéctelo, desbloquéelo y acepte la depuración USB')
        if self._url is None: self._url = serve(self.port)
        adb('reverse', f'tcp:{self.port}', f'tcp:{self.port}'); adb('forward', 'tcp:9222', 'localabstract:chrome_devtools_remote')
        return await self._p.chromium.connect_over_cdp('http://127.0.0.1:9222')

    async def new_page(self):
        """A tab with this map's settings, in a new browser context (an empty cache); on the phone, a new tab of its
        Chrome (its size and density are the phone's). It listens to the console into self.logs."""
        if self.android:
            pg = await self.browser.contexts[0].new_page(); await pg.bring_to_front()
        else:
            w, h = map(int, self.size.split('x'))
            ctx = await self.browser.new_context(viewport={'width': w, 'height': h}, color_scheme='dark' if self.dark else 'light',
                                                 has_touch=w < 800, is_mobile=w < 800, device_scale_factor=self.dpr)
            pg = await ctx.new_page()
        pg.on('console', lambda m: self.logs.append(f'{m.type}: {m.text}'))
        pg.on('pageerror', lambda e: self.logs.append(f'ERROR: {e}'))
        if self.offline:
            async def local(r): await (r.continue_() if r.request.url.startswith('http://localhost') else r.abort())
            await pg.route('**/*', local)
        if self.init: await pg.add_init_script(self.init)  # JS that runs before the page's (window.__STAGE=0, window.__KEEP)
        if self.red:
            cdp = await pg.context.new_cdp_session(pg); lat, down, up = RED[self.red]
            await cdp.send('Network.enable')
            await cdp.send('Network.emulateNetworkConditions', {'offline': False, 'latency': lat, 'downloadThroughput': down, 'uploadThroughput': up})
        return pg

    async def load(self, ready=None):
        """Navigates to the map and waits for it (ready, or the Map's)."""
        await self.page.goto(self.url, wait_until='domcontentloaded', timeout=LOAD_MS)
        await self.wait(ready or self.ready)

    async def reload(self, cold=False):
        """Loads the map again: in the same tab (with what the browser cached) or, cold, in a new context (no cache)."""
        if cold and not self.android:
            await self.page.context.close(); self.page = await self.new_page(); await self.load()
        elif self.android: await self.load()
        else: await self.page.reload(wait_until='domcontentloaded', timeout=LOAD_MS); await self.wait(self.ready)

    async def wait(self, ready):
        if ready == 'shown':
            await self.page.wait_for_function('window.__three', timeout=LOAD_MS); await self.frame(); return
        await self.page.wait_for_function('window.__stats', timeout=LOAD_MS)
        if ready == 'idle': await self.settle()
        if not self.quiet: print('stats:', await self.page.evaluate('JSON.stringify(window.__stats)'), flush=True)

    async def settle(self, timeout=60_000):
        """Waits until the map is still and a frame drawn after the call is on screen (window.__idle, 99-boot.js). A
        dist/ from before __idle (TALCA_DIST, --url of an older deployment) gets the old 2.5 s instead."""
        if await self.page.evaluate('typeof window.__idle==="function"'):
            await self.page.wait_for_function('window.__stats', timeout=LOAD_MS)
            await asyncio.wait_for(self.page.evaluate('window.__idle()'), timeout / 1000)
        else: await self.page.wait_for_timeout(2500)

    async def frame(self):
        """Two of the page's frames: one drawn, one shown."""
        await self.page.evaluate(FRAME_JS)

    async def run(self, js, settle=True):
        """Evaluates js (an expression, or one that returns a promise: it is awaited), then settles; its result."""
        r = await self.page.evaluate(js)
        if settle: await self.settle()
        return r

    async def stats(self):
        import json
        return json.loads(await self.page.evaluate('JSON.stringify(window.__stats||null)'))

    async def hide(self, overlay=False, brand=False):
        """Hides the interface (HIDE); overlay: the markers and street names too; brand: the title."""
        await self.page.add_style_tag(content=HIDE + ('#overlay{display:none!important}' if overlay else '') +
                                      ('.brand{display:none!important}' if brand else ''))

    def errors(self):
        return errors(self.logs)

    def print_logs(self, everything=False):
        """Prints the console's errors (everything: every line but the GPU driver's notes); returns the errors."""
        for l in self.logs if everything else self.errors():
            if not noise(l): print(l)
        return self.errors()


async def open_page(p, size='1440x900', dark=False, offline=False, hash=None, dpr=1, init=None, go=True, gl='swiftshader'):
    """La forma de antes de Map, para lo que la llame todavía: (navegador, página, logs), con la página cargada y
    quieta (go=False: sin cargar). El navegador lo cierra quien llama."""
    m = Map(size, dpr, dark, gl, init, hash, offline, ready='idle' if go else None, p=p)
    await m.__aenter__()
    return m.browser, m.page, m.logs


def add_page_args(ap, size='1440x900', dpr=1, gl='swiftshader', only=('size', 'dpr', 'gl', 'init')):
    """--size, --dpr, --gl and --init, the same in every tool (the defaults are the tool's; only: some of them)."""
    if 'size' in only: ap.add_argument('--size', default=size, help=f'ventana en píxeles CSS (por omisión {size})')
    if 'dpr' in only: ap.add_argument('--dpr', type=float, default=dpr, help=f'densidad de pantalla (2: Retina; por omisión {dpr:g})')
    if 'gl' in only: ap.add_argument('--gl', default=gl, choices=list(GL), help=f'{GL_HELP} (por omisión {gl})')
    if 'init' in only: ap.add_argument('--init', help='JS que corre antes que la página (window.__STAGE=0: la generación de una vez)')
    return ap


def parse_views(items, what='--view'):
    """['nombre=js', …] -> [(nombre, js), …]. The old form 'Nombre:js' (variants.py until November 2026) still works,
    with a warning: it is the one where a ':' comes before any '='."""
    out = []
    for v in items or []:
        i, j = v.find('='), v.find(':')
        if j >= 0 and (i < 0 or j < i):
            print(f'aviso: {what} «{v[:40]}» usa la forma vieja nombre:js; use nombre=js', file=sys.stderr)
            name, js = v[:j], v[j + 1:]
        elif i >= 0: name, js = v[:i], v[i + 1:]
        else: raise SystemExit(f'{what} espera nombre=expresión JS: {v}')
        out.append((name.strip(), js))
    return out


def diff(a, b, umbral=8):
    """The pixels where image b differs from a (some channel by more than umbral): (share in %, count, image with
    them in magenta over a in light grey). Different sizes: (100, None, b)."""
    from PIL import Image, ImageChops
    a, b = a.convert('RGB'), b.convert('RGB')
    if a.size != b.size: return 100.0, None, b
    m = ImageChops.difference(a, b).convert('L').point(lambda v: 255 if v > umbral else 0)
    n = m.histogram()[255]
    grey = Image.blend(a.convert('L').convert('RGB'), Image.new('RGB', a.size, 'white'), 0.5)
    return 100 * n / (a.size[0] * a.size[1]), n, Image.composite(Image.new('RGB', a.size, (255, 0, 200)), grey, m)


def ease(t):
    """Smoothstep of t clamped to 0..1."""
    t = min(max(t, 0), 1); return t * t * (3 - 2 * t)


def alias(ap, old, new, **kw):
    """An old flag that still works (with a warning) for its new name `new` (a flag already added to ap)."""
    import argparse
    dest = new.lstrip('-').replace('-', '_')
    class Old(argparse.Action):
        def __call__(self, parser, ns, values, option_string=None):
            print(f'aviso: {old} ahora es {new}', file=sys.stderr)
            setattr(ns, dest, values if self.nargs != 0 else True)
    ap.add_argument(old, action=Old, help=argparse.SUPPRESS, **kw)
