# Cambios

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
