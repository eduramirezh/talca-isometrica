/* spatial grids */
const BG=100, bgW=Math.ceil((XMAX-XMIN)/BG), bgH=Math.ceil((YMAX-YMIN)/BG);
const bgrid=Array.from({length:bgW*bgH},()=>[]);
blocks.forEach((b,i)=>{for(let gx=Math.max(0,Math.floor((b.bb[0]-XMIN)/BG));gx<=Math.min(bgW-1,Math.floor((b.bb[2]-XMIN)/BG));gx++)for(let gy=Math.max(0,Math.floor((b.bb[1]-YMIN)/BG));gy<=Math.min(bgH-1,Math.floor((b.bb[3]-YMIN)/BG));gy++)bgrid[gy*bgW+gx].push(i);});
function blockAt(x,y){const gx=Math.floor((x-XMIN)/BG),gy=Math.floor((y-YMIN)/BG);if(gx<0||gy<0||gx>=bgW||gy>=bgH)return -1;for(const i of bgrid[gy*bgW+gx]){const b=blocks[i];if(x<b.bb[0]||x>b.bb[2]||y<b.bb[1]||y>b.bb[3])continue;if(pip([x,y],b.r))return i;}return -1;}
const SG=40, sgW=Math.ceil((XMAX-XMIN)/SG), sgH=Math.ceil((YMAX-YMIN)/SG);
const sgrid=Array.from({length:sgW*sgH},()=>[]);
const segs=[]; // [ax,ay,bx,by,hw,street index,point index]
streets.forEach((s,si)=>{const hw=swOf(s)/2;for(let i=0;i<s.pts.length-1;i++){const a=s.pts[i],b=s.pts[i+1];const id=segs.length;segs.push([a[0],a[1],b[0],b[1],hw,si,i]);
  const x0=Math.min(a[0],b[0])-hw,x1=Math.max(a[0],b[0])+hw,y0=Math.min(a[1],b[1])-hw,y1=Math.max(a[1],b[1])+hw;
  for(let gx=Math.max(0,Math.floor((x0-XMIN)/SG));gx<=Math.min(sgW-1,Math.floor((x1-XMIN)/SG));gx++)for(let gy=Math.max(0,Math.floor((y0-YMIN)/SG));gy<=Math.min(sgH-1,Math.floor((y1-YMIN)/SG));gy++)sgrid[gy*sgW+gx].push(id);}});
function nearStreet(x,y,pad){const gx=Math.floor((x-XMIN)/SG),gy=Math.floor((y-YMIN)/SG);if(gx<0||gy<0||gx>=sgW||gy>=sgH)return false;for(const id of sgrid[gy*sgW+gx]){const s=segs[id];const r=s[4]+pad;if(segDist2(x,y,s[0],s[1],s[2],s[3])<r*r)return true;}return false;}
/* occupancy raster */
const OC=2.5, ocW=Math.ceil((XMAX-XMIN)/OC), ocH=Math.ceil((YMAX-YMIN)/OC);
const occ=new Uint8Array(ocW*ocH);
const occAt=(x,y)=>{const gx=Math.floor((x-XMIN)/OC),gy=Math.floor((y-YMIN)/OC);return (gx<0||gy<0||gx>=ocW||gy>=ocH)?1:occ[gy*ocW+gx];};
function occMark(q,v=1){ // q: 4 corners [[x,y]..]; v=2: a lot of cityGen (lotFits skips those cells)
  let x0=1e9,y0=1e9,x1=-1e9,y1=-1e9;for(const p of q){x0=Math.min(x0,p[0]);x1=Math.max(x1,p[0]);y0=Math.min(y0,p[1]);y1=Math.max(y1,p[1]);}
  for(let gx=Math.floor((x0-XMIN)/OC);gx<=Math.floor((x1-XMIN)/OC);gx++)for(let gy=Math.floor((y0-YMIN)/OC);gy<=Math.floor((y1-YMIN)/OC);gy++){
    if(gx<0||gy<0||gx>=ocW||gy>=ocH)continue;const cx=XMIN+(gx+.5)*OC,cy=YMIN+(gy+.5)*OC;if(pip([cx,cy],q)&&(v===1||!occ[gy*ocW+gx]))occ[gy*ocW+gx]=v;}}
function rectOcc(cx,cy,w,d){const q=[[cx-w/2,cy-d/2],[cx+w/2,cy-d/2],[cx+w/2,cy+d/2],[cx-w/2,cy+d/2]];occMark(q);}

