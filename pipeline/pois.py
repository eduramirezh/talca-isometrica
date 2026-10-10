"""Catálogo de lugares (POI) y recorridos -> data/pois.json y data/pois.csv.

Cada lugar: add(id, nombre, categoría, lat, lon, dirección, descripción, confianza, fuentes,
                fact=dato curioso, sub=instituciones dentro, model=modelo 3D propio, pri=prioridad
                de etiqueta 0..3 (0 = siempre visible), cats=categorías extra).
Categorías: tribunales, fiscalia, notarial, academia, gobierno, penitenciario, historia, ciudad.
Confianza: alta = punto OSM o CMN que calza con la dirección; media = una fuente secundaria o
ubicación calculada con la numeración de la grilla (pipeline/geocode.py); baja = fuentes en conflicto.

Para agregar un lugar: añada una llamada add(...), corra `make pois build` y valide con
`make validate`.
"""
import csv, json
from common import loc, DATA
P = []

def add(id, name, cat, lat, lon, addr, desc, conf, src, fact=None, sub=None, model=None, pri=2, cats=None):
    x, y = loc(lon, lat)
    P.append(dict(id=id, n=name, c=cat, cs=cats or [], lat=round(lat, 6), lon=round(lon, 6), x=round(x, 1), y=round(y, 1),
                  a=addr, d=desc, f=fact, conf=conf, src=src, sub=sub, m=model, p=pri))

MC = 'https://mapcarta.com/'
CMN = 'https://www.monumentos.gob.cl/monumentos/'

# ------------------------------------------------------------------ HISTORIA LEGAL
add('plaza-de-armas', 'Plaza de Armas', 'historia', -35.42653, -71.66600,
    '1 Norte · 1 Sur · 1 Oriente · 1 Poniente',
    'Centro fundacional de San Agustín de Talca (1742), levantado en terreno cedido por los agustinos. Aquí se juró la Independencia de Chile el 12 de febrero de 1818.',
    'alta', [['OpenStreetMap vía Mapcarta', MC + 'W479529034'], ['Wikipedia', 'https://es.wikipedia.org/wiki/Plaza_de_Armas_de_Talca']],
    fact='Es el punto cero de las calles numeradas: el sistema de Daniel Barros Grez, aprobado por el municipio en 1869, cuenta desde los cuatro costados de esta plaza. Su cuadra es la «700» de las calles Norte y Sur.',
    model='plaza', pri=0, cats=['ciudad'])
add('casa-independencia', 'Casa de la Independencia', 'historia', -35.425781, -71.664095,
    '1 Norte 875, esquina 2 Oriente',
    'Hoy Museo O\'Higginiano y de Bellas Artes. Según la tradición, aquí Bernardo O\'Higgins aprobó el Acta de Proclamación de la Independencia fechada en Talca en 1818. Monumento Histórico desde 1971.',
    'alta', [['Museo de Talca', 'https://www.museodetalca.gob.cl/casa-de-la-independencia'], ['Portal Patrimonio', 'https://patrimonio.bienes.cl/patrimonio/casa-de-la-independencia/']],
    fact='El propio museo advierte que no hay documentos que prueben que la firma ocurrió en esta casa: es una tradición histórica, no un hecho acreditado.',
    model='casa', pri=0, cats=['ciudad'])
add('memorial-firma', 'Memorial Firma de la Independencia', 'historia', -35.425922, -71.665438,
    '1 Norte, frente a la Municipalidad',
    'Monumento de 2016 que conmemora la firma del Acta de Independencia de Chile, cuyo texto quedó fechado en Talca.',
    'alta', [['OpenStreetMap vía Mapcarta', MC + 'N7597212247']], pri=3)

# ------------------------------------------------------------------ TRIBUNALES
add('corte-apelaciones', 'Corte de Apelaciones de Talca', 'tribunales', -35.421143, -71.667256,
    '4 Norte (Alameda) 609',
    'Tribunal de alzada de toda la Región del Maule. Fue creada por ley del 28 de julio de 1888 con cinco ministros; hoy funciona con dos salas.',
    'alta', [['OpenStreetMap vía Mapcarta', MC + 'W723911157'], ['Wikipedia', 'https://es.wikipedia.org/wiki/Corte_de_Apelaciones_de_Talca']],
    fact='En la cuadra vecina, 4 Norte 615, funcionan el 1°, 2°, 3° y 4° Juzgado de Letras (civiles) y el Juzgado de Letras del Trabajo.',
    sub=['1° a 4° Juzgado de Letras de Talca (civiles) · 4 Norte 615', 'Juzgado de Letras del Trabajo · 4 Norte 615, 2° piso'],
    model='corte', pri=0)
add('garantia-top', 'Juzgado de Garantía y Tribunal Oral en lo Penal', 'tribunales', -35.42117, -71.66848,
    '4 Norte 541',
    'Los dos tribunales de la reforma procesal penal comparten recinto: el Juzgado de Garantía controla la investigación y el TOP realiza los juicios orales.',
    'media', [['OpenStreetMap vía Mapcarta', MC + 'N3689725114'], ['OpenStreetMap vía Mapcarta', MC + 'N3689725112']],
    model='garantia', pri=1)
add('juzgado-familia', 'Juzgado de Familia de Talca', 'tribunales', -35.42419, -71.65992,
    '5 Oriente 1361',
    'Conoce causas de alimentos, cuidado personal, relación directa y regular, violencia intrafamiliar y medidas de protección.',
    'alta', [['OpenStreetMap vía Mapcarta', 'https://mapcarta.com/es/W392091760']],
    fact='OpenStreetMap registra su edificio con seis pisos, uno de los más altos del barrio.', model='familia', pri=1)
add('jpl-1', '1° Juzgado de Policía Local', 'tribunales', -35.42279, -71.660324,
    '4 Norte 1154, 3° piso',
    'Juzgado municipal: infracciones de tránsito, reclamos de consumidores y faltas a ordenanzas.', 'media',
    [['Municipalidad de Talca', 'https://www.talca.cl/?page_id=12824']], pri=3)
add('jpl-2', '2° Juzgado de Policía Local', 'tribunales', -35.42637, -71.66689,
    '1 Poniente 1133, frente a la plaza', 'Juzgado municipal de policía local.', 'alta',
    [['Municipalidad de Talca', 'https://servicios.talca.cl/telefonos/']], pri=3)
add('jpl-3', '3° Juzgado de Policía Local', 'tribunales', -35.41939, -71.6636,
    '6 Norte 874', 'Juzgado municipal de policía local.', 'alta',
    [['Municipalidad de Talca', 'https://servicios.talca.cl/telefonos/']], pri=3)
add('tta-maule', 'Edificio Portal Maule', 'tribunales', -35.425868, -71.663359,
    '1 Norte 931',
    'Reúne dos instituciones: el Tribunal Tributario y Aduanero del Maule (3° piso), primera instancia en conflictos con el SII y Aduanas, y la Defensoría Regional de la Defensoría Penal Pública.',
    'media', [['TTA', 'https://www.tta.cl/tribunal-tributario-y-aduanero-de-la-region-del-maule/'], ['OpenStreetMap vía Mapcarta', 'https://mapcarta.com/es/W364439678']],
    sub=['Tribunal Tributario y Aduanero del Maule · of. 304', 'Defensoría Regional del Maule (DPP)'], pri=1, cats=['fiscalia'])

# ------------------------------------------------------------------ FISCALIA Y DEFENSA
add('fiscalia-local', 'Fiscalía Local de Talca', 'fiscalia', -35.42124, -71.66592,
    '4 Norte 703, esquina 1 Poniente',
    'Edificio del Ministerio Público entregado en enero de 2022: 3.297 m², cuatro pisos y subterráneo. Aloja también la Fiscalía de Flagrancia.',
    'alta', [['MOP Maule', 'https://maule.mop.gob.cl/mop-hace-entre-al-ministerio-publico-la-nueva-fiscalia-local-de-talca/']],
    fact='Forma, con la Corte y los juzgados de la Alameda, el llamado «barrio cívico» de Talca.', model='fiscalia', pri=1)
add('fiscalia-regional', 'Fiscalía Regional del Maule', 'fiscalia', -35.42458, -71.66525,
    '2 Norte 781',
    'Sede de la Fiscalía Regional, que dirige la persecución penal en toda la Región del Maule.', 'media',
    [['Fiscalía de Chile', 'https://www.fiscaliadechile.cl/quienes-somos/fiscalias/region-del-maule']],
    fact='Ubicación calculada por la numeración de la grilla: 2 Norte, cuadra 700, cerca de 1 Oriente.', pri=1)
add('defensoria-local', 'Defensoría Local de Talca', 'fiscalia', -35.427032, -71.663493,
    '1 Sur 931', 'Oficina de los defensores penales públicos que representan a imputados en Talca.', 'media',
    [['OpenStreetMap vía Mapcarta', 'https://mapcarta.com/es/N6048926028']], pri=2)
add('caj-talca', 'Corporación de Asistencia Judicial', 'fiscalia', -35.43103, -71.66604,
    '4 Sur 768',
    'Consultorio jurídico gratuito: orientación y patrocinio en materias civiles y de familia para quienes no pueden pagar un abogado.', 'media',
    [['Infored', 'https://inforedchile.cl/publico/talca/corporacion-de-asistencia-judicial/consultorio-juridico-talca/15657']],
    fact='Ubicación calculada por la numeración de la grilla (4 Sur, cuadra 700).', pri=2)
add('cde-talca', 'Consejo de Defensa del Estado', 'fiscalia', -35.427459, -71.666873,
    '1 Poniente, al sur de 1 Sur', 'Procuraduría Fiscal de Talca: defiende judicialmente los intereses del Fisco.', 'media',
    [['OpenStreetMap vía Mapcarta', MC + 'N7597310415']], pri=3)
add('carabineros', 'Prefectura de Carabineros Talca', 'fiscalia', -35.42098, -71.66647,
    '4 Norte 687', 'Mando policial de la zona, frente a la Fiscalía Local.', 'media',
    [['OpenStreetMap vía Mapcarta', MC + 'N3700548445']], pri=3)

# ------------------------------------------------------------------ NOTARIAL Y REGISTRAL
add('cbr-talca', 'Conservador de Bienes Raíces y Archivero Judicial', 'notarial', -35.425976, -71.663675,
    '1 Norte 911, esquina 2 Oriente',
    'Lleva los registros de propiedad, comercio y aguas, y custodia los expedientes judiciales archivados de Talca. Oficinas inauguradas el 8 de febrero de 2022.',
    'alta', [['Conservador de Talca', 'https://conservadortalca.cl/'], ['Diario Talca', 'https://diariotalca.cl/inauguran-nuevas-oficinas-del-conservador-y-archivero-judicial-de-talca/']],
    pri=1)
add('notaria-1', '1ª Notaría de Talca', 'notarial', -35.42608, -71.66301, '1 Norte 963, of. 103', 'Notaría pública.', 'media',
    [['Notarías de turno', 'https://www.notariasdeturno.cl/talca/']], pri=3)
add('notaria-2', '2ª Notaría de Talca', 'notarial', -35.42741, -71.66403, '1 Sur 898, esquina 2 Oriente', 'Notaría pública.', 'media',
    [['Infonotarías', 'https://infonotarias.cl/talca/']], pri=3)
add('notaria-3', '3ª Notaría de Talca', 'notarial', -35.42719, -71.66364, '1 Sur 925', 'Notaría pública.', 'media',
    [['Notaría Hormazábal', 'https://www.notariahormazabal.cl/']], pri=3)
add('notaria-4', '4ª Notaría de Talca', 'notarial', -35.42626, -71.66386, '1 Norte 902, esquina 2 Oriente', 'Notaría pública.', 'media',
    [['Notaría Silva', 'http://notariasilvatalca.cl']], pri=3)
add('notaria-5', '5ª Notaría de Talca', 'notarial', -35.42624, -71.66404, '1 Norte 888', 'Notaría pública.', 'alta',
    [['OpenStreetMap vía Mapcarta', 'https://mapcarta.com/es/W818950430']],
    fact='Cinco de las notarías de Talca están a menos de 150 m de la esquina de 1 Norte con 2 Oriente. La 7ª está lejos del centro, en 30 Oriente 1528.', pri=3)
add('registro-civil', 'Registro Civil de Talca', 'notarial', -35.42992, -71.66019, '3 Sur 1188',
    'Oficina del Servicio de Registro Civil e Identificación: nacimientos, matrimonios, cédulas y certificados.', 'media',
    [['Waze', 'https://www.waze.com/live-map/directions/registro-civil-talca-3-sur-1188?to=place.w.188941734.1889679481.22681099']],
    fact='Ubicación calculada por la numeración de la grilla.', pri=3)

# ------------------------------------------------------------------ ACADEMIA Y GREMIO
add('utalca-derecho', 'Universidad de Talca, Campus Lircay', 'academia', -35.40577, -71.6346, 'Av. Lircay s/n',
    'Sede de la Facultad de Ciencias Jurídicas y Sociales (1992), que edita las revistas Ius et Praxis y Política Criminal. El campus supera las 90 hectáreas y tiene un parque de esculturas.',
    'media', [['Wikipedia', 'https://es.wikipedia.org/wiki/Facultad_de_Ciencias_Jur%C3%ADdicas_y_Sociales_de_la_Universidad_de_Talca'], ['OpenStreetMap vía Mapcarta', 'https://mapcarta.com/es/W101562805']],
    fact='Su Centro de Estudios Constitucionales (CECOCH) funciona en Santiago, no en este campus.', model='campus', pri=1, cats=['ciudad'])
add('ucm-derecho', 'Universidad Católica del Maule', 'academia', -35.4354, -71.6196, 'Av. San Miguel 3605, Campus San Miguel',
    'Imparte la carrera de Derecho. Nació en 1991 a partir de la sede Talca de la Pontificia Universidad Católica.', 'media',
    [['Wikipedia', 'https://en.wikipedia.org/wiki/Catholic_University_of_the_Maule']], model='ucm', pri=2)
add('ua-talca', 'Universidad Autónoma, sede Talca', 'academia', -35.41907, -71.67132, '5 Poniente 1670',  # corregido 2026-10-10: antes -71.67597 (mediana de 5 Poniente contaminada)
    'Dicta Derecho diurno y vespertino y mantiene una clínica jurídica abierta a la comunidad.', 'media',
    [['U. Autónoma', 'https://www.uautonoma.cl/sedes/talca/']],
    fact='Ubicación calculada por la numeración de la grilla (5 Poniente, entre 5 y 6 Norte).', pri=2)
add('colegio-abogados', 'Colegio de Abogados, Consejo Talca', 'academia', -35.42250, -71.66674, '4 Norte 648',
    'Consejo regional del Colegio de Abogados de Chile, frente a la Corte de Apelaciones.', 'baja',
    [['Colegio de Abogados', 'https://colegioabogados.cl/el-colegio/colegios-de-regiones/']],
    fact='Otra fuente da el número 620. Ubicación calculada por la numeración de la grilla.', pri=3)

# ------------------------------------------------------------------ GOBIERNO Y CONTROL
add('contraloria', 'Contraloría Regional del Maule', 'gobierno', -35.425542, -71.667253, '1 Norte 665',
    'Controla la legalidad de los actos de los servicios públicos y municipios de la región (toma de razón, auditorías, dictámenes).', 'alta',
    [['OpenStreetMap vía Mapcarta', MC + 'W813330079']], pri=2)
add('municipalidad', 'Municipalidad de Talca', 'gobierno', -35.425762, -71.665434, '1 Norte 797',
    'Gobierno comunal, frente a la Plaza de Armas.', 'alta', [['OpenStreetMap vía Mapcarta', MC + 'W310186641'], ['Museo de Talca', 'https://www.museodetalca.gob.cl/casa-de-la-independencia']],
    fact='Una investigación de A. Daitsman ubica en este solar la casa de Juan Albano Pereira, donde se crió Bernardo O\'Higgins.', pri=2)
add('gore-maule', 'Gobierno Regional del Maule', 'gobierno', -35.425694, -71.666383, '1 Norte 771',
    'Sede del gobernador regional y del Consejo Regional.', 'alta', [['OpenStreetMap vía Mapcarta', MC + 'W275506471']], pri=3)
add('servicios-publicos', 'Edificio de los Servicios Públicos', 'gobierno', -35.42663, -71.66503, '1 Oriente 1150',
    'Construido hacia 1930 tras el terremoto de 1928, al amparo de la Ley de Transformación de Talca. Monumento Histórico desde 2008. En su 2° piso funciona el Tribunal Electoral Regional del Maule.',
    'alta', [['Consejo de Monumentos Nacionales', CMN + 'monumentos-historicos/edificio-de-los-servicios-publicos-de-talca'], ['TER Maule', 'https://www.tribunalelectoraldelmaule.cl/miembros/']],
    sub=['Tribunal Electoral Regional del Maule · 2° piso'], model='servicios', pri=1, cats=['ciudad', 'tribunales'])
add('seremi-justicia', 'Seremi de Justicia y DD.HH.', 'gobierno', -35.41926, -71.66242, '6 Norte 957',
    'Representa al Ministerio de Justicia y Derechos Humanos en la región.', 'media',
    [['OpenStreetMap vía Mapcarta', 'https://mapcarta.com/es/N13699047049']], pri=3)

# ------------------------------------------------------------------ PENITENCIARIO
add('ex-carcel', 'Ex Cárcel Pública de Talca', 'penitenciario', -35.42280, -71.66875, '4 Norte 520 (manzana 3–4 Norte, 2–3 Poniente)',
    'Hay cárcel en este sitio desde 1864; el edificio actual se reconstruyó en 1930 tras el terremoto de 1928. En 1973 fue centro de detención de presos políticos.',
    'media', [['Municipalidad de Talca (PDF)', 'https://www.talca.cl/espacio-civico-talca/anexos/Origen-y-evolucion-de-la-Carcel-Publica-en-Talca.pdf'], ['Radio FM+', 'https://radiofmmas.cl/prescindencia-de-la-carcel-de-talca-hito-clave-para-el-futuro-centro-civico-en-plena-alameda/']],
    fact='Tras abrir en 2025 el complejo concesionado La Laguna (2.320 plazas, a unos 10 km al norte), se tramita dejar este recinto para un futuro Centro Cívico en plena Alameda.',
    model='carcel', pri=1)
add('gendarmeria', 'Dirección Regional de Gendarmería', 'penitenciario', -35.422965, -71.65887, '4 Norte 1246',
    'Dirige la administración penitenciaria de la Región del Maule.', 'media',
    [['Gendarmería', 'https://www.gendarmeria.gob.cl/orga_maule.html']], pri=3)

# ------------------------------------------------------------------ CIUDAD ICONICA
add('catedral', 'Catedral de Talca', 'ciudad', -35.42612, -71.66707, '1 Poniente con 1 Norte',
    'Tercera catedral levantada en este sitio, construida en ladrillo a la vista entre 1939 y 1954 tras el terremoto de 1928.',
    'alta', [['OpenStreetMap vía Mapcarta', MC + 'W114237041']], fact='Su cripta guarda los restos del obispo Manuel Larraín.', model='catedral', pri=0)
add('mercado-central', 'Mercado Central', 'ciudad', -35.42707, -71.66052, 'Entre 1 Norte, 1 Sur, 4 y 5 Oriente',
    'Mercado neoclásico de ladrillo de 1890, diseñado por Benjamín Vivanco. Monumento Histórico desde 1998.',
    'alta', [['Consejo de Monumentos Nacionales', CMN + 'monumentos-historicos/mercado-central-municipal-de-talca']],
    fact='Sobrevivió al terremoto de 2010 y a incendios en 2000 y 2014.', model='mercado', pri=1)
add('escuelas-concentradas', 'Escuelas Concentradas', 'ciudad', -35.42687, -71.66239, '1 Sur 1025',
    'Escuelas públicas de 1939–1941, declaradas Monumento Histórico en 2013 para evitar su demolición tras el terremoto de 2010.',
    'alta', [['Consejo de Monumentos Nacionales', CMN + 'monumentos-historicos/escuelas-concentradas-de-talca']], pri=3)
add('alameda', 'Alameda Bernardo O\'Higgins', 'ciudad', -35.42145, -71.67245, '4 Norte, del Río Claro a 11 Oriente',
    'Parque lineal de unos 3 km, el principal de la ciudad, con cerca de 950 árboles de 53 especies.',
    'alta', [['Wikipedia', 'https://es.wikipedia.org/wiki/Alameda_Bernardo_O%27Higgins_(Talca)']],
    fact='Su primer tramo lo construyeron presidiarios en 1792. En la grilla es la calle 4 Norte.', pri=1)
add('la-victoria', 'Monumento La Victoria', 'ciudad', -35.42201, -71.66488, 'Alameda con 1 Oriente',
    'Estatua de 1904 que honra al Batallón Cívico de Talca en la Guerra del Pacífico.',
    'alta', [['Consejo de Monumentos Nacionales', CMN + 'monumentos-publicos/batallon-civico-de-talca-y-la-victoria']],
    fact='La obra fue encargada originalmente por el Perú; oficiales chilenos la tomaron como botín de guerra en 1882.', model='victoria', pri=2)
add('teatro-regional', 'Teatro Regional del Maule', 'ciudad', -35.42260, -71.66455, '1 Oriente 1484',
    'Principal escenario de artes escénicas de la región, inaugurado en 2005 junto a la Alameda.', 'alta',
    [['OpenStreetMap vía Mapcarta', MC + 'W214851535']], model='teatro', pri=2)
add('liceo-abate-molina', 'Liceo Abate Molina', 'ciudad', -35.42206, -71.65878, 'Alameda, entre 5 y 6 Oriente',
    'Uno de los liceos más antiguos de Chile, creado por decreto en 1827. Sus alumnos fundaron el club Rangers en 1902.',
    'media', [['Consejo de Monumentos Nacionales', CMN + 'monumentos-publicos/abate-molina']],
    fact='La estatua del Abate Molina (1861) en su entrada fue la primera escultura fundida en Chile.', pri=3)
add('estadio', 'Estadio Fiscal de Talca', 'ciudad', -35.41991, -71.67281, 'Alameda 251',
    'Estadio Bicentenario Iván Azócar Bernales, casa de Rangers desde 1930. Tras la ampliación de 2019 recibe 16.070 espectadores.',
    'alta', [['OpenStreetMap vía Mapcarta', MC + 'W89069046'], ['IND', 'https://ind.cl/noticias/ind-rinde-homenaje-a-un-idolo-fiscal-de-talca-ahora-se-llama-estadio-bicentenario-ivan-azocar-bernales/']],
    model='estadio', pri=1)
add('parque-rio-claro', 'Parque Río Claro', 'ciudad', -35.41810, -71.68045, 'Extremo poniente de la Alameda',
    'Parque de 11 hectáreas inaugurado en 2023 junto al tradicional balneario de botes y mote con huesillo.',
    'alta', [['Talca Sostenible', 'https://www.talcasostenible.cl/parque-rio-claro/']], pri=2)
add('cerro-la-virgen', 'Cerro La Virgen', 'ciudad', -35.42270, -71.70318, 'Ribera poniente del Río Claro',
    'Su punto más alto, el Peñón (372 m), es el techo de la comuna y queda unos 2 km al norte del santuario. La Virgen del Carmen del santuario se inauguró en 1910, para el Centenario.',
    'alta', [['Wikipedia', 'https://es.wikipedia.org/wiki/Cerro_La_Virgen_(Talca)']],
    fact='El relieve de la maqueta es el real (SRTM): el santuario queda a unos 270 m, 165 m sobre la Plaza de Armas. Las alturas están exageradas unas 3 veces en el plano y unas 1,3 veces en los cerros.', model='cerro', pri=1)
add('estacion', 'Estación de Ferrocarriles', 'ciudad', -35.42978, -71.64960, '11 Oriente 1000',
    'Principal estación del Maule, reconstruida en 1929 y en 2017. Desde aquí parte el ramal Talca–Constitución.',
    'alta', [['OpenStreetMap vía Mapcarta', MC + 'N308140957'], ['Wikipedia', 'https://en.wikipedia.org/wiki/Talca_railway_station']],
    model='estacion', pri=1)
add('ramal-constitucion', 'Ramal Talca–Constitución', 'ciudad', -35.44022, -71.65053, 'Puente sobre el estero Piduco',
    'Ramal de trocha métrica construido entre 1888 y 1915, recorrido por el Buscarril. Monumento Histórico desde 2007.',
    'media', [['Consejo de Monumentos Nacionales', CMN + 'monumentos-historicos/ramal-ferroviario-talca-constitucion']], pri=3)
add('terminal-buses', 'Terminal de Buses', 'ciudad', -35.43027, -71.64733, '2 Sur, al oriente de la vía férrea',
    'Terminal interurbano Lorenzo Varoli, a 200 m de la estación de trenes.', 'alta',
    [['OpenStreetMap vía Mapcarta', MC + 'W110962821']], pri=3)
add('hospital-regional', 'Hospital Regional de Talca', 'ciudad', -35.42660, -71.64638, '1 Norte 1990',
    'Hospital de alta complejidad y cabecera de la red de salud del Maule.', 'alta',
    [['OpenStreetMap vía Mapcarta', MC + 'W618536526']], model='hospital', pri=2)
add('mall-plaza-maule', 'Mall Plaza Maule', 'ciudad', -35.43242, -71.62991, 'Av. Circunvalación 30 Oriente 1055',
    'Principal centro comercial de la ciudad, en el sector oriente.', 'alta', [['OpenStreetMap vía Mapcarta', MC + 'W110780381']], model='mall', pri=3)
add('parque-piduco', 'Parque Piduco', 'ciudad', -35.43735, -71.66091, 'Ribera del estero Piduco',
    'El parque urbano más grande de Talca: 25,9 hectáreas a lo largo de 3 km del estero.', 'alta',
    [['Talca Sostenible', 'https://www.talcasostenible.cl/parque-piduco/']],
    fact='«Piduco» vendría de «agua del pudú»; de ahí el gentilicio popular «piducanos».', pri=2)
add('plaza-las-heras', 'Plaza Las Heras', 'ciudad', -35.41774, -71.65838, 'Barrio norte, entre 5 y 6 Oriente',
    'Plaza de barrio dedicada al general Juan Gregorio Las Heras, frente a la iglesia San Luis.', 'alta',
    [['OpenStreetMap vía Mapcarta', 'https://mapcarta.com/es/W89069033']], pri=3)
add('cementerio', 'Cementerio General', 'ciudad', -35.40751, -71.66412, 'Sector norte',
    'Cementerio histórico de la ciudad, con un memorial a los detenidos desaparecidos.', 'alta',
    [['OpenStreetMap vía Mapcarta', 'https://mapcarta.com/es/W86933822']], pri=3)

TOURS = {
    'justicia': dict(n='Ruta de la Justicia', d='Del juramento de 1818 al barrio cívico de la Alameda, a pie en unos 3 km.',
        s=['plaza-de-armas', 'casa-independencia', 'contraloria', 'cbr-talca', 'notaria-5', 'tta-maule', 'juzgado-familia',
           'fiscalia-regional', 'fiscalia-local', 'corte-apelaciones', 'garantia-top', 'ex-carcel', 'utalca-derecho']),
    'iconica': dict(n='Talca icónica', d='Monumentos, ríos y estaciones: la ciudad en trece paradas.',
        s=['plaza-de-armas', 'catedral', 'servicios-publicos', 'mercado-central', 'escuelas-concentradas', 'estacion',
           'teatro-regional', 'la-victoria', 'alameda', 'estadio', 'parque-rio-claro', 'cerro-la-virgen', 'parque-piduco']),
}
ids = {p['id'] for p in P}
for t in TOURS.values():
    for s in t['s']:
        assert s in ids, s
DATA.mkdir(exist_ok=True)
json.dump(dict(pois=P, tours=TOURS), open(DATA / 'pois.json', 'w'), ensure_ascii=False, separators=(',', ':'))
with open(DATA / 'pois.csv', 'w', newline='', encoding='utf-8') as f:
    w = csv.writer(f)
    w.writerow(['id', 'nombre', 'categoria', 'categorias_extra', 'direccion', 'lat', 'lon', 'confianza', 'modelo_3d', 'prioridad', 'descripcion', 'dato', 'instituciones', 'fuentes'])
    for p in P:
        w.writerow([p['id'], p['n'], p['c'], ';'.join(p['cs']), p['a'], p['lat'], p['lon'], p['conf'], p['m'] or '', p['p'], p['d'], p['f'] or '',
                    ' | '.join(p['sub'] or []), ' | '.join(f'{a} <{b}>' for a, b in p['src'])])
print(len(P), 'lugares ->', DATA / 'pois.json', 'y pois.csv')
