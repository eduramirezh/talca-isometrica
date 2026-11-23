# Los faroles de noche de toda la comuna. La página tiene tres clases (lamps() de src/js/84-lights.js): las lámparas de
# los hitos (GLOW, con su poste en la geometría: mapa/indice.json «luces», que ambiente.gd pasa a fijas()), las de la
# Alameda (ALAM_LAMPS, con poste) y las de las calles, una cada 35 m en las de clase 3 o menos dentro del área urbana,
# de las que la página dibuja solo el brillo, sobre el eje de la calle a 6 m. Las dos últimas las escribe
# tools/export.py --faroles en mapa/t_<i>_<j>.json (__exLamps de tools/export.js: «faroles», el pie del poste en la
# vereda a 0,45 m de la solera y su brazo hacia la calle; «luces», las de la Alameda), y mapa.gd las pone tesela por
# tesela.
#
# En cada tesela: los postes de las calles (un MultiMesh: base, poste, brazo y luminaria, ~90 triángulos, y la lámpara
# emisiva, encendida de noche, en una segunda superficie) y el brillo de cada farol (shaders/brillo.gdshader: un punto de luz de al menos
# PIXELES en la pantalla, como el de la página, que de lejos no se pierde entre los píxeles). Luz de verdad solo en los
# LUCES faroles más cercanos a la cámara (de las calles, la Alameda y los hitos): un grupo fijo de OmniLight3D que se
# reasignan cada REVISAR segundos; cada una se desvanece antes de la distancia del último elegido, así que una luz que
# cambia de farol ya no se ve. Con una luz por farol serían ~5.900 (y ~660 de los hitos, que ambiente.gd ponía hasta
# noviembre de 2026, todas en la escena y apagadas solo por distancia).
#
# Los recortes de los modelos que nombran «veredas», o ninguna capa, quitan los faroles cuyo pie cae dentro (los de las
# calles de la plaza: calles.gd pone los suyos). Sin colisión (el poste mide 16 cm).
#
#   --sin luces   sin las luces de verdad (solo lámparas y brillo), para medir cuánto cuestan con --fps
extends Node3D

const Args := preload("res://args.gd")
const Malla := preload("res://malla.gd")
const Mat := preload("res://materiales.gd")
const BRILLO := preload("res://shaders/brillo.gdshader")
const ALTO := 6.0  # m: la lámpara sobre el pie del poste (la página: E + 6 en el eje)
const LUCES := 32  # luces de verdad
const RADIO := 160.0  # m: más allá ninguna (como el distance_fade de las de los hitos, 160 + 40)
const REVISAR := 0.25  # s
const POSTES := 500.0  # m: hasta aquí los postes (los de lejos no se distinguen; la lámpara y el brillo siguen)
const COLOR_LUZ := Color(1.0, 0.78, 0.5)

var teselas := {}  # clave -> {"nodos": [MultiMeshInstance3D], "lamparas": PackedVector3Array (Godot)}
var brillos: Array[MultiMeshInstance3D] = []  # se dibujan solo de noche (de día serían llamadas de más)
var fijas := PackedVector3Array()  # las lámparas de los hitos (ambiente.gd)
var luces: Array[OmniLight3D] = []
var asignada := {}  # índice de luz -> la lámpara (Vector3) que alumbra
var k_noche := 0.0
var t_revisar := 0.0
var con_luces := true
var mallas := {}
var mat_brillo: ShaderMaterial
var mat_lampara: StandardMaterial3D
var n_lamparas := 0


func _ready() -> void:
	name = "faroles"
	con_luces = not ("luces" in Args.sin_())
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	mallas["brillo"] = q
	mat_brillo = ShaderMaterial.new()
	mat_brillo.shader = BRILLO
	mat_lampara = StandardMaterial3D.new()
	mat_lampara.albedo_color = Color(1.0, 0.92, 0.75)
	mat_lampara.emission_enabled = true
	mat_lampara.emission = Color(1.0, 0.8, 0.55)
	mat_lampara.emission_energy_multiplier = 0.0
	mallas["poste"] = poste(mat_lampara)
	for i in LUCES if con_luces else 0:
		var f := OmniLight3D.new()
		f.light_color = COLOR_LUZ
		f.omni_range = 16.0
		f.omni_attenuation = 1.4
		f.shadow_enabled = false
		f.light_energy = 0.0
		f.visible = false
		f.distance_fade_enabled = true
		add_child(f)
		luces.append(f)


# en un hilo (mapa.gd): los faroles de una tesela sin los que quitan los recortes: las transformaciones de los postes
# (12 números) y, de cada farol, dónde va la lámpara
static func preparar(datos: Dictionary, recs: Array) -> Dictionary:
	if not (datos.has("faroles") or datos.has("luces")):
		return {}
	var pols := []
	for r in recs:
		var capas: Array = r.get("capas", [])
		if capas.is_empty() or "veredas" in capas:
			pols.append(r["poligono"])
	var fuera := func(x: float, y: float) -> bool:
		for pol in pols:
			if Geometry2D.is_point_in_polygon(Vector2(x, y), pol):
				return false
		return true
	var postes := PackedFloat32Array()
	var lamparas := PackedVector3Array()
	var a: Array = datos.get("faroles", [])
	for k in range(0, a.size() - 5, 6):
		if not fuera.call(a[k], a[k + 1]):
			continue
		var t := Transform3D(Basis(Vector3.UP, atan2(a[k + 4], a[k + 3])), Vector3(a[k], a[k + 2], -a[k + 1]))
		var s := t.basis
		postes.append_array([s.x.x, s.y.x, s.z.x, t.origin.x, s.x.y, s.y.y, s.z.y, t.origin.y, s.x.z, s.y.z, s.z.z, t.origin.z])
		lamparas.append(t * Vector3(a[k + 5], ALTO, 0.0))
	var l: Array = datos.get("luces", [])
	for k in range(0, l.size() - 2, 3):
		if fuera.call(l[k], l[k + 1]):
			lamparas.append(Vector3(l[k], l[k + 2], -l[k + 1]))
	if lamparas.is_empty():
		return {}
	return {"postes": postes, "lamparas": lamparas}


# en el hilo principal: los postes, las lámparas y los brillos de una tesela
func agregar(clave: String, prep: Dictionary) -> void:
	quitar(clave)
	var nodos := []
	var postes: PackedFloat32Array = prep["postes"]
	if postes.size() > 0:
		var mm := multimesh(mallas["poste"], postes.size() / 12)
		mm.buffer = postes
		nodos.append(instancia(mm, POSTES, true))
	var lamparas: PackedVector3Array = prep["lamparas"]
	var b := PackedFloat32Array()
	for p in lamparas:
		b.append_array([1, 0, 0, p.x, 0, 1, 0, p.y, 0, 0, 1, p.z])
	var mm := multimesh(mallas["brillo"], lamparas.size())
	mm.buffer = b
	nodos.append(brillo(mm))
	teselas[clave] = {"nodos": nodos, "lamparas": lamparas}
	n_lamparas += lamparas.size()
	t_revisar = 0.0


func quitar(clave: String) -> void:
	if not teselas.has(clave):
		return
	for n in teselas[clave]["nodos"]:
		brillos.erase(n)
		n.queue_free()
	n_lamparas -= teselas[clave]["lamparas"].size()
	teselas.erase(clave)
	t_revisar = 0.0


func multimesh(mesh: Mesh, n: int) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = n
	return mm


func instancia(mm: MultiMesh, hasta: float, sombra: bool) -> MultiMeshInstance3D:
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.visibility_range_end = hasta
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if sombra else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	return mmi


# las lámparas de los hitos (ambiente.gd, de Glb.luces(), sin las que reemplazan los modelos): solo luz de verdad, la
# lámpara la pone ambiente.gd; aquí, además, su brillo
func poner_fijas(ps: Array[Vector3]) -> void:
	fijas = PackedVector3Array(ps)
	if ps.is_empty():
		return
	var mm := multimesh(mallas["brillo"], ps.size())
	for i in ps.size():
		mm.set_instance_transform(i, Transform3D(Basis(), ps[i]))
	brillo(mm)
	t_revisar = 0.0


func brillo(mm: MultiMesh) -> MultiMeshInstance3D:
	var mmi := instancia(mm, 0.0, false)
	mmi.material_override = mat_brillo
	mmi.extra_cull_margin = 20.0  # el cuadrado crece en la pantalla: que no lo recorte la caja de la tesela
	mmi.visible = k_noche > 0.3
	brillos.append(mmi)
	return mmi


# de ambiente.gd poner_hora(): 0 de día, 1 de noche
func noche(k: float) -> void:
	k_noche = k
	mat_lampara.emission_energy_multiplier = 6.0 * k
	for b in brillos:
		b.visible = k > 0.3
	for f in luces:
		f.light_energy = 2.5 * k
		f.visible = k > 0.3 and asignada.has(luces.find(f))
	t_revisar = 0.0


func _process(dt: float) -> void:
	t_revisar -= dt
	if t_revisar > 0.0 or luces.is_empty():
		return
	t_revisar = REVISAR
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	if k_noche <= 0.3:
		if not asignada.is_empty():
			asignada.clear()
			for f in luces:
				f.visible = false
		return
	repartir(cam.global_position)


# las LUCES lámparas más cercanas a c (Godot) a menos de RADIO: las que ya tenían luz la conservan; las otras luces
# van a las nuevas. Todas se desvanecen antes de la distancia del último elegido
func repartir(c: Vector3) -> void:
	var cand := []  # [distancia², lámpara]
	var r2 := RADIO * RADIO
	for p in fijas:
		var q := c.distance_squared_to(p)
		if q < r2:
			cand.append([q, p])
	var g := Vector2(c.x, -c.z)
	for clave in teselas:
		var t: Dictionary = teselas[clave]
		var lp: PackedVector3Array = t["lamparas"]
		if lp.is_empty() or Vector2(lp[0].x, -lp[0].z).distance_to(g) > RADIO + 800.0:
			continue
		for p in lp:
			var q := c.distance_squared_to(p)
			if q < r2:
				cand.append([q, p])
	cand.sort_custom(func(a, b): return a[0] < b[0])
	if cand.size() > LUCES:
		cand.resize(LUCES)
	var lejos_ := RADIO if cand.size() < LUCES else sqrt(cand[-1][0])
	var quedan := {}
	for e in cand:
		quedan[e[1]] = true
	var libres := []
	for i in luces.size():
		if asignada.has(i) and quedan.has(asignada[i]):
			quedan.erase(asignada[i])
		else:
			asignada.erase(i)
			libres.append(i)
	for p in quedan:
		var i: int = libres.pop_back()
		asignada[i] = p
		luces[i].position = p
	for i in luces.size():
		var f := luces[i]
		f.visible = asignada.has(i)
		f.distance_fade_begin = maxf(lejos_ - 40.0, 10.0)
		f.distance_fade_length = 35.0


# el poste de una calle en su marco (X hacia la calle): una base, el poste de 6,3 m, el brazo de BRAZO (1,6 m) y la
# luminaria, de fierro gris, y bajo ella la lámpara (otra superficie, con el material lampara: emisiva de noche)
static func poste(lampara: Material) -> ArrayMesh:
	var m := Malla.new()
	m.solido = false
	var f := Malla.Marco.new(0, 0, 0)
	var gris := Color(0.42, 0.44, 0.45)
	m.caja(f, -0.16, -0.16, 0.16, 0.16, 0.0, 0.45, Color(0.5, 0.5, 0.49), "metal")
	m.cilindro(f, 0.0, 0.0, 0.08, 0.45, ALTO + 0.35, gris, "metal", 6)
	m.caja(f, -0.04, 0.0, 0.04, 1.45, ALTO + 0.18, ALTO + 0.26, gris, "metal")
	m.caja(f, -0.15, 1.3, 0.15, 1.9, ALTO + 0.02, ALTO + 0.22, Color(0.3, 0.31, 0.32), "metal")
	var am := m.malla()
	var l := Malla.new()
	l.solido = false
	l.caja(f, -0.12, 1.35, 0.12, 1.85, ALTO - 0.04, ALTO + 0.02, Color.WHITE, "", null, true)
	l.malla(lampara, am)
	return am
