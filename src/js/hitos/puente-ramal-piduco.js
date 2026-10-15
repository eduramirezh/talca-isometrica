  // ==== hito: puente-ramal-piduco ====
  // The ramal a Constitución over the estero Piduco (OSM w435101040, outline w475946828 «Puente Piduco»; 14 m), the
  // place of the poi ramal-constitucion: the ramal, metre gauge, built 1888–1915, is a Monumento Histórico (2007). A
  // narrower deck than the Línea Central's on plate girders, in the weathered grey streaked with rust of the ramal's
  // steel bridges in the Commons photos (Puente Banco Arena, 2012, CC BY-SA 3.0; none of this one), on the ramal's
  // earthen bed (railBase). Approximate: all of it but the plan.
  {const K={ballast:C('#A08D72'),par:C('#8E8B83'),old:C('#9D9A92'),beam:C('#8E8B83'),steel:C('#8E8B83'),steel2:C('#86705E'),stone:C('#BDB8AD'),stone2:C('#A9A49A')};
    const a=[1525.4,-1383.8],b=[1525.4,-1397.6];
    RAIL_BR.push({line:'ramal',a,b,hb:2,draw:(G,hAt)=>{deckBridge(G,K,[a,b],2.1,hAt,{deck:K.ballast,beamD:1,beamCol:K.beam,pier:1e9});
      railGirder(G,K,a,b,2.1,hAt,{plates:1});railPiers(G,K,a,b,2.1,hAt,{spans:1,beamD:1});}});
    MODELS['ramal-constitucion']={x:1525.4,y:-1390.7,h:5};}
