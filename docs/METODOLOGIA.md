# Metodología

Cómo se construyó Talca Isométrica, en el orden en que se hizo: decisiones, alternativas descartadas y lo que quedó aproximado. Los scripts mencionados están en `pipeline/`.

## 1. Objetivo y enfoque

El encargo era un mapa isométrico de Talca basado en información cartográfica real, que destacara lugares icónicos y del ámbito jurídico, tomando ideas de proyectos populares como el mapa isométrico de San Francisco con lugares del mundo tech.

Los proyectos de referencia ([PROYECTOS-SIMILARES.md](PROYECTOS-SIMILARES.md)) generan imágenes con modelos de IA a partir de Google 3D Tiles. Esa vía se descartó por tres motivos:

- Requiere GPU y modelos ajustados.
- Produce errores conocidos (calles convertidas en ríos, áreas verdes tomadas por lagos).
- No permite saber dónde está realmente cada cosa.

Se optó por **dibujar geometría real en el navegador** con three.js y una cámara ortográfica en ángulo de simulador: 30° de elevación y 45° de azimut, la proyección 2:1 de los juegos de ciudades. Las calles y manzanas están donde corresponden; los edificios se generan siguiendo reglas.

## 2. Obtención de datos

El entorno de trabajo no tenía salida a OpenStreetMap: Overpass, Nominatim y los servidores de teselas estaban bloqueados. GitHub sí era accesible, y allí se encontraron dos fuentes que cubren lo necesario:

1. **Manzanas del Censo 2017 (INE)** en GeoJSON, repositorio [jiboncom/chile_geojson](https://github.com/jiboncom/chile_geojson). Se usaron los tres archivos de la Región del Maule:
   - `IND`: manzanas con datos de personas y viviendas.
   - `SIN_INF`: manzanas sin información, que en la práctica son parques, riberas, recintos y terrenos institucionales. La maqueta las pinta como parque. No todas lo son: en el centro hay manzanas comerciales e institucionales sin viviendas (frente a la Plaza de Armas, el Mercado Central, las Escuelas Concentradas). Esas se revisaron contra la imagen satelital y se listan en `config/manzanas.json`; `build.py` las marca como construidas (tipo 3). Para revisar otra, `python pipeline/satellite.py <id-de-lugar>` superpone las manzanas a la imagen satelital.
   - `ALDEA`: aldeas.

   La maqueta toma solo las manzanas de la comuna de Talca (el campo `COMUNA` del Censo, 7101): 2.811 polígonos con datos, 296 sin información y 21 de aldeas. Antes de octubre de 2026 entraban todas las de un rectángulo, también las de Maule al sur y al poniente (3.134 con datos y 322 sin información). Cada manzana trae `TOTAL_PERS` y `TOTAL_VIVI`, que se usan para la densidad. El sistema de referencia es EPSG:4674 (SIRGAS 2000), que a esta escala equivale a WGS84.
2. **Grafo vial de Talca extraído de OpenStreetMap**, del proyecto [Shiroku36/cicloconecta](https://github.com/Shiroku36/cicloconecta) (`data/cities/talca/nav_graph.json`). Tiene 31.529 nodos y 65.278 aristas con nombre de calle, tipo `highway` e id del way de OSM. Es un grafo pensado para bicicletas, así que **no incluye autopistas** (la Ruta 5) ni ferrocarriles, y cubre solo una caja alrededor de la ciudad (lon −71,695..−71,605, lat −35,465..−35,395, con las vías que la cruzan enteras). El resto de la comuna sale de la API `map` de OpenStreetMap (§4).

3. **Elevación SRTM de 1 segundo de arco** (~30 m), tesela `S36W072`, de los [Terrain Tiles de AWS](https://registry.opendata.aws/terrain-tiles/) (formato `.hgt`, sin autenticación). Una sola tesela cubre toda la maqueta.

`pipeline/fetch_sources.sh` descarga solo los archivos necesarios mediante sparse checkout.

## 3. Sistema de coordenadas y giro de la grilla

Talca tiene una de las grillas más regulares de Chile, con calles numeradas desde la Plaza de Armas. Para que la grilla calce con los ejes isométricos, primero se midió su orientación:

- Para cada tramo de calle numerada a menos de 1,5 km de la plaza se calculó el rumbo y se armó un histograma ponderado por largo.
- Las calles Norte/Sur dieron un pico en −5° / −6° y las Oriente/Poniente en −4° / −5°.
- Se adoptó un **giro de +5°**.

La proyección (`common.loc`) es equirectangular local con origen en el centro de la Plaza de Armas (−35,42653; −71,66600). Usa 90.719 m por grado de longitud y 110.950 m por grado de latitud. A escala de una ciudad el error es menor a 0,1 %.

## 4. Procesamiento de la geometría (`process_geometry.py`)

- **La comuna** (octubre de 2026). La maqueta es la comuna de Talca, 232 km², recortada por su límite: la relación 541797 de OpenStreetMap (`admin_level=8`, `dpachile:id` 07101), que `common.comuna()` baja una vez a `raw/osm/comuna-talca.json` y simplifica a 2 m (461 vértices). Hasta entonces era un rectángulo de 9,6 × 8,9 km (x ∈ [−4.000; 5.600], y ∈ [−4.200; 4.700]) que dejaba fuera el campo del oriente y del norte (Panguilemo, Huilquilemu, el Lircay aguas arriba) y una franja de los cerros del poniente, y metía barrios de Maule al sur. La caja de la comuna, `common.EXT`, es x ∈ [−4.920; 15.800], y ∈ [−10.840; 13.000] (20,7 × 23,8 km, alineada a la grilla del relieve), y lo que cae en ella fuera del límite no se dibuja:
  - **Manzanas**: las de la comuna según el Censo (`COMUNA` 7101), que calzan con el límite de OSM: solo una, sin información, tiene el centro fuera de él.
  - **Calles**: las del grafo y, donde el grafo no llega, las vías `highway=*` de la API `map` de OSM (`python pipeline/traces.py tiles-comuna`: cajas de 0,01° sobre la comuna, unidas a `map-todo` y `map-este` en `raw/osm/map-comuna.json`; `process_geometry.osm_streets`). Un tramo de OSM se descarta si sus extremos y su punto medio quedan a menos de 6 m de una calle del grafo, para no duplicarla. Todas se cortan en el límite (`common.clip_line`). Son 9.037 polilíneas, 2.255 de ellas de OSM.
  - **Relieve**: los nodos a más de cuatro celdas fuera del límite repiten el valor anterior (delta 0), y `data/elevation.json` pesa 720 KB por 519 × 597 nodos.
  - **En la plantilla**, `DATA.limit` marca cada celda del relieve como de adentro, de afuera o cruzada por el límite (`CM`, en `25-terrain.js`); en una cruzada, la parte de la comuna (`rectClip`, triangulada en `LIMT`) es la que `drape()` y `terrainMesh()` cortan, y `inTerrain(x, y)` dice si un punto está en la comuna: lo usan los árboles, los autos, los lotes, la Ruta 5, la vía y los usos. Los bordes del diorama siguen el límite.
  - **Los usos de suelo** (`config/usos.json`) con la mayoría de sus vértices fuera del límite no se inyectan (`build.py`). Cuatro entradas que apuntaban a manzanas de Maule por su índice (`bi`) quedaron con el polígono de esa manzana y una nota, y los índices de las otras 16 se rehicieron con la manzana idéntica de la geometría nueva.
- **Recorte de las manzanas.** Se recortan a la caja con Sutherland-Hodgman, y la plantilla las corta en el límite.
- **Simplificación.** Douglas-Peucker con 1,2 m de tolerancia para manzanas y 0,8 m para calles. Los anillos cerrados se simplifican en dos mitades, porque el algoritmo falla cuando el primer y el último punto coinciden.
- **Orientación.** Todos los anillos quedan en sentido antihorario y se descartan polígonos de menos de 30 m².
- **Calles.** Las aristas del grafo vienen dirigidas y duplicadas. Se eliminan duplicados y se encadenan en polilíneas por way de OSM. Cada calle recibe una clase de 0 a 7 (troncal, primaria, secundaria, terciaria, residencial, pasaje, peatonal, servicio), que define su ancho en el render: 16, 13, 11, 9,5, 7, 5, 3,5 y 3,5 m.
- **Codificación.** Coordenadas enteras en metros y en delta, unos 560 KB en total.

## 5. Ríos, vía férrea y Ruta 5 (`config/trazados.json`)

Como el grafo vial no traía estos elementos, primero se dibujaron a mano. `diagnostics.py` genera paneles con las manzanas, las calles y una grilla fina de coordenadas (0,001°). En esos paneles un río aparece como un hueco continuo entre manzanas. Desde octubre de 2026 los tres ríos, la Ruta 5 y el tramo norte de la vía férrea salen de OpenStreetMap (abajo); los trazados a mano quedaban decenas o cientos de metros fuera:

- **Río Claro.** El trazado a mano quedaba 115–180 m al poniente del río frente al Parque Río Claro y hasta ~750 m fuera en el norte, donde cortaba potreros.
- **Estero Piduco.** Se había seguido una franja sin manzanas que cruza la ciudad en diagonal, desde el sureste hasta la Alameda poniente (Wikipedia: «cruza por enmedio de Talca en dirección nor-poniente»). Quedaba hasta 140 m fuera en la ciudad y 320 m al oriente. La confluencia está, como se había visto, cerca del extremo poniente de la Alameda, no en el punto de GeoNames (−35,4325; −71,6935).
- **Río Lircay.** Seguía el borde norte de las manzanas, por la llanura de inundación, y quedaba hasta 125 m fuera.
- **Vía férrea.** El tramo central se había anclado a mano en la estación, los pasos bajo nivel de 1 Norte, 1 Sur y 8 Sur y el puente sobre el Piduco (puntos OSM vistos en Mapcarta), pero en la estación iba hasta 26 m al oriente, por una vía de patio; el tramo norte doblaba al noreste demasiado pronto (hasta ~600 m fuera, cruzaba el Lircay 170 m al poniente de su puente) y el sur quedaba hasta ~500 m fuera. Hoy toda la línea y el ramal a Constitución son de OSM (abajo).
- **Ruta 5.** El corredor a mano (la autopista no está en el grafo ciclista) quedaba 26–157 m fuera y cruzaba el Piduco 60 m y el Lircay 30 m lejos de sus puentes. Ahora es el eje medio de las dos calzadas de OSM, con 26 m de ancho, el de las dos calzadas reales (con 30 tapaba la caletera de 20 Oriente).

**Los ríos desde OpenStreetMap.** En octubre de 2026 la API de OSM respondía, pero Overpass no (los servidores probados daban error por carga, también el 11 de octubre). En vez de una consulta por área se bajan objetos completos, que no tienen límite de caja: las vías del eje (`way/<id>/full`, `waterway=river`) y el agua (`relation/<id>/full`, `natural=water`, con las islas como anillos interiores, o una vía cerrada). Cuando un río de `config/trazados.json` trae la clave `osm`, `process_geometry.py` los guarda en `raw/osm/rio-<río>.json` y:

- encadena las vías de `via` (en orden aguas abajo) en un solo eje, y cada vía de `ramas` en una línea aparte (`branch`);
- junta los contornos de `agua` que comparten un borde (OSM corta las áreas largas en piezas: con todos los anillos antihorarios, las aristas compartidas van en ambos sentidos y se anulan), asigna cada isla a su contorno y recorta todo a la maqueta (`area`: lista de polígonos).

Donde no hay área, la plantilla dibuja una cinta de `ancho_m` sobre el eje (`riverRuns`). Los tres ríos, y desde octubre de 2026 un estero y un canal del campo (abajo):

| Río | Eje | Agua | Sin área |
|---|---|---|---|
| Claro | vías 203907281 (aguas arriba de la confluencia con el Lircay) y 203907278 | multipolígonos 15397714 y, al sur de y ≈ −630, 15397715; aguas arriba de la confluencia, vías cerradas 972937378 y 972937405 (50 islas en la comuna) | ninguno en la comuna |
| Piduco | vías 818896454, 115278012, 115278408 (relación 12030965); rama: Piduco Norte, vía 115765863 | multipolígono 15792513, de la desembocadura a 6 Oriente (1 isla) | aguas arriba de 6 Oriente (cinta de 12 m) y los últimos ~50 m de cada boca |
| Lircay | vías 52047309 y 101557414 (relación 8894881) | multipolígono 2636992 y vía 972937377, unidos, y aguas arriba el multipolígono 15068144 (20 islas en la comuna) | al oriente de x ≈ 13.700, donde es el límite de la comuna |
| Pangue y Panguilemo (`panguilemo`) | vías 101547239 (Estero Pangue) y 631639959 (Estero Panguilemo, desde la junta con Las Chilcas) | vía cerrada 1135758132, en la junta | todo lo demás (cinta de 10 m) |
| Canal de Regadío Pencahue (`pencahue`) | vías 101557431, 101557449 y 201352313; túneles 101557434 (bajo la Ruta 5) y 521046942 (sifón bajo el Lircay y el Claro), que no se dibujan | ninguna | todo (cinta de 6 m) |

Antes de reemplazar cada trazado se comparó OSM con el mapa (`python pipeline/traces.py check <río>`) y sobre la imagen satelital (`traces.py panel <río> x0 x1 y0 y1`: el eje, el agua, las manzanas, las calles con su ancho de render, los puentes de OSM, la vía y la Ruta 5), con esta regla: toda calle del mapa que cruce el eje debe ser un puente en OSM, y si OSM y el mapa difieren en más de ~15 m, se mira la imagen antes de decidir. Lo que salió y lo que se decidió:

- **El eje y el agua de OSM calzan con la imagen** en los tres ríos.
- **Calles.** Sobre el Claro, solo la Ruta K-60-J, a ~5 m de su puente. Sobre el Piduco, 11 calles (Circunvalación, 2 Sur, Barcelona, 1 Oriente, 6 Oriente, Salvador Allende, 14 Oriente, 30 Oriente, Ruta K-353), todas puentes en OSM a 0–1 m. Ninguna sobre el Lircay. Ninguna calle corre dentro del agua nueva.
- **Vía férrea y Ruta 5.** No cruzaban los ríos donde están sus puentes (diferencias de 30 a 170 m, más arriba). Se decidió traerlas de OSM en vez de correr solo los cruces. Ahora cruzan sobre sus puentes: la vía sobre el Piduco y el Lircay, la Ruta 5 a 3 m de los suyos.
- **Manzanas en el agua.** Cinco manzanas del Claro entran más de 15 m (hasta 85 m) y tres del Lircay (la 2469, con 103 personas, hasta 77 m; la 3387, 44 m; la 3386, 26 m). En esa parte solo hay lecho de ripio, brazos laterales y bosque de ribera: las casas de la 2469 están a más de 200 m. En el Piduco ninguna entra más de 12 m. Por eso el agua de los tres ríos se dibuja sobre las manzanas (y bajo las calles, que la cruzan como puentes).
- **Explanadas.** Ninguna queda a menos de 120 m del agua nueva del Piduco ni del Lircay (el Parque Piduco tiene lugar pero no modelo).
- **Ribera.** La franja de ripio del Lircay baja de 40 m a 6, como en el Claro: el agua de OSM ya es todo el lecho. El Piduco conserva 5 m.
- **El Piduco Norte.** El multipolígono del Piduco incluye el brazo norte pero se detiene ~50 m antes del Claro. Se agregó la vía del brazo como rama, para que el agua llegue al Claro.

La vía férrea y la Ruta 5 de OSM no se bajan en el pipeline: solo están en relaciones de ruta de más de mil miembros. Se tomaron una vez de la API `map` (cajas de 0,01°, `traces.py tiles`) encadenando (`traces.py line`) las vías `highway=motorway` «Ruta 5 Sur» (las dos calzadas, a 9–15 m entre sí; el eje es su promedio, simplificado a 2 m) y `railway=rail` «Línea Central Sur» con `usage=main` (simplificada a 1,5 m), y quedaron como `puntos` en `config/trazados.json`, con las vías de origen en `fuente`. Se repiten con:

```
python pipeline/traces.py tiles-comuna                                                     # toda la comuna -> map-comuna
python pipeline/traces.py line comuna highway=^motorway$ "name=^Ruta 5 Sur$" --mid          # Ruta 5
python pipeline/railway.py write comuna                                                     # la vía y el ramal
```

**La vía férrea completa** (octubre de 2026, docs/PLAN-TREN.md §2.1–2.3). `pipeline/railway.py` encadena, de la misma caché `map-este`, la Línea Central (`usage=main`, 32 puntos, 10,5 km) y el ramal a Constitución (`usage=branch`, 9 puntos, 4,2 km, desde el tope de su vía junto a la estación), los dos simplificados a 1,5 m, y escribe en `config/trazados.json` → `ferrocarril` (con el ramal dentro) también (desde octubre de 2026, de `map-comuna` y recortados a la comuna con 300 m de margen: la Línea Central tiene 43 puntos y 14,4 km, hasta el Estero Pangue en el norte, con cuatro cruces a nivel más en el campo, y el ramal 3 km):

- **`pasos`**: cada calle del mapa que cruza una línea, con lo que dice OSM del cruce. «bajo» si la vía tiene `bridge=yes` (1 Norte, 2 Norte, la Alameda y un camino al norte del Lircay) o la calle `tunnel=yes` / `layer=-1` (1 Sur, 6 Sur y 8 Sur, estos dos también bajo el ramal); «nivel» si hay un nodo `railway=level_crossing` a menos de 15 m, con `barreras` y `luces` de sus etiquetas (14 Sur, en las dos líneas). Las 13 calles del mapa que cruzan la vía calzan con un cruce de OSM a menos de 1 m. Fuera del mapa quedan la Ruta 5, que pasa sobre la vía en su propio puente, y un camino a nivel al norte del Lircay.
- **`postes`**: los postes de la catenaria (`power=catenary_mast`) a menos de 8 m del eje de la Línea Central (181), que es la electrificada (`electrified=contact_line`; las fotos de 1 Sur de 2014 muestran los postes y el hilo); **`senales`**: las señales luminosas junto a las dos líneas (16).

**Esteros y canales** (octubre de 2026). De los cuatro cursos de agua del campo pendientes se dibujan dos, con el mismo camino que los ríos (`osm_river`, `riverBase`) y no con uno propio: un estero o un canal es un río sin área, una cinta sobre el eje, y así hereda el recorte en el límite, la nivelación del cauce, `occ`, las franjas de ripio, los árboles de ribera y las etiquetas. `osm_river` acepta un río sin `agua` y una lista `tunel` de vías del eje que van bajo tierra: el eje se corta ahí y sus tramos abiertos quedan como eje y ramas. Una clave `canal` (en `widths`, el tercer valor) le quita al canal la franja verde ancha de ribera y deja solo un árbol cada tanto junto a su camino de servicio.
- **El Estero Pangue y el Estero Panguilemo** son el límite norte de la comuna: la maqueta dibuja la mitad sur de su cauce, ~2 km de cada uno, con el agua de OSM en la junta. Sobre él pasan los puentes de la Ruta 5 (`puente-panguilemo-ruta5`) y de la Línea Central (`puente-panguilemo-ferrocarril`, w101547234, cortado en su pila central). Ninguna calle del mapa lo cruza.
- **El Estero Las Chilcas** (w101547258) y el brazo norte del Panguilemo (w101547222) están fuera de la comuna: no se dibujan.
- **El Canal de Regadío Pencahue** cruza la comuna de oriente a poniente, 21 km: del oriente (10.177, 2.408) al norte de la ciudad, bajo la Ruta 5 en túnel, por Panguilemo, bajo el Lircay y el Claro en un sifón de 1,4 km, y por los cerros del poniente hasta salir de la comuna. En la imagen es un canal revestido de 6–8 m con un camino de servicio. `traces.py check pencahue --map comuna` (con `--map`, las vías de OSM salen de `map-comuna` y no de cajas nuevas de la API): las 11 calles del mapa que lo cruzan son puentes de OSM a 0–1 m. Dos manzanas lo tocan 3 m (una sin información en los cerros y una con datos en Panguilemo).

Lo revisado antes de reemplazar: el nuevo eje coincide con el anterior (0 m) desde 2 Norte al norte; cruza el Piduco a 1 m (Línea Central) y 0 m (ramal) de sus puentes de OSM y el Lircay a 1 m del suyo (`traces.py check piduco`, `check lircay`); y en los paneles sobre la imagen (`traces.py panel piduco 1000 1750 -4250 -2900 16` y `… 1420 1640 -700 250 17`) sigue la faja de la vía en el sur y el patio de la estación. Los puentes de OSM sobre esteros y canales que la maqueta no tiene (Caiván, Los Molinos, El Parrón, Canal Sandoval) no se dibujan. Cómo se dibuja todo eso está en §8 («Vía férrea»).
 Sin lotes ni árboles sobre ellas (`linesOcc`): 15 m a cada lado del eje de la Ruta 5, 5 m de la vía y 4 m del ramal (este, en `railBase`, que además deja libres los terraplenes).

**La Ruta 5 como autopista (octubre de 2026).** El eje medio sigue en `config/trazados.json`, pero la plantilla ya no dibuja una cinta de 26 m sobre él: dibuja las dos calzadas, cada una sobre su línea de OSM y en su sentido, como se modela un hito (§9), con los datos en `data/ruta5.json` (`make ruta5`, de `python pipeline/traces.py calzadas`; `build.py` lo inyecta como `DATA.r5`, el `R5` de la plantilla: las 74 vías `highway=motorway` encadenadas en dos cadenas, simplificadas a 0,3 m, con `lanes`, `lit` y `bridge` por tramo, y los 40 ramales `motorway_link`, que el grafo de cicloconecta no trae; sus `trunk_link` sí son calles del mapa). Antes de modelar se listaron todos los cruces con `traces.py cruces` y se miraron sobre la imagen de Esri con `traces.py vial`:

| Cruce | Dónde | Tipo en OSM |
|---|---|---|
| Estero Panguilemo, en el límite norte de la comuna | (7377, 8848) | la autopista en dos puentes de 124 m, con una huella debajo; el límite de la comuna va por el estero, así que solo entran sus ~55 m del sur, que terminan cortados en el borde (`puente-panguilemo-ruta5`) |
| Pasarela Aldea Campesina | (6693, 7620) | pasarela con rampas |
| Cruce Talca–Pelarco | (6307, 7028) | paso superior y ramales en trébol parcial |
| pasarela | (5046, 5128) | pasarela con rampas |
| Río Lircay | (4128, 3717) | la autopista en dos puentes de 164 m |
| camino sin nombre, junto al Caserío Lircay | (3958, 3485) | bajo la autopista, que va en dos puentes de 81 m |
| Enlace Avenida Lircay | (3811, 3294) | paso superior, un lazo y cuatro ramales |
| vía férrea (electrificada) | (3379, 2703) | bajo la autopista, en dos puentes de ~60 m |
| Enlace Las Industrias | (3249, 2144) | paso superior y tres ramales |
| Pasarela Nueva Holanda | (2960, 890) | pasarela con rampas |
| calle sin nombre | (2820, 276) | bajo la autopista, que va a nivel |
| Enlace 2 Norte | (2747, −40) | paso superior en dos puentes |
| Enlace San Miguel | (2670, −375) | paso superior en dos puentes y una ciclovía |
| pasarela | (2575, −788) | pasarela con rampas y escaleras |
| Enlace 8 Sur | (2507, −1080) | paso superior en dos puentes |
| Estero Piduco | (2328, −1854) | la autopista en dos puentes de ~65 m |
| Enlace El Tabaco | (2144, −2642) | paso superior y ramales en trébol |

Más los cursos de agua en alcantarilla, que no se dibujan: los canales Sandoval, Baeza, Parrón y de Regadío Pencahue, un canal en el enlace de Pelarco, un estero, una acequia y un cauce sin nombre. Nada cruza a nivel; tres caminos de servicio de OSM terminan en la calzada (accesos directos). La primera versión (con la caja de la maqueta rectangular) tenía 74 vías y 40 ramales; desde que la maqueta es la comuna (octubre de 2026), `traces.py calzadas comuna` toma las vías a menos de 300 m del límite: dos cadenas de 15 km, del Estero Panguilemo al sur del Piduco, y 57 ramales. En OSM cada calzada tiene dos pistas (tres en los tramos de entrada y salida, `placement=right_of:1`), está iluminada desde el Lircay al sur y sus líneas quedan a 9–15 m entre sí. La imagen de Esri y una foto de 2011 muestran que en la ciudad la autopista va en trinchera bajo los pasos superiores, con las caleteras a nivel junto a los estribos. El relieve, con nodos cada 40 m, no puede hundir 40 m de ancho sin hundir las manzanas vecinas, así que se invirtió: los pasos superiores suben 2–4 m sobre la calle en rampas entre muros, con una abertura oscura donde la autopista pasaría por debajo, y la autopista sube en terraplén donde de verdad va en puente (8,6 m sobre la vía férrea, por la catenaria; 6 m sobre el camino de 3958, 3485; 8 m sobre el Lircay). Las pasarelas van a su altura real (5,6 m), con sus rampas y escaleras de OSM.

El relieve tampoco sigue a los ríos en todas partes: el SRTM suavizado pone el fondo del valle a decenas de metros del cauce real, y el agua apoyada en el terreno quedaba inclinada (10 m a lo largo de un muelle de 45 m en el Claro). La plantilla nivela, en una sola pasada para los tres ríos, los nodos del relieve que caen dentro del agua al promedio del cauce en 80 m a la redonda (`riversLevel`) y repone esos niveles después de las explanadas (`riversRelevel`). El Piduco, de 12 m, casi no tiene nodos dentro: su agua sigue el terreno. Donde el cauce nivelado sube hacia la orilla, el agua (1 cm sobre las manzanas) necesita un desplazamiento de profundidad proporcional a la pendiente (`polygonOffsetFactor` −1), o las manzanas asoman en astillas. En las bocas del Piduco, su agua de OSM y la del Claro dejan una grieta de pocos metros: las franjas de orilla que caerían en el agua de otro río se dibujan con el agua.

Si Overpass responde, esta consulta trae todos los trazados de una vez:

```
[out:json];
(way[waterway=river](-35.47,-71.72,-35.37,-71.58);
 way[waterway=stream][name~"Piduco"](-35.47,-71.72,-35.37,-71.58);
 way[railway=rail](-35.47,-71.72,-35.37,-71.58);
 way[highway=motorway](-35.47,-71.72,-35.37,-71.58););
out geom;
```

## 6. Relieve (`elevation.py`)

Hasta la versión 1.1 la maqueta era plana, con un cerro inventado. El modelo de elevación mostró que el relieve de Talca tiene dos escalas muy distintas:

- **Los cerros del poniente.** Al otro lado del Río Claro, la cordillera de la Costa sube hasta ~370 m. El Cerro La Virgen está en su borde oriental, y el santuario queda a ~270 m.
- **El plano de la ciudad.** Baja suavemente de ~130 m en la UCM, al oriente, a ~105 m en la plaza y ~80 m en el Río Claro. Lo que se nota son los escarpes de las terrazas hacia el Claro, el Lircay y el Piduco, de 10 a 25 m.

El procesamiento:

1. **De superficie a terreno.** El SRTM mide techos y copas de árboles. Se muestrea a 20 m en metros de grilla y se aplica una apertura morfológica (mínimo y luego máximo en una ventana de 100 m), que borra los objetos más angostos que eso sin tocar los valles. Después se suaviza con un filtro gaussiano de 30 m. En Talca el filtro quita poco (≈ 1 m de desviación, 9 m como máximo en el centro), así que el SRTM es limpio aquí.
2. **Salida.** Una grilla de 241 × 224 nodos cada 40 m, en decímetros relativos a la plaza (103,7 m), codificada en delta (`data/elevation.json`, ~144 KB). Para revisarla, un sombreado con los ríos encima: el Claro y el Lircay calzan con sus valles.
3. **Exageración en el navegador.** Con una exageración lineal, o los cerros tapan la ciudad o el plano sigue viéndose plano. Se usa una curva logarítmica: `h' = 3 · 50 · ln(1 + |h| / 50)`, con signo. Cerca de la plaza la pendiente se multiplica por 3, y a +170 m (el santuario) la altura queda en ×1,3. Las constantes son `RELIEF_A` y `RELIEF_K` en la plantilla.
4. **Todo sobre el terreno.**
   - Las capas planas (parcelas, manzanas, calles, ríos, vía férrea) se cortan por las aristas de la malla de terreno (`drape()`). Así cada pedazo queda dentro de un solo triángulo del terreno y es coplanar con él, y los desfases de pocos centímetros entre capas siguen funcionando en pendiente.
   - Los edificios se apoyan en la esquina más baja de su huella. Los muros bajan 4 m más, así que en pendiente nunca quedan flotando.
   - Bajo cada hito se nivela una explanada a la altura media de su huella.
   - Donde la pendiente real supera ~6 % no hay parcelas agrícolas: el terreno se pinta de matorral y se siembran árboles en manchones.
   - Los bordes del diorama siguen el perfil del terreno.
5. **Lectura.** El lector de direcciones busca el punto del terreno bajo el cursor y muestra la altura real sobre el nivel del mar, sin exagerar.

## 7. Lugares (`pois.py`, `geocode.py`)

**Investigación.** Se buscaron por separado las instituciones jurídicas y los hitos de la ciudad. Como Overpass y Nominatim estaban bloqueados, las coordenadas se tomaron de:

- **Mapcarta**, que publica cada elemento de OSM con sus coordenadas (punto, o centroide del edificio).
- **Las fichas del Consejo de Monumentos Nacionales**, cuyas coordenadas UTM se convirtieron a lat/lon.

Las direcciones salieron de los sitios institucionales.

**Numeración de Talca.** Es el sistema de Daniel Barros Grez, aprobado en 1869, y se confirmó con varias direcciones conocidas:

| Calles | Sentido | Cuadra de la plaza | Fórmula |
|---|---|---|---|
| Norte / Sur | crecen hacia el oriente | 700 (entre 1 Poniente y 1 Oriente) | k Poniente = 800 − 100k · k Oriente = 700 + 100k |
| Oriente / Poniente | crecen hacia el norte | 1100 (entre 1 Sur y 1 Norte) | k Sur = 1200 − 100k · k Norte = 1100 + 100k |

En 1 Norte los impares están al lado norte. La Alameda es la 4 Norte.

**Geocodificador.** `geocode.py` calcula la posición de cada calle numerada como la mediana de sus nodos OSM a menos de 900 m de la plaza. Con eso interpola la dirección dentro de la cuadra y la desplaza hacia el lado que corresponde. Sirve para dos cosas:

1. **Validar** cada lugar que ya tiene coordenadas contra su dirección (`make validate`). La mayoría queda a menos de 50 m. Las diferencias mayores tienen explicación:
   - La ex Cárcel está ubicada a propósito en el centro de su manzana.
   - El Hospital está fuera de la grilla regular y su punto es el centroide de un edificio grande.
   - La Alameda mide unos 70 m de ancho.
2. **Ubicar** lugares que solo tenían dirección: la Fiscalía Regional, la Corporación de Asistencia Judicial, la 1ª a 4ª Notaría, el Registro Civil, la U. Autónoma y el Colegio de Abogados. Sus fichas lo indican.

**Confianza.** Cada lugar declara `alta`, `media` o `baja` (criterios en CLAUDE.md). Algunos quedaron fuera:

- La Delegación Presidencial, porque dos fuentes daban direcciones distintas.
- El Servicio Médico Legal, porque no se encontró el número de su sede nueva.
- El INDH Maule, porque no se encontró su dirección.
- El CECOCH de la U. de Talca está en Santiago y se menciona solo como dato.

**Recorridos.**

- **Ruta de la Justicia:** 13 paradas, de la jura de la Independencia (1818) al barrio cívico de la Alameda, y termina en la Facultad de Derecho de la U. de Talca.
- **Talca icónica:** 13 paradas.

## 8. Render (`src/`)

La aplicación es un solo fragmento HTML con un solo script, pero se escribe en fuentes separados que `pipeline/build.py` une sin cambiarlos, salvo una línea `// ---- src/js/<archivo> ----` antes de cada archivo del script: `src/page.html` (el DOM), `src/style.css`, el script por secciones en `src/js/NN-<sección>.js` (unidas en el orden de su número) y los hitos en `src/js/hitos/<id>.js`, dentro de `buildModels`, en el orden de `src/js/hitos/ORDER`. Hasta octubre de 2026 era un solo archivo, `src/template.html`, de 4.500 líneas; al partirlo, el resultado de `make build` quedó idéntico byte a byte. Un error en el navegador da una línea de `dist/`: `python pipeline/build.py --where index.html:N` dice de qué archivo y línea de `src/` viene, y `make check` traduce así los errores de `node --check`.

- **Base.**
  - Una malla de terreno (sección 6) con bordes de tierra que siguen su perfil.
  - Parcelas agrícolas generadas donde no hay manzanas, con algunas hileras de álamos.
  - La Ruta 5 como autopista (sección 5): dos calzadas con sus pistas, líneas, bandejón, barrera, ramales, postes de iluminación y autos; sus puentes, terraplenes, pasos superiores y pasarelas son hitos.
  - Usos de suelo (sección 13) en los terrenos que el Censo deja en blanco: industria, cementerios, el regimiento, colegios, canchas, parques, huertos, viñas, eriazos.
  - Manzanas como polígonos planos, calles como cintas encima, ríos con ribera de ripio y una franja verde de parque ribereño. El Río Claro es el agua de OSM con sus islas, sobre las manzanas, con una franja de ripio en cada orilla, nivelada a lo ancho del cauce.
- **Edificios procedurales** (`cityGen`). Se generan **a lo largo de cada tramo de calle**, por ambos lados, y no siguiendo el borde de la manzana. Las manzanas del censo pueden contener pasajes interiores, y así los edificios dan siempre a una calle real. Para cada lote:
  1. Se identifica la manzana que hay detrás de la calle.
  2. Según la manzana se elige un estilo:
     - **core** (centro, fachada continua): de 1 a 4 pisos, con torres ocasionales cerca del centro; techos de teja vieja, óxido y zinc gastado; vitrinas y letreros en la planta baja de las calles principales.
     - **house**: lo decide el barrio (abajo).
     - **apt**: bloques de vivienda social de 3 o 4 pisos con cajas de escalera, perpendiculares o paralelos a la calle, entre prados y estacionamientos, donde la densidad supera 115 viviendas por hectárea.
     - **ind**: galpones (de dos aguas, diente de sierra, bóveda o techo plano) en patios pavimentados, con muro al frente y algunos estanques. Fuera del centro ninguna manzana con datos del censo queda sin personas ni viviendas, así que los galpones salen de las manzanas de 2 ha o más con menos de 8 viviendas por hectárea: ahí, cerca de la mitad de los lotes.

     **Barrios.** Talca creció por piezas, cada una construida de una vez y pareja por dentro, pero el censo solo da personas y viviendas por manzana. Las manzanas construidas se agrupan en barrios con un Voronoi de semillas sorteadas en una grilla de 280 m (una manzana entera va a la semilla más cercana, así que un barrio termina en una calle), y cada barrio sortea una receta según su distancia a la plaza y su densidad: el **barrio antiguo** rodea el centro hasta ~1,4 km (casas de un piso en la línea de la calle, teja vieja y óxido); la **población** (casas distintas de 7 a 11 m de frente, zinc de todos los colores, mediagua al fondo) domina entre 1,4 y 2,6 km; **villas de pareadas** (dos casas en espejo bajo un techo, cada mitad pintada por su dueño), **villas de casas en fila** de dos pisos y **condominios** de casas con techo a cuatro aguas son más frecuentes en las afueras, y las villas, donde la densidad pasa de 75 viviendas por hectárea. Una manzana de cada siete toma la segunda receta del barrio. La receta fija el tipo de casa, el ancho y la regularidad de los lotes (en una villa todos iguales), los pisos, la familia del techo, los colores de muros y patios, los árboles, las mediaguas y los almacenes de esquina. Los colores de los techos salen de la imagen satelital de cinco barrios (`pipeline/satellite.py`): zinc galvanizado claro y gastado en casi todos los barrios, con planchas oxidadas, rojas, verdes y azules; teja oscura y óxido en el centro; un solo color por villa o condominio.

     **Almacenes y avenidas.** En las esquinas, una parte de los lotes es un almacén: techo plano con fachada falsa que lleva el letrero, cortina metálica y vitrina. En las calles de clase 1 a 3 a menos de 1,5 km de la plaza, más de la mitad del frente son locales continuos, algunos de 2 o 3 pisos.
  3. Se descarta el lote si invade otra calle, si sale de la manzana o si choca con algo ya construido. Lo que había antes de la ciudad (hitos, ríos, Ruta 5, vía férrea) está en un raster de ocupación de 2,5 m; los lotes se prueban entre sí como rectángulos exactos (`LOTS`).
  4. La casa queda sobre su lote: una losa del color del patio que va del antejardín al medio de la manzana, donde se junta con el lote de la calle opuesta. En el centro, la casa de un piso tiene un ala a un costado del patio (a veces en U), y los lotes comerciales una construcción al fondo; en los barrios, el patio suele tener una mediagua al fondo y a veces un árbol. Así la manzana se ve construida hasta los deslindes, como las reales, y no como casas sueltas sobre suelo pelado ([PROYECTOS-SIMILARES.md](PROYECTOS-SIMILARES.md), punto 1).

  Todo usa números aleatorios con semilla, así que la ciudad sale idéntica en cada carga. El resultado: ~61.000 lotes en ~550 barrios, ~2,15 millones de vértices en un solo buffer con ventanas y ~0,19 millones en la malla sin ventanas (`Z`: galpones, letreros, antepechos), más ~1,1 millones en la malla de los lotes.
- **Hitos.** Hay 19 modelos hechos a mano. El Estadio Fiscal y la Catedral siguen su planta real y la estética de pixel art (sección 9 y [ESTETICA.md](ESTETICA.md)); los demás todavía son simplificados: entre ellos la Corte con su pórtico, los tribunales penales, la Fiscalía, el Juzgado de Familia, la ex Cárcel con muros y torres de guardia, el Mercado, la Casa de la Independencia, el Estadio, la Estación, el Teatro, La Victoria, el Hospital y la estatua del Cerro La Virgen. Reservan su huella y nivelan el terreno antes de que se genere la ciudad.
- **Luz y sombras.** Un cielo tenue (0,5) y un sol más fuerte (0,82) desde el nor-nororiente a 45°, para que techo, muro al sol y muro a la sombra tengan tres tonos claros. El sol proyecta sombras: un mapa de 4096² (2048² en móvil) que `fitShadow()` ajusta a lo que muestra la vista y mueve en texeles enteros. Proyectan sombra los edificios, los hitos y los árboles; de noche no hay sombras. Desde la vista inicial las sombras caen delante de los muros sur, donde se ven.
- **Pixel art.** La escena siempre se dibuja como pixel art: a baja resolución, con píxeles de arte de ~0,5 m que se agrandan sin suavizar, y un contorno de un píxel en un tono más oscuro de cada superficie donde cambia la profundidad (la silueta) o la normal (cumbreras, esquinas). Al alejar, el píxel de arte crece y el contorno se aligera: pliegues hasta 1 m, silueta hasta 2 m, nada más allá. La imagen está anclada a la grilla para que los píxeles no titilen al desplazar la vista. Sin paleta reducida: probada, convertía el ladrillo en oliva ([PROYECTOS-SIMILARES.md](PROYECTOS-SIMILARES.md), punto 3).
- **Árboles.** Unos 78.000, en dos mallas instanciadas: árboles redondos en parques, patios y laderas, y álamos en riberas y en la Alameda.
- **Vía férrea** (`railBase`). Cada línea se muestrea cada 0,7 m con un perfil de alturas. En el suelo: balasto, durmientes cada 1,4 m (de hormigón en la Línea Central, de madera sobre tierra en el ramal) y rieles de 0,4 m con la trocha de cada línea, drapeados. Donde una calle pasa bajo la vía, la vía sube 3 m en un terraplén con rampas de 1:16 y cruza en un tablero blanco con balaustrada (la calle no puede bajar: el relieve es una malla de 40 m). Los puentes de los ríos son hitos que se registran (`RAIL_BR`) y se dibujan con el perfil final. En el cruce a nivel de 14 Sur, un panel, barreras y cruces de San Andrés; a lo largo de la Línea Central, los postes de la catenaria de OSM con su ménsula, y las señales, encendidas de noche.
- **Trenes** (`trainsInit`, `trainsTick`). Tres trenes modelados según las fotos de Commons (docs/FUENTES.md): el automotor SFB de EFE y un tren de madera en la Línea Central, el Buscarril en el ramal. Cada coche es dos mallas (carrocería y ventanas, que de noche se encienden por `emissive`) que se ubican por su `s` sobre el camino que `railBase` deja en `RAILP`, a la altura del riel, orientadas por la tangente entre sus bogies. Un horario ficticio por línea (`TRAIN.lines`: corridas con entrada, paradas y salida) los despacha de a uno por sentido; fuera del terreno un coche se oculta. Es el único movimiento de la escena: `loop()` llama a `trainsTick()` en cada cuadro, que avanza los trenes y pide un cuadro a 18 por segundo solo mientras uno se mueve dentro de la vista (prueba de frustum por coche); el resto del tiempo la página sigue dibujando solo con `dirty`. Como la imagen de baja resolución está anclada a la grilla, el tren avanza de a un píxel de arte. Con `prefers-reduced-motion` quedan detenidos en la estación. `window.__train(línea, s, tipo)` deja un tren quieto para las capturas; `__trainFps()` mide los cuadros que piden.
- **Nivel de la calle.** Veredas con solera y pasos de cebra en los cruces del centro (`walkBase`), árboles de vereda (`streetTrees`) y autos estacionados (`parkedCars`), todos a lo largo de los tramos de vereda de `walkRuns()`. La densidad de árboles y autos sale de la imagen satelital (`pipeline/satellite.py` a zoom 19 en la plaza, 3 Sur con 3 Oriente, un barrio y la Diagonal): los autos llenan casi toda la solera en las calles de la plaza y son pocos en los barrios. Cada tramo tiene su propia tasa y los autos se agrupan en filas con una cadena de dos estados; todo con su propio generador aleatorio, para que la ciudad no cambie.
- **Noche.** Las ventanas se dibujan en el shader (patrón por piso y vano, y una semilla por fachada que decide cuáles se encienden). También hay faroles cada 35 m en las calles principales.
- **Interfaz.** Los marcadores y etiquetas son elementos del DOM proyectados en cada cuadro, ordenados por prioridad para no superponerse. Las calles se rotulan en dos escalas: las de la ciudad (cuadrícula numerada y avenidas) de cerca, y las rutas y caminos del campo (los `Ruta …` y `Camino …` de OSM de troncal a terciaria, y la Avenida San Miguel como Ruta 115-CH, su `ref` en OSM) cada 3 km, solo donde no hay manzanas construidas a 100 m, desde la vista general. El lector de direcciones usa `config/grid_lines.json`.

## 9. Modelos de hitos

Los hitos se rehicieron sobre su planta real y con estética de pixel art. El primero fue el Estadio Fiscal y el segundo la Catedral; los demás se rehicieron después, varios a la vez (§9.7), en octubre de 2026. Este es el procedimiento que se siguió y que conviene repetir. Los criterios visuales (escala, lenguaje, paleta) están en [ESTETICA.md](ESTETICA.md).

### 9.1 Planta

`python pipeline/landmark.py osm <id> [media caja]` (o un punto de la grilla, `landmark.py osm 4178,3725 110`, para lo que no es un lugar: así se miraron los puentes ferroviarios del Lircay) (con Pillow: `uv run --with pillow python …`) baja de la API de OpenStreetMap una caja alrededor del lugar. Luego lista las vías, relaciones y nodos etiquetados, y dibuja `diagnostics/plan-<id>.png`: calles del mapa con su ancho de render, manzanas, polígonos de OSM con su id y el punto del lugar. Antes de modelar, hay que contestar tres preguntas con el plano:

- **¿El punto del lugar cae en el hito?** Los puntos de `pois.py` son direcciones y suelen quedar en un borde o en la entrada. El del estadio (Alameda 251) está en el borde oriente del recinto. El modelo anterior estaba centrado ahí: quedaba 100 m al oriente del estadio real y montado sobre 5 Norte. El modelo se ubica sobre la planta real y `MODELS[id]` apunta a su centro, para que el marcador y la cámara vayan ahí. El punto de `pois.py` no se toca: es la dirección.
- **¿La caja cubre todo el hito?** La primera descarga del estadio, en una caja centrada en el punto, dejó fuera dos de las cuatro torres de iluminación. Agrande la media caja si la huella llega al borde del plano.
- **¿La huella real choca con calles del mapa?** Las calles vienen del grafo de cicloconecta, no del OSM actual, y pueden pasar por dentro de un recinto. En el estadio, solo el camino de servicio desde 5 Norte entra, por el portón del lado norponiente, y ahí el modelo deja un hueco.

### 9.2 Marco local

`python pipeline/landmark.py frame <id> <vía de referencia> [otras vías]` toma como origen el centroide de la vía de referencia (la cancha, el edificio principal) y como eje v la dirección de su lado más largo. Imprime los lados de la referencia y cada vía en coordenadas (u, v), además de los nodos etiquetados cercanos (torres, entradas). El modelo se escribe en ese marco y una función `G(u,v)` lo pasa a metros de grilla:

```
G(u,v) = [X + u·sin A + v·cos A,  Y − u·cos A + v·sin A]
```

En el estadio, la cancha (vía 815575960) da X = −780,8, Y = 684,8 y A = 64,8°. Las medidas salen de ahí: cancha de 105 × 67 m; pista con radio interior de 36,2 m, exterior de 46,4 m y rectas de 85,8 m; gradería de 20 m de fondo en la curva sur y el lado oriente, y de 8 m en la cabecera norte.

En la Catedral, el edificio (vía 114237041) da X = −102,9, Y = 32,3 y A = 179,3°: v corre por la nave hacia el ábside, al poniente, y u hacia 1 Norte. La fachada queda en v = −29, la torre (vía 798980080) en la esquina de 1 Norte y la escalinata (vía 799225255) delante. En la plantilla, `localFrame(X, Y, A)` devuelve `G`, `V`, `N3` y `R` para cualquier hito.

### 9.3 Fotos y fuentes: el estado actual

La planta no dice alturas, techos ni colores. `python pipeline/landmark.py photos <id> ["consulta"]` busca en Wikimedia Commons y guarda las miniaturas en `diagnostics/fotos/<id>/`, más recientes primero, con un `indice.txt` (fecha, licencia y enlace). Si la etiqueta `wikimedia_commons` de OSM nombra una categoría, búsquela con `incategory:`: `landmark.py photos catedral 'incategory:"Catedral_de_San_Agustín,_Talca"'` (con el nombre solo, Commons hace una búsqueda de texto). Con consulta, el primer argumento puede ser cualquier nombre, que solo nombra la carpeta: así se buscaron las fotos de la Diagonal (`landmark.py photos diagonal "Diagonal Isidoro del Solar Talca"`), que es una calle y no un lugar. Complemente con prensa o fichas técnicas sobre remodelaciones.

**La imagen satelital puede tener años.** La de Esri (`satellite.py`) muestra el estadio antes de las obras de 2017: galería oriente descubierta y techo gris en la tribuna. Las fotos de 2021 a 2025 y la ficha de StadiumDB muestran el estado actual. Ahora una membrana de PVC cubre la galería oriente y ambas cabeceras, la tribuna está techada entera y hay escaleras amarillas, asientos rojos con filas negras y cuatro torres de iluminación. Use el satélite para plantas y las fotos fechadas para todo lo que está sobre el suelo.

Anote de dónde sale cada detalle. Los detalles sin fuente se marcan como aproximados en el comentario del modelo (en el estadio: la altura de la cabecera norte y el dibujo exacto de los asientos negros).

### 9.4 Modelo

- **Estética de pixel art.** Los criterios completos están en [ESTETICA.md](ESTETICA.md). En resumen:
  - Formas escalonadas en vez de rampas y curvas lisas: cada fila de una gradería es un peldaño, cada arco un rectángulo con dos escalones.
  - Dos tonos alternados donde la realidad tiene ritmo: filas, franjas de corte del pasto, paños de techo, bandas de un vitral.
  - Molduras blancas (pilastras, bandas, cornisas) como contorno; vanos oscuros y fríos.
  - Líneas más anchas que las reales (0,5 m en vez de 0,12) para que se lean a ~1 m por píxel, el zoom de la ficha.
  - Detalles que ocupen 2 o 3 píxeles: paneles de focos, puertas, pilares.
  - Paleta en un objeto local `K`, tomada de las fotos y de la tabla de ESTETICA.md §4.
- **Constructor.** `buildModels(B, S)` recibe dos. `B` pasa por el sombreador de ventanas procedurales, que pinta ventanas en toda cara vertical a más de 1 m del suelo. `S` no pasa por él. Use `S` para lo que tiene muchas caras verticales que no son fachadas, como las contrahuellas de una gradería, y para los edificios cuyas ventanas se dibujan a mano, como la Catedral.
- **Alturas.** Las etiquetas `height` y `building:levels` de OSM no sirven para hitos: la torre de la Catedral dice 17 m y mide ~39. Mida en una foto frontal con una medida conocida de la planta como escala (el ancho de la torre) y anote la estimación en el comentario.
- **Huella y terreno.** `occMark(polígono)` con la huella real, no un rectángulo, para que la ciudad y los árboles no la invadan. `padAt(caja)` nivela el terreno y su altura va en `S.dy` (o `B.dy`). Las capas planas del modelo van a 0,30–0,43 m sobre la explanada, separadas al menos 0,03 m para evitar parpadeo.
- **Recintos.** Si el hito está dentro de un recinto cercado (el polígono OSM del recinto deportivo, simplificado), agregue ese polígono a `NOLOTS`: la ciudad no genera casas ahí, pero sí árboles.
- **Luces.** Los puntos que deben brillar de noche van a `GLOW` (x, altura absoluta, y). Póngalos delante de la cara que los lleva, o la prueba de profundidad los esconde.
- **Archivo.** El modelo va en `src/js/hitos/<id>.js`, que empieza con la línea `  // ==== hito: <id> ====` (con la sangría del cuerpo de `buildModels`), y su id se agrega a `src/js/hitos/ORDER`: al final, salvo que su explanada deba ceder ante la de un vecino (el encabezado de ORDER explica el orden). `make check` avisa si falta uno de los dos.
- **Comentario.** Arriba del modelo, en su archivo, cite los ids de OSM y las fuentes de lo que está sobre el suelo, y diga qué es aproximado.

### 9.5 Verificación

Con `tools/screenshot.py --hash <id>` y `--js`:

| Vista | `--js` |
|---|---|
| ficha | (nada) |
| de cerca | `document.querySelector('#cx').click();for(let i=0;i<3;i++)document.querySelector('#zin').click()` |
| girada | lo anterior + `;document.querySelector('#rr').click()` |
| noche | lo anterior + `;document.querySelector('#night').click()` |
| móvil | `--size 390x844 --dpr 3`, sin `--js` |

Compare la vista girada con las fotos tomadas desde un ángulo parecido. Revise también la vista inicial (`shots/centro.png`) y que las estadísticas solo cambien donde se espera: con `NOLOTS`, el número de edificios baja un poco. Para encuadrar un punto que no es un lugar (un muelle, un puente), `--js "__look(x, y, zoom, giro)"` centra la cámara en ese punto de la grilla; `zoom` 4 es el de la ficha y `giro` es el azimut en radianes (`Math.PI/4` es la vista inicial; sumando `Math.PI` se mira desde el noroeste). Para varias vistas de una sola carga (la carga es lo que cuesta), `--view nombre=expresión`, repetido, deja una captura por vista en el directorio de salida. Para mirar un dato de la página sin captura (`window.__rail`, `__trains()`, la altura `__E(x, y)`), `tools/probe.py "expresión" …` lo imprime como JSON.

### 9.6 Registro

- `CHANGELOG.md`: qué cambió y con qué fuentes.
- `docs/FUENTES.md`: las fotos y fichas usadas, con su licencia.
- `CLAUDE.md`: las trampas nuevas.

Si un hito no tiene fotos con licencia libre (el Juzgado de Garantía, la Fiscalía Local), Google Street View y su imagen satelital pueden servir para mirar, nunca para copiar: nada de esas imágenes entra en la maqueta ni en el repositorio, y FUENTES.md lo dice. Si no hay ninguna vista de una fachada (el Juzgado de Familia), el modelo se queda en un bloque sencillo con la planta, la altura y el techo correctos, y el comentario lo declara.

### 9.7 Varios hitos a la vez

Los hitos restantes se rehicieron en cinco sesiones paralelas, una por zona (Plaza de Armas; barrio judicial de la Alameda; Alameda centro y oriente; oriente del centro; afueras), cada una en su propio `git worktree`. Para que las ramas se mezclen sin conflictos:

- Cada hito está en su archivo, `src/js/hitos/<id>.js`, y una sesión solo edita el suyo. (Entonces era un bloque de la plantilla bajo su línea de marca `// ==== hito: <id> ====`, que sigue siendo la primera línea de cada archivo: las marcas, que no cambiaban, separaban los cambios de dos ramas, porque git no mezcla cambios en líneas contiguas.) Dos sesiones que agregan un hito cada una tocan las dos el final de `src/js/hitos/ORDER`: esa mezcla se resuelve a mano, con una línea por hito.
- Lo compartido (`localFrame`, `facade`, el terreno, la ciudad) no se toca en paralelo. Antes de repartir el trabajo se subió a `facade()` el vocabulario de la Catedral, para que nadie lo copiara por su cuenta; los ayudantes nuevos quedan dentro de cada bloque y se suben después (CLAUDE.md, «Ideas pendientes»).
- Las sesiones no editan la documentación: entregan sus entradas de CHANGELOG, FUENTES y trampas, y se integran todas al final, en un solo cambio.
- `raw/` y `node_modules/` no están en git: en cada worktree van como enlaces simbólicos a los del checkout principal.
- Commons limita las descargas cuando varias sesiones bajan fotos a la vez; `landmark.py photos` espera y reintenta. Las capturas, en cambio, conviene sacarlas de a una: con la máquina cargada, Playwright agota su tiempo.

## 10. Diseño de la interfaz

- **Paleta.** La escena usa los tonos del Maule en verano: campo seco, teja, ripio de río. La interfaz evoca un expediente: tinta azul marino sobre papel, con un acento vino (el Maule es zona vitivinícola) para la capa jurídica y verde para los hitos.
- **Tipografía.** Alegreya SC, Alegreya Sans e IBM Plex Mono (esta última para las direcciones de la grilla).
- **Temas.** Claro y oscuro con tokens CSS. En móvil el panel se convierte en hoja inferior.

## 11. Verificación

- **Validación de lugares.** `make validate` compara cada lugar con su dirección. En la revisión de la exportación (10-10-2026) detectó un error: la U. Autónoma estaba ~420 m al poniente de su dirección, y se corrigió (CHANGELOG).
- **Reproducibilidad.** `process_geometry.py` reproduce exactamente la geometría de `data/` desde `raw/` (con `raw/osm/map-comuna.json` y `raw/osm/comuna-talca.json`; hasta octubre de 2026, la de la v1).
- **Revisión automática.** `make check` (`tools/check.py`, menos de un segundo) revisa los JSON, los marcadores de la plantilla, las restricciones de los artifacts y que el script de `dist/` compile (`node --check`); el hook de pre-commit lo corre solo (`make hooks`). `make smoke` carga la página en Chromium y falla si hay errores de consola o la generación sale vacía.
- **Capturas.** `tools/screenshot.py` permite revisar escritorio, móvil, tema oscuro, modo noche, recorridos y búsqueda. Para comparar alternativas de render, `tools/variants.py` arma en una sola carga una hoja de vistas por variantes (así se evaluó el pixel art, PROYECTOS-SIMILARES.md punto 3). Las vistas para revisar un hito están en la sección 9.5.

## 12. Limitaciones

- Los edificios generados no son los reales: son una interpretación según las reglas descritas. Solo los hitos siguen su planta real (sección 9), y en ellos lo que está sobre el suelo es una interpretación de fotos: cada modelo dice en su comentario qué es aproximado.
- Los tres ríos, el Estero Pangue–Panguilemo, el Canal Pencahue, la Ruta 5 y el ferrocarril son los de OpenStreetMap. Donde OSM no tiene el agua, el ancho es una constante: el Lircay al oriente de x ≈ 13.700 (60 m), el Piduco aguas arriba de 6 Oriente (12 m), el estero (10 m) y el canal (6 m). Los puentes de las calles son solo la calle sobre el agua, salvo los dos del Claro junto a la Alameda.
- La maqueta termina en el límite de la comuna, también donde el límite sigue un río: el Lircay en el oriente (x ≈ 9.800–11.700 y al oriente de 13.700) queda cortado a lo largo, por donde pasa el límite. En el campo, las parcelas, las hileras de álamos y el matorral son genéricos (no los predios reales), y los caminos rurales son los de OSM con el ancho de su clase. Fuera de los tres ríos, el Estero Pangue–Panguilemo y el Canal Pencahue, no hay esteros ni canales (el Canal Sandoval, el Baeza, los esteros Caiván y Los Molinos, las acequias).
- El relieve está exagerado (×3 en el plano, ×1,3 en los cerros) y suavizado a ~40 m: no se ven taludes ni desniveles de pocos metros. Los ríos no siempre van por el fondo del valle del modelo; el Claro y el Lircay se nivelan a lo ancho del cauce, y en las celdas de la orilla el agua sube un poco hacia la ribera.
- Fuera del centro, la grilla se deforma y el lector de direcciones deja de funcionar. Muestra «Fuera del centro numerado».
- La información institucional (direcciones, notarios) es de septiembre de 2026 y puede cambiar.

## 13. Usos de suelo (`config/usos.json`, `pipeline/usos.py`)

El Censo describe las manzanas por sus habitantes. Donde no hay viviendas da el tipo «sin información», que la maqueta pintaba como arena (más de 4 ha) o como parque, y fuera de las manzanas no hay nada: el terreno pelado. Además, las manzanas con datos que no son vivienda (el regimiento, los cementerios, los colegios, el golf) se llenaban de casas generadas. En octubre de 2026 eso dejaba 14 manzanas en blanco de 4 ha o más (267 ha) y campos de arena a ambos lados de la Ruta 5 y al sur del Piduco.

**Levantamiento.** Se hizo por cuadrante (nororiente, norponiente, surponiente y suroriente), primero las 14 manzanas grandes, luego el borde al oriente de la Ruta 5 y al sur del Piduco, luego las manzanas chicas:

1. OSM entero en una sola descarga, por la API `map` (Overpass no respondía): `python pipeline/traces.py tiles -4000 5600 -4200 4700 todo` → `raw/osm/map-todo.json` (~137 mil elementos, ~3 min).
2. `python pipeline/usos.py survey todo [caja]` lista los polígonos etiquetados (`landuse`, `amenity`, `leisure`, `natural`, `military`…) que caen sobre terreno en blanco, con las manzanas que pisan. `usos.py blancos 0.5 --osm todo` lista al revés: las manzanas en blanco que ningún uso cubre, con lo que OSM tiene en ellas.
3. `python pipeline/satellite.py punto x y lado 17 --calles` muestra la imagen de Esri con las manzanas, las calles del mapa, una cruz cada 100 m y los usos ya cargados (naranjo): así se revisa cada entrada y se dibujan a mano los polígonos que OSM no tiene.
4. Lo que OSM tiene y la imagen confirma se importa: `usos.py importar comuna` (hasta octubre de 2026, `todo`) rehace todas las entradas con `"auto": true` (confianza media hasta revisarlas en la imagen). Lo que OSM no tiene, o tiene mal, va como entrada a mano, que manda: las 14 manzanas grandes, villas, conjuntos y parcelas. Lo que otra sección dibuja (la Alameda, el patio de la Estación) va en `excluir`.
5. `usos.py check` revisa el archivo (fuente, confianza, hitos, superposiciones, cuánta agua pisa) y cuánto de las manzanas grandes queda cubierto.

Lo que se encontró en las 14 manzanas grandes: casi todas son eriazos (rastrojo seco, ribera, sitios junto a la Ruta 5); en la 3156 están la planta de Cecinas PF y un recinto deportivo; en la 3193, el humedal urbano del Claro; en la 3387 y la 3438, conjuntos de vivienda posteriores al Censo; la 3451 es una villa entera construida después de 2017; la 3184 es una ladera de bosque. Fuera de las manzanas, OSM tiene villas recientes con sus calles en el mapa (`vivienda`: build.py las convierte en manzanas construidas y la ciudad generada pone las casas), condominios con pasajes que el mapa no tiene (`conjunto`: hileras de casas pareadas iguales) y parcelas a lo largo de los caminos.

**La comuna** (octubre de 2026). Al pasar a la comuna entraron manzanas «sin información» del campo que el levantamiento no había visto; `usos.py blancos 0.5 --osm comuna` las lista. Las cuatro de más de 0,8 ha fuera del rectángulo anterior se revisaron en la imagen: la 3036 (10,6 ha, junto a la Ruta 115-CH) es un aserradero, con su polígono de OSM (w1255366487, en `excluir` para que `importar` no lo duplique) y `tipo: "aserradero"`, más potreros secos; la 3074 son parcelas con casa y jardín, la 2812 un potrero arado y la 2811 casas y galpones alrededor de una cancha de fútbol (construida en `config/manzanas.json`; la cancha es la de OSM).

**El campo** (octubre de 2026). Con la comuna, `importar` toma `map-comuna` y los polígonos con su centro dentro del límite: entran ~2.000 ha de potreros, huertos, viñas, bosques y eriazos de OSM, la mayoría lejos de toda manzana. Se revisaron en la imagen las seis más grandes: los huertos de 116, 74 y 66 ha y la Viña Calina muestran sus hileras; un potrero de 181 ha es rastrojo seco; un huerto de 236 ha (w798105494) es sobre todo potreros, chacras y un vivero, y quedó en `excluir`. Donde hay un uso, `buildBase()` no pone las parcelas genéricas (`usoAt`). Un huerto grande no se puede dibujar árbol por árbol (585 ha a 33 m² por árbol): lleva árboles en sus 12 m de borde y, adentro, franjas de copa con su sombra.

**Render.** Cada uso tiene un dibujador genérico en `src/js/76-usos.js` (sección `// ==== usos de suelo ====`), con el vocabulario de ESTETICA §3 (dos tonos, líneas de 0,5 m, blanco como contorno) y números aleatorios con semilla por entrada. Los usos reservan su suelo en `occ` antes de la ciudad, como un hito, pero dejan libres 2,5 m junto a las calles para que sigan las veredas, los árboles de vereda y los autos. El suelo va a 0,11 en su propia malla, recortado donde hay ríos, hitos, la Ruta 5 o la vía; los detalles a 0,12–0,14, de a 1 cm. Las industrias sobre manzanas con datos conservan los galpones de `cityGen` y solo reciben el patio.

**Lo aproximado.** Todo lo que está sobre el suelo es genérico: los galpones, las tumbas y las cuadras no son los reales; las canchas de OSM llevan las líneas de su deporte, y los recintos sin canchas en OSM reciben una cancha de fútbol al centro si cabe. Las entradas importadas de OSM no se revisaron una por una en la imagen. Las villas posteriores al Censo tienen ~35 viviendas por hectárea supuestas.

## 14. Publicación

La maqueta se publica de dos formas, desde la misma plantilla:

- **Como artifact de Claude:** `dist/talca.html`, el fragmento, con las restricciones de CLAUDE.md (`make check` las revisa).
- **Como sitio:** `dist/index.html` en [talca.eduramirez.com](https://talca.eduramirez.com/). `build.py --standalone` le agrega el `<head>` que la plataforma de artifacts pone por su cuenta: idioma `es-CL`, título, descripción, dirección canónica, Open Graph y tarjeta de Twitter con una imagen del mapa, e ícono. Los archivos de `src/site/` se copian a su lado. La imagen de Open Graph (`og.jpg`, 1200 × 630, en JPEG para que la vista previa de WhatsApp no la descarte) y el ícono para iOS salen de `tools/site_assets.py` (`make site-assets`): la imagen es una captura del mapa sin el panel ni los controles, con el encabezado y los marcadores.

El sitio se sube a Cloudflare Pages con `make deploy` (`scripts/deploy-cloudflare.sh`), a mano o desde el hook de pre-push cuando se empuja `main` al repositorio canónico de Codeberg. El hook es de mejor esfuerzo, como el del blog: una publicación fallida no detiene el push, y no publica un árbol con cambios sin commit, para que el sitio sea siempre un commit de `main`.
