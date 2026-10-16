/* =============== terrain =============== */
// DATA.elev: nodes every ES m, real heights in dm relative to the plaza (pipeline/elevation.py).
// ER keeps the real relief (altitude readout). EH is the model's relief: ~3× on the plain, less on the hills
// (relief()), with flat pads under the landmarks. The whole scene stands on EH through E(x,y).
const EV=DATA.elev,[EX0,EY0]=EV.o,ES=EV.s,[ENX,ENY]=EV.n,EN_=ENX*ENY;
const ER=new Float32Array(EN_),EH=new Float32Array(EN_);
const RELIEF_A=3,RELIEF_K=50; // slope gain near the plaza's level, and the height (m) where it has halved
const relief=d=>Math.sign(d)*RELIEF_A*RELIEF_K*Math.log1p(Math.abs(d)/RELIEF_K);
{let v=0;for(let i=0;i<EN_;i++){v+=EV.h[i];ER[i]=v/10;EH[i]=relief(v/10);}}
// value inside the terrain triangle holding (x,y); each cell is split along its (i+1,j)-(i,j+1) diagonal,
// the same way terrainMesh() triangulates it, so E() is exactly the rendered surface
function sampleTri(A,x,y){let u=(x-EX0)/ES,v=(y-EY0)/ES;u=u<0?0:u>ENX-1.0001?ENX-1.0001:u;v=v<0?0:v>ENY-1.0001?ENY-1.0001:v;
  const i=Math.floor(u),j=Math.floor(v);u-=i;v-=j;const k=j*ENX+i;
  return u+v<=1?A[k]+u*(A[k+1]-A[k])+v*(A[k+ENX]-A[k]):A[k+ENX+1]+(1-u)*(A[k+ENX]-A[k+ENX+1])+(1-v)*(A[k+1]-A[k+ENX+1]);}
const E=(x,y)=>sampleTri(EH,x,y);
// The diorama is the commune of Talca, cut along its limit (DATA.limit: OSM's boundary, a counter-clockwise ring;
// pipeline/common.py). CM marks every terrain cell: 0 outside the limit, 1 inside, 2 crossed by it. A crossed cell
// keeps the part of the commune inside it (LIMP[cell]: polygons; LIMT[cell]: the same as counter-clockwise
// triangles), which drape() and terrainMesh() cut against. inTerrain(x,y): is the point on the diorama (in the commune).
// The ring is shifted by a few millimetres so that none of its integer vertices lies on a grid line.
const EX1=EX0+(ENX-1)*ES,EY1=EY0+(ENY-1)*ES,ECW=ENX-1,ECH=ENY-1;
const LIM=dec(DATA.limit).map(p=>[p[0]+0.0123,p[1]+0.0071]),CM=new Uint8Array(ECW*ECH),LIMP=new Map(),LIMT=new Map();
const cellOf=(x,y)=>{const i=Math.floor((x-EX0)/ES),j=Math.floor((y-EY0)/ES);return i<0||j<0||i>=ECW||j>=ECH?-1:j*ECW+i;};
// t (0..1) along a→b where it crosses the terrain's grid lines and, with diag, the cells' diagonals too
function gridCuts(a,b,diag){const ts=[],f=[p=>(p[0]-EX0)/ES,p=>(p[1]-EY0)/ES];if(diag)f.push(p=>(p[0]-EX0+p[1]-EY0)/ES);
  for(const g of f){const u=g(a),v=g(b);for(let k=Math.floor(Math.min(u,v))+1;k<Math.max(u,v);k++)ts.push((k-u)/(v-u));}
  return ts.sort((p,q)=>p-q);}
// the commune inside the rectangle [x0,x1]×[y0,y1]: the runs of the ring inside it, closed along the rectangle's
// border counter-clockwise from each exit to the next entry (the ring is counter-clockwise, so the commune is on its left)
function rectClip(x0,y0,x1,y1){
  const ins=p=>p[0]>x0&&p[0]<x1&&p[1]>y0&&p[1]<y1,n=LIM.length;let s0=0;while(ins(LIM[s0]))s0++;
  const per=p=>Math.abs(p[1]-y0)<1e-6?(p[0]-x0)/(x1-x0):Math.abs(p[0]-x1)<1e-6?1+(p[1]-y0)/(y1-y0):Math.abs(p[1]-y1)<1e-6?2+(x1-p[0])/(x1-x0):3+(y1-p[1])/(y1-y0);
  const arcs=[];let cur=null;
  for(let k=0;k<n;k++){const a=LIM[(s0+k)%n],b=LIM[(s0+k+1)%n],ts=[];
    for(const [ax,v,lo,hi] of [[0,x0,y0,y1],[0,x1,y0,y1],[1,y0,x0,x1],[1,y1,x0,x1]]){if((a[ax]-v)*(b[ax]-v)>=0)continue;
      const t=(v-a[ax])/(b[ax]-a[ax]),o=a[1-ax]+(b[1-ax]-a[1-ax])*t;if(o>lo&&o<hi)ts.push(t);}
    ts.sort((p,q)=>p-q);
    for(const t of ts){const q=[a[0]+(b[0]-a[0])*t,a[1]+(b[1]-a[1])*t];
      if(Math.abs(q[0]-x0)<1e-9)q[0]=x0;else if(Math.abs(q[0]-x1)<1e-9)q[0]=x1;if(Math.abs(q[1]-y0)<1e-9)q[1]=y0;else if(Math.abs(q[1]-y1)<1e-9)q[1]=y1;
      if(cur){cur.push(q);arcs.push(cur);cur=null;}else cur=[q];}
    if(cur&&ins(b))cur.push(b);}
  const C=[[x0,y0],[x1,y0],[x1,y1],[x0,y1]],out=[],used=new Set();
  for(let a0=0;a0<arcs.length;a0++){if(used.has(a0))continue;const poly=[];let a=a0;
    for(let guard=0;guard<=arcs.length;guard++){used.add(a);poly.push(...arcs[a]);const se=per(arcs[a][arcs[a].length-1]);
      let nb=-1,bd=9;for(let m=0;m<arcs.length;m++){const d=((per(arcs[m][0])-se)%4+4)%4;if(d>1e-12&&d<bd){bd=d;nb=m;}}
      for(let c=Math.floor(se)+1;c<se+bd;c++)poly.push(C[c%4]); // the corners passed on the way
      a=nb;if(a===a0||a<0)break;}
    if(poly.length>2)out.push(poly);}
  return out;}
{ // cells crossed by the limit: those between successive grid-line crossings of each edge
  for(let k=0;k<LIM.length;k++){const a=LIM[k],b=LIM[(k+1)%LIM.length],ts=[0,...gridCuts(a,b,false),1];
    for(let m=0;m<ts.length-1;m++){const t=(ts[m]+ts[m+1])/2,c=cellOf(a[0]+(b[0]-a[0])*t,a[1]+(b[1]-a[1])*t);if(c>=0)CM[c]=2;}}
  // inside: a scanline through each row of cell centres
  for(let j=0;j<ECH;j++){const y=EY0+(j+.5)*ES,xs=[];
    for(let k=0;k<LIM.length;k++){const a=LIM[k],b=LIM[(k+1)%LIM.length];if((a[1]>y)!==(b[1]>y))xs.push(a[0]+(y-a[1])*(b[0]-a[0])/(b[1]-a[1]));}
    xs.sort((p,q)=>p-q);
    for(let m=0;m+1<xs.length;m+=2)for(let i=Math.max(0,Math.ceil((xs[m]-EX0)/ES-.5));i<=Math.min(ECW-1,Math.floor((xs[m+1]-EX0)/ES-.5));i++)if(!CM[j*ECW+i])CM[j*ECW+i]=1;}
  for(let c=0;c<CM.length;c++){if(CM[c]!==2)continue;const i=c%ECW,j=(c-i)/ECW,x0=EX0+i*ES,y0=EY0+j*ES;
    const P=rectClip(x0,y0,x0+ES,y0+ES),tr=[];
    for(const q of P){let t;try{t=T.ShapeUtils.triangulateShape(q.map(p=>new T.Vector2(p[0],p[1])),[]);}catch(e){continue;}
      for(const [u,v,w] of t){const A=q[u],B=q[v],D=q[w];tr.push((B[0]-A[0])*(D[1]-A[1])-(B[1]-A[1])*(D[0]-A[0])>0?[A,B,D]:[A,D,B]);}}
    if(!tr.length)CM[c]=0;else{LIMP.set(c,P);LIMT.set(c,tr);}}
}
const inTerrain=(x,y)=>{const c=cellOf(x,y);if(c<0)return false;const m=CM[c];return m===1||(m===2&&LIMP.get(c).some(q=>pip([x,y],q)));};
// polygon q (any orientation) clipped to the convex counter-clockwise polygon t (Sutherland–Hodgman); q keeps its orientation
function clipTo(q,t){let out=q;
  for(let i=0;i<t.length&&out.length>2;i++){const a=t[i],b=t[(i+1)%t.length],inp=out;out=[];
    const side=p=>(b[0]-a[0])*(p[1]-a[1])-(b[1]-a[1])*(p[0]-a[0]);
    for(let k=0;k<inp.length;k++){const p=inp[k],r=inp[(k+1)%inp.length],sp=side(p),sr=side(r);if(sp>=0)out.push(p);
      if((sp>=0)!==(sr>=0)){const u=sp/(sp-sr);out.push([p[0]+(r[0]-p[0])*u,p[1]+(r[1]-p[1])*u]);}}}
  return out;}
const node=(i,j)=>Math.min(ENY-1,Math.max(0,j))*ENX+Math.min(ENX-1,Math.max(0,i));
const ENRM=new Float32Array(EN_*3);
function terrainNormals(){for(let j=0;j<ENY;j++)for(let i=0;i<ENX;i++){
  const hx=(EH[node(i+1,j)]-EH[node(i-1,j)])/(2*ES),hy=(EH[node(i,j+1)]-EH[node(i,j-1)])/(2*ES);const L=Math.hypot(hx,1,hy),k=(j*ENX+i)*3;
  ENRM[k]=-hx/L;ENRM[k+1]=1/L;ENRM[k+2]=hy/L;}} // surface Y=h(x,-Z): normal (-hx, 1, hy)
const _n=[0,0,0];
function EN(x,y){let u=(x-EX0)/ES,v=(y-EY0)/ES;u=u<0?0:u>ENX-1.0001?ENX-1.0001:u;v=v<0?0:v>ENY-1.0001?ENY-1.0001:v;
  const i=Math.floor(u),j=Math.floor(v);u-=i;v-=j;const k=(j*ENX+i)*3,k2=k+ENX*3,w0=(1-u)*(1-v),w1=u*(1-v),w2=(1-u)*v,w3=u*v; // the 4 nodes, in this order (same sums)
  const a=ENRM[k]*w0+ENRM[k+3]*w1+ENRM[k2]*w2+ENRM[k2+3]*w3,b=ENRM[k+1]*w0+ENRM[k+4]*w1+ENRM[k2+1]*w2+ENRM[k2+4]*w3,c=ENRM[k+2]*w0+ENRM[k+5]*w1+ENRM[k2+2]*w2+ENRM[k2+5]*w3;
  const L=Math.hypot(a,b,c);_n[0]=a/L;_n[1]=b/L;_n[2]=c/L;return _n;}
// land cover: real slope above ~6 % is scrub and wood, not farmland (the hills west of the Río Claro, the river scarps)
const EW=new Float32Array(EN_);
{const s=new Float32Array(EN_);for(let j=0;j<ENY;j++)for(let i=0;i<ENX;i++)s[j*ENX+i]=Math.hypot(ER[node(i+1,j)]-ER[node(i-1,j)],ER[node(i,j+1)]-ER[node(i,j-1)])/(2*ES);
  for(let j=0;j<ENY;j++)for(let i=0;i<ENX;i++){let m=0;for(let dj=-1;dj<=1;dj++)for(let di=-1;di<=1;di++)m+=s[node(i+di,j+dj)];m/=9;
    const t=Math.max(0,Math.min(1,(m-0.04)/0.07));EW[j*ENX+i]=t*t*(3-2*t);}}
const wildAt=(x,y)=>sampleTri(EW,x,y);
// landmark pads: the ground under a landmark is levelled to its mean height (applied by applyPads() before anything
// is laid on the terrain). Every node of a cell the footprint touches is set, so the footprint is exactly flat.
const PADS=[];
function padAt(x0,y0,x1,y1){let h=0,n=0;for(let a=0;a<=4;a++)for(let b=0;b<=4;b++){h+=E(x0+(x1-x0)*a/4,y0+(y1-y0)*b/4);n++;}h/=n;PADS.push([x0,y0,x1,y1,h]);return h;}
function applyPads(){for(const [x0,y0,x1,y1,h] of PADS)
  for(let j=Math.max(0,Math.ceil((y0-ES-EY0)/ES));j<=Math.min(ENY-1,Math.floor((y1+ES-EY0)/ES));j++)
    for(let i=Math.max(0,Math.ceil((x0-ES-EX0)/ES));i<=Math.min(ENX-1,Math.floor((x1+ES-EX0)/ES));i++)EH[j*ENX+i]=h;}
const groundMin=q=>Math.min(...q.map(p=>E(p[0],p[1])));
const groundMax=q=>Math.max(...q.map(p=>E(p[0],p[1])));

