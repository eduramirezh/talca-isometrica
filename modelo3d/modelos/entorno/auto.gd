# Los autos del juego, en un solo lugar: los estacionados de calles.gd (alrededor de la plaza, uno por uno en su
# malla) y los de toda la comuna de autos.gd (los de la página, en un MultiMesh por tipo). Hasta noviembre de 2026
# eran auto() de calles.gd.
#
# Un auto se escribe en un marco (Malla.Marco) con v hacia adelante, u al costado y h desde el suelo (las ruedas lo
# tocan en h = 0). Desde noviembre de 2026 la carrocería es un barrido de secciones a lo largo de v (PERFILES): en cada
# estación, el piso (que sube en los tapabarros: arcos de verdad, con su techo oscuro), la línea de cintura, el
# hombro y el techo, y el ancho, que se angosta en las puntas (las esquinas redondeadas en planta) y hacia el techo
# (la cabina más angosta que la carrocería). Entre dos estaciones, cada franja es pintura o vidrio según dónde cae:
# el parabrisas y la luneta arriba, las ventanas al costado, con los pilares A (el riel del techo que baja por el
# borde del parabrisas), B y C pintados. Encima, en las tapas de adelante y de atrás: focos, parrilla, toma de aire,
# luces traseras y la patente chilena (blanca, letras negras, 36 × 13 cm), y al costado las líneas de las puertas y
# los espejos. Las medidas son las de antes (CUERPOS, ANCHO, RUEDA_*: las de la página y de la colisión); las formas,
# de autos comunes en Chile en 2015–2025, a ojo: el sedán como un Chevrolet Sail o un Nissan Versa, el hatchback un
# Suzuki Swift o un Kia Morning, el SUV un Hyundai Tucson, la camioneta una doble cabina (Hilux, L200) con la caja
# abierta, el furgón un Hyundai H-1 con ventanas hasta atrás, y el camión de reparto (un Mercedes Atego o un Hyundai
# HD) con cabina chata, deflector y furgón de carga. El colectivo es el sedán negro con el letrero amarillo atravesado
# en el techo, con su número en negro adelante y atrás.
#
#   const Auto := preload("res://modelos/entorno/auto.gd")
#   Auto.modelo(m, marco, Auto.SEDAN, Color(0.6, 0.08, 0.07), choques)   # choques: una Malla para la caja de colisión
#   Auto.modelo(m, marco, Auto.SUV, Auto.PINTURA)   # la carrocería en alfa 0: en un MultiMesh con Mat.tinte, el color
#                                                   # de cada instancia (autos.gd); es lo único en alfa 0
#   Auto.caja(Auto.SUV)                             # [medio ancho, v de atrás, v de adelante, alto]: la de colisión
#   Auto.modelo(m, marco, Auto.SEDAN, col, null, false)   # sin neumáticos ni llantas: el auto de vehiculo.gd, que pone
#                                                   # sus ruedas aparte para que giren
extends RefCounted

const Malla := preload("res://malla.gd")

const SEDAN := 0
const HATCHBACK := 1
const SUV := 2
const CAMIONETA := 3
const COLECTIVO := 4
const FURGON := 5
const CAMION := 6
const TIPOS := 7

# los colores de calles.gd (los más comunes en Chile: blanco, gris, plata, negro, rojo, azul)
const COLORES := [Color(0.92, 0.92, 0.9), Color(0.92, 0.92, 0.9), Color(0.62, 0.64, 0.66), Color(0.75, 0.76, 0.77),
	Color(0.1, 0.1, 0.11), Color(0.35, 0.36, 0.38), Color(0.6, 0.08, 0.07), Color(0.12, 0.2, 0.42), Color(0.45, 0.06, 0.08)]
const NEGRO_COLECTIVO := Color(0.07, 0.07, 0.08)
const PINTURA := Color(1, 1, 1, 0)  # la carrocería de una malla para MultiMesh: el color lo pone la instancia
const VIDRIO := Color(0.13, 0.16, 0.19)
const GRIS := Color(0.18, 0.18, 0.19)
const OSCURO := Color(0.07, 0.07, 0.075)  # el techo de los tapabarros, la parrilla, las líneas de las puertas
const FOCO := Color(0.95, 0.95, 0.88)
const ROJO := Color(0.72, 0.07, 0.05)
const PATENTE := Color(0.94, 0.94, 0.91)
const AMARILLO := Color(0.95, 0.8, 0.15)

# las medidas de cada tipo (la caja de colisión, caja(), y el piso de vehiculo.gd salen de aquí): la carrocería hasta la
# línea de cintura (v hacia adelante, h; el primer punto es el de atrás abajo, el segundo el de adelante abajo) y la
# cabina encima (el cuarto punto, el techo adelante); v = 0 al medio del auto. El dibujo es el de PERFILES.
const CUERPOS := [
	[[[-2.25, 0.32], [2.25, 0.32], [2.32, 0.58], [2.1, 0.8], [1.0, 0.9], [-1.65, 0.93], [-2.22, 0.86]], [[1.0, 0.9], [-1.65, 0.93], [-0.95, 1.42], [0.3, 1.44]]],
	[[[-1.95, 0.32], [1.95, 0.32], [2.02, 0.58], [1.82, 0.82], [0.85, 0.93], [-1.92, 0.95], [-2.0, 0.6]], [[0.85, 0.93], [-1.92, 0.95], [-1.82, 1.45], [0.2, 1.47]]],
	[[[-2.2, 0.4], [2.2, 0.4], [2.27, 0.72], [2.05, 0.98], [1.0, 1.05], [-2.15, 1.08], [-2.25, 0.75]], [[1.0, 1.05], [-2.15, 1.08], [-2.05, 1.7], [0.45, 1.72]]],
	[[[-2.6, 0.45], [2.6, 0.45], [2.67, 0.8], [2.42, 1.05], [1.35, 1.1], [-0.4, 1.12], [-0.4, 1.12], [-2.6, 1.12]], [[1.35, 1.1], [-0.4, 1.12], [-0.3, 1.78], [0.85, 1.8]]],
	[[[-2.25, 0.32], [2.25, 0.32], [2.32, 0.58], [2.1, 0.8], [1.0, 0.9], [-1.65, 0.93], [-2.22, 0.86]], [[1.0, 0.9], [-1.65, 0.93], [-0.95, 1.42], [0.3, 1.44]]],
	# el furgón: 4,9 m, la cabina alta hasta atrás (en la página, 1,3 veces el alto de un auto)
	[[[-2.45, 0.36], [2.45, 0.36], [2.52, 0.68], [2.3, 0.98], [1.45, 1.06], [-2.45, 1.08]], [[1.45, 1.06], [-2.45, 1.08], [-2.45, 2.02], [0.8, 2.04]]]]
const ANCHO := [0.86, 0.85, 0.92, 0.93, 0.86, 0.95]  # medio ancho de la carrocería
const RUEDA_V := [1.4, 1.25, 1.4, 1.75, 1.4, 1.6]  # el eje, desde el medio
const RUEDA_R := [0.31, 0.31, 0.36, 0.38, 0.31, 0.33]
const CAMION_L := 11.5  # m: el camión de modelo (autos.gd lo estira al largo de la página, 10,8–12,6 m)

# el barrido de cada tipo (el colectivo usa el del sedán), con los mismos largos y altos que CUERPOS. Listas de [v, h]
# (o [v, fracción del medio ancho]) que se interpolan entre puntos:
#   techo: lo más alto de cada sección (la tapa del maletero, la luneta, el techo, el parabrisas, el capó, la trompa)
#   cintura: el borde de abajo de las ventanas (en el capó y el maletero, 4 cm bajo el techo: el hombro redondeado)
#   piso: el borde de abajo de la carrocería fuera de los tapabarros
#   ancho: el medio ancho, en fracción de ANCHO (menos de 1 en las esquinas)
#   k: el ancho del techo de la cabina, en fracción del de la carrocería; riel: el ancho del riel del techo (el pilar A)
#   frente, atras: [v0, v1] del parabrisas y de la luneta; lado: [v0, v1] de las ventanas laterales, salvo pilares
#   puertas: v de las líneas de las puertas; caja: [v0, v1] de la caja abierta de la camioneta (piso a h_caja)
const PERFILES := [
	{  # sedán (Chevrolet Sail, Nissan Versa, Hyundai Accent): maletero corto, luneta tendida
		"techo": [[-2.25, 0.8], [-2.14, 0.89], [-1.6, 0.93], [-0.92, 1.41], [0.3, 1.44], [1.03, 0.93], [1.95, 0.8], [2.25, 0.7]],
		"cintura": [[-2.25, 0.74], [-2.14, 0.85], [-1.6, 0.89], [1.03, 0.86], [1.95, 0.76], [2.25, 0.66]],
		"piso": [[-2.25, 0.42], [-2.14, 0.3], [1.95, 0.3], [2.25, 0.36]],
		"ancho": [[-2.25, 0.9], [-2.14, 1.0], [1.95, 1.0], [2.25, 0.86]],
		"k": 0.8, "riel": 0.09, "frente": [0.3, 1.03], "atras": [-1.6, -0.92], "lado": [-1.3, 1.03],
		"pilares": [[-0.3, -0.17]], "puertas": [0.97, -0.24, -1.27]},
	{  # hatchback (Suzuki Swift, Kia Morning): el portalón casi vertical
		"techo": [[-1.95, 0.95], [-1.82, 1.4], [-1.7, 1.47], [0.2, 1.47], [0.88, 0.95], [1.72, 0.84], [1.95, 0.72]],
		"cintura": [[-1.95, 0.91], [-1.62, 0.93], [0.88, 0.91], [1.72, 0.8], [1.95, 0.68]],
		"piso": [[-1.95, 0.4], [-1.82, 0.3], [1.72, 0.3], [1.95, 0.36]],
		"ancho": [[-1.95, 0.92], [-1.82, 1.0], [1.72, 1.0], [1.95, 0.86]],
		"k": 0.8, "riel": 0.09, "frente": [0.2, 0.88], "atras": [-1.95, -1.82], "lado": [-1.45, 0.88],
		"pilares": [[-0.38, -0.26]], "puertas": [0.82, -0.32, -1.18]},
	{  # SUV (Hyundai Tucson, Chevrolet Groove): alto, portalón vertical y ventana del maletero tras el pilar C
		"techo": [[-2.2, 1.12], [-2.12, 1.62], [-1.95, 1.7], [0.45, 1.72], [0.98, 1.1], [1.95, 1.0], [2.2, 0.9]],
		"cintura": [[-2.2, 1.06], [-1.95, 1.09], [0.98, 1.05], [1.95, 0.96], [2.2, 0.86]],
		"piso": [[-2.2, 0.52], [-2.12, 0.4], [1.95, 0.4], [2.2, 0.46]],
		"ancho": [[-2.2, 0.92], [-2.12, 1.0], [1.95, 1.0], [2.2, 0.88]],
		"k": 0.84, "riel": 0.09, "frente": [0.45, 0.98], "atras": [-2.2, -2.12], "lado": [-1.82, 0.98],
		"pilares": [[-0.36, -0.23], [-1.36, -1.17]], "puertas": [0.95, -0.3, -1.29]},
	{  # camioneta doble cabina (Toyota Hilux, Mitsubishi L200): la caja abierta detrás de la cabina
		"techo": [[-2.6, 1.14], [-2.53, 1.14], [-0.47, 1.14], [-0.42, 1.74], [-0.3, 1.78], [0.85, 1.8], [1.31, 1.14], [2.35, 1.08], [2.6, 0.96]],
		"cintura": [[-2.6, 1.1], [-0.42, 1.1], [1.31, 1.1], [2.35, 1.04], [2.6, 0.92]],
		"piso": [[-2.6, 0.55], [-2.53, 0.45], [2.35, 0.45], [2.6, 0.52]],
		"ancho": [[-2.6, 0.98], [-2.53, 1.0], [2.35, 1.0], [2.6, 0.88]],
		"k": 0.84, "riel": 0.09, "frente": [0.85, 1.31], "atras": [-0.47, -0.42], "lado": [-0.42, 1.31],
		"pilares": [[0.38, 0.5]], "puertas": [1.28, 0.44, -0.38], "caja": [-2.53, -0.47], "h_caja": 0.78},
	{},  # el colectivo: el del sedán
	{  # furgón (Hyundai H-1): trompa corta, ventanas hasta atrás, puerta corredera
		"techo": [[-2.45, 1.99], [-2.4, 2.04], [0.8, 2.04], [1.39, 1.1], [2.3, 0.98], [2.45, 0.86]],
		"cintura": [[-2.45, 1.04], [1.39, 1.06], [2.3, 0.94], [2.45, 0.82]],
		"piso": [[-2.45, 0.44], [-2.4, 0.34], [2.3, 0.34], [2.45, 0.4]],
		"ancho": [[-2.45, 0.96], [-2.4, 1.0], [2.3, 1.0], [2.45, 0.88]],
		"k": 0.92, "riel": 0.07, "frente": [0.8, 1.39], "atras": [], "lado": [-2.4, 1.39],
		"pilares": [[0.44, 0.57], [-0.78, -0.68]], "puertas": [1.36, 0.5, -0.66]}]


static func caja(tipo: int) -> Array:
	if tipo == CAMION:
		return [1.25, -CAMION_L / 2.0, CAMION_L / 2.0, 3.6]
	var c: Array = CUERPOS[tipo]
	return [ANCHO[tipo], c[0][0][0], c[0][1][0], c[1][3][1]]


static func modelo(m: Malla, f: Malla.Marco, tipo: int, col: Color, choques: Malla = null, llantas := true) -> void:
	if tipo == CAMION:
		camion(m, f, col, choques)
		return
	var ancho: float = ANCHO[tipo]
	var cuerpos: Array = CUERPOS[tipo]
	if choques:
		choques.caja(f, -ancho, cuerpos[0][0][0], ancho, cuerpos[0][1][0], 0.2, cuerpos[1][3][1], col)
	var p: Dictionary = _perfil(tipo)
	var est := _estaciones(tipo)
	_carroceria(m, f, p, est, col)
	_tapas(m, f, est, col, tipo)
	_costados(m, f, p, tipo, col)
	if tipo == COLECTIVO:
		# el letrero de techo de los colectivos de Talca: una placa amarilla atravesada sobre el techo, con el número
		# de la línea en negro adelante y atrás
		var hr: float = _f(p["techo"], -0.15) - 0.005
		m.caja(f, -0.42, -0.21, 0.42, -0.09, hr, hr + 0.24, AMARILLO, "pintura")
		for sv: float in [-1.0, 1.0]:
			var vv: float = -0.15 + sv * 0.065
			m.cara([f.V(-0.13, vv, hr + 0.05), f.V(0.13, vv, hr + 0.05), f.V(0.13, vv, hr + 0.19), f.V(-0.13, vv, hr + 0.19)],
				OSCURO, "pintura", f.N(0, sv))
	if llantas:
		_neumaticos(m, f, ancho, [-RUEDA_V[tipo], RUEDA_V[tipo]], RUEDA_R[tipo])


# ---------------------------------------------------------------- el barrido

static func _perfil(tipo: int) -> Dictionary:
	return PERFILES[SEDAN if tipo == COLECTIVO else tipo]


# la lista l de [x, y] interpolada en x (constante fuera de sus extremos)
static func _f(l: Array, x: float) -> float:
	if x <= l[0][0]:
		return l[0][1]
	for i in range(1, l.size()):
		if x <= l[i][0]:
			var t: float = (x - l[i - 1][0]) / max(l[i][0] - l[i - 1][0], 1e-6)
			return lerp(float(l[i - 1][1]), float(l[i][1]), t)
	return l[l.size() - 1][1]


static func _en(r: Array, x: float) -> bool:
	return r.size() == 2 and x > r[0] and x < r[1]


# las estaciones del barrido: cada punto de quiebre de PERFILES y cuatro por tapabarro
static func _estaciones(tipo: int) -> Array:
	var p := _perfil(tipo)
	var r: float = RUEDA_R[tipo]
	var vr: float = RUEDA_V[tipo]
	var vs := []
	for clave in ["techo", "cintura", "piso", "ancho"]:
		for q in p[clave]:
			vs.append(float(q[0]))
	for clave in ["frente", "atras", "lado", "caja"]:
		for x in p.get(clave, []):
			vs.append(float(x))
	for q in p["pilares"]:
		vs.append(float(q[0]))
		vs.append(float(q[1]))
	for cv in [-vr, vr]:
		for k in [-1.0, -0.55, 0.55, 1.0]:
			vs.append(cv + k * (r + 0.06))
	vs.sort()
	var v0: float = p["techo"][0][0]
	var v1: float = p["techo"][p["techo"].size() - 1][0]
	var est := []
	for v: float in vs:
		if v < v0 - 0.001 or v > v1 + 0.001:
			continue
		# los puntos a menos de 4,5 cm de la estación anterior no hacen otra (cada una son 14 triángulos)
		if not est.is_empty() and v - est[est.size() - 1][0] < 0.045:
			continue
		est.append(_seccion(p, tipo, v))
	return est


# la sección en v: [v, piso, cintura, techo, ancho de la carrocería, ancho del techo, riel]
static func _seccion(p: Dictionary, tipo: int, v: float) -> Array:
	var w: float = ANCHO[tipo]
	var r: float = RUEDA_R[tipo]
	var hb := _f(p["piso"], v)
	# el tapabarro: un arco de cuatro tramos (los costados inclinados y el techo plano) 6 cm sobre el neumático
	var ra := r + 0.06
	for cv in [-RUEDA_V[tipo], RUEDA_V[tipo]]:
		var d: float = abs(v - cv)
		if d < ra:
			var tope := r + ra * 0.9
			hb = max(hb, tope if d <= 0.55 * ra else lerp(tope, hb, (d - 0.55 * ra) / (0.45 * ra)))
	var hc := _f(p["cintura"], v)
	var ht := _f(p["techo"], v)
	var wb := w * _f(p["ancho"], v)
	# en el capó y el maletero el hombro baja 6 cm hacia adentro; en la cabina, el techo es k del ancho
	var t: float = clamp((ht - hc - 0.06) / 0.3, 0.0, 1.0)
	# el riel solo en la cabina: en el capó y el maletero su franja se anula (y no dibuja)
	return [v, hb, hc, ht, wb, lerp(wb - 0.06, wb * p["k"], t), p["riel"] * t]


# los puntos (u, h) del lado derecho de una sección: el piso, la cintura, el hombro y el borde del riel
static func _pts(e: Array) -> Array:
	return [Vector2(e[4] - 0.03, e[1]), Vector2(e[4], e[2]), Vector2(e[5], e[3]), Vector2(e[5] - e[6], e[3] + e[6] / 9.0)]


# una cara de puntos locales (u, v, h), con su normal hacia afuera de c (el centro del barrido en esa franja)
static func _cara(m: Malla, f: Malla.Marco, q: Array, col: Color, mat: String, c: Vector3) -> void:
	# sin los puntos repetidos: una franja que se anula en una punta es un triángulo, y en las dos, nada
	var d := []
	for x: Vector3 in q:
		if d.is_empty() or x.distance_squared_to(d[d.size() - 1]) > 1e-8:
			d.append(x)
	if d.size() > 1 and d[0].distance_squared_to(d[d.size() - 1]) < 1e-8:
		d.pop_back()
	if d.size() < 3:
		return
	q = d
	var n := Vector3.ZERO
	var g := Vector3.ZERO
	for i in q.size():
		var a: Vector3 = q[i]
		var b: Vector3 = q[(i + 1) % q.size()]
		n += Vector3((a.y - b.y) * (a.z + b.z), (a.z - b.z) * (a.x + b.x), (a.x - b.x) * (a.y + b.y))
		g += a / q.size()
	if n.length_squared() < 1e-10:
		return
	if n.dot(g - c) < 0:
		n = -n
	var w := []
	for a: Vector3 in q:
		w.append(f.V(a.x, a.y, a.z))
	m.cara(w, col, mat, f.N(n.x, n.y, n.z))


static func _carroceria(m: Malla, f: Malla.Marco, p: Dictionary, est: Array, col: Color) -> void:
	var hcaja: float = p.get("h_caja", 0.0)
	for i in est.size() - 1:
		var a: Array = est[i]
		var b: Array = est[i + 1]
		var va: float = a[0]
		var vb: float = b[0]
		var vm := (va + vb) / 2.0
		var pa := _pts(a)
		var pb := _pts(b)
		var pilar := false
		for q in p["pilares"]:
			pilar = pilar or _en(q, vm)
		var alto: float = (a[3] - a[2] + b[3] - b[2]) / 2.0
		var vlado := _en(p["lado"], vm) and not pilar and alto > 0.12
		var varriba := _en(p["frente"], vm) or _en(p["atras"], vm)
		var abierta := _en(p.get("caja", []), vm)
		var c := Vector3(0, vm, (a[1] + a[2] + b[1] + b[2]) / 4.0)
		for s: float in [-1.0, 1.0]:
			for k in 3:
				var vid := k == 1 and vlado
				_cara(m, f, [Vector3(s * pa[k].x, va, pa[k].y), Vector3(s * pb[k].x, vb, pb[k].y),
					Vector3(s * pb[k + 1].x, vb, pb[k + 1].y), Vector3(s * pa[k + 1].x, va, pa[k + 1].y)],
					VIDRIO if vid else col, "vidrio" if vid else "pintura", c)
		if abierta:
			# la caja de la camioneta: el piso y los costados por dentro, en plástico negro
			var ua: float = pa[3].x
			var ub: float = pb[3].x
			_cara(m, f, [Vector3(-ua, va, hcaja), Vector3(ua, va, hcaja), Vector3(ub, vb, hcaja), Vector3(-ub, vb, hcaja)],
				GRIS, "pintura", Vector3(0, vm, -1))
			for s: float in [-1.0, 1.0]:
				_cara(m, f, [Vector3(s * ua, va, hcaja), Vector3(s * ub, vb, hcaja), Vector3(s * pb[3].x, vb, pb[3].y),
					Vector3(s * pa[3].x, va, pa[3].y)], GRIS, "pintura", Vector3(s * 3.0, vm, 0.9))
		else:
			_cara(m, f, [Vector3(-pa[3].x, va, pa[3].y), Vector3(pa[3].x, va, pa[3].y), Vector3(pb[3].x, vb, pb[3].y),
				Vector3(-pb[3].x, vb, pb[3].y)], VIDRIO if varriba else col, "vidrio" if varriba else "pintura", c)
		# el techo de los tapabarros, oscuro: mirando hacia el neumático se ve el arco y no el cielo
		if a[1] + b[1] > _f(p["piso"], va) + _f(p["piso"], vb) + 0.04:
			_cara(m, f, [Vector3(-pa[0].x, va, pa[0].y), Vector3(pa[0].x, va, pa[0].y), Vector3(pb[0].x, vb, pb[0].y),
				Vector3(-pb[0].x, vb, pb[0].y)], OSCURO, "pintura", Vector3(0, vm, 3.0))
	if hcaja > 0:
		# la caja: la pared de adelante (la espalda de la cabina) y el portalón por dentro
		var ca: Array = p["caja"]
		for j in 2:
			var v: float = ca[j]
			var e := _seccion(p, CAMIONETA, v)
			var u: float = _pts(e)[3].x
			_cara(m, f, [Vector3(-u, v, hcaja), Vector3(u, v, hcaja), Vector3(u, v, e[3]), Vector3(-u, v, e[3])], GRIS, "pintura",
				Vector3(0, v + (-1.0 if j == 0 else 1.0), e[3] / 2.0))


# las tapas de adelante y de atrás (la sección de la punta) y lo que llevan: focos, parrilla, patente, luces
static func _tapas(m: Malla, f: Malla.Marco, est: Array, col: Color, tipo: int) -> void:
	for j in 2:
		var e: Array = est[0] if j == 0 else est[est.size() - 1]
		var sv := -1.0 if j == 0 else 1.0
		var v: float = e[0]
		var pt := _pts(e)
		var poli := PackedVector2Array()
		for k in 4:
			poli.append(pt[k])
		for k in range(3, -1, -1):
			poli.append(Vector2(-pt[k].x, pt[k].y))
		var idx := Geometry2D.triangulate_polygon(poli)
		for t in range(0, idx.size(), 3):
			m.cara([f.V(poli[idx[t]].x, v, poli[idx[t]].y), f.V(poli[idx[t + 1]].x, v, poli[idx[t + 1]].y),
				f.V(poli[idx[t + 2]].x, v, poli[idx[t + 2]].y)], col, "pintura", f.N(0, sv))
		var hb: float = e[1]
		var hc: float = e[2]
		var ht: float = e[3]
		var wb: float = e[4]
		var vv: float = v + sv * 0.006
		var alto := hc - hb
		if j == 1:
			# focos en las esquinas de arriba, la parrilla entre ellos y la toma de aire abajo (si cabe)
			for s: float in [-1.0, 1.0]:
				_rect(m, f, vv, s * (wb - 0.05), s * (wb - 0.33), hc - 0.12, hc - 0.02, FOCO, "pintura", sv)
			var hg: float = max(hb + 0.21, hc - 0.13)
			_rect(m, f, vv, -(wb - 0.37), wb - 0.37, hg, hc - 0.03, OSCURO, "pintura", sv)
			if alto > 0.42:
				_rect(m, f, vv, -(wb - 0.22), wb - 0.22, hb + 0.03, hb + 0.08, OSCURO, "pintura", sv)
			_patente(m, f, vv, hb + 0.06 + (0.05 if alto > 0.42 else 0.0), sv)
		else:
			var vert := tipo in [SUV, CAMIONETA, FURGON]
			for s: float in [-1.0, 1.0]:
				if vert:
					# las luces traseras verticales de los SUV, las camionetas y los furgones
					_rect(m, f, vv, s * (wb - 0.03), s * (wb - 0.17), hc - 0.42, hc - 0.02, ROJO, "pintura", sv)
				else:
					_rect(m, f, vv, s * (wb - 0.04), s * (wb - 0.31), hc - 0.15, hc - 0.03, ROJO, "pintura", sv)
			_patente(m, f, vv, hb + 0.1, sv)
			# la luneta del furgón, en la puerta de atrás
			if ht - hc > 0.4:
				_rect(m, f, vv, -(e[5] - 0.1), e[5] - 0.1, hc + 0.08, ht - 0.12, VIDRIO, "vidrio", sv)


# un rectángulo en el plano v = constante, de u0 a u1 y de h0 a h1, mirando hacia sv
static func _rect(m: Malla, f: Malla.Marco, v: float, u0: float, u1: float, h0: float, h1: float, col: Color, mat: String,
		sv: float) -> void:
	m.cara([f.V(u0, v, h0), f.V(u1, v, h0), f.V(u1, v, h1), f.V(u0, v, h1)], col, mat, f.N(0, sv))


# la patente chilena: blanca, de 36 × 13 cm, con una franja negra por las letras
static func _patente(m: Malla, f: Malla.Marco, v: float, h0: float, sv: float) -> void:
	_rect(m, f, v, -0.18, 0.18, h0, h0 + 0.13, PATENTE, "pintura", sv)
	_rect(m, f, v + sv * 0.003, -0.14, 0.14, h0 + 0.035, h0 + 0.09, OSCURO, "pintura", sv)


# las líneas de las puertas y los espejos
static func _costados(m: Malla, f: Malla.Marco, p: Dictionary, tipo: int, col: Color) -> void:
	for v: float in p["puertas"]:
		var e := _seccion(p, tipo, v)
		var pt := _pts(e)
		for s: float in [-1.0, 1.0]:
			var u0: float = s * (pt[0].x + 0.012)
			var u1: float = s * (pt[1].x + 0.006)
			m.cara([f.V(u0, v - 0.01, e[1] + 0.03), f.V(u0, v + 0.01, e[1] + 0.03), f.V(u1, v + 0.01, e[2] - 0.015),
				f.V(u1, v - 0.01, e[2] - 0.015)], OSCURO, "pintura", f.N(s, 0))
	# los espejos: una caja del color del auto en la punta de adelante de las ventanas, con el vidrio atrás
	var ve: float = p["lado"][1] - 0.14
	var es := _seccion(p, tipo, ve)
	var w: float = es[4]
	var h0: float = es[2] + 0.02
	for s: float in [-1.0, 1.0]:
		var ua: float = s * (w - 0.02)
		var ub: float = s * (w + 0.17)
		# afuera, adelante, arriba y el vidrio atrás (el lado de la puerta y abajo no se ven)
		var q := [Vector3(ua, ve - 0.06, h0), Vector3(ub, ve - 0.06, h0), Vector3(ub, ve + 0.04, h0), Vector3(ua, ve + 0.04, h0)]
		var c := Vector3(s * (w + 0.07), ve - 0.01, h0 + 0.06)
		_cara(m, f, [q[1], q[2], q[2] + Vector3(0, 0, 0.12), q[1] + Vector3(0, 0, 0.12)], col, "pintura", c)
		_cara(m, f, [q[2], q[3], q[3] + Vector3(0, 0, 0.12), q[2] + Vector3(0, 0, 0.12)], col, "pintura", c)
		_cara(m, f, [q[0] + Vector3(0, 0, 0.12), q[1] + Vector3(0, 0, 0.12), q[2] + Vector3(0, 0, 0.12), q[3] + Vector3(0, 0, 0.12)], col,
			"pintura", c)
		_cara(m, f, [q[0], q[1], q[1] + Vector3(0, 0, 0.12), q[0] + Vector3(0, 0, 0.12)], VIDRIO, "vidrio", c)


# los neumáticos de un auto (los tapabarros son de la carrocería): diez caras de banda, el flanco negro y la llanta
static func _neumaticos(m: Malla, f: Malla.Marco, ancho: float, ejes: Array, r: float) -> void:
	for cv: float in ejes:
		for su: float in [-1.0, 1.0]:
			_neumatico(m, f, su * (ancho - 0.21), su * (ancho - 0.01), cv, r, su)


# un neumático de u0 a u1 (u1 afuera, del lado su) en el eje cv, de radio r: la banda, el flanco y la llanta
static func _neumatico(m: Malla, f: Malla.Marco, u0: float, u1: float, cv: float, r: float, su: float) -> void:
	var c := Malla.ngon(cv, r, r, 10, PI / 10)
	var flanco := []
	for i in 10:
		var a := c[i]
		var b := c[(i + 1) % 10]
		var n := ((a + b) / 2 - Vector2(cv, r)).normalized()
		m.cara([f.V(u0, a.x, a.y), f.V(u1, a.x, a.y), f.V(u1, b.x, b.y), f.V(u0, b.x, b.y)], Color(0.07, 0.07, 0.07), "pintura",
			f.N(0, n.x, n.y))
		flanco.append(f.V(u1, a.x, a.y))
	m.cara(flanco, Color(0.09, 0.09, 0.09), "pintura", f.N(su, 0))
	var q := []
	for a in Malla.ngon(cv, r, r * 0.6, 8, PI / 8):
		q.append(f.V(u1 + su * 0.006, a.x, a.y))
	m.cara(q, Color(0.55, 0.56, 0.58), "metal", f.N(su, 0))


# las ruedas (con llanta y tapabarro) en cada eje v de ejes, a los dos lados de una carrocería de medio ancho ancho
# (llantas falso: solo los tapabarros). Las del camión; los autos tienen sus tapabarros en la carrocería.
static func ruedas(m: Malla, f: Malla.Marco, ancho: float, ejes: Array, r: float, llantas := true) -> void:
	for cv: float in ejes:
		for su: float in [-1.0, 1.0]:
			if llantas:
				_neumatico(m, f, su * (ancho - 0.22), su * (ancho + 0.01), cv, r, su)
			tapabarro(m, f, ancho, cv, r, su)


# el tapabarro: un arco oscuro sobre la rueda del eje cv, al lado su
static func tapabarro(m: Malla, f: Malla.Marco, ancho: float, cv: float, r: float, su: float) -> void:
	var q2 := []
	for k in 7:
		var t := PI * k / 6.0
		q2.append(Vector2(cv + cos(t) * (r + 0.06), r + sin(t) * (r + 0.06)))
	for k in 6:
		m.cara([f.V(su * (ancho + 0.004), q2[k].x, q2[k].y), f.V(su * (ancho + 0.004), q2[k + 1].x, q2[k + 1].y),
			f.V(su * (ancho + 0.004), cv + (q2[k + 1].x - cv) * 0.85, r + (q2[k + 1].y - r) * 0.85),
			f.V(su * (ancho + 0.004), cv + (q2[k].x - cv) * 0.85, r + (q2[k].y - r) * 0.85)], Color(0.1, 0.1, 0.1), "pintura", f.N(su, 0))


# un camión de reparto de 11,5 m (los de la Ruta 5 de la página: un quinto de sus autos, en la pista de la derecha):
# el chasis, la cabina chata blanca (parrilla, focos, parabrisas inclinado, ventanas, espejos en sus brazos, el
# deflector sobre el techo), el estanque de combustible, las barras laterales, y el furgón de carga del color de la
# instancia, con sus puertas atrás; seis ruedas por lado (dobles atrás)
static func camion(m: Malla, f: Malla.Marco, col: Color, choques: Malla = null) -> void:
	var L := CAMION_L / 2.0
	var a := 1.25
	if choques:
		choques.caja(f, -a, -L, a, L, 0.2, 3.6, col)
	var gris := Color(0.22, 0.22, 0.23)
	var cab := Color(0.88, 0.88, 0.86)  # las cabinas, casi siempre blancas
	m.caja(f, -1.0, -L + 0.2, 1.0, L - 0.3, 0.55, 0.95, gris, "metal")  # el chasis
	# la cabina, de perfil: la trompa vertical, un chaflán, el parabrisas inclinado y el techo; extruida a lo ancho
	var vc := L - 2.3
	var w := 1.2
	var perfil := [Vector2(vc, 0.95), Vector2(L, 0.95), Vector2(L, 1.62), Vector2(L - 0.1, 1.72), Vector2(L - 0.4, 2.9),
		Vector2(L - 0.58, 3.05), Vector2(vc, 3.05)]
	var poli := PackedVector2Array(perfil)
	var idx := Geometry2D.triangulate_polygon(poli)
	for s: float in [-1.0, 1.0]:
		for t in range(0, idx.size(), 3):
			m.cara([f.V(s * w, poli[idx[t]].x, poli[idx[t]].y), f.V(s * w, poli[idx[t + 1]].x, poli[idx[t + 1]].y),
				f.V(s * w, poli[idx[t + 2]].x, poli[idx[t + 2]].y)], cab, "pintura", f.N(s, 0))
	for i in perfil.size():
		var p0: Vector2 = perfil[i]
		var p1: Vector2 = perfil[(i + 1) % perfil.size()]
		var e := p1 - p0
		var n := Vector2(e.y, -e.x).normalized()
		var vid := i == 3
		m.cara([f.V(-w, p0.x, p0.y), f.V(w, p0.x, p0.y), f.V(w, p1.x, p1.y), f.V(-w, p1.x, p1.y)], VIDRIO if vid else cab,
			"vidrio" if vid else "pintura", f.N(0, n.x, n.y))
	# el deflector sobre el techo, hasta el alto del furgón
	var defl := [Vector2(vc + 0.05, 3.05), Vector2(L - 0.75, 3.05), Vector2(vc + 0.05, 3.52)]
	for s: float in [-1.0, 1.0]:
		m.cara([f.V(s * 1.1, defl[0].x, defl[0].y), f.V(s * 1.1, defl[1].x, defl[1].y), f.V(s * 1.1, defl[2].x, defl[2].y)], cab,
			"pintura", f.N(s, 0))
	var dn := Vector2(defl[2].y - defl[1].y, -(defl[2].x - defl[1].x)).normalized()
	m.cara([f.V(-1.1, defl[1].x, defl[1].y), f.V(1.1, defl[1].x, defl[1].y), f.V(1.1, defl[2].x, defl[2].y),
		f.V(-1.1, defl[2].x, defl[2].y)], cab, "pintura", f.N(0, dn.x, dn.y))
	# la trompa: parrilla, focos, parachoques y patente
	var vf := L + 0.006
	_rect(m, f, vf, -0.62, 0.62, 1.2, 1.56, OSCURO, "pintura", 1.0)
	for s: float in [-1.0, 1.0]:
		_rect(m, f, vf, s * 0.75, s * 1.12, 1.18, 1.38, FOCO, "pintura", 1.0)
	m.caja(f, -1.25, L - 0.1, 1.25, L + 0.08, 0.6, 0.98, GRIS, "pintura")
	_patente(m, f, L + 0.086, 0.7, 1.0)
	for s: float in [-1.0, 1.0]:
		var us := s * (w + 0.005)
		# la ventana de la puerta y la línea de la puerta
		m.cara([f.V(us, vc + 0.95, 1.95), f.V(us, L - 0.62, 1.95), f.V(us, L - 0.48, 2.78), f.V(us, vc + 0.95, 2.78)], VIDRIO,
			"vidrio", f.N(s, 0))
		m.cara([f.V(us, vc + 0.85, 1.0), f.V(us, vc + 0.88, 1.0), f.V(us, vc + 0.88, 2.9), f.V(us, vc + 0.85, 2.9)], OSCURO,
			"pintura", f.N(s, 0))
		# los espejos: un brazo y el espejo alto, negros
		m.caja(f, min(s * w, s * (w + 0.28)), L - 0.5, max(s * w, s * (w + 0.28)), L - 0.46, 2.55, 2.6, OSCURO, "pintura")
		m.caja(f, min(s * (w + 0.22), s * (w + 0.32)), L - 0.52, max(s * (w + 0.22), s * (w + 0.32)), L - 0.44, 2.05, 2.62,
			OSCURO, "pintura")
		# las barras laterales entre los ejes, a la altura de la rueda
		m.cara([f.V(s * 1.15, -L + 2.5, 0.5), f.V(s * 1.15, L - 2.1, 0.5), f.V(s * 1.15, L - 2.1, 0.7),
			f.V(s * 1.15, -L + 2.5, 0.7)], gris, "metal", f.N(s, 0))
	# el estanque de combustible, a la izquierda tras la cabina
	m.caja(f, -1.12, vc - 1.3, -0.7, vc - 0.3, 0.5, 0.92, Color(0.6, 0.62, 0.64), "metal")
	# el furgón de carga, con un zócalo y las puertas de atrás: dos hojas, sus bisagras y las luces
	m.caja(f, -a, -L, a, vc - 0.25, 1.0, 3.6, col, "pintura")
	m.caja(f, -a - 0.02, -L, a + 0.02, vc - 0.25, 1.0, 1.12, gris, "metal")
	var vt := -L - 0.006
	_rect(m, f, vt, -0.015, 0.015, 1.15, 3.5, OSCURO, "pintura", -1.0)
	for s: float in [-1.0, 1.0]:
		_rect(m, f, vt, s * 1.17, s * 1.21, 1.15, 3.5, OSCURO, "pintura", -1.0)
		_rect(m, f, vt, s * 0.95, s * 1.15, 1.16, 1.36, ROJO, "pintura", -1.0)
	m.caja(f, -1.1, -L - 0.12, 1.1, -L + 0.1, 0.5, 0.66, gris, "metal")  # la barra de atrás
	_patente(m, f, -L - 0.126, 0.69, -1.0)
	ruedas(m, f, 1.18, [L - 1.45, -L + 3.3, -L + 1.9], 0.5)
