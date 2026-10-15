  // ==== hito: puente-panguilemo-ferrocarril ====
  // The Línea Central over the Estero Pangue where the Estero Las Chilcas joins it, at the commune's northern limit
  // (OSM w101547234, 47 m, no outline), 150 m east of the Ruta 5's bridges. Only its southern half lies in the
  // commune: the deck ends on its middle pier, by the limit. The Esri imagery shows a dark steel deck; a photo of
  // c. 1929 (Commons, public domain) of a «Puente Panguilemo» between San Rafael and Panguilemo shows a viaduct of
  // eleven masonry arches, longer than this bridge: not this one, or not as it is today. Drawn as the Piduco's: a deck
  // on plate girders from a concrete abutment, 2 m over the higher bank so that the water shows under it.
  // Approximate: all of it but the plan.
  {const K={ballast:PAL.ballast,par:C('#4F565B'),old:C('#5F676C'),beam:C('#4F565B'),steel:C('#4F565B'),steel2:C('#5F676C'),stone:C('#BDB8AD'),stone2:C('#A9A49A')};
    const a=[7523.1,8820.4],b=[7531.0,8842.5]; // b: the middle of OSM's bridge, ~3 m inside the limit
    RAIL_BR.push({line:'main',a,b,hb:2,draw:(G,hAt)=>{deckBridge(G,K,[a,b],2.8,hAt,{deck:K.ballast,beamD:1.3,beamCol:K.beam,pier:1e9});
      railGirder(G,K,a,b,2.8,hAt,{plates:1.3});railPiers(G,K,a,b,2.8,hAt,{spans:1,beamD:1.3,cut:true});}});}
