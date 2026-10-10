# Cambios

## Sin publicar

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
