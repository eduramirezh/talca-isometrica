# Plan: la vía férrea y un tren en movimiento

Plan de trabajo (octubre de 2026), todavía sin empezar. Junta la vía férrea con su detalle, los dos pendientes que ya estaban en CLAUDE.md (el tramo sur desde OSM y los puentes ferroviarios) y lo nuevo: un tren que recorre la vía. Es independiente de los puntos 4 a 6 de [PROYECTOS-SIMILARES.md](PROYECTOS-SIMILARES.md), aunque comparte `buildBase()` con el punto 4 (ver «Coordinación»).

## 1. Cómo está hoy

- **Trazado.** `config/trazados.json` → `ferrocarril` → `DATA.rail`, una sola línea.
  - El tramo norte, desde 2 Norte hasta el puente del Lircay, es la Línea Central de OSM.
  - El tramo central está trazado a mano y calza con los pasos inferiores de 1 Norte, 1 Sur y 8 Sur, con la estación y con el puente del Piduco.
  - El tramo sur es aproximado: queda hasta ~500 m fuera en el borde sur.
  - La vía y la Ruta 5 de OSM no se bajan en el pipeline, porque solo están en relaciones de ruta de más de mil miembros. Se tomaron una vez de la API `map` con `pipeline/traces.py tiles` y `line` (METODOLOGIA §5).
- **Dibujo.** En `buildBase()` la vía es una cinta de balasto de 6 m (a 0,2) y una línea de riel de 0,35 m (a 0,26), apoyadas en el terreno con `drape()`. `linesOcc()` deja ocupada una banda de 5 m a cada lado, sin casas ni árboles.
- **Estación.** El hito `estacion`, bajo `// ==== hito: estacion ====`, dibuja el edificio, la cubierta de hormigón, los andenes y tres vías del patio (la del andén cubierto y dos de patio, simplificadas). La línea principal es la de la capa base, en u ≈ 46 de su marco.
- **Ramal Talca–Constitución.** Está como lugar (`ramal-constitucion`, en el puente sobre el Piduco), pero su vía no se dibuja. Es de trocha métrica, de 1888–1915, lo recorre el Buscarril y es Monumento Histórico desde 2007 (ficha del CMN en `pois.py`).
- **Cruces con el agua.** La vía cruza el Piduco y el Lircay como una cinta plana sobre el agua.
- **El render.** Hoy se redibuja solo cuando algo cambia (`dirty`), y cada cuadro hace una pasada de sombras, la escena a baja resolución y, de cerca, la pasada de normales del pixel art (METODOLOGIA §8).

## 2. Las etapas

### 2.1 Trazado completo

1. **Tramo sur desde OSM.** Igual que el norte: `traces.py tiles` sobre las cajas del borde sur y `traces.py line ferrocarril railway=rail ...` para encadenar la Línea Central, comparando con `traces.py check` y con un panel sobre la imagen satelital. Reemplaza los puntos aproximados de `config/trazados.json`, con la procedencia en `fuente`.
2. **El ramal a Constitución** como segunda línea: desde el patio de la estación hasta el borde de la maqueta, cruzando el Piduco.
   - Hay que decidir el formato: `DATA.rail` como lista de líneas, o una clave nueva `ramal`. `process_geometry.py` y `build.py` lo pasan a la plantilla; `linesOcc()` y la capa base lo recorren.
   - Su ancho es menor: trocha de 1 m.
3. **Revisión de los cruces.** Las calles que pasan bajo la vía (pasos inferiores) y las que la cruzan a nivel, según OSM (`railway=level_crossing`). Hoy todo se dibuja a nivel.

### 2.2 Detalle de la vía, para el píxel de 0,5 m

Siguiendo ESTETICA §2 y §3: líneas de 0,4–0,5 m como mínimo, dos tonos alternados donde hay ritmo y nada menor de 0,4 m.

- **Rieles y durmientes.** Dos rieles oscuros de ~0,4 m sobre el balasto, separados por la trocha: 1,676 m en la Línea Central y 1 m en el ramal. Los durmientes van como bandas alternadas de dos tonos cada ~1–1,5 m, no cada 0,6 m como los reales, que a esta escala serían ruido.
- **Pasos inferiores.** La vía sobre un terraplén o un tablero corto en 1 Norte, 1 Sur y 8 Sur, con muros de contención. Hay que ver en fotos cómo son.
- **Pasos a nivel.** Barreras, señales y el cruce de tablones o asfalto. Solo donde OSM los marca.
- **Catenaria.** Postes y cable solo si las fotos muestran la Línea Central electrificada en Talca (por verificar). El cable mide menos de 0,4 m: se dibujan los postes y, a lo más, una línea de un píxel.
- **Luces de noche.** Pocas: señales y los faroles del andén con `GLOW`.

Todo lo que va en el suelo se apoya con `drape()` (capas planas) o `E(x, y)`, como el resto de la capa base. La vía de la estación sigue en su hito.

### 2.3 Puentes ferroviarios

- **Piduco:** el de la Línea Central y el del ramal.
- **Lircay:** el ferroviario, junto al Puente Lircay N.° 1 de la Ruta 5.

Se modelan como los puentes del Río Claro (tablero sobre pilas que reemplaza la cinta, un hito por puente), con su planta de OSM (`landmark.py osm`) y fotos fechadas. La vía deja de dibujarse sobre el agua donde hay puente, como la calle con `s.bridge`. El tren tiene que tomar la altura del tablero.

### 2.4 El tren

- **Qué trenes.** En la Línea Central, los servicios de pasajeros que paran en Talca y quizá uno de carga; en el ramal, el Buscarril. Modelos según fotos fechadas (Wikimedia Commons), con la estética de los hitos: volumen escalonado, dos tonos, ventanas oscuras, franjas de color de la empresa. Hay que verificar qué material rueda hoy por Talca antes de dibujarlo.
- **Recorrido.** Cada línea se convierte en un camino muestreado: puntos cada ~1 m con su distancia acumulada `s`, el rumbo y la altura (terreno, terraplén o tablero de puente). Cada carro se ubica por su `s` (el del primero menos el largo de los anteriores), orientado por la tangente entre sus dos bogies, para que tome bien las curvas.
- **Horario.** Ficticio pero verosímil: un tren cada pocos minutos de tiempo real, que entra por un borde, se detiene en la estación unos segundos y sale por el otro. El Buscarril va y vuelve por el ramal. De noche, un foco delantero y las ventanas encendidas.
- **Movimiento lento.** Si `prefers-reduced-motion` está activo, el tren queda detenido en la estación.

### 2.5 El render con algo en movimiento

Es el cambio de fondo: hasta ahora la escena solo se dibuja cuando algo cambia.

- **Cuándo dibujar.** Solo mientras algún tren esté dentro de la vista (una prueba de frustum con su caja). Fuera de la vista se avanza su `s` sin dibujar.
- **Cuadros por segundo.** 15–20 por segundo bastan y van con el pixel art. Cada cuadro cuesta las sombras, la escena a baja resolución y, de cerca, la pasada de normales. Hay que medirlo en una GPU real, no con SwiftShader.
- **El paso del tren.** Como la imagen de baja resolución está anclada a la grilla, el tren avanza de a un píxel de arte, como en un juego. No hay que suavizarlo.
- **El bucle.** No usar `anim`, que es el vuelo de la cámara y se cancela con la rueda o el arrastre. Hace falta un gancho propio por cuadro que marque `dirty` cuando corresponda.
- **Sombras.** El tren las proyecta: va con `castShadow`, como `B` y `S`.
- **Para las capturas.** `window.__train(línea, s)` deja un tren detenido en un punto, para `tools/screenshot.py --js` y `tools/variants.py`.

### 2.6 Verificación

- Capturas de cerca (`__look(x, y, 14.2)`, píxel de 0,5 m) de los rieles, los pasos inferiores, la estación con un tren detenido y cada puente. Ver también la vista girada, la noche y el móvil.
- Una hoja de `tools/variants.py` con el tren en varios `s` a lo largo de cada línea, para ver que no flote, no se hunda en los puentes y no atraviese el andén.
- Cuadros por segundo en una GPU real con un tren en pantalla, contra la vista quieta.
- CHANGELOG, FUENTES (fotos y licencias), METODOLOGIA §5 (los trazados nuevos) y CLAUDE.md, si aparece una trampa nueva.

## 3. Coordinación

- **Con el punto 4** (veredas, autos, árboles de vereda; PROYECTOS-SIMILARES), que también edita `buildBase()`. Conviene sacar primero el dibujo de la vía a una función propia, `railBase()`, llamada desde `buildBase()`, para que las dos sesiones toquen bloques distintos. Los autos del punto 4 no deben quedar sobre los pasos a nivel.
- **Con el hito de la estación.** Las vías del patio quedan en el hito. Si el ramal sale del patio, empalmarlo ahí y documentarlo en el comentario del hito.
