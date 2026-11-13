# Un paseo por la Plaza de Armas: la maqueta exportada por tools/export.py (juego/plaza.glb, una caja de 400 m
# alrededor de la plaza: la plaza, las calles que la rodean y las manzanas del frente) con un personaje en tercera
# persona que camina sobre ella.
#
#   make juego                                                     # exporta juego/plaza.glb e importa en Godot (~30 s)
#   /Applications/Godot.app/Contents/MacOS/Godot --path juego       # jugar (o abrir juego/project.godot en el editor)
#   /Applications/Godot.app/Contents/MacOS/Godot --path juego -- --png shots/juego.png [--desde x,y] [--girar 90] [--caminar 3]
#
# WASD o flechas: caminar; Mayús: correr; Espacio: saltar; mouse: mirar; rueda: acercar la cámara (hasta la primera
# persona); Esc: soltar el mouse (un clic lo vuelve a tomar). --png guarda un cuadro y sale; --desde x,y pone al
# personaje en ese punto de grilla, --girar G gira la vista G grados a
# la izquierda y --caminar N camina N segundos hacia adelante antes (para revisar la colisión sin teclado).
#
# Coordenadas como en la página: X = x de grilla (oriente), Y = altura, Z = -y (norte), origen en la plaza.
# Colisión: una malla exacta (trimesh) por capa del glb, salvo los árboles (se atraviesan). El importador de Godot no
# usa los colores por vértice del glb (ver tools/godot/ver.gd): se encienden aquí.
extends Node3D

const SIN_COLISION := ["arboles", "alamos", "agua", "autos-ruta5", "trenes"]
const INICIO := Vector2(0, -45)  # x, y de grilla: el borde sur de la plaza, mirando al norte

var jugador: CharacterBody3D


func abs_path(p: String) -> String:
	return p if p.is_absolute_path() else OS.get_environment("PWD").path_join(p)


func _ready() -> void:
	acciones()
	if not ResourceLoader.exists("res://plaza.glb"):
		push_error("falta juego/plaza.glb: corra `make juego` en la raíz del repositorio")
		get_tree().quit(1)
		return
	var plaza: Node3D = load("res://plaza.glb").instantiate()
	add_child(plaza)

	var caja := AABB()
	var primera := true
	for mi in plaza.find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i) as BaseMaterial3D
			if m:
				m.vertex_color_use_as_albedo = true
		var b: AABB = mi.global_transform * mi.get_aabb()
		caja = b if primera else caja.merge(b)
		primera = false
		if not (mi.name in SIN_COLISION or mi.get_parent().name in SIN_COLISION):
			mi.create_trimesh_collision()
	muros(caja)
	ambiente()

	var args := OS.get_cmdline_user_args()
	jugador = preload("res://jugador.gd").new()
	jugador.mouse = not ("--png" in args or "--caminar" in args)
	add_child(jugador)
	await get_tree().physics_frame
	await get_tree().physics_frame
	jugador.inicio = suelo(INICIO.x, -INICIO.y) + Vector3.UP * 0.1
	jugador.global_position = jugador.inicio
	ayuda()

	if "--desde" in args:
		var d: PackedStringArray = args[args.find("--desde") + 1].split(",")
		jugador.inicio = suelo(float(d[0]), -float(d[1])) + Vector3.UP * 0.1
		jugador.global_position = jugador.inicio
	if "--girar" in args:
		jugador.yaw = deg_to_rad(float(args[args.find("--girar") + 1]))
	if "--caminar" in args:
		Input.action_press("adelante")
		await get_tree().create_timer(float(args[args.find("--caminar") + 1])).timeout
		Input.action_release("adelante")
		var choque := jugador.get_last_slide_collision()
		var contra := ""
		if choque and jugador.is_on_wall():
			contra = ", contra «%s»" % choque.get_collider().get_parent().name
		print("main.gd: jugador en x %.1f, y %.1f, altura %.2f%s" % [jugador.global_position.x, -jugador.global_position.z, jugador.global_position.y, contra])
	if "--png" in args:
		for i in 10:
			await RenderingServer.frame_post_draw
		var out := abs_path(args[args.find("--png") + 1])
		get_viewport().get_texture().get_image().save_png(out)
		print("main.gd -> ", out)
		get_tree().quit()


# las teclas, como acciones (así --caminar puede apretarlas)
func acciones() -> void:
	var teclas := {"adelante": [KEY_W, KEY_UP], "atras": [KEY_S, KEY_DOWN], "izquierda": [KEY_A, KEY_LEFT],
		"derecha": [KEY_D, KEY_RIGHT], "saltar": [KEY_SPACE], "correr": [KEY_SHIFT]}
	for a in teclas:
		if InputMap.has_action(a):
			continue
		InputMap.add_action(a)
		for k in teclas[a]:
			var e := InputEventKey.new()
			e.physical_keycode = k
			InputMap.action_add_event(a, e)


# el suelo bajo (X, Z): un rayo desde arriba contra la colisión
func suelo(x: float, z: float) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, 200, z), Vector3(x, -200, z))
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	return r.position if r else Vector3(x, 0, z)


# muros invisibles en el borde de la caja exportada, para no caerse de la maqueta
func muros(caja: AABB) -> void:
	var c := caja.get_center()
	var s := caja.size
	var cuerpo := StaticBody3D.new()
	add_child(cuerpo)
	for m in [[Vector3(c.x, c.y, caja.position.z), Vector3(s.x, 200, 1)], [Vector3(c.x, c.y, caja.end.z), Vector3(s.x, 200, 1)],
			[Vector3(caja.position.x, c.y, c.z), Vector3(1, 200, s.z)], [Vector3(caja.end.x, c.y, c.z), Vector3(1, 200, s.z)]]:
		var forma := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = m[1]
		forma.shape = b
		forma.position = m[0]
		cuerpo.add_child(forma)


# cielo, luz y niebla: el sol del nor-nororiente, como en la página (SUND), y una niebla que esconde el borde
func ambiente() -> void:
	var cielo := ProceduralSkyMaterial.new()
	cielo.sky_top_color = Color("6f9fd0")
	cielo.sky_horizon_color = Color("e8e2d6")
	cielo.ground_horizon_color = Color("e8e2d6")
	cielo.ground_bottom_color = Color("b9b2a4")
	var sky := Sky.new()
	sky.sky_material = cielo
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color("e8e2d6")
	env.fog_depth_begin = 90
	env.fog_depth_end = 220
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sol := DirectionalLight3D.new()
	sol.light_energy = 0.7
	sol.shadow_enabled = true
	sol.directional_shadow_max_distance = 150
	add_child(sol)
	sol.look_at_from_position(Vector3(0.35, 1.0, -0.9), Vector3.ZERO)  # desde el norte (-Z), un poco al oriente


func ayuda() -> void:
	var capa := CanvasLayer.new()
	add_child(capa)
	var l := Label.new()
	l.text = "WASD: caminar · Mayús: correr · Espacio: saltar · mouse: mirar · rueda: cámara · Esc: soltar el mouse"
	l.position = Vector2(16, 12)
	l.add_theme_color_override("font_color", Color(1, 1, 1))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("outline_size", 4)
	capa.add_child(l)
