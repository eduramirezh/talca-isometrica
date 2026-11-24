"""Baja la maqueta en 3D del sitio a modelo3d/mapa/ y modelo3d/datos/, para abrirla con Godot sin armarla.

  python3 tools/bajar_mapa.py                    # de talca.eduramirez.com/3d/ (~170 MB en gzip, ~600 MB en disco)
  python3 tools/bajar_mapa.py --url http://localhost:8765/3d/    # de otro lugar (tools/web3d.py servir)
  python3 tools/bajar_mapa.py --revisar          # solo dice cuántos archivos faltan o cambiaron
  python3 tools/bajar_mapa.py --destino ../talca-juego/juego   # a otro proyecto de Godot (escribe mapa/ y datos/ ahí)

Lo mismo que deja `make modelo3d` (que necesita el pipeline entero: raw/, npm, Playwright y ~3 min), pero bajado de lo
que publica tools/web3d.py armar: <dir>/lista.json (nombre -> [bytes, sha256 corto]) y cada archivo en gzip
(<nombre>.gz). Baja solo lo que falta o cambió (compara tamaño y hash), 8 a la vez, y escribe cada archivo entero o
nada (un .tmp que se renombra), así que se puede cortar y volver a correr. No borra nada. Solo la biblioteca estándar.
Después:

  godot --headless --path modelo3d --import      # la primera vez (lo que hace make modelo3d al final)
  godot --path modelo3d                          # el visor (ver.gd)
"""
import argparse, concurrent.futures, gzip, hashlib, json, sys, urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
M3D = ROOT / 'modelo3d'
URL = 'https://talca.eduramirez.com/3d/'
AGENTE = 'talca-isometrica bajar_mapa.py'


def leer(url):
    with urllib.request.urlopen(urllib.request.Request(url, headers={'User-Agent': AGENTE}), timeout=60) as r:
        return r.read()


def resumen(f):
    b = f.read_bytes()
    return [len(b), hashlib.sha256(b).hexdigest()[:16]]


def bajar(base, dest, d, nombre, esperado):
    b = gzip.decompress(leer(f'{base}{d}/{nombre}.gz'))
    if [len(b), hashlib.sha256(b).hexdigest()[:16]] != esperado:
        raise ValueError(f'{d}/{nombre}: no calza con lista.json')
    f = dest / d / nombre
    tmp = f.with_name(f.name + '.tmp')
    tmp.write_bytes(b)
    tmp.replace(f)
    return len(b)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--url', default=URL, help=f'donde está la maqueta publicada (por omisión {URL})')
    ap.add_argument('--destino', type=Path, default=M3D, help='el proyecto de Godot (por omisión modelo3d/)')
    ap.add_argument('--revisar', action='store_true', help='solo cuenta lo que falta, sin bajar')
    a = ap.parse_args()
    base = a.url if a.url.endswith('/') else a.url + '/'
    total_mb, fallas = 0.0, []
    for d in ('datos', 'mapa'):
        lista = json.loads(leer(f'{base}{d}/lista.json'))
        (a.destino / d).mkdir(parents=True, exist_ok=True)
        faltan = [n for n, v in lista.items() if not (a.destino / d / n).exists() or resumen(a.destino / d / n) != v]
        mb = sum(lista[n][0] for n in faltan) / 1e6
        print(f'{a.destino / d}/: {len(lista)} archivos, {len(faltan)} por bajar ({mb:.0f} MB sin comprimir)')
        if a.revisar or not faltan:
            continue
        hechos = 0
        with concurrent.futures.ThreadPoolExecutor(8) as ex:
            tareas = {ex.submit(bajar, base, a.destino, d, n, lista[n]): n for n in faltan}
            for t in concurrent.futures.as_completed(tareas):
                try:
                    total_mb += t.result() / 1e6
                except Exception as e:   # sigue con los demás: volver a correrlo baja solo lo que falló
                    fallas.append(f'{d}/{tareas[t]}: {e}')
                hechos += 1
                if hechos % 100 == 0 or hechos == len(faltan):
                    print(f'  {hechos}/{len(faltan)}', flush=True)
        if d == 'mapa':
            (a.destino / d / '.gdignore').touch()   # Godot no importa los glb: mapa.gd los lee mientras se mira
    for f in fallas[:20]:
        print('  falló ' + f, file=sys.stderr)
    if fallas:
        sys.exit(f'bajar_mapa.py: {len(fallas)} archivos fallaron; vuelva a correrlo para bajar solo esos')
    if not a.revisar:
        print(f'listo ({total_mb:.0f} MB escritos). Luego: godot --headless --path modelo3d --import && godot --path modelo3d')


if __name__ == '__main__':
    main()
