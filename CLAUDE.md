# CLAUDE.md — Talca Isométrica

Maqueta isométrica de Talca (Chile) con lugares jurídicos e icónicos. Lee primero README.md y, para entender por qué las cosas son como son, docs/METODOLOGIA.md. Todo el contenido visible para el usuario está en español de Chile.

## Cómo está organizada esta guía

Este archivo se carga en cada sesión y es corto a propósito: lo que vale para todo el repo y un mapa del resto. El detalle está en `.claude/rules/<tema>.md`: cada regla declara en `paths:` los archivos de su tema, y Claude Code la carga sola cuando la sesión lee o edita uno de ellos (también con un `cat` o `head` de un archivo; no con `grep` ni `ls`). Si planea un cambio antes de abrir el código, o el índice de trampas de abajo nombra algo de su tema, lea la regla primero.

| Regla | Tema | Se carga al tocar |
|---|---|---|
| [`generacion.md`](.claude/rules/generacion.md) | La generación de la maqueta (src/js/) | `src/js/**` |
| [`hitos.md`](.claude/rules/hitos.md) | Los hitos (src/js/hitos/) | `src/js/hitos/**`, `src/js/45-landmarks.js`, `src/js/74-cerro.js`, `pipeline/landmark.py` y 1 más |
| [`ciudad.md`](.claude/rules/ciudad.md) | La ciudad generada (cityGen, lotes, calles) | `src/js/20-grids.js`, `src/js/50-city.js`, `src/js/60-streets.js`, `src/js/62-diagonal.js` y 4 más |
| [`edificios.md`](.claude/rules/edificios.md) | Los edificios de OSM y las huellas de aprendizaje automático | `pipeline/edificios.py`, `src/js/52-edificios.js`, `config/edificios.json`, `config/techos.json` y 2 más |
| [`usos.md`](.claude/rules/usos.md) | Los usos de suelo y las fuentes chilenas | `pipeline/usos.py`, `pipeline/fuentes_cl.py`, `pipeline/cobertura.py`, `config/usos*.json` y 4 más |
| [`rios-vias.md`](.claude/rules/rios-vias.md) | Ríos, calles, Ruta 5, vía férrea y trenes | `src/js/55-rivers.js`, `src/js/60-streets.js`, `src/js/62-diagonal.js`, `src/js/63-paseos.js` y 13 más |
| [`pipeline.md`](.claude/rules/pipeline.md) | El pipeline de datos (pipeline/, config/, data/) | `pipeline/**`, `config/**`, `Makefile`, `tests/**` |
| [`pagina.md`](.claude/rules/pagina.md) | La página y el sitio publicado | `src/page.html`, `src/style.css`, `src/site/**`, `src/js/05-categories.js` y 8 más |
| [`juego.md`](.claude/rules/juego.md) | El juego en Godot (juego/) y la exportación | `juego/**`, `tools/export.py`, `tools/export.js`, `tools/godot/**` y 5 más |
| [`juego-jugador.md`](.claude/rules/juego-jugador.md) | El personaje del juego (vida, armas, jetpack, menú) | `juego/jugador.gd`, `juego/vehiculo.gd`, `juego/vida.gd`, `juego/armas.gd` y 5 más |
| [`herramientas.md`](.claude/rules/herramientas.md) | Las herramientas de tools/ (Playwright, rendimiento) | `tools/**` |

Además:

- la skill `/modelar-hito`: el procedimiento para modelar o rehacer un hito, con sus comandos;
- docs/METODOLOGIA.md (el porqué de cada paso), docs/ESTETICA.md (los criterios visuales), docs/FUENTES.md (fuentes y licencias);
- docs/PENDIENTES.md: las ideas pendientes y lo medido para decidirlas (no son instrucciones);
- CHANGELOG.md: la historia. Una regla dice qué hacer y por qué en una frase; cuándo cambió y qué se midió va en el CHANGELOG o en `raw/eval/`.

Mantenerla: lo nuevo va en la regla de su tema, no aquí; una trampa nueva, en la sección «Trampas» de su regla, con su título en el índice de abajo (`make check`, `docs`, falla si el índice y las reglas no calzan, si una trampa citada en el código o en los docs no está en el índice, si un `paths:` no calza con ningún archivo o si este archivo o una regla pasan su tope de tamaño). Un tema nuevo es una regla nueva, con su fila en la tabla.

## Comandos

Los comandos usan las rutas del Mac. En Linux, `godot` (o `godot4`) en vez de `/Applications/Godot.app/Contents/MacOS/Godot` y `blender` en vez de `/Applications/Blender.app/Contents/MacOS/Blender`; el `Makefile` busca Godot en el PATH solo (o `GODOT=<ruta>`). Lo demás es igual: ver «En Linux» en README.md.

```bash
make build                      # src/ (page.html, style.css, js/) + data/ + config/ -> dist/: index.html y assets/ (el script, three.js y los datos, con hash en el nombre); requiere npm install
python pipeline/build.py --where app.3fa2c1d4e5.js:4026   # el archivo de src/ y la línea de un error de la consola del navegador (app.<hash>.js:N o N, el script; index.html:N o (index):N, la página)
make check                      # revisión rápida (~1 s): JSON, marcadores, hitos, node --check del script, los archivos que pide la página, trampas de config/ y data/ (tools/check.py, PIPELINE), las pruebas de tests/ y compileall; la corre el hook de pre-commit (make hooks)
make golden [SAVE=1] [REF=shots/golden-ref]   # antes (SAVE=1) y después de tocar pipeline/: la salida de 43 comandos y los archivos que escriben, byte a byte (tests/golden.py; ~5 min, sin red salvo las capturas de golf)
python3 tools/datadiff.py [rev | a.json b.json]   # qué cambió en los data/*.json (de una línea): claves, tamaños, elementos distintos, contra HEAD u otra versión
make smoke                      # make lint, y carga dist/ en Chromium: falla si hay errores de consola o la generación sale vacía (~1 min; tools/screenshot.py --strict)
make lint                       # ESLint 10.15 (package.json, versión fija; npm install) sobre el script unido: no-undef, no-redeclare, no-shadow, no-unused-vars, con el archivo y la línea de src/ (tools/lint.py, tools/eslint.config.mjs; ~3 s)
make serve                      # http://localhost:8765
make deploy [DRY_RUN=1]         # make build y publica dist/ en Cloudflare Pages: talca.eduramirez.com (scripts/deploy-cloudflare.sh)
make fetch                      # descarga raw/ (solo la primera vez)
python tools/screenshot.py shots/x.png --hash corte-apelaciones [--size 390x844] [--dpr 2] [--dark] [--js "..."]
python tools/screenshot.py shots/x.png --js "__look(-1640,533,10,Math.PI/4+Math.PI)"   # cámara en (x, y) de grilla, zoom, giro
python tools/screenshot.py shots/ --view "plaza=__look(-60,30,14.2)" --view "giro=__look(-60,30,14.2,Math.PI/4+Math.PI/2)"   # varias vistas de una sola carga
python tools/probe.py "__trains()" "__rail.main.s.length"   # evalúa expresiones en el mapa cargado e imprime JSON (--js corre antes)
uv run --with "playwright==1.63" --with pillow python tools/regress.py --save shots/ref   # antes de un cambio que no debe cambiar el mapa: capturas fijas (teléfono y escritorio) y __stats
uv run --with "playwright==1.63" --with pillow python tools/regress.py --against shots/ref   # después: % de píxeles distintos por vista, imagen de la diferencia y estadísticas que cambiaron (sale con 1)
```

Cada script de `pipeline/` y `tools/` documenta su uso en su docstring (`python <script> --help`); los comandos de cada tema están en su regla. Después de cualquier cambio en la plantilla, `make check` (~1 s; el hook de pre-commit lo corre solo) y una captura con `tools/screenshot.py` (`make smoke` es la mínima que falla sola); las opciones de las herramientas de Playwright (`--gl gpu`, `uv run`, `--view`) están en `herramientas.md`.

**Godot, siempre oculto.** Una sesión de Claude nunca corre el binario de Godot a la vista: al partir se pone al frente y le quita a Edu el teclado y el mouse. Se corre con `tools/godot_oculto.sh … --png|--fps|--cuadro` (sin una de esas tres quedaría corriendo oculto) o con `--headless` cuando no dibuja (`juego.md`).

## Arquitectura

**Pipeline (Python, solo biblioteca estándar).** `raw/` (las descargas, fuera de git) y `config/` (lo escrito a mano) → los scripts de `pipeline/` (se corren desde `pipeline/`, porque se importan entre sí por nombre) → `data/*.json` → `pipeline/build.py` → `dist/`. Los módulos compartidos (`common.py`, `geom.py`, `osm.py`, `net.py`, `cli.py`) y el flujo de cada archivo de datos: `pipeline.md`.

**Coordenadas.** Todo usa «metros de grilla» (`common.loc` / `common.unloc`):
- El origen es la Plaza de Armas.
- La maqueta es la comuna de Talca, recortada por su límite de OSM (`common.comuna()`, `DATA.limit`), dentro de la caja `common.EXT` (x ∈ [−4.920; 15.800], y ∈ [−10.840; 13.000]; `DATA.ext`, `XMIN`… en la plantilla). Lo que cae en la caja fuera del límite no se dibuja.
- La grilla está girada +5° para que las calles numeradas queden paralelas a los ejes.
- x crece hacia el oriente e y hacia el norte.
- En three.js: `X = x`, `Z = -y` (`Y` es la altura). El suelo no está en `Y = 0`: está en `E(x, y)`, el relieve exagerado, con 0 en la plaza.
- En `geometry.json` las geometrías están codificadas en delta con enteros `[x0,y0,dx1,dy1,…]`; las decodifica `dec()` en la plantilla.

**La página (`src/`, ~4500 líneas).** `build.py` arma `dist/index.html` (`page()`) y el script, `dist/assets/app.<hash>.js` (`script()`), con los fuentes:

- `src/page.html`: el documento entero (el `<head>` del sitio, con título, descripción, canónica, Open Graph y tarjeta de Twitter con `og.jpg`; el DOM; el póster), el cargador de los datos en el `<head>` (`window.__data`: un `fetch` por archivo, con los nombres en `/*DATA*/`, antes que nada para que bajen mientras llegan three.js y el script) y `<!--SCRIPTS-->`, donde `build.py` pone three.js y el script; `src/style.css` va en línea en su `/*STYLE*/`.
- `src/js/NN-<sección>.js`: el script, unido en el orden de los nombres en un solo archivo y un solo ámbito (la función `async` que abre `00-start.js`, que espera los datos, y cierra `99-boot.js`). Antes de cada archivo, `build.py` pone una línea `// ---- src/js/<archivo> ----` (con `:N` donde un archivo sigue después de los hitos): en las fuentes del navegador dice de dónde viene el código.
- `src/js/hitos/<id>.js`: un hito por archivo, pegados dentro de `buildModels` en el marcador `/*HITOS*/` de `45-landmarks.js`, en el orden de `src/js/hitos/ORDER`.

| Archivo (`src/js/`) | Qué hace | Detalle |
|---|---|---|
| `00-start.js` | abre la función que envuelve todo el script, `$`, el aviso de carga | `generacion.md` |
| `05-categories.js` | `CATS` y las capas (`LEGAL`, `CITYCATS`, `enabled`) | `pagina.md` |
| `10-decode.js` | manzanas (`blocks`) y calles (`streets`) | `generacion.md` |
| `15-utils.js` | `STATS`, `rng`, `pip` y sus variantes, recortes (`clipKeep`, `splitAt`), `PolyPath` | `generacion.md` |
| `20-grids.js` | `blockAt`, `segsAt`, el raster `occ` (un `Grid`), `urbanAt` | `ciudad.md` |
| `25-terrain.js` | el relieve (`ER`, `EH`, `E(x,y)`, `EN`, `wildAt`) y el límite de la comuna (`CM`, `inTerrain`) | `generacion.md` |
| `26-cobertura.js` | la cobertura de CONAF (`COB`, `EW`, `cobK`) | `usos.md` |
| `30-geometry.js` | el constructor de geometría (`face`, `prism`, `flat`, `drape`), `Y_LAYER`, `STAGE`, `tiled`/`instTiled` y las franjas | `generacion.md` |
| `35-palettes.js` | colores de la escena | `generacion.md` |
| `40-three.js` | cámara, luces, `winMat()` | `generacion.md` |
| `45-landmarks.js` | `buildModels` y lo que comparten los hitos (`KH`, `facade`, `localFrame`, `groundLayer`, `onFinalTerrain`, `deckBridge`…) | `hitos.md` |
| `hitos/<id>.js` | un hito por archivo, en el orden de `hitos/ORDER` | `hitos.md` |
| `50-city.js` | `cityGen`, `CITY_ORDER`, barrios y recetas, `blockTrees` | `ciudad.md` |
| `52-edificios.js` | los edificios de OSM y las huellas (`ED`, `edificiosPlan`, `edificiosBase`, `edHulls`) | `edificios.md` |
| `55-rivers.js … 68-rail.js` | ríos, veredas, diagonal, paseos, `buildBase`, Ruta 5, vía férrea | `rios-vias.md` |
| `70-trains.js` | los trenes y su horario | `rios-vias.md` |
| `72-alameda.js` | la Alameda | `ciudad.md` |
| `74-cerro.js` | el Cerro La Virgen, `wildTrees` | `hitos.md` |
| `76-usos.js` | los usos de suelo (`USOS`, `usosPlan`, `usosBase`) | `usos.md` |
| `80-trees.js` | árboles instanciados, de cerca y de lejos | `generacion.md` |
| `82-terrain-mesh.js` | la malla del terreno y los bordes del diorama | `generacion.md` |
| `84-lights.js` | faroles (`lamps`, `GLOW`) y el anillo de selección | `generacion.md` |
| `86-camera.js` | la vista inicial, la cámara, `fitShadow`, `lift`, `framed` | `generacion.md` |
| `90-overlay.js` | marcadores y etiquetas en el DOM | `pagina.md` |
| `92-panel.js` | ficha, recorridos, filtros, búsqueda y enlaces `#id` | `pagina.md` |
| `94-pixel-art.js` | `paRender()`: todo se dibuja como pixel art | `generacion.md` |
| `99-boot.js` | los ganchos `window.__*`, el orden del arranque y la segunda etapa (`rest()`) | `generacion.md` |

## Convenciones

- **Lugares.** Cada lugar nuevo se agrega en `pipeline/pois.py` y lleva fuente (`src`) y confianza honesta:
  - `alta`: punto OSM o del Consejo de Monumentos Nacionales que calza con la dirección.
  - `media`: una fuente secundaria, o ubicación calculada con `geocode.py`.
  - `baja`: fuentes en conflicto.

  Nunca inventes coordenadas. Si solo hay dirección, usa `python pipeline/geocode.py address "..."` y dilo en `fact`.
- **Recorridos.** Se definen en `TOURS` (`pois.py`) como listas de ids. El script valida que cada id exista.
- **Textos.** Español claro y directo, sin muletillas. Las fichas son resúmenes propios; no copies párrafos de las fuentes.
- **Tema.** Los colores de la interfaz son tokens CSS en `:root`, redefinidos para el modo oscuro en `@media (prefers-color-scheme: dark)` y en `[data-theme="dark"]`. Cualquier color nuevo debe definirse en los tres lugares; `tools/check.py` (`css_tokens`) falla con un color fijo fuera de un token y si los dos bloques oscuros difieren.
- **Tipografía.** Alegreya SC (títulos), Alegreya Sans (texto) e IBM Plex Mono (direcciones y datos).
- **Herramientas.** Toda herramienta que se escriba durante una tarea y pueda volver a servir (un panel de diagnóstico, una revisión contra OSM, un script que deriva datos) se agrega al repo, no se deja en el scratchpad ni en un directorio temporal: en `pipeline/` (Python, solo biblioteca estándar; Pillow solo para dibujar, importado dentro de la función) o en `tools/`. Su uso se documenta una sola vez, en su docstring (lo imprime `--help`); además, una línea en «Comandos» de la regla de su tema (`.claude/rules/<tema>.md`; aquí solo si la usan todas las sesiones), otra en la estructura del README y una mención en docs/METODOLOGIA.md donde se use. Si la herramienta necesita algo de la página, se expone en `window.__*` (como `__look`, `__pads` y `__E`, la altura del suelo). Así `pipeline/traces.py` salió de la revisión del Lircay y el Piduco.
- **Dependencias.** Todas con versión fija, y una sola fuente para cada una, que Dependabot sube con un PR los lunes (`.github/dependabot.yml`, con una semana de espera tras cada publicación; también las alertas y los PR de seguridad de GitHub): Python en `requirements.txt` (Pillow, Playwright) y `requirements-geo.txt` (`tools/ml_buildings.py`, `tools/sentinel.py`), con `==`; npm en `package.json` (three.js, ESLint) y `scripts/deploy/package.json` (Wrangler, aparte para que `make build` no baje sus ~270 MB; `deploy-cloudflare.sh` corre `npm ci` ahí cuando cambia el lockfile), exactas y con `package-lock.json` (`.npmrc`: `save-exact`). El `Makefile` (`$(PIL)`, `$(PW)`) y `tests/golden.py` leen `requirements.txt`; los encabezados PEP 723 de `tools/` repiten las versiones porque Dependabot no los lee, y `tools/check.py` (`pins`, en `make check`) falla si difieren, si algo no está fijo o si un `package-lock.json` no resuelve su `package.json`: al aceptar un PR de pip, cambie los encabezados que nombra. Nada corre con `npx <paquete>` (bajaría la última versión: Wrangler la correría con las credenciales de Cloudflare). Dependabot no sube three.js ni Playwright (`ignore`): three.js está fijado en r128 (`build.py` copia `node_modules/three/build/three.min.js` a `dist/assets/`, así que `make build` necesita `npm install`), y si se actualiza, revisa `onBeforeCompile` en `winMat()` (`src/js/40-three.js`), que reemplaza `#include <tonemapping_fragment>` y `#include <project_vertex>`; Playwright 1.63 va con el Chromium de su caché y las referencias de `tools/regress.py` y `tools/hitos.py` se tomaron con él. Los ejemplos de uso de los docstrings (`uv run --with pillow …`) siguen sin versión: son para la consola, y uv toma la de su caché.

## El sitio publicado

`dist/` (fuera de git) se publica en talca.eduramirez.com con `make deploy`, y **también solo**: `.githooks/pre-push` (`make hooks`) publica cuando un push a `origin` actualiza `main` (`git push --no-verify` o `TALCA_SKIP_DEPLOY=1` lo saltan). El resto (Cloudflare Pages, `_headers`, el póster, `og.jpg`): `pagina.md`.

## Trampas

La que vale para todo el código:

- **Un solo script en muchos archivos.** `src/js/*.js` no son módulos: se unen en un solo archivo (`dist/assets/app.<hash>.js`), dentro de una función, y ninguno es JavaScript válido por sí solo (no los revise con `node --check` uno a uno: `make check` revisa el resultado y da el archivo y la línea del error; para uno de la consola del navegador, `python pipeline/build.py --where app.<hash>.js:N`). `make lint` (ESLint sobre el script unido) avisa de un nombre que tapa a otro de primer nivel o de uno sin declarar: con unos 500 nombres en un ámbito, un `const H` en una función tapaba el alto de la vista. Una `const` de primer nivel no se puede repetir entre archivos, y un archivo nuevo entra donde lo pone su número: lo que declara no existe para el código de primer nivel de los archivos anteriores (sí dentro de las funciones que corren después, en `boot`). Lo mismo vale para los hitos dentro de `buildModels` y su `ORDER`.

Las demás están en su regla, que se carga al tocar los archivos de su tema. Sus títulos:

- **`generacion.md`**: «Árboles» · «Relieve» · «Sombras que no se ven» · «Lo que proyecta sombra se dibuja por su cara trasera» · «El arranque en dos etapas» · «Una malla sobre toda la comuna se dibuja entera» · «El mapa de sombras no se redibuja solo» · «Todo pasa por el pixel art» · «`prism()` hunde 4 m los muros que parten bajo 0,31» · «Lo que mide menos de 0,4 m no se dibuja, tampoco en la vía» · «La maqueta es la comuna, no su caja» · «`occ` no es un arreglo» · «Lo que recorre todos los nodos del relieve»
- **`hitos.md`**: «Las alturas de OSM no sirven para hitos» · «Caras sin normal en `S`» · «El punto del lugar no es el centro del hito» · «La caja de descarga de OSM» · «Ventanas en caras que no son fachadas» · «Líneas de 0,5 m en un marco girado» · «`E()` dentro de `buildModels` es el terreno sin explanadas» · «Capas planas sin explanada» · «Techos a la misma altura en `S`» · «`prism()` y `face()` triangulan en abanico desde el primer vértice» · «Las caras inferiores no se ven» · «Calzadas del mapa y plantas de OSM» · «El contorno de OSM puede incluir estacionamientos» · «`buildCerro()` corre después del terreno» · «El punto de un edificio junto a la Alameda» · «Explanadas vecinas» · «OSM no siempre trae los patios» · «Un hito sobre un uso de suelo lo saca entero» · «Un hito sobre un uso del campo deja las parcelas como estaban» · «Un hito en la vereda, y el edificio de OSM que es su único edificio»
- **`ciudad.md`**: «Calles bajo las manzanas» · «El orden de la ciudad» · «Lotes y `occ`» · «Estilos de manzana que no aparecen» · «Lo que no es fachada, en `Z`» · «Filas de casas sin muros interiores» · «`NOLOTS` es caro»
- **`edificios.md`**: «Los edificios de OSM marcan `occ` con 3, no con 1» · «Losas de los edificios de OSM» · «Las manzanas mixtas» · «Las huellas de aprendizaje automático» · «Las torres en la imagen de Esri»
- **`usos.md`**: «Manzanas «sin información»» · «Los usos del campo reemplazan las parcelas genéricas» · «Usos de suelo que se superponen» · «El suelo de un uso no pisa el agua ni los hitos» · «Datos de OSM posteriores a la imagen de Esri» · «Los `bi` de `config/usos.json` son índices de `data/geometry.json`» · «Los usos están en varios archivos, y su lugar siembra su dibujo» · «Una entrada nueva con suelo, dentro o fuera de otra, nunca a medias» · «Las manzanas del Censo 2024 no reemplazan las de 2017» · «`EW` no es solo la pendiente»
- **`rios-vias.md`**: «Datos fuera del grafo» · «Los ríos están sobre las manzanas, a 0,11» · «Los ríos están nivelados» · «Etiquetas de los ríos por punto» · «Dos ríos de OSM se tocan sin compartir nodos» · «Ríos en `config/trazados.json`» · «La Ruta 5 va en trinchera y el relieve no la puede dibujar» · «Las líneas de OSM de la Ruta 5 son el borde entre la primera y la segunda pista» · «La vía se dibuja después de las explanadas» · «Los pasos bajo nivel suben la vía, no bajan la calle» · «Cada calle del mapa que cruza la vía está en `DATA.railx`» · «La vía principal pasa bajo la cubierta de la estación» · «Lo que se mueve no usa `winMat()`» · «Una pestaña oculta no anima» · «El tren detenido en la estación no se ve»
- **`pipeline.md`**: «Medianas de calles» · «Grilla irregular» · «La Alameda (4 Norte)» · «La imagen satelital puede ser vieja» · «Overpass puede no responder» · «La búsqueda por caja de Mapillary pierde fotos» · «La posición de una foto de Mapillary puede errar 10 m» · «El relieve es de superficie»
- **`pagina.md`**: «El póster del arranque»
- **`juego.md`**: «Exportar lo generado (`tools/export.py`)» · «El juego carga la comuna por teselas» · «Los vehículos del juego y los pasos bajo la Ruta 5» · «La red de calles del juego no sale de los vértices compartidos» · «Los letreros de las calles del juego» · «Los autos y los faroles del juego son datos, como los árboles» · «Las fachadas de cerca del juego son un registro por edificio, no la geometría del glb»
- **`juego-jugador.md`**: «Bajarse del vehículo y el servidor de física» · «El jetpack del juego» · «Los tiros en la red» · «En captura la bandera manda el anfitrión» · «Las armas del juego»
- **`herramientas.md`**: «Navegadores sin GPU» · «Rotar en `--js`» · «`__look` no limita el zoom»
