  // ==== hito: terminal-buses ====
  // Terminal de Buses Lorenzo Varoli Gherardi (the interurban bus terminal), in the block between 12 and 13 Oriente,
  // 2 Sur and 3 Sur, 200 m east of the railway station; drawn on S. Plan from OpenStreetMap: the site w110962821
  // (amenity=bus_station), the long office building along 2 Sur w1420052912 (22 m deep, with a lower west wing), the
  // market-like block at the south-west w1420052911, the platform canopies w1420052919 (the island) and w1420052914
  // with the back building w1420052913 (the south strip), the toilets w723297522, three kiosks (w1420052908-10) and the
  // four vehicle gates (nodes barrier=gate). Frame from landmark.py frame terminal-buses 1420052912: X=1718.2,
  // Y=-235.7, A=0.8°; u runs south (toward 3 Sur), v east (toward 13 Oriente).
  // Sources: only the Esri imagery (undated: buses in the bays, a canopy about 9 m deep that carries the office roof
  // south over the first row of bays, the canopies' pale panels) and six photos of buses entering the terminal
  // (Wikimedia Commons, JordiCuber, 2018-09, CC BY-SA 4.0: the liveries and the street front; no photo shows the
  // buildings). Approximate, therefore: every height (offices 7.6 m, the west wing 6.2, the market block 4.8, the
  // canopies 4.4-4.9 m), the facades (bays, the signs' colours: licence), the market block's roofs, the fence and its
  // gates' widths, and above all the buses: where they stand changes every minute; here, rows of the kind the imagery
  // shows (nose-in under the office canopy; along the island and the south platform). No lights: none documented.
  {const F=localFrame(1718.2,-235.7,0.8*Math.PI/180),{G,Gs,V,N3,R}=F;
    const K={wall:C('#D6CFBF'),wall2:C('#C4BDAD'),base:C('#A8A196'),white:C('#ECE7DC'),roof:C('#6F7173'),roof2:C('#65686A'),
      light:C('#B4B6B2'),sky:C('#A8B1B3'),glass:C('#3B4653'),glass2:C('#2C3540'),door:C('#5A4636'),
      can:C('#A9AEAE'),can2:C('#979C9D'),col:C('#4A4A4A'),asph:C('#65615D'),bays:C('#716D68'),line:C('#E8E4DA'),
      plat:C('#C8C2B4'),edge:C('#E2B33C'),fence:C('#B9B3A6'),hvac:C('#8F8C86'),tyre:C('#2E2D2C'),
      aw:[C('#E8E4DA'),C('#8DA7BC'),C('#E8E4DA'),C('#C9BFA8')],sign:[C('#3F8F4B'),C('#3C5FA8'),C('#B23B2E'),C('#E2B33C'),C('#2F7A8F')]};
    const BUS=[['#E8C23A','#3F8F4B'],['#E9E7E1','#3C5FA8'],['#E9E7E1','#B23B2E'],['#3C5FA8','#E9E7E1'],['#E9E7E1','#2F7A4F'],['#D8742B','#E9E7E1'],['#E9E7E1','#6B4C93'],['#E8C23A','#E9E7E1']].map(p=>p.map(C));
    const {box,WL,rect}=facade(S,F,K);
    const r=rng(8531);
    // walls of a counter-clockwise (u,v) ring from h0 to h1; col(i) picks each side's colour, a white cornice on top
    const walls=(ring,h0,h1,col,cor=true)=>{for(let i=0;i<ring.length;i++){const a=ring[i],b=ring[(i+1)%ring.length],L=Math.hypot(b[0]-a[0],b[1]-a[1]);
      if(L<.01)continue;const w=WL(a,b,[(b[1]-a[1])/L,-(b[0]-a[0])/L],0),c=typeof col==='function'?col(i):col;
      S.face([w.q(0,h0),w.q(L,h0),w.q(L,cor?h1-.5:h1),w.q(0,cor?h1-.5:h1)],w.n,c);if(cor)S.face([w.q(0,h1-.5),w.q(L,h1-.5),w.q(L,h1),w.q(0,h1)],w.n,K.white);}};
    const ccw=ring=>{let A=0;for(let i=0;i<ring.length;i++){const p=ring[i],q=ring[(i+1)%ring.length];A+=p[0]*q[1]-q[0]*p[1];}return A<0?ring.slice().reverse():ring;};
    // a facade of bays on the wall a->b (out: its outward direction): a plinth band, a window per bay between white
    // pilasters, a sign over each (storefronts), an upper ribbon of glass; bay: its width, sg: the signs' colours or 0
    const front=(a,b,out,o)=>{const w=WL(a,b,out,.06),wb=WL(a,b,out,.09),wp=WL(a,b,out,.12),L=w.L,n=Math.max(1,Math.round(L/(o.bay||4.5))),bw=L/n;
      rect(w,0,L,.3,o.sill,K.base);
      if(o.upper)for(let k=0;k<n;k++)rect(wb,k*bw+.6,(k+1)*bw-.6,o.upper[0],o.upper[1],k%2?K.glass2:K.glass);
      for(let k=0;k<n;k++){const s0=k*bw+.7,s1=(k+1)*bw-.7;rect(wb,s0,s1,o.sill,o.top,k%2?K.glass2:K.glass);
        if(o.signs)rect(wp,s0+.3,s1-.3,o.top+.25,o.top+1.25,K.sign[(k*3+(o.sd||0))%K.sign.length]);}
      for(let k=0;k<=n;k++)rect(wp,Math.max(0,k*bw-.3),Math.min(L,k*bw+.3),.3,o.cor-.5,K.white);};
    // the site (OSM's outline, simplified), its pad, the ground
    const SITE=ccw([[-13,-51],[19,-51],[20,-52],[53,-52],[74,-51],[75,7],[74,62],[24,61],[-13,61]]);
    const site=Gs(SITE);NOLOTS.push(site);occMark(site);
    const pad=padAt(Math.min(...site.map(p=>p[0])),Math.min(...site.map(p=>p[1])),Math.max(...site.map(p=>p[0])),Math.max(...site.map(p=>p[1])));S.dy=pad;
    S.flat(site,.3,K.asph);
    S.quadXY(R(9,-17,22,53),.33,K.bays);                                   // the first row of bays, under and past the office canopy
    for(let v=-15;v<=51;v+=3.6)S.quadXY(R(10,v-.25,21.5,v+.25),.36,K.line);   // the bays' lines
    // the office building along 2 Sur: two floors of storefronts and offices, a dark flat roof in bays of two tones with
    // a pale skylight band, a white cornice; the lower west wing is lighter and has a ribbon of windows
    box(-13,-51,6,-17,.3,6.2,K.wall,K.light);box(-13,-17,9,60,.3,7.6,K.wall,K.roof);
    for(let v=-15,k=0;v<60;v+=8,k++)S.quadXY(R(-12.6,v,8.6,Math.min(60,v+8)),7.63,k%2?K.roof2:K.roof);
    S.quadXY(R(-3,-14,-1,56),7.66,K.sky);S.quadXY(R(-11,-48,-9,-20),6.23,K.sky);
    front([9,-17],[9,60],[1,0],{sill:1,top:3.2,upper:[4.8,6.6],cor:7.6,bay:4.6,signs:1});
    front([6,-51],[6,-17],[1,0],{sill:1,top:3.2,upper:[4.4,5.4],cor:6.2,bay:4.6,signs:1,sd:2});
    front([-13,60],[-13,-17],[-1,0],{sill:1.2,top:2.8,upper:[4.8,6.6],cor:7.6,bay:5});          // the 2 Sur side: plainer, shop windows
    front([-13,-17],[-13,-51],[-1,0],{sill:1.2,top:2.6,cor:6.2,bay:5});
    front([-13,-51],[6,-51],[0,-1],{sill:1,top:3,cor:6.2,bay:4.2});
    front([9,60],[-13,60],[0,1],{sill:1,top:3,upper:[4.8,6.6],cor:7.6,bay:4.5});
    for(const [u,v] of [[-9,-8],[-9,12],[-9,32],[-9,48],[-5,-40]])box(u-1.5,v-1.5,u+1.5,v+1.5,u<-6&&v<-30?6.2:7.6,(u<-6&&v<-30?6.2:7.6)+1.5,K.hvac,K.wall2);
    // the office canopy: the roof carried south over the first row of bays on columns, a white fascia
    {const CU=18.5,v0=-17,v1=53,h=4.9;box(9,v0,CU,v1,h,h+.45,K.white,K.roof,true);
      for(let v=v0,k=0;v<v1-1e-6;v+=7,k++)S.quadXY(R(9,v,CU,Math.min(v1,v+7)),h+.48,k%2?K.roof2:K.roof);
      for(let v=v0+.5;v<=v1;v+=7)box(CU-.9,v-.25,CU-.4,v+.25,.3,h,K.col,K.col);}
    // the toilets at the building's east end, the kiosks along the east fence
    box(9,53,14,60,.3,3,K.wall2,K.light);box(24,58,28,61,.3,3,K.wall,K.roof);box(29,58,34,61,.3,3,K.wall,K.roof);box(36,57,47,61,.3,3.2,K.wall,K.roof);
    // the south-west block: the market-like shops (OSM's outline), walls with awnings, a roof of zinc bays in tones, the
    // passages' roofs (OSM's corridors, lit) paler
    const SW=ccw([[20,-52],[20,-34],[17,-34],[17,-12],[50,-12],[50,-8],[62,-8],[62,0],[75,0],[74,-14],[70,-14],[70,-22],[74,-22],[74,-33],[71,-35],[71,-37],[74,-37],[74,-51],[53,-52]]);
    walls(SW,.3,4.8,i=>i%2?K.wall:K.wall2);S.flat(Gs(SW),4.8,K.roof2);
    // the market passages' awnings (u 20-36, OSM's lit corridors), zinc gable roofs over the sheds east of them
    for(let v=-52,k=0;v<-12;v+=3.2,k++)S.quadXY(R(20,v,36,Math.min(-12,v+3.2)),4.86,K.aw[k%K.aw.length]);
    const zinc=facade(S,F,{...K,tile:K.can,tile2:K.can2,gable:K.wall});
    zinc.roof('v',-52,-13,36,53,4.8,2.4,6.5,[1,1]);zinc.roof('v',-52,-13,53,70,4.8,2.4,6.5,[1,1]);
    for(let i=0;i<SW.length;i++){const a=SW[i],b=SW[(i+1)%SW.length],L=Math.hypot(b[0]-a[0],b[1]-a[1]);if(L<8)continue;
      const out=[(b[1]-a[1])/L,-(b[0]-a[0])/L];
      const w=WL(a,b,out,.08);for(let s=1.5,k=i;s<L-3.5;s+=4,k++){rect(w,s,s+3,.3,2.6,K.glass2);rect(WL(a,b,out,.12),s-.2,s+3.2,2.6,3.1,K.aw[k%K.aw.length]);}}
    // the island: a raised platform under a canopy of pale panels (OSM w1420052919: u 33-42, v 1-52), two rows of
    // columns, a yellow edge
    box(31,0,44,53,.3,.55,K.plat,K.plat);
    for(const u of [31.25,43.75])S.quadXY(R(u-.25,0,u+.25,53),.58,K.edge);
    {const h=4.6;box(32.7,1,42.4,52,h,h+.4,K.white,K.can,true);
      for(let v=1,k=0;v<52-1e-6;v+=6.4,k++)S.quadXY(R(32.9,v,42.2,Math.min(52,v+6.4)),h+.43,k%2?K.can2:K.can);
      for(let v=1.5;v<=51.6;v+=6.4)for(const u of [34.2,40.9])box(u-.25,v-.25,u+.25,v+.25,.55,h,K.col,K.col);}
    // the south platform (w1420052914 canopy, w1420052913 back building)
    box(63.5,6,71,56,.3,.55,K.plat,K.plat);S.quadXY(R(63.25,6,63.75,56),.58,K.edge);
    {const h=4.4;box(65,7,71,55,h,h+.4,K.white,K.can,true);
      for(let v=7,k=0;v<55-1e-6;v+=6,k++)S.quadXY(R(65.2,v,70.8,Math.min(55,v+6)),h+.43,k%2?K.can2:K.can);
      for(let v=7.5;v<=54.6;v+=6)box(65.4,v-.25,65.9,v+.25,.55,h,K.col,K.col);
      box(71,7,75,62,.3,5.4,K.wall,K.light);
      front([71,55],[71,7],[-1,0],{sill:1,top:3.2,cor:5.4,bay:4.8,signs:1,sd:1});
      front([75,7],[74,62],[1,0],{sill:1,top:3,cor:5.4,bay:5});}
    // the fence along the east side and the west gate, with the gates' gaps (OSM nodes: u 21 and 52.6 east, 14.5 west; the kiosks stand along the rest)
    const fence=(a,b)=>{const L=Math.hypot(b[0]-a[0],b[1]-a[1]),out=[(b[1]-a[1])/L,-(b[0]-a[0])/L],w=WL(a,b,out,0),w2=WL(a,b,[-out[0],-out[1]],0);
      S.face([w.q(0,.3),w.q(L,.3),w.q(L,1.9),w.q(0,1.9)],w.n,K.fence);S.face([w2.q(0,.3),w2.q(L,.3),w2.q(L,1.9),w2.q(0,1.9)],w2.n,K.fence);
      S.face([w.q(0,1.9),w.q(L,1.9),w.q(L,2.4),w.q(0,2.4)],w.n,K.white);};
    for(const [a,b] of [[[17,60.6],[9,60.6]],[[65,60.6],[56.6,60.6]],[[6,-50.6],[10.5,-50.6]],[[18.5,-50.6],[20,-50.6]]])fence(a,b);
    // the buses: a dark skirt, a body, a band of glass and a stripe; nose-in under the office canopy (first row),
    // along the island and along the south platform. th: the long axis' angle from u (0: nose to the office)
    const bus=(cu,cv,len,th,p,h=3.3)=>{const c=Math.cos(th),s=Math.sin(th),hl=len/2,q=(l,w)=>Gs([[-l,-w],[l,-w],[l,w],[-l,w]].map(([a,b])=>[cu+a*c-b*s,cv+a*s+b*c]));
      S.prism(q(hl-.5,1),.32,.9,K.tyre,K.tyre,false);S.prism(q(hl,1.3),.9,h,p[0],K.white);
      S.prism(q(hl+.04,1.34),1.0,1.5,p[1],p[1],false);S.prism(q(hl+.04,1.34),1.8,2.7,K.glass,K.glass,false);};
    const pickBus=()=>BUS[Math.floor(r()*BUS.length)];
    for(let v=-13.2;v<=50;v+=3.6){if(r()<.22)continue;const len=r()<.3?9.4:11.8;bus(10.6+len/2+(r()<.5?0:.6),v+(r()-.5)*.5,len,(r()-.5)*.1,pickBus());}
    for(const [u,th,vs] of [[28.6,Math.PI/2-.12,[9,23,37,50]],[46.2,Math.PI/2+.12,[8,22,36,50]],[60,Math.PI/2-.08,[14,29,44]]])
      for(const v of vs){if(r()<.2)continue;bus(u,v+(r()-.5)*2,r()<.25?9.4:11.8,th+(r()-.5)*.06,pickBus());}
    for(const [u,v] of [[23,-44],[29,-44],[35,-46]])bus(u,v,6.8,Math.PI/2,[C('#3C5FA8'),C('#E9E7E1')],2.9);   // blue micros waiting at the west gate
    const c=G(31,5);MODELS['terminal-buses']={x:c[0],y:c[1],h:12};S.dy=0;}
