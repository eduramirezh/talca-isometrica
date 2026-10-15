  // ==== hito: plaza-de-armas ====
  // helpers for the landmarks round the plaza (they could be shared): a Canary palm (ringed trunk, dark crown, eight
  // arched fronds in two greens) and a Chilean flag on a pole, both on S at S.dy, in grid metres
  const palmS=(x,y,h,r0=0)=>{const tr=C('#6E5B48'),cr=C('#4E7A3C'),fr=[C('#5F8C45'),C('#4E7A3A')];occMark(rotRect(x,y,3,3));
    for(let z=0.3,k=0;z<h-.6;z+=1.2,k++)S.prism(ngon(x,y,k%2?.45:.5,6),z,Math.min(z+1.2,h-.6),k%2?shade(tr,.9):tr,tr);
    S.prism(ngon(x,y,.8,6),h-.6,h+.3,cr,cr);
    for(let i=0;i<8;i++){const t=r0+i*Math.PI/4,c=Math.cos(t),s=Math.sin(t),P=(d,w,z)=>[x+c*d-s*w,z,-(y+s*d+c*w)];
      S.face([P(.3,-.3,h+.2),P(.3,.3,h+.2),P(2.2,.7,h+.6),P(2.2,-.7,h+.6)],null,fr[i%2]);
      S.face([P(2.2,-.7,h+.6),P(2.2,.7,h+.6),P(4,.25,h-1),P(4,-.25,h-1)],null,fr[i%2]);}};
  const flagS=(x,y,h0,ph)=>{const pole=C('#D9D9D6'),f=(x0,x1,z0,z1,c)=>{const t=h0+ph-.2;
      for(const sg of [1,-1])S.face([[x+x0,t-z1,-y],[x+x1,t-z1,-y],[x+x1,t-z0,-y],[x+x0,t-z0,-y]],[0,0,sg],c);};
    S.prism(rotRect(x,y,.22,.22),h0,h0+ph,pole,pole);f(.1,2.2,.75,1.5,C('#C8322B'));f(.1,.85,0,.75,C('#2B4C8C'));f(.85,2.2,0,.75,C('#F2F0EA'));};
  // Plaza de Armas, built on S in grid metres (the plaza is aligned with the grid). Plan from OpenStreetMap: park
  // w479529034 (rounded corners), the twelve lawn beds w1186645153–64 between the diagonal walks, the inner ring and
  // the outer ring, the two lawns along 1 Norte (w556036456, w556036459), the four round plazuelas on the cross axes
  // (kiosk w223617018 to the east, fountains n11021259067 north and n3428801896 west, the Carlos Spano memorial
  // n11021258973 in a flower bed to the south), the central fountain n3428801388 and the Monseñor Larraín statue
  // n11021259030. Above the ground, from photos on Wikimedia Commons: the octagonal cast-iron bandstand on a stone base
  // under a scaled zinc dome (2014, 2022), the central fountain's stone basin, painted blue, with a green iron
  // two-tier fountain (2018), the Spano stone (2024), tiled walks with darker bands, lawns edged with white curbs
  // (2024), Canary palms flanking the diagonal entrances (2024). The trees are the generic park trees, kept to the
  // lawns and to the row along the edge (OSM maps that row), so the walks stay clear. Approximate: the north and west
  // fountains (no photos: drawn as plain basins), the bands' grid, which trees are palms (only the four entrance
  // pairs are drawn), the kiosk's steps. The lamps' glow is real (the plaza is lit), their positions are not.
  // Method: docs/METODOLOGIA.md §9; style: docs/ESTETICA.md.
  {const K={pave:C('#D6CDBD'),band:C('#C2B6A3'),sett:C('#ACA497'),curb:C('#ECE7DC'),grass:C('#5F9840'),grass2:C('#72AC4D'),
      bed:C('#4E7A3C'),bloom:C('#C77D8E'),stone:C('#A9A49A'),stone2:C('#BDB8AD'),water:C('#4F86B5'),iron:C('#2F2D2C'),
      green:C('#33544A'),zinc:C('#A9ADAB'),granite:C('#B3AEA4'),marble:C('#E4E0D6'),
      lamp:C('#F1E6C4')};
    const Q=a=>{const o=[];for(let i=0;i<a.length;i+=2)o.push([a[i],a[i+1]]);return o;};
    const PZ=Q([38.9,-54.2,35.8,-54.5,-21.3,-54,-29.9,-54,-35.8,-52.5,-41.2,-49.6,-47.4,-44.3,-51.5,-38.9,-53.5,-32.2,-55.7,-23.9,
      -55.7,22.4,-55,34.9,-53.3,40.4,-51.5,43.9,-47.7,48.9,-43.7,52,-39.2,53.7,-34.7,54.8,36.6,53.1,40.3,52.5,43.8,50.4,49.6,43.6,
      53.8,38.2,55.7,30.3,56.2,-29.9,55.8,-34.7,53.2,-41.1,48.4,-47.7,41.6,-53]);
    const LAWNS=[[-13.4,16.8,-4.5,7.9,-1.9,8.7,0.5,8.9,3,8.4,5.3,7.1,14.3,15.5,13.7,16.3,7.6,19.6,0.1,20.8,-7.1,20],
      [17.2,12.3,8.4,3.9,9.2,2.3,9.8,-1,9.2,-4.3,8.5,-5.8,17.3,-14.2,19.9,-11.4,22.1,-4.1,21.8,2.9,19.7,9.4],
      [-8.3,3.9,-17.1,13.1,-18.6,12,-21.8,5.6,-22,-1.9,-21.3,-8.8,-18.4,-14.8,-17.4,-16,-7.7,-6.5,-8.7,-4.8,-9.3,-2.7,-9.5,0,-8.9,2.7],
      [-4.3,-9.7,-13.5,-18.9,-12.1,-20.1,-5.7,-22.8,0.7,-23,9,-21.3,14.5,-18,5.6,-8.9,3.3,-9.9,0.5,-10.3,-2.2,-10.2],
      [-15.6,18.8,-30.1,32.5,-28,34.9,-8.3,34.8,-9.4,32,-9.6,28.5,-8.9,25.5,-7.7,23.7,-6.6,23],
      [7.7,34.4,8.7,31.6,8.3,28.2,7.4,25.8,4.9,22.7,8.6,22.4,16.6,17.4,30.4,30.9,28,34.2],
      [-33.1,28.7,-35.7,26,-35.5,5.1,-31.9,6.3,-28.6,6.1,-26.3,5.3,-25,4.5,-24.8,6.8,-20.9,13.9,-19.6,15.5],
      [33.1,27.6,19.6,14.1,21.7,11.7,23.8,5.7,26.8,7.8,30.7,8.4,33.5,8.2,35.5,6.7,35.7,24.4],
      [-35.5,-10.4,-35.1,-27.8,-32,-30.8,-19.6,-18.3,-21,-16.2,-24.1,-10.6,-24.6,-9.1,-28.2,-11.2,-32,-11.4],
      [-28.4,-34.2,-26.2,-36.4,-7,-36.6,-8.7,-34.7,-9,-31.3,-8.1,-27.7,-6.9,-26.5,-14.3,-23.4,-16.5,-21.9],
      [28,-33.3,24.3,-36.3,7.4,-36.5,9.1,-34.6,9.5,-31.2,8.7,-27.6,7.7,-26.4,15.1,-23.4,17.7,-21.6],
      [24.4,-7.9,22.9,-13.1,20.1,-17.8,31,-29.5,35.1,-25.8,35.3,-8.6,33.2,-9.9,29,-10,26.2,-9.3],
      [5.3,52.3,38,52.2,39.3,51.8,41.7,49.1,41.6,47.4,39.9,46.7,38.3,46.1,5.3,47.8,3.1,49.7,3.5,51.4],
      [-31,48.3,-3,48,-2.3,49.4,-2.1,51.7,-3.2,52.7,-4.9,53.2,-7,53.5,-30.1,54,-32.2,52.8,-32.3,51.1,-32.2,49.2]].map(Q);
    // polygon tools: signed area, inset by d (mitred), a segment clipped to a convex polygon
    const area=q=>{let a=0;for(let i=0;i<q.length;i++){const p=q[i],r=q[(i+1)%q.length];a+=p[0]*r[1]-r[0]*p[1];}return a/2;};
    const inset=(q,d)=>{const s=area(q)>0?1:-1,n=q.length;return q.map((p,i)=>{const a=q[(i+n-1)%n],b=q[(i+1)%n];
      const l1=Math.hypot(p[0]-a[0],p[1]-a[1])||1,l2=Math.hypot(b[0]-p[0],b[1]-p[1])||1;
      const n1=[-(p[1]-a[1])/l1*s,(p[0]-a[0])/l1*s],n2=[-(b[1]-p[1])/l2*s,(b[0]-p[0])/l2*s],k=Math.max(.35,1+n1[0]*n2[0]+n1[1]*n2[1]);
      return [p[0]+(n1[0]+n2[0])*d/k,p[1]+(n1[1]+n2[1])*d/k];});};
    const clip=(a,b,q)=>{let t0=0,t1=1;const s=area(q)>0?1:-1,d=[b[0]-a[0],b[1]-a[1]];
      for(let i=0;i<q.length;i++){const p=q[i],r=q[(i+1)%q.length],nx=-(r[1]-p[1])*s,ny=(r[0]-p[0])*s;
        const num=nx*(a[0]-p[0])+ny*(a[1]-p[1]),den=nx*d[0]+ny*d[1];
        if(Math.abs(den)<1e-9){if(num<0)return null;continue;}const t=-num/den;if(den>0)t0=Math.max(t0,t);else t1=Math.min(t1,t);if(t0>=t1)return null;}
      return [[a[0]+d[0]*t0,a[1]+d[1]*t0],[a[0]+d[0]*t1,a[1]+d[1]*t1]];};
    const disc=(x,y,r,h,col,n=16)=>S.flat(ngon(x,y,r,n,Math.PI/n),h,col);
    // the ground is levelled. Its height is the level of the buildings round the plaza too (MODELS[...].pad): terrain
    // nodes are 40 m apart and the last pad pushed sets the ones it shares, so neighbouring pads at different heights
    // would tilt the plaza. The procedural park trees keep to the lawns and to a 4 m row along the edge
    S.dy=padAt(-56,-55,56.5,55.2);
    {const row0=inset(PZ,4.5),row1=inset(PZ,8.5);
      for(let gx=Math.floor((-57-XMIN)/OC);gx<=Math.floor((57-XMIN)/OC);gx++)for(let gy=Math.floor((-56-YMIN)/OC);gy<=Math.floor((56-YMIN)/OC);gy++){
        const c=[XMIN+(gx+.5)*OC,YMIN+(gy+.5)*OC];if(!pip(c,PZ)||LAWNS.some(q=>pip(c,q))||(pip(c,row0)&&!pip(c,row1)))continue;occ[gy*ocW+gx]=1;}}
    // paving, darker bands every 6 m, sett round the west fountain
    S.flat(PZ,0.30,K.pave);const pin=inset(PZ,.6);
    for(let k=-54;k<=54;k+=6){for(const [a,b] of [[[k,-60],[k,60]],[[-60,k],[60,k]]]){const s=clip(a,b,pin);if(!s)continue;
      const v=k===s[0][0]&&k===s[1][0];S.quadXY(v?[[k-.25,s[0][1]],[k+.25,s[0][1]],[k+.25,s[1][1]],[k-.25,s[1][1]]]:[[s[0][0],k-.25],[s[1][0],k-.25],[s[1][0],k+.25],[s[0][0],k+.25]],0.33,K.band);}}
    disc(-30.7,-2.3,7.2,0.36,K.sett,24);
    // lawns: a white curb round each bed, grass in two tones
    LAWNS.forEach((q,i)=>{S.flat(q,0.39,K.curb);S.flat(inset(q,.45),0.42,i%2?K.grass2:K.grass);});
    // central fountain: stone basin painted blue inside, green iron fountain in two tiers
    {const x=0.2,y=-1.4;S.prism(ngon(x,y,3.6,16,Math.PI/16),0.3,1.0,K.stone,K.stone2);disc(x,y,3.1,1.03,K.water);
      S.prism(ngon(x,y,.9,8),1.0,1.6,K.green,K.green);S.prism(ngon(x,y,1.7,8,Math.PI/8),1.6,1.95,K.green,K.green);
      S.prism(ngon(x,y,.32,6),1.95,3.3,K.green,K.green);S.prism(ngon(x,y,.95,8,Math.PI/8),3.3,3.55,K.green,K.green);S.prism(ngon(x,y,.28,6),3.55,4.4,K.green,K.green);}
    // north and west fountains: plain round basins with a spout (no photos)
    for(const [x,y] of [[-0.8,29.7],[-30.7,-2.3]]){S.prism(ngon(x,y,2.6,16,Math.PI/16),0.3,0.95,K.stone,K.stone2);disc(x,y,2.15,0.98,K.water);
      S.prism(ngon(x,y,.4,6),0.98,2.2,K.stone2,K.stone2);}
    // bandstand (OSM octagon, r 4.4): stone base with steps toward the plaza's centre, eight iron columns, a railing,
    // the cornice with a stepped pediment on each face, a zinc dome in two tones and a finial
    {const x=30.2,y=-0.5,a0=Math.PI/8;S.prism(ngon(x,y,4.6,8,a0),0.3,1.6,K.stone,K.stone2);
      S.prism(rotRect(x-5.2,y,1.4,3.2),0.3,0.75,K.stone2,K.stone2);S.prism(rotRect(x-4.9,y,1,3.2),0.75,1.2,K.stone2,K.stone2);
      S.prism(ngon(x,y,4.15,8,a0),1.6,2.5,K.iron,K.iron,false);
      for(const c of ngon(x,y,4.15,8,a0))S.prism(rotRect(c[0],c[1],.4,.4),2.5,5.5,K.iron,K.iron,false);
      S.prism(ngon(x,y,4.8,8,a0),5.5,6.3,K.iron,K.iron);
      for(let i=0;i<8;i++){const t=i*Math.PI/4,cx=x+Math.cos(t)*4.3,cy=y+Math.sin(t)*4.3;
        S.prism(rotRect(cx,cy,.3,2.4,t),6.3,6.75,K.iron,K.iron);S.prism(rotRect(cx,cy,.3,1.2,t),6.75,7.2,K.iron,K.iron);}
      pyramid(S,ngon(x,y,3.9,8,a0),6.3,2.3,K.zinc);S.prism(ngon(x,y,.3,6),8.4,9.2,K.iron,K.iron);
      GLOW.push(x,S.dy+5,y);}
    // Carlos Spano memorial: a round flower bed with a white curb, a stone pedestal and the inscribed granite slab
    {const x=0.2,y=-31.4;disc(x,y,3.8,0.39,K.curb);disc(x,y,3.35,0.42,K.bed);
      for(let i=0;i<8;i++){const t=i*Math.PI/4+.3;S.quadXY(rotRect(x+Math.cos(t)*2.5,y+Math.sin(t)*2.5,.6,.6,t),0.45,K.bloom);}
      S.prism(ngon(x,y,.9,8,Math.PI/8),0.3,1.0,K.marble,K.marble);S.prism(rotRect(x,y,2.1,.55),1.0,3.1,K.granite,K.granite);}
    // Monseñor Larraín: a white statue on a stone plinth
    {const x=-35.2,y=27.5;S.prism(rotRect(x,y,1.5,1.5),0.3,2.1,K.stone2,K.stone);S.prism(rotRect(x,y,.8,.6),2.1,3.6,K.marble,K.marble);
      S.prism(rotRect(x,y,.45,.45),3.6,4.1,K.marble,K.marble);}
    // Canary palms flanking the diagonal entrances
    [[26.5,32.5],[32.5,25],[-26.5,32.5],[-31,23],[26.5,-32.5],[32.5,-25],[-26.5,-32.5],[-32.5,-25]].forEach(([x,y],i)=>palmS(x,y,11+(i%3)*1.2,i*.4));
    // lamps on the inner ring at the diagonals and round the central fountain
    for(const [r,n,a] of [[23.6,8,Math.PI/8],[8.6,4,Math.PI/4]])for(const c of ngon(0.2,-1.2,r,n,a)){
      S.prism(rotRect(c[0],c[1],.3,.3),0.3,4.2,K.green,K.green);S.prism(rotRect(c[0],c[1],.7,.7),4.2,4.9,K.green,K.lamp);GLOW.push(c[0],S.dy+4.6,c[1]);}
    MODELS['plaza-de-armas']={x:0,y:0,h:9,pad:S.dy};S.dy=0;}
