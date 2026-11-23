// El agua de las piletas: una lámina poco profunda y algo transparente (deja ver el fondo pintado de azul) con ondas
// que se mueven y reflejos del cielo. `cae` > 0 la vuelve un chorro o una cortina que cae (UV.y a lo largo): franjas
// que bajan y un borde deshilachado.
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_opaque;

uniform vec3 color : source_color = vec3(0.35, 0.55, 0.62);
uniform float alfa = 0.55;
uniform float cae = 0.0;

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
	if (cae > 0.0) {
		float franja = ruido(vec2(UV.x * 40.0, UV.y * 3.0 - TIME * 4.0 * cae));
		ALBEDO = vec3(0.85, 0.92, 0.95);
		ALPHA = (0.25 + 0.45 * franja) * smoothstep(0.0, 0.08, UV.y);
		ROUGHNESS = 0.1;
		EMISSION = vec3(0.05);
	} else {
		vec2 p = wp.xz;
		float t = TIME;
		vec2 g = vec2(
			sin(p.x * 3.1 + t * 1.3) + sin(p.y * 2.3 - t * 1.7) * 0.6 + (ruido(p * 4.0 + t) - 0.5) * 1.5,
			cos(p.y * 2.9 + t * 1.1) + cos(p.x * 2.1 + t * 1.9) * 0.6 + (ruido(p * 4.0 - t) - 0.5) * 1.5);
		NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4(g.x * 0.05, 0.0, g.y * 0.05, 0.0)).xyz);
		ALBEDO = color;
		ALPHA = alfa;
		ROUGHNESS = 0.04;
		SPECULAR = 0.7;
		METALLIC = 0.0;
	}
}
