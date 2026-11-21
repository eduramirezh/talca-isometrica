// Los ojos de los animales del juego (perro.gd, gata.gd ojos: cada uno un elipsoide en su propio nodo, que parpadea
// achatándolo en Y): casi todo iris, con fibras radiales y un anillo oscuro en el borde, del color de iris_adentro junto
// a la pupila a iris_afuera en el borde; la pupila, una rendija vertical (la gata) o redonda (el perro, redonda), que se
// abre de noche (el global noche de ambiente.gd, de pupila.x de día a pupila.y de noche). Una córnea pulida (casi sin
// rugosidad y con barniz) da los brillos del sol y del cielo. De noche, la pupila devuelve un brillo verdoso cuando el
// ojo mira hacia la cámara (el tapetum lucidum). Por omisión, los de la gata.
shader_type spatial;
render_mode blend_mix, cull_back, diffuse_burley, specular_schlick_ggx;

#include "res://shaders/ruido.gdshaderinc"

global uniform float noche;
uniform vec2 radio = vec2(0.0105, 0.0095);  // m: el medio ancho y el medio alto del ojo
uniform vec3 iris_adentro = vec3(0.80, 0.72, 0.30);  // sRGB
uniform vec3 iris_afuera = vec3(0.50, 0.58, 0.27);
uniform vec2 pupila = vec2(0.3, 0.85);  // cuánto se abre (0 … 1) de día y de noche
uniform bool redonda = false;

varying vec3 lp;

void vertex() {
	lp = VERTEX;
}

vec3 lin(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
}

void fragment() {
	vec2 p = lp.xy / radio;
	float r = length(p);
	float dil = mix(pupila.x, pupila.y, clamp(noche, 0.0, 1.0));
	// la pupila: una elipse vertical de medio ancho w y medio alto casi el del iris (o un círculo), con el borde de un píxel
	float w = redonda ? mix(0.35, 0.7, dil) : mix(0.1, 0.72, dil);
	float e = length(vec2(p.x / w, p.y / (redonda ? w : mix(0.86, 0.8, dil))));
	float aa = max(fwidth(e), 1e-4);
	float pup = 1.0 - clamp((e - 1.0) / aa + 0.5, 0.0, 1.0);
	// el iris: del color de adentro junto a la pupila al de afuera, fibras radiales y el anillo oscuro del borde
	float ang = atan(p.y, p.x);
	float fib = ruido2(vec2(ang * 7.0, r * 2.5)) * 0.6 + ruido2(vec2(ang * 19.0, r * 5.0)) * 0.4;
	vec3 iris = mix(iris_adentro, iris_afuera, smoothstep(0.15, 0.85, r));
	iris *= 0.78 + 0.42 * fib;
	iris = mix(iris, iris_afuera * 0.4, smoothstep(0.8, 0.97, r));
	vec3 c = mix(iris, vec3(0.012), pup);
	ALBEDO = lin(c);
	ROUGHNESS = 0.05;
	SPECULAR = 0.75;
	CLEARCOAT = 1.0;
	CLEARCOAT_ROUGHNESS = 0.03;
	float frente = pow(clamp(dot(NORMAL, VIEW), 0.0, 1.0), 6.0);
	EMISSION = lin(vec3(0.55, 0.75, 0.3)) * pup * frente * smoothstep(0.3, 1.0, noche) * 0.3;
}
