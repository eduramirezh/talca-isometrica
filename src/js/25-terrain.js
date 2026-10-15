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
// the diorama ends where the terrain grid does: nothing is laid outside it
const EX1=EX0+(ENX-1)*ES,EY1=EY0+(ENY-1)*ES;
const inTerrain=(x,y)=>x>=EX0&&x<=EX1&&y>=EY0&&y<=EY1;
const node=(i,j)=>Math.min(ENY-1,Math.max(0,j))*ENX+Math.min(ENX-1,Math.max(0,i));
const ENRM=new Float32Array(EN_*3);
function terrainNormals(){for(let j=0;j<ENY;j++)for(let i=0;i<ENX;i++){
  const hx=(EH[node(i+1,j)]-EH[node(i-1,j)])/(2*ES),hy=(EH[node(i,j+1)]-EH[node(i,j-1)])/(2*ES);const L=Math.hypot(hx,1,hy),k=(j*ENX+i)*3;
  ENRM[k]=-hx/L;ENRM[k+1]=1/L;ENRM[k+2]=hy/L;}} // surface Y=h(x,-Z): normal (-hx, 1, hy)
const _n=[0,0,0];
function EN(x,y){let u=(x-EX0)/ES,v=(y-EY0)/ES;u=u<0?0:u>ENX-1.0001?ENX-1.0001:u;v=v<0?0:v>ENY-1.0001?ENY-1.0001:v;
  const i=Math.floor(u),j=Math.floor(v);u-=i;v-=j;const k=(j*ENX+i)*3,w=[(1-u)*(1-v),u*(1-v),(1-u)*v,u*v],o=[0,3,ENX*3,ENX*3+3];
  let a=0,b=0,c=0;for(let q=0;q<4;q++){a+=ENRM[k+o[q]]*w[q];b+=ENRM[k+o[q]+1]*w[q];c+=ENRM[k+o[q]+2]*w[q];}
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

