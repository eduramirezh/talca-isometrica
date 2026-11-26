# La Ruta 5 en trinchera por la ciudad, de cerca: de 2 Norte a San Miguel (el Cruce Varoli), con los dos pasos
# superiores y los ramales que suben a las caleteras (20 y 21 Oriente), y la de 8 Sur. Cada tramo de TRAMOS lo arma
# modelos/entorno/trinchera.gd (su encabezado dice cómo) cuando están las teselas de todo él, con el relieve de todas
# (suelo.gd sumar()); lo armado queda aunque la tesela se suelte, como modelos/perfiles.gd.
#
# Un tramo: «y» de sur a norte, en y de grilla; «hondo», cuánto va la calzada bajo el suelo (m, por tramos lineales de
# y); «muro», el alto del muro vertical de hormigón (lo que falta hasta el suelo es talud de pasto); «pasos», los
# tableros de las calles que la cruzan (las polilíneas y medio ancho de hitos/enlaces-ruta-5.js).
#
# De dónde salen (fotos de Mapillary desde la autopista, una cada 40 m en cada sentido, 25 de diciembre de 2022 hacia
# el norte y 29 de diciembre de 2025 hacia el sur; la imagen de Esri de 2015):
#   - de y ≈ 0 (2 Norte) a y ≈ −470 (al sur de San Miguel) la autopista va entre muros verticales de ~6 m de moldaje
#     de tablas, con un talud de pasto seco de 1 m sobre ellos y un cierro de malla en el borde; bajo los pasos los
#     muros llegan al tablero (los estribos);
#   - al norte de 2 Norte los muros bajan y queda un talud sobre un muro bajo: a nivel en y ≈ +120, donde el ramal de
#     2 Norte (al oriente) llega a la calzada en y ≈ +190;
#   - al sur de San Miguel los muros bajan a 1 m (y ≈ −540) y la trinchera se hace más baja hasta quedar a nivel en
#     y ≈ −760; entremedio bajan los ramales de 20 Oriente (al poniente) y suben los de 21 Oriente (al oriente);
#   - la mediana es de tierra, con una defensa caminera a cada lado y postes de dos brazos; los pasos (San Miguel:
#     dos tableros de OSM, w478971526 y w478971523, que se ven como uno) son una losa delgada con columnas en la
#     mediana y una baranda de malla sobre un parapeto.
# Y de 8 Sur (las mismas pasadas): de y ≈ −850 a −1570 la trinchera es de taludes de pasto seco sobre un muro bajo de
# 1 m, de 5–6 m junto al paso y más baja hacia los dos lados; bajo el paso, los estribos. Al norte de ella, en la
# pasarela de y ≈ −790, la autopista va a nivel.
extends Node3D

const Args := preload("res://args.gd")
const Malla := preload("res://malla.gd")
const Suelo := preload("res://modelos/entorno/suelo.gd")
const Trinchera := preload("res://modelos/entorno/trinchera.gd")

const TRAMOS := [
	{
		"nombre": "2 Norte – San Miguel",
		"y": [-770, 205],
		"hondo": [[205, 0.0], [125, 0.3], [90, 1.6], [60, 3.0], [35, 4.6], [5, 6.4], [-470, 6.4], [-520, 5.2],
			[-580, 3.6], [-640, 2.1], [-700, 0.9], [-770, 0.0]],
		"muro": [[205, 0.4], [60, 0.6], [35, 1.3], [10, 5.4], [-460, 5.4], [-500, 2.2], [-540, 0.9], [-770, 0.6]],
		"pasos": [
			{"nombre": "2 Norte", "pts": [[2728, -35.5], [2736, -37], [2758, -42.5], [2766, -44.5]], "hw": 10.6},
			{"nombre": "San Miguel", "pts": [[2651, -370], [2658.5, -372], [2681, -378], [2689, -380.5]], "hw": 11.8},
		],
	},
	{
		"nombre": "8 Sur",
		"y": [-1600, -830],
		"hondo": [[-830, 0.0], [-860, 0.6], [-905, 1.8], [-966, 3.0], [-1020, 4.4], [-1060, 5.6], [-1100, 5.6],
			[-1150, 5.0], [-1250, 4.8], [-1400, 4.6], [-1460, 3.6], [-1500, 2.4], [-1530, 1.4], [-1570, 0.3], [-1600, 0.0]],
		"muro": [[-830, 0.6], [-900, 1.0], [-1530, 1.0], [-1600, 0.6]],
		"pasos": [
			{"nombre": "8 Sur", "pts": [[2472, -1071], [2493, -1076], [2519.5, -1082.5], [2535, -1086.5]], "hw": 10.6},
		],
	},
]

var tramos := []  # Trinchera
var pend := []  # [Trinchera, fase]: 0 el suelo, 1 lo demás
var S: Suelo
var hechas := {}


func _init() -> void:
	if "trinchera" in Args.sin_():  # --sin trinchera: para comparar con --fps
		return
	for t in TRAMOS:
		var tr := Trinchera.new(t)
		if not tr.est[0].is_empty():
			tramos.append(tr)
			pend.append([tr, 0])


func recortes() -> Array:
	var out := []
	for t in tramos:
		out += t.recortes()
	return out


# mundo.gd solido(): mientras un tramo no está armado, sus corredores no tienen colisión (el recorte quitó el
# terreno de las teselas) y sus pasos todavía no tienen tablero
func pendiente(p: Vector2) -> bool:
	for it in pend:
		for r in it[0].recortes():
			if Geometry2D.is_point_in_polygon(p, r["poligono"]):
				return true
	return false


func _process(_d: float) -> void:
	if pend.is_empty():
		set_process(false)
		return
	var mapa = get_parent().get("mapa")
	if mapa == null:
		return
	var it: Array = pend[0]
	var tr: Trinchera = it[0]
	var ts := []
	for g in tr.puntos():
		var k := "%d_%d" % [floori(g.x / mapa.tam), floori(g.y / mapa.tam)]
		var tt: Node3D = mapa.cargadas.get(k)
		if tt == null or not tt.is_inside_tree():
			return
		if not tt in ts:
			ts.append(tt)
	var t0 := Time.get_ticks_msec()
	if S == null:
		S = Suelo.new(ts[0])
	for t in ts:
		S.sumar(t)
	tr.S = S
	var m := Malla.new()
	var fase := "suelo" if it[1] == 0 else "cosas"
	if it[1] == 0:
		tr.armar_suelo(m)
		m.construir(self, "trinchera-suelo")
		it[1] = 1
	else:
		tr.armar_cosas(m)
		m.construir(self, "trinchera-cosas")
		var fz := get_parent().get_node_or_null("mapa/faroles")
		if fz and fz.has_method("agregar_fijas"):
			fz.agregar_fijas(tr.lamparas)
		pend.pop_front()
	print("trinchera_ruta5.gd: %s, %s en %d ms (%d teselas)" % [tr.nombre, fase, Time.get_ticks_msec() - t0, ts.size()])
