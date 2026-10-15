/* =============== decode data =============== */
// block t: 0 census data, 1 no data, 2 village, 3 no data but built (config/manzanas.json). Only built blocks get lots.
function dec(a){const o=new Array(a.length/2);let x=0,y=0;for(let i=0,j=0;i<a.length;i+=2,j++){x+=a[i];y+=a[i+1];o[j]=[x,y];}return o;}
const [XMIN,XMAX,YMIN,YMAX]=DATA.ext;
const blocks=DATA.blocks.map(b=>{const r=dec(b[3]);let A=0,cx=0,cy=0,x0=1e9,y0=1e9,x1=-1e9,y1=-1e9;
  for(let i=0;i<r.length;i++){const p=r[i],q=r[(i+1)%r.length];const c=p[0]*q[1]-q[0]*p[1];A+=c;cx+=(p[0]+q[0])*c;cy+=(p[1]+q[1])*c;
    if(p[0]<x0)x0=p[0];if(p[0]>x1)x1=p[0];if(p[1]<y0)y0=p[1];if(p[1]>y1)y1=p[1];}
  A/=2;return {t:b[0],built:b[0]===0||b[0]===3,pers:b[1],viv:b[2],r,A:Math.abs(A),cx:cx/(6*A),cy:cy/(6*A),bb:[x0,y0,x1,y1]};});
const SW=[16,13,11,9.5,7,5,3.5,3.5]; // street widths per class
const streets=DATA.streets.map(s=>({c:s[0],name:DATA.names[s[1]],pts:dec(s[2])}));
// Streets drawn narrower than their class: [name, width, sidewalk inside it, street trees [spacing, size] in rows on
// every run]. The Diagonal (Avenida Isidoro del Solar) is two one-way carriageways of one lane and parking, 12 m apart
// (OSM), with a tree-lined median between them (diagonalBase); at its class width (11 m) they would cover the median.
const STREET_W=[[/^Avenida Isidoro del Solar$/,9.5,2,[7,.75]]];
streets.forEach(s=>{for(const [re,w,walk,rows] of STREET_W)if(re.test(s.name||'')){s.w=w;s.walk=walk;s.rows=rows;}});
const swOf=s=>s.w||SW[s.c],walkOf=s=>s.walk??WALK[s.c]; // a street's width and sidewalk (WALK: street level)
// the water of the rivers from OpenStreetMap: RIV[k] = [[outer ring, island, ...], ...] (pipeline/process_geometry.py);
// CLARO is the Río Claro's one polygon, [outer ring, island, ...]
const RIV={};for(const k in DATA.area||{})RIV[k]=DATA.area[k].map(p=>p.map(dec));
const CLARO=RIV.claro?RIV.claro[0]:[];
const W2L=(x,y)=>[x,-y];

