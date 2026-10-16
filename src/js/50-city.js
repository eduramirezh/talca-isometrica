/* =============== procedural city =============== */
function styleFor(bi){
  const b=blocks[bi];if(b._s)return b._s;
  const dc=Math.hypot(b.cx+8,b.cy+7);const ha=b.A/1e4;const dens=b.viv/Math.max(ha,.05);
  let s;
  if(dc<720||(dc<1250&&(b.pers===0||dens<14)))s='core';
  else if(b.pers===0&&b.viv===0)s=(ha>1.2?'ind':'core2');
  else if(dens>115)s='apt';
  else s='house';
  b._s=s;return s;
}
// The lots of cityGen are rectangles in LOTS, tested exactly against each other (sepQuad): the 2.5 m raster would leave a
// strip between neighbours or let two lots overlap, and two slabs at the same height flicker. occ marks them with 2,
// which lotFits skips: there the raster only stands for what was there before (landmarks, rivers, the Ruta 5, the rail).
const LG=40,lgW=Math.ceil((XMAX-XMIN)/LG),LOTS=[],lgrid=new Map(),lseen=[];let lstamp=0;
function sepQuad(A,B){return sepAxes(A,A,B)||sepAxes(B,A,B);}
function sepAxes(P,A,B){for(let i=0;i<P.length;i++){const a=P[i],b=P[(i+1)%P.length],nx=b[1]-a[1],ny=a[0]-b[0],L=Math.hypot(nx,ny)||1;
    let a0=1e9,a1=-1e9,b0=1e9,b1=-1e9;for(let j=0;j<A.length;j++){const p=A[j],d=(p[0]*nx+p[1]*ny)/L;if(d<a0)a0=d;if(d>a1)a1=d;}for(let j=0;j<B.length;j++){const p=B[j],d=(p[0]*nx+p[1]*ny)/L;if(d<b0)b0=d;if(d>b1)b1=d;}
    if(a1<=b0+.05||b1<=a0+.05)return true;}return false;}
function lotCells(q,f){let x0=1e9,y0=1e9,x1=-1e9,y1=-1e9;for(const p of q){x0=Math.min(x0,p[0]);x1=Math.max(x1,p[0]);y0=Math.min(y0,p[1]);y1=Math.max(y1,p[1]);}
  for(let gx=Math.floor((x0-XMIN)/LG);gx<=Math.floor((x1-XMIN)/LG);gx++)for(let gy=Math.floor((y0-YMIN)/LG);gy<=Math.floor((y1-YMIN)/LG);gy++)if(f(gy*lgW+gx)===false)return false;return true;}
function lotFree(q){lstamp++;return lotCells(q,k=>{const c=lgrid.get(k);if(c)for(const id of c){if(lseen[id]===lstamp)continue;lseen[id]=lstamp;if(!sepQuad(q,LOTS[id]))return false;}});}
function lotAdd(q){const id=LOTS.length;LOTS.push(q);lotCells(q,k=>{const c=lgrid.get(k);if(c)c.push(id);else lgrid.set(k,[id]);});occMark(q,2);}
// The city's palettes. Roofs come by family, each in two tones (a row of identical houses alternates them, ESTETICA §3).
// From pipeline/satellite.py on five neighbourhoods (diagnostics/sat-*.png): the barrios are a field of galvanized zinc,
// bright or weathered grey, with rusted, red, green and blue painted sheets; the old centre is dark weathered tile and
// rust; villas and condominiums have one colour for all their houses (grey zinc, red, clay tile); sheds are pale grey.
const CP={
  roof:{zinc:['#CFD2CF','#C0C4C4'],zincOld:['#A7AFB1','#98A2A6'],rust:['#8F5C42','#7D503B'],red:['#A9493A','#954134'],
    green:['#62806A','#557461'],blue:['#5B7592','#4D6782'],tile:['#B5563B','#A54C36'],tileOld:['#8F5644','#7D4B3C'],
    light:['#D3CFC5','#C3BFB5']},
  wallsPob:PAL.walls.concat(['#E3C08F','#D8A68C','#BCC9D2','#C5D3BC','#E9D58F'].map(hex)),
  wallsCondo:['#F0EBDF','#E8DECB','#DDD0B8','#E9E2D2'].map(hex),
  wallsApt:['#E2B8A0','#D9C68F','#B8C8AE','#B4C2CF','#E9DAC0','#D5A79A','#C9B9D0'].map(hex), // pastel social housing
  wallsShed:['#C9C6BE','#B7B3AA','#D4CFC3','#BDB9AE','#A9A69D'].map(hex),
  shedRoof:['#CDCFCC','#BFC3C3','#D8D8D2','#ADB2B4','#C9CBC8','#B9BEC0','#A7493B','#5B7592'].map(hex),
  wood:['#9A7B5C','#B39878','#8C735A','#C9BBA2'].map(hex), // mediaguas at the back of the yard
  yardPob:['#C7AE84','#BCA67F','#B9B4A8','#A2B068','#9DAF63','#B1A68A'].map(hex), // dirt, cement, some grass
  yardVilla:['#9DAF63','#A8B56E','#93A75C','#A2B068','#B9B4A8'].map(hex),
  yardOld:['#CDBB98','#BDB7AA','#A2B068','#B5967C','#9DAF63','#C7AE84'].map(hex),
  paved:['#B4B0A7','#A8A59D','#BEB9AD','#BFA987'].map(hex), lawn:['#9AAE60','#A5B26B','#93A85B'].map(hex), parking:hex('#8F8C86'),
  sign:['#B23A30','#D3A93A','#2F5D8C','#3E7A4E','#E6E0D2','#C2502E'].map(hex), // almacén and botillería signs
  signCore:['#8E3A32','#2E4A6B','#D9CDB0','#3F5C4E','#A8742E','#5A4636'].map(hex),
  door:hex('#77797A'), glass:hex('#3B4653'), fence:hex('#C8C3B8'), tank:['#D9D7D0','#BFC2C2','#E2DED3'].map(hex),
};
for(const k in CP.roof)CP.roof[k]=CP.roof[k].map(hex);
// roof mixes [family, weight]: houses drawn one by one from a mix (poblaciones, the old barrios, the centre)
const MIX={pob:[['zinc',35],['zincOld',30],['rust',15],['red',10],['green',5],['blue',5]],
  old:[['tileOld',30],['rust',25],['zincOld',25],['zinc',15],['tile',5]],
  core:[['tileOld',45],['tile',15],['rust',20],['zincOld',20]],
  villa:[['zinc',30],['zincOld',15],['red',30],['tile',15],['green',10]],
  condo:[['tile',60],['tileOld',20],['red',20]], apt:[['zinc',50],['zincOld',25],['red',25]]};
const fam=(r,mix)=>{let t=0;for(const m of mix)t+=m[1];let x=r()*t;for(const m of mix){x-=m[1];if(x<0)return m[0];}return mix[0][0];};
const tone=(f,k)=>CP.roof[f][k&1];
const wpick=(r,W)=>{let t=0;for(const w of W)t+=w;let x=r()*t;for(let k=0;k<W.length;k++){x-=W[k];if(x<0)return k;}return W.length-1;};
// Barrios. Talca grew by pieces, each built at once and alike inside: the colonial centre; the old barrios around it,
// one-storey houses on the line of the street with dark tile and rusted roofs (antiguo); poblaciones of self-built
// houses, every one different, with zinc roofs of every colour and a mediagua at the back (pob); villas of identical
// pareadas, two mirrored houses under one roof, each half painted by its owner (pareada); villas of two-storey rows
// (fila); condominiums of hipped-roof houses (condo); social-housing blocks (apt). The census only gives persons and
// dwellings per block, so the barrios are a seeded clustering: each built block goes to the nearest seed of a jittered
// BAR_G grid (a Voronoi of whole blocks, so a barrio ends at a street), and each barrio draws its recipe from its
// distance to the plaza and its density (dwellings per hectare): the old barrios ring the centre (to ~1.4 km), villas and
// condominiums are the outskirts, and dense barrios are villas of small lots. A block in seven takes the barrio's second
// recipe (a villa squeezed into a población). The recipe sets the house type, the lot width and its regularity, the
// floors, the roof family, the wall and yard colours, trees, sheds and corner shops.
const BAR_G=280,CITY={}; // CITY: counts for __stats
let BARS=null;
function barrioId(x,y){const gx=Math.floor(x/BAR_G),gy=Math.floor(y/BAR_G);let best=1e18,id=0;
  for(let i=gx-1;i<=gx+1;i++)for(let j=gy-1;j<=gy+1;j++){const q=rng((i+999)*7919+(j+999)*104729),sx=(i+.1+.8*q())*BAR_G,sy=(j+.1+.8*q())*BAR_G,d=(x-sx)**2+(y-sy)**2;
    if(d<best){best=d;id=(i+999)*4096+(j+999);}}
  return id;}
function houseRecipe(r,dc,D){const W=dc<1400?[60,30,10,0,0]:dc<2600?[6,49,25,11,9]:[0,35,30,17,18];
  if(D>75){W[3]*=2.5;W[2]*=1.5;W[4]*=.2;}else if(D<35){W[4]*=2;W[3]*=.3;}
  const t=['antiguo','pob','pareada','fila','condo'][wpick(r,W)],some=(a,n)=>{const o=[];for(let k=0;k<n;k++)o.push(pick(r,a));return o;};
  if(t==='antiguo')return {t,mix:MIX.old,wl:PAL.wallsCore,yc:CP.yardOld,tr:.35,sh:.3,sp:.3,yd:30};
  if(t==='pob')return {t,mix:MIX.pob,wl:CP.wallsPob,yc:CP.yardPob,tr:.35,sh:.6,sp:.3,yd:28};
  if(t==='pareada')return {t,wu:6+r()*1.5,d:6.5+r()*2,gp:2+r()*2,sb:2.5+r()*1.5,fl:r()<.4?2:1,rk:r()<.4?'hip':'gable',rf:fam(r,MIX.villa),wl:some(CP.wallsPob,3),yc:CP.yardVilla,tr:.25,sh:.35,sp:.12,yd:20};
  if(t==='fila')return {t,wu:5.5+r()*1.2,d:7+r(),sb:2+r(),rf:fam(r,MIX.villa),wl:some(CP.wallsPob,2),yc:CP.yardVilla,tr:.15,sh:.2,sp:.1,yd:14,n:5+Math.floor(r()*4)};
  return {t,wu:10+r()*2,d:8+r()*2,gp:3+r()*1.5,sb:4,rf:fam(r,MIX.condo),wl:some(CP.wallsCondo,2),yc:CP.yardVilla,tr:.55,sh:.05,sp:0,yd:22};}
function barrios(){BARS=new Map();
  blocks.forEach(b=>{if(!b.built)return;const id=b._bar=barrioId(b.cx,b.cy);let s=BARS.get(id);if(!s)BARS.set(id,s={A:0,Ac:0,viv:0,x:0,y:0});
    s.A+=b.A;s.x+=b.cx*b.A;s.y+=b.cy*b.A;if(b.t===0){s.Ac+=b.A;s.viv+=b.viv;}});
  for(const [id,s] of BARS){const r=rng(id*31+7),dc=Math.hypot(s.x/s.A+8,s.y/s.A+7),D=s.Ac?s.viv/(s.Ac/1e4):40;
    s.h=houseRecipe(r,dc,D);s.alt=houseRecipe(r,dc,D);
    s.a={perp:r()<.6,fl:r()<.75?3:4,gab:r()<.6,wl:[pick(r,CP.wallsApt),pick(r,CP.wallsApt)],rf:fam(r,MIX.apt)};}
  CITY.barrios=BARS.size;}
function recipeOf(bi){const b=blocks[bi];if(b._rec)return b._rec;if(!BARS)barrios();const s=BARS.get(b._bar);
  const ha=b.A/1e4,big=b.t===0&&ha>=2&&b.viv/ha<8&&Math.hypot(b.cx+8,b.cy+7)>=1250;
  return b._rec={h:rng(bi*977+3)()<.14?s.alt:s.h,a:s.a,ind:big?.4:0};}
// a hipped roof over the rectangle q (front-left, front-right, back-right, back-left) at height y, its ridge rh higher
// along the longer side: front and back slopes in two tones, the ends a step darker. The walls are a prism of their own
GB.prototype.hipRoof=function(q,y,rh,roof){const [A,Bq,C,D]=q,lf=Math.hypot(Bq[0]-A[0],Bq[1]-A[1]),ls=Math.hypot(D[0]-A[0],D[1]-A[1]),
    cx=(A[0]+C[0])/2,cy=(A[1]+C[1])/2,al=lf>=ls,e=al?[(Bq[0]-A[0])/lf,(Bq[1]-A[1])/lf]:[(D[0]-A[0])/ls,(D[1]-A[1])/ls],k=Math.abs(lf-ls)/2,
    R0=[cx-e[0]*k,cy-e[1]*k],R1=[cx+e[0]*k,cy+e[1]*k],V=(p,h)=>[p[0],h,-p[1]],t=y+rh,r2=shade(roof,.86),r3=shade(roof,.93);
  if(al){this.face([V(A,y),V(Bq,y),V(R1,t),V(R0,t)],null,roof);this.face([V(C,y),V(D,y),V(R0,t),V(R1,t)],null,r2);
    this.face([V(D,y),V(A,y),V(R0,t)],null,r3);this.face([V(Bq,y),V(C,y),V(R1,t)],null,r3);}
  else{this.face([V(A,y),V(Bq,y),V(R0,t)],null,roof);this.face([V(C,y),V(D,y),V(R1,t)],null,r2);
    this.face([V(D,y),V(A,y),V(R0,t),V(R1,t)],null,r3);this.face([V(Bq,y),V(C,y),V(R1,t),V(R0,t)],null,r3);}};
// Helpers on a lot's frame P(u, v) (u along the street, v away from it; the street is at -v). F holds the scene normals
// of the frame's directions: f toward the street, b away from it, l toward -u, r toward +u.
// a vertical quad u0..u1 at v, heights y0..y1 over G.dy, facing n
function wq(G,P,n,u0,u1,v,y0,y1,col){const a=P(u0,v),b=P(u1,v);G.face([[a[0],y0,-a[1]],[b[0],y0,-b[1]],[b[0],y1,-b[1]],[a[0],y1,-a[1]]],n,col);}
// a saw-tooth roof over u0..u1 x v0..v1 at height h: teeth ~7 m deep along v, their glazing toward the street
function sawRoof(G,P,F,u0,u1,v0,v1,h,wall,roof){const n=Math.max(2,Math.round((v1-v0)/7)),bw=(v1-v0)/n,rt=Math.min(2.6,bw*.4),V=(u,v,y)=>{const p=P(u,v);return [p[0],y,-p[1]];};
  for(let k=0;k<n;k++){const a=v0+k*bw,b=a+bw;
    G.face([V(u0,a,h),V(u1,a,h),V(u1,a,h+rt),V(u0,a,h+rt)],F.f,CP.glass);
    G.face([V(u0,a,h+rt),V(u1,a,h+rt),V(u1,b,h),V(u0,b,h)],null,k%2?shade(roof,.93):roof);
    G.face([V(u0,a,h),V(u0,a,h+rt),V(u0,b,h)],F.l,wall);G.face([V(u1,a,h),V(u1,b,h),V(u1,a,h+rt)],F.r,wall);}}
// a barrel roof over u0..u1 x v0..v1 at height h: the vault across u in four facets (peldaños, ESTETICA §3), along v
function barrelRoof(G,P,F,u0,u1,v0,v1,h,wall,roof){const K=4,rise=Math.min(4,(u1-u0)*.18),pts=[],V=(u,v,y)=>{const p=P(u,v);return [p[0],y,-p[1]];};
  for(let k=0;k<=K;k++){const t=k/K*Math.PI;pts.push([u0+(u1-u0)*(1-Math.cos(t))/2,h+rise*Math.sin(t)]);}
  for(let k=0;k<K;k++){const [ua,ya]=pts[k],[ub,yb]=pts[k+1];G.face([V(ua,v0,ya),V(ub,v0,yb),V(ub,v1,yb),V(ua,v1,ya)],null,k%2?shade(roof,.92):roof);}
  G.face(pts.map(([uu,yy])=>V(uu,v0,yy)),F.f,wall);G.face(pts.map(([uu,yy])=>V(uu,v1,yy)),F.b,wall);}
// A shop's front on the street (v0). One storey: the almacén of every barrio, a false front (a parapet 1.8 m over the
// roof, along the street and round the corner, cs -1 at u0, 1 at u1) carrying the sign (1.4 m: three art pixels at the
// card's zoom, ESTETICA §2), a roller door and a shop window.
// More storeys: a shopfront of dark glass with a sign band over it. Details 6 cm in front of the wall (ESTETICA §3).
function shopFront(Z,P,F,u0,u1,v0,dd,fl,h,wall,signs,r,cs){const sg=pick(r,signs),v=v0-.06;
  if(fl===1){const cap=shade(wall,1.05);Z.prism([P(u0,v0),P(u1,v0),P(u1,v0+.4),P(u0,v0+.4)],h,h+1.8,wall,cap);
    if(cs){const us=cs<0?u0:u1-.4;Z.prism([P(us,v0+.4),P(us+.4,v0+.4),P(us+.4,v0+dd),P(us,v0+dd)],h,h+1.8,wall,cap);}
    wq(Z,P,F.f,u0+.4,u1-.4,v,h+.2,h+1.6,sg);
    const dw=Math.min(3.2,(u1-u0)*.4);wq(Z,P,F.f,u0+.8,u0+.8+dw,v,.3,2.6,CP.door);
    if(u1-.8-(u0+1.4+dw)>1.2)wq(Z,P,F.f,u0+1.4+dw,u1-.8,v,.9,2.5,CP.glass);}
  else{wq(Z,P,F.f,u0+.6,u1-.6,v,.4,2.6,CP.glass);wq(Z,P,F.f,u0+.4,u1-.4,v,2.75,3.35,sg);}}
// A house's walls on the lot frame, v0..v1, from 4 m under the ground (as prism()) to y1: the front and the back in
// segments [ua, ub, colour] (the two halves of a pareada), the ends only where asked (l, r: the walls between the
// houses of a row are hidden, so they are not drawn). And its gable roof, the ridge along u: a front and a back slope
// per segment (the back a tone darker), the gable ends in the colours cl, cr where asked. Fewer faces than a gable()
// per house, which keeps the pareadas and rows within the vertex budget.
function lotWalls(G,P,F,v0,v1,y1,segs,l,r){
  for(const [ua,ub,c] of segs){wq(G,P,F.f,ua,ub,v0,-3.7,y1,c);wq(G,P,F.b,ua,ub,v1,-3.7,y1,c);}
  if(l)uq(G,P,F.l,segs[0][0],v0,v1,-3.7,y1,segs[0][2]);
  if(r){const s=segs[segs.length-1];uq(G,P,F.r,s[1],v0,v1,-3.7,y1,s[2]);}}
function uq(G,P,n,u,v0,v1,y0,y1,col){const a=P(u,v0),b=P(u,v1);G.face([[a[0],y0,-a[1]],[b[0],y0,-b[1]],[b[0],y1,-b[1]],[a[0],y1,-a[1]]],n,col);}
function lotGable(G,P,F,v0,v1,y1,rh,segs,cl,cr){const vm=(v0+v1)/2,t=y1+rh,V=(u,v,y)=>{const p=P(u,v);return [p[0],y,-p[1]];};
  for(const [ua,ub,c] of segs){G.face([V(ua,v0,y1),V(ub,v0,y1),V(ub,vm,t),V(ua,vm,t)],null,c);G.face([V(ub,v1,y1),V(ua,v1,y1),V(ua,vm,t),V(ub,vm,t)],null,shade(c,.86));}
  if(cl){const u=segs[0][0];G.face([V(u,v0,y1),V(u,v1,y1),V(u,vm,t)],F.l,cl);}
  if(cr){const u=segs[segs.length-1][1];G.face([V(u,v0,y1),V(u,v1,y1),V(u,vm,t)],F.r,cr);}}
// Lots along the streets. Each house stands on its lot: a slab 20 cm over the ground (Y, without procedural windows)
// in the colour of its yard, from the front garden past the side passage to the back, so that a block reads as built
// up to its back fences, as Talca's are, and not as houses on bare ground (docs/PROYECTOS-SIMILARES.md). In the centre
// a one-storey house is the colonial type: a front range on the street and a wing along one side of a patio. Elsewhere
// the barrio's recipe (barrios()) chooses the house: a población's gable houses of every width and colour, pareadas,
// rows, hipped condominium houses, social-housing slabs with stair towers around lawns and parking; on the corners and
// along the avenues near the centre, shops. Industrial blocks get sheds (gable, saw-tooth, barrel, flat) in paved yards
// with a front wall and some tanks. A tree in some yards and patios. What has no windows (sheds, tanks, parapets, signs,
// shopfronts, walls) goes on Z, a mesh of its own that casts shadows.
// The streets in the order cityGen lays their lots: by their distance from the Plaza de Armas (their nearest segment),
// then by index. Lots compete only with lots near them (lotFree), and each street has its own rng, so the city around
// the plaza out to any distance d depends only on the streets nearer than d plus the lots' reach: it can be generated
// first and the rest after it with the same result. Before October 2026 the order was the index, which has no
// relation to the place: the streets near the plaza depended, through chains of streets competing for corner lots, on
// a third of the city.
const CITY_ORDER=streets.map((s,si)=>{let d=1e18;for(let i=0;i<s.pts.length-1;i++){const a=s.pts[i],b=s.pts[i+1];d=Math.min(d,segDist2(0,0,a[0],a[1],b[0],b[1]));}return [Math.sqrt(d),si];})
  .sort((a,b)=>a[0]-b[0]||a[1]-b[1]).map(e=>e[1]);
// CITY_DIST[si]: that distance; CITY_REACH, how far a lot of cityGen can reach from its street's axis (half the widest
// carriageway, setback, depth and yard: ~105 m) and a margin: the lots at a point come from streets nearer than that
const CITY_DIST=new Float64Array(streets.length),CITY_REACH=130,CITY_POS=new Int32Array(streets.length);CITY_ORDER.forEach((si,p)=>CITY_POS[si]=p);
streets.forEach((s,si)=>{let d=1e18;for(let i=0;i<s.pts.length-1;i++){const a=s.pts[i],b=s.pts[i+1];d=Math.min(d,segDist2(0,0,a[0],a[1],b[0],b[1]));}CITY_DIST[si]=Math.sqrt(d);});
// Trees in the parks and the backyards: each block its own number, from the census alone, so that a block's trees
// depend only on what stands in and around it. The budget MAXT holds the most the parks can take (their count before
// the occupied points are skipped) plus the backyards, thinned all alike to what is left (YARD_K). Until October 2026
// the parks went first and the backyards got what the parks had left, so every block's trees depended on all the
// parks of the commune. The Alameda's rows come from alamedaPark().
const MAXT=36000,isPark=bi=>!blocks[bi].built||bi===PLAZA_BI;
const parkTrees=b=>Math.min(b.A<40000?b.A/150:b.A/900,1400);
let YARD_K=-1; // set on the first blockTrees(): PLAZA_BI and ALAM come later in the script
function blockTrees(bi,TR){const b=blocks[bi];if(isPark(bi)&&ALAM.has(bi))return;
  if(YARD_K<0){let np=0,ny=0;blocks.forEach((c,ci)=>{if(!isPark(ci))ny+=c.A/1100;else if(!ALAM.has(ci))np+=Math.ceil(parkTrees(c));});YARD_K=Math.max(0,Math.min(1,(MAXT-np)/ny));}
  const r=rng(bi*31+5);let n=isPark(bi)?parkTrees(b):b.A/1100*YARD_K,tries=n*3;
  while(n>0&&tries-->0){const x=b.bb[0]+r()*(b.bb[2]-b.bb[0]),y=b.bb[1]+r()*(b.bb[3]-b.bb[1]);
    if(!pip([x,y],b.r))continue;if(occAt(x,y))continue;if(nearStreet(x,y,1.2))continue;
    TR.push([x,y,0.8+r()*0.6,r()]);n--;}}
// cityGen(B, Y, Z, sts, bis): the lots of the streets sts (indices, a stretch of CITY_ORDER, in its order), then the
// trees of the blocks bis; boot calls it for the streets near the first view and again, in pieces, for the rest
function cityGen(B,Y,Z,sts,bis){
  const TR=[],PO=[]; // tree instances [x,y,s], poplars
  const cnt=k=>{CITY[k]=(CITY[k]||0)+1;};
  let nb=0;
  sts.forEach(si=>{const s=streets[si];
    if(s.c===0||s.c===7)return;
    B.k=Y.k=Z.k=3e7+CITY_POS[si]; // its run in the builders: the startup puts the stages back in CITY_ORDER (GB.grow)
    const hw=swOf(s)/2;const r=rng(si*9973+17),ave=s.c<=3,last=s.pts.length-2;
    for(let i=0;i<s.pts.length-1;i++){
      const a=s.pts[i],b=s.pts[i+1];const dx=b[0]-a[0],dy=b[1]-a[1];const L=Math.hypot(dx,dy);if(L<7)continue;
      const tx=dx/L,ty=dy/L;
      for(const side of [1,-1]){
        const nx=-ty*side,ny=tx*side;let u=1.5,run=0; // run: houses placed along this side (a villa's rhythm)
        let pend=null;const flush=()=>{if(pend){pend();pend=null;}}; // the open end of a row of houses (kind 'row')
        // (u along the street, v away from its axis) -> grid metres; the rectangle u0..u1 x v0..v1
        const P=(uu,vv)=>[a[0]+tx*uu+nx*vv,a[1]+ty*uu+ny*vv],Q=(u0,u1,v0,v1)=>[P(u0,v0),P(u1,v0),P(u1,v1),P(u0,v1)];
        const F={f:[-nx,0,ny],b:[nx,0,-ny],l:[-tx,0,ty],r:[tx,0,-ty]};
        while(u<L-5){
          const pr=P(u+3,hw+7);
          const bi=blockAt(pr[0],pr[1]);
          if(bi<0||!blocks[bi].built||blocks[bi].osm||NOLOTS.some(q=>inRing(pr[0],pr[1],q))){u+=5;continue;} // osm: its buildings come from OSM (edificiosBase)
          const R=recipeOf(bi),H=R.h;let st=styleFor(bi);
          if(st==='house'&&R.ind&&r()<R.ind)st='ind'; // the large, nearly empty blocks of the outskirts: sheds among the houses
          let w,d,sb,gap,fl,kind,yd=0,front=false,shop=false;
          const dc=Math.hypot(pr[0],pr[1]);
          if(st==='core'){w=7+r()*8;d=13+r()*12;sb=1.2;gap=0;const q=r();fl=q<.52?1:q<.85?2:q<.975?3+Math.floor(r()*2):(dc<1000?5+Math.floor(r()*6):3);kind=fl>=3||r()<.55?'flat':'gable';
            if(kind==='gable')d=8+r()*5;yd=45;shop=kind==='flat'&&s.c<=4&&dc<1100&&r()<.6;}
          else if(st==='core2'){w=10+r()*10;d=14+r()*10;sb=2;gap=r()*3;fl=1+Math.floor(r()*2);kind='flat';yd=20;shop=r()<.4;}
          else if(st==='ind'){w=18+r()*26;d=18+r()*18;sb=5;gap=4+r()*6;fl=0;kind='shed';yd=16;}
          else if(st==='apt'){const A=R.a;if(A.perp){w=9.5;d=26+r()*8;sb=4;gap=14;}else{w=30;d=10;sb=6;gap=10;front=true;}fl=A.fl;kind='slab';yd=14;}
          else{const t=H.t;front=true;yd=H.yd;
            if(t==='antiguo'){w=8+r()*7;d=8+r()*5;sb=.8;gap=r()<.7?0:1+r()*2;fl=r()<.88?1:2;kind='gable';front=false;}
            else if(t==='pob'){w=7+r()*3.5;if(r()<.15)w*=1.6;d=7+r()*4;sb=2+r()*2;gap=1+r()*2.5;fl=r()<.85?1:2;kind=r()<.6?'gable':'gableX';}
            else if(t==='pareada'){w=2*H.wu;d=H.d;sb=H.sb;gap=H.gp;fl=H.fl;kind='pair';}
            else if(t==='fila'){w=H.wu;d=H.d;sb=H.sb;gap=(run+1)%H.n?0:3;fl=2;kind='row';}
            else{w=H.wu;d=H.d;sb=H.sb;gap=H.gp;fl=2;kind='hip';}
            // shops: most of the front along an avenue near the centre (some of two or three storeys), and corners
            const corner=(i===0&&u<12)||(i===last&&u+w>L-9);
            if(ave&&dc<1500&&r()<.55){kind='flat';shop=true;w=7+r()*6;d=12+r()*8;sb=1.2;gap=0;fl=r()<.45?2+(r()<.3?1:0):1;front=false;}
            else if(corner&&r()<H.sp){kind='flat';shop=true;w=Math.max(7,Math.min(w,11));d=10+r()*5;sb=Math.min(sb,1.5);fl=1;front=false;}}
          if(u+w>L-1.5){w=L-1.5-u;if(w<6)break;if(kind==='pair'&&w<1.6*H.wu)kind='gable';}
          const o0=hw+sb,wl=Math.min(w+(yd?gap:0),L-1.5-u);
          // where the block ends straight behind the lot: the yards of both sides reach its middle and meet there
          const back=()=>{let v=o0;for(;v<o0+120;v+=3){const p=P(u+w/2,v+3);if(!blockIs(p[0],p[1],bi))break;}return (hw+v)/2;};
          // a rectangle free of other lots, of what occupied the raster before, of streets, and inside block bi
          const fits=(u0,u1,v0,v1)=>{const q=Q(u0,u1,v0,v1);if(!q.every(p=>inTerrain(p[0],p[1]))||!lotFree(q))return false;
            const nu=Math.max(1,Math.ceil((u1-u0)/2.5)),nv=Math.max(1,Math.ceil((v1-v0)/2.5));
            for(let i=0;i<=nu;i++)for(let j=0;j<=nv;j++){const p=P(u0+(u1-u0)*i/nu,v0+(v1-v0)*j/nv);if(occAt(p[0],p[1])===1)return false;
              if((i===0||j===0||i===nu||j===nv)&&nearStreet(p[0],p[1],0.6))return false;}
            for(const p of [P(u0,v1),P(u1,v1),P((u0+u1)/2,(v0+v1)/2)])if(!blockIs(p[0],p[1],bi))return false;
            return true;};
          let ok=false;
          for(const dd of [d,d*.65]){
            const q=Q(u,u+w,o0,o0+dd);
            if(!fits(u,u+w,o0,o0+dd))continue;
            // the lot: the deepest yard that fits, with the front garden if it fits too
            let lot=null,yv=0;
            const yt=yd?Math.max(0,Math.min(yd,back()-o0-dd)):0;
            if(yt||front)for(const y of [yt,yt*.75,yt*.5,yt*.25,0]){
              for(const f of front?[hw+0.9,o0]:[o0]){if(!y&&f===o0&&wl<=w)continue;if(fits(u,u+wl,f,o0+dd+y)){lot=Q(u,u+wl,f,o0+dd+y);yv=y;break;}}
              if(lot)break;}
            lotAdd(lot||q);ok=true;nb++;B.dy=Z.dy=groundMin(q);const qc=[(q[0][0]+q[2][0])/2,(q[0][1]+q[2][1])/2];
            // emit
            const wall=st.startsWith('core')?pick(r,PAL.wallsCore):st==='house'?pick(r,shop?CP.wallsPob:H.wl):st==='apt'?pick(r,R.a.wl):pick(r,PAL.walls);
            let roof=null;cnt(shop?'shop':kind);if(kind!=='row')flush();
            if(kind==='gable'||kind==='gableX'){const h=fl*3.0+0.3;roof=tone(st==='core'?fam(r,MIX.core):fam(r,H.mix||MIX.pob),r()<.5?0:1);
              if(kind==='gable')B.gable(q,0.3,h,Math.min(w,dd)*0.22,wall,roof);else B.gable([q[1],q[2],q[3],q[0]],0.3,h,Math.min(w,dd)*0.24,wall,roof);}
            else if(kind==='pair'){ // two mirrored houses under one roof; each half its own colour, now and then its own roof
              const h=fl*2.9+.3,hu=w/2,wb=r()<.25?pick(r,CP.wallsPob):pick(r,H.wl);
              roof=tone(H.rf,run);const rb=r()<.15?tone(fam(r,MIX.pob),0):roof;
              lotWalls(B,P,F,o0,o0+dd,h,[[u,u+hu,wall],[u+hu,u+w,wb]],true,true);
              if(H.rk==='hip')B.hipRoof(q,h,Math.min(w,dd)*.3,roof);
              else lotGable(B,P,F,o0,o0+dd,h,dd*.24,rb===roof?[[u,u+w,roof]]:[[u,u+hu,roof],[u+hu,u+w,rb]],wall,wb);run++;}
            else if(kind==='row'){ // a row of two-storey houses: the walls between them are not drawn, its open end waits for the next
              const h=fl*2.8+.3,rh=dd*.22,wc=r()<.15?pick(r,CP.wallsPob):H.wl[run%H.wl.length],join=!!pend&&Math.abs(pend.u1-u)<.01&&Math.abs(pend.dy-B.dy)<.05&&pend.dd===dd;
              if(join)pend=null;else flush();
              roof=tone(H.rf,run);lotWalls(B,P,F,o0,o0+dd,h,[[u,u+w,wc]],!join,false);lotGable(B,P,F,o0,o0+dd,h,rh,[[u,u+w,roof]],join?null:wc,null);
              const u1=u+w,dy=B.dy,v1=o0+dd,vm=o0+dd/2;
              pend=()=>{const k=B.dy;B.dy=dy;uq(B,P,F.r,u1,o0,v1,-3.7,h,wc);const a=P(u1,o0),b=P(u1,v1),m=P(u1,vm);B.face([[a[0],h,-a[1]],[b[0],h,-b[1]],[m[0],h+rh,-m[1]]],F.r,wc);B.dy=k;};
              pend.u1=u1;pend.dy=dy;pend.dd=dd;run++;}
            else if(kind==='hip'){const h=fl*2.8+.3;roof=tone(H.rf,run);B.prism(q,.3,h,wall,null,false);B.hipRoof(q,h,Math.min(w,dd)*.3,roof);run++;}
            else if(kind==='shed'){const h=6+r()*4,sw=pick(r,CP.wallsShed),sr=pick(r,CP.shedRoof),k=r();
              if(k<.4){const lg=dd>w;Z.gable(lg?[q[1],q[2],q[3],q[0]]:q,.3,h,(lg?w:dd)*.12,sw,sr);}
              else{Z.prism(q,.3,h,sw,sr,k>=.8);if(k<.6)sawRoof(Z,P,F,u,u+w,o0,o0+dd,h,sw,sr);else if(k<.8)barrelRoof(Z,P,F,u,u+w,o0,o0+dd,h,sw,sr);}}
            else if(kind==='slab'){ // a social-housing block, three or four storeys, with its stair towers
              const A=R.a,h=fl*2.8+.5,fc=tone('light',0),tw=shade(wall,.86);roof=A.gab?tone(A.rf,run):fc;run++;
              if(A.perp){if(A.gab)B.gable([q[1],q[2],q[3],q[0]],.3,h,w*.16,wall,roof);else B.prism(q,.3,h,wall,fc);
                for(const t of dd>24?[.27,.73]:[.5]){const vc=o0+dd*t;B.prism(Q(u+w,u+w+2.2,vc-1.6,vc+1.6),.3,h+(A.gab?.4:1.2),tw,fc);}}
              else{if(A.gab)B.gable(q,.3,h,dd*.16,wall,roof);else B.prism(q,.3,h,wall,fc);
                for(const t of w>24?[.27,.73]:[.5]){const uc=u+w*t;B.prism(Q(uc-1.6,uc+1.6,o0-2.2,o0),.3,h+(A.gab?.4:1.2),tw,fc);}}}
            else{const h=fl*3.1+0.6;B.prism(q,0.3,h,wall,r()<.3?tone('light',r()<.5?0:1):pick(r,PAL.flat));if(fl>=5&&r()<.6)B.prism([q[0],q[1],q[2],q[3]].map(p=>[p[0]+(qc[0]-p[0])*.4,p[1]+(qc[1]-p[1])*.4]),h,h+2.4,shade(wall,.9),pick(r,PAL.flat));
              if(shop)shopFront(Z,P,F,u,u+w,o0,dd,fl,h,wall,st==='core'?CP.signCore:CP.sign,r,(i===0&&u<12)?-1:(i===last&&u+w>L-9)?1:0);}
            if(lot){const col=st==='core'?pick(r,PAL.patio):st==='core2'?pick(r,PAL.backlot):st==='ind'?pick(r,CP.paved):st==='apt'?pick(r,CP.lawn):pick(r,H.yc);
              Y.dy=groundMin(lot);const top=groundMax(lot)-Y.dy+0.2;Y.prism(lot,0,top,shade(col,.82),col);
              const v0=o0+dd,v1=o0+dd+yv;let tu0=u+1,tu1=u+wl-1;
              if(st==='core'&&kind==='gable'&&fl<=2&&w>=9&&yv>=8){ // the wing along one side of the patio
                const ww=Math.min(4.5,w*.4),left=r()<.5,us=left?u:u+w-ww,wg=[P(us,v0),P(us,v1-1.5),P(us+ww,v1-1.5),P(us+ww,v0)];
                B.dy=groundMin(wg);B.gable(wg,0.3,3.3,ww*.3,wall,roof);if(left)tu0=us+ww+1;else tu1=us-1;
                if(yv>=16&&r()<.45){const bq=[P(u+w,v1-.5),P(u,v1-.5),P(u,v1-6),P(u+w,v1-6)];B.dy=groundMin(bq);B.gable(bq,0.3,3.3,1.6,wall,roof);}} // and a back range: a U
              else if(st.startsWith('core')&&yv>=6&&r()<.75){ // the centre is built to the back: a storeroom, a workshop, a back block
                const e=v0+yv*(.45+r()*.5),rq=Q(u+.3,u+wl-.3,v0,e);B.dy=groundMin(rq);B.prism(rq,0.3,3.2+(r()<.3?3:0),shade(wall,.95),r()<.5?pick(r,PAL.flat):tone(fam(r,MIX.core),0));tu0=tu1;}
              else if(st==='house'&&yv>=7&&r()<H.sh){ // a mediagua at the back of the yard
                const sq=Q(u+.4,u+Math.max(3,w*(.55+r()*.4)),v1-3.4,v1-.5);B.dy=groundMin(sq);B.prism(sq,0.3,2.5,pick(r,CP.wood),tone(fam(r,MIX.pob),r()<.5?0:1));}
              else if(kind==='shed'){ // the yard's front wall, and tanks in some yards
                if(wl-w>3)Z.prism(Q(u+w+.3,u+wl-.3,o0,o0+.4),.3,2.1,CP.fence,shade(CP.fence,1.05));
                const rad=1.6+r()*1.4;if(yv>=2*rad+3&&r()<.15){const vc=v0+1.5+rad;
                  for(let k=0,uc=u+1+rad;k<2&&uc+rad<u+wl-1;k++,uc+=2*rad+1.2){const c=P(uc,vc),tq=ngon(c[0],c[1],rad,8),th=6+r()*6,tc=pick(r,CP.tank);
                    Z.dy=groundMin(tq);Z.prism(tq,.3,th,tc,tc);pyramid(Z,tq,th,rad*.35,shade(tc,.95));cnt('tank');}
                  tu0=tu1;}}
              else if(kind==='slab'&&R.a.perp&&wl-w>6){Y.quadXY(Q(u+w+2.6,u+wl-.8,o0+.5,o0+Math.min(dd,16)),top+.05,CP.parking);} // parking between the blocks
              if(yv>=6&&tu1-tu0>1&&r()<(st==='core'?.3:st==='house'?H.tr:st==='ind'?.1:.4)){const t=P(tu0+r()*(tu1-tu0),v0+2+r()*Math.max(0,yv-6));TR.push([t[0],t[1],0.7+r()*0.4,r()]);}}
            break;
          }
          u+=ok?w+gap:w*.5+1;
        }
        flush();
      }
    }
  });
  B.dy=0;Z.dy=0;
  for(const bi of bis)blockTrees(bi,TR);
  return {TR,PO,nb};
}

