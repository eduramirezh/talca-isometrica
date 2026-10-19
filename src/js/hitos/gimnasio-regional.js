  // ==== hito: gimnasio-regional ====
  // Gimnasio Regional de Talca (since 2022 «Manuel Herrera Blanco»), the region's main roofed arena (basketball, shows;
  // ~4,000–5,000 seats), on S. The footprint is OpenStreetMap's (building w89114822, leisure=stadium; site w110587869,
  // leisure=sports_centre: the two land uses the generic layer drew here are skipped because the site is reserved in occ):
  // a 12-vertex star that fits a 6-fold figure (tips r 37.9 m at 8.7° + 60°·k, valleys r 34.3 m between them; least
  // squares on the 12 nodes). Frame: origin at the roof's centre, u east and v north (A = 90°), so a polar point is
  // (r cos a, r sin a). The roof (Esri imagery of 2015-03-31, z19 rotated: satellite.py marco 2358.4 198.3 90 …): 12 radial
  // facets from a small hexagonal lantern to the eaves, which rise at the 6 tips and fall at the 6 valleys (the zigzag
  // eave of the 2005 photo File:Talca gimnasio.jpg, Commons, public domain, and of the steel frame in File:Gimnasio
  // regional.jpg, 2013-08-21, CC BY-SA 3.0 Daniel Vásquez Guajardo, taken while the works of tender 2295-27-LP12 of the
  // Gobierno Regional del Maule were under way, awarded 2012-07-25). Six low entrance wings at the tips, a hexagonal
  // ring road, a parking lot to the north with its tree islands, lawns with gravel paths, round red kiosks and the tree
  // belts: all read from the 2015 imagery (the lot, lawns and kiosks may have changed). Walls (light stucco, white-framed
  // glass) follow the plaque photo of 2023 (vlnradio.cl) and the 2005 photo. Approximate: the heights (eaves 15 m at the
  // valleys and 18 m at the tips, lantern 22 m, from the 2013 frame photographed from a valley side: ~6 px/m against the
  // 75 m tip-to-tip span), the roof's colour (slate blue-grey: the satellite shows blue, the 2013 frame is bare steel),
  // the number and depth of the glazed bays, the wings' function and height, the kiosks' use. No lights: nothing says
  // the site is lit. Method: docs/METODOLOGIA.md §9.
  {const X=2358.41,Y=198.42,F=localFrame(X,Y,Math.PI/2),{G,Gs,V,N3}=F; // A = 90°: G(u,v) = [X + u, Y + v]
    const K={asph:C('#65615D'),asph2:C('#57534F'),lawn:C('#97AA5E'),lawn2:C('#8DA056'),gravel:C('#D8C69C'),sand:C('#C9B38A'),pad:C('#CFC7B0'),
      wall:C('#D8D3C6'),pil:C('#C4BEB0'),zoc:C('#B9B3A5'),plinth:C('#BDB7AA'),plinthT:C('#D3CDBF'),white:C('#EFEBE0'),
      glass:C('#4D5D66'),glass2:C('#3B4653'),roofA:C('#566A8A'),roofB:C('#465878'),hub:C('#D9D6CE'),hubT:C('#ECEAE3'),
      wing:C('#E7E2D6'),door:C('#4A3F3A'),kiosk:C('#B5524A'),kioskT:C('#9F4540'),shed:C('#6F6B64'),shedT:C('#3F4448')};
    const A0=8.7*Math.PI/180,RT=37.9,RV=34.3,HF=.3,HT=18,HV=15,HH=22,WS=.965; // HF floor, HT/HV eave at tips/valleys, HH lantern (above the floor)
    const pol=(r,a)=>[r*Math.cos(a),r*Math.sin(a)],ang=i=>A0+i*Math.PI/6,eave=i=>HF+(i%2?HV:HT);
    const OUT=[];for(let i=0;i<12;i++)OUT.push(pol(i%2?RV:RT,ang(i)));
    const HUB=[];for(let i=0;i<12;i++)HUB.push(pol(i%2?4.95:5.7,ang(i)));
    // the site (w110587869) and the ring road, in (u, v)
    const SITE=[[2330,131],[2360,115],[2388,118],[2437,244],[2452,282],[2381,309],[2379,310],[2308,337],[2268,201],[2285,182]];
    const RING=[[-61,0],[-60,-30],[-42.5,-42.5],[-25,-54],[7.5,-56],[39,-46],[50,-22.5],[65,0],[62,10],[50,20],[35,45],[25,54],[7.5,57.5],[-22,53],[-46,32.5]];
    const LOT=[[-47,133],[17,109.5],[62,91],[50,87],[40,82],[36,67.5],[17.5,62.5],[1,58],[-17.5,72.5],[-35,76],[-41,75],[-51,90],[-55,110]];
    const LAWNS=[ // [polygon, tone]: west strip along the fence, the lawn north of the ring, the east strip, south of the ring
      [[[-90,3],[-50,139],[-45,133],[-56,105],[-52,88],[-60,60],[-58,20],[-72,-6]],0],
      [[[-35,76],[-17.5,72.5],[1,58],[-3,55],[-30,56],[-36,62]],1],
      [[[40,81],[52.5,86],[54,75],[45,57.5],[39,41],[31,46],[36,65]],0],
      [[[-33,-62],[-8,-58],[32,-56],[33,-70],[10,-80],[-20,-77]],1]];
    const SANDS=[[[45,72],[60,70],[58,45],[42,44]]];
    const PADS_=[[[-54,-8],[-40,-8],[-38,-17],[-52,-19]],[[36,3],[50,6],[48,-4],[36,-6]]];
    const PATHS=[[[-85,10],[-60,75]],[[-60,15],[-82,60]],[[-32,70],[-8,57]],[[-24,74],[-12,57]],[[-20,-60],[5,-72]],[[10,-58],[18,-78]]];
    const ring=SITE; // grid metres
    // the footprint: the whole site is reserved (the generic sports layer is skipped), the pavement and the building marked
    occFill(ring,2.5);
    streets.forEach(s=>{if(s.c===7&&s.pts.filter(p=>pip(p,ring)).length*2>=s.pts.length)s.bridge=true;});
    const gOUT=Gs(OUT);occMark(Gs(RING));occMark(Gs(LOT));occMark(gOUT);
    // level the ground under the building and its wings (nodes every 40 m: the ring road lies on the plateau); the pad is
    // applied while this block is drawn so that drape() and the lot see the final terrain, and undone after (applyPads
    // runs later for everyone)
    const gx0=Math.min(...gOUT.map(p=>p[0]))-3,gx1=Math.max(...gOUT.map(p=>p[0]))+3,gy0=Math.min(...gOUT.map(p=>p[1]))-3,gy1=Math.max(...gOUT.map(p=>p[1]))+3;
    S.dy=padAt(gx0,gy0,gx1,gy1);const keepEH=EH.slice();applyPads();
    // ---- the ground, draped on the terrain
    {const Lg=new GB(1<<15),lay=(q,o,c)=>{if(q.length>2)Lg.flat(q,o,c);};
      for(const [q,t] of LAWNS)lay(Gs(q),.11,t?K.lawn2:K.lawn);
      for(const q of SANDS)lay(Gs(q),.11,K.sand);
      lay(Gs(RING),.12,K.asph);lay(Gs(LOT),.13,K.asph);
      // the car way from the lot's corner to the ring (the map's track, now a landmark's) and the east gate
      ribbon(Lg,[[2398,295],[2378,247]],7,.14,K.asph);ribbon(Lg,[[2416,202],[2436,198]],6,.14,K.asph);
      for(const q of PADS_)lay(Gs(q),.14,K.pad);
      for(const p of PATHS)ribbon(Lg,p.map(a=>G(a[0],a[1])),1.6,.14,K.gravel);
      const d=drape(Lg);const sv=S.dy;S.dy=0;
      for(let t=0;t<d.ni;t+=3){const k=d.I[t]*3;S.face([0,1,2].map(j=>{const m=d.I[t+j]*3;return [d.P[m],d.P[m+1],d.P[m+2]];}),[0,1,0],[d.C[k],d.C[k+1],d.C[k+2]]);}S.dy=sv;}
    // ---- the building. Faces with an explicit normal; up(): a normal with its y > 0 from the triangle itself
    const up=(a,b,c,col)=>{const ux=b[0]-a[0],uy=b[1]-a[1],uz=b[2]-a[2],vx=c[0]-a[0],vy=c[1]-a[1],vz=c[2]-a[2];let n=[uy*vz-uz*vy,uz*vx-ux*vz,ux*vy-uy*vx];
      const L=Math.hypot(...n)||1;n=n.map(x=>x/L);if(n[1]<0)n=n.map(x=>-x);S.face([a,b,c],n,col);};
    // unit normal (u, v) of the chord a→b, pointing away from the centre
    const chordN=(a,b)=>{let n=[b[1]-a[1],a[0]-b[0]];const L=Math.hypot(n[0],n[1])||1;n=[n[0]/L,n[1]/L];return n[0]*(a[0]+b[0])+n[1]*(a[1]+b[1])<0?[-n[0],-n[1]]:n;};
    // plinth: a step of concrete around the walls
    {const q=Gs(OUT.map(p=>[p[0]*.99,p[1]*.99]));S.prism(q,HF,HF+.65,K.plinth,K.plinthT,false);S.flat(q,HF+.65,K.plinthT);} // concave: flat() triangulates it
    // roof: 12 radial facets from the lantern, two triangles each (the eaves differ in height), two tones
    for(let i=0;i<12;i++){const j=(i+1)%12,c=i%2?K.roofB:K.roofA,P=k=>V(OUT[k][0],OUT[k][1],eave(k)),H=k=>V(HUB[k][0],HUB[k][1],HF+HH);
      up(H(i),P(i),P(j),c);up(H(i),P(j),H(j),c);
      // fascia: a white band along the zigzag eave, a hand's breadth proud of the roof's edge
      const a=OUT[i],b=OUT[j],cn=chordN(a,b);
      S.face([V(a[0]+cn[0]*.05,a[1]+cn[1]*.05,eave(i)),V(b[0]+cn[0]*.05,b[1]+cn[1]*.05,eave(j)),V(b[0]+cn[0]*.05,b[1]+cn[1]*.05,eave(j)-.9),V(a[0]+cn[0]*.05,a[1]+cn[1]*.05,eave(i)-.9)],N3(cn[0],cn[1]),K.white);}
    // lantern: a hexagonal drum with a pale flat top
    S.prism(Gs(HUB),HF+HH,HF+HH+1.5,K.hub,K.hubT);
    // walls: light stucco up to the eaves, a dark plinth strip, and glazed bays between white mullions
    for(let i=0;i<12;i++){const j=(i+1)%12,a=OUT[i].map(x=>x*WS),b=OUT[j].map(x=>x*WS),cn=chordN(a,b),n=N3(cn[0],cn[1]),
        ha=eave(i)+.3,hb=eave(j)+.3,L=Math.hypot(b[0]-a[0],b[1]-a[1]),
        PT=(s,h,o=0)=>{const t=s/L;return V(a[0]+(b[0]-a[0])*t+cn[0]*o,a[1]+(b[1]-a[1])*t+cn[1]*o,h);},
        top=s=>ha+(hb-ha)*s/L;
      S.face([V(a[0],a[1],-1),V(b[0],b[1],-1),V(b[0],b[1],hb),V(a[0],a[1],ha)],n,K.wall);
      S.face([PT(0,HF+.65,.06),PT(L,HF+.65,.06),PT(L,HF+1.6,.06),PT(0,HF+1.6,.06)],n,K.zoc);
      const nb=4,bw=(L-1.4)/nb;
      for(let k=0;k<nb;k++){const s0=.7+k*bw+.25,s1=.7+(k+1)*bw-.25;
        S.face([PT(s0,6,.08),PT(s1,6,.08),PT(s1,top(s1)-2,.08),PT(s0,top(s0)-2,.08)],n,(i+k)%2?K.glass2:K.glass);}
      // white band under the fascia, over the glass
      S.face([PT(0,top(0)-1.6,.09),PT(L,top(L)-1.6,.09),PT(L,top(L)-.9,.09),PT(0,top(0)-.9,.09)],n,K.white);
      // pilaster at the vertex
      const pa=G(a[0]*1.01,a[1]*1.01);S.prism(rotRect(pa[0],pa[1],1.3,1.3,ang(i)),HF,ha,K.pil,K.pil);}
    // ---- six entrance wings at the tips (radial, 17 × 9 m, low flat roof with a white coping), taller at the NE and NW
    for(let k=0;k<6;k++){const a=ang(2*k),c=G(...pol(44,a)),h=(k===1||k===2)?5.6:4.4,wq=rotRect(c[0],c[1],17,9,a),cq=rotRect(c[0],c[1],17.6,9.6,a);
      S.prism(wq,HF,h,K.wall,K.wall,false);S.prism(cq,h,h+.4,K.white,K.wing);
      const e=G(...pol(52.5+.06,a)),tx=-Math.sin(a),ty=Math.cos(a),nn=N3(Math.cos(a),Math.sin(a));
      for(const [o0,o1,col] of [[-2.2,-.2,K.glass],[.2,2.2,K.glass],[-.2,.2,K.door]])
        S.face([[e[0]+tx*o0,HF,-(e[1]+ty*o0)],[e[0]+tx*o1,HF,-(e[1]+ty*o1)],[e[0]+tx*o1,HF+2.8,-(e[1]+ty*o1)],[e[0]+tx*o0,HF+2.8,-(e[1]+ty*o0)]],[Math.cos(a),0,-Math.sin(a)],col);}
    // round red kiosks around the walls and a dark shed in the south-west corner of the lawn
    for(const [u,v] of [[-15,33.7],[-.5,35.7],[23,25.7],[32.5,15.7],[35.7,-10.7],[30.7,-23.7]]){const g=G(u,v);S.prism(ngon(g[0],g[1],2.2,10),HF,2.9,K.kiosk,K.kioskT);}
    {const g=G(-40,-60);S.prism(rotRect(g[0],g[1],12,5,-47*Math.PI/180),HF,3.2,K.shed,K.shedT);}
    // east gate: two white piers
    for(const o of [-3.4,3.4]){const g=[2423+0,200+o];S.prism(rotRect(g[0],g[1],1,1,0),HF,3.2,K.white,K.white);}
    // ---- trees where the imagery shows them: the lot's islands, the east and south-east belts, a few on the lawns
    {const rr=rng(7141),inR=(u,v)=>pip(G(u,v),ring)&&!pip([u,v],RING)&&!pip([u,v],LOT),t=(u,v,s)=>{const p=G(u,v);if(inTerrain(p[0],p[1]))TREES.push([p[0],p[1],s,rr()]);};
      for(const [u,v] of [[-34.5,122.5],[-19,115.5],[-42,102.5],[-26,95.5],[-4,108],[-11,91],[29.5,94],[22.5,77.5]])t(u,v,1.0+rr()*.25);
      const grove=(poly,n,s0)=>{let k=0,bb=[1e9,1e9,-1e9,-1e9];for(const p of poly){bb=[Math.min(bb[0],p[0]),Math.min(bb[1],p[1]),Math.max(bb[2],p[0]),Math.max(bb[3],p[1])];}
        for(let g=0;g<n*40&&k<n;g++){const u=bb[0]+rr()*(bb[2]-bb[0]),v=bb[1]+rr()*(bb[3]-bb[1]);if(pip([u,v],poly)&&inR(u,v)){t(u,v,s0+rr()*.5);k++;}}};
      grove([[60,105],[88,80],[86,50],[76,35],[64,45],[58,70]],26,1.4);
      grove([[52,-8],[62,-4],[58,-25],[44,-52],[34,-60],[36,-40],[48,-20]],14,1.4);
      grove([[-80,-10],[-72,-14],[-40,-50],[-34,-62],[-44,-60],[-70,-30]],8,1.3);
      for(const [u,v] of [[-60,30],[-68,48],[-56,70],[-48,100],[-56,-6],[26,-78],[-4,-84]])t(u,v,1.2+rr()*.3);}
    MODELS['gimnasio-regional']={x:X,y:Y,h:HF+HH+1.6};
    EH.set(keepEH);S.dy=0;}
