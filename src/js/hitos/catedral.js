  // ==== hito: catedral ====
  // Catedral de San Agustín, on the plaza's west side, facing east; built on S (its windows are drawn, not shaded).
  // Plan from OpenStreetMap: church w114237041 (nave, transept, segmental apse to the west, round baptistery by the
  // façade, sacristy to the north), bell tower w798980080 at the 1 Norte corner, front steps w799225255. Frame from
  // landmark.py frame catedral 114237041: v runs along the nave toward the apse (west), u toward 1 Norte; the façade
  // is the v=-29 line. Heights and colours from dated photos on Wikimedia Commons (2017–2024), measured against the
  // tower's OSM width: white façade 17 m to the shoulders and 20 m to the apex with three arched bays; brick tower
  // with white piers and bands, a setback halfway, balustrade, white belfry and a green spire to ~39 m; brick nave
  // with clerestory windows between white pilasters, tiled roofs. Approximate: the nave's and aisles' exact widths,
  // the transept ends, apse and sacristy (no photos of the west side), the roofs' pitch. Night glow in the façade
  // windows is licence. Method: docs/METODOLOGIA.md §9; style: docs/ESTETICA.md.
  {const F=localFrame(-102.9,32.3,179.3*Math.PI/180),{G,Gs,V,N3,R}=F;
    const K={brick:C('#A04B34'),brick2:C('#8F4330'),white:C('#ECE7DC'),whiteSh:C('#D3CDC0'),plinth:C('#C9C3B6'),
      tile:C('#A35C42'),tile2:C('#8E4F3A'),flat:C('#8F8A82'),glass:C('#3B4653'),glass2:C('#2C3540'),door:C('#5A4636'),
      bell:C('#2E2C2B'),spire:C('#3F5C4E'),iron:C('#3A3A3A'),step:C('#D9D3C5'),step2:C('#C6BFAF')};
    const {box,WL,WV,WU,rect,arch,glass,roof}=facade(S,F,K);
    // footprint (OSM church + tower + steps); it levels the ground and keeps the city off it. The pad takes the plaza's
    // level: pads within ~80 m share terrain nodes and the last one registered wins, which tilted the plaza's west side
    const fp=Gs([[-10,-35],[16,-35],[16,-32.4],[21.7,-32.4],[21.7,-25.8],[16,-25.8],[16,6],[24,6],[24,25],[13,25],[13,24],
      [7,27],[3,28.5],[-2,27],[-6,22.5],[-9,22.5],[-9,17],[-18,17],[-18,6],[-10,6],[-10,-23],[-13.3,-26],[-10,-29]]);
    occMark(fp);S.dy=MODELS['plaza-de-armas'].pad;PADS.push([Math.min(...fp.map(p=>p[0])),Math.min(...fp.map(p=>p[1])),Math.max(...fp.map(p=>p[0])),Math.max(...fp.map(p=>p[1])),S.dy]);
    // front steps (OSM stairs): a landing and two treads, in two tones
    box(-10,-33,16,-28,0.3,0.9,K.step2,K.step);box(-10,-34,16,-33,0.3,0.7,K.step2,K.step2);box(-10,-35,16,-34,0.3,0.5,K.step2,K.step);
    // aisles: brick to 8.5 m under a shed roof that climbs to the nave; arched windows in 8 bays between white
    // pilasters, a white band and plinth. South aisle u -10..-1.5, north 10.5..16; nave u -1.5..10.5
    const NU0=-1.5,NU1=10.5,BAY=35/8;
    for(const [u0,u1,uo,sg] of [[-10,NU0,-10,-1],[NU1,16,16,1]]){const hi=u=>8.5+1.7*Math.abs(u-uo)/(u1-u0);
      box(u0,-29,u1,6,0.3,8.5,K.brick,K.brick,false);
      for(let v=-29,k=0;v<6-1e-6;v+=BAY,k++){const e=v+BAY,ui=sg<0?NU0:NU1,c=k%2?K.tile2:K.tile;
        S.face([V(uo+sg*.5,v,8.4),V(uo+sg*.5,e,8.4),V(ui,e,10.2),V(ui,v,10.2)],N3(sg*1.7,0,u1-u0),c);}
      const w=WU(uo,sg);rect(w,-29,6,0.3,1.1,K.plinth);rect(WU(uo,sg,.09),-29,6,6.3,6.75,K.white);
      for(let v=-29;v<=6+1e-6;v+=BAY)rect(WU(uo,sg,.12),Math.max(-29,v-.3),Math.min(6,v+.3),0.3,8.5,K.white);
      for(let v=-29+BAY/2;v<6;v+=BAY)glass(w,v,1.2,3,5.8);
      // the aisle's front: brick up to the roof's slope, white coping along it, a door in a white frame
      const f=WV(-29,-1,0),fc=WV(-29,-1,.1),a0=sg<0?u0:u1,a1=sg<0?u1-1:u0+1;
      S.face([f.q(a0,8.5),f.q(a1,8.5),f.q(a1,hi(a1))],f.n,K.brick);
      S.face([fc.q(a0,hi(a0)-.4),fc.q(a1,hi(a1)-.4),fc.q(a1,hi(a1)+.1),fc.q(a0,hi(a0)+.1)],fc.n,K.white);
      const fd=WV(-29,-1),dc=(u0+u1)/2+(sg<0?-.5:.3);rect(fd,Math.min(a0,a1),Math.max(a0,a1),0.3,1.0,K.plinth);rect(WV(-29,-1,.09),Math.min(a0,a1),Math.max(a0,a1),6.3,6.75,K.white);
      rect(WV(-29,-1,.12),uo-sg*.7,uo,0.3,8.5,K.white);rect(fd,dc-1.5,dc+1.5,1.0,4.4,K.white);rect(WV(-29,-1,.1),dc-1.1,dc+1.1,0.9,4.0,K.door);}
    // nave: brick to 15 m, clerestory pairs between white pilasters above the aisles, white cornice, tiled roof
    box(NU0,-29,NU1,23,0.3,15,K.brick,K.brick,false);
    for(const [u,sg] of [[NU0,-1],[NU1,1]]){const w=WU(u,sg);rect(WU(u,sg,.12),-28.5,6,14.4,15,K.white);
      for(let v=-29;v<=6+1e-6;v+=BAY)rect(w,Math.max(-28.5,v-.3),Math.min(6,v+.3),10.2,14.4,K.white);
      for(let v=-29+BAY/2;v<6;v+=BAY)for(const d of [-.75,.75])arch(w,v+d,.8,11,13.6,K.glass);}
    roof('v',-28.5,23,NU0,NU1,15,3.5,BAY,[0,1]);
    // transept: arms to u -18 and 24 between v 6 and 17, 14 m to the eaves, ridge across the nave; tall windows
    box(-18,6,24,17,0.3,14,K.brick,K.brick,false);roof('u',-18,24,6,17,14,3.5,BAY);
    for(const [u,sg] of [[-18,-1],[24,1]]){const w=WU(u,sg);rect(w,6,17,0.3,1.1,K.plinth);glass(w,11.5,2.6,4,11);
      for(const v of [6,16.4])rect(WU(u,sg,.1),v,v+.6,0.3,14,K.white);}
    for(const [v,sg,us,h0] of [[6,-1,[-14,20],3.5],[17,1,[-13.5,18.5],8]]){const w=WV(v,sg);
      for(const u of us)glass(w,u,1.4,h0,12);}
    // chancel and apse: a lower block with a hipped roof and a segmental apse (OSM) under a half cone, white plinth,
    // band and cornice, a window in each face of the curve
    box(-9,17,13,23,0.3,12,K.brick,K.brick,false);pyramid(S,R(-9.4,16.6,13.4,23.4),12,3,K.tile);
    {const cu=3.5,cv=16.5,r=11.5,arc=[];for(let i=0;i<=8;i++){const t=(34.4+(145.6-34.4)*i/8)*Math.PI/180;arc.push([cu+r*Math.cos(t),cv+r*Math.sin(t)]);}
      S.prism(Gs(arc),0.3,11,K.brick,K.brick,false);
      for(let i=0;i<8;i++){const a=arc[i],b=arc[i+1],m=[(a[0]+b[0])/2-cu,(a[1]+b[1])/2-cv],L=Math.hypot(...m),out=[m[0]/L,m[1]/L];
        const w=WL(a,b,out),wl=WL(a,b,out,.1),A0=[a[0]+out[0]*.4,a[1]+out[1]*.4],B0=[b[0]+out[0]*.4,b[1]+out[1]*.4];
        rect(w,0,w.L,0.3,1.3,K.plinth);rect(w,0,w.L,5.8,6.3,K.white);rect(wl,0,w.L,10.4,11,K.white);glass(w,w.L/2,.9,7,9.8);
        S.face([V(...A0,11),V(...B0,11),V(cu,21,13)],null,i%2?K.tile2:K.tile);}}
    // sacristy (OSM, north of the chancel): flat roof behind a white cornice
    box(13,17,24,25,0.3,7.1,K.brick,K.flat);rect(WV(25,1),13,24,6.5,7.1,K.white);rect(WU(24,1),17,25,6.5,7.1,K.white);
    for(const u of [16,20])rect(WV(25,1),u-.6,u+.6,3,5,K.glass);
    // round baptistery south of the façade (OSM): half drum with a white plinth and cornice
    {const half=(r,a0=90)=>{const o=[];for(let i=0;i<=8;i++){const t=(a0+180*i/8)*Math.PI/180;o.push([-10+r*Math.cos(t),-26+r*Math.sin(t)]);}return Gs(o);};
      S.prism(half(3.1),0.3,1.2,K.plinth,K.plinth);S.prism(half(3),1.2,6.6,K.brick,K.brick);S.prism(half(3.3),6.6,7.2,K.white,K.flat);}
    // façade: a white frontispiece, 3 m proud of the aisles, with three arched bays (doors under stained glass) and
    // a pediment that stands above the nave roof, an emblem and an iron cross
    const FU0=-2.5,FU1=11.5,FM=4.5;box(FU0,-32,FU1,-28.5,0.3,17,K.white,K.white);
    {const P=(u,v,h)=>V(u,v,h);S.face([P(FU0,-32,17),P(FU1,-32,17),P(FU1,-32,17.3),P(FM,-32,20.3),P(FU0,-32,17.3)],N3(0,-1),K.white);
      S.face([P(FU0,-28.5,17),P(FU1,-28.5,17),P(FU1,-28.5,17.3),P(FM,-28.5,20.3),P(FU0,-28.5,17.3)],N3(0,1),K.white);
      S.face([P(FU0-.3,-32.3,17.1),P(FM,-32.3,20.4),P(FM,-28.2,20.4),P(FU0-.3,-28.2,17.1)],N3(-3.3,0,7),K.whiteSh);
      S.face([P(FU1+.3,-32.3,17.1),P(FM,-32.3,20.4),P(FM,-28.2,20.4),P(FU1+.3,-28.2,17.1)],N3(3.3,0,7),K.whiteSh);}
    const fw=WV(-32,-1);
    for(const [u,wd,top] of [[1.2,2.6,13.8],[FM,3.6,14.6],[7.8,2.6,13.8]]){arch(fw,u,wd,0.3,top,K.whiteSh);
      glass(WV(-32,-1,.12),u,wd-.6,6,top-.5);rect(WV(-32,-1,.12),u-wd/2+.4,u+wd/2-.4,0.3,3.7,K.door);}
    rect(WV(-32,-1,.12),FM-.5,FM+.5,4.3,5.7,K.white);rect(fw,FM-.5,FM+.5,18.1,19.1,K.whiteSh);
    box(FM-.2,-30.4,FM+.2,-30,20.2,22.4,K.iron,K.iron);box(FM-.7,-30.4,FM+.7,-30,21.4,21.8,K.iron,K.iron);
    // bell tower (OSM, ~5.6 × 6.3 m, drawn square): white plinth; brick shaft with white corner piers and bands in
    // stages, a pair of slit windows per stage and face; a setback at 15 m; balustrade, white belfry with three
    // arched openings a side, cornice and spire
    {const tu=18.85,tv=-29.1,sq=(h0,h1,a,wall,top)=>box(tu-a,tv-a,tu+a,tv+a,h0,h1,wall,top);
      const faces=(a,o)=>[[[tu-a,tv-a],[tu+a,tv-a],[0,-1]],[[tu+a,tv-a],[tu+a,tv+a],[1,0]],[[tu+a,tv+a],[tu-a,tv+a],[0,1]],[[tu-a,tv+a],[tu-a,tv-a],[-1,0]]].map(([a0,b0,out])=>WL(a0,b0,out,o));
      sq(0.3,3.6,3.25,K.white,K.white);
      for(const [h0,h1,a,st] of [[3.6,15,3,[7.4,11.2]],[15.1,26.2,2.7,[18.8,22.5]]]){sq(h0,h1,a,K.brick,K.brick);
        for(const [x,y] of [[-1,-1],[1,-1],[1,1],[-1,1]])box(tu+x*(a+.08)-(x>0?.9:0),tv+y*(a+.08)-(y>0?.9:0),tu+x*(a+.08)+(x<0?.9:0),tv+y*(a+.08)+(y<0?.9:0),h0,h1,K.white,K.white);
        const bands=[h0,...st,h1];for(const b of st)sq(b-.22,b+.22,a+.1,K.white,K.white);sq(h1-.45,h1,a+.12,K.white,K.white);
        for(const w of faces(a,.06))for(let k=0;k<bands.length-1;k++){const m=(bands[k]+bands[k+1])/2;for(const d of [-.45,.45])rect(w,w.L/2+d-.22,w.L/2+d+.22,m-.3,m+.8,K.bell);}}
      sq(26.2,27.4,3,K.white,K.white);for(const w of faces(3,.06))for(let k=0;k<5;k++){const s=.8+k*(w.L-1.6)/4;rect(w,s-.22,s+.22,26.5,27.05,K.whiteSh);}
      sq(27.4,31.2,2.1,K.white,K.white);for(const w of faces(2.1,.06))for(const d of [-1.15,0,1.15])arch(w,w.L/2+d,.62,28,30.6,K.bell);
      sq(31.2,31.7,2.45,K.white,K.white);pyramid(S,R(tu-2.2,tv-2.2,tu+2.2,tv+2.2),31.7,7.8,K.spire);}
    // the façade's windows glow at night
    for(const u of [1.2,FM,7.8]){const g=G(u,-32.8);GLOW.push(g[0],S.dy+10,g[1]);}
    const c=G(4,-4);MODELS.catedral={x:c[0],y:c[1],h:26};S.dy=0;}
