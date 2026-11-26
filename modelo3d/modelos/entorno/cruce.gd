# Un cruce de calles medidas en fotos, de cerca (modelos/perfiles.gd lo arma): lo que pipeline/perfiles.py calcula de
# config/cruces.json en data/cruces.json, sin medidas propias: el asfalto entre las esquinas, las esquinas con su
# solera, vereda y pasto hasta los cierros, la isla de un enlace con su achurado, las líneas de detención, los cruces
# peatonales y las flechas, y el mobiliario (mobiliario.gd: semáforos, postes y cables, letreros, banderas, palmeras,
# cierros y señales). Cada polígono va apoyado en el relieve (Malla.capa), a la altura que le pone el pipeline.
extends RefCounted

const Malla := preload("res://malla.gd")
const Mob := preload("res://modelos/entorno/mobiliario.gd")
const Arboles := preload("res://modelos/plaza/arboles.gd")

const K := Mob.K
const CAPAS := ["suelo", "usos", "patios", "autos"]
const H_PINTURA := 0.132
const H_SOLERA := 0.27
const SUELO := {   # tipo -> [color, material]
	"calzada": ["asfalto", "asfalto"], "vereda": ["vereda", "hormigon"], "pasto": ["pasto", "liso"],
	"tierra": ["tierra", "liso"], "solera": ["solera", "granito"], "solera-amarilla": ["amarillo", "pintura"],
}

var clave: String
var D := {}
var S: RefCounted  # el relieve (suelo.gd), que pone perfiles.gd
var G := Malla.grilla()
var arboles: Arboles  # las especies de la plaza: las de la arboleda del mapa (arboleda.gd), que perfiles.gd le pasa


func _init(k: String, d: Dictionary) -> void:
	clave = k
	D = d


static func pol(r: Array) -> PackedVector2Array:
	return Malla.pol(r)


# los puntos de los que depende (todo el cruce se arma junto, cuando están sus teselas)
func puntos() -> Array:
	var out := []
	for s in D["suelo"]:
		var p := pol(s[2])
		for i in range(0, p.size(), maxi(1, p.size() / 6)):
			out.append(p[i])
	return out


func recortes() -> Array:
	var out := []
	for s in D["suelo"]:
		var p := pol(s[2])
		if p.size() > 4 and absf(Malla.area(p)) > 4.0:
			if Geometry2D.is_polygon_clockwise(p):
				p.reverse()
			out.append({"poligono": p, "capas": CAPAS})
	# the furniture the page draws too (src/js/hitos/cruces.js: palms, billboards, banners, fences), which this one
	# draws up close: its footprint, out of the «hitos» layer (an object goes by the centre of its plan, a fence's
	# walls by theirs)
	for o in D["objetos"]:
		if o[0] == "cerco":
			var l := pol(o[4])
			for i in l.size() - 1:
				var d := (l[i + 1] - l[i]).normalized()
				var n := Vector2(-d.y, d.x) * 0.8
				out.append({"poligono": PackedVector2Array([l[i] - n - d * 0.3, l[i + 1] - n + d * 0.3, l[i + 1] + n + d * 0.3, l[i] + n - d * 0.3]), "capas": ["hitos"]})
		elif o[0] in ["palmera", "letrero", "bandera"]:
			var r := 2.5 if o[0] == "palmera" else float(o[4].get("ancho", 2.0)) / 2.0 + 0.8
			var c := Vector2(o[1], o[2])
			out.append({"poligono": PackedVector2Array([c + Vector2(-r, -r), c + Vector2(r, -r), c + Vector2(r, r), c + Vector2(-r, r)]), "capas": ["hitos"]})
	for r in out:
		var p: PackedVector2Array = r["poligono"]
		if Geometry2D.is_polygon_clockwise(p):
			p.reverse()
			r["poligono"] = p
	return out


func V(p: Vector2, h: float) -> Vector3:
	return Malla.P(p.x, p.y, S.E(p.x, p.y) + h)


# el suelo, las caras de las soleras y los faldones, y la pintura
func suelo(m: Malla) -> void:
	for s in D["suelo"]:
		var t: Array = SUELO.get(s[0], ["tierra", "liso"])
		m.capa(G, S, Array(pol(s[2])), float(s[1]), K[t[0]], t[1])
	for b in D["bordes"]:
		var p := pol(b[3])
		var col: Color = K["amarillo"] if b[2] == "solera-amarilla" else K["solera"] if b[2] == "solera" else K["tierra"]
		var mat := "pintura" if b[2] == "solera-amarilla" else "granito" if b[2] == "solera" else "liso"
		for i in p.size() - 1:
			var a := p[i]
			var c := p[i + 1]
			if a.distance_to(c) < 0.01:
				continue
			var d := (c - a).normalized()
			var n := Vector2(-d.y, d.x)  # a la izquierda: hacia lo más bajo
			m.cara([V(a, float(b[0])), V(c, float(b[0])), V(c, float(b[1])), V(a, float(b[1]))], col, mat, Vector3(n.x, 0, -n.y))
	for p in D["pintura"]:
		m.capa(G, S, Array(pol(p[1])), H_PINTURA, K["blanco"], "pintura")


# los objetos y los vanos de cable
func cosas(m: Malla, raiz: Node3D) -> void:
	for o in D["objetos"]:
		if o[0] == "cerco":
			var pts := []
			for p in pol(o[4]):
				pts.append(V(p, H_SOLERA))
			Mob.cerco(m, pts, o[1], float(o[2]), Color(o[3]))
			continue
		var x: float = o[1]
		var y: float = o[2]
		var a: float = o[3]
		var q: Dictionary = o[4]
		var f := Malla.Marco.new(x, y, a, S.E(x, y) + H_SOLERA)
		match o[0]:
			"semaforo":
				Mob.semaforo(m, f, q.get("forma", "poste"), float(q.get("largo", 6.0)), int(q.get("cabezas", 1)), q.get("camara", false))
			"poste":
				Mob.poste(m, Malla.Marco.new(x, y, a, S.E(x, y) + H_SOLERA - 0.05), q.get("poste", "media"), false, q.get("pintado", ""))
				if q.has("letrero"):
					# el letrero vertical de la farmacia: azul, 0,6 × 2,2 m a 3 m
					m.caja(f, -0.32, 0.17, 0.32, 0.27, 3.0, 5.2, Color("1f3f8f"), "pintura")
					m.caja(f, -0.26, 0.27, 0.26, 0.28, 3.15, 5.05, Color("e9edf4"), "pintura")
			"letrero":
				Mob.letrero(m, f, float(q.get("ancho", 4.0)), float(q.get("alto", 2.5)), float(q.get("base", 3.0)), q.get("colores", []), int(q.get("caras", 1)), q.get("pie", ""))
			"bandera":
				Mob.bandera(m, f, float(q.get("alto", 6.0)), Color(q.get("color", "2e8b3e")))
			"senal":
				Mob.senal(m, f, q.get("forma", "pare"))
			"palmera":
				palmera(raiz, x, y, float(q.get("alto", 12.0)), q.get("forma", "canaria"))
	for v in D["vanos"]:
		var a: Array = v[0]
		var b: Array = v[1]
		var fa := Malla.Marco.new(a[0], a[1], atan2(a[3], a[2]), S.E(a[0], a[1]) + H_SOLERA - 0.05)
		var fb := Malla.Marco.new(b[0], b[1], atan2(b[3], b[2]), S.E(b[0], b[1]) + H_SOLERA - 0.05)
		Mob.vano(m, fa, a[4], fb, b[4], int(v[2]))


# una palmera canaria de la plaza (modelos/plaza/arboles.gd), de `alto` m; la de abanico (una Washingtonia: no está
# entre las de la plaza) va como una canaria más chica y angosta
func palmera(raiz: Node3D, x: float, y: float, alto: float, forma: String) -> void:
	if arboles == null:
		arboles = Arboles.comun() as Arboles
	var v := int(absf(x * 7.0 + y * 13.0)) % Arboles.VARIANTES
	var mi := MeshInstance3D.new()
	mi.mesh = arboles.malla("palmera", v)
	var k := alto / 13.0  # las de la plaza: estípite de 8,5–12,5 m, ~13 m con las frondas
	var xz := Vector3(k * (0.7 if forma == "abanico" else 1.0), k, k * (0.7 if forma == "abanico" else 1.0))
	mi.transform = Transform3D(Basis(Vector3.UP, fmod(x * 3.1 + y, TAU)).scaled(xz), V(Vector2(x, y), 0.2))
	mi.name = "palmera"
	raiz.add_child(mi)
