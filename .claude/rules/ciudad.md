---
paths:
  - "src/js/20-grids.js"
  - "src/js/50-city.js"
  - "src/js/60-streets.js"
  - "src/js/62-diagonal.js"
  - "src/js/63-paseos.js"
  - "src/js/64-base.js"
  - "src/js/72-alameda.js"
  - "config/manzanas.json"
---

# La ciudad generada (cityGen, lotes, calles)

Los lotes de `cityGen`, el orden de las calles, la Alameda y los estilos de manzana.

## Arquitectura

| Archivo (`src/js/`) | Qué hace |
|---|---|
| `20-grids.js` | `blockAt` (celdas de 100 m; `blockIs(x, y, bi)` es `blockAt(x, y) === bi`, más barato; las dos prueban cada manzana con `inBlock`, que después de `BK_N` consultas usa un raster de su caja: afuera, adentro o con un borde cerca, y solo eso va a `pipXY`), `segsAt(x, y)` y `segsInBox(x0, y0, x1, y1, f)`: los tramos de calle de la grilla de 40 m (`nearStreet` y todo lo que pregunta «¿hay una calle aquí?»), raster de ocupación `occ` (2,5 m) para que los edificios no se superpongan (1: hitos, ríos y líneas; 2: lotes de la ciudad), un `Grid` en bloques de 128 × 128 celdas (`occ.get(gx,gy)`, `occ.set(gx,gy,v)`; `occ.keep(true)` guarda cada bloque antes de su primera escritura y `occ.was`/`occWas` leen el raster como estaba entonces); `urbanAt` (el área urbana: celdas de 100 m junto a una manzana construida) |
| `50-city.js` | `CITY_ORDER`: las calles en el orden en que `cityGen` pone sus lotes, de la más cercana a la Plaza de Armas a la más lejana (trampa «El orden de la ciudad»); `blockTrees(bi)`: los árboles de parque y de patio de cada manzana, con una cuota fija (`YARD_K`). `styleFor()` clasifica cada manzana (core, core2, ind, apt, house; la distancia a la plaza, desde `PLAZA_C`, 11 m del origen que usan `cityGen` y `CITY_DIST`: mover cualquiera de los dos cambia la ciudad); `barrios()` agrupa las manzanas construidas en barrios (Voronoi de semillas cada `BAR_G` m) y les da una receta según distancia a la plaza y densidad (`recipeOf(bi)`: antiguo, pob, pareada, fila, condo; bloques para `apt`; galpones en las manzanas grandes casi vacías). `cityGen(B, Y)` recorre cada tramo de calle por ambos lados y coloca casas, cada una sobre su lote: una losa en `Y` (sin ventanas) que llega al medio de la manzana, con alas, construcciones al fondo, mediaguas y árboles de patio. Techos por familia en dos tonos (`CP.roof`, mezclas `MIX`), `hipRoof()`, `lotWalls`/`lotGable` (pareadas y filas sin muros interiores), almacenes en esquinas y avenidas (`shopFront`), galpones de dos aguas, diente de sierra y bóveda con estanques. Lo que no lleva ventanas va en `Z`, una malla propia que crea `cityGen`. Los lotes se prueban entre sí como rectángulos exactos (`LOTS`, `lotFree`, `sepQuad`) |
| `72-alameda.js` | la Alameda: `ALAM` (las franjas de parque en el medio de la avenida), `alamedaPlan()` (la plaza de cada tramo, centrada en un hito; trampa «El punto de un edificio junto a la Alameda»), `alamedaGround()` y `alamedaPark()` (paseo, plazas, faroles y álamos), que saltan los tramos de `ALAM_OWN`: los que un hito dibuja enteros (`hitos/juegos-alameda.js`, entre 3 y 4 Oriente); también `PO_FIELD` y `PLAZA_BI` |

## Trampas

- **Calles bajo las manzanas.** Las manzanas del censo pueden contener pasajes interiores. Por eso las calles se dibujan encima de las manzanas (y 0,12–0,15 contra 0,10) y los edificios se generan a lo largo de las calles, no del borde de la manzana.
- **El orden de la ciudad.** `cityGen()` recorre las calles por su distancia a la plaza (`CITY_ORDER`), no por su índice, y cada calle tiene su propio `rng`: los lotes solo compiten con los de calles cercanas (`lotFree`), así que la ciudad hasta una distancia d depende solo de las calles más cercanas que d más el alcance de un lote (~130 m), y se puede generar primero sin cambiar el resultado. Por lo mismo, los árboles de cada manzana (`blockTrees`) tienen una cuota fija sacada del censo: con un presupuesto compartido, los de cualquier manzana dependerían de todos los parques. Algo nuevo en la ciudad no puede depender del orden de las calles ni de un contador global (un `rng` compartido entre calles, un presupuesto): rompería el arranque progresivo.
- **Lotes y `occ`.** `cityGen()` marca sus lotes con 2 y sus pruebas solo ven el 1: lo que había antes. Lo que se genere después (árboles, el parque de la Alameda) ve ocupado todo lo que no es 0. Un hito nuevo marca con `occMark(q)` (valor 1) antes de la ciudad.
- **Estilos de manzana que no aparecen.** Fuera del centro, toda manzana del censo con datos tiene personas o viviendas, así que `styleFor()` nunca da `ind` ni `core2` allí: solo `core`, `house` y `apt`. Los galpones salen de la receta (`recipeOf(bi).ind`, manzanas de 2 ha o más con menos de 8 viviendas por hectárea, a más de 1.250 m de la plaza), no del estilo. `streetTrees()` y `parkedCars()` siguen leyendo `styleFor()`.
- **Lo que no es fachada, en `Z`.** Letreros, cortinas, vitrinas, antepechos, galpones, estanques y muros de patio de la ciudad van en `Z` (sin ventanas de sombreador, proyecta sombra), que `cityGen` agrega a la escena. En `B` les saldrían ventanas. Los detalles van 6 cm delante del muro, como en los hitos.
- **Filas de casas sin muros interiores.** Las casas en fila (`row`) no dibujan el muro entre una y la siguiente: el extremo abierto de la última queda pendiente (`pend`) y se dibuja si la siguiente no se junta (otra altura de suelo, otro fondo, un hueco). Cualquier tipo nuevo que se coloque en un costado de calle tiene que pasar por `flush()` antes de emitir, como los demás.
- **`NOLOTS` es caro.** `cityGen()` prueba cada polígono de `NOLOTS` en cada paso de 5 m de cada calle: con los ~300 usos de suelo sobre manzanas construidas costaría ~2 s de generación. Los usos dejan fuera la ciudad con `occ` (un lote se prueba cada 2,5 m y es más profundo que el margen que queda junto a la calle); `NOLOTS` queda para los recintos de los hitos.
