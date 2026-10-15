  // ==== hito: gore-maule ====
  // Gobierno Regional del Maule, 1 Norte 771: the office tower on the plaza's north side (not the historic Intendencia,
  // which stands across 1 Oriente, w275506476). Built on S in grid metres. Plan from OpenStreetMap w275506471: a
  // three-floor podium along 1 Norte (y 69–82) and the ten-floor tower behind it. Above the ground, from photos on
  // Wikimedia Commons (2017, 2018, the tower behind the Municipalidad and seen down 1 Norte): grey frame with ribbons of
  // blue glass on every floor, a solid grey core in the middle of the east face, a thin roof slab and plant on the
  // roof, the flag on the podium. Approximate: the height (10 floors as tagged, ~3.2 m each), the west and north faces
  // (drawn like the east), the podium's windows. It stands on the plaza's level (MODELS[...].pad) with walls 10 m
  // deep: the Catedral's lower pad tilts the ground under its west side. Method: docs/METODOLOGIA.md §9.
  {const F=localFrame(0,0,Math.PI/2),H=MODELS['plaza-de-armas'].pad;
    const K={wall:C('#C6C8C4'),wall2:C('#B5B8B4'),core:C('#A3A7A6'),groove:C('#8E9291'),glass:C('#6A8DAB'),glass2:C('#5C7F9E'),
      white:C('#E8E6E0'),flat:C('#8F8A82'),plant:C('#A7AAA7'),dark:C('#3B4653')};
    const {box,WU,WV,rect}=facade(S,F,K);
    occMark([[-55.9,69.2],[-27.3,69.1],[-27.3,81.6],[-29.6,81.6],[-29.5,109.9],[-55.7,110]]);PADS.push([-55.9,69.1,-27.3,110,H]);S.dy=H;
    // podium: three floors with ribbon windows, a flat roof behind a white edge
    box(-55.9,69.1,-27.3,81.6,-6,9.6,K.wall2,K.flat);
    for(const [mk,s0,s1] of [[o=>WV(69.1,-1,o),-55.9,-27.3],[o=>WU(-27.3,1,o),69.1,81.6],[o=>WU(-55.9,-1,o),69.1,81.6]]){const w=mk(.06);
      rect(w,s0+.8,s1-.8,1.0,3.7,K.glass2);for(const h of [4.6,7.6])rect(w,s0+.8,s1-.8,h,h+1.5,K.glass);rect(mk(.09),s0,s1,9.1,9.6,K.white);}
    // tower: ground floor glazed, then nine floors of a grey spandrel under a glass ribbon (two tones by floor)
    box(-55.8,81.6,-29.6,110,-6,33,K.wall,K.flat);
    const FL=[[1.0,3.8]];for(let k=1;k<10;k++){const f=4.3+(k-1)*3.2;FL.push([f+.95,f+3.0]);}
    const ribbons=(w,spans,from=0)=>FL.forEach(([a,b],i)=>{if(a<from)return;for(const [s0,s1] of spans)rect(w,s0,s1,a,b,i%2?K.glass2:K.glass);});
    for(const [u,sg] of [[-29.6,1],[-55.8,-1]]){const w=WU(u,sg);ribbons(w,[[83,93.6],[100.4,108.6]]);
      rect(w,93.6,100.4,4.3,33,K.core);for(let k=1;k<10;k++){const f=4.3+k*3.2-.25;rect(WU(u,sg,.09),93.6,100.4,f,f+.3,K.groove);}}
    ribbons(WV(110,1),[[-54.4,-31]]);ribbons(WV(81.6,-1),[[-54.4,-31]],10);
    // roof: a thin white slab a little wider than the tower, plant rooms and the lift shaft
    box(-56.3,81.1,-29.1,110.5,33,33.5,K.white,K.white);box(-51,87,-38,103,33.5,35.6,K.plant,K.flat);box(-35.5,92,-31.5,100,33.5,37,K.plant,K.flat);
    flagS(-31,72,9.6,7);
    MODELS['gore-maule']={x:-42.7,y:93,h:38};S.dy=0;}
