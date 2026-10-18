// sidewalks, curbs and crosswalks, draped straight into G (buildBase's ground); the Diagonal's median first (it
// occupies the raster), with its shrubs and lamps on D, and the paseos (paseosBase)
// (with L, the startup's lists: the strips outside STAGE wait in L.walk)
// (with STAGE, only the streets whose sidewalks can reach it: the others wait in L.walkSts for the second stage,
// walkRest, reading occ as it is now, occ.keep)
function walkBase(G,D,L){const t0=performance.now(),B=draped(G,L&&L.walk),nv=G.nv;diagonalBase(G,D);paseosBase(G,D);
  let sis=null;if(STAGE&&L){const[a,b]=split([...streets.keys()],si=>{const s=streets[si],m=swOf(s)/2+WALK_OUT+3;let x0=1e9,y0=1e9,x1=-1e9,y1=-1e9;
      for(const p of s.pts){x0=Math.min(x0,p[0]);x1=Math.max(x1,p[0]);y0=Math.min(y0,p[1]);y1=Math.max(y1,p[1]);}return boxIn(x0-m,y0-m,x1+m,y1+m);});
    sis=a;L.walkSts=b;occ.keep(true);}
  walkRuns(sis);const t1=performance.now();walkRibbons(B,WALKS);
  B.band=streets.length+1;STREET.zebras=crossings(B);Object.assign(STREET,{walks:WALKS.length,walkVerts:G.nv-nv,walkMs:Math.round(performance.now()-t0),runMs:Math.round(t1-t0)});}
// the sidewalks and curbs of the runs ws, each street in its band of keys (draped)
const WALK_K=hex('#C3C1BA'),CURB_K=hex('#E8E5DC');
function walkRibbons(B,ws){for(const w of ws){B.band=w.si+1;sideRibbon(B,w.pts,w.side,w.hw-w.iw+CURB,w.iw+WALK_OUT-CURB,WALK_Y,WALK_K);sideRibbon(B,w.pts,w.side,w.hw-w.iw,CURB,CURB_Y,CURB_K);}}
// the second stage's sidewalks (walkBase): the runs of L.walkSts as walkBase would have seen them, their quads to
// L.walk (all outside STAGE), WALKS back in the order of the streets; a generator, a piece every n streets
function* walkRest(G,L,n){const B=draped(G,L.walk),sts=L.walkSts||[],out=[];
  for(let i=0;i<sts.length;i+=n){const w0=WALKS.length;walkRuns(sts.slice(i,i+n),occWas);const ws=WALKS.slice(w0);walkRibbons(B,ws);out.push(...ws);yield;}
  occ.keep(false);WALKS.sort((a,b)=>a.si-b.si);STREET.walks=WALKS.length;return out;}
// buildBase(L): with L, the startup's lists, the triangles outside STAGE wait in L.base (of the flat layers, L.flat)
// and L.water (L.flatW)
function buildBase(L){
  const B=new GB(1<<17);
  // farmland parcels outside urban area, but where a land use of OSM says what the ground is (usoAt: a real field,
  // orchard, vineyard, wood or vacant lot)
  const r=rng(4242);
  for(let x=XMIN;x<XMAX;x+=160){for(let y=YMIN;y<YMAX;y+=130){
    if(!CM[cellOf(x+80,y+65)]&&!CM[cellOf(x,y)]&&!CM[cellOf(x+160,y+130)]&&!CM[cellOf(x,y+130)]&&!CM[cellOf(x+160,y)])continue; // outside the commune
    let px=x,w=160;
    while(px<x+160){const pw=Math.min(40+r()*120,x+160-px);const cx=px+pw/2,cy=y+65;
      if(blockAt(cx,cy)<0&&blockAt(px+3,y+3)<0&&blockAt(px+pw-3,y+127)<0&&Math.max(wildAt(cx,cy),wildAt(px,y),wildAt(px+pw,y+130))<0.35&&!usoAt(cx,cy)){
        B.quadXY([[px+1.5,y+1.5],[px+pw-1.5,y+1.5],[px+pw-1.5,y+128.5],[px+1.5,y+128.5]],0.02,pick(r,PAL.fields));
        if(r()<.07){for(let yy=y+4;yy<y+126;yy+=6)if(inTerrain(px+2,yy))PO_FIELD.push([px+2,yy,0.9+r()*0.4,r()]);}
      }
      px+=pw;}
  }}
  // blocks
  blocks.forEach((b,bi)=>{let col;
    if(bi===PLAZA_BI)col=PAL.park; else if(b.built){col=b.edYard?edYardCol(bi):PAL.lot;} // edYard: a block of real houses (52-edificios.js)
    else if(ALAM.has(bi))col=PAL.lawn;
    else col=b.A<40000?PAL.park:PAL.open;
    B.flat(b.r,0.1,col);});
  alamedaGround(B);
  // plaza de armas block recolor handled by trees
  // rivers: a green riparian margin (not along an irrigation canal, W[k][2]), then gravel bank and water. A river
  // from OpenStreetMap (RIV; an estero or a canal without OSM water is all ribbon) lies over the blocks (riverBase);
  // a hand-traced one is a ribbon under them
  const W=DATA.widths,BW=new GB(1<<14);
  for(const k in DATA.water){const pts=chaikin(dec(DATA.water[k]),3);if(!W[k][2])ribbon(B,pts,W[k][0]+W[k][1]*2+(W[k][0]<30?40:150),0.03,hex('#A7B472'));
    if(RIV[k]){riverBase(B,BW,k,W[k]);continue;}
    ribbon(B,pts,W[k][0]+W[k][1]*2,0.05,PAL.bank);ribbon(B,pts,W[k][0],0.07,PAL.water);}
  riverWater=drape(BW,L&&L.water);if(L)L.flatW=BW;
  ruta5Base(B);  // under the streets
  // streets
  const order=[7,6,5,4,3,2,1,0];
  // (a street a landmark draws as a bridge, s.bridge, stays off the ground: the Ruta K-60-J over the Río Claro)
  for(const c of order)streets.forEach(s=>{if(s.c===c&&!s.bridge&&!s.paseo)ribbon(B,s.pts,swOf(s),0.12+(7-c)*0.004,c<=2?PAL.asphalt2:PAL.asphalt,c<=5);});
  railBase(B);   // over the streets
  if(L)L.flat=B;return drape(B,L&&L.base);
}
