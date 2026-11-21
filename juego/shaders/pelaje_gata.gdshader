// El pelaje de la gata (gata.gd): Watata, calicó de pelo corto. Blanca en el pecho, el vientre, las patas, el hocico y
// una lista angosta entre los ojos; en el lomo, manchas naranjas y atigradas (café grisáceo con rayas negras) que se
// mezclan en los bordes, con la raya del espinazo oscura; la cola atigrada en anillos con la punta negra; la cabeza
// naranja a la derecha y más oscura a la izquierda, con la M de la frente y las rayas de las mejillas. Como en las fotos.
//
// Por píxel, desde dónde está cada punto con la gata de pie (pelo.gdshaderinc; ZONAS abajo), así que las manchas tienen
// bordes irregulares y las rayas no dependen de cuántos vértices hay. Encima, la veta del pelo (un ruido fino estirado a
// lo largo del pelo) y una luz de pelaje: difusa envolvente, poco brillo y un borde claro a contraluz; las orejas dejan
// pasar la luz (BACKLIGHT), como las de verdad. Las rayas y la veta se apagan cuando miden menos de unos píxeles
// (fwidth), para que de lejos no titilen.
shader_type spatial;
render_mode blend_mix, cull_back, diffuse_lambert_wrap, specular_schlick_ggx;

#include "res://shaders/pelo.gdshaderinc"

// el centro del ojo derecho y su medio ancho y medio alto, en el marco de la cabeza (gata.gd OJO, OJO_R): el borde
// oscuro de los párpados
uniform vec3 ojo = vec3(0.0215, 0.007, -0.045);
uniform vec2 ojo_radio = vec2(0.0105, 0.0095);

// ZONAS (UV2.y): 0 el cuerpo, el cuello y las patas (pat: el punto en el marco de la gata, m); 1 la cabeza y la mandíbula
// (en el marco de la cabeza); 2 y 3 el lado de afuera de la oreja izquierda y la derecha (en el de la oreja: arriba +Y);
// 4 la cola (pat.x: m desde la base, yz: el punto en el marco de su tramo); 5 el adentro de las orejas

const vec3 BLANCO = vec3(0.95, 0.937, 0.91);
const vec3 NARANJO = vec3(0.80, 0.52, 0.26);
const vec3 NARANJO_OSCURO = vec3(0.60, 0.33, 0.14);
const vec3 NARANJO_CLARO = vec3(0.90, 0.69, 0.46);
const vec3 AGUTI = vec3(0.47, 0.40, 0.33);  // el café grisáceo del atigrado (cada pelo con bandas)
const vec3 AGUTI_CLARO = vec3(0.63, 0.56, 0.47);
const vec3 NEGRO = vec3(0.12, 0.10, 0.09);
const vec3 ROSA = vec3(0.86, 0.66, 0.64);

// el cuerpo: blanco abajo, y sobre una línea ondulada que sube hacia la nuca, naranjo o atigrado
vec3 cuerpo(vec3 q) {
	float n1 = fbm3d(q * 12.0 + 1.3, 3).x;
	float n2 = fino(q, 170.0);
	// la línea del blanco: a media altura en los costados, más alta en el pecho (blanco hasta la garganta) y la nuca
	// de color; el muslo de atrás, blanco con color arriba
	float borde = 0.205 + 0.01 * sin(q.z * 31.0 + 0.7) + min(max(-0.115 - q.z, 0.0) * 1.5, 0.075) + (n1 - 0.5) * 0.06
		+ (fbm3d(q * 5.0 + 11.0, 2).x - 0.5) * 0.05;
	float h = q.y - borde + (n2 - 0.5) * 0.014;
	float color = smoothstep(-0.0025, 0.0025, h);
	// naranjo u oscuro: manchas grandes como en las fotos (la izquierda, x < 0, más oscura; el espinazo y la base de la
	// cola, oscuros; la paleta y el anca derechas, naranjas), con un ruido que las rompe y bordes atigrados mezclados
	float d = (fbm3d(q * 7.0 + 7.7, 3).x - 0.5) * 1.3;
	d += 0.45 * exp(-pow(q.x / 0.035, 2.0)) * smoothstep(-0.14, -0.03, q.z);
	d += 0.55 * mancha(q, vec3(0.0, 0.26, 0.17), 0.065);
	d += 0.4 * mancha(q, vec3(-0.08, 0.24, -0.08), 0.055);
	d += 0.35 * mancha(q, vec3(-0.085, 0.22, 0.09), 0.05);
	d += 0.3 * mancha(q, vec3(0.085, 0.235, 0.0), 0.04);
	d -= 0.5 * mancha(q, vec3(0.08, 0.25, -0.09), 0.05);
	d -= 0.4 * mancha(q, vec3(0.075, 0.22, 0.12), 0.045);
	d -= 0.35 * mancha(q, vec3(-0.075, 0.21, 0.02), 0.05);
	d -= 0.3 * mancha(q, vec3(0.0, 0.31, -0.2), 0.04);  // la nuca, naranja
	float oscuro = smoothstep(-0.07, 0.07, d + (fino(q + 3.0, 110.0) - 0.5) * 0.3);
	// las rayas del atigrado: anillos alrededor del cuerpo que se inclinan hacia atrás al bajar por el costado, torcidas
	// y cortadas a ratos (el atigrado de una calicó es manchado, no un tigre), sobre un fondo moteado de negro y con pelos
	// naranjos sueltos
	float s = q.z - 0.3 * (0.28 - q.y) + (fbm3d(q * 18.0, 3).x - 0.5) * 0.035;
	float r = rayas(s, 0.032, 0.4) * smoothstep(0.28, 0.6, fbm3d(q * 22.0 + 4.0, 2).x);
	vec3 atig = mix(AGUTI, NEGRO, r * 0.72);
	atig = mix(atig, NEGRO, smoothstep(0.55, 0.8, fbm3d(q * 40.0 + 9.0, 2).x) * 0.45);
	atig = mix(atig, NARANJO_OSCURO, smoothstep(0.62, 0.82, fbm3d(q * 55.0 + 2.0, 2).x) * 0.55);
	atig = mix(atig, NEGRO, exp(-pow(q.x / 0.013, 2.0)) * smoothstep(0.245, 0.27, q.y) * 0.6);  // la raya del espinazo
	vec3 nar = mix(NARANJO, NARANJO_OSCURO, r * 0.35);
	nar = mix(nar, NARANJO_CLARO, (1.0 - smoothstep(0.0, 0.03, h)) * 0.5);  // más claro junto al blanco
	return mix(BLANCO, mix(nar, atig, oscuro), color);
}

// la cabeza (h en el marco de la cabeza: adelante -Z, la derecha +X)
vec3 cabeza(vec3 h) {
	float ax = abs(h.x);
	float n1 = fbm3d(h * 60.0 + 2.0, 3).x;
	float n2 = fino(h, 500.0);
	float cara = smoothstep(-0.025, -0.045, h.z);
	// el blanco: el hocico (los cojinetes de los bigotes y el mentón), la garganta y la lista entre los ojos, angosta
	// arriba y más ancha al llegar a la nariz
	float hocico = smoothstep(0.003, -0.007, h.y + (n1 - 0.5) * 0.01 - ax * 0.14) * smoothstep(-0.018, -0.038, h.z);
	float bajo = smoothstep(-0.015, -0.026, h.y + (n1 - 0.5) * 0.008 - max(h.z, 0.0) * 0.2);
	float ancho = 0.0022 + max(0.0, 0.008 - h.y) * 0.45;
	float lista = (1.0 - smoothstep(ancho, ancho + 0.0015, ax + (n2 - 0.5) * 0.002)) * smoothstep(0.026, 0.017, h.y) * cara;
	float blanco = max(max(hocico, bajo), lista);
	// naranjo u oscuro: la mitad derecha más naranja, la izquierda y la coronilla más oscuras
	float d = (n1 - 0.5) * 1.2 + 0.08 - 0.25 * smoothstep(-0.005, 0.02, h.x) + 0.3 * smoothstep(0.005, -0.02, h.x) + 0.25 * smoothstep(0.02, 0.045, h.y);
	float oscuro = smoothstep(-0.08, 0.08, d + (n2 - 0.5) * 0.25);
	// la M de la frente y las rayas de la coronilla (a lo largo de la cabeza, x constante) y las de las mejillas, que
	// salen hacia atrás desde el rabillo del ojo
	float frente = rayas(h.x + (n1 - 0.5) * 0.004, 0.0105, 0.3) * smoothstep(0.013, 0.024, h.y) * smoothstep(0.036, 0.022, ax) * 0.8;
	float mejilla = rayas(h.y - 0.22 * (h.z + 0.03) + (n1 - 0.5) * 0.003, 0.0075, 0.32) * smoothstep(0.03, 0.042, ax)
		* (1.0 - smoothstep(0.008, 0.014, h.y)) * smoothstep(-0.016, -0.008, h.y) * (1.0 - smoothstep(-0.012, 0.008, h.z));
	float raya = max(frente, mejilla);
	vec3 atig = mix(AGUTI, NEGRO, raya * 0.8);
	vec3 nar = mix(NARANJO, NARANJO_OSCURO, raya * 0.5);
	vec3 c = mix(mix(nar, atig, oscuro), BLANCO, blanco);
	// el borde negro de los párpados alrededor de cada ojo (adentro, el párpado: el pelo, que se ve al cerrarlo)
	vec2 e = (vec2(ax, h.y) - ojo.xy) / ojo_radio;
	float re = length(e);
	float borde = smoothstep(0.84, 0.92, re) * (1.0 - smoothstep(0.98, 1.06, re));
	c = mix(c, NEGRO, borde * smoothstep(-0.03, -0.04, h.z));
	return c;
}

vec3 oreja(vec3 p, float lado) {
	float n = fbm3d(p * 90.0 + lado * 5.0, 3).x;
	vec3 c = lado > 0.0 ? mix(NARANJO, AGUTI, smoothstep(0.42, 0.62, n)) : mix(AGUTI, NEGRO, smoothstep(0.3, 0.7, n) * 0.7);
	return mix(c, NEGRO, smoothstep(0.026, 0.04, p.y) * 0.85);  // la punta
}

// el adentro de la oreja: piel rosada con pelos blancos que salen de la base y del borde
vec3 oido(vec3 p) {
	float pelos = smoothstep(0.45, 0.75, fino(p * vec3(1.0, 0.3, 1.0), 900.0));
	vec3 c = mix(ROSA, BLANCO, pelos * (1.0 - smoothstep(0.006, 0.024, p.y)) * 0.9);
	return c * mix(0.8, 1.0, smoothstep(0.0, 0.02, p.y));  // más oscuro al fondo
}

vec3 cola(vec3 p) {
	float u = p.x;
	float n = fbm3d(p * vec3(30.0, 120.0, 120.0), 2).x;
	float r = rayas(u + (n - 0.5) * 0.012, 0.034, 0.46);
	vec3 c = mix(AGUTI, NEGRO, r * 0.9);
	c = mix(c, AGUTI_CLARO, smoothstep(0.0, -0.014, p.z) * 0.55 * (1.0 - r));  // abajo, más clara
	c = mix(c, NEGRO, smoothstep(0.255, 0.285, u));  // la punta
	return mix(mix(NARANJO, AGUTI, 0.6), c, smoothstep(0.0, 0.035, u));  // la base, como el anca
}

void fragment() {
	vec3 c;
	vec3 veta = pat;  // el grano del pelo, estirado a lo largo del pelo
	if (zona < 0.5) {
		c = cuerpo(pat);
		veta *= vec3(1.0, 1.0, 0.25);
	} else if (zona < 1.5) {
		c = cabeza(pat);
		veta *= vec3(1.0, 1.0, 0.35);
	} else if (zona < 3.5) {
		c = oreja(pat, zona < 2.5 ? -1.0 : 1.0);
		veta *= vec3(1.0, 0.3, 1.0);
	} else if (zona < 4.5) {
		c = cola(pat);
		veta *= vec3(0.25, 1.0, 1.0);
	} else {
		c = oido(pat);
	}
	float g = fino(veta, 1100.0);
	c *= 0.93 + 0.14 * g;
	ALBEDO = lin(c);
	ROUGHNESS = 0.8 - 0.1 * g;
	SPECULAR = 0.32;
	RIM = 0.4;
	RIM_TINT = 0.65;
	if (zona > 1.5 && zona < 3.5 || zona > 4.5) {
		BACKLIGHT = lin(vec3(0.85, 0.42, 0.36)) * 0.6;
	}
}
