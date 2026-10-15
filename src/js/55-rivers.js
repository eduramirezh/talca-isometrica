/* =============== base layers =============== */
function chaikin(pts,it=2){for(let k=0;k<it;k++){const o=[pts[0]];for(let i=0;i<pts.length-1;i++){const a=pts[i],b=pts[i+1];o.push([a[0]*.75+b[0]*.25,a[1]*.75+b[1]*.25],[a[0]*.25+b[0]*.75,a[1]*.25+b[1]*.75]);}o.push(pts[pts.length-1]);pts=o;}return pts;}
function ribbon(B,pts,w,y,col,joins=true){
  for(let i=0;i<pts.length-1;i++){const a=pts[i],b=pts[i+1];const dx=b[0]-a[0],dy=b[1]-a[1];const L=Math.hypot(dx,dy);if(L<0.01)continue;const nx=-dy/L*w/2,ny=dx/L*w/2;
    B.quadXY([[a[0]+nx,a[1]+ny],[b[0]+nx,b[1]+ny],[b[0]-nx,b[1]-ny],[a[0]-nx,a[1]-ny]],y,col);}
  if(joins)for(let i=1;i<pts.length-1;i++){B.flat(ngon(pts[i][0],pts[i][1],w/2,8),y,col);}
}
// Rivers from OpenStreetMap (RIV[k], the rivers with DATA.area[k]): the water area, polygons with their islands,
// where it exists, and a ribbon of the configured width on the river's axis outside it (riverRuns: the stretches
// of the axis outside the area, each starting one point inside it). The water lies over the census blocks, which
// reach into the riverbed (their edges follow the channel's axis or a side arm), and under the streets, so the
// bridges cross it. Water and the gravel strip on every shore share 0.11 (blocks 0.10, streets from 0.12) and never
// overlap: the strip runs just outside the water. A 7 mm step under the water flickers (the depth buffer spans
// ±30 km). All the rivers' water is one mesh (riverWater).
const inRiver=(k,x,y)=>!!RIV[k]&&RIV[k].some(p=>pip([x,y],p[0])&&!p.slice(1).some(r=>pip([x,y],r)));
const inClaro=(x,y)=>inRiver('claro',x,y);
const _runs={};
// the river's lines, smoothed: its axis and its side branches (DATA.branch: the Piduco Norte)
const riverLines=k=>[DATA.water[k],...((DATA.branch||{})[k]||[])].map(l=>chaikin(dec(l),3));
function riverRuns(k){if(_runs[k])return _runs[k];const P=RIV[k]||[],runs=[];
  for(const pts of riverLines(k)){let run=null;
    for(let i=0;i<pts.length;i++){const out=!P.some(p=>pip(pts[i],p[0]));
      if(out){if(!run){run=i?[pts[i-1]]:[];runs.push(run);}run.push(pts[i]);}else if(run){run.push(pts[i]);run=null;}}}
  return _runs[k]=runs.filter(r=>r.length>1);}
// a strip w wide beside a polyline, from `off` to off+w on its left (side 1) or right (side -1), with fans at the bends
function sideRibbon(B,pts,side,off,w,y,col){
  const nrm=(a,b)=>{const L=Math.hypot(b[0]-a[0],b[1]-a[1])||1;return [-(b[1]-a[1])/L*side,(b[0]-a[0])/L*side];},at=(p,n,d)=>[p[0]+n[0]*d,p[1]+n[1]*d];
  for(let i=0;i<pts.length-1;i++){const a=pts[i],b=pts[i+1];if(Math.hypot(b[0]-a[0],b[1]-a[1])<0.01)continue;const n=nrm(a,b);
    B.quadXY([at(a,n,off),at(b,n,off),at(b,n,off+w),at(a,n,off+w)],y,col);
    if(i>0){const m=nrm(pts[i-1],a);B.quadXY([at(a,m,off),at(a,m,off+w),at(a,n,off+w),at(a,n,off)],y,col);}}}
let riverWater=null; // the rivers' water, draped: its own mesh (matWater), drawn over coplanar layers
function riverBase(B,BW,k,[w,rb]){
  const V=r=>r.map(p=>new T.Vector2(p[0],p[1]));
  for(const [outer,...isl] of RIV[k]){const all=outer.concat(...isl);
    for(const t of T.ShapeUtils.triangulateShape(V(outer),isl.map(V)))BW.face(t.map(i=>[all[i][0],0.11,-all[i][1]]),[0,1,0],PAL.water);}
  // shore strips, outside the water: right of a counter-clockwise outer ring, left of a counter-clockwise island.
  // None on ring edges the clip laid along the model's border, nor on the edge where the area ends across the river,
  // and in water colour where it would lie in another river's water: the Piduco's mouths in the Claro, where the two
  // OSM areas leave a crack of a few metres between them
  const wet=p=>Object.keys(RIV).some(j=>j!==k&&inRiver(j,p[0],p[1]));
  const lines=riverLines(k),o=(p,q,r)=>(q[0]-p[0])*(r[1]-p[1])-(q[1]-p[1])*(r[0]-p[0]);
  const cross=(a,b)=>lines.some(axis=>axis.some((c,i)=>i<axis.length-1&&o(a,b,c)*o(a,b,axis[i+1])<0&&o(c,axis[i+1],a)*o(c,axis[i+1],b)<0));
  const skip=(a,b)=>[XMIN,XMAX].some(v=>Math.abs(a[0]-v)<1&&Math.abs(b[0]-v)<1)||[YMIN,YMAX].some(v=>Math.abs(a[1]-v)<1&&Math.abs(b[1]-v)<1)||cross(a,b);
  for(const P of RIV[k])P.forEach((r,j)=>{let A=0;for(let i=0;i<r.length;i++){const p=r[i],q=r[(i+1)%r.length];A+=p[0]*q[1]-q[0]*p[1];}
    const side=(A>0?1:-1)*(j?1:-1);let run=[],cls=0;
    const inOther=(a,b)=>{const L=Math.hypot(b[0]-a[0],b[1]-a[1])||1;return [[.5,.3],[.5,.9],[.15,.6],[.85,.6]].some(([t,f])=>{const d=rb*f/L*side;
      return wet([a[0]+(b[0]-a[0])*t-(b[1]-a[1])*d,a[1]+(b[1]-a[1])*t+(b[0]-a[0])*d]);});};
    const flush=()=>{if(run.length>1){if(cls===1)sideRibbon(B,run,side,0,rb,0.11,PAL.bank);else if(cls===2)sideRibbon(BW,run,side,0,rb,0.11,PAL.water);}run=[];};
    for(let i=0;i<=r.length;i++){const a=r[i%r.length],b=r[(i+1)%r.length];
      const c=i<r.length&&!skip(a,b)?(inOther(a,b)?2:1):0;if(c!==cls){flush();cls=c;}
      if(c){if(!run.length)run.push(a);run.push(b);}}flush();});
  // the ribbon's strips stop where it enters another river's water
  for(const run of riverRuns(k)){ribbon(BW,run,w,0.11,PAL.water);
    let dry=[];for(const p of run.concat([null])){if(p&&!wet(p)){dry.push(p);continue;}
      if(dry.length>1)for(const sd of [1,-1])sideRibbon(B,dry,sd,w/2,rb,0.11,PAL.bank);dry=[];}}
}
// The water lies level across its channel. The relief does not follow the real rivers everywhere (at the Parque Río
// Claro the terrain fell 10 m across the jetty), so the draped water tilted. The terrain nodes in a channel (inside
// a river's area, or on its ribbon outside it) take the mean height of the channel nodes within 80 m; along the
// river the level still follows the valley, and the shore cells slope from it to the banks. (The lowest node instead
// of the mean cut cliffs into the banks where the relief's valley is off the real river.) Runs before buildModels;
// riversRelevel() puts the levels back after the pads, which set every node within 40 m of their box.
const RIV_LEV=new Float32Array(EN_).fill(NaN);
function riversLevel(){const ks=Object.keys(RIV);if(!ks.length)return;const ch=new Uint8Array(EN_);
  for(const k of ks){const [w]=DATA.widths[k];
    const onRun=(x,y)=>riverRuns(k).some(run=>run.some((a,i)=>i<run.length-1&&segDist2(x,y,a[0],a[1],run[i+1][0],run[i+1][1])<w*w/4));
    for(let j=0;j<ENY;j++)for(let i=0;i<ENX;i++){const x=EX0+i*ES,y=EY0+j*ES;if(RIV[k].some(p=>pip([x,y],p[0]))||onRun(x,y))ch[j*ENX+i]=1;}}
  for(let j=0;j<ENY;j++)for(let i=0;i<ENX;i++){const k=j*ENX+i;if(!ch[k])continue;let s=0,n=0;
    for(let dj=-2;dj<=2;dj++)for(let di=-2;di<=2;di++){const ii=i+di,jj=j+dj;if(ii<0||jj<0||ii>=ENX||jj>=ENY||di*di+dj*dj>5)continue;const kk=jj*ENX+ii;if(ch[kk]){s+=EH[kk];n++;}}
    RIV_LEV[k]=s/n;}
  riversRelevel();
}
function riversRelevel(){for(let k=0;k<EN_;k++)if(!isNaN(RIV_LEV[k]))EH[k]=RIV_LEV[k];}
// no lots, trees or lamps in the rivers or on their gravel: each area (a scanline fill, even-odd for the islands),
// a band of the strip's width along every shore and the ribbon outside the area are occupied
function riversOcc(){for(const k in RIV){
  for(const P of RIV[k]){const ed=[];for(const r of P)for(let i=0;i<r.length;i++)ed.push([r[i],r[(i+1)%r.length]]);
    let y0=1e9,y1=-1e9;for(const p of P[0]){y0=Math.min(y0,p[1]);y1=Math.max(y1,p[1]);}
    for(let gy=Math.max(0,Math.floor((y0-YMIN)/OC));gy<=Math.min(ocH-1,Math.floor((y1-YMIN)/OC));gy++){const cy=YMIN+(gy+.5)*OC,xs=[];
      for(const [a,b] of ed)if((a[1]>cy)!==(b[1]>cy))xs.push(a[0]+(cy-a[1])*(b[0]-a[0])/(b[1]-a[1]));
      xs.sort((p,q)=>p-q);
      for(let i=0;i+1<xs.length;i+=2)for(let gx=Math.max(0,Math.ceil((xs[i]-XMIN)/OC-.5));gx<=Math.min(ocW-1,Math.floor((xs[i+1]-XMIN)/OC-.5));gx++)occ[gy*ocW+gx]=1;}}
  const [w,rb]=DATA.widths[k],hw=w/2+rb;
  for(const P of RIV[k])for(const r of P)for(let i=0;i<r.length;i++)occBand(r[i],r[(i+1)%r.length],rb); // the gravel strip along every shore
  for(const run of riverRuns(k))for(let i=0;i<run.length-1;i++)occBand(run[i],run[i+1],hw);
}}
// occupies the cells within r of the segment a-b
function occBand(a,b,r){for(let gx=Math.floor((Math.min(a[0],b[0])-r-XMIN)/OC);gx<=Math.floor((Math.max(a[0],b[0])+r-XMIN)/OC);gx++)
  for(let gy=Math.floor((Math.min(a[1],b[1])-r-YMIN)/OC);gy<=Math.floor((Math.max(a[1],b[1])+r-YMIN)/OC);gy++){
    if(gx<0||gy<0||gx>=ocW||gy>=ocH)continue;if(segDist2(XMIN+(gx+.5)*OC,YMIN+(gy+.5)*OC,a[0],a[1],b[0],b[1])<r*r)occ[gy*ocW+gx]=1;}}
// no lots or trees on the Ruta 5 (26 m) or the railway (6 m of ballast), plus a margin: both are OpenStreetMap's
// lines now (only the rail's central stretch is hand-traced), and the lots along their frontage streets reached them
function linesOcc(){for(const [d,hw] of [[DATA.ruta5,15],[DATA.rail,5]]){const p=chaikin(dec(d),2);for(let i=0;i<p.length-1;i++)occBand(p[i],p[i+1],hw);}}
