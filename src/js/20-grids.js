/* spatial grids */
const BG=100, bgW=Math.ceil((XMAX-XMIN)/BG), bgH=Math.ceil((YMAX-YMIN)/BG);
const bgrid=Array.from({length:bgW*bgH},()=>[]);
blocks.forEach((b,i)=>{for(let gx=Math.max(0,Math.floor((b.bb[0]-XMIN)/BG));gx<=Math.min(bgW-1,Math.floor((b.bb[2]-XMIN)/BG));gx++)for(let gy=Math.max(0,Math.floor((b.bb[1]-YMIN)/BG));gy<=Math.min(bgH-1,Math.floor((b.bb[3]-YMIN)/BG));gy++)bgrid[gy*bgW+gx].push(i);});
// the urban area: the 100 m cells within one cell of a built block's box (no street lamps on the country roads)
const URB=new Uint8Array(bgW*bgH);
blocks.forEach(b=>{if(!b.built)return;for(let gx=Math.max(0,Math.floor((b.bb[0]-XMIN)/BG)-1);gx<=Math.min(bgW-1,Math.floor((b.bb[2]-XMIN)/BG)+1);gx++)for(let gy=Math.max(0,Math.floor((b.bb[1]-YMIN)/BG)-1);gy<=Math.min(bgH-1,Math.floor((b.bb[3]-YMIN)/BG)+1);gy++)URB[gy*bgW+gx]=1;});
const urbanAt=(x,y)=>{const gx=Math.floor((x-XMIN)/BG),gy=Math.floor((y-YMIN)/BG);return gx>=0&&gy>=0&&gx<bgW&&gy<bgH&&URB[gy*bgW+gx]===1;};
// inBlock(x, y, bi): pipXY(x, y, blocks[bi].r), with a raster of the block's box once it has been asked BK_N times (the
// city asks the same block hundreds of times: back() walks 3 m at a time up to 120 m into it, fits() tests three points).
// A cell is 0 outside, 1 inside, or 2 where an edge of the ring passes within BK_E of it: only those go to pipXY. A cell
// no edge reaches lies all inside or all outside the ring, and its centre (pipRow, the same crossings as pipXY) says
// which: the same answers as pipXY, point by point.
const BK_N=16,BK_E=0.01,BKR=new Array(blocks.length).fill(null),BKQ=new Uint16Array(blocks.length),BK_XS=[];
function bkRaster(bi){const r=blocks[bi].r,bb=blocks[bi].bb,w=bb[2]-bb[0],h=bb[3]-bb[1],c=Math.max(3,Math.sqrt(w*h/4096)),
    nx=Math.max(1,Math.ceil(w/c)),ny=Math.max(1,Math.ceil(h/c)),x0=bb[0],y0=bb[1],a=new Uint8Array(nx*ny);
  for(let i=0,j=r.length-1;i<r.length;j=i++){const px=r[j][0],py=r[j][1],dx=r[i][0]-px,dy=r[i][1]-py;
    const j0=Math.max(0,Math.floor((Math.min(py,py+dy)-BK_E-y0)/c)),j1=Math.min(ny-1,Math.floor((Math.max(py,py+dy)+BK_E-y0)/c));
    for(let gy=j0;gy<=j1;gy++){let xa=px,xb=px+dx; // the part of the edge within the row (grown by BK_E)
      if(dy!==0){const ya=y0+gy*c-BK_E,yb=y0+(gy+1)*c+BK_E;let t0=(ya-py)/dy,t1=(yb-py)/dy;if(t0>t1){const t=t0;t0=t1;t1=t;}t0=Math.max(0,t0);t1=Math.min(1,t1);xa=px+dx*t0;xb=px+dx*t1;}
      const i0=Math.max(0,Math.floor((Math.min(xa,xb)-BK_E-x0)/c)),i1=Math.min(nx-1,Math.floor((Math.max(xa,xb)+BK_E-x0)/c));
      for(let gx=i0;gx<=i1;gx++)a[gy*nx+gx]=2;}}
  for(let gy=0;gy<ny;gy++){const xs=pipRow(r,y0+(gy+.5)*c,BK_XS);let k=0;
    for(let gx=0;gx<nx;gx++){const x=x0+(gx+.5)*c;while(k<xs.length&&xs[k]<=x)k++;const n=gy*nx+gx;if(a[n]!==2&&(xs.length-k)&1)a[n]=1;}}
  return {x0,y0,c,nx,ny,a};}
function inBlock(x,y,bi){let R=BKR[bi];if(!R){if(++BKQ[bi]<BK_N)return pipXY(x,y,blocks[bi].r);R=BKR[bi]=bkRaster(bi);}
  const gx=Math.floor((x-R.x0)/R.c),gy=Math.floor((y-R.y0)/R.c);if(gx<0||gy<0||gx>=R.nx||gy>=R.ny)return pipXY(x,y,blocks[bi].r);
  const v=R.a[gy*R.nx+gx];return v===2?pipXY(x,y,blocks[bi].r):v===1;}
function blockAt(x,y){const gx=Math.floor((x-XMIN)/BG),gy=Math.floor((y-YMIN)/BG);if(gx<0||gy<0||gx>=bgW||gy>=bgH)return -1;for(const i of bgrid[gy*bgW+gx]){const b=blocks[i];if(x<b.bb[0]||x>b.bb[2]||y<b.bb[1]||y>b.bb[3])continue;if(inBlock(x,y,i))return i;}return -1;}
// blockIs(x, y, bi): blockAt(x, y) === bi, testing bi first (the city asks it of points that are mostly in bi)
function blockIs(x,y,bi){const b=blocks[bi];if(x<b.bb[0]||x>b.bb[2]||y<b.bb[1]||y>b.bb[3]||!inBlock(x,y,bi))return false;
  const gx=Math.floor((x-XMIN)/BG),gy=Math.floor((y-YMIN)/BG);if(gx<0||gy<0||gx>=bgW||gy>=bgH)return false;
  for(const i of bgrid[gy*bgW+gx]){if(i===bi)return true;const c=blocks[i];if(x<c.bb[0]||x>c.bb[2]||y<c.bb[1]||y>c.bb[3])continue;if(inBlock(x,y,i))return false;}return false;}
const SG=40, sgW=Math.ceil((XMAX-XMIN)/SG), sgH=Math.ceil((YMAX-YMIN)/SG);
const NOSEG=[],sgrid=new Array(sgW*sgH).fill(NOSEG); // most cells of the commune have no street: they share one empty list
const segs=[]; // [ax,ay,bx,by,hw,street index,point index]
streets.forEach((s,si)=>{const hw=swOf(s)/2;for(let i=0;i<s.pts.length-1;i++){const a=s.pts[i],b=s.pts[i+1];const id=segs.length;segs.push([a[0],a[1],b[0],b[1],hw,si,i]);
  const x0=Math.min(a[0],b[0])-hw,x1=Math.max(a[0],b[0])+hw,y0=Math.min(a[1],b[1])-hw,y1=Math.max(a[1],b[1])+hw;
  for(let gx=Math.max(0,Math.floor((x0-XMIN)/SG));gx<=Math.min(sgW-1,Math.floor((x1-XMIN)/SG));gx++)for(let gy=Math.max(0,Math.floor((y0-YMIN)/SG));gy<=Math.min(sgH-1,Math.floor((y1-YMIN)/SG));gy++){const k=gy*sgW+gx;if(sgrid[k]===NOSEG)sgrid[k]=[];sgrid[k].push(id);}}});
function nearStreet(x,y,pad){const gx=Math.floor((x-XMIN)/SG),gy=Math.floor((y-YMIN)/SG);if(gx<0||gy<0||gx>=sgW||gy>=sgH)return false;for(const id of sgrid[gy*sgW+gx]){const s=segs[id];const r=s[4]+pad;if(segDist2(x,y,s[0],s[1],s[2],s[3])<r*r)return true;}return false;}
/* occupancy raster */
const OC=2.5, ocW=Math.ceil((XMAX-XMIN)/OC), ocH=Math.ceil((YMAX-YMIN)/OC);
// The commune's box is ~8 300 × 9 500 cells and most of it stays empty, so a raster over it (occ, and the masks built
// like it) is kept in chunks of 128 × 128 cells, allocated when a cell is first written: get(gx, gy) and set(gx, gy, v)
// for cells inside the box (the caller checks), clone() copies it. keep(true): from then on the first write to a chunk
// saves its old contents, and was(gx, gy) reads the grid as it was then (the sidewalks of the rest of the startup read
// occ as walkBase saw it: walkRuns); keep(false) lets them go.
class Grid{
  constructor(){this.w=Math.ceil(ocW/128);this.c=new Array(this.w*Math.ceil(ocH/128)).fill(null);}
  get(gx,gy){const c=this.c[(gy>>7)*this.w+(gx>>7)];return c?c[((gy&127)<<7)|(gx&127)]:0;}
  set(gx,gy,v){const k=(gy>>7)*this.w+(gx>>7);let c=this.c[k];if(this.old&&!this.old.has(k))this.old.set(k,c&&c.slice());if(!c){if(!v)return;c=this.c[k]=new Uint8Array(16384);}c[((gy&127)<<7)|(gx&127)]=v;}
  clone(){const g=Object.create(Grid.prototype);g.w=this.w;g.c=this.c.map(c=>c&&c.slice());return g;}
  keep(on){this.old=on?new Map():null;}
  was(gx,gy){const k=(gy>>7)*this.w+(gx>>7),c=this.old&&this.old.has(k)?this.old.get(k):this.c[k];return c?c[((gy&127)<<7)|(gx&127)]:0;}}
const occ=new Grid();
const occAt=(x,y)=>{const gx=Math.floor((x-XMIN)/OC),gy=Math.floor((y-YMIN)/OC);return (gx<0||gy<0||gx>=ocW||gy>=ocH)?1:occ.get(gx,gy);};
const occWas=(x,y)=>{const gx=Math.floor((x-XMIN)/OC),gy=Math.floor((y-YMIN)/OC);return (gx<0||gy<0||gx>=ocW||gy>=ocH)?1:occ.was(gx,gy);}; // occ at keep(true)
function occMark(q,v=1){ // q: 4 corners [[x,y]..]; v=2: a lot of cityGen (lotFits skips those cells)
  let x0=1e9,y0=1e9,x1=-1e9,y1=-1e9;for(const p of q){x0=Math.min(x0,p[0]);x1=Math.max(x1,p[0]);y0=Math.min(y0,p[1]);y1=Math.max(y1,p[1]);}
  const xs=OM_XS; // the cells whose centre is in q (pip), a row at a time (pipRow)
  for(let gy=Math.max(0,Math.floor((y0-YMIN)/OC));gy<=Math.min(ocH-1,Math.floor((y1-YMIN)/OC));gy++){pipRow(q,YMIN+(gy+.5)*OC,xs);if(!xs.length)continue;let n=0;
    for(let gx=Math.max(0,Math.floor((x0-XMIN)/OC));gx<=Math.min(ocW-1,Math.floor((x1-XMIN)/OC));gx++){const cx=XMIN+(gx+.5)*OC;while(n<xs.length&&xs[n]<=cx)n++;
      if((xs.length-n)&1&&(v===1||!occ.get(gx,gy)))occ.set(gx,gy,v);}}}
const OM_XS=[];
function rectOcc(cx,cy,w,d){const q=[[cx-w/2,cy-d/2],[cx+w/2,cy-d/2],[cx+w/2,cy+d/2],[cx-w/2,cy+d/2]];occMark(q);}

