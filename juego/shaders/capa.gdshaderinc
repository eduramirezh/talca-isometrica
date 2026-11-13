// El cuerpo de capa.gdshader y follaje.gdshader (ver capa.gdshader).

#include "res://shaders/ruido.gdshaderinc"

global uniform float noche;       // 0 de día, 1 de noche (ventanas encendidas)
global uniform vec3 sol_dir;

uniform int tipo = 0;
uniform int clase = -1;
uniform bool color_vertice = true;
uniform vec4 color : source_color = vec4(1.0);
uniform vec2 ventana_cada = vec2(3.4, 3.0);   // m (ancho, alto de cada vano con su muro)
uniform float ventana_desde = 1.0;            // m sobre el origen (la plaza)
uniform float viento = 1.0;                   // cuánto se mecen las copas
uniform float detalle = 1.0;                  // multiplica el relieve procedural

const int C_ESTUCO = 0;
const int C_ASFALTO = 1;
const int C_BALDOSA = 2;
const int C_PASTO = 3;
const int C_TIERRA = 4;
const int C_AGUA = 5;
const int C_TEJA = 6;
const int C_ZINC = 7;
const int C_FOLLAJE = 8;
const int C_CORTEZA = 9;
const int C_PINTURA = 10;
const int C_VIDRIO = 11;
const int C_TECHO = 12;
const int C_PIEDRA = 13;

varying vec3 wp;
varying vec3 wn;
varying float verde;

vec3 a_srgb(vec3 c) { return pow(max(c, vec3(0.0)), vec3(1.0 / 2.2)); }

int clasificar(vec3 lin, vec3 n, vec3 p) {
	vec3 s = a_srgb(lin);
	float mx = max(s.r, max(s.g, s.b));
	float mn = min(s.r, min(s.g, s.b));
	float sat = (mx - mn) / (mx + 1e-3);
	float lum = dot(s, vec3(0.299, 0.587, 0.114));
	bool es_verde = s.g > s.r * 1.04 && s.g > s.b * 1.12;
	bool es_azul = s.b > s.r * 1.25 && s.b > s.g * 1.05 && sat > 0.2;
	bool es_rojizo = s.r > s.g * 1.12 && s.r > s.b * 1.2;
	if (tipo == 3) {
		return es_verde || s.g >= s.r ? C_FOLLAJE : C_CORTEZA;
	}
	if (tipo == 4) {
		return (lum < 0.16 || (es_azul && lum < 0.3)) ? C_VIDRIO : C_PINTURA;
	}
	if (n.y > 0.8) {
		if (es_azul) return C_AGUA;
		if (es_verde) return C_PASTO;
		if (tipo == 1 && p.y > 2.5) return C_TECHO;
		if (lum < 0.44 && sat < 0.16) return C_ASFALTO;
		if (lum > 0.6 && sat < 0.21) return C_BALDOSA;
		if (s.r >= s.g && s.g >= s.b && sat > 0.12) return C_TIERRA;
		return C_ESTUCO;
	}
	if (n.y > 0.25) {  // techos inclinados
		if (es_rojizo && sat > 0.25) return C_TEJA;
		if (lum < 0.5) return C_ZINC;
		return C_ESTUCO;
	}
	if (tipo == 2 && sat < 0.1 && lum > 0.5 && lum < 0.75) return C_PIEDRA;
	return C_ESTUCO;
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	verde = 0.0;
	if (tipo == 3) {
		vec3 s = a_srgb(color_vertice ? COLOR.rgb : color.rgb);
		verde = step(s.r, s.g);
		// las copas se mecen: una onda lenta que recorre la plaza y un temblor rápido por árbol
		float fase = wp.x * 0.07 + wp.z * 0.05;
		vec2 m = vec2(sin(TIME * 0.9 + fase), cos(TIME * 0.7 + fase * 1.3)) * 0.07
			+ vec2(sin(TIME * 3.1 + wp.y * 2.0 + wp.x), sin(TIME * 2.7 + wp.z)) * 0.02;
		vec3 desp = vec3(m.x, 0.0, m.y) * verde * viento;
		VERTEX += (inverse(MODEL_MATRIX) * vec4(desp, 0.0)).xyz;
	}
}

// inclina la normal n con un gradiente g en el mundo (solo la parte tangente)
vec3 relieve(vec3 n, vec3 g, float k) {
	g -= dot(g, n) * n;
	return normalize(n - g * k * detalle);
}

void fragment() {
	vec3 base = color_vertice ? COLOR.rgb : color.rgb;
	vec3 n = normalize(wn);
	int k = clase >= 0 ? clase : clasificar(base, n, wp);
	float dist = length(VERTEX);
	float fino = 1.0 - smoothstep(25.0, 70.0, dist);  // el detalle de pocos cm se apaga de lejos
	vec3 alb = base;
	float rug = 0.9;
	float met = 0.0;
	float spec = 0.5;
	vec3 emi = vec3(0.0);
	float ao = 1.0;
	vec3 g = vec3(0.0);
	float kr = 0.0;
	float cc = 0.0;

	if (k == C_ASFALTO) {
		vec3 m = fbm2d(wp.xz * 0.35, 3);           // parches de 3 m
		vec3 f = ruido2d(wp.xz * 22.0);            // árido de 5 cm
		vec3 ff = ruido2d(wp.xz * 70.0);
		alb *= 0.86 + 0.22 * m.x + (f.x - 0.5) * 0.18 * fino + (ff.x - 0.5) * 0.12 * fino;
		alb *= vec3(1.0, 0.99, 0.97);
		g = vec3(f.y, 0.0, f.z) * 22.0 * 0.0015 * fino + vec3(ff.y, 0.0, ff.z) * 70.0 * 0.0006 * fino;
		kr = 1.0;
		rug = 0.82 + 0.1 * m.x;
		// manchas de aceite y desgaste
		float mancha = smoothstep(0.62, 0.75, fbm2(wp.xz * 0.12 + 9.0, 4));
		alb *= 1.0 - 0.2 * mancha;
		rug -= 0.25 * mancha;
	} else if (k == C_BALDOSA) {
		// adoquín de hormigón de 20 × 10 cm en hiladas trabadas, cada uno de un tono algo distinto
		vec2 q = wp.xz / vec2(0.2, 0.1);
		q.x += 0.5 * step(0.5, fract(q.y * 0.5));
		vec2 id = floor(q);
		float h = hash12(id);
		float j = juntas(q, 0.07);
		vec3 f = ruido2d(wp.xz * 30.0);
		alb *= vec3(0.78, 0.78, 0.8);
		alb *= mix(1.0, (0.9 + 0.18 * h) * (1.0 - 0.3 * j), fino) * (0.97 + 0.06 * f.x * fino);
		alb *= 0.88 + 0.16 * fbm2(wp.xz * 0.25, 3);  // suciedad y desgaste
		vec2 fr = fract(q) - 0.5;
		vec2 borde = sign(fr) * smoothstep(0.38, 0.5, abs(fr)) / vec2(0.2, 0.1);
		g = vec3(borde.x, 0.0, borde.y) * 0.004 * fino + vec3(f.y, 0.0, f.z) * 30.0 * 0.0008 * fino;
		kr = 1.0;
		rug = 0.8 + 0.1 * h;
	} else if (k == C_PASTO) {
		vec3 m = fbm2d(wp.xz * 0.18, 4);
		vec3 f = ruido2d(wp.xz * 9.0);
		vec3 ff = ruido2d(wp.xz * 45.0);
		vec3 s = a_srgb(alb);
		// tono más natural: menos saturado, con manchas secas y matas oscuras
		float l = dot(alb, vec3(0.3, 0.6, 0.1));
		alb = mix(vec3(l), alb, 0.8) * vec3(0.72, 0.8, 0.62);
		alb *= 0.78 + 0.42 * m.x;
		alb = mix(alb, alb * vec3(1.25, 1.05, 0.7), smoothstep(0.55, 0.8, fbm2(wp.xz * 0.07 + 3.0, 3)) * 0.6);
		alb *= 0.85 + 0.3 * mix(0.5, f.x, fino) ;
		alb *= 0.9 + 0.2 * mix(0.5, ff.x, fino);
		g = vec3(f.y, 0.0, f.z) * 9.0 * 0.01 * fino + vec3(ff.y, 0.0, ff.z) * 45.0 * 0.004 * fino;
		kr = 1.0;
		rug = 0.95;
		spec = 0.3;
	} else if (k == C_TIERRA) {
		vec3 m = fbm2d(wp.xz * 0.3, 4);
		vec3 f = ruido2d(wp.xz * 25.0);
		alb *= 0.85 + 0.25 * m.x + (f.x - 0.5) * 0.2 * fino;
		g = vec3(m.y, 0.0, m.z) * 0.3 * 0.15 + vec3(f.y, 0.0, f.z) * 25.0 * 0.002 * fino;
		kr = 1.0;
		rug = 0.97;
		spec = 0.3;
	} else if (k == C_AGUA) {
		vec2 t = vec2(TIME * 0.35, TIME * 0.21);
		vec3 o1 = ruido2d(wp.xz * 1.6 + t);
		vec3 o2 = ruido2d(wp.xz * 3.7 - t * 1.3);
		g = vec3(o1.y + o2.y * 0.6, 0.0, o1.z + o2.z * 0.6) * 0.06;
		kr = 1.0;
		alb = base * 0.5;
		rug = 0.04;
		spec = 0.6;
	} else if (k == C_TEJA) {
		// teja colonial: filas a lo largo de la pendiente, canales cada 25 cm, hiladas cada 40 cm
		vec3 cae = normalize(vec3(n.x, 0.0, n.z) + 1e-4);
		vec3 lado = normalize(cross(vec3(0.0, 1.0, 0.0), cae));
		float u = dot(wp, lado) / 0.25;
		float v = dot(wp, cae) / 0.4 + 0.5 * step(0.5, fract(u * 0.5));
		float onda = sin(u * 6.2832);
		float hilada = fract(v);
		alb *= (0.85 + 0.15 * hash12(floor(vec2(u, v)))) * (0.88 + 0.12 * onda) * (1.0 - 0.25 * smoothstep(0.85, 1.0, hilada));
		alb *= 0.9 + 0.2 * fbm2(wp.xz * 0.4, 3);
		g = lado * cos(u * 6.2832) * 0.6 * fino + cae * smoothstep(0.85, 1.0, hilada) * 0.8 * fino;
		kr = 1.0;
		rug = 0.75;
	} else if (k == C_ZINC) {
		// planchas onduladas de zinc pintado
		vec3 cae = normalize(vec3(n.x, 0.0, n.z) + 1e-4);
		vec3 lado = normalize(cross(vec3(0.0, 1.0, 0.0), cae));
		float u = dot(wp, lado) / 0.076;
		g = lado * cos(u * 6.2832) * 0.5 * fino;
		kr = 1.0;
		alb *= 0.9 + 0.15 * fbm2(wp.xz * 0.3, 3);
		rug = 0.45;
		met = 0.5;
	} else if (k == C_TECHO) {
		// techo plano: membrana con gravilla y manchas de agua
		vec3 m = fbm2d(wp.xz * 0.25, 4);
		vec3 f = ruido2d(wp.xz * 18.0);
		alb *= 0.8 + 0.3 * m.x + (f.x - 0.5) * 0.15 * fino;
		g = vec3(f.y, 0.0, f.z) * 18.0 * 0.002 * fino;
		kr = 1.0;
		rug = 0.9;
	} else if (k == C_FOLLAJE) {
		// copas: racimos de hojas como relieve (la forma redonda la dan las normales de ambiente.gd/copas()), huecos
		// oscuros entre ellos, un tono por árbol y por racimo, y luz que atraviesa del lado del sol
		vec4 rr = ruido3d(wp * 3.2);
		vec4 r3 = ruido3d(wp * 9.0 + 4.0);
		float racimo = smoothstep(0.2, 0.8, rr.x * 0.75 + r3.x * 0.35);
		alb = mix(alb, vec3(dot(alb, vec3(0.3, 0.6, 0.1))), 0.1) * vec3(0.72, 0.86, 0.62);
		alb *= 0.62 + 0.5 * racimo;
		alb *= 0.92 + 0.16 * r3.x * fino;
		float t = hash13(floor(wp * 0.15));
		alb *= mix(vec3(1.0), vec3(1.12, 1.05, 0.8), t * 0.7);
		g = rr.yzw * 3.2 * 0.09 + r3.yzw * 9.0 * 0.02 * fino;
		kr = 1.0;
		rug = 0.8;
		spec = 0.25;
		ao = (0.55 + 0.45 * racimo) * (0.45 + 0.55 * smoothstep(-0.7, 0.5, n.y));
		alb *= 0.6 + 0.4 * smoothstep(-0.8, 0.3, n.y);  // la parte de abajo de la copa, en su propia sombra
	} else if (k == C_CORTEZA) {
		vec2 q = vec2(atan(n.x, n.z) * 3.0, wp.y * 6.0);
		vec3 f = ruido2d(vec2(q.x * 3.0 + wp.x * 4.0, wp.y * 2.5 + wp.z * 4.0));
		alb *= 0.75 + 0.4 * f.x;
		g = vec3(0.0, 1.0, 0.0) * f.z * 0.05;
		kr = 1.0;
		rug = 0.95;
	} else if (k == C_PINTURA) {
		rug = 0.28;
		met = 0.35;
		cc = 1.0;
		spec = 0.6;
	} else if (k == C_VIDRIO) {
		alb = base * 0.5;
		rug = 0.05;
		spec = 0.9;
	} else {
		// estuco y hormigón: manchas grandes, granos finos, chorreaduras bajo las ventanas
		vec3 a = abs(n);
		vec2 q = a.x > a.z ? wp.zy : wp.xy;
		if (a.y > 0.8) q = wp.xz;
		vec3 m = fbm2d(q * 0.35, 4);
		vec3 f = ruido2d(q * 16.0);
		alb *= 0.9 + 0.16 * m.x + (f.x - 0.5) * 0.08 * fino;
		vec4 r3 = ruido3d(wp * 16.0);
		g = r3.yzw * 16.0 * 0.0012 * fino + vec3(m.y, m.z, m.y) * 0.002;
		kr = 1.0;
		rug = 0.88;
		if (k == C_PIEDRA) {
			// sillería: bloques de 60 × 30 cm
			vec2 b = vec2(dot(wp.xz, normalize(vec2(-n.z, n.x))) / 0.6, wp.y / 0.3);
			b.x += 0.5 * step(0.5, fract(b.y * 0.5));
			float j = juntas(b, 0.06);
			alb *= (1.0 - 0.25 * j) * (0.92 + 0.12 * hash12(floor(b)));
		}
	}

	// ventanas en las fachadas (como winMat() de la página: toda cara vertical sobre ventana_desde)
	if (tipo == 1 && abs(n.y) < 0.3 && wp.y > ventana_desde) {
		vec2 t = normalize(vec2(-n.z, n.x));
		float u = dot(wp.xz, t);
		float v = wp.y - ventana_desde;
		vec2 c = vec2(u, v) / ventana_cada;
		vec2 id = floor(c);
		vec2 f = fract(c);
		// en metros dentro del vano
		vec2 fm = f * ventana_cada;
		vec2 a0 = vec2(0.26, 0.28) * ventana_cada, a1 = vec2(0.74, 0.80) * ventana_cada;
		float marco = 0.07;
		float vano = banda_aa(a0.x, a1.x, fm.x) * banda_aa(a0.y, a1.y, fm.y);
		float vidrio = banda_aa(a0.x + marco, a1.x - marco, fm.x) * banda_aa(a0.y + marco, a1.y - marco, fm.y);
		float h = hash12(id + floor(wp.xz * 0.013) * 7.0);
		float h2 = hash12(id * 1.7 + 3.1 + floor(wp.xz * 0.013));
		// travesaño al medio en la mitad de las ventanas
		float mid = (a0.x + a1.x) * 0.5;
		vidrio *= 1.0 - step(0.5, h2) * banda_aa(mid - 0.03, mid + 0.03, fm.x);
		// alféizar: una franja clara bajo el vano, que sobresale
		float alf = banda_aa(a0.x - 0.08, a1.x + 0.08, fm.x) * banda_aa(a0.y - 0.09, a0.y, fm.y);
		alb = mix(alb, vec3(0.75, 0.73, 0.68), alf);
		g += vec3(0.0, -1.0, 0.0) * alf * 0.0;
		// chorreadura bajo el alféizar
		float chorro = banda_aa(a0.x, a1.x, fm.x) * (1.0 - smoothstep(0.0, 1.2, a0.y - 0.09 - fm.y)) * step(fm.y, a0.y - 0.09);
		alb *= 1.0 - 0.1 * chorro * ruido2(vec2(fm.x * 9.0, fm.y * 0.8)) * fino;
		// el marco, más oscuro o blanco según la casa
		vec3 cmarco = mix(vec3(0.85, 0.84, 0.8), vec3(0.12, 0.11, 0.1), step(0.6, hash12(floor(wp.xz * 0.05) + 1.3)));
		alb = mix(alb, cmarco, vano - vidrio);
		rug = mix(rug, 0.6, vano - vidrio);
		// el vidrio: refleja el cielo; adentro, cortinas o la pieza oscura
		vec3 dentro = mix(vec3(0.02, 0.022, 0.025), vec3(0.45, 0.4, 0.33), step(0.55, h) * 0.6);
		float persiana = step(0.82, h) * step(0.5, fract((fm.y - a0.y) / 0.06));
		dentro = mix(dentro, vec3(0.5, 0.48, 0.44), persiana * 0.7);
		// sombra del dintel arriba y a un lado: el vidrio está retirado del muro
		float sombra = smoothstep(a1.y - marco - 0.25, a1.y - marco, fm.y) * 0.6;
		dentro *= 1.0 - sombra;
		alb = mix(alb, dentro, vidrio);
		rug = mix(rug, 0.04, vidrio);
		spec = mix(spec, 0.8, vidrio);
		kr = mix(kr, 0.0, vidrio);
		// de noche se encienden unas cuantas
		float on = step(0.55, h) * noche;
		vec3 calida = mix(vec3(1.0, 0.72, 0.38), vec3(0.85, 0.9, 1.0), step(0.85, h));
		emi += vidrio * on * calida * (1.2 + 1.5 * h) * mix(1.0, 0.6, persiana);
		ao = mix(ao, 1.0, vidrio);
	}

	vec3 nw = relieve(n, g, kr);
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	ALBEDO = alb;
	ROUGHNESS = rug;
	METALLIC = met;
	SPECULAR = spec;
	EMISSION = emi;
	AO = ao;
	AO_LIGHT_AFFECT = 0.3;
	if (cc > 0.0) {
		CLEARCOAT = cc;
		CLEARCOAT_ROUGHNESS = 0.08;
	}
	if (k == C_FOLLAJE) {
		BACKLIGHT = alb * 0.6;
	}
}
