// El cielo de Talca: el degradado de la atmósfera según la altura del sol (día, atardecer, noche), el disco del sol y
// su halo, cúmulos que se mueven con el viento, la cordillera de los Andes al oriente y la de la Costa al poniente, y
// estrellas de noche. Lo usa ambiente.gd; también ilumina la escena (luz ambiente y reflejos del cielo).
//
// Coordenadas del juego: X al oriente de la grilla, -Z al norte de la grilla; la grilla está girada 5° (el norte
// verdadero queda 5° al poniente del norte de la grilla).
shader_type sky;
render_mode use_debanding;

#include "res://shaders/ruido.gdshaderinc"

global uniform vec3 sol_dir;   // hacia el sol (normalizado), en el mundo
global uniform vec3 luna_dir;  // hacia la luna
global uniform float noche;    // 0 de día, 1 de noche

uniform float cobertura : hint_range(0.0, 1.0) = 0.38;  // fracción del cielo con nubes
uniform float nubes_altura = 1800.0;                     // m
uniform vec2 viento = vec2(9.0, 3.0);                    // m/s (en X y Z del juego): del sur poniente, como la brisa de la tarde
uniform float brillo = 1.0;

// colores del cielo en el cénit y el horizonte para una altura del sol h (seno de su elevación)
void colores(float h, out vec3 cenit, out vec3 horiz) {
	vec3 cenit_dia = vec3(0.045, 0.16, 0.55);
	vec3 horiz_dia = vec3(0.42, 0.56, 0.74);
	vec3 cenit_tarde = vec3(0.12, 0.17, 0.38);
	vec3 horiz_tarde = vec3(0.95, 0.52, 0.28);
	vec3 cenit_noche = vec3(0.0025, 0.004, 0.012);
	vec3 horiz_noche = vec3(0.006, 0.010, 0.022);
	float dia = smoothstep(0.02, 0.35, h);
	float crep = smoothstep(-0.22, 0.02, h);
	cenit = mix(mix(cenit_noche, cenit_tarde, crep), cenit_dia, dia);
	horiz = mix(mix(horiz_noche, horiz_tarde * 0.6, crep), horiz_dia, dia);
}

// color de la luz del sol que llega a una altura h: blanca arriba, naranja al ponerse
vec3 color_sol(float h) {
	vec3 bajo = vec3(1.0, 0.42, 0.14);
	vec3 alto = vec3(1.0, 0.95, 0.88);
	return mix(bajo, alto, smoothstep(0.0, 0.45, h)) * smoothstep(-0.04, 0.03, h);
}

// la cordillera: elevación aparente (radianes) en el azimut verdadero az (0 norte, π/2 oriente)
float cordillera(float az, out float nieve) {
	float e = sin(az);  // >0 al oriente
	nieve = 0.0;
	if (e > 0.0) {
		// los Andes, a unos 80 km: cumbres de 3.000 a 4.000 m, más bajas hacia el norte y el sur (más lejos)
		float a = az * 9.0;
		float r = 1.0 - abs(ruido2(vec2(a, 1.3)) * 2.0 - 1.0);  // crestas
		float perfil = 0.016 + 0.010 * fbm2(vec2(a * 0.7, 4.1), 4) + 0.008 * r * r;
		// el Descabezado Grande (3.953 m, con la cumbre cortada) y el cerro Azul, al oriente sur oriente
		float dg = 1.0 - smoothstep(0.012, 0.03, abs(az - radians(103.0)));
		float ca = 1.0 - smoothstep(0.0, 0.035, abs(az - radians(110.0)));
		perfil = max(perfil, 0.038 * dg);
		perfil = max(perfil, 0.034 * ca * ca);
		float alto = perfil * e;
		nieve = smoothstep(0.024, 0.032, perfil);
		return alto;
	}
	// la cordillera de la Costa, a unos 35 km: lomas de 500 a 800 m
	return (0.006 + 0.008 * fbm2(vec2(az * 6.0, 7.7), 4)) * -e;
}

float densidad_nubes(vec2 p, int oct) {
	// p en km; deformado para que no sean manchas redondas
	vec2 q = p + 0.6 * vec2(fbm2(p * 0.5 + 3.1, 3), fbm2(p * 0.5 - 1.7, 3));
	float d = fbm2(q * 0.55, oct);
	return smoothstep(1.0 - cobertura - 0.08, 1.0 - cobertura + 0.22, d + 0.25);
}

void sky() {
	vec3 d = EYEDIR;
	vec3 s = normalize(sol_dir);
	float h = s.y;
	vec3 cenit, horiz;
	colores(h, cenit, horiz);
	vec3 csol = color_sol(h);

	float alt = max(d.y, 0.0);
	float g = pow(1.0 - alt, 5.0);
	vec3 col = mix(cenit, horiz, g);
	float mu = dot(d, s);
	// el resplandor del atardecer hacia el sol, sobre el horizonte
	float tarde = (1.0 - smoothstep(0.0, 0.3, h)) * smoothstep(-0.2, 0.0, h);
	col += vec3(1.0, 0.38, 0.12) * pow(max(mu, 0.0), 3.0) * g * tarde * 0.9;
	// halo del sol (Mie)
	col += csol * (0.12 * pow(max(mu, 0.0), 10.0) + 0.5 * pow(max(mu, 0.0), 300.0));

	// la tierra bajo el horizonte (el anillo lejano de ambiente.gd la tapa casi toda)
	vec3 suelo = horiz * vec3(0.55, 0.55, 0.5);
	if (d.y < 0.0) {
		col = mix(horiz * 0.9, suelo, smoothstep(0.0, -0.08, d.y));
	}

	// el sol y la luna
	if (!AT_CUBEMAP_PASS) {
		float disco = smoothstep(0.99996, 0.99999, mu);
		col += csol * disco * 60.0 * step(0.0, d.y + 0.01);
		vec3 l = normalize(luna_dir);
		float ml = dot(d, l);
		col += vec3(0.9, 0.92, 1.0) * smoothstep(0.99993, 0.99996, ml) * noche * 3.0;
		col += vec3(0.05, 0.06, 0.09) * pow(max(ml, 0.0), 60.0) * noche;
	}

	// estrellas
	if (noche > 0.01 && d.y > 0.0) {
		vec3 c = floor(d * 380.0);
		float r = hash13(c);
		float est = smoothstep(0.9975, 1.0, r) * (0.6 + 0.4 * sin(TIME * (2.0 + r * 5.0) + r * 40.0));
		col += vec3(0.8, 0.85, 1.0) * est * noche * smoothstep(0.0, 0.2, d.y) * 1.5;
	}

	// nubes: cúmulos en un plano a nubes_altura, iluminados del lado del sol
	if (d.y > 0.0) {
		vec2 p = d.xz / (d.y + 0.04) * nubes_altura;
		p = (p + viento * TIME) / 1000.0;
		int oct = AT_CUBEMAP_PASS ? 3 : 6;
		float c = densidad_nubes(p, oct);
		if (c > 0.001) {
			float c2 = densidad_nubes(p + s.xz * 0.35, oct);  // hacia el sol: más denso, más sombra
			float luz = clamp(1.0 - (c2 - c) * 1.6 - c * 0.35, 0.15, 1.0);
			vec3 amb = mix(cenit, horiz, 0.5) * 1.2 + vec3(0.06);
			vec3 cn = amb * 0.55 + csol * luz * 1.25;
			// borde plateado contra el sol
			cn += csol * pow(max(mu, 0.0), 12.0) * (1.0 - c) * 2.0;
			cn = mix(cn, vec3(0.02, 0.025, 0.04), noche * 0.9);
			float lejos = smoothstep(0.015, 0.2, d.y);
			// a lo lejos se funden con la bruma del horizonte
			cn = mix(horiz, cn, smoothstep(0.0, 0.25, d.y));
			col = mix(col, cn, c * lejos);
		}
	}

	// la cordillera, sobre el horizonte
	{
		float gx = d.x, gy = -d.z;
		float e = gx * cos(radians(5.0)) + gy * sin(radians(5.0));
		float n = -gx * sin(radians(5.0)) + gy * cos(radians(5.0));
		float az = atan(e, n);
		float hz = length(vec2(gx, gy));
		float el = atan(d.y, hz);
		float nieve;
		float m = cordillera(az, nieve);
		if (el < m && el > -0.02) {
			float oriente = step(0.0, sin(az));
			// la luz sobre las laderas: de frente cuando el sol está al otro lado
			float frente = 0.6 + 0.4 * clamp(-dot(normalize(vec2(gx, gy)), normalize(vec2(s.x, -s.z) + 1e-4)), 0.0, 1.0);
			vec3 roca = mix(vec3(0.20, 0.24, 0.32), vec3(0.28, 0.30, 0.30), 1.0 - oriente) * frente;
			vec3 blanco = vec3(1.0, 0.98, 0.96) * frente * 1.4;
			float altura_rel = el / max(m, 1e-4);
			vec3 cm = mix(roca, blanco, nieve * smoothstep(0.55, 0.85, altura_rel));
			cm *= mix(vec3(1.0), csol * 1.4 + vec3(0.05), 0.5);
			// la bruma de 35–80 km de aire
			float bruma = mix(0.72, 0.5, 1.0 - oriente);
			cm = mix(cm, horiz, bruma);
			cm = mix(cm, horiz * 0.5, noche * 0.6);
			col = mix(col, cm, smoothstep(m, m - 0.0015, el));
		}
	}

	COLOR = col * brillo;
}
