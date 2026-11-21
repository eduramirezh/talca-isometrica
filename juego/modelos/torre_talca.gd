# La Torre Talca (1 Sur 865), en el interior de la manzana de 1 Norte, 1 Sur, 1 y 2 Oriente, con el detalle que pide
# una cámara a 1,7 m: ventanas y cintas de ventanas hundidas con su vidrio y sus montantes, las bandas blancas de las
# losas, la planta baja vidriada con su puerta, el pretil, la sala de máquinas roja y el letrero de Trifolia en el techo.
# Reemplaza el hito de la página (capa «hitos» del glb dentro de su planta).
#
# Planta y alturas: las del hito (src/js/hitos/torre-talca.js, su encabezado dice de dónde sale cada cosa): OSM
# w310246574, un ala sur de 16 m y una parte norte más angosta, retirada 2,6 m al poniente; doce pisos, la planta baja
# de 4,2 m y once de 3 m, hasta 37,2 m sobre la explanada de la plaza. Las caras, de una foto de Commons desde el
# poniente (2007) y de Mapillary (CC BY-SA 4.0, kaartcam, febrero de 2018; la torre es de ~1990): desde 1 Norte
# (507847920560801) la cara norte con una cinta de ventanas por piso entre bandas blancas y, al oriente de la parte
# norte, una ventana por piso junto a la esquina; desde 1 Sur y 2 Oriente (398133034526935, 1445198049155522) la cara
# oriente del ala sur en cintas y la sur blanca, con una ventana ancha y una chica junto a la esquina poniente por piso
# y equipos de aire acondicionado, y el letrero del techo de canto. Las cámaras de 2018 yerran ~10° y algunos metros
# (trampa «La posición de una foto de Mapillary puede errar 10 m»): la torre se reconoció por ser la única alta ahí
# (y por su techo rojo en la imagen de Esri), y las caras por el lado de la calle desde donde se ven, no por la planta
# dibujada encima. Aproximado: el lugar de las ventanas en las caras sur y oriente, los montantes, la puerta, los
# equipos de aire y el tamaño del letrero.
#
# musica.gd reconoce el techo por la planta de OSM y la altura (más de 25 m): el modelo tiene la misma planta, y su
# azotea queda a 36,3 m.
extends Node3D

const Malla := preload("res://malla.gd")
const Suelo := preload("res://modelos/entorno/suelo.gd")

const PLANTA := [[152.6, -25.8], [168.6, -25.8], [168.6, -13.2], [167.6, -13.2], [167.6, -5.2], [155.2, -5.2],
	[155.2, -16.2], [152.6, -16.2]]
const TOP := 37.2
const PRETIL := 0.9
const PB := 4.2  # la planta baja
const FH := 3.0  # cada piso sobre ella
const PISOS := 11

const K := {
	"muro": Color("ece7dc"), "blanco": Color("f4f0e6"), "derrame": Color("d8d3c8"), "zocalo": Color("bdb8ae"),
	"vidrio": Color("3b4653"), "vidrio2": Color("2c3540"), "aluminio": Color("6a6e72"), "techo": Color("a35c42"),
	"rojo": Color("b04a3c"), "rojo2": Color("93402f"), "marco": Color("b9b7b0"), "letrero": Color("e9e7e0"),
	"metal": Color("707070"), "aire": Color("cfd0cc"),
}

var m := Malla.new()
var f: Malla.Marco
var rng := RandomNumberGenerator.new()


func recortes() -> Array:
	var p := PackedVector2Array()
	for q in PLANTA:
		p.append(Vector2(q[0], q[1]))
	return [{"poligono": Malla.adentro(p, -0.6), "capas": ["hitos"]}]


func _ready() -> void:
	var S := Suelo.new(get_parent())
	f = Malla.grilla(S.E(160.6, -15.5))
	rng.seed = 865
	caras()
	planta_baja()
	techo()
	m.construir(self, "torre-talca")
	letrero_texto()


# ---------------------------------------------------------------- ayudas

func V2(u: float, v: float) -> Vector2:
	return Vector2(u, v)


func piso(k: int) -> float:
	return PB + k * FH


func vidrio() -> Color:
	var c: Color = K["vidrio"] if rng.randf() < 0.5 else K["vidrio2"]
	c.a = 1.0 if rng.randf() < 0.35 else 0.5
	return c


# s de una coordenada (x o y, según el muro) a lo largo de a -> b
func s_de(a: Vector2, b: Vector2, c: float) -> float:
	var d := (b - a).normalized()
	var p := Vector2(c, a.y) if absf(d.x) > 0.5 else Vector2(a.x, c)
	return (p - a).dot(d)


# los vanos [s0, s1, z0, z1, montantes cada ~m (0: uno al medio)] de un muro a -> b (afuera a la derecha), de -10 a
# TOP, hundidos 0,15 m con su vidrio, sus montantes y un alféizar blanco
func fachada(a: Vector2, b: Vector2, vanos: Array) -> void:
	var huecos := []
	for w in vanos:
		var s0: float = w[0]
		var s1: float = w[1]
		var z0: float = w[2]
		var z1: float = w[3]
		huecos.append(PackedVector2Array([Vector2(s0, z0), Vector2(s1, z0), Vector2(s1, z1), Vector2(s0, z1)]))
	m.muro_vanos(f, a, b, -10, TOP, huecos, K["muro"])
	for i in vanos.size():
		var w: Array = vanos[i]
		var s0: float = w[0]
		var s1: float = w[1]
		var z0: float = w[2]
		var z1: float = w[3]
		var paso: float = w[4]
		m.derrame(f, a, b, huecos[i], 0.15, K["derrame"], "liso", vidrio(), "ventana")
		m.solido = false
		var n := 2 if paso <= 0 else maxi(1, roundi((s1 - s0) / paso))
		for j in range(1, n):
			var s := s0 + (s1 - s0) * j / n
			m.moldura(f, a, b, s - 0.03, s + 0.03, z0, z1, -0.1, K["aluminio"], "metal", -0.15)
		m.moldura(f, a, b, s0 - 0.05, s1 + 0.05, z0 - 0.06, z0, 0.05, K["blanco"])
		m.solido = true


# una ventana por piso centrada en c (x o y) de ancho w, en los once pisos
func ventanas(a: Vector2, b: Vector2, c: float, w: float, alto := 1.3, desde := 1.0) -> Array:
	var out := []
	var s := s_de(a, b, c)
	for k in PISOS:
		out.append([s - w / 2, s + w / 2, piso(k) + desde, piso(k) + desde + alto, 0.0])
	return out


# una cinta de ventanas por piso de c0 a c1, con montantes cada ~1,3 m; la del último piso, más alta si alto_ultimo
func cintas(a: Vector2, b: Vector2, c0: float, c1: float, alto_ultimo := false) -> Array:
	var out := []
	var s0 := s_de(a, b, c0)
	var s1 := s_de(a, b, c1)
	for k in PISOS:
		var z0 := piso(k) + (0.4 if alto_ultimo and k == PISOS - 1 else 1.0)
		var z1 := piso(k) + (2.6 if alto_ultimo and k == PISOS - 1 else 2.3)
		out.append([minf(s0, s1), maxf(s0, s1), z0, z1, 1.3])
	return out


# las bandas blancas de las losas, que salen 5 cm, de c0 a c1 del muro a -> b
func bandas(a: Vector2, b: Vector2, c0: float, c1: float) -> void:
	var s0 := s_de(a, b, c0)
	var s1 := s_de(a, b, c1)
	for k in PISOS:
		m.moldura(f, a, b, minf(s0, s1), maxf(s0, s1), piso(k) - 0.15, piso(k) + 0.25, 0.05, K["blanco"])


# ---------------------------------------------------------------- las caras

func caras() -> void:
	# sur: blanca, una ventana ancha y una chica junto a la esquina poniente por piso, y el aire acondicionado
	var a := V2(152.6, -25.8)
	var b := V2(168.6, -25.8)
	var vs := ventanas(a, b, 160.2, 4.4)
	vs.append_array(ventanas(a, b, 153.8, 1.0))
	fachada(a, b, vs)
	for k in PISOS:
		if rng.randf() < 0.6:
			m.caja(f, 162.7, -26.25, 163.5, -25.8, piso(k) + 0.9, piso(k) + 1.45, K["aire"], "metal")
	# oriente del ala sur: cintas entre bandas; el escalón de 1 m; la parte norte, una ventana por piso junto a la esquina
	a = V2(168.6, -25.8); b = V2(168.6, -13.2)
	fachada(a, b, cintas(a, b, -25.2, -13.8))
	bandas(a, b, -25.8, -13.2)
	fachada(V2(168.6, -13.2), V2(167.6, -13.2), [])
	a = V2(167.6, -13.2); b = V2(167.6, -5.2)
	fachada(a, b, ventanas(a, b, -7.6, 1.4))
	# norte: una cinta por piso, la del último más alta
	a = V2(167.6, -5.2); b = V2(155.2, -5.2)
	fachada(a, b, cintas(a, b, 167.0, 155.8, true))
	bandas(a, b, 167.6, 155.2)
	# poniente de la parte norte: ciega, con una columna de ventanas chicas junto a la esquina sur (Commons, 2007)
	a = V2(155.2, -5.2); b = V2(155.2, -16.2)
	fachada(a, b, ventanas(a, b, -14.8, 1.2, 1.1, 1.2))
	# el ala sur: su cara norte al poniente de la parte norte y su cara poniente, en cintas
	a = V2(155.2, -16.2); b = V2(152.6, -16.2)
	fachada(a, b, cintas(a, b, 154.8, 153.0))
	bandas(a, b, 155.2, 152.6)
	a = V2(152.6, -16.2); b = V2(152.6, -25.8)
	fachada(a, b, cintas(a, b, -16.6, -25.2))
	bandas(a, b, -16.2, -25.8)


# la planta baja: vidriada bajo una banda blanca en todo el contorno, con la puerta al sur (la entrada desde 1 Sur)
func planta_baja() -> void:
	var p := PLANTA
	for i in p.size():
		var a := V2(p[i][0], p[i][1])
		var b := V2(p[(i + 1) % p.size()][0], p[(i + 1) % p.size()][1])
		var L := a.distance_to(b)
		m.moldura(f, a, b, 0.0, L, PB - 0.5, PB, 0.08, K["blanco"])
		m.moldura(f, a, b, 0.0, L, -1.0, 0.3, 0.03, K["zocalo"], "hormigon")
		if L < 2:
			continue
		var c := Color(K["vidrio2"])
		c.a = 1.0
		m.panel(f, a, b, 0.4, L - 0.4, 0.3, PB - 0.8, 0.01, c, "ventana")
		m.solido = false
		var n := maxi(1, roundi((L - 0.8) / 1.6))
		for j in range(n + 1):
			var s := 0.4 + (L - 0.8) * j / n
			m.moldura(f, a, b, s - 0.04, s + 0.04, 0.3, PB - 0.5, 0.06, K["aluminio"], "metal")
		m.moldura(f, a, b, 0.4, L - 0.4, 2.6, 2.68, 0.06, K["aluminio"], "metal")
		m.solido = true
	# la puerta: un marco oscuro y un alero sobre ella
	m.caja(f, 164.0, -26.4, 166.4, -25.8, 2.75, 2.95, K["blanco"])
	m.caja(f, 164.2, -25.84, 166.2, -25.8, 0.3, 2.5, K["aluminio"], "metal")


# ---------------------------------------------------------------- el techo

func techo() -> void:
	var p := PackedVector2Array()
	for q in PLANTA:
		p.append(V2(q[0], q[1]))
	var pin := Malla.adentro(p, 0.25)
	m.piso(f, pin, TOP - PRETIL, K["techo"], "hormigon")
	for i in pin.size():
		var j := (i + 1) % pin.size()
		m.muro(f, pin[j], pin[i], TOP - PRETIL, TOP, K["muro"])
		m.cara([f.V(p[i].x, p[i].y, TOP), f.V(p[j].x, p[j].y, TOP), f.V(pin[j].x, pin[j].y, TOP), f.V(pin[i].x, pin[i].y, TOP)],
			K["blanco"], "liso", Vector3.UP)
	var h := TOP - PRETIL
	# la sala de máquinas roja, con su puerta
	m.caja(f, 158.0, -16.0, 163.5, -9.0, h, 42.6, K["rojo"], "liso", K["rojo2"])
	m.caja(f, 160.1, -16.04, 161.1, -16.0, h, h + 2.1, K["aluminio"], "metal")
	# el letrero en el borde oriente: tres patas y dos travesaños de metal, el marco y la cara al oriente
	for v in [-23.5, -15.5, -7.5]:
		m.caja(f, 166.6, v - 0.2, 167.0, v + 0.2, h, 40.0, K["metal"], "metal")
		m.caja(f, 164.6, v - 0.12, 166.6, v + 0.12, h, h + 0.25, K["metal"], "metal")
	m.caja(f, 166.6, -25.5, 167.0, -5.5, 39.8, 40.1, K["metal"], "metal")
	m.caja(f, 166.7, -25.5, 167.1, -5.5, 40.0, 45.0, K["marco"], "metal")
	m.panel(f, V2(167.1, -25.5), V2(167.1, -5.5), 0.3, 19.7, 40.3, 44.7, 0.01, K["letrero"])


# el nombre en la cara del letrero, al oriente (el del hito: Trifolia, oficina 63 de la torre)
func letrero_texto() -> void:
	var l := Label3D.new()
	l.text = "TRIFOLIA"
	l.font_size = 160
	l.pixel_size = 0.022
	l.modulate = Color("58585a")
	l.outline_size = 0
	l.double_sided = false
	var n := f.N(1, 0)
	l.position = f.V(167.13, -15.5, 42.5)
	l.basis = Basis.looking_at(-n, Vector3.UP)
	add_child(l)
