# El perro: el otro personaje que se puede jugar (jugador.gd cambiar_personaje(): --personaje perro o el menú de Esc), y
# el de los otros jugadores que lo eligieron (red.gd traje()). Un quiltro mediano de pelo corto, como el de la foto que
# lo inspiró: café claro (leonado), el pecho y el vientre crema, las patas blancas desde el carpo, el hocico gris oscuro
# casi negro con una sombra alrededor de los ojos, las orejas grandes y paradas con la punta oscura, la cola larga con la
# punta clara y un collar oscuro con argolla y placa (de otro color en los otros jugadores: su color de red.gd). La cruz
# a 0,57 m, la cabeza a ~0,75, de la trufa a la grupa ~1,05 m; las medidas son a ojo. Mira hacia -Z, como peaton.gd.
#
# Extiende peaton.gd: hereda sus mallas por secciones (loft(), elipsoide(), caja()), el arma (sostener(), disparo(),
# golpear(), alza, mira, objetivo) y el triple salto (saltar(), salto, vuelta), así que jugador.gd, armas.gd,
# vehiculo.gd, red.gd y bandera.gd lo usan igual que al peatón. Lo que cambia con el cuerpo son métodos que este
# reemplaza: animar(), sentar() (en la bicicleta: sentado en el sillín, las manos en el manubrio y las patas de atrás
# hacia los pedales), volar() (con el jetpack: estirado como un superhéroe), tendido() (muerto, de costado),
# montura() (la mochila del jetpack, acostada en el lomo, sin correas), portabandera(), medidas() y es_cabeza().
#
# Cada pata es una cadena de tres huesos y la mano o el pie (hombro, codo, carpo; cadera, rodilla, corvejón), resuelta
# cada cuadro como cinemática inversa (pata()): la almohadilla va a su punto y el hueso de abajo (el metacarpo o el
# metatarso) tiene su ángulo, así que los pies pisan donde deben aunque el tronco suba, baje, cabecee o se doble. Los
# puntos salen del paso: al paso (lateral: atrás izquierda, adelante izquierda, atrás derecha, adelante derecha), al
# trote (las diagonales juntas) y al galope (rotatorio, con el lomo que se dobla y se estira y las cuatro en el aire), y
# se mezclan según la rapidez, como la zancada de peaton.gd. En el aire, encogido (primer salto), estirado (el segundo) y
# hecho un ovillo en la voltereta (el tercero). La boca abierta jadeando con la lengua afuera, la cola que se mueve más
# cuando está quieto y las orejas que se van hacia atrás al correr. El arma, en el hocico (mano[DER]): la pistola y el
# rifle de lado, a lo pandillero, y el cuchillo atravesado como un hueso.
#
# El pelaje no va en colores por vértice: terminar() escribe en UV y UV2 dónde está cada punto con el perro de pie y su
# zona (_zona), y shaders/pelaje_perro.gdshader lo pinta por píxel (con pelo.gdshaderinc, que comparte con la gata). Los
# ojos son nodos propios (ojos) con shaders/ojo.gdshader: iris café, pupila redonda y brillo de córnea; parpadean
# (parpadear()) y muerto quedan cerrados.
extends "res://peaton.gd"

# los colores lisos (por vértice); los del pelaje están en shaders/pelaje_perro.gdshader
const TONOS := {"crema": "ecdfc8", "nariz": "1a1716", "lengua": "d2707c", "boca": "6a3036", "collar": "26272a",
	"metal": "c2bba9", "una": "35302b"}
const PELAJE_PERRO := preload("res://shaders/pelaje_perro.gdshader")
const OJO_SH := preload("res://shaders/ojo.gdshader")
const OJO_PERRO := Vector3(0.039, 0.047, -0.113)  # el centro del ojo derecho, en el marco de la cabeza (sin su escala)
const OJO_PERRO_R := Vector3(0.0145, 0.0135, 0.0105)
const CENTRO := 0.45  # m: el tronco (su nodo) sobre el suelo, de pie
const PISA := 0.027  # m: el nudo de la mano o el pie sobre el suelo cuando pisa (el grosor de la almohadilla)
const L_DEL := [0.17, 0.19, 0.07]  # m: húmero, antebrazo y metacarpo
const L_TRAS := [0.19, 0.2, 0.12]  # fémur, tibia y metatarso
# 0 adelante izquierda, 1 adelante derecha, 2 atrás izquierda, 3 atrás derecha: dónde pisa de pie (en el marco del perro)
const PISADA := [Vector3(-0.08, PISA, -0.27), Vector3(0.08, PISA, -0.27), Vector3(-0.07, PISA, 0.31), Vector3(0.07, PISA, 0.31)]
# el desfase de cada pata en el ciclo (0 … 1): al paso, al trote y al galope
const AL_PASO := [0.25, 0.75, 0.0, 0.5]
const AL_TROTE := [0.0, 0.5, 0.5, 0.0]
const AL_GALOPE := [0.57, 0.45, 0.0, 0.12]
const ANGULO_ABAJO := [0.12, 0.08]  # rad: el metacarpo y el metatarso al pisar, desde la vertical (+ hacia adelante)

var tronco := Node3D.new()  # el centro del cuerpo: sube, baja, cabecea, se ladea y da la voltereta
var cuello := Node3D.new()
var mandibula := Node3D.new()
var lengua := Node3D.new()
var hocico := Node3D.new()  # entre los dientes: el arma (mano[DER])
var lomo := Node3D.new()  # la mochila del jetpack (montura())
var orejas: Array[Node3D] = []
var cola: Array[Node3D] = []
var patas := []  # por pata: {"n": [cuatro nodos], "l": [tres largos], "s": +1 la rodilla adelante, -1 el codo atrás}
var aire := 0.0  # 0 en el suelo … 1 en el aire (la mezcla de las poses)
var inclinacion := 0.0  # rad: el cabeceo del tronco, sin la voltereta (vuelta)
var _zona: Callable  # (material, punto local, punto en el marco del perro) -> Vector4: las coordenadas del dibujo del pelaje y su zona (terminar())
var ojos: Array[Node3D] = []  # cada uno con su elipsoide en el origen: parpadea achatándose en Y (parpadear())
var parpadeo := -1.0  # s desde que empezó a parpadear (-1: no)
var t_parpadeo := 2.0  # s hasta el próximo
var lento := false  # el parpadeo en curso es lento (la gata, sentada o echada)
var caida := 0.0  # tendido(): 0 de pie … 1 tendido
var t_caida := INF  # s desde el último tendido(): muerto mientras se lo siguen llamando
var _rng := RandomNumberGenerator.new()
# el tamaño, para el paso de animar(): gata.gd, que lo extiende, es más chica. talla multiplica los largos del paso (la
# zancada, lo que sube cada pata, el bote, las poses en el aire), y la frecuencia crece como 1/√talla (un animal más chico
# da más pasos a la misma rapidez)
var centro := CENTRO
var pisada: Array = PISADA
var talla := 1.0


func _ready() -> void:
	for k in TONOS:
		mats[k] = material_perro(k)
	mats["pelo"] = material_pelaje(PELAJE_PERRO)
	mats["oido"] = mats["pelo"]
	mats["ojo"] = material_ojo(OJO_PERRO_R, Color("a4713a"), Color("5a3819"), Vector2(0.3, 0.85), true)
	_rng.randomize()
	t_parpadeo = _rng.randf_range(1.0, 4.0)
	tronco.position.y = CENTRO
	add_child(tronco)
	torso.position.z = -0.02  # la mitad de adelante (el pecho)
	cadera.position.z = 0.02  # la de atrás (el lomo y la grupa)
	tronco.add_child(torso)
	tronco.add_child(cadera)
	_zona = zona_cuerpo
	empezar()
	suave("pelo", [Z(-0.375, -0.02, 0.03, 0.05), Z(-0.36, -0.01, 0.075, 0.1), Z(-0.32, 0.0, 0.105, 0.135),
		Z(-0.25, -0.012, 0.118, 0.152), Z(-0.16, -0.012, 0.12, 0.145), Z(-0.06, 0.0, 0.115, 0.13), Z(0.03, 0.012, 0.106, 0.114),
		Z(0.08, 0.02, 0.09, 0.09)], 20, 2.1)
	terminar(torso)
	empezar()
	suave("pelo", [Z(-0.08, 0.012, 0.095, 0.1), Z(-0.05, 0.012, 0.106, 0.114), Z(0.05, 0.03, 0.1, 0.094), Z(0.15, 0.032, 0.106, 0.1),
		Z(0.24, 0.032, 0.112, 0.106), Z(0.31, 0.036, 0.098, 0.094), Z(0.36, 0.04, 0.068, 0.068), Z(0.385, 0.045, 0.025, 0.025)], 20, 2.1)
	terminar(cadera)
	armar_cuello()
	armar_cola()
	for i in 4:
		armar_pata(i)
	# la mochila del jetpack (vehiculo.gd, hecha para la espalda de una persona): acostada en el lomo, su arriba hacia la
	# cabeza y su espalda hacia el cielo, a 0,6 de su tamaño; las toberas quedan hacia la cola
	lomo.transform = Transform3D(Basis(Vector3.RIGHT, Vector3.FORWARD, Vector3.UP).scaled(Vector3.ONE * 0.6), Vector3(0, 0.035, 0.14))
	tronco.add_child(lomo)
	mano.assign([hocico, hocico])
	animar(0.5, 0.0, true)  # de pie desde el comienzo (sin esto, las patas estiradas un cuadro)


func material_perro(k: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true  # los TONOS son sRGB, como los de la página
	m.roughness = 0.85
	match k:
		"nariz":
			m.roughness = 0.3
		"lengua", "boca":
			m.roughness = 0.4
		"metal":
			m.roughness = 0.35
			m.metallic = 0.7
	return m


# el pelaje (shaders/pelaje_perro.gdshader o pelaje_gata.gdshader), que pinta lo que terminar() escribe con _zona
func material_pelaje(sh: Shader) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


# los ojos (shaders/ojo.gdshader): sus radios, el iris junto a la pupila y en el borde, cuánto se abre la pupila de día
# y de noche, y si es redonda (si no, una rendija)
func material_ojo(r: Vector3, adentro: Color, afuera: Color, pupila: Vector2, redonda: bool) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = OJO_SH
	m.set_shader_parameter("radio", Vector2(r.x, r.y))
	m.set_shader_parameter("iris_adentro", Vector3(adentro.r, adentro.g, adentro.b))
	m.set_shader_parameter("iris_afuera", Vector3(afuera.r, afuera.g, afuera.b))
	m.set_shader_parameter("pupila", pupila)
	m.set_shader_parameter("redonda", redonda)
	return m


# la zona 0 de los pelajes: el punto en el marco del animal, de pie
func zona_cuerpo(_k: String, _l: Vector3, q: Vector3) -> Vector4:
	return Vector4(q.x, q.y, q.z, 0.0)


# el cuello (de la cruz a la nuca), el collar, la cabeza con sus orejas, la mandíbula y la lengua
func armar_cuello() -> void:
	cuello.position = Vector3(0, 0.07, -0.25)
	torso.add_child(cuello)
	empezar()
	cadena("pelo", [[Vector3(0, -0.07, 0.07), 0.07, 0.08], [Vector3(0, -0.01, 0.01), 0.07, 0.078], [Vector3(0, 0.08, -0.06), 0.06, 0.066],
		[Vector3(0, 0.15, -0.11), 0.054, 0.06], [Vector3(0, 0.2, -0.145), 0.048, 0.052]])
	# el collar: una banda un poco más ancha que el cuello, una argolla abajo y la placa colgando de ella
	var eje := Vector3(0, 0.8, -0.6)
	var c0 := Vector3(0, 0.045, -0.034)
	cadena("collar", [[c0 - eje * 0.016, 0.071, 0.076], [c0 - eje * 0.012, 0.075, 0.08], [c0 + eje * 0.012, 0.075, 0.08],
		[c0 + eje * 0.016, 0.071, 0.076]], false, false)
	var abajo := Vector3(0, -0.6, -0.8)
	tubo("metal", c0 + abajo * 0.078 - Vector3(0.008, 0, 0), c0 + abajo * 0.078 + Vector3(0.008, 0, 0), 0.006, 0.006, 6)
	elipsoide("metal", c0 + abajo * 0.083 + Vector3(0, -0.022, -0.004), Vector3(0.015, 0.017, 0.004), 10, 5)
	terminar(cuello)
	cabeza.position = Vector3(0, 0.17, -0.13)
	cabeza.scale = Vector3.ONE * 1.12
	cuello.add_child(cabeza)
	empezar()
	# el cráneo, la frente y el hocico: secciones verticales de la nuca a la trufa
	suave("pelo", [Z(0.055, 0.03, 0.025, 0.025), Z(0.035, 0.035, 0.06, 0.058), Z(-0.01, 0.04, 0.074, 0.068), Z(-0.06, 0.036, 0.074, 0.066),
		Z(-0.1, 0.026, 0.064, 0.058), Z(-0.125, 0.012, 0.052, 0.05)], 14, 2.1)
	suave("pelo", [Z(-0.1, 0.002, 0.05, 0.045), Z(-0.16, -0.008, 0.041, 0.036), Z(-0.21, -0.014, 0.034, 0.029),
		Z(-0.245, -0.016, 0.028, 0.023), Z(-0.258, -0.016, 0.015, 0.013)], 12, 2.2)
	elipsoide("nariz", Vector3(0, -0.002, -0.253), Vector3(0.02, 0.015, 0.012), 10, 5)
	elipsoide("boca", Vector3(0, -0.034, -0.15), Vector3(0.026, 0.006, 0.09), 8, 4)  # el paladar
	for lado in [-1.0, 1.0]:
		var o := Node3D.new()
		o.position = Vector3(0.045 * lado, 0.08, -0.005)
		o.rotation = Vector3(0.15, 0.0, -0.3 * lado)
		cabeza.add_child(o)
		orejas.append(o)
	terminar(cabeza)
	for lado in [-1.0, 1.0]:  # los ojos, hacia adelante y un poco afuera
		var o := Node3D.new()
		o.position = Vector3(OJO_PERRO.x * lado, OJO_PERRO.y, OJO_PERRO.z)
		o.rotation.y = -0.3 * lado
		cabeza.add_child(o)
		ojos.append(o)
		empezar()
		elipsoide("ojo", Vector3.ZERO, OJO_PERRO_R, 16, 8)
		terminar(o)
	_zona = func(k: String, _l: Vector3, q: Vector3) -> Vector4: return Vector4(q.x, q.y, q.z, 2.0 if k == "oido" else 4.0)
	for o in orejas:
		empezar()
		cadena("pelo", [[Vector3(0, -0.015, 0.002), 0.036, 0.017], [Vector3(0, 0.03, 0.002), 0.035, 0.013], [Vector3(0, 0.07, 0.004), 0.023, 0.009],
			[Vector3(0, 0.103, 0.006), 0.009, 0.005], [Vector3(0, 0.116, 0.007), 0.002, 0.002]])
		cadena("oido", [[Vector3(0, 0.0, -0.01), 0.025, 0.004], [Vector3(0, 0.05, -0.008), 0.018, 0.004], [Vector3(0, 0.09, -0.004), 0.006, 0.003]])
		terminar(o)
	mandibula.position = Vector3(0, -0.036, -0.06)
	cabeza.add_child(mandibula)
	empezar()
	_zona = func(_k: String, _l: Vector3, q: Vector3) -> Vector4: return Vector4(q.x, q.y, q.z, 1.0)
	suave("pelo", [Z(0.03, -0.008, 0.048, 0.03), Z(-0.04, -0.012, 0.039, 0.022), Z(-0.11, -0.01, 0.03, 0.016), Z(-0.165, -0.006, 0.02, 0.012),
		Z(-0.178, -0.005, 0.01, 0.007)], 10, 2.2)
	elipsoide("boca", Vector3(0, 0.008, -0.08), Vector3(0.024, 0.006, 0.085), 8, 4)
	for lado in [-1.0, 1.0]:  # los colmillos de abajo
		elipsoide("crema", Vector3(0.02 * lado, 0.012, -0.15), Vector3(0.004, 0.009, 0.004), 6, 3)
	terminar(mandibula)
	_zona = zona_cuerpo  # después de terminar(), que es donde se lee: antes de que fuera así, la mandíbula salía del color del pelo
	lengua.position = Vector3(0, 0.012, -0.02)
	mandibula.add_child(lengua)
	empezar()
	cadena("lengua", [[Vector3(0, 0, 0.0), 0.019, 0.006], [Vector3(0, 0.002, -0.08), 0.022, 0.006], [Vector3(0, -0.006, -0.14), 0.023, 0.006],
		[Vector3(0, -0.03, -0.175), 0.02, 0.006], [Vector3(0, -0.056, -0.186), 0.013, 0.005]])
	terminar(lengua)
	hocico.position = Vector3(0, -0.036, -0.165)
	cabeza.add_child(hocico)


# la cola: cuatro tramos de 0,1 m y la punta, más clara, que se mueven como una cadena
func armar_cola() -> void:
	var padre: Node3D = cadera
	var radios := [0.036, 0.03, 0.024, 0.018, 0.011]
	for k in 4:
		var c := Node3D.new()
		c.position = Vector3(0, 0.07, 0.345) if k == 0 else Vector3(0, 0, 0.1)
		padre.add_child(c)
		cola.append(c)
		empezar()
		_zona = func(_k: String, _l: Vector3, q: Vector3) -> Vector4: return Vector4(q.x, q.y, q.z, 3.0)
		var secs := [[Vector3(0, 0, -0.02 if k == 0 else -0.012), radios[k], radios[k]], [Vector3(0, 0, 0.1), radios[k + 1], radios[k + 1]]]
		if k == 3:
			secs.append([Vector3(0, 0, 0.13), 0.004, 0.004])
		cadena("pelo", secs, k == 0, k == 3)
		terminar(c)
		padre = c
	_zona = zona_cuerpo


# la pata i: tres huesos y la mano o el pie, colgando de su articulación (el hombro en el pecho, la cadera en la grupa)
func armar_pata(i: int) -> void:
	var lado := -1.0 if i % 2 == 0 else 1.0
	var adelante := i < 2
	var l: Array = L_DEL if adelante else L_TRAS
	var n := []
	var arriba := Node3D.new()
	if adelante:
		arriba.position = Vector3(0.088 * lado, -0.02, -0.23)
		torso.add_child(arriba)
	else:
		arriba.position = Vector3(0.078 * lado, 0.0, 0.23)
		cadera.add_child(arriba)
	n.append(arriba)
	# el blanco desde un poco sobre el carpo (o el corvejón): de pie y sin animar, las patas cuelgan derechas, así que en
	# pelaje_perro.gdshader es lo que queda bajo una altura
	_zona = zona_cuerpo
	empezar()
	if adelante:  # el hombro (la escápula, ancha) y el brazo
		cadena("pelo", [[Vector3(-0.02 * lado, 0.09, 0.04), 0.03, 0.05], [Vector3(-0.008 * lado, 0.05, 0.01), 0.048, 0.074],
			[Vector3(0, -0.03, -0.004), 0.054, 0.07], [Vector3(0, -0.11, 0.008), 0.046, 0.054], [Vector3(0, -0.17, 0.018), 0.034, 0.038],
			[Vector3(0, -0.195, 0.022), 0.03, 0.03]])
	else:  # el muslo: grueso adelante
		cadena("pelo", [[Vector3(-0.025 * lado, 0.065, 0.0), 0.045, 0.075], [Vector3(-0.008 * lado, 0.03, -0.02), 0.064, 0.098],
			[Vector3(0, -0.06, -0.018), 0.062, 0.084], [Vector3(0, -0.15, -0.004), 0.044, 0.052], [Vector3(0, -0.205, 0.004), 0.033, 0.036]])
	terminar(arriba)
	var medio := Node3D.new()
	medio.position.y = -l[0]
	arriba.add_child(medio)
	n.append(medio)
	empezar()
	if adelante:  # el antebrazo, con la punta del codo atrás
		cadena("pelo", [[Vector3(0, 0.03, 0.014), 0.035, 0.04], [Vector3(0, -0.04, 0.0), 0.034, 0.038], [Vector3(0, -0.13, -0.003), 0.027, 0.029],
			[Vector3(0, -0.195, 0.0), 0.023, 0.025]])
		elipsoide("pelo", Vector3(0, 0.0, 0.03), Vector3(0.025, 0.03, 0.024), 8, 4)
	else:  # la pierna, con la pantorrilla atrás
		cadena("pelo", [[Vector3(0, 0.03, 0.0), 0.036, 0.042], [Vector3(0, -0.05, 0.016), 0.036, 0.05], [Vector3(0, -0.14, 0.01), 0.025, 0.03],
			[Vector3(0, -0.205, 0.008), 0.021, 0.023]])
		elipsoide("pelo", Vector3(0, -0.2, 0.02), Vector3(0.021, 0.025, 0.021), 8, 4)  # el corvejón
	terminar(medio)
	var abajo := Node3D.new()
	abajo.position.y = -l[1]
	medio.add_child(abajo)
	n.append(abajo)
	empezar()
	cadena("pelo", [[Vector3(0, 0.014, 0.003), 0.023, 0.026], [Vector3(0, -l[2] * 0.5, 0.0), 0.021, 0.022], [Vector3(0, -l[2] - 0.004, -0.004), 0.022, 0.023]])
	terminar(abajo)
	var mn := Node3D.new()
	mn.position.y = -l[2]
	abajo.add_child(mn)
	n.append(mn)
	empezar()
	# la mano: plana, más larga que ancha, con cuatro dedos y sus uñas oscuras
	elipsoide("pelo", Vector3(0, -0.006, -0.018), Vector3(0.033, 0.022, 0.042), 10, 5)
	for d in [-1.5, -0.5, 0.5, 1.5]:
		var x: float = d * 0.0135
		var z := -0.046 + absf(d) * 0.006
		elipsoide("pelo", Vector3(x, -0.012, z), Vector3(0.0105, 0.013, 0.014), 8, 4)
		elipsoide("una", Vector3(x * 1.05, -0.018, z - 0.013), Vector3(0.004, 0.005, 0.006), 6, 3)
	terminar(mn)
	patas.append({"n": n, "l": l, "s": -1.0 if adelante else 1.0})


# ---------------------------------------------------------------- mallas

# loft() por secciones intermedias (curvas de Catmull-Rom por las dadas, sub por tramo): sin quiebres donde cambia el
# ancho
func suave(mat: String, secs: Array, n: int, e := 2.0, tapa0 := true, tapa1 := true, sub := 3) -> void:
	loft(mat, subdividir(secs, sub), n, e, tapa0, tapa1)


# cada elemento de lista es un arreglo de valores (Vector3 o float) que se interpolan uno a uno
static func subdividir(lista: Array, sub: int) -> Array:
	if lista.size() < 3 or sub < 2:
		return lista
	var out := []
	var m := lista.size()
	for i in m - 1:
		var a: Array = lista[maxi(i - 1, 0)]
		var b: Array = lista[i]
		var c: Array = lista[i + 1]
		var d: Array = lista[mini(i + 2, m - 1)]
		for j in sub:
			var u := float(j) / sub
			var r := []
			for q in b.size():
				r.append(catmull(a[q], b[q], c[q], d[q], u))
			out.append(r)
	out.append(lista[m - 1])
	return out


static func catmull(a: Variant, b: Variant, c: Variant, d: Variant, u: float) -> Variant:
	var u2 := u * u
	var u3 := u2 * u
	return 0.5 * ((2.0 * b) + (c - a) * u + (2.0 * a - 5.0 * b + 4.0 * c - d) * u2 + (3.0 * b - a - 3.0 * c + d) * u3)


# un tubo por los puntos [centro, medio ancho (x), medio grosor] de pts, con cada sección perpendicular al camino
func cadena(mat: String, pts: Array, tapa0 := true, tapa1 := true) -> void:
	pts = subdividir(pts, 3)
	# las puntas cerradas en cúpula (una tapa plana del ancho del tubo se ve como una placa)
	for lado in ([0] if tapa0 else []) + ([1] if tapa1 else []):
		var j := 0 if lado == 0 else pts.size() - 1
		var o := 1 if lado == 0 else pts.size() - 2
		var dir: Vector3 = (pts[j][0] - pts[o][0]).normalized()
		var r := minf(pts[j][1], pts[j][2])
		var extra := [[pts[j][0] + dir * r * 0.45, pts[j][1] * 0.8, pts[j][2] * 0.8], [pts[j][0] + dir * r * 0.8, pts[j][1] * 0.42, pts[j][2] * 0.42]]
		if lado == 0:
			extra.reverse()
			pts = extra + pts
		else:
			pts = pts + extra
	var secs := []
	for i in pts.size():
		var c: Vector3 = pts[i][0]
		var d: Vector3 = (pts[mini(i + 1, pts.size() - 1)][0] - pts[maxi(i - 1, 0)][0]).normalized()
		var u := (Vector3.RIGHT - d * d.x).normalized()
		var v := d.cross(u).normalized()
		secs.append([c, u * float(pts[i][1]), v * float(pts[i][2])])
	loft(mat, secs, 16, 2.0, tapa0, tapa1)


# como el de peaton.gd, pero el pelo (y el adentro de las orejas) no lleva color: lleva en UV y UV2 las coordenadas de su
# dibujo y su zona (_zona), que pinta el pelaje (pelaje_perro.gdshader, pelaje_gata.gdshader); los ojos, nada (ojo.gdshader
# usa el vértice); lo demás, su color liso por vértice (tono()). _zona se lee aquí, no al agregar cada pieza: una pieza de
# otro color en el mismo hueso va con otro material
func terminar(padre: Node3D) -> void:
	var a_raiz := en_raiz(padre)
	var am := ArrayMesh.new()
	for k in _sup:
		var s: Array = _sup[k]
		var nv: int = s[0].size()
		var a := []
		a.resize(Mesh.ARRAY_MAX)
		a[Mesh.ARRAY_VERTEX] = s[0]
		a[Mesh.ARRAY_NORMAL] = s[1]
		a[Mesh.ARRAY_INDEX] = s[2]
		if k == "pelo" or k == "oido":
			var uv := PackedVector2Array()
			var uv2 := PackedVector2Array()
			uv.resize(nv)
			uv2.resize(nv)
			for i in nv:
				var v: Vector3 = s[0][i]
				var z: Vector4 = _zona.call(k, v, a_raiz * v)
				uv[i] = Vector2(z.x, z.y)
				uv2[i] = Vector2(z.z, z.w)
			a[Mesh.ARRAY_TEX_UV] = uv
			a[Mesh.ARRAY_TEX_UV2] = uv2
		elif k != "ojo":
			var cols := PackedColorArray()
			cols.resize(nv)
			cols.fill(tono(k))
			a[Mesh.ARRAY_COLOR] = cols
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
		am.surface_set_material(am.get_surface_count() - 1, mats[k])
	var mi := MeshInstance3D.new()
	mi.mesh = am
	padre.add_child(mi)
	_sup = {}


# el color liso de lo que no es pelo; el collar, el de colores (en los otros jugadores, su color de red.gd). Hasta
# noviembre de 2026 el collar era pelo con su propio color, que terminar() no alcanzaba a leer: salía café como el cuello
func tono(k: String) -> Color:
	if k == "collar":
		return Color(colores.get("collar", colores.get("polera", TONOS["collar"])))
	return Color(TONOS[k])


# la transformación de n en el marco del perro (sin pasar por la escena: sirve antes de agregarlo)
func en_raiz(n: Node3D) -> Transform3D:
	var x := Transform3D()
	while n != null and n != self:
		x = n.transform * x
		n = n.get_parent() as Node3D
	return x


# ---------------------------------------------------------------- las patas

# la pata i con la almohadilla en meta (en el marco del perro), el hueso de abajo a abajo rad de la vertical (+ hacia
# adelante, en el marco del perro) y la mano a dedos rad (0: plana): dos huesos de arriba por el teorema del coseno,
# con la rodilla adelante o el codo atrás
func pata(i: int, meta: Vector3, abajo: float, dedos: float) -> void:
	var p: Dictionary = patas[i]
	var n: Array = p["n"]
	var l: Array = p["l"]
	var top: Node3D = n[0]
	var marco := en_raiz(top.get_parent())
	var q := marco.affine_inverse() * meta - top.position
	var giro := atan2(marco.basis.y.z, marco.basis.y.y)  # cuánto está girado el marco de la pata en x
	var a3 := abajo - giro
	var w := Vector2(-q.z, q.y) - Vector2(sin(a3), -cos(a3)) * float(l[2])  # el carpo o el corvejón (adelante, arriba)
	var l1: float = l[0]
	var l2: float = l[1]
	var d := clampf(w.length(), absf(l1 - l2) + 0.005, l1 + l2 - 0.002)
	var alfa := atan2(w.x, -w.y)
	var beta := acos(clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0))
	var a1: float = alfa + float(p["s"]) * beta
	var m := Vector2(sin(a1), -cos(a1)) * l1
	var a2 := atan2(w.x - m.x, -(w.y - m.y))
	(n[0] as Node3D).rotation.x = a1
	(n[1] as Node3D).rotation.x = a2 - a1
	(n[2] as Node3D).rotation.x = a3 - a2
	(n[3] as Node3D).rotation.x = dedos - giro - a3


# ---------------------------------------------------------------- las poses

func animar(dt: float, rapidez: float, en_suelo: bool) -> void:
	t += dt
	t_caida += dt
	t_salto += dt
	t_golpe += dt
	patada *= exp(-16.0 * dt)
	if en_suelo:
		salto = 0
	var k := 1.0 - exp(-12.0 * dt)
	aire = lerpf(aire, 0.0 if en_suelo else 1.0, 1.0 - exp(-10.0 * dt))
	var mov := smoothstep(0.15, 1.0, rapidez)
	var trote := smoothstep(2.0, 5.0, rapidez)
	var galope := smoothstep(9.0, 14.0, rapidez)
	var frec := (0.9 + 0.32 * minf(rapidez, 8.0) + 0.04 * maxf(rapidez - 8.0, 0.0)) / sqrt(talla)  # ciclos por segundo
	if en_suelo:
		fase = fposmod(fase + dt * frec * smoothstep(0.02, 0.4, rapidez), 1.0)
	var duty := lerpf(lerpf(0.65, 0.5, trote), 0.38, galope)  # la parte del ciclo que cada pata pisa
	var largo := minf(rapidez * duty / frec, (lerpf(0.5, 0.6, trote) + 0.2 * galope) * talla) * mov
	var alto := lerpf(lerpf(0.05, 0.08, trote), 0.12, galope) * mov * talla
	# el tronco: el bote (dos por ciclo al paso y al trote, uno al galope), el cabeceo y el lomo que se dobla al galope
	var ciclo := TAU * fase
	var bote := ((-0.006 * (1.0 - trote) - 0.014 * trote * (1.0 - galope)) * cos(2.0 * ciclo) * mov + 0.03 * sin(ciclo) * galope) * talla
	var y := centro - (0.012 * trote + 0.02 * galope) * mov * talla + bote
	var cabeceo := 0.08 * cos(ciclo - TAU * 0.19) * galope
	var doblez := 0.15 * cos(ciclo - TAU * 0.63) * galope  # + encogido (el lomo arqueado), - estirado
	var ladeo := 0.03 * sin(ciclo) * mov * (1.0 - galope)
	# en el aire: encogido, estirado o en ovillo (con la voltereta), en el marco del tronco
	var u := clampf((t_salto - VUELTA_0) / VUELTA_T, 0.0, 1.0)
	var pose_aire := []
	var flex_aire := 0.4
	var cabeceo_aire := 0.3 * (1.0 - smoothstep(0.1, 0.6, t_salto)) - 0.2 * smoothstep(0.4, 1.0, t_salto)
	var doblez_aire := 0.0
	if salto == 2:
		pose_aire = [Vector3(0, -0.2, -0.56) * talla, Vector3(0, -0.26, 0.6) * talla]
		flex_aire = 0.0
		doblez_aire = -0.12
	elif salto == 3 and u < 0.92:
		pose_aire = [Vector3(0, -0.16, -0.18) * talla, Vector3(0, -0.17, 0.12) * talla]
		flex_aire = 1.0
		doblez_aire = 0.25
		cabeceo_aire = 0.0
	else:
		pose_aire = [Vector3(0, -0.25, -0.38) * talla, Vector3(0, -0.36, 0.42) * talla]
	if salto == 3:
		vuelta = -TAU * u * u * (3.0 - 2.0 * u)
	else:
		vuelta = lerpf(wrapf(vuelta, -PI, PI), 0.0, k)
	var sujeta := 0.0  # cuánto manda el arma sobre la cabeza
	if arma and salto != 3:
		sujeta = 1.0 if tipo_arma == "rifle" else maxf(alza, 0.35)
	tronco.position.y = lerpf(tronco.position.y, lerpf(y, centro, aire), k)
	tronco.position.z = lerpf(tronco.position.z, 0.0, k)
	inclinacion = lerpf(inclinacion, lerpf(cabeceo, cabeceo_aire, aire), k)
	tronco.rotation = Vector3(inclinacion + vuelta, 0.0, lerpf(tronco.rotation.z, ladeo * (1.0 - aire), k))
	var dz := lerpf(doblez, doblez_aire, aire)
	torso.rotation.x = lerpf(torso.rotation.x, -dz, k)
	cadera.rotation.x = lerpf(cadera.rotation.x, dz, k)
	var resp := 0.012 * sin(t * 11.0) * (1.0 - mov)  # el jadeo
	torso.scale = Vector3(1.0 + resp, 1.0 + resp, 1.0)
	# las patas: del paso al aire, en el marco del perro
	var al_tronco := tronco.transform
	var metas := []  # por pata: [dónde pisa, el ángulo del hueso de abajo, el de la mano] (pata())
	for i in 4:
		var desf: float = lerpf(lerpf(AL_PASO[i], AL_TROTE[i], trote), AL_GALOPE[i], galope)
		var w := fposmod(fase + desf, 1.0)
		var meta: Vector3 = pisada[i]
		var flex := 0.0
		if w < duty:
			meta.z += -largo * (0.5 - w / duty)
		else:
			var s := (w - duty) / (1.0 - duty)
			meta.z += largo * (0.5 - smoothstep(0.0, 1.0, s))
			meta.y += alto * sin(PI * s)
			flex = sin(PI * s) * mov
		var en_aire_: Vector3 = al_tronco * (Vector3(pisada[i].x, 0, 0) + pose_aire[0 if i < 2 else 1])
		meta = meta.lerp(en_aire_, aire)
		flex = lerpf(flex, flex_aire, aire)
		var adelante := i < 2
		var abajo: float = ANGULO_ABAJO[0 if adelante else 1] - (1.5 if adelante else 0.6) * flex
		metas.append([meta, abajo, -(0.9 if adelante else 0.5) * flex])
	postura(dt, metas)
	for i in 4:
		pata(i, metas[i][0], metas[i][1], metas[i][2])
	# el cuello y la cabeza: más bajos al correr, mirando alrededor quieto, hacia la mira con el arma; el tajo sacude
	var golpe := 0.0  # el tajo: la cabeza adelante y sacudiéndose (t_golpe es INF sin tajo: sin(INF) no es un número)
	var sacude := 0.0
	if tipo_arma == "cuchillo" and t_golpe < GOLPE + 0.1:
		golpe = 1.0 - smoothstep(0.0, GOLPE + 0.1, t_golpe)
		sacude = 0.55 * sin(t_golpe * 38.0) * golpe
	# en la voltereta, hecho ovillo, la cabeza metida hacia el pecho. La cabeza no sigue a vuelta: va de 0 a -2π, y
	# restarle la mitad (como hasta noviembre de 2026) la dejaba media vuelta girada, el hocico hacia atrás, al terminar
	var ovillo := aire * float(salto == 3 and u < 0.92)
	var mira_x := -0.25 * trote * mov + 0.1 * (1.0 - mov) - 0.4 * aire * float(salto == 2) - 0.45 * ovillo
	cuello.rotation.x = lerpf(cuello.rotation.x, mira_x - 0.35 * golpe, k)
	cuello.rotation.y = lerpf(cuello.rotation.y, 0.35 * sin(t * 0.37) * sin(t * 0.13) * (1.0 - mov) * (1.0 - sujeta) + sacude, k)
	var cab_x := 0.15 * trote * mov - 0.6 * cabeceo + mira * 0.7 * sujeta + patada * 0.8 - cabeceo_aire * aire * 0.5 - 0.5 * ovillo
	if recarga >= 0.0:
		cab_x -= 0.5 * smoothstep(0.0, 0.25, recarga) * (1.0 - smoothstep(0.75, 1.0, recarga))
	cabeza.rotation.x = lerpf(cabeza.rotation.x, cab_x, k)
	cabeza.rotation.z = lerpf(cabeza.rotation.z, 0.14 * sin(t * 0.5) * (1.0 - mov) * (1.0 - sujeta), k)
	# la boca: jadeando, más abierta al correr; cerrada sobre el arma
	var abre := lerpf(0.16 + 0.05 * sin(t * 11.0), 0.3, trote * mov)
	if arma:
		abre = 0.06
	mandibula.rotation.x = lerpf(mandibula.rotation.x, -abre, k)
	lengua.visible = arma == null
	lengua.rotation.y = 0.12 * sin(t * 7.0) * (trote + aire)
	var atras := 0.15 * trote * mov + 0.35 * galope + 0.6 * aire
	for j in 2:
		var o := orejas[j]
		o.rotation.x = lerpf(o.rotation.x, 0.15 + atras + 0.06 * sin(t * 0.9 + j * 2.0) * (1.0 - mov) + 0.08 * sin(2.0 * ciclo) * trote, k)
	# la cola: levantada y moviéndose quieto (contento), atrás y más quieta corriendo, estirada en el aire
	var meneo := 0.6 * (1.0 - mov) + 0.2 * mov * (1.0 - galope)
	var alza_cola := lerpf(lerpf(0.05, -0.08, mov), -0.2, maxf(galope, aire))
	for j in cola.size():
		var c := cola[j]
		var vel := 10.0 if mov < 0.5 else 6.0
		c.rotation.x = lerpf(c.rotation.x, alza_cola if j == 0 else -0.16 + 0.1 * mov, k)
		c.rotation.y = 0.5 * meneo * sin(t * vel - j * 0.8) + 0.12 * sin(ciclo) * trote * float(j == 0)
	ojos_animar(dt)
	boca_arma(dt)


# los ojos al final de animar(): el perro parpadea con los ojos abiertos; la gata los entorna echada y parpadea lento
func ojos_animar(dt: float) -> void:
	parpadear(dt, 1.0)


# un parpadeo cada 2 a 5 s (con lentos, a veces uno lento de 1,5 s, y más espaciados), con los ojos abiertos a ap (0
# cerrados … 1); muerto (tendido() en el último 0,2 s), cerrados
func parpadear(dt: float, ap: float, lentos := false) -> void:
	t_parpadeo -= dt
	if parpadeo < 0.0 and t_parpadeo <= 0.0:
		parpadeo = 0.0
		lento = lentos and _rng.randf() < 0.5
		t_parpadeo = _rng.randf_range(2.0, 5.0) * (1.6 if lentos else 1.0)
	if parpadeo >= 0.0:
		parpadeo += dt
		var u := parpadeo / (1.5 if lento else 0.18)
		ap *= 1.0 - smoothstep(0.0, 0.35, u) * (1.0 - smoothstep(0.6, 1.0, u))
		if u >= 1.0:
			parpadeo = -1.0
	if muerto():
		ap = 0.0
	for o in ojos:
		o.scale.y = maxf(ap, 0.06)


func muerto() -> bool:
	return caida > 0.0 and t_caida < 0.2


# después de calcular el paso y antes de resolver las patas: el tronco ya tiene su pose y metas, por pata, [dónde pisa,
# el ángulo del hueso de abajo, el de la mano] (pata()). El perro no cambia nada; gata.gd se sienta y se echa aquí
func postura(_dt: float, _metas: Array) -> void:
	pass


# el arma en el hocico: de lado (la pistola y el rifle) o atravesado (el cuchillo); en alto, la boca del arma hacia
# objetivo (o hacia la mira)
func boca_arma(_dt: float) -> void:
	if arma == null:
		return
	var de_lado := Basis(Vector3.BACK, PI / 2)  # la empuñadura entre los dientes, el arma hacia la izquierda
	var rep := Transform3D(de_lado * Basis(Vector3.RIGHT, -0.12), Vector3.ZERO)
	if tipo_arma == "cuchillo":
		rep = Transform3D(Basis(Vector3.UP, -PI / 2), Vector3(-0.03, 0, 0))  # la hoja hacia la derecha
		arma.transform = rep
		return
	if salto == 3 or not is_inside_tree():
		arma.transform = rep
		return
	var boca := hocico.global_position
	var dir := global_transform.basis * Vector3(0, sin(mira), -cos(mira))
	if objetivo != Vector3.INF and boca.distance_to(objetivo) > 2.5:
		var d := (objetivo - boca).normalized()
		if absf(d.y) < 0.99:
			dir = d
	var b := Basis.looking_at(dir, Vector3.UP) * de_lado * Basis(Vector3.RIGHT, patada)
	var alto_ := hocico.global_transform.affine_inverse() * Transform3D(b, boca)
	arma.transform = rep.interpolate_with(alto_, alza)


# En la bicicleta (vehiculo.gd pedalear()): sentado en el sillín, el tronco casi vertical, las manos en el manubrio y
# las patas de atrás estiradas hacia los pedales (no alcanzan: pies, en el marco de la cadera del ciclista, adelante y
# arriba). Se mezcla en ~0,1 s
func sentar(dt: float, pies: Array, incl: float, _hombros: float, _codos: float) -> void:
	t += dt
	var k := 1.0 - exp(-14.0 * dt)
	salto = 0
	vuelta = 0.0
	aire = 0.0
	var th := 0.95 - 0.8 * (incl - 0.62)  # de pie en los pedales (incl más), más echado adelante
	# la cadera (su articulación) sobre el sillín: a 0,97 m del pie del modelo
	var cad := Basis(Vector3.RIGHT, th) * Vector3(0, 0, 0.25)
	tronco.position = tronco.position.lerp(Vector3(0, 0.97, 0.02) - cad, k)
	inclinacion = lerpf(inclinacion, th, k)
	tronco.rotation = Vector3(inclinacion, 0.0, 0.0)
	torso.rotation.x = lerpf(torso.rotation.x, 0.0, k)
	cadera.rotation.x = lerpf(cadera.rotation.x, -0.15, k)
	torso.scale = Vector3.ONE
	for i in 2:
		pata(i, Vector3(PISADA[i].x, 0.985, -0.59), 0.6, 0.4)  # el manubrio: 0,59 m adelante y 0,985 arriba del sillín
		var p: Vector2 = pies[i]
		pata(i + 2, Vector3(PISADA[i + 2].x, 0.93 + p.y, -p.x), 0.3, 0.6)
	cuello.rotation.x = lerpf(cuello.rotation.x, -0.65, k)
	cuello.rotation.y = lerpf(cuello.rotation.y, 0.0, k)
	cabeza.rotation.x = lerpf(cabeza.rotation.x, -0.35, k)
	cabeza.rotation.z = lerpf(cabeza.rotation.z, 0.0, k)
	mandibula.rotation.x = lerpf(mandibula.rotation.x, -(0.24 + 0.04 * sin(t * 11.0)), k)
	lengua.visible = true
	for o in orejas:
		o.rotation.x = lerpf(o.rotation.x, 0.45, k)
	for j in cola.size():
		cola[j].rotation.x = lerpf(cola[j].rotation.x, 1.1 if j == 0 else 0.05, k)
		cola[j].rotation.y = 0.15 * sin(t * 6.0 - j * 0.8)
	parpadear(dt, 1.0)


# Con el jetpack en el aire (vehiculo.gd pose_vuelo()): estirado como un superhéroe, las manos adelante, las patas atrás,
# las orejas y la cola al viento y la lengua afuera
func volar(dt: float, inclinar: Vector3) -> void:
	t += dt
	var k := 1.0 - exp(-8.0 * dt)
	salto = 0
	vuelta = 0.0
	aire = 1.0
	tronco.position = tronco.position.lerp(Vector3(0, CENTRO + 0.1, 0), k)
	inclinacion = lerpf(inclinacion, 0.05, k)
	tronco.rotation = Vector3(inclinacion, 0.0, 0.0)
	torso.rotation.x = lerpf(torso.rotation.x, 0.06, k)
	cadera.rotation.x = lerpf(cadera.rotation.x, -0.06, k)
	torso.scale = Vector3.ONE
	var al_tronco := tronco.transform
	var vaiven := 0.03 * sin(t * 2.1)
	for i in 4:
		var meta: Vector3 = Vector3(0, -0.12 + vaiven, -0.6) if i < 2 else Vector3(0, -0.2 - vaiven, 0.62)
		meta.x = PISADA[i].x
		pata(i, al_tronco * meta, 0.0 if i < 2 else 0.4, 0.0)
	cuello.rotation.x = lerpf(cuello.rotation.x, -0.5, k)
	cuello.rotation.y = lerpf(cuello.rotation.y, 0.0, k)
	cabeza.rotation.x = lerpf(cabeza.rotation.x, 0.3 + inclinar.x * 0.7, k)
	cabeza.rotation.z = lerpf(cabeza.rotation.z, 0.0, k)
	mandibula.rotation.x = lerpf(mandibula.rotation.x, -0.3, k)
	lengua.visible = true
	lengua.rotation.y = 0.25 * sin(t * 17.0)
	for j in 2:
		orejas[j].rotation.x = 1.0 + 0.15 * sin(t * 19.0 + j)
	for j in cola.size():
		cola[j].rotation.x = lerpf(cola[j].rotation.x, -0.25 if j == 0 else 0.0, k)
		cola[j].rotation.y = 0.12 * sin(t * 13.0 - j * 1.1)
	parpadear(dt, 0.8)


# ---------------------------------------------------------------- lo que leen los demás

# muerto (jugador.gd, red.gd): de costado, desde las patas, y con los ojos cerrados (parpadear()); f de 0 (de pie) a 1
# (tendido)
func tendido(n: Node3D, f: float) -> void:
	caida = f
	t_caida = 0.0
	n.rotation.x = 0.0
	n.rotation.z = 1.5 * f
	n.position.y = 0.12 * f


func montura() -> Node3D:
	return lomo


func con_correas() -> bool:
	return false


func portabandera() -> Transform3D:
	return tronco.global_transform * Transform3D(Basis(Vector3.RIGHT, 0.35), Vector3(0.07, 0.06, 0.2))


# cabeza: adonde apunta la prueba de los tiros a la cabeza (red.gd apuntar(), --red-cabeza), en el marco del perro
func medidas() -> Dictionary:
	return {"ojo": 0.95, "etiqueta": 1.3, "radio": 0.26, "alto": 1.15, "cabeza": Vector3(0, 0.67, -0.53),
		"blanco": Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(0, 0.47, -0.08))}


# la cabeza (el doble de daño): adelante del pecho y sobre la cruz
func es_cabeza(p: Vector3) -> bool:
	return p.z < -0.36 and p.y > 0.5
