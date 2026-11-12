# Visor de lo que exporta tools/export.py en Godot: carga un glb en tiempo de ejecución (GLTFDocument, el mismo
# importador del editor) y lo muestra con una cámara ortográfica desde el sureste, como la página.
#
#   /Applications/Godot.app/Contents/MacOS/Godot --path tools/godot -- shots/export/centro.glb
#   /Applications/Godot.app/Contents/MacOS/Godot --path tools/godot -- shots/export/centro.glb --png shots/export/godot.png
#
# El importador de Godot no usa los colores por vértice (COLOR_0) de una primitiva con material: este visor los
# enciende; en el editor, en la importación avanzada del glb, extraiga los materiales y marque en cada uno
# Vertex Color > Use as Albedo.
#
# Arrastrar: girar; botón derecho o central: desplazar; rueda: zoom; F: encuadrar todo. Con --png guarda el primer
# cuadro y sale. Godot no lee STL: el STL se mira en Blender (tools/blender_ver.py). Para verlo en el editor, copie
# el glb dentro de un proyecto de Godot y ábralo con doble clic (o arrástrelo a una escena).
extends Node3D

var cam := Camera3D.new()
var pivot := Vector3.ZERO
var yaw := PI / 4  # desde el sureste
var pitch := deg_to_rad(35.264)
var extent := 1000.0


func abs_path(p: String) -> String:
	return p if p.is_absolute_path() else OS.get_environment("PWD").path_join(p)


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("uso: Godot --path tools/godot -- <archivo.glb> [--png salida.png]")
		get_tree().quit(1)
		return
	var path := abs_path(args[0])
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	var err := doc.append_from_file(path, st)
	if err != OK:
		push_error("no se pudo leer %s (%s)" % [path, error_string(err)])
		get_tree().quit(1)
		return
	var scene := doc.generate_scene(st)
	add_child(scene)

	var env := Environment.new()  # el fondo y la luz de la página (cielo y sol del nor-nororiente)
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("e8e2d6")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_energy = 0.55
	sun.shadow_enabled = true
	add_child(sun)
	sun.look_at_from_position(Vector3(-0.35, 1.0, -0.9), Vector3.ZERO)  # luz desde el norte (-Z) y un poco al oriente
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.near = 1
	cam.far = 100000
	add_child(cam)

	var box := AABB()
	var first := true
	var n := 0
	for mi in scene.find_children("*", "MeshInstance3D", true, false):
		# el glb trae los colores en COLOR_0 con un material blanco (glTF los multiplica); el importador de Godot
		# no los usa si la primitiva tiene material, y todo sale blanco: se encienden aquí
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i) as BaseMaterial3D
			if m:
				m.vertex_color_use_as_albedo = true
		var b: AABB = mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
		n += 1
	print("ver.gd: %d mallas, caja %s" % [n, box])
	pivot = box.get_center()
	extent = max(box.size.x, box.size.z)
	frame_all()

	if "--png" in args:
		var out := abs_path(args[args.find("--png") + 1])
		for i in 3:
			await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out)
		print("ver.gd -> ", out)
		get_tree().quit()


func frame_all() -> void:
	cam.size = extent * 0.75
	place()


func place() -> void:
	var d := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	cam.look_at_from_position(pivot + d * extent * 5, pivot)


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		if e.button_mask & MOUSE_BUTTON_MASK_LEFT:
			yaw -= e.relative.x * 0.005
			pitch = clamp(pitch + e.relative.y * 0.005, deg_to_rad(5), deg_to_rad(89))
			place()
		elif e.button_mask & (MOUSE_BUTTON_MASK_RIGHT | MOUSE_BUTTON_MASK_MIDDLE):
			var k := cam.size / get_viewport().get_visible_rect().size.y
			pivot -= cam.global_basis.x * e.relative.x * k
			pivot += Vector3(cam.global_basis.y.x, 0, cam.global_basis.y.z).normalized() * e.relative.y * k
			place()
	elif e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam.size *= 0.9
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam.size /= 0.9
	elif e is InputEventKey and e.pressed and e.keycode == KEY_F:
		frame_all()
