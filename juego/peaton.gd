# El peatón que maneja jugador.gd (y los otros de red.gd y cine.gd): una persona de 1,75 m de polera tipo polo (cuello,
# tapeta y mangas cortas con puño), jeans con cinturón y zapatillas blancas, articulada en caderas, rodillas, tobillos,
# hombros, codos y cuello, y animada en código según la velocidad: quieto (respira y se balancea), camina, trota y corre
# (más zancada, más inclinado, codos doblados) y salta (una rodilla arriba; en el triple salto de jugador.gd, el segundo
# con los brazos arriba y el tercero con una voltereta: saltar()). La fase de los pasos avanza con la distancia
# recorrida, para que los pies no patinen; las poses se mezclan en ~0,1 s. Mira hacia -Z.
# Cada hueso es una sola malla con una superficie por color, hecha de secciones (loft(): anillos elípticos o de
# esquinas redondeadas unidos con normales suaves), no de cápsulas: el torso se ensancha en los hombros, la cabeza tiene
# mentón, nariz, orejas, cejas y un pelo con volumen que termina en una línea de frente y patillas, las manos tienen
# palma, dedos juntos y pulgar, y la zapatilla, punta, suela y talón. Proporciones de un adulto de 1,75 m (la cabeza,
# ~1/7,5 del alto; el hombro a 1,45 m; la muñeca a ~0,84 m); las medidas son a ojo, no de una persona en particular.
# Las articulaciones están donde estaban (sentar() y vehiculo.gd cuentan con el muslo de 0,44 m y la canilla de 0,46).
#
# Con un arma (armas.gd: sostener(), y cada cuadro alza, mira, objetivo, patada y recarga) los brazos que la sostienen
# dejan la pose de animar(): cada mano va a su punto del arma (la derecha a la empuñadura, la izquierda al guardamanos o
# al cargador) resuelta como dos huesos (alcanzar(): el codo por el teorema del coseno), y se mezcla con la de animar()
# con un peso por brazo (pesos), así que sacar, guardar, el tajo del cuchillo y la voltereta pasan suaves. animar()
# sigue cada cuadro desde su propia pose (libre), no desde la del arma. Sin arma, todo es como antes (cine.gd).
extends Node3D

const COLORES := {"piel": "c4967a", "pelo": "2a1d16", "polera": "3b6fa0", "jeans": "2d3c58", "zapatilla": "e6e3dc", "suela": "3a3836",
	"cinturon": "3b2a1e", "hebilla": "b9b2a3", "ojos": "1d1714"}
# el arma
const IZQ := 0  # hombro[0] está en x < 0: mira hacia -Z, así que es el brazo izquierdo
const DER := 1  # el derecho, el que lleva el arma (mano[DER])
const L_BRAZO := 0.29  # m: del hombro al codo
const L_ANTEBRAZO := 0.29  # m: del codo a la palma (mano[i])
const PIVOTE := Vector3(0, 1.45, 0)  # entre los hombros: la pistola en alto gira en torno a esto
const PISTOLA_ALTA := Vector3(0.07, 0.02, -0.53)  # la empuñadura desde PIVOTE, en el marco de la mira: los brazos casi estirados, el alza bajo los ojos
const RIFLE_HOMBRO := Vector3(-0.05, 0.04, -0.05)  # el bolsillo del hombro (la culata) desde la articulación del hombro derecho
# el rifle bajo (listo, cruzado frente al cuerpo, la boca abajo y a la izquierda), en el marco del torso
const RIFLE_BAJO := Transform3D(Basis(Vector3.UP, 0.45) * Basis(Vector3.RIGHT, -0.8), Vector3(0.12, 0.28, -0.15))
const TORSION_RIFLE := [-0.3, -0.55]  # rad: el torso girado a la derecha, bajo y en alto: el hombro izquierdo adelante, para que la mano izquierda alcance el guardamanos
# el arma en la mano cuando la mano no la sostiene en alto (la pistola y el cuchillo al costado; el rifle en la voltereta)
const REPOSO := {"pistola": Transform3D(Basis(Vector3.RIGHT, -0.35), Vector3(0, -0.01, -0.02)),
	"cuchillo": Transform3D(Basis(Vector3.RIGHT, -0.15), Vector3(0, 0, -0.01)),
	"rifle": Transform3D(Basis(Vector3.RIGHT, -0.2), Vector3.ZERO)}
const POLO := [Vector3(-0.5, -1.0, 0.25), Vector3(0.6, -1.0, 0.35)]  # hacia dónde apunta cada codo, en el marco del torso: abajo, afuera y atrás
# el tajo del cuchillo: la palma derecha en el marco del peatón a los s del golpe (atrás arriba, adelante, cruzada abajo)
const TAJO := [[0.0, Vector3(0.36, 1.6, 0.05)], [0.08, Vector3(0.33, 1.62, -0.06)], [0.15, Vector3(0.02, 1.34, -0.52)],
	[0.24, Vector3(-0.24, 1.08, -0.34)]]
const GOLPE := 0.24  # s que la mano sigue el tajo; después vuelve a la pose de animar()

var colores := {}  # los que cambian de COLORES (cine.gd: un peatón distinto de otro), antes de agregarlo a la escena
var fase := 0.0
var t := 0.0
var cadera := Node3D.new()
var torso := Node3D.new()
var cabeza := Node3D.new()
var muslo: Array[Node3D] = []
var canilla: Array[Node3D] = []
var pie: Array[Node3D] = []
var hombro: Array[Node3D] = []
var codo: Array[Node3D] = []
var mats := {}
var mano: Array[Node3D] = []  # la palma de cada mano, al final del antebrazo (el arma va en mano[DER])
# el arma (armas.gd)
var arma: Node3D = null  # su modelo (modelos/entorno/armas.gd): el origen en la empuñadura, «apoyo» y «cargador» para la mano izquierda
var tipo_arma := ""  # "", "cuchillo", "pistola" o "rifle"
var alza := 0.0  # 0 el arma abajo … 1 en alto (apuntando o disparando)
var mira := 0.0  # rad: la inclinación de la cámara (jugador.pitch), sin objetivo
var objetivo := Vector3.INF  # el punto bajo la mira: el arma en alto lo apunta
var patada := 0.0  # el retroceso del último disparo (disparo()), que se apaga solo
var recarga := -1.0  # 0 … 1 mientras recarga (la mano izquierda va al cargador); -1 si no
var t_golpe := INF  # s desde el último tajo del cuchillo (golpear())
var pesos := PackedFloat64Array([0.0, 0.0])  # cuánto manda el arma en cada brazo (IZQ, DER)
var ik := [[Quaternion(), 0.0], [Quaternion(), 0.0]]  # la última pose del arma de cada brazo: [hombro, codo]
var libre := [[Vector3.ZERO, 0.0], [Vector3.ZERO, 0.0]]  # la pose de animar() de cada brazo antes del arma
var armado := -10  # el cuadro en que los brazos fueron del arma
# los ángulos que busca cada articulación en este cuadro, por lado i (0 izquierda, 1 derecha): obj[i * 6 + j], con j en
# M (muslo), R (rodilla), P (pie), H (hombro), HZ (hombro hacia afuera), C (codo); uno solo para todos los cuadros
enum {M, R, P, H, HZ, C}
var obj := PackedFloat64Array()
# el salto en curso (saltar(), desde jugador.gd: el triple salto): 1, una rodilla arriba; 2, además los brazos arriba;
# 3, una voltereta hacia adelante, encogido, y después los brazos abiertos. 0 en el suelo (o en el aire sin saltar).
var salto := 0
var t_salto := 0.0
var vuelta := 0.0  # rad: el giro de la voltereta, en la cadera (negativo: la cabeza hacia adelante)
const VUELTA_0 := 0.06  # s desde el salto hasta que empieza a girar
const VUELTA_T := 0.8  # s que dura la vuelta (el tercero sube 1,0 s y está 2 s en el aire)
var _sup := {}  # la malla del hueso que se arma: color -> [vértices, normales, índices]
# el contorno del torso (y, medio ancho, media profundidad, z del centro) en el marco del torso (origen en la cadera):
# la cintura, el pecho y los hombros anchos; la tapeta y el cuello se apoyan en él
const TORSO := [[0.10, 0.172, 0.118, 0.0], [0.2, 0.158, 0.108, 0.0], [0.32, 0.168, 0.118, -0.006], [0.42, 0.176, 0.116, -0.004],
	[0.48, 0.172, 0.104, 0.004], [0.522, 0.148, 0.09, 0.008], [0.552, 0.108, 0.074, 0.008], [0.57, 0.07, 0.06, 0.008]]


func _ready() -> void:
	for k in COLORES:
		mats[k] = material(Color(colores.get(k, COLORES[k])), k)
	# los que salen de otro: el cuello y los puños de la polera, un poco más oscuros (el tejido de punto); los labios
	mats["puno"] = material(Color(colores.get("polera", COLORES["polera"])).darkened(0.18), "polera")
	mats["cordones"] = material(Color(colores.get("zapatilla", COLORES["zapatilla"])).darkened(0.25), "zapatilla")
	mats["labios"] = material(Color(colores.get("piel", COLORES["piel"])).darkened(0.22).lerp(Color("a0524a"), 0.25), "piel")
	cadera.position.y = 0.95
	add_child(cadera)
	# la pelvis: los jeans de la entrepierna a la cintura, el cinturón y su hebilla
	empezar()
	loft("jeans", [Y(-0.15, 0.07, 0.06), Y(-0.1, 0.15, 0.1), Y(-0.04, 0.172, 0.112), Y(0.03, 0.172, 0.11), Y(0.085, 0.165, 0.108)], 14)
	loft("cinturon", [Y(0.058, 0.17, 0.112), Y(0.062, 0.171, 0.113), Y(0.098, 0.169, 0.111), Y(0.102, 0.162, 0.104)], 14, 2.0, false, false)
	caja("hebilla", Vector3(0, 0.08, -0.114), Vector3(0.042, 0.03, 0.008))
	terminar(cadera)
	cadera.add_child(torso)
	# el torso: la polera hasta la base del cuello, con una franja de puño en el borde, el cuello del polo y la tapeta
	empezar()
	var secs := []
	for r in TORSO:
		secs.append(Y(r[0], r[1], r[2], 0.0, r[3]))
	loft("polera", secs, 16, 2.4)
	loft("puno", [Y(0.096, 0.168, 0.114), Y(0.1, 0.176, 0.12), Y(0.125, 0.172, 0.117), Y(0.13, 0.166, 0.112)], 16, 2.4, false, false)
	loft("puno", [Y(0.535, 0.112, 0.094, 0.0, 0.004), Y(0.548, 0.108, 0.088, 0.0, 0.004), Y(0.585, 0.074, 0.064, 0.0, 0.01),
		Y(0.592, 0.066, 0.058, 0.0, 0.01), Y(0.575, 0.06, 0.054, 0.0, 0.01)], 14, 2.0, false, false)
	var zf := -torso_z(0.48) - 0.004  # la tapeta del polo: una franja con dos botones, al frente bajo el cuello
	caja("puno", Vector3(0, 0.505, zf), Vector3(0.034, 0.075, 0.008), -0.17)
	for yb in [0.49, 0.525]:
		caja("hebilla", Vector3(0, yb, zf - 0.0055), Vector3(0.012, 0.012, 0.004))
	loft("piel", [Y(0.5, 0.058, 0.055, 0.0, 0.012), Y(0.6, 0.052, 0.05, 0.0, 0.016), Y(0.68, 0.05, 0.05, 0.0, 0.02)], 10, 2.0, false, false)  # el cuello
	terminar(torso)
	cabeza.position.y = 0.63
	torso.add_child(cabeza)
	armar_cabeza()
	for lado in [-1.0, 1.0]:
		var h := Node3D.new()
		h.position = Vector3(0.192 * lado, 0.5, 0)  # el ancho de hombros, ~0,5 m con las mangas
		torso.add_child(h)
		# la manga: más ancha que el brazo, desde el hombro hasta medio brazo, con su puño
		empezar()
		loft("polera", [Y(0.035, 0.026, 0.036, -0.03 * lado), Y(0.02, 0.052, 0.058, -0.012 * lado), Y(-0.02, 0.062, 0.064, -0.002 * lado),
			Y(-0.1, 0.06, 0.062, 0.003 * lado)], 12, 2.0, true, false)
		loft("puno", [Y(-0.1, 0.06, 0.062, 0.003 * lado), Y(-0.135, 0.059, 0.061, 0.004 * lado), Y(-0.14, 0.047, 0.05, 0.004 * lado)], 12)
		loft("piel", [Y(-0.12, 0.043, 0.046), Y(-0.22, 0.041, 0.044), Y(-0.29, 0.038, 0.041)], 10, 2.0, false, true)
		terminar(h)
		var c := Node3D.new()
		c.position.y = -0.29
		h.add_child(c)
		empezar()
		armar_antebrazo(-lado)
		terminar(c)
		var mn := Node3D.new()  # la palma (armar_antebrazo(): la muñeca a 0,235 m del codo, la punta de los dedos a 0,405)
		mn.position.y = -L_ANTEBRAZO
		c.add_child(mn)
		hombro.append(h)
		codo.append(c)
		mano.append(mn)
		var m := Node3D.new()
		m.position = Vector3(0.095 * lado, -0.02, 0)
		cadera.add_child(m)
		empezar()  # el muslo, del pliegue de la ingle a la rodilla
		loft("jeans", [Y(0.07, 0.07, 0.08, -0.025 * lado), Y(0.0, 0.094, 0.098, -0.004 * lado), Y(-0.2, 0.082, 0.086),
			Y(-0.38, 0.066, 0.07, 0.0, -0.004), Y(-0.46, 0.06, 0.064, 0.0, -0.004)], 12, 2.0, true, false)
		terminar(m)
		var r := Node3D.new()
		r.position.y = -0.44
		m.add_child(r)
		empezar()  # la canilla, con la pantorrilla atrás y la basta ancha sobre la zapatilla
		loft("jeans", [Y(0.03, 0.06, 0.064), Y(-0.12, 0.064, 0.072, 0.0, 0.01), Y(-0.3, 0.054, 0.058, 0.0, 0.004),
			Y(-0.4, 0.058, 0.064, 0.0, 0.004), Y(-0.415, 0.06, 0.068, 0.0, 0.006), Y(-0.416, 0.04, 0.045, 0.0, 0.006)], 12)
		terminar(r)
		var p := Node3D.new()
		p.position.y = -0.46
		r.add_child(p)
		empezar()
		armar_zapatilla()
		terminar(p)
		muslo.append(m)
		canilla.append(r)
		pie.append(p)


func material(col: Color, k: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.95 if k == "jeans" else 0.8
	if k == "piel":
		m.roughness = 0.6
		m.subsurf_scatter_enabled = true
		m.subsurf_scatter_strength = 0.3
	elif k == "hebilla":
		m.roughness = 0.4
		m.metallic = 0.6
	elif k == "pelo":
		m.roughness = 0.65
		m.cull_mode = BaseMaterial3D.CULL_DISABLED  # el casco del pelo es una sola capa: su borde se ve por dentro
	return m


# la cabeza, en el marco del cuello (cabeza, a 1,58 m del suelo): del mentón (1,52) a la coronilla (1,75 con el pelo);
# la cara mira hacia -Z
func armar_cabeza() -> void:
	empezar()
	loft("piel", [Y(-0.062, 0.018, 0.016, 0.0, -0.064), Y(-0.056, 0.04, 0.034, 0.0, -0.058), Y(-0.035, 0.058, 0.062, 0.0, -0.034),
		Y(0.0, 0.068, 0.084, 0.0, -0.012), Y(0.045, 0.074, 0.098, 0.0, 0.0), Y(0.09, 0.077, 0.101, 0.0, 0.004),
		Y(0.125, 0.072, 0.095, 0.0, 0.006), Y(0.152, 0.054, 0.072, 0.0, 0.008), Y(0.166, 0.026, 0.036, 0.0, 0.008)], 14, 2.0)
	# la nariz: una cuña que sale de la cara entre los ojos y la boca
	loft("piel", [Z(-0.088, 0.036, 0.007, 0.022), Z(-0.103, 0.026, 0.011, 0.014), Z(-0.112, 0.019, 0.01, 0.008)], 8, 2.0, false, true)
	for x in [-1.0, 1.0]:
		elipsoide("piel", Vector3(0.074 * x, 0.042, 0.012), Vector3(0.013, 0.03, 0.02), 8, 4)  # las orejas
		elipsoide("ojos", Vector3(0.03 * x, 0.064, -0.088), Vector3(0.009, 0.009, 0.007), 8, 4)
		caja("pelo", Vector3(0.032 * x, 0.083, -0.089), Vector3(0.032, 0.007, 0.012), 0.0, 0.1 * x)  # las cejas
	caja("labios", Vector3(0, 0.0, -0.083), Vector3(0.036, 0.009, 0.01))
	# el pelo: un casco con volumen (1-2 cm sobre la cabeza, más arriba) desde la coronilla hasta la línea del pelo,
	# que va por la frente (y = 0,136), sobre las orejas (0,074), baja a patillas delante de ellas y cae a la nuca; su borde
	# entra hacia la cabeza para que el pelo tenga grosor
	var n := 16
	var anillos := 6
	var cen := Vector3(0, 0.072, 0.012)
	var rad := Vector3(0.09, 0.118, 0.112)
	var sv := PackedVector3Array()
	for j in anillos + 2:
		for i in n:
			var phi := TAU * i / n
			var dz := sin(phi)  # -1: al frente
			var frente := maxf(0.0, -dz)
			var atras := maxf(0.0, dz)
			var ycut := 0.074 + 0.062 * pow(frente, 2.0) - 0.08 * pow(atras, 1.2) - 0.035 * exp(-pow((frente - 0.33) / 0.1, 2.0))
			var tcut := acos(clampf((ycut - cen.y) / rad.y, -1.0, 1.0))
			var th := tcut * minf(j, anillos) / anillos
			var q := Vector3(sin(th) * cos(phi) * rad.x, cos(th) * rad.y, sin(th) * dz * rad.z)
			q *= 1.0 + 0.09 * frente * cos(th) * sin(th) * 2.0  # el jopo: más volumen arriba de la frente
			if j == 0:
				q = Vector3(0, rad.y, 0)
			if j == anillos and i % 2 == 1:  # mechones: el borde en punta, más en la frente y las patillas
				q.y -= 0.004 + 0.01 * frente
			if j == anillos + 1:  # el borde, hacia adentro (el grosor del pelo)
				q = Vector3(q.x * 0.88, q.y - 0.002, q.z * 0.9)
			sv.append(cen + q)
	var ref := PackedVector3Array()
	for j in anillos + 2:
		ref.append(cen + Vector3(0, -0.03, 0))
	malla_anillos("pelo", sv, n, anillos + 2, ref, false, false)
	terminar(cabeza)


# el antebrazo, la muñeca y la mano (en el marco del codo); adentro: hacia dónde queda el cuerpo en x (-1 o 1). La palma
# mira hacia el muslo, el pulgar hacia adelante, los dedos juntos y un poco recogidos
func armar_antebrazo(adentro: float) -> void:
	loft("piel", [Y(0.03, 0.036, 0.04), Y(-0.03, 0.042, 0.046, 0.0, 0.004), Y(-0.12, 0.037, 0.042, 0.0, 0.002),
		Y(-0.235, 0.024, 0.032)], 10, 2.0, true, false)
	var a := adentro * 0.004
	loft("piel", [Y(-0.235, 0.024, 0.032), Y(-0.26, 0.022, 0.042), Y(-0.31, 0.021, 0.046, a),
		Y(-0.335, 0.018, 0.044, 2 * a, 0.002), Y(-0.37, 0.016, 0.04, 4 * a, 0.004), Y(-0.395, 0.013, 0.032, 6 * a, 0.006),
		Y(-0.405, 0.006, 0.016, 7 * a, 0.006)], 10, 2.6, false, true)
	# el pulgar: de la base de la palma hacia adelante y abajo
	tubo("piel", Vector3(adentro * 0.006, -0.262, -0.028), Vector3(adentro * 0.014, -0.325, -0.06), 0.016, 0.012, 6)


# la zapatilla, en el marco del tobillo (a 3 cm del suelo): de talón (z 0,08) a punta (z -0.21), la capellada blanca
# hasta el borde del tobillo y una suela de goma de 2 cm que sube un poco en la punta y el talón
func armar_zapatilla() -> void:
	const B := -0.046  # la planta, bajo el tobillo
	var perfil := [  # z, medio ancho, alto de la capellada sobre la suela
		[0.088, 0.024, 0.038], [0.082, 0.037, 0.066], [0.065, 0.044, 0.076], [0.035, 0.047, 0.08], [-0.02, 0.05, 0.068], [-0.08, 0.054, 0.05],
		[-0.14, 0.052, 0.038], [-0.18, 0.045, 0.03], [-0.203, 0.032, 0.022], [-0.212, 0.014, 0.012]]
	var secs := []
	for f in perfil:
		var hh: float = f[2] / 2.0
		var sube: float = 0.012 * pow(maxf(0.0, (-0.12 - f[0]) / 0.09), 2.0)  # la punta levantada
		secs.append([Vector3(0, B + 0.016 + hh + sube, f[0]), Vector3(f[1], 0, 0), Vector3(0, hh, 0)])
	loft("zapatilla", secs, 12, 2.8)
	# los cordones: una franja gris sobre el empeine, de la punta de la lengüeta a cerca de la punta
	loft("cordones", [[Vector3(0, B + 0.091, 0.02), Vector3(0.02, 0, 0), Vector3(0, 0.012, 0)],
		[Vector3(0, B + 0.081, -0.04), Vector3(0.022, 0, 0), Vector3(0, 0.012, 0)],
		[Vector3(0, B + 0.064, -0.1), Vector3(0.018, 0, 0), Vector3(0, 0.01, 0)]], 6, 2.0)
	secs = []
	var sp := [[0.094, 0.026], [0.084, 0.042], [0.06, 0.05], [0.0, 0.053], [-0.09, 0.059], [-0.17, 0.052], [-0.205, 0.038], [-0.22, 0.016]]
	for f in sp:
		var hh: float = 0.012 if f[0] > -0.19 and f[0] < 0.08 else 0.017  # sube en la punta y el talón
		secs.append([Vector3(0, B + hh, f[0]), Vector3(f[1], 0, 0), Vector3(0, hh, 0)])
	loft("suela", secs, 12, 5.0)
	# el borde del tobillo, oscuro, y la lengüeta
	loft("suela", [Y(0.05, 0.045, 0.04, 0.0, 0.03), Y(0.035, 0.05, 0.046, 0.0, 0.03)], 10, 2.0, false, false)


# ---------------------------------------------------------------- mallas por secciones

# una sección horizontal (en el plano XZ, a la altura y), elíptica: medio ancho rx, media profundidad rz
func Y(y: float, rx: float, rz: float, x := 0.0, z := 0.0) -> Array:
	return [Vector3(x, y, z), Vector3(rx, 0, 0), Vector3(0, 0, rz)]


# una sección vertical (en el plano XY, en z): medio ancho rx, medio alto ry, centro a la altura y
func Z(z: float, y: float, rx: float, ry: float) -> Array:
	return [Vector3(0, y, z), Vector3(rx, 0, 0), Vector3(0, ry, 0)]


func empezar() -> void:
	_sup = {}


# une las secciones [centro, eje u, eje v] con anillos de n puntos (e: 2 elipse, más: esquinas más cuadradas) y tapa
# los extremos con un vértice al centro; las normales son suaves dentro de cada pieza
func loft(mat: String, secs: Array, n: int, e := 2.0, tapa0 := true, tapa1 := true, a0 := 0.0) -> void:
	var v := PackedVector3Array()
	var ref := PackedVector3Array()
	for s in secs:
		ref.append(s[0])
		for i in n:
			var a := a0 + TAU * i / n
			var c := cos(a)
			var s_ := sin(a)
			v.append(s[0] + s[1] * signf(c) * pow(absf(c), 2.0 / e) + s[2] * signf(s_) * pow(absf(s_), 2.0 / e))
	malla_anillos(mat, v, n, secs.size(), ref, tapa0, tapa1)


func malla_anillos(mat: String, v: PackedVector3Array, n: int, k: int, ref: PackedVector3Array, tapa0: bool, tapa1: bool) -> void:
	if not _sup.has(mat):
		_sup[mat] = [PackedVector3Array(), PackedVector3Array(), PackedInt32Array()]
	var tris := PackedInt32Array()
	var pts := v.duplicate()
	var refs := []  # el punto de adentro de cada triángulo, para orientarlo hacia afuera
	for j in k - 1:
		var r := (ref[j] + ref[j + 1]) / 2.0
		for i in n:
			var a := j * n + i
			var b := j * n + (i + 1) % n
			var c := a + n
			var d := b + n
			tris.append_array([a, b, d, a, d, c])
			refs.append_array([r, r])
	for lado in 2:
		if not (tapa0 if lado == 0 else tapa1):
			continue
		var j := 0 if lado == 0 else k - 1
		var centro := 0.0 * v[0]
		for i in n:
			centro += v[j * n + i]
		centro /= n
		pts.append(centro)
		var ci := pts.size() - 1
		var r := ref[1] if lado == 0 else ref[k - 2]
		if r.distance_to(centro) < 0.001:
			r = centro - (ref[k - 1] - ref[0]).normalized() * (1.0 if lado == 1 else -1.0) * 0.01
		for i in n:
			tris.append_array([j * n + i, j * n + (i + 1) % n, ci])
			refs.append(r)
	var nor := PackedVector3Array()
	nor.resize(pts.size())
	for q in tris.size() / 3:
		var a := pts[tris[q * 3]]
		var b := pts[tris[q * 3 + 1]]
		var d := pts[tris[q * 3 + 2]]
		var g := (d - a).cross(b - a)
		if g.dot((a + b + d) / 3.0 - refs[q]) < 0:
			var tmp := tris[q * 3 + 1]
			tris[q * 3 + 1] = tris[q * 3 + 2]
			tris[q * 3 + 2] = tmp
			g = -g
		for o in 3:
			nor[tris[q * 3 + o]] += g
	var s: Array = _sup[mat]
	var base: int = s[0].size()
	for i in pts.size():
		s[0].append(pts[i])
		s[1].append(nor[i].normalized() if nor[i].length_squared() > 0.0 else Vector3.UP)
	for i in tris:
		s[2].append(base + i)


func elipsoide(mat: String, c: Vector3, r: Vector3, n: int, m: int) -> void:
	var secs := []
	for j in range(1, m):
		var th := PI * j / m
		secs.append(Y(c.y + cos(th) * r.y, sin(th) * r.x, sin(th) * r.z, c.x, c.z))
	loft(mat, secs, n)


# un tubo de a a b (los dedos, el pulgar), con radios ra y rb y las puntas cerradas
func tubo(mat: String, a: Vector3, b: Vector3, ra: float, rb: float, n: int) -> void:
	var d := (b - a).normalized()
	var u := d.cross(Vector3.FORWARD if absf(d.z) < 0.9 else Vector3.UP).normalized()
	var w := d.cross(u)
	loft(mat, [[a - d * ra * 0.5, u * ra * 0.6, w * ra * 0.6], [a, u * ra, w * ra], [b, u * rb, w * rb], [b + d * rb * 0.6, u * rb * 0.5, w * rb * 0.5]], n)


# una caja (en el centro c, de tamaño s), girada rx en x y rz en z
func caja(mat: String, c: Vector3, s: Vector3, rx := 0.0, rz := 0.0) -> void:
	var b := Basis.from_euler(Vector3(rx, 0, rz))
	var h := s / 2.0
	loft(mat, [[c + b * Vector3(0, 0, -h.z), b * Vector3(h.x * 1.41, 0, 0), b * Vector3(0, h.y * 1.41, 0)],
		[c + b * Vector3(0, 0, h.z), b * Vector3(h.x * 1.41, 0, 0), b * Vector3(0, h.y * 1.41, 0)]], 4, 2.0, true, true, PI / 4)


# la media profundidad del torso a la altura y (para apoyar algo en el pecho)
func torso_z(y: float) -> float:
	for i in TORSO.size() - 1:
		var a: Array = TORSO[i]
		var b: Array = TORSO[i + 1]
		if y <= b[0]:
			var u := clampf((y - a[0]) / (b[0] - a[0]), 0.0, 1.0)
			return lerpf(a[2] - a[3], b[2] - b[3], u)
	return TORSO[-1][2]


func terminar(padre: Node3D) -> void:
	var am := ArrayMesh.new()
	for k in _sup:
		var s: Array = _sup[k]
		var a := []
		a.resize(Mesh.ARRAY_MAX)
		a[Mesh.ARRAY_VERTEX] = s[0]
		a[Mesh.ARRAY_NORMAL] = s[1]
		a[Mesh.ARRAY_INDEX] = s[2]
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
		am.surface_set_material(am.get_surface_count() - 1, mats[k])
	var mi := MeshInstance3D.new()
	mi.mesh = am
	padre.add_child(mi)
	_sup = {}


func saltar(n: int) -> void:
	salto = n
	t_salto = 0.0


# rapidez: m/s horizontales; en_suelo: si pisa
func animar(dt: float, rapidez: float, en_suelo: bool) -> void:
	soltar_brazos()
	t += dt
	t_salto += dt
	t_golpe += dt
	patada *= exp(-16.0 * dt)
	if en_suelo:
		salto = 0
	var paso := 0.55 + 0.25 * rapidez  # m por paso: 0,9 caminando de verdad, 2,5 a 8 m/s, 5 a 18 m/s
	fase += dt * rapidez / (2.0 * paso) * TAU
	var mov := smoothstep(0.3, 1.2, rapidez)    # 0 quieto, 1 en movimiento
	var trote := smoothstep(2.5, 6.0, rapidez)  # 0 camina, 1 trota
	var carrera := smoothstep(10.0, 16.0, rapidez)
	var p := fase
	obj.resize(12)
	for i in 2:
		var q := p + PI * i  # la pierna derecha media vuelta después
		var s := sin(q)
		var balanceo := cos(q)  # >0: la pierna va hacia adelante (en el aire)
		var amp_m := lerpf(0.42, 0.75, trote) + 0.2 * carrera
		var th := s * amp_m
		var kn := -(lerpf(0.06, 0.25, trote) + lerpf(0.65, 1.5, trote) * pow(max(balanceo, 0.0), 1.4))
		obj[i * 6 + M] = th * mov
		obj[i * 6 + R] = kn * mov - 0.04 * (1.0 - mov)
		obj[i * 6 + P] = -(th + kn) * 0.45 * mov
		var amp_b := lerpf(0.35, 0.8, trote) + 0.2 * carrera
		obj[i * 6 + H] = -s * amp_b * mov
		obj[i * 6 + HZ] = (0.07 + 0.05 * trote * mov) * (-1 if i == 0 else 1)  # hacia afuera
		obj[i * 6 + C] = (lerpf(0.2, 1.35, trote) * mov + 0.1 * (1.0 - mov) + 0.08 * sin(t * 1.3))
	var bote := lerpf(0.03 * pow(sin(p), 2.0), 0.07 * abs(cos(p)), trote) * mov
	var y := 0.95 - bote - 0.03 * trote * mov
	var lean := -(0.04 + 0.16 * trote + 0.14 * carrera) * mov
	var giro := 0.12 * sin(p) * (1.0 + trote) * mov
	var resp := 0.012 * sin(t * 1.7) * (1.0 - mov)
	if not en_suelo:  # en el aire: una rodilla arriba, los brazos abiertos
		obj[0 + M] = 0.75
		obj[0 + R] = -1.1
		obj[6 + M] = -0.2
		obj[6 + R] = -0.45
		obj[0 + P] = 0.2
		obj[6 + P] = 0.3
		obj[0 + H] = -0.5
		obj[6 + H] = 0.6
		obj[0 + HZ] = -0.45
		obj[6 + HZ] = 0.45
		obj[0 + C] = 0.6
		obj[6 + C] = 0.6
		y = 0.95
		lean = -0.08
		if salto >= 2:
			giro = 0.0
		var u := clampf((t_salto - VUELTA_0) / VUELTA_T, 0.0, 1.0)
		if salto == 2:  # los dos brazos arriba, estirados
			for i in 2:
				obj[i * 6 + H] = 2.75
				obj[i * 6 + HZ] = 0.25 * (-1 if i == 0 else 1)
				obj[i * 6 + C] = 0.15
			lean = 0.06
		elif salto == 3 and u < 0.92:  # encogido: las rodillas al pecho y las manos en las canillas
			for i in 2:
				obj[i * 6 + M] = 1.85
				obj[i * 6 + R] = -2.15
				obj[i * 6 + P] = 0.35
				obj[i * 6 + H] = 0.75
				obj[i * 6 + HZ] = 0.22 * (-1 if i == 0 else 1)
				obj[i * 6 + C] = 1.1
			y = 1.02
			lean = -0.45
		elif salto == 3:  # la vuelta terminó: los brazos abiertos, las piernas casi estiradas, hasta caer
			for i in 2:
				obj[i * 6 + M] = 0.2 if i == 0 else -0.08
				obj[i * 6 + R] = -0.35 if i == 0 else -0.2
				obj[i * 6 + P] = 0.15
				obj[i * 6 + H] = 0.35
				obj[i * 6 + HZ] = 1.3 * (-1 if i == 0 else 1)
				obj[i * 6 + C] = 0.12
			lean = 0.04
		if salto == 3:
			vuelta = -TAU * u * u * (3.0 - 2.0 * u)
	# el arma: el torso deja de balancearse (y gira a la derecha con el rifle, o con el tajo), la cabeza sigue a la mira
	var torsion := 0.0  # rad, solo el torso (la cadera no)
	var sujeta := 0.0  # cuánto manda el arma sobre el torso y la cabeza
	if arma and salto != 3:
		if tipo_arma == "rifle":
			sujeta = 1.0
			torsion = lerpf(TORSION_RIFLE[0], TORSION_RIFLE[1], alza)
		elif tipo_arma == "pistola":
			sujeta = alza
		elif t_golpe < GOLPE + 0.1:  # el cuchillo: atrás al tomar impulso, adelante al cortar
			sujeta = 1.0
			torsion = lerpf(-0.35, 0.4, smoothstep(0.06, 0.2, t_golpe)) * (1.0 - smoothstep(GOLPE, GOLPE + 0.1, t_golpe))
		giro *= 1.0 - sujeta
		lean = lerpf(lean, -0.03, sujeta)
	var k := 1.0 - exp(-14.0 * dt)
	if salto != 3:  # en el suelo (o si cayó antes de terminar la vuelta): derecho por el camino más corto
		vuelta = lerpf(wrapf(vuelta, -PI, PI), 0.0, k)
	cadera.rotation.x = vuelta
	for i in 2:
		muslo[i].rotation.x = lerpf(muslo[i].rotation.x, obj[i * 6 + M], k)
		canilla[i].rotation.x = lerpf(canilla[i].rotation.x, obj[i * 6 + R], k)
		pie[i].rotation.x = lerpf(pie[i].rotation.x, obj[i * 6 + P], k)
		hombro[i].rotation.x = lerpf(hombro[i].rotation.x, obj[i * 6 + H], k)
		hombro[i].rotation.z = lerpf(hombro[i].rotation.z, obj[i * 6 + HZ], k)
		codo[i].rotation.x = lerpf(codo[i].rotation.x, obj[i * 6 + C], k)
	cadera.position.y = lerpf(cadera.position.y, y, k)
	torso.rotation.x = lerpf(torso.rotation.x, lean, k)
	torso.rotation.y = lerpf(torso.rotation.y, giro + torsion, k)
	cadera.rotation.y = lerpf(cadera.rotation.y, -giro * 0.6, k)
	torso.scale = Vector3(1.0 + resp, 1.0 + resp * 0.5, 1.0 + resp)
	cabeza.rotation.x = lerpf(cabeza.rotation.x, -lean * 0.6 + 0.02 * sin(t * 0.7) * (1.0 - mov) + mira * 0.6 * sujeta, k)
	cabeza.rotation.y = lerpf(cabeza.rotation.y, -torsion, k)
	if arma or pesos[IZQ] > 0.001 or pesos[DER] > 0.001:
		brazos_del_arma(dt)


# Sentado (vehiculo.gd: en la bicicleta): cada pie (el tobillo) va a su punto pies[i] = (adelante, arriba) en m desde la
# articulación de su cadera, con la pierna resuelta en su plano (dos huesos: muslo 0,44, canilla 0,46, la rodilla hacia
# adelante) y el pie horizontal; el torso inclinado incl rad hacia adelante, los hombros adelantados hombros rad y los
# codos doblados codos rad (las manos en el manubrio). Se mezcla como animar(), en ~0,1 s.
func sentar(dt: float, pies: Array, incl: float, hombros: float, codos: float) -> void:
	soltar_brazos()
	t += dt
	var k := 1.0 - exp(-14.0 * dt)
	const L1 := 0.44
	const L2 := 0.46
	for i in 2:
		var d: Vector2 = pies[i]
		var largo := clampf(d.length(), absf(L1 - L2) + 0.01, L1 + L2 - 0.005)
		var alfa := atan2(d.x, -d.y)  # desde la vertical hacia abajo, + adelante
		var beta := acos(clampf((L1 * L1 + largo * largo - L2 * L2) / (2.0 * L1 * largo), -1.0, 1.0))
		var gama := acos(clampf((L1 * L1 + L2 * L2 - largo * largo) / (2.0 * L1 * L2), -1.0, 1.0))
		var th := alfa + beta
		var kn := -(PI - gama)
		muslo[i].rotation.x = th  # la pierna sigue al pedal sin retraso: con la mezcla, el pie se despegaba
		canilla[i].rotation.x = kn
		pie[i].rotation.x = -(th + kn) - 0.1  # la punta un poco abajo
		muslo[i].rotation.z = 0.0
		hombro[i].rotation.x = lerpf(hombro[i].rotation.x, hombros, k)
		hombro[i].rotation.z = lerpf(hombro[i].rotation.z, 0.12 * (-1 if i == 0 else 1), k)
		codo[i].rotation.x = lerpf(codo[i].rotation.x, codos, k)
	cadera.position.y = lerpf(cadera.position.y, 0.95, k)
	cadera.rotation.y = lerpf(cadera.rotation.y, 0.0, k)
	salto = 0
	vuelta = 0.0
	cadera.rotation.x = 0.0
	torso.rotation.x = lerpf(torso.rotation.x, -incl, k)
	torso.rotation.y = lerpf(torso.rotation.y, 0.0, k)
	torso.scale = Vector3.ONE
	cabeza.rotation.x = lerpf(cabeza.rotation.x, incl * 0.75, k)
	cabeza.rotation.y = lerpf(cabeza.rotation.y, 0.0, k)  # lo que la giró el arma (animar()), si subió con ella


# Con el jetpack en el aire (vehiculo.gd pose_vuelo(); red.gd, la de otro jugador): las piernas colgando, un poco
# dobladas y meciéndose (la derecha adelante), las puntas de los pies abajo y las manos en los mandos de la cintura;
# inclinar es la del vuelo (la cabeza mira adelante, no al suelo). Se mezcla en ~0,15 s
func volar(dt: float, inclinar: Vector3) -> void:
	t += dt
	var k := 1.0 - exp(-8.0 * dt)
	var vaiven := 0.06 * sin(t * 2.1)
	var m_ := [0.14 + vaiven, -0.1 - vaiven]
	var rodilla := [-0.5, -0.28]
	var tobillo := [-0.55, -0.6]
	for i in 2:
		var lado := -1.0 if i == 0 else 1.0
		muslo[i].rotation.x = lerpf(muslo[i].rotation.x, m_[i], k)
		canilla[i].rotation.x = lerpf(canilla[i].rotation.x, rodilla[i], k)
		pie[i].rotation.x = lerpf(pie[i].rotation.x, tobillo[i], k)
		hombro[i].rotation.x = lerpf(hombro[i].rotation.x, 0.1, k)
		hombro[i].rotation.z = lerpf(hombro[i].rotation.z, 0.16 * lado, k)
		codo[i].rotation.x = lerpf(codo[i].rotation.x, 1.2, k)
	cadera.position.y = lerpf(cadera.position.y, 0.95, k)
	cadera.rotation = Vector3(0.0, lerpf(cadera.rotation.y, 0.0, k), 0.0)
	torso.rotation.x = lerpf(torso.rotation.x, -0.04, k)
	torso.rotation.y = lerpf(torso.rotation.y, 0.0, k)
	torso.scale = Vector3.ONE
	cabeza.rotation.x = lerpf(cabeza.rotation.x, 0.08 + inclinar.x * 0.7, k)
	salto = 0
	vuelta = 0.0


# ---------- lo que cambia con el cuerpo (perro.gd los reemplaza) ----------

# muerto (jugador.gd en su cuerpo, red.gd en el peatón de otro): de bruces, como un tablón que se vuelca desde los pies;
# f de 0 (de pie) a 1 (tendido: ~83°, el pecho y los brazos se hunden en el suelo)
func tendido(n: Node3D, f: float) -> void:
	n.rotation.x = -1.45 * f
	n.position.y = 0.1 * f


# donde va la mochila del jetpack (vehiculo.gd mochila_puesta(), en su marco: la cadera en el origen, arriba +Y, la
# espalda hacia +Z) y si lleva sus correas
func montura() -> Node3D:
	return torso


func con_correas() -> bool:
	return true


# la bandera que lleva (bandera.gd), en el mundo: en la espalda, inclinada hacia atrás (bandera.gd la escala)
func portabandera() -> Transform3D:
	return torso.global_transform * Transform3D(Basis(Vector3.RIGHT, 0.28), Vector3(0.05, -0.1, 0.17))


# ojo: la altura del brazo de la cámara (jugador.gd); etiqueta: la del nombre sobre otro jugador (red.gd); radio, alto y
# blanco: la cápsula que reciben los tiros de otro jugador (red.gd Otro), en el marco del peatón
func medidas() -> Dictionary:
	return {"ojo": 1.6, "etiqueta": 2.25, "radio": 0.32, "alto": 1.8, "blanco": Transform3D(Basis(), Vector3(0, 0.9, 0))}


# un golpe en p (en el marco del peatón) es en la cabeza (vale el doble: red.gd), como en los muñecos de blancos.gd; _dir,
# hacia dónde iba el tiro en ese marco, lo usa la gata (gata.gd), cuya cápsula de los tiros es mucho más grande que ella
func es_cabeza(p: Vector3, _dir := Vector3.ZERO) -> bool:
	return p.y > 1.52


# ---------- el arma (armas.gd) ----------

# el arma en la mano derecha (el modelo es de armas.gd, que lo crea); tipo "" la guarda: el modelo se oculta
func sostener(tipo: String, modelo: Node3D = null) -> void:
	if tipo == "":
		modelo = null
	if modelo == arma and (tipo_arma == tipo or modelo == null):
		return
	if arma:
		arma.visible = false
	arma = modelo
	tipo_arma = tipo if modelo else ""
	if arma:
		if arma.get_parent() == null:
			mano[DER].add_child(arma)
		elif arma.get_parent() != mano[DER]:
			arma.reparent(mano[DER], false)
		arma.transform = REPOSO.get(tipo, Transform3D.IDENTITY)
		arma.visible = true
	t_golpe = INF
	recarga = -1.0


# el tajo del cuchillo (TAJO): la mano derecha atrás arriba, adelante y cruzada abajo
func golpear() -> void:
	t_golpe = 0.0


# el retroceso de un disparo: el cañón sube fuerza rad y el arma vuelve hacia el hombro; se apaga en ~0,1 s
func disparo(fuerza: float) -> void:
	patada = minf(patada + fuerza, 0.4)


# si el cuadro anterior los brazos fueron del arma, animar() y sentar() siguen desde los suyos (libre), no desde la pose
# del arma: la mezcla no se acumula de un cuadro a otro, y al soltar el arma vuelven a donde iban
func soltar_brazos() -> void:
	if armado != Engine.get_process_frames() - 1:
		return
	for i in 2:
		hombro[i].rotation = libre[i][0]
		codo[i].rotation.x = libre[i][1]


# los brazos que sostienen el arma, después de animar(): la mano derecha a la empuñadura y la izquierda al guardamanos (o
# al cargador, recargando), cada una mezclada con la pose de animar() por su peso; el arma en la mano, apuntando a
# objetivo cuando está en alto. En la voltereta los brazos son de animar() y el arma queda como en REPOSO.
func brazos_del_arma(dt: float) -> void:
	var cuadro := Engine.get_process_frames()
	if armado != cuadro - 1:
		pesos = PackedFloat64Array([0.0, 0.0])  # venía sin arma (o de la bicicleta): entra desde la pose libre
	armado = cuadro
	for i in 2:
		libre[i] = [hombro[i].rotation, codo[i].rotation.x]
	var kp := 1.0 - exp(-(30.0 if tipo_arma == "cuchillo" else 16.0) * dt)
	var deseo := [0.0, 0.0]
	var meta := Vector3.INF  # la palma derecha, en el mundo
	var sobre := Transform3D()  # el arma en el mundo, si la mano derecha la sostiene así
	var volteando := salto == 3
	var rec := 0.0  # la mano izquierda en el cargador
	if recarga >= 0.0:
		rec = smoothstep(0.0, 0.25, recarga) * (1.0 - smoothstep(0.75, 1.0, recarga))
	if arma and not volteando:
		match tipo_arma:
			"pistola":
				sobre = en_alto()
				deseo = [maxf(alza, rec), alza]
				meta = sobre.origin
			"rifle":
				sobre = (torso.global_transform * RIFLE_BAJO).interpolate_with(en_alto(), alza)
				sobre = sobre * Transform3D(Basis(Vector3.BACK, 0.5 * rec), Vector3.ZERO)  # ladeado para cambiar el cargador
				deseo = [1.0, 1.0]
				meta = sobre.origin
			"cuchillo":
				if t_golpe < GOLPE:
					deseo[DER] = 1.0
					meta = global_transform * tajo(t_golpe)
	pesos[DER] = lerpf(pesos[DER], deseo[DER], kp)
	if meta != Vector3.INF:
		ik[DER] = alcanzar(DER, meta)
	poner_brazo(DER)
	if arma:
		var rep: Transform3D = REPOSO.get(tipo_arma, Transform3D.IDENTITY)
		if tipo_arma == "cuchillo" or volteando:
			arma.transform = rep
		else:  # entre la mano y donde debe ir: en alto, la palma llega a la empuñadura y el arma queda en `sobre`
			arma.transform = rep.interpolate_with(mano[DER].global_transform.affine_inverse() * sobre, pesos[DER])
	pesos[IZQ] = lerpf(pesos[IZQ], deseo[IZQ], kp)
	if arma and deseo[IZQ] > 0.0:
		var p: Vector3 = (arma.get_node("apoyo") as Node3D).global_position
		if rec > 0.0:
			p = p.lerp((arma.get_node("cargador") as Node3D).global_position, rec)
		ik[IZQ] = alcanzar(IZQ, p)
	poner_brazo(IZQ)


# el brazo i entre la pose de animar() (libre) y la del arma (ik), según su peso
func poner_brazo(i: int) -> void:
	var w := pesos[i]
	if w <= 0.001:
		return
	hombro[i].quaternion = Quaternion(Basis.from_euler(libre[i][0])).slerp(ik[i][0], w)
	codo[i].rotation.x = lerpf(libre[i][1], ik[i][1], w)


# el arma en alto, en el mundo: la boca hacia objetivo (o hacia la mira, sin objetivo o muy cerca); la pistola con los
# brazos estirados bajo los ojos, el rifle con la culata en el hombro derecho; el retroceso sube el cañón y la echa atrás
func en_alto() -> Transform3D:
	var P := global_transform
	var piv: Vector3 = P * PIVOTE
	if tipo_arma == "rifle":
		piv = hombro[DER].global_position + P.basis * RIFLE_HOMBRO
	var dir := P.basis * Vector3(0, sin(mira), -cos(mira))
	if objetivo != Vector3.INF and piv.distance_to(objetivo) > 2.5:
		var d := (objetivo - piv).normalized()
		if absf(d.y) < 0.99:
			dir = d
	var b := Basis.looking_at(dir, Vector3.UP) * Basis(Vector3.RIGHT, patada)
	if tipo_arma == "rifle":
		var culata: Vector3 = (arma.get_node("culata") as Node3D).position
		return Transform3D(b, piv - b * (culata - Vector3(0, 0, 0.12 * patada)))
	return Transform3D(b, piv + b * (PISTOLA_ALTA + Vector3(0, 0, 0.3 * patada)))


# la palma derecha en el tajo, s después del golpe (en el marco del peatón)
func tajo(s: float) -> Vector3:
	for j in TAJO.size() - 1:
		var a: Array = TAJO[j]
		var b: Array = TAJO[j + 1]
		if s <= b[0]:
			var u: float = clampf((s - a[0]) / (b[0] - a[0]), 0.0, 1.0)
			return (a[1] as Vector3).lerp(b[1], smoothstep(0.0, 1.0, u))
	return TAJO[TAJO.size() - 1][1]


# el brazo i para que la palma llegue a p (en el mundo), como dos huesos, con el codo hacia POLO[i]: [la rotación del
# hombro, el ángulo del codo]. El codo, por el teorema del coseno; el hombro, el giro que lleva la palma de la pose del
# brazo colgando con el codo doblado a p, con el codo del lado del polo. Si p queda fuera de alcance, el brazo estirado
# hacia p.
func alcanzar(i: int, p: Vector3) -> Array:
	var t_ := torso.global_transform.affine_inverse() * p - hombro[i].position  # en el marco del torso, desde el hombro
	var d := clampf(t_.length(), 0.08, L_BRAZO + L_ANTEBRAZO - 0.003)
	var c := acos(clampf((d * d - L_BRAZO * L_BRAZO - L_ANTEBRAZO * L_ANTEBRAZO) / (2.0 * L_BRAZO * L_ANTEBRAZO), -1.0, 1.0))
	var h := Vector3(0, -L_BRAZO - L_ANTEBRAZO * cos(c), -L_ANTEBRAZO * sin(c))  # la palma con el brazo colgando y el codo doblado c
	var a := marco(h, Vector3(0, -L_BRAZO, 0))
	var b := marco(t_, POLO[i])
	return [Quaternion(b * a.transposed()), c]


# una base ortonormal con x en la dirección de x y y hacia `hacia` (lo de `hacia` perpendicular a x)
static func marco(x: Vector3, hacia: Vector3) -> Basis:
	var e1 := x.normalized()
	var e2 := (hacia - e1 * hacia.dot(e1)).normalized()
	return Basis(e1, e2, e1.cross(e2))
