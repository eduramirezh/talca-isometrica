# Estética de los hitos

Criterios visuales para los modelos hechos a mano, para que los hitos rehechos se vean como una sola familia. El procedimiento (planta, marco local, fotos, verificación) está en [METODOLOGIA.md §9](METODOLOGIA.md#9-modelos-de-hitos); este documento dice cómo debe verse el resultado. Los ejemplos de referencia son el Estadio Fiscal y la Catedral; todos los hitos de `buildModels` siguen ya estos criterios.

## 1. La idea

**Una maqueta de pixel art, no una foto.** Los hitos son la versión de juego de ciudades del edificio real: la planta y las proporciones son las reales, y la superficie se dibuja con pocos colores planos y detalles grandes. El modelo tiene que reconocerse al zoom de la ficha y verse bien con el modo pixel activado.

Tres reglas ordenan las demás:

1. **La planta es la real; la elevación se interpreta.** La huella sale de OpenStreetMap, y las alturas y los colores, de fotos fechadas. Todo lo que está sobre el suelo se simplifica hasta lo que se lee a la escala de trabajo (§2).
2. **Se dibuja con forma y color, no con textura.** No hay imágenes, degradados, transparencias ni bordes de posproceso. La luz de la escena sombrea cada cara y el sol proyecta sombras (desde el nor-nororiente, a 45°: techo claro, muro oriente al sol, muro sur a la sombra); el resto lo ponen los colores de la paleta.
3. **El hito destaca por su silueta y su detalle, no por su color.** Los colores se quedan dentro de la paleta de la escena (§4). La ciudad generada es más simple (cajas con ventanas de sombreador), así que basta el detalle dibujado para que el hito se distinga.

## 2. La escala de trabajo

El zoom de la ficha muestra ~0,9 m por píxel en escritorio; «Acercar» llega a ~0,6 m. El modo pixel divide la resolución por tres. Por eso:

| Elemento | Medida mínima | Ejemplos |
|---|---|---|
| Líneas y molduras | 0,4–0,5 m (más anchas que las reales) | líneas de la cancha, bandas blancas de la torre, cornisas |
| Vanos (ventanas, puertas) | 0,45 m de ancho, ~1 m de alto | ranuras de la torre de la Catedral |
| Detalle que debe reconocerse | 2–3 píxeles a la escala de la ficha (1,5–3 m) | paneles de focos, puertas, vitrales, emblemas |
| Lo que no se dibuja | menos de 0,4 m | barandas finas, parteluces, cruces de cumbrera, letreros |

Si un detalle desaparece en la captura con modo pixel, se agranda o se quita.

## 3. El lenguaje

- **Peldaños en vez de rampas y curvas lisas.** Una gradería es una fila de peldaños; un arco es un rectángulo con dos escalones encima (`arch()`); una escalinata son dos o tres peldaños. Las curvas de un edificio (ábsides, baptisterios) se hacen con ocho segmentos por semicírculo, con las facetas a la vista. Las curvas de un trazado (la pista atlética) pueden ser más finas.
- **Dos tonos alternados donde la realidad tiene ritmo.** Paños de techo cada 4–12 m, filas de una gradería, franjas de corte del pasto, bandas de un vitral. La alternancia es sutil (un 10–15 % de diferencia de luminosidad): marca el ritmo sin parecer rayado.
- **El blanco como contorno.** Pilastras, bandas, cornisas, zócalos y albardillas en un blanco cálido separan los paños de ladrillo o estuco y dibujan la silueta. Son el equivalente del contorno del pixel art.
- **Vanos oscuros y fríos.** Ventanas y vitrales en azul pizarra casi negro (dos tonos en bandas de 1,5 m para los vitrales), puertas en café oscuro. Contra el ladrillo y el estuco cálidos, se leen como agujeros.
- **Relieve por capas.** Los detalles de fachada son caras paralelas al muro, adelantadas unos centímetros, en capas fijas: 0,06 m para paños y vanos, 0,09 m para bandas horizontales, 0,12 m para lo que va encima de ambos (pilastras, vitrales dentro de un nicho, puertas). Dos detalles a la misma distancia del muro no deben cruzarse, porque parpadean.
- **Volúmenes escalonados.** Los edificios altos se escriben por etapas que se angostan (la torre de la Catedral: zócalo, fuste, retranqueo, balaustrada, campanario, aguja). Cada etapa termina en una banda o cornisa un poco más ancha que el volumen.

## 4. Paleta

Cada modelo define su paleta en un objeto local `K`, con colores tomados de las fotos. Para que los hitos combinen entre sí, parta de estos tonos y ajústelos solo si las fotos muestran otra cosa:

| Material | Colores | Usado en |
|---|---|---|
| Ladrillo | `#A04B34`, sombra `#8F4330` | Catedral |
| Estuco blanco | `#ECE7DC`, sombra `#D3CDC0`, zócalo `#C9C3B6` | Catedral |
| Muro claro | `#D9D2C2`, borde `#EEE8DA` | Estadio |
| Teja | `#A35C42` / `#8E4F3A` | Catedral |
| Techo plano | `#8F8A82` | Catedral |
| Membrana | `#F0EFE9` / `#D8D6CE` | Estadio |
| Vidrio y vitral | `#3B4653` / `#2C3540`; vidrio de oficina `#4D5D66` | Catedral, Estadio |
| Puerta | `#5A4636`; vanos de campanario `#2E2C2B` | Catedral |
| Cobre verde | `#3F5C4E` | aguja de la Catedral |
| Metal | `#3A3A3A` (fierro), `#707070` (mástil) | Catedral, Estadio |
| Pasto | `#5F9840` / `#72AC4D` | Estadio |
| Piedra de escalinata | `#D9D3C5` / `#C6BFAF` | Catedral |

Evite el blanco puro y el negro puro: la escena es el Maule en verano, cálida y algo desteñida (METODOLOGIA §10). Los acentos saturados (asientos rojos, escaleras amarillas) solo donde la realidad los tiene.

## 5. Techos

- Techos inclinados con `roof()`: paños de dos tonos, alero de 0,5 m y albardilla blanca en los hastiales. La pendiente, a ojo desde las fotos (~30° en teja).
- Donde dos naves se cruzan, los techos se intersectan sin más; la cumbrera más baja se mete bajo la más alta.
- Ábsides y torres: medio cono o pirámide (`pyramid()`), que ya alterna dos tonos por cara.
- Techos planos en gris con una banda blanca en el borde.

## 6. Noche

Los modelos dibujados en `S` no tienen ventanas de sombreador: de noche se oscurecen como el resto. La luz se agrega con `GLOW`, poca y donde existe: torres de iluminación, vitrales de una fachada. Si una luz es licencia (no hay fuente de que esté encendida), el comentario del modelo lo dice.

## 7. Herramientas

En la plantilla, `localFrame(X, Y, A)` da el marco del hito (`G`, `V`, `N3`, `R`; METODOLOGIA §9.2). `facade(S, F, K)` da el vocabulario de fachada en ese marco (`F`, lo que devuelve `localFrame`), con la paleta `K` del modelo (usa `tile`/`tile2`, `white`, `glass`/`glass2` y `gable` o `brick`):

| Función | Qué dibuja |
|---|---|
| `WL(a, b, out, o)`, `WV`, `WU` | un muro de a a b (en u, v) con su normal hacia `out`; los detalles van `o` m delante |
| `rect(w, s0, s1, h0, h1, color)` | un paño rectangular sobre el muro (s: distancia a lo largo del muro) |
| `arch(...)`, `glass(...)` | arco escalonado; vitral en bandas de dos tonos con remate escalonado |
| `roof(eje, s0, s1, t0, t1, h, rh, paño)` | techo a dos aguas con paños alternados, alero y hastiales con albardilla |
| `box(u0, v0, u1, v1, h0, h1, muro, tapa)` | un volumen en el marco local |

Las caras verticales llevan su normal explícita (`w.n`, `N3(...)`): el material solo dibuja la cara de frente, y la normal decide hacia dónde mira.

## 8. Revisión

Además de las capturas de METODOLOGIA §9.5, antes de dar por terminado un modelo:

- [ ] La silueta se reconoce en la vista inicial, sin acercar.
- [ ] Al zoom de la ficha se distinguen los elementos que identifican el edificio en las fotos (en la Catedral: el frontis blanco de tres arcos y la torre de ladrillo con aguja verde).
- [ ] En modo pixel, ningún detalle queda como ruido de un píxel.
- [ ] Ninguna cara parpadea al girar la vista (capas a la misma distancia, techos coplanares).
- [ ] Los colores están en la paleta o tienen una foto que los justifique.
- [ ] Las cuatro orientaciones se ven completas: no hay caras faltantes en los lados sin fotos.
- [ ] Los frentes a la sombra (el sur y el poniente) se leen igual: sus detalles no dependen del sol para distinguirse. La sombra del hito no deja manchas en sus propios techos.
- [ ] El comentario del modelo dice qué es aproximado y qué es licencia.
