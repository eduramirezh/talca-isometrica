# Proyectos similares e ideas tomadas

Investigación hecha antes de construir la maqueta (septiembre de 2026).

## Isopolis San Francisco (Vivek Aithal, @nuwandavek)

Es el «mapa isométrico de San Francisco con lugares del mundo tech».

- **Enlaces.** Sitio: https://sf.isopolis.city/. Notas técnicas del autor: https://sf.isopolis.city/dev.html. Hacker News: [«Show HN: Isopolis»](https://news.ycombinator.com/item?id=49149966), 350 puntos, agosto de 2026.
- **Cómo se hizo.**
  - Google Photorealistic 3D Tiles renderizados en three.js con cámara ortográfica fija (azimut 22,5°, elevación 30°), capturados con Playwright.
  - Arte de referencia con Nano Banana y un ajuste fino LoRA de Qwen-Image-Edit para convertir las capturas a pixel art.
  - Visor propio en canvas, con un mapa base CARTO deformado debajo.
- **Funciones.** Capa GeoJSON de letreros, «monedas» de empresas, barrios con hover y clic, recorridos guiados, postales para compartir, música y efectos.
- **Críticas.** Errores de la IA (calles convertidas en ríos, sombras tomadas por lagos), píxeles borrosos y una ciudad plana.

## Isometric NYC (Andy Coenen)

- **Enlaces.** https://isometric.nyc. Explicación: https://cannoneyed.com/projects/isometric-nyc. Hacker News: [1.325 puntos](https://news.ycombinator.com/item?id=46721802).
- **Cómo se hizo.** Google 3D Tiles con render ortográfico, Qwen-Image-Edit ajustado con unos 40 pares de imágenes y un visor de zoom profundo (OpenSeadragon).
- **Lo que pidieron los usuarios.** Enlaces a coordenadas, nombres de calles, rotación de 90° y agua animada.

## Otros

- [Google Maps Mania: Isometric San Francisco](https://googlemapsmania.blogspot.com/2026/08/isometric-san-francisco.html)
- **sf.thijs.gg** («SF as a video game»): Gaussian splats; criticado por su consumo de memoria.
- **isocity**, de victorqribeiro: un constructor de ciudades en canvas puro que guarda el estado en la URL.
- **Streets GL**: render 3D de OSM con ciclo de día y noche.
- **IsometricBlocks**, de Shaun Lebron: orden de dibujo de cajas isométricas.

## Qué se tomó y qué se hizo distinto

| Idea | En Talca Isométrica |
|---|---|
| Vista fija de simulador | Cámara ortográfica 2:1 (elevación 30°), con giro de 90° (lo pidieron los usuarios de NYC) |
| «Monedas» de empresas | Monedas por institución, con ícono y color por categoría y filtros por capa |
| Recorridos guiados | Ruta de la Justicia y Talca icónica, con progreso y anterior/siguiente |
| Enlaces a un punto | `#id` por lugar o recorrido (la plataforma solo admite un identificador simple) |
| Nombres de calles | Etiquetas giradas según la calle, con interruptor y sin superposiciones |
| Edición de nieve y noche | Modo noche con ventanas y faroles; modo pixel opcional |
| Imágenes de IA | **No.** Geometría real dibujada en el navegador, para que calles y manzanas estén donde corresponden y se evite el aspecto difuso de la IA |
| Página de créditos honesta | Pestaña «Acerca» con fuentes y limitaciones, más esta documentación |
