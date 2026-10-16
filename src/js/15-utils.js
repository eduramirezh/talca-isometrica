/* =============== utils =============== */
function rng(seed){let a=seed>>>0;return()=>{a|=0;a=a+0x6D2B79F5|0;let t=Math.imul(a^a>>>15,1|a);t=t+Math.imul(t^t>>>7,61|t)^t;return((t^t>>>14)>>>0)/4294967296;};}
const pick=(r,arr)=>arr[Math.floor(r()*arr.length)];
const hex=h=>[parseInt(h.slice(1,3),16),parseInt(h.slice(3,5),16),parseInt(h.slice(5,7),16)];
const shade=(c,f)=>[Math.min(255,c[0]*f),Math.min(255,c[1]*f),Math.min(255,c[2]*f)];
function pipXY(x,y,r){let ins=false;for(let i=0,j=r.length-1;i<r.length;j=i++){const xi=r[i][0],yi=r[i][1],xj=r[j][0],yj=r[j][1];if(((yi>y)!==(yj>y))&&(x<(xj-xi)*(y-yi)/(yj-yi)+xi))ins=!ins;}return ins;}
const pip=(pt,r)=>pipXY(pt[0],pt[1],r);
// inRing(x, y, r): pipXY with the ring's box first, kept in RING_BB (for rings that do not change: the rivers, NOLOTS).
// A point more than 1 m outside the box is outside for pipXY too: no edge straddles its y, or every one it could cross
// lies to its right, an even number of them. The margin covers the rounding of the crossing's x.
const RING_BB=new WeakMap(),ringBox=r=>{let b=RING_BB.get(r);if(!b){b=[1e9,1e9,-1e9,-1e9];for(const p of r){b[0]=Math.min(b[0],p[0]);b[1]=Math.min(b[1],p[1]);b[2]=Math.max(b[2],p[0]);b[3]=Math.max(b[3],p[1]);}RING_BB.set(r,b);}return b;};
const inRing=(x,y,r)=>{const b=ringBox(r);return x>b[0]-1&&y>b[1]-1&&x<b[2]+1&&y<b[3]+1&&pipXY(x,y,r);};
// pipRow(r, y, xs): into xs, sorted, the x where the edges of ring r cross the line at y, computed exactly as pipXY()
// does; (x, y) is inside r, as pipXY() says, when an odd number of them is greater than x. For a row of points
// (a raster, the relief's nodes) instead of a pip per point: same answers, one pass over the ring per row
function pipRow(r,y,xs){xs.length=0;for(let i=0,j=r.length-1;i<r.length;j=i++){const xi=r[i][0],yi=r[i][1],xj=r[j][0],yj=r[j][1];if((yi>y)!==(yj>y))xs.push((xj-xi)*(y-yi)/(yj-yi)+xi);}
  return xs.sort((a,b)=>a-b);}
function segDist2(px,py,ax,ay,bx,by){const dx=bx-ax,dy=by-ay;const L=dx*dx+dy*dy;let t=L?((px-ax)*dx+(py-ay)*dy)/L:0;t=t<0?0:t>1?1:t;const x=ax+t*dx-px,y=ay+t*dy-py;return x*x+y*y;}

