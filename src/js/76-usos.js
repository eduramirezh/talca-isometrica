// ==== usos de suelo ====
// Land uses (config/usos.json, pipeline/usos.py; docs/METODOLOGIA.md §13). The census leaves much of the ground blank:
// blocks "sin información" are painted as sand or park, the fringe has no block at all, and built blocks that are not
// housing (the regiment, the cemeteries, schools, the golf course) fill with generated houses or sheds. DATA.usos says
// what each of those grounds is: a polygon (OpenStreetMap, a census block, or drawn on the satellite image) and a use,
// drawn here in a generic pixel-art vocabulary (docs/ESTETICA.md §3), every choice seeded by the entry's index.
//  - usosPlan(), after the landmarks and before the pads and the city, reserves the ground like a landmark: occ on every
//    cell of the polygon but a margin along the streets (so the sidewalks, street trees and parked cars stay). That is
//    enough to keep cityGen's lots out (a lot is tested every 2.5 m of its rectangle and is deeper than the margin);
//    NOLOTS is not used: cityGen tests every polygon in it at every step along every street, and with the ~300 uses on
//    built blocks generation took 2 s longer. An industrial use on a built block keeps cityGen's sheds and only gets
//    its yard. A use that lies mostly on what was there before (a landmark, a river) is skipped.
//  - usosBase(B,S), once the terrain is final, lays the ground of each use in its own draped mesh at 0.11 (blocks 0.10,
//    rivers 0.11, streets from 0.12), with the smaller uses inside it cut out, and none where the raster was occupied
//    before (rivers and their gravel, landmarks, the Ruta 5 and the rail: pieces are split down to ~2 m there); details
//    in 1 cm steps (a 0.5 cm step flickers): surfaces 0.12 (pitches, parade ground), stripes, rows and paths 0.13,
//    lines, greens and sand 0.14; strips are cut where they meet a street; objects on S (sheds, walls, graves, stalls,
//    bleachers: no window shader) or B (barracks, pavilions and houses, with windows); trees into TREES and PO_FIELD.
//    Eriazo, bosque and parcelas lay no ground (the block's sand, the terrain or the farmland stays; an eriazo on a block
//    painted as a park gets the sand) but scrub, dirt tracks, trees or houses, and they may overlap the others: they
//    leave out every ground-laying use (inUso). Then usosFringe() puts scrub on the bare ground of the urban fringe
//    that no block, use or farmland parcel covers.
// Uses: industrial (yard, sheds with ridge or saw-tooth roofs, trucks, tanks, a fence; o.t "corral": rows of parked
// vehicles), cementerio (avenues with cypresses, niches, graves, mausoleums, chapel, wall; o.t "parque": lawn), militar
// (parade ground, barracks, wall), educacional, salud, deportivo (o.c: one OSM pitch of that sport; otherwise a
// sports ground with a pitch and bleachers), golf, parque, huerto, vina, potrero, feria, terminal (bus platforms),
// conjunto (rows of identical semi-detached houses where the map has no streets), parcelas, bosque, eriazo. The
// `vivienda` entries never get here: build.py turns them into built census blocks for cityGen.
// window.__usos: counts per use, skipped entries, trees and the time taken.
const USOS=(()=>{const D=DATA.usos||{k:[],u:[]};return D.u.map(([k,rr,o],i)=>{const r=dec(rr);let A=0,x0=1e9,y0=1e9,x1=-1e9,y1=-1e9;
  for(let j=0;j<r.length;j++){const p=r[j],q=r[(j+1)%r.length];A+=p[0]*q[1]-q[0]*p[1];x0=Math.min(x0,p[0]);x1=Math.max(x1,p[0]);y0=Math.min(y0,p[1]);y1=Math.max(y1,p[1]);}
  if(A<0)r.reverse();return {i,k:D.k[k],r,o:o||{},A:Math.abs(A)/2,bb:[x0,y0,x1,y1],kids:[],skip:false};});})();
const USO_GROUND=new Set(['industrial','cementerio','militar','educacional','salud','deportivo','golf','parque','huerto','vina','potrero','feria','conjunto','terminal']);
const USTAT={n:{},skip:[],trees:0,ms:0};
const UGRID=new Array(bgW*bgH); // the uses touching each 100 m cell of blockAt's grid
for(const u of USOS)for(let gx=Math.max(0,Math.floor((u.bb[0]-XMIN)/BG));gx<=Math.min(bgW-1,Math.floor((u.bb[2]-XMIN)/BG));gx++)
  for(let gy=Math.max(0,Math.floor((u.bb[1]-YMIN)/BG));gy<=Math.min(bgH-1,Math.floor((u.bb[3]-YMIN)/BG));gy++)(UGRID[gy*bgW+gx]||(UGRID[gy*bgW+gx]=[])).push(u);
let OCC0=null; // occ as it was before the uses: rivers and their gravel, landmarks, the Ruta 5 and the rail
const occ0At=(x,y)=>{const gx=Math.floor((x-XMIN)/OC),gy=Math.floor((y-YMIN)/OC);return (gx<0||gy<0||gx>=ocW||gy>=ocH)?1:OCC0[gy*ocW+gx];};
// is (x, y) in use u and none of its kids? A use without ground of its own (eriazo, bosque, parcelas) may overlap
// others: it also leaves out every ground-laying use
const groundAt=(x,y)=>(UGRID[Math.floor((y-YMIN)/BG)*bgW+Math.floor((x-XMIN)/BG)]||[]).some(p=>!p.skip&&USO_GROUND.has(p.k)&&x>=p.bb[0]&&x<=p.bb[2]&&y>=p.bb[1]&&y<=p.bb[3]&&pip([x,y],p.r));
const inUso=(u,x,y)=>x>=u.bb[0]&&x<=u.bb[2]&&y>=u.bb[1]&&y<=u.bb[3]&&pip([x,y],u.r)&&!u.kids.some(k=>pip([x,y],k.r))&&(USO_GROUND.has(u.k)||!groundAt(x,y));
const ccwQ=q=>{let A=0;for(let i=0;i<q.length;i++){const p=q[i],r=q[(i+1)%q.length];A+=p[0]*r[1]-r[0]*p[1];}return A<0?q.slice().reverse():q;};
function usoSamples(u,n=48){const [x0,y0,x1,y1]=u.bb,s=Math.max(4,Math.sqrt(u.A/n)),o=[];
  for(let x=x0+s/2;x<x1;x+=s)for(let y=y0+s/2;y<y1;y+=s)if(pip([x,y],u.r))o.push([x,y]);return o.length?o:[u.r[0]];}
function usosPlan(){const t0=performance.now();OCC0=occ.slice();
  // nesting: a use whose polygon lies inside a larger one is its kid (a pitch in a school, a school in a park)
  const by=USOS.slice().sort((a,b)=>a.A-b.A);
  for(const c of USOS){let best=null;for(const p of by){if(p.A<=c.A||(best&&p.A>=best.A))continue;
      if(c.bb[0]<p.bb[0]||c.bb[1]<p.bb[1]||c.bb[2]>p.bb[2]||c.bb[3]>p.bb[3])continue;if(c.r.every(q=>pip(q,p.r)))best=p;}
    if(best)best.kids.push(c);}
  // the landmarks' fenced grounds (NOLOTS holds only theirs at this point: the campuses, the stadium's complex, the
  // Parque Río Claro) are modelled already: a use mostly inside one is skipped like one on a landmark's footprint
  const HN=NOLOTS.map(q=>{let x0=1e9,y0=1e9,x1=-1e9,y1=-1e9;for(const p of q){x0=Math.min(x0,p[0]);x1=Math.max(x1,p[0]);y0=Math.min(y0,p[1]);y1=Math.max(y1,p[1]);}return {q,bb:[x0,y0,x1,y1]};});
  const inHito=(x,y)=>HN.some(({q,bb})=>x>=bb[0]&&x<=bb[2]&&y>=bb[1]&&y<=bb[3]&&pip([x,y],q));
  for(const u of USOS){const S=usoSamples(u);let pre=0,built=0,alam=0;
    for(const [x,y] of S){if(OCC0[Math.floor((y-YMIN)/OC)*ocW+Math.floor((x-XMIN)/OC)]===1||inHito(x,y))pre++;const bi=blockAt(x,y);if(bi>=0){if(blocks[bi].built)built++;if(ALAM.has(bi)||bi===PLAZA_BI)alam++;}}
    // a ground use mostly inside a larger one it is not the kid of (two OSM pitches drawn over each other) would flicker
    const dup=USO_GROUND.has(u.k)&&(UGRID[Math.floor((S[0][1]-YMIN)/BG)*bgW+Math.floor((S[0][0]-XMIN)/BG)]||[]).some(p=>p!==u&&!p.skip&&p.A>u.A&&USO_GROUND.has(p.k)&&!p.kids.includes(u)&&S.filter(q=>pip(q,p.r)).length>S.length*.5);
    if(dup||alam>S.length*.2||pre>S.length*(u.k==='eriazo'||u.k==='bosque'?.6:.35)){u.skip=true;USTAT.skip.push(u.i);continue;}
    u.built=built>S.length*.5;u.green=S.filter(([x,y])=>{const bi=blockAt(x,y);return bi>=0&&!blocks[bi].built&&blocks[bi].A<40000;}).length>S.length*.5; // on a block painted as park
    // a ground use that overlaps a larger one without lying inside it (OSM draws pitches over pitches) lays its ground
    // 1 cm higher, or the two would flicker where they meet
    if(USO_GROUND.has(u.k)){const nb=new Set();for(let gx=Math.max(0,Math.floor((u.bb[0]-XMIN)/BG));gx<=Math.min(bgW-1,Math.floor((u.bb[2]-XMIN)/BG));gx++)for(let gy=Math.max(0,Math.floor((u.bb[1]-YMIN)/BG));gy<=Math.min(bgH-1,Math.floor((u.bb[3]-YMIN)/BG));gy++)for(const p of UGRID[gy*bgW+gx]||[])nb.add(p);
      for(const p of nb)if(p!==u&&!p.skip&&p.A>u.A&&USO_GROUND.has(p.k)&&!p.kids.includes(u)&&(u.r.some(q=>pip(q,p.r))||S.some(q=>pip(q,p.r)))){u.lift=0.01;break;}}
    if(u.k==='industrial'&&u.built)continue; // cityGen's sheds stay; only the yard is laid
    // occ: a scanline fill, leaving 2.5 m past each street's edge free
    const [x0,y0,x1,y1]=u.bb;for(let gy=Math.max(0,Math.floor((y0-YMIN)/OC));gy<=Math.min(ocH-1,Math.floor((y1-YMIN)/OC));gy++){const cy=YMIN+(gy+.5)*OC,xs=[];
      for(let i=0,j=u.r.length-1;i<u.r.length;j=i++){const a=u.r[i],c=u.r[j];if((a[1]>cy)!==(c[1]>cy))xs.push(a[0]+(cy-a[1])*(c[0]-a[0])/(c[1]-a[1]));}xs.sort((p,q)=>p-q);
      for(let i=0;i+1<xs.length;i+=2)for(let gx=Math.max(0,Math.ceil((xs[i]-XMIN)/OC-.5));gx<=Math.min(ocW-1,Math.floor((xs[i+1]-XMIN)/OC-.5));gx++){
        const k=gy*ocW+gx;if(occ[k]===1)continue;if(!nearStreet(XMIN+(gx+.5)*OC,cy,2.5))occ[k]=1;}}}
  USTAT.planMs=Math.round(performance.now()-t0);
}
// the use's frame: u along its rows (o.r, degrees from +x, or the long side of the polygon's minimum-area rectangle), v
// across; G: (u,v) -> grid metres, L the reverse; lr/kl: the ring and its kids in (u,v); u0..v1 the extent
function usoFrame(u){if(u.fr)return u.fr;const R=u.r;
  const P=R.slice().sort((a,b)=>a[0]-b[0]||a[1]-b[1]),cr=(o,a,b)=>(a[0]-o[0])*(b[1]-o[1])-(a[1]-o[1])*(b[0]-o[0]),lo=[],hi=[];
  for(const p of P){while(lo.length>1&&cr(lo[lo.length-2],lo[lo.length-1],p)<=0)lo.pop();lo.push(p);}
  for(let i=P.length-1;i>=0;i--){const p=P[i];while(hi.length>1&&cr(hi[hi.length-2],hi[hi.length-1],p)<=0)hi.pop();hi.push(p);}
  const H=lo.slice(0,-1).concat(hi.slice(0,-1));let best=null;
  for(let i=0;i<H.length;i++){const p=H[i],q=H[(i+1)%H.length],a=Math.atan2(q[1]-p[1],q[0]-p[0]),c=Math.cos(a),s=Math.sin(a);let a0=1e9,a1=-1e9,b0=1e9,b1=-1e9;
    for(const t of H){const uu=t[0]*c+t[1]*s,vv=-t[0]*s+t[1]*c;a0=Math.min(a0,uu);a1=Math.max(a1,uu);b0=Math.min(b0,vv);b1=Math.max(b1,vv);}
    const ar=(a1-a0)*(b1-b0);if(!best||ar<best.ar)best={ar,a:a1-a0>=b1-b0?a:a+Math.PI/2};}
  const a=u.o.r!=null?u.o.r*Math.PI/180:best?best.a:0,c=Math.cos(a),s=Math.sin(a),L=(x,y)=>[x*c+y*s,-x*s+y*c];
  const lr=R.map(p=>L(...p));let u0=1e9,u1=-1e9,v0=1e9,v1=-1e9;for(const [x,y] of lr){u0=Math.min(u0,x);u1=Math.max(u1,x);v0=Math.min(v0,y);v1=Math.max(v1,y);}
  return u.fr={a,u0,u1,v0,v1,G:(x,y)=>[x*c-y*s,x*s+y*c],L,lr,kl:u.kids.map(k=>k.r.map(p=>L(...p))),R:(a0,b0,a1,b1)=>[[a0,b0],[a1,b0],[a1,b1],[a0,b1]].map(p=>[p[0]*c-p[1]*s,p[0]*s+p[1]*c])};}
// where the line v = const crosses the polygon minus its kids: [[u0, u1], ...]; band(): inside along both edges of a strip
function crossAt(lr,v){const o=[];for(let i=0,j=lr.length-1;i<lr.length;j=i++){const a=lr[i],b=lr[j];if((a[1]>v)!==(b[1]>v))o.push(a[0]+(v-a[1])*(b[0]-a[0])/(b[1]-a[1]));}return o.sort((p,q)=>p-q);}
function usoSpans(fr,v){let I=[];const s=crossAt(fr.lr,v);for(let i=0;i+1<s.length;i+=2)I.push([s[i],s[i+1]]);
  for(const kl of fr.kl){const t=crossAt(kl,v);for(let i=0;i+1<t.length;i+=2){const a=t[i],b=t[i+1],J=[];for(const [p,q] of I){if(q<=a||p>=b)J.push([p,q]);else{if(p<a)J.push([p,a]);if(q>b)J.push([b,q]);}}I=J;}}
  return I;}
function usoBand(fr,v0,v1){const A=usoSpans(fr,v0),B=usoSpans(fr,v1),o=[];for(const [a,b] of A)for(const [c,d] of B){const p=Math.max(a,c),q=Math.min(b,d);if(q-p>.5)o.push([p,q]);}return o;}
function usosBase(B,S){const t0=performance.now(),UG=new GB(1<<16),C=hex;if(!OCC0)return;
  // ground pieces: split where the raster was occupied before the uses, down to ~2 m (rivers, gravel, landmarks)
  const dry=(q,off,col)=>{let x0=1e9,y0=1e9,x1=-1e9,y1=-1e9;for(const p of q){x0=Math.min(x0,p[0]);x1=Math.max(x1,p[0]);y0=Math.min(y0,p[1]);y1=Math.max(y1,p[1]);}
    let busy=false;for(let gx=Math.floor((x0-XMIN)/OC);gx<=Math.floor((x1-XMIN)/OC)&&!busy;gx++)for(let gy=Math.floor((y0-YMIN)/OC);gy<=Math.floor((y1-YMIN)/OC);gy++){
      if(gx<0||gy<0||gx>=ocW||gy>=ocH||OCC0[gy*ocW+gx]===1){busy=true;break;}}
    if(!busy)return UG.onGround(q,off,col);
    if(x1-x0<2.2&&y1-y0<2.2){let cx=0,cy=0;for(const p of q){cx+=p[0];cy+=p[1];}if(!occ0At(cx/q.length,cy/q.length))UG.onGround(q,off,col);return;}
    const f=x1-x0>y1-y0?p=>p[0]:p=>p[1],[A,Bq]=cutAt(q,f,x1-x0>y1-y0?(x0+x1)/2:(y0+y1)/2);if(A.length>2)dry(A,off,col);if(Bq.length>2)dry(Bq,off,col);};
  const PX={onGround:dry};
  const ground=(u,col)=>{const holes=u.kids.filter(k=>!k.skip&&USO_GROUND.has(k.k)).map(k=>k.r);let t;
    try{t=T.ShapeUtils.triangulateShape(u.r.map(p=>new T.Vector2(p[0],p[1])),holes.map(h=>h.map(p=>new T.Vector2(p[0],p[1]))));}catch(e){return;}
    const all=u.r.concat(...holes);for(const [a,b,c] of t)drapeQ(PX,ccwQ([all[a],all[b],all[c]]),0.11+(u.lift||0),col);};
  const flatD=(q,y,col)=>drapeQ(PX,ccwQ(q),y,col); // a small convex detail, draped (no street test)
  // a strip along u from ua to ub between v0 and v1, cut where it meets a street or what was there before
  const strip=(fr,v0,v1,ua,ub,y,col,step=4)=>{const vm=(v0+v1)/2;let s=null,last=ua;
    for(let t=ua;;t=Math.min(ub,t+step)){const p=fr.G(t,vm),ok=!nearStreet(p[0],p[1],.8)&&!occ0At(p[0],p[1]);
      if(ok&&s===null)s=t;if(ok)last=t;
      if((!ok||t>=ub)&&s!==null){if(last-s>.6)drapeQ(UG,ccwQ(fr.R(s,v0,last,v1)),y,col);s=null;}
      if(t>=ub)break;}};
  const rows=(fr,gap,w,y,col,col2,off=0)=>{let n=0;for(let v=fr.v0+off+gap/2;v<fr.v1;v+=gap,n++)for(const [a,b] of usoBand(fr,v-w/2,v+w/2))strip(fr,v-w/2,v+w/2,a,b,y,col2&&n%2?col2:col);};
  // can a rectangle q (grid metres) stand in use u: inside it, off its kids, off the streets (margin m), off what was
  // there before and off what this use already placed (objs)
  const fits=(u,q,m,objs)=>{const c=[(q[0][0]+q[2][0])/2,(q[0][1]+q[2][1])/2],pts=q.concat([c],q.map((p,i)=>{const r=q[(i+1)%4];return [(p[0]+r[0])/2,(p[1]+r[1])/2];}));
    for(const p of pts){if(!inUso(u,p[0],p[1])||occ0At(p[0],p[1])||nearStreet(p[0],p[1],m))return false;}
    return !objs||objs.every(o=>sepQuad(q,o));};
  const tree=(x,y,s,seed,po)=>{if(!inTerrain(x,y))return;(po?PO_FIELD:TREES).push([x,y,s,seed]);USTAT.trees++;};
  const wallsOf=(u,h,w,col,top,gap)=>{const R=u.r;for(let i=0;i<R.length;i++){const a=R[i],b=R[(i+1)%R.length],L=Math.hypot(b[0]-a[0],b[1]-a[1]);if(L<2)continue;
      const tx=(b[0]-a[0])/L,ty=(b[1]-a[1])/L,nx=-ty,ny=tx,o=1.2; // inward (the ring is counter-clockwise)
      let s=null;for(let t=0;;t=Math.min(L,t+3)){const x=a[0]+tx*t+nx*o,y=a[1]+ty*t+ny*o,ok=!nearStreet(x,y,.3)&&!occ0At(x,y)&&!(gap&&gap(x,y));
        if(ok&&s===null)s=t;
        if((!ok||t>=L)&&s!==null){const e=ok?t:t-3;if(e-s>1){const q=[[a[0]+tx*s+nx*o,a[1]+ty*s+ny*o],[a[0]+tx*e+nx*o,a[1]+ty*e+ny*o],[a[0]+tx*e+nx*(o+w),a[1]+ty*e+ny*(o+w)],[a[0]+tx*s+nx*(o+w),a[1]+ty*s+ny*(o+w)]];
          S.dy=groundMin(q);S.prism(q,0.3,h,col,top);}s=null;}
        if(t>=L)break;}}};
  // buildings: a shed with a low ridge or a saw-tooth roof (S), a pavilion with windows (B)
  const shed=(q,h,wall,roof,kind)=>{S.dy=groundMin(q);const L=Math.hypot(q[1][0]-q[0][0],q[1][1]-q[0][1]),D=Math.hypot(q[3][0]-q[0][0],q[3][1]-q[0][1]);
    if(kind==='gable'){S.gable(q,0.3,h,D*.12,wall,roof);return;}
    if(kind==='flat'){S.prism(q,0.3,h,wall,roof);S.prism(q,h,h+.5,C('#E4E1D8'),roof,false);return;} // a white parapet
    const ex=[(q[1][0]-q[0][0])/L,(q[1][1]-q[0][1])/L],ey=[(q[3][0]-q[0][0])/D,(q[3][1]-q[0][1])/D],P=(s,t,y)=>[q[0][0]+ex[0]*s+ey[0]*t,y,-(q[0][1]+ex[1]*s+ey[1]*t)];
    S.prism(q,0.3,h,wall,roof,false);const n=Math.max(2,Math.round(L/9)),b=L/n,th=2.4,gl=C('#3B4653');
    for(let i=0;i<n;i++){const s0=i*b,s1=s0+b;S.face([P(s0,0,h),P(s1,0,h+th),P(s1,D,h+th),P(s0,D,h)],null,i%2?shade(roof,.92):roof);
      S.face([P(s1,0,h),P(s1,D,h),P(s1,D,h+th),P(s1,0,h+th)],[ex[0],0,-ex[1]],gl);
      S.face([P(s0,0,h),P(s1,0,h),P(s1,0,h+th)],[-ey[0],0,ey[1]],wall);S.face([P(s0,D,h),P(s1,D,h+th),P(s1,D,h)],[ey[0],0,-ey[1]],wall);}};
  const pavilion=(q,fl,wall,roof,gable)=>{B.dy=groundMin(q);const h=fl*3.2+.3,D=Math.hypot(q[3][0]-q[0][0],q[3][1]-q[0][1]);if(gable)B.gable(q,0.3,h,D*.28,wall,roof);else{B.prism(q,0.3,h,wall,roof);}};
  const K={yard:C('#ABA79C'),yard2:C('#9E9A90'),swalls:['#D4D0C6','#C9C6BE','#B9B5AC','#D8CDB8','#C4BFB2'].map(C),zinc:['#A9ADB0','#C2C4C3','#9CA3A6','#8F969A','#B4B0A6'].map(C),
    tank:C('#DAD7D0'),truck:C('#E8E6E0'),cab:['#B4372C','#3E6D9C','#E8E6E0','#3A3A3A'].map(C),fence:C('#BDB8AC'),
    gravel:C('#CFC5AE'),path:C('#D8C69C'),white:C('#E9E5DB'),white2:C('#D6D1C5'),grave:['#E8E4DA','#D3CFC5','#BDB8AE','#CFC2B2','#A8A49C'].map(C),stone:C('#C9C1B0'),
    tile:C('#A35C42'),tile2:C('#8E4F3A'),lawn:PAL.lawn,lawn2:C('#8AA055'),sand:C('#DCCB9E'),asph:C('#6E6A64'),line:C('#F1EEE4'),
    grass:C('#6F9F48'),grass2:C('#7DAD52'),dirt:C('#C39A6B'),court:C('#9EA39E'),court2:C('#5B8C74'),clay:C('#B5643F'),hard:C('#4F7C9A'),
    play:['#C23B32','#E2B33C','#3E6D9C','#4F8A4C'].map(C),soil:C('#B4A27C'),vine:C('#6F8B47'),vine2:C('#7E9A52'),orch:C('#A3A06C'),
    stall:['#3E6D9C','#E9E4D8','#D9792E','#4F8A4C','#C23B32'].map(C),pave:C('#A8A49C'),track:C('#D3BE94'),patch:['#C9B58C','#C2B98E','#A8AD76','#B3A77E','#9FA86E'].map(C),
    golf:C('#86AE58'),golf2:C('#7BA44F'),green:C('#69A345'),bunker:C('#E2D4A6'),walls:['#E8DCC4','#F0E6D2','#D9C9A7','#E6D3B5','#E4E0D6'].map(C)};
  // a pitch on the rectangle (a0..a1, b0..b1) of frame fr: surface, mowing stripes, lines (ESTETICA: 0.5 m), goals or hoops
  // (surf: the surface's colour, laid as a layer of its own when lay; grass gets mowing stripes)
  const pitch=(fr,a0,b0,a1,b1,sport,r,surf,lay)=>{const L=a1-a0,W=b1-b0,lw=.5,ln=(p,q,s,t,y=0.14)=>flatD(fr.R(p,q,s,t),y,K.line);
    const kind=/soccer|futbol|football/.test(sport)?'f':/tennis|padel/.test(sport)?'t':/basket|multi|volley|futsal|hand/.test(sport)?'b':'o';
    if(lay)flatD(fr.R(a0,b0,a1,b1),0.12,surf);
    if(kind==='f'&&surf===K.grass)for(let k=0,n=Math.max(2,Math.round(L/9));k<n;k+=2)flatD(fr.R(a0+L*k/n,b0,a0+L*(k+1)/n,b1),0.13,K.grass2);
    if(L<12||W<8)return;
    ln(a0,b0,a1,b0+lw);ln(a0,b1-lw,a1,b1);ln(a0,b0,a0+lw,b1);ln(a1-lw,b0,a1,b1);ln((a0+a1-lw)/2,b0,(a0+a1+lw)/2,b1);
    const cu=(a0+a1)/2,cv=(b0+b1)/2;
    if(kind==='f'){const R0=Math.min(9.15,W*.14),P=(R,t)=>fr.G(cu+R*Math.cos(t),cv+R*Math.sin(t));for(let i=0;i<16;i++){const t0=i/16*Math.PI*2,t1=(i+1)/16*Math.PI*2;
        flatD([P(R0-lw/2,t0),P(R0-lw/2,t1),P(R0+lw/2,t1),P(R0+lw/2,t0)],0.14,K.line);}
      const pd=Math.min(16.5,L*.16),pw=Math.min(40,W*.6);
      for(const sg of [1,-1]){const e=sg>0?a0:a1,f=e+sg*pd;ln(Math.min(e,f),cv-pw/2,Math.max(e,f),cv-pw/2+lw);ln(Math.min(e,f),cv+pw/2-lw,Math.max(e,f),cv+pw/2);ln(f-lw/2,cv-pw/2,f+lw/2,cv+pw/2);
        const gw=Math.min(3.66,W*.06);for(const gv of [cv-gw,cv+gw]){const q=fr.R(e-sg*.6-.25,gv-.25,e-sg*.6+.25,gv+.25);S.dy=groundMin(q);S.prism(q,0.3,2.4,K.line,K.line);}}}
    else if(kind==='b'){for(const e of [a0+1.2,a1-1.2]){const q=fr.R(e-.3,cv-.3,e+.3,cv+.3);S.dy=groundMin(q);S.prism(q,0.3,3,C('#3A3A3A'),C('#3A3A3A'));
      const bq=fr.R(e+(e<cu?.3:-.6),cv-.9,e+(e<cu?.6:-.3),cv+.9);S.dy=groundMin(bq);S.prism(bq,2.6,3.7,K.line,K.line);}}
    else if(kind==='t'){const q=fr.R(cu-.25,b0,cu+.25,b1);S.dy=groundMin(q);S.prism(q,0.3,1.1,C('#2E2C2B'),K.line);ln(a0+L*.23,cv-lw/2,a1-L*.23,cv+lw/2);}};
  const bleachers=(fr,a0,a1,b,dir,n)=>{for(let k=0;k<n;k++){const q=fr.R(a0,b+dir*k*1.1,a1,b+dir*(k+1)*1.1).map(p=>p);const qq=ccwQ(q);S.dy=groundMin(qq);S.prism(qq,0.3,0.6+k*.55,k%2?C('#B9B2A3'):C('#C9C3B6'),k%2?C('#C9C3B6'):C('#D9D3C5'));}};
  // ---- the uses
  const draw={
    industrial(u,r,fr){ground(u,K.yard);if(u.built)return;const objs=[];
      if(u.o.t==='corral'){ // a yard of parked vehicles (the municipal impound): rows of cars and buses, an office
        for(let v=fr.v0+5;v<fr.v1-5;v+=7)for(let a=fr.u0+4;a<fr.u1-4;a+=2.6){if(r()<.25)continue;const bus=r()<.08,q=fr.R(a,v,a+(bus?2.5:1.9),v+(bus?11:4.5));if(!fits(u,q,2))continue;
          S.dy=groundMin(q);const c=bus?C('#E2B33C'):pick(r,[K.truck,C('#B9BCBE'),C('#6E7276'),C('#2F3133'),C('#9C2F27'),C('#2E3F66')]);S.prism(q,0.3,bus?3:1.5,shade(c,.85),c);if(bus)a+=1;}
        return;}
      for(let v=fr.v0+6;v<fr.v1-10;){const d=16+r()*22;let a=fr.u0+5;
        while(a<fr.u1-12){const w=Math.min(18+r()*34,fr.u1-5-a);if(w<12)break;const q=fr.R(a,v,a+w,v+d);
          if(r()<.8&&fits(u,q,4,objs)){objs.push(q);const h=6+r()*4.5,kind=d>26&&r()<.45?'saw':r()<.75?'gable':'flat';shed(q,h,pick(r,K.swalls),pick(r,K.zinc),kind);
            if(r()<.35){const tq=fr.R(a+2,v-4.2,a+12,v-1.8);if(fits(u,tq,2,objs)){S.dy=groundMin(tq);S.prism(tq,0.3,3.9,K.truck,K.truck);const cq=fr.R(a+12.3,v-4.2,a+14.6,v-1.8);S.dy=groundMin(cq);S.prism(cq,0.3,3.1,pick(r,K.cab),C('#2C3540'));}}
            if(r()<.15){const c=fr.G(a+w+5,v+3);const tq=ngon(c[0],c[1],2.6+r()*1.4,8);if(fits(u,fr.R(a+w+2,v,a+w+8,v+6),2,objs)){S.dy=groundMin(tq);S.prism(tq,0.3,6+r()*6,K.tank,shade(K.tank,.85));}}}
          a+=w+6+r()*8;}
        v+=d+10+r()*6;}
      wallsOf(u,2.2,.5,K.fence,K.fence);},
    cementerio(u,r,fr){const park=/parque/i.test(u.o.t||'');ground(u,park?K.lawn:K.gravel);const cu=(fr.u0+fr.u1)/2,cv=(fr.v0+fr.v1)/2,objs=[];
      if(park){rows(fr,3.2,.5,0.13,C('#DAD7CB'));for(let k=0;k<u.A/500;k++){const p=fr.G(fr.u0+r()*(fr.u1-fr.u0),fr.v0+r()*(fr.v1-fr.v0));if(inUso(u,...p)&&!nearStreet(...p,3))tree(p[0],p[1],.9+r()*.4,r());}}
      else{// avenues along v and u through the middle, with cypresses; quarters of niches, graves or mausoleums between them
        for(const [a,b] of usoSpans({...fr,lr:fr.lr.map(p=>[p[1],p[0]]),kl:fr.kl.map(k=>k.map(p=>[p[1],p[0]]))},cu))strip({...fr,G:(x,y)=>fr.G(y,x),R:(a0,b0,a1,b1)=>fr.R(b0,a0,b1,a1)},cu-4,cu+4,a,b,0.13,C('#DCD3BF'));
        for(const [a,b] of usoSpans(fr,cv))strip(fr,cv-3,cv+3,a,b,0.13,C('#DCD3BF'));
        for(let v=fr.v0+3;v<fr.v1;v+=6)for(const sd of [-1,1]){const p=fr.G(cu+sd*5,v);if(inUso(u,...p)&&!occ0At(...p)&&!nearStreet(...p,2))tree(p[0],p[1],.75+r()*.15,r()*.2,true);}
        for(let a=fr.u0+4;a<fr.u1-8;a+=40)for(let v=fr.v0+4;v<fr.v1-8;v+=27){const a1=Math.min(a+36,fr.u1-4),v1=Math.min(v+23,fr.v1-4);
          if(Math.abs((a+a1)/2-cu)<(a1-a)/2+4||Math.abs((v+v1)/2-cv)<(v1-v)/2+3)continue; // the avenues
          if(!fits(u,fr.R(a,v,a1,v1),3))continue;const t=r();
          // rows of niches: a long block of three tiers, its body in the shaded white and a cornice 0.25 m wider on top
          if(t<.3){for(let b=v+2;b+3.2<v1;b+=9){const q=fr.R(a+1,b,a1-1,b+3.2);S.dy=groundMin(q);S.prism(q,0.3,3.0,K.white2,K.white2);S.prism(fr.R(a+.75,b-.25,a1-.75,b+3.45),3.0,3.4,K.white,K.white);}}
          // graves in rows: two tones and two heights alternating by row, a darker stone here and there, some gaps
          else if(t<.85){let row=0;for(let b=v+1;b+2.2<v1;b+=3.4,row++)for(let c=a+1;c+1.1<a1;c+=1.9){if(r()<.12)continue;const q=fr.R(c,b,c+1.1,b+2.2);S.dy=groundMin(q);
              const col=r()<.15?K.grave[4]:row%2?K.grave[1]:K.grave[0];S.prism(q,0.3,row%2?.55:.8,shade(col,.9),col);}}
          else{for(let b=v+1;b+5<v1;b+=8)for(let c=a+1;c+4<a1;c+=6.5){const q=fr.R(c,b,c+4,b+5);S.dy=groundMin(q);const col=pick(r,[K.stone,K.white,C('#B7AE9E')]);S.gable(q,0.3,3.2,1.2,col,shade(col,.8));}}}
        const ch=fr.R(cu-6,fr.v0+8,cu+6,fr.v0+26);if(fits(u,ch,3)){pavilion(ch.slice(1).concat([ch[0]]),2,K.white,K.tile,true);const tq=fr.R(cu-2,fr.v0+4.5,cu+2,fr.v0+8.5);S.dy=groundMin(tq);S.prism(tq,0.3,13,K.white,K.white);pyramid(S,tq,13,3,K.tile);}}
      wallsOf(u,2.8,.6,K.white,K.white2,(x,y)=>{const [a,b]=fr.L(x,y);return Math.abs(a-cu)<4||Math.abs(b-cv)<3;});},
    militar(u,r,fr){ground(u,C('#C2B591'));const cu=(fr.u0+fr.u1)/2,cv=(fr.v0+fr.v1)/2,pw=Math.min(130,(fr.u1-fr.u0)*.45),pd=Math.min(80,(fr.v1-fr.v0)*.35),objs=[];
      const pg=fr.R(cu-pw/2,cv-pd/2,cu+pw/2,cv+pd/2);if(fits(u,pg,3)){flatD(pg,0.12,K.asph);objs.push(pg);for(const s of [-1,1])flatD(fr.R(cu-pw/2+3,cv+s*(pd/2-3)-.25,cu+pw/2-3,cv+s*(pd/2-3)+.25),0.14,K.line);
        const fq=fr.R(cu-.3,cv-pd/2-3,cu+.3,cv-pd/2-2.4);S.dy=groundMin(fq);S.prism(fq,0.3,12,C('#707070'),C('#707070'));}
      for(const [b0,dir] of [[cv-pd/2-8,-1],[cv+pd/2+8,1]])for(let k=0;k<3;k++){const b=b0+dir*k*26;for(let a=fr.u0+8;a<fr.u1-50;a+=52){const q=ccwQ(fr.R(a,b,a+44,b+dir*12));
        if(fits(u,q,4,objs)){objs.push(q);pavilion(q,2,pick(r,[C('#E9DFC8'),C('#E2D3B4')]),r()<.6?K.tile:pick(r,K.zinc),true);}}}
      for(let a=fr.u0+6;a<fr.u1;a+=9)for(const b of [fr.v0+5,fr.v1-5]){const p=fr.G(a,b);if(inUso(u,...p)&&!occ0At(...p)&&!nearStreet(...p,2))tree(p[0],p[1],1+r()*.3,r());}
      wallsOf(u,2.6,.6,C('#D8C7A0'),C('#E9E1CC'));},
    educacional(u,r,fr){const big=u.A>2.5e4;ground(u,big?K.lawn:C('#C8BFA9'));const objs=[],W=pick(r,K.walls),Rf=r()<.5?pick(r,K.zinc):K.tile,fl=r()<.6?2:1+Math.floor(r()*3);
      const cands=[[fr.u0+3,fr.v0+3,fr.u1-3,fr.v0+12],[fr.u0+3,fr.v1-12,fr.u1-3,fr.v1-3],[fr.u0+3,fr.v0+15,fr.u0+12,fr.v1-15],[fr.u1-12,fr.v0+15,fr.u1-3,fr.v1-15]];
      if(big)for(let a=fr.u0+6;a<fr.u1-30;a+=44)for(let b=fr.v0+6;b<fr.v1-12;b+=34)cands.push([a,b,a+20+r()*16,b+10+r()*4]);
      for(const [a0,b0,a1,b1] of cands){for(const f of [1,.6,.35]){const L=(a1-a0)*f,D=(b1-b0)*Math.min(1,f+.3),am=(a0+a1)/2,bm=(b0+b1)/2;if(L<8||D<6)continue;
        const q=ccwQ(fr.R(am-L/2,bm-D/2,am+L/2,bm+D/2));if(fits(u,q,3,objs)){objs.push(q);const L2=Math.hypot(q[1][0]-q[0][0],q[1][1]-q[0][1]),D2=Math.hypot(q[3][0]-q[0][0],q[3][1]-q[0][1]);
          pavilion(L2>=D2?q:q.slice(1).concat([q[0]]),fl,W,Rf,Rf===K.tile);break;}}}
      if(!u.kids.some(k=>k.k==='deportivo')){const cu=(fr.u0+fr.u1)/2,cv=(fr.v0+fr.v1)/2;for(const [L,D] of [[30,17],[22,13]]){const q=fr.R(cu-L/2,cv-D/2,cu+L/2,cv+D/2);if(fits(u,q,2,objs)){pitch(fr,cu-L/2+.5,cv-D/2+.5,cu+L/2-.5,cv+D/2-.5,'multi',r,r()<.5?K.court:K.court2,true);objs.push(q);break;}}}
      for(let k=0;k<Math.min(40,u.A/400);k++){const p=fr.G(fr.u0+r()*(fr.u1-fr.u0),fr.v0+r()*(fr.v1-fr.v0));if(inUso(u,...p)&&!occ0At(...p)&&!nearStreet(...p,3)&&objs.every(o=>!pip(p,o)))tree(p[0],p[1],.8+r()*.4,r());}},
    salud(u,r,fr){ground(u,C('#BDB7AA'));const objs=[];for(let a=fr.u0+4;a<fr.u1-14;a+=34)for(let b=fr.v0+4;b<fr.v1-10;b+=26){const q=ccwQ(fr.R(a,b,a+26+r()*6,b+12+r()*6));
      if(fits(u,q,3,objs)){objs.push(q);pavilion(q,1+Math.floor(r()*3),C('#ECEAE3'),C('#B3AFA6'),false);}}},
    deportivo(u,r,fr){const L=fr.u1-fr.u0,W=fr.v1-fr.v0;
      if(u.o.c){const fill=u.A/(L*W);const sp=u.o.c,surf=/soccer|futbol/.test(sp)?(r()<.62?K.grass:K.dirt):/tennis|padel/.test(sp)?(r()<.6?K.clay:K.hard):/basket|multi|volley|futsal|hand/.test(sp)?(r()<.5?K.court:K.court2):K.dirt;
        ground(u,surf);if(fill>.75)pitch(fr,fr.u0+1.5,fr.v0+1.5,fr.u1-1.5,fr.v1-1.5,sp,r,surf,false);return;}
      ground(u,C('#AFB277'));const objs=[];
      if(!u.kids.some(k=>k.k==='deportivo')){const cu=(fr.u0+fr.u1)/2,cv=(fr.v0+fr.v1)/2;
        for(const [pl,pd] of [[100,64],[90,55],[60,40],[40,22]]){const q=fr.R(cu-pl/2,cv-pd/2,cu+pl/2,cv+pd/2);if(fits(u,q,2)){objs.push(q);pitch(fr,cu-pl/2,cv-pd/2,cu+pl/2,cv+pd/2,'soccer',r,r()<.6?K.grass:K.dirt,true);
          const bq=fr.R(cu-pl*.3,cv+pd/2+2,cu+pl*.3,cv+pd/2+2+4*1.1);if(fits(u,bq,2,objs)){bleachers(fr,cu-pl*.3,cu+pl*.3,cv+pd/2+2,1,4);objs.push(bq);}break;}}}
      const hq=ccwQ(fr.R(fr.u0+4,fr.v0+4,fr.u0+20,fr.v0+12));if(fits(u,hq,3,objs))pavilion(hq,1,pick(r,K.walls),pick(r,K.zinc),false);
      for(let a=fr.u0+5;a<fr.u1;a+=10)for(const b of [fr.v0+3,fr.v1-3]){const p=fr.G(a,b);if(r()<.6&&inUso(u,...p)&&!occ0At(...p)&&!nearStreet(...p,2)&&objs.every(o=>!pip(p,o)))tree(p[0],p[1],1+r()*.3,r(),r()<.4);}},
    golf(u,r,fr){ground(u,K.golf);rows(fr,24,12,0.13,K.golf2);
      for(let v=fr.v0+30;v<fr.v1-10;v+=55)for(let a=fr.u0+5;a<fr.u1;a+=7){if(Math.sin(a*.05+v)>.55)continue;const p=fr.G(a+(r()-.5)*3,v+(r()-.5)*4);if(inUso(u,...p)&&!occ0At(...p)&&!nearStreet(...p,3))tree(p[0],p[1],1.1+r()*.4,r(),r()<.15);}
      for(let k=0;k<u.A/1.2e4;k++){const a=fr.u0+r()*(fr.u1-fr.u0),b=fr.v0+r()*(fr.v1-fr.v0),c=fr.G(a,b),R=8+r()*6;if(!fits(u,fr.R(a-R,b-R,a+R,b+R),4))continue;
        flatD(ngon(c[0],c[1],R,12),0.14,K.green);const s=fr.G(a+R+5,b+r()*6-3);flatD(ngon(s[0],s[1],3+r()*2.5,10),0.14,K.bunker);
        const fq=[[c[0]-.25,c[1]-.25],[c[0]+.25,c[1]-.25],[c[0]+.25,c[1]+.25],[c[0]-.25,c[1]+.25]];S.dy=groundMin(fq);S.prism(fq,0.3,2.6,K.line,C('#C23B32'));}},
    parque(u,r,fr){ground(u,K.lawn);const cu=(fr.u0+fr.u1)/2,cv=(fr.v0+fr.v1)/2,L=fr.u1-fr.u0,W=fr.v1-fr.v0,objs=[];
      for(const [a,b] of usoSpans(fr,cv))strip(fr,cv-1.25,cv+1.25,a,b,0.13,K.path);
      if(W>30)for(const [a,b] of usoSpans({...fr,lr:fr.lr.map(p=>[p[1],p[0]]),kl:fr.kl.map(k=>k.map(p=>[p[1],p[0]]))},cu))strip({...fr,G:(x,y)=>fr.G(y,x),R:(a0,b0,a1,b1)=>fr.R(b0,a0,b1,a1)},cu-1.25,cu+1.25,a,b,0.13,K.path);
      if(u.A>2500){const pq=fr.R(cu+6,cv+5,cu+18,cv+15);if(fits(u,pq,3)){flatD(pq,0.14,K.sand);objs.push(pq);for(let k=0;k<3;k++){const c=fr.G(cu+8.5+k*3.5,cv+7+(k%2)*4),q=[[c[0]-.6,c[1]-.6],[c[0]+.6,c[1]-.6],[c[0]+.6,c[1]+.6],[c[0]-.6,c[1]+.6]];S.dy=groundMin(q);S.prism(q,0.3,1+k*.6,K.play[k],K.play[(k+1)%4]);}}}
      for(let a=fr.u0+r()*10;a<fr.u1;a+=20+r()*8)for(let b=fr.v0+r()*10;b<fr.v1;b+=20+r()*8){if(r()<.3)continue;const n=2+Math.floor(r()*5);
        for(let k=0;k<n;k++){const ta=a+(r()-.5)*12,tb=b+(r()-.5)*12;if(Math.abs(tb-cv)<3||(W>30&&Math.abs(ta-cu)<3))continue;const p=fr.G(ta,tb);
          if(inUso(u,...p)&&!occ0At(...p)&&!nearStreet(...p,2)&&objs.every(o=>!pip(p,o)))tree(p[0],p[1],.9+r()*.5,r());}}},
    huerto(u,r,fr){ground(u,K.orch);for(let b=fr.v0+3;b<fr.v1-2;b+=6)for(const [a0,a1] of usoBand(fr,b-1,b+1))for(let a=a0+2.5;a<a1-2;a+=5.5){const p=fr.G(a,b);if(!occ0At(...p)&&!nearStreet(...p,2))tree(p[0],p[1],.42+r()*.08,.25+r()*.3);}},
    vina(u,r,fr){ground(u,K.soil);rows(fr,2.8,1.2,0.13,K.vine,K.vine2);},
    potrero(u,r,fr){const c=pick(r,PAL.fields);ground(u,c);rows(fr,18,9,0.13,shade(c,.93));},
    // a bus terminal: paved yard, platforms under long canopies, buses at the bays
    terminal(u,r,fr){ground(u,K.pave);const objs=[];for(let v=fr.v0+6;v<fr.v1-8;v+=22){const L=Math.min(90,fr.u1-fr.u0-12),a=(fr.u0+fr.u1)/2-L/2,q=ccwQ(fr.R(a,v,a+L,v+5));
        if(!fits(u,q,3))continue;flatD(fr.R(a,v,a+L,v+5),0.13,C('#C9C3B6'));S.dy=groundMin(q);S.prism(ccwQ(fr.R(a,v+1.5,a+L,v+3.5)),4.2,4.8,K.white2,C('#B9BCBE'),true);
        for(const c of [a+1,a+L-1.5])for(const b of [v+2.3]){const pq=fr.R(c,b,c+.5,b+.5);S.dy=groundMin(pq);S.prism(pq,0.3,4.2,C('#707070'),C('#707070'));}
        for(let c=a+2;c<a+L-3;c+=4.2){if(r()<.35)continue;const bq=ccwQ(fr.R(c,v+5.6,c+2.6,v+17.6));if(!fits(u,bq,2))continue;S.dy=groundMin(bq);const col=pick(r,[K.truck,C('#3E6D9C'),C('#E2B33C'),C('#B4372C')]);S.prism(bq,0.3,3.3,shade(col,.85),col);}}},
    feria(u,r,fr){ground(u,K.pave);for(let v=fr.v0+3;v<fr.v1-3;v+=7.5)for(let a=fr.u0+2;a<fr.u1-3;a+=3.2){const q=fr.R(a,v,a+3,v+3);if(r()<.15||!fits(u,q,1))continue;S.dy=groundMin(q);const col=pick(r,K.stall);S.prism(q,0.3,2.5,shade(col,.8),col);}},
    // housing the census does not have, where the map has no streets in it (a social housing estate of identical
    // semi-detached houses): passages along u every 30 m, a row of houses facing each, on their yards
    conjunto(u,r,fr){const yc=pick(r,PAL.yard);ground(u,yc);const Ws=[0,1,2].map(()=>pick(r,PAL.walls)),Rf=r()<.65?pick(r,PAL.tile):pick(r,PAL.zinc),fl=r()<.7?1:2,objs=[];
      for(let v=fr.v0+4;v<fr.v1-4;v+=30){for(const [a,b] of usoBand(fr,v,v+5))strip(fr,v,v+5,a,b,0.13,PAL.asphalt);
        for(const [b0,dir] of [[v-2.5,-1],[v+7.5,1]])for(let a=fr.u0+2;a<fr.u1-6;a+=16.5){const q=ccwQ(fr.R(a,b0,a+13,b0+dir*7.5));if(!fits(u,q,2.5,objs))continue;objs.push(q);
          for(const h of [0,6.5]){const hq=ccwQ(fr.R(a+h,b0,a+h+6.5,b0+dir*7.5));B.dy=groundMin(hq);B.gable(hq,0.3,fl*2.8+.3,1.9,pick(r,Ws),Rf);} // a semi-detached pair
          if(r()<.3){const t=fr.G(a+r()*13,b0+dir*(10+r()*2.5));if(inUso(u,...t))tree(t[0],t[1],.6+r()*.3,r());}}}},
    // rural housing (parcelas): a house every 25-45 m along the map's roads in the polygon, set back on a big plot with
    // trees around it; the ground stays (farmland, terrain)
    parcelas(u,r,fr){const seen=new Set(),objs=[];
      for(let gx=Math.max(0,Math.floor((u.bb[0]-XMIN)/SG));gx<=Math.min(sgW-1,Math.floor((u.bb[2]-XMIN)/SG));gx++)for(let gy=Math.max(0,Math.floor((u.bb[1]-YMIN)/SG));gy<=Math.min(sgH-1,Math.floor((u.bb[3]-YMIN)/SG));gy++)
        for(const id of sgrid[gy*sgW+gx]){if(seen.has(id))continue;seen.add(id);const [ax,ay,bx,by,hw]=segs[id],L=Math.hypot(bx-ax,by-ay);if(L<8)continue;const tx=(bx-ax)/L,ty=(by-ay)/L;
          for(const sd of [1,-1])for(let t=r()*20;t<L-6;t+=25+r()*20){const o=hw+6+r()*8,w=8+r()*4,d=7+r()*2,nx=-ty*sd,ny=tx*sd,P=(s,v)=>[ax+tx*(t+s)+nx*(o+v),ay+ty*(t+s)+ny*(o+v)];
            const q=ccwQ([P(0,0),P(w,0),P(w,d),P(0,d)]);if(!fits(u,q,3,objs))continue;objs.push(q);B.dy=groundMin(q);B.gable(q,0.3,r()<.8?3.1:6,d*.25,pick(r,PAL.walls),r()<.7?pick(r,PAL.tile):pick(r,PAL.zinc));
            for(let k=0,n=2+Math.floor(r()*4);k<n;k++){const p=P(r()*w*1.6-w*.3,d+3+r()*14);if(inUso(u,...p)&&!occ0At(...p)&&!nearStreet(...p,2))tree(p[0],p[1],.8+r()*.5,r(),r()<.2);}}}},
    bosque(u,r,fr){const d=(u.o.a||110)/1e4,n=Math.round(u.A*d),[x0,y0,x1,y1]=u.bb;for(let k=0,t=0;k<n&&t<n*3;t++){const x=x0+r()*(x1-x0),y=y0+r()*(y1-y0);
      if(!inUso(u,x,y)||occ0At(x,y)||nearStreet(x,y,2)||(wildAt(x,y)>.35&&blockAt(x,y)<0))continue;k++;tree(x,y,.9+r()*.6,r(),r()<.25);}}, // (wildTrees() covers steep ground outside the blocks)
    eriazo(u,r,fr){if(u.green)ground(u,PAL.open); // a vacant lot on a small block "sin información" (painted as a park): its sand
      const m=u.o.m??.35,ta=(u.o.a??4)/1e4,[x0,y0,x1,y1]=u.bb,nz=(x,y)=>.5+.5*Math.sin(x*.023+u.i)*Math.cos(y*.019-u.i*.7);
      for(let x=x0+r()*9;x<x1;x+=9)for(let y=y0+r()*9;y<y1;y+=9){const px=x+(r()-.5)*7,py=y+(r()-.5)*7;if(r()>m*1.6*nz(px,py)||!inUso(u,px,py)||occ0At(px,py)||nearStreet(px,py,2))continue;
        for(let k=0,n=1+Math.floor(r()*3);k<n;k++)tree(px+(r()-.5)*4,py+(r()-.5)*4,.3+r()*.22,.1+r()*.5);}
      for(let k=0;k<u.A*ta;k++){const x=x0+r()*(x1-x0),y=y0+r()*(y1-y0);if(inUso(u,x,y)&&!occ0At(x,y)&&!nearStreet(x,y,2))tree(x,y,.8+r()*.5,r());}
      // patches of bare dirt, dry grass and greener grass (ellipses of 8-30 m that do not touch each other: one height)
      const pat=[];for(let k=0;k<u.A/1100;k++){const c=fr.G(fr.u0+r()*(fr.u1-fr.u0),fr.v0+r()*(fr.v1-fr.v0)),R=8+r()*26,e=.45+r()*.55,a0=r()*Math.PI;
        if(pat.some(([x,y,s])=>Math.hypot(x-c[0],y-c[1])<s+R+2))continue;
        if(![0,1,2,3,4,5,6,7,8].every(j=>{const t=j*Math.PI/4,d=j<8?R:0,x=c[0]+Math.cos(t)*d,y=c[1]+Math.sin(t)*d;return inUso(u,x,y)&&!occ0At(x,y)&&!nearStreet(x,y,1);}))continue;
        pat.push([c[0],c[1],R]);const ca=Math.cos(a0),sa=Math.sin(a0);
        flatD(ngon(0,0,R,10).map(([x,y])=>[c[0]+x*ca-y*e*sa,c[1]+x*sa+y*e*ca]),u.green?0.12:0.11,pick(r,K.patch));}
      // dirt tracks: random walks of 2 m wide segments
      for(let k=0;k<Math.ceil(u.A/6e4);k++){let p=fr.G(fr.u0+r()*(fr.u1-fr.u0),fr.v0+r()*(fr.v1-fr.v0)),h=r()*Math.PI*2;
        for(let s=0;s<40;s++){h+=(r()-.5)*.6;const q=[p[0]+Math.cos(h)*9,p[1]+Math.sin(h)*9];if(!inUso(u,...q)||occ0At(...q)||nearStreet(...q,1))break;
          const nx=-Math.sin(h)*1.5,ny=Math.cos(h)*1.5;flatD([[p[0]+nx,p[1]+ny],[p[0]-nx,p[1]-ny],[q[0]-nx,q[1]-ny],[q[0]+nx,q[1]+ny]],0.13,K.track);p=q;}}}};
  for(const u of USOS){if(u.skip||!draw[u.k])continue;const r=rng(1000+u.i*7919);draw[u.k](u,r,usoFrame(u));USTAT.n[u.k]=(USTAT.n[u.k]||0)+1;}
  usosFringe();
  S.dy=0;B.dy=0;if(UG.nv)scene.add(new T.Mesh(UG.geo(),matFlat));USTAT.verts=UG.nv;
  USTAT.ms=Math.round(performance.now()-t0);window.__usos=USTAT;OCC0=null;
}
// the urban fringe: bare ground with no census block, use or farmland parcel within ~250 m of built blocks gets scrub
// (the farmland of buildBase() only takes whole 160 x 130 m cells free of blocks, so the cells it skips are tested the
// same way here)
function usosFringe(){const r=rng(31337),G=100,urb=new Uint8Array(bgW*bgH);
  blocks.forEach(b=>{if(!b.built)return;const gx=Math.floor((b.cx-XMIN)/BG),gy=Math.floor((b.cy-YMIN)/BG);for(let i=-2;i<=2;i++)for(let j=-2;j<=2;j++){const x=gx+i,y=gy+j;if(x>=0&&y>=0&&x<bgW&&y<bgH)urb[y*bgW+x]=1;}});
  let n=0;for(let x=XMIN;x<XMAX;x+=160)for(let y=YMIN;y<YMAX;y+=130){
    if(blockAt(x+80,y+65)<0&&blockAt(x+3,y+3)<0&&blockAt(x+157,y+127)<0&&blockAt(x+3,y+127)<0&&blockAt(x+157,y+3)<0)continue; // farmland there
    for(let k=0;k<70;k++){const px=x+r()*160,py=y+r()*130,g=Math.floor((px-XMIN)/BG)+Math.floor((py-YMIN)/BG)*bgW;
      if(!inTerrain(px,py)||!urb[g]||blockAt(px,py)>=0||occAt(px,py)||nearStreet(px,py,3)||wildAt(px,py)>.3||(UGRID[g]||[]).some(u=>!u.skip&&inUso(u,px,py)))continue;
      if(r()>.45*(.5+.5*Math.sin(px*.021)*Math.cos(py*.017)))continue;
      for(let j=0,m=1+Math.floor(r()*3);j<m;j++){TREES.push([px+(r()-.5)*4,py+(r()-.5)*4,.3+r()*.25,.1+r()*.5]);n++;}}}
  USTAT.fringe=n;USTAT.trees+=n;
}

