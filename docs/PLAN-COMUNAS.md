# Otras comunas: cuánto de Talca está fijo en el código

Diagnóstico del 14 de noviembre de 2026. La pregunta: ¿se puede hacer la maqueta de otra comuna chilena con este mismo código, y qué hay que cambiar para eso? Se revisaron `pipeline/`, `src/js/`, `src/page.html`, `config/` y `data/`. Como caso de prueba se tomó **Curicó**: es la otra ciudad que trae cicloconecta (`data/cities/curico/nav_graph.json`), está en la misma región que Talca (los mismos archivos del Censo, de CONAF y de CIREN) y tiene el mismo tipo de ciudad: damero colonial, Plaza de Armas, Ruta 5, Línea Central y un cerro junto al centro (el Condell).

Lo que no se hizo: correr el pipeline para Curicó. En la sesión del diagnóstico no estaba `raw/` y la API de OpenStreetMap no era alcanzable. Las cifras de Curicó salen del grafo de cicloconecta, que sí se pudo bajar de GitHub; el resto queda como pendiente en §7.

## Resumen

- **El motor es casi todo genérico.** El terreno, la ciudad generada, los edificios de OSM y de aprendizaje automático, los usos de suelo, los ríos, la Ruta 5, la vía, el pixel art, las teselas, el arranque en dos etapas y la exportación leen `DATA`, no a Talca.
- **Talca está fija en cinco capas,** de la más fácil a la más difícil de cambiar:
  1. parámetros del pipeline (origen, giro, códigos de comuna, tesela de elevación);
  2. código de la página que nombra lugares de Talca o usa sus coordenadas;
  3. calibraciones de la ciudad generada, que no fallan pero se verían distintas;
  4. contenido curado a mano (lugares, hitos, correcciones);
  5. la identidad del sitio.
- **Tamaño.** Los hitos de `src/js/hitos/` (45 archivos) pesan 346 KB: la mitad del JavaScript. El resto del script son 332 KB, casi todo genérico. El pipeline son 340 KB de Python, casi todo genérico salvo los parámetros.
- **Una Curicó sin hitos parece alcanzable.** Al cambiar las capas 1 y 2 y regenerar los datos saldría un mapa de sus manzanas, calles, ríos, ruta, vía, edificios y usos de suelo, pero sin hitos, con pocos lugares y con la ciudad generada calibrada para Talca. Llegar al nivel de Talca (hitos, lugares con ficha, correcciones de manzanas y usos) sería el mismo trabajo de meses que tuvo Talca.
- **La condición:** Talca no puede cambiar. Cada paso se verifica con `tools/regress.py --against` y 0 píxeles distintos.

## 1. Parámetros del pipeline

Cambiarlos es mecánico, pero hoy están en el código y no en un archivo de configuración.

| Qué | Dónde | Talca | Curicó |
|---|---|---|---|
| Origen (centro de la plaza) | `common.py` `LAT0, LON0`; también `tools/export.py` `ORIGEN` | −35,42653; −71,66600 | −34,9854; −71,2394 (el `center` de cicloconecta: hay que medirlo en OSM) |
| Metros por grado de longitud | `common.py` `KX`: `cos(35.4265)` escrito a mano | | sacarlo de `LAT0` |
| Giro de la grilla | `common.py` `TH` | +5° | **−5,9°** a 600 m (89 % del largo a ±2°), −5,4° a 1,2 km (`pipeline/grilla.py`) |
| Límite de la comuna | `common.py` `COMUNA_OSM`, caché `raw/osm/comuna-talca.json` | relación 541797 | buscar la relación `admin_level=8` |
| Caja de la maqueta | `common.py` `EXT`, escrita a mano | (−4920, 15800, −10840, 13000) | calcularla del límite, ajustada a la grilla de 40 m |
| Comuna del Censo 2017 | `process_geometry.py` `COMUNA = '7101'`; archivos `R07_MANZANA_*` | 7101, región 07 | 7301, región 07 (los mismos archivos) |
| Grafo de calles | `common.py` `NAV_GRAPH` (`cities/talca/`) | 19 MB | `cities/curico/`, 9,9 MB |
| Elevación | `elevation.py` `COP`, `HGT`: **una** tesela fija | S36W072 | S35W072, y quizás más de una (ver §5) |
| Fuentes chilenas | `fuentes_cl.py`: archivos y consultas del Maule, `CUT=7101` (MINVU, Censo 2024); `usos.py escuelas`/`salud`: `'7101'` | 7101 | 7301 |
| Paneles | `diagnostics.py`: nombres de comunas vecinas (`TALCA`, `MAULE`, `PENCAHUE`, `SAN CLEMENTE`) | | las vecinas de Curicó |

Las rutas de `raw/`, `data/` y `config/` son únicas (`common.py`; `TALCA_RAW` cambia solo `raw/`), así que dos ciudades no pueden convivir en el repositorio sin un directorio por ciudad (§6, fase 3).

### El giro de la grilla

El giro se mide con `pipeline/grilla.py`, que repite la medición de METODOLOGIA §3 sobre un grafo de cicloconecta o un JSON de la API map de OSM:

```
$ python -I pipeline/grilla.py talca/nav_graph.json -35.42653 -71.66600
600 m: pico en 85.0°, 79% del largo a ±2° (24 km de calles); giro de la grilla +5.0°
1200 m: pico en 85.1°, 50% del largo a ±2° (102 km de calles); giro de la grilla +4.9°
$ python -I pipeline/grilla.py curico/nav_graph.json -34.9854 -71.2394
600 m: pico en 5.9°, 89% del largo a ±2° (23 km de calles); giro de la grilla -5.9°
1200 m: pico en 5.4°, 51% del largo a ±2° (96 km de calles); giro de la grilla -5.4°
2500 m: pico en 83.0°, 22% del largo a ±2° (351 km de calles); giro de la grilla +7.0°
```

En Talca da los +5° de `common.TH`. El centro de Curicó es una grilla tan regular como la de Talca, girada hacia el otro lado. A 2,5 km ya no hay un pico claro: los barrios nuevos tienen otra orientación, como en Talca, donde el pico también cae a menos de un tercio del largo. Una ciudad sin damero (Valparaíso, Viña del Mar) no tendría un giro que alinee sus calles con los ejes isométricos. La maqueta igual funcionaría, pero las calles se verían en diagonal escalonada en el pixel art (trampa «Líneas de 0,5 m en un marco girado»).

## 2. Código de la página que nombra a Talca

Hay dos tipos: lo que **falla** (un `TypeError` en el arranque, la página no carga) y lo que **sale mal en silencio** (algo de Talca dibujado en otra parte, o nada).

| Archivo | Qué | Con otra comuna |
|---|---|---|
| `72-alameda.js` | `PLAZA_BI` lee `BYID['plaza-de-armas']` | **falla** si no hay un lugar con ese id |
| `90-overlay.js` | las etiquetas de los ríos: doce puntos de grilla con claves de `DATA.water` (`claro`, `lircay`, `piduco`, `panguilemo`, `pencahue`) | **falla** (`dec(undefined)`) si falta un río |
| `pipeline/build.py` | `data/golf.json` es obligatorio (`require`) | **falla** el build sin él (es del Talca Country Club) |
| `74-cerro.js` | `buildCerro()`: el santuario del Cerro La Virgen en el marco fijo (−3401, 118) y `MODELS['cerro-la-virgen']`; `99-boot.js` lo llama siempre | en silencio: dibuja el santuario en ese punto, haya cerro o no |
| `62-diagonal.js` | `DIAG`: los extremos y el eje de la Diagonal en coordenadas de grilla; `walkBase` llama siempre a `diagonalBase()` | en silencio: puede dibujar tramos de bandejón donde caigan esas coordenadas |
| `50-city.js` | `Math.hypot(b.cx+8, b.cy+7)` (dos veces): el centro de la manzana de la plaza de Talca, a 8 y 7 m del origen | en silencio: la distancia al centro queda corrida unos 10 m |
| `70-trains.js` | `ST`: la estación de Talca en (1519, −205); los trenes y su horario son los de Talca; `trainsInit()` no corre sin ramal | sin ramal en servicio (Curicó no tiene) no hay trenes; con ramal, una estación en el lugar equivocado |
| `72-alameda.js` | `ALAM`: las franjas de parque de toda calle con «Alameda» en el nombre | Curicó tiene la Alameda Manso de Velasco: puede funcionar o no, según si sus franjas cumplen las condiciones (sin datos del Censo, menos de 80 m de fondo) |
| `10-decode.js` | `STREET_W` (Avenida Isidoro del Solar), `PASEOS` (`^Paseo Peatonal`) | inofensivo si no calza; si calza, aplica el ancho de Talca |
| `90-overlay.js` | solo rotula calles locales con nombre de grilla numerada (`^\d+ (Norte\|Sur\|Oriente\|Poniente)$`); `RURAL` (Avenida San Miguel → Ruta 115-CH) | en Curicó, donde las calles tienen nombre (Merced, Yungay, Prat…), solo se rotularían las de clase 3 o menos |
| `25-terrain.js` | `RELIEF_A`, `RELIEF_K`: la exageración del relieve, calibrada para el llano de Talca | ver §3 |
| `45-landmarks.js`, `hitos/` | los 45 hitos y su `ORDER` | `ORDER` vacío funciona; cada hito necesita su lugar en `BYID` |
| `src/page.html` | título, descripción, canónica, Open Graph, «San Agustín de Talca · 1742 · 35°25′ S 71°40′ O», la pestaña «Acerca» con las cifras de Talca, el `aria-label` del mapa | texto de Talca |

Lo demás (`05-categories.js` con las capas jurídicas, `86-camera.js` con la vista en el origen, `60-streets.js` con densidades según la distancia al origen) es genérico, porque el origen es siempre la plaza.

## 3. Calibraciones

No fallan, pero son números elegidos mirando a Talca:

- **Los barrios** (`50-city.js`): `styleFor()` llama `core` a lo que está a menos de 720 m (o 1.250 m con poca densidad); `houseRecipe()` reparte las recetas en anillos de 1.400 y 2.600 m; los galpones van a más de 1.250 m; los almacenes, a menos de 1.100 m; los edificios de 5 a 10 pisos, a menos de 1.000 m. Curicó tiene unos dos tercios de la población de Talca y un centro más chico: esos radios deberían escalar con el tamaño de la ciudad, por ejemplo con el radio del área construida o la población.
- **Los árboles de vereda** (`60-streets.js`): densidades por estilo y a menos de 450 m del origen.
- **El relieve** (`relief()`): tres veces en el llano, la mitad a 50 m. Curicó también está en el valle central, pero el Condell y la precordillera habría que mirarlos de cerca.
- **La vista inicial** (`HOME_ZOOM`) y los pósters del arranque, que son capturas de Talca.

## 4. Contenido curado

Esto no se porta: se rehace para cada ciudad. Separando lo que se puede regenerar de lo que es trabajo a mano:

| Archivo | Qué | ¿Regenerable? |
|---|---|---|
| `pipeline/pois.py` | 79 lugares con ficha, fuente y confianza; recorridos (`TOURS`) | a mano |
| `src/js/hitos/` | 45 hitos, 346 KB | a mano (los ayudantes, como `deckBridge`, `facade`, `localFrame`, `r5Raise` o `railGirder`, sí sirven) |
| `config/usos.json` | 650 usos: 623 importados de OSM, 23 leídos en la imagen, 4 del MINVU | los de OSM sí (`usos.py importar comuna`); el resto, a mano |
| `config/usos-ciren.json`, `usos-censo2024.json`, `usos-minvu.json` | huertos, villas nuevas, plazas | sí, con el código de comuna (§1) |
| `config/trazados.json` | 5 ríos con sus ids de OSM, la vía, el ramal y la Ruta 5 | semiautomático: `traces.py line`, `railway.py write` |
| `config/manzanas.json` | 9 manzanas «sin información» construidas y 3 parques | a mano, con `satellite.py` |
| `config/edificios.json` | dónde OSM está completo (2 áreas) y correcciones | a mano, con `edificios.py panel` |
| `config/techos.json` | la familia de techo de cada edificio de OSM | sí (`edificios.py techos`, de la imagen de Esri) |
| `config/rutas.json` | nombres de rutas corregidos con el MOP | semiautomático (`rutas.py check`) |
| `config/grid_lines.json`, `pipeline/geocode.py` | la numeración de las calles de Talca | solo Talca (el mapa ya no los usa) |
| `data/golf.json` | el Talca Country Club | solo Talca |

## 5. Las fuentes en otra comuna

| Fuente | Curicó |
|---|---|
| Censo 2017 (manzanas, `chile_geojson`) | los mismos archivos `R07`, comuna 7301 |
| cicloconecta | tiene Curicó; a largo plazo conviene sacar las calles solo de OSM (`raw/osm/map-comuna.json`, que ya completa el grafo fuera de la ciudad), porque cicloconecta solo tiene dos ciudades |
| OpenStreetMap (límite, calles, ríos, vía, Ruta 5, edificios, usos) | igual, por la API |
| Copernicus GLO-30 | otra tesela; `elevation.py` hoy lee una sola |
| CONAF 2024, CIREN 2022 y 2024 | los mismos archivos del Maule |
| MINVU 2023, Censo 2024, MINEDUC, DEIS | los mismos servicios con el código 7301 |
| Overture (Microsoft, Google), Google 2.5D | globales |

**El tamaño de la comuna.** La de Talca mide 232 km². La de Curicó es varias veces más grande (cerca de 1.300 km² según las fuentes habituales; hay que confirmarlo con su límite de OSM) y llega hacia la precordillera. Muchas trampas de CLAUDE.md son de rendimiento y crecieron al pasar Talca de su caja a la comuna («Lo que recorre todos los nodos del relieve», «`occ` no es un arreglo», «Una malla sobre toda la comuna se dibuja entera»). Con cinco veces el área, la generación y la memoria crecen en proporción. La primera Curicó convendría recortarla a un polígono menor que la comuna, por ejemplo el área urbana con un margen. El código ya recorta todo a `DATA.limit`, así que basta con que ese polígono sea otro.

**Licencias.** `config/techos.json` y `data/golf.json` se derivan de la imagen de Esri World Imagery. El README dice que nada de esa imagen se redistribuye, pero las clasificaciones derivadas de ella sí van en el repositorio y en el sitio. Antes de repetirlo para otras ciudades (y sobre todo si las maquetas se ofrecen como datos abiertos) conviene revisar los términos de Esri o reemplazarla por Sentinel-2 (`tools/sentinel.py`), que es libre pero de 10 m.

## 6. Plan propuesto

Cada fase deja a Talca idéntica: `tools/regress.py --save shots/ref` antes y `--against shots/ref` después, también con `--init "window.__STAGE=0"`.

1. **Medir (hecho).** Este documento y `pipeline/grilla.py`.
2. **Parametrizar sin cambiar Talca.** Un archivo por ciudad (por ejemplo `config/lugar.json`) con el nombre, el origen, el giro, la relación de OSM del límite (o el polígono que recorta), el código de comuna, la región y las teselas de elevación. `common.py` lo lee, calcula `KX` y `EXT`, y `build.py` lo pasa a la página como `DATA.lugar`. `elevation.py` acepta varias teselas. `golf.json` pasa a ser opcional.
3. **Sacar a Talca del motor.** Lo de §2 pasa a hitos o a datos:
   - `buildCerro()` se vuelve un hito (`hitos/cerro-la-virgen.js`), con su clave 2e7 intacta;
   - la Diagonal se vuelve un hito o una entrada de configuración;
   - las etiquetas de los ríos van a `config/trazados.json`;
   - la estación de los trenes se lee de un lugar;
   - el centro de la manzana de la plaza sale de `MODELS['plaza-de-armas']`, o la plaza se toma del origen si no hay hito;
   - `PLAZA_BI` tolera que falte la plaza;
   - los nombres de calles especiales (`STREET_W`, `PASEOS`, `RURAL`, `Alameda`) y la regla de rótulos van a la configuración;
   - el texto de `page.html` toma lo suyo de `DATA.lugar` o de una plantilla por ciudad.

   Lo más delicado es el orden de las claves y de los `rng` (trampas «El arranque en dos etapas» y «El orden de la ciudad»): mover código no puede cambiar en qué orden se crean las mallas ni qué números sale de cada `rng`.
4. **Un directorio por ciudad.** `ciudades/<id>/` con su `config/`, `data/`, `hitos/` (y `ORDER`), lugares y `site/`; `make CIUDAD=curico build` arma `dist/curico/`. Mientras haya dos ciudades, conviene un solo repositorio: separar el motor de los datos se decide cuando la segunda funcione.
5. **Curicó mínima.** El límite (o el área urbana), las manzanas, las calles, la elevación, los ríos de OSM, la Ruta 5, la vía, los edificios, los usos importados y un solo lugar, la plaza. Ningún hito. Pasa `make smoke` y se compara con la imagen satelital (`satellite.py`). Con eso se ven las calibraciones de §3 en una ciudad que no es Talca.
6. **Después.** Calles solo de OSM (sin cicloconecta), calibraciones que escalan con la ciudad, los hitos de Curicó que alguien quiera modelar y exportaciones georreferenciadas (glTF o 3D Tiles en un sistema de referencia estándar, con el relieve sin exagerar) para que las maquetas sirvan fuera del sitio.

Una estimación gruesa: las fases 2 a 5 son trabajo de semanas, no de meses, porque casi todo es mover parámetros y comprobar que Talca no cambia. Lo largo es lo que hace a Talca ser Talca: los hitos y las correcciones a mano.

## 7. Pendiente de comprobar

- El centro de la Plaza de Armas de Curicó en OSM (el de cicloconecta es aproximado) y la relación de su límite comunal.
- El área de la comuna de Curicó y cuántas teselas de Copernicus cubre.
- Si la Alameda Manso de Velasco tiene franjas que `ALAM` reconozca.
- Correr `make fetch`, `make osm` y `make data` con los parámetros de Curicó. Ahí saldrán las trampas que este diagnóstico no ve, como las que salieron con cada fuente nueva de Talca.
