# Fuentes, licencias y atribución

## Datos geográficos

| Dato | Fuente | Licencia / condiciones | Uso |
|---|---|---|---|
| Manzanas censales 2017 (polígonos, personas, viviendas) | Instituto Nacional de Estadísticas, Censo de Población y Vivienda 2017. Conversión a GeoJSON: [jiboncom/chile_geojson](https://github.com/jiboncom/chile_geojson) | Datos públicos del INE; citar la fuente | Trama urbana, densidad → alturas |
| Red vial de Talca | © colaboradores de [OpenStreetMap](https://www.openstreetmap.org/copyright). Grafo extraído por [Shiroku36/cicloconecta](https://github.com/Shiroku36/cicloconecta) | **ODbL 1.0**: toda obra derivada publicada debe atribuir a OpenStreetMap y compartir la base de datos derivada con la misma licencia | Calles, nombres, jerarquía, posición de la grilla |
| Puntos de lugares y anclas de trazados | OpenStreetMap, consultado a través de [Mapcarta](https://mapcarta.com) | ODbL (OSM) | Coordenadas de la mayoría de los lugares, pasos bajo nivel, puentes, estación |
| Elevación (SRTM 1", tesela S36W072) | NASA / USGS, Shuttle Radar Topography Mission, vía los [Terrain Tiles de AWS](https://registry.opendata.aws/terrain-tiles/) | Dominio público (SRTM) | Relieve de la maqueta y altura del lector |
| Monumentos | [Consejo de Monumentos Nacionales](https://www.monumentos.gob.cl) | Información pública | Coordenadas UTM y fechas de Catedral, Mercado, Escuelas Concentradas, Edificio de los Servicios Públicos, La Victoria, ramal Talca–Constitución |

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

## Contexto histórico y trazados

- [Qué Talca: la historia de las calles enumeradas](https://quetalca.com/la-historia-de-talca-y-sus-calles-enumeradas/) (sistema de Daniel Barros Grez, 1869)
- [Wikipedia: Plaza de Armas de Talca](https://es.wikipedia.org/wiki/Plaza_de_Armas_de_Talca), [Alameda Bernardo O'Higgins](https://es.wikipedia.org/wiki/Alameda_Bernardo_O%27Higgins_(Talca)), [Estero Piduco](https://es.wikipedia.org/wiki/Estero_Piduco), [Cerro La Virgen](https://es.wikipedia.org/wiki/Cerro_La_Virgen_(Talca))
- Mapcarta: [Paso inferior 1 Sur](https://mapcarta.com/es/W470435442), [Paso inferior 1 Norte](https://mapcarta.com/es/W470439793), [Paso inferior 8 Sur](https://mapcarta.com/es/W470060830), [Puente Lircay N° 1](https://mapcarta.com/W474514799), [Parque Piduco](https://mapcarta.com/es/W310571340)

## Software

- [three.js](https://threejs.org) r128 (MIT), cargado desde cdnjs.
- Tipografías Alegreya SC, Alegreya Sans e IBM Plex Mono (SIL Open Font License), vía Google Fonts.
