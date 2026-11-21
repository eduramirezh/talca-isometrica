  // ==== hito: juegos-alameda ====
  // The playground of the Alameda between 3 and 4 Oriente, and its whole stretch of the Alameda (ALAM_OWN: the map's
  // paseo, round plaza, plinth, benches, lamps and rows of trees would run through it). Not a place of pois.py.
  // Plan from OpenStreetMap: the fenced playground w1421055220 (leisure=playground, barrier=fence; 82 x 29.5 m,
  // x 331-413, y 496-525.5, turned 0.6° off the grid: drawn on it) with its two gates on the axis (n13058892789 west,
  // n13058892788 east), the hut w1421055218 west of it, the trees of the stretch (n13067152469-536, natural=tree) and
  // the tree rows w1421875934-40, all mapped in August 2025. Frame: u east, v north, on the grid (A = 90°), origin at
  // the playground's centre.
  // What stands inside, from Mapillary (CC BY-SA 4.0; docs/FUENTES.md): the 360° panoramas driven along both
  // carriageways on 2023-11-30 and 2024-09-28. Nothing was photographed inside the fence: each structure was placed
  // from its bearing in panoramas on both sides (poles every 5 m along the axis, drawn with each image's computed
  // camera; the 2024 north drive comes out 3.7 m west against the gates and the corners of the fence, and was moved
  // back). The fence is a low yellow wall (~0.6 m) with square pillars (~1.3 m) every ~8 m and tall posts at the two
  // gates, on maicillo; maicillo paths run round it between the lawns, and a sandy forecourt reaches 3 Oriente. West to
  // east: in the north-west corner a one-storey shed with a grey sheet roof (dark red roller shutters and a grey grille
  // to the north, a dark slatted pergola to the south) and a red board fence east of it; a red swing frame; a small
  // structure of yellow posts and arches with red and pink slides; in the middle the big one, a tall beige timber tower
  // with a box roof, an orange tube slide and a teal panel, joined to a pink tower with a cream pointed roof, a wide
  // metal slide and a grey concrete border to the south; to the east a platform with teal railings, a turret with a white
  // hipped roof, a blue spiral slide and a blue straight one; outside the east gate a brown sign on two posts; on the
  // paths dark benches, black lamp posts and green bins; outside the west end OSM's hut, painted orange, and a cabinet
  // covered in green graffiti.
  // Approximate: every position inside (along the playground ±2 m; across it, from two nearly opposite sides, ±4 m),
  // every size and height (no photo measures them: guessed against the wall's pillars and the people next to them),
  // the shed's plan (OSM's tree n13067152469 falls on it: that tree goes 5 m east, where a trunk stands between the shed
  // and the fence), how many swings, the paths' widths and the east end (concrete paths, from the 2023 panoramas), the
  // sign's text (a pale band). Licence: the wall 0.6 m thick, the railings solid panels, the posts 0.5 m (thinner, the
  // art pixel leaves only their outline), and the trees, OSM's points with the rows split every ~7 m, smaller than the
  // Alameda's (1.25-1.6): 0.85-1.0 inside the fence and 1.15-1.4 outside; at full size their crowns hide every
  // structure from the map's camera. The 2025 Airbus image under satellite.py shows only the canopy. Method:
  // docs/METODOLOGIA.md §9 (mapillary.py postes and cruce); style: docs/ESTETICA.md.
  {const X=372,Y=510.9,F=localFrame(X,Y,Math.PI/2),{G,V,N3,R}=F,rr=rng(4417);
    const K={...KH,yellow:C('#E6C434'),cap:C('#F2DA62'),sand:C('#D2BF92'),gravel:PAL.gravel,edge:PAL.edging,conc:C('#C3C1BA'),
      wood:C('#B98E5C'),panel:C('#D9C39A'),hood:C('#E2D3B2'),hoodTop:C('#EFE5CF'),orange:C('#E8832E'),orange2:C('#D06A22'),teal:C('#36B0A4'),
      pink:C('#DE6F90'),cream:C('#F0E7D6'),cream2:C('#D6CCB8'),metal:C('#C4C8CA'),metal2:C('#AEB3B6'),lilac:C('#9A86C8'),red:C('#D23A30'),red2:C('#B32C25'),
      pink2:C('#E2809E'),post:C('#EDC02C'),rails:C('#36B5A6'),deck:C('#8E9A9C'),roofW:C('#EEEBE4'),roofW2:C('#CFCAC0'),
      blue:C('#5F66DE'),blue4:C('#4B52C4'),blue2:C('#3D72D6'),blue3:C('#7FA6E8'),swing:C('#C8402F'),swing2:C('#DA5A45'),shedWall:C('#A8A39A'),shedRoof:C('#8F8D88'),
      shutter:C('#8B3A30'),grille:C('#5E6262'),slat:C('#4D4843'),slat2:C('#5F5A53'),board:C('#9C3B31'),hut:C('#C9673B'),
      hutRoof:C('#5B4B43'),graffiti:C('#4F8A5B'),grey:C('#9C9A94'),grey2:C('#BDBAB2'),bench:C('#4C3B2F'),bench2:C('#5E4A3A'),
      iron:C('#3B4240'),lamp:C('#F1E6C4'),sign:C('#8A4A2C'),signText:C('#E8E2D4'),bin:C('#2F6E45')};
    const {hipped}=facade(S,F,K),bi=blockAt(X,Y);if(ALAM.has(bi))ALAM_OWN.add(bi);
    const U0=-41,U1=41,V0=-14.6,V1=14.6,WT=.6;               // the fence's wall, on its inner face, and its thickness
    occMark(R(U0-.5,V0-.5,U1+.5,V1+.5));occMark(R(-51.5,-11.5,-47.6,-7.1));
    // O: the origin of the structure being drawn, (u,v) of the frame (each play structure is written round where it
    // was drawn first and moved to where mapillary.py cruce puts it)
    let O=[0,0];const Ro=(u0,v0,u1,v1)=>R(u0+O[0],v0+O[1],u1+O[0],v1+O[1]),W=(u,v,h)=>V(u+O[0],v+O[1],h);
    const gnd=(u0,v0,u1,v1)=>groundMin(Ro(u0,v0,u1,v1));
    const bx=(u0,v0,u1,v1,h0,h1,w,t)=>S.prism(Ro(u0,v0,u1,v1),h0,h1,w,t||w);
    const put=(u0,v0,u1,v1,h0,h1,w,t)=>{S.dy=gnd(u0,v0,u1,v1);bx(u0,v0,u1,v1,h0,h1,w,t);};
    // ---- the ground: maicillo paths round the fence with a darker edging (the Alameda's), the forecourt to 3 Oriente,
    // concrete from the east gate to 4 Oriente, the playground's sand (none of them overlaps another at its height)
    {const L=groundLayer(S,1<<13,F),ye=Y_LAYER.alamEdge,yg=Y_LAYER.alamGravel;
      const paths=[[-44.6,-18.4,44.6,-14.6-WT],[-44.6,14.6+WT,44.6,18.4],[41+WT,-14.6-WT,44.6,14.6+WT],[-44.6,-14.6-WT,-41-WT,14.6+WT]];
      const fore=[[-55.5,-20],[-44.6,-20],[-44.6,20],[-55.5,20],[-56.5,17],[-56.5,-17]];
      for(const [u0,v0,u1,v1] of paths)L.rc(u0-.8,v0-.8,u1+.8,v1+.8,ye,K.edge);
      L.pl([[-56.3,-20.8],[-44.6,-20.8],[-44.6,20.8],[-56.3,20.8],[-57.3,17.6],[-57.3,-17.6]],ye,K.edge);
      L.rc(44.6,-2.6,58.6,2.6,ye,K.edge);
      for(const [u0,v0,u1,v1] of paths)L.rc(u0,v0,u1,v1,yg,K.gravel);
      L.pl(fore,yg,K.gravel);L.rc(44.6,-2,58.6,2,yg,K.conc);
      L.rc(U0-WT,V0-WT,U1+WT,V1+WT,yg,K.sand);L.done();}
    // ---- the fence: a low yellow wall, pillars every 8.2 m on the long sides and halfway on the short ones, two tall
    // posts at each gate (3.2 m wide, on the axis). Thicker than the real one (0.6 m, not ~0.25): thinner, the art pixel
    // leaves only its dark outline
    {const H=.7,wall=(u0,v0,u1,v1)=>put(u0,v0,u1,v1,0,H,K.yellow,K.cap),pil=(u,v,h=1.5,s=.4)=>put(u-s,v-s,u+s,v+s,0,h,K.yellow,K.cap);
      for(let k=0;k<10;k++){const a=U0+k*8.2,b=a+8.2;wall(a,V0-WT,b,V0);wall(a,V1,b,V1+WT);}
      for(const u of [U0-WT,U1])for(const [a,b] of [[V0-WT,-1.6],[1.6,V1+WT]])wall(u,a,u+WT,b);
      for(let k=0;k<=10;k++){const u=Math.min(U1+WT/2,Math.max(U0-WT/2,U0+k*8.2));pil(u,V0-WT/2);pil(u,V1+WT/2);}
      for(const u of [U0-WT/2,U1+WT/2]){pil(u,-7.4);pil(u,7.4);for(const v of [-2.05,2.05])pil(u,v,2.6,.45);}}
    // the play structures' parts, in (u,v) on S at S.dy: a slide from p to q ([u,v,h]) w wide, in k bays of two tones,
    // with its sides; a tube slide, n blocks of 1 m turning round (cu,cv) from h down
    const slide=(p,q,w,c1,c2,k=4)=>{const L=Math.hypot(q[0]-p[0],q[1]-p[1]),nu=-(q[1]-p[1])/L*w/2,nv=(q[0]-p[0])/L*w/2;
      for(let i=0;i<k;i++){const P=t=>[p[0]+(q[0]-p[0])*t,p[1]+(q[1]-p[1])*t,p[2]+(q[2]-p[2])*t],a=P(i/k),b=P((i+1)/k),c=i%2?c2:c1;
        S.face([W(a[0]-nu,a[1]-nv,a[2]),W(a[0]+nu,a[1]+nv,a[2]),W(b[0]+nu,b[1]+nv,b[2]),W(b[0]-nu,b[1]-nv,b[2])],null,c);
        for(const sg of [-1,1])S.face([W(a[0]+sg*nu,a[1]+sg*nv,a[2]),W(b[0]+sg*nu,b[1]+sg*nv,b[2]),W(b[0]+sg*nu,b[1]+sg*nv,b[2]+.35),W(a[0]+sg*nu,a[1]+sg*nv,a[2]+.35)],N3(sg*nu,sg*nv),c1);}};
    const hip=(u0,v0,u1,v1,...r)=>hipped(u0+O[0],v0+O[1],u1+O[0],v1+O[1],...r);
    const tube=(cu,cv,a0,h,n,c1,c2)=>{for(let i=0;i<n;i++){const a=a0+i*Math.PI/2,u=cu+Math.cos(a)*1.05,v=cv+Math.sin(a)*1.05,z=h-i*.55;
      bx(u-.5,v-.5,u+.5,v+.5,Math.max(.32,z-.5),z+.45,i%2?c2:c1);}};
    // a tower of the structures: four posts (pw) up to top, a deck at pl (its top in deck), solid side panels from the
    // deck up 0.9 m (the railings: open, they would be noise at this scale) on the sides in `sides` (s, n, w, e)
    const tower=(u0,v0,u1,v1,pl,top,post,deck,panel,sides='snwe',pw=.5)=>{
      for(const [u,v] of [[u0,v0],[u1-pw,v0],[u0,v1-pw],[u1-pw,v1-pw]])bx(u,v,u+pw,v+pw,0,top,post);
      bx(u0,v0,u1,v1,pl-.2,pl,post,deck);const t=.25;
      for(const [c,q] of [['s',[u0,v0,u1,v0+t]],['n',[u0,v1-t,u1,v1]],['w',[u0,v0,u0+t,v1]],['e',[u1-t,v0,u1,v1]]])if(sides.includes(c))bx(...q,pl,pl+.9,panel);};
    // ---- the big structure in the middle: the beige tower (box roof, orange tube slide to the west, a teal climbing
    // panel to the south), a bridge to the pink tower (cream pointed roof, a lilac net to the east), a wide metal slide
    // to the north and a grey concrete border to the south
    {O=[.8,3.2];S.dy=gnd(-7,-8.5,6,4);const pl=1.6;
      tower(-3.6,-3.2,-1.2,-.8,pl,3.6,K.wood,K.panel,K.panel,'snw');
      bx(-3.9,-3.5,-.9,-.5,3.6,4.8,K.hood,K.hoodTop);                                              // the box roof
      tube(-5.1,-2,Math.PI/2,2.8,5,K.orange,K.orange2);
      bx(-3.6,-3.6,-1.2,-3.2,.32,pl,K.teal);                                                        // the climbing panel
      bx(-1.2,-2.8,1.8,-1.2,pl-.2,pl,K.wood,K.panel);bx(-1.2,-2.8,1.8,-2.55,pl,pl+.8,K.pink);bx(-1.2,-1.45,-.3,-1.2,pl,pl+.8,K.pink);
      tower(1.8,-3.2,4.2,-.8,pl,2.9,K.wood,K.panel,K.pink,'sne');hip(1.8,-3.2,4.2,-.8,2.9,1.7,K.cream,K.cream2,{o:.3});
      bx(4.2,-2.8,4.6,-1.2,.32,pl+.9,K.lilac);
      slide([.75,-1.2,pl],[.75,2.9,.35],1.2,K.metal,K.metal2);
      bx(-3,-7.9,2.5,-5.4,0,.45,K.grey,K.grey2);O=[0,0];}
    // ---- the small structure to the west: yellow posts under a yellow canopy (the arches), a beige drum on top, a red
    // slide to the south and a pink one to the east
    {O=[0,-1.1];S.dy=gnd(-18,-6.5,-9.5,1);const pl=1;
      tower(-17.2,-2.6,-12.8,.6,pl,2,K.post,K.panel,K.post,'nw');
      bx(-17.4,-2.8,-12.6,.8,2,2.35,K.post,K.cap);bx(-16.6,-2,-13.4,0,2.35,2.6,K.post,K.cap);      // the canopy, stepped
      bx(-15.6,-1.6,-14.4,-.4,2.6,3.2,K.panel,K.hood);
      slide([-15.8,-2.6,pl],[-15.8,-5.8,.35],1,K.red,K.red2,3);slide([-12.8,-1,pl],[-9.8,-1,.35],1,K.pink2,K.pink,3);O=[0,0];}
    // ---- the swings: a red frame with two seats
    {S.dy=gnd(-28.6,-7.4,-23,-4.6);
      for(const u of [-28.4,-23.6])for(const v of [-7.2,-5.2])bx(u,v,u+.45,v+.45,0,2.4,K.swing);
      bx(-28.4,-6.5,-23.15,-5.95,2.4,2.85,K.swing,K.swing2);for(const u of [-27.2,-25.3])bx(u,-6.6,u+.9,-5.85,.45,.75,K.red);}
    // ---- the east structure: a platform with teal railings, a turret with a white hipped roof, a blue spiral slide to
    // the north-east and a striped blue one to the south
    {O=[-2.6,.6];S.dy=gnd(26,-1,34.5,10);const pl=1.3;
      tower(29.4,3.4,33.8,6.8,pl,pl+.9,K.rails,K.deck,K.rails,'ne');
      bx(29.4,3.4,30.2,3.65,pl,pl+.9,K.rails);bx(31.6,3.4,33.8,3.65,pl,pl+.9,K.rails);bx(29.4,4.8,29.65,6.8,pl,pl+.9,K.rails);
      for(const [u,v] of [[31.8,4.6],[33.3,4.6],[31.8,6.3],[33.3,6.3]])bx(u,v,u+.5,v+.5,pl,3.1,K.rails);
      hip(31.8,4.6,33.8,6.8,3.1,1.2,K.roofW,K.roofW2,{o:.3});
      tube(32.8,8,Math.PI,2.1,4,K.blue,K.blue4);
      slide([30.9,3.4,pl],[30.9,.2,.35],1.2,K.blue2,K.blue3);O=[0,0];}
    // ---- the shed in the north-west corner, its pergola to the south, the red board fence east of it
    {const w0=-38.5,w1=-28,s0=4.6,s1=10.6,h=2.7;S.dy=gnd(w0,-.4,w1,s1);
      bx(w0,s0,w1,s1,0,h,K.shedWall,K.shedRoof);bx(w0-.3,s0-.3,w1+.3,s1+.3,h,h+.2,K.shedRoof);
      const n=N3(0,1),f=(a,b,h0,h1,col)=>S.face([V(a,s1+.06,h0),V(b,s1+.06,h0),V(b,s1+.06,h1),V(a,s1+.06,h1)],n,col);
      f(-36,-33.5,.3,2.2,K.shutter);f(-33,-30.5,.3,2.2,K.shutter);f(-38,-36.4,.8,2.2,K.grille);
      for(const [u,v] of [[w0+.2,-.4],[w1-.5,-.4],[(w0+w1)/2,-.4]])bx(u,v,u+.3,v+.3,0,2.4,K.slat);
      for(let u=w0+.2,k=0;u<w1-.2;u+=.8,k++)bx(u,-.4,Math.min(u+.5,w1-.2),s0,2.4,2.6,k%2?K.slat2:K.slat);
      put(-27,9.6,-19.5,10.1,0,2,K.board);}
    // ---- outside the west end: OSM's hut (orange) and the graffiti cabinet
    put(-51.2,-11.2,-47.9,-7.4,0,2.5,K.hut,K.hutRoof);put(-53.4,-10.4,-52.4,-9.6,0,1.6,K.graffiti);
    // ---- the paths' furniture: benches on the lawn side facing the fence, lamps on the fence side, two bins; the sign
    // outside the east gate
    for(const u of [-32,-16,0,16,32])for(const sg of [-1,1]){const v=sg*18.95;put(u-1.1,v-.3,u+1.1,v+.3,0,.75,K.bench,K.bench2);}
    for(const u of [-36,-20,-4,12,28])for(const sg of [-1,1]){const u2=u+(sg>0?8:0),v=sg*15.6,p=G(u2,v);
      put(u2-.15,v-.15,u2+.15,v+.15,0,4.4,K.iron);bx(u2-.45,v-.45,u2+.45,v+.45,4.4,4.8,K.iron,K.lamp);GLOW.push(p[0],S.dy+4.6,p[1]);}
    put(-30,18.7,-29.5,19.2,0,.9,K.bin);put(20,-19.2,20.5,-18.7,0,.9,K.bin);
    {S.dy=gnd(45.2,-2,46,2);for(const v of [-1.9,1.6])bx(45.4,v,45.7,v+.3,0,3.1,K.door);
      S.prism(R(45.35,-2.1,45.75,2.1),2.2,3.1,K.sign,K.sign);
      S.face([V(45.81,-1.6,2.45),V(45.81,1.6,2.45),V(45.81,1.6,2.85),V(45.81,-1.6,2.85)],N3(1,0),K.signText);}
    // ---- the trees, OSM's: one by one, and the rows split every ~7 m (the ones inside the fence a little smaller)
    {const tree=(x,y,s)=>{if(inTerrain(x,y))TREES.push([x,y,s,rr()]);};
      const one=[[345.3,517.5],[350.6,518.9],[329.7,518.0],[332.3,503.3],[415.2,519.8],[406.7,520.5],[422.6,518.6],[416.6,531.0],
        [410.9,531.2],[403.0,531.2],[391.8,530.6],[383.1,531.0],[376.9,531.0],[371.8,530.9],[364.8,530.6],[357.4,530.6],[345.5,530.7],
        [338.3,530.7],[325.5,530.3],[423.7,500.9],[322.8,485.9],[321.8,491.0],[398.4,491.5],[391.0,491.2],[404.8,491.3],[412.8,491.7],
        [362.4,490.8],[354.2,491.0],[345.5,490.6],[336.7,490.6],[344.7,485.6],[336.4,486.1]];
      const rows=[[360.8,518.8,382.2,519.3,4],[376.7,501.3,409.5,501.6,6],[338.4,500.9,361.2,500.8,4],[362.9,485.5,415.3,485.8,8]];
      const inside=(x,y)=>x>X+U0&&x<X+U1&&y>Y+V0&&y<Y+V1;
      for(const [x,y] of one)tree(x,y,inside(x,y)?.85+rr()*.15:1.15+rr()*.25);
      for(const [xa,ya,xb,yb,n] of rows)for(let i=0;i<n;i++){const t=i/(n-1),x=xa+(xb-xa)*t,y=ya+(yb-ya)*t;tree(x,y,inside(x,y)?.85+rr()*.15:1.15+rr()*.25);}}
    MODELS['juegos-alameda']={x:X,y:Y,h:5};S.dy=0;}
