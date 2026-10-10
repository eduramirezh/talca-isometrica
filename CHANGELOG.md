# Cambios

## Sin publicar

- **Catedral, nuevo modelo.** Sigue la planta de OpenStreetMap: nave con naves laterales, crucero, ábside segmentado al poniente, baptisterio redondo junto a la fachada, sacristía y la torre en la esquina de 1 Norte con 1 Poniente, con la escalinata delante. El modelo anterior era una caja con una torre centrada en la nave. Alturas, colores y fachadas salen de fotos de 2017 a 2024 en Wikimedia Commons, medidas con el ancho de la torre como escala (OSM dice 17 m para la torre; mide ~39): frontis blanco de 20 m con tres arcos, vitrales y puertas; torre de ladrillo con pilastras y bandas blancas, retranqueo, balaustrada, campanario blanco y aguja verde; nave de ladrillo con ventanas altas entre pilastras y techos de teja. De noche se encienden los vitrales de la fachada.
- **docs/ESTETICA.md**: los criterios visuales de los hitos rehechos (escala de trabajo, lenguaje de pixel art, paleta común, techos, noche y una lista de revisión).
- `localFrame()` en la plantilla: el marco local de un hito, compartido por el Estadio y la Catedral.
- **Estadio Fiscal, nuevo modelo.** El modelo anterior estaba centrado en el punto de la dirección (Alameda 251), que cae en el borde oriente del recinto: quedaba unos 100 m al oriente del estadio real y montado sobre 5 Norte. El nuevo sigue la planta de OpenStreetMap: cancha de 105 × 67 m girada como la real, pista atlética de 8 carriles, graderías escalonadas en curva (sur, oriente y una norte más baja) bajo la cubierta de membrana que desde las obras de 2017 techa la galería oriente y ambas cabeceras, tribuna poniente techada, las cuatro torres de iluminación (encendidas de noche), las tres entradas del sector sur y la cancha de hockey junto a la Alameda. Los detalles (cubiertas, asientos rojos con filas negras en las curvas, escaleras amarillas, torres) se contrastaron con fotos de 2021 a 2025 en Wikimedia Commons y con la descripción de las obras en StadiumDB; la imagen satelital de Esri es anterior a 2017 y no muestra las cubiertas. Es el primer modelo con estética de pixel art: filas en dos tonos, pasillos, franjas de corte en el pasto y líneas más anchas que las reales para que se lean a 1 m por píxel.
- Los modelos que no deben llevar ventanas procedurales (las contrahuellas de una gradería son caras verticales) se construyen en un segundo constructor sin ese sombreador.
- Dentro del recinto deportivo cercado (estadio, piscina, canchas) ya no se generan casas.
- **`pipeline/landmark.py`**: insumos para rehacer un hito. `osm` baja la planta de OpenStreetMap y dibuja un plano contra las calles del mapa; `frame` pasa las vías al marco local del modelo; `photos` baja fotos de Wikimedia Commons ordenadas por fecha. El procedimiento está en docs/METODOLOGIA.md §9.

- **Manzanas construidas que aparecían como parque.** El Censo marca «sin información» las manzanas sin viviendas, y la maqueta las pintaba todas como parque. Se revisaron contra la imagen satelital las del centro: ocho están construidas y ahora tienen edificios. Entre ellas, la manzana frente a la Plaza de Armas (1 Sur, entre 1 Poniente y 1 Oriente), el Mercado Central, las Escuelas Concentradas y el Liceo Abate Molina. La lista, con su nota, está en `config/manzanas.json`.

## 1.2 — 2026-10-10 · Relieve

- **Relieve real.** La maqueta deja de ser plana: usa el modelo de elevación SRTM (`pipeline/elevation.py` → `data/elevation.json`). Aparecen los cerros del poniente, al otro lado del Río Claro (hasta ~370 m), y las terrazas de la ciudad hacia el Claro, el Lircay y el Piduco.
  - La exageración es logarítmica: ×3 en el plano y ×1,3 en los cerros.
  - Calles, manzanas, ríos, edificios, árboles y faroles se apoyan en el terreno. Los hitos grandes nivelan una explanada.
  - Las laderas empinadas son matorral y bosque en vez de parcelas.
- **Cerro La Virgen.** Se elimina el cerro inventado y achatado. La estatua queda sobre el terreno real, en la ubicación del santuario. La ficha distingue el santuario (~270 m) del Peñón (372 m), que es el punto más alto de la comuna.
- **Lector.** Muestra la altura real sobre el nivel del mar del punto bajo el cursor.
- **Cámara.** El giro de la vista y el vuelo a un lugar toman en cuenta la altura del terreno.
- `make fetch` baja además la tesela SRTM (~12 MB); `make elevation` regenera el relieve sin necesitar las otras fuentes.

## 1.1 — 2026-10-10 · Exportación a proyecto

- **Proyecto reproducible.**
  - Se reorganizaron los scripts en un pipeline con rutas relativas: `pipeline/`, `config/`, `Makefile`.
  - `fetch_sources.sh` descarga solo lo necesario.
  - `process_geometry.py` reproduce exactamente la geometría de la versión 1.0.
- **Trazados editables.** Ríos, ferrocarril y Ruta 5 pasaron de estar en el código a `config/trazados.json`, con su procedencia.
- **Nuevas herramientas.**
  - `geocode.py`: geocodificador de la numeración de Talca y validador de lugares.
  - `diagnostics.py`: paneles de revisión.
  - `tools/screenshot.py`: capturas sin conexión.
  - `data/pois.csv`: catálogo de lugares en tabla.
- **Corrección.** Universidad Autónoma, sede Talca (5 Poniente 1670): pasa de −71,67597 a −71,67132. Estaba unos 420 m al poniente, porque la mediana de «5 Poniente» se había calculado con una ventana de 2,5 km, que incluía tramos lejanos con el mismo nombre. Ahora queda junto al Estadio, como indican las fuentes.
- **Documentación.** README, CLAUDE.md, METODOLOGIA, FUENTES y PROYECTOS-SIMILARES.

## 1.0 — 2026-09-27

- Primera versión publicada como artifact en Claude.
