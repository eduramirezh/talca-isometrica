# Las calles medidas en fotos y sus cruces, de cerca: hoy la Avenida Las Rastras (Ruta K-35, de la Avenida San Miguel
# al puente sobre el canal, 1,9 km), la Avenida San Miguel a cada lado de ella (784 m al poniente, hasta los ramales de
# la Ruta 5, y 290 m al oriente), la Ruta K-353 (199 m al sur), el enlace de San Miguel a Las Rastras y el cruce de las
# cuatro. Cada calle (modelos/entorno/perfil.gd) es su franja de una línea de cierre a la otra, con la calzada y su
# demarcación, el bandejón, las ciclovías, las soleras, las veredas, el pasto y la tierra, y su mobiliario
# (modelos/entorno/mobiliario.gd: postes con cables, columnas de luz, paraderos, resaltos, cebras, semáforos); el cruce
# (modelos/entorno/cruce.gd), el asfalto entre las esquinas, las esquinas, la isla del enlace con su achurado, la
# demarcación, los semáforos de poste y de mástil, los postes y cables que lo atraviesan, los letreros, las banderas,
# las palmeras y los cierros. Reemplaza en su franja el suelo de la página, sus usos y sus autos (recortes()); los
# árboles de las calles son los de la página (arboleda.gd), que pone también las hileras de álamos y eucaliptos de los
# perfiles, y la luz de los faroles le llega por GLOW, como la de los hitos.
#
# No tiene medidas propias: todo sale de data/perfiles.json y data/cruces.json (pipeline/perfiles.py: los ejes de OSM
# corridos a la imagen de Esri, las secciones de config/perfiles.json y el cruce de config/cruces.json, medidos en
# fotos de Mapillary de 2018 a 2026), en la copia de modelo3d/datos/ que hace make modelo3d; la página dibuja lo mismo
# (src/js/12-perfiles.js). Las medidas son de verdad, no las del pixel art: líneas de 12 cm, soleras de 15 cm, cables de
# 2 cm.
#
# Las franjas cruzan varias teselas: cada tramo de 20 m de una calle se arma cuando están las teselas de sus dos puntas
# (mapa.cargadas; hasta POR_CUADRO por cuadro), un cruce cuando están las de todo él, y cada objeto cuando está la de
# su pie (un vano de cable, las de sus dos postes), con el relieve de todas las cargadas (suelo.gd sumar()); lo armado
# queda aunque la tesela se suelte.
extends Node3D

const Malla := preload("res://malla.gd")
const Suelo := preload("res://modelos/entorno/suelo.gd")
const Perfil := preload("res://modelos/entorno/perfil.gd")
const Cruce := preload("res://modelos/entorno/cruce.gd")

const DATOS := "res://datos/perfiles.json"
const CRUCES := "res://datos/cruces.json"
const OBJETOS_POR_CUADRO := 40  # postes, vanos, paraderos…
const POR_CUADRO := 12  # tramos por cuadro, como mucho (~2,5 ms cada uno en el hilo principal: una tesela entera de una vez eran 130 ms)

var perfiles := []  # Perfil
var cruces := []  # Cruce
var S: Suelo
var pendientes := []  # [Perfil, s0, s1] de los tramos que faltan
var cruces_pend := []  # los Cruce que faltan
var objetos := []  # [[Vector2…], Callable] los postes, paraderos, vanos… que faltan, por sus teselas
var hechas := {}  # las teselas ya sumadas al relieve
var mias := {}  # las teselas que tocan las franjas y los cruces


static func leer(ruta: String) -> Dictionary:
	var f := FileAccess.open(ruta, FileAccess.READ)
	if f == null:
		push_warning("perfiles.gd: no está %s (make modelo3d)" % ruta)
		return {}
	var d = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else {}


func _init() -> void:
	var dp := leer(DATOS)
	for k in dp:
		perfiles.append(Perfil.new(k, dp[k]))
	if FileAccess.file_exists(CRUCES):
		var dc := leer(CRUCES)
		for k in dc:
			cruces.append(Cruce.new(k, dc[k]))


func recortes() -> Array:
	var out := []
	for p in perfiles:
		out += p.recortes()
	for c in cruces:
		out += c.recortes()
	return out


func _ready() -> void:
	if perfiles.is_empty():
		set_process(false)
		return
	for p in perfiles:
		for tr in p.tramos():
			pendientes.append([p, tr[0], tr[1]])
		objetos += p.objetos()
	cruces_pend = cruces.duplicate()


func clave(p: Vector2, tam: float) -> String:
	return "%d_%d" % [floori(p.x / tam), floori(p.y / tam)]


func listos(pts: Array, tam: float) -> bool:
	for q in pts:
		if not hechas.has(clave(q, tam)):
			return false
	return true


func _process(_d: float) -> void:
	var mapa = get_parent().get("mapa")
	if mapa == null:
		return
	if mias.is_empty():
		for p in perfiles:
			var s: float = p.desde()
			while s <= p.hasta():
				for d in [-16.0, 0.0, 16.0]:
					mias[clave(p.en(s, d), mapa.tam)] = true
				s += 10.0
		for c in cruces:
			for q in c.puntos():
				mias[clave(q, mapa.tam)] = true
	for k in mapa.cargadas:
		var t: Node3D = mapa.cargadas[k]
		if mias.has(k) and not hechas.has(k) and t != null and t.is_inside_tree():
			if S == null:
				S = Suelo.new(t)
			else:
				S.sumar(t)
			hechas[k] = true
	if S == null:
		return
	var t0 := Time.get_ticks_msec()
	var piso := Malla.new()
	var cosas := Malla.new()
	var n := 0
	# un cruce, solo en su cuadro y en dos: su suelo y, en el siguiente, su mobiliario (las palmeras se arman la primera vez)
	for c in cruces_pend:
		if listos(c.puntos(), mapa.tam):
			c.S = S
			if not c.get_meta("suelo", false):
				c.suelo(piso)
				c.set_meta("suelo", true)
			else:
				var ab = mapa.get("arboleda")
				if ab != null and ab.get("arb") != null:
					c.arboles = ab.arb
				c.cosas(cosas, self)
				cruces_pend.erase(c)
			n = POR_CUADRO
			break
	for tr in pendientes.duplicate():
		if n >= POR_CUADRO:
			break
		var p: Perfil = tr[0]
		if listos([p.en(tr[1], 0), p.en(tr[2], 0)], mapa.tam):
			p.S = S
			p.franja(piso, tr[1], tr[2])
			pendientes.erase(tr)
			n += 1
	var k := 0
	for o in objetos.duplicate():
		if k >= OBJETOS_POR_CUADRO:
			break
		if listos(o[0], mapa.tam):
			for p in perfiles:
				p.S = S
			o[1].call(cosas)
			objetos.erase(o)
			k += 1
	if not piso.vacia():
		piso.construir(self, "perfiles-suelo", false)
	if not cosas.vacia():
		cosas.construir(self, "perfiles-objetos")
	if n or k:
		print("perfiles.gd: %d piezas y %d objetos en %d ms (faltan %d tramos, %d cruces)" % [n, k, Time.get_ticks_msec() - t0, pendientes.size(), cruces_pend.size()])
	if pendientes.is_empty() and objetos.is_empty() and cruces_pend.is_empty():
		set_process(false)
