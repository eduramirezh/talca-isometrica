  // ==== hito: puente-panguilemo-ruta5 ====
  // The Ruta 5 over the Estero Panguilemo at the commune's northern limit: two decks of 124 m, one per carriageway
  // («Puente Pangue» in OSM: w101547260 southbound, w101547242 northbound, lanes=2, unlit), over a farm track
  // (w151617660, 20 m north of the south abutment) and the stream (w631639959), whose bed is the commune's limit. Only
  // the southern ~55 m of each deck lie in the commune: they end at the limit, cut like the diorama, with a face of the
  // beam's colour. No photos with a free licence: concrete decks with New Jersey parapets on wall piers every 25 m, like
  // the Lircay bridges, 6 m over the ground at the abutment, on an embankment of 100 m with grass slopes. No pad.
  // Approximate: the height, the piers' spacing, the embankment's length.
  {const K={asph:R5K.asph,line:R5K.line,par:C('#D9D3C5'),old:C('#D9D3C5'),beam:C('#B3AEA4'),metal:C('#8A8F92'),lamp:R5K.lamp,fill:C('#93A35B'),fill2:C('#86964F'),void:C('#2B3036')};
    const A=[7364,8797],H=E(...A)+6; // the south abutment, between the two carriageways' lines
    for(const k of [0,1]){const [d0]=r5d(k,...A),dir=r5north(k,d0);
      // the last cross-section of the deck (deckBridge's half width hw around the offset co, as r5Deck has them) whose
      // two edges are in the commune
      const sec=d=>{const p=r5at(k,d);return {p,co:(4.5-6-3.5*p.e)/2,hw:(10.5+3.5*p.e)/2+.6};};
      let d1=d0;while(Math.abs(d1-d0)<130){const {p,co,hw}=sec(d1+dir*.5);if(!inTerrain(...r5off(p,co+hw))||!inTerrain(...r5off(p,co-hw)))break;d1+=dir*.5;}
      const Z=r5off(r5at(k,d1),0),hAt=r5Raise(S,K,k,[[...A,null,-100],[...A,H],[...Z,H]],[[A,Z]],{pier:25});
      const {p,co,hw}=sec(d1),V=(o,y)=>{const c=r5off(p,o);return [c[0],y,-c[1]];},h=hAt(d1);
      S.face([V(co-hw,h-1.5),V(co+hw,h-1.5),V(co+hw,h+.9),V(co-hw,h+.9)],[p.tx*dir,0,-p.ty*dir],K.beam);}}
