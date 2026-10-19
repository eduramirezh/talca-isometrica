  // ==== hito: casino-dreams ====
  // Casino Dreams Talca («Parque Ferial del Maule»), on the old FITAL fairground (Feria Internacional de Talca, held here
  // from 1947 by the Asociación Gremial Agrícola Central), on S (unlisted windows: timber slats and glass are drawn).
  // Under construction since August 2025, opening announced for November 2026. The lot is OpenStreetMap's
  // (w595485838, landuse=construction «Casino Dreams Talca»; 8.8 ha). The layout is figure 1 of SMA Res. Ex. 2367/2025
  // (from the SEA's consulta de pertinencia PERTI-2025-2627), georeferenced by its UTM 19S ticks: the «área modificada»
  // is a circle of r ≈ 122 m centred at (−1051, 744), cut flat on the north (v ≤ 58), with three arms (5 Norte to the
  // north, Circunvalación to the east, the Alameda at 4 Norte 99 to the south); the «nuevas construcciones», a box to the
  // west and a round lobe to the south-east. Sentinel-2 of 2026-10-11 (tools/sentinel.py caja) shows the circle cleared
  // and the dark roof in its middle. The rest follows Dreams' published views (Meganoticias, 2025-06-18): a long box
  // with a glazed ground floor and an upper band of vertical timber slats, a drum of three stacked rings, parking in
  // concentric arcs with tree islands, a pedestrian axis from the west with palms, a water channel along the façade,
  // a plaza with fountains and a pergola, farm machinery on a lawn (the fair's heritage). Figures from the SMA: one
  // building of two floors (plus a basement), 7,655 m² built, 45,000 m² intervened, 373 parking spaces; the press:
  // timber, raised on 1.7 m piles because the lot is in the PRC's flood zones R-3B and R-2. Approximate: every height,
  // the drum's tiers, the box's proportions, the fountains', pergola's, amphitheater's and display's places (the
  // programme lists an amphitheater; its place is a guess), the number of cars, the trees outside the circle (from the
  // Esri imagery of 2020, before the works). Frame: origin at the circle's centre, u east and v north (A = 90°).
  {const X=-1051,Y=744,F=localFrame(X,Y,Math.PI/2),{G,Gs,V,N3}=F; // G(u,v) = [X + u, Y + v]
    const K={meadow:C('#AEAA6C'),lawn:C('#8FA552'),lawn2:C('#869B4C'),pave:C('#D6CDB8'),pave2:C('#C9BFA8'),asph:C('#5E5B57'),
      bay:C('#67645D'),bay2:C('#5A5752'),line:C('#E9E4D6'),gravel:C('#D8C69C'),water:C('#4F86A8'),rim:C('#E6E1D4'),jet:C('#DCEEF4'),
      wood:C('#A5673F'),wood2:C('#8B5333'),wood3:C('#C08552'),deck:C('#9A7A5C'),slab:C('#C9C3B6'),dark:C('#2E2B28'),
      glass:C('#4D5D66'),glass2:C('#3B4653'),roof:C('#4E4F52'),roof2:C('#5D5E61'),hvac:C('#A9ABAD'),sign:C('#F3E3B8'),
      iron:C('#4A4C4F'),lamp:C('#FFF4C8'),seat:C('#C4BEB0'),seat2:C('#B3AD9F'),stage:C('#8B5333'),wheel:C('#2A2A2A'),
      car:['#E8E8E4','#E8E8E4','#E8E8E4','#BBBFC0','#BBBFC0','#3A3D42','#3A3D42','#A8453D','#4F6D8C'].map(C),carGl:C('#2C3540'),
      tractor:[C('#3F7D3A'),C('#B23A2E'),C('#3F7D3A'),C('#D9A532')],cab:C('#3B4653')};
    // the lot (w595485838), in grid metres
    const LOT=[[-1195,891],[-1297,680],[-1317,639],[-1192,624],[-1049,601],[-1031,596],[-990,590],[-989,556],[-941,557],[-935,601],[-928,661],[-913,715],[-874,819]];
    // what is reserved: the lot out to the map's 5 Norte and the west carriageway of Circunvalación, which run 10–20 m
    // outside its fence (the strips hold trees, not the houses cityGen would put there)
    const RES=[[-1204,906],[-1297,680],[-1317,639],[-1192,624],[-1049,601],[-1031,596],[-990,590],[-989,556],[-927,548],[-919,634],[-915,666],[-911,681],[-858,803],[-860,824],[-874,829],[-905,844]];
    const RO=122,VMAX=58,D2R=Math.PI/180,P=(r,t)=>[r*Math.cos(t),r*Math.sin(t)],rr=rng(5381);
    const NCLIP=[[-400,-400],[400,-400],[400,VMAX],[-400,VMAX]],cut=q=>clipTo(q,NCLIP);
    // the building: a box (u −28…40, v −30…30, the deck's edge) and a drum (centre DC, radius DR), the deck 1.7 m over the ground
    const BX=[-28,-30,40,30],DC=[63,-28],DR=33,DK=1.7,AM=[96,-76]; // AM: the amphitheater's centre
    const rect=(u0,v0,u1,v1)=>[[u0,v0],[u1,v0],[u1,v1],[u0,v1]];
    // roads (u, v): from the Alameda (4 Norte 99), to Circunvalación, to 5 Norte; the drive along the north edge
    const SROAD=[[86,-192],[84,-139],[50,-89]],EROAD=[[95,30],[152,8]],NROAD=[[-3,52],[-3,117]],NDRIVE=[[-90,50],[0,50]];
    const DISPLAY=rect(-160,20,-125,75); // the farm machinery's lawn
    // reserve the whole lot: no generated houses or trees inside it; the map's tracks in it are this landmark's
    occFill(RES,2.5);
    streets.forEach(s=>{if(s.c===7&&s.pts.filter(p=>pip(p,RES)).length*2>=s.pts.length)s.bridge=true;});
    const inAxis=(u,v)=>u<-30&&Math.abs(v)<9.5,inDrive=(u,v)=>u>-95&&u<4&&Math.abs(v-50)<6.5,
      nearRoad=(u,v,d)=>[SROAD,EROAD,NROAD,NDRIVE].some(p=>{for(let i=0;i+1<p.length;i++)if(segDist2(u,v,...p[i],...p[i+1])<d*d)return true;return false;}),
      free=(u,v)=>!inAxis(u,v)&&!nearRoad(u,v,7.5); // a lawn's or a bay's piece that leaves the axis and the roads alone
    const keepEH=EH.slice();applyPads(); // draw on the final terrain (the Estadio's pad reaches Circunvalación), undone below
    // ---- the ground, draped on the terrain
    {const Lg=new GB(1<<16),lay=(q,o,c)=>{if(q.length>2)Lg.flat(q,o,c);};
      lay(RES,.11,K.meadow);
      // a band of the circle [r0, r1] × [t0, t1] in pieces of about `step` metres of arc, clipped to the north edge
      const band=(r0,r1,t0,t1,step,o,col,skip)=>{const rm=(r0+r1)/2,n=Math.max(1,Math.round((t1-t0)*rm/step));
        for(let i=0;i<n;i++){const a=t0+(t1-t0)*i/n,b=t0+(t1-t0)*(i+1)/n,m=P(rm,(a+b)/2);if(skip&&skip(m[0],m[1],i))continue;
          lay(Gs(cut([P(r0,a),P(r0,b),P(r1,b),P(r1,a)])),o,typeof col==='function'?col(i):col);}};
      band(0,RO,0,2*Math.PI,4,.125,K.pave);
      const T0=128*D2R,T1=300*D2R;
      band(75.5,82,T0-8*D2R,T1,4,.14,K.asph);band(96,102.5,T0-8*D2R,T1,4,.14,K.asph);
      band(108,111,T0-14*D2R,T1+6*D2R,4,.14,K.pave2,(u,v)=>!free(u,v));band(111,RO,T0-14*D2R,T1+6*D2R,4,.14,i=>i%2?K.lawn:K.lawn2,(u,v)=>!free(u,v));
      band(62,70,T0,T1,4,.14,i=>i%2?K.lawn:K.lawn2,(u,v)=>!free(u,v));band(87.5,90.5,T0,T1,4,.155,K.lawn,(u,v)=>!free(u,v)||inDrive(u,v));
      // the bays, a tone each (the pixel-art stripe of the painted lines)
      for(const [r0,r1] of [[70,75.5],[82,87.5],[90.5,96],[102.5,108]])
        band(r0,r1,T0,T1,2.5,.155,i=>i%2?K.bay:K.bay2,(u,v)=>!free(u,v)||inDrive(u,v));
      for(const p of [SROAD,EROAD,NROAD,NDRIVE])ribbon(Lg,Gs(p),9,.14,K.asph);
      ribbon(Lg,Gs(SROAD),.5,.17,K.line);
      // the pedestrian axis from the west, in two-tone bands, and the water channel along the façade
      for(let u=-RO-2;u<-34;u+=3)lay(Gs(rect(u,-5,u+3,5)),.17,Math.round((u+200)/3)%2?K.pave:K.pave2);
      lay(Gs(rect(-37,-25,-33,-8)),.17,K.water);lay(Gs(rect(-37,8,-33,25)),.17,K.water);
      // the lawns: south-east of the drum (the amphitheater's), the machinery display, the plaza east of the box
      lay(Gs([[40,-60],[78,-100],[118,-90],[121,-40],[95,-45]]),.14,K.lawn);
      lay(Gs(DISPLAY),.14,K.lawn2);ribbon(Lg,Gs([[-122,0],[-142,30],[-142,62]]),2.5,.155,K.gravel);
      lay(Gs(rect(44,6,94,52)),.14,K.pave2);
      const d=drape(Lg);const sv=S.dy;S.dy=0;
      for(let t=0;t<d.ni;t+=3){const k=d.I[t]*3;S.face([0,1,2].map(j=>{const m=d.I[t+j]*3;return [d.P[m],d.P[m+1],d.P[m+2]];}),[0,1,0],[d.C[k],d.C[k+1],d.C[k+2]]);}S.dy=sv;}
    // ---- the building
    const bxQ=rect(...BX),fp=Gs(bxQ.concat(ngon(DC[0],DC[1],DR,16)));occMark(Gs(bxQ));occMark(Gs(ngon(DC[0],DC[1],DR+1,16)));
    const hG=groundMax(fp);S.dy=hG;
    // a wall of vertical stripes along a→b (u, v), outward normal n, between y0 and y1 (relative to S.dy), `w` metres each
    const stripes=(a,b,y0,y1,w,c0,c1,o=.06)=>{const L=Math.hypot(b[0]-a[0],b[1]-a[1]),tu=(b[0]-a[0])/L,tv=(b[1]-a[1])/L,nu=tv,nv=-tu,n=N3(nu,nv);
      for(let s=0,k=0;s<L-.01;s+=w,k++){const e=Math.min(L,s+w),A=[a[0]+tu*s+nu*o,a[1]+tv*s+nv*o],B=[a[0]+tu*e+nu*o,a[1]+tv*e+nv*o];
        S.face([V(A[0],A[1],y0),V(B[0],B[1],y0),V(B[0],B[1],y1),V(A[0],A[1],y1)],n,k%2?c1:c0);}};
    // the four sides of a rectangle, counter-clockwise so that the normal (tv, −tu) points out
    const sides=q=>[[q[0],q[1]],[q[1],q[2]],[q[2],q[3]],[q[3],q[0]]];
    // a cylinder of n facets with its colour per facet
    const cyl=(c,r,y0,y1,n,col,o=0)=>{for(let i=0;i<n;i++){const a=i/n*2*Math.PI,b=(i+1)/n*2*Math.PI,m=(a+b)/2,A=P(r+o,a),B=P(r+o,b);
      S.face([V(c[0]+A[0],c[1]+A[1],y0),V(c[0]+B[0],c[1]+B[1],y0),V(c[0]+B[0],c[1]+B[1],y1),V(c[0]+A[0],c[1]+A[1],y1)],N3(Math.cos(m),Math.sin(m)),col(i));}};
    // piles: a dark core under the deck (the shadow between them) and a row of piles along the edges, each on its own ground
    S.prism(Gs(rect(BX[0]+4,BX[1]+4,BX[2]-4,BX[3]-4)),0,DK,K.dark,K.dark,false);S.prism(Gs(ngon(DC[0],DC[1],DR-4,24)),0,DK,K.dark,K.dark,false);
    {const pile=(u,v)=>{const g=G(u,v),e=E(g[0],g[1]);S.dy=e;S.prism(rotRect(g[0],g[1],.7,.7),0,hG+DK-e,K.slab,K.slab,false);};
      for(let u=BX[0]+1.2;u<=BX[2]-1.2;u+=6){pile(u,BX[1]+1.2);pile(u,BX[3]-1.2);}
      for(let v=BX[1]+7.2;v<=BX[3]-7.2;v+=6)pile(BX[0]+1.2,v);
      for(let i=0;i<32;i++){const p=P(DR-1.2,i/32*2*Math.PI);if(p[0]+DC[0]>BX[2]||p[1]+DC[1]<BX[1])pile(DC[0]+p[0],DC[1]+p[1]);}S.dy=hG;}
    // the deck (concrete edge, timber floor)
    S.prism(Gs(bxQ),DK-.45,DK,K.slab,K.deck);S.prism(Gs(ngon(DC[0],DC[1],DR,48)),DK-.45,DK,K.slab,K.deck);
    // the box: glazed ground floor 3 m inside the deck's edge, timber columns, the slatted upper floor over the terrace
    {const gq=rect(BX[0]+3,BX[1]+3,BX[2]-3,BX[3]-3),H1=DK+5,H2=DK+9.5;
      S.prism(Gs(gq),DK,H1,K.glass,K.roof,false);for(const [a,b] of sides(gq))stripes(a,b,DK+.2,H1,3,K.glass,K.glass2,.04);
      for(let u=BX[0]+.8;u<=BX[2]-.8;u+=6)for(const v of [BX[1]+.8,BX[3]-.8]){const g=G(u,v);S.prism(rotRect(g[0],g[1],.6,.6),DK,H1,K.wood2,K.wood2,false);}
      for(let v=BX[1]+6.8;v<=BX[3]-6.8;v+=6){const g=G(BX[0]+.8,v);S.prism(rotRect(g[0],g[1],.6,.6),DK,H1,K.wood2,K.wood2,false);}
      S.prism(Gs(bxQ),H1,H2,K.wood,K.roof);for(let u=BX[0]+1;u<BX[2]-1;u+=4)S.flat(Gs(rect(u,BX[1]+1,Math.min(u+2,BX[2]-1),BX[3]-1)),H2+.05,K.roof2); // the roof's panelsfor(const [a,b] of sides(bxQ))stripes(a,b,H1+.3,H2-.3,1,K.wood,K.wood2);
      for(const [a,b] of sides(bxQ))stripes(a,b,H2-.3,H2+.25,200,K.wood3,K.wood3,.09); // the coping
      // a raised central volume with a lighter roof, and the plant on it
      const cq=rect(-12,-18,24,18);S.prism(Gs(cq),H2,H2+2,K.wood2,K.roof2);for(const [a,b] of sides(cq))stripes(a,b,H2+.1,H2+1.9,1,K.wood2,K.wood);
      for(const [u,v] of [[-22,-24],[-16,-24],[30,22],[30,16],[-22,24]]){const g=G(u,v);S.prism(rotRect(g[0],g[1],3,2),H2,H2+1.4,K.hvac,K.hvac);}
      // the main entrance: stairs from the plaza to the deck, in the middle of the west façade
      for(let k=0;k<4;k++)S.prism(Gs(rect(BX[0]-4+k,-7,BX[0],7)),0,(k+1)*DK/4,K.slab,k%2?K.pave:K.pave2,true);
      for(let v=-25;v<=25;v+=6){const g=G(BX[0]-.4,v);GLOW.push(g[0],hG+H1-.3,g[1]);}}
    // the drum: glass behind a terrace, then three rings of slats stepping in, the crown with the sign band
    {const c=DC,H1=DK+4.5,H2=DK+7,H3=DK+10.5,H4=DK+13,H5=DK+14.5;
      cyl(c,DR-2.5,DK,H1,48,i=>i%2?K.glass2:K.glass);S.prism(Gs(ngon(c[0],c[1],DR-2.5,48)),DK,H1,K.glass,K.roof,false);
      for(let i=0;i<16;i++){const p=P(DR-.8,i/16*2*Math.PI),g=G(c[0]+p[0],c[1]+p[1]);S.prism(rotRect(g[0],g[1],.6,.6),DK,H1,K.wood2,K.wood2,false);}
      S.prism(Gs(ngon(c[0],c[1],DR,96)),H1,H2,K.wood,K.roof);cyl(c,DR,H1+.2,H2-.2,96,i=>i%2?K.wood2:K.wood,.06);
      S.prism(Gs(ngon(c[0],c[1],27,80)),H2,H3,K.wood,K.roof2);cyl(c,27,H2+.2,H3-.2,80,i=>i%2?K.wood:K.wood2,.06);
      S.prism(Gs(ngon(c[0],c[1],21,64)),H3,H4,K.wood3,K.roof);cyl(c,21,H3+.2,H4-.2,64,i=>i%2?K.wood3:K.wood,.06);
      S.prism(Gs(ngon(c[0],c[1],13,40)),H4,H5,K.sign,K.roof2);cyl(c,13,H5-.3,H5,40,()=>K.wood2,.04);
      // the side entrance toward the plaza of the fountains: stairs at the drum's north-east
      {const a=50*D2R,p=P(DR+2,a),g=G(c[0]+p[0],c[1]+p[1]);for(let k=0;k<4;k++){const q=P(DR+3.5-k,a),h=G(c[0]+q[0],c[1]+q[1]);S.prism(rotRect(h[0],h[1],1.2,10,a),0,(k+1)*DK/4,K.slab,K.pave,true);}
        GLOW.push(g[0],hG+H1,g[1]);}
      for(let i=0;i<24;i++){const p=P(DR+.4,i/24*2*Math.PI),g=G(c[0]+p[0],c[1]+p[1]);GLOW.push(g[0],hG+H1-.3,g[1]);}
      for(let i=0;i<12;i++){const p=P(13.3,i/12*2*Math.PI),g=G(c[0]+p[0],c[1]+p[1]);GLOW.push(g[0],hG+H4+.7,g[1]);}}
    // ---- the plaza of the fountains (east of the box): two basins with jets, a pergola along its north side
    {const at=(u,v)=>{const g=G(u,v);S.dy=E(g[0],g[1]);return g;};
      at(65,26);S.prism(Gs(rect(56,20,74,32)),0,.55,K.rim,K.rim);S.flat(Gs(rect(56.6,20.6,73.4,31.4)),.6,K.water);
      for(const [u,v] of [[60,26],[65,26],[70,26]]){const g=G(u,v);S.prism(rotRect(g[0],g[1],.6,.6),.5,2.6,K.jet,K.jet);}
      at(87,27);S.prism(Gs(ngon(87,27,6,16)),0,.55,K.rim,K.rim);S.flat(Gs(ngon(87,27,5.4,16)),.6,K.water);
      {const g=G(87,27);S.prism(ngon(g[0],g[1],.5,6),.5,3.4,K.jet,K.jet);}
      for(let u=48;u<=98;u+=5)for(const v of [43.5,48.5]){const g=at(u,v);S.prism(rotRect(g[0],g[1],.5,.5),0,3.3,K.wood2,K.wood2,false);if(v>45&&u%10===8)GLOW.push(g[0],S.dy+3,g[1]);}
      at(73,46);for(let u=48;u<=98;u+=1)S.prism(Gs(rect(u-.25,42.8,u+.25,49.2)),3.3,3.6,K.wood,K.wood3);
      for(const [u,v] of [[46,8],[98,8],[46,40],[98,40],[80,14],[52,30]]){const g=G(u,v);S.dy=E(g[0],g[1]);palmS(g[0],g[1],8.5+rr()*2.5,rr()*Math.PI);}}
    // ---- the amphitheater: five tiers facing north (toward the drum), a timber stage
    {const g=G(...AM);S.dy=E(g[0],g[1]);
      for(let k=0;k<5;k++){const r0=6+1.6*k,r1=r0+1.6,n=14;
        for(let i=0;i<n;i++){const a=Math.PI+Math.PI*i/n,b=Math.PI+Math.PI*(i+1)/n;
          S.prism(Gs([P(r0,a),P(r0,b),P(r1,b),P(r1,a)].map(p=>[AM[0]+p[0],AM[1]+p[1]])),0,.4+.45*k,K.seat,k%2?K.seat2:K.seat,true);}}
      S.prism(Gs(rect(AM[0]-7,AM[1],AM[0]+7,AM[1]+5)),0,.9,K.wood2,K.stage);occMark(Gs(ngon(AM[0],AM[1],15,12)));}
    // ---- parked cars (a body and a cabin), radial in the bays; lamps and trees on the island between the middle rows
    {const car=(r,t)=>{const p=P(r,t),g=G(p[0],p[1]),c=K.car[Math.floor(rr()*K.car.length)];if(!inTerrain(g[0],g[1]))return;
        S.dy=E(g[0],g[1]);S.prism(rotRect(g[0],g[1],4.2,1.8,t),.13,1,c,c);S.prism(rotRect(g[0],g[1],2.2,1.6,t),1,1.55,K.carGl,c);};
      const T0=128*D2R,T1=300*D2R;
      for(const [r0,r1] of [[70,75.5],[82,87.5],[90.5,96],[102.5,108]]){const rm=(r0+r1)/2,n=Math.round((T1-T0)*rm/2.5);
        for(let i=0;i<n;i++){const t=T0+(T1-T0)*(i+.5)/n,p=P(rm,t);if(!free(...p)||inDrive(...p)||p[1]>VMAX-2.5)continue;if(rr()<.5)car(rm,t);}}
      for(let t=T0+2*D2R,k=0;t<T1;t+=9/89,k++){const p=P(89,t);if(!free(...p)||inDrive(...p)||p[1]>VMAX)continue;const g=G(...p);
        if(k%3===1){S.dy=E(g[0],g[1]);S.prism(rotRect(g[0],g[1],.3,.3),0,7,K.iron,K.iron,false);S.prism(rotRect(g[0],g[1],.8,.8),7,7.35,K.iron,K.lamp);GLOW.push(g[0],S.dy+7.6,g[1]);}
        else if(inTerrain(g[0],g[1]))TREES.push([g[0],g[1],.95+rr()*.3,rr()]);}}
    // ---- palms along the axis and the inner lawn; lamps along the axis; palms and trees on the plaza north of the box
    {for(let u=-22;u<=-8;u+=7){const g=G(u,40);S.dy=E(g[0],g[1]);palmS(g[0],g[1],8.5+rr()*2,rr()*Math.PI);}
      for(const [u,v] of [[8,40],[20,44],[32,38],[12,52],[28,54]]){const g=G(u,v);TREES.push([g[0],g[1],.9+rr()*.25,rr()]);}
      for(let u=-118;u<=-42;u+=13)for(const v of [-7.5,7.5]){const g=G(u+(v>0?6:0),v);S.dy=E(g[0],g[1]);palmS(g[0],g[1],9+rr()*2.5,rr()*Math.PI);}
      for(let t=134*D2R;t<300*D2R;t+=16/66){const p=P(66,t);if(inAxis(...p)||p[1]>VMAX-4)continue;const g=G(...p);S.dy=E(g[0],g[1]);palmS(g[0],g[1],8+rr()*3,rr()*Math.PI);}
      for(let u=-112;u<=-44;u+=13){const g=G(u+3,0);S.dy=E(g[0],g[1]);S.prism(rotRect(g[0],g[1],.3,.3),0,4.5,K.iron,K.iron,false);S.prism(rotRect(g[0],g[1],.7,.7),4.5,4.8,K.iron,K.lamp);GLOW.push(g[0],S.dy+5,g[1]);}}
    // ---- the fair's farm machinery on its lawn: four tractors and a combine harvester
    {const tractor=(u,v,a,col)=>{const g=G(u,v),R_=(du,dv,w,d)=>{const c=Math.cos(a),s=Math.sin(a);return rotRect(g[0]+du*c-dv*s,g[1]+du*s+dv*c,w,d,a);};
        S.dy=E(g[0],g[1]);S.prism(R_(.2,0,3.4,1.3),.6,1.7,col,col);S.prism(R_(-.7,0,1.5,1.5),1.7,2.9,K.cab,col);
        for(const s of [-1,1]){S.prism(R_(-.9,s*1.05,1.6,.6),0,1.6,K.wheel,K.wheel,false);S.prism(R_(1.4,s*.85,1,.45),0,1,K.wheel,K.wheel,false);}};
      tractor(-150,32,.3,K.tractor[0]);tractor(-140,44,-.4,K.tractor[1]);tractor(-153,56,1.2,K.tractor[2]);tractor(-133,66,0,K.tractor[3]);
      {const g=G(-134,28),a=-.2;S.dy=E(g[0],g[1]);S.prism(rotRect(g[0],g[1],7,3.2,a),.6,3.4,K.tractor[0],K.tractor[0]);
        const c=G(-134+2.4*Math.cos(a),28+2.4*Math.sin(a));S.prism(rotRect(c[0],c[1],1.8,1.8,a),3.4,4.6,K.cab,K.tractor[0]);
        const h=G(-134+4.4*Math.cos(a),28+4.4*Math.sin(a));S.prism(rotRect(h[0],h[1],1.2,6,a),.5,1.4,K.tractor[3],K.tractor[3]);
        for(const s of [-1,1]){const w=G(-134+1.6*Math.cos(a)-s*1.7*Math.sin(a),28+1.6*Math.sin(a)+s*1.7*Math.cos(a));S.prism(rotRect(w[0],w[1],1.7,.7,a),0,1.7,K.wheel,K.wheel,false);}}}
    // ---- trees outside the circle where the 2020 imagery shows them: the south-west grove, the rows along the lot's
    // edges (south, north, east), the north-east corner; none on the roads, the display or the circle
    {const t=(x,y,s)=>{if(inTerrain(x,y))TREES.push([x,y,s,rr()]);},uv=(x,y)=>[x-X,y-Y],
        ok=(x,y)=>{const [u,v]=uv(x,y);return pip([x,y],RES)&&Math.hypot(u,v)>RO+3&&!(v>VMAX-2&&Math.hypot(u,v)<RO)&&!nearRoad(u,v,8)&&!pip([u,v],DISPLAY)&&!inAxis(u,v);};
      const grove=(poly,n,s0)=>{let k=0,bb=[1e9,1e9,-1e9,-1e9];for(const p of poly)bb=[Math.min(bb[0],p[0]),Math.min(bb[1],p[1]),Math.max(bb[2],p[0]),Math.max(bb[3],p[1])];
        for(let g=0;g<n*40&&k<n;g++){const x=bb[0]+rr()*(bb[2]-bb[0]),y=bb[1]+rr()*(bb[3]-bb[1]);if(pip([x,y],poly)&&ok(x,y)){t(x,y,s0+rr()*.5);k++;}}};
      const edge=(a,b,step,off)=>{const L=Math.hypot(b[0]-a[0],b[1]-a[1]),tx=(b[0]-a[0])/L,ty=(b[1]-a[1])/L;
        for(let s=step/2;s<L;s+=step){if(rr()<.2)continue;const x=a[0]+tx*s-ty*off+(rr()-.5)*2,y=a[1]+ty*s+tx*off+(rr()-.5)*2;if(ok(x,y))t(x,y,1.1+rr()*.4);}};
      grove([[-1255,640],[-1190,628],[-1175,660],[-1172,745],[-1212,760],[-1262,690]],70,1.3);
      edge([-1317,639],[-1192,624],9,6);edge([-1192,624],[-1049,601],9,6);edge([-1049,601],[-990,590],9,6);
      edge([-874,819],[-1195,891],10,7);edge([-874,819],[-1195,891],9,-6);edge([-913,715],[-874,819],9,-9);edge([-928,661],[-913,715],9,-9);edge([-935,601],[-928,661],9,-8);edge([-1195,891],[-1297,680],11,7);edge([-913,715],[-874,819],9,7);edge([-928,661],[-913,715],9,7);
      grove([[-960,800],[-885,790],[-878,815],[-940,835]],16,1.3);grove([[-1150,840],[-1100,800],[-1060,815],[-1100,870],[-1150,880]],18,1.3);}
    MODELS['casino-dreams']={x:G(20,-8)[0],y:G(20,-8)[1],h:DK+14.5};
    EH.set(keepEH);S.dy=0;}
