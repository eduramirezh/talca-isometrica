# El índice de las teselas que tools/export.py escribe en modelo3d/mapa/ (indice.json; make modelo3d), leído una vez: las
# capas que puede tener un glb con su tipo y si son sólidas (LAYERS de tools/export.js), los lugares, las luces de
# noche de los hitos (GLOW de la página), el límite de la comuna y las teselas (mapa.gd). El juego no tiene listas
# propias de capas: las toma de aquí. (Hasta noviembre de 2026, plaza.json, al lado de un solo plaza.glb de 400 m.)
#
#   const Glb := preload("res://glb.gd")
#   Glb.tipo("edificios")      # "edificio" (suelo, edificio, hito, arbol, auto; "" sin material propio)
#   Glb.solida("arboles")      # false: sin colisión
#   Glb.es_capa("hitos")       # para revisar los nombres de los recortes de modelos/
#   Glb.lugar("plaza-de-armas")   # {id, nombre, x, y, h, ...} o {}
#   Glb.luces()                # [Vector3] en Godot: cada lámpara de un hito de la comuna
#   Glb.info()                 # todo el índice (mapa.gd: «teselas», «tesela_m», «lejos», «limite»)
extends RefCounted

const RUTA := "res://mapa/indice.json"

static var _info := {}


static func info() -> Dictionary:
	if _info.is_empty():
		var f := FileAccess.open(RUTA, FileAccess.READ)
		var j: Variant = JSON.parse_string(f.get_as_text()) if f else null
		if not (j is Dictionary) or not j.has("capas"):
			push_error("glb.gd: falta %s: corra `make modelo3d` en la raíz del repositorio" % RUTA)
			j = {"capas": {}, "lugares": [], "luces": [], "teselas": []}
		_info = j
	return _info


static func es_capa(nombre: String) -> bool:
	return info()["capas"].has(nombre)


static func tipo(nombre: String) -> String:
	var c: Variant = info()["capas"].get(nombre)
	return String(c["tipo"]) if c is Dictionary and c["tipo"] != null else ""


static func solida(nombre: String) -> bool:
	var c: Variant = info()["capas"].get(nombre)
	return c is Dictionary and bool(c["solido"])


static func lugar(id: String) -> Dictionary:
	for l in info().get("lugares", []):
		if l.get("id") == id:
			return l
	return {}


static func luces() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for l in info().get("luces", []):
		out.append(Vector3(l[0], l[2], -l[1]))
	return out
