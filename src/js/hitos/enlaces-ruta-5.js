  // ==== hito: enlaces-ruta-5 ====
  // Every crossing of the Ruta 5 in the model, from OpenStreetMap (`python pipeline/traces.py cruces`, north to south;
  // `traces.py vial` draws them over the Esri image):
  //   (4128, 3717) Río Lircay: the motorway on two bridges (puente-lircay-ruta5)
  //   (3958, 3485) a road under the motorway (w373726646, tunnel), which crosses it on two 81 m bridges (w151617653,
  //                w474496436; puente-lircay-ruta5); the Enlace Avenida Lircay's ramps join 70 m south
  //   (3811, 3294) Enlace Avenida Lircay: Avenida Lircay over it (w45040637), a cloverleaf loop and four ramps
  //   (3379, 2703) the railway (Línea Central Sur, electrified) under it: the motorway on two bridges (w151617648/9)
  //   (3249, 2144) Enlace Las Industrias, over it (w101568643), three ramps
  //   (2960, 890)  Pasarela Nueva Holanda, a footbridge with ramps (w101568620)
  //   (2820, 276)  a street under it (w193825710, tunnel); ramps of the Enlace 2 Norte join beside it
  //   (2747, -40)  Enlace 2 Norte (Talca Norte): Calle 2 Norte over it on two bridges (w83666254, w478675461)
  //   (2670, -375) Enlace San Miguel (to San Clemente and the Paso Pehuenche): Avenida San Miguel on two bridges
  //                (w478971526, w478971523) and a cycleway bridge beside them (w1121132285)
  //   (2575, -788) a footbridge with ramps and stairs (w1025552569)
  //   (2507, -1080) Enlace 8 Sur: Avenida 8 Sur over it on two bridges (w478951507, w478951521)
  //   (2328, -1854) Estero Piduco: the motorway on two bridges (puente-piduco-ruta5)
  //   (2144, -2642) Enlace El Tabaco (to Pirque), over it (w83143729)
  // and six culverts it needs no model for (the canals Sandoval, Baeza and Parrón, a stream, a ditch, an unnamed river). Nothing crosses it
  // at grade. Their ramps (motorway_link) are drawn by ruta5Base.
  // In Talca the motorway runs in a cutting under its overpasses (Esri image; a photo of 2011 on Commons, CC BY-SA 2.0),
  // with the frontage roads beside it at street level, a few metres from the bridges' ends. The relief, a node every
  // 40 m, cannot hold a cutting 40 m wide, so the overpasses rise instead, 2-4 m over the ends of the streets on ramps
  // between walls (the map's streets on the bridge are taken off the ground), with dark openings over the motorway
  // where it would run below; out of town, where there is room, they rise higher, as on the Esri image. Where the
  // motorway really is on bridges (the railway; the road at 3958, 3485), it climbs on embankments: 8.6 m over the
  // railway (an electrified line: catenary), 6 m over the road. The street at 2820, 276, under the motorway at grade with
  // ramps joining a few metres away, gets dark openings on both sides. Footbridges at their real height (5.6 m), on
  // columns, with their ramps and stairs. Approximate: every height, ramp and embankment length, the decks' widths
  // (the map's streets'), the piers.
  {const K={asph:R5K.asph,line:R5K.line,par:C('#D9D3C5'),old:C('#D9D3C5'),walk:C('#C9C3B6'),red:C('#C8503A'),beam:C('#B3AEA4'),wall:C('#C4BEB1'),
      void:C('#2B3036'),metal:C('#8A8F92'),lamp:R5K.lamp,fill:C('#93A35B'),fill2:C('#86964F'),foot:C('#CFC8B8'),foot2:C('#BDB6A6')};
    // overpasses: deck polyline (the map's street, ends at the junctions beyond the bridge), half width, rise
    for(const [pts,hw,top] of [
      [[[3742,3323],[3792,3302],[3828,3286],[3839,3284],[3847,3285]],6.5,3.5],                       // Avenida Lircay
      [[[3189,2158],[3214,2152],[3227,2150],[3274,2138],[3321,2124],[3369,2103]],5,4],                // Las Industrias
      [[[2728,-35.5],[2736,-37],[2758,-42.5],[2766,-44.5]],10.6,2],                                   // 2 Norte, both bridges
      [[[2651,-370],[2658.5,-372],[2681,-378],[2689,-380.5]],11.8,2],                                // San Miguel, both
      [[[2472,-1071],[2493,-1076],[2519.5,-1082.5],[2535,-1086.5]],10.6,2.2],                         // 8 Sur, both
      [[[2060,-2623],[2096,-2631],[2123,-2637],[2167,-2647],[2189,-2653],[2215,-2659]],5.5,4]])        // El Tabaco
      r5Over(S,K,pts,hw,top,{lamps:true});
    // the motorway over the railway: 8.6 m, on embankments of 200 m each side (the road at 3958, 3485: puente-lircay-ruta5)
    {const H=E(3379,2703)+8.6;for(const k of [0,1])r5Raise(S,K,k,[[3379,2703,null,240],[3379,2703,H,42],[3379,2703,H,-42],[3379,2703,null,-240]],[[[3389,2744],[3369,2661]]],{pier:18,lamps:true});}
    // the street under the motorway at 2820, 276: a dark opening (the shade under the motorway) where it meets each
    // pavement's outer edge, 2.5 m deep, as wide as the street
    for(const k of [0,1]){const [d]=r5d(k,2820.5,276.2),p=r5at(k,d),[sx,sy]=[(2837.2-2796.2)/43.1,(281.4-268.0)/43.1],c=Math.abs(p.tx*sy-p.ty*sx)||1,o=R5R(p);
      const P=(t,u)=>{const q=r5at(k,d+t/c);return r5off(q,o-u);},q=[P(-4,0),P(4,0),P(4,2.5),P(-4,2.5)];
      S.face(q.map(v=>[v[0],E(v[0],v[1])+.2,-v[1]]),[0,1,0],K.void);}
    // footbridges: OSM polyline, span from point i0 to i1; stairs [foot, top]
    {const ht=r5Foot(S,K,[[2934.1,847.7],[2944.7,893.9],[2974.7,887.1],[2963.8,839.7]],1,2,5.6);}
    {const ht=r5Foot(S,K,[[2569.3,-705.4],[2552.2,-783.5],[2586.8,-791.0],[2573.2,-852.9]],1,2,5.6);
      r5Stairs(S,K,2548.5,-796.3,2552.2,-783.5,ht);r5Stairs(S,K,2588.5,-781.6,2586.8,-791.0,ht);}
    S.dy=0;}
