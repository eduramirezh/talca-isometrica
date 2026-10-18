# Plan: el sitio sin las restricciones del artifact

Plan de octubre de 2026. Hasta entonces un solo archivo, `dist/talca.html`, servía para dos cosas: el artifact de Claude y, con su `<head>`, el sitio publicado (`dist/index.html`, talca.eduramirez.com). Por eso el sitio cargaba con todas las restricciones del artifact. **El artifact se quitó** (el 18 de octubre de 2026): el producto es el sitio, y el artifact fue solo el punto de partida. Este plan dice qué se hizo al levantar las restricciones y qué sigue.

## 1. Cómo estaba

- **Un fragmento, dos destinos.** `pipeline/build.py` unía `src/` en un fragmento HTML con los datos incrustados (`/*DATA*/`, `/*POIS*/`) y escribía `dist/talca.html` (el artifact) y `dist/index.html` (el mismo fragmento con `STANDALONE`, el póster y los archivos de `src/site/`). `tools/check.py` revisaba las restricciones del artifact sobre los dos.
- **Tamaño.** `dist/index.html` pesaba 2,5 MB (756 KB con gzip), lejos de los 16 MB. **El límite de tamaño no era lo que apretaba.** Lo que apretaba era lo demás:
  - **sin `fetch`**: todos los datos iban incrustados como un literal de JavaScript dentro del HTML, que el navegador tenía que leer entero antes de correr nada, y cualquier cambio de código invalidaba la caché de los datos (y al revés);
  - **scripts solo de cdnjs, jsdelivr o unpkg**: three.js r128 desde cdnjs, en otra conexión; desde r160 three.js no tiene versión UMD, así que actualizarlo pide módulos;
  - **un solo `<script>` en línea**: `build.py` concatena `src/js/*.js` en un solo ámbito (trampa «Un solo script en muchos archivos»), sin módulos ni minificación; en línea, además, el navegador no lo compila en segundo plano ni guarda su código compilado entre visitas;
  - **todo se genera en el navegador**, en el hilo principal: 7,5 s en un Pixel 8a, 3,8 s en un Mac; el arranque en dos etapas adelanta el primer cuadro, pero la segunda etapa mueve el mapa a tirones.
- **El relieve.** `data/elevation.json` es una grilla de 40 m (519 × 597 nodos), filtrada desde el SRTM de 30 m sobre una grilla de trabajo de 20 m (`elevation.py`, `FINE`). Varias trampas vienen de esos 40 m: la Ruta 5 no puede ir en trinchera, los pasos bajo la vía suben la vía en vez de bajar la calle, y dos explanadas a menos de 80 m comparten nodos.

## 2. Hecho: una salida, con los datos y los scripts aparte

- **Sin artifact.** `build.py` arma solo el sitio. `src/page.html` es el documento entero, con el `<head>` que antes ponía `STANDALONE`, y el póster va escrito en él. `tools/check.py` ya no revisa las restricciones del artifact; en su lugar revisa que cada archivo que pide la página esté en `dist/` y que `dist/assets/` no tenga sobrantes.
- **Los datos, en archivos.** Un archivo por fuente (`geometry` con los usos de suelo, `elevation`, `ruta5`, `edificios`, `golf`, `pois`), en `dist/assets/` con un hash de su contenido en el nombre. El `<head>` los pide con `fetch` antes que nada (`window.__data`), así que bajan mientras llegan three.js y el script, y `00-start.js` los espera (la función que envuelve el script es `async`) y arma `DATA` y `PD` como antes: nada más en `src/js/` cambió.
- **El script, en su archivo** (`assets/app.<hash>.js`). Chrome compila en segundo plano un script externo mientras baja y guarda su código compilado para la visita siguiente; con uno en línea no hace ninguna de las dos cosas. `build.py --where app.<hash>.js:N` traduce sus líneas, y `tools/profile.py` también.
- **three.js del mismo origen** (`assets/three-r128.<hash>.js`, copiado de `node_modules`): sin la conexión aparte a cdnjs. `make build` necesita `npm install`.
- **Caché.** `src/site/_headers` le dice a Cloudflare Pages que `assets/*` no cambia nunca (`immutable`, un año): una publicación que toca el código no vuelve a bajar los ~1,9 MB de datos ni three.js. `index.html` (26 KB) se revalida en cada visita.
- **Las herramientas** sirven `dist/` en un puerto local (`serve()` de `tools/screenshot.py`; `fetch` no funciona desde `file://`), y `TALCA_DIST=<directorio>` sirve otro, para comparar con una copia de antes de un cambio.
- **El mismo mapa.** `tools/regress.py --against`: las 14 vistas, idénticas píxel a píxel, y las mismas estadísticas.
- **El póster primero.** Con los datos y los scripts pedidos desde el `<head>`, en una red lenta le quitaban el ancho de banda al póster, que llegaba después del mapa (9,5 s en vez de 4,7 s). Ahora se piden cuando el póster llegó (`window.__go`; sin póster, de inmediato), y `build.py` agrega los dos scripts desde JS en ese momento.
- **Lo que se midió** (§4): en una red móvil lenta y sin caché, el póster aparece a los 2,5 s en vez de 4,7 s y el primer cuadro llega igual (~8,8 s); al recargar, igual que antes. En local, sin red, no hay diferencia medible. Lo que más cambia no se ve en una carga: después de una publicación que toca solo el código se bajan ~215 KB (el script) en vez de ~750 KB (la página entera con los datos), y una que toca un dato baja solo ese archivo. Queda por medir en el teléfono, publicado (§3.0).

### Lo que no se hizo, y por qué

- **Datos binarios** (la etapa 3.2 del plan anterior): `JSON.parse` de los seis archivos tarda ~7 ms en total en un Mac (node; elevation, 2 ms), y comprimidos pesan ~506 KB con gzip (elevation, 131 KB). Pasarlos a `Int16Array` ahorraría unos ms de análisis y poco de descarga, a cambio de un formato propio en el pipeline y en la página. No vale la pena ahora; se vuelve a mirar si el relieve se hace más fino (§3.6).
- **Partir los datos por zonas** (lo que la primera vista no usa, pedido durante `rest()`): con la caché de `assets/`, solo cuenta en la primera visita, y casi todos los datos los lee la etapa 0 (`edificiosPlan`, `usosPlan`, el relieve entero). Medir en el teléfono antes.

## 3. Lo que sigue

Cada etapa se puede publicar sola y deja el mapa idéntico, píxel a píxel, salvo 3.4 y 3.5. Antes de cada una: `tools/regress.py --save`; después, `--against`, y `tools/perf.py --android --arranque 3` antes y después.

### 3.0 Medir en el teléfono, ya publicado

`tools/perf.py --android --arranque 3` contra la versión de antes (8,4 s hasta el primer cuadro en el Pixel 8a con la página servida por USB) y, sobre todo, en una red móvil de verdad y en una segunda visita (con `assets/` en caché). Agregar un iPhone (depuración de Safari) y un Android de gama baja, que faltan (CLAUDE.md, «Rendimiento»).

### 3.1 Las fuentes, del mismo origen

Las fuentes de Google son lo único que queda de otro origen: una hoja de estilos que bloquea el primer pintado (también el del póster) y dos conexiones más (fonts.googleapis.com y fonts.gstatic.com). Servir los `woff2` desde `assets/` (Alegreya SC, Alegreya Sans e IBM Plex Mono, con licencia OFL; solo los pesos y el subconjunto latino que se usan) con `@font-face` en `style.css` y `font-display: swap`. Una herramienta en `tools/` que los baje una vez y los deje en `src/site/fonts/`. Ganancia: el póster y el panel se pintan sin esperar a otro servidor.

### 3.2 Empaquetador y módulos

- esbuild (con `npx`, como ya se usa Wrangler) en vez de concatenar. Primer paso sin cambiar el código: el resultado de `script()` minificado, con mapa de fuentes (`app.<hash>.js.map`); `build.py --where` y `tools/profile.py` pasan a leer el mapa.
- Después, sección por sección, `src/js/NN-*.js` pasan a ser módulos con `import`/`export`. Los hitos se quedan como están: son trozos del cuerpo de `buildModels` que comparten sus variables locales (`C`, `at`, `reserve`, `palmS`…), y volverlos módulos es un trabajo aparte.
- Ganancia: desaparece la trampa «Un solo script en muchos archivos», hay errores por archivo y el script baja de ~580 KB (~180 KB con brotli, mucho de ello comentarios: medir cuánto queda minificado). Es requisito de 3.5.

### 3.3 La segunda etapa en un Worker

- Lo que hoy hace `rest()` en tajadas entre cuadros (`sliced()`) pasa a un Worker. Los constructores (`GB`) ya escriben arreglos tipados (posición Float32, normal Int8, color Uint8): el Worker los transfiere sin copiar y el hilo principal solo crea las mallas (`tiledParts`, `canon()`).
- Se descartó en octubre de 2026 (CLAUDE.md, «Rendimiento»): no adelanta el primer cuadro, la CPU total es la misma y crear y subir las mallas sigue en el hilo principal. Vuelve a tener sentido solo si el teléfono muestra tirones de la segunda etapa que las tajadas no resuelven (`tools/profile.py --android --tareas 8 --gesto`).
- Primero, revisar qué funciones de la generación tocan `T` (three.js) o el DOM. Requisito: el mapa terminado igual, píxel a píxel (trampa «El arranque en dos etapas»).

### 3.4 La primera vista generada al armar

- La generación es determinista (`rng` con semilla). Al armar el sitio, Chromium sin interfaz (como `tools/screenshot.py`) carga la página, corre la etapa 0 y la primera, y guarda los arreglos de los constructores de la caja de `STAGE` en `dist/assets/stage-*.bin`, junto con el estado que la segunda etapa lee (`occ`, `LOTS`, `PT`). No hace falta reescribir el generador en otro lenguaje.
- El sitio carga esos arreglos y dibuja; la segunda etapa sigue en el navegador. Si falta un archivo o su hash no calza con el de los datos, genera como hoy.
- Costos: un paso más en `make build` (alrededor de un minuto con SwiftShader, como `make smoke`), más descarga en la primera visita (medir: puede ser más lento que generar en un teléfono con mala red), y el estado que lee la segunda etapa tiene que poder guardarse y leerse. El de `occ` (un `Grid` en bloques) es el más delicado. Con el póster, el primer cuadro ya no es lo primero que se ve: medir si vale la pena después de 3.0.
- `tools/regress.py --against` con el arranque normal como referencia: la imagen tiene que ser idéntica.

### 3.5 three.js nuevo

- Después de 3.2. Lo que da: `BatchedMesh` (muchas mallas en una llamada; hoy son ~1.000 llamadas en la vista de la comuna), recorte de `InstancedMesh` por su esfera (r128 nunca los recorta: `instTiled` lo resuelve a mano) y el renderizador de WebGPU, más adelante.
- Lo que cuesta: el manejo del color y las luces cambió en r152 (todas las capturas de referencia quedan viejas y la paleta hay que reajustarla a ojo contra ESTETICA.md), `winMat()` reemplaza trozos del sombreador con `onBeforeCompile` (`#include <tonemapping_fragment>`, `#include <project_vertex>`) que cambiaron, y `treeGeo()` supone que `IcosahedronGeometry` viene sin índice.
- Plan propio cuando llegue: es la etapa que más cambia la imagen.

### 3.6 Relieve más fino (exploratorio)

- El SRTM es de 30 m: una grilla de 20 m es lo más fino que sale de los datos actuales (`elevation.py` ya trabaja a 20 m). Más fino pide otra fuente (ALOS PALSAR a 12,5 m o un modelo nacional) y otra revisión del filtro de techos y árboles (trampa «El SRTM es de superficie»).
- Lo que se busca no es más detalle del terreno, sino poder **tallar** en él: la trinchera de la Ruta 5 bajo los pasos superiores, las calles que bajan bajo la vía, explanadas vecinas sin compartir nodos. Eso se logra mejor con una grilla de 20 m más cortes a lo largo de trazados conocidos (la Ruta 5, los `railx` tipo 0) que con una grilla fina en toda la comuna.
- Costos: con 20 m son 1,24 millones de nodos (cuatro veces más): cada recorrido de nodos (trampa «Lo que recorre todos los nodos del relieve») y cada `drape()` cortan cuatro veces más; `sampleTri()` y `terrainMesh()` tienen que seguir coincidiendo. El JSON del relieve pasaría de 0,7 a ~3 MB: ahí sí conviene un binario. Medir primero, con un `elevation.json` de 20 m, cuánto crecen la generación y los triángulos.

### Otras cosas que el artifact no dejaba

- **Una postal PNG de la vista actual** (Ideas pendientes de CLAUDE.md): el artifact no dejaba que la página iniciara descargas; el sitio sí.
- **Enlaces con estado**: el artifact solo aceptaba `#id` en la dirección; el sitio puede guardar la vista (`#v=x,y,zoom,giro`) o la noche en el enlace, para compartir una vista exacta.

## 4. Mediciones

Chromium con SwiftShader en un Mac, `dist/` servido en local, 1440 × 900, la mediana de tres cargas (`TALCA_DIST=<copia de antes> tools/perf.py --arranque 3 --size 1440x900 --dpr 1`); ms desde la navegación.

Chromium con SwiftShader en un Mac, 390 × 844 y densidad 2, `--red lenta` (150 ms de ida y vuelta, 1,6 Mbit/s), `dist/` servido en local como lo sirve Cloudflare (gzip; Cloudflare usa brotli, ~15 % menos) por HTTP/1.1. Mediana de tres cargas, ms desde la navegación; el 18 de octubre de 2026, con dos procesos del sistema ocupando ~2 núcleos (los ms varían ±0,5 s entre cargas).

| | antes (artifact + sitio) | ahora |
|---|---|---|
| sin caché (`--frio`): póster | 4.724 | 2.532 |
| sin caché: datos y script listos | 6.672 (llega el HTML) | 7.122 |
| sin caché: primer cuadro (`frame`) | 8.954 | 8.750 |
| sin caché: todo (`full`) | 12.314 | 12.057 |
| recarga: póster | 824 | 940 |
| recarga: primer cuadro | 2.258 | 2.361 |
| bytes de la primera visita (comprimidos) | 750 KB de página + 118 KB de three.js (cdnjs, brotli) | 9 + 215 (script) + 146 (three.js) + 528 (datos) KB, más el póster en los dos |

Sin red (`tools/perf.py --arranque 3 --size 1440x900 --dpr 1`), los dos arrancan igual: el primer cuadro a los ~2,4–2,5 s al recargar, ~4,1 s en frío, la mayor parte en crear el contexto WebGL.

## 5. Preguntas abiertas

- **¿Node en el armado?** Desde este cambio `make build` necesita `node_modules` (three.js); con 3.2 necesitaría también esbuild.
- **¿Cuánto se puede descargar en la primera visita?** 3.4 y 3.6 cambian generación por descarga. Decidirlo con las mediciones del teléfono en una red móvil, no con las del escritorio.
- **¿Herramientas en otro lenguaje?** No hacen falta para este plan: la generación al armar (3.4) usa el mismo código de la página en Chromium. Si un paso del pipeline resulta lento (`make data`, `make edificios`), se mide ese paso antes de pensar en reescribirlo.
