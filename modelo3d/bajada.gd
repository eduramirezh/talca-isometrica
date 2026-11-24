# En el navegador: baja archivos de mapa/ (fuente.gd, Fuente.base) por HTTP, A_LA_VEZ a la vez, en el orden en que se
# piden (mapa.gd pide primero las teselas más cercanas), y los deja en la memoria de fuente.gd tal como llegan: en
# gzip (el servidor tiene <nombre>.gz; fuente.gd los descomprime al leerlos). Un archivo que el servidor no tiene
# (404) queda vacío: Fuente.existe() da false. Uno que falla por la red se reintenta REINTENTOS veces.
# web.gd la crea y la cuelga de la raíz (sobrevive al cambio de escena a ver.tscn).
#
#   Fuente.bajada.pedir(["t_0_0.glb", "t_0_0.json"], func(): …)   # llama cuando están todos (al tiro si ya estaban)
#   Fuente.bajada.mb                                                # lo bajado, en MB
extends Node

const Fuente := preload("res://fuente.gd")
const A_LA_VEZ := 6
const REINTENTOS := 2

var cola := []  # nombres por bajar
var esperan := {}  # nombre -> [grupo]; grupo: {"faltan": n, "listo": Callable}
var intentos := {}  # nombre -> los que fallaron
var activos := 0
var mb := 0.0
var archivos := 0


func pedir(nombres: Array, listo: Callable) -> void:
	var grupo := {"faltan": 0, "listo": listo}
	for n in nombres:
		if Fuente.tiene(n):
			continue
		grupo["faltan"] += 1
		if not esperan.has(n):
			esperan[n] = []
			cola.append(n)
		esperan[n].append(grupo)
	if grupo["faltan"] == 0:
		listo.call()
		return
	siguiente()


func siguiente() -> void:
	while activos < A_LA_VEZ and not cola.is_empty():
		var n: String = cola.pop_front()
		var r := HTTPRequest.new()
		add_child(r)
		activos += 1
		r.request_completed.connect(func(res: int, codigo: int, _h: PackedStringArray, cuerpo: PackedByteArray):
			llego(n, r, res, codigo, cuerpo))
		var err := r.request(Fuente.base + n + ".gz")
		if err != OK:
			llego(n, r, HTTPRequest.RESULT_CANT_CONNECT, 0, PackedByteArray())


func llego(n: String, r: HTTPRequest, res: int, codigo: int, cuerpo: PackedByteArray) -> void:
	r.queue_free()
	activos -= 1
	if res != HTTPRequest.RESULT_SUCCESS or (codigo != 200 and codigo != 404):
		intentos[n] = intentos.get(n, 0) + 1
		if intentos[n] <= REINTENTOS:
			cola.push_front(n)
			siguiente()
			return
		push_warning("bajada.gd: no pude bajar %s (resultado %d, HTTP %d)" % [n, res, codigo])
	Fuente.guardar(n, cuerpo if codigo == 200 else PackedByteArray())
	mb += cuerpo.size() / 1048576.0
	archivos += 1
	for g in esperan.get(n, []):
		g["faltan"] -= 1
		if g["faltan"] == 0:
			g["listo"].call()
	esperan.erase(n)
	siguiente()
