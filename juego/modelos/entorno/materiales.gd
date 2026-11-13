# Materiales de los modelos del entorno de la plaza (catedral.gd, fachadas.gd, calles.gd): un solo sombreador con el
# color por vértice como base y un dibujo procedural en coordenadas del mundo, para que de cerca (la cámara a 1,7 m)
# haya ladrillos, losas y baldosas sin texturas que bajar ni importar. Los dibujos se desvanecen cuando miden menos
# de un píxel (fwidth), para que de lejos no titilen.
#
#   var M := preload("res://modelos/entorno/materiales.gd")
#   M.mat("ladrillo")   # el material (uno por nombre, compartido)
#
# Dibujos (PATRON): liso (revoque con manchas suaves), ladrillo (0,29 × 0,07 m, trabado, cantería de mortero),
# hormigon (losas de calzada de 3,5 × 4,5 m con juntas y manchas: OSM dice surface=concrete en las cuatro calles, y
# se ven en la foto de 1 Norte de 2022 en Commons), baldosa (40 × 40 cm con 16 botones, la «baldosa microvibrada» de
# las veredas de Talca, foto de 1 Norte), teja (hileras de teja de arcilla), granito (soleras y peldaños), pizarra
# (escamas del chapitel), asfalto (1 Oriente: OSM dice surface=asphalt al sur de la plaza, y las fotos de 2022 de la
# esquina de 1 Norte lo muestran también al norte), metal y vidrio (sin dibujo).
extends RefCounted

const PATRON := {"liso": 0, "ladrillo": 1, "hormigon": 2, "baldosa": 3, "teja": 4, "granito": 5, "pizarra": 6,
	"metal": 7, "vidrio": 8, "pintura": 9, "tela": 10, "emisivo": 11, "asfalto": 12}

const CODIGO := """
shader_type spatial;
render_mode blend_mix, cull_back, diffuse_burley, specular_schlick_ggx;
uniform int patron = 0;
uniform float rugosidad = 0.9;
uniform float metalico = 0.0;
uniform float especular = 0.5;
uniform float emision = 0.0;
varying vec3 wp;
varying vec3 wn;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
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
	ALBEDO = c;
	ROUGHNESS = r;
	METALLIC = metalico;
	SPECULAR = especular;
	EMISSION = c * emision;
}
"""

static var _cache := {}


static func mat(nombre: String) -> Material:
	if _cache.has(nombre):
		return _cache[nombre]
	var m: Material
	if nombre == "vidrio":
		var s := StandardMaterial3D.new()
		s.vertex_color_use_as_albedo = true
		s.vertex_color_is_srgb = true
		s.metallic = 0.55
		s.roughness = 0.06
		s.metallic_specular = 0.8
		m = s
	else:
		var sh := Shader.new()
		sh.code = CODIGO
		var sm := ShaderMaterial.new()
		sm.shader = sh
		sm.set_shader_parameter("patron", PATRON.get(nombre, 0))
		var rug := {"metal": 0.38, "pintura": 0.55, "granito": 0.7, "emisivo": 0.5, "pizarra": 0.6}
		sm.set_shader_parameter("rugosidad", rug.get(nombre, 0.88))
		sm.set_shader_parameter("metalico", 0.45 if nombre == "metal" else 0.0)
		if nombre == "emisivo":
			sm.set_shader_parameter("emision", 0.9)
		m = sm
	_cache[nombre] = m
	return m
