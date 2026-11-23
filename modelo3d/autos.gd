# Los autos del mapa: las capas «autos» (los estacionados de las calles, parkedCars de src/js/60-streets.js) y
# «autos-ruta5» (los de la Ruta 5, ruta5Objects de 66-ruta5.js), que tools/export.py --instancias escribe como datos en
# mapa/t_<i>_<j>.json (x, y, altura, largo, alto, giro, color e inclinación de cada uno; __exInst de tools/export.js).
# Los pone mapa.gd, tesela por tesela, como los árboles (arboleda.gd).
#
# Cerca de la cámara (CERCA) son los autos de calles.gd (modelos/entorno/auto.gd), uno por cada auto de la página: el
# tipo sale de su largo y su alto (un furgón 1,3 veces el alto, un camión de la Ruta 5 2,1; de los autos, los más
# cortos son hatchback, los más largos SUV o camioneta), el color es el de la página y la inclinación, la de la calle.
# Más lejos, el auto de la página (carGeo: dos cajas, 20 triángulos) con su largo y su alto. Cada tesela tiene un
# MultiMesh de lejos por capa; los de cerca van en un MultiMesh por tipo, que se rehace cuando la cámara se mueve
# REHACER metros: los que entran ahí se esconden en el de su tesela (su transformación en cero). Así nunca se dibujan
# los dos. Un solo material para todos los colores: la carrocería va en alfa 0 y toma el color de su instancia
# (Mat.tinte, los datos propios del MultiMesh).
#
# Colisión: una caja por auto (Auto.caja: la de calles.gd) a menos de CHOQUE de la cámara, que se rehace con los de
# cerca; hasta noviembre de 2026 eran los triángulos de los autos del glb, en la colisión de cada tesela cercana (los
# de la Ruta 5 no tenían: ahora sí). Una BoxShape3D por auto y no una forma cóncava con todas: la caja aparece cuando
# la cámara llega a CHOQUE, o de golpe alrededor del personaje si viaja (Tab, --desde) a donde hay un auto, y de una
# forma convexa el motor lo saca; de una cóncava con caras por los dos lados quedaba encerrado. Los recortes de los modelos (recortes()) que nombran la capa,
# o ninguna, quitan los autos cuyo centro cae dentro (preparar()), como el recorte del glb quitaba un auto entero.
extends Node3D

const Args := preload("res://args.gd")
const Auto := preload("res://modelos/entorno/auto.gd")
const Malla := preload("res://malla.gd")
const Mat := preload("res://materiales.gd")
const N := 10  # números por auto en los datos (__exInstN)
const CAPAS := ["autos", "autos-ruta5"]
const CERCA := 90.0  # m: hasta aquí, los autos de calles.gd
const REHACER := 12.0  # m que se mueve la cámara antes de volver a elegir los de cerca
const CHOQUE := 60.0  # m: los autos con colisión
const LEJOS := {"autos": 450.0, "autos-ruta5": 600.0}  # m: más allá no se dibujan (lo que hacía VISTA de mapa.gd)
const LARGO := 4.5  # m: el auto de la página a escala 1 (carGeo)

var teselas := {}  # clave -> {capa: {"d": PackedFloat32Array (N por auto), "b": PackedFloat32Array (16 por auto), "caja": Rect2, "mmi": MultiMeshInstance3D, "oculta": bool}}
var cerca := {}  # tipo -> MultiMeshInstance3D
var centro := Vector2(INF, INF)
var lejos: ArrayMesh
var choques: StaticBody3D
var cajas: Array[CollisionShape3D] = []  # las de los autos cercanos (se reusan)
var formas := {}  # "ancho/largo/alto" -> BoxShape3D
var n_cerca := 0


func _ready() -> void:
	name = "autos"
	visible = not ("autos" in Args.sin_())  # --sin autos: para medir cuánto cuestan con --fps
	lejos = auto_lejos()
	choques = StaticBody3D.new()
	choques.name = "autos-colision"
	add_child(choques)


# la transformación de un auto en Godot: el giro en torno a Y y la inclinación en torno a su eje transversal (Z
# local), como el Euler YZX de carsMesh; escala (largo, alto, 1) de lejos o 1 de cerca
static func xf(d: PackedFloat32Array, k: int, lejos_ := true, largo := 1.0) -> Transform3D:
	var b := Basis(Vector3.UP, d[k + 5]) * Basis(Vector3.BACK, d[k + 9])
	if lejos_:
		b = b.scaled_local(Vector3(d[k + 3], d[k + 4], 1.0))
	elif largo != 1.0:
		b = b.scaled_local(Vector3(largo, 1.0, 1.0))
	return Transform3D(b, Vector3(d[k], d[k + 2], -d[k + 1]))


static func empacar(b: PackedFloat32Array, t: Transform3D, c: Color) -> void:
	var s := t.basis
	b.append_array([s.x.x, s.y.x, s.z.x, t.origin.x, s.x.y, s.y.y, s.z.y, t.origin.y, s.x.z, s.y.z, s.z.z, t.origin.z, c.r, c.g, c.b, 1.0])


# en un hilo (mapa.gd): los autos de una tesela ({capa: Array de números}, solo las de CAPAS) sin lo que quitan los
# recortes, y los búferes de los de lejos (MultiMesh: 12 números de la transformación y 4 de los datos propios, el color)
static func preparar(datos: Dictionary, recs: Array) -> Dictionary:
	var out := {}
	for capa in CAPAS:
		if not datos.has(capa):
			continue
		var a: Array = datos[capa]
		var pols := []
		for r in recs:
			var capas: Array = r.get("capas", [])
			if capas.is_empty() or capa in capas:
				pols.append(r["poligono"])
		var d := PackedFloat32Array()
		var b := PackedFloat32Array()
		var caja := Rect2()
		for k in range(0, a.size() - N + 1, N):
			var p := Vector2(a[k], a[k + 1])
			var fuera := true
			for pol in pols:
				if Geometry2D.is_point_in_polygon(p, pol):
					fuera = false
					break
			if not fuera:
				continue
			caja = Rect2(p, Vector2.ZERO) if d.is_empty() else caja.expand(p)
			var i := d.size()
			for j in N:
				d.append(a[k + j])
			empacar(b, xf(d, i), Color(a[k + 6], a[k + 7], a[k + 8]))
		if d.size() > 0:
			out[capa] = {"d": d, "b": b, "caja": caja}
	return out


# en el hilo principal: los autos de lejos de una tesela (lo que dio preparar())
func agregar(clave: String, prep: Dictionary) -> void:
	quitar(clave)
	var t := {}
	for capa in prep:
		var e: Dictionary = prep[capa]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = lejos
		mm.instance_count = e["d"].size() / N
		mm.buffer = e["b"]
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.visibility_range_end = LEJOS[capa]
		add_child(mmi)
		e["mmi"] = mmi
		e["oculta"] = false
		t[capa] = e
	teselas[clave] = t
	centro = Vector2(INF, INF)  # que rehaga los de cerca


func quitar(clave: String) -> void:
	if not teselas.has(clave):
		return
	for capa in teselas[clave]:
		teselas[clave][capa]["mmi"].queue_free()
	teselas.erase(clave)
	centro = Vector2(INF, INF)


func _process(_dt: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var p := Vector2(cam.global_position.x, -cam.global_position.z)
	if p.distance_to(centro) > REHACER:
		rehacer(p)


# el tipo de auto.gd de un auto de la página: por su alto y su largo; entre los de un mismo largo, por su lugar
static func tipo(d: PackedFloat32Array, k: int, capa: String) -> int:
	var alto := d[k + 4]
	if alto > 1.8:
		return Auto.CAMION
	if alto > 1.15:
		return Auto.FURGON
	var l := d[k + 3] * LARGO
	var h := posmod(int(floor(d[k] * 7.0 + d[k + 1] * 13.0)), 6)
	if l < 4.25:
		return Auto.HATCHBACK
	if l < 4.45:
		# los colectivos (sedanes negros con letrero) entre los negros de las calles, uno de cada tres
		return Auto.COLECTIVO if capa == "autos" and d[k + 6] < 0.2 and h < 2 else Auto.SEDAN
	return Auto.SUV if h < 3 else Auto.CAMIONETA


# los autos de cerca alrededor de p (grilla): uno de auto.gd por cada uno de la página a menos de CERCA, y la
# colisión de los que están a menos de CHOQUE
func rehacer(p: Vector2) -> void:
	centro = p
	var lotes := {}  # tipo -> PackedFloat32Array (16 por auto)
	var choca := []  # [Transform3D, Array (Auto.caja), largo]
	var r2 := CERCA * CERCA
	var c2 := CHOQUE * CHOQUE
	for clave in teselas:
		for capa in teselas[clave]:
			var e: Dictionary = teselas[clave][capa]
			var d: PackedFloat32Array = e["d"]
			var ocultos := PackedInt32Array()
			var caja: Rect2 = e["caja"]
			if caja.grow(CERCA).has_point(p):
				for k in range(0, d.size(), N):
					var dx := d[k] - p.x
					var dy := d[k + 1] - p.y
					var q := dx * dx + dy * dy
					if q >= r2:
						continue
					ocultos.append(k / N)
					var t := tipo(d, k, capa)
					if not lotes.has(t):
						lotes[t] = PackedFloat32Array()
					# el camión, al largo de la página; los demás, del suyo
					var largo := d[k + 3] * LARGO / Auto.CAMION_L if t == Auto.CAMION else 1.0
					var x := xf(d, k, false, largo)
					empacar(lotes[t], x, Color(d[k + 6], d[k + 7], d[k + 8]))
					if q < c2:
						choca.append([x, Auto.caja(t), largo])
			if ocultos.size() > 0:
				var b: PackedFloat32Array = e["b"].duplicate()
				for i in ocultos:
					for j in 12:
						b[i * 16 + j] = 0.0
				e["mmi"].multimesh.buffer = b
				e["oculta"] = true
			elif e["oculta"]:
				e["mmi"].multimesh.buffer = e["b"]
				e["oculta"] = false
	n_cerca = 0
	for t in range(Auto.TIPOS):
		var buf: PackedFloat32Array = lotes.get(t, PackedFloat32Array())
		if not cerca.has(t):
			if buf.is_empty():
				continue
			cerca[t] = lote(malla(t))
		var mm: MultiMesh = cerca[t].multimesh
		mm.instance_count = buf.size() / 16
		if buf.size() > 0:
			mm.buffer = buf
		cerca[t].visible = buf.size() > 0
		n_cerca += buf.size() / 16
	cajas_de(choca)


# las cajas de colisión de los autos cercanos (Auto.caja: medio ancho, v de atrás y de adelante, alto; v hacia
# adelante es X local, el costado Z local), desde 0,2 m: el auto girado e inclinado, sin escala (Godot no la quiere en
# una forma; el largo del camión va en el tamaño de la caja)
func cajas_de(choca: Array) -> void:
	while cajas.size() < choca.size():
		var cs := CollisionShape3D.new()
		choques.add_child(cs)
		cajas.append(cs)
	for i in cajas.size():
		var cs := cajas[i]
		cs.disabled = i >= choca.size()
		if cs.disabled:
			continue
		var t: Transform3D = choca[i][0]
		var c: Array = choca[i][1]
		var largo: float = choca[i][2]
		var tam := Vector3((c[2] - c[1]) * largo, c[3] - 0.2, c[0] * 2.0)
		var k := "%.2f/%.2f/%.2f" % [tam.x, tam.y, tam.z]
		if not formas.has(k):
			formas[k] = BoxShape3D.new()
			formas[k].size = tam
		cs.shape = formas[k]
		var b := t.basis.orthonormalized()
		cs.transform = Transform3D(b, t.origin + b * Vector3((c[1] + c[2]) / 2.0 * largo, (c[3] + 0.2) / 2.0, 0.0))


func lote(mesh: Mesh) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add_child(mmi)
	return mmi


# el auto de cerca de un tipo, en un marco con el origen en el suelo y v hacia adelante (X de Godot): la carrocería en
# alfa 0, con Mat.tinte (el color de la instancia); el vidrio, el de siempre
static func malla(t: int) -> ArrayMesh:
	var m := Malla.new()
	m.solido = false
	var f := Malla.Marco.new(0, 0, 0)
	Auto.modelo(m, f, t, Auto.NEGRO_COLECTIVO if t == Auto.COLECTIVO else Auto.PINTURA)
	var am := m.malla()
	for s in am.get_surface_count():
		var mat := am.surface_get_material(s)
		for nombre in ["pintura", "metal"]:
			if mat == Mat.patron(nombre):
				am.surface_set_material(s, Mat.tinte(nombre))
	return am


# el auto de la página (carGeo de 60-streets.js) a escala 1: la carrocería de 4,5 × 0,8 × 1,8 m y encima la cabina,
# con sus costados en un tono oscuro (las ventanas) y su techo del color del auto
static func auto_lejos() -> ArrayMesh:
	var m := Malla.new()
	m.solido = false
	var f := Malla.Marco.new(0, 0, 0)
	m.caja(f, -0.9, -2.25, 0.9, 2.25, 0.0, 0.8, Auto.PINTURA, "pintura")
	m.caja(f, -0.74, -1.35, 0.74, 0.85, 0.8, 1.3, Color(0.2, 0.23, 0.28), "pintura", Auto.PINTURA)
	var am := m.malla()
	am.surface_set_material(0, Mat.tinte("pintura"))
	return am
