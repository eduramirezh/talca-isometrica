# Las armas del personaje (armas.gd), hechas en código: un cuchillo, una pistola y un rifle de asalto. Cada una es un
# Node3D con una malla de colores por vértice (como las piezas de vehiculo.gd: un material por acabado, sin el dibujo de
# patron.gdshader, que está en coordenadas del mundo y se deslizaría sobre algo que se mueve) y unos puntos con nombre,
# que peaton.gd y armas.gd leen:
#   el origen   la palma de la mano derecha en la empuñadura (peaton.gd lo pone en mano[DER])
#   «apoyo»     la palma izquierda: bajo el guardamanos del rifle, envolviendo la derecha en la pistola
#   «cargador»  donde la mano izquierda lo cambia al recargar
#   «boca»      el extremo del cañón: el fogonazo y la trazadora (en el cuchillo, «punta»)
#   «culata»    lo que va en el hombro (el rifle)
# Marco: el cañón (o la hoja) hacia -Z, arriba +Y, la derecha +X, en metros. Las medidas, de una pistola de polímero de
# 9 mm (~19 cm de largo, como una Glock 17), un fusil de 5,56 mm con culata plegada (~0,9 m: un M4 con el guardamanos y
# la culata color arena) y un cuchillo de 24 cm con 17 de hoja; los detalles de menos de 5 mm no se dibujan.
#
#   const Modelos := preload("res://modelos/entorno/armas.gd")
#   var r := Modelos.rifle()        # Node3D; r.get_node("boca").position
extends RefCounted

const Malla := preload("res://malla.gd")

const NEGRO := Color(0.06, 0.06, 0.065)  # el polímero
const PAVON := Color(0.14, 0.145, 0.155)  # el acero pavonado de la corredera y el cañón
const ARENA := Color(0.58, 0.5, 0.36)  # el guardamanos, la empuñadura y la culata del rifle
const ACERO := Color(0.74, 0.76, 0.78)  # la hoja
const GOMA := Color(0.09, 0.09, 0.09)


static func pistola() -> Node3D:
	var m := nueva()
	var raya := Basis(Vector3.RIGHT, -0.3)  # la empuñadura, inclinada hacia atrás
	caja(m, Vector3(0, -0.01, 0.012), Vector3(0.029, 0.105, 0.048), NEGRO, "", raya)
	caja(m, Vector3(0, -0.061, 0.028), Vector3(0.031, 0.009, 0.05), NEGRO, "", raya)  # la base del cargador
	caja(m, Vector3(0, 0.052, -0.045), Vector3(0.027, 0.022, 0.13), NEGRO)  # el armazón
	caja(m, Vector3(0, 0.077, -0.05), Vector3(0.025, 0.03, 0.186), PAVON, "metal")  # la corredera
	caja(m, Vector3(0, 0.0945, -0.137), Vector3(0.004, 0.006, 0.007), PAVON, "metal")  # el alza y el guión
	caja(m, Vector3(0, 0.0945, 0.035), Vector3(0.017, 0.006, 0.007), PAVON, "metal")
	cilindro(m, Vector3(0, 0.072, -0.142), Vector3(0, 0.072, -0.146), 0.0065, Color(0.02, 0.02, 0.02), "metal")
	caja(m, Vector3(0, 0.0225, -0.044), Vector3(0.009, 0.005, 0.05), NEGRO)  # el guardamonte
	caja(m, Vector3(0, 0.031, -0.068), Vector3(0.009, 0.02, 0.005), NEGRO)
	caja(m, Vector3(0, 0.034, -0.036), Vector3(0.005, 0.016, 0.006), PAVON, "metal")  # el gatillo
	var n := armar(m, "pistola")
	marca(n, "boca", Vector3(0, 0.072, -0.15))
	marca(n, "apoyo", Vector3(-0.045, -0.022, 0.004))
	marca(n, "cargador", Vector3(0, -0.075, 0.032))
	return n


static func rifle() -> Node3D:
	var m := nueva()
	caja(m, Vector3(0, -0.005, 0.01), Vector3(0.03, 0.1, 0.042), ARENA, "", Basis(Vector3.RIGHT, -0.38))  # la empuñadura
	caja(m, Vector3(0, 0.065, -0.03), Vector3(0.036, 0.05, 0.2), NEGRO)  # el cajón de los mecanismos
	caja(m, Vector3(0, 0.112, -0.035), Vector3(0.04, 0.045, 0.21), PAVON, "metal")
	caja(m, Vector3(0, 0.139, -0.035), Vector3(0.022, 0.008, 0.2), NEGRO)  # el riel de arriba
	caja(m, Vector3(0, 0.162, -0.02), Vector3(0.03, 0.038, 0.06), NEGRO)  # la mira de punto rojo
	caja(m, Vector3(0, 0.166, -0.051), Vector3(0.022, 0.024, 0.004), Color(0.25, 0.45, 0.42), "metal")
	caja(m, Vector3(0, 0.128, 0.068), Vector3(0.05, 0.01, 0.016), NEGRO)  # la palanca de carga
	caja(m, Vector3(0, 0.108, -0.29), Vector3(0.052, 0.052, 0.32), ARENA)  # el guardamanos
	caja(m, Vector3(0, 0.135, -0.29), Vector3(0.016, 0.008, 0.3), NEGRO)  # su riel
	caja(m, Vector3(0, 0.13, -0.468), Vector3(0.03, 0.05, 0.025), NEGRO)  # el bloque de gases y el guión
	caja(m, Vector3(0, 0.168, -0.468), Vector3(0.006, 0.03, 0.01), NEGRO)
	cilindro(m, Vector3(0, 0.11, -0.45), Vector3(0, 0.11, -0.56), 0.0105, PAVON, "metal")  # el cañón
	cilindro(m, Vector3(0, 0.11, -0.56), Vector3(0, 0.11, -0.6), 0.0135, NEGRO, "metal")  # la bocacha
	caja(m, Vector3(0, -0.035, -0.095), Vector3(0.026, 0.17, 0.065), NEGRO, "", Basis(Vector3.RIGHT, 0.22))  # el cargador
	caja(m, Vector3(0, 0.03, -0.06), Vector3(0.008, 0.006, 0.07), NEGRO)  # el guardamonte
	caja(m, Vector3(0, 0.04, -0.045), Vector3(0.005, 0.018, 0.006), PAVON, "metal")  # el gatillo
	cilindro(m, Vector3(0, 0.1, 0.07), Vector3(0, 0.1, 0.2), 0.016, NEGRO)  # el tubo de la culata
	caja(m, Vector3(0, 0.085, 0.215), Vector3(0.042, 0.085, 0.13), ARENA)  # la culata
	caja(m, Vector3(0, 0.077, 0.285), Vector3(0.044, 0.11, 0.02), GOMA)  # la cantonera
	var n := armar(m, "rifle")
	marca(n, "boca", Vector3(0, 0.11, -0.605))
	marca(n, "apoyo", Vector3(-0.012, 0.055, -0.3))
	marca(n, "cargador", Vector3(0, -0.095, -0.12))
	marca(n, "culata", Vector3(0, 0.085, 0.295))
	return n


static func cuchillo() -> Node3D:
	var m := nueva()
	caja(m, Vector3(0, 0, 0.0025), Vector3(0.024, 0.03, 0.105), GOMA)  # el mango
	caja(m, Vector3(0, 0, 0.058), Vector3(0.027, 0.033, 0.01), PAVON, "metal")  # el pomo
	caja(m, Vector3(0, 0, -0.054), Vector3(0.012, 0.064, 0.008), PAVON, "metal")  # la guarda
	# la hoja: un perfil (z, y) con el filo abajo y la punta un poco abajo del lomo, de 5 mm de grueso
	perfil(m, [Vector2(-0.058, -0.017), Vector2(-0.17, -0.017), Vector2(-0.215, -0.012), Vector2(-0.235, -0.004),
		Vector2(-0.2, 0.012), Vector2(-0.058, 0.013)], 0.0025, ACERO, "acero")
	var n := armar(m, "cuchillo")
	marca(n, "punta", Vector3(0, -0.004, -0.235))
	return n


# ---------- piezas ----------

static func nueva() -> Malla:
	var m := Malla.new()
	m.solido = false  # sin colisión: el arma la lleva el peatón
	return m


# una caja de lados s centrada en c, girada b
static func caja(m: Malla, c: Vector3, s: Vector3, col: Color, mat := "", b := Basis.IDENTITY) -> void:
	var h := s / 2.0
	for eje in 3:
		var u := Vector3.ZERO
		u[(eje + 1) % 3] = h[(eje + 1) % 3]
		var v := Vector3.ZERO
		v[(eje + 2) % 3] = h[(eje + 2) % 3]
		for sg in [-1.0, 1.0]:
			var n := Vector3.ZERO
			n[eje] = sg
			var o := c + b * (n * h)
			var du := b * u
			var dv := b * v
			m.cara([o - du - dv, o + du - dv, o + du + dv, o - du + dv], col, mat, b * n)


# un cilindro de radio r entre a y b, de k lados y con tapas (las caras planas: a este tamaño no se notan)
static func cilindro(m: Malla, a: Vector3, b: Vector3, r: float, col: Color, mat := "", k := 8) -> void:
	var w := (b - a).normalized()
	var u := w.cross(Vector3.UP if absf(w.y) < 0.9 else Vector3.RIGHT).normalized()
	var v := w.cross(u)
	var pa := []
	var pb := []
	for i in k:
		var ang := TAU * (i + 0.5) / k
		var d := u * cos(ang) + v * sin(ang)
		pa.append(a + d * r)
		pb.append(b + d * r)
	for i in k:
		var j := (i + 1) % k
		var nn: Vector3 = ((pa[i] + pa[j]) / 2.0 - a).normalized()
		m.cara([pa[i], pa[j], pb[j], pb[i]], col, mat, nn)
	m.cara(pb, col, mat, w)
	m.cara(pa, col, mat, -w)


# un perfil convexo en el plano (z, y), extruido de -g a g en X (la hoja del cuchillo)
static func perfil(m: Malla, pts: Array, g: float, col: Color, mat := "") -> void:
	var c := Vector2.ZERO
	for p in pts:
		c += p
	c /= pts.size()
	var izq := []
	var der := []
	for p in pts:
		izq.append(Vector3(-g, p.y, p.x))
		der.append(Vector3(g, p.y, p.x))
	m.cara(izq, col, mat, Vector3.LEFT)
	m.cara(der, col, mat, Vector3.RIGHT)
	for i in pts.size():
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % pts.size()]
		var n := Vector2(-(b - a).y, (b - a).x).normalized()  # (z, y)
		if n.dot((a + b) / 2.0 - c) < 0:
			n = -n
		m.cara([izq[i], izq[(i + 1) % pts.size()], der[(i + 1) % pts.size()], der[i]], col, mat, Vector3(0, n.y, n.x))


# la malla como un Node3D con su MeshInstance3D: un material por acabado
static func armar(m: Malla, nombre: String) -> Node3D:
	var mats := {"": material(0.6), "metal": material(0.4, 0.55), "acero": material(0.22, 0.9)}
	var am := ArrayMesh.new()
	for capa in m.capas:
		var c: Array = m.capas[capa]
		if c[0].is_empty():
			continue
		var a := []
		a.resize(Mesh.ARRAY_MAX)
		a[Mesh.ARRAY_VERTEX] = c[0]
		a[Mesh.ARRAY_NORMAL] = c[1]
		a[Mesh.ARRAY_COLOR] = c[2]
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
		am.surface_set_material(am.get_surface_count() - 1, mats.get(capa, mats[""]))
	var n := Node3D.new()
	n.name = nombre
	var mi := MeshInstance3D.new()
	mi.mesh = am
	n.add_child(mi)
	return n


static func material(rugoso: float, metal := 0.0) -> StandardMaterial3D:
	var mt := StandardMaterial3D.new()
	mt.vertex_color_use_as_albedo = true
	mt.vertex_color_is_srgb = true
	mt.roughness = rugoso
	mt.metallic = metal
	return mt


static func marca(n: Node3D, nombre: String, p: Vector3) -> void:
	var q := Node3D.new()
	q.name = nombre
	q.position = p
	n.add_child(q)
