# Cielo, luz, sombras, niebla, posproceso y la hora del día (main.gd lo agrega a la escena, después de recortar el glb).
#
# El sol está donde está en Talca (35,43° S, 71,67° O; UTC−3, la hora de verano) el día y la hora de FECHA y HORA: por
# omisión, el 15 de enero a las 17:00 (el sol a ~45°, al poniente nor-poniente). La tecla T avanza una hora (Mayús+T
# retrocede), con atardecer, crepúsculo y noche: de noche la luz es la de la luna, las ventanas se encienden y los
# faroles de la plaza alumbran. El cielo es shaders/cielo.gdshader (nubes, la cordillera, estrellas) y también da la luz
# ambiente y los reflejos. Las capas del glb toman su material de materiales.gd (shaders/capa.gdshader): la textura,
# las ventanas y el brillo de cada superficie, sobre el color por vértice de la maqueta. Más allá del borde de la caja
# exportada, una ciudad lejana de bloques bajos (lejos()) para que el horizonte no quede vacío.
#
#   --hora 20.5      la hora al comenzar (decimal, hora de verano)
#   --dia 172        el día del año (1 = 1 de enero)
#   --calidad baja   sin SSIL, SSAO ni sombras blandas (para máquinas más lentas)
#   --sin a,b        apaga partes para medir su costo con --fps (modelos/calles.gd): ssil, ssao, glow, niebla,
#                    sombras, blandas, lejos, nubes
extends Node3D

const Mat := preload("res://materiales.gd")
const LAT := -35.4265
const LON := -71.666
const UTC := -3.0
const GIRO := 5.0  # grados: la grilla está girada; el norte verdadero queda 5° al poniente del norte de la grilla

var dia := 15
var hora := 17.0
var objetivo := 17.0
var env: Environment
var sky: Sky
var cielo: ShaderMaterial
var sol: DirectionalLight3D
var faroles: Array[OmniLight3D] = []
var focos: MultiMeshInstance3D
var reloj: Label
var reloj_t := 0.0
var lejanos: Array[Node3D] = []


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if "--hora" in args:
		hora = float(args[args.find("--hora") + 1])
	if "--dia" in args:
		dia = int(args[args.find("--dia") + 1])
	objetivo = hora
	# noche, sol_dir y luna_dir son parámetros globales de los sombreadores ([shader_globals] de project.godot)
	calidad()
	entorno()
	copas()
	materiales()
	buscar_faroles()
	lejos()
	hud()
	poner_hora(hora)
	var sin_ := []
	if "--sin" in args:
		sin_ = Array(args[args.find("--sin") + 1].split(","))
	if "--calidad" in args and args[args.find("--calidad") + 1] == "baja":
		sin_ += ["ssil", "ssao", "blandas"]
	apagar(sin_)


# sombras y antialiasing (en tiempo de ejecución, para no tocar project.godot)
func calidad() -> void:
	RenderingServer.directional_shadow_atlas_set_size(4096, true)  # 8192 costaba ~25 cuadros por segundo
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM)
	var vp := get_viewport()
	vp.msaa_3d = Viewport.MSAA_2X
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	vp.use_taa = false


func entorno() -> void:
	cielo = ShaderMaterial.new()
	cielo.shader = preload("res://shaders/cielo.gdshader")
	sky = Sky.new()
	sky.sky_material = cielo
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	sky.process_mode = Sky.PROCESS_MODE_REALTIME
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.ambient_light_sky_contribution = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_agx_contrast = 1.45
	# oclusión ambiente e iluminación indirecta en pantalla: los rincones, los pies de los muros, el pasto bajo los árboles
	env.ssao_enabled = true
	env.ssao_radius = 1.6
	env.ssao_intensity = 2.2
	env.ssao_power = 1.4
	env.ssao_detail = 0.6
	env.ssao_light_affect = 0.15
	env.ssil_enabled = true
	env.ssil_radius = 6.0
	env.ssil_intensity = 0.8
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.02
	env.glow_hdr_threshold = 1.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	# niebla atmosférica: la perspectiva aérea toma el color del cielo; a 200 m apenas un 20 %
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_density = 0.0011
	env.fog_aerial_perspective = 0.85
	env.fog_sky_affect = 0.0
	env.fog_sun_scatter = 0.12
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	env.adjustment_contrast = 1.04
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	sol = DirectionalLight3D.new()
	sol.shadow_enabled = true
	sol.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sol.directional_shadow_max_distance = 260.0
	sol.directional_shadow_split_1 = 0.04  # 10 m
	sol.directional_shadow_split_2 = 0.12  # 31 m
	sol.directional_shadow_split_3 = 0.35  # 91 m
	sol.directional_shadow_blend_splits = true
	sol.directional_shadow_fade_start = 0.85
	sol.shadow_bias = 0.04
	sol.shadow_normal_bias = 1.2
	sol.light_angular_distance = 0.53  # el disco del sol: sombras más blandas lejos de lo que las proyecta
	sol.shadow_blur = 1.0
	add_child(sol)


# el material de cada capa del glb, por nombre (los modelos de modelos/ traen los suyos)
func materiales() -> void:
	for n in get_parent().get_children():
		if n == self or not n is Node3D:
			continue
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			var nombre := String(mi.name)
			if not Mat.TIPOS.has(nombre):
				nombre = String(mi.get_parent().name)
			if Mat.TIPOS.has(nombre):
				mi.material_override = Mat.capa(nombre)


# Las copas de la maqueta son icosaedros de caras planas: se ven como piedras talladas. Cada copa (los triángulos verdes
# conectados de «arboles») se deforma con ruido (±15 % del radio, una masa irregular) y toma normales que salen de su
# centro, mezcladas con las de sus caras: la luz la redondea como una masa de hojas. Lo mismo para cualquier malla
# de árboles de modelos/ que se llame «arboles».
func copas() -> void:
	var ruido := FastNoiseLite.new()
	ruido.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	ruido.frequency = 0.45
	ruido.seed = 35
	for n in get_parent().get_children():
		if not n is Node3D or n == self:
			continue
		for mi in n.find_children("arboles", "MeshInstance3D", true, false):
			var am := mi.mesh as ArrayMesh
			if am == null:
				continue
			var nuevo := ArrayMesh.new()
			var copas_n := 0
			for si in am.get_surface_count():
				var a := am.surface_get_arrays(si)
				var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
				var nr: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
				var c: PackedColorArray = a[Mesh.ARRAY_COLOR]
				var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
				if c.is_empty() or idx.is_empty():
					nuevo.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
					continue
				# vértices iguales (las caras planas los repiten) -> un solo nodo
				var nodo := PackedInt32Array()
				nodo.resize(v.size())
				var por_pos := {}
				for i in v.size():
					var k := Vector3i(roundi(v[i].x * 200), roundi(v[i].y * 200), roundi(v[i].z * 200))
					if not por_pos.has(k):
						por_pos[k] = por_pos.size()
					nodo[i] = por_pos[k]
				var padre := PackedInt32Array()
				padre.resize(por_pos.size())
				for i in padre.size():
					padre[i] = i
				var verde := PackedByteArray()
				verde.resize(v.size())
				for i in v.size():
					verde[i] = 1 if c[i].g > c[i].r * 1.02 else 0
				for t in range(0, idx.size(), 3):
					if not verde[idx[t]]:
						continue
					var r0 := _raiz(padre, nodo[idx[t]])
					for j in [1, 2]:
						var r1 := _raiz(padre, nodo[idx[t + j]])
						if r1 != r0:
							padre[r1] = r0
				var suma := {}
				var cuenta := {}
				for i in v.size():
					if not verde[i]:
						continue
					var r := _raiz(padre, nodo[i])
					suma[r] = suma.get(r, Vector3.ZERO) + v[i]
					cuenta[r] = cuenta.get(r, 0) + 1
				copas_n += suma.size()
				for i in v.size():
					if not verde[i]:
						continue
					var r := _raiz(padre, nodo[i])
					var cen: Vector3 = suma[r] / cuenta[r]
					var d := v[i] - cen
					var w: Vector3 = mi.global_transform * v[i]
					v[i] = cen + d * (1.0 + 0.4 * ruido.get_noise_3dv(w))
					nr[i] = (d.normalized() * 0.8 + nr[i] * 0.2).normalized()
				a[Mesh.ARRAY_VERTEX] = v
				a[Mesh.ARRAY_NORMAL] = nr
				nuevo.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
				nuevo.surface_set_material(nuevo.get_surface_count() - 1, am.surface_get_material(si))
			mi.mesh = nuevo
			print("ambiente.gd: %d copas redondeadas en %s" % [copas_n, mi.get_path()])


func _raiz(padre: PackedInt32Array, i: int) -> int:
	while padre[i] != i:
		padre[i] = padre[padre[i]]
		i = padre[i]
	return i


# ---------- el sol ----------

# dirección hacia el sol en el juego (Y arriba), para un día del año y una hora local; también sirve para la luna
func sol_en(d: int, h: float) -> Vector3:
	var b := deg_to_rad(360.0 / 365.0 * (d - 81))
	var decl := deg_to_rad(23.44) * sin(b)
	var eot := 9.87 * sin(2 * b) - 7.53 * cos(b) - 1.5 * sin(b)  # minutos
	var solar := h + (4.0 * (LON - 15.0 * UTC) + eot) / 60.0
	var hra := deg_to_rad(15.0 * (solar - 12.0))
	var phi := deg_to_rad(LAT)
	var e := -cos(decl) * sin(hra)
	var n := sin(decl) * cos(phi) - cos(decl) * cos(hra) * sin(phi)
	var u := sin(decl) * sin(phi) + cos(decl) * cos(hra) * cos(phi)
	var t := deg_to_rad(GIRO)
	var gx := e * cos(t) - n * sin(t)
	var gy := e * sin(t) + n * cos(t)
	return Vector3(gx, u, -gy).normalized()


func poner_hora(h: float) -> void:
	hora = h  # sin envolver, para que T pueda pasar de las 23 a las 0
	var h24 := fposmod(h, 24.0)
	var s := sol_en(dia, h24)
	# la luna: llena, al otro lado del cielo (sale cuando el sol se pone)
	var l := sol_en(dia, h24 + 12.0)
	l.y = abs(l.y) * 0.8 + 0.25
	l = l.normalized()
	var elev := s.y
	var dia_k := smoothstep(-0.05, 0.12, elev)  # 0 de noche, 1 de día
	var noche := 1.0 - smoothstep(-0.16, 0.0, elev)
	RenderingServer.global_shader_parameter_set("sol_dir", s)
	RenderingServer.global_shader_parameter_set("luna_dir", l)
	RenderingServer.global_shader_parameter_set("noche", noche)

	var calida := Color(1.0, 0.45, 0.18).lerp(Color(1.0, 0.95, 0.88), smoothstep(0.0, 0.5, elev))
	if elev > -0.03:
		sol.basis = Basis.looking_at(-s, Vector3.UP if abs(s.y) < 0.99 else Vector3.FORWARD)
		sol.light_color = calida
		sol.light_energy = 3.0 * smoothstep(-0.03, 0.08, elev)
		sol.shadow_opacity = 1.0
	else:
		sol.basis = Basis.looking_at(-l, Vector3.UP)
		sol.light_color = Color(0.62, 0.72, 1.0)
		sol.light_energy = 0.22 * smoothstep(-0.03, -0.16, elev)
		sol.shadow_opacity = 0.8
	sol.light_angular_distance = 0.53 if elev > 0.0 else 1.5
	env.ambient_light_energy = lerp(0.9, 0.5, dia_k)
	env.tonemap_exposure = lerp(2.0, 0.5, smoothstep(-0.2, 0.05, elev))
	env.fog_light_color = Color(0.55, 0.65, 0.8).lerp(Color(0.95, 0.6, 0.4), 1.0 - smoothstep(0.0, 0.25, elev))
	env.glow_intensity = lerp(0.9, 0.35, dia_k)
	env.glow_hdr_threshold = lerp(0.8, 1.1, dia_k)
	for f in faroles:
		f.visible = noche > 0.3
		f.light_energy = 2.5 * noche
	if focos:
		focos.visible = noche > 0.3
	if reloj:
		reloj.text = "%02d:%02d  ·  T: avanzar la hora (Mayús+T: retroceder)" % [int(h24), int(fmod(h24, 1.0) * 60.0)]


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and e.physical_keycode == KEY_T:
		objetivo += -1.0 if e.shift_pressed else 1.0
		reloj_t = 4.0


func _process(dt: float) -> void:
	if hora != objetivo:
		hora = move_toward(hora, objetivo, dt * 1.5)  # 1,5 horas por segundo
		poner_hora(hora)
	if reloj:
		reloj_t = max(reloj_t - dt, 0.0)
		reloj.modulate.a = clampf(reloj_t, 0.0, 1.0) * 0.6 + 0.4


func hud() -> void:
	var capa := CanvasLayer.new()
	add_child(capa)
	reloj = Label.new()
	reloj.anchor_left = 1.0
	reloj.anchor_right = 1.0
	reloj.offset_left = -520
	reloj.offset_right = -16
	reloj.offset_top = 12
	reloj.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	reloj.add_theme_color_override("font_color", Color(1, 1, 1))
	reloj.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	reloj.add_theme_constant_override("outline_size", 4)
	capa.add_child(reloj)


# ---------- los faroles de la plaza ----------

# Los faroles del glb (en «hitos»: postes verde oscuro con su linterna arriba) se reconocen por el color y la altura;
# en la punta de cada uno va una luz para la noche. Si un modelo propio los reemplaza, no se encuentra ninguno.
func buscar_faroles() -> void:
	var celdas := {}
	for n in get_parent().get_children():
		if not n is Node3D or n == self:
			continue
		for mi in n.find_children("hitos", "MeshInstance3D", true, false):
			var xf: Transform3D = mi.global_transform
			for s in mi.mesh.get_surface_count():
				var a: Array = mi.mesh.surface_get_arrays(s)
				var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
				var c: PackedColorArray = a[Mesh.ARRAY_COLOR]
				if c.is_empty():
					continue
				var ref := Color("36554b").srgb_to_linear()
				for i in v.size():
					var col := c[i]
					if abs(col.r - ref.r) + abs(col.g - ref.g) + abs(col.b - ref.b) > 0.02:
						continue
					var p: Vector3 = xf * v[i]
					var k := Vector2i(floori(p.x / 1.5), floori(p.z / 1.5))
					if not celdas.has(k) or celdas[k].y < p.y:
						celdas[k] = p
	# un farol por grupo de celdas vecinas: el punto más alto
	var puntos: Array[Vector3] = []
	for k in celdas:
		var p: Vector3 = celdas[k]
		var junto := false
		for i in puntos.size():
			if Vector2(puntos[i].x - p.x, puntos[i].z - p.z).length() < 2.0:
				junto = true
				if p.y > puntos[i].y:
					puntos[i] = p
				break
		if not junto:
			puntos.append(p)
	var suelo_y := 0.0
	var lampara := SphereMesh.new()
	lampara.radius = 0.22
	lampara.height = 0.44
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = lampara
	var altos: Array[Vector3] = []
	for p in puntos:
		if p.y - suelo_y > 2.5:  # los postes, no las bancas ni los basureros
			altos.append(p)
	mm.instance_count = altos.size()
	for i in altos.size():
		var p := altos[i] + Vector3.DOWN * 0.35
		mm.set_instance_transform(i, Transform3D(Basis(), p))
		var f := OmniLight3D.new()
		f.position = p
		f.light_color = Color(1.0, 0.78, 0.5)
		f.omni_range = 14.0
		f.omni_attenuation = 1.4
		f.shadow_enabled = false
		f.light_energy = 0.0
		f.visible = false
		add_child(f)
		faroles.append(f)
	if altos.size() > 0:
		focos = MultiMeshInstance3D.new()
		focos.multimesh = mm
		var em := StandardMaterial3D.new()
		em.albedo_color = Color(1.0, 0.9, 0.7)
		em.emission_enabled = true
		em.emission = Color(1.0, 0.8, 0.55)
		em.emission_energy_multiplier = 6.0
		focos.material_override = em
		focos.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		focos.visible = false
		add_child(focos)
	print("ambiente.gd: %d faroles" % altos.size())



# ---------- la ciudad más allá de la caja ----------

# Bloques bajos con techos de colores y árboles sueltos en una grilla de manzanas de ~100 m, desde el borde de la caja
# hasta 1,5 km, sobre un suelo plano: la niebla los funde con el cielo. No tienen colisión (los muros de main.gd no dejan
# llegar a ellos) y son inventados: solo dan la idea de que la ciudad sigue.
func lejos() -> void:
	var caja := AABB()
	var primera := true
	for n in get_parent().get_children():
		if not n is Node3D or n == self:
			continue
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			var b: AABB = mi.global_transform * mi.get_aabb()
			caja = b if primera else caja.merge(b)
			primera = false
	if primera:
		return
	var suelo_y := -2.5
	# el suelo: un plano grande con un agujero donde está la caja (cuatro rectángulos)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var R := 6000.0
	var x0 := caja.position.x + 0.5
	var x1 := caja.end.x - 0.5
	var z0 := caja.position.z + 0.5
	var z1 := caja.end.z - 0.5
	for r in [[-R, -R, R, z0], [-R, z1, R, R], [-R, z0, x0, z1], [x1, z0, R, z1]]:
		var a := Vector3(r[0], suelo_y, r[1])
		var b := Vector3(r[2], suelo_y, r[1])
		var c := Vector3(r[2], suelo_y, r[3])
		var d := Vector3(r[0], suelo_y, r[3])
		st.set_normal(Vector3.UP)
		for p in [a, b, c, a, c, d]:
			st.add_vertex(p)
	var plano := MeshInstance3D.new()
	plano.mesh = st.commit()
	plano.material_override = Mat._color(Color("8d8a7c"), 0, Mat.TIERRA)
	plano.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(plano)
	lejanos.append(plano)

	# las casas: cajas por manzana, de 3 a 7 m (más altas cerca del centro)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7101
	var casas: Array[Transform3D] = []
	var colores: Array[Color] = []
	var arboles: Array[Transform3D] = []
	var paleta := [Color("e5d2c2"), Color("d8c19e"), Color("efe7d9"), Color("cab899"), Color("d7c8b7"), Color("c8cabf"), Color("e2ceb1")]
	var M := 104.0  # una cuadra con su calle
	var C := 84.0   # la manzana
	for i in range(-15, 16):
		for j in range(-15, 16):
			var cx := i * M
			var cz := j * M
			if cx + C / 2 > caja.position.x - 4 and cx - C / 2 < caja.end.x + 4 and cz + C / 2 > caja.position.z - 4 and cz - C / 2 < caja.end.z + 4:
				continue
			var d := Vector2(cx, cz).length()
			if d > 1600:
				continue
			# casas a lo largo del borde de la manzana
			for lado in 4:
				var k := 0.0
				while k < C:
					var ancho := rng.randf_range(6.0, 14.0)
					var fondo := rng.randf_range(8.0, 16.0)
					var alto := rng.randf_range(3.0, 6.5) * (1.6 if d < 500 and rng.randf() < 0.25 else 1.0)
					var t := -C / 2 + k + ancho / 2
					var p := Vector3.ZERO
					var bs := Basis().scaled(Vector3(ancho, alto, fondo))
					match lado:
						0: p = Vector3(cx + t, 0, cz - C / 2 + fondo / 2)
						1: p = Vector3(cx + t, 0, cz + C / 2 - fondo / 2)
						2:
							p = Vector3(cx - C / 2 + fondo / 2, 0, cz + t)
							bs = Basis().scaled(Vector3(fondo, alto, ancho))
						3:
							p = Vector3(cx + C / 2 - fondo / 2, 0, cz + t)
							bs = Basis().scaled(Vector3(fondo, alto, ancho))
					p.y = suelo_y + alto / 2
					casas.append(Transform3D(bs, p))
					colores.append(paleta[rng.randi() % paleta.size()])
					k += ancho
			for a in rng.randi_range(2, 7):
				var p := Vector3(cx + rng.randf_range(-C / 3, C / 3), 0, cz + rng.randf_range(-C / 3, C / 3))
				var s := rng.randf_range(5.0, 9.0)
				p.y = suelo_y + s * 0.75
				arboles.append(Transform3D(Basis().scaled(Vector3(s, s * 0.9, s)), p))
	var caja_m := BoxMesh.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = caja_m
	mm.instance_count = casas.size()
	for i in casas.size():
		mm.set_instance_transform(i, casas[i])
		mm.set_instance_color(i, colores[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	mmi.material_override = mat
	add_child(mmi)
	lejanos.append(mmi)
	var copa := SphereMesh.new()
	copa.radial_segments = 8
	copa.rings = 4
	copa.radius = 0.5
	copa.height = 1.0
	var ma := MultiMesh.new()
	ma.transform_format = MultiMesh.TRANSFORM_3D
	ma.mesh = copa
	ma.instance_count = arboles.size()
	for i in arboles.size():
		ma.set_instance_transform(i, arboles[i])
	var ami := MultiMeshInstance3D.new()
	ami.multimesh = ma
	ami.material_override = Mat.follaje(Color("587d3a"))
	ami.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ami)
	lejanos.append(ami)
	print("ambiente.gd: ciudad lejana, %d casas y %d árboles" % [casas.size(), arboles.size()])


# ---------- rendimiento ----------

# --sin ssil,ssao,glow,niebla,sombras,blandas,lejos,nubes: apaga partes para medir cuánto cuestan (--calidad baja:
# ssil, ssao y blandas)
func apagar(que: Array) -> void:
	for k in que:
		match k:
			"ssil": env.ssil_enabled = false
			"ssao": env.ssao_enabled = false
			"glow": env.glow_enabled = false
			"niebla": env.fog_enabled = false
			"sombras": sol.shadow_enabled = false
			"blandas":
				RenderingServer.directional_shadow_atlas_set_size(4096, true)
				RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_HARD)
				sol.light_angular_distance = 0.0
			"lejos":
				for n in lejanos:
					n.visible = false
			"nubes": sky.process_mode = Sky.PROCESS_MODE_QUALITY
