  // ==== hito: la-victoria ====
  // Monumento La Victoria: the obelisk to the Batallón Cívico de Talca (1904) crowned by the bronze Victory (León
  // Cugnot and Guillaume per the CMN, 1868, made for Lima's Dos de Mayo monument and taken in 1882), back on it since 2011.
  // It stands on the paved island where 1 Oriente splits around the Alameda (OSM w214851537, statue node at the
  // centre), drawn on S. Frame from landmark.py frame la-victoria 214851537: u east, v north. The map's carriageways
  // are wider than the real ones (11 m), so the island is drawn narrower than OSM's 14 m, between them. Elevation
  // from a 2026 photo (File:Monumento al 2 de Mayo.jpg, right half) scaled by a van, ~20 m in all, and the 1898 one
  // (File:Victoriatalca1.jpg): stepped plinth, grey granite dado with white marble plaques on each face (CMN), a stage
  // with arched niches and medallions, a coursed obelisk, a dark capital and the dark bronze winged Victory with arms
  // raised (laurel crown and sword). Approximate: every measure (±1 m), the niches' carving, which way the Victory
  // faces (drawn facing south), the island's paving pattern (satellite: pale paving, no lawn).
  {const F=localFrame(57.4,509.6,90.3*Math.PI/180),{G,Gs,V,N3,R}=F;
    const K={pave:C('#DDD6C6'),pave2:C('#D0C8B6'),curb:C('#C9C3B6'),stone:C('#9E9B93'),stone2:C('#8F8C84'),stoneLt:C('#B3AFA6'),
      marble:C('#F0ECE2'),niche:C('#5E5C57'),bronze:C('#3C4540'),bronze2:C('#2F3632'),iron:C('#3B4240'),lamp:C('#F1E6C4'),
      white:C('#ECE7DC'),glass:C('#3B4653'),glass2:C('#2C3540'),tile:C('#8F8A82'),tile2:C('#8F8A82')};
    const {WL,rect,arch}=facade(S,F,K);
    // the island between the carriageways as the map draws them (west edge u=-3.6, east 4.9; the Alameda's lanes
    // at v -23 and +25); its north end narrows where the two branches of 1 Oriente meet
    const isl=[[-3.6,-20.6],[-2.1,-22.1],[3.4,-22.1],[4.9,-20.6],[4.9,12.5],[1.6,17.5],[-0.6,17.5],[-3.6,14]];
    const fp=Gs(isl);occMark(fp);
    S.dy=padAt(Math.min(...fp.map(p=>p[0])),Math.min(...fp.map(p=>p[1])),Math.max(...fp.map(p=>p[0])),Math.max(...fp.map(p=>p[1])));
    // curb and paving in bands of two tones across the island
    S.prism(fp,0.3,0.42,K.curb,K.curb);
    S.flat(Gs([[-3.2,-20.4],[-1.9,-21.7],[3.2,-21.7],[4.5,-20.4],[4.5,12.4],[1.4,17.1],[-.4,17.1],[-3.2,13.9]]),0.45,K.pave);
    for(let v=-19.5;v<8;v+=5)S.quadXY(R(-3.2,v,4.5,v+2.5),0.48,K.pave2);
    // two lamps on the island (photos), like the Alameda's, lit at night
    for(const v of [-15,11]){const g=G(.6,v);S.prism(rotRect(g[0],g[1],.3,.3),0.45,4.6,K.iron,K.iron);S.prism(rotRect(g[0],g[1],.9,.9),4.6,5,K.iron,K.lamp);GLOW.push(g[0],S.dy+4.8,g[1]);}
    // the monument, centred on the OSM statue node
    const mu=-0.2,mv=-0.8,sq=(a,h0,h1,wall,top)=>S.prism(R(mu-a,mv-a,mu+a,mv+a),h0,h1,wall,top);
    const faces=(a,o)=>[[[mu-a,mv-a],[mu+a,mv-a],[0,-1]],[[mu+a,mv-a],[mu+a,mv+a],[1,0]],[[mu+a,mv+a],[mu-a,mv+a],[0,1]],[[mu-a,mv+a],[mu-a,mv-a],[-1,0]]].map(([a0,b0,out])=>WL(a0,b0,out,o));
    // stepped plinth: three treads in two tones
    sq(2.9,0.3,0.75,K.stoneLt,K.stoneLt);sq(2.55,0.75,1.05,K.stone,K.stone2);sq(2.2,1.05,1.35,K.stoneLt,K.stoneLt);
    // dado with a white marble plaque on each face, a moulded cap
    sq(1.9,1.35,3.6,K.stone,K.stone);for(const w of faces(1.9,.06)){rect(w,w.L/2-1,w.L/2+1,1.95,3.15,K.marble);rect(w,0,w.L,1.35,1.7,K.stone2);}
    sq(2.1,3.6,3.95,K.stoneLt,K.stoneLt);sq(1.75,3.95,4.3,K.stone2,K.stone2);
    // stage with an arched niche and a white medallion on each face, corner piers, cornice
    sq(1.35,4.3,7,K.stone,K.stone);
    for(const w of faces(1.35,.06))arch(w,w.L/2,1.3,4.6,6.7,K.niche);
    for(const w of faces(1.35,.12))rect(w,w.L/2-.35,w.L/2+.35,5.3,6.1,K.marble);
    sq(1.6,7,7.35,K.stoneLt,K.stoneLt);sq(1.25,7.35,7.7,K.stone2,K.stone2);
    // coursed obelisk: stepped courses in two tones, narrowing upward
    for(let k=0;k<7;k++){const h0=7.7+k*1.1,a=.95-k*.06;sq(a,h0,h0+1.1,k%2?K.stone2:K.stone,K.stone);}
    // dark capital (flared), a round base and the Victory
    sq(.75,15.4,15.75,K.bronze2,K.bronze2);sq(.6,15.75,16.2,K.bronze,K.bronze);sq(.95,16.2,16.6,K.bronze2,K.bronze);
    S.prism(Gs(ngon(mu,mv,.45,8)),16.6,17.1,K.bronze,K.bronze);
    // the Victory: robe in stepped tiers, torso, head; both arms raised (sword and laurel crown) and wings spread
    // behind her, facing south (-v)
    const fig=(u0,v0,u1,v1,h0,h1,c)=>S.prism(R(mu+u0,mv+v0,mu+u1,mv+v1),h0,h1,c,c);
    fig(-.55,-.5,.55,.5,17.1,18.1,K.bronze);fig(-.45,-.4,.45,.4,18.1,19.2,K.bronze2);fig(-.35,-.3,.35,.3,19.2,20.1,K.bronze);
    fig(-.2,-.25,.2,.15,20.1,20.6,K.bronze);
    fig(-.6,-.2,-.35,.05,19.6,21.3,K.bronze2);fig(.35,-.2,.6,.05,19.6,21.1,K.bronze2);
    fig(-.55,-.15,-.4,0,21.3,22.3,K.bronze); // sword
    fig(.25,-.2,.95,.05,21.1,21.35,K.bronze);fig(.25,-.2,.95,.05,21.75,22,K.bronze);fig(.25,-.2,.45,.05,21.35,21.75,K.bronze);fig(.75,-.2,.95,.05,21.35,21.75,K.bronze); // crown
    for(const sg of [-1,1]){const P=(u,h)=>V(mu+u*sg,mv+.35,h),Q=(u,h)=>V(mu+u*sg,mv+.2,h);
      const w=[[.3,19.4],[1.6,20.6],[1.9,22.2],[.5,20.4]];
      S.face(w.map(p=>P(...p)),N3(0,1),K.bronze2);S.face(w.map(p=>Q(...p)),N3(0,-1),K.bronze);}
    const c=G(mu,mv);MODELS['la-victoria']={x:c[0],y:c[1],h:23};S.dy=0;}
