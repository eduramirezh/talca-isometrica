# Materiales del juego: shaders/capa.gdshader con las opciones de cada capa del glb y de cada superficie, para que
# los modelos propios (modelos/*.gd) se vean igual que la maqueta que los rodea.
#
#   const Mat := preload("res://materiales.gd")
#   malla.material_override = Mat.capa("edificios")          # una capa del glb, con su color por vértice
#   caja.material = Mat.fachada(Color("e5d2c2"))             # estuco con ventanas cada 3,4 × 3,0 m
#   caja.material = Mat.fachada(Color("e5d2c2"), false)      # estuco sin ventanas
#   piso.material = Mat.baldosa(Color("cac3a9"))             # baldosa de 40 cm con junta
#   Mat.pasto(c), Mat.tierra(c), Mat.asfalto(c), Mat.piedra(c), Mat.teja(c), Mat.zinc(c), Mat.techo(c),
#   Mat.follaje(c), Mat.corteza(c), Mat.pintura(c) (autos), Mat.vidrio(c), Mat.agua(c)
#   Mat.superficie(c)                                        # la reconoce por el color, como en la maqueta
#   Mat.vertices(tipo)                                       # con el color por vértice de la malla y el tipo de capa
#
# Todas devuelven un ShaderMaterial nuevo; el color va en sRGB, como en la página. Las texturas son en coordenadas del
# mundo (no necesitan UV) y reconocen la orientación de cada cara: una caja con fachada() tiene ventanas en los
# muros y estuco en la tapa. Las ventanas y las juntas usan la altura sobre la plaza (Y = 0), no sobre la caja.
# La hora del día llega por los parámetros globales `noche` y `sol_dir` (ambiente.gd): de noche las ventanas se
# encienden solas.
extends RefCounted

const SHADER := preload("res://shaders/capa.gdshader")
const SHADER_FOLLAJE := preload("res://shaders/follaje.gdshader")  # tipo 3: las copas no reciben sombras

# tipo de cada capa del glb (capa.gdshader): 0 suelo, 1 edificio con ventanas, 2 hito, 3 árbol, 4 auto
const TIPOS := {"terreno": 0, "suelo": 0, "usos": 0, "patios": 0, "veredas": 0, "ciudad": 1, "edificios": 1,
	"hitos": 2, "arboles": 3, "alamos": 3, "autos": 4, "autos-ruta5": 4, "agua": 0}

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

static var _capas := {}


# el material de una capa del glb (compartido: una capa, un material)
static func capa(nombre: String) -> ShaderMaterial:
	if not _capas.has(nombre):
		_capas[nombre] = vertices(TIPOS.get(nombre, 0))
	return _capas[nombre]


static func vertices(tipo: int) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER_FOLLAJE if tipo == 3 else SHADER
	m.set_shader_parameter("tipo", tipo)
	return m


static func _color(c: Color, tipo: int, clase: int) -> ShaderMaterial:
	var m := vertices(tipo)
	m.set_shader_parameter("color_vertice", false)
	m.set_shader_parameter("color", c)
	m.set_shader_parameter("clase", clase)
	return m


static func superficie(c: Color, tipo := 2) -> ShaderMaterial: return _color(c, tipo, -1)
static func fachada(c: Color, ventanas := true) -> ShaderMaterial: return _color(c, 1 if ventanas else 2, ESTUCO)
static func asfalto(c := Color("5f5b57")) -> ShaderMaterial: return _color(c, 0, ASFALTO)
static func baldosa(c := Color("cac3a9")) -> ShaderMaterial: return _color(c, 0, BALDOSA)
static func pasto(c := Color("6f864a")) -> ShaderMaterial: return _color(c, 0, PASTO)
static func tierra(c := Color("b4957b")) -> ShaderMaterial: return _color(c, 0, TIERRA)
static func agua(c := Color("3c6f9a")) -> ShaderMaterial: return _color(c, 0, AGUA)
static func teja(c := Color("a4553a")) -> ShaderMaterial: return _color(c, 2, TEJA)
static func zinc(c := Color("7d8285")) -> ShaderMaterial: return _color(c, 2, ZINC)
static func techo(c := Color("b8b4aa")) -> ShaderMaterial: return _color(c, 2, TECHO)
static func piedra(c := Color("b9b4a8")) -> ShaderMaterial: return _color(c, 2, PIEDRA)
static func follaje(c := Color("587d3a")) -> ShaderMaterial: return _color(c, 3, FOLLAJE)
static func corteza(c := Color("5e4a35")) -> ShaderMaterial: return _color(c, 3, CORTEZA)
static func pintura(c := Color("8a1c1c")) -> ShaderMaterial: return _color(c, 4, PINTURA)
static func vidrio(c := Color("1d232b")) -> ShaderMaterial: return _color(c, 4, VIDRIO)
