# El visor de la maqueta en 3D: la comuna en teselas, con los modelos de cerca de la Plaza de Armas y sus calles, la
# Catedral, el Edificio Raíces y la Torre Talca (modelos/), y el cielo y el sol de Talca (ambiente.gd), vistos con una
# cámara que orbita alrededor de un punto. Lo arma mundo.gd; este archivo solo pone la cámara.
#
#   make modelo3d                                                             # en la raíz: exporta mapa/ y datos/ (~3 min)
#   /Applications/Godot.app/Contents/MacOS/Godot --path modelo3d              # mirar (o abrir modelo3d/project.godot en el editor)
#   tools/godot_oculto.sh --path modelo3d -- --png shots/m.png [--desde x,y --girar G --mirar P --camara L --hora h]
#
# Mouse con el botón izquierdo (o derecho) apretado: girar alrededor del punto; rueda: acercar o alejar; WASD o
# flechas: mover el punto (Mayús: más rápido); Q y E: bajarlo y subirlo; Esc: salir. --desde x,y pone el punto en ese
# punto de grilla (sin ella, el centro de la plaza), --girar G gira la vista G grados a la izquierda (0: mirando al
# norte), --mirar P la inclina P grados (+ arriba; -30 por omisión) y --camara L pone la cámara a L m del punto (160;
# 0.01: en el punto, que está 1,7 m sobre el suelo, a la altura de los ojos, como las vistas de
# tools/modelo3d_vistas.py). Las demás banderas (--hora, --sin, --calidad, --fps, --cenital) son las de args.gd.
extends "res://mundo.gd"

const INICIO := Vector2(0, 0)  # x, y de grilla: el centro de la plaza
const RAPIDEZ := 30.0  # m/s del punto con WASD (Mayús: por 4), a 40 m del punto (más lejos, más rápido)

var cam: Camera3D
var punto := Vector3.ZERO  # el centro de la órbita
var yaw := 0.0
var pitch := deg_to_rad(-30.0)
var largo := 160.0  # m de la cámara al punto
var arrastre := false


func _ready() -> void:
	Args.revisar()
	var desde := Args.vec2("--desde", INICIO)
	if not armar([Vector2.ZERO, desde]):
		return
	yaw = deg_to_rad(Args.num("--girar", 0.0))
	pitch = deg_to_rad(Args.num("--mirar", -30.0, -89.0, 89.0))
	largo = Args.num("--camara", largo, 0.01, 5000.0)
	punto = Vector3(desde.x, 0.0, -desde.y)
	cam = Camera3D.new()
	cam.far = 6000.0
	add_child(cam)
	if not Args.has("--cenital"):  # modelos/calles.gd pone la suya
		cam.make_current()
	colocar()
	# la altura del punto: la colisión bajo él (mapa.gd la arma alrededor de la cámara)
	while not mapa.solido(desde.x, desde.y):
		await get_tree().physics_frame
	punto.y = suelo(punto.x, punto.z).y + 1.7
	colocar()
	await png()


func colocar() -> void:
	var b := Basis.from_euler(Vector3(pitch, yaw, 0.0))
	cam.global_transform = Transform3D(b, punto + b.z * largo)


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		if e.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			arrastre = e.pressed
		elif e.pressed and e.button_index == MOUSE_BUTTON_WHEEL_UP:
			largo = maxf(largo * 0.9, 1.0)
		elif e.pressed and e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			largo = minf(largo * 1.1, 5000.0)
	elif e is InputEventMouseMotion and arrastre:
		yaw -= e.relative.x * 0.005
		pitch = clampf(pitch - e.relative.y * 0.005, deg_to_rad(-89.0), deg_to_rad(89.0))
	elif e is InputEventKey and e.pressed and e.physical_keycode == KEY_ESCAPE:
		get_tree().quit()


func _process(d: float) -> void:
	if cam == null or Args.has("--png"):
		return
	var v := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		v.z -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		v.z += 1.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		v.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		v.x += 1.0
	if Input.is_physical_key_pressed(KEY_Q):
		v.y -= 1.0
	if Input.is_physical_key_pressed(KEY_E):
		v.y += 1.0
	var r := RAPIDEZ * (4.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 1.0) * maxf(largo / 40.0, 0.25)
	punto += Basis(Vector3.UP, yaw) * v * r * d
	colocar()
