# Los recortes de los modelos (modelos/*.gd, recortes()) aplicados a una malla del mapa: lo que cae dentro de un
# polígono de grilla se quita de las capas que nombra, antes de crear la colisión. Funciones estáticas, sin escena:
# mapa.gd las corre en un hilo sobre cada tesela recién leída, antes de agregarla (hasta noviembre de 2026 estaban en
# main.gd y cortaban el plaza.glb de una vez).
#
#   const Recorte := preload("res://recorte.gd")
#   Recorte.recortar(mi, recs, xf)     # recs: [{"poligono": PackedVector2Array, "capas": [...]}]; xf: la de mi en el mundo
#   Recorte.toca(recs, caja)           # si algún recorte cae en la caja de grilla (Rect2)
extends RefCounted


static func toca(recs: Array, caja: Rect2) -> bool:
	for r in recs:
		if _caja(r["poligono"]).intersects(caja, true):
			return true
	return false


# quita de una malla del glb lo que cae en un recorte que toca su capa. Los triángulos se juntan en piezas por sus
# vértices (soldados al milímetro: el glb repite los de cada cara). Una pieza chica y con alto (un árbol, un auto,
# un farol) se quita o queda entera, por el centro de su planta: no se corta un objeto por la mitad. En lo demás
# (el suelo y las losas, planos a cualquier tamaño; las piezas grandes soldadas), cada triángulo inclinado o plano
# se corta en el borde del polígono (en planta) y lo que queda se vuelve a triangular, con sus atributos (posición,
# normal, color, uv) interpolados en el triángulo original: sigue en su plano; uno casi vertical (un muro) es una
# línea en planta y se quita si su centro cae dentro. Antes todo se quitaba por el centro de cada triángulo: un
# triángulo grande que cruzaba el borde quedaba o se iba entero (el suelo de una manzana de la página asomaba por las
# fachadas de 1 Sur), y los objetos quedaban a medias
const VERTICAL := 0.2  # |normal.y| bajo esto: un muro
const SUBDIV := 6  # cuántas veces partir en cuatro un triángulo con un recorte entero adentro (un hueco)
const OBJETO := 25.0  # m: una pieza de este lado o menos en planta, y de más de ALTO_OBJETO de alto, es un objeto
const ALTO_OBJETO := 0.3
const CELDA := 20.0  # m: el lado de las celdas en que se anotan los recortes (_celdas), para no probar cada triángulo contra todos
# m: un triángulo cuya caja queda a más de esto de la de todo recorte no se corta ni es parte de un objeto que se quita
# (un objeto mide OBJETO o menos y se quita si su centro cae en uno: todos sus vértices quedan a menos de OBJETO / 2 de
# su caja). Las piezas y los objetos se buscan solo entre los triángulos más cercanos (_cerca); una pieza que sigue
# más allá queda partida, pero cada parte que importa toca la caja de un recorte y sale de CERCA: mide más de OBJETO,
# no es un objeto, igual que la pieza entera
const CERCA := OBJETO + 1.0


static func recortar(mi: MeshInstance3D, recs: Array, xf := Transform3D.IDENTITY) -> void:
	var capa := String(mi.name)
	var pols := []
	for r in recs:
		var capas: Array = r.get("capas", [])
		if capas.is_empty() or capa in capas or String(mi.get_parent().name) in capas:
			var pol: PackedVector2Array = r["poligono"]
			pols.append([pol, _caja(pol)])
	if pols.is_empty():
		return
	var celdas := _celdas(pols)
	var grandes := []  # las cajas de los recortes, con CERCA m más por lado
	for pb in pols:
		grandes.append([null, (pb[1] as Rect2).grow(CERCA)])
	var celdas_cerca := _celdas(grandes)
	var am := mi.mesh as ArrayMesh
	var nuevo := ArrayMesh.new()
	var n := {"quitados": 0, "cortados": 0}
	for s in am.get_surface_count():
		var a := am.surface_get_arrays(s)
		for k in [Mesh.ARRAY_BONES, Mesh.ARRAY_WEIGHTS, Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2, Mesh.ARRAY_CUSTOM3]:
			assert(a[k] == null, "recortar: atributo %d sin interpolar" % k)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
		var w := PackedVector3Array()  # en el mundo
		w.resize(v.size())
		for i in v.size():
			w[i] = xf * v[i]
		var cerca := _cerca(w, idx, grandes, celdas_cerca)  # por triángulo: 1 si su caja toca una de grandes
		var pieza := _piezas(w, idx, cerca)  # por vértice (de los triángulos cerca): el índice de su pieza
		var objeto := _objetos(w, idx, cerca, pieza, pols)
		var out := {"a": a, "base": v.size(), "nuevos": {}}  # los vértices nuevos, por atributo (Array: por referencia)
		var keep := []
		for t in range(0, idx.size(), 3):
			var i0 := idx[t]
			var i1 := idx[t + 1]
			var i2 := idx[t + 2]
			if cerca[t / 3] == 0:
				keep.append(i0)
				keep.append(i1)
				keep.append(i2)
				continue
			if objeto.has(pieza[i0]):  # antes de la prueba de cajas: un objeto se va entero
				if objeto[pieza[i0]]:
					n.quitados += 1
				else:
					keep.append(i0)
					keep.append(i1)
					keep.append(i2)
				continue
			var p0 := w[i0]
			var p1 := w[i1]
			var p2 := w[i2]
			var x0 := minf(p0.x, minf(p1.x, p2.x))
			var y0 := minf(-p0.z, minf(-p1.z, -p2.z))
			var tb := Rect2(x0, y0, maxf(p0.x, maxf(p1.x, p2.x)) - x0, maxf(-p0.z, maxf(-p1.z, -p2.z)) - y0)
			var hits := []
			for i in _candidatos(celdas, tb):
				if pols[i][1].intersects(tb, true):
					hits.append(pols[i])
			if hits.is_empty():
				keep.append(i0)
				keep.append(i1)
				keep.append(i2)
				continue
			var tri := PackedVector2Array([Vector2(p0.x, -p0.z), Vector2(p1.x, -p1.z), Vector2(p2.x, -p2.z)])
			var nm := (w[i1] - w[i0]).cross(w[i2] - w[i0])
			if absf(nm.y) < VERTICAL * nm.length():  # un muro: por su centro
				var c := (tri[0] + tri[1] + tri[2]) / 3.0
				if _dentro(c, hits):
					n.quitados += 1
				else:
					keep.append_array([i0, i1, i2])
				continue
			var piezas := _recorte(tri, hits, 0)
			if piezas.size() == 1 and absf(_area(piezas[0]) - _area(tri)) <= 1e-6 * absf(_area(tri)) + 1e-9:
				keep.append_array([i0, i1, i2])  # no lo toca
				continue
			if piezas.is_empty():
				n.quitados += 1
				continue
			n.cortados += 1
			_rellenar(piezas, tri, [i0, i1, i2], out, keep, capa)
		if keep.is_empty():
			continue
		_juntar(a, out.nuevos)
		a[Mesh.ARRAY_INDEX] = PackedInt32Array(keep)
		nuevo.add_surface_from_arrays(am.surface_get_primitive_type(s), a)
		nuevo.surface_set_material(nuevo.get_surface_count() - 1, am.surface_get_material(s))
	mi.mesh = nuevo
	if n.quitados + n.cortados > 0:
		print("recorte.gd: %s%s, %d triángulos quitados y %d cortados" % [String(mi.get_parent().name) + "/" if mi.get_parent() else "", capa, n.quitados, n.cortados])


# las piezas que son objetos (chicas en planta y con alto: un árbol, un auto, un farol) -> si se quitan (el centro de su
# planta cae en un recorte)
static func _objetos(w: PackedVector3Array, idx: PackedInt32Array, cerca: PackedByteArray, pieza: PackedInt32Array, pols: Array) -> Dictionary:
	var cajas := {}  # pieza -> AABB en el mundo
	for t in range(0, idx.size(), 3):
		if cerca[t / 3] == 0:
			continue
		for j in 3:
			var i := idx[t + j]
			var k: int = pieza[i]
			cajas[k] = cajas[k].expand(w[i]) if cajas.has(k) else AABB(w[i], Vector3.ZERO)
	var objeto := {}
	for k in cajas:
		var bb: AABB = cajas[k]
		if maxf(bb.size.x, bb.size.z) <= OBJETO and bb.size.y > ALTO_OBJETO:
			var c := bb.get_center()
			objeto[k] = _dentro(Vector2(c.x, -c.z), pols)
	return objeto


# las piezas que quedan de un triángulo cortado (tri: en planta; ii: sus vértices), triangulados en el orden del
# original, con sus vértices nuevos (out) y sus índices en keep
static func _rellenar(piezas: Array, tri: PackedVector2Array, ii: Array, out: Dictionary, keep: Array, capa: String) -> void:
	var signo := signf(_area(tri))
	for pz in piezas:
		var tr := PackedInt32Array([0, 1, 2]) if pz.size() == 3 else Geometry2D.triangulate_polygon(pz)
		if tr.is_empty() and absf(_area(pz)) > 1e-4:  # no la pudo triangular: en abanico, antes que un hueco
			push_warning("recortar: %s, una pieza de %d vértices en abanico" % [capa, pz.size()])
			for k in range(1, pz.size() - 1):
				tr.append_array([0, k, k + 1])
		for k in range(0, tr.size(), 3):
			var q0: Vector2 = pz[tr[k]]
			var q1: Vector2 = pz[tr[k + 1]]
			var q2: Vector2 = pz[tr[k + 2]]
			var ar := (q1 - q0).cross(q2 - q0) / 2.0
			if absf(ar) < 1e-6:
				continue
			var q := [q0, q1, q2] if signf(ar) == signo else [q0, q2, q1]
			for p in q:
				keep.append(_vertice(out, ii[0], ii[1], ii[2], tri, p))


# lo que queda de un triángulo (en planta) fuera de los recortes hits: polígonos simples, sin huecos. Un recorte
# entero dentro de una pieza deja un hueco, que triangulate_polygon no acepta: el triángulo se parte en cuatro y
# cada parte se recorta de nuevo (tras SUBDIV veces, la parte se quita o queda por su centro)
static func _recorte(tri: PackedVector2Array, hits: Array, prof: int) -> Array:
	var piezas := [tri]
	for h in hits:
		var nuevas := []
		for pz in piezas:
			if not _caja(pz).intersects(h[1], true):
				nuevas.append(pz)
				continue
			var r := Geometry2D.clip_polygons(pz, h[0])
			if _hueco(r):
				if prof >= SUBDIV:
					return [] if _dentro((tri[0] + tri[1] + tri[2]) / 3.0, hits) else [tri]
				var m01 := (tri[0] + tri[1]) / 2.0
				var m12 := (tri[1] + tri[2]) / 2.0
				var m20 := (tri[2] + tri[0]) / 2.0
				var out := []
				for sub in [[tri[0], m01, m20], [m01, tri[1], m12], [m20, m12, tri[2]], [m01, m12, m20]]:
					out.append_array(_recorte(PackedVector2Array(sub), hits, prof + 1))
				return out
			nuevas.append_array(r)
		piezas = nuevas
	return piezas


# clip_polygons devuelve un hueco como un polígono de la orientación contraria a la de los demás
static func _hueco(r: Array) -> bool:
	if r.size() < 2:
		return false
	var cw := Geometry2D.is_polygon_clockwise(r[0])
	for p in r:
		if Geometry2D.is_polygon_clockwise(p) != cw:
			return true
	return false


# un vértice nuevo en el punto p (en planta) del triángulo i0 i1 i2 (tri, en planta): sus atributos interpolados
# con las coordenadas baricéntricas de p, en out.nuevos; devuelve su índice
static func _vertice(out: Dictionary, i0: int, i1: int, i2: int, tri: PackedVector2Array, p: Vector2) -> int:
	var a: Array = out.a
	var nv: Dictionary = out.nuevos
	var d := (tri[1] - tri[0]).cross(tri[2] - tri[0])
	var b1 := (p - tri[0]).cross(tri[2] - tri[0]) / d
	var b2 := (tri[1] - tri[0]).cross(p - tri[0]) / d
	var b0 := 1.0 - b1 - b2
	for k in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TANGENT, Mesh.ARRAY_COLOR, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2]:
		var x = a[k]
		if x == null:
			continue
		if not nv.has(k):
			nv[k] = []
		match k:
			Mesh.ARRAY_TANGENT:
				var tv := Vector3(x[i0 * 4], x[i0 * 4 + 1], x[i0 * 4 + 2]) * b0 \
					+ Vector3(x[i1 * 4], x[i1 * 4 + 1], x[i1 * 4 + 2]) * b1 + Vector3(x[i2 * 4], x[i2 * 4 + 1], x[i2 * 4 + 2]) * b2
				tv = tv.normalized()
				nv[k].append_array([tv.x, tv.y, tv.z, x[i0 * 4 + 3]])
			Mesh.ARRAY_NORMAL:
				nv[k].append((x[i0] * b0 + x[i1] * b1 + x[i2] * b2).normalized())
			_:
				nv[k].append(x[i0] * b0 + x[i1] * b1 + x[i2] * b2)
	return out.base + nv[Mesh.ARRAY_VERTEX].size() - 1


# agrega a los arreglos de la superficie los vértices nuevos
static func _juntar(a: Array, nv: Dictionary) -> void:
	for k in nv:
		var x = a[k]
		match k:
			Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL:
				x.append_array(PackedVector3Array(nv[k]))
			Mesh.ARRAY_TANGENT:
				x.append_array(PackedFloat32Array(nv[k]))
			Mesh.ARRAY_COLOR:
				x.append_array(PackedColorArray(nv[k]))
			_:
				x.append_array(PackedVector2Array(nv[k]))
		a[k] = x


# por triángulo, 1 si su caja (en planta) toca una de las cajas de grandes (anotadas en celdas)
static func _cerca(w: PackedVector3Array, idx: PackedInt32Array, grandes: Array, celdas: Dictionary) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(idx.size() / 3)
	for t in range(0, idx.size(), 3):
		var p0 := w[idx[t]]
		var p1 := w[idx[t + 1]]
		var p2 := w[idx[t + 2]]
		var x0 := minf(p0.x, minf(p1.x, p2.x))
		var y0 := minf(-p0.z, minf(-p1.z, -p2.z))
		var tb := Rect2(x0, y0, maxf(p0.x, maxf(p1.x, p2.x)) - x0, maxf(-p0.z, maxf(-p1.z, -p2.z)) - y0)
		for i in _candidatos(celdas, tb):
			if grandes[i][1].intersects(tb, true):
				out[t / 3] = 1
				break
	return out


# las piezas de los triángulos cerca (_cerca): los unidos por vértices en el mismo lugar (al milímetro); por vértice,
# el representante de su pieza (los vértices de los demás quedan solos)
static func _piezas(w: PackedVector3Array, idx: PackedInt32Array, cerca: PackedByteArray) -> PackedInt32Array:
	var padre := PackedInt32Array()
	padre.resize(w.size())
	for i in w.size():
		padre[i] = i
	var en := {}
	for t in range(0, idx.size(), 3):
		if cerca[t / 3] == 0:
			continue
		for j in 3:
			var i := idx[t + j]
			if padre[i] != i:
				continue  # ya soldado a otro
			var key := Vector3i((w[i] * 1000.0).round())
			var e: int = en.get(key, -1)
			if e == -1:
				en[key] = i
			elif e != i:
				padre[i] = e
	for t in range(0, idx.size(), 3):
		if cerca[t / 3] == 0:
			continue
		var r0 := _raiz(padre, idx[t])
		for j in [1, 2]:
			var r := _raiz(padre, idx[t + j])
			if r != r0:
				padre[r] = r0
	for i in w.size():
		padre[i] = _raiz(padre, i)
	return padre


static func _raiz(padre: PackedInt32Array, i: int) -> int:
	while padre[i] != i:
		padre[i] = padre[padre[i]]
		i = padre[i]
	return i


# los recortes anotados por celda de CELDA m (Vector2i -> PackedInt32Array de índices en pols, en orden): cada uno en
# las celdas que toca su caja. Probar los ~33.000 triángulos de los patios de una tesela de la plaza contra las cajas de
# sus 189 recortes tomaba ~380 ms de los ~550 de recortarla; con las celdas, cada triángulo prueba solo los de las suyas
# (y con _cerca, las piezas se buscan solo cerca de los recortes: las cuatro teselas del arranque, de 3,9 s a 0,45 s
# con --headless, las mismas mallas byte a byte)
static func _celdas(pols: Array) -> Dictionary:
	var celdas := {}
	for i in pols.size():
		var bb: Rect2 = pols[i][1]
		for cy in range(floori(bb.position.y / CELDA), floori(bb.end.y / CELDA) + 1):
			for cx in range(floori(bb.position.x / CELDA), floori(bb.end.x / CELDA) + 1):
				var c := Vector2i(cx, cy)
				if not celdas.has(c):
					celdas[c] = PackedInt32Array()
				celdas[c].append(i)
	return celdas


# los índices de los recortes cuya caja puede tocar la caja tb (los de sus celdas), en el orden de pols: _recorte()
# los corta en ese orden. Dos cajas que se tocan, aunque sea en el borde, comparten un punto, y su celda está en las dos
static func _candidatos(celdas: Dictionary, tb: Rect2) -> PackedInt32Array:
	var x0 := floori(tb.position.x / CELDA)
	var x1 := floori(tb.end.x / CELDA)
	var y0 := floori(tb.position.y / CELDA)
	var y1 := floori(tb.end.y / CELDA)
	if x0 == x1 and y0 == y1:
		return celdas.get(Vector2i(x0, y0), PackedInt32Array())
	var visto := {}
	for cy in range(y0, y1 + 1):
		for cx in range(x0, x1 + 1):
			for i in celdas.get(Vector2i(cx, cy), PackedInt32Array()):
				visto[i] = true
	var out := PackedInt32Array(visto.keys())
	out.sort()
	return out


static func _dentro(p: Vector2, hits: Array) -> bool:
	for pb in hits:
		if pb[1].has_point(p) and Geometry2D.is_point_in_polygon(p, pb[0]):
			return true
	return false


static func _caja(pol: PackedVector2Array) -> Rect2:
	var bb := Rect2(pol[0], Vector2.ZERO)
	for p in pol:
		bb = bb.expand(p)
	return bb


static func _area(pol: PackedVector2Array) -> float:
	var s := 0.0
	for i in pol.size():
		s += pol[i].cross(pol[(i + 1) % pol.size()])
	return s / 2.0
