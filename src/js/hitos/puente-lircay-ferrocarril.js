  // ==== hito: puente-lircay-ferrocarril ====
  // The Línea Central's two bridges over the Río Lircay, 30 m south-east of the Ruta 5's: Puente Lircay N° 1 over the
  // main channel (OSM w143173502, outline w474514799; 132 m) and N° 2 over the south arm (w101562801, outline
  // w474497525; 32 m). Designed by Domingo V. Santa María and built by Lever, Murphy y Cía in 1885. The one photo with a
  // free licence (Commons, c. 1900, CC0) shows masonry piers with cutwaters under half-through lattice girders, about
  // six spans, and a stone pillar at each abutment; the Esri imagery shows a dark steel deck today. Drawn so:
  // deckBridge's deck with steel parapets, lattice girders above it on both sides (railGirder, two tones by panel),
  // stone piers and abutments with their pillars (railPiers); railBase lays the track on it at the line's profile
  // (RAIL_BR registers it; it is drawn there, after the pads). Approximate: today's girders, the spans (6 × 22 m and
  // 2 × 16 m), the deck 0.6 m over the higher bank. No pad: the Ruta 5 bridge is 30 m away («Explanadas vecinas»).
  {const K={ballast:PAL.ballast,par:C('#4F565B'),old:C('#5F676C'),beam:C('#454B50'),steel:C('#4F565B'),steel2:C('#5F676C'),stone:C('#B5AC9A'),stone2:C('#A0978A')};
    const add=(a,b,n)=>RAIL_BR.push({line:'main',a,b,hb:.6,draw:(G,hAt)=>{deckBridge(G,K,[a,b],2.8,hAt,{deck:K.ballast,beamD:1.2,beamCol:K.beam,pier:1e9});
      railGirder(G,K,a,b,2.8,hAt,{spans:n,h:3});railPiers(G,K,a,b,2.8,hAt,{spans:n,beamD:1.2,pillars:true});}});
    add([4141.4,3669.7],[4214.3,3779.7],6);add([4013,3482.3],[4031.7,3508.9],2);}
