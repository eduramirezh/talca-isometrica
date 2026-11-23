// Ruido para los sombreadores del juego (capa.gdshader, cielo.gdshader): valor con derivadas (las de Inigo Quilez,
// iquilezles.org/articles/morenoise), fbm y un paso suavizado por el tamaño del píxel. Solo funciones, sin uniformes.

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float hash13(vec3 p3) {
	p3 = fract(p3 * 0.1031);
	p3 += dot(p3, p3.zyx + 31.32);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

// ruido de valor 2D: x el valor (0..1), yz la derivada
vec3 ruido2d(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	vec2 du = 30.0 * f * f * (f * (f - 2.0) + 1.0);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	float k1 = b - a, k2 = c - a, k4 = a - b - c + d;
	return vec3(a + k1 * u.x + k2 * u.y + k4 * u.x * u.y, du * vec2(k1 + k4 * u.y, k2 + k4 * u.x));
}

float ruido2(vec2 p) {
	return ruido2d(p).x;
}

// ruido de valor 3D: x el valor (0..1), yzw la derivada
vec4 ruido3d(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	vec3 u = f * f * (3.0 - 2.0 * f);
	vec3 du = 6.0 * f * (1.0 - f);
	float a = hash13(i);
	float b = hash13(i + vec3(1, 0, 0));
	float c = hash13(i + vec3(0, 1, 0));
	float d = hash13(i + vec3(1, 1, 0));
	float e = hash13(i + vec3(0, 0, 1));
	float f1 = hash13(i + vec3(1, 0, 1));
	float g = hash13(i + vec3(0, 1, 1));
	float h = hash13(i + vec3(1, 1, 1));
	float k0 = a, k1 = b - a, k2 = c - a, k3 = e - a, k4 = a - b - c + d;
	float k5 = a - c - e + g, k6 = a - b - e + f1, k7 = -a + b + c - d + e - f1 - g + h;
	return vec4(k0 + k1 * u.x + k2 * u.y + k3 * u.z + k4 * u.x * u.y + k5 * u.y * u.z + k6 * u.z * u.x + k7 * u.x * u.y * u.z,
		du * vec3(k1 + k4 * u.y + k6 * u.z + k7 * u.y * u.z,
				k2 + k5 * u.z + k4 * u.x + k7 * u.z * u.x,
				k3 + k6 * u.x + k5 * u.y + k7 * u.x * u.y));
}

// fbm 2D con derivada (octavas: cuántas; las finas se apagan con `lejos`, 0..1, para que no titilen de lejos)
vec3 fbm2d(vec2 p, int octavas) {
	vec3 s = vec3(0.0);
	float a = 0.5, f = 1.0;
	for (int i = 0; i < octavas; i++) {
		vec3 n = ruido2d(p * f);
		s += a * vec3(n.x, n.yz * f);
		a *= 0.5;
		f *= 2.03;
		p = vec2(p.y * 0.8 + p.x * 0.6, p.y * 0.6 - p.x * 0.8) + 1.7;  // giro: sin ejes visibles
	}
	return s;
}

float fbm2(vec2 p, int octavas) {
	float s = 0.0, a = 0.5;
	for (int i = 0; i < octavas; i++) {
		s += a * ruido2(p);
		a *= 0.5;
		p = mat2(vec2(1.6, -1.2), vec2(1.2, 1.6)) * p + 1.7;
	}
	return s;
}

vec4 fbm3d(vec3 p, int octavas) {
	vec4 s = vec4(0.0);
	float a = 0.5, f = 1.0;
	for (int i = 0; i < octavas; i++) {
		vec4 n = ruido3d(p * f);
		s += a * vec4(n.x, n.yzw * f);
		a *= 0.5;
		f *= 2.01;
	}
	return s;
}

// un paso con borde suave de un píxel: no titila de lejos
float paso_aa(float borde, float x) {
	float w = max(fwidth(x), 1e-5);
	return clamp((x - borde) / w + 0.5, 0.0, 1.0);
}

// 1 dentro de [a, b], con bordes de un píxel
float banda_aa(float a, float b, float x) {
	return paso_aa(a, x) * (1.0 - paso_aa(b, x));
}

// líneas de una grilla (junta: ancho en las mismas unidades que p, que es fract): 1 en la junta. Se desvanecen cuando
// la celda mide menos de unos píxeles.
float juntas(vec2 p, float junta) {
	vec2 w = max(fwidth(p), vec2(1e-5));
	vec2 f = abs(fract(p + 0.5) - 0.5);
	vec2 l = 1.0 - clamp((f - junta * 0.5) / w + 0.5, 0.0, 1.0);
	float fade = 1.0 - smoothstep(0.08, 0.3, max(w.x, w.y));
	return max(l.x, l.y) * fade;
}
