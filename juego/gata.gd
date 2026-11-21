# La gata: Watata, el tercer personaje que se puede jugar (jugador.gd cambiar_personaje(): --personaje gata o el menú
# de Esc), y el de los otros jugadores que la eligieron (red.gd traje()). Una gata calicó de pelo corto y gordita, hecha
# desde sus fotos: blanca en el pecho, la guata, las patas, el hocico y una lista entre los ojos; manchas naranjas y
# atigradas en el lomo y la cabeza (la derecha más naranja), la cola atigrada en anillos con la punta negra, la nariz
# rosada, los ojos verde amarillo y un collar verde con su placa (de otro color en los otros jugadores: su color de
# red.gd). De tamaño natural: la cruz a ~0,27 m, la coronilla a ~0,35, del pecho a la grupa ~0,42 m y la cola de 0,3;
# las medidas son a ojo. Mira hacia -Z, como peaton.gd.
#
# Extiende perro.gd: hereda las patas por cinemática inversa (pata()), el paso, el trote y el galope (animar(), con
# centro, pisada y talla, que la achican), el triple salto y el arma en el hocico. Lo que cambia:
# - el pelaje no va en colores por vértice: terminar() escribe en UV y UV2 dónde está cada punto con la gata de pie y una
#   zona (cuerpo, cabeza, orejas, cola), y shaders/pelaje_gata.gdshader dibuja por píxel las manchas, las rayas y la
#   veta del pelo, con luz de pelaje y orejas que dejan pasar la luz. Los ojos (shaders/ojo.gdshader) tienen iris, pupila de
#   rendija que se abre de noche, brillo de córnea y reflejo nocturno, y parpadean; los bigotes son líneas;
# - quieta, al rato se sienta (la grupa en el suelo, las manos juntas y la cola alrededor) y, más rato después, se echa
#   como esfinge con los ojos entornados (postura(), el gancho de perro.gd antes de resolver las patas); sentada se lame
#   la nariz de vez en cuando, como en una de las fotos, y parpadea lento;
# - la boca cerrada (no jadea), las orejas que se van hacia atrás al correr y se mueven solas, la cola en alto con la
#   punta curva al caminar y estirada al correr (cara());
# - en la bicicleta, estirada del sillín al manubrio (sentar()); con el jetpack, como un superhéroe (volar()); muerta,
#   de costado y con los ojos cerrados (tendido()); medidas() acerca la cámara (brazo).
extends "res://perro.gd"

const PELAJE_GATA := preload("res://shaders/pelaje_gata.gdshader")
const TONOS_GATA := {"nariz": "d48689", "boca": "4e2429", "lengua": "e0858f", "collar": "1f8f6c", "metal": "c9c3b2",
	"almohadilla": "cf7f86"}
const PISA_G := 0.012  # m: el nudo de la mano sobre el suelo cuando pisa
# dónde pisa de pie (0 adelante izquierda, 1 adelante derecha, 2 atrás izquierda, 3 atrás derecha), cerca del centro
const PISADA_G := [Vector3(-0.032, PISA_G, -0.14), Vector3(0.032, PISA_G, -0.14), Vector3(-0.04, PISA_G, 0.15), Vector3(0.04, PISA_G, 0.15)]
const L_DEL_G := [0.085, 0.085, 0.032]  # m: húmero, antebrazo y metacarpo
const L_TRAS_G := [0.095, 0.1, 0.065]  # fémur, tibia y metatarso
const OJO := Vector3(0.021, 0.007, -0.0475)  # el centro del ojo derecho, en el marco de la cabeza
const OJO_R := Vector3(0.0118, 0.0106, 0.0068)  # sus radios
const SENTARSE := 1.2  # s quieta hasta sentarse
const ECHARSE := 14.0  # s quieta hasta echarse
# las poses quietas: el tronco (posición, cabeceo, el del pecho) y cada pata [dónde pisa, el hueso de abajo, la mano]
const SENTADA := {"pos": Vector3(0, 0.137, -0.042), "th": 0.55, "pecho": 0.3, "cuello": -0.74,
	"patas": [[Vector3(-0.03, PISA_G, -0.158), 0.05, 0.0], [Vector3(0.03, PISA_G, -0.158), 0.05, 0.0],
		[Vector3(-0.052, PISA_G, -0.08), 1.45, 0.0], [Vector3(0.052, PISA_G, -0.08), 1.45, 0.0]]}
const ECHADA := {"pos": Vector3(0, 0.1, 0.0), "th": 0.02, "pecho": 0.0, "cuello": -0.12,
	"patas": [[Vector3(-0.036, PISA_G, -0.25), 1.45, 0.0], [Vector3(0.036, PISA_G, -0.25), 1.45, 0.0],
		[Vector3(-0.072, PISA_G, 0.045), 1.5, 0.0], [Vector3(0.072, PISA_G, 0.045), 1.5, 0.0]]}
# la cola sentada y echada: el giro en x (+ hacia abajo) y en y (+ hacia la derecha) de cada tramo, en el suelo alrededor
const COLA_SENTADA := [[-0.3, 0.75], [0.06, 0.62], [0.06, 0.62], [0.06, 0.62], [0.06, 0.62], [0.06, 0.62]]
const COLA_ECHADA := [[1.3, 0.25], [-0.4, 0.3], [-0.55, 0.5], [0.0, 0.5], [0.0, 0.5], [0.0, 0.5]]

var bigotes := MeshInstance3D.new()
var quieta := 0.0  # s quieta en el suelo
var sentada := 0.0  # 0 … 1 (la mezcla de la pose)
var echada := 0.0
var lamer := -1.0  # s desde que empezó a lamerse la nariz (-1: no)
var t_lamer := 4.0  # s hasta la próxima (sentada)
var oreja_mueve := -1.0  # s desde que una oreja empezó a moverse sola
var oreja_cual := 0
var t_oreja := 3.0
var oreja_base: Array[Vector3] = []  # el giro de cada oreja como se armó
var cola_x: Array[float] = []  # el giro de cada tramo de la cola (suavizado)
var cola_y: Array[float] = []
var _rapidez := 0.0  # la de este cuadro (animar()), para los ojos (ojos_animar())


func _init() -> void:
	centro = 0.205
	pisada = PISADA_G
	talla = 0.5


func _ready() -> void:
	var pel := material_pelaje(PELAJE_GATA)
	pel.set_shader_parameter("ojo", OJO)
	pel.set_shader_parameter("ojo_radio", Vector2(OJO_R.x, OJO_R.y))
	mats["pelo"] = pel
	mats["oido"] = pel
	mats["ojo"] = material_ojo(OJO_R, Color(0.8, 0.72, 0.3), Color(0.5, 0.58, 0.27), Vector2(0.3, 0.85), false)
	for k in TONOS_GATA:
		mats[k] = material_perro(k)
	mats["almohadilla"].roughness = 0.55
	_rng.randomize()
	t_parpadeo = _rng.randf_range(1.0, 4.0)
	tronco.position.y = centro
	add_child(tronco)
	torso.position.z = -0.01  # la mitad de adelante (el pecho)
	cadera.position.z = 0.01  # la de atrás (la guata y la grupa)
	tronco.add_child(torso)
	tronco.add_child(cadera)
	_zona = zona_cuerpo
	# el cuerpo: hondo en el pecho, ancho y bajo en la guata (la panza le cuelga), redondo en la grupa
	empezar()
	suave("pelo", [Z(-0.205, 0.005, 0.02, 0.022), Z(-0.195, 0.0, 0.045, 0.052), Z(-0.17, -0.004, 0.06, 0.068),
		Z(-0.125, -0.008, 0.07, 0.078), Z(-0.07, -0.014, 0.08, 0.087), Z(-0.015, -0.02, 0.088, 0.093), Z(0.045, -0.021, 0.083, 0.087)],
		28, 2.15, true, true, 4)
	terminar(torso)
	empezar()
	suave("pelo", [Z(-0.04, -0.021, 0.082, 0.086), Z(0.02, -0.024, 0.092, 0.095), Z(0.07, -0.02, 0.088, 0.09), Z(0.115, -0.012, 0.078, 0.08),
		Z(0.155, -0.004, 0.064, 0.066), Z(0.185, 0.003, 0.044, 0.046), Z(0.2, 0.008, 0.018, 0.02)], 28, 2.15, true, true, 4)
	terminar(cadera)
	armar_cuello()
	armar_cola()
	for i in 4:
		armar_pata(i)
	# la mochila del jetpack (vehiculo.gd, hecha para la espalda de una persona): acostada en el lomo como en el perro, a
	# 0,36 de su tamaño
	lomo.transform = Transform3D(Basis(Vector3.RIGHT, Vector3.FORWARD, Vector3.UP).scaled(Vector3.ONE * 0.36), Vector3(0, 0.032, 0.1))
	tronco.add_child(lomo)
	mano.assign([hocico, hocico])
	animar(0.5, 0.0, true)


func tono(k: String) -> Color:
	if k == "collar":
		return Color(colores.get("collar", colores.get("polera", TONOS_GATA["collar"])))
	return Color(TONOS_GATA[k])


# el cuello (corto y grueso), el collar, la cabeza redonda con sus ojos, orejas, mandíbula, lengua y bigotes
func armar_cuello() -> void:
	cuello.position = Vector3(0, 0.03, -0.165)
	torso.add_child(cuello)
	_zona = zona_cuerpo
	empezar()
	cadena("pelo", [[Vector3(0, -0.05, 0.045), 0.055, 0.06], [Vector3(0, -0.008, 0.006), 0.05, 0.055], [Vector3(0, 0.025, -0.015), 0.045, 0.047],
		[Vector3(0, 0.045, -0.025), 0.04, 0.04]])
	# el collar: una banda un poco más ancha que el cuello y la placa redonda colgando adelante
	var eje := Vector3(0, 0.81, -0.59)
	var c0 := Vector3(0, 0.029, -0.014)
	cadena("collar", [[c0 - eje * 0.0065, 0.0465, 0.0485], [c0 - eje * 0.0045, 0.0492, 0.0512], [c0 + eje * 0.0045, 0.0492, 0.0512],
		[c0 + eje * 0.0065, 0.0465, 0.0485]], false, false)
	var abajo := Vector3(0, -0.59, -0.81)
	tubo("metal", c0 + abajo * 0.052 - Vector3(0.003, 0, 0), c0 + abajo * 0.052 + Vector3(0.003, 0, 0), 0.0022, 0.0022, 6)
	elipsoide("metal", c0 + abajo * 0.054 + Vector3(0, -0.009, -0.002), Vector3(0.0075, 0.0075, 0.0016), 12, 6)
	terminar(cuello)
	cabeza.position = Vector3(0, 0.05, -0.036)
	cuello.add_child(cabeza)
	_zona = func(_k: String, l: Vector3, _q: Vector3) -> Vector4: return Vector4(l.x, l.y, l.z, 1.0)
	empezar()
	# el cráneo y las mejillas: secciones verticales de la nuca a la cara, más ancho que alto y redondo, con las mejillas
	# adelante
	suave("pelo", [Z(0.042, 0.004, 0.018, 0.018), Z(0.034, 0.006, 0.038, 0.036), Z(0.018, 0.005, 0.05, 0.044), Z(0.0, 0.002, 0.055, 0.046),
		Z(-0.018, -0.003, 0.056, 0.044), Z(-0.032, -0.007, 0.051, 0.038), Z(-0.044, -0.009, 0.041, 0.03), Z(-0.052, -0.011, 0.027, 0.02),
		Z(-0.056, -0.012, 0.01, 0.008)], 28, 2.0, true, true, 3)
	# el hocico: el puente de la nariz, los cojinetes de los bigotes y la nariz
	elipsoide("pelo", Vector3(0, -0.001, -0.05), Vector3(0.012, 0.014, 0.009), 12, 6)
	for lado in [-1.0, 1.0]:
		elipsoide("pelo", Vector3(0.0105 * lado, -0.019, -0.05), Vector3(0.0128, 0.0105, 0.011), 14, 7)
	elipsoide("nariz", Vector3(0, -0.0082, -0.0598), Vector3(0.0078, 0.0049, 0.0042), 10, 5)
	tubo("boca", Vector3(0, -0.0125, -0.0592), Vector3(0, -0.0175, -0.0588), 0.0008, 0.0008, 5)  # la línea bajo la nariz
	terminar(cabeza)
	for lado in [-1.0, 1.0]:
		var o := Node3D.new()
		o.position = Vector3(OJO.x * lado, OJO.y, OJO.z)
		o.rotation = Vector3(0.0, -0.25 * lado, 0.07 * lado)  # hacia afuera y con el rabillo más alto
		cabeza.add_child(o)
		ojos.append(o)
		empezar()
		elipsoide("ojo", Vector3.ZERO, OJO_R, 18, 9)  # grande y redondo (con un párpado de pelo encima quedaba con cara de enojada)
		terminar(o)
	for lado in [-1.0, 1.0]:
		var o := Node3D.new()
		o.position = Vector3(0.029 * lado, 0.036, 0.006)
		o.rotation = Vector3(-0.08, -0.3 * lado, -0.38 * lado)  # abiertas hacia adelante y un poco afuera
		cabeza.add_child(o)
		orejas.append(o)
		oreja_base.append(o.rotation)
		var z := 2.0 if lado < 0.0 else 3.0
		_zona = func(k: String, l: Vector3, _q: Vector3) -> Vector4: return Vector4(l.x, l.y, l.z, 5.0 if k == "oido" else z)
		empezar()
		cadena("pelo", [[Vector3(0, -0.01, 0.004), 0.021, 0.009], [Vector3(0, 0.01, 0.004), 0.019, 0.0075], [Vector3(0, 0.028, 0.003), 0.011, 0.005],
			[Vector3(0, 0.041, 0.002), 0.003, 0.002]])
		cadena("oido", [[Vector3(0, -0.006, -0.003), 0.016, 0.0035], [Vector3(0, 0.01, -0.0029), 0.0135, 0.003], [Vector3(0, 0.027, -0.0019), 0.006, 0.0018]])
		terminar(o)
	mandibula.position = Vector3(0, -0.027, -0.028)
	cabeza.add_child(mandibula)
	var al_cab := mandibula.transform
	_zona = func(_k: String, l: Vector3, _q: Vector3) -> Vector4:
		var h := al_cab * l
		return Vector4(h.x, h.y, h.z, 1.0)
	empezar()
	suave("pelo", [Z(0.012, -0.002, 0.018, 0.009), Z(-0.004, -0.004, 0.015, 0.0085), Z(-0.014, -0.004, 0.011, 0.007), Z(-0.021, -0.003, 0.005, 0.004)], 12, 2.0)
	elipsoide("boca", Vector3(0, 0.004, -0.006), Vector3(0.009, 0.003, 0.013), 8, 4)
	terminar(mandibula)
	lengua.position = Vector3(0, 0.004, -0.002)
	mandibula.add_child(lengua)
	empezar()
	cadena("lengua", [[Vector3(0, 0, 0.004), 0.0072, 0.002], [Vector3(0, 0.0005, -0.01), 0.0078, 0.0022], [Vector3(0, 0.001, -0.019), 0.0066, 0.002]])
	terminar(lengua)
	lengua.visible = false
	hocico.position = Vector3(0, -0.03, -0.054)
	cabeza.add_child(hocico)
	armar_bigotes()


# los bigotes: cuatro por lado desde los cojinetes, hacia afuera y un poco adelante, curvos; y dos sobre cada ojo. Son
# líneas (un píxel de ancho a cualquier distancia: un tubo de medio milímetro titilaría)
func armar_bigotes() -> void:
	var v := PackedVector3Array()
	for lado in [-1.0, 1.0]:
		for j in 4:
			var a := Vector3(0.017 * lado, -0.0155 - 0.0028 * j, -0.0565 + 0.0018 * j)
			var largo := 0.072 - 0.006 * j
			var sube := 0.012 - 0.009 * j
			var antes := a
			for s in range(1, 7):
				var u := s / 6.0
				var p := a + Vector3(lado * largo * u, sube * u - 0.012 * u * u, -0.018 * u + 0.022 * u * u)
				v.append_array([antes, p])
				antes = p
		for j in 2:
			var a := Vector3((0.014 + 0.008 * j) * lado, 0.019 - 0.002 * j, -0.047 + 0.003 * j)
			var antes := a
			for s in range(1, 5):
				var u := s / 4.0
				var p := a + Vector3(lado * 0.008 * u, 0.017 * u - 0.005 * u * u, 0.004 * u)
				v.append_array([antes, p])
				antes = p
	var nor := PackedVector3Array()
	nor.resize(v.size())
	nor.fill(Vector3.UP)
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = v
	a[Mesh.ARRAY_NORMAL] = nor
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, a)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("f1eee8")
	m.roughness = 0.5
	am.surface_set_material(0, m)
	bigotes.mesh = am
	bigotes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cabeza.add_child(bigotes)


# la cola: seis tramos de 0,05 m que se adelgazan, con una bola en cada unión para que no se abran al doblarse
func armar_cola() -> void:
	var padre: Node3D = cadera
	var radios := [0.02, 0.019, 0.0175, 0.016, 0.0145, 0.013, 0.011]
	for k in 6:
		var c := Node3D.new()
		c.position = Vector3(0, 0.035, 0.19) if k == 0 else Vector3(0, 0, 0.05)
		padre.add_child(c)
		cola.append(c)
		cola_x.append(0.0)
		cola_y.append(0.0)
		var desde := k * 0.05
		_zona = func(_k: String, l: Vector3, _q: Vector3) -> Vector4: return Vector4(desde + l.z, l.x, l.y, 4.0)
		empezar()
		var secs := [[Vector3(0, 0, -0.012 if k == 0 else 0.0), radios[k], radios[k]], [Vector3(0, 0, 0.05), radios[k + 1], radios[k + 1]]]
		if k == 5:
			secs.append([Vector3(0, 0, 0.062), 0.004, 0.004])
		cadena("pelo", secs, k == 0, k == 5)
		if k > 0:
			elipsoide("pelo", Vector3.ZERO, Vector3.ONE * radios[k], 12, 6)
		terminar(c)
		padre = c


# la pata i: tres huesos y la mano, como en perro.gd, más finos; las manos redondas con cuatro dedos y las almohadillas
# rosadas abajo (se ven al levantarlas)
func armar_pata(i: int) -> void:
	var lado := -1.0 if i % 2 == 0 else 1.0
	var adelante := i < 2
	var l: Array = L_DEL_G if adelante else L_TRAS_G
	var n := []
	_zona = zona_cuerpo
	var arriba := Node3D.new()
	if adelante:
		arriba.position = Vector3(0.042 * lado, -0.025, -0.125)
		torso.add_child(arriba)
	else:
		arriba.position = Vector3(0.048 * lado, -0.005, 0.125)
		cadera.add_child(arriba)
	n.append(arriba)
	empezar()
	if adelante:  # la paleta y el brazo, metidos en el cuerpo
		cadena("pelo", [[Vector3(-0.008 * lado, 0.05, 0.012), 0.022, 0.03], [Vector3(-0.004 * lado, 0.018, 0.004), 0.032, 0.042],
			[Vector3(0, -0.03, -0.002), 0.031, 0.037], [Vector3(0, -0.07, 0.005), 0.024, 0.028], [Vector3(0, -0.088, 0.008), 0.02, 0.022]])
	else:  # el muslo, grueso
		cadena("pelo", [[Vector3(-0.01 * lado, 0.05, 0.004), 0.03, 0.045], [Vector3(-0.004 * lado, 0.015, -0.008), 0.042, 0.058],
			[Vector3(0, -0.035, -0.01), 0.038, 0.05], [Vector3(0, -0.078, -0.003), 0.024, 0.03], [Vector3(0, -0.098, 0.0), 0.017, 0.019]])
	terminar(arriba)
	var medio := Node3D.new()
	medio.position.y = -l[0]
	arriba.add_child(medio)
	n.append(medio)
	empezar()
	if adelante:  # el antebrazo, con la punta del codo atrás
		cadena("pelo", [[Vector3(0, 0.012, 0.006), 0.024, 0.026], [Vector3(0, -0.035, 0.0), 0.0205, 0.0225], [Vector3(0, -0.08, -0.001), 0.0155, 0.0165],
			[Vector3(0, -0.088, 0.0), 0.014, 0.015]])
		elipsoide("pelo", Vector3(0, 0.0, 0.01), Vector3(0.0145, 0.016, 0.014), 8, 4)
	else:  # la pierna y el corvejón
		cadena("pelo", [[Vector3(0, 0.012, 0.0), 0.021, 0.025], [Vector3(0, -0.035, 0.01), 0.019, 0.025], [Vector3(0, -0.085, 0.007), 0.013, 0.015],
			[Vector3(0, -0.102, 0.005), 0.0125, 0.014]])
		elipsoide("pelo", Vector3(0, -0.1, 0.008), Vector3(0.011, 0.013, 0.011), 8, 4)
	terminar(medio)
	var abajo := Node3D.new()
	abajo.position.y = -l[1]
	medio.add_child(abajo)
	n.append(abajo)
	empezar()
	cadena("pelo", [[Vector3(0, 0.006, 0.002), 0.0142, 0.015], [Vector3(0, -l[2] * 0.5, 0.0), 0.0132, 0.014], [Vector3(0, -l[2] - 0.002, -0.003), 0.0138, 0.0145]])
	terminar(abajo)
	var mn := Node3D.new()
	mn.position.y = -l[2]
	abajo.add_child(mn)
	n.append(mn)
	empezar()
	elipsoide("pelo", Vector3(0, -0.002, -0.008), Vector3(0.018, 0.011, 0.02), 12, 6)
	for d in [-1.5, -0.5, 0.5, 1.5]:
		var x: float = d * 0.0078
		var z := -0.022 + absf(d) * 0.0035
		elipsoide("pelo", Vector3(x, -0.004, z), Vector3(0.0062, 0.0075, 0.0068), 8, 4)
		elipsoide("almohadilla", Vector3(x, -0.0105, z + 0.001), Vector3(0.0042, 0.0016, 0.0042), 6, 3)
	elipsoide("almohadilla", Vector3(0, -0.011, -0.004), Vector3(0.009, 0.002, 0.0075), 8, 4)
	terminar(mn)
	patas.append({"n": n, "l": l, "s": -1.0 if adelante else 1.0})


# ---------------------------------------------------------------- las poses

func animar(dt: float, rapidez: float, en_suelo: bool) -> void:
	_rapidez = rapidez
	var muerta := muerto()
	# quieta en el suelo, sin apuntar: al rato se sienta y después se echa (con un arma en el hocico, no se echa)
	var quieto_ahora := en_suelo and rapidez < 0.12 and salto == 0 and alza < 0.5 and recarga < 0.0 and not muerta
	quieta = quieta + dt if quieto_ahora else 0.0
	var a_sentar := 1.0 if quieta > SENTARSE else 0.0
	var a_echar := 1.0 if quieta > ECHARSE and arma == null else 0.0
	sentada = move_toward(sentada, a_sentar, dt / (0.5 if a_sentar > sentada else 0.15))
	echada = move_toward(echada, a_echar, dt / (1.0 if a_echar > echada else 0.2))
	super.animar(dt, rapidez, en_suelo)
	cara(dt, rapidez)
	boca_arma(dt)


# los ojos (perro.gd los anima al final de animar()): sentada o echada, los parpadeos más espaciados y a veces lentos;
# echada, entornados; al galope, achinados
func ojos_animar(dt: float) -> void:
	var e := smoothstep(0.0, 1.0, echada)
	var galope := smoothstep(9.0, 14.0, _rapidez)
	parpadear(dt, lerpf(1.0, 0.45, e) * (1.0 - 0.3 * galope), maxf(smoothstep(0.0, 1.0, sentada), e) > 0.9)


# sentada o echada: la pose quieta reemplaza la del paso (perro.gd la llama antes de resolver las patas)
func postura(_dt: float, metas: Array) -> void:
	var s := smoothstep(0.0, 1.0, sentada)
	var e := smoothstep(0.0, 1.0, echada)
	var w := maxf(s, e)
	if w <= 0.0:
		return
	tronco.position = tronco.position.lerp(SENTADA["pos"].lerp(ECHADA["pos"], e), w)
	tronco.rotation = Vector3(lerpf(tronco.rotation.x, lerpf(SENTADA["th"], ECHADA["th"], e), w), 0.0, lerpf(tronco.rotation.z, 0.0, w))
	torso.rotation.x = lerpf(torso.rotation.x, lerpf(SENTADA["pecho"], ECHADA["pecho"], e), w)
	cadera.rotation.x = lerpf(cadera.rotation.x, 0.0, w)
	for i in 4:
		var a: Array = SENTADA["patas"][i]
		var b: Array = ECHADA["patas"][i]
		var meta: Vector3 = (a[0] as Vector3).lerp(b[0], e)
		metas[i] = [(metas[i][0] as Vector3).lerp(meta, w), lerpf(metas[i][1], lerpf(a[1], b[1], e), w),
			lerpf(metas[i][2], lerpf(a[2], b[2], e), w)]


# lo de la cara y la cola, después del paso de perro.gd (que deja la boca jadeando y la cola de perro): la boca cerrada,
# la lengua solo al lamerse, las orejas y la cola de gata (los ojos, en ojos_animar(), que llama animar() del perro)
func cara(dt: float, rapidez: float) -> void:
	var k := 1.0 - exp(-10.0 * dt)
	var mov := smoothstep(0.15, 1.0, rapidez)
	var trote := smoothstep(2.0, 5.0, rapidez)
	var galope := smoothstep(9.0, 14.0, rapidez)
	var s := smoothstep(0.0, 1.0, sentada)
	var e := smoothstep(0.0, 1.0, echada)
	var w := maxf(s, e)
	# sentada o echada, el cuello endereza la cabeza (el tronco va inclinado)
	cuello.rotation.x = lerpf(cuello.rotation.x, lerpf(SENTADA["cuello"], ECHADA["cuello"], e), w)
	var resp := 0.01 * sin(t * 2.6) * (1.0 - mov)  # respira despacio: no jadea
	torso.scale = Vector3(1.0 + resp, 1.0 + resp, 1.0)
	# se lame la nariz: tres lengüetazos en 1,4 s, sentada y sin arma
	if s > 0.95 and e < 0.05 and arma == null:
		t_lamer -= dt
		if t_lamer <= 0.0 and lamer < 0.0:
			lamer = 0.0
			t_lamer = _rng.randf_range(7.0, 13.0)
	var abre := 0.02
	if lamer >= 0.0:
		lamer += dt
		var u := lamer / 1.4
		var env := sin(PI * minf(u, 1.0))
		var lengueta := 0.5 - 0.5 * cos(TAU * 3.0 * u)
		abre = 0.34 * env
		lengua.position = Vector3(0, 0.004 + 0.004 * lengueta * env, -0.002 - 0.02 * env - 0.006 * lengueta)
		lengua.rotation = Vector3(0.5 + 0.9 * lengueta, 0.0, 0.0)
		cabeza.rotation.x = lerpf(cabeza.rotation.x, 0.22, 0.5 * env)
		if u >= 1.0 or w < 0.5 or arma != null:
			lamer = -1.0
	if arma:
		abre = 0.07
	mandibula.rotation.x = -abre
	lengua.visible = lamer >= 0.0
	# las orejas: hacia atrás al correr y en el aire; de vez en cuando una se mueve sola (un tic hacia atrás y afuera)
	t_oreja -= dt
	if t_oreja <= 0.0 and oreja_mueve < 0.0:
		oreja_mueve = 0.0
		oreja_cual = _rng.randi() % 2
		t_oreja = _rng.randf_range(2.5, 7.0)
	var tic := 0.0
	if oreja_mueve >= 0.0:
		oreja_mueve += dt
		tic = sin(PI * clampf(oreja_mueve / 0.25, 0.0, 1.0))
		if oreja_mueve > 0.25:
			oreja_mueve = -1.0
	var atras := 0.4 * trote * mov + 0.45 * galope + 0.5 * aire
	for j in 2:
		var b := oreja_base[j]
		var lado := -1.0 if j == 0 else 1.0
		var t_j := tic if j == oreja_cual else 0.0
		orejas[j].rotation = Vector3(b.x + atras + 0.3 * t_j, b.y - lado * 0.55 * t_j, b.z)
	# la cola: en alto con la punta curva hacia adelante, quieta o al paso; estirada atrás al trote, al galope y en el
	# aire; sentada o echada, en el suelo alrededor de las patas, con la punta que se mueve
	var n := cola.size()
	var corre := maxf(galope, aire)
	var punta := 0.25 * sin(t * 4.0) * smoothstep(0.4, 1.0, sin(t * 0.5))  # la punta que se mueve sola, a ratos
	for j in n:
		var alto_x := -1.2 if j == 0 else (-0.04 if j < n - 2 else -0.42)
		var tx := lerpf(alto_x, -0.5 if j == 0 else 0.08, trote * mov)  # al trote, levantada y curva hacia abajo
		tx = lerpf(tx, -0.18 if j == 0 else 0.03, corre)
		var ty := 0.13 * sin(t * 1.6 - j * 0.7) * (1.0 - maxf(corre, trote * mov * 0.6))
		var suelo_x: float = lerpf(COLA_SENTADA[j][0], COLA_ECHADA[j][0], e)
		var suelo_y: float = lerpf(COLA_SENTADA[j][1], COLA_ECHADA[j][1], e) + (punta if j >= n - 2 else 0.0)
		tx = lerpf(tx, suelo_x, w)
		ty = lerpf(ty, suelo_y, w)
		cola_x[j] = lerpf(cola_x[j], tx, k)
		cola_y[j] = lerpf(cola_y[j], ty, k)
		cola[j].rotation = Vector3(cola_x[j], cola_y[j], 0.0)


# En la bicicleta (vehiculo.gd pedalear()): estirada del sillín al manubrio, las patas de atrás en el sillín (amasan al
# ritmo de los pedales, que no alcanza) y las manos en el manubrio, la cabeza adelante y la cola al viento
func sentar(dt: float, pies: Array, incl: float, _hombros: float, _codos: float) -> void:
	t += dt
	var k := 1.0 - exp(-14.0 * dt)
	salto = 0
	vuelta = 0.0
	aire = 0.0
	quieta = 0.0
	sentada = 0.0
	echada = 0.0
	var th := -0.06 - 0.35 * (incl - 0.62)  # más agachada adelante pedaleando fuerte
	tronco.position = tronco.position.lerp(Vector3(0, 1.015, -0.29), k)
	inclinacion = lerpf(inclinacion, th, k)
	tronco.rotation = Vector3(inclinacion, 0.0, 0.0)
	torso.rotation.x = lerpf(torso.rotation.x, 0.0, k)
	cadera.rotation.x = lerpf(cadera.rotation.x, 0.0, k)
	torso.scale = Vector3.ONE
	for i in 2:
		pata(i, Vector3(pisada[i].x * 1.6, 0.997, -0.59), 0.6, 0.2)  # el manubrio: 0,59 m adelante y 0,985 arriba del pie del modelo
		# el pie del pedal respecto del eje de la biela (vehiculo.gd: pies desde la cadera): cuándo sube
		var p: Vector2 = pies[i] - Vector2(0.19, -0.66)
		var sube := 0.018 * maxf(sin(atan2(p.y, p.x)), 0.0)
		pata(i + 2, Vector3(pisada[i + 2].x, 0.877 + PISA_G + sube, 0.035), 0.35, 0.0)  # el sillín: arriba a ~0,88 del pie del modelo
	cuello.rotation.x = lerpf(cuello.rotation.x, -0.1, k)
	cuello.rotation.y = lerpf(cuello.rotation.y, 0.0, k)
	cabeza.rotation.x = lerpf(cabeza.rotation.x, 0.05, k)
	cabeza.rotation.z = lerpf(cabeza.rotation.z, 0.0, k)
	quieta_cara(dt, 0.75, 0.35)
	for j in cola.size():
		cola_x[j] = lerpf(cola_x[j], -0.15 if j == 0 else 0.03, k)
		cola_y[j] = 0.15 * sin(t * 5.0 - j * 0.9)
		cola[j].rotation = Vector3(cola_x[j], cola_y[j], 0.0)


# Con el jetpack en el aire (vehiculo.gd pose_vuelo()): estirada como un superhéroe, las manos adelante, las patas atrás,
# las orejas aplastadas, los ojos achinados y la cola flameando
func volar(dt: float, inclinar: Vector3) -> void:
	t += dt
	var k := 1.0 - exp(-8.0 * dt)
	salto = 0
	vuelta = 0.0
	aire = 1.0
	quieta = 0.0
	sentada = 0.0
	echada = 0.0
	tronco.position = tronco.position.lerp(Vector3(0, centro + 0.05, 0), k)
	inclinacion = lerpf(inclinacion, 0.05, k)
	tronco.rotation = Vector3(inclinacion, 0.0, 0.0)
	torso.rotation.x = lerpf(torso.rotation.x, 0.06, k)
	cadera.rotation.x = lerpf(cadera.rotation.x, -0.06, k)
	torso.scale = Vector3.ONE
	var al_tronco := tronco.transform
	var vaiven := 0.015 * sin(t * 2.1)
	for i in 4:
		var meta: Vector3 = Vector3(pisada[i].x, -0.06 + vaiven, -0.3) if i < 2 else Vector3(pisada[i].x, -0.1 - vaiven, 0.31)
		pata(i, al_tronco * meta, 0.0 if i < 2 else 0.4, 0.0)
	cuello.rotation.x = lerpf(cuello.rotation.x, -0.3, k)
	cuello.rotation.y = lerpf(cuello.rotation.y, 0.0, k)
	cabeza.rotation.x = lerpf(cabeza.rotation.x, 0.25 + inclinar.x * 0.7, k)
	cabeza.rotation.z = lerpf(cabeza.rotation.z, 0.0, k)
	quieta_cara(dt, 0.6, 1.0 + 0.12 * sin(t * 19.0))
	mandibula.rotation.x = -0.12
	for j in cola.size():
		cola_x[j] = lerpf(cola_x[j], -0.1 if j == 0 else 0.02, k)
		cola_y[j] = 0.16 * sin(t * 12.0 - j * 1.1)
		cola[j].rotation = Vector3(cola_x[j], cola_y[j], 0.0)


# la cara montada (sentar(), volar()): la boca cerrada, sin lengua, los ojos abiertos a ap (con sus parpadeos) y las
# orejas atras rad hacia atrás
func quieta_cara(dt: float, ap: float, atras: float) -> void:
	lamer = -1.0
	lengua.visible = false
	mandibula.rotation.x = -0.02
	parpadear(dt, ap)
	for j in 2:
		var b := oreja_base[j]
		orejas[j].rotation = Vector3(b.x + atras, b.y, b.z)


# ---------------------------------------------------------------- lo que leen los demás

# muerta (jugador.gd, red.gd): de costado, con los ojos cerrados (perro.gd parpadear()); f de 0 (de pie) a 1 (tendida)
func tendido(n: Node3D, f: float) -> void:
	caida = f
	t_caida = 0.0
	n.rotation.x = 0.0
	n.rotation.z = 1.5 * f
	n.position.y = 0.075 * f


func portabandera() -> Transform3D:
	return tronco.global_transform * Transform3D(Basis(Vector3.RIGHT, 0.35), Vector3(0.03, 0.07, 0.07))


# brazo: el largo del brazo de la cámara a pie (jugador.gd brazo_de(): la persona y el perro, 5 m; la gata es mucho más
# chica); cabeza: adonde apunta la prueba de los tiros a la cabeza (red.gd apuntar())
func medidas() -> Dictionary:
	return {"ojo": 0.55, "etiqueta": 0.7, "radio": 0.14, "alto": 0.62, "brazo": 2.2, "cabeza": Vector3(0, 0.29, -0.26),
		"blanco": Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(0, 0.21, -0.04))}


# la cabeza (el doble de daño): adelante del pecho y sobre la cruz
func es_cabeza(p: Vector3) -> bool:
	return p.z < -0.17 and p.y > 0.22
