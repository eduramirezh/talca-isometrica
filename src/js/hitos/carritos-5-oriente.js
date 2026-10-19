  // ==== hito: carritos-5-oriente ====
  // Los carritos de completos: the completo stands of Talca's best-known food street, two rows drawn on S.
  // Not carts on wheels: fixed kiosks.
  // (A) 5 Oriente between 2 and 3 Sur (OSM node n1033452823 "Carritos 5 oriente"; Diario Talca, Maule News and En Línea
  // Maule, 2020-2026, put the sector "entre 2 y 3 Sur"; the Seremi inspected "cuatro locales establecidos y seis
  // quioscos" there in June 2026): a continuous row of six kiosks along the west sidewalk, 26.5 m long and ~3.5 m deep (+0.45 m of fascia),
  // backed against the east face of the two-storey office building w952827345 (Chile Atiende-IPS). Frame: u east,
  // v north along the street (A = 91.5°, the axis of OSM's 5 Oriente w1022644646). From Google Street View panoramas
  // (looked at, nothing copied; undated, 2024-25 by the cars): a flat roof under one blue fascia sign per kiosk with a
  // round soda logo and a white lettering band, dark red kiosk bodies, brick-and-white columns between them, an open
  // front onto the street with a counter, steel pots and red stools inside, a red-and-white striped awning on the
  // northern one, crates and a bin at the south end, whose kiosk has a dark roof and a navy-and-red front.
  // (B) 6 Oriente (OSM w360214695 "Carritos 6 oriente", building=hut, 6 x 36 m, east face x 676, in the market's car park;
  // the Meganoticias piece on the completo mentions stalls on 6 Oriente): a second row, newer, that edificiosBase already
  // draws as a plain building. Street View (across the street, under the street trees) shows its east face as a run of
  // stalls with soda-red and black sign bands, white lettering, counters and red curtains outside; Google's satellite
  // names small locales along it (completos, sushi). Only that face is dressed here (six stalls, a paved apron, a green
  // bin at each end); the hut stays. A first try that dropped the hut and drew free-standing kiosks at the curb also
  // repainted the block's ground (the hut was its only OSM building): not that.
  // Approximate: every measure (±0.3 m: stall width ~4.5 m, fascia ~1.4 m, from the Street View framing), which stall
  // has which sign colour, the number of stalls of (B) (six, by the hut's length), the awning, the lettering (a band: the
  // names are below the art pixel), the lights at night (the sector is busy at night, "consumo nocturno": licence, three
  // warm points per stall). The kiosks of (A) are not in the 2015 imagery's detail; the Mercado Central's own
  // carritos stood in 4 Oriente from 1965 to the plaza's remodelling in 2009 (Urbanbat).
  // Method: docs/METODOLOGIA.md §9; style: docs/ESTETICA.md.
  {const nv0=S.nv,t0=performance.now();
    const KA={fascia:C('#2F5DA8'),fascia2:C('#244B8C'),text:C('#E8E5DC'),body:C('#9C2F2B'),brick:C('#8F4330'),white:C('#E4E0D6'),
      roof:C('#6E6A64'),roofS:C('#5C5853'),floor:C('#B39A7B'),back:C('#3A322D'),counter:C('#D8D2C4'),ctop:C('#B8895A'),stool:C('#B4322D'),
      pot:C('#B9BDBE'),crate:C('#2F5DA8'),bin:C('#6F7679'),logoR:C('#C8322B'),logoB:C('#2A4F9A'),awA:C('#C94B45'),awB:C('#EEEAE0'),
      navy:C('#2B3A6B'),red:C('#A82A2D'),dark:C('#3C3A38')};
    const KB={fascia:C('#C23B2F'),text:C('#EEEAE0'),body:C('#B5352D'),roof:C('#A62F26'),counter:C('#D8D2C4'),ctop:C('#C9A878'),pot:C('#B9BDBE'),
      bin:C('#4E8B4B'),logoR:C('#EEEAE0'),pave:C('#CDBFA9'),pave2:C('#BFAF98'),black:C('#2A2A2E')};
    const D=3.5,FU=.45; // depth of a kiosk, how far the fascia sticks out past it
    // one kiosk in frame F: v0..v1 along the row, depth d; o: {pal, awning, back, shop (a navy-and-red front)}
    const kiosk=(F,v0,v1,d,o)=>{const {V,N3,R}=F,P=o.pal,W=v1-v0;
      S.dy=groundMin(R(0,v0,d+FU,v1));
      const face=(pts,n,col)=>S.face(pts,n,col);
      const Fr=(h0,h1,a,b,col,off=0)=>face([V(d+FU+off,a,h0),V(d+FU+off,b,h0),V(d+FU+off,b,h1),V(d+FU+off,a,h1)],N3(1,0),col);
      S.prism(R(0,v0,d,v1),.1,.3,P.floor,P.floor);                                  // floor slab
      face([V(.15,v0,.3),V(.15,v1,.3),V(.15,v1,2.85),V(.15,v0,2.85)],N3(1,0),P.back);  // dark back, the facade behind
      S.prism(R(0,v0,d,v1),2.9,3.1,P.roofS,P.roof);                                // flat roof
      // fascia: the sign band along the front, a little proud of the roof and of the posts
      const fc=o.shop?P.navy:P.fascia;S.prism(R(d-.05,v0,d+FU,v1),1.9,3.3,fc,P.roof);
      if(o.shop){Fr(1.9,2.4,v0,v1,P.red,.04);Fr(2.55,3.1,v0+.4,v1-.4,P.text,.07);}
      else{Fr(1.9,2.1,v0,v1,P.fascia2,.04);                                           // a darker lower edge
        Fr(2.35,3.0,v0+1.5,v1-.35,P.text,.07);                                       // the lettering band
        Fr(2.2,3.1,v0+.3,v0+1.2,P.logoR,.07);Fr(2.2,2.65,v0+.3,v0+1.2,P.logoB,.1);} // the round soda logo, two halves
      // counter with a top, steel pots on it, red stools in front of it
      S.prism(R(1.3,v0+.5,2.0,v1-.5),.3,1.05,P.counter,P.ctop);
      for(const f of [.3,.7])S.prism(R(1.4,v0+W*f-.3,1.9,v0+W*f+.3),1.05,1.5,P.pot,P.pot);
      const ns=Math.max(2,Math.round(W/1.6));for(let k=0;k<ns;k++){const c=v0+W*(k+.5)/ns;S.prism(R(2.5,c-.3,3.1,c+.3),.3,.85,P.stool,P.stool);}
      // columns between kiosks (drawn per boundary by the caller: o.cols), awning, crates, bin
      if(o.awning){const n=Math.round(W/.5);for(let k=0;k<n;k++){const a=v0+k*W/n,b=a+W/n;
        face([V(d+FU,a,1.9),V(d+FU,b,1.9),V(d+FU+.95,b,1.55),V(d+FU+.95,a,1.55)],N3(.4,0,.9),k%2?P.awB:P.awA);}}
      if(o.crates)for(let k=0;k<2;k++)S.prism(R(d-.3,v1-1.3+k*.0,d+.3,v1-.6),.3,1.1+k*.5,P.crate||P.bin,P.crate||P.bin);
      if(o.bin)S.prism(R(d+.1,v0+.2,d+.7,v0+.8),.3,1.0,P.bin,P.bin);
      for(const f of [1/6,.5,5/6]){const g=F.G(d+FU+.5,v0+W*f);GLOW.push(g[0],S.dy+1.7,g[1]);}}; // three warm points under each fascia
    // ---- (A) 5 Oriente
    {const F=localFrame(562.8,-258,91.5*Math.PI/180),{R}=F,W=[4.2,4.6,4.6,4.5,4.4,4.2];let v=0;const ks=[];
      W.forEach((w,i)=>{ks.push([v,v+w,i]);v+=w;});
      occMark(R(-.5,-.3,D+FU+1.2,v+.3),3);
      CLEAR.push(R(-.5,-3,9,v+3)); // no street trees or parked cars in front of the row (Edu, 2026-10-19: they hid it)
      const colB=[KA.brick,KA.white,KA.brick,KA.white,KA.brick,KA.white,KA.brick];
      ks.forEach(([a,b,i])=>kiosk(F,a,b,D,{pal:KA,shop:i===0,awning:i===5,crates:i===0,bin:i===0}));
      // columns: at each boundary and the two ends, full height, 0.4 m wide, brick and white alternating
      [0,...ks.map(k=>k[1])].forEach((vb,i)=>{S.dy=groundMin(R(0,vb-.2,D+FU,vb+.2));S.prism(R(D-.4,vb-.2,D,vb+.2),.3,2.95,colB[i],colB[i]);
        S.prism(R(0,vb-.12,D-.4,vb+.12),.3,2.9,KA.body,KA.body);});
      const m=F.G(D/2,v/2);MODELS['carritos-5-oriente']={x:m[0],y:m[1],h:4};}
    // ---- (B) 6 Oriente: the row is OSM's hut itself (w360214695, drawn by edificiosBase like any building); only its
    // east face gets the shopfronts: a sign band per stall, a counter outside and curtains, on a paved apron
    {const F=localFrame(676.36,128.44,91.4*Math.PI/180),{G,Gs,V,N3,R}=F;
      {const Lg=new GB(1<<10);Lg.flat(Gs([[-.3,-.5],[3.4,-.5],[3.4,35.5],[-.3,35.5]]),.2,KB.pave);
        for(let v=-.5,k=0;v<35;v+=3,k++)Lg.flat(Gs([[-.3,v],[3.4,v],[3.4,Math.min(v+1.5,35.5)],[-.3,Math.min(v+1.5,35.5)]]),.22,k%2?KB.pave2:KB.pave);
        const d=drape(Lg);S.dy=0;for(let t=0;t<d.ni;t+=3){const k=d.I[t]*3;S.face([0,1,2].map(j=>{const m=d.I[t+j]*3;return [d.P[m],d.P[m+1],d.P[m+2]];}),[0,1,0],[d.C[k],d.C[k+1],d.C[k+2]]);}}
      const W=34.7/6,sg=[KB.fascia,KB.black,KB.fascia,KB.fascia,KB.black,KB.fascia];
      for(let i=0;i<6;i++){const v0=.15+i*W,v1=v0+W-.3;S.dy=groundMin(R(0,v0,1.4,v1));
        const fr=(h0,h1,a,b,col,off)=>S.face([V(.6+off,a,h0),V(.6+off,b,h0),V(.6+off,b,h1),V(.6+off,a,h1)],N3(1,0),col);
        S.prism(R(0,v0,.6,v1),1.9,3.3,sg[i],KB.roof);                                    // the sign band, proud of the hut's face
        fr(2.35,3.0,v0+1.2,v1-.4,KB.text,.04);fr(2.2,3.1,v0+.3,v0+1.0,sg[i]===KB.black?KB.fascia:KB.logoR,.04);
        S.prism(R(.6,v0+.9,1.3,v1-.9),.3,1.05,KB.counter,KB.ctop);                       // the counter outside
        for(const f of [.3,.7])S.prism(R(.7,v0+(v1-v0)*f-.3,1.2,v0+(v1-v0)*f+.3),1.05,1.5,KB.pot,KB.pot);
        for(const [c0,c1] of [[v0+.1,v0+.9],[v1-.9,v1-.1]])S.face([V(.75,c0,1.0),V(.75,c1,1.0),V(.75,c1,1.9),V(.75,c0,1.9)],N3(1,0),KB.body); // red curtains at the ends
        for(const f of [.2,.5,.8]){const g=G(1.1,v0+(v1-v0)*f);GLOW.push(g[0],S.dy+1.7,g[1]);}}
      for(const [v,h] of [[-.2,1],[35.6,1]]){S.dy=groundMin(R(1.2,v-.3,1.8,v+.3));S.prism(R(1.4,v-.3,2.0,v+.3),.3,h,KB.bin,KB.bin);}}   // a green bin at each end
    S.dy=0;
    window.__carritos={verts:S.nv-nv0,ms:+(performance.now()-t0).toFixed(1)};} // for tools/probe.py: what the model costs
