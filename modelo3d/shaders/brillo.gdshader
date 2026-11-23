// El brillo de un farol de noche (faroles.gd), como los puntos de luz de la página (glowMat de src/js/84-lights.js:
// un sprite de 9 píxeles que no se achica con la distancia): un cuadrado de cara a la cámara, en un MultiMesh, de
// `metros` de lado o de al menos `pixeles` en la pantalla, con un degradé radial que se suma a lo que hay detrás. De
// cerca es un halo alrededor de la lámpara; de lejos, un punto de luz que no desaparece entre los píxeles (la lámpara
// misma mide 0,5 m: a 1 km, menos de un píxel). Se apaga de día (el parámetro global noche, ambiente.gd) y se
// desvanece con la distancia (la niebla no se aplica a lo que se suma).
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

global uniform float noche;
uniform float metros = 1.6;
uniform float pixeles = 7.0;
uniform vec3 color : source_color = vec3(1.0, 0.8, 0.52);
uniform float energia = 1.4;
uniform float lejos = 2200.0;  // m: aquí ya no se ve
varying float k;

void vertex() {
	vec4 c = MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0);
	float d = max(-c.z, 0.1);
	float px = 2.0 * d / (PROJECTION_MATRIX[1][1] * VIEWPORT_SIZE.y);  // metros por píxel a esa distancia
	float s = max(metros, pixeles * px);
	c.xyz += normalize(-c.xyz) * min(0.6, d * 0.5);  // un poco hacia la cámara, para no hundirse en el farol
	POSITION = PROJECTION_MATRIX * (c + vec4(VERTEX.xy * s, 0.0, 0.0));
	UV = VERTEX.xy + 0.5;
	k = noche * (1.0 - smoothstep(lejos * 0.4, lejos, d));
}

void fragment() {
	float r = length(UV - 0.5) * 2.0;
	float a = pow(max(1.0 - r, 0.0), 2.2);
	ALBEDO = color * a * energia * k;
}
