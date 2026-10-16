  // ==== hito: colegio-la-salle ====
  // Colegio De La Salle (1 Oriente 1481), the whole block between 3 Norte, the Alameda, 1 Poniente and 1 Oriente, on S
  // (unlisted: it has no card). Grounds from OpenStreetMap's school w111123029 (the land-use layer's "educacional" entry,
  // skipped because this footprint is reserved in occ; the block is `generar` in config/edificios.json, so its OSM
  // buildings are not drawn as plain slabs). Buildings from OSM: the L of the east and south wings w664947884, the
  // E-shaped west building w952226021, the gym w664947885 and the three-storey north-east block w664947886. The rest is
  // read from the Esri imagery (satellite.py marco 0 410 90 …: u = grid x, v = grid y): the gabled two-storey wing on
  // the west side of the courtyard, the thin north wing that closes it, the asphalt yard with four marked courts and
  // the trees along its east and south sides, the hipped roof of the north-east block, the cross wing into the yard,
  // the glass-roofed court and the green-roofed range of the west building, the garden on the Alameda and the trees
  // in the south-west corner. There is NO photo of the school (Commons has none): wall colours (cream), the zinc
  // roofs' tone, the windows, the storey heights (3.8 m; OSM's height tags are the import's 2.8 m a storey), the gym's
  // height and the low railing on the Alameda are guesses. The model's relief falls ~12 m across the block (from the
  // Alameda, where the Teatro's and La Victoria's pads hold it at +5 m, to the south-west corner), so there is no pad:
  // the pads already registered are applied to the terrain while this block is drawn (and undone after, applyPads
  // does it again), every building stands on the final ground in steps of up to ~2.5 m (the step's gable in the darker wall tone), and the ground is
  // draped on it.
  {const F=localFrame(0,0,Math.PI/2),{G,Gs,V,N3,R}=F,keepEH=EH.slice();applyPads();
    const K={wall:C('#E8E0CC'),wall2:C('#DED5BE'),plinth:C('#B9B2A2'),white:C('#F0EBDF'),glass:C('#3B4653'),glass2:C('#2C3540'),door:C('#5A4636'),
      blue:C('#2F4F8F'),tile:C('#C9CCCA'),tile2:C('#BABEBD'),flat:C('#A9ACAA'),greenR:C('#5F8A64'),greenR2:C('#7FA37A'),skylight:C('#A9C3C6'),
      gym:C('#E4E0D6'),asph:C('#8C8A84'),line:C('#F3F0E6'),court:C('#7E8C8F'),pave:C('#D8D1C1'),pave2:C('#CCC4B2'),sand:C('#D6C59A'),
      lawn:C('#8FA85A'),lawn2:C('#7FA14F'),iron:C('#3A3A3A'),mast:C('#707070')};
    const {WV,WU,rect,roof}=facade(S,F,{...K,gable:K.wall}),roofG=facade(S,F,{...K,tile:K.greenR,tile2:K.greenR2,gable:K.wall2}).roof;
    const SITE=[[-60,470],[-58,350],[-10,348],[-10,347],[46,346],[52,350],[52,468],[49,471]];
    NOLOTS.push(Gs(SITE));occFill(Gs(SITE),2.5);
    // ground: paving under all (0.11), the asphalt yard with its courts, the garden on the Alameda, lawns and the
    // south-west garden; draped on the final terrain, copied to S facing up (EN() is still zero here)
    {const Lg=new GB(1<<12),lay=(q,o,c)=>Lg.flat(Gs(q),o,c),box=(u0,v0,u1,v1)=>[[u0,v0],[u1,v0],[u1,v1],[u0,v1]];
      lay(SITE,.11,K.pave);lay(box(2,359,39,441),.13,K.asph);
      for(const [u0,v0] of [[3.5,414],[18.5,414],[3.5,386.5],[18.5,386.5]]){lay(box(u0,v0,u0+14,v0+25),.15,K.line);lay(box(u0+.5,v0+.5,u0+13.5,v0+24.5),.17,K.court);
        lay(box(u0+.5,v0+12.25,u0+13.5,v0+12.75),.19,K.line);}
      lay(box(-18,447,38,469),.13,K.lawn);lay(box(-57,425,-21,434),.13,K.lawn2);lay(box(-58,351,-29,372),.13,K.lawn2);lay(box(-54,383,-18,402),.13,K.pave2);
      // the garden's sand plaza: a square turned 45° and the walks to the gate and the wings
      lay([[17,449],[25,457],[17,465],[9,457]],.15,K.sand);lay(box(15.5,457,18.5,469),.16,K.sand);lay(box(-8,455.5,38,458.5),.16,K.sand);
      const d=drape(Lg);S.dy=0;
      for(let t=0;t<d.ni;t+=3){const k=d.I[t]*3;S.face([0,1,2].map(j=>{const m=d.I[t+j]*3;return [d.P[m],d.P[m+1],d.P[m+2]];}),[0,1,0],[d.C[k],d.C[k+1],d.C[k+2]]);}}
    // windows: nst storeys of windows every ~3.6 m on wall w from s0 to s1, a plinth and a white band under the eaves
    const win=(w,s0,s1,H,nst,sh=3.8)=>{if(s1-s0<2.5)return;const n=Math.max(1,Math.round((s1-s0)/3.6)),d=(s1-s0)/n;
      rect(w,s0,s1,0.3,0.9,K.plinth);rect(WLo(w),s0,s1,H-.45,H,K.white);
      for(let k=0;k<nst;k++)for(let i=0;i<n;i++){const c=s0+(i+.5)*d;rect(w,c-.9,c+.9,1.3+k*sh,2.9+k*sh,k%2?K.glass2:K.glass);}};
    const WLo=w=>({...w,q:(s,h)=>{const p=w.q(s,h),n=w.n;return [p[0]+n[0]*.03,p[1],p[2]+n[2]*.03];}});
    // a range from (u0,v0) to (u1,v1) with its ridge along ax ('u' or 'v'), cut along it into steps that each stand on
    // their own lowest corner: eaves H, ridge rh higher (0: a flat roof), nst storeys of windows on the open sides
    // (sides: which of S, N, W, E get windows), ends: which ends of the whole range get a gable
    const range=(u0,v0,u1,v1,ax,H,rh,nst,o={})=>{const wall=o.wall||K.wall,sides=o.sides||'SNWE',ends=o.ends||[1,1],rf=o.roof||roof,
        a0=ax==='u'?u0:v0,a1=ax==='u'?u1:v1,cuts=[a0];
      const q=(s0,s1)=>ax==='u'?R(s0,v0,s1,v1):R(u0,s0,u1,s1),rise=(s0,s1)=>{const g=q(s0,s1);return groundMax(g)-groundMin(g);};
      for(let s=a0;s<a1-1e-6;){let e=a1;while(e-s>10&&rise(s,e)>2.5)e=s+(e-s)/2;cuts.push(e);s=e;}
      const n=cuts.length-1,dys=[];for(let i=0;i<n;i++)dys.push(groundMin(q(cuts[i],cuts[i+1])));
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
        if(nst){if(sides.includes('S'))win(WV(V0,-1),U0+.6,U1-.6,H,nst);if(sides.includes('N'))win(WV(V1,1),U0+.6,U1-.6,H,nst);
          if(sides.includes('W')&&(ax==='v'||i===0))win(WU(U0,-1),V0+.6,V1-.6,H,nst);if(sides.includes('E')&&(ax==='v'||i===n-1))win(WU(U1,1),V0+.6,V1-.6,H,nst);}}
      return cuts;};
    // hipped roof over a rectangle (as the Liceo's), eaves at h, ridge rh higher, along its longer side
    const hip=(u0,v0,u1,v1,h,rh,o=.4)=>{u0-=o;v0-=o;u1+=o;v1+=o;const hw=(u1-u0)/2,um=(u0+u1)/2,a=v0+hw,b=v1-hw;
      S.face([V(u0,v1,h),V(u0,v0,h),V(um,a,h+rh),V(um,b,h+rh)],null,K.tile2);S.face([V(u1,v0,h),V(u1,v1,h),V(um,b,h+rh),V(um,a,h+rh)],null,K.tile);
      S.face([V(u0,v0,h),V(u1,v0,h),V(um,a,h+rh)],null,K.tile);S.face([V(u1,v1,h),V(u0,v1,h),V(um,b,h+rh)],null,K.tile2);};
    const H2=7.6;
    // the courtyard's ranges: south wing (to 3 Norte), east wing (to 1 Oriente, with the entrance), the cross wing
    // into the yard, the west wing and the thin north wing; zinc gable roofs, two storeys
    range(-11,346,39,359,'u',H2,2.6,2,{ends:[1,0]});
    range(39,346,51,444,'v',H2,2.4,2);
    range(33,399,39,413,'u',H2,2.2,2,{sides:'SNW',ends:[1,0]});
    range(-10,359,2,447,'v',H2,2.4,2,{sides:'E'});
    range(2,441,38,447,'u',H2,1.2,2,{sides:'SN',ends:[0,0]});
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
    range(-50,386,-21,396,'u',3.6,0,0,{top:K.skylight,wall:K.wall2});
    range(-54,372,-37,383,'u',4.2,1.8,1,{roof:roofG,sides:'SW',ends:[1,0]});
    range(-37,372,-18,383,'u',4.2,1.8,1,{roof:roofG,sides:'S',ends:[0,0]});
    // small sheds in the south-west corner
    range(-24,359,-14,372,'v',4,0,0);range(-29,351,-12,359,'u',3.4,0,0);
    // the gym: tall walls with a band of high windows, a zinc gable roof running east-west
    range(-58,434,-21,467,'u',8.4,3,0,{wall:K.gym,deco:(u0,v0,u1)=>{for(const w of [WV(467,1,.09),WV(434,-1,.09)])for(let s=u0+.6;s<u1-2.4;s+=3)rect(w,s,s+2,5.6,7.4,K.glass);}});
    // basketball hoops at the ends of each court (post and backboard)
    for(const [uc,v0] of [[10.5,414],[25.5,414],[10.5,386.5],[25.5,386.5]])for(const [vb,sg] of [[v0+.2,-1],[v0+24.8,1]]){
      S.dy=E(uc,vb);S.prism(R(uc-.15,vb+sg*.6-.15,uc+.15,vb+sg*.6+.15),0.3,3.5,K.mast,K.mast);S.prism(R(uc-.9,vb-.1,uc+.9,vb+.1),2.9,4.1,K.white,K.white);}
    // a low white wall with an iron railing along the Alameda, the garden's gate
    {const fw=(a,b)=>{const g=R(a,469.6,b,470);S.dy=groundMin(g);S.prism(g,0.3,0.9,K.white,K.white);S.prism(R(a,469.75,b,469.85),0.9,1.9,K.iron,K.iron);};
      fw(-18,15);fw(19,38);for(const u of [15,19]){const g=R(u-.4,469.4,u+.4,470.2);S.dy=groundMin(g);S.prism(g,0.3,2.4,K.white,K.white);}}
    // trees: along the yard's east and south sides, in the garden (a row behind the railing and two clumps), between
    // the gym and the west building, and in the south-west garden
    for(const [u,v,s] of [[35.5,372,1.1],[35.5,385,1.1],[35.5,420,1.2],[35.5,432,1.1],[14,369,1.2],[23,368.5,1.2],[31,369,1.1],
      [-14,467,1],[-8,467,1],[-2,467,1],[4,467,1],[25,467,1],[31,467,1],[-15,452,1.3],[-12,461,1.2],[32,452,1.1],[2,452,1],
      [-50,429.5,1.2],[-38,429.5,1.1],[-28,429.5,1.2],[-54,367,1.4],[-46,362,1.3],[-38,368,1.4],[-52,356,1.3],[-41,355,1.2],[-33,362,1.2]])
      TREES.push([u,v,s,(u*7.3+v*1.7)%1]);
    EH.set(keepEH);S.dy=0;}
