# Las fachadas de cerca de los edificios de toda la comuna: lo que no es la plaza (modelos/fachadas.gd) tenía en el
# glb una caja de un color con la grilla de ventanas del sombreador (capa.gdshader) en cada muro, también en las
# medianeras. Aquí cada edificio de la página (cityGen y los de OSM y de aprendizaje automático: f_<i>_<j>.json, que
# escribe `make modelo3d` con tools/export.py --fachadas, __exFach de tools/export.js) se viste según su tipo, 5 cm
# delante de sus muros: una piel de su color que tapa la grilla genérica, y en los lados a la calle sus vanos.
#
# Los tipos (el campo t, que la página saca de su receta de barrio, su estilo de manzana y las etiquetas de OSM; ver
# FACH en src/js/50-city.js) son los de Talca, sin fotos de cada casa: un catálogo de patrones que se repiten.
#   adobe        la casa antigua de fachada continua del centro y los barrios viejos: zócalo pintado, ventanas altas
#                con reja de fierro, el portón del zaguán de madera, cornisa; las medianeras sin vanos
#   continua     fachada continua de albañilería (uno o dos pisos, techo plano): puerta, ventanas anchas, a veces un
#                portón de garaje metálico, pretil
#   local        el comercio: la planta baja es la vitrina de la página (shopFront); arriba, ventanas
#   poblacion    la casa aislada de un piso de las poblaciones: puerta, una o dos ventanas con protecciones (rejas),
#                la reja del antejardín con su portón
#   pareada      dos casas bajo un techo, cada una con su color, su puerta junto a la medianera y su reja
#   fila         casas de dos pisos en hilera
#   condominio   casas de dos pisos de los condominios, sin reja propia (el condominio cierra afuera)
#   block        el block de departamentos de tres o cuatro pisos (SERVIU): ventanas en pares por piso
#   edificio, torre, institucional   ventanas regulares por piso, bandas de losa en las torres, un acceso vidriado
#   galpon       planchas metálicas, un portón grande y una banda de luz arriba
# El color de muro y techo es el de la página (el glb debajo es el mismo); lo demás (dónde va la puerta, cuántas
# ventanas, el color de rejas y marcos) sale de una semilla por edificio (s), siempre igual.
#
# Por celdas de CELDA m: las que caen a menos de CERCA de la cámara se arman en hilos (WorkerThreadPool) y se sueltan
# pasado SOLTAR; cada una se deja de dibujar a VISTA m (más lejos queda la caja del glb, con su grilla de ventanas).
# Un edificio cuyo centro cae en un recorte de las capas edificios o ciudad (los modelos propios: la plaza) no se viste.
# Sin colisión ni sombra (sale 5 a 20 cm de los muros, que ya la tienen). --sin fachadas lo apaga.
extends Node3D

const Malla := preload("res://malla.gd")
const Mat := preload("res://materiales.gd")
const DIR := "res://mapa/"
const CELDA := 125.0
const CERCA := 280.0  # m de la cámara al borde de la celda
const SOLTAR := 420.0
const VISTA := 250.0
const HILOS := 2
const MATS := ["liso", "ladrillo", "metal", "pintura", "ventana", "granito", "hormigon"]

const REJAS := ["262626", "262626", "2f4a3a", "e6e6df", "5f6366", "4a3426", "1f3550"]
const MARCOS := ["eeede8", "eeede8", "b9bdc0", "6b4a30", "3e5a46", "e2dccd"]
const PUERTAS := ["6a4428", "5a3a22", "7a7d80", "dcd8cf", "2f5a45", "8a5a33", "3d4a5c"]
const VIDRIO := Color("4a5864")  # el vidrio de día: refleja el cielo

var mapa: Node3D  # mapa.gd: foco, tam, teselas, recs
var celdas := {}  # "cx_cy" -> Node3D armado (o null: vacía)
var tareas := {}  # id -> clave de celda
var hechas := []
var cerrojo := Mutex.new()
var cache := {}  # "i_j" de la tesela -> {"cx_cy": [edificios]} (en hilos, con cerrojo_t)
var cerrojo_t := Mutex.new()
var recs := []  # los polígonos de los recortes de edificios y ciudad
var esp := {}  # config/fachadas.json (modelo3d/datos/): lo medido en fotos de un edificio de OSM, por su id (w…)
var t_revisar := 0.0
var stats := {"celdas": 0, "edificios": 0, "triangulos": 0, "ms": 0}


func _ready() -> void:
	name = "fachadas_ciudad"
	for m in MATS:
		Mat.patron(m)  # en el hilo principal: los hilos solo los leen
	for r in mapa.recs:
		var cs: Array = r["capas"]
		if "edificios" in cs or "ciudad" in cs:
			recs.append(r["poligono"])
	var f := FileAccess.open("res://datos/fachadas.json", FileAccess.READ)
	if f:
		var d: Variant = JSON.parse_string(f.get_as_text())
		if d is Dictionary:
			for k in d:
				if String(k).begins_with("w"):
					esp[String(k)] = d[k]


func _process(dt: float) -> void:
	recoger()
	t_revisar -= dt
	if t_revisar > 0.0:
		return
	t_revisar = 0.3
	if mapa.foco.x != INF:
		revisar(mapa.foco)


func caja(clave: String) -> Rect2:
	var p := clave.split("_")
	return Rect2(int(p[0]) * CELDA, int(p[1]) * CELDA, CELDA, CELDA)


static func dist(c: Rect2, p: Vector2) -> float:
	return Vector2(clampf(p.x, c.position.x, c.end.x), clampf(p.y, c.position.y, c.end.y)).distance_to(p)


# las celdas a menos de r de p que caen en una tesela con edificios, de la más cercana a la más lejana
func cerca_de(p: Vector2, r: float) -> Array:
	var out := []
	for cy in range(floori((p.y - r) / CELDA), floori((p.y + r) / CELDA) + 1):
		for cx in range(floori((p.x - r) / CELDA), floori((p.x + r) / CELDA) + 1):
			var k := "%d_%d" % [cx, cy]
			if dist(caja(k), p) > r:
				continue
			var t: Dictionary = mapa.teselas.get(tesela(k), {})
			if int(t.get("fachadas", 0)) > 0:
				out.append(k)
	out.sort_custom(func(a, b): return dist(caja(a), p) < dist(caja(b), p))
	return out


func tesela(celda: String) -> String:
	var c := caja(celda).get_center()
	return "%d_%d" % [floori(c.x / mapa.tam), floori(c.y / mapa.tam)]


func revisar(p: Vector2) -> void:
	for k in celdas.keys():
		if dist(caja(k), p) > SOLTAR:
			if celdas[k]:
				celdas[k].queue_free()
			celdas.erase(k)
	# la caché de las teselas sin celdas cerca
	cerrojo_t.lock()
	for t in cache.keys():
		var c := Rect2(int(t.split("_")[0]) * mapa.tam, int(t.split("_")[1]) * mapa.tam, mapa.tam, mapa.tam)
		if dist(c, p) > SOLTAR + CELDA:
			cache.erase(t)
	cerrojo_t.unlock()
	for k in cerca_de(p, CERCA):
		if tareas.size() >= HILOS:
			break
		if celdas.has(k) or k in tareas.values():
			continue
		var f := func():
			var r := armar(k)
			cerrojo.lock()
			hechas.append([k, r])
			cerrojo.unlock()
		tareas[WorkerThreadPool.add_task(f, false, "fachadas %s" % k)] = k


func recoger() -> void:
	for id in tareas.keys():
		if WorkerThreadPool.is_task_completed(id):
			WorkerThreadPool.wait_for_task_completion(id)
			tareas.erase(id)
	cerrojo.lock()
	var l := hechas
	hechas = []
	cerrojo.unlock()
	for h in l:
		var nodo: Node3D = h[1]
		if mapa.foco.x != INF and dist(caja(h[0]), mapa.foco) > SOLTAR:
			if nodo:
				nodo.free()
			continue
		if nodo:
			add_child(nodo)
		celdas[h[0]] = nodo


# si están todas las celdas que pide la cámara (mapa.gd listo(), para las capturas)
func listo(p: Vector2) -> bool:
	if not tareas.is_empty():
		return false
	for k in cerca_de(p, CERCA):
		if not celdas.has(k):
			return false
	return true


# ---------------------------------------------------------------- en un hilo

# los edificios de la tesela, por celda (una vez por tesela)
func edificios_de(celda: String) -> Array:
	var t := tesela(celda)
	cerrojo_t.lock()
	if not cache.has(t):
		var por := {}
		var f := DIR + "f_%s.json" % t
		if FileAccess.file_exists(f):
			var j: Variant = JSON.parse_string(FileAccess.get_file_as_string(f))
			if j is Array:
				for e in j:
					var q := PackedVector2Array()
					for p in e["q"]:
						q.append(Vector2(p[0], p[1]))
					if q.size() < 3:
						continue
					var c := Vector2.ZERO
					for p in q:
						c += p
					c /= q.size()
					if recortado(c):
						continue
					e["Q"] = q
					var k := "%d_%d" % [floori(c.x / CELDA), floori(c.y / CELDA)]
					if not por.has(k):
						por[k] = []
					por[k].append(e)
		cache[t] = por
	var out: Array = cache[t].get(celda, [])
	cerrojo_t.unlock()
	return out


func recortado(c: Vector2) -> bool:
	for pol in recs:
		if Geometry2D.is_point_in_polygon(c, pol):
			return true
	return false


func armar(celda: String) -> Node3D:
	var t0 := Time.get_ticks_msec()
	var lista := edificios_de(celda)
	if lista.is_empty():
		return null
	var a := Armador.new()
	a.esp = esp
	for e in lista:
		a.edificio(e)
	if a.m.tris == 0:
		return null
	var am := ArrayMesh.new()
	for m in a.m.capas:
		var c: Array = a.m.capas[m]
		if c[0].is_empty():
			continue
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = c[0]
		arr[Mesh.ARRAY_NORMAL] = c[1]
		arr[Mesh.ARRAY_COLOR] = c[2]
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		am.surface_set_material(am.get_surface_count() - 1, Mat.patron(m))
	var mi := MeshInstance3D.new()
	mi.name = "f_" + celda
	mi.mesh = am
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = VISTA
	mi.visibility_range_end_margin = 20.0
	cerrojo.lock()
	stats["celdas"] += 1
	stats["edificios"] += lista.size()
	stats["triangulos"] += a.m.tris
	stats["ms"] += Time.get_ticks_msec() - t0
	cerrojo.unlock()
	return mi


# ---------------------------------------------------------------- un edificio

class Muro:
	var a: Vector2
	var d: Vector2  # a lo largo
	var o: Vector2  # hacia afuera
	var L: float
	var N: Vector3

	func _init(p: Vector2, q: Vector2, afuera: Vector2) -> void:
		a = p
		L = p.distance_to(q)
		d = (q - p) / L
		o = afuera
		N = Vector3(o.x, 0, -o.y)

	func W(s: float, h: float, off: float) -> Vector3:
		var g := a + d * s + o * off
		return Vector3(g.x, h, -g.y)


class Armador:
	const P := 0.05  # la piel, delante del muro
	var m := Malla.new()
	var r := RandomNumberGenerator.new()
	var esp := {}
	var zoc := ""  # el color del zócalo medido en fotos (frente())
	var pb := ""  # la planta baja medida en fotos: vitrinas o vidrio (frente())
	# el estilo de config/fachadas.json (el de modelos/fachadas.gd) -> el tipo de aquí
	const ESTILO := {"colonial": "adobe", "clasico": "continua", "comercial": "continua", "deco": "edificio",
		"torre": "torre", "vidrio": "torre", "municipal": "institucional", "intendencia": "institucional", "moderno": "edificio"}

	func _init() -> void:
		m.solido = false

	func hx(s: String, def := "d8cfbf") -> Color:
		return Color(s if s != "" else def)

	func pick(a: Array) -> Color:
		return Color(a[r.randi() % a.size()])

	# un rectángulo en el muro, a off m de él
	func rect(w: Muro, s0: float, s1: float, h0: float, h1: float, off: float, col: Color, mat := "liso") -> void:
		if s1 - s0 < 0.01 or h1 - h0 < 0.01:
			return
		m.cara([w.W(s0, h0, off), w.W(s1, h0, off), w.W(s1, h1, off), w.W(s0, h1, off)], col, mat, w.N)

	# una caja adosada (cornisa, alféizar, marquesina): de off0 a off1 del muro
	func saliente(w: Muro, s0: float, s1: float, h0: float, h1: float, off0: float, off1: float, col: Color, mat := "liso") -> void:
		rect(w, s0, s1, h0, h1, off1, col, mat)
		m.cara([w.W(s0, h1, off0), w.W(s0, h1, off1), w.W(s1, h1, off1), w.W(s1, h1, off0)], col.lightened(0.06), mat, Vector3.UP)
		m.cara([w.W(s0, h0, off1), w.W(s0, h0, off0), w.W(s1, h0, off0), w.W(s1, h0, off1)], col.darkened(0.25), mat, Vector3.DOWN)
		var dn := Vector3(w.d.x, 0, -w.d.y)
		m.cara([w.W(s1, h0, off0), w.W(s1, h0, off1), w.W(s1, h1, off1), w.W(s1, h1, off0)], col.darkened(0.1), mat, dn)
		m.cara([w.W(s0, h0, off1), w.W(s0, h0, off0), w.W(s0, h1, off0), w.W(s0, h1, off1)], col.darkened(0.1), mat, -dn)

	# una ventana centrada en s: marco, vidrio (encendido de noche o no), travesaño, alféizar y, si se pide, su reja
	func ventana(w: Muro, s: float, ancho: float, h0: float, alto: float, marco: Color, reja: Variant = null, hojas := 2) -> void:
		var s0 := s - ancho / 2
		var s1 := s + ancho / 2
		rect(w, s0 - 0.1, s1 + 0.1, h0 - 0.1, h0 + alto + 0.1, P + 0.03, marco)
		var v := VIDRIO
		v.a = 1.0 if r.randf() < 0.35 else 0.6
		rect(w, s0 + 0.03, s1 - 0.03, h0 + 0.03, h0 + alto - 0.03, P + 0.045, v, "ventana")
		if hojas > 1:
			rect(w, s - 0.035, s + 0.035, h0, h0 + alto, P + 0.06, marco)
		saliente(w, s0 - 0.15, s1 + 0.15, h0 - 0.16, h0 - 0.04, P, P + 0.14, marco.darkened(0.08))
		if reja != null:
			var c: Color = reja
			var n := maxi(3, roundi(ancho / 0.13))
			for i in range(1, n):
				var x := s0 + ancho * i / n
				rect(w, x - 0.018, x + 0.018, h0, h0 + alto, P + 0.12, c, "metal")
			for y in [h0 + 0.08, h0 + alto - 0.08, h0 + alto * 0.55]:
				rect(w, s0, s1, y - 0.02, y + 0.02, P + 0.125, c, "metal")

	# una puerta en s (de abajo, h0): una hoja o dos, con su marco
	func puerta(w: Muro, s: float, ancho: float, h0: float, alto: float, col: Color, marco: Color, dos := false) -> void:
		rect(w, s - ancho / 2 - 0.1, s + ancho / 2 + 0.1, h0, h0 + alto + 0.1, P + 0.03, marco)
		rect(w, s - ancho / 2, s + ancho / 2, h0, h0 + alto, P + 0.05, col, "pintura")
		if dos:
			rect(w, s - 0.02, s + 0.02, h0, h0 + alto, P + 0.06, col.darkened(0.35), "pintura")
		# los tableros, un tono más oscuro
		var k := 2 if dos else 1
		for i in k:
			var a0 := s - ancho / 2 + ancho * i / k
			var a1 := a0 + ancho / k
			rect(w, a0 + 0.12, a1 - 0.12, h0 + 0.25, h0 + alto * 0.45, P + 0.06, col.darkened(0.15), "pintura")
			rect(w, a0 + 0.12, a1 - 0.12, h0 + alto * 0.55, h0 + alto - 0.2, P + 0.06, col.darkened(0.15), "pintura")
		var pomo := s + (0.0 if dos else ancho / 2 - 0.15)
		rect(w, pomo - 0.03, pomo + 0.03, h0 + 1.0, h0 + 1.08, P + 0.08, Color("c9b27a"), "metal")

	# un portón metálico (de garaje o de galpón): plancha con nervios horizontales
	func porton(w: Muro, s0: float, s1: float, h0: float, alto: float, col: Color) -> void:
		rect(w, s0, s1, h0, h0 + alto, P + 0.04, col, "metal")
		var y := h0 + 0.3
		while y < h0 + alto - 0.1:
			rect(w, s0 + 0.05, s1 - 0.05, y - 0.03, y + 0.03, P + 0.06, col.darkened(0.2), "metal")
			y += 0.3

	# la reja del antejardín de a a b, con pilares y un portón; mira a los dos lados
	func reja_antejardin(a: Vector2, b: Vector2, h0: float, col: Color, pilar: Color) -> void:
		var L := a.distance_to(b)
		if L < 2.0:
			return
		var d := (b - a) / L
		var o := Vector2(d.y, -d.x)
		var alto := 1.6 + r.randf() * 0.3
		for lado in [Muro.new(a, b, o), Muro.new(b, a, -o)]:
			var w: Muro = lado
			# los barrotes, cada 0,16 m, y dos travesaños
			var n := roundi(L / 0.16)
			for i in range(1, n):
				var x := L * i / n
				rect(w, x - 0.02, x + 0.02, h0, h0 + alto, 0.02, col, "metal")
			for y in [h0 + 0.12, h0 + alto - 0.1]:
				rect(w, 0, L, y - 0.03, y + 0.03, 0.04, col, "metal")
		# los pilares, cada ~3 m (albañilería, del color de la casa o blancos)
		var np := maxi(1, roundi(L / 3.0))
		var wa := Muro.new(a, b, o)
		for i in range(np + 1):
			var x := clampf(L * i / np, 0.15, L - 0.15)
			saliente(wa, x - 0.15, x + 0.15, h0 - 0.3, h0 + alto + 0.15, -0.15, 0.15, pilar, "liso")

	# ---------------------------------------------------------------- por tipo

	func edificio(e: Dictionary) -> void:
		var q: PackedVector2Array = e["Q"]
		r.seed = hash(int(e.get("s", 0)) * 2654435761 + q.size())
		var t := String(e.get("t", ""))
		var b := float(e["b"])
		var h := float(e["h"])
		var top := h + float(e.get("ph", 0.0))
		var p := maxi(1, int(e.get("p", 1)))
		var col := hx(String(e.get("w", "")))
		var cw := Geometry2D.is_polygon_clockwise(q)
		var front := []  # los índices llegan del JSON como decimales: `in` no los iguala a un entero
		for x in e.get("f", []):
			front.append(int(x))
		var shops := []
		for x in e.get("l", []):
			shops.append(int(x))
		var k := String(e.get("k", "f"))
		var rh := float(e.get("rh", 0.0))
		var continua := t in ["adobe", "continua", "local"]
		var aislada := not continua
		# sin lado a la calle (las casas que dan a un pasaje interior de una villa): la puerta en el lado más largo
		var puerta_en := -1
		if front.is_empty() and aislada:
			var mejor := 0.0
			for i in q.size():
				var L := q[i].distance_to(q[(i + 1) % q.size()])
				if L > mejor:
					mejor = L
					puerta_en = i
		var marco := pick(MARCOS)
		var reja_col := pick(REJAS)
		var zocalo := ""
		# lo medido en fotos (config/fachadas.json): el tipo, los pisos, los colores; el alto ya viene de la página
		var fa: Dictionary = esp.get(String(e.get("id", "")), {})
		if not fa.is_empty():
			t = ESTILO.get(String(fa.get("estilo", "")), t)
			if t == "continua" and int(fa.get("pisos", p)) >= 3:
				t = "edificio"
			p = int(fa.get("pisos", p))
			if fa.has("color"):
				col = hx(String(fa["color"]))
			if fa.has("marco"):
				marco = hx(String(fa["marco"]))
			zocalo = String(fa.get("zocalo", ""))
		pb = String(fa.get("pb", "")) if not fa.is_empty() else ""
		var con_reja: bool = r.randf() < {"adobe": 0.9, "poblacion": 0.85, "pareada": 0.7, "fila": 0.55, "condominio": 0.15,
			"continua": 0.6, "local": 0.3}.get(t, 0.0)
		for i in q.size():
			var a := q[i]
			var c := q[(i + 1) % q.size()]
			if a.distance_to(c) < 0.6:
				continue
			# hacia afuera: a la derecha de a -> c en un polígono antihorario
			var d := (c - a).normalized()
			var o := Vector2(d.y, -d.x) * (-1.0 if cw else 1.0)
			var w := Muro.new(a, c, o)
			var calle := i in front or i == puerta_en
			var tienda := i in shops
			if tienda and calle and (pb == "vitrinas" or pb == "vidrio"):
				# la planta baja medida en fotos reemplaza la vitrina genérica de la página (6 cm fuera del muro):
				# una piel más afuera la tapa
				tienda = false
				rect(w, 0, w.L, b - 0.6, b + 3.6, P + 0.025, col)
			# la piel: de bajo el suelo al alero (o al pretil); en una pareada, cada mitad de su color
			var h0 := b - 0.6
			if tienda:
				if p <= 1:
					continue  # la vitrina, el letrero y el pretil de la página
				h0 = b + 3.45
			var cols := [[0.0, w.L, col]]
			if e.has("m") and e.has("w2"):
				var mp := Vector2(e["m"][0], e["m"][1])
				var sm := (mp - a).dot(w.d)
				if sm > 0.5 and sm < w.L - 0.5 and absf((mp - a).dot(w.o)) < 1.0:
					cols = [[0.0, sm, col], [sm, w.L, hx(String(e["w2"]))]]
			for cc in cols:
				rect(w, cc[0], cc[1], h0, b + top, P, cc[2], "metal" if t == "galpon" else "liso")
			# el hastial
			if rh > 0.05 and q.size() == 4 and ((k == "g" and i % 2 == 1) or (k == "x" and i % 2 == 0)):
				m.cara([w.W(0, b + h, P), w.W(w.L, b + h, P), w.W(w.L / 2, b + h + rh - 0.04, P)], col, "liso", w.N)
			if calle:
				zoc = zocalo
				frente(t, w, b, h, p, col, marco, reja_col if con_reja else null, tienda, cols)
			else:
				lado(t, w, b, h, p, marco, reja_col if con_reja else null)
		if e.has("c"):
			var c0 := Vector2(e["c"][0][0], e["c"][0][1])
			var c1 := Vector2(e["c"][1][0], e["c"][1][1])
			if t in ["poblacion", "pareada", "fila"] and r.randf() < 0.85:
				reja_antejardin(c0, c1, b, reja_col, col if r.randf() < 0.6 else Color("e8e6df"))

	# un lado a la calle
	func frente(t: String, w: Muro, b: float, h: float, p: int, col: Color, marco: Color, reja: Variant, tienda: bool, cols: Array) -> void:
		var L := w.L
		if (pb == "vitrinas" or pb == "vidrio") and not tienda and L > 4.0:
			# la planta baja de las fotos: vanos vidriados entre pilares del color del marco (un cuartel de bomberos,
			# un hotel); arriba, ventanas por piso
			var hg := minf(3.6, h / p if p > 1 else h - 0.6)
			var n := maxi(1, roundi(L / (6.0 if pb == "vitrinas" else 4.0)))
			for i in n + 1:
				var x := clampf(L * i / n, 0.4, L - 0.4)
				saliente(w, x - 0.4, x + 0.4, b - 0.6, b + hg + 0.3, P, P + 0.12, marco)
			for i in n:
				var v := VIDRIO
				v.a = 1.0
				rect(w, L * i / n + 0.45, L * (i + 1) / n - 0.45, b, b + hg, P + 0.04, v, "ventana")
				for k in range(1, 4):
					rect(w, L * i / n + 0.45, L * (i + 1) / n - 0.45, b + hg * k / 4 - 0.03, b + hg * k / 4 + 0.03, P + 0.06, Color("2b2b2b"), "metal")
			saliente(w, 0, L, b + hg + 0.3, b + hg + 0.5, P, P + 0.15, col.lightened(0.15))
			if p > 1:
				var hu := (h - hg - 0.5) / (p - 1)
				var nv := maxi(1, roundi(L / 3.0))
				for f in range(p - 1):
					for i in nv:
						ventana(w, L * (i + 0.5) / nv, minf(1.6, L / nv - 0.5), b + hg + 0.5 + f * hu + 0.7, minf(1.4, hu - 1.0), marco, null, 2)
			saliente(w, 0, L, b + h - 0.12, b + h + 0.06, P, P + 0.12, col.lightened(0.2))
			return
		match t:
			"adobe":
				# zócalo, vanos altos cada ~3,4 m, el portón del zaguán, la cornisa
				var zc := col.darkened(0.35) if r.randf() < 0.6 else Color(["8c7b6a", "6e4538", "7d8580", "5d5a52"][r.randi() % 4])
				if zoc != "":
					zc = Color(zoc)
				rect(w, 0, L, b - 0.6, b + 0.9, P + 0.02, zc)
				var hp := (h - 0.4) / p
				var n := maxi(1, roundi(L / 3.4))
				var zaguan := r.randi() % n if L > 5.0 else -1
				var madera := pick(PUERTAS)
				for i in n:
					var s := L * (i + 0.5) / n
					if i == zaguan:
						puerta(w, s, minf(1.6, L / n - 0.6), b, minf(2.9, hp - 0.5), madera, marco.darkened(0.1), true)
					else:
						ventana(w, s, minf(1.05, L / n - 0.8), b + 0.95, minf(1.9, hp - 1.45), marco, reja, 2)
					for f in range(1, p):
						ventana(w, s, minf(1.0, L / n - 0.8), b + f * hp + 0.6, minf(1.8, hp - 1.2), marco, null, 2)
						rect(w, s - 0.6, s + 0.6, b + f * hp + 0.6, b + f * hp + 1.5, P + 0.14, reja if reja != null else Color("262626"), "metal")
				saliente(w, 0, L, b + h - 0.45, b + h - 0.1, P, P + 0.22, col.lightened(0.25))
				saliente(w, 0, L, b + h - 0.7, b + h - 0.55, P, P + 0.1, col.lightened(0.18))
			"continua", "local":
				var hp := (h - 0.5) / p
				if zoc != "":
					rect(w, 0, L, b - 0.6, b + 0.9, P + 0.02, Color(zoc))
				var desde := 1
				if not tienda:
					desde = 0
				var n := maxi(1, roundi(L / 3.8))
				for f in range(desde, p):
					for i in n:
						var s := L * (i + 0.5) / n
						if f == 0:
							if i == 0 and L > 5.0:
								puerta(w, s, 1.0, b, 2.2, pick(PUERTAS), marco)
							elif i == n - 1 and n > 2 and r.randf() < 0.3:
								porton(w, s - 1.3, s + 1.3, b, 2.3, Color(["8a8d90", "5f6366", "e2e0da"][r.randi() % 3]))
							else:
								ventana(w, s, minf(1.6, L / n - 0.8), b + 1.0, 1.3, marco, reja, 2)
						else:
							ventana(w, s, minf(1.4, L / n - 0.8), b + f * hp + 0.85, minf(1.4, hp - 1.2), marco, null, 2)
				saliente(w, 0, L, b + h - 0.12, b + h + 0.06, P, P + 0.12, col.lightened(0.2))
				if p >= 2:
					for f in range(1, p):
						saliente(w, 0, L, b + f * hp - 0.08, b + f * hp + 0.08, P, P + 0.06, col.lightened(0.12))
			"poblacion", "condominio", "fila":
				var hp := h / p
				var dpos := 0.25 + r.randf() * 0.5 if L > 4.0 else 0.5
				var sd := clampf(L * dpos, 0.8, L - 0.8)
				puerta(w, sd, 0.9, b + 0.15, 2.05, pick(PUERTAS), marco)
				# una o dos ventanas en lo que queda
				var huecos := []
				if sd - 0.6 > 1.6:
					huecos.append([0.2, sd - 0.6])
				if L - sd - 0.6 > 1.6:
					huecos.append([sd + 0.6, L - 0.2])
				for hq in huecos:
					var ancho := minf(1.6, hq[1] - hq[0] - 0.4)
					if ancho > 0.6:
						ventana(w, (hq[0] + hq[1]) / 2, ancho, b + 1.0, 1.1, marco, reja, 2)
				for f in range(1, p):
					var k := maxi(1, roundi(L / 3.2))
					for i in k:
						ventana(w, L * (i + 0.5) / k, minf(1.2, L / k - 0.6), b + f * hp + 0.85, 1.0, marco, null, 2)
			"pareada":
				# dos casas: la puerta de cada una junto a la medianera (el cambio de color), la ventana afuera
				var hp := h / p
				for cc in cols:
					var s0: float = cc[0]
					var s1: float = cc[1]
					var junto := s1 if cc == cols[0] and cols.size() > 1 else s0
					var sd := clampf(junto + (-1.1 if junto == s1 else 1.1), s0 + 0.6, s1 - 0.6)
					if s1 - s0 < 2.5:
						continue
					puerta(w, sd, 0.9, b + 0.15, 2.05, pick(PUERTAS), marco)
					var sv := (s0 + sd - 0.5) / 2 if junto == s1 else (sd + 0.5 + s1) / 2
					var ancho := minf(1.5, absf(sv - sd) * 2 - 1.4)
					if ancho > 0.6:
						ventana(w, sv, ancho, b + 1.0, 1.1, marco, reja, 2)
					for f in range(1, p):
						ventana(w, (s0 + s1) / 2, minf(1.4, s1 - s0 - 1.0), b + f * hp + 0.85, 1.0, marco, null, 2)
			"galpon":
				var pw := minf(L * 0.5, 4.5)
				var s := L * (0.3 + r.randf() * 0.4)
				porton(w, s - pw / 2, s + pw / 2, b, minf(4.5, h - 1.2), Color(["8a8d90", "6f7a6e", "b3aa96", "4d5560"][r.randi() % 4]))
				if L > pw + 3:
					puerta(w, s + pw / 2 + 1.2 if s + pw / 2 + 2 < L else s - pw / 2 - 1.2, 0.9, b, 2.1, Color("6f7276"), Color("6f7276"))
				var v := VIDRIO.lightened(0.35)
				v.a = 0.6
				rect(w, 0.3, L - 0.3, b + h - 1.3, b + h - 0.5, P + 0.03, v, "ventana")
			"block":
				pisos(w, b, h, p, marco, 2.8, 1.2, 1.15, true)
				puerta(w, L / 2, 1.2, b + 0.1, 2.2, Color("7a5a3a"), marco)
			"edificio", "torre", "institucional":
				pisos(w, b, h, p, marco, 2.6 if t == "torre" else 3.2, 1.6 if t == "institucional" else 1.4, 1.5 if t != "torre" else 1.7, t == "torre")
				var v := VIDRIO
				v.a = 1.0
				var aw := minf(2.6, L * 0.4)
				rect(w, L / 2 - aw / 2, L / 2 + aw / 2, b, b + 2.6, P + 0.05, v, "ventana")
				saliente(w, L / 2 - aw / 2 - 0.6, L / 2 + aw / 2 + 0.6, b + 2.8, b + 3.0, P, P + 1.4, Color("d8d6d0"), "hormigon")
			_:
				lado(t, w, b, h, p, marco, reja)

	# una grilla de ventanas por piso (bloques y edificios), desde el segundo piso o desde el primero
	func pisos(w: Muro, b: float, h: float, p: int, marco: Color, cada: float, ancho: float, alto: float, bandas: bool) -> void:
		var hp := clampf(h / p, 2.5, 4.2)
		var n := maxi(1, roundi(w.L / cada))
		for f in p:
			var y := b + f * hp
			if y + alto + 0.8 > b + h:
				break
			for i in n:
				var s := w.L * (i + 0.5) / n
				if f == 0 and absf(s - w.L / 2) < 2.0:
					continue  # el acceso
				ventana(w, s, minf(ancho, w.L / n - 0.5), y + 0.9, alto, marco, null, 2)
			if bandas and f > 0:
				saliente(w, 0, w.L, y - 0.12, y + 0.08, P, P + 0.1, Color("e4e2dc"), "hormigon")

	# un lado que no da a la calle: en las casas aisladas, una ventana por piso cada ~4 m; en las de fachada
	# continua, la medianera lisa
	func lado(t: String, w: Muro, b: float, h: float, p: int, marco: Color, reja: Variant) -> void:
		if t in ["adobe", "continua", "local"] or w.L < 2.5:
			return
		if t == "galpon":
			return
		if t in ["block", "edificio", "torre", "institucional"]:
			pisos(w, b, h, p, marco, 3.2, 1.2, 1.2, t == "torre")
			return
		var hp := h / p
		var n := mini(3, maxi(1, floori(w.L / 4.0)))
		for f in p:
			for i in n:
				if r.randf() < 0.25:
					continue
				ventana(w, w.L * (i + 0.5) / n, minf(1.0, w.L / n - 0.8), b + f * hp + 1.0, 0.9, marco, reja if f == 0 else null, 1)
