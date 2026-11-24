# El mundo de la maqueta en Godot: la comuna entera en teselas (mapa/, que mapa.gd carga alrededor de la cámara), el
# cielo y la luz de Talca (ambiente.gd) y los modelos de cerca (modelos/*.gd), sobre el nodo que lo extiende. Es la
# base de ver.gd (el visor de este proyecto) y de cualquier proyecto que use la maqueta: el que la extiende arma el
# mundo en su _ready() y pone encima lo suyo (una cámara, un personaje).
#
#   extends "res://mundo.gd"
#   func _ready() -> void:
#       Args.revisar()
#       if not armar([Vector2(0, -45)]):   # las teselas a menos de mapa.ARRANQUE de esos puntos de grilla, con colisión
#           return
#       …                                  # la cámara (mapa.gd carga alrededor de la que esté en uso)
#       await png()                        # --png x.png: un cuadro cuando terminó de cargar, y sale
#
# Lo que los modelos y ambiente.gd esperan de este nodo, que es su padre: la propiedad mapa y el hijo «mapa»
# (raices.gd, ambiente.gd), los modelos y el ambiente como hermanos (plaza.gd busca la hora en ellos), la malla
# «terreno» de las teselas bajo él (modelos/entorno/suelo.gd) y recortado() (ambiente.gd: las luces de los hitos que un
# modelo reemplaza).
#
# Los modelos de modelos/*.gd, en orden de nombre, son Node3D que construyen lo suyo (geometría y colisión) en
# _ready() y pueden declarar
#   func recortes() -> Array   # [{"poligono": PackedVector2Array([...]), "capas": ["hitos", ...]}]
# polígonos en metros de grilla (x al oriente, y al norte; X = x, Z = -y) dentro de los cuales se quita de las teselas
# lo de esas capas ("capas" vacío o ausente: todas), antes de crear la colisión: el suelo se corta en el borde del
# polígono y un objeto (un auto) se va o queda entero (recorte.gd); un árbol de arboleda.gd, si su pie cae dentro. Las
# capas, con su tipo y si son sólidas, están en mapa/indice.json («capas», LAYERS de tools/export.js; glb.gd las lee):
# un recorte con una capa que no existe da un aviso.
#
# Coordenadas como en la página: X = x de grilla (oriente), Y = altura, Z = -y (norte), origen en la plaza.
extends Node3D

const Args := preload("res://args.gd")
const Fps := preload("res://fps.gd")
const Glb := preload("res://glb.gd")
const Mapa := preload("res://mapa.gd")

var mapa: Node3D  # mapa.gd: las teselas
var ambiente: Node3D  # ambiente.gd: el cielo y la hora
var recs := []  # los recortes de los modelos (recortes()): [{"poligono", "capas"}]


func abs_path(p: String) -> String:
	return p if p.is_absolute_path() else OS.get_environment("PWD").path_join(p)


# el mapa, el ambiente y los modelos, y fps.gd si se pide (--fps); false (y sale con 1) si falta mapa/. puntos y
# alcance van a mapa.arrancar(): lo que se carga sin hilos antes del primer cuadro
func armar(puntos: Array, alcance: float = Mapa.ARRANQUE) -> bool:
	if not preload("res://fuente.gd").existe(Glb.RUTA.get_file()):
		push_error("falta mapa/: corra `make modelo3d` en la raíz de talca-isometrica")
		get_tree().quit(1)
		return false
	var mods := modelos()
	for m in mods:
		if m.has_method("recortes"):
			for r in m.recortes():
				for c in r.get("capas", []):
					if not Glb.es_capa(c):
						push_warning("mundo.gd: %s recorta la capa «%s», que el mapa no tiene (mapa/indice.json, capas)" % [m.get_script().resource_path.get_file(), c])
				recs.append(r)
	mapa = Mapa.new()
	mapa.recs = recs
	add_child(mapa)
	# la plaza (los modelos leen su suelo) y donde parte la cámara
	mapa.arrancar(puntos, alcance)
	ambiente = preload("res://ambiente.gd").new()
	add_child(ambiente)
	for m in mods:
		add_child(m)
	var fps := Fps.pedido()
	if fps > 0:
		var f := Fps.new()
		f.segundos = fps
		add_child(f)
	return true


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


# el suelo bajo (X, Z): un rayo desde arriba contra la colisión
func suelo(x: float, z: float) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, 1500, z), Vector3(x, -500, z))  # el Cerro La Virgen llega a ~223 m (el relieve exagerado)
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	return r.position if r else Vector3(x, 0, z)


# lo que la captura espera además de la carga del mapa (quien extiende este nodo lo reemplaza: una prueba que termina)
func antes_de_la_captura() -> void:
	pass


# --png x.png: guarda un cuadro, cuando el mapa terminó de cargar alrededor de la cámara, y sale
func png() -> void:
	var f := Args.texto("--png")
	if f == "":
		return
	# Godot no dibuja si ninguna de sus ventanas está a la vista (en el Mac, la de tools/godot_oculto.sh queda tapada a
	# ratos), y la captura esperaba para siempre: una salida adicional lo hace dibujar igual (también recorrido.gd)
	DisplayServer.register_additional_output(self)
	await mapa.esperar()
	await antes_de_la_captura()
	for i in 10:
		await RenderingServer.frame_post_draw
	var out := abs_path(f)
	get_viewport().get_texture().get_image().save_png(out)
	print("%s -> %s" % [get_script().resource_path.get_file(), out])
	get_tree().quit()
