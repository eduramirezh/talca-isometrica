# Las teselas de modelo3d/mapa/ van en el formato liviano de tools/export.py (--liviano, make modelo3d): normales en BYTE
# normalizado, que glTF permite solo con la extensión KHR_mesh_quantization. GLTFDocument de Godot 4.7 no la declara
# y rechaza el archivo («required extension … is not supported»), pero su lector de accesores ya decodifica cualquier
# tipo de componente normalizado: basta con decir que se conoce. Probado (noviembre de 2026) con un glb de tres
# vértices: las normales y los colores de un byte salen iguales a los de float, salvo el redondeo de las normales a
# 1/127 (de todos modos Godot las guarda en 16 bits, octaédricas). Solo eso: las posiciones van en float (la
# extensión también permite enteros con una escala en el nodo, que tools/export.py no usa).
#
#   Cuantizado.registrar()   # una vez, antes de leer un glb (mapa.gd: _init)
extends GLTFDocumentExtension

static var _hecho := false


static func registrar() -> void:
	if not _hecho:
		_hecho = true
		GLTFDocument.register_gltf_document_extension(new())


func _get_supported_extensions() -> PackedStringArray:
	return PackedStringArray(["KHR_mesh_quantization"])
