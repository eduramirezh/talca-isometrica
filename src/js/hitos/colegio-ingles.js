  // ==== hito: colegio-ingles ====
  // Colegio Inglés de Talca (Avenida San Miguel 5766), on S (unlisted: it has no card). The ground is OpenStreetMap's
  // school w110778737 (the same polygon the land-use layer drew generically, as ~25 identical red-roofed pavilions: that
  // use is skipped because this footprint is reserved in occ), 11.3 ha according to the school's own site
  // (colegioingles.cl/infraestructura: five pavilions "por ciclo", 52 classrooms, a gym, covered multicourts, an athletics
  // track, football fields, a climbing wall, an auditorium; colegioingles.cl/historia: on this campus since 1998). The
  // buildings are OSM's (w976147704–08, 699, 698, 703, 702, 700, 701, 696 and the gate's four) and the layout is read
  // from the Esri imagery rotated into the campus frame (satellite.py marco 6400 -2400 77.7 …: u east-south-east along
  // the campus's cross axis, v north-north-east along its long one, the campus's own grid: the long classroom blocks
  // run along u): the three long classroom blocks around two tree rows with the covered walkways between them, the
  // gym (a gabled hall with two lean-to annexes and a curved porch on its north side) in the south, the west
  // buildings (striped roofs), the east service range (two gabled bays, a flat-roofed block with skylights, a gabled
  // shed) along the parking lane, the gravel entrance yard with its loop, the central lawn with its round bed, the
  // grass football field in the middle (OSM's two pitches w502205426 and w976147695 on one big lawn, with a big tree),
  // the covered multicourt with the open court beside it (w976147696, w976147697), the synthetic-turf pitch inside the
  // red athletics track (OSM's multipolygon r13125063: w976147693 and w976147694, which is narrower than the real one:
  // the imagery shows ~7 m of red, so the inner ring is drawn 5 % smaller about its centre), the access road lined with poplars (w65736145) running north to Avenida San Miguel,
  // and the forest strip that closes the south and east sides. The imagery here is from 2015-03-31 at z19 (WorldView-3,
  // 0.31 m; the layout) and 2020-04-06 at z17 (0.5 m, which shows the same campus: the lanes and buildings did not
  // change); there is NO free photo of the school (Commons and Panoramax have nothing within 300 m): every height, wall
  // and roof colour is a guess from the imagery's shadows and the look of Chilean school pavilions (cream walls, pale
  // zinc roofs), the storeys (one, 4 m to the eaves, for the classroom blocks: the school says 52 rooms, which fits ten
  // or so in each of the five pavilions), the windows, the gym's 7.5 m walls and the covered court's 8 m roof, the
  // number and place of the trees and the cars (parked cars follow the 2015 lanes: a placeholder, not a count), and
  // every building that OSM lacks (the east service block at v -205..-228, the gabled shed south of it, the small sheds)
  // are approximate. The west wing's striped roof (blue and white panels in the imagery) is drawn as two-tone strips. Lines are 0.8 m wide: the frame is turned 12° off the art-pixel grid and 0.5 m lines break up into dots. The map's own tracks
  // inside the grounds (class 7, ~3 m off the lanes seen on the imagery) are replaced by the access road and the
  // gravel yards. No lights: nothing documents them.
  {const F=localFrame(6400,-2400,77.7*Math.PI/180),{G,Gs,V,N3,R}=F;
    const K={soil:C('#B9A47E'),gravel:C('#C9BA97'),gravel2:C('#B3A68C'),asph:C('#7D7B76'),asph2:C('#8E8B86'),path:C('#D6CFBE'),plaza:C('#CFC6B2'),
      lawn:C('#6F9D4A'),lawn2:C('#7DAA55'),field:C('#5E8E47'),field2:C('#69994F'),turf:C('#468239'),turf2:C('#4F8C41'),track:C('#B5573F'),line:C('#F1EEE4'),
      court:C('#C4BCAF'),
      cream:C('#E6DFCE'),cream2:C('#D9D1BD'),white:C('#ECE7DC'),plinth:C('#C9C3B6'),
      zinc:C('#CDC8BE'),zincP:C('#CFC2B6'),zinc2:C('#B7B6B1'),flat:C('#A8A59E'),memb:C('#E6E4DD'),blue:C('#7894AA'),redR:C('#A5503A'),
      glass:C('#3B4653'),glass2:C('#2C3540'),dark:C('#5A4636'),post:C('#8E8B86'),
      car:['#E8E8E4','#E8E8E4','#E8E8E4','#BBBFC0','#BBBFC0','#3A3D42','#3A3D42','#A8453D','#4F6D8C'].map(C),carGl:C('#2C3540')};
    const {WV,WU,rect}=facade(S,F,{tile:K.zinc,tile2:K.zinc2,white:K.white,glass:K.glass,glass2:K.glass2,gable:K.cream});
    const RING=[[6301,-2409],[6331,-2302],[6359,-2129],[6477,-2165],[6490,-2071],[6551,-2092],[6537,-2138],[6508,-2195],[6488,-2226],[6491,-2266],[6534,-2309],[6434,-2723],[6252,-2632],[6247,-2609],[6272,-2477]];
    occFill(RING,2.5);
    // the land uses inside the grounds (the generic school, OSM's pitches and track) are replaced by this model: u.keep makes usoAt
    // (76-usos.js) go on counting them, or buildBase would lay farmland parcels here and move its shared rng for every parcel east of it
    for(const u of USOS){let cx=0,cy=0;for(const p of u.r){cx+=p[0];cy+=p[1];}if(pip([cx/u.r.length,cy/u.r.length],RING))u.keep=true;}
    // the map's own tracks inside the grounds are drawn here (s.bridge: a street a landmark draws)
    streets.forEach(s=>{if(s.c===7&&s.pts.filter(p=>pip(p,RING)).length*2>=s.pts.length)s.bridge=true;});
    const rr=rng(7129),BL=[],bl=(u0,v0,u1,v1,m=2)=>{BL.push([u0-m,v0-m,u1+m,v1+m]);};
    const inBL=(u,v)=>BL.some(o=>u>o[0]&&u<o[2]&&v>o[1]&&v<o[3]);
    const UV=RING.map(p=>[(p[0]-6400)*Math.sin(77.7*Math.PI/180)-(p[1]+2400)*Math.cos(77.7*Math.PI/180),(p[0]-6400)*Math.cos(77.7*Math.PI/180)+(p[1]+2400)*Math.sin(77.7*Math.PI/180)]);
    const inR=(u,v)=>pip([u,v],UV);
    // ---- ground. Layers, each 1 cm above the last: dry soil under all (0.11); the gravel yards and parking (0.12); lawns,
    // the fields' bases, the covered court's floor, the track (0.13); paths, the road, mown bands, the infield (0.14);
    // the turf, the red cap, the runways (0.15); its bands (0.16); lines (0.17). Draped on the terrain (no pad)
    {const Lg=new GB(1<<15),lay=(q,o,c)=>{if(q.length>2)Lg.flat(q,o,c);},rc=(u0,v0,u1,v1,o,c)=>lay(R(u0,v0,u1,v1),o,c),pl=(pts,o,c)=>lay(Gs(pts),o,c),
        ell=(cu,cv,a,b,n=28)=>{const o=[];for(let i=0;i<n;i++){const t=i/n*Math.PI*2;o.push([cu+a*Math.cos(t),cv+b*Math.sin(t)]);}return o;};
      lay(RING,.11,K.soil);
      // gravel: the entrance yard with its loop, the yard round the classroom blocks and the gym, the parking lane on the east side
      pl([[-100,-44],[66,-44],[66,-250],[105,-250],[105,-290],[-100,-290]],.12,K.gravel);rc(66,-250,105,-44,.12,K.gravel2);
      pl([[45,-2],[80,-2],[80,132],[45,132]],.12,K.asph2);pl([[80,-2],[103,-2],[103,115],[80,115]],.12,K.gravel2);
      // lawns: the oval west of the blocks, the little one beside the west building, the south-west one, the central court's, the north strips
      pl(ell(-72,-169,25,15),.13,K.lawn);rc(-96,-146,-78,-136,.13,K.lawn2);rc(-96,-231,-48,-208,.13,K.lawn);rc(33,-194,62,-171,.13,K.lawn2);
      pl([[24,226],[37,226],[39,320],[20,330],[22,250]],.13,K.lawn2);pl([[45,200],[56,200],[66,240],[68,286],[62,292],[48,292],[46,230]],.13,K.lawn);
      // the central court between the blocks and the east range: paved to the north, bare earth to the south
      rc(30,-166,64,-108,.13,K.plaza);rc(30,-226,64,-196,.13,K.gravel2);
      // covered walkways and paths
      for(const [u0,v0,u1,v1] of [[28.5,-250,32.5,-100],[32.5,-165,64,-161.5],[32.5,-197,64,-194],[62,-226,65.5,-108],[-41,-225,-37,-122],[-51,-112,28.5,-109]])rc(u0,v0,u1,v1,.14,K.path);
      // the round bed in the central lawn: a pale ring and a green heart
      pl(ell(47.5,-182.5,3.4,3.4,16),.14,K.plaza);pl(ell(47.5,-182.5,1.6,1.6,12),.15,K.lawn);
      // the middle football field: one lawn (OSM's two pitches on it), mown in bands along v, with the pitches' lines
      rc(-90,-44,22,80,.13,K.field);for(let v=-44,k=0;v<80;v+=8,k++)if(k%2)rc(-90,v,22,Math.min(80,v+8),.14,K.field2);
      // an athletics track: OSM's outer ring in red, the inner one over it as the infield's lawn
      pl([[6,101],[6,100],[1,93],[-4,88],[-10,83],[-17,80],[-25,78],[-34,78],[-46,81],[-56,87],[-63,94],[-68,102],[-73,119],[-77,204],[-77,206],[-74,220],[-70,227],[-66,232],[-59,237],[-52,242],[-44,244],[-36,245],[-27,244],[-20,241],[-12,237],[-6,232],[3,220],[7,206],[11,117],[12,96]],.13,K.track);
      {const ir=[[-67,119],[-63,104],[-59,97],[-53,91],[-44,86],[-33,84],[-26,84],[-19,85],[-13,88],[-8,92],[-3,97],[1,102],[4,109],[5,117],[2,205],[-2,217],[-10,228],[-15,232],[-22,236],[-29,239],[-36,239],[-43,239],[-50,237],[-56,233],[-62,228],[-66,224],[-69,218],[-72,205]];
        pl(ir.map(p=>[-33+(p[0]+33)*.95,161+(p[1]-161)*.95]),.14,K.lawn);}
      rc(-68,108,2,213,.15,K.turf);for(let v=108,k=0;v<213;v+=10,k++)if(k%2)rc(-68,v,2,Math.min(213,v+10),.16,K.turf2);
      // the multicourt: the covered court (w976147696) and the open court beside it (w976147697)
      rc(40,-44,99,-9,.13,K.court);
      // the access road (OSM w65736145 and the two service ways to Avenida San Miguel), 6 m of asphalt
      ribbon(Lg,Gs([[33,-58],[37,19],[42,35],[42,47],[43,127],[43,139],[35,166],[39,248],[50,337],[53,350]]),6,.14,K.asph);
      // lines: the three pitches, the court's, the track's start line
      const ln=(u0,v0,u1,v1)=>rc(u0,v0,u1,v1,.17,K.line),ln15=(u0,v0,u1,v1)=>rc(u0,v0,u1,v1,.15,K.line);
      const LW=.8,out=(u0,v0,u1,v1,f=ln)=>{f(u0,v0,u1,v0+LW);f(u0,v1-LW,u1,v1);f(u0,v0,u0+LW,v1);f(u1-LW,v0,u1,v1);};
      const pitch=(cu,cv,w,l,f=ln)=>{const a=cu-w/2,b=cu+w/2,c=cv-l/2,d=cv+l/2,pw=Math.min(40.3,w*.58),pd=Math.min(16.5,l*.16),gw=pw*.45,gd=pd*.33;
        out(a,c,b,d,f);f(a,cv-LW/2,b,cv+LW/2);
        for(let i=0;i<16;i++){const t0=i/16*Math.PI*2,t1=(i+1)/16*Math.PI*2,P=(r,t)=>[cu+r*Math.cos(t),cv+r*Math.sin(t)];lay(Gs([P(8.8,t0),P(8.8,t1),P(9.6,t1),P(9.6,t0)]),f===ln?.17:.15,K.line);}
        out(cu-pw/2,c,cu+pw/2,c+pd,f);out(cu-pw/2,d-pd,cu+pw/2,d,f);out(cu-gw/2,c,cu+gw/2,c+gd,f);out(cu-gw/2,d-gd,cu+gw/2,d,f);};
      pitch(-33,160,69,104);                                                                        // the turf pitch inside the track (w502205427)
      pitch(-50,27,60,98,ln15);pitch(1,4,40,74,ln15);                                                // the grass pitches (w502205426, w976147695), over the lawn's bands
      out(40.4,-44,98.8,-9,ln15);ln15(60.6,-44,61.4,-9);ln15(79.4,-44,80.2,-9);                       // the courts
      const d=drape(Lg);S.dy=0;
      for(let t=0;t<d.ni;t+=3){const k=d.I[t]*3;S.face([0,1,2].map(j=>{const m=d.I[t+j]*3;return [d.P[m],d.P[m+1],d.P[m+2]];}),[0,1,0],[d.C[k],d.C[k+1],d.C[k+2]]);}}
    // the keep-out boxes for the random trees: the pitches, the track, the courts, the lawns, the yards, the road and every building below
    bl(-100,-44,25,82,0);bl(-80,76,15,248,0);bl(40,-44,100,-8,0);bl(28,-50,50,340,3);bl(45,-4,104,135,0);
    // ---- buildings. blk: a block with a gabled roof (ridge along u or v) or a flat one with a parapet; wins: rows of dark
    // windows along its long sides (st storeys), and a pale plinth
    const blk=(u0,v0,u1,v1,o)=>{const h=o.h,wall=o.wall||K.cream,alongU=o.ax?o.ax==='u':(u1-u0)>=(v1-v0),q=alongU?R(u0,v0,u1,v1):Gs([[u0,v0],[u0,v1],[u1,v1],[u1,v0]]);
      S.dy=groundMin(Gs([[u0,v0],[u1,v0],[u1,v1],[u0,v1]]));
      if(o.flat){S.prism(R(u0,v0,u1,v1),.3,h+.5,wall,wall,false);S.quadXY(R(u0,v0,u1,v1),h,o.roof||K.flat);}
      else S.gable(q,.3,h,o.rise??Math.min(3,Math.min(u1-u0,v1-v0)*.2),wall,o.roof||K.zinc);
      const st=o.st??1,sh=o.sh??4;
      if(o.win!==false)for(let k=0;k<st;k++){const h0=1.2+k*sh,h1=h0+1.7,c=k%2?K.glass2:K.glass;
        for(const [w,s0,s1] of [[WV(v0,-1,.06),u0,u1],[WV(v1,1,.06),u0,u1]])for(let s=s0+2.4;s<s1-1.8;s+=3.6)rect(w,s,s+1.3,h0,h1,c);
        if(o.ends)for(const [w,s0,s1] of [[WU(u0,-1,.06),v0,v1],[WU(u1,1,.06),v0,v1]])for(let s=s0+2.4;s<s1-1.8;s+=3.6)rect(w,s,s+1.3,h0,h1,c);}
      bl(u0,v0,u1,v1);occMark(Gs([[u0,v0],[u1,v0],[u1,v1],[u0,v1]]));S.dy=0;};
    // the three long classroom blocks (w976147704, w976147705, w976147706): one storey, pale zinc roof over cream walls
    blk(-30,-143,26,-125,{h:4,rise:2.4,roof:K.zincP,ends:1});blk(-31,-173,26,-155,{h:4,rise:2.4,roof:K.zincP,ends:1});blk(-31,-204,25,-186,{h:4,rise:2.4,roof:K.zincP,ends:1});
    // the west buildings: w976147699 (a flat-roofed L; its west wing under striped panels), w976147707 and the L of w976147708
    {const q=Gs([[-42,-119],[-72,-119],[-72,-112],[-96,-112],[-96,-96],[-63,-96],[-63,-102],[-42,-102]]);S.dy=groundMin(q);
      S.prism(q,.3,4.9,K.cream,K.cream,false);S.flat(q,4.4,K.flat);
      for(let u=-96,k=0;u<-76;u+=2,k++)S.quadXY(R(u,-112,u+2,-96),4.43,k%2?K.blue:K.memb);S.quadXY(R(-76,-112,-63,-96),4.43,K.memb);
      for(const [w,s0,s1] of [[WV(-119,-1,.06),-72,-42],[WV(-96,1,.06),-96,-63],[WV(-112,-1,.06),-96,-72]])for(let s=s0+2.4;s<s1-1.8;s+=3.6)rect(w,s,s+1.3,1.2,2.9,K.glass);
      bl(-96,-119,-42,-96);occMark(q);S.dy=0;}
    blk(-67,-203,-43,-186,{h:4,rise:2.2,roof:K.zinc,ends:1});
    blk(-78,-244,-40,-227,{h:4,rise:2.4,roof:K.zinc,ends:1});blk(-50,-255,-34,-234,{h:7,flat:1,roof:K.memb,st:2,sh:3.4});blk(-34,-255,-12,-238,{h:4,rise:2.2,roof:K.zinc,ends:1});
    // the east service range: w976147700, w976147703 (two gabled bays, then a narrow wing), w976147702, the flat block with two skylights
    // that OSM lacks (read from the imagery), the gabled shed south of it, and w976147701
    blk(68,-132,81,-112,{h:3.8,rise:2,roof:K.zinc,ends:0});blk(88,-121,99,-114,{h:3,rise:1.6,roof:K.zinc2,win:false});
    blk(68,-165,77,-138,{h:4.2,rise:2.2,roof:K.zinc,ax:'v',win:false});blk(77,-165,86,-138,{h:4.2,rise:2.2,roof:K.zinc2,ax:'v',win:false});
    blk(68,-196,76,-165,{h:4.2,rise:2.2,roof:K.zinc,ax:'v',win:false});blk(65,-205,83,-196.5,{h:4.2,rise:2,roof:K.zinc,win:false});
    blk(69,-227,85,-205,{h:5,flat:1,roof:K.memb,win:false});S.dy=groundMin(R(70,-222,74,-218));for(const u of [72.5,78.5])S.prism(R(u,-216,u+2.4,-213.6),5,5.9,K.white,K.white);S.dy=0;
    blk(69,-247,81,-229,{h:4.2,rise:2.6,roof:K.memb,ax:'v',win:false});
    // the gym: a gabled hall (ridge along v) with two white lean-to annexes and a curved porch on its north side (w976147698)
    {const q=Gs([[14,-273],[14,-232],[44,-232],[44,-273]]);S.dy=groundMin(q);S.gable(q,.3,7.5,3.6,K.cream2,K.memb);
      for(const [u0,u1] of [[7.5,14],[44,50.6]]){const a=R(u0,-265,u1,-243);S.dy=groundMin(a);S.prism(a,.3,4,K.cream2,K.memb);}
      S.dy=groundMin(q);const po=[];for(let i=0;i<=10;i++){const t=Math.PI*i/10;po.push([29+15*Math.cos(t),-232+6*Math.sin(t)]);}
      S.prism(Gs(po),.3,4.6,K.cream2,K.memb);
      for(const w of [WV(-273,-1,.06)])for(let s=17;s<41;s+=4.5)rect(w,s,s+1.6,2.5,6,K.glass);
      for(const w of [WU(14,-1,.06),WU(44,1,.06)])for(let s=-268;s<-236;s+=5.5)rect(w,s,s+1.6,3,6,K.glass);
      bl(7,-273,51,-226);occMark(Gs([[7,-273],[51,-273],[51,-226],[7,-226]]));S.dy=0;}
    // the covered multicourt: a white roof on steel posts over the court (w976147696), 8 m up
    {const q=R(40.4,-43.7,61.1,-8.9);S.dy=groundMin(q);const gq=Gs([[40.4,-43.7],[61.1,-43.7],[61.1,-8.9],[40.4,-8.9]]);
      {const u0=40.4,u1=61.1,v0=-43.7,v1=-8.9,um=(u0+u1)/2,h=7.2,rh=1.8,hw=(u1-u0)/2;
        S.face([V(u0-.4,v0,h-.2),V(u0-.4,v1,h-.2),V(um,v1,h+rh),V(um,v0,h+rh)],N3(-rh,0,hw),K.memb);S.face([V(u1+.4,v0,h-.2),V(u1+.4,v1,h-.2),V(um,v1,h+rh),V(um,v0,h+rh)],N3(rh,0,hw),K.zinc);
        S.face([V(u0-.4,v0,h-.2),V(u1+.4,v0,h-.2),V(um,v0,h+rh)],N3(0,-1,0),K.cream2);S.face([V(u0-.4,v1,h-.2),V(u1+.4,v1,h-.2),V(um,v1,h+rh)],N3(0,1,0),K.cream2);}
      for(const u of [41.2,60.3])for(let v=-43;v<-8;v+=8.7)S.prism(R(u-.4,v-.4,u+.4,v+.4),.3,7.2,K.post,K.post);
      occMark(gq);S.dy=0;}
    // small buildings: the shed south of the middle field, the shelter north of the track and the four kiosks at the north gate (w976147689, w976147690–92)
    blk(-62,-48,-42,-41,{h:3,rise:1.2,roof:K.memb,win:false});blk(13,239,20,245,{h:3,flat:1,roof:K.memb,win:false});
    blk(40,318.5,44,322.2,{h:2.8,rise:1,roof:K.redR,win:false});blk(50.4,317.5,54.2,321.1,{h:2.8,rise:1,roof:K.redR,win:false});blk(64.7,304.6,73.2,311.6,{h:3.2,rise:1.4,roof:K.zinc2,win:false});
    // ---- parked cars (a body and a cabin): the east lane in two columns, the entrance yard's right side and its middle
    {const car=(u,v,al)=>{const c=K.car[Math.floor(rr()*K.car.length)],q=al?R(u-2.1,v-.9,u+2.1,v+.9):R(u-.9,v-2.1,u+.9,v+2.1),q2=al?R(u-1.1,v-.8,u+1.1,v+.8):R(u-.8,v-1.1,u+.8,v+1.1),p=G(u,v);
        if(!inTerrain(p[0],p[1]))return;S.dy=E(p[0],p[1]);S.prism(q,.13,1,c,c);S.prism(q2,1,1.55,K.carGl,c);S.dy=0;};
      for(let v=-128;v>-226;v-=2.8)if(rr()<.9)car(88.7,v,true);
      for(let v=-112;v>-228;v-=2.7)if(rr()<.92)car(97.2,v,true);
      for(let v=-56;v>-102;v-=2.8)if(rr()<.7)car(88,v,true);
      for(const [u,v] of [[-12,-60],[-6,-60],[2,-63],[12,-78],[16,-78],[-10,-78],[-20,-84],[4,-84],[20,-95],[-30,-70]])if(rr()<.8)car(u,v,rr()<.5);}
    // ---- trees: rows between the blocks, the west court, the forest strips along the south, east and west sides, the avenue's poplars
    {const t=(u,v,s)=>{const p=G(u,v);if(inR(u,v)&&!inBL(u,v)&&inTerrain(p[0],p[1]))TREES.push([p[0],p[1],s,rr()]);},
        field=(u0,v0,u1,v1,n,s0)=>{for(let i=0;i<n;i++)t(u0+rr()*(u1-u0),v0+rr()*(v1-v0),s0+rr()*.5);},
        row=(u0,u1,v,n,s0)=>{for(let i=0;i<n;i++)TREES_RAW(u0+(u1-u0)*(i+.5)/n+(rr()-.5)*2,v+(rr()-.5)*3,s0+rr()*.3);},
        TREES_RAW=(u,v,s)=>{const p=G(u,v);if(inR(u,v)&&inTerrain(p[0],p[1]))TREES.push([p[0],p[1],s,rr()]);};
      row(-30,26,-116,10,1.1);row(-28,26,-149,10,1.1);row(-28,26,-181,10,1.1);row(-28,25,-210,9,1.1);
      for(const [u,v] of [[-86,-110],[-88,-122],[-80,-130],[-92,-124],[-76,-118],[-70,-138],[-82,-140],[-74,-128],[-68,-124],[-62,-132]])TREES_RAW(u,v,1.2+rr()*.3);
      for(let v=-155;v>-185;v-=7)TREES_RAW(-38,v,1.2);
      for(let i=0;i<9;i++)TREES_RAW(34+rr()*28,-224+rr()*26,1+rr()*.5);for(let i=0;i<4;i++)TREES_RAW(-50+rr()*30,-232+rr()*20,1.1+rr()*.5);
      field(-108,-250,-96,-110,22,1.3);field(-95,-300,100,-268,60,1.5);field(97,-300,111,-110,48,1.4);
      field(20,255,62,335,18,1.3);field(-104,-30,-96,70,8,1.2);
      TREES_RAW(-35,10,2.6);                                                                         // the big tree in the middle of the field
      // the poplars along the access road (w65736145), both sides
      {const pts=[[33,-58],[37,19],[42,35],[42,47],[43,127],[43,139],[35,166],[39,248],[50,337]];
        for(let i=0;i<pts.length-1;i++){const a=pts[i],b=pts[i+1],L=Math.hypot(b[0]-a[0],b[1]-a[1]),nx=-(b[1]-a[1])/L,ny=(b[0]-a[0])/L;
          for(let s=0;s<L;s+=7.5)for(const sd of [-1,1]){if(rr()<.2)continue;const u=a[0]+(b[0]-a[0])*s/L+nx*sd*(sd<0?6.5:5.5),v=a[1]+(b[1]-a[1])*s/L+ny*sd*(sd<0?6.5:5.5),p=G(u,v);
            if(inR(u,v)&&inTerrain(p[0],p[1]))PO_FIELD.push([p[0],p[1],.75+rr()*.25,rr()]);}}}}
    S.dy=0;}
