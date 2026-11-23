# Los materiales del juego, en un solo lugar (hasta noviembre de 2026 había tres: este, modelos/entorno/materiales.gd y
# el shader() de plaza.gd). Los sombreadores están en shaders/.
#
#   const Mat := preload("res://materiales.gd")
#   Mat.capa("edificios", "edificio")   # una capa del glb (shaders/capa.gdshader), con su color por vértice; el tipo
#                                       # sale de mapa/indice.json (glb.gd): suelo, edificio, hito, arbol, auto
#   Mat.follaje(c), Mat.tierra(c)       # capa.gdshader con un color fijo
#   Mat.patron("ladrillo")              # los dibujos de los modelos del entorno (shaders/patron.gdshader; PATRON),
#                                       # uno por nombre, compartido: malla.gd construir() y malla()
#   Mat.plaza("piedra", {"rugoso": 0.8})  # un sombreador de shaders/plaza/ con sus parámetros (plaza.gd, plaza/*.gd)
#   Mat.tinte("pintura")                # patron() en un MultiMesh: el alfa 0 toma el color de la instancia (autos.gd)
#   Mat.textura(tex)                    # una textura con transparencia por recorte (rejas, filigranas)
#
# En capa.gdshader el color va en sRGB, como en la página; las texturas son en coordenadas del mundo y reconocen la
# orientación de cada cara. La hora del día llega por los parámetros globales `noche` y `sol_dir` (ambiente.gd).
extends RefCounted

const SHADER := preload("res://shaders/capa.gdshader")
const SHADER_FOLLAJE := preload("res://shaders/follaje.gdshader")  # tipo 3: las copas no reciben sombras
const SHADER_PATRON := preload("res://shaders/patron.gdshader")

# el número de cada tipo de capa (el «tipo» de mapa/indice.json, LAYERS de tools/export.js) en capa.gdshader
const TIPOS := {"suelo": 0, "edificio": 1, "hito": 2, "arbol": 3, "auto": 4}

# las clases de capa.gdshader (su uniform `clase`; -1: la reconoce por el color)
const ESTUCO := 0
const ASFALTO := 1
const BALDOSA := 2
const PASTO := 3
const TIERRA := 4
const AGUA := 5
const TEJA := 6
const ZINC := 7
const FOLLAJE := 8
const CORTEZA := 9
const PINTURA := 10
const VIDRIO := 11
const TECHO := 12
const PIEDRA := 13

# los dibujos de patron.gdshader: liso (revoque con manchas suaves), ladrillo (0,29 × 0,07 m, trabado, cantería de
# mortero), hormigon (losas de calzada de 3,5 × 4,5 m con juntas y manchas: OSM dice surface=concrete en las cuatro
# calles, y se ven en la foto de 1 Norte de 2022 en Commons), baldosa (40 × 40 cm con 16 botones, la «baldosa
# microvibrada» de las veredas de Talca, foto de 1 Norte), teja (hileras de teja de arcilla), granito (soleras y
# peldaños), pizarra (escamas del chapitel), asfalto (1 Oriente: OSM dice surface=asphalt al sur de la plaza, y las
# fotos de 2022 de la esquina de 1 Norte lo muestran también al norte), metal y vidrio (sin dibujo), ventana (el vidrio de
# fachadas_ciudad.gd: de noche se encienden las de alfa 1)
const PATRON := {"liso": 0, "ladrillo": 1, "hormigon": 2, "baldosa": 3, "teja": 4, "granito": 5, "pizarra": 6,
	"metal": 7, "vidrio": 8, "pintura": 9, "tela": 10, "emisivo": 11, "asfalto": 12, "ventana": 13}
const RUGOSIDAD := {"metal": 0.38, "pintura": 0.55, "granito": 0.7, "emisivo": 0.5, "pizarra": 0.6}

const ALZAR_AGUA := 0.06  # m: el agua sobre el ripio de las orillas, que está a su misma altura (trampa «Los ríos están sobre las manzanas, a 0,11»)
static var _capas := {}
static var _patrones := {}
static var _plaza := {}


# el material de una capa del glb, de su tipo (glb.gd; compartido: una capa, un material)
static func capa(nombre: String, tipo: String) -> ShaderMaterial:
	if not _capas.has(nombre):
		_capas[nombre] = _vertices(TIPOS[tipo])
		if nombre == "agua":  # la página la dibuja con polygonOffset: gana donde coincide con la orilla (ALZAR_AGUA)
			_capas[nombre].set_shader_parameter("alzar", ALZAR_AGUA)
	return _capas[nombre]


static func _vertices(tipo: int) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER_FOLLAJE if tipo == 3 else SHADER
	m.set_shader_parameter("tipo", tipo)
	return m


static func _color(c: Color, tipo: int, clase: int) -> ShaderMaterial:
	var m := _vertices(tipo)
	m.set_shader_parameter("color_vertice", false)
	m.set_shader_parameter("color", c)
	m.set_shader_parameter("clase", clase)
	return m


static func tierra(c := Color("b4957b")) -> ShaderMaterial: return _color(c, 0, TIERRA)
static func follaje(c := Color("587d3a")) -> ShaderMaterial: return _color(c, 3, FOLLAJE)


# el material de un dibujo de los modelos del entorno (uno por nombre, compartido)
static func patron(nombre: String) -> Material:
	if _patrones.has(nombre):
		return _patrones[nombre]
	var m: Material
	if nombre == "vidrio":
		var s := StandardMaterial3D.new()
		s.vertex_color_use_as_albedo = true
		s.vertex_color_is_srgb = true
		s.metallic = 0.55
		s.roughness = 0.06
		s.metallic_specular = 0.8
		m = s
	else:
		var sm := ShaderMaterial.new()
		sm.shader = SHADER_PATRON
		sm.set_shader_parameter("patron", PATRON.get(nombre, 0))
		sm.set_shader_parameter("rugosidad", RUGOSIDAD.get(nombre, 0.88))
		sm.set_shader_parameter("metalico", 0.45 if nombre == "metal" else 0.0)
		if nombre == "emisivo":
			sm.set_shader_parameter("emision", 0.9)
		m = sm
	_patrones[nombre] = m
	return m


# patron(nombre) para un MultiMesh con use_custom_data: los vértices de alfa 0 toman el color de su instancia (la
# carrocería de los autos de autos.gd); el vidrio, que no lo usa, es el de patron()
static func tinte(nombre: String) -> Material:
	var k := nombre + "/tinte"
	if not _patrones.has(k):
		var m := patron(nombre)
		if m is ShaderMaterial:
			m = m.duplicate()
			m.set_shader_parameter("tinte", true)
		_patrones[k] = m
	return _patrones[k]


# un material nuevo con un sombreador de shaders/plaza/ (piedra, pavimento, pasto, pasto_hojas, agua, zinc, farol,
# corteza, follaje) y sus parámetros
static func plaza(nombre: String, params := {}) -> ShaderMaterial:
	if not _plaza.has(nombre):
		_plaza[nombre] = load("res://shaders/plaza/%s.gdshader" % nombre)
	var m := ShaderMaterial.new()
	m.shader = _plaza[nombre]
	for k in params:
		m.set_shader_parameter(k, params[k])
	return m


# una textura con transparencia por recorte, de las dos caras (rejas, filigranas, flores)
static func textura(tex: Texture2D, metal := 0.5, rugoso := 0.45) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.albedo_color = Color(1, 1, 1)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.4
	m.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.metallic = metal
	m.roughness = rugoso
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m
