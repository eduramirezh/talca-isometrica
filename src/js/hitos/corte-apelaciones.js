  // ==== hito: corte-apelaciones ====
  // Corte de Apelaciones de Talca and the Juzgados de Letras (4 Norte 609 and 615), one stone-clad building of about
  // 2004 (new in a 2005 photo) north of the Alameda, between 2 and 1 Poniente; built on S, windows drawn by hand.
  // Plan from OpenStreetMap w723911157, in the frame of landmark.py frame corte-apelaciones 723911157: v runs north
  // (away from the Alameda), u east. Two parts: the Corte (u -16.6..5, set back 16 m behind a paved forecourt) and the
  // Juzgados wing (u 5..18.2), which comes forward to the Alameda's building line at v=-31.9. Heights and colours from
  // Wikimedia Commons photos (2005, 2013, 2015), measured against the wing's 13 m front: ground floor plus five, ~24 m.
  // The Corte's front is a stone portal (a pier on the west, a deep slab on top, the Juzgados wing as its east side)
  // framing a recessed glass curtain wall, with a lighter glass box in a white frame standing proud of it; the west
  // face has a louvred glass strip. The wing: grey granite plinth, a glazed recess over its entrance and a narrow
  // glass slot on the front, a column of small windows a floor on its west side, flagpole at the corner. Roof
  // blue-grey with plant boxes (Esri imagery). Approximate: the rear and east faces (no photos; windows drawn like the
  // west side's), the depth of the portal and the glass box, the stone's coursing. Method: docs/METODOLOGIA.md §9.
  {const F=localFrame(-167.1,592.6,91.3*Math.PI/180),{G,Gs,V,N3,R}=F;
    const K={stone:C('#ECE8DF'),stone2:C('#E0DBD0'),plinth:C('#ABA9A3'),white:C('#EEEBE3'),roof:C('#8D97A0'),plant:C('#B9B7B1'),
      glass:C('#4C6B78'),glass2:C('#405D69'),mull:C('#8C9CA3'),boxg:C('#6A8B92'),boxg2:C('#5D7D85'),louv:C('#C8D2D0'),
      door:C('#2E3A40'),win:C('#3B4653'),pave:C('#D9D3C5'),pave2:C('#C6BFAF'),mast:C('#707070'),red:C('#C8352B'),blue:C('#2D4F9A'),fw:C('#F1EEE6')};
    const {box,WL,WV,WU,rect}=facade(S,F,K);
    const H=24,HT=H-.03,FL=[0.3,4.3,7.9,11.5,15.1,18.7]; // roof line (walls stop 3 cm under the roof: no seams); floor levels (ground floor 4 m, then 3.6 m)
    // footprint (OSM) plus the paved forecourt to the Alameda's sidewalk: levels the ground and keeps the city off it
    const fp=Gs([[-16.6,-43],[18.2,-43],[18.2,17.3],[6,17.4],[5.6,8],[0.5,7.8],[0.5,18],[-13.7,17.8],[-11.5,4.7],[-16.7,4.7]]);
    occMark(fp);S.dy=padAt(Math.min(...fp.map(p=>p[0])),Math.min(...fp.map(p=>p[1])),Math.max(...fp.map(p=>p[0])),Math.max(...fp.map(p=>p[1])));
    // stone walls in courses of two tones (one band per half floor), a white coping, a roof with plant boxes
    const courses=(w,s0,s1,h0=4.3,h1=H-.45)=>{for(let h=h0,k=0;h<h1-1e-6;h+=1.8,k++)if(k%2)rect(w,s0,s1,h,Math.min(h+1.8,h1),K.stone2);};
    const windows=(w,ss,wd=1.2)=>{for(const f of FL.slice(1))for(const s of ss)rect(WL(w.a,w.b,w.out,.09),s-wd/2,s+wd/2,f+1,f+2.5,K.win);};
    const wall=(a,b,out)=>Object.assign(WL(a,b,out),{a,b,out});
    // forecourt: paving in strips, two steps up to the Corte's door
    for(let v=-43,k=0;v<-16.1-1e-6;v+=3,k++)S.quadXY(R(-16.6,v,v<-31.9?18.2:5,Math.min(v+3,v<-31.9?-31.9:-16.1)),0.33,k%2?K.pave2:K.pave);
    box(-12.6,-18.4,4.8,-17.2,0.3,0.55,K.pave2,K.pave);box(-12.6,-17.2,4.8,-16.1,0.3,0.8,K.pave2,K.pave);
    // the Corte: the main mass behind the curtain wall (v -12 back to the rear, OSM outline)
    const cor=[[-16.6,-12],[-16.7,4.7],[-11.5,4.7],[-13.7,17.8],[0.5,18],[0.5,7.8],[5,8],[5,-12]];
    S.prism(Gs(cor),0.3,HT,K.stone,K.roof,false);
    // portal: west pier and the deep slab on top, the stone ends 0.45 m proud as a white coping
    box(-16.6,-16.1,-13.1,-12,0.3,HT,K.stone,K.roof,false);box(-13.1,-16.1,5,-12,20.4,HT,K.stone,K.roof,false);
    {const w=WV(-16.1,-1);rect(w,-16.6,-13.1,0.3,4.3,K.plinth);rect(WV(-16.1,-1,.09),-16.6,5,H-.45,H,K.white);
      rect(WV(-16.1,-1,.09),-13.1,5,20.4,20.85,K.white);courses(w,-16.6,-13.1);courses(w,-13.1,5,20.4);}
    // recessed curtain wall at v=-12: glass in floor bands of two tones, light spandrels, mullions every 3 m, doors
    {const w=WV(-12,-1),w2=WV(-12,-1,.09),w3=WV(-12,-1,.12);
      FL.forEach((f,k)=>{rect(w,-13.1,5,f,k<5?FL[k+1]:20.4,k%2?K.glass2:K.glass);if(k)rect(w2,-13.1,5,f-.25,f+.25,K.mull);});
      for(let u=-13.1+3;u<5-1;u+=3)rect(w3,u-.2,u+.2,4.3,20.4,K.mull);
      rect(w3,-12.2,-8.2,0.3,3.4,K.door);rect(w2,-13.1,5,3.5,4.05,K.mull);}
    // the glass box proud of it: louvred glass on three sides, white frame (top and west edge), stone base
    {const u0=-5,u1=2.5,v0=-15.4,v1=-12,h1=17.6;box(u0,v0,u1,v1,0.3,h1,K.boxg,K.white);
      box(u0-.5,v0-.5,u1+.5,v1,h1,h1+.6,K.white,K.white);box(u0-.5,v0-.5,u0,v1,0.3,h1,K.white,K.white);
      for(const [w,wl,s0,s1] of [[WV(v0,-1,.09),WV(v0,-1,.12),u0,u1],[WU(u1,1,.09),WU(u1,1,.12),v0,v1]]){rect(w,s0,s1,0.3,4.3,K.stone);
        for(let h=4.3,k=0;h<h1-.5;h+=1.8,k++){if(k%2)rect(w,s0,s1,h,h+1.8,K.boxg2);rect(wl,s0,s1,h+1.3,h+1.7,K.louv);}}}
    // west face: plinth, courses, a louvred glass strip
    {const w=WU(-16.6,-1),w2=WU(-16.6,-1,.09),w3=WU(-16.6,-1,.12);rect(w,-16.1,4.7,0.3,4.3,K.plinth);courses(w,-16.1,-9.5);courses(w,1.5,4.7);
      rect(w2,-9.5,1.5,4.3,H-1.2,K.glass);for(let h=5.5;h<H-1.5;h+=1.2)rect(w3,-9.5,1.5,h,h+.4,K.louv);rect(WU(-16.6,-1,.09),-16.1,4.7,H-.45,H,K.white);}
    // Corte rear faces: windows a floor (approximate)
    {const wv=wall([-13.7,17.8],[0.5,18],[0,1]);rect(wv,0,wv.L,0.3,4.3,K.plinth);windows(wv,[2.5,6.5,10.5]);
      const e=wall([5,8],[0.5,7.8],[0,1]);windows(e,[1.5,3.5]);}
    // Juzgados wing
    {const u0=5,u1=18.2,v0=-31.9,v1=17.3;box(u0,v0,u1,v1,0.3,HT,K.stone,K.roof,false);
      const s=WV(v0,-1),s2=WV(v0,-1,.09),s3=WV(v0,-1,.12);rect(s,u0,u1,0.3,4.3,K.plinth);courses(s,9.6,13.6);courses(s,15.3,u1);courses(s,u0,5.8);
      rect(s2,u0,u1,H-.45,H,K.white);
      // glazed recess over the entrance and the slot: glass in floor bands
      FL.forEach((f,k)=>{const t=k<5?FL[k+1]:H-1;rect(s2,5.8,9.6,f,t,k%2?K.glass2:K.glass);rect(s2,13.6,15.3,Math.max(f,4.3),t,k%2?K.glass:K.glass2);});
      rect(s3,6.2,9.2,0.3,3.2,K.door);box(5.6,v0-1.6,9.8,v0,3.7,4.1,K.white,K.white);
      // west side (seen from 2 Poniente): plinth, courses, a column of small windows per floor; east and rear
      const w=wall([u0,v0],[u0,-16.2],[-1,0]),ws=WU(u0,-1);rect(ws,v0,-16.2,0.3,4.3,K.plinth);courses(ws,v0,-16.2);
      rect(WU(u0,-1,.09),v0,-16.2,H-.45,H,K.white);windows(w,[4,10],1);
      const e=wall([u1,v0],[u1,v1],[1,0]),es=WU(u1,1);rect(es,v0,v1,0.3,4.3,K.plinth);courses(es,v0,v1);rect(WU(u1,1,.09),v0,v1,H-.45,H,K.white);
      windows(e,[4,10,16,22,28,34,40,45]);
      const n=wall([u0+.8,v1],[u1,v1],[0,1]);rect(WV(v1,1),u0+.8,u1,0.3,4.3,K.plinth);windows(n,[3,6.5,10]);}
    // one flat roof over the whole outline (OSM), with plant boxes
    S.flat(Gs([[-16.6,-16.1],[-16.7,4.7],[-11.5,4.7],[-13.7,17.8],[0.5,18],[0.5,7.8],[5,8],[5,17.3],[18.2,17.3],[18.2,-31.9],[5,-31.9],[5,-16.1]]),H,K.roof);
    box(-9,0,-3,6,H,H+1.6,K.plant,K.plant);box(-1,-6,3,-2,H,H+1.2,K.plant,K.plant);box(8,-8,15,-2,H,H+1.8,K.plant,K.plant);
    box(9,4,13,9,H,H+1.2,K.plant,K.plant);
    // flagpole at the wing's corner, with the Chilean flag
    {const pu=4,pv=-34.5;box(pu-.2,pv-.2,pu+.2,pv+.2,0.3,13,K.mast,K.mast);
      for(const sg of [-1,1]){const fw=WV(pv+sg*.05,sg,0);rect(fw,pu-3,pu-1.2,11.6,12.8,K.fw);rect(fw,pu-1.2,pu,11.6,12.8,K.blue);rect(fw,pu-3,pu,10.4,11.6,K.red);}}
    const c=G(1,-6);MODELS['corte-apelaciones']={x:c[0],y:c[1],h:27};S.dy=0;}
