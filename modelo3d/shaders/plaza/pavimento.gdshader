// Las baldosas de la Plaza de Armas, dibujadas en el espacio del mundo (metros de grilla): baldosas de 40 cm con un
// meandro en bajorrelieve (fotos de Commons de 2013, 2014 y 2024: «Talca, plaza (15711413856)», «Plaza de armas de
// Talca2», «Plaza de Armas de Talca en 2024 04»), bandas de baldosas rojizas cada 6 m que forman los cuadros grandes
// (el hito de la página las pone cada 6 m; en la foto de 2018 «Talca Plaza (5)» son de un rosado terroso) y un tono
// distinto por baldosa con manchas de desgaste. Aproximado: el dibujo exacto del meandro (aquí, una espiral cuadrada que
// alterna su giro de una baldosa a la otra) y el ancho de las bandas (dos baldosas).
shader_type spatial;
render_mode cull_back;

uniform vec3 base_col : source_color = vec3(0.76, 0.74, 0.70);
uniform vec3 banda_col : source_color = vec3(0.62, 0.52, 0.47);
uniform float baldosa = 0.4;     // m
uniform float paso_banda = 6.0;  // m entre bandas
uniform float relieve = 1.0;

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

float seg(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a, ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}

// distancia al meandro dentro de una baldosa (coordenadas 0..1)
float meandro(vec2 f) {
	float d = seg(f, vec2(0.0, 0.5), vec2(0.18, 0.5));
	d = min(d, seg(f, vec2(0.18, 0.5), vec2(0.18, 0.18)));
	d = min(d, seg(f, vec2(0.18, 0.18), vec2(0.82, 0.18)));
	d = min(d, seg(f, vec2(0.82, 0.18), vec2(0.82, 0.82)));
	d = min(d, seg(f, vec2(0.82, 0.82), vec2(0.36, 0.82)));
	d = min(d, seg(f, vec2(0.36, 0.82), vec2(0.36, 0.36)));
	d = min(d, seg(f, vec2(0.36, 0.36), vec2(0.64, 0.36)));
	d = min(d, seg(f, vec2(0.64, 0.36), vec2(0.64, 0.62)));
	d = min(d, seg(f, vec2(0.82, 0.5), vec2(1.0, 0.5)));
	return d;
}

void fragment() {
	vec2 p = vec2(wp.x, -wp.z);
	vec2 q = p / baldosa;
	vec2 id = floor(q);
	vec2 f = fract(q);
	// el meandro gira un cuarto de vuelta en baldosas alternadas (se lee como una greca continua)
	if (mod(id.x + id.y, 2.0) > 0.5) f = vec2(f.y, 1.0 - f.x);
	float fw = max(length(fwidth(q)), 1e-4);
	float lejos = smoothstep(0.06, 0.25, fw);  // a lo lejos el dibujo se funde en su tono medio
	float ranura = 1.0 - smoothstep(0.035, 0.035 + fw * 1.5, meandro(f));
	vec2 fb = fract(q);
	float junta = 1.0 - smoothstep(0.0, 0.012 + fw, min(min(fb.x, 1.0 - fb.x), min(fb.y, 1.0 - fb.y)));

	vec2 m6 = abs(p - paso_banda * round(p / paso_banda));
	float banda = step(min(m6.x, m6.y), baldosa * 0.999);
	vec3 col = mix(base_col, banda_col, banda);
	col *= 0.94 + 0.12 * hash(id);                     // cada baldosa con su tono
	float mancha = ruido(p * 0.35) * 0.6 + ruido(p * 1.7) * 0.4;
	col *= 0.9 + 0.16 * mancha;                        // desgaste y suciedad
	float oscuro = mix(ranura * 0.14 + junta * 0.25, 0.04, lejos);
	col *= 1.0 - oscuro;
	ALBEDO = col;
	ROUGHNESS = 0.88 - 0.1 * ranura;
	SPECULAR = 0.35;

	// bajorrelieve: la ranura y la junta hundidas 3 mm (gradiente de superficie, sin textura de normales)
	float h = -(ranura + junta) * 0.003 * relieve * (1.0 - lejos);
	vec3 dpx = dFdx(VERTEX), dpy = dFdy(VERTEX);
	float dhx = dFdx(h), dhy = dFdy(h);
	vec3 r1 = cross(dpy, NORMAL), r2 = cross(NORMAL, dpx);
	float det = dot(dpx, r1);
	vec3 grad = sign(det) * (dhx * r1 + dhy * r2);
	NORMAL = normalize(abs(det) * NORMAL - grad);
}
