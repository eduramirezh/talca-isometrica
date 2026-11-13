# Cielo, luz, sombras y niebla del juego (main.gd lo agrega a la escena).
extends Node3D


# cielo, luz y niebla: el sol del nor-nororiente, como en la página (SUND), y una niebla que esconde el borde
func _ready() -> void:
	var cielo := ProceduralSkyMaterial.new()
	cielo.sky_top_color = Color("6f9fd0")
	cielo.sky_horizon_color = Color("e8e2d6")
	cielo.ground_horizon_color = Color("e8e2d6")
	cielo.ground_bottom_color = Color("b9b2a4")
	var sky := Sky.new()
	sky.sky_material = cielo
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color("e8e2d6")
	env.fog_depth_begin = 90
	env.fog_depth_end = 220
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sol := DirectionalLight3D.new()
	sol.light_energy = 0.7
	sol.shadow_enabled = true
	sol.directional_shadow_max_distance = 150
	add_child(sol)
	sol.look_at_from_position(Vector3(0.35, 1.0, -0.9), Vector3.ZERO)  # desde el norte (-Z), un poco al oriente
