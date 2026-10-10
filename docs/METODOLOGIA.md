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

   Dentro de la maqueta quedan 3.134 manzanas con datos y 322 sin información. Cada manzana trae `TOTAL_PERS` y `TOTAL_VIVI`, que se usan para la densidad. El sistema de referencia es EPSG:4674 (SIRGAS 2000), que a esta escala equivale a WGS84.
2. **Grafo vial de Talca extraído de OpenStreetMap**, del proyecto [Shiroku36/cicloconecta](https://github.com/Shiroku36/cicloconecta) (`data/cities/talca/nav_graph.json`). Tiene 31.529 nodos y 65.278 aristas con nombre de calle, tipo `highway` e id del way de OSM. Es un grafo pensado para bicicletas, así que **no incluye autopistas** (la Ruta 5) ni ferrocarriles.

3. **Elevación SRTM de 1 segundo de arco** (~30 m), tesela `S36W072`, de los [Terrain Tiles de AWS](https://registry.opendata.aws/terrain-tiles/) (formato `.hgt`, sin autenticación). Una sola tesela cubre toda la maqueta.

`pipeline/fetch_sources.sh` descarga solo los archivos necesarios mediante sparse checkout.

## 3. Sistema de coordenadas y giro de la grilla

Talca tiene una de las grillas más regulares de Chile, con calles numeradas desde la Plaza de Armas. Para que la grilla calce con los ejes isométricos, primero se midió su orientación:

- Para cada tramo de calle numerada a menos de 1,5 km de la plaza se calculó el rumbo y se armó un histograma ponderado por largo.
- Las calles Norte/Sur dieron un pico en −5° / −6° y las Oriente/Poniente en −4° / −5°.
- Se adoptó un **giro de +5°**.

La proyección (`common.loc`) es equirectangular local con origen en el centro de la Plaza de Armas (−35,42653; −71,66600). Usa 90.719 m por grado de longitud y 110.950 m por grado de latitud. A escala de una ciudad el error es menor a 0,1 %.

## 4. Procesamiento de la geometría (`process_geometry.py`)

- **Recorte.** La maqueta abarca el rectángulo x ∈ [−4.000; 5.600] m, y ∈ [−4.200; 4.700] m (≈ 9,6 × 8,9 km). Las manzanas se recortan con Sutherland-Hodgman.
- **Simplificación.** Douglas-Peucker con 1,2 m de tolerancia para manzanas y 0,8 m para calles. Los anillos cerrados se simplifican en dos mitades, porque el algoritmo falla cuando el primer y el último punto coinciden.
- **Orientación.** Todos los anillos quedan en sentido antihorario y se descartan polígonos de menos de 30 m².
- **Calles.** Las aristas del grafo vienen dirigidas y duplicadas. Se eliminan duplicados y se encadenan en polilíneas por way de OSM. Cada calle recibe una clase de 0 a 7 (troncal, primaria, secundaria, terciaria, residencial, pasaje, peatonal, servicio), que define su ancho en el render: 16, 13, 11, 9,5, 7, 5, 3,5 y 3,5 m.
- **Codificación.** Coordenadas enteras en metros y en delta, unos 560 KB en total.

## 5. Ríos, vía férrea y Ruta 5 (`config/trazados.json`)

Como ninguna fuente traía estos elementos, se dibujaron a mano. `diagnostics.py` genera paneles con las manzanas, las calles y una grilla fina de coordenadas (0,001°). En esos paneles un río aparece como un hueco continuo entre manzanas. El razonamiento en cada caso:

- **Estero Piduco.** Una franja sin manzanas cruza la ciudad en diagonal, desde el sureste hasta la Alameda poniente. Coincide con Wikipedia («cruza por enmedio de Talca en dirección nor-poniente») y con que la Plaza de Armas queda «apenas a cuatro cuadras». La calle Costanera lo acompaña.
  - Se descartó el punto de confluencia de GeoNames (−35,4325; −71,6935): la franja llega claramente al Río Claro cerca del extremo poniente de la Alameda (≈ −35,4232; −71,6850).
- **Río Claro.** Primero se trazó a mano siguiendo el borde poniente de las manzanas. Desde octubre de 2026 sale de OpenStreetMap (abajo): el trazado a mano quedaba 115–180 m al poniente del río frente al Parque Río Claro y hasta ~750 m fuera en el norte, donde cortaba potreros.
- **Río Lircay.** Sigue el borde norte, por la llanura de inundación (manzanas sin información), y se ancla en el puente Lircay de la Ruta 5.
- **Vía férrea.** El tramo central es exacto: se ancló en la estación y en los pasos bajo nivel de 2 Norte, 1 Norte, 1 Sur y 8 Sur, más el puente sobre el Piduco, todos puntos OSM consultados en Mapcarta. El trazado resultante es paralelo a la grilla, a la altura de 11–12 Oriente. El tramo norte, hasta el puente ferroviario del Lircay junto a la Ruta 5, es aproximado.
- **Ruta 5.** Un corredor recto sin manzanas ni calles: es la autopista, ausente del grafo ciclista.

**El Río Claro desde OpenStreetMap.** En octubre de 2026 la API de OSM respondía, pero Overpass no (los tres servidores probados dieron error por carga). En vez de una consulta por área se bajan dos objetos completos, que no tienen límite de caja: `way/203907278/full` (el eje, `waterway=river`) y `relation/15397714/full` (el agua, `natural=water`, con las islas como anillos interiores). `process_geometry.py` los guarda en `raw/osm/rio-claro.json` cuando `config/trazados.json` trae la clave `osm` en el río, recorta el agua a la maqueta y deja el eje en `water` y los anillos en `area`. El multipolígono llega hasta y ≈ −630; al sur la plantilla dibuja una cinta de `ancho_m` sobre el eje.

Antes de reemplazar el trazado se comparó OSM con el mapa sobre la imagen satelital (paneles con el eje, el agua, las manzanas y las calles con su ancho de render):

- El eje y el agua de OSM calzan con la imagen en todo el tramo.
- Solo una calle del mapa cruza el río, la Ruta K-60-J, a ~5 m del puente de OSM.
- Cinco manzanas del censo entran más de 15 m en el agua (hasta 85 m en el norte): sus bordes siguen el eje del cauce o cortan un brazo lateral, y ninguna tiene edificios en esa parte. Por eso el agua del Claro se dibuja sobre las manzanas (y bajo las calles) y no al revés, como los otros ríos.

El relieve tampoco sigue al río en todas partes: el SRTM suavizado pone el fondo del valle a decenas de metros del cauce real, y el agua apoyada en el terreno quedaba inclinada (10 m a lo largo de un muelle de 45 m). La plantilla nivela los nodos del relieve que caen dentro del agua al promedio del cauce en 80 m a la redonda (`claroLevel`) y repone esos niveles después de las explanadas (`claroRelevel`).

El Lircay y el Piduco siguen dibujados a mano (salvo los últimos cinco puntos del Piduco, nodos de OSM). Para reemplazarlos se puede repetir lo del Claro con sus objetos de OSM, o, si Overpass responde, esta consulta trae todos los trazados:

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

## 8. Render (`src/template.html`)

- **Base.**
  - Una malla de terreno (sección 6) con bordes de tierra que siguen su perfil.
  - Parcelas agrícolas generadas donde no hay manzanas, con algunas hileras de álamos.
  - Manzanas como polígonos planos, calles como cintas encima, ríos con ribera de ripio y una franja verde de parque ribereño. El Río Claro es el agua de OSM con sus islas, sobre las manzanas, con una franja de ripio en cada orilla, nivelada a lo ancho del cauce.
- **Edificios procedurales** (`cityGen`). Se generan **a lo largo de cada tramo de calle**, por ambos lados, y no siguiendo el borde de la manzana. Las manzanas del censo pueden contener pasajes interiores, y así los edificios dan siempre a una calle real. Para cada lote:
  1. Se identifica la manzana que hay detrás de la calle.
  2. Según la manzana se elige un estilo:
     - **core** (centro, fachada continua): de 1 a 4 pisos, con torres ocasionales cerca del centro.
     - **house**: casas aisladas o pareadas con techo a dos aguas de teja o zinc.
     - **apt**: blocks de 3 a 5 pisos donde la densidad supera 115 viviendas por hectárea.
     - **ind**: galpones en manzanas grandes sin habitantes.
  3. Se descarta el lote si invade otra calle, si sale de la manzana o si choca con algo ya construido. Para esto último hay un raster de ocupación de 2,5 m.

  Todo usa números aleatorios con semilla, así que la ciudad sale idéntica en cada carga. El resultado: ~72.000 edificios y ~2,1 millones de vértices en un solo buffer.
- **Hitos.** Hay 19 modelos hechos a mano. El Estadio Fiscal y la Catedral siguen su planta real y la estética de pixel art (sección 9 y [ESTETICA.md](ESTETICA.md)); los demás todavía son simplificados: entre ellos la Corte con su pórtico, los tribunales penales, la Fiscalía, el Juzgado de Familia, la ex Cárcel con muros y torres de guardia, el Mercado, la Casa de la Independencia, el Estadio, la Estación, el Teatro, La Victoria, el Hospital y la estatua del Cerro La Virgen. Reservan su huella y nivelan el terreno antes de que se genere la ciudad.
- **Árboles.** Unos 76.000, en dos mallas instanciadas: árboles redondos en parques, patios y laderas, y álamos en riberas y en la Alameda.
- **Noche.** Las ventanas se dibujan en el shader (patrón por piso y vano, y una semilla por fachada que decide cuáles se encienden). También hay faroles cada 35 m en las calles principales.
- **Interfaz.** Los marcadores y etiquetas son elementos del DOM proyectados en cada cuadro, ordenados por prioridad para no superponerse. El lector de direcciones usa `config/grid_lines.json`.

## 9. Modelos de hitos

Los hitos se rehicieron sobre su planta real y con estética de pixel art. El primero fue el Estadio Fiscal y el segundo la Catedral; los demás se rehicieron después, varios a la vez (§9.7), en octubre de 2026. Este es el procedimiento que se siguió y que conviene repetir. Los criterios visuales (escala, lenguaje, paleta) están en [ESTETICA.md](ESTETICA.md).

### 9.1 Planta

`python pipeline/landmark.py osm <id> [media caja]` (con Pillow: `uv run --with pillow python …`) baja de la API de OpenStreetMap una caja alrededor del lugar. Luego lista las vías, relaciones y nodos etiquetados, y dibuja `diagnostics/plan-<id>.png`: calles del mapa con su ancho de render, manzanas, polígonos de OSM con su id y el punto del lugar. Antes de modelar, hay que contestar tres preguntas con el plano:

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

La planta no dice alturas, techos ni colores. `python pipeline/landmark.py photos <id> ["consulta"]` busca en Wikimedia Commons y guarda las miniaturas en `diagnostics/fotos/<id>/`, más recientes primero, con un `indice.txt` (fecha, licencia y enlace). Si la etiqueta `wikimedia_commons` de OSM nombra una categoría, búsquela con `incategory:`: `landmark.py photos catedral 'incategory:"Catedral_de_San_Agustín,_Talca"'` (con el nombre solo, Commons hace una búsqueda de texto). Complemente con prensa o fichas técnicas sobre remodelaciones.

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
- **Comentario.** Arriba del modelo, en la plantilla, cite los ids de OSM y las fuentes de lo que está sobre el suelo, y diga qué es aproximado.

### 9.5 Verificación

Con `tools/screenshot.py --hash <id>` y `--js`:

| Vista | `--js` |
|---|---|
| ficha | (nada) |
| de cerca | `document.querySelector('#cx').click();for(let i=0;i<3;i++)document.querySelector('#zin').click()` |
| girada | lo anterior + `;document.querySelector('#rr').click()` |
| noche | lo anterior + `;document.querySelector('#night').click()` |
| pixel | lo anterior + `;document.querySelector('#pixel').click()` |
| móvil | `--size 390x844`, sin `--js` |

Compare la vista girada con las fotos tomadas desde un ángulo parecido. Revise también la vista inicial (`shots/centro.png`) y que las estadísticas solo cambien donde se espera: con `NOLOTS`, el número de edificios baja un poco. Para encuadrar un punto que no es un lugar (un muelle, un puente), `--js "__look(x, y, zoom, giro)"` centra la cámara en ese punto de la grilla; `zoom` 4 es el de la ficha y `giro` es el azimut en radianes (`Math.PI/4` es la vista inicial; sumando `Math.PI` se mira desde el noroeste).

### 9.6 Registro

- `CHANGELOG.md`: qué cambió y con qué fuentes.
- `docs/FUENTES.md`: las fotos y fichas usadas, con su licencia.
- `CLAUDE.md`: las trampas nuevas.

Si un hito no tiene fotos con licencia libre (el Juzgado de Garantía, la Fiscalía Local), Google Street View y su imagen satelital pueden servir para mirar, nunca para copiar: nada de esas imágenes entra en la maqueta ni en el repositorio, y FUENTES.md lo dice. Si no hay ninguna vista de una fachada (el Juzgado de Familia), el modelo se queda en un bloque sencillo con la planta, la altura y el techo correctos, y el comentario lo declara.

### 9.7 Varios hitos a la vez

Los hitos restantes se rehicieron en cinco sesiones paralelas, una por zona (Plaza de Armas; barrio judicial de la Alameda; Alameda centro y oriente; oriente del centro; afueras), cada una en su propio `git worktree`. Para que las ramas se mezclen sin conflictos:

- En `buildModels`, cada hito ocupa el bloque bajo su línea de marca `// ==== hito: <id> ====`, y un hito nuevo tiene la suya. Una sesión solo edita entre su marca y la siguiente. Git no mezcla cambios de dos ramas en líneas contiguas: las marcas, que no cambian, los separan.
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
- **Reproducibilidad.** `process_geometry.py` reproduce exactamente la geometría publicada en la v1.
- **Capturas.** `tools/screenshot.py` permite revisar escritorio, móvil, tema oscuro, modo noche, recorridos y búsqueda. Las vistas para revisar un hito están en la sección 9.5.

## 12. Limitaciones

- Los edificios generados no son los reales: son una interpretación según las reglas descritas. Solo los hitos siguen su planta real (sección 9), y en ellos lo que está sobre el suelo es una interpretación de fotos: cada modelo dice en su comentario qué es aproximado.
- El Lircay, el Piduco, el tramo norte del ferrocarril y la Ruta 5 son trazados aproximados (con un error de decenas de metros). El Río Claro es el de OpenStreetMap; al sur de y ≈ −630 su ancho es una constante (60 m).
- El relieve está exagerado (×3 en el plano, ×1,3 en los cerros) y suavizado a ~40 m: no se ven taludes ni desniveles de pocos metros. Los ríos no siempre van por el fondo del valle del modelo; el Claro se nivela a lo ancho del cauce, y en las celdas de la orilla el agua sube un poco hacia la ribera.
- Fuera del centro, la grilla se deforma y el lector de direcciones deja de funcionar. Muestra «Fuera del centro numerado».
- La información institucional (direcciones, notarios) es de septiembre de 2026 y puede cambiar.
