  // ==== hito: escuelas-concentradas ====
  // Escuelas Concentradas (1939–1941, Monumento Histórico 2013), on the north half of the block between 3 and 4
  // Oriente, facing Plaza Cienfuegos and 1 Sur; drawn on S. Plan from OpenStreetMap: the U-shaped school w110971696
  // (a south wing with the clock tower in the middle, west and east wings around the schoolyard, open to 1 Norte) and
  // the plaza w107754260. Frame localFrame(375, 15, 90°): u = grid x (east), v = grid y (north). Closed since the 2010
  // earthquake. Elevation from photos on Wikimedia Commons (2014, 2018): two storeys, the ground floor painted red
  // (windows boarded up), the upper one cream with ribbon windows; a central tower with two orange piers, two slit
  // windows and a round clock; a one-storey red block with a rounded corner at the south-east end ("Escuela Superior
  // de Hombres"). Courts in the yard and the plaza's paving, lawn and sunken amphitheatre from the Esri imagery
  // (undated). Approximate: the heights (proportions from the photos, ~9 m eaves, ~14 m tower), flat roofs (they are
  // low iron roofs behind the parapet), the court side and the north ends (no photos), the wings' widths. No lights.
  {const F=localFrame(375,15,Math.PI/2),{G,Gs,V,N3,R}=F;
    const K={red:C('#B5433A'),red2:C('#9E3B33'),cream:C('#E6DCC2'),white:C('#F0EADB'),roof:C('#8A6A58'),orange:C('#D88A55'),
      glass:C('#3B4653'),glass2:C('#2C3540'),board:C('#B39A62'),dark:C('#2E2C2B'),sign:C('#7FA7C9'),tile:C('#8A6A58'),tile2:C('#7A5E4E'),
      yard:C('#C9B98F'),clay:C('#B0644A'),court:C('#58758C'),line:C('#F3F0E6'),pave:C('#CFC7B0'),pave2:C('#BDB49C'),lawn:C('#8FA85A')};
    const {box,WL,WV,WU,rect}=facade(S,F,K);
    const site=Gs([[-57,-83],[56,-83],[56,34],[-57,34]]);NOLOTS.push(site);
    const fp=[[[-36,-35],[36,-35],[36,-25],[-36,-25]],[[-56,-33],[-36,-33],[-36,-23],[-56,-23]],[[-56,-23],[-46,-23],[-46,34],[-56,34]],
      [[36,-28],[56,-28],[56,-23],[36,-23]],[[46,-23],[56,-23],[56,32],[46,32]],[[36,-33],[56,-33],[56,-28],[36,-28]],[[-57,-83],[56,-83],[56,-36],[-57,-36]]];
    fp.forEach(q=>occMark(Gs(q)));S.dy=padAt(G(-57,0)[0],G(0,-83)[1],G(56,0)[0],G(0,34)[1]);
    // Plaza Cienfuegos in front: paving, a lawn strip with a central walk, the sunken amphitheatre in two-tone steps
    S.flat(Gs([[-57,-83],[56,-83],[56,-35],[-57,-35]]),0.3,K.pave);
    for(const [a,b] of [[-52,-6],[6,50]])S.quadXY(R(a,-41,b,-36.5),0.33,K.lawn);
    for(let k=0;k<4;k++){const r0=19-k*3,r1=r0-3,arc=[];for(let i=0;i<=12;i++){const t=Math.PI*i/12;arc.push([Math.cos(t),Math.sin(t)]);}
      for(let i=0;i<12;i++)S.face([V(arc[i][0]*r0,-66+arc[i][1]*r0,.33+k*.03),V(arc[i+1][0]*r0,-66+arc[i+1][1]*r0,.33+k*.03),V(arc[i+1][0]*r1,-66+arc[i+1][1]*r1,.33+k*.03),V(arc[i][0]*r1,-66+arc[i][1]*r1,.33+k*.03)],[0,1,0],k%2?K.pave2:K.pave);}
    // schoolyard with two courts
    S.flat(Gs([[-46,-23],[46,-23],[46,34],[-46,34]]),0.3,K.yard);
    S.quadXY(R(-23,-17,-8,11),0.33,K.line);S.quadXY(R(-22.5,-16.5,-8.5,10.5),0.36,K.clay);
    S.quadXY(R(8,-19,24,10),0.33,K.line);S.quadXY(R(8.5,-18.5,23.5,9.5),0.36,K.court);
    // the U: a red ground floor and a cream upper floor under a flat roof with a pale cornice
    const GF=4.6,TOP=8.6;
    for(const q of fp.slice(0,5)){const [u0,v0]=q[0],[u1,v1]=q[2];box(u0,v0,u1,v1,0.3,GF,K.red,K.red,false);box(u0,v0,u1,v1,GF,TOP,K.cream,K.roof);}
    // a façade from a to b (u,v) facing out: boarded and glazed windows below, ribbon windows above between piers
    const floors=(a,b,out,skip)=>{const w=WL(a,b,out),wb=WL(a,b,out,.09),n=Math.max(1,Math.round(w.L/4)),bw=w.L/n;
      rect(wb,0,w.L,TOP-.4,TOP,K.white);rect(w,0,w.L,0.3,0.8,K.red2);
      for(let k=0;k<n;k++){const c=(k+.5)*bw;if(skip&&c>skip[0]&&c<skip[1])continue;
        rect(w,c-bw/2+.3,c+bw/2-.3,5.3,7.7,k%2?K.glass2:K.glass);rect(w,c-1.5,c+1.5,1.3,3.8,k%3===1?K.glass:K.board);}};
    floors([-36,-35],[36,-35],[0,-1],[33,39]);floors([-56,-33],[-36,-33],[0,-1]);floors([-56,34],[-56,-33],[-1,0]);floors([56,-28],[56,32],[1,0]);
    floors([-56,34],[-46,34],[0,1]);floors([46,32],[56,32],[0,1]);floors([-36,-25],[36,-25],[0,1],[33,39]);floors([-46,-23],[-46,34],[1,0]);floors([46,34],[46,-23],[-1,0]);
    floors([36,-28],[56,-28],[0,-1]);floors([-46,-23],[-36,-23],[0,1]);floors([36,-23],[46,-23],[0,1]);
    // the one-storey red block with a rounded corner at the south-east end
    {const q=[[36,-33],[53,-33]];for(let i=1;i<=6;i++){const t=-Math.PI/2+Math.PI/2*i/6;q.push([53+3*Math.cos(t),-30+3*Math.sin(t)]);}q.push([56,-28],[36,-28]);
      S.prism(Gs(q),0.3,4.8,K.red,K.roof);const w=WV(-33,-1),wb=WV(-33,-1,.09);rect(wb,36,53,4.3,4.8,K.white);rect(w,36,53,0.3,0.8,K.red2);
      for(const c of [40,45,50])rect(w,c-1.7,c+1.7,1.3,3.7,K.glass);}
    // clock tower (~14 m): orange piers framing two slit windows, a round clock and a sign band at the top
    box(-3,-35.6,3,-27,0.3,14.5,K.cream,K.roof);
    {const w=WV(-35.6,-1),wp=WV(-35.6,-1,.12);rect(w,-3,3,0.3,GF,K.red);
      for(const s of [-3,2])rect(wp,s,s+1,0.3,14.5,K.orange);for(const s of [-1.5,.6])rect(WV(-35.6,-1,.09),s,s+.9,1.2,10.8,K.dark);
      rect(w,-.9,.9,12,13.4,K.dark);rect(w,-.6,.6,11.7,13.7,K.dark);rect(wp,-.3,.3,12.5,12.9,K.white);rect(w,-2,2,13.85,14.35,K.sign);}
    const c=G(0,-24);MODELS['escuelas-concentradas']={x:c[0],y:c[1],h:16};S.dy=0;}
