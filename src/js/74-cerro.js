function buildCerro(B){ // Cerro La Virgen: the hill is real terrain now; the statue stands at the sanctuary
  // The sanctuary on the hill's eastern shoulder, ~165 m above the plaza, drawn on its own builder without the window
  // shader (added to the scene here; S is not in scope). Plan from OpenStreetMap (statue node "Virgen Maria",
  // monument node "Virgen del Carmen", the sanctuary's area w203379398, viewpoint) and the Esri imagery: a paved
  // square with the statue on a stepped platform; north of it a gravel esplanade with rows of stone benches facing an
  // open-air stone chapel on its west side, flanked by arched walls, with a bell gable and an iron cross; a walk comes
  // up from the parking loop to the south. Frame localFrame(-3401, 118, 0): v east (toward the city, where the Virgin
  // looks), u south. Heights and colours from photos on Wikimedia Commons (2024-10 and 2025-04, CC0), measured
  // against the pedestal's shaft (~2.7 m wide): three steps of 0.25 m, a base of 1.3 m and a shaft of 3.4 m in dark
  // stone covered with white votive plaques; the white Virgin with the Child, ~4.8 m, her right arm raised with a
  // rosary; the chapel ~7 × 9.5 m, eaves 4.8 m, ridge 7 m, bell gable 9.4 m plus the cross. Approximate: the
  // terraces' outline and the chapel's depth (trees hide them in the imagery), the number of benches. The terrain is
  // built before buildCerro runs, so padAt can't level it: the terraces are platforms on the slope with stone
  // retaining walls, as the real ones are. No night glow (no source that the statue is lit).
  const S=new GB(1<<14),C=hex;
  const F=localFrame(-3401,118,0),{G,Gs,R}=F;
  const K={stone:C('#6E7068'),stone2:C('#5E605A'),plaque:C('#E2DED3'),plaque2:C('#C9C5BA'),white:C('#ECE7DC'),whiteSh:C('#D3CDC0'),
    paving:C('#CFC9BB'),step:C('#D9D3C5'),step2:C('#C6BFAF'),gravel:C('#BDB3A0'),bench:C('#D3CDC0'),bench2:C('#B3AD9F'),
    wall:C('#8A8373'),chapel:C('#7D8173'),chapel2:C('#6C7064'),tile:C('#5E5148'),tile2:C('#524640'),grille:C('#3F5049'),
    bell:C('#2E2C2B'),iron:C('#3A3A3A'),pole:C('#8A8A86'),red:C('#C8352B'),blue:C('#2D4E9A'),flagW:C('#F0EDE6'),rosary:C('#4A3A30')};
  // façade vocabulary; the roof's gable copings in the chapel's darker stone
  const {box,WL,WV,rect,arch,roof}=facade(S,F,{tile:K.tile,tile2:K.tile2,white:K.chapel2,gable:K.chapel});
  // a terrace: flat top just above the highest ground under it, retaining walls down into the slope
  const terrace=(u0,v0,u1,v1,top)=>{let hi=-1e9,lo=1e9;
    for(let a=0;a<=6;a++)for(let b=0;b<=6;b++){const g=G(u0+(u1-u0)*a/6,v0+(v1-v0)*b/6),e=E(g[0],g[1]);hi=Math.max(hi,e);lo=Math.min(lo,e);}
    const q=R(u0,v0,u1,v1);S.dy=0;S.prism(q,lo-2,hi+.2,K.wall,top);occMark(q);return hi+.2;};
  const faces=(u0,v0,u1,v1,o)=>[[[u0,v1],[u1,v1],[0,1]],[[u1,v1],[u1,v0],[1,0]],[[u1,v0],[u0,v0],[0,-1]],[[u0,v0],[u0,v1],[-1,0]]].map(([a,b,out])=>WL(a,b,out,o));
  // the statue's square, and the esplanade with the chapel to the north of it (it stands higher: the ground rises)
  const h1=terrace(-8,-8,15,15,K.paving),h2=terrace(-26.5,-12,-8,22,K.gravel);
  // ---- the monument, on the square ----
  S.dy=h1;
  box(-5.5,-5.5,5.5,5.5,0,.25,K.step2,K.step);box(-4.8,-4.8,4.8,4.8,.25,.5,K.step2,K.step2);box(-4.1,-4.1,4.1,4.1,.5,.75,K.step2,K.step);
  // pedestal: base, cap, shaft, cornice in dark stone; votive plaques in two tones over every face, the decree's
  // inscription (a large white slab) on the front
  box(-2.1,-2.1,2.1,2.1,.75,2.05,K.stone,K.stone);box(-2.25,-2.25,2.25,2.25,2.05,2.25,K.stone2,K.stone);
  box(-1.35,-1.35,1.35,1.35,2.25,5.1,K.stone,K.stone);box(-1.55,-1.55,1.55,1.55,5.1,5.45,K.stone2,K.stone2);
  for(const w of faces(-2.1,-2.1,2.1,2.1,.06))for(let r=0;r<2;r++)for(let c=0;c<6;c++){const s=.15+c*.65+(r%2)*.3;if(s+.55>w.L-.1)continue;rect(w,s,s+.55,.95+r*.5,1.35+r*.5,(r+c)%2?K.plaque2:K.plaque);}
  for(const w of faces(-1.35,-1.35,1.35,1.35,.06))for(let r=0;r<4;r++)for(let c=0;c<4;c++){const s=.12+c*.64+(r%2)*.2;if(s+.52>w.L-.08)continue;rect(w,s,s+.52,2.5+r*.6,2.95+r*.6,(r+c)%2?K.plaque2:K.plaque);}
  rect(WV(1.35,1,.12),-.6,.6,3,4.5,K.white);
  // the Virgin, facing the city: a cloud, the robe in two stepped stages, torso, shoulders and veil, head; her right
  // arm (+u) raised in three steps with the rosary hanging from the hand; the Child on her left arm, arms out
  const H=5.45,ring=(r,h0,h1,col)=>S.prism(ngon(...G(0,0),r,8,Math.PI/8),H+h0,H+h1,col,col);
  ring(.95,0,.35,K.whiteSh);ring(.8,.35,1.7,K.white);ring(.68,1.7,2.9,K.whiteSh);
  box(-.55,-.35,.55,.35,H+2.9,H+3.55,K.white,K.white);box(-.65,-.42,.65,.36,H+3.5,H+3.9,K.whiteSh,K.whiteSh);
  box(-.34,-.4,.34,.26,H+3.9,H+4.45,K.white,K.white);
  box(.5,-.2,.95,.25,H+3.4,H+3.95,K.white,K.white);box(.75,-.2,1.2,.25,H+3.9,H+4.35,K.whiteSh,K.whiteSh);box(.95,-.2,1.42,.25,H+4.3,H+4.85,K.white,K.white);
  box(1.12,.25,1.47,.6,H+2.9,H+4.75,K.rosary,K.rosary);
  box(-1.05,-.1,-.35,.55,H+2.6,H+3.4,K.white,K.white);box(-.9,.02,-.5,.45,H+3.4,H+3.8,K.whiteSh,K.whiteSh);box(-1.65,.1,-.9,.5,H+3.15,H+3.55,K.white,K.white);
  // two Chilean flags flanking the monument
  for(const u of [-4.6,4.6]){box(u-.2,4.8,u+.2,5.2,0,8.2,K.pole,K.pole);const sg=Math.sign(u);
    box(Math.min(u,u+sg*2.1),4.95,Math.max(u,u+sg*2.1),5.05,7.1,7.8,K.red,K.red);
    box(Math.min(u,u+sg*.7),4.95,Math.max(u,u+sg*.7),5.05,7.8,8.5,K.blue,K.blue);
    box(Math.min(u+sg*.7,u+sg*2.1),4.95,Math.max(u+sg*.7,u+sg*2.1),5.05,7.8,8.5,K.flagW,K.flagW);}
  // ---- the open-air chapel and its esplanade ----
  S.dy=h2;
  // stone benches in four blocks of eleven rows, facing the chapel
  for(const [u0,u1] of [[-22,-19.4],[-18.9,-16.3],[-14.7,-12.1],[-11.6,-9]])for(let k=0;k<11;k++){const v=1.5+k*1.75;box(u0,v,u1,v+.6,0,.55,K.bench2,K.bench);}
  // the chapel: stone walls, a dark tiled gable roof running east-west, the front (east) with an arched iron grille
  // in a darker stone frame
  box(-20.5,-10.5,-13.5,-1,0,4.8,K.chapel,K.chapel,false);roof('v',-10.5,-1,-20.5,-13.5,4.8,2.2,3.2);
  for(const w of [WV(-1,1),WV(-10.5,-1)])rect(w,-20.5,-13.5,0,.6,K.chapel2);
  arch(WV(-1,1,.06),-17,3.8,0,4.2,K.chapel2);arch(WV(-1,1,.12),-17,3,0,3.8,K.grille);
  // bell gable south of the front: two arched openings, a small pyramid roof and the cross
  box(-13.5,-4.4,-10.3,-1.3,0,9.4,K.chapel2,K.chapel2);pyramid(S,R(-13.75,-4.65,-10.05,-1.05),9.4,1.1,K.tile);
  for(const [v,sg] of [[-1.3,1],[-4.4,-1]])for(const s of [-12.55,-11.25])arch(WV(v,sg),s,.75,7,8.7,K.bell);
  box(-12.1,-3.05,-11.7,-2.65,10.2,12.1,K.iron,K.iron);box(-12.6,-3.05,-11.2,-2.65,11.2,11.6,K.iron,K.iron);
  // arched walls on both sides of the chapel: piers, a beam, and pixel arches stepped into the openings
  const arcade=(piers,u0,u1)=>{box(u0,-2.6,u1,-2,3.4,4.4,K.chapel,K.chapel2);
    for(let i=0;i<piers.length;i++){const [a,b]=piers[i];box(a,-2.6,b,-2,0,3.4,K.chapel,K.chapel);
      if(i<piers.length-1){const c=piers[i+1][0];box(b,-2.6,b+.45,-2,2.7,3.4,K.chapel,K.chapel);box(c-.45,-2.6,c,-2,2.7,3.4,K.chapel,K.chapel);
        box(b+.45,-2.6,b+.9,-2,3.05,3.4,K.chapel,K.chapel);box(c-.9,-2.6,c-.45,-2,3.05,3.4,K.chapel,K.chapel);}}};
  arcade([[-10.3,-9.6],[-7.8,-7.1],[-5.3,-4.6]],-10.3,-4.6);arcade([[-21.5,-20.5],[-25.3,-24.3]].reverse(),-25.3,-20.5);
  // ---- the walk up from the parking loop, in steps that follow the slope ----
  {const a=[15,3],b=[47,-8],L=Math.hypot(b[0]-a[0],b[1]-a[1]),du=(b[0]-a[0])/L,dv=(b[1]-a[1])/L,n=6;S.dy=0;
    for(let i=0;i<n;i++){const p0=[a[0]+du*L*i/n,a[1]+dv*L*i/n],p1=[a[0]+du*L*(i+1)/n,a[1]+dv*L*(i+1)/n];
      const q=Gs([[p0[0]-dv*1.2,p0[1]+du*1.2],[p1[0]-dv*1.2,p1[1]+du*1.2],[p1[0]+dv*1.2,p1[1]-du*1.2],[p0[0]+dv*1.2,p0[1]-du*1.2]]);
      const es=q.map(p=>E(p[0],p[1]));S.prism(q,Math.min(...es)-1.5,Math.max(...es)+.12,K.step2,i%2?K.step:K.paving);}}
  S.dy=0;cerroMesh=new T.Mesh(S.geo(),matFlat);scene.add(cerroMesh);
  const c=G(0,0);MODELS['cerro-la-virgen']={x:c[0],y:c[1],h:h1+12};
}
// scrub and wood on steep ground and where CONAF says there is (wildAt), in clumps; the plantations of eucalyptus or pine
// (cobTall) as columns, in T0.p
function wildTrees(){
  const r=rng(5),T0=[],P0=[];const n=(x,y)=>0.5+0.5*Math.sin(x*0.011+y*0.017)*Math.cos(x*0.006-y*0.009+1.3);
  for(let x=XMIN;x<XMAX;x+=13)for(let y=YMIN;y<YMAX;y+=13){if(!CM[cellOf(x,y)])continue;const w=wildAt(x,y);if(w<0.15)continue;
    if(r()>w*0.55*(0.25+n(x,y)))continue;const tx=x+r()*12,ty=y+r()*12;if(blockAt(tx,ty)>=0||nearStreet(tx,ty,2)||occAt(tx,ty))continue;(cobTall(tx,ty)?P0:T0).push([tx,ty,0.8+r()*.7,r()]);}
  T0.p=P0;return T0;
}

