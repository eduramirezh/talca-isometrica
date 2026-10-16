/* spatial grids */
const BG=100, bgW=Math.ceil((XMAX-XMIN)/BG), bgH=Math.ceil((YMAX-YMIN)/BG);
const bgrid=Array.from({length:bgW*bgH},()=>[]);
blocks.forEach((b,i)=>{for(let gx=Math.max(0,Math.floor((b.bb[0]-XMIN)/BG));gx<=Math.min(bgW-1,Math.floor((b.bb[2]-XMIN)/BG));gx++)for(let gy=Math.max(0,Math.floor((b.bb[1]-YMIN)/BG));gy<=Math.min(bgH-1,Math.floor((b.bb[3]-YMIN)/BG));gy++)bgrid[gy*bgW+gx].push(i);});
// the urban area: the 100 m cells within one cell of a built block's box (no street lamps on the country roads)
const URB=new Uint8Array(bgW*bgH);
blocks.forEach(b=>{if(!b.built)return;for(let gx=Math.max(0,Math.floor((b.bb[0]-XMIN)/BG)-1);gx<=Math.min(bgW-1,Math.floor((b.bb[2]-XMIN)/BG)+1);gx++)for(let gy=Math.max(0,Math.floor((b.bb[1]-YMIN)/BG)-1);gy<=Math.min(bgH-1,Math.floor((b.bb[3]-YMIN)/BG)+1);gy++)URB[gy*bgW+gx]=1;});
const urbanAt=(x,y)=>{const gx=Math.floor((x-XMIN)/BG),gy=Math.floor((y-YMIN)/BG);return gx>=0&&gy>=0&&gx<bgW&&gy<bgH&&URB[gy*bgW+gx]===1;};
function blockAt(x,y){const gx=Math.floor((x-XMIN)/BG),gy=Math.floor((y-YMIN)/BG);if(gx<0||gy<0||gx>=bgW||gy>=bgH)return -1;for(const i of bgrid[gy*bgW+gx]){const b=blocks[i];if(x<b.bb[0]||x>b.bb[2]||y<b.bb[1]||y>b.bb[3])continue;if(pipXY(x,y,b.r))return i;}return -1;}
// blockIs(x, y, bi): blockAt(x, y) === bi, testing bi first (the city asks it of points that are mostly in bi)
function blockIs(x,y,bi){const b=blocks[bi];if(x<b.bb[0]||x>b.bb[2]||y<b.bb[1]||y>b.bb[3]||!pipXY(x,y,b.r))return false;
  const gx=Math.floor((x-XMIN)/BG),gy=Math.floor((y-YMIN)/BG);if(gx<0||gy<0||gx>=bgW||gy>=bgH)return false;
  for(const i of bgrid[gy*bgW+gx]){if(i===bi)return true;const c=blocks[i];if(x<c.bb[0]||x>c.bb[2]||y<c.bb[1]||y>c.bb[3])continue;if(pipXY(x,y,c.r))return false;}return false;}
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
// for cells inside the box (the caller checks), clone() copies it.
class Grid{
  constructor(){this.w=Math.ceil(ocW/128);this.c=new Array(this.w*Math.ceil(ocH/128)).fill(null);}
  get(gx,gy){const c=this.c[(gy>>7)*this.w+(gx>>7)];return c?c[((gy&127)<<7)|(gx&127)]:0;}
  set(gx,gy,v){const k=(gy>>7)*this.w+(gx>>7);let c=this.c[k];if(!c){if(!v)return;c=this.c[k]=new Uint8Array(16384);}c[((gy&127)<<7)|(gx&127)]=v;}
  clone(){const g=Object.create(Grid.prototype);g.w=this.w;g.c=this.c.map(c=>c&&c.slice());return g;}}
const occ=new Grid();
const occAt=(x,y)=>{const gx=Math.floor((x-XMIN)/OC),gy=Math.floor((y-YMIN)/OC);return (gx<0||gy<0||gx>=ocW||gy>=ocH)?1:occ.get(gx,gy);};
function occMark(q,v=1){ // q: 4 corners [[x,y]..]; v=2: a lot of cityGen (lotFits skips those cells)
  let x0=1e9,y0=1e9,x1=-1e9,y1=-1e9;for(const p of q){x0=Math.min(x0,p[0]);x1=Math.max(x1,p[0]);y0=Math.min(y0,p[1]);y1=Math.max(y1,p[1]);}
  const xs=OM_XS; // the cells whose centre is in q (pip), a row at a time (pipRow)
  for(let gy=Math.max(0,Math.floor((y0-YMIN)/OC));gy<=Math.min(ocH-1,Math.floor((y1-YMIN)/OC));gy++){pipRow(q,YMIN+(gy+.5)*OC,xs);if(!xs.length)continue;let n=0;
    for(let gx=Math.max(0,Math.floor((x0-XMIN)/OC));gx<=Math.min(ocW-1,Math.floor((x1-XMIN)/OC));gx++){const cx=XMIN+(gx+.5)*OC;while(n<xs.length&&xs[n]<=cx)n++;
      if((xs.length-n)&1&&(v===1||!occ.get(gx,gy)))occ.set(gx,gy,v);}}}
const OM_XS=[];
function rectOcc(cx,cy,w,d){const q=[[cx-w/2,cy-d/2],[cx+w/2,cy-d/2],[cx+w/2,cy+d/2],[cx-w/2,cy+d/2]];occMark(q);}

