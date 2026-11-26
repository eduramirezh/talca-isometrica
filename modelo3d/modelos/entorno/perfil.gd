# Una calle medida en fotos, de cerca (modelos/perfiles.gd la arma): su franja de una línea de cierre a la otra, con la
# calzada y su demarcación, el bandejón, las ciclovías, las soleras (amarillas donde van pintadas), las veredas, el
# pasto y la tierra, y su mobiliario (mobiliario.gd): postes con sus cables, columnas de luz del bandejón, paraderos,
# resaltos, cebras y semáforos. Todo sale de su entrada de data/perfiles.json (pipeline/perfiles.py: el eje de OSM
# corrido a la imagen, las secciones medidas en fotos, las bocas de las calles que llegan, y el lugar de cada poste,
# paradero y árbol), y se dibuja solo de «desde» a «hasta»: lo de antes o después es de un cruce (cruce.gd).
#
# Aproximado: los anchos (±0,5 m, por las pistas y los autos de las fotos), dónde empieza y termina cada sección (±20 m:
# una foto cada 30–40 m), el largo de las líneas segmentadas (3 m de línea y 5 de espacio) y de los resaltos (4 m).
extends RefCounted

const Malla := preload("res://malla.gd")
const Mob := preload("res://modelos/entorno/mobiliario.gd")

const TRAMO := 20.0  # m de eje por pieza de la franja (y por recorte)
const PASO := 4.0  # m: el muestreo a lo largo del eje dentro de un tramo
const CAPAS := ["suelo", "usos", "patios", "autos"]
# alturas sobre el relieve (E): la calzada de la página va a 0,12; las soleras suben 15 cm
const H_CALZADA := 0.12
const H_PINTURA := 0.132
const H_SOLERA := 0.27
const H_BAJO := 0.10  # tierra y pasto junto a la calzada, sin solera
const CALZADA := ["pista", "ciclo", "berma"]
const K := Mob.K

var clave: String
var D := {}  # la entrada de data/perfiles.json
var P := PackedVector2Array()  # el eje
var S0 := PackedFloat64Array()  # la distancia de cada punto del eje
var S: RefCounted  # el relieve (suelo.gd), que pone perfiles.gd


func _init(k: String, d: Dictionary) -> void:
	clave = k
	D = d
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


func desde() -> float:
	return float(D.get("desde", 0.0))


func hasta() -> float:
	return float(D.get("hasta", largo()))


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


func medio(sec: Dictionary) -> float:
	return float(sec.get("bandejon", 0.0)) / 2.0 if sec["centro"] == "bandejon" else 0.0


# lo que hay a un lado (-1 izquierda, 1 derecha) en s: [[tipo, d0, d1, extra]], de adentro hacia afuera, el último
# hasta la línea de cierre o el borde de la calle de la página, lo que esté más lejos
func bandas(s: float, lado: int) -> Array:
	var sec := seccion(s)
	var d := medio(sec)
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
		"pasto": return [K["pasto"], "maleza"]
		"tierra": return [K["tierra"], "tierra"]
	return [K["tierra"], "tierra"]


# ---- lo que se arma ----

# los tramos de TRAMO m de lo que se dibuja: [s0, s1]
func tramos() -> Array:
	var out := []
	var s := desde()
	while s < hasta() - 0.01:
		var s1 := minf(s + TRAMO, hasta())
		out.append([s, s1])
		s = s1
	return out


func recortes() -> Array:
	var out := []
	for tr in tramos():
		var izq := PackedVector2Array()
		var der := PackedVector2Array()
		for q in muestras(tr[0], tr[1]):
			der.append(en(q, maxf(bandas(q, 1)[-1][2], borde(q, 1)) + 0.05))
			izq.append(en(q, -maxf(bandas(q, -1)[-1][2], borde(q, -1)) - 0.05))
		izq.reverse()
		var p := simple(der + izq)
		if Geometry2D.is_polygon_clockwise(p):
			p.reverse()
		out.append({"poligono": p, "capas": CAPAS})
	return out


# sin los puntos que casi no cambian el contorno (a menos de 3 cm de la recta de sus vecinos): al cortar los
# triángulos de las teselas, dejaban astillas que no se pueden triangular
static func simple(p: PackedVector2Array) -> PackedVector2Array:
	var q := p.duplicate()
	var cambio := true
	while cambio and q.size() > 3:
		cambio = false
		for i in q.size():
			var a := q[(i - 1 + q.size()) % q.size()]
			var b := q[i]
			var c := q[(i + 1) % q.size()]
			if Geometry2D.get_closest_point_to_segment(b, a, c).distance_to(b) < 0.03:
				q.remove_at(i)
				cambio = true
				break
	return q


# las estaciones de muestreo entre s0 y s1: cada PASO m y en cada vértice del eje, cambio de sección, borde de boca y nariz
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
	var nz := float(D.get("nariz", 0.0))
	if nz > s0 + 0.05 and nz < s1 - 0.05:
		cortes.append(nz)
	cortes.sort()
	var out := PackedFloat64Array()
	for c in cortes:
		if out.is_empty() or c - out[out.size() - 1] > 0.05:
			out.append(c)
	return out


# lo que se pone cuando están las teselas de sus puntos: [[Vector2…], Callable(malla)]
func objetos() -> Array:
	var out := []
	var ps: Array = D["postes"]
	for p in ps:
		out.append([[Vector2(p[0], p[1])], _poste.bind(p)])
	for v in D.get("vanos", []):
		var a: Array = ps[v[0]]
		var b: Array = ps[v[1]]
		out.append([[Vector2(a[0], a[1]), Vector2(b[0], b[1])], _vano.bind(a, b)])
	for p in D.get("faroles", []):
		out.append([[Vector2(p[0], p[1])], _farol.bind(p)])
	for p in D["paraderos"]:
		out.append([[Vector2(p[0], p[1])], _paradero.bind(p)])
	for p in D["semaforos"]:
		out.append([[Vector2(p[0], p[1])], _semaforo.bind(p)])
	for c in D["lomos"]:
		out.append([[Vector2(c[1], c[2])], lomo.bind(c)])
	for c in D["cebras"]:
		out.append([[Vector2(c[1], c[2])], cebra.bind(c)])
	return out


# ---- la franja: bandas, soleras y pintura ----

# (nivel: lo que sube toda la calle sobre las que pisa, un enlace sobre la calzada de la que sale, para que no compartan
# un plano)
func V(p: Vector2, h: float) -> Vector3:
	return Malla.P(p.x, p.y, S.E(p.x, p.y) + h + float(D.get("nivel", 0.0)))


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
	var nz := float(D.get("nariz", 0.0))
	for i in ss.size() - 1:
		var sa := ss[i]
		var sb := ss[i + 1]
		var sm := (sa + sb) / 2
		var sec := seccion(sm)
		var med := medio(sec)
		var abierto := med > 0 and (boca(sm, -1, 2.0) or boca(sm, 1, 2.0) or sm < nz)
		if med > 0:
			if abierto:
				cinta(m, sa, sb, -med, med, H_CALZADA, K["asfalto"], "asfalto")
			else:
				bandejon(m, sa, sb, sec, med, nz > 0 and absf(sa - nz) < 0.06)
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
				elif tipo == "isla":
					continue  # la isla de un cruce: la dibuja cruce.gd
				var h := alto(tipo, tras)
				var c := color(tipo, b[3])
				cinta(m, sa, sb, lado * d0, lado * d1, h, c[0], c[1])
				# el escalón con lo de adentro: la cara de la solera (pintada si es amarilla) o el borde de una berma
				escalon(m, sa, sb, lado * d0, previo, h, -lado if h > previo else lado, c[0], c[1])
				if tipo == "solera":
					tras = true
				previo = h
			# el faldón en la línea de cierre, hasta bajo el suelo de la página (no donde sigue la isla de un cruce)
			if en_boca or bs[bs.size() - 1][0] != "isla":
				escalon(m, sa, sb, lado * bs[bs.size() - 1][2], previo, -0.3, lado, K["tierra"], "liso")
		pintura(m, sa, sb, sec, med, abierto)


# el bandejón: su relleno (maleza, pasto, tierra o un parque) entre dos soleras de hormigón (o amarillas), con una
# baranda negra si la lleva; en su nariz, la cara de la punta
func bandejon(m: Malla, sa: float, sb: float, sec: Dictionary, med: float, nariz: bool) -> void:
	var rel: String = sec.get("mediana", "maleza")
	var cr: Color = {"pasto": K["pasto"], "tierra": K["tierra"], "parque": K["parque"]}.get(rel, K["maleza"])
	var amarilla: bool = sec.get("solera_mediana", "") == "amarilla"
	var cs: Color = K["amarillo"] if amarilla else K["solera"]
	var ms := "pintura" if amarilla else "granito"
	cinta(m, sa, sb, -med + 0.15, med - 0.15, H_SOLERA - 0.03, cr, "tierra" if rel == "tierra" else "maleza")
	for l in [-1, 1]:
		cinta(m, sa, sb, l * med, l * (med - 0.15), H_SOLERA, cs, ms)
		escalon(m, sa, sb, l * med, H_CALZADA, H_SOLERA, l, cs, ms)
		escalon(m, sa, sb, l * (med - 0.15), H_SOLERA - 0.03, H_SOLERA, -l, cs, ms)
	if nariz:
		var a := en(sa, -med)
		var b := en(sa, med)
		var t: Vector2 = marco_en(sa)[2]
		m.cara([V(b, H_CALZADA), V(a, H_CALZADA), V(a, H_SOLERA), V(b, H_SOLERA)], cs, ms, Vector3(-t.x, 0, t.y))
	if sec.get("baranda_mediana", false):
		var solido := m.solido
		m.solido = false
		var a := en(sa, -med + 0.3)
		var b := en(sb, -med + 0.3)
		for h in [0.55, 1.1]:
			m.tubo(V(a, H_SOLERA + h), V(b, H_SOLERA + h), 0.025, 0.025, 5, K["semaforo"], K["semaforo"])
		m.tubo(V(a, H_SOLERA), V(a, H_SOLERA + 1.12), 0.03, 0.03, 5, K["semaforo"], K["semaforo"])
		m.solido = solido


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
	elif sec["centro"] == "bandejon" and abierto and not cruce:
		# frente a una boca de un solo lado y antes de la nariz: el borde de las pistas junto al bandejón, en línea
		for l in [-1, 1]:
			raya(m, sa, sb, l * (med - 0.1), 0.12)
	for li in 2:
		var lado: int = [-1, 1][li]
		var bs := bandas(sm, lado)
		var pistas := 0
		for j in bs.size():
			var b: Array = bs[j]
			if b[0] == "pista":
				pistas += 1
				# entre dos pistas del mismo sentido, segmentada
				if pistas >= 2 and not bocas[li]:
					segmentada(m, sa, sb, lado * b[1])
			elif b[0] == "ciclo":
				raya(m, sa, sb, lado * (b[1] + 0.08), 0.12)
			elif b[0] in ["berma", "solera", "tierra", "pasto", "vereda", "ciclovia"] and sec.get("bordes", false) and not bocas[li]:
				if pistas > 0 and j > 0 and bs[j - 1][0] == "pista":
					raya(m, sa, sb, lado * (b[1] - 0.15), 0.12)


# ---- los objetos ----

func lugar(p: Array, h := 0.0) -> Malla.Marco:
	var x: float = p[0]
	var y: float = p[1]
	return Malla.Marco.new(x, y, atan2(p[3], p[2]), S.E(x, y) + h)


func _poste(m: Malla, p: Array) -> void:
	var tipo: String = p[4] if p.size() > 4 else "media"
	var farol: bool = p.size() <= 5 or int(p[5]) == 1
	Mob.poste(m, lugar(p, H_SOLERA - 0.05), tipo, farol)


func _vano(m: Malla, a: Array, b: Array) -> void:
	var ta: String = a[4] if a.size() > 4 else "media"
	var tb: String = b[4] if b.size() > 4 else "media"
	var tel := mini(int(a[6]) if a.size() > 6 else 0, int(b[6]) if b.size() > 6 else 0)
	Mob.vano(m, lugar(a, H_SOLERA - 0.05), ta, lugar(b, H_SOLERA - 0.05), tb, tel)


# una columna del bandejón: [x, y, tx, ty, distancia del brazo]: el marco con v a lo largo del eje
func _farol(m: Malla, p: Array) -> void:
	var x: float = p[0]
	var y: float = p[1]
	Mob.farol_doble(m, Malla.Marco.new(x, y, atan2(p[3], p[2]), S.E(x, y) + H_SOLERA), float(p[4]))


func _paradero(m: Malla, p: Array) -> void:
	Mob.paradero(m, lugar(p, H_SOLERA), p[4])


func _semaforo(m: Malla, p: Array) -> void:
	Mob.semaforo(m, lugar(p, H_SOLERA))


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
