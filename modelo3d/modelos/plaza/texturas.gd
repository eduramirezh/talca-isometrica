# Texturas dibujadas en código (sin archivos): racimos de hojas, ramitas de agujas, frondas de palmera, la reja de
# arcos de los prados y la filigrana de fierro del quiosco. Se dibujan en un lienzo RGBA de punto flotante, el color
# de fondo es el medio de lo dibujado (así los mipmaps no oscurecen los bordes) y el alfa de cada mipmap se refuerza
# para que el follaje no se adelgace a lo lejos.
extends RefCounted

var w: int
var h: int
var px: PackedFloat32Array
var rng := RandomNumberGenerator.new()


func _init(ancho := 256, alto := 256, semilla := 1, fondo := Color(0.3, 0.4, 0.2, 0)) -> void:
	w = ancho; h = alto
	rng.seed = semilla
	px.resize(w * h * 4)
	for i in w * h:
		px[i * 4] = fondo.r; px[i * 4 + 1] = fondo.g; px[i * 4 + 2] = fondo.b; px[i * 4 + 3] = 0.0


func punto(x: int, y: int, col: Color, a := 1.0) -> void:
	if x < 0 or y < 0 or x >= w or y >= h:
		return
	var i := (y * w + x) * 4
	var k := col.a * a
	px[i] = lerp(px[i], col.r, k); px[i + 1] = lerp(px[i + 1], col.g, k); px[i + 2] = lerp(px[i + 2], col.b, k)
	px[i + 3] = max(px[i + 3], k)


# una elipse rellena con centro (cx, cy), semiejes (a, b), girada t; sombreada de un lado al otro (nervio)
func hoja(cx: float, cy: float, a: float, b: float, t: float, col: Color, nervio := true) -> void:
	var r := int(ceil(max(a, b))) + 1
	var ct := cos(t)
	var st := sin(t)
	for y in range(int(cy) - r, int(cy) + r + 1):
		for x in range(int(cx) - r, int(cx) + r + 1):
			var dx := x - cx
			var dy := y - cy
			var u := (dx * ct + dy * st) / a
			var v := (-dx * st + dy * ct) / b
			# punta aguda: el ancho se angosta hacia los extremos
			var d: float = u * u + v * v / max(0.15, 1.0 - u * u * 0.6)
			if d <= 1.0:
				var sh := 0.85 + 0.25 * v if nervio else 1.0
				if nervio and abs(v) < 0.12:
					sh = 1.12
				var cc := Color(col.r * sh, col.g * sh, col.b * sh, 1.0)
				punto(x, y, cc, clamp((1.0 - d) * 4.0, 0.0, 1.0))


# una línea gruesa de (x0, y0) a (x1, y1), ancho e0 al comienzo y e1 al final
func linea(x0: float, y0: float, x1: float, y1: float, e0: float, e1: float, col: Color) -> void:
	var xa := int(min(x0, x1) - max(e0, e1) - 1)
	var xb := int(max(x0, x1) + max(e0, e1) + 1)
	var ya := int(min(y0, y1) - max(e0, e1) - 1)
	var yb := int(max(y0, y1) + max(e0, e1) + 1)
	var d := Vector2(x1 - x0, y1 - y0)
	var l2: float = max(d.length_squared(), 1e-6)
	for y in range(ya, yb + 1):
		for x in range(xa, xb + 1):
			var p := Vector2(x - x0, y - y0)
			var t: float = clamp(p.dot(d) / l2, 0.0, 1.0)
			var e: float = lerp(e0, e1, t) * 0.5
			var dist := (p - d * t).length()
			if dist <= e + 0.5:
				punto(x, y, col, clamp(e + 0.5 - dist, 0.0, 1.0))


func anillo(cx: float, cy: float, r: float, e: float, col: Color) -> void:
	for y in range(int(cy - r - e - 1), int(cy + r + e + 2)):
		for x in range(int(cx - r - e - 1), int(cx + r + e + 2)):
			var d: float = abs(Vector2(x - cx, y - cy).length() - r)
			if d <= e * 0.5 + 0.5:
				punto(x, y, col, clamp(e * 0.5 + 0.5 - d, 0.0, 1.0))


func textura(refuerzo := 0.35) -> ImageTexture:
	# fondo: el color medio de lo dibujado, para que el filtrado no traiga el negro de afuera
	var s := Vector3.ZERO
	var k := 0.0
	for i in w * h:
		var a := px[i * 4 + 3]
		s += Vector3(px[i * 4], px[i * 4 + 1], px[i * 4 + 2]) * a
		k += a
	var m: Vector3 = s / max(k, 1.0)
	var bytes := PackedByteArray()
	bytes.resize(w * h * 4)
	for i in w * h:
		var a := px[i * 4 + 3]
		for j in 3:
			var cv: float = lerp(m[j], px[i * 4 + j], clamp(a * 3.0, 0.0, 1.0))
			bytes[i * 4 + j] = int(clamp(cv, 0.0, 1.0) * 255.0)
		bytes[i * 4 + 3] = int(clamp(a, 0.0, 1.0) * 255.0)
	var img := Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, bytes)
	img.generate_mipmaps()
	var data := img.get_data()
	for nivel in range(1, img.get_mipmap_count() + 1):
		var o := img.get_mipmap_offset(nivel)
		var fin := img.get_mipmap_offset(nivel + 1) if nivel < img.get_mipmap_count() else data.size()
		var f := 1.0 + refuerzo * nivel
		for i in range(o + 3, fin, 4):
			data[i] = int(min(255.0, data[i] * f))
	img = Image.create_from_data(w, h, true, Image.FORMAT_RGBA8, data)
	return ImageTexture.create_from_image(img)


# ---- las texturas ----

static func _lienzo(ancho: int, alto: int, semilla: int, fondo: Color) -> RefCounted:
	return load("res://modelos/plaza/texturas.gd").new(ancho, alto, semilla, fondo)


# un racimo de hojas anchas: denso al medio, suelto en el borde (silueta irregular). col: el verde medio
static func hojas(semilla: int, col: Color, n := 260, largo := 9.0, ancho := 4.5, tam := 256) -> ImageTexture:
	var L := _lienzo(tam, tam, semilla, col)
	var c := tam / 2.0
	# ramitas que llevan las hojas
	for i in 7:
		var t: float = L.rng.randf() * TAU
		L.linea(c, c, c + cos(t) * c * 0.8, c + sin(t) * c * 0.8, 2.0, 0.8, Color(0.25, 0.2, 0.14))
	for i in n:
		var r := c * 0.9 * sqrt(L.rng.randf())
		var t: float = L.rng.randf() * TAU
		var x := c + cos(t) * r
		var y := c + sin(t) * r
		var sombra: float = 0.7 + 0.5 * L.rng.randf() - 0.25 * r / c
		var tinte := Color(col.r * sombra * L.rng.randf_range(0.9, 1.1), col.g * sombra, col.b * sombra * L.rng.randf_range(0.85, 1.15))
		var e: float = L.rng.randf_range(0.75, 1.25) * tam / 256.0
		L.hoja(x, y, largo * e, ancho * e, t + L.rng.randf_range(-0.8, 0.8), tinte)
	return L.textura()


# una rama de cedro deodara: un eje que cae con ramitas cortas de agujas en manojos (verde azulado)
static func agujas(semilla: int, col: Color, tam := 256) -> ImageTexture:
	var L := _lienzo(tam, tam, semilla, col)
	var c := tam / 2.0
	# ramitas que cuelgan desde arriba, en abanico; cubren una elipse con el borde deshilachado
	for k in 9:
		var x0: float = c + L.rng.randf_range(-0.3, 0.3) * tam
		var y0: float = L.rng.randf_range(0.04, 0.2) * tam
		var x1: float = x0 + L.rng.randf_range(-0.25, 0.25) * tam
		var y1: float = L.rng.randf_range(0.8, 0.96) * tam
		L.linea(x0, y0, x1, y1, 2.0, 0.8, Color(0.28, 0.24, 0.18))
		var pasos := 55
		for i in pasos:
			var t := float(i) / pasos
			var x: float = lerp(x0, x1, t); var y: float = lerp(y0, y1, t)
			for lado in [-1, 1]:
				var ang: float = PI / 2 + lado * L.rng.randf_range(0.5, 1.3)
				for m in 7:
					var a2: float = ang + L.rng.randf_range(-0.6, 0.6)
					var l: float = L.rng.randf_range(7, 15) * tam / 256.0 * (1.15 - 0.45 * t)
					var sh: float = L.rng.randf_range(0.7, 1.2) * (1.05 - 0.25 * t)
					L.linea(x, y, x + cos(a2) * l * lado, y + sin(a2) * l * 0.7, 1.6, 0.7, Color(col.r * sh, col.g * sh, col.b * sh))
	return L.textura(0.5)


# una fronda de palmera canaria vista de arriba: el raquis por el medio (v de 0 a 1 es la base a la punta, en la
# coordenada x de la imagen) y los folíolos angostos a los lados, más cortos hacia la punta y espinas en la base
static func fronda(semilla: int, col: Color, tam := 256) -> ImageTexture:
	var L := _lienzo(tam * 2, tam / 2, semilla, col)
	var cy := tam / 4.0
	var largo := tam * 2.0
	L.linea(0, cy, largo, cy, 5.0, 1.0, Color(0.55, 0.55, 0.3))
	var i := 0
	var x := largo * 0.12
	while x < largo - 3:
		var t := x / largo
		var l := (1.0 - pow(abs(t - 0.4) / 0.6, 2.0)) * cy * 0.95
		l = max(l, 4.0)
		for lado in [-1, 1]:
			var sh: float = L.rng.randf_range(0.8, 1.15)
			var ang: float = 0.55 + L.rng.randf_range(-0.1, 0.1)
			L.linea(x, cy, x + cos(ang) * l, cy + lado * sin(ang) * l, 2.4, 0.8, Color(col.r * sh, col.g * sh, col.b * sh))
		x += L.rng.randf_range(4.5, 6.0)
		i += 1
	# espinas en la base
	for j in 10:
		var xs := largo * 0.02 + j * largo * 0.009
		for lado in [-1, 1]:
			L.linea(xs, cy, xs + 6, cy + lado * 9, 1.2, 0.5, Color(0.6, 0.6, 0.35))
	return L.textura(0.4)


# una rama de araucaria: un cordón de hojas escamosas que se curva hacia arriba, con ramillas a los lados
static func araucaria(semilla: int, col: Color, tam := 256) -> ImageTexture:
	var L := _lienzo(tam, tam / 2, semilla, col)
	var cy := tam / 4.0
	L.linea(0, cy, tam, cy, 12.0, 6.0, Color(col.r * 0.8, col.g * 0.8, col.b * 0.8))
	var x := 4.0
	while x < tam - 4:
		for lado in [-1, 1]:
			var l: float = L.rng.randf_range(22, 34) * (1.0 - x / tam * 0.45)
			var ang: float = L.rng.randf_range(0.6, 1.2)
			var sh: float = L.rng.randf_range(0.75, 1.2)
			var cc := Color(col.r * sh, col.g * sh, col.b * sh)
			var ex := x + cos(ang) * l
			var ey: float = cy + lado * sin(ang) * l
			L.linea(x, cy, ex, ey, 7.0, 4.0, cc)
			L.linea(ex, ey, ex + 5, ey + lado * 5, 4.0, 2.0, cc * 1.1)  # la puntita que se curva
		x += L.rng.randf_range(4, 6)
	for i in 600:
		L.punto(L.rng.randi_range(0, tam - 1), int(cy + L.rng.randf_range(-5, 5)), Color(col.r * 1.3, col.g * 1.3, col.b * 1.2), 0.5)
	return L.textura(0.5)


# la reja de arcos que bordea los prados (fotos de 2014 y 2024): aros de fierro redondo que se cruzan, sobre un
# fierro horizontal arriba; una tira de 4 aros por textura (se repite a lo largo)
static func reja() -> ImageTexture:
	var L := _lienzo(256, 128, 3, Color(0.13, 0.22, 0.17))
	var col := Color(0.14, 0.24, 0.18)
	for i in 5:
		var cx := i * 64.0
		L.anillo(cx, 58, 40, 5.0, col)
	L.linea(0, 18, 256, 18, 4.0, 4.0, col)
	for i in 5:
		L.linea(i * 64.0 - 32, 98, i * 64.0 - 32, 127, 5.0, 5.0, col)
	return L.textura(0.5)


# la filigrana del fierro fundido del quiosco: baranda (un paño entre pilares) y friso calado
static func filigrana(friso := false) -> ImageTexture:
	var L := _lienzo(256, 128, 5, Color(0.1, 0.12, 0.1))
	var col := Color(0.12, 0.14, 0.12)
	L.linea(0, 3, 256, 3, 6.0, 6.0, col)
	L.linea(0, 124, 256, 124, 6.0, 6.0, col)
	if friso:
		for i in 9:
			var x := i * 32.0
			L.anillo(x, 64, 22, 4.0, col)
			L.anillo(x + 16, 64, 9, 3.0, col)
			L.linea(x, 6, x, 122, 3.0, 3.0, col)
	else:
		for i in 9:
			var x := i * 32.0
			L.linea(x, 6, x, 122, 3.5, 3.5, col)
			L.anillo(x + 16, 40, 12, 3.0, col)
			L.anillo(x + 16, 88, 12, 3.0, col)
			L.linea(x, 64, x + 32, 64, 3.0, 3.0, col)
	return L.textura(0.5)


# el arco calado entre dos columnas del quiosco: un arco rebajado con volutas en las enjutas (u: 0..1 de columna a
# columna, v: de arriba abajo)
static func arco() -> ImageTexture:
	var L := _lienzo(256, 128, 7, Color(0.1, 0.12, 0.1))
	var col := Color(0.12, 0.14, 0.12)
	L.linea(0, 4, 256, 4, 8.0, 8.0, col)
	for i in 64:
		var t := float(i) / 63.0
		var x := t * 256.0
		var y := 120.0 - sin(t * PI) * 100.0
		L.linea(x, y, x + 4.0, 120.0 - sin(min(1.0, t + 1.0 / 63.0) * PI) * 100.0, 7.0, 7.0, col)
	for lado in [0.0, 1.0]:
		var cx: float = 30.0 if lado == 0.0 else 226.0
		L.anillo(cx, 36, 18, 4.0, col)
		L.anillo(cx, 36, 7, 3.0, col)
		L.anillo(128, 0, 12, 3.0, col)
	for i in 7:
		var x := 64.0 + i * 21.0
		L.linea(x, 6, x, 16 + 10 * sin(i * 0.8), 3.0, 2.0, col)
	return L.textura(0.5)


# flores sueltas sobre transparente (begonias del memorial de Spano, foto de 2024; maceteros de los faroles)
static func flores(semilla: int, colores: Array, n := 90) -> ImageTexture:
	var L := _lienzo(128, 128, semilla, Color(0.25, 0.4, 0.2))
	for i in n:
		var x: float = L.rng.randf_range(8, 120); var y: float = L.rng.randf_range(8, 120)
		L.hoja(x, y, 9, 6, L.rng.randf() * TAU, Color(0.2, 0.4, 0.15).darkened(L.rng.randf() * 0.3))
	for i in n:
		var x: float = L.rng.randf_range(10, 118); var y: float = L.rng.randf_range(10, 118)
		var col: Color = colores[L.rng.randi() % colores.size()]
		for p in 5:
			var t := p * TAU / 5
			L.hoja(x + cos(t) * 2.5, y + sin(t) * 2.5, 3.2, 2.2, t, col, false)
		L.punto(int(x), int(y), Color(0.95, 0.85, 0.3))
	return L.textura(0.3)
