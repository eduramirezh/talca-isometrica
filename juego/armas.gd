# Las armas del personaje: un cuchillo (1), una pistola (2) y un rifle de asalto (3); el mismo número otra vez, o 0, la
# guarda. Clic izquierdo dispara (el rifle sigue mientras se aprieta, a su cadencia) o da un tajo; el botón derecho
# apunta: la cámara se corre al hombro derecho, se acerca y cierra el campo de visión; R recarga (también sola al
# apretar el gatillo con el cargador vacío). Los modelos, de modelos/entorno/armas.gd, en la mano derecha del peatón
# (peaton.gd sostener(): los brazos van al arma); los blancos, los muñecos de blancos.gd.
#
# El tiro: un rayo desde el centro de la cámara (la mira), con la dispersión del arma (un cono más ancho desde la cadera
# que apuntando, y más corriendo o en el aire), que empieza a la altura del personaje (lo que hay entre la cámara y él
# no cuenta) y no lo ve a él; si desde la boca del cañón el punto queda tapado (un muro al lado), el tiro da en lo que lo
# tapa. Lo golpeado cuyo cuerpo, o un ancestro, tiene recibir_dano(cantidad, punto, desde) recibe el daño (los muñecos;
# los otros jugadores de la red); en lo demás queda polvo (chispas en los autos) y, en lo fijo, una marca. El cuchillo
# corta a ALCANCE frente al pecho, en la dirección de la cámara, a los 0,12 s del golpe (cuando la hoja pasa).
# recibir_dano() devuelve el daño que tomó (0: ninguno, como un jugador recién reaparecido), y es más que `cantidad` si
# fue en la cabeza, que vale el doble (lo decide cada uno: blancos.gd CABEZA, red.gd el es_cabeza() de cada cuerpo): el tiro a la cabeza se
# nota en la X de la mira, más grande y dorada, en un tic metálico y en la cifra del daño, dorada.
# Efectos: fogonazo (una luz y un destello), trazadora, polvo o chispas, marcas (las últimas MARCAS), el retroceso de la
# cámara (sube y vuelve; un poco queda: hay que bajar el mouse en una ráfaga) y del arma, y sonidos hechos en código
# (sonidos(): ruido filtrado con envolventes, no hay archivos de audio).
#
# No se usa montado en un vehículo (el arma se guarda en la mano hasta bajar), con jugador.quieto (el mapa grande, la
# lista de lugares), con el mouse suelto (Esc: el clic que lo vuelve a tomar no dispara) ni muerto (si jugador.gd tiene
# `vida`), ni en la voltereta del triple salto.
#
#   var a := preload("res://armas.gd").new(); a.jugador = jugador; add_child(a)   # main.gd
#   a.elegir("rifle")      # 1, 2, 3; "" la guarda
#   await a.prueba(n)      # --disparar n [--apuntar] [--pausa s]: dispara n veces e imprime cada impacto
#
# En pantalla: la mira al centro (se abre con la dispersión; una X al acertar), y abajo a la derecha, sobre el mapa en
# miniatura (plano.gd), el arma, sus teclas, la munición y la recarga. Junto a lo que se hiere, la cifra del daño
# (cifra()): los golpes seguidos al mismo se suman en una sola, que sube y se apaga cuando paran.
#
# En la red (red.gd): cada tiro, tajo y corte sale por la señal accion, que red.gd manda a los otros jugadores para que
# vean el fogonazo (un Fogonazo por tirador), la trazadora y el polvo; los otros jugadores son un Area3D en CAPA_RED,
# que solo ven los rayos de aquí (rayo(), cortar()), y su recibir_dano() le avisa al herido por la red.
extends Node3D

# un tiro, tajo o corte propio, para red.gd: que es el arma («pistola», «rifle») o «tajo» (el golpe del cuchillo) o
# «corte» (la hoja que llega); a, la boca (o el pecho); b, donde pegó o se perdió; n, la normal ahí; col, el polvo;
# marcas: IMPACTO (pegó en algo), CHISPAS, MARCA (dejó una marca de bala)
signal accion(que: String, a: Vector3, b: Vector3, n: Vector3, col: Color, marcas: int)

const Args := preload("res://args.gd")
const Modelos := preload("res://modelos/entorno/armas.gd")
const Plano := preload("res://plano.gd")

# cada arma: dano (puntos de vida por impacto; los muñecos tienen 100 y la cabeza vale el doble), cadencia (s entre
# disparos o tajos), alcance (m desde el personaje), auto (sigue disparando mientras se aprieta), cargador (tiros),
# recarga (s), disp (grados del medio cono de dispersión: [desde la cadera, apuntando]), florece (grados que suma cada
# tiro seguido; se apagan en ~0,3 s), patada (rad que la cámara sube y vuelve), sube (rad que queda: la mira se va
# arriba en una ráfaga), brazos (rad que el arma salta en las manos, peaton.gd disparo()), fov (grados de la cámara
# apuntando; jugador.gd usa 70), fogonazo (m del destello)
const ARMAS := {
	"cuchillo": {"nombre": "Cuchillo", "dano": 50.0, "cadencia": 0.5, "alcance": 1.7, "auto": true},
	"pistola": {"nombre": "Pistola", "dano": 25.0, "cadencia": 0.16, "alcance": 150.0, "auto": false, "cargador": 15,
		"recarga": 1.5, "disp": [2.2, 0.35], "florece": 0.0, "patada": 0.035, "sube": 0.005, "brazos": 0.2, "fov": 52.0,
		"fogonazo": 0.32},
	"rifle": {"nombre": "Rifle de asalto", "dano": 20.0, "cadencia": 0.1, "alcance": 300.0, "auto": true, "cargador": 30,
		"recarga": 2.2, "disp": [3.0, 0.5], "florece": 0.3, "patada": 0.022, "sube": 0.0045, "brazos": 0.09, "fov": 40.0,
		"fogonazo": 0.42},
}
const ORDEN := ["cuchillo", "pistola", "rifle"]  # las teclas 1, 2 y 3 (acciones con esos nombres, main.gd acciones())
const MOVIMIENTO := 1.5  # la dispersión crece hasta (1 + esto) veces corriendo (jugador.CORRER)
const AIRE := 2.0  # y esto más en el aire
const HOMBRO := Vector3(0.7, -0.05, 0)  # m: el brazo de la cámara apuntando, corrido a la derecha (en el marco del yaw)
const LARGO_APUNTAR := 2.1  # m: el brazo de la cámara apuntando (si estaba más lejos)
const SACAR := 0.35  # s para sacar un arma o cambiarla: mientras, no dispara
const T_ALTO := 1.4  # s que el arma sigue en alto después de disparar sin apuntar
const ALZADA := 0.5  # el primer tiro desde la cadera sale cuando el arma va en la mitad del camino (~0,05 s)
const ESPERA := 0.25  # s que un clic espera su turno (la cadencia, el arma que sube) antes de perderse
const TAJO := 0.12  # s del golpe al corte (peaton.gd TAJO: la hoja pasa adelante)
const FOGONAZO := 0.05  # s
const VEL_TRAZA := 350.0  # m/s de la trazadora (una bala va a ~900: a esto se ve)
const LARGO_TRAZA := 4.0  # m
const MARCAS := 64  # las marcas de bala que quedan (las más viejas se reusan)
const POLVO := Color(0.66, 0.62, 0.55)
const CHISPA := Color(1.0, 0.78, 0.38)
const RELLENO := Color(0.82, 0.72, 0.5)  # el polvo de lo que se hiere y no dice el suyo (`polvo` del blanco)
const ORO := Color(1, 0.82, 0.3)  # la cabeza: la X de la mira y la cifra
const ROJO := Color(1, 0.25, 0.2)  # lo botó: la X de la mira
const CIFRA := 0.9  # s que dura la cifra del daño
const SUMA := 0.5  # s: un golpe al mismo blanco antes de esto se suma a su cifra (una ráfaga es un solo número)
const CAPA_RED := 1 << 19  # la capa 20: los otros jugadores de la red (red.gd), que solo ven los rayos de las armas
const IMPACTO := 1  # las marcas de accion
const CHISPAS := 2
const MARCA := 4

var jugador: CharacterBody3D
var tipo := ""  # el arma en la mano ("": ninguna)
var municion := {"pistola": ARMAS["pistola"]["cargador"], "rifle": ARMAS["rifle"]["cargador"]}  # en el cargador
var modelos := {}  # tipo -> Node3D (lo lleva peaton.gd en la mano)
var t_listo := 0.0  # s hasta que puede disparar otra vez
var t_recarga := 0.0  # s que faltan para terminar de recargar (0: no recarga)
var t_alto := 0.0  # s que el arma sigue en alto
var t_tajo := 0.0  # s hasta el corte del tajo en curso
var pendiente := 0.0  # s que el último clic sigue esperando su turno
var alza := 0.0  # 0 el arma abajo … 1 en alto (peaton.gd)
var k_mira := 0.0  # 0 … 1: la cámara apuntando
var gatillo := false  # el botón apretado en el cuadro de física anterior
var bloqueado := false  # el clic que vuelve a tomar el mouse no dispara
var florece := 0.0  # rad que suman los tiros seguidos
var patada := 0.0  # rad: el retroceso de la cámara
var objetivo := Vector3.INF  # el punto bajo la mira
var fov0 := 70.0
var fov_mira := 70.0
var libre := 5.0  # el brazo de la cámara que jugador.gd tendría (con la rueda)
var tocada := false  # la cámara está corrida o girada por el arma
var disparos := 0
var t_disparo := 0.0  # s de juego desde el último disparo o tajo
var congelar := -1.0  # congela el juego (Engine.time_scale 0) esto s de juego después del último tiro
var congelar_siguiente := -1.0  # prueba(): congelar, para el tiro que viene (el último)
var t_acierto := 0.0  # el marcador de acierto en la mira
var mato := false  # el último acierto lo botó (la X de la mira, roja)
var en_cabeza := false  # el último acierto fue en la cabeza (la X de la mira, más grande y dorada)
var prueba_on := false  # --disparar o --apuntar: sin el mouse tomado
var dibujado := false  # la mira o el tablero tenían algo el cuadro anterior

# los efectos
var fog: Fogonazo  # el fogonazo propio
var trazas := []  # [{"nodo", "a", "dir", "largo", "s" (m recorridos por la punta), "nueva"}]
var polvos: Array[CPUParticles3D] = []
var i_polvo := 0
var marcas: Array[MeshInstance3D] = []
var i_marca := 0
var cifras := []  # [Label3D, s desde el último golpe que sumó, id de lo herido, daño sumado], de la más vieja
var sonido := {}  # nombre -> AudioStreamPlayer
var mira_ui: Control
var tablero: Control
var efecto := [RELLENO, 0]  # lo que dejó el último impacto(): [el color del polvo, las marcas de accion]

static var _sonidos := {}
static var _mat_fogonazo := {}  # los materiales del fogonazo, una vez para todos los tiradores


# el fogonazo de un tirador (el propio y uno por cada otro jugador de la red): una luz, un destello de frente y la llama
# de costado, por FOGONAZO s desde el cuadro siguiente al primero en que se dibujó (a pocos cuadros por segundo FOGONAZO
# es menos que un cuadro, y el cuadro del tiro trae el tiempo de antes, aunque prueba() congele); fogonazo_nuevo() lo arma
class Fogonazo extends Node3D:
	var luz := OmniLight3D.new()
	var destello := MeshInstance3D.new()
	var cono := MeshInstance3D.new()
	var t := 0.0
	var visto := false

	func encender(p: Vector3, dir: Vector3, tam: float, dura: float) -> void:
		t = dura
		visto = false
		luz.global_position = p + dir * 0.15
		luz.visible = true
		destello.global_position = p + dir * tam * 0.3
		destello.scale = Vector3.ONE * tam * randf_range(0.8, 1.25)
		destello.visible = true
		var up := Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT
		var b := Basis.looking_at(dir, up).rotated(dir, randf() * PI)
		cono.global_transform = Transform3D(b.scaled_local(Vector3(tam * 0.55, tam * 0.55, tam * randf_range(1.2, 1.8))), p)
		cono.visible = true

	func _process(dt: float) -> void:
		if not luz.visible:
			return
		if visto:
			t -= dt
		visto = true
		if t <= 0.0:
			luz.visible = false
			destello.visible = false
			cono.visible = false


class Mira extends Control:
	var armas: Node

	func _draw() -> void:
		armas.dibujar_mira(self)


class Tablero extends Control:
	var armas: Node

	func _draw() -> void:
		armas.dibujar_tablero(self)


func _ready() -> void:
	name = "armas"
	process_priority = 10  # después de jugador.gd: la cámara y el cuerpo se corrigen sobre lo que dejó
	process_physics_priority = 10
	modelos = {"cuchillo": Modelos.cuchillo(), "pistola": Modelos.pistola(), "rifle": Modelos.rifle()}
	fov0 = jugador.cam.fov
	libre = jugador.largo
	efectos_nuevos()
	hud()
	for k in sonidos():
		var p := AudioStreamPlayer.new()
		p.stream = sonidos()[k]
		p.max_polyphony = 6 if k in ["pistola", "rifle"] else 2
		p.volume_db = -5.0 if k in ["pistola", "rifle"] else -9.0
		add_child(p)
		sonido[k] = p
	prueba_on = Args.has("--disparar") or Args.has("--apuntar")
	if Args.has("--arma"):
		elegir(Args.texto("--arma"))
		t_listo = 0.0
	if Args.has("--apuntar"):
		Input.action_press("apuntar")


func _exit_tree() -> void:
	for k in modelos:
		if is_instance_valid(modelos[k]) and modelos[k].get_parent() == null:
			modelos[k].free()


# ---------- elegir, recargar, cuándo se puede ----------

func elegir(t: String) -> void:
	if t != "" and not ARMAS.has(t):
		push_warning("armas.gd: no hay arma «%s» (cuchillo, pistola o rifle)" % t)
		return
	if t == tipo:
		return
	tipo = t
	t_recarga = 0.0
	t_listo = SACAR
	t_alto = 0.0
	t_tajo = 0.0
	pendiente = 0.0
	florece = 0.0
	if t != "":
		sonar("sacar")


func recargar() -> void:
	var a: Dictionary = ARMAS.get(tipo, {})
	if not a.has("cargador") or t_recarga > 0.0 or municion[tipo] >= a["cargador"] or not lleva():
		return
	t_recarga = a["recarga"]
	pendiente = 0.0
	sonar("recarga")


func muerto() -> bool:
	return "vida" in jugador and jugador.vida <= 0


# el arma está en la mano (no montado, no muerto)
func lleva() -> bool:
	return tipo != "" and jugador.vehiculo == null and not muerto()


# y se puede usar
func puede() -> bool:
	if not lleva() or jugador.quieto:
		return false
	if not prueba_on and jugador.mouse and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return false
	return jugador.peaton.salto != 3  # la voltereta


func _input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		# _input va antes que jugador.gd, que con este clic toma el mouse: ese clic no dispara
		bloqueado = e.pressed and jugador != null and jugador.mouse and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED


func _unhandled_input(e: InputEvent) -> void:
	if jugador == null or jugador.quieto or e.is_echo() or not e.is_pressed():
		return
	for t in ORDEN:
		if e.is_action_pressed(t):
			elegir("" if t == tipo else t)
			get_viewport().set_input_as_handled()
			return
	if e.is_action_pressed("guardar"):
		elegir("")
		get_viewport().set_input_as_handled()
	elif e.is_action_pressed("recargar"):
		recargar()
		get_viewport().set_input_as_handled()


# ---------- cada cuadro ----------

func _physics_process(dt: float) -> void:
	if jugador == null or dt <= 0.0:  # congelado (prueba(), Engine.time_scale 0): ni el punto de la mira cambia
		return
	t_disparo += dt
	if congelar >= 0.0 and t_disparo >= congelar:
		Engine.time_scale = 0.0
		congelar = -1.0
	t_listo = maxf(t_listo - dt, 0.0)
	t_alto = maxf(t_alto - dt, 0.0)
	pendiente = maxf(pendiente - dt, 0.0)
	florece *= exp(-10.0 * dt)
	if t_recarga > 0.0:
		t_recarga -= dt
		if t_recarga <= 0.0:
			t_recarga = 0.0
			municion[tipo] = ARMAS[tipo]["cargador"]
			sonar("recarga")
	if t_tajo > 0.0:
		t_tajo -= dt
		if t_tajo <= 0.0:
			cortar()
	var dedo := Input.is_action_pressed("disparar") and not bloqueado
	var nuevo := dedo and not gatillo
	gatillo = dedo
	objetivo = apuntado() if lleva() else Vector3.INF
	if not puede():
		pendiente = 0.0
		return
	var a: Dictionary = ARMAS[tipo]
	if nuevo:
		pendiente = ESPERA
	if (dedo or pendiente > 0.0) and tipo != "cuchillo":
		t_alto = maxf(t_alto, T_ALTO)  # el arma sube para el tiro
	if alza > 0.05 or k_mira > 0.05 or t_alto > 0.0:  # el cuerpo mira hacia donde apunta la cámara
		jugador.cuerpo.rotation.y = lerp_angle(jugador.cuerpo.rotation.y, jugador.yaw, 1.0 - exp(-20.0 * dt))
	if t_listo > 0.001 or t_recarga > 0.0:  # con tolerancia: 0,1 s son seis cuadros de física, no siete
		return
	if tipo != "cuchillo" and alza < ALZADA:
		return
	if pendiente > 0.0 or (dedo and a["auto"]):
		pendiente = 0.0
		disparar()


func _process(dt: float) -> void:
	if jugador == null:
		return
	var j := jugador
	var pe: Node3D = j.peaton
	var en_mano := lleva()
	pe.sostener(tipo if en_mano else "", modelos.get(tipo))
	var mirando := en_mano and tipo != "cuchillo" and puede() and Input.is_action_pressed("apuntar")
	k_mira = lerpf(k_mira, 1.0 if mirando else 0.0, 1.0 - exp(-12.0 * dt))
	if mirando:
		fov_mira = ARMAS[tipo]["fov"]
	var meta := 1.0 if en_mano and tipo != "cuchillo" and (mirando or t_alto > 0.0) else 0.0
	if t_recarga > 0.0:
		meta = 0.45 if tipo == "pistola" else 0.0  # la pistola frente al pecho; el rifle bajo, con el cargador a mano
	alza = lerpf(alza, meta, 1.0 - exp(-(14.0 if meta > alza else 8.0) * dt))
	pe.alza = alza
	pe.mira = j.pitch
	pe.objetivo = objetivo
	pe.recarga = 1.0 - t_recarga / ARMAS[tipo]["recarga"] if t_recarga > 0.0 else -1.0
	camara(dt)
	efectos(dt)
	t_acierto = maxf(t_acierto - dt, 0.0)
	if en_mano or dibujado:  # sin arma, una vez para borrarlos
		mira_ui.queue_redraw()
		tablero.queue_redraw()
	dibujado = en_mano


# la cámara apuntando: el brazo de jugador.gd corrido al hombro derecho, más corto y con menos campo de visión, y el
# retroceso; jugador.gd la deja cada cuadro antes que esto (process_priority), así que se corrige encima
func camara(dt: float) -> void:
	var j := jugador
	patada = lerpf(patada, 0.0, 1.0 - exp(-14.0 * dt))
	if j.vehiculo:  # vehiculo.gd lleva la cámara
		libre = j.brazo.spring_length
		k_mira = 0.0
		if tocada:
			j.cam.fov = fov0
			tocada = false
		return
	libre = lerpf(libre, j.largo, 0.2)  # lo que hace jugador.gd largo_actual(), sin lo de este cuadro
	if k_mira < 0.002 and absf(patada) < 0.0005:
		if tocada:
			j.brazo.position = Vector3(0, j.ojo(), 0)
			j.brazo.spring_length = libre
			j.cam.fov = fov0
			tocada = false
		return
	tocada = true
	var cerca := clampf(libre / 1.5, 0.0, 1.0)  # en primera persona no se corre al hombro
	j.brazo.position = Vector3(0, j.ojo(), 0) + Basis(Vector3.UP, j.yaw) * (HOMBRO * k_mira * cerca)
	j.brazo.spring_length = lerpf(libre, minf(libre, LARGO_APUNTAR), k_mira)
	j.cam.fov = lerpf(fov0, fov_mira, k_mira)
	j.brazo.rotation.x += patada


# ---------- el tiro ----------

func disparar() -> void:
	if tipo == "cuchillo":
		acuchillar()
		return
	var a: Dictionary = ARMAS[tipo]
	if municion[tipo] <= 0:
		sonar("vacio")
		recargar()
		return
	municion[tipo] -= 1
	disparos += 1
	t_disparo = 0.0
	congelar = congelar_siguiente
	congelar_siguiente = -1.0
	t_listo = a["cadencia"]
	t_alto = T_ALTO
	var cam: Camera3D = jugador.cam
	var dir := desviar(-cam.global_basis.z, dispersion())
	var o := desde_jugador(cam.global_position, dir)
	var fin := o + dir * float(a["alcance"])
	var r := rayo(o, fin)
	var boca := boca_global()
	if r:
		var r2 := rayo(boca, r.position + (r.position - boca).normalized() * 0.05)
		if r2 and r2.position.distance_to(r.position) > 0.1:  # tapado desde el cañón
			r = r2
		fin = r.position
	fogonazo(boca, (fin - boca).normalized(), a["fogonazo"])
	trazadora(boca, fin)
	sonar(tipo)
	patada += a["patada"]
	jugador.pitch = clampf(jugador.pitch + a["sube"] * randf_range(0.6, 1.0), -1.45, 1.2)
	jugador.yaw += a["sube"] * randf_range(-0.5, 0.5)
	jugador.peaton.disparo(a["brazos"])
	florece += deg_to_rad(a["florece"])
	var dice := "nada a menos de %d m" % a["alcance"]
	efecto = [RELLENO, 0]
	if r:
		dice = impacto(r, a["dano"], boca)
	accion.emit(tipo, boca, fin, r["normal"] if r else Vector3.UP, efecto[0], efecto[1])
	if prueba_on:
		informar("disparo %d (%s, %d en el cargador): %s" % [disparos, tipo, municion[tipo], dice])
	if congelar == 0.0:  # en este mismo cuadro: el fogonazo y la trazadora recién puestos
		Engine.time_scale = 0.0
		congelar = -1.0


# el tajo: el golpe ahora (peaton.gd golpear()), el corte cuando la hoja pasa (cortar())
func acuchillar() -> void:
	t_listo = ARMAS["cuchillo"]["cadencia"]
	t_alto = 0.5
	t_tajo = TAJO
	disparos += 1
	t_disparo = 0.0
	congelar = congelar_siguiente
	congelar_siguiente = -1.0
	jugador.peaton.golpear()
	sonar("tajo")
	var pecho := jugador.global_position + Vector3.UP * 1.25
	accion.emit("tajo", pecho, pecho, Vector3.UP, RELLENO, 0)


func cortar() -> void:
	if not lleva() or tipo != "cuchillo":
		return
	var a: Dictionary = ARMAS["cuchillo"]
	var adelante := Vector3.FORWARD.rotated(Vector3.UP, jugador.yaw)  # hacia donde mira la cámara, horizontal
	var pecho := jugador.global_position + Vector3.UP * 1.25
	var esp := get_world_3d().direct_space_state
	var r := rayo(pecho, pecho + adelante * float(a["alcance"]))
	var quien: Node = null
	if r:
		quien = receptor(r.collider)
	if quien == null:  # el rayo es fino: lo que se puede herir dentro de una esfera frente al pecho
		var q := PhysicsShapeQueryParameters3D.new()
		var s := SphereShape3D.new()
		s.radius = 0.55
		q.shape = s
		q.transform = Transform3D(Basis(), pecho + adelante * (float(a["alcance"]) - 0.55))
		q.exclude = [jugador.get_rid()]
		var tocados := esp.intersect_shape(q, 8)
		q.collide_with_bodies = false  # y los otros jugadores de la red (red.gd), que solo ven las armas
		q.collide_with_areas = true
		q.collision_mask = CAPA_RED
		tocados.append_array(esp.intersect_shape(q, 8))
		for h in tocados:
			var n := receptor(h["collider"])
			if n:
				var d := pecho.distance_to((n as Node3D).global_position + Vector3.UP * 1.25)
				var p: Vector3 = pecho + adelante * minf(float(a["alcance"]), d)
				r = {"collider": h["collider"], "position": p, "normal": -adelante}
				break
	var dice := "al aire"
	if r:
		efecto = [RELLENO, 0]
		dice = impacto(r, a["dano"], pecho, false)
		accion.emit("corte", pecho, r["position"], r["normal"], efecto[0], efecto[1])
	if prueba_on:
		informar("tajo %d: %s" % [disparos, dice])


# lo que pasa donde pega: el daño (recibir_dano), el polvo o las chispas, la marca (de una bala: el cuchillo saca
# chispas), el sonido, la X de la mira y la cifra; devuelve qué fue
func impacto(r: Dictionary, dano: float, desde: Vector3, bala := true) -> String:
	var col: Object = r["collider"]
	var p: Vector3 = r["position"]
	var n: Vector3 = r["normal"]
	var d := desde.distance_to(p)
	var quien := receptor(col)
	if quien:
		var antes = quien.get("vida")  # si lo dice (los muñecos), para la prueba y la X roja de la mira
		var tomo = quien.recibir_dano(dano, p, desde)  # si lo dice, el daño que tomó: más que dano, en la cabeza
		var c = quien.get("polvo")
		efecto = [c if c is Color else RELLENO, IMPACTO]
		levantar(p, n, efecto[0], false)
		sonar("golpe")
		var despues = quien.get("vida")
		if antes is float and antes <= 0.0:
			return "«%s» a %.1f m, ya en el suelo" % [quien.name, d]
		if tomo is float and tomo <= 0.0:
			return "«%s» a %.1f m, sin daño" % [quien.name, d]
		mato = antes is float and despues is float and despues <= 0.0
		en_cabeza = tomo is float and tomo > dano
		t_acierto = 0.3
		if tomo is float:
			cifra(quien, p, tomo, en_cabeza)
		if en_cabeza:
			sonar("cabeza")
		var vida := "" if not despues is float else ", vida %.0f → %.0f%s" % [antes, despues, " (cae)" if mato else ""]
		return "«%s» a %.1f m, %.0f de daño%s%s" % [quien.name, d, tomo if tomo is float else dano,
			" en la cabeza" if en_cabeza else "", vida]
	var nombre := nombre_de(col)
	var metal := col is CharacterBody3D or nombre.begins_with("autos") or not bala
	levantar(p, n, CHISPA if metal else POLVO, metal)
	efecto = [CHISPA if metal else POLVO, IMPACTO | (CHISPAS if metal else 0)]
	if bala and col is StaticBody3D and not metal and nombre != "limite":
		marcar(p, n)
		efecto[1] |= MARCA
	return "«%s» a %.1f m" % [nombre, d]


# el nodo que recibe el daño: el cuerpo golpeado o el primero de sus ancestros con recibir_dano()
static func receptor(col: Object) -> Node:
	var n := col as Node
	while n:
		if n.has_method("recibir_dano"):
			return n
		n = n.get_parent()
	return null


# el nombre de lo golpeado: la capa del mapa (mapa.gd pone su colisión, «colision», bajo la malla de la capa) o el suyo
static func nombre_de(col: Object) -> String:
	var n := col as Node
	if n == null:
		return "?"
	if n.name == "colision" and n.get_parent():
		return String(n.get_parent().name)
	return String(n.name)


# lo primero entre a y b: los cuerpos (el mapa, los autos, los muñecos) y los otros jugadores de la red (un Area3D en
# CAPA_RED, red.gd), en dos consultas: con collide_with_areas en la primera, cualquier otra área taparía los tiros
func rayo(a: Vector3, b: Vector3) -> Dictionary:
	var esp := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(a, b)
	q.exclude = [jugador.get_rid()]
	var r := esp.intersect_ray(q)
	q.collide_with_bodies = false
	q.collide_with_areas = true
	q.collision_mask = CAPA_RED
	var o := esp.intersect_ray(q)
	if o and (r.is_empty() or a.distance_squared_to(o["position"]) < a.distance_squared_to(r["position"])):
		return o
	return r


# el rayo de la cámara empieza a la altura del personaje: lo que queda entre la cámara y él no se puede herir
func desde_jugador(o: Vector3, dir: Vector3) -> Vector3:
	var pecho := jugador.global_position + Vector3.UP * 1.4
	return o + dir * maxf(0.0, (pecho - o).dot(dir))


# el punto bajo la mira (el arma en alto lo apunta: peaton.gd en_alto())
func apuntado() -> Vector3:
	var cam: Camera3D = jugador.cam
	var dir := -cam.global_basis.z
	var o := desde_jugador(cam.global_position, dir)
	var r := rayo(o, o + dir * 300.0)
	return r["position"] if r else o + dir * 300.0


func boca_global() -> Vector3:
	var m: Node3D = modelos[tipo]
	var b := m.get_node_or_null("boca") as Node3D
	return b.global_position if b and m.is_inside_tree() else jugador.global_position + Vector3.UP * 1.4


# rad del medio cono: el del arma, entre la cadera y la mira, más corriendo y en el aire, más lo que florece
func dispersion() -> float:
	var a: Dictionary = ARMAS.get(tipo, {})
	if not a.has("disp"):
		return 0.0
	var d: float = lerpf(a["disp"][0], a["disp"][1], k_mira)
	var v := Vector2(jugador.velocity.x, jugador.velocity.z).length()
	d *= 1.0 + MOVIMIENTO * clampf(v / jugador.CORRER, 0.0, 1.0) + (0.0 if jugador.is_on_floor() else AIRE)
	return deg_to_rad(d) + florece


# una dirección al azar dentro del cono de medio ángulo `ang` alrededor de dir (uniforme en el disco)
static func desviar(dir: Vector3, ang: float) -> Vector3:
	if ang <= 0.0:
		return dir
	var u := dir.cross(Vector3.UP if absf(dir.y) < 0.9 else Vector3.RIGHT).normalized()
	var v := dir.cross(u)
	var r := ang * sqrt(randf())
	var t := randf() * TAU
	return (dir * cos(r) + (u * cos(t) + v * sin(t)) * sin(r)).normalized()


# ---------- los efectos ----------

func efectos_nuevos() -> void:
	fog = fogonazo_nuevo()
	add_child(fog)
	# las trazadoras
	var caja := BoxMesh.new()
	caja.size = Vector3.ONE
	var mtz := StandardMaterial3D.new()
	mtz.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mtz.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mtz.albedo_color = Color(1.0, 0.82, 0.5)
	for i in 10:
		var tz := MeshInstance3D.new()
		tz.mesh = caja
		tz.material_override = mtz
		tz.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		tz.visible = false
		add_child(tz)
		trazas.append({"nodo": tz, "a": Vector3.ZERO, "dir": Vector3.FORWARD, "largo": 0.0, "s": INF, "nueva": false})
	# el polvo y las chispas
	var mp := StandardMaterial3D.new()
	mp.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mp.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mp.billboard_keep_scale = true  # sin esto, cada partícula mide lo que el QuadMesh (1 m)
	mp.vertex_color_use_as_albedo = true
	mp.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mp.albedo_texture = textura_punto()
	var qp := QuadMesh.new()
	qp.size = Vector2.ONE
	qp.material = mp
	var desvanece := Gradient.new()
	desvanece.set_color(0, Color(1, 1, 1, 1))
	desvanece.set_color(1, Color(1, 1, 1, 0))
	for i in 12:
		var e := CPUParticles3D.new()
		e.mesh = qp
		e.emitting = false
		e.one_shot = true
		e.amount = 14
		e.lifetime = 0.55
		e.explosiveness = 1.0
		e.local_coords = false
		e.direction = Vector3.UP
		e.spread = 35.0
		e.gravity = Vector3(0, -9.8, 0)
		e.initial_velocity_min = 1.0
		e.initial_velocity_max = 3.5
		e.damping_min = 2.0
		e.damping_max = 4.0
		e.scale_amount_min = 0.03
		e.scale_amount_max = 0.08
		e.color_ramp = desvanece
		add_child(e)
		polvos.append(e)
	# las marcas: un agujero con su quemadura, en lo fijo
	var qm := QuadMesh.new()
	qm.size = Vector2(0.09, 0.09)
	var mm := StandardMaterial3D.new()
	mm.albedo_texture = textura_marca()
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mm.roughness = 1.0
	for i in MARCAS:
		var m := MeshInstance3D.new()
		m.mesh = qm
		m.material_override = mm
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.visibility_range_end = 60.0
		m.visible = false
		add_child(m)
		marcas.append(m)


# un fogonazo para un tirador (este o un jugador de la red: red.gd), con los materiales de todos
static func fogonazo_nuevo() -> Fogonazo:
	if _mat_fogonazo.is_empty():
		_mat_fogonazo["destello"] = brillo(textura_destello(), BaseMaterial3D.BILLBOARD_ENABLED)
		_mat_fogonazo["llama"] = brillo(textura_llama(), BaseMaterial3D.BILLBOARD_DISABLED)
		# la llama de costado: dos tarjetas cruzadas a lo largo del cañón (el destello se ve de frente; esto, de lado)
		var am := ArrayMesh.new()
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for giro in [0.0, PI / 2]:
			var b := Basis(Vector3.BACK, giro)
			var pts := [Vector3(-0.5, 0, 0), Vector3(0.5, 0, 0), Vector3(0.5, 0, -1), Vector3(-0.5, 0, -1)]
			var uv := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
			for k in [0, 1, 2, 0, 2, 3]:
				st.set_uv(uv[k])
				st.add_vertex(b * pts[k])
		st.commit(am)
		_mat_fogonazo["cono"] = am
		var q := QuadMesh.new()
		q.size = Vector2.ONE
		_mat_fogonazo["quad"] = q
	var f := Fogonazo.new()
	f.name = "fogonazo"
	f.luz.light_color = Color(1.0, 0.78, 0.45)
	f.luz.omni_range = 7.0
	f.luz.light_energy = 5.0
	f.luz.shadow_enabled = false
	f.luz.visible = false
	f.add_child(f.luz)
	f.destello.mesh = _mat_fogonazo["quad"]
	f.destello.material_override = _mat_fogonazo["destello"]
	f.destello.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	f.destello.visible = false
	f.add_child(f.destello)
	f.cono.mesh = _mat_fogonazo["cono"]
	f.cono.material_override = _mat_fogonazo["llama"]
	f.cono.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	f.cono.visible = false
	f.add_child(f.cono)
	return f


static func brillo(tex: Texture2D, cartel: int) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.billboard_mode = cartel
	m.billboard_keep_scale = true  # el destello se escala con el arma
	m.albedo_texture = tex
	return m


func fogonazo(p: Vector3, dir: Vector3, tam: float) -> void:
	fog.encender(p, dir, tam, FOGONAZO)


func trazadora(a: Vector3, b: Vector3) -> void:
	var largo := a.distance_to(b)
	if largo < 1.0:
		return
	var libre_: Dictionary = trazas[0]
	for tz in trazas:  # una libre, o la más avanzada
		if tz["s"] - LARGO_TRAZA >= tz["largo"]:
			libre_ = tz
			break
		if tz["s"] > libre_["s"]:
			libre_ = tz
	libre_["a"] = a
	libre_["dir"] = (b - a) / largo
	libre_["largo"] = largo
	libre_["s"] = VEL_TRAZA / 120.0  # medio cuadro a 60 por segundo ya recorrido
	libre_["nueva"] = true


func levantar(p: Vector3, n: Vector3, col: Color, chispas: bool) -> void:
	var e := polvos[i_polvo]
	i_polvo = (i_polvo + 1) % polvos.size()
	var b := Basis(Vector3.RIGHT, PI) if n.dot(Vector3.UP) < -0.999 else Basis(Quaternion(Vector3.UP, n.normalized()))
	e.global_transform = Transform3D(b, p + n * 0.03)
	e.color = col
	e.initial_velocity_min = 2.5 if chispas else 1.0
	e.initial_velocity_max = 6.0 if chispas else 3.0
	e.lifetime = 0.3 if chispas else 0.55
	e.scale_amount_max = 0.05 if chispas else 0.09
	e.restart()


func marcar(p: Vector3, n: Vector3) -> void:
	var m := marcas[i_marca]
	i_marca = (i_marca + 1) % marcas.size()
	var up := Vector3.UP if absf(n.y) < 0.95 else Vector3.FORWARD
	m.global_transform = Transform3D(Basis.looking_at(-n, up).rotated(n, randf() * TAU), p + n * 0.012)
	m.visible = true


func efectos(dt: float) -> void:
	for tz in trazas:
		var nodo: MeshInstance3D = tz["nodo"]
		var largo: float = tz["largo"]
		var s: float = tz["s"]
		var cola := maxf(0.0, s - LARGO_TRAZA)
		if cola >= largo:
			nodo.visible = false
			continue
		var cabeza := minf(s, largo)
		var dir: Vector3 = tz["dir"]
		var up := Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT
		nodo.global_transform = Transform3D(Basis.looking_at(dir, up).scaled_local(Vector3(0.022, 0.022, cabeza - cola)),
			tz["a"] + dir * (cabeza + cola) / 2.0)
		nodo.visible = cabeza - cola > 0.01
		if tz["nueva"]:  # como el fogonazo: el primer cuadro se ve donde partió
			tz["nueva"] = false
		else:
			tz["s"] = s + VEL_TRAZA * dt
	var ojo: Vector3 = jugador.cam.global_position
	for c in cifras:  # suben lo mismo en pantalla cerca y lejos (son de tamaño fijo): ~0,35 m/s a 7 m
		var l: Label3D = c[0]
		c[1] += dt
		l.global_position.y += 0.05 * maxf(ojo.distance_to(l.global_position), 3.0) * dt
		l.modulate.a = clampf((CIFRA - c[1]) / 0.4, 0.0, 1.0)
		l.outline_modulate.a = 0.8 * l.modulate.a
	while not cifras.is_empty() and cifras[0][1] > CIFRA:
		cifras.pop_front()[0].queue_free()


# el daño de un acierto a quien: una cifra de frente a la cámara, a la vista a través de todo, a la derecha del impacto
# (encima van su nombre o su barra de vida); blanca, o más grande y dorada en la cabeza. Un golpe al mismo antes de SUMA
# s se suma a la suya, que salta a este impacto; sube y se apaga en CIFRA s (efectos())
func cifra(quien: Node, p: Vector3, dano: float, cabeza: bool) -> void:
	var id := quien.get_instance_id()
	var total := dano
	var l: Label3D = null
	for c in cifras:
		if c[2] == id and c[1] < SUMA:
			l = c[0]
			total += c[3]
			cifras.erase(c)  # vuelve al final, como la más nueva
			break
	if l == null:
		l = Label3D.new()
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.fixed_size = true  # a 50 m se lee igual que a 5
		l.no_depth_test = true
		l.pixel_size = 0.0006
		l.outline_size = 12
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT  # empieza donde se pone: a la derecha del impacto
		l.top_level = true
		add_child(l)
	l.text = "%d" % roundi(total)
	l.font_size = 56 if cabeza else 44
	l.modulate = ORO if cabeza else Color(1, 1, 1)
	l.outline_modulate = Color(0, 0, 0, 0.8)
	# el corrimiento crece con la distancia, como el tamaño fijo: en pantalla es el mismo
	var cam: Camera3D = jugador.cam
	var k := maxf(cam.global_position.distance_to(p), 3.0) / 7.0
	l.global_position = p + (cam.global_basis.x * 0.25 + Vector3.UP * 0.05) * k
	cifras.append([l, 0.0, id, total])


# ---------- texturas y sonidos hechos en código ----------

static func imagen(n: int, f: Callable) -> ImageTexture:
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			img.set_pixel(x, y, f.call((x + 0.5) / n * 2.0 - 1.0, (y + 0.5) / n * 2.0 - 1.0))
	return ImageTexture.create_from_image(img)


# el destello de frente: una estrella de seis puntas con el centro blanco
static func textura_destello() -> ImageTexture:
	return imagen(64, func(x: float, y: float) -> Color:
		var r := Vector2(x, y).length()
		var puntas := pow(absf(cos(atan2(y, x) * 3.0)), 5.0) * pow(clampf(1.0 - r, 0.0, 1.0), 1.3)
		var v := clampf(exp(-r * r * 10.0) * 1.4 + puntas, 0.0, 1.0)
		return Color(1.0, 0.75 + 0.25 * v, 0.4 + 0.6 * v * v, v))


# la llama de costado: una lengua que se angosta hacia la punta (v = 0)
static func textura_llama() -> ImageTexture:
	return imagen(64, func(x: float, y: float) -> Color:
		var u := (1.0 - y) / 2.0  # 0 en la boca, 1 en la punta
		var ancho := 0.55 * pow(1.0 - u, 0.8) + 0.02
		var v := clampf(1.0 - absf(x) / ancho, 0.0, 1.0) * clampf(1.0 - u, 0.0, 1.0)
		v = pow(v, 0.7)
		return Color(1.0, 0.7 + 0.3 * v, 0.35 + 0.5 * v, v))


static func textura_punto() -> ImageTexture:
	return imagen(16, func(x: float, y: float) -> Color:
		return Color(1, 1, 1, clampf(1.0 - Vector2(x, y).length(), 0.0, 1.0)))


# la marca de bala: el agujero negro y un halo de quemadura que se desvanece
static func textura_marca() -> ImageTexture:
	return imagen(32, func(x: float, y: float) -> Color:
		var r := Vector2(x, y).length()
		if r < 0.28:
			return Color(0.03, 0.03, 0.03, 1.0)
		return Color(0.12, 0.1, 0.09, clampf((1.0 - r) / 0.72, 0.0, 1.0) * 0.75))


# los sonidos, una vez: ruido filtrado con envolventes (22.050 muestras por segundo)
static func sonidos() -> Dictionary:
	if not _sonidos.is_empty():
		return _sonidos
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	_sonidos["pistola"] = tiro(rng, 0.006, 0.03, 0.08, 95.0)
	_sonidos["rifle"] = tiro(rng, 0.004, 0.022, 0.06, 120.0)
	var lp := [0.0, 0.0]
	_sonidos["tajo"] = onda(0.22, func(t: float) -> float:  # un silbido: ruido de banda media que sube y baja
		var r := rng.randf_range(-1.0, 1.0)
		lp[0] += (r - lp[0]) * 0.45
		lp[1] += (lp[0] - lp[1]) * 0.12
		return (lp[0] - lp[1]) * 1.4 * pow(sin(PI * t / 0.22), 2.0))
	var lg := [0.0]
	_sonidos["golpe"] = onda(0.14, func(t: float) -> float:  # sordo: un relleno que recibe el golpe
		lg[0] += (rng.randf_range(-1.0, 1.0) - lg[0]) * 0.12
		return sin(TAU * 140.0 * t) * 0.6 * exp(-t / 0.03) + lg[0] * 2.5 * exp(-t / 0.025))
	_sonidos["cabeza"] = onda(0.2, func(t: float) -> float:  # un tic metálico, para el que acierta en la cabeza
		return ((sin(TAU * 2650.0 * t) * 0.55 + sin(TAU * 3980.0 * t) * 0.3 * exp(-t / 0.02)) * exp(-t / 0.05)
			* minf(t / 0.0015, 1.0)))
	_sonidos["vacio"] = onda(0.05, func(t: float) -> float: return clic(rng, t))
	_sonidos["recarga"] = onda(0.16, func(t: float) -> float:  # clic y clac
		return clic(rng, t) + (clic(rng, t - 0.07) * 1.3 if t > 0.07 else 0.0))
	var ls := [0.0]
	_sonidos["sacar"] = onda(0.12, func(t: float) -> float:  # la funda y un clic
		ls[0] += (rng.randf_range(-1.0, 1.0) - ls[0]) * 0.5
		return ls[0] * 0.5 * sin(PI * t / 0.12) + (clic(rng, t - 0.09) * 0.6 if t > 0.09 else 0.0))
	return _sonidos


# un disparo: el chasquido (ruido que se apaga en `crack` s), el cuerpo (ruido filtrado y un tono grave, `cuerpo` s) y
# la cola (más filtrado, `cola` s)
static func tiro(rng: RandomNumberGenerator, crack: float, cuerpo: float, cola: float, grave: float) -> AudioStreamWAV:
	var lp := [0.0, 0.0]
	return onda(cola * 4.0, func(t: float) -> float:
		var r := rng.randf_range(-1.0, 1.0)
		lp[0] += (r - lp[0]) * 0.3
		lp[1] += (lp[0] - lp[1]) * 0.07
		return (r * 0.7 * exp(-t / crack) + lp[0] * 1.6 * exp(-t / cuerpo) + lp[1] * 5.0 * exp(-t / cola)
			+ sin(TAU * grave * t) * 0.55 * exp(-t / cuerpo)) * 0.85)


static func clic(rng: RandomNumberGenerator, t: float) -> float:
	return rng.randf_range(-1.0, 1.0) * exp(-t / 0.003) * 0.7 + sin(TAU * 2300.0 * t) * 0.4 * exp(-t / 0.005)


static func onda(dur: float, f: Callable) -> AudioStreamWAV:
	var hz := 22050
	var n := int(dur * hz)
	var datos := PackedByteArray()
	datos.resize(n * 2)
	for i in n:
		datos.encode_s16(i * 2, int(clampf(f.call(float(i) / hz), -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = hz
	w.data = datos
	return w


func sonar(k: String) -> void:
	if sonido.has(k):
		sonido[k].play()


# ---------- en pantalla ----------

func hud() -> void:
	var capa := CanvasLayer.new()
	capa.layer = 4  # bajo los mapas de plano.gd (5): el mapa grande la tapa
	add_child(capa)
	var m := Mira.new()
	m.armas = self
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.add_child(m)
	mira_ui = m
	var t := Tablero.new()
	t.armas = self
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.anchor_left = 1.0
	t.anchor_right = 1.0
	t.anchor_top = 1.0
	t.anchor_bottom = 1.0
	var abajo := Plano.MARGEN + 22.0 + 2.0 * Plano.RADIO + 12.0  # sobre el mapa en miniatura y lo que dice abajo
	t.offset_right = -Plano.MARGEN
	t.offset_left = -Plano.MARGEN - 2.0 * Plano.RADIO
	t.offset_bottom = -abajo
	t.offset_top = -abajo - 66.0
	capa.add_child(t)
	tablero = t


# la mira: cuatro rayas que se abren con la dispersión (un punto con el cuchillo), una X al acertar (más grande y
# dorada en la cabeza, roja si cae) y un arco con la recarga
func dibujar_mira(c: Control) -> void:
	if not puede():
		return
	var o := c.size / 2.0
	var blanco := Color(1, 1, 1, 0.92)
	var sombra := Color(0, 0, 0, 0.55)
	if tipo == "cuchillo":
		c.draw_circle(o, 3.2, sombra)
		c.draw_circle(o, 2.0, blanco)
	else:
		var px := tan(dispersion()) / tan(deg_to_rad(jugador.cam.fov) / 2.0) * c.size.y / 2.0
		var g := 4.0 + px
		for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			c.draw_line(o + d * (g - 1.0), o + d * (g + 10.0), sombra, 4.0)
			c.draw_line(o + d * g, o + d * (g + 9.0), blanco, 2.0)
		c.draw_circle(o, 2.0, sombra)
		c.draw_circle(o, 1.1, blanco)
	if t_acierto > 0.0:
		var col := ROJO if mato else ORO if en_cabeza else Color(1, 1, 1)
		col.a = clampf(t_acierto / 0.2, 0.0, 1.0)
		var largo := 21.0 if en_cabeza else 16.0
		var ancho := 3.5 if en_cabeza else 2.5
		for d in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			var u: Vector2 = d.normalized()
			if en_cabeza:  # con borde: el dorado se pierde sobre el cielo
				c.draw_line(o + u * 8.0, o + u * (largo + 1.0), Color(0, 0, 0, 0.6 * col.a), ancho + 2.0)
			c.draw_line(o + u * 9.0, o + u * largo, col, ancho)
	if t_recarga > 0.0:
		var u: float = 1.0 - t_recarga / ARMAS[tipo]["recarga"]
		c.draw_arc(o, 22.0, -PI / 2, -PI / 2 + TAU * u, 40, Color(1, 1, 1, 0.8), 3.0, true)


# el tablero: el arma, las tres teclas, la munición o la recarga
func dibujar_tablero(c: Control) -> void:
	if not lleva():
		return
	var f := ThemeDB.fallback_font
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.08, 0.1, 0.78)
	sb.set_corner_radius_all(10)
	c.draw_style_box(sb, Rect2(Vector2.ZERO, c.size))
	var a: Dictionary = ARMAS[tipo]
	texto(c, f, Vector2(14, 25), a["nombre"], 17, Color(1, 1, 1))
	for i in ORDEN.size():  # las teclas, con la de la mano encendida
		var r := Rect2(Vector2(c.size.x - 14 - 22 * (ORDEN.size() - i), 9), Vector2(18, 20))
		var activa: bool = ORDEN[i] == tipo
		c.draw_rect(r, Color(1, 0.85, 0.4, 0.95) if activa else Color(1, 1, 1, 0.14))
		texto(c, f, r.position + Vector2(5, 15), str(i + 1), 13, Color(0.1, 0.1, 0.1) if activa else Color(1, 1, 1, 0.7))
	if not a.has("cargador"):
		texto(c, f, Vector2(14, 54), "clic: tajo", 14, Color(1, 1, 1, 0.6))
		return
	var n: int = municion[tipo]
	var vacio := n == 0
	texto(c, f, Vector2(14, 57), str(n), 28, Color(1, 0.4, 0.3) if vacio else Color(1, 1, 1))
	var w := f.get_string_size(str(n), HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
	texto(c, f, Vector2(18 + w, 57), "/ %d" % a["cargador"], 16, Color(1, 1, 1, 0.6))
	if t_recarga > 0.0:
		var u: float = 1.0 - t_recarga / a["recarga"]
		var barra := Rect2(Vector2(100, 44), Vector2(c.size.x - 114, 7))
		c.draw_rect(barra, Color(1, 1, 1, 0.15))
		c.draw_rect(Rect2(barra.position, Vector2(barra.size.x * u, barra.size.y)), Color(1, 0.85, 0.4))
		texto(c, f, Vector2(100, 39), "recargando", 13, Color(1, 1, 1, 0.75))
	elif vacio:
		texto(c, f, Vector2(100, 55), "R: recargar", 15, Color(1, 0.8, 0.35))


static func texto(c: Control, f: Font, p: Vector2, s: String, tam: int, col: Color) -> void:
	c.draw_string_outline(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, 4, Color(0, 0, 0, 0.7))
	c.draw_string(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, col)


# ---------- --disparar ----------

func informar(s: String) -> void:
	print("armas.gd: ", s)


# --arma … --disparar n [--apuntar] [--pausa s] [--orbitar g] (main.gd): saca el arma (la pistola si no hay --arma),
# espera a que suba, y dispara n veces a lo que hay bajo la mira, apretando el gatillo para cada tiro (el rifle: una
# ráfaga, el gatillo apretado), e imprime cada impacto, el daño, la munición y cada cuánto salieron; con pausa >= 0
# congela el juego pausa s después del último (Engine.time_scale 0: --png captura el fogonazo, que dura FOGONAZO, la
# trazadora y el muñeco) y gira la cámara g grados alrededor del personaje (para ver la pose de lado), y vuelve
func prueba(n: int, pausa := -1.0) -> void:
	var arbol := get_tree()
	if tipo == "":
		elegir("pistola")
	await arbol.create_timer(SACAR + 0.4).timeout  # sacar y apuntar
	var a: Dictionary = ARMAS[tipo]
	var tiempos := []
	var t0 := Time.get_ticks_msec()
	for i in n:
		var antes := disparos
		if i == n - 1 and pausa >= 0.0:
			congelar_siguiente = pausa  # este es el último
		Input.action_press("disparar")
		var espera := 0.0
		while disparos == antes and espera < 4.0:  # la cadencia, el arma que sube
			await arbol.physics_frame
			espera += get_physics_process_delta_time()
			if t_recarga > 0.0 and not a["auto"]:  # el clic en vacío empezó a recargar: otro clic al terminar
				Input.action_release("disparar")
				while t_recarga > 0.0:
					await arbol.physics_frame
				Input.action_press("disparar")
				espera = 0.0
		tiempos.append((Time.get_ticks_msec() - t0) / 1000.0)
		if i == n - 1 and pausa >= 0.0:
			Input.action_release("disparar")
			var espera_ := 0.0
			while Engine.time_scale > 0.0 and espera_ < 5.0:
				await arbol.process_frame
				espera_ += get_process_delta_time()
			jugador.yaw += deg_to_rad(Args.num("--orbitar", 0.0, -360.0, 360.0))
			print("armas.gd: congelado %.3f s (de juego) después del último" % t_disparo)
			return
		if not a["auto"] or i == n - 1:
			Input.action_release("disparar")
			await arbol.physics_frame
	await arbol.create_timer(0.8).timeout  # lo que cae
	var pasos := []
	for i in range(1, tiempos.size()):
		pasos.append(tiempos[i] - tiempos[i - 1])
	var medio := 0.0
	for p in pasos:
		medio += p
	medio /= maxf(pasos.size(), 1)
	print("armas.gd: %s, %d %s en %.2f s (cada %.3f s); %s" % [a["nombre"], n, "tajos" if tipo == "cuchillo" else "tiros",
		tiempos[-1] - tiempos[0] if tiempos.size() > 1 else 0.0, medio,
		"%d en el cargador" % municion[tipo] if municion.has(tipo) else "sin munición"])
