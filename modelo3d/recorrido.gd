# Una toma de cámara por un recorrido fijo, para un video: ver.gd la agrega con --recorrido toma.json (tools/video3d.py
# las arma de config/video3d.json, una corrida de Godot por toma). La toma es una lista de claves en el tiempo, cada
# una con el punto que se mira y la cámara alrededor de él, como las banderas del visor:
#
#   {"id": "plaza", "dur": 6.0, "dia": 15, "hora": [17.0, 21.5],
#    "claves": [{"t": 0, "x": 0, "y": 0, "alto": 1.7, "girar": 45, "mirar": -30, "camara": 300}, …]}
#
#   x, y     el punto en metros de grilla (x al oriente, y al norte; --desde)
#   alto     m del punto sobre el suelo bajo él (1,7 por omisión: los ojos; el suelo, sin edificios ni autos)
#   girar    grados de la vista a la izquierda (0: mirando al norte; --girar)
#   mirar    grados de inclinación (+ arriba; --mirar)
#   camara   m de la cámara al punto (0,01: en el punto; --camara)
#   hora     la hora al comenzar y al terminar (avanza con una curva suave); dia, el día del año (15 de enero)
#   suave    false: la cámara no parte ni llega detenida (por omisión sí)
#
# Entre las claves, cada número sigue una curva de Hermite con las tangentes de Catmull-Rom (por el tiempo de cada
# clave), detenida en la primera y la última (parte y se posa sola); la distancia, en logaritmo (un
# acercamiento de 800 a 2 m va parejo) y el giro sin saltos de 360°. Todo es función del tiempo t de la toma: un
# cuadro se puede rehacer solo (--instantes) y la toma sale igual cada vez.
#
# Antes del primer cuadro, la toma recorre su camino: mide el suelo bajo el punto cada PASO s (la colisión está solo
# alrededor de la cámara, así que la lleva a cada punto y la espera) y fija en mapa.gd los lugares por donde pasa la
# cámara (mapa.fijos): lo que la cámara pediría en cualquier punto del camino se carga antes y no se suelta, así que
# ninguna tesela ni fachada aparece a media toma (solo donde la cámara va a menos de ALTO_FIJO m sobre el suelo: más
# arriba, lo de cerca ya no se distingue). Después espera a que todo eso esté (mapa.esperar()), deja la cámara quieta
# en su primer lugar ESPERA cuadros (los modelos propios que esperan su tesela se arman ahí) y deja el mapa quieto
# (mapa.quieto: no carga ni suelta nada hasta el final; lejos de lo cargado se ve lejos.glb) y pone los árboles de la
# plaza en todos los árboles cargados (arboleda.gd todos_de_cerca(): en el visor, solo a menos de 130 m, y el cambio de
# la copa redonda al árbol se veía al acercarse). Recién entonces corre.
# Los cuadros sueltos (--instantes) salen después de lo mismo: muestran lo que mostrará la toma. La niebla se adelgaza
# con la altura de la cámara (NIEBLA_ALTO) y el fin de la cámara se aleja con su distancia: la comuna entera se ve
# desde 30 km. Movie Maker (--write-movie, --fixed-fps) graba también los cuadros de la carga: la toma imprime
# «recorrido.gd: toma <id> cuadros <n> + <cola>» y tools/video3d.py se queda con los n cuadros que siguen a la espera
# (cuenta desde el final: los últimos <cola> son la cámara quieta en su último lugar).
#
#   tools/godot_oculto.sh --path modelo3d --write-movie $PWD/x.avi --fixed-fps 30 -- --recorrido toma.json
#   tools/godot_oculto.sh --path modelo3d -- --recorrido toma.json --png x.png --instantes 0,3,6   # x-t0.00.png, x-t3.00.png…
#
# Al terminar imprime lo que conviene revisar: la menor altura de la cámara sobre lo que tiene debajo y en cuántos
# cuadros algo tapa el punto (la cámara dentro o detrás de un edificio), con la colisión que hay (a menos de 250 m).
extends Node3D

const Args := preload("res://args.gd")

const PASO := 0.25  # s de la toma entre dos medidas del suelo
const FIJO := 60.0  # m: un punto fijo de mapa.gd cada tanto de camino de la cámara
const ESPERA := 60  # cuadros con la cámara quieta antes de correr
const COLA := 8  # cuadros con la cámara quieta al terminar (tools/video3d.py los descarta)
const FPS := 30.0  # el de --fixed-fps (los cuadros de la toma)
const NO_SUELO := ["edificio", "hito", "auto"]  # lo que el rayo del suelo atraviesa (Glb.tipo de la capa)
const ALTO_FIJO := 1500.0  # m de la cámara sobre el suelo: más arriba, su camino no fija teselas
const NIEBLA_ALTO := 300.0  # m: con la cámara más alta, la niebla se adelgaza en proporción (con 600, las vistas desde 400 m salían lavadas)

var toma := {}
var main: Node  # ver.gd
var ambiente: Node
var cam := Camera3D.new()
var claves := []  # [t, PackedFloat64Array(x, y, alto, giro, inclinación, ln distancia)]
var suelos := PackedFloat64Array()  # el suelo bajo el punto, cada PASO s
var min_alto := INF  # la menor altura de la cámara sobre lo que tiene debajo
var tapado := 0  # cuadros en que algo tapa el punto
var mirado := Vector3.ZERO  # el punto que mira la cámara (poner())
var niebla := 0.0  # la densidad de la niebla de ambiente.gd


# la toma de --recorrido (vacía si no se pidió o no se pudo leer)
static func pedida() -> Dictionary:
	var f := Args.texto("--recorrido")
	if f == "":
		return {}
	var ruta := f if f.is_absolute_path() else OS.get_environment("PWD").path_join(f)
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(ruta))
	if not (d is Dictionary and d.get("claves", []).size() >= 1):
		push_error("recorrido.gd: %s no es una toma (claves)" % ruta)
		return {}
	return d


# el punto de la primera clave (ver.gd arranca el mapa ahí)
static func inicio(t: Dictionary) -> Vector2:
	var k: Dictionary = t["claves"][0]
	return Vector2(float(k.get("x", 0.0)), float(k.get("y", 0.0)))


func _init(t: Dictionary) -> void:
	toma = t
	name = "recorrido"


func dur() -> float:
	return float(toma.get("dur", claves[-1][0] if claves.size() else 1.0))


func _ready() -> void:
	main = get_parent()
	ambiente = main.ambiente
	if ambiente:
		ambiente.dia = int(toma.get("dia", 15))
		if ambiente.reloj:
			ambiente.reloj.get_parent().visible = false  # el reloj de la pantalla
	cam.fov = float(toma.get("fov", 50.0))
	if toma.get("vertical", false):  # el corte vertical (más alto que ancho): el mismo ancho de vista que el horizontal
		cam.keep_aspect = Camera3D.KEEP_WIDTH
		cam.fov = rad_to_deg(2.0 * atan(tan(deg_to_rad(cam.fov) / 2.0) * 16.0 / 9.0))
	cam.near = 0.1
	cam.far = 6000.0
	if ambiente and ambiente.env:
		niebla = ambiente.env.fog_density
	add_child(cam)
	cam.make_current()
	for k in toma["claves"]:
		var v := PackedFloat64Array([float(k.get("x", 0.0)), float(k.get("y", 0.0)), float(k.get("alto", 1.7)),
			deg_to_rad(float(k.get("girar", 0.0))), deg_to_rad(clampf(float(k.get("mirar", -30.0)), -89.0, 89.0)),
			log(clampf(float(k.get("camara", 160.0)), 0.01, 20000.0))])
		if claves.size() > 0:  # el giro, sin saltos de 360° respecto de la clave anterior
			var g0: float = claves[-1][1][3]
			v[3] = g0 + wrapf(v[3] - g0, -PI, PI)
		claves.append([float(k.get("t", 0.0)), v])
	if claves.size() == 1:
		claves.append([dur(), claves[0][1]])
	await preparar()
	var instantes := Args.lista("--instantes")
	if instantes.size() > 0:
		await cuadros(instantes)
		return
	await correr()


# ---------- antes del primer cuadro ----------

func preparar() -> void:
	var t0 := Time.get_ticks_msec()
	# los lugares de la cámara a lo largo del camino (sin el suelo: el que pide mapa.gd no depende de la altura)
	var fijos := PackedVector2Array()
	var n := maxi(1, ceili(dur() / PASO))
	for i in n + 1:
		var l := lugar(dur() * i / n, 0.0)
		var c: Vector3 = l[0]
		var p := Vector2(c.x, -c.z)
		if c.y > ALTO_FIJO and not fijos.is_empty():
			continue  # con el suelo en 0, c.y es la altura de la cámara sobre el suelo bajo el punto
		if fijos.is_empty() or p.distance_to(fijos[-1]) >= FIJO or i == n:
			fijos.append(p)
	main.mapa.fijos = fijos
	# el suelo bajo el punto, cada PASO s
	suelos.resize(n + 1)
	for i in n + 1:
		var v := valor(dur() * i / n)
		suelos[i] = await suelo_en(v[0], v[1])
	print("recorrido.gd: el suelo del camino en %d ms" % (Time.get_ticks_msec() - t0))
	poner(0.0)
	await main.mapa.esperar()
	for i in ESPERA:
		await get_tree().process_frame
	await main.mapa.esperar()  # lo que hayan pedido los modelos que se armaron en la espera
	main.mapa.quieto = true
	main.mapa.arboleda.todos_de_cerca()  # los árboles de la plaza en todos: ninguno cambia de forma a media toma
	print("recorrido.gd: toma %s lista en %d ms (%d puntos fijos, %d teselas cargadas)" % [toma.get("id", "?"),
		Time.get_ticks_msec() - t0, fijos.size(), main.mapa.cargadas.size()])


# el suelo bajo (x, y): la cámara va arriba del punto y espera su colisión (mapa.gd la arma solo alrededor de ella)
func suelo_en(x: float, y: float) -> float:
	if not main.mapa.solido(x, y):
		cam.global_position = Vector3(x, 50.0, -y)
		main.mapa.t_revisar = 0.0
		while not main.mapa.solido(x, y):
			await get_tree().physics_frame
	await get_tree().physics_frame
	return suelo(x, y)


# un rayo desde arriba que solo se detiene en las capas de suelo de las teselas (el terreno, la calle, la vereda, el
# pasto): atraviesa edificios, hitos, autos, fachadas y los modelos propios (la Torre Talca tiene su colisión). Donde un
# modelo recortó el suelo de la tesela (la plaza), el primero que encuentre; si nada, 0 (la plaza)
func suelo(x: float, y: float) -> float:
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, 1500, -y), Vector3(x, -500, -y))
	var fuera := []
	var primero := NAN
	for i in 16:
		q.exclude = fuera
		var r := get_world_3d().direct_space_state.intersect_ray(q)
		if r.is_empty():
			break
		if is_nan(primero):
			primero = r["position"].y
		if es_suelo(r["collider"]):
			return r["position"].y
		fuera.append(r["rid"])
	return 0.0 if is_nan(primero) else primero


func es_suelo(o: Object) -> bool:
	var n := o as Node
	var capa := ""
	while n and n != main:
		if n is MeshInstance3D and capa == "":
			capa = String(n.name)
		if n == main.mapa:  # una capa de una tesela (no las fachadas ni las cajas de los autos, que cuelgan del mapa)
			var Glb := preload("res://glb.gd")
			return Glb.es_capa(capa) and not Glb.tipo(capa) in NO_SUELO
		n = n.get_parent()
	return false


func suelo_t(t: float) -> float:
	if suelos.is_empty():
		return 0.0
	var u := clampf(t / dur(), 0.0, 1.0) * (suelos.size() - 1)
	var i := mini(floori(u), suelos.size() - 2)
	if i < 0:
		return suelos[0]
	return lerpf(suelos[i], suelos[i + 1], u - i)


# ---------- la toma ----------

func correr() -> void:
	poner(0.0)
	for i in 10:  # que el cielo y las sombras se asienten
		await get_tree().process_frame
	var n := roundi(dur() * FPS)
	print("recorrido.gd: toma %s cuadros %d + %d" % [toma.get("id", "?"), n, COLA])
	for i in n:
		poner(i / FPS)
		revisar()
		await get_tree().process_frame
	poner(dur())
	for i in COLA:
		await get_tree().process_frame
	print("recorrido.gd: toma %s, fin (la cámara a %.1f m sobre lo que tiene debajo como mínimo; el punto tapado en %d de %d cuadros)" % [
		toma.get("id", "?"), min_alto, tapado, n])
	get_tree().quit()


# --instantes s,s,…: esos segundos de la toma, con --png x.png (x-t<s>.png), y sale
func cuadros(instantes: PackedStringArray) -> void:
	var out: String = main.abs_path(Args.texto("--png", "user://recorrido.png"))
	for s in instantes:
		if not s.is_valid_float():
			push_warning("recorrido.gd: --instantes espera segundos de la toma, no «%s»" % s)
			continue
		var t := clampf(float(s), 0.0, dur())
		poner(t)
		for i in 12:
			await RenderingServer.frame_post_draw
		poner(t)
		revisar()
		var f := "%s-t%.2f.png" % [out.get_basename(), t]
		get_viewport().get_texture().get_image().save_png(f)
		print("recorrido.gd -> %s (la cámara a %.1f m sobre lo que tiene debajo%s)" % [f, min_alto, ", el punto tapado" if tapado else ""])
		min_alto = INF
		tapado = 0
	get_tree().quit()


# la cámara y la hora en el segundo t
func poner(t: float) -> void:
	var l := lugar(t, suelo_t(t))
	cam.global_transform = Transform3D(l[1], l[0])
	mirado = l[2]
	var d := l[0].distance_to(l[2]) as float
	cam.far = maxf(6000.0, d + 30000.0)
	if ambiente and ambiente.env and niebla > 0.0:
		var alto: float = l[0].y - suelo_t(t)
		ambiente.env.fog_density = niebla * NIEBLA_ALTO / maxf(alto, NIEBLA_ALTO)
	if ambiente:
		var h: Array = toma.get("hora", [17.0, 17.0])
		var hh := lerpf(float(h[0]), float(h[-1]), smoothstep(0.0, 1.0, t / dur()))
		ambiente.objetivo = hh
		ambiente.poner_hora(hh)


# [la posición de la cámara, su Basis] en t, con el suelo s bajo el punto
func lugar(t: float, s: float) -> Array:
	var v := valor(t)
	var punto := Vector3(v[0], s + v[2], -v[1])
	var b := Basis.from_euler(Vector3(v[4], v[3], 0.0))  # como ver.gd colocar(): la cámara mira hacia -Z
	return [punto + b.z * exp(v[5]), b, punto]


# lo que dicen las claves en t: x, y, alto, giro, inclinación, ln distancia
func valor(t: float) -> PackedFloat64Array:
	var n := claves.size()
	var i := 0
	while i < n - 2 and t > claves[i + 1][0]:
		i += 1
	var t0: float = claves[i][0]
	var t1: float = claves[i + 1][0]
	var u := clampf((t - t0) / maxf(t1 - t0, 1e-6), 0.0, 1.0)
	var a: PackedFloat64Array = claves[i][1]
	var b: PackedFloat64Array = claves[i + 1][1]
	var ma := tangente(i)
	var mb := tangente(i + 1)
	var dt := t1 - t0
	var u2 := u * u
	var u3 := u2 * u
	var out := PackedFloat64Array()
	for k in a.size():
		out.append(a[k] * (2 * u3 - 3 * u2 + 1) + ma[k] * dt * (u3 - 2 * u2 + u) + b[k] * (-2 * u3 + 3 * u2) + mb[k] * dt * (u3 - u2))
	return out


# la pendiente de cada número en la clave i (Catmull-Rom por el tiempo); en la primera y la última, 0 (parte y llega
# detenida) salvo con "suave": false, que sigue la del tramo
func tangente(i: int) -> PackedFloat64Array:
	var n := claves.size()
	var out := PackedFloat64Array()
	var a := maxi(i - 1, 0)
	var b := mini(i + 1, n - 1)
	var extremo := i == 0 or i == n - 1
	for k in claves[i][1].size():
		if extremo and toma.get("suave", true):
			out.append(0.0)
		else:
			out.append((claves[b][1][k] - claves[a][1][k]) / maxf(claves[b][0] - claves[a][0], 1e-6))
	return out


# lo que se revisa en cada cuadro: la altura de la cámara sobre lo que tiene debajo y si algo tapa el punto
func revisar() -> void:
	var e := get_world_3d().direct_space_state
	var c := cam.global_position
	var r := e.intersect_ray(PhysicsRayQueryParameters3D.create(c, c + Vector3.DOWN * 3000.0))
	if r:
		min_alto = minf(min_alto, c.y - r["position"].y)
	var punto := mirado + (c - mirado).normalized() * 0.3  # sin tocar el suelo bajo el punto
	if mirado.distance_to(c) > 0.5:
		var ida := e.intersect_ray(PhysicsRayQueryParameters3D.create(c, punto))
		var vuelta := e.intersect_ray(PhysicsRayQueryParameters3D.create(punto, c))
		if ida or vuelta:
			tapado += 1
