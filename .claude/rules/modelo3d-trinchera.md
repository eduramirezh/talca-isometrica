---
paths:
  - "modelo3d/modelos/trinchera_ruta5.gd"
  - "modelo3d/modelos/entorno/trinchera.gd"
---

# La Ruta 5 en trinchera en 3D (trinchera_ruta5.gd)

La página no puede dibujar la trinchera de la Ruta 5 bajo los pasos de la ciudad (trampa «La Ruta 5 va en trinchera y el relieve no la puede dibujar», `rios-vias.md`): sube los pasos 2–4 m con una abertura oscura. El 3D sí: `modelo3d/modelos/trinchera_ruta5.gd` recorta de las teselas todo lo que cae en el corredor de la autopista (todas las capas: el terreno, la Ruta 5 y sus autos, los árboles, los faroles) y el paso de la página (`hitos`, `veredas`), y lo arma de nuevo a su altura con `modelos/entorno/trinchera.gd`. Hoy, dos tramos (`TRAMOS`): de 2 Norte a San Miguel (el Cruce Varoli), con sus dos pasos y los ramales a 20 y 21 Oriente, y el de 8 Sur. Lo demás del mapa (las caleteras, las calles, los edificios) es el de la página.

## Arquitectura

| Archivo (`modelo3d/modelos/`) | Qué hace |
|---|---|
| `trinchera_ruta5.gd` | `TRAMOS`: por tramo, «y» (de sur a norte), «hondo» y «muro» (m, por tramos lineales de y: cuánto va la calzada bajo el suelo y el alto del muro vertical; lo demás es talud) y «pasos» (las polilíneas y medio ancho de `hitos/enlaces-ruta-5.js`). Espera las teselas de cada tramo y lo arma en dos cuadros: el suelo (con colisión) y lo demás (defensas, cierros, postes, pasos, autos); sus lámparas van a `faroles.gd agregar_fijas()`. `pendiente(p)`, para `mundo.gd solido()`. `--sin trinchera` lo apaga, para comparar con `--fps` |
| `entorno/trinchera.gd` | Un tramo: lee `datos/ruta5.json` como la página (`R5C`, `r5at`, `R5R` de `66-ruta5.js`: `en()`, `off()`, `borde()`, `proyectar()`), recorre cada calzada cada 2 m y arma su sección de la mediana hacia afuera (mediana de tierra, defensa, calzada con sus líneas de 12–15 cm, cuneta, muro de moldaje, tapa, talud de pasto seco, franja y cierro de malla); los ramales de la página (`R5.k`) que van bajo el suelo entran en la sección, con su altura de la junta a la calle; los pasos: tablero de punta a punta a la altura de la calle, losa, parapeto, baranda de malla, pilas en la mediana; postes de dos brazos cada 45 m; unos autos de `auto.gd` |

Los dibujos que usa (`moldaje`, `maleza`, `rejilla`) están en `shaders/patron.gdshader` y sirven a cualquier modelo: `maleza` y `tierra` los usan también los perfiles medidos (`entorno/perfil.gd`, `cruce.gd`) y `rejilla` todo cierro «malla» de `mobiliario.gd`.

## Comandos

```bash
tools/godot_oculto.sh --path modelo3d -- --png shots/t.png --desde 2683,-290 --girar 195 --mirar 4 --camara 6   # dentro de la trinchera, hacia el paso de San Miguel (como las fotos de Mapillary desde la autopista)
tools/godot_oculto.sh --path modelo3d -- --png shots/t.png --desde 2672,-400 --girar 15 --mirar 6 --camara 5    # bajo el paso de San Miguel
tools/godot_oculto.sh --path modelo3d -- --fps 6 --desde 2660,-420 --mirar -30 --camara 150 [--sin trinchera]  # lo que cuesta
```

Un tramo nuevo se lee en las fotos de la autopista (una cada 40 m en cada sentido: la más nueva de cada franja de y a menos de 6 m de una de las líneas de `data/ruta5.json`, de `raw/mapillary/imagenes.json`) y de la imagen de Esri (`pipeline/traces.py vial x0 x1 y0 y1 18`): dónde están los muros, cuán alto es cada uno y dónde la autopista vuelve a nivel.

## Trampas

- **Un modelo que recorta el terreno no puede leerlo ahí.** `modelos/entorno/suelo.gd` lee la malla `terreno` de las teselas ya recortadas: dentro del corredor no queda nada y `S.E()` extrapola de otros triángulos de su celda (salían muros de 10 m). `trinchera.gd` toma el suelo de cada estación en el borde del recorte, un poco afuera (`gb`), y el de la calzada del promedio con la estación de la otra calzada (`gref`), para que las dos mitades de la mediana se junten. Y mientras el modelo no está armado, ahí no hay colisión: un rayo no da en nada (`ver.gd` ponía la cámara bajo la ciudad, y el personaje del juego caería). `mundo.gd solido(x, y)` espera también a los modelos con `pendiente(p)`; quien pone algo sobre el suelo usa eso, no `mapa.solido()`.
- **El recorte sale de los datos, no del relieve.** `recortes()` se pide al armar el mundo, antes de cargar una tesela: el ancho del talud se calcula con un suelo plano ((hondo − muro) / `TALUD`) y, al armar, el talud llega al borde del recorte a la altura del suelo de ese punto, así que calza con el terreno de la tesela sin costura aunque el suelo no sea plano. Un ramal entra en la sección donde va más de `RAMAL_HONDO` bajo el suelo, con su profundidad repartida a lo largo entre la junta (la de la calzada) y la calle (0), también de los datos.
