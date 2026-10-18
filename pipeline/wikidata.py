"""Cruce de los lugares de pipeline/pois.py con Wikidata: coordenadas, fechas, patrimonio, fotos y candidatos.

  python wikidata.py check              # informe (baja los elementos la primera vez a raw/wikidata/)
  python wikidata.py check --refresh    # lo mismo, volviendo a bajarlos
  python wikidata.py item Q42898047     # las declaraciones de un elemento que interesan aquí

Elementos: los que Wikidata ubica (P131) en Talca, la ciudad (Q4469) o la comuna (Q31947291), y los que tienen
coordenadas (P625) en la caja de la comuna (SPARQL, query.wikidata.org), con sus declaraciones (wbgetentities). Un
lugar se enlaza con su elemento por `wd=` en pois.add() ('Q…', o varios separados por comas: el primero es el
principal, y su categoría de Commons es la que usa `landmark.py photos --cat`).

El informe:
  1. Cada lugar con wd=: la distancia entre su punto y el de Wikidata (avisa sobre 50 m; casi siempre es Wikidata el
     que está peor: un punto de OSM o de la dirección contra uno puesto a mano), y lo que Wikidata sabe que la ficha
     no dice: el año de inicio (P571, P1619) que no aparece en el texto, la protección patrimonial (P1435) si la ficha
     no menciona «Monumento» ni «conservación», la categoría de Commons (P373) y la foto (P18) que docs/FUENTES.md no
     cita, y el artículo de la Wikipedia en español que no está entre las fuentes.
  2. Candidatos: elementos con coordenadas dentro de la comuna, con protección patrimonial o de una clase que le
     interesa a este mapa (tribunales, notarías, monumentos, memoriales, iglesias, museos, estaciones, puentes,
     batallas), que ningún lugar enlaza; con la distancia al lugar más cercano.
  3. Posibles duplicados: dos elementos con el mismo nombre (o la misma foto) a menos de 150 m.

Lo que diga Wikidata hay que confirmarlo en una fuente primaria antes de llevarlo a una ficha, y la ficha lo resume
con palabras propias. Wikidata es CC0; las coordenadas de pois.py vienen de OSM (ODbL) y no se copian a Wikidata.
Biblioteca estándar; requiere internet la primera vez.
"""
import json, math, re, sys, time, urllib.parse, urllib.request
from common import ROOT, DATA, RAW, loc, comuna, in_ring, require

UA = {'User-Agent': 'talca-isometrica/1.0 (maqueta isometrica de Talca; https://github.com/eduramirezh/talca-isometrica)'}
CACHE = RAW / 'wikidata'
TALCA = ('Q4469', 'Q31947291')                       # la ciudad y la comuna
BOX = ('Point(-71.76 -35.31)', 'Point(-71.45 -35.535)')
WANT = re.compile(r'tribunal|juzgado|corte|notar|fiscal|c[aá]rcel|monumento|memorial|escultura|estatua|iglesia|templo|'
                  r'catedral|santuario|capilla|museo|estaci[oó]n|puente|batalla|combate|bien cultural|edificio|teatro', re.I)

def get(url, accept=None):
    h = dict(UA, Accept=accept) if accept else UA
    for k in range(4):
        try: return json.loads(urllib.request.urlopen(urllib.request.Request(url, headers=h), timeout=300).read())
        except urllib.error.HTTPError as e:
            if e.code not in (429, 500, 502, 503, 504) or k == 3: raise
            time.sleep(10 * (k + 1))

def sparql(q):
    return get('https://query.wikidata.org/sparql?' + urllib.parse.urlencode({'query': q}), 'application/sparql-results+json')['results']['bindings']

def entities(ids, props='labels|descriptions|claims|sitelinks'):
    out = {}
    for k in range(0, len(ids), 50):
        out.update(get('https://www.wikidata.org/w/api.php?' + urllib.parse.urlencode({'action': 'wbgetentities',
                   'ids': '|'.join(ids[k:k+50]), 'props': props, 'languages': 'es|en', 'sitefilter': 'eswiki|commonswiki',
                   'format': 'json'}))['entities'])
        time.sleep(1)
    return out

def fetch(extra=()):
    """The items of Talca (and those of `extra`, the wd= of pois.py) with the labels of their classes -> raw/wikidata/."""
    ids = set(extra)
    for q in ['SELECT DISTINCT ?i WHERE { VALUES ?t { %s } ?i wdt:P131 ?t }' % ' '.join('wd:' + t for t in TALCA),
              'SELECT DISTINCT ?i WHERE { SERVICE wikibase:box { ?i wdt:P625 ?c . bd:serviceParam wikibase:cornerWest '
              '"%s"^^geo:wktLiteral . bd:serviceParam wikibase:cornerEast "%s"^^geo:wktLiteral . } }' % BOX]:
        ids |= {r['i']['value'].rsplit('/', 1)[1] for r in sparql(q)}; time.sleep(2)
    ents = entities(sorted(ids))
    tg = sorted({v['id'] for e in ents.values() for p in ('P31', 'P1435') for v in vals(e, p)})
    lab = {q: label(e) for q, e in entities(tg, 'labels').items()}
    CACHE.mkdir(parents=True, exist_ok=True)
    json.dump(ents, open(CACHE / 'entities.json', 'w'), ensure_ascii=False)
    json.dump(lab, open(CACHE / 'labels.json', 'w'), ensure_ascii=False)
    (CACHE / 'fecha.txt').write_text(time.strftime('%Y-%m-%d\n'))

def vals(e, p):
    return [c['mainsnak']['datavalue']['value'] for c in e.get('claims', {}).get(p, []) if c['mainsnak'].get('datavalue')]

def label(e):
    L = e.get('labels', {}); return (L.get('es') or L.get('en') or {}).get('value', e.get('id', '?'))

def row(q, e, lab):
    co = vals(e, 'P625'); xy = loc(co[0]['longitude'], co[0]['latitude']) if co else None
    return dict(q=q, name=label(e), xy=xy, p31=[lab.get(v['id'], v['id']) for v in vals(e, 'P31')],
                start=sorted({v['time'][1:5] for p in ('P571', 'P1619') for v in vals(e, p)}),
                heritage=[lab.get(v['id'], v['id']) for v in vals(e, 'P1435')], cat=vals(e, 'P373'), img=vals(e, 'P18'),
                eswiki=e.get('sitelinks', {}).get('eswiki', {}).get('title'))

def cmd_item(q):
    e = entities([q])[q]; tg = [v['id'] for p in ('P31', 'P1435') for v in vals(e, p)]
    lab = {k: label(v) for k, v in entities(tg, 'labels').items()} if tg else {}
    print(json.dumps(row(q, e, lab), ensure_ascii=False, indent=1))

def cmd_check(*args):
    pois = json.load(open(require(DATA / 'pois.json', 'Ejecute: make pois')))['pois']
    wd = {p['id']: [q.strip() for q in p['wd'].split(',')] for p in pois if p.get('wd')}
    if '--refresh' in args or not (CACHE / 'entities.json').exists():
        print('bajando de Wikidata…'); fetch({q for qs in wd.values() for q in qs})
    ents = json.load(open(CACHE / 'entities.json')); lab = json.load(open(CACHE / 'labels.json'))
    missing = sorted({q for qs in wd.values() for q in qs} - set(ents))
    if missing: ents.update(entities(missing)); json.dump(ents, open(CACHE / 'entities.json', 'w'), ensure_ascii=False)
    R = {q: row(q, e, lab) for q, e in ents.items() if 'missing' not in e}
    ring = comuna(); inside = [r for r in R.values() if r['xy'] and in_ring(r['xy'], ring)]
    fuentes = urllib.parse.unquote(open(ROOT / 'docs' / 'FUENTES.md').read()).replace('_', ' ')
    print(f"Wikidata (caché del {(CACHE / 'fecha.txt').read_text().strip() if (CACHE / 'fecha.txt').exists() else '?'}): "
          f"{len(R)} elementos, {len(inside)} con coordenadas dentro de la comuna.\n")
    print(f'1. Lugares con wd= ({len(wd)} de {len(pois)}):')
    far = []
    for p in pois:
        for q in wd.get(p['id'], []):
            r = R.get(q)
            if not r: print(f"  {p['id']:26} {q:>11}  ¡no existe en Wikidata!"); continue
            d = math.dist((p['x'], p['y']), r['xy']) if r['xy'] else None
            if d is not None and d > 50: far.append((p['id'], q, d))
            txt = ' '.join([p['d'], p['f'] or '', p['n']]); src = json.dumps(p['src'], ensure_ascii=False).lower()
            notes = [f'{y} no aparece en la ficha' for y in r['start'] if y not in txt]
            if r['heritage'] and not re.search(r'monumento|conservaci', txt, re.I): notes.append(f"protección: {', '.join(r['heritage'])}")
            notes += [f'categoría de Commons «{c}» no citada en FUENTES' for c in r['cat'] if c not in fuentes]
            notes += [f'foto P18 «{i}» no citada en FUENTES' for i in r['img'] if i not in fuentes]
            if r['eswiki'] and 'wikipedia' not in src: notes.append(f"eswiki «{r['eswiki']}» no está entre las fuentes")
            print(f"  {p['id']:26} {q:>11}  {r['name'][:40]:40} {'Δ —' if d is None else f'Δ {d:.0f} m':>8}")
            for n in notes: print(f'      · {n}')
    print('\n  Distancias de más de 50 m (revise con landmark.py osm <id>; el punto de pois.py suele ser la dirección):')
    for pid, q, d in sorted(far, key=lambda t: -t[2]): print(f'    {pid:26} {q:>11} {d:5.0f} m')
    print(f"\n  Sin wd= ({len(pois) - len(wd)}): {', '.join(p['id'] for p in pois if p['id'] not in wd)}")
    linked = {q for qs in wd.values() for q in qs}
    print('\n2. Candidatos (en la comuna, con protección patrimonial o de una clase de interés, sin lugar que los enlace):')
    for r in sorted(inside, key=lambda r: (not r['heritage'], r['name'])):
        if r['q'] in linked or not (r['heritage'] or WANT.search(' '.join(r['p31']))): continue
        near = min(pois, key=lambda p: math.dist((p['x'], p['y']), r['xy']))
        print(f"  {r['q']:>11}  {r['name'][:46]:46} {', '.join(r['p31'])[:30]:30} ({r['xy'][0]:.0f}, {r['xy'][1]:.0f})"
              f"{'  ' + '; '.join(r['heritage']) if r['heritage'] else ''}{'  ' + r['start'][0] if r['start'] else ''}"
              f"  · {near['id']} a {math.dist((near['x'], near['y']), r['xy']):.0f} m")
    print('\n3. Posibles duplicados (mismo nombre o misma foto, a menos de 150 m):')
    rs = [r for r in R.values() if r['xy']]
    for i, a in enumerate(rs):
        for b in rs[i+1:]:
            if math.dist(a['xy'], b['xy']) < 150 and (a['name'].lower() == b['name'].lower() or set(a['img']) & set(b['img'])):
                print(f"  {a['q']} y {b['q']}: «{a['name']}» / «{b['name']}», a {math.dist(a['xy'], b['xy']):.0f} m")

if __name__ == '__main__':
    cmds = {'check': cmd_check, 'item': cmd_item}
    if len(sys.argv) < 2 or sys.argv[1] not in cmds: raise SystemExit(__doc__)
    cmds[sys.argv[1]](*sys.argv[2:])
