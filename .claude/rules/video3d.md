---
paths:
  - "tools/video3d.py"
  - "config/video3d.json"
  - "modelo3d/recorrido.gd"
---

# El video de la maqueta en 3D (tools/video3d.py)

Un video del 3D por un recorrido de cámara escrito como datos: `config/video3d.json` (la apertura con el mapa isométrico, las tomas y el cierre; cada toma, sus claves de cámara en metros de grilla, su duración, la hora al comenzar y al terminar y su texto) → `tools/video3d.py` → `shots/video3d/talca-3d.mp4` y su hoja. Cada toma es una corrida de Godot con Movie Maker (`--write-movie … --fixed-fps 30 -- --recorrido toma.json`) por `tools/godot_oculto.sh`; `modelo3d/recorrido.gd` mueve la cámara y la hora (su encabezado dice el formato de una toma), y `video3d.py` corta los cuadros de la toma, la revisa, le pone su texto (Pillow, las tipografías del sitio) y une todo con ffmpeg. Lo demás de `modelo3d/`, en `modelo3d.md`.

## Comandos

```bash
make video3d                     # o uv run tools/video3d.py: graba las tomas que cambiaron (su entrada, el tamaño, la exportación o el código de modelo3d/; ~75–140 s cada una) y arma el video (~10 min desde cero)
uv run tools/video3d.py --cuadros [--solo torre --instantes 0,4.5,9]   # tres cuadros de cada toma (o esos segundos) con su texto, y una hoja: para encuadrar (~20 s por toma)
uv run tools/video3d.py --montar     # solo el montaje (textos, orden, fundidos), con las tomas ya grabadas (~1 min)
uv run tools/video3d.py --vertical   # además, el corte de 1080x1920 (las claves de «claves_vertical» de cada toma; aún sin encuadrar)
tools/godot_oculto.sh --path modelo3d -- --recorrido toma.json --png x.png --instantes 0,3   # una toma suelta, sin video.py: x-t0.00.png, x-t3.00.png
```

## Trampas

- **Una toma que se mueve carga su camino antes.** El mapa carga en hilos alrededor de la cámara, y Movie Maker graba también los cuadros de la carga: una cámara que se mueve vería aparecer teselas y fachadas a media toma. `recorrido.gd` recorre antes el camino: mide el suelo bajo el punto, pone los lugares de la cámara en `mapa.fijos` (cuentan como la cámara para cargar y soltar teselas, medias y fachadas de cerca; solo donde va a menos de 1.500 m de altura), espera a que todo esté, deja el mapa quieto (`mapa.quieto`: no carga ni suelta nada) y pone los árboles de la plaza en todos los cargados (`arboleda.gd todos_de_cerca()`; en el visor, a menos de 130 m, y el cambio de forma se veía al acercarse). Recién entonces corre, y imprime cuántos cuadros son de la toma: `video3d.py` se queda con esos, del final. Lo que no se cargó se ve como `lejos.glb` (sin campos): una toma que se aleja hasta ver la comuna entera lleva `toda_la_comuna` (las 1.028 teselas, 13 s, con las copas y las capas chicas sin fin de vista). El rayo del suelo toma solo las capas de suelo de las teselas (la colisión de la Torre Talca lo detenía en su techo) y espera a dar en algo: que `mapa.solido()` diga que la colisión está no basta, la recién puesta puede no estar aún en la física, y lejos de la plaza la cámara partía fuera de lugar y saltaba a su sitio en el primer medio segundo.
- **Godot no dibuja una ventana tapada.** Si ninguna de sus ventanas está a la vista, Godot no dibuja, y en el Mac la de `godot_oculto.sh` queda tapada a ratos (con la pantalla apagada, siempre): Movie Maker grababa el último cuadro una y otra vez (la toma congelada, y más corta de grabar) y una captura esperaba para siempre. `recorrido.gd` y `mundo.gd png()` se registran como salida adicional (`DisplayServer.register_additional_output()`, lo que usa un casco de realidad virtual) y Godot dibuja igual. `video3d.py` revisa igual cada toma (`congelada()`, con `freezedetect` de ffmpeg; `tirones()`: un cuadro que cambia más de tres veces lo que sus vecinos, o casi nada con la cámara en movimiento) y la vuelve a grabar si algo salió mal; corre Godot con `caffeinate -d -i` y mata una corrida que pasa de 10 min.
