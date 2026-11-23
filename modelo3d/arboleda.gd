# Los árboles del mapa: las capas «arboles» y «alamos» de la página (treeGeo de src/js/80-trees.js: la copa redonda
# y el álamo), que tools/export.py --instancias escribe como datos en mapa/t_<i>_<j>.json (x, y, altura del pie, escala
# horizontal y vertical, giro y tinte de cada uno; __exInst de tools/export.js). Los pone mapa.gd, tesela por tesela.
#
# Cerca de la cámara (CERCA) son los árboles de la plaza (modelos/plaza/arboles.gd: el «frondoso» por la copa redonda y
# el «alamo» por el álamo, tres variantes de cada uno elegidas por el lugar, con follaje en tarjetas que se mece con el
# viento), del alto que tiene cada uno en la página. Más lejos, una copa redonda de pocas caras deformada con ruido (la
# misma idea que ambiente.gd copas() para los icosaedros del glb) y un tronco, con el material de la capa «arboles»
# (materiales.gd) y el tinte de la página. Cada tesela tiene un MultiMesh de copas por capa; los árboles de cerca van en
# un MultiMesh por variante, que se rehace cuando la cámara se mueve REHACER metros: los que entran ahí se esconden en el
# de su tesela (su transformación en cero). Así nunca se dibujan los dos.
#
# Sin colisión, como en el glb (los árboles se atraviesan). Los recortes de los modelos (modelos/*.gd, recortes()) que
# nombran la capa, o ninguna, quitan los árboles cuyo pie cae dentro (preparar()).
extends Node3D

const Arboles := preload("res://modelos/plaza/arboles.gd")
const Mat := preload("res://materiales.gd")
const N := 9  # números por árbol en los datos
const CERCA := 130.0  # m: hasta aquí, los árboles de la plaza
const REHACER := 15.0  # m que se mueve la cámara antes de volver a elegir los de cerca
const LEJOS := 1400.0  # m: más allá no se dibujan las copas (la niebla deja ~20 %)
const ESPECIE := {"arboles": "frondoso", "alamos": "alamo"}
const TOPE := {"arboles": 8.8, "alamos": 11.7}  # el alto de la página a escala 1 (treeGeo: la copa, el cono)

var arb: Arboles
var teselas := {}  # clave -> {capa: {"d": PackedFloat32Array (N por árbol), "b": PackedFloat32Array (16 por árbol), "caja": Rect2 de grilla, "mmi": MultiMeshInstance3D, "oculta": bool}}
var cerca := {}  # "capa/variante" -> [MultiMeshInstance3D, MultiMeshInstance3D (sombra)]
var alto_var := {}  # "capa/variante" -> el alto de la malla de la plaza
var centro := Vector2(INF, INF)
var copas := {}  # capa -> Mesh: la copa de lejos
var n_cerca := 0


func _ready() -> void:
	name = "arboleda"
	copas["arboles"] = copa_lejos(false)
	copas["alamos"] = copa_lejos(true)


# en un hilo (mapa.gd): los datos de una tesela ({capa: Array de números}) sin lo que quitan los recortes, y los búferes
# de sus copas de lejos (MultiMesh: 12 números de la transformación y 4 del color por instancia)
static func preparar(datos: Dictionary, recs: Array) -> Dictionary:
	var out := {}
	for capa in datos:
		if not ESPECIE.has(capa):  # los autos y faroles del mismo archivo (autos.gd, faroles.gd)
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
			for j in N:
				d.append(a[k + j])
			var bs := Basis(Vector3.UP, a[k + 5]).scaled(Vector3(a[k + 3], a[k + 4], a[k + 3]))
			var c := Color(a[k + 6], a[k + 7], a[k + 8]).srgb_to_linear()
			b.append_array([bs.x.x, bs.y.x, bs.z.x, a[k], bs.x.y, bs.y.y, bs.z.y, a[k + 2], bs.x.z, bs.y.z, bs.z.z, -a[k + 1], c.r, c.g, c.b, 1.0])
		if d.size() > 0:
			out[capa] = {"d": d, "b": b, "caja": caja}
	return out


# en el hilo principal: las copas de lejos de una tesela (lo que dio preparar())
func agregar(clave: String, prep: Dictionary) -> void:
	quitar(clave)
	var t := {}
	for capa in prep:
		var e: Dictionary = prep[capa]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = copas[capa]
		mm.instance_count = e["d"].size() / N
		mm.buffer = e["b"]
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = Mat.capa("arboles", "arbol")
		mmi.visibility_range_end = LEJOS
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


# los árboles de cerca alrededor de p (grilla): uno de la plaza por cada uno de la página a menos de CERCA
func rehacer(p: Vector2) -> void:
	centro = p
	if arb == null:
		arb = Arboles.new()
	var lotes := {}  # "capa/variante" -> PackedFloat32Array (16 por árbol)
	var r2 := CERCA * CERCA
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
					if dx * dx + dy * dy < r2:
						ocultos.append(k / N)
						var v := posmod(int(floor(d[k] * 7.0 + d[k + 1] * 13.0)), Arboles.VARIANTES)
						var lk := "%s/%d" % [capa, v]
						if not lotes.has(lk):
							lotes[lk] = PackedFloat32Array()
						var s: float = TOPE[capa] * d[k + 4] / alto(capa, v)  # del alto de la página
						var bs := Basis(Vector3.UP, d[k + 5]).scaled(Vector3.ONE * s)
						lotes[lk].append_array([bs.x.x, bs.y.x, bs.z.x, d[k], bs.x.y, bs.y.y, bs.z.y, d[k + 2] - 0.1, bs.x.z, bs.y.z, bs.z.z, -d[k + 1],
							d[k + 6], d[k + 7], d[k + 8], 1.0])
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
	var claves := cerca.duplicate()
	claves.merge(lotes)
	for lk in claves:
		var buf: PackedFloat32Array = lotes.get(lk, PackedFloat32Array())
		if not cerca.has(lk):
			var capa: String = lk.get_slice("/", 0)
			var v := int(lk.get_slice("/", 1))
			var especie: String = ESPECIE[capa]
			cerca[lk] = [lote(arb.malla(especie, v), GeometryInstance3D.SHADOW_CASTING_SETTING_OFF),
				lote(arb.sombra(especie, v), GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY)]
		for mmi in cerca[lk]:
			var mm: MultiMesh = mmi.multimesh
			mm.instance_count = buf.size() / 16
			if buf.size() > 0:
				mm.buffer = buf
			mmi.visible = buf.size() > 0
		n_cerca += buf.size() / 16


func alto(capa: String, v: int) -> float:
	var k := "%s/%d" % [capa, v]
	if not alto_var.has(k):
		alto_var[k] = maxf(arb.malla(ESPECIE[capa], v).get_aabb().end.y, 1.0)
	return alto_var[k]


func lote(mesh: Mesh, sombra: GeometryInstance3D.ShadowCastingSetting) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = sombra
	add_child(mmi)
	return mmi


# La copa de lejos, en las medidas de la página a escala 1 (treeGeo): una esfera de 80 caras (radio 3,2 m, centro a
# 5,4 m; el álamo, un huso de 1,6 m de radio entre 2,7 y 11,7 m) deformada con ruido, con normales que salen de su centro
# (la luz la redondea como una masa de hojas), y un tronco de cinco caras. El color, el de la página (lineal, como el glb)
func copa_lejos(alamo: bool) -> ArrayMesh:
	var ruido := FastNoiseLite.new()
	ruido.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	ruido.frequency = 0.9
	ruido.seed = 35 if alamo else 36
	var verde := (Color(0.42, 0.56, 0.28) if alamo else Color(0.40, 0.54, 0.27)).srgb_to_linear()
	var corteza := Color(0.42, 0.33, 0.25).srgb_to_linear()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var c := Vector3(0, 7.2 if alamo else 5.4, 0)
	var esc := Vector3(1.6, 4.5, 1.6) if alamo else Vector3(3.2, 3.36, 3.2)
	for tri in icosfera():
		var q := []
		for v: Vector3 in tri:
			var d: Vector3 = v * (1.0 + 0.22 * ruido.get_noise_3dv(v * 2.0))
			if alamo:
				d.x *= 1.0 - 0.55 * maxf(d.y, 0.0)  # más angosto arriba
				d.z *= 1.0 - 0.55 * maxf(d.y, 0.0)
			q.append([c + d * esc, (v * 0.8 + Vector3.UP * 0.2).normalized()])
		for k in [0, 2, 1]:
			st.set_color(verde)
			st.set_normal(q[k][1])
			st.add_vertex(q[k][0])
	var h := 3.0 if alamo else 2.8
	for i in 5:
		var a0 := TAU * i / 5.0
		var a1 := TAU * (i + 1) / 5.0
		var p0 := Vector3(cos(a0), 0, sin(a0))
		var p1 := Vector3(cos(a1), 0, sin(a1))
		var n := ((p0 + p1) / 2.0).normalized()
		for v in [p0 * 0.4, p1 * 0.3 + Vector3.UP * h, p0 * 0.3 + Vector3.UP * h, p0 * 0.4, p1 * 0.4, p1 * 0.3 + Vector3.UP * h]:
			st.set_color(corteza)
			st.set_normal(n)
			st.add_vertex(v + Vector3.DOWN * 0.3)
	return st.commit()


# una esfera de radio 1: un icosaedro con cada cara partida en cuatro (80 triángulos, en sentido antihorario desde afuera)
static func icosfera() -> Array:
	var t := (1.0 + sqrt(5.0)) / 2.0
	var v := [Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0), Vector3(0, -1, t), Vector3(0, 1, t),
		Vector3(0, -1, -t), Vector3(0, 1, -t), Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]
	var f := [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6],
		[7, 1, 8], [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9], [4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]]
	var out := []
	for k in f:
		var a: Vector3 = v[k[0]].normalized()
		var b: Vector3 = v[k[1]].normalized()
		var c: Vector3 = v[k[2]].normalized()
		var ab := (a + b).normalized()
		var bc := (b + c).normalized()
		var ca := (c + a).normalized()
		out.append_array([[a, ab, ca], [b, bc, ab], [c, ca, bc], [ab, bc, ca]])
	return out
