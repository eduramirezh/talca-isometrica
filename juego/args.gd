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
	"--vehiculo": ["bici|auto|jetpack", "main.gd: sube a la bicicleta o al auto, o se pone el jetpack, al comenzar (vehiculo.gd)"],
	"--conducir": ["s", "vehiculo.gd: acelera s segundos e imprime dónde terminó y contra qué chocó (con --vehiculo)"],
	"--volante": ["v", "vehiculo.gd: con --conducir, gira (-1 izquierda … 1 derecha)"],
	"--fuerte": ["", "vehiculo.gd: con --conducir, con Q apretada (la bicicleta pedalea de pie); con --volar, con Mayús"],
	"--saltos": ["n", "main.gd: camina 1 s y salta n veces seguidas (el triple salto) e imprime la altura de cada uno (jugador.gd prueba_saltos())"],
	"--menu-prueba": ["", "main.gd: aprieta Esc, Tab y M sin teclado e imprime qué queda abierto (menu.gd prueba())"],
	"--menu": ["", "main.gd: abre el menú de Esc al comenzar (menu.gd; para --png)"],
	"--pausa": ["s", "jugador.gd, vida.gd y armas.gd: con --saltos, --dano, --caer o --disparar, congela el juego s segundos después del último salto, del daño, del golpe contra el suelo o del último disparo (para --png); vehiculo.gd: con --volar, s segundos después de despegar"],
	"--dano": ["n", "main.gd: le quita n de vida e imprime cómo se recupera, o si muere dónde reaparece (vida.gd prueba())"],
	"--caer": ["m", "main.gd: lo deja caer desde m metros sobre el suelo (negativo: bajo él, fuera de la maqueta) e imprime la rapidez, el daño y la vida (vida.gd prueba())"],
	"--bajar": ["", "vehiculo.gd: con --conducir, se baja al final y dice dónde quedó el personaje; con --volar, se saca el jetpack, camina y se lo pone otra vez"],
	"--volar": ["s", "vehiculo.gd: con --vehiculo jetpack, despega, sube, avanza y aterriza en ~s segundos e imprime la altura máxima, lo recorrido, el combustible y la rapidez al aterrizar"],
	"--musica": ["archivo", "musica.gd: la pista (ogg, mp3 o wav) que suena al despegar con el jetpack desde el techo de la Torre Talca, en vez de juego/musica/torre-talca.mp3"],
	"--arma": ["cuchillo|pistola|rifle", "armas.gd: saca esa arma al comenzar"],
	"--apuntar": ["", "armas.gd: apunta (el botón derecho apretado) desde el comienzo"],
	"--disparar": ["n", "main.gd: dispara (o ataca) n veces a lo que hay bajo la mira e imprime cada impacto, el daño y la munición (armas.gd prueba())"],
	"--orbitar": ["grados", "armas.gd: con --disparar y --pausa, gira la cámara alrededor del personaje al congelar (la pose de lado)"],
	"--marcar": ["x,y", "main.gd: pone el marcador en ese punto de grilla y traza el camino hasta él (ruta.gd)"],
	"--plano": ["", "main.gd: abre el mapa grande (plano.gd), después de --marcar"],
	"--escala-plano": ["px/m", "main.gd: con --plano, la escala del mapa grande (0,035 la comuna entera … 4)"],
	"--clic": ["px,py", "main.gd: con --plano, un clic izquierdo en ese punto de la pantalla (pone o quita el marcador)"],
	"--doble-clic": ["px,py", "main.gd: con --plano, un doble clic en ese punto de la pantalla (va ahí) e imprime dónde quedó"],
	"--norte": ["", "plano.gd: el mapa en miniatura con el norte arriba (N lo cambia jugando)"],
	"--vp": ["", "main.gd: producción virtual (vp.gd)"],
	"--cine": ["", "main.gd: un plano de cine de 30 s, sin personaje (cine.gd; make cine)"],
	"--trailer": ["toma", "main.gd: una toma del avance (trailer.gd: ciudad, auto, bici, saltos, estadio, rio, cerro, noche)"],
	"--cuadro": ["s,s,…", "cine.gd y trailer.gd: solo esos segundos de la toma (con --png: x-t<s>.png de cada uno) y sale"],
	"--sin-titulo": ["", "cine.gd: la toma sin la hora, el título ni los fundidos"],
	"--fps": ["s", "fps.gd: mide los cuadros por segundo durante s segundos y sale"],
	"--render": ["escala", "fps.gd: dibuja la escena a escala² veces los píxeles (con --fps)"],
	"--sin": ["a,b,…", "ambiente.gd y modelos/plaza.gd: apaga partes (ver SIN)"],
	"--calidad": ["baja", "ambiente.gd: baja = --sin ssil,ssao,blandas"],
	"--hora": ["h", "ambiente.gd: la hora del día, quieta (sin ella, jugando, la del computador o la del anfitrión, que corre; en una captura, las 17:00; T la avanza; L, día o noche)"],
	"--dia": ["día del año", "ambiente.gd: el sol de ese día"],
	"--reloj": ["ahora|aaaa-mm-ddThh:mm", "ambiente.gd: la hora del computador también en una captura (--png, --fps, --cine, --trailer, --vp), o la de ese momento como si fuera la del computador"],
	"--pose": ["m/s", "jugador.gd: el peatón animado como a esa velocidad"],
	"--personaje": ["persona|perro", "jugador.gd: el cuerpo que se ve (perro.gd; jugando, en el menú de Esc)"],
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
	"--servidor": ["", "red.gd: crea una partida en la red local al comenzar (J: el panel)"],
	"--unirse": ["ip|lan", "red.gd: se une a la partida de esa IP (lan: a la primera que se anuncie)"],
	"--nombre": ["texto", "red.gd: el nombre que ven los demás jugadores"],
	"--puerto": ["n", "red.gd: el puerto de la partida (8790)"],
	"--red-prueba": ["s", "red.gd: a los s segundos imprime dónde están los otros jugadores y sale (con --png, después de ella)"],
	"--ctf": ["n", "bandera.gd: el anfitrión prepara captura la bandera al comenzar y la empieza cuando haya n banderas puestas"],
	"--bandera": ["", "bandera.gd: pone la bandera propia donde está el personaje en cuanto se prepare captura la bandera"],
	"--ctf-prueba": ["", "bandera.gd: toma la bandera ajena más cercana, anota con ella, la toma otra vez, muere con ella y espera la reaparición en la propia; imprime cada paso y sale (con --png, después)"],
	"--ctf-preparar": ["", "bandera.gd: el anfitrión (--servidor) sube con el jetpack, prepara captura la bandera (baja solo y se lo saca), pone la suya, prueba ponerse el jetpack, se aleja, empieza (vuelve a su bandera) y prueba los viajes; imprime cada paso y sale (con --png, después)"],
	"--ctf-robar": ["s", "bandera.gd: toma la bandera ajena más cercana y se queda con ella s segundos, y sale (con --png, después)"],
	"--red-foto": ["n", "red.gd: con --png, la captura al llegar el tiro n de otro jugador, con el juego congelado (el fogonazo y la trazadora)"],
	"--red-tiros": ["n", "red.gd: espera a otro jugador de la partida, le apunta y le dispara n veces (el arma de --arma; --apuntar), imprime cada impacto y la vida que le quedó, y sale (con --png, después)"],
	"--red-cabeza": ["", "red.gd: con --red-tiros, le apunta a la cabeza en vez del pecho"],
}

# lo que apaga --sin (y quién lo lee)
const SIN := {
	"ssil": "ambiente.gd", "ssao": "ambiente.gd", "glow": "ambiente.gd", "niebla": "ambiente.gd",
	"sombras": "ambiente.gd", "blandas": "ambiente.gd", "lejos": "ambiente.gd", "nubes": "ambiente.gd",
	"plaza": "modelos/plaza.gd (el modelo entero: el hito del glb queda)", "arboles": "modelos/plaza.gd",
	"pasto": "modelos/plaza.gd",
	"autos": "autos.gd (los autos del mapa, de cerca y de lejos)", "luces": "faroles.gd (las luces de verdad: quedan lámparas y brillos)",
	"fachadas": "mapa.gd (las fachadas de cerca de toda la comuna, fachadas_ciudad.gd: queda la caja del glb)",
	"letreros": "letreros.gd (los de las calles de la comuna; los de calles.gd quedan)",
	"plano": "main.gd (el mapa en miniatura y el mapa grande de plano.gd; el marcador de --marcar queda)",
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
