# La música del jetpack en la Torre Talca: despegar con el jetpack desde el techo de la torre (1 Sur 865,
# src/js/hitos/torre-talca.js) pone una pista de música, que sigue en loop mientras el jetpack va puesto y se apaga
# (en FUNDIDO s) al sacárselo, al cambiar de vehículo o al morir. Solo en el juego propio: en la red no viaja.
#
# La pista va en git: juego/musica/torre-talca.mp3 (la carpeta lleva .gdignore para que Godot no la importe: se lee del
# archivo al despegar). Se busca, en este orden, en --musica archivo (otra pista, para probar),
# res://musica/torre-talca.{ogg,mp3,wav} y user://musica/torre-talca.{ogg,mp3,wav} (un juego exportado no ve
# juego/musica/). Sin pista, despegar desde la torre lo dice una vez en la consola y no pasa nada más.
#
# «Sobre la torre» es despegar (Espacio en el suelo, vehiculo.gd volar()) con los pies dentro de su planta (PLANTA, la
# de OSM w310246574 en metros de grilla, como en el hito) y más alto que SOBRE m: los muros llegan al suelo, así que
# dentro de la planta solo se puede estar en la azotea (a 36,3 m sobre la explanada de la plaza, dentro del pretil de
# modelos/torre_talca.gd), en la sala de máquinas o en el marco del letrero.
#
#   var m := preload("res://musica.gd").new(); add_child(m)
#   m.despegue(global_position)   # vehiculo.gd, al despegar del suelo con el jetpack
#   m.parar()                     # vehiculo.gd: sacárselo, V, morir
extends Node

const Args := preload("res://args.gd")

const PLANTA := [Vector2(152.6, -25.8), Vector2(168.6, -25.8), Vector2(168.6, -13.2), Vector2(167.6, -13.2),
	Vector2(167.6, -5.2), Vector2(155.2, -5.2), Vector2(155.2, -16.2), Vector2(152.6, -16.2)]
const SOBRE := 25.0  # m (Y del juego, 0 en la plaza): el techo está a ~37
const NOMBRE := "torre-talca"
const FORMATOS := ["ogg", "mp3", "wav"]
const FUNDIDO := 2.0  # s del volumen lleno al silencio al parar
const VOLUMEN := -6.0  # dB

var reproductor := AudioStreamPlayer.new()
var sonando := false
var dicho := false  # sin pista: el aviso, una sola vez
var fundido: Tween


func _ready() -> void:
	reproductor.volume_db = VOLUMEN
	reproductor.finished.connect(func(): if sonando: reproductor.play())  # en loop, sea cual sea el formato
	add_child(reproductor)


# los pies en p (Y del juego, X = x, Z = -y): ¿sobre el techo de la Torre Talca?
static func sobre_la_torre(p: Vector3) -> bool:
	return p.y > SOBRE and Geometry2D.is_point_in_polygon(Vector2(p.x, -p.z), PackedVector2Array(PLANTA))


# despegó con el jetpack desde p: si es el techo de la torre, la música (si ya suena, sigue)
func despegue(p: Vector3) -> void:
	if sonando or not sobre_la_torre(p):
		return
	if reproductor.stream == null:
		reproductor.stream = cargar()
		if reproductor.stream == null:
			if not dicho:
				print("musica.gd: despegó desde la Torre Talca, pero no hay pista: falta juego/musica/%s.mp3 (o .ogg, .wav)" % NOMBRE)
				dicho = true
			return
	if fundido:
		fundido.kill()
	reproductor.volume_db = VOLUMEN
	reproductor.play()
	sonando = true
	print("musica.gd: despegó desde la Torre Talca: suena la música")


# se apaga en FUNDIDO s
func parar() -> void:
	if not sonando:
		return
	sonando = false
	if fundido:
		fundido.kill()
	fundido = create_tween()
	fundido.tween_property(reproductor, "volume_db", -60.0, FUNDIDO)
	fundido.tween_callback(reproductor.stop)
	print("musica.gd: la música se apaga")


# la pista: la primera que haya de --musica, res://musica/ y user://musica/
func cargar() -> AudioStream:
	var rutas: Array[String] = []
	if Args.has("--musica"):
		rutas.append(Args.texto("--musica"))
	for dir in ["res://musica/", "user://musica/"]:
		for f in FORMATOS:
			rutas.append(dir + NOMBRE + "." + f)
	for r in rutas:
		var ruta := ProjectSettings.globalize_path(r) if r.begins_with("res://") or r.begins_with("user://") else r
		if not FileAccess.file_exists(ruta):
			continue
		var s: AudioStream = null
		match ruta.get_extension().to_lower():
			"ogg":
				s = AudioStreamOggVorbis.load_from_file(ruta)
			"mp3":
				s = AudioStreamMP3.load_from_file(ruta)
			"wav":
				s = AudioStreamWAV.load_from_file(ruta)
		if s:
			print("musica.gd: la pista de la Torre Talca es ", ruta)
			return s
		push_warning("musica.gd: no se pudo leer %s (ogg, mp3 o wav)" % ruta)
	return null
