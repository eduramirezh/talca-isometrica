// La corteza de los troncos y ramas (UV de malla.gd: x alrededor, 0..1; y a lo largo, en m), tres dibujos:
//   tipo 0: corteza con surcos a lo largo (cedros, frondosos), con musgo hacia abajo
//   tipo 1: la base de las hojas cortadas de la palmera canaria, en rombos escalonados
//   tipo 2: lisa con cicatrices horizontales (araucaria, cordyline)
// El color base es el del vértice.
shader_type spatial;

uniform int tipo = 0;
uniform float vueltas = 6.0;  // repeticiones del dibujo alrededor del tronco

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
	vec2 p = vec2(UV.x * vueltas, UV.y);
	vec3 col = COLOR.rgb;
	float h = 0.0;
	if (tipo == 1) {
		// cicatrices de las frondas cortadas: escamas anchas, irregulares, en hileras que se traslapan
		vec2 q = vec2(p.x * 1.4 + ruido(p * vec2(1.0, 4.0)) * 0.4, p.y / 0.11);
		q.x += floor(q.y) * 0.5;
		vec2 f = fract(q) - 0.5;
		float rombo = abs(f.x) * 1.2 + abs(f.y + 0.15) * 0.9;
		h = 1.0 - smoothstep(0.3, 0.5, rombo);
		col *= 0.68 + 0.32 * h + 0.18 * (hash(floor(q)) - 0.5);
		col *= 0.9 + 0.2 * ruido(p * vec2(3.0, 0.7));
	} else if (tipo == 2) {
		float anillo = smoothstep(0.85, 1.0, fract(p.y / 0.35 + ruido(p * 3.0) * 0.2));
		h = 1.0 - anillo;
		col *= 0.85 + 0.15 * ruido(p * vec2(2.0, 8.0)) - 0.2 * anillo;
	} else {
		float surco = ruido(vec2(p.x * 2.2, p.y * 0.9)) * 0.6 + ruido(vec2(p.x * 6.0, p.y * 2.5)) * 0.4;
		h = smoothstep(0.35, 0.65, surco);
		col *= 0.45 + 0.5 * h;
		float musgo = (1.0 - smoothstep(0.0, 2.5, UV.y)) * smoothstep(0.5, 0.8, ruido(p * 3.0));
		col = mix(col, vec3(0.30, 0.36, 0.20), musgo * 0.5);
	}
	ALBEDO = col;
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
	float hh = h * 0.01;
	vec3 dpx = dFdx(VERTEX), dpy = dFdy(VERTEX);
	float dhx = dFdx(hh), dhy = dFdy(hh);
	vec3 r1 = cross(dpy, NORMAL), r2 = cross(NORMAL, dpx);
	float det = dot(dpx, r1);
	NORMAL = normalize(abs(det) * NORMAL - sign(det) * (dhx * r1 + dhy * r2));
}
