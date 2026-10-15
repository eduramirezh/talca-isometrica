// sidewalks, curbs and crosswalks, draped straight into G (buildBase's ground); the Diagonal's median first (it
// occupies the raster), with its shrubs and lamps on D
function walkBase(G,D){const t0=performance.now(),B=draped(G),nv=G.nv,sw=hex('#C3C1BA'),curb=hex('#E8E5DC');diagonalBase(G,D);walkRuns();const t1=performance.now();
  for(const w of WALKS){sideRibbon(B,w.pts,w.side,w.hw-w.iw+CURB,w.iw+WALK_OUT-CURB,WALK_Y,sw);sideRibbon(B,w.pts,w.side,w.hw-w.iw,CURB,CURB_Y,curb);}
  STREET.zebras=crossings(B);Object.assign(STREET,{walks:WALKS.length,walkVerts:G.nv-nv,walkMs:Math.round(performance.now()-t0),runMs:Math.round(t1-t0)});}
function buildBase(){
  const B=new GB(1<<17);
  // farmland parcels outside urban area
  const r=rng(4242);
  for(let x=XMIN;x<XMAX;x+=160){for(let y=YMIN;y<YMAX;y+=130){
    if(!CM[cellOf(x+80,y+65)]&&!CM[cellOf(x,y)]&&!CM[cellOf(x+160,y+130)]&&!CM[cellOf(x,y+130)]&&!CM[cellOf(x+160,y)])continue; // outside the commune
    let px=x,w=160;
    while(px<x+160){const pw=Math.min(40+r()*120,x+160-px);const cx=px+pw/2,cy=y+65;
      if(blockAt(cx,cy)<0&&blockAt(px+3,y+3)<0&&blockAt(px+pw-3,y+127)<0&&Math.max(wildAt(cx,cy),wildAt(px,y),wildAt(px+pw,y+130))<0.35){
        B.quadXY([[px+1.5,y+1.5],[px+pw-1.5,y+1.5],[px+pw-1.5,y+128.5],[px+1.5,y+128.5]],0.02,pick(r,PAL.fields));
        if(r()<.07){for(let yy=y+4;yy<y+126;yy+=6)if(inTerrain(px+2,yy))PO_FIELD.push([px+2,yy,0.9+r()*0.4,r()]);}
      }
      px+=pw;}
  }}
  // blocks
  blocks.forEach((b,bi)=>{let col;
    if(bi===PLAZA_BI)col=PAL.park; else if(b.built){col=PAL.lot;}
    else if(ALAM.has(bi))col=PAL.lawn;
    else col=b.A<40000?PAL.park:PAL.open;
    B.flat(b.r,0.1,col);});
  alamedaGround(B);
  // plaza de armas block recolor handled by trees
  // rivers: a green riparian margin, then gravel bank and water. A river with OpenStreetMap's water (RIV) lies over
  // the blocks (riverBase); a hand-traced one is a ribbon under them
  const W=DATA.widths,BW=new GB(1<<14);
  for(const k of ['lircay','claro','piduco']){const pts=chaikin(dec(DATA.water[k]),3);ribbon(B,pts,W[k][0]+W[k][1]*2+(W[k][0]<30?40:150),0.03,hex('#A7B472'));
    if(RIV[k]){riverBase(B,BW,k,W[k]);continue;}
    ribbon(B,pts,W[k][0]+W[k][1]*2,0.05,PAL.bank);ribbon(B,pts,W[k][0],0.07,PAL.water);}
  riverWater=drape(BW);
  ruta5Base(B);  // under the streets
  // streets
  const order=[7,6,5,4,3,2,1,0];
  // (a street a landmark draws as a bridge, s.bridge, stays off the ground: the Ruta K-60-J over the Río Claro)
  for(const c of order)streets.forEach(s=>{if(s.c===c&&!s.bridge)ribbon(B,s.pts,swOf(s),0.12+(7-c)*0.004,c<=2?PAL.asphalt2:PAL.asphalt,c<=5);});
  railBase(B);   // over the streets
  return drape(B);
}
