# Talca Isométrica

Maqueta isométrica interactiva de Talca (Región del Maule, Chile) que destaca los lugares del ámbito jurídico (tribunales, fiscalías, defensorías, notarías, registros, academia y la historia legal de la ciudad) junto a sus hitos urbanos. Está hecha sobre datos reales: las 3.456 manzanas del Censo 2017 y la red vial de OpenStreetMap.

![Vista del barrio judicial de la Alameda](docs/img/barrio-judicial.jpg)

- **52 lugares** en 8 categorías, cada uno con dirección, coordenadas, fuente y nivel de confianza.
- **Dos recorridos guiados:** la Ruta de la Justicia y Talca icónica.
- **~72.000 edificios** generados en el navegador frente a cada calle real, con alturas según la densidad del censo y 19 hitos con modelo propio.
- **Relieve real** del modelo de elevación SRTM: los cerros del poniente y las terrazas de la ciudad hacia sus ríos, con exageración logarítmica. El lector muestra la altura sobre el nivel del mar.
- **Lector de direcciones:** al pasar el cursor muestra la dirección aproximada según la grilla numerada («1 Norte ≈ 850, entre 1 y 2 Oriente»).
- **Vistas:** modo noche, giro de la vista en 90°, modo pixel, tema claro y oscuro, y diseño para móvil.
- **Un solo archivo HTML** autocontenido (~820 KB). Solo carga three.js desde cdnjs y las fuentes de Google Fonts.

## Inicio rápido

No hace falta descargar nada para ver o modificar la página: los datos procesados ya están en `data/`.

```bash
make build          # -> dist/index.html (página completa) y dist/talca.html (fragmento para Claude)
make serve          # sirve en http://localhost:8765 y lo abre en el navegador
```

Para regenerar todo desde las fuentes originales:

```bash
make fetch          # descarga manzanas del Censo, grafo vial OSM y elevación SRTM a raw/ (~72 MB, requiere git y curl)
make all            # geometría -> lugares -> HTML
make validate       # compara cada lugar con su dirección en la grilla
```

Requisitos: Python 3.9+ (el pipeline usa solo la biblioteca estándar). Opcionales:

- `pip install -r requirements.txt` para los paneles de diagnóstico y las capturas.
- `python -m playwright install chromium` y `npm install` para las capturas sin conexión.

## Estructura

```
config/
  grid_lines.json        posición de cada calle numerada (lector de direcciones)
  manzanas.json          manzanas «sin información» del Censo que están construidas (revisadas en imagen satelital)
  trazados.json          ríos, vía férrea y Ruta 5 dibujados a mano, con su procedencia
pipeline/
  common.py              rutas y proyección (origen en la Plaza de Armas, grilla girada 5°)
  fetch_sources.sh       descarga las fuentes a raw/
  process_geometry.py    manzanas + calles + trazados -> data/geometry.json
  elevation.py           elevación SRTM -> data/elevation.json
  pois.py                catálogo de lugares y recorridos -> data/pois.json + pois.csv
  geocode.py             geocodificador de la numeración de Talca y validador
  build.py               plantilla + datos -> dist/
  diagnostics.py         paneles PNG para revisar trazados contra las manzanas
  satellite.py           imagen satelital con las manzanas encima (qué hay de verdad en cada una)
  landmark.py            insumos para modelar un hito: planta OSM, marco local, fotos de Commons
src/template.html        toda la aplicación: CSS, UI y motor three.js (r128)
data/                    datos procesados (versionados)
dist/                    resultado: talca.html (fragmento) e index.html (página completa)
tools/screenshot.py      capturas con Chromium sin interfaz
docs/                    metodología, fuentes, investigación de proyectos similares
```

## Documentación

- [docs/METODOLOGIA.md](docs/METODOLOGIA.md): cómo se construyó, paso a paso, con las decisiones y lo que es aproximado.
- [docs/ESTETICA.md](docs/ESTETICA.md): criterios visuales de los hitos hechos a mano (pixel art, paleta, revisión).
- [docs/FUENTES.md](docs/FUENTES.md): fuentes de datos, licencias y atribuciones.
- [docs/PROYECTOS-SIMILARES.md](docs/PROYECTOS-SIMILARES.md): Isopolis, Isometric NYC y las ideas que se tomaron de ellos.
- [CLAUDE.md](CLAUDE.md): guía para seguir trabajando con Claude Code (arquitectura, convenciones, trampas conocidas).
- [CHANGELOG.md](CHANGELOG.md): cambios.

## Licencias y atribución

- **Datos de calles:** © colaboradores de OpenStreetMap, bajo licencia ODbL. Cualquier publicación debe mantener la atribución (ya incluida en la pestaña «Acerca»).
- **Manzanas:** Censo de Población y Vivienda 2017, Instituto Nacional de Estadísticas de Chile.
- **Fichas:** los textos son resúmenes propios; cada ficha enlaza su fuente.

Ver [docs/FUENTES.md](docs/FUENTES.md).
