# Fuentes, licencias y atribución

## Datos geográficos

| Dato | Fuente | Licencia / condiciones | Uso |
|---|---|---|---|
| Manzanas censales 2017 (polígonos, personas, viviendas) | Instituto Nacional de Estadísticas, Censo de Población y Vivienda 2017. Conversión a GeoJSON: [jiboncom/chile_geojson](https://github.com/jiboncom/chile_geojson) | Datos públicos del INE; citar la fuente | Trama urbana, densidad → alturas |
| Red vial de Talca | © colaboradores de [OpenStreetMap](https://www.openstreetmap.org/copyright). Grafo extraído por [Shiroku36/cicloconecta](https://github.com/Shiroku36/cicloconecta) | **ODbL 1.0**: toda obra derivada publicada debe atribuir a OpenStreetMap y compartir la base de datos derivada con la misma licencia | Calles, nombres, jerarquía, posición de la grilla |
| Puntos de lugares y anclas de trazados | OpenStreetMap, consultado a través de [Mapcarta](https://mapcarta.com) | ODbL (OSM) | Coordenadas de la mayoría de los lugares, pasos bajo nivel, puentes, estación |
| Elevación (SRTM 1", tesela S36W072) | NASA / USGS, Shuttle Radar Topography Mission, vía los [Terrain Tiles de AWS](https://registry.opendata.aws/terrain-tiles/) | Dominio público (SRTM) | Relieve de la maqueta y altura del lector |
| Monumentos | [Consejo de Monumentos Nacionales](https://www.monumentos.gob.cl) | Información pública | Coordenadas UTM y fechas de Catedral, Mercado, Escuelas Concentradas, Edificio de los Servicios Públicos, La Victoria, ramal Talca–Constitución |
| Plantas de hitos | API de [OpenStreetMap](https://www.openstreetmap.org/copyright) (`pipeline/landmark.py`) | **ODbL 1.0** (ver arriba) | Planta, orientación y medidas de los modelos rehechos (Estadio Fiscal: cancha, pista, graderías, recinto, torres, entradas; Catedral: nave, crucero, ábside, baptisterio, sacristía, torre, escalinata) |
| Imagen satelital | [Esri World Imagery](https://www.arcgis.com/home/item.html?id=10df2279f9684e4a9f6a7f08febac2a9) (Esri, Maxar, Earthstar Geographics) | Solo consulta; las teselas no se incluyen en la maqueta | Revisión de las manzanas «sin información» que están construidas (`config/manzanas.json`, `pipeline/satellite.py`). En algunos lugares la imagen tiene años (el Estadio, antes de 2017) |

La atribución de OpenStreetMap y del INE está en la pestaña «Acerca» del mapa. Manténgala en cualquier versión publicada.

## Fichas de lugares

Cada lugar lista sus fuentes en `data/pois.csv` (columna `fuentes`) y en su ficha dentro del mapa. Fuentes institucionales usadas con más frecuencia:

- Poder Judicial y [Wikipedia: Corte de Apelaciones de Talca](https://es.wikipedia.org/wiki/Corte_de_Apelaciones_de_Talca)
- [Fiscalía de Chile, Región del Maule](https://www.fiscaliadechile.cl/quienes-somos/fiscalias/region-del-maule) y [MOP Maule: nueva Fiscalía Local](https://maule.mop.gob.cl/mop-hace-entre-al-ministerio-publico-la-nueva-fiscalia-local-de-talca/)
- [Conservador de Bienes Raíces de Talca](https://conservadortalca.cl/) y [Diario Talca](https://diariotalca.cl/inauguran-nuevas-oficinas-del-conservador-y-archivero-judicial-de-talca/)
- [Tribunal Tributario y Aduanero del Maule](https://www.tta.cl/tribunal-tributario-y-aduanero-de-la-region-del-maule/), [Tribunal Electoral Regional del Maule](https://www.tribunalelectoraldelmaule.cl/miembros/)
- [Municipalidad de Talca: historia de la Cárcel Pública (PDF)](https://www.talca.cl/espacio-civico-talca/anexos/Origen-y-evolucion-de-la-Carcel-Publica-en-Talca.pdf)
- [Museo de Talca: Casa de la Independencia](https://www.museodetalca.gob.cl/casa-de-la-independencia)
- Directorios de notarías: [notariasdeturno.cl](https://www.notariasdeturno.cl/talca/), [infonotarias.cl](https://infonotarias.cl/talca/)

## Modelos de hitos

Las fotos y fichas solo se consultaron para el modelo (alturas, techos, colores). No se incluyen en la maqueta.

- **Estadio Fiscal de Talca.** Fotos de Wikimedia Commons:
  - [2021](https://commons.wikimedia.org/wiki/File:Estadio_Fiscal_Talca.jpg) (CC BY-SA 4.0);
  - de 2024: [noviembre](https://commons.wikimedia.org/wiki/File:Estadio_Fiscal_de_Talca_2024.jpg), [diciembre (1)](https://commons.wikimedia.org/wiki/File:Estadio_Fiscal_de_Talca_20241.jpg) y [diciembre (2)](https://commons.wikimedia.org/wiki/File:Estadio_Fiscal_de_Talca_20242.jpg) (CC BY 4.0);
  - [reinauguración de 2025](https://commons.wikimedia.org/wiki/File:Inauguraci%C3%B3n_Fiscal_de_Talca_2025.jpg) (CC BY 3.0 CL).

  Obras de 2010–2017: [StadiumDB](https://stadiumdb.com/news/2020/02/new_stadium_yet_one_more_interesting_case_from_chile). Obras de 2025 para el Mundial Sub-20: [Gobierno de Chile](https://interior.gob.cl/noticias/2025/09/24/gobierno-reinaugura-estadio-fiscal-de-talca-tras-obras-de-remodelacion-con-miras-a-la-copa-mundial-de-la-fifa-sub-20/) y [CNN Chile](https://www.cnnchile.com/deportes/mundial-sub-20-asi-quedo-renovado-estadio-fiscal-de-talca_20250925/).

- **Catedral de San Agustín.** Fotos de Wikimedia Commons ([categoría](https://commons.wikimedia.org/wiki/Category:Catedral_de_San_Agust%C3%ADn,_Talca)), para alturas, colores y fachadas:
  - [2024](https://commons.wikimedia.org/wiki/File:Catedral_de_San_Agust%C3%ADn_en_Talca_2024.jpg) (CC0) y [2022](https://commons.wikimedia.org/wiki/File:Iglesia_de_la_comunidad_buen_pastor.jpg) (CC BY-SA 4.0): fachada, torre y nave desde 1 Poniente y 1 Norte;
  - [febrero de 2018](https://commons.wikimedia.org/wiki/File:Catedral_de_San_Agust%C3%ADn,_Talca,_2018-02-14.jpg) (CC BY-SA 4.0): vista frontal, usada para medir alturas con el ancho de la torre como escala; [2018](https://commons.wikimedia.org/wiki/File:Talca_Cathedral_(1).jpg) (CC BY-SA 4.0);
  - de diciembre de 2017: [fachada](https://commons.wikimedia.org/wiki/File:Talca,_catedral_(41238932865).jpg) y [baptisterio](https://commons.wikimedia.org/wiki/File:Talca,_catedral_(41420032554).jpg) (CC BY-SA 2.0);
  - [interior, 2014](https://commons.wikimedia.org/wiki/File:Interior_de_la_Catedral_de_Talca.jpg) (CC BY-SA 4.0): nave, naves laterales y ábside.

## Contexto histórico y trazados

- [Qué Talca: la historia de las calles enumeradas](https://quetalca.com/la-historia-de-talca-y-sus-calles-enumeradas/) (sistema de Daniel Barros Grez, 1869)
- [Wikipedia: Plaza de Armas de Talca](https://es.wikipedia.org/wiki/Plaza_de_Armas_de_Talca), [Alameda Bernardo O'Higgins](https://es.wikipedia.org/wiki/Alameda_Bernardo_O%27Higgins_(Talca)), [Estero Piduco](https://es.wikipedia.org/wiki/Estero_Piduco), [Cerro La Virgen](https://es.wikipedia.org/wiki/Cerro_La_Virgen_(Talca))
- Mapcarta: [Paso inferior 1 Sur](https://mapcarta.com/es/W470435442), [Paso inferior 1 Norte](https://mapcarta.com/es/W470439793), [Paso inferior 8 Sur](https://mapcarta.com/es/W470060830), [Puente Lircay N° 1](https://mapcarta.com/W474514799), [Parque Piduco](https://mapcarta.com/es/W310571340)

## Software

- [three.js](https://threejs.org) r128 (MIT), cargado desde cdnjs.
- Tipografías Alegreya SC, Alegreya Sans e IBM Plex Mono (SIL Open Font License), vía Google Fonts.
