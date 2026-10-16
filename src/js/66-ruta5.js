// ==== Ruta 5 ====
// The Ruta 5 (Panamericana) as the motorway it is: two carriageways, each on its own line of OpenStreetMap in its
// direction of travel (R5.c: the 74 ways highway=motorway "Ruta 5 Sur", from `python pipeline/traces.py calzadas` -> data/ruta5.json,
// simplified to 0.3 m, with their lanes and lit tags per stretch), and the 40 motorway_link ramps of its interchanges
// (R5.k), which the map's graph does not have (its trunk_links are map streets already). In OSM a carriageway's line is
// the boundary between its first lane (by the median) and the second, also where a third lane is added on the right
// (placement=right_of:1), so the pavement runs from 4.5 m left of the line (a 3.5 m lane and a 1 m inner shoulder) to
// 3.5 m per further lane and a 2.5 m outer shoulder on its right; a third lane opens and closes over 40 m. White edge
// lines and dashed lane lines one art pixel wide (0.5 m; 4.5 m dashes every 12 m). The median is what lies between the
// two pavements (the lines are 9-15 m apart): concrete under 2.5 m (the city), grass when wider, nothing where the
// carriageways part by more than 28 m; a concrete barrier down its middle where it is under 9 m. Where OSM says
// lit=yes (everything south of the Lircay bridge), a lamp post every 45 m: 12 m with two arms in a narrow median, as in
// a photo of 2011 on Commons (Ruta 5 talca, CC BY-SA 2.0), or on the outer shoulders, staggered, where the median is
// wide. A few cars and lorries in each direction (ruta5Objects). Heights: pavement and median 0.16 (over the streets,
// 0.12-0.148), lines 0.172. The landmarks puente-lircay-ruta5, puente-piduco-ruta5 and enlaces-ruta-5 draw the
// stretches on bridges and embankments (r5Deck, which leaves a gap in the carriageway here) and the decks over it.
const R5=DATA.r5; // data/ruta5.json, from `python pipeline/traces.py calzadas` (make ruta5); injected by build.py
const R5K={asph:hex('#6C6862'),line:hex('#E8E5DC'),conc:hex('#BDB8AD'),grass:hex('#97A65E'),bar:hex('#CFCAC0'),bar2:hex('#E2DDD2'),
  pole:hex('#8A8F92'),lamp:hex('#F1E6C4')};
// each carriageway resampled every 8 m or less: per point its distance d, the lanes and lit of the stretch ahead, the
// third lane's share e (0..1), the tangent of the stretch ahead, a miter normal (nx, ny: left of travel, scaled so an
// offset keeps its width at the bends) and hs, half the distance to the other carriageway's line
const R5C=R5.c.map(c=>{let x=0,y=0;const raw=[],P=[];let d=0;for(let i=0;i<c.p.length;i+=2){x+=c.p[i];y+=c.p[i+1];raw.push([x/10,y/10]);}
  for(let i=0;i<raw.length-1;i++){const a=raw[i],b=raw[i+1],L=Math.hypot(b[0]-a[0],b[1]-a[1]);if(L<.01)continue;const n=Math.max(1,Math.ceil(L/8));
    for(let k=0;k<n;k++)P.push({x:a[0]+(b[0]-a[0])*k/n,y:a[1]+(b[1]-a[1])*k/n,d:d+L*k/n,l:+c.l[i],lit:c.lit[i]==='1',tx:(b[0]-a[0])/L,ty:(b[1]-a[1])/L,e:0});
    d+=L;}
  const z=raw[raw.length-1],q=P[P.length-1];P.push({x:z[0],y:z[1],d,l:q.l,lit:q.lit,tx:q.tx,ty:q.ty,e:0});
  for(let i=0,r0=-1;i<=P.length;i++){const on=i<P.length&&P[i].l>=3;if(on&&r0<0)r0=i;
    if(!on&&r0>=0){const a=P[r0].d,b=P[Math.min(i,P.length-1)].d;for(let j=r0;j<i;j++)P[j].e=Math.max(0,Math.min(1,(P[j].d-a)/40,(b-P[j].d)/40));r0=-1;}}
  P.forEach((p,i)=>{const s=P[Math.max(0,i-1)];let mx=-s.ty-p.ty,my=s.tx+p.tx;const L=Math.hypot(mx,my)||1,c=Math.max(.5,(-mx*p.ty+my*p.tx)/L);p.nx=mx/L/c;p.ny=my/L/c;});
  return {P,L:d,gaps:[]};});
R5C.forEach((C,k)=>{const O=R5C[1-k].P;for(const p of C.P){let m=1e18;for(let i=0;i<O.length-1;i++){const a=O[i],b=O[i+1];
  if(Math.abs(a.x-p.x)>120&&Math.abs(b.x-p.x)>120||Math.abs(a.y-p.y)>120&&Math.abs(b.y-p.y)>120)continue;m=Math.min(m,segDist2(p.x,p.y,a.x,a.y,b.x,b.y));}p.hs=Math.sqrt(m)/2;}});
// carriageway k at distance d (interpolated); a point `o` metres left of its line; the right edge of its pavement
function r5at(k,d){const P=R5C[k].P;let lo=0,hi=P.length-1;d=Math.max(0,Math.min(R5C[k].L,d));while(hi-lo>1){const m=(lo+hi)>>1;if(P[m].d<=d)lo=m;else hi=m;}
  const a=P[lo],b=P[hi],t=b.d>a.d?(d-a.d)/(b.d-a.d):0,f=(u,v)=>u+(v-u)*t;
  return {x:f(a.x,b.x),y:f(a.y,b.y),d,nx:f(a.nx,b.nx),ny:f(a.ny,b.ny),tx:a.tx,ty:a.ty,e:f(a.e,b.e),hs:f(a.hs,b.hs),lit:a.lit,l:a.l};}
const r5off=(p,o)=>[p.x+p.nx*o,p.y+p.ny*o],R5R=p=>-(6+3.5*p.e);
// the distance along carriageway k nearest to (x, y), and its signed offset from the line (left positive)
function r5d(k,x,y){let best=1e18,bd=0,bo=0;const P=R5C[k].P;for(let i=0;i<P.length-1;i++){const a=P[i],b=P[i+1],dx=b.x-a.x,dy=b.y-a.y,L2=dx*dx+dy*dy||1;
  let t=((x-a.x)*dx+(y-a.y)*dy)/L2;t=t<0?0:t>1?1:t;const ex=x-a.x-dx*t,ey=y-a.y-dy*t,q=ex*ex+ey*ey;if(q<best){best=q;bd=a.d+(b.d-a.d)*t;bo=(-dy*ex+dx*ey)/Math.sqrt(L2);}}
  return [bd,bo];}
const r5gh=(k,d)=>{const p=r5at(k,d);return E(...r5off(p,(4.5+R5R(p))/2))+.16;}; // the pavement's height on the ground
window.__E=(x,y)=>E(x,y); // the ground's height (grid metres), to measure the structures from tools/screenshot.py --js
const r5gap=(k,d)=>R5C[k].gaps.find(g=>d>=g[0]&&d<=g[1]);
// calls f(p, q) for the pieces of carriageway k between d0 and d1 that are off the gaps and whose start passes ok(p)
function r5each(k,d0,d1,ok,f){const P=R5C[k].P,gaps=R5C[k].gaps;
  for(let i=0;i<P.length-1;i++){const a=P[i],b=P[i+1];if(b.d<=d0||a.d>=d1||(ok&&!ok(a)))continue;let iv=[[Math.max(a.d,d0),Math.min(b.d,d1)]];
    for(const g of gaps)iv=iv.flatMap(([u,v])=>g[1]<=u||g[0]>=v?[[u,v]]:[[u,g[0]],[g[1],v]].filter(([s,t])=>t-s>.05));
    for(const [u,v] of iv)f(r5at(k,u),r5at(k,v));}}
const r5band=(G,k,f0,f1,y,col,ok)=>r5each(k,0,R5C[k].L,ok,(p,q)=>G.quadXY([r5off(p,f0(p)),r5off(q,f0(q)),r5off(q,f1(q)),r5off(p,f1(p))],y,col));
function r5dash(G,k,o,y,col,ok){for(let d=6;d<R5C[k].L-4.5;d+=12){if(R5C[k].gaps.some(g=>d+4.5>=g[0]&&d<=g[1]))continue;const p=r5at(k,d),q=r5at(k,d+4.5);if(ok&&!ok(p))continue;
  G.quadXY([r5off(p,o(p)-.25),r5off(q,o(q)-.25),r5off(q,o(q)+.25),r5off(p,o(p)+.25)],y,col);}}
const R5X=[]; // decks over the motorway [polyline, half width] (overpasses, footbridges): no median lamp post under them
const r5under=(x,y)=>R5X.some(([pts,hw])=>pts.some((a,i)=>i<pts.length-1&&segDist2(x,y,a[0],a[1],pts[i+1][0],pts[i+1][1])<(hw+3)**2));
// The Ruta 5's flat layers, into buildBase's B (draped with it): pavements, lines, median, ramps. Keeps lots, trees and
// sidewalks off them (occ), with a metre to spare.
function ruta5Base(B){const K=R5K;
  for(let k=0;k<2;k++){
    r5band(B,k,()=>4.5,R5R,0.16,K.asph);
    r5band(B,k,()=>3.25,()=>3.75,0.172,K.line);r5band(B,k,p=>-3.75-3.5*p.e,p=>-3.25-3.5*p.e,0.172,K.line);
    r5dash(B,k,()=>0,0.172,K.line);r5dash(B,k,()=>-3.5,0.172,K.line,p=>p.e>.5);
    r5band(B,k,()=>4.5,p=>p.hs,0.16,K.conc,p=>p.hs>4.55&&p.hs<5.75);r5band(B,k,()=>4.5,p=>p.hs,0.16,K.grass,p=>p.hs>=5.75&&p.hs<14);
    r5each(k,0,R5C[k].L,null,(p,q)=>{for(const r of [p,q])occMark(rotRect(...r5off(r,(4.5+R5R(r))/2),3,12.5+3.5*r.e,Math.atan2(r.ty,r.tx)));});}
  for(const r of R5.k){const w=r[0]*3.5+2.5;let x=0,y=0;const pts=[];for(let i=1;i<r.length;i+=2){x+=r[i];y+=r[i+1];pts.push([x/10,y/10]);}
    ribbon(B,pts,w,0.16,K.asph);for(const s of [1,-1])sideRibbon(B,pts,s,w/2-1,.5,0.172,K.line);
    for(let i=0;i<pts.length-1;i++)occBand(pts[i],pts[i+1],w/2+1);}}
// The Ruta 5's objects, after buildBase: the median barrier, the lamp posts (their lights go to GLOW) and the cars.
// Returns the meshes for the scene (they cast shadows).
function ruta5Objects(){const K=R5K,G=new GB(1<<15),A=R5C[0];
  // barrier: 0.6 m wide, 0.85 m over the pavement, on the median's middle line, as long as the median is narrow (and in
  // the commune: the carriageways run on 300 m past its limit)
  r5each(0,0,A.L,p=>p.hs<9,(p,q)=>{const a=r5off(p,p.hs),b=r5off(q,q.hs);if(!inTerrain(...a)||!inTerrain(...b))return;
    const L=Math.hypot(b[0]-a[0],b[1]-a[1])||1,nx=-(b[1]-a[1])/L*.3,ny=(b[0]-a[0])/L*.3,ga=E(...a),gb=E(...b),V=(c,s,h)=>[c[0]+nx*s,h,-(c[1]+ny*s)];
    for(const s of [1,-1])G.face([V(a,s,ga-.3),V(b,s,gb-.3),V(b,s,gb+1.01),V(a,s,ga+1.01)],[nx*s/.3,0,-ny*s/.3],K.bar);
    G.face([V(a,1,ga+1.01),V(b,1,gb+1.01),V(b,-1,gb+1.01),V(a,-1,ga+1.01)],[0,1,0],K.bar2);});
  // lamp posts: 0.5 m square, 12 m; arms 3 m long over the inner lanes; heads in the lamp colour
  const post=(x,y,arms)=>{const g=E(x,y);G.dy=g;G.prism(rotRect(x,y,.5,.5),0,12,K.pole,K.pole);
    for(const [hx,hy] of arms){const a=Math.atan2(hy-y,hx-x),L=Math.hypot(hx-x,hy-y);G.prism(rotRect((x+hx)/2,(y+hy)/2,L,.4,a),11.6,12,K.pole,K.pole);
      G.prism(rotRect(hx,hy,1.2,.6,a),11.3,11.75,K.pole,K.lamp);GLOW.push(hx,g+11.2,hy);}G.dy=0;};
  let posts=0;
  for(let k=0;k<2;k++)for(let d=(k?32.5:10);d<R5C[k].L;d+=45){const p=r5at(k,d);if(!p.lit||r5gap(k,d)||!inTerrain(p.x,p.y))continue;
    if(p.hs<9){if(k)continue;const c=r5off(p,p.hs);if(r5under(...c))continue;post(...c,[r5off(p,p.hs-3),r5off(p,p.hs+3)]);posts++;}
    else{const c=r5off(p,R5R(p)-1),h=r5off(p,R5R(p)+2);if(r5under(...c))continue;post(...c,[h]);posts++;}}
  // cars: one every ~110 m in each direction, a fifth of them lorries in the right lane; on the decks at their height
  const r=rng(5005),list=[],colW=CAR_COLS.reduce((a,c)=>a+c[3],0);
  const H=(k,d)=>{const g=r5gap(k,d);if(g)return g[2](d);const p=r5at(k,d);return E(p.x,p.y)+.16;};
  for(let k=0;k<2;k++)for(let d=30+r()*60;d<R5C[k].L-10;d+=20+r()*180){const p=r5at(k,d);if(!inTerrain(p.x,p.y))continue;
    const truck=r()<.2,o=truck||r()<.55?-1.75:1.75,c=r5off(p,p.e>.9&&r()<.3?-5.25:o),len=truck?2.4+r()*.4:(4.1+r()*.6)/4.5;
    let cc=r()*colW,col=CAR_COLS[0];for(const q of CAR_COLS){if((cc-=q[3])<0){col=q;break;}}
    list.push([c[0],c[1],p.tx,p.ty,len,truck?2.1:1,col,r(),(H(k,d-2)+H(k,d+2))/2,Math.atan2(H(k,d+2)-H(k,d-2),4)]);}
  const q=new T.Quaternion(),e=new T.Euler(0,0,0,'YZX'),s=new T.Vector3(),pp=new T.Vector3();
  const cars=instTiled(carGeo(),new T.MeshLambertMaterial({vertexColors:true}),list,([x,y,dx,dy,len,hs,c,k,h,sl],m,col)=>{e.set(0,Math.atan2(dy,dx),sl);q.setFromEuler(e);s.set(len,hs,1);pp.set(x,h,-y);m.compose(pp,q,s);
    const v=.96+k*.08;col.setRGB(c[0]*v,c[1]*v,c[2]*v);});
  Object.assign(STREET,{r5posts:posts,r5cars:list.length,r5gaps:R5C.map(c=>c.gaps.length)});
  const mesh=tiled(G,matFlat);for(const o of [mesh,cars])o.traverse(c=>c.castShadow=true);
  window.__r5cars=on=>{cars.visible=on;dirty=true;};
  return [mesh,cars];}
// Carriageway k on a bridge or an embankment from d0 to d1 (landmarks, from buildModels): the deck (deckBridge: its
// pavement, parapets and beam, piers every o.pier m where it stands 2.5 m over the ground) at h(d), an absolute height
// never under the terrain plus 0.3 m, with its lines; outside the open spans (open: [[d0, d1], ...], where it stands on
// piers) an embankment of grass slopes, 1:1.5, in two tones, and an abutment wall at each end of an open span where the
// deck is over a metre up; lamp posts on the median side where the stretch is lit; voids: [[d0, d1], ...] dark openings
// in the embankment where a street passes under it. The carriageway on the ground stops there (gaps).
function r5Deck(S,K,k,d0,d1,h,open=[],o={}){
  let em=0;for(let d=d0;d<=d1;d+=5)em=Math.max(em,r5at(k,d).e);
  const hw=(10.5+3.5*em)/2+.6,co=(4.5-6-3.5*em)/2,pts=[];
  for(let d=d0;;d+=5){const dd=Math.min(d,d1);pts.push(r5off(r5at(k,dd),co));if(dd>=d1)break;}
  const H=d=>{const c=r5off(r5at(k,d),co);return Math.max(h(d),E(c[0],c[1])+.3);};
  deckBridge(S,K,pts,hw,p=>h(d0+p.d),{deck:K.asph,beamD:1.5,beamCol:K.beam,pier:o.pier||25,ends:false});
  R5C[k].gaps.push([d0,d1,H]);
  const isOpen=d=>open.some(([a,b])=>d>=a&&d<=b),isVoid=d=>(o.voids||[]).some(([a,b])=>d>=a&&d<=b),st=2.5;
  for(let d=d0;d<d1-1e-6;d+=st){const e=Math.min(d+st,d1),p=r5at(k,d),q=r5at(k,e),hp=H(d),hq=H(e),m=(d+e)/2;
    const V=(r,off,y)=>{const c=r5off(r,off);return [c[0],y,-c[1]];};
    for(const [a,b] of [[3.25,3.75],[-3.75,-3.25],[-.25,.25]])if(a<0&&a>-1?(m-d0)%12<4.5:true)S.face([V(p,a,hp+.05),V(q,a,hq+.05),V(q,b,hq+.05),V(p,b,hp+.05)],[0,1,0],K.line);
    if(isOpen(m))continue;
    for(const s of [1,-1]){const off=co+s*hw,gp=E(...r5off(p,off)),gq=E(...r5off(q,off));
      if(isVoid(m)){if(hp-gp>2)S.face([V(p,off+s*.02,gp-.3),V(q,off+s*.02,gq-.3),V(q,off+s*.02,hq-1.5),V(p,off+s*.02,hp-1.5)],[p.nx*s,0,-p.ny*s],K.void);continue;}
      if(hp-gp<.35&&hq-gq<.35)continue;
      const fp=off+s*1.5*Math.max(0,hp-gp),fq=off+s*1.5*Math.max(0,hq-gq),col=Math.floor(m/10)%2?K.fill:K.fill2;
      S.face([V(p,off,hp-.02),V(q,off,hq-.02),V(q,fq,E(...r5off(q,fq))-.3),V(p,fp,E(...r5off(p,fp))-.3)],null,col);
      occMark([r5off(p,off),r5off(q,off),r5off(q,fq),r5off(p,fp)]);}}
  for(const [a,b] of open)for(const [d,sg] of [[a,1],[b,-1]]){if(d<=d0+1||d>=d1-1)continue;const p=r5at(k,d),g=E(...r5off(p,co)),hh=H(d);if(hh-g<1)continue;
    const V=(off,y)=>{const c=r5off(p,off);return [c[0],y,-c[1]];};S.face([V(co-hw,g-.5),V(co+hw,g-.5),V(co+hw,hh-.1),V(co-hw,hh-.1)],[p.tx*sg,0,-p.ty*sg],K.beam);}
  if(o.lamps)for(let d=d0+15;d<d1-5;d+=45){const p=r5at(k,d);if(!p.lit)continue;const c=r5off(p,co+hw-.35),hd=r5off(p,co+hw-3.3),hh=H(d),a=Math.atan2(p.ty,p.tx);
    S.prism(rotRect(...c,.5,.5,a),hh+.9,hh+12,K.metal,K.metal);S.prism(rotRect(...r5off(p,co+hw-1.8),.4,3,a),hh+11.6,hh+12,K.metal,K.metal);
    S.prism(rotRect(...hd,.6,1.2,a),hh+11.3,hh+11.75,K.metal,K.lamp);GLOW.push(hd[0],hh+11.2,hd[1]);}
  S.dy=0;return H;}
// Both carriageways' profile through knots [x, y, h, n]: the point of the carriageway nearest to (x, y), moved n m
// north along it, at height h (absolute; null: on the ground); open spans [[x, y], [x, y]] likewise (without n). Draws
// r5Deck from the first knot to the last on carriageway k. Which way is north along a carriageway comes from its
// tangent: the chains' order in data/ruta5.json follows their length (traces.py calzadas), and it swapped when the
// model became the commune.
const r5north=(k,d)=>r5at(k,d).ty<0?-1:1; // +1 where d grows northwards on carriageway k
function r5Raise(S,K,k,knots,open,o={}){
  const Q=knots.map(([x,y,h,n=0])=>{const d=r5d(k,x,y)[0];return [d+r5north(k,d)*n,h];}).sort((a,b)=>a[0]-b[0]);for(const q of Q)if(q[1]===null)q[1]=r5gh(k,q[0]);
  const h=d=>{for(let i=0;i<Q.length-1;i++)if(d<=Q[i+1][0])return Q[i][1]+(Q[i+1][1]-Q[i][1])*(d-Q[i][0])/Math.max(Q[i+1][0]-Q[i][0],1e-6);return Q[Q.length-1][1];};
  return r5Deck(S,K,k,Q[0][0],Q[Q.length-1][0],h,open.map(([a,b])=>{const u=r5d(k,...a)[0],v=r5d(k,...b)[0];return [Math.min(u,v),Math.max(u,v)];}),o);}
// A street over the motorway (landmarks): its deck along pts (grid metres; for a divided street, the middle of both
// carriageways) at street level at its ends and `top` m over the street's highest end above the motorway, on ramps
// between walls in between; dark openings on both faces where the motorway runs under it (in Talca the motorway runs in
// a cutting under its overpasses, which the 40 m relief cannot hold: the street rises instead). The map's streets that
// lie on it are taken off the ground (s.bridge). Lamps if o.lamps.
function r5Over(S,K,pts,hw,top,o={}){
  const seg=[];let L=0;for(let i=0;i<pts.length-1;i++){const l=Math.hypot(pts[i+1][0]-pts[i][0],pts[i+1][1]-pts[i][1]);seg.push([L,l]);L+=l;}
  const at=u=>{let i=0;while(i<seg.length-1&&u>seg[i][0]+seg[i][1])i++;const a=pts[i],b=pts[i+1],t=Math.max(0,Math.min(1,(u-seg[i][0])/seg[i][1]));
    return [a[0]+(b[0]-a[0])*t,a[1]+(b[1]-a[1])*t,(b[0]-a[0])/seg[i][1],(b[1]-a[1])/seg[i][1]];};
  // the stretch over the motorway: where the deck's middle is on a pavement or the median between them
  let u0=1e9,u1=-1e9;for(let u=0;u<=L;u+=1){const [x,y]=at(u);for(let k=0;k<2;k++){const [d,off]=r5d(k,x,y),p=r5at(k,d);if(off>=R5R(p)-.5&&off<=Math.max(4.5,p.hs)+.5){u0=Math.min(u0,u);u1=Math.max(u1,u);}}}
  const ha=E(...pts[0])+.13,hb=E(...pts[pts.length-1])+.13,ht=Math.max(ha,hb)+top;
  const h=u=>u<u0?ha+(ht-ha)*u/Math.max(u0,1):u>u1?hb+(ht-hb)*(L-u)/Math.max(L-u1,1):ht;
  deckBridge(S,K,pts,hw,p=>h(p.d),{walk:hw-2.5,beamD:.6,beamCol:K.beam,pier:1e9,lamps:o.lamps,ends:false});
  for(let u=0;u<L-1e-6;u+=1){const v=Math.min(u+1,L),[ax,ay,tx,ty]=at(u),[bx,by]=at(v),ov=u+.5>=u0&&u+.5<=u1;
    for(const s of [1,-1]){const nx=-ty*s,ny=tx*s,A=[ax+nx*(hw+.03),ay+ny*(hw+.03)],B=[bx+nx*(hw+.03),by+ny*(hw+.03)],ga=E(...A),gb=E(...B);
      if(h(u)-.6-ga<.15&&h(v)-.6-gb<.15)continue;
      S.face([[A[0],ov?ga+.16:ga-.3,-A[1]],[B[0],ov?gb+.16:gb-.3,-B[1]],[B[0],h(v)-.6,-B[1]],[A[0],h(u)-.6,-A[1]]],[nx,0,-ny],ov?K.void:K.wall);}}
  const Z=pts[pts.length-1],dl=Math.hypot(Z[0]-pts[0][0],Z[1]-pts[0][1]);
  streets.forEach(s=>{const [p,q]=s.pts,l=Math.hypot(q[0]-p[0],q[1]-p[1])||1;if(s.pts.length===2&&Math.abs(((Z[0]-pts[0][0])*(q[0]-p[0])+(Z[1]-pts[0][1])*(q[1]-p[1]))/dl/l)>.8
    &&s.pts.every(p=>pts.some((a,i)=>i<pts.length-1&&segDist2(p[0],p[1],a[0],a[1],pts[i+1][0],pts[i+1][1])<(hw*.6)**2)))s.bridge=true;});
  R5X.push([pts,hw]);S.dy=0;}
// A footbridge over the motorway (landmarks): pts its OSM polyline (ramps and span); the span, from pts[i0] to pts[i1],
// `top` m over the highest ground under it, the ramps down to the ground at the polyline's ends, on columns.
function r5Foot(S,K,pts,i0,i1,top){let L=0;const D=[0];for(let i=0;i<pts.length-1;i++)D.push(L+=Math.hypot(pts[i+1][0]-pts[i][0],pts[i+1][1]-pts[i][1]));
  let g=-1e9;for(let i=i0;i<i1;i++)for(let t=0;t<=1;t+=.1)g=Math.max(g,E(pts[i][0]+(pts[i+1][0]-pts[i][0])*t,pts[i][1]+(pts[i+1][1]-pts[i][1])*t));
  const ht=g+top,ha=E(...pts[0])+.2,hb=E(...pts[pts.length-1])+.2,u0=D[i0],u1=D[i1];
  const h=u=>u<u0?ha+(ht-ha)*u/Math.max(u0,1):u>u1?hb+(ht-hb)*(L-u)/Math.max(L-u1,1):ht;
  deckBridge(S,K,pts,1.6,p=>h(p.d),{deck:K.foot,beamD:.6,beamCol:K.beam,pier:9,ends:false});
  R5X.push([pts.slice(i0,i1+1),1.6]);S.dy=0;return ht;}
// stairs from (x, y) at the ground up to height ht at (x1, y1): 0.5 m steps, 1.6 m wide, on S
function r5Stairs(S,K,x,y,x1,y1,ht){const g=E(x,y),n=Math.max(2,Math.ceil((ht-g)/.5)),a=Math.atan2(y1-y,x1-x),L=Math.hypot(x1-x,y1-y);
  for(let i=0;i<n;i++){const t=(i+.5)/n;S.dy=0;S.prism(rotRect(x+(x1-x)*t,y+(y1-y)*t,L/n+.02,1.6,a),g-.5,g+(ht-g)*(i+1)/n,K.beam,i%2?K.foot:K.foot2);}
  occMark(rotRect((x+x1)/2,(y+y1)/2,L+2,4,a));}
