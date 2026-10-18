"""Captura de pantalla del mapa con Chromium sin interfaz (Playwright), para revisar cambios.

  python tools/screenshot.py shots/centro.png                       # 1440x900, vista inicial
  python tools/screenshot.py shots/corte.png --hash corte-apelaciones
  python tools/screenshot.py shots/movil.png --size 390x844 --dark --dpr 3
  python tools/screenshot.py shots/noche.png --js "document.querySelector('#night').click()"
  python tools/screenshot.py shots/ruta.png --hash justicia          # inicia un recorrido
  python tools/screenshot.py shots/puente.png --js "__look(-1640,533,6,Math.PI/4+Math.PI)"  # cámara en (x, y) de grilla, zoom, giro
  python tools/screenshot.py shots/ --view "plaza=__look(-60,30,14.2)" --view "giro=__look(-60,30,14.2,Math.PI/4+Math.PI/2)"
      # varias vistas de una sola carga (shots/plaza.png, shots/giro.png): genera una vez, no una por captura
  python tools/screenshot.py shots/smoke.png --strict             # termina con código 1 si hay errores de consola o la
      # generación sale vacía (sin edificios, árboles o vértices): es `make smoke`, la prueba de humo del repo

Sirve dist/ (make build) en un puerto local (la página pide sus datos con fetch, que no funciona desde file://); todo
lo que necesita, three.js incluido, está ahí, así que funciona sin internet salvo las fuentes de Google. Imprime las estadísticas de generación (edificios, vértices, árboles, ms) y los
errores de consola.
"""
import argparse, asyncio, email.utils, functools, gzip, http.server, mimetypes, os, threading
from pathlib import Path
from playwright.async_api import async_playwright

ROOT = Path(__file__).resolve().parent.parent
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
    Pages (Site), en un hilo, una vez por proceso y puerto (0: uno libre): devuelve la URL de la página. También la
    usan perf.py y profile.py."""
    root = Path(root or os.environ.get('TALCA_DIST') or ROOT / 'dist')
    if not (root / 'index.html').exists(): raise SystemExit(f'Falta {root}/index.html. Ejecute: make build')
    key = (port, str(root))
    if key not in _SERVED:
        srv = http.server.ThreadingHTTPServer(('127.0.0.1', port), functools.partial(Site, directory=str(root)))
        threading.Thread(target=srv.serve_forever, daemon=True).start()
        _SERVED[key] = f'http://localhost:{srv.server_address[1]}/index.html'
    return _SERVED[key]

async def open_page(p, size='1440x900', dark=False, offline=False, hash=None, dpr=1, init=None, go=True):
    """Abre el mapa en Chromium (SwiftShader) y espera la generación. Devuelve (navegador, página, logs).
    También la usa tools/variants.py. Con go=False no la carga: la URL es serve().
    TALCA_DIST=<directorio> sirve otro dist/ (una copia de antes de un cambio, para comparar)."""
    url = serve()
    w, h = map(int, size.split('x'))
    b = await p.chromium.launch(args=['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'])
    pg = await b.new_page(viewport={'width': w, 'height': h}, color_scheme='dark' if dark else 'light',
                          has_touch=w < 800, is_mobile=w < 800, device_scale_factor=dpr)
    logs = []
    pg.on('console', lambda m: logs.append(f'{m.type}: {m.text}'))
    pg.on('pageerror', lambda e: logs.append(f'ERROR: {e}'))
    async def local(r): await (r.continue_() if r.request.url.startswith('http://localhost') else r.abort())
    if offline: await pg.route('**/*', local)
    if init: await pg.add_init_script(init)  # JS that runs before the page's (window.__STAGE=0: tools/regress.py --init)
    if not go: return b, pg, logs  # without loading the page (tools/profile.py loads it while profiling)
    await pg.goto(url + (f'#{hash}' if hash else ''))
    await pg.wait_for_function('window.__stats', timeout=180000)
    await pg.wait_for_timeout(2500)
    print('stats:', await pg.evaluate('JSON.stringify(window.__stats)'))
    return b, pg, logs

async def main(a):
    async with async_playwright() as p:
        b, pg, logs = await open_page(p, a.size, a.dark, a.offline, a.hash, a.dpr)
        if a.js:
            await pg.evaluate(a.js); await pg.wait_for_timeout(3000)
        if a.view:
            out = Path(a.out); out.mkdir(parents=True, exist_ok=True)
            for v in a.view:
                name, _, js = v.partition('=')
                if not js: raise SystemExit(f'--view espera nombre=expresión: {v}')
                await pg.evaluate(js); await pg.wait_for_timeout(2500)
                f = out / f'{name}.png'; await pg.screenshot(path=str(f)); print('->', f)
        else:
            Path(a.out).parent.mkdir(parents=True, exist_ok=True)
            await pg.screenshot(path=a.out); print('->', a.out)
        for l in logs: print(l)
        bad = []
        if a.strict:
            bad = [l for l in logs if l.startswith(('ERROR:', 'error:'))]
            st = await pg.evaluate('window.__stats') or {}
            bad += [f'stats.{k} = {st.get(k)}' for k in ('buildings', 'trees', 'verts', 'ground') if not st.get(k)]
        await b.close()
        if bad: raise SystemExit('smoke: ' + '; '.join(bad))
        if a.strict: print('smoke: ok')

if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('out'); ap.add_argument('--size', default='1440x900'); ap.add_argument('--hash')
    ap.add_argument('--js'); ap.add_argument('--dark', action='store_true')
    ap.add_argument('--view', action='append', help='nombre=expresión JS; varias capturas de una carga (out es un directorio)')
    ap.add_argument('--dpr', type=float, default=1, help='densidad de pantalla (2: Retina)')
    ap.add_argument('--offline', action='store_true', help='bloquea las fuentes web y todo lo que no sea dist/')
    ap.add_argument('--strict', action='store_true', help='código 1 si hay errores de consola o la generación sale vacía (make smoke)')
    asyncio.run(main(ap.parse_args()))
