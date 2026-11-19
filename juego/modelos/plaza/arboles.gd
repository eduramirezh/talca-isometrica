# Árboles de la plaza hechos en código, uno por especie de las que se ven en las fotos (Commons, 2013–2024; las fuentes
# de cada una, en plaza.gd). Cada especie tiene unas pocas variantes (semillas) que se reparten con giro y escala
# distintos. Un árbol es una ArrayMesh con dos superficies: la corteza (tronco y ramas, corteza.gdshader) y el follaje
# en tarjetas con textura (follaje.gdshader) o en hojas sólidas (cordyline, agapantos). El origen es el pie del tronco.
#
# Medidas de las fotos y de lo típico de cada especie en ciudad; ninguna se midió en el lugar:
#   palmera  Phoenix canariensis: estípite de 0,9–1,1 m de diámetro con la base de las hojas en rombos, 9–15 m,
#            40–50 frondas arqueadas de 4,5–5,5 m, racimos de dátiles naranjos (foto de 2024 «…en 2024 01»)
#   cedro    Cedrus deodara: 18–24 m, copa cónica ancha, ramas horizontales con las puntas caídas, verde azulado,
#            tronco despejado hasta ~5 m (foto de 2024 «…en 2024 02», junto al memorial de Spano)
#   araucaria  Araucaria heterophylla o columnaris: 20–26 m, pisos de cinco ramas horizontales (fotos de 2024 «03», «04»)
#   frondoso árbol de hoja ancha genérico (fresno, plátano, tilo: las fotos no permiten decir cuál), 12–17 m
#   podado   la copa recortada en cúpula sobre troncos retorcidos (pitosporo o laurel, foto de 2024 «01»), ~6 m
#   cordyline  Cordyline australis: troncos delgados que se ramifican en penachos de hojas angostas (foto de 2014
#            «Talca, plaza (14836795037)»), 4–6 m
#   arbusto  bolas recortadas de ~1,2 m junto a las soleras (foto de 2024 «01»)
#   agapanto matas de hojas en cinta en los bordes de los prados (fotos de 2014 y 2024)
#   alamo    Populus nigra 'Italica', columnar, 16–21 m: no está en la plaza; lo usa arboleda.gd para los álamos del mapa
extends RefCounted

const Malla := preload("res://malla.gd")
const Mat := preload("res://materiales.gd")
const Tx := preload("res://modelos/plaza/texturas.gd")

const ESPECIES := {
	"palmera": {"corteza": Color(0.45, 0.38, 0.29), "tipo": 1, "hojas": Color(0.46, 0.58, 0.22)},
	"cedro": {"corteza": Color(0.27, 0.25, 0.23), "tipo": 0, "hojas": Color(0.34, 0.46, 0.42)},
	"araucaria": {"corteza": Color(0.3, 0.25, 0.21), "tipo": 2, "hojas": Color(0.20, 0.34, 0.18)},
	"frondoso": {"corteza": Color(0.27, 0.245, 0.22), "tipo": 0, "hojas": Color(0.33, 0.50, 0.20)},
	"podado": {"corteza": Color(0.38, 0.35, 0.31), "tipo": 0, "hojas": Color(0.26, 0.42, 0.17)},
	"cordyline": {"corteza": Color(0.44, 0.40, 0.34), "tipo": 2, "hojas": Color(0.38, 0.52, 0.22)},
	"arbusto": {"corteza": Color(0.4, 0.35, 0.3), "tipo": 0, "hojas": Color(0.24, 0.40, 0.16)},
	"agapanto": {"corteza": Color(0.4, 0.35, 0.3), "tipo": 0, "hojas": Color(0.22, 0.40, 0.16)},
	"alamo": {"corteza": Color(0.42, 0.40, 0.36), "tipo": 0, "hojas": Color(0.36, 0.52, 0.22)},
}
const VARIANTES := 3

var mat_corteza := {}
var mat_follaje := {}
var mat_solido: StandardMaterial3D
var mat_datiles: ShaderMaterial
var cache := {}
var radios := {}  # especie/variante -> radio del tronco a 1 m (colisión)
var sombras := {}  # especie/variante -> la malla de la sombra
const SOMBRA_K := {"frondoso": 2, "podado": 2, "arbusto": 2, "cedro": 2, "araucaria": 3, "alamo": 2}  # una tarjeta de cada k


func _init() -> void:
	var tex := {
		"palmera": Tx.fronda(11, Color(0.42, 0.55, 0.22)),
		"cedro": Tx.agujas(12, Color(0.32, 0.44, 0.38)),
		"araucaria": Tx.araucaria(13, Color(0.22, 0.36, 0.19)),
		"frondoso": Tx.hojas(14, Color(0.36, 0.54, 0.22)),
		"podado": Tx.hojas(15, Color(0.28, 0.45, 0.18), 520, 6.0, 3.2),
		"arbusto": Tx.hojas(16, Color(0.26, 0.43, 0.17), 480, 6.0, 3.0),
		"alamo": Tx.hojas(18, Color(0.38, 0.55, 0.23), 420, 7.0, 4.0),
	}
	for e in ESPECIES:
		mat_corteza[e] = Mat.plaza("corteza", {"tipo": ESPECIES[e]["tipo"], "vueltas": 10.0 if e == "palmera" else 6.0})
		if e in tex:
			mat_follaje[e] = Mat.plaza("follaje", {"tex": tex[e], "viento": 1.4 if e == "palmera" else 1.0,
				"brillo": 0.45 if e in ["podado", "arbusto", "palmera"] else 0.3})
	mat_solido = StandardMaterial3D.new()
	mat_solido.vertex_color_use_as_albedo = true
	mat_solido.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat_solido.roughness = 0.7
	mat_solido.backlight_enabled = true
	mat_solido.backlight = Color(0.25, 0.35, 0.12)
	mat_datiles = Mat.plaza("follaje", {"tex": Tx.flores(17, [Color(0.9, 0.5, 0.12), Color(0.95, 0.62, 0.15), Color(0.8, 0.42, 0.1)], 70)})


# la malla de una variante (se arma una vez)
func malla(especie: String, variante: int) -> ArrayMesh:
	var clave := "%s/%d" % [especie, variante % VARIANTES]
	if clave in cache:
		return cache[clave]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(clave) & 0x7fffffff
	var tr := Malla.new()
	var fo := Malla.new()
	var extra := Malla.new()  # sólidos (hojas en cinta) o dátiles
	var r := 0.3
	match especie:
		"palmera": r = palmera(rng, tr, fo, extra)
		"cedro": r = cedro(rng, tr, fo)
		"araucaria": r = araucaria(rng, tr, fo)
		"frondoso": r = frondoso(rng, tr, fo)
		"podado": r = podado(rng, tr, fo)
		"cordyline": r = cordyline(rng, tr, extra)
		"arbusto": r = arbusto(rng, fo)
		"agapanto": r = agapanto(rng, extra)
		"alamo": r = alamo(rng, tr, fo)
	var m := ArrayMesh.new()
	tr.malla(mat_corteza[especie], m)
	if especie in mat_follaje:
		fo.malla(mat_follaje[especie], m)
	extra.malla(mat_datiles if especie == "palmera" else mat_solido, m)
	cache[clave] = m
	radios[clave] = r
	# la sombra: la corteza y una tarjeta de cada racimo (las tres cruzadas de un racimo dan casi la misma sombra)
	var s := ArrayMesh.new()
	tr.malla(mat_corteza[especie], s)
	if especie in mat_follaje:
		fo.cada(SOMBRA_K.get(especie, 1)).malla(mat_follaje[especie], s)
	sombras[clave] = s
	return m


# la malla que proyecta la sombra de una variante (instancia solo de sombra)
func sombra(especie: String, variante: int) -> ArrayMesh:
	malla(especie, variante)
	return sombras["%s/%d" % [especie, variante % VARIANTES]]


func radio(especie: String, variante: int) -> float:
	malla(especie, variante)
	return radios["%s/%d" % [especie, variante % VARIANTES]]


# ---- piezas ----

# una tarjeta de follaje: un cuadrado centrado en p con ejes u, v (mitades), normal de iluminación nn
static func tarjeta(m: Malla, p: Vector3, u: Vector3, v: Vector3, nn: Vector3, col: Color) -> void:
	m.quad(p - u - v, p + u - v, p + u + v, p - u + v, col, nn, [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)])


# un racimo: tres tarjetas cruzadas de lado s en p, iluminadas desde el centro de la copa c
static func racimo(m: Malla, rng: RandomNumberGenerator, p: Vector3, s: float, c: Vector3, col: Color, tarjetas := 3) -> void:
	var nn := (p - c).normalized()
	nn = (nn + Vector3.UP * 0.35).normalized()
	var b := Basis(Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized(), rng.randf() * TAU)
	var ejes := [[b.x, b.y], [b.y, b.z], [b.z, b.x]]
	for i in tarjetas:
		var tinte := col * rng.randf_range(0.85, 1.15)
		tinte.a = 1.0
		tarjeta(m, p, ejes[i][0] * s * 0.5, ejes[i][1] * s * 0.5, nn, tinte)


# un tronco o rama curvo: una serie de tubos por los puntos pts con radios rs (UV en m a lo largo)
static func rama(m: Malla, pts: Array, rs: Array, k: int, col: Color) -> void:
	var largo := 0.0
	for i in pts.size() - 1:
		var l: float = (pts[i + 1] - pts[i]).length()
		var ca: Color = col * (0.92 + 0.08 * float(i) / pts.size())
		m.tubo(pts[i], pts[i + 1], rs[i], rs[i + 1], k, ca, ca, largo, largo + l)
		largo += l


# dos tarjetas de lado s en p sobre una superficie recortada de normal n (cúpulas podadas, bolas): una tangente a la
# superficie (así la cúpula se lee lisa, como la poda) y otra cruzada que le da espesor. Siempre dos cuadriláteros,
# como racimo(..., 2), para que la sombra (cada(2)) tome uno de cada par
static func escama(m: Malla, rng: RandomNumberGenerator, p: Vector3, n: Vector3, s: float, col: Color) -> void:
	var ref := Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT
	var u := n.cross(ref).normalized().rotated(n, rng.randf() * TAU)
	var v := n.cross(u)
	var nn := (n + Vector3.UP * 0.3).normalized()
	var t1 := col * rng.randf_range(0.88, 1.12)
	t1.a = 1.0
	tarjeta(m, p, u * s * 0.5, v * s * 0.5, nn, t1)
	var w := (v * 0.6 + n * 0.8).normalized()
	var t2 := col * rng.randf_range(0.8, 1.0)
	t2.a = 1.0
	tarjeta(m, p - n * s * 0.12, u * s * 0.45, w * s * 0.4, nn, t2)


# Phoenix canariensis: el estípite grueso y casi cilíndrico con los rombos de las bases de las hojas cortadas (corteza
# tipo 1; ~22 cm de ancho y ~11 de alto con vueltas = 10), la «piña» de bases recién podadas bajo la copa, y una copa
# densa casi esférica de frondas pinnadas: las nuevas suben derechas, las viejas se arquean y cuelgan con la punta
# hacia abajo. Cada fronda es un raquis con folíolos en V, más anchos a un tercio de su largo.
func palmera(rng: RandomNumberGenerator, tr: Malla, fo: Malla, datiles: Malla) -> float:
	var E: Dictionary = ESPECIES["palmera"]
	var H := rng.randf_range(8.5, 12.5)
	var r0 := rng.randf_range(0.45, 0.55)
	var incl := Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized() * rng.randf_range(0.2, 0.6)
	var pts := []
	var rs := []
	var n := 12
	for i in n + 1:
		var t := float(i) / n
		pts.append(Vector3.UP * (H * t - 0.3) + incl * t * t)
		# el pie se ensancha y el estípite engruesa un poco bajo la copa
		rs.append(r0 * (1.0 + 0.4 * pow(maxf(0.0, 1.0 - t * 6.0), 2.0)) * (0.97 + 0.07 * t * t))
	rama(tr, pts, rs, 14, E["corteza"])
	var top: Vector3 = pts[n]
	# la «piña»: las bases de las frondas cortadas, más claras y anchas que el estípite, cerrándose hacia la copa
	tr.torno(top - Vector3.UP * 0.15, [Vector2(r0 * 1.02, 0), Vector2(r0 * 1.32, 0.45), Vector2(r0 * 1.42, 0.95),
		Vector2(r0 * 1.2, 1.45), Vector2(0.4, 1.85), Vector2(0.0, 2.05)], 14, E["corteza"] * 1.18)
	var c := top + Vector3.UP * 1.5
	var nf := rng.randi_range(44, 54)
	var col: Color = E["hojas"]
	for i in nf:
		var az := i * 2.39996 + rng.randf_range(-0.12, 0.12)  # ángulo áureo
		var f := float(i) / nf  # 0: las de arriba (nuevas), 1: las de abajo (viejas)
		var el: float = lerpf(1.3, -0.3, f) + rng.randf_range(-0.12, 0.12)
		var L := rng.randf_range(4.5, 5.5)
		var horiz := Vector3(cos(az), 0, sin(az))
		var d0 := (horiz * cos(el) + Vector3.UP * sin(el)).normalized()
		var p0: Vector3 = c + horiz * lerpf(0.15, 0.45, f) + Vector3.UP * lerpf(0.4, -0.9, f)
		# el arco: las nuevas apenas se doblan, las viejas cuelgan
		var caida: float = L * lerpf(0.12, 0.85, pow(f, 1.3)) * rng.randf_range(0.85, 1.15)
		var lado := horiz.cross(Vector3.UP).normalized()
		var pasos := 7
		var tinte: Color = col * lerpf(1.08, 0.82, f)
		if f > 0.88 and rng.randf() < 0.45:
			tinte = Color(0.56, 0.5, 0.27)  # alguna fronda vieja amarillenta
		tinte.a = 1
		var prev_p: Vector3 = p0
		var prev_l := Vector3.ZERO
		var prev_r := Vector3.ZERO
		for j in pasos + 1:
			var t := float(j) / pasos
			var p: Vector3 = p0 + d0 * L * t + Vector3.DOWN * caida * t * t
			var tang: Vector3 = (d0 * L + Vector3.DOWN * 2.0 * caida * t).normalized()
			# folíolos cortos (espinas) en la base, los más largos a un tercio, angostándose hacia la punta
			var ancho := 0.95 * pow(sin(PI * clampf(0.04 + 0.96 * t, 0.0, 1.0)), 0.55) * (1.0 - 0.4 * t) + 0.04
			if t < 0.12:
				ancho *= 0.35
			var up: Vector3 = tang.cross(lado).normalized()
			if up.y < 0:
				up = -up
			# los folíolos en V abierta: cada mitad sube ~20°
			var izq: Vector3 = (lado * cos(0.35) + up * sin(0.35)) * ancho
			var der: Vector3 = (-lado * cos(0.35) + up * sin(0.35)) * ancho
			if j > 0:
				var nn: Vector3 = (up + (p - c).normalized() * 0.6).normalized()
				var u0 := t - 1.0 / pasos
				fo.quad(prev_p + prev_l, p + izq, p, prev_p, tinte, nn,
					[Vector2(u0, 0), Vector2(t, 0), Vector2(t, 0.5), Vector2(u0, 0.5)])
				fo.quad(prev_p, p, p + der, prev_p + prev_r, tinte, nn,
					[Vector2(u0, 0.5), Vector2(t, 0.5), Vector2(t, 1), Vector2(u0, 1)])
			prev_p = p; prev_l = izq; prev_r = der
	# racimos de dátiles naranjos colgando bajo la copa, entre las frondas viejas
	for i in rng.randi_range(3, 6):
		var az := rng.randf() * TAU
		var p := top + Vector3(cos(az), 0, sin(az)) * rng.randf_range(0.8, 1.2) + Vector3.UP * rng.randf_range(0.1, 0.5)
		var u := Vector3(-sin(az), 0, cos(az)) * 0.35
		tarjeta(datiles, p - Vector3.UP * 0.45, u, Vector3.UP * 0.55, Vector3(cos(az), 0.3, sin(az)).normalized(), Color(1, 1, 1))
		tarjeta(datiles, p - Vector3.UP * 0.45, Vector3(cos(az), 0, sin(az)) * 0.35, Vector3.UP * 0.55, Vector3(cos(az), 0.3, sin(az)).normalized(), Color(1, 1, 1))
	return r0


# Cedrus deodara: un cono ancho de pisos separados (se ve el cielo entre ellos), cada rama casi horizontal con una
# almohadilla plana de agujas que se ensancha hacia el tronco y la punta que cae; la guía de arriba se inclina (el
# rasgo del deodara). Los pisos se juntan hacia la cima.
func cedro(rng: RandomNumberGenerator, tr: Malla, fo: Malla) -> float:
	var E: Dictionary = ESPECIES["cedro"]
	var H := rng.randf_range(18.0, 23.0)
	var r0 := rng.randf_range(0.5, 0.65)
	var R := rng.randf_range(6.0, 7.5)
	var h0 := rng.randf_range(4.5, 5.8)
	var cab := Vector3.RIGHT.rotated(Vector3.UP, rng.randf() * TAU)  # hacia donde cae la guía
	var pts := []
	var rs := []
	for i in 13:
		var t := i / 12.0
		var ladeo := cab * pow(maxf(0.0, (t - 0.85) / 0.15), 2.0) * 1.1  # la guía que se dobla
		pts.append(Vector3(sin(t * 3.0) * 0.12, H * 0.97 * t - 0.3, cos(t * 2.0) * 0.08 - 0.08) + ladeo
			- Vector3.UP * pow(maxf(0.0, (t - 0.85) / 0.15), 2.0) * 0.4)
		rs.append(r0 * (1.0 - 0.93 * t) * (1.0 + 0.4 * pow(maxf(0.0, 1.0 - t * 8.0), 2.0)))
	rama(tr, pts, rs, 10, E["corteza"])
	var col: Color = E["hojas"]
	var c := Vector3(0, (h0 + H) * 0.5, 0)
	var h := h0
	var az0 := rng.randf() * TAU
	while h < H - 2.0:
		var f := (h - h0) / (H - h0)
		var Lp := R * pow(1.0 - f, 0.9) + 0.7
		var nb := 6 if f < 0.45 else (5 if f < 0.75 else 4)
		az0 += 0.5 + rng.randf_range(-0.2, 0.2)
		for b in nb:
			var az := az0 + TAU * b / nb + rng.randf_range(-0.25, 0.25)
			var L := Lp * rng.randf_range(0.8, 1.1)
			var d := Vector3(cos(az), 0, sin(az))
			var p0 := Vector3(0, h + rng.randf_range(-0.2, 0.2), 0)
			var sube := rng.randf_range(0.02, 0.12)
			var p1 := p0 + d * L * 0.55 + Vector3.UP * L * sube
			var p2 := p0 + d * L + Vector3.UP * (L * sube - L * 0.2)  # la punta cae
			var rr := 0.04 + 0.1 * L / R
			rama(tr, [p0, p1, p2], [rr, rr * 0.6, 0.02], 4, E["corteza"] * 0.9)
			# la almohadilla: tarjetas casi horizontales a lo largo de la rama, anchas cerca del tronco
			var lado := d.cross(Vector3.UP)
			var k := int(L / 0.85) + 1
			var tinte := col * rng.randf_range(0.88, 1.08)
			tinte.a = 1
			for j in k:
				var t: float = 0.2 + 0.68 * float(j) / maxf(1, k - 1)
				var p: Vector3 = (p0.lerp(p1, t / 0.55) if t < 0.55 else p1.lerp(p2, (t - 0.55) / 0.45))
				var tg: Vector3 = (p1 - p0).normalized() if t < 0.55 else (p2 - p1).normalized()
				var ancho: float = clampf(L * lerpf(0.5, 0.26, t), 1.1, 3.0) * rng.randf_range(0.9, 1.1)
				var largo: float = minf(1.3, L * 0.32)
				var nn := ((p - c).normalized() * 0.4 + Vector3.UP).normalized()
				# el borde de afuera de la almohadilla cae un poco
				var v: Vector3 = (lado + Vector3.DOWN * 0.12).normalized() * ancho * 0.5
				tarjeta(fo, p + Vector3.DOWN * 0.1, tg * largo, v, nn, tinte)
				tarjeta(fo, p + Vector3.DOWN * 0.4, tg.rotated(Vector3.UP, 0.4) * largo * 0.9, v.rotated(Vector3.UP, 0.4) * 0.85, nn, tinte * 0.82)
			# la punta que cuelga
			var pt: Vector3 = p2 + d * 0.2
			tarjeta(fo, pt + Vector3.DOWN * 0.35, (d + Vector3.DOWN * 1.3).normalized() * 0.75, lado * 0.55, (d + Vector3.UP * 0.6).normalized(), tinte * 0.95)
		h += lerpf(1.45, 0.85, f) * rng.randf_range(0.85, 1.15)
	# la guía de arriba, que se inclina: tarjetas chicas a lo largo de los últimos tramos del tronco
	for i in range(9, 13):
		var p: Vector3 = pts[i]
		var t := rng.randf() * TAU
		var s := lerpf(0.9, 0.45, (i - 9) / 3.0)
		tarjeta(fo, p, Vector3(cos(t), 0, sin(t)) * s, Vector3(cos(t + 1.5), -0.6, sin(t + 1.5)).normalized() * s * 0.8,
			Vector3.UP, col * 1.05)
		tarjeta(fo, p, Vector3(cos(t + 1.6), 0, sin(t + 1.6)) * s, Vector3(cos(t), -0.6, sin(t)).normalized() * s * 0.8,
			Vector3.UP, col)
	return r0


# Araucaria heterophylla: el tronco recto a la vista entre los pisos, pisos regulares de cinco ramas horizontales (el
# rasgo de la especie: «pisos» con cielo entre ellos), cada rama una lámina plana de ramillas que se dobla un poco
# hacia abajo a los lados y sube en la punta; los pisos de abajo cuelgan un poco y los de arriba suben.
func araucaria(rng: RandomNumberGenerator, tr: Malla, fo: Malla) -> float:
	var E: Dictionary = ESPECIES["araucaria"]
	var H := rng.randf_range(19.0, 25.0)
	var r0 := rng.randf_range(0.35, 0.45)
	var pts := []
	var rs := []
	for i in 9:
		var t := i / 8.0
		pts.append(Vector3(0, H * t - 0.3, 0))
		rs.append(r0 * (1.0 - 0.9 * t) * (1.0 + 0.3 * pow(maxf(0.0, 1.0 - t * 8.0), 2.0)))
	rama(tr, pts, rs, 10, E["corteza"])
	var col: Color = E["hojas"]
	var h0 := H * rng.randf_range(0.3, 0.38)
	var Lmax := rng.randf_range(3.8, 4.8)
	var h := h0
	var giro := rng.randf() * TAU
	while h < H - 0.9:
		var f := (h - h0) / (H - h0)
		var L := Lmax * pow(1.0 - f, 0.85) + 0.45
		var cae := lerpf(0.12, -0.08, f)  # los de abajo cuelgan, los de arriba suben
		giro += 0.63
		for b in 5:
			if rng.randf() < 0.07 and f < 0.5:
				continue  # alguna rama perdida en los pisos de abajo
			var az := giro + b * TAU / 5 + rng.randf_range(-0.08, 0.08)
			var d := Vector3(cos(az), 0, sin(az))
			var p0 := Vector3(0, h, 0)
			var p1 := p0 + d * L * 0.6 + Vector3.DOWN * L * cae
			var p2 := p0 + d * L + Vector3.UP * L * (0.1 - cae * 0.5)  # la punta sube
			rama(tr, [p0, p1, p2], [0.05 + 0.05 * (1 - f), 0.035, 0.02], 3, E["corteza"])
			# la lámina de ramillas: dos tarjetas por tramo, una a cada lado del eje, caídas ~29° (en V invertida: de
			# arriba se ve la lámina), y una que cuelga bajo el eje; la textura solo hasta donde llegan sus ramillas (v 0,14),
			# para que la lámina se lea llena
			var lado := d.cross(Vector3.UP).normalized()
			var tinte := col * rng.randf_range(0.88, 1.12)
			tinte.a = 1
			var anch: float = lerpf(1.25, 0.75, f)
			for seg in [[p0.lerp(p1, 0.12), p1, 1.0], [p1, p2, 0.75]]:
				var a: Vector3 = seg[0]
				var e: Vector3 = seg[1]
				var w: float = anch * seg[2]
				var mitad := (e - a) * 0.5
				var m := a + mitad
				var nn := (d * 0.4 + Vector3.UP).normalized()
				for s in [-1.0, 1.0]:
					var ala: Vector3 = (lado * s + Vector3.DOWN * 0.55).normalized() * w
					fo.quad(m - mitad, m + mitad, m + mitad + ala, m - mitad + ala, tinte * (1.0 if s > 0 else 0.92), nn,
						[Vector2(0, 0.5), Vector2(1, 0.5), Vector2(1, 0.14 if s > 0 else 0.86), Vector2(0, 0.14 if s > 0 else 0.86)])
				# las ramillas que cuelgan bajo el eje: de costado dan la masa del piso
				var cuelga := Vector3.DOWN * w * 0.55 + lado * w * 0.15
				fo.quad(m - mitad, m + mitad, m + mitad + cuelga, m - mitad + cuelga, tinte * 0.85, nn,
					[Vector2(0, 0.5), Vector2(1, 0.5), Vector2(1, 0.14), Vector2(0, 0.14)])
		h += rng.randf_range(0.95, 1.25) * lerpf(1.1, 0.8, f)
	# el brote de la punta
	var cima := Vector3(0, H - 0.3, 0)
	for i in 3:
		var t := giro + i * TAU / 3
		tarjeta(fo, cima + Vector3.DOWN * 0.3, Vector3(cos(t), 0, sin(t)) * 0.35, Vector3.UP * 0.55, Vector3.UP, col)
	return r0


# El árbol de hoja ancha de la plaza y de todo el mapa (arboleda.gd): un tronco que se abre a ~3 m en tres o cuatro
# ramas madre que suben y se separan, cada una partida dos veces, y en las puntas masas de follaje (de 1,4 a 2,3 m de
# radio) con su propia luz: la copa se lee en grumos, con huecos de cielo y ramas a la vista por debajo, y no como una
# bola. Las ramas finas van con menos caras (no se distinguen a la distancia de juego).
func frondoso(rng: RandomNumberGenerator, tr: Malla, fo: Malla) -> float:
	var E: Dictionary = ESPECIES["frondoso"]
	var H := rng.randf_range(12.0, 16.5)
	var R := rng.randf_range(5.0, 6.8)
	var r0 := rng.randf_range(0.32, 0.48)
	var hf := rng.randf_range(2.6, 3.6)
	var lean := Vector3(rng.randf_range(-0.4, 0.4), 0, rng.randf_range(-0.4, 0.4))
	var tope := Vector3.UP * hf + lean
	rama(tr, [Vector3.DOWN * 0.3, Vector3.UP * 0.4, Vector3.UP * hf * 0.6 + lean * 0.5, tope], [r0 * 1.45, r0 * 1.05, r0 * 0.95, r0 * 0.88], 8, E["corteza"])
	var c := Vector3(lean.x, hf + (H - hf) * 0.48, lean.z)
	var ry := (H - hf) * 0.52
	var grumos := []  # [centro, radio]
	var nl := rng.randi_range(3, 4)
	var az0 := rng.randf() * TAU
	for i in nl:
		var az := az0 + TAU * i / nl + rng.randf_range(-0.35, 0.35)
		var el := rng.randf_range(0.65, 1.05)
		var d := Vector3(cos(az) * cos(el), sin(el), sin(az) * cos(el))
		ramas(rng, tr, tope, d, (H - hf) * rng.randf_range(0.36, 0.44), r0 * 0.62, 2, grumos, c, R, ry)
	var col: Color = E["hojas"]
	for g in grumos:
		var gc: Vector3 = g[0]
		var gr: float = g[1]
		var tg: Color = col * rng.randf_range(0.9, 1.08)
		# más oscuro abajo y adentro de la copa (la sombra propia que el sombreador no da a las tarjetas)
		tg = tg * lerpf(0.82, 1.06, clampf((gc.y - (c.y - ry)) / (2.0 * ry), 0.0, 1.0))
		var cn := gc.lerp(c, 0.3) + Vector3.DOWN * 0.4  # de donde salen las normales: el grumo, algo de la copa
		var n := int(gr * gr * 2.8) + 3
		for i in n:
			var q := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.55, 1), rng.randf_range(-1, 1))
			if q.length() < 0.15:
				q = Vector3.UP
			q = q.normalized() * rng.randf_range(0.35, 1.0)
			var p := gc + Vector3(q.x * gr, q.y * gr * 0.8, q.z * gr)
			racimo(fo, rng, p, rng.randf_range(1.7, 2.3), cn, tg, 2)
	return r0


# una rama y sus hijas, hasta nivel 0; en cada punta un grumo de follaje (y uno más chico en las de nivel 1, que
# llena el interior de la copa). Las puntas no salen del elipsoide de la copa (c, R, ry)
func ramas(rng: RandomNumberGenerator, tr: Malla, p: Vector3, d: Vector3, L: float, r: float, nivel: int, grumos: Array, c: Vector3, R: float, ry: float) -> void:
	var e := p + d * L
	var q := e - c
	var k := Vector3(q.x / R, q.y / ry, q.z / R).length()
	if k > 0.82:
		e = c + q / k * 0.82
	var mid := p.lerp(e, 0.5) + Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(0.0, 0.3), rng.randf_range(-0.3, 0.3)) * L * 0.25
	rama(tr, [p, mid, e], [r, r * 0.8, r * 0.62], [3, 4, 6][nivel], ESPECIES["frondoso"]["corteza"])
	if nivel == 0:
		grumos.append([e + Vector3.UP * 0.3, rng.randf_range(1.5, 2.2)])
		return
	if nivel >= 1:
		# grumos a lo largo de las ramas gruesas: llenan la copa media y baja (las de nivel 2, hacia afuera y abajo)
		var fuera := Vector3(e.x - c.x, 0, e.z - c.z).normalized()
		grumos.append([p.lerp(e, 0.65) + fuera * 0.8 + Vector3.DOWN * (0.6 if nivel == 2 else 0.2), rng.randf_range(1.4, 1.9) if nivel == 2 else rng.randf_range(1.3, 1.7)])
	var hijos := rng.randi_range(2, 3)
	for i in hijos:
		var eje := d.cross(Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1))).normalized()
		if eje == Vector3.ZERO:
			eje = Vector3.RIGHT
		var d2 := d.rotated(eje, rng.randf_range(0.4, 0.85))
		d2 = (d2 + (e - c).normalized() * 0.45 + Vector3.UP * 0.1).normalized()
		ramas(rng, tr, e, d2, L * rng.randf_range(0.6, 0.78), r * 0.6, nivel - 1, grumos, c, R, ry)


# Populus nigra 'Italica', el álamo de las hileras del campo y de los caminos (el cono de la página, treeGeo('poplar') de
# src/js/80-trees.js; arboleda.gd lo usa en todo el mapa): 16–21 m, una copa columnar de 3–4,5 m de ancho desde ~2 m
# del suelo, más ancha a un cuarto de su alto y aguzada arriba como una llama, con ramas cortas que suben pegadas al
# tronco. El follaje en tarjetas más altas que anchas y casi verticales: la copa se lee en vetas que suben, no en bolas.
# Lo típico de la especie, sin una foto de Talca.
func alamo(rng: RandomNumberGenerator, tr: Malla, fo: Malla) -> float:
	var E: Dictionary = ESPECIES["alamo"]
	var H := rng.randf_range(16.0, 21.0)
	var R := rng.randf_range(1.6, 2.2)
	var r0 := rng.randf_range(0.26, 0.36)
	var h0 := rng.randf_range(1.6, 2.4)  # donde empieza la copa
	rama(tr, [Vector3.DOWN * 0.3, Vector3.UP * h0, Vector3.UP * H * 0.55, Vector3.UP * H * 0.92], [r0 * 1.4, r0, r0 * 0.6, r0 * 0.18], 8, E["corteza"])
	# el ancho de la copa a la fracción t de su alto: redondeada abajo, la más ancha a un cuarto, aguzada arriba
	var ancho := func(t: float) -> float:
		if t < 0.25:
			return R * (0.55 + 0.45 * sin(t / 0.25 * PI * 0.5))
		return R * (1.0 - 0.9 * pow((t - 0.25) / 0.75, 1.5))
	for i in rng.randi_range(6, 9):  # ramas que suben
		var t := rng.randf_range(0.03, 0.6)
		var y := lerpf(h0, H, t)
		var az := rng.randf() * TAU
		var d := Vector3(cos(az) * 0.35, 1.0, sin(az) * 0.35).normalized()
		rama(tr, [Vector3.UP * y, Vector3.UP * y + d * ancho.call(t) * 1.8], [r0 * 0.3, r0 * 0.1], 4, E["corteza"])
	var col: Color = E["hojas"]
	var n := int(H * R * 4.2)
	for i in n:
		var t := pow(rng.randf(), 0.9)
		var y := lerpf(h0, H - 0.6, t)
		var w: float = ancho.call(t)
		var rr: float = w * sqrt(rng.randf_range(0.2, 1.0))
		var az := rng.randf() * TAU
		var p := Vector3(cos(az) * rr, y, sin(az) * rr)
		var s := rng.randf_range(1.1, 1.5) * clampf(w / R + 0.35, 0.5, 1.0)
		var tinte := col * rng.randf_range(0.86, 1.12) * lerpf(0.88, 1.05, t)
		tinte.a = 1.0
		# dos tarjetas cruzadas, altas y casi verticales, giradas al azar alrededor del eje (vetas que suben)
		var nn := (Vector3(p.x, 0, p.z).normalized() + Vector3.UP * 0.35).normalized()
		var a := rng.randf() * TAU
		var inc := Vector3(rng.randf_range(-0.2, 0.2), 1, rng.randf_range(-0.2, 0.2)).normalized()
		for k in 2:
			var u := Vector3(cos(a + k * PI / 2), 0, sin(a + k * PI / 2))
			tarjeta(fo, p, u * s * 0.5, inc * s * 0.85, nn, tinte * (1.0 - 0.08 * k))
	return r0


# un pitosporo o laurel podado en cúpula: dos a cuatro troncos retorcidos que se abren y una copa recortada lisa y
# densa, aplanada por debajo (la poda deja la base pareja). Las tarjetas van tangentes a la cúpula (escama())
func podado(rng: RandomNumberGenerator, tr: Malla, fo: Malla) -> float:
	var E: Dictionary = ESPECIES["podado"]
	var R := rng.randf_range(2.8, 3.6)
	var ry := rng.randf_range(2.0, 2.6)
	var c := Vector3(0, ry * 0.75 + rng.randf_range(1.8, 2.3), 0)
	var nt := rng.randi_range(2, 4)
	for i in nt:
		var az := TAU * i / nt + rng.randf_range(-0.4, 0.4)
		var d := Vector3(cos(az), 0, sin(az))
		var l := d.cross(Vector3.UP)
		var r := rng.randf_range(0.14, 0.22)
		var tw := rng.randf_range(-0.25, 0.25)
		rama(tr, [Vector3.DOWN * 0.2 + d * 0.12, Vector3.UP * 0.7 + d * 0.3 + l * tw, Vector3.UP * 1.4 + d * 0.55 - l * tw,
			Vector3.UP * 2.0 + d * 1.0 + l * tw * 0.6, c + d * R * 0.45 + Vector3.DOWN * 0.4],
			[r * 1.35, r, r * 0.9, r * 0.75, r * 0.45], 6, E["corteza"])
	var col: Color = E["hojas"]
	var n := int(R * R * 8)
	for i in n:
		var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.5, 1), rng.randf_range(-1, 1))
		if d.length() < 0.1:
			continue
		d = d.normalized()
		if d.y < -0.3:  # la base recortada, casi plana
			d.y = -0.3 - (d.y + 0.3) * 0.25
		d *= rng.randf_range(0.9, 1.0)
		var p := c + Vector3(d.x * R, d.y * ry, d.z * R)
		var nrm := Vector3(d.x / R, d.y / ry, d.z / R).normalized()
		var tinte := col * lerpf(0.82, 1.06, (d.y + 0.4) / 1.4)
		escama(fo, rng, p, nrm, rng.randf_range(1.15, 1.5), tinte)
	return 0.45


# Cordyline australis: un tronco gris corchoso que se ramifica una o dos veces en candelabro; en cada punta un penacho
# denso de hojas angostas (las de arriba derechas, las de abajo arqueadas) y bajo él una falda de hojas secas pardas
# que cuelgan pegadas a la rama (foto de 2014)
func cordyline(rng: RandomNumberGenerator, tr: Malla, hojas: Malla) -> float:
	var E: Dictionary = ESPECIES["cordyline"]
	var H := rng.randf_range(3.8, 5.5)
	var hb := H * rng.randf_range(0.4, 0.55)
	rama(tr, [Vector3.DOWN * 0.2, Vector3.UP * hb * 0.5, Vector3.UP * hb], [0.19, 0.15, 0.13], 7, E["corteza"])
	var nb := rng.randi_range(2, 3)
	for i in nb:
		var az := TAU * i / nb + rng.randf_range(-0.4, 0.4)
		var d := Vector3(cos(az) * 0.45, 1, sin(az) * 0.45).normalized()
		var base := Vector3.UP * hb
		var largo := (H - hb) * rng.randf_range(0.75, 1.0)
		var tope := base + d * largo
		if rng.randf() < 0.5 and largo > 1.4:
			# se parte otra vez en dos
			var medio := base + d * largo * 0.55
			rama(tr, [base, medio], [0.1, 0.085], 6, E["corteza"])
			for s in [-1.0, 1.0]:
				var d2: Vector3 = (d + Vector3(-d.z, 0, d.x) * 0.5 * s).normalized()
				var t2: Vector3 = medio + d2 * largo * 0.5
				rama(tr, [medio, t2], [0.075, 0.06], 5, E["corteza"])
				falda(rng, hojas, t2, 0.5, 8)
				penacho(rng, hojas, t2, 0.8, 0.04, E["hojas"], 30)
		else:
			var medio := base + (tope - base) * 0.5 + Vector3(d.x, 0, d.z) * 0.12
			rama(tr, [base, medio, tope], [0.1, 0.085, 0.07], 6, E["corteza"])
			falda(rng, hojas, tope, 0.55, 10)
			penacho(rng, hojas, tope, 0.9, 0.045, E["hojas"], 40)
	return 0.19


# un penacho de hojas en cinta: n hojas que salen de p en todas direcciones, arqueadas
static func penacho(rng: RandomNumberGenerator, m: Malla, p: Vector3, L: float, ancho: float, col: Color, n: int, solo_arriba := false) -> void:
	for i in n:
		var az := rng.randf() * TAU
		var el := rng.randf_range(-0.5, 1.45) if not solo_arriba else rng.randf_range(0.5, 1.4)
		var d := Vector3(cos(az) * cos(el), sin(el), sin(az) * cos(el))
		var lado := d.cross(Vector3.UP).normalized() * ancho
		if lado == Vector3.ZERO:
			lado = Vector3.RIGHT * ancho
		var l := L * rng.randf_range(0.75, 1.15)
		var a := p
		var tinte := col * rng.randf_range(0.8, 1.15)
		tinte.a = 1
		var prev_w := lado * 0.4
		# las hojas bajas se arquean más
		var arco := lerpf(0.45, 0.15, clampf((el + 0.5) / 1.9, 0.0, 1.0))
		for j in range(1, 4):
			var t := j / 3.0
			var b := p + d * l * t + Vector3.DOWN * l * arco * t * t
			var w := lado * (1.0 - t * 0.85)
			var nn := (d + Vector3.UP).normalized()
			m.quad(a - prev_w, b - w, b + w, a + prev_w, tinte, nn)
			a = b; prev_w = w


# la falda de hojas secas de la cordyline: cintas pardas que cuelgan de p pegadas a la rama
static func falda(rng: RandomNumberGenerator, m: Malla, p: Vector3, L: float, n: int) -> void:
	for i in n:
		var az := TAU * i / n + rng.randf_range(-0.2, 0.2)
		var d := Vector3(cos(az), 0, sin(az))
		var lado := d.cross(Vector3.UP) * 0.05
		var a := p + d * 0.08 + Vector3.DOWN * 0.05
		var b := a + d * 0.12 + Vector3.DOWN * L * rng.randf_range(0.8, 1.15)
		var tinte := Color(0.24, 0.17, 0.1) * rng.randf_range(0.8, 1.15)  # el material sólido no pasa el color a lineal: va oscuro
		tinte.a = 1
		m.quad(a - lado, b - lado * 0.6, b + lado * 0.6, a + lado, tinte, (d + Vector3.UP * 0.2).normalized())


# una bola recortada junto a la solera: tarjetas tangentes a la esfera achatada (escama())
func arbusto(rng: RandomNumberGenerator, fo: Malla) -> float:
	var R := rng.randf_range(0.6, 0.8)
	var ry := R * rng.randf_range(0.75, 0.9)
	var c := Vector3(0, ry * 0.55, 0)  # apoyada en el suelo, no flotando
	var col: Color = ESPECIES["arbusto"]["hojas"]
	for i in 32:
		var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.4, 1), rng.randf_range(-1, 1))
		if d.length() < 0.1:
			continue
		d = d.normalized() * rng.randf_range(0.88, 1.0)
		var nrm := Vector3(d.x / R, d.y / ry, d.z / R).normalized()
		escama(fo, rng, c + Vector3(d.x * R, d.y * ry, d.z * R), nrm, rng.randf_range(0.55, 0.72), col * lerpf(0.85, 1.05, (d.y + 0.4) / 1.4))
	return 0.0


# una mata de agapantos: tres a cinco matas de hojas en cinta de ~4 cm que salen del suelo y se arquean hacia afuera
# hasta casi tocarlo (fotos de 2014 y 2024; sin flores: las fotos no las muestran)
func agapanto(rng: RandomNumberGenerator, hojas: Malla) -> float:
	var col: Color = ESPECIES["agapanto"]["hojas"]
	for i in rng.randi_range(3, 5):
		var p := Vector3(rng.randf_range(-0.35, 0.35), 0, rng.randf_range(-0.35, 0.35))
		for j in 14:
			var az := rng.randf() * TAU
			var el := rng.randf_range(0.6, 1.4)
			var d := Vector3(cos(az) * cos(el), sin(el), sin(az) * cos(el))
			var lado := d.cross(Vector3.UP).normalized() * 0.022
			var l := rng.randf_range(0.5, 0.75)
			var arco := lerpf(0.9, 0.35, (el - 0.6) / 0.8)  # las más abiertas caen más
			var tinte := col * rng.randf_range(0.82, 1.15)
			tinte.a = 1
			var a := p
			var prev_w := lado * 0.6
			for k in range(1, 4):
				var t := k / 3.0
				var b := p + d * l * t + Vector3.DOWN * l * arco * t * t
				var w := lado * (1.0 - t * 0.7)
				hojas.quad(a - prev_w, b - w, b + w, a + prev_w, tinte, (d + Vector3.UP).normalized())
				a = b; prev_w = w
	return 0.0

