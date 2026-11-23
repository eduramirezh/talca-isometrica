# La altura del suelo de la maqueta en un punto de grilla: la malla «terreno» del glb (el relieve exagerado de la
# página, con las explanadas ya aplicadas), interpolada dentro del mismo triángulo que dibuja. Es la E(x, y) de la
# página: las calles van a E + 0,12, las veredas y el borde de la plaza a E + 0,30.
#
#   var S := preload("res://modelos/entorno/suelo.gd").new(get_parent())   # desde el _ready() de un modelo
#   S.E(x, y)
extends RefCounted

const CELDA := 20.0

var tris := []  # [Vector2 a, b, c (x, z), Vector3 alturas]
var celdas := {}


func _init(raiz: Node) -> void:
	for mi in raiz.find_children("terreno", "MeshInstance3D", true, false):
		var xf: Transform3D = mi.global_transform if mi.is_inside_tree() else Transform3D.IDENTITY
		var am: Mesh = mi.mesh
		for s in am.get_surface_count():
			var a := am.surface_get_arrays(s)
			var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else PackedInt32Array(range(v.size()))
			for t in range(0, idx.size(), 3):
				var p := [xf * v[idx[t]], xf * v[idx[t + 1]], xf * v[idx[t + 2]]]
				var k := tris.size()
				tris.append([Vector2(p[0].x, p[0].z), Vector2(p[1].x, p[1].z), Vector2(p[2].x, p[2].z), Vector3(p[0].y, p[1].y, p[2].y)])
				var x0 := floori(min(p[0].x, p[1].x, p[2].x) / CELDA)
				var x1 := floori(max(p[0].x, p[1].x, p[2].x) / CELDA)
				var z0 := floori(min(p[0].z, p[1].z, p[2].z) / CELDA)
				var z1 := floori(max(p[0].z, p[1].z, p[2].z) / CELDA)
				for i in range(x0, x1 + 1):
					for j in range(z0, z1 + 1):
						var c := Vector2i(i, j)
						if not celdas.has(c):
							celdas[c] = []
						celdas[c].append(k)
	if tris.is_empty():
		push_warning("suelo.gd: no encontré la malla «terreno» del glb; uso altura 0")


# la altura del suelo en (x, y) de grilla
func E(x: float, y: float) -> float:
	var p := Vector2(x, -y)
	var c := Vector2i(floori(p.x / CELDA), floori(p.y / CELDA))
	var mejor := 0.0
	var dmin := INF
	for k in celdas.get(c, []):
		var t: Array = tris[k]
		var b := _bary(p, t[0], t[1], t[2])
		var m: float = min(b.x, b.y, b.z)
		if m >= -1e-4:
			return b.x * t[3].x + b.y * t[3].y + b.z * t[3].z
		if -m < dmin:
			dmin = -m
			mejor = b.x * t[3].x + b.y * t[3].y + b.z * t[3].z
	return mejor


# los triángulos del relieve que tocan la caja (x0, y0, x1, y1) de grilla, como polígonos antihorarios de grilla: una
# capa plana cortada por ellos y con E() en cada vértice queda apoyada exactamente en el terreno
func triangulos(x0: float, y0: float, x1: float, y1: float) -> Array:
	var vistos := {}
	var out := []
	for i in range(floori(x0 / CELDA), floori(x1 / CELDA) + 1):
		for j in range(floori(-y1 / CELDA), floori(-y0 / CELDA) + 1):
			for k in celdas.get(Vector2i(i, j), []):
				if vistos.has(k):
					continue
				vistos[k] = true
				var t: Array = tris[k]
				var p := PackedVector2Array([Vector2(t[0].x, -t[0].y), Vector2(t[1].x, -t[1].y), Vector2(t[2].x, -t[2].y)])
				if Geometry2D.is_polygon_clockwise(p):
					p.reverse()
				out.append(p)
	return out


static func _bary(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> Vector3:
	var v0 := b - a
	var v1 := c - a
	var v2 := p - a
	var d := v0.x * v1.y - v1.x * v0.y
	if abs(d) < 1e-9:
		return Vector3(-1, -1, -1)
	var l1 := (v2.x * v1.y - v1.x * v2.y) / d
	var l2 := (v0.x * v2.y - v2.x * v0.y) / d
	return Vector3(1.0 - l1 - l2, l1, l2)
