---
paths:
  - "src/js/hitos/**"
  - "src/js/45-landmarks.js"
  - "src/js/74-cerro.js"
  - "pipeline/landmark.py"
  - "tools/hitos.py"
---

# Los hitos (src/js/hitos/)

Los modelos a mano de los hitos: el catálogo de ejemplos, las reglas del archivo y sus trampas. El procedimiento paso a paso es la skill `/modelar-hito`; el porqué, docs/METODOLOGIA.md §9 y docs/ESTETICA.md.

## Arquitectura

| Archivo (`src/js/`) | Qué hace |
|---|---|
| `45-landmarks.js`, `hitos/` | `buildModels(B, S)`: modelos a mano de los hitos, cada uno en su archivo `hitos/<id>.js`, que empieza con la línea `  // ==== hito: <id> ====` (no la borre: la revisa `make check`), pegados en el marcador `/*HITOS*/` del cuerpo de la función en el orden de `hitos/ORDER` (el orden importa; su encabezado dice por qué). Lo que comparten los hitos está en `45-landmarks.js`, nunca en un hito (`make check` falla si un hito usa un nombre que declara otro, o lee `MODELS['<id>']` antes del hito que lo pone): en la cabecera de `buildModels`, `C`, `palmS`, `flagS`, `wallPath` y `wallRing` (cierran sobre `S`); antes, `KH` (la paleta de ESTETICA §4: cada hito escribe `K={...KH, …}`), `groundLayer(S,cap,F)`/`drapeInto(S,G)` (capas planas sin explanada; trampa «Capas planas sin explanada»), `onFinalTerrain(fn)` (trampa «`E()` dentro de `buildModels`…»), `occFill`, `keepOut`, `treeAt`, `scatterTrees` y `ownTracks` (recintos: tumbas, árboles propios, las pistas del grafo dentro de los muros), `pairs` (y `toCCW`, `ringArea` y `convexHull` de `15-utils.js`); el comentario de la cabecera enumera el estado que comparten (`MODELS`, `PADS`, `TREES`, `streets[i].bridge`…). Reservan su huella en `occ` y registran una explanada (`padAt`) antes de generar la ciudad. Todos dibujan en `S`, sin ventanas procedurales; `B` (con ventanas) no lo usa ninguno. `localFrame(X,Y,A)` da el marco local de un hito (`G`, `V`, `N3`, `R`) y `facade(S,F,K)` el vocabulario de fachada (muros `WL`, que guardan `a`, `b`, `out` y dan `w.at(o)`; `outOf`, `walls` de un anillo con remate, paños, arcos, vitrales, techos a dos aguas `roof` y a cuatro aguas `hipped`; ESTETICA §7). Después de cada hito, `build.py` pone `__HT('<id>')`: sus ms en `__stats.t.hitos` y, con `window.__HITOS_HASH`, una huella de lo que dibujó y cambió (`tools/hitos.py`). `NOLOTS` excluye recintos enteros de la ciudad generada; `GLOW` agrega luces nocturnas a `lamps()`. `deckBridge(S,K,pts,hw,hAt,o)` (antes de `buildModels`) dibuja un tablero sobre pilas para cualquier puente, con la altura `hAt(p)` del vano, veredas y parapetos o balaustrada, y marca su huella en `occ`: lo usan los puentes del Río Claro y los ferroviarios (`puente-lircay-ferrocarril`, `puente-piduco-ferrocarril`, `puente-ramal-piduco`, `puente-panguilemo-ferrocarril`) |
| `74-cerro.js` | `buildCerro`, `wildTrees`: estatua del Cerro La Virgen sobre el terreno real; árboles en manchones en las laderas y donde CONAF dice bosque o matorral (`wildAt`, `26-cobertura.js`; los de las plantaciones de eucalipto o pino, como álamos, en `T0.p`) |

## Comandos

```bash
uv run --with "playwright==1.63" python tools/hitos.py [--save shots/hitos-ref.json | --against shots/hitos-ref.json]   # ms de cada hito (__stats.t.hitos); con --save/--against, una huella exacta de lo que dibuja y cambia cada hito y de cada capa de la escena terminada: un cambio que no debe mover nada sale «igual» (más fino que regress.py, que mira siete vistas)
uv run --with pillow python pipeline/landmark.py osm estadio [250]   # planta OSM + plano en diagnostics/
python pipeline/landmark.py frame estadio 815575960 [más vías]       # vías en el marco local del modelo
python pipeline/landmark.py photos estadio ["consulta"]              # fotos de Commons, más recientes primero
python pipeline/landmark.py photos diagonal "Isidoro del Solar"     # con consulta, el nombre puede no ser un lugar (una calle)
python pipeline/landmark.py photos estacion --geo 150 --cat [--panoramax 150] [--mapillary] [--flickr]   # más fuentes: Commons por ubicación y por la categoría de Wikidata (wd=); Mapillary (las que miran al lugar, una por pasada; su clave: mapillary.py clave) y Flickr con FLICKR_KEY
uv run --with pillow python pipeline/landmark.py osm 4178,3725 [120]  # planta OSM alrededor de un punto de la grilla (un puente, un cruce), no de un lugar
```

## Modelar un hito

Los hitos se rehacen uno por uno sobre su planta real y con estética de pixel art: el procedimiento (planta, marco local, fotos, capturas, registro) es `/modelar-hito`; los criterios visuales (escala, lenguaje, paleta, lista de revisión), docs/ESTETICA.md.

Las reglas del archivo:

- en `src/js/hitos/<id>.js`, que empieza con `  // ==== hito: <id> ====`, y su id en `src/js/hitos/ORDER` (al final, salvo que deba ir antes de un vecino); `make check` avisa si falta uno de los dos;
- pixel art: peldaños y arcos escalonados, dos tonos alternados, molduras blancas, líneas de 0,5 m, paleta local `K={...KH, …}` (KH es ESTETICA.md §4);
- `S` para todo, con el vocabulario de `facade()` y los ayudantes de `45-landmarks.js` antes que copias de otro hito; si algo nuevo sirve a dos hitos, va ahí (`make check` falla si un hito usa lo que declara otro);
- `occMark` con la huella real, `padAt`, `NOLOTS` si hay recinto cercado y `GLOW` para luces;
- un comentario con los ids de OSM, las fuentes y lo aproximado;
- una trampa nueva va en la sección «Trampas» de esta regla (o en la de su tema), con su título en el índice de CLAUDE.md.

### De qué hito copiar

El Estadio Fiscal y la Catedral son los ejemplos de referencia. Para casos particulares, copie del que se parezca:

- en ladera y fuera de toda explanada: el Cerro La Virgen (`buildCerro`);
- un campus de decenas de edificios de OSM sin explanada y con pasto apoyado en el terreno: la U. de Talca y la UCM;
- vías que siguen el suelo junto a una explanada: la Estación;
- una isla entre calzadas: La Victoria;
- plantas cóncavas y relieve real en la fachada: el Hospital;
- techos a cuatro aguas: la Ex Cárcel y el Liceo Abate Molina;
- un parque con prados, senderos, juegos y muelles sobre el agua: el Parque Río Claro;
- un puente de tablero sobre pilas que reemplaza una calle del mapa: los puentes del Río Claro;
- una autopista sobre puentes y terraplenes (también uno cortado en el límite de la comuna, `puente-panguilemo-ruta5`), un paso superior con rampas o una pasarela: la Ruta 5 (`puente-lircay-ruta5`, `puente-piduco-ruta5`, `enlaces-ruta-5`, con `r5Raise`, `r5Over` y `r5Foot`);
- un puente ferroviario con vigas de celosía sobre pilas de piedra, que la vía cruza a la altura de su perfil: el puente-lircay-ferrocarril (`RAIL_BR`, `railGirder`, `railPiers`);
- un viaducto de arcos de ladrillo junto a un puente de celosía bajo el tablero (`railGirder` con `warren`): el puente-panguilemo-ferrocarril;
- un recinto amurallado de piezas repetidas y mucho árbol (tumbas, nichos, cuarteles): el Cementerio General y el Regimiento 16 (`wallPath`, `wallRing`, `occFill`, `keepOut`, `treeAt` y `ownTracks`, de `45-landmarks.js`);
- una manzana en pendiente junto a las explanadas de otros hitos, con alas escalonadas sobre el terreno final: el Colegio De La Salle (`colegio-la-salle`);
- un recinto con una cubierta plegada de facetas radiales sobre una planta en estrella, con su anillo de calzada, estacionamiento, prados y árboles leídos de la imagen, y los usos genéricos que cubre saltados con `occFill`: el Gimnasio Regional (`gimnasio-regional`: se dibuja dentro de `onFinalTerrain()`, que aplica las explanadas registradas mientras corre, como el Colegio De La Salle);
- un edificio sobre pilotes en terreno inundable, sin explanada (el piso a una altura fija sobre el punto más alto de su planta, cada pilote sobre su propio suelo), con un estacionamiento en anillos concéntricos cortados por el borde del plano (`band`, con `clipTo`): el Casino Dreams (`casino-dreams`, en el ex recinto de la FITAL);
- quioscos sobre la vereda de una calle del mapa, sin cortarla (`occMark(q, 3)` y `CLEAR` para los árboles y autos de la vereda): los carritos de 5 Oriente (`carritos-5-oriente`);
- un edificio que OSM no tiene, desde una huella de aprendizaje automático, sin lugar en `pois.py` y sin explanada (`occFill`): el Edificio Raíces (`edificio-raices`);
- un tramo entero de la Alameda, que la Alameda deja de dibujar (`ALAM_OWN`: su paseo, su plaza, sus faroles y sus árboles), con lo que hay adentro ubicado por rumbos desde las panorámicas de las dos calzadas (`mapillary.py postes` y `cruce`), sin explanada (`groundLayer`) y con los árboles de OSM uno por uno: los juegos entre 3 y 4 Oriente (`juegos-alameda`);
- un recinto fuera de las manzanas que reemplaza un uso del campo sin correr las parcelas vecinas (`u.keep`): el Colegio Inglés (`colegio-ingles`);
- un recinto dibujado desde datos leídos de la imagen (`DATA.golf`, de `pipeline/golf.py`): el Talca Country Club (`talca-country-club`);
- calles vestidas sin reemplazar el mapa (la calzada pintada por zonas con `s.paint`, líneas de pista con `s.lanes`, faroles con `LAMP_SKIP`, árboles reales con `CLEAR_T`, objetos sobre la vereda de la calle del mapa y no sobre la solera real): las calles de la plaza (`calles-plaza`, con `DATA.plaza`: los semáforos y árboles de OSM del plano del juego).

## Trampas

- **Las alturas de OSM no sirven para hitos.** `height` y `building:levels` suelen ser valores por defecto: la torre de la Catedral dice 17 m y mide ~39. Mida en una foto frontal con un ancho conocido de la planta como escala.
- **Caras sin normal en `S`.** El material dibuja solo la cara de frente y `face()` ordena los vértices según la normal que recibe. Las caras verticales (muros, hastiales, detalles de fachada) necesitan su normal explícita (`N3(...)`); sin ella, `face()` solo garantiza que la cara mire hacia arriba.
- **El punto del lugar no es el centro del hito.** Las coordenadas de `pois.py` son direcciones. En recintos grandes caen en el borde (centrado ahí, el Estadio quedaba 100 m corrido, sobre 5 Norte). Ubique el modelo con la planta de OSM y apunte `MODELS[id]` a su centro.
- **La caja de descarga de OSM.** Si no cubre todo el hito, faltan piezas sin aviso (al estadio le faltaban dos de sus cuatro torres). Use `landmark.py osm <id> <media caja>` con margen.
- **Ventanas en caras que no son fachadas.** `winMat()` pinta ventanas en toda cara vertical a más de 1 m de altura. Graderías, escalinatas y muros van en `S`.
- **Líneas de 0,5 m en un marco girado.** El píxel de arte (0,5 m) está anclado a los ejes de la grilla: en un marco local girado (el del Colegio Inglés, a 12° del eje) una línea de 0,5 m (las de una cancha) se rompe en puntos sueltos; con 0,8 m se lee entera. En un marco alineado con la grilla (el Regimiento) 0,5 m basta.
- **`E()` dentro de `buildModels` es el terreno sin explanadas.** `applyPads()` corre después y además aplana una celda de 40 m alrededor de cada explanada. Lo que va justo afuera de una (andenes, vías) toma `max(explanada, E)`. Un hito sin explanada al lado de otras (a menos de 40 m: comparten nodos) se dibuja sobre el terreno final dentro de `onFinalTerrain(() => {…})` (`45-landmarks.js`: aplica a `EH` las explanadas registradas mientras corre y lo restaura al terminar, también si falla; `groundMin` y `drape` las ven), como `hitos/colegio-la-salle.js`; tiene que ir después de esos hitos en `ORDER`.
- **Capas planas sin explanada.** Donde un hito no tiene `padAt`, sus capas planas van en `groundLayer(S, cap, F)` (`45-landmarks.js`: `lay`, `rc`, `pl` y `done()`, que las drapea con `drape()` y copia sus triángulos a `S` con normal `[0,1,0]`, porque `EN()` todavía vale cero, y a `S.dy` 0, que restaura al terminar), o en un `GB` propio con `drapeInto(S, G)`. Las alturas están en `Y_LAYER` (`30-geometry.js`): una capa nueva va ahí, y si toca otra, el par en `Y_OVER` (`make check` exige `Y_STEP`, 7 mm; una separación de 0,5 cm parpadea).
- **Techos a la misma altura en `S`.** Si varias cajas llegan a la misma altura, sus tapas coplanares y los muros interiores que terminan en el techo se ven como líneas cortadas. Use `lid=false`, termine los muros 3 cm abajo y ponga un solo `S.flat` sobre todo el contorno.
- **`prism()` y `face()` triangulan en abanico desde el primer vértice.** Con un contorno cóncavo (la estrella de doce vértices del Gimnasio Regional) la tapa sale con triángulos de más o de menos: los muros de `prism(q, …, false)` sirven, y la tapa va con `S.flat(q, y, col)`, que triangula de verdad. Una faceta de cuatro vértices no coplanares (un alero que sube y baja) va como dos triángulos, cada uno con su normal.
- **Las caras inferiores no se ven.** Aleros y voladizos miran hacia abajo; un color que solo vive ahí (la madera del Teatro Regional) va en un borde visible.
- **Calzadas del mapa y plantas de OSM.** Las calzadas del mapa (calles del grafo, con ancho por clase) son más anchas que las reales, y las plantas de OSM pueden quedar ~5 m corridas respecto de las manzanas del censo: una isla o un muro dibujado desde OSM puede pisar el asfalto. Ajústelo al hueco entre las calles del mapa (La Victoria, la Ex Cárcel). Al revés también pasa: el predio de OSM de la ex FITAL queda 10–20 m antes de 5 Norte y de Circunvalación en el mapa, y en esa franja `cityGen` pondría galpones: el hito reserva hasta el eje de esas calles (`occFill` ya deja 2,5 m junto a ellas para las veredas).
- **El contorno de OSM puede incluir estacionamientos.** El del Mall Plaza Maule abarca un estacionamiento en superficie (por el subterráneo). Contraste con la imagen.
- **`buildCerro()` corre después del terreno.** Ahí `padAt` ya no sirve y `S` no está al alcance: el santuario se apoya en `E()`/`groundMin`, con muros de contención, en su propio `GB`.
- **El punto de un edificio junto a la Alameda.** `alamedaPlan()` centra la plaza de cada tramo de la Alameda en el `MODELS` cuya x cae en el tramo y cuya y está a menos de 20 m de su centro. El punto de un edificio vecino no debe caer ahí por accidente.
- **Explanadas vecinas.** Los nodos del relieve están cada 40 m y `applyPads()` fija todos los que quedan a menos de 40 m de la caja: dos explanadas a menos de ~80 m comparten nodos y gana la última registrada. Con alturas distintas, una queda inclinada o enterrada. Los hitos vecinos registran la misma altura (`PADS.push([x0,y0,x1,y1,h])`): la plaza, la Catedral y el lado norte usan `MODELS['plaza-de-armas'].pad`.
- **OSM no siempre trae los patios.** El contorno de la Casa de la Independencia (w214849869) no tiene sus patios interiores; salen de `satellite.py`.
- **Un hito sobre un uso de suelo lo saca entero.** `usosPlan` salta un uso cuando más de un 35 % de sus muestras cae en la huella de un hito (`occMark`, o el polígono entero con `occFill(anillo, 2.5)`, como `hitos/cementerio.js`: la misma regla de `usosPlan`, que deja 2,5 m junto a las calles) o en su `NOLOTS`; para eso no hace falta `NOLOTS`, que se prueba en cada paso de cada calle. Lo que el hito no dibuja dentro del contorno del uso (el obrador al sur de la planta de Cecinas PF, el cerro seco del golf) queda con el suelo de la manzana, sin los árboles ni los detalles genéricos; si hace falta, el hito lo dibuja él (el golf: `DATA.golf`, de `pipeline/golf.py`). Se confirma en `__usos.skip` y `__usos.n.<uso>`; `__usos.skip` lista índices de `USOS`, no de `config/usos.json` (`build.py` descarta las `vivienda` y lo de fuera de la comuna): el Cementerio General es el 91 y el Regimiento el 69; para otro, cuente `usos.json` con ese filtro (`pipeline/build.py land_uses`). Las pistas del grafo dentro de un recinto (clase 7) se dibujan como calles; si el hito dibuja sus propios senderos las apaga con `s.bridge=true` (el Cementerio; el Regimiento las deja, son sus caminos).
- **Un hito sobre un uso del campo deja las parcelas como estaban.** `buildBase()` pone una parcela agrícola (y, con un 7 %, su hilera de álamos) donde el centro de su celda de 160 × 130 m no cae en un uso (`usoAt`), y todas sacan sus números de un solo `rng(4242)` que recorre la comuna de poniente a oriente. Cuando `usosPlan` salta un uso porque un hito lo cubre, `usoAt` pasa a decir que no: aparecen parcelas bajo el hito (escondidas por su suelo, pero con álamos) y, sobre todo, el `rng` se corre para cada parcela que sigue al oriente, lejos del hito. Un hito que reemplaza un uso fuera de las manzanas marca los que quedan dentro de su recinto con `u.keep=true` (recorre `USOS` después de `occFill`) y `usoAt` los sigue contando, como `hitos/colegio-ingles.js` (los anteriores no lo hacen: sus parcelas ya están en la referencia de `tools/regress.py`). Se nota en `--against` como píxeles distintos lejos del hito y en `__stats.poplars`.
- **Un hito en la vereda, y el edificio de OSM que es su único edificio.** Las veredas, los árboles de vereda y los autos estacionados ceden solo ante `occ === 1`: un hito que pone quioscos sobre la vereda (`carritos-5-oriente`) marca con `occMark(q, 3)` (lo ven los usos y los árboles del campo) o no marca nada, y no con 1, que cortaría la vereda y los cruces de la calle. Si los árboles de la calle o los autos estacionados tapan el hito, no se sacan por `occ` (las celdas de 2,5 m de las pruebas de los árboles y de las veredas son las mismas): el hito empuja un polígono a `CLEAR` (`60-streets.js`), y `streetTrees`/`parkedCars` no ponen nada dentro; la prueba va después de sacar los números de cada árbol o auto, así que el resto de su tramo no cambia. Y no se quita un edificio de OSM (con `occMark(q, 1)` sobre su planta, que `edificiosPlan` salta) si es el único de su manzana entera: sin edificios, la manzana pierde el suelo que dibuja `edificiosGround` (de arena a pasto de parque) sin que `__usos.skip` cambie. Se viste su cara en cambio (la caseta «Carritos 6 oriente», w360214695).
