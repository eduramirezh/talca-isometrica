# El personaje: una cápsula de 1,75 m (la colisión; lo que se ve es peaton.gd, animado según la velocidad, el perro de
# perro.gd o la gata de gata.gd: --personaje perro|gata o el menú de Esc, cambiar_personaje()) con una cámara en tercera persona sobre un brazo (SpringArm3D) que se acorta
# cuando un muro se interpone. La rueda lo acorta hasta 0: primera persona, sin cuerpo a la vista. Montado en la
# bicicleta o el auto (vehiculo.gd), no se mueve solo: va con el vehículo, que maneja también la cámara.
extends CharacterBody3D

signal murio  # la vida llegó a 0 (danar())
signal danado(cantidad: float, causa: String)  # vida.gd: el destello de la barra
signal reaparecio(donde: String)  # vida.gd: el aviso («» si fue con Tab o el mapa grande)
signal no_viaja(por_que: String)  # viajar() no lo llevó (main.gd lo muestra en el mapa chico)
signal cambio_personaje(cual: String)  # cambiar_personaje() (red.gd se lo dice a los demás: traje())
signal viajes_cambio  # sin_viajes cambió: el menú, la lista de lugares, los mapas, la red y la ayuda quitan o devuelven los viajes

const CAMINAR := 8.0  # m/s (de verdad, ~1,4: se siente lento en una caja de 400 m)
const CORRER := 18.0
# El triple salto, como el de Super Mario 64: saltar otra vez hasta VENTANA s después de caer de un salto encadena el
# siguiente, más alto; el tercero, solo en movimiento (TRIPLE m/s o más; si no, vuelve al primero), es una voltereta
# hacia adelante (peaton.gd saltar()). Después del tercero la cadena empieza de nuevo. Espacio se aprieta para cada
# salto (dejarla apretada no salta de nuevo), y lo apretado hasta ANTES s antes de tocar el suelo también vale.
const SALTOS: Array[float] = [4.5, 5.6, 10.0]  # m/s hacia arriba: ~1,0, 1,6 y 5,1 m (en Mario 64, 42, 52 y 69: 1, 1,5 y 2,7 veces la altura; aquí el tercero, ~5 veces, sube al techo de una casa)
const VENTANA := 0.2  # s (en Mario 64, 5 cuadros a 30 por segundo: 0,17)
const ANTES := 0.12
const TRIPLE := 6.0  # m/s horizontales: caminando (8) alcanza; detenido o casi, no
const ALTO := 1.75
const RADIO := 0.3
const SENS := 0.004
const PELDANO := 0.4  # m: lo más alto que sube sin saltar (soleras, el borde de la plaza)
# La vida (vida.gd la muestra abajo al centro): danar() la baja y curar() la sube, hasta VIDA_MAX. Las caídas duelen
# según la rapidez hacia abajo al tocar el suelo (aterrizar()): nada hasta VEL_DOLOR, y de ahí el daño crece con la
# energía (v², la altura de la caída) hasta VEL_MUERTE, que mata con la vida llena. Con REGEN_ESPERA s sin daño se
# recupera sola, REGEN por segundo (en los carritos de completos, mucho más rápido: vida.gd). En 0 muere: cae de bruces
# (se inclina cuerpo, el nodo del peatón; el peatón no se toca), no se mueve ni recibe daño, y a los ESPERA_MUERTO s
# reaparece en la Plaza de Armas (plaza: el INICIO de main.gd, mirando al norte) con la vida llena, INVULNERABLE s sin
# recibir daño y la cadena del triple salto de nuevo. Si muere montado se baja (vehiculo.gd bajar()) y el vehículo queda
# donde estaba. Tab o el mapa grande con el personaje caído lo hacen reaparecer allá en vez de en la plaza.
const VIDA_MAX := 100.0
# m/s: ~7,3 m de caída (v² / 2g). Un salto cae a 4,5–7,4 m/s (el tercero, a ~10 si sube 5 m), una solera a ~2
const VEL_DOLOR := 12.0
const VEL_MUERTE := 23.0  # m/s: ~27 m. Entremedio, 10 m quitan ~14, 15 m ~39, 20 m ~64 y 25 m ~90
const REGEN_ESPERA := 6.0  # s sin daño antes de que se recupere sola
const REGEN := 4.0  # por segundo: de 10 a 100 en ~23 s
const ESPERA_MUERTO := 2.5  # s caído antes de reaparecer
const INVULNERABLE := 3.0  # s sin daño después de reaparecer (el peatón parpadea)
const FUERA := 60.0  # m bajo el último suelo y sin nada abajo: cayó por un hueco de la colisión, fuera de la maqueta
const CAIDO := 0.7  # s que tarda en quedar tendido
# Los toboganes: en la canaleta de uno (un cuerpo con la meta «tobogan»: modelos/juegos_alameda.gd) resbala cuesta
# abajo, con la gravedad a lo largo de la pendiente menos un roce, y las teclas no lo mueven (saltar sí); donde la
# canaleta se aplana (bajo TOBOGAN_DESDE) camina como siempre (resbalar())
const TOBOGAN_ROCE := 0.12
const TOBOGAN_MAX := 9.0  # m/s
const TOBOGAN_DESDE := deg_to_rad(10.0)

var g: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var yaw := 0.0  # 0: mirando al norte (-Z)
var pitch := -0.3
var largo := 5.0
var inicio := Vector3.ZERO
var mouse := true  # falso en las pruebas (--png): el mouse real no mueve la cámara
var brazo := SpringArm3D.new()
var cam := Camera3D.new()
var cuerpo := Node3D.new()
var pose := -1.0
const CUERPOS := {"persona": preload("res://peaton.gd"), "perro": preload("res://perro.gd"), "gata": preload("res://gata.gd")}
var personaje := "persona"  # el cuerpo que se ve: una clave de CUERPOS
var peaton: Node3D = CUERPOS[personaje].new()  # el cuerpo que se ve (peaton.gd, o perro.gd, que lo extiende, o gata.gd, que extiende al perro)
var mapa: Node3D  # mapa.gd: mientras la colisión bajo el personaje no está, no cae
var tobogan := Vector3.ZERO  # la normal de la canaleta bajo los pies en el cuadro anterior (canaleta()), o cero
var bajada := {}  # --resbalar: la bajada en curso (desde dónde, la rapidez máxima)
var _quieto := false
# viaje.gd y plano.gd: con la lista de lugares o el mapa grande abiertos, las teclas no lo mueven; muerto, tampoco,
# aunque se cierren (y vehiculo.gd, que lo lee, no lo deja subir con E)
var quieto: bool:
	get:
		return _quieto or vida <= 0.0
	set(v):
		_quieto = v
var llegar := Vector3.INF  # ir(): el punto de grilla (x, y, altura del lugar) donde aparece cuando su tesela esté lista
var forma := CollisionShape3D.new()  # vehiculo.gd la apaga mientras va montado
var vehiculo: Node = null  # vehiculo.gd, mientras va montado
var largo_a_pie := 5.0  # el brazo de la cámara antes de subir (al bajar vuelve a ese)
var t_mouse := 100.0  # s desde que se movió el mouse (vehiculo.gd: la cámara vuelve detrás del vehículo)
var salto := 0  # el último salto de la cadena (1, 2 o 3; 0: ninguno)
var en_salto := false  # en el aire por un salto (no por caerse de un borde)
var t_suelo := 0.0  # s en el suelo desde que cayó del último salto
var t_tecla := INF  # s desde que se apretó saltar
var vida := VIDA_MAX
var plaza := Vector3(0, -45, 0)  # x, y de grilla y altura del suelo donde reaparece (main.gd: INICIO y su suelo)
var t_dano := 100.0  # s desde el último daño
var t_muerto := 0.0  # s desde que murió
var t_invulnerable := 0.0  # s que le quedan sin recibir daño
var causa_muerte := ""  # la de la última muerte (vida.gd la muestra)
var caida := 0.0  # m/s hacia abajo en el último aterrizaje (vida.gd prueba())
var iba_montado := false  # en el cuadro de física anterior (bajado())
# captura la bandera (bandera.gd), en una partida: cuánto espera muerto, dónde reaparece (x, y de grilla y altura del
# suelo; INF: en la plaza), por qué no viaja con Tab, el mapa, el menú ni la red ("": viaja; los que ofrecen un viaje
# lo quitan mientras tanto: viajes_cambio), si lleva una bandera (vehiculo.gd: entonces solo a pie o en bicicleta) y
# por qué no puede ponerse el jetpack ("": puede; vehiculo.gd: puesto, baja solo y se lo saca en el suelo)
var espera_muerto := ESPERA_MUERTO
var reaparece_en := Vector3.INF
var sin_viajes := "":
	set(v):
		if v != sin_viajes:
			sin_viajes = v
			viajes_cambio.emit()
var con_bandera := false
var sin_jetpack := ""
var sin_forma := 0  # cuadros de física que le quedan con la cápsula apagada al bajarse (bajado())


func _ready() -> void:
	var cap := CapsuleShape3D.new()
	cap.radius = RADIO
	cap.height = ALTO
	forma.shape = cap
	forma.position.y = ALTO / 2
	add_child(forma)

	cuerpo.add_child(peaton)
	add_child(cuerpo)

	brazo.position.y = ojo()
	brazo.margin = 0.2
	brazo.add_excluded_object(get_rid())
	add_child(brazo)
	brazo.add_child(cam)
	cam.near = 0.05
	cam.far = 3000
	cam.fov = 70
	cam.current = true

	floor_snap_length = PELDANO + 0.05
	floor_max_angle = deg_to_rad(50)
	pose = preload("res://args.gd").num("--pose", pose, 0.0, 20.0)
	var cual := preload("res://args.gd").texto("--personaje", personaje)
	if CUERPOS.has(cual):
		cambiar_personaje(cual)
	else:
		push_warning("jugador.gd: --personaje %s no existe (%s)" % [cual, ", ".join(CUERPOS.keys())])
	if mouse:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(e: InputEvent) -> void:
	if not mouse:
		return
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= e.relative.x * SENS
		t_mouse = 0.0
		pitch = clamp(pitch - e.relative.y * SENS, -1.45, 1.2)
	elif e is InputEventMouseButton and e.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif e.button_index == MOUSE_BUTTON_WHEEL_UP or e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			# 1 m por clic; a pie, en proporción al brazo del cuerpo (con la gata, a 2,2 m, dos clics de 1 m la dejaban
			# con la cámara adentro)
			var paso := 1.0 if vehiculo else brazo_de(peaton) / 5.0
			var signo := -1.0 if e.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0
			largo = clampf(largo + signo * paso, 0.0, 20.0)
	# Esc abre el menú (menu.gd), que suelta el mouse


# un viaje que pide el jugador (Tab, el mapa grande, el menú, la red): ir(), salvo en una partida de captura la
# bandera (sin_viajes), donde avisa por qué no (no_viaja) y devuelve falso. Los que ofrecen un viaje lo quitan mientras
# tanto; esto queda por si uno se pide con un panel que ya estaba abierto
func viajar(x: float, y: float, h: float) -> bool:
	if sin_viajes != "":
		no_viaja.emit(sin_viajes)
		return false
	ir(x, y, h)
	return true


# aparece en el punto (x, y) de grilla, cuya altura del suelo es h (el «h» de los lugares de mapa/indice.json),
# cuando mapa.gd tenga ahí su colisión
func ir(x: float, y: float, h: float) -> void:
	if vehiculo:
		vehiculo.ir(x, y, h)
		return
	var revive := vida <= 0.0  # Tab o el mapa grande con el personaje caído: reaparece allá
	if revive:
		revivir()
	llegar = Vector3(x, y, h)
	velocity = Vector3.ZERO
	global_position = Vector3(x, h + 1.0, -y)
	salto = 0
	en_salto = false
	if revive:
		reaparecio.emit("")


func _physics_process(dt: float) -> void:
	vida_cuadro(dt)
	bajado()
	if vehiculo:
		return  # vehiculo.gd lo lleva
	if llegar != Vector3.INF:
		if mapa and not mapa.solido(llegar.x, llegar.y):
			return
		global_position = suelo_en(llegar) + Vector3.UP * 0.1
		inicio = global_position
		llegar = Vector3.INF
	elif mapa and not mapa.solido(global_position.x, -global_position.z):
		return  # la tesela de adelante todavía no tiene colisión: espera
	if vida <= 0.0:
		yacer(dt)
		return
	t_tecla += dt
	if Input.is_action_just_pressed("saltar") and not quieto:
		t_tecla = 0.0
	if not is_on_floor():
		velocity.y -= g * dt
	else:
		t_suelo += dt
		if t_tecla <= ANTES and not quieto:
			saltar()

	var v := Vector2.ZERO if quieto else Input.get_vector("izquierda", "derecha", "adelante", "atras")
	var dir := Vector3(v.x, 0, v.y).rotated(Vector3.UP, yaw)
	var rapidez := CORRER if Input.is_action_pressed("correr") else CAMINAR
	var k := 1.0 - exp(-12.0 * dt)  # arranca y frena en ~0,2 s
	if tobogan != Vector3.ZERO and acos(clampf(tobogan.y, -1.0, 1.0)) > TOBOGAN_DESDE and is_on_floor():
		resbalar(dt)
	else:
		velocity.x = lerp(velocity.x, dir.x * rapidez, k)
		velocity.z = lerp(velocity.z, dir.z * rapidez, k)
		if dir.length() > 0.01:
			cuerpo.rotation.y = lerp_angle(cuerpo.rotation.y, atan2(-dir.x, -dir.z), 1.0 - exp(-10.0 * dt))
	var deseo := Vector3(velocity.x, 0, velocity.z) * dt  # antes de que el choque lo anule
	var cae := 0.0 if is_on_floor() else -velocity.y  # m/s hacia abajo antes de tocar el suelo (aterrizar())
	move_and_slide()
	subir_cordon(deseo)
	tobogan = canaleta()
	if is_on_floor():
		if cae > 0.0:
			aterrizar(cae)
		inicio = global_position
		if en_salto:  # cayó: desde aquí corre la ventana para el siguiente
			en_salto = false
			t_suelo = 0.0
	elif global_position.y < inicio.y - FUERA and nada_abajo():
		# Antes volvía al último suelo. Ahora muere, como en una caída de 60 m; con suelo abajo (un barranco del
		# Cerro, bajar con el jetpack) sigue cayendo y aterrizar() decide
		morir("una caída fuera de la maqueta")


# la normal de la canaleta de tobogán bajo los pies (un rayo corto: con el ajuste al suelo, bajar por una pendiente
# no siempre deja el choque con ella entre los de move_and_slide), o cero. Con --resbalar imprime cada bajada al salir
func canaleta() -> Vector3:
	var n := Vector3.ZERO
	if is_on_floor():
		var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.3, global_position + Vector3.DOWN * 0.4)
		q.exclude = [get_rid()]
		var r := get_world_3d().direct_space_state.intersect_ray(q)
		if r and r.collider is Node and (r.collider as Node).has_meta("tobogan") and r.normal.y > 0.5:
			n = r.normal
	if preload("res://args.gd").has("--resbalar"):
		var v := Vector2(velocity.x, velocity.z).length()
		if n != Vector3.ZERO:
			if bajada.is_empty():
				bajada = {"desde": global_position, "max": 0.0}
			bajada["max"] = maxf(bajada["max"], v)
		elif not bajada.is_empty() and is_on_floor():
			var a: Vector3 = bajada["desde"]
			print("jugador.gd: tobogán de x %.1f, y %.1f, altura %.2f a x %.1f, y %.1f, altura %.2f; rapidez máxima %.1f m/s, al salir %.1f" % [
				a.x, -a.z, a.y, global_position.x, -global_position.z, global_position.y, bajada["max"], v])
			bajada = {}
	return n


# cuesta abajo por la canaleta de normal `tobogan`: la gravedad a lo largo de la pendiente (su parte horizontal) menos
# el roce, hasta TOBOGAN_MAX; mira hacia donde va
func resbalar(dt: float) -> void:
	var n := tobogan
	var baja := Vector3.DOWN - n * n.dot(Vector3.DOWN)  # a lo largo de la canaleta, cuesta abajo; su largo, el seno
	var hv := Vector2(velocity.x, velocity.z)
	var acel := Vector2(baja.x, baja.z) * g
	if hv.length() > 0.01:
		acel -= hv.normalized() * TOBOGAN_ROCE * g * n.y
	hv = (hv + acel * dt).limit_length(TOBOGAN_MAX)
	velocity.x = hv.x
	velocity.z = hv.y
	if hv.length() > 0.5:
		cuerpo.rotation.y = lerp_angle(cuerpo.rotation.y, atan2(-hv.x, -hv.y), 1.0 - exp(-10.0 * dt))


# el salto que sigue en la cadena (SALTOS): el segundo o el tercero si cayó del anterior hace VENTANA s o menos; si no,
# o después del tercero, el primero
func saltar() -> void:
	var rapidez := Vector2(velocity.x, velocity.z).length()
	if t_suelo > VENTANA or salto >= 3 or (salto == 2 and rapidez < TRIPLE):
		salto = 0
	salto += 1
	velocity.y = SALTOS[salto - 1]
	en_salto = true
	t_tecla = INF
	peaton.saltar(salto)


# --saltos n (main.gd): camina hacia adelante 1 s y salta n veces, cada una en el primer cuadro en el suelo después de
# la anterior, e imprime cuánto subió cada una sobre el suelo del que partió; con pausa >= 0, congela el juego pausa s
# después de apretar la última (Engine.time_scale 0: --png captura la pose, la voltereta del tercero, con la cámara
# de costado) y vuelve sin esperar que caiga
func prueba_saltos(n: int, pausa := -1.0) -> void:
	var arbol := get_tree()
	Input.action_press("adelante")
	await arbol.create_timer(1.0).timeout
	var dice := []
	for i in n:
		while not is_on_floor():
			await arbol.physics_frame
		var y0 := global_position.y
		var v0 := Vector2(velocity.x, velocity.z).length()
		Input.action_press("saltar")  # Input la da por recién apretada en el cuadro de física siguiente
		var t := 0.0
		while not en_salto and t < 0.1:
			await arbol.physics_frame
			t += get_physics_process_delta_time()
		Input.action_release("saltar")
		var cima := y0
		while en_salto:
			cima = max(cima, global_position.y)
			if i == n - 1 and pausa >= 0.0 and t >= pausa:
				Engine.time_scale = 0.0
				yaw += PI / 2  # la cámara de costado (a la izquierda), para ver la pose
				pitch = -0.1
				print("jugador.gd: ", ", ".join(dice + ["salto %d congelado a %.2f s (%.2f m arriba)" % [salto, t, global_position.y - y0]]))
				return
			await arbol.physics_frame
			t += get_physics_process_delta_time()
		dice.append("salto %d: %.2f m (a %.1f m/s, %.2f s en el aire)" % [salto, cima - y0, v0, t])
	Input.action_release("adelante")
	print("jugador.gd: ", ", ".join(dice))


# el suelo en el punto de un lugar: un rayo desde poco más arriba del suelo (h), para no quedar en un techo; si no da
# con nada, desde arriba
func suelo_en(p: Vector3) -> Vector3:
	var esp := get_world_3d().direct_space_state
	for desde in [p.z + 1.6, 1500.0]:
		var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, desde, -p.y), Vector3(p.x, p.z - 30.0, -p.y))
		q.exclude = [get_rid()]
		var r := esp.intersect_ray(q)
		if r:
			return r.position
	return Vector3(p.x, p.z, -p.y)


# Las soleras y los peldaños bajos (hasta PELDANO): CharacterBody3D no sube escalones solo. Si choca un muro al
# caminar, prueba el mismo paso PELDANO más arriba y, si cabe, avanza ahí; el ajuste al suelo (floor_snap_length) lo
# baja en el cuadro siguiente.
func subir_cordon(paso: Vector3) -> void:
	if not is_on_floor() or not is_on_wall() or paso.length() < 0.001:
		return
	paso = paso.normalized() * max(paso.length(), 0.05)
	var sube := Vector3.UP * PELDANO
	if test_move(global_transform, sube):  # un techo encima
		return
	var arriba := global_transform.translated(sube)
	if test_move(arriba, paso):
		return
	global_position += sube + paso


func _process(dt: float) -> void:
	t_mouse += dt
	if vehiculo:
		vehiculo.camara(dt)
		brazo.rotation = Vector3(pitch, yaw, 0)
		return
	var v := Vector2(velocity.x, velocity.z).length()
	if pose >= 0.0:  # --pose R: anima como a R m/s sin moverse (capturas del peatón)
		v = pose
	peaton.animar(dt, v, is_on_floor())
	if vida <= 0.0:  # de bruces, como un tablón que se vuelca desde los pies: el giro acelera hasta CAIDO
		var f := minf(t_muerto / CAIDO, 1.0)
		f *= f
		peaton.tendido(cuerpo, f)  # la persona de bruces, el perro y la gata de costado
	largo_actual()
	# recién reaparecido, parpadea; a pie el peatón siempre se ve (en el auto, vehiculo.gd lo esconde)
	peaton.visible = t_invulnerable <= 0.0 or fmod(t_invulnerable, 0.24) > 0.08
	brazo.rotation = Vector3(pitch, yaw, 0)


# la altura del brazo de la cámara a pie (la de los ojos de la persona, más baja con el perro y la gata)
func ojo() -> float:
	return peaton.medidas()["ojo"]


# el largo del brazo de la cámara a pie que corresponde al cuerpo (medidas() «brazo»: 5 m la persona y el perro, menos la
# gata, que es mucho más chica)
func brazo_de(pe: Node3D) -> float:
	return pe.medidas().get("brazo", 5.0)


# Otro cuerpo (una clave de CUERPOS), en el mismo lugar y pose que el de ahora (a pie, en la bicicleta o con el jetpack):
# las armas que el de ahora tiene en la mano (o en el hocico) salen antes de soltarlo, porque son de armas.gd, que se
# las pasa al nuevo con sostener() en el cuadro siguiente; la mochila del jetpack vuelve al vehículo y pasa a su montura.
# El brazo de la cámara a pie se escala con el del cuerpo (brazo_de()), y el paso de la rueda a pie también
func cambiar_personaje(cual: String) -> void:
	if cual == personaje or not CUERPOS.has(cual):
		return
	var viejo := peaton
	var padre := viejo.get_parent()
	var jet: bool = vehiculo != null and vehiculo.tipo == "jetpack"
	if jet:
		vehiculo.mochila_puesta(false)
	for m in viejo.mano:
		for c in m.get_children():
			m.remove_child(c)
	peaton = CUERPOS[cual].new()
	personaje = cual
	var escala := brazo_de(peaton) / brazo_de(viejo)
	if vehiculo == null:
		largo *= escala
	else:
		largo_a_pie *= escala
	if padre:
		padre.add_child(peaton)
		peaton.transform = viejo.transform
		peaton.visible = viejo.visible
		padre.remove_child(viejo)
	viejo.queue_free()
	if jet:
		vehiculo.mochila_puesta(true)
	if vehiculo == null:
		brazo.position = Vector3(0, ojo(), 0)
	cambio_personaje.emit(cual)


func largo_actual() -> void:
	brazo.spring_length = lerp(brazo.spring_length, largo, 0.2)
	cuerpo.visible = brazo.get_hit_length() > 0.6


# ---------- la vida (vida.gd la muestra) ----------

# quita vida (las armas, las caídas, --dano); en 0, muere. Muerto o recién reaparecido (INVULNERABLE), no hace nada
func danar(cantidad: float, causa := "") -> void:
	if vida <= 0.0 or cantidad <= 0.0 or t_invulnerable > 0.0:
		return
	vida = maxf(vida - cantidad, 0.0)
	t_dano = 0.0
	danado.emit(cantidad, causa)
	if vida <= 0.0:
		morir(causa)


# suma vida, hasta VIDA_MAX (la regeneración, los carritos de completos de vida.gd); muerto, no revive
func curar(cantidad: float) -> void:
	if vida <= 0.0 or cantidad <= 0.0:
		return
	vida = minf(vida + cantidad, VIDA_MAX)


# la entrada de las armas, la misma en cualquier blanco: el golpe en el punto `punto` desde `desde` (causa: quién, si
# viene de otro jugador de la red, red.gd tocado()). A pie lo empuja un poco hacia donde va el golpe (lo que pide
# caminar lo frena en ~0,2 s: unos 25 cm)
func recibir_dano(cantidad: float, punto: Vector3, desde: Vector3, causa := "") -> void:
	if vida > 0.0 and t_invulnerable <= 0.0 and vehiculo == null:
		var d := Vector3(punto.x - desde.x, 0.0, punto.z - desde.z)
		if d.length() > 0.01:
			velocity += d.normalized() * minf(cantidad * 0.1, 3.0)
	danar(cantidad, causa)


# los relojes de la vida, en cada cuadro de física (también montado): la regeneración, la invulnerabilidad y, muerto,
# cuándo reaparece
func vida_cuadro(dt: float) -> void:
	if vida <= 0.0:
		t_muerto += dt
		if t_muerto >= espera_muerto:
			reaparecer()
		return
	t_dano += dt
	if llegar == Vector3.INF:  # la invulnerabilidad corre desde que aparece, no mientras espera la colisión
		t_invulnerable = maxf(t_invulnerable - dt, 0.0)
	if t_dano >= REGEN_ESPERA and vida < VIDA_MAX:
		curar(REGEN * dt)


# tocó el suelo cayendo a v m/s: bajo VEL_DOLOR nada; de ahí, el daño crece con v² (la altura) hasta VIDA_MAX en
# VEL_MUERTE
func aterrizar(v: float) -> void:
	caida = v
	if v <= VEL_DOLOR:
		return
	var d := VIDA_MAX * (v * v - VEL_DOLOR * VEL_DOLOR) / (VEL_MUERTE * VEL_MUERTE - VEL_DOLOR * VEL_DOLOR)
	var m := v * v / (2.0 * g)
	print("jugador.gd: cayó a %.1f m/s (como de %.1f m): %.0f de daño" % [v, m, d])
	danar(d, "una caída de %.0f m" % m)


func morir(causa := "") -> void:
	vida = 0.0
	t_muerto = 0.0
	causa_muerte = causa
	if vehiculo:
		vehiculo.bajar()  # al lado del vehículo, que queda donde estaba (y bajado() que no quede encima)
	salto = 0
	en_salto = false
	print("jugador.gd: murió%s en x %.1f, y %.1f" % [" (%s)" % causa if causa != "" else "", global_position.x, -global_position.z])
	murio.emit()


# muerto: sin teclas, frena y, si murió en el aire, cae (sin más daño)
func yacer(dt: float) -> void:
	var k := 1.0 - exp(-6.0 * dt)
	velocity.x = lerp(velocity.x, 0.0, k)
	velocity.z = lerp(velocity.z, 0.0, k)
	if not is_on_floor():
		velocity.y -= g * dt
	move_and_slide()


# a la Plaza de Armas (o, en captura la bandera, a la suya: reaparece_en), mirando al norte, por ir(): aparece cuando
# la colisión de allá esté
func reaparecer() -> void:
	yaw = 0.0
	pitch = -0.3
	cuerpo.rotation.y = 0.0
	revivir()
	if reaparece_en != Vector3.INF:
		ir(reaparece_en.x, reaparece_en.y, reaparece_en.z)
		print("jugador.gd: reaparece en su bandera (x %.1f, y %.1f)" % [reaparece_en.x, reaparece_en.y])
		reaparecio.emit("en tu bandera")
		return
	ir(plaza.x, plaza.y, plaza.z)
	print("jugador.gd: reaparece en la Plaza de Armas")
	reaparecio.emit("en la Plaza de Armas")


# de pie, con la vida llena, un rato invulnerable y la cadena del triple salto de nuevo (ir() pone dónde, y después
# se avisa: reaparecio)
func revivir() -> void:
	vida = VIDA_MAX
	t_muerto = 0.0
	t_dano = 100.0
	t_invulnerable = INVULNERABLE
	cuerpo.rotation = Vector3(0.0, cuerpo.rotation.y, 0.0)
	cuerpo.position = Vector3.ZERO
	velocity = Vector3.ZERO
	salto = 0
	en_salto = false
	t_suelo = 0.0
	t_tecla = INF


# Recién bajado del vehículo (E o al morir), la cápsula se apaga dos cuadros de física. vehiculo.gd bajar() la enciende
# y mueve el nodo al costado, pero un cuerpo cinemático llega a su lugar nuevo recién en el paso de física siguiente:
# en ese cuadro el vehículo se movía contra la cápsula todavía en el asiento, salía 1 m hacia arriba y en el siguiente
# se iba con ella (lo que está encima de un cuerpo que se mueve va con él), sobre la cabeza del personaje. Pasaba en
# cada bajada de la bicicleta detenida (noviembre de 2026).
func bajado() -> void:
	if iba_montado and vehiculo == null:
		forma.disabled = true
		sin_forma = 2
	elif sin_forma > 0:
		sin_forma -= 1
		if sin_forma == 0 and vehiculo == null:
			forma.disabled = false
	iba_montado = vehiculo != null


# nada bajo el personaje en 3 km: se cayó de la maqueta (la colisión es de una cara: de abajo no se ve el suelo)
func nada_abajo() -> bool:
	var q := PhysicsRayQueryParameters3D.create(global_position, global_position + Vector3.DOWN * 3000.0)
	q.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()
