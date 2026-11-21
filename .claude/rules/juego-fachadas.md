---
paths:
  - "juego/fachadas_ciudad.gd"
  - "juego/modelos/fachadas.gd"
  - "tools/juego_vistas.py"
---

# Las fachadas del juego (fachadas_ciudad.gd)

Cómo se visten de cerca, en el juego, los edificios de la comuna (`juego/fachadas_ciudad.gd`) y los de las calles de la plaza (`juego/modelos/fachadas.gd`): lo que la página registra de cada uno (`FACH`), lo medido en fotos (`config/fachadas.json`) y el repertorio de Talca que sale de ahí. Lo demás del juego, en `juego.md`.

## Comandos

```bash
uv run --with "playwright==1.63" python tools/export.py --teselas juego/mapa --solo-fachadas   # solo los f_<i>_<j>.json de las fachadas de cerca del juego, sin rehacer los glb (~1 min; después de tocar FACH en la página o config/fachadas.json: cp config/fachadas.json juego/datos/)
python3 tools/juego_vistas.py punto 313 110 [--dist 8 --lado 0 --tipo adobe]   # --desde/--girar frente al lado a la calle del edificio más cercano (de juego/mapa/f_*.json)
python3 tools/juego_vistas.py buscar poblacion [--techo x --lados 0,2 --fuente ms -n 3]   # vistas frente a edificios de un tipo, un techo (k) y una fuente
python3 tools/juego_vistas.py tomar shots/antes [--solo adobe,pobl | --vistas vistas.txt]   # una captura por vista (por omisión, las 25 de VISTAS: cada tipo, esquinas del centro, techos, noche; ~8 min), en primera persona, por tools/godot_oculto.sh; imprime los triángulos de fachadas_ciudad.gd
uv run tools/juego_vistas.py hoja shots/h.jpg shots/antes shots/despues -- adobe pobl   # una hoja: cada vista antes sobre después, sin la ayuda de arriba
```

Un cambio en `fachadas_ciudad.gd` no pide `make juego` (lee los mismos `f_<i>_<j>.json`): se toman las vistas antes y después con `tomar` y se comparan con `hoja`; el costo, con `--fps 6` en una vista densa (los condominios de `--desde 241,-2024`), comparando el «GPU» de `fps.gd` en corridas alternadas de una y otra versión (de una corrida a otra varió hasta 1,5 ms).

## Trampas

- **Las fachadas de cerca del juego son un registro por edificio, no la geometría del glb.** Fuera de la plaza (que tiene `modelos/fachadas.gd`), `juego/fachadas_ciudad.gd` viste cada edificio de `f_<i>_<j>.json` según su tipo (`t`: adobe, continua, local, poblacion, pareada, fila, condominio, block, edificio, torre, institucional, galpon), a menos de `CERCA` (280 m, celdas de 125 m en hilos; se dejan de dibujar a `VISTA`, 250 m). El registro sale de la página al exportar (`FACH`, `fachRec()` en `50-city.js`, desde `cityGen()` y `edificio()` de `52-edificios.js`, solo con `window.__KEEP`): lo que allí se dibuja y lo que se registra tiene que coincidir (la altura del alero `h` sobre la base `b`, la cumbrera `rh`, el techo `k`: `g` con los hastiales en los lados 1 y 3 del cuadrilátero del lote, `x` en el 0 y el 2, `h` a cuatro aguas, con la pendiente que da `rh`, o 0,5 en los truncados de OSM y de aprendizaje automático, 0,3 en sus galpones), o la fachada queda corta, asoma sobre el techo o el alero no sigue el faldón; si cambia cómo `cityGen` emite un tipo de casa, cambie también su registro. El registro no saca números de los `rng` ni cambia la imagen de la página. Los lados a la calle son los de `fachFront` (a 4,5 m sale a una calle del mapa; en un lote de `cityGen`, siempre el frente); una casa sin lado a la calle (las de los pasajes de una villa) lleva la puerta en su lado más largo. En el JSON los índices llegan como decimales: `fachadas_ciudad.gd` los pasa a enteros antes de `in`. Un edificio cuyo centro cae en un recorte de `edificios` o `ciudad` no se viste. `config/fachadas.json` corrige por id de OSM el tipo (de `estilo`), los pisos, el color, el marco, el zócalo, el toldo y la planta baja (`pb`: ventanas, sin locales aunque la página los ponga; vitrinas o vidrio, locales del juego); la página toma de ahí el alto, los pisos y el color, así que una entrada nueva cambia los dos (y pide `make build`, `--solo-fachadas` y la copia a `juego/datos/`).
- **La fachada gruesa y los aleros del juego.** Los lados a la calle son un muro `GRUESO` (10–30 cm, por tipo) delante de la caja del glb, con los vanos abiertos y el vidrio o la puerta 3 cm delante de la caja (`FONDO`): la caja sigue detrás, con su colisión y su grilla de ventanas, y el plano lleva la suya (un `StaticBody3D` «fachadas» por celda; sin él, el personaje que se arrima al muro se hunde 30 cm en la fachada). Los demás lados, una piel a 5 cm. Las vitrinas van a 9 cm (`FONDO_LOCAL`), delante de las de `shopFront` (6 cm), y el local de un piso sube su fachada al pretil de 1,8 m de `shopFront`: si cambia uno, el otro. Bajo un alero, la fachada termina en el cielo del alero (`TF` + su grueso por la pendiente), que la tapa; el faldón del alero usa el material de la capa «ciudad» del glb (`Mat.capa`), para que las tejas y el zinc sigan sin costura. El alero y el vuelo sobre el hastial no van donde otro edificio de la tesela está pegado (`vecino()`, a 35 cm del muro: las filas, las pareadas de aprendizaje automático, el adobe de fachada continua); uno de la tesela vecina no se ve, y ahí el alero puede caer sobre su techo. Todo da sombra (las rejas del antejardín sobre la vereda, los aleros, los derrames de los vanos): en noviembre de 2026, con la GTX 1650, la fachada gruesa con sombra costó 0,1–0,3 ms de GPU más que las pieles planas sin sombra de antes.
