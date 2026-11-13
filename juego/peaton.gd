# El peatón que maneja jugador.gd: una persona de 1,75 m hecha de cápsulas y esferas (polera, jeans, zapatillas),
# articulada en caderas, rodillas, tobillos, hombros, codos y cuello, y animada en código según la velocidad: quieto
# (respira y se balancea), camina, trota y corre (más zancada, más inclinado, codos doblados) y salta (una rodilla
# arriba). La fase de los pasos avanza con la distancia recorrida, para que los pies no patinen; las poses se
# mezclan en ~0,1 s. Mira hacia -Z.
extends Node3D

const COLORES := {"piel": "c4967a", "pelo": "2a1d16", "polera": "3b6fa0", "jeans": "2d3c58", "zapatilla": "e6e3dc", "suela": "3a3836"}

var fase := 0.0
var t := 0.0
var cadera := Node3D.new()
var torso := Node3D.new()
var cabeza := Node3D.new()
var muslo: Array[Node3D] = []
var canilla: Array[Node3D] = []
var pie: Array[Node3D] = []
var hombro: Array[Node3D] = []
var codo: Array[Node3D] = []
var mats := {}


func _ready() -> void:
	for k in COLORES:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(COLORES[k])
		m.roughness = 0.95 if k == "jeans" else 0.8
		if k == "piel":
			m.roughness = 0.6
			m.subsurf_scatter_enabled = true
			m.subsurf_scatter_strength = 0.3
		mats[k] = m
	cadera.position.y = 0.95
	add_child(cadera)
	# pelvis y torso
	pieza(cadera, cap(0.15, 0.36), "jeans", Vector3(0, 0.02, 0), Vector3(0, 0, PI / 2), Vector3(1, 1, 0.75))
	cadera.add_child(torso)
	pieza(torso, cap(0.17, 0.56), "polera", Vector3(0, 0.3, 0), Vector3.ZERO, Vector3(1, 1, 0.68))
	pieza(torso, cap(0.06, 0.2), "piel", Vector3(0, 0.6, 0))  # cuello
	cabeza.position.y = 0.63
	torso.add_child(cabeza)
	pieza(cabeza, esfera(0.105, 0.25), "piel", Vector3(0, 0.1, 0))
	pieza(cabeza, esfera(0.113, 0.21), "pelo", Vector3(0, 0.145, 0.022))
	for x in [-0.045, 0.045]:  # los ojos: para saber hacia dónde mira
		pieza(cabeza, esfera(0.011, 0.022), "pelo", Vector3(x, 0.115, -0.094))
	for lado in [-1.0, 1.0]:
		var h := Node3D.new()
		h.position = Vector3(0.215 * lado, 0.5, 0)
		torso.add_child(h)
		pieza(h, cap(0.06, 0.3), "polera", Vector3(0, -0.12, 0))  # manga
		pieza(h, cap(0.05, 0.3), "piel", Vector3(0, -0.15, 0))
		var c := Node3D.new()
		c.position.y = -0.29
		h.add_child(c)
		pieza(c, cap(0.046, 0.28), "piel", Vector3(0, -0.13, 0))
		pieza(c, esfera(0.046, 0.1), "piel", Vector3(0, -0.29, -0.01), Vector3.ZERO, Vector3(0.8, 1, 1))
		hombro.append(h)
		codo.append(c)
		var m := Node3D.new()
		m.position = Vector3(0.095 * lado, -0.02, 0)
		cadera.add_child(m)
		pieza(m, cap(0.092, 0.5), "jeans", Vector3(0, -0.22, 0))
		var r := Node3D.new()
		r.position.y = -0.44
		m.add_child(r)
		pieza(r, cap(0.072, 0.48), "jeans", Vector3(0, -0.21, 0))
		var p := Node3D.new()
		p.position.y = -0.46
		r.add_child(p)
		pieza(p, caja(Vector3(0.105, 0.075, 0.27)), "zapatilla", Vector3(0, -0.02, -0.05))
		pieza(p, caja(Vector3(0.11, 0.025, 0.28)), "suela", Vector3(0, -0.06, -0.05))
		muslo.append(m)
		canilla.append(r)
		pie.append(p)


func cap(r: float, h: float) -> Mesh:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = h
	m.radial_segments = 12
	m.rings = 3
	return m


func esfera(r: float, h: float) -> Mesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = h
	m.radial_segments = 14
	m.rings = 7
	return m


func caja(s: Vector3) -> Mesh:
	var m := BoxMesh.new()
	m.size = s
	return m


func pieza(padre: Node3D, malla: Mesh, mat: String, pos: Vector3, rot := Vector3.ZERO, esc := Vector3.ONE) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = malla
	mi.material_override = mats[mat]
	mi.position = pos
	mi.rotation = rot
	mi.scale = esc
	padre.add_child(mi)


# rapidez: m/s horizontales; en_suelo: si pisa
func animar(dt: float, rapidez: float, en_suelo: bool) -> void:
	t += dt
	var paso := 0.55 + 0.25 * rapidez  # m por paso: 0,9 caminando de verdad, 2,5 a 8 m/s, 5 a 18 m/s
	fase += dt * rapidez / (2.0 * paso) * TAU
	var mov := smoothstep(0.3, 1.2, rapidez)    # 0 quieto, 1 en movimiento
	var trote := smoothstep(2.5, 6.0, rapidez)  # 0 camina, 1 trota
	var carrera := smoothstep(10.0, 16.0, rapidez)
	var p := fase
	var obj := {}
	for i in 2:
		var q := p + PI * i  # la pierna derecha media vuelta después
		var s := sin(q)
		var balanceo := cos(q)  # >0: la pierna va hacia adelante (en el aire)
		var amp_m := lerpf(0.42, 0.75, trote) + 0.2 * carrera
		var th := s * amp_m
		var kn := -(lerpf(0.06, 0.25, trote) + lerpf(0.65, 1.5, trote) * pow(max(balanceo, 0.0), 1.4))
		obj["m%d" % i] = th * mov
		obj["r%d" % i] = kn * mov - 0.04 * (1.0 - mov)
		obj["p%d" % i] = -(th + kn) * 0.45 * mov
		var amp_b := lerpf(0.35, 0.8, trote) + 0.2 * carrera
		obj["h%d" % i] = -s * amp_b * mov
		obj["hz%d" % i] = (0.07 + 0.05 * trote * mov) * (-1 if i == 0 else 1)  # hacia afuera
		obj["c%d" % i] = (lerpf(0.2, 1.35, trote) * mov + 0.1 * (1.0 - mov) + 0.08 * sin(t * 1.3))
	var bote := lerpf(0.03 * pow(sin(p), 2.0), 0.07 * abs(cos(p)), trote) * mov
	var y := 0.95 - bote - 0.03 * trote * mov
	var lean := -(0.04 + 0.16 * trote + 0.14 * carrera) * mov
	var giro := 0.12 * sin(p) * (1.0 + trote) * mov
	var resp := 0.012 * sin(t * 1.7) * (1.0 - mov)
	if not en_suelo:  # en el aire: una rodilla arriba, los brazos abiertos
		obj["m0"] = 0.75
		obj["r0"] = -1.1
		obj["m1"] = -0.2
		obj["r1"] = -0.45
		obj["p0"] = 0.2
		obj["p1"] = 0.3
		obj["h0"] = -0.5
		obj["h1"] = 0.6
		obj["hz0"] = -0.45
		obj["hz1"] = 0.45
		obj["c0"] = 0.6
		obj["c1"] = 0.6
		y = 0.95
		lean = -0.08
	var k := 1.0 - exp(-14.0 * dt)
	for i in 2:
		muslo[i].rotation.x = lerpf(muslo[i].rotation.x, obj["m%d" % i], k)
		canilla[i].rotation.x = lerpf(canilla[i].rotation.x, obj["r%d" % i], k)
		pie[i].rotation.x = lerpf(pie[i].rotation.x, obj["p%d" % i], k)
		hombro[i].rotation.x = lerpf(hombro[i].rotation.x, obj["h%d" % i], k)
		hombro[i].rotation.z = lerpf(hombro[i].rotation.z, obj["hz%d" % i], k)
		codo[i].rotation.x = lerpf(codo[i].rotation.x, obj["c%d" % i], k)
	cadera.position.y = lerpf(cadera.position.y, y, k)
	torso.rotation.x = lerpf(torso.rotation.x, lean, k)
	torso.rotation.y = lerpf(torso.rotation.y, giro, k)
	cadera.rotation.y = lerpf(cadera.rotation.y, -giro * 0.6, k)
	torso.scale = Vector3(1.0 + resp, 1.0 + resp * 0.5, 1.0 + resp)
	cabeza.rotation.x = lerpf(cabeza.rotation.x, -lean * 0.6 + 0.02 * sin(t * 0.7) * (1.0 - mov), k)
