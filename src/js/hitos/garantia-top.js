  // ==== hito: garantia-top ====
  // Juzgado de Garantía and Tribunal de Juicio Oral en lo Penal (4 Norte 541), a three-storey brick building north
  // of the Alameda between 3 and 2 Poniente, built on S with windows drawn by hand. Plan from OpenStreetMap
  // w563110572, in the frame of landmark.py frame garantia-top 563110572 (v north, away from the Alameda; u east):
  // a 35 × 35 m block with a forward wing on the Alameda side. Heights, materials and colours from Google Street View
  // (March 2024) and current Google imagery: red-brown brick to ~12.5 m with a white coping; the entrance is a glass
  // curtain wall under a thin flat canopy on slender white columns, between a brick volume with a tall glass slot
  // (east) and the main block (west); a pale green roof with a skylight over the centre. Behind a white palisade fence
  // (not drawn: too thin) and a paved yard. Approximate: the depth of the glazed porch, the rear and east faces (no
  // views; windows drawn by floor), the skylight's size. Method: docs/METODOLOGIA.md §9.
  {const F=localFrame(-285.5,577.4,92.4*Math.PI/180),{G,Gs,V,N3,R}=F;
    const K={brick:C('#A6553D'),brick2:C('#984D37'),white:C('#ECE7DC'),roof:C('#B3BFA3'),sky:C('#3B4653'),
      glass:C('#4C6B78'),glass2:C('#405D69'),mull:C('#8C9CA3'),win:C('#3B4653'),door:C('#2E3A40'),col:C('#EEEBE3'),
      pave:C('#CFCAC0'),pave2:C('#C2BDB2'),flagb:C('#2D4F9A'),flagr:C('#C8352B')};
    const {box,WL,WV,WU,rect}=facade(S,F,K);
    const H=12.5,HT=H-.03,FL=[0.3,4.5,8.5]; // roof line (walls stop 3 cm under it); floor levels
    // footprint (OSM) plus the paved yard to the Alameda's sidewalk
    const fp=Gs([[-16,-28],[19,-28],[19,29],[-16,29]]);
    occMark(fp);S.dy=padAt(Math.min(...fp.map(p=>p[0])),Math.min(...fp.map(p=>p[1])),Math.max(...fp.map(p=>p[0])),Math.max(...fp.map(p=>p[1])));
    for(let v=-28,k=0;v<-6-1e-6;v+=3.5,k++)S.quadXY(R(-16,v,19,Math.min(v+3.5,-6)),0.33,k%2?K.pave2:K.pave);
    // brick in floor bands of two tones, a white coping on every outer wall
    const bands=(w,s0,s1)=>{FL.forEach((f,k)=>{if(k%2)rect(w,s0,s1,f,k<2?FL[k+1]:H-.45,K.brick2);});rect(WL(w.a,w.b,w.out,.09),0,w.L,H-.45,H,K.white);};
    const wall=(a,b,out)=>Object.assign(WL(a,b,out),{a,b,out});
    const windows=(w,ss,wd=1.4)=>{for(const f of FL.slice(1))for(const s of ss)rect(WL(w.a,w.b,w.out,.12),s-wd/2,s+wd/2,f+1,f+2.6,K.win);};
    // the volumes: main block (OSM outline behind the porch) and the brick volume with the slot on the east
    const main=[[-16,-6],[-12,-6],[-12,-9],[-1,-9],[-1,-6],[9,-6],[9,-9],[19,-9],[19,29],[-16,29]];
    S.prism(Gs(main),0.3,HT,K.brick,K.roof,false);box(-1,-14,9,-6,0.3,HT,K.brick,K.roof,false);
    S.flat(Gs([[-16,-6],[-12,-6],[-12,-9],[-1,-9],[-1,-14],[9,-14],[9,-9],[19,-9],[19,29],[-16,29]]),H,K.roof);
    // outer walls: bands, coping and windows (by floor; the west face has a glazed strip by its south corner)
    const outs=[[[-16,29],[-16,-6],[-1,0]],[[-16,-6],[-12,-6],[0,-1]],[[-1,-14],[9,-14],[0,-1]],[[9,-14],[9,-9],[1,0]],
      [[9,-9],[19,-9],[0,-1]],[[19,-9],[19,29],[1,0]],[[19,29],[-16,29],[0,1]],[[-1,-6],[-1,-14],[-1,0]]];
    const W=outs.map(([a,b,o])=>{const w=wall(a,b,o);bands(w,0,w.L);return w;});
    windows(W[0],[8,12,16,20,24,28]);windows(W[5],[6,10,14,18,22,26,30,34]);windows(W[6],[4,8,12,16,20,24,28,32]);windows(W[4],[3,7]);
    rect(WL(W[0].a,W[0].b,W[0].out,.12),30,34,4.5,11.4,K.glass);for(const h of [6,8.5,11])rect(WL(W[0].a,W[0].b,W[0].out,.15),30,34,h-.2,h+.2,K.mull);
    // the brick volume's front: a tall glass slot; the flagpole in front of it
    {const w=W[2];rect(WL(w.a,w.b,w.out,.12),5.6,6.8,1,11.5,K.glass);rect(WL(w.a,w.b,w.out,.12),5.6,6.8,0.3,1,K.door);}
    {const pu=3,pv=-15.6;box(pu-.2,pv-.2,pu+.2,pv+.2,0.3,10.5,K.mull,K.mull);
      for(const w of [WV(pv-.05,-1,0),WV(pv+.05,1,0)]){rect(w,pu+.2,pu+1.4,9.2,10.2,K.flagb);rect(w,pu+1.4,pu+3,9.2,10.2,K.col);rect(w,pu+.2,pu+3,8.2,9.2,K.flagr);}}
    // glazed porch: curtain wall at v=-9 between the main block and the brick volume, the canopy and its columns
    {const w=WV(-9,-1),w2=WV(-9,-1,.09),w3=WV(-9,-1,.12);
      FL.forEach((f,k)=>{rect(w,-12,-1,f,k<2?FL[k+1]:11,k%2?K.glass2:K.glass);if(k)rect(w2,-12,-1,f-.2,f+.2,K.mull);});
      for(let u=-10;u<-1;u+=2.2)rect(w3,u-.15,u+.15,4.7,11,K.mull);rect(w3,-8.5,-4.5,0.3,3.4,K.door);
      box(-13,-14.6,-1,-9,11,11.6,K.col,K.col);
      for(let u=-11.6;u<-1;u+=3)S.prism(Gs(ngon(u,-13.8,.3,8)),0.3,11,K.col,K.col,false);}
    // roof: the skylight over the central hall, plant boxes
    box(-6,12,14,19,H,H+1.2,K.white,K.sky);box(10,-4,15,0,H,H+1.3,K.white,K.white);box(-12,22,-8,26,H,H+1,K.white,K.white);
    const c=G(1.5,8);MODELS['garantia-top']={x:c[0],y:c[1],h:14};S.dy=0;}
