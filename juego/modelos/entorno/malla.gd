# Constructor de mallas para los modelos del entorno: caras con color por vértice agrupadas por material
# (materiales.gd), y sus triángulos de colisión. Al final, construir() deja un MeshInstance3D (una superficie por
# material) y, si hubo caras sólidas, un StaticBody3D con su forma exacta.
#
# Coordenadas: las de la página. Un punto de grilla (x al oriente, y al norte, h de altura) es Vector3(x, h, -y)
# (P()). Los modelos se escriben en un marco local (Marco), como los hitos de la página (localFrame): u y v en metros,
# G(u, v) da el punto de grilla y V(u, v, h) el Vector3. Con A = 90° el marco es la grilla misma (u = x, v = y).
#
# Las caras se dan con sus puntos en sentido antihorario mirados desde afuera (como en matemática); Godot dibuja la
# cara de frente en sentido horario, así que cara() los invierte. Si se da la normal n, cara() corrige el orden.
extends RefCounted

const M := preload("res://modelos/entorno/materiales.gd")

var capas := {}  # material -> [PackedVector3Array posiciones, PackedVector3Array normales, PackedColorArray colores]
var colision := PackedVector3Array()
var solido := true  # las caras que se agregan van también a la colisión
var tris := 0


class Marco:
	var X: float
	var Y: float
	var sa: float
	var ca: float
	var base: float  # altura del suelo del marco: V() le suma esto

	func _init(x: float, y: float, a: float, b := 0.0) -> void:
		X = x; Y = y; sa = sin(a); ca = cos(a); base = b

	func G(u: float, v: float) -> Vector2:
		return Vector2(X + u * sa + v * ca, Y - u * ca + v * sa)

	func V(u: float, v: float, h: float) -> Vector3:
		var g := G(u, v)
		return Vector3(g.x, base + h, -g.y)

	# una dirección (nu, nv, ny) del marco, en el mundo
	func N(nu: float, nv: float, ny := 0.0) -> Vector3:
		return Vector3(nu * sa + nv * ca, ny, -(-nu * ca + nv * sa)).normalized()

	# un punto de grilla en (u, v) del marco
	func L(x: float, y: float) -> Vector2:
		var dx := x - X
		var dy := y - Y
		return Vector2(dx * sa - dy * ca, dx * ca + dy * sa)


static func P(x: float, y: float, h: float) -> Vector3:
	return Vector3(x, h, -y)


static func grilla(base := 0.0) -> Marco:
	return Marco.new(0, 0, PI / 2, base)


func _capa(m: String) -> Array:
	if not capas.has(m):
		capas[m] = [PackedVector3Array(), PackedVector3Array(), PackedColorArray()]
	return capas[m]


# un polígono convexo (o en abanico desde el primero) con puntos antihorarios vistos desde afuera
func cara(p: Array, col: Color, mat := "liso", n := Vector3.ZERO) -> void:
	var k := p.size()
	if k < 3:
		return
	var nw := Vector3.ZERO  # normal de Newell, con el orden dado (regla de la mano derecha)
	for i in k:
		var a: Vector3 = p[i]
		var b: Vector3 = p[(i + 1) % k]
		nw += Vector3((a.y - b.y) * (a.z + b.z), (a.z - b.z) * (a.x + b.x), (a.x - b.x) * (a.y + b.y))
	if nw.length_squared() < 1e-12:
		return
	nw = nw.normalized()
	if n == Vector3.ZERO:
		n = nw
	elif nw.dot(n) < 0:
		p = p.duplicate()
		p.reverse()
	var c := _capa(mat)
	for i in range(1, k - 1):
		for q in [p[0], p[i + 1], p[i]]:  # horario para Godot
			c[0].append(q)
			c[1].append(n)
			c[2].append(col)
		if solido:
			colision.append(p[0]); colision.append(p[i + 1]); colision.append(p[i])
		tris += 1


func tri(a: Vector3, b: Vector3, c: Vector3, col: Color, mat := "liso", n := Vector3.ZERO) -> void:
	cara([a, b, c], col, mat, n)


# un polígono plano cualquiera (cóncavo) en el marco f a la altura h (o con altura por punto: alt.call(u, v)),
# mirando hacia arriba (o hacia abajo con abajo = true)
func piso(f: Marco, poli: PackedVector2Array, h: float, col: Color, mat := "liso", alt := Callable(), abajo := false) -> void:
	var idx := Geometry2D.triangulate_polygon(poli)
	if idx.is_empty():
		return
	var n := Vector3.DOWN if abajo else Vector3.UP
	for t in range(0, idx.size(), 3):
		var q := []
		for j in 3:
			var p := poli[idx[t + j]]
			q.append(f.V(p.x, p.y, alt.call(p.x, p.y) if alt.is_valid() else h))
		cara(q, col, mat, n)


# un muro de a a b (en u, v del marco) entre h0 y h1, mirando hacia afuera = a la derecha de a -> b
func muro(f: Marco, a: Vector2, b: Vector2, h0: float, h1: float, col: Color, mat := "liso") -> void:
	var d := (b - a).normalized()
	cara([f.V(a.x, a.y, h0), f.V(b.x, b.y, h0), f.V(b.x, b.y, h1), f.V(a.x, a.y, h1)], col, mat, f.N(d.y, -d.x))


# un prisma sobre un polígono antihorario (u, v): muros y, si tapa, la cara de arriba (otro color: ctapa)
func prisma(f: Marco, poli: PackedVector2Array, h0: float, h1: float, col: Color, mat := "liso", tapa := true,
		ctapa: Variant = null, mtapa := "", base := false) -> void:
	if Geometry2D.is_polygon_clockwise(poli):
		poli = poli.duplicate()
		poli.reverse()
	for i in poli.size():
		muro(f, poli[i], poli[(i + 1) % poli.size()], h0, h1, col, mat)
	if tapa:
		piso(f, poli, h1, col if ctapa == null else ctapa, mat if mtapa == "" else mtapa)
	if base:
		piso(f, poli, h0, col, mat, Callable(), true)


func rect(u0: float, v0: float, u1: float, v1: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), Vector2(u0, v1)])


# una caja alineada al marco
func caja(f: Marco, u0: float, v0: float, u1: float, v1: float, h0: float, h1: float, col: Color, mat := "liso",
		ctapa: Variant = null, base := false) -> void:
	prisma(f, rect(min(u0, u1), min(v0, v1), max(u0, u1), max(v0, v1)), h0, h1, col, mat, true, ctapa, "", base)


# un polígono regular (centro, radio, lados, giro) como PackedVector2Array antihorario
static func ngon(cu: float, cv: float, r: float, n: int, a0 := 0.0) -> PackedVector2Array:
	var o := PackedVector2Array()
	for i in n:
		var t := a0 + TAU * i / n
		o.append(Vector2(cu + r * cos(t), cv + r * sin(t)))
	return o


# un cilindro vertical (n lados) en el marco
func cilindro(f: Marco, cu: float, cv: float, r: float, h0: float, h1: float, col: Color, mat := "liso", n := 10,
		tapa := true) -> void:
	prisma(f, ngon(cu, cv, r, n), h0, h1, col, mat, tapa)


# una pirámide sobre un polígono convexo, con la punta a la altura hp sobre (cu, cv)
func piramide(f: Marco, poli: PackedVector2Array, h0: float, hp: float, cu: float, cv: float, col: Color, mat := "liso") -> void:
	if Geometry2D.is_polygon_clockwise(poli):
		poli = poli.duplicate()
		poli.reverse()
	var top := f.V(cu, cv, hp)
	for i in poli.size():
		var a := poli[i]
		var b := poli[(i + 1) % poli.size()]
		var pa := f.V(a.x, a.y, h0)
		var pb := f.V(b.x, b.y, h0)
		cara([pa, pb, top], col, mat, (pb - pa).cross(top - pa).normalized())


# un arco de medio punto (o rebajado) como polígono en (s, h) de un muro: ancho w, de h0 al arranque ha, flecha r
static func arco(s: float, w: float, h0: float, ha: float, flecha := -1.0, n := 10) -> PackedVector2Array:
	var r := w / 2.0
	var f := r if flecha < 0 else flecha
	var o := PackedVector2Array([Vector2(s - r, h0), Vector2(s + r, h0)])
	for i in range(0, n + 1):
		var t := PI * i / n
		o.append(Vector2(s + r * cos(t), ha + f * sin(t)))
	return o


# un muro plano en el marco con vanos: la cara entre a y b (u, v), de h0 a h1, menos los huecos dados como polígonos
# en (s, h), s a lo largo del muro desde a. Se triangula por franjas: los huecos deben ser convexos y no tocarse.
func muro_vanos(f: Marco, a: Vector2, b: Vector2, h0: float, h1: float, huecos: Array, col: Color, mat := "liso") -> void:
	var L := a.distance_to(b)
	superficie(f, a, b, PackedVector2Array([Vector2(0, h0), Vector2(L, h0), Vector2(L, h1), Vector2(0, h1)]), huecos, col, mat)


# lo mismo con un contorno cualquiera en (s, h) (un hastial, el fondo de un arco), sobre la línea a -> b
func superficie(f: Marco, a: Vector2, b: Vector2, contorno: PackedVector2Array, huecos: Array, col: Color, mat := "liso") -> void:
	var L := a.distance_to(b)
	var d := (b - a) / L
	var n := f.N(d.y, -d.x)
	var s0c := INF
	var s1c := -INF
	var h0 := INF
	var h1 := -INF
	for p in contorno:
		s0c = min(s0c, p.x); s1c = max(s1c, p.x); h0 = min(h0, p.y); h1 = max(h1, p.y)
	L = s1c
	var cortes := [s0c, s1c]
	for hq in huecos:
		var s0 := INF
		var s1 := -INF
		for p in hq:
			s0 = min(s0, p.x); s1 = max(s1, p.x)
		cortes.append(clamp(s0, s0c, L)); cortes.append(clamp(s1, s0c, L))
	cortes.sort()
	var W := func(s: float, h: float) -> Vector3: return f.V(a.x + d.x * s, a.y + d.y * s, h)
	for i in cortes.size() - 1:
		var s0: float = cortes[i]
		var s1: float = cortes[i + 1]
		if s1 - s0 < 1e-4:
			continue
		var franja := PackedVector2Array([Vector2(s0, h0 - 1), Vector2(s1, h0 - 1), Vector2(s1, h1 + 1), Vector2(s0, h1 + 1)])
		var piezas := Geometry2D.intersect_polygons(franja, contorno).filter(func(x): return not Geometry2D.is_polygon_clockwise(x))
		for hq in huecos:
			var nuevas := []
			for pz in piezas:
				for r in Geometry2D.clip_polygons(pz, hq):
					if not Geometry2D.is_polygon_clockwise(r):
						nuevas.append(r)
			piezas = nuevas
		for pz in piezas:
			var idx := Geometry2D.triangulate_polygon(pz)
			for t in range(0, idx.size(), 3):
				var q := [W.call(pz[idx[t]].x, pz[idx[t]].y), W.call(pz[idx[t + 1]].x, pz[idx[t + 1]].y), W.call(pz[idx[t + 2]].x, pz[idx[t + 2]].y)]
				cara(q, col, mat, n)


# el derrame (los costados hacia adentro) de un hueco de un muro: un hueco de puntos (s, h) en el muro a -> b,
# hundido prof m; con fondo, un panel (vidrio, puerta) al fondo
func derrame(f: Marco, a: Vector2, b: Vector2, hq: PackedVector2Array, prof: float, col: Color, mat := "liso",
		fondo: Variant = null, mfondo := "vidrio") -> void:
	var L := a.distance_to(b)
	var d := (b - a) / L
	var o := Vector2(d.y, -d.x)  # hacia afuera
	var W := func(s: float, h: float, p: float) -> Vector3:
		return f.V(a.x + d.x * s - o.x * p, a.y + d.y * s - o.y * p, h)
	var k := hq.size()
	var cw := Geometry2D.is_polygon_clockwise(hq)
	for i in k:
		var p := hq[i]
		var q := hq[(i + 1) % k]
		var e := q - p
		var nin := Vector2(-e.y, e.x).normalized() if not cw else Vector2(e.y, -e.x).normalized()  # hacia el centro del hueco
		var n3: Vector3 = f.N(d.x * nin.x, d.y * nin.x, nin.y)
		cara([W.call(p.x, p.y, 0.0), W.call(q.x, q.y, 0.0), W.call(q.x, q.y, prof), W.call(p.x, p.y, prof)], col, mat, n3)
	if fondo != null:
		var idx := Geometry2D.triangulate_polygon(hq)
		var nf := f.N(o.x, o.y)
		for t in range(0, idx.size(), 3):
			cara([W.call(hq[idx[t]].x, hq[idx[t]].y, prof), W.call(hq[idx[t + 1]].x, hq[idx[t + 1]].y, prof),
				W.call(hq[idx[t + 2]].x, hq[idx[t + 2]].y, prof)], fondo, mfondo, nf)


# un panel plano sobre un muro a -> b: el rectángulo (s0..s1, h0..h1), separado o m del muro (hacia afuera)
func panel(f: Marco, a: Vector2, b: Vector2, s0: float, s1: float, h0: float, h1: float, o: float, col: Color, mat := "liso") -> void:
	var L := a.distance_to(b)
	var d := (b - a) / L
	var ou := Vector2(d.y, -d.x)
	var W := func(s: float, h: float) -> Vector3: return f.V(a.x + d.x * s + ou.x * o, a.y + d.y * s + ou.y * o, h)
	cara([W.call(s0, h0), W.call(s1, h0), W.call(s1, h1), W.call(s0, h1)], col, mat, f.N(ou.x, ou.y))


# una moldura (caja) adosada a un muro a -> b: de s0 a s1, de h0 a h1, saliendo sal m
func moldura(f: Marco, a: Vector2, b: Vector2, s0: float, s1: float, h0: float, h1: float, sal: float, col: Color,
		mat := "liso", desde := 0.0) -> void:
	var L := a.distance_to(b)
	var d := (b - a) / L
	var ou := Vector2(d.y, -d.x)
	var pt := func(s: float, p: float) -> Vector2: return a + d * s + ou * p
	var q := PackedVector2Array([pt.call(s0, desde), pt.call(s1, desde), pt.call(s1, sal), pt.call(s0, sal)])
	prisma(f, q, h0, h1, col, mat, true, null, "", h0 > 0.5)


# solo la colisión (sin malla): para un constructor que junta formas simples (las cajas de los edificios y los autos)
func construir_colision(padre: Node3D, nombre: String) -> void:
	if colision.is_empty():
		return
	var cuerpo := StaticBody3D.new()
	cuerpo.name = nombre
	var forma := CollisionShape3D.new()
	var s := ConcavePolygonShape3D.new()
	s.backface_collision = true
	s.set_faces(colision)
	forma.shape = s
	cuerpo.add_child(forma)
	padre.add_child(cuerpo)


func construir(padre: Node3D, nombre: String, sombra := true) -> MeshInstance3D:
	var am := ArrayMesh.new()
	for m in capas:
		var c: Array = capas[m]
		if c[0].is_empty():
			continue
		var a := []
		a.resize(Mesh.ARRAY_MAX)
		a[Mesh.ARRAY_VERTEX] = c[0]
		a[Mesh.ARRAY_NORMAL] = c[1]
		a[Mesh.ARRAY_COLOR] = c[2]
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
		am.surface_set_material(am.get_surface_count() - 1, M.mat(m))
	var mi := MeshInstance3D.new()
	mi.name = nombre
	mi.mesh = am
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if sombra else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	padre.add_child(mi)
	print("malla.gd: %s, %d triángulos (%d de colisión)" % [nombre, tris, colision.size() / 3])
	if not colision.is_empty():
		var cuerpo := StaticBody3D.new()
		cuerpo.name = nombre + "-colision"
		var forma := CollisionShape3D.new()
		var s := ConcavePolygonShape3D.new()
		s.backface_collision = true
		s.set_faces(colision)
		forma.shape = s
		cuerpo.add_child(forma)
		mi.add_child(cuerpo)
	return mi
