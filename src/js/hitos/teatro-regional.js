  // ==== hito: teatro-regional ====
  // Teatro Regional del Maule (2005), on the corner of the Alameda and 1 Oriente, drawn on S. Plan from OpenStreetMap
  // (w214851535; frame from landmark.py frame teatro-regional 214851535: v runs east along the Alameda, u south,
  // the Alameda front is u=-20.5). Volumes from the Esri imagery (flat pale roofs, the fly tower in the east third
  // with plant on top) and from photos on Wikimedia Commons (File:TalcaTeatro.jpg, 2005; File:Talca (37060017476).jpg,
  // 2017): cream stucco hall ~11 m (OSM height 11.2), a banded cylinder, the fly tower ~18.5 m, a low wing with the
  // marquee to the east and, at the 1 Oriente corner, the lobby under a cantilevered roof: a glass front leaning
  // out behind vertical timber louvres. Approximate: the heights (±1.5 m, scaled from the photos), the west and
  // south sides (no photos), the brown box by the cylinder (2017 photo). The timber soffits can't be seen from
  // above, so the visor's roof edge carries a band of their colour (licence); the lobby's night glow is licence too.
  {const F=localFrame(97.9,442.2,1.4*Math.PI/180),{G,Gs,V,N3,R}=F;
    const K={wall:C('#E2D2A6'),wall2:C('#CDBB8E'),tower:C('#ECE5D1'),roof:C('#C8C5BC'),roof2:C('#B5B2A9'),white:C('#F1EEE6'),
      wood:C('#B0663A'),louvre:C('#C49A6C'),glass:C('#3B4653'),glass2:C('#2C3540'),brown:C('#6E4B3A'),step:C('#D9D3C5'),step2:C('#C6BFAF'),
      plant:C('#B9B4A8'),tile:C('#D9D6CC'),tile2:C('#D9D6CC')};
    const {box,WV,WU,rect}=facade(S,F,K);
    const fp=Gs([[7,-33],[7,10],[13,10],[13,23],[-20.5,23],[-20.5,-33]]);occMark(fp);occMark(Gs([[-29,-34],[-20.5,-34],[-20.5,23],[-29,23]])); // the forecourt on the Alameda stays clear
    S.dy=padAt(Math.min(...fp.map(p=>p[0])),Math.min(...fp.map(p=>p[1])),Math.max(...fp.map(p=>p[0])),Math.max(...fp.map(p=>p[1]))+3);
    // a flat-roofed block with a white coping round its top
    const blk=(u0,v0,u1,v1,h0,h1,wall,top=K.roof)=>{box(u0,v0,u1,v1,h0,h1,wall,top);
      for(const [w,a,b] of [[WV(v0,-1,.09),u0,u1],[WV(v1,1,.09),u0,u1],[WU(u0,-1,.09),v0,v1],[WU(u1,1,.09),v0,v1]])rect(w,a,b,h1-.45,h1,K.white);};
    // auditorium: plain cream walls with two reveal bands
    blk(-20.5,-15.5,7,8,0.3,11.2,K.wall);
    for(const [w,a,b] of [[WU(-20.5,-1),-15.5,8],[WU(7,1),-15.5,8]])for(const h of [4.4,8])rect(w,a,b,h,h+.3,K.wall2);
    rect(WU(-20.5,-1,.12),-11,-9.6,0.3,8,K.glass);
    // fly tower, paler, with plant on its roof (satellite)
    blk(-16,5,10,20.5,0.3,18.5,K.tower);box(-12,8,1,17,18.5,19.8,K.plant,K.roof2);
    for(const [w,a,b] of [[WV(20.5,1),-16,10],[WU(-16,-1),5,20.5],[WU(10,1),5,20.5]])rect(w,a,b,11.2,11.5,K.wall2);
    // east: low wing on the Alameda with the marquee on two posts; back of house to the south
    blk(-20.5,8,-16,23,0.3,4.6,K.wall);blk(7,10,13,23,0.3,8,K.wall);blk(-16,20.5,7,23,0.3,8,K.wall);
    rect(WU(-20.5,-1),9.5,21.5,0.3,2.8,K.glass);
    box(-23.2,9.5,-20.5,19.5,3,4.3,K.white,K.roof);rect(WU(-23.2,-1),9.5,19.5,3.35,3.95,K.wall2);
    for(const v of [10.2,18.8])box(-22.9,v-.2,-22.5,v+.2,0.3,3,K.white,K.white);
    // brown box by the cylinder (2017)
    box(-21,-9,-16,-1.5,0.3,6.6,K.brown,K.roof2);rect(WU(-21,-1),-8,-2.5,0.3,2.8,K.glass);
    // banded cylinder on the Alameda front
    {const c=G(-20,-12.8);for(let h=0.3,k=0;h<11.8;k++){const h1=Math.min(11.8,h+(k%2?.5:2.4));S.prism(ngon(c[0],c[1],3.1,16,Math.PI/16),h,h1,k%2?K.wall2:K.wall,K.wall);h=h1;}
      S.prism(ngon(c[0],c[1],3.25,16,Math.PI/16),11.8,12.2,K.white,K.roof);}
    // lobby block at the 1 Oriente corner: walls, the glazed ground floor under a canopy, the leaning glass front
    // with timber louvres, white cheeks and the cantilevered roof
    blk(-18.5,-33,7,-15.5,0.3,12.6,K.wall);
    rect(WU(-18.5,-1),-32.5,-16,0.3,4.5,K.glass);for(let v=-31;v<-16;v+=3)rect(WU(-18.5,-1,.12),v-.2,v+.2,0.3,4.5,K.white);
    rect(WV(-33,-1),-18,4,0.3,4.5,K.glass);
    box(-21.2,-33,-18.5,-15.5,4.5,5.2,K.wood,K.roof2);
    {const lean=(u,h)=>u-(h-5.2)*1.8/7.7,P=(u,v,h)=>V(lean(u,h),v,h),n=N3(-7.7,0,-1.8);
      S.face([P(-20.5,-33,5.2),P(-20.5,-15.5,5.2),P(-20.5,-15.5,12.9),P(-20.5,-33,12.9)],n,K.glass);
      for(let v=-32.4,k=0;v<-15.6;v+=1,k++)S.face([P(-20.62,v,5.2),P(-20.62,v+.45,5.2),P(-20.62,v+.45,12.9),P(-20.62,v,12.9)],n,k%2?K.louvre:K.wood);
      for(const [v,sg] of [[-33,-1],[-15.5,1]])S.face([V(-18.5,v,5.2),V(-20.5,v,5.2),V(-22.3,v,12.9),V(-18.5,v,12.9)],N3(0,sg),K.white);
      box(-23.4,-33.6,-18.5,-15,12.9,14,K.white,K.roof);rect(WU(-23.4,-1),-33.6,-15,12.9,13.45,K.wood);rect(WV(-33.6,-1),-23.4,-18.5,12.9,13.45,K.wood);}
    // entrance steps under the canopy
    box(-22.6,-31,-20.5,-18,0.3,0.55,K.step2,K.step);box(-21.8,-31,-20.5,-18,0.55,0.8,K.step2,K.step2);
    // the glazed lobby glows at night, in front of its leaning glass (licence)
    for(const v of [-29,-24,-19]){const g=G(-21.9,v);GLOW.push(g[0],S.dy+8,g[1]);}
    const c=G(-6,-5);MODELS['teatro-regional']={x:c[0],y:c[1],h:21};S.dy=0;}
