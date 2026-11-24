# Los archivos de mapa/ (lo que exporta `make modelo3d`: indice.json, las teselas y sus datos), de donde estén. En el
# computador, de res://mapa/ con FileAccess. En el navegador (la exportación web, `make web3d`) mapa/ no va en el
# paquete (son ~570 MB): web.gd y mapa.gd los bajan por HTTP de mapa/, junto a la página (bajada.gd, en el hilo
# principal), comprimidos (<nombre>.gz: ~28 % del tamaño; tools/web3d.py armar), y quedan así en memoria hasta que
# quien los usó los suelta; se descomprimen al leerlos (en el hilo de la tesela). Todo lo de mapa/ se lee por aquí;
# las funciones de lectura se pueden llamar desde un hilo.
#
#   const Fuente := preload("res://fuente.gd")
#   Fuente.existe("indice.json")
#   Fuente.json("t_0_0.json")         # null si no está
#   Fuente.glb("t_0_0.glb")           # Node3D (fuera de la escena) o null
#   Fuente.soltar("t_0_0.glb")        # en el navegador, lo libera de la memoria (en el computador no hace nada)
#   Fuente.bajada.pedir(["t_0_0.glb"], func(): …)   # solo en el navegador: los baja y después llama
extends RefCounted

const DIR := "res://mapa/"

static var web := OS.has_feature("web")
static var base := ""  # en el navegador: la URL de mapa/ (web.gd)
static var bajada: Node  # en el navegador: bajada.gd (web.gd la cuelga de la raíz)
static var _mem := {}  # en el navegador: nombre -> PackedByteArray en gzip (vacío: no está en el servidor)
static var _cerrojo := Mutex.new()


# en el navegador, si ya se bajó (esté o no en el servidor); en el computador, siempre
static func tiene(nombre: String) -> bool:
	if not web:
		return true
	_cerrojo.lock()
	var t := _mem.has(nombre)
	_cerrojo.unlock()
	return t


static func guardar(nombre: String, b: PackedByteArray) -> void:
	_cerrojo.lock()
	_mem[nombre] = b
	_cerrojo.unlock()


static func soltar(nombre: String) -> void:
	if web:
		_cerrojo.lock()
		_mem.erase(nombre)
		_cerrojo.unlock()


static func existe(nombre: String) -> bool:
	if not web:
		return FileAccess.file_exists(DIR + nombre)
	return not _gz(nombre).is_empty()


static func bytes(nombre: String) -> PackedByteArray:
	if not web:
		return FileAccess.get_file_as_bytes(DIR + nombre)
	var gz := _gz(nombre)
	# solo si viene en gzip (1f 8b): un servidor que lo mandara con Content-Encoding llegaría ya descomprimido
	if gz.size() < 2 or gz[0] != 0x1f or gz[1] != 0x8b:
		return gz
	return gz.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP)


static func _gz(nombre: String) -> PackedByteArray:
	_cerrojo.lock()
	var t := _mem.has(nombre)
	var b: PackedByteArray = _mem.get(nombre, PackedByteArray())
	_cerrojo.unlock()
	if not t:
		push_error("fuente.gd: %s no se ha bajado (bajada.pedir() antes de leerlo)" % nombre)
	return b


static func json(nombre: String) -> Variant:
	if not existe(nombre):
		return null
	return JSON.parse_string(bytes(nombre).get_string_from_utf8())


# el glb como escena (fuera del árbol), o null
static func glb(nombre: String) -> Node3D:
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	var err: Error
	if web:
		var b := bytes(nombre)
		err = doc.append_from_buffer(b, "", st) if not b.is_empty() else ERR_FILE_NOT_FOUND
	else:
		err = doc.append_from_file(ProjectSettings.globalize_path(DIR + nombre), st)
	if err != OK:
		push_error("fuente.gd: no pude leer %s (%s)" % [nombre, error_string(err)])
		return null
	return doc.generate_scene(st) as Node3D
