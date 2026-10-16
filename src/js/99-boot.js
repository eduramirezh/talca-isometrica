/* =============== boot =============== */
function loop(now){
  if(anim){anim(now);}
  if(ring.visible){const t=((now-(ring.userData.t0||0))%1800)/1800;const s=18+t*38;ring.scale.set(s,s,s);ring.material.opacity=0.85*(1-t);dirty=true;}
  const tr=trainsTick(now);if(tr)dirty=true; // the trains: a frame at TRAIN_FPS while one moves in the view
  // while the camera moves (a gesture, a flight: it moved since the last frame or less than MOVE_MS ago, which on a
  // slow phone is shorter than a frame) the frames leave out the creases, whose pass costs a third of a frame up close;
  // the first frame after it stops draws them again
  const moving=!!anim||camMoved||now-camT<MOVE_MS;camMoved=false;if(paLite&&!moving)dirty=true;
  if(dirty){const t0=performance.now();ART=PA?paFit(PA):wpp()/DPR;setLod(ART);renderer.shadowMap.needsUpdate=shDirty;shDirty=false;
    if(PA){paRender(moving);paLite=moving&&PA.ol>1;}else renderer.render(scene,cam);layout();dirty=false;if(tr)trainFrame(now,performance.now()-t0);}
  updateReadout();
  requestAnimationFrame(loop);
}
function boot(){
  const t0=performance.now();
  loadMsg('Levantando hitos y edificios…');
  setTimeout(()=>{
    const B=new GB(1<<19),S=new GB(1<<16);
    const TT={};let tl=performance.now();const tm=k=>{const n=performance.now();TT[k]=Math.round(n-tl);tl=n;}; // ms per phase: __stats.t
    riversLevel();riversOcc();linesOcc();tm('rivers');   // level water; no lots or trees in the rivers, the Ruta 5 or the rail
    buildModels(B,S);tm('models');          // records the landmark pads...
    usosPlan();tm('usosPlan');              // land uses: their ground in occ, like a landmark
    applyPads();riversRelevel();terrainNormals(); // ...which level the terrain before anything is laid on it
    for(const k in MODELS)MODELS[k].h+=E(MODELS[k].x,MODELS[k].y);
    for(let k=0;k<EN_;k++){EHI=Math.max(EHI,EH[k]);ELO=Math.min(ELO,EH[k]);}SH=null; // the shadow box, with the terrain's heights
    tm('pads');scene.add(terrainMesh());tm('terrain');
    const base=buildBase();tm('base');const D=new GB(1<<14);walkBase(base,D);tm('walk');scene.add(tiled(base,matFlat));if(riverWater.nv)scene.add(tiled(riverWater,matWater));
    for(const m of ruta5Objects())scene.add(m); // the Ruta 5's barrier, lamp posts and cars
    tm('r5obj');trainsInit();                           // the trains, on the paths railBase left in RAILP
    usosBase(B,S);tm('usosBase');           // land uses: ground, objects and trees
    buildCerro(B);const hillTrees=wildTrees();tm('cerro+wild');
    const Y=new GB(1<<18);const {TR,PO,nb}=cityGen(B,Y);TR.push(...alamedaPark(B),...streetTrees());const cars=instCars(parkedCars());tm('city');
    // riparian poplars/willows
    const rip=[];const r=rng(77);
    // the rivers from OSM: along their real shores (the water side is occupied and skipped), on their islands, and
    // along their axes outside the area; the hand-traced ones along their axes
    for(const k in RIV)for(const ring of RIV[k].flat()){const off0=DATA.widths[k][1]+.5;for(let i=0;i<ring.length;i++){const a=ring[i],b=ring[(i+1)%ring.length];const L=Math.hypot(b[0]-a[0],b[1]-a[1]);if(L<1)continue;const nx=-(b[1]-a[1])/L,ny=(b[0]-a[0])/L;
      for(let u=0;u<L;u+=11)for(const sd of [1,-1]){if(r()<.35)continue;const off=off0+r()*12;const x=a[0]+(b[0]-a[0])*u/L+nx*off*sd,y=a[1]+(b[1]-a[1])*u/L+ny*off*sd;if(occAt(x,y)||nearStreet(x,y,1))continue;(r()<.5?PO:TR).push([x,y,0.8+r()*.6,r()]);}}}
    for(const k in RIV)for(const P of RIV[k])for(const ring of P.slice(1)){let x0=1e9,y0=1e9,x1=-1e9,y1=-1e9;for(const p of ring){x0=Math.min(x0,p[0]);x1=Math.max(x1,p[0]);y0=Math.min(y0,p[1]);y1=Math.max(y1,p[1]);}
      for(let n=(x1-x0)*(y1-y0)/90;n>0;n--){const x=x0+r()*(x1-x0),y=y0+r()*(y1-y0);if(!pip([x,y],ring)||occAt(x,y))continue;(r()<.3?PO:TR).push([x,y,0.8+r()*.6,r()]);}}
    // along the axes outside the areas (a canal: a tree here and there along its service track)
    for(const k in DATA.water){const [w,,canal]=DATA.widths[k],runs=RIV[k]?riverRuns(k):[chaikin(dec(DATA.water[k]),3)];
      for(const pts of runs)for(let i=0;i<pts.length-1;i++){const a=pts[i],b=pts[i+1];const L=Math.hypot(b[0]-a[0],b[1]-a[1]);const nx=-(b[1]-a[1])/L,ny=(b[0]-a[0])/L;
        for(let u=0;u<L;u+=11){for(const sd of [1,-1]){if(r()<(canal?.85:.35))continue;const off=w/2+(w<30?5:18)+r()*14;const x=a[0]+(b[0]-a[0])*u/L+nx*off*sd,y=a[1]+(b[1]-a[1])*u/L+ny*off*sd;if(occAt(x,y)||nearStreet(x,y,1))continue;(r()<.5?PO:TR).push([x,y,0.8+r()*.6,r()]);}}}}
    tm('riparian');const bverts=B.nv,trees=[instTrees(TR.concat(hillTrees,TREES),'round'),instTrees(PO.concat(PO_FIELD),'poplar')],cast=[tiled(B,matBld),tiled(S,matFlat),...trees,tiled(D,matFlat),cars];
    scene.add(tiled(Y,matFlat));
    // shadows: everything receives them; the buildings, the landmarks (and the Cerro's sanctuary) and the trees cast them
    scene.traverse(o=>{if(o.isMesh&&o!==ring)o.receiveShadow=true;});
    if(cerroMesh)cast.push(cerroMesh);
    for(const m of cast){m.traverse(o=>o.castShadow=o.receiveShadow=true);if(!m.parent)scene.add(m);}
    scene.traverse(o=>{if(o.castShadow)CASTERS.push(o);});SH=null;shOff=false; // what casts shadows, switched off together by fitShadow when far
    tm('meshes');lampPts=lamps();scene.add(lampPts);tm('lamps');
    window.__stats={buildings:nb,lots:LOTS.length,verts:bverts,yards:Y.nv,ground:base.nv+riverWater.nv,street:STREET,trees:TR.length+hillTrees.length+TREES.length,poplars:PO.length+PO_FIELD.length,ms:Math.round(performance.now()-t0),t:TT};
    window.__stats.city=CITY; // cityGen: barrios, house types, the Z mesh (procedural city)
    // for tools/screenshot.py --js: centre the camera on a ground point (grid metres), at a zoom (4 = the card's) and azimuth
    window.__look=(x,y,zoom=4,az=view.az)=>{view.az=az;view.zoom=zoom;[view.tx,view.ty]=lift(x,y,az);placeCam();};
    window.__trees=on=>{for(const m of trees)m.visible=on;shDirty=dirty=true;}; // hide the trees to see the ground under them (tools/variants.py)
    window.__cars=on=>{cars.visible=on;shDirty=dirty=true;}; // the parked cars, likewise
    // for tools/perf.py: the renderer and what a frame depends on (timing each pass, panning, forcing a shadow refit)
    window.__three={renderer,scene,cam,sun,pan,placeCam,fitShadow,get PA(){return PA;}};
    window.__pads=PADS; // the landmark pads [x0,y0,x1,y1,h], for pipeline/traces.py check --pads
    buildPanel();resize();
    const h=decodeURIComponent(location.hash.slice(1));
    if(h&&BYID[h]){const m=MODELS[h]||BYID[h];select(h,false);view.zoom=4;const f=framed(...lift(m.x,m.y),4);view.tx=f[0];view.ty=f[1];placeCam();} // card first: framed() measures it
    else if(h==='justicia'||h==='iconica'){startTour(h);}
    $('#loading').style.opacity=0;setTimeout(()=>$('#loading').hidden=true,500);
    requestAnimationFrame(loop);
  },30);
}
window.addEventListener('resize',resize);
if(window.matchMedia)matchMedia('(prefers-color-scheme: dark)').addEventListener?.('change',()=>{dirty=true;});
resize();
setTimeout(boot,30);
})();
