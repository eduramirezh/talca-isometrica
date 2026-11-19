# La vida del personaje en pantalla (la lógica está en jugador.gd: danar(), curar(), las caídas, la muerte y la
# reaparición) y los carritos de completos, donde se recupera rápido.
#
# La barra va abajo al centro, entre la rapidez del vehículo (abajo a la izquierda, vehiculo.gd) y el mapa chico (abajo
# a la derecha, plano.gd), con el valor en número encima: verde, amarilla bajo MEDIA y roja bajo POCA, donde además
# late. Al recibir daño destella, la pantalla se enrojece en los bordes (más con más daño) y lo perdido queda un momento
# en claro antes de vaciarse; recién reaparecido, el borde brilla mientras dura la invulnerabilidad. Se ve a pie y
# montado (el mapa grande, en la capa 5 de plano.gd, la tapa).
#
# Al morir: «Moriste» y la causa al medio; la pantalla se funde a negro antes de reaparecer y se aclara cuando el
# personaje ya está en la plaza (jugador.gd ir() espera la colisión), con el aviso de dónde reapareció sobre la barra.
#
# Los carritos de completos (el hito carritos-5-oriente de la página: dos hileras de quioscos, en 5 Oriente entre 2 y
# 3 Sur y en 6 Oriente frente al Mercado): un rectángulo por hilera (CARRITOS) en el marco local del hito, el de
# localFrame(X, Y, A) en src/js/hitos/carritos-5-oriente.js, G(u, v) = (X + u·sen A + v·cos A, Y − u·cos A + v·sen A),
# u hacia la calle y v a lo largo de la hilera, sobre donde se para la gente (en 5 Oriente también los pisos de los
# quioscos, entre el mesón y la vereda). A pie, detenido ahí (bajo 2 m/s) PARAR s y con la vida incompleta, come un
# completo: COMPLETO de vida por segundo (de 0 a 100 en ~3 s), con el aviso «Comiendo un completo… +N». De paso, sin
# detenerse, no; con la vida llena, nada.
#
#   var v := preload("res://vida.gd").new()
#   v.jugador = jugador; add_child(v)
#   await v.prueba()    # --dano n, --caer m [--pausa s] (main.gd)
extends CanvasLayer

const Args := preload("res://args.gd")
const ANCHO := 300.0  # px de la barra
const ALTO := 14.0
const ABAJO := 24.0  # px del borde de abajo de la ventana
const MEDIA := 0.5  # de la vida: desde aquí, amarilla
const POCA := 0.25  # roja y late
const C_FONDO := Color(0.07, 0.08, 0.10, 0.75)  # como el del mapa chico (plano.gd)
const C_BORDE := Color(1, 1, 1, 0.85)
const C_LLENA := Color(0.36, 0.78, 0.36)
const C_MEDIA := Color(0.96, 0.72, 0.18)
const C_POCA := Color(0.92, 0.22, 0.18)
const C_PERDIDA := Color(1.0, 0.92, 0.80)
const C_INVULNERABLE := Color(1.0, 0.86, 0.35)
const PERDIDA_ESPERA := 0.45  # s que lo perdido queda en claro
const PERDIDA_VACIA := 80.0  # por segundo, después
# las hileras de carritos: el marco del hito (x, y de grilla, A en grados) y el rectángulo en (u, v), en m
const CARRITOS := [
	# (A) 5 Oriente entre 2 y 3 Sur: los quioscos en u 0–3,5 (el mesón en 1,3–2 y los pisos hasta 3,5), la vereda hasta
	# ~8 y la calzada de 5 Oriente después; v 0–26,5, seis quioscos
	{"nombre": "5 Oriente", "x": 562.8, "y": -258.0, "a": 91.5, "u0": 2.0, "u1": 9.0, "v0": -1.5, "v1": 28.0},
	# (B) 6 Oriente, frente al Mercado: la caseta al poniente de u 0, los mesones afuera en u 0,6–1,3, el pavimento
	# hasta 3,4 y el estacionamiento; v -0,5–35,5, seis puestos
	{"nombre": "6 Oriente", "x": 676.36, "y": 128.44, "a": 91.4, "u0": 0.5, "u1": 8.0, "v0": -1.5, "v1": 37.0},
]
const COMPLETO := 35.0  # de vida por segundo comiendo
const PARAR := 0.6  # s detenido en el carrito antes de empezar a comer
const LENTO := 2.0  # m/s: más rápido, va de paso

var jugador: CharacterBody3D  # jugador.gd
var barra := Barra.new()
var aviso := Label.new()  # sobre la barra: el completo, la reaparición
var muerte := Label.new()  # al medio: «Moriste»
var causa := Label.new()  # debajo: de qué, y que Tab lleva a otro lugar
var negro := ColorRect.new()  # el fundido antes de reaparecer
var rojo := TextureRect.new()  # los bordes de la pantalla al recibir daño
var mostrada := 100.0  # la vida que muestra la barra en claro (lo perdido, que se vacía después)
var t_perdida := 0.0
var t_destello := 0.0
var t_aviso := 0.0
var t := 0.0
var volviendo := false  # reapareció tras morir y todavía espera la colisión del lugar (pantalla en negro)
var comiendo := 0.0  # la vida que lleva ganada en este completo
var t_parado := 0.0


class Barra extends Control:
	var vida: CanvasLayer

	func _draw() -> void:
		vida.dibujar(self)


func _ready() -> void:
	layer = 2  # sobre la ayuda y la lista de Tab, bajo el mapa grande (5)
	# el enrojecido: transparente al medio, rojo en los bordes
	var gr := Gradient.new()
	gr.set_offset(0, 0.55)
	gr.set_color(0, Color(0.8, 0.0, 0.0, 0.0))
	gr.set_offset(1, 1.0)
	gr.set_color(1, Color(0.8, 0.0, 0.0, 0.55))
	var tex := GradientTexture2D.new()
	tex.gradient = gr
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.05, 0.5)
	tex.width = 256
	tex.height = 256
	rojo.texture = tex
	rojo.stretch_mode = TextureRect.STRETCH_SCALE
	rojo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rojo.set_anchors_preset(Control.PRESET_FULL_RECT)
	rojo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rojo.modulate.a = 0.0
	add_child(rojo)
	negro.color = Color(0, 0, 0, 0)
	negro.set_anchors_preset(Control.PRESET_FULL_RECT)
	negro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(negro)
	# la barra, con el número encima: abajo al centro
	barra.vida = self
	barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	barra.anchor_left = 0.5
	barra.anchor_right = 0.5
	barra.anchor_top = 1.0
	barra.anchor_bottom = 1.0
	barra.offset_left = -ANCHO / 2.0
	barra.offset_right = ANCHO / 2.0
	barra.offset_top = -ABAJO - ALTO - 26.0
	barra.offset_bottom = -ABAJO
	add_child(barra)
	estilo(aviso, 22)
	aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aviso.anchor_left = 0.5
	aviso.anchor_right = 0.5
	aviso.anchor_top = 1.0
	aviso.anchor_bottom = 1.0
	aviso.offset_bottom = barra.offset_top - 8.0
	aviso.grow_horizontal = Control.GROW_DIRECTION_BOTH
	aviso.grow_vertical = Control.GROW_DIRECTION_BEGIN
	aviso.visible = false
	add_child(aviso)
	estilo(muerte, 46)
	muerte.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	muerte.anchor_left = 0.5
	muerte.anchor_right = 0.5
	muerte.anchor_top = 0.3
	muerte.anchor_bottom = 0.3
	muerte.grow_horizontal = Control.GROW_DIRECTION_BOTH
	muerte.visible = false
	add_child(muerte)
	estilo(causa, 24)
	causa.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	causa.anchor_left = 0.5
	causa.anchor_right = 0.5
	causa.anchor_top = 0.3
	causa.anchor_bottom = 0.3
	causa.offset_top = 66.0
	causa.grow_horizontal = Control.GROW_DIRECTION_BOTH
	causa.visible = false
	add_child(causa)
	if jugador:
		mostrada = jugador.vida
		jugador.connect("danado", _al_dano)
		jugador.connect("murio", _al_morir)
		jugador.connect("reaparecio", _al_reaparecer)


static func estilo(l: Label, tam: int) -> void:
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", Color(1, 1, 1))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 5)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE


func avisar(texto: String, s := 3.0) -> void:
	aviso.text = texto
	aviso.visible = true
	t_aviso = s


# ---------- lo que dice jugador.gd ----------

func _al_dano(cantidad: float, _causa: String) -> void:
	t_destello = 0.35
	t_perdida = PERDIDA_ESPERA
	rojo.modulate.a = maxf(rojo.modulate.a, clampf(cantidad / 40.0, 0.35, 1.0))
	comiendo = 0.0
	t_parado = 0.0


func _al_morir() -> void:
	var c: String = jugador.causa_muerte
	muerte.text = "Moriste"
	causa.text = (c.left(1).to_upper() + c.substr(1) + "\n" if c != "" else "") + "Tab: reaparecer en otro lugar"
	for l in [muerte, causa]:
		l.visible = true
		l.modulate.a = 0.0
	aviso.visible = false
	t_aviso = 0.0
	volviendo = true


func _al_reaparecer(donde: String) -> void:
	muerte.visible = false
	causa.visible = false
	mostrada = jugador.vida
	avisar("Reapareciste" + (" " + donde if donde != "" else ""), 3.5)


# ---------- cada cuadro ----------

func _physics_process(dt: float) -> void:
	if jugador:
		carritos(dt)


# el completo: a pie en una hilera de carritos, detenido PARAR s, recupera COMPLETO por segundo hasta llenarse
func carritos(dt: float) -> void:
	var v: float = jugador.vida
	var vmax: float = jugador.VIDA_MAX
	var aca := ""
	if v > 0.0 and jugador.vehiculo == null:
		aca = carrito_en(Vector2(jugador.global_position.x, -jugador.global_position.z))
	if aca == "":
		t_parado = 0.0
		comiendo = 0.0
		return
	var lento := Vector2(jugador.velocity.x, jugador.velocity.z).length() < LENTO
	t_parado = t_parado + dt if lento else 0.0
	if v >= vmax:
		return
	if t_parado < PARAR:
		if comiendo == 0.0:
			avisar("Carritos de completos de %s: deténgase a comer uno" % aca, 0.6)
		return
	jugador.curar(COMPLETO * dt)
	comiendo += jugador.vida - v
	if jugador.vida >= vmax:
		avisar("Comió un completo: +%d, vida llena" % roundi(comiendo), 2.5)
		comiendo = 0.0
	else:
		avisar("Comiendo un completo… +%d" % roundi(comiendo), 0.6)


# la hilera de carritos en el punto p de grilla, o ""
static func carrito_en(p: Vector2) -> String:
	for c in CARRITOS:
		var a := deg_to_rad(float(c["a"]))
		var d := p - Vector2(c["x"], c["y"])
		var u := d.x * sin(a) - d.y * cos(a)  # el eje u del marco: (sen A, −cos A)
		var w := d.x * cos(a) + d.y * sin(a)  # el eje v: (cos A, sen A)
		if u >= c["u0"] and u <= c["u1"] and w >= c["v0"] and w <= c["v1"]:
			return c["nombre"]
	return ""


func _process(dt: float) -> void:
	if jugador == null:
		return
	t += dt
	var v: float = jugador.vida
	# lo perdido: queda PERDIDA_ESPERA s y se vacía; lo ganado se ve de inmediato
	if v >= mostrada:
		mostrada = v
	elif t_perdida > 0.0:
		t_perdida -= dt
	else:
		mostrada = maxf(v, mostrada - PERDIDA_VACIA * dt)
	t_destello = maxf(t_destello - dt, 0.0)
	rojo.modulate.a = move_toward(rojo.modulate.a, 0.0, dt / 0.6)
	if t_aviso > 0.0:
		t_aviso -= dt
		aviso.modulate.a = clampf(t_aviso / 0.4, 0.0, 1.0)
		aviso.visible = t_aviso > 0.0
	# muerto: el texto aparece y, al final de la espera, el negro; después de reaparecer, negro hasta que esté en el
	# lugar y luego se aclara
	var muerto_t: float = jugador.t_muerto
	var a := 0.0
	if v <= 0.0:
		muerte.modulate.a = smoothstep(0.15, 0.6, muerto_t)
		causa.modulate.a = smoothstep(0.4, 0.9, muerto_t)
		var espera: float = jugador.ESPERA_MUERTO
		a = smoothstep(espera - 0.8, espera - 0.1, muerto_t)
	elif volviendo:
		if jugador.llegar == Vector3.INF:
			volviendo = false
		else:
			a = 1.0
	negro.color.a = a if a > negro.color.a else move_toward(negro.color.a, a, dt / 0.5)
	barra.queue_redraw()


# la barra: el fondo, lo perdido en claro, la vida en su color y el borde; el número encima, a la derecha
func dibujar(c: Control) -> void:
	var vmax: float = jugador.VIDA_MAX
	var f: float = clampf(jugador.vida / vmax, 0.0, 1.0)
	var r := Rect2(0.0, c.size.y - ALTO, c.size.x, ALTO)
	c.draw_rect(r.grow(2.0), C_FONDO)
	var dentro := r.grow(-1.0)
	var fm := clampf(mostrada / vmax, 0.0, 1.0)
	if fm > f:
		c.draw_rect(Rect2(dentro.position + Vector2(dentro.size.x * f, 0.0), Vector2(dentro.size.x * (fm - f), dentro.size.y)), C_PERDIDA)
	var col := C_LLENA if f >= MEDIA else (C_MEDIA if f >= POCA else C_POCA)
	if f < POCA and f > 0.0:  # late, más rápido con menos vida
		col = col.lightened(0.35 * (0.5 + 0.5 * sin(t * lerpf(9.0, 5.0, f / POCA))))
	if t_destello > 0.0:
		col = col.lerp(Color(1, 1, 1), t_destello / 0.35 * 0.8)
	if f > 0.0:
		c.draw_rect(Rect2(dentro.position, Vector2(dentro.size.x * f, dentro.size.y)), col)
		c.draw_rect(Rect2(dentro.position, Vector2(dentro.size.x * f, 2.0)), col.lightened(0.3))  # un brillo arriba
	var borde := C_BORDE
	var inv: float = jugador.t_invulnerable
	if inv > 0.0:
		borde = C_INVULNERABLE.lerp(Color(1, 1, 1), 0.5 + 0.5 * sin(t * 12.0))
	elif t_destello > 0.0:
		borde = Color(1, 0.3, 0.25).lerp(C_BORDE, 1.0 - t_destello / 0.35)
	c.draw_rect(r.grow(2.0), borde, false, 2.0 if t_destello > 0.0 or inv > 0.0 else 1.5)
	var font := ThemeDB.fallback_font
	var tam := 20
	var txt := "%d" % ceili(jugador.vida)
	var p := Vector2(0.0, r.position.y - 7.0)
	c.draw_string_outline(font, p, "Vida", HORIZONTAL_ALIGNMENT_LEFT, c.size.x, 16, 5, Color(0, 0, 0, 0.8))
	c.draw_string(font, p, "Vida", HORIZONTAL_ALIGNMENT_LEFT, c.size.x, 16, Color(1, 1, 1, 0.9))
	var cn := Color(1, 1, 1) if f >= POCA else C_POCA.lightened(0.45)
	c.draw_string_outline(font, p, txt, HORIZONTAL_ALIGNMENT_RIGHT, c.size.x, tam, 5, Color(0, 0, 0, 0.8))
	c.draw_string(font, p, txt, HORIZONTAL_ALIGNMENT_RIGHT, c.size.x, tam, cn)


# ---------- la prueba sin teclado (main.gd) ----------

# --caer m: lo sube m metros sobre el suelo donde está (negativo: bajo el suelo, por donde la colisión de una cara no lo
# sostiene) y lo deja caer; imprime cuánto cayó, a qué rapidez llegó y la vida. --dano n: le quita n (montado también).
# Si muere, imprime dónde quedó el vehículo, espera que reaparezca e imprime dónde, la vida y que la invulnerabilidad
# para un daño; si no, imprime la vida cada 0,5 s hasta 14 s o hasta que se llene (la regeneración, o un completo con
# --desde en un carrito: 568.5,-245 o 680,146). Con --pausa s congela el juego s segundos después del daño o del golpe
# contra el suelo (Engine.time_scale 0, como --saltos) para que --png capture la barra o la muerte, y vuelve.
func prueba() -> void:
	var arbol := get_tree()
	var pausa := Args.num("--pausa", -1.0, 0.0, 30.0)
	var veh: Node3D = jugador.vehiculo
	if veh == null:
		while not jugador.is_on_floor():
			await arbol.physics_frame
	if Args.has("--caer"):
		var m := Args.num("--caer", 10.0, -50.0, 2000.0)
		if veh:
			push_warning("vida.gd: --caer va a pie (sin --vehiculo)")
		var y0: float = jugador.global_position.y + m
		jugador.global_position.y = y0
		jugador.velocity = Vector3.ZERO
		var s := 0.0
		while jugador.is_on_floor() and s < 0.5:  # (is_on_floor() es del cuadro anterior)
			await arbol.physics_frame
			s += get_physics_process_delta_time()
		while jugador.vida > 0.0 and not jugador.is_on_floor():
			await arbol.physics_frame
			s += get_physics_process_delta_time()
		print("vida.gd: --caer %.1f: cayó %.1f m en %.2f s, a %.1f m/s; vida %.0f" % [m, y0 - jugador.global_position.y, s,
			jugador.caida if jugador.is_on_floor() else -jugador.velocity.y, jugador.vida])
	if Args.has("--dano"):
		var n := Args.num("--dano", 10.0, 0.0, 1000.0)
		if veh:
			print("vida.gd: en %s, en x %.1f, y %.1f" % [veh.t["nombre"], veh.global_position.x, -veh.global_position.z])
		if veh:  # como jugando: un rato montado antes (recién traído, el vehículo todavía no se asienta)
			await arbol.create_timer(0.5).timeout
		jugador.danar(n, "la prueba")
		print("vida.gd: --dano %.0f: vida %.0f" % [n, jugador.vida])
	if pausa >= 0.0:
		var s := 0.0
		while s < pausa:
			await arbol.physics_frame
			s += get_physics_process_delta_time()
		Engine.time_scale = 0.0
		print("vida.gd: congelado a %.2f s: vida %.0f%s%s" % [s, jugador.vida, ", comiendo +%d" % roundi(comiendo) if comiendo > 0.0 else "",
			", invulnerable %.2f s" % jugador.t_invulnerable if jugador.t_invulnerable > 0.0 else ""])
		return
	if jugador.vida <= 0.0:
		var muerto_en := Vector2(jugador.global_position.x, -jugador.global_position.z)
		await Signal(jugador, "reaparecio")
		while jugador.llegar != Vector3.INF or not jugador.is_on_floor():
			await arbol.physics_frame
		var p := Vector2(jugador.global_position.x, -jugador.global_position.z)
		var pl: Vector3 = jugador.plaza
		print("vida.gd: murió en x %.1f, y %.1f; reapareció en x %.1f, y %.1f, altura %.2f (a %.1f m de la plaza, mirando a %.0f°), vida %.0f, invulnerable %.1f s" % [
			muerto_en.x, muerto_en.y, p.x, p.y, jugador.global_position.y, p.distance_to(Vector2(pl.x, pl.y)), rad_to_deg(jugador.yaw),
			jugador.vida, jugador.t_invulnerable])
		jugador.danar(30.0, "la prueba")
		print("vida.gd: invulnerable: 30 de daño lo dejan en %.0f" % jugador.vida)
		if veh:
			print("vida.gd: %s quedó en x %.1f, y %.1f (montado: %s)" % [veh.t["nombre"], veh.global_position.x, -veh.global_position.z, veh.montado])
		return
	var s := 0.0
	var dice := []
	while s < 14.0 and jugador.vida < jugador.VIDA_MAX:
		await arbol.create_timer(0.5, true, true).timeout
		s += 0.5
		dice.append("%.1f s: %.0f%s" % [s, jugador.vida, " (completo)" if comiendo > 0.0 else ""])
	if not dice.is_empty():
		print("vida.gd: ", ", ".join(dice))

