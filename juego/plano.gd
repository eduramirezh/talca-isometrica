# Los mapas del juego, sobre el plano de la comuna (plano_datos.gd: datos/plano.json, de pipeline/plano.py):
#
# - el mapa en miniatura, siempre a la vista, redondo, abajo a la derecha: las calles por clase, el agua, la vía, la
#   Ruta 5 y el límite alrededor del personaje (o del vehículo en que va), girado con la cámara (N: con el norte
#   arriba), con la flecha del personaje al medio, la N del norte en el borde, los lugares, el camino al marcador y el
#   marcador (en el borde si está fuera, con la distancia que falta por el camino). Se aleja con la rapidez.
# - el mapa grande (M): a pantalla completa, con el mouse suelto. Arrastrar lo mueve, la rueda (o el trackpad) lo
#   acerca, abre centrado en el personaje, con los nombres de las calles y de los lugares de cerca. Un clic pone el
#   marcador (sobre un lugar, en el lugar, con su nombre); un clic sobre el marcador o el botón derecho lo quita. Un
#   doble clic lleva ahí al personaje (o al vehículo en que va), y Enter, al marcador: ir_a(). M o Esc lo cierran y
#   devuelven el mouse a la cámara, como viaje.gd (Tab). Jugando captura la bandera (jugador.sin_viajes, bandera.gd)
#   no se viaja: la ayuda no lo ofrece, el doble clic es un clic y Enter solo avisa por qué.
#
# El camino y lo que se ve en el mundo (la cinta y la columna de luz) son de ruta.gd. Lo que no cambia de un cuadro a
# otro se dibuja una vez: las calles y los rellenos van en un Node2D en metros de grilla (Mundo) que se vuelve a dibujar
# solo cuando el personaje se aleja de donde se dibujó o cambia la escala; en cada cuadro cambia solo su transformación
# (el giro y el desplazamiento), y encima se dibujan el camino, el marcador y la flecha (pocos puntos).
#
#   var p := preload("res://plano.gd").new(); p.jugador = …; p.vehiculo = …; p.ruta = …; p.viaje = …; add_child(p)
#   p.abrir(true)        # el mapa grande (--plano)
extends CanvasLayer

const Datos := preload("res://plano_datos.gd")
const RADIO := 112.0  # px, el del mapa en miniatura
const MARGEN := 24.0  # px del borde de la ventana
const M_PIE := 260.0  # m de la miniatura (del centro al borde) a pie
const M_RAPIDO := 700.0  # m a 36 m/s (la Ruta 5 en auto)
const ESC_MIN := 0.035  # px/m del mapa grande: la comuna entera en ~800 px
const ESC_MAX := 4.0
const C_FONDO_MINI := Color(0.07, 0.08, 0.10, 0.92)
const C_BORDE := Color(1, 1, 1, 0.85)
const C_JUGADOR := Color(1, 1, 1)
const PEGAR := 40.0  # m: ir a un punto a menos de esto de una calle lleva a la calle (no adentro de un edificio)

var jugador: CharacterBody3D
var vehiculo: CharacterBody3D
var ruta: Node3D  # ruta.gd
var viaje: CanvasLayer  # viaje.gd: con su lista abierta, M y N no hacen nada (se están escribiendo)
var red: Node3D  # red.gd: los otros jugadores (flechas de su color) y, con su panel abierto, M y N no hacen nada
var bandera: Node3D  # bandera.gd: las banderas de captura la bandera (banderin())
var datos: RefCounted
var norte := false  # la miniatura con el norte arriba
var antes := Input.MOUSE_MODE_CAPTURED
var radio_m := M_PIE

var mini: Control  # la miniatura: el círculo de fondo; lo de adentro se recorta con shaders/circulo.gdshader
var recorte := ShaderMaterial.new()
var mini_mundo: Mundo
var mini_encima := Encima.new()
var mini_borde := Borde.new()
var grande: Control
var grande_mundo: Mundo
var grande_encima: Control
var ayuda := Label.new()
var aviso := Label.new()
var t_aviso := 0.0

# el mapa grande
var centro := Vector2.ZERO
var esc := 0.3
var arrastre := false
var movio := 0.0
var soltar_doble := false  # la suelta del segundo clic de un doble clic no es un clic
var deshacer := []  # el marcador antes del último clic: [marcador, nombre, s]; el doble clic lo deja como estaba
var etiquetas := []  # [texto, posición en la pantalla, ángulo, tamaño de letra, color]


# ---------- lo que se dibuja en metros de grilla ----------

class Mundo extends Node2D:
	var datos: RefCounted
	var region := Rect2()  # lo que se dibuja, en metros de grilla
	var esc := 1.0  # px/m con que se dibujó (el ancho mínimo de las líneas)
	var menores := true  # pasajes y caminos de servicio

	func _draw() -> void:
		if datos == null:
			return
		draw_mesh(datos.relleno, null)
		var px := 1.0 / esc  # un píxel, en metros
		for w in datos.rios_seg:
			draw_multiline(datos.rios_seg[w], Datos.C_AGUA, maxf(w, 2.0 * px))
		draw_multiline(datos.via_seg, Datos.C_VIA, maxf(2.0, 2.0 * px))
		# las calles de una clase en un solo dibujo (draw_multiline: pares de puntos), de las menores a las mayores; con
		# draw_polyline por calle, la miniatura sumaba ~670 dibujos por cuadro en el centro
		var por_clase := [PackedVector2Array(), PackedVector2Array(), PackedVector2Array(), PackedVector2Array(),
			PackedVector2Array(), PackedVector2Array(), PackedVector2Array(), PackedVector2Array()]
		for i in datos.calles_en(region):
			var c: int = datos.clase[i]
			if c >= 6 and not menores:
				continue
			var p: PackedVector2Array = datos.calles[i]
			var seg: PackedVector2Array = por_clase[c]
			for k in range(p.size() - 1):
				seg.append(p[k])
				seg.append(p[k + 1])
			por_clase[c] = seg
		for c in range(7, -1, -1):
			if por_clase[c].is_empty():
				continue
			var ancho := maxf(Datos.ANCHO[c] * 0.9, (2.4 if c <= 3 else 1.6) * px)
			draw_multiline(por_clase[c], Datos.C_CALLE[c], ancho)
		draw_multiline(datos.ruta5_seg, Datos.C_RUTA5, maxf(9.0, 2.6 * px))
		draw_polyline(datos.limite, Datos.C_LIMITE, 2.0 * px)


# el camino, los lugares, el marcador y la flecha, en coordenadas de la pantalla (cada cuadro)
class Encima extends Node2D:
	var plano: CanvasLayer

	func _draw() -> void:
		plano.dibujar_mini(self)


class Borde extends Node2D:
	var plano: CanvasLayer

	func _draw() -> void:
		plano.dibujar_borde(self)


class Circulo extends Control:
	func _draw() -> void:
		draw_circle(size / 2.0, size.x / 2.0, C_FONDO_MINI)


class Grande extends Control:
	var plano: CanvasLayer

	func _draw() -> void:
		plano.dibujar_grande(self)

	func _gui_input(e: InputEvent) -> void:
		plano.entrada_grande(e)


func _ready() -> void:
	layer = 5
	datos = Datos.uno()
	if datos == null:
		return
	norte = preload("res://args.gd").has("--norte")
	# la miniatura
	var circ := Circulo.new()
	recorte.shader = preload("res://shaders/circulo.gdshader")
	recorte.set_shader_parameter("radio", RADIO)
	circ.mouse_filter = Control.MOUSE_FILTER_IGNORE
	circ.size = Vector2(RADIO, RADIO) * 2.0
	mini = circ
	mini.anchor_left = 1.0
	mini.anchor_right = 1.0
	mini.anchor_top = 1.0
	mini.anchor_bottom = 1.0
	mini.offset_left = -MARGEN - 2.0 * RADIO
	mini.offset_right = -MARGEN
	mini.offset_top = -MARGEN - 2.0 * RADIO - 22.0
	mini.offset_bottom = -MARGEN - 22.0
	add_child(mini)
	mini_mundo = Mundo.new()
	mini_mundo.datos = datos
	mini_mundo.material = recorte
	mini.add_child(mini_mundo)
	mini_encima.plano = self
	mini_encima.material = recorte
	mini.add_child(mini_encima)
	mini_borde.plano = self
	mini.add_sibling.call_deferred(mini_borde)
	# el mapa grande
	var g := Grande.new()
	g.plano = self
	grande = g
	grande.set_anchors_preset(Control.PRESET_FULL_RECT)
	grande.mouse_filter = Control.MOUSE_FILTER_STOP
	grande.clip_contents = true
	grande.visible = false
	grande.resized.connect(redimensionar)
	add_child(grande)
	grande_mundo = Mundo.new()
	grande_mundo.datos = datos
	grande.add_child(grande_mundo)
	var gt := GrandeEncima.new()
	gt.plano = self
	grande_encima = gt
	grande_encima.set_anchors_preset(Control.PRESET_FULL_RECT)
	grande_encima.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grande.add_child(grande_encima)
	texto_ayuda()
	if jugador:
		jugador.viajes_cambio.connect(texto_ayuda)
	estilo(ayuda, 18)
	ayuda.position = Vector2(16, 12)
	grande.add_child(ayuda)
	# el aviso de llegada
	estilo(aviso, 30)
	aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aviso.set_anchors_preset(Control.PRESET_CENTER_TOP)
	aviso.offset_top = 90
	aviso.grow_horizontal = Control.GROW_DIRECTION_BOTH
	aviso.visible = false
	add_child(aviso)
	if ruta:
		ruta.cambio.connect(func(): grande_encima.queue_redraw())
		ruta.llego.connect(func(n: String): avisar("Llegaste" + (" a %s" % n if n != "" else " al marcador")))


class GrandeEncima extends Control:
	var plano: CanvasLayer

	func _draw() -> void:
		plano.dibujar_grande_encima(self)


static func estilo(l: Label, tam: int) -> void:
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", Color(1, 1, 1))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 5)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE


# la ayuda de arriba del mapa grande: sin los viajes mientras no se viaja (jugador.sin_viajes)
func texto_ayuda() -> void:
	var viaja: bool = jugador == null or jugador.sin_viajes == ""
	ayuda.text = "Clic: poner el marcador · clic en el marcador o botón derecho: quitarlo%s · arrastrar: mover · rueda: acercar · M o Esc: cerrar" % (
		" · doble clic: ir ahí · Enter: ir al marcador" if viaja else "")


func _exit_tree() -> void:
	Datos.soltar()


func avisar(t: String) -> void:
	aviso.text = t
	aviso.visible = true
	aviso.modulate.a = 1.0
	t_aviso = 3.5


# ---------- dónde está y hacia dónde mira ----------

func pos() -> Vector2:
	return Vector2(jugador.global_position.x, -jugador.global_position.z)


# el rumbo del cuerpo o del vehículo (como jugador.yaw: 0 al norte, crece a la izquierda)
func rumbo() -> float:
	if vehiculo and jugador.vehiculo:
		return vehiculo.rumbo
	return jugador.cuerpo.rotation.y


func rapidez() -> float:
	if vehiculo and jugador.vehiculo:
		return absf(vehiculo.rapidez)
	return Vector2(jugador.velocity.x, jugador.velocity.z).length()


func giro_mini() -> float:
	return 0.0 if norte else jugador.yaw


# grilla -> pantalla de la miniatura (relativa a su esquina)
func t_mini() -> Transform2D:
	var s := RADIO / radio_m
	return Transform2D(giro_mini(), Vector2(s, -s), 0.0, Vector2(RADIO, RADIO)) * Transform2D(0.0, -pos())


func t_grande() -> Transform2D:
	return Transform2D(0.0, Vector2(esc, -esc), 0.0, grande.size / 2.0) * Transform2D(0.0, -centro)


# ---------- cada cuadro ----------

func _process(dt: float) -> void:
	if datos == null or jugador == null:
		return
	if t_aviso > 0.0:
		t_aviso -= dt
		aviso.modulate.a = clampf(t_aviso, 0.0, 1.0)
		aviso.visible = t_aviso > 0.0
	# la escala de la miniatura sigue a la rapidez, suave
	var meta := lerpf(M_PIE, M_RAPIDO, clampf((rapidez() - 4.0) / 32.0, 0.0, 1.0))
	radio_m = lerpf(radio_m, meta, 1.0 - exp(-1.5 * dt))
	var p := pos()
	var s := RADIO / radio_m
	# se vuelve a dibujar cuando el personaje sale del centro de lo dibujado o la escala cambió más de un 15 %
	var r := mini_mundo.region
	if r.size == Vector2.ZERO or not r.grow(-radio_m * 1.45).has_point(p) or absf(s / mini_mundo.esc - 1.0) > 0.15:
		var lado := radio_m * 1.5 * 2.0
		mini_mundo.region = Rect2(p - Vector2(lado, lado), Vector2(lado, lado) * 2.0)
		mini_mundo.esc = s
		mini_mundo.menores = s > 0.25
		mini_mundo.queue_redraw()
	mini_mundo.transform = t_mini()
	recorte.set_shader_parameter("centro", mini.position + Vector2(RADIO, RADIO))
	mini_encima.queue_redraw()
	mini_borde.position = mini.position
	mini_borde.queue_redraw()
	if grande.visible:
		grande_encima.queue_redraw()


# ---------- la miniatura ----------

func dibujar_mini(n: Node2D) -> void:
	var t := t_mini()
	var c := Vector2(RADIO, RADIO)
	# los lugares
	for l in datos.lugares:
		var q: Vector2 = t * Vector2(l["x"], l["y"])
		if q.distance_to(c) < RADIO:
			n.draw_circle(q, 3.5, Color(0, 0, 0, 0.6))
			n.draw_circle(q, 2.5, Color(1, 0.93, 0.7))
	# el camino que falta
	if ruta and ruta.activo():
		var pts := camino_pantalla(t, Rect2(Vector2(-40, -40), Vector2(RADIO, RADIO) * 2.0 + Vector2(80, 80)))
		for p in pts:
			n.draw_polyline(p, Color(0, 0, 0, 0.5), 7.0)
			n.draw_polyline(p, ruta.COLOR, 4.5)
		var m: Vector2 = t * ruta.marcador
		if m.distance_to(c) <= RADIO - 9.0:
			pin(n, m, 1.0)
	# las banderas (bandera.gd) y los otros jugadores (red.gd): dentro del círculo, o en su borde si están más lejos
	if bandera:
		for b in bandera.en_mapa():
			var q: Vector2 = t * b[0]
			if q.distance_to(c) > RADIO - 10.0:
				q = c + (q - c).normalized() * (RADIO - 10.0)
			banderin(n, q, b[1], 0.8)
	if red:
		for o in red.en_mapa():
			var q: Vector2 = t * o[0]
			if q.distance_to(c) > RADIO - 8.0:
				q = c + (q - c).normalized() * (RADIO - 8.0)
			flecha(n, q, giro_mini() - o[1], 0.75, o[2])
	flecha(n, c, giro_mini() - rumbo(), 1.0)


# el camino desde donde va el personaje, en la pantalla, cortado a lo que cae cerca del rectángulo (para no
# transformar miles de puntos de un camino largo): una lista de polilíneas
func camino_pantalla(t: Transform2D, caja: Rect2) -> Array:
	var out := []
	var cur := PackedVector2Array()
	var cam: PackedVector2Array = ruta.camino
	var desde: int = ruta.prog
	var prev: Vector2 = t * ruta.proy
	cur.append(prev)
	for i in range(desde + 1, cam.size()):
		var q: Vector2 = t * cam[i]
		var dentro := caja.has_point(q) or caja.has_point(prev) or Rect2(prev, Vector2.ZERO).expand(q).intersects(caja)
		if dentro:
			if cur.is_empty():
				cur.append(prev)
			cur.append(q)
		elif cur.size() > 1:
			out.append(cur)
			cur = PackedVector2Array()
		else:
			cur = PackedVector2Array()
		prev = q
	if cur.size() > 1:
		out.append(cur)
	return out


# el borde: anillo, la N, el marcador fuera de la vista y la distancia (sin el recorte redondo)
func dibujar_borde(n: Node2D) -> void:
	var c := Vector2(RADIO, RADIO)
	n.draw_arc(c, RADIO, 0, TAU, 64, C_BORDE, 2.5, true)
	var f := ThemeDB.fallback_font
	var dn := Vector2(0, -1).rotated(giro_mini()) * RADIO
	n.draw_circle(c + dn, 11.0, Color(0.1, 0.1, 0.12))
	n.draw_arc(c + dn, 11.0, 0, TAU, 24, C_BORDE, 1.5, true)
	n.draw_string(f, c + dn + Vector2(-5.5, 6), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 0.85, 0.4))
	var texto := "N: norte arriba" if not norte else "N: girar con la cámara"
	if ruta and ruta.activo():
		var m: Vector2 = t_mini() * ruta.marcador
		if m.distance_to(c) > RADIO - 9.0:
			var dir := (m - c).normalized()
			pin(n, c + dir * (RADIO - 2.0), 0.9)
		texto = distancia(ruta.restante()) + ("" if ruta.nombre == "" else " · " + ruta.nombre)
	var w := f.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	n.draw_string_outline(f, Vector2(RADIO - w / 2.0, 2.0 * RADIO + 20.0), texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Color(0, 0, 0, 0.8))
	n.draw_string(f, Vector2(RADIO - w / 2.0, 2.0 * RADIO + 20.0), texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1))


static func distancia(m: float) -> String:
	if m < 950.0:
		return "%d m" % (roundi(m / 10.0) * 10)
	return ("%.1f km" % (m / 1000.0)).replace(".", ",")


# la flecha del personaje: un triángulo con muesca, apuntando según `ang` (0: arriba; positivo: a la derecha)
func flecha(n: CanvasItem, c: Vector2, ang: float, k: float, col := C_JUGADOR) -> void:
	var p := PackedVector2Array([Vector2(0, -11), Vector2(8, 8), Vector2(0, 3.5), Vector2(-8, 8)])
	var q := PackedVector2Array()
	for v in p:
		q.append(c + (v * k).rotated(ang))
	var borde := q.duplicate()
	borde.append(q[0])
	n.draw_colored_polygon(q, col)
	n.draw_polyline(borde, Color(0, 0, 0, 0.8), 2.0, true)


# una bandera de captura la bandera: el asta con el pie en p y el paño de su color a la derecha
func banderin(n: CanvasItem, p: Vector2, col: Color, k: float) -> void:
	var tope := p + Vector2(0, -20.0 * k)
	var pano := PackedVector2Array([tope, tope + Vector2(13.0 * k, 4.5 * k), tope + Vector2(0, 9.0 * k)])
	n.draw_line(p, tope, Color(0, 0, 0, 0.8), 4.0 * k)
	n.draw_colored_polygon(pano, col)
	n.draw_polyline(PackedVector2Array([pano[0], pano[1], pano[2], pano[0]]), Color(0, 0, 0, 0.8), 1.5, true)
	n.draw_line(p, tope, Color(0.9, 0.9, 0.9), 2.0 * k)
	n.draw_circle(p, 2.5 * k, Color(0, 0, 0, 0.8))


# el marcador: una gota con un punto
func pin(n: CanvasItem, p: Vector2, k: float) -> void:
	var col: Color = ruta.COLOR
	var r := 8.0 * k
	var tip := p
	var c := p + Vector2(0, -r * 1.9)
	n.draw_colored_polygon(PackedVector2Array([tip, c + Vector2(-r * 0.86, r * 0.5), c + Vector2(r * 0.86, r * 0.5)]), Color(0, 0, 0, 0.7))
	n.draw_circle(c, r + 1.5, Color(0, 0, 0, 0.7))
	n.draw_colored_polygon(PackedVector2Array([tip + Vector2(0, -1.5), c + Vector2(-r * 0.8, r * 0.45), c + Vector2(r * 0.8, r * 0.45)]), col)
	n.draw_circle(c, r, col)
	n.draw_circle(c, r * 0.4, Color(1, 1, 1))


# ---------- el mapa grande ----------

func abrir(si: bool) -> void:
	if datos == null or si == grande.visible:
		return
	grande.visible = si
	if jugador:
		jugador.quieto = si
	if si:
		if viaje and viaje.panel.visible:
			viaje.abrir(false)
		antes = Input.mouse_mode
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		centro = pos()
		esc = 0.3
		vista_grande()
	else:
		Input.mouse_mode = antes


func redimensionar() -> void:
	if grande.visible:
		vista_grande()


func vista_grande() -> void:
	var t := t_grande()
	var inv := t.affine_inverse()
	var a: Vector2 = inv * Vector2.ZERO
	var b: Vector2 = inv * grande.size
	var r := Rect2(a, Vector2.ZERO).expand(b)
	grande_mundo.region = r.grow(r.size.x * 0.1)
	grande_mundo.esc = esc
	grande_mundo.menores = esc > 0.3
	grande_mundo.transform = t
	grande_mundo.queue_redraw()
	etiquetar(r)
	grande.queue_redraw()
	grande_encima.queue_redraw()


func dibujar_grande(n: Control) -> void:
	n.draw_rect(Rect2(Vector2.ZERO, n.size), Datos.C_FONDO)


func dibujar_grande_encima(n: Control) -> void:
	var t := t_grande()
	var f := ThemeDB.fallback_font
	for e in etiquetas:
		n.draw_set_transform(e[1], e[2])
		var w := f.get_string_size(e[0], HORIZONTAL_ALIGNMENT_LEFT, -1, e[3]).x
		n.draw_string_outline(f, Vector2(-w / 2.0, e[3] * 0.35), e[0], HORIZONTAL_ALIGNMENT_LEFT, -1, e[3], 4, Color(0, 0, 0, 0.85))
		n.draw_string(f, Vector2(-w / 2.0, e[3] * 0.35), e[0], HORIZONTAL_ALIGNMENT_LEFT, -1, e[3], e[4])
	n.draw_set_transform(Vector2.ZERO)
	if ruta and ruta.activo():
		for p in camino_pantalla(t, Rect2(Vector2(-50, -50), n.size + Vector2(100, 100))):
			n.draw_polyline(p, Color(0, 0, 0, 0.55), 8.0)
			n.draw_polyline(p, ruta.COLOR, 5.0)
	# los lugares
	for l in datos.lugares:
		var q: Vector2 = t * Vector2(l["x"], l["y"])
		if Rect2(Vector2.ZERO, n.size).grow(20).has_point(q):
			n.draw_circle(q, 5.0, Color(0, 0, 0, 0.7))
			n.draw_circle(q, 3.8, Color(1, 0.93, 0.7))
	if ruta and ruta.activo():
		pin(n, t * ruta.marcador, 1.4)
	if bandera:  # cada una donde está, con su dueño; fuera de su lugar, un anillo en su base
		for b in bandera.en_mapa():
			var q: Vector2 = t * b[0]
			var base: Vector2 = t * b[2]
			if base.distance_to(q) > 6.0:
				n.draw_arc(base, 7.0, 0.0, TAU, 20, Color(0, 0, 0, 0.7), 4.0, true)
				n.draw_arc(base, 7.0, 0.0, TAU, 20, b[1], 2.0, true)
			banderin(n, q, b[1], 1.2)
			var txt := "bandera de %s" % b[3]
			n.draw_string_outline(f, q + Vector2(10, -22), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color(0, 0, 0, 0.8))
			n.draw_string(f, q + Vector2(10, -22), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, b[1].lightened(0.45))
	if red:
		for o in red.en_mapa():
			var q: Vector2 = t * o[0]
			flecha(n, q, -o[1], 1.1, o[2])
			n.draw_string_outline(f, q + Vector2(12, 5), o[3], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, Color(0, 0, 0, 0.8))
			n.draw_string(f, q + Vector2(12, 5), o[3], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, o[2].lightened(0.45))
	flecha(n, t * pos(), -rumbo(), 1.3)
	# la escala
	var m := escala_redonda(120.0 / esc)
	var px := m * esc
	var y := n.size.y - 28.0
	n.draw_line(Vector2(20, y), Vector2(20 + px, y), Color(1, 1, 1), 3.0)
	n.draw_line(Vector2(20, y - 6), Vector2(20, y + 6), Color(1, 1, 1), 2.0)
	n.draw_line(Vector2(20 + px, y - 6), Vector2(20 + px, y + 6), Color(1, 1, 1), 2.0)
	n.draw_string_outline(f, Vector2(26 + px, y + 6), distancia(m), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Color(0, 0, 0, 0.8))
	n.draw_string(f, Vector2(26 + px, y + 6), distancia(m), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1))
	if ruta and ruta.activo():
		var txt := "Marcador%s · %s por %s" % [" en " + ruta.nombre if ruta.nombre != "" else "", distancia(ruta.restante()),
			"línea recta" if ruta.recto else "las calles"]
		n.draw_string_outline(f, Vector2(20, y - 22), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 4, Color(0, 0, 0, 0.8))
		n.draw_string(f, Vector2(20, y - 22), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, ruta.COLOR.lightened(0.4))


static func escala_redonda(m: float) -> float:
	var e := pow(10.0, floorf(log(m) / log(10.0)))
	for k in [5.0, 2.0, 1.0]:
		if e * k <= m:
			return e * k
	return e


# Los nombres de las calles y de los lugares que caben, de las más importantes a las menores, cada uno una vez, en su
# tramo más largo a la vista y sin taparse (cajas en la pantalla). Se calcula al cambiar la vista, no en cada cuadro.
func etiquetar(r: Rect2) -> void:
	etiquetas.clear()
	var t := t_grande()
	var f := ThemeDB.fallback_font
	var ocupado: Array[Rect2] = []
	var pantalla := Rect2(Vector2.ZERO, grande.size)
	# los lugares primero (de cerca)
	if esc >= 0.22:
		for l in datos.lugares:
			var q: Vector2 = t * Vector2(l["x"], l["y"])
			if not pantalla.has_point(q):
				continue
			var tam := 15
			var w := f.get_string_size(l["nombre"], HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
			var caja := Rect2(q + Vector2(8, -tam * 0.6), Vector2(w, tam * 1.2))
			if libre(caja, ocupado):
				ocupado.append(caja)
				etiquetas.append([l["nombre"], q + Vector2(8 + w / 2.0, 0), 0.0, tam, Color(1, 0.93, 0.7)])
	var maxc := 5 if esc >= 0.5 else (3 if esc >= 0.2 else (2 if esc >= 0.07 else -1))
	if maxc < 0:
		return
	var mejor := {}  # nombre -> [clase, largo en px, punto medio, ángulo]
	for i in datos.calles_en(r):
		var c: int = datos.clase[i]
		if c > maxc:
			continue
		var nom: String = datos.nombres[datos.nombre[i]] if datos.nombre[i] < datos.nombres.size() else ""
		if nom == "" or nom == "Calle sin nombre" or nom.begins_with("Calle de Servicio"):
			continue
		nom = nom.trim_prefix("Calle ")  # «Calle 1 Norte» -> «1 Norte», como en los letreros
		var p: PackedVector2Array = datos.calles[i]
		for k in range(p.size() - 1):
			var a: Vector2 = t * p[k]
			var b: Vector2 = t * p[k + 1]
			var L := a.distance_to(b)
			var m := (a + b) / 2.0
			if not pantalla.grow(-30).has_point(m):
				continue
			if not mejor.has(nom) or L > mejor[nom][1]:
				var ang := (b - a).angle()
				if ang > PI / 2.0:
					ang -= PI
				elif ang < -PI / 2.0:
					ang += PI
				mejor[nom] = [c, L, m, ang]
	var nombres := mejor.keys()
	nombres.sort_custom(func(a, b): return mejor[a][0] < mejor[b][0] or (mejor[a][0] == mejor[b][0] and mejor[a][1] > mejor[b][1]))
	for nom in nombres:
		if etiquetas.size() > 90:
			break
		var e: Array = mejor[nom]
		var tam := 15 if e[0] <= 2 else 13
		var w := f.get_string_size(nom, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
		if w + 8.0 > e[1]:
			continue
		var caja := Rect2(e[2], Vector2.ZERO)
		for s in [-1.0, 1.0]:
			for h in [-1.0, 1.0]:
				caja = caja.expand(e[2] + Vector2(s * w / 2.0, h * tam * 0.6).rotated(e[3]))
		if not libre(caja, ocupado):
			continue
		ocupado.append(caja)
		etiquetas.append([nom, e[2], e[3], tam, Color(1, 1, 1)])


static func libre(c: Rect2, ocupado: Array[Rect2]) -> bool:
	for o in ocupado:
		if o.intersects(c):
			return false
	return true


func entrada_grande(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP and e.pressed:
			zoom(1.2, e.position)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN and e.pressed:
			zoom(1.0 / 1.2, e.position)
		elif e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed and e.double_click:
				arrastre = false
				soltar_doble = true
				doble_clic(e.position)
			elif e.pressed:
				arrastre = true
				movio = 0.0
			elif soltar_doble:
				soltar_doble = false
			else:
				arrastre = false
				if movio < 5.0:
					clic(e.position)
		elif e.button_index == MOUSE_BUTTON_RIGHT and e.pressed and ruta:
			ruta.quitar()
	elif e is InputEventMouseMotion and arrastre:
		movio += e.relative.length()
		centro -= Vector2(e.relative.x, -e.relative.y) / esc
		vista_grande()
	elif e is InputEventMagnifyGesture:
		zoom(e.factor, e.position)
	elif e is InputEventPanGesture:  # dos dedos en el trackpad: acercar o alejar, como la rueda
		zoom(pow(1.2, -e.delta.y * 0.5), e.position)
	grande.accept_event()


func zoom(k: float, en: Vector2) -> void:
	var antes_m: Vector2 = t_grande().affine_inverse() * en
	esc = clampf(esc * k, ESC_MIN, ESC_MAX)
	var despues: Vector2 = t_grande().affine_inverse() * en
	centro += antes_m - despues
	vista_grande()


func clic(en: Vector2) -> void:
	if ruta == null:
		return
	deshacer = [ruta.marcador, ruta.nombre, Time.get_ticks_msec() / 1000.0]
	var t := t_grande()
	if ruta.activo() and (t * ruta.marcador + Vector2(0, -14)).distance_to(en) < 16.0:
		ruta.quitar()
		return
	for l in datos.lugares:
		if (t * Vector2(l["x"], l["y"])).distance_to(en) < 10.0:
			ruta.marcar(Vector2(l["x"], l["y"]), l["nombre"])
			return
	ruta.marcar(t.affine_inverse() * en)


# Doble clic: ir ahí (sobre un lugar, al lugar). El primer clic ya puso o quitó el marcador: vuelve a como estaba. Si no
# se viaja (captura la bandera), queda lo del primer clic
func doble_clic(en: Vector2) -> void:
	if jugador and jugador.sin_viajes != "":
		deshacer = []
		return
	if ruta and deshacer.size() == 3 and Time.get_ticks_msec() / 1000.0 - deshacer[2] < 1.0:
		if deshacer[0] == Vector2.INF:
			ruta.quitar()
		elif deshacer[0] != ruta.marcador:
			ruta.marcar(deshacer[0], deshacer[1])
	deshacer = []
	var t := t_grande()
	for l in datos.lugares:
		if (t * Vector2(l["x"], l["y"])).distance_to(en) < 10.0:
			ir_a(Vector2(l["x"], l["y"]), l["h"], false, l["nombre"])
			return
	ir_a(t.affine_inverse() * en)


# Lleva al personaje (o al vehículo en que va) al punto p de grilla y cierra el mapa: jugador.ir(), como la lista de
# lugares (Tab), que lo deja ahí cuando la tesela tenga su colisión. Un punto fuera de la comuna pasa adentro; con
# `pegar`, uno a menos de PEGAR m de una calle va a la calle. La altura h (la del suelo, para que el rayo de jugador.gd
# no quede en un techo) sale del relieve de lejos.glb si no se sabe.
func ir_a(p: Vector2, h := NAN, pegar := true, nombre := "") -> void:
	if jugador == null:
		return
	if jugador.sin_viajes != "":  # captura la bandera (bandera.gd): el mapa sigue abierto, con el aviso
		avisar(jugador.sin_viajes)
		return
	var q: Vector2 = ruta.adentro(p) if ruta else p
	if pegar:
		var c: Array = datos.cercano(q, -1, PEGAR)
		if not c.is_empty():
			q = c[1]
	if is_nan(h):
		h = ruta.altura_lejos(q) if ruta else NAN
	if is_nan(h):
		h = 0.0
	abrir(false)
	jugador.viajar(q.x, q.y, h)
	print("plano.gd: a (%.0f, %.0f)%s" % [q.x, q.y, " «%s»" % nombre if nombre != "" else ""])
	if nombre != "":
		avisar(nombre)


func _input(e: InputEvent) -> void:
	if datos == null or not (e is InputEventKey and e.pressed and not e.echo):
		return
	if grande.visible and e.keycode == KEY_TAB and (jugador == null or jugador.sin_viajes == ""):  # si no se viaja, viaje.gd avisa
		# Tab con el mapa abierto: lo cierra y deja que viaje.gd abra su lista, con el mouse suelto (si viaje.gd la
		# abrió antes que esto, se le devuelve el mouse de antes del mapa para cuando la cierre)
		var m := antes
		abrir(false)
		if viaje and viaje.panel.visible:
			viaje.antes = m
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			jugador.quieto = true
		return
	if viaje and viaje.panel.visible:
		return  # se está escribiendo en la lista de lugares
	if red and red.panel.visible:
		return  # o en el panel de la red
	if e.physical_keycode == KEY_M:
		abrir(not grande.visible)
		get_viewport().set_input_as_handled()
	elif grande.visible and e.keycode in [KEY_ENTER, KEY_KP_ENTER] and ruta and ruta.activo():
		ir_a(ruta.marcador, NAN, ruta.nombre == "", ruta.nombre)
		get_viewport().set_input_as_handled()
	elif grande.visible and e.keycode == KEY_ESCAPE:
		abrir(false)
		get_viewport().set_input_as_handled()
	elif e.physical_keycode == KEY_N and not grande.visible:
		norte = not norte
		get_viewport().set_input_as_handled()
