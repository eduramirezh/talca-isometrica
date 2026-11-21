# Un paseo por Talca: la maqueta de la página exportada por tools/export.py, la comuna entera en teselas de 500 m
# (juego/mapa/, que mapa.gd carga alrededor de la cámara mientras se juega), con la Plaza de Armas y sus calles en
# detalle (modelos/) y un personaje en tercera persona que camina sobre ella.
#
#   make juego                                                     # exporta juego/mapa/ (~3 min, ~800 MB) e importa en Godot
#   /Applications/Godot.app/Contents/MacOS/Godot --path juego       # jugar (o abrir juego/project.godot en el editor)
#   /Applications/Godot.app/Contents/MacOS/Godot --path juego -- --png shots/juego.png [--desde x,y] [--girar 90] [--mirar -10] [--camara 5] [--caminar 3]
#
# WASD o flechas: caminar; Mayús: correr; Espacio: saltar (otra vez apenas cae: más alto; la tercera, en movimiento,
# una voltereta: el triple salto, jugador.gd); mouse: mirar; rueda: acercar la cámara (hasta la primera
# persona); Esc: el menú (menu.gd: pausa; seguir, ir a un lugar, el mapa, volver a la plaza, día o noche, la red, la
# ayuda en pantalla, pantalla completa, salir); Tab: ir a un lugar (viaje.gd); M: el mapa grande, donde un
# clic pone un marcador y ruta.gd traza el camino hasta él, y un doble clic (o Enter, al marcador) lleva al personaje
# ahí (plano.gd, que dibuja también el mapa en miniatura; N: con el norte arriba). E: subir a la bicicleta o
# al auto, o bajar (si está lejos, lo trae), o ponerse o sacarse el jetpack; V: cambiar entre los tres; montado, W/S
# acelera y frena (detenido, retrocede), A/D gira, Espacio frena de golpe y, en la bicicleta, Q pedalea de pie; con el
# jetpack, Espacio sube, C baja rápido, WASD lo mueve y Mayús más rápido (vehiculo.gd). J: la red local,
# para jugar con otros en la misma red (red.gd: crear una partida o unirse; --servidor, --unirse ip, --nombre). --png guarda un cuadro
# (cuando el mapa terminó de cargar alrededor de la cámara) y sale; --desde x,y pone al
# personaje en ese punto de grilla, --girar G gira la vista G grados a
# la izquierda, --mirar P la inclina P grados, --camara L pone la cámara a L m (0: primera persona) y --caminar N camina N segundos hacia adelante antes (para revisar la colisión sin teclado).
# --vehiculo bici|auto|jetpack sube al vehículo al comenzar y --conducir N acelera N segundos (--volante v: girando,
# -1 a la izquierda … 1 a la derecha; --fuerte: con Q) e imprime dónde terminó, contra qué chocó, cuánto esperó la
# colisión y los cuadros más lentos (--bajar: se baja al final); con --png, la captura es del final; sin --png, sale.
# Con el jetpack, --volar N despega, sube, avanza y aterriza en ~N s (--fuerte: con Mayús; --pausa s: congela el vuelo
# s segundos después de despegar, para --png; --bajar: al final se lo saca, camina y se lo pone otra vez) e imprime la
# altura máxima, lo recorrido, el combustible y la rapidez al aterrizar.
# --saltos N camina 1 s hacia adelante y salta N veces seguidas e imprime la altura de cada salto (--pausa s: congela el
# juego s segundos después del último, para que --png capture la voltereta); sin --png, sale.
# --dano N le quita N de vida y --caer M lo deja caer desde M m sobre el suelo, e imprimen la vida, la caída y, si
# muere, dónde reaparece (vida.gd prueba(); --pausa s: congela el juego s segundos después, para --png); sin --png, sale.
# 1, 2, 3: el cuchillo, la pistola o el rifle (otra vez, o 0: guardarlo); clic: disparar o atacar; botón derecho:
# apuntar; R: recargar (armas.gd; los muñecos de práctica del borde sur de la plaza son de blancos.gd). --arma
# cuchillo|pistola|rifle la saca al comenzar, --apuntar apunta y --disparar N dispara N veces a lo que hay bajo la mira e
# imprime cada impacto (--pausa s: congela s después del último, para --png; --orbitar G gira entonces la cámara G grados
# alrededor del personaje); sin --png, sale. Los muñecos se ven desde donde parte: --girar 58 --mirar -3 --apuntar apunta
# al más cercano.
#
# Coordenadas como en la página: X = x de grilla (oriente), Y = altura, Z = -y (norte), origen en la plaza.
# Colisión: una malla exacta (trimesh) por capa sólida de cada tesela cercana (mapa.gd), salvo los árboles (se
# atraviesan); en el borde de la comuna, un muro invisible.
#
# Lo que se ve y lo que reemplaza al glb va en archivos propios, para que este no crezca:
#   cine.gd          --cine: un plano de cine a la tarde, con la cámara en un recorrido fijo y peatones (ver cine.gd)
#   trailer.gd       --trailer toma: una toma del avance (tools/trailer.py las graba y las junta)
#   vp.gd            --vp: producción virtual con una tele de fondo, la cámara movida por un teléfono (ver vp.gd)
#   mapa.gd          las teselas de la comuna alrededor de la cámara, lo de lejos, la colisión cercana y el límite
#   arboleda.gd      los árboles de la página, como los de la plaza de cerca y copas redondas de lejos
#   recorte.gd       los recortes de los modelos sobre cada tesela (abajo)
#   ambiente.gd      cielo, luz, sombras, niebla y posproceso (un Node3D que se agrega a la escena)
#   jugador.gd       el personaje y su cámara, su vida y las caídas; viaje.gd, la lista de lugares para ir (Tab)
#   vida.gd          la barra de vida, la muerte en pantalla y los carritos de completos, donde se recupera
#   plano.gd         el mapa en miniatura y el mapa grande (M), con plano_datos.gd (datos/plano.json, de pipeline/plano.py)
#   ruta.gd          el marcador del mapa grande y el camino hasta él, con la cinta de flechas y la columna de luz
#   vehiculo.gd      la bicicleta, el auto y el jetpack (E, V), con su cámara
#   menu.gd          el menú de Esc (pausa)
#   red.gd           la red local (J, --servidor, --unirse ip): los otros jugadores, como peatones o en sus vehículos, con sus armas
#   armas.gd         el cuchillo, la pistola y el rifle (1, 2, 3), con sus modelos en modelos/entorno/armas.gd
#   bandera.gd       captura la bandera en la red local (el anfitrión la prepara con J; B pone la bandera propia)
#   blancos.gd       los muñecos de práctica, cerca de donde parte el personaje
#   modelos/*.gd     modelos propios del juego, más detallados que los de la página. Cada uno es un Node3D que construye
#                    lo suyo (geometría y colisión) en _ready() y puede declarar
#                      func recortes() -> Array   # [{"poligono": PackedVector2Array([...]), "capas": ["hitos", ...]}]
#                    polígonos en metros de grilla (x al oriente, y al norte; X = x, Z = -y) dentro de los cuales se
#                    quita de las teselas lo de esas capas ("capas" vacío o ausente: todas), antes de crear la
#                    colisión: el suelo se corta en el borde del polígono y un objeto (un auto) se va o queda entero
#                    (recorte.gd); un árbol de arboleda.gd, si su pie cae dentro. Las capas, con su tipo y si son
#                    sólidas, están en mapa/indice.json («capas», LAYERS de tools/export.js; glb.gd las lee): un
#                    recorte con una capa que no existe da un aviso.
extends Node3D

const Args := preload("res://args.gd")
const Fps := preload("res://fps.gd")
const Glb := preload("res://glb.gd")
const Mapa := preload("res://mapa.gd")
const Trailer := preload("res://trailer.gd")
const INICIO := Vector2(0, -45)  # x, y de grilla: el borde sur de la plaza, mirando al norte

var jugador: CharacterBody3D
var vehiculo: CharacterBody3D
var mapa: Node3D
var viaje: CanvasLayer
var ruta: Node3D  # ruta.gd: el marcador y el camino
var plano: CanvasLayer  # plano.gd: el mapa en miniatura y el mapa grande (M)
var red: Node3D  # red.gd: los otros jugadores de la red local (J)
var vida: CanvasLayer  # vida.gd: la barra de vida y los carritos de completos
var armas: Node3D  # armas.gd
var bandera: Node3D  # bandera.gd: captura la bandera, en la red local
var ambiente: Node3D  # ambiente.gd: el cielo y la hora (el menú pasa del día a la noche)
var ayuda_texto: Label  # la ayuda de arriba a la izquierda (ayuda(); el menú la muestra u oculta)
var menu: CanvasLayer  # menu.gd: Esc
var recs := []  # los recortes de los modelos (recortes()): [{"poligono", "capas"}]


func abs_path(p: String) -> String:
	return p if p.is_absolute_path() else OS.get_environment("PWD").path_join(p)


func _ready() -> void:
	Args.revisar()
	acciones()
	if not FileAccess.file_exists(Glb.RUTA):
		push_error("falta juego/mapa/: corra `make juego` en la raíz del repositorio")
		get_tree().quit(1)
		return
	var mods := modelos()
	for m in mods:
		if m.has_method("recortes"):
			for r in m.recortes():
				for c in r.get("capas", []):
					if not Glb.es_capa(c):
						push_warning("main.gd: %s recorta la capa «%s», que el mapa no tiene (mapa/indice.json, capas)" % [m.get_script().resource_path.get_file(), c])
				recs.append(r)

	mapa = Mapa.new()
	mapa.recs = recs
	add_child(mapa)
	var toma: Dictionary = Trailer.pedida() if Args.has("--trailer") else {}  # una toma del avance (trailer.gd)
	var desde := Args.vec2("--desde", INICIO) if Args.has("--desde") else INICIO
	if toma.has("desde") and not Args.has("--desde"):
		desde = Vector2(toma["desde"][0], toma["desde"][1])
	# la plaza (los modelos leen su suelo) y donde aparece el personaje; para la película, todo lo que ve su cámara
	mapa.arrancar([Vector2.ZERO, desde], Mapa.CARGA if Args.has("--cine") or not toma.is_empty() else Mapa.ARRANQUE)
	ambiente = preload("res://ambiente.gd").new()
	add_child(ambiente)
	for m in mods:
		add_child(m)
	var fps := Fps.pedido()
	if fps > 0:
		var f := Fps.new()
		f.segundos = fps
		add_child(f)

	if Args.has("--cine"):  # un plano de cine: la cámara, la hora y los peatones, en función del tiempo (cine.gd)
		add_child(preload("res://cine.gd").new())
		return
	if toma.get("tipo", "") == "camara":  # una toma de cámara del avance, sin personaje (trailer.gd)
		add_child(Trailer.new())
		return
	if Args.has("--vp"):  # la tele de fondo: la cámara la mueve un teléfono (vp.gd), sin personaje
		add_child(preload("res://vp.gd").new())
		await png()
		return
	jugador = preload("res://jugador.gd").new()
	jugador.mouse = not (Args.has("--png") or Args.has("--caminar") or Args.has("--trailer"))
	jugador.mapa = mapa
	add_child(jugador)
	viaje = preload("res://viaje.gd").new()
	add_child(viaje)
	vehiculo = preload("res://vehiculo.gd").new()
	vehiculo.jugador = jugador
	vehiculo.mapa = mapa
	add_child(vehiculo)
	ruta = preload("res://ruta.gd").new()
	ruta.jugador = jugador
	ruta.vehiculo = vehiculo
	ruta.mapa = mapa
	add_child(ruta)
	if not "plano" in Args.sin_():  # --sin plano: sin los mapas (para medir con --fps cuánto cuestan)
		plano = preload("res://plano.gd").new()
		plano.jugador = jugador
		plano.vehiculo = vehiculo
		plano.ruta = ruta
		plano.viaje = viaje
		add_child(plano)
	red = preload("res://red.gd").new()
	red.jugador = jugador
	red.vehiculo = vehiculo
	red.viaje = viaje
	red.plano = plano
	if plano:
		plano.red = red
	add_child(red)
	ambiente.red = red  # el anfitrión manda su hora a los demás (ambiente.gd la_hora())
	red.ambiente = ambiente
	red.salio.connect(ambiente.salio)
	vida = preload("res://vida.gd").new()
	vida.jugador = jugador
	add_child(vida)
	armas = preload("res://armas.gd").new()
	armas.jugador = jugador
	add_child(armas)
	red.armas = armas  # los tiros propios a los demás, y los de ellos aquí
	armas.accion.connect(red.enviar_accion)
	bandera = preload("res://bandera.gd").new()  # captura la bandera, en la red
	bandera.red = red
	bandera.jugador = jugador
	bandera.plano = plano
	bandera.ruta = ruta
	add_child(bandera)
	if plano:
		plano.bandera = bandera
		jugador.no_viaja.connect(plano.avisar)  # Tab, el mapa, el menú o la red en captura la bandera
	var blancos := preload("res://blancos.gd").new()
	blancos.mapa = mapa
	add_child(blancos)
	await get_tree().physics_frame
	await get_tree().physics_frame
	jugador.inicio = suelo(INICIO.x, -INICIO.y) + Vector3.UP * 0.1
	jugador.global_position = jugador.inicio
	jugador.plaza = Vector3(INICIO.x, INICIO.y, jugador.inicio.y - 0.1)  # donde reaparece al morir
	if toma.is_empty():
		ayuda()
	menu = preload("res://menu.gd").new()  # el último: su _input ve Esc antes que los paneles (menu.gd)
	menu.main = self
	add_child(menu)

	if Args.has("--desde") or not toma.is_empty():
		# primero el personaje allá (jugador.gd no lo deja caer mientras no haya colisión): mapa.gd arma la colisión
		# alrededor de la cámara y suelta la de más de 500 m, así que un rayo en este cuadro no daba con nada lejos de
		# la plaza (el Cerro quedaba bajo el suelo)
		var d := desde
		jugador.global_position = Vector3(d.x, jugador.global_position.y, -d.y)
		while not mapa.solido(d.x, d.y):
			await get_tree().physics_frame
		jugador.inicio = suelo(d.x, -d.y) + Vector3.UP * 0.1
		jugador.global_position = jugador.inicio
	if Args.has("--girar"):
		jugador.yaw = deg_to_rad(Args.num("--girar", 0.0))
	elif toma.has("girar"):
		jugador.yaw = deg_to_rad(toma["girar"])
	if not toma.is_empty():  # una toma de juego del avance: trailer.gd maneja las teclas
		add_child(Trailer.new())
		return
	if Args.has("--mirar"):  # grados sobre (+) o bajo (−) la horizontal
		jugador.pitch = deg_to_rad(Args.num("--mirar", 0.0, -89.0, 89.0))
	if Args.has("--vehiculo"):
		await mapa.esperar()
		var tv := Args.texto("--vehiculo")
		if vehiculo.TIPOS.has(tv):
			vehiculo.armar(tv)
		else:
			push_warning("main.gd: --vehiculo espera bici, auto o jetpack")
		vehiculo.usar()
	if Args.has("--marcar"):  # el marcador en ese punto de grilla y el camino hasta él (ruta.gd)
		await mapa.esperar()
		ruta.marcar(Args.vec2("--marcar", Vector2.ZERO))
	if Args.has("--plano") and plano:
		plano.abrir(true)
		if Args.has("--escala-plano"):
			plano.esc = Args.num("--escala-plano", 0.3, plano.ESC_MIN, plano.ESC_MAX)
			plano.vista_grande()
		for b in ["--clic", "--doble-clic"]:  # clics izquierdos en ese punto de la pantalla, por la entrada del mouse
			if Args.has(b):
				var c := Args.vec2(b, Vector2.ZERO)
				await get_tree().process_frame
				for k in (2 if b == "--doble-clic" else 1):
					for abajo in [true, false]:
						var e := InputEventMouseButton.new()
						e.button_index = MOUSE_BUTTON_LEFT
						e.pressed = abajo
						e.double_click = abajo and k == 1
						e.position = c
						e.global_position = c
						Input.parse_input_event(e)
						await get_tree().process_frame
		if Args.has("--doble-clic"):  # fue a otra parte: la captura espera a que cargue
			await get_tree().create_timer(0.5).timeout
			await mapa.esperar()
			print("main.gd: jugador en x %.1f, y %.1f, altura %.2f" % [jugador.global_position.x, -jugador.global_position.z, jugador.global_position.y])
	if Args.has("--camara"):  # largo del brazo de la cámara en m (0: primera persona)
		jugador.largo = Args.num("--camara", jugador.largo, 0.0, 100.0)
		jugador.brazo.spring_length = jugador.largo
	if Args.has("--caminar"):
		await mapa.esperar()
		Input.action_press("adelante")
		await get_tree().create_timer(Args.num("--caminar", 1.0, 0.0, 600.0)).timeout
		Input.action_release("adelante")
		var choque := jugador.get_last_slide_collision()
		var contra := ""
		if choque and jugador.is_on_wall():
			contra = ", contra «%s»" % choque.get_collider().get_parent().name
		print("main.gd: jugador en x %.1f, y %.1f, altura %.2f%s" % [jugador.global_position.x, -jugador.global_position.z, jugador.global_position.y, contra])
	if Args.has("--saltos"):  # el triple salto sin teclado (jugador.gd prueba_saltos())
		await mapa.esperar()
		await jugador.prueba_saltos(roundi(Args.num("--saltos", 3.0, 1.0, 20.0)), Args.num("--pausa", -1.0, 0.0, 5.0))
		if not Args.has("--png"):
			get_tree().quit()
			return
	if Args.has("--dano") or Args.has("--caer"):  # la vida sin teclado: daño, caídas y reaparición (vida.gd prueba())
		await mapa.esperar()
		await vida.prueba()
		if not Args.has("--png"):
			get_tree().quit()
			return
	if Args.has("--disparar"):  # las armas sin mouse (armas.gd prueba())
		await mapa.esperar()
		await blancos.listos()
		await armas.prueba(roundi(Args.num("--disparar", 5.0, 1.0, 200.0)), Args.num("--pausa", -1.0, 0.0, 5.0))
		if not Args.has("--png"):
			get_tree().quit()
			return
	if Args.has("--conducir"):
		await vehiculo.prueba()
		if not Args.has("--png"):  # sin captura (--headless), sale al terminar
			get_tree().quit()
			return
	if Args.has("--volar"):  # el jetpack sin teclado (vehiculo.gd prueba_vuelo())
		await vehiculo.prueba_vuelo()
		if not Args.has("--png"):
			get_tree().quit()
			return
	if Args.has("--menu-prueba"):  # Esc, Tab y M sin teclado (menu.gd prueba())
		await mapa.esperar()
		await menu.prueba()
		if not Args.has("--png"):
			get_tree().quit()
			return
	if Args.has("--menu"):  # el menú de Esc abierto, para la captura
		await mapa.esperar()
		menu.abrir(true)
	await png()


# --png x.png: guarda un cuadro y sale
func png() -> void:
	var f := Args.texto("--png")
	if f == "":
		return
	await mapa.esperar()
	if red and (Args.has("--red-prueba") or Args.has("--red-tiros") or Args.has("--red-foto")):  # la captura después del informe de la red (con los otros ya a la vista)
		while not red.prueba_lista:
			await get_tree().process_frame
	if bandera and (Args.has("--ctf-prueba") or Args.has("--ctf-robar")):  # después de la prueba de captura la bandera
		while not bandera.prueba_lista:
			await get_tree().process_frame
	for i in 10:
		await RenderingServer.frame_post_draw
	var out := abs_path(f)
	get_viewport().get_texture().get_image().save_png(out)
	print("main.gd -> ", out)
	get_tree().quit()


# los modelos de modelos/*.gd, en orden de nombre
func modelos() -> Array:
	var out := []
	var fs := Array(ResourceLoader.list_directory("res://modelos/"))
	fs.sort()
	for f in fs:
		if f.ends_with(".gd"):
			out.append(load("res://modelos/" + f).new())
	return out


# si un punto de grilla cae en un recorte que quita la capa (ambiente.gd: las luces de los hitos que un modelo reemplaza)
func recortado(p: Vector2, capa: String) -> bool:
	for r in recs:
		var capas: Array = r.get("capas", [])
		if (capas.is_empty() or capa in capas) and Geometry2D.is_point_in_polygon(p, r["poligono"]):
			return true
	return false


# las teclas, como acciones (así --caminar puede apretarlas)
func acciones() -> void:
	var teclas := {"adelante": [KEY_W, KEY_UP], "atras": [KEY_S, KEY_DOWN], "izquierda": [KEY_A, KEY_LEFT],
		"derecha": [KEY_D, KEY_RIGHT], "saltar": [KEY_SPACE], "correr": [KEY_SHIFT], "vehiculo": [KEY_E], "cambiar": [KEY_V],
		"impulso": [KEY_Q],  # Q y no Mayús: en el Mac de Edu el Bloq Mayús está como Esc
		"cuchillo": [KEY_1], "pistola": [KEY_2], "rifle": [KEY_3], "guardar": [KEY_0], "recargar": [KEY_R],  # armas.gd
		"bandera": [KEY_B]}  # bandera.gd
	var botones := {"disparar": MOUSE_BUTTON_LEFT, "apuntar": MOUSE_BUTTON_RIGHT}  # armas.gd
	for a in teclas:
		if InputMap.has_action(a):
			continue
		InputMap.add_action(a)
		for k in teclas[a]:
			var e := InputEventKey.new()
			e.physical_keycode = k
			InputMap.action_add_event(a, e)
	for a in botones:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
			var e := InputEventMouseButton.new()
			e.button_index = botones[a]
			InputMap.action_add_event(a, e)


# el suelo bajo (X, Z): un rayo desde arriba contra la colisión
func suelo(x: float, z: float) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, 1500, z), Vector3(x, -500, z))  # el Cerro La Virgen llega a ~223 m (el relieve exagerado)
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	return r.position if r else Vector3(x, 0, z)


func ayuda() -> void:
	var capa := CanvasLayer.new()
	add_child(capa)
	var l := Label.new()
	l.text = "WASD: caminar · Mayús: correr · Espacio: saltar (tres seguidos: triple salto) · mouse: mirar · rueda: cámara · Tab: ir a un lugar · Esc: menú\nE: subir o bajar del vehículo (lejos, lo trae) · V: bicicleta, auto o jetpack · montado, W/S: acelerar y frenar · A/D: girar · Espacio: frenar · Q: pedalear de pie\nJetpack: Espacio sube · C baja rápido · WASD lo mueve · Mayús: más rápido · se recarga en el suelo\nM: mapa (un clic pone el marcador y el camino hasta él; doble clic: ir ahí) · N: el mapa chico con el norte arriba · J: red local (jugar con otros; captura la bandera: B pone la tuya)\nVida (abajo): las caídas de más de ~7 m duelen y de ~27 m matan; se recupera sola, y rápido comiendo un completo en los carritos de 5 y 6 Oriente\n1: cuchillo · 2: pistola · 3: rifle (otra vez o 0: guardar) · clic: disparar · botón derecho: apuntar · R: recargar"
	l.position = Vector2(16, 12)
	l.add_theme_color_override("font_color", Color(1, 1, 1))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("outline_size", 4)
	capa.add_child(l)
	ayuda_texto = l
