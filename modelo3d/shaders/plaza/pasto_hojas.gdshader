// Las matas de pasto (MultiMesh sobre los prados): color por vértice, más oscuro abajo, y un vaivén con el viento que
// crece con la altura de la hoja. Se desvanecen con la distancia (visibility_range) y el pasto plano sigue debajo.
shader_type spatial;
render_mode cull_disabled;

uniform float viento = 1.0;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float t = TIME * 1.7 + w.x * 0.21 + w.z * 0.17;
	float k = VERTEX.y * VERTEX.y * 3.0 * viento;
	VERTEX.x += sin(t) * 0.04 * k;
	VERTEX.z += cos(t * 0.8) * 0.03 * k;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.9;
	SPECULAR = 0.25;
	BACKLIGHT = COLOR.rgb * 0.2;
}
