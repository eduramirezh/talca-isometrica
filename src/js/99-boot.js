/* =============== boot =============== */
function loop(now){
  if(anim){anim(now);}
  if(ring.visible){const t=((now-(ring.userData.t0||0))%1800)/1800;const s=18+t*38;ring.scale.set(s,s,s);ring.material.opacity=0.85*(1-t);dirty=true;}
  const tr=trainsTick(now);if(tr)dirty=true; // the trains: a frame at TRAIN_FPS while one moves in the view
  // while the camera moves (a gesture, a flight: it moved since the last frame or less than MOVE_MS ago, which on a
  // slow phone is shorter than a frame) the frames leave out the normals pass of crease:'normals' (the creases from depth cost
  // nothing and stay); the first frame after it stops draws them again
  const moving=!!anim||camMoved||now-camT<MOVE_MS;camMoved=false;if(paLite&&!moving)dirty=true;
  if(dirty){const t0=performance.now();ART=PA?paFit(PA):wpp()/DPR;setLod(ART);stripLod(cam);renderer.shadowMap.needsUpdate=shDirty;shDirty=false;
    if(PA){paRender(moving);paLite=moving&&PA.ol>1&&PA.crease==='normals';}else renderer.render(scene,cam);layout();dirty=false;if(tr)trainFrame(now,performance.now()-t0);
    if(!LOAD.frame){LOAD.frame=Math.round(performance.now());LOAD.frameMs=Math.round(LOAD.frame-t0);requestAnimationFrame(t=>{LOAD.shown=Math.round(performance.now());posterOff();});}}
  requestAnimationFrame(loop);
}
// startup times, ms since navigation start (__stats.load): the script runs, the generation starts (boot), the first
// view's part of it ends (gen), the first frame is drawn (frame; frameMs of it in loop(), with the shader compiles and
// the first shadow map) and the frame after it starts (shown: the first one is on screen), and the rest of the
// generation ends (full); plus the navigation's own (the HTML's response, DOMContentLoaded) and three.js
const LOAD={script:Math.round(T_SCRIPT)};
// the poster (src/page.html) gives way to the map once its first frame is on screen; poster: when it was (Chromium)
function posterOff(){const p=$('#poster');if(!p)return;p.style.opacity=0;setTimeout(()=>p.remove(),450);}
function loadTimes(){if(window.__posterT)LOAD.poster=window.__posterT;const n=performance.getEntriesByType?.('navigation')[0],r=performance.getEntriesByType?.('resource')||[];
  if(n){LOAD.html=Math.round(n.responseEnd);LOAD.htmlKB=Math.round((n.transferSize||0)/1024);LOAD.dcl=Math.round(n.domContentLoadedEventEnd);}
  const t=r.find(e=>/three/.test(e.name));if(t){LOAD.three=Math.round(t.responseEnd);LOAD.threeKB=Math.round((t.transferSize||0)/1024);}
  const f=r.filter(e=>/fonts\.(googleapis|gstatic)/.test(e.name));if(f.length)LOAD.fonts=Math.round(Math.max(...f.map(e=>e.responseEnd)));
  return LOAD;}
// The rest of the generation runs after the first frame, in slices of SLICE_MS (SLICE_BUSY while the camera moves) so
// that the map can be moved meanwhile: gen is a generator that yields between pieces of work. A MessageChannel instead
// of setTimeout(0), which the browser stretches to 4 ms after a few in a row.
const SLICE_MS=40,SLICE_BUSY=8;
function sliced(gen,done){const ch=new MessageChannel();let ms=0;
  ch.port1.onmessage=()=>{const t=performance.now(),b=t-camT<300||anim?SLICE_BUSY:SLICE_MS;let r;
    do{r=gen.next();}while(!r.done&&performance.now()-t<b);ms+=performance.now()-t;
    if(r.done){ch.port1.close();done(Math.round(ms),r.value);}else ch.port2.postMessage(0);};
  ch.port2.postMessage(0);}
// the box of the first view (STAGE): the ground under the edges of the screen, plus STAGE_M for the shadows of what
// stands just outside it; and how far from the plaza the city must be laid for it (the farthest of those points plus
// the reach of a lot)
const STAGE_M=150;
function stageBox(){let x0=1e9,y0=1e9,x1=-1e9,y1=-1e9,far=0;
  for(const [px,py] of [[0,0],[W/2,0],[W,0],[0,H/2],[W,H/2],[0,H],[W/2,H],[W,H]]){const g=ground(px,py)||planeAt(px,py);if(!g)continue;
    x0=Math.min(x0,g[0]);x1=Math.max(x1,g[0]);y0=Math.min(y0,g[1]);y1=Math.max(y1,g[1]);far=Math.max(far,Math.hypot(g[0],g[1]));}
  return {box:[x0-STAGE_M,y0-STAGE_M,x1+STAGE_M,y1+STAGE_M],rho:far+STAGE_M+CITY_REACH};}
const split=(a,f)=>{const y=[],n=[];for(const e of a)(f(e)?y:n).push(e);return [y,n];};
// the riparian poplars and willows, after the whole city (they skip its lots), with one rng for all the rivers
function riparian(TR,PO){const r=rng(77);
  // the rivers from OSM: along their real shores (the water side is occupied and skipped), on their islands, and
  // along their axes outside the area; the hand-traced ones along their axes
  for(const k in RIV)for(const ring of RIV[k].flat()){const off0=DATA.widths[k][1]+.5;for(let i=0;i<ring.length;i++){const a=ring[i],b=ring[(i+1)%ring.length];const L=Math.hypot(b[0]-a[0],b[1]-a[1]);if(L<1)continue;const nx=-(b[1]-a[1])/L,ny=(b[0]-a[0])/L;
    for(let u=0;u<L;u+=11)for(const sd of [1,-1]){if(r()<.35)continue;const off=off0+r()*12;const x=a[0]+(b[0]-a[0])*u/L+nx*off*sd,y=a[1]+(b[1]-a[1])*u/L+ny*off*sd;if(occAt(x,y)||nearStreet(x,y,1))continue;(r()<.5?PO:TR).push([x,y,0.8+r()*.6,r()]);}}}
  for(const k in RIV)for(const P of RIV[k])for(const ring of P.slice(1)){let x0=1e9,y0=1e9,x1=-1e9,y1=-1e9;for(const p of ring){x0=Math.min(x0,p[0]);x1=Math.max(x1,p[0]);y0=Math.min(y0,p[1]);y1=Math.max(y1,p[1]);}
    for(let n=(x1-x0)*(y1-y0)/90;n>0;n--){const x=x0+r()*(x1-x0),y=y0+r()*(y1-y0);if(!pip([x,y],ring)||occAt(x,y))continue;(r()<.3?PO:TR).push([x,y,0.8+r()*.6,r()]);}}
  // along the axes outside the areas (a canal: a tree here and there along its service track)
  for(const k in DATA.water){const [w,,canal]=DATA.widths[k],runs=RIV[k]?riverRuns(k):[chaikin(dec(DATA.water[k]),3)];
    for(const pts of runs)for(let i=0;i<pts.length-1;i++){const a=pts[i],b=pts[i+1];const L=Math.hypot(b[0]-a[0],b[1]-a[1]);const nx=-(b[1]-a[1])/L,ny=(b[0]-a[0])/L;
      for(let u=0;u<L;u+=11){for(const sd of [1,-1]){if(r()<(canal?.85:.35))continue;const off=w/2+(w<30?5:18)+r()*14;const x=a[0]+(b[0]-a[0])*u/L+nx*off*sd,y=a[1]+(b[1]-a[1])*u/L+ny*off*sd;if(occAt(x,y)||nearStreet(x,y,1))continue;(r()<.5?PO:TR).push([x,y,0.8+r()*.6,r()]);}}}}}
// meshes that join the scene: everything receives shadows, the casters cast them too (and switch with the others when
// the shadow map is too coarse: CASTERS, fitShadow)
function addMeshes(recv,cast){for(const m of recv){m.traverse(o=>{if(o.isMesh)o.receiveShadow=true;});scene.add(m);}
  for(const m of cast){m.traverse(o=>{if(o.isMesh){o.castShadow=!shOff;o.receiveShadow=true;CASTERS.push(o);}});scene.add(m);}}
// Startup. What the first view needs comes first (STAGE, its box; the city's streets nearer the plaza than rho, in
// CITY_ORDER), then the first frame, then the rest (rest(), in slices). Whatever lies outside the box waits in lists:
// the triangles of the ground layers (L), the land uses, the sidewalks' trees and cars, the city's streets and the
// trees of the blocks that lots from those streets could reach. Each of those pieces depends only on what was laid
// before it in the order of a startup at once (window.__STAGE=0 before the page loads: tools/regress.py --init), and
// that order is kept for every piece that could see another, so the finished map is the same, pixel for pixel.
function boot(){
  const t0=performance.now();LOAD.boot=Math.round(t0);
  loadMsg('Levantando hitos y edificios…');
  buildPanel(); // the panel first: over the poster it is on screen during the generation
  setTimeout(()=>{
    const B=new GB(1<<19),S=new GB(1<<16);
    const TT={};let tl=performance.now();const tm=k=>{const n=performance.now();TT[k]=Math.round(n-tl);tl=n;}; // ms per phase: __stats.t
    riversLevel();riversOcc();linesOcc();tm('rivers');   // level water; no lots or trees in the rivers, the Ruta 5 or the rail
    buildModels(B,S);tm('models');          // records the landmark pads...
    edificiosPlan();tm('edPlan');           // the OSM buildings: those the landmarks leave, cut at the sidewalks, in occ (3)
    usosPlan();tm('usosPlan');              // land uses: their ground in occ, like a landmark
    applyPads();riversRelevel();terrainNormals(); // ...which level the terrain before anything is laid on it
    for(const k in MODELS)MODELS[k].h+=E(MODELS[k].x,MODELS[k].y);
    for(let k=0;k<EN_;k++){EHI=Math.max(EHI,EH[k]);ELO=Math.min(ELO,EH[k]);}SH=null; // the shadow box, with the terrain's heights
    // the first view, on the levelled terrain: the initial one, or the place or tour of the link (the card first:
    // framed() measures it)
    resize();homeView();
    const h=decodeURIComponent(location.hash.slice(1));
    if(h&&BYID[h]){const m=MODELS[h]||BYID[h];select(h,false);view.zoom=4;const f=framed(...lift(m.x,m.y),4);view.tx=f[0];view.ty=f[1];placeCam();}
    else if(h==='justicia'||h==='iconica'){startTour(h);}
    // (window.__STAGE before the page loads, for tools/regress.py --init: 0, everything at once; [x0, y0, x1, y1, rho], another first box)
    let rho=Infinity;const SG=window.__STAGE;if(Array.isArray(SG)){STAGE=SG.slice(0,4);rho=SG[4];}else if(SG!==0){const s=stageBox();STAGE=s.box;rho=s.rho;}
    const L={base:[],water:[],walk:[]};
    tm('pads');scene.add(terrainMesh());tm('terrain');
    const base=buildBase(L);tm('base');const D=new GB(1<<14);walkBase(base,D,L);tm('walk');
    // The first view's meshes are made from what is laid so far (keep: the builders stay), and when the rest is done
    // every builder is tiled again with its second half, its triangles in the order of a startup at once (the runs of
    // GB.grow: B.k, S.k... below), and the meshes in that order too (draw order ties between meshes of a material go
    // by their creation): the first view's meshes give way to those. Only then is the finished map the same, pixel for
    // pixel, as one made at once: two coplanar layers meet in a seam whose pixels the draw order decides
    const first={g:tiled(base,matFlat,true)};const gnd=[base.nv,riverWater.nv],walkV=STREET.walkVerts;scene.add(first.g);
    if(riverWater.nv)scene.add(first.w=tiled(riverWater,matWater,true));
    for(const m of ruta5Objects())scene.add(m); // the Ruta 5's barrier, lamp posts and cars
    tm('r5obj');trainsInit();                           // the trains, on the paths railBase left in RAILP
    // The trees and cars come from many places, and a tile's instances are drawn in the order of their list (ties
    // between overlapping crowns go by it): each source keeps its part here, and the lists are put together in the
    // order of a startup at once (canon())
    const PT={uses:new Map(),blocks:[],alam:new Map(),walks:[],cars:[],yard:[],rip:[],ripP:[]},T0=TREES.length,P0=PO_FIELD.length,UI=new Map(USOS.map((u,i)=>[u,i]));
    const drawUses=(Bx,Sx,UGx,list)=>{for(const u of list){const n=TREES.length,p=PO_FIELD.length;Bx.k=Sx.k=UGx.k=1e7+UI.get(u);usosBase(Bx,Sx,UGx,[u]);PT.uses.set(u,[TREES.slice(n),PO_FIELD.slice(p)]);}};
    const [us1,us2]=split(USOS,u=>boxIn(...u.bb)),UG=new GB(1<<16);drawUses(B,S,UG,us1);
    const F0=TREES.length;usosFringe();PT.fringe=TREES.slice(F0);const uv=[UG.nv];if(UG.nv)scene.add(first.u=tiled(UG,matFlat,true));tm('usosBase'); // land uses: ground, objects and trees
    B.k=2e7;buildCerro(B);const hillTrees=wildTrees();tm('cerro+wild');
    // the city: the streets nearer than rho (B.k, Y.k, Z.k: 3e7 + their place in CITY_ORDER, set by cityGen); the
    // trees of a block, and a stretch of the Alameda (4e7 + its place in ALAM), once every street whose lots can reach
    // it is laid
    const k1=CITY_ORDER.findIndex(si=>CITY_DIST[si]>rho),sts1=k1<0?CITY_ORDER:CITY_ORDER.slice(0,k1),sts2=k1<0?[]:CITY_ORDER.slice(k1);
    const ready=bi=>{const b=blocks[bi].bb;return boxIn(...b)&&Math.max(Math.hypot(b[0],b[1]),Math.hypot(b[2],b[1]),Math.hypot(b[0],b[3]),Math.hypot(b[2],b[3]))+CITY_REACH<=rho;};
    const AL=[...ALAM],[bis1,bis2]=split(blocks.map((b,bi)=>bi),ready),[al1,al2]=split(AL,ready),[wi1,wi2]=split(WALKS.map((w,i)=>i),i=>polyIn(WALKS[i].pts));
    const Y=new GB(1<<18),Z=new GB(1<<17);let nb=0;
    const [ed1,ed2]=split(ED.bks,bk=>boxIn(...bk.bb));
    edificiosBase(B,Z,Y,ed1);tm('edificios'); // ...drawn, with their blocks' ground (2.5e7 + the block: between the Cerro and the city)
    const streetsOf=(Bx,Yx,Zx,sts)=>{const c=cityGen(Bx,Yx,Zx,sts,[]);PT.yard.push(...c.TR);nb+=c.nb;};
    const blocksOf=bis=>{for(const bi of bis)blockTrees(bi,PT.blocks[bi]=[]);};
    const alamOf=(Bx,bis)=>{for(const bi of bis){Bx.k=4e7+AL.indexOf(bi);PT.alam.set(bi,alamedaPark(Bx,[bi]));}};
    const walksOf=wis=>{for(const i of wis){PT.walks[i]=streetTrees([WALKS[i]]);PT.cars[i]=parkedCars([WALKS[i]]);}};
    streetsOf(B,Y,Z,sts1);blocksOf(bis1);
    first.z=tiled(Z,matFlat,true);first.z.traverse(o=>o.castShadow=o.receiveShadow=true);scene.add(first.z);
    alamOf(B,al1);walksOf(wi1);
    const cat=parts=>{const o=[];for(const p of parts)if(p)for(const e of p)o.push(e);return o;};
    const canon=()=>({round:cat([PT.yard,...PT.blocks,...AL.map(bi=>PT.alam.get(bi)),...PT.walks,PT.rip,hillTrees,TREES.slice(0,T0),...USOS.map(u=>(PT.uses.get(u)||[])[0]),PT.fringe]),
      poplar:cat([PT.ripP,PO_FIELD.slice(0,P0),...USOS.map(u=>(PT.uses.get(u)||[])[1])]),cars:cat(PT.cars)});
    const inBox=t=>boxIn(t[0],t[1],t[0],t[1]),C1=canon(),cars=[instCars(C1.cars.filter(inBox))];tm('city');
    const bv=[B.nv],yv=[Y.nv],zv=[Z.nv],trees=[instTrees(C1.round.filter(inBox),'round'),instTrees(C1.poplar.filter(inBox),'poplar')];
    first.b=tiled(B,matBld,true);first.s=tiled(S,matFlat,true);first.d=tiled(D,matFlat,true);
    const cast=[first.b,first.s,...trees,first.d,...cars];
    scene.add(first.y=tiled(Y,matFlat,true));
    // shadows: everything receives them; the buildings, the landmarks (and the Cerro's sanctuary) and the trees cast them
    scene.traverse(o=>{if(o.isMesh&&o!==ring)o.receiveShadow=true;});
    if(cerroMesh)cast.push(cerroMesh);
    for(const m of cast){m.traverse(o=>o.castShadow=o.receiveShadow=true);if(!m.parent)scene.add(m);}
    scene.traverse(o=>{if(o.castShadow)CASTERS.push(o);});SH=null;shOff=false;placeCam(); // what casts shadows, switched off together by fitShadow when far; the shadow box for the first view
    tm('meshes');LOAD.gen=Math.round(performance.now());
    // for tools/screenshot.py --js: centre the camera on a ground point (grid metres), at a zoom (4 = the card's) and azimuth
    window.__home=z=>homeView(z); // the initial view, at another zoom (to choose one: tools/screenshot.py --view)
    window.__look=(x,y,zoom=4,az=view.az)=>{view.az=az;view.zoom=zoom;[view.tx,view.ty]=lift(x,y,az);placeCam();};
    window.__trees=on=>{for(const m of trees)m.visible=on;shDirty=dirty=true;}; // hide the trees to see the ground under them (tools/variants.py)
    window.__cars=on=>{for(const m of cars)m.visible=on;shDirty=dirty=true;}; // the parked cars, likewise
    // for tools/perf.py: the renderer and what a frame depends on (timing each pass, panning, forcing a shadow refit)
    window.__three={renderer,scene,cam,sun,pan,placeCam,fitShadow,get PA(){return PA;}};
    window.__pads=PADS; // the landmark pads [x0,y0,x1,y1,h], for pipeline/traces.py check --pads
    $('#loading').style.opacity=0;setTimeout(()=>$('#loading').hidden=true,500);
    requestAnimationFrame(loop);
    if(STAGE)$('#more').hidden=false;
    // the rest: the same work, outside the box, into builders of its own
    const B2=new GB(1<<19),S2=new GB(1<<15),Y2=new GB(1<<18),Z2=new GB(1<<17),UG2=new GB(1<<16),G2=new GB(1<<20),W2=new GB(1<<14),CH=400;
    // the first view's meshes leave the scene (and CASTERS, LODS, STRIPS); own: their materials go too (trees, cars)
    const drop=(grps,own)=>{const gone=new Set();for(const g of grps){if(!g)continue;scene.remove(g);g.traverse(o=>{if(!o.isMesh)return;gone.add(o);for(const x of o.userData.lod||[o.geometry])x.dispose();});
        if(own&&g.children[0])g.children[0].material.dispose();}
      const keep=a=>{const k=a.filter(o=>!gone.has(o));a.length=0;a.push(...k);};keep(CASTERS);keep(LODS);
      const ks=STRIPS.filter(s=>!gone.has(s.c));STRIPS.length=0;STRIPS.push(...ks);};
    function* rest(){
      for(let i=0;i<L.base.length/2;i+=CH){drapeRest(L.flat,L.base,G2,i,Math.min(L.base.length/2,i+CH));yield;}
      for(let i=0;i<L.water.length/2;i+=CH){drapeRest(L.flatW,L.water,W2,i,Math.min(L.water.length/2,i+CH));yield;}
      const g0=G2.nv;for(let i=0;i<L.walk.length;i++){const [q,y,col,run]=L.walk[i];G2.k=run;drapeQ(G2,q,y,col);if(i%CH===CH-1)yield;}
      STREET.walkVerts=walkV+G2.nv-g0;
      for(const u of us2){drawUses(B2,S2,UG2,[u]);yield;}
      usosDone(uv[0]+UG2.nv);
      for(const bk of ed2){edificiosBase(B2,Z2,Y2,[bk]);yield;} // a block per piece: six were up to 97 ms
      for(let i=0;i<sts2.length;i+=4){streetsOf(B2,Y2,Z2,sts2.slice(i,i+4));yield;}
      for(let i=0;i<bis2.length;i+=40){blocksOf(bis2.slice(i,i+40));yield;}
      alamOf(B2,al2);yield;
      for(let i=0;i<wi2.length;i+=200){walksOf(wi2.slice(i,i+200));yield;}
      riparian(PT.rip,PT.ripP);yield;
      gnd.push(G2.nv,W2.nv);bv.push(B2.nv);yv.push(Y2.nv);zv.push(Z2.nv);
      // the finished meshes, in the order of a startup at once
      // (each a generator that yields between tiles: tiledPartsGen, instTreesGen)
      const fin={g:yield* tiledPartsGen([base,G2],matFlat)};if(riverWater.nv||W2.nv)fin.w=yield* tiledPartsGen([riverWater,W2],matWater);
      if(UG.nv||UG2.nv)fin.u=yield* tiledPartsGen([UG,UG2],matFlat);fin.z=yield* tiledPartsGen([Z,Z2],matFlat);
      const C=canon();yield;fin.c=instCars(C.cars);yield;fin.t=[yield* instTreesGen(C.round,'round'),yield* instTreesGen(C.poplar,'poplar')];
      fin.b=yield* tiledPartsGen([B,B2],matBld);fin.s=yield* tiledPartsGen([S,S2],matFlat);fin.d=yield* tiledPartsGen([D],matFlat);fin.y=yield* tiledPartsGen([Y,Y2],matFlat);yield;
      drop([first.g,first.w,first.u,first.z,first.b,first.s,first.d,first.y]);drop([...trees,...cars],true);
      trees.length=cars.length=0;trees.push(...fin.t);cars.push(fin.c);
      addMeshes([fin.g,fin.w,fin.u,fin.y].filter(Boolean),[fin.z,fin.c,...fin.t,fin.b,fin.s,fin.d]);lodFar=null;return C;}
    setTimeout(()=>sliced(rest(),(ms,C)=>{TT.rest=ms;
      lampPts=lamps();lampPts.visible=night;scene.add(lampPts);STAGE=null;$('#more').hidden=true;shDirty=dirty=true;
      LOAD.full=Math.round(performance.now());
      const sum=a=>a.reduce((s,v)=>s+v,0);CITY.zVerts=sum(zv);
      window.__stats={buildings:nb,lots:LOTS.length-EDS.hulls,verts:sum(bv),yards:sum(yv),ground:sum(gnd),street:STREET,trees:C.round.length,poplars:C.poplar.length,ms:Math.round(performance.now()-t0),t:TT};
      window.__stats.city=CITY;Object.defineProperty(window.__stats,'load',{get:loadTimes,enumerable:true}); // cityGen: barrios, house types, the Z mesh (procedural city)
    }),0);
  },30);
}
window.addEventListener('resize',resize);
if(window.matchMedia)matchMedia('(prefers-color-scheme: dark)').addEventListener?.('change',()=>{dirty=true;});
resize();
setTimeout(boot,30);
})();
