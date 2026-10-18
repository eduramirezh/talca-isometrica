// ==== edificios de OSM ====
// The buildings of OpenStreetMap (pipeline/edificios.py, config/edificios.json; METODOLOGIA §14): DATA.ed lists the
// census blocks OSM has (a point inside each): whole (m), where OSM has them all, and mixed (x), where it has some;
// their buildings (footprint with courtyards, height, kind, floors, roof colour from the satellite image or none, and
// the block's place in m then x) and the surfaces OSM draws in them (parking, grass, gardens, pools, playgrounds).
// cityGen() lays no lots in a whole block (blocks[bi].osm); in a mixed one (blocks[bi].mixto) it fills the street
// fronts the OSM buildings leave free. This draws them:
//  - edificiosPlan(), after the landmarks and before the land uses, leaves out the buildings a landmark already models
//    (its point inside, or a quarter of the footprint on what the landmarks occupy or fence), cuts every footprint at
//    the line of the sidewalks (the map's streets are wider than the real ones, and OSM may sit a few metres off the
//    census blocks: trap «Calzadas del mapa y plantas de OSM») and marks it in occ with 3: the trees and the uses'
//    objects keep out of it, while the street level (sidewalks, crosswalks, street trees, parked cars), which only
//    yields to 1, and cityGen's tests, which only see 1, go on as before. In a mixed block it also closes to the lots
//    (lotBlock: the exact test of cityGen, not the raster) the convex hull of each building grown by ED_GAP, and of
//    each surface: the lots and their yards shrink around them as they do around each other.
//  - edificiosBase(B, Z, Y, bks), with the final terrain and before the city: each building on its real footprint, in
//    the city's vocabulary (docs/ESTETICA.md): walls with the window shader on B; a flat roof with a white parapet, or a
//    hipped roof made by insetting the footprint (any plan, concave too: the slopes rise to the inset outline and
//    a flat cap closes it, a truncated hip that reads as one at 0.5 m per art pixel) on the low houses whose
//    roof is tile, rust or sheet; shopfronts on the street fronts of the centre (shopFront, as cityGen's); a stair
//    and lift housing and a water tank on the towers; canopies on posts, ruins without a roof, sheds without windows
//    (Z). Then the ground of each block, on a 1 m raster: in a whole block, the strip between the sidewalk and the
//    facades as sidewalk (in the centre the facades stand on the line of the street; the map's sidewalks end ~2.4 m
//    short of them), the OSM surfaces, and every other cell in the patio colour of the nearest building (a
//    breadth-first search from the footprints); in a mixed block, only the hulls closed to the lots (cityGen's lots
//    bring their own yards). Merged into rectangles of slab like cityGen's lots (Y, 0.2 m over the ground). Each block
//    is a piece of the startup with its own key (2.5e7 + its place in DATA.ed): the first view's blocks come before
//    the first frame, the rest in rest() (trap «El arranque en dos etapas»).
// window.__ed: counts, the buildings left out for a landmark, and the ms taken.
const ED_GAP=2,ED_SOLID=6e4;
const ED_T0=performance.now(),ED=(()=>{const D=DATA.ed;if(!D)return {list:[],surf:[],bks:[]};const dm=a=>dec(a).map(p=>[p[0]/10,p[1]/10]);
  const box=r=>{let x0=1e9,y0=1e9,x1=-1e9,y1=-1e9;for(const p of r){x0=Math.min(x0,p[0]);x1=Math.max(x1,p[0]);y0=Math.min(y0,p[1]);y1=Math.max(y1,p[1]);}return [x0,y0,x1,y1];};
  const bks=D.m.map(p=>[p,false]).concat((D.x||[]).map(p=>[p,true])).map(([[x,y],mix],k)=>{let bi=blockAt(x,y);if(bi>=0&&(blocks[bi].osm||blocks[bi].mixto))bi=-1;
    if(bi>=0)blocks[bi][mix?'mixto':'osm']=true;return {bi,mix,k,eds:[],surf:[],obs:[],paved:[],bb:bi>=0?blocks[bi].bb:[x,y,x,y]};});
  // the loose footprints (outside every census block: villas after the census, farm buildings), in groups of 500 m
  // cells with their box: no block, no ground of their own
  for(const bb of D.z||[])bks.push({bi:-1,mix:false,loose:true,k:bks.length,eds:[],surf:[],obs:[],paved:[],bb});
  const seed=id=>{let h=2166136261;for(let i=0;i<id.length;i++)h=Math.imul(h^id.charCodeAt(i),16777619);return h>>>0;};
  // a machine-learning footprint has no id (0): its seed comes from its encoded footprint, its id is its block's
  const seedN=a=>{let h=2166136261;for(let i=0;i<a.length;i++)h=Math.imul(h^(a[i]&0xffff),16777619);return h>>>0;};
  const list=D.e.map(([id,rings,h,t,lv,roof,est,k,f=0])=>{const R=rings.map(dm),e={id:id||'ml'+k,R,h:h/10,t:D.tipos[t],lv,roof:roof<0?null:D.techos[roof],est:est===1,f:D.fuentes?D.fuentes[f]:'osm',bb:box(R[0]),bk:bks[k],seed:id?seed(id):seedN(rings[0])};
    bks[k].eds.push(e);if(f)bks[k].ml=true;return e;});
  const surf=D.s.map(([r,s,k])=>{const R=dm(r),o={r:R,k:D.superficies[s],bb:box(R)};bks[k].surf.push(o);return o;});
  // a mixed block under ED_SOLID with machine-learning footprints has its houses nearly all drawn: its own ground
  // (buildBase) takes the yard colour of its barrio (edYardCol) instead of the 2 m raster of yards, which then only
  // runs around its other buildings and surfaces (paved)
  for(const bk of bks)if(bk.ml&&bk.mix&&bk.bi>=0&&blocks[bk.bi].A<ED_SOLID)bk.solid=blocks[bk.bi].edYard=true;
  return {list,surf,bks};})();
const EDS={decodeMs:Math.round(performance.now()-ED_T0),blocks:ED.bks.filter(b=>!b.mix&&!b.loose).length,mixed:ED.bks.filter(b=>b.mix).length,loose:ED.bks.filter(b=>b.loose).length,
  src:ED.list.reduce((o,e)=>(o[e.f]=(o[e.f]||0)+1,o),{}),buildings:0,inMixed:0,hulls:0,landmark:[],clipped:0,dropped:0,shops:0,hip:0,cells:0,cellsX:0,rects:0,ms:0};
// the convex hull of ring r grown by d (counter-clockwise): Andrew's monotone chain over its points, then the
// Minkowski sum with an octagon of radius d, merging the edges of both by their angle (the same polygon as the hull of
// every point moved d in eight directions, which took ~0.35 s of the startup over the 70 thousand footprints)
const ED_OCT=[];for(let k=0;k<8;k++){const a=-Math.PI/2+k*Math.PI/4;ED_OCT.push([Math.cos(a),Math.sin(a)]);} // from the lowest point, counter-clockwise
function edHull(r,d){const P=r.slice().sort((a,b)=>a[0]-b[0]||a[1]-b[1]),X=(o,a,b)=>(a[0]-o[0])*(b[1]-o[1])-(a[1]-o[1])*(b[0]-o[0]),lo=[],hi=[];
  for(const p of P){while(lo.length>1&&X(lo[lo.length-2],lo[lo.length-1],p)<=0)lo.pop();lo.push(p);}
  for(let i=P.length-1;i>=0;i--){const p=P[i];while(hi.length>1&&X(hi[hi.length-2],hi[hi.length-1],p)<=0)hi.pop();hi.push(p);}
  const H=lo.slice(0,-1).concat(hi.slice(0,-1));if(!d||H.length<3)return H;
  let s=0;for(let i=1;i<H.length;i++)if(H[i][1]<H[s][1]||(H[i][1]===H[s][1]&&H[i][0]<H[s][0]))s=i;
  const n=H.length,o=[];let i=0,j=0;
  while(i<n||j<8){const p=H[(s+i)%n],q=ED_OCT[j%8];o.push([p[0]+d*q[0],p[1]+d*q[1]]);
    const p1=H[(s+i+1)%n],q1=ED_OCT[(j+1)%8],c=(p1[0]-p[0])*(q1[1]-q[1])-(p1[1]-p[1])*(q1[0]-q[0]);
    if(j>=8||(i<n&&c>0))i++;else if(i>=n||c<0)j++;else{i++;j++;}}
  const h=[];for(const p of o){while(h.length>1&&X(h[h.length-2],h[h.length-1],p)<=1e-9)h.pop();h.push(p);}
  while(h.length>2&&X(h[h.length-2],h[h.length-1],h[0])<=1e-9)h.pop();while(h.length>2&&X(h[h.length-1],h[0],h[1])<=1e-9)h.shift();
  return h;}
const ringArea=r=>{let A=0;for(let i=0,j=r.length-1;i<r.length;j=i++)A+=r[j][0]*r[i][1]-r[i][0]*r[j][1];return A/2;};
// the part of ring r on the side of the line through a (direction t, unit) where the signed distance is >= m
function clipHalf(r,a,t,side,m){const o=[],d=p=>side*((p[0]-a[0])*t[1]-(p[1]-a[1])*t[0])-m;
  for(let i=0;i<r.length;i++){const p=r[i],q=r[(i+1)%r.length],dp=d(p),dq=d(q);if(dp>=0)o.push(p);
    if((dp>=0)!==(dq>=0)){const s=dp/(dp-dq);o.push([p[0]+(q[0]-p[0])*s,p[1]+(q[1]-p[1])*s]);}}
  return o;}
function edificiosPlan(){const t0=performance.now();
  const HN=NOLOTS.map(q=>({q,bb:ringBox(q)}));
  const pts=Object.values(MODELS);
  for(const e of ED.list){const [x0,y0,x1,y1]=e.bb,R=e.R[0];
    // a landmark models it already (the samples inside the footprint are counted only when one of them falls on a
    // landmark: with the machine-learning footprints the pip tests took ~0.1 s of the startup)
    const hn=HN.filter(({bb})=>bb[0]<=x1&&bb[2]>=x0&&bb[1]<=y1&&bb[3]>=y0),inHito=(x,y)=>hn.some(({q,bb})=>x>=bb[0]&&x<=bb[2]&&y>=bb[1]&&y<=bb[3]&&pip([x,y],q));
    let n=0,hit=0,any=false;for(let i=0;i<4&&!any;i++)for(let j=0;j<4;j++){const x=x0+(x1-x0)*(i+.5)/4,y=y0+(y1-y0)*(j+.5)/4;if(occAt(x,y)===1||inHito(x,y)){any=true;break;}}
    if(any)for(let i=0;i<4;i++)for(let j=0;j<4;j++){const x=x0+(x1-x0)*(i+.5)/4,y=y0+(y1-y0)*(j+.5)/4;if(!pip([x,y],R))continue;n++;if(occAt(x,y)===1||inHito(x,y))hit++;}
    if(pts.some(m=>m.x>=x0&&m.x<=x1&&m.y>=y0&&m.y<=y1&&pip([m.x,m.y],R))||(n&&hit>=n/4)){e.skip=true;EDS.landmark.push(e.id);continue;}
    // cut at the line of the sidewalks of every street segment it reaches into
    const A0=ringArea(R),seen=new Set(),cOf=O=>{let c=[0,0];for(const p of O){c[0]+=p[0];c[1]+=p[1];}return [c[0]/O.length,c[1]/O.length];};let rings=e.R,c=cOf(R);
    for(let gx=Math.max(0,Math.floor((x0-XMIN)/SG));gx<=Math.min(sgW-1,Math.floor((x1-XMIN)/SG));gx++)for(let gy=Math.max(0,Math.floor((y0-YMIN)/SG));gy<=Math.min(sgH-1,Math.floor((y1-YMIN)/SG));gy++)
      for(const id of sgrid[gy*sgW+gx]){if(seen.has(id))continue;seen.add(id);const s=segs[id],st=streets[s[5]];if(st.bridge)continue;
        const L=Math.hypot(s[2]-s[0],s[3]-s[1]);if(L<0.5)continue;const t=[(s[2]-s[0])/L,(s[3]-s[1])/L],a=[s[0],s[1]],m=s[4]+(walkOf(st)?WALK_OUT:0.3);
        const O=rings[0];
        const side=Math.sign((c[0]-a[0])*t[1]-(c[1]-a[1])*t[0])||1;
        const reach=O.some(p=>{const u=(p[0]-a[0])*t[0]+(p[1]-a[1])*t[1],d=side*((p[0]-a[0])*t[1]-(p[1]-a[1])*t[0]);return u>=0&&u<=L&&d<m;});
        if(!reach)continue;const o=clipHalf(O,a,t,side,m);if(o.length<3){rings=null;break;}
        rings=[o,...rings.slice(1).filter(h=>h.every(p=>side*((p[0]-a[0])*t[1]-(p[1]-a[1])*t[0])>=m))];c=cOf(o);}
    if(!rings||ringArea(rings[0])<Math.max(4,A0*.4)){e.skip=true;EDS.dropped++;continue;}
    if(rings!==e.R){e.R=rings;EDS.clipped++;}
    occMark(e.R[0],3);EDS.buildings++;
    // a loose footprint is closed to the lots too: a vivienda block of config/usos.json may cover it (pipeline/edificios.py
    // gives the footprints inside one to its block, but usos.json may have changed since)
    if(e.bk.mix||e.bk.loose){const q=edHull(e.R[0],ED_GAP);lotBlock(q);e.bk.obs.push(q);if(e.t!=='casa')e.bk.paved.push(q);EDS.inMixed+=e.bk.mix;EDS.hulls++;}}
  for(const bk of ED.bks)if(bk.mix)for(const s of bk.surf){const q=edHull(s.r,0);lotBlock(q);bk.obs.push(q);bk.paved.push(q);EDS.hulls++;}
  EDS.planMs=Math.round(performance.now()-t0);}
// r inset by d (counter-clockwise ring; the corners mitred, an acute one clipped at 2.5 d), or null where the
// outline would fold over itself (a part narrower than 2 d)
function insetRing(r,d){const n=r.length,o=[];
  for(let i=0;i<n;i++){const p=r[(i+n-1)%n],q=r[i],s=r[(i+1)%n];let ax=q[0]-p[0],ay=q[1]-p[1],bx=s[0]-q[0],by=s[1]-q[1];const la=Math.hypot(ax,ay)||1,lb=Math.hypot(bx,by)||1;ax/=la;ay/=la;bx/=lb;by/=lb;
    let mx=-ay-by,my=ax+bx;const ml=Math.hypot(mx,my);if(ml<1e-6)return null;mx/=ml;my/=ml;const c=mx*-ay+my*ax;if(c<0.2)return null;const k=Math.min(d/c,2.5*d);o.push([q[0]+mx*k,q[1]+my*k]);}
  for(let i=0;i<n;i++){const a=r[i],b=r[(i+1)%n],p=o[i],q=o[(i+1)%n];if((b[0]-a[0])*(q[0]-p[0])+(b[1]-a[1])*(q[1]-p[1])<=0)return null;}
  const X=(a,b,c,e)=>{const d1=(b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0]),d2=(b[0]-a[0])*(e[1]-a[1])-(b[1]-a[1])*(e[0]-a[0]),d3=(e[0]-c[0])*(a[1]-c[1])-(e[1]-c[1])*(a[0]-c[0]),d4=(e[0]-c[0])*(b[1]-c[1])-(e[1]-c[1])*(b[0]-c[0]);return d1*d2<0&&d3*d4<0;};
  if(n<=80)for(let i=0;i<n;i++)for(let j=i+2;j<n;j++){if(i===0&&j===n-1)continue;if(X(o[i],o[(i+1)%n],o[j],o[(j+1)%n]))return null;}
  return ringArea(o)>1?o:null;}
// a flat polygon with holes at height y (over G.dy), facing up
GB.prototype.flatH=function(rings,y,col){const V=a=>a.map(p=>new T.Vector2(p[0],p[1]));let tris;
  try{tris=T.ShapeUtils.triangulateShape(V(rings[0]),rings.slice(1).map(V));}catch(e){return;}
  const all=[].concat(...rings);this.grow(all.length,tris.length*3);const base=this.nv;
  for(const p of all){const k=this.nv*3;this.P[k]=p[0];this.P[k+1]=y+this.dy;this.P[k+2]=-p[1];this.N[k]=0;this.N[k+1]=127;this.N[k+2]=0;this.C[k]=col[0];this.C[k+1]=col[1];this.C[k+2]=col[2];this.nv++;}
  for(const t of tris){const a=all[t[0]],b=all[t[1]],c=all[t[2]],up=(b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])>=0;
    this.I[this.ni++]=base+t[0];this.I[this.ni++]=base+(up?t[1]:t[2]);this.I[this.ni++]=base+(up?t[2]:t[1]);}};
// the walls of a ring from y0 to y1, facing out of the building's mass (outer rings counter-clockwise, courtyards
// clockwise: the right-hand normal of each edge); y0 <= 0.31 goes 4 m under the ground, as prism()
function ringWalls(G,r,y0,y1,col){const yw=y0<=0.31?y0-4:y0;
  for(let i=0;i<r.length;i++){const a=r[i],b=r[(i+1)%r.length],L=Math.hypot(b[0]-a[0],b[1]-a[1]);if(L<0.05)continue;const nx=(b[1]-a[1])/L,ny=-(b[0]-a[0])/L;
    G.face([[a[0],yw,-a[1]],[b[0],yw,-b[1]],[b[0],y1,-b[1]],[a[0],y1,-a[1]]],[nx,0,-ny],col);}}
const ED_K={wall:{casa:PAL.wallsCore,comercio:PAL.wallsCore,otro:PAL.wallsCore,departamentos:CP.wallsApt.concat(PAL.wallsCore),
    publico:['#ECE7DC','#E8DFCC','#E6D3B5','#D9D2C2'].map(hex),iglesia:['#ECE7DC','#E8DFCC'].map(hex),galpon:CP.wallsShed,techo:CP.wallsShed,ruina:['#B5967C','#C2B49A'].map(hex)},
  parapet:hex('#E9E5DB'),post:hex('#6E6A64'),
  surf:{estacionamiento:hex('#8F8C86'),pasto:PAL.lawn,jardin:hex('#93A85B'),piscina:PAL.water2,juegos:hex('#D2BF92')},walk:hex('#C3C1BA')};
// the blocks bks (pieces of ED.bks), each its buildings then its ground
function edificiosBase(B,Z,Y,bks){const t0=performance.now();
  for(const bk of bks){B.k=Z.k=Y.k=2.5e7+bk.k; // after the Cerro (2e7), before the city (3e7 +)
    const t1=performance.now();for(const e of bk.eds)if(!e.skip)edificio(B,Z,e);const t2=performance.now();edificiosGround(Y,bk);
    EDS.msEd=(EDS.msEd||0)+t2-t1;EDS[bk.mix?'msGx':'msGm']=(EDS[bk.mix?'msGx':'msGm']||0)+performance.now()-t2;}
  B.dy=Z.dy=Y.dy=0;EDS.ms+=performance.now()-t0;window.__ed=EDS;}
function edificio(B,Z,e){const r=rng(e.seed),R=e.R[0],holes=e.R.slice(1),t=e.t;
  let lv=e.lv,h=e.h;if(e.est&&(t==='casa'||t==='otro'||t==='comercio')){lv=r()<.7?1:2;h=lv*3+.5;} // no height in OSM: one or two storeys, as the centre's
  const G=t==='galpon'||t==='techo'||t==='ruina'?Z:B;B.dy=Z.dy=groundMin(R);
  // a house of a mixed block takes its barrio's walls and roofs (cityGen's recipe: a villa's one roof colour, a
  // población's mix), one of a whole block the centre's
  const H=t==='casa'&&e.bk.mix&&e.bk.bi>=0?recipeOf(e.bk.bi).h:null;
  const wall=pick(r,H?H.wl:ED_K.wall[t]||PAL.wallsCore);
  // the roof's colour: the satellite's family, else the barrio's or the centre's mix for a house, light or grey for
  // the rest (a tower's roof is displaced in the image, which is not orthorectified: its sample is facade or street,
  // and the warm families there are wrong; towers keep the light and grey ones)
  const sat=e.roof&&!(lv>=4&&/tile|rust|red/.test(e.roof))?e.roof:null;
  const rf=sat||(H?(H.mix?fam(r,H.mix):H.rf):t==='casa'?fam(r,MIX.core):t==='galpon'?pick(r,['zinc','zincOld','light']):r()<.5?'light':null);
  const roof=rf?CP.roof[rf][r()<.5?0:1]:pick(r,PAL.flat);
  if(t==='techo'){ // a canopy on posts (a petrol station, a car park)
    ringWalls(Z,R,Math.max(.4,h-.5),h,shade(roof,.85));Z.flatH([R],h,roof);const step=Math.max(1,Math.floor(R.length/6));
    for(let i=0;i<R.length;i+=step){const q=insetRing(R,.8);const p=q?q[i]:R[i];Z.prism([[p[0]-.25,p[1]-.25],[p[0]+.25,p[1]-.25],[p[0]+.25,p[1]+.25],[p[0]-.25,p[1]+.25]],.3,h-.5,ED_K.post,ED_K.post);}
    return;}
  if(t==='ruina'){for(const ring of e.R)ringWalls(Z,ring,.3,2.4,wall);return;}
  const pitched=!holes.length&&lv<=2&&t!=='departamentos'&&rf&&rf!=='light'&&(t==='casa'||t==='iglesia'||t==='galpon'||r()<.45);
  let cap=null,d=0;if(pitched)for(d=Math.min(4,Math.sqrt(Math.abs(ringArea(R)))*.3);d>=.9;d*=.7){cap=insetRing(R,d);if(cap)break;}
  if(cap){ // a truncated hip: each slope from the eaves up to the inset outline, the cap closing it
    EDS.hip++;const rh=d*(t==='galpon'?.3:.5),hl=Math.hypot(d,rh),s=rh/hl,c=d/hl;ringWalls(G,R,.3,h,wall);
    for(let i=0;i<R.length;i++){const a=R[i],b=R[(i+1)%R.length],L=Math.hypot(b[0]-a[0],b[1]-a[1]);if(L<0.05)continue;const nx=(b[1]-a[1])/L,ny=-(b[0]-a[0])/L,p=cap[i],q=cap[(i+1)%R.length];
      G.face([[a[0],h,-a[1]],[b[0],h,-b[1]],[q[0],h+rh,-q[1]],[p[0],h+rh,-p[1]]],[nx*s,c,-ny*s],nx+ny<0?shade(roof,.9):roof);}
    G.flatH([cap],h+rh,roof);}
  else{ // flat, with a white parapet where the outline allows one
    const I=insetRing(R,.5),ph=t==='galpon'?.3:.6;
    if(I){ringWalls(G,R,.3,h+ph,wall);ringWalls(G,I.slice().reverse(),h,h+ph,shade(wall,.9));G.flatH([R,I.slice().reverse()],h+ph,ED_K.parapet);G.flatH([I,...holes],h,roof);}
    else{ringWalls(G,R,.3,h,wall);G.flatH([R,...holes],h,roof);}
    for(const k of holes)ringWalls(G,k,.3,h,wall);
    if(lv>=4&&I){ // the stair and lift housing, and a water tank, on the roof
      let cx=0,cy=0;for(const p of I){cx+=p[0];cy+=p[1];}cx/=I.length;cy/=I.length;const w=1.6+r()*.6,dd=2+r()*.8,q=[[cx-w,cy-dd],[cx+w,cy-dd],[cx+w,cy+dd],[cx-w,cy+dd]];
      if(q.every(p=>pip(p,I))){Z.prism(q,h,h+2.8,shade(wall,.92),pick(r,PAL.flat));
        const tq=ngon(cx+w+1.6,cy,1.1,8);if(r()<.6&&tq.every(p=>pip(p,I))){Z.prism(tq,h,h+1.8,CP.tank[0],CP.tank[1]);}}}}
  // shopfronts on the street fronts: most of the centre's ground floors are shops
  // (fewer on the machine-learning footprints: they are the suburbs and the countryside, where OSM would tag a shop)
  const ps=(e.f==='osm'?{comercio:.9,otro:.6,casa:.35,departamentos:.6}:{otro:.25,casa:.05,departamentos:.3})[t]||0;if(!ps)return;
  for(let i=0;i<R.length;i++){const a=R[i],b=R[(i+1)%R.length],L=Math.hypot(b[0]-a[0],b[1]-a[1]);if(L<4.5)continue;
    const tx=(b[0]-a[0])/L,ty=(b[1]-a[1])/L,nx=ty,ny=-tx,mx=(a[0]+b[0])/2,my=(a[1]+b[1])/2;
    if(!nearStreet(mx+nx*4.5,my+ny*4.5,0)||r()>ps)continue;
    const P=(u,v)=>[a[0]+tx*u-nx*v,a[1]+ty*u-ny*v],F={f:[nx,0,-ny],b:[-nx,0,ny],l:[-tx,0,ty],r:[tx,0,-ty]};
    shopFront(Z,P,F,.3,L-.3,0,4,lv===1?1:2,h,wall,CP.signCore,r,0);EDS.shops++;}}
// the ground of an OSM block on a 1 m raster (see the header): the cells inside it and off the streets' sidewalks,
// each the front strip, an OSM surface, or the patio of its nearest building (up to 40 m away; ED_YARD in a mixed
// block), merged into rectangles. A whole block lays them as slabs; a mixed one drapes them on the ground at 0.135
// (at 0.11, the land uses' height, it came out striped in the pixel art beside the Lider of Avenida Colín; 0.135 lies
// between the streets' classes, and the margin
// keeps a cell off any carriageway), under cityGen's lots (slabs 0.2 m over the ground) wherever those land: the yards of the OSM houses
// that face the passages inside a block (the map has no lots there) and the ground between them. A mixed block takes
// one raster for each group of buildings whose yards may meet (by their boxes): one over the block would cover tens
// of hectares of nothing in the large blocks of the outskirts
const ED_XS=[],ED_YARD=20;
// the yard colour of a solid block (bk.solid): the one edRaster gives its houses
const edYardCol=bi=>pick(rng(bi*131+7),recipeOf(bi).h.yc||PAL.patio);
function edificiosGround(Y,bk){if(bk.bi<0)return;if(!bk.mix){edRaster(Y,bk,blocks[bk.bi].bb);return;}
  const m=ED_YARD+2,gs=(bk.solid?bk.paved:bk.obs).map(q=>{const r=ringBox(q);return [r[0]-m,r[1]-m,r[2]+m,r[3]+m];});
  for(let merged=true;merged;){merged=false;
    for(let i=0;i<gs.length;i++)for(let j=gs.length-1;j>i;j--){const a=gs[i],c=gs[j];if(a[2]<c[0]||c[2]<a[0]||a[3]<c[1]||c[3]<a[1])continue;
      gs[i]=[Math.min(a[0],c[0]),Math.min(a[1],c[1]),Math.max(a[2],c[2]),Math.max(a[3],c[3])];gs.splice(j,1);merged=true;}}
  for(const g of gs)edRaster(Y,bk,g);}
// the raster of block bk over the box bb
// (a block with machine-learning footprints, bk.ml, takes 2 m cells and merges its rectangles by colour, not by
// owner: with its tens of thousands of houses the 1 m raster took ~2.8 s of the startup and 5.7 million vertices)
function edRaster(Y,bk,bb){const C=bk.ml?2:1,FRONT=3.2,{bi,mix,surf}=bk,xs=ED_XS,eds=bk.eds.filter(e=>!e.skip),b=blocks[bi];
  const bx0=Math.max(bb[0],b.bb[0]),by0=Math.max(bb[1],b.bb[1]),bx1=Math.min(bb[2],b.bb[2]),by1=Math.min(bb[3],b.bb[3]);if(bx1<=bx0||by1<=by0)return;
  const X0=Math.floor(bx0/C)*C,Y0=Math.floor(by0/C)*C,nx=Math.ceil((bx1-X0)/C),ny=Math.ceil((by1-Y0)/C);
  // own: 0 outside, -1 street margin, -2 front strip (-4 along a paseo: its paving), -3 occupied before (landmark, land use), 10+k surface k,
  // 100+k building k (its patio), 1 open (assigned by the search)
  const own=new Int32Array(nx*ny),dist=new Int16Array(nx*ny).fill(-1);
  const fill=(ring,v,only)=>{const rb=ringBox(ring),i0=Math.max(0,Math.floor((rb[0]-X0)/C)),i1=Math.min(nx,Math.ceil((rb[2]-X0)/C)+1);
    for(let j=Math.max(0,Math.floor((rb[1]-Y0)/C));j<Math.min(ny,Math.ceil((rb[3]-Y0)/C)+1);j++){const y=Y0+(j+.5)*C;pipRow(ring,y,xs);if(!xs.length)continue;let k=0;
      for(let i=i0;i<i1;i++){const x=X0+(i+.5)*C;while(k<xs.length&&xs[k]<=x)k++;if((xs.length-k)&1){const c=j*nx+i;if(!only||only(own[c]))own[c]=v;}}}};
  fill(b.r,1);
  // the streets: each segment near the block marks its margin and the front strip behind it (none in a mixed block)
  const seen=new Set();
  for(let gx=Math.max(0,Math.floor((bx0-20-XMIN)/SG));gx<=Math.min(sgW-1,Math.floor((bx1+20-XMIN)/SG));gx++)for(let gy=Math.max(0,Math.floor((by0-20-YMIN)/SG));gy<=Math.min(sgH-1,Math.floor((by1+20-YMIN)/SG));gy++)
    for(const id of sgrid[gy*sgW+gx]){if(seen.has(id))continue;seen.add(id);const s=segs[id],st=streets[s[5]];const m=s[4]+(walkOf(st)?WALK_OUT:mix?0.8:0.3),f=!mix&&(walkOf(st)||st.paseo)?m+FRONT:m,fv=st.paseo?-4:-2;
      const i0=Math.max(0,Math.floor((Math.min(s[0],s[2])-f-X0)/C)),i1=Math.min(nx-1,Math.ceil((Math.max(s[0],s[2])+f-X0)/C)),j0=Math.max(0,Math.floor((Math.min(s[1],s[3])-f-Y0)/C)),j1=Math.min(ny-1,Math.ceil((Math.max(s[1],s[3])+f-Y0)/C));
      for(let j=j0;j<=j1;j++)for(let i=i0;i<=i1;i++){const c=j*nx+i;if(own[c]===0||own[c]===-1)continue;const d2=segDist2(X0+(i+.5)*C,Y0+(j+.5)*C,s[0],s[1],s[2],s[3]);
        if(d2<m*m)own[c]=-1;else if(d2<f*f&&own[c]!==-2)own[c]=fv;}}
  // what was there before: a landmark, a land use (occ 1), or a landmark's fenced ground (NOLOTS: the Mall's car park)
  // and, in a mixed block, any land use (but parcelas): their ground and an eriazo's patches lie at 0.11 too, and an
  // industrial use or an eriazo leave occ free
  const HN=NOLOTS.filter(q=>{const r=ringBox(q);return r[2]>=bx0&&r[0]<=bx1&&r[3]>=by0&&r[1]<=by1;}),UN=new Set();
  if(mix)for(let gx=Math.floor((bx0-XMIN)/BG);gx<=Math.floor((bx1-XMIN)/BG);gx++)for(let gy=Math.floor((by0-YMIN)/BG);gy<=Math.floor((by1-YMIN)/BG);gy++)
    for(const u of UGRID[gy*bgW+gx]||[])if(!u.skip&&u.k!=='parcelas')UN.add(u);
  // a row at a time: the crossings of each ring that reaches the row (pipRow), with the box tests of inRing() for NOLOTS
  // and of the land uses: the same answers as inRing() and pipXY() cell by cell, which took ~0.2 s of the startup
  const RS=[...HN.map(q=>{const rb=ringBox(q);return [q,rb[0]-1,rb[1]-1,rb[2]+1,rb[3]+1,true];}),...[...UN].map(u=>[u.r,...u.bb,false])],
    RX=RS.map(()=>[]),RK=new Int32Array(RS.length),on=[];
  for(let j=0;j<ny;j++){const y=Y0+(j+.5)*C;on.length=0;
    for(let n=0;n<RS.length;n++){const R=RS[n];if(R[5]?y>R[2]&&y<R[4]:y>=R[2]&&y<=R[4]){pipRow(R[0],y,RX[n]);if(RX[n].length){on.push(n);RK[n]=0;}}}
    for(let i=0;i<nx;i++){const c=j*nx+i;if(own[c]<=0)continue;const x=X0+(i+.5)*C;if(occAt(x,y)===1){own[c]=-3;continue;}
      for(const n of on){const R=RS[n],xs=RX[n];let k=RK[n];while(k<xs.length&&xs[k]<=x)k++;RK[n]=k; // x grows along the row
        if((R[5]?x>R[1]&&x<R[3]:x>=R[1]&&x<=R[3])&&(xs.length-k)&1){own[c]=-3;break;}}}}
  surf.forEach((s,k)=>fill(s.r,10+k,v=>v>0||v===-2||v===-4));
  eds.forEach((e,k)=>fill(e.R[0],bk.solid&&e.t==='casa'?-5:100+k,v=>v>0||v===-2||v===-4)); // under the building: its own patio colour (hidden, no seams at the walls); a house of a solid block, none (-5)
  // breadth-first from the footprints: an open cell takes the patio of the nearest building
  const qu=new Int32Array(nx*ny),reach=Math.round((mix?ED_YARD:40)/C);let qh=0,qt=0;for(let c=0;c<nx*ny;c++)if(own[c]>=100){qu[qt++]=c;dist[c]=0;}
  while(qh<qt){const c=qu[qh++],i=c%nx,j=(c-i)/nx;if(dist[c]>=reach)continue;
    for(const n of [i>0?c-1:-1,i<nx-1?c+1:-1,j>0?c-nx:-1,j<ny-1?c+nx:-1]){if(n<0||own[n]!==1||dist[n]>=0)continue;own[n]=own[c];dist[n]=dist[c]+1;qu[qt++]=n;}}
  // colours: by owner (in a mixed block a house's yard in its barrio's colours, other buildings' paved; a cell no
  // building reached is left to the block's ground), then rectangles (runs along x merged down the rows while they match)
  const r=rng(bi*131+7),yc=mix?recipeOf(bi).h.yc||PAL.patio:PAL.patio,
    yb=bk.solid?pick(r,yc):null, // a solid block's (the colour of its ground, edYardCol; its houses lay no yard here)
    pc=eds.map(e=>e.t==='techo'||e.t==='galpon'||(mix&&e.t!=='casa'&&e.t!=='otro')?pick(r,CP.paved):yb||pick(r,yc)),
    colOf=v=>v===-2?ED_K.walk:v===-4?PASEO_K.pave:v===1?(mix?null:PAL.backlot[bi%3]):v>=100?pc[v-100]:v>=10?ED_K.surf[surf[v-10].k]:null;
  const laid=(i,j)=>{if(i<0||j<0||i>=nx||j>=ny)return false;const v=own[j*nx+i];return v>0||v===-2||v===-4;};
  // a whole block: the tops of the rectangles lie on one plane fitted to its ground (least squares over a 5 m grid of
  // it, raised to clear the highest point by o): with a top per rectangle at its own height, the few millimetres
  // between neighbours were outlined by the pixel art, and tops following the terrain left cracks at the T-junctions
  let qa=0,qb=0,qc=E(X0+nx/2,Y0+ny/2),lift=0;
  if(!mix){let n=0,sx=0,sy=0,sz=0,sxx=0,syy=0,sxy=0,sxz=0,syz=0;
    for(let j=0;j<ny;j+=5)for(let i=0;i<nx;i+=5){if(!laid(i,j))continue;const x=i-nx/2,y=j-ny/2,z=E(X0+i+.5,Y0+j+.5);n++;sx+=x;sy+=y;sz+=z;sxx+=x*x;syy+=y*y;sxy+=x*y;sxz+=x*z;syz+=y*z;}
    if(n>=3){const mx=sx/n,my=sy/n,mz=sz/n,cxx=sxx/n-mx*mx,cyy=syy/n-my*my,cxy=sxy/n-mx*my,cxz=sxz/n-mx*mz,cyz=syz/n-my*mz,det=cxx*cyy-cxy*cxy;
      if(Math.abs(det)>1e-9){qa=(cxz*cyy-cyz*cxy)/det;qb=(cyz*cxx-cxz*cxy)/det;}qc=mz-qa*mx-qb*my;}
    for(let j=0;j<ny;j+=2)for(let i=0;i<nx;i+=2){if(!laid(i,j))continue;lift=Math.max(lift,E(X0+i+.5,Y0+j+.5)-(qa*(i+.5-nx/2)+qb*(j+.5-ny/2)+qc));}}
  const plane=(x,y)=>qa*(x-X0-nx/2)+qb*(y-Y0-ny/2)+qc+Math.min(lift,.6);
  let open=new Map();const emit=(x0,x1,y0,y1,v)=>{const col=colOf(v);if(!col)return;const q=[[X0+x0*C,Y0+y0*C],[X0+x1*C,Y0+y0*C],[X0+x1*C,Y0+y1*C],[X0+x0*C,Y0+y1*C]];EDS.rects++;
    if(mix){drapeQ(Y,q,.135,col);return;}
    const o=v===-2||v===-4?.18:.2,sd=shade(col,.82);Y.dy=0;const tp=q.map(p=>[p[0],plane(p[0],p[1])+o,-p[1]]);Y.face(tp,[0,1,0],col);
    const out=[[(x0+x1)/2,y0-.5,0,-1],[x1+.5,(y0+y1)/2,1,0],[(x0+x1)/2,y1+.5,0,1],[x0-.5,(y0+y1)/2,-1,0]];
    // an underlay 3 cm lower, wider by 0.25 m on the sides with a laid neighbour: the raster leaves pixel gaps at the
    // T-junctions between rectangles, and they show it, in the same colour, instead of the ground (an outlined dot)
    const g=out.map(([ci,cj])=>laid(Math.floor(ci),Math.floor(cj))?.25:0),u=[[X0+x0-g[3],Y0+y0-g[0]],[X0+x1+g[1],Y0+y0-g[0]],[X0+x1+g[1],Y0+y1+g[2]],[X0+x0-g[3],Y0+y1+g[2]]];
    if(g.some(v=>v))Y.face(u.map(p=>[p[0],plane(p[0],p[1])+o-.03,-p[1]]),[0,1,0],col);
    for(let k=0;k<4;k++){const [ci,cj,nx_,ny_]=out[k];if(laid(Math.floor(ci),Math.floor(cj)))continue;const a=tp[k],b=tp[(k+1)%4];
      Y.face([[a[0],E(q[k][0],q[k][1])-.4,a[2]],[b[0],E(q[(k+1)%4][0],q[(k+1)%4][1])-.4,b[2]],b,a],[nx_,0,-ny_],sd);}};
  const cid=new Map(),same=bk.ml?(v=>{const c=colOf(v);if(!c)return -1e9;let k=cid.get(c);if(k===undefined)cid.set(c,k=cid.size);return k;}):(v=>v);
  for(let j=0;j<=ny;j++){const cur=new Map();
    if(j<ny)for(let i=0;i<nx;){const v=own[j*nx+i],sv=same(v);let e=i+1;while(e<nx&&same(own[j*nx+e])===sv)e++;if(colOf(v)){EDS[mix?'cellsX':'cells']+=(e-i)*C*C;const k=i+','+e+','+sv,o=open.get(k);cur.set(k,o?o:[i,e,j,v]);open.delete(k);}i=e;}
    for(const [,[x0,x1,y0,v]] of open)emit(x0,x1,y0,j,v);open=cur;}}
