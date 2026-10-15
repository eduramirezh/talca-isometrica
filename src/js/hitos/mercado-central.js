  // ==== hito: mercado-central ====
  // Mercado Central (1890, Monumento Histórico 1998), the whole block between 4 and 5 Oriente, 1 Sur and 1 Norte;
  // drawn on S. Plan from OpenStreetMap: the perimeter range w114237042 (west, south and east wings, 13 m deep, with
  // chamfered corners on 1 Sur and the passage from 1 Sur to the hall), the central hall w110971686, the north shed
  // w798984630 on 1 Norte and the corner shops w975735413/w975735414. Frame localFrame(502, -16, 90°): u = grid x
  // (east), v = grid y (north). Since the 2010 earthquake and the fires of 2014 it is closed, fenced and roofed with
  // rusty iron; a restoration is planned (GORE/SUBDERE, archaeological survey in 2026). Elevations from photos on
  // Wikimedia Commons (2017, 2018, the 1 Sur front and a pavilion on Oriente) and the restoration project's render:
  // white stucco range with a cornice, pilasters, shop fronts and mezzanine windows; entrance pavilions with a big
  // arch closed by an iron grille between two smaller arches; corner pavilions on 1 Sur. Roofs from the Esri
  // imagery (undated): rusty iron on the range, a light shed roof on the north, and a hall in three bays, each a
  // lantern and a curved slope. The north wall carries a mural (photo, 2015), drawn as colour blocks. Approximate:
  // all heights (no measured elevation), the hall's walls and its roof's current state (fire damage unknown), the
  // Oriente pavilions' position and the inner courtyard. No night lights: the building is closed.
  {const F=localFrame(502,-16,Math.PI/2),{G,Gs,V,N3,R}=F;
    const K={wall:C('#DCD5C6'),wallIn:C('#CBC4B5'),white:C('#EFEAE0'),whiteSh:C('#D3CDC0'),plinth:C('#BDB6A8'),
      tile:C('#8A5E48'),tile2:C('#79523F'),gable:C('#DCD5C6'),flat:C('#8F8A82'),shed:C('#C9C9C1'),shed2:C('#B5B7B0'),
      hall:C('#CFC8BA'),lantern:C('#DCD6BF'),slope:C('#AEB5A6'),slope2:C('#9DA597'),glass:C('#3B4653'),glass2:C('#2C3540'),
      shutter:C('#5E5A55'),door:C('#5A4636'),iron:C('#3A3A3A'),yard:C('#BDB197'),
      mural:['#C8553D','#E2B33C','#4F8A8B','#7A9A3B','#B4372C','#3E6D9C','#E9DDC6','#D9822B'].map(C)};
    const {box,WL,WV,WU,rect,arch,roof}=facade(S,F,K),shedRoof=facade(S,F,{...K,tile:K.shed,tile2:K.shed2}).roof;
    const fp=Gs([[-54,-40],[-49,-44],[51,-44],[54,-41],[54,62],[-54,62]]);
    occMark(fp);S.dy=padAt(G(-54,0)[0],G(0,-44)[1],G(54,0)[0],G(0,62)[1]);
    // edges of a convex (u,v) polygon as walls facing out, details o metres in front
    const edges=(q,o)=>{let cu=0,cv=0;q.forEach(p=>{cu+=p[0]/q.length;cv+=p[1]/q.length;});
      return q.map((a,i)=>{const b=q[(i+1)%q.length],du=b[0]-a[0],dv=b[1]-a[1],L=Math.hypot(du,dv);let out=[dv/L,-du/L];
        if(out[0]*((a[0]+b[0])/2-cu)+out[1]*((a[1]+b[1])/2-cv)<0)out=[-out[0],-out[1]];return WL(a,b,out,o);});};
    const H=7.4,PH=8.4; // eaves of the range and top of its street parapet
    // courtyard (rubble and gravel since the market closed)
    S.flat(Gs([[-41,-31],[41,-31],[41,40],[-41,40]]),0.3,K.yard);
    // the range: south wing with the chamfered corners, west and east wings, north shed; rusty iron roofs behind a
    // white parapet on the street side
    S.prism(Gs([[-54,-40],[-49,-44],[49,-44],[54,-40],[54,-31],[-54,-31]]),0.3,H,K.wall,K.wall,false);
    box(-54,-31,-41,62,0.3,H,K.wall,K.wall,false);box(41,-31,54,62,0.3,H,K.wall,K.wall,false);
    box(-41,40,41,62,0.3,6.2,K.wall,K.wall,false);
    roof('v',-34,62,-53.4,-41,H,2,6,[0,1]);roof('v',-34,62,41,53.4,H,2,6,[0,1]);roof('u',-47.5,47.5,-43.4,-31,H,2,6,[0,0]);
    shedRoof('u',-47.5,47.5,40,61.4,6.2,2.4,8,[0,0]);
    box(-45,-44,45,-43.6,H-.2,PH,K.wall,K.white);box(-54,-35,-53.6,62,H-.2,PH,K.wall,K.white);box(53.6,-35,54,62,H-.2,PH,K.wall,K.white);
    // street fronts in bays: white pilasters, plinth, shop fronts (shuttered), a band, mezzanine windows, cornice
    const front=(a,b,out,skip)=>{const w=WL(a,b,out),wb=WL(a,b,out,.09),wp=WL(a,b,out,.12),n=Math.round(w.L/4.5),bw=w.L/n;
      rect(w,0,w.L,0.3,0.9,K.plinth);rect(wb,0,w.L,3.8,4.15,K.white);rect(wb,0,w.L,6.7,7.2,K.white);rect(wb,0,w.L,PH-.35,PH,K.white);
      for(let k=0;k<=n;k++)rect(wp,Math.max(0,k*bw-.3),Math.min(w.L,k*bw+.3),0.3,PH-.35,K.white);
      for(let k=0;k<n;k++){const c=(k+.5)*bw;if(skip&&c>skip[0]&&c<skip[1])continue;
        rect(w,c-1.5,c+1.5,0.9,3.5,K.shutter);rect(w,c-1.05,c+1.05,4.5,6.3,k%2?K.glass2:K.glass);}};
    front([-44,-44],[44,-44],[0,-1],[34,54]);front([-54,62],[-54,-35],[-1,0],[44,64]);front([54,-35],[54,62],[1,0],[33,53]);
    // entrance pavilions: a block above the range with a big arch closed by an iron grille between two smaller
    // arches, white pilasters, cornice and a stepped attic; the 1 Sur one opens the passage to the hall
    const pav=(a,b,out)=>{const L=Math.hypot(b[0]-a[0],b[1]-a[1]),du=(b[0]-a[0])/L,dv=(b[1]-a[1])/L,bk=[-out[0]*13,-out[1]*13];
      const q=[a,b,[b[0]+bk[0],b[1]+bk[1]],[a[0]+bk[0],a[1]+bk[1]]];
      box(Math.min(...q.map(p=>p[0])),Math.min(...q.map(p=>p[1])),Math.max(...q.map(p=>p[0])),Math.max(...q.map(p=>p[1])),0.3,10.6,K.wall,K.flat);
      const w=WL(a,b,out),wb=WL(a,b,out,.09),wp=WL(a,b,out,.12),m=L/2;
      rect(w,0,L,0.3,0.9,K.plinth);rect(wb,0,L,9.3,9.8,K.white);rect(wb,0,L,10.25,10.6,K.white);
      for(const s of [0,L-1])rect(wp,s,s+1,0.3,10.25,K.white);
      arch(w,m,6,0.9,9.3,K.white);arch(wp,m,4.8,0.9,8.7,K.iron);
      for(const d of [-4.6,4.6]){arch(w,m+d,2.8,0.9,7.2,K.white);arch(wp,m+d,2,0.9,6.8,K.glass);}
      const c=[a[0]+du*m,a[1]+dv*m],t=[du,dv];
      for(const [hw,h0,h1] of [[3.6,10.6,11.4],[2,11.4,12.2]]){const p0=[c[0]-t[0]*hw,c[1]-t[1]*hw],p1=[c[0]+t[0]*hw,c[1]+t[1]*hw],k=[-out[0]*.8,-out[1]*.8];
        const qq=[p0,p1,[p1[0]+k[0],p1[1]+k[1]],[p0[0]+k[0],p0[1]+k[1]]];
        box(Math.min(...qq.map(p=>p[0])),Math.min(...qq.map(p=>p[1])),Math.max(...qq.map(p=>p[0])),Math.max(...qq.map(p=>p[1])),h0,h1,K.white,K.white);}};
    pav([-8,-45],[7,-45],[0,-1]);pav([-55,15.5],[-55,0.5],[-1,0]);pav([55,0.5],[55,15.5],[1,0]);
    // corner pavilions on 1 Sur: chamfered, a door under an arch on the chamfer, arched windows on the streets
    for(const sg of [-1,1]){const q=[[-54,-40],[-49,-44],[-44,-44],[-44,-35],[-54,-35]].map(p=>[p[0]*sg,p[1]]);if(sg>0)q.reverse();
      S.prism(Gs(q),0.3,10.2,K.wall,K.flat);
      const ew=edges(q,.06),eb=edges(q,.09),ep=edges(q,.12);
      for(let i=0;i<q.length;i++){const w=ew[i],a=q[i],b=q[(i+1)%q.length];
        if(Math.abs(a[0])===44&&Math.abs(b[0])===44||a[1]===-35&&b[1]===-35)continue; // the inner sides
        rect(w,0,w.L,0.3,0.9,K.plinth);rect(eb[i],0,w.L,8.9,9.4,K.white);rect(eb[i],0,w.L,9.85,10.2,K.white);
        if(a[0]!==b[0]&&a[1]!==b[1]){arch(w,w.L/2,3.6,0.9,7.6,K.white);arch(ep[i],w.L/2,2.6,0.9,7.1,K.door);}
        else{arch(w,w.L/2,2.6,0.9,7.2,K.white);arch(ep[i],w.L/2,1.8,1.2,6.8,K.glass);}}}
    // inner faces on the courtyard: plain, with doors
    for(const [w,s0,s1] of [[WV(-31,1),-41,41],[WU(-41,1),-31,40],[WU(41,-1),-31,40],[WV(40,-1),-41,41]])
      for(let s=s0+4;s<s1-2;s+=8)rect(w,s-1,s+1,0.3,3,K.door);
    // passage from 1 Sur to the hall
    box(-4,-31,3,-16.5,0.3,6,K.wallIn,K.flat);
    // the hall: plain walls with a row of arched windows and a cornice, three roof bays from south to north, each a
    // curved slope (three facets in two tones) up to a flat lantern with a skylight strip and a clerestory facing north
    box(-26,-16.5,27,32.5,0.3,10,K.hall,K.hall,false);
    for(const [w,s0,s1] of [[WV(-16.5,-1),-26,27],[WV(32.5,1),-26,27],[WU(-26,-1),-16.5,32.5],[WU(27,1),-16.5,32.5]]){
      rect(w,s0,s1,0.3,1,K.plinth);for(let s=s0+3;s<s1-2;s+=4.2)arch(w,s,1.4,5.2,8.6,K.glass);}
    for(const [w,s0,s1] of [[WV(-16.5,-1,.09),-26,27],[WV(32.5,1,.09),-26,27],[WU(-26,-1,.09),-16.5,32.5],[WU(27,1,.09),-16.5,32.5]])rect(w,s0,s1,9.4,10,K.white);
    {const L=49/3;for(let k=0;k<3;k++){const va=-16.5+k*L,vb=va+L,pr=[[va,10],[va+4,11.6],[va+8,12.8],[vb-4,13.6],[vb,13.6]];
      for(let i=0;i<3;i++){const [v0,h0]=pr[i],[v1,h1]=pr[i+1];S.face([V(-26.3,v0,h0),V(27.3,v0,h0),V(27.3,v1,h1),V(-26.3,v1,h1)],N3(0,-(h1-h0),v1-v0),i%2?K.slope2:K.slope);}
      S.face([V(-26.3,vb-4,13.6),V(27.3,vb-4,13.6),V(27.3,vb,13.6),V(-26.3,vb,13.6)],[0,1,0],K.lantern);
      for(let u=-24;u<26;u+=6)S.face([V(u,vb-3.6,13.63),V(u+3.6,vb-3.6,13.63),V(u+3.6,vb-2.6,13.63),V(u,vb-2.6,13.63)],[0,1,0],K.glass);
      const cw=WV(vb,1,.02);rect(cw,-26.3,27.3,10,13.6,K.wallIn);for(let u=-25;u<26;u+=2.5)rect(WV(vb,1,.06),u,u+1.6,10.6,13,K.glass);
      for(const [u,sg] of [[-26.3,-1],[27.3,1]])S.face(pr.concat([[vb,10]]).map(([v,h])=>V(u,v,h)),N3(sg,0),K.hall);}}
    // the mural on the 1 Norte wall, in blocks of colour; plain corner shops at both ends
    {const w=WV(62,1),wb=WV(62,1,.09);let s=-40,k=0;const ws=[5,3,6,4,7,3,5,4];
      while(s<40){const e=Math.min(40,s+ws[k%8]);rect(w,s,e,0.9,3.2,K.mural[k%8]);rect(w,s,e,3.2,5.4,K.mural[(k*3+5)%8]);s=e;k++;}
      rect(w,-41,41,0.3,0.9,K.plinth);rect(wb,-41,41,5.8,6.2,K.white);
      for(const [a,b] of [[-54,-41],[41,54]]){rect(w,a,b,0.3,0.9,K.plinth);for(let u=a+2.2;u<b-1;u+=4.3){rect(w,u-1.4,u+1.4,0.9,3.5,K.shutter);rect(w,u-1,u+1,4.5,6.3,K.glass);}}}
    const c=G(0,8);MODELS['mercado-central']={x:c[0],y:c[1],h:16};S.dy=0;}
