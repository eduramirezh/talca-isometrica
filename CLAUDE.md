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
python tools/screenshot.py shots/x.png --hash corte-apelaciones [--size 390x844] [--dark] [--js "..."]
python tools/screenshot.py shots/x.png --js "__look(-1640,533,10,Math.PI/4+Math.PI)"   # cámara en (x, y) de grilla, zoom, giro
python pipeline/satellite.py plaza-de-armas [500]   # manzanas sobre imagen satelital, en diagnostics/
python pipeline/geocode.py address "2 Norte 781"
python pipeline/diagnostics.py centro          # panel PNG en diagnostics/
uv run --with pillow python pipeline/landmark.py osm estadio [250]   # planta OSM + plano en diagnostics/
python pipeline/landmark.py frame estadio 815575960 [más vías]       # vías en el marco local del modelo
python pipeline/landmark.py photos estadio ["consulta"]              # fotos de Commons, más recientes primero
```

Después de cualquier cambio en la plantilla, verifícalo con `tools/screenshot.py`. Imprime las estadísticas de generación y los errores de consola. Una vista de escritorio y una de móvil suelen bastar. Si el Python del sistema no tiene Playwright (o Pillow para `satellite.py`), `uv run --with playwright python tools/screenshot.py …` funciona sin instalar nada; los navegadores ya están en la caché de Playwright.

## Arquitectura

**Pipeline (Python, solo biblioteca estándar).** Ejecuta los scripts desde `pipeline/`, porque se importan entre sí por nombre:

`raw/` + `config/trazados.json` (+ el Río Claro de la API de OSM, en `raw/osm/rio-claro.json`) → `process_geometry.py` → `data/geometry.json` (`water`: ejes; `area`: el agua del Claro con sus islas)
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
| grillas espaciales | `blockAt` (celdas de 100 m), `nearStreet` (40 m), raster de ocupación `occ` (2,5 m) para que los edificios no se superpongan |
| terrain | decodifica `DATA.elev`: `ER` (relieve real) y `EH` (exagerado con `relief()`, más explanadas). `E(x,y)` es la altura del suelo, interpolada dentro del mismo triángulo que dibuja la malla; `EN` la normal; `wildAt` la cobertura de matorral (pendiente real) |
| `GB` | constructor de geometría indexada (posición Float32, normal Int8, color Uint8). `face()` orienta cada cara según la normal; `prism()` para cajas (los muros que parten del suelo bajan 4 m), `gable()` para techos a dos aguas, `flat()` para polígonos. `B.dy` sube todo lo que se emite; `drape()` corta capas planas por las aristas del terreno y las apoya en él |
| palettes | colores de la escena |
| three setup | cámara ortográfica, luces, `winMat()`: Lambert con ventanas procedurales en el shader (`uNight`, `uWin`) |
| landmark models | `buildModels(B, S)`: modelos a mano de los hitos, cada uno en su bloque bajo una línea `// ==== hito: <id> ====` (no las borre: permiten rehacer hitos en paralelo sin conflictos). Reservan su huella en `occ` y registran una explanada (`padAt`) antes de generar la ciudad. `S` se dibuja sin ventanas procedurales (el Estadio, la Catedral). `localFrame(X,Y,A)` da el marco local de un hito (`G`, `V`, `N3`, `R`) y `facade(S,F,K)` el vocabulario de fachada (muros, paños, arcos, vitrales, techos; ESTETICA §7). `NOLOTS` excluye recintos enteros de la ciudad generada; `GLOW` agrega luces nocturnas a `lamps()` |
| procedural city | `styleFor()` clasifica cada manzana (core, core2, ind, apt, house); `cityGen()` recorre cada tramo de calle por ambos lados y coloca lotes |
| base layers | parcelas agrícolas, manzanas, ríos (con suavizado Chaikin), Ruta 5, calles, vía férrea; todo pasa por `drape()`. El Río Claro (`claroBase`) es el agua de OSM sobre las manzanas, en su propia malla (`claroWater`, `matWater` con `polygonOffset`), con franjas de ripio fuera de las orillas; `claroLevel`/`claroRelevel` lo nivelan, `claroOcc` lo deja ocupado. Una calle con `s.bridge` (la Ruta K-60-J sobre el río) no se dibuja: la dibuja el hito del puente |
| `buildCerro`, `wildTrees` | estatua del Cerro La Virgen sobre el terreno real; árboles en manchones en las laderas |
| trees | dos `InstancedMesh`: árboles redondos y álamos |
| `terrainMesh` | malla del terreno (colores por cobertura) y bordes del diorama que siguen su perfil |
| camera / input | `view {tx, ty, zoom, az}`, que apunta al plano `Y = 0`; `placeCam()`, `pan()`, `zoomAt()`, `flyTo()`; `ground()` busca el terreno bajo un punto de la pantalla y `lift()` da el punto del plano que centra un punto del terreno; `framed()` corrige el objetivo para que el lugar quede en el área libre entre el panel y la ficha |
| readout | `gridAddr()` convierte un punto en dirección aproximada usando `DATA.lines` |
| overlay | marcadores y etiquetas de calles en el DOM, proyectados en cada cuadro; `layout()` evita superposiciones por prioridad |
| selection / panel | ficha, recorridos, filtros, búsqueda y enlaces `#id` |
| boot | orden: `claroLevel()` y `claroOcc()` → hitos (registran explanadas) → `applyPads()` → `claroRelevel()` → terreno y capas base → ciudad (los árboles de `TREES`, plantados por los hitos, van con los demás); genera todo dentro de `setTimeout` (para mostrar la pantalla de carga) y deja `window.__stats` |

El render se hace solo cuando hace falta: `loop()` dibuja únicamente si `dirty` está activo.

## Modelar un hito

Los hitos se rehacen uno por uno sobre su planta real y con estética de pixel art. El Estadio Fiscal y la Catedral son los ejemplos de referencia. Para casos particulares, copie del hito que se parezca: en ladera y fuera de toda explanada, el Cerro La Virgen (`buildCerro`); un campus de decenas de edificios de OSM sin explanada y con pasto apoyado en el terreno, la U. de Talca y la UCM; vías que siguen el suelo junto a una explanada, la Estación; una isla entre calzadas, La Victoria; plantas cóncavas y relieve real en la fachada, el Hospital; techos a cuatro aguas, la Ex Cárcel y el Liceo Abate Molina; un parque con prados, senderos, juegos y muelles sobre el agua, el Parque Río Claro; un puente de tablero sobre pilas que reemplaza una calle del mapa, los puentes del Río Claro. El procedimiento completo está en docs/METODOLOGIA.md §9 y los criterios visuales (escala, lenguaje, paleta, lista de revisión) en docs/ESTETICA.md. En resumen:

1. `landmark.py osm <id>`: la planta y el plano. Compruebe si el punto del lugar cae en el hito (suele ser la dirección, en un borde), si la caja cubre todo el hito y si la huella choca con calles del mapa.
2. `landmark.py frame <id> <vía de referencia>`: origen y giro. Escriba el modelo en (u, v) con `G(u,v)`, como el estadio.
3. `landmark.py photos <id>` y prensa sobre remodelaciones. Las fotos fechadas mandan sobre el satélite para techos, alturas y colores.
4. El modelo:
   - pixel art: peldaños y arcos escalonados, dos tonos alternados, molduras blancas, líneas de 0,5 m, paleta local `K` partiendo de ESTETICA.md §4;
   - `S` para lo que no lleva ventanas;
   - `occMark` con la huella real, `padAt`, `NOLOTS` si hay recinto cercado y `GLOW` para luces;
   - un comentario con los ids de OSM, las fuentes y lo aproximado.
5. Capturas: ficha, de cerca, girada, noche, pixel y móvil (las líneas `--js` están en §9.5). Compárelas con las fotos. Una a la vez: varias en paralelo agotan el tiempo de Playwright.
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
- **Datos fuera del grafo.** El grafo de cicloconecta excluye autopistas (la Ruta 5 no está) y ferrocarriles. Por eso esos trazados están en `config/trazados.json`.
- **Navegadores sin GPU.** En Chromium sin GPU (las capturas) hay que usar SwiftShader; ver los argumentos en `tools/screenshot.py`.
- **Árboles.** `IcosahedronGeometry` ya viene sin índice en r128; `treeGeo()` lo detecta para no llamar a `toNonIndexed()`.
- **Relieve.** Todo lo nuevo que vaya en el suelo necesita la altura del terreno: capas planas en `buildBase()` (pasan por `drape()`), objetos con `B.dy = groundMin(huella)`, puntos sueltos con `E(x, y)`. `MODELS[id].h` es absoluta (se le suma el suelo al terminar `buildModels`). Para centrar la cámara en un lugar, usa `lift(x, y)`, no `(x, y)`. Si cambias la triangulación de `terrainMesh()`, cambia `sampleTri()` igual: `drape()` depende de que coincidan.
- **La imagen satelital puede ser vieja.** Las teselas de Esri que usa `satellite.py` sirven para plantas y manzanas, pero pueden tener años: en el Estadio Fiscal son anteriores a las cubiertas de 2017. Para alturas, techos y colores de un hito, contrasta con fotos recientes (Wikimedia Commons; la etiqueta `wikimedia_commons` de OSM lleva a la categoría).
- **Las alturas de OSM no sirven para hitos.** `height` y `building:levels` suelen ser valores por defecto: la torre de la Catedral dice 17 m y mide ~39. Mida en una foto frontal con un ancho conocido de la planta como escala.
- **Caras sin normal en `S`.** El material dibuja solo la cara de frente y `face()` ordena los vértices según la normal que recibe. Las caras verticales (muros, hastiales, detalles de fachada) necesitan su normal explícita (`N3(...)`); sin ella, `face()` solo garantiza que la cara mire hacia arriba.
- **El punto del lugar no es el centro del hito.** Las coordenadas de `pois.py` son direcciones. En recintos grandes caen en el borde: el Estadio quedó 100 m corrido y montado sobre 5 Norte por centrarlo ahí. Ubique el modelo con la planta de OSM y apunte `MODELS[id]` a su centro.
- **La caja de descarga de OSM.** Si no cubre todo el hito, faltan piezas sin aviso: la primera descarga del estadio dejó fuera dos de sus cuatro torres. Use `landmark.py osm <id> <media caja>` con margen.
- **Ventanas en caras que no son fachadas.** `winMat()` pinta ventanas en toda cara vertical a más de 1 m de altura. Graderías, escalinatas y muros van en `S`.
- **Rotar en `--js`.** El giro es animado: dos clics seguidos en `#rr` giran una sola vez, y una rueda del mouse cancela el giro en curso. Espere ~2 s entre clics (`--js` acepta una expresión async, que se espera). La cámara inicial mira desde el sureste: una fachada al poniente necesita dos o tres giros.
- **`E()` dentro de `buildModels` es el terreno sin explanadas.** `applyPads()` corre después y además aplana una celda de 40 m alrededor de cada explanada. Lo que va justo afuera de una (andenes, vías) toma `max(explanada, E)`.
- **Overpass puede no responder.** En octubre de 2026 los tres servidores daban error por carga. La API de OSM entrega un objeto entero sin límite de caja: `api/0.6/way/<id>/full.json` o `relation/<id>/full.json` (así se baja el Río Claro). Para un área, cajas de la API `map` de menos de 0,25 grados² y 50 mil nodos.
- **El Río Claro está sobre las manzanas, a 0,11.** Su agua y las franjas de ripio de las orillas comparten esa altura sin tocarse; el agua tiene su propia malla con `polygonOffset` y gana donde coinciden. Una capa plana nueva junto al río no puede ir a 0,11 encima de la franja (6 m fuera del agua): el suelo del Parque Río Claro se detiene 8 m antes. Una capa 7 mm bajo otra también parpadea: el búfer de profundidad cubre ±30 km.
- **El río está nivelado.** Los nodos del relieve dentro del agua del Claro valen el nivel del cauce, también para `E()` en `buildModels`; en las celdas de la orilla el agua sube hacia la ribera. Lo que flota en el río (muelles) se apoya con `drape()` o con `E(x, y)` en cada punto, no a una altura fija. Una explanada a menos de 40 m del agua toma nodos del cauce: `claroRelevel()` los repone después (Las Viejas Cochinas).
- **Etiquetas del Claro por índice.** Las etiquetas del río toman los segmentos 25 y 42 del eje de OSM (`'Río Claro','claro'`). Si cambia el eje, revíselas.
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

## Ideas pendientes

- Subir a `facade()` los ayudantes que hoy se repiten dentro de los bloques: techo a cuatro aguas (`hip`, en la Ex Cárcel y el Liceo), muros de un contorno cóncavo con tapa (`walls`/`extrude`, en el Mall, los campus y el Hospital), muros de un polígono hacia afuera (`edges`, Mercado y Juzgado de Familia), filas de ventanas por piso (`windows`, Corte y Garantía) y relieve real en fachada (`rib`, Hospital), palmera y bandera (`palmS`, `flagS`, Plaza de Armas) y contorno hacia adentro (`inset`, Plaza de Armas).
- `applyPads()` que mezcle las explanadas vecinas en vez de sobrescribirlas (trampa «Explanadas vecinas»).
- La antigua Intendencia (1 Norte con 1 Oriente, OSM w275506476, 1910–1916), en reconstrucción desde 2021: modelarla cuando se sepa cómo quedó.
- Polígonos reales de edificios desde OSM (`building=*`) para el centro, en vez de los generados.
- Agregar la 7ª Notaría (30 Oriente 1528), la clínica jurídica de la U. de Talca, el SML y el INDH Maule cuando haya direcciones confirmadas.
- El Lircay y el Piduco con el agua de OSM, como el Claro (objetos completos por la API; docs/METODOLOGIA.md §5). La desembocadura del Lircay en el Claro queda fuera de la maqueta.
- Los otros restaurantes de la ribera poniente (Los Olivares, OSM n1024052077) y el mirador del bosque; el parque de noche, si se confirma que está iluminado.
- Exportar una postal PNG de la vista actual. Dentro de un artifact se necesita la capacidad de descargas.
