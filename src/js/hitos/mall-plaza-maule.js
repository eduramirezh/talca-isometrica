  // ==== hito: mall-plaza-maule ====
  // Mall Plaza Maule, on S (its windows are drawn). Plan from OpenStreetMap: the mall w110780381, the hotel and
  // casino w110781510, the parking lot w311050604, the site w101568633 (landuse=commercial). The mall's OSM outline
  // also takes in the parking lot to the north-west (it has been there since 2020, perhaps for the underground deck
  // under it); the imagery shows cars there, so that part is drawn as a lot and the building stops at its south edge.
  // Frame from landmark.py frame mall-plaza-maule 110780381: v along the long side, toward 2 Norte (NNE), u toward
  // Av. Circunvalación. The masses read in the Esri imagery: the galleria's lens-shaped vault with its blue dome, the
  // anchors' flat and ribbed roofs, the hotel's slab with a pool on the north podium. The east front on the central
  // lot (photos on Wikimedia Commons, 2025-03, CC BY 4.0) is a curved brick façade, ~12 m, with large glazed bays over
  // a grey band, a white coping and the four-colour logo. Approximate: every height (none measured: ~12 m for the
  // mall, a 2-storey façade; vault and dome from the imagery's shadows; the hotel's slab ~24 m, five floors of rooms
  // on the casino), the dome's size, the hotel's split between slab and podium, the anchors' façades (no photos).
  {const F=localFrame(3328.2,-322.5,74.7*Math.PI/180),{G,Gs,V,N3,R}=F;
    const K={clad:C('#D9D5CC'),clad2:C('#C9C5BC'),white:C('#ECE7DC'),roof:C('#B3AFA6'),roof2:C('#A8A49A'),roof3:C('#C4BFB3'),
      brick:C('#B07552'),band:C('#9A9A96'),glass:C('#4D5D66'),glass2:C('#3B4653'),vault:C('#D8D6CE'),vault2:C('#C6C3BA'),
      dome:C('#3E6F80'),dome2:C('#4A8396'),hvac:C('#8F8C86'),asph:C('#65615D'),stall:C('#716D68'),line:C('#E8E4DA'),
      pool:C('#4E8FA6'),hotel:C('#E3E1DA'),podium:C('#8C8A86'),grass:C('#7FA05A'),
      logo:[C('#3A7FC1'),C('#7DB343'),C('#F2C230'),C('#E0533A')]};
    const {box,WL,rect}=facade(S,F,K);
    // walls of a counter-clockwise (u,v) ring from h0 to h1, a white coping on top; col(i) picks each side's colour
    const walls=(ring,h0,h1,col)=>{for(let i=0;i<ring.length;i++){const a=ring[i],b=ring[(i+1)%ring.length],L=Math.hypot(b[0]-a[0],b[1]-a[1]);
      if(L<.01)continue;const w=WL(a,b,[(b[1]-a[1])/L,-(b[0]-a[0])/L],0),c=typeof col==='function'?col(i):col;
      S.face([w.q(0,h0),w.q(L,h0),w.q(L,h1-.5),w.q(0,h1-.5)],w.n,c);S.face([w.q(0,h1-.5),w.q(L,h1-.5),w.q(L,h1),w.q(0,h1)],w.n,K.white);}};
    const slab=(ring,h0,h1,col,top)=>{walls(ring,h0,h1,col);S.flat(Gs(ring),h1,top);};
    const SITE=[[-97,113],[-99,6],[-82,6],[-90,-208],[95,-213],[96,-97],[96,-79],[98,113]].reverse();
    const site=Gs(SITE);NOLOTS.push(site);occMark(site);
    S.dy=padAt(Math.min(...site.map(p=>p[0])),Math.min(...site.map(p=>p[1])),Math.max(...site.map(p=>p[0])),Math.max(...site.map(p=>p[1])));
    // the site's asphalt, the lots' stall rows (lighter bands with a white line between the two rows of a bay)
    S.flat(site,.3,K.asph);
    const rows=(v,u0,u1)=>{S.quadXY(R(u0,v-5.2,u1,v-.25),.33,K.stall);S.quadXY(R(u0,v+.25,u1,v+5.2),.33,K.stall);S.quadXY(R(u0,v-.25,u1,v+.25),.36,K.line);};
    for(const v of [-63,-79,-95,-111])rows(v,-1,v<-108?46:78);
    for(let v=6;v<106;v+=15){const ue=v<57?-30+9*(v+3)/60:-21+2*(v-57)/53;rows(v,-93,ue-6);}
    S.quadXY(R(88,-112,95,60),.33,K.grass); // the planted strip along Av. Circunvalación
    // the mall: one block at 12 m, its east front on the central lot (sides 3-9) a curved brick façade
    const MALL=[[-80,-200],[15,-200],[17,-129],[-15,-129],[-13,-121],[-10,-112],[-8,-103],[-7,-93],[-7,-78],[-9,-52],[-10,-48],[-2,-46],[7,-46],
      [7,-51],[89,-51],[90,-4],[83,-3],[84,78],[86,105],[34,105],[33,66],[19,66],[19,61],[8,61],[9,109],[-19,110],[-18,63],[-14,62],[-14,50],
      [-17,50],[-21,57],[-30,-3],[-80,-7]];
    const BRICK=i=>i>=3&&i<=9;
    slab(MALL,.3,12,i=>BRICK(i)?K.brick:i%2?K.clad:K.clad2,K.roof);occMark(Gs(MALL));
    // the brick front: shop windows, a grey band, tall glazed bays between brick piers
    for(let i=3;i<=9;i++){const a=MALL[i],b=MALL[i+1],L=Math.hypot(b[0]-a[0],b[1]-a[1]),out=[(b[1]-a[1])/L,-(b[0]-a[0])/L];
      const w=WL(a,b,out),w2=WL(a,b,out,.09),n=Math.max(1,Math.round(L/8.5)),bw=L/n;
      rect(w2,0,L,4.2,5.4,K.band);
      for(let k=0;k<n;k++){const s0=k*bw+1.1,s1=(k+1)*bw-1.1;if(s1-s0<1.5)continue;rect(w,s0,s1,.3,3.8,K.glass2);
        for(let h=5.6,j=0;h<10.6;h+=1.7,j++)rect(w,s0,s1,h,Math.min(h+1.7,10.6),j%2?K.glass2:K.glass);}}
    {const a=MALL[8],b=MALL[9],L=Math.hypot(b[0]-a[0],b[1]-a[1]),w=WL(a,b,[(b[1]-a[1])/L,-(b[0]-a[0])/L],.12);
      [[0,0],[1,0],[0,1],[1,1]].forEach(([i,j],k)=>rect(w,L-6+i*1.2,L-4.8+i*1.2,9.8+j*1.2,11+j*1.2,K.logo[k]));}
    // anchors: the north-east store's ribbed roof (bays of two tones), the south-west block's plant on its roof
    for(let v=-51,k=0;v<61;v+=7,k++)S.quadXY(R(7.5,v,83,Math.min(61,v+7)),12.03,k%2?K.roof3:K.roof);
    for(let v=66,k=0;v<104;v+=6,k++)S.quadXY(R(34.5,v,85,Math.min(104.5,v+6)),12.03,k%2?K.roof3:K.roof2);
    S.quadXY(R(-79.5,-199.5,-36,-130),12.03,K.roof2);S.quadXY(R(-36,-199.5,14.5,-130),12.03,K.roof3);
    for(const [u,v] of [[-70,-188],[-58,-176],[-70,-160],[-48,-188],[-58,-146],[-20,-180],[2,-160],[-45,-160]])box(u-2,v-1.5,u+2,v+1.5,12,13.6,K.hvac,K.clad);
    // the galleria: a lens-shaped vault (OSM's outline, the imagery's tips) over the mall, ribs in two tones, a
    // stepped glass dome west of its ridge
    {const N=[-54,-20],Sx=[-38,-144],c=[(N[0]+Sx[0])/2,(N[1]+Sx[1])/2],Lh=Math.hypot(Sx[0]-N[0],Sx[1]-N[1])/2,d=[(N[0]-Sx[0])/(2*Lh),(N[1]-Sx[1])/(2*Lh)],p=[d[1],-d[0]];
      const n=16,at=(t,s)=>{const w=19*(1-t*t);return [c[0]+d[0]*Lh*t+p[0]*w*s,c[1]+d[1]*Lh*t+p[1]*w*s];},rh=t=>7*Math.sqrt(Math.max(0,1-t*t));
      const leaf=[];for(let i=0;i<=n;i++)leaf.push(at(-1+2*i/n,1));for(let i=n-1;i>0;i--)leaf.push(at(-1+2*i/n,-1));
      walls(leaf,12,15,K.clad);
      for(let i=0;i<n;i++){const t0=-1+2*i/n,t1=t0+2/n,col=i%2?K.vault2:K.vault;
        for(const s of [1,-1]){const a0=at(t0,s),a1=at(t1,s),m0=at(t0,0),m1=at(t1,0);
          const P=[V(...a0,15),V(...a1,15),V(...m1,15+rh(t1)),V(...m0,15+rh(t0))],e=[P[2][0]-P[0][0],P[2][1]-P[0][1],P[2][2]-P[0][2]],f=[P[3][0]-P[1][0],P[3][1]-P[1][1],P[3][2]-P[1][2]];
          let nn=[e[1]*f[2]-e[2]*f[1],e[2]*f[0]-e[0]*f[2],e[0]*f[1]-e[1]*f[0]];if(nn[1]<0)nn=nn.map(x=>-x);const L=Math.hypot(...nn);S.face(P,nn.map(x=>x/L),col);}}
      const dc=G(-56,-76);[[8,15,19.6,K.dome],[7,19.6,21.2,K.dome2],[5.6,21.2,22.5,K.dome],[3.8,22.5,23.4,K.dome2],[1.4,23.4,24.6,K.white]]
        .forEach(([r,h0,h1,col])=>S.prism(ngon(dc[0],dc[1],r,8,Math.PI/8),h0,h1,col,col));}
    // hotel and casino: the casino's podium (OSM outline), the hotel's slab with bands of windows, the pool on the
    // north podium
    const HOT=[[51,-120],[69,-120],[69,-117],[88,-117],[86,-199],[50,-200],[50,-196],[35,-196],[36,-127],[51,-127]].reverse();
    slab(HOT,.3,7,K.glass,K.podium);occMark(Gs(HOT));
    for(const [a,b] of HOT.map((p,i)=>[p,HOT[(i+1)%HOT.length]])){const L=Math.hypot(b[0]-a[0],b[1]-a[1]);if(L<4)continue;
      const w=WL(a,b,[(b[1]-a[1])/L,-(b[0]-a[0])/L],.06);for(const h of [2.2,4.6])rect(w,0,L,h,h+.5,K.band);}
    box(52,-198,87,-138,7,24,K.hotel,K.roof3);
    for(const w of [WL([52,-198],[52,-138],[-1,0]),WL([87,-138],[87,-198],[1,0]),WL([87,-198],[52,-198],[0,-1]),WL([52,-138],[87,-138],[0,1])])
      for(let h=8.6;h<23;h+=3.2)rect(w,1,w.L-1,h,h+1.5,K.glass);
    box(45,-138,87,-119,7,13,K.hotel,K.roof3);S.quadXY(R(48,-134,58,-124),13.03,K.pool);
    for(const [u,v] of [[60,-185],[75,-170],[64,-155],[78,-148]])box(u-2,v-1.5,u+2,v+1.5,24,25.4,K.hvac,K.clad);
    const m=G(-30,-70);MODELS['mall-plaza-maule']={x:m[0],y:m[1],h:20};S.dy=0;}
