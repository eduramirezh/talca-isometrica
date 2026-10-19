"""Catálogo de lugares (POI) y recorridos -> data/pois.json y data/pois.csv.

Cada lugar: add(id, nombre, categoría, lat, lon, dirección, descripción, confianza, fuentes,
                fact=dato curioso, sub=instituciones dentro, model=modelo 3D propio, pri=prioridad
                de etiqueta 0..3 (0 = siempre visible), cats=categorías extra, wd=elemento de Wikidata).
Categorías: tribunales, fiscalia, notarial, academia, gobierno, penitenciario, historia, ciudad. Los Monumentos
Históricos del Consejo de Monumentos Nacionales y los Inmuebles de Conservación Histórica del Plan Regulador de Talca
de 2011 llevan 'patrimonio' en cats: no es una capa (van en la suya, casi siempre «Hitos de la ciudad»), y la ficha
lo muestra junto a la categoría.
wd: 'Q…' (o varios separados por comas, el principal primero); lo usan `wikidata.py check` y `landmark.py photos
--cat`. Wikidata solo sirve para revisar: las coordenadas de aquí vienen de OSM (ODbL) y no se copian allá.
Confianza: alta = punto OSM o CMN que calza con la dirección; media = una fuente secundaria o
ubicación calculada con la numeración de la grilla (pipeline/geocode.py); baja = fuentes en conflicto.

Para agregar un lugar: añada una llamada add(...), corra `make pois build` y valide con
`make validate`.
"""
import csv, json
from common import loc, DATA
P = []

def add(id, name, cat, lat, lon, addr, desc, conf, src, fact=None, sub=None, model=None, pri=2, cats=None, wd=None):
    x, y = loc(lon, lat)
    P.append(dict(id=id, n=name, c=cat, cs=cats or [], lat=round(lat, 6), lon=round(lon, 6), x=round(x, 1), y=round(y, 1),
                  a=addr, d=desc, f=fact, conf=conf, src=src, sub=sub, m=model, p=pri, **({'wd': wd} if wd else {})))

MC = 'https://mapcarta.com/'
CMN = 'https://www.monumentos.gob.cl/monumentos/'
DEC = 'https://www.monumentos.gob.cl/sites/default/files/decretos/'    # decretos de los Monumentos Históricos
ICH = ['MINVU: Inmuebles de Conservación Histórica (PRC de Talca, 2011)', 'https://geoide.minvu.cl/server/rest/services/IPT/Patrimonio/FeatureServer/0']

# ------------------------------------------------------------------ HISTORIA LEGAL
add('plaza-de-armas', 'Plaza de Armas', 'historia', -35.42653, -71.66600,
    '1 Norte · 1 Sur · 1 Oriente · 1 Poniente',
    'Centro fundacional de San Agustín de Talca (1742), levantado en terreno cedido por los agustinos. Aquí se juró la Independencia de Chile el 12 de febrero de 1818.',
    'alta', [['OpenStreetMap vía Mapcarta', MC + 'W479529034'], ['Wikipedia', 'https://es.wikipedia.org/wiki/Plaza_de_Armas_de_Talca']],
    fact='Es el punto cero de las calles numeradas: el sistema de Daniel Barros Grez, aprobado por el municipio en 1869, cuenta desde los cuatro costados de esta plaza. Su cuadra es la «700» de las calles Norte y Sur.',
    model='plaza', pri=0, cats=['ciudad'], wd='Q115169333')
add('casa-independencia', 'Casa de la Independencia', 'historia', -35.425781, -71.664095,
    '1 Norte 875, esquina 2 Oriente',
    'Hoy Museo O\'Higginiano y de Bellas Artes, que una ley creó en 1945 y que abrió aquí en 1964. Según la tradición, aquí Bernardo O\'Higgins aprobó el Acta de Proclamación de la Independencia fechada en Talca en 1818. Monumento Histórico desde 1971, junto con la casa vecina.',
    'alta', [['Museo de Talca', 'https://www.museodetalca.gob.cl/casa-de-la-independencia'], ['Portal Patrimonio', 'https://patrimonio.bienes.cl/patrimonio/casa-de-la-independencia/'],
             ['Wikipedia: el museo', 'https://es.wikipedia.org/wiki/Museo_O%27Higginiano_y_de_Bellas_Artes_de_Talca'], ['Decreto 1749 de 1971 (CMN)', DEC + 'MH_00065_1971_D01749.PDF']],
    fact='El propio museo advierte que no hay documentos que prueben que la firma ocurrió en esta casa: es una tradición histórica, no un hecho acreditado.',
    model='casa', pri=0, cats=['ciudad', 'patrimonio'], wd='Q123382692,Q6033413,Q42959415')
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
    model='corte', pri=0, wd='Q19587960')
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
    fact='La universidad nació en 1981. Su Centro de Estudios Constitucionales (CECOCH) funciona en Santiago, no en este campus.', model='campus', pri=1, cats=['ciudad'], wd='Q3551328')
add('ucm-derecho', 'Universidad Católica del Maule', 'academia', -35.4354, -71.6196, 'Av. San Miguel 3605, Campus San Miguel',
    'Imparte la carrera de Derecho. Nació en 1991 a partir de la sede Talca de la Pontificia Universidad Católica.', 'media',
    [['Wikipedia', 'https://en.wikipedia.org/wiki/Catholic_University_of_the_Maule'], ICH], model='ucm', pri=2, cats=['patrimonio'], wd='Q5053274',
    fact='Su campus San Miguel es Inmueble de Conservación Histórica del Plan Regulador de 2011.')
add('ua-talca', 'Universidad Autónoma, sede Talca', 'academia', -35.41907, -71.67132, '5 Poniente 1670',  # corregido 2026-10-10: antes -71.67597 (mediana de 5 Poniente contaminada)
    'Dicta Derecho diurno y vespertino y mantiene una clínica jurídica abierta a la comunidad.', 'media',
    [['U. Autónoma', 'https://www.uautonoma.cl/sedes/talca/']],
    fact='Ubicación calculada por la numeración de la grilla (5 Poniente, entre 5 y 6 Norte).', pri=2)
add('colegio-abogados', 'Colegio de Abogados, Consejo Talca', 'academia', -35.42250, -71.66674, '4 Norte 648',
    'Consejo regional del Colegio de Abogados de Chile, frente a la Corte de Apelaciones.', 'baja',
    [['Colegio de Abogados', 'https://colegioabogados.cl/el-colegio/colegios-de-regiones/']],
    fact='Otra fuente da el número 620. Ubicación calculada por la numeración de la grilla.', pri=3)

add('trifolia', 'Trifolia', 'academia', -35.426810, -71.664253, '1 Sur 865, of. 63 (Torre Talca)',
    'Legaltech: un asistente de inteligencia artificial para investigar derecho chileno (jurisprudencia, legislación, doctrina y dictámenes) que cita la fuente de cada resultado. Su oficina está en la Torre Talca. El autor de esta maqueta es uno de sus fundadores. El letrero con su nombre en el techo de la torre es una licencia de la maqueta: no se sabe qué muestra el real.',
    'alta', [['Trifolia', 'https://trifolia.cl/'], ['Mapa legaltech de Bredia', 'https://mapa.bredia.com.co/mapa?country=CL'], ['OpenStreetMap vía Mapcarta (la torre)', MC + 'W310246574']],
    fact='El mapa de legaltech de Iberoamérica de Bredia lista 23 legaltech chilenas: 22 en el área de Santiago y Trifolia, la única en Talca, en «Investigación jurídica» (consultado el 15 de octubre de 2026).',
    pri=3)

# ------------------------------------------------------------------ GOBIERNO Y CONTROL
add('contraloria', 'Contraloría Regional del Maule', 'gobierno', -35.425542, -71.667253, '1 Norte 665',
    'Controla la legalidad de los actos de los servicios públicos y municipios de la región (toma de razón, auditorías, dictámenes).', 'alta',
    [['OpenStreetMap vía Mapcarta', MC + 'W813330079']], pri=2)
add('municipalidad', 'Municipalidad de Talca', 'gobierno', -35.425762, -71.665434, '1 Norte 797',
    'Gobierno comunal, frente a la Plaza de Armas. Su edificio es Inmueble de Conservación Histórica del Plan Regulador de 2011.', 'alta', [['OpenStreetMap vía Mapcarta', MC + 'W310186641'], ['Museo de Talca', 'https://www.museodetalca.gob.cl/casa-de-la-independencia'], ICH],
    fact='Una investigación de A. Daitsman ubica en este solar la casa de Juan Albano Pereira, donde se crió Bernardo O\'Higgins.', pri=2, cats=['patrimonio'])
add('gore-maule', 'Gobierno Regional del Maule', 'gobierno', -35.425694, -71.666383, '1 Norte 771',
    'Sede del gobernador regional y del Consejo Regional.', 'alta', [['OpenStreetMap vía Mapcarta', MC + 'W275506471']], pri=3, wd='Q42700559')
add('servicios-publicos', 'Edificio de los Servicios Públicos', 'gobierno', -35.42663, -71.66503, '1 Oriente 1150',
    'Construido hacia 1930 tras el terremoto de 1928, al amparo de la Ley de Transformación de Talca. Monumento Histórico desde 2008. En su 2° piso funciona el Tribunal Electoral Regional del Maule.',
    'alta', [['Consejo de Monumentos Nacionales', CMN + 'monumentos-historicos/edificio-de-los-servicios-publicos-de-talca'], ['TER Maule', 'https://www.tribunalelectoraldelmaule.cl/miembros/']],
    sub=['Tribunal Electoral Regional del Maule · 2° piso'], model='servicios', pri=1, cats=['ciudad', 'tribunales', 'patrimonio'], wd='Q42898878')
add('seremi-justicia', 'Seremi de Justicia y DD.HH.', 'gobierno', -35.41926, -71.66242, '6 Norte 957',
    'Representa al Ministerio de Justicia y Derechos Humanos en la región.', 'media',
    [['OpenStreetMap vía Mapcarta', 'https://mapcarta.com/es/N13699047049']], pri=3)

# ------------------------------------------------------------------ PENITENCIARIO
add('ex-carcel', 'Ex Cárcel Pública de Talca', 'penitenciario', -35.42280, -71.66875, '4 Norte 520 (manzana 3–4 Norte, 2–3 Poniente)',
    'Hay cárcel en este sitio desde 1864; el edificio actual se reconstruyó en 1930 tras el terremoto de 1928. En 1973 fue centro de detención de presos políticos.',
    'media', [['Municipalidad de Talca (PDF)', 'https://www.talca.cl/espacio-civico-talca/anexos/Origen-y-evolucion-de-la-Carcel-Publica-en-Talca.pdf'], ['Radio FM+', 'https://radiofmmas.cl/prescindencia-de-la-carcel-de-talca-hito-clave-para-el-futuro-centro-civico-en-plena-alameda/']],
    fact='Tras abrir en 2025 el complejo concesionado La Laguna (2.320 plazas, a unos 10 km al norte), se tramita dejar este recinto para un futuro Centro Cívico en plena Alameda.',
    model='carcel', pri=1, wd='Q141051264')
add('gendarmeria', 'Dirección Regional de Gendarmería', 'penitenciario', -35.422965, -71.65887, '4 Norte 1246',
    'Dirige la administración penitenciaria de la Región del Maule.', 'media',
    [['Gendarmería', 'https://www.gendarmeria.gob.cl/orga_maule.html']], pri=3)

# ------------------------------------------------------------------ CIUDAD ICONICA
add('catedral', 'Catedral de Talca', 'ciudad', -35.42612, -71.66707, '1 Poniente con 1 Norte',
    'Tercera catedral levantada en este sitio, construida en ladrillo a la vista tras el terremoto de 1928: su primera piedra se bendijo en 1939 y se consagró en 1954. Es Inmueble de Conservación Histórica del Plan Regulador de 2011, no Monumento Nacional.',
    'alta', [['OpenStreetMap vía Mapcarta', MC + 'W114237041'], ['Wikipedia', 'https://es.wikipedia.org/wiki/Catedral_de_San_Agust%C3%ADn_(Talca)'], ICH],
    fact='Su cripta guarda los restos del obispo Manuel Larraín.', model='catedral', pri=0, cats=['patrimonio'], wd='Q21164976')
add('mercado-central', 'Mercado Central', 'ciudad', -35.42707, -71.66052, 'Entre 1 Norte, 1 Sur, 4 y 5 Oriente',
    'Mercado neoclásico de ladrillo de 1890, diseñado por Benjamín Vivanco. Monumento Histórico desde 1998.',
    'alta', [['Consejo de Monumentos Nacionales', CMN + 'monumentos-historicos/mercado-central-municipal-de-talca']],
    fact='Sobrevivió al terremoto de 2010 y a incendios en 2000 y 2014.', model='mercado', pri=1, cats=['patrimonio'], wd='Q42898050,Q122874880')
add('escuelas-concentradas', 'Escuelas Concentradas', 'ciudad', -35.42687, -71.66239, '1 Sur 1025',
    'Escuelas públicas de 1939–1941, declaradas Monumento Histórico en 2013 para evitar su demolición tras el terremoto de 2010.',
    'alta', [['Consejo de Monumentos Nacionales', CMN + 'monumentos-historicos/escuelas-concentradas-de-talca']], pri=3, cats=['patrimonio'], wd='Q109311517,Q42899331,Q42899338')
add('carritos-5-oriente', 'Carritos de completos de 5 Oriente', 'ciudad', -35.4290505, -71.6600422, '5 Oriente, entre 2 y 3 Sur',
    'Hilera de quioscos de completos pegada al edificio de la vereda poniente de 5 Oriente, a media cuadra de 2 Sur: el lugar de comida al paso más conocido de Talca, con mucho público de noche. En 6 Oriente, frente al Mercado, hay otra hilera de quioscos rojos.',
    'alta', [['OpenStreetMap (nodo n1033452823)', MC + 'N1033452823'], ['Diario El Centro, 8 de junio de 2026', 'https://www.diarioelcentro.cl/2026/06/08/fiscalizacion-a-carros-de-completos-en-talca-deja-un-local-clausurado-y-cuatro-sumarios-sanitarios/'],
             ['Maule News, junio de 2026', 'https://www.maulenews.com/2026/06/carros-de-completos-de-talca-bajo-la.html'], ['Urbanbat: Talca, la ciudad del completo', 'https://urbanbat.org/talca-la-ciudad-del-completo/']],
    fact='Antes de 2009 los carritos más conocidos estaban frente al Mercado Central, en 4 Oriente: una estructura compartida de cuatro locales que funcionó desde 1965 hasta la remodelación de la plaza.',
    model='carritos', pri=3)
add('torre-talca', 'Torre Talca', 'ciudad', -35.426810, -71.664253, '1 Sur 865',
    'Edificio de oficinas y departamentos de doce pisos, a una cuadra de la Plaza de Armas. Es de los pocos edificios altos del centro.',
    'alta', [['OpenStreetMap vía Mapcarta', MC + 'W310246574'], ['Mercantil.com (dirección)', 'https://www.mercantil.com/empresa/inmobiliaria-honorato/talca/300378810/esp/']],
    fact='Su dirección es de 1 Sur, pero la torre no da a la calle: se levanta en el interior de la manzana, unos 35 m detrás de la vereda, tras los locales de la calle.',
    model='torre', pri=2)
add('alameda', 'Alameda Bernardo O\'Higgins', 'ciudad', -35.42145, -71.67245, '4 Norte, del Río Claro a 11 Oriente',
    'Parque lineal de unos 3 km, el principal de la ciudad, con cerca de 950 árboles de 53 especies.',
    'alta', [['Wikipedia', 'https://es.wikipedia.org/wiki/Alameda_Bernardo_O%27Higgins_(Talca)']],
    fact='Su primer tramo lo construyeron presidiarios en 1792. En la grilla es la calle 4 Norte.', pri=1, wd='Q116365051')
add('la-victoria', 'Monumento La Victoria', 'ciudad', -35.42201, -71.66488, 'Alameda con 1 Oriente',
    'Estatua de 1904 que honra al Batallón Cívico de Talca en la Guerra del Pacífico. Como todo monumento público, es Monumento Nacional por el solo ministerio de la Ley 17.288, sin decreto propio.',
    'alta', [['Consejo de Monumentos Nacionales', CMN + 'monumentos-publicos/batallon-civico-de-talca-y-la-victoria']],
    fact='La obra fue encargada originalmente por el Perú; oficiales chilenos la tomaron como botín de guerra en 1882.', model='victoria', pri=2, cats=['patrimonio'], wd='Q116946069')
add('teatro-regional', 'Teatro Regional del Maule', 'ciudad', -35.42260, -71.66455, '1 Oriente 1484',
    'Principal escenario de artes escénicas de la región, inaugurado en 2005 junto a la Alameda.', 'alta',
    [['OpenStreetMap vía Mapcarta', MC + 'W214851535']], model='teatro', pri=2, wd='Q121307303,Q83509977')
add('liceo-abate-molina', 'Liceo Abate Molina', 'ciudad', -35.42206, -71.65878, 'Alameda, entre 5 y 6 Oriente',
    'Uno de los liceos más antiguos de Chile, creado por decreto en 1827. Sus alumnos fundaron el club Rangers en 1902.',
    'media', [['Consejo de Monumentos Nacionales', CMN + 'monumentos-publicos/abate-molina'], ICH],
    fact='La estatua del Abate Molina (1861) en su entrada fue la primera escultura fundida en Chile. El edificio es Inmueble de Conservación Histórica del Plan Regulador de 2011.', pri=3, cats=['patrimonio'], wd='Q16590864')
add('estadio', 'Estadio Fiscal de Talca', 'ciudad', -35.41991, -71.67281, 'Alameda 251',
    'Estadio Bicentenario Iván Azócar Bernales, casa de Rangers desde 1930. Tras la ampliación de 2019 recibe 16.070 espectadores.',
    'alta', [['OpenStreetMap vía Mapcarta', MC + 'W89069046'], ['IND', 'https://ind.cl/noticias/ind-rinde-homenaje-a-un-idolo-fiscal-de-talca-ahora-se-llama-estadio-bicentenario-ivan-azocar-bernales/']],
    model='estadio', pri=1, wd='Q5400204')
add('gimnasio-regional', 'Gimnasio Regional «Manuel Herrera Blanco»', 'ciudad', -35.426602, -71.639909, '16 Oriente 2388–2392',
    'Principal recinto techado de Talca y de la región, para básquetbol y espectáculos, bajo una cubierta de doce paños en estrella. Desde 2022 lleva el nombre del baloncestista talquino Manuel Herrera Blanco.',
    'alta', [['OpenStreetMap vía Mapcarta', MC + 'W89114822'], ['Talca Digital', 'https://talcadigital.cl/gimnasio-o-complejo-deportivo/4655/'],
             ['Diario Talca', 'https://diariotalca.cl/renombran-gimnasio-regional-en-honor-al-deportista-talquino-manuel-herrera-blanco/'],
             ['Mercado Público: licitación 2295-27-LP12', 'https://www.mercadopublico.cl/Procurement/Modules/RFB/DetailsAcquisition.aspx?qs=zbvW/Aigz6Q0rbiXJEWxDg%3D%3D']],
    fact='Su capacidad varía según la fuente (4.000, 4.500 o 5.000 espectadores). El Gobierno Regional del Maule adjudicó su «mejoramiento» en julio de 2012 (licitación 2295-27-LP12, financiada con el FNDR y el IND); las fotos de 2013 muestran la estructura de acero de la cubierta en obras.',
    model='gimnasio-regional', pri=2)
add('casino-dreams', 'Casino Dreams Talca (ex FITAL)', 'ciudad', -35.419112, -71.676615, '4 Norte 99',
    'Casino, centro de convenciones y salas de espectáculos de Dreams en el antiguo recinto de la FITAL, la feria agrícola, industrial y ganadera que la Agrícola Central hizo aquí desde 1947. El edificio, de madera y vidrio, se levanta sobre pilotes de 1,7 m porque el terreno es inundable; lo rodean un estacionamiento en anillo y plazas con piletas.',
    'media', [['SMA: Res. Ex. 2367/2025 (archiva la denuncia; describe el proyecto)', 'https://transparencia.sma.gob.cl/doc/resoluciones/RESOL_EXENTA_SMA_2025/denuncias_archivadas/RESOL%202367%20Archivo%20Casino%20Dreams.pdf'],
             ['Diario Financiero, agosto de 2025', 'https://www.df.cl/empresas/industria/dreams-inicia-obras-de-un-nuevo-casino-en-talca-en-terrenos-de-la-ex-fital'],
             ['Meganoticias: imágenes del proyecto', 'https://www.meganoticias.cl/nacional/489185-nuevo-casino-en-talca-dreams-como-sera-inauguracion-pdp-18-6-2025.html'],
             ['El Dínamo: el terreno inundable y el humedal', 'https://www.eldinamo.cl/reportajes/2025/03/01/el-polemico-proyecto-del-casino-dreams-en-talca-se-construiria-en-terreno-inundable-y-colinda-con-un-humedal-urbano/'],
             ['Diario El Centro, junio de 2026', 'https://www.diarioelcentro.cl/2026/06/15/dreams-informa-rechazo-de-recurso-ambiental-que-aun-no-se-resuelve-por-construccion-de-casino-en-talca/']],
    fact='En obras desde agosto de 2025; Dreams anunció la apertura para noviembre de 2026. Según la SMA: un edificio de dos pisos y un subterráneo, 7.655 m² construidos, 4,5 de las 8,8 ha del predio intervenidas y 373 estacionamientos. El terreno está en zona inundable del Plan Regulador (R-3B, con una franja en R-2), a unos 300 m del Humedal Urbano Cajón del Río Claro y Estero Piduco. El SEA resolvió en 2025 que no debía entrar a evaluación ambiental; en junio de 2026 seguía pendiente una solicitud de invalidación. El punto es el centro del edificio en el plano de la consulta de pertinencia; el modelo sigue ese plano y las imágenes del proyecto, y es aproximado.',
    model='casino-dreams', pri=2)
add('parque-rio-claro', 'Parque Río Claro', 'ciudad', -35.41810, -71.68045, 'Extremo poniente de la Alameda',
    'Parque de 11 hectáreas sobre el antiguo balneario Río Claro, renovado en dos etapas (2020 y 2023): paseos, juegos, juegos de agua y muelles flotantes junto a los botes.',
    'alta', [['Talca Sostenible', 'https://www.talcasostenible.cl/parque-rio-claro/'],
             ['Minvu', 'https://www.minvu.gob.cl/noticia/noticias/ministro-montes-inaugura-segunda-etapa-de-parque-urbano-rio-claro-de-talca']],
    model='parque', pri=2)
add('viejas-cochinas', 'Las Viejas Cochinas', 'ciudad', -35.41803, -71.68383, 'Rivera Poniente Río Claro s/n',
    'Restaurante de cocina chilena en la ribera poniente del Río Claro, frente al parque. Empezó en 1975 como una ramada de coligüe a la orilla del río que vendía sandías y pan amasado.',
    'alta', [['OpenStreetMap vía Mapcarta', MC + 'N3331425921'], ['De Buena Mesa (reseña de La Tercera, 2011)', 'https://debuenamesa.wordpress.com/2011/08/09/se-recomienda-las-viejas-cochinas-talca/']],
    fact='El nombre, oficial desde 1988, nació como burla de un vecino y la familia lo adoptó. Tras una crecida a fines de los años 90 se trasladó más lejos del río y a mayor altura.',
    model='cochinas', pri=3)
add('cerro-la-virgen', 'Cerro La Virgen', 'ciudad', -35.42270, -71.70318, 'Ribera poniente del Río Claro',
    'Su punto más alto, el Peñón (372 m), es el techo de la comuna y queda unos 2 km al norte del santuario. La Virgen del Carmen del santuario se inauguró en 1910, para el Centenario.',
    'alta', [['Wikipedia', 'https://es.wikipedia.org/wiki/Cerro_La_Virgen_(Talca)']], wd='Q125127353',
    fact='El relieve de la maqueta es el real (Copernicus GLO-30): el santuario queda a unos 265 m, 170 m sobre la Plaza de Armas. Las alturas están exageradas unas 3 veces en el plano y unas 1,3 veces en los cerros.', model='cerro', pri=1)
add('estacion', 'Estación de Ferrocarriles', 'ciudad', -35.42978, -71.64960, '11 Oriente 1000',
    'Principal estación del Maule. El tren de Santiago llegó en septiembre de 1875 y la estación se inauguró oficialmente el 1 de enero de 1878; fue reconstruida en 1929 y en 2017. Desde aquí parte el ramal Talca–Constitución, y con él es Monumento Histórico desde 2007.',
    'alta', [['OpenStreetMap vía Mapcarta', MC + 'N308140957'], ['Wikipedia', 'https://es.wikipedia.org/wiki/Estaci%C3%B3n_Talca'], ['Decreto 1030 de 2007 (CMN)', DEC + 'MH_01027_2007_D01030.PDF']],
    model='estacion', pri=1, cats=['patrimonio'], wd='Q5400061')
add('ramal-constitucion', 'Ramal Talca–Constitución', 'ciudad', -35.44022, -71.65053, 'Puente sobre el estero Piduco',
    'Ramal de trocha métrica construido entre 1888 y 1915, recorrido por el Buscarril. Monumento Histórico desde 2007.',
    'media', [['Consejo de Monumentos Nacionales', CMN + 'monumentos-historicos/ramal-ferroviario-talca-constitucion']], pri=3, cats=['patrimonio'], wd='Q24716650',
    fact='El decreto protege también, en la comuna, la tornamesa de Talca, el paso superior Moya y los puentes del estero Piduco, del canal El Molino y El Parrón 1.')
add('terminal-buses', 'Terminal de Buses', 'ciudad', -35.43027, -71.64733, '2 Sur, al oriente de la vía férrea',
    'Terminal interurbano Lorenzo Varoli, a 200 m de la estación de trenes.', 'alta',
    [['OpenStreetMap vía Mapcarta', MC + 'W110962821']], model='terminal', pri=3, wd='Q139934983')
add('cecinas-pf', 'Planta de Cecinas PF', 'ciudad', -35.415289, -71.628998, 'Calle de Servicio Ruta 5, costado oriente de la Ruta 5 Sur',
    'Sede industrial de PF Alimentos (Productos Fernández), la empresa de cecinas nacida en Talca a comienzos del siglo XX.', 'media',
    [['OpenStreetMap vía Mapcarta', MC + 'W297781219'], ['The Clinic, 2025', 'https://www.theclinic.cl/2025/07/28/la-reinvencion-de-pf-la-centenaria-firma-de-cecinas-que-nacio-en-talca-y-se-transformo-en-un-imperio-que-factura-us600-millones-al-ano/'],
     ['Amunategui Barreau: PF/Talca Industrial Complex', 'https://www.abarchitec.com/?p=83748']],
    fact='Según The Clinic, la producción de PF se reparte en seis plantas, todas en Talca.', model='cecinas', pri=3)
add('talca-country-club', 'Talca Country Club', 'ciudad', -35.421908, -71.623100, 'Calle Talca Country Club, nororiente de la ciudad',
    'Club de golf de nueve hoyos, con canchas de tenis y piscina, al nororiente de la ciudad.', 'media',
    [['OpenStreetMap vía Mapcarta', MC + 'W101587762'], ['GolfAdvisor', 'https://www.golfadvisor.com/courses/30115-talca-country-club']],
    model='golf', pri=3)
add('hospital-regional', 'Hospital Regional de Talca', 'ciudad', -35.42660, -71.64638, '1 Norte 1990',
    'Hospital de alta complejidad y cabecera de la red de salud del Maule.', 'alta',
    [['OpenStreetMap vía Mapcarta', MC + 'W618536526']], model='hospital', pri=2, wd='Q16576212')
add('mall-plaza-maule', 'Mall Plaza Maule', 'ciudad', -35.43242, -71.62991, 'Av. Circunvalación 30 Oriente 1055',
    'Principal centro comercial de la ciudad, en el sector oriente.', 'alta', [['OpenStreetMap vía Mapcarta', MC + 'W110780381']], model='mall', pri=3, wd='Q123786281')
add('parque-piduco', 'Parque Piduco', 'ciudad', -35.43735, -71.66091, 'Ribera del estero Piduco',
    'El parque urbano más grande de Talca: 25,9 hectáreas a lo largo de 3 km del estero.', 'alta',
    [['Talca Sostenible', 'https://www.talcasostenible.cl/parque-piduco/']],
    fact='«Piduco» vendría de «agua del pudú»; de ahí el gentilicio popular «piducanos».', pri=2)
add('plaza-las-heras', 'Plaza Las Heras', 'ciudad', -35.41774, -71.65838, 'Barrio norte, entre 5 y 6 Oriente',
    'Plaza de barrio dedicada al general Juan Gregorio Las Heras, frente a la iglesia San Luis.', 'alta',
    [['OpenStreetMap vía Mapcarta', 'https://mapcarta.com/es/W89069033']], pri=3)
add('cementerio', 'Cementerio General', 'ciudad', -35.40751, -71.66412, 'Sector norte',
    'Cementerio histórico de la ciudad, cuyos orígenes se remontan a 1847, con un memorial a los detenidos desaparecidos.', 'alta',
    [['OpenStreetMap vía Mapcarta', 'https://mapcarta.com/es/W86933822'], ['Wikipedia', 'https://es.wikipedia.org/wiki/Cementerio_Municipal_de_Talca']], model='cementerio', pri=3, wd='Q107846398')

# ------------------------------------------------------------------ PATRIMONIO
# Monumentos Históricos del CMN (capa de puntos oficiales, decretos) e Inmuebles de Conservación Histórica del PRC de
# 2011 (MINVU IDE) que no eran lugares; octubre de 2026. Las ubicaciones: OSM donde tiene el edificio, si no el punto
# del CMN o el centro del polígono del PRC (confianza media).
add('puente-pangue', 'Puente ferroviario sobre el río Pangue', 'ciudad', -35.353135, -71.574995,
    'Línea Central, en el límite norte de la comuna',
    'Viaducto de ladrillo de unos 60 m y ocho arcos de medio punto, construido hacia 1878–1880 para el ferrocarril al sur, con sus pilas estucadas imitando piedra. Monumento Histórico desde 1989. Los trenes pasan hoy por un puente de acero pintado de amarillo, unos metros al oriente.',
    'alta', [['Decreto 499 de 1989 (CMN)', DEC + 'MH_00478_1989_D00499.PDF'], ['OpenStreetMap vía Mapcarta', MC + 'N4289189189'],
             ['Foto de 2008 en Commons', 'https://commons.wikimedia.org/wiki/File:Puente_Pangue.JPG']],
    fact='El decreto lo protegió por ser el único puente de su tipo que seguía en pie en Chile. El límite de la comuna corre por el estero: la maqueta muestra solo la mitad sur de los dos puentes.',
    pri=2, wd='Q42898047', cats=['patrimonio'])
add('intendencia', 'Antigua Intendencia', 'ciudad', -35.426266, -71.664950, '1 Norte con 1 Oriente, frente a la plaza',
    'Edificio neoclásico del arquitecto Carlos Crouzat, levantado entre 1910 y 1915 para la Intendencia de la provincia de Talca. Monumento Histórico desde 2001. El terremoto de 2010 lo dejó inutilizable; una restauración empezada en 2022 quedó inconclusa.',
    'alta', [['Decreto 103 de 2001 (CMN)', DEC + 'MH_00800_2001_D00103.PDF'], ['Wikipedia', 'https://es.wikipedia.org/wiki/Edificio_de_la_Intendencia_de_la_Regi%C3%B3n_del_Maule'],
             ['OpenStreetMap vía Mapcarta', MC + 'W275506476']],
    fact='Su fachada hacia la Plaza de Armas tenía un tercer piso bajo una mansarda, que se quitó en la reparación de 2011.', pri=3, cats=['gobierno', 'patrimonio'], wd='Q16559130')
add('edificio-ohiggins', 'Edificio O\'Higgins (ex Banco de Talca)', 'ciudad', -35.427383, -71.665628, '1 Sur 790, esquina 1 Oriente',
    'Edificio art déco de hormigón de los arquitectos Carlos y Alberto Cruz Eyzaguirre, construido entre 1929 y 1930 como casa matriz del Banco de Talca, que el terremoto de 1928 había dejado sin sede. Inmueble de Conservación Histórica del Plan Regulador de 2011.',
    'media', [ICH, ['Wikipedia', 'https://es.wikipedia.org/wiki/Edificio_O%27Higgins'], ['Foto de 2014 en Commons', 'https://commons.wikimedia.org/wiki/File:Ex_Banco_de_Talca.jpg']],
    fact='Entre 2010 y 2021 funcionaron aquí oficinas de la Fiscalía, mientras se construían sus edificios; desde entonces está desocupado. Ubicación: el polígono del Plan Regulador.', pri=3, wd='Q131410816', cats=['patrimonio'])
add('buen-pastor', 'Iglesia del Buen Pastor', 'ciudad', -35.428801, -71.673358, '3 Sur, a la altura del 7½ Poniente',
    'Iglesia neogótica que levantó entre 1887 y 1900 la congregación del Buen Pastor, que acogía mujeres y educaba niñas huérfanas; su fachada neorrománica es de la reconstrucción que siguió al terremoto de 1928. Monumento Histórico desde 1993; hoy se llama también del Apóstol Pedro.',
    'alta', [['Decreto 281 de 1993 (CMN)', DEC + 'MH_00592_1993_D00281.PDF'], ['Wikipedia', 'https://es.wikipedia.org/wiki/Iglesia_del_Ap%C3%B3stol_Pedro'], ['OpenStreetMap vía Mapcarta', MC + 'W310246576']],
    fact='El terremoto de 2010 la dejó muy dañada: está cerrada y abandonada.', pri=3, wd='Q42898048,Q50750351', cats=['patrimonio'])
add('huilquilemu', 'Casa Patronal de Huilquilemu', 'ciudad', -35.462210, -71.577126, 'Avenida San Miguel, Huilquilemu',
    'Casona de adobe de hacia 1850, con corredores en torno a un patio, en un parque de árboles centenarios. Desde 1975 es de la Universidad Católica (hoy la UCM), que la restauró como Villa Cultural Huilquilemu y museo. Monumento Histórico desde 1986.',
    'alta', [['Decreto 1092 de 1986 (CMN)', DEC + 'MH_00423_1986_D01092.PDF'], ['Wikipedia', 'https://es.wikipedia.org/wiki/Casa_patronal_de_Huilquilemu'],
             ['OpenStreetMap vía Mapcarta', MC + 'W244752822']],
    fact='La mandó construir Bruno González, que hizo fortuna en la minería del Norte Grande. Tras el terremoto de 2010 se restauró hasta 2013.', pri=2, wd='Q42898043,Q86280850', cats=['patrimonio'])
add('estacion-mercedes', 'Estación Mercedes', 'ciudad', -35.470332, -71.553539, 'Mercedes, al oriente de la comuna',
    'Estación de madera de 1900 del antiguo ramal Talca–Mariposas, que llevó trenes hacia la precordillera hasta 1975. Restaurada en 2005 como centro comunitario. Monumento Histórico desde 2010.',
    'alta', [['Decreto 98 de 2010 (CMN)', DEC + 'MH_01229_2010_D00098.PDF'], ['Wikipedia', 'https://es.wikipedia.org/wiki/Estaci%C3%B3n_Mercedes_(Chile)'],
             ['OpenStreetMap vía Mapcarta', MC + 'W475336898']], pri=3, wd='Q42899036', cats=['patrimonio'])
add('iglesia-san-agustin', 'Iglesia de San Agustín', 'ciudad', -35.421339, -71.663615, '2 Oriente 1500, junto a la Alameda',
    'Iglesia del convento de los agustinos, la orden que cedió el terreno donde se fundó la villa de San Agustín de Talca en 1742. Inmueble de Conservación Histórica del Plan Regulador de 2011.',
    'alta', [['OpenStreetMap vía Mapcarta', MC + 'W802004025'], ICH],
    fact='El Plan Regulador le da la dirección Alameda 1334, que es la del Liceo de Niñas; su polígono y OpenStreetMap la ubican en 2 Oriente.', pri=3, cats=['patrimonio'])
add('maria-auxiliadora', 'Santuario de María Auxiliadora', 'ciudad', -35.428469, -71.660131, '2 Sur 1147 (Av. Monseñor Manuel Larraín)',
    'Templo de los salesianos, inaugurado en 1915 donde desde 1807 estuvo la capilla del antiguo Hospital San Juan de Dios. Él y el colegio salesiano vecino son Inmuebles de Conservación Histórica del Plan Regulador de 2011.',
    'alta', [['OpenStreetMap vía Mapcarta', MC + 'W565185280'], ['Wikipedia', 'https://es.wikipedia.org/wiki/Santuario_de_Mar%C3%ADa_Auxiliadora_(Talca)'], ICH],
    fact='Los salesianos llegaron a Talca en 1888 y compraron el edificio del hospital, que se había trasladado.', pri=3, wd='Q130639815', cats=['patrimonio'])
add('san-francisco', 'Iglesia de San Francisco (Pompeya)', 'ciudad', -35.426714, -71.668635, '1 Sur con 2 Poniente',
    'Iglesia de San Francisco de Asís, a una cuadra al poniente de la Plaza de Armas. Inmueble de Conservación Histórica del Plan Regulador de 2011, que la nombra también «de Pompeya».',
    'alta', [['OpenStreetMap vía Mapcarta', MC + 'W799509091'], ICH], pri=3, cats=['patrimonio'])
add('corazon-de-maria', 'Iglesia del Corazón de María', 'ciudad', -35.428433, -71.655905, '2 Sur 1499, cerca de 8 Oriente',
    'Iglesia del barrio oriente del centro. Inmueble de Conservación Histórica del Plan Regulador de 2011.',
    'media', [ICH], fact='Ubicación: el centro del polígono del Plan Regulador; OpenStreetMap no tiene el edificio con nombre.', pri=3, cats=['patrimonio'])
add('liceo-ninas', 'Liceo de Niñas (Liceo Marta Donoso Espejo)', 'ciudad', -35.423320, -71.657153, 'Alameda 1334',
    'El antiguo Liceo de Niñas de Talca, hoy Liceo Marta Donoso Espejo, frente a la Alameda. Su edificio es Inmueble de Conservación Histórica del Plan Regulador de 2011.',
    'alta', [['OpenStreetMap vía Mapcarta', MC + 'W111123034'], ICH], pri=3, cats=['patrimonio'])
add('club-talca', 'Club Talca', 'ciudad', -35.427785, -71.665886, '1 Oriente 1033',
    'Edificio del Club Talca, en 1 Oriente al sur de la Plaza de Armas. Inmueble de Conservación Histórica del Plan Regulador de 2011.',
    'media', [ICH], fact='Ubicación: el polígono del Plan Regulador. OpenStreetMap llama «Centro Español» a este edificio, pero el Centro Español está en 3 Oriente.', pri=3, cats=['patrimonio'])
add('centro-espanol', 'Centro Español', 'ciudad', -35.427053, -71.662810, '3 Oriente 1109, esquina 1 Sur',
    'Edificio del Centro Español, frente al Paseo 1 Sur. Inmueble de Conservación Histórica del Plan Regulador de 2011.',
    'alta', [['OpenStreetMap vía Mapcarta', MC + 'W310550395'], ICH], pri=3, cats=['patrimonio'])
add('hotel-plaza', 'Hotel Plaza', 'ciudad', -35.426582, -71.667061, '1 Poniente 1141, frente a la plaza',
    'Edificio del Hotel Plaza, en el costado poniente de la Plaza de Armas. Inmueble de Conservación Histórica del Plan Regulador de 2011.',
    'media', [ICH], fact='Ubicación: el polígono del Plan Regulador.', pri=3, cats=['patrimonio'])
add('ex-registro-civil', 'Antiguo Registro Civil', 'ciudad', -35.424421, -71.665383, '1 Oriente 1311',
    'Antiguo edificio del Registro Civil, que el Plan Regulador de 2011 protege como Inmueble de Conservación Histórica. La oficina de hoy está en 3 Sur 1188.',
    'media', [ICH], fact='Ubicación: el polígono del Plan Regulador.', pri=3, cats=['notarial', 'patrimonio'])
add('ex-hospicio', 'Antiguo Hospicio e iglesia', 'ciudad', -35.434617, -71.679216, 'Av. Ignacio Carrera Pinto 106',
    'Ruinas del antiguo hospicio de Talca y su iglesia, al sur poniente del centro. Inmueble de Conservación Histórica del Plan Regulador de 2011.',
    'alta', [['OpenStreetMap vía Mapcarta', MC + 'W587986690'], ICH], pri=3, cats=['patrimonio'])

# ------------------------------------------------------------------ HISTORIA: MEMORIA
add('sitio-memoria', 'Sitio de Memoria 4 Oriente 1470', 'historia', -35.423117, -71.660504, '4 Oriente 1470',
    'Inmueble que ocupó la DINA y, después, la CNI, los organismos de seguridad de la dictadura. Declarado Monumento Histórico en 2023 (D.S. 31) como sitio de memoria.',
    'alta', [['CMN: capa de Monumentos Nacionales', 'https://services2.arcgis.com/mQ0T5ijzGExuCc9o/arcgis/rest/services/Puntos_Oficiales_Monumentos_Nacionales_(Vista)/FeatureServer/0']],
    pri=2, cats=['patrimonio'])
add('la-espera', 'La espera en el tiempo', 'historia', -35.421587, -71.670743, 'Alameda, entre 4 y 5 Poniente',
    'Escultura de Graciela Albridi en memoria de las víctimas de la dictadura, impulsada por la Agrupación de Familiares de Detenidos Desaparecidos y Ejecutados Políticos e inaugurada en junio de 2014.',
    'media', [['Wikipedia', 'https://es.wikipedia.org/wiki/La_espera_en_el_tiempo'], ['Wikidata', 'https://www.wikidata.org/wiki/Q100149210']],
    fact='Ha sido dañada varias veces desde su inauguración. Ubicación: el punto de Wikidata, que calza con la cuadra que da Wikipedia.', pri=3, wd='Q100149210')
add('cancha-rayada', 'Batalla de Cancha Rayada (1818)', 'historia', -35.405459, -71.645833, 'Sector Cancha Rayada, al norte de la ciudad',
    'La noche del 19 de marzo de 1818, un mes después de jurada la Independencia en Talca, el ejército realista de Mariano Osorio sorprendió aquí al ejército patriota de San Martín y O\'Higgins, que se dispersó. El 5 de abril, en Maipú, los patriotas ganaron la guerra.',
    'baja', [['Wikipedia', 'https://es.wikipedia.org/wiki/Batalla_de_Cancha_Rayada_(1818)'], ['Wikidata', 'https://www.wikidata.org/wiki/Q333088']],
    fact='El punto es aproximado: es el que Wikidata da al campo de batalla, y OpenStreetMap llama Cancha Rayada a un sector unos 700 m al poniente. No hay un monumento en el lugar.',
    pri=3, wd='Q333088,Q5747044')

TOURS = {
    'justicia': dict(n='Ruta de la Justicia', d='Del juramento de 1818 al barrio cívico de la Alameda, a pie en unos 3 km.',
        s=['plaza-de-armas', 'casa-independencia', 'contraloria', 'cbr-talca', 'notaria-5', 'tta-maule', 'juzgado-familia',
           'fiscalia-regional', 'fiscalia-local', 'corte-apelaciones', 'garantia-top', 'ex-carcel', 'utalca-derecho', 'trifolia']),
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
    w.writerow(['id', 'nombre', 'categoria', 'categorias_extra', 'direccion', 'lat', 'lon', 'confianza', 'modelo_3d', 'prioridad', 'descripcion', 'dato', 'instituciones', 'fuentes', 'wikidata'])
    for p in P:
        w.writerow([p['id'], p['n'], p['c'], ';'.join(p['cs']), p['a'], p['lat'], p['lon'], p['conf'], p['m'] or '', p['p'], p['d'], p['f'] or '',
                    ' | '.join(p['sub'] or []), ' | '.join(f'{a} <{b}>' for a, b in p['src']), p.get('wd', '')])
print(len(P), 'lugares ->', DATA / 'pois.json', 'y pois.csv')
