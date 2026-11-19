# Ir a un lugar: la comuna mide ~20 km de lado y caminando (8 m/s, 18 corriendo) se tarda. Tab abre la lista de los
# lugares de la página (mapa/indice.json, «lugares»: los de pipeline/pois.py, con su punto de grilla y la altura del
# suelo), que se filtra escribiendo; Enter o un doble clic lleva al personaje ahí (jugador.gd ir(): aparece cuando la
# tesela del lugar tenga su colisión, mapa.gd). Esc o Tab la cierra. El punto de un lugar es su dirección: suele caer en
# la vereda o en el borde del recinto, no al medio (CLAUDE.md, «El punto del lugar no es el centro del hito»).
extends CanvasLayer

const Glb := preload("res://glb.gd")

var lugares := []  # [{nombre, x, y, h}], por nombre
var panel := PanelContainer.new()
var filtro := LineEdit.new()
var lista := ItemList.new()
var vistos := []  # los índices de lugares que muestra la lista
var antes := Input.MOUSE_MODE_CAPTURED


func _ready() -> void:
	for l in Glb.info().get("lugares", []):
		lugares.append({"nombre": String(l.get("nombre", l.get("id", "?"))), "x": float(l["x"]), "y": float(l["y"]), "h": float(l.get("h", 0.0))})
	lugares.sort_custom(func(a, b): return a["nombre"].naturalnocasecmp_to(b["nombre"]) < 0)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.1
	panel.anchor_bottom = 0.9
	panel.offset_left = -260
	panel.offset_right = 260
	var caja := VBoxContainer.new()
	var titulo := Label.new()
	titulo.text = "Ir a un lugar (%d) · Enter: ir · Esc: cerrar" % lugares.size()
	filtro.placeholder_text = "escriba para filtrar"
	lista.size_flags_vertical = Control.SIZE_EXPAND_FILL
	caja.add_child(titulo)
	caja.add_child(filtro)
	caja.add_child(lista)
	panel.add_child(caja)
	add_child(panel)
	panel.visible = false
	filtro.text_changed.connect(func(_t): llenar())
	filtro.text_submitted.connect(func(_t): elegir(0 if lista.get_selected_items().is_empty() else lista.get_selected_items()[0]))
	lista.item_activated.connect(elegir)


func _input(e: InputEvent) -> void:
	if not (e is InputEventKey and e.pressed and not e.echo):
		return
	var red: Node = get_parent().get("red")
	if red and red.panel.visible:
		return  # se está escribiendo en el panel de la red (red.gd)
	if e.keycode == KEY_TAB:
		abrir(not panel.visible)
		get_viewport().set_input_as_handled()
	elif panel.visible and e.keycode == KEY_ESCAPE:
		abrir(false)
		get_viewport().set_input_as_handled()
	elif panel.visible and e.keycode in [KEY_DOWN, KEY_UP] and filtro.has_focus() and lista.item_count > 0:
		var i := 0 if lista.get_selected_items().is_empty() else lista.get_selected_items()[0]
		i = clampi(i + (1 if e.keycode == KEY_DOWN else -1), 0, lista.item_count - 1)
		lista.select(i)
		lista.ensure_current_is_visible()
		get_viewport().set_input_as_handled()


func abrir(si: bool) -> void:
	var j := jugador()
	panel.visible = si
	if j:
		j.quieto = si
	if si:
		antes = Input.mouse_mode
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		filtro.text = ""
		llenar()
		filtro.grab_focus()
	else:
		Input.mouse_mode = antes


func llenar() -> void:
	var q := filtro.text.strip_edges().to_lower()
	lista.clear()
	vistos.clear()
	for i in lugares.size():
		if q == "" or q in String(lugares[i]["nombre"]).to_lower():
			lista.add_item(lugares[i]["nombre"])
			vistos.append(i)
	if lista.item_count > 0:
		lista.select(0)


func elegir(k: int) -> void:
	if k < 0 or k >= vistos.size():
		return
	var l: Dictionary = lugares[vistos[k]]
	var j := jugador()
	if j:
		j.ir(l["x"], l["y"], l["h"])
		print("viaje.gd: a %s (%.0f, %.0f)" % [l["nombre"], l["x"], l["y"]])
	abrir(false)


func jugador() -> Node:
	return get_parent().get("jugador")
