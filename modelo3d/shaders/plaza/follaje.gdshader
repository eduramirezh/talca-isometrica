// Follaje en tarjetas: una textura con transparencia (hojas, agujas, frondas: texturas.gd) multiplicada por el color
// del vértice, recortada por su alfa (sin alpha to coverage: costaba ~1,3 ms por cuadro en la plaza), translúcida a
// contraluz y movida por el viento según la altura sobre el suelo del árbol. Las normales de las tarjetas vienen del
// constructor (salen del centro de la copa): así la copa se ilumina como un volumen y no como planos sueltos.
shader_type spatial;
render_mode cull_disabled;

uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float viento = 1.0;
uniform float corte = 0.45;
uniform float brillo = 0.3;

void vertex() {
	vec3 o = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = max(VERTEX.y - 1.0, 0.0);
	float t = TIME * 1.1 + o.x * 0.13 + o.z * 0.11;
	float rafaga = 0.6 + 0.4 * sin(TIME * 0.37 + o.x * 0.05);
	float temblor = sin(TIME * 4.0 + w.x * 1.7 + w.y * 1.3 + w.z * 1.9) * 0.025;  // las hojas tiemblan
	VERTEX.x += (sin(t) * 0.006 * h * rafaga + temblor) * viento;
	VERTEX.z += (cos(t * 0.83) * 0.005 * h * rafaga + temblor * 0.7) * viento;
}

void fragment() {
	vec4 c = texture(tex, UV);
	ALBEDO = c.rgb * COLOR.rgb;
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = corte;

	ALPHA_TEXTURE_COORDINATE = UV * vec2(textureSize(tex, 0));
	ROUGHNESS = 0.75;
	SPECULAR = brillo;
	BACKLIGHT = c.rgb * COLOR.rgb * 0.55;
}
