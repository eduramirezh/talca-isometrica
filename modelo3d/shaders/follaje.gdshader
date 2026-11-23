// capa.gdshader para las copas de los árboles (tipo 3): no reciben sombras. Sus normales salen del centro de cada
// copa (ambiente.gd, copas()), pero sus caras siguen siendo las de un icosaedro, y el mapa de sombras las oscurecía
// cara por cara; sin él la luz las redondea. Proyectan sombra igual.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert_wrap, specular_schlick_ggx, shadows_disabled;

#include "res://shaders/capa.gdshaderinc"
