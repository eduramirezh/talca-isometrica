# El mobiliario de las calles medidas en fotos (modelos/perfiles.gd: los perfiles y sus cruces): postes de la luz y de
# los cables, cables con su comba, semáforos de poste y de mástil, columnas de luz del bandejón, paraderos, letreros,
# banderas, cierros, señales y palmeras. Medidas de verdad, no las del pixel art; cada pieza en un marco
# (Malla.Marco) cuyo eje v apunta hacia donde mira (la calzada, o el tránsito que llega) y u a su derecha.
#
# Aproximado: las alturas son las típicas de lo que se ve en las fotos (postes de hormigón de 9 m de media tensión y de
# 14 m de alta tensión, cabezas de semáforo de 0,9 m, letreros de 3–4 m de alto a 4–5 m del suelo), no medidas en el
# lugar; el mazo de cables de telecomunicaciones va como cables sueltos a 5,8–6,5 m, que es como se ve de cerca.
extends RefCounted

const Malla := preload("res://malla.gd")

const K := {
	"asfalto": Color("5a5a58"), "berma": Color("615f5b"), "blanco": Color("e8e6de"), "amarillo": Color("e0b52e"),
	"azul": Color("7f9fc2"), "azul2": Color("5f86b6"), "gris": Color("6a6866"), "solera": Color("bdbab2"),
	"vereda": Color("aaa69c"), "pasto": Color("6f8a45"), "pasto2": Color("8a8a55"), "tierra": Color("9c8664"),
	"hormigon": Color("a7a49b"), "poste": Color("b3b0a8"), "fierro": Color("4a4c4e"), "cable": Color("1e1f20"),
	"aislador": Color("d9d6cf"), "lampara": Color("d8d4c4"), "vidrio": Color("8fa3ad"), "madera": Color("8a6a46"),
	"zinc": Color("a4a8a8"), "teja": Color("8a4a32"), "muro": Color("4f6fa8"), "banca": Color("5e4a3a"),
	"semaforo": Color("232526"), "verde": Color("3fae5a"), "rojo": Color("c8402f"), "galvanizado": Color("a9adb0"),
	"parque": Color("5f8a3e"), "maleza": Color("8a8a55"),
}

# las alturas de amarre de los cables en cada tipo de poste: [u, v, h] del marco del poste (v hacia la calzada)
const AMARRES := {
	"media": [[0, -0.8, 8.76], [0, 0.0, 8.76], [0, 0.8, 8.76]],
	"alta": [[0, -1.3, 10.6], [0, 1.3, 10.6], [0, -1.3, 11.8], [0, 1.3, 11.8], [0, -1.3, 13.0], [0, 1.3, 13.0]],
	"simple": [],
}


# un poste de hormigón: «media» (9 m, cruceta de tres aisladores atravesada a la línea), «alta» (14 m, tres crucetas de
# dos aisladores a cada lado), «simple» (7 m, sin cruceta). Con farol: un brazo curvo de 2 m sobre la calzada con su
# luminaria (v). pintado: «rojo», la base en franjas rojas y blancas hasta 2,5 m
static func poste(m: Malla, f: Malla.Marco, tipo := "media", farol := true, pintado := "") -> void:
	var alto := 14.2 if tipo == "alta" else 9.0 if tipo == "media" else 7.0
	m.cilindro(f, 0, 0, 0.18 if tipo == "alta" else 0.16, -0.4, 1.0, K["poste"], "hormigon", 8)
	m.cilindro(f, 0, 0, 0.16 if tipo == "alta" else 0.13, 1.0, alto, K["poste"], "hormigon", 8)
	if pintado == "rojo":
		for k in 5:
			m.cilindro(f, 0, 0, 0.17, k * 0.5, k * 0.5 + 0.5, K["rojo"] if k % 2 == 0 else K["blanco"], "pintura", 8)
	if tipo == "media":
		m.caja(f, -0.06, -0.9, 0.06, 0.9, 8.4, 8.52, K["poste"], "hormigon")
		for v in [-0.8, 0.0, 0.8]:
			m.cilindro(f, 0, v, 0.05, 8.52, 8.72, K["aislador"], "liso", 6)
	elif tipo == "alta":
		for h in [10.2, 11.4, 12.6]:
			m.caja(f, -0.07, -1.45, 0.07, 1.45, h, h + 0.14, K["poste"], "hormigon")
			for v in [-1.3, 1.3]:
				m.cilindro(f, 0, v, 0.06, h - 0.25, h, K["aislador"], "liso", 6)
	# el mazo de telecomunicaciones: una abrazadera a 6 m
	m.caja(f, -0.17, -0.17, 0.17, 0.17, 5.9, 6.4, K["fierro"], "metal")
	if farol:
		var h0 := 7.5
		m.caja(f, -0.03, 0.12, 0.03, 0.9, h0, h0 + 0.06, K["fierro"], "metal")
		m.caja(f, -0.03, 0.85, 0.03, 2.0, h0 + 0.2, h0 + 0.26, K["fierro"], "metal")
		m.caja(f, -0.03, 0.85, 0.03, 0.91, h0, h0 + 0.26, K["fierro"], "metal")
		m.caja(f, -0.16, 1.75, 0.16, 2.45, h0 + 0.12, h0 + 0.26, K["lampara"], "metal")


# los puntos de amarre de un poste en el mundo (sus conductores), y el del mazo de telecomunicaciones
static func amarres(f: Malla.Marco, tipo: String) -> Array:
	var out := []
	for a in AMARRES.get(tipo, []):
		out.append(f.V(a[0], a[1], a[2] + 0.06))
	return out


static func amarre_telecom(f: Malla.Marco) -> Vector3:
	return f.V(0, 0, 6.2)


# un cable de a a b con comba (la flecha a medio vano), de grosor g: dos tiras cruzadas por tramo
static func cable(m: Malla, a: Vector3, b: Vector3, flecha: float, g := 0.012, col := Color("1e1f20")) -> void:
	var prev := a
	for k in range(1, 9):
		var t := k / 8.0
		var q := a.lerp(b, t) - Vector3(0, flecha * 4.0 * t * (1.0 - t), 0)
		var d := (q - prev).normalized()
		var lat := d.cross(Vector3.UP).normalized() * g
		var up := Vector3(0, g, 0)
		m.cara([prev - lat, q - lat, q + lat, prev + lat], col, "liso", Vector3.UP)
		m.cara([prev - up, q - up, q + up, prev + up], col, "liso", lat.normalized())
		prev = q


# un vano entre dos postes: sus conductores, del más cercano al más cercano, y n cables de telecomunicaciones (el mazo
# se abre un poco a medio vano; cada uno con su comba)
static func vano(m: Malla, fa: Malla.Marco, ta: String, fb: Malla.Marco, tb: String, telecom: int) -> void:
	var solido := m.solido
	m.solido = false
	var aa := amarres(fa, ta)
	var bb := amarres(fb, tb)
	var largo := fa.V(0, 0, 0).distance_to(fb.V(0, 0, 0))
	for p in aa:
		if bb.is_empty():
			break
		var q: Vector3 = bb[0]
		for c in bb:
			if p.distance_to(c) < p.distance_to(q):
				q = c
		cable(m, p, q, 0.012 * largo + 0.1)
	var ta_ := amarre_telecom(fa)
	var tb_ := amarre_telecom(fb)
	for i in telecom:
		var o := Vector3(0, -0.05 * i, 0)
		cable(m, ta_ + o, tb_ + o, 0.015 * largo + 0.25 + 0.03 * i, 0.014 if i % 3 else 0.022)
	m.solido = solido


# una columna de luz del bandejón: 10 m de acero galvanizado con dos brazos curvos de 1,8 m, uno sobre cada calzada (v
# a lo largo del bandejón; u hacia la derecha)
static func farol_doble(m: Malla, f: Malla.Marco, brazo := 1.8) -> void:
	m.cilindro(f, 0, 0, 0.12, 0.0, 0.6, K["galvanizado"], "metal", 8)
	m.cilindro(f, 0, 0, 0.08, 0.6, 9.6, K["galvanizado"], "metal", 8)
	for l in [-1, 1]:
		m.caja(f, min(0.0, l * brazo), -0.03, max(0.0, l * brazo), 0.03, 9.5, 9.56, K["galvanizado"], "metal")
		m.caja(f, l * brazo - 0.35 if l > 0 else l * brazo - 0.0, -0.14, l * brazo + 0.0 if l > 0 else l * brazo + 0.35, 0.14, 9.42, 9.54, K["lampara"], "metal")


# un semáforo: «poste» (3,5 m con una cabeza de tres luces mirando a v), «mastil» (un mástil galvanizado en L de 6 m
# con un brazo de `largo` m sobre la calzada, a la izquierda de quien llega, y una cabeza en la punta y otra en el poste).
# camara: una cámara sobre el poste
static func semaforo(m: Malla, f: Malla.Marco, forma := "poste", largo := 6.0, cabezas := 1, camara := false) -> void:
	if forma == "mastil":
		m.cilindro(f, 0, 0, 0.13, 0.0, 6.6, K["galvanizado"], "metal", 10)
		# el brazo sale hacia la calzada: a la izquierda del que llega es -u del marco (v mira al que llega)
		m.caja(f, -largo, -0.06, 0.0, 0.06, 6.2, 6.34, K["galvanizado"], "metal")
		cabeza(m, f, -largo + 0.5, 0.15, 5.0)
		if cabezas > 1:
			cabeza(m, f, 0, 0.2, 2.6)
		# el letrero bajo la cabeza del poste
		m.caja(f, -0.3, 0.15, 0.3, 0.18, 1.9, 2.5, Color("f2f2f2"), "pintura")
	else:
		var h := 6.5 if camara else 3.6
		m.cilindro(f, 0, 0, 0.07, 0.0, h, K["semaforo"], "metal", 8)
		cabeza(m, f, 0, 0.15, 2.4)
		if camara:
			m.caja(f, -0.03, 0.0, 0.03, 1.2, 6.3, 6.38, K["semaforo"], "metal")
			cabeza(m, f, 0, 1.1, 5.2)
			m.caja(f, -0.12, -0.2, 0.12, 0.25, 6.5, 6.7, Color("e8e8e8"), "pintura")


# una cabeza de tres luces con su visera, centrada en (u, v) del marco desde h (su base) hacia arriba, mirando a +v
static func cabeza(m: Malla, f: Malla.Marco, u: float, v: float, h: float) -> void:
	m.caja(f, u - 0.17, v - 0.12, u + 0.17, v + 0.12, h, h + 0.9, K["semaforo"], "metal")
	m.caja(f, u - 0.32, v - 0.14, u + 0.32, v - 0.12, h - 0.05, h + 0.95, K["semaforo"], "metal")
	for k in 3:
		var col: Color = [K["rojo"], K["amarillo"], K["verde"]][k]
		m.caja(f, u - 0.1, v + 0.12, u + 0.1, v + 0.14, h + 0.66 - k * 0.28, h + 0.84 - k * 0.28, col.darkened(0.35), "pintura")


# un paradero: «curvo» (fierro y techo curvo translúcido, con banca), «madera» (postes y techo de zinc de una agua),
# «techo» (muros pintados de azul y techo de tejas). Mira a la calzada (v), 4 m de largo (u)
static func paradero(m: Malla, f: Malla.Marco, tipo: String) -> void:
	match tipo:
		"curvo":
			for u in [-1.9, 1.9]:
				m.caja(f, u - 0.05, -0.75, u + 0.05, -0.65, 0.0, 2.5, K["fierro"], "metal")
			m.caja(f, -1.9, -0.72, 1.9, -0.68, 0.3, 2.2, K["vidrio"], "vidrio")
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


# un letrero publicitario: un panel de ancho × alto desde `base`, mirando a +v (con caras 2, también a -v), en uno o
# dos pies de acero; colores: [el fondo, una franja]; pie «rojo»: un poste pintado en franjas rojas y blancas
static func letrero(m: Malla, f: Malla.Marco, ancho: float, alto: float, base: float, colores: Array, caras := 1, pie := "") -> void:
	var c0 := Color(colores[0]) if colores.size() > 0 else Color("e8e4da")
	var c1 := Color(colores[1]) if colores.size() > 1 else c0.darkened(0.3)
	var dos := ancho > 3.0
	for u in ([-ancho * 0.3, ancho * 0.3] if dos else [0.0]):
		m.caja(f, u - 0.11, -0.11, u + 0.11, 0.11, 0.0, base + alto * 0.5, K["galvanizado"], "metal")
		if pie == "rojo":
			for k in 5:
				m.cilindro(f, u, 0, 0.14, k * 0.5, k * 0.5 + 0.5, K["rojo"] if k % 2 == 0 else K["blanco"], "pintura", 8)
	m.caja(f, -ancho / 2, -0.12, ancho / 2, 0.12, base, base + alto, K["fierro"], "metal")
	for l in ([1, -1] if caras > 1 else [1]):
		var v: float = l * 0.13
		m.caja(f, -ancho / 2 + 0.08, min(v, v + l * 0.01), ancho / 2 - 0.08, max(v, v + l * 0.01), base + 0.08, base + alto - 0.08, c0, "pintura")
		m.caja(f, -ancho / 2 + 0.08, min(v, v + l * 0.02), ancho / 2 - 0.08, max(v, v + l * 0.02), base + 0.08, base + alto * 0.28, c1, "pintura")


# una bandera de una marca: un mástil de `alto` m con un paño vertical de 0,9 × 2,8 m arriba
static func bandera(m: Malla, f: Malla.Marco, alto: float, col: Color) -> void:
	m.cilindro(f, 0, 0, 0.04, 0.0, alto, K["galvanizado"], "metal", 6)
	m.caja(f, 0.04, -0.01, 0.94, 0.01, alto - 3.0, alto - 0.2, col, "tela")
	m.caja(f, 0.04, -0.012, 0.94, 0.012, alto - 0.6, alto - 0.45, Color("f4f4f0"), "tela")


# una señal: «pare» (un octógono rojo de 0,75 m a 2,2 m), «disco» (un disco azul de 0,6 m: mantenga su derecha)
static func senal(m: Malla, f: Malla.Marco, forma: String) -> void:
	m.cilindro(f, 0, 0, 0.03, 0.0, 2.3, K["galvanizado"], "metal", 6)
	var col := K["rojo"] if forma == "pare" else Color("2457a6")
	var r := 0.38 if forma == "pare" else 0.3
	var n := 8 if forma == "pare" else 12
	var poli := PackedVector2Array()
	for i in n:
		var a := TAU * (i + 0.5) / n
		poli.append(Vector2(r * cos(a), 2.2 + r * sin(a)))
	for l in [0.04, 0.05]:
		var q := []
		for p in poli:
			q.append(f.V(p.x, l, p.y))
		if l > 0.045:
			q.reverse()
		m.cara(q, col if l < 0.045 else K["galvanizado"], "pintura", f.N(0, 1 if l < 0.045 else -1))


# un cierro a lo largo de puntos del suelo (Vector3, cada uno a su altura): «malla» (postes cada 2,5 m, una malla de
# alambre que deja ver lo de atrás, Mat «rejilla», y un tubo arriba), «seto» (un seto tupido), «tablas», «muro» (con pilares cada 3 m), «defensa» (una defensa caminera de
# perfil W en postes), «tubo» (una baranda de tubo de dos barras)
static func cerco(m: Malla, pts: Array, forma: String, alto: float, col: Color) -> void:
	for i in pts.size() - 1:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var L := Vector2(b.x - a.x, b.z - a.z).length()
		if L < 0.05:
			continue
		var d := Vector3(b.x - a.x, 0, b.z - a.z) / L
		var n := Vector3(-d.z, 0, d.x)
		match forma:
			"seto":
				_banda(m, a, b, n, 0.45, -0.2, alto, col)
			"muro", "tablas":
				_banda(m, a, b, n, 0.1 if forma == "muro" else 0.03, 0.0, alto, col)
				if forma == "muro":
					var k := 0.0
					while k < L:
						_pilar(m, a + d * k, 0.35, -0.2, alto + 0.15, Color("e3d9bf") if col.r > col.b else col.darkened(0.1))
						k += 3.0
			"malla":
				var k := 0.0
				while k <= L:
					_pilar(m, a + d * k, 0.06, -0.2, alto, col.darkened(0.3))
					k += 2.5
				var solido := m.solido
				m.solido = false
				m.cara([a + Vector3(0, 0.05, 0), b + Vector3(0, 0.05, 0), b + Vector3(0, alto, 0), a + Vector3(0, alto, 0)], col.lightened(0.15), "rejilla", n)
				m.cara([b + Vector3(0, 0.05, 0), a + Vector3(0, 0.05, 0), a + Vector3(0, alto, 0), b + Vector3(0, alto, 0)], col.lightened(0.15), "rejilla", -n)
				m.tubo(a + Vector3(0, alto, 0), b + Vector3(0, alto, 0), 0.025, 0.025, 5, col.darkened(0.3), col.darkened(0.3))
				m.solido = solido
			"defensa":
				var k := 0.0
				while k <= L:
					_pilar(m, a + d * k, 0.12, -0.3, alto, Color("6d7073"))
					k += 2.0
				_banda(m, a + Vector3(0, alto - 0.33, 0), b + Vector3(0, alto - 0.33, 0), n, 0.08, 0.0, 0.31, col)
			"tubo":
				for h in [0.5, alto]:
					m.tubo(a + Vector3(0, h, 0), b + Vector3(0, h, 0), 0.03, 0.03, 6, col, col)
				var k := 0.0
				while k <= L:
					m.tubo(a + d * k, a + d * k + Vector3(0, alto, 0), 0.03, 0.03, 6, col, col)
					k += 1.6


# un pilar cuadrado de lado w sobre p, de h0 a h1
static func _pilar(m: Malla, p: Vector3, w: float, h0: float, h1: float, col: Color) -> void:
	m.bloque(p + Vector3(0, (h0 + h1) / 2, 0), Vector3(w, h1 - h0, w), col)


# una banda vertical de grosor g de a a b (corrida o a lo largo de n), de h0 a h1 sobre cada punto
static func _banda(m: Malla, a: Vector3, b: Vector3, n: Vector3, g: float, h0: float, h1: float, col: Color) -> void:
	var o := n * (g / 2)
	var y0 := Vector3(0, h0, 0)
	var y1 := Vector3(0, h1, 0)
	m.cara([a + o + y0, b + o + y0, b + o + y1, a + o + y1], col, "liso", n)
	m.cara([b - o + y0, a - o + y0, a - o + y1, b - o + y1], col, "liso", -n)
	m.cara([a + o + y1, b + o + y1, b - o + y1, a - o + y1], col.lightened(0.05), "liso", Vector3.UP)
