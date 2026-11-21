---
paths:
  - "pipeline/**"
  - "config/**"
  - "Makefile"
  - "tests/**"
---

# El pipeline de datos (pipeline/, config/, data/)

Las fuentes, los scripts de `pipeline/` y lo que escriben en `data/`. El porqué de cada paso está en docs/METODOLOGIA.md.

## Arquitectura

**Pipeline (Python, solo biblioteca estándar).** Ejecuta los scripts desde `pipeline/`, porque se importan entre sí por nombre. Lo compartido no se copia en cada script: `common.py` (rutas, `loc`/`unloc`, `comuna()`, `EXT`, `require`), `geom.py` (`dec`/`enc`, `area`, `centre`, `pip`, `in_ring` —la misma respuesta que `pip`, con las aristas por bandas: para un anillo que se prueba muchas veces, como el límite—, `near_ring`, `clip_line`, `crossings_at`/`scanlines`, `seg_dist`, `crossings`, `rdp`/`simplify_ring`, `merc_px`, `inner_point`), `osm.py` (`osm.load('comuna')`: los JSON de OSM por id, en metros de grilla; `osm.join`), `net.py` (`net.get`: un User-Agent genérico, reintentos ante 429/5xx y cortes) y `cli.py` (`cli.run(cmds, __doc__)`: la firma de cada comando es su sintaxis —argumentos, `--opción valor`, interruptores—, y lo que no calza termina con el uso y código 1). Los comentarios y docstrings de estos módulos van en inglés; el docstring de cada comando, que imprime `--help`, en español. Un cambio en `pipeline/` que no debe cambiar los datos se prueba con `make golden` (antes `SAVE=1`): `geom.rdp` tiene un error conocido que no se arregló porque cambia el mapa (su docstring y `raw/eval/resultado-calidad-pipeline-nov16.md`).
`raw/` + `config/trazados.json` (+ los ríos de la API de OSM, en `raw/osm/rio-<río>.json`; el límite de la comuna, `raw/osm/comuna-talca.json`; las calles de OSM donde no llega el grafo, `raw/osm/map-comuna.json`) → `process_geometry.py` → `data/geometry.json` (`limit`: el límite de la comuna; `water`: ejes; `area`: el agua del Claro con sus islas; `rail`, `ramal`, `railx`, `rmast`, `rsig`, `rgauge`: la vía férrea, que `pipeline/railway.py` escribe en `config/trazados.json`)
`raw/dem/copernicus/Copernicus_DSM_COG_10_S36_00_W072_00_DEM.tif` (Copernicus GLO-30; `geotiff.py`) → `elevation.py` → `data/elevation.json`
`raw/osm/map-comuna.json` (`traces.py tiles-comuna`) → `traces.py calzadas comuna` → `data/ruta5.json` (las dos calzadas y los ramales de la Ruta 5)
`raw/osm/map-comuna.json` → `sentidos.py` → `data/sentidos.json` (las calles de un sentido, en el sentido del tránsito; no lo lee la página: `tools/export.py --letreros`, para el juego)
`pois.py` → `data/pois.json`, `data/pois.csv`
`raw/osm/map-comuna.json` (`make osm`) → `usos.py importar comuna` → `config/usos.json` (+ entradas a mano)
`raw/cl/` (`fuentes_cl.py fetch`) → `usos.py importar ciren|censo2024|areasverdes` → `config/usos-ciren.json`, `config/usos-censo2024.json` (CC BY-SA 4.0), `config/usos-minvu.json`: un archivo por licencia, que `build.py` junta después de `config/usos.json` (`USOS_FILES`)
`raw/cl/conaf/` → `cobertura.py` → `data/cobertura.json` (como `DATA.cob`: la cobertura vegetal de CONAF, una clase cada 40 m)
`raw/osm/map-comuna.json` + `config/edificios.json` + `config/techos.json` (`edificios.py techos`, de la imagen de Esri) (+ `raw/edificios-ml/`, de `tools/ml_buildings.py`: las huellas de Microsoft y Google de Overture y los altos de Google 2.5D) → `edificios.py` → `data/edificios.json` (los edificios de OSM: manzanas enteras, donde OSM está completo, y mixtas, donde tiene algunos o hay huellas de aprendizaje automático; las huellas fuera de las manzanas, sueltas). Las huellas van en `h`: casi todas rectilíneas, como una dirección y los largos de sus lados sobre una grilla de 0,5 m girada a ella (`h_encode`; trampa «Las huellas de aprendizaje automático»)
`build.py` marca como construidas (tipo 3) las manzanas de `config/manzanas.json` y las `vivienda` de `config/usos.json` (las que no tienen manzana se agregan), inyecta los usos de `config/usos.json` y de los archivos de las fuentes chilenas (como `DATA.usos`, en el orden de `USOS_FILES`) e inyecta geometry + elevation (como `DATA.elev`) + `data/ruta5.json` (como `DATA.r5`, el `R5` de la plantilla) + `data/edificios.json` (como `DATA.ed`, el `ED` de la plantilla, con `DATA.ed.f`: lo medido en fotos de los edificios de la plaza, de `config/fachadas.json`, el mismo archivo que lee el juego en `juego/modelos/fachadas.gd`; cambiarlo no pide `make edificios`) + los semáforos y árboles de vereda de OSM alrededor de la plaza, del plano del juego (`data/plaza-osm.json`, de `tools/juego_osm.py`, como `DATA.plaza`, que lee `hitos/calles-plaza.js`) + `data/golf.json` (como `DATA.golf`: el pasto y las copas del Talca Country Club, que lee su hito; `golf.py`, de la imagen de Esri) + `data/cobertura.json` (como `DATA.cob`, si está) + pois (`PD`): cada uno en su archivo de `dist/assets/`, con un hash de su contenido en el nombre, que la página pide con `fetch` (los nombres van en el marcador `/*DATA*/` de `src/page.html`). El script los espera al comenzar (`00-start.js`) y arma `DATA`.

## Comandos

```bash
make pois build                 # tras editar pipeline/pois.py
make data build                 # tras editar config/trazados.json o process_geometry.py (requiere raw/)
make elevation build            # tras editar elevation.py (requiere raw/dem/copernicus/; no necesita las otras fuentes)
python pipeline/elevation.py stats   # además, cuánto quita el filtro por zonas (--srtm: con el SRTM de antes, para comparar; escribe data/elevation.json)
python -I pipeline/geotiff.py info raw/dem/copernicus/<tesela>.tif   # tamaño, bloques, compresión y georreferencia de un GeoTIFF de elevación (`punto <lat> <lon>`: un valor)
uv run --with pillow python tools/relieve.py antes.json data/elevation.json [--png x.png]   # qué mueve un cambio del relieve: alturas sobre la plaza por zona, matorral, puntos de referencia
make golf build                 # data/golf.json: el pasto y las copas del club de golf, de la imagen de Esri (pipeline/golf.py; requiere internet la primera vez)
make osm                        # la API map de OSM sobre toda la comuna -> raw/osm/map-comuna.json (caminos rurales, Ruta 5, vía; la usa make data)
make validate                   # distancia entre cada lugar y su dirección en la grilla (requiere raw/)
python pipeline/satellite.py plaza-de-armas [500]   # manzanas sobre imagen satelital, en diagnostics/
python pipeline/satellite.py punto 3755 1414 [900] [17] --calles   # caja en (x, y) de grilla, con calles, cruces cada 100 m y usos
python pipeline/satellite.py marco -4 2120 75.3 -135 105 -250 -70 19 sur   # la imagen en el marco local de un hito (X Y A u0 u1 v0 v1 [z] [nombre]: landmark.py frame), girada, con cruces cada 10 m en (u,v): así se leyó el Cementerio; `punto … --rejilla[=N]` pone cruces de grilla cada N m
uv run --with pillow python pipeline/golf.py [panel]   # el pasto cortado y las copas del Talca Country Club desde la imagen de Esri -> data/golf.json (make golf; `panel`: diagnostics/golf-clases.png)
python pipeline/geocode.py address "2 Norte 781"
python -I pipeline/grilla.py <nav_graph.json|map-*.json> <lat> <lon> [radio ...]   # el giro de la grilla de una ciudad alrededor de su plaza (METODOLOGIA §3; otra comuna: docs/PLAN-COMUNAS.md)
python pipeline/diagnostics.py centro          # panel PNG en diagnostics/
python pipeline/satellite.py punto 3755 1414 600 18 --fecha        # además, la fecha, el sensor y la resolución de la imagen dibujada (y si a z17 hay una más nueva)
python pipeline/satellite.py punto 3755 1414 600 17 --release=2019-01-01   # una publicación anterior de Esri Wayback (id, fecha o `ultima`)
python pipeline/satellite.py historia 0 0 [17]                     # cada versión de la tesela bajo (x, y) en Wayback, con su captura (~40 s)
python pipeline/satellite.py tiempo 2580 3530 -2740 -2220 17 piduco [--todas]   # la caja en cada captura distinta, lado a lado -> diagnostics/tiempo-piduco.png
uv run tools/sentinel.py buscar [--desde 2026-01-01] [--nubes 5]   # escenas Sentinel-2 L2A sobre la comuna (STAC de Element84), con las nubes sobre la comuna
uv run tools/sentinel.py bajar ultima   # la ventana de la comuna de la escena sin nubes más reciente -> raw/satelite/sentinel2/<fecha>/
uv run tools/sentinel.py caja 2580 3530 -2740 -2220 piduco   # color y NDVI de una caja de grilla -> diagnostics/s2-piduco.png
uv run tools/sentinel.py usos   # las entradas de config/usos.json que hoy se ven construidas o peladas (solo lee)
python pipeline/mapillary.py clave           # de dónde se lee la clave de Mapillary (MAPILLARY_TOKEN o ~/.config/mapillary.key) y si responde; sin clave, cómo pedirla
uv run --with pillow python pipeline/mapillary.py cobertura [--caja x0 x1 y0 y1]   # las fotos de Mapillary en la comuna (teselas z14, una vez) -> raw/mapillary/imagenes.json, por año y autor, y el panel diagnostics/mapillary-cobertura.png
python pipeline/mapillary.py lugares [80]     # cada lugar con fotos de Mapillary a menos de 80 m: cuántas lo miran, de cuántas pasadas y la más nueva (las baja landmark.py photos --mapillary)
uv run --with pillow python pipeline/mapillary.py fachada --caja -318 318 -318 318 --saltar @hitos.txt [--nombre centro]   # para medir alto, pisos y color de los edificios de OSM (config/fachadas.json): las fotos que ven cada uno de frente, con su planta, una regla de alturas y el alto del mapa dibujados con la cámara de Mapillary, en hojas -> diagnostics/fachadas/ (con ids: esos edificios; --entera: la foto completa, con los vecinos)
uv run --with pillow python pipeline/mapillary.py punto -0.8 29.7 2.6   # lo mismo para un punto de la grilla (una pila, una estatua): un círculo de r m y una regla vertical
python pipeline/wikidata.py check [--refresh]   # los lugares contra Wikidata: distancias, fechas y protección que la ficha no dice, fotos que FUENTES no cita, candidatos (caché en raw/wikidata/)
python pipeline/traces.py tiles x0 x1 y0 y1 <nombre>                # API map de OSM por cajas (sin Overpass) -> raw/osm/map-<nombre>.json
python pipeline/traces.py tiles-comuna                              # lo mismo sobre toda la comuna -> raw/osm/map-comuna.json (make osm)
python pipeline/gis.py exportar [carpeta] [--wgs84]   # data/ y config/ -> gis/talca.gpkg y gis/talca.qgs (QGIS 3.34 o más), en metros de grilla (WKT2: `gis.py crs`); sin raw/
python pipeline/gis.py importar [gis/talca.gpkg] [--escribir]   # la capa usos editada en QGIS -> config/usos*.json (nuevas al final; las borradas solo se avisan); luego usos.py check y make build
```

## Trampas

- **Medianas de calles.** `geocode.lines()` calcula la mediana de cada calle dentro de 900 m de la plaza. Con una ventana mayor, algunas calles salen corrompidas por tramos lejanos con el mismo nombre, y un lugar geocodificado sobre ellas queda cientos de metros corrido. `config/grid_lines.json` es la versión revisada a mano (hoy el mapa no la lee).
- **Grilla irregular.** La grilla es regular solo en el centro, hasta unas 9–10 cuadras de la plaza. Más afuera las calles se curvan, y cerca de la vía férrea (11–12 Oriente) faltan números.
- **La Alameda (4 Norte).** Es una avenida con parque central de unos 70 m. Las direcciones sobre ella necesitan `side_off` de 45–95 m, no 14.
- **La imagen satelital puede ser vieja.** Las teselas de Esri que usa `satellite.py` sirven para plantas y manzanas, pero pueden tener años, y no son las mismas en todos los zooms. En la ciudad (el 40 % de la comuna), z18 y z19 son del 31 de marzo de 2015 (WorldView-3, 0,31 m) y z17 o menos del 6 de abril de 2020 (WorldView-2, 0,5 m); el campo es de 2024 a 2026. `satellite.py` usa z18 (`marco`, z19), `edificios.py techos 19` y `golf.py` z19: en la ciudad, 2015; `edificios.py panel … 17`, 2020. Así, el Estadio Fiscal de z18 es anterior a las cubiertas de 2017, y las notas de `config/usos.json` que dicen «en obras» describen la de z17. `--fecha` dice de cuándo es lo dibujado; `historia` y `tiempo` muestran las versiones anteriores (Esri Wayback), y `tools/sentinel.py` (Sentinel-2, 10 m) lo que hay hoy, sin detalle. Para alturas, techos y colores de un hito, contrasta con fotos recientes (Wikimedia Commons; la etiqueta `wikimedia_commons` de OSM lleva a la categoría). Las huellas de Microsoft y Google son posteriores: las villas que la imagen muestra como potreros ya tienen sus casas.
- **Overpass puede no responder.** Sus tres servidores pueden dar error por carga a la vez. La API de OSM entrega un objeto entero sin límite de caja: `api/0.6/way/<id>/full.json` o `relation/<id>/full.json` (así se bajan los ríos). Para un área, cajas de la API `map` de menos de 0,25 grados² y 50 mil nodos.
- **La búsqueda por caja de Mapillary pierde fotos.** `graph.mapillary.com/images?bbox=…` devuelve menos que su `limit` aunque haya más, sin aviso ni paginación: 1817 de 2225 a 250 m de la plaza, 2000 de 14.185 a 700 m, y partir la caja no lo arregla. Las teselas vectoriales (`mly1_computed_public`, capa `image` a z14) tienen todas: `mapillary.py` elige de ellas y pide a la API solo lo de las elegidas (`image_ids`). Use `computed_compass_angle` (el `compass_angle` de las teselas computadas lo es), no el `compass_angle` de la API: el de la cámara suele errar en 100° o más.
- **La posición de una foto de Mapillary puede errar 10 m.** En algunas pasadas de 2018 la posición computada queda hasta ~10 m de donde se tomó la foto (una cámara que andaba por 1 Oriente queda dentro de la Plaza de Armas), y el rumbo unos grados (las cámaras delanteras, ~3° a la izquierda de la marcha); el cabeceo sí calza. Lo que `mapillary.py fachada` y `punto` dibujan con esa cámara puede caer corrido o sobre el vecino, y la escala de su regla errar un 30–40 %: un alto se mide por los pisos y, de frente, por la proporción con el largo del lado de OSM; la regla solo lo comprueba. Y casi todas las fotos de la ciudad son de febrero de 2018: un edificio posterior no aparece.
- **El relieve es de superficie.** Copernicus GLO-30 mide techos y árboles: la ciudad queda ~1,5 m más alta que el terreno desnudo. `elevation.py` los quita con una apertura morfológica; si se cambia la fuente, revisa `python pipeline/elevation.py stats` y compara con `tools/relieve.py`. Sus cuerpos de agua sí vienen aplanados. Las alturas son relativas al nodo de la plaza: un cambio de fuente que la mueva respecto de su entorno (una que mida las copas de la plaza la sube) sube o baja toda la maqueta en la exageración de `relief()`, y con ella las explanadas y los puentes; los hitos se apoyan en `E()` y se mueven solos, pero hay que mirarlos de cerca. No cambie el nodo de la plaza por la mediana de su entorno: con el terreno desnudo de FABDEM la plaza queda a menos de 1 m de los anillos de 100 m a 1 km, como con Copernicus, así que la ciudad que sube hacia el oriente (+6–7 m a 2–3 km) es el terreno real. Un terreno desnudo (FABDEM) no necesitaría la apertura, pero su licencia es CC BY-NC-SA.
