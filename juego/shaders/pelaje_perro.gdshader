// El pelaje del perro (perro.gd): un quiltro café claro (leonado), el lomo más oscuro, el pecho, la garganta y el
// vientre crema, las patas blancas desde el carpo (o el corvejón) con una franja crema encima, el hocico gris oscuro casi
// negro con una sombra alrededor de los ojos, la punta de las orejas oscura y la punta de la cola clara.
//
// Por píxel, desde dónde está cada punto con el perro de pie y quieto (pelo.gdshaderinc; ZONAS abajo): las patas cuelgan
// derechas de su articulación, así que su blanco es lo que queda bajo una altura. Hasta noviembre de 2026 eran colores
// por vértice (las funciones pelaje() y pata_tinte() de perro.gd, con los mismos límites): ahora los bordes son irregulares (el blanco de
// las patas, el crema de la garganta, el hocico), el pelo varía un poco de tono y el lomo se oscurece en vetas, con la
// veta del pelo y la luz de pelaje de la gata (difusa envolvente, poco brillo, un borde claro a contraluz); las orejas
// dejan pasar la luz.
shader_type spatial;
render_mode blend_mix, cull_back, diffuse_lambert_wrap, specular_schlick_ggx;

#include "res://shaders/pelo.gdshaderinc"

// ZONAS (UV2.y), todas con pat en el marco del perro (m): 0 el cuerpo, el cuello, la cabeza y las patas; 1 la mandíbula;
// 2 el adentro de las orejas; 3 la cola; 4 las orejas por fuera

const vec3 PELO = vec3(0.784, 0.584, 0.373);  // c8955f
const vec3 LOMO = vec3(0.682, 0.478, 0.275);  // ae7a46
const vec3 CREMA = vec3(0.925, 0.875, 0.784);  // ecdfc8
const vec3 BLANCO = vec3(0.949, 0.933, 0.902);  // f2eee6
const vec3 HOCICO = vec3(0.231, 0.208, 0.2);  // 3b3533
const vec3 MASCARA = vec3(0.416, 0.31, 0.227);  // 6a4f3a
const vec3 PUNTA = vec3(0.306, 0.212, 0.149);  // 4e3626
const vec3 OIDO = vec3(0.863, 0.702, 0.592);  // dcb397

// 1 dentro de [a, b], con bordes de ancho s
float ventana(float a, float b, float s, float x) {
	return smoothstep(a - s, a + s, x) * (1.0 - smoothstep(b - s, b + s, x));
}

vec3 perro(vec3 q) {
	float n1 = fbm3d(q * 8.0 + 3.0, 3).x;
	float n2 = fino(q, 130.0);
	// el pelo varía un poco de tono, en manchas grandes y suaves
	vec3 c = PELO * (0.93 + 0.14 * n1);
	// el tronco: el lomo más oscuro, en vetas a lo largo del cuerpo; el vientre y el pecho crema
	float cuerpo = ventana(-0.14, 0.14, 0.02, q.x) * ventana(-0.4, 0.4, 0.03, q.z) * ventana(0.2, 0.62, 0.02, q.y);
	float vetas = fbm3d(q * vec3(40.0, 40.0, 9.0) + 5.0, 2).x;
	c = mix(c, LOMO * (0.88 + 0.24 * vetas), 0.5 * smoothstep(0.5, 0.58, q.y + (vetas - 0.5) * 0.04) * cuerpo);
	c = mix(c, CREMA, 0.7 * smoothstep(0.34, 0.29, q.y + (n1 - 0.5) * 0.04 + (n2 - 0.5) * 0.008) * smoothstep(0.3, 0.1, q.z) * cuerpo);
	c = mix(c, CREMA, 0.6 * smoothstep(-0.31, -0.37, q.z) * smoothstep(0.55, 0.45, q.y + (n1 - 0.5) * 0.03)
		* smoothstep(0.07, 0.02, abs(q.x)) * cuerpo);
	// la garganta, crema adelante y abajo del eje del cuello (de (0, 0.47, -0.25) a (0, 0.69, -0.42))
	float cuello = ventana(-0.48, -0.22, 0.015, q.z) * ventana(0.42, 0.74, 0.015, q.y);
	float gar = dot(q - vec3(0.0, 0.47, -0.25), vec3(0.0, -0.61, -0.79)) + (n2 - 0.5) * 0.012;
	c = mix(c, CREMA, 0.85 * smoothstep(0.0, 0.05, gar) * cuello);
	// la cabeza: la sombra de los ojos, el hocico gris oscuro y su borde crema abajo
	float cab = smoothstep(0.58, 0.62, q.y) * smoothstep(-0.36, -0.4, q.z);
	for (int i = 0; i < 2; i++) {
		float x = i == 0 ? -0.04 : 0.04;
		float d = length(vec2(q.x - x, (q.y - 0.735) * 1.3)) + abs(q.z + 0.535) * 0.5 + (n2 - 0.5) * 0.006;
		c = mix(c, MASCARA, 0.7 * smoothstep(0.05, 0.02, d) * cab);
	}
	c = mix(c, HOCICO * (0.9 + 0.2 * n2), smoothstep(-0.53, -0.58, q.z + (n1 - 0.5) * 0.012) * cab);
	c = mix(c, CREMA, 0.35 * smoothstep(0.66, 0.62, q.y) * smoothstep(-0.48, -0.53, q.z) * (1.0 - smoothstep(-0.56, -0.6, q.z)) * cab);
	// las puntas de las orejas
	c = mix(c, PUNTA, smoothstep(0.84, 0.9, q.y + (n2 - 0.5) * 0.012));
	// las patas: crema sobre el carpo (o el corvejón) y blancas desde ahí, con el borde del pelo irregular
	float b = q.z < 0.0 ? 0.05 : 0.04;
	float h = q.y + (fino(q + 7.0, 90.0) - 0.5) * 0.014;
	c = mix(c, CREMA, 0.4 * smoothstep(b + 0.12, b + 0.02, h));
	c = mix(c, BLANCO, smoothstep(b + 0.03, b - 0.02, h));
	return c;
}

void fragment() {
	vec3 c;
	// la veta del pelo: a lo largo del cuerpo, y hacia abajo en las patas
	vec3 veta = pat * mix(vec3(1.0, 0.25, 1.0), vec3(1.0, 1.0, 0.25), smoothstep(0.25, 0.32, pat.y));
	if (zona < 0.5 || zona > 3.5) {
		c = perro(pat);
	} else if (zona < 1.5) {
		c = mix(HOCICO, PELO, 0.25) * (0.9 + 0.2 * fino(pat, 300.0));
	} else if (zona < 2.5) {
		float pelos = smoothstep(0.45, 0.75, fino(pat * vec3(1.0, 0.3, 1.0), 700.0));
		c = mix(OIDO, CREMA, pelos * 0.5);
	} else {
		c = mix(perro(pat), CREMA, smoothstep(0.24, 0.34, pat.z - 0.365 + (fino(pat, 80.0) - 0.5) * 0.02));
		veta = pat * vec3(1.0, 1.0, 0.25);
	}
	float g = fino(veta, 1000.0);
	c *= 0.93 + 0.14 * g;
	ALBEDO = lin(c);
	ROUGHNESS = 0.8 - 0.1 * g;
	SPECULAR = 0.3;
	RIM = 0.35;
	RIM_TINT = 0.6;
	if (zona > 1.5 && zona < 2.5 || zona > 3.5) {
		BACKLIGHT = lin(vec3(0.85, 0.5, 0.38)) * 0.5;  // las orejas, al trasluz
	}
}
