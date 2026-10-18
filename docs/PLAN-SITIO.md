# Plan: separar el sitio del artifact

Plan de trabajo de octubre de 2026. **Nada está hecho todavía.** Hoy un solo archivo, `dist/talca.html`, sirve para dos cosas: el artifact de Claude y, con su `<head>`, el sitio publicado (`dist/index.html`, talca.eduramirez.com). Por eso el sitio carga con todas las restricciones del artifact. Este plan las levanta solo para el sitio y deja el artifact como está, una versión liviana que se arma de los mismos fuentes.

## 1. Cómo está hoy

- **Un fragmento, dos destinos.** `pipeline/build.py` une `src/` en un fragmento HTML con los datos incrustados (`/*DATA*/`, `/*POIS*/`) y escribe `dist/talca.html` (el artifact) y `dist/index.html` (el mismo fragmento con `STANDALONE`, el póster y los archivos de `src/site/`). `tools/check.py` revisa las restricciones del artifact sobre los dos.
- **Tamaño.** `dist/index.html` pesa 2,5 MB (756 KB con gzip), lejos de los 16 MB. **El límite de tamaño no es lo que aprieta.** Lo que aprieta es lo demás:
  - **sin `fetch`**: todos los datos van incrustados como un solo JSON dentro del HTML: se descargan, se analizan y se decodifican antes de que corra nada, también los que la primera vista no usa, y cualquier cambio de código invalida la caché de los datos;
  - **scripts solo de cdnjs, jsdelivr o unpkg**: three.js r128 en su versión UMD; desde r160 three.js no tiene UMD, así que actualizarlo pide módulos;
  - **un solo `<script>`**: `build.py` concatena `src/js/*.js` en un solo ámbito (trampa «Un solo script en muchos archivos»), sin módulos ni minificación;
  - **todo se genera en el navegador**, en el hilo principal: 7,5 s en un Pixel 8a, 3,8 s en un Mac; el arranque en dos etapas adelanta el primer cuadro, pero la segunda etapa mueve el mapa a tirones.
- **El relieve.** `data/elevation.json` es una grilla de 40 m (519 × 597 nodos), filtrada desde el SRTM de 30 m sobre una grilla de trabajo de 20 m (`elevation.py`, `FINE`). Varias trampas vienen de esos 40 m: la Ruta 5 no puede ir en trinchera, los pasos bajo la vía suben la vía en vez de bajar la calle, y dos explanadas a menos de 80 m comparten nodos.

## 2. Qué se gana y qué no

| Cambio | Solo posible en el sitio | Gana |
|---|---|---|
| Datos en archivos aparte | sí (`fetch`) | descarga en paralelo con three.js, caché separada del código, binario en vez de JSON |
| Primera vista generada al armar | sí (archivos grandes, `fetch`) | el primer cuadro sin esperar a la generación |
| Generación en un Worker | no necesariamente (ver 3.4) | el mapa no se traba mientras se genera |
| Módulos y un empaquetador | el artifact también, empaquetado en un solo script | ámbitos de verdad, errores por archivo, minificación |
| Relieve más fino | sí, si se carga por partes | trincheras, pasos bajo nivel, explanadas vecinas |
| three.js nuevo | sí, en la práctica (módulos) | `BatchedMesh`, recorte por instancia, WebGPU |

No se gana velocidad al arrastrar el mapa: ya va a 60 cuadros por segundo en el Pixel 8a. Lo lento de lejos (los árboles de toda la comuna) es trabajo de la GPU y se arregla con otro nivel de `setLod`, una decisión de estética, no con este plan.

## 3. Las etapas

Cada etapa se puede publicar sola y deja el mapa idéntico, píxel a píxel, salvo la 3.5 y la 3.6. Antes de cada una: `tools/regress.py --save`; después, `--against`, y `tools/perf.py --android --arranque 3` antes y después.

### 3.0 Medir y decidir

1. La línea de base: `tools/perf.py --android --arranque 3` (`frame`, `shown`, `full`) y `tools/profile.py --android` para saber qué fases pesan en el teléfono. Agregar un iPhone (depuración de Safari) y un Android de gama baja, que faltan (CLAUDE.md, «Rendimiento»).
2. Decidir si el artifact sigue (ver §5). Si no sigue, las etapas se simplifican: no hace falta mantener dos salidas.

### 3.1 Dos salidas en `build.py`

- `build.py` arma dos destinos de los mismos fuentes:
  - `dist/talca.html`, el artifact, igual que hoy (datos incrustados, un solo archivo);
  - `dist/site/`, el sitio: `index.html` sin datos incrustados, más `data/*.json` (o binarios, 3.2) que el script pide con `fetch`.
- En el código, un solo punto de entrada a los datos: `loadData()` devuelve una promesa con `DATA` y `PD`. En el artifact resuelve con lo incrustado; en el sitio, con los archivos. `boot` la espera. Nada más en `src/js/` sabe de dónde vienen.
- `tools/check.py` revisa las restricciones del artifact solo en `dist/talca.html`; en el sitio revisa que cada archivo que pide exista.
- `scripts/deploy-cloudflare.sh` sube `dist/site/`, y el hook de pre-push sigue igual. El póster no cambia.
- Ganancia esperada: chica (la descarga y el análisis del JSON ya son una parte menor del arranque), pero es la base de todo lo demás. Medir `__stats.load` antes y después.

### 3.2 Datos binarios y por partes

- Las grillas (`elevation`, el raster del golf) y las geometrías codificadas en delta pasan a `Int16Array`/`Int32Array` en archivos `.bin`: sin `JSON.parse` y sin decodificar números uno por uno. `pipeline/` los escribe con `struct` (sigue en la biblioteca estándar); el artifact los sigue recibiendo como JSON, o como base64 si se mide que conviene.
- Separar lo que la primera vista no necesita (los edificios de OSM fuera de la caja de `STAGE`, los usos del campo) en archivos que se piden durante `rest()`.
- Nombres con hash del contenido (`elevation.3fa2c1.bin`) y caché larga en Cloudflare: un cambio de código no vuelve a bajar los datos.

### 3.3 Empaquetador y módulos

- esbuild (con `npx`, como ya se usa Wrangler) en vez de concatenar. Primer paso sin cambiar el código: el resultado de `template()` como un solo módulo, con mapa de fuentes. `build.py --where` sigue funcionando sobre el mapa de fuentes.
- Después, sección por sección, `src/js/NN-*.js` pasan a ser módulos con `import`/`export`. Los hitos se quedan como están: son trozos del cuerpo de `buildModels` que comparten sus variables locales (`C`, `at`, `reserve`, `palmS`…), y volverlos módulos es un trabajo aparte.
- El artifact recibe el mismo paquete, en línea, en un solo `<script>`: su restricción es el origen de los scripts, no que sean módulos.
- Ganancia: desaparece la trampa «Un solo script en muchos archivos», hay errores por archivo y el paquete se minifica (medir cuánto bajan los ~610 KB de código; los otros ~1,9 MB son datos). Es requisito de 3.6.

### 3.4 La segunda etapa en un Worker

- Lo que hoy hace `rest()` en tajadas entre cuadros (`sliced()`) pasa a un Worker. Los constructores (`GB`) ya escriben arreglos tipados (posición Float32, normal Int8, color Uint8): el Worker los transfiere sin copiar y el hilo principal solo crea las mallas (`tiledParts`, `canon()`).
- Primero, revisar qué funciones de la generación tocan `T` (three.js) o el DOM; lo que las use se queda en el hilo principal o se reemplaza por matemática propia. El Worker necesita los mismos datos: con 3.1 los pide él mismo.
- La primera etapa sigue en el hilo principal al comienzo: el primer cuadro no puede ir antes que ella. Si la 3.5 funciona, deja de importar.
- En el artifact, un Worker desde un `Blob` probablemente funciona; comprobarlo. Si no, el artifact sigue con `sliced()`.
- Requisito: el mapa terminado igual, píxel a píxel (trampa «El arranque en dos etapas»: las claves `G.k` y el orden de creación de las mallas).

### 3.5 La primera vista generada al armar

- La generación es determinista (`rng` con semilla). Al armar el sitio, Chromium sin interfaz (como `tools/screenshot.py`) carga la página, corre la etapa 0 y la primera, y guarda los arreglos de los constructores de la caja de `STAGE` en `dist/site/stage/*.bin`, junto con el estado que la segunda etapa lee (`occ`, `LOTS`, `PT`). No hace falta reescribir el generador en otro lenguaje.
- El sitio carga esos arreglos y dibuja; la segunda etapa sigue en el navegador (o en el Worker, 3.4). Si falta un archivo o su hash no calza con el de los datos, genera como hoy.
- Costos: un paso más en `make build` (alrededor de un minuto con SwiftShader, como `make smoke`), más descarga en la primera visita (medir: puede ser más lento que generar en un teléfono con mala red), y el estado que lee la segunda etapa tiene que poder guardarse y leerse. El de `occ` (un `Grid` en bloques) es el más delicado.
- `tools/regress.py --against` con el arranque normal como referencia: la imagen tiene que ser idéntica.

### 3.6 three.js nuevo

- Después de 3.3. Lo que da: `BatchedMesh` (muchas mallas en una llamada; hoy son ~1.000 llamadas en la vista de la comuna), recorte de `InstancedMesh` por su esfera (r128 nunca los recorta: `instTiled` lo resuelve a mano) y el renderizador de WebGPU, más adelante.
- Lo que cuesta: el manejo del color y las luces cambió en r152 (todas las capturas de referencia quedan viejas y la paleta hay que reajustarla a ojo contra ESTETICA.md), `winMat()` reemplaza trozos del sombreador con `onBeforeCompile` (`#include <tonemapping_fragment>`, `#include <project_vertex>`) que cambiaron, y `treeGeo()` supone que `IcosahedronGeometry` viene sin índice.
- Plan propio cuando llegue: es la etapa que más cambia la imagen.

### 3.7 Relieve más fino (exploratorio)

- El SRTM es de 30 m: una grilla de 20 m es lo más fino que sale de los datos actuales (`elevation.py` ya trabaja a 20 m). Más fino pide otra fuente (ALOS PALSAR a 12,5 m o un modelo nacional) y otra revisión del filtro de techos y árboles (trampa «El SRTM es de superficie»).
- Lo que se busca no es más detalle del terreno, sino poder **tallar** en él: la trinchera de la Ruta 5 bajo los pasos superiores, las calles que bajan bajo la vía, explanadas vecinas sin compartir nodos. Eso se logra mejor con una grilla de 20 m más cortes a lo largo de trazados conocidos (la Ruta 5, los `railx` tipo 0) que con una grilla fina en toda la comuna.
- Costos: con 20 m son 1,24 millones de nodos (cuatro veces más): cada recorrido de nodos (trampa «Lo que recorre todos los nodos del relieve») y cada `drape()` cortan cuatro veces más; `sampleTri()` y `terrainMesh()` tienen que seguir coincidiendo. Medir primero, con un `elevation.json` de 20 m, cuánto crecen la generación y los triángulos.
- Con 3.2 el relieve se puede pedir por zonas; sin eso, el de 20 m pesa ~3 MB como JSON.

## 4. Orden y dependencias

```
3.0 ─► 3.1 ─► 3.2 ─► 3.5
         └──► 3.3 ─► 3.4
               └───► 3.6
3.7: después de 3.2, independiente del resto
```

3.1 y 3.3 son las que más ordenan el trabajo y menos arriesgan. 3.5 es la que más acorta el arranque, y la más cara de mantener.

## 5. Preguntas abiertas

- **¿El artifact sigue?** Si nadie lo usa, quitarlo ahorra mantener dos salidas y la revisión de restricciones. Si sigue, queda como versión liviana: mismos fuentes, sin 3.5 ni 3.7.
- **¿Node en el armado?** Hoy `make build` es solo Python; Node se usa al publicar (`npx wrangler`) y para `node --check`. Con 3.3, `make build` pide Node.
- **¿Cuánto se puede descargar en la primera visita?** 3.5 y 3.7 cambian generación por descarga. Decidirlo con las mediciones del teléfono en una red móvil, no con las del escritorio.
- **¿Herramientas en otro lenguaje?** No hacen falta para este plan: la generación al armar (3.5) usa el mismo código de la página en Chromium. El pipeline de Python no es lo que el usuario espera; si un paso resulta lento (`make data`, `make edificios`), se mide ese paso antes de pensar en reescribirlo.
