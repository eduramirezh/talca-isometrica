  // ==== hito: regimiento-16 ====
  // Regimiento de Infantería N° 16 Talca, on S (unlisted: it has no card). The ground is OpenStreetMap's landuse=military
  // w110462501 (the same polygon the land-use layer draws generically; that use is skipped because this footprint is
  // reserved in occ), with OSM's stadium w366882797, its running track (multipolygon r19560482: w723298599 and
  // w1426825003) and the pools w588206288 and w723298600; the map's own tracks inside it are drawn as streets. The rest is
  // read from the Esri imagery rotated into the grid frame (satellite.py marco 150 1480 90: u east, v north, origin
  // (150, 1480), so G is a plain shift): the old barracks in two rows of long rust-roofed blocks around the parade ground
  // (asphalt with two lawn strips), the red-tiled headquarters and the mess with its pool, the grey drill hall, three white
  // hangars, the dark-roofed sheds and the long warehouse by 12 Norte, the red-roofed lodgings along the east wall and
  // the forest that covers the west and east of the grounds. The east wall and the north and south-east stretches are
  // drawn from the imagery (double line along the street). There is NO free photo of the regiment (Commons has only the
  // regiment's 1903 mausoleum, in the cemetery: hitos/cementerio.js): every height, roof and wall colour is a guess from
  // the satellite image and the usual look of Chilean army barracks (cream walls, red tile, rust zinc); the two floors
  // of the barracks, the windows, the number and size of the trees and the dry-grass colours are approximate, and the
  // imagery may be years old. The parade ground has no flagpole: nothing shows one. No lights: nothing documents them.
  {const F=localFrame(150,1480,Math.PI/2),{G,Gs,V,R}=F,{WV,WU,rect}=facade(S,F,{tile:C('#A8482F'),tile2:C('#8E4F3A'),white:C('#ECE7DC'),glass:C('#3B4653'),glass2:C('#2C3540'),gable:C('#D9CDB0'),brick:C('#D9CDB0')});
    const K={soil:C('#B8A27C'),dry:C('#B7A57E'),dry2:C('#B3A07A'),lawn:C('#7FA14F'),lawn2:C('#8FAE58'),asph:C('#7D7B76'),asph2:C('#6E6C68'),yard:C('#9A988F'),track:C('#C49A72'),pitch:C('#9DA66A'),pitch2:C('#8E9A5E'),line:C('#F1EEE4'),road:C('#CDB88F'),
      cream:C('#E6D8B4'),cream2:C('#D9CDB0'),rustR:C('#8F5240'),rustR2:C('#7F4636'),teja:C('#B3412E'),teja2:C('#9A3828'),olive:C('#7C7860'),olive2:C('#6C6853'),zinc:C('#B8BAB6'),zinc2:C('#A5A8A4'),metal:C('#E4E4DE'),metal2:C('#D2D3CD'),
      wall:C('#DDD3BA'),white:C('#ECE7DC'),glass:C('#3B4653'),pool:C('#5BB0D6'),poolE:C('#E6E2D6'),dark:C('#5A4636')};
    const RING=[143,-224,60,-225,60,-229,36,-249,25,-266,21,-286,-6,-329,-85,-303,-88,-225,-86,-133,-162,-111,-131,113,-112,145,-85,194,-38,248,7,323,141,290,145,286,145,116,141,40,142,-14,142,-98];
    const UV=[];for(let i=0;i<RING.length;i+=2)UV.push([RING[i],RING[i+1]]);const GR=Gs(UV),inR=(u,v)=>pip([u,v],UV);
    occFill(GR,2.5);
    const BL=[],bl=(u0,v0,u1,v1,m=2)=>{BL.push([u0-m,v0-m,u1+m,v1+m]);};
    const inBL=(u,v)=>BL.some(o=>u>o[0]&&u<o[2]&&v>o[1]&&v<o[3]);
    // ---- ground: dry soil under all (0.11); the stadium's track and pitch, the lawns, the aprons and the parade ground
    // (0.12–0.14), draped on the terrain (no pad)
    {const Lg=new GB(1<<14),lay=(q,o,c)=>{if(q.length>2)Lg.flat(q,o,c);},rc=(u0,v0,u1,v1)=>[[u0,v0],[u1,v0],[u1,v1],[u0,v1]];
      lay(GR,.11,K.soil);
      lay(Gs(rc(-47,-147,42,-107)),.12,K.dry);                                         // the training field north of the stadium
      lay(Gs(rc(-24,157,-5,227)),.12,K.asph2);lay(Gs(rc(50,225,92,268)),.12,K.asph2);lay(Gs(rc(-98,-57,-76,-18)),.12,K.yard); // old paving, the apron of the sheds, the hangar's yard
      lay(Gs(rc(50,-42,82,50)),.12,K.asph);                                            // the parade ground
      lay(Gs(rc(58.5,-18,65,40)),.13,K.lawn);lay(Gs(rc(58.5,-48,65,-22)),.13,K.lawn2); // its two lawn strips
      lay(Gs(rc(94,-215,126,-178)),.12,K.lawn);                                        // the mess's lawn around its pool
      lay(Gs([[-145,-110],[-130,110],[-52,110],[-52,-125],[-88,-130]]),.12,K.dry2);                                       // the forest floor in the west
      // the stadium: OSM's track (outer ring then the inner one over it), the pitch in mown bands, the lines
      lay(Gs([[-76.9,-179.9],[-76.4,-284.8],[-70.7,-289.5],[-64.5,-293.5],[-57.7,-296.7],[-50.7,-298.9],[-43.4,-300.2],[-36,-300.6],[-28.6,-300],[-21.3,-298.4],[-14.2,-295.9],[-7.5,-292.5],[-1.3,-288.2],[4.2,-283.1],[3.1,-182.7],[-1.2,-177.4],[-6.3,-172.7],[-11.9,-168.8],[-18,-165.7],[-24.5,-163.4],[-31.2,-162],[-38.1,-161.6],[-44.4,-162],[-50.7,-163.2],[-56.7,-165.2],[-62.4,-167.9],[-67.7,-171.3],[-72.6,-175.3]]),.12,K.track);
      lay(Gs([[-71.4,-182.1],[-70.9,-282.2],[-67.4,-285.1],[-61.8,-288.7],[-55.7,-291.5],[-49.3,-293.6],[-42.8,-294.8],[-36.1,-295.1],[-29.4,-294.5],[-22.8,-293.1],[-16.4,-290.9],[-10.4,-287.8],[-4.8,-283.9],[-1.3,-280.7],[-2.4,-184.7],[-5.3,-181.2],[-9.7,-177],[-14.8,-173.5],[-20.2,-170.7],[-26,-168.7],[-32,-167.4],[-38.1,-167],[-43.7,-167.4],[-49.3,-168.5],[-54.6,-170.3],[-59.7,-172.7],[-64.5,-175.7],[-68.8,-179.3]]),.13,K.pitch);
      for(let k=0;k<8;k++)lay(Gs(rc(-68.3,-182.6-k*12.3,-4.8,-182.6-(k+1)*12.3+(k===7?-.5:0))),.14,k%2?K.pitch2:K.pitch);
      const ln=(a,b,c,d)=>lay(Gs(rc(a,b,c,d)),.15,K.line),X0=-67.8,X1=-5.3,Y0=-182,Y1=-280.5,cx=(X0+X1)/2,cy=(Y0+Y1)/2,lw=.5;
      ln(X0,Y0-lw,X1,Y0);ln(X0,Y1,X1,Y1+lw);ln(X0,Y1,X0+lw,Y0);ln(X1-lw,Y1,X1,Y0);ln(X0,cy-lw/2,X1,cy+lw/2);
      for(let i=0;i<16;i++){const a=i/16*Math.PI*2,b=(i+1)/16*Math.PI*2,P=(r,t)=>[cx+r*Math.cos(t),cy+r*Math.sin(t)];lay(Gs([P(8.9,a),P(8.9,b),P(9.4,b),P(9.4,a)]),.15,K.line);}
      for(const [y,sg] of [[Y0,-1],[Y1,1]]){ln(cx-20,y+sg*16.5-(sg>0?0:lw),cx+20,y+sg*16.5+(sg>0?lw:0));ln(cx-20,Math.min(y,y+sg*16.5),cx-20+lw,Math.max(y,y+sg*16.5));ln(cx+20-lw,Math.min(y,y+sg*16.5),cx+20,Math.max(y,y+sg*16.5));}
      // the pools (OSM): water in a pale coping
      for(const p of [[[3.7,-64.2],[37.5,-63.1],[37.9,-75.6],[4,-76.6]],[[100.1,-185.3],[112.4,-184.8],[112.6,-190.2],[100.4,-190.7]]]){
        const c=p.reduce((s,q)=>[s[0]+q[0]/4,s[1]+q[1]/4],[0,0]);lay(Gs(p.map(q=>[c[0]+(q[0]-c[0])*1.1,c[1]+(q[1]-c[1])*1.2])),.13,K.poolE);lay(Gs(p),.14,K.pool);}
      // dirt roads: the west side of the stadium, the avenue from the east gate to the parade ground
      ribbon(Lg,Gs([[-80,-300],[-79,-139],[-72,-110]]),5,.13,K.road);ribbon(Lg,Gs([[142,1],[110,1],[84,0]]),5,.13,K.road);
      const d=drape(Lg);S.dy=0;
      for(let t=0;t<d.ni;t+=3){const k=d.I[t]*3;S.face([0,1,2].map(j=>{const m=d.I[t+j]*3;return [d.P[m],d.P[m+1],d.P[m+2]];}),[0,1,0],[d.C[k],d.C[k+1],d.C[k+2]]);}}
    bl(-77,-301,5,-162,0);bl(3,-77,38,-63,1);bl(100,-191,113,-185,1);bl(50,-42,82,50,0);bl(-24,157,-5,227,0);
    // ---- the wall: the east side, the north-east and the south-east stretches (indices 15..2 of the ring), 2.4 m, with the gate
    {const run=[15,16,17,18,19,20,21,0,1,2].map(i=>GR[i]);let A=0;for(let i=0;i<GR.length;i++){const p=GR[i],q=GR[(i+1)%GR.length];A+=p[0]*q[1]-q[0]*p[1];}
      wallPath(run,false,2.4,.5,K.wall,K.white,[[...G(142,1),3.5]],A>0?1:-1);}
    // gate piers
    for(const o of [-3.8,3.8]){const q=Gs([[139.8,1+o-.5],[143.4,1+o-.5],[143.4,1+o+.5],[139.8,1+o+.5]]);S.dy=groundMin(q);S.prism(q,.3,3.4,K.white,K.white);}S.dy=0;
    // ---- buildings: a gabled block (ridge along its long side), walls with rows of dark windows
    const bld=(u0,v0,u1,v1,o)=>{const h=o.fl*3.4+.3,alongU=(u1-u0)>=(v1-v0),q=alongU?R(u0,v0,u1,v1):Gs([[u0,v0],[u0,v1],[u1,v1],[u1,v0]]),rise=o.rise??Math.min(3,Math.min(u1-u0,v1-v0)*.2);
      S.dy=groundMin(q);S.gable(q,.3,h,rise,o.wall||K.cream,o.roof);
      if(o.win!==false)for(let k=0;k<o.fl;k++){const h0=1.2+k*3.4,h1=h0+1.6;
        if(alongU){for(const [v,sg] of [[v0,-1],[v1,1]]){const w=WV(v,sg,.06);for(let s=u0+3;s<u1-2;s+=3.6)rect(w,s,s+1.2,h0,h1,K.glass);}}
        else for(const [u,sg] of [[u0,-1],[u1,1]]){const w=WU(u,sg,.06);for(let s=v0+3;s<v1-2;s+=3.6)rect(w,s,s+1.2,h0,h1,K.glass);}}
      bl(u0,v0,u1,v1);occMark(q);S.dy=0;};
    const RUST=[K.rustR,K.rustR2];
    // the old barracks: two rows of long blocks, two floors, rust zinc roofs
    bld(-45,46,-31,120,{fl:2,roof:K.rustR});bld(-15,47,0,89,{fl:2,roof:K.rustR2});bld(-45,-30,-31,35,{fl:2,roof:K.rustR2});bld(-16,-10,0,34,{fl:2,roof:K.teja});
    bld(-16,-41,0,-10,{fl:1,roof:K.metal,wall:K.cream2,win:false});bld(14,-40,21,-15,{fl:1,roof:K.metal,wall:K.cream2,win:false});
    // the drill hall: one big low shed with a grey zinc roof
    bld(14,51,45,94,{fl:2,roof:K.zinc2,wall:K.cream2,rise:3.2,win:false});
    // headquarters: a red-tiled bar with two wings, and the officers' quarters on the east wall
    bld(30,-38,45,22,{fl:2,roof:K.teja});bld(22,-14,30,8,{fl:1,roof:K.teja2});bld(30,-44,45,-38,{fl:1,roof:K.teja2});
    bld(118,62,133,110,{fl:2,roof:K.teja});bld(121,38,129,48,{fl:1,roof:K.teja2});bld(117,-22,134,15,{fl:2,roof:K.teja});bld(120,-56,132,-35,{fl:1,roof:K.teja});
    bld(91,-175,105,-137,{fl:2,roof:K.teja});bld(110,-180,131,-132,{fl:2,roof:K.teja});
    // hangars and sheds
    bld(-97,-55,-79,-19,{fl:1,roof:K.metal,wall:K.metal2,rise:3,win:false});bld(-64,-57,-52,-12,{fl:1,roof:K.metal2,wall:K.metal2,rise:2.4,win:false});
    bld(-51,164,-42,184,{fl:1,roof:K.metal,wall:K.metal2,win:false});bld(-22,225,-12,235,{fl:1,roof:K.metal,wall:K.metal2,win:false});
    bld(-2,255,5,266,{fl:1,roof:K.olive2,wall:K.cream2,win:false});bld(12,247,21,260,{fl:1,roof:K.olive2,wall:K.cream2,win:false});
    bld(47,275,126,308,{fl:1,roof:K.zinc,wall:K.metal2,rise:3,win:false});                                   // the long warehouse by 12 Norte
    bld(96,232,109,268,{fl:1,roof:K.olive,wall:K.cream2,win:false});bld(117,232,130,268,{fl:1,roof:K.olive,wall:K.cream2,win:false});
    bld(94,204,142,225,{fl:1,roof:K.teja,wall:K.cream2});bld(11,169,25,235,{fl:1,roof:K.olive,wall:K.cream2,win:false});
    bld(70,162,96,187,{fl:2,roof:K.teja});bld(92,156,116,175,{fl:2,roof:K.teja2});bld(122,150,132,185,{fl:1,roof:K.rustR2,win:false});bld(137,150,142,185,{fl:1,roof:K.rustR,win:false});
    // the pool's small house and the round quincho of the mess
    bld(9,-65,20,-52,{fl:1,roof:K.teja2});
    {const c=G(99,-210),o=ngon(c[0],c[1],4.6,8);S.dy=groundMin(o);S.prism(o,.3,3.2,K.cream2,K.cream2,false);pyramid(S,ngon(c[0],c[1],5.2,8),3.2,2.6,K.teja2);bl(94,-216,105,-204);S.dy=0;}
    {const c=G(27,-95),o=ngon(c[0],c[1],4.6,8);S.dy=groundMin(o);S.prism(o,.3,3.2,K.cream2,K.cream2,false);pyramid(S,ngon(c[0],c[1],5.2,8),3.2,2.6,K.teja2);bl(22,-100,33,-89);S.dy=0;}
    // ---- trees: the forest of the west and the east, the lines along the barracks
    {const rr=rng(4417),t=(u,v,s)=>{const p=G(u,v);if(inR(u,v)&&!inBL(u,v)&&inTerrain(p[0],p[1]))TREES.push([p[0],p[1],s,rr()]);},
        field=(u0,v0,u1,v1,n,s0)=>{for(let i=0;i<n;i++)t(u0+rr()*(u1-u0),v0+rr()*(v1-v0),s0+rr()*.5);};
      field(-146,-125,-52,125,340,1.4);field(-60,-30,12,130,50,1.2);field(46,-110,142,-40,80,1.4);field(80,50,142,130,80,1.3);field(46,-250,142,-225,14,1.1);
      field(-60,-125,60,-30,24,1.1);field(20,-100,60,-60,16,1.4);field(-90,-310,40,-170,12,1.1);field(-20,130,110,250,14,1.0);
      for(const [u,v] of [[-10,132],[-48,150],[-30,245]])t(u,v,1.4);}
    S.dy=0;}
