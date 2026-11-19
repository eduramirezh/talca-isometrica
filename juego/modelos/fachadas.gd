# Los edificios que dan a las calles alrededor de la plaza: cada planta de OSM (plaza-osm.json) que tiene un lado a la
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
#   - el Edificio O'Higgins (ex Banco de Talca, 1 Sur con 1 Oriente): «Edificio ohiggins2.jpg» (2025-10-10, CC BY 4.0,
#     ElPabloRN): beige, zócalo alto de piedra gris verdosa, pilastras planas entre ventanas altas, cornisa pesada;
#   - el BCI (1 Sur 732): «Banco de Crédito e Inversiones Talca.jpg» (2024-03-15, CC BY 4.0, ElPabloRN): blanco,
#     neoclásico, el nombre en letras negras en el friso y un frontón con tímpano;
#   - la casa blanca de 1 Poniente 1133, junto a la catedral: fotos de la catedral 00 y 06 (2024, 2017): blanca, zócalo
#     café rojizo, rejas en las ventanas, techo de cuatro aguas rojo con alero.
# Lo demás es genérico y aproximado: los colores (una paleta de fachadas del centro, elegida por el id de OSM), la
# cantidad de ventanas, los locales y sus toldos; los letreros llevan solo los nombres que da OSM (BCI, Oriencoop,
# Chilexpress, AFP Habitat, Banco Santander, cine Plaza), con colores supuestos. El Edificio O'Higgins (ex Banco de
# Talca) y el BCI se dibujan con el lenguaje genérico «clásico», con lo que muestran sus fotos (zócalo con sus juntas,
# pilastras de orden gigante con basa y capitel, arquitrabe y cornisa doble, friso; el pórtico bajo el frontón del BCI
# sale más). La Intendencia lleva además la planta baja almohadillada y la balaustrada del pretil.
# Los genéricos varían por edificio (variacion(), con el id de OSM de semilla: noviembre de 2026): la altura de la
# planta baja, el ritmo de las bahías, el tipo de ventana (rectangular, de arco rebajado, con recercado y clave,
# puertaventana con balconcito, pareada), balcones de fierro al medio o corridos, persianas bajadas, el remate del
# pretil (un paño alzado escalonado o dados), las molduras blancas u oscuras, las pilastras de las esquinas, los
# machones entre los locales, las cortinas metálicas bajadas, los toldos a listas y los letreros de bandera.
extends Node3D

const Malla := preload("res://malla.gd")
const Plano := preload("res://modelos/entorno/plano.gd")
const Suelo := preload("res://modelos/entorno/suelo.gd")

const NO := [114237041, 798980080, 223617018, 191869528]  # la catedral y su torre (catedral.gd), el quiosco, la Tesorería (dentro de los Servicios Públicos)
const PALETA := ["e9dfc6", "efe8d8", "dcc093", "d2b48a", "e5d2ab", "c3c3bb", "dfc6b2", "c9d1cd", "e8d9a6", "d7c9b5"]

# lo propio de cada edificio, por id de OSM (lo que falta sale de sus etiquetas y de valores por omisión): en
# config/fachadas.json, que lee también la página (src/js/52-edificios.js), copiado a juego/datos/ por `make juego`;
# tools/check.py revisa sus claves y sus valores, y especiales() avisa de una clave que spec() no conoce
var ESPECIAL := especiales()
# las claves de config/fachadas.json: las de spec() más el corte de un basamento
const CLAVES := ["estilo", "pisos", "alto", "color", "zocalo", "pb", "toldo", "techo", "marco", "letreros", "zocalo_alto",
	"friso", "fronton", "bahia", "pilastras", "corte_y", "alto_basamento"]


static func especiales() -> Dictionary:
	var ruta := "res://datos/fachadas.json"
	var f := FileAccess.open(ruta, FileAccess.READ)
	if f == null:
		push_error("fachadas.gd: falta %s: corra `make juego`" % ruta)
		return {}
	var d: Variant = JSON.parse_string(f.get_as_text())
	var out := {}
	if not d is Dictionary:
		return out
	for k in d:
		if not String(k).begins_with("w"):
			continue
		var e: Dictionary = d[k]
		for c in e:
			if not c in CLAVES:
				push_warning("fachadas.gd: %s: clave desconocida «%s» (config/fachadas.json)" % [k, c])
		if e.has("pisos"):
			e["pisos"] = int(e["pisos"])  # JSON da números de punto flotante
		out[int(String(k).substr(1))] = e
	return out

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
			if not (da_a_la_calle(pz) or ESPECIAL.has(t[0])):
				continue
			var esp: Dictionary = ESPECIAL.get(t[0], {})
			if esp.has("corte_y"):
				# el GORE: un basamento de tres pisos a lo largo de 1 Norte y la torre detrás (el hito de la página)
				var y: float = esp["corte_y"]
				for r in Geometry2D.intersect_polygons(pz, Plano.rect([-500, -500, 500, y])):
					var e2 := esp.duplicate()
					e2["alto"] = esp["alto_basamento"]
					e2["pisos"] = 3
					plantas.append([t[0], r, t[2], e2])
				for r in Geometry2D.intersect_polygons(pz, Plano.rect([-500, y, 500, 500])):
					plantas.append([t[0], r, t[2], esp])
				continue
			plantas.append([t[0], pz, t[2], esp])


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
			# «hitos»: la página modela el GORE, la Municipalidad y los Servicios Públicos como hitos
			out.append({"poligono": r[0], "capas": ["edificios", "ciudad", "hitos"]})
	# la plaza de la Municipalidad (OSM w813330084): sin los árboles ni el suelo de la página, y sin la terraza, la
	# palmera y la bandera del hito; queda el Memorial Firma de la Independencia (el hito memorial-firma, en 44,9, 71,7)
	for r in [[26.5, 69.0, 43.9, 77.2], [45.9, 69.0, 56.0, 77.2], [43.9, 69.0, 45.9, 71.25], [43.9, 72.15, 45.9, 77.2]]:
		out.append({"poligono": Plano.rect(r), "capas": ["ciudad", "patios", "arboles", "autos", "suelo", "usos", "hitos"]})
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
		"marco": "e8e6e0", "letreros": [], "zocalo_alto": -1.0, "friso": "", "fronton": false, "bahia": 0.0, "pilastras": false}
	for k in esp:
		sp[k] = esp[k]
	if sp["estilo"] == "torre" or sp["estilo"] == "vidrio":
		sp["pb"] = "vitrinas" if sp["estilo"] == "torre" else "vidrio"
	variacion(sp, id, esp)
	return sp


# lo que cambia de un edificio genérico a otro (claves v_*): la altura de la planta baja, el tipo de ventana, el
# ritmo de las bahías, los balcones, el remate del pretil, el color de las molduras, las pilastras de las esquinas,
# las cortinas cerradas y los letreros de bandera. La semilla es el id de OSM: el mismo edificio sale igual en cada
# corrida y en cada una de sus caras. Lo aproximado: todo; es el repertorio de las fachadas del centro de Talca
# (comercio de dos pisos de los años 1930–1960, con ventanas de recercado o de arco rebajado, balcones de fierro y
# pretiles con un paño alzado al medio), no lo que tiene cada edificio. Los que tienen fotos (config/fachadas.json con
# friso, pilastras o zócalo alto, y los estilos propios) no varían.
func variacion(sp: Dictionary, id: int, esp: Dictionary) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = id * 7919 + 1742
	# se sacan siempre todos los números, en el mismo orden, aunque no se usen
	var dhg := r.randf_range(-0.4, 0.5)
	var tipos := ["rect", "rect", "rebajado", "alta", "par", "recercado"] if sp["estilo"] == "comercial" else ["recercado", "recercado", "rebajado", "rect", "alta"]
	var vent: String = tipos[r.randi() % tipos.size()]
	var vh := r.randf_range(0.56, 0.7)
	var bal := r.randf()
	var remate := r.randi() % 3
	var pretil := r.randf_range(0.7, 1.25)
	var trim: String = ["f1ede3", "f4f1ea", "", "", "8f8778"][r.randi() % 5]
	var esq := r.randf() < 0.5
	var cortina := r.randf_range(0.0, 0.45)
	var bandera := r.randf() < 0.45
	var ritmo := r.randf_range(0.85, 1.2)
	var pilares: String = ["", "", "8a8780", "5e5a55", "b7b1a5"][r.randi() % 5]
	var gen: bool = sp["estilo"] in ["comercial", "clasico"] and not (esp.has("friso") or esp.has("pilastras") or esp.has("zocalo_alto") or esp.has("bahia"))
	if not gen:
		sp.merge({"v_dhg": 0.0, "v_vent": "rect", "v_vh": 0.62, "v_balcon": 0, "v_remate": 0, "v_pretil": 0.9, "v_trim": "",
			"v_esquinas": sp["estilo"] == "colonial", "v_cortina": 0.0, "v_bandera": false, "v_ritmo": 1.0, "v_pilares": "", "v_gen": false})
		if sp["estilo"] == "intendencia":
			sp["v_pretil"] = 1.1  # la balaustrada sobre la cornisa (foto de 2022, sobre los andamios)
		return
	sp.merge({"v_dhg": dhg, "v_vent": vent, "v_vh": vh, "v_balcon": 0 if bal < 0.55 else (1 if bal < 0.85 else 2),
		"v_remate": remate, "v_pretil": pretil, "v_trim": trim, "v_esquinas": esq, "v_cortina": cortina if sp["pb"] == "vitrinas" else 0.0,
		"v_bandera": bandera, "v_ritmo": ritmo, "v_pilares": pilares, "v_gen": true})


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
			if sp["estilo"] == "deco":
				m.moldura(g, a, b, 0, a.distance_to(b), -0.9, 1.1, 0.08, Color("6e6c66"), "granito")
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
	var d := (b - a) / L
	var o := Vector2(d.y, -d.x)  # hacia afuera
	var estilo: String = sp["estilo"]
	var H: float = sp["alto"]
	var n: int = max(1, sp["pisos"])
	var col := Color(sp["color"])
	var marco := Color(sp["marco"])
	var zocalo: Color = Color(sp["zocalo"]) if sp["zocalo"] != "" else col.darkened(0.3)
	# las molduras (bandas, cornisa, recercados): blancas, oscuras o un tono más claro que el muro
	var trim: Color = Color(sp["v_trim"]) if sp["v_trim"] != "" else col.lightened(0.07)
	if estilo == "vidrio":
		muro_cortina(g, a, b, H, n)
		return
	var pretil: float = sp["v_pretil"]
	var hg: float = {"comercial": 3.9, "clasico": 4.0, "deco": 4.3, "torre": 4.2, "moderno": 4.2, "colonial": 3.8, "intendencia": 4.6}.get(estilo, 3.9)
	if sp["v_gen"]:
		# la planta baja más alta o más baja, sin dejar pisos de menos de 2,7 m
		hg = clampf(hg + sp["v_dhg"], 3.3, max(3.3, H - pretil - (n - 1) * 2.7))
	if n == 1:
		hg = H - pretil
	var hu: float = (H - hg - pretil) / max(1, n - 1)
	var bahia: float = {"comercial": 4.2, "clasico": 3.6, "deco": 3.4, "torre": 3.3, "moderno": 3.0, "colonial": 3.4, "intendencia": 3.3}.get(estilo, 3.6)
	bahia *= sp["v_ritmo"]
	if sp["bahia"] > 0:
		bahia = sp["bahia"]
	var nb: int = max(1, roundi(L / bahia))
	var bw := L / nb
	var huecos := []
	var vidrio := Color("2e3a44")
	var tipo: String = sp["v_vent"]
	# los pisos de arriba: una ventana por bahía (en el moderno, una banda corrida)
	for k in range(1, n):
		var hf: float = hg + (k - 1) * hu
		if estilo == "moderno":
			var hq := PackedVector2Array([Vector2(0.4, hf + 0.85), Vector2(L - 0.4, hf + 0.85), Vector2(L - 0.4, hf + hu - 0.45), Vector2(0.4, hf + hu - 0.45)])
			m.derrame(g, a, b, hq, 0.12, col.darkened(0.2), "liso", vidrio, "vidrio")
			huecos.append(hq)
			var s := 0.4 + 1.5
			while s < L - 0.6:
				m.moldura(g, a - o * 0.1, b - o * 0.1, s - 0.03, s + 0.03, hf + 0.85, hf + hu - 0.45, 0.03, Color("3c3f42"), "metal")
				s += 1.5
			continue
		# el balcón corrido del primer piso, de esquina a esquina (una losa con baranda)
		if k == 1 and sp["v_balcon"] == 2 and tipo != "alta":
			balcon(g, a, b, 0.4, L - 0.4, hf + 0.14, 0.75, trim)
		for j in nb:
			var s: float = (j + 0.5) * bw
			var w: float = clampf(bw * (0.42 if estilo == "colonial" else 0.5), 0.9, 2.2)
			var vh: float = hu * (sp["v_vh"] if estilo != "torre" else 0.55)
			var h0: float = hf + (0.95 if estilo != "torre" else 1.0)
			if tipo == "alta":
				# puertaventana de piso a dintel, con un balconcito de fierro
				w = clampf(bw * 0.4, 0.9, 1.5)
				h0 = hf + 0.14
				vh = hu - 0.14 - 0.55
			var hq: PackedVector2Array
			if estilo == "colonial" or estilo == "intendencia":
				hq = Malla.arco(s, w, h0, h0 + vh - w / 2 * 0.35, w / 2 * 0.35, 6)
			elif tipo == "rebajado":
				hq = Malla.arco(s, w, h0, h0 + vh - w * 0.14, w * 0.14, 4)
			else:
				hq = PackedVector2Array([Vector2(s - w / 2, h0), Vector2(s + w / 2, h0), Vector2(s + w / 2, h0 + vh), Vector2(s - w / 2, h0 + vh)])
			if tipo == "par" and w > 1.3:
				# dos ventanas angostas por bahía, con un machón entre ellas
				for sg in [-1.0, 1.0]:
					var sj: float = s + sg * w * 0.3
					var wj: float = w * 0.46
					var hj := PackedVector2Array([Vector2(sj - wj / 2, h0), Vector2(sj + wj / 2, h0), Vector2(sj + wj / 2, h0 + vh), Vector2(sj - wj / 2, h0 + vh)])
					huecos.append(hj)
					ventana(g, a, b, hj, sj, wj, h0, h0 + vh, marco, vidrio, estilo)
				m.moldura(g, a, b, s - w / 2 - 0.15, s + w / 2 + 0.15, h0 + vh + 0.08, h0 + vh + 0.24, 0.1, trim)
			else:
				huecos.append(hq)
				ventana(g, a, b, hq, s, w, h0, h0 + vh, marco, vidrio, estilo)
				if (sp["v_gen"] or estilo == "torre") and rng.randf() < 0.3:
					# la persiana enrollable bajada a medias o casi entera, con su cajón sobre el dintel
					var z: float = h0 + vh * rng.randf_range(0.15, 0.7)
					var pc := Color(["d8d2c4", "efece4", "8a6f55", "b9b4a8"][rng.randi() % 4])
					m.panel(g, a - o * 0.15, b - o * 0.15, s - w / 2, s + w / 2, z, h0 + vh, 0.0, pc, "metal")
					m.panel(g, a - o * 0.15, b - o * 0.15, s - w / 2, s + w / 2, z, z + 0.05, 0.005, pc.darkened(0.3), "metal")
			if tipo == "recercado" and estilo in ["comercial", "clasico"]:
				# el recercado: jambas y un dintel con su cornisita y la clave al medio
				for sg in [-1.0, 1.0]:
					var e0: float = s + w / 2 if sg > 0 else s - w / 2 - 0.2
					m.panel(g, a, b, e0, e0 + 0.2, h0 - 0.1, h0 + vh + 0.15, 0.035, trim)
				m.moldura(g, a, b, s - w / 2 - 0.3, s + w / 2 + 0.3, h0 + vh + 0.15, h0 + vh + 0.4, 0.12, trim)
				m.moldura(g, a, b, s - 0.14, s + 0.14, h0 + vh - 0.05, h0 + vh + 0.3, 0.08, trim.darkened(0.06))
			elif tipo == "rebajado" and estilo in ["comercial", "clasico"]:
				m.moldura(g, a, b, s - 0.13, s + 0.13, h0 + vh - 0.1, h0 + vh + 0.25, 0.07, trim)
			if tipo == "alta" and estilo in ["comercial", "clasico"]:
				balcon(g, a, b, s - w / 2 - 0.25, s + w / 2 + 0.25, hf + 0.14, 0.4, trim)
				m.moldura(g, a, b, s - w / 2 - 0.2, s + w / 2 + 0.2, h0 + vh + 0.05, h0 + vh + 0.25, 0.12, trim)
			elif k == 1 and sp["v_balcon"] == 1 and j == nb / 2 and nb >= 3:
				# un balcón al medio, sobre la entrada
				balcon(g, a, b, s - bw / 2 + 0.3, s + bw / 2 - 0.3, hf + 0.14, 0.85, trim)
			if estilo == "torre":
				# balcón: losa que sale 0,9 m y una baranda de fierro
				m.moldura(g, a, b, s - w / 2 - 0.5, s + w / 2 + 0.5, hf - 0.02, hf + 0.16, 0.9, col.darkened(0.08))
				baranda(g, a, b, s - w / 2 - 0.5, s + w / 2 + 0.5, hf + 0.16, 0.9)
			elif estilo == "deco":
				# el cuadrado escalonado del antepecho (foto «Detalle…», 2022), en un paño hundido más oscuro
				m.panel(g, a, b, s - w / 2, s + w / 2, h0 - 1.15, h0 - 0.2, 0.004, col.darkened(0.08))
				m.moldura(g, a, b, s - 0.32, s + 0.32, h0 - 1.0, h0 - 0.36, 0.04, col.lightened(0.08))
				m.moldura(g, a, b, s - 0.2, s + 0.2, h0 - 0.88, h0 - 0.48, 0.08, col.lightened(0.14))
			elif estilo == "intendencia" or estilo == "clasico" and tipo == "rect":
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
			# la cortina metálica: bajada entera (un local cerrado) o a medias
			var cr := rng.randf()
			if cr < sp["v_cortina"] * 1.6:
				var z0: float = 0.2 if cr < sp["v_cortina"] else lerpf(0.9, hg - 1.6, rng.randf())
				cortina(g, a - o * 0.1, b - o * 0.1, x0, x1, z0, hg - 1.1)
			j += 1
		if sp["v_pilares"] != "":
			# los machones entre los locales, enchapados en piedra o pintados de otro color
			for jj in range(0, nb + 1):
				var sj: float = jj * bw
				m.moldura(g, a, b, max(0.0, sj - 0.35), min(L, sj + 0.35), 0.0, hg - 1.1, 0.05, Color(sp["v_pilares"]), "granito")
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
			else:
				# una franja clara al medio del letrero, que de lejos se lee como el texto
				m.panel(g, a, b, s0 + (s1 - s0) * 0.2, s1 - (s1 - s0) * 0.2, hg - 0.68, hg - 0.52, 0.105, fondo.lightened(0.55) if fondo.get_luminance() < 0.5 else fondo.darkened(0.6), "pintura")
			if toldo != "" or rng.randf() < 0.3:
				var tc := Color(toldo) if toldo != "" else Color(["7a2e26", "2f5e3e", "3a4f7a", "c9a227"][rng.randi() % 4])
				toldo_(g, a, b, s0 + 0.1, s1 - 0.1, hg - 1.05, tc, rng.randf() < 0.4)
			if sp["v_bandera"] and rng.randf() < 0.6 and n > 1 and sp["v_balcon"] == 0 and tipo != "alta":
				letrero_bandera(g, a, b, s1 - 0.3, hg + 0.25, fondo)
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
				if estilo == "deco" and w > 1.8:
					# tres puertas vidriadas de marco oscuro (la entrada de los Servicios Públicos)
					for kk in 3:
						var sk: float = s - w / 2 + w * (kk + 0.5) / 3.0
						m.panel(g, a - o * 0.34, b - o * 0.34, sk - w / 6 + 0.1, sk + w / 6 - 0.1, 0.1, 2.7, 0.01, Color("34414b"), "vidrio")
						m.panel(g, a - o * 0.34, b - o * 0.34, sk - 0.03, sk + 0.03, 0.1, 2.7, 0.02, Color("2a2622"), "metal")
				elif estilo != "deco":
					# las dos hojas de madera con sus tableros (el portón de la casa colonial, la puerta de los clásicos)
					var w2: float = 1.5 if estilo == "colonial" else w
					for sg in [-1.0, 1.0]:
						var c0: float = s + (0.0 if sg > 0 else -w2 / 2)
						for hh in [[0.25, 1.15], [1.35, 2.25]]:
							m.panel(g, a - o * 0.35, b - o * 0.35, c0 + 0.12, c0 + w2 / 2 - 0.12, hh[0], hh[1], 0.02, Color("5c4330"), "pintura")
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
	var hz: float = sp["zocalo_alto"] if sp["zocalo_alto"] > 0 else (0.2 if pb == "vitrinas" else 0.75)
	if hz < 1.5:
		m.moldura(g, a, b, 0, L, -0.9, hz, 0.05, zocalo, "liso")
	else:
		# un zócalo alto de piedra (el Edificio O'Higgins): una capa 12 cm delante del muro, con los mismos vanos
		var o4 := o * 0.12
		var hz_huecos := huecos.filter(func(hq): return hq[0].y < hz)
		m.superficie(g, a + o4, b + o4, PackedVector2Array([Vector2(0, -0.9), Vector2(L, -0.9), Vector2(L, hz), Vector2(0, hz)]), hz_huecos, zocalo, "granito")
		m.moldura(g, a, b, 0, L, hz - 0.05, hz + 0.1, 0.16, zocalo.lightened(0.08), "granito")
		for hq in hz_huecos:
			m.derrame(g, a + o4, b + o4, hq, 0.13, zocalo.darkened(0.1), "granito")
		# las juntas horizontales de la piedra, entre los vanos
		var hj := 0.55
		while hj < hz - 0.3:
			franja(g, a + o4, b + o4, hj, hj + 0.04, 0.006, zocalo.darkened(0.22), huecos)
			hj += 0.6
	if estilo == "intendencia":
		# la planta baja almohadillada (foto de 2022): juntas horizontales cada 0,5 m entre los vanos
		var hj := 1.0
		while hj < hg - 0.3:
			franja(g, a, b, hj, hj + 0.05, 0.006, col.darkened(0.16), huecos)
			hj += 0.5
	if sp["friso"] != "" and L > 12:
		rotulo(g, a, b, L / 2, H - pretil - 0.75, 0.31, sp["friso"], Color("1c1c1c"), 0.55)
	if sp["fronton"] and L > 12:
		# el frontón al medio, con su tímpano (foto del BCI, 2024)
		var w2: float = min(9.0, L * 0.4)
		var P := func(ss: float, hh: float, sal: float) -> Vector3:
			var q: Vector2 = a + d * ss + o * sal
			return g.V(q.x, q.y, hh)
		for sal in [0.32, -1.5]:
			m.cara([P.call(L / 2 - w2 / 2, H, sal), P.call(L / 2 + w2 / 2, H, sal), P.call(L / 2, H + 1.6, sal)], col, "liso", g.N(o.x, o.y) if sal > 0 else -g.N(o.x, o.y))
		for sg in [-1.0, 1.0]:
			m.cara([P.call(L / 2 + sg * w2 / 2 * 1.05, H - 0.05, 0.45), P.call(L / 2, H + 1.75, 0.45), P.call(L / 2, H + 1.75, -1.6), P.call(L / 2 + sg * w2 / 2 * 1.05, H - 0.05, -1.6)],
				col.darkened(0.1), "liso", (g.N(d.x * sg, d.y * sg) * 1.6 + Vector3.UP * w2 / 2).normalized())
		# la cornisa horizontal bajo el tímpano
		m.moldura(g, a, b, L / 2 - w2 / 2 * 1.05, L / 2 + w2 / 2 * 1.05, H - 0.1, H + 0.12, 0.45, col.lightened(0.05))
	if estilo in ["clasico", "intendencia", "colonial", "comercial"]:
		for k in range(1, n):
			var hf: float = hg + (k - 1) * hu
			m.moldura(g, a, b, 0, L, hf - 0.1, hf + 0.12, 0.08, trim)
	var hc := H - pretil  # la cornisa
	if estilo != "moderno":
		m.moldura(g, a, b, -0.05, L + 0.05, hc - 0.1, hc + 0.25, 0.3 if estilo != "torre" else 0.15, trim)
		if estilo in ["clasico", "intendencia"] or sp["v_remate"] > 0:
			# el arquitrabe: una segunda moldura bajo la cornisa, que la hace más pesada
			if sp["friso"] == "":
				m.moldura(g, a, b, 0, L, hc - 0.42, hc - 0.28, 0.12, trim.darkened(0.04))
			m.moldura(g, a, b, -0.05, L + 0.05, hc + 0.25, hc + 0.36, 0.38 if estilo != "torre" else 0.2, trim.lightened(0.04))
	m.moldura(g, a, b, 0, L, H - 0.12, H, 0.08, trim.lightened(0.03))
	if estilo == "intendencia":
		balaustrada(g, a, b, hc + 0.36, H - 0.12, nb, bw, col)
	elif sp["v_remate"] == 1 and L > 6:
		# un paño alzado al medio del pretil, escalonado, con un paño hundido (la fecha o el nombre de la casa)
		var wr: float = min(L * 0.35, 6.0)
		m.moldura(g, a, b, L / 2 - wr / 2, L / 2 + wr / 2, H - 0.12, H + 0.75, 0.08, col)
		m.moldura(g, a, b, L / 2 - wr / 4, L / 2 + wr / 4, H + 0.75, H + 1.15, 0.08, col)
		m.moldura(g, a, b, L / 2 - wr / 4 - 0.08, L / 2 + wr / 4 + 0.08, H + 1.15, H + 1.27, 0.14, trim)
		m.moldura(g, a, b, L / 2 - wr / 2 - 0.08, L / 2 + wr / 2 + 0.08, H + 0.7, H + 0.82, 0.14, trim)
		m.panel(g, a, b, L / 2 - wr / 2 + 0.35, L / 2 + wr / 2 - 0.35, H + 0.05, H + 0.55, 0.085, col.darkened(0.1))
	elif sp["v_remate"] == 2:
		# dados sobre el pretil, uno en cada eje de bahía
		for j in range(0, nb + 1):
			var s: float = clampf(j * bw, 0.25, L - 0.25)
			m.moldura(g, a, b, s - 0.25, s + 0.25, H - 0.12, H + 0.45, 0.14, trim)
	if sp["v_esquinas"] and estilo in ["comercial", "clasico", "colonial"]:
		# pilastras en las dos esquinas de la fachada, del zócalo a la cornisa
		for e in [[0.0, 0.55], [L - 0.55, L]]:
			m.moldura(g, a, b, e[0], e[1], hz, hc - 0.1, 0.07, trim)
	if estilo == "deco":
		# los machones dobles escalonados entre las bahías, que suben 1,2 m sobre el pretil (Servicios Públicos), con un
		# tercer escalón angosto en los altos
		for j in range(0, nb + 1):
			var s: float = j * bw
			var alto := H + (1.2 if j % 2 == 0 else 0.4)
			m.moldura(g, a, b, max(0.0, s - 0.42), min(L, s + 0.42), hg - 0.3, alto, 0.14, col.lightened(0.10))
			m.moldura(g, a, b, max(0.0, s - 0.25), min(L, s + 0.25), hg - 0.3, alto - 0.3, 0.3, col.lightened(0.16))
			if j % 2 == 0:
				m.moldura(g, a, b, max(0.0, s - 0.12), min(L, s + 0.12), alto - 0.3, alto + 0.35, 0.22, col.lightened(0.16))
	if estilo == "intendencia" or estilo == "clasico" and (n <= 3 or sp["pilastras"]):
		# pilastras en cada eje, con basa y capitel; las del O'Higgins y el BCI, de orden gigante desde el zócalo
		var gigante: bool = sp["pilastras"] or sp["fronton"]
		var hp0: float = hz + 0.1 if gigante else hg
		var hp1: float = hc - 0.42  # bajo el arquitrabe
		if sp["friso"] != "":
			hp1 = H - pretil - 1.1
		var hw := 0.25 if gigante and pb == "ventanas" else 0.3
		var w2: float = min(9.0, L * 0.4)
		for j in range(0, nb + 1):
			var s: float = j * bw
			var sal := 0.1
			if sp["fronton"] and abs(s - L / 2) < w2 / 2 + 0.5:
				sal = 0.2  # el pórtico bajo el frontón sale más
			m.moldura(g, a, b, max(0.0, s - hw), min(L, s + hw), hp0, hp1, sal, col.lightened(0.05))
			m.moldura(g, a, b, max(0.0, s - hw - 0.1), min(L, s + hw + 0.1), hp1 - 0.3, hp1, sal + 0.07, trim)
			if gigante:
				m.moldura(g, a, b, max(0.0, s - hw - 0.08), min(L, s + hw + 0.08), hp0, hp0 + 0.35, sal + 0.05, trim.darkened(0.05))


# una banda horizontal (junta, moldura) de h0 a h1 a lo largo de a -> b que se corta en los vanos que cruza
func franja(g: Malla.Marco, a: Vector2, b: Vector2, h0: float, h1: float, sal: float, col: Color, huecos: Array) -> void:
	var L := a.distance_to(b)
	var tramos := [[0.0, L]]
	for hq in huecos:
		var s0 := INF
		var s1 := -INF
		var z0 := INF
		var z1 := -INF
		for p in hq:
			s0 = min(s0, p.x); s1 = max(s1, p.x); z0 = min(z0, p.y); z1 = max(z1, p.y)
		if z1 < h0 or z0 > h1:
			continue
		var nuevos := []
		for t in tramos:
			if s1 <= t[0] or s0 >= t[1]:
				nuevos.append(t)
				continue
			if s0 - 0.05 > t[0]:
				nuevos.append([t[0], s0 - 0.05])
			if s1 + 0.05 < t[1]:
				nuevos.append([s1 + 0.05, t[1]])
		tramos = nuevos
	for t in tramos:
		if t[1] - t[0] > 0.1:
			m.panel(g, a, b, t[0], t[1], h0, h1, sal, col)


# un balcón de fierro: la losa bajo h, que sale sal m, el pasamanos y barrotes cada 16 cm al frente y a los lados
func balcon(g: Malla.Marco, a: Vector2, b: Vector2, s0: float, s1: float, h: float, sal: float, losa: Color) -> void:
	var c := Color(0.17, 0.18, 0.19)
	m.moldura(g, a, b, s0, s1, h - 0.16, h, sal, losa)
	m.moldura(g, a, b, s0, s1, h + 0.92, h + 0.97, sal, c, "metal", sal - 0.05)
	m.moldura(g, a, b, s0, s1, h + 0.05, h + 0.09, sal - 0.01, c, "metal", sal - 0.04)
	var x := s0 + 0.08
	while x < s1 - 0.04:
		m.panel(g, a, b, x - 0.02, x + 0.02, h, h + 0.92, sal - 0.025, c, "metal")
		x += 0.16
	var d := (b - a).normalized()
	var o := Vector2(d.y, -d.x)
	for e in [[s0 + 0.025, -1.0], [s1 - 0.025, 1.0]]:
		var a2: Vector2 = a + d * e[0]
		var b2: Vector2 = a2 + o * sal
		var sg: float = e[1]
		m.moldura(g, a2, b2, 0.0, sal, h + 0.92, h + 0.97, 0.025, c, "metal", -0.025)
		var y := 0.12
		while y < sal - 0.03:
			if sg > 0:
				m.panel(g, b2, a2, sal - y - 0.02, sal - y + 0.02, h, h + 0.92, 0.026, c, "metal")
			else:
				m.panel(g, a2, b2, y - 0.02, y + 0.02, h, h + 0.92, 0.026, c, "metal")
			y += 0.16


# la cortina metálica de un local, bajada de z1 a z0 delante del vidrio: un paño gris con sus pliegues y la barra de abajo
func cortina(g: Malla.Marco, a: Vector2, b: Vector2, x0: float, x1: float, z0: float, z1: float) -> void:
	var c := Color(0.62, 0.63, 0.63)
	m.panel(g, a, b, x0 + 0.02, x1 - 0.02, z0, z1, 0.0, c, "metal")
	var h := z1 - 0.3
	while h > z0 + 0.2:
		m.panel(g, a, b, x0 + 0.02, x1 - 0.02, h, h + 0.04, 0.008, c.darkened(0.25), "metal")
		h -= 0.45
	m.panel(g, a, b, x0 + 0.02, x1 - 0.02, z0, z0 + 0.08, 0.012, Color(0.3, 0.31, 0.32), "metal")


# un letrero de bandera: una caja angosta perpendicular al muro, en s, desde h, con un paño claro en cada cara
func letrero_bandera(g: Malla.Marco, a: Vector2, b: Vector2, s: float, h: float, fondo: Color) -> void:
	var d := (b - a).normalized()
	var o := Vector2(d.y, -d.x)
	var a2 := a + d * s
	var b2 := a2 + o * 1.1
	m.moldura(g, a2, b2, 0.0, 0.25, h + 0.35, h + 0.45, 0.02, Color(0.2, 0.21, 0.22), "metal", -0.02)  # la ménsula
	m.moldura(g, a2, b2, 0.15, 1.05, h, h + 0.8, 0.05, fondo, "pintura", -0.05)
	var claro := fondo.lightened(0.6) if fondo.get_luminance() < 0.5 else fondo.darkened(0.55)
	m.panel(g, a2, b2, 0.3, 0.9, h + 0.3, h + 0.5, 0.052, claro, "pintura")
	m.panel(g, b2, a2, 0.15, 0.75, h + 0.3, h + 0.5, 0.052, claro, "pintura")


# la balaustrada del pretil de la Intendencia: dados en cada eje, pasamanos y balaustres (paños claros sobre un fondo
# en sombra; de cerca se leen como balaustres, con 2 triángulos cada uno)
func balaustrada(g: Malla.Marco, a: Vector2, b: Vector2, h0: float, h1: float, nb: int, bw: float, col: Color) -> void:
	var L := a.distance_to(b)
	m.panel(g, a, b, 0.0, L, h0, h1 - 0.12, 0.004, col.darkened(0.35))
	for j in range(0, nb + 1):
		var s: float = clampf(j * bw, 0.3, L - 0.3)
		m.moldura(g, a, b, s - 0.3, s + 0.3, h0, h1 + 0.1, 0.12, col.lightened(0.06))
		if j == nb:
			break
		var x := s + 0.5
		while x < (j + 1) * bw - 0.5:
			m.panel(g, a, b, x - 0.07, x + 0.07, h0 + 0.05, h1 - 0.17, 0.05, col.lightened(0.04))
			x += 0.3
	m.moldura(g, a, b, 0.0, L, h1 - 0.17, h1, 0.12, col.lightened(0.06))


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


# un toldo de lona inclinado, de s0 a s1, colgado a h, que sale 1,3 m y baja 0,6 m, con faldón (liso o a listas)
func toldo_(g: Malla.Marco, a: Vector2, b: Vector2, s0: float, s1: float, h: float, col: Color, rayado := false) -> void:
	var L := a.distance_to(b)
	var d := (b - a) / L
	var o := Vector2(d.y, -d.x)
	var P := func(s: float, sal: float, hh: float) -> Vector3:
		var q: Vector2 = a + d * s + o * sal
		return g.V(q.x, q.y, hh)
	var antes := m.solido
	m.solido = false
	# rayado: listas de 0,5 m del color y blancas, a lo largo
	var k := maxi(1, roundi((s1 - s0) / 0.5)) if rayado else 1
	for i in k:
		var t0: float = lerpf(s0, s1, float(i) / k)
		var t1: float = lerpf(s0, s1, float(i + 1) / k)
		var c: Color = col if i % 2 == 0 else Color("efebe0")
		m.cara([P.call(t0, 0.02, h), P.call(t1, 0.02, h), P.call(t1, 1.3, h - 0.6), P.call(t0, 1.3, h - 0.6)], c, "tela", g.N(o.x, o.y, 2.2))
		m.cara([P.call(t0, 1.3, h - 0.6), P.call(t1, 1.3, h - 0.6), P.call(t1, 1.3, h - 0.85), P.call(t0, 1.3, h - 0.85)], c.darkened(0.1), "tela", g.N(o.x, o.y))
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
	bandera(g, 33.0, 74.5, 0.8, 10.0)


# el asta con la bandera de Chile (foto de 2018: a la izquierda de la entrada)
func bandera(g: Malla.Marco, x: float, y: float, h0: float, alto: float) -> void:
	m.cilindro(g, x, y, 0.06, h0, h0 + alto, Color("dcdcd8"), "metal", 8)
	var t := h0 + alto - 0.2
	var paño := func(x0: float, x1: float, z0: float, z1: float, c: Color) -> void:
		for n in [Vector3(0, 0, 1), Vector3(0, 0, -1)]:
			m.cara([g.V(x + x0, y, t - z1), g.V(x + x1, y, t - z1), g.V(x + x1, y, t - z0), g.V(x + x0, y, t - z0)], c, "tela", n)
	paño.call(0.1, 0.85, 0.0, 0.75, Color("2b4c8c"))
	paño.call(0.85, 2.3, 0.0, 0.75, Color("f2f0ea"))
	paño.call(0.1, 2.3, 0.75, 1.5, Color("c8322b"))


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
