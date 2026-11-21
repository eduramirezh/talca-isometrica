  // ==== hito: edificio-raices ====
  // Edificio Raíces, 3 Oriente 1645 (between 5 and 6 Norte): a residential tower finished after April 2020 (Esri
  // Wayback: an empty lot with the first columns on 31 March 2015, still bare earth on 6 April 2020; Google Open
  // Buildings 2.5D Temporal: presence 0.24 in 2016, 0.94 in 2023, 35 m). No OSM building; the plan is the Microsoft
  // footprint d281d024-3996-4b34-97e5-7cb7bdaba258 (raw/edificios-ml/huellas.jsonl, confidence 0.976), moved back by the
  // median shift of the Microsoft footprints against OSM (pipeline/edificios.py shifts(): 2.68 m west, 0.51 m south),
  // a bar of 49.6 × 15 m at 1.8° from the grid, rectilinear to the decimetre. Frame: u along the bar toward 3 Oriente
  // (east), v to the north. Above the ground, from the broker's photos of the sale (CIMA Propiedades, Quezada Ausset;
  // looked at, not copied: docs/FUENTES.md): grey-white concrete; ten storeys of flats (2.65 m) with a white band at
  // every floor; on 3 Oriente a full-width balcony on every floor between thick white cheeks and a thin central column,
  // glass railings, the double-height hall behind wooden slats in the south half and the street wall of the ground
  // floor terraces (with the number 1645) in the north half; on the north face punched windows in pairs, a column of
  // small windows and a wooden slot by the east corner, and two stacks of projecting balconies (the footprint's comb);
  // an eleventh storey at both ends, set back in the middle (the sky lounge, with a dark pergola on its terrace), lift
  // overruns on the roof; to the north a lawn with the flats' terraces, a playground in the west corner and a black
  // fence. The driveway along the south side is the map's track (Calle sin nombre, class 7). Approximate: the height
  // (35 m from Google to the top of the overruns; the photos give 10 + 1 storeys, ~30 m to the parapets), the west face
  // (no photos: the north face's rhythm), the lot's edges (the 2015 empty lot), the playground and the pergola. The
  // south face, from Mapillary's panoramas from the Alameda (2024, ~205 m, blurry: mapillary.py mirar): light, with
  // dark windows in pairs on every floor, also on the west block (their places there ± 2 m). Not a place of pois.py (a private residential tower; the map's places are legal and iconic). Its own
  // footprint in occ (the whole lot, occFill: no generated houses in the garden), no pad: it stands on its highest
  // corner with walls 4 m down. Method: docs/METODOLOGIA.md §9.
  {const F=localFrame(275,747,(90+1.8)*Math.PI/180),{G,Gs}=F;
    const K={...KH,wall:C('#DCDBD6'),white:C('#F0EFEA'),glass:C('#3B4653'),glass2:C('#2C3540'),rail:C('#A7B4B7'),
      wood:C('#8A5A3B'),wood2:C('#74492F'),roof:C('#B3B2AC'),roof2:C('#A3A29C'),plant:C('#C4C3BD'),dark:C('#474B4F'),
      lawn:C('#6F9F48'),pave:C('#C9C6BE'),mat:C('#5E8A6A'),green:C('#4FA53E'),yellow:C('#E0B83A'),blue:C('#3E6FB0'),red:C('#C2483A')};
    const {box,WU,WV,rect,walls}=facade(S,F,K),FH=2.65,BAR=27.3,TOP=30;
    // the bar's outline (the footprint without the balconies that stand out of it), the east balconies' recess cut in
    const R=[[-25.55,-6.25],[-8.9,-6.25],[-8.9,-7.58],[24,-7.58],[24,-6.38],[22.2,-6.38],[22.2,5.98],[24,5.98],[24,7.18],
      [6.54,7.18],[6.54,7.78],[-12.04,7.78],[-12.04,4.3],[-16.78,4.3],[-16.78,8.18],[-25.55,8.18]];
    const RE=[[16.2,-7.58],[24,-7.58],[24,-6.38],[22.2,-6.38],[22.2,5.98],[24,5.98],[24,7.18],[16.2,7.18]],
      RW=[[-25.55,-6.25],[-16.78,-6.25],[-16.78,8.18],[-25.55,8.18]];
    // the lot (the 2015 empty lot, to 3 Oriente and over the driveway): occFill keeps the sidewalk and the track
    occFill(Gs([[-28.6,-16.5],[33,-16.5],[33,19],[-28.6,19]]),2.5);occMark(Gs([[-25.6,-7.6],[24.1,-7.6],[24.1,9.5],[-25.6,9.5]]));
    const g0=Math.max(...Gs(R).map(p=>E(p[0],p[1])));S.dy=g0;
    // storeys k = 0…9 (ten) in the bar, 10 (the eleventh) in the end blocks; the floors' white band, windows in two tones
    const st=k=>k*FH,gl=k=>k%2?K.glass2:K.glass;
    const band=(w,s0,s1,k0,k1)=>{for(let k=k0;k<=k1;k++)rect(w.at(.09),s0,s1,st(k)-.2,st(k)+.25,K.white);};
    const wins=(w,cs,wd,k0,k1,h=1.5)=>{for(let k=k0;k<=k1;k++)for(const c of cs)rect(w,c-wd/2,c+wd/2,st(k)+.65,st(k)+.65+h,gl(k));};
    // a balcony's look on a flat face: dark glazing, the railing over it and the slab's edge
    const balc=(w,s0,s1,k0,k1)=>{for(let k=k0;k<=k1;k++){rect(w,s0,s1,st(k)+.25,st(k)+2.35,gl(k));rect(w.at(.09),s0,s1,st(k)+.25,st(k)+1.2,K.rail);
      rect(w.at(.12),s0-.3,s1+.3,st(k)-.25,st(k)+.25,K.white);}};
    walls(R,-4,BAR,K.wall);S.flat(Gs(R),BAR,K.roof);
    walls(RE,BAR,TOP,K.wall);S.flat(Gs(RE),TOP,K.roof);walls(RW,BAR,TOP,K.wall);S.flat(Gs(RW),TOP,K.roof);
    // 3 Oriente: a balcony on every floor between the cheeks, glazing behind, the thin central column; the hall's
    // wooden slats over two storeys in the south half, the ground floor's terraces in the north half
    {const w=WU(22.2,1);
      rect(w,-.25,5.98,.3,2.4,gl(0));for(let k=1;k<=10;k++)rect(w,-6.38,5.98,st(k)+.25,st(k)+2.4,gl(k));
      for(let s=-6.38,i=0;s<-.26;s+=.5,i++)rect(w.at(.09),s,Math.min(s+.5,-.25),.2,st(2)-.25,i%2?K.wood2:K.wood);
      for(let k=1;k<=11;k++){const v0=k===1?-.25:-6.38;box(22.2,v0,24,5.98,st(k)-.25,st(k)+.2,K.white,K.white);
        if(k<11)rect(WU(24,1),v0,5.98,st(k)+.2,st(k)+1.15,K.rail);}
      box(22.2,-6.38,24,5.98,st(11)+.2,TOP,K.white,K.roof2);box(22.2,-.25,23.8,.25,-.5,st(11)-.25,K.white,K.white);
      box(25.6,0,26.1,9,-.5,1.9,K.white,K.white);
      for(const v of [-4.6,-1.8]){const g=G(24.6,v);GLOW.push(g[0],g0+4.9,g[1]);}}
    // north face. The east block: a column of small windows and the wooden slot by the corner; the bar's punched pairs
    {const w=WV(7.18,1);rect(w,22.7,23.5,.2,TOP-.6,K.wood);wins(w,[18.6],.9,0,10,1.2);band(w,16.2,22.6,1,9);
      wins(w,[14.4,13.0,9.9,8.5],1.2,0,9);band(w,6.54,16.2,1,9);rect(w.at(.12),15.9,16.5,-.5,BAR,K.white);}
    // the projecting balconies of the comb: slabs out to the footprint, railings round them, glazing behind
    {const w=WV(7.78,1);rect(w.at(.09),-3,6.2,.25,1.2,K.rail);
      for(let k=0;k<=9;k++){rect(w,-3.0,6.2,st(k)+.25,st(k)+2.35,gl(k));if(!k)continue;
        box(-3.3,7.78,6.54,9.48,st(k)-.25,st(k)+.2,K.white,K.white);
        rect(WV(9.48,1),-3.3,6.54,st(k)+.2,st(k)+1.15,K.rail);rect(WU(6.54,1),7.78,9.48,st(k)+.2,st(k)+1.15,K.rail);rect(WU(-3.3,-1),7.78,9.48,st(k)+.2,st(k)+1.15,K.rail);}
      box(-3.3,7.78,6.54,9.48,BAR-.45,BAR,K.white,K.roof2);
      wins(w,[-10.6,-9.2,-6.4,-5.0],1.2,0,9);band(w,-12.04,-3.3,1,9);}
    balc(WV(4.3,1),-16.5,-12.3,0,9);
    for(const [u,sg,a,b] of [[-12.04,-1,4.3,7.78],[-16.78,1,4.3,8.18]])wins(WU(u,sg),[(a+b)/2],1.4,0,9);
    {const w=WV(8.18,1);balc(w,-25,-17.3,0,10);}
    // south face (Mapillary, from the Alameda): pairs of windows on every floor, a column of small windows on the east
    // block; the west block has windows, not the north face's balconies
    {const w=WV(-7.58,-1);wins(w,[18.6],.9,0,10,1.2);band(w,16.2,22.6,1,9);
      wins(w,[14.4,13,10.2,8.8,5.4,4,1.2,-.2,-3.6,-5],1.2,0,9);band(w,-8.9,16.2,1,9);rect(w.at(.12),15.9,16.5,-.5,BAR,K.white);
      const v=WV(-6.25,-1);wins(v,[-23,-21.6,-19.4,-18],1.2,0,10);band(v,-25.55,-16.78,1,10);wins(v,[-14.6,-13.2,-11.4,-10],1.2,0,9);band(v,-16.78,-8.9,1,9);}
    // west face: two columns of windows by the corners
    {const w=WU(-25.55,-1);wins(w,[-4.6,6.6],1.2,0,10);band(w,-6.25,8.18,1,10);}
    // the set-back eleventh storey (the sky lounge) with a ribbon of dark glass, its pergola, the lift overruns
    box(-6,-4.6,16,4.6,BAR,29.6,K.wall,K.roof2);
    for(const [v,sg] of [[4.6,1],[-4.6,-1]]){const w=WV(v,sg);for(let s=-5.6,i=0;s<15.6;s+=3,i++)rect(w,s,Math.min(s+3,15.6),27.7,29.1,i%2?K.glass2:K.glass);}
    rect(WU(-6,-1),-4,4,27.7,29.1,K.glass);
    for(const [u,v] of [[-14.5,-4],[-14.5,3.6],[-6.45,-4],[-6.45,3.6]])box(u,v,u+.45,v+.45,BAR,29.6,K.dark,K.dark);
    box(-14.5,-4,-6,-3.55,29.2,29.6,K.dark,K.dark);box(-14.5,3.6,-6,4.05,29.2,29.6,K.dark,K.dark);
    for(let u=-13.3;u<-6.4;u+=1.2)box(u,-3.55,u+.45,3.6,29.25,29.55,K.dark,K.dark);
    box(2,-2.2,6.2,2.2,29.6,32.4,K.plant,K.roof);box(18,-3.4,20.8,.6,TOP,34,K.plant,K.roof);box(-23.6,-3,-19.6,2,TOP,31.6,K.plant,K.roof);
    // the garden: lawn, the ground floor's terraces, the forecourt, the playground and the fence (on the ground, no pad)
    {const {rc,done}=groundLayer(S,1<<12,F);
      rc(-28.2,9.5,24,18.4,.13,K.lawn);rc(-25.5,7.2,22.2,11.4,.145,K.pave);rc(24,-9.6,25.6,18.4,.145,K.pave);rc(-25.5,-9.6,24,-7.6,.145,K.pave);
      rc(-27.6,12.2,-19.4,17.8,.16,K.mat);done();}
    {const p=(u,v,a,b,h0,h1,c)=>{const g=G(u,v);S.dy=E(g[0],g[1]);box(u,v,u+a,v+b,h0,h1,c,c);};
      p(-26.6,13.4,1.6,1.6,0,2.4,K.yellow);p(-26.6,15,1.6,.6,1.6,1.9,K.blue);p(-25,13.6,2.6,.9,0,1.4,K.green);
      p(-22.6,15.2,1.4,1.4,0,2,K.blue);p(-22.4,13.2,.9,2,0,1.1,K.green);p(-21,13.4,.6,.6,0,1.2,K.red);
      for(let u=-28.4;u<24;u+=6.5)p(u,18.5,Math.min(6.5,24-u),.4,0,1.6,K.iron);
      for(let v=-9.5;v<18.5;v+=6)p(-28.6,v,.4,Math.min(6,18.9-v),0,1.6,K.iron);}
    {const rr=rng(1645),t=treeAt(F,()=>true,rr);t(-15,15.5,.7);t(-6,16.5,.75);t(8,16,.7);t(17,15.8,.65);}
    {const c=G(0,0);MODELS['edificio-raices']={x:c[0],y:c[1],h:35};}S.dy=0;}
