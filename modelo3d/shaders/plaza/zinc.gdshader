// La cúpula de zinc del quiosco: escamas en hileras (UV de malla.gd/torno: x alrededor, 0..1; y a lo largo del perfil,
// en m), cada hilera corrida media escama, con el borde de cada una más oscuro y un tono distinto por escama. Fotos de
// 2014 (Commons, «Talca, plaza (15020251291)» y «(15711413856)»): escamas redondeadas de un gris verdoso claro.
shader_type spatial;

uniform vec3 zinc : source_color = vec3(0.62, 0.65, 0.63);
uniform float escamas = 48.0;  // por vuelta
uniform float alto = 0.2;      // m por hilera

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 q = vec2(UV.x * escamas, UV.y / alto);
	float fila = floor(q.y);
	q.x += mod(fila, 2.0) * 0.5;
	vec2 f = fract(q);
	// la escama: un semicírculo que cuelga, su borde de abajo redondeado
	float d = length(vec2(f.x - 0.5, (f.y) * 0.9));
	float borde = smoothstep(0.42, 0.5, d);
	vec3 col = zinc * (0.9 + 0.15 * hash(floor(q)));
	col *= 1.0 - 0.3 * borde;
	ALBEDO = col;
	METALLIC = 0.55;
	ROUGHNESS = 0.45;
	float h = (1.0 - borde) * 0.004;
	vec3 dpx = dFdx(VERTEX), dpy = dFdy(VERTEX);
	float dhx = dFdx(h), dhy = dFdy(h);
	vec3 r1 = cross(dpy, NORMAL), r2 = cross(NORMAL, dpx);
	float det = dot(dpx, r1);
	NORMAL = normalize(abs(det) * NORMAL - sign(det) * (dhx * r1 + dhy * r2));
}
