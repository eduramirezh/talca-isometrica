---
paths:
  - "src/page.html"
  - "src/style.css"
  - "src/site/**"
  - "src/js/05-categories.js"
  - "src/js/90-overlay.js"
  - "src/js/92-panel.js"
  - "pipeline/build.py"
  - "tools/site_assets.py"
  - "tools/gif.py"
  - "tools/video.py"
  - "scripts/**"
  - ".githooks/**"
---

# La página y el sitio publicado

El documento, el CSS, el panel y las etiquetas, el póster del arranque y la publicación en Cloudflare Pages.

## Arquitectura

| Archivo (`src/js/`) | Qué hace |
|---|---|
| `05-categories.js` | `CATS`: nombre e ícono SVG por categoría; `LEGAL` lista las capas jurídicas y `CITYCATS` las de la ciudad; `enabled`, las capas encendidas (solo las que tienen botón). `patrimonio` no es una capa: los Monumentos Históricos del CMN y los Inmuebles de Conservación Histórica del PRC de 2011 lo llevan en `cs`, y la ficha lo muestra |
| `90-overlay.js` | marcadores y etiquetas de calles en el DOM, proyectados en cada cuadro; `layout()` evita superposiciones por prioridad, ordena los lugares solo cuando cambia la selección y escribe en el DOM solo lo que cambió (`LAY`). Las calles de la ciudad se rotulan desde el zoom 2,6; las rutas y caminos del campo (`Ruta …`, `Camino …` y la Ruta 115-CH, de troncal a terciaria), cada 3 km y fuera del área urbana, desde 0,45 |
| `92-panel.js` | ficha, recorridos, filtros, búsqueda y enlaces `#id` |

## Comandos

```bash
make site-assets                # src/site/og.jpg (Open Graph, 1200 × 630, desde el mapa), apple-touch-icon.png y los pósters del arranque poster-*.webp (tools/site_assets.py; `poster` hace solo los pósters)
uv run --with "playwright==1.63" --with pillow python tools/gif.py shots/talca.gif [--center 0,0 --zoom 9 --from 2.2 --size 640x400 --turn 32 --night 90 --labels]   # GIF para mostrar el mapa (un correo): se acerca, una vuelta de día, fundido a la noche, medio giro y fundido al comienzo (~2 min)
uv run --with "playwright==1.63" --with pillow python tools/video.py shots/historia.mp4 [--zoom 6 --to 2.6 --speed 36 --stills]   # video vertical para una historia de Instagram (1080x1920, H.264, 18 s, ~2 min con la GPU del Mac): se acerca girando, una vuelta de día, fundido a la noche girando y se aleja; título y dirección del sitio dentro de la zona segura
```

## El sitio publicado (talca.eduramirez.com)

El sitio es `dist/` (no está en git: sale de los fuentes y los datos): `index.html`, chico (~26 KB, con el CSS en línea), y en `assets/` el script, three.js y un archivo por cada fuente de datos, con un hash de su contenido en el nombre; `src/site/` se copia al lado (ícono, `og.jpg`, pósters, `_headers`). En `3d/` va la maqueta en 3D para el navegador (`make web3d`, que `make build` no toca: trampa «La maqueta en el navegador» de `modelo3d.md`); la ficha de cada lugar enlaza a `3d/#<id>` («Ver en 3D»), y «Acerca» la presenta. `_headers` le dice a Cloudflare Pages que guarde `assets/` en la caché del navegador sin vencimiento: un cambio del código no vuelve a bajar los datos ni three.js, y al revés; `index.html` se revalida en cada visita (lo que sigue para el sitio: docs/PLAN-SITIO.md). La página pide sus datos con `fetch`, que no funciona desde `file://`: se abre con `make serve`, y las herramientas de `tools/` sirven `dist/` en un puerto local (`serve()` de `tools/screenshot.py`). `og.jpg`, `apple-touch-icon.png` y los pósters del arranque (`poster-*.webp`) se rehacen con `make site-assets` (la vista de la imagen es `OG_VIEW` en `tools/site_assets.py`) y van en git. La pestaña «Acerca» enlaza a eduramirez.com y al repositorio de GitHub.

Se publica con `make deploy` (`scripts/deploy-cloudflare.sh`: `make build` y `wrangler pages deploy`, con el Wrangler fijo de `scripts/deploy/`, al proyecto `talca-isometrica`, rama `main` = producción; `DRY_RUN=1` arma y lista sin subir; `CF_PAGES_PROJECT` cambia el proyecto). `.githooks/pre-push` (`make hooks`) publica cuando un push a `origin` (GitHub, el repositorio canónico) actualiza `main`, y nunca bloquea el push: si falla, avisa; si el árbol tiene cambios sin commit o HEAD no es el main empujado, no publica. Para saltarlo: `git push --no-verify` o `TALCA_SKIP_DEPLOY=1`.

## Trampas

- **El póster del arranque.** `dist/index.html` muestra una imagen de la vista inicial (`src/site/poster-movil.webp` y `poster-escritorio.webp`, de `tools/site_assets.py poster`) mientras genera la maqueta, con el aviso de carga como una etiqueta encima; `posterOff()` la funde cuando el primer cuadro está en pantalla, y `__stats.load.poster` da cuándo se vio (solo Chromium). Es una captura: si cambia lo que se ve desde la vista inicial (un hito cerca de la plaza, colores, `HOME_ZOOM`, `homeView()`), rehaga los pósters con `make site-assets`, o el arranque mostrará el mapa viejo y saltará al nuevo. Lo coloca el script en línea de `src/page.html` (escalado a la altura del mapa y corrido a la derecha del panel como `homeView()`), no `86-camera.js`, para que se vea antes de que corra el script grande: si cambia cómo `homeView()` centra la plaza, cambie también ese script. No aparece con un enlace a un lugar o un recorrido. Los datos y los scripts se piden recién cuando el póster llegó (`window.__go`, que resuelve ese mismo script; sin póster, de inmediato): si no, en una red lenta le quitan el ancho de banda y el póster sale después del mapa. Por eso `build.py` no pone `<script src>` en `<!--SCRIPTS-->`, sino uno que los agrega cuando resuelve `__go`, y un póster más pesado retrasa todo lo demás.
