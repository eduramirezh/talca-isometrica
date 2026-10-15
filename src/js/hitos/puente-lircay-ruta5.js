  // ==== hito: puente-lircay-ruta5 ====
  // The Ruta 5 over the Río Lircay and its floodplain, from the road under it at (3958, 3485) to the north bank: two
  // decks, one per carriageway, as OpenStreetMap has them, on two bridges each: 164 m over the river (w52129398
  // southbound, w151617647 northbound) and 81 m over the road (w151617653, w474496436), with the motorway on an
  // embankment between them, over a hollow of the relief. No photos with a free licence: concrete decks with New
  // Jersey parapets on wall piers every 25 m, like the Río Claro bridges; grass slopes on the embankments. Heights from
  // the ground: 6 m over the road, 8 m over the levelled river; no pad (the railway bridge stands 50 m east, and two
  // pads that close would fight). Lit from the road southwards, as in OSM. Approximate: every height, the piers'
  // spacing, the ramps (60 m to the south, 120 m north of the river).
  {const K={asph:R5K.asph,line:R5K.line,par:C('#D9D3C5'),old:C('#D9D3C5'),beam:C('#B3AEA4'),metal:C('#8A8F92'),lamp:R5K.lamp,fill:C('#93A35B'),fill2:C('#86964F'),void:C('#2B3036')};
    const HR=E(3958,3485)+6,HL=E(4128,3717)+8;
    for(const k of [0,1])r5Raise(S,K,k,[[3958,3485,null,-60],[3958,3485,HR,-8],[4004,3548,HR],[4096,3674,HL],[4193,3805,HL],[4193,3805,null,120]],
      [[[3953,3478],[4004,3548]],[[4096,3674],[4193,3805]]],{pier:25,lamps:true});}
