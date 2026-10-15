  // ==== hito: fiscalia-local ====
  // Fiscalía Local de Talca (4 Norte 703, at 1 Poniente), the Ministerio Público building delivered by the MOP in
  // late 2021 (four floors, terrace and basement, 3,297 m²); built on S, windows drawn by hand. Plan from OpenStreetMap
  // w975848488 (28.6 × 48.5 m), in the frame of landmark.py frame fiscalia-local 975848488: v north, u east. Heights,
  // materials and colours from Google Street View (March 2024) and a press photo of the delivery (Radio Agricultura,
  // December 2021): dark slate cladding in courses, white concrete bands at the floor slabs; on 1 Poniente a ribbon
  // window on the second floor and grey aluminium louvres over the top two, with orange panels behind them; on the
  // Alameda corner a glazed ground floor under a light grey panelled box topped by a white steel pergola; the
  // institution's emblem and two flagpoles on the front; a forecourt of red pavers. ~13.6 m to the coping, 15.4 m
  // to the box. The Esri imagery predates it (empty lot); the roof follows current Google imagery. Approximate: the
  // east and north faces (no views; drawn like the west face), the box's depth, the louvres' pattern, the rooftop
  // terrace. Method: docs/METODOLOGIA.md §9.
  {const F=localFrame(-43.7,585.5,Math.PI/2),{G,Gs,V,N3,R}=F;
    const K={slate:C('#737981'),slate2:C('#686E76'),white:C('#E6E4DE'),conc:C('#C9C7C1'),roof:C('#9EA1A0'),deck:C('#B9AF9E'),
      panel:C('#C2C4C3'),panel2:C('#B3B6B6'),louv:C('#A9ADAF'),louv2:C('#868C90'),orange:C('#D27A3E'),
      glass:C('#3E5560'),glass2:C('#34474F'),mull:C('#8C9CA3'),win:C('#3B4653'),steel:C('#ECEBE6'),
      pave:C('#C38A7B'),pave2:C('#AF7C6F'),pole:C('#D8D8D4'),plant:C('#B9B7B1')};
    const {box,WL,WV,WU,rect}=facade(S,F,K);
    const H=13.6,HT=H-.03,U0=-14.3,U1=14.3,V0=-24.3,V1=24.3;
    // footprint (OSM) plus the paved forecourt to the Alameda's sidewalk
    const fp=Gs([[U0,-37],[U1,-37],[U1,V1],[U0,V1]]);
    occMark(fp);S.dy=padAt(Math.min(...fp.map(p=>p[0])),Math.min(...fp.map(p=>p[1])),Math.max(...fp.map(p=>p[0])),Math.max(...fp.map(p=>p[1])));
    for(let v=-37,k=0;v<V0-1e-6;v+=2.6,k++)S.quadXY(R(U0,v,U1,Math.min(v+2.6,V0)),0.33,k%2?K.pave2:K.pave);
    // the main block; the corner box (u U0..-3, v V0..-14) stands proud of it from the first-floor slab up
    const BU=-3,BV=-14;
    S.prism(Gs([[BU,V0],[U1,V0],[U1,V1],[U0,V1],[U0,BV],[BU,BV]]),0.3,HT,K.slate,K.roof,false);
    S.flat(Gs([[U0,V0],[U1,V0],[U1,V1],[U0,V1]]),H,K.roof);
    const wall=(a,b,out)=>Object.assign(WL(a,b,out),{a,b,out}),at=(w,o)=>WL(w.a,w.b,w.out,o);
    const slate=(w,s0,s1,h0,h1)=>{for(let h=h0,k=0;h<h1-1e-6;h+=1.1,k++)if(k%2)rect(w,s0,s1,h,Math.min(h+1.1,h1),K.slate2);};
    // a side in the 1 Poniente manner: slate ground floor with paired windows, white slab band, ribbon window,
    // band, louvres with orange panels between concrete piers, white coping
    const side=(w,s0,s1,seed)=>{slate(w,s0,s1,0.3,4.3);rect(at(w,.09),s0,s1,4.3,4.8,K.white);
      rect(w,s0,s1,4.8,7.6,K.glass);for(let s=s0+1.5;s<s1-.5;s+=1.6)rect(at(w,.09),s-.12,s+.12,4.8,7.6,K.mull);
      rect(at(w,.09),s0,s1,7.6,8.2,K.white);
      for(let h=8.2,k=0;h<13-1e-6;h+=.6,k++)rect(w,s0,s1,h,h+.6,k%2?K.louv2:K.louv);
      let j=0;for(let s=s0+1;s<s1-2;s+=2.2,j++)for(let r=0;r<3;r++)if((j*5+r*3+seed)%7<2)rect(at(w,.09),s,s+1.6,8.6+r*1.5,9.6+r*1.5,K.orange);
      for(let s=s0;s<=s1+1e-6;s+=Math.max(4,(s1-s0)/Math.round((s1-s0)/9.5)))rect(at(w,.12),Math.max(s0,s-.5),Math.min(s1,s+.5),4.8,13,K.conc);
      rect(at(w,.12),s0,s1,13,H,K.white);
      for(let s=s0+2;s<s1-1.5;s+=4.5)for(const d of [-.75,.75])rect(at(w,.12),s+d-.55,s+d+.55,1.5,2.7,K.win);};
    const W=wall([U0,V1],[U0,BV],[-1,0]);side(W,0,W.L,1);
    const E=wall([U1,V0],[U1,V1],[1,0]);side(E,0,E.L,4);
    const N=wall([U1,V1],[U0,V1],[0,1]);side(N,0,N.L,2);
    // the front's slate part: courses, two white bands, small framed windows, the big window, emblem and flagpoles
    {const w=WV(V0,-1),w2=WV(V0,-1,.09),w3=WV(V0,-1,.12);slate(w,BU,U1,0.3,H-.45);
      rect(w2,BU,U1,3.9,4.4,K.white);rect(w2,BU,U1,7.9,8.4,K.white);rect(w2,BU,U1,H-.45,H,K.white);
      for(const u of [-1.2,.6,2.8,4.6,6.8,8.6]){rect(w2,u-.8,u+.8,1.2,2.9,K.white);rect(w3,u-.55,u+.55,1.45,2.65,K.win);}
      rect(w2,7.6,11.6,4.9,7.4,K.white);rect(w3,7.9,11.3,5.2,7.1,K.win);
      rect(w2,2.7,4.5,10,11.6,K.white);rect(w2,1.8,5.4,9.3,9.7,K.white);
      for(const u of [10.2,11.4])box(u-.2,V0-1.2,u+.2,V0-.8,0.3,12.4,K.pole,K.pole);}
    // the corner: glazed ground floor (curtain walls in two tones with mullions), the panelled box above it
    // (light panels to the Alameda, dark louvres to 1 Poniente), the steel pergola on top
    {const g=WV(V0,-1),gw=WU(U0,-1);rect(g,U0,BU,0.3,4.3,K.glass);rect(gw,V0,BV,0.3,4.3,K.glass);
      for(let u=U0+1.6;u<BU;u+=1.8)rect(WV(V0,-1,.09),u-.12,u+.12,0.3,4.3,K.mull);
      for(let v=V0+1.6;v<BV;v+=1.8)rect(WU(U0,-1,.09),v-.12,v+.12,0.3,4.3,K.mull);
      box(U0,V0,BU,BV,0.3,4.3,K.glass,K.glass,false);
      const X0=U0-.6,Y0=V0-.6,HB=15.4;box(X0,Y0,BU,BV,4.3,HB,K.panel,K.roof);
      {const w=WV(Y0,-1);for(let h=4.3,k=0;h<HB-.5;h+=1.2,k++)if(k%2)rect(w,X0,BU,h,h+1.2,K.panel2);rect(WV(Y0,-1,.09),X0,BU,HB-.4,HB,K.white);}
      {const w=WU(X0,-1);for(let h=4.3,k=0;h<HB-.4;h+=.6,k++)rect(w,Y0,BV,h,h+.6,k%2?K.louv2:K.louv);rect(WU(X0,-1,.09),Y0,BV,HB-.4,HB,K.white);}
      rect(WU(BU,1),Y0,V0,4.3,HB,K.panel);
      const pg=[[X0+.2,Y0+.2],[BU-.4,Y0+.2],[BU-.4,BV-.4],[X0+.2,BV-.4]];
      for(const [u,v] of pg)box(u,v,u+.4,v+.4,HB,HB+2.3,K.steel,K.steel);
      box(X0+.2,Y0+.2,BU,Y0+.6,HB+2.3,HB+2.7,K.steel,K.steel);box(X0+.2,BV-.4,BU,BV,HB+2.3,HB+2.7,K.steel,K.steel);
      box(X0+.2,Y0+.6,X0+.6,BV-.4,HB+2.3,HB+2.7,K.steel,K.steel);box(BU-.4,Y0+.6,BU,BV-.4,HB+2.3,HB+2.7,K.steel,K.steel);
      box(X0+.6,(Y0+BV)/2-.2,BU-.4,(Y0+BV)/2+.2,HB+2.3,HB+2.7,K.steel,K.steel);}
    // roof: terrace deck to the north-east, plant boxes
    S.quadXY(R(2,6,U1-1,V1-1),H+.05,K.deck);box(-10,-6,-4,0,H,H+1.4,K.plant,K.plant);box(-9,6,-4,12,H,H+1.1,K.plant,K.plant);
    const c=G(0,-2);MODELS['fiscalia-local']={x:c[0],y:c[1],h:18};S.dy=0;}
