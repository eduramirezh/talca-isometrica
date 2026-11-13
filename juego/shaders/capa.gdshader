// Material de las capas del glb (y de los modelos que lo quieran: materiales.gd). Conserva el color por vértice de la
// maqueta como base y le suma el detalle que la página no dibuja: reconoce cada superficie por su color y su normal
// (asfalto, baldosa, pasto, tierra, agua, teja, zinc, estuco, follaje, corteza, pintura de auto, vidrio) y le pone
// textura procedural, relieve, rugosidad y, en las fachadas de los edificios, ventanas (como winMat() de la página:
// cada 3,4 × 3,0 m desde 1 m de altura), encendidas de noche.
//
// tipo (de la capa): 0 suelo y genérico, 1 edificio con ventanas, 2 hito (sin ventanas), 3 árbol, 4 auto.
// clase: -1 la reconoce por el color; si no, fuerza una (las constantes C_* de abajo; materiales.gd las nombra).
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

#include "res://shaders/capa.gdshaderinc"
