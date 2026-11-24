# El arranque en el navegador (la escena principal de la exportación web, `make web3d`: talca.eduramirez.com/3d/).
# mapa/ no va en el paquete: se baja por HTTP de mapa/, junto a la página (fuente.gd, bajada.gd). Antes de abrir el
# visor (ver.tscn) baja indice.json, lejos.glb y las teselas que mapa.gd arrancar() lee sin hilos (la plaza y el punto
# de partida); lo demás lo baja mapa.gd mientras se mira. Las banderas de args.gd vienen del # de la dirección:
#
#   /3d/#catedral                     el lugar con ese id (los de la página: indice.json, «lugares»)
#   /3d/#120,-340                     ese punto de grilla
#   /3d/#catedral&girar=90&camara=60&mirar=-20&hora=20.5&dia=172&calidad=alta
#
# Sin calidad=alta va con --calidad baja (sin SSIL ni SSAO, que el renderizador del navegador no tiene, ni sombras
# blandas). Mientras corre deja su estado en window.__m3d (un JSON: estado, MB bajados, teselas, cuadros por segundo),
# para la página (web/shell.html) y para tools/web3d.py.
extends Node

const Fuente := preload("res://fuente.gd")
const Bajada := preload("res://bajada.gd")
const Mapa := preload("res://mapa.gd")
const Glb := preload("res://glb.gd")
const Args := preload("res://args.gd")
const NO_WEB := ["png", "fps", "render", "cenital", "reloj"]  # banderas que en el navegador no sirven

var ver: Node  # ver.gd, cuando está
var aviso: Label
var estado := "bajando"
var t_estado := 0.0


func _ready() -> void:
	Fuente.base = str(JavaScriptBridge.eval("new URL('mapa/', location.href).href"))
	var h := str(JavaScriptBridge.eval("decodeURIComponent(location.hash.slice(1))"))
	var bajada := Bajada.new()
	bajada.name = "bajada"
	add_child(bajada)
	Fuente.bajada = bajada
	poner_aviso()
	await bajar(["indice.json"])
	if not Fuente.existe("indice.json"):
		estado = "error"
		aviso.text = "No pude bajar la maqueta (mapa/indice.json). Recargue la página para intentar de nuevo."
		return
	Args.extra = argumentos(h)
	Args.revisar()
	var m := Mapa.new()  # sin la escena: solo para saber qué teselas lee arrancar()
	var fs := m.archivos_arranque([Vector2.ZERO, Args.vec2("--desde", Vector2.ZERO)])
	m.free()
	fs.append(String(Glb.info()["lejos"]["archivo"]))
	await bajar(fs)
	estado = "cargando"
	ver = load("res://ver.tscn").instantiate()
	get_tree().root.add_child(ver)
	get_tree().current_scene = ver


# las banderas del # de la dirección (ver arriba)
func argumentos(h: String) -> PackedStringArray:
	var out := PackedStringArray()
	var calidad := "baja"
	for parte in h.split("&", false):
		var kv := parte.split("=", true, 1)
		if kv.size() == 2:
			var b := "--" + kv[0]
			if kv[0] == "calidad":
				calidad = kv[1]
			elif Args.BANDERAS.has(b) and Args.BANDERAS[b][0] != "" and not kv[0] in NO_WEB:
				out.append_array([b, kv[1]])
			else:
				push_warning("web.gd: no entiendo «%s» en la dirección" % parte)
		elif parte.split(",").size() == 2 and parte.split(",")[0].is_valid_float() and parte.split(",")[1].is_valid_float():
			out.append_array(["--desde", parte])
		else:
			var l := Glb.lugar(parte)
			if l.is_empty():
				push_warning("web.gd: no hay un lugar «%s» (indice.json, lugares)" % parte)
			else:
				out.append_array(["--desde", "%s,%s" % [l["x"], l["y"]]])
	if calidad == "baja":
		out.append_array(["--calidad", "baja"])
	return out


func bajar(nombres: Array) -> void:
	var e := {"listo": false}  # una lambda no puede cambiar una variable local: cambia este diccionario
	Fuente.bajada.pedir(nombres, func(): e["listo"] = true)
	while not e["listo"]:
		await get_tree().process_frame


func poner_aviso() -> void:
	var capa := CanvasLayer.new()
	capa.layer = 10
	add_child(capa)
	aviso = Label.new()
	aviso.position = Vector2(16, 16)
	aviso.add_theme_font_size_override("font_size", 18)
	aviso.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	aviso.add_theme_constant_override("outline_size", 6)
	capa.add_child(aviso)


func _process(dt: float) -> void:
	if estado == "bajando":
		aviso.text = "Bajando la maqueta… %.0f MB" % Fuente.bajada.mb
	t_estado -= dt
	if t_estado > 0.0:
		return
	t_estado = 0.5
	var mapa: Node = ver.get("mapa") if ver else null
	if estado == "cargando" and mapa:
		if mapa.listo():
			estado = "listo"
			aviso.visible = false
		else:
			aviso.text = "Cargando alrededor… %d teselas (%.0f MB)" % [mapa.cargadas.size(), Fuente.bajada.mb]
	var s := {"estado": estado, "mb": snappedf(Fuente.bajada.mb if Fuente.bajada else 0.0, 0.1),
		"fps": Engine.get_frames_per_second()}
	if mapa:
		s["teselas"] = mapa.cargadas.size()
		s["medias"] = mapa.medios.size()
	JavaScriptBridge.eval("window.__m3d = %s" % JSON.stringify(s))
