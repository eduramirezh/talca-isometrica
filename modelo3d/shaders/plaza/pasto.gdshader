// El pasto de los prados: dos verdes que se mezclan con ruido en el espacio del mundo, un grano fino que se ve de cerca
// y manchas más secas. Las matas de hojas (pasto_hojas.gdshader) van encima, cerca de la cámara.
shader_type spatial;
render_mode cull_back;

uniform vec3 verde_a : source_color = vec3(0.30, 0.47, 0.18);
uniform vec3 verde_b : source_color = vec3(0.44, 0.60, 0.24);
uniform vec3 seco : source_color = vec3(0.55, 0.55, 0.30);

varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float ruido(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

void fragment() {
	vec2 p = wp.xz;
	float n = ruido(p * 0.25) * 0.5 + ruido(p * 0.9) * 0.3 + ruido(p * 3.1) * 0.2;
	vec3 col = mix(verde_a, verde_b, smoothstep(0.3, 0.75, n));
	col = mix(col, seco, smoothstep(0.62, 0.9, ruido(p * 0.13 + 7.0)) * 0.35);
	float fw = length(fwidth(p * 40.0));
	float grano = mix(hash(floor(p * 40.0)), 0.5, smoothstep(0.3, 1.5, fw));
	col *= 0.94 + 0.12 * grano;
	ALBEDO = col * COLOR.rgb;
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
}
