# Las fachadas de cerca de los edificios de toda la comuna: lo que no es la plaza (modelos/fachadas.gd) tenía en el
# glb una caja de un color con la grilla de ventanas del sombreador (capa.gdshader) en cada muro, también en las
# medianeras. Aquí cada edificio de la página (cityGen y los de OSM y de aprendizaje automático: f_<i>_<j>.json, que
# escribe `make juego` con tools/export.py --fachadas, __exFach de tools/export.js) se viste según su tipo.
#
# Los lados a la calle son una fachada gruesa: un muro de su color 10 a 30 cm delante de la caja (GRUESO, por tipo),
# con los vanos abiertos de verdad (derrames, y el vidrio, la puerta o la vitrina al fondo, a 3 cm de la caja), las
# esquinas a inglete con el lado vecino si también da a la calle (si no, una tapa), su pretil y su colisión (la caja
# queda detrás: sin ella, el personaje que se arrima al muro se hunde en la fachada). Los demás lados, una piel de su
# color 5 cm delante de cada muro, que tapa la grilla genérica (en las casas aisladas, con ventanas planas). Los techos
# inclinados (k: g, x, h) llevan alero: el faldón sigue 0,4–0,5 m afuera con su tapacán y su cielo, a inglete en las
# esquinas de cuatro aguas y con vuelo sobre los hastiales; no donde otro edificio de la tesela está pegado (una fila,
# una pareada de aprendizaje automático, las casas de adobe de fachada continua: vecino()).
#
# Los tipos (el campo t, que la página saca de su receta de barrio, su estilo de manzana y las etiquetas de OSM; ver
# FACH en src/js/50-city.js) son los de Talca, sin fotos de cada casa: un catálogo de patrones que se repiten.
#   adobe, continua, local, edificio de hasta cuatro pisos: el centro (fachada_centro()). El repertorio de la plaza
#                (modelos/fachadas.gd variacion()) y lo medido en las 82 fachadas de alrededor de ella
#                (config/fachadas.json, de fotos de Mapillary y Commons, noviembre de 2026): la planta baja de ~3,9 m
#                (las de dos pisos miden 7–9,5 m), bahías de 3,4–4,2 m con una ventana cada una (rectangular, de arco
#                rebajado, con recercado y clave, puertaventana con balconcito, pareada), balcones de fierro al medio o
#                corridos, persianas bajadas, fajas entre pisos, cornisa y pretil con un paño alzado o dados, pilastras en
#                las esquinas; zócalos de 0,85–1,5 m en los colores medidos (ladrillo, café rojizo, azul oscuro, gris
#                verdoso, negro, celeste), marcos verdes, cafés, blancos u ocres; la mayoría de las plantas bajas medidas
#                son de ventanas, no de locales (31 de 42). La casa de adobe, con muros de 30 cm, el
#                portón del zaguán de dos hojas con tableros y montante, ventanas altas con reja. Los locales (lados con
#                local de la página, o pb: vitrinas): vitrinas entre machones, cortinas metálicas (algunas bajadas),
#                el letrero sobre cada local, toldos y letreros de bandera
#   poblacion, pareada, fila, condominio   la casa (fachada_casa()): puerta con montante y a veces su alerito, ventanas de
#                aluminio con protecciones (rejas), la reja del antejardín con su portón; la pareada con su puerta junto
#                a la medianera y cada mitad de su color
#   block, torre, institucional, edificio de cinco pisos o más: ventanas por piso hundidas, bandas de losa, balcones en
#                las torres, un acceso vidriado con marquesina (fachada_altos())
#   galpon       planchas metálicas, un portón grande y una banda de luz arriba
# El color de muro y techo es el de la página (el glb debajo es el mismo); lo demás sale de una semilla por edificio
# (s), siempre igual (estilo(): todos los números en el mismo orden, aunque el tipo no los use).
#
# Por celdas de CELDA m: las que caen a menos de CERCA de la cámara se arman en hilos (WorkerThreadPool) y se sueltan
# pasado SOLTAR; cada una se deja de dibujar a VISTA m (más lejos queda la caja del glb, con su grilla de ventanas).
# Un edificio cuyo centro cae en un recorte de las capas edificios o ciudad (los modelos propios: la plaza) no se viste.
# Da sombra: las rejas sobre la vereda, los aleros, los derrames de los vanos (con la fachada gruesa, 0,1–0,3 ms de GPU
# más que las pieles planas sin sombra de antes, en noviembre de 2026); la colisión, solo el plano de cada fachada
# gruesa. --sin fachadas lo apaga.
extends Node3D

const Malla := preload("res://malla.gd")
const Mat := preload("res://materiales.gd")
const Glb := preload("res://glb.gd")
const DIR := "res://mapa/"
const CELDA := 125.0
const CERCA := 280.0  # m de la cámara al borde de la celda
const SOLTAR := 420.0
const VISTA := 250.0
const HILOS := 2
const INDICE := 20.0  # m: las celdas del índice de plantas de cada tesela (vecino())
const MATS := ["liso", "ladrillo", "metal", "pintura", "ventana", "granito", "hormigon", "tela"]
const TECHO := "@techo"  # los faldones de los aleros: con el material de la capa del glb (sus tejas, su zinc), como el techo

const REJAS := ["262626", "262626", "2f4a3a", "e6e6df", "5f6366", "4a3426", "1f3550"]
const MARCOS := ["eeede8", "eeede8", "b9bdc0", "6b4a30", "3e5a46", "e2dccd"]  # aluminio y PVC de las casas
# los marcos medidos en las fotos del centro (config/fachadas.json: verde, café, blanco, casi negro, ocre, rosado) y el
# rojo de las ventanas de madera de 1 Sur con 2 Oriente
const MARCOS_CENTRO := ["3f6b4a", "6b4a32", "f4f3ef", "3a3a36", "dda55d", "dab6a9", "eeede8", "8a3a2a"]
# los zócalos medidos (ladrillo, cafés rojizos, azul oscuro, gris verdoso, negro, celeste, piedra clara)
const ZOCALOS := ["6e4538", "8f5d42", "9c5a3e", "c8956e", "26305f", "4d5650", "2a2a2a", "5a78a8", "d8d6cf"]
const PUERTAS := ["6a4428", "5a3a22", "7a7d80", "dcd8cf", "2f5a45", "8a5a33", "3d4a5c"]
const LETREROS := ["2f4f6f", "8a2c26", "f2efe6", "2c5a3a", "d9a325", "3b3b3b", "c43c2c", "1d1d1d"]
const TOLDOS := ["7a2e26", "2f5e3e", "3a4f7a", "c9a227", "8a2c26"]
const VIDRIO := Color("4a5864")  # el vidrio de día: refleja el cielo

var mapa: Node3D  # mapa.gd: foco, tam, teselas, recs
var celdas := {}  # "cx_cy" -> Node3D armado (o null: vacía)
var tareas := {}  # id -> clave de celda
var hechas := []
var cerrojo := Mutex.new()
var cache := {}  # "i_j" de la tesela -> {"por": {"cx_cy": [edificios]}, "idx": índice de plantas} (en hilos, con cerrojo_t)
var cerrojo_t := Mutex.new()
var recs := []  # los polígonos de los recortes de edificios y ciudad
var techo_mat: Material  # el de la capa «ciudad» del glb (mapa.gd poner())
var esp := {}  # config/fachadas.json (juego/datos/): lo medido en fotos de un edificio de OSM, por su id (w…)
var t_revisar := 0.0
var stats := {"celdas": 0, "edificios": 0, "triangulos": 0, "ms": 0}


func _ready() -> void:
	name = "fachadas_ciudad"
	for m in MATS:
		Mat.patron(m)  # en el hilo principal: los hilos solo los leen
	techo_mat = Mat.capa("ciudad", Glb.tipo("ciudad"))
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

# los edificios de la tesela, por celda, y el índice de sus plantas (una vez por tesela)
func tesela_de(celda: String) -> Dictionary:
	var t := tesela(celda)
	cerrojo_t.lock()
	if not cache.has(t):
		var por := {}
		var idx := {}
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
					# el índice: la planta en cada celda de INDICE m que toca su caja
					var bb := Rect2(q[0], Vector2.ZERO)
					for p in q:
						bb = bb.expand(p)
					for iy in range(floori(bb.position.y / INDICE), floori(bb.end.y / INDICE) + 1):
						for ix in range(floori(bb.position.x / INDICE), floori(bb.end.x / INDICE) + 1):
							var ki := Vector2i(ix, iy)
							if not idx.has(ki):
								idx[ki] = []
							idx[ki].append(e)
		cache[t] = {"por": por, "idx": idx}
	var out: Dictionary = cache[t]
	cerrojo_t.unlock()
	return out


func recortado(c: Vector2) -> bool:
	for pol in recs:
		if Geometry2D.is_point_in_polygon(c, pol):
			return true
	return false


func armar(celda: String) -> Node3D:
	var t0 := Time.get_ticks_msec()
	var td := tesela_de(celda)
	var lista: Array = td["por"].get(celda, [])
	if lista.is_empty():
		return null
	var a := Armador.new()
	a.esp = esp
	a.idx = td["idx"]
	for e in lista:
		a.edificio(e)
	if a.m.tris == 0:
		return null
	var mi := instancia(a.m, "f_" + celda)
	if not a.choque.is_empty():
		# el plano de las fachadas gruesas (la caja de la tesela queda detrás), armado aquí en el hilo
		var cuerpo := StaticBody3D.new()
		cuerpo.name = "fachadas"
		cuerpo.add_child(Malla.colisionador(Malla.concava(a.choque)))
		mi.add_child(cuerpo)
	cerrojo.lock()
	stats["celdas"] += 1
	stats["edificios"] += lista.size()
	stats["triangulos"] += a.m.tris
	stats["ms"] += Time.get_ticks_msec() - t0
	cerrojo.unlock()
	return mi


# la malla de un constructor, con sus materiales (el de los faldones, el de la capa del glb)
func instancia(m: Malla, nombre: String) -> MeshInstance3D:
	var am := ArrayMesh.new()
	for k in m.capas:
		var c: Array = m.capas[k]
		if c[0].is_empty():
			continue
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = c[0]
		arr[Mesh.ARRAY_NORMAL] = c[1]
		arr[Mesh.ARRAY_COLOR] = c[2]
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		am.surface_set_material(am.get_surface_count() - 1, techo_mat if k == TECHO else Mat.patron(k))
	var mi := MeshInstance3D.new()
	mi.name = nombre
	mi.mesh = am
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	mi.visibility_range_end = VISTA
	mi.visibility_range_end_margin = 20.0
	return mi


# ---------------------------------------------------------------- un edificio

class Muro:
	var a: Vector2
	var d: Vector2  # a lo largo
	var o: Vector2  # hacia afuera
	var L: float
	var N: Vector3
	var D: Vector3  # d en el mundo

	func _init(p: Vector2, q: Vector2, afuera: Vector2) -> void:
		a = p
		L = p.distance_to(q)
		d = (q - p) / L
		o = afuera
		N = Vector3(o.x, 0, -o.y)
		D = Vector3(d.x, 0, -d.y)

	func W(s: float, h: float, off: float) -> Vector3:
		var g := a + d * s + o * off
		return Vector3(g.x, h, -g.y)

	# la normal de un plano que baja hacia afuera con pendiente k (un faldón)
	func faldon(k: float) -> Vector3:
		return (N * k + Vector3.UP).normalized()


class Armador:
	const P := 0.05  # la piel, delante del muro
	const FONDO := 0.03  # el vidrio y las puertas al fondo de los vanos: delante de la caja del glb
	const FONDO_LOCAL := 0.09  # las vitrinas: delante de la vitrina genérica de la página (6 cm)
	const TF := 0.14  # el canto del alero (tapacán)
	# el grueso de la fachada a la calle (del muro de la caja al plano), por tipo
	const GRUESO := {"adobe": 0.3, "continua": 0.22, "local": 0.22, "edificio": 0.2, "poblacion": 0.15, "pareada": 0.15,
		"fila": 0.15, "condominio": 0.15, "block": 0.15, "torre": 0.15, "institucional": 0.18, "galpon": 0.1}
	const ALERO := {"adobe": 0.5, "poblacion": 0.5, "pareada": 0.5, "fila": 0.45, "condominio": 0.5, "block": 0.4}
	# el estilo de config/fachadas.json (el de modelos/fachadas.gd) -> el tipo de aquí
	const ESTILO := {"colonial": "adobe", "clasico": "continua", "comercial": "continua", "deco": "edificio",
		"torre": "torre", "vidrio": "torre", "municipal": "institucional", "intendencia": "institucional", "moderno": "edificio"}

	var m := Malla.new()
	var choque := PackedVector3Array()  # la colisión de las fachadas gruesas
	var r := RandomNumberGenerator.new()
	var esp := {}
	var idx := {}  # el índice de plantas de la tesela (tesela_de())
	var yo: Dictionary  # el edificio que se arma (vecino() lo salta)
	var vanos := []  # los vanos del muro que se arma: [s0, s1, z0, z1, flecha del arco]
	var F := P  # el grueso del muro que se arma
	var sp := {}  # el estilo del edificio que se arma (estilo())

	func _init() -> void:
		m.solido = false

	func hx(s: String, def := "d8cfbf") -> Color:
		return Color(s if s != "" else def)

	# si el punto cae en la planta de otro edificio de la tesela
	func vecino(p: Vector2) -> bool:
		for e in idx.get(Vector2i(floori(p.x / INDICE), floori(p.y / INDICE)), []):
			if not is_same(e, yo) and Geometry2D.is_point_in_polygon(p, e["Q"]):
				return true
		return false

	# ------------------------------------------------------------ primitivas

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
		m.cara([w.W(s1, h0, off0), w.W(s1, h0, off1), w.W(s1, h1, off1), w.W(s1, h1, off0)], col.darkened(0.1), mat, w.D)
		m.cara([w.W(s0, h0, off1), w.W(s0, h0, off0), w.W(s0, h1, off0), w.W(s0, h1, off1)], col.darkened(0.1), mat, -w.D)

	# una banda (zócalo, faja, cornisa) de s0 a s1 que se corta en los vanos que cruza
	func franja(w: Muro, s0: float, s1: float, h0: float, h1: float, off0: float, off1: float, col: Color, mat := "liso") -> void:
		var tramos := [[s0, s1]]
		for v in vanos:
			if v[3] + v[4] <= h0 or v[2] >= h1:
				continue
			var nuevos := []
			for t in tramos:
				if v[1] <= t[0] or v[0] >= t[1]:
					nuevos.append(t)
					continue
				if v[0] > t[0]:
					nuevos.append([t[0], v[0]])
				if v[1] < t[1]:
					nuevos.append([v[1], t[1]])
			tramos = nuevos
		for t in tramos:
			if t[1] - t[0] > 0.05:
				saliente(w, t[0], t[1], h0, h1, off0, off1, col, mat)

	# los puntos (s, z) de un arco rebajado sobre el vano de s0 a s1 que arranca en z y sube f, de izquierda a derecha
	static func arco(s0: float, s1: float, z: float, f: float, n := 6) -> PackedVector2Array:
		var c := (s0 + s1) / 2
		var hw := (s1 - s0) / 2
		var R := (hw * hw + f * f) / (2 * f)
		var cy := z + f - R
		var a0 := acos(clampf(hw / R, -1.0, 1.0))
		var out := PackedVector2Array()
		for i in n + 1:
			var t := lerpf(PI - a0, a0, float(i) / n)
			out.append(Vector2(c + R * cos(t), cy + R * sin(t)))
		return out

	# el plano de una fachada gruesa: de s0 a s1 y de h0 a h1, a off del muro, menos los vanos, en franjas verticales;
	# cols: los tramos de color [[desde, _, color]] (una pareada); los arcos, con sus enjutas
	func plano(w: Muro, s0: float, s1: float, h0: float, h1: float, off: float, cols: Array, mat := "liso") -> void:
		var cortes := [s0, s1]
		for v in vanos:
			cortes.append(clampf(v[0], s0, s1))
			cortes.append(clampf(v[1], s0, s1))
		for c in cols:
			cortes.append(clampf(c[0], s0, s1))
		cortes.sort()
		for i in cortes.size() - 1:
			var a: float = cortes[i]
			var b: float = cortes[i + 1]
			if b - a < 0.005:
				continue
			var mid := (a + b) / 2
			var col: Color = cols[0][2]
			for c in cols:
				if mid >= c[0]:
					col = c[2]
			var tapados := []
			for v in vanos:
				if v[0] <= mid and v[1] >= mid:
					tapados.append([v[2], v[3] + v[4]])
			tapados.sort_custom(func(x, y): return x[0] < y[0])
			var z := h0
			for tp in tapados:
				if tp[0] > z:
					rect(w, a, b, z, minf(tp[0], h1), off, col, mat)
				z = maxf(z, tp[1])
			if z < h1:
				rect(w, a, b, z, h1, off, col, mat)
		for v in vanos:
			if v[4] > 0.0:
				var col: Color = cols[0][2]
				for c in cols:
					if (v[0] + v[1]) / 2 >= c[0]:
						col = c[2]
				var pts := arco(v[0], v[1], v[3], v[4])
				var tope: float = v[3] + v[4]
				var izq := [w.W(v[0], tope, off)]
				var der := [w.W(v[1], tope, off)]
				for k in pts.size():
					if k <= pts.size() / 2:
						izq.append(w.W(pts[k].x, pts[k].y, off))
					if k >= pts.size() / 2:
						der.append(w.W(pts[k].x, pts[k].y, off))
				m.cara(izq, col, mat, w.N)
				m.cara(der, col, mat, w.N)

	# un vano del muro grueso: sus derrames del plano (F) al fondo, el umbral o alféizar, el dintel o el arco
	func vano(w: Muro, s0: float, s1: float, z0: float, z1: float, fondo: float, col: Color, flecha := 0.0, mat := "liso") -> void:
		vanos.append([s0, s1, z0, z1, flecha])
		m.cara([w.W(s0, z0, fondo), w.W(s0, z0, F), w.W(s0, z1, F), w.W(s0, z1, fondo)], col, mat, w.D)
		m.cara([w.W(s1, z0, F), w.W(s1, z0, fondo), w.W(s1, z1, fondo), w.W(s1, z1, F)], col, mat, -w.D)
		m.cara([w.W(s0, z0, fondo), w.W(s1, z0, fondo), w.W(s1, z0, F), w.W(s0, z0, F)], col.lightened(0.08), mat, Vector3.UP)
		if flecha <= 0.0:
			m.cara([w.W(s0, z1, F), w.W(s1, z1, F), w.W(s1, z1, fondo), w.W(s0, z1, fondo)], col.darkened(0.25), mat, Vector3.DOWN)
		else:
			var pts := arco(s0, s1, z1, flecha)
			for k in pts.size() - 1:
				var e := pts[k + 1] - pts[k]
				var n := (w.D * e.y - Vector3.UP * e.x).normalized()  # hacia el centro del arco
				m.cara([w.W(pts[k].x, pts[k].y, F), w.W(pts[k + 1].x, pts[k + 1].y, F), w.W(pts[k + 1].x, pts[k + 1].y, fondo),
					w.W(pts[k].x, pts[k].y, fondo)], col.darkened(0.2), mat, n)

	# el fondo de un vano: un rectángulo (con su arco) a off del muro
	func fondo_de(w: Muro, s0: float, s1: float, z0: float, z1: float, off: float, col: Color, mat: String, flecha := 0.0) -> void:
		if flecha <= 0.0:
			rect(w, s0, s1, z0, z1, off, col, mat)
			return
		var p := [w.W(s0, z0, off), w.W(s1, z0, off)]
		var pts := arco(s0, s1, z1, flecha)
		for k in range(pts.size() - 1, -1, -1):
			p.append(w.W(pts[k].x, pts[k].y, off))
		m.cara(p, col, mat, w.N)

	# ------------------------------------------------------------ vanos

	# una ventana hundida: vano con derrames, el vidrio al fondo (encendido de noche o no), el marco con sus hojas y un
	# travesaño, el alféizar; si se pide, su reja dentro del vano y una persiana bajada hasta la fracción pers del alto
	func ventana(w: Muro, s: float, ancho: float, z0: float, alto: float, marco: Color, reja: Variant = null, hojas := 2,
			flecha := 0.0, pers := -1.0) -> void:
		var s0 := s - ancho / 2
		var s1 := s + ancho / 2
		var z1 := z0 + alto
		vano(w, s0, s1, z0, z1, FONDO, sp["revoque"], flecha)
		var v := VIDRIO
		v.a = 1.0 if r.randf() < 0.35 else 0.6
		fondo_de(w, s0, s1, z0, z1, FONDO + 0.002, v, "ventana", flecha)
		var o := FONDO + 0.02
		var t := 0.06
		for q in [[s0, s1, z0, z0 + t], [s0, s0 + t, z0, z1], [s1 - t, s1, z0, z1], [s0, s1, z1 - t, z1]]:
			rect(w, q[0], q[1], q[2], q[3], o, marco, "pintura")
		if flecha > 0.0:
			rect(w, s0, s1, z1 - 0.03, z1 + 0.03, o, marco, "pintura")  # el travesaño del arranque del arco
		if hojas > 1:
			rect(w, s - 0.03, s + 0.03, z0, z1, o, marco, "pintura")
		var zt := z0 + alto * 0.7 if alto > 1.3 else -1.0
		if zt > 0.0:
			rect(w, s0, s1, zt - 0.025, zt + 0.025, o, marco, "pintura")
		if pers > 0.0:
			# la persiana enrollable, bajada desde el dintel
			var pc: Color = sp["persiana"]
			var zp := z1 - alto * pers
			rect(w, s0, s1, zp, z1, o + 0.012, pc, "metal")
			rect(w, s0, s1, zp, zp + 0.05, o + 0.02, pc.darkened(0.3), "metal")
		saliente(w, s0 - 0.08, s1 + 0.08, z0 - 0.07, z0, F - 0.04, F + 0.07, sp["alfeizar"])
		if reja != null:
			var c: Color = reja
			var n := maxi(3, roundi(ancho / 0.13))
			var oj := minf(F - 0.04, FONDO + 0.12)
			for i in range(1, n):
				var x := s0 + ancho * i / n
				rect(w, x - 0.016, x + 0.016, z0, z1 + flecha * 0.6, oj, c, "metal")
			for y in [z0 + 0.1, z1 - 0.1, z0 + alto * 0.55]:
				rect(w, s0, s1, y - 0.018, y + 0.018, oj + 0.005, c, "metal")

	# una ventana plana sobre la piel (los lados que no dan a la calle de las casas aisladas)
	func ventana_plana(w: Muro, s: float, ancho: float, h0: float, alto: float, marco: Color, reja: Variant = null) -> void:
		var s0 := s - ancho / 2
		var s1 := s + ancho / 2
		rect(w, s0 - 0.08, s1 + 0.08, h0 - 0.08, h0 + alto + 0.08, P + 0.03, marco)
		var v := VIDRIO
		v.a = 1.0 if r.randf() < 0.35 else 0.6
		rect(w, s0, s1, h0, h0 + alto, P + 0.045, v, "ventana")
		saliente(w, s0 - 0.12, s1 + 0.12, h0 - 0.14, h0 - 0.04, P, P + 0.12, marco.darkened(0.08))
		if reja != null:
			var c: Color = reja
			var n := maxi(3, roundi(ancho / 0.13))
			for i in range(1, n):
				var x := s0 + ancho * i / n
				rect(w, x - 0.018, x + 0.018, h0, h0 + alto, P + 0.12, c, "metal")
			for y in [h0 + 0.08, h0 + alto - 0.08]:
				rect(w, s0, s1, y - 0.02, y + 0.02, P + 0.125, c, "metal")

	# una puerta hundida en s (de abajo, z0): una hoja o dos con sus tableros, su marco, y arriba un montante vidriado
	# (o el arco)
	func puerta(w: Muro, s: float, ancho: float, z0: float, alto: float, col: Color, marco: Color, dos := false,
			montante := 0.0, flecha := 0.0) -> void:
		var s0 := s - ancho / 2
		var s1 := s + ancho / 2
		var z1 := z0 + alto
		vano(w, s0, s1, z0 - 0.02, z1, FONDO, sp["revoque"], flecha)
		var zh := z1 - montante  # el alto de las hojas
		if montante > 0.0 or flecha > 0.0:
			var v := VIDRIO
			v.a = 0.6
			fondo_de(w, s0, s1, zh, z1, FONDO + 0.002, v, "ventana", flecha)
			rect(w, s0, s1, zh - 0.04, zh + 0.04, FONDO + 0.02, marco, "pintura")
		rect(w, s0, s1, z0 - 0.02, zh, FONDO + 0.005, col, "pintura")
		var o := FONDO + 0.02
		rect(w, s0, s0 + 0.07, z0, z1, o, marco, "pintura")
		rect(w, s1 - 0.07, s1, z0, z1, o, marco, "pintura")
		if dos:
			rect(w, s - 0.02, s + 0.02, z0, zh, o, col.darkened(0.35), "pintura")
		# los tableros, un tono más oscuro
		var k := 2 if dos else 1
		var ht := zh - z0
		for i in k:
			var a0 := s0 + ancho * i / k
			var a1 := a0 + ancho / k
			rect(w, a0 + 0.13, a1 - 0.13, z0 + 0.22, z0 + ht * 0.42, o, col.darkened(0.16), "pintura")
			rect(w, a0 + 0.13, a1 - 0.13, z0 + ht * 0.52, zh - 0.18, o, col.darkened(0.16), "pintura")
		var pomo := s + (0.08 if dos else ancho / 2 - 0.16)
		rect(w, pomo - 0.03, pomo + 0.03, z0 + 1.0, z0 + 1.08, o + 0.02, Color("c9b27a"), "metal")

	# un portón metálico hundido (de garaje o de galpón): plancha con nervios horizontales
	func porton(w: Muro, s0: float, s1: float, z0: float, alto: float, col: Color, fondo := FONDO) -> void:
		vano(w, s0, s1, z0 - 0.02, z0 + alto, fondo, sp["revoque"])
		rect(w, s0, s1, z0 - 0.02, z0 + alto, fondo + 0.005, col, "metal")
		var y := z0 + 0.3
		while y < z0 + alto - 0.1:
			rect(w, s0 + 0.05, s1 - 0.05, y - 0.03, y + 0.03, fondo + 0.02, col.darkened(0.2), "metal")
			y += 0.3

	# la cortina metálica de un local, bajada de z1 a z0: un paño gris con sus pliegues y la barra de abajo
	func cortina(w: Muro, s0: float, s1: float, z0: float, z1: float, off: float) -> void:
		var c: Color = sp["cortina_col"]
		rect(w, s0, s1, z0, z1, off, c, "metal")
		var h := z1 - 0.3
		while h > z0 + 0.2:
			rect(w, s0, s1, h, h + 0.04, off + 0.006, c.darkened(0.25), "metal")
			h -= 0.45
		rect(w, s0, s1, z0, z0 + 0.08, off + 0.01, Color(0.3, 0.31, 0.32), "metal")

	# un balcón de fierro: la losa bajo h, que sale sal m del plano, el pasamanos y barrotes cada 16 cm al frente
	func balcon(w: Muro, s0: float, s1: float, h: float, sal: float, losa: Color) -> void:
		var c := Color(0.17, 0.18, 0.19)
		saliente(w, s0, s1, h - 0.16, h, F - 0.02, F + sal, losa)
		saliente(w, s0, s1, h + 0.92, h + 0.97, F, F + sal, c, "metal")
		var x := s0 + 0.08
		while x < s1 - 0.04:
			rect(w, x - 0.02, x + 0.02, h, h + 0.92, F + sal - 0.025, c, "metal")
			x += 0.16
		for e in [[s0 + 0.02, -1.0], [s1 - 0.02, 1.0]]:
			# los costados: un paño de barrotes de cada lado
			var sx: float = e[0]
			m.cara([w.W(sx, h, F), w.W(sx, h, F + sal), w.W(sx, h + 0.92, F + sal), w.W(sx, h + 0.92, F)], c, "metal", w.D * e[1])
			m.cara([w.W(sx, h, F + sal), w.W(sx, h, F), w.W(sx, h + 0.92, F), w.W(sx, h + 0.92, F + sal)], c, "metal", -w.D * e[1])

	# un toldo de lona inclinado, de s0 a s1, colgado a h del plano, que sale 1,2 m y baja 0,55 m (liso o a listas)
	func toldo(w: Muro, s0: float, s1: float, h: float, col: Color, rayado := false) -> void:
		var k := maxi(1, roundi((s1 - s0) / 0.5)) if rayado else 1
		var n := w.faldon(0.55 / 1.2)
		for i in k:
			var t0 := lerpf(s0, s1, float(i) / k)
			var t1 := lerpf(s0, s1, float(i + 1) / k)
			var c: Color = col if i % 2 == 0 else Color("efebe0")
			m.cara([w.W(t0, h, F), w.W(t1, h, F), w.W(t1, h - 0.55, F + 1.2), w.W(t0, h - 0.55, F + 1.2)], c, "tela", n)
			m.cara([w.W(t0, h, F), w.W(t0, h - 0.55, F + 1.2), w.W(t1, h - 0.55, F + 1.2), w.W(t1, h, F)], c.darkened(0.3), "tela", -n)
			m.cara([w.W(t0, h - 0.55, F + 1.2), w.W(t1, h - 0.55, F + 1.2), w.W(t1, h - 0.8, F + 1.2), w.W(t0, h - 0.8, F + 1.2)], c.darkened(0.1), "tela", w.N)
		for e in [[s0, -1.0], [s1, 1.0]]:
			m.cara([w.W(e[0], h, F), w.W(e[0], h - 0.55, F + 1.2), w.W(e[0], h - 0.8, F + 1.2)], col.darkened(0.15), "tela", w.D * e[1])

	# un letrero de bandera: una caja angosta perpendicular al plano en s, desde h, con un paño claro en cada cara
	func letrero_bandera(w: Muro, s: float, h: float, fondo: Color) -> void:
		var a2 := w.a + w.d * s
		var b2 := a2 + w.o * (F + 1.1)
		var wb := Muro.new(a2, b2, -w.d)
		var wc := Muro.new(b2, a2, w.d)
		var c := Color(0.2, 0.21, 0.22)
		saliente(wb, F, F + 0.25, h + 0.35, h + 0.45, -0.02, 0.02, c, "metal")  # la ménsula
		saliente(wb, F + 0.15, F + 1.05, h, h + 0.8, -0.05, 0.05, fondo, "pintura")
		var claro := fondo.lightened(0.6) if fondo.get_luminance() < 0.5 else fondo.darkened(0.55)
		rect(wb, F + 0.3, F + 0.9, h + 0.3, h + 0.5, 0.052, claro, "pintura")
		rect(wc, 0.2, 0.8, h + 0.3, h + 0.5, 0.052, claro, "pintura")

	# ------------------------------------------------------------ el edificio

	# lo que varía de un edificio a otro, sacado siempre entero y en el mismo orden de la semilla
	func estilo(t: String, col: Color) -> Dictionary:
		var u := []
		for i in 26:
			u.append(r.randf())
		var trims := ["f1ede3", "f4f1ea", "", "", "8f8778"]
		var centro: bool = t in ["adobe", "continua", "local", "edificio"]
		var s := {
			"hg": 3.9 + lerpf(-0.4, 0.5, u[0]),
			"vent": (["recercado", "recercado", "rebajado", "rect", "alta"] if t == "adobe" else
				["rect", "rect", "rebajado", "alta", "par", "recercado"])[int(u[1] * 5.999) % (5 if t == "adobe" else 6)],
			"vh": lerpf(0.56, 0.7, u[2]),
			"balcon": 0 if u[3] < 0.55 else (1 if u[3] < 0.85 else 2),
			"remate": int(u[4] * 2.999),
			"pretil": lerpf(0.5, 0.9, u[5]),
			"trim": trims[int(u[6] * 4.999)],
			"esquinas": u[7] < 0.5,
			"cortina": lerpf(0.0, 0.45, u[8]),
			"bandera": u[9] < 0.45,
			"bahia": {"adobe": 3.4, "local": 4.2}.get(t, 3.8) * lerpf(0.85, 1.2, u[10]),
			"pilares": ["", "", "8a8780", "5e5a55", "b7b1a5"][int(u[11] * 4.999)],
			"zocalo": u[12] < {"adobe": 0.8, "continua": 0.6, "local": 0.35, "edificio": 0.4}.get(t, 0.2),
			"zocalo_col": Color(ZOCALOS[int(u[13] * 8.999)]) if u[14] < 0.6 else col.darkened(0.32),
			"zocalo_alto": [1.0, 1.0, 1.2, 1.5, 0.9][int(u[15] * 4.999)],
			"marco": Color((MARCOS_CENTRO if centro else MARCOS)[int(u[16] * 7.999) % (8 if centro else 6)]),
			"reja": Color(REJAS[int(u[17] * 6.999)]),
			"puerta": Color(PUERTAS[int(u[18] * 6.999)]),
			"puerta_j": int(u[19] * 97.0),
			"porton": u[20] < 0.25,
			"persianas": u[21] < 0.45,
			"alerito": u[22] < 0.4,
			"montante": u[23] < 0.5,
			"toldo": u[24] < 0.3,
			"recercado": u[25] < 0.4,
			"persiana": Color(["d8d2c4", "efece4", "8a6f55", "b9b4a8"][int(u[0] * 3.999)]),
			"cortina_col": Color(0.6 + u[1] * 0.06, 0.61 + u[1] * 0.06, 0.61 + u[1] * 0.05),
		}
		s["t"] = t
		s["revoque"] = col.darkened(0.14)
		s["alfeizar"] = col.lightened(0.1) if s["trim"] == "" else Color(s["trim"])
		s["trim_col"] = Color(s["trim"]) if s["trim"] != "" else col.lightened(0.08)
		return s

	func edificio(e: Dictionary) -> void:
		yo = e
		var q: PackedVector2Array = e["Q"]
		var n := q.size()
		r.seed = hash(int(e.get("s", 0)) * 2654435761 + n)
		var t := String(e.get("t", ""))
		var b := float(e["b"])
		var H := b + float(e["h"])  # el alero o el techo plano (las alturas de aquí en adelante, absolutas)
		var ph := float(e.get("ph", 0.0))
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
		# lo medido en fotos (config/fachadas.json): el tipo, los pisos, los colores; el alto ya viene de la página
		var fa: Dictionary = esp.get(String(e.get("id", "")), {})
		var pb := String(fa.get("pb", ""))
		if not fa.is_empty():
			t = ESTILO.get(String(fa.get("estilo", "")), t)
			if t == "continua" and int(fa.get("pisos", p)) >= 3:
				t = "edificio"
			p = int(fa.get("pisos", p))
			if fa.has("color"):
				col = hx(String(fa["color"]))
		sp = estilo(t, col)
		if fa.has("marco"):
			sp["marco"] = hx(String(fa["marco"]))
		if fa.has("zocalo"):
			sp["zocalo"] = true
			sp["zocalo_col"] = hx(String(fa["zocalo"]))
			sp["zocalo_alto"] = float(fa.get("zocalo_alto", 1.0))
		if fa.has("toldo"):
			sp["toldo"] = true
		var con_reja: bool = r.randf() < {"adobe": 0.9, "poblacion": 0.85, "pareada": 0.7, "fila": 0.55, "condominio": 0.15,
			"continua": 0.6, "local": 0.3}.get(t, 0.0)
		var reja: Variant = sp["reja"] if con_reja else null
		var centro: bool = t in ["adobe", "continua", "local"] or t == "edificio" and p <= 4
		var aislada: bool = not t in ["adobe", "continua", "local"]
		# sin lado a la calle (las casas que dan a un pasaje interior de una villa): la puerta en el lado más largo
		var puerta_en := -1
		if front.is_empty() and aislada:
			var mejor := 0.0
			for i in n:
				var L := q[i].distance_to(q[(i + 1) % n])
				if L > mejor:
					mejor = L
					puerta_en = i
		# los muros, sus lados a la calle y sus aleros
		var muros := []
		var calle := []
		for i in n:
			var a := q[i]
			var c := q[(i + 1) % n]
			if a.distance_to(c) < 0.05:
				muros.append(null)
				calle.append(false)
				continue
			var d := (c - a).normalized()
			var o := Vector2(d.y, -d.x) * (-1.0 if cw else 1.0)  # hacia afuera: a la derecha de a -> c si es antihorario
			muros.append(Muro.new(a, c, o))
			calle.append(muros[i].L >= 1.5 and (i in front or i in shops or i == puerta_en))
		# el techo: qué muros llevan alero (con su pendiente) y cuáles hastial
		var pend := 0.0
		var aleros := []
		var hastial := []
		aleros.resize(n)
		hastial.resize(n)
		aleros.fill(false)
		hastial.fill(false)
		if rh > 0.05:
			if (k == "g" or k == "x") and n == 4:
				var j := 0 if k == "g" else 1  # los aleros en j y j + 2, los hastiales en los otros
				pend = rh / maxf(0.5, q[(j + 1) % 4].distance_to(q[(j + 2) % 4]) / 2)
				for i in 4:
					aleros[i] = i % 2 == j % 2
					hastial[i] = not aleros[i]
			elif k == "h":
				if e.has("osm"):
					pend = 0.3 if t == "galpon" else 0.5  # el techo truncado de 52-edificios.js: rh = d · 0,5
				elif n == 4:
					pend = rh / maxf(0.5, minf(q[0].distance_to(q[1]), q[1].distance_to(q[2])) / 2)
				for i in n:
					aleros[i] = pend > 0.0
		var vuelo: float = ALERO.get(t, 0.4)
		var libre := []  # el alero (o el vuelo sobre el hastial) de cada muro, si no tiene un vecino pegado
		for i in n:
			var w: Muro = muros[i]
			var ok: bool = w != null and (aleros[i] or hastial[i])
			if ok:
				for f in [0.2, 0.5, 0.8]:
					if vecino(w.a + w.d * (w.L * f) + w.o * 0.35):
						ok = false
						break
			libre.append(ok)
		# el grueso de cada muro y lo que se alarga (o se cierra) en cada punta: a inglete con el vecino que también da a
		# la calle en una esquina saliente
		var grueso: float = GRUESO.get(t, 0.15)
		var ext := []
		for i in n:
			ext.append([0.0, 0.0, false, false])  # alargar al comienzo, al final; tapar el comienzo, el final
		for i in n:
			var j := (i + 1) % n
			var wi: Muro = muros[i]
			var wj: Muro = muros[j]
			if wi == null or wj == null:
				continue
			var giro := wi.d.cross(wj.d) * (-1.0 if cw else 1.0)  # > 0: esquina saliente
			if giro <= 0.0:
				continue
			var tg := tan(acos(clampf(wi.d.dot(wj.d), -1.0, 1.0)) / 2)
			if calle[i] and calle[j] and tg < 1.5:
				ext[i][1] = grueso * tg
				ext[j][0] = grueso * tg
			else:
				ext[i][3] = calle[i]
				ext[j][2] = calle[j]
		# las fachadas
		var tienda_pb := pb == "vitrinas" or pb == "vidrio"
		# el local de un piso: todos sus lados a la calle suben al pretil de la página (shopFront, 1,8 m sobre el techo)
		var pretil_local: bool = p <= 1 and t != "galpon" and pb != "ventanas" and (not shops.is_empty() or tienda_pb) and k == "f"
		for i in n:
			var w: Muro = muros[i]
			if w == null or w.L < 0.6:
				continue
			F = grueso if calle[i] else P
			vanos = []
			var tienda: bool = calle[i] and pb != "ventanas" and (i in shops or tienda_pb)
			# lo alto: bajo el cielo del alero, hasta el pretil de la página, o el propio de las fachadas del centro
			var top := H + ph
			var pretil_propio := false
			if aleros[i] and libre[i]:
				top = H - TF - F * pend - 0.01
			elif hastial[i] and libre[i]:
				top = H - TF - 0.01
			elif calle[i] and (k == "f" or rh <= 0.05):
				if pretil_local:
					top = H + 1.8
				elif centro and k == "f" and float(sp["pretil"]) > ph:
					top = H + float(sp["pretil"])
					pretil_propio = true
			var hi := top if aleros[i] and libre[i] else H  # lo alto de la fachada para sus vanos
			# los tramos de color: una pareada, cada mitad del suyo
			var cols := [[-10.0, 0.0, col]]
			if e.has("m") and e.has("w2"):
				var mp := Vector2(e["m"][0], e["m"][1])
				var sm := (mp - w.a).dot(w.d)
				if sm > 0.5 and sm < w.L - 0.5 and absf((mp - w.a).dot(w.o)) < 1.0:
					cols = [[-10.0, 0.0, col], [sm, 0.0, hx(String(e["w2"]))]]
			var mat := "metal" if t == "galpon" else "liso"
			if calle[i]:
				if centro:
					fachada_centro(w, b, hi, top, p, col, tienda, reja, pb, k == "f")
				elif t == "galpon":
					fachada_galpon(w, b, H)
				elif t in ["block", "torre", "institucional", "edificio"]:
					fachada_altos(w, b, H, p, t, col)
				else:
					fachada_casa(w, b, hi, p, t, col, cols, reja)
				var e0: float = ext[i][0]
				var e1: float = ext[i][1]
				plano(w, -e0, w.L + e1, b - 0.6, top, F, cols, mat)
				# las puntas que no siguen en otra fachada, el canto de arriba y, sobre el techo, la cara de atrás del pretil
				# (a inglete con la del lado vecino: la línea de atrás se acorta lo que la de adelante se alarga)
				var atras := -0.2 if top > H + ph + 0.05 else 0.0
				var a0 := e0 / grueso * -atras
				var a1 := w.L - e1 / grueso * -atras
				for pu in [[ext[i][2], -e0, -1.0, cols[0][2]], [ext[i][3], w.L + e1, 1.0, cols[-1][2]]]:
					if pu[0]:
						var sx: float = pu[1]
						var cc: Color = pu[3]
						m.cara([w.W(sx, b - 0.6, 0.0), w.W(sx, b - 0.6, F), w.W(sx, top, F), w.W(sx, top, atras)], cc.darkened(0.06), mat, w.D * pu[2])
				if not (aleros[i] and libre[i]):
					m.cara([w.W(a0, top, atras), w.W(a1, top, atras), w.W(w.L + e1, top, F), w.W(-e0, top, F)], col.lightened(0.05), mat, Vector3.UP)
				if atras < 0.0:
					m.cara([w.W(a1, H + ph, atras), w.W(a0, H + ph, atras), w.W(a0, top, atras), w.W(a1, top, atras)], col.darkened(0.1), mat, -w.N)
				if pretil_propio:
					remate(w, -e0, w.L + e1, top, col)
				# la colisión: el plano
				var zc := maxf(top, b + 2.5)
				var c0 := w.W(-e0, b - 0.6, F)
				var c1 := w.W(w.L + e1, b - 0.6, F)
				var c2 := w.W(w.L + e1, zc, F)
				var c3 := w.W(-e0, zc, F)
				choque.append_array([c0, c1, c2, c0, c2, c3])
			else:
				plano(w, 0.0, w.L, b - 0.6, top, P, cols, mat)
				lado(t, w, b, minf(top, H), p, sp["marco"], reja)
			# el hastial
			if hastial[i] and rh > 0.05:
				var hb := top if libre[i] else H
				m.cara([w.W(0, hb, F), w.W(w.L, hb, F), w.W(w.L / 2, hb + rh - 0.02, F)], col, "liso", w.N)
				if not libre[i] and F > P + 0.01:
					for lado_h in [[0.0, w.L / 2], [w.L, w.L / 2]]:
						var s0: float = lado_h[0]
						var s1: float = lado_h[1]
						m.cara([w.W(s0, hb, 0), w.W(s1, hb + rh, 0), w.W(s1, hb + rh, F), w.W(s0, hb, F)], col.lightened(0.05), "liso", Vector3.UP)
		# los aleros y el vuelo sobre los hastiales
		if pend > 0.0:
			techo(muros, aleros, hastial, libre, H, rh, pend, vuelo, hx(String(e.get("r", "")), "8d8a84"), col, cw)
		if e.has("c"):
			var c0 := Vector2(e["c"][0][0], e["c"][0][1])
			var c1 := Vector2(e["c"][1][0], e["c"][1][1])
			if t in ["poblacion", "pareada", "fila"] and r.randf() < 0.85:
				reja_antejardin(c0, c1, b, sp["reja"], col if r.randf() < 0.6 else Color("e8e6df"))

	# ------------------------------------------------------------ los techos

	# el alero de cada muro que lo lleva (el faldón sigue e m afuera con su pendiente, su tapacán y su cielo; a inglete
	# con el del muro vecino en una esquina de cuatro aguas) y el vuelo sobre cada hastial (el faldón sigue e m más allá
	# del muro, hasta la línea del alero)
	func techo(muros: Array, aleros: Array, hastial: Array, libre: Array, h: float, rh: float, k: float, e: float, tc: Color, col: Color, cw: bool) -> void:
		var n := muros.size()
		var mt := TECHO
		var cielo := col.lightened(0.12)
		var canto := Color("e8e4da") if r.randf() < 0.6 else tc.darkened(0.25)
		for i in n:
			var w: Muro = muros[i]
			if w == null or not libre[i]:
				continue
			var wp: Muro = muros[(i - 1 + n) % n]
			var wn: Muro = muros[(i + 1) % n]
			if aleros[i]:
				# en cada punta: con otro alero en una esquina saliente, a inglete (el borde de afuera se alarga); junto a
				# un hastial con vuelo, nada (el vuelo cubre la esquina); si no, se cierra
				var xo := [0.0, 0.0]
				var cerrar := [true, true]
				for lado_i in 2:
					var j := (i - 1 + n) % n if lado_i == 0 else (i + 1) % n
					var wv: Muro = wp if lado_i == 0 else wn
					if wv == null or not libre[j]:
						continue
					if hastial[j]:
						cerrar[lado_i] = false
						continue
					var giro := (wv.d.cross(w.d) if lado_i == 0 else w.d.cross(wv.d)) * (-1.0 if cw else 1.0)
					var tg := tan(acos(clampf(w.d.dot(wv.d), -1.0, 1.0)) / 2)
					xo[lado_i] = (e * tg if tg < 3.0 else 0.0) * (1.0 if giro > 0.0 else -1.0)
					cerrar[lado_i] = tg >= 3.0
				var zi := h + 0.015 + 0.05 * k
				var zo := h + 0.015 - e * k
				var nf := w.faldon(k)
				var a0: float = -xo[0]
				var a1: float = w.L + xo[1]
				m.cara([w.W(0, zi, -0.05), w.W(w.L, zi, -0.05), w.W(a1, zo, e), w.W(a0, zo, e)], tc, mt, nf)
				m.cara([w.W(a0, zo - TF, e), w.W(a1, zo - TF, e), w.W(a1, zo, e), w.W(a0, zo, e)], canto, "pintura", w.N)
				m.cara([w.W(0, h - TF, 0), w.W(a0, zo - TF, e), w.W(a1, zo - TF, e), w.W(w.L, h - TF, 0)], cielo, "liso", -nf)
				for pu in [[cerrar[0], 0.0, a0, -1.0], [cerrar[1], w.L, a1, 1.0]]:
					if pu[0]:
						m.cara([w.W(pu[1], h - TF, 0), w.W(pu[1], zi, -0.05), w.W(pu[2], zo, e), w.W(pu[2], zo - TF, e)], canto, "pintura", w.D * pu[3])
			elif hastial[i]:
				# el vuelo: cada mitad en el plano de su faldón, de la línea del alero (s = -e o L + e) a la cumbrera
				for mitad in 2:
					var s0 := -e if mitad == 0 else w.L + e
					var s1 := w.L / 2
					var z0 := h + 0.015 - e * k
					var z1 := h + 0.015 + rh
					var wv: Muro = wp if mitad == 0 else wn
					if wv == null:
						continue
					var nf := wv.faldon(k)
					m.cara([w.W(s0, z0, -0.05), w.W(s1, z1, -0.05), w.W(s1, z1, e), w.W(s0, z0, e)], tc, mt, nf)
					m.cara([w.W(s0, z0 - TF, e), w.W(s1, z1 - TF, e), w.W(s1, z1, e), w.W(s0, z0, e)], canto, "pintura", w.N)
					m.cara([w.W(s0, z0 - TF, 0), w.W(s1, z1 - TF, 0), w.W(s1, z1 - TF, e), w.W(s0, z0 - TF, e)], cielo, "liso", -nf)
					# la punta del faldón, de canto, en la línea del alero
					m.cara([w.W(s0, z0 - TF, 0), w.W(s0, z0 - TF, e), w.W(s0, z0, e), w.W(s0, z0, -0.05)], canto, "pintura", wv.N)

	# ------------------------------------------------------------ por tipo

	# el centro: planta baja (locales, o la puerta y ventanas), los pisos de arriba por bahías, zócalo, fajas, cornisa
	func fachada_centro(w: Muro, b: float, h: float, top: float, p: int, col: Color, tienda: bool, reja: Variant, pb: String, plano_techo: bool) -> void:
		var L := w.L
		var t: String = sp["t"]
		var adobe := t == "adobe"
		var marco: Color = sp["marco"]
		var trim: Color = sp["trim_col"]
		var margen := 0.3 if adobe else 0.4  # bajo la cornisa
		var hg: float = h - b - margen if p <= 1 else clampf(sp["hg"], 3.0, maxf(3.0, h - b - margen - (p - 1) * 2.6))
		if tienda and p <= 1:
			hg = h - b - 0.3  # el local de un piso: el letrero va en el pretil
		var hu := (h - b - margen - hg) / maxi(1, p - 1)
		var nb := maxi(1, roundi(L / sp["bahia"]))
		var bw := L / nb
		var tipo: String = sp["vent"]
		# los pisos de arriba: una ventana por bahía
		for f in range(1, p):
			var hf := b + hg + (f - 1) * hu
			if f == 1 and sp["balcon"] == 2 and tipo != "alta" and nb >= 2:
				balcon(w, 0.4, L - 0.4, hf + 0.14, 0.75, trim)
			for j in nb:
				var s := (j + 0.5) * bw
				var an := clampf(bw * (0.42 if adobe else 0.5), 0.8, 2.0)
				var z0 := hf + 0.95
				var al := hu * float(sp["vh"])
				if tipo == "alta":
					an = clampf(bw * 0.4, 0.8, 1.5)
					z0 = hf + 0.14
					al = hu - 0.14 - 0.5
				al = minf(al, hf + hu - 0.3 - z0)
				if al < 0.6 or an > bw - 0.4:
					continue
				var fl := 0.0
				if adobe or tipo == "rebajado":
					fl = an * 0.14
				var pers: float = r.randf_range(0.15, 0.7) if sp["persianas"] and r.randf() < 0.35 else -1.0
				if tipo == "par" and an > 1.3:
					for sg in [-1.0, 1.0]:
						ventana(w, s + sg * an * 0.3, an * 0.42, z0, al, marco, null, 1, 0.0, pers)
					saliente(w, s - an / 2 - 0.15, s + an / 2 + 0.15, z0 + al + 0.08, z0 + al + 0.24, F, F + 0.1, trim)
				else:
					ventana(w, s, an, z0, al - fl, marco, null, 2, fl, pers)
				if tipo == "recercado" or sp["recercado"]:
					# el recercado: jambas y un dintel con su cornisita y la clave al medio
					for sg in [-1.0, 1.0]:
						var e0: float = s + an / 2 if sg > 0 else s - an / 2 - 0.18
						saliente(w, e0, e0 + 0.18, z0 - 0.07, z0 + al + 0.1, F, F + 0.04, trim)
					saliente(w, s - an / 2 - 0.28, s + an / 2 + 0.28, z0 + al + 0.1, z0 + al + 0.32, F, F + 0.12, trim)
					saliente(w, s - 0.13, s + 0.13, z0 + al - 0.04 + fl, z0 + al + 0.28, F, F + 0.08, trim.darkened(0.06))
				if tipo == "alta":
					balcon(w, s - an / 2 - 0.25, s + an / 2 + 0.25, hf + 0.14, 0.4, trim)
				elif f == 1 and sp["balcon"] == 1 and j == nb / 2 and nb >= 3:
					balcon(w, s - bw / 2 + 0.3, s + bw / 2 - 0.3, hf + 0.14, 0.85, trim)
		# la planta baja
		if tienda:
			comercio(w, b, hg, nb, bw, p, col, pb)
		else:
			var pj: int = sp["puerta_j"] % nb if L > 4.0 else -1
			for j in nb:
				var s := (j + 0.5) * bw
				if j == pj:
					# la puerta: en el adobe, el portón del zaguán, de dos hojas con su montante; si no, una o dos hojas
					var an := minf(bw - 0.7, 1.7 if adobe else 1.4)
					var al := minf(hg - 0.3, 3.0 if adobe else 2.6)
					var mont := minf(0.55, al - 2.05) if (sp["montante"] or adobe) and al > 2.35 else 0.0
					puerta(w, s, an, b, al, sp["puerta"], marco.darkened(0.1), an > 1.2, mont,
						an * 0.12 if adobe and sp["vent"] == "rebajado" else 0.0)
				elif j == nb - 1 and nb > 2 and sp["porton"] and not adobe:
					porton(w, s - minf(1.3, bw / 2 - 0.3), s + minf(1.3, bw / 2 - 0.3), b, minf(2.4, hg - 0.5), Color(["8a8d90", "5f6366", "e2e0da"][r.randi() % 3]))
				else:
					var an := clampf(bw * (0.38 if adobe else 0.45), 0.8, 1.6)
					var z0 := b + (0.8 if adobe else 1.0)
					var al := hg - (z0 - b) - (0.35 if adobe else 0.6)
					if al < 0.6 or an > bw - 0.4:
						continue
					var fl := an * 0.14 if adobe and sp["vent"] == "rebajado" else 0.0
					ventana(w, s, an, z0, al - fl, marco, reja, 2, fl)
					if adobe and sp["recercado"]:
						saliente(w, s - an / 2 - 0.2, s + an / 2 + 0.2, z0 + al + 0.08, z0 + al + 0.26, F, F + 0.1, trim)
		# zócalo, fajas, cornisa, pilastras
		var hz: float = sp["zocalo_alto"]
		if adobe:
			hz = 0.72
		if tienda:
			hz = 0.35
		if sp["zocalo"] or tienda:
			franja(w, -0.02, L + 0.02, b - 0.6, b + hz, F - 0.01, F + 0.025, sp["zocalo_col"] if sp["zocalo"] else col.darkened(0.3))
		for f in range(1, p):
			var hf := b + hg + (f - 1) * hu
			franja(w, 0, L, hf - 0.1, hf + 0.1, F, F + 0.07, trim)
		# la cornisa: bajo el alero, a la altura del techo plano (con el pretil encima) o, en un local de un piso, sobre
		# su letrero
		var hc := (top if tienda and p <= 1 else minf(h, top)) - 0.3
		saliente(w, -0.02, L + 0.02, hc, hc + 0.22, F, F + (0.2 if plano_techo else 0.1), trim)
		if plano_techo and (t != "adobe" or sp["remate"] > 0):
			saliente(w, 0.0, L, hc - 0.3, hc - 0.18, F, F + 0.08, trim.darkened(0.04))
		if sp["esquinas"] and L > 4.0:
			# pilastras en las dos esquinas, del zócalo a la cornisa
			for ex in [[0.0, 0.5], [L - 0.5, L]]:
				saliente(w, ex[0], ex[1], b + (hz if sp["zocalo"] else 0.0), hc, F, F + 0.06, trim)

	# el remate de un pretil propio (centro, techo plano): un paño alzado al medio o dados en los ejes, y su albardilla
	func remate(w: Muro, s0: float, s1: float, top: float, col: Color) -> void:
		var L := s1 - s0
		var trim: Color = sp["trim_col"]
		saliente(w, s0, s1, top - 0.08, top, F - 0.05, F + 0.06, trim.lightened(0.03))
		if sp["remate"] == 1 and L > 6.0:
			var wr := minf(L * 0.35, 6.0)
			var c := (s0 + s1) / 2
			bloque(w, c - wr / 2, c + wr / 2, top - 0.1, top + 0.6, F - 0.12, F + 0.04, col)
			bloque(w, c - wr / 4, c + wr / 4, top + 0.6, top + 0.95, F - 0.12, F + 0.04, col)
			bloque(w, c - wr / 4 - 0.08, c + wr / 4 + 0.08, top + 0.95, top + 1.05, F - 0.14, F + 0.1, trim)
			saliente(w, c - wr / 2 - 0.08, c + wr / 2 + 0.08, top + 0.55, top + 0.65, F - 0.14, F + 0.1, trim)
			rect(w, c - wr / 2 + 0.35, c + wr / 2 - 0.35, top, top + 0.45, F + 0.045, col.darkened(0.1))
		elif sp["remate"] == 2:
			var nd := maxi(1, roundi(L / float(sp["bahia"])))
			for j in nd + 1:
				var s := clampf(s0 + L * j / nd, s0 + 0.25, s1 - 0.25)
				bloque(w, s - 0.22, s + 0.22, top - 0.08, top + 0.4, F - 0.1, F + 0.1, trim)

	# una caja suelta sobre el pretil: como saliente(), con su cara de atrás (se ve desde el techo)
	func bloque(w: Muro, s0: float, s1: float, h0: float, h1: float, off0: float, off1: float, col: Color) -> void:
		saliente(w, s0, s1, h0, h1, off0, off1, col)
		m.cara([w.W(s1, h0, off0), w.W(s0, h0, off0), w.W(s0, h1, off0), w.W(s1, h1, off0)], col.darkened(0.12), "liso", -w.N)

	# los locales de una planta baja: vitrinas hundidas (con su puerta) entre machones, la cortina metálica bajada o
	# enrollada, el letrero de cada local, toldos y letreros de bandera; pb: vidrio, vanos vidriados entre pilares
	func comercio(w: Muro, b: float, hg: float, nb: int, bw: float, p: int, col: Color, pb: String) -> void:
		var L := w.L
		var por := 2 if bw < 3.4 and nb >= 2 else 1
		var zt := b + hg - (1.0 if p > 1 else 0.6)  # lo alto de las vitrinas
		var x := 0.0
		var pil: Color = Color(sp["pilares"]) if sp["pilares"] != "" else col.darkened(0.05)
		while x < L - 1.2:
			var x1 := minf(L, x + bw * por)
			if L - x1 < 1.2:
				x1 = L
			var v0 := x + 0.35
			var v1 := x1 - 0.35
			var vid := VIDRIO
			vid.a = 1.0 if r.randf() < 0.5 else 0.6  # encendida de noche, la mitad
			vano(w, v0, v1, b, zt, FONDO_LOCAL, Color(0.32, 0.33, 0.34), 0.0, "metal")
			fondo_de(w, v0, v1, b + 0.35, zt, FONDO_LOCAL + 0.002, vid, "ventana")
			rect(w, v0, v1, b, b + 0.35, FONDO_LOCAL + 0.004, Color(0.25, 0.26, 0.27), "metal")
			var mt := Color(0.24, 0.25, 0.26) if pb != "vidrio" else Color(sp["marco"])
			var pu := v1 - 1.1 if r.randf() < 0.5 else v0 + 0.1
			for q in [[v0, v1, zt - 0.06, zt], [pu, pu + 0.06, b, zt], [pu + 0.94, pu + 1.0, b, zt], [pu, pu + 1.0, b + 2.2, b + 2.26]]:
				rect(w, q[0], q[1], q[2], q[3], FONDO_LOCAL + 0.02, mt, "metal")
			if pb == "vidrio":
				for kk in range(1, 4):
					rect(w, v0, v1, b + (zt - b) * kk / 4 - 0.03, b + (zt - b) * kk / 4 + 0.03, FONDO_LOCAL + 0.02, mt, "metal")
			else:
				# la cortina: bajada entera (un local cerrado), a medias o enrollada en su cajón
				var cr := r.randf()
				if cr < float(sp["cortina"]):
					cortina(w, v0, v1, b, zt, FONDO_LOCAL + 0.06)
				elif cr < float(sp["cortina"]) * 1.6:
					cortina(w, v0, v1, lerpf(b + 1.0, zt - 0.6, r.randf()), zt, FONDO_LOCAL + 0.06)
				saliente(w, v0, v1, zt - 0.3, zt, F - 0.12, F - 0.02, Color(0.45, 0.46, 0.46), "metal")
				# el letrero del local
				var fondo := Color(LETREROS[r.randi() % LETREROS.size()])
				var lz0 := zt + 0.15 if p > 1 else b + hg + 0.45
				var lz1 := zt + 0.85 if p > 1 else b + hg + 1.45
				saliente(w, v0 - 0.15, v1 + 0.15, lz0, lz1, F, F + 0.1, fondo, "pintura")
				var claro := fondo.lightened(0.55) if fondo.get_luminance() < 0.5 else fondo.darkened(0.6)
				rect(w, v0 + (v1 - v0) * 0.2, v1 - (v1 - v0) * 0.2, (lz0 + lz1) / 2 - 0.09, (lz0 + lz1) / 2 + 0.09, F + 0.105, claro, "pintura")
				if sp["toldo"] and r.randf() < 0.7:
					toldo(w, v0, v1, zt + 0.08, Color(TOLDOS[r.randi() % TOLDOS.size()]), r.randf() < 0.4)
				elif sp["bandera"] and p > 1 and r.randf() < 0.5:
					letrero_bandera(w, v1 + 0.1, zt + 1.0, fondo)
			# el machón entre los locales
			if sp["pilares"] != "" and x1 < L - 0.1:
				saliente(w, x1 - 0.35, x1 + 0.35, b, zt + 0.1, F, F + 0.05, pil, "granito")
			x = x1

	# una casa: la puerta (con montante y a veces un alerito), ventanas con protecciones, los pisos de arriba; en una
	# pareada, la puerta de cada una junto a la medianera
	func fachada_casa(w: Muro, b: float, h: float, p: int, t: String, col: Color, cols: Array, reja: Variant) -> void:
		var L := w.L
		var marco: Color = sp["marco"]
		var hp := (h - b) / p
		var tramos := []
		if t == "pareada" and cols.size() > 1:
			tramos = [[0.0, cols[1][0], true], [cols[1][0], L, false]]
		else:
			var dpos := 0.25 + r.randf() * 0.5 if L > 4.0 else 0.5
			tramos = [[0.0, L, clampf(L * dpos, 0.8, L - 0.8)]]
		for tr in tramos:
			var s0: float = tr[0]
			var s1: float = tr[1]
			if s1 - s0 < 2.0:
				continue
			var sd: float
			if tr[2] is bool:
				# la puerta junto a la medianera (el cambio de color)
				sd = clampf(s1 - 1.1 if tr[2] else s0 + 1.1, s0 + 0.6, s1 - 0.6)
			else:
				sd = tr[2]
			var mont := 0.45 if sp["montante"] else 0.0
			puerta(w, sd, 0.9, b + 0.15, 2.05 + mont, sp["puerta"], marco, false, mont)
			if sp["alerito"] and t != "condominio":
				saliente(w, sd - 0.75, sd + 0.75, b + 2.45 + mont, b + 2.55 + mont, F, F + 0.7, col.lightened(0.1))
			# una o dos ventanas en lo que queda
			for hq in [[s0 + 0.25, sd - 0.65], [sd + 0.65, s1 - 0.25]]:
				var an := minf(1.6, hq[1] - hq[0] - 0.3)
				if an > 0.6:
					ventana(w, (hq[0] + hq[1]) / 2, an, b + 0.95, minf(1.15, hp - 1.35), marco, reja, 2)
			for f in range(1, p):
				var k := maxi(1, roundi((s1 - s0) / 3.2))
				for i in k:
					var an := minf(1.3, (s1 - s0) / k - 0.7)
					if an > 0.5:
						ventana(w, s0 + (s1 - s0) * (i + 0.5) / k, an, b + f * hp + 0.9, minf(1.05, hp - 1.3), marco, null, 2)
		if sp["zocalo"]:
			franja(w, -0.02, L + 0.02, b - 0.6, b + 0.5, F - 0.01, F + 0.02, col.darkened(0.25) if r.randf() < 0.5 else Color("9a9690"), "granito")

	# bloques, torres, edificios altos e institucionales: ventanas por piso, bandas de losa, balcones, el acceso
	func fachada_altos(w: Muro, b: float, h: float, p: int, t: String, col: Color) -> void:
		var L := w.L
		var marco: Color = sp["marco"]
		var hp := clampf((h - b) / p, 2.5, 4.2)
		var cada: float = {"torre": 2.8, "block": 2.8, "institucional": 3.4}.get(t, 3.2)
		var an0: float = {"torre": 1.5, "block": 1.2, "institucional": 1.7}.get(t, 1.4)
		var alto: float = {"torre": 1.6, "block": 1.15, "institucional": 1.5}.get(t, 1.5)
		var nv := maxi(1, roundi(L / cada))
		var acceso := L / 2 if L > 5.0 else -100.0
		var balcones: bool = t == "torre" and sp["balcon"] > 0
		for f in p:
			var y := b + f * hp
			if y + alto + 0.8 > h:
				break
			for i in nv:
				var s := L * (i + 0.5) / nv
				var an := minf(an0, L / nv - 0.5)
				if an < 0.5:
					continue
				if f == 0 and absf(s - acceso) < 2.0:
					continue
				ventana(w, s, an, y + 0.9, alto, marco, null, 2)
				if balcones and f > 0:
					saliente(w, s - an / 2 - 0.5, s + an / 2 + 0.5, y - 0.02, y + 0.14, F - 0.02, F + 0.9, col.darkened(0.06))
					saliente(w, s - an / 2 - 0.5, s + an / 2 + 0.5, y + 1.0, y + 1.05, F + 0.85, F + 0.9, Color(0.2, 0.21, 0.22), "metal")
					rect(w, s - an / 2 - 0.5, s + an / 2 + 0.5, y + 0.14, y + 1.0, F + 0.88, Color(0.22, 0.23, 0.24), "metal")
			if f > 0 and (t == "torre" or t == "block"):
				franja(w, -0.02, L + 0.02, y - 0.12, y + 0.06, F, F + 0.08, Color("e4e2dc"), "hormigon")
		if acceso > 0.0:
			var v := VIDRIO
			v.a = 1.0
			var aw := minf(2.6, L * 0.4)
			vano(w, acceso - aw / 2, acceso + aw / 2, b, b + 2.6, FONDO, sp["revoque"])
			fondo_de(w, acceso - aw / 2, acceso + aw / 2, b, b + 2.6, FONDO + 0.002, v, "ventana")
			for kk in 3:
				var sx := acceso - aw / 2 + aw * kk / 2.0
				rect(w, sx - 0.03, sx + 0.03, b, b + 2.6, FONDO + 0.02, Color(0.2, 0.21, 0.22), "metal")
			saliente(w, acceso - aw / 2 - 0.6, acceso + aw / 2 + 0.6, b + 2.8, b + 3.0, F, F + 1.4, Color("d8d6d0"), "hormigon")

	func fachada_galpon(w: Muro, b: float, h: float) -> void:
		var L := w.L
		var pw := minf(L * 0.5, 4.5)
		if pw < 1.5:
			return
		var s := L * (0.3 + r.randf() * 0.4)
		porton(w, s - pw / 2, s + pw / 2, b, minf(4.5, h - b - 1.2), Color(["8a8d90", "6f7a6e", "b3aa96", "4d5560"][r.randi() % 4]))
		if L > pw + 3:
			var sp2 := s + pw / 2 + 1.2 if s + pw / 2 + 2 < L else s - pw / 2 - 1.2
			puerta(w, sp2, 0.9, b, 2.1, Color("6f7276"), Color("6f7276"))
		var v := VIDRIO.lightened(0.35)
		v.a = 0.6
		rect(w, 0.3, L - 0.3, h - 1.3, h - 0.5, F + 0.02, v, "ventana")

	# un lado que no da a la calle: en las casas aisladas, una ventana plana por piso cada ~4 m; en las de fachada
	# continua, la medianera lisa
	func lado(t: String, w: Muro, b: float, h: float, p: int, marco: Color, reja: Variant) -> void:
		if t in ["adobe", "continua", "local", "galpon"] or w.L < 2.5:
			return
		var hp := (h - b) / p
		if t in ["block", "edificio", "torre", "institucional"]:
			var nv := maxi(1, roundi(w.L / 3.2))
			for f in p:
				var y := b + f * clampf(hp, 2.5, 4.2)
				if y + 2.0 > h:
					break
				for i in nv:
					ventana_plana(w, w.L * (i + 0.5) / nv, minf(1.2, w.L / nv - 0.5), y + 0.9, 1.2, marco)
			return
		var n := mini(3, maxi(1, floori(w.L / 4.0)))
		for f in p:
			for i in n:
				if r.randf() < 0.25:
					continue
				ventana_plana(w, w.L * (i + 0.5) / n, minf(1.0, w.L / n - 0.8), b + f * hp + 1.0, 0.9, marco, reja if f == 0 else null)

	# la reja del antejardín de a a b, con pilares y un portón; mira a los dos lados
	func reja_antejardin(a: Vector2, b: Vector2, h0: float, col: Color, pilar: Color) -> void:
		var L := a.distance_to(b)
		if L < 2.0:
			return
		var d := (b - a) / L
		var o := Vector2(d.y, -d.x)
		var alto := 1.6 + r.randf() * 0.3
		for lado_r in [Muro.new(a, b, o), Muro.new(b, a, -o)]:
			var w: Muro = lado_r
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
