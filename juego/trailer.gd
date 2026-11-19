# Las tomas del avance («trailer») del juego: cada una es una corrida de Godot con Movie Maker (tools/trailer.py las
# graba, les pone los títulos y la música y las junta en shots/trailer/talca.mp4). Una toma es de cámara (un recorrido
# fijo, como cine.gd: «camara») o de juego (el personaje o un vehículo manejados por un guion de teclas: «auto», «bici»,
# «saltos»), a una hora fija.
#
#   python3 tools/trailer.py [--solo auto,noche] [--size 1280x720]       # todas las tomas, los títulos y la música
#   Godot --path juego --write-movie $PWD/shots/trailer/auto.avi --fixed-fps 30 -- --trailer auto --sin plano
#   Godot --path juego -- --trailer cerro --cuadro 0,2,4 --png shots/trailer/c.png   # cuadros sueltos, para encuadrar
#
# El mapa carga en hilos mientras la toma espera (mapa.esperar()) y Movie Maker graba también esos cuadros: la toma
# imprime «trailer.gd: toma N…M» (Engine.get_frames_drawn() al comenzar y al terminar) y tools/trailer.py corta ahí.
# Antes de esos cuadros, PREVIO s de juego sin grabar: el auto ya va andando y el sol ya está en su lugar.
#
# Coordenadas como en main.gd: x, y de grilla (x al oriente, y al norte), X = x, Z = -y. En «plano», cada clave es
# [t, x, y, alto, mira x, mira y, mira alto]: las alturas, sobre el suelo bajo cada punto (un rayo contra la colisión).
# «orbita»: [x, y, radio, alto, grados al comenzar, grados al terminar, mira alto] (0°: al oriente, crece al norte).
extends Node3D

const Args := preload("res://args.gd")

const PREVIO := 0.8  # s de juego antes de grabar (las tomas de juego: arrancar el vehículo)
const TOMAS := {
	# sobre los techos hacia la Plaza de Armas y la Catedral, a la hora dorada
	"ciudad": {"tipo": "camara", "dur": 5.0, "hora": 20.35, "desde": [60, -120],
		"plano": [[0.0, 230, -260, 120, -40, 30, 0], [5.0, 90, -110, 55, -80, 35, 8]]},
	# el auto por 1 Norte hacia el oriente, de tarde (en la Ruta 5 chocaba con los autos quietos de su pista)
	"auto": {"tipo": "auto", "dur": 5.0, "hora": 18.2, "desde": [75, 61], "girar": -90, "volante": 0.0},
	# la bicicleta por 1 Sur hacia el oriente, frente a la plaza
	"bici": {"tipo": "bici", "dur": 4.0, "hora": 11.0, "desde": [-60, -62], "girar": -90, "volante": 0.0, "fuerte": true},
	# el triple salto en la vereda de 1 Sur
	"saltos": {"tipo": "saltos", "dur": 4.0, "hora": 13.0, "desde": [0, -62], "girar": -90},
	# vuelta alrededor del Estadio Fiscal
	"estadio": {"tipo": "camara", "dur": 4.5, "hora": 19.6, "desde": [-680, 680],
		"orbita": [-680, 678, 210, 85, -60, -20, 0]},
	# el Río Claro y sus puentes al atardecer
	"rio": {"tipo": "camara", "dur": 4.5, "hora": 20.8, "desde": [-1390, 820],
		"plano": [[0.0, -1150, 650, 60, -1500, 900, 0], [4.5, -1260, 700, 45, -1560, 950, 0]]},
	# la Virgen del cerro, girando a contraluz
	"cerro": {"tipo": "camara", "dur": 4.5, "hora": 20.75, "desde": [-3397, 129],
		"orbita": [-3397, 129, 70, 20, 195, 245, 10]},
	# la plaza de noche, con los faroles, hacia la Catedral
	"noche": {"tipo": "camara", "dur": 5.0, "hora": 22.6, "desde": [0, 40],
		"plano": [[0.0, 10, 40.5, 2.0, -74, 40, 6], [5.0, -14, 40.5, 3.4, -74, 40, 12]]},
}
const DIA := 15  # 15 de enero

var main: Node
var ambiente: Node
var toma: Dictionary
var nombre := ""
var cam := Camera3D.new()
var claves := []  # [t, posición, mira]
var t := 0.0
var grabando := false
var cuadro0 := 0


static func pedida() -> Dictionary:
	return TOMAS.get(Args.texto("--trailer"), {})


func _ready() -> void:
	main = get_parent()
	nombre = Args.texto("--trailer")
	toma = TOMAS.get(nombre, {})
	if toma.is_empty():
		push_error("trailer.gd: no hay una toma «%s» (%s)" % [nombre, ", ".join(TOMAS.keys())])
		get_tree().quit(1)
		return
	for n in main.get_children():
		if n.has_method("poner_hora"):
			ambiente = n
	if ambiente:
		ambiente.dia = DIA
		hora()
		if ambiente.reloj:
			ambiente.reloj.get_parent().visible = false
	var vida: CanvasLayer = main.get("vida")  # la barra de vida.gd (las tomas de juego), como el reloj y la ayuda
	if vida:
		vida.visible = false
	if toma["tipo"] == "camara":
		cam.fov = 50.0
		cam.near = 0.1
		cam.far = 3000
		add_child(cam)
		cam.make_current()
		await get_tree().physics_frame
		await get_tree().physics_frame
		await main.mapa.esperar()
		await armar_claves()
		camara(0.0)
		await main.mapa.esperar()  # lo que ve la cámara desde su primer lugar
	else:
		await juego()
	var cuadros := PackedFloat32Array()
	for c in Args.lista("--cuadro"):
		if c.is_valid_float():
			cuadros.append(clampf(float(c), 0.0, toma["dur"]))
	if cuadros.size() > 0:  # cuadros sueltos (solo las tomas de cámara): x-t<s>.png
		var out: String = main.abs_path(Args.texto("--png")) if Args.has("--png") else "user://trailer.png"
		for c in cuadros:
			t = c
			camara(c)
			hora()
			for i in 12:
				await RenderingServer.frame_post_draw
			var f := "%s-t%s.png" % [out.get_basename(), String.num(c, 2).trim_suffix(".0")]
			get_viewport().get_texture().get_image().save_png(f)
			print("trailer.gd -> ", f)
		get_tree().quit()
		return
	for i in 6:  # que el cielo y las sombras se asienten
		await RenderingServer.frame_post_draw
	cuadro0 = Engine.get_frames_drawn()
	t = 0.0
	grabando = true


func hora() -> void:
	if ambiente:
		ambiente.objetivo = toma["hora"]
		ambiente.poner_hora(toma["hora"])


func _process(dt: float) -> void:
	hora()
	if toma.get("tipo", "") == "camara" and not claves.is_empty():
		camara(t)
	if not grabando:
		return
	t += dt
	var v: Node3D = main.get("vehiculo")
	var parado: bool = toma["tipo"] in ["auto", "bici"] and t > 1.5 and absf(v.rapidez) < 2.0
	if t >= toma["dur"] or parado:  # un vehículo que choca termina la toma ahí: el cuadro congelado es el choque
		grabando = false
		print("trailer.gd: toma %s cuadros %d…%d" % [nombre, cuadro0, Engine.get_frames_drawn()])
		get_tree().quit()


# ---------- tomas de cámara ----------

func armar_claves() -> void:
	var plano: Array = toma.get("plano", [])
	if toma.has("orbita"):
		var o: Array = toma["orbita"]
		plano = []
		var n := 8
		for i in n + 1:
			var u := float(i) / n
			var a := deg_to_rad(lerpf(o[4], o[5], u))
			plano.append([u * toma["dur"], o[0] + cos(a) * o[2], o[1] + sin(a) * o[2], o[3], o[0], o[1], o[6]])
	for k in plano:
		var p: Vector3 = await suelo_cargado(k[1], k[2]) + Vector3.UP * float(k[3])
		var m: Vector3 = await suelo_cargado(k[4], k[5]) + Vector3.UP * float(k[6])
		claves.append([float(k[0]), p, m])


func camara(tt: float) -> void:
	if claves.size() < 2:
		return
	var d: float = claves[-1][0]
	var orbita := toma.has("orbita")
	var s := tt / d if orbita else smoothstep(0.0, 1.0, tt / d) * 0.5 + tt / d * 0.5  # sale y llega suave, sin detenerse
	var tq := s * d
	var i := 0
	while i < claves.size() - 2 and tq > claves[i + 1][0]:
		i += 1
	var u := clampf((tq - claves[i][0]) / (claves[i + 1][0] - claves[i][0]), 0.0, 1.0)
	var p := catmull(i, 1, u)
	var m := catmull(i, 2, u)
	cam.global_position = p
	if not p.is_equal_approx(m):
		cam.look_at(m, Vector3.UP)


func catmull(i: int, k: int, u: float) -> Vector3:
	var n := claves.size()
	var p0: Vector3 = claves[maxi(i - 1, 0)][k]
	var p1: Vector3 = claves[i][k]
	var p2: Vector3 = claves[i + 1][k]
	var p3: Vector3 = claves[mini(i + 2, n - 1)][k]
	return p1.cubic_interpolate(p2, p0, p3, u)


# mapa.gd arma la colisión solo alrededor de la cámara (COLISION): lejos de la plaza un rayo no daba con nada y la
# cámara quedaba a la altura 0, bajo el Cerro La Virgen. La cámara va a cada punto y espera su colisión.
func suelo_cargado(x: float, y: float) -> Vector3:
	cam.global_position = Vector3(x, cam.global_position.y, -y)
	await get_tree().process_frame
	await main.mapa.esperar()
	await get_tree().physics_frame
	return suelo(x, y)


func suelo(x: float, y: float) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, 1500, -y), Vector3(x, -500, -y))
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	return r.position if r else Vector3(x, 0, -y)


# ---------- tomas de juego ----------

func juego() -> void:
	var j: Node3D = main.jugador
	var v: Node3D = main.vehiculo
	await main.mapa.esperar()
	var tipo: String = toma["tipo"]
	if tipo == "auto" or tipo == "bici":
		if v.tipo != tipo:
			v.cambiar()
		v.usar()
		Input.action_press("adelante")
		var vol: float = toma.get("volante", 0.0)
		if vol > 0.0:
			Input.action_press("derecha", vol)
		elif vol < 0.0:
			Input.action_press("izquierda", -vol)
		if toma.get("fuerte", false):
			Input.action_press("impulso")
		await get_tree().create_timer(PREVIO).timeout
		await main.mapa.esperar()
	elif tipo == "saltos":
		# corre y salta tres veces seguidas: el tercero, la voltereta (jugador.gd prueba_saltos())
		Input.action_press("correr")
		j.prueba_saltos(3)
	else:
		push_error("trailer.gd: tipo de toma «%s»" % tipo)
