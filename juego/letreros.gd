# Los letreros con el nombre de las calles, en los cruces de toda la comuna. tools/export.py --letreros los escribe en
# mapa/t_<i>_<j>.json (__exSigns de tools/export.js: uno por cruce de dos calles de nombre distinto en el área urbana,
# en una de sus esquinas, a 0,45 m de las dos soleras; «letreros», once números por letrero, y «nombres», sus rótulos)
# y mapa.gd los pone tesela por tesela, como los faroles. La página no los dibuja: una placa de 24 cm se pierde en su
# píxel de arte de 0,5 m.
#
# Cómo son: el letrero del centro de Talca en las fotos de Wikimedia Commons de 2005 a 2017 (docs/FUENTES.md: «Talca 1
# sur.jpg», 2005, 1 Sur con 1 Oriente, la más legible; «Talca04.jpg», 2011, y «TalcaNavidad17 (62).jpg», 2017, 1 Sur
# con 7 Oriente; «1 Sur 4 Oriente.jpg», 2014): un poste delgado verde muy oscuro con una perilla arriba y, a unos
# 2,7 m, una placa por calle, negra con un borde blanco de esquinas redondeadas y dos líneas de letra blanca: el nombre
# («1 ORIENTE») y la numeración de la cuadra («1199 - 1101»); junto al poste, en las calles de un sentido, un módulo
# cuadrado con la flecha del tránsito. Cada placa sale del poste por la vereda de su calle, paralela a ella: la placa
# de una calle la lee quien llega por la otra. Lo aproximado: el color (las fotos son chicas y lavadas: negro o verde
# muy oscuro), los tamaños (de la proporción en las fotos y la altura de la gente), las esquinas redondeadas (aquí
# rectas), la letra (la de Godot), que todos sean de este tipo (en los barrios y las avenidas nuevas hay otros: tres
# líneas «CALLE / 5 NORTE / 718», o una flecha grande con el nombre chico) y la numeración fuera del centro (solo entre
# calles numeradas hasta la 10, donde la grilla es regular: pipeline/geocode.py).
#
# En cada tesela: los postes, las placas y los módulos de flecha (uno por sentido), cada uno un MultiMesh. El texto
# (Label3D, que no va en un MultiMesh) solo en los ROTULOS letreros más cercanos a la cámara a menos de RADIO: un grupo
# fijo de Label3D que se reasigna cada REVISAR segundos, como las luces de faroles.gd; con uno por cara de cada placa
# serían ~18.000. Los recortes de los modelos que nombran «veredas», o ninguna capa, quitan los letreros cuyo poste cae
# dentro: calles.gd pone los suyos alrededor de la plaza, con poste(), placa(), flecha() y texto() de aquí. Sin
# colisión (el poste mide 7 cm).
#
#   --sin letreros   sin los letreros de la comuna (quedan los de calles.gd), para medir cuánto cuestan con --fps
extends Node3D

const Args := preload("res://args.gd")
const Malla := preload("res://malla.gd")
const ALTO := 2.7  # m: el centro de las placas sobre la vereda
const ANCHO := 0.24  # m: el alto de la placa (y el lado del módulo de la flecha)
const LARGO := 0.62  # m: el largo de la placa del nombre (en las fotos, ~2,5 veces su alto)
const GROSOR := 0.02
const DESDE := 0.045  # m: del eje del poste al módulo de la flecha
const PLACA := DESDE + ANCHO + 0.025  # m: del eje del poste a la placa del nombre (después del módulo)
const R_POSTE := 0.035
const ROTULOS := 24  # letreros con texto
const RADIO := 45.0  # m: más allá, las placas sin texto (a 45 m una letra de 8 cm mide ~2 píxeles)
const REVISAR := 0.25  # s
const POSTES := 350.0  # m: hasta aquí los postes y las placas
const C_FONDO := Color(0.06, 0.075, 0.07)
const C_BORDE := Color(0.9, 0.9, 0.88)
const C_LETRA := Color(0.95, 0.95, 0.93)
const C_POSTE := Color(0.08, 0.11, 0.09)

var teselas := {}  # clave -> {"nodos": [MultiMeshInstance3D], "letreros": Array de [pie (Godot), [dir, rótulo], [dir, rótulo]]}
var mallas := {}
var etiquetas: Array = []  # ROTULOS grupos de cuatro Label3D: las dos caras de las dos placas
var asignado := {}  # índice del grupo -> el pie (Vector3) del letrero que rotula
var t_revisar := 0.0
var apagados := false  # --sin letreros: para medir cuánto cuestan con --fps


func _ready() -> void:
	name = "letreros"
	apagados = "letreros" in Args.sin_()
	mallas["poste"] = una(func(m, f): poste(m, f))
	mallas["placa"] = una(func(m, f): placa(m, f))
	mallas["ida"] = una(func(m, f): flecha(m, f, 1.0))
	mallas["vuelta"] = una(func(m, f): flecha(m, f, -1.0))
	for i in ROTULOS:
		var g := []
		for k in 4:
			var l := etiqueta()
			l.visible = false
			add_child(l)
			g.append(l)
		etiquetas.append(g)


static func una(dibujar: Callable) -> ArrayMesh:
	var m := Malla.new()
	m.solido = false
	dibujar.call(m, Malla.Marco.new(0, 0, 0))
	return m.malla()


static func etiqueta() -> Label3D:
	var l := Label3D.new()
	l.font_size = 64
	l.modulate = C_LETRA
	l.outline_size = 0
	l.double_sided = false
	l.shaded = true
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.line_spacing = -6
	return l


# en un hilo (mapa.gd): los letreros de una tesela sin los que quitan los recortes: las transformaciones de los postes,
# las placas y los módulos de flecha (12 números cada una) y, de cada letrero, su pie y sus dos placas (dirección y
# rótulo) para el texto
static func preparar(datos: Dictionary, recs: Array) -> Dictionary:
	if not datos.has("letreros"):
		return {}
	var pols := []
	for r in recs:
		var capas: Array = r.get("capas", [])
		if capas.is_empty() or "veredas" in capas:
			pols.append(r["poligono"])
	var a: Array = datos["letreros"]
	var nombres: Array = datos.get("nombres", [])
	var out := {"poste": PackedFloat32Array(), "placa": PackedFloat32Array(), "ida": PackedFloat32Array(),
		"vuelta": PackedFloat32Array(), "letreros": []}
	for k in range(0, a.size() - 10, 11):
		var dentro := false
		for pol in pols:
			if Geometry2D.is_point_in_polygon(Vector2(a[k], a[k + 1]), pol):
				dentro = true
				break
		if dentro:
			continue
		var pie := Vector3(a[k], a[k + 2], -a[k + 1])
		out["poste"].append_array([1, 0, 0, pie.x, 0, 1, 0, pie.y, 0, 0, 1, pie.z])
		var item := [pie]
		for o in [3, 7]:
			var d := Vector2(a[k + o], a[k + o + 1])
			var b := Basis(Vector3.UP, atan2(d.y, d.x))
			var t := [b.x.x, b.y.x, b.z.x, pie.x, b.x.y, b.y.y, b.z.y, pie.y, b.x.z, b.y.z, b.z.z, pie.z]
			out["placa"].append_array(t)
			var s: float = a[k + o + 3]
			if s != 0.0:
				out["ida" if s > 0.0 else "vuelta"].append_array(t)
			var i := int(a[k + o + 2])
			item.append([d, String(nombres[i]) if i < nombres.size() else ""])
		out["letreros"].append(item)
	return out if not out["letreros"].is_empty() else {}


# en el hilo principal: los postes, las placas y las flechas de una tesela
func agregar(clave: String, prep: Dictionary) -> void:
	quitar(clave)
	if apagados:
		return
	var nodos := []
	for k in ["poste", "placa", "ida", "vuelta"]:
		var b: PackedFloat32Array = prep[k]
		if b.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mallas[k]
		mm.instance_count = b.size() / 12
		mm.buffer = b
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.visibility_range_end = POSTES
		add_child(mmi)
		nodos.append(mmi)
	teselas[clave] = {"nodos": nodos, "letreros": prep["letreros"]}
	t_revisar = 0.0


func quitar(clave: String) -> void:
	if not teselas.has(clave):
		return
	for n in teselas[clave]["nodos"]:
		n.queue_free()
	teselas.erase(clave)
	t_revisar = 0.0


func _process(dt: float) -> void:
	t_revisar -= dt
	if t_revisar > 0.0:
		return
	t_revisar = REVISAR
	var cam := get_viewport().get_camera_3d()
	if cam:
		repartir(cam.global_position)


# los ROTULOS letreros más cercanos a c (Godot) a menos de RADIO: los que ya tenían texto lo conservan; los grupos libres
# van a los nuevos
func repartir(c: Vector3) -> void:
	var cand := []  # [distancia², letrero]
	var r2 := RADIO * RADIO
	for clave in teselas:
		for l in teselas[clave]["letreros"]:
			var q := c.distance_squared_to(l[0])
			if q < r2:
				cand.append([q, l])
	cand.sort_custom(func(a, b): return a[0] < b[0])
	if cand.size() > ROTULOS:
		cand.resize(ROTULOS)
	var quedan := {}
	for e in cand:
		quedan[e[1][0]] = e[1]
	var libres := []
	for i in etiquetas.size():
		if asignado.has(i) and quedan.has(asignado[i]):
			quedan.erase(asignado[i])
		else:
			asignado.erase(i)
			libres.append(i)
			for l in etiquetas[i]:
				l.visible = false
	for pie in quedan:
		var i: int = libres.pop_back()
		asignado[i] = pie
		var l: Array = quedan[pie]
		for k in 2:
			var d: Vector2 = l[k + 1][0]
			var f := Malla.Marco.new(pie.x, -pie.z, atan2(d.y, d.x), pie.y)
			for s in 2:
				texto(etiquetas[i][k * 2 + s], f, l[k + 1][1], 1.0 if s == 0 else -1.0)


# el rótulo de la placa del marco f (v a lo largo de la placa, desde el poste) en la etiqueta e, sobre la cara de +u
# (sg = 1) o de -u: «NOMBRE» o «NOMBRE|cerca|lejos» (__exSigns), el nombre en dos líneas si es largo y la numeración
# debajo, con cada número del lado del extremo de la cuadra que le toca, como en la placa de 1 Oriente en 1 Sur
# (2005): «1199 - 1101», con el 1101 junto al poste. e tiene que estar en el árbol (look_at)
static func texto(e: Label3D, f: Malla.Marco, rotulo: String, sg: float) -> void:
	var p := rotulo.split("|")
	var lineas := [partir(p[0])]
	var n := f.N(sg, 0)
	if p.size() == 3:
		var hacia_lejos := Vector3.UP.cross(n).dot(f.N(0, 1)) > 0.0  # la derecha de quien lee va hacia el otro extremo
		lineas.append((p[1] + " - " + p[2]) if hacia_lejos else (p[2] + " - " + p[1]))
	var t := "\n".join(lineas)
	var font: Font = e.font if e.font else ThemeDB.fallback_font
	var w := 1.0
	for linea in t.split("\n"):
		w = maxf(w, font.get_string_size(linea, HORIZONTAL_ALIGNMENT_LEFT, -1, e.font_size).x)
	var filas := t.count("\n") + 1
	# el alto de cada línea, una fracción del de la placa (en la foto de 1 Oriente, 2005, las mayúsculas del nombre miden
	# ~0,3 de su alto); menos si el rótulo es largo y no cabe a lo largo
	var px := minf(ANCHO * 0.8 / filas / e.font_size, (LARGO - 0.08) / w)
	e.text = t
	e.pixel_size = px
	e.position = f.V(sg * (GROSOR / 2 + 0.003), PLACA + LARGO / 2, ALTO)
	e.visible = true
	e.look_at(e.position - n, Vector3.UP)


# un nombre largo en dos líneas, cortado en el espacio más cercano a la mitad
static func partir(t: String) -> String:
	if t.length() <= 12 or not " " in t:
		return t
	var mejor := -1
	for i in t.length():
		if t[i] == " " and (mejor < 0 or absi(i - t.length() / 2) < absi(mejor - t.length() / 2)):
			mejor = i
	return t.substr(0, mejor) + "\n" + t.substr(mejor + 1)


# el poste en su pie: de la vereda hasta sobre las placas, con una perilla
static func poste(m: Malla, f: Malla.Marco) -> void:
	var h := ALTO + ANCHO / 2 + 0.06
	m.cilindro(f, 0.0, 0.0, R_POSTE * 1.5, 0.0, 0.25, C_POSTE, "metal", 8)  # la base
	m.cilindro(f, 0.0, 0.0, R_POSTE, 0.25, h, C_POSTE, "metal", 8)
	m.cilindro(f, 0.0, 0.0, R_POSTE * 1.4, h, h + 0.03, C_POSTE, "metal", 8)
	m.cilindro(f, 0.0, 0.0, R_POSTE * 1.7, h + 0.03, h + 0.1, C_POSTE, "metal", 8)  # la perilla
	m.cilindro(f, 0.0, 0.0, R_POSTE * 0.8, h + 0.1, h + 0.14, C_POSTE, "metal", 8)


# un panel oscuro con un borde claro en sus dos caras, de v0 a v1 a lo largo del marco f
static func panel(m: Malla, f: Malla.Marco, v0: float, v1: float) -> void:
	var h0 := ALTO - ANCHO / 2
	var h1 := ALTO + ANCHO / 2
	m.caja(f, -GROSOR / 2, v0, GROSOR / 2, v1, h0, h1, C_FONDO, "pintura")
	var b := 0.012  # el borde
	var e := 0.012  # su margen desde el canto
	for sg in [1.0, -1.0]:
		var u: float = sg * (GROSOR / 2 + 0.001)
		var n := f.N(sg, 0)
		for r in [[v0 + e, v1 - e, h1 - e - b, h1 - e], [v0 + e, v1 - e, h0 + e, h0 + e + b],
				[v0 + e, v0 + e + b, h0 + e, h1 - e], [v1 - e - b, v1 - e, h0 + e, h1 - e]]:
			m.cara([f.V(u, r[0], r[2]), f.V(u, r[1], r[2]), f.V(u, r[1], r[3]), f.V(u, r[0], r[3])], C_BORDE, "pintura", n)


# la placa del nombre en el marco f (v a lo largo de la placa, desde el poste), con el soporte que la une al poste
# (pasa por donde va el módulo de la flecha, si la calle es de un sentido)
static func placa(m: Malla, f: Malla.Marco) -> void:
	panel(m, f, PLACA, PLACA + LARGO)
	m.caja(f, -0.008, 0.0, 0.008, PLACA + 0.01, ALTO - 0.03, ALTO + 0.03, C_POSTE, "metal")


# el módulo cuadrado de la flecha, junto al poste, con la flecha blanca en sus dos caras hacia +v (s = 1: el tránsito va
# hacia donde apunta la placa) o hacia el poste (s = -1)
static func flecha(m: Malla, f: Malla.Marco, s: float) -> void:
	panel(m, f, DESDE, DESDE + ANCHO)
	var c := DESDE + ANCHO / 2
	var pts := [[-0.065, 0.016], [0.005, 0.016], [0.005, 0.05], [0.07, 0.0], [0.005, -0.05], [0.005, -0.016], [-0.065, -0.016]]
	for sg in [1.0, -1.0]:
		var u: float = sg * (GROSOR / 2 + 0.0015)
		var q := []
		for p in pts:
			q.append(f.V(u, c + s * p[0], ALTO + p[1]))
		# el asta y la punta por separado: cara() triangula en abanico y el contorno de la flecha es cóncavo
		m.cara([q[0], q[1], q[5], q[6]], C_BORDE, "pintura", f.N(sg, 0))
		m.cara([q[2], q[3], q[4]], C_BORDE, "pintura", f.N(sg, 0))
