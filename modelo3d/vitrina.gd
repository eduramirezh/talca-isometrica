# Los vehículos de modelos/entorno/auto.gd en fila, uno de cada tipo (en el orden de sus constantes, el camión al final)
# con uno de los tres colores más comunes del suyo en config/autos.json, sobre un piso gris y con el sol de la tarde: para revisar los modelos sin
# exportar el mapa. Se corre oculto, como todo Godot en una sesión de Claude, y guarda una captura:
#
#   tools/godot_oculto.sh --path modelo3d -s res://vitrina.gd -- --png shots/vitrina.png [--girar 55] [--mirar 18] [--tipos 3,7,8]
#
# --girar: el ángulo de la vista desde el frente de los autos (grados, 55 por omisión, + hacia su izquierda; 180: de atrás), --mirar:
# desde arriba (grados), --tipos: solo esos (los índices de NOMBRES de auto.gd). Lo dibuja con los materiales de
# materiales.gd (Mat.patron), como calles.gd los autos de la plaza.
extends SceneTree

const Args := preload("res://args.gd")
const Auto := preload("res://modelos/entorno/auto.gd")
const Malla := preload("res://malla.gd")

const PASO := 4.5  # m entre el eje de un auto y el del siguiente (más su ancho sobre 1,8 m)


func _initialize() -> void:
	var raiz := Node3D.new()
	root.add_child(raiz)
	var tipos := []
	for t in Args.lista("--tipos"):
		tipos.append(int(t))
	if tipos.is_empty():
		tipos = range(Auto.TIPOS)
		tipos.erase(Auto.CAMION)
		tipos.append(Auto.CAMION)  # el camión, de 11,5 m, al final: no tapa a los otros
	var T := Auto.tipos()
	# mirando hacia +x de grilla (X de Godot), uno al lado del otro hacia -y (Z de Godot)
	var m := Malla.new()
	var y := 0.0
	var largo := 0.0
	for i in tipos.size():
		var t: int = tipos[i]
		var c: Array = Auto.caja(t)
		# uno de los tres colores más comunes de su tipo, alternados para que se distingan
		var cols: Array = T[t]["colores"] if T.size() > t else []
		var col: Color = cols[i % mini(3, cols.size())][0] if not cols.is_empty() else Auto.COLORES[i % Auto.COLORES.size()]
		y -= c[0]
		Auto.modelo(m, Malla.Marco.new(0, y, 0, 0), t, col)
		y -= c[0] + PASO - 1.8
		largo = max(largo, c[2] - c[1])
	var mi := MeshInstance3D.new()
	mi.mesh = m.malla()
	raiz.add_child(mi)
	var piso := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(400, 400)
	piso.mesh = pm
	var mp := StandardMaterial3D.new()
	mp.albedo_color = Color(0.42, 0.42, 0.43)
	piso.material_override = mp
	raiz.add_child(piso)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-38, 140, 0)
	sol.shadow_enabled = true
	sol.light_energy = 1.25
	raiz.add_child(sol)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.72, 0.8, 0.88)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.78, 0.85)
	env.environment.ambient_light_energy = 0.7
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	raiz.add_child(env)
	# la cámara: ortográfica, mirando al medio de la fila
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	var medio := Vector3(0, 1.0, -y / 2.0)
	cam.size = max(-y + 2.0, largo * 1.2) * 0.62
	var g := deg_to_rad(Args.num("--girar", 55.0, -180.0, 180.0))
	var a := deg_to_rad(Args.num("--mirar", 18.0, 0.0, 89.0))
	raiz.add_child(cam)
	cam.look_at_from_position(medio + Vector3(cos(g) * cos(a), sin(a), -sin(g) * cos(a)) * 60.0, medio)
	cam.current = true
	root.size = Vector2i(1800, 1000)
	_captura.call_deferred()


func _captura() -> void:
	for i in 8:
		await RenderingServer.frame_post_draw
	var f := Args.texto("--png")
	if f == "":
		push_error("vitrina.gd: falta --png archivo")
		quit(1)
		return
	var out := f if f.is_absolute_path() else OS.get_environment("PWD").path_join(f)
	root.get_texture().get_image().save_png(out)
	print("vitrina.gd -> %s" % out)
	quit()
