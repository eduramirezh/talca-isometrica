  // ==== hito: puente-piduco-ferrocarril ====
  // The Línea Central over the estero Piduco (OSM w102212627, outline w475946827 «Puente Piduco»; 14 m), 5 m east of the
  // ramal's (next block). No photo with a free licence; the Esri imagery shows a short single span. Drawn as a deck on
  // plate girders (stiffeners in two tones) between concrete abutments. Approximate: all of it but the plan. The deck
  // stands 2 m over the higher bank so that the water shows under it: the estero runs in a ditch the relief does not
  // have, so the line rises to it on short ramps (railBase).
  {const K={ballast:PAL.ballast,par:C('#4F565B'),old:C('#5F676C'),beam:C('#4F565B'),steel:C('#4F565B'),steel2:C('#5F676C'),stone:C('#BDB8AD'),stone2:C('#A9A49A')};
    const a=[1530.6,-1383.8],b=[1530.4,-1397.7];
    RAIL_BR.push({line:'main',a,b,hb:2,draw:(G,hAt)=>{deckBridge(G,K,[a,b],2.8,hAt,{deck:K.ballast,beamD:1.3,beamCol:K.beam,pier:1e9});
      railGirder(G,K,a,b,2.8,hAt,{plates:1.3});railPiers(G,K,a,b,2.8,hAt,{spans:1,beamD:1.3});}});}
