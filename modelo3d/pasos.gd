# Los pasos bajo la Ruta 5 en la colisión de la capa «hitos». La página no puede hundir la autopista bajo los pasos
# superiores de la ciudad (2 Norte, San Miguel, 8 Sur: trampa «La Ruta 5 va en trinchera y el relieve no la puede
# dibujar»), ni un camino bajo un terraplén: dibuja el paso con una rampa que sube 2–4 m y una cara oscura (K.void,
# #2B3036, r5Over y los `voids` de r5Raise en 66-ruta5.js) donde la autopista o el camino pasarían por debajo. En el
# juego esa cara era un muro de colisión que cerraba la Ruta 5 en cada paso (el auto, a 90 km/h, contra el de 8 Sur), y
# bajo el tablero de 8 Sur quedan 1,4–2,8 m, menos que un auto (la cápsula de vehiculo.gd mide 1,7 m).
#
# Aquí, las caras oscuras verticales de una tesela se agrupan (las de un mismo paso están a menos de AGRUPAR) y la
# envolvente convexa de cada grupo, en planta, es el paso: dentro de ella solo chocan los triángulos que miran hacia
# arriba (el tablero, la autopista sobre el terraplén), y como la colisión de una malla es de una cara
# (ConcavePolygonShape3D sin backface_collision, como create_trimesh_shape()), se pasa por debajo de ellos. Muros,
# vigas, barandas y la cara inferior del tablero dentro del paso no chocan: un auto sobre el puente puede caer por el
# costado a la autopista, y la cámara, que va más alta que el tablero, lo ve desde arriba al pasar. Solo la capa
# «hitos», y solo en las teselas que tienen ese color (las de la Ruta 5); en las demás, create_trimesh_shape() igual
# que antes.
#
#   var forma := preload("res://pasos.gd").forma(malla)   # en el hilo de mapa.gd, al armar la colisión de «hitos»
extends RefCounted

const OSCURO := Color(0x2B / 255.0, 0x30 / 255.0, 0x36 / 255.0)  # K.void de enlaces-ruta-5.js y los puentes de la Ruta 5
const TOLERANCIA := 1.5 / 255.0  # el glb lo trae lineal y Godot lo guarda en 8 bits
const AGRUPAR := 30.0  # m: las caras de un paso (los dos costados de un tablero de hasta 23,6 m de ancho)
const ARRIBA := 0.7  # la componente vertical de la normal de lo que sigue chocando dentro de un paso


static func forma(m: Mesh) -> Shape3D:
	var lineal := OSCURO.srgb_to_linear()
	var tris := []  # [a, b, c, oscuro vertical] de toda la malla
	var hay := false
	for s in m.get_surface_count():
		var col: Variant = m.surface_get_arrays(s)[Mesh.ARRAY_COLOR]
		if col == null:
			continue
		for c in col:
			if absf(c.r - lineal.r) < TOLERANCIA and absf(c.g - lineal.g) < TOLERANCIA and absf(c.b - lineal.b) < TOLERANCIA:
				hay = true
				break
		if hay:
			break
	if not hay:
		return m.create_trimesh_shape()
	# hay pasos: todos los triángulos, con su normal y si son de la cara oscura
	var grupos := []  # [[centros xz…]]
	for s in m.get_surface_count():
		var a := m.surface_get_arrays(s)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var col: PackedColorArray = a[Mesh.ARRAY_COLOR] if a[Mesh.ARRAY_COLOR] != null else PackedColorArray()
		var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var n_tri := (idx.size() if not idx.is_empty() else v.size()) / 3
		for t in n_tri:
			var i0 := idx[t * 3] if not idx.is_empty() else t * 3
			var i1 := idx[t * 3 + 1] if not idx.is_empty() else t * 3 + 1
			var i2 := idx[t * 3 + 2] if not idx.is_empty() else t * 3 + 2
			var p0 := v[i0]
			var p1 := v[i1]
			var p2 := v[i2]
			var n := (p2 - p0).cross(p1 - p0)  # la cara de frente de Godot va en sentido horario
			n = n.normalized() if n.length_squared() > 1e-12 else Vector3.UP
			var c := col[i0] if not col.is_empty() else Color.WHITE
			var osc := absf(c.r - lineal.r) < TOLERANCIA and absf(c.g - lineal.g) < TOLERANCIA and absf(c.b - lineal.b) < TOLERANCIA \
				and absf(n.y) < 0.3
			tris.append([p0, p1, p2, n, osc])
			if osc:
				for q in [p0, p1, p2]:
					agregar(grupos, Vector2(q.x, q.z))
	var envolventes := []
	for gr in grupos:
		var h := Geometry2D.convex_hull(PackedVector2Array(gr))
		if h.size() >= 4:  # convex_hull cierra el anillo repitiendo el primero
			envolventes.append(h)
	if envolventes.is_empty():  # solo caras oscuras planas (la calle bajo la autopista en 2820, 276)
		return m.create_trimesh_shape()
	var caras := PackedVector3Array()
	var quitados := 0
	for tr in tris:
		var n: Vector3 = tr[3]
		if tr[4] or n.y < ARRIBA:
			var cen: Vector3 = (tr[0] + tr[1] + tr[2]) / 3.0
			var dentro := false
			for h in envolventes:
				if Geometry2D.is_point_in_polygon(Vector2(cen.x, cen.z), h):
					dentro = true
					break
			if dentro or tr[4]:
				quitados += 1
				continue
		caras.append_array([tr[0], tr[1], tr[2]])
	var forma := ConcavePolygonShape3D.new()
	forma.set_faces(caras)
	print("pasos.gd: %d pasos, %d de %d triángulos sin colisión" % [envolventes.size(), quitados, tris.size()])
	return forma


# un punto al grupo de un paso a menos de AGRUPAR de alguno de sus puntos, juntando los grupos que alcanza
static func agregar(grupos: Array, p: Vector2) -> void:
	var mio := -1
	var i := 0
	while i < grupos.size():
		var cerca := false
		for q in grupos[i]:
			if q.distance_squared_to(p) < AGRUPAR * AGRUPAR:
				cerca = true
				break
		if cerca:
			if mio < 0:
				mio = i
				grupos[i].append(p)
			else:
				grupos[mio].append_array(grupos[i])
				grupos.remove_at(i)
				continue
		i += 1
	if mio < 0:
		grupos.append([p])
