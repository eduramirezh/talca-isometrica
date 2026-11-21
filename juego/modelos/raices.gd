# El Edificio Raíces (3 Oriente 1645, entre 5 y 6 Norte), con el detalle que pide una cámara a 1,7 m: ventanas hundidas
# con su vidrio, su montante y su alféizar, balcones con losa y baranda de vidrio, el hall de doble altura tras listones
# de madera, el muro de la calle con su número, el remate con el sky lounge y la pérgola, el prado, los juegos y la reja.
# Reemplaza el hito de la página (capa «hitos» del glb dentro del sitio).
#
# Planta, marco y alturas: los del hito de la página (src/js/hitos/edificio-raices.js, su encabezado dice de dónde sale
# cada cosa): la huella de Microsoft d281d024… corrida como las demás de Microsoft contra OSM, una barra de 49,6 × 15 m a
# 1,8° de la grilla; u a lo largo de la barra hacia 3 Oriente (oriente) y v al norte. Diez pisos de 2,65 m y un undécimo
# en los extremos y retranqueado al medio; lo de arriba del suelo, de las fotos de los avisos de venta (miradas, no
# copiadas: docs/FUENTES.md).
#
# Mapillary (CC BY-SA 4.0; diagnostics/fotos/raices-pano/, fuera de git): a menos de 150 m solo hay fotos de febrero de
# 2018, cuando el sitio estaba vacío; la torre terminada se ve solo en las panorámicas de 2023 y 2024 desde la Alameda,
# a ~205 m, borrosa y entre árboles. Sirven para la cara sur, que no tenía fotos: de la x 264–271 (Cristian_Adonay_Baeza,
# 2024-09-28, 438188555394259, 873538511416209 y 2445007295696620) se ve entera, clara, con ventanas oscuras de a pares
# en cada piso (cada ~2,6 m de alto) también en el bloque poniente, donde el hito tenía balcones, y los dos extremos
# a ~31 m con una sala de máquinas más alta; de ahí VENTANAS_SUR_PONIENTE. La posición de los pares en ese bloque es
# aproximada (± 2 m: la posición y el rumbo de la cámara de Mapillary).
#
# Aproximado: lo mismo que en el hito (la cara poniente, los bordes del sitio, los juegos, la pérgola), y lo que la
# página no dibuja y aquí se inventa con sensatez: los montantes de las ventanas, las correderas de los balcones, la
# puerta del hall y sus apliques, la reja a 3 Oriente, el tobogán y el columpio.
#
# El sitio no está en las teselas que el juego carga al comenzar (las de la plaza): el modelo se arma cuando llega su
# tesela (_process), con el relieve de esa sola tesela (suelo.gd). Como en la página, la torre se apoya en la esquina
# más alta de su planta y sus muros bajan 4 m: al poniente el primer piso queda ~1,3 m sobre el suelo, con zócalo.
extends Node3D

const Malla := preload("res://malla.gd")
const Suelo := preload("res://modelos/entorno/suelo.gd")

const X := 275.0
const Y := 747.0
const A := (90.0 + 1.8) * PI / 180
const FH := 2.65  # el alto de un piso
const BAR := 27.3  # el remate de la barra (diez pisos)
const TOP := 30.0  # el remate de los extremos (once pisos)
const PRETIL := 0.8  # el alto del pretil sobre la azotea

# la barra sin los balcones que salen de ella (el hito: R), los dos extremos de once pisos (RE, RW)
const R := [[-25.55, -6.25], [-8.9, -6.25], [-8.9, -7.58], [24, -7.58], [24, -6.38], [22.2, -6.38], [22.2, 5.98],
	[24, 5.98], [24, 7.18], [6.54, 7.18], [6.54, 7.78], [-12.04, 7.78], [-12.04, 4.3], [-16.78, 4.3], [-16.78, 8.18],
	[-25.55, 8.18]]
const RE := [[16.2, -7.58], [24, -7.58], [24, -6.38], [22.2, -6.38], [22.2, 5.98], [24, 5.98], [24, 7.18], [16.2, 7.18]]
const RW := [[-25.55, -6.25], [-16.78, -6.25], [-16.78, 8.18], [-25.55, 8.18]]
# el sitio (el eriazo de 2015, hasta 3 Oriente y el pasaje del sur): lo que la página dibuja en él se quita
const SITIO := [[-29.0, -10.0], [26.6, -10.0], [26.6, 19.3], [-29.0, 19.3]]
# la línea de la vereda de 3 Oriente (x de grilla): el patio de la entrada llega hasta ahí, bajo la vereda
const X_VEREDA := 304.4
# Mapillary: los pares de ventanas de la cara sur del bloque poniente (u)
const VENTANAS_SUR_PONIENTE := [-23.0, -21.6, -19.4, -18.0]

const K := {
	"muro": Color("dcdbd6"), "blanco": Color("f0efea"), "derrame": Color("cfcec8"), "zocalo": Color("b9b8b2"),
	"vidrio": Color("3b4653"), "vidrio2": Color("2c3540"), "baranda": Color("a9bcbe"), "aluminio": Color("5b6066"),
	"madera": Color("8a5a3b"), "madera2": Color("74492f"), "techo": Color("b3b2ac"), "sala": Color("c4c3bd"),
	"oscuro": Color("474b4f"), "pasto": Color("6f9f48"), "baldosa": Color("c9c6be"), "losa": Color("bdb9af"),
	"goma": Color("5e8a6a"), "verde": Color("4fa53e"), "amarillo": Color("e0b83a"), "azul": Color("3e6fb0"),
	"rojo": Color("c2483a"), "fierro": Color("2e2f31"), "deck": Color("8c6a4f"), "lampara": Color(1.0, 0.89, 0.69, 1.0),
}

var m := Malla.new()
var mc := Malla.new()  # solo colisión (la reja)
var f: Malla.Marco
var S: Suelo
var rng := RandomNumberGenerator.new()


func recortes() -> Array:
	var g := Malla.Marco.new(X, Y, A)
	var p := PackedVector2Array()
	for q in SITIO:
		p.append(g.punto(q[0], q[1]))
	if Geometry2D.is_polygon_clockwise(p):
		p.reverse()
	return [{"poligono": p, "capas": ["hitos"]}]


# se arma cuando está la tesela del sitio (main.gd la carga en hilos; suelo.gd lee su relieve)
func _process(_d: float) -> void:
	var mapa = get_parent().get("mapa")
	if mapa == null:
		return
	var k := "%d_%d" % [floori(X / mapa.tam), floori(Y / mapa.tam)]
	var t: Node3D = mapa.cargadas.get(k)
	if t == null or not t.is_inside_tree():
		return
	set_process(false)
	construir(t)


func construir(tesela: Node3D) -> void:
	var t0 := Time.get_ticks_msec()
	S = Suelo.new(tesela)
	rng.seed = 1645
	var g := Malla.Marco.new(X, Y, A)
	var g0 := -INF
	for q in R:
		var p := g.punto(q[0], q[1])
		g0 = maxf(g0, S.E(p.x, p.y))
	f = Malla.Marco.new(X, Y, A, g0)
	suelos()
	caras()
	oriente()
	balcones_norte()
	remates()
	juegos()
	reja()
	numero()
	m.construir(self, "raices")
	mc.construir_colision(self, "raices-reja")
	S = null  # el relieve de toda la tesela y los arreglos de las mallas: ya están en la escena
	m = null
	mc = null
	print("raices.gd: %d ms (base %.2f)" % [Time.get_ticks_msec() - t0, g0])


# ---------------------------------------------------------------- ayudas

func V2(u: float, v: float) -> Vector2:
	return Vector2(u, v)


func st(k: int) -> float:
	return k * FH


# la altura del suelo en (u, v), sobre la base del marco
func E(u: float, v: float) -> float:
	var p := f.punto(u, v)
	return S.E(p.x, p.y) - f.base


# el vidrio de un departamento: dos tonos, y de noche encendido uno de cada tres (alfa 1: shaders/patron «ventana»)
func vidrio() -> Color:
	var c: Color = K["vidrio"] if rng.randf() < 0.5 else K["vidrio2"]
	c.a = 1.0 if rng.randf() < 0.35 else 0.5
	return c


# una capa plana sobre el relieve (u, v), off m sobre el suelo: cortada por los triángulos del terreno, apoyada en él
func capa(pol: Array, off: float, col: Color, mat := "liso") -> void:
	var gp := PackedVector2Array()
	for q in pol:
		gp.append(f.punto(q[0], q[1]))
	if Geometry2D.is_polygon_clockwise(gp):
		gp.reverse()
	var x0 := INF
	var y0 := INF
	var x1 := -INF
	var y1 := -INF
	for p in gp:
		x0 = minf(x0, p.x); y0 = minf(y0, p.y); x1 = maxf(x1, p.x); y1 = maxf(y1, p.y)
	var alt := func(u: float, v: float) -> float: return E(u, v) + off
	for t in S.triangulos(x0, y0, x1, y1):
		for pz in Geometry2D.intersect_polygons(gp, t):
			if Geometry2D.is_polygon_clockwise(pz):
				continue
			var pu := PackedVector2Array()
			for p in pz:
				pu.append(f.L(p.x, p.y))
			m.piso(f, pu, 0.0, col, mat, alt)


func rect(u0: float, v0: float, u1: float, v1: float) -> Array:
	return [[u0, v0], [u1, v0], [u1, v1], [u0, v1]]


# ventanas de los pisos k0..k1 centradas en cs (u o v), de ancho w y alto h, a 0,65 m del piso
func ventanas(a: Vector2, b: Vector2, cs: Array, w: float, k0: int, k1: int, h := 1.5) -> Array:
	var out := []
	for k in range(k0, k1 + 1):
		for c in cs:
			var s := Malla.s_de(a, b, c)
			out.append([s - w / 2, s + w / 2, st(k) + 0.65, st(k) + 0.65 + h, "v"])
	return out


# las correderas de un balcón: un vano de piso a dintel entre c0 y c1 (u o v) en los pisos k0..k1
func correderas(a: Vector2, b: Vector2, c0: float, c1: float, k0: int, k1: int, tipo := "p") -> Array:
	var out := []
	var s0 := Malla.s_de(a, b, c0)
	var s1 := Malla.s_de(a, b, c1)
	for k in range(k0, k1 + 1):
		out.append([minf(s0, s1), maxf(s0, s1), st(k) + 0.2, st(k) + 2.35, tipo])
	return out


# un muro a -> b (afuera a la derecha) de h0 a h1 con sus vanos [s0, s1, z0, z1, tipo] en (s, altura):
#   v  ventana hundida 0,18 m: vidrio, montante al medio y alféizar blanco
#   p  corredera hundida 0,15 m: vidrio con montantes cada ~1,4 m
#   l  logia de 1,2 m de fondo (derrames blancos) con la corredera al fondo
#   h  el vidrio del hall, encendido de noche
#   m  la ranura de madera de la esquina
func fachada(a: Vector2, b: Vector2, h0: float, h1: float, vanos: Array, col: Color) -> void:
	var huecos := Malla.huecos_de(vanos)
	m.muro_vanos(f, a, b, h0, h1, huecos, col)
	for i in vanos.size():
		var w: Array = vanos[i]
		var s0: float = w[0]
		var s1: float = w[1]
		var z0: float = w[2]
		var z1: float = w[3]
		var tipo: String = w[4]
		match tipo:
			"v":
				m.derrame(f, a, b, huecos[i], 0.18, K["derrame"], "liso", vidrio(), "ventana")
				m.solido = false
				m.moldura(f, a, b, (s0 + s1) / 2 - 0.025, (s0 + s1) / 2 + 0.025, z0, z1, -0.13, K["aluminio"], "metal", -0.18)
				m.moldura(f, a, b, s0, s1, z0 + 0.0, z0 + 0.05, -0.13, K["aluminio"], "metal", -0.18)
				m.moldura(f, a, b, s0 - 0.06, s1 + 0.06, z0 - 0.06, z0, 0.06, K["blanco"])
				m.solido = true
			"p", "l":
				var prof := 0.15 if tipo == "p" else 1.2
				m.derrame(f, a, b, huecos[i], prof, K["derrame"] if tipo == "p" else K["blanco"], "liso", vidrio(), "ventana")
				var n := maxi(1, roundi((s1 - s0) / 1.4))
				m.solido = false
				for j in range(1, n):
					var s := s0 + (s1 - s0) * j / n
					m.moldura(f, a, b, s - 0.03, s + 0.03, z0, z1, -prof + 0.05, K["aluminio"], "metal", -prof)
				m.solido = true
			"h":
				var c := Color(K["vidrio2"])
				c.a = 1.0
				m.derrame(f, a, b, huecos[i], 0.12, K["madera2"], "liso", c, "ventana")
			"m":
				m.derrame(f, a, b, huecos[i], 0.25, K["madera"], "liso", K["madera2"], "liso")


# las bandas blancas de las losas en los pisos k0..k1, de s0 a s1 del muro a -> b
func bandas(a: Vector2, b: Vector2, c0: float, c1: float, k0: int, k1: int) -> void:
	var s0 := Malla.s_de(a, b, c0)
	var s1 := Malla.s_de(a, b, c1)
	for k in range(k0, k1 + 1):
		m.moldura(f, a, b, minf(s0, s1), maxf(s0, s1), st(k) - 0.2, st(k) + 0.25, 0.04, K["blanco"])


# una baranda de vidrio sobre la línea a -> b, de s0 a s1, sobre el piso h: el paño y su pasamanos
func baranda(a: Vector2, b: Vector2, s0: float, s1: float, h: float) -> void:
	m.moldura(f, a, b, s0, s1, h, h + 1.0, -0.01, K["baranda"], "vidrio", -0.03)
	m.solido = false
	m.moldura(f, a, b, s0, s1, h + 1.0, h + 1.06, 0.0, K["aluminio"], "metal", -0.05)
	m.solido = true


# ---------------------------------------------------------------- el suelo del sitio

func suelos() -> void:
	# el patio de la entrada, de la fachada a la vereda de 3 Oriente (bajo ella, que está más alta)
	var se := f.L(X_VEREDA, f.punto(24, -9.6).y)
	var ne := f.L(X_VEREDA, f.punto(24, 18.9).y)
	capa([[22.2, -9.6], [se.x, -9.6], [ne.x, 18.9], [22.2, 18.9]], 0.145, K["baldosa"], "baldosa")
	# el pasillo del sur (junto al pasaje), el del poniente y el del norte, frente a las terrazas del primer piso
	capa(rect(-28.4, -9.6, 22.2, -6.25), 0.145, K["baldosa"], "baldosa")
	capa(rect(-28.4, -6.25, -25.55, 11.4), 0.145, K["baldosa"], "baldosa")
	capa(rect(-25.55, 7.18, 22.2, 11.4), 0.145, K["baldosa"], "baldosa")
	# el prado, y la goma de los juegos en la esquina poniente
	capa(rect(-28.4, 11.4, 22.2, 18.5), 0.13, K["pasto"])
	capa(rect(-27.6, 12.2, -19.4, 17.8), 0.16, K["goma"])


# ---------------------------------------------------------------- las caras

func caras() -> void:
	var muro: Color = K["muro"]
	var blanco: Color = K["blanco"]
	# sur: el bloque poniente (once pisos; los pares de Mapillary), la barra retranqueada, el quiebre y la barra
	var a := V2(-25.55, -6.25)
	var b := V2(-16.78, -6.25)
	fachada(a, b, -4, TOP, ventanas(a, b, VENTANAS_SUR_PONIENTE, 1.2, 0, 10), muro)
	bandas(a, b, -25.55, -16.78, 1, 10)
	a = V2(-16.78, -6.25); b = V2(-8.9, -6.25)
	fachada(a, b, -4, BAR, ventanas(a, b, [-14.6, -13.2, -11.4, -10.0], 1.2, 0, 9), muro)
	bandas(a, b, -16.78, -8.9, 1, 9)
	fachada(V2(-8.9, -6.25), V2(-8.9, -7.58), -4, BAR, [], muro)
	a = V2(-8.9, -7.58); b = V2(16.2, -7.58)
	fachada(a, b, -4, BAR, ventanas(a, b, [-5.0, -3.6, -0.2, 1.2, 4.0, 5.4, 8.8, 10.2, 13.0, 14.4], 1.2, 0, 9), muro)
	bandas(a, b, -8.9, 15.9, 1, 9)
	a = V2(16.2, -7.58); b = V2(24, -7.58)
	fachada(a, b, -4, TOP, ventanas(a, b, [18.6], 0.9, 0, 10, 1.2), muro)
	bandas(a, b, 16.5, 22.6, 1, 10)
	m.moldura(f, V2(-8.9, -7.58), V2(24, -7.58), 24.8, 25.4, -0.5, BAR, 0.12, blanco)  # la pilastra en u 15,9–16,5
	# las mochetas blancas de 3 Oriente (sus caras: oriente() pone lo que va entre ellas)
	fachada(V2(24, -7.58), V2(24, -6.38), -4, TOP, [], blanco)
	fachada(V2(24, -6.38), V2(22.2, -6.38), -4, TOP, [], blanco)
	fachada(V2(22.2, 5.98), V2(24, 5.98), -4, TOP, [], blanco)
	fachada(V2(24, 5.98), V2(24, 7.18), -4, TOP, [], blanco)
	# norte: el bloque oriente con la ranura de madera y la columna de ventanas chicas, la barra con sus pares
	a = V2(24, 7.18); b = V2(16.2, 7.18)
	var vn := ventanas(a, b, [18.6], 0.9, 0, 10, 1.2)
	vn.append([Malla.s_de(a, b, 23.5), Malla.s_de(a, b, 22.7), 0.2, TOP - 0.6, "m"])
	fachada(a, b, -4, TOP, vn, muro)
	bandas(a, b, 16.5, 22.6, 1, 10)
	a = V2(16.2, 7.18); b = V2(6.54, 7.18)
	fachada(a, b, -4, BAR, ventanas(a, b, [14.4, 13.0, 9.9, 8.5], 1.2, 0, 9), muro)
	bandas(a, b, 15.9, 6.54, 1, 9)
	m.moldura(f, V2(24, 7.18), V2(6.54, 7.18), 7.5, 8.1, -0.5, BAR, 0.12, blanco)
	fachada(V2(6.54, 7.18), V2(6.54, 7.78), -4, BAR, [], muro)
	# la barra tras los balcones del peine: las correderas, y al poniente los pares
	a = V2(6.54, 7.78); b = V2(-12.04, 7.78)
	var vp := correderas(a, b, 6.2, 1.75, 0, 9)
	vp.append_array(correderas(a, b, 1.35, -3.0, 0, 9))
	vp.append_array(ventanas(a, b, [-5.0, -6.4, -9.2, -10.6], 1.2, 0, 9))
	fachada(a, b, -4, BAR, vp, muro)
	bandas(a, b, -3.3, -12.04, 1, 9)
	# la escotadura: ventanas en sus costados y logias al fondo
	a = V2(-12.04, 7.78); b = V2(-12.04, 4.3)
	fachada(a, b, -4, BAR, ventanas(a, b, [6.04], 1.4, 0, 9), muro)
	a = V2(-12.04, 4.3); b = V2(-16.78, 4.3)
	fachada(a, b, -4, BAR, correderas(a, b, -12.3, -16.5, 0, 9), muro)
	for k in range(1, 10):
		m.caja(f, -16.78, 4.3, -12.04, 5.4, st(k) - 0.25, st(k) + 0.2, blanco, "liso", K["losa"], true)
		baranda(V2(-12.04, 5.4), V2(-16.78, 5.4), 0.0, 4.74, st(k) + 0.2)
	a = V2(-16.78, 4.3); b = V2(-16.78, 8.18)
	fachada(a, b, -4, TOP, ventanas(a, b, [6.24], 1.4, 0, 9), muro)
	# el bloque poniente al norte: logias de piso a piso con su baranda de vidrio al ras
	a = V2(-16.78, 8.18); b = V2(-25.55, 8.18)
	fachada(a, b, -4, TOP, correderas(a, b, -17.3, -25.0, 0, 10, "l"), muro)
	for k in range(0, 11):
		m.moldura(f, a, b, 0.0, 8.77, st(k) - 0.25, st(k) + 0.2, 0.05, blanco)
		baranda(a, b, Malla.s_de(a, b, -17.3), Malla.s_de(a, b, -25.0), st(k) + 0.2)
	# poniente: dos columnas de ventanas junto a las esquinas
	a = V2(-25.55, 8.18); b = V2(-25.55, -6.25)
	fachada(a, b, -4, TOP, ventanas(a, b, [6.6, -4.6], 1.2, 0, 10), muro)
	bandas(a, b, 8.18, -6.25, 1, 10)
	# el zócalo de hormigón (al poniente el primer piso queda sobre el suelo)
	var p := PackedVector2Array()
	for q in R:
		p.append(V2(q[0], q[1]))
	for i in p.size():
		var c := p[i]
		var d := p[(i + 1) % p.size()]
		if absf(c.x - 22.2) < 0.01 and absf(d.x - 22.2) < 0.01:
			continue  # el hall y la terraza de 3 Oriente
		m.moldura(f, c, d, 0.0, c.distance_to(d), -4, 0.05, 0.03, K["zocalo"], "hormigon")


# ---------------------------------------------------------------- 3 Oriente

# entre las mochetas: un balcón por piso con baranda de vidrio y un pilar delgado al medio; abajo, al sur el hall de
# doble altura tras listones de madera con su puerta, al norte la terraza del primer piso tras el muro de la calle
func oriente() -> void:
	var a := V2(22.2, -6.38)
	var b := V2(22.2, 5.98)
	var vs := [[0.15, 6.03, 0.0, st(2) - 0.25, "h"], [6.73, 12.21, 0.2, 2.4, "p"], [6.73, 12.21, st(1) + 0.2, st(1) + 2.35, "p"]]
	for k in range(2, 11):
		vs.append([0.15, 6.03, st(k) + 0.2, st(k) + 2.35, "p"])
		vs.append([6.73, 12.21, st(k) + 0.2, st(k) + 2.35, "p"])
	fachada(a, b, -4, TOP, vs, K["muro"])
	# las losas de los balcones (la del primer piso solo al norte: el hall sube dos pisos), las barandas y el remate
	for k in range(1, 12):
		var v0 := -0.25 if k == 1 else -6.38
		m.caja(f, 22.2, v0, 24, 5.98, st(k) - 0.25, st(k) + 0.2, K["blanco"], "liso", K["losa"], true)
		if k < 11:
			var ba := V2(24, v0)
			var bb := V2(24, 5.98)
			baranda(ba, bb, 0.0, ba.distance_to(bb), st(k) + 0.2)
	m.caja(f, 22.2, -6.38, 24, 5.98, st(11) + 0.2, TOP, K["blanco"])
	m.caja(f, 22.2, -0.25, 23.8, 0.25, -0.5, st(11) - 0.25, K["blanco"])
	# los listones del hall, con la puerta de vidrio al medio (v -3,9 … -2,5) y dos apliques
	m.solido = false
	var v := -6.25
	while v < -0.4:
		if v > -4.0 and v < -2.4:
			v += 0.22
			continue
		m.caja(f, 22.2, v, 22.34, v + 0.08, 0.1, st(2) - 0.25, K["madera"] if int((v + 7) / 0.22) % 2 else K["madera2"])
		v += 0.22
	m.solido = true
	m.caja(f, 22.2, -4.0, 22.32, -2.4, 2.4, 2.55, K["aluminio"], "metal")
	m.caja(f, 22.2, -4.0, 22.32, -3.9, 0.0, 2.4, K["aluminio"], "metal")
	m.caja(f, 22.2, -2.5, 22.32, -2.4, 0.0, 2.4, K["aluminio"], "metal")
	m.caja(f, 22.2, -3.23, 22.3, -3.17, 0.0, 2.4, K["aluminio"], "metal")
	for vl in [-4.45, -1.95]:
		m.caja(f, 22.3, vl - 0.1, 22.42, vl + 0.1, 2.45, 2.75, K["lampara"], "ventana")
	# el muro de la calle de la terraza del primer piso (con el número: numero())
	m.caja(f, 25.6, 0.0, 26.1, 9.0, minf(E(25.85, 0), E(25.85, 9)) - 0.3, 1.9, K["blanco"])
	m.caja(f, 25.55, 0.0, 26.15, 9.0, 1.9, 1.98, K["zocalo"], "hormigon")


func numero() -> void:
	var l := Label3D.new()
	l.text = "1645"
	l.font_size = 96
	l.pixel_size = 0.003
	l.modulate = Color("2e2f31")
	l.outline_size = 0
	l.double_sided = false
	var n := f.N(1, 0)
	l.position = f.V(26.11, 6.6, 1.35)
	l.basis = Basis.looking_at(-n, Vector3.UP)
	add_child(l)


# ---------------------------------------------------------------- el peine del norte

# dos pilas de balcones que salen 1,7 m de la barra (la huella de Microsoft tiene ahí dos dientes), con baranda de
# vidrio en sus tres lados; el del primer piso es la terraza sobre el prado
func balcones_norte() -> void:
	for k in range(0, 10):
		var h0 := -0.6 if k == 0 else st(k) - 0.25
		for par in [[-3.3, 1.45], [1.65, 6.54]]:
			var u0: float = par[0]
			var u1: float = par[1]
			m.caja(f, u0, 7.78, u1, 9.48, h0, st(k) + 0.2, K["blanco"], "liso", K["losa"], k > 0)
			baranda(V2(u1, 9.48), V2(u0, 9.48), 0.05, u1 - u0 - 0.05, st(k) + 0.2)
			if u1 > 6:  # los lados de afuera; entre las dos pilas, el muro que las separa
				baranda(V2(u1, 7.78), V2(u1, 9.48), 0.0, 1.65, st(k) + 0.2)
			else:
				baranda(V2(u0, 9.48), V2(u0, 7.78), 0.05, 1.7, st(k) + 0.2)
	m.caja(f, 1.45, 7.78, 1.65, 9.48, -0.6, BAR - 0.45, K["blanco"])
	m.caja(f, -3.3, 7.78, 6.54, 9.48, BAR - 0.45, BAR, K["blanco"])


# ---------------------------------------------------------------- los remates

# la azotea de un polígono a la altura h: el piso PRETIL m más abajo, el pretil por dentro y su coronación blanca
func azotea(pol: Array, h: float) -> void:
	var p := PackedVector2Array()
	for q in pol:
		p.append(V2(q[0], q[1]))
	if Geometry2D.is_polygon_clockwise(p):
		p.reverse()
	var pin := Malla.adentro(p, 0.25)
	m.piso(f, pin, h - PRETIL, K["techo"], "hormigon")
	for i in pin.size():
		var j := (i + 1) % pin.size()
		m.muro(f, pin[j], pin[i], h - PRETIL, h, K["muro"])
		m.cara([f.V(p[i].x, p[i].y, h), f.V(p[j].x, p[j].y, h), f.V(pin[j].x, pin[j].y, h), f.V(pin[i].x, pin[i].y, h)],
			K["blanco"], "liso", Vector3.UP)


func remates() -> void:
	azotea(R, BAR)
	azotea(RE, TOP)
	azotea(RW, TOP)
	var h := BAR - PRETIL  # el piso de la azotea de la barra: el del undécimo
	# las caras interiores de los extremos, sobre la azotea, con la puerta de la escalera
	var a := V2(16.2, 7.18)
	var b := V2(16.2, -7.58)
	fachada(a, b, h, TOP, [[Malla.s_de(a, b, 0.6), Malla.s_de(a, b, -0.6), h + 0.05, h + 2.2, "p"]], K["muro"])
	a = V2(-16.78, -6.25); b = V2(-16.78, 4.3)
	fachada(a, b, h, TOP, [[Malla.s_de(a, b, -1.2), Malla.s_de(a, b, 0.0), h + 0.05, h + 2.2, "p"]], K["muro"])
	# el sky lounge: el undécimo piso retranqueado, vidriado de piso a cielo
	var sl := [[-6.0, -4.6], [16.0, -4.6], [16.0, 4.6], [-6.0, 4.6]]
	for i in 4:
		var c := V2(sl[i][0], sl[i][1])
		var d := V2(sl[(i + 1) % 4][0], sl[(i + 1) % 4][1])
		var L := c.distance_to(d)
		var vs := [[0.4, L - 0.4, h + 0.15, 29.1, "p"]]
		fachada(c, d, h, TOP, vs, K["sala"])
	azotea(sl, TOP)
	# la terraza de la pérgola (deck) entre el bloque poniente y el lounge (sin pasar a la escotadura), con la pérgola
	m.piso(f, m.rect(-16.5, -5.8, -6.0, 4.0), h + 0.06, K["deck"])
	for q in [[-14.5, -4.0], [-14.5, 3.6], [-6.45, -4.0], [-6.45, 3.6]]:
		m.caja(f, q[0], q[1], q[0] + 0.45, q[1] + 0.45, h, 29.6, K["oscuro"], "metal")
	m.caja(f, -14.5, -4.0, -6.0, -3.55, 29.2, 29.6, K["oscuro"], "metal")
	m.caja(f, -14.5, 3.6, -6.0, 4.05, 29.2, 29.6, K["oscuro"], "metal")
	m.solido = false
	var u := -13.3
	while u < -6.4:
		m.caja(f, u, -3.55, u + 0.3, 3.6, 29.3, 29.55, K["oscuro"], "metal")
		u += 0.9
	m.solido = true
	# las salas de máquinas de los ascensores
	m.caja(f, 2.0, -2.2, 6.2, 2.2, TOP - PRETIL, 32.4, K["sala"], "liso", K["techo"])
	m.caja(f, 18.0, -3.4, 20.8, 0.6, TOP - PRETIL, 34.0, K["sala"], "liso", K["techo"])
	m.caja(f, -23.6, -3.0, -19.6, 2.0, TOP - PRETIL, 31.6, K["sala"], "liso", K["techo"])


# ---------------------------------------------------------------- el jardín

# los juegos de la esquina poniente, sobre la goma: una torre con techo y tobogán, un columpio y un balancín
func juegos() -> void:
	var z := func(u: float, v: float) -> float: return E(u, v) + 0.16
	# la torre: cuatro pilares, la plataforma, las barandas y el techo a dos aguas rojo
	var tu := -26.2
	var tv := 16.2
	var z0: float = z.call(tu, tv)
	for q in [[-0.7, -0.7], [0.62, -0.7], [-0.7, 0.62], [0.62, 0.62]]:
		m.caja(f, tu + q[0], tv + q[1], tu + q[0] + 0.08, tv + q[1] + 0.08, z0 - 0.2, z0 + 2.4, K["amarillo"])
	m.caja(f, tu - 0.7, tv - 0.7, tu + 0.7, tv + 0.7, z0 + 1.1, z0 + 1.2, K["madera"])
	m.caja(f, tu - 0.7, tv + 0.62, tu + 0.7, tv + 0.7, z0 + 1.2, z0 + 1.8, K["azul"])
	m.caja(f, tu - 0.7, tv - 0.7, tu - 0.62, tv + 0.62, z0 + 1.2, z0 + 1.8, K["azul"])
	m.caja(f, tu - 0.7, tv - 0.7, tu + 0.7, tv - 0.62, z0 + 1.2, z0 + 1.8, K["verde"])
	var t0 := f.V(tu - 0.8, tv - 0.8, z0 + 2.4)
	var t1 := f.V(tu + 0.8, tv - 0.8, z0 + 2.4)
	var t2 := f.V(tu + 0.8, tv + 0.8, z0 + 2.4)
	var t3 := f.V(tu - 0.8, tv + 0.8, z0 + 2.4)
	var c0 := f.V(tu - 0.8, tv, z0 + 3.0)
	var c1 := f.V(tu + 0.8, tv, z0 + 3.0)
	m.cara([t0, t1, c1, c0], K["rojo"])
	m.cara([t2, t3, c0, c1], K["rojo"])
	m.cara([t1, t2, c1], K["rojo"])
	m.cara([t3, t0, c0], K["rojo"])
	m.cara([t0, t3, t2, t1], K["rojo"])  # por debajo
	# el tobogán, de la plataforma hacia el oriente
	var e0: float = z.call(tu + 3.6, tv)
	var s0 := f.V(tu + 0.7, tv - 0.3, z0 + 1.2)
	var s1 := f.V(tu + 3.6, tv - 0.3, e0 + 0.25)
	var s2 := f.V(tu + 3.6, tv + 0.3, e0 + 0.25)
	var s3 := f.V(tu + 0.7, tv + 0.3, z0 + 1.2)
	m.cara([s0, s1, s2, s3], K["azul"])
	m.cara([s3, s2, s1, s0], K["azul"])
	for sv in [-0.36, 0.3]:
		m.cara([f.V(tu + 0.7, tv + sv, z0 + 1.2), f.V(tu + 3.6, tv + sv, e0 + 0.25), f.V(tu + 3.6, tv + sv, e0 + 0.45),
			f.V(tu + 0.7, tv + sv, z0 + 1.4)], K["azul"], "liso", f.N(0, -1 if sv < 0 else 1))
		m.cara([f.V(tu + 0.7, tv + sv + 0.06, z0 + 1.2), f.V(tu + 3.6, tv + sv + 0.06, e0 + 0.25), f.V(tu + 3.6, tv + sv + 0.06, e0 + 0.45),
			f.V(tu + 0.7, tv + sv + 0.06, z0 + 1.4)], K["azul"], "liso", f.N(0, 1 if sv < 0 else -1))
	m.caja(f, tu + 3.3, tv - 0.3, tu + 3.4, tv + 0.3, e0 - 0.2, e0 + 0.25, K["amarillo"])
	# el columpio: dos marcos en A con su travesaño y dos asientos colgando
	m.solido = false
	var cu := -24.4
	var cv := 13.4
	var zc: float = z.call(cu, cv)
	for du in [-1.6, 1.6]:
		for dv in [-0.6, 0.6]:
			var pie := f.V(cu + du, cv + dv, zc - 0.1)
			var top := f.V(cu + du, cv, zc + 2.2)
			var lado := f.N(1, 0) * 0.05
			m.cara([pie - lado, pie + lado, top + lado, top - lado], K["rojo"], "liso", f.N(0, signf(dv)))
			m.cara([pie + lado, pie - lado, top - lado, top + lado], K["rojo"], "liso", f.N(0, -signf(dv)))
	m.caja(f, cu - 1.65, cv - 0.05, cu + 1.65, cv + 0.05, zc + 2.15, zc + 2.25, K["rojo"], "metal")
	for su in [-0.7, 0.7]:
		m.caja(f, cu + su - 0.22, cv - 0.01, cu + su - 0.2, cv + 0.01, zc + 0.45, zc + 2.15, K["fierro"], "metal")
		m.caja(f, cu + su + 0.2, cv - 0.01, cu + su + 0.22, cv + 0.01, zc + 0.45, zc + 2.15, K["fierro"], "metal")
		m.caja(f, cu + su - 0.25, cv - 0.12, cu + su + 0.25, cv + 0.12, zc + 0.4, zc + 0.46, K["fierro"], "metal")
	# el balancín
	var bu := -21.0
	var bv := 13.8
	var zb: float = z.call(bu, bv)
	m.caja(f, bu - 0.1, bv - 0.15, bu + 0.1, bv + 0.15, zb - 0.1, zb + 0.4, K["amarillo"])
	m.caja(f, bu - 1.5, bv - 0.1, bu + 1.5, bv + 0.1, zb + 0.4, zb + 0.48, K["verde"])
	for sg in [-1.0, 1.0]:
		m.caja(f, bu + sg * 1.3 - 0.02, bv - 0.2, bu + sg * 1.3 + 0.02, bv + 0.2, zb + 0.48, zb + 0.75, K["fierro"], "metal")
	m.solido = true


# la reja negra del sitio: al norte y al poniente (el hito) y a 3 Oriente al norte del muro de la calle
func reja() -> void:
	cerco(V2(-28.6, 18.7), V2(26.0, 18.7))
	cerco(V2(-28.6, -9.6), V2(-28.6, 18.7))
	cerco(V2(26.0, 9.0), V2(26.0, 18.7))


# una reja de barrotes de 1,6 m sobre el suelo de a a b, con pilares cada ~2,4 m; la colisión, un muro delgado aparte
func cerco(a: Vector2, b: Vector2) -> void:
	var L := a.distance_to(b)
	var d := (b - a) / L
	var n := maxi(1, ceili(L / 2.4))
	var zmin := INF
	var zmax := -INF
	m.solido = false
	for i in n:
		var s0 := L * i / n
		var s1 := L * (i + 1) / n
		var pm := a + d * (s0 + s1) / 2
		var z := E(pm.x, pm.y) + 0.13
		zmin = minf(zmin, z); zmax = maxf(zmax, z)
		m.moldura(f, a, b, s0, s1, z + 0.08, z + 0.13, 0.02, K["fierro"], "metal", -0.02)
		m.moldura(f, a, b, s0, s1, z + 1.48, z + 1.54, 0.02, K["fierro"], "metal", -0.02)
		var s := s0 + 0.1
		while s < s1 - 0.06:
			m.moldura(f, a, b, s - 0.012, s + 0.012, z, z + 1.62, 0.012, K["fierro"], "metal", -0.012)
			s += 0.13
	for i in n + 1:
		var s := L * i / n
		var p := a + d * s
		var z := E(p.x, p.y) + 0.13
		m.moldura(f, a, b, s - 0.045, s + 0.045, z - 0.3, z + 1.7, 0.045, K["fierro"], "metal", -0.045)
	m.solido = true
	mc.moldura(f, a, b, 0.0, L, zmin - 0.5, zmax + 1.6, 0.03, K["fierro"], "metal", -0.03)
