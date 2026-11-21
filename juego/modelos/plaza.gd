# La Plaza de Armas de Talca a la escala de una persona: reemplaza, dentro del contorno del parque (PZ), el hito de la
# página (src/js/hitos/plaza-de-armas.js, hecho para una vista isométrica en pixel art) y los árboles genéricos del glb.
#
# La planta es la del hito, de OpenStreetMap: el parque w479529034 (PZ), los doce prados w1186645153–64 entre los
# paseos diagonales, los dos de 1 Norte (w556036456, w556036459), las cuatro plazoletas de los ejes (el quiosco
# w223617018 al oriente, las piletas n11021259067 al norte y n3428801896 al poniente, el memorial de Carlos Spano
# n11021258973 en un macizo de flores al sur), la pileta central n3428801388 y la estatua de Monseñor Larraín
# n11021259030. Lo que está sobre el suelo sale de las fotos de Wikimedia Commons (las de la categoría de la plaza y
# las que da `python pipeline/landmark.py photos plaza-de-armas`; en docs/FUENTES.md):
#   2013-04  «Quiosco de la plaza de armas», «Plaza de armas de Talca2» (CC BY-SA 3.0)
#   2014-08/10  «Talca, plaza (15020251291)», «(14836795037)», «(15020260081)», «(15711413856)» (Flickr, CC BY-SA 2.0)
#   2005  «Talca plaza armas larrain» (dominio público)
#   2018  «Talca Plaza (5)» (JordiCuber, CC BY-SA 4.0): la pileta central
#   2024-10  «Plaza de Armas de Talca en 2024 01–04» (TomasVial, CC0): paseos, prados, especies, faroles, Spano
# y la imagen de Esri (z19, 2015: `pipeline/satellite.py punto 0 0 130 19`), para la hilera de árboles del borde.
# Lo que es aproximado está dicho en cada pieza. Coordenadas: metros de grilla (x al oriente, y al norte; en Godot
# X = x, Z = -y), origen en la plaza; las alturas, sobre el suelo del mapa en la plaza (mapa/indice.json, «h» del lugar).
extends Node3D

const Args := preload("res://args.gd")
const Plano := preload("res://modelos/entorno/plano.gd")
const Malla := preload("res://malla.gd")
const Mat := preload("res://materiales.gd")
const Tx := preload("res://modelos/plaza/texturas.gd")
const Arboles := preload("res://modelos/plaza/arboles.gd")
const Piezas := preload("res://modelos/plaza/piezas.gd")

# el contorno del parque (OSM w479529034, esquinas redondeadas: el PZ del hito, en plano.gd) y los prados, en metros de
# grilla (los LAWNS del hito; tools/check.py revisa que sigan iguales)
const PZ := Plano.PZ
const PRADOS := [
	[-13.4, 16.8, -4.5, 7.9, -1.9, 8.7, 0.5, 8.9, 3, 8.4, 5.3, 7.1, 14.3, 15.5, 13.7, 16.3, 7.6, 19.6, 0.1, 20.8, -7.1, 20],
	[17.2, 12.3, 8.4, 3.9, 9.2, 2.3, 9.8, -1, 9.2, -4.3, 8.5, -5.8, 17.3, -14.2, 19.9, -11.4, 22.1, -4.1, 21.8, 2.9, 19.7, 9.4],
	[-8.3, 3.9, -17.1, 13.1, -18.6, 12, -21.8, 5.6, -22, -1.9, -21.3, -8.8, -18.4, -14.8, -17.4, -16, -7.7, -6.5, -8.7, -4.8, -9.3, -2.7, -9.5, 0, -8.9, 2.7],
	[-4.3, -9.7, -13.5, -18.9, -12.1, -20.1, -5.7, -22.8, 0.7, -23, 9, -21.3, 14.5, -18, 5.6, -8.9, 3.3, -9.9, 0.5, -10.3, -2.2, -10.2],
	[-15.6, 18.8, -30.1, 32.5, -28, 34.9, -8.3, 34.8, -9.4, 32, -9.6, 28.5, -8.9, 25.5, -7.7, 23.7, -6.6, 23],
	[7.7, 34.4, 8.7, 31.6, 8.3, 28.2, 7.4, 25.8, 4.9, 22.7, 8.6, 22.4, 16.6, 17.4, 30.4, 30.9, 28, 34.2],
	[-33.1, 28.7, -35.7, 26, -35.5, 5.1, -31.9, 6.3, -28.6, 6.1, -26.3, 5.3, -25, 4.5, -24.8, 6.8, -20.9, 13.9, -19.6, 15.5],
	[33.1, 27.6, 19.6, 14.1, 21.7, 11.7, 23.8, 5.7, 26.8, 7.8, 30.7, 8.4, 33.5, 8.2, 35.5, 6.7, 35.7, 24.4],
	[-35.5, -10.4, -35.1, -27.8, -32, -30.8, -19.6, -18.3, -21, -16.2, -24.1, -10.6, -24.6, -9.1, -28.2, -11.2, -32, -11.4],
	[-28.4, -34.2, -26.2, -36.4, -7, -36.6, -8.7, -34.7, -9, -31.3, -8.1, -27.7, -6.9, -26.5, -14.3, -23.4, -16.5, -21.9],
	[28, -33.3, 24.3, -36.3, 7.4, -36.5, 9.1, -34.6, 9.5, -31.2, 8.7, -27.6, 7.7, -26.4, 15.1, -23.4, 17.7, -21.6],
	[24.4, -7.9, 22.9, -13.1, 20.1, -17.8, 31, -29.5, 35.1, -25.8, 35.3, -8.6, 33.2, -9.9, 29, -10, 26.2, -9.3],
	[5.3, 52.3, 38, 52.2, 39.3, 51.8, 41.7, 49.1, 41.6, 47.4, 39.9, 46.7, 38.3, 46.1, 5.3, 47.8, 3.1, 49.7, 3.5, 51.4],
	[-31, 48.3, -3, 48, -2.3, 49.4, -2.1, 51.7, -3.2, 52.7, -4.9, 53.2, -7, 53.5, -30.1, 54, -32.2, 52.8, -32.3, 51.1, -32.2, 49.2]]

# las piezas fijas (metros de grilla), del hito salvo donde se dice
const PILETA := Vector2(0.2, -1.4)
const PILETA_N := Vector2(-0.8, 29.7)
const PILETA_O := Vector2(-30.7, -2.3)
const QUIOSCO := Vector2(30.2, -0.5)
const SPANO := Vector2(0.2, -31.4)
const LARRAIN := Vector2(-35.2, 27.5)
# las palmeras canarias que flanquean las entradas diagonales (fotos de 2024 «01» y «04»: dos por entrada)
const PALMAS_ENTRADA := [[26.5, 32.5], [32.5, 25], [-26.5, 32.5], [-31, 23], [26.5, -32.5], [32.5, -25], [-26.5, -32.5], [-32.5, -25]]

var Y0 := -0.19   # el suelo del mapa en la plaza (mapa/indice.json); se lee en _init
var PAV := 0.11   # la cara de las baldosas
var pz: PackedVector2Array
var prados: Array[PackedVector2Array] = []
var colision := Malla.new()          # caras sólidas: una sola forma cóncava
var formas: Array = []               # [Shape3D, Transform3D] de lo que es mejor como forma simple (troncos, postes)
var ocupado: Array = []              # [Vector2, radio]: lo que ya está puesto, para que nada se monte
var arb: RefCounted
var rng := RandomNumberGenerator.new()
var stats := {}


func _init() -> void:
	name = "plaza"
	pz = Malla.pol(PZ)
	for p in PRADOS:
		prados.append(Malla.pol(p))
	Y0 = float(preload("res://glb.gd").lugar("plaza-de-armas").get("h", Y0))
	PAV = Y0 + 0.30  # como el hito: S.dy + 0,30


# --sin plaza|arboles|pasto apaga esa parte (hasta noviembre de 2026, PLAZA_ANTES=1 y PLAZA_SIN=arboles,pasto: sirven
# todavía, con un aviso)
static func apagado(que: String) -> bool:
	if que in Args.sin_():
		return true
	if que == "plaza" and OS.has_environment("PLAZA_ANTES"):
		push_warning("plaza.gd: PLAZA_ANTES=1 ahora es --sin plaza")
		return true
	if que in OS.get_environment("PLAZA_SIN").split(","):
		push_warning("plaza.gd: PLAZA_SIN=%s ahora es --sin %s" % [que, que])
		return true
	return false


# lo que se quita del glb dentro del contorno: el hito, sus árboles y el suelo de la manzana que queda debajo
func recortes() -> Array:
	if apagado("plaza"):
		return []
	return [{"poligono": Malla.pol(PZ), "capas": ["hitos", "arboles", "suelo", "patios", "usos"]}]


func _ready() -> void:
	if apagado("plaza"):  # para medir el juego sin este modelo
		return
	var t0 := Time.get_ticks_msec()
	rng.seed = 1541  # el año de la fundación... de Santiago; cualquier semilla fija sirve
	arb = Arboles.new()
	suelo()
	prados_y_soleras()
	var pz_ := Piezas.new(self)
	pz_.construir()
	if not apagado("arboles"):  # --sin arboles, pasto: para medir
		arboles()
	pz_.poner_escanos()
	if not apagado("pasto"):
		pasto_de_cerca()
	cuerpo()
	luces_de_noche(pz_.faroles)
	cerrar_lotes()
	print("plaza.gd: %d ms, %s" % [Time.get_ticks_msec() - t0, str(stats)])


func instancia(mesh: Mesh, xf := Transform3D.IDENTITY, sombra := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.transform = xf
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if sombra else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


# Lo que se repite (árboles, matas, faroles, escaños, basureros) va en lotes: un MultiMesh por malla, que se dibuja de
# una vez en cada pasada (color, profundidad y las cuatro cascadas de sombra de ambiente.gd). Con un MeshInstance por
# árbol eran ~860 dibujos por cuadro y la plaza bajaba a ~62 cuadros por segundo con el resto del juego.
var lotes := {}


# sombra: true, false o "solo" (una malla que solo proyecta sombra: la de los árboles, más liviana)
func lote(mesh: Mesh, xf: Transform3D, sombra: Variant = true, alcance := 0.0) -> void:
	var k := "%d/%s/%d" % [mesh.get_instance_id(), sombra, int(alcance)]
	if not k in lotes:
		lotes[k] = [mesh, sombra, alcance, []]
	lotes[k][3].append(xf)


func cerrar_lotes() -> void:
	for k in lotes:
		var l: Array = lotes[k]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = l[0]
		mm.instance_count = l[3].size()
		for i in l[3].size():
			mm.set_instance_transform(i, l[3][i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		if l[1] is String:
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		else:
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if l[1] else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if l[2] > 0:
			mmi.visibility_range_end = l[2]
			mmi.visibility_range_end_margin = 5.0
			mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		add_child(mmi)
	stats["lotes"] = lotes.size()


func en_prado(p: Vector2, margen := 0.0) -> int:
	for i in prados.size():
		if Geometry2D.is_point_in_polygon(p, prados[i]):
			return i
	if margen > 0:
		for i in prados.size():
			var q := prados[i]
			for k in q.size():
				if Geometry2D.get_closest_point_to_segment(p, q[k], q[(k + 1) % q.size()]).distance_to(p) < margen:
					return i
	return -1


func libre(p: Vector2, r: float) -> bool:
	for o in ocupado:
		if p.distance_to(o[0]) < r + o[1]:
			return false
	return true


# sep > 0: un árbol, que pide esa distancia (la media de las dos) a otros árboles y su radio a lo demás
func ocupar(p: Vector2, r: float, sep := 0.0) -> void:
	ocupado.append([p, r, sep])


func libre_arbol(p: Vector2, sep: float, r: float) -> bool:
	for o in ocupado:
		var d := p.distance_to(o[0])
		if o[2] > 0 and d < (sep + o[2]) / 2:
			return false
		if d < o[1] + r:
			return false
	return true


# ---- el suelo ----

# Las baldosas sobre todo el parque (los prados van encima, sobre sus soleras) y una solera de granito de 25 cm en el
# borde, que baja hasta la calle (el suelo del glb fuera del contorno está ~0,1–0,2 m más abajo).
func suelo() -> void:
	var dentro := Malla.adentro(pz, 0.25)
	var m := Malla.new()
	m.plano(dentro, PAV, Color.WHITE)
	instancia(m.malla(Mat.plaza("pavimento")), Transform3D.IDENTITY, false)
	colision.plano(pz, PAV, Color.WHITE)
	var s := Malla.new()
	var gris := Color(0.62, 0.61, 0.58)
	for i in pz.size():
		var a := pz[i]
		var b := pz[(i + 1) % pz.size()]
		var ai := dentro[i]
		var bi := dentro[(i + 1) % pz.size()]
		s.quad(Malla.P(a.x, a.y, PAV + 0.004), Malla.P(b.x, b.y, PAV + 0.004), Malla.P(bi.x, bi.y, PAV + 0.004), Malla.P(ai.x, ai.y, PAV + 0.004), gris, Vector3.UP)
	s.muros(pz, Y0 - 0.25, PAV + 0.004, gris)
	colision.muros(pz, Y0 - 0.25, PAV, gris)
	instancia(s.malla(Mat.plaza("piedra", {"rugoso": 0.8})))
	# los adoquines alrededor de la pileta poniente (el hito: «sett round the west fountain», de la imagen de Esri)
	var ad := Malla.new()
	var circ := PackedVector2Array()
	for k in 48:
		circ.append(PILETA_O + Vector2.from_angle(TAU * k / 48) * 7.2)
	ad.plano(circ, PAV + 0.004, Color.WHITE)
	instancia(ad.malla(Mat.plaza("pavimento", {"base_col": Color(0.6, 0.58, 0.55), "banda_col": Color(0.6, 0.58, 0.55),
		"baldosa": 0.2, "paso_banda": 1000.0})), Transform3D.IDENTITY, false)


# Los prados: una solera de hormigón pintada de blanco de 30 cm de alto y 20 cm de ancho (fotos de 2014 y 2024), el
# pasto 6 cm bajo su borde y la reja baja de aros de fierro verde oscuro por dentro (38 cm). En algunos tramos, una
# hilera de piedras y un macizo con agapantos y bolas recortadas por dentro de la reja (foto de 2024 «01»).
func prados_y_soleras() -> void:
	var sol := Malla.new()
	var pasto := Malla.new()
	var rej := Malla.new()
	var blanco := Color(0.9, 0.89, 0.85)
	var H := PAV + 0.30
	var HP := H - 0.06
	var piedras: Array[Transform3D] = []
	for i in prados.size():
		var q := prados[i]
		var qi := Malla.adentro(q, 0.2)
		sol.muros(q, PAV - 0.03, H, blanco)
		for k in q.size():
			var a := q[k]
			var b := q[(k + 1) % q.size()]
			var ai := qi[k]
			var bi := qi[(k + 1) % q.size()]
			sol.quad(Malla.P(a.x, a.y, H), Malla.P(b.x, b.y, H), Malla.P(bi.x, bi.y, H), Malla.P(ai.x, ai.y, H), blanco, Vector3.UP,
				[Vector2(0, 0), Vector2(a.distance_to(b), 0), Vector2(a.distance_to(b), 0.2), Vector2(0, 0.2)])
		sol.muros(qi, HP, H, blanco, false)
		pasto.plano(qi, HP, Color.WHITE)
		colision.muros(q, PAV - 0.03, H, blanco)
		colision.plano(q, HP, blanco)
		# la reja: 35 cm adentro de la solera
		var qr := Malla.adentro(q, 0.35)
		var largo := 0.0
		for k in qr.size():
			var a := qr[k]
			var b := qr[(k + 1) % qr.size()]
			var l := a.distance_to(b)
			var u0 := largo / 0.8
			var u1 := (largo + l) / 0.8
			var nn := Vector3(b.y - a.y, 0, b.x - a.x).normalized()
			rej.quad(Malla.P(a.x, a.y, HP), Malla.P(b.x, b.y, HP), Malla.P(b.x, b.y, HP + 0.38), Malla.P(a.x, a.y, HP + 0.38), Color.WHITE, nn,
				[Vector2(u0, 1), Vector2(u1, 1), Vector2(u1, 0), Vector2(u0, 0)])
			colision.quad(Malla.P(a.x, a.y, HP), Malla.P(b.x, b.y, HP), Malla.P(b.x, b.y, HP + 0.38), Malla.P(a.x, a.y, HP + 0.38), Color.WHITE, nn)
			largo += l
		# macizos: en los tramos de más de 6 m, con probabilidad, piedras y matas por dentro de la reja
		var qm := Malla.adentro(q, 0.6)
		for k in qm.size():
			var a := qm[k]
			var b := qm[(k + 1) % qm.size()]
			var l := a.distance_to(b)
			if l < 6.0 or rng.randf() > 0.45:
				continue
			var d := (b - a) / l
			var nin := Vector2(-d.y, d.x) * (1.0 if Malla.area(q) > 0 else -1.0)
			var s := 1.0
			while s < l - 1.0:
				var p := a + d * s
				var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.7, 1.3)), Malla.P(p.x, p.y, HP))
				piedras.append(xf)
				s += rng.randf_range(0.3, 0.45)
			s = 1.5
			while s < l - 1.5:
				var p := a + d * s + nin * rng.randf_range(0.5, 0.9)
				if Geometry2D.is_point_in_polygon(p, qi):
					var esp := "agapanto" if rng.randf() < 0.65 else "arbusto"
					var mesh: ArrayMesh = arb.malla(esp, rng.randi())
					lote(mesh, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.8, 1.2)), Malla.P(p.x, p.y, HP)), esp == "arbusto", 70.0)
				s += rng.randf_range(0.9, 1.6)
	instancia(sol.malla(Mat.plaza("piedra", {"rugoso": 0.85})))
	instancia(pasto.malla(Mat.plaza("pasto")), Transform3D.IDENTITY, false)
	instancia(rej.malla(Mat.textura(Tx.reja(), 0.4, 0.5)))
	# las piedras: una sola malla instanciada (MultiMesh)
	var piedra := Malla.new()
	Piezas.roca(piedra, rng, Vector3.ZERO, 0.16, Color(0.62, 0.6, 0.55))
	var mp := StandardMaterial3D.new()
	mp.vertex_color_use_as_albedo = true
	mp.roughness = 0.9
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = piedra.malla(mp)
	mm.instance_count = piedras.size()
	for i in piedras.size():
		mm.set_instance_transform(i, piedras[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visibility_range_end = 60.0
	add_child(mmi)
	stats["piedras"] = piedras.size()


# ---- los árboles ----

func arbol(especie: String, p: Vector2, h: float, escala := 1.0, var_ := -1, sep := 4.0) -> void:
	var v := var_ if var_ >= 0 else rng.randi()
	var mesh: ArrayMesh = arb.malla(especie, v)
	var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * escala), Malla.P(p.x, p.y, h))
	lote(mesh, xf, false)
	lote(arb.sombra(especie, v), xf, "solo")
	var r: float = arb.radio(especie, v) * escala
	if r > 0.05:
		var cil := CylinderShape3D.new()
		cil.radius = r
		cil.height = 4.0
		formas.append([cil, Transform3D(Basis(), Malla.P(p.x, p.y, h + 2.0))])
	ocupar(p, max(r, 0.5), sep)
	stats[especie] = stats.get(especie, 0) + 1


# el alcorque de un árbol en el pavimento: un cuadro de tierra de 1,4 m con un borde de hormigón
func alcorque(p: Vector2, m: Malla) -> void:
	var tierra := Color(0.33, 0.26, 0.2)
	var borde := Color(0.7, 0.69, 0.65)
	var q := PackedVector2Array([p + Vector2(-0.7, -0.7), p + Vector2(0.7, -0.7), p + Vector2(0.7, 0.7), p + Vector2(-0.7, 0.7)])
	var qi := Malla.adentro(q, 0.1)
	m.muros(q, PAV - 0.02, PAV + 0.06, borde)
	for k in 4:
		var a := q[k]
		var b := q[(k + 1) % 4]
		var ai := qi[k]
		var bi := qi[(k + 1) % 4]
		m.quad(Malla.P(a.x, a.y, PAV + 0.06), Malla.P(b.x, b.y, PAV + 0.06), Malla.P(bi.x, bi.y, PAV + 0.06), Malla.P(ai.x, ai.y, PAV + 0.06), borde, Vector3.UP)
	m.muros(qi, PAV - 0.03, PAV + 0.06, borde, false)
	m.plano(qi, PAV - 0.03, tierra)


# Dónde van: las palmeras de las entradas (fijas), la hilera del borde sobre el pavimento (OSM y la imagen de Esri: un
# árbol cada ~9 m a 5,5 m del borde, de hoja ancha; palmeras en el lado sur, donde la imagen muestra copas en
# estrella) y los árboles de los prados, repartidos al azar con una semilla fija y una distancia mínima, con la mezcla
# de especies de las fotos. Las posiciones de los árboles de los prados y de la hilera son aproximadas.
func arboles() -> void:
	for p in [PILETA, PILETA_N, PILETA_O]:
		ocupar(p, 4.0)
	ocupar(QUIOSCO, 5.5)
	ocupar(QUIOSCO + Vector2(10.3, 0), 4.0)  # la losa del escudo
	ocupar(SPANO, 4.2)
	ocupar(LARRAIN, 1.5)
	for i in PALMAS_ENTRADA.size():
		var p := Vector2(PALMAS_ENTRADA[i][0], PALMAS_ENTRADA[i][1])
		arbol("palmera", p, PAV + 0.24 if en_prado(p) >= 0 else PAV, rng.randf_range(1.0, 1.2), i)
	arbol("palmera", Vector2(-34.3, 25.0), PAV + 0.24, 1.15)  # tras la estatua de Larraín (foto de 2005)

	# la hilera del borde
	var al := Malla.new()
	var fila := Malla.adentro(pz, 5.5)
	var entradas := []
	for d in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		entradas.append(d.normalized() * 64.0)
	for e in [Vector2(0, 55), Vector2(0, -55), Vector2(55, -1), Vector2(-55, -1)]:
		entradas.append(e)
	var largo := 0.0
	for k in fila.size():
		var a := fila[k]
		var b := fila[(k + 1) % fila.size()]
		var l := a.distance_to(b)
		var s := fmod(9.0 - fmod(largo, 9.0), 9.0)
		while s < l:
			var p := a.lerp(b, s / l)
			s += 9.0
			var cerca := false
			for e in entradas:
				var lim: float = 9.0 if e.length() > 60 else 7.0
				if p.distance_to(e.normalized() * min(e.length(), p.length())) < lim and p.length() > 30:
					cerca = true
			if cerca or not libre_arbol(p, 8.0, 1.0):
				continue
			var esp := "palmera" if p.y < -40 and int(p.x / 9.0) % 2 == 0 else "frondoso"
			var en := en_prado(p, 0.6)
			if en < 0:
				alcorque(p, al)
			arbol(esp, p, PAV + (0.24 if en >= 0 else 0.0), rng.randf_range(0.75, 0.9) if esp == "frondoso" else rng.randf_range(0.9, 1.1), -1, 8.0)
		largo += l
	instancia(al.malla(Mat.plaza("piedra")))

	# los prados, en dos pasadas: primero los árboles grandes que hacen la sombra densa de la plaza (cedros, araucarias,
	# frondosos: la imagen de Esri muestra la copa casi cerrada sobre los prados), después palmeras, copas podadas y
	# cordylines en los claros
	var grandes := [["cedro", 0.32, 10.0], ["araucaria", 0.2, 8.0], ["frondoso", 0.48, 9.0]]
	var chicos := [["palmera", 0.45, 5.0], ["podado", 0.3, 5.5], ["cordyline", 0.25, 3.5]]
	for pasada in [grandes, chicos]:
		for i in prados.size():
			var q := Malla.adentro(prados[i], 1.6 if pasada == grandes else 1.2)
			var caja := Rect2(q[0], Vector2.ZERO)
			for p in q:
				caja = caja.expand(p)
			var puestos := 0
			for t in int(caja.get_area() / 3.0) + 20:
				var p := caja.position + Vector2(rng.randf() * caja.size.x, rng.randf() * caja.size.y)
				if not Geometry2D.is_point_in_polygon(p, q):
					continue
				var x := rng.randf()
				var e: Array = pasada[0]
				for m in pasada:
					x -= m[1]
					if x <= 0:
						e = m
						break
				var esp: String = e[0]
				if i >= 12 and esp in ["cedro", "araucaria"]:
					esp = "frondoso"  # los prados de 1 Norte son angostos
				if pasada == chicos and puestos >= 2:
					break
				if not libre_arbol(p, e[2], 1.0):
					continue
				arbol(esp, p, PAV + 0.24, rng.randf_range(0.9, 1.1), -1, e[2])
				puestos += 1


# ---- el pasto de cerca ----

# Matas de hojas de pasto sobre los prados (MultiMesh por prado, sin sombra): 14 por m², visibles hasta 26 m. Más
# lejos queda el pasto plano con su ruido de color.
func pasto_de_cerca() -> void:
	var mata := Malla.new()
	var r := RandomNumberGenerator.new()
	r.seed = 77
	for b in 5:
		var az := r.randf() * TAU
		var p := Vector3(cos(az), 0, sin(az)) * r.randf_range(0.0, 0.08)
		var h := r.randf_range(0.06, 0.13)
		var d := Vector3(cos(az + 1.3), 0, sin(az + 1.3)) * 0.012
		var inc := Vector3(cos(az), 0, sin(az)) * r.randf_range(0.02, 0.06)
		var base := Color(0.2, 0.32, 0.11) * r.randf_range(0.8, 1.1)
		var punta := Color(0.36, 0.5, 0.19) * r.randf_range(0.85, 1.15)
		base.a = 1; punta.a = 1
		var mid := p + Vector3.UP * h * 0.55 + inc * 0.4
		var nn := Vector3(cos(az), 0.6, sin(az)).normalized()
		mata.tri_n(p - d, p + d, mid + d * 0.6, nn, nn, nn, base, base, base.lerp(punta, 0.6))
		mata.tri_n(p - d, mid + d * 0.6, mid - d * 0.6, nn, nn, nn, base, base.lerp(punta, 0.6), base.lerp(punta, 0.6))
		mata.tri_n(mid - d * 0.6, mid + d * 0.6, p + Vector3.UP * h + inc, nn, nn, nn, base.lerp(punta, 0.6), base.lerp(punta, 0.6), punta)
	var mesh := mata.malla(Mat.plaza("pasto_hojas"))
	var total := 0
	for i in prados.size():
		var q := Malla.adentro(prados[i], 0.45)
		var tri := Geometry2D.triangulate_polygon(q)
		var xfs: Array[Transform3D] = []
		for t in range(0, tri.size(), 3):
			var a := q[tri[t]]
			var b := q[tri[t + 1]]
			var c := q[tri[t + 2]]
			var area: float = abs((b - a).cross(c - a)) / 2.0
			for k in int(area * 14.0):
				var u := r.randf()
				var v := r.randf()
				if u + v > 1:
					u = 1 - u; v = 1 - v
				var p := a + (b - a) * u + (c - a) * v
				var ok := true
				for o in ocupado:
					if p.distance_to(o[0]) < 0.35 and o[1] < 1.6:
						ok = false
						break
				if ok:
					xfs.append(Transform3D(Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3(1, r.randf_range(0.7, 1.4), 1)), Malla.P(p.x, p.y, PAV + 0.24)))
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = xfs.size()
		for k in xfs.size():
			mm.set_instance_transform(k, xfs[k])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = 26.0
		mmi.visibility_range_end_margin = 5.0
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		add_child(mmi)
		total += xfs.size()
	stats["matas"] = total


# ---- de noche ----

# Una luz en cada farol y una bajo el cielo del quiosco. ambiente.gd prende las suyas de noche (las busca en la capa
# «hitos» del glb, que aquí se recorta); estas se agregan a su lista para que las prenda y apague igual. Sin ambiente
# (o con otro que no tenga `faroles`), quedan apagadas.
func luces_de_noche(postes: Array) -> void:
	var amb: Node = null
	for n in get_parent().get_children():
		if n != self and n.has_method("poner_hora") and "faroles" in n:
			amb = n
	if amb == null:
		return
	# ambiente busca los faroles por el color en los vértices de «hitos», y el recorte de main.gd deja los vértices de
	# los triángulos quitados (solo cambia los índices): encuentra los del hito de la página dentro de la plaza y les
	# pone un foco y una luz flotando donde ya no hay poste. Se sacan aquí.
	var quedan: Array[OmniLight3D] = []
	for f in amb.faroles:
		if Geometry2D.is_point_in_polygon(Vector2(f.position.x, -f.position.z), Malla.adentro(pz, -1.0)):
			f.queue_free()
		else:
			quedan.append(f)
	amb.faroles = quedan
	if amb.get("focos") is MultiMeshInstance3D:
		var mm: MultiMesh = amb.focos.multimesh
		for i in mm.instance_count:
			var o := mm.get_instance_transform(i).origin
			if Geometry2D.is_point_in_polygon(Vector2(o.x, -o.z), Malla.adentro(pz, -1.0)):
				mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ZERO), o))
	var puntos: Array[Vector3] = []
	for q in postes:
		puntos.append(Malla.P(q.x, q.y, PAV + 4.15))
	puntos.append(Malla.P(QUIOSCO.x, QUIOSCO.y, PAV + 1.35 + 2.7))
	for p in puntos:
		var f := OmniLight3D.new()
		f.position = p
		f.light_color = Color(1.0, 0.78, 0.5)
		f.omni_range = 13.0
		f.omni_attenuation = 1.4
		f.shadow_enabled = false
		f.light_energy = 0.0
		f.visible = false
		add_child(f)
		amb.faroles.append(f)
	amb.poner_hora(amb.hora)  # para que tomen la hora de partida (--hora)
	stats["luces"] = puntos.size()


# ---- colisión ----

func cuerpo() -> void:
	var cuerpo := StaticBody3D.new()
	cuerpo.name = "plaza_colision"
	add_child(cuerpo)
	cuerpo.add_child(Malla.colisionador(Malla.concava(colision.caras())))
	for f in formas:
		var c := CollisionShape3D.new()
		c.shape = f[0]
		c.transform = f[1]
		cuerpo.add_child(c)
	stats["caras_colision"] = colision.caras().size() / 3
