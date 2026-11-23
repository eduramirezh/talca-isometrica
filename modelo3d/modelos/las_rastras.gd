# La Avenida Las Rastras (Ruta K-35) de cerca, de la Avenida San Miguel al puente sobre el canal (1,9 km): la calzada
# con su demarcación, el bandejón del tramo de dos calzadas, las ciclovías azules, las soleras (amarillas donde van
# pintadas), las veredas, el pasto y la tierra de las bermas, los postes de la luz con sus cables, los paraderos, los
# resaltos, los pasos de cebra y los semáforos. Reemplaza en su franja (de una línea de cierre a la otra) el suelo de
# la página, sus usos y sus autos (recortes()); los árboles son los de la página (arboleda.gd), que pone también las
# hileras de álamos y eucaliptos del perfil, y la luz de los faroles le llega por GLOW, como la de los hitos.
#
# Todo sale de data/perfiles.json (pipeline/perfiles.py: el eje de OSM, las secciones de config/perfiles.json medidas
# en 78 fotos de Mapillary de 2018 a 2025, los cruces con las calles del mapa y el lugar de cada poste, paradero y
# cebra), en la copia de modelo3d/datos/ que hace make modelo3d; la página dibuja lo mismo (src/js/12-perfiles.js).
# Las medidas son de verdad, no las del pixel art: líneas de 12 cm, soleras de 15 cm, cables de 2 cm.
#
# Aproximado: los anchos (±0,5 m, por las pistas y los autos de las fotos), dónde empieza y termina cada sección (±20 m:
# una foto cada 40 m), el lado y el paso de los postes (cada ~35 m en las fotos), los paraderos (tres tipos, por las
# fotos), el largo de las líneas segmentadas (3 m de línea y 5 de espacio) y de los resaltos (4 m); y al norte de
# s = 1562 m, donde no hay fotos, el último tramo fotografiado.
#
# La franja cruza nueve teselas: cada tramo de 20 m se arma cuando están las teselas de sus dos puntas (mapa.cargadas;
# hasta POR_CUADRO por cuadro),
# con el relieve de todas las cargadas (suelo.gd sumar()), y queda armado aunque la tesela se suelte.
extends Node3D

const Malla := preload("res://malla.gd")
const Suelo := preload("res://modelos/entorno/suelo.gd")

const DATOS := "res://datos/perfiles.json"
const CLAVE := "avenida-las-rastras"
const TRAMO := 20.0  # m de eje por pieza de la franja (y por recorte)
const PASO := 4.0  # m: el muestreo a lo largo del eje dentro de un tramo
const POR_CUADRO := 12  # tramos por cuadro, como mucho (~2,5 ms cada uno en el hilo principal: una tesela entera de una vez eran 130 ms)
const CAPAS := ["suelo", "usos", "patios", "autos"]
# alturas sobre el relieve (E): la calzada de la página va a 0,12; las soleras suben 15 cm
const H_CALZADA := 0.12
const H_PINTURA := 0.132
const H_SOLERA := 0.27
const H_BAJO := 0.10  # tierra y pasto junto a la calzada, sin solera
const CALZADA := ["pista", "ciclo", "berma"]

const K := {
	"asfalto": Color("5a5a58"), "berma": Color("615f5b"), "blanco": Color("e8e6de"), "amarillo": Color("e0b52e"),
	"azul": Color("7f9fc2"), "azul2": Color("5f86b6"), "gris": Color("6a6866"), "solera": Color("bdbab2"),
	"vereda": Color("aaa69c"), "pasto": Color("6f8a45"), "pasto2": Color("8a8a55"), "tierra": Color("9c8664"),
	"hormigon": Color("a7a49b"), "poste": Color("b3b0a8"), "fierro": Color("4a4c4e"), "cable": Color("1e1f20"),
	"aislador": Color("d9d6cf"), "lampara": Color("d8d4c4"), "vidrio": Color("8fa3ad"), "madera": Color("8a6a46"),
	"zinc": Color("a4a8a8"), "teja": Color("8a4a32"), "muro": Color("4f6fa8"), "banca": Color("5e4a3a"),
	"semaforo": Color("232526"), "verde": Color("3fae5a"), "rojo": Color("c8402f"),
}

var D := {}  # el perfil de data/perfiles.json
var P := PackedVector2Array()  # el eje
var S0 := PackedFloat64Array()  # la distancia de cada punto del eje
var S: Suelo
var pendientes := []  # [s0, s1, claves de teselas] de los tramos que faltan
var objetos := []  # [Vector2 lugar, Callable] los postes, paraderos… que faltan, por su tesela
var hechas := {}  # las teselas ya sumadas al relieve
var mias := {}  # las teselas que toca la franja
var cableados := {}  # los vanos de cable ya puestos (índice del primer poste)


func _init() -> void:
	var f := FileAccess.open(DATOS, FileAccess.READ)
	if f == null:
		push_warning("las_rastras.gd: no está %s (make modelo3d)" % DATOS)
		return
	var todo = JSON.parse_string(f.get_as_text())
	if todo == null or not todo.has(CLAVE):
		push_warning("las_rastras.gd: %s no tiene %s" % [DATOS, CLAVE])
		return
	D = todo[CLAVE]
	var e: Array = D["eje"]
	var x := 0.0
	var y := 0.0
	for i in range(0, e.size(), 2):
		x += e[i] / 10.0
		y += e[i + 1] / 10.0
		P.append(Vector2(x, y))
	S0.append(0.0)
	for i in range(1, P.size()):
		S0.append(S0[i - 1] + P[i - 1].distance_to(P[i]))


# ---- el eje ----

func largo() -> float:
	return S0[S0.size() - 1]


# el punto del eje en s y su normal a la derecha, en un vértice la del ángulo (más larga: el borde corrido d queda a d)
func marco_en(s: float) -> Array:
	s = clampf(s, 0.0, largo())
	var i := 0
	while i < P.size() - 2 and S0[i + 1] < s:
		i += 1
	var t := (P[i + 1] - P[i]).normalized()
	var u := s - S0[i]
	var n := Vector2(t.y, -t.x)
	var k := -1
	if u < 1e-3 and i > 0:
		k = i
	elif S0[i + 1] - s < 1e-3 and i + 1 < P.size() - 1:
		k = i + 1
	if k > 0:
		var t0 := (P[k] - P[k - 1]).normalized()
		var t1 := (P[k + 1] - P[k]).normalized()
		var m := Vector2(t0.y, -t0.x) + Vector2(t1.y, -t1.x)
		if m.length() > 1e-6:
			m = m.normalized()
			n = m / maxf(0.5, m.dot(Vector2(t0.y, -t0.x)))
	return [P[i] + t * u, n, t]


func en(s: float, d: float) -> Vector2:
	var m := marco_en(s)
	return m[0] + m[1] * d


func seccion(s: float) -> Dictionary:
	for sec in D["secciones"]:
		if s >= sec["s"][0] and s < sec["s"][1]:
			return sec
	return D["secciones"][D["secciones"].size() - 1]


func boca(s: float, lado: int, r := 0.0) -> bool:
	for b in D["bocas"]:
		if int(b[2]) == lado and s >= b[0] - r and s <= b[1] + r:
			return true
	return false


# lo que hay a un lado (-1 izquierda, 1 derecha) en s: [[tipo, d0, d1, extra]], de adentro hacia afuera, el último
# hasta la línea de cierre o el borde de la calle de la página, lo que esté más lejos
func bandas(s: float, lado: int) -> Array:
	var sec := seccion(s)
	var d := float(sec.get("bandejon", 0.0)) / 2.0 if sec["centro"] == "bandejon" else 0.0
	var out := []
	var lista: Array = sec["O" if lado < 0 else "E"]
	for b in lista:
		out.append([b[0], d, d + float(b[1]), b[2] if b.size() > 2 else ""])
		d += float(b[1])
	out[out.size() - 1][2] = maxf(d, borde(s, lado))
	return out


# hasta dónde llega a un lado la calle de la página (su margen de lotes): de las calles que toma el perfil
func borde(s: float, lado: int) -> float:
	var m := 0.0
	for c in D["calles"]:
		if s >= c[1] - 1.0 and s <= c[2] + 1.0:
			m = maxf(m, -float(c[3]) if lado < 0 else float(c[4]))
	return m


func calzada(s: float, lado: int) -> float:
	var d := 0.0
	for b in bandas(s, lado):
		if b[0] in CALZADA:
			d = b[2]
	return d


func alto(tipo: String, tras_solera: bool) -> float:
	if tipo == "solera":
		return H_SOLERA
	if tipo in CALZADA:
		return H_CALZADA
	if tras_solera:
		return H_SOLERA - (0.03 if tipo in ["pasto", "tierra"] else 0.0)
	return H_BAJO if tipo in ["pasto", "tierra"] else H_CALZADA + 0.02


func color(tipo: String, extra: String) -> Array:
	match tipo:
		"pista": return [K["asfalto"], "asfalto"]
		"berma": return [K["berma"], "asfalto"]
		"ciclo": return [K["azul"], "pintura"]
		"ciclovia": return [K["azul2"] if extra == "azul" else K["gris"], "asfalto" if extra != "azul" else "pintura"]
		"solera": return [K["amarillo"] if extra == "amarilla" else K["solera"], "pintura" if extra == "amarilla" else "granito"]
		"vereda": return [K["vereda"], "hormigon"]
		"pasto": return [K["pasto"], "liso"]
		"tierra": return [K["tierra"], "liso"]
	return [K["tierra"], "liso"]


# ---- la escena ----

func recortes() -> Array:
	var out := []
	if D.is_empty():
		return out
	var s := 0.0
	while s < largo() - 0.01:
		var s1 := minf(s + TRAMO, largo())
		var izq := PackedVector2Array()
		var der := PackedVector2Array()
		for q in muestras(s, s1):
			der.append(en(q, maxf(bandas(q, 1)[-1][2], borde(q, 1)) + 0.05))
			izq.append(en(q, -maxf(bandas(q, -1)[-1][2], borde(q, -1)) - 0.05))
		izq.reverse()
		var p := der + izq
		if Geometry2D.is_polygon_clockwise(p):
			p.reverse()
		out.append({"poligono": p, "capas": CAPAS})
		s = s1
	return out


# las estaciones de muestreo entre s0 y s1: cada PASO m y en cada vértice del eje, cambio de sección y borde de boca
func muestras(s0: float, s1: float) -> PackedFloat64Array:
	var cortes := [s0, s1]
	var s := s0 + PASO
	while s < s1 - 0.5:
		cortes.append(s)
		s += PASO
	for v in S0:
		if v > s0 + 0.05 and v < s1 - 0.05:
			cortes.append(v)
	for sec in D["secciones"]:
		for v in sec["s"]:
			if v > s0 + 0.05 and v < s1 - 0.05:
				cortes.append(float(v))
	for b in D["bocas"]:
		for v in [b[0], b[1]]:
			if v > s0 + 0.05 and v < s1 - 0.05:
				cortes.append(float(v))
	cortes.sort()
	var out := PackedFloat64Array()
	for c in cortes:
		if out.is_empty() or c - out[out.size() - 1] > 0.05:
			out.append(c)
	return out


func _ready() -> void:
	if D.is_empty():
		set_process(false)
		return
	var s := 0.0
	while s < largo() - 0.01:
		var s1 := minf(s + TRAMO, largo())
		pendientes.append([s, s1])
		s = s1
	for p in D["postes"]:
		objetos.append([Vector2(p[0], p[1]), poste.bind(p)])
	for p in D["paraderos"]:
		objetos.append([Vector2(p[0], p[1]), paradero.bind(p)])
	for p in D["semaforos"]:
		objetos.append([Vector2(p[0], p[1]), semaforo.bind(p)])
	for c in D["lomos"]:
		objetos.append([Vector2(c[1], c[2]), lomo.bind(c)])
	for c in D["cebras"]:
		objetos.append([Vector2(c[1], c[2]), cebra.bind(c)])


func clave(p: Vector2, tam: float) -> String:
	return "%d_%d" % [floori(p.x / tam), floori(p.y / tam)]


func _process(_d: float) -> void:
	var mapa = get_parent().get("mapa")
	if mapa == null:
		return
	if mias.is_empty():
		var s := 0.0
		while s <= largo():
			for d in [-16.0, 0.0, 16.0]:
				mias[clave(en(s, d), mapa.tam)] = true
			s += 10.0
	for k in mapa.cargadas:
		var t: Node3D = mapa.cargadas[k]
		if mias.has(k) and not hechas.has(k) and t != null and t.is_inside_tree():
			if S == null:
				S = Suelo.new(t)
			else:
				S.sumar(t)
			hechas[k] = true
	var t0 := Time.get_ticks_msec()
	var piso := Malla.new()
	var cosas := Malla.new()
	var n := 0
	for tr in pendientes.duplicate():
		if n >= POR_CUADRO:
			break
		if hechas.has(clave(en(tr[0], 0), mapa.tam)) and hechas.has(clave(en(tr[1], 0), mapa.tam)):
			franja(piso, tr[0], tr[1])
			pendientes.erase(tr)
			n += 1
	for o in objetos.duplicate():
		if hechas.has(clave(o[0], mapa.tam)):
			o[1].call(cosas)
			objetos.erase(o)
	if n:
		cables(cosas)
	if not piso.vacia():
		piso.construir(self, "rastras-suelo", false)
	if not cosas.vacia():
		cosas.construir(self, "rastras-objetos")
	if n:
		print("las_rastras.gd: %d tramos en %d ms (faltan %d)" % [n, Time.get_ticks_msec() - t0, pendientes.size()])
	if pendientes.is_empty() and objetos.is_empty():
		set_process(false)


# ---- la franja: bandas, soleras y pintura ----

func V(p: Vector2, h: float) -> Vector3:
	return Malla.P(p.x, p.y, S.E(p.x, p.y) + h)


# una cinta entre las distancias d0 y d1 (con signo: a la derecha del eje) de sa a sb, a la altura h
func cinta(m: Malla, sa: float, sb: float, d0: float, d1: float, h: float, col: Color, mat: String) -> void:
	var a0 := en(sa, d0)
	var a1 := en(sa, d1)
	var b0 := en(sb, d0)
	var b1 := en(sb, d1)
	m.cara([V(a0, h), V(b0, h), V(b1, h), V(a1, h)], col, mat, Vector3.UP)


# una cara vertical a lo largo del eje en la distancia d, de h0 a h1, mirando hacia el lado de signo `mira`
func escalon(m: Malla, sa: float, sb: float, d: float, h0: float, h1: float, mira: float, col: Color, mat: String) -> void:
	if absf(h1 - h0) < 0.005:
		return
	var a := en(sa, d)
	var b := en(sb, d)
	var nn: Vector2 = marco_en((sa + sb) / 2)[1].normalized() * signf(mira)
	m.cara([V(a, h0), V(b, h0), V(b, h1), V(a, h1)], col, mat, Vector3(nn.x, 0, -nn.y))


func franja(m: Malla, s0: float, s1: float) -> void:
	var ss := muestras(s0, s1)
	for i in ss.size() - 1:
		var sa := ss[i]
		var sb := ss[i + 1]
		var sm := (sa + sb) / 2
		var sec := seccion(sm)
		var med := float(sec.get("bandejon", 0.0)) / 2.0 if sec["centro"] == "bandejon" else 0.0
		var abierto := med > 0 and (boca(sm, -1, 2.0) or boca(sm, 1, 2.0))
		if med > 0:
			if abierto:
				cinta(m, sa, sb, -med, med, H_CALZADA, K["asfalto"], "asfalto")
			else:
				# el bandejón: 1,5 m de tierra con maleza entre dos soleras de hormigón (la foto de 2025)
				cinta(m, sa, sb, -med + 0.15, med - 0.15, H_SOLERA - 0.03, K["pasto2"], "liso")
				for l in [-1, 1]:
					cinta(m, sa, sb, l * med, l * (med - 0.15), H_SOLERA, K["solera"], "granito")
					escalon(m, sa, sb, l * med, H_CALZADA, H_SOLERA, l, K["solera"], "granito")
					escalon(m, sa, sb, l * (med - 0.15), H_SOLERA - 0.03, H_SOLERA, -l, K["solera"], "granito")
		for lado in [-1, 1]:
			var bs := bandas(sm, lado)
			var en_boca := boca(sm, lado)
			var previo := H_CALZADA
			var tras := false
			for b in bs:
				var tipo: String = b[0]
				var d0: float = b[1]
				var d1: float = b[2]
				if en_boca and not (tipo in CALZADA):
					tipo = "berma"
				var h := alto(tipo, tras)
				var c := color(tipo, b[3])
				cinta(m, sa, sb, lado * d0, lado * d1, h, c[0], c[1])
				# el escalón con lo de adentro: la cara de la solera (pintada si es amarilla) o el borde de una berma
				escalon(m, sa, sb, lado * d0, previo, h, -lado if h > previo else lado, c[0], c[1])
				if tipo == "solera":
					tras = true
				previo = h
			# el faldón en la línea de cierre, hasta bajo el suelo de la página
			escalon(m, sa, sb, lado * bs[bs.size() - 1][2], previo, -0.3, lado, K["tierra"], "liso")
		pintura(m, sa, sb, sec, med, abierto)


func raya(m: Malla, sa: float, sb: float, d: float, w: float, col := Color.WHITE) -> void:
	cinta(m, sa, sb, d - w / 2, d + w / 2, H_PINTURA, K["blanco"] if col == Color.WHITE else col, "pintura")


# 3 m de línea y 5 de espacio, contados desde s = 0
func segmentada(m: Malla, sa: float, sb: float, d: float) -> void:
	var k := floorf(sa / 8.0) * 8.0
	while k < sb:
		var a := maxf(sa, k)
		var b := minf(sb, k + 3.0)
		if b > a:
			raya(m, a, b, d, 0.12)
		k += 8.0


func achurado(sm: float) -> Array:
	for a in D["achurados"]:
		if sm >= a[0] and sm <= a[1]:
			return a
	return []


func pintura(m: Malla, sa: float, sb: float, sec: Dictionary, med: float, abierto: bool) -> void:
	var sm := (sa + sb) / 2
	var bocas := [boca(sm, -1), boca(sm, 1)]
	var cruce: bool = bocas[0] and bocas[1]
	# el centro
	var ach := achurado(sm)
	if not ach.is_empty():
		for l in [-1, 1]:
			raya(m, sa, sb, l * 1.25, 0.12)
		# las diagonales, cada 3 m
		var k := ceilf(sa / 3.0) * 3.0
		while k < sb:
			var p0 := en(k, -1.2)
			var p1 := en(minf(k + 2.4, sb), 1.2)
			var n: Vector2 = (p1 - p0).normalized()
			var o := Vector2(-n.y, n.x) * 0.25
			m.cara([V(p0 - o, H_PINTURA), V(p1 - o, H_PINTURA), V(p1 + o, H_PINTURA), V(p0 + o, H_PINTURA)], K["blanco"], "pintura", Vector3.UP)
			k += 3.0
	elif sec["centro"] == "segmentada" and not cruce:
		segmentada(m, sa, sb, 0.0)
	elif sec["centro"] == "doble" and not cruce:
		for l in [-1, 1]:
			raya(m, sa, sb, l * 0.12, 0.12)
	for li in 2:
		var lado: int = [-1, 1][li]
		var bs := bandas(sm, lado)
		var pistas := 0
		for b in bs:
			if b[0] == "pista":
				pistas += 1
				# entre dos pistas del mismo sentido, segmentada
				if pistas == 2 and not bocas[li]:
					segmentada(m, sa, sb, lado * b[1])
			elif b[0] == "ciclo":
				raya(m, sa, sb, lado * (b[1] + 0.08), 0.12)
			elif b[0] in ["berma", "solera", "tierra", "pasto", "vereda", "ciclovia"] and sec.get("bordes", false) and not bocas[li]:
				if pistas > 0 and bs[bs.find(b) - 1][0] == "pista":
					raya(m, sa, sb, lado * (b[1] - 0.15), 0.12)


# ---- los objetos ----

func lugar(p: Array, h := 0.0) -> Malla.Marco:
	var x: float = p[0]
	var y: float = p[1]
	return Malla.Marco.new(x, y, atan2(p[3], p[2]), S.E(x, y) + h)


# un poste de hormigón de 9 m con su cruceta de tres aisladores (media tensión) y un farol de brazo curvo sobre la
# calzada (las fotos: postes de la luz y de los cables a la vez, cada ~35 m, de un lado). En el marco, v apunta a la calzada
func poste(m: Malla, p: Array) -> void:
	var f := lugar(p, H_SOLERA - 0.05)
	m.cilindro(f, 0, 0, 0.16, -0.4, 1.0, K["poste"], "hormigon", 8)
	m.cilindro(f, 0, 0, 0.13, 1.0, 9.0, K["poste"], "hormigon", 8)
	m.caja(f, -0.9, -0.06, 0.9, 0.06, 8.4, 8.52, K["poste"], "hormigon")
	for u in [-0.8, 0.0, 0.8]:
		m.cilindro(f, u, 0, 0.05, 8.52, 8.72, K["aislador"], "liso", 6)
	# el brazo del farol: sube y sale 2 m hacia la calzada, con la luminaria al final
	m.caja(f, -0.03, 0.12, 0.03, 0.9, 7.5, 7.56, K["fierro"], "metal")
	m.caja(f, -0.03, 0.85, 0.03, 2.0, 7.7, 7.76, K["fierro"], "metal")
	m.caja(f, -0.03, 0.85, 0.03, 0.91, 7.5, 7.76, K["fierro"], "metal")
	m.caja(f, -0.16, 1.75, 0.16, 2.45, 7.62, 7.76, K["lampara"], "metal")


# los cables de media tensión entre postes seguidos del mismo lado (a menos de 60 m), con su comba
func cables(m: Malla) -> void:
	var ps: Array = D["postes"]
	var solido := m.solido
	m.solido = false
	for i in ps.size() - 1:
		var a: Array = ps[i]
		var b: Array = ps[i + 1]
		var pa := Vector2(a[0], a[1])
		var pb := Vector2(b[0], b[1])
		if cableados.has(i) or pa.distance_to(pb) > 60.0 or not (hechas.has(clave(pa, get_parent().mapa.tam)) and hechas.has(clave(pb, get_parent().mapa.tam))):
			continue
		cableados[i] = true
		var fa := lugar(a, H_SOLERA - 0.05)
		var fb := lugar(b, H_SOLERA - 0.05)
		for u in [-0.8, 0.0, 0.8]:
			var q0 := fa.V(u, 0, 8.76)
			var q1 := fb.V(u, 0, 8.76)
			var prev := q0
			for k in range(1, 9):
				var t := k / 8.0
				var q := q0.lerp(q1, t) - Vector3(0, 0.6 * 4.0 * t * (1.0 - t), 0)
				var d := (q - prev).normalized()
				var lat := d.cross(Vector3.UP).normalized() * 0.012
				var up := Vector3(0, 0.012, 0)
				m.cara([prev - lat, q - lat, q + lat, prev + lat], K["cable"], "liso", Vector3.UP)
				m.cara([prev - up, q - up, q + up, prev + up], K["cable"], "liso", lat.normalized())
				prev = q
	m.solido = solido


# un paradero: «curvo» (fierro y techo curvo translúcido, con banca: frente al Paseo Las Rastras, 2018, y en la
# vereda poniente, 2025), «madera» (postes y techo de zinc de una agua, 2022), «techo» (muros pintados de azul y techo
# de tejas, 2022). Mira a la calzada (v), 4 m de largo (u)
func paradero(m: Malla, p: Array) -> void:
	var f := lugar(p, H_SOLERA)
	var tipo: String = p[4]
	match tipo:
		"curvo":
			for u in [-1.9, 1.9]:
				m.caja(f, u - 0.05, -0.75, u + 0.05, -0.65, 0.0, 2.5, K["fierro"], "metal")
			m.caja(f, -1.9, -0.72, 1.9, -0.68, 0.3, 2.2, K["vidrio"], "vidrio")
			# el techo curvo, en cinco facetas
			var prev := Vector2(-0.8, 2.5)
			for k in range(1, 6):
				var a := k / 5.0 * PI * 0.5
				var q := Vector2(-0.8 + 1.7 * sin(a), 2.25 + 0.25 * cos(a))
				m.cara([f.V(-2.0, prev.x, prev.y), f.V(2.0, prev.x, prev.y), f.V(2.0, q.x, q.y), f.V(-2.0, q.x, q.y)], K["vidrio"], "vidrio", Vector3.UP)
				prev = q
			m.caja(f, -1.5, -0.6, 1.5, -0.25, 0.42, 0.48, K["fierro"], "metal")
		"madera":
			for u in [-2.4, 2.4]:
				for v in [-1.2, 0.9]:
					m.caja(f, u - 0.06, v - 0.06, u + 0.06, v + 0.06, 0.0, 2.4 if v < 0 else 2.2, K["madera"], "liso")
			m.caja(f, -2.4, -1.26, 2.4, -1.14, 0.2, 2.0, K["madera"], "liso")
			m.cara([f.V(-2.6, -1.4, 2.45), f.V(2.6, -1.4, 2.45), f.V(2.6, 1.1, 2.2), f.V(-2.6, 1.1, 2.2)], K["zinc"], "metal", Vector3.UP)
			m.caja(f, -2.0, -1.1, 2.0, -0.7, 0.42, 0.48, K["banca"], "liso")
		_:
			m.caja(f, -1.8, -1.0, 1.8, -0.85, 0.0, 2.2, K["muro"], "liso")
			for u in [-1.8, 1.65]:
				m.caja(f, u, -1.0, u + 0.15, 0.4, 0.0, 2.2, K["muro"], "liso")
			m.prisma(f, m.rect(-2.0, -1.2, 2.0, 0.6), 2.2, 2.25, K["teja"], "teja")
			m.cara([f.V(-2.0, -1.2, 2.25), f.V(2.0, -1.2, 2.25), f.V(2.0, -0.3, 2.7), f.V(-2.0, -0.3, 2.7)], K["teja"], "teja", Vector3.UP)
			m.cara([f.V(2.0, 0.6, 2.25), f.V(-2.0, 0.6, 2.25), f.V(-2.0, -0.3, 2.7), f.V(2.0, -0.3, 2.7)], K["teja"], "teja", Vector3.UP)
			m.caja(f, -1.4, -0.85, 1.4, -0.5, 0.42, 0.48, K["banca"], "liso")


# un semáforo en la esquina: poste de 3,5 m con su caja de tres luces hacia la calzada, y un brazo sobre ella
func semaforo(m: Malla, p: Array) -> void:
	var f := lugar(p, H_SOLERA)
	m.cilindro(f, 0, 0, 0.07, 0.0, 5.6, K["semaforo"], "metal", 8)
	m.caja(f, -0.03, 0.0, 0.03, 4.0, 5.5, 5.6, K["semaforo"], "metal")
	for v in [0.0, 3.6]:
		var h := 2.4 if v == 0.0 else 4.6
		m.caja(f, -0.16, v - 0.12, 0.16, v + 0.12, h, h + 0.9, K["semaforo"], "metal")
		for k in 3:
			var col: Color = [K["rojo"], K["amarillo"], K["verde"]][k]
			m.caja(f, -0.17, v - 0.06, -0.16, v + 0.06, h + 0.72 - k * 0.28, h + 0.84 - k * 0.28, col.darkened(0.35), "pintura")


# un resalto: 4 m de largo y 8 cm de alto a lo ancho de la calzada, pintado de amarillo (fotos de 2022)
func lomo(m: Malla, c: Array) -> void:
	var s: float = c[0]
	var w: float = c[5]
	var o := (calzada(s, 1) - calzada(s, -1)) / 2.0
	var perfil := [[-2.0, 0.0], [-1.2, 0.07], [1.2, 0.07], [2.0, 0.0]]
	for k in perfil.size() - 1:
		var a: Array = perfil[k]
		var b: Array = perfil[k + 1]
		var pa0 := en(s + a[0], o - w / 2)
		var pa1 := en(s + a[0], o + w / 2)
		var pb0 := en(s + b[0], o - w / 2)
		var pb1 := en(s + b[0], o + w / 2)
		m.cara([V(pa0, H_CALZADA + a[1] + 0.004), V(pb0, H_CALZADA + b[1] + 0.004), V(pb1, H_CALZADA + b[1] + 0.004), V(pa1, H_CALZADA + a[1] + 0.004)],
			K["amarillo"], "pintura", Vector3.UP)


# un paso de cebra a lo ancho de la calzada: franjas de 0,5 m cada 1 m, de 3 m a lo largo de la calle
func cebra(m: Malla, c: Array) -> void:
	var s: float = c[0]
	var d := -calzada(s, -1) + 0.5
	while d < calzada(s, 1) - 0.5:
		cinta(m, s - 1.5, s + 1.5, d, d + 0.5, H_PINTURA, K["blanco"], "pintura")
		d += 1.0
