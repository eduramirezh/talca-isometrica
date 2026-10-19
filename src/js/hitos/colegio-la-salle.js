  // ==== hito: colegio-la-salle ====
  // Colegio De La Salle (1 Oriente 1481), the whole block between 3 Norte, the Alameda, 1 Poniente and 1 Oriente, on S
  // (unlisted: it has no card). Grounds from OpenStreetMap's school w111123029 (the land-use layer's "educacional" entry,
  // skipped because this footprint is reserved in occ; the block is `generar` in config/edificios.json, so its OSM
  // buildings are not drawn as plain slabs). Buildings from OSM: the L of the east and south wings w664947884, the
  // E-shaped west building w952226021, the gym w664947885 and the three-storey north-east block w664947886. The rest is
  // read from the Esri imagery (satellite.py marco 0 0 90 …: u = grid x, v = grid y; z18–19 is of 2015-03-31, the z17
  // captures of 2010, 2011, 2015, 2016, 2018, 2019 and 2020 show the same buildings): the gabled two-storey wing on the
  // west side of the courtyard, the 4 m north wing that closes it (it stops 5 m short of the east wing), the asphalt yard
  // with its four courts (two columns of 14 × 25 m) and the trees along its east side, the hipped roof of the north-east
  // block, the 4 × 10 m cross wing into the yard, the green-roofed range of the west building, the gabled hall and the
  // low annex in the south-west corner, the garden on the Alameda. The courts were painted blue and red between
  // 2015-03 and 2016-12.
  // The school's own site (lasalletalca.cl, "Historia de nuestro colegio"; looked at, not redistributed) dates it: founded
  // in 1911, on this block from 1913, the whole block theirs in 1930; the 1 Oriente and 3 Norte wings rebuilt after the
  // earthquakes of 1939 and 1960; the chapel 1944; the Alameda–1 Oriente pavilion (the north-east block) 1954; an Olympic
  // pool 1961; the dining hall in the 1980s–93 and the gym (frame 1993, finished 2002). Its cover photo (the yard seen
  // from the west wing, undated) gives the east wing's yard face: cream walls, a salmon dado, windows 1.5 m wide on a
  // ~2.5 m pitch, grey standing-seam zinc roofs, the cross wing with a maroon plinth, a niche with the founder's statue and
  // tall windows, the two galvanised stairs under zinc canopies that climb to it from both sides, the blue court with
  // its red border next to the grey asphalt, and the hoops on bent arms. Commons has no photo of the school.
  // STILL GUESSED: the colours and windows of the street faces and of every other wing (the photo's rhythm is repeated;
  // the storey, 3.8 m, is its scale; OSM's height tags are the import's 2.8 m a storey), the zinc's tone, the gym's
  // height and walls, the railing on the Alameda, and what the walled patio south of the E-shaped building is: a tan floor
  // and a pale-blue rectangle, the same in every capture (drawn as a pool; it may be a glazed roof over a drained one); the
  // hall of the south-west corner (11 × 15 m, a gable roof) may be the chapel. The photo's tan shed on the yard's right is
  // not drawn: nothing in the imagery says where it stands. The model's relief falls ~12 m across the block (from the
  // Alameda, where the Teatro's and La Victoria's pads hold it at +5 m, to the south-west corner), so there is no pad:
  // the pads already registered are applied to the terrain while this block is drawn (and undone after, applyPads
  // does it again), every building stands on the final ground in steps of up to ~2.5 m (the step's gable in the darker
  // wall tone; the cross wing and the stairs take the east wing's step), and the ground is draped on it.
  {const F=localFrame(0,0,Math.PI/2),{G,Gs,V,N3,R}=F,keepEH=EH.slice();applyPads();
    const K={wall:C('#EEE7D3'),wall2:C('#E0D7C0'),plinth:C('#B9B2A2'),dado:C('#D98E70'),maroon:C('#80504A'),white:C('#F3EEE2'),glass:C('#3B4653'),glass2:C('#2C3540'),door:C('#5A4636'),
      blue:C('#2F4F8F'),tile:C('#B4BABC'),tile2:C('#A2A9AC'),flat:C('#A9ACAA'),greenR:C('#5F8A64'),greenR2:C('#7FA37A'),skylight:C('#A9C3C6'),
      gym:C('#E4E0D6'),asph:C('#8E9399'),line:C('#F3F0E6'),cblue:C('#33559F'),cred:C('#C0483A'),cred2:C('#A53A30'),deck:C('#C9B58C'),pool:C('#8EC3CB'),pave:C('#D8D1C1'),pave2:C('#CCC4B2'),sand:C('#D6C59A'),
      lawn:C('#8FA85A'),lawn2:C('#7FA14F'),iron:C('#3A3A3A'),mast:C('#707070'),steel:C('#BFC4C5'),steel2:C('#A5ABAD'),rail:C('#D3D7D7'),stone:C('#CDBFA6'),ring:C('#D8662A'),lamp:C('#F4E3A6')};
    const {WV,WU,rect,roof}=facade(S,F,{...K,gable:K.wall}),roofG=facade(S,F,{...K,tile:K.greenR,tile2:K.greenR2,gable:K.wall2}).roof;
    const SITE=[[-60,470],[-58,350],[-10,348],[-10,347],[46,346],[52,350],[52,468],[49,471]];
    NOLOTS.push(Gs(SITE));occFill(Gs(SITE),2.5);
    // ground: paving under all (0.11), the asphalt yard with its courts, the garden on the Alameda, lawns and the
    // south-west garden; draped on the final terrain, copied to S facing up (EN() is still zero here)
    {const Lg=new GB(1<<12),lay=(q,o,c)=>Lg.flat(Gs(q),o,c),box=(u0,v0,u1,v1)=>[[u0,v0],[u1,v0],[u1,v1],[u0,v1]];
      lay(SITE,.11,K.pave);lay(box(2,359,39,443),.13,K.asph);
      // the north row of courts is painted blue inside a red border whose south edge alternates two reds (the school's
      // photo); the south row stays grey asphalt. Lines are 0.5 m, white, on both rows
      lay(box(2.4,410.2,36.6,442.2),.15,K.cred);lay(box(3.6,411.4,35.4,441),.17,K.cblue);
      for(let i=0;i<29;i+=2){const u=2.4+i*1.2;lay(box(u,410.2,Math.min(u+1.2,36.6),411.4),.16,K.cred2);}
      for(const [u0,v0] of [[3.5,413.5],[18.5,413.5],[3.5,384],[18.5,384]]){
        for(const b of [[u0,v0,u0+14,v0+.5],[u0,v0+25,u0+14,v0+25.5],[u0,v0,u0+.5,v0+25.5],[u0+13.5,v0,u0+14,v0+25.5],[u0,v0+12.5,u0+14,v0+13]])lay(box(...b),.19,K.line);}
      lay(box(-18,447,38,469),.13,K.lawn);lay(box(-57,425,-21,434),.13,K.lawn2);lay(box(-58,351,-29,372),.13,K.lawn2);lay(box(-54,392,-18,402),.13,K.pave2);
      // the walled patio south of the E-shaped building: a tan floor and a pale-blue rectangle in its east half (a pool or a
      // glazed roof: the same in every capture from 2010 to 2020)
      lay(box(-54,383,-21,392),.13,K.deck);lay(box(-38.7,384.5,-23.2,391.7),.15,K.line);lay(box(-38.2,385,-23.7,391.2),.17,K.pool);
      // the garden's sand plaza: a square turned 45° and the walks to the gate and the wings
      lay([[17,449],[25,457],[17,465],[9,457]],.15,K.sand);lay(box(15.5,457,18.5,469),.16,K.sand);lay(box(-8,455.5,38,458.5),.16,K.sand);
      const d=drape(Lg);S.dy=0;
      for(let t=0;t<d.ni;t+=3){const k=d.I[t]*3;S.face([0,1,2].map(j=>{const m=d.I[t+j]*3;return [d.P[m],d.P[m+1],d.P[m+2]];}),[0,1,0],[d.C[k],d.C[k+1],d.C[k+2]]);}}
    // windows: nst storeys of windows 1.5 m wide and 1.9 high every ~2.5 m (read from the school's photo of the east wing's
    // yard face, taking a 3.8 m storey as the scale and assumed for every wing) on wall w from s0 to s1, a plinth (the
    // yard faces' dado is salmon in the photo) and a white band under the eaves
    const win=(w,s0,s1,H,nst,sh=3.8,pl=K.plinth)=>{if(s1-s0<2.5)return;const n=Math.max(1,Math.round((s1-s0)/2.5)),d=(s1-s0)/n;
      rect(w,s0,s1,0.3,1.1,pl);rect(WLo(w),s0,s1,H-.45,H,K.white);
      for(let k=0;k<nst;k++)for(let i=0;i<n;i++){const c=s0+(i+.5)*d;rect(w,c-.75,c+.75,1.1+k*sh,3+k*sh,k%2?K.glass2:K.glass);}};
    const WLo=w=>({...w,q:(s,h)=>{const p=w.q(s,h),n=w.n;return [p[0]+n[0]*.03,p[1],p[2]+n[2]*.03];}});
    // a range from (u0,v0) to (u1,v1) with its ridge along ax ('u' or 'v'), cut along it into steps that each stand on
    // their own lowest corner: eaves H, ridge rh higher (0: a flat roof), nst storeys of windows on the open sides
    // (sides: which of S, N, W, E get windows; dado: which of them have the salmon dado, yard faces; plinth: the dado's
    // colour), ends: which ends of the whole range get a gable, dy: the floor's height when it must line up with
    // another range. Returns {cuts, dys}: where the steps are and the height each stands on
    const range=(u0,v0,u1,v1,ax,H,rh,nst,o={})=>{const wall=o.wall||K.wall,sides=o.sides||'SNWE',dado=o.dado||'',pl=o.plinth||K.dado,ends=o.ends||[1,1],rf=o.roof||roof,
        a0=ax==='u'?u0:v0,a1=ax==='u'?u1:v1,cuts=[a0];
      const q=(s0,s1)=>ax==='u'?R(s0,v0,s1,v1):R(u0,s0,u1,s1),rise=(s0,s1)=>{const g=q(s0,s1);return groundMax(g)-groundMin(g);};
      for(let s=a0;s<a1-1e-6;){let e=a1;while(e-s>10&&rise(s,e)>2.5)e=s+(e-s)/2;cuts.push(e);s=e;}
      const n=cuts.length-1,dys=[];for(let i=0;i<n;i++)dys.push(o.dy!==undefined?o.dy:groundMin(q(cuts[i],cuts[i+1])));
      for(let i=0;i<n;i++){const s0=cuts[i],s1=cuts[i+1],g=q(s0,s1);S.dy=dys[i];occMark(g);
        const [U0,V0,U1,V1]=ax==='u'?[s0,v0,s1,v1]:[u0,s0,u1,s1];
        S.prism(g,0.3,H,wall,o.top||K.flat,!rh);
        // a step's gable shows only where it rises over the next one, plain (the white coping is for the range's ends)
        if(rh){const t0=ax==='u'?v0:u0,t1=ax==='u'?v1:u1,tm=(t0+t1)/2,P=(s,t,h)=>ax==='u'?V(s,t,h):V(t,s,h);
          rf(ax,s0,s1,t0,t1,H,rh,1e3,[i===0?ends[0]:0,i===n-1?ends[1]:0]);
          for(const [k,s,sg] of [[i-1,s0,-1],[i+1,s1,1]])if(k>=0&&k<n&&dys[k]<dys[i]-.01)
            S.face([P(s,t0,H),P(s,t1,H),P(s,tm,H+rh)],ax==='u'?N3(sg,0):N3(0,sg),K.wall2);}
        else{for(const w of [WV(V0,-1,.09),WV(V1,1,.09)])rect(w,U0,U1,H-.4,H+.2,K.white);for(const w of [WU(U0,-1,.09),WU(U1,1,.09)])rect(w,V0,V1,H-.4,H+.2,K.white);}
        if(o.deco)o.deco(U0,V0,U1,V1);
        if(nst){const pc=k=>dado.includes(k)?pl:K.plinth;
          if(sides.includes('S'))win(WV(V0,-1),U0+.6,U1-.6,H,nst,3.8,pc('S'));if(sides.includes('N'))win(WV(V1,1),U0+.6,U1-.6,H,nst,3.8,pc('N'));
          if(sides.includes('W')&&(ax==='v'||i===0))win(WU(U0,-1),V0+.6,V1-.6,H,nst,3.8,pc('W'));if(sides.includes('E')&&(ax==='v'||i===n-1))win(WU(U1,1),V0+.6,V1-.6,H,nst,3.8,pc('E'));}}
      return {cuts,dys};};
    // hipped roof over a rectangle (as the Liceo's), eaves at h, ridge rh higher, along its longer side
    const hip=(u0,v0,u1,v1,h,rh,o=.4)=>{u0-=o;v0-=o;u1+=o;v1+=o;const hw=(u1-u0)/2,um=(u0+u1)/2,a=v0+hw,b=v1-hw;
      S.face([V(u0,v1,h),V(u0,v0,h),V(um,a,h+rh),V(um,b,h+rh)],null,K.tile2);S.face([V(u1,v0,h),V(u1,v1,h),V(um,b,h+rh),V(um,a,h+rh)],null,K.tile);
      S.face([V(u0,v0,h),V(u1,v0,h),V(um,a,h+rh)],null,K.tile);S.face([V(u1,v1,h),V(u0,v1,h),V(um,b,h+rh)],null,K.tile2);};
    const H2=7.6;
    // the courtyard's ranges: south wing (to 3 Norte), east wing (to 1 Oriente, with the entrance), the cross wing
    // into the yard, the west wing and the thin north wing; zinc gable roofs, two storeys. The yard faces have the
    // salmon dado (photo). The north wing is 4 m wide and ends 5 m short of the east wing (the yard's open end on
    // the garden, 2015 imagery)
    range(-11,346,39,359,'u',H2,2.6,2,{ends:[1,0],dado:'N'});
    const EW=range(39,346,51,444,'v',H2,2.4,2,{dado:'W'});
    range(-10,359,2,447,'v',H2,2.4,2,{sides:'E',dado:'E'});
    range(2,443,33.5,447,'u',H2,1.2,2,{sides:'SN',ends:[0,0],dado:'S'});
    // the cross wing on the yard, 4.3 m deep and 10 m long (2015 imagery): it stands on the east wing's floor. On its
    // west face, from the photo: a maroon plinth, a niche with the statue of the founder in the middle, two windows
    // on the ground floor and three tall ones above
    const dyE=EW.dys[Math.max(0,EW.cuts.findIndex((c,i)=>c<=407&&407<EW.cuts[i+1]))];
    range(35,402,39.2,412,'u',H2,2.2,2,{sides:'SN',ends:[1,0],dy:dyE,dado:'SN',plinth:K.maroon});
    {S.dy=dyE;const w=WU(35,-1,.09);rect(w,402,412,0.3,1.7,K.maroon);rect(WLo(w),402,412,H2-.45,H2,K.white);
      rect(w,405.9,408.1,1.9,4.4,K.stone);rect(w,406.6,407.4,2.1,3.7,K.white);
      for(const c of [403.6,410.4])rect(w,c-.8,c+.8,1.9,3,K.glass);for(const c of [404,407,410])rect(w,c-.75,c+.75,4.9,7,K.glass2);}
    // the two galvanised stairs that climb to the cross wing from the north and the south, along the east wing's yard
    // face, each under a zinc canopy on steel posts: treads and risers every 0.5 m, a solid light rail on the yard side
    {const stair=(u,vb,vt,hb,ht)=>{const sg=Math.sign(vt-vb),L=Math.abs(vt-vb),n=Math.max(4,Math.round((ht-hb)/.5)),u0=u-.9,u1=u+.9,rh=(ht-hb)/n,P=(uu,v,h)=>V(uu,v,h),
          hAt=(t,d)=>hb+(ht-hb)*t+d;S.dy=0;
        for(let i=0;i<n;i++){const va=vb+sg*L*i/n,vz=vb+sg*L*(i+1)/n,h=hb+rh*(i+1);
          S.face([P(u0,va,h),P(u1,va,h),P(u1,vz,h),P(u0,vz,h)],[0,1,0],K.steel);
          S.face([P(u0,va,h-rh),P(u1,va,h-rh),P(u1,va,h),P(u0,va,h)],N3(0,-sg),K.steel2);}
        S.face([P(u0,vb,hb-.6),P(u0,vt,ht-.6),P(u0,vt,ht+.9),P(u0,vb,hb+.9)],N3(-1,0),K.rail);
        S.face([P(u0-.3,vb-sg*.4,hb+2.6),P(u1,vb-sg*.4,hb+2.6),P(u1,vt,ht+2.6),P(u0-.3,vt,ht+2.6)],null,K.tile);
        for(const t of [0,.5,1]){const v=vb+sg*L*t;S.dy=E(u0-.2,v);S.prism(R(u0-.4,v-.2,u0,v+.2),0.3,hAt(t,2.6)-S.dy,K.steel2,K.steel2);}S.dy=0;};
      stair(37.9,418,412,E(37.9,418)+.3,dyE+4.1);stair(37.9,396,402,E(37.9,396)+.3,dyE+4.1);}
    // north-east block on the Alameda: three storeys under a hipped roof
    {const g=R(38,444,52,470);S.dy=groundMin(g);occMark(g);S.prism(g,0.3,11.4,K.wall,K.flat,false);hip(38,444,52,470,11.4,2.6);
      for(const [w,a,b] of [[WV(470,1),38.6,51.4],[WU(52,1),444.6,469.4],[WU(38,-1),447.5,469.4]])win(w,a,b,11.4,3);}
    // the entrance on 1 Oriente, mid-way along the east wing: a door under a blue band with the school's name
    {S.dy=groundMin(R(48,396,52,404));const w=WU(51,1,.12);rect(w,397.6,402.4,0.3,3.4,K.door);rect(w,396.8,403.2,3.6,4.4,K.blue);rect(WU(51,1,.15),399,401,3.8,4.2,K.white);}
    // west of the long wing: a flat annex, the stair block on the garden, and the E-shaped building to 1 Poniente: the
    // upper arm (gable), its low strip to the north, the glass-roofed court and the green-roofed one-storey range
    range(-18,383,-10,445,'v',6.6,0,0);
    range(-8,447,0,456,'u',8.6,0,0);
    range(-57,402,-18,419,'u',H2,3,2,{sides:'SW',ends:[1,0]});
    range(-57,419,-18,425,'u',5.2,0,1,{sides:'NW'});
    range(-54,372,-37,383,'u',4.2,1.8,1,{roof:roofG,sides:'SW',ends:[1,0]});
    range(-37,372,-18,383,'u',4.2,1.8,1,{roof:roofG,sides:'S',ends:[0,0]});
    // the south-west corner: a gabled hall of 11 × 15 m (it may be the chapel of 1944: nothing confirms it) and a low
    // white annex to its south-west (2015 imagery)
    range(-24,354,-13,369,'v',4.8,2.2,1,{wall:K.wall2});range(-29,350,-20,355.5,'u',3.4,0,0);
    // the gym: tall walls with a band of high windows, a zinc gable roof running east-west
    range(-58,434,-21,467,'u',8.4,3,0,{wall:K.gym,deco:(u0,v0,u1)=>{for(const w of [WV(467,1,.09),WV(434,-1,.09)])for(let s=u0+.6;s<u1-2.4;s+=3)rect(w,s,s+2,5.6,7.4,K.glass);}});
    // basketball hoops at the ends of each court: a post behind the baseline with a bent arm that carries the backboard,
    // and the ring (an orange square, 0.5 m) in front of it
    for(const [uc,v0] of [[10.5,413.5],[25.5,413.5],[10.5,384],[25.5,384]])for(const [vb,sg] of [[v0+.2,-1],[v0+25.3,1]]){
      S.dy=E(uc,vb);S.prism(R(uc-.2,vb+sg*1.1-.2,uc+.2,vb+sg*1.1+.2),0.3,3.9,K.mast,K.mast);S.prism(R(uc-.2,Math.min(vb,vb+sg*1.1)-.2,uc+.2,Math.max(vb,vb+sg*1.1)+.2),3.5,3.9,K.mast,K.mast);
      S.prism(R(uc-.9,vb-.1,uc+.9,vb+.1),2.9,4.1,K.white,K.white);S.prism(R(uc-.25,vb-sg*.6-.25,uc+.25,vb-sg*.6+.25),2.9,3,K.ring,K.ring);}
    // two light poles at the east wing's foot, north and south of the cross wing (the photo shows one by the big tree)
    for(const [u,v] of [[36.2,423],[36.2,393]]){S.dy=E(u,v);S.prism(R(u-.15,v-.15,u+.15,v+.15),0.3,7,K.iron,K.iron);S.prism(R(u-.45,v-.45,u+.45,v+.45),7,7.4,K.iron,K.lamp);GLOW.push(u,S.dy+7.2,v);}
    // a low white wall with an iron railing along the Alameda, the garden's gate
    {const fw=(a,b)=>{const g=R(a,469.6,b,470);S.dy=groundMin(g);S.prism(g,0.3,0.9,K.white,K.white);S.prism(R(a,469.75,b,469.85),0.9,1.9,K.iron,K.iron);};
      fw(-18,15);fw(19,38);for(const u of [15,19]){const g=R(u-.4,469.4,u+.4,470.2);S.dy=groundMin(g);S.prism(g,0.3,2.4,K.white,K.white);}}
    // trees: along the yard's east and south sides, in the garden (a row behind the railing and two clumps), between
    // the gym and the west building, and in the south-west garden
    for(const [u,v,s] of [[34.6,433,1.2],[34.6,426,1.1],[34.6,387,1.1],[34.6,374,1.2],[34.6,369.5,1.1],[14,369,1.2],[23,368.5,1.2],[31,369,1.1],
      [-14,467,1],[-8,467,1],[-2,467,1],[4,467,1],[25,467,1],[31,467,1],[-15,452,1.3],[-12,461,1.2],[32,452,1.1],[2,452,1],
      [-50,429.5,1.2],[-38,429.5,1.1],[-28,429.5,1.2],[-54,367,1.4],[-46,362,1.3],[-38,368,1.4],[-52,356,1.3],[-41,355,1.2],[-33,362,1.2]])
      TREES.push([u,v,s,(u*7.3+v*1.7)%1]);
    EH.set(keepEH);S.dy=0;}
