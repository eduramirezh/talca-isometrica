# El constructor de mallas del juego, para todos los modelos de modelos/: caras con normal, color por vértice y UV,
# agrupadas por material, y sus triángulos de colisión. Hasta noviembre de 2026 había dos (modelos/entorno/malla.gd y
# modelos/plaza/malla.gd, con G() que significaba cosas distintas); este los junta.
#
# Coordenadas: las de la página. Un punto de grilla (x al oriente, y al norte, h de altura) es Vector3(x, h, -y): P(),
# la única conversión de grilla a Godot del juego. Los modelos se escriben en un marco local (Marco), como los hitos de
# la página (localFrame): u y v en metros, punto(u, v) da el punto de grilla y V(u, v, h) el Vector3. Con A = 90° el
# marco es la grilla misma (u = x, v = y; grilla()).
#
# Dos maneras de llenarla, que se pueden mezclar:
#   - por material del patrón (materiales.gd patron(): ladrillo, baldosa…), en el marco: cara(), piso(), muro(),
#     prisma(), caja(), cilindro(), piramide(), muro_vanos(), superficie(), derrame(), panel(), moldura(); las caras van
#     también a la colisión mientras `solido`, y construir() deja el MeshInstance3D y su StaticBody3D (catedral.gd,
#     fachadas.gd, calles.gd, raices.gd, torre_talca.gd). Para los vanos de una fachada por la coordenada del marco:
#     s_de() y huecos_de();
#   - en Godot, con UV, para un material que se da al final (malla(mat)): tri(), tri_n(), quad(), plano(), muros(),
#     prisma_uv(), bloque(), torno(), tubo() (las piezas de la plaza: plaza.gd, plaza/*.gd), en la capa "".
#
# Las caras se dan con sus puntos en sentido antihorario mirados desde afuera (como en matemática); Godot dibuja la
# cara de frente en sentido horario, así que cara() los invierte. Si se da la normal n, cara() corrige el orden. tri()
# recibe la normal que debe mirar (o, sin ella, toma la de los vértices tal como vienen, en el orden de Godot).
extends RefCounted

const Mat := preload("res://materiales.gd")

var capas := {}  # material -> [posiciones, normales, colores, uv]: PackedVector3Array ×2, PackedColorArray, PackedVector2Array
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

	# el punto de grilla de (u, v)
	func punto(u: float, v: float) -> Vector2:
		return Vector2(X + u * sa + v * ca, Y - u * ca + v * sa)

	func V(u: float, v: float, h: float) -> Vector3:
		var g := punto(u, v)
		return Vector3(g.x, base + h, -g.y)

	# una dirección (nu, nv, ny) del marco, en el mundo
	func N(nu: float, nv: float, ny := 0.0) -> Vector3:
		return Vector3(nu * sa + nv * ca, ny, -(-nu * ca + nv * sa)).normalized()

	# un punto de grilla en (u, v) del marco
	func L(x: float, y: float) -> Vector2:
		var dx := x - X
		var dy := y - Y
		return Vector2(dx * sa - dy * ca, dx * ca + dy * sa)


# metros de grilla (x, y) y altura -> Godot
static func P(x: float, y: float, h: float) -> Vector3:
	return Vector3(x, h, -y)


static func grilla(base := 0.0) -> Marco:
	return Marco.new(0, 0, PI / 2, base)


func _capa(m: String) -> Array:
	if not capas.has(m):
		capas[m] = [PackedVector3Array(), PackedVector3Array(), PackedColorArray(), PackedVector2Array()]
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
			c[3].append(Vector2.ZERO)
		if solido:
			colision.append(p[0]); colision.append(p[i + 1]); colision.append(p[i])
		tris += 1


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


# los huecos de muro_vanos() de una lista de vanos rectangulares [s0, s1, z0, z1, …] (lo que sigue a z1 es de cada
# modelo: el tipo de vano o el paso de los montantes; raices.gd, torre_talca.gd)
static func huecos_de(vanos: Array) -> Array:
	var out := []
	for w in vanos:
		var s0: float = w[0]
		var s1: float = w[1]
		var z0: float = w[2]
		var z1: float = w[3]
		out.append(PackedVector2Array([Vector2(s0, z0), Vector2(s1, z0), Vector2(s1, z1), Vector2(s0, z1)]))
	return out


# s a lo largo de un muro a -> b paralelo a un eje del marco, del punto c de ese eje (u en un muro a lo largo de u, v
# en uno a lo largo de v): para dar los vanos por la coordenada del marco y no por la distancia desde a
static func s_de(a: Vector2, b: Vector2, c: float) -> float:
	var d := (b - a).normalized()
	var p := Vector2(c, a.y) if absf(d.x) > 0.5 else Vector2(a.x, c)
	return (p - a).dot(d)


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


# El CollisionShape3D de una forma cóncava, sin que la arme dos veces. Con la depuración (el binario de siempre, no una
# exportación de lanzamiento), set_shape() le pasa a la forma el color de depuración del CollisionShape3D, y una
# ConcavePolygonShape3D que cambia de color le manda de nuevo sus caras al servidor de física, que rehace su árbol: con
# los patios de una tesela, ~25 ms en el hilo principal. El color de la forma por omisión es el transparente: con el
# mismo, set_shape() no la toca (en «Visible Collision Shapes» estas no se ven)
static func colisionador(forma: Shape3D) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	cs.debug_color = Color(0, 0, 0, 0)
	cs.shape = forma
	return cs


static func concava(caras: PackedVector3Array) -> ConcavePolygonShape3D:
	var s := ConcavePolygonShape3D.new()
	s.backface_collision = true
	s.set_faces(caras)
	return s


# solo la colisión (sin malla): para un constructor que junta formas simples (las cajas de los edificios y los autos);
# devuelve el cuerpo (null si no hay caras), para marcarlo (la meta «tobogan» de modelos/juegos_alameda.gd)
func construir_colision(padre: Node3D, nombre: String) -> StaticBody3D:
	if colision.is_empty():
		return null
	var cuerpo := StaticBody3D.new()
	cuerpo.name = nombre
	cuerpo.add_child(colisionador(concava(colision)))
	padre.add_child(cuerpo)
	return cuerpo


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
		am.surface_set_material(am.get_surface_count() - 1, Mat.patron(m))
	var mi := MeshInstance3D.new()
	mi.name = nombre
	mi.mesh = am
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if sombra else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	padre.add_child(mi)
	print("malla.gd: %s, %d triángulos (%d de colisión)" % [nombre, tris, colision.size() / 3])
	if not colision.is_empty():
		var cuerpo := StaticBody3D.new()
		cuerpo.name = nombre + "-colision"
		cuerpo.add_child(colisionador(concava(colision)))
		mi.add_child(cuerpo)
	return mi


# ---------------------------------------------------------------- en Godot, con UV (capa "": malla(mat))

func vacia() -> bool:
	for m in capas:
		if not capas[m][0].is_empty():
			return false
	return true


var _d := []  # la capa "", a mano (una búsqueda menos por triángulo)


func _emitir(a: Vector3, b: Vector3, d: Vector3, na: Vector3, nb: Vector3, nd: Vector3, ca: Color, cb: Color, cd: Color,
		ua: Vector2, ub: Vector2, ud: Vector2) -> void:
	if _d.is_empty():
		_d = _capa("")
	var k := _d
	k[0].append_array([a, b, d])
	k[1].append_array([na, nb, nd])
	k[2].append_array([ca, cb, cd])
	k[3].append_array([ua, ub, ud])


# un triángulo con normal plana (nn: la que debe mirar; si es cero, la geométrica tal como vienen los vértices)
func tri(a: Vector3, b: Vector3, d: Vector3, col: Color, nn := Vector3.ZERO, ua := Vector2.ZERO, ub := Vector2.ZERO, ud := Vector2.ZERO) -> void:
	var g := (d - a).cross(b - a)
	if nn == Vector3.ZERO:
		nn = g.normalized()
	elif g.dot(nn) < 0:
		var t := b; b = d; d = t
		var tu := ub; ub = ud; ud = tu
	_emitir(a, b, d, nn, nn, nn, col, col, col, ua, ub, ud)


# un triángulo con una normal por vértice (superficies suaves); el orden lo decide la suma de las normales
func tri_n(a: Vector3, b: Vector3, d: Vector3, na: Vector3, nb: Vector3, nd: Vector3, ca: Color, cb: Color, cd: Color,
		ua := Vector2.ZERO, ub := Vector2.ZERO, ud := Vector2.ZERO) -> void:
	if (d - a).cross(b - a).dot(na + nb + nd) < 0:
		var t := b; b = d; d = t
		var tn := nb; nb = nd; nd = tn
		var tc := cb; cb = cd; cd = tc
		var tu := ub; ub = ud; ud = tu
	_emitir(a, b, d, na, nb, nd, ca, cb, cd, ua, ub, ud)


func quad(a: Vector3, b: Vector3, d: Vector3, e: Vector3, col: Color, nn := Vector3.ZERO, uvs := []) -> void:
	if nn == Vector3.ZERO:
		nn = (d - a).cross(b - a).normalized()
		if nn == Vector3.ZERO:
			return
	var u: Array = uvs if uvs.size() == 4 else [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	tri(a, b, d, col, nn, u[0], u[1], u[2])
	tri(a, d, e, col, nn, u[0], u[2], u[3])


# un polígono horizontal (puntos de grilla) a la altura h, mirando arriba (o abajo); triangula de verdad (cóncavos)
func plano(pol: PackedVector2Array, h: float, col: Color, arriba := true) -> void:
	var t := Geometry2D.triangulate_polygon(pol)
	var nn := Vector3.UP if arriba else Vector3.DOWN
	for i in range(0, t.size(), 3):
		var a := pol[t[i]]
		var b := pol[t[i + 1]]
		var d := pol[t[i + 2]]
		tri(P(a.x, a.y, h), P(b.x, b.y, h), P(d.x, d.y, h), col, nn, a, b, d)


# los muros de un polígono de grilla entre h0 y h1, mirando hacia afuera (o adentro); uv: (largo recorrido, altura)
func muros(pol: PackedVector2Array, h0: float, h1: float, col: Color, afuera := true) -> void:
	var s := 1.0 if area(pol) > 0 else -1.0
	if not afuera:
		s = -s
	var largo := 0.0
	for i in pol.size():
		var a := pol[i]
		var b := pol[(i + 1) % pol.size()]
		var d := b - a
		if d.length() < 1e-4:
			continue
		var nn := Vector3(d.y * s, 0, d.x * s).normalized()  # (dy, -dx) en grilla -> Godot (dy, 0, dx)
		var l := d.length()
		quad(P(a.x, a.y, h0), P(b.x, b.y, h0), P(b.x, b.y, h1), P(a.x, a.y, h1), col, nn,
			[Vector2(largo, h0), Vector2(largo + l, h0), Vector2(largo + l, h1), Vector2(largo, h1)])
		largo += l


# muros() y, si tapa, plano(): el prisma de un polígono de grilla con UV (prisma() es el del marco, sin UV)
func prisma_uv(pol: PackedVector2Array, h0: float, h1: float, col_muro: Color, col_tapa: Color, tapa := true) -> void:
	muros(pol, h0, h1, col_muro)
	if tapa:
		plano(pol, h1, col_tapa)


# una caja de lado s centrada en p (Godot), girada `giro` radianes en torno al eje vertical (caja() es la del marco)
func bloque(p: Vector3, s: Vector3, col: Color, giro := 0.0, col_tapa := Color(0, 0, 0, 0), base := false) -> void:
	var bs := Basis(Vector3.UP, giro)
	var h := s / 2
	var Q := func(x: float, y: float, z: float) -> Vector3: return p + bs * Vector3(x * h.x, y * h.y, z * h.z)
	var ct := col if col_tapa.a == 0 else col_tapa
	quad(Q.call(-1, -1, 1), Q.call(1, -1, 1), Q.call(1, 1, 1), Q.call(-1, 1, 1), col, bs * Vector3.BACK)
	quad(Q.call(1, -1, -1), Q.call(-1, -1, -1), Q.call(-1, 1, -1), Q.call(1, 1, -1), col, bs * Vector3.FORWARD)
	quad(Q.call(1, -1, 1), Q.call(1, -1, -1), Q.call(1, 1, -1), Q.call(1, 1, 1), col, bs * Vector3.RIGHT)
	quad(Q.call(-1, -1, -1), Q.call(-1, -1, 1), Q.call(-1, 1, 1), Q.call(-1, 1, -1), col, bs * Vector3.LEFT)
	quad(Q.call(-1, 1, 1), Q.call(1, 1, 1), Q.call(1, 1, -1), Q.call(-1, 1, -1), ct, Vector3.UP)
	if base:
		quad(Q.call(-1, -1, -1), Q.call(1, -1, -1), Q.call(1, -1, 1), Q.call(-1, -1, 1), col, Vector3.DOWN)


# un sólido de revolución en torno al eje vertical por p: perfil [Vector2(radio, altura), ...] de abajo arriba,
# k lados, normales suaves; uv: (vuelta, largo del perfil). col puede ser un Color o un Callable(i_perfil) -> Color
func torno(p: Vector3, perfil: Array, k: int, col: Variant, a0 := 0.0, suave := true) -> void:
	var largo := [0.0]
	for i in range(1, perfil.size()):
		largo.append(largo[i - 1] + (perfil[i] - perfil[i - 1]).length())
	for i in perfil.size() - 1:
		var p0: Vector2 = perfil[i]
		var p1: Vector2 = perfil[i + 1]
		var dr := p1 - p0
		var c0: Color = col.call(i) if col is Callable else col
		var c1: Color = col.call(i + 1) if col is Callable else col
		if not suave:
			c1 = c0
		for j in k:
			var t0 := a0 + TAU * j / k
			var t1 := a0 + TAU * (j + 1) / k
			var e0 := Vector3(cos(t0), 0, sin(t0))
			var e1 := Vector3(cos(t1), 0, sin(t1))
			var a := p + e0 * p0.x + Vector3.UP * p0.y
			var b := p + e1 * p0.x + Vector3.UP * p0.y
			var d := p + e1 * p1.x + Vector3.UP * p1.y
			var e := p + e0 * p1.x + Vector3.UP * p1.y
			var tm := (t0 + t1) / 2
			# (radial, vertical): el perfil se recorre con el sólido a su izquierda (afuera subiendo, adentro de un
			# tazón bajando), así un anillo que se abre mira abajo y uno que se cierra, arriba
			var nr := Vector2(dr.y, -dr.x).normalized()
			var n0 := (e0 * nr.x + Vector3.UP * nr.y).normalized()
			var n1 := (e1 * nr.x + Vector3.UP * nr.y).normalized()
			if not suave:
				var em := Vector3(cos(tm), 0, sin(tm))
				n0 = (em * nr.x + Vector3.UP * nr.y).normalized()
				n1 = n0
			var u0 := float(j) / k
			var u1 := float(j + 1) / k
			if (a - e).length() > 1e-5 or (b - d).length() > 1e-5:
				if (a - b).length() > 1e-6:
					tri_n(a, b, d, n0, n1, n1, c0, c0, c1, Vector2(u0, largo[i]), Vector2(u1, largo[i]), Vector2(u1, largo[i + 1]))
				if (d - e).length() > 1e-6:
					tri_n(a, d, e, n0, n1, n0, c0, c1, c1, Vector2(u0, largo[i]), Vector2(u1, largo[i + 1]), Vector2(u0, largo[i + 1]))


# un cilindro (o tronco de cono) entre dos puntos cualesquiera, k lados, sin tapas: ramas, columnas inclinadas
func tubo(a: Vector3, b: Vector3, ra: float, rb: float, k: int, col_a: Color, col_b: Color, va := 0.0, vb := 1.0) -> void:
	var eje := b - a
	if eje.length() < 1e-4:
		return
	var w := eje.normalized()
	# un marco que cambia poco entre tramos casi paralelos (troncos curvos sin grietas en las uniones)
	var ref := Vector3.FORWARD if abs(w.z) < 0.9 else Vector3.RIGHT
	var u := (ref - w * ref.dot(w)).normalized()
	var q := w.cross(u)
	b = b + w * min(rb, 0.05) * 0.5  # se monta un poco en el tramo siguiente
	var pend := (ra - rb) / eje.length()
	for j in k:
		var t0 := TAU * j / k
		var t1 := TAU * (j + 1) / k
		var d0 := u * cos(t0) + q * sin(t0)
		var d1 := u * cos(t1) + q * sin(t1)
		var n0 := (d0 + w * pend).normalized()
		var n1 := (d1 + w * pend).normalized()
		var u0 := float(j) / k
		var u1 := float(j + 1) / k
		tri_n(a + d0 * ra, a + d1 * ra, b + d1 * rb, n0, n1, n1, col_a, col_a, col_b, Vector2(u0, va), Vector2(u1, va), Vector2(u1, vb))
		tri_n(a + d0 * ra, b + d1 * rb, b + d0 * rb, n0, n1, n0, col_a, col_b, col_b, Vector2(u0, va), Vector2(u1, vb), Vector2(u0, vb))


static func area(pol: PackedVector2Array) -> float:
	var a := 0.0
	for i in pol.size():
		var p := pol[i]
		var r := pol[(i + 1) % pol.size()]
		a += p.x * r.y - r.x * p.y
	return a / 2


# el polígono corrido d hacia adentro (d < 0: afuera), con el mismo número de vértices (inglete acotado), como `inset`
# del hito de la página
static func adentro(pol: PackedVector2Array, d: float) -> PackedVector2Array:
	var s := 1.0 if area(pol) > 0 else -1.0
	var k := pol.size()
	var out := PackedVector2Array()
	for i in k:
		var p := pol[i]
		var a := pol[(i + k - 1) % k]
		var b := pol[(i + 1) % k]
		var l1: float = max((p - a).length(), 1e-6)
		var l2: float = max((b - p).length(), 1e-6)
		var n1 := Vector2(-(p.y - a.y) / l1 * s, (p.x - a.x) / l1 * s)
		var n2 := Vector2(-(b.y - p.y) / l2 * s, (b.x - p.x) / l2 * s)
		var f: float = max(0.35, 1 + n1.dot(n2))
		out.append(p + (n1 + n2) * d / f)
	return out


# una lista plana [x0, y0, x1, y1, ...] como polígono
static func pol(a: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(0, a.size(), 2):
		out.append(Vector2(a[i], a[i + 1]))
	return out


# una copia de la capa "" con uno de cada k cuadriláteros (6 vértices cada uno): para mallas hechas solo de tarjetas
func cada(k: int) -> RefCounted:
	var o: RefCounted = get_script().new()
	var a := _capa("")
	var b: Array = o._capa("")
	if k <= 1:
		for i in 4:
			b[i] = a[i]
		return o
	for q in range(0, a[0].size() / 6, k):
		for j in range(q * 6, q * 6 + 6):
			for i in 4:
				b[i].append(a[i][j])
	return o


# las capas como un ArrayMesh (o agregadas a `previa`): la capa "" con el material mat (sin él, ninguno); las del
# patrón, con el suyo
func malla(mat: Material = null, previa: ArrayMesh = null) -> ArrayMesh:
	var m := previa if previa else ArrayMesh.new()
	for nombre in capas:
		var c: Array = capas[nombre]
		if c[0].is_empty():
			continue
		var a := []
		a.resize(Mesh.ARRAY_MAX)
		a[Mesh.ARRAY_VERTEX] = c[0]
		a[Mesh.ARRAY_NORMAL] = c[1]
		a[Mesh.ARRAY_COLOR] = c[2]
		a[Mesh.ARRAY_TEX_UV] = c[3]
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
		var sm: Material = mat if nombre == "" else Mat.patron(nombre)
		if sm:
			m.surface_set_material(m.get_surface_count() - 1, sm)
	return m


# las caras de todas las capas como lista para una forma de colisión cóncava (ConcavePolygonShape3D)
func caras() -> PackedVector3Array:
	var out := PackedVector3Array()
	for m in capas:
		out.append_array(capas[m][0])
	return out
