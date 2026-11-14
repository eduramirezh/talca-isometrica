# Producción virtual con una tele de fondo (como el «volume» de LED de The Mandalorian, en chico): la tele muestra la
# plaza como una ventana vista desde donde está el teléfono que filma. El teléfono (Chrome en Android, WebXR con ARCore)
# manda su posición; la cámara de Godot se pone en ese punto, mirando de frente a la tele, con una proyección
# descentrada (Camera3D.PROJECTION_FRUSTUM) cuyo plano cercano es la pantalla misma. Solo importa la posición del
# teléfono, no hacia dónde apunta: lo que dibuja la tele es lo que se vería a través de una ventana del tamaño de la
# tele, y el teléfono filma lo que quiera de ella. El paralaje solo es correcto desde el teléfono (como en el set de
# verdad): a simple vista, desde otro lugar, se ve deformado.
#
#   Godot --path juego -- --vp [--tele 55] [--pantalla 1] [--ancla 0,-45 --rumbo 0 --alto 1.6 --escala 1]
#         [--lente 0.15] [--adelanto 0.05] [--ojo x,y,z --png x.png]
#
# Teléfono, por USB (WebXR exige https o localhost):
#   adb reverse tcp:8770 tcp:8770 && adb reverse tcp:8771 tcp:8771
#   y en Chrome del teléfono: http://localhost:8770
# Sin cable: en chrome://flags del teléfono, «Insecure origins treated as secure» con http://<ip del computador>:8770
# (la tele muestra la dirección). La página es vp/telefono.html, que sirve este mismo script (puerto 8770; las poses
# llegan por WebSocket al 8771).
#
# Calibrar: pare el teléfono sobre el borde de arriba de la tele, al centro, con la cámara mirando a la pieza, y toque
# «Calibrar» (cuenta 3 s y promedia medio segundo). Así se sabe dónde está la pantalla en el espacio de ARCore: su
# centro queda --lente m (el alto del lente sobre el borde de la imagen: el marco más la distancia del borde del
# teléfono a su cámara) más medio alto de la imagen bajo el lente, y su normal es hacia donde mira la cámara, en
# horizontal (ARCore da la vertical). Se guarda en user://vp.json: no hay que repetirlo si la tele no se mueve. Si ARCore
# se pierde (tapar la cámara, moverse muy rápido) el origen salta: recalibre.
#
#   --tele P        la diagonal de la imagen en pulgadas (55); el alto sale de la diagonal y la proporción de la ventana
#   --pantalla N    pantalla completa en el monitor N (la tele, si está como segundo monitor)
#   --ancla x,y     el centro de la tele en la plaza, en metros de grilla (0,-45: el borde sur, como el juego)
#   --rumbo G       hacia dónde mira la ventana: G grados a la izquierda del norte (como --girar del juego)
#   --alto A        el centro de la tele a A m sobre el suelo de la plaza (1,6: a la altura de los ojos)
#   --escala S      un metro del living son S m de la plaza (1: tamaño natural; 20: la tele es un ventanal de un
#                   edificio de 20 pisos)
#   --lente L       ver «Calibrar» (0,15 m)
#   --adelanto T    predice la posición T s adelante para compensar el retraso de la red, Godot y la tele (0,05)
#   --ojo x,y,z     el ojo fijo, en metros desde el centro de la tele (x a la derecha, y arriba, z hacia la pieza); para
#                   probar sin teléfono (con --png)
#
# Teclas: flechas, mover la ventana por la plaza; Q/E, girarla; RePág/AvPág, subirla o bajarla; +/−, la escala;
# R, un túnel cuadriculado detrás de la pantalla para comprobar la calibración (con la calibración bien hecha, sus
# líneas siguen rectas y fijas a la tele al mover el teléfono); M, el ojo con el mouse (sin teléfono: mueve el mouse,
# la rueda acerca); H, ocultar el texto; T, la hora (ambiente.gd); Esc, salir.
extends Node3D

const PUERTO_HTTP := 8770
const PUERTO_WS := 8771
const CAL := "user://vp.json"

var ancla := Vector2(0, -45)  # metros de grilla
var rumbo := 0.0  # grados a la izquierda del norte
var alto := 1.6
var escala := 1.0
var pulgadas := 55.0
var lente := 0.15
var adelanto := 0.05

var cam := Camera3D.new()
var nodo := Node3D.new()  # el marco de la ventana en la plaza: x a la derecha, y arriba, z hacia el espectador
var tunel := MeshInstance3D.new()
var texto := Label.new()
var suelo_y := 0.0

# la pantalla en el espacio de ARCore
var cal := false
var c := Vector3.ZERO
var r := Vector3.RIGHT
var u := Vector3.UP
var n := Vector3.BACK

# el ojo en el marco de la pantalla (m), su velocidad y cuándo llegó
var ojo := Vector3(0, 0, 2)
var vel := Vector3.ZERO
var t_ojo := 0.0  # s de Godot
var t_tel := -1.0  # ms del teléfono (el tiempo del cuadro de XR)
var fijo := false  # --ojo
var con_mouse := false

var http := TCPServer.new()
var ws := TCPServer.new()
var pend := []  # [StreamPeerTCP, bytes leídos, desde]
var peers: Array[WebSocketPeer] = []
var ultima_pose := {}  # p, q del último mensaje
var t_estado := 0.0
var n_poses := 0


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	if "--ancla" in a:
		var d: PackedStringArray = a[a.find("--ancla") + 1].split(",")
		ancla = Vector2(float(d[0]), float(d[1]))
	for k in [["--rumbo", "rumbo"], ["--alto", "alto"], ["--escala", "escala"], ["--tele", "pulgadas"],
			["--lente", "lente"], ["--adelanto", "adelanto"]]:
		if k[0] in a:
			set(k[1], float(a[a.find(k[0]) + 1]))
	if "--ojo" in a:
		var d: PackedStringArray = a[a.find("--ojo") + 1].split(",")
		ojo = Vector3(float(d[0]), float(d[1]), float(d[2]))
		fijo = true
	if "--pantalla" in a:
		DisplayServer.window_set_current_screen(int(a[a.find("--pantalla") + 1]))
	if not "--png" in a:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

	add_child(nodo)
	nodo.add_child(cam)
	cam.projection = Camera3D.PROJECTION_FRUSTUM
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.far = 3000
	cam.current = true
	nodo.add_child(tunel)
	tunel.visible = false

	var capa := CanvasLayer.new()
	add_child(capa)
	texto.position = Vector2(24, 20)
	texto.add_theme_color_override("font_color", Color(1, 1, 1))
	texto.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	texto.add_theme_constant_override("outline_size", 6)
	texto.add_theme_font_size_override("font_size", 22)
	capa.add_child(texto)

	leer_cal()
	if http.listen(PUERTO_HTTP) != OK or ws.listen(PUERTO_WS) != OK:
		push_error("vp.gd: no pude abrir los puertos %d y %d" % [PUERTO_HTTP, PUERTO_WS])
	await get_tree().physics_frame
	await get_tree().physics_frame
	suelo_y = get_parent().suelo(ancla.x, -ancla.y).y
	tunel_mesh()


# el alto y el ancho de la imagen de la tele, en m (la proporción es la de la ventana: la tele en pantalla completa)
func pantalla() -> Vector2:
	var s := get_viewport().get_visible_rect().size
	var asp: float = s.x / max(s.y, 1.0)
	var h := pulgadas * 0.0254 / sqrt(1.0 + asp * asp)
	return Vector2(h * asp, h)


func _process(dt: float) -> void:
	red()
	if con_mouse and not fijo:
		var m := get_viewport().get_mouse_position() / get_viewport().get_visible_rect().size
		var p := pantalla()
		ojo.x = (m.x - 0.5) * p.x * 2.0
		ojo.y = (0.5 - m.y) * p.y * 2.0
		vel = Vector3.ZERO
	teclas(dt)
	colocar()
	estado(dt)


# la ventana en la plaza y la cámara en el ojo predicho
func colocar() -> void:
	nodo.basis = Basis(Vector3.UP, deg_to_rad(rumbo))
	nodo.position = Vector3(ancla.x, suelo_y + alto, -ancla.y)
	var e := ojo
	if not fijo and not con_mouse and t_ojo > 0.0:
		var t := Time.get_ticks_msec() / 1000.0 - t_ojo
		e += vel * clamp(t + adelanto, 0.0, 0.25)
	e.z = max(e.z, 0.05)
	var p := pantalla()
	cam.position = e * escala
	cam.size = p.y * escala
	cam.frustum_offset = Vector2(-e.x, -e.y) * escala
	cam.near = e.z * escala


func teclas(dt: float) -> void:
	var paso: float = dt * 4.0 * max(escala, 1.0) * (4.0 if Input.is_key_pressed(KEY_SHIFT) else 1.0)
	var adelante := Vector2(-sin(deg_to_rad(rumbo)), cos(deg_to_rad(rumbo)))  # en grilla (y al norte)
	var derecha := Vector2(adelante.y, -adelante.x)
	if Input.is_key_pressed(KEY_UP): ancla += adelante * paso
	if Input.is_key_pressed(KEY_DOWN): ancla -= adelante * paso
	if Input.is_key_pressed(KEY_RIGHT): ancla += derecha * paso
	if Input.is_key_pressed(KEY_LEFT): ancla -= derecha * paso
	if Input.is_key_pressed(KEY_Q): rumbo += dt * 30.0
	if Input.is_key_pressed(KEY_E): rumbo -= dt * 30.0
	if Input.is_key_pressed(KEY_PAGEUP): alto += paso
	if Input.is_key_pressed(KEY_PAGEDOWN): alto -= paso
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_RIGHT):
		suelo_y = get_parent().suelo(ancla.x, -ancla.y).y


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		match e.physical_keycode:
			KEY_R: tunel.visible = not tunel.visible
			KEY_M: con_mouse = not con_mouse
			KEY_H: texto.visible = not texto.visible
			KEY_EQUAL, KEY_KP_ADD: escala *= 1.25; tunel_mesh()
			KEY_MINUS, KEY_KP_SUBTRACT: escala /= 1.25; tunel_mesh()
			KEY_ESCAPE: get_tree().quit()
	elif e is InputEventMouseButton and e.pressed and con_mouse:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP: ojo.z = max(0.1, ojo.z * 0.9)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN: ojo.z *= 1.1


# ---- red: la página (HTTP) y las poses (WebSocket) ----

func red() -> void:
	while http.is_connection_available():
		pend.append([http.take_connection(), PackedByteArray(), Time.get_ticks_msec()])
	for q in pend.duplicate():
		var s: StreamPeerTCP = q[0]
		s.poll()
		var nb := s.get_available_bytes()
		if nb > 0:
			q[1].append_array(s.get_data(nb)[1])
		var req: String = q[1].get_string_from_utf8()
		if req.contains("\r\n\r\n"):
			responder(s, req.get_slice(" ", 1))
			pend.erase(q)
		elif Time.get_ticks_msec() - q[2] > 3000 or s.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			s.disconnect_from_host()
			pend.erase(q)
	while ws.is_connection_available():
		var p := WebSocketPeer.new()
		p.accept_stream(ws.take_connection())
		peers.append(p)
	for p in peers.duplicate():
		p.poll()
		var st: int = p.get_ready_state()
		if st == WebSocketPeer.STATE_CLOSED:
			peers.erase(p)
			continue
		while p.get_available_packet_count() > 0:
			var m = JSON.parse_string(p.get_packet().get_string_from_utf8())
			if m is Dictionary:
				mensaje(m)


func responder(s: StreamPeerTCP, ruta: String) -> void:
	var cuerpo := PackedByteArray()
	var tipo := "text/html; charset=utf-8"
	var cod := "200 OK"
	if ruta == "/" or ruta.begins_with("/?") or ruta == "/index.html":
		cuerpo = FileAccess.get_file_as_bytes("res://vp/telefono.html")
	else:
		cod = "404 Not Found"
		tipo = "text/plain"
		cuerpo = "no existe".to_utf8_buffer()
	var cab := "HTTP/1.1 %s\r\nContent-Type: %s\r\nContent-Length: %d\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n" % [cod, tipo, cuerpo.size()]
	s.put_data(cab.to_utf8_buffer())
	s.put_data(cuerpo)
	s.disconnect_from_host()


func mensaje(m: Dictionary) -> void:
	if not m.has("p") or not m.has("q"):
		return
	var p := Vector3(m.p[0], m.p[1], m.p[2])
	var q := Quaternion(m.q[0], m.q[1], m.q[2], m.q[3])
	if m.get("t") == "cal":
		calibrar(p, q)
		return
	ultima_pose = m
	n_poses += 1
	if not cal or fijo or con_mouse:
		return
	var d := p - c
	var e := Vector3(d.dot(r), d.dot(u), d.dot(n))
	var ms: float = m.get("ms", -1.0)
	if t_tel > 0.0 and ms > t_tel:
		var v := (e - ojo) / ((ms - t_tel) / 1000.0)
		vel = vel.lerp(v, 0.35) if v.length() < 10.0 else vel
	ojo = e
	t_tel = ms
	t_ojo = Time.get_ticks_msec() / 1000.0


# el teléfono parado sobre el borde de arriba de la tele, al centro, con la cámara mirando a la pieza
func calibrar(p: Vector3, q: Quaternion) -> void:
	var f := q * Vector3.FORWARD  # hacia donde mira la cámara: hacia la pieza
	f.y = 0.0
	if f.length() < 0.2:
		enviar({"aviso": "El teléfono miraba hacia arriba o abajo: párelo derecho y repita."})
		return
	n = f.normalized()
	u = Vector3.UP
	r = u.cross(n)
	c = p - u * (lente + pantalla().y / 2.0)
	cal = true
	vel = Vector3.ZERO
	t_tel = -1.0
	var fa := FileAccess.open(CAL, FileAccess.WRITE)
	fa.store_string(JSON.stringify({"c": [c.x, c.y, c.z], "n": [n.x, n.y, n.z]}))
	enviar({"aviso": "Calibrado."})
	print("vp.gd: calibrado, centro %s, normal %s" % [c, n])


func leer_cal() -> void:
	if not FileAccess.file_exists(CAL):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(CAL))
	if d is Dictionary and d.has("c") and d.has("n"):
		c = Vector3(d.c[0], d.c[1], d.c[2])
		n = Vector3(d.n[0], d.n[1], d.n[2])
		u = Vector3.UP
		r = u.cross(n)
		cal = true


func enviar(d: Dictionary) -> void:
	var s := JSON.stringify(d)
	for p in peers:
		if p.get_ready_state() == WebSocketPeer.STATE_OPEN:
			p.send_text(s)


func estado(dt: float) -> void:
	t_estado += dt
	if t_estado < 0.25:
		return
	var hz := n_poses / t_estado
	t_estado = 0.0
	n_poses = 0
	enviar({"ojo": [ojo.x, ojo.y, ojo.z], "cal": cal, "hz": hz})
	if not texto.visible:
		return
	var l := []
	if peers.is_empty():
		l.append("Teléfono: Chrome en http://localhost:%d (con adb reverse tcp:%d tcp:%d y tcp:%d tcp:%d)" % [PUERTO_HTTP, PUERTO_HTTP, PUERTO_HTTP, PUERTO_WS, PUERTO_WS])
		for ip in IP.get_local_addresses():
			if ip.count(".") == 3 and not ip.begins_with("127.") and not ip.begins_with("169.254."):
				l.append("  o sin cable: http://%s:%d (ver chrome://flags en vp.gd)" % [ip, PUERTO_HTTP])
	else:
		l.append("Teléfono conectado: %.0f poses por segundo" % hz)
	if not cal:
		l.append("Sin calibrar: pare el teléfono sobre el borde de arriba de la tele, al centro, mirando a la pieza, y toque «Calibrar»")
	var p := pantalla()
	l.append("Ojo: %.2f m a la derecha, %.2f m arriba, %.2f m de la tele · tele %.2f × %.2f m" % [ojo.x, ojo.y, ojo.z, p.x, p.y])
	l.append("Ventana: x %.0f, y %.0f, rumbo %.0f°, alto %.1f m, escala %.2f%s" % [ancla.x, ancla.y, rumbo, alto, escala, " · ojo con el mouse" if con_mouse else ""])
	l.append("Flechas, Q/E, RePág/AvPág, +/−: mover la ventana · R: túnel de prueba · M: mouse · T: hora · H: ocultar")
	texto.text = "\n".join(l)


# un túnel cuadriculado de la profundidad del alto de la tele, justo detrás de la pantalla, y tres cubos adentro
func tunel_mesh() -> void:
	var p := pantalla() * escala
	var w := p.x / 2.0
	var h := p.y / 2.0
	var d := p.y * 1.5
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	var k := 8
	for i in k + 1:
		var z := -d * i / k
		for a in [[Vector3(-w, -h, z), Vector3(w, -h, z)], [Vector3(w, -h, z), Vector3(w, h, z)],
				[Vector3(w, h, z), Vector3(-w, h, z)], [Vector3(-w, h, z), Vector3(-w, -h, z)]]:
			im.surface_add_vertex(a[0]); im.surface_add_vertex(a[1])
		var x := -w + 2.0 * w * i / k
		var y := -h + 2.0 * h * i / k
		for a in [[Vector3(x, -h, 0), Vector3(x, -h, -d)], [Vector3(x, h, 0), Vector3(x, h, -d)],
				[Vector3(-w, y, 0), Vector3(-w, y, -d)], [Vector3(w, y, 0), Vector3(w, y, -d)]]:
			im.surface_add_vertex(a[0]); im.surface_add_vertex(a[1])
	for b in [[Vector3(-w * 0.5, -h, -d * 0.25), h * 0.3], [Vector3(w * 0.4, -h, -d * 0.6), h * 0.4], [Vector3(0, -h, -d * 0.9), h * 0.5]]:
		var o: Vector3 = b[0]
		var s: float = b[1]
		var cs := []
		for j in 8:
			cs.append(o + Vector3((j & 1) * s - s / 2, (j >> 1 & 1) * s, (j >> 2 & 1) * s - s / 2))
		for e in [[0, 1], [2, 3], [4, 5], [6, 7], [0, 2], [1, 3], [4, 6], [5, 7], [0, 4], [1, 5], [2, 6], [3, 7]]:
			im.surface_add_vertex(cs[e[0]]); im.surface_add_vertex(cs[e[1]])
	im.surface_end()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.2, 1.0, 0.4)
	m.disable_fog = true
	tunel.mesh = im
	tunel.material_override = m
