# Captura la bandera: un modo de la red local (red.gd) para dos o más jugadores, cada uno con su bandera.
#
# El anfitrión lo prepara en el panel de la red (J): cada uno pone su bandera con B donde quiera defenderla (puede
# moverla mientras se prepara; el que no la puso, la tiene donde esté al empezar), y el anfitrión empieza. Mientras se
# prepara no hay jetpack (jugador.gd sin_jetpack, vehiculo.gd): con él una bandera quedaría en un techo, y con una
# bandera no se vuela (abajo), así que nadie la sacaría de ahí; tampoco jugando para el que no ha puesto la suya. Al
# empezar, cada uno parte en su bandera (a_mi_bandera(): su juego lo lleva, como al reaparecer). Jugando, se
# toma una bandera ajena pasando junto a ella (a pie o en bicicleta: TOMAR m) y se anota llevándola a la propia
# (ANOTAR m de su base), siempre que la propia esté en su lugar: +1 al que anota, y la bandera vuelve a su base. Gana
# el primero que llega a `meta` puntos (el anfitrión la elige; 0: sin límite). Con una bandera, solo a pie o en
# bicicleta (vehiculo.gd: en auto se ocultaría, en jetpack volaría sobre todo); si el que la lleva muere, queda en el
# suelo donde cayó: su dueño la devuelve tocándola, otro la puede tomar, y si nadie la toca vuelve sola a los VUELTA s.
# El que muere reaparece en su bandera a los `reaparecer` s (jugador.gd reaparece_en, espera_muerto; vida.gd lleva la
# cuenta), y mientras se juega no se viaja (jugador.gd sin_viajes: Tab, el mapa grande, el menú y la red quitan sus
# viajes).
#
# Quién decide: el anfitrión. Lo demás de red.gd no tiene autoridad (cada uno simula lo suyo), pero una bandera no
# puede estar en dos manos: cada uno le pide al anfitrión tomar, anotar, soltar o devolver (tramite(), confiable; el
# anfitrión se atiende a sí mismo en atender()), y él resuelve en orden de llegada y manda a todos el juego entero con
# lo que pasó (vigente(): fase, meta, banderas, puntos y un evento, que cada uno cuenta a su modo: «tomaste», «tomó tu
# bandera»). Si el que lleva una bandera muere, su juego la suelta (soltar); si eso no llega, el anfitrión la suelta al
# ver su vida en 0 (red.gd porte()). Este nodo («bandera») tiene sus propias rpc: no corre la numeración de las de
# red.gd, y a una copia sin este modo no se le manda nada (con_modo: los que mandaron saludo()).
#
# En el mundo: cada bandera es un asta con su paño de color (el de la polera de su dueño en red.gd: POLERAS), una
# columna de luz (faro.gdshader, como el marcador de ruta.gd) donde está y un anillo en su base; llevada, va más chica
# en la espalda del que la lleva, con la columna encima. En los mapas (plano.gd): en_mapa(). Arriba a la derecha, el
# marcador y el estado de la propia. Al tomar una, el camino a la propia queda marcado (ruta.gd).
#
#   --ctf n: el anfitrión prepara al comenzar y empieza cuando haya n banderas puestas
#   --bandera: pone la propia donde está el personaje en cuanto se prepare (sin apretar B)
#   --ctf-prueba: toma la bandera ajena más cercana, la lleva a la propia (anota), toma otra vez, muere con ella y
#   espera la reaparición; imprime cada paso (con --png, la captura sale después)
#   --ctf-robar s: toma la bandera ajena más cercana y se queda con ella s segundos (la regla de la propia en su lugar)
#   --ctf-preparar: el anfitrión (--servidor, sin --ctf) sube con el jetpack, prepara (baja solo y se lo saca), pone la
#   suya, prueba ponerse el jetpack, se aleja, empieza (vuelve a su bandera) y prueba viajar; imprime cada paso
extends Node3D

const Args := preload("res://args.gd")
const Red := preload("res://red.gd")
const Jugador := preload("res://jugador.gd")

const TOMAR := 2.5  # m del asta para tomarla (o devolver la propia)
const ANOTAR := 3.5  # m de la base propia para anotar
const VUELTA := 30.0  # s que una bandera en el suelo espera antes de volver sola
const META := 3  # puntos para ganar, si el anfitrión no elige otra cosa
const REAPARECER := 5.0  # s muerto antes de reaparecer en la bandera
const ASTA := 3.4  # m
const LLEVADA := 0.45  # la escala de la bandera en la espalda
const PEDIR_CADA := 0.5  # s entre dos pedidos iguales (cada cuadro junto a una bandera pediría tomarla)
const FARO_DESDE := 35.0  # m de la cámara: más cerca, la columna de luz no se dibuja (la propia, a los pies, tapaba la vista)
const NO_VIAJA := "En captura la bandera no se viaja: a pie, en bicicleta o en auto"
const SIN_JETPACK := "Mientras se prepara, sin jetpack"
const SIN_JETPACK_NI_BANDERA := "Sin jetpack hasta que pongas tu bandera (B)"

var red: Node3D  # red.gd
var jugador: CharacterBody3D  # jugador.gd
var plano: CanvasLayer  # plano.gd (los avisos), si está
var ruta: Node3D  # ruta.gd: el camino a la propia mientras se lleva una

# el juego, como lo dice el anfitrión (vigente())
var fase := ""  # "": sin juego; "preparar": cada uno pone la suya (B); "jugar"; "fin": alguien llegó a la meta
var meta := META
var reaparecer := REAPARECER
var ganador := 0
var banderas := {}  # id del dueño -> {"base": Vector3, "pos": Vector3 (donde está si no la llevan), "lleva": id (0: nadie), "t": s en el suelo}
var puntos := {}  # id -> puntos

var con_modo := {}  # ids que tienen este modo (mandaron saludo())
var nombres := {}  # id -> su nombre, también después de que se fue
var t_pedido := {}  # pedido -> s desde que se mandó
var muerto_desde := {}  # el anfitrión: id de un portador con la vida en 0 -> s (por si su soltar() no llegó)
var visuales := {}  # dueño -> {"asta", "anillo", "faro", "nombre"}
var marqué := false  # la ruta a la propia es de aquí (al soltar o anotar se quita)

var capa := CanvasLayer.new()
var marcador := RichTextLabel.new()
# en el panel de la red (red.gd caja_panel)
var btn := Button.new()
var btn_terminar := Button.new()
var meta_sb := SpinBox.new()
var reaparecer_sb := SpinBox.new()
var panel_lbl := Label.new()

var prueba_lista := false  # --ctf-prueba: terminó (main.gd png() la espera)
var plantar_al_preparar := false  # --bandera


func _ready() -> void:
	name = "bandera"  # las rpc buscan este nodo por su ruta: tiene que llamarse igual en todos
	multiplayer.peer_connected.connect(_llego)
	multiplayer.peer_disconnected.connect(_se_fue)
	red.salio.connect(limpiar)  # crear() y unirse() salen y vuelven a conectar en la misma llamada: sondear no lo ve
	jugador.murio.connect(_murio)
	armar_hud()
	armar_panel()
	plantar_al_preparar = Args.has("--bandera")
	if Args.has("--ctf"):
		await get_tree().process_frame  # red.gd crea la partida en su _ready (--servidor)
		if red.anfitrion():
			preparar()
	if Args.has("--ctf-prueba"):
		prueba()
	elif Args.has("--ctf-robar"):
		prueba_robar()
	elif Args.has("--ctf-preparar"):
		prueba_preparar()


# ---------- quién es quién ----------

func yo() -> int:
	return multiplayer.get_unique_id()


func nombre_de(id: int) -> String:
	if id == yo():
		return red.nombre
	var o = red.otros.get(id)
	if o and o.nombre != "":
		nombres[id] = o.nombre  # red.gd lo borra al salir, antes de que aquí se cuente
	return nombres.get(id, "otro jugador")


static func color_de(id: int) -> Color:
	return Color(Red.POLERAS[posmod(id, Red.POLERAS.size())])


# dónde está un jugador (los pies), o INF si no se sabe
func pos_de(id: int) -> Vector3:
	if id == yo():
		return jugador.global_position
	var o = red.otros.get(id)
	return o.cuerpo.global_position if o and o.recibido else Vector3.INF


# en el suelo (a pie), o en auto o bicicleta: donde una bandera puede quedar puesta (con el jetpack, en_aire)
func en_suelo(id: int) -> bool:
	if id == yo():
		var e: Array = red.estado_propio()
		return e[3] or (e[4] and e[5] != "" and e[5] != "jetpack")
	var o = red.otros.get(id)
	return o != null and o.recibido and (o.en_suelo or (o.montado and o.vt != "" and o.vt != "jetpack"))


func vivo(id: int) -> bool:
	if id == yo():
		return jugador.vida > 0.0
	var o = red.otros.get(id)
	return o != null and o.vida_red > 0.0


# la bandera (su dueño) que lleva el jugador id, o 0
func lleva_de(id: int) -> int:
	for d in banderas:
		if banderas[d]["lleva"] == id:
			return d
	return 0


static func en_su_lugar(f: Dictionary) -> bool:
	return f["lleva"] == 0 and f["pos"] == f["base"]


# los que juegan: este y los otros con este modo
func jugadores() -> Array:
	var out := [yo()]
	for id in red.otros:
		if con_modo.has(id):
			out.append(id)
	return out


# ---------- lo que viaja ----------

func _llego(id: int) -> void:
	saludo.rpc_id(id)


func _se_fue(id: int) -> void:
	con_modo.erase(id)
	if not red.anfitrion() or fase == "":
		return
	# su bandera se va con él; la que llevaba vuelve a su lugar
	var d := lleva_de(id)
	if d != 0:
		volver(d)
	banderas.erase(id)
	puntos.erase(id)
	enviar(["salio", id, 0])


# que este tiene el modo; el anfitrión le cuenta el juego si hay uno
@rpc("any_peer", "call_remote", "reliable")
func saludo() -> void:
	var id := multiplayer.get_remote_sender_id()
	con_modo[id] = true
	if red.anfitrion() and fase != "":
		vigente.rpc_id(id, paquete([]))


# un pedido al anfitrión: plantar [base], tomar [dueño, donde la vio], anotar, soltar [donde], devolver [donde la vio]
@rpc("any_peer", "call_remote", "reliable")
func tramite(que: String, a: Array) -> void:
	if red.anfitrion():
		atender(multiplayer.get_remote_sender_id(), que, a)


# el juego entero, del anfitrión, con lo que acaba de pasar (evento: [qué, quién, de quién])
@rpc("authority", "call_remote", "reliable")
func vigente(e: Dictionary) -> void:
	aplicar(e)


func pedir(que: String, a := []) -> void:
	if red.anfitrion():
		atender(yo(), que, a)
	elif red.en_partida():
		tramite.rpc_id(1, que, a)


# lo mismo, no más de una vez cada PEDIR_CADA s (lo que se pide estando junto a una bandera)
func pedir_una_vez(que: String, a := []) -> void:
	if t_pedido.get(que, INF) < PEDIR_CADA:
		return
	t_pedido[que] = 0.0
	pedir(que, a)


func paquete(ev: Array) -> Dictionary:
	return {"fase": fase, "meta": meta, "reaparecer": reaparecer, "ganador": ganador, "banderas": banderas.duplicate(true),
		"puntos": puntos.duplicate(), "evento": ev}


# el anfitrión: el juego a todos los que tienen el modo, y aquí
func enviar(ev: Array) -> void:
	var e := paquete(ev)
	for id in con_modo:
		if red.otros.has(id):
			vigente.rpc_id(id, e)
	aplicar(e)


func aplicar(e: Dictionary) -> void:
	var antes := fase
	fase = e["fase"]
	meta = e["meta"]
	reaparecer = e["reaparecer"]
	ganador = e["ganador"]
	if not red.anfitrion():
		banderas = e["banderas"]
		puntos = e["puntos"]
	contar(e["evento"])
	if fase == "jugar" and antes != "jugar":
		t_pedido.clear()
	ajustar_jugador()
	if e["evento"].size() == 3 and e["evento"][0] == "empieza":
		a_mi_bandera()


# al empezar (también otra ronda), cada uno parte en su bandera: lo lleva su juego, como al reaparecer (jugador.gd ir(),
# que no mira sin_viajes y espera la colisión de allá; montado, con el vehículo). El que la tiene donde está, no se mueve
func a_mi_bandera() -> void:
	var mia = banderas.get(yo())
	if mia == null:
		return
	var b: Vector3 = mia["base"]
	var lejos := jugador.global_position.distance_to(b)
	if lejos < TOMAR:
		return
	jugador.ir(b.x, -b.z, b.y)
	print("bandera.gd: a tu bandera, en x %.1f, y %.1f (estaba a %.0f m)" % [b.x, -b.z, lejos])


# lo que cambia en el personaje: no viaja, espera más muerto y reaparece en su bandera; con una, solo a pie o en
# bicicleta; sin jetpack mientras se prepara (y jugando, sin la propia puesta); el camino a la propia mientras lleva una
func ajustar_jugador() -> void:
	var jugando := fase == "jugar"
	var mia = banderas.get(yo())
	jugador.sin_viajes = NO_VIAJA if jugando else ""
	jugador.sin_jetpack = SIN_JETPACK if fase == "preparar" else SIN_JETPACK_NI_BANDERA if jugando and mia == null else ""
	jugador.espera_muerto = reaparecer if jugando else Jugador.ESPERA_MUERTO
	jugador.reaparece_en = Vector3(mia["base"].x, -mia["base"].z, mia["base"].y) if jugando and mia else Vector3.INF
	jugador.con_bandera = jugando and lleva_de(yo()) != 0
	if ruta:
		if jugador.con_bandera and mia and not marqué:
			ruta.marcar(Vector2(mia["base"].x, -mia["base"].z), "tu bandera")
			marqué = true
		elif not jugador.con_bandera and marqué:
			ruta.quitar()
			marqué = false


# el evento, en palabras de cada uno
func contar(ev: Array) -> void:
	if ev.size() != 3:
		return
	var q: int = ev[1]
	var d: int = ev[2]
	var quien := nombre_de(q)
	var de := "tu bandera" if d == yo() else "la bandera de %s" % nombre_de(d)
	var t := ""
	match ev[0]:
		"prepara":
			t = "Captura la bandera: pon la tuya con B donde quieras defenderla (a pie: mientras se prepara, sin jetpack)"
		"empieza":
			t = "¡A jugar! Toma una bandera ajena y llévala a la tuya (a %d puntos)" % meta if meta > 0 else "¡A jugar! Toma una bandera ajena y llévala a la tuya"
			if not banderas.has(yo()):
				t += ". Pon la tuya con B, en el suelo"
		"termina":
			t = "Terminó la captura la bandera"
		"planto":
			t = "Pusiste tu bandera" if q == yo() else ""
		"tomo":
			t = ("Tomaste %s: llévala a la tuya" % de) if q == yo() else "%s tomó %s" % [quien, de]
		"solto":
			if q == yo():
				t = "Soltaste %s" % de
			else:
				t = "%s soltó %s%s" % [quien, de, ": tócala para devolverla" if d == yo() else ""]
		"devolvio":
			t = "Devolviste tu bandera" if q == yo() else "%s devolvió su bandera" % quien
		"volvio":
			t = ("Tu bandera" if d == yo() else "La bandera de %s" % nombre_de(d)) + " volvió a su lugar"
		"anoto":
			t = ("¡Anotaste! (%d)" % puntos.get(q, 0)) if q == yo() else "%s anotó con %s (%d)" % [quien, de, puntos.get(q, 0)]
		"gano":
			t = "¡Ganaste!" if q == yo() else "¡Ganó %s!" % quien
		"salio":
			t = "%s salió: su bandera también" % quien
	if t != "":
		avisar(t)


func avisar(t: String) -> void:
	print("bandera.gd: ", t)
	if plano and plano.has_method("avisar"):
		plano.avisar(t)


# ---------- el anfitrión ----------

func atender(id: int, que: String, a: Array) -> void:
	var ev := []
	match que:
		"plantar":
			if a.size() == 1 and a[0] is Vector3 and (fase == "preparar" or (fase == "jugar" and not banderas.has(id))):
				banderas[id] = {"base": a[0], "pos": a[0], "lleva": 0, "t": 0.0}
				puntos[id] = puntos.get(id, 0)
				ev = ["planto", id, id]
		"tomar":
			# [dueño, donde la vio]: si entretanto volvió o la movieron, el pedido llegó tarde
			if fase != "jugar" or a.size() != 2 or not a[0] is int or not a[1] is Vector3:
				return
			var d: int = a[0]
			var f = banderas.get(d)
			if f and d != id and f["lleva"] == 0 and f["pos"] == a[1] and lleva_de(id) == 0 and vivo(id):
				f["lleva"] = id
				ev = ["tomo", id, d]
		"devolver":
			var f = banderas.get(id)
			if fase == "jugar" and f and f["lleva"] == 0 and f["pos"] != f["base"] and a.size() == 1 and a[0] == f["pos"]:
				volver(id)
				ev = ["devolvio", id, id]
		"anotar":
			var d := lleva_de(id)
			var mia = banderas.get(id)
			if fase == "jugar" and d != 0 and mia and en_su_lugar(mia):
				puntos[id] = puntos.get(id, 0) + 1
				volver(d)
				ev = ["anoto", id, d]
				if meta > 0 and puntos[id] >= meta:
					fase = "fin"
					ganador = id
					ev = ["gano", id, d]
		"soltar":
			var d := lleva_de(id)
			if d != 0 and a.size() == 1 and a[0] is Vector3:
				soltar(d, a[0])
				ev = ["solto", id, d]
	if not ev.is_empty():
		enviar(ev)


func volver(d: int) -> void:
	var f: Dictionary = banderas[d]
	f["pos"] = f["base"]
	f["lleva"] = 0
	f["t"] = 0.0


func soltar(d: int, p: Vector3) -> void:
	var f: Dictionary = banderas[d]
	f["pos"] = p
	f["lleva"] = 0
	f["t"] = 0.0


# el anfitrión, cada cuadro: las banderas en el suelo vuelven a los VUELTA s, y la del que se fue o cayó (si su soltar()
# no llegó) queda donde estaba
func cuidar(dt: float) -> void:
	if fase != "jugar":
		return
	for d in banderas.keys():
		var f: Dictionary = banderas[d]
		var c: int = f["lleva"]
		if c == 0:
			if f["pos"] != f["base"]:
				f["t"] += dt
				if f["t"] >= VUELTA:
					volver(d)
					enviar(["volvio", 0, d])
		elif c != yo() and not red.otros.has(c):
			volver(d)
			enviar(["volvio", 0, d])
		elif not vivo(c):
			muerto_desde[c] = muerto_desde.get(c, 0.0) + dt
			if muerto_desde[c] > 1.0 and pos_de(c) != Vector3.INF:
				soltar(d, pos_de(c))
				enviar(["solto", c, d])
		else:
			muerto_desde.erase(c)


func preparar() -> void:
	fase = "preparar"
	ganador = 0
	puntos.clear()
	for d in banderas:
		volver(d)
		puntos[d] = 0
	enviar(["prepara", 0, 0])


func empezar() -> void:
	meta = int(meta_sb.value)
	reaparecer = reaparecer_sb.value
	# el que no la puso, la tiene donde está, si está en el suelo: en el aire nadie la alcanzaría ni anotaría, y
	# reaparecer ahí sería caer; si no, la pone con B jugando (atender() lo deja)
	for id in jugadores():
		if not banderas.has(id) and pos_de(id) != Vector3.INF and en_suelo(id):
			banderas[id] = {"base": pos_de(id), "pos": pos_de(id), "lleva": 0, "t": 0.0}
	puntos.clear()
	for d in banderas:
		volver(d)
		puntos[d] = 0
	fase = "jugar"
	ganador = 0
	enviar(["empieza", 0, 0])


func terminar() -> void:
	fase = ""
	banderas.clear()
	puntos.clear()
	enviar(["termina", 0, 0])


# sin partida: todo fuera
func limpiar() -> void:
	fase = ""
	banderas.clear()
	puntos.clear()
	con_modo.clear()
	t_pedido.clear()
	muerto_desde.clear()
	ajustar_jugador()


# ---------- cada cuadro ----------

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("bandera") and not e.is_echo() and not jugador.quieto:
		if fase == "preparar" or (fase == "jugar" and not banderas.has(yo())):
			plantar()
		elif fase == "jugar":
			avisar("Tu bandera ya está puesta: se mueve solo mientras se prepara")
		get_viewport().set_input_as_handled()


# la propia, donde está el personaje: a pie, vivo y en el suelo
func plantar() -> void:
	if jugador.vehiculo != null or jugador.vida <= 0.0 or not jugador.is_on_floor():
		avisar("Para poner tu bandera: a pie y en el suelo")
		return
	pedir("plantar", [jugador.global_position])


func _murio() -> void:
	if fase == "jugar" and lleva_de(yo()) != 0:
		pedir("soltar", [jugador.global_position])


func _physics_process(dt: float) -> void:
	if fase != "" and not red.en_partida():
		limpiar()
		return
	for k in t_pedido:
		t_pedido[k] += dt
	if red.anfitrion():
		cuidar(dt)
		if Args.has("--ctf") and fase == "preparar" and banderas.size() >= roundi(Args.num("--ctf", 2.0, 1.0, 16.0)):
			empezar()
	# --bandera: la propia donde está, en cuanto se pueda (en el suelo: al comenzar todavía cae)
	if plantar_al_preparar and fase == "preparar" and not banderas.has(yo()) and jugador.is_on_floor() \
			and jugador.vehiculo == null and jugador.vida > 0.0:
		pedir_una_vez("plantar", [jugador.global_position])
	if fase != "jugar" or jugador.vida <= 0.0:
		return
	var p := jugador.global_position
	var a_pie: bool = jugador.vehiculo == null or jugador.vehiculo.tipo == "bici"
	var llevo := lleva_de(yo())
	for d in banderas:
		var f: Dictionary = banderas[d]
		if f["lleva"] != 0 or p.distance_to(f["pos"]) > TOMAR:
			continue
		if d == yo():
			if f["pos"] != f["base"]:
				pedir_una_vez("devolver", [f["pos"]])
		elif llevo == 0 and a_pie:
			pedir_una_vez("tomar", [d, f["pos"]])
	var mia = banderas.get(yo())
	if llevo != 0 and mia and p.distance_to(mia["base"]) < ANOTAR:
		if en_su_lugar(mia):
			pedir_una_vez("anotar")
		elif t_pedido.get("aviso", INF) > 4.0:
			t_pedido["aviso"] = 0.0
			avisar("Para anotar, tu bandera tiene que estar en su lugar")


func _process(dt: float) -> void:
	if not red.anfitrion():  # la cuenta de las que están en el suelo (la de verdad es la del anfitrión)
		for d in banderas:
			if banderas[d]["lleva"] == 0 and banderas[d]["pos"] != banderas[d]["base"]:
				banderas[d]["t"] += dt
	poner_visuales()
	escribir_marcador()
	if btn.is_visible_in_tree():
		refrescar_panel()


# ---------- en el mundo ----------

func poner_visuales() -> void:
	for d in visuales.keys():
		if not banderas.has(d) or fase == "":
			for k in visuales[d]:
				visuales[d][k].queue_free()
			visuales.erase(d)
	if fase == "":
		return
	var cam := get_viewport().get_camera_3d()
	for d in banderas:
		if not visuales.has(d):
			visuales[d] = armar(d)
		var v: Dictionary = visuales[d]
		var f: Dictionary = banderas[d]
		var asta: Node3D = v["asta"]
		var donde: Vector3 = f["pos"]
		var c: int = f["lleva"]
		if c == 0:
			asta.global_transform = Transform3D(Basis(), donde)
			asta.visible = true
		else:
			var torso := torso_de(c)
			asta.visible = torso != null and not (c == yo() and not jugador.cuerpo.visible)
			if torso:
				# en la espalda (+Z del peatón), inclinada hacia atrás
				asta.global_transform = torso.global_transform * Transform3D(Basis(Vector3.RIGHT, 0.28).scaled(Vector3.ONE * LLEVADA), Vector3(0.05, -0.1, 0.17))
			donde = pos_de(c) if pos_de(c) != Vector3.INF else donde
		var faro: MeshInstance3D = v["faro"]
		faro.global_position = donde + Vector3.UP * 248.0
		faro.visible = cam == null or Vector2(cam.global_position.x - donde.x, cam.global_position.z - donde.z).length() > FARO_DESDE
		var anillo: MeshInstance3D = v["anillo"]
		anillo.global_position = f["base"] + Vector3.UP * 0.25
		var nombre: Label3D = v["nombre"]
		nombre.visible = c == 0
		nombre.global_position = donde + Vector3.UP * (ASTA + 0.7)


func torso_de(id: int) -> Node3D:
	if id == yo():
		return jugador.peaton.torso
	var o = red.otros.get(id)
	return o.peaton.torso if o and o.recibido else null


# la bandera de d: el asta con su paño, una columna de luz y un anillo en la base (los de ruta.gd) y su nombre
func armar(d: int) -> Dictionary:
	var col := color_de(d)
	var asta := Node3D.new()
	var palo := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.035
	c.bottom_radius = 0.045
	c.height = ASTA
	c.radial_segments = 8
	palo.mesh = c
	palo.position.y = ASTA / 2.0
	palo.material_override = material(Color(0.82, 0.83, 0.85), 0.6)
	asta.add_child(palo)
	var bola := MeshInstance3D.new()
	var e := SphereMesh.new()
	e.radius = 0.08
	e.height = 0.16
	bola.mesh = e
	bola.position.y = ASTA + 0.05
	bola.material_override = material(Color(0.86, 0.7, 0.28), 0.8)
	asta.add_child(bola)
	var pano := MeshInstance3D.new()
	var q := PlaneMesh.new()
	q.orientation = PlaneMesh.FACE_Z
	q.size = Vector2(1.25, 0.8)
	q.subdivide_width = 10
	q.subdivide_depth = 2
	pano.mesh = q
	pano.position = Vector3(0.04 + 0.625, ASTA - 0.06 - 0.4, 0.0)
	var sm := ShaderMaterial.new()
	sm.shader = preload("res://shaders/bandera.gdshader")
	sm.set_shader_parameter("color", col)
	sm.set_shader_parameter("fase", float(posmod(d, 97)))
	pano.material_override = sm
	asta.add_child(pano)
	add_child(asta)
	var faro := MeshInstance3D.new()
	var cf := CylinderMesh.new()
	cf.top_radius = 1.0
	cf.bottom_radius = 1.0
	cf.height = 500.0
	cf.radial_segments = 12
	cf.rings = 1
	cf.cap_top = false
	cf.cap_bottom = false
	faro.mesh = cf
	var mf := ShaderMaterial.new()
	mf.shader = preload("res://shaders/faro.gdshader")
	mf.set_shader_parameter("color", col)
	mf.set_shader_parameter("pixeles", 4.0)
	faro.material_override = mf
	faro.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	faro.extra_cull_margin = 16384.0
	add_child(faro)
	var anillo := MeshInstance3D.new()
	var pl := PlaneMesh.new()
	pl.size = Vector2(7, 7)
	anillo.mesh = pl
	var ma := ShaderMaterial.new()
	ma.shader = preload("res://shaders/faro.gdshader")
	ma.set_shader_parameter("color", col)
	ma.set_shader_parameter("aro", true)
	anillo.material_override = ma
	anillo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(anillo)
	var nombre := Label3D.new()
	nombre.text = "Tu bandera" if d == yo() else "Bandera de %s" % nombre_de(d)
	nombre.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	nombre.fixed_size = true
	nombre.pixel_size = 0.0011
	nombre.font_size = 26
	nombre.outline_size = 8
	nombre.modulate = col.lightened(0.45)
	nombre.visibility_range_end = 3000.0
	add_child(nombre)
	return {"asta": asta, "faro": faro, "anillo": anillo, "nombre": nombre}


static func material(col: Color, metal: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.metallic = metal
	m.roughness = 0.4
	return m


# para plano.gd: [donde está (grilla), su color, su base (grilla), su dueño, si la llevan] de cada bandera
func en_mapa() -> Array:
	var out := []
	if fase == "":
		return out
	for d in banderas:
		var f: Dictionary = banderas[d]
		var p: Vector3 = f["pos"] if f["lleva"] == 0 or pos_de(f["lleva"]) == Vector3.INF else pos_de(f["lleva"])
		out.append([Vector2(p.x, -p.z), color_de(d), Vector2(f["base"].x, -f["base"].z), nombre_de(d), f["lleva"] != 0])
	return out


# ---------- en pantalla ----------

func armar_hud() -> void:
	add_child(capa)
	capa.layer = 2
	marcador.bbcode_enabled = true
	marcador.fit_content = true
	marcador.scroll_active = false
	marcador.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marcador.anchor_left = 1.0
	marcador.anchor_right = 1.0
	marcador.offset_left = -560
	marcador.offset_right = -16
	marcador.offset_top = 68  # bajo la hora (ambiente.gd) y la red (red.gd)
	marcador.add_theme_constant_override("outline_size", 5)
	marcador.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	marcador.add_theme_color_override("default_color", Color(1, 1, 1))
	marcador.add_theme_font_size_override("normal_font_size", 17)
	marcador.add_theme_font_size_override("bold_font_size", 17)
	capa.add_child(marcador)


# arriba a la derecha: los puntos de cada uno y el estado de la propia (o lo que falta para empezar)
func escribir_marcador() -> void:
	if fase == "":
		if marcador.text != "":
			marcador.text = ""
		return
	var l := []
	var orden := jugadores()
	orden.sort_custom(func(a, b): return puntos.get(a, 0) > puntos.get(b, 0))
	var cuenta := []
	for id in orden:
		var n := "Tú" if id == yo() else nombre_de(id)
		cuenta.append("[color=#%s]■[/color] %s %d" % [color_de(id).to_html(false), n, puntos.get(id, 0)])
	var titulo := "Captura la bandera" + (" · a %d" % meta if meta > 0 and fase != "preparar" else "")
	l.append("[b]%s[/b] · %s" % [titulo, " · ".join(cuenta)])
	var mia = banderas.get(yo())
	match fase:
		"preparar":
			var faltan := []
			for id in jugadores():
				if not banderas.has(id):
					faltan.append("tú" if id == yo() else nombre_de(id))
			l.append("B: pon tu bandera donde quieras defenderla" + (" (puesta; puedes moverla)" if mia else "") + " · sin jetpack")
			l.append(("Faltan: %s · " % ", ".join(faltan) if not faltan.is_empty() else "") + ("J: empezar" if red.anfitrion() else "El anfitrión empieza"))
		"jugar":
			if mia == null:
				l.append("B: pon tu bandera para poder anotar")
			elif mia["lleva"] != 0:
				l.append("Tu bandera: [color=#ff8a70]la lleva %s[/color]" % nombre_de(mia["lleva"]))
			elif mia["pos"] != mia["base"]:
				l.append("Tu bandera: [color=#ffd36b]en el suelo[/color], vuelve sola en %d s (tócala para devolverla)" % maxi(ceili(VUELTA - mia["t"]), 0))
			else:
				l.append("Tu bandera: en su lugar")
			var d := lleva_de(yo())
			if d != 0 and mia:
				var m: float = jugador.global_position.distance_to(mia["base"])
				l.append("Llevas la bandera de %s: a tu bandera, %s" % [nombre_de(d), Red.distancia(m)])
		"fin":
			l.append("¡%s!" % ("Ganaste" if ganador == yo() else "Ganó " + nombre_de(ganador)) + (" · J: otra ronda" if red.anfitrion() else ""))
	var t := "[right]%s[/right]" % "\n".join(l)
	if marcador.text != t:
		marcador.text = t


# en el panel de la red (J): el anfitrión prepara, empieza, termina y elige la meta y la espera para reaparecer
func armar_panel() -> void:
	var caja: VBoxContainer = red.caja_panel
	caja.add_child(HSeparator.new())
	var titulo := Label.new()
	titulo.text = "Captura la bandera (B: poner la tuya)"
	caja.add_child(titulo)
	var fila := HBoxContainer.new()
	btn.pressed.connect(_boton)
	btn_terminar.text = "Terminar"
	btn_terminar.pressed.connect(terminar)
	var la := Label.new()
	la.text = "a"
	meta_sb.min_value = 0
	meta_sb.max_value = 20
	meta_sb.value = META
	meta_sb.suffix = "puntos"
	meta_sb.tooltip_text = "0: sin límite"
	var lr := Label.new()
	lr.text = "reaparecer en"
	reaparecer_sb.min_value = 1
	reaparecer_sb.max_value = 30
	reaparecer_sb.value = REAPARECER
	reaparecer_sb.suffix = "s"
	for n in [btn, btn_terminar, la, meta_sb, lr, reaparecer_sb]:
		fila.add_child(n)
	caja.add_child(fila)
	panel_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	caja.add_child(panel_lbl)


func _boton() -> void:
	match fase:
		"":
			preparar()
		"preparar", "fin":
			empezar()
		"jugar":
			terminar()


func refrescar_panel() -> void:
	var anf: bool = red.anfitrion()
	match fase:
		"":
			btn.text = "Preparar"
		"preparar":
			btn.text = "Empezar"
		"jugar":
			btn.text = "Terminar"
		"fin":
			btn.text = "Otra ronda"
	btn.disabled = not anf
	btn_terminar.visible = anf and (fase == "preparar" or fase == "fin")
	meta_sb.editable = anf and fase != "jugar"
	reaparecer_sb.editable = anf and fase != "jugar"
	if not red.en_partida():
		panel_lbl.text = "Para jugar, cree una partida o únase a una"
	elif anf:
		panel_lbl.text = {"": "Preparar: cada uno pone su bandera con B (sin jetpack); después, Empezar", "preparar": "Cuando estén puestas: Empezar (cada uno parte en la suya; el que no la puso, la tiene donde esté)", "jugar": "Jugando: nadie viaja; quien muere reaparece en su bandera", "fin": "Otra ronda: las mismas banderas, desde cero"}[fase]
	else:
		panel_lbl.text = "El anfitrión prepara y empieza" if fase == "" else "Jugando a %d puntos" % meta if fase == "jugar" else ""


# ---------- --ctf-prueba ----------

func prueba() -> void:
	var arbol := get_tree()
	await arbol.process_frame
	if jugador.mapa:
		await jugador.mapa.esperar()
	var hasta := Time.get_ticks_msec() + 90000
	while fase != "jugar" and Time.get_ticks_msec() < hasta:
		await arbol.create_timer(0.25).timeout
	if fase != "jugar":
		print("bandera.gd: --ctf-prueba: no empezó en 90 s")
		terminar_prueba()
		return
	var mia = banderas.get(yo())
	print("bandera.gd: empezó; mi bandera en x %.1f, y %.1f; %d banderas" % [mia["base"].x, -mia["base"].z, banderas.size()])
	# 1. tomar la ajena más cercana y llevarla a la propia
	var d := ajena_cercana()
	await ir_a(banderas[d]["pos"])
	var tomo: bool = await esperar(func(): return lleva_de(yo()) == d, 10.0)
	if not tomo:
		print("bandera.gd: no la tomó")
	print("bandera.gd: lleva la de %s: %s" % [nombre_de(d), lleva_de(yo()) == d])
	await ir_a(mia["base"])
	await esperar(func(): return puntos.get(yo(), 0) > 0, 10.0)
	print("bandera.gd: puntos %s" % str(puntos))
	# 2. tomarla otra vez y morir con ella: queda en el suelo y reaparece en la propia
	await ir_a(banderas[d]["pos"])
	await esperar(func(): return lleva_de(yo()) == d, 10.0)
	await arbol.create_timer(0.5).timeout
	jugador.danar(1000.0, "la prueba")
	await esperar(func(): return lleva_de(yo()) == 0, 5.0)
	var f: Dictionary = banderas[d]
	print("bandera.gd: murió con ella; la de %s quedó en x %.1f, y %.1f (en su lugar: %s)" % [nombre_de(d), f["pos"].x, -f["pos"].z, en_su_lugar(f)])
	await esperar(func(): return jugador.vida > 0.0 and jugador.llegar == Vector3.INF, reaparecer + 15.0)
	await arbol.create_timer(0.5).timeout
	print("bandera.gd: reapareció a %.1f m de su bandera (vida %.0f)" % [jugador.global_position.distance_to(mia["base"]), jugador.vida])
	terminar_prueba()


# --ctf-robar s: la ajena más cercana, y quieto con ella s segundos
func prueba_robar() -> void:
	var arbol := get_tree()
	await arbol.process_frame
	await esperar(func(): return fase == "jugar", 90.0)
	if fase != "jugar":
		terminar_prueba()
		return
	var d := ajena_cercana()
	await ir_a(banderas[d]["pos"])
	var tomo: bool = await esperar(func(): return lleva_de(yo()) == d, 10.0)
	print("bandera.gd: tomó la de %s: %s; se queda con ella" % [nombre_de(d), tomo])
	var mia = banderas.get(yo())
	if mia:  # un poco hacia la propia (sin llegar), mirando hacia allá: la bandera en la espalda y el camino marcado
		var b: Vector3 = mia["base"]
		var p := jugador.global_position.lerp(b, 0.4)
		await ir_a(p)
		jugador.yaw = atan2(-(b.x - p.x), -(b.z - p.z))
		jugador.cuerpo.rotation.y = jugador.yaw
	await arbol.create_timer(Args.num("--ctf-robar", 20.0, 1.0, 600.0)).timeout
	print("bandera.gd: puntos %s" % str(puntos))
	terminar_prueba()


# --ctf-preparar (el anfitrión, solo en su partida): el jetpack mientras se prepara, la partida desde la propia y los
# viajes quitados al jugar
func prueba_preparar() -> void:
	var arbol := get_tree()
	var main := get_parent()
	var v: CharacterBody3D = main.vehiculo
	await arbol.process_frame
	if jugador.mapa:
		await jugador.mapa.esperar()
	if not red.anfitrion():
		print("bandera.gd: --ctf-preparar: es para el anfitrión (--servidor)")
		terminar_prueba()
		return
	# 1. en el aire con el jetpack cuando se prepara: baja solo y se lo saca
	v.armar("jetpack")
	v.usar()
	Input.action_press("saltar")
	await esperar(func(): return v.altura > 25.0, 15.0)
	Input.action_release("saltar")
	print("bandera.gd: con el jetpack a %.0f m sobre el suelo; prepara" % v.altura)
	preparar()
	var t0 := Time.get_ticks_msec()
	var bajo: bool = await esperar(func(): return not v.montado, 45.0)
	print("bandera.gd: %s a los %.1f s (en el suelo: %s, vida %.0f)" % ["se sacó el jetpack" if bajo else "sigue con el jetpack",
		(Time.get_ticks_msec() - t0) / 1000.0, jugador.is_on_floor(), jugador.vida])
	# 2. ponérselo otra vez: E con el jetpack, y V
	v.usar()
	print("bandera.gd: E con el jetpack en el suelo: puesto %s" % v.montado)
	var vistos := []
	for i in 3:
		v.cambiar()
		vistos.append(v.tipo)
	print("bandera.gd: V tres veces: %s" % ", ".join(vistos))
	if v.montado:
		v.usar()
	# 3. la propia aquí, lejos de ella al empezar, y de vuelta
	await arbol.create_timer(0.5).timeout
	plantar()
	if not await esperar(func(): return banderas.has(yo()), 5.0):
		print("bandera.gd: no pudo poner su bandera")
		terminar_prueba()
		return
	var b: Vector3 = banderas[yo()]["base"]
	jugador.ir(b.x + 80.0, -b.z, b.y)
	await esperar(func(): return jugador.llegar == Vector3.INF, 20.0)
	await arbol.create_timer(0.5).timeout
	print("bandera.gd: a %.0f m de su bandera; empieza" % jugador.global_position.distance_to(b))
	empezar()
	await arbol.physics_frame
	await esperar(func(): return jugador.llegar == Vector3.INF, 20.0)
	await arbol.create_timer(0.5).timeout
	print("bandera.gd: empezó a %.1f m de su bandera" % jugador.global_position.distance_to(b))
	# 4. jugando, los viajes no se ofrecen: el menú, Tab, el mapa grande y la red
	main.menu.abrir(true)
	print("bandera.gd: en el menú, «Ir a un lugar» %s y «Volver a la Plaza de Armas» %s" % [
		"se ve" if main.menu.b_viaje.visible else "no está", "se ve" if main.menu.b_plaza.visible else "no está"])
	main.menu.abrir(false)
	main.viaje.abrir(true)
	print("bandera.gd: Tab: la lista de lugares %s" % ("abierta" if main.viaje.panel.visible else "no se abre"))
	main.viaje.abrir(false)
	if plano:
		print("bandera.gd: la ayuda del mapa grande: «%s»" % plano.ayuda.text)
	red.refrescar()
	print("bandera.gd: la lista de jugadores de la red: «%s»" % red.jugadores_lbl.text)
	print("bandera.gd: jugador.viajar() a la plaza: %s" % jugador.viajar(0.0, -45.0, 0.0))
	terminar_prueba()


func terminar_prueba() -> void:
	prueba_lista = true
	if not Args.has("--png"):
		get_tree().quit()


func ajena_cercana() -> int:
	var mejor := 0
	for d in banderas:
		if d != yo() and (mejor == 0 or jugador.global_position.distance_to(banderas[d]["pos"]) < jugador.global_position.distance_to(banderas[mejor]["pos"])):
			mejor = d
	return mejor


# a un punto del mundo como un viaje de prueba (jugador.gd ir(), que no mira sin_viajes) y espera a llegar
func ir_a(p: Vector3) -> void:
	jugador.ir(p.x, -p.z, p.y)
	await esperar(func(): return jugador.llegar == Vector3.INF, 15.0)
	await get_tree().create_timer(0.3).timeout


func esperar(cond: Callable, s: float) -> bool:
	var hasta := Time.get_ticks_msec() + int(s * 1000.0)
	while not cond.call():
		if Time.get_ticks_msec() > hasta:
			return false
		await get_tree().physics_frame
	return true
