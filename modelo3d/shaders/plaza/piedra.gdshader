// Sillares de piedra (la base del quiosco, foto de 2014: bloques gris verdoso con juntas claras) y hormigón con
// textura fina (soleras, pilas). UV de malla.gd: x a lo largo del muro, y la altura, en m. `sillar` en 0 deja solo el
// grano y las manchas (hormigón pintado). El color base es el del vértice.
shader_type spatial;

uniform vec2 sillar = vec2(0.0, 0.0);  // largo y alto de un bloque (0: sin bloques)
uniform float rugoso = 0.9;

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
	vec3 col = COLOR.rgb;
	float h = 0.0;
	vec2 p = UV;
	if (sillar.x > 0.0) {
		vec2 q = p / sillar;
		q.x += mod(floor(q.y), 2.0) * 0.5;
		vec2 f = fract(q);
		float fw = length(fwidth(q));
		float junta = 1.0 - smoothstep(0.0, 0.03 + fw, min(min(f.x, 1.0 - f.x) * sillar.x, min(f.y, 1.0 - f.y) * sillar.y) / max(sillar.x, sillar.y) * 4.0);
		col *= 0.88 + 0.2 * hash(floor(q));
		col = mix(col, col * 1.25 + 0.05, junta * 0.7);
		h = 1.0 - junta;
	}
	vec3 m = wp * 2.3;
	float grano = ruido(m.xz + m.y) * 0.5 + ruido(m.zy * 3.0 + m.x) * 0.5;
	col *= 0.9 + 0.18 * grano;
	ALBEDO = col;
	ROUGHNESS = rugoso;
	SPECULAR = 0.3;
	float hh = h * 0.006;
	vec3 dpx = dFdx(VERTEX), dpy = dFdy(VERTEX);
	float dhx = dFdx(hh), dhy = dFdy(hh);
	vec3 r1 = cross(dpy, NORMAL), r2 = cross(NORMAL, dpx);
	float det = dot(dpx, r1);
	NORMAL = normalize(abs(det) * NORMAL - sign(det) * (dhx * r1 + dhy * r2));
}
