# El menú de Esc: pausa el juego y ofrece seguir, ir a un lugar (viaje.gd, lo mismo que Tab), el mapa grande (plano.gd,
# M), volver a la Plaza de Armas, pasar del día a la noche (ambiente.gd, L), la red local (red.gd, J), mostrar u ocultar
# la ayuda de arriba a la izquierda, la pantalla completa, el personaje (la persona, el perro o la gata Watata: jugador.gd
# cambiar_personaje(), uno tras otro) y salir. Esc lo abre y lo cierra (antes solo soltaba el mouse:
# abierto, el mouse queda suelto igual). Las flechas y Enter recorren los botones.
#
# En una partida en red no pausa, porque los demás siguen jugando: deja quieto al personaje (jugador.quieto, que respetan
# también los vehículos y las armas) y se traga las teclas del juego. Corre también en pausa (PROCESS_MODE_ALWAYS).
# Jugando captura la bandera (jugador.sin_viajes, bandera.gd) no están «ir a un lugar» ni «volver a la plaza».
#
# Esc y los otros paneles: con la lista de lugares, el mapa grande o el panel de la red abiertos, Esc los cierra a ellos.
# Godot llama _input en el orden inverso del árbol, así que este (el último que main.gd agrega) la ve primero: si uno de
# ellos está abierto la deja pasar, y su _input la toma.
extends CanvasLayer

const Args := preload("res://args.gd")

var main: Node  # main.gd: jugador, viaje, plano, red, ambiente y ayuda_texto
var fondo := ColorRect.new()
var caja := VBoxContainer.new()
var subtitulo := Label.new()
var botones: Array[Button] = []
var b_ayuda: Button
var b_pantalla: Button
var b_personaje: Button
const NOMBRES := {"persona": "persona", "perro": "perro", "gata": "Watata (gata)"}  # cómo dice el botón cada cuerpo de jugador.gd CUERPOS
var b_plano: Button
var b_red: Button
var b_viaje: Button  # «ir a un lugar» y «volver a la plaza»: no están mientras no se viaja (viajes())
var b_plaza: Button
var antes := Input.MOUSE_MODE_CAPTURED
var en_red := false  # abierto durante una partida en red (sin pausa)


func _ready() -> void:
	layer = 10  # sobre la barra de vida, las armas y los mapas
	process_mode = Node.PROCESS_MODE_ALWAYS
	fondo.color = Color(0.02, 0.03, 0.05, 0.55)
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo.mouse_filter = Control.MOUSE_FILTER_STOP  # un clic fuera de los botones no llega a jugador.gd (que tomaría el mouse)
	add_child(fondo)
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo.add_child(centro)
	var panel := PanelContainer.new()
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.09, 0.1, 0.12, 0.94)
	estilo.border_color = Color(1, 1, 1, 0.12)
	estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(10)
	estilo.set_content_margin_all(26)
	panel.add_theme_stylebox_override("panel", estilo)
	centro.add_child(panel)
	caja.add_theme_constant_override("separation", 8)
	panel.add_child(caja)

	var titulo := Label.new()
	titulo.text = "Talca Isométrica"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 30)
	caja.add_child(titulo)
	subtitulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitulo.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	caja.add_child(subtitulo)
	caja.add_child(espacio(6))

	boton("Seguir jugando", "Esc", cerrar)
	b_viaje = boton("Ir a un lugar…", "Tab", func(): cerrar_y(func(): main.viaje.abrir(true)))
	b_plano = boton("Mapa", "M", func(): cerrar_y(func(): main.plano.abrir(true)))
	b_plaza = boton("Volver a la Plaza de Armas", "", volver_a_la_plaza)
	boton("Día o noche", "L", func(): cerrar_y(func(): main.ambiente.ir_a_hora(main.ambiente.dia_o_noche(main.ambiente.objetivo))))
	b_red = boton("Red local…", "J", func(): cerrar_y(func(): main.red.abrir(true)))
	caja.add_child(espacio(4))
	b_ayuda = boton("", "", alternar_ayuda)
	b_pantalla = boton("", "", alternar_pantalla)
	b_personaje = boton("", "", alternar_personaje)
	caja.add_child(espacio(4))
	boton("Salir del juego", "", func(): get_tree().quit())
	visible = false
	if main.jugador:
		main.jugador.viajes_cambio.connect(viajes)


func espacio(alto: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = alto
	return c


# un botón con su texto y, a la derecha y más tenue, la tecla que hace lo mismo fuera del menú
func boton(texto: String, tecla: String, accion: Callable) -> Button:
	var b := Button.new()
	b.text = texto
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(320, 40)
	b.add_theme_font_size_override("font_size", 18)
	b.pressed.connect(accion)
	if tecla != "":
		var t := Label.new()
		t.text = tecla
		t.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
		t.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
		t.offset_left = -60
		t.offset_right = -12
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(t)
	caja.add_child(b)
	botones.append(b)
	return b


func _input(e: InputEvent) -> void:
	if not (e is InputEventKey and e.pressed):
		return
	if e.keycode == KEY_ESCAPE and not e.echo:
		if not visible and otro_panel():
			return  # Esc es para cerrar ese panel (su _input viene después de este)
		abrir(not visible)
		get_viewport().set_input_as_handled()
	elif visible and e.keycode not in [KEY_UP, KEY_DOWN, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		get_viewport().set_input_as_handled()  # en red no hay pausa: que T, M, J, Tab, 1, 2, 3… no hagan nada


func otro_panel() -> bool:
	return (main.viaje and main.viaje.panel.visible) or (main.plano and main.plano.grande.visible) \
		or (main.red and main.red.panel.visible)


func abrir(si: bool) -> void:
	if si == visible:
		return
	visible = si
	var j: Node = main.jugador
	if si:
		antes = Input.mouse_mode
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		en_red = main.red != null and main.red.en_partida()
		subtitulo.text = "La partida en red sigue mientras tanto" if en_red else "Pausa"
		get_tree().paused = not en_red
		if j:
			j.quieto = true
		b_plano.disabled = main.plano == null  # --sin plano
		b_red.disabled = main.red == null
		viajes()
		textos()
		botones[0].grab_focus()
	else:
		get_tree().paused = false
		if j:
			j.quieto = false
		var f := get_viewport().gui_get_focus_owner()
		if f:
			f.release_focus()
		# a jugar otra vez: el mouse tomado (salvo en las pruebas sin mouse, --png)
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if j and j.mouse else antes


func cerrar() -> void:
	abrir(false)


# los viajes, si el personaje viaja (jugador.sin_viajes); también con el menú abierto, si empieza o termina una partida
func viajes() -> void:
	var si: bool = main.jugador == null or main.jugador.sin_viajes == ""
	b_viaje.visible = si
	b_plaza.visible = si
	if visible and get_viewport().gui_get_focus_owner() == null:
		botones[0].grab_focus()


# cierra el menú (y la pausa) y después abre lo que se eligió, que guarda el mouse tomado para cuando se cierre
func cerrar_y(accion: Callable) -> void:
	abrir(false)
	accion.call()


func volver_a_la_plaza() -> void:
	abrir(false)
	var j: Node = main.jugador
	var p: Vector3 = j.plaza  # x, y de grilla y altura del suelo (main.gd: INICIO)
	if j.viajar(p.x, p.y, p.z):
		j.yaw = 0.0  # mirando al norte, como al comenzar


func alternar_ayuda() -> void:
	main.ayuda_texto.visible = not main.ayuda_texto.visible
	textos()


func alternar_pantalla() -> void:
	var completa := DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if completa else DisplayServer.WINDOW_MODE_FULLSCREEN)
	textos()


# el siguiente cuerpo de jugador.gd CUERPOS (la persona, el perro, la gata y otra vez la persona)
func alternar_personaje() -> void:
	var j: Node = main.jugador
	var todos: Array = preload("res://jugador.gd").CUERPOS.keys()
	j.cambiar_personaje(todos[(todos.find(j.personaje) + 1) % todos.size()])
	textos()


func textos() -> void:
	b_ayuda.text = "Ayuda en pantalla: %s" % ("sí" if main.ayuda_texto.visible else "no")
	var completa := DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
	b_pantalla.text = "Pantalla completa: %s" % ("sí" if completa else "no")
	b_personaje.text = "Personaje: %s" % NOMBRES.get(main.jugador.personaje if main.jugador else "persona", "persona")
	b_personaje.disabled = main.jugador == null


# --menu-prueba (main.gd): Esc, Tab y M por la misma entrada que el teclado (Input.parse_input_event), e imprime lo que
# quedó abierto después de cada una: que el menú pause y se trague Tab, y que con otro panel abierto Esc lo cierre a él
func prueba() -> void:
	var pasos := [[KEY_ESCAPE, "Esc"], [KEY_TAB, "Tab con el menú abierto"], [KEY_ESCAPE, "Esc"], [KEY_TAB, "Tab"],
		[KEY_ESCAPE, "Esc con la lista abierta"], [KEY_M, "M"], [KEY_ESCAPE, "Esc con el mapa abierto"], [KEY_ESCAPE, "Esc"],
		[KEY_ESCAPE, "Esc"]]
	for p in pasos:
		for apretada in [true, false]:
			var e := InputEventKey.new()
			e.keycode = p[0]
			e.physical_keycode = p[0]
			e.pressed = apretada
			Input.parse_input_event(e)
			await get_tree().process_frame
			await get_tree().process_frame
		print("menu.gd: %s → %s" % [p[1], estado()])


func estado() -> String:
	var abiertos := []
	if visible:
		abiertos.append("menú")
	if main.viaje.panel.visible:
		abiertos.append("lugares")
	if main.plano and main.plano.grande.visible:
		abiertos.append("mapa")
	return "%s%s, mouse %s, quieto %s" % [", ".join(abiertos) if abiertos else "nada abierto", " (en pausa)" if get_tree().paused else "",
		"suelto" if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE else "tomado", "sí" if main.jugador.quieto else "no"]
