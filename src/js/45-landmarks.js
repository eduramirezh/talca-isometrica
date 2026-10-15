/* =============== landmark models =============== */
const MODELS={}; // id -> {x,y,h}
const GLOW=[]; // extra night lights [x, height, y] (the stadium's masts)
const NOLOTS=[]; // polygons (grid metres) where cityGen places no lots: fenced grounds modelled on their own
const TREES=[]; // round trees a landmark plants where the real ones stand [x, y, scale, seed] (the Parque Río Claro's eucalyptus)
const P2=(p)=>p;
function rotRect(cx,cy,w,d,a=0){const c=Math.cos(a),s=Math.sin(a);return [[-w/2,-d/2],[w/2,-d/2],[w/2,d/2],[-w/2,d/2]].map(([x,y])=>[cx+x*c-y*s,cy+x*s+y*c]);}
function ngon(cx,cy,r,n,a0=0){const o=[];for(let i=0;i<n;i++){const a=a0+i/n*Math.PI*2;o.push([cx+Math.cos(a)*r,cy+Math.sin(a)*r]);}return o;}
function pyramid(B,q,y,h,col){let cx=0,cy=0;q.forEach(p=>{cx+=p[0];cy+=p[1];});cx/=q.length;cy/=q.length;B._c=[cx,-cy];for(let i=0;i<q.length;i++){const a=q[i],b=q[(i+1)%q.length];B.face([[a[0],y,-a[1]],[b[0],y,-b[1]],[cx,y+h,-cy]],null,i%2?shade(col,.9):col);}B._c=null;}
// a landmark's local frame (docs/METODOLOGIA.md §9.2): origin (X, Y) in grid metres, v along angle A (radians from
// +x), u to the right of v. G: (u,v) -> grid metres; V: (u,v,height) -> scene point; N3: a (u,v) direction as a scene
// normal (ny: its vertical part, normalised with it); R: an axis-aligned (u,v) rectangle in grid metres
function localFrame(X,Y,A){const sa=Math.sin(A),ca=Math.cos(A),G=(u,v)=>[X+u*sa+v*ca,Y-u*ca+v*sa],Gs=q=>q.map(p=>G(p[0],p[1]));
  return {G,Gs,V:(u,v,h)=>{const g=G(u,v);return [g[0],h,-g[1]];},
    N3:(nu,nv,ny=0)=>{const L=Math.hypot(nu,nv,ny)||1;return [(nu*sa+nv*ca)/L,ny/L,(nu*ca-nv*sa)/L];},
    R:(u0,v0,u1,v1)=>Gs([[u0,v0],[u1,v0],[u1,v1],[u0,v1]])};}
// façade vocabulary for a landmark drawn on S in frame F (localFrame) with palette K (docs/ESTETICA.md §7). K needs
// tile/tile2 (roof bays), white (copings), glass/glass2 (stained glass) and brick, or gable, for the gable ends
function facade(S,F,K){const {V,N3,R}=F;
  const box=(u0,v0,u1,v1,h0,h1,wall,top,lid=true)=>S.prism(R(u0,v0,u1,v1),h0,h1,wall,top,lid);
  // a wall from (u,v) a to b with outward direction `out`; details are drawn `o` metres in front of it, s runs
  // along the wall from a (so on a wall parallel to u, s is u itself)
  const WL=(a,b,out,o=.06)=>{const L=Math.hypot(b[0]-a[0],b[1]-a[1]),du=(b[0]-a[0])/L,dv=(b[1]-a[1])/L;
    return {L,q:(s,h)=>V(a[0]+du*s+out[0]*o,a[1]+dv*s+out[1]*o,h),n:N3(out[0],out[1])};};
  const WV=(v,sg,o)=>WL([0,v],[1,v],[0,sg],o),WU=(u,sg,o)=>WL([u,0],[u,1],[sg,0],o);
  const rect=(w,s0,s1,h0,h1,col)=>S.face([w.q(s0,h0),w.q(s1,h0),w.q(s1,h1),w.q(s0,h1)],w.n,col);
  // pixel arch: a rectangle under two narrower steps
  const arch=(w,sc,wd,h0,h1,col)=>{const r=wd*.45;rect(w,sc-wd/2,sc+wd/2,h0,h1-r,col);rect(w,sc-wd*.36,sc+wd*.36,h1-r,h1-r*.4,col);rect(w,sc-wd*.18,sc+wd*.18,h1-r*.4,h1,col);};
  // stained glass: leaded bands in two tones
  const glass=(w,sc,wd,h0,h1)=>{const r=wd*.45;for(let h=h0,k=0;h<h1-r-.01;h+=1.5,k++)rect(w,sc-wd/2,sc+wd/2,h,Math.min(h+1.5,h1-r),k%2?K.glass2:K.glass);
    rect(w,sc-wd*.36,sc+wd*.36,h1-r,h1-r*.4,K.glass);rect(w,sc-wd*.18,sc+wd*.18,h1-r*.4,h1,K.glass);};
  // gable roof over s0..s1 (along its ridge) and t0..t1, eaves at h, ridge rh higher; ax 'v': the ridge runs along
  // v. Tiles in bays of two tones; gable ends with a white coping; eaves overhang by half a metre
  const roof=(ax,s0,s1,t0,t1,h,rh,bay,ends=[1,1])=>{const P=(s,t,y)=>ax==='v'?V(t,s,y):V(s,t,y),D=(ds,dt,y)=>ax==='v'?N3(dt,ds,y):N3(ds,dt,y);
    const tm=(t0+t1)/2,hw=(t1-t0)/2,o=.5,dr=o*rh/hw;
    for(let s=s0,k=0;s<s1-1e-6;s+=bay,k++){const e=Math.min(s+bay,s1),c=k%2?K.tile2:K.tile;
      S.face([P(s,t0-o,h-dr),P(e,t0-o,h-dr),P(e,tm,h+rh),P(s,tm,h+rh)],D(0,-rh,hw),c);
      S.face([P(s,t1+o,h-dr),P(e,t1+o,h-dr),P(e,tm,h+rh),P(s,tm,h+rh)],D(0,rh,hw),c);}
    [s0,s1].forEach((s,i)=>{if(!ends[i])return;const sg=i?1:-1,n=D(sg,0,0),f=s+sg*.08;
      S.face([P(s,t0,h),P(s,t1,h),P(s,tm,h+rh)],n,K.gable||K.brick);
      S.face([P(f,t0-o,h-dr-.45),P(f,tm,h+rh-.45),P(f,tm,h+rh+.05),P(f,t0-o,h-dr+.05)],n,K.white);
      S.face([P(f,t1+o,h-dr-.45),P(f,tm,h+rh-.45),P(f,tm,h+rh+.05),P(f,t1+o,h-dr+.05)],n,K.white);});};
  return {box,WL,WV,WU,rect,arch,glass,roof};}
// A road or rail deck on piers, for any bridge (the Río Claro ones, puentes-rio-claro): pts the deck's polyline in grid
// metres, hw half its width, hAt(p) its height along the span (never under the terrain plus 0.3 m), o its parts:
// walk (half the roadway: asphalt, sidewalks and parapets) or deck (a plain top colour) with balus (balustrade in two
// tones), beamD/beamCol the beam under the deck, pier the piers' spacing, lamps, ends (false: no end walls, for a deck that
// runs on into a road on the ground: the Ruta 5's, ruta5Base). K: asph, walk, par, red, metal, lamp,
// old, old2. Marks its footprint in occ and removes the TREES under it. Call it from buildModels (before the city).
function deckBridge(S,K,pts,hw,hAt,o){const sm=[];
    for(let i=0;i<pts.length-1;i++){const a=pts[i],b=pts[i+1],L=Math.hypot(b[0]-a[0],b[1]-a[1]),n=Math.max(1,Math.ceil(L/2.5));
      for(let k=i?1:0;k<=n;k++)sm.push({x:a[0]+(b[0]-a[0])*k/n,y:a[1]+(b[1]-a[1])*k/n,dx:(b[0]-a[0])/L,dy:(b[1]-a[1])/L});}
    let D=0;sm.forEach((p,i)=>{if(i)D+=Math.hypot(p.x-sm[i-1].x,p.y-sm[i-1].y);p.d=D;p.h=Math.max(hAt(p),E(p.x,p.y)+.3);p.nx=-p.dy;p.ny=p.dx;});
    const P=(p,off,dh)=>[p.x+p.nx*off,p.h+dh,-(p.y+p.ny*off)],N=(p,s)=>[p.nx*s,0,-p.ny*s];S.dy=0;
    for(let i=0;i<sm.length-1;i++){const a=sm[i],b=sm[i+1],top=(o0,o1,dh,col)=>S.face([P(a,o0,dh),P(b,o0,dh),P(b,o1,dh),P(a,o1,dh)],[0,1,0],col);
      const side=(off,s,d0,d1,col)=>S.face([P(a,off,d0),P(b,off,d0),P(b,off,d1),P(a,off,d1)],N(a,s),col);
      if(o.walk){top(-o.walk,o.walk,0,K.asph);for(const s of [1,-1]){top(s*o.walk,s*(hw-.25),.15,K.walk);side(s*o.walk,-s,0,.15,K.walk);}}
      else top(-hw+.25,hw-.25,0,o.deck);
      for(const s of [1,-1]){const rail=o.balus?(i%2?K.old2:K.old):K.par;
        side(s*hw,s,-o.beamD,o.walk?.15:0,o.beamCol);side(s*hw,s,o.walk?.15:0,o.walk?1.05:.9,rail);       // beam and the parapet's outer face
        side(s*(hw-.25),-s,o.walk?.15:0,o.walk?1.05:.9,rail);top(s*(hw-.25),s*hw,o.walk?1.05:.9,o.walk?K.par:K.old);}}
    if(o.ends!==false)for(const [p,sg] of [[sm[0],-1],[sm[sm.length-1],1]])S.face([P(p,-hw,-o.beamD),P(p,hw,-o.beamD),P(p,hw,1),P(p,-hw,1)],[p.dx*sg,0,-p.dy*sg],o.beamCol);
    let nextPier=o.pier/2,nextLamp=10,ls=1,nextRed=0;
    for(const p of sm){const g=E(p.x,p.y),a=Math.atan2(p.dy,p.dx);occMark(rotRect(p.x,p.y,3,2*hw+4,a));
      if(p.d>=nextPier){nextPier+=o.pier;if(p.h-g>2.5){
        if(o.walk){for(const s of [1,-1])S.prism(ngon(p.x+p.nx*s*4,p.y+p.ny*s*4,.75,6),g-.5,p.h-o.beamD-.8,o.beamCol,o.beamCol);
          S.prism(rotRect(p.x,p.y,1.4,2*hw-1,a),p.h-o.beamD-.8,p.h-o.beamD,o.beamCol,o.beamCol);}
        else S.prism(rotRect(p.x,p.y,1.2,2*hw-1.5,a),g-.5,p.h-o.beamD,o.beamCol,o.beamCol);}}
      if(o.walk&&p.d>=nextRed){nextRed+=4;for(const s of [1,-1])S.prism(rotRect(p.x+p.nx*s*(hw-.12),p.y+p.ny*s*(hw-.12),.35,.35,a),1.05+p.h,1.35+p.h,K.red,K.red);}
      if(o.lamps&&p.d>=nextLamp){nextLamp+=35;ls=-ls;const ox=p.x+p.nx*ls*(hw-.6),oy=p.y+p.ny*ls*(hw-.6);
        S.prism(rotRect(ox,oy,.3,.3,a),p.h+1.05,p.h+8,K.metal,K.metal);S.prism(rotRect(ox-p.nx*ls*1,oy-p.ny*ls*1,.25,2.2,a),p.h+7.8,p.h+8.05,K.metal,K.metal);
        const hx=ox-p.nx*ls*2,hy=oy-p.ny*ls*2;S.prism(rotRect(hx,hy,.6,.8,a),p.h+7.55,p.h+7.85,K.metal,K.lamp);GLOW.push(hx,p.h+7.4,hy);}}
    // no tree of the park's wood under or through the deck
    for(let i=TREES.length-1;i>=0;i--){const t=TREES[i];if(sm.some(p=>Math.hypot(t[0]-p.x,t[1]-p.y)<hw+5))TREES.splice(i,1);}}
function buildModels(B,S){ // S: models drawn without the window shader
  const C=hex;
  const at=id=>BYID[id];
  // reserve the footprint and stand the model on the ground: landmarks get a levelled pad (pad=true),
  // campus buildings just sit on their lowest corner
  const reserve=(x,y,w,d,pad=true)=>{rectOcc(x,y,w,d);B.dy=pad?padAt(x-w/2,y-d/2,x+w/2,y+d/2):groundMin(rotRect(x,y,w,d));};
  let p;
  /*HITOS*/
  // ==== fin de los hitos ====
  B.dy=0;S.dy=0;
}

