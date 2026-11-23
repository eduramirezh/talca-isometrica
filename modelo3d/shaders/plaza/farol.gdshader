// El vidrio de los faroles de la plaza: de día un vidrio lechoso, de noche encendido. `noche` es el parámetro global
// que pone ambiente.gd (0 de día, 1 de noche; [shader_globals] de project.godot).
shader_type spatial;

global uniform float noche;

void fragment() {
	ALBEDO = vec3(0.95, 0.92, 0.82);
	ROUGHNESS = 0.15;
	EMISSION = vec3(1.0, 0.82, 0.55) * mix(0.1, 7.0, noche);
}
