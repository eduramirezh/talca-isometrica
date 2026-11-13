# La Catedral de Talca (Catedral de San Agustín), en el lado poniente de la plaza, mirando al oriente, con el detalle
# que pide una cámara a 1,7 m. Reemplaza el hito de la página (capa «hitos» del glb dentro de su planta).
#
# Planta y marco: los del hito de la página (src/js/hitos/catedral.js): OSM w114237041 (nave, crucero, ábside, bautisterio,
# sacristía), el campanario w798980080 en la esquina de 1 Norte y la escalinata w799225255; marco de
# `landmark.py frame catedral 114237041`: v corre a lo largo de la nave hacia el ábside (poniente), u hacia 1 Norte, y la
# fachada está en v = -32 (el frontis) y v = -29 (las naves laterales). Alturas medidas en las fotos de Commons con el
# ancho del campanario de OSM como escala (diagnostics/fotos/catedral/, indice.txt):
#   - 00 (2024-10-18, CC0, desde el sureste): el frontis blanco con tres arcos hondos (el del medio más alto), las
#     puertas al fondo de cada arco, los vitrales con parteluces encima; la nave lateral sur de ladrillo con su puerta
#     de marco blanco y bandas blancas; el triforio con ventanas de arco en pares entre pilastras blancas; la cornisa
#     con dentículos; el techo de teja gris parda;
#   - 02 (2018, CC BY-SA 4.0, de frente): las proporciones del frontis (hombros a ~17 m, vértice a ~20 m, cruz de
#     fierro), el emblema bajo el vértice, el campanario de cinco cuerpos;
#   - 05 y 07 (2017-12-12, CC BY-SA 2.0 y CC BY 4.0): la escalinata de tres peldaños, los relieves sobre las puertas
#     (San Agustín al medio, dos escudos), el zócalo blanco del campanario con su baranda, los cuerpos de ladrillo
#     entre machones blancos con un par de ventanillas de arco cada uno, el retranqueo a media altura, la balaustrada,
#     el cuerpo de campanas blanco con tres arcos por lado y el chapitel verde de escamas;
#   - 06 (2017-12-12): el bautisterio redondo de ladrillo, con dos ventanas de arco con vitral, una banda y una cornisa
#     blancas sobre un zócalo de hormigón;
#   - 01 (2022-05-28, CC BY-SA 4.0, desde 1 Norte): la reja roja del patio entre el campanario y el crucero.
# Lo aproximado: el ancho exacto de las naves y del crucero, el ábside y la sacristía (no hay fotos del lado poniente),
# la pendiente de los techos, el dibujo de los vitrales y de los relieves (siluetas), las campanas.
extends Node3D

const Malla := preload("res://modelos/entorno/malla.gd")
const Suelo := preload("res://modelos/entorno/suelo.gd")

const X := -102.9
const Y := 32.3
const A := 179.3 * PI / 180

# la planta (OSM: iglesia, campanario y escalinata) en (u, v) del marco, como en la página
const PLANTA := [[-10, -35], [16, -35], [16, -32.4], [21.7, -32.4], [21.7, -25.8], [16, -25.8], [16, 6], [24, 6], [24, 25],
	[13, 25], [13, 24], [7, 27], [3, 28.5], [-2, 27], [-6, 22.5], [-9, 22.5], [-9, 17], [-18, 17], [-18, 6], [-10, 6],
	[-10, -23], [-13.3, -26], [-10, -29]]

const K := {
	"ladrillo": Color("a65640"), "ladrillo2": Color("97503b"), "blanco": Color("e9e5dc"), "blanco_s": Color("d5d0c5"),
	"zocalo": Color("c9c4b8"), "teja": Color("7d5a4a"), "teja_cum": Color("9a4a33"), "vidrio": Color("33404c"),
	"vitral": Color("5b4a3a"), "puerta": Color("4a3a2c"), "fierro": Color("2e2d2b"), "chapitel": Color("50695a"),
	"peldano": Color("bdb7ab"), "oscuro": Color("1d1b19"), "reja": Color("8f2a22"),
}

var m := Malla.new()
var f: Malla.Marco


func recortes() -> Array:
	var g := Malla.Marco.new(X, Y, A)
	var p := PackedVector2Array()
	for q in PLANTA:
		p.append(g.G(q[0], q[1]))
	if Geometry2D.is_polygon_clockwise(p):
		p.reverse()
	var r := Geometry2D.offset_polygon(p, 1.2, Geometry2D.JOIN_MITER)
	# el patio entre el campanario y el crucero, hasta la reja de 1 Norte: lo dibuja patio()
	var pt := PackedVector2Array()
	for q in [[15.5, -26.5], [24.6, -26.5], [24.6, 6.5], [15.5, 6.5]]:
		pt.append(g.G(q[0], q[1]))
	if Geometry2D.is_polygon_clockwise(pt):
		pt.reverse()
	return [{"poligono": r[0], "capas": ["hitos", "edificios", "ciudad", "patios", "suelo", "usos"]},
		{"poligono": pt, "capas": ["hitos", "edificios", "ciudad", "patios", "suelo", "usos", "arboles", "autos"]}]


func _ready() -> void:
	var S := Suelo.new(get_parent())
	f = Malla.Marco.new(X, Y, A, S.E(-80, 35))
	escalinata()
	frontis()
	naves_laterales()
	nave()
	crucero_y_abside()
	bautisterio()
	campanario()
	patio()
	m.construir(self, "catedral")


# ---------------------------------------------------------------- ayudas

func V2(u: float, v: float) -> Vector2:
	return Vector2(u, v)


# una ventana de arco hundida en un muro a -> b: hueco de ancho w desde h0 hasta el arranque ha (arco de medio
# punto encima), derrame de prof m, vitral al fondo con parteluces (nv verticales y nh horizontales)
func ventana(a: Vector2, b: Vector2, s: float, w: float, h0: float, ha: float, prof: float, col_derrame: Color,
		vidrio := K["vitral"], nv := 1, nh := 2, marco := 0.0) -> PackedVector2Array:
	var hq := Malla.arco(s, w, h0, ha, -1.0, 8)
	m.derrame(f, a, b, hq, prof, col_derrame, "liso", vidrio, "vidrio")
	var L := a.distance_to(b)
	var d := (b - a) / L
	var o := Vector2(d.y, -d.x)
	# parteluces: listones finos justo delante del vidrio
	var pin := prof - 0.02
	var top := ha + w / 2.0
	for i in range(1, nv + 1):
		var si := s - w / 2 + w * i / (nv + 1)
		m.moldura(f, a - o * pin, b - o * pin, si - 0.03, si + 0.03, h0, ha + sqrt(max(0.0, (w / 2) ** 2 - (si - s) ** 2)) - 0.02, 0.025, K["fierro"], "metal")
	for j in range(1, nh + 1):
		var hj := h0 + (ha - h0) * j / (nh + 1)
		m.moldura(f, a - o * pin, b - o * pin, s - w / 2, s + w / 2, hj - 0.03, hj + 0.03, 0.025, K["fierro"], "metal")
	if marco > 0:
		# un marco blanco plano alrededor del hueco (el de las puertas de las naves laterales)
		m.moldura(f, a, b, s - w / 2 - marco, s - w / 2, h0, ha, 0.06, K["blanco"])
		m.moldura(f, a, b, s + w / 2, s + w / 2 + marco, h0, ha, 0.06, K["blanco"])
		m.moldura(f, a, b, s - w / 2 - marco, s + w / 2 + marco, ha, ha + marco, 0.06, K["blanco"])
	# el alféizar
	m.moldura(f, a, b, s - w / 2 - 0.08, s + w / 2 + 0.08, h0 - 0.1, h0, 0.1, K["blanco"])
	return hq


# un vano rectangular (puerta) con hoja de madera al fondo y tableros
func puerta(a: Vector2, b: Vector2, s: float, w: float, h0: float, h1: float, prof: float, col_derrame: Color) -> PackedVector2Array:
	var hq := PackedVector2Array([Vector2(s - w / 2, h0), Vector2(s + w / 2, h0), Vector2(s + w / 2, h1), Vector2(s - w / 2, h1)])
	m.derrame(f, a, b, hq, prof, col_derrame, "liso", K["puerta"], "pintura")
	var L := a.distance_to(b)
	var d := (b - a) / L
	var o := Vector2(d.y, -d.x)
	var pa := a - o * (prof - 0.03)
	var pb := b - o * (prof - 0.03)
	# las dos hojas y sus tableros (listones algo más oscuros)
	var osc: Color = K["puerta"].darkened(0.25)
	m.moldura(f, pa, pb, s - 0.03, s + 0.03, h0, h1, 0.03, osc, "pintura")
	for k in 3:
		var hk := h0 + 0.25 + (h1 - h0 - 0.5) * k / 3.0
		for sg in [-1.0, 1.0]:
			var c: float = s + sg * w / 4
			m.moldura(f, pa, pb, c - w / 4 + 0.15, c + w / 4 - 0.15, hk + 0.08, hk + (h1 - h0 - 0.5) / 3.0 - 0.08, 0.02, osc, "pintura")
	return hq


# ---------------------------------------------------------------- piezas

# la escalinata (OSM w799225255): un descanso y dos peldaños de 0,2 m de piedra gris a lo ancho de la fachada
func escalinata() -> void:
	m.caja(f, -10, -33, 16, -28.4, 0.0, 0.9, K["peldano"], "granito")
	m.caja(f, -10, -34, 16, -33, 0.0, 0.7, K["peldano"], "granito")
	m.caja(f, -10, -35, 16, -34, 0.0, 0.5, K["peldano"], "granito")
	# maceteros de hormigón con arbustos delante de los machones del frontis (fotos 05, 07)
	for u in [-2.0, 11.0, -9.0, 15.2]:
		m.caja(f, u - 0.35, -32.9, u + 0.35, -32.2, 0.9, 1.45, K["zocalo"], "granito")
		m.cilindro(f, u, -32.55, 0.32, 1.45, 1.95, Color("3f5a2c"), "liso", 7)


const FU0 := -2.5
const FU1 := 11.5
const FM := 4.5
const ARCOS := [[0.95, 2.5, 13.8], [4.5, 3.6, 14.6], [8.05, 2.5, 13.8]]  # centro u, ancho, clave


# el frontis: un bloque blanco de 14 × 3,5 m que sobresale de las naves, con tres arcos hondos (1 m) que llegan casi
# al suelo; al fondo de cada uno, la puerta, una banda con relieves y el vitral; arriba el hastial con su coronación,
# el emblema y la cruz de fierro
func frontis() -> void:
	var a := V2(FU0, -32)
	var b := V2(FU1, -32)
	var huecos := []
	for ar in ARCOS:
		var w: float = ar[1]
		huecos.append(Malla.arco(ar[0] - FU0, w, 0.9, ar[2] - w / 2, -1.0, 10))
	# la cara del frente con los arcos, y el hastial encima
	var cont := PackedVector2Array([Vector2(0, 0.9), Vector2(14, 0.9), Vector2(14, 17), Vector2(7, 20.0), Vector2(0, 17)])
	m.superficie(f, a, b, cont, huecos, K["blanco"])
	m.moldura(f, a, b, 0, 14, 0.9, 1.35, 0.05, K["zocalo"])  # zócalo
	for hq in huecos:
		m.derrame(f, a, b, hq, 1.0, K["blanco_s"])
	# el fondo de cada arco (a 1 m): puerta abajo, banda de relieves, vitral arriba
	for ar in ARCOS:
		var u: float = ar[0]
		var w: float = ar[1]
		var top: float = ar[2]
		var fa := V2(u - w / 2, -31.0)
		var fb := V2(u + w / 2, -31.0)
		var fondo := Malla.arco(w / 2, w, 0.9, top - w / 2, -1.0, 10)
		var pw := w - 0.9
		var ph := 3.6 if w > 3 else 3.3
		var hp := puerta(fa, fb, w / 2, pw, 0.9, 0.9 + ph, 0.25, K["blanco_s"])
		var hv := ventana(fa, fb, w / 2, w - 0.7, 6.4, top - w / 2 - 0.1, 0.18, K["blanco_s"], K["vitral"], 3 if w > 3 else 2, 5)
		m.superficie(f, fa, fb, fondo, [hp, hv], K["blanco_s"])
		# los relieves de la banda (fotos 05, 07): San Agustín al medio, un escudo en cada arco lateral
		if w > 3:
			estatua(fa, fb, w / 2, 0.9 + ph + 0.15)
		else:
			var c := Malla.ngon(w / 2, 0.9 + ph + 1.0, 0.42, 10)
			var p := []
			var L := fa.distance_to(fb)
			for q in c:
				p.append(f.V(fa.x + (fb.x - fa.x) * q.x / L, -31.0 - 0.08, q.y))
			m.cara(p, K["blanco"], "liso", f.N(0, -1))
	# los costados del frontis (u = FU0 y FU1, de v -32 a -29) y su tapa con el hastial
	m.muro(f, V2(FU0, -29), V2(FU0, -32), 0.9, 17, K["blanco"])
	m.muro(f, V2(FU1, -32), V2(FU1, -29), 0.9, 17, K["blanco"])
	var cara_atras := PackedVector2Array([Vector2(0, 10), Vector2(14, 10), Vector2(14, 17), Vector2(7, 20), Vector2(0, 17)])
	m.superficie(f, V2(FU1, -28.5), V2(FU0, -28.5), cara_atras, [], K["blanco"])
	# la coronación del hastial: dos faldones blancos que salen 0,3 m
	for sg in [-1.0, 1.0]:
		var u0 := FU0 - 0.3 if sg < 0 else FU1 + 0.3
		var p0 := f.V(u0, -32.3, 16.85)
		var p1 := f.V(FM, -32.3, 20.25)
		var p2 := f.V(FM, -28.4, 20.25)
		var p3 := f.V(u0, -28.4, 16.85)
		m.cara([p0, p1, p2, p3], K["blanco_s"], "liso", f.N(sg * 3.4, 0, 7.0))
		m.cara([f.V(u0, -32.3, 16.6), f.V(FM, -32.3, 20.0), p1, p0], K["blanco_s"], "liso", f.N(0, -1))
	m.caja(f, FU0 - 0.3, -32.3, FU0 + 0.6, -28.4, 16.6, 17.05, K["blanco_s"])
	m.caja(f, FU1 - 0.6, -32.3, FU1 + 0.3, -28.4, 16.6, 17.05, K["blanco_s"])
	# el emblema (un ancla y una cruz en un círculo, foto 02) y la cruz de fierro
	var e := Malla.ngon(FM - FU0, 18.2, 0.42, 12)
	var p := []
	for q in e:
		p.append(f.V(FU0 + q.x, -32.06, q.y))
	m.cara(p, K["blanco_s"], "liso", f.N(0, -1))
	m.caja(f, FM - 0.06, -32.1, FM + 0.06, -32.04, 17.9, 18.55, K["fierro"], "metal")
	m.caja(f, FM - 0.22, -32.1, FM + 0.22, -32.04, 18.35, 18.45, K["fierro"], "metal")
	m.caja(f, FM - 0.1, -30.5, FM + 0.1, -30.3, 20.0, 22.4, K["fierro"], "metal")
	m.caja(f, FM - 0.6, -30.5, FM + 0.6, -30.3, 21.4, 21.62, K["fierro"], "metal")


# una silueta de santo en relieve (la estatua de San Agustín sobre la puerta central, fotos 05 y 07): peana, túnica
# que se ensancha hacia abajo, hombros, cabeza con mitra y báculo
func estatua(a: Vector2, b: Vector2, s: float, h0: float) -> void:
	var L := a.distance_to(b)
	var d := (b - a) / L
	var o := Vector2(d.y, -d.x)
	var c := K["blanco"].darkened(0.04)
	m.moldura(f, a, b, s - 0.35, s + 0.35, h0, h0 + 0.25, 0.25, c)
	var cuerpo := [[0.36, 0.25], [0.3, 1.2], [0.24, 1.5]]
	for i in 2:
		var w0: float = cuerpo[i][0]
		var w1: float = cuerpo[i + 1][0]
		var y0: float = h0 + cuerpo[i][1]
		var y1: float = h0 + cuerpo[i + 1][1]
		var q := [f.V(a.x + d.x * (s - w0) + o.x * 0.2, a.y + d.y * (s - w0) + o.y * 0.2, y0),
			f.V(a.x + d.x * (s + w0) + o.x * 0.2, a.y + d.y * (s + w0) + o.y * 0.2, y0),
			f.V(a.x + d.x * (s + w1) + o.x * 0.18, a.y + d.y * (s + w1) + o.y * 0.18, y1),
			f.V(a.x + d.x * (s - w1) + o.x * 0.18, a.y + d.y * (s - w1) + o.y * 0.18, y1)]
		m.cara(q, c, "liso", f.N(o.x, o.y))
		for sg in [-1.0, 1.0]:
			m.cara([f.V(a.x + d.x * (s + sg * w0), a.y + d.y * (s + sg * w0), y0), f.V(a.x + d.x * (s + sg * w0) + o.x * 0.2, a.y + d.y * (s + sg * w0) + o.y * 0.2, y0),
				f.V(a.x + d.x * (s + sg * w1) + o.x * 0.18, a.y + d.y * (s + sg * w1) + o.y * 0.18, y1), f.V(a.x + d.x * (s + sg * w1), a.y + d.y * (s + sg * w1), y1)],
				c.darkened(0.05), "liso", f.N(d.x * sg, d.y * sg))
	m.moldura(f, a, b, s - 0.11, s + 0.11, h0 + 1.5, h0 + 1.78, 0.2, c)
	m.moldura(f, a, b, s - 0.08, s + 0.08, h0 + 1.78, h0 + 1.98, 0.17, c)
	m.moldura(f, a, b, s + 0.38, s + 0.43, h0 + 0.3, h0 + 2.0, 0.22, c)  # el báculo


# las naves laterales: de ladrillo hasta 8,5 m bajo un techo de un agua que sube hasta la nave; ocho tramos con
# ventanas de arco entre pilastras blancas, zócalo y banda blancos. Sur: u -10 a -1,5; norte: u 10,5 a 16
const NU0 := -1.5
const NU1 := 10.5
const BAY := 35.0 / 8.0


func naves_laterales() -> void:
	for lado in [[-10.0, NU0, -10.0, -1.0], [NU1, 16.0, 16.0, 1.0]]:
		var u0: float = lado[0]
		var u1: float = lado[1]
		var uo: float = lado[2]
		var sg: float = lado[3]
		var ui := NU0 if sg < 0 else NU1
		# el muro exterior, con una ventana por tramo
		var a := V2(uo, 6.0) if sg < 0 else V2(uo, -29.0)
		var b := V2(uo, -29.0) if sg < 0 else V2(uo, 6.0)
		var huecos := []
		for k in 8:
			var vc := -29.0 + BAY * (k + 0.5)
			var s := a.distance_to(V2(uo, vc))
			huecos.append(ventana(a, b, s, 1.2, 3.0, 5.2, 0.3, K["ladrillo2"], K["vitral"], 1, 2))
		m.muro_vanos(f, a, b, 0.3, 8.5, huecos, K["ladrillo"], "ladrillo")
		m.moldura(f, a, b, 0, 35, 0.3, 1.1, 0.04, K["zocalo"])
		m.moldura(f, a, b, 0, 35, 6.3, 6.7, 0.07, K["blanco"])
		m.moldura(f, a, b, 0, 35, 8.2, 8.55, 0.12, K["blanco"])
		for k in 9:
			var s := BAY * k
			m.moldura(f, a, b, max(0.0, s - 0.3), min(35.0, s + 0.3), 0.3, 8.5, 0.1, K["blanco"])
		# el techo de un agua, de teja, desde el alero (8,5 m, 0,5 m afuera) hasta el muro de la nave (10,2 m)
		var ue := uo + sg * 0.5
		m.cara([f.V(ue, -29.0, 8.4), f.V(ue, 6.0, 8.4), f.V(ui, 6.0, 10.2), f.V(ui, -29.0, 10.2)], K["teja"], "teja", f.N(sg * 1.7, 0, abs(ui - ue)))
		m.cara([f.V(ue, -29.0, 8.36), f.V(ue, 6.0, 8.36), f.V(uo, 6.0, 8.36), f.V(uo, -29.0, 8.36)], K["blanco_s"], "liso", Vector3.DOWN)
		# el frente de la nave lateral (v = -29): ladrillo hasta la pendiente del techo, coronación blanca, una
		# puerta de marco blanco, el zócalo y las bandas; la pilastra blanca de la esquina
		var a0 := V2(u0, -29) if sg < 0 else V2(FU1, -29)
		var b0 := V2(FU0, -29) if sg < 0 else V2(u1, -29)
		var L := a0.distance_to(b0)
		var hi := func(u: float) -> float: return 8.5 + 1.7 * abs(u - uo) / (u1 - u0)
		var cont := PackedVector2Array([Vector2(0, 0.9), Vector2(L, 0.9), Vector2(L, hi.call(b0.x)), Vector2(0, hi.call(a0.x))])
		var dc := L / 2.0 + (0.4 if sg < 0 else 0.0)
		var hp := puerta(a0, b0, dc, 2.3, 0.9, 4.1, 0.3, K["blanco_s"])
		m.superficie(f, a0, b0, cont, [hp], K["ladrillo"], "ladrillo")
		m.moldura(f, a0, b0, dc - 1.55, dc - 1.15, 0.9, 4.5, 0.08, K["blanco"])
		m.moldura(f, a0, b0, dc + 1.15, dc + 1.55, 0.9, 4.5, 0.08, K["blanco"])
		m.moldura(f, a0, b0, dc - 1.55, dc + 1.55, 4.1, 4.5, 0.08, K["blanco"])
		m.moldura(f, a0, b0, 0, L, 0.9, 1.3, 0.04, K["zocalo"])
		m.moldura(f, a0, b0, 0, L, 6.3, 6.7, 0.07, K["blanco"])
		var c0 := f.V(a0.x, -29.12, hi.call(a0.x) - 0.35)
		var c1 := f.V(b0.x, -29.12, hi.call(b0.x) - 0.35)
		m.cara([c0, c1, f.V(b0.x, -29.12, hi.call(b0.x) + 0.1), f.V(a0.x, -29.12, hi.call(a0.x) + 0.1)], K["blanco"], "liso", f.N(0, -1))
		var esq := uo if sg < 0 else 16.0
		m.caja(f, esq - 0.45 if sg > 0 else esq, -29.15, esq if sg > 0 else esq + 0.45, -28.6, 0.9, hi.call(esq) + 0.15, K["blanco"])


# la nave: ladrillo de 10,2 a 15 m sobre los techos de las laterales, pares de ventanas de arco entre pilastras
# blancas, cornisa blanca con dentículos y techo de dos aguas de teja con cumbrera roja
func nave() -> void:
	for lado in [[NU0, -1.0], [NU1, 1.0]]:
		var u: float = lado[0]
		var sg: float = lado[1]
		var a := V2(u, 6.0) if sg < 0 else V2(u, -28.5)
		var b := V2(u, -28.5) if sg < 0 else V2(u, 6.0)
		var huecos := []
		for k in 8:
			var vc := -29.0 + BAY * (k + 0.5)
			for dv in [-0.75, 0.75]:
				var s := a.distance_to(V2(u, vc + dv))
				huecos.append(ventana(a, b, s, 0.8, 11.0, 13.2, 0.25, K["ladrillo2"], K["vitral"], 0, 1))
		m.muro_vanos(f, a, b, 10.0, 15.0, huecos, K["ladrillo"], "ladrillo")
		for k in 9:
			var s := clampf(BAY * k - 0.5, 0.3, 34.2)
			m.moldura(f, a, b, s - 0.3, s + 0.3, 10.0, 14.4, 0.1, K["blanco"])
		m.moldura(f, a, b, 0, 34.5, 14.35, 14.7, 0.16, K["blanco"])
		m.moldura(f, a, b, 0, 34.5, 14.7, 15.05, 0.32, K["blanco"])
		var s := 0.15
		while s < 34.4:
			m.moldura(f, a, b, s, s + 0.14, 14.2, 14.35, 0.13, K["blanco_s"])
			s += 0.42
	techo(-28.5, 23.0, NU0, NU1, 15.0, 3.5)


# un techo de dos aguas de teja a lo largo de v (de v0 a v1), entre u0 y u1, alero a h y cumbrera a h + alto, con
# hastiales de ladrillo en los extremos
func techo(v0: float, v1: float, u0: float, u1: float, h: float, alto: float, hastiales := true) -> void:
	var um := (u0 + u1) / 2
	var e := 0.5
	for sg in [-1.0, 1.0]:
		var ue := (u0 - e) if sg < 0 else (u1 + e)
		var he := h - alto * e / ((u1 - u0) / 2)
		m.cara([f.V(ue, v0 - 0.3, he), f.V(ue, v1 + 0.3, he), f.V(um, v1 + 0.3, h + alto), f.V(um, v0 - 0.3, h + alto)], K["teja"], "teja", f.N(sg * alto, 0, (u1 - u0) / 2))
	m.caja(f, um - 0.18, v0 - 0.3, um + 0.18, v1 + 0.3, h + alto - 0.05, h + alto + 0.18, K["teja_cum"], "teja")
	if hastiales:
		for v in [v0, v1]:
			var sv := -1.0 if v == v0 else 1.0
			m.cara([f.V(u0, v, h), f.V(u1, v, h), f.V(um, v, h + alto)], K["ladrillo"], "ladrillo", f.N(0, sv))


# el crucero (u -18 a 24, v 6 a 17, 14 m) y el presbiterio con el ábside de nueve caras, como en la página; la
# sacristía al norte, de techo plano
func crucero_y_abside() -> void:
	m.caja(f, -18, 6, 24, 17, 0.3, 14, K["ladrillo"], "ladrillo")
	var g := Malla.Marco.new(0, 0, 0)
	for lado in [[-18.0, -1.0], [24.0, 1.0]]:
		var u: float = lado[0]
		var sg: float = lado[1]
		var a := V2(u, 17.0) if sg < 0 else V2(u, 6.0)
		var b := V2(u, 6.0) if sg < 0 else V2(u, 17.0)
		var hv := ventana(a, b, 5.5, 2.6, 4.0, 10.0, 0.4, K["ladrillo2"], K["vitral"], 2, 5)
		m.panel(f, a, b, 0, 11, 0.3, 1.1, 0.03, K["zocalo"])
		m.moldura(f, a, b, 0, 0.6, 0.3, 14, 0.1, K["blanco"])
		m.moldura(f, a, b, 10.4, 11, 0.3, 14, 0.1, K["blanco"])
		m.moldura(f, a, b, 0, 11, 13.6, 14.1, 0.2, K["blanco"])
		# el hastial del brazo
		m.cara([f.V(u, 6, 14), f.V(u, 17, 14), f.V(u, 11.5, 17.5)], K["ladrillo"], "ladrillo", f.N(sg, 0))
		m.derrame(f, a, b, Malla.arco(5.5, 1.0, 14.6, 15.3, -1.0, 6), 0.2, K["ladrillo2"], "liso", K["oscuro"], "pintura")
	# techo del crucero, a lo largo de u
	for sg in [-1.0, 1.0]:
		var ve := 6.0 - 0.5 if sg < 0 else 17.0 + 0.5
		m.cara([f.V(-18.3, ve, 13.7), f.V(24.3, ve, 13.7), f.V(24.3, 11.5, 17.5), f.V(-18.3, 11.5, 17.5)], K["teja"], "teja", f.N(0, sg * 3.8, 6.0))
	m.caja(f, -18.3, 11.32, 24.3, 11.68, 17.45, 17.65, K["teja_cum"], "teja")
	# presbiterio y ábside
	m.caja(f, -9, 17, 13, 23, 0.3, 12, K["ladrillo"], "ladrillo")
	m.piramide(f, m.rect(-9.4, 16.6, 13.4, 23.4), 12, 15, 2, 20, K["teja"], "teja")
	var cu := 3.5
	var cv := 16.5
	var r := 11.5
	var arc := PackedVector2Array()
	for i in 9:
		var t := deg_to_rad(34.4 + (145.6 - 34.4) * i / 8.0)
		arc.append(Vector2(cu + r * cos(t), cv + r * sin(t)))
	for i in 8:
		var a := arc[i]
		var b := arc[i + 1]
		var hv := ventana(a, b, a.distance_to(b) / 2, 0.9, 6.0, 8.8, 0.3, K["ladrillo2"], K["vitral"], 0, 2)
		m.muro_vanos(f, a, b, 0.3, 11, [hv], K["ladrillo"], "ladrillo")
		m.moldura(f, a, b, 0, a.distance_to(b), 0.3, 1.3, 0.04, K["zocalo"])
		m.moldura(f, a, b, 0, a.distance_to(b), 10.4, 11, 0.12, K["blanco"])
		m.cara([f.V(a.x, a.y, 11), f.V(b.x, b.y, 11), f.V(cu, 21, 13)], K["teja"], "teja")
	# la sacristía (OSM, al norte del presbiterio)
	m.caja(f, 13, 17, 24, 25, 0.3, 7.1, K["ladrillo"], "ladrillo", K["zocalo"])
	for u in [16.0, 20.0]:
		ventana(V2(24, 25), V2(13, 25), 24 - u, 1.2, 3.0, 4.6, 0.2, K["ladrillo2"], K["vidrio"], 0, 1)
	m.moldura(f, V2(24, 25), V2(13, 25), 0, 11, 6.5, 7.15, 0.12, K["blanco"])
	m.moldura(f, V2(24, 17), V2(24, 25), 0, 8, 6.5, 7.15, 0.12, K["blanco"])


# el bautisterio redondo junto a la fachada (OSM; foto 06): tres cuartos de cilindro de ladrillo con dos ventanas de
# arco con vitral, zócalo de hormigón, banda y cornisa blancas, techo plano
func bautisterio() -> void:
	var cu := -10.0
	var cv := -26.0
	var n := 14
	var pts := PackedVector2Array()
	for i in n + 1:
		var t := deg_to_rad(90.0 + 225.0 * i / n)
		pts.append(Vector2(cu + 3.0 * cos(t), cv + 3.0 * sin(t)))
	for i in n:
		var a := pts[i]
		var b := pts[i + 1]
		var L := a.distance_to(b)
		var hs := []
		if i == 4 or i == 9:
			hs.append(ventana(a, b, L / 2, 0.75, 3.9, 5.3, 0.25, K["ladrillo2"], Color("8a5a2a"), 0, 3))
		m.muro_vanos(f, a, b, 0.3, 6.6, hs, K["ladrillo"], "ladrillo")
		m.moldura(f, a, b, -0.02, L + 0.02, 0.3, 1.5, 0.06, K["zocalo"])
		m.moldura(f, a, b, -0.02, L + 0.02, 3.2, 3.45, 0.08, K["blanco"])
		m.moldura(f, a, b, -0.02, L + 0.02, 6.6, 7.1, 0.25, K["blanco"])
	var tapa := pts.duplicate()
	tapa.append(Vector2(cu, cv))
	m.piso(f, tapa, 7.1, K["zocalo"])


# el campanario (OSM w798980080, ~5,6 × 6,3 m, dibujado cuadrado): zócalo blanco con baranda; dos cuerpos de ladrillo
# entre machones blancos, cada uno de tres tramos con un par de ventanillas de arco; el retranqueo a 15 m; la
# balaustrada; el cuerpo de campanas blanco con tres arcos por lado; la cornisa y el chapitel verde de escamas a ~39 m
func campanario() -> void:
	var tu := 18.85
	var tv := -29.1
	var caras := func(a: float) -> Array:
		return [[V2(tu - a, tv - a), V2(tu + a, tv - a)], [V2(tu + a, tv - a), V2(tu + a, tv + a)],
			[V2(tu + a, tv + a), V2(tu - a, tv + a)], [V2(tu - a, tv + a), V2(tu - a, tv - a)]]
	m.caja(f, tu - 3.25, tv - 3.25, tu + 3.25, tv + 3.25, 0.3, 4.3, K["blanco"])
	m.caja(f, tu - 3.35, tv - 3.35, tu + 3.35, tv + 3.35, 4.3, 4.55, K["blanco_s"])
	for cuerpo in [[4.55, 15.0, 3.0, [8.1, 11.55]], [15.0, 26.2, 2.7, [18.7, 22.45]]]:
		var h0: float = cuerpo[0]
		var h1: float = cuerpo[1]
		var a: float = cuerpo[2]
		var bandas: Array = [h0] + cuerpo[3] + [h1]
		for c in caras.call(a):
			var hs := []
			for k in bandas.size() - 1:
				var hm: float = bandas[k + 1] - 1.6
				for ds in [-0.42, 0.42]:
					var hq := Malla.arco(a + ds, 0.42, hm, hm + 0.7, -1.0, 6)
					m.derrame(f, c[0], c[1], hq, 0.25, K["blanco_s"], "liso", K["oscuro"], "pintura")
					hs.append(hq)
			m.muro_vanos(f, c[0], c[1], h0, h1, hs, K["ladrillo"], "ladrillo")
			for b in bandas.slice(1, bandas.size() - 1):
				m.moldura(f, c[0], c[1], -0.1, 2 * a + 0.1, b - 0.2, b + 0.2, 0.1, K["blanco"])
			# los machones de las esquinas, 0,9 m de ancho, salen 0,12 m
			m.moldura(f, c[0], c[1], -0.12, 0.9, h0, h1, 0.12, K["blanco"])
			m.moldura(f, c[0], c[1], 2 * a - 0.9, 2 * a + 0.12, h0, h1, 0.12, K["blanco"])
		m.caja(f, tu - a - 0.2, tv - a - 0.2, tu + a + 0.2, tv + a + 0.2, h1 - 0.4, h1, K["blanco"])
	# la balaustrada: un antepecho con balaustres cada 0,25 m entre una base y un pasamanos
	m.caja(f, tu - 3.0, tv - 3.0, tu + 3.0, tv + 3.0, 26.2, 26.45, K["blanco"])
	m.caja(f, tu - 3.05, tv - 3.05, tu + 3.05, tv + 3.05, 27.2, 27.4, K["blanco"])
	for c in caras.call(2.9):
		var L: float = c[0].distance_to(c[1])
		var s := 0.25
		while s < L - 0.1:
			var p: Vector2 = c[0] + (c[1] - c[0]) / L * s
			m.caja(f, p.x - 0.05, p.y - 0.05, p.x + 0.05, p.y + 0.05, 26.45, 27.2, K["blanco_s"])
			s += 0.27
	# el cuerpo de campanas: blanco, tres arcos por lado, con la campana al fondo
	m.caja(f, tu - 2.1, tv - 2.1, tu + 2.1, tv + 2.1, 27.4, 27.6, K["blanco"])
	for c in caras.call(2.1):
		var hs := []
		for ds in [-1.15, 0.0, 1.15]:
			var hq := Malla.arco(2.1 + ds, 0.62, 28.0, 30.3, -1.0, 6)
			m.derrame(f, c[0], c[1], hq, 0.45, K["blanco_s"], "liso", K["oscuro"], "pintura")
			hs.append(hq)
		m.muro_vanos(f, c[0], c[1], 27.6, 31.2, hs, K["blanco"])
	m.cilindro(f, tu, tv, 0.55, 28.2, 29.3, Color("6b5a3a"), "metal", 10)
	m.caja(f, tu - 2.45, tv - 2.45, tu + 2.45, tv + 2.45, 31.2, 31.7, K["blanco"])
	# el chapitel: una pirámide de cuatro caras algo cóncava (dos tramos) con escamas verdes, y una cruz
	var base := m.rect(tu - 2.2, tv - 2.2, tu + 2.2, tv + 2.2)
	var med := m.rect(tu - 1.25, tv - 1.25, tu + 1.25, tv + 1.25)
	for i in 4:
		var a0 := base[i]
		var a1 := base[(i + 1) % 4]
		var b0 := med[i]
		var b1 := med[(i + 1) % 4]
		var n := ((a0 + a1) / 2 - Vector2(tu, tv)).normalized()
		m.cara([f.V(a0.x, a0.y, 31.7), f.V(a1.x, a1.y, 31.7), f.V(b1.x, b1.y, 34.6), f.V(b0.x, b0.y, 34.6)], K["chapitel"], "pizarra", f.N(n.x * 3, n.y * 3, 1))
		m.cara([f.V(b0.x, b0.y, 34.6), f.V(b1.x, b1.y, 34.6), f.V(tu, tv, 39.5)], K["chapitel"], "pizarra", f.N(n.x * 5, n.y * 5, 1))
	m.caja(f, tu - 0.05, tv - 0.05, tu + 0.05, tv + 0.05, 39.4, 40.6, K["fierro"], "metal")
	m.caja(f, tu - 0.3, tv - 0.05, tu + 0.3, tv + 0.05, 40.1, 40.2, K["fierro"], "metal")


# el patio entre el campanario y el crucero, hacia 1 Norte: una reja de fierro roja sobre un murete blanco (foto 01)
func patio() -> void:
	var a := V2(24.25, 6.0)
	var b := V2(24.25, -25.6)
	var L := a.distance_to(b)
	m.moldura(f, b, a, 0, L, 0.0, 0.6, 0.25, K["blanco_s"], "liso", -0.25)
	m.moldura(f, b, a, 0, L, 1.95, 2.0, 0.04, K["reja"], "metal", -0.04)
	var s := 0.0
	while s < L:
		m.moldura(f, b, a, s, s + 0.04, 0.6, 2.05, 0.02, K["reja"], "metal", -0.02)
		s += 0.14
	# el suelo del patio: baldosa gris y un prado con arbustos junto a la nave
	m.piso(f, m.rect(16.0, -25.8, 24.1, 6.0), 0.3, Color("a8a49b"), "baldosa")
	m.caja(f, 16.3, -22.0, 19.5, 4.0, 0.3, 0.45, Color("e9e5dc"), "liso", Color("5f8a3e"))
	for v in [-19.0, -12.0, -5.0, 2.0]:
		m.cilindro(f, 17.9, v, 0.7, 0.45, 1.4, Color("3f5f2e"), "liso", 7)
	for s2 in [0.0, L / 3, 2 * L / 3, L - 0.2]:
		m.moldura(f, b, a, s2, s2 + 0.2, 0.0, 2.2, 0.1, K["blanco"], "liso", -0.1)
