# Las cuatro calles alrededor de la Plaza de Armas (1 Norte, 1 Sur, 1 Oriente, 1 Poniente: Cardenal Raúl Silva
# Henríquez) y sus tramos hasta ~130 m de la plaza: calzada de losas de hormigón con demarcación, pasos de cebra,
# soleras de granito, veredas de baldosa, árboles, faroles, semáforos, señales, paraderos y autos estacionados.
# Reemplaza las capas suelo, veredas, autos, arboles, usos y patios del glb entre las fachadas (plano.gd).
#
# Fuentes, pieza por pieza (el detalle de cada una va en su función):
#   - el plano (fachadas, soleras, anchos): plano.gd;
#   - la calzada: OSM (surface=concrete, lanes=2, oneway en las cuatro calles) y la foto de 1 Norte hacia la catedral
#     (Commons, «Iglesia de la comunidad buen pastor.jpg», 2022-05-28): losas de hormigón gris con juntas, sin asfalto;
#   - los cruces: los nodos highway=crossing y crossing=traffic_signals de OSM (plaza-osm.json), cruzando la calle por el
#     camino más corto entre soleras; los semáforos: los nodos highway=traffic_signals;
#   - los faroles: la foto de 1 Norte (2022) y las de la catedral (2017, 2018): poste de fierro fundido verde oscuro
#     con base, linterna de cuatro caras y un brazo con macetero;
#   - los árboles de vereda: los nodos natural=tree de OSM fuera de la plaza (1 Norte y 1 Oriente al norte); OSM no
#     dice la especie: un caducifolio de copa ancha (en las fotos, otoñal), aproximado;
#   - los autos: estacionados del lado de la plaza en las cuatro calles, como en la imagen de Esri y las fotos; modelos
#     y colores inventados (los más comunes en Chile: blanco, gris, plata, negro, rojo, azul).
# Lo aproximado: el ancho de las veredas (±1 m), la demarcación (líneas de pista segmentadas, cebras de 0,5 m), dónde
# va cada farol (cada ~22 m); los letreros de las calles son los de letreros.gd (con sus fuentes).
extends Node3D

const Args := preload("res://args.gd")
const Auto := preload("res://modelos/entorno/auto.gd")
const Letreros := preload("res://letreros.gd")
const Malla := preload("res://malla.gd")
const Plano := preload("res://modelos/entorno/plano.gd")
const Suelo := preload("res://modelos/entorno/suelo.gd")

const C_CALZADA := Color(0.53, 0.53, 0.51)
const C_ASFALTO := Color(0.36, 0.36, 0.36)
const C_VEREDA := Color(0.66, 0.64, 0.60)
const C_FAJA := Color(0.62, 0.36, 0.30)  # la faja de baldosa roja de las veredas (foto de 1 Norte)
const C_GRANITO := Color(0.72, 0.71, 0.68)
const C_BLANCO := Color(0.92, 0.92, 0.88)
const C_FIERRO := Color(0.12, 0.19, 0.16)  # el verde oscuro de los faroles
const C_NEGRO := Color(0.09, 0.09, 0.09)
# el sentido del tránsito de las calles de la plaza (grilla: x al oriente, y al norte), para las flechas de sus letreros:
# de OSM (oneway=yes; 1 Norte w33885109, 1 Oriente w33885416, 1 Sur w191869142, 1 Poniente w172679667, noviembre de
# 2026), una vuelta en el sentido del reloj, como en data/sentidos.json
const SENTIDO_PLAZA := {"1 NORTE": Vector2(1, 0), "1 SUR": Vector2(-1, 0), "1 ORIENTE": Vector2(0, -1), "1 PONIENTE": Vector2(0, 1)}

var S: Suelo
var calz := []  # polígonos de calzada (con los redondeos de las esquinas)
var pasillos := []  # de fachada a fachada
var pz_solera: PackedVector2Array
var rng := RandomNumberGenerator.new()
var choques := Malla.new()  # la colisión de los autos: una caja cada uno


func recortes() -> Array:
	# «hitos»: los faroles y semáforos que la página dibuja para estas calles (src/js/hitos/calles-plaza.js), del
	# tamaño de un píxel de arte; este modelo pone los suyos
	var capas := ["suelo", "veredas", "autos", "arboles", "usos", "patios", "hitos"]
	var out := []
	for p in zona():
		out.append({"poligono": p, "capas": capas})
	return out


# la zona que este modelo dibuja, en polígonos sin huecos: el anillo de fachada a fachada menos la plaza, en
# cuatro cuadrantes, y los tramos que siguen
func zona() -> Array:
	var out := []
	var anillo := Plano.anillo_fachadas()
	var pz := Plano.crecer(Plano.pz(), 0.2)
	for q in [[-200, -200, 0, 0], [0, -200, 200, 0], [0, 0, 200, 200], [-200, 0, 0, 200]]:
		for a in Geometry2D.intersect_polygons(anillo, Plano.rect(q)):
			for b in Geometry2D.clip_polygons(a, pz):
				if not Geometry2D.is_polygon_clockwise(b):
					out.append(b)
	for t in Plano.TRAMOS:
		out.append(Plano.rect(t[2]))
	return out


func _ready() -> void:
	rng.seed = 1541  # el año en que Talca no existía todavía: la semilla da lo mismo, pero fija
	S = Suelo.new(get_parent())
	pz_solera = Plano.crecer(Plano.pz(), 0.16)
	calz.append(Plano.anillo_calzada())
	for t in Plano.TRAMOS:
		calz.append(Plano.rect(t[1]))
	calz.append_array(redondeos())
	pasillos.append(Plano.anillo_fachadas())
	for t in Plano.TRAMOS:
		pasillos.append(Plano.rect(t[2]))

	var piso := Malla.new()
	suelos(piso)
	demarcacion(piso)
	piso.construir(self, "calles-suelo", false)

	var cosas := Malla.new()
	faroles(cosas)
	semaforos(cosas)
	senales(cosas)
	cosas.solido = false
	autos(cosas)
	cosas.construir(self, "calles-objetos")
	choques.construir_colision(self, "autos-colision")

	var arb := Malla.new()
	arboles(arb)
	arb.construir(self, "calles-arboles")
	cenital()


# para revisar el plano: --cenital x,y,lado pone una cámara ortográfica mirando hacia abajo sobre (x, y) de grilla,
# con lado m de alto, sin niebla (solo para las capturas: --png)
func cenital() -> void:
	if not Args.has("--cenital"):
		return
	var d := Args.nums("--cenital", 3, [0.0, 0.0, 300.0])
	for i in 3:
		await get_tree().process_frame
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = d[2]
	cam.far = 500
	add_child(cam)
	cam.global_position = Vector3(d[0], 200, -d[1])
	cam.rotation_degrees = Vector3(-90, 0, 0)
	cam.make_current()
	for we in get_tree().root.find_children("*", "WorldEnvironment", true, false):
		we.environment.fog_enabled = false


# ---------------------------------------------------------------- el suelo

# las esquinas de las veredas, redondeadas (radio 3 m frente a la plaza, 4 m en las manzanas de las esquinas): el
# pedazo de calzada entre la esquina y el arco, [esquina, signo hacia la vereda]
func redondeos() -> Array:
	var esquinas := [[-64.5, 69.0, -1, 1, 4.0], [66.0, 65.5, 1, 1, 4.0], [67.5, -68.5, 1, -1, 4.0], [-64.5, -68.5, -1, -1, 4.0],
		[-64.5, 59.5, -1, -1, 3.0], [-64.5, -58.5, -1, 1, 3.0], [-59.5, 65.5, 1, 1, 3.0], [59.5, 65.5, -1, 1, 3.0],
		[67.5, 58.0, 1, -1, 3.0], [67.5, -58.0, 1, 1, 3.0], [-57.5, -68.5, 1, -1, 3.0], [59.0, -68.5, -1, -1, 3.0]]
	var out := []
	for e in esquinas:
		var c := Vector2(e[0], e[1])
		var s := Vector2(e[2], e[3])
		var r: float = e[4]
		var o := c + s * r
		var p := PackedVector2Array([c])
		for i in 9:
			var t := float(i) / 8.0
			var d := Vector2(0, -s.y).lerp(Vector2(-s.x, 0), t).normalized()
			p.append(o + d * r)
		if Geometry2D.is_polygon_clockwise(p):
			p.reverse()
		out.append(p)
	return out


func dentro(p: Vector2, polys: Array) -> bool:
	for q in polys:
		if Geometry2D.is_point_in_polygon(p, q):
			return true
	return false


func es_calzada(p: Vector2) -> bool:
	return dentro(p, calz) and not Geometry2D.is_point_in_polygon(p, pz_solera)


static func unir(ps: Array) -> Array:
	var out := []
	for p in ps:
		var cur: PackedVector2Array = p
		var i := 0
		while i < out.size():
			var m := Geometry2D.merge_polygons(out[i], cur)
			var ext := m.filter(func(x): return not Geometry2D.is_polygon_clockwise(x))
			if ext.size() == 1:
				cur = ext[0]
				out.remove_at(i)
				i = 0
			else:
				i += 1
		out.append(cur)
	return out


static func restar(ps: Array, q: PackedVector2Array) -> Array:
	var out := []
	for p in ps:
		for r in Geometry2D.clip_polygons(p, q):
			if not Geometry2D.is_polygon_clockwise(r):
				out.append(r)
	return out


# un polígono plano apoyado en el terreno a alto metros, cortado por los triángulos del relieve
func apoyar(m: Malla, piezas: Array, alto: float, col: Color, mat: String) -> void:
	var g := Malla.grilla()
	for pz in piezas:
		m.piso(g, pz, 0.0, col, mat, func(x, y): return S.E(x, y) + alto)


func suelos(m: Malla) -> void:
	var caja := Rect2(-Plano.LEJOS - 2, -Plano.LEJOS - 2, 2 * Plano.LEJOS + 4, 2 * Plano.LEJOS + 4)
	var tri := S.triangulos(caja.position.x, caja.position.y, caja.end.x, caja.end.y)
	var pz := Plano.pz()
	var bordes := []  # [a, b, alto de este lado, qué hay del otro lado]
	for T in tri:
		var cz := []
		for p in calz:
			cz.append_array(Geometry2D.intersect_polygons(T, p).filter(func(x): return not Geometry2D.is_polygon_clockwise(x)))
		cz = restar(unir(cz), pz_solera)
		var ve := []
		for p in pasillos:
			ve.append_array(Geometry2D.intersect_polygons(T, p).filter(func(x): return not Geometry2D.is_polygon_clockwise(x)))
		ve = unir(ve)
		for p in calz:
			ve = restar(ve, p)
		ve = restar(ve, pz_solera)
		var so := restar(Geometry2D.intersect_polygons(T, pz_solera).filter(func(x): return not Geometry2D.is_polygon_clockwise(x)), pz)
		# 1 Oriente es de asfalto (x entre la plaza y la solera oriente); las otras, de losas de hormigón
		var asf := Plano.rect([55.0, -Plano.LEJOS - 5, Plano.SOLERA["E"], Plano.LEJOS + 5])
		var cza := []
		for p in cz:
			cza.append_array(Geometry2D.intersect_polygons(p, asf).filter(func(x): return not Geometry2D.is_polygon_clockwise(x)))
		apoyar(m, restar(cz, asf), Plano.ALTO_CALZADA, C_CALZADA, "hormigon")
		apoyar(m, cza, Plano.ALTO_CALZADA, C_ASFALTO, "asfalto")
		apoyar(m, ve, Plano.ALTO_VEREDA, C_VEREDA, "baldosa")
		apoyar(m, so, Plano.ALTO_VEREDA + 0.004, C_GRANITO, "granito")
		for p in cz:
			for i in p.size():
				bordes.append([p[i], p[(i + 1) % p.size()], Plano.ALTO_CALZADA])
		for p in ve:
			for i in p.size():
				bordes.append([p[i], p[(i + 1) % p.size()], Plano.ALTO_VEREDA])
	# los bordes: una solera donde la vereda o la plaza dan a la calzada; un faldón hasta el suelo donde la zona
	# termina (los cortes de los tramos, las fachadas), para que no se vea el hueco con el glb
	var g := Malla.grilla()
	for b in bordes:
		var a: Vector2 = b[0]
		var c: Vector2 = b[1]
		var L := a.distance_to(c)
		if L < 0.02:
			continue
		var d := (c - a) / L
		var o := Vector2(d.y, -d.x)
		var afuera := (a + c) / 2 + o * 0.08
		var h: float = b[2]
		if h == Plano.ALTO_VEREDA:
			if es_calzada(afuera):
				# la solera: cara vertical hasta la calzada y una franja de granito de 16 cm sobre la vereda
				m.cara([g.V(a.x, a.y, S.E(a.x, a.y) + Plano.ALTO_CALZADA), g.V(c.x, c.y, S.E(c.x, c.y) + Plano.ALTO_CALZADA),
					g.V(c.x, c.y, S.E(c.x, c.y) + h), g.V(a.x, a.y, S.E(a.x, a.y) + h)], C_GRANITO, "granito", g.N(o.x, o.y))
				var ai := a - o * 0.16
				var ci := c - o * 0.16
				m.cara([g.V(a.x, a.y, S.E(a.x, a.y) + h + 0.006), g.V(c.x, c.y, S.E(c.x, c.y) + h + 0.006),
					g.V(ci.x, ci.y, S.E(ci.x, ci.y) + h + 0.006), g.V(ai.x, ai.y, S.E(ai.x, ai.y) + h + 0.006)], C_GRANITO, "granito", Vector3.UP)
			elif not dentro(afuera, pasillos) and not Geometry2D.is_point_in_polygon(afuera, pz_solera):
				m.cara([g.V(a.x, a.y, S.E(a.x, a.y) - 0.3), g.V(c.x, c.y, S.E(c.x, c.y) - 0.3),
					g.V(c.x, c.y, S.E(c.x, c.y) + h), g.V(a.x, a.y, S.E(a.x, a.y) + h)], C_VEREDA, "baldosa", g.N(o.x, o.y))
		else:
			if Geometry2D.is_point_in_polygon(afuera, pz_solera):
				m.cara([g.V(a.x, a.y, S.E(a.x, a.y) + h), g.V(c.x, c.y, S.E(c.x, c.y) + h),
					g.V(c.x, c.y, S.E(c.x, c.y) + Plano.ALTO_VEREDA), g.V(a.x, a.y, S.E(a.x, a.y) + Plano.ALTO_VEREDA)], C_GRANITO, "granito", g.N(o.x, o.y))
			elif not dentro(afuera, pasillos) and not dentro(afuera, calz):
				m.cara([g.V(a.x, a.y, S.E(a.x, a.y) - 0.3), g.V(c.x, c.y, S.E(c.x, c.y) - 0.3),
					g.V(c.x, c.y, S.E(c.x, c.y) + h), g.V(a.x, a.y, S.E(a.x, a.y) + h)], C_CALZADA, "hormigon", g.N(o.x, o.y))
	# la faja de baldosa roja a 1,2 m de las fachadas que miran a la plaza (foto de 1 Norte, 2022)
	var faja := [[Plano.FACHADA["O"] + 1.0, -56.0, Plano.FACHADA["O"] + 1.6, 56.0], [-54.0, Plano.FACHADA["N"] - 1.6, 56.0, Plano.FACHADA["N"] - 1.0],
		[Plano.FACHADA["E"] - 1.6, -52.0, Plano.FACHADA["E"] - 1.0, 54.0], [-54.0, Plano.FACHADA["S"] + 1.0, 57.0, Plano.FACHADA["S"] + 1.6]]
	for f in faja:
		var p := Plano.rect(f)
		for T in tri:
			apoyar(m, Geometry2D.intersect_polygons(T, p).filter(func(x): return not Geometry2D.is_polygon_clockwise(x)),
				Plano.ALTO_VEREDA + 0.006, C_FAJA, "baldosa")


# una franja de pintura (un rectángulo de largo L y ancho w centrado en c, a lo largo de d) sobre la calzada
func pintura(m: Malla, c: Vector2, d: Vector2, L: float, w: float, col := C_BLANCO) -> void:
	var g := Malla.grilla()
	var n := Vector2(-d.y, d.x)
	var p := [c - d * L / 2 - n * w / 2, c + d * L / 2 - n * w / 2, c + d * L / 2 + n * w / 2, c - d * L / 2 + n * w / 2]
	var q := []
	for x in p:
		q.append(g.V(x.x, x.y, S.E(x.x, x.y) + Plano.ALTO_CALZADA + 0.012))
	m.cara(q, col, "pintura", Vector3.UP)


# desde c, cuánto sigue la calzada en la dirección d (hasta 30 m)
func hasta_solera(c: Vector2, d: Vector2) -> float:
	var s := 0.0
	while s < 30.0 and es_calzada(c + d * (s + 0.25)):
		s += 0.25
	return s


func demarcacion(m: Malla) -> void:
	m.solido = false
	# líneas de pista segmentadas (3 m de línea, 5 m de espacio), entre las dos pistas de cada calle de un sentido;
	# se cortan en los cruces de calles. [x o y fija, eje (0: corre en x, 1: en y), desde, hasta]
	var L := Plano.LEJOS - 3.0
	var lineas := [[61.6, 0, -58.0, 58.0], [-62.0, 0, -56.0, 58.0], [-61.0, 1, -56.0, 56.0], [63.0, 1, -56.0, 56.0],
		[64.3, 0, -L, -67.0], [61.8, 0, 70.0, L], [-63.5, 0, -L, -67.0], [-63.2, 0, 70.0, L],
		[-62.0, 1, 69.0, 98.0], [-61.0, 1, -L, -71.0], [62.7, 1, 69.0, L], [63.2, 1, -L, -71.0]]
	for l in lineas:
		var fijo: float = l[0]
		var a: float = l[2]
		var b: float = l[3]
		var s := a + 2.0
		while s + 3.0 < b - 2.0:
			var c := Vector2(s + 1.5, fijo) if l[1] == 0 else Vector2(fijo, s + 1.5)
			var d := Vector2(1, 0) if l[1] == 0 else Vector2(0, 1)
			if es_calzada(c) and not cerca_de_cruce(c, 5.0):
				pintura(m, c, d, 3.0, 0.12)
			s += 8.0
	# los pasos de cebra: franjas de 0,5 m cada 1 m, de 3 m de largo, cruzando la calle por el nodo de OSM
	for n in Plano.nodos("crossing"):
		if n.get("crossing", "") == "uncontrolled":
			continue  # los de las esquinas de la plaza cruzan en diagonal la pista que la rodea: sin cebra
		var c := Vector2(n["x"], n["y"])
		var d := direccion_calle(c)  # a lo largo de la calle
		var t := Vector2(-d.y, d.x)  # cruzando
		var s0 := -hasta_solera(c, -t)
		var s1 := hasta_solera(c, t)
		if s1 - s0 < 3.0 or s1 - s0 > 25.0:
			continue
		var s := s0 + 0.5
		while s + 0.5 <= s1 - 0.3:
			pintura(m, c + t * (s + 0.25), d, 3.0, 0.5)
			s += 1.0
		# la línea de detención, 1,5 m antes de la cebra en el lado del que vienen los autos (los dos: no sabemos)
		for sg in [-1.0, 1.0]:
			var e: Vector2 = c + d * sg * 2.7
			if es_calzada(e) and not cerca_de_cruce(e, 0.0, n):
				pintura(m, c + d * sg * 2.4 + t * (s0 + s1) / 2, t, s1 - s0 - 0.6, 0.35)
	m.solido = true


func cerca_de_cruce(c: Vector2, r: float, salvo: Variant = null) -> bool:
	for n in Plano.nodos("crossing"):
		if n == salvo or n.get("crossing", "") == "uncontrolled":
			continue
		var p := Vector2(n["x"], n["y"])
		var d := direccion_calle(p)
		var rel := c - p
		if abs(rel.dot(d)) < 2.0 + r and abs(rel.dot(Vector2(-d.y, d.x))) < 14.0:
			return true
	return false


var _dir_cache := {}


# la dirección de la calle (de autos) más cercana a un punto, de las vías de OSM
func direccion_calle(c: Vector2) -> Vector2:
	var k := Vector2i(roundi(c.x * 10), roundi(c.y * 10))
	if _dir_cache.has(k):
		return _dir_cache[k]
	var mejor := Vector2(1, 0)
	var dmin := INF
	for v in Plano.osm().get("vias", []):
		if v["highway"] in ["footway", "pedestrian", "service", "corridor", "steps", "cycleway"] or "link" in v["highway"]:
			continue
		var pts: Array = v["puntos"]
		for i in pts.size() - 1:
			var a := Vector2(pts[i][0], pts[i][1])
			var b := Vector2(pts[i + 1][0], pts[i + 1][1])
			var q := Geometry2D.get_closest_point_to_segment(c, a, b)
			var dd := q.distance_to(c)
			if dd < dmin and a.distance_to(b) > 1.0:
				dmin = dd
				mejor = (b - a).normalized()
	# las calles de la grilla corren por los ejes: se redondea a ellos
	mejor = Vector2(signf(mejor.x), 0) if abs(mejor.x) > abs(mejor.y) else Vector2(0, signf(mejor.y))
	_dir_cache[k] = mejor
	return mejor


# ---------------------------------------------------------------- objetos

# un farol de fierro fundido verde (fotos de 1 Norte, 2022, y de la catedral, 2017-2024): base de 0,8 m, poste que se
# adelgaza hasta 3,6 m, collarín, linterna de cuatro caras con vidrio y sombrerete; un brazo con macetero a 2,6 m
func farol(m: Malla, x: float, y: float, a: float) -> void:
	var f := Malla.Marco.new(x, y, a, S.E(x, y) + Plano.ALTO_VEREDA)
	var v := C_FIERRO
	m.prisma(f, Malla.ngon(0, 0, 0.2, 8, PI / 8), 0.0, 0.25, v, "metal")
	m.prisma(f, Malla.ngon(0, 0, 0.15, 8, PI / 8), 0.25, 0.8, v, "metal")
	m.prisma(f, Malla.ngon(0, 0, 0.18, 8, PI / 8), 0.8, 0.9, v, "metal")
	m.prisma(f, Malla.ngon(0, 0, 0.075, 8, PI / 8), 0.9, 3.55, v, "metal")
	m.prisma(f, Malla.ngon(0, 0, 0.11, 8, PI / 8), 3.55, 3.7, v, "metal")
	# la linterna: un tronco de pirámide de vidrio (más ancha arriba), con aristas de fierro
	var abajo := Malla.ngon(0, 0, 0.13, 4, PI / 4)
	var arriba := Malla.ngon(0, 0, 0.24, 4, PI / 4)
	m.prisma(f, abajo, 3.7, 3.78, v, "metal")
	for i in 4:
		var p0 := abajo[i]
		var p1 := abajo[(i + 1) % 4]
		var q0 := arriba[i]
		var q1 := arriba[(i + 1) % 4]
		var n := f.N((p0.x + p1.x) / 2, (p0.y + p1.y) / 2, 0.2)
		m.cara([f.V(p0.x, p0.y, 3.78), f.V(p1.x, p1.y, 3.78), f.V(q1.x, q1.y, 4.3), f.V(q0.x, q0.y, 4.3)], Color(0.86, 0.84, 0.74), "vidrio", n)
		m.caja(f, q0.x - 0.02, q0.y - 0.02, q0.x + 0.02, q0.y + 0.02, 3.78, 4.3, v, "metal")
	m.prisma(f, Malla.ngon(0, 0, 0.28, 4, PI / 4), 4.3, 4.36, v, "metal")
	m.piramide(f, Malla.ngon(0, 0, 0.26, 4, PI / 4), 4.36, 4.62, 0, 0, v, "metal")
	m.cilindro(f, 0, 0, 0.03, 4.62, 4.75, v, "metal", 6)
	# el brazo y el macetero (terracota, con flores)
	m.caja(f, 0.05, -0.025, 0.55, 0.025, 2.6, 2.65, v, "metal")
	m.prisma(f, Malla.ngon(0.62, 0, 0.13, 8), 2.38, 2.62, Color(0.55, 0.27, 0.18), "liso")
	m.prisma(f, Malla.ngon(0.62, 0, 0.15, 7), 2.62, 2.78, Color(0.30, 0.45, 0.22), "liso")


func faroles(m: Malla) -> void:
	# en la vereda de las manzanas, a 0,55 m de la solera, cada ~22 m; [x o y de la solera, eje, desde, hasta, signo
	# hacia la vereda]
	var filas := [[Plano.SOLERA["O"], 1, -52.0, 50.0, -1], [Plano.SOLERA["N"], 0, -50.0, 52.0, 1],
		[Plano.SOLERA["E"], 1, -50.0, 50.0, 1], [Plano.SOLERA["S"], 0, -52.0, 52.0, -1],
		[59.5, 0, -125.0, -74.0, -1], [69.0, 0, -112.0, -74.0, 1], [58.0, 0, 76.0, 125.0, -1], [65.5, 0, 87.0, 125.0, 1],
		[-58.5, 0, -125.0, -74.0, 1], [-68.5, 0, -112.0, -74.0, -1], [-58.0, 0, 76.0, 125.0, 1], [-68.5, 0, 87.0, 125.0, -1],
		[-64.5, 1, 76.0, 96.0, -1], [-59.5, 1, 87.0, 96.0, 1], [-64.5, 1, -125.0, -76.0, -1], [-57.5, 1, -112.0, -76.0, 1],
		[59.5, 1, 76.0, 125.0, -1], [66.0, 1, 87.0, 125.0, 1], [59.0, 1, -125.0, -76.0, -1], [67.5, 1, -112.0, -76.0, 1]]
	for fl in filas:
		var s: float = fl[2]
		while s <= fl[3]:
			var p := Vector2(fl[0] + fl[4] * 0.55, s) if fl[1] == 1 else Vector2(s, fl[0] + fl[4] * 0.55)
			if not cerca_de_cruce(p, 1.0):
				var hacia := Vector2(-fl[4], 0) if fl[1] == 1 else Vector2(0, -fl[4])  # el brazo, hacia la calle
				farol(m, p.x, p.y, atan2(hacia.x, -hacia.y))
			s += 24.0


# un semáforo: poste gris oscuro de 3,4 m y una caja negra con visera, rojo, amarillo y verde (el rojo, encendido),
# mirando hacia dir (de donde vienen los autos)
func semaforo(m: Malla, p: Vector2, dir: Vector2, peatonal := false) -> void:
	var f := Malla.Marco.new(p.x, p.y, atan2(dir.y, dir.x), S.E(p.x, p.y) + Plano.ALTO_VEREDA)
	var g := Color(0.22, 0.23, 0.23)
	m.prisma(f, Malla.ngon(0, 0, 0.065, 8), 0.0, 3.0 if peatonal else 3.4, g, "metal")
	if peatonal:
		m.caja(f, -0.17, 0.07, 0.17, 0.3, 2.1, 2.8, C_NEGRO, "pintura")
		for k in 2:
			var h := 2.3 + k * 0.32
			m.panel(f, Vector2(-0.12, 0.3), Vector2(0.12, 0.3), 0.0, 0.24, h - 0.12, h + 0.12, 0.005,
				[Color(0.25, 0.9, 0.5), Color(0.25, 0.08, 0.06)][k], "emisivo" if k == 0 else "pintura")
		return
	var h0 := 2.35
	m.caja(f, -0.17, 0.07, 0.17, 0.32, h0, h0 + 1.0, C_NEGRO, "pintura")
	m.caja(f, -0.25, 0.3, 0.25, 0.33, h0 - 0.08, h0 + 1.08, C_NEGRO, "pintura")  # la placa de contraste
	var luces := [Color(0.95, 0.18, 0.1), Color(0.3, 0.22, 0.05), Color(0.06, 0.2, 0.1)]
	for k in 3:
		var hc := h0 + 0.84 - k * 0.32
		var dsc := Malla.ngon(0, hc, 0.1, 10)
		var q := []
		for pp in dsc:
			q.append(f.V(pp.x, 0.335, pp.y))
		m.cara(q, luces[k], "emisivo" if k == 0 else "pintura", f.N(0, 1))
		m.caja(f, -0.12, 0.33, 0.12, 0.45, hc + 0.1, hc + 0.12, C_NEGRO, "pintura")


func semaforos(m: Malla) -> void:
	var centros := [Vector2(-61.5, 63.0), Vector2(63.0, 62.0), Vector2(64.0, -64.0), Vector2(-61.5, -63.0)]
	for n in Plano.nodos("traffic_signals"):
		var c := Vector2(n["x"], n["y"])
		var cen: Vector2 = centros[0]
		for k in centros:
			if k.distance_to(c) < cen.distance_to(c):
				cen = k
		var d := direccion_calle(c)
		var afuera := d if (c - cen).dot(d) > 0 else -d  # de donde vienen los autos
		# el poste en la solera de la derecha de quien llega (en Chile se maneja por la derecha): llega por -afuera
		var der := Vector2(-afuera.y, afuera.x)
		var s := hasta_solera(c, der)
		var p := c + der * (s + 0.45)
		semaforo(m, p, afuera)
	# los semáforos peatonales, a cada lado de los cruces con semáforo
	for n in Plano.nodos("crossing"):
		if n.get("crossing", "") != "traffic_signals":
			continue
		var c := Vector2(n["x"], n["y"])
		var d := direccion_calle(c)
		var t := Vector2(-d.y, d.x)
		for sg in [-1.0, 1.0]:
			var s := hasta_solera(c, t * sg)
			semaforo(m, c + t * sg * (s + 0.45) + d * 1.9, -t * sg, true)


# un letrero en un poste: una placa (con texto, Label3D) a la altura h, de ancho w, mirando hacia dir
func letrero(m: Malla, p: Vector2, dir: Vector2, texto: String, fondo: Color, letra: Color, h := 2.6, w := 0.9, alto := 0.22, poste := true) -> void:
	var f := Malla.Marco.new(p.x, p.y, atan2(dir.y, dir.x), S.E(p.x, p.y) + Plano.ALTO_VEREDA)
	if poste:
		m.prisma(f, Malla.ngon(0, 0, 0.035, 6), 0.0, h + alto / 2 + 0.05, Color(0.55, 0.56, 0.56), "metal")
	m.caja(f, -w / 2, 0.04, w / 2, 0.06, h - alto / 2, h + alto / 2, fondo, "pintura")
	for sg in [1.0, -1.0]:
		var l := Label3D.new()
		l.text = texto
		l.font_size = 64
		l.pixel_size = alto * 0.0105
		l.modulate = letra
		l.outline_size = 0
		l.double_sided = false
		l.shaded = true
		l.position = f.V(0, 0.05 + sg * 0.016, h)
		add_child(l)
		l.look_at(l.position - f.N(0, sg), Vector3.UP)


func senales(m: Malla) -> void:
	# los nombres de las calles en las cuatro esquinas de la plaza, en las veredas de las manzanas: el letrero de toda la
	# comuna (letreros.gd, con sus fuentes), cada placa saliendo del poste por la vereda de su calle, hacia afuera de la
	# plaza, con la numeración de esa cuadra (la regla de pipeline/geocode.py, como __exSigns de tools/export.js)
	var esquinas := [[Vector2(-65.6, 70.2), "1 NORTE|699|601", "1 PONIENTE|1201|1299"],
		[Vector2(68.6, 66.8), "1 NORTE|801|899", "1 ORIENTE|1201|1299"],
		[Vector2(68.6, -69.6), "1 SUR|801|899", "1 ORIENTE|1099|1001"],
		[Vector2(-65.6, -69.6), "1 SUR|699|601", "1 PONIENTE|1099|1001"]]
	for e in esquinas:
		var p: Vector2 = e[0]
		var h0 := S.E(p.x, p.y) + Plano.ALTO_VEREDA
		Letreros.poste(m, Malla.Marco.new(p.x, p.y, 0.0, h0))
		for k in 2:
			var d := Vector2(signf(p.x), 0) if k == 0 else Vector2(0, signf(p.y))
			var f := Malla.Marco.new(p.x, p.y, atan2(d.y, d.x), h0)
			Letreros.placa(m, f)
			# el tránsito de la calle de la placa: hacia donde apunta (1) o al revés (-1)
			var s: float = SENTIDO_PLAZA.get(String(e[k + 1]).split("|")[0], Vector2.ZERO).dot(d)
			if s != 0.0:
				Letreros.flecha(m, f, signf(s))
			for sg in [1.0, -1.0]:
				var l := Letreros.etiqueta()
				add_child(l)
				Letreros.texto(l, f, e[k + 1], sg)
	# «no estacionar» del lado de las manzanas (la foto de la catedral de 2017 tiene una frente al campanario)
	for p in [Vector2(-65.1, 38.0), Vector2(-65.1, -20.0), Vector2(20.0, 66.1), Vector2(68.1, 15.0), Vector2(-20.0, -69.1)]:
		var d := Vector2(0, 1) if abs(p.x) > 60 else Vector2(1, 0)
		var f := Malla.Marco.new(p.x, p.y, atan2(d.y, d.x), S.E(p.x, p.y) + Plano.ALTO_VEREDA)
		m.prisma(f, Malla.ngon(0, 0, 0.03, 6), 0.0, 2.45, Color(0.55, 0.56, 0.56), "metal")
		m.caja(f, -0.22, 0.03, 0.22, 0.05, 1.95, 2.55, Color(0.95, 0.95, 0.93), "pintura")
		var anillo := Malla.ngon(0, 2.32, 0.17, 16)
		var q := []
		for pp in anillo:
			q.append(f.V(pp.x, 0.055, pp.y))
		m.cara(q, Color(0.8, 0.12, 0.1), "pintura", f.N(0, 1))
		var dentro_ := Malla.ngon(0, 2.32, 0.13, 16)
		q = []
		for pp in dentro_:
			q.append(f.V(pp.x, 0.058, pp.y))
		m.cara(q, Color(0.95, 0.95, 0.93), "pintura", f.N(0, 1))
		var l := Label3D.new()
		l.text = "E"
		l.font_size = 64
		l.pixel_size = 0.0028
		l.modulate = Color(0.1, 0.1, 0.1)
		l.outline_size = 0
		l.position = f.V(0, 0.062, 2.32)
		add_child(l)
		l.look_at(l.position - f.N(0, 1), Vector3.UP)
		m.cara([f.V(-0.1, 0.064, 2.21), f.V(-0.07, 0.064, 2.19), f.V(0.1, 0.064, 2.43), f.V(0.07, 0.064, 2.45)], Color(0.8, 0.12, 0.1), "pintura", f.N(0, 1))
		var l2 := Label3D.new()
		l2.text = "LUN A SÁB\n8 A 20 HRS"
		l2.font_size = 32
		l2.pixel_size = 0.0026
		l2.modulate = Color(0.1, 0.1, 0.1)
		l2.outline_size = 0
		l2.position = f.V(0, 0.062, 2.05)
		add_child(l2)
		l2.look_at(l2.position - f.N(0, 1), Vector3.UP)
	# los paraderos de OSM (highway=bus_stop): poste con la placa de paradero
	for n in Plano.nodos("bus_stop"):
		var c := Vector2(n["x"], n["y"])
		var d := direccion_calle(c)
		var t := Vector2(-d.y, d.x)
		var p := c
		for sg in [1.0, -1.0]:  # a la vereda más cercana
			var s := hasta_solera(c, t * sg)
			if es_calzada(c) and s < 12:
				p = c + t * sg * (s + 0.6)
				break
		letrero(m, p, d, "PARADERO", Color(0.1, 0.35, 0.65), Color.WHITE, 2.7, 0.7, 0.35)


# ---------------------------------------------------------------- autos

# un auto (modelos/entorno/auto.gd): sedán, hatchback, SUV, camioneta o colectivo (sedán negro con letrero), de un
# color de Auto.COLORES; en un marco con v hacia adelante
func auto(m: Malla, p: Vector2, adelante: Vector2) -> void:
	var f := Malla.Marco.new(p.x, p.y, atan2(adelante.y, adelante.x), S.E(p.x, p.y) + Plano.ALTO_CALZADA)
	var tipo: int = [0, 0, 0, 1, 1, 2, 2, 3, 4][rng.randi() % 9]  # sedán, hatchback, SUV, camioneta, colectivo (sedán negro con letrero)
	var col: Color = Auto.COLORES[rng.randi() % Auto.COLORES.size()]
	if tipo == Auto.COLECTIVO:
		col = Auto.NEGRO_COLECTIVO
	Auto.modelo(m, f, tipo, col, choques)


func autos(m: Malla) -> void:
	# estacionados en fila junto a la solera de la plaza (las cuatro calles) y en los tramos que siguen, a la derecha
	# [punto de partida, dirección, largo, desplazamiento hacia la solera desde la calzada]
	var filas := [[Vector2(-60.0, -24.0), Vector2(0, 1), 46.0], [Vector2(-30.0, 59.0), Vector2(1, 0), 62.0],
		[Vector2(61.0, 28.0), Vector2(0, -1), 56.0], [Vector2(34.0, -60.0), Vector2(-1, 0), 56.0],
		[Vector2(-125.0, 64.0), Vector2(1, 0), 52.0], [Vector2(125.0, 61.8), Vector2(-1, 0), 50.0],
		[Vector2(-125.0, -63.5), Vector2(1, 0), 52.0], [Vector2(125.0, -63.2), Vector2(-1, 0), 50.0],
		[Vector2(-62.0, 96.0), Vector2(0, -1), 22.0], [Vector2(-61.0, -125.0), Vector2(0, 1), 50.0],
		[Vector2(62.7, 125.0), Vector2(0, -1), 52.0], [Vector2(63.2, -125.0), Vector2(0, 1), 50.0]]
	for fl in filas:
		var s := 0.0
		var d: Vector2 = fl[1]
		while s < fl[2]:
			var p: Vector2 = fl[0] + d * s
			# los autos van pegados a la solera: se corre hacia ella hasta 1 m del borde
			var t := Vector2(-d.y, d.x)
			var lado := t if hasta_solera(p, t) < hasta_solera(p, -t) else -t
			p = p + lado * (hasta_solera(p, lado) - 1.0)
			if rng.randf() < 0.86 and es_calzada(p) and not cerca_de_cruce(p, 2.5):
				auto(m, p, d)
			s += 5.6 + rng.randf() * 1.2


# ---------------------------------------------------------------- árboles

# una icoesfera de un nivel (80 caras), deformada, como un manchón de copa
func copa(m: Malla, c: Vector3, r: Vector3, col: Color) -> void:
	var t := (1.0 + sqrt(5.0)) / 2.0
	var v := [Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0), Vector3(0, -1, t), Vector3(0, 1, t),
		Vector3(0, -1, -t), Vector3(0, 1, -t), Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]
	var caras := [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6],
		[7, 1, 8], [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9], [4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]]
	var ruido := {}
	var P := func(p: Vector3) -> Vector3:
		var k := p.normalized()
		var key := Vector3i(roundi(k.x * 1000), roundi(k.y * 1000), roundi(k.z * 1000))
		if not ruido.has(key):
			ruido[key] = 0.82 + rng.randf() * 0.3
		return c + k * r * ruido[key]
	for cf in caras:
		var a: Vector3 = v[cf[0]]
		var b: Vector3 = v[cf[1]]
		var d: Vector3 = v[cf[2]]
		var ab := (a + b) / 2
		var bd := (b + d) / 2
		var da := (d + a) / 2
		for tr in [[a, ab, da], [ab, b, bd], [da, bd, d], [ab, bd, da]]:
			var p0: Vector3 = P.call(tr[0])
			var p1: Vector3 = P.call(tr[1])
			var p2: Vector3 = P.call(tr[2])
			var n := (p1 - p0).cross(p2 - p0).normalized()
			if n.dot(p0 - c) < 0:
				n = -n
			var sombra: float = 0.85 + 0.25 * clamp(((p0 + p1 + p2) / 3 - c).y / r.y, -1.0, 1.0)
			m.cara([p0, p1, p2], Color(col.r * sombra, col.g * sombra, col.b * sombra), "liso", n)


# un árbol de vereda de copa ancha: tronco gris pardo que se abre en tres ramas y una copa de cinco manchones
func arbol(m: Malla, x: float, y: float, alto := 8.0) -> void:
	var e := S.E(x, y) + Plano.ALTO_VEREDA
	var f := Malla.Marco.new(x, y, rng.randf() * TAU, e)
	var tronco := Color(0.36, 0.31, 0.26)
	m.solido = true
	m.prisma(f, Malla.ngon(0, 0, 0.24, 7), 0.0, alto * 0.38, tronco, "liso")
	# la taza del árbol: un cuadro de tierra con borde
	m.solido = false
	m.caja(f, -0.6, -0.6, 0.6, 0.6, -0.02, 0.012, Color(0.33, 0.25, 0.18), "liso")
	for k in 3:
		var a := TAU * k / 3.0 + rng.randf()
		var b := Vector2(cos(a), sin(a)) * alto * 0.16
		m.cara([f.V(-0.14, 0, alto * 0.34), f.V(0.14, 0, alto * 0.34), f.V(b.x + 0.08, b.y, alto * 0.62), f.V(b.x - 0.08, b.y, alto * 0.62)], tronco, "liso")
		m.cara([f.V(0.14, 0, alto * 0.34), f.V(-0.14, 0, alto * 0.34), f.V(b.x - 0.08, b.y, alto * 0.62), f.V(b.x + 0.08, b.y, alto * 0.62)], tronco, "liso")
	var verde: Color = [Color(0.33, 0.47, 0.22), Color(0.39, 0.52, 0.25), Color(0.30, 0.43, 0.20)][rng.randi() % 3]
	var R := alto * 0.36
	copa(m, f.V(0, 0, alto * 0.72), Vector3(R, R * 0.62, R), verde)
	for k in 4:
		var a := TAU * k / 4.0 + rng.randf() * 0.8
		var d := Vector2(cos(a), sin(a)) * R * 0.55
		copa(m, f.V(d.x, d.y, alto * (0.62 + rng.randf() * 0.12)), Vector3(R * 0.62, R * 0.45, R * 0.62), verde.lightened(rng.randf() * 0.08))


func arboles(m: Malla) -> void:
	var pz := Plano.crecer(Plano.pz(), 0.5)
	for n in Plano.nodos("tree"):
		var p := Vector2(n["x"], n["y"])
		if Geometry2D.is_point_in_polygon(p, pz) or not dentro(p, pasillos) or es_calzada(p):
			continue
		arbol(m, p.x, p.y, 7.5 + rng.randf() * 2.0)
