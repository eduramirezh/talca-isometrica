  // ==== hito: calles-plaza ====
  // The four streets around the Plaza de Armas (1 Norte, 1 Sur, 1 Oriente, 1 Poniente: Cardenal Raúl Silva
  // Henríquez) and their runs up to 132 m from the plaza, as the game reads them (modelo3d/modelos/calles.gd, which has
  // the sources of each piece): concrete slabs on the carriageway (OSM surface=concrete; the photo of 1 Norte, 2022),
  // asphalt on 1 Oriente; dashed lane lines; cast-iron street lamps, dark green, every ~24 m on the blocks' side of
  // the plaza and on both sides of the runs (photos of 1 Norte, 2022, and of the Catedral, 2017–2024); the traffic
  // lights at OSM's highway=traffic_signals nodes, on the right-hand curb of the cars that arrive, facing them; the
  // street trees at OSM's natural=tree nodes (DATA.plaza, from data/plaza-osm.json; build.py) instead of
  // the generated ones. Drawn on the map's streets, not on the game's kerbs: the map's carriageways (by class, on the
  // graph's axis) lie up to ~2 m off the real ones. At the art pixel's scale (ESTETICA §2) the lamp and the light are
  // 0.4 m poles with a lantern or a head, the lane lines 0.4 m wide (real: 0.12). Approximate: where each lamp stands
  // (~24 m apart, as in the game), the lane lines (3 m every 8 m), the size of the trees (OSM gives no species).
  // The pads already registered are applied to the terrain while this block is drawn, as the Colegio De La Salle:
  // last in ORDER.
  onFinalTerrain(()=>{
    const Z0=132,inZ=(x,y)=>Math.abs(x)<=Z0&&Math.abs(y)<=Z0,ZONE=[[-Z0,-Z0],[Z0,-Z0],[Z0,Z0],[-Z0,Z0]];
    const K={...KH,concrete:C('#8E8C86'),iron:C('#24322B'),iron2:C('#2E3E35'),lantern:C('#E6DDB8'),grey:C('#3A3C3C'),black:C('#1D1D1D'),red:C('#D8452F')};
    const NAMES=/^(Calle 1 Norte|Calle 1 Sur|Calle 1 Oriente|Cardenal Raúl Silva Henríquez)$/;
    const near=s=>s.pts.some(p=>inZ(p[0],p[1]));
    const sts=streets.filter(s=>s.c<=5&&!s.bridge&&NAMES.test(s.name||'')&&near(s));
    // the plaza's rounded corners (OSM secondary_link: unnamed in the graph), wholly within 70 m of the plaza
    const links=streets.filter(s=>s.c<=5&&!s.bridge&&s.name==='Calle sin nombre'&&s.pts.every(p=>Math.abs(p[0])<70&&Math.abs(p[1])<70));
    // concrete everywhere in the zone but on 1 Oriente (x between the plaza and its east facades), asphalt
    for(const s of sts.concat(links))s.paint=[[56,-Z0,71,Z0,null],[-Z0,-Z0,Z0,Z0,K.concrete]];
    for(const s of sts)s.lanes=[-Z0,-Z0,Z0,Z0];
    CLEAR_T.push([ZONE,NAMES]);LAMP_SKIP.push([[-Z0,-Z0,Z0,Z0],NAMES]);
    // the junctions: three street ends or more
    const ends=new Map();for(const s of streets){if(s.c>5)continue;for(const p of [s.pts[0],s.pts[s.pts.length-1]]){const k=Math.round(p[0])+','+Math.round(p[1]);ends.set(k,(ends.get(k)||0)+1);}}
    const J=[...ends].filter(([k,c])=>c>=3).map(([k])=>k.split(',').map(Number)).filter(([x,y])=>inZ(x,y));
    const nearJ=(x,y,r)=>J.some(j=>Math.hypot(j[0]-x,j[1]-y)<r);
    const curb=s=>swOf(s)/2-walkOf(s); // from the axis to the curb
    const walkY=(x,y)=>E(x,y)+WALK_Y;
    // a street lamp: a base, the pole, a cream lantern under a cap; its light in GLOW
    const lamp=(x,y)=>{S.dy=walkY(x,y);const sq=(r)=>[[x-r,y-r],[x+r,y-r],[x+r,y+r],[x-r,y+r]];
      S.prism(sq(.35),0,.7,K.iron2,K.iron2);S.prism(sq(.2),.7,3.7,K.iron,K.iron);S.prism(sq(.35),3.7,4.3,K.lantern,K.lantern);
      S.prism(sq(.45),4.3,4.5,K.iron,K.iron);S.prism(sq(.2),4.5,4.8,K.iron,K.iron);GLOW.push(x,S.dy+4,y);};
    // a traffic light: a grey pole and a black head facing (fx, fy), the red lamp lit
    const light=(x,y,fx,fy)=>{S.dy=walkY(x,y);const sq=(r)=>[[x-r,y-r],[x+r,y-r],[x+r,y+r],[x-r,y+r]];S.prism(sq(.2),0,3.5,K.grey,K.grey);
      const lx=-fy,ly=fx,hx=x+fx*.3,hy=y+fy*.3,H=(u,v)=>[hx+lx*u+fx*v,hy+ly*u+fy*v];
      S.prism([H(-.3,-.25),H(.3,-.25),H(.3,.25),H(-.3,.25)],2.4,3.6,K.black,K.black);
      const f=(u,v,h)=>{const p=H(u,v);return [p[0],S.dy+h,-p[1]];};
      S.face([f(-.2,.31,3.05),f(.2,.31,3.05),f(.2,.31,3.45),f(-.2,.31,3.45)],[fx,0,-fy],K.red);};
    // the lamps: along each side of every segment in the zone (on the plaza's ring, the blocks' side only), from the
    // curb 0.6 m into the sidewalk, every 24 m of the street, not within 9 m of a junction nor on a landmark
    let nl=0;
    for(const s of sts){const P=s.pts,off=curb(s)+.6;
      for(const side of [1,-1]){let acc=0;
        for(let i=0;i+1<P.length;i++){const a=P[i],b=P[i+1],L=Math.hypot(b[0]-a[0],b[1]-a[1]);if(L<0.01)continue;const tx=(b[0]-a[0])/L,ty=(b[1]-a[1])/L,nx=-ty*side,ny=tx*side;
          const mx=(a[0]+b[0])/2,my=(a[1]+b[1])/2,ring=Math.abs(mx)<70&&Math.abs(my)<70;
          if(ring&&nx*mx+ny*my<0){acc+=L;continue;} // the plaza's side of the ring: its own lamps
          for(let u=(24-acc%24)%24;u<=L;u+=24){const x=a[0]+tx*u+nx*off,y=a[1]+ty*u+ny*off;
            if(!inZ(x,y)||!inTerrain(x,y)||nearJ(x,y,9)||occAt(x,y)===1)continue;lamp(x,y);nl++;}
          acc+=L;}}}
    // the traffic lights: on the nearest street of the zone, the cars arriving from the far side of the nearest
    // junction (its corner of the plaza); the pole on their right-hand curb, the head facing them
    let ns=0;
    for(const [cx,cy] of (DATA.plaza&&DATA.plaza.sem)||[]){if(!inZ(cx,cy))continue;let best=null;
      for(const st of sts)for(let i=0;i+1<st.pts.length;i++){const a=st.pts[i],b=st.pts[i+1],L=Math.hypot(b[0]-a[0],b[1]-a[1]);if(L<1)continue;const ux=(b[0]-a[0])/L,uy=(b[1]-a[1])/L;
        const u=Math.max(0,Math.min(L,(cx-a[0])*ux+(cy-a[1])*uy)),qx=a[0]+ux*u,qy=a[1]+uy*u,d=Math.hypot(cx-qx,cy-qy);if(!best||d<best.d)best={d,s:st,px:qx,py:qy,tx:ux,ty:uy};}
      if(!best||!J.length)continue;const {s,px,py}=best;let {tx,ty}=best;
      const j=J.reduce((m,q)=>Math.hypot(q[0]-cx,q[1]-cy)<Math.hypot(m[0]-cx,m[1]-cy)?q:m);
      if((cx-j[0])*tx+(cy-j[1])*ty<0){tx=-tx;ty=-ty;} // (tx, ty): toward where the cars come from
      const rx=-ty,ry=tx,o=curb(s)+.45;light(px+rx*o,py+ry*o,tx,ty);ns++;}
    // the street trees of OpenStreetMap: off the plaza, off the map's carriageways and the landmarks
    let nt=0;const rt=rng(5151);
    for(const [x,y] of (DATA.plaza&&DATA.plaza.arb)||[]){const sz=.8+rt()*.25,sd=.15+rt()*.3;
      if(!inZ(x,y)||(Math.abs(x)<57&&Math.abs(y)<56)||occAt(x,y)===1)continue;
      let road=false;for(const s of sts.concat(links))for(let i=0;i+1<s.pts.length&&!road;i++){const a=s.pts[i],b=s.pts[i+1];if(segDist2(x,y,a[0],a[1],b[0],b[1])<(curb(s)+.3)**2)road=true;}
      if(road)continue;TREES.push([x,y,sz,sd]);nt++;}
    window.__callesPlaza={lamps:nl,lights:ns,trees:nt};
    S.dy=0;});
