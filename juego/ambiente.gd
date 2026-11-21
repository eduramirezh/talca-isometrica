# Cielo, luz, sombras, niebla, posproceso y la hora del día (main.gd lo agrega a la escena, después de recortar el glb).
#
# El sol está donde está en Talca (35,43° S, 71,67° O) el día y a la hora del juego. Jugando, son los del computador, y
# el reloj corre con el suyo (al_reloj(); la diferencia con UTC, la de Chile ese día: utc_chile()); en una partida de la
# red local, los del anfitrión (la_hora()). Con --hora, o en una captura o una toma (FIJA: --png, --fps, --cine,
# --trailer, --vp), la hora queda quieta, para que salga igual cada vez: el 15 de enero a las 17:00 (UTC−3, la hora de
# verano; el sol a ~45°, al poniente nor-poniente) o la pedida. La tecla T avanza una hora (Mayús+T
# retrocede) y L pasa del día a la noche o de la noche al día (el reloj corre hacia adelante, en ~3 s, hasta la noche
# cerrada o hasta la hora de día del comienzo; con el reloj, hasta la suya si es de día), con atardecer, crepúsculo y noche: de noche la luz es la de la luna, las ventanas se encienden y los
# faroles de la plaza alumbran. El cielo es shaders/cielo.gdshader (nubes, la cordillera, estrellas) y también da la luz
# ambiente y los reflejos. Las capas del glb toman su material de materiales.gd (shaders/capa.gdshader): la textura,
# las ventanas y el brillo de cada superficie, sobre el color por vértice de la maqueta. Hasta noviembre de 2026, más
# allá de la caja de 400 m de plaza.glb había una ciudad inventada de bloques bajos; ahora está la comuna (mapa.gd).
#
#   --hora 20.5      la hora al comenzar, quieta (decimal, hora de verano)
#   --dia 172        el día del año (1 = 1 de enero)
#   --reloj ahora    la hora del computador también en una captura; --reloj 2026-07-15T18:30, la de ese momento como si
#                    fuera la del computador, que corre desde ahí (para ver el invierno sin cambiar el reloj)
#   --calidad baja   sin SSIL, SSAO ni sombras blandas (para máquinas más lentas)
#   --sin a,b        apaga partes para medir su costo con --fps (modelos/calles.gd): ssil, ssao, glow, niebla,
#                    sombras, blandas, lejos (las teselas de lejos.glb), nubes
extends Node3D

const Mat := preload("res://materiales.gd")
const Args := preload("res://args.gd")
const Glb := preload("res://glb.gd")
const LAT := -35.4265
const LON := -71.666
const UTC := -3.0  # la hora de verano: la de --hora y las capturas
const GIRO := 5.0  # grados: la grilla está girada; el norte verdadero queda 5° al poniente del norte de la grilla
const FIJA := ["--png", "--fps", "--cine", "--trailer", "--vp"]  # la hora quieta de siempre (salvo con --reloj)

var dia := 15
var hora := 17.0
var objetivo := 17.0
var hora_dia := 17.0  # adonde va L de noche: la hora del comienzo si es de día, si no las 17:00
var rapidez := 1.5  # horas por segundo hacia objetivo
var utc := UTC  # la diferencia con UTC de la hora del juego (sol_en())
var fija := false  # --hora o una captura: la hora no corre ni la cambia el anfitrión
var corre := false  # la hora corre con el reloj del computador (al_reloj()) o con el del anfitrión (la_hora())
var real := 17.0  # la hora de ese reloj en t_reloj, sin lo que la movieron T y L
var t_reloj := 0.0  # Time.get_unix_time_from_system() del último paso del reloj
var simulado := NAN  # --reloj aaaa-mm-ddThh:mm: los segundos entre esa fecha y la del computador
var de := ""  # de quién es la hora mientras nadie la mueve aquí («computador», «anfitrión»; texto_hora())
var con_anfitrion := false  # ya llegó la hora del anfitrión de la partida (la primera salta; las que siguen, corren)
var red: Node  # red.gd (main.gd): si es el anfitrión de una partida, manda la hora a los demás
var env: Environment
var sky: Sky
var cielo: ShaderMaterial
var sol: DirectionalLight3D
var faroles: Array[OmniLight3D] = []
var focos: MultiMeshInstance3D
var reloj: Label
var reloj_t := 0.0


func _init() -> void:
	name = "ambiente"  # la_hora() busca este nodo por su ruta: tiene que llamarse igual en todos


func _ready() -> void:
	fija = Args.has("--hora") or (not Args.has("--reloj") and FIJA.any(func(f: String) -> bool: return Args.has(f)))
	if fija:
		hora = Args.num("--hora", hora, 0.0, 24.0)
	else:
		var s := Args.texto("--reloj", "ahora")
		if s != "ahora":
			if RegEx.create_from_string("^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}$").search(s):
				simulado = Time.get_unix_time_from_datetime_string(s + ":00") - Time.get_unix_time_from_system()
			else:
				push_warning("ambiente.gd: --reloj espera ahora o aaaa-mm-ddThh:mm, no «%s»" % s)
		al_reloj()
	dia = int(Args.num("--dia", dia, 1, 366))
	objetivo = hora
	if sol_en(dia, fposmod(hora, 24.0)).y > 0.1:
		hora_dia = hora
	# noche, sol_dir y luna_dir son parámetros globales de los sombreadores ([shader_globals] de project.godot)
	calidad()
	entorno()
	copas()
	materiales()
	buscar_faroles()
	hud()
	poner_hora(hora)
	apagar(Array(Args.sin_()))
	multiplayer.peer_connected.connect(_llego)


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
			if not Glb.es_capa(nombre):
				nombre = String(mi.get_parent().name)
			if Glb.tipo(nombre) != "":
				mi.material_override = Mat.capa(nombre, Glb.tipo(nombre))


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
	var solar := h + (4.0 * (LON - 15.0 * utc) + eot) / 60.0
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
	var fz := faroles_mapa()
	if fz:
		fz.noche(noche)
	if reloj:
		reloj.text = "%02d:%02d  ·  T: avanzar la hora (Mayús+T: retroceder)  ·  L: día o noche" % [int(h24), int(fmod(h24, 1.0) * 60.0)]


func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey and e.pressed and not e.echo):
		return
	if e.physical_keycode == KEY_T:
		ir_a_hora(objetivo + (-1.0 if e.shift_pressed else 1.0))
	elif e.physical_keycode == KEY_L:
		ir_a_hora(dia_o_noche(objetivo))


# el reloj corre hasta h (T, L y el menú de Esc, menu.gd); el anfitrión de una partida se la manda a los demás
func ir_a_hora(h: float) -> void:
	correr_a(h)
	de = ""
	if red and red.anfitrion():
		la_hora.rpc(paquete())


func correr_a(h: float) -> void:
	objetivo = h
	rapidez = max(1.5, abs(objetivo - hora) / 3.0)  # una hora a 1,5 por segundo; un salto largo, en ~3 s
	reloj_t = 4.0


# La hora a la que lleva L desde h (siempre hacia adelante, para pasar por el atardecer o el amanecer): si en h el sol
# está bajo el horizonte, la próxima hora_dia (con el reloj, la suya si es de día); si no, la noche cerrada (noche = 1
# en poner_hora) y un cuarto de hora más.
func dia_o_noche(h: float) -> float:
	if sol_en(dia, fposmod(h, 24.0)).y < 0.0:
		var vuelta := hora_dia
		if corre and sol_en(dia, fposmod(real, 24.0)).y > 0.1:
			vuelta = real
		var d := fposmod(vuelta - h, 24.0)
		return h + (d if d > 0.0 else 24.0)
	var t := h
	for i in 96:  # 24 h en pasos de 15 minutos
		t += 0.25
		if sol_en(dia, fposmod(t, 24.0)).y < -0.16:
			return t + 0.25
	return h + 12.0


func _process(dt: float) -> void:
	if corre:
		var t := Time.get_unix_time_from_system()
		if abs(t - t_reloj) >= 1.0:  # cada segundo (el sol se mueve 0,004°); si el reloj del computador salta, con él
			var a := (t - t_reloj) / 3600.0
			t_reloj = t
			real += a
			hora += a
			objetivo += a
			poner_hora(hora)
	if hora != objetivo:
		hora = move_toward(hora, objetivo, dt * rapidez)
		poner_hora(hora)
	if reloj:
		reloj_t = max(reloj_t - dt, 0.0)
		reloj.modulate.a = clampf(reloj_t, 0.0, 1.0) * 0.6 + 0.4


# ---------- el reloj del computador ----------

# la hora y el día del computador (o los de --reloj, que corren desde que partió el juego) y su diferencia con UTC;
# desde ahí, la hora corre con su reloj (_process)
func al_reloj() -> void:
	var ahora := Time.get_unix_time_from_system()
	var f := Time.get_datetime_dict_from_system()
	var u := snappedf((Time.get_unix_time_from_datetime_dict(f) - ahora) / 3600.0, 0.25)
	if not is_nan(simulado):
		f = Time.get_datetime_dict_from_unix_time(int(ahora + simulado))
		u = NAN
	utc = utc_chile(f, u)
	dia = dia_del_ano(f)
	real = f["hour"] + f["minute"] / 60.0 + f["second"] / 3600.0
	hora = real
	corre = true
	t_reloj = ahora
	de = "computador"


# La diferencia con UTC de la hora de Chile continental en la fecha f: la del computador (u) si es una de las dos de
# Chile (−3, la de verano, o −4); si no (un computador con otra zona, o una fecha de --reloj), la regla de Chile desde
# 2023: la de invierno desde el primer domingo desde el 2 de abril hasta el primer domingo desde el 2 de septiembre. Así
# las 18:00 del computador son las 18:00 de Talca, con el sol de esa hora.
static func utc_chile(f: Dictionary, u := NAN) -> float:
	if u == -3.0 or u == -4.0:
		return u
	var y: int = f["year"]
	var d := _fecha(y, f["month"], f["day"])
	return -4.0 if d >= _domingo(y, 4) and d < _domingo(y, 9) else -3.0


static func dia_del_ano(f: Dictionary) -> int:
	return roundi((_fecha(f["year"], f["month"], f["day"]) - _fecha(f["year"], 1, 1)) / 86400.0) + 1


# las 0 h de una fecha, en segundos desde 1970 (como en UTC: sirve para contar días)
static func _fecha(y: int, m: int, d: int) -> int:
	return Time.get_unix_time_from_datetime_dict({"year": y, "month": m, "day": d})


# el primer domingo desde el 2 de ese mes
static func _domingo(y: int, m: int) -> int:
	var d := _fecha(y, m, 2)
	var wd: int = Time.get_datetime_dict_from_unix_time(d)["weekday"]  # 0: domingo
	return d + (7 - wd) % 7 * 86400


# la hora del juego en palabras (red.gd prueba())
func texto_hora() -> String:
	var h := fposmod(hora, 24.0)
	return "%02d:%02d:%02d del día %d, UTC%+d, %s%s" % [int(h), int(h * 60.0) % 60, int(h * 3600.0) % 60, dia, int(utc),
		"corre" if corre else "quieta", "" if de == "" else ", la del " + de]


# ---------- la hora en la red local ----------
# El anfitrión de una partida (red.gd) manda su hora a cada uno que llega y a todos cuando la mueve (T, L, el menú): la
# de su reloj, adonde va, el día, la diferencia con UTC y si corre. El que llega la toma de una vez y las que siguen las
# corre como con T, salvo con --hora o en una captura (fija). Cada uno puede mover la suya con T y L, solo para él, hasta
# que el anfitrión mueva la de él; al salir de la partida vuelve a la del computador. Este nodo («ambiente») tiene su
# propia rpc, así que no corre la numeración de las de red.gd; una copia del juego sin ella deja un error en su consola
# cada vez que le llega y sigue con su hora.

func _llego(id: int) -> void:
	if red and red.anfitrion():
		la_hora.rpc_id(id, paquete())


func paquete() -> Array:
	var a := (Time.get_unix_time_from_system() - t_reloj) / 3600.0 if corre else 0.0  # lo que corrió desde el último paso
	return [real + a, objetivo + a, dia, utc, corre]


@rpc("authority", "call_remote", "reliable")
func la_hora(e: Array) -> void:
	if fija or e.size() < 5:  # una copia más nueva puede mandar más valores, agregados al final
		return
	real = e[0]
	dia = int(e[2])
	utc = e[3]
	corre = e[4]
	t_reloj = Time.get_unix_time_from_system()
	de = "anfitrión"
	if con_anfitrion:
		correr_a(e[1])
	else:
		con_anfitrion = true
		var antes := hora
		hora = e[1]
		objetivo = hora
		poner_hora(hora)
		if red and absf(fposmod(hora - antes + 12.0, 24.0) - 12.0) > 1.0 / 60.0:  # el sol saltó: se dice por qué
			var h := fposmod(hora, 24.0)
			red.avisar("La hora es la del anfitrión: %02d:%02d" % [int(h), int(fmod(h, 1.0) * 60.0)])


# red.gd salio (salir, y también crear o unirse a otra): de vuelta a la hora del computador, por el camino más corto
func salio() -> void:
	if not con_anfitrion:
		return
	con_anfitrion = false
	var h := hora
	al_reloj()
	hora = h
	correr_a(real + 24.0 * roundf((h - real) / 24.0))


func hud() -> void:
	var capa := CanvasLayer.new()
	add_child(capa)
	reloj = Label.new()
	reloj.anchor_left = 1.0
	reloj.anchor_right = 1.0
	reloj.offset_left = -680
	reloj.offset_right = -16
	reloj.offset_top = 12
	reloj.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	reloj.add_theme_color_override("font_color", Color(1, 1, 1))
	reloj.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	reloj.add_theme_constant_override("outline_size", 4)
	capa.add_child(reloj)


# ---------- los faroles de la plaza ----------

# Las luces de noche de los hitos del glb (GLOW de la página: tools/export.py las escribe en mapa/indice.json, «luces»): en
# cada una va una lámpara, y su luz de verdad la reparte mapa.gd/faroles.gd entre las más cercanas a la cámara, con las
# de las calles (hasta noviembre de 2026 eran ~600 OmniLight3D, una por lámpara, y la lámpara una esfera de 4.000
# triángulos: 2,4 millones de noche). Las que caen donde un modelo propio recorta los hitos (main.gd recortado()) no:
# ese modelo pone las suyas (plaza.gd luces_de_noche(), en `faroles`).
func faroles_mapa() -> Node:
	return get_parent().get_node_or_null("mapa/faroles")


func buscar_faroles() -> void:
	var main := get_parent()
	var altos: Array[Vector3] = []
	for p in Glb.luces():
		if main.has_method("recortado") and main.recortado(Vector2(p.x, -p.z), "hitos"):
			continue
		altos.append(p)
	var lampara := SphereMesh.new()
	lampara.radius = 0.22
	lampara.height = 0.44
	lampara.radial_segments = 10
	lampara.rings = 5
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = lampara
	mm.instance_count = altos.size()
	for i in altos.size():
		var p := altos[i]
		mm.set_instance_transform(i, Transform3D(Basis(), p))
	var fz := faroles_mapa()
	if fz:
		fz.poner_fijas(altos)
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
			"lejos":  # las teselas de lejos.glb (mapa.gd)
				var m := get_parent().get_node_or_null("mapa")
				if m:
					m.lejos_visible(false)
			"nubes": sky.process_mode = Sky.PROCESS_MODE_QUALITY
