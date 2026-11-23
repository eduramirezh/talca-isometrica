---
name: modelar-hito
description: Modelar o rehacer un hito de la maqueta (un edificio, un puente, un recinto, una calle vestida) en src/js/hitos/<id>.js, sobre su planta real de OSM y con estética de pixel art. Planta, marco local, fotos, modelo, capturas y registro. Úsela al crear un hito o al rehacer uno entero; un retoque chico de un hito que ya existe no la necesita.
argument-hint: "<id del lugar en pois.py, o x,y en metros de grilla>"
---

# Modelar un hito

El procedimiento corto y ejecutable para un hito: `$ARGUMENTS` es su id (el de `pipeline/pois.py`) o, si no es un
lugar (un puente, un paso), un punto `x,y` de la grilla. Los ejemplos de referencia son el Estadio Fiscal
(`src/js/hitos/estadio.js`) y la Catedral (`src/js/hitos/catedral.js`): léalos antes de escribir el modelo.

- **El porqué** de cada paso está en `docs/METODOLOGIA.md` §9 (9.1 planta, 9.2 marco, 9.3 fotos, 9.4 modelo,
  9.5 verificación, 9.6 registro, 9.7 varios hitos a la vez). Léalo cuando un paso no calce con su caso.
- **Cómo debe verse** (escala de 0,5 m, lenguaje, paleta `KH`, techos, noche, vocabulario de `facade()`):
  `docs/ESTETICA.md`.
- **Las trampas de los hitos, el catálogo de hitos de referencia («copie del hito que se parezca») y las reglas del
  archivo** están en `.claude/rules/hitos.md`, que se carga solo al leer o editar `src/js/hitos/**` o
  `src/js/45-landmarks.js`. No las repita aquí: si un caso se parece a uno del catálogo (en ladera, un campus de OSM,
  un puente, la Ruta 5, un recinto amurallado, una calle vestida), abra ese hito y copie su enfoque.

## 0. Antes de empezar

En un worktree, `raw/` y `node_modules/` no van en git: el hook `WorktreeCreate` (`tools/preparar.sh`) los enlaza a
los del checkout principal. Si faltan (un worktree hecho a mano), `tools/preparar.sh`.

```bash
tools/preparar.sh --revisar || tools/preparar.sh
make build
```

¿Es un lugar? `grep -n "'<id>'" pipeline/pois.py`. Si debe tener ficha y no la tiene, agréguelo primero en
`pipeline/pois.py` (con `src` y una confianza honesta; convenciones de `CLAUDE.md`) y `make pois build`. Un hito sin
lugar (los puentes, `regimiento-16`, `edificio-raices`) se trabaja con su punto `x,y` y se mira con `__look`.

Guarde una referencia del mapa antes de tocar nada, para ver después que solo cambió lo que debía (~2 min; con la
vista del hito, que `--against` repite):

```bash
uv run tools/regress.py --save shots/ref-<id> --view "hito=__look(<x>,<y>,4)"
```

## 1. Planta

```bash
uv run --with pillow python pipeline/landmark.py osm <id> [media caja, 250 por omisión]
uv run --with pillow python pipeline/landmark.py osm <x>,<y> [media caja]     # lo que no es un lugar
```

Lista vías, relaciones y nodos etiquetados y dibuja `diagnostics/plan-<id>.png`. La descarga queda en
`raw/osm/<id>.json` (bórrela para volver a bajarla, p. ej. con una caja mayor). Con el plano, conteste:

1. ¿El punto del lugar cae en el hito, o en un borde (es una dirección)? El modelo va sobre la planta, y
   `MODELS[id]` apunta a su centro; el punto de `pois.py` no se toca.
2. ¿La caja cubre todo el hito? Si la huella toca el borde del plano, agrande la media caja.
3. ¿La huella choca con calles del mapa (las del grafo, más anchas que las reales)? Ahí el modelo deja un hueco o se
   ajusta al espacio entre las calles.

Para manzanas e imagen: `uv run --with pillow python pipeline/satellite.py punto <x> <y> [lado] [z] --calles --fecha`
(`--fecha`: de cuándo es la imagen; en la ciudad, z18–19 son de 2015).

## 2. Marco local

```bash
python pipeline/landmark.py frame <id> <vía de referencia> [otras vías] [--origin X Y --angle A]
```

Origen en el centroide de la primera vía y eje v por su lado más largo; imprime `marco: X=… Y=… A=…°`, la extensión
en (u, v) de cada vía y los nodos etiquetados a menos de 150 m. Escriba todo el modelo en (u, v). Para un recinto
grande, la imagen girada a ese marco, con cruces cada 10 m rotuladas en (u, v):

```bash
uv run --with pillow python pipeline/satellite.py marco <X> <Y> <A> <u0> <u1> <v0> <v1> [z] [nombre]
```

## 3. Fotos y fuentes

```bash
python pipeline/landmark.py photos <id> --geo 150 --cat           # Commons por nombre, por ubicación y por la categoría de Wikidata
python pipeline/landmark.py photos <id> 'incategory:"<Categoría_de_Commons>"'   # la de la etiqueta wikimedia_commons de OSM
python pipeline/landmark.py photos <nombre> "<consulta>"          # algo que no es un lugar: el nombre es la carpeta
```

Quedan en `diagnostics/fotos/<id>/` con `indice.txt` (fecha, licencia, autor, enlace: para FUENTES). Más fuentes:
`--panoramax 150`, `--mapillary` (su clave: `python pipeline/mapillary.py clave`; `mapillary.py lugares` dice qué lugares
tienen fotos que los miran), `--flickr` (con `FLICKR_KEY`). Busque también prensa sobre
remodelaciones y, si es Monumento Histórico, su decreto. **Las fotos fechadas mandan** sobre el satélite para techos,
alturas y colores; las alturas de OSM no sirven (mida en una foto frontal con un ancho conocido de la planta). Anote
de dónde sale cada medida. Street View sirve para mirar, nunca para copiar.

## 4. El modelo

Cree `src/js/hitos/<id>.js` y agregue `<id>` a `src/js/hitos/ORDER` (al final, salvo que su explanada deba ceder ante
la de un vecino: lo explica el encabezado de `ORDER`). El esqueleto, como el Estadio y la Catedral (los comentarios
del código van en inglés, como en los demás hitos):

```js
  // ==== hito: <id> ====
  // <Name>, on S. Plan from OpenStreetMap: <w…, r…>. Frame from landmark.py frame <id> <way>: v runs <…>, u <…>.
  // Heights and colours from <dated photos, sources>. Approximate: <…>. Method: docs/METODOLOGIA.md §9.
  {const F=localFrame(<X>,<Y>,<A>*Math.PI/180),{G,Gs,V,N3,R}=F;
    const K={...KH,<tonos propios de las fotos>};
    const {box,WL,WV,WU,rect,arch,glass,roof,outOf,walls,hipped}=facade(S,F,K);
    const fp=Gs([<huella real en (u,v)>]);occMark(fp);
    S.dy=padAt(Math.min(...fp.map(p=>p[0])),Math.min(...fp.map(p=>p[1])),Math.max(...fp.map(p=>p[0])),Math.max(...fp.map(p=>p[1])));
    // … the model, in (u,v), on S …
    const c=G(0,0);MODELS['<id>']={x:c[0],y:c[1],h:<alto>};S.dy=0;}
```

Reglas del procedimiento (el detalle y las trampas, en `.claude/rules/hitos.md`):

- Un hito por archivo, con su primera línea `  // ==== hito: <id> ====` (dos espacios) y su id en `ORDER`.
- Paleta `K={...KH, …}`; todo en `S`, con `facade()` y los ayudantes de `src/js/45-landmarks.js` (su cabecera los
  lista) antes que copias de otro hito. Lo que sirva a dos hitos va a `45-landmarks.js`, nunca a un hito.
- `occMark` con la huella real (o `occFill` para un recinto), `padAt` para la explanada (o, sin explanada,
  `groundLayer` / `onFinalTerrain`), `NOLOTS` si es un recinto cercado, `GLOW` para las luces de noche.
- Pixel art: peldaños y arcos escalonados, dos tonos alternados, molduras blancas, líneas de 0,5 m, nada bajo 0,4 m.
- El comentario de arriba: ids de OSM, fuentes de lo que está sobre el suelo y qué es aproximado o licencia.

Después de cada cambio:

```bash
make check     # ~1 s: la línea del hito, ORDER, nombres de otro hito, MODELS leído antes de tiempo, node --check
make lint      # ESLint sobre el script unido: un nombre que tapa a otro de primer nivel
```

## 5. Capturas

De a una (varias en paralelo agotan el tiempo de Playwright), y cada `--view` sobre la anterior, de una sola carga
(las de `docs/METODOLOGIA.md` §9.5):

```bash
make build
uv run tools/screenshot.py shots/<id>/ --hash <id> \
  --view "ficha=0" \
  --view "cerca=document.querySelector('#cx').click();for(let i=0;i<3;i++)document.querySelector('#zin').click()" \
  --view "girada=document.querySelector('#rr').click()" \
  --view "noche=document.querySelector('#night').click()"
uv run tools/screenshot.py shots/<id>/movil.png --hash <id> --size 390x844 --dpr 3
uv run tools/screenshot.py shots/<id>/centro.png          # la vista inicial: ¿se reconoce la silueta sin acercar?
```

Sin lugar (no hay `--hash`), con `__look(x, y, zoom, giro)`: zoom 4 es el de la ficha, 14,2 el de cerca (píxeles de
0,5 m), giro `Math.PI/4` la vista inicial y `+Math.PI` desde el noroeste:

```bash
uv run tools/screenshot.py shots/<id>/ --view "ficha=__look(<x>,<y>,4)" --view "cerca=__look(<x>,<y>,14.2)" \
  --view "girada=__look(<x>,<y>,14.2,Math.PI/4+Math.PI)" \
  --view "noche=(document.querySelector('#night').click(),__look(<x>,<y>,6))"
```

Compare cada vista con las fotos tomadas desde un ángulo parecido (una fachada al poniente necesita la vista girada).
Un dato de la página sin captura (los ganchos `window.__*` de `src/js/99-boot.js`; `MODELS` no es uno):
`uv run tools/probe.py "__E(<x>,<y>)" "__pads.slice(-3)" "__usos.skip" "__stats.t.hitos['<id>']"`.

Contra la referencia del paso 0 (sale con 1 si algo difiere: tiene que cambiar solo el entorno del hito; con
`NOLOTS`, unos pocos edificios menos en `__stats`):

```bash
uv run tools/regress.py --against shots/ref-<id> --view "hito=__look(<x>,<y>,4)"
```

Lista de revisión (`docs/ESTETICA.md` §8), antes de darlo por terminado:

- [ ] La silueta se reconoce en la vista inicial, sin acercar.
- [ ] Al zoom de la ficha se distingue lo que identifica al edificio en las fotos.
- [ ] De cerca, ningún detalle queda como ruido de un píxel ni lo tapa el contorno.
- [ ] Nada parpadea al girar (capas a la misma distancia, techos coplanares).
- [ ] Los colores están en la paleta o tienen una foto que los justifique.
- [ ] Las cuatro orientaciones están completas, también los lados sin fotos.
- [ ] Los frentes a la sombra (sur, poniente) se leen igual; la sombra del hito no mancha sus propios techos.
- [ ] El comentario dice qué es aproximado y qué es licencia.

## 6. Registro

- `CHANGELOG.md`, bajo «## Sin publicar»: qué cambió y con qué fuentes.
- `docs/FUENTES.md`, en «## Modelos de hitos»: cada foto y ficha usada, con su enlace y licencia (de `indice.txt`).
  Sin fotos libres, dígalo ahí (§9.6).
- Una trampa nueva: en `.claude/rules/hitos.md`.
- Si el hito se ve desde la vista inicial (cerca de la plaza), rehaga los pósters del arranque: `make site-assets`.
- Commit con un mensaje en español como los del repo (el hook de pre-commit corre `make check`).

Si se reparten varios hitos entre sesiones paralelas, siga `docs/METODOLOGIA.md` §9.7: cada sesión toca solo su
archivo, la mezcla de `ORDER` se resuelve a mano y lo compartido de `45-landmarks.js` no se toca en paralelo.
