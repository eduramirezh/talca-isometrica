# Los edificios que dan a las calles alrededor de la plaza: cada planta de OSM (osm.json) que tiene un lado a la
# calle se levanta de nuevo con fachada de cerca (zócalo, ventanas hundidas con vidrio y marco, cornisa, pretil,
# vitrinas con cortina, letreros y toldos en los locales), y reemplaza su caja de un color del glb (capas
# «edificios» y «ciudad» dentro de la planta). Los lados que no dan a la calle quedan como muros lisos (medianeras).
#
# Fuentes: las plantas, pisos, alturas y nombres de OSM (tools/juego_osm.py); el aspecto, de las fotos de Commons
# (diagnostics/fotos/, `landmark.py photos`):
#   - Edificio de los Servicios Públicos (1 Oriente): «Edificio de los Servicios Públicos de Talca (Correo).jpg» y
#     «Detalle Edificio de los Servicios Públicos de Talca.jpg» (2022-05-29, CC BY-SA 4.0): hormigón gris claro,
#     machones dobles escalonados que suben sobre el pretil, antepechos con un cuadrado escalonado, ventanas de marco de
#     madera, marquesina sobre la entrada del medio;
#   - Antigua Intendencia (1 Norte con 1 Oriente): «Edificio de la Intendencia de la VII Región de Maule y Edificio de
#     los Servicios Públicos de Talca.jpg» (2022-05-29): neoclásica, crema, ventanas de marco verde, en reconstrucción
#     con andamios, una estructura de acero sobre el techo y un cierre de obra rojo en la vereda. Se dibuja así, como
#     en 2022: no sabemos cómo quedó (CLAUDE.md, «Ideas pendientes»);
#   - Municipalidad (1 Norte): «Talca Rathaus (3).jpg» (2018, CC BY-SA 4.0): tres pisos crema, una losa de techo que
#     vuela 1,5 m con canto de plancha ondulada, el último piso de ventanal corrido, el letrero «I. MUNICIPALIDAD DE
#     TALCA», una explanada de piedra con baranda y una palmera; OSM dice dos pisos y 5,6 m, la foto ~12 m;
#   - Gobierno Regional (1 Norte, 10 pisos): «Talca, reflecc (15550291390).jpg» (2014, CC BY-SA 2.0): muro cortina de
#     vidrio azul con montantes y bandas de piso, cantos blancos;
#   - la casa blanca de 1 Poniente 1133, junto a la catedral: fotos de la catedral 00 y 06 (2024, 2017): blanca, zócalo
#     café rojizo, rejas en las ventanas, techo de cuatro aguas rojo con alero.
# Lo demás es genérico y aproximado: los colores (una paleta de fachadas del centro, elegida por el id de OSM), la
# cantidad de ventanas, los locales y sus toldos; los letreros llevan solo los nombres que da OSM (BCI, Oriencoop,
# Chilexpress, AFP Habitat, Banco Santander, cine Plaza), con colores supuestos. El Edificio O'Higgins (ex Banco de
# Talca, art déco según el CMN) no tiene fotos libres: se dibuja con el lenguaje de los Servicios Públicos.
extends Node3D

const Malla := preload("res://modelos/entorno/malla.gd")
const Plano := preload("res://modelos/entorno/plano.gd")
const Suelo := preload("res://modelos/entorno/suelo.gd")

const NO := [114237041, 798980080, 223617018, 191869528]  # la catedral y su torre (catedral.gd), el quiosco, la Tesorería (dentro de los Servicios Públicos)
const PALETA := ["e9dfc6", "efe8d8", "dcc093", "d2b48a", "e5d2ab", "c3c3bb", "dfc6b2", "c9d1cd", "e8d9a6", "d7c9b5"]

# lo propio de cada edificio, por id de OSM (lo que falta sale de sus etiquetas y de valores por omisión)
const ESPECIAL := {
	939131659: {"estilo": "colonial", "alto": 7.6, "pisos": 2, "color": "ebe7dd", "zocalo": "6e4538", "techo": "teja"},
	813755289: {"estilo": "clasico", "alto": 12.5, "pisos": 3, "color": "dccfb3", "pb": "ventanas"},
	843566423: {"estilo": "comercial", "alto": 7.4, "color": "e3d4b6", "toldo": "2f5e3e"},
	843566419: {"estilo": "comercial", "alto": 7.4, "color": "d6c3a8", "toldo": "8a2c26"},
	275506471: {"estilo": "vidrio", "alto": 30.0, "pisos": 10},
	944738558: {"estilo": "comercial", "alto": 7.0, "color": "e6dcc8"},
	310597000: {"estilo": "clasico", "alto": 8.0, "pisos": 2, "color": "d9c9a6", "pb": "ventanas"},
	310596999: {"estilo": "clasico", "alto": 8.4, "pisos": 2, "color": "e8e0cc", "pb": "ventanas"},
	941592849: {"estilo": "clasico", "alto": 10.0, "pisos": 3, "color": "cdbfa8"},
	310186641: {"estilo": "municipal"},
	275506476: {"estilo": "intendencia", "alto": 12.0, "pisos": 3, "color": "e7dcc0"},
	214849867: {"estilo": "deco", "alto": 15.5, "pisos": 4, "color": "c9c3b6", "pb": "ventanas", "marco": "6b4a32"},
	275506477: {"estilo": "torre", "alto": 21.0, "pisos": 7, "color": "dfd6c4"},
	941674694: {"estilo": "moderno", "alto": 13.0, "pisos": 4, "color": "d9d9d4", "letreros": [["BCI", "1e1e1e", "ffffff"]]},
	941980882: {"estilo": "clasico", "alto": 12.4, "pisos": 4, "color": "e2d5bb"},
	813330085: {"estilo": "deco", "alto": 11.0, "pisos": 2, "color": "e3dac6", "pb": "ventanas", "marco": "3a3a36"},
	565220652: {"estilo": "torre", "alto": 35.0, "pisos": 12, "color": "d9a679"},
	392084816: {"estilo": "torre", "alto": 38.0, "pisos": 13, "color": "e6e1d6"},
	392084817: {"estilo": "torre", "alto": 38.0, "pisos": 13, "color": "e6e1d6"},
	842604131: {"estilo": "comercial", "letreros": [["ORIENCOOP", "f4f4f0", "0f5d3a"]]},
	842629847: {"estilo": "comercial", "letreros": [["ORIENCOOP", "f4f4f0", "0f5d3a"]]},
	842637397: {"estilo": "comercial", "letreros": [["CHILEXPRESS", "f3c623", "1b2a6b"]]},
	842637398: {"estilo": "comercial", "alto": 9.0, "letreros": [["AFP HABITAT", "ffffff", "b0282a"]]},
	818950429: {"estilo": "comercial", "letreros": [["BANCO SANTANDER", "d8241c", "ffffff"]]},
	842604130: {"estilo": "comercial", "alto": 9.0, "letreros": [["CINE PLAZA", "1d1d1d", "f2c94c"]]},
}

var m := Malla.new()
var mc := Malla.new()  # la colisión: el prisma de cada planta, sin los detalles
var S: Suelo
var pasillos := []
var plantas := []  # [id, polígono antihorario, etiquetas, especial]
var rng := RandomNumberGenerator.new()


func _init() -> void:
	pasillos.append(Plano.anillo_fachadas())
	for t in Plano.TRAMOS:
		pasillos.append(Plano.rect(t[2]))
	# las plantas que dan a la calle; las que se superponen se recortan con las anteriores (de mayor a menor área)
	var todas := []
	for b in Plano.osm().get("edificios", []):
		var id := int(b["id"])
		if id in NO:
			continue
		var p := PackedVector2Array()
		for q in b["anillo"]:
			p.append(Vector2(q[0], q[1]))
		if Geometry2D.is_polygon_clockwise(p):
			p.reverse()
		todas.append([id, p, b["tags"], area(p)])
	todas.sort_custom(func(x, y): return x[3] > y[3])
	var hechas := []
	for t in todas:
		var piezas := [t[1]]
		for h in hechas:
			var nuevas := []
			for pz in piezas:
				for r in Geometry2D.clip_polygons(pz, h):
					if not Geometry2D.is_polygon_clockwise(r) and area(r) > 4.0:
						nuevas.append(r)
			piezas = nuevas
		hechas.append(t[1])
		for pz in piezas:
			if da_a_la_calle(pz) or ESPECIAL.has(t[0]):
				plantas.append([t[0], pz, t[2], ESPECIAL.get(t[0], {})])


static func area(p: PackedVector2Array) -> float:
	var a := 0.0
	for i in p.size():
		a += p[i].cross(p[(i + 1) % p.size()])
	return abs(a) / 2


func en_calle(p: Vector2) -> bool:
	for q in pasillos:
		if Geometry2D.is_point_in_polygon(p, q):
			return not Geometry2D.is_point_in_polygon(p, Plano.pz())
	return false


# un lado da a la calle si, saliendo de su medio hacia afuera, se llega a la calle (o a la plaza de la Municipalidad)
# antes de 9 m sin cruzar otra planta
func lado_a_calle(a: Vector2, b: Vector2) -> bool:
	var L := a.distance_to(b)
	if L < 1.5:
		return false
	var d := (b - a) / L
	var o := Vector2(d.y, -d.x)
	var c := (a + b) / 2
	for k in range(1, 19):
		var p := c + o * (k * 0.5)
		if en_calle(p):
			return true
	return false


func da_a_la_calle(p: PackedVector2Array) -> bool:
	for i in p.size():
		if lado_a_calle(p[i], p[(i + 1) % p.size()]):
			return true
	return false


func recortes() -> Array:
	var out := []
	for t in plantas:
		# 1,8 m de margen: las plantas de la página (data/edificios.json) no calzan exactas con las de OSM de hoy
		var r := Geometry2D.offset_polygon(t[1], 1.8, Geometry2D.JOIN_MITER)
		if not r.is_empty():
			out.append({"poligono": r[0], "capas": ["edificios", "ciudad"]})
	# la plaza de la Municipalidad (OSM w813330084): sin los árboles ni el suelo de la página
	out.append({"poligono": Plano.rect([26.5, 69.0, 56.0, 77.2]), "capas": ["ciudad", "patios", "arboles", "autos", "suelo", "usos"]})
	return out


func _ready() -> void:
	m.solido = false
	S = Suelo.new(get_parent())
	rng.seed = 1742  # la fundación de Talca
	for t in plantas:
		edificio(t[0], t[1], t[2], t[3])
	plaza_municipal()
	m.construir(self, "fachadas")
	mc.construir_colision(self, "fachadas-colision")


# ---------------------------------------------------------------- un edificio

func spec(id: int, tags: Dictionary, esp: Dictionary) -> Dictionary:
	var pisos := int(tags.get("building:levels", "2"))
	var alto := float(tags.get("height", str(pisos * 3.3 + 0.8)))
	alto = max(alto, pisos * 3.1 + 0.8)
	var sp := {"estilo": "comercial" if pisos <= 3 else "clasico", "pisos": pisos, "alto": alto,
		"color": PALETA[id % PALETA.size()], "zocalo": "", "pb": "vitrinas", "toldo": "", "techo": "plano",
		"marco": "e8e6e0", "letreros": []}
	for k in esp:
		sp[k] = esp[k]
	if sp["estilo"] == "torre" or sp["estilo"] == "vidrio":
		sp["pb"] = "vitrinas" if sp["estilo"] == "torre" else "vidrio"
	return sp


func edificio(id: int, p: PackedVector2Array, tags: Dictionary, esp: Dictionary) -> void:
	var sp := spec(id, tags, esp)
	var c := Vector2.ZERO
	for q in p:
		c += q
	c /= p.size()
	var base := S.E(c.x, c.y) + Plano.ALTO_VEREDA
	var g := Malla.grilla(base)
	var col := Color(sp["color"])
	var H: float = sp["alto"]
	mc.prisma(g, p, -0.9, H if sp["estilo"] != "municipal" else 12.0, col)
	if sp["estilo"] == "municipal":
		municipalidad(p, g)
		return
	for i in p.size():
		var a := p[i]
		var b := p[(i + 1) % p.size()]
		if lado_a_calle(a, b):
			fachada(g, a, b, sp, id * 31 + i)
		else:
			m.muro(g, a, b, -0.9, H, col.darkened(0.12), "liso")
	# el techo: plano, un poco bajo el pretil, o de cuatro aguas de teja
	if sp["techo"] == "teja":
		techo_teja(g, p, H, 2.4)
	else:
		m.piso(g, p, H - 0.85, Color("8d8a84"), "hormigon")
		cosas_de_techo(g, p, H - 0.85, id)
	if sp["estilo"] == "intendencia":
		andamios(g, p, H)


# la fachada a la calle de a a b, según el estilo
func fachada(g: Malla.Marco, a: Vector2, b: Vector2, sp: Dictionary, semilla: int) -> void:
	rng.seed = semilla
	var L := a.distance_to(b)
	var estilo: String = sp["estilo"]
	var H: float = sp["alto"]
	var n: int = max(1, sp["pisos"])
	var col := Color(sp["color"])
	var marco := Color(sp["marco"])
	var zocalo: Color = Color(sp["zocalo"]) if sp["zocalo"] != "" else col.darkened(0.3)
	if estilo == "vidrio":
		muro_cortina(g, a, b, H, n)
		return
	var hg: float = {"comercial": 3.9, "clasico": 4.0, "deco": 4.3, "torre": 4.2, "moderno": 4.2, "colonial": 3.8, "intendencia": 4.6}.get(estilo, 3.9)
	if n == 1:
		hg = H - 0.9
	var pretil := 0.9
	var hu: float = (H - hg - pretil) / max(1, n - 1)
	var bahia: float = {"comercial": 4.2, "clasico": 3.6, "deco": 3.4, "torre": 3.3, "moderno": 3.0, "colonial": 3.4, "intendencia": 3.3}.get(estilo, 3.6)
	var nb: int = max(1, roundi(L / bahia))
	var bw := L / nb
	var huecos := []
	var vidrio := Color("2e3a44")
	# los pisos de arriba: una ventana por bahía (en el moderno, una banda corrida)
	for k in range(1, n):
		var hf: float = hg + (k - 1) * hu
		if estilo == "moderno":
			var hq := PackedVector2Array([Vector2(0.4, hf + 0.85), Vector2(L - 0.4, hf + 0.85), Vector2(L - 0.4, hf + hu - 0.45), Vector2(0.4, hf + hu - 0.45)])
			m.derrame(g, a, b, hq, 0.12, col.darkened(0.2), "liso", vidrio, "vidrio")
			huecos.append(hq)
			var s := 0.4 + 1.5
			while s < L - 0.6:
				m.moldura(g, a - Vector2((b - a).y, -(b - a).x).normalized() * 0.1, b - Vector2((b - a).y, -(b - a).x).normalized() * 0.1, s - 0.03, s + 0.03, hf + 0.85, hf + hu - 0.45, 0.03, Color("3c3f42"), "metal")
				s += 1.5
			continue
		for j in nb:
			var s: float = (j + 0.5) * bw
			var w: float = clampf(bw * (0.42 if estilo == "colonial" else 0.5), 0.9, 2.2)
			var vh: float = hu * (0.62 if estilo != "torre" else 0.55)
			var h0: float = hf + (0.95 if estilo != "torre" else 1.0)
			var hq: PackedVector2Array
			if estilo == "colonial" or estilo == "intendencia":
				hq = Malla.arco(s, w, h0, h0 + vh - w / 2 * 0.35, w / 2 * 0.35, 6)
			else:
				hq = PackedVector2Array([Vector2(s - w / 2, h0), Vector2(s + w / 2, h0), Vector2(s + w / 2, h0 + vh), Vector2(s - w / 2, h0 + vh)])
			huecos.append(hq)
			ventana(g, a, b, hq, s, w, h0, h0 + vh, marco, vidrio, estilo)
			if estilo == "torre":
				# balcón: losa que sale 0,9 m y una baranda de fierro
				m.moldura(g, a, b, s - w / 2 - 0.5, s + w / 2 + 0.5, hf - 0.02, hf + 0.16, 0.9, col.darkened(0.08))
				baranda(g, a, b, s - w / 2 - 0.5, s + w / 2 + 0.5, hf + 0.16, 0.9)
			elif estilo == "deco":

				m.moldura(g, a, b, s - 0.32, s + 0.32, h0 - 1.07, h0 - 0.43, 0.04, col.lightened(0.05))
				m.moldura(g, a, b, s - 0.2, s + 0.2, h0 - 0.95, h0 - 0.55, 0.08, col.lightened(0.08))
			elif estilo == "intendencia" or estilo == "clasico":
				# una cornisa sobre la ventana
				m.moldura(g, a, b, s - w / 2 - 0.2, s + w / 2 + 0.2, h0 + vh + 0.1, h0 + vh + 0.28, 0.14, col.lightened(0.06))
	# la planta baja
	var pb: String = sp["pb"]
	if estilo == "colonial":
		pb = "ventanas"
	var letreros: Array = sp["letreros"]
	var toldo: String = sp["toldo"]
	if pb == "vitrinas":
		var j := 0
		while j < nb:
			var s: float = (j + 0.5) * bw
			var x0 := s - bw / 2 + 0.35
			var x1 := s + bw / 2 - 0.35
			var hq := PackedVector2Array([Vector2(x0, 0.2), Vector2(x1, 0.2), Vector2(x1, hg - 1.1), Vector2(x0, hg - 1.1)])
			huecos.append(hq)
			vitrina(g, a, b, hq, x0, x1, hg)
			j += 1
		# un letrero sobre cada local (cada dos bahías), con el nombre de OSM si lo hay; si no, un panel de color
		var k := 0
		var s0 := 0.25
		while s0 < L - 1.0:
			var s1: float = min(L - 0.25, s0 + bw * (2 if nb > 2 else nb) - 0.3)
			var fondo := Color(["2f4f6f", "8a2c26", "f2efe6", "2c5a3a", "d9a325", "3b3b3b"][rng.randi() % 6])
			var texto := ""
			var letra := Color.WHITE
			if k < letreros.size():
				fondo = Color(letreros[k][1])
				letra = Color(letreros[k][2])
				texto = letreros[k][0]
			m.moldura(g, a, b, s0, s1, hg - 0.95, hg - 0.25, 0.1, fondo, "pintura")
			if texto != "":
				rotulo(g, a, b, (s0 + s1) / 2, hg - 0.6, 0.11, texto, letra, 0.42)
			if toldo != "" or rng.randf() < 0.3:
				var tc := Color(toldo) if toldo != "" else Color(["7a2e26", "2f5e3e", "3a4f7a", "c9a227"][rng.randi() % 4])
				toldo_(g, a, b, s0 + 0.1, s1 - 0.1, hg - 1.05, tc)
			s0 = s1 + 0.3
			k += 1
	elif pb == "ventanas" or pb == "vidrio":
		var puerta_j := nb / 2
		for j in nb:
			var s: float = (j + 0.5) * bw
			if j == puerta_j:
				var w: float = min(bw - 0.6, 2.4)
				var hq := PackedVector2Array([Vector2(s - w / 2, 0.0), Vector2(s + w / 2, 0.0), Vector2(s + w / 2, 3.0), Vector2(s - w / 2, 3.0)])
				if estilo == "colonial":
					hq = Malla.arco(s, 1.5, 0.0, 2.55, -1.0, 8)
				huecos.append(hq)
				m.derrame(g, a, b, hq, 0.35, col.darkened(0.15), "liso", Color("4a3626"), "pintura")
				if estilo == "deco" or estilo == "clasico":
					# marquesina sobre la entrada (los Servicios Públicos tienen una)
					m.moldura(g, a, b, s - w / 2 - 0.6, s + w / 2 + 0.6, 3.35, 3.55, 1.3, col.darkened(0.05))
				continue
			var w: float = clampf(bw * 0.5, 0.9, 2.0)
			var hq := PackedVector2Array([Vector2(s - w / 2, 1.0), Vector2(s + w / 2, 1.0), Vector2(s + w / 2, hg - 0.8), Vector2(s - w / 2, hg - 0.8)])
			huecos.append(hq)
			ventana(g, a, b, hq, s, w, 1.0, hg - 0.8, marco, vidrio, estilo)
			if estilo == "colonial":
				reja(g, a, b, s - w / 2, s + w / 2, 1.0, hg - 0.8)
	m.muro_vanos(g, a, b, -0.9, H, huecos, col, "liso")
	# zócalo, bandas de piso, cornisa y pretil
	m.moldura(g, a, b, 0, L, -0.9, 0.2 if pb == "vitrinas" else 0.75, 0.05, zocalo, "liso")
	if estilo in ["clasico", "intendencia", "colonial", "comercial"]:
		for k in range(1, n):
			var hf: float = hg + (k - 1) * hu
			m.moldura(g, a, b, 0, L, hf - 0.1, hf + 0.12, 0.08, col.lightened(0.06))
	if estilo != "moderno":
		m.moldura(g, a, b, -0.05, L + 0.05, H - pretil - 0.1, H - pretil + 0.25, 0.3 if estilo != "torre" else 0.15, col.lightened(0.07))
	m.moldura(g, a, b, 0, L, H - 0.12, H, 0.08, col.lightened(0.04))
	if estilo == "deco":
		# los machones dobles escalonados entre las bahías, que suben 1,2 m sobre el pretil (Servicios Públicos)
		for j in range(0, nb + 1):
			var s: float = j * bw
			var alto := H + (1.2 if j % 2 == 0 else 0.4)
			m.moldura(g, a, b, max(0.0, s - 0.42), min(L, s + 0.42), hg - 0.3, alto, 0.12, col.lightened(0.04))
			m.moldura(g, a, b, max(0.0, s - 0.25), min(L, s + 0.25), hg - 0.3, alto - 0.3, 0.26, col.lightened(0.07))
	if estilo == "intendencia" or estilo == "clasico" and n <= 3:
		for j in range(0, nb + 1):
			var s: float = j * bw
			m.moldura(g, a, b, max(0.0, s - 0.3), min(L, s + 0.3), hg, H - pretil - 0.1, 0.1, col.lightened(0.05))


# una ventana hundida: derrame, vidrio, marco con un montante y un travesaño, alféizar
func ventana(g: Malla.Marco, a: Vector2, b: Vector2, hq: PackedVector2Array, s: float, w: float, h0: float, h1: float,
		marco: Color, vidrio: Color, estilo: String) -> void:
	var prof := 0.2 if estilo != "colonial" else 0.32
	var L := a.distance_to(b)
	var d := (b - a) / L
	var o := Vector2(d.y, -d.x)
	m.derrame(g, a, b, hq, prof, Color(0.8, 0.78, 0.74), "liso", vidrio, "vidrio")
	# el marco y los montantes: paneles planos 1 cm delante del vidrio (una moldura por listón costaría 12 triángulos)
	var pa := a - o * prof
	var pb := b - o * prof
	var t := 0.06
	var ht := h0 + (h1 - h0) * 0.7
	for r in [[s - w / 2, s + w / 2, h0, h0 + t], [s - w / 2, s + w / 2, h1 - t, h1], [s - w / 2, s - w / 2 + t, h0, h1],
			[s + w / 2 - t, s + w / 2, h0, h1], [s - 0.025, s + 0.025, h0, h1], [s - w / 2, s + w / 2, ht - 0.025, ht + 0.025]]:
		m.panel(g, pa, pb, r[0], r[1], r[2], r[3], 0.012, marco, "pintura")
	m.moldura(g, a, b, s - w / 2 - 0.08, s + w / 2 + 0.08, h0 - 0.08, h0, 0.12, Color(0.85, 0.84, 0.8))
	# un equipo de aire acondicionado de vez en cuando (las fotos de los Servicios Públicos y la Municipalidad los tienen)
	if estilo in ["deco", "clasico", "torre"] and rng.randf() < 0.12:
		m.moldura(g, a, b, s + w / 2 - 0.65, s + w / 2 - 0.05, h0 + 0.05, h0 + 0.45, 0.45, Color(0.88, 0.88, 0.86), "metal")


# una vitrina: el vidrio al fondo de un derrame de 0,25 m, la puerta en un lado, la cortina metálica enrollada arriba
func vitrina(g: Malla.Marco, a: Vector2, b: Vector2, hq: PackedVector2Array, x0: float, x1: float, hg: float) -> void:
	var L := a.distance_to(b)
	var d := (b - a) / L
	var o := Vector2(d.y, -d.x)
	m.derrame(g, a, b, hq, 0.25, Color(0.3, 0.31, 0.32), "metal", Color("324049"), "vidrio")
	var pa := a - o * 0.25
	var pb := b - o * 0.25
	var mt := Color(0.25, 0.26, 0.27)
	var pu := x1 - 1.1 if rng.randf() < 0.5 else x0 + 0.1
	for r in [[x0, x1, 0.2, 0.32], [pu, pu + 0.06, 0.2, hg - 1.1], [pu + 0.94, pu + 1.0, 0.2, hg - 1.1], [pu, pu + 1.0, 2.25, 2.31]]:
		m.panel(g, pa, pb, r[0], r[1], r[2], r[3], 0.012, mt, "metal")
	m.moldura(g, a, b, x0 - 0.05, x1 + 0.05, hg - 1.1, hg - 0.95, 0.18, Color(0.55, 0.56, 0.56), "metal")


# un rótulo de texto (Label3D) sobre un muro a -> b, en s, a la altura h, salido o m
func rotulo(g: Malla.Marco, a: Vector2, b: Vector2, s: float, h: float, o: float, texto: String, col: Color, alto := 0.4) -> void:
	var L := a.distance_to(b)
	var d := (b - a) / L
	var ou := Vector2(d.y, -d.x)
	var p := a + d * s + ou * (o + 0.012)
	var l := Label3D.new()
	l.text = texto
	l.font_size = 96
	l.pixel_size = alto / 96.0 * 0.95
	l.modulate = col
	l.outline_size = 0
	l.shaded = true
	l.double_sided = false
	add_child(l)
	l.position = g.V(p.x, p.y, h)
	l.look_at(l.position - g.N(ou.x, ou.y), Vector3.UP)


# un toldo de lona inclinado, de s0 a s1, colgado a h, que sale 1,3 m y baja 0,6 m, con faldón
func toldo_(g: Malla.Marco, a: Vector2, b: Vector2, s0: float, s1: float, h: float, col: Color) -> void:
	var L := a.distance_to(b)
	var d := (b - a) / L
	var o := Vector2(d.y, -d.x)
	var P := func(s: float, sal: float, hh: float) -> Vector3:
		var q: Vector2 = a + d * s + o * sal
		return g.V(q.x, q.y, hh)
	var antes := m.solido
	m.solido = false
	m.cara([P.call(s0, 0.02, h), P.call(s1, 0.02, h), P.call(s1, 1.3, h - 0.6), P.call(s0, 1.3, h - 0.6)], col, "tela", g.N(o.x, o.y, 2.2))
	m.cara([P.call(s0, 1.3, h - 0.6), P.call(s1, 1.3, h - 0.6), P.call(s1, 1.3, h - 0.85), P.call(s0, 1.3, h - 0.85)], col.darkened(0.1), "tela", g.N(o.x, o.y))
	for sg in [[s0, -1.0], [s1, 1.0]]:
		m.cara([P.call(sg[0], 0.02, h), P.call(sg[0], 1.3, h - 0.6), P.call(sg[0], 1.3, h - 0.85)], col.darkened(0.15), "tela", g.N(d.x * sg[1], d.y * sg[1]))
	m.solido = antes


# una baranda de fierro (pasamanos y barrotes) delante de un muro, a sal m, de s0 a s1 desde h
func baranda(g: Malla.Marco, a: Vector2, b: Vector2, s0: float, s1: float, h: float, sal: float) -> void:
	var c := Color(0.2, 0.21, 0.22)
	m.moldura(g, a, b, s0, s1, h + 0.95, h + 1.0, sal, c, "metal", sal - 0.05)
	# los barrotes, como un panel oscuro a cada lado (de cerca se lee como fierro; 4 triángulos en vez de cientos)
	m.panel(g, a, b, s0, s1, h, h + 0.95, sal - 0.02, c.lightened(0.05), "metal")
	var L := a.distance_to(b)
	var d := (b - a) / L
	var o := Vector2(d.y, -d.x)
	m.panel(g, b + o * (sal - 0.03) * 2, a + o * (sal - 0.03) * 2, L - s1, L - s0, h, h + 0.95, -(sal - 0.03), c, "metal")


# las rejas de las ventanas de la casa colonial (foto 00 de la catedral): un enrejado en rombos, como barrotes cruzados
func reja(g: Malla.Marco, a: Vector2, b: Vector2, s0: float, s1: float, h0: float, h1: float) -> void:
	var c := Color(0.95, 0.95, 0.93)
	var s: float = s0
	while s <= s1 + 0.01:
		m.moldura(g, a, b, s - 0.015, s + 0.015, h0, h1, 0.06, c, "metal", 0.03)
		s += 0.16
	var h := h0 + 0.3
	while h < h1:
		m.moldura(g, a, b, s0, s1, h - 0.015, h + 0.015, 0.06, c, "metal", 0.03)
		h += 0.55


# el muro cortina del Gobierno Regional: vidrio azul entre montantes cada 1,5 m y bandas de piso, cantos blancos,
# planta baja vidriada y hundida
func muro_cortina(g: Malla.Marco, a: Vector2, b: Vector2, H: float, n: int) -> void:
	var L := a.distance_to(b)
	var hg := 5.0
	var hu: float = (H - hg - 0.5) / (n - 1)
	var vid := Color("3b5f8a")
	m.panel(g, a, b, 0.5, L - 0.5, hg, H - 0.5, 0.0, vid, "vidrio")
	var s := 0.5
	while s <= L - 0.5:
		m.moldura(g, a, b, s - 0.03, s + 0.03, hg, H - 0.5, 0.06, Color("2a2f35"), "metal")
		s += 1.5
	for k in n:
		var h := hg + k * hu
		m.moldura(g, a, b, 0.5, L - 0.5, h - 0.15, h + 0.05, 0.08, Color("1f2a36"), "metal")
	m.moldura(g, a, b, 0, 0.5, -0.9, H, 0.1, Color("f0efea"))
	m.moldura(g, a, b, L - 0.5, L, -0.9, H, 0.1, Color("f0efea"))
	m.moldura(g, a, b, 0, L, H - 0.5, H, 0.1, Color("f0efea"))
	var hq := PackedVector2Array([Vector2(1.2, 0.0), Vector2(L - 1.2, 0.0), Vector2(L - 1.2, hg - 0.4), Vector2(1.2, hg - 0.4)])
	m.derrame(g, a, b, hq, 2.0, Color("d8d8d2"), "liso", Color("41505c"), "vidrio")
	m.superficie(g, a, b, PackedVector2Array([Vector2(0, -0.9), Vector2(L, -0.9), Vector2(L, hg), Vector2(0, hg)]), [hq], Color("e8e7e2"))
	var s2 := 1.2
	while s2 <= L - 1.2:
		m.moldura(g, a - Vector2((b - a).y, -(b - a).x).normalized() * 1.95, b - Vector2((b - a).y, -(b - a).x).normalized() * 1.95, s2 - 0.04, s2 + 0.04, 0.0, hg - 0.4, 0.04, Color("2a2f35"), "metal")
		s2 += 2.0


# un techo de cuatro aguas de teja sobre el rectángulo orientado que contiene la planta, con alero de 0,6 m
func techo_teja(g: Malla.Marco, p: PackedVector2Array, h: float, alto: float) -> void:
	var lmax := 0.0
	var d := Vector2(1, 0)
	for i in p.size():
		var e := p[(i + 1) % p.size()] - p[i]
		if e.length() > lmax:
			lmax = e.length()
			d = e.normalized()
	var n := Vector2(-d.y, d.x)
	var u0 := INF
	var u1 := -INF
	var v0 := INF
	var v1 := -INF
	for q in p:
		u0 = min(u0, q.dot(d)); u1 = max(u1, q.dot(d)); v0 = min(v0, q.dot(n)); v1 = max(v1, q.dot(n))
	u0 -= 0.6; u1 += 0.6; v0 -= 0.6; v1 += 0.6
	var P := func(u: float, v: float, hh: float) -> Vector3:
		var q := d * u + n * v
		return g.V(q.x, q.y, hh)
	var vm := (v0 + v1) / 2
	var r := (v1 - v0) / 2
	var col := Color("a24a32")
	var he := h - 0.25
	m.cara([P.call(u0, v0, he), P.call(u1, v0, he), P.call(u1 - r, vm, he + alto), P.call(u0 + r, vm, he + alto)], col, "teja", (Vector3(-n.x, 0, n.y) * alto + Vector3(0, r, 0)).normalized())
	m.cara([P.call(u1, v1, he), P.call(u0, v1, he), P.call(u0 + r, vm, he + alto), P.call(u1 - r, vm, he + alto)], col, "teja", (Vector3(n.x, 0, -n.y) * alto + Vector3(0, r, 0)).normalized())
	m.cara([P.call(u1, v0, he), P.call(u1, v1, he), P.call(u1 - r, vm, he + alto)], col.darkened(0.05), "teja", (Vector3(d.x, 0, -d.y) * alto + Vector3(0, r, 0)).normalized())
	m.cara([P.call(u0, v1, he), P.call(u0, v0, he), P.call(u0 + r, vm, he + alto)], col.darkened(0.05), "teja", (Vector3(-d.x, 0, d.y) * alto + Vector3(0, r, 0)).normalized())
	m.cara([P.call(u0, v0, he - 0.02), P.call(u1, v0, he - 0.02), P.call(u1, v1, he - 0.02), P.call(u0, v1, he - 0.02)], Color("5a3b2c"), "liso", Vector3.DOWN)
	m.piso(g, p, h - 0.3, Color("8d8a84"))


# estanques, equipos y casetas sobre los techos planos (se ven desde la vista alta y desde las torres)
func cosas_de_techo(g: Malla.Marco, p: PackedVector2Array, h: float, id: int) -> void:
	rng.seed = id
	var c := Vector2.ZERO
	for q in p:
		c += q
	c /= p.size()
	if area(p) < 60:
		return
	for k in range(1 + rng.randi() % 3):
		var q := c + Vector2(rng.randf_range(-4, 4), rng.randf_range(-4, 4))
		if not Geometry2D.is_point_in_polygon(q, Plano.crecer(p, -1.5)):
			continue
		var w := rng.randf_range(0.8, 2.2)
		m.caja(g, q.x - w / 2, q.y - 0.6, q.x + w / 2, q.y + 0.6, h, h + rng.randf_range(0.7, 1.8), Color("b9b8b2"), "metal")


# los andamios de la Antigua Intendencia (foto de 2022): tubos verticales cada 2,5 m y horizontales cada 2 m a 1,2 m de
# la fachada, tablones en cada nivel, un cierre de obra rojo en la vereda y la estructura de acero sobre el techo
func andamios(g: Malla.Marco, p: PackedVector2Array, H: float) -> void:
	var tubo := Color("b8b8b0")
	for i in p.size():
		var a := p[i]
		var b := p[(i + 1) % p.size()]
		if not lado_a_calle(a, b):
			continue
		var L := a.distance_to(b)
		var s := 0.3
		while s < L:
			for sal in [0.4, 1.5]:
				m.moldura(g, a, b, s, s + 0.05, -0.3, H + 1.5, sal + 0.05, tubo, "metal", sal)
			s += 2.5
		var h := 2.0
		while h < H + 1.6:
			for sal in [0.4, 1.5]:
				m.moldura(g, a, b, 0.2, L - 0.2, h, h + 0.05, sal + 0.05, tubo, "metal", sal)
			m.moldura(g, a, b, 0.2, L - 0.2, h - 0.05, h, 1.45, Color("8a6a3f"), "liso", 0.45)
			h += 2.0
		# el cierre de obra en la vereda: paneles rojos de 2 m
		m.moldura(g, a, b, 0, L, 0.0, 2.0, 2.3, Color("b3342a"), "pintura", 2.25)
	# la estructura de acero sobre el techo (vigas y pilares color minio)
	var c := Vector2.ZERO
	for q in p:
		c += q
	c /= p.size()
	var minio := Color("9c3b22")
	var anillo := Plano.crecer(p, -2.0)
	for i in range(0, anillo.size()):
		var q := anillo[i]
		m.caja(g, q.x - 0.15, q.y - 0.15, q.x + 0.15, q.y + 0.15, H - 0.85, H + 4.2, minio, "metal")
		var r := anillo[(i + 1) % anillo.size()]
		var L2 := q.distance_to(r)
		var d2 := (r - q) / L2
		var o2 := Vector2(d2.y, -d2.x)
		for hh in [H + 1.5, H + 4.0]:
			m.moldura(g, q, r, 0, L2, hh, hh + 0.3, 0.12, minio, "metal", -0.12)


# la Municipalidad (foto «Talca Rathaus (3).jpg», 2018): planta baja vidriada y hundida tras pilares, dos pisos crema con
# ventanas y un paño central más claro, el tercero con ventanal corrido, la losa de techo que vuela con canto ondulado,
# el letrero, una explanada de piedra con baranda y escalera, y la palmera
func municipalidad(p: PackedVector2Array, g: Malla.Marco) -> void:
	var crema := Color("e6e0cf")
	var H := 12.0
	for i in p.size():
		var a := p[i]
		var b := p[(i + 1) % p.size()]
		var L := a.distance_to(b)
		var d := (b - a) / L
		var o := Vector2(d.y, -d.x)
		if o.y > -0.7:  # solo el frente sur (hacia la plaza) lleva la fachada
			m.muro(g, a, b, -0.9, H, crema.darkened(0.1), "liso")
			continue
		var huecos := []
		var pb := PackedVector2Array([Vector2(L * 0.25, 0.9), Vector2(L * 0.75, 0.9), Vector2(L * 0.75, 3.9), Vector2(L * 0.25, 3.9)])
		huecos.append(pb)
		m.derrame(g, a, b, pb, 1.2, Color("7c7a74"), "liso", Color("3a4650"), "vidrio")
		for k in 5:
			var s := L * 0.25 + L * 0.5 * (k + 0.5) / 5
			m.moldura(g, a - o * 1.15, b - o * 1.15, s - 0.04, s + 0.04, 0.9, 3.9, 0.04, Color("40474d"), "metal")
		for s in [L * 0.36, L * 0.64]:
			m.moldura(g, a, b, s - 0.2, s + 0.2, 0.9, 3.9, -0.6, Color("dcd6c4"), "liso", -1.0)
		# el paño central más claro del segundo piso, con su ventanal
		var vc := PackedVector2Array([Vector2(L * 0.38, 5.0), Vector2(L * 0.62, 5.0), Vector2(L * 0.62, 6.6), Vector2(L * 0.38, 6.6)])
		huecos.append(vc)
		ventana(g, a, b, vc, L * 0.5, L * 0.24, 5.0, 6.6, Color("dcdcd8"), Color("34414b"), "clasico")
		for s in [L * 0.1, L * 0.9]:
			for h0 in [1.6, 5.0]:
				var hq := PackedVector2Array([Vector2(s - 0.9, h0), Vector2(s + 0.9, h0), Vector2(s + 0.9, h0 + 1.7), Vector2(s - 0.9, h0 + 1.7)])
				huecos.append(hq)
				ventana(g, a, b, hq, s, 1.8, h0, h0 + 1.7, Color("dcdcd8"), Color("34414b"), "clasico")
		var vb := PackedVector2Array([Vector2(1.0, 8.6), Vector2(L - 1.0, 8.6), Vector2(L - 1.0, 10.6), Vector2(1.0, 10.6)])
		huecos.append(vb)
		m.derrame(g, a, b, vb, 0.3, crema.darkened(0.1), "liso", Color("34414b"), "vidrio")
		var s2 := 1.0
		while s2 <= L - 1.0:
			m.moldura(g, a - o * 0.27, b - o * 0.27, s2 - 0.04, s2 + 0.04, 8.6, 10.6, 0.03, Color("2f3439"), "metal")
			s2 += 1.6
		m.muro_vanos(g, a, b, -0.9, H, huecos, crema, "liso")
		m.moldura(g, a, b, L * 0.25, L * 0.75, 4.0, 7.6, 0.06, crema.lightened(0.05))
		rotulo(g, a, b, L * 0.5, 7.95, 0.06, "I. MUNICIPALIDAD DE TALCA", Color("2a2a2a"), 0.48)
		# la losa que vuela 1,6 m por delante y 1 m a los lados, con canto de plancha ondulada
		m.moldura(g, a, b, -1.0, L + 1.0, 11.0, 11.9, 1.6, Color("eceae4"), "tela")
	m.piso(g, Plano.crecer(p, 1.0), 11.9, Color("9a9890"))
	m.piso(g, Plano.crecer(p, 1.0), 11.0, Color("dedbd2"), "liso", Callable(), true)


# la explanada de la Municipalidad: una plataforma de piedra de 0,8 m entre 1 Norte y la fachada, con baranda de tubo,
# una escalera al medio, maceteros y la palmera canaria de la foto
func plaza_municipal() -> void:
	var y0 := Plano.FACHADA["N"]
	var e := S.E(42, 73) + Plano.ALTO_VEREDA
	var g := Malla.grilla(e)
	# el pavimento de la plaza de OSM entre las veredas y la explanada (baldosa, como las veredas)
	m.piso(g, Plano.rect([26.5, y0, 56.0, 77.2]), 0.0, Color("a9a59c"), "baldosa")
	m.muro(g, Vector2(26.5, y0), Vector2(56, y0), -0.3, 0.0, Color("a9a59c"), "baldosa")
	var piedra := Color("6d6a64")
	m.caja(g, 31.0, 73.6, 56.0, 77.2, 0.0, 0.8, piedra, "granito", Color("b9b4aa"))
	mc.caja(g, 31.0, 73.6, 56.0, 77.2, -0.3, 0.8, piedra)
	for k in 4:
		m.caja(g, 40.0, 72.0 + k * 0.4, 46.0, 72.4 + k * 0.4, 0.0, 0.2 * (k + 1), Color("b9b4aa"), "granito")
		mc.caja(g, 40.0, 72.0 + k * 0.4, 46.0, 72.4 + k * 0.4, -0.3, 0.2 * (k + 1), piedra)
	mc.piso(g, Plano.rect([26.5, y0, 56.0, 77.2]), 0.0, piedra)
	for x0 in [31.0, 46.2]:
		var x1: float = x0 + 9.8 if x0 < 40 else 56.0
		var s: float = x0
		while s <= x1:
			m.caja(g, s - 0.03, 73.7, s + 0.03, 73.76, 0.8, 1.75, Color("c9cbcd"), "metal")
			s += 2.0
		m.caja(g, x0, 73.68, x1, 73.78, 1.7, 1.78, Color("c9cbcd"), "metal")
	for x in [33.0, 53.0]:
		m.caja(g, x - 0.5, 72.3, x + 0.5, 73.3, 0.0, 0.7, Color("f2f0ea"), "liso")
		m.cilindro(g, x, 72.8, 0.45, 0.7, 1.2, Color("3d5d2b"), "liso", 7)
	palmera(g, 43.0, 75.6, 0.8, 11.0)


# una palmera canaria: tronco anillado de 0,45 m, una corona oscura y dieciséis hojas arqueadas
func palmera(g: Malla.Marco, x: float, y: float, h0: float, h: float) -> void:
	var tr := Color("6e5b48")
	var k := 0
	var z := h0
	while z < h - 0.8:
		m.cilindro(g, x, y, 0.45 if k % 2 else 0.5, z, min(z + 0.6, h - 0.8), tr if k % 2 else tr.darkened(0.1), "liso", 8)
		z += 0.6
		k += 1
	m.cilindro(g, x, y, 0.8, h - 0.8, h + 0.2, Color("5d6e34"), "liso", 8)
	var antes := m.solido
	m.solido = false
	for i in 16:
		var t := TAU * i / 16 + 0.2 * (i % 2)
		var c := cos(t)
		var s := sin(t)
		var P := func(dd: float, w: float, zz: float) -> Vector3: return g.V(x + c * dd - s * w, y + s * dd + c * w, zz)
		var col := Color("55803c") if i % 2 else Color("466f33")
		var hh := h + (0.3 if i % 2 else 0.0)
		for n in [Vector3.UP, Vector3.DOWN]:
			var cn: Color = col if n == Vector3.UP else col.darkened(0.2)
			m.cara([P.call(0.4, -0.25, hh), P.call(0.4, 0.25, hh), P.call(2.4, 0.6, hh + 0.7), P.call(2.4, -0.6, hh + 0.7)], cn, "liso", n)
			m.cara([P.call(2.4, -0.6, hh + 0.7), P.call(2.4, 0.6, hh + 0.7), P.call(4.4, 0.2, hh - 0.9), P.call(4.4, -0.2, hh - 0.9)], cn, "liso", n)
	m.solido = antes
