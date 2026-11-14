# Un paseo por la Plaza de Armas: la maqueta exportada por tools/export.py (juego/plaza.glb, una caja de 400 m
# alrededor de la plaza: la plaza, las calles que la rodean y las manzanas del frente) con un personaje en tercera
# persona que camina sobre ella.
#
#   make juego                                                     # exporta juego/plaza.glb e importa en Godot (~30 s)
#   /Applications/Godot.app/Contents/MacOS/Godot --path juego       # jugar (o abrir juego/project.godot en el editor)
#   /Applications/Godot.app/Contents/MacOS/Godot --path juego -- --png shots/juego.png [--desde x,y] [--girar 90] [--mirar -10] [--camara 5] [--caminar 3]
#
# WASD o flechas: caminar; Mayús: correr; Espacio: saltar; mouse: mirar; rueda: acercar la cámara (hasta la primera
# persona); Esc: soltar el mouse (un clic lo vuelve a tomar). --png guarda un cuadro y sale; --desde x,y pone al
# personaje en ese punto de grilla, --girar G gira la vista G grados a
# la izquierda, --mirar P la inclina P grados, --camara L pone la cámara a L m (0: primera persona) y --caminar N camina N segundos hacia adelante antes (para revisar la colisión sin teclado).
#
# Coordenadas como en la página: X = x de grilla (oriente), Y = altura, Z = -y (norte), origen en la plaza.
# Colisión: una malla exacta (trimesh) por capa del glb, salvo los árboles (se atraviesan). El importador de Godot no
# usa los colores por vértice del glb (ver tools/godot/ver.gd): se encienden aquí.
#
# Lo que se ve y lo que reemplaza al glb va en archivos propios, para que este no crezca:
#   vp.gd            --vp: producción virtual con una tele de fondo, la cámara movida por un teléfono (ver vp.gd)
#   ambiente.gd      cielo, luz, sombras, niebla y posproceso (un Node3D que se agrega a la escena)
#   jugador.gd       el personaje y su cámara
#   modelos/*.gd     modelos propios del juego, más detallados que los de la página. Cada uno es un Node3D que construye
#                    lo suyo (geometría y colisión) en _ready() y puede declarar
#                      func recortes() -> Array   # [{"poligono": PackedVector2Array([...]), "capas": ["hitos", ...]}]
#                    polígonos en metros de grilla (x al oriente, y al norte; X = x, Z = -y) dentro de los cuales se
#                    quitan del glb los triángulos (por su centro) de esas capas ("capas" vacío o ausente: todas), antes
#                    de crear la colisión. Capas del glb: terreno, suelo, usos, patios, ciudad, autos, arboles,
#                    edificios, hitos, veredas (plaza.json, "capas").
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
	var mods := modelos()
	var recs := []
	for m in mods:
		if m.has_method("recortes"):
			recs.append_array(m.recortes())

	var caja := AABB()
	var primera := true
	for mi in plaza.find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i) as BaseMaterial3D
			if m:
				m.vertex_color_use_as_albedo = true
		recortar(mi, recs)
		var b: AABB = mi.global_transform * mi.get_aabb()
		caja = b if primera else caja.merge(b)
		primera = false
		if not (mi.name in SIN_COLISION or mi.get_parent().name in SIN_COLISION):
			mi.create_trimesh_collision()
	muros(caja)
	add_child(preload("res://ambiente.gd").new())
	for m in mods:
		add_child(m)

	var args := OS.get_cmdline_user_args()
	if "--vp" in args:  # la tele de fondo: la cámara la mueve un teléfono (vp.gd), sin personaje
		add_child(preload("res://vp.gd").new())
		await png(args)
		return
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
	if "--mirar" in args:  # grados sobre (+) o bajo (−) la horizontal
		jugador.pitch = deg_to_rad(float(args[args.find("--mirar") + 1]))
	if "--camara" in args:  # largo del brazo de la cámara en m (0: primera persona)
		jugador.largo = float(args[args.find("--camara") + 1])
		jugador.brazo.spring_length = jugador.largo
	if "--caminar" in args:
		Input.action_press("adelante")
		await get_tree().create_timer(float(args[args.find("--caminar") + 1])).timeout
		Input.action_release("adelante")
		var choque := jugador.get_last_slide_collision()
		var contra := ""
		if choque and jugador.is_on_wall():
			contra = ", contra «%s»" % choque.get_collider().get_parent().name
		print("main.gd: jugador en x %.1f, y %.1f, altura %.2f%s" % [jugador.global_position.x, -jugador.global_position.z, jugador.global_position.y, contra])
	await png(args)


# --png x.png: guarda un cuadro y sale
func png(args: PackedStringArray) -> void:
	if not "--png" in args:
		return
	for i in 10:
		await RenderingServer.frame_post_draw
	var out := abs_path(args[args.find("--png") + 1])
	get_viewport().get_texture().get_image().save_png(out)
	print("main.gd -> ", out)
	get_tree().quit()


# los modelos de modelos/*.gd, en orden de nombre
func modelos() -> Array:
	var out := []
	var fs := Array(ResourceLoader.list_directory("res://modelos/"))
	fs.sort()
	for f in fs:
		if f.ends_with(".gd"):
			out.append(load("res://modelos/" + f).new())
	return out


# quita de una malla del glb los triángulos cuyo centro cae en un recorte que toca su capa
func recortar(mi: MeshInstance3D, recs: Array) -> void:
	var capa := String(mi.name)
	var pols := []
	for r in recs:
		var capas: Array = r.get("capas", [])
		if capas.is_empty() or capa in capas or String(mi.get_parent().name) in capas:
			var pol: PackedVector2Array = r["poligono"]
			var bb := Rect2(pol[0], Vector2.ZERO)
			for p in pol:
				bb = bb.expand(p)
			pols.append([pol, bb])
	if pols.is_empty():
		return
	var am := mi.mesh as ArrayMesh
	var nuevo := ArrayMesh.new()
	var xf := mi.global_transform
	var quitados := 0
	for s in am.get_surface_count():
		var a := am.surface_get_arrays(s)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
		var keep := PackedInt32Array()
		for t in range(0, idx.size(), 3):
			var c := xf * ((v[idx[t]] + v[idx[t + 1]] + v[idx[t + 2]]) / 3.0)
			var p := Vector2(c.x, -c.z)
			var dentro := false
			for pb in pols:
				if pb[1].has_point(p) and Geometry2D.is_point_in_polygon(p, pb[0]):
					dentro = true
					break
			if dentro:
				quitados += 1
			else:
				keep.append(idx[t]); keep.append(idx[t + 1]); keep.append(idx[t + 2])
		if keep.is_empty():
			continue
		a[Mesh.ARRAY_INDEX] = keep
		nuevo.add_surface_from_arrays(am.surface_get_primitive_type(s), a)
		nuevo.surface_set_material(nuevo.get_surface_count() - 1, am.surface_get_material(s))
	mi.mesh = nuevo
	print("main.gd: %s, %d triángulos recortados" % [capa, quitados])


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
