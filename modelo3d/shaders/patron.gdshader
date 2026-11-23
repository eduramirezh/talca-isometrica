// Los dibujos de los modelos del entorno de la plaza (catedral.gd, fachadas.gd, calles.gd; materiales.gd patron()):
// el color por vértice como base y un dibujo procedural en coordenadas del mundo, para que de cerca (la cámara a 1,7 m)
// haya ladrillos, losas y baldosas sin texturas que bajar ni importar. Los dibujos se desvanecen cuando miden menos de
// un píxel (fwidth), para que de lejos no titilen. patron: el número de materiales.gd PATRON. Hasta noviembre de 2026
// era un texto dentro de modelos/entorno/materiales.gd.
shader_type spatial;
render_mode blend_mix, cull_back, diffuse_burley, specular_schlick_ggx;
global uniform float noche;  // 0 de día, 1 de noche (ambiente.gd): las ventanas encendidas de «ventana»
uniform int patron = 0;
uniform float rugosidad = 0.9;
uniform float metalico = 0.0;
uniform float especular = 0.5;
uniform float emision = 0.0;
// tinte: en un MultiMesh con datos propios (use_custom_data), los vértices de alfa 0 toman el color de su instancia
// (INSTANCE_CUSTOM, en sRGB): la carrocería de los autos de autos.gd, una malla para todos los colores
uniform bool tinte = false;
varying vec3 wp;
varying vec3 wn;
varying vec3 tinte_v;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	tinte_v = tinte ? INSTANCE_CUSTOM.rgb : vec3(1.0);
}

float h21(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
float vn(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) { float a = 0.5, s = 0.0; for (int i = 0; i < 4; i++) { s += a * vn(p); p *= 2.03; a *= 0.5; } return s; }
// una línea de ancho w (en unidades de la celda) en el borde de cada celda, suavizada por su tamaño en pantalla
float junta(vec2 f, vec2 w, vec2 fw) {
	vec2 d = min(f, 1.0 - f);
	vec2 l = 1.0 - smoothstep(w, w + fw * 1.5, d);
	return max(l.x, l.y);
}

void fragment() {
	vec3 c = COLOR.rgb;
	if (tinte && COLOR.a < 0.5) {
		c = tinte_v;
	}
	c = c * (c * (c * 0.305306011 + 0.682171111) + 0.012522878);  // los colores se dan en sRGB, como en la página
	float r = rugosidad;
	bool suelo = abs(wn.y) > 0.7;
	// en un muro: a lo largo del muro y la altura; en un suelo o techo: el plano (X, Z)
	vec2 t = normalize(vec2(-wn.z, wn.x) + vec2(1e-5));
	vec2 q = suelo ? wp.xz : vec2(dot(wp.xz, t), wp.y);
	if (patron == 0 || patron == 9) {
		c *= 0.93 + 0.13 * fbm(q * 1.3) + 0.04 * (h21(floor(q * 40.0)) - 0.5);
	} else if (patron == 1) {
		vec2 b = q / vec2(0.30, 0.083);
		float fila = floor(b.y);
		b.x += mod(fila, 2.0) * 0.5;
		vec2 id = floor(b);
		vec2 fw = fwidth(b);
		float lejos = smoothstep(0.25, 0.6, max(fw.x * 0.3, fw.y));
		vec3 ladr = c * (0.80 + 0.34 * h21(id)) * (0.94 + 0.12 * fbm(q * 3.0));
		float m = junta(fract(b), vec2(0.018, 0.07), fw);
		ladr = mix(ladr, vec3(0.74, 0.71, 0.66), m);
		c = mix(ladr, c * 0.97, lejos);
	} else if (patron == 2) {
		vec2 b = q / vec2(3.5, 4.5);
		vec2 fw = fwidth(b);
		float m = junta(fract(b), vec2(0.0035, 0.003), fw);
		float man = fbm(q * 0.35) * 0.6 + fbm(q * 2.3) * 0.4;
		c *= 0.86 + 0.22 * man + 0.06 * (h21(floor(q * 60.0)) - 0.5) + 0.05 * (h21(floor(b)) - 0.5);
		c = mix(c, c * 0.55, m * (1.0 - smoothstep(0.02, 0.08, max(fw.x, fw.y))));
	} else if (patron == 3) {
		vec2 b = q / 0.4;
		vec2 fw = fwidth(b);
		float lejos = smoothstep(0.08, 0.3, max(fw.x, fw.y));
		vec2 f = fract(b);
		float m = junta(f, vec2(0.015), fw);
		vec2 k = fract(f * 4.0) - 0.5;
		float boton = 1.0 - smoothstep(0.22, 0.30, length(k));
		vec3 bal = c * (0.92 + 0.10 * h21(floor(b)) + 0.06 * fbm(q * 2.0)) * (1.0 + 0.07 * boton);
		bal = mix(bal, bal * 0.68, m);
		c = mix(bal, c * 0.95, lejos);
	} else if (patron == 4) {
		vec2 b = q / vec2(0.22, 0.38);
		vec2 fw = fwidth(b);
		float lejos = smoothstep(0.15, 0.5, max(fw.x, fw.y));
		float onda = 0.5 + 0.5 * cos(fract(b.x) * 6.2832);
		vec3 te = c * (0.80 + 0.25 * onda) * (0.9 + 0.2 * h21(floor(b)));
		te = mix(te, te * 0.6, junta(fract(b), vec2(0.0, 0.06), fw));
		c = mix(te, c * 0.92, lejos);
	} else if (patron == 5) {
		c *= 0.9 + 0.1 * h21(floor(q * 90.0)) + 0.08 * fbm(q * 4.0);
		r = 0.7;
	} else if (patron == 6) {
		vec2 b = q / vec2(0.25, 0.18);
		b.x += mod(floor(b.y), 2.0) * 0.5;
		vec2 fw = fwidth(b);
		vec2 f = fract(b);
		float esc = smoothstep(0.0, 0.5, length(vec2(f.x - 0.5, f.y * 0.8)));
		c *= mix(0.78 + 0.25 * (1.0 - esc) + 0.1 * h21(floor(b)), 1.0, smoothstep(0.2, 0.6, max(fw.x, fw.y)));
	} else if (patron == 12) {
		float man = fbm(q * 0.25) * 0.55 + fbm(q * 1.7) * 0.45;
		c *= 0.82 + 0.26 * man + 0.10 * (h21(floor(q * 70.0)) - 0.5);
		r = 0.95;
	} else if (patron == 10) {
		c *= 0.92 + 0.08 * step(0.5, fract(q.x / 0.5));
	}
	vec3 em = c * emision;
	if (patron == 13) {
		// el vidrio de una ventana (fachadas_ciudad.gd): oscuro y liso de día; de noche, las de alfa 1 se encienden
		// con una luz cálida, más clara arriba (la lámpara del techo)
		r = 0.12;
		em = vec3(1.0, 0.74, 0.42) * (0.8 + 0.4 * fract(q.y / 2.8)) * noche * step(0.8, COLOR.a) * 1.3;
	}
	ALBEDO = c;
	ROUGHNESS = r;
	METALLIC = metalico;
	SPECULAR = especular;
	EMISSION = em;
}
