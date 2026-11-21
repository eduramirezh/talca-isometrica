// Lo que comparten los pelajes de los animales del juego (pelaje_perro.gdshader, pelaje_gata.gdshader): el dibujo no va
// en los vértices, se calcula por píxel desde dónde está cada punto con el animal de pie y quieto, que perro.gd
// terminar() escribe en UV y UV2 (x, y, z y la zona, que cada pelaje define), y las funciones para dibujarlo. Incluye
// ruido.gdshaderinc: el sombreador que incluye este no lo incluye otra vez.

#include "res://shaders/ruido.gdshaderinc"

varying vec3 pat;
varying flat float zona;

void vertex() {
	pat = vec3(UV, UV2.x);
	zona = UV2.y;
}

// los colores de los pelajes van en sRGB (como los de la página): lin() los pasa a lineal
vec3 lin(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
}

// un ruido fino (escala: por metro) que vuelve a 0,5 cuando su grano mide menos de un píxel
float fino(vec3 p, float escala) {
	vec3 q = p * escala;
	float w = length(fwidth(q));
	return mix(ruido3d(q).x, 0.5, smoothstep(0.35, 1.1, w));
}

// rayas de período per (en las unidades de s): 1 en la raya, que ocupa la fracción ancho del período, con bordes suaves;
// cuando el período mide menos de ~5 píxeles, su promedio
float rayas(float s, float per, float ancho) {
	float f = s / per;
	float w = fwidth(f);
	float d = abs(fract(f) - 0.5) * 2.0;  // 0 en el centro de la raya, 1 entre dos
	float r = 1.0 - smoothstep(ancho - 0.25 - w, ancho + 0.25 + w, d);
	return mix(r, ancho, smoothstep(0.1, 0.25, w));
}

float mancha(vec3 q, vec3 c, float r) {
	vec3 d = q - c;
	return exp(-dot(d, d) / (r * r));
}
