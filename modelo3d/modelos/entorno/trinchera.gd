# Un tramo de la Ruta 5 en trinchera, de cerca (modelos/trinchera_ruta5.gd): la autopista bajo el nivel de la ciudad,
# entre muros de hormigón y taludes de pasto seco con su cierro arriba, con los ramales que suben a las caleteras y los
# pasos superiores que la cruzan. La página no puede dibujarla (trampa «La Ruta 5 va en trinchera y el relieve no la
# puede dibujar»: los pasos suben 2–4 m sobre la calle con una abertura oscura); aquí se recorta de las teselas todo lo
# que cae en el corredor y se arma de nuevo, a su altura.
#
# Cada calzada (data/ruta5.json, la copia de modelo3d/datos/: las líneas de OSM, que son el borde entre la primera y la
# segunda pista, trampa «Las líneas de OSM de la Ruta 5…») se recorre cada PASO m, y en cada estación se arma su sección
# de la mediana hacia afuera, con las medidas de la página (src/js/66-ruta5.js: la calzada de 4,5 m a la izquierda de
# la línea a 6 m, o 9,5 con la tercera pista, a su derecha):
#   la mitad de la mediana (tierra) con su defensa caminera, la calzada (pistas, bermas, líneas de 12–15 cm), la cuneta
#   de hormigón, el muro (de moldaje, del alto de «muro» o hasta el suelo bajo un paso: el estribo), su tapa, el talud
#   de pasto seco hasta el suelo, una franja de pasto y el cierro de malla.
# Donde un ramal de la página (R5.k, motorway_link) corre por fuera de la calzada bajo el suelo, la sección lo incluye:
# entre la calzada y el ramal, una berma (un talud, o un muro si sube más de 1:1), y el muro va por fuera del ramal. La
# altura de un ramal va de la de la calzada donde se junta con ella a la de la calle en su otra punta, a lo largo.
#
# Todo lo que el recorte necesita sale de los datos, sin el relieve (recortes() se pide antes de cargar las teselas): el
# ancho del talud es (hondo − muro) / TALUD sobre un suelo plano. Al armar, el talud llega al borde del recorte a la
# altura del suelo de ese punto, así que calza con el terreno de la tesela sin costura.
#
# Los pasos superiores (el tablero de la calle de la página, de una punta a la otra: las mismas polilíneas de
# hitos/enlaces-ruta-5.js) van a la altura de la calle, con su losa, las pilas en la mediana, el parapeto y la baranda
# de malla donde cruzan el corredor. Los postes de la luz de la mediana (cada 45 m, dos brazos de 12 m, como en las
# fotos) suman su lámpara a las de faroles.gd. Y unos autos por la trinchera (los de la página, a la altura de la
# calle, se van con el recorte).
#
# Aproximado: la profundidad y el alto de los muros a lo largo («hondo», «muro») se leyeron de las fotos de Mapillary
# de 2022 y 2025 desde la autopista (una cada 40 m en cada sentido), no medidos; la pendiente de los taludes, la losa,
# las pilas y la baranda son las típicas de las fotos.
extends RefCounted

const Malla := preload("res://malla.gd")
const Mob := preload("res://modelos/entorno/mobiliario.gd")
const Auto := preload("res://modelos/entorno/auto.gd")

const RUTA5 := "res://datos/ruta5.json"
const PASO := 2.0  # m entre estaciones
const TALUD := 0.8  # m de alto por m: los taludes de pasto sobre los muros (~39°)
const CUNETA := 0.8  # m de hormigón entre la berma y el muro
const TAPA := 0.3  # m: la tapa del muro
const FRANJA := 1.2  # m de pasto plano entre el talud y el borde del recorte (el cierro va en ella)
const LOSA := 1.15  # m: el espesor del tablero de un paso
const H_CALZADA := 0.16  # sobre el suelo donde la autopista no está en trinchera (Y_LAYER.r5 de la página)
const H_CALLE := 0.12
const CELDA := 50.0  # m: las franjas de y en que se anotan los segmentos de cada calzada
const RAMAL_HONDO := 0.25  # m: un ramal entra en el corredor donde va al menos así de hondo

const K := {
	"asfalto": Color("55554f"), "blanco": Color("e6e4dc"), "hormigon": Color("b9b3a6"), "muro": Color("b3a993"),
	"tapa": Color("c2bba9"), "seco": Color("b49f6c"), "tierra": Color("8e7d5c"), "malla": Color("5d6b62"),
	"defensa": Color("a9adb0"), "poste": Color("9a9c9c"), "lampara": Color("d8d4c4"), "losa": Color("aaa395"),
	"baranda": Color("6c7872"), "pila": Color("a39c8d"),
}
const PALETA := [Color(0.93, 0.93, 0.91), Color(0.72, 0.74, 0.76), Color(0.45, 0.47, 0.49), Color(0.13, 0.13, 0.14),
	Color(0.68, 0.13, 0.11), Color(0.16, 0.23, 0.43), Color(0.74, 0.68, 0.55)]

static var _calzadas := []  # las dos calzadas de datos/ruta5.json, remuestreadas (una vez para todos los tramos)
static var _ramales := []  # [ancho, PackedVector2Array]

var nombre: String
var y0: float  # el tramo: de y0 (sur) a y1 (norte), en y de grilla
var y1: float
var hondo := []  # [[y, m]] ordenados por y
var muro := []
var pasos := []  # [{"pts": PackedVector2Array, "hw": float, "L": [...]}]
var est := [[], []]  # por calzada: las estaciones (Dictionary)
var S: RefCounted  # suelo.gd
var lamparas: Array[Vector3] = []


func _init(def: Dictionary) -> void:
	if _calzadas.is_empty():
		_leer()
	nombre = def["nombre"]
	y0 = minf(def["y"][0], def["y"][1])
	y1 = maxf(def["y"][0], def["y"][1])
	hondo = _orden(def["hondo"])
	muro = _orden(def["muro"])
	for p in def.get("pasos", []):
		var pts := PackedVector2Array()
		for q in p["pts"]:
			pts.append(Vector2(q[0], q[1]))
		pasos.append({"nombre": p["nombre"], "pts": pts, "hw": float(p["hw"])})
	if _calzadas.size() == 2:
		_estaciones()


static func _orden(knots: Array) -> Array:
	var k := knots.duplicate()
	k.sort_custom(func(a, b): return a[0] < b[0])
	return k


# un valor por tramos lineales de [[y, valor]]
static func _lineal(knots: Array, y: float) -> float:
	if y <= knots[0][0]:
		return knots[0][1]
	for i in knots.size() - 1:
		if y <= knots[i + 1][0]:
			var t: float = (y - knots[i][0]) / maxf(knots[i + 1][0] - knots[i][0], 1e-6)
			return lerpf(knots[i][1], knots[i + 1][1], t)
	return knots[-1][1]


# ---------------------------------------------------------------- la Ruta 5 de la página (66-ruta5.js: R5C, r5at, R5R)

static func _leer() -> void:
	var f := FileAccess.open(RUTA5, FileAccess.READ)
	if f == null:
		push_warning("trinchera.gd: no está %s (make modelo3d)" % RUTA5)
		return
	var d: Dictionary = JSON.parse_string(f.get_as_text())
	for c in d["c"]:
		var raw := []
		var x := 0.0
		var y := 0.0
		var p: Array = c["p"]
		for i in range(0, p.size(), 2):
			x += p[i]; y += p[i + 1]
			raw.append(Vector2(x / 10.0, y / 10.0))
		var P := []
		var dd := 0.0
		var l: String = c["l"]
		var lit: String = c["lit"]
		for i in raw.size() - 1:
			var a: Vector2 = raw[i]
			var b: Vector2 = raw[i + 1]
			var L := a.distance_to(b)
			if L < 0.01:
				continue
			var n := maxi(1, ceili(L / 8.0))
			var t := (b - a) / L
			for k in n:
				P.append({"p": a.lerp(b, float(k) / n), "d": dd + L * k / n, "l": int(l[i]), "lit": lit[i] == "1", "t": t, "e": 0.0})
			dd += L
		var z: Dictionary = P[-1]
		P.append({"p": raw[-1], "d": dd, "l": z["l"], "lit": z["lit"], "t": z["t"], "e": 0.0})
		# la tercera pista abre y cierra en 40 m
		var r0 := -1
		for i in P.size() + 1:
			var on: bool = i < P.size() and P[i]["l"] >= 3
			if on and r0 < 0:
				r0 = i
			if not on and r0 >= 0:
				var a: float = P[r0]["d"]
				var b: float = P[mini(i, P.size() - 1)]["d"]
				for j in range(r0, i):
					P[j]["e"] = clampf(minf((P[j]["d"] - a) / 40.0, (b - P[j]["d"]) / 40.0), 0.0, 1.0)
				r0 = -1
		# la normal en inglete (a la izquierda de la marcha), escalada para que un desplazamiento conserve su ancho
		for i in P.size():
			var s: Dictionary = P[maxi(0, i - 1)]
			var m := Vector2(-s["t"].y - P[i]["t"].y, s["t"].x + P[i]["t"].x)
			var ml := maxf(m.length(), 1e-9)
			var cs := maxf(0.5, (-m.x * P[i]["t"].y + m.y * P[i]["t"].x) / ml)
			P[i]["n"] = m / ml / cs
		# los segmentos por franja de CELDA m de y, para proyectar() y _hs()
		var celdas := {}
		for i in P.size() - 1:
			for j in range(floori(minf(P[i]["p"].y, P[i + 1]["p"].y) / CELDA), floori(maxf(P[i]["p"].y, P[i + 1]["p"].y) / CELDA) + 1):
				if not celdas.has(j):
					celdas[j] = []
				celdas[j].append(i)
		_calzadas.append({"P": P, "L": dd, "celdas": celdas})
	for r in d["k"]:
		var pts := PackedVector2Array()
		var x := 0.0
		var y := 0.0
		for i in range(1, r.size(), 2):
			x += r[i]; y += r[i + 1]
			pts.append(Vector2(x / 10.0, y / 10.0))
		_ramales.append([float(r[0]) * 3.5 + 2.5, pts])


# la calzada k a la distancia d: punto, normal en inglete, tangente, tercera pista (e)
static func en(k: int, d: float) -> Dictionary:
	var P: Array = _calzadas[k]["P"]
	d = clampf(d, 0.0, _calzadas[k]["L"])
	var lo := 0
	var hi := P.size() - 1
	while hi - lo > 1:
		var m := (lo + hi) >> 1
		if P[m]["d"] <= d:
			lo = m
		else:
			hi = m
	var a: Dictionary = P[lo]
	var b: Dictionary = P[hi]
	var t: float = (d - a["d"]) / (b["d"] - a["d"]) if b["d"] > a["d"] else 0.0
	return {"p": a["p"].lerp(b["p"], t), "n": a["n"].lerp(b["n"], t), "t": a["t"], "e": lerpf(a["e"], b["e"], t), "d": d, "lit": a["lit"]}


static func off(q: Dictionary, o: float) -> Vector2:
	return q["p"] + q["n"] * o


static func borde(q: Dictionary) -> float:  # R5R: el borde derecho de la calzada
	return -(6.0 + 3.5 * q["e"])


# la distancia a lo largo de la calzada k más cercana a g y su desplazamiento (+ a la izquierda)
static func proyectar(k: int, g: Vector2) -> Vector2:
	var P: Array = _calzadas[k]["P"]
	var best := INF
	var out := Vector2.ZERO
	for i in _cerca(k, g.y, 60.0):
		var a: Vector2 = P[i]["p"]
		var b: Vector2 = P[i + 1]["p"]
		var ab := b - a
		var t := clampf((g - a).dot(ab) / maxf(ab.length_squared(), 1e-9), 0.0, 1.0)
		var e := g - (a + ab * t)
		if e.length_squared() < best:
			best = e.length_squared()
			out = Vector2(lerpf(P[i]["d"], P[i + 1]["d"], t), (ab.x * e.y - ab.y * e.x) / ab.length())
	return out


# los segmentos de la calzada k que tocan las franjas de y a menos de r de y
static func _cerca(k: int, y: float, r: float) -> Array:
	var c: Dictionary = _calzadas[k]["celdas"]
	var vistos := {}
	for j in range(floori((y - r) / CELDA), floori((y + r) / CELDA) + 1):
		for i in c.get(j, []):
			vistos[i] = true
	return vistos.keys()


# la mitad de la distancia a la línea de la otra calzada
static func _hs(k: int, g: Vector2) -> float:
	var P: Array = _calzadas[1 - k]["P"]
	var best := INF
	for i in _cerca(1 - k, g.y, 60.0):
		var a: Vector2 = P[i]["p"]
		var b: Vector2 = P[i + 1]["p"]
		best = minf(best, Geometry2D.get_closest_point_to_segment(g, a, b).distance_squared_to(g))
	return sqrt(best) / 2.0


# ---------------------------------------------------------------- las estaciones (solo datos)

func _estaciones() -> void:
	var rams := _ramales_del_tramo()
	for k in 2:
		var P: Array = _calzadas[k]["P"]
		var da := INF
		var db := -INF
		for q in P:
			if q["p"].y >= y0 and q["p"].y <= y1:
				da = minf(da, q["d"]); db = maxf(db, q["d"])
		if da > db:
			continue
		var d := da
		while true:
			var q := en(k, d)
			var hs := _hs(k, q["p"])
			var c := off(q, hs)
			var D := maxf(0.0, _lineal(hondo, c.y))
			var e := {"d": d, "q": q, "hs": hs, "D": D, "Hw": minf(_lineal(muro, c.y), D)}
			var oc := borde(q)
			e["oc"] = oc
			# el ramal de este lado, si hay
			var r = _ramal_en(rams[k], d)
			e["oi"] = oc
			e["oe"] = oc
			e["De"] = D
			if r != null:
				e["ramal"] = r
				e["oi"] = minf(oc, r["o"] + r["w"] / 2.0)
				e["oe"] = minf(e["oi"] - 0.5, r["o"] - r["w"] / 2.0)
				e["De"] = r["D"]
			e["bajo"] = bajo_paso(off(q, e["oe"] - CUNETA)) or bajo_paso(off(q, hs))
			var hw: float = e["De"] if e["bajo"] else minf(e["Hw"], e["De"])
			e["hwe"] = hw
			e["ow"] = e["oe"] - CUNETA
			e["ot"] = e["ow"] - TAPA - maxf(0.0, e["De"] - hw) / TALUD
			e["ob"] = e["ot"] - FRANJA
			est[k].append(e)
			if d >= db:
				break
			d = minf(d + PASO, db)


# si un punto cae bajo el tablero de un paso (con 1 m de margen)
func bajo_paso(g: Vector2) -> bool:
	for p in pasos:
		var pts: PackedVector2Array = p["pts"]
		for i in pts.size() - 1:
			if Geometry2D.get_closest_point_to_segment(g, pts[i], pts[i + 1]).distance_to(g) < p["hw"] + 1.0:
				return true
	return false


# los ramales de la página que tocan el tramo, como muestras cada 2 m de lado de la calzada a la que van (por fuera:
# desplazamiento negativo): [d, o, ancho, hondo]. Sus puntas se juntan en nodos; el que cae sobre una calzada es la
# junta (va tan hondo como ella), uno suelto es la calle (0 m), y uno interior, en proporción a su distancia a las dos
func _ramales_del_tramo() -> Array:
	var sel := []
	for r in _ramales:
		var pts: PackedVector2Array = r[1]
		var toca := false
		for g in pts:
			if g.y > y0 - 30.0 and g.y < y1 + 30.0:
				toca = true
		if toca:
			sel.append(r)
	# nodos
	var nodos := []  # [Vector2, grado, hondo]
	var ends := []  # por ramal: [i nodo a, i nodo b, largo]
	var nodo := func(g: Vector2) -> int:
		for i in nodos.size():
			if nodos[i][0].distance_to(g) < 1.5:
				nodos[i][1] += 1
				return i
		nodos.append([g, 1, -1.0])
		return nodos.size() - 1
	for r in sel:
		var pts: PackedVector2Array = r[1]
		var L := 0.0
		for i in pts.size() - 1:
			L += pts[i].distance_to(pts[i + 1])
		ends.append([nodo.call(pts[0]), nodo.call(pts[-1]), L])
	var junta := []
	for i in nodos.size():
		var g: Vector2 = nodos[i][0]
		for k in 2:
			var pr := proyectar(k, g)
			if absf(pr.y) < 9.0 and g.y >= y0 - 5.0 and g.y <= y1 + 5.0:
				nodos[i][2] = maxf(0.0, _lineal(hondo, g.y))
				junta.append(i)
				break
	# distancias por los ramales a la junta y a la calle más cercanas
	var dist := func(fuentes: Array) -> Array:
		var dd := []
		dd.resize(nodos.size())
		dd.fill(INF)
		for s in fuentes:
			dd[s] = 0.0
		for _it in nodos.size():
			for e in ends:
				dd[e[1]] = minf(dd[e[1]], dd[e[0]] + e[2])
				dd[e[0]] = minf(dd[e[0]], dd[e[1]] + e[2])
		return dd
	var calles := []
	for i in nodos.size():
		if nodos[i][1] == 1 and not i in junta:
			calles.append(i)
	var dj: Array = dist.call(junta)
	var dc: Array = dist.call(calles)
	for i in nodos.size():
		if nodos[i][2] >= 0.0:
			continue
		if dj[i] == INF:
			nodos[i][2] = 0.0
		else:
			var hj: float = 0.0
			for j in junta:
				hj = maxf(hj, nodos[j][2])
			nodos[i][2] = hj * dc[i] / maxf(dc[i] + dj[i], 1e-6) if dc[i] < INF else hj
	# muestras
	var out := [[], []]
	for ri in sel.size():
		var pts: PackedVector2Array = sel[ri][1]
		var w: float = sel[ri][0]
		var ha: float = nodos[ends[ri][0]][2]
		var hb: float = nodos[ends[ri][1]][2]
		var L: float = ends[ri][2]
		var s := 0.0
		for i in pts.size() - 1:
			var a := pts[i]
			var b := pts[i + 1]
			var l := a.distance_to(b)
			var n := maxi(1, ceili(l / 2.0))
			for j in n + (1 if i == pts.size() - 2 else 0):
				var g := a.lerp(b, float(j) / n)
				var hh := lerpf(ha, hb, (s + l * j / n) / maxf(L, 1e-6))
				if hh < RAMAL_HONDO:
					continue
				var p0 := proyectar(0, g)
				var p1 := proyectar(1, g)
				var k := 0 if absf(p0.y) < absf(p1.y) else 1
				var pr := p0 if k == 0 else p1
				if pr.y < 0.0 and pr.y > -40.0:
					out[k].append({"d": pr.x, "o": pr.y, "w": w, "D": hh, "g": g})
			s += l
	for k in 2:
		out[k].sort_custom(func(a, b): return a["d"] < b["d"])
	return out


func _ramal_en(muestras: Array, d: float):
	var mejor = null
	for m in muestras:
		if absf(m["d"] - d) <= PASO * 0.75 and (mejor == null or m["o"] > mejor["o"]):
			mejor = m
	return mejor


# ---------------------------------------------------------------- recortes

# el corredor de cada calzada (de la mitad de la mediana, con 0,6 m de más, al borde de la franja) quita todas las
# capas; el tablero de cada paso, el paso de la página (hitos) y sus faroles y letreros (veredas)
func recortes() -> Array:
	var out := []
	for k in 2:
		for pol in corredor(k):
			out.append({"poligono": pol, "capas": []})
	for p in pasos:
		out.append({"poligono": cinta(p["pts"], p["hw"] + 0.5), "capas": ["hitos", "veredas"]})
	return out


# el corredor de la calzada k, en trozos de ~100 m (polígonos simples y cajas chicas para recorte.gd)
func corredor(k: int) -> Array:
	var out := []
	var E: Array = est[k]
	var i := 0
	while i < E.size() - 1:
		var j := mini(i + 50, E.size() - 1)
		var a := PackedVector2Array()
		var b := PackedVector2Array()
		for n in range(i, j + 1):
			var e: Dictionary = E[n]
			a.append(off(e["q"], e["hs"] + 0.6))
			b.append(off(e["q"], e["ob"]))
		b.reverse()
		a.append_array(b)
		out.append(a)
		i = j
	return out


static func cinta(pts: PackedVector2Array, hw: float) -> PackedVector2Array:
	var a := PackedVector2Array()
	var b := PackedVector2Array()
	for i in pts.size():
		var t := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var n := Vector2(-t.y, t.x)
		a.append(pts[i] + n * hw)
		b.append(pts[i] - n * hw)
	b.reverse()
	a.append_array(b)
	return a


# los puntos de grilla que tiene que cubrir el relieve (las teselas que espera)
func puntos() -> Array:
	var out := []
	for k in 2:
		for e in est[k]:
			out.append(off(e["q"], e["ob"]))
	for p in pasos:
		out.append_array(Array(p["pts"]))
	return out


# ---------------------------------------------------------------- armar (con el relieve: S)

static func V(g: Vector2, h: float) -> Vector3:
	return Vector3(g.x, h, -g.y)


# el suelo de cada estación, afuera del corredor: dentro, las teselas ya no tienen terreno (el recorte lo quitó antes
# de que suelo.gd lo leyera, y S.E() ahí extrapola de otros triángulos). «gb», el del borde del recorte (un poco
# afuera: el triángulo que queda calza ahí con la franja); «gref», el promedio con el de la otra calzada a la misma
# altura del eje, para que las dos mitades de la mediana se junten
func _suelos() -> void:
	for k in 2:
		for e in est[k]:
			var g := off(e["q"], e["ob"] - 0.05)
			e["gb"] = S.E(g.x, g.y)
	for k in 2:
		var O: Array = est[1 - k]
		for e in est[k]:
			var gref: float = e["gb"]
			if not O.is_empty():
				var pr := proyectar(1 - k, off(e["q"], e["hs"]))
				var i := clampi(int(round((pr.x - O[0]["d"]) / PASO)), 0, O.size() - 1)
				if absf(O[i]["d"] - pr.x) < PASO * 2.0:
					gref = (gref + O[i]["gb"]) / 2.0
			e["gref"] = gref


# las alturas de cada estación: la calzada a H_CALZADA sobre el suelo de referencia menos el hondo, el ramal lo mismo
# con el suelo de su lado, el muro hasta su alto (o hasta el suelo, bajo un paso) y el talud hasta el suelo del borde
func _alturas(e: Dictionary) -> void:
	var h: float = e["gref"] + H_CALZADA - e["D"]
	e["h"] = h
	var he := h
	if e.has("ramal"):
		he = e["gb"] + H_CALZADA - e["ramal"]["D"]
	e["he"] = he
	var hw: float = clampf(e["hwe"], 0.0, maxf(0.0, e["gb"] - he))
	if e["bajo"]:
		hw = maxf(0.0, e["gb"] - he)
	e["hw"] = hw
	e["gt"] = e["gb"]


# la sección de una estación: [offset, altura, el material de la banda que sigue, su color, vertical]
func _seccion(e: Dictionary) -> Array:
	var h: float = e["h"]
	var he: float = e["he"]
	var oc: float = e["oc"]
	var oi: float = e["oi"]
	var gap := oc - oi
	var c1 := oc - minf(CUNETA, gap)
	var hg := h  # el alto de la berma entre calzada y ramal, al pie
	if gap > CUNETA + 0.5 and (he - h) / (gap - CUNETA) > 1.0:
		hg = he  # un muro entre los dos
	var top: float = he + e["hw"]
	return [
		[maxf(e["hs"], 4.5), h + 0.02, "tierra", K["tierra"]],
		[4.5, h, "asfalto", K["asfalto"]],
		[oc, h, "hormigon", K["hormigon"]],
		[c1, h + 0.02, "moldaje", K["muro"]],
		[c1, hg, "maleza", K["seco"]],
		[oi, he, "asfalto", K["asfalto"]],
		[e["oe"], he, "hormigon", K["hormigon"]],
		[e["ow"], he + 0.02, "moldaje", K["muro"]],
		[e["ow"], top, "moldaje", K["tapa"]],
		[e["ow"] - TAPA, top, "maleza", K["seco"]],
		[e["ot"], e["gt"], "maleza", K["seco"]],
		[e["ob"], e["gb"], "", Color()],
	]


func armar_suelo(m: Malla) -> void:
	_suelos()
	for k in 2:
		for e in est[k]:
			_alturas(e)
	for k in 2:
		var E: Array = est[k]
		var prev := []
		for i in E.size():
			var e: Dictionary = E[i]
			var sec := _seccion(e)
			var pts := []
			for s in sec:
				pts.append(V(off(e["q"], s[0]), s[1]))
			if i > 0:
				var adentro := Vector3(e["q"]["n"].x, 0, -e["q"]["n"].y)
				for j in sec.size() - 1:
					var a: Vector3 = prev[j]
					var b: Vector3 = pts[j]
					var c: Vector3 = pts[j + 1]
					var d: Vector3 = prev[j + 1]
					var vertical: bool = absf(sec[j][0] - sec[j + 1][0]) < 0.01
					var n := (c - a).cross(d - b)
					if n.length_squared() < 1e-8:
						continue
					n = n.normalized()
					if n.dot(adentro if vertical else Vector3.UP) < 0:
						n = -n
					m.cara([a, b, c, d], sec[j][3], sec[j][2], n)
			prev = pts
		_lineas(m, k)


# las líneas de la calzada (12–15 cm): el borde interior continuo a 3,5 m de la línea de OSM, el exterior al borde
# de las pistas, la línea entre pistas segmentada (4,5 m cada 12 m), la de la tercera pista donde la hay; y los
# bordes del ramal
func _lineas(m: Malla, k: int) -> void:
	var E: Array = est[k]
	var banda := func(a: Dictionary, b: Dictionary, o0: float, o1: float, ha: float, hb: float) -> void:
		m.cara([V(off(a["q"], o0), ha), V(off(b["q"], o0), hb), V(off(b["q"], o1), hb), V(off(a["q"], o1), ha)],
			K["blanco"], "pintura", Vector3.UP)
	for i in E.size() - 1:
		var a: Dictionary = E[i]
		var b: Dictionary = E[i + 1]
		var ha: float = a["h"] + 0.012
		var hb: float = b["h"] + 0.012
		banda.call(a, b, 3.42, 3.57, ha, hb)
		var ea: float = -3.5 - 3.5 * a["q"]["e"]
		var eb: float = -3.5 - 3.5 * b["q"]["e"]
		m.cara([V(off(a["q"], ea + 0.075), ha), V(off(b["q"], eb + 0.075), hb), V(off(b["q"], eb - 0.075), hb), V(off(a["q"], ea - 0.075), ha)],
			K["blanco"], "pintura", Vector3.UP)
		if a.has("ramal") and b.has("ramal") and a["oi"] - a["oe"] > 3.0 and b["oi"] - b["oe"] > 3.0:
			for o in [["oi", -0.6], ["oe", 0.6]]:
				var oa: float = a[o[0]] + o[1]
				var ob: float = b[o[0]] + o[1]
				m.cara([V(off(a["q"], oa + 0.07), a["he"] + 0.012), V(off(b["q"], ob + 0.07), b["he"] + 0.012),
					V(off(b["q"], ob - 0.07), b["he"] + 0.012), V(off(a["q"], oa - 0.07), a["he"] + 0.012)], K["blanco"], "pintura", Vector3.UP)
	var d0: float = E[0]["d"]
	var d1: float = E[-1]["d"]
	var d := d0 + 6.0
	while d + 4.5 < d1:
		for o in [0.0, -3.5]:
			var qa := en(k, d)
			if o < 0.0 and qa["e"] < 0.5:
				continue
			var qb := en(k, d + 4.5)
			var ha := altura(k, d) + 0.012
			var hb := altura(k, d + 4.5) + 0.012
			m.cara([V(off(qa, o + 0.06), ha), V(off(qb, o + 0.06), hb), V(off(qb, o - 0.06), hb), V(off(qa, o - 0.06), ha)],
				K["blanco"], "pintura", Vector3.UP)
		d += 12.0


# la altura de la calzada k a la distancia d (interpolada entre estaciones)
func altura(k: int, d: float) -> float:
	var E: Array = est[k]
	var i := clampi(int((d - E[0]["d"]) / PASO), 0, E.size() - 2)
	while i < E.size() - 2 and E[i + 1]["d"] < d:
		i += 1
	var a: Dictionary = E[i]
	var b: Dictionary = E[i + 1]
	return lerpf(a["h"], b["h"], clampf((d - a["d"]) / maxf(b["d"] - a["d"], 1e-6), 0.0, 1.0))


# las defensas de la mediana, los cierros, los postes de la luz, los pasos y los autos
func armar_cosas(m: Malla) -> void:
	for k in 2:
		var E: Array = est[k]
		var def := []
		var cierro := []
		for e in E:
			var q: Dictionary = e["q"]
			if e["hs"] > 2.5:
				var o: float = e["hs"] - 0.8
				def.append(V(off(q, o), e["h"]))
			if e["bajo"]:
				if cierro.size() > 1:
					Mob.cerco(m, cierro, "malla", 1.8, K["malla"])
				cierro = []
			else:
				cierro.append(V(off(q, e["ob"] + 0.45), e["gb"]))
		Mob.cerco(m, def, "defensa", 0.75, K["defensa"])
		if cierro.size() > 1:
			Mob.cerco(m, cierro, "malla", 1.8, K["malla"])
	_postes(m)
	for p in pasos:
		_paso(m, p)
	_autos(m)


# postes de la luz en la mediana angosta, cada 45 m: 12 m, con dos brazos curvos sobre las pistas interiores
func _postes(m: Malla) -> void:
	var E: Array = est[0]
	var d: float = E[0]["d"] + 20.0
	while d < E[-1]["d"] - 10.0:
		var q := en(0, d)
		var i := clampi(int((d - E[0]["d"]) / PASO), 0, E.size() - 1)
		var e: Dictionary = E[i]
		var c := off(q, e["hs"])
		if e["hs"] < 9.0 and q["lit"] and not bajo_paso(c):
			var h := altura(0, d)
			var base := V(c, h)
			m.tubo(base, base + Vector3(0, 11.2, 0), 0.13, 0.08, 8, K["poste"], K["poste"])
			for s in [1.0, -1.0]:
				var dir: Vector3 = Vector3(q["n"].x, 0, -q["n"].y) * s
				var p1 := base + Vector3(0, 11.2, 0)
				var p2: Vector3 = p1 + dir * 0.9 + Vector3(0, 0.55, 0)
				var p3: Vector3 = p2 + dir * 1.8 + Vector3(0, 0.15, 0)
				m.tubo(p1, p2, 0.07, 0.06, 6, K["poste"], K["poste"])
				m.tubo(p2, p3, 0.06, 0.05, 6, K["poste"], K["poste"])
				m.tubo(p3 - dir * 0.1 - Vector3(0, 0.12, 0), p3 + dir * 0.55 - Vector3(0, 0.12, 0), 0.16, 0.12, 8, K["poste"], K["lampara"])
				lamparas.append(p3 + dir * 0.2 - Vector3(0, 0.35, 0))
		d += 45.0


# un paso superior: el tablero a la altura de la calle de punta a punta (la de la página, sobre el suelo, donde no hay
# corredor), y sobre el corredor la losa, las veredas, el parapeto con su baranda de malla, y las pilas en la mediana
func _paso(m: Malla, p: Dictionary) -> void:
	var pts: PackedVector2Array = p["pts"]
	var hw: float = p["hw"]
	var D := [0.0]
	for i in pts.size() - 1:
		D.append(D[-1] + pts[i].distance_to(pts[i + 1]))
	var L: float = D[-1]
	var at := func(u: float) -> Array:
		var i := 0
		while i < pts.size() - 2 and D[i + 1] < u:
			i += 1
		var t := clampf((u - D[i]) / maxf(D[i + 1] - D[i], 1e-6), 0.0, 1.0)
		var dir := (pts[i + 1] - pts[i]).normalized()
		return [pts[i].lerp(pts[i + 1], t), Vector2(-dir.y, dir.x)]
	var ha: float = S.E(pts[0].x, pts[0].y) + H_CALLE + 0.015
	var hb: float = S.E(pts[-1].x, pts[-1].y) + H_CALLE + 0.015
	var H := func(u: float) -> float: return lerpf(ha, hb, u / L)
	# dónde cruza el corredor
	var pols := []
	for k in 2:
		pols.append_array(corredor(k))
	var u0 := INF
	var u1 := -INF
	var u := 0.0
	while u <= L:
		var g: Vector2 = at.call(u)[0]
		for pol in pols:
			if Geometry2D.is_point_in_polygon(g, pol):
				u0 = minf(u0, u); u1 = maxf(u1, u)
				break
		u += 0.5
	var sobre := func(x: float) -> bool: return x >= u0 - 2.0 and x <= u1 + 2.0
	var vereda := 2.2
	var us := []
	u = 0.0
	while u < L:
		us.append(u)
		u += 1.0
	us.append(L)
	for i in us.size() - 1:
		var ua: float = us[i]
		var ub: float = us[i + 1]
		var A: Array = at.call(ua)
		var B: Array = at.call(ub)
		var hA: float = H.call(ua)
		var hB: float = H.call(ub)
		var P := func(X: Array, o: float, h: float) -> Vector3: return V(X[0] + X[1] * o, h)
		var en_puente: bool = sobre.call((ua + ub) / 2.0)
		var ov := hw - vereda if en_puente else hw
		m.cara([P.call(A, -ov, hA), P.call(B, -ov, hB), P.call(B, ov, hB), P.call(A, ov, hA)], K["asfalto"], "asfalto", Vector3.UP)
		# líneas: doble al medio, segmentadas entre pistas
		for o in [-0.2, 0.2]:
			m.cara([P.call(A, o - 0.06, hA + 0.01), P.call(B, o - 0.06, hB + 0.01), P.call(B, o + 0.06, hB + 0.01), P.call(A, o + 0.06, hA + 0.01)], K["blanco"], "pintura", Vector3.UP)
		if fmod(ua, 8.0) < 3.0:
			for o in [-3.7, 3.7]:
				m.cara([P.call(A, o - 0.06, hA + 0.01), P.call(B, o - 0.06, hB + 0.01), P.call(B, o + 0.06, hB + 0.01), P.call(A, o + 0.06, hA + 0.01)], K["blanco"], "pintura", Vector3.UP)
		for s in [-1.0, 1.0]:
			var n: Vector3 = Vector3(A[1].x, 0, -A[1].y) * s
			if en_puente:
				# vereda, solera, parapeto
				m.cara([P.call(A, s * ov, hA + 0.17), P.call(B, s * ov, hB + 0.17), P.call(B, s * (hw - 0.3), hB + 0.17), P.call(A, s * (hw - 0.3), hA + 0.17)], K["hormigon"], "hormigon", Vector3.UP)
				m.cara([P.call(A, s * ov, hA), P.call(B, s * ov, hB), P.call(B, s * ov, hB + 0.17), P.call(A, s * ov, hA + 0.17)], K["hormigon"], "liso", -n)
				m.cara([P.call(A, s * (hw - 0.3), hA + 0.17), P.call(B, s * (hw - 0.3), hB + 0.17), P.call(B, s * (hw - 0.3), hB + 0.7), P.call(A, s * (hw - 0.3), hA + 0.7)], K["losa"], "moldaje", -n)
				m.cara([P.call(A, s * (hw - 0.3), hA + 0.7), P.call(B, s * (hw - 0.3), hB + 0.7), P.call(B, s * hw, hB + 0.7), P.call(A, s * hw, hA + 0.7)], K["tapa"], "moldaje", Vector3.UP)
				m.cara([P.call(A, s * hw, hA - LOSA), P.call(B, s * hw, hB - LOSA), P.call(B, s * hw, hB + 0.7), P.call(A, s * hw, hA + 0.7)], K["losa"], "moldaje", n)
			else:
				var ga: float = S.E((A[0] + A[1] * s * hw).x, (A[0] + A[1] * s * hw).y)
				var gb: float = S.E((B[0] + B[1] * s * hw).x, (B[0] + B[1] * s * hw).y)
				m.cara([P.call(A, s * hw, ga - 0.3), P.call(B, s * hw, gb - 0.3), P.call(B, s * hw, hB), P.call(A, s * hw, hA)], K["hormigon"], "liso", n)
		if en_puente:
			m.cara([P.call(A, -hw, hA - LOSA), P.call(B, -hw, hB - LOSA), P.call(B, hw, hB - LOSA), P.call(A, hw, hA - LOSA)], K["losa"], "moldaje", Vector3.DOWN)
	if u0 > u1:
		return
	# baranda de malla sobre el parapeto
	for s in [-1.0, 1.0]:
		var bar := []
		u = u0 - 2.0
		while u <= u1 + 2.0:
			var X: Array = at.call(clampf(u, 0.0, L))
			bar.append(V(X[0] + X[1] * s * (hw - 0.15), H.call(u) + 0.7))
			u += 2.0
		Mob.cerco(m, bar, "malla", 1.25, K["baranda"])
		for i in bar.size() - 1:
			m.tubo(bar[i] + Vector3(0, 1.25, 0), bar[i + 1] + Vector3(0, 1.25, 0), 0.04, 0.04, 6, K["baranda"], K["baranda"])
	# las pilas: donde la línea del tablero cruza el medio de la mediana, una viga cabezal y columnas cada ~5 m
	var med := PackedVector2Array()
	for e in est[0]:
		med.append(off(e["q"], e["hs"]))
	for i in pts.size() - 1:
		for j in med.size() - 1:
			var x = Geometry2D.segment_intersects_segment(pts[i], pts[i + 1], med[j], med[j + 1])
			if x == null:
				continue
			var uc: float = D[i] + pts[i].distance_to(x)
			var X: Array = at.call(uc)
			var hm := altura(0, est[0][j]["d"])
			var top: float = H.call(uc) - LOSA
			var giro := atan2(X[1].y, X[1].x)
			m.bloque(V(X[0], top - 0.45), Vector3(2.0 * hw - 1.0, 0.9, 1.1), K["pila"], giro)
			var o := -hw + 2.5
			while o <= hw - 2.4:
				var g: Vector2 = X[0] + X[1] * o
				m.tubo(V(g, hm - 0.3), V(g, top - 0.85), 0.42, 0.42, 12, K["pila"], K["pila"])
				o += maxf(4.0, (2.0 * hw - 5.0) / 3.0)


# unos autos por cada calzada, en las pistas, donde la pendiente es suave
func _autos(m: Malla) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(nombre)
	var tipos := [Auto.SEDAN, Auto.SEDAN, Auto.HATCHBACK, Auto.SUV, Auto.SUV, Auto.CAMIONETA, Auto.FURGON, Auto.CAMION, Auto.CAMION]
	var solido := m.solido
	m.solido = false
	for k in 2:
		var E: Array = est[k]
		var d: float = E[0]["d"] + 15.0 + rng.randf() * 40.0
		while d < E[-1]["d"] - 15.0:
			var q := en(k, d)
			var pend := absf(altura(k, d + 3.0) - altura(k, d - 3.0)) / 6.0
			var t: int = tipos[rng.randi() % tipos.size()]
			var o := -1.75 if t == Auto.CAMION or rng.randf() < 0.55 else 1.75
			if pend < 0.035:
				var g := off(q, o)
				var f := Malla.Marco.new(g.x, g.y, atan2(q["t"].y, q["t"].x), altura(k, d))
				Auto.modelo(m, f, t, PALETA[rng.randi() % PALETA.size()])
			d += 35.0 + rng.randf() * 110.0
	m.solido = solido
