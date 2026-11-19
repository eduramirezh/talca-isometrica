# La red local: varios jugadores en la misma comuna, cada uno en su computador (la misma red, Wi-Fi o cable). Uno crea
# la partida (el anfitrión) y los demás se unen; cada uno ve a los otros caminando, en bicicleta o en auto, con su
# nombre encima, y como flechas de color en los mapas (plano.gd).
#
# J abre el panel: el nombre, «Crear partida», las partidas que se anuncian en la red (doble clic: unirse), una IP a
# mano y, en una partida, la lista de jugadores (doble clic: ir donde está). Esc o J lo cierra.
#
#   Godot --path juego -- --servidor [--nombre Ana]          # crea la partida al comenzar
#   Godot --path juego -- --unirse 192.168.1.20 [--nombre Bea] # se une a esa IP («lan»: a la primera que se anuncie)
#   --puerto N: otro puerto (PUERTO; el anuncio va siempre a PUERTO_AVISO)
#   --red-prueba s: a los s segundos imprime a los otros jugadores (dónde están, en qué van) y sale (con --png, la
#   captura sale después); para probarlo sin teclado, un anfitrión con --headless y un cliente con godot_oculto.sh
#
# Cómo: ENet (ENetMultiplayerPeer, UDP) con la API de alto nivel de Godot. Cada jugador manda su estado HZ veces por
# segundo (rpc no confiable: estado()) a todos; el anfitrión lo reenvía a los clientes (server_relay de
# SceneMultiplayer, activo por omisión). No hay autoridad: cada uno simula lo suyo y los otros solo se dibujan
# (Otro: peaton.gd y, si tienen el vehículo afuera, un vehiculo.gd sin física, solo su modelo), sin colisión entre
# jugadores. El anfitrión anuncia la partida por broadcast UDP cada segundo (FIRMA|puerto|nombre|jugadores) a
# PUERTO_AVISO, que el panel escucha mientras está abierto sin partida. Lo que no viaja: la hora (T), el marcador y lo
# que carga cada uno; el mapa es el mismo porque sale de los mismos archivos (make juego).
extends Node3D

const Args := preload("res://args.gd")
const Vehiculo := preload("res://vehiculo.gd")

const PUERTO := 8790  # ENet (UDP)
const PUERTO_AVISO := 8791  # el anuncio de las partidas (broadcast UDP)
const MAX_JUGADORES := 16
const HZ := 20.0
const FIRMA := "talca-juego-1"
const POLERAS := ["b8442f", "3f8a4a", "c99a2e", "7a4fa0", "2f8f8f", "d0679a", "e07b39", "5c5c66"]  # la propia es la azul de peaton.gd

var jugador: CharacterBody3D  # jugador.gd
var vehiculo: CharacterBody3D  # vehiculo.gd
var viaje: CanvasLayer
var plano: CanvasLayer
var nombre := "Jugador"
var puerto := PUERTO
var otros := {}  # id de ENet -> Otro
var t_envio := 0.0
var anuncio := PacketPeerUDP.new()  # el anfitrión: anuncia la partida
var t_anuncio := 0.0
var escucha := PacketPeerUDP.new()  # el panel abierto sin partida (o --unirse lan): escucha los anuncios
var partidas := {}  # "ip:puerto" -> {nombre, ip, puerto, n, visto}
var conectando := ""  # la IP mientras se conecta un cliente

var capa := CanvasLayer.new()
var panel := PanelContainer.new()
var hud := Label.new()
var nombre_edit := LineEdit.new()
var crear_btn := Button.new()
var lista_partidas := ItemList.new()
var ip_edit := LineEdit.new()
var unirse_btn := Button.new()
var estado_lbl := Label.new()
var lista_jugadores := ItemList.new()
var ids_lista := []  # los ids de ENet en el orden de lista_jugadores
var antes := Input.MOUSE_MODE_CAPTURED
var t_panel := 0.0

var prueba_lista := false  # --red-prueba: ya imprimió (main.gd png() la espera)


func _init() -> void:
	name = "red"  # las rpc buscan este nodo por su ruta: tiene que llamarse igual en todos


func _ready() -> void:
	nombre = Args.texto("--nombre", nombre).strip_edges().left(24)
	puerto = int(Args.num("--puerto", PUERTO, 1024, 65535))
	multiplayer.peer_connected.connect(_llego)
	multiplayer.peer_disconnected.connect(_se_fue)
	multiplayer.connected_to_server.connect(_conectado)
	multiplayer.connection_failed.connect(_fallo)
	multiplayer.server_disconnected.connect(_sin_anfitrion)
	armar_panel()
	if Args.has("--servidor"):
		crear()
	elif Args.has("--unirse"):
		var ip := Args.texto("--unirse", "lan")
		if ip == "lan":
			buscar_y_unirse()
		else:
			unirse(ip, puerto)
	if Args.has("--red-prueba"):
		prueba()


# ---------- crear, unirse, salir ----------

func en_partida() -> bool:
	var p := multiplayer.multiplayer_peer
	return p is ENetMultiplayerPeer and p.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


func anfitrion() -> bool:
	return en_partida() and multiplayer.is_server()


func crear() -> void:
	salir(false)
	var p := ENetMultiplayerPeer.new()
	var err := p.create_server(puerto, MAX_JUGADORES)
	if err != OK:
		avisar("No se pudo abrir el puerto %d: %s (¿otra partida en este computador?)" % [puerto, error_string(err)])
		return
	multiplayer.multiplayer_peer = p
	escucha.close()
	anuncio.set_broadcast_enabled(true)
	print("red.gd: partida creada en el puerto %d (%s)" % [puerto, ", ".join(ips_locales())])
	avisar("Partida creada. Los demás la ven con J, o se unen a %s" % " o ".join(ips_locales()))


func unirse(ip: String, port := PUERTO) -> void:
	salir(false)
	ip = ip.strip_edges()
	if ip == "":
		return
	var p := ENetMultiplayerPeer.new()
	var err := p.create_client(ip, port)
	if err != OK:
		avisar("No se pudo conectar a %s: %s" % [ip, error_string(err)])
		return
	multiplayer.multiplayer_peer = p
	escucha.close()
	conectando = "%s:%d" % [ip, port]
	avisar("Conectando a %s…" % conectando)


# --unirse lan: escucha anuncios hasta 15 s y se une a la primera partida
func buscar_y_unirse() -> void:
	escuchar()
	avisar("Buscando una partida en la red local…")
	var hasta := Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < hasta:
		await get_tree().create_timer(0.25).timeout
		leer_anuncios()
		if not partidas.is_empty():
			var p: Dictionary = partidas.values()[0]
			unirse(p["ip"], p["puerto"])
			return
	avisar("No apareció ninguna partida en la red local (pruebe con la IP del anfitrión: J)")


func salir(avisar_ := true) -> void:
	if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		multiplayer.multiplayer_peer.close()
		if avisar_:
			avisar("Saliste de la partida")
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	anuncio.close()
	conectando = ""
	for id in otros.keys():
		otros[id].queue_free()
	otros.clear()


func _llego(id: int) -> void:
	otro(id)
	hola.rpc_id(id, nombre)


func _se_fue(id: int) -> void:
	var o: Otro = otros.get(id)
	if o:
		if o.nombre != "":
			avisar("%s salió" % o.nombre)
		o.queue_free()
		otros.erase(id)


func _conectado() -> void:
	print("red.gd: conectado a %s (id %d)" % [conectando, multiplayer.get_unique_id()])
	avisar("Conectado a %s" % conectando)
	conectando = ""


func _fallo() -> void:
	avisar("No se pudo conectar a %s" % conectando)
	salir(false)


func _sin_anfitrion() -> void:
	salir(false)
	avisar("El anfitrión cerró la partida")


func otro(id: int) -> Otro:
	if not otros.has(id):
		var o := Otro.new()
		o.color = Color(POLERAS[posmod(id, POLERAS.size())])
		otros[id] = o
		add_child(o)
	return otros[id]


# ---------- lo que viaja ----------

# el nombre, una vez por jugador que llega
@rpc("any_peer", "call_remote", "reliable")
func hola(n: String) -> void:
	var o := otro(multiplayer.get_remote_sender_id())
	o.nombre = n.strip_edges().left(24)
	o.etiqueta.text = o.nombre
	avisar("%s entró" % o.nombre)


# el estado de un jugador (estado_propio()), HZ veces por segundo
@rpc("any_peer", "call_remote", "unreliable_ordered")
func estado(e: Array) -> void:
	if e.size() != 11:
		return
	otro(multiplayer.get_remote_sender_id()).recibir(e)


func estado_propio() -> Array:
	var v := vehiculo
	var vt: String = v.tipo if v and v.activo else ""
	var montado: bool = v != null and v.montado
	# con el jetpack puesto lo mueve vehiculo.gd: is_on_floor() del personaje no cambia, y en_aire es lo que vale
	var en_suelo: bool = not v.en_aire if montado and vt == "jetpack" else jugador.is_on_floor()
	return [jugador.global_position, jugador.velocity, jugador.cuerpo.rotation.y, en_suelo, montado, vt,
		v.global_position if v else Vector3.ZERO, v.rumbo if v else 0.0, v.rapidez if v else 0.0,
		v.volante if v else 0.0, v.inclinar if v else Vector3.ZERO]


func _physics_process(dt: float) -> void:
	if not en_partida():
		return
	t_envio += dt
	if t_envio >= 1.0 / HZ and jugador and not multiplayer.get_peers().is_empty():
		t_envio = 0.0
		estado.rpc(estado_propio())
	if anfitrion():
		t_anuncio -= dt
		if t_anuncio <= 0.0:
			t_anuncio = 1.0
			anunciar()


# ---------- el anuncio de las partidas ----------

# a 255.255.255.255, a la difusión de cada red /24 propia (en el Mac la general no siempre sale) y a 127.0.0.1 (otra
# copia del juego en este computador)
func anunciar() -> void:
	var msg := ("%s|%d|%s|%d" % [FIRMA, puerto, nombre.replace("|", "/"), otros.size() + 1]).to_utf8_buffer()
	var destinos := ["255.255.255.255", "127.0.0.1"]
	for ip in ips_locales():
		var b := ip.substr(0, ip.rfind(".")) + ".255"
		if not b in destinos:
			destinos.append(b)
	for d in destinos:
		anuncio.set_dest_address(d, PUERTO_AVISO)
		anuncio.put_packet(msg)

func escuchar() -> void:
	if escucha.is_bound():
		return
	var err := escucha.bind(PUERTO_AVISO)
	if err != OK:
		push_warning("red.gd: no se pudo escuchar los anuncios en el puerto %d (%s)" % [PUERTO_AVISO, error_string(err)])


func leer_anuncios() -> void:
	while escucha.is_bound() and escucha.get_available_packet_count() > 0:
		var txt := escucha.get_packet().get_string_from_utf8()
		var ip := escucha.get_packet_ip()
		if ip == "127.0.0.1" or ip in ips_locales():
			ip = "127.0.0.1"  # una partida en este computador llega por varias vías: una sola entrada
		var p := txt.split("|")
		if p.size() != 4 or p[0] != FIRMA or not p[1].is_valid_int():
			continue
		partidas["%s:%s" % [ip, p[1]]] = {"ip": ip, "puerto": int(p[1]), "nombre": p[2], "n": int(p[3]), "visto": Time.get_ticks_msec()}
	for k in partidas.keys():
		if Time.get_ticks_msec() - partidas[k]["visto"] > 4000:
			partidas.erase(k)


static func ips_locales() -> PackedStringArray:
	var out := PackedStringArray()
	for a in IP.get_local_addresses():
		if a.count(".") == 3 and not a.begins_with("127.") and not a.begins_with("169.254."):
			out.append(a)
	return out


# ---------- el panel (J) ----------

func armar_panel() -> void:
	add_child(capa)
	capa.layer = 2
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.12
	panel.offset_left = -270
	panel.offset_right = 270
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 8)
	var titulo := Label.new()
	titulo.text = "Red local · J o Esc: cerrar"
	caja.add_child(titulo)
	var fila := HBoxContainer.new()
	var ln := Label.new()
	ln.text = "Nombre"
	nombre_edit.text = nombre
	nombre_edit.max_length = 24
	nombre_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nombre_edit.text_changed.connect(func(t): nombre = t.strip_edges() if t.strip_edges() != "" else "Jugador")
	crear_btn.pressed.connect(crear_o_salir)
	fila.add_child(ln)
	fila.add_child(nombre_edit)
	fila.add_child(crear_btn)
	caja.add_child(fila)
	var lp := Label.new()
	lp.text = "Partidas en la red (doble clic: unirse)"
	caja.add_child(lp)
	lista_partidas.custom_minimum_size.y = 90
	lista_partidas.item_activated.connect(unirse_a_partida)
	caja.add_child(lista_partidas)
	var fila_ip := HBoxContainer.new()
	ip_edit.placeholder_text = "o la IP del anfitrión (192.168.…)"
	ip_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ip_edit.text_submitted.connect(func(t): unirse(t, puerto))
	unirse_btn.text = "Unirse"
	unirse_btn.pressed.connect(func(): unirse(ip_edit.text, puerto))
	fila_ip.add_child(ip_edit)
	fila_ip.add_child(unirse_btn)
	caja.add_child(fila_ip)
	caja.add_child(estado_lbl)
	var lj := Label.new()
	lj.text = "Jugadores (doble clic: ir donde está)"
	caja.add_child(lj)
	lista_jugadores.custom_minimum_size.y = 110
	lista_jugadores.item_activated.connect(ir_a)
	caja.add_child(lista_jugadores)
	panel.add_child(caja)
	capa.add_child(panel)
	panel.visible = false
	# arriba a la derecha, en partida: con quién
	hud.anchor_left = 1.0
	hud.anchor_right = 1.0
	hud.offset_left = -520
	hud.offset_right = -16
	hud.offset_top = 40  # bajo la ayuda de la hora (ambiente.gd)
	hud.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud.add_theme_color_override("font_color", Color(1, 1, 1))
	hud.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	hud.add_theme_constant_override("outline_size", 4)
	capa.add_child(hud)


func crear_o_salir() -> void:
	if en_partida() or conectando != "":
		salir()
	else:
		crear()
	refrescar()


func unirse_a_partida(i: int) -> void:
	var k: String = lista_partidas.get_item_metadata(i)
	if partidas.has(k):
		unirse(partidas[k]["ip"], partidas[k]["puerto"])
		refrescar()


func abrir(si: bool) -> void:
	if si == panel.visible:
		return
	panel.visible = si
	if jugador:
		jugador.quieto = si
	if si:
		antes = Input.mouse_mode
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if not en_partida():
			escuchar()
		t_panel = 0.0
		refrescar()
	else:
		if not en_partida() and conectando == "":
			escucha.close()
		var f := get_viewport().gui_get_focus_owner()
		if f:
			f.release_focus()
		Input.mouse_mode = antes


func _input(e: InputEvent) -> void:
	if not (e is InputEventKey and e.pressed and not e.echo):
		return
	if panel.visible and e.keycode == KEY_ESCAPE:
		abrir(false)
		get_viewport().set_input_as_handled()
	elif e.physical_keycode == KEY_J:
		if panel.visible and get_viewport().gui_get_focus_owner() is LineEdit:
			return  # se está escribiendo
		if (viaje and viaje.panel.visible) or (plano and plano.grande.visible):
			return
		abrir(not panel.visible)
		get_viewport().set_input_as_handled()


func _process(dt: float) -> void:
	if panel.visible:
		t_panel -= dt
		if t_panel <= 0.0:
			t_panel = 0.5
			leer_anuncios()
			refrescar()
	if en_partida():
		hud.text = "%s · %d jugador%s · J" % ["Anfitrión en " + " / ".join(ips_locales()) if anfitrion() else "En red", otros.size() + 1, "" if otros.is_empty() else "es"]
	elif conectando != "":
		hud.text = "Conectando a %s…" % conectando
	else:
		hud.text = ""


func refrescar() -> void:
	var dentro := en_partida() or conectando != ""
	crear_btn.text = "Salir de la partida" if dentro else "Crear partida"
	lista_partidas.clear()
	for k in partidas:
		var p: Dictionary = partidas[k]
		var donde: String = "este computador" if p["ip"] == "127.0.0.1" else p["ip"]
		lista_partidas.add_item("%s · %s · %d jugador%s" % [p["nombre"], donde, p["n"], "" if p["n"] == 1 else "es"])
		lista_partidas.set_item_metadata(lista_partidas.item_count - 1, k)
	lista_partidas.mouse_filter = Control.MOUSE_FILTER_IGNORE if dentro else Control.MOUSE_FILTER_STOP
	unirse_btn.disabled = dentro
	if anfitrion():
		estado_lbl.text = "Eres el anfitrión: los demás se unen a %s (puerto %d)" % [" o ".join(ips_locales()), puerto]
	elif en_partida():
		estado_lbl.text = "En la partida (id %d)" % multiplayer.get_unique_id()
	elif conectando != "":
		estado_lbl.text = "Conectando a %s…" % conectando
	else:
		estado_lbl.text = "Sin partida" + ("" if escucha.is_bound() else " (no se pueden escuchar anuncios: use la IP)")
	lista_jugadores.clear()
	ids_lista.clear()
	if jugador:
		for id in otros:
			var o: Otro = otros[id]
			var d := jugador.global_position.distance_to(o.cuerpo.global_position)
			lista_jugadores.add_item("%s · %s · %s" % [o.nombre if o.nombre != "" else "…", o.en_que(), distancia(d)])
			ids_lista.append(id)


static func distancia(m: float) -> String:
	if m < 1000.0:
		return "%d m" % roundi(m)
	return ("%.1f km" % (m / 1000.0)).replace(".", ",")


# doble clic en un jugador: aparece a su lado (jugador.gd ir(), que espera la colisión de esa tesela)
func ir_a(i: int) -> void:
	if i < 0 or i >= ids_lista.size() or not otros.has(ids_lista[i]) or jugador == null:
		return
	var p: Vector3 = otros[ids_lista[i]].cuerpo.global_position
	jugador.ir(p.x + 2.0, -p.z, p.y)
	abrir(false)


func avisar(t: String) -> void:
	print("red.gd: ", t)
	if plano and plano.has_method("avisar"):
		plano.avisar(t)


# para plano.gd: [posición en grilla, rumbo, color, nombre] de cada otro jugador
func en_mapa() -> Array:
	var out := []
	for id in otros:
		var o: Otro = otros[id]
		if o.recibido:
			var p := o.cuerpo.global_position
			out.append([Vector2(p.x, -p.z), o.cuerpo.rotation.y if not o.montado else o.veh.rotation.y, o.color, o.nombre])
	return out


# --red-prueba s: a los s segundos, dónde están los otros
func prueba() -> void:
	await get_tree().create_timer(Args.num("--red-prueba", 10.0, 0.0, 3600.0)).timeout
	var yo := jugador.global_position if jugador else Vector3.ZERO
	print("red.gd: %s, %d otros (yo: %s en x %.1f, y %.1f)" % ["anfitrión" if anfitrion() else ("cliente" if en_partida() else "sin partida"), otros.size(), nombre, yo.x, -yo.z])
	for id in otros:
		var o: Otro = otros[id]
		var p := o.cuerpo.global_position
		print("red.gd:   %s (id %d) en x %.1f, y %.1f, altura %.2f, %s, a %.1f m" % [o.nombre, id, p.x, -p.z, p.y, o.en_que(), yo.distance_to(p)])
	prueba_lista = true
	if not Args.has("--png"):
		get_tree().quit()


# ---------- otro jugador, como se ve aquí ----------

class Otro extends Node3D:
	const Peaton := preload("res://peaton.gd")
	const Veh := preload("res://vehiculo.gd")

	var nombre := ""
	var color := Color.WHITE
	var cuerpo := Node3D.new()  # en la posición del jugador, girado como su cuerpo
	var peaton: Node3D = Peaton.new()
	var veh: CharacterBody3D  # vehiculo.gd sin física ni entrada (jugador nulo, activo falso): solo su modelo
	var etiqueta := Label3D.new()
	var recibido := false
	var t := 0.0  # s desde el último estado
	# el último estado (estado_propio())
	var p := Vector3.ZERO
	var v := Vector3.ZERO
	var rumbo := 0.0
	var en_suelo := true
	var montado := false
	var vt := ""
	var vp := Vector3.ZERO
	var vr := 0.0
	var vrap := 0.0
	var vvol := 0.0
	var vinc := Vector3.ZERO
	var fase_biela := 0.0

	func _ready() -> void:
		peaton.colores = {"polera": color.to_html(false)}
		cuerpo.add_child(peaton)
		add_child(cuerpo)
		etiqueta.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		etiqueta.fixed_size = true
		etiqueta.pixel_size = 0.0012
		etiqueta.font_size = 28
		etiqueta.outline_size = 8
		etiqueta.modulate = color.lightened(0.45)
		etiqueta.position.y = 2.25
		etiqueta.visibility_range_end = 600.0
		cuerpo.add_child(etiqueta)
		veh = Veh.new()
		add_child(veh)  # su _ready lo deja oculto y sin colisión
		visible = false

	func recibir(e: Array) -> void:
		p = e[0]
		v = e[1]
		rumbo = e[2]
		en_suelo = e[3]
		montado = e[4]
		vt = e[5]
		vp = e[6]
		vr = e[7]
		vrap = e[8]
		vvol = e[9]
		vinc = e[10]
		t = 0.0
		if not recibido:  # la primera vez, ahí mismo
			recibido = true
			visible = true
			cuerpo.global_position = p
			veh.global_position = vp

	func en_que() -> String:
		if montado:
			return "en " + Veh.TIPOS[vt]["nombre"] if Veh.TIPOS.has(vt) else "montado"
		return "a pie"

	func _process(dt: float) -> void:
		if not recibido:
			return
		t += dt
		# hacia donde estaría ahora (el último estado más su velocidad, hasta 0,25 s), suave
		var k := 1.0 - exp(-15.0 * dt)
		var meta := p + v * minf(t, 0.25)
		if cuerpo.global_position.distance_to(meta) > 30.0:  # un viaje (Tab): salta
			cuerpo.global_position = meta
		cuerpo.global_position = cuerpo.global_position.lerp(meta, k)
		cuerpo.rotation.y = lerp_angle(cuerpo.rotation.y, rumbo, k)
		# el vehículo
		if vt == "" or not Veh.TIPOS.has(vt):
			veh.visible = false
		else:
			if veh.tipo != vt:
				veh.armar(vt)
			veh.visible = true
			var adelante := Vector3.FORWARD.rotated(Vector3.UP, vr) * vrap
			var vmeta := vp + (adelante * minf(t, 0.25) if montado else Vector3.ZERO)
			if veh.global_position.distance_to(vmeta) > 30.0:
				veh.global_position = vmeta
			veh.global_position = veh.global_position.lerp(vmeta, k)
			veh.rotation.y = lerp_angle(veh.rotation.y, vr, k)
			veh.inclinar = veh.inclinar.lerp(vinc, k)
			veh.modelo.position.y = veh.inclinar.z
			veh.modelo.rotation = Vector3(veh.inclinar.x, 0, veh.inclinar.y)
			veh.fase += vrap / veh.radio_rueda * dt
			for r in veh.ruedas:
				r.rotation.x = -veh.fase
			for d in veh.direccion:
				d.rotation.y = -vvol * veh.t["giro"] * lerpf(1.0, 0.5, clampf(absf(vrap) / veh.t["vmax"], 0.0, 1.0))
			if vt == "bici":
				if montado and vrap > 0.3:
					fase_biela += vrap / 4.3 * TAU * dt
				veh.biela.rotation.x = -fase_biela
			elif vt == "jetpack":  # las llamas mientras vuela (no viaja cuánto empuja: en el aire, algo más de la mitad)
				veh.llama = 0.6 if montado and not en_suelo else 0.0
				veh.mostrar_jetpack(dt)  # veh.montado es falso aquí: solo las llamas y la luz
		# el peatón: en el asiento de la bicicleta, oculto en el auto, o caminando
		if montado and vt == "bici":
			if peaton.get_parent() != veh.asiento:
				peaton.reparent(veh.asiento, false)
			peaton.transform = Transform3D.IDENTITY
			peaton.visible = true
			var pies := []
			for i in 2:
				var a := -fase_biela + PI * i
				pies.append(Veh.BIELA_C + Vector2(cos(a), sin(a)) * Veh.BIELA_R + Vector2(-0.03, 0.07) - Veh.CADERA)
			peaton.sentar(dt, pies, 0.62, Veh.BICI_BRAZOS.x, Veh.BICI_BRAZOS.y)
		elif montado and vt == "jetpack":  # como vehiculo.gd peaton_al_vehiculo(): en el asiento, la mochila en la espalda
			if peaton.get_parent() != veh.asiento:
				peaton.reparent(veh.asiento, false)
			peaton.transform = Transform3D.IDENTITY
			peaton.visible = true
			veh.mochila_puesta(true, peaton)
			if en_suelo:
				peaton.animar(dt, vrap, true)
			else:
				veh.pose_vuelo(dt, peaton)
		else:
			if vt == "jetpack":
				veh.mochila_puesta(false)  # sacada: parada en el suelo, en el modelo del vehículo
			if peaton.get_parent() != cuerpo:
				peaton.reparent(cuerpo, false)
				peaton.transform = Transform3D.IDENTITY
			peaton.visible = not montado
			if not montado:
				peaton.animar(dt, Vector2(v.x, v.z).length(), en_suelo)
		etiqueta.position.y = 2.25 if not (montado and vt == "auto") else 1.9
