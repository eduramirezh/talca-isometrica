# Muñecos de práctica para las armas (armas.gd), en el pavimento abierto del borde sur de la plaza, frente a donde
# parte el personaje (main.gd INICIO, (0, -45) de grilla): entre la fila de árboles de 1 Sur (y ≈ -42 a -53) y los
# jardines (y ≈ -36), a los lados del acceso al monumento (|x| < 7, entre los faroles de x ≈ ±5,5), que queda libre:
# el personaje parte mirando hacia él (y --caminar va por ahí). Cada uno es un poste de madera sobre una base redonda
# de goma, con un cuerpo acolchado de arpillera (correas, brazos, cabeza) y un disco de tiro en el pecho, y mira hacia
# INICIO. LUGARES son los puntos pedidos; cada uno busca su lugar libre cerca (lugar(): un rayo al suelo, casi plano y
# a la altura de la plaza, y nada a menos de LIBRE m entre 0,25 y 2 m de alto: faroles, troncos, escaños, muros, otro
# muñeco).
#
# Cada uno tiene VIDA y una barra chica encima, siempre de frente a la cámara. Implementan recibir_dano(cantidad, punto,
# desde), el contrato de armas.gd: sobre CABEZA m el golpe vale el doble, y devuelven el daño que tomaron (armas.gd
# muestra la cifra, dorada en la cabeza); el muñeco se enciende un instante y se bambolea (un resorte que lo inclina
# sobre el borde de la base, hacia donde iba el golpe); con la vida en 0 cae hacia ese lado, y a los REAPARECE s se
# levanta con la vida entera.
#
#   var b := preload("res://blancos.gd").new(); b.mapa = mapa; add_child(b)   # main.gd
#   await b.listos()     # ya puestos (esperan la colisión de la plaza)
extends Node3D

const LUGARES: Array[Vector2] = [Vector2(-8.5, -39), Vector2(8.5, -39), Vector2(-13, -38.5), Vector2(13, -38.5),
	Vector2(-17.5, -39.5)]  # los dos primeros se ven desde donde parte
const MIRAN := Vector2(0, -45)  # INICIO de main.gd
const VIDA := 100.0
const CABEZA := 1.52  # m sobre la base: de aquí arriba, la cabeza
const REAPARECE := 4.0  # s en el suelo antes de levantarse
const LEVANTA := 0.8  # s que tarda en levantarse
const LIBRE := 0.9  # m alrededor sin nada
const R_BASE := 0.3  # m: el radio de la base, el borde sobre el que se inclina
const RESORTE := 90.0  # 1/s²: ~1,5 bamboleos por segundo
const AMORTIGUA := 3.2  # 1/s
const EMPUJE := 0.05  # rad/s por punto de daño: un tiro de pistola lo inclina ~7°
const MAX_INCL := 0.45  # rad
const TENDIDO := 1.38  # rad: caído, apoyado en el relleno
const CAE := 12.0  # 1/s²: g / (el largo hasta el centro del cuerpo, ~0,8 m)
# la barra de vida: un rectángulo de frente a la cámara, verde a rojo, con borde
const BARRA := """
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;
uniform float vida : hint_range(0.0, 1.0) = 1.0;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
	vec2 px = UV * vec2(50.0, 6.0);
	float borde = step(px.x, 0.9) + step(49.1, px.x) + step(px.y, 0.9) + step(5.1, px.y);
	vec3 lleno = mix(vec3(0.9, 0.18, 0.12), vec3(0.35, 0.85, 0.3), smoothstep(0.25, 0.7, vida));
	ALBEDO = mix(UV.x < vida ? lleno : vec3(0.1), vec3(0.0), clamp(borde, 0.0, 1.0));
}
"""

var mapa: Node3D
var munecos: Array[Node3D] = []
var listo := false


class Muneco extends Node3D:
	var mats: Dictionary  # los compartidos (blancos.gd materiales())
	var barra_shader: Shader
	var vida := VIDA
	var polvo := Color(0.8, 0.7, 0.48)  # lo que salta al golpearlo (armas.gd): el relleno
	var pivote := Node3D.new()  # lo que se inclina (y su colisión)
	var incl := Vector3.ZERO  # hacia dónde y cuánto se inclina: horizontal, en el marco del muñeco, en rad
	var vel := Vector3.ZERO
	var caido := 0.0  # s desde que cayó (0: en pie)
	var dir_caida := Vector3.BACK
	var ang := 0.0
	var vang := 0.0
	var t_brillo := 0.0
	var arpillera := StandardMaterial3D.new()  # la suya: se enciende al golpearlo
	var barra := ShaderMaterial.new()

	func _ready() -> void:
		add_child(pivote)
		arpillera.albedo_color = Color(0.78, 0.67, 0.47)
		arpillera.roughness = 0.95
		arpillera.emission_enabled = true
		arpillera.emission = Color(1.0, 0.35, 0.2)
		arpillera.emission_energy_multiplier = 0.0
		var base := CylinderMesh.new()
		base.top_radius = R_BASE - 0.04
		base.bottom_radius = R_BASE
		base.height = 0.12
		pieza(base, mats["goma"], Vector3(0, 0.06, 0))
		var poste := CylinderMesh.new()
		poste.top_radius = 0.045
		poste.bottom_radius = 0.05
		poste.height = 0.95
		pieza(poste, mats["madera"], Vector3(0, 0.575, 0))
		var torso := CapsuleMesh.new()
		torso.radius = 0.2
		torso.height = 0.62
		pieza(torso, arpillera, Vector3(0, 1.24, 0), Vector3.ZERO, Vector3(1, 1, 0.75))
		for y in [1.08, 1.38]:  # las correas
			var c := CylinderMesh.new()
			c.top_radius = 0.204
			c.bottom_radius = 0.204
			c.height = 0.035
			pieza(c, mats["correa"], Vector3(0, y, 0), Vector3.ZERO, Vector3(1, 1, 0.76))
		var brazos := CapsuleMesh.new()
		brazos.radius = 0.07
		brazos.height = 0.8
		pieza(brazos, arpillera, Vector3(0, 1.41, 0), Vector3(0, 0, PI / 2))
		var cabeza := SphereMesh.new()
		cabeza.radius = 0.13
		cabeza.height = 0.26
		pieza(cabeza, arpillera, Vector3(0, 1.67, 0))
		var anillos := [[0.12, "blanco"], [0.09, "rojo"], [0.06, "blanco"], [0.03, "rojo"]]
		for k in anillos.size():  # el disco de tiro: anillos de adelante hacia atrás
			var d := CylinderMesh.new()
			d.top_radius = anillos[k][0]
			d.bottom_radius = anillos[k][0]
			d.height = 0.006
			d.radial_segments = 24
			pieza(d, mats[anillos[k][1]], Vector3(0, 1.24, -0.155 - 0.002 * k), Vector3(PI / 2, 0, 0))
		# la colisión, con el pivote
		var cuerpo := StaticBody3D.new()
		cuerpo.name = "cuerpo"
		pivote.add_child(cuerpo)
		var fs := [[cilindro(R_BASE, 0.12), Vector3(0, 0.06, 0)], [cilindro(0.06, 0.95), Vector3(0, 0.575, 0)],
			[capsula(0.2, 0.62), Vector3(0, 1.24, 0)], [caja(Vector3(0.8, 0.14, 0.14)), Vector3(0, 1.41, 0)],
			[esfera(0.13), Vector3(0, 1.67, 0)]]
		for f in fs:
			var cs := CollisionShape3D.new()
			cs.shape = f[0]
			cs.position = f[1]
			cuerpo.add_child(cs)
		# la barra de vida, sin inclinarse
		var sh := ShaderMaterial.new()
		sh.shader = barra_shader
		barra = sh
		var q := QuadMesh.new()
		q.size = Vector2(0.5, 0.06)
		var mi := MeshInstance3D.new()
		mi.mesh = q
		mi.material_override = barra
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position.y = 2.0
		mi.visibility_range_end = 45.0
		add_child(mi)

	func pieza(m: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO, esc := Vector3.ONE) -> void:
		var mi := MeshInstance3D.new()
		mi.mesh = m
		mi.material_override = mat
		mi.position = pos
		mi.rotation = rot
		mi.scale = esc
		pivote.add_child(mi)

	static func cilindro(r: float, h: float) -> Shape3D:
		var s := CylinderShape3D.new()
		s.radius = r
		s.height = h
		return s

	static func capsula(r: float, h: float) -> Shape3D:
		var s := CapsuleShape3D.new()
		s.radius = r
		s.height = h
		return s

	static func caja(t: Vector3) -> Shape3D:
		var s := BoxShape3D.new()
		s.size = t
		return s

	static func esfera(r: float) -> Shape3D:
		var s := SphereShape3D.new()
		s.radius = r
		return s

	# el contrato de armas.gd: cantidad de daño en el punto (mundo), desde donde vino (la boca del cañón, el pecho); el
	# que tomó, el doble en la cabeza
	func recibir_dano(cantidad: float, punto: Vector3, desde: Vector3) -> float:
		if vida <= 0.0:
			return 0.0  # en el suelo: ya cayó
		var cabeza := (pivote.global_transform.affine_inverse() * punto).y > CABEZA
		var dano := cantidad * (2.0 if cabeza else 1.0)
		vida = maxf(vida - dano, 0.0)
		t_brillo = 0.12
		var d := global_basis.inverse() * (punto - desde)  # hacia donde iba el golpe, en el marco del muñeco
		d.y = 0.0
		d = d.normalized() if d.length() > 1e-4 else Vector3.BACK
		vel += d * dano * EMPUJE
		if vida <= 0.0:
			caido = 0.001
			dir_caida = d  # hacia donde iba el golpe (si iba de vuelta en el bamboleo, igual: el golpe manda)
			ang = maxf(incl.dot(d), 0.05)
			vang = maxf(vel.dot(d), 1.6)
			print("blancos.gd: %s cae (vuelve en %.0f s)" % [name, REAPARECE])
		return dano

	# se inclina ang rad hacia t (horizontal, en su marco), sobre el borde de la base de ese lado
	func inclinar(t: Vector3) -> void:
		var a := t.length()
		if a < 1e-5:
			pivote.transform = Transform3D.IDENTITY
			return
		var d := t / a
		var b := Basis(Vector3.UP.cross(d).normalized(), a)
		var borde := d * R_BASE
		pivote.transform = Transform3D(b, borde - b * borde)

	func _physics_process(dt: float) -> void:
		if caido > 0.0:
			caido += dt
			if caido < REAPARECE:  # cae como un péndulo invertido (~0,5 s) y rebota un poco en el relleno
				vang += CAE * sin(ang) * dt
				ang += vang * dt
				if ang >= TENDIDO:
					ang = TENDIDO
					vang = -absf(vang) * 0.25
			else:  # se levanta
				var u := clampf((caido - REAPARECE) / LEVANTA, 0.0, 1.0)
				ang = minf(ang, TENDIDO * (1.0 - smoothstep(0.0, 1.0, u)))
				if u >= 1.0:
					print("blancos.gd: %s de pie otra vez" % name)
					caido = 0.0
					vida = VIDA
					incl = Vector3.ZERO
					vel = Vector3.ZERO
					ang = 0.0
			inclinar(dir_caida * ang)
		else:
			vel += (-RESORTE * incl - AMORTIGUA * vel) * dt
			incl += vel * dt
			if incl.length() > MAX_INCL:
				incl = incl.normalized() * MAX_INCL
			inclinar(incl)
		t_brillo = maxf(t_brillo - dt, 0.0)
		arpillera.emission_energy_multiplier = 2.5 * t_brillo / 0.12
		barra.set_shader_parameter("vida", vida / VIDA)


func _ready() -> void:
	name = "blancos"
	poner()


# los muñecos, cuando está la colisión del lugar (la tesela de la plaza; la de los modelos ya está: se arma en su _ready())
func poner() -> void:
	var arbol := get_tree()
	await arbol.physics_frame
	while mapa and not mapa.solido(MIRAN.x, MIRAN.y):
		await arbol.physics_frame
	await arbol.physics_frame
	var esp := get_world_3d().direct_space_state
	var r := esp.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(MIRAN.x, 1500, -MIRAN.y), Vector3(MIRAN.x, -500, -MIRAN.y)))
	var h0: float = r["position"].y if r else 0.0
	var mats := materiales()
	var sh := Shader.new()
	sh.code = BARRA
	var dice := []
	for i in LUGARES.size():
		var p := lugar(esp, LUGARES[i], h0)
		if p == Vector3.INF:
			push_warning("blancos.gd: no hay lugar libre cerca de (%.0f, %.0f)" % [LUGARES[i].x, LUGARES[i].y])
			continue
		var m := Muneco.new()
		m.name = "muñeco %d" % (i + 1)
		m.mats = mats
		m.barra_shader = sh
		add_child(m)
		m.global_position = p
		var v := Vector3(MIRAN.x, 0, -MIRAN.y) - p  # hacia INICIO
		m.rotation.y = atan2(-v.x, -v.z)  # el muñeco mira hacia -Z
		munecos.append(m)
		dice.append("(%.1f, %.1f)" % [p.x, -p.z])
	print("blancos.gd: %d muñecos en %s" % [munecos.size(), ", ".join(dice)])
	listo = true


func listos() -> void:
	while not listo:
		await get_tree().process_frame


# un lugar libre cerca de c (grilla): en espiral desde c, el primer suelo casi plano, a no más de 1 m de la altura de
# INICIO (no un techo ni el monumento), sin nada a menos de LIBRE m entre 0,25 y 2 m de alto ni otro muñeco a 2 m
func lugar(esp: PhysicsDirectSpaceState3D, c: Vector2, h0: float) -> Vector3:
	var forma := CylinderShape3D.new()
	forma.radius = LIBRE
	forma.height = 1.75
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = forma
	for k in 30:
		var p := c + (Vector2.from_angle(k * 2.39996) * 0.7 * sqrt(k) if k > 0 else Vector2.ZERO)
		var r := esp.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x, h0 + 3.0, -p.y), Vector3(p.x, h0 - 3.0, -p.y)))
		if r.is_empty() or r["normal"].y < 0.97 or absf(r["position"].y - h0) > 1.0:
			continue
		var pos: Vector3 = r["position"]
		var cerca := false
		for m in munecos:
			cerca = cerca or m.global_position.distance_to(pos) < 2.0
		if cerca:
			continue
		q.transform = Transform3D(Basis(), pos + Vector3.UP * (0.25 + 0.875))
		if not esp.intersect_shape(q, 1).is_empty():
			continue
		return pos
	return Vector3.INF


# los materiales que comparten todos (la arpillera es de cada uno: se enciende al golpearlo)
static func materiales() -> Dictionary:
	var out := {}
	var cols := {"goma": [Color(0.13, 0.13, 0.14), 0.9], "madera": [Color(0.45, 0.31, 0.19), 0.85],
		"correa": [Color(0.36, 0.24, 0.14), 0.7], "blanco": [Color(0.93, 0.92, 0.88), 0.7], "rojo": [Color(0.78, 0.12, 0.1), 0.6]}
	for k in cols:
		var m := StandardMaterial3D.new()
		m.albedo_color = cols[k][0]
		m.roughness = cols[k][1]
		out[k] = m
	return out
