  // ==== hito: liceo-abate-molina ====
  // Liceo Abate Molina, on the Alameda between 5 and 6 Oriente, drawn on S. Plan from OpenStreetMap: the historic
  // building r9394557 (a front range set back behind a forecourt, two wings to the street with light wells), the
  // new range w798161251 ("Zona Nueva", rebuilt after the 2010 earthquake, which brought down part of the school;
  // reconstruction 2012–2015, Cooperativa) and the school grounds w798996848. Frame from landmark.py frame
  // liceo-abate-molina 798161253: u east, v north; the front range's face is v=-19 (the pavilion, -21). The historic
  // front still stands (File:Monumento A Molina1.jpg, 2024; File:Talca liceo abate molina.jpg, 2005): white walls
  // between cream piers, arched windows upstairs, a raised cream pavilion with the "Liceo de Hombres" panel and a
  // flag, iron railings on a white wall, and the Abate Molina statue (1861) on its pedestal in front. Roofs (grey
  // metal, hipped), the covered courts with pale green roofs and the pool hall to the north from the Esri imagery
  // (date unknown). Approximate: heights (two storeys, ~10 m; scaled from the 2024 photo with the door), the side
  // and inner façades (drawn like the front), the new range's look (no photos), the courts' roofs.
  {const F=localFrame(597.6,583.4,90.7*Math.PI/180),{G,Gs,V,N3,R}=F;
    const K={white:C('#ECE7DC'),whiteSh:C('#D9D3C6'),cream:C('#E0CDA4'),cream2:C('#D2BD90'),plinth:C('#C9C3B6'),
      glass:C('#3B4653'),glass2:C('#2C3540'),door:C('#5A4636'),roof:C('#ADABA4'),roof2:C('#9D9B94'),flat:C('#8F8A82'),
      newWall:C('#E4E0D6'),newBand:C('#B65A3C'),court:C('#B7C7A4'),court2:C('#A7B994'),hall:C('#E8E6E0'),
      pave:C('#D8D1C1'),pave2:C('#CCC4B2'),pitch:C('#7D8E8C'),line:C('#F3F0E6'),iron:C('#3A3A3A'),mast:C('#707070'),
      red:C('#C8312A'),blue:C('#2C4A8C'),stone:C('#7F8A80'),stone2:C('#6F7A71'),bronze:C('#3C4540'),bronze2:C('#2F3632'),
      tile:C('#ADABA4'),tile2:C('#9D9B94')};
    const {box,WL,WV,WU,rect,arch}=facade(S,F,K);
    // the grounds: no procedural lots inside the school's fence; level pad under all of it
    const site=Gs([[-40,-30],[-36,-33],[8,-33],[9,-31],[10,-29],[20,-29],[22,-31],[22,-33],[69,-34],[73,-30],[71,92],[68,95],[-41,94]]);
    NOLOTS.push(site);
    S.dy=padAt(Math.min(...site.map(p=>p[0])),Math.min(...site.map(p=>p[1]))-3,Math.max(...site.map(p=>p[0])),Math.max(...site.map(p=>p[1])));
    const bld=(u0,v0,u1,v1)=>occMark(R(u0,v0,u1,v1));
    // hipped roof over a rectangle, eaves at h (0.4 m overhang), ridge rh higher, along its longer side
    const hip=(u0,v0,u1,v1,h,rh,o=.4)=>{u0-=o;v0-=o;u1+=o;v1+=o;const alU=u1-u0>=v1-v0,hw=(alU?v1-v0:u1-u0)/2;
      if(alU){const vm=(v0+v1)/2,a=Math.min(u0+hw,(u0+u1)/2),b=Math.max(u1-hw,(u0+u1)/2);
        S.face([V(u0,v0,h),V(u1,v0,h),V(b,vm,h+rh),V(a,vm,h+rh)],null,K.roof);S.face([V(u1,v1,h),V(u0,v1,h),V(a,vm,h+rh),V(b,vm,h+rh)],null,K.roof2);
        S.face([V(u0,v1,h),V(u0,v0,h),V(a,vm,h+rh)],null,K.roof2);S.face([V(u1,v0,h),V(u1,v1,h),V(b,vm,h+rh)],null,K.roof);}
      else{const um=(u0+u1)/2,a=Math.min(v0+hw,(v0+v1)/2),b=Math.max(v1-hw,(v0+v1)/2);
        S.face([V(u0,v1,h),V(u0,v0,h),V(um,a,h+rh),V(um,b,h+rh)],null,K.roof2);S.face([V(u1,v0,h),V(u1,v1,h),V(um,b,h+rh),V(um,a,h+rh)],null,K.roof);
        S.face([V(u0,v0,h),V(u1,v0,h),V(um,a,h+rh)],null,K.roof);S.face([V(u1,v1,h),V(u0,v1,h),V(um,b,h+rh)],null,K.roof2);}};
    // the historic façade: white wall, cream piers between bays, plinth and cornice; a window below and an arched
    // one above in each bay. mk(o) gives the wall at offset o; s0..s1 along it
    const H=10;
    const bays=(mk,s0,s1,piers=true)=>{const w=mk(.06),n=Math.max(1,Math.round((s1-s0)/4.4)),d=(s1-s0)/n;
      rect(w,s0,s1,0.3,1.1,K.plinth);rect(mk(.09),s0,s1,H-.6,H,K.white);
      if(piers)for(let k=0;k<=n;k++){const s=s0+k*d;rect(mk(.12),Math.max(s0,s-.45),Math.min(s1,s+.45),0.3,H-.6,K.cream);}
      for(let k=0;k<n;k++){const c=s0+(k+.5)*d;rect(w,c-.7,c+.7,1.6,3.6,K.glass);arch(w,c,1.4,5.2,8.2,K.glass);rect(mk(.09),c-.85,c+.85,4.9,5.2,K.whiteSh);}};
    const fU=(u,sg)=>o=>WU(u,sg,o),fV=(v,sg)=>o=>WV(v,sg,o);
    const range=(u0,v0,u1,v1,sides,hipIt=true)=>{box(u0,v0,u1,v1,0.3,H,K.white,K.flat);bld(u0,v0,u1,v1);
      for(const sd of sides){if(sd==='S')bays(fV(v0,-1),u0,u1);if(sd==='N')bays(fV(v1,1),u0,u1);if(sd==='W')bays(fU(u0,-1),v0,v1);if(sd==='E')bays(fU(u1,1),v0,v1);}
      if(hipIt)hip(u0,v0,u1,v1,H,1.8);};
    // front range, either side of the pavilion
    range(-9,-19,9,-6,['S','N']);range(23,-19,42,-6,['S','N']);
    // west wing (to 5 Oriente): south front, a west range, an inner range, and the bits between the two light wells
    range(-40,-33,-9,-23,['S','W','E']);range(-40,-23,-28.5,22,['W']);range(-19.5,-23,-9,22,['E']);
    range(-28.5,-16,-19.5,-9,[]);range(-28.5,9,-19.5,22,['N']);range(-16,22,-9,30,['N','E']);
    // east wing (to 6 Oriente) round its light well
    range(42,-34,73,-24,['S','E','W']);range(42,-24,52,10,['W']);range(62,-24,73,10,['E']);range(42,10,73,21,['W','E']);range(42,21,53,31,['N','W']);
    // pavilion: cream mass with a white centre bay, the doorway, the panel and the flag, a little higher
    {const u0=9,u1=23,v0=-21,v1=-6,PH=12.7;box(u0,v0,u1,v1,0.3,PH,K.cream,K.flat);bld(u0,v0,u1,v1);
      const w=WV(v0,-1),w2=WV(v0,-1,.09),w3=WV(v0,-1,.12);
      rect(w,u0,u1,0.3,1.1,K.plinth);rect(w2,u0,u1,PH-.5,PH,K.white);rect(w2,u0,u1,10,10.4,K.cream2);
      rect(w,12.4,19.6,1.1,10,K.white);rect(w,9.7,11.7,1.1,10,K.white);rect(w,20.3,22.3,1.1,10,K.white);
      for(const c of [14.6,17.4])arch(w3,c,1.9,5.3,8.9,K.glass);for(const c of [10.7,21.3])arch(w3,c,1.1,5.3,8.6,K.glass);
      for(const c of [10.7,21.3])rect(w3,c-.55,c+.55,1.7,3.7,K.glass);
      rect(w3,14.8,17.2,1.1,3.8,K.door);rect(w2,13.6,18.4,11.05,11.95,K.white);
      for(const [u,sg] of [[u0,-1],[u1,1]]){const s=WU(u,sg);rect(s,v0,v1,0.3,1.1,K.plinth);rect(WU(u,sg,.09),v0,v1,PH-.5,PH,K.white);}
      // steps to the door
      box(14.2,-23.4,17.8,-21,0.3,0.55,K.plinth,K.pave);box(14.2,-22.6,17.8,-21,0.55,0.8,K.plinth,K.pave);
      // flag on the parapet (Chile: white over red, blue canton)
      box(15.85,-13.6,16.15,-13.3,PH,20,K.mast,K.mast);
      const fw=WV(-13.45,-1,.2),fq=(s,h)=>fw.q(s,h);
      S.face([fq(16.15,19.2),fq(18.45,19.2),fq(18.45,19.8),fq(16.15,19.8)],fw.n,K.white);S.face([fq(16.15,18.6),fq(18.45,18.6),fq(18.45,19.2),fq(16.15,19.2)],fw.n,K.red);
      const fb=WV(-13.45,-1,.23);S.face([fb.q(16.15,19.2),fb.q(16.85,19.2),fb.q(16.85,19.8),fb.q(16.15,19.8)],fb.n,K.blue);}
    // new range (2 storeys, plain, a terracotta band; look approximate): north bar and two legs
    {const nb=(u0,v0,u1,v1)=>{box(u0,v0,u1,v1,0.3,7.6,K.newWall,K.flat);bld(u0,v0,u1,v1);hip(u0,v0,u1,v1,7.6,1.4);};
      nb(-40,43,72,57);nb(-40,22,-28.5,43);nb(61,21,72,43);
      for(const [w,a,b] of [[WV(43,-1),-28.5,61],[WV(57,1),-40,72],[WU(-40,-1),22,57],[WU(72,1),21,57],[WU(-28.5,1),22,43],[WU(61,-1),21,43]]){
        rect(w,a,b,3.6,4,K.newBand);for(let s=a+2;s<b-1.5;s+=3.5){rect(w,s-.8,s+.8,1.2,3,K.glass);rect(w,s-.8,s+.8,4.8,6.6,K.glass);}}}
    // covered courts (pale green, ribbed) and the pool hall to the north (satellite)
    {const hall=(u0,v0,u1,v1,h,wall,c1,c2)=>{box(u0,v0,u1,v1,0.3,h,wall,K.flat,false);bld(u0,v0,u1,v1);
        for(let u=u0,k=0;u<u1-.01;u+=3,k++){const e=Math.min(u+3,u1),c=k%2?c2:c1;const vm=(v0+v1)/2;
          S.face([V(u,v0-.4,h),V(e,v0-.4,h),V(e,vm,h+2.2),V(u,vm,h+2.2)],null,c);S.face([V(e,v1+.4,h),V(u,v1+.4,h),V(u,vm,h+2.2),V(e,vm,h+2.2)],null,c);}
        for(const [u,sg] of [[u0,-1],[u1,1]])S.face([V(u,v0,h),V(u,v1,h),V(u,(v0+v1)/2,h+2.2)],N3(sg,0),wall);};
      hall(-24,70,1,93,7,K.hall,K.court,K.court2);hall(1,70,29.5,93,7,K.hall,K.court,K.court2);
      box(32,70,56,89,0.3,6.5,K.hall,K.hall);bld(32,70,56,89);for(const [w,a,b] of [[WV(70,-1),32,56],[WU(56,1),70,89]])for(let s=a+2;s<b-1;s+=3)rect(w,s-.9,s+.9,3.5,5.6,K.glass);}
    // main patio: paving and the basketball court (OSM w646462667)
    S.quadXY(R(-8.8,-5.8,41.8,20.8),0.32,K.pave);S.quadXY(R(2,4,31,19),0.36,K.pitch);
    for(const q of [R(2,4,31,4.5),R(2,18.5,31,19),R(2,4,2.5,19),R(30.5,4,31,19),R(16.25,4,16.75,19)])S.quadXY(q,0.39,K.line);
    // forecourt: paving, the white wall with iron railings and piers along the Alameda, the gate
    S.quadXY(R(-9,-33,42,-19),0.32,K.pave2);occMark(R(-9,-37,42,-19));
    {const fw=(a,b)=>{box(a,-33.3,b,-32.9,0.3,0.9,K.white,K.white);box(a,-33.15,b,-33.05,0.9,2.1,K.iron,K.iron);
        for(let u=a;u<=b+.01;u+=(b-a)/Math.max(1,Math.round((b-a)/4.5)))box(u-.3,-33.4,u+.3,-32.8,0.3,2.4,K.white,K.white);};
      fw(-9,13.6);fw(18.4,42);for(const u of [13.6,18.4])box(u-.4,-33.5,u+.4,-32.7,0.3,3,K.white,K.white);}
    // the Abate Molina statue on its pedestal, on the pavement in front of the gate (2024 photo)
    {const su=16,sv=-35;box(su-.9,sv-.9,su+.9,sv+.9,0.3,0.8,K.stone2,K.stone2);box(su-.7,sv-.7,su+.7,sv+.7,0.8,3,K.stone,K.stone);
      box(su-.85,sv-.85,su+.85,sv+.85,3,3.35,K.stone2,K.stone);
      box(su-.45,sv-.35,su+.45,sv+.35,3.35,4.6,K.bronze,K.bronze2);box(su-.35,sv-.3,su+.35,sv+.3,4.6,5.4,K.bronze2,K.bronze);
      box(su-.2,sv-.2,su+.2,sv+.2,5.4,5.85,K.bronze,K.bronze);box(su-.85,sv-.3,su-.45,sv+.3,3.35,4.1,K.bronze2,K.bronze2);}
    const c=G(16,-12);MODELS['liceo-abate-molina']={x:c[0],y:c[1],h:21};S.dy=0;}
