// La llama de una tobera del jetpack (vehiculo.gd): un cono (CylinderMesh de 1 m, con la base en la tobera y la punta
// abajo) que se suma a lo que hay detrás, del color de la base (casi blanco) al de la punta (naranjo) y más tenue hacia
// la punta y en los bordes de la silueta, con un temblor que baja por el cono. Va en HDR (energia × fuerza pasa de 1):
// de día se ve contra el cielo y de noche la toma el resplandor (glow) de ambiente.gd. `fuerza` (0 … 1) la pone
// vehiculo.gd según lo que empujan las toberas; la luz que echa sobre el suelo es un OmniLight3D aparte.
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec3 base : source_color = vec3(1.0, 0.82, 0.5);
uniform vec3 punta : source_color = vec3(1.0, 0.28, 0.04);
uniform float energia = 4.0;
uniform float fuerza = 0.0;
varying float largo;

void vertex() {
	largo = 0.5 - VERTEX.y;  // 0 en la tobera, 1 en la punta
}

void fragment() {
	float a = clamp(largo, 0.0, 1.0);
	float borde = abs(dot(NORMAL, VIEW));
	float onda = 0.8 + 0.2 * sin(TIME * 47.0 - a * 14.0);
	ALBEDO = mix(base, punta, a) * energia * fuerza * (1.0 - a) * (0.3 + 0.7 * borde) * onda;
}
