---
paths:
  - "tools/**"
  - ".claude/hooks/**"
---

# Las herramientas de tools/ (Playwright, rendimiento)

Capturas, comparaciones, perfiles y mediciones en el navegador. Cada herramienta documenta su uso en su docstring (`--help`).

## Comandos

```bash
tools/preparar.sh [--revisar]   # un worktree listo: raw/, node_modules/, scripts/deploy/node_modules/ y modelo3d/mapa y datos, enlazados a los de la copia principal; lo corre solo el hook WorktreeCreate de .claude/settings.json (.claude/hooks/worktree-crear.sh: el worktree en .claude/worktrees/<nombre>, rama worktree-<nombre>, desde origin/main), y WorktreeRemove (worktree-quitar.sh) lo quita y borra su rama si ya no lleva nada propio; a mano, en un worktree hecho con git worktree add
uv run --with "playwright==1.63" --with pillow python tools/variants.py shots/hoja.png --view "Plaza=__look(-60,30,14.2)" --variant "Sin pixel art=__pixelArt(null)" --variant "0,75 m=__pixelArt({m:0.75})" --reset "__pixelArt({m:0.5})" --scale 1   # vistas x variantes en una hoja
uv run --with "playwright==1.63" --with pillow python tools/variants.py shots/d.png --size 390x844 --dpr 2 --clip 0,0,390,844 --view "z4=__look(-60,30,4)" --variant "Antes=__pixelArt({m:0.5,crease:'normals'})" --variant "Ahora=" --diff   # % de píxeles distintos y columna Δ
uv run --with "playwright==1.63" python tools/perf.py [--size 1440x900 --dpr 1] [--view "nombre=__look(x,y,z)"]   # ms, llamadas, triángulos y ms de CPU de un cuadro (refit, pan, settle) y ms entre cuadros al arrastrar (gesto); teléfono por omisión
uv run --with "playwright==1.63" python tools/perf.py --android   # lo mismo en el Chrome de un teléfono Android conectado por USB (adb, depuración USB)
uv run --with "playwright==1.63" python tools/perf.py --android --arranque 3   # solo el arranque (__stats.load: ms desde la navegación hasta el primer cuadro en pantalla), tres cargas y la mediana; también la de las fases (__stats.t, edDecode). Un --port distinto para cada versión: con el mismo, el Chrome del teléfono reusa el index.html de su caché
uv run --with "playwright==1.63" python tools/perf.py --android --arranque 3 --url https://talca.eduramirez.com/   # el sitio publicado (o una publicación anterior: scripts/deploy/node_modules/.bin/wrangler pages deployment list --project-name talca-isometrica) por la red del teléfono
uv run --with "playwright==1.63" python tools/perf.py --arranque 3 --red lenta --frio   # el arranque en Chromium con una red móvil emulada (lenta: 150 ms, 1,6 Mbit/s; 4g), cada carga sin caché (sin --frio, recargando); TALCA_DIST=<copia de dist/> mide otra versión
uv run --with "playwright==1.63" python tools/profile.py --android [--under cityGen] [--callers pip --depth 2] [--save x.cpuprofile]   # perfil de CPU del arranque: ms por función, con su archivo y línea de src/
python tools/profile.py --from x.cpuprofile --callers blockAt   # lo mismo sobre un perfil guardado, sin cargar la página
uv run --with "playwright==1.63" python tools/heap.py [--vivo] [--top 40]   # el montón de JS por fase (window.__mem), su pico, lo que queda tras un GC y los MB que asigna (o con --vivo, retiene) cada función de src/
uv run --with "playwright==1.63" python tools/profile.py --etapa 2 --tareas 8 [--gesto]   # en Chromium (una carga en frío): solo la segunda etapa (--etapa 1: antes del primer cuadro) y sus tareas de más de 8 ms, con la parte de rest() de cada una; --gesto arrastra el mapa mientras tanto
uv run --with "playwright==1.63" --with pillow python tools/regress.py --save shots/ref --view "terminal=__look(1722,-262,16)"   # más vistas (repetible: --save y --against las llevan igual), p. ej. las de un hito nuevo; con --init "window.__STAGE=0" comprueba el arranque en dos etapas
```

## Verificar en el navegador

`tools/screenshot.py` (después de `make check`, como dice CLAUDE.md) imprime las estadísticas de generación y los errores de consola, y sale con 1 si hubo errores (como todas las de `tools/`). Las herramientas de Playwright comparten `tools/page.py` (`Map`: abre Chromium, sirve `dist/` y espera; cada vista o `--js` espera a que el mapa quede quieto con `window.__idle()`, no un plazo fijo; `--size --dpr --gl --init` iguales en todas, `--gl gpu` usa la GPU del equipo (`metal` en un Mac, ~6 veces más rápido; en Linux `nvidia` si está su driver y si no `egl`: un cuadro de la comuna tarda 15–70 ms en vez de ~5 s con SwiftShader, pero la carga, ~14 s, es de la CPU), y `regress.py`/`hitos.py` se comparan siempre con referencias del mismo `--gl`; `TALCA_ESPERA=<s>` alarga la espera de la carga); una herramienta nueva la usa en vez de abrir el navegador a mano. Cada una lleva sus dependencias en un encabezado PEP 723: `uv run tools/screenshot.py …` basta. Una vista de escritorio y una de móvil suelen bastar; con `--view nombre=expresión` (repetible) se toman varias de una sola carga, que es lo que cuesta (~1 min con SwiftShader). Si el Python del sistema no tiene Playwright (o Pillow para `satellite.py`), `uv run tools/screenshot.py …` (o `uv run --with "playwright==1.63" python tools/screenshot.py …`) funciona sin instalar nada: el Chromium de la caché de Playwright (`~/Library/Caches/ms-playwright/chromium_headless_shell-1243` en el Mac, `~/.cache/ms-playwright/…` en Linux) es el de la 1.63; una versión más nueva pide otro navegador y falla con «Executable doesn't exist».

## Trampas

- **Navegadores sin GPU.** En Chromium sin GPU (las capturas) hay que usar SwiftShader; ver `GL` en `tools/page.py`.
- **Rotar en `--js`.** El giro es animado: dos clics seguidos en `#rr` giran una sola vez, y una rueda del mouse cancela el giro en curso. Espere ~2 s entre clics (`--js` acepta una expresión async, que se espera). La cámara inicial mira desde el sureste: una fachada al poniente necesita dos o tres giros.
- **`__look` no limita el zoom.** `clampView()` deja el zoom en 26, pero `__look(x, y, 70)` sirve para inspeccionar un modelo chico (un coche de 3 m) con `__pixelArt(null)`: píxeles de 5 cm.
