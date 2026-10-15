# CLAUDE.md — Talca Isométrica

Maqueta isométrica de Talca (Chile) con lugares jurídicos e icónicos. Lee primero README.md y, para entender por qué las cosas son como son, docs/METODOLOGIA.md. Todo el contenido visible para el usuario está en español de Chile.

## Comandos

```bash
make build                      # src/template.html + data/ + config/ -> dist/talca.html y dist/index.html
make serve                      # http://localhost:8765
make pois build                 # tras editar pipeline/pois.py
make data build                 # tras editar config/trazados.json o process_geometry.py (requiere raw/)
make elevation build            # tras editar elevation.py (requiere raw/dem/; no necesita las otras fuentes)
make fetch                      # descarga raw/ (solo la primera vez)
make validate                   # distancia entre cada lugar y su dirección en la grilla (requiere raw/)
python tools/screenshot.py shots/x.png --hash corte-apelaciones [--size 390x844] [--dpr 2] [--dark] [--js "..."]
python tools/screenshot.py shots/x.png --js "__look(-1640,533,10,Math.PI/4+Math.PI)"   # cámara en (x, y) de grilla, zoom, giro
python tools/screenshot.py shots/ --view "plaza=__look(-60,30,14.2)" --view "giro=__look(-60,30,14.2,Math.PI/4+Math.PI/2)"   # varias vistas de una sola carga
uv run --with playwright --with pillow python tools/variants.py shots/hoja.png --view "Plaza:__look(-60,30,14.2)" --variant "Sin pixel art:__pixelArt(null)" --variant "0,75 m:__pixelArt({m:0.75})" --reset "__pixelArt({m:0.5})" --scale 1   # vistas x variantes en una hoja
python pipeline/satellite.py plaza-de-armas [500]   # manzanas sobre imagen satelital, en diagnostics/
python pipeline/geocode.py address "2 Norte 781"
python pipeline/diagnostics.py centro          # panel PNG en diagnostics/
uv run --with pillow python pipeline/landmark.py osm estadio [250]   # planta OSM + plano en diagnostics/
python pipeline/landmark.py frame estadio 815575960 [más vías]       # vías en el marco local del modelo
python pipeline/landmark.py photos estadio ["consulta"]              # fotos de Commons, más recientes primero
python pipeline/landmark.py photos diagonal "Isidoro del Solar"     # con consulta, el nombre puede no ser un lugar (una calle)
python pipeline/traces.py check piduco [--osm '{...}'] [--pads pads.txt]    # un río de OSM contra el mapa: cruces, puentes, manzanas en el agua
uv run --with pillow python pipeline/traces.py panel lircay x0 x1 y0 y1 [18]  # eje, agua y puentes de OSM sobre la imagen satelital
python pipeline/traces.py tiles x0 x1 y0 y1 <nombre>                # API map de OSM por cajas (sin Overpass) -> raw/osm/map-<nombre>.json
python pipeline/traces.py line <nombre> clave=regex [...] [--mid]   # encadena vías de OSM en `puntos` para config/trazados.json
python pipeline/railway.py check este                               # la vía y el ramal de OSM: cruces con las calles (bajo la vía o a nivel), puentes, postes, señales
python pipeline/railway.py write este                               # lo mismo, escrito en config/trazados.json -> ferrocarril (y su ramal); luego make data build
uv run --with pillow python pipeline/landmark.py osm 4178,3725 [120]  # planta OSM alrededor de un punto de la grilla (un puente, un cruce), no de un lugar
```

Después de cualquier cambio en la plantilla, verifícalo con `tools/screenshot.py`. Imprime las estadísticas de generación y los errores de consola. Una vista de escritorio y una de móvil suelen bastar; con `--view nombre=expresión` (repetible) se toman varias de una sola carga, que es lo que cuesta (~1 min con SwiftShader). Si el Python del sistema no tiene Playwright (o Pillow para `satellite.py`), `uv run --with "playwright==1.63" python tools/screenshot.py …` funciona sin instalar nada: el Chromium de la caché de Playwright (`~/Library/Caches/ms-playwright/chromium_headless_shell-1243`) es el de la 1.63; una versión más nueva pide otro navegador y falla con «Executable doesn't exist».

## Arquitectura

**Pipeline (Python, solo biblioteca estándar).** Ejecuta los scripts desde `pipeline/`, porque se importan entre sí por nombre:

`raw/` + `config/trazados.json` (+ el Río Claro de la API de OSM, en `raw/osm/rio-claro.json`) → `process_geometry.py` → `data/geometry.json` (`water`: ejes; `area`: el agua del Claro con sus islas; `rail`, `ramal`, `railx`, `rmast`, `rsig`, `rgauge`: la vía férrea, que `pipeline/railway.py` escribe en `config/trazados.json`)
`raw/dem/S36W072.hgt.gz` (SRTM) → `elevation.py` → `data/elevation.json`
`pois.py` → `data/pois.json`, `data/pois.csv`
`build.py` marca como construidas (tipo 3) las manzanas de `config/manzanas.json` e inyecta geometry + elevation (como `DATA.elev`) + `config/grid_lines.json` (como `DATA.lines`) + pois en `src/template.html`, reemplazando los marcadores `/*DATA*/` y `/*POIS*/`.

**Coordenadas.** Todo usa «metros de grilla» (`common.loc` / `common.unloc`):
- El origen es la Plaza de Armas.
- La grilla está girada +5° para que las calles numeradas queden paralelas a los ejes.
- x crece hacia el oriente e y hacia el norte.
- En three.js: `X = x`, `Z = -y` (`Y` es la altura). El suelo no está en `Y = 0`: está en `E(x, y)`, el relieve exagerado, con 0 en la plaza.
- En `geometry.json` las geometrías están codificadas en delta con enteros `[x0,y0,dx1,dy1,…]`; las decodifica `dec()` en la plantilla.

**Plantilla (`src/template.html`, ~1040 líneas).** Es un fragmento HTML, no un documento completo: la plataforma de artifacts de Claude agrega `<!doctype>`, `<head>` y `<body>` (`build.py --standalone` hace lo mismo para uso local). Secciones del script, en orden:

| Sección | Qué hace |
|---|---|
| categories | `CATS`: nombre e ícono SVG por categoría; `LEGAL` lista las capas jurídicas |
| decode data | manzanas (`blocks`: área, centroide, bbox) y calles (`streets`) |
| utils | `rng` con semilla (mulberry32), `pip`, `segDist2` |
| grillas espaciales | `blockAt` (celdas de 100 m), `nearStreet` (40 m), raster de ocupación `occ` (2,5 m) para que los edificios no se superpongan (1: hitos, ríos y líneas; 2: lotes de la ciudad) |
| terrain | decodifica `DATA.elev`: `ER` (relieve real) y `EH` (exagerado con `relief()`, más explanadas). `E(x,y)` es la altura del suelo, interpolada dentro del mismo triángulo que dibuja la malla; `EN` la normal; `wildAt` la cobertura de matorral (pendiente real) |
| `GB` | constructor de geometría indexada (posición Float32, normal Int8, color Uint8). `face()` orienta cada cara según la normal; `prism()` para cajas (los muros que parten del suelo bajan 4 m), `gable()` para techos a dos aguas, `flat()` para polígonos. `B.dy` sube todo lo que se emite; `drape()` corta capas planas por las aristas del terreno y las apoya en él |
| palettes | colores de la escena |
| three setup | cámara ortográfica, luces (cielo `HEMI_I`, sol `SUN_I` en la dirección `SUND`, con sombras), `winMat()`: Lambert con ventanas procedurales en el shader (`uNight`, `uWin`) |
| landmark models | `buildModels(B, S)`: modelos a mano de los hitos, cada uno en su bloque bajo una línea `// ==== hito: <id> ====` (no las borre: permiten rehacer hitos en paralelo sin conflictos). Reservan su huella en `occ` y registran una explanada (`padAt`) antes de generar la ciudad. `S` se dibuja sin ventanas procedurales (el Estadio, la Catedral). `localFrame(X,Y,A)` da el marco local de un hito (`G`, `V`, `N3`, `R`) y `facade(S,F,K)` el vocabulario de fachada (muros, paños, arcos, vitrales, techos; ESTETICA §7). `NOLOTS` excluye recintos enteros de la ciudad generada; `GLOW` agrega luces nocturnas a `lamps()`. `deckBridge(S,K,pts,hw,hAt,o)` (antes de `buildModels`) dibuja un tablero sobre pilas para cualquier puente, con la altura `hAt(p)` del vano, veredas y parapetos o balaustrada, y marca su huella en `occ`: lo usan los dos puentes del Río Claro |
| procedural city | `styleFor()` clasifica cada manzana (core, core2, ind, apt, house); `cityGen(B, Y)` recorre cada tramo de calle por ambos lados y coloca casas, cada una sobre su lote: una losa en `Y` (sin ventanas) que llega al medio de la manzana, con alas, construcciones al fondo, mediaguas y árboles de patio. Los lotes se prueban entre sí como rectángulos exactos (`LOTS`, `lotFree`, `sepQuad`) |
| base layers | parcelas agrícolas, manzanas, ríos (con suavizado Chaikin), Ruta 5 (`ruta5Base`, bajo las calles), calles, vía férrea (`railBase`, sobre ellas); todo pasa por `drape()`. Los tres ríos son de OSM (`RIV[k]`, de `DATA.area[k]`; ramas laterales en `DATA.branch`) y van sobre las manzanas (`riverBase`): el agua de todos en una malla propia (`riverWater`, `matWater` con `polygonOffset`), con franjas de ripio fuera de las orillas y una cinta de `ancho_m` sobre el eje donde no hay área (`riverRuns`); `riversLevel`/`riversRelevel` los nivelan, `riversOcc` los deja ocupados y `linesOcc` hace lo mismo con la Ruta 5 y la vía férrea. `CLARO` e `inClaro` siguen como atajos para los hitos de la ribera. Una calle con `s.bridge` (la Ruta K-60-J sobre el río) no se dibuja: la dibuja el hito del puente. `railBase()` dibuja las dos líneas (`DATA.rail`, `DATA.ramal`) y las vías de patio (`RAIL_YARD`) muestreadas cada 0,7 m con un perfil de alturas: en el suelo, balasto, durmientes y rieles drapeados; donde una calle pasa bajo la vía (`DATA.railx` tipo 0), terraplén y tablero; los puentes que registran los hitos (`RAIL_BR`) se dibujan ahí, con el perfil final. Lo que no es plano (terraplenes, tableros, puentes, postes, señales, barreras) va en una malla propia que proyecta sombra. `RAILP` (`window.__rail`) guarda cada línea como camino para el tren |
| `buildCerro`, `wildTrees` | estatua del Cerro La Virgen sobre el terreno real; árboles en manchones en las laderas |
| trees | dos `InstancedMesh`: árboles redondos y álamos |
| `terrainMesh` | malla del terreno (colores por cobertura) y bordes del diorama que siguen su perfil |
| camera / input | `fitShadow()` ajusta la cámara de sombras a lo que muestra la vista en cada `placeCam()`. `view {tx, ty, zoom, az}`, que apunta al plano `Y = 0`; `placeCam()`, `pan()`, `zoomAt()`, `flyTo()`; `ground()` busca el terreno bajo un punto de la pantalla y `lift()` da el punto del plano que centra un punto del terreno; `framed()` corrige el objetivo para que el lugar quede en el área libre entre el panel y la ficha |
| readout | `gridAddr()` convierte un punto en dirección aproximada usando `DATA.lines` |
| overlay | marcadores y etiquetas de calles en el DOM, proyectados en cada cuadro; `layout()` evita superposiciones por prioridad |
| selection / panel | ficha, recorridos, filtros, búsqueda y enlaces `#id` |
| pixel art | `paRender()`: la escena siempre se dibuja como pixel art. Se renderiza a 1/k de la pantalla, con píxeles de arte de ~0,5 m (`k` sigue al zoom y a la densidad de la pantalla), más una pasada de normales; una pasada de pantalla agranda cada píxel a k × k y oscurece la silueta y los pliegues. La imagen está anclada al origen de la grilla para que los píxeles no titilen al desplazar. `window.__pixelArt(opciones)` lo cambia y `__pixelArt(null)` lo apaga (para comparar con `tools/variants.py`) |
| boot | orden: `riversLevel()` y `riversOcc()` → hitos (registran explanadas) → `applyPads()` → `riversRelevel()` → terreno y capas base → ciudad (los árboles de `TREES`, plantados por los hitos, van con los demás) → sombras (todas las mallas las reciben; las proyectan `B`, `S`, el Cerro y los árboles); genera todo dentro de `setTimeout` (para mostrar la pantalla de carga) y deja `window.__stats` |

El render se hace solo cuando hace falta: `loop()` dibuja únicamente si `dirty` está activo.

## Modelar un hito

Los hitos se rehacen uno por uno sobre su planta real y con estética de pixel art. El Estadio Fiscal y la Catedral son los ejemplos de referencia. Para casos particulares, copie del hito que se parezca: en ladera y fuera de toda explanada, el Cerro La Virgen (`buildCerro`); un campus de decenas de edificios de OSM sin explanada y con pasto apoyado en el terreno, la U. de Talca y la UCM; vías que siguen el suelo junto a una explanada, la Estación; una isla entre calzadas, La Victoria; plantas cóncavas y relieve real en la fachada, el Hospital; techos a cuatro aguas, la Ex Cárcel y el Liceo Abate Molina; un parque con prados, senderos, juegos y muelles sobre el agua, el Parque Río Claro; un puente de tablero sobre pilas que reemplaza una calle del mapa, los puentes del Río Claro; un puente ferroviario con vigas de celosía sobre pilas de piedra, que la vía cruza a la altura de su perfil, el puente-lircay-ferrocarril (`RAIL_BR`, `railGirder`, `railPiers`). El procedimiento completo está en docs/METODOLOGIA.md §9 y los criterios visuales (escala, lenguaje, paleta, lista de revisión) en docs/ESTETICA.md. En resumen:

1. `landmark.py osm <id>`: la planta y el plano. Compruebe si el punto del lugar cae en el hito (suele ser la dirección, en un borde), si la caja cubre todo el hito y si la huella choca con calles del mapa.
2. `landmark.py frame <id> <vía de referencia>`: origen y giro. Escriba el modelo en (u, v) con `G(u,v)`, como el estadio.
3. `landmark.py photos <id>` y prensa sobre remodelaciones. Las fotos fechadas mandan sobre el satélite para techos, alturas y colores.
4. El modelo:
   - pixel art: peldaños y arcos escalonados, dos tonos alternados, molduras blancas, líneas de 0,5 m, paleta local `K` partiendo de ESTETICA.md §4;
   - `S` para lo que no lleva ventanas;
   - `occMark` con la huella real, `padAt`, `NOLOTS` si hay recinto cercado y `GLOW` para luces;
   - un comentario con los ids de OSM, las fuentes y lo aproximado.
5. Capturas: ficha, de cerca, girada, noche y móvil (las líneas `--js` están en §9.5). Compárelas con las fotos. Una a la vez: varias en paralelo agotan el tiempo de Playwright.
6. Registre en CHANGELOG, docs/FUENTES.md (fotos y licencias) y aquí, si aparece una trampa nueva.

## Convenciones

- **Lugares.** Cada lugar nuevo se agrega en `pipeline/pois.py` y lleva fuente (`src`) y confianza honesta:
  - `alta`: punto OSM o del Consejo de Monumentos Nacionales que calza con la dirección.
  - `media`: una fuente secundaria, o ubicación calculada con `geocode.py`.
  - `baja`: fuentes en conflicto.

  Nunca inventes coordenadas. Si solo hay dirección, usa `python pipeline/geocode.py address "..."` y dilo en `fact`.
- **Recorridos.** Se definen en `TOURS` (`pois.py`) como listas de ids. El script valida que cada id exista.
- **Textos.** Español claro y directo, sin muletillas. Las fichas son resúmenes propios; no copies párrafos de las fuentes.
- **Tema.** Los colores de la interfaz son tokens CSS en `:root`, redefinidos para el modo oscuro en `@media (prefers-color-scheme: dark)` y en `[data-theme="dark"]`. Cualquier color nuevo debe definirse en los tres lugares.
- **Tipografía.** Alegreya SC (títulos), Alegreya Sans (texto) e IBM Plex Mono (direcciones y datos).
- **Herramientas.** Toda herramienta que se escriba durante una tarea y pueda volver a servir (un panel de diagnóstico, una revisión contra OSM, un script que deriva datos) se agrega al repo, no se deja en el scratchpad ni en un directorio temporal: en `pipeline/` (Python, solo biblioteca estándar; Pillow solo para dibujar, importado dentro de la función) o en `tools/`, con un docstring de uso al comienzo, una línea en «Comandos» de este archivo, otra en la estructura del README y una mención en docs/METODOLOGIA.md donde se use. Si la herramienta necesita algo de la página, se expone en `window.__*` (como `__look` y `__pads`). Así `pipeline/traces.py` salió de la revisión del Lircay y el Piduco.
- **Dependencias.** three.js está fijado en r128 (build UMD de cdnjs). Si se actualiza, revisa `onBeforeCompile` en `winMat()`, que reemplaza `#include <tonemapping_fragment>` y `#include <project_vertex>`.

## Restricciones si se publica como artifact de Claude

- Solo se permiten scripts de cdnjs, jsdelivr o unpkg y estilos de Google Fonts.
- Sin `fetch` externo: los datos tienen que ir incrustados.
- Sin descargas iniciadas por la página, sin `alert`, `confirm` ni `prompt`.
- `location.hash` solo acepta un identificador simple (`#corte-apelaciones`), no pares `clave=valor`.
- Máximo 16 MB.

Para publicar: `make build` y sube `dist/talca.html`, el fragmento, no `index.html`. `dist/` no está en git: es un resultado de la plantilla y los datos.

## Trampas conocidas

- **Medianas de calles.** `geocode.lines()` calcula la mediana de cada calle dentro de 900 m de la plaza. Con una ventana mayor, algunas calles salen corrompidas por tramos lejanos con el mismo nombre: así quedó mal ubicada la Universidad Autónoma en la v1 (ver CHANGELOG). `config/grid_lines.json` es la versión revisada a mano y es la única que usa el mapa.
- **Grilla irregular.** La grilla es regular solo en el centro, hasta unas 9–10 cuadras de la plaza. Más afuera las calles se curvan, y cerca de la vía férrea (11–12 Oriente) faltan números.
- **La Alameda (4 Norte).** Es una avenida con parque central de unos 70 m. Las direcciones sobre ella necesitan `side_off` de 45–95 m, no 14.
- **Calles bajo las manzanas.** Las manzanas del censo pueden contener pasajes interiores. Por eso las calles se dibujan encima de las manzanas (y 0,12–0,15 contra 0,10) y los edificios se generan a lo largo de las calles, no del borde de la manzana.
- **Manzanas «sin información».** El Censo da ese tipo (1) a toda manzana sin viviendas, y la plantilla la pinta como parque (`built` falso: sin lotes, árboles densos). En el centro muchas son comercio o recintos. Si una se ve verde y no lo es, compruébalo con `pipeline/satellite.py` y agrega un punto dentro de ella en `config/manzanas.json`; no edites `data/geometry.json`, que `make data` regenera.
- **Datos fuera del grafo.** El grafo de cicloconecta excluye autopistas (la Ruta 5 no está) y ferrocarriles. Por eso esos trazados están en `config/trazados.json`: puntos tomados de OSM una vez (la Ruta 5 y el tramo norte de la vía; ver `fuente`) o a mano (el resto de la vía). Los ríos se bajan de OSM en `make data`.
- **Navegadores sin GPU.** En Chromium sin GPU (las capturas) hay que usar SwiftShader; ver los argumentos en `tools/screenshot.py`.
- **Árboles.** `IcosahedronGeometry` ya viene sin índice en r128; `treeGeo()` lo detecta para no llamar a `toNonIndexed()`.
- **Relieve.** Todo lo nuevo que vaya en el suelo necesita la altura del terreno: capas planas en `buildBase()` (pasan por `drape()`), objetos con `B.dy = groundMin(huella)`, puntos sueltos con `E(x, y)`. `MODELS[id].h` es absoluta (se le suma el suelo al terminar `buildModels`). Para centrar la cámara en un lugar, usa `lift(x, y)`, no `(x, y)`. Si cambias la triangulación de `terrainMesh()`, cambia `sampleTri()` igual: `drape()` depende de que coincidan.
- **La imagen satelital puede ser vieja.** Las teselas de Esri que usa `satellite.py` sirven para plantas y manzanas, pero pueden tener años: en el Estadio Fiscal son anteriores a las cubiertas de 2017. Para alturas, techos y colores de un hito, contrasta con fotos recientes (Wikimedia Commons; la etiqueta `wikimedia_commons` de OSM lleva a la categoría).
- **Las alturas de OSM no sirven para hitos.** `height` y `building:levels` suelen ser valores por defecto: la torre de la Catedral dice 17 m y mide ~39. Mida en una foto frontal con un ancho conocido de la planta como escala.
- **Caras sin normal en `S`.** El material dibuja solo la cara de frente y `face()` ordena los vértices según la normal que recibe. Las caras verticales (muros, hastiales, detalles de fachada) necesitan su normal explícita (`N3(...)`); sin ella, `face()` solo garantiza que la cara mire hacia arriba.
- **El punto del lugar no es el centro del hito.** Las coordenadas de `pois.py` son direcciones. En recintos grandes caen en el borde: el Estadio quedó 100 m corrido y montado sobre 5 Norte por centrarlo ahí. Ubique el modelo con la planta de OSM y apunte `MODELS[id]` a su centro.
- **La caja de descarga de OSM.** Si no cubre todo el hito, faltan piezas sin aviso: la primera descarga del estadio dejó fuera dos de sus cuatro torres. Use `landmark.py osm <id> <media caja>` con margen.
- **Sombras que no se ven.** Con el sol desde el nororiente las sombras caían detrás de los edificios (al poniente), ocultas desde la vista inicial: parecía que no funcionaban. `SUND` viene del nor-nororiente para que caigan delante de los muros sur. Para comprobar sombras, compare una captura con otra igual donde `sun.castShadow=false` (la diferencia de las imágenes las muestra todas).
- **Lo que proyecta sombra se dibuja por su cara trasera.** El mapa de sombras guarda las caras que no miran al sol (la regla de three.js para evitar manchas). Un prisma sin base, como los de `GB`, queda hueco en el mapa, pero su sombra sobre el suelo sale bien porque la tapan los muros del lado de la sombra. Una malla nueva no proyecta sombra hasta que se le pone `castShadow` (en `boot`, junto a `B` y `S`).
- **Lotes y `occ`.** `cityGen()` marca sus lotes con 2 y sus pruebas solo ven el 1: lo que había antes. Lo que se genere después (árboles, el parque de la Alameda) ve ocupado todo lo que no es 0. Un hito nuevo marca con `occMark(q)` (valor 1) antes de la ciudad, como siempre.
- **Ventanas en caras que no son fachadas.** `winMat()` pinta ventanas en toda cara vertical a más de 1 m de altura. Graderías, escalinatas y muros van en `S`.
- **Todo pasa por el pixel art.** La escena se dibuja en un objetivo a baja resolución sin antialiasing: lo que mide menos de 0,5 m desaparece de cerca (ESTETICA §2), y lo que se dibuje en la pasada de normales (`scene.overrideMaterial`) no lleva los cambios de vértice de un material propio: si un material mueve vértices en su shader, los contornos no lo siguen. Los faroles (`Points`) se ocultan en esa pasada y su tamaño se divide por k. Los marcadores del DOM usan la cámara sin anclar: pueden quedar a menos de un píxel de arte de su lugar.
- **Rotar en `--js`.** El giro es animado: dos clics seguidos en `#rr` giran una sola vez, y una rueda del mouse cancela el giro en curso. Espere ~2 s entre clics (`--js` acepta una expresión async, que se espera). La cámara inicial mira desde el sureste: una fachada al poniente necesita dos o tres giros.
- **`E()` dentro de `buildModels` es el terreno sin explanadas.** `applyPads()` corre después y además aplana una celda de 40 m alrededor de cada explanada. Lo que va justo afuera de una (andenes, vías) toma `max(explanada, E)`.
- **Overpass puede no responder.** En octubre de 2026 los tres servidores daban error por carga. La API de OSM entrega un objeto entero sin límite de caja: `api/0.6/way/<id>/full.json` o `relation/<id>/full.json` (así se bajan los ríos). Para un área, cajas de la API `map` de menos de 0,25 grados² y 50 mil nodos.
- **Los ríos están sobre las manzanas, a 0,11.** Su agua y las franjas de ripio de las orillas comparten esa altura sin tocarse; el agua tiene su propia malla con `polygonOffset` (factor −1, units −2: sin el factor, las manzanas asoman en astillas donde el cauce sube hacia la orilla) y gana donde coinciden. Una capa plana nueva junto al río no puede ir a 0,11 encima de la franja (6 m fuera del agua): el suelo del Parque Río Claro se detiene 8 m antes. Una capa 7 mm bajo otra también parpadea: el búfer de profundidad cubre ±30 km.
- **Los ríos están nivelados.** Los nodos del relieve dentro del agua de un río valen el nivel del cauce, también para `E()` en `buildModels`; en las celdas de la orilla el agua sube hacia la ribera. Lo que flota en el río (muelles) se apoya con `drape()` o con `E(x, y)` en cada punto, no a una altura fija. Una explanada a menos de 40 m del agua toma nodos del cauce: `riversRelevel()` los repone después (Las Viejas Cochinas).
- **Etiquetas de los ríos por índice.** Cada etiqueta toma un segmento del eje de OSM: el Claro el 25 y el 42, el Lircay el 32, el Piduco el 83 (Parque Piduco) y el 42. Si cambia un eje, revíselas (`DATA.water[k]` decodificado, un segmento largo sobre el agua).
- **Dos ríos de OSM se tocan sin compartir nodos.** En las bocas del Piduco su agua y la del Claro se solapan o dejan una grieta de pocos metros. Las franjas de orilla que caen en el agua de otro río se dibujan con el agua (`riverBase`); si se agrega otro río que desemboque en uno de OSM, revise la boca de cerca.
- **Ríos en `config/trazados.json`.** `osm.via` va en orden aguas abajo; `osm.agua` acepta un número (multipolígono) o una lista con `'w<id>'` para vías cerradas; `osm.ramas`, vías de brazos laterales. La caché `raw/osm/rio-<río>.json` se vuelve a bajar sola si le falta un objeto.
- **Capas planas sin explanada.** `drape()` se puede llamar desde `buildModels` donde no hay `padAt`; copie los triángulos a `S` con normal `[0,1,0]` (`EN()` todavía vale cero). Alturas: manzanas 0,10, pasto bajo las calles 0,11, calles desde 0,12, capas sobre las calles desde 0,155. Una separación de 0,5 cm parpadea.
- **Techos a la misma altura en `S`.** Si varias cajas llegan a la misma altura, sus tapas coplanares y los muros interiores que terminan en el techo se ven como líneas cortadas. Use `lid=false`, termine los muros 3 cm abajo y ponga un solo `S.flat` sobre todo el contorno.
- **Las caras inferiores no se ven.** Aleros y voladizos miran hacia abajo; un color que solo vive ahí (la madera del Teatro Regional) va en un borde visible.
- **Calzadas del mapa y plantas de OSM.** Las calzadas del mapa (calles del grafo, con ancho por clase) son más anchas que las reales, y las plantas de OSM pueden quedar ~5 m corridas respecto de las manzanas del censo: una isla o un muro dibujado desde OSM puede pisar el asfalto. Ajústelo al hueco entre las calles del mapa (La Victoria, la Ex Cárcel).
- **El contorno de OSM puede incluir estacionamientos.** El del Mall Plaza Maule abarca un estacionamiento en superficie (por el subterráneo). Contraste con la imagen.
- **`buildCerro()` corre después del terreno.** Ahí `padAt` ya no sirve y `S` no está al alcance: el santuario se apoya en `E()`/`groundMin`, con muros de contención, en su propio `GB`.
- **El punto de un edificio junto a la Alameda.** `alamedaPlan()` centra la plaza de cada tramo de la Alameda en el `MODELS` cuya x cae en el tramo y cuya y está a menos de 20 m de su centro. El punto de un edificio vecino no debe caer ahí por accidente.
- **Explanadas vecinas.** Los nodos del relieve están cada 40 m y `applyPads()` fija todos los que quedan a menos de 40 m de la caja: dos explanadas a menos de ~80 m comparten nodos y gana la última registrada. Con alturas distintas, una queda inclinada o enterrada. Los hitos vecinos registran la misma altura (`PADS.push([x0,y0,x1,y1,h])`): la plaza, la Catedral y el lado norte usan `MODELS['plaza-de-armas'].pad`.
- **OSM no siempre trae los patios.** El contorno de la Casa de la Independencia (w214849869) no tiene sus patios interiores; salen de `satellite.py`.
- **El SRTM es de superficie.** Mide techos y árboles. `elevation.py` los quita con una apertura morfológica; si se cambia la fuente, revisa `python pipeline/elevation.py stats`.
- **La vía se dibuja después de las explanadas.** `railBase()` corre en `buildBase()`, con el terreno final, y todavía antes de la ciudad (puede marcar `occ`). Por eso los puentes ferroviarios no se dibujan en su bloque de `buildModels`: se registran en `RAIL_BR` con una función `draw(G, hAt)` que `railBase()` llama con la altura del perfil. Lo que se apoye en la vía (un andén, un tren) toma la altura de `RAILP` (`window.__rail`: `h` es la del riel), no `E()`: junto a los pasos bajo nivel la vía va hasta 3 m sobre el suelo.
- **Los pasos bajo nivel suben la vía, no bajan la calle.** El relieve es una malla de 40 m y no puede hundir una calle de 11 m: la vía sube `RAIL_HU` (3 m) con rampas de 1:16 (48 m) y cruza en un tablero. Dos pasos a menos de `RAIL_FILL` (160 m) quedan unidos por el terraplén (1 Sur, 1 Norte y 2 Norte). La rampa de 1 Sur empieza justo al norte de la cubierta de la estación: un paso nuevo cerca de un andén no cabe sin acortar las rampas.
- **Cada calle del mapa que cruza la vía está en `DATA.railx`.** `railway.py write` decide con OSM si pasa bajo la vía o a nivel. Si el mapa gana una calle que cruza la vía (otro grafo de cicloconecta), hay que volver a correrlo: sin entrada en `railx` la calle cruza a nivel, sin panel ni barreras, y el balasto queda sobre el asfalto.
- **La vía principal pasa bajo la cubierta de la estación.** El trazado a mano iba 26 m al oriente, por una vía de patio. La de OSM (`usage=main`) es la de la cubierta (u ≈ 18–20 del marco de la estación); el ramal sale de la cara poniente del andén descubierto.
- **Lo que mide menos de 0,4 m no se dibuja, tampoco en la vía.** El hilo de contacto de la catenaria, dibujado como un píxel de arte, se cortaba en trazos: hay postes y ménsulas, sin hilo. Los durmientes van cada 1,4 m (no cada 0,6 m) por lo mismo.

## Ideas pendientes

- Subir a `facade()` los ayudantes que hoy se repiten dentro de los bloques: techo a cuatro aguas (`hip`, en la Ex Cárcel y el Liceo), muros de un contorno cóncavo con tapa (`walls`/`extrude`, en el Mall, los campus y el Hospital), muros de un polígono hacia afuera (`edges`, Mercado y Juzgado de Familia), filas de ventanas por piso (`windows`, Corte y Garantía) y relieve real en fachada (`rib`, Hospital), palmera y bandera (`palmS`, `flagS`, Plaza de Armas) y contorno hacia adentro (`inset`, Plaza de Armas).
- `applyPads()` que mezcle las explanadas vecinas en vez de sobrescribirlas (trampa «Explanadas vecinas»).
- La antigua Intendencia (1 Norte con 1 Oriente, OSM w275506476, 1910–1916), en reconstrucción desde 2021: modelarla cuando se sepa cómo quedó.
- Polígonos reales de edificios desde OSM (`building=*`) para el centro, en vez de los generados.
- Agregar la 7ª Notaría (30 Oriente 1528), la clínica jurídica de la U. de Talca, el SML y el INDH Maule cuando haya direcciones confirmadas.
- Puentes modelados sobre el Piduco y el Lircay (hoy la calle o la Ruta 5 pasan sobre el agua como una cinta): el Puente Lircay N° 1 de la Ruta 5 y la Costanera del Piduco. Los ferroviarios están en el plan del tren.
- Un tren en movimiento: docs/PLAN-TREN.md §2.4–2.6 (la vía completa, el ramal, sus cruces y sus puentes ya están; falta el tren y el render con algo en movimiento).
- Los otros restaurantes de la ribera poniente (Los Olivares, OSM n1024052077) y el mirador del bosque; el parque de noche, si se confirma que está iluminado.
- Lo que falta para parecerse a Isopolis e Isometric NYC (docs/PROYECTOS-SIMILARES.md, puntos 4 a 6): veredas, autos, árboles de vereda y objetos de techo, textura del agua, un poco más de color.
- Exportar una postal PNG de la vista actual. Dentro de un artifact se necesita la capacidad de descargas.
