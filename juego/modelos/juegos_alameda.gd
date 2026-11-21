# Los juegos de la Alameda entre 3 y 4 Oriente, y todo su tramo de la Alameda, con el detalle que pide una cámara a
# 1,7 m y para jugar: a la plataforma de la estructura grande y a la del oriente se sube por escaleras, y por sus
# toboganes abiertos (y por los de la estructura chica) se baja resbalando (sus canaletas son un cuerpo con la meta
# «tobogan»: jugador.gd resbalar()). Reemplaza el hito de la página (la capa «hitos» del glb en el tramo); los árboles
# son los de la página (arboleda.gd), que son los de OSM.
#
# Planta y lugares: los del hito de la página (src/js/hitos/juegos-alameda.js; su encabezado dice de dónde sale cada
# cosa): la reja de OSM w1421055220 (82 × 29,5 m) sobre la grilla, y lo de adentro ubicado por rumbos desde las
# panorámicas de Mapillary de las dos calzadas (pipeline/mapillary.py postes y cruce), cada estructura en su marco,
# corrido como en la página (GRANDE, CHICA, ORIENTE). Aquí con medidas de verdad, no las del pixel art: el murete de
# 0,25 m (la página, 0,6), postes de 12 cm, barandas de barrotes, cadenas en los columpios.
#
# Aproximado: lo mismo que en la página (los lugares, ±2 m a lo largo del bandejón y ±4 m a lo ancho; las medidas; el
# cobertizo; cuántos columpios; el texto del letrero, que va en blanco), y lo que la página no dibuja y aquí se
# inventa con sensatez: las escaleras (las fotos no muestran por dónde se sube), las solerillas de los senderos, la
# puerta y la ventana del cobertizo, los listones de las bancas, los asientos de los columpios, que se mecen un poco.
#
# El tramo cae en dos teselas (la línea y = 500 cruza los juegos): se arma cuando están todas las que toca, con el
# relieve de ellas (suelo.gd sumar()). Las lámparas de los faroles se suman a las de los hitos de faroles.gd
# (agregar_fijas()): luz de verdad cuando están entre las más cercanas.
extends Node3D

const Malla := preload("res://malla.gd")
const Suelo := preload("res://modelos/entorno/suelo.gd")

const X := 372.0
const Y := 510.9
const A := PI / 2  # el marco es la grilla: u al oriente, v al norte
# el tramo entre las calzadas de 3 y 4 Oriente (grilla): lo que el hito de la página dibuja en él se quita
const TRAMO := [[313.0, 489.0], [432.0, 489.0], [432.0, 533.0], [313.0, 533.0]]
const U0 := -41.0  # la reja: la cara de adentro del murete
const U1 := 41.0
const V0 := -14.6
const V1 := 14.6
const MURO := 0.25
const PISO := 0.13  # el maicillo y la arena sobre el suelo (el pasto de la manzana va a 0,10)
const PUERTA := 1.6  # la mitad del vano de cada portón
# los marcos de las estructuras, corridos como en la página
const GRANDE := Vector2(0.8, 3.2)
const CHICA := Vector2(0.0, -1.1)
const ORIENTE := Vector2(-2.6, 0.6)

const K := {
	"amarillo": Color("e2c033"), "amarillo2": Color("eed660"), "arena": Color("d2bf92"), "maicillo": Color("d8c69c"),
	"solera": Color("b9b6ad"), "concreto": Color("c3c1ba"), "madera": Color("b98e5c"), "madera2": Color("9c7448"),
	"panel": Color("d9c39a"), "capota": Color("e2d3b2"), "capota2": Color("efe5cf"), "naranjo": Color("e8832e"),
	"naranjo2": Color("d06a22"), "turquesa": Color("36b0a4"), "rosado": Color("de6f90"), "crema": Color("f0e7d6"),
	"crema2": Color("d6ccb8"), "metal": Color("c4c8ca"), "metal2": Color("aeb3b6"), "lila": Color("9a86c8"),
	"rojo": Color("d23a30"), "rojo2": Color("b32c25"), "rosado2": Color("e2809e"), "poste": Color("edc02c"),
	"baranda": Color("36b5a6"), "cubierta": Color("8e9a9c"), "blanco": Color("eeebe4"), "blanco2": Color("cfcac0"),
	"azul": Color("5f66de"), "azul2": Color("4b52c4"), "celeste": Color("3d72d6"), "celeste2": Color("7fa6e8"),
	"columpio": Color("c8402f"), "goma": Color("2a2a2c"), "cadena": Color("8a8d90"), "bloque": Color("a8a39a"),
	"techo": Color("9a9893"), "techo2": Color("8a8883"), "cortina": Color("8b3a30"), "reja": Color("4e5252"),
	"liston": Color("4d4843"), "liston2": Color("5f5a53"), "tabla": Color("9c3b31"), "tabla2": Color("8a332b"),
	"caseta": Color("c9673b"), "caseta2": Color("5b4b43"), "verde": Color("4f8a5b"), "grafiti": Color("e05a9a"),
	"grafiti2": Color("f2f0ea"), "gris": Color("9c9a94"), "gris2": Color("bdbab2"), "banca": Color("5e4a3a"),
	"fierro": Color("2e2f31"), "letrero": Color("8a4a2c"), "texto": Color("e8e2d4"), "basurero": Color("2f6e45"),
	"puerta": Color("4a4642"), "vidrio": Color("3b4653"), "lampara": Color(1.0, 0.89, 0.69, 1.0),
	"asideros": [Color("e0b83a"), Color("c2483a"), Color("3e6fb0"), Color("f0efea")],
}

var m := Malla.new()
var mc := Malla.new()  # solo colisión: las barandas de barrotes, los bordes de los toboganes
var mt := Malla.new()  # solo colisión, con la meta «tobogan»: las canaletas
var f: Malla.Marco
var S: Suelo
var lamparas: Array[Vector3] = []
var asientos := []  # [Node3D del eje, fase]: los columpios, que se mecen
var t := 0.0
var listo := false


func recortes() -> Array:
	var p := PackedVector2Array()
	for q in TRAMO:
		p.append(Vector2(q[0], q[1]))
	return [{"poligono": p, "capas": ["hitos"]}]


# se arma cuando están las teselas del tramo (main.gd las carga en hilos; suelo.gd lee su relieve); después mece los
# columpios
func _process(dt: float) -> void:
	if listo:
		mecer(dt)
		return
	var mapa = get_parent().get("mapa")
	if mapa == null:
		return
	var ts := []
	for q in TRAMO:
		var k := "%d_%d" % [floori(q[0] / mapa.tam), floori(q[1] / mapa.tam)]
		var tt: Node3D = mapa.cargadas.get(k)
		if tt == null or not tt.is_inside_tree():
			return
		if not tt in ts:
			ts.append(tt)
	listo = true
	construir(ts)


func construir(ts: Array) -> void:
	var t0 := Time.get_ticks_msec()
	S = Suelo.new(ts[0])
	for i in range(1, ts.size()):
		S.sumar(ts[i])
	f = Malla.Marco.new(X, Y, A)
	suelos()
	reja()
	grande()
	chica()
	columpios()
	oriente()
	cobertizo()
	afuera()
	senderos()
	m.construir(self, "juegos-alameda")
	mc.construir_colision(self, "juegos-alameda-barandas")
	var cuerpo := mt.construir_colision(self, "juegos-alameda-toboganes")
	if cuerpo:
		cuerpo.set_meta("tobogan", true)
	var fz := get_parent().get_node_or_null("mapa/faroles")
	if fz and fz.has_method("agregar_fijas"):
		fz.agregar_fijas(lamparas)
	S = null  # el relieve y los arreglos de las mallas: ya están en la escena
	m = null
	mc = null
	mt = null
	print("juegos_alameda.gd: %d ms, %d teselas, %d faroles" % [Time.get_ticks_msec() - t0, ts.size(), lamparas.size()])


# ---------------------------------------------------------------- ayudas

# la altura del suelo en (u, v) del marco del tramo
func E(u: float, v: float) -> float:
	var p := f.punto(u, v)
	return S.E(p.x, p.y)


# el marco de una estructura corrida o: su base es el suelo más bajo de su caja (u0, v0, u1, v1, en el marco de la
# estructura) más el maicillo
func marco(o: Vector2, caja: Array) -> Malla.Marco:
	var b := INF
	for q in [[caja[0], caja[1]], [caja[2], caja[1]], [caja[2], caja[3]], [caja[0], caja[3]], [(caja[0] + caja[2]) / 2, (caja[1] + caja[3]) / 2]]:
		b = minf(b, E(q[0] + o.x, q[1] + o.y))
	return Malla.Marco.new(X + o.x, Y + o.y, A, b + PISO)


func rect(u0: float, v0: float, u1: float, v1: float) -> Array:
	return [[u0, v0], [u1, v0], [u1, v1], [u0, v1]]


# una capa plana sobre el relieve, off m sobre el suelo: cortada por los triángulos del terreno, apoyada en él
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
	for tri in S.triangulos(x0, y0, x1, y1):
		for pz in Geometry2D.intersect_polygons(gp, tri):
			if Geometry2D.is_polygon_clockwise(pz):
				continue
			var pu := PackedVector2Array()
			for p in pz:
				pu.append(f.L(p.x, p.y))
			m.piso(f, pu, 0.0, col, mat, alt)


# una caja sobre el suelo del tramo, de h m sobre el maicillo, con su pie 0,3 m bajo el punto más bajo
func al_suelo(u0: float, v0: float, u1: float, v1: float, h: float, col: Color, mat := "liso", ctapa: Variant = null) -> void:
	var lo := minf(minf(E(u0, v0), E(u1, v0)), minf(E(u1, v1), E(u0, v1)))
	var c := E((u0 + u1) / 2, (v0 + v1) / 2)
	m.caja(f, u0, v0, u1, v1, lo - 0.3, c + PISO + h, col, mat, ctapa)


# una barra de a a b ([u, v, h] del marco g), de sección cuadrada w, como caja girada: los barrotes, los parantes en A
func barra(g: Malla.Marco, a: Vector3, b: Vector3, w: float, col: Color, mat := "liso", malla: Malla = null) -> void:
	var mm := m if malla == null else malla
	var d := Vector3(b.x - a.x, b.y - a.y, b.z - a.z)
	var L := d.length()
	if L < 1e-4:
		return
	d /= L
	var r := Vector3(-d.y, d.x, 0.0)  # de lado, horizontal
	if r.length() < 1e-3:
		r = Vector3(1, 0, 0)
	r = r.normalized()
	var s := d.cross(r).normalized()  # el tercer eje
	var h := w / 2
	var P := func(p: Vector3, i: float, j: float) -> Vector3:
		var q := p + r * (i * h) + s * (j * h)
		return g.V(q.x, q.y, q.z)
	var esq := [[-1.0, -1.0], [1.0, -1.0], [1.0, 1.0], [-1.0, 1.0]]
	for k in 4:
		var e0: Array = esq[k]
		var e1: Array = esq[(k + 1) % 4]
		var nm: Vector3 = r * (e0[0] + e1[0]) + s * (e0[1] + e1[1])
		mm.cara([P.call(a, e0[0], e0[1]), P.call(a, e1[0], e1[1]), P.call(b, e1[0], e1[1]), P.call(b, e0[0], e0[1])], col, mat,
			g.N(nm.x, nm.y, nm.z))


# un tobogán abierto de p a q ([u, v, h] del marco g), w de ancho: la canaleta, más empinada arriba y plana el último
# medio metro, en k tramos de dos tonos, con sus bordes de 0,3 m. La canaleta va a mt (resbala) y los bordes a mc
func tobogan(g: Malla.Marco, p: Vector3, q: Vector3, w: float, c1: Color, c2: Color, k := 8) -> void:
	var d := Vector2(q.x - p.x, q.y - p.y)
	var L := d.length()
	d /= L
	var nn := Vector2(-d.y, d.x) * (w / 2)
	var pts := []
	for i in k + 1:
		var s := float(i) / k
		var c := Vector2(p.x, p.y) + d * (L * s)
		var tt := clampf(L * s / maxf(L - 0.5, 0.1), 0.0, 1.0)
		pts.append(Vector3(c.x, c.y, q.z + (p.z - q.z) * pow(1.0 - tt, 1.4)))
	m.solido = false
	for i in k:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var col := c1 if i % 2 == 0 else c2
		var q4 := [g.V(a.x - nn.x, a.y - nn.y, a.z), g.V(b.x - nn.x, b.y - nn.y, b.z), g.V(b.x + nn.x, b.y + nn.y, b.z),
			g.V(a.x + nn.x, a.y + nn.y, a.z)]
		var up: Vector3 = (q4[1] - q4[0]).cross(q4[3] - q4[0]).normalized()
		if up.y < 0:
			up = -up
		m.cara(q4, col, "metal" if c1 == K["metal"] else "pintura", up)
		m.cara(q4, c2.darkened(0.3), "liso", -up)
		mt.cara(q4, col, "liso", up)
		for sg in [-1.0, 1.0]:
			var o: Vector2 = nn * sg
			var lado := [g.V(a.x + o.x, a.y + o.y, a.z - 0.05), g.V(b.x + o.x, b.y + o.y, b.z - 0.05), g.V(b.x + o.x, b.y + o.y, b.z + 0.3),
				g.V(a.x + o.x, a.y + o.y, a.z + 0.3)]
			m.cara(lado, c1, "pintura", g.N(o.x, o.y))
			m.cara(lado, c2, "pintura", g.N(-o.x, -o.y))
			mc.cara(lado, c1, "liso", g.N(o.x, o.y))
	m.solido = true


# un tobogán de tubo que baja girando alrededor de (cu, cv) del marco g, a R del eje, con un tubo de radio r, de h0 a
# h1 en `vueltas` vueltas desde el ángulo a0 (antihorario); dos tonos por tramo. Por fuera, sólido
func tubo(g: Malla.Marco, cu: float, cv: float, R: float, r: float, h0: float, h1: float, vueltas: float, a0: float, c1: Color, c2: Color) -> void:
	var n := maxi(4, ceili(vueltas * 16))
	var lados := 10
	var prev := []
	var cprev := Vector3.ZERO
	for i in n + 1:
		var s := float(i) / n
		var a := a0 + TAU * vueltas * s
		var c := Vector3(cu + R * cos(a), cv + R * sin(a), lerpf(h0, h1, s))
		var tg := Vector3(-sin(a) * R * TAU * vueltas, cos(a) * R * TAU * vueltas, h1 - h0).normalized()
		var rad := Vector3(cos(a), sin(a), 0.0)
		var bi := tg.cross(rad).normalized()
		var anillo := []
		for j in lados:
			var phi := TAU * j / lados
			anillo.append(c + (rad * cos(phi) + bi * sin(phi)) * r)
		if i > 0:
			var col := c1 if i % 2 == 0 else c2
			for j in lados:
				var p0: Vector3 = prev[j]
				var p1: Vector3 = prev[(j + 1) % lados]
				var p2: Vector3 = anillo[(j + 1) % lados]
				var p3: Vector3 = anillo[j]
				var nm := (p0 + p1 + p2 + p3) / 4 - (cprev + c) / 2
				m.cara([g.V(p0.x, p0.y, p0.z), g.V(p1.x, p1.y, p1.z), g.V(p2.x, p2.y, p2.z), g.V(p3.x, p3.y, p3.z)], col, "pintura",
					g.N(nm.x, nm.y, nm.z))
		prev = anillo
		cprev = c


# una escalera de n peldaños de a (arriba, [u, v, h]) a b (abajo, [u, v, 0]) del marco g, w de ancho, con pasamanos
func escalera(g: Malla.Marco, a: Vector3, b: Vector3, w: float, n: int, col: Color, pasa: Color) -> void:
	var d := Vector2(b.x - a.x, b.y - a.y)
	var L := d.length()
	d /= L
	var nn := Vector2(-d.y, d.x) * (w / 2)
	for i in n:
		var s0 := L * i / n
		var s1 := L * (i + 1) / n
		var h := a.z * (n - 1 - i) / n  # el peldaño i, de arriba abajo
		var c0 := Vector2(a.x, a.y) + d * s0
		var c1 := Vector2(a.x, a.y) + d * s1
		var poli := PackedVector2Array([c0 - nn, c1 - nn, c1 + nn, c0 + nn])
		m.prisma(g, poli, -0.4, h + 0.06, col, "liso", true, col.lightened(0.12))
	m.solido = false
	for sg in [-1.0, 1.0]:
		var o: Vector2 = nn * sg * 1.05
		barra(g, Vector3(a.x + o.x, a.y + o.y, a.z + 0.9), Vector3(b.x + o.x, b.y + o.y, 0.9), 0.05, pasa, "metal")
		barra(g, Vector3(b.x + o.x, b.y + o.y, -0.3), Vector3(b.x + o.x, b.y + o.y, 0.9), 0.06, pasa, "metal")
	m.solido = true


# una baranda de barrotes de a a b ([u, v] del marco g) sobre el piso h: pasamanos, barrotes cada 12 cm y, en mc, un
# muro de 0,9 m que no deja caer
func baranda(g: Malla.Marco, a: Vector2, b: Vector2, h: float, col: Color) -> void:
	var L := a.distance_to(b)
	var d := (b - a) / L
	m.solido = false
	barra(g, Vector3(a.x, a.y, h + 0.9), Vector3(b.x, b.y, h + 0.9), 0.06, col, "pintura")
	barra(g, Vector3(a.x, a.y, h + 0.12), Vector3(b.x, b.y, h + 0.12), 0.04, col, "pintura")
	var s := 0.1
	while s < L - 0.05:
		var p := a + d * s
		barra(g, Vector3(p.x, p.y, h + 0.1), Vector3(p.x, p.y, h + 0.88), 0.025, col, "pintura")
		s += 0.12
	m.solido = true
	var nm := Vector2(d.y, -d.x)
	mc.cara([g.V(a.x, a.y, h), g.V(b.x, b.y, h), g.V(b.x, b.y, h + 0.95), g.V(a.x, a.y, h + 0.95)], col, "liso", g.N(nm.x, nm.y))


# una torre: cuatro postes de 12 cm hasta top y la plataforma a pl (tablones de dos tonos)
func torre(g: Malla.Marco, u0: float, v0: float, u1: float, v1: float, pl: float, top: float, poste: Color, piso: Color) -> void:
	for q in [[u0, v0], [u1 - 0.12, v0], [u0, v1 - 0.12], [u1 - 0.12, v1 - 0.12]]:
		m.caja(g, q[0], q[1], q[0] + 0.12, q[1] + 0.12, -0.5, top, poste)
	var k := 0
	var u := u0
	while u < u1 - 0.01:
		var e := minf(u + 0.3, u1)
		m.caja(g, u, v0, e, v1, pl - 0.06, pl, piso.darkened(0.1 * (k % 2)), "liso", null, true)
		u = e
		k += 1


# ---------------------------------------------------------------- el suelo

func suelos() -> void:
	var w := MURO
	# los senderos de maicillo alrededor de la reja, la explanada hasta 3 Oriente, el concreto hasta 4 Oriente y la
	# arena de los juegos (bajo el murete): ninguno se monta sobre otro
	for s in [rect(-44.6, -18.4, 44.6, V0 - w), rect(-44.6, V1 + w, 44.6, 18.4), rect(U1 + w, V0 - w, 44.6, V1 + w),
			rect(-44.6, V0 - w, U0 - w, V1 + w)]:
		capa(s, PISO, K["maicillo"])
	capa([[-55.5, -20], [-44.6, -20], [-44.6, 20], [-55.5, 20], [-56.5, 17], [-56.5, -17]], PISO, K["maicillo"])
	capa(rect(44.6, -2.0, 58.6, 2.0), PISO + 0.02, K["concreto"], "hormigon")
	capa(rect(U0 - w, V0 - w, U1 + w, V1 + w), PISO, K["arena"])
	# las solerillas entre los senderos y el pasto (las de 4 Oriente, en las panorámicas de 2023), en tramos de 2 m
	var solera := func(a: Vector2, b: Vector2) -> void:
		var L := a.distance_to(b)
		var n := ceili(L / 2.0)
		for i in n:
			var p := a.lerp(b, float(i) / n)
			var q := a.lerp(b, float(i + 1) / n)
			al_suelo(minf(p.x, q.x) - 0.06, minf(p.y, q.y) - 0.06, maxf(p.x, q.x) + 0.06, maxf(p.y, q.y) + 0.06, 0.06, K["solera"], "hormigon")
	solera.call(Vector2(-44.6, -18.46), Vector2(44.66, -18.46))
	solera.call(Vector2(-44.6, 18.46), Vector2(44.66, 18.46))
	solera.call(Vector2(44.66, -18.46), Vector2(44.66, -2.06))
	solera.call(Vector2(44.66, 2.06), Vector2(44.66, 18.46))
	solera.call(Vector2(44.6, -2.06), Vector2(58.6, -2.06))
	solera.call(Vector2(44.6, 2.06), Vector2(58.6, 2.06))


# ---------------------------------------------------------------- la reja

# el murete amarillo en tramos de ≤ 2,05 m que siguen el suelo, los pilares cada 8,2 m en los lados largos y al medio
# de los cortos, y los postes altos de los portones (el vano, PUERTA a cada lado del eje)
func reja() -> void:
	var w := MURO
	var murete := func(u0: float, v0: float, u1: float, v1: float) -> void:
		var largo := maxf(u1 - u0, v1 - v0)
		var n := ceili(largo / 2.05)
		for i in n:
			var a := float(i) / n
			var b := float(i + 1) / n
			if u1 - u0 > v1 - v0:
				al_suelo(lerpf(u0, u1, a), v0, lerpf(u0, u1, b), v1, 0.6, K["amarillo"], "pintura", K["amarillo2"])
			else:
				al_suelo(u0, lerpf(v0, v1, a), u1, lerpf(v0, v1, b), 0.6, K["amarillo"], "pintura", K["amarillo2"])
	var pilar := func(u: float, v: float, h: float, s: float) -> void:
		al_suelo(u - s, v - s, u + s, v + s, h, K["amarillo"], "pintura", K["amarillo2"])
		al_suelo(u - s - 0.03, v - s - 0.03, u + s + 0.03, v + s + 0.03, h + 0.06, K["amarillo2"], "pintura")
	murete.call(U0 - w, V0 - w, U1 + w, V0)
	murete.call(U0 - w, V1, U1 + w, V1 + w)
	for u in [U0 - w, U1]:
		murete.call(u, V0, u + w, -PUERTA)
		murete.call(u, PUERTA, u + w, V1)
	for k in 11:
		var u := clampf(U0 + k * 8.2, U0 - w / 2, U1 + w / 2)
		pilar.call(u, V0 - w / 2, 1.3, 0.2)
		pilar.call(u, V1 + w / 2, 1.3, 0.2)
	for u in [U0 - w / 2, U1 + w / 2]:
		pilar.call(u, -7.4, 1.3, 0.2)
		pilar.call(u, 7.4, 1.3, 0.2)
		for v in [-PUERTA - 0.25, PUERTA + 0.25]:
			pilar.call(u, v, 2.4, 0.25)


# ---------------------------------------------------------------- la estructura grande

# la torre beige (techo de cajón, tobogán de tubo naranjo al poniente, muro de escalar turquesa al sur), el puente a la
# torre rosada (techo crema en punta, red lila al oriente), el tobogán metálico ancho al norte, la escalera al sur y el
# borde de concreto
func grande() -> void:
	var g := marco(GRANDE, [-7.0, -8.5, 6.0, 4.0])
	var pl := 1.6
	# la torre beige: el piso a 1,6 m deja 2 m bajo el techo (el personaje mide 1,75)
	torre(g, -3.6, -3.2, -1.2, -0.8, pl, 3.6, K["madera"], K["madera"])
	for e in [[-3.6, -3.2, -1.2, -3.15], [-3.6, -0.85, -1.2, -0.8], [-3.6, -3.2, -3.55, -0.8]]:
		m.caja(g, e[0], e[1], e[2], e[3], pl, pl + 0.95, K["panel"], "liso", K["madera2"])
	m.caja(g, -3.85, -3.45, -0.95, -0.55, 3.6, 3.75, K["madera2"])
	m.caja(g, -3.75, -3.35, -1.05, -0.65, 3.75, 4.6, K["capota"], "liso", K["capota2"])
	# el muro de escalar, con sus asideros
	m.caja(g, -3.5, -3.4, -1.3, -3.25, -0.3, pl, K["turquesa"])
	var rng := RandomNumberGenerator.new()
	rng.seed = 370
	for i in 14:
		var u := rng.randf_range(-3.35, -1.5)
		var h := rng.randf_range(0.25, 1.45)
		var c: Color = K["asideros"][i % 4]
		m.caja(g, u, -3.48, u + 0.12, -3.4, h, h + 0.1, c)
	tubo(g, -5.1, -2.0, 1.05, 0.38, pl + 0.45, 0.35, 1.25, 0.0, K["naranjo"], K["naranjo2"])
	# el puente, con su baranda rosada abierta a la escalera (sur) y al tobogán (norte)
	m.caja(g, -1.2, -2.8, 1.8, -1.2, pl - 0.06, pl, K["madera"], "liso", null, true)
	for e in [[-1.2, -2.8, 0.0, -2.75], [1.5, -2.8, 1.8, -2.75], [-1.2, -1.25, 0.2, -1.2], [1.3, -1.25, 1.8, -1.2]]:
		m.caja(g, e[0], e[1], e[2], e[3], pl, pl + 0.9, K["rosado"], "pintura", K["rosado2"])
	# la torre rosada: su techo queda bajo (1,3 m sobre el piso): no se entra
	torre(g, 1.8, -3.2, 4.2, -0.8, pl, 2.9, K["madera"], K["madera"])
	for e in [[1.8, -3.2, 4.2, -3.15], [1.8, -0.85, 4.2, -0.8], [4.15, -3.2, 4.2, -0.8]]:
		m.caja(g, e[0], e[1], e[2], e[3], pl, pl + 0.95, K["rosado"], "pintura", K["rosado2"])
	var base := PackedVector2Array([Vector2(1.5, -3.5), Vector2(4.5, -3.5), Vector2(4.5, -0.5), Vector2(1.5, -0.5)])
	m.piramide(g, base, 2.9, 4.6, 3.0, -2.0, K["crema"], "pintura")
	m.piso(g, base, 2.9, K["crema2"], "liso", Callable(), true)
	m.solido = false  # la red lila del oriente
	for i in 7:
		var v := lerpf(-3.0, -1.0, float(i) / 6)
		barra(g, Vector3(4.3, v, 0.2), Vector3(4.3, v, pl + 0.9), 0.03, K["lila"])
	for i in 8:
		var h := lerpf(0.2, pl + 0.9, float(i) / 7)
		barra(g, Vector3(4.3, -3.0, h), Vector3(4.3, -1.0, h), 0.03, K["lila"])
	m.solido = true
	# el tobogán metálico, del puente al norte, y la escalera del sur
	tobogan(g, Vector3(0.75, -1.2, pl), Vector3(0.75, 3.4, 0.3), 0.9, K["metal"], K["metal2"])
	escalera(g, Vector3(0.75, -2.8, pl), Vector3(0.75, -5.2, 0.0), 1.4, 8, K["madera"], K["fierro"])
	# el borde de concreto, con arena adentro: de 35 cm, se pasa sin saltar (jugador.gd PELDANO) hacia la escalera
	for e in [[-3.0, -7.9, 2.5, -7.7], [-3.0, -5.6, 2.5, -5.4], [-3.0, -7.7, -2.8, -5.6], [2.3, -7.7, 2.5, -5.6]]:
		m.caja(g, e[0], e[1], e[2], e[3], -0.3, 0.35, K["gris"], "hormigon", K["gris2"])
	m.caja(g, -2.8, -7.7, 2.3, -5.6, -0.3, 0.25, K["arena"])


# ---------------------------------------------------------------- la estructura chica

# postes amarillos bajo un techo de arco amarillo, una linterna beige arriba, un tobogán rojo al sur y uno rosado al
# oriente; el piso a 1 m y el techo a 2 m: para niños chicos, el personaje no cabe
func chica() -> void:
	var g := marco(CHICA, [-18.0, -6.5, -9.5, 1.0])
	var pl := 1.0
	torre(g, -17.2, -2.6, -12.8, 0.6, pl, 2.0, K["poste"], K["panel"])
	for q in [[-15.06, -2.6], [-15.06, 0.48]]:
		m.caja(g, q[0], q[1], q[0] + 0.12, q[1] + 0.12, -0.5, 2.0, K["poste"])
	# el techo: una bóveda de cañón a lo largo de u, de v -2,7 a 0,7, que sube 0,7 m, en franjas de dos tonos
	var n := 10
	for i in n:
		var a0 := PI * i / n
		var a1 := PI * (i + 1) / n
		var p0 := Vector2(-1.0 - 1.7 * cos(a0), 2.0 + 0.7 * sin(a0))
		var p1 := Vector2(-1.0 - 1.7 * cos(a1), 2.0 + 0.7 * sin(a1))
		var col: Color = K["poste"] if i % 2 == 0 else K["amarillo2"]
		var q4 := [g.V(-17.3, p0.x, p0.y), g.V(-12.7, p0.x, p0.y), g.V(-12.7, p1.x, p1.y), g.V(-17.3, p1.x, p1.y)]
		var up: Vector3 = (q4[1] - q4[0]).cross(q4[3] - q4[0]).normalized()
		if up.y < 0:
			up = -up
		m.cara(q4, col, "pintura", up)
		m.cara(q4, K["amarillo"].darkened(0.2), "pintura", -up)
	m.cilindro(g, -15.0, -1.0, 0.45, 2.6, 3.1, K["panel"], "liso", 10)
	m.piramide(g, Malla.ngon(-15.0, -1.0, 0.55, 10), 3.1, 3.45, -15.0, -1.0, K["capota"])
	baranda(g, Vector2(-17.2, 0.6), Vector2(-12.8, 0.6), pl, K["poste"])
	baranda(g, Vector2(-17.2, -2.6), Vector2(-17.2, 0.6), pl, K["poste"])
	tobogan(g, Vector3(-15.8, -2.6, pl), Vector3(-15.8, -5.6, 0.3), 0.6, K["rojo"], K["rojo2"], 6)
	tobogan(g, Vector3(-12.8, -1.0, pl), Vector3(-9.9, -1.0, 0.3), 0.6, K["rosado2"], K["rosado"], 6)


# ---------------------------------------------------------------- los columpios

# un marco rojo en A en cada punta, el travesaño y dos asientos de goma colgando de cadenas, que se mecen (mecer())
func columpios() -> void:
	var g := marco(Vector2.ZERO, [-28.8, -7.6, -23.0, -4.2])
	var vc := -6.0
	var top := 2.4
	m.solido = false
	for u in [-28.4, -23.6]:
		for dv in [-0.95, 0.95]:
			barra(g, Vector3(u, vc + dv, -0.3), Vector3(u, vc, top), 0.08, K["columpio"], "pintura")
	m.solido = true
	barra(g, Vector3(-28.5, vc, top), Vector3(-23.5, vc, top), 0.1, K["columpio"], "pintura")
	for su in [-26.75, -24.85]:
		# el eje del asiento en el travesaño: un nodo que gira; el asiento y las cadenas, en su marco (u, v, h desde él)
		var eje := Node3D.new()
		eje.position = g.V(su, vc, top - 0.05)
		add_child(eje)
		var s := Malla.new()
		var l := Malla.Marco.new(0.0, 0.0, A)
		s.solido = false
		for du in [-0.22, 0.22]:
			s.caja(l, du - 0.012, -0.012, du + 0.012, 0.012, -1.95, 0.0, K["cadena"], "metal")
		s.caja(l, -0.25, -0.11, 0.25, 0.11, -2.0, -1.95, K["goma"])
		s.construir(eje, "asiento")
		asientos.append([eje, su * 1.7])


func mecer(dt: float) -> void:
	t += dt
	for a in asientos:
		var eje: Node3D = a[0]
		eje.rotation.x = 0.05 * sin(2.2 * t + a[1]) + 0.02 * sin(0.7 * t + a[1] * 0.3)


# ---------------------------------------------------------------- la estructura del oriente

# la plataforma de barandas turquesa (piso de chapa gris a 1,3 m), la torrecilla de techo blanco (1,8 m libres), el
# tobogán de tubo azul al norte, el recto de franjas al sur y la escalera al poniente
func oriente() -> void:
	var g := marco(ORIENTE, [26.0, -1.0, 35.0, 10.0])
	var pl := 1.3
	torre(g, 29.4, 3.4, 33.8, 6.8, pl, pl + 0.9, K["baranda"], K["cubierta"])
	for q in [[31.6, 3.4], [31.6, 6.68]]:
		m.caja(g, q[0], q[1], q[0] + 0.12, q[1] + 0.12, -0.5, pl + 0.9, K["baranda"])
	baranda(g, Vector2(29.4, 6.8), Vector2(32.0, 6.8), pl, K["baranda"])  # norte, hasta el tubo
	baranda(g, Vector2(33.6, 6.8), Vector2(33.8, 6.8), pl, K["baranda"])
	baranda(g, Vector2(33.8, 3.4), Vector2(33.8, 6.8), pl, K["baranda"])  # oriente
	baranda(g, Vector2(29.4, 3.4), Vector2(30.2, 3.4), pl, K["baranda"])  # sur, a los lados del tobogán
	baranda(g, Vector2(31.6, 3.4), Vector2(33.8, 3.4), pl, K["baranda"])
	baranda(g, Vector2(29.4, 5.8), Vector2(29.4, 6.8), pl, K["baranda"])  # poniente, al norte de la escalera
	baranda(g, Vector2(29.4, 3.4), Vector2(29.4, 4.0), pl, K["baranda"])
	# la torrecilla
	for q in [[31.8, 4.6], [33.58, 4.6], [31.8, 6.58], [33.58, 6.58]]:
		m.caja(g, q[0], q[1], q[0] + 0.12, q[1] + 0.12, pl, 3.1, K["baranda"])
	var techo := PackedVector2Array([Vector2(31.5, 4.3), Vector2(34.0, 4.3), Vector2(34.0, 7.0), Vector2(31.5, 7.0)])
	m.piramide(g, techo, 3.1, 4.25, 32.75, 5.65, K["blanco"], "pintura")
	m.piso(g, techo, 3.1, K["blanco2"], "liso", Callable(), true)
	tubo(g, 32.8, 8.0, 1.05, 0.38, pl + 0.45, 0.35, 1.25, -PI / 2, K["azul"], K["azul2"])
	tobogan(g, Vector3(30.9, 3.4, pl), Vector3(30.9, 0.3, 0.3), 0.9, K["celeste"], K["celeste2"])
	escalera(g, Vector3(29.4, 4.9, pl), Vector3(27.2, 4.9, 0.0), 1.4, 6, K["cubierta"], K["fierro"])


# ---------------------------------------------------------------- el cobertizo

# muros de bloque y techo de planchas, al norte dos cortinas metálicas rojas y una reja; al sur una puerta y una
# ventana bajo la pérgola de listones; al oriente el cierro de tablas rojas
func cobertizo() -> void:
	var w0 := -38.5
	var w1 := -28.0
	var s0 := 4.6
	var s1 := 10.6
	var h := 2.7
	var g := marco(Vector2.ZERO, [w0, -0.6, w1, s1])
	m.caja(g, w0, s0, w1, s1, -0.5, h, K["bloque"], "hormigon")
	# el techo de planchas, del norte (2,9) al sur (2,7), en ondas de dos tonos
	var u := w0 - 0.3
	var k := 0
	while u < w1 + 0.3 - 0.01:
		var e := minf(u + 0.25, w1 + 0.3)
		var q4 := [g.V(u, s0 - 0.3, h), g.V(e, s0 - 0.3, h), g.V(e, s1 + 0.3, h + 0.25), g.V(u, s1 + 0.3, h + 0.25)]
		m.cara(q4, K["techo"] if k % 2 == 0 else K["techo2"], "metal", Vector3.UP)
		m.cara(q4, K["techo2"], "liso", Vector3.DOWN)
		u = e
		k += 1
	var norte := Vector2(w1, s1)
	var norte2 := Vector2(w0, s1)
	m.solido = false
	for c in [[-36.0, -33.5], [-33.0, -30.5]]:
		m.moldura(g, norte, norte2, w1 - c[1], w1 - c[0], 0.0, 2.2, 0.05, K["cortina"], "metal")
		var z := 0.15
		while z < 2.2:
			m.moldura(g, norte, norte2, w1 - c[1], w1 - c[0], z, z + 0.03, 0.07, K["cortina"].darkened(0.2), "metal")
			z += 0.18
		m.moldura(g, norte, norte2, w1 - c[1] - 0.05, w1 - c[0] + 0.05, 2.2, 2.35, 0.1, K["cortina"].darkened(0.3), "metal")
	m.moldura(g, norte, norte2, w1 - (-36.4), w1 - (-38.0), 0.6, 2.2, 0.03, K["puerta"])  # la reja, sobre un fondo oscuro
	var sg := w1 - (-36.4) + 0.06
	while sg < w1 - (-38.0) - 0.04:
		m.moldura(g, norte, norte2, sg, sg + 0.04, 0.6, 2.2, 0.09, K["reja"], "metal")
		sg += 0.15
	# al sur, la puerta y la ventana
	var sur := Vector2(w0, s0)
	var sur2 := Vector2(w1, s0)
	m.moldura(g, sur, sur2, 2.0, 3.0, 0.0, 2.1, 0.03, K["puerta"])
	m.moldura(g, sur, sur2, 5.0, 7.0, 1.0, 2.0, 0.03, K["vidrio"], "vidrio")
	m.solido = true
	# la pérgola: tres postes, dos vigas y listones cada 0,5 m
	for q in [[w0 + 0.2, -0.4], [(w0 + w1) / 2, -0.4], [w1 - 0.32, -0.4]]:
		m.caja(g, q[0], q[1], q[0] + 0.12, q[1] + 0.12, -0.5, 2.4, K["liston"])
	m.caja(g, w0 + 0.1, -0.42, w1 - 0.1, -0.26, 2.4, 2.6, K["liston"])
	m.caja(g, w0 + 0.1, s0 - 0.1, w1 - 0.1, s0, 2.4, 2.6, K["liston"])
	m.solido = false
	var lu := w0 + 0.2
	var j := 0
	while lu < w1 - 0.2:
		m.caja(g, lu, -0.5, lu + 0.08, s0, 2.6, 2.72, K["liston"] if j % 2 == 0 else K["liston2"])
		lu += 0.5
		j += 1
	m.solido = true
	# el cierro de tablas, al oriente
	var tu := -27.0
	j = 0
	while tu < -19.5:
		m.caja(g, tu, 9.6, minf(tu + 0.15, -19.5), 9.75, -0.4, 2.0, K["tabla"] if j % 2 == 0 else K["tabla2"])
		tu += 0.15
		j += 1


# ---------------------------------------------------------------- afuera del poniente

# la caseta de OSM (w1421055218), naranja con su puerta, y el gabinete cubierto de grafitis
func afuera() -> void:
	al_suelo(-51.2, -11.2, -47.9, -7.4, 2.4, K["caseta"], "pintura")
	al_suelo(-51.35, -11.35, -47.75, -7.25, 2.55, K["caseta2"])
	var g := marco(Vector2.ZERO, [-51.2, -11.2, -47.9, -7.4])
	m.solido = false
	m.moldura(g, Vector2(-47.9, -11.2), Vector2(-47.9, -7.4), 1.2, 2.1, 0.0, 2.0, 0.03, K["puerta"])
	m.solido = true
	al_suelo(-53.4, -10.4, -52.4, -9.6, 1.5, K["verde"])
	var c := marco(Vector2.ZERO, [-53.4, -10.4, -52.4, -9.6])
	m.solido = false
	for q in [[0.1, 0.45, 0.3, 0.9, "grafiti"], [0.5, 0.9, 0.6, 1.2, "grafiti2"], [0.2, 0.6, 0.9, 1.1, "fierro"]]:
		m.moldura(c, Vector2(-52.4, -10.4), Vector2(-52.4, -9.6), q[0], q[1], q[2], q[3], 0.02, K[q[4]])
		m.moldura(c, Vector2(-53.4, -10.4), Vector2(-52.4, -10.4), q[0] + 0.1, q[1] + 0.1, q[2], q[3], 0.02, K[q[4]])
	m.solido = true


# ---------------------------------------------------------------- los senderos

# bancas en el borde del pasto mirando a la reja, faroles junto a la reja (con su lámpara, que se enciende de noche),
# dos basureros y el letrero del portón oriente
func senderos() -> void:
	for u in [-32.0, -16.0, 0.0, 16.0, 32.0]:
		for sg in [-1.0, 1.0]:
			banca(u, sg * 18.95, sg)
	for u in [-36.0, -20.0, -4.0, 12.0, 28.0]:
		for sg in [-1.0, 1.0]:
			farol(u + (8.0 if sg > 0 else 0.0), sg * 15.6)
	for q in [[-30.0, 18.95], [20.25, -18.95]]:
		var gb := marco(Vector2.ZERO, [q[0] - 0.3, q[1] - 0.3, q[0] + 0.3, q[1] + 0.3])
		m.caja(gb, q[0] - 0.04, q[1] - 0.04, q[0] + 0.04, q[1] + 0.04, -0.3, 0.9, K["fierro"], "metal")
		m.cilindro(gb, q[0], q[1], 0.25, 0.3, 1.0, K["basurero"], "pintura", 12)
	# el letrero: dos postes y un tablero café con su franja clara (el texto no se lee en las fotos)
	var g := marco(Vector2.ZERO, [45.2, -2.2, 45.8, 2.2])
	for v in [-1.9, 1.9]:
		m.caja(g, 45.35, v - 0.06, 45.47, v + 0.06, -0.4, 3.1, K["puerta"])
	m.caja(g, 45.33, -2.1, 45.49, 2.1, 2.2, 3.0, K["letrero"])
	m.solido = false
	for sg in [-1.0, 1.0]:
		var a := Vector2(45.41 + sg * 0.08, -1.6 * sg)  # a -> b con la cara hacia afuera a su derecha
		var b := Vector2(45.41 + sg * 0.08, 1.6 * sg)
		m.moldura(g, a, b, 0.0, 3.2, 2.42, 2.78, 0.01, K["texto"])
	m.solido = true


# una banca en (u, v) del tramo, mirando a la reja (sg: -1 al sur del eje, mira al norte): patas de fierro, tres
# listones de asiento y dos de respaldo
func banca(u: float, v: float, sg: float) -> void:
	var g := marco(Vector2.ZERO, [u - 1.1, v - 0.4, u + 1.1, v + 0.4])
	var fr := v + sg * 0.25  # el respaldo, del lado del pasto
	for du in [-0.9, 0.9]:
		m.caja(g, u + du - 0.03, v - 0.25, u + du + 0.03, v + 0.25, -0.2, 0.42, K["fierro"], "metal")
		m.caja(g, u + du - 0.03, fr - 0.04, u + du + 0.03, fr + 0.04, 0.42, 0.85, K["fierro"], "metal")
	for i in 3:
		var a := v - sg * 0.22 + sg * i * 0.16
		m.caja(g, u - 1.0, minf(a, a + sg * 0.12), u + 1.0, maxf(a, a + sg * 0.12), 0.42, 0.46, K["banca"])
	for z in [0.55, 0.72]:
		m.caja(g, u - 1.0, fr - 0.03, u + 1.0, fr + 0.03, z, z + 0.11, K["banca"])


# un farol en (u, v): el poste negro y una lámpara de globo, que de noche se enciende (y suma su luz: faroles.gd)
func farol(u: float, v: float) -> void:
	var g := marco(Vector2.ZERO, [u - 0.2, v - 0.2, u + 0.2, v + 0.2])
	m.cilindro(g, u, v, 0.14, -0.3, 0.5, K["fierro"], "metal", 8)
	m.cilindro(g, u, v, 0.07, 0.5, 3.8, K["fierro"], "metal", 8)
	m.cilindro(g, u, v, 0.12, 3.8, 3.9, K["fierro"], "metal", 8)
	m.solido = false
	m.cilindro(g, u, v, 0.2, 3.9, 4.25, K["lampara"], "ventana", 10)
	m.piramide(g, Malla.ngon(u, v, 0.2, 10), 4.25, 4.4, u, v, K["lampara"], "ventana")
	m.caja(g, u - 0.1, v - 0.1, u + 0.1, v + 0.1, 4.38, 4.45, K["fierro"], "metal")
	m.solido = true
	lamparas.append(g.V(u, v, 4.1))
