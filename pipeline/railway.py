"""La vía férrea desde OpenStreetMap: la Línea Central, el ramal a Constitución y lo que va sobre ellas.

  python railway.py check este        # revisa, sin escribir nada
  python railway.py write este        # además reescribe `ferrocarril` y `ramal` en config/trazados.json

Lee raw/osm/map-<nombre>.json (la API `map` por cajas: python traces.py tiles 1300 5200 -4400 4900 este) y:

  * encadena la Línea Central (railway=rail, usage=main) y el ramal (usage=branch) como `traces.py line`, simplificadas
    a 1,5 m, de norte a sur y recortadas a la maqueta con 300 m de margen;
  * cruza cada línea con las calles del mapa (data/geometry.json) y decide, con las vías de OSM del mismo cruce, si
    la calle pasa bajo la vía (la vía con bridge=yes o la calle con tunnel=yes / layer<0: «bajo») o la cruza a nivel
    (un nodo railway=level_crossing a menos de 15 m: «nivel», con barreras, luces y campana según sus etiquetas);
    un cruce que OSM no explica se avisa y queda «nivel» sin barreras;
  * toma los postes de la catenaria (power=catenary_mast) a menos de 8 m del eje de la Línea Central, que es la
    única electrificada (electrified=contact_line; el ramal no), y las señales luminosas (railway=signal con
    railway:signal:main o :crossing) a menos de 8 m de una de las dos líneas;
  * lista, para los hitos de la plantilla, los puentes ferroviarios (vías bridge=yes y sus contornos
    man_made=bridge) con lo que cruzan.

Todos los puntos se guardan como [lat, lon], como los demás trazados; process_geometry.py los pasa a la plantilla
(DATA.rail, DATA.ramal, DATA.railx, DATA.rmast, DATA.rsig). Ver docs/METODOLOGIA.md §5 y docs/PLAN-TREN.md.
"""
import contextlib, io, json, math, sys
from common import CONFIG, DATA, RAW, loc, unloc, require
import process_geometry as pg
import traces as tr

R = lambda p: [round(c, 6) for c in unloc(*p)]

def chain(name, usage):
    """The longest chain of railway=rail ways with this usage, as traces.py line prints it, in grid metres."""
    out = io.StringIO()
    with contextlib.redirect_stdout(out): tr.cmd_line(name, 'railway=^rail$', f'usage=^{usage}$', '--eps', '1.5')
    return [loc(lo, la) for la, lo in json.loads(out.getvalue())]

def survey(name):
    el = json.load(open(require(RAW / 'osm' / f'map-{name}.json', f'Ejecute: python traces.py tiles 1300 5200 -4400 4900 {name}')))['elements']
    N = {e['id']: e for e in el if e['type'] == 'node'}
    P = lambda w: [loc(N[n]['lon'], N[n]['lat']) for n in w['nodes'] if n in N]
    ways = [e for e in el if e['type'] == 'way']
    lines = {'principal': chain(name, 'main'), 'ramal': chain(name, 'branch')}
    for k, l in lines.items():
        print(f'{k}: {len(l)} puntos, {sum(math.dist(l[i], l[i+1]) for i in range(len(l)-1)):.0f} m, '
              f'de ({l[0][0]:.0f}, {l[0][1]:.0f}) a ({l[-1][0]:.0f}, {l[-1][1]:.0f})')
    inm = lambda p: pg.XMIN <= p[0] <= pg.XMAX and pg.YMIN <= p[1] <= pg.YMAX
    rails = [(w, P(w)) for w in ways if (w.get('tags') or {}).get('railway') == 'rail' and w['tags'].get('usage') in ('main', 'branch')]
    roads = [(w, P(w)) for w in ways if 'highway' in (w.get('tags') or {})]
    lcs = [(n, loc(n['lon'], n['lat'])) for n in N.values() if (n.get('tags') or {}).get('railway') == 'level_crossing']
    g = json.load(open(require(DATA / 'geometry.json', 'Ejecute: make data')))
    # every map street that crosses a line: under the rail, or at grade
    pasos = []
    print('\ncalles del mapa que cruzan la vía (y lo que dice OSM del cruce):')
    for k, l in lines.items():
        use = 'main' if k == 'principal' else 'branch'
        for s in g['streets']:
            for p in tr.crossings(tr.dec(s[2]), l):
                if not inm(p): continue
                nm = g['names'][s[1]]
                best = None                    # the OSM road crossing this line's OSM ways nearest to p
                for w, wp in roads:
                    for rw, rp in rails:
                        if rw['tags']['usage'] != use: continue
                        for q in tr.crossings(wp, rp):
                            d = math.dist(p, q)
                            if d < 15 and (best is None or d < best[0]): best = (d, w, rw)
                lc = min(((math.dist(p, q), n) for n, q in lcs), default=(1e9, None), key=lambda t: t[0])
                if best:
                    d, w, rw = best; t = w['tags']
                    under = rw['tags'].get('bridge', 'no') != 'no' or t.get('tunnel', 'no') != 'no' or int(t.get('layer', '0') or 0) < 0
                    why = f"w{w['id']} {t.get('name', t['highway'])}: " + (f"vía w{rw['id']} bridge=yes" if rw['tags'].get('bridge', 'no') != 'no'
                                                                           else f"tunnel={t.get('tunnel')} layer={t.get('layer')}" if under else 'a nivel')
                else: under, why = False, 'sin vía de OSM a menos de 15 m'
                if under: tipo = 'bajo'
                else:
                    tipo = 'nivel'
                    if lc[0] < 15:
                        lt = lc[1]['tags']; why += f"; level_crossing n{lc[1]['id']}" + ''.join(f' {x}' for x in ('barrier', 'light', 'bell') if lt.get(f'crossing:{x}') == 'yes')
                    else: why += '; SIN level_crossing EN OSM'
                e = {'linea': k, 'tipo': tipo, 'calle': nm, 'punto': R(p), 'osm': why}
                if tipo == 'nivel' and lc[0] < 15:
                    e['barreras'] = lc[1]['tags'].get('crossing:barrier') == 'yes'; e['luces'] = lc[1]['tags'].get('crossing:light') == 'yes'
                pasos.append(e)
                print(f"  {k:<9} {tipo:<5} {nm[:30]:<30} ({p[0]:.0f}, {p[1]:.0f})  {why}")
    # OSM roads that cross a line and are not in the map
    print('\nvías de OSM (no senderos) que cruzan la vía sin estar en el mapa:')
    for w, wp in roads:
        t = w['tags']
        if t['highway'] in ('footway', 'path', 'steps', 'track', 'cycleway', 'service', 'platform'): continue
        for k, l in lines.items():
            for q in tr.crossings(wp, l):
                if inm(q) and not any(math.dist(q, loc(e['punto'][1], e['punto'][0])) < 20 for e in pasos):
                    print(f"  {k:<9} w{w['id']} {t['highway']} {t.get('name', '')[:30]} ({q[0]:.0f}, {q[1]:.0f}) "
                          f"bridge={t.get('bridge', '')} tunnel={t.get('tunnel', '')} layer={t.get('layer', '')}")
    # rail bridges and what they cross
    print('\npuentes de la vía en la maqueta (vía de OSM, extremos, contorno man_made=bridge, lo que cruza):')
    outl = [(w, P(w)) for w in ways if (w.get('tags') or {}).get('man_made') == 'bridge']
    for rw, rp in rails:
        if rw['tags'].get('bridge', 'no') == 'no' or not any(map(inm, rp)): continue
        what = sorted({(w['tags'].get('name') or w['tags'].get('highway') or w['tags'].get('waterway')) for w, wp in
                       [(w, P(w)) for w in ways if 'highway' in (w.get('tags') or {}) or 'waterway' in (w.get('tags') or {})] if tr.crossings(wp, rp)})
        ol = [w for w, wp in outl if any(tr.pld(q, wp + wp[:1]) < 3 for q in rp)]
        print(f"  {rw['tags']['usage']:<6} w{rw['id']} ({rp[0][0]:.1f}, {rp[0][1]:.1f}) -> ({rp[-1][0]:.1f}, {rp[-1][1]:.1f}) "
              f"{math.dist(rp[0], rp[-1]):.0f} m; contorno {', '.join(f'w{w["id"]} {w["tags"].get("name", "")}' for w in ol) or '-'}; cruza {', '.join(what) or '?'}")
    # catenary masts along the main line, signals along both
    main = lines['principal']
    masts = [loc(n['lon'], n['lat']) for n in N.values() if (n.get('tags') or {}).get('power') == 'catenary_mast']
    masts = [q for q in masts if inm(q) and tr.pld(q, main) < 8]
    sl = lambda q: min(range(len(main)-1), key=lambda i: tr.segd(q, main[i], main[i+1]))
    masts.sort(key=lambda q: (sl(q), math.dist(main[sl(q)], q)))
    sigs = [loc(n['lon'], n['lat']) for n in N.values() if (n.get('tags') or {}).get('railway') == 'signal'
            and any(k in n['tags'] for k in ('railway:signal:main', 'railway:signal:crossing'))]
    sigs = [q for q in sigs if inm(q) and min(tr.pld(q, l) for l in lines.values()) < 8]
    print(f'\npostes de catenaria a menos de 8 m de la Línea Central: {len(masts)}; señales luminosas junto a la vía: {len(sigs)}')
    return lines, pasos, masts, sigs

def cmd_check(name): survey(name)

FUENTE = ('OpenStreetMap, tomado una vez de la API `map` (python pipeline/railway.py write este): la Línea Central '
          '(vías railway=rail «Línea Central Sur», usage=main, trocha de 1,676 m, electrified=contact_line), simplificada '
          'a 1,5 m. Reemplazó en octubre de 2026 al trazado a mano del tramo central (hasta 26 m al oriente de la vía '
          'principal en la estación) y del tramo sur (hasta ~500 m fuera). `postes`: los postes de la catenaria '
          '(power=catenary_mast) a menos de 8 m del eje; `senales`: las señales luminosas junto a la vía; `pasos`: cada '
          'calle del mapa que cruza la vía, bajo ella («bajo»: la vía con bridge=yes o la calle con tunnel=yes) o a nivel '
          '(«nivel», con las barreras y luces del nodo railway=level_crossing).')
FUENTE_RAMAL = ('OpenStreetMap, como la Línea Central: el ramal Talca–Constitución (vías railway=rail usage=branch, trocha '
                'de 1 m, sin electrificar), desde el tope de su vía junto a la estación hasta el borde sur de la maqueta.')

def block(lines, pasos, masts, sigs):
    """The `ferrocarril` entry of config/trazados.json as text, with the ramal inside it: each list of points on one
    line, like the rest of the file, so that a rewrite touches only this block."""
    J = lambda o: json.dumps(o, ensure_ascii=False, separators=(',', ':'))
    pts = lambda l: J([R(p) for p in l])
    ps = lambda k, ind: ('[\n' + ',\n'.join(ind + '  ' + json.dumps(e, ensure_ascii=False) for e in pasos if e['linea'] == k)
                         + '\n' + ind + ']')
    return ('  "ferrocarril": {\n'
            f'    "fuente": {J(FUENTE)},\n'
            '    "trocha_m": 1.676,\n'
            f'    "puntos": {pts(lines["principal"])},\n'
            f'    "postes": {pts(masts)},\n'
            f'    "senales": {pts(sigs)},\n'
            f'    "pasos": {ps("principal", "    ")},\n'
            '    "ramal": {\n'
            f'      "fuente": {J(FUENTE_RAMAL)},\n'
            '      "trocha_m": 1.0,\n'
            f'      "puntos": {pts(lines["ramal"])},\n'
            f'      "pasos": {ps("ramal", "      ")}\n'
            '    }\n'
            '  },\n')

def cmd_write(name):
    lines, pasos, masts, sigs = survey(name)
    f = CONFIG / 'trazados.json'; t = f.read_text()
    a = t.index('  "ferrocarril": {'); b = t.index('  "ruta5": {')
    t = t[:a] + block(lines, pasos, masts, sigs) + t[b:]
    json.loads(t); f.write_text(t); print(f'-> {f.relative_to(CONFIG.parent)}')

if __name__ == '__main__':
    cmds = {'check': cmd_check, 'write': cmd_write}
    if len(sys.argv) < 3 or sys.argv[1] not in cmds: raise SystemExit(__doc__)
    cmds[sys.argv[1]](*sys.argv[2:])
