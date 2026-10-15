  // ==== hito: hospital-regional ====
  // Hospital Regional de Talca: the new hospital (in use in stages from 2013, fully open 2017; 85 000 m², seismic
  // isolation) on the block between 13 and 14 Oriente, 1 and 2 Norte; drawn on S. Plan from OpenStreetMap: the
  // site r/w618536526, the main building w8550475/w618536195 (a nine-storey tower along 1 Norte over a two-storey
  // podium with two light wells and a patio), the older three-storey block to the north w618536206 (yellow roof with
  // solar panels, drawn in rows), the low blocks on the west (w618536201, w618536203) and the small ones w618536209, w618536211,
  // w618536213. Frame localFrame(1770, 150, 90°): u = grid x (east), v = grid y (north); the tower is not split from
  // the podium in OSM, so its depth (27 m) comes from the Esri imagery, which also shows the podium's green roofs, a
  // pergola grid over its west half and the raised helipad (the emergency unit's, Minsal 2013). Elevation from photos
  // on Wikimedia Commons (2014, 2015): white, horizontal sunshades on every floor, dark glazing, the end walls framed
  // by nested chamfered white ribs, a red volume at street level. Approximate: heights (nine storeys, ~38 m; podium
  // ~10 m), the end walls' lattice (drawn as a window grid), the north and west blocks' elevations (a 2005 photo of the
  // yellow annex), the green roof's paths. Night: a few lit windows on the tower (the hospital works around the clock).
  {const F=localFrame(1770,150,Math.PI/2),{G,Gs,V,N3,R}=F;
    const K={white:C('#EEEDE8'),white2:C('#DADAD4'),roof:C('#C9C9C4'),glass:C('#4D5D66'),glass2:C('#3B4653'),red:C('#B4372C'),
      green:C('#7E9B5A'),green2:C('#8FA85A'),path:C('#E3E0D6'),padc:C('#B9B8B2'),yellow:C('#D3AE5E'),yroof:C('#BCA562'),roof2:C('#B5B8AE'),solar:C('#3E4A5C'),
      orange:C('#C8693E'),grey:C('#E3E1DA'),groof:C('#B9BCBC'),tile:C('#C9C9C4'),tile2:C('#B9B9B4')};
    const {box,WL,WV,WU,rect}=facade(S,F,K);
    const quad=(w,pts,col)=>S.face(pts.map(([s,h])=>w.q(s,h)),w.n,col);
    // a (u,v) polygon (any orientation, may be concave) as walls h0..h1 and a flat roof; returns the walls (WL) so
    // they can take window bands
    const extrude=(q,h0,h1,wall,top)=>{let A=0;q.forEach((p,i)=>{const r=q[(i+1)%q.length];A+=p[0]*r[1]-r[0]*p[1];});const sg=A>0?1:-1,ws=[];
      q.forEach((a,i)=>{const b=q[(i+1)%q.length],du=b[0]-a[0],dv=b[1]-a[1],L=Math.hypot(du,dv);if(L<.01)return;const out=[sg*dv/L,-sg*du/L],y0=h0<=0.31?h0-4:h0;
        S.face([V(a[0],a[1],y0),V(b[0],b[1],y0),V(b[0],b[1],h1),V(a[0],a[1],h1)],N3(out[0],out[1]),wall);ws.push(WL(a,b,out));});
      S.flat(Gs(q),h1,top);return ws;};
    const bands=(ws,hs,col)=>{for(const w of ws)if(w.L>3)for(const [h0,h1] of hs)rect(w,.6,w.L-.6,h0,h1,col);};
    const site=Gs([[108,95],[113,88],[113,23],[107,22],[107,-106],[102,-112],[-99,-109],[-106,-98],[-113,65],[-102,83],[-81,93],[-46,101],[-12,109],[25,116],[70,113],[91,105]]);
    NOLOTS.push(site);
    const main=R(-75,-88,96,2);occMark(main);const pad=padAt(G(-75,0)[0],G(0,-88)[1],G(96,0)[0],G(0,101)[1]);S.dy=pad;
    // podium: two storeys around two light wells and a patio against the tower; green roofs with paths, a white
    // pergola grid over the west half
    const PH=10;
    for(const [u0,v0,u1,v1] of [[-75,-60,-48,2],[-48,-60,-34,-41],[-48,-17,-34,2],[-34,-60,-7,2],[-7,-60,7,-40],[-7,-17,7,2],[7,-60,40,2],[40,-41,71,2],[71,-60,96,2]])
      box(u0,v0,u1,v1,0.3,PH,K.white,u1<=-7?K.roof2:K.green);
    for(const [w,s0,s1] of [[WU(-75,-1),-60,2],[WU(96,1),-60,2],[WV(2,1),-75,96],[WU(-48,1),-41,-17],[WU(-34,-1),-41,-17],[WV(-41,1),-48,-34],[WV(-17,-1),-48,-34],
      [WU(-7,1),-40,-17],[WU(7,-1),-40,-17],[WV(-40,1),-7,7],[WV(-17,-1),-7,7],[WU(40,1),-60,-41],[WU(71,-1),-60,-41],[WV(-41,-1),40,71]])
      for(const [h0,h1] of [[1.6,3.8],[6,8.2]])rect(w,s0+.6,s1-.6,h0,h1,h0<3?K.glass2:K.glass);
    for(const [w,s0,s1] of [[WU(-75,-1,.09),-60,2],[WU(96,1,.09),-60,2],[WV(2,1,.09),-75,96]])for(const h of [4.6,9.4])rect(w,s0,s1,h,h+.6,K.white2);
    for(let u=-72;u<-8;u+=9)S.quadXY(R(u,-58,u+.6,0),PH+.04,K.path);for(let v=-56;v<0;v+=9)S.quadXY(R(-74,v,-8,v+.6),PH+.05,K.path);
    for(const [a,b] of [[[42,-39],[60,-20]],[[60,-20],[48,-2]],[[72,-58],[94,-30]],[[94,-30],[76,-2]],[[8,-58],[30,-36]]]){
      const du=b[0]-a[0],dv=b[1]-a[1],L=Math.hypot(du,dv),nu=-dv/L*.35,nv=du/L*.35;
      S.face([V(a[0]-nu,a[1]-nv,PH+.04),V(b[0]-nu,b[1]-nv,PH+.04),V(b[0]+nu,b[1]+nv,PH+.04),V(a[0]+nu,a[1]+nv,PH+.04)],[0,1,0],K.path);}
    for(const [u0,v0,u1,v1] of [[8,-58,40,-36],[72,-58,95,-31],[41,-39,70,-21]])S.quadXY(R(u0,v0,u1,v1),PH+.02,K.green2);
    // raised block of the emergency unit with the helipad: grey deck, white disc, red cross
    box(16,-33,38,-9,PH,15.6,K.white,K.padc);for(const [h0,h1] of [[11.4,13.8]])rect(WV(-33,-1),16.6,37.4,h0,h1,K.glass);
    {const o=ngon(0,0,6.5,16).map(([a,b])=>G(27+a,-21+b));S.flat(o,15.64,K.white);
      S.quadXY(R(22.5,-22,31.5,-20),15.68,K.red);S.quadXY(R(26,-25.5,28,-16.5),15.69,K.red);}
    // the tower: nine storeys, a sunshade at every floor over a dark band of glass, white fins every 9 m, a glazed
    // ground floor with a red volume; end walls framed by three nested chamfered white ribs; plant room on the roof
    const T0=-50,T1=94,TV0=-87,TV1=-60,TH=38;
    box(T0,TV0,T1,TV1,0.3,TH,K.white,K.roof);box(-30,-80,74,-67,TH,41,K.white,K.roof);
    for(const [v,sg] of [[TV0,-1],[TV1,1]]){const w=WV(v,sg),wb=WV(v,sg,.09),wp=WV(v,sg,.12);
      if(sg<0){rect(w,T0+1,T1-1,0.3,5,K.glass2);rect(wp,78,90,0.3,6,K.red);}
      for(let h=5.5;h<TH-1;h+=4){rect(w,T0+.6,T1-.6,h+1.3,h+3.1,(h-5.5)%8?K.glass:K.glass2);rect(wb,T0,T1,h,h+.8,K.white);}
      rect(wb,T0,T1,TH-.6,TH,K.white);for(let u=T0;u<=T1+1e-6;u+=9)rect(wp,Math.max(T0,u-.35),Math.min(T1,u+.35),sg<0?0.3:PH,TH,K.white);}
    for(const [u,sg] of [[T0,-1],[T1,1]]){const w=WL([u,TV0],[u,TV1],[sg,0]),L=TV1-TV0;
      // s runs along the wall from its south corner: a shaded field with a window grid, then the ribs, 1.2 m deep
      rect(WL([u,TV0],[u,TV1],[sg,0],.03),0,L,0.3,TH,K.white2);
      for(let h=5.5;h<TH-2;h+=4)for(let x=2.5;x<25;x+=3)rect(w,x-.7,x+.7,h+1,h+3,((x+h)|0)%2?K.glass:K.glass2);
      const P=(x,h,o)=>V(u+sg*o,TV0+x,h),rib=pts=>{S.face(pts.map(([x,h])=>P(x,h,1.2)),N3(sg,0),K.white);
        pts.forEach((p,i)=>{const q=pts[(i+1)%pts.length],ns=q[1]-p[1],nh=-(q[0]-p[0]),l=Math.hypot(ns,nh),d=N3(0,ns/l);
          S.face([P(...p,.02),P(...q,.02),P(...q,1.2),P(...p,1.2)],[d[0],nh/l,d[2]],ns/l>.5?K.white2:K.white);});};
      for(const [i,top,ch] of [[0,36.5,7],[3.6,31,5.5],[7.2,25.5,3.8]]){const L0=1+i,L1=26-i,rw=1.1;
        rib([[L0,0.3],[L0+rw,0.3],[L0+rw,top-ch],[L0,top-ch]]);rib([[L1-rw,0.3],[L1,0.3],[L1,top-ch],[L1-rw,top-ch]]);
        rib([[L0,top-ch],[L0+rw,top-ch],[L0+ch+rw,top-rw],[L0+ch,top]]);rib([[L1-rw,top-ch],[L1,top-ch],[L1-ch,top],[L1-ch-rw,top-rw]]);
        rib([[L0+ch,top-rw],[L1-ch,top-rw],[L1-ch,top],[L0+ch,top]]);}}
    for(let u=T0+8;u<T1-4;u+=18)for(const h of [13.5,21.5,29.5])for(const [v,o] of [[TV0,-1.2],[TV1,1.2]]){const g=G(u+(h%16),v+o);GLOW.push(g[0],S.dy+h+2,g[1]);}
    // the north block (yellow walls, an orange stripe, window bands, yellow roof) and the low ones around
    {S.dy=pad;const q=[[-8,96],[31,95],[31,101],[52,101],[52,95],[72,95],[72,82],[82,82],[82,69],[72,69],[72,53],[81,53],[81,29],[27,28],[27,45],[23,45],[23,1],[17,1],[16,23],[16,45],[-8,46]];
      occMark(Gs(q));const ws=extrude(q,0.3,12.4,K.yellow,K.yroof);bands(ws,[[1.6,3.2],[5.6,7.2],[9.6,11.2]],K.glass);
      for(const [u0,u1] of [[-4,20],[30,68]])for(let v=50;v<92;v+=4.5)S.quadXY(R(u0,v,u1,v+2.2),12.44,K.solar);
      for(const w of ws)if(w.L>3)rect(w,.3,w.L-.3,4.2,4.8,K.orange);}
    for(const [q,h] of [[[[-107,-5],[-106,-16],[-104,-22],[-90,-22],[-87,-1],[-84,-1],[-85,32],[-81,32],[-81,42],[-85,42],[-85,54],[-108,54]],8.2],
      [[[-100,-27],[-95,-27],[-95,-31],[-83,-31],[-80,-73],[-93,-73],[-93,-78],[-97,-78]],8.2],[[[7,22],[16,23],[17,2],[10,2],[10,5],[7,5]],5],
      [[[37,13],[30,13],[30,17],[23,17],[23,7],[37,7]],5],[[[77,108],[94,99],[93,96],[97,95],[92,86],[70,98],[67,95],[63,97],[68,106],[74,104]],7.6]]){
      const g=Gs(q);occMark(g);S.dy=groundMin(g)-.3;const ws=extrude(q,0.3,h,K.grey,K.groof);bands(ws,h>6?[[1.4,3.2],[5,6.8]]:[[1.4,3.4]],K.glass);}
    const c=G(10,-40);MODELS['hospital-regional']={x:c[0],y:c[1],h:44};S.dy=0;}
