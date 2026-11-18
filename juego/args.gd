# Las banderas del juego (lo que va después de `--` en la línea de comandos), en un solo lugar: cada archivo las lee
# con estas funciones en vez de buscarlas a mano, y main.gd llama a revisar() al comenzar, que avisa de una bandera
# desconocida, de una a la que le falta su valor y de un valor que no es un número.
#
#   const Args := preload("res://args.gd")
#   if Args.has("--png"): ...
#   var h := Args.num("--hora", 12.0, 0.0, 24.0)        # acotado a [0, 24], con aviso si se sale
#   var p := Args.vec2("--desde", Vector2(0, -45))
#   for s in Args.lista("--sin"): ...
#
# BANDERAS es la lista de todas, con lo que esperan y quién las lee: una nueva se agrega ahí.
extends RefCounted

# nombre -> [valor que espera ("" si ninguno), quién la lee y qué hace]
const BANDERAS := {
	"--png": ["archivo", "main.gd: guarda un cuadro y sale"],
	"--desde": ["x,y", "main.gd: el personaje en ese punto de grilla"],
	"--girar": ["grados", "main.gd: gira la vista a la izquierda"],
	"--mirar": ["grados", "main.gd: inclina la vista (+ arriba)"],
	"--camara": ["m", "main.gd: el largo del brazo de la cámara (0: primera persona)"],
	"--caminar": ["s", "main.gd: camina hacia adelante antes de --png"],
	"--vehiculo": ["bici|auto", "main.gd: sube a la bicicleta o al auto al comenzar (vehiculo.gd)"],
	"--conducir": ["s", "vehiculo.gd: acelera s segundos e imprime dónde terminó y contra qué chocó (con --vehiculo)"],
	"--volante": ["v", "vehiculo.gd: con --conducir, gira (-1 izquierda … 1 derecha)"],
	"--fuerte": ["", "vehiculo.gd: con --conducir, con Q apretada (la bicicleta pedalea de pie)"],
	"--bajar": ["", "vehiculo.gd: con --conducir, se baja al final y dice dónde quedó el personaje"],
	"--vp": ["", "main.gd: producción virtual (vp.gd)"],
	"--cine": ["", "main.gd: un plano de cine de 30 s, sin personaje (cine.gd; make cine)"],
	"--cuadro": ["s,s,…", "cine.gd: solo esos segundos de la toma (con --png: x-t<s>.png de cada uno) y sale"],
	"--sin-titulo": ["", "cine.gd: la toma sin la hora, el título ni los fundidos"],
	"--fps": ["s", "fps.gd: mide los cuadros por segundo durante s segundos y sale"],
	"--render": ["escala", "fps.gd: dibuja la escena a escala² veces los píxeles (con --fps)"],
	"--sin": ["a,b,…", "ambiente.gd y modelos/plaza.gd: apaga partes (ver SIN)"],
	"--calidad": ["baja", "ambiente.gd: baja = --sin ssil,ssao,blandas"],
	"--hora": ["h", "ambiente.gd: la hora del día (T la avanza)"],
	"--dia": ["día del año", "ambiente.gd: el sol de ese día"],
	"--pose": ["m/s", "jugador.gd: el peatón animado como a esa velocidad"],
	"--cenital": ["x,y,lado", "modelos/calles.gd: cámara ortográfica desde arriba"],
	"--ancla": ["x,y", "vp.gd: el punto de grilla al pie de la tele"],
	"--rumbo": ["grados", "vp.gd"],
	"--alto": ["m", "vp.gd"],
	"--escala": ["escala", "vp.gd: la escala de la plaza"],
	"--tele": ["pulgadas", "vp.gd"],
	"--lente": ["mm", "vp.gd"],
	"--adelanto": ["s", "vp.gd"],
	"--ojo": ["x,y,z", "vp.gd: el ojo fijo (sin teléfono)"],
	"--pantalla": ["n", "vp.gd: la pantalla de la ventana"],
	"--lan": ["", "vp.gd: abre los puertos a la red local (el teléfono sin cable); sin ella, solo 127.0.0.1"],
}

# lo que apaga --sin (y quién lo lee)
const SIN := {
	"ssil": "ambiente.gd", "ssao": "ambiente.gd", "glow": "ambiente.gd", "niebla": "ambiente.gd",
	"sombras": "ambiente.gd", "blandas": "ambiente.gd", "lejos": "ambiente.gd", "nubes": "ambiente.gd",
	"plaza": "modelos/plaza.gd (el modelo entero: el hito del glb queda)", "arboles": "modelos/plaza.gd",
	"pasto": "modelos/plaza.gd",
	"autos": "autos.gd (los autos del mapa, de cerca y de lejos)", "luces": "faroles.gd (las luces de verdad: quedan lámparas y brillos)",
	"letreros": "letreros.gd (los de las calles de la comuna; los de calles.gd quedan)",
}


static func _args() -> PackedStringArray:
	return OS.get_cmdline_user_args()


static func has(nombre: String) -> bool:
	return nombre in _args()


# el valor que sigue a la bandera, o def si no está o le falta (con un aviso)
static func texto(nombre: String, def := "") -> String:
	var a := _args()
	var i := a.find(nombre)
	if i < 0:
		return def
	if i + 1 >= a.size() or a[i + 1].begins_with("--"):
		push_warning("args.gd: %s espera %s" % [nombre, BANDERAS.get(nombre, ["un valor"])[0]])
		return def
	return a[i + 1]


static func _num(nombre: String, s: String, def: float) -> float:
	if not s.is_valid_float():
		push_warning("args.gd: %s espera un número, no «%s»" % [nombre, s])
		return def
	return float(s)


# un número, acotado a [lo, hi] (con un aviso si se sale)
static func num(nombre: String, def: float, lo := -INF, hi := INF) -> float:
	var s := texto(nombre)
	if s == "":
		return def
	var v := _num(nombre, s, def)
	if v < lo or v > hi:
		push_warning("args.gd: %s %s fuera de [%s, %s]" % [nombre, s, lo, hi])
		v = clampf(v, lo, hi)
	return v


# los números de una lista separada por comas (n de ellos), o def
static func nums(nombre: String, n: int, def: Array) -> Array:
	var s := texto(nombre)
	if s == "":
		return def
	var p := s.split(",")
	if p.size() != n:
		push_warning("args.gd: %s espera %s" % [nombre, BANDERAS.get(nombre, ["%d números" % n])[0]])
		return def
	var out := []
	for i in n:
		out.append(_num(nombre, p[i], def[i]))
	return out


static func vec2(nombre: String, def: Vector2) -> Vector2:
	var v := nums(nombre, 2, [def.x, def.y])
	return Vector2(v[0], v[1])


static func vec3(nombre: String, def: Vector3) -> Vector3:
	var v := nums(nombre, 3, [def.x, def.y, def.z])
	return Vector3(v[0], v[1], v[2])


# una lista separada por comas (vacía si no está)
static func lista(nombre: String) -> PackedStringArray:
	var s := texto(nombre)
	return PackedStringArray() if s == "" else s.split(",")


# lo que apaga --sin, más lo de --calidad baja
static func sin_() -> PackedStringArray:
	var out := lista("--sin")
	if texto("--calidad") == "baja":
		out.append_array(["ssil", "ssao", "blandas"])
	return out


# avisa de lo que no se entiende: banderas desconocidas, valores sueltos, partes de --sin que nada apaga
static func revisar() -> void:
	var a := _args()
	var i := 0
	while i < a.size():
		var s := a[i]
		if not BANDERAS.has(s):
			push_warning("args.gd: bandera desconocida «%s» (las que hay: args.gd, BANDERAS)" % s)
		elif BANDERAS[s][0] != "":
			i += 1  # su valor (texto() avisa si falta)
		i += 1
	for p in lista("--sin"):
		if not SIN.has(p):
			push_warning("args.gd: --sin %s no apaga nada (las que hay: %s)" % [p, ", ".join(SIN.keys())])
	var c := texto("--calidad")
	if c != "" and c != "baja":
		push_warning("args.gd: --calidad espera baja, no «%s»" % c)
