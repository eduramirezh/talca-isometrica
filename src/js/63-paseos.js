// ==== paseos peatonales ====
// Pedestrian streets (PASEOS, in 10-decode.js: a name and the width from facade to facade). The graph of cicloconecta has them as paths
// (class 6, 3.5 m, no sidewalks), and between the real buildings of OSM (edificiosBase) that left a thin grey line in a
// wide gap. A paseo is drawn at its width instead: paving in two tones in bands across it, two rows of slim trees a
// few metres from the facades with lamp posts between them, and planters down the middle; the crossing streets go
// over it (the paving is at the class-6 street height, 0.124) and nothing stands on them. edificiosGround paves the
// strip between the paseo and the facades in its colour.
// The Paseo Peatonal 1 Sur (3 to 6 Oriente; OSM w89069029, highway=pedestrian, paving stones): photo of 2013 on
// Commons (File:Paseo Peatonal de Talca.jpg, diagnostics/fotos/diagonal/): warm grey tiles from facade to facade
// (~15 m), two rows of slim trees ~3 m from the facades with the lamps among them, concrete planters and benches.
// Approximate: the spacing of trees (9 m), lamps (18 m) and planters (24 m); the benches are below the art pixel.
const PASEO_K={pave:hex('#B4A79D'),pave2:hex('#A39286'),planter:hex('#B7B2A8'),shrub:hex('#5C7A3E'),iron:hex('#3B4240'),lamp:hex('#F1E6C4')};
function paseosBase(G,D){const B=draped(G),r=rng(5150);let n=0;
  // a point on another street's carriageway, or on what occupied the raster before (a landmark)
  const cross=(x,y,si)=>{const gx=Math.floor((x-XMIN)/SG),gy=Math.floor((y-YMIN)/SG);if(gx<0||gy<0||gx>=sgW||gy>=sgH)return true;
    for(const id of sgrid[gy*sgW+gx]){const s=segs[id];if(s[5]===si||streets[s[5]].c>=6)continue;const R=s[4]+1.5;if(segDist2(x,y,s[0],s[1],s[2],s[3])<R*R)return true;}
    return occAt(x,y)===1;};
  streets.forEach((s,si)=>{if(!s.paseo)return;const hw=swOf(s)/2;
    for(let i=0;i<s.pts.length-1;i++){const a=s.pts[i],b=s.pts[i+1],L=Math.hypot(b[0]-a[0],b[1]-a[1]);if(L<1)continue;
      const tx=(b[0]-a[0])/L,ty=(b[1]-a[1])/L,nx=-ty,ny=tx,P=(u,v)=>[a[0]+tx*u+nx*v,a[1]+ty*u+ny*v];
      // paving: bands of 3 m across, alternating tones (ESTETICA §3)
      const nb=Math.max(1,Math.round(L/3));for(let k=0;k<nb;k++){const u0=L*k/nb,u1=L*(k+1)/nb;B.quadXY([P(u0,-hw),P(u1,-hw),P(u1,hw),P(u0,hw)],0.124,k%2?PASEO_K.pave2:PASEO_K.pave);}
      const off=Math.max(1.5,hw-3);
      for(const [side,ph] of [[-1,0],[1,4.5]]){
        for(let u=4+ph;u<L-3;u+=9){const [x,y]=P(u,side*off);if(cross(x,y,si))continue;
          if(Math.round((u-4-ph)/9)%2===1){const q=rotRect(x,y,.3,.3),h=E(x,y)+0.124;D.dy=h;D.prism(q,0,4.2,PASEO_K.iron,PASEO_K.iron);D.prism(rotRect(x,y,.8,.8),4.2,4.6,PASEO_K.iron,PASEO_K.lamp);GLOW.push(x,h+4.4,y);}
          else{TREES.push([x,y,.75+r()*.15,r()]);n++;}}}
      for(let u=12;u<L-6;u+=24){const [x,y]=P(u,0);if(cross(x,y,si))continue;const q=rotRect(x,y,1.6,1.6,Math.atan2(ty,tx));D.dy=E(x,y)+0.124;D.prism(q,0,.6,PASEO_K.planter,PASEO_K.shrub);}}});
  D.dy=0;STREET.paseoTrees=n;}
