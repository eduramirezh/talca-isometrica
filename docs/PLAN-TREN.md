# Plan: la vía férrea y un tren en movimiento

Plan de trabajo de octubre de 2026. **Todas las etapas están hechas** (2.1 a 2.3, la vía, en una sesión; 2.4 a 2.6, el tren y el render con algo en movimiento, que cambian `loop()` para toda la página, en otra). Junta la vía férrea con su detalle, los dos pendientes que estaban en CLAUDE.md (el tramo sur desde OSM y los puentes ferroviarios) y lo nuevo: un tren que recorre la vía. Es independiente de los puntos 4 a 6 de [PROYECTOS-SIMILARES.md](PROYECTOS-SIMILARES.md), aunque comparte `buildBase()` con el punto 4 (ver «Coordinación»).

## 1. Cómo está hoy

- **Trazado.** Las dos líneas son de OpenStreetMap, tomadas una vez de la API `map` (caché `raw/osm/map-este.json`, de `traces.py tiles`) con `python pipeline/railway.py write este`, que reescribe `config/trazados.json` → `ferrocarril` (METODOLOGIA §5):
  - la **Línea Central** (`puntos`, 32 puntos, 10,5 km; trocha de 1,676 m; electrificada) → `DATA.rail`;
  - el **ramal a Constitución** (`ferrocarril.ramal.puntos`, 9 puntos, 4,2 km; trocha de 1 m; sin electrificar) → `DATA.ramal`. Empieza en el tope de su vía, al sur del edificio de la estación (OSM n4330545413), baja por la cara poniente del andén descubierto, corre 5–8 m al poniente de la Línea Central y deja la maqueta por el sur, en (1180, −4200), rumbo al surponiente;
  - los cruces con las calles del mapa (`pasos` → `DATA.railx`, `[tipo, línea, x, y]`), los postes de la catenaria (`postes` → `DATA.rmast`), las señales (`senales` → `DATA.rsig`) y las trochas (`DATA.rgauge`).
  - Ya no hay tramos a mano: el central iba hasta 26 m al oriente de la vía principal en la estación, por una vía de patio, y el sur quedaba hasta ~500 m fuera.
- **Dibujo** (`railBase()`, llamado desde `buildBase()` después de las calles; corre después de las explanadas y antes de la ciudad). Cada línea se muestrea cada 0,7 m sobre su eje suavizado (Chaikin, 2 pasadas) con un perfil de alturas `T`, la cara superior del balasto:
  - **en el suelo** (`T = E + 0,2`): balasto drapeado a 0,2 (grava `PAL.ballast` en la Línea Central, tierra en el ramal, como en las fotos), durmientes a 0,22 cada 1,4 m y de 0,7 m de ancho (hormigón o madera), dos rieles de 0,4 m a 0,24 separados por la trocha;
  - **sobre un terraplén o un tablero** (malla propia, no drapeada, que proyecta sombra): la misma vía a `T`, `T + 0,02` y `T + 0,04`.
  - `linesOcc()` deja libre una banda de 5 m a cada lado de la Línea Central; `railBase()`, 4 m del ramal y el pie de los terraplenes.
- **Pasos bajo nivel** (`DATA.railx` tipo 0): donde OSM dice que la calle pasa bajo la vía (la vía con `bridge=yes`: 1 Norte, 2 Norte, la Alameda y un camino al norte del Lircay; la calle con `tunnel=yes`: 1 Sur, 6 Sur y 8 Sur, estos dos bajo las dos líneas). La calle no puede bajar (el relieve es una malla de 40 m), así que la vía sube: tablero a `E(cruce) + RAIL_HU` (3 m) del largo de la calle más 1,2 m por lado, rampas de 1:`RAIL_G` (1:16, 48 m) y, entre dos pasos a menos de `RAIL_FILL` (160 m), terraplén continuo (1 Sur, 1 Norte y 2 Norte quedan unidos, a la altura del más bajo). El tablero es blanco, con balaustrada de postes y huecos cada 0,7 m y estribos blancos, como el de 1 Sur en las fotos de 2014; el terraplén, de pasto seco en dos tonos cada 4 m, con taludes de 1:1,5. Las dos calzadas de 1 Sur y de la Alameda pasan bajo un solo tablero.
- **Cruce a nivel** (tipo 1, con barreras): 14 Sur, en las dos líneas. El balasto se corta en la calzada y los rieles cruzan sobre un panel; en cada acceso, a la derecha, un poste blanco con la cruz de San Andrés (blanca con borde rojo), dos luces rojas y la barrera levantada (rojo y blanco cada 0,6 m). No hay otros en el mapa: el camino a nivel al norte del Lircay (OSM n4684344952) no es una calle del mapa.
- **Catenaria y señales.** Los 181 postes de OSM a menos de 8 m de la Línea Central, desplazados fuera del balasto si caían en él, con una ménsula sobre la vía a `T + 6,2`; ninguno bajo la Ruta 5. Sin hilo de contacto: dibujado como un píxel de arte se cortaba en trazos. Las 16 señales luminosas de OSM: poste, cabeza oscura con una banda roja y una luz (`GLOW`) de noche.
- **Puentes** (hitos que se registran en `RAIL_BR` y que `railBase()` dibuja con el perfil final):
  - `puente-lircay-ferrocarril`: N° 1 sobre el cauce (OSM w143173502, 132 m) y N° 2 sobre el brazo sur (w101562801, 32 m). Tablero con vigas de celosía a los lados (`railGirder`, 3 m sobre el tablero), pilas de piedra con tajamares y estribos con pilares (`railPiers`), según la foto de c. 1900; 6 y 2 tramos. Tablero a 0,6 m sobre la orilla más alta. Sin explanada: el puente de la Ruta 5 está a 30 m.
  - `puente-piduco-ferrocarril` (w102212627) y `puente-ramal-piduco` (w435101040, el lugar `ramal-constitucion`): un tramo de 14 m sobre vigas de alma llena, uno junto al otro, a 2 m sobre la orilla más alta para que el agua se vea bajo ellos (el estero corre en una zanja que el relieve no tiene).
  - Los puentes de OSM sobre esteros y canales que la maqueta no dibuja (Caiván, Los Molinos, El Parrón, el Canal Sandoval y un estero de 4 m al norte de la Alameda) no se modelan: la vía pasa a nivel.
- **Estación.** La vía principal de OSM es la de la cubierta (u ≈ 18–20 del marco de la estación) y la dibuja `railBase()`; el andén descubierto queda entre ella (al oriente) y el ramal (al poniente). Las dos vías de patio del hito (u 33,5 y 38,5, simplificadas) van en `RAIL_YARD` y se dibujan igual que las líneas; los topes siguen en el hito, también el del ramal.
- **El camino para el tren.** `RAILP` (`window.__rail`) guarda cada línea, `main` y `ramal`, como arreglos de la misma longitud, uno por muestra (cada 0,7 m): `x`, `y` (metros de grilla), `s` (distancia acumulada: desde el borde norte en la Línea Central, desde el tope de la estación en el ramal), `h` (altura del riel: la del suelo, el terraplén, el tablero o el puente), `g` (el suelo), `kind` (0 suelo, 1 terraplén, 2 tablero de paso bajo nivel, 3 puente, 4 cruce a nivel) y `lifts` (`{s0, s1, H, bridge}`, los tableros y puentes). Puntos de referencia: Línea Central, 10.477 m, 14.969 muestras; la cubierta de la estación entre s ≈ 6.150 y 6.270, el puente del Piduco en 7.397, el cruce de 14 Sur en 8.133, el Lircay N° 1 en ~1.200–1.334 y el N° 2 en ~1.528–1.560. Ramal, 4.224 m, 6.035 muestras; el puente del Piduco en s ≈ 1.145 y 14 Sur en 1.880.
- **El render.** Se redibuja cuando algo cambia (`dirty`) y, desde la etapa 2.5, a 18 cuadros por segundo mientras un tren se mueve dentro de la vista (`trainsTick`, llamado por `loop()` en cada cuadro); cada cuadro hace una pasada de sombras, la escena a baja resolución y, de cerca, la pasada de normales del pixel art (METODOLOGIA §8).
- **Los trenes** (sección «trains» de la plantilla, después de `railPiers`): el automotor SFB de EFE (tres coches) y un tren de madera (locomotora y seis carros) en la Línea Central, el Buscarril (dos coches) en el ramal, cada uno un `Group` con dos mallas por coche. `TRAIN.lines` guarda el horario de cada línea como corridas cíclicas.

## 2. Las etapas

### 2.1 Trazado completo (hecho)

1. **Tramo sur desde OSM.** Hecho con `pipeline/railway.py`: toda la Línea Central, no solo el sur, sale de la cadena `usage=main` de la caché `map-este`. Revisado con `traces.py check piduco` y `check lircay` (los cruces caen a 0–1 m de los puentes de OSM) y con paneles sobre la imagen satelital del sur y de la estación.
2. **El ramal a Constitución.** Hecho: clave nueva `DATA.ramal` (y `ramal` dentro de `ferrocarril` en `config/trazados.json`), para no cambiar la forma de `DATA.rail`, que otras herramientas leen. Arranca en el patio de la estación (su vía de andén), sin empalme dibujado con la principal: en OSM se une a ella por los cambios del patio sur, que la maqueta no tiene.
3. **Revisión de los cruces.** Hecha: las 13 calles del mapa que cruzan la vía (10 la Línea Central, 3 el ramal) están en `DATA.railx`, cada una con lo que dice OSM. Aproximado: la altura de los tableros (3 m sobre la calle, la vía sube en vez de bajar la calle).

### 2.2 Detalle de la vía (hecho)

- **Rieles y durmientes.** Hechos, como estaba previsto (ESTETICA §2 y §3). Los durmientes se distinguen del balasto en un 15–20 % de luminosidad (más claros en la Línea Central, más oscuros en el ramal).
- **Pasos bajo nivel.** Hechos como terraplén y tablero (arriba). Fotos solo del de 1 Sur; los demás son iguales por licencia.
- **Pasos a nivel.** El de 14 Sur, el único del mapa.
- **Catenaria.** Verificado: OSM marca la Línea Central `electrified=contact_line` y las fotos de 1 Sur (2014) muestran postes e hilo. Postes y ménsulas, sin hilo.
- **Luces de noche.** Las señales. Los faroles del andén no se agregaron (serían un cambio del hito de la estación fuera de su patio).

### 2.3 Puentes ferroviarios (hecho)

Los tres previstos y uno más (el N° 2 del Lircay, sobre el brazo sur, que OSM tiene dentro del agua del río). Formas aproximadas: hay una sola foto con licencia libre, del Lircay N° 1 hacia 1900, y ninguna de los del Piduco. Cómo se registra un puente en `RAIL_BR` está en el comentario de `railBase()` y en CLAUDE.md.

### 2.4 El tren (hecho)

Hecho como estaba previsto. Lo que se verificó y lo aproximado: por Talca corren hoy el automotor bimodal SFB-3000 de EFE (Santiago–Chillán, fotos de 2024 bajo la cubierta) y el Buscarril ADM del ramal (fotos de 2019 y 2024); el tren de madera sale de una foto de 2017 de los carros en la estación, y su locomotora, que no aparece en ninguna foto libre, es un modelo genérico en amarillo y azul. Tres coches en el SFB (los de las fotos), dos en el Buscarril, seis carros en el de madera. Las medidas de los coches son las del tipo donde se conocen y aproximadas en lo demás; la velocidad (100 km/h el automotor, 65 el de carga, 50 el Buscarril) y las paradas (25 s bajo la cubierta, 40 s en el andén) son ficticias. Sin luz de cola. El Buscarril parte del andén descubierto y no empalma con la principal (la maqueta no tiene los cambios del patio).

- **Qué trenes.** En la Línea Central, los servicios de pasajeros que paran en Talca (las relaciones de OSM: Tren Chillán–Estación Central, el Expreso y el Curicó–Linares) y quizá uno de carga; en el ramal, el Buscarril. Modelos según fotos fechadas (Wikimedia Commons: hay del Buscarril y del servicio Talca–Constitución de 2009 a 2016), con la estética de los hitos: volumen escalonado, dos tonos, ventanas oscuras, franjas de color de la empresa. Hay que verificar qué material rueda hoy por Talca antes de dibujarlo.
- **Recorrido.** El camino muestreado ya existe: `RAILP` (§1). Cada carro se ubica por su `s` (el del primero menos el largo de los anteriores), a la altura `h`, orientado por la tangente entre sus dos bogies (los puntos de `s ± media distancia entre bogies`), para que tome bien las curvas y las rampas de los pasos bajo nivel (1:16).
- **Gálibos que ya hay que respetar.** Sobre los tableros de los pasos bajo nivel hay parapetos a ±2,8 m del eje (±2,2 en el ramal) y 1 m de alto; en los puentes del Lircay, las vigas de celosía por dentro a ±2,5 m y 3 m de alto; las ménsulas de la catenaria a 6,2 m sobre el balasto y los postes a ≥3 m del eje. Un coche de trocha ancha (~3,2 m de ancho, ~4,3 de alto) cabe. En la estación, el borde del andén descubierto (u = 18) queda a ~1,5 m del eje: un coche de 3,2 m lo roza; el piso del coche va sobre el andén (1 m).
- **Horario.** Ficticio pero verosímil: un tren cada pocos minutos de tiempo real, que entra por un borde, se detiene en la estación unos segundos (Línea Central: s ≈ 6.150–6.270, bajo la cubierta) y sale por el otro. El Buscarril parte del tope del ramal (s = 0), va hasta el borde sur y vuelve. De noche, un foco delantero y las ventanas encendidas.
- **Movimiento lento.** Si `prefers-reduced-motion` está activo, el tren queda detenido en la estación.

### 2.5 El render con algo en movimiento (hecho)

Hecho como estaba previsto: `trainsTick()` corre en cada cuadro de `loop()`, mueve los trenes y pide un cuadro a 18 por segundo solo mientras uno se mueve dentro de la vista (prueba de frustum con la esfera de cada coche, y un cuadro más cuando sale o se oculta). `window.__train(línea, s, tipo, sentido)` detiene el horario y deja un tren en `s`; `__train(null)` lo reanuda. `__trainFps()` mide los cuadros que piden los trenes. Medido con SwiftShader la generación sube ~2 ms. En la GPU real de Edu (Chrome, pantalla Retina a 60 Hz, 2026-10-15), con el automotor en pantalla a zoom 22, `__trainFps()` da 16–17 cuadros por segundo con 1–2 ms de CPU por cuadro (el tope de 18 cae entre cada tercer y cuarto cuadro de los 60), y 0 cuando ningún tren se mueve en la vista.

Es el cambio de fondo: hasta ahora la escena solo se dibuja cuando algo cambia.

- **Cuándo dibujar.** Solo mientras algún tren esté dentro de la vista (una prueba de frustum con su caja). Fuera de la vista se avanza su `s` sin dibujar.
- **Cuadros por segundo.** 15–20 por segundo bastan y van con el pixel art. Cada cuadro cuesta las sombras, la escena a baja resolución y, de cerca, la pasada de normales. Hay que medirlo en una GPU real, no con SwiftShader.
- **El paso del tren.** Como la imagen de baja resolución está anclada a la grilla, el tren avanza de a un píxel de arte, como en un juego. No hay que suavizarlo.
- **El bucle.** No usar `anim`, que es el vuelo de la cámara y se cancela con la rueda o el arrastre. Hace falta un gancho propio por cuadro que marque `dirty` cuando corresponda.
- **Sombras.** El tren las proyecta: va con `castShadow`, como `B`, `S` y la malla de la vía.
- **Para las capturas.** `window.__train(línea, s)` deja un tren detenido en un punto, para `tools/screenshot.py --js` y `tools/variants.py`.

### 2.6 Verificación (hecha)

Capturas en `shots/tren/` (ignorado por git): la estación (el tren detenido queda bajo la cubierta y no se ve: se ve entrar y salir), el andén del ramal con el Buscarril, el tablero de 1 Sur, los puentes del Lircay y del Piduco (las dos líneas), el tren de madera, la noche y el móvil; de cerca con `__pixelArt(null)` y `__look(x, y, 70–90)` para revisar cada modelo, el borde del andén y los parapetos. Una hoja de `tools/variants.py` con el tren en diez `s` de las dos líneas: no flota ni se hunde, y fuera del terreno se oculta. `stats:` iguales salvo `trains` (12 coches, 1.328 vértices, 2 ms); cero errores de consola. `tools/probe.py` salió de aquí.

- Capturas de cerca de la estación con un tren detenido y de cada puente y paso bajo nivel con un tren encima (para la vía sola ya están hechas: zoom 22–26, que en esta versión es el de píxeles de arte de ~0,5 m; `__look(x, y, 14.2)` queda más lejos). Ver también la vista girada, la noche y el móvil.
- Una hoja de `tools/variants.py` con el tren en varios `s` a lo largo de cada línea, para ver que no flote, no se hunda en los tableros y no atraviese el andén ni los parapetos.
- Cuadros por segundo en una GPU real con un tren en pantalla, contra la vista quieta.
- CHANGELOG, FUENTES (fotos y licencias), METODOLOGIA y CLAUDE.md, si aparece una trampa nueva.

## 3. Coordinación

- **Con el punto 4** (veredas, autos, árboles de vereda; PROYECTOS-SIMILARES), que también edita `buildBase()`. El dibujo de la vía es `railBase()`, una función propia. Los autos y las veredas se cortan en la banda ocupada de la vía (`occ`), que cubre también los cruces a nivel y los tableros: no hay autos sobre la vía.
- **Con la Ruta 5.** La Ruta 5 pasa sobre la Línea Central en (3378, 2703), en su propio puente (OSM w151617648 y w151617649, `layer=1`); la vía va a nivel debajo (`kind` 0) y sin postes de catenaria a menos de 16 m del eje de la autopista. El tablero de ese puente tiene que quedar sobre la vía (balasto a `E + 0,2`) con espacio para el tren (~5 m). Junto al puente ferroviario N° 1 del Lircay está el de la Ruta 5, a 30 m: ninguno de los dos tiene explanada.
- **Con el hito de la estación.** Las vías del patio son del hito, que las registra en `RAIL_YARD`; las dibuja `railBase()`. El ramal sale del andén descubierto y no tiene empalme dibujado con la principal.
