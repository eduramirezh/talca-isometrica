# El plano del entorno de la plaza, en metros de grilla (x al oriente, y al norte; en Godot X = x, Z = -y): el
# borde de la plaza, las calzadas, las veredas y los edificios de OSM (osm.json, de tools/juego_osm.py). Lo comparten
# calles.gd, fachadas.gd y catedral.gd.
#
# Las medidas: las fachadas, de las plantas de OSM (las cuatro caras: 1 Poniente x = -67, 1 Norte y = 69,
# 1 Oriente x = 71, 1 Sur y = -72,5); el borde de la plaza, el contorno PZ del hito de la página
# (src/js/hitos/plaza-de-armas.js, el parque w479529034), que es la solera del lado de la plaza: la plaza va a
# E + 0,30 y la calzada a E + 0,12. La solera del lado de las manzanas, de la imagen de Esri (satellite.py punto …
# --rejilla=5) y de los árboles de vereda de OSM en 1 Norte (y = 66,5–67,4): veredas de 2,5 m en 1 Poniente, 3,5 m
# en 1 Norte y 1 Oriente y 4 m en 1 Sur. Las calles del mapa de la página son más anchas que las reales (11 m,
# centradas en el eje del grafo): aquí la calzada va de solera a solera. Lo aproximado: el ancho de las veredas
# (±1 m), las calles que siguen más allá de las esquinas (un ancho fijo sobre el eje de OSM).
extends RefCounted

const ALTO_CALZADA := 0.12
const ALTO_VEREDA := 0.30

# el contorno de la plaza (PZ del hito plaza-de-armas), antihorario
const PZ := [38.9, -54.2, 35.8, -54.5, -21.3, -54, -29.9, -54, -35.8, -52.5, -41.2, -49.6, -47.4, -44.3, -51.5, -38.9,
	-53.5, -32.2, -55.7, -23.9, -55.7, 22.4, -55, 34.9, -53.3, 40.4, -51.5, 43.9, -47.7, 48.9, -43.7, 52, -39.2, 53.7,
	-34.7, 54.8, 36.6, 53.1, 40.3, 52.5, 43.8, 50.4, 49.6, 43.6, 53.8, 38.2, 55.7, 30.3, 56.2, -29.9, 55.8, -34.7,
	53.2, -41.1, 48.4, -47.7, 41.6, -53]

# líneas de fachada y soleras de las cuatro calles que rodean la plaza
const FACHADA := {"O": -67.0, "N": 69.0, "E": 71.0, "S": -72.5}
const SOLERA := {"O": -64.5, "N": 65.5, "E": 67.5, "S": -68.5}
const LEJOS := 132.0  # hasta dónde siguen las calles más allá de las esquinas

# las calzadas: el anillo alrededor de la plaza (menos la plaza) y los ocho tramos que siguen desde las esquinas,
# [x0, y0, x1, y1]; cada tramo, con su vereda a cada lado hasta las fachadas ([x0, y0, x1, y1] de fachada a fachada)
const TRAMOS := [
	# calle, calzada, fachada a fachada
	["1 Norte", [-LEJOS, 59.5, -64.5, 69.0], [-LEJOS, 57.0, -67.0, 72.5]],
	["1 Norte", [67.5, 58.0, LEJOS, 65.5], [71.0, 55.0, LEJOS, 69.5]],
	["1 Sur", [-LEJOS, -68.5, -64.5, -58.5], [-LEJOS, -75.0, -67.0, -55.0]],
	["1 Sur", [67.5, -68.5, LEJOS, -58.0], [71.0, -71.0, LEJOS, -54.5]],
	["1 Poniente", [-64.5, 65.5, -59.5, 100.0], [-68.0, 69.0, -56.0, 100.0]],
	["1 Poniente", [-64.5, -LEJOS, -57.5, -68.5], [-69.0, -LEJOS, -55.0, -72.5]],
	["1 Oriente", [59.5, 65.5, 66.0, LEJOS], [56.0, 69.0, 69.0, LEJOS]],
	["1 Oriente", [59.0, -LEJOS, 67.5, -68.5], [55.0, -LEJOS, 71.0, -72.5]],
]

static var _osm := {}


static func pz() -> PackedVector2Array:
	var o := PackedVector2Array()
	for i in range(0, PZ.size(), 2):
		o.append(Vector2(PZ[i], PZ[i + 1]))
	return o


static func rect(r: Array) -> PackedVector2Array:
	return PackedVector2Array([Vector2(r[0], r[1]), Vector2(r[2], r[1]), Vector2(r[2], r[3]), Vector2(r[0], r[3])])


static func anillo_calzada() -> PackedVector2Array:
	return rect([SOLERA["O"], SOLERA["S"], SOLERA["E"], SOLERA["N"]])


static func anillo_fachadas() -> PackedVector2Array:
	return rect([FACHADA["O"], FACHADA["S"], FACHADA["E"], FACHADA["N"]])


static func osm() -> Dictionary:
	if _osm.is_empty():
		var f := FileAccess.open("res://modelos/entorno/osm.json", FileAccess.READ)
		if f:
			_osm = JSON.parse_string(f.get_as_text())
	return _osm


# la planta de un edificio de OSM por su id, como PackedVector2Array antihoraria en (x, y) de grilla
static func edificio(id: int) -> PackedVector2Array:
	for b in osm().get("edificios", []):
		if int(b["id"]) == id:
			var o := PackedVector2Array()
			for p in b["anillo"]:
				o.append(Vector2(p[0], p[1]))
			if Geometry2D.is_polygon_clockwise(o):
				o.reverse()
			return o
	push_warning("plano.gd: no está el edificio w%d en osm.json" % id)
	return PackedVector2Array()


static func nodos(tipo: String) -> Array:
	return osm().get("nodos", []).filter(func(n): return n["tipo"] == tipo)


# un polígono crecido (o achicado) m metros, el primero que da offset_polygon
static func crecer(p: PackedVector2Array, m: float) -> PackedVector2Array:
	var r := Geometry2D.offset_polygon(p, m, Geometry2D.JOIN_MITER)
	return r[0] if not r.is_empty() else p
