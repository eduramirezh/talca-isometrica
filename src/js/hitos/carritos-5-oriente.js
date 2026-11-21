  // ==== hito: carritos-5-oriente ====
  // Los carritos de completos: the completo stands of Talca's best-known food street, two rows drawn on S.
  // Not carts on wheels: fixed kiosks.
  // (A) 5 Oriente between 2 and 3 Sur (OSM node n1033452823 "Carritos 5 oriente"; Diario Talca, Maule News and En Línea
  // Maule, 2020-2026, put the sector "entre 2 y 3 Sur"; the Seremi inspected "cuatro locales establecidos y seis
  // quioscos" there in June 2026): one shed of six kiosks along the west sidewalk, 26.5 m long and ~3.5 m deep,
  // backed against the east face of the two-storey office building w952827345 (Chile Atiende-IPS). Frame: u east,
  // v north along the street (A = 91.5°, the axis of OSM's 5 Oriente w1022644646). From Mapillary (CC BY-SA 4.0;
  // docs/FUENTES.md): the photo of 2022-10-23 from the row's north end and the 360° panoramas from the street, dated
  // 2023-12-03 and 2024-09-28 (one drive uploaded twice: the same parked cars), show one continuous blue sign band
  // along the whole row (Pepsi blue; the panoramas render it lighter), each kiosk's name in white lettering on it after a Pepsi disc (a white oval with PF over
  // Señora Anita, a round red badge at La Quinito's north end), the southern kiosk under a dark sign; below the band,
  // red fronts with a counter opening and doors (La Quinito's is white), dark timber posts at the front holding the
  // band, stacked red crates on the sidewalk in front of Señora Mary and a blue bin at the south end. South to north:
  // the dark sign, Sabores de Talca, Señora Mary, PF Señora Anita, La Quinito, a sixth «La …» under a large Pepsi
  // logo. The 2018 Mapillary photos show the street before this row: separate signs, and a free-standing PF kiosk at
  // the 2 Sur corner. An earlier version of this model, from undated Street View, drew six separate kiosks with
  // brick-and-white columns and a striped awning on the northern one, which none of the dated photos show.
  // (B) 6 Oriente (OSM w360214695 "Carritos 6 oriente", building=hut, 6 x 36 m, east face x 676, between the market's
  // car park and 6 Oriente; the Meganoticias piece on the completo mentions stalls on 6 Oriente): a second row, newer,
  // that edificiosBase already draws as a plain building. The Mapillary panoramas dated 2023-12-03 and 2024-09-28,
  // driving along 6 Oriente, show its east face under the street trees, south to north: a red fabric tent at the
  // corner of 1½ Norte; «Completos y Bebidas Mafran», an orange-red band with a Coca-Cola disc, over a white roller
  // shutter; «Kiosko Hotdoguería Raulito» («el primer carrito de Talca, desde 1976»), a wide black sign over a black
  // canopy, with a gold badge; a dark red Coca-Cola sign; a red «Completos …» band; and a red «Mafran» band with a
  // white-topped tent in front. Only that face is dressed here, with counters outside, red curtains, a paved apron
  // and a green bin at each end; the hut stays. A first try that dropped the hut and drew free-standing kiosks at the
  // curb also repainted the block's ground (the hut was its only OSM building): not that.
  // Approximate: every measure (±0.3 m: the kiosks' widths; the band, ~1.1 m in the panorama, half the front, drawn
  // 1.35 m and its top blue too, because the map's camera sees the roofs more than the fronts), the stalls'
  // lengths along (B), the roofs (no photo sees them: a grey sheet sloping to the street on (A)), the lettering (a
  // band: the names are below the art pixel), the logos (two-pixel blocks), the lights at night (the sector is busy at
  // night, "consumo nocturno": licence, three warm points per stall). The kiosks of (A) are not in the 2015 imagery's
  // detail; the Mercado Central's own carritos stood in 4 Oriente from 1965 to the plaza's remodelling in 2009
  // (Urbanbat).
  // Method: docs/METODOLOGIA.md §9; style: docs/ESTETICA.md.
  {const nv0=S.nv,t0=performance.now();
    const KA={fascia:C('#2F5DA8'),navy:C('#252F52'),text:C('#E8E5DC'),white:C('#E4E0D6'),body:C('#B0302A'),door:C('#C8473A'),
      post:C('#5E4634'),roof:C('#6E6A64'),floor:C('#B39A7B'),back:C('#3A322D'),counter:C('#D8D2C4'),ctop:C('#B8895A'),
      pot:C('#B9BDBE'),crate:C('#C4362B'),bin:C('#2F6AAE'),logoR:C('#C8322B')};
    const KB={fascia:C('#C23B2F'),orange:C('#D24A2C'),maroon:C('#8A2B2A'),black:C('#2A2A2E'),canopy:C('#353338'),gold:C('#D9A732'),
      text:C('#EEEAE0'),white:C('#EEEAE0'),body:C('#B5352D'),tent:C('#C9473A'),counter:C('#D8D2C4'),ctop:C('#C9A878'),
      pot:C('#B9BDBE'),bin:C('#4E8B4B'),pave:C('#CDBFA9'),pave2:C('#BFAF98')};
    // ---- (A) 5 Oriente: one shed, a continuous sign band over six kiosks
    {const F=localFrame(562.8,-258,91.5*Math.PI/180),{V,N3,R}=F;
      const D=3.5,FU=.45,HB=1.95,HT=3.3; // the kiosks' depth; how far the band sticks out past their fronts; its bottom and top
      // south to north: width; the band's colour (blue if none); the logo at its south end; the counter opening (a
      // fraction of the front); a door; what stands outside
      const ROW=[
        {w:4.2,band:KA.navy,logo:'dot',open:.45,bin:true},          // the dark sign, a red PF disc
        {w:4.6,logo:'pepsi',open:.55},                              // Completos Sabores de Talca
        {w:4.6,logo:'pepsi',open:.6,crates:true},                   // Completos Señora Mary: wide open, red crates outside
        {w:4.5,logo:'pf',open:.3,door:KA.door},                     // PF Señora Anita: a mostly closed front
        {w:4.4,logo:'pepsi',open:.35,door:KA.white,badge:true},     // Completos La Quinito
        {w:4.2,logo:'pepsi',open:.6}];                              // «La …»
      let v=0;for(const k of ROW){k.v0=v;v+=k.w;k.v1=v;}
      occMark(R(-.5,-.3,D+FU+1.2,v+.3),3);
      CLEAR.push(R(-.5,-3,9,v+3)); // no street trees or parked cars in front of the row (Edu, 2026-10-19: they hid it)
      const at=(u,a,b,h0,h1,col)=>S.face([V(u,a,h0),V(u,b,h0),V(u,b,h1),V(u,a,h1)],N3(1,0),col); // a face looking east
      const end=(vb,n)=>S.face([V(0,vb,.3),V(D,vb,.3),V(D,vb,3.25),V(0,vb,3.55)],N3(0,n),KA.body);  // the row's end walls
      ROW.forEach((k,i)=>{const {v0,v1}=k,W=v1-v0,o0=v0+.4,o1=o0+W*k.open,f=D+FU;
        S.dy=groundMin(R(0,v0,f,v1));
        S.prism(R(0,v0,D,v1),.1,.3,KA.floor,KA.floor);                         // floor slab
        at(.15,v0,v1,.3,3.2,KA.back);                                         // the dark inside, against the building
        S.prism(R(1.3,o0,2.0,o1),.3,1.05,KA.counter,KA.ctop);                  // the counter, pots on it
        for(const t of [.3,.7]){const c=o0+(o1-o0)*t;S.prism(R(1.4,c-.3,1.9,c+.3),1.05,1.5,KA.pot,KA.pot);}
        // the red front around the counter opening (open up to the band), and a door
        at(D,v0,o0,.3,HB,KA.body);at(D,o1,v1,.3,HB,KA.body);at(D,o0,o1,.3,1.05,KA.body);
        if(k.door)at(D+.03,v1-1.4,v1-.5,.3,1.9,k.door);
        if(i)S.prism(R(.15,v0-.12,D,v0+.12),.3,3.2,KA.body,KA.body);else end(v0,-1);  // the wall to the south neighbour
        if(i===ROW.length-1)end(v1,1);
        // the roof, a sheet sloping to the street under the band's top, and the band (its top too: from above, the
        // blue line along the street is what tells the row)
        S.face([V(0,v0,3.55),V(D,v0,3.25),V(D,v1,3.25),V(0,v1,3.55)],null,KA.roof);
        S.prism(R(D-.05,v0,f,v1),HB,HT,k.band||KA.fascia,k.band||KA.fascia);
        // on the band: the logo at its south end (Pepsi: white under red), the lettering, La Quinito's badge
        const lw=k.logo==='pf'?1.5:.9;
        at(f+.07,v0+.4,v0+.4+lw,2.15,3.15,k.logo==='dot'?KA.logoR:KA.white);
        if(k.logo==='pepsi')at(f+.1,v0+.4,v0+.4+lw,2.65,3.15,KA.logoR);
        at(f+.07,v0+lw+.8,v1-(k.badge?1.8:.4),2.35,3.0,KA.text);
        if(k.badge)at(f+.07,v1-1.4,v1-.5,2.15,3.15,KA.logoR);
        if(k.crates)for(const [a,h] of [[v0+.5,1.6],[v1-1.1,1.1]])S.prism(R(f+.2,a,f+.8,a+.55),.3,h,KA.crate,KA.crate);
        if(k.bin)S.prism(R(f+.2,v0+.3,f+.8,v0+.9),.3,1.0,KA.bin,KA.bin);
        for(const t of [1/6,.5,5/6]){const g=F.G(f+.5,v0+W*t);GLOW.push(g[0],S.dy+1.7,g[1]);}}); // three warm points under the band
      // the timber posts holding the band, at each kiosk boundary and both ends
      [0,...ROW.map(k=>k.v1)].forEach(vb=>{S.dy=groundMin(R(D,vb-.2,D+FU,vb+.2));S.prism(R(D+.05,vb-.2,D+.45,vb+.2),.3,HB,KA.post,KA.post);});
      const m=F.G(D/2,v/2);MODELS['carritos-5-oriente']={x:m[0],y:m[1],h:4};}
    // ---- (B) 6 Oriente: the row is OSM's hut itself (w360214695, drawn by edificiosBase like any building); only its
    // east face gets the shopfronts, on a paved apron
    {const F=localFrame(676.36,128.44,91.4*Math.PI/180),{G,Gs,V,N3,R}=F;
      {const {G:Lg,done}=groundLayer(S,1<<10);Lg.flat(Gs([[-.3,-.5],[3.4,-.5],[3.4,35.5],[-.3,35.5]]),.2,KB.pave);
        for(let v=-.5,k=0;v<35;v+=3,k++)Lg.flat(Gs([[-.3,v],[3.4,v],[3.4,Math.min(v+1.5,35.5)],[-.3,Math.min(v+1.5,35.5)]]),.22,k%2?KB.pave2:KB.pave);
        done();}
      const at=(u,a,b,h0,h1,col)=>S.face([V(u,a,h0),V(u,b,h0),V(u,b,h1),V(u,a,h1)],N3(1,0),col); // a face looking east
      const tent=(u0,u1,v0,v1,h,top)=>{S.dy=groundMin(R(u0,v0,u1,v1));S.prism(R(u0,v0,u1,v1),.3,h,KB.tent,KB.tent);
        pyramid(S,R(u0-.1,v0-.1,u1+.1,v1+.1),h,.8,top);};
      // south to north: the band's colour; its badge at the south end (a Coca-Cola disc if none); what else it has
      const ROW=[
        {v0:.15,v1:3.6,tent:true},                                  // a red fabric tent at the corner of 1½ Norte
        {v0:3.9,v1:10.2,band:KB.orange,shutter:true},               // Completos y Bebidas Mafran
        {v0:10.5,v1:19,band:KB.black,logo:KB.gold,canopy:true},     // Kiosko Hotdoguería Raulito: tall, over a canopy
        {v0:19.3,v1:24.1,band:KB.maroon,short:true},                // a dark red Coca-Cola sign
        {v0:24.4,v1:30.1,band:KB.fascia},                           // Completos …
        {v0:30.4,v1:35.35,band:KB.fascia,front:true}];              // Mafran, a white-topped tent in front
      for(const k of ROW){const {v0,v1}=k,W=v1-v0;
        if(k.tent){tent(.2,3.2,v0,v1,2.2,KB.tent);continue;}
        S.dy=groundMin(R(0,v0,1.4,v1));
        const out=k.canopy?.8:.6,h0=k.canopy?2.3:1.9,h1=k.canopy?3.5:3.3;
        S.prism(R(0,v0,out,v1),h0,h1,k.band,k.band);                                  // the sign band, proud of the hut's face
        if(k.canopy)S.face([V(out,v0,h0),V(out,v1,h0),V(2.0,v1,2.0),V(2.0,v0,2.0)],null,KB.canopy);
        at(out+.04,v0+.3,v0+1.0,h0+.3,h1-.2,k.logo||KB.white);
        at(out+.04,v0+1.4,k.short?v0+3.2:v1-.4,h1-(k.canopy?.75:.95),h1-.3,KB.text);   // the lettering
        if(k.shutter)at(.05,v0+.4,v0+2.6,.3,1.85,KB.white);                           // Mafran's roller shutter
        if(!k.front){S.prism(R(.6,v0+.9,1.3,v1-.9),.3,1.05,KB.counter,KB.ctop);          // the counter outside
          for(const t of [.3,.7])S.prism(R(.7,v0+W*t-.3,1.2,v0+W*t+.3),1.05,1.5,KB.pot,KB.pot);}
        for(const [c0,c1] of [[v0+.1,v0+.9],[v1-.9,v1-.1]])at(.75,c0,c1,1.0,1.9,KB.body); // red curtains at the ends
        for(const t of [.2,.5,.8]){const g=G(1.1,v0+W*t);GLOW.push(g[0],S.dy+1.7,g[1]);}
        if(k.front)tent(.8,3.2,v0+.6,v0+4,2.1,KB.white);}
      for(const [v,h] of [[-.2,1],[35.6,1]]){S.dy=groundMin(R(1.2,v-.3,1.8,v+.3));S.prism(R(1.4,v-.3,2.0,v+.3),.3,h,KB.bin,KB.bin);}}   // a green bin at each end
    S.dy=0;
    window.__carritos={verts:S.nv-nv0,ms:+(performance.now()-t0).toFixed(1)};} // for tools/probe.py: what the model costs
