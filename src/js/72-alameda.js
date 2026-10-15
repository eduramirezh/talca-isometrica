const PO_FIELD=[];
const PLAZA_BI=blockAt(BYID['plaza-de-armas'].x,BYID['plaza-de-armas'].y);
// La Alameda: the park strips down the middle of the avenue (no census data, under 80 m deep, centroid on the avenue).
// Blocks with census data inside the strip keep their buildings.
const ALAM=(()=>{const g=[];streets.forEach(s=>{if(/Alameda/.test(s.name||''))for(let i=0;i<s.pts.length-1;i++)g.push([...s.pts[i],...s.pts[i+1]]);});
  const o=new Set();blocks.forEach((b,bi)=>{if(!b.built&&b.bb[3]-b.bb[1]<80&&g.some(s=>segDist2(b.cx,b.cy,...s)<38*38))o.add(bi);});return o;})();
// Each strip is a linear park: a gravel paseo down the middle with lawn edging, a cross walk and a round plaza at
// mid-block (around the landmark when one stands in the strip, else a fountain or a plinth), benches and lamps along
// the paseo, and four staggered rows of big trees. alamedaGround() lays the flat parts (draped by buildBase),
// alamedaPark() the objects and the trees.
const ALAM_LAMPS=[];
const box=(x0,y0,x1,y1)=>[[x0,y0],[x1,y0],[x1,y1],[x0,y1]];
function alamedaPlan(bi){const b=blocks[bi];if(b._al)return b._al;
  const [x0,y0,x1,y1]=b.bb,cy=(y0+y1)/2;let px=(x0+x1)/2,lm=null;
  for(const k in MODELS){const m=MODELS[k];if(m.x>x0&&m.x<x1&&Math.abs(m.y-cy)<20){px=m.x;lm=k;}}
  return b._al={x0:x0+5,x1:x1-5,y0:y0+3,y1:y1-3,cy,px,lm,pr:lm?11:8};}
function alamedaGround(B){
  ALAM.forEach(bi=>{const a=alamedaPlan(bi);if(a.x1-a.x0<20)return;const {x0,x1,cy,px,pr}=a;
    B.quadXY(box(x0,cy-6.5,x1,cy+6.5),0.107,PAL.edging);B.quadXY(box(px-4.5,a.y0,px+4.5,a.y1),0.107,PAL.edging);B.flat(ngon(px,cy,pr+2,20),0.107,PAL.edging);
    B.quadXY(box(x0,cy-4.5,x1,cy+4.5),0.114,PAL.gravel);B.quadXY(box(px-2.5,a.y0,px+2.5,a.y1),0.114,PAL.gravel);B.flat(ngon(px,cy,pr,20),0.114,PAL.gravel);});
}
function alamedaPark(B){const TR=[],C=hex,stone=C('#D2CAB8'),iron=C('#3B4240'),wood=C('#7A5A3E');
  ALAM.forEach(bi=>{const b=blocks[bi],a=alamedaPlan(bi),r=rng(bi*53+11);if(a.x1-a.x0<20)return;const {x0,x1,cy,px,pr}=a;
    if(!a.lm){B.dy=groundMin(ngon(px,cy,6,8));
      if(r()<.5){B.prism(ngon(px,cy,5.5,16),0.3,0.95,stone,PAL.water2);B.prism(ngon(px,cy,1.1,8),0.95,2.6,stone,C('#E6E0D2'));}
      else{B.prism(rotRect(px,cy,3.2,3.2),0.3,3.4,stone,stone);B.prism(ngon(px,cy,.7,8),3.4,5.6,C('#56614F'),C('#56614F'));}}
    const clear=(x,m)=>Math.abs(x-px)>pr+m;
    for(let x=x0+6;x<x1-3;x+=16)for(const sd of[-1,1]){
      if(clear(x,3)){B.dy=E(x,cy+sd*3.7);B.prism(rotRect(x,cy+sd*3.7,2.2,.7),0.3,0.75,wood,shade(wood,1.15));}
      const lx=x+8,ly=cy+sd*5.5;if(lx<x1-3&&clear(lx,3)){B.dy=E(lx,ly);B.prism(rotRect(lx,ly,.3,.3),0.3,4.4,iron,iron);B.prism(rotRect(lx,ly,.9,.9),4.4,4.8,iron,C('#F1E6C4'));ALAM_LAMPS.push(lx,ly);}}
    for(const [v,o] of [[11,0],[20,4.5]])for(const sd of[-1,1])for(let x=x0+2+o;x<x1+3;x+=9){
      const tx=x+(r()-.5)*1.4,ty=cy+sd*v+(r()-.5)*1.4;
      if(!clear(tx,4)||!pip([tx,ty],b.r)||occAt(tx,ty)||nearStreet(tx,ty,1.5))continue;
      TR.push([tx,ty,1.25+r()*.35,r()]);}});
  B.dy=0;return TR;
}
