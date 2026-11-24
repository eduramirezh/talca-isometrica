"""La maqueta en 3D en el navegador (talca.eduramirez.com/3d/): la exportación web de modelo3d/ (Godot) con sus teselas.

  python3 tools/web3d.py armar                 # -> dist/3d/ (make web3d; requiere modelo3d/mapa/: make modelo3d)
  python3 tools/web3d.py servir [--port 8765]  # sirve dist/ como Cloudflare Pages, con las cabeceras de _headers
  uv run --with "playwright==1.63" python tools/web3d.py probar shots/3d.png [--hash catedral] [--gl gpu]
      [--size 1440x900] [--fps 5]             # abre /3d/ en Chromium, espera a que cargue lo que ve la cámara,
                                               # captura y mide; sale con 1 si hubo errores de consola

armar exporta modelo3d/ con el preset «Web» de modelo3d/export_presets.cfg (Godot con --headless, que no abre
ventana: GODOT=<ruta> o el de siempre, como el Makefile) a dist/3d/index.html, index.js, index.pck (los scripts, los
sombreadores y datos/) e index.wasm, que va comprimido, index.wasm.gz (~10 MB en vez de ~39: Cloudflare Pages no
sirve archivos de más de 25 MiB; modelo3d/web/shell.html lo descomprime en el navegador). Luego copia modelo3d/mapa/
en gzip a dist/3d/mapa/<nombre>.gz (~28 % del tamaño; modelo3d/fuente.gd los descomprime), solo los que cambiaron
(la primera vez, ~600 MB en unos segundos; el gzip no lleva fecha, así que el mismo archivo da los mismos bytes y
Wrangler no lo vuelve a subir), borra los que ya no están y escribe dist/3d/mapa/lista.json (nombre -> [bytes, sha256
corto] del archivo sin comprimir); lo mismo con modelo3d/datos/ en dist/3d/datos/ (en el navegador van en index.pck).
tools/bajar_mapa.py baja los dos al computador, desde el sitio. dist/3d/ no lo toca
pipeline/build.py, y scripts/deploy-cloudflare.sh corre `make web3d` antes de subir (una publicación sin dist/3d/
borraría /3d/ del sitio).

servir es `make serve` con las cabeceras de dist/_headers (tools/page.py, Site): /3d/ necesita las de aislamiento
entre orígenes (los hilos de Godot), que `python -m http.server` no manda.

probar carga /3d/#<hash> (los # de modelo3d/web.gd: un lugar, x,y, girar=, camara=…) y espera a que
window.__m3d.estado sea «listo» (web.gd: lo que pide la cámara está cargado), mide los cuadros por segundo durante
--fps s y guarda la captura. Imprime window.__m3d (MB bajados, teselas) y la consola. Por omisión con la GPU del
equipo (--gl gpu, tools/page.py GL); con --gl swiftshader Godot dibuja, pero a pocos cuadros por segundo.
"""
import argparse, concurrent.futures, gzip, hashlib, json, os, shutil, subprocess, sys, time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
ROOT = Path(__file__).resolve().parent.parent
DIST = ROOT / 'dist'
M3D = ROOT / 'modelo3d'


def godot():
    g = os.environ.get('GODOT')
    if g: return g
    mac = '/Applications/Godot.app/Contents/MacOS/Godot'
    if Path(mac).exists(): return mac
    return shutil.which('godot') or shutil.which('godot4') or sys.exit('web3d.py: no encuentro Godot (GODOT=<ruta>)')


def comprimir(src, dst):
    dst.write_bytes(gzip.compress(src.read_bytes(), 6, mtime=0))
    os.utime(dst, ns=(src.stat().st_atime_ns, src.stat().st_mtime_ns))


def resumen(f):
    b = f.read_bytes()
    return [len(b), hashlib.sha256(b).hexdigest()[:16]]


def faltan_en(mapa):
    """Los archivos que indice.json nombra y no están en mapa/ (los que lee modelo3d/mapa.gd: cada tesela, sus datos,
    su media y las fachadas; lejos.glb). make modelo3d vacía mapa/ antes de escribirlo: a medias faltan cientos."""
    i = json.loads((mapa / 'indice.json').read_text())
    nombres = [i['lejos']['archivo']] if i.get('lejos') else []
    for t in i['teselas']:
        nombres.append(t['archivo'])
        if 'instancias' in t: nombres.append(t['archivo'].rsplit('.', 1)[0] + '.json')
        if 'medio' in t: nombres.append(t['medio']['archivo'])
        if t.get('fachadas', 0) > 0: nombres.append(f"f_{t['i']}_{t['j']}.json")
    return [n for n in nombres if not (mapa / n).exists()]


def armar(a):
    out = DIST / '3d'
    mapa = M3D / 'mapa'
    if not (mapa / 'indice.json').exists():
        sys.exit('web3d.py: falta modelo3d/mapa/indice.json: corra `make modelo3d`')
    faltan = faltan_en(mapa)
    if faltan:   # publicarlo así dejaría huecos en el sitio
        sys.exit(f'web3d.py: modelo3d/mapa/ está incompleto ({len(faltan)} archivos de indice.json no están, p. ej. '
                 f'{faltan[0]}): ¿make modelo3d está corriendo? Espere a que termine')
    out.mkdir(parents=True, exist_ok=True)
    for f in out.glob('index.*'): f.unlink()
    t0 = time.time()
    r = subprocess.run([godot(), '--headless', '--path', str(M3D), '--export-release', 'Web', str(out / 'index.html')],
                       capture_output=True, text=True)
    if r.returncode != 0 or not (out / 'index.wasm').exists():
        print(r.stdout[-3000:], r.stderr[-3000:], sep='\n')
        sys.exit('web3d.py: la exportación de Godot falló (¿están sus plantillas de exportación? Godot > Editor > Manage '
                 'Export Templates; en el Mac, ~/Library/Application Support/Godot/export_templates/<versión>/web_release.zip)')
    w = out / 'index.wasm'
    (out / 'index.wasm.gz').write_bytes(gzip.compress(w.read_bytes(), 9, mtime=0))
    w.unlink()
    print(f'dist/3d/: exportado en {time.time() - t0:.0f} s; index.wasm.gz {(out / "index.wasm.gz").stat().st_size / 1e6:.1f} MB, '
          f'index.pck {(out / "index.pck").stat().st_size / 1e6:.1f} MB')

    for d in ('mapa', 'datos'):
        publicar(M3D / d, out / d)


def publicar(src, dst):
    """src/ en gzip a dst/<nombre>.gz (solo lo que cambió; borra lo que ya no está) y dst/lista.json."""
    t0 = time.time()
    dst.mkdir(exist_ok=True)
    fuentes = sorted(f for f in src.iterdir() if f.is_file() and not f.name.startswith('.'))
    nombres = {f.name + '.gz' for f in fuentes}
    viejos = [f for f in dst.glob('*.gz') if f.name not in nombres]
    for f in viejos: f.unlink()
    hacer = [f for f in fuentes if not (dst / (f.name + '.gz')).exists()
             or (dst / (f.name + '.gz')).stat().st_mtime_ns != f.stat().st_mtime_ns]
    with concurrent.futures.ThreadPoolExecutor(os.cpu_count()) as ex:   # zlib suelta el GIL
        list(ex.map(lambda f: comprimir(f, dst / (f.name + '.gz')), hacer))
        lista = dict(zip([f.name for f in fuentes], ex.map(resumen, fuentes)))
    (dst / 'lista.json').write_text(json.dumps(lista, separators=(',', ':')))
    mb = sum(f.stat().st_size for f in dst.glob('*.gz')) / 1e6
    print(f'dist/3d/{dst.name}/: {len(fuentes)} archivos ({sum(v[0] for v in lista.values()) / 1e6:.0f} MB, en gzip {mb:.0f} MB); '
          f'{len(hacer)} comprimidos, {len(viejos)} borrados, en {time.time() - t0:.0f} s')


def servir(a):
    import page
    url = page.serve(a.port, DIST)
    print(f'{url.rsplit("/", 1)[0]}/ y {url.rsplit("/", 1)[0]}/3d/ (Ctrl+C para terminar)')
    try:
        while True: time.sleep(3600)
    except KeyboardInterrupt:
        pass


async def _probar(a):
    from playwright.async_api import async_playwright
    import page
    if not (DIST / '3d' / 'index.html').exists(): sys.exit('web3d.py: falta dist/3d/: make web3d')
    url = page.serve(0, DIST).rsplit('/', 1)[0] + '/3d/index.html' + (f'#{a.hash}' if a.hash else '')
    w, h = (int(x) for x in a.size.split('x'))
    logs = []
    async with async_playwright() as p:
        b = await page.launch(p, a.gl)
        pg = await b.new_page(viewport={'width': w, 'height': h})
        pg.on('console', lambda m: logs.append(f'{m.type}: {m.text}'))
        pg.on('pageerror', lambda e: logs.append(f'error: {e}'))
        t0 = time.time()
        await pg.goto(url)
        aislada = await pg.evaluate('crossOriginIsolated')
        estado = {}
        while time.time() - t0 < a.espera:
            estado = await pg.evaluate('window.__m3d || {}')
            if estado.get('estado') in ('listo', 'error'): break
            await pg.wait_for_timeout(500)
        t_listo = time.time() - t0
        if a.fps:
            await pg.wait_for_timeout(a.fps * 1000)
            estado = await pg.evaluate('window.__m3d || {}')
        await pg.screenshot(path=a.png)
        await b.close()
    print(f'{url}: crossOriginIsolated={aislada}; {estado.get("estado", "sin estado")} a los {t_listo:.1f} s; {json.dumps(estado)}')
    print(f'-> {a.png}')
    errores = [l for l in logs if l.startswith(('error', 'pageerror')) or 'ERROR' in l]
    for l in logs: print('  ' + l[:400])
    return 1 if errores or estado.get('estado') != 'listo' else 0


def probar(a):
    import asyncio
    return asyncio.run(_probar(a))


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest='cmd', required=True)
    sub.add_parser('armar', help='exporta modelo3d/ y copia mapa/ en gzip a dist/3d/')
    s = sub.add_parser('servir', help='sirve dist/ con las cabeceras de _headers')
    s.add_argument('--port', type=int, default=8765)
    pr = sub.add_parser('probar', help='abre /3d/ en Chromium, espera, captura y mide')
    pr.add_argument('png')
    pr.add_argument('--hash', default='')
    pr.add_argument('--gl', default='gpu')
    pr.add_argument('--size', default='1440x900')
    pr.add_argument('--fps', type=float, default=5.0, help='s que espera después de cargar, para medir (0: no espera)')
    pr.add_argument('--espera', type=float, default=180.0, help='s máximos hasta que cargue')
    a = ap.parse_args()
    sys.exit({'armar': armar, 'servir': servir, 'probar': probar}[a.cmd](a) or 0)


if __name__ == '__main__':
    main()
