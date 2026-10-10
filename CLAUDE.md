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
python pipeline/satellite.py plaza-de-armas [500]   # manzanas sobre imagen satelital, en diagnostics/
python pipeline/geocode.py address "2 Norte 781"
python pipeline/diagnostics.py centro          # panel PNG en diagnostics/
```

Después de cualquier cambio en la plantilla, verifícalo con `tools/screenshot.py`. Imprime las estadísticas de generación y los errores de consola. Una vista de escritorio y una de móvil suelen bastar. Si el Python del sistema no tiene Playwright (o Pillow para `satellite.py`), `uv run --with playwright python tools/screenshot.py …` funciona sin instalar nada; los navegadores ya están en la caché de Playwright.

## Arquitectura

**Pipeline (Python, solo biblioteca estándar).** Ejecuta los scripts desde `pipeline/`, porque se importan entre sí por nombre:

`raw/` + `config/trazados.json` → `process_geometry.py` → `data/geometry.json`
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
| landmark models | `buildModels()`: modelos a mano de los 19 hitos, que reservan su huella en `occ` y registran una explanada (`padAt`) antes de generar la ciudad |
| procedural city | `styleFor()` clasifica cada manzana (core, core2, ind, apt, house); `cityGen()` recorre cada tramo de calle por ambos lados y coloca lotes |
| base layers | parcelas agrícolas, manzanas, ríos (con suavizado Chaikin), Ruta 5, calles, vía férrea; todo pasa por `drape()` |
| `buildCerro`, `wildTrees` | estatua del Cerro La Virgen sobre el terreno real; árboles en manchones en las laderas |
| trees | dos `InstancedMesh`: árboles redondos y álamos |
| `terrainMesh` | malla del terreno (colores por cobertura) y bordes del diorama que siguen su perfil |
| camera / input | `view {tx, ty, zoom, az}`, que apunta al plano `Y = 0`; `placeCam()`, `pan()`, `zoomAt()`, `flyTo()`; `ground()` busca el terreno bajo un punto de la pantalla y `lift()` da el punto del plano que centra un punto del terreno; `framed()` corrige el objetivo para que el lugar quede en el área libre entre el panel y la ficha |
| readout | `gridAddr()` convierte un punto en dirección aproximada usando `DATA.lines` |
| overlay | marcadores y etiquetas de calles en el DOM, proyectados en cada cuadro; `layout()` evita superposiciones por prioridad |
| selection / panel | ficha, recorridos, filtros, búsqueda y enlaces `#id` |
| boot | orden: hitos (registran explanadas) → `applyPads()` → terreno y capas base → ciudad; genera todo dentro de `setTimeout` (para mostrar la pantalla de carga) y deja `window.__stats` |

El render se hace solo cuando hace falta: `loop()` dibuja únicamente si `dirty` está activo.

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

Para publicar: sube `dist/talca.html`, el fragmento, no `index.html`.

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
- **El SRTM es de superficie.** Mide techos y árboles. `elevation.py` los quita con una apertura morfológica; si se cambia la fuente, revisa `python pipeline/elevation.py stats`.

## Ideas pendientes

- Polígonos reales de edificios desde OSM (`building=*`) para el centro, en vez de los generados.
- Agregar la 7ª Notaría (30 Oriente 1528), la clínica jurídica de la U. de Talca, el SML y el INDH Maule cuando haya direcciones confirmadas.
- Ríos trazados con geometría OSM (`waterway=river`) si se puede ejecutar Overpass. La consulta está en docs/METODOLOGIA.md.
- Exportar una postal PNG de la vista actual. Dentro de un artifact se necesita la capacidad de descargas.
