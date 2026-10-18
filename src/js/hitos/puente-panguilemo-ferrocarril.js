  // ==== hito: puente-panguilemo-ferrocarril ====
  // The Línea Central over the Estero Pangue where the Estero Las Chilcas joins it, at the commune's northern limit,
  // 150 m east of the Ruta 5's bridges: two bridges side by side, of which only the southern halves lie in the commune.
  // - The old one, 11 m west (OSM w166664024, railway=abandoned, 74 m; node n4289189189 «Puente de Alto Pangue»): the
  //   Monumento Histórico «Puente Ferroviario sobre el Río Pangue» (D.S. 499 of 1989, CMN 00478_MH_MT; Wikidata
  //   Q42898047). The decree: about 60 m long, built c. 1878–80, eight semicircular («de medio punto») arches of brick
  //   masonry, rendered up to the arches' impost on the piers and on the abutments with stucco that imitates ashlar;
  //   «the only one of its type still standing» in Chile. Commons «Puente Pangue.JPG» (2008, CC BY 3.0) and the CMN's
  //   photos of 2017 (consulted only) show the brick arches, the piers with pilasters up to a cornice, the stucco
  //   piers. Drawn so: the eight arches over the middle 60 m of OSM's way, stepped (0.5 m columns, a ring in the
  //   second tone), piers in stucco up to the impost, pilasters and cornice in brick, an earth top; the abutment in the
  //   bank; ends on the last pier inside the commune, with the cut section closed.
  // - The line's, which carries the electrified track (OSM w101547234, 47 m): a steel deck truss painted pale yellow
  //   (the 2008 photo and the CMN's) on concrete piers, its deck about 3 m above the old one's, and a concrete approach
  //   span with a balustrade at its south end (the CMN's photo from under it). Drawn with deckBridge (deck, steel
  //   railing; the approach with balusters), railGirder's Warren deck truss and railPiers (concrete).
  // The heights are the map's, not the real ones (the estero runs ~12 m under the new deck, in a ravine the 40 m relief
  // does not have): the old top 5.6 m over the water, the new deck 3.2 m over it, so that the line rises to it on a
  // short embankment (railBase). Approximate: the arches' place along OSM's way, the approach's length (8 m), the truss's
  // panels and the colours.
  {const K={ballast:PAL.ballast,par:C('#C2AF72'),old:C('#BDBBB4'),old2:C('#A9A7A0'),beam:C('#A9A7A0'),steel:C('#D6C487'),steel2:C('#C2AF72'),stone:C('#BDBBB4'),stone2:C('#A9A7A0')};
    const KV={brick:C('#9A5B44'),brick2:C('#84493A'),stucco:C('#B9A68E'),stucco2:C('#A8957E'),top:C('#8E8A62')};
    const a=[7523.1,8820.4],b=[7531.0,8842.5]; // b: the middle of OSM's bridge, ~3 m inside the limit
    const da=[(b[0]-a[0])/Math.hypot(b[0]-a[0],b[1]-a[1]),(b[1]-a[1])/Math.hypot(b[0]-a[0],b[1]-a[1])],a0=[a[0]-da[0]*8,a[1]-da[1]*8];
    // the old viaduct: frame along OSM's way, module of 7.5 m (8 arches in 60 m), piers 1.4 m, half width 2.5 m
    const A=[7503.4,8803.3],B=[7531.2,8871.5],VL=Math.hypot(B[0]-A[0],B[1]-A[1]),vx=(B[0]-A[0])/VL,vy=(B[1]-A[1])/VL,ang=Math.atan2(vy,vx);
    const M=7.5,PW=1.4,R=(M-PW)/2,HW=2.5,T0=(VL-8*M)/2,at=(t,n)=>[A[0]+vx*t-vy*n,A[1]+vy*t+vx*n];
    let n=0;while(n<8&&inTerrain(...at(T0+(n+1)*M+PW/2,0)))n++;            // the arches wholly inside the commune
    let Ew=1e9;for(let t=T0;t<=T0+n*M;t+=2)Ew=Math.min(Ew,E(...at(t,0)));
    const HV=Ew+6.5,HI=HV-.95-R,H=HV+3;                                        // old top, impost, the new deck
    const bL=[b[0]+da[0]*6,b[1]+da[1]*6];                                    // the lift goes on past the limit: no ramp hanging off it
    RAIL_BR.push({line:'main',a:a0,b:bL,hb:H-Math.max(E(...a0),E(...bL)),draw:(G,hAt)=>{
      deckBridge(G,K,[a0,a],2.8,hAt,{deck:K.ballast,beamD:1,beamCol:K.beam,balus:true,pier:1e9});
      deckBridge(G,{...K,old:K.steel},[a,b],2.8,hAt,{deck:K.ballast,beamD:.45,beamCol:K.steel2,pier:1e9});
      railGirder(G,K,a,b,2.8,hAt,{warren:3});
      railPiers(G,K,a0,a,2.8,hAt,{spans:1,beamD:1});railPiers(G,K,a,b,2.8,hAt,{spans:1,beamD:3.1,cut:true,open:true});
      // the viaduct, on the final ground (railBase runs after the pads)
      const V=(t,o,h)=>{const p=at(t,o);return [p[0],h,-p[1]];},Nn=s=>[-vy*s,0,-vx*s],Nt=s=>[vx*s,0,-vy*s];
      const wall=(t0,t1,h0,h1,col)=>{for(const s of [1,-1])G.face([V(t0,s*HW,h0),V(t1,s*HW,h0),V(t1,s*HW,h1),V(t0,s*HW,h1)],Nn(s),col);};
      const tE=T0+n*M+PW/2,box=(t0,t1,w,h0,h1,c,ct)=>{const q=rotRect(...at((t0+t1)/2,0),t1-t0,w,ang);G.prism(q,h0,h1,c,ct||c);};
      // the abutment (3 m) and, behind it, the abandoned line's embankment down to the ground at 1:10
      const tA=T0-PW/2-3,bk=[C('#A4A273'),C('#999767')];
      for(let t=tA,h=HV-.35;t>tA-60;t-=2,h-=.2){const g0=E(...at(t,0)),g1=E(...at(t-2,0));if(h<Math.min(g0,g1)+.1)break;
        G.face([V(t,-HW,h),V(t,HW,h),V(t-2,HW,h-.2),V(t-2,-HW,h-.2)],null,KV.top);
        for(const s of [1,-1]){const o0=s*(HW+1.5*Math.max(0,h-g0)),o1=s*(HW+1.5*Math.max(0,h-.2-g1));
          G.face([V(t,s*HW,h),V(t-2,s*HW,h-.2),V(t-2,o1,E(...at(t-2,o1))-.05),V(t,o0,E(...at(t,o0))-.05)],null,bk[Math.floor(t/4)&1]);}
        occMark(rotRect(...at(t-1,0),2,2*HW+3*Math.max(0,h-g0)+1,ang));}
      box(tA,T0-PW/2,2*HW+.6,Math.min(E(...at(tA,0)),E(...at(T0,0)))-.6,HV-.35,KV.stucco);
      for(let k=0;k<=n;k++){const t=T0+k*M,g=E(...at(t,0));
        box(t-PW/2,t+PW/2,2*HW+.6,g-.6,HI-.3,KV.stucco);box(t-PW/2-.1,t+PW/2+.1,2*HW+.7,HI-.3,HI,KV.stucco2);
        box(t-.4,t+.4,2*HW+.5,HI,HV-.35,KV.brick2);wall(t-PW/2,Math.min(t+PW/2,tE),HI,HV-.35,KV.brick);}
      for(let k=0;k<n;k++){const c=T0+k*M+M/2,nc=Math.round(2*R/.5);
        for(let j=0;j<nc;j++){const u0=c-R+j*2*R/nc,u1=u0+2*R/nc,m=(u0+u1)/2-c,hi=HI+Math.sqrt(Math.max(0,R*R-m*m));
          wall(u0,u1,hi,hi+.6,KV.brick2);wall(u0,u1,hi+.6,HV-.35,KV.brick);}}
      box(tA,tE,2*HW+.6,HV-.35,HV,KV.brick2,KV.top);
      G.face([V(tE,-HW,HI),V(tE,HW,HI),V(tE,HW,HV-.35),V(tE,-HW,HV-.35)],Nt(1),KV.brick2);   // the cut, at the limit
      for(let t=tA;t<tE;t+=3)occMark(rotRect(...at(Math.min(t+1.5,tE),0),3,2*HW+3,ang));}});}
