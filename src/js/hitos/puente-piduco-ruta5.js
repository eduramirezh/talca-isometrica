  // ==== hito: puente-piduco-ruta5 ====
  // The Ruta 5's bridge over the Estero Piduco: two decks of ~65 m, one per carriageway (OSM w478951509 southbound,
  // w143102108 northbound, lit=yes; under them maxheight=4.3), on wall piers every 20 m, 4.5 m over the stream, on short
  // embankments (a ramp of the Enlace 5 Sur leaves 35 m south of the bridge). Lamp posts on the median side.
  // Approximate, as the Lircay bridge.
  {const K={asph:R5K.asph,line:R5K.line,par:C('#D9D3C5'),old:C('#D9D3C5'),beam:C('#B3AEA4'),metal:C('#8A8F92'),lamp:R5K.lamp,fill:C('#93A35B'),fill2:C('#86964F'),void:C('#2B3036')};
    const HP=E(2328,-1854)+4.5;
    for(const k of [0,1])r5Raise(S,K,k,[[2336,-1821,null,70],[2336,-1821,HP],[2321,-1884,HP],[2321,-1884,null,-30]],[[[2336,-1821],[2321,-1884]]],{pier:20,lamps:true});}
