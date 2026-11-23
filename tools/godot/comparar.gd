# Compara dos exportaciones de teselas (tools/export.py --teselas) en lo que el juego recibe: lee cada glb con
# GLTFDocument, como modelo3d/mapa.gd, y compara lo que Godot guarda en cada malla (ArrayMesh: los colores en RGBA8 y las
# normales en 16 bits octaédricas, cualquiera sea el formato del archivo), capa por capa y vértice por vértice. Sirve
# para un cambio de formato que no debe cambiar el juego (--liviano, noviembre de 2026): las capturas del juego no
# salen iguales de una corrida a otra (las nubes y el viento siguen los cuadros que tardó la carga).
#
#   /Applications/Godot.app/Contents/MacOS/Godot --headless -s tools/godot/comparar.gd -- <dir A> <dir B> [cada N]
#
# Con --headless el binario directo no abre ventana (no hace falta tools/godot_oculto.sh).
#
# Con cada N compara una de cada N teselas (por omisión todas, ~1 min). Imprime por capa los vértices, los índices
# distintos, la mayor diferencia de posición (m), de color (en bytes, 0 a 255) y el mayor ángulo entre normales
# (grados), y sale con 1 si una tesela o una capa falta en B, o si cambian los vértices o los índices.
extends SceneTree


# lo mismo que modelo3d/cuantizado.gd (este script corre fuera del proyecto del juego)
class Cuantizado extends GLTFDocumentExtension:
	func _get_supported_extensions() -> PackedStringArray:
		return PackedStringArray(["KHR_mesh_quantization"])


func mallas(ruta: String) -> Dictionary:
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	if doc.append_from_file(ruta, st) != OK:
		return {}
	var raiz := doc.generate_scene(st)
	var out := {}
	for n in raiz.find_children("*", "", true, false):
		var m: Mesh = null
		if n is ImporterMeshInstance3D and n.mesh:
			m = n.mesh.get_mesh()
		elif n is MeshInstance3D:
			m = n.mesh
		if m:
			for s in m.get_surface_count():
				var mat := m.surface_get_material(s)
				out["%s/%s" % [n.name, mat.resource_name if mat else str(s)]] = m.surface_get_arrays(s)
	raiz.free()
	return out


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() < 2:
		print("uso: Godot --headless -s tools/godot/comparar.gd -- <dir A> <dir B> [cada N]")
		quit(1)
		return
	GLTFDocument.register_gltf_document_extension(Cuantizado.new())
	var cada := int(a[2]) if a.size() > 2 else 1
	var archivos := Array(DirAccess.get_files_at(a[0])).filter(func(f): return f.ends_with(".glb"))
	archivos.sort()
	var tot := {}  # capa -> [vértices, índices distintos, posición, color, ángulo]
	var malo := 0
	for k in range(0, archivos.size(), cada):
		var f: String = archivos[k]
		var A := mallas(a[0].path_join(f))
		var B := mallas(a[1].path_join(f))
		if B.is_empty() and not A.is_empty():
			print("falta en B: ", f)
			malo += 1
			continue
		for capa in A:
			if not B.has(capa):
				print("%s: falta la capa %s en B" % [f, capa])
				malo += 1
				continue
			var x: Array = A[capa]
			var y: Array = B[capa]
			var t: Array = tot.get(capa.get_slice("/", 1), [0, 0, 0.0, 0, 0.0])
			var pa: PackedVector3Array = x[Mesh.ARRAY_VERTEX]
			var pb: PackedVector3Array = y[Mesh.ARRAY_VERTEX]
			if pa.size() != pb.size() or x[Mesh.ARRAY_INDEX] != y[Mesh.ARRAY_INDEX]:
				print("%s %s: %d y %d vértices, índices %s" % [f, capa, pa.size(), pb.size(), "iguales" if x[Mesh.ARRAY_INDEX] == y[Mesh.ARRAY_INDEX] else "distintos"])
				malo += 1
				t[1] += 1
				tot[capa.get_slice("/", 1)] = t
				continue
			var na: PackedVector3Array = x[Mesh.ARRAY_NORMAL]
			var nb: PackedVector3Array = y[Mesh.ARRAY_NORMAL]
			var ca: PackedColorArray = x[Mesh.ARRAY_COLOR]
			var cb: PackedColorArray = y[Mesh.ARRAY_COLOR]
			for i in pa.size():
				t[2] = maxf(t[2], pa[i].distance_to(pb[i]))
				t[4] = maxf(t[4], rad_to_deg(na[i].angle_to(nb[i])))
				for q in 3:
					t[3] = maxi(t[3], absi(roundi(ca[i][q] * 255.0) - roundi(cb[i][q] * 255.0)))
			t[0] += pa.size()
			tot[capa.get_slice("/", 1)] = t
	print("%d teselas (una de cada %d)" % [ceili(archivos.size() / float(cada)), cada])
	for capa in tot:
		var t: Array = tot[capa]
		print("%-12s %9d vértices  índices distintos en %d  posición %.4f m  color %d/255  normal %.2f°" % [capa, t[0], t[1], t[2], t[3], t[4]])
	quit(1 if malo else 0)
