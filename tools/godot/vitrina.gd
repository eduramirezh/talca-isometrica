# Un modelo del juego solo, sin el mapa: para mirarlo mientras se trabaja en él, en segundos y no en minutos (cargar la
# comuna con Vulkan por CPU, lavapipe, tarda varios minutos). Un suelo gris, el cielo y el sol del día, y una hoja
# con cuatro vistas alrededor del modelo (o --vistas N), cada una de --size.
#
#   tools/godot_oculto.sh --path juego -s $PWD/tools/godot/vitrina.gd -- <que> --png shots/v.png [--size 640x480]
#       [--vistas 4] [--alto 15] [--dist D] [--centro x,y,z] [--rapidez 3] [--t 0.4] [--color 3b6fa0] [--noche]
#
# <que>:
#   peaton | perro | gata
#                       el peatón de peaton.gd, el perro de perro.gd o la gata de gata.gd, animado --t s a --rapidez m/s
#                       (0 quieto, 1,5 camina, 8 corre, 18 galopa; la gata, quieta más de 1,2 s, se sienta, y más de 14 s,
#                       se echa); --aire: en el aire, --salto n: en el salto n del triple salto (con --t, cuánto después
#                       de saltar: la voltereta del tercero a ~0,4)
#   bici | auto         el vehículo de vehiculo.gd (armar())
#   bici:quien          la bicicleta con el peatón, el perro o la gata (quien: peaton, perro o gata) pedaleando --t s
#                       (sentar())
#   jetpack:quien       el peatón, el perro o la gata con el jetpack puesto, en vuelo (volar())
#   auto:N              el auto N de modelos/entorno/auto.gd (0 sedán … 6 camión), del color --color
#   autos               los siete en fila
#   arbol:especie[:v]   un árbol de modelos/plaza/arboles.gd (palmera, cedro, araucaria, frondoso, podado, cordyline,
#                       arbusto, agapanto, alamo), la variante v
#   arboles             todas las especies en fila
# --alto: grados sobre el horizonte de la cámara; --dist: su distancia (si no, del tamaño del modelo); --azimut: los grados
# de la primera vista alrededor del modelo (30; 90: de costado, desde la derecha); --centro: el punto que mira la cámara,
# en m desde el pie del modelo (si no, el centro de su caja; para acercarse a una parte, como la cara de la gata:
# --centro 0,0.3,-0.25 --dist 0.35).
extends SceneTree

const Args := preload("res://args.gd")
const Malla := preload("res://malla.gd")
const Auto := preload("res://modelos/entorno/auto.gd")
const Arboles := preload("res://modelos/plaza/arboles.gd")

var raiz := Node3D.new()


func arg(nombre: String, defecto: String) -> String:
	var a := OS.get_cmdline_user_args()
	var i := a.find(nombre)
	return a[i + 1] if i >= 0 and i + 1 < a.size() else defecto


func _initialize() -> void:
	_correr.call_deferred()


func _correr() -> void:
	var a := OS.get_cmdline_user_args()
	if a.is_empty() or a[0].begins_with("--"):
		printerr("vitrina.gd: falta <que> (peaton, perro, bici, bici:quien, jetpack:quien, auto, auto:N, autos, arbol:especie[:v], arboles)")
		quit(1)
		return
	var que: String = a[0]
	var tam := arg("--size", "640x480").split("x")
	var W := int(tam[0])
	var H := int(tam[1])
	var n := int(arg("--vistas", "4"))
	var noche := a.has("--noche")
	root.size = Vector2i(W, H)
	root.add_child(raiz)
	escena(noche)
	var modelo := await construir(que)
	if modelo == null:
		quit(1)
		return
	var caja := aabb(modelo)
	print("vitrina.gd: %s, caja %s" % [que, caja])
	var c := caja.get_center()
	var r := maxf(caja.size.length() * 0.5, 0.5)
	if arg("--centro", "") != "":
		var p := arg("--centro", "").split_floats(",")
		c = Vector3(p[0], p[1], p[2])
	var cam := Camera3D.new()
	cam.fov = 40
	raiz.add_child(cam)
	cam.current = true
	var alto := deg_to_rad(float(arg("--alto", "15")))
	var dist := float(arg("--dist", str(r / sin(deg_to_rad(20)) * 1.05)))
	var hoja := Image.create(W * mini(n, 2), H * ((n + 1) / 2), false, Image.FORMAT_RGB8)
	for k in n:
		var az := deg_to_rad(float(arg("--azimut", "30")) + 360.0 * k / n)
		cam.position = c + Vector3(sin(az) * cos(alto), sin(alto), cos(az) * cos(alto)) * dist
		cam.look_at(c)
		for _f in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		hoja.blit_rect(img, Rect2i(0, 0, W, H), Vector2i((k % 2) * W, (k / 2) * H))
	var png := arg("--png", "vitrina.png")
	if not png.is_absolute_path():
		png = OS.get_environment("PWD").path_join(png)
	DirAccess.make_dir_recursive_absolute(png.get_base_dir())
	hoja.save_png(png)
	print("vitrina.gd: -> ", png)
	quit(0)


func escena(noche: bool) -> void:
	var env := Environment.new()
	var cielo := Sky.new()
	var pm := ProceduralSkyMaterial.new()
	cielo.sky_material = pm
	env.background_mode = Environment.BG_SKY
	env.sky = cielo
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	if noche:
		env.ambient_light_energy = 0.15
		pm.sky_top_color = Color(0.02, 0.03, 0.08)
		pm.sky_horizon_color = Color(0.05, 0.06, 0.12)
	RenderingServer.global_shader_parameter_set("noche", 1.0 if noche else 0.0)  # el de ambiente.gd: ventanas, pupilas de la gata
	var we := WorldEnvironment.new()
	we.environment = env
	raiz.add_child(we)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-50, -30, 0)
	sol.shadow_enabled = true
	sol.light_energy = 0.1 if noche else 1.0
	raiz.add_child(sol)
	var suelo := MeshInstance3D.new()
	var pl := PlaneMesh.new()
	pl.size = Vector2(200, 200)
	suelo.mesh = pl
	var ms := StandardMaterial3D.new()
	ms.albedo_color = Color(0.45, 0.45, 0.43)
	suelo.material_override = ms
	raiz.add_child(suelo)


func construir(que: String) -> Node3D:
	var p := que.split(":")
	var n := Node3D.new()
	raiz.add_child(n)
	match p[0]:
		"peaton", "perro", "gata":
			var pe: Node3D = load("res://%s.gd" % p[0]).new()
			n.add_child(pe)
			await process_frame
			var rap := float(arg("--rapidez", "0"))
			var t := float(arg("--t", "0.4"))
			var dt := 1.0 / 60
			var salto := int(arg("--salto", "0"))
			var suelo := not (OS.get_cmdline_user_args().has("--aire") or salto > 0)
			if salto > 0:
				pe.saltar(salto)
			for _i in int(t / dt):
				pe.animar(dt, rap, suelo)
		"bici", "jetpack" when p.size() == 2:
			var v: Node3D = load("res://vehiculo.gd").new()
			n.add_child(v)
			await process_frame
			v.visible = true
			v.armar(p[0])
			await process_frame
			var pe: Node3D = load("res://%s.gd" % p[1]).new()
			v.asiento.add_child(pe)
			await process_frame
			var t := float(arg("--t", "0.6"))
			var dt := 1.0 / 60
			var biela := 0.0
			for _i in int(t / dt):
				if p[0] == "bici":
					biela += 3.0 / 4.3 * TAU * dt
					v.biela.rotation.x = -biela
					var pies := []
					for i in 2:
						var a: float = -biela + PI * i
						pies.append(v.BIELA_C + Vector2(cos(a), sin(a)) * v.BIELA_R + Vector2(-0.03, 0.07) - v.CADERA)
					pe.sentar(dt, pies, 0.62, v.BICI_BRAZOS.x, v.BICI_BRAZOS.y)
				else:
					v.mochila_puesta(true, pe)
					v.llama = 0.6
					v.pose_vuelo(dt, pe)
		"bici", "auto" when p.size() == 1:
			var v: Node3D = load("res://vehiculo.gd").new()
			n.add_child(v)
			await process_frame
			v.visible = true
			v.armar(p[0])
			await process_frame
		"auto":
			auto(n, int(p[1]), Vector3.ZERO)
		"autos":
			for i in Auto.TIPOS:
				auto(n, i, Vector3(i * 3.2 - 9.6, 0, 0))
		"arbol":
			var ar := Arboles.new()
			arbol(n, ar, p[1], int(p[2]) if p.size() > 2 else 0, Vector3.ZERO)
		"arboles":
			var ar := Arboles.new()
			var x := 0.0
			for e in ar.ESPECIES:
				arbol(n, ar, e, 0, Vector3(x, 0, 0))
				x += ar.radio(e, 0) * 2 + 2
		_:
			printerr("vitrina.gd: no sé qué es «%s»" % que)
			return null
	return n


func auto(n: Node3D, tipo: int, pos: Vector3) -> void:
	var m := Malla.new()
	m.solido = false
	var col := Color(arg("--color", "a01814"))
	Auto.modelo(m, Malla.Marco.new(pos.x, -pos.z, PI / 2), tipo, col)
	m.construir(n, "auto%d" % tipo)


func arbol(n: Node3D, ar, especie: String, v: int, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = ar.malla(especie, v)
	mi.position = pos
	n.add_child(mi)


func aabb(n: Node3D) -> AABB:
	var caja := AABB()
	var primera := true
	for c in n.find_children("*", "VisualInstance3D", true, false):
		if c is Light3D:  # su alcance no es el modelo (la luz de las llamas del jetpack: 28 m)
			continue
		var vi: VisualInstance3D = c
		var b := vi.global_transform * vi.get_aabb()
		if b.size == Vector3.ZERO:
			continue
		caja = b if primera else caja.merge(b)
		primera = false
	return caja
