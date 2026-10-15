/* =============== trains =============== */
// A train on each line (docs/PLAN-TREN.md 2.4-2.5), moving on the paths railBase leaves in RAILP: every car sits at
// its own s (the head's minus the cars before it), at the railhead's height h, and turns with the tangent between
// its two bogies, so it follows the curves and the 1:16 ramps of the underpasses. What runs through Talca today,
// from the photos on Wikimedia Commons (docs/FUENTES.md):
//  - sfb: the EFE railcar of the Santiago-Chillán service (the bimodal SFB-3000, photos of 2024 under the station's
//    shed): white body, a dark band of windows, a red roof band that comes down over the cab, a blue line under the
//    windows, a grey stepped nose. Three cars (cab, trailer, cab), as the units in the photos;
//  - adm: the Buscarril of the ramal a Constitución (Ferrostaal ADM 255, photos of 2019 and 2024): two short cars on
//    metre gauge, teal upper body and roof, a yellow band at the waist, cream below, a rounded teal cab with a yellow
//    front;
//  - carga: a timber train like the one under the shed in a photo of 2017 (stake wagons loaded with logs). Its
//    locomotive is not in any photo: a generic hood unit in the yellow and blue of EFE's classic scheme (photo of
//    2014 of such a locomotive, not in Talca).
// Lengths and heights from the types where known (SFB cars ~24-26 m, 3 m wide, ~4.2 m over the rail; ADM cars
// ~16 m, 2.6 m wide, 3.6 m high), the rest approximate; the models are stepped volumes in two tones with dark
// windows >= 0.45 m high, nothing under 0.4 m (ESTETICA §2-§3). The windows are a mesh of their own (matTrainWin) so
// that they can glow at night; the cars do not use winMat(), whose windows are anchored to the world and would slide
// over a moving body.
// Timetable (trainsTick), fictional but plausible: on the Línea Central the sfb enters from the north, slows down
// (0.5 m/s²), stops 25 s under the shed (s 6148-6272, centred at 6210) and leaves by the south; a freight follows it
// 2 min later without stopping; then both come back from the south, and so on (one direction at a time on the single
// track, 30 s between the last train out and the next one in). On the ramal the Buscarril waits 40 s at the open
// platform (its west face, s 24 on), goes out by the south edge, waits 40 s outside and comes back. Off the terrain
// a car is hidden. With prefers-reduced-motion the trains stand at the station and nothing moves.
// Rendering: loop() ticks the trains every frame (positions only) and draws at TRAIN_FPS while a moving train is in
// the view (a frustum test on each car's sphere, plus one frame when it leaves); out of view only s advances. The
// low-resolution image is anchored to the grid, so a train advances by whole art pixels, as in a game: no smoothing.
// The cars cast shadows. At night the leading car's headlight is a point of the lamps' glow (TRAIN.pts, hidden in
// the normals pass like the street lamps) and the windows glow through matTrainWin's emissive.
// For tools/screenshot.py --js: window.__train(line, s, kind, dir) holds the timetable and leaves one train with its
// head at s (returns [x, y] of its middle, for __look); __train(null) resumes. window.__trains() reports the state.
const TRAIN={list:[],geo:{},pts:null,hold:false,last:0,drawn:0,lines:{},reduced:matchMedia('(prefers-reduced-motion: reduce)').matches};
const TRAIN_FPS=18,TRAIN_GAP=0.6;
const matTrain=new T.MeshLambertMaterial({vertexColors:true});
const matTrainWin=new T.MeshLambertMaterial({vertexColors:true});
// a car's geometry: kind, nose (+1: the cab at +x, -1 at -x, 0: none), cached. Local frame: x along the track
// (toward growing s), y up from the railhead, z across (three.js' z). Returns {body, win, len, bd: bogie spacing}.
function trainCar(kind,nose){const key=kind+nose;if(TRAIN.geo[key])return TRAIN.geo[key];
  const G=new GB(1<<10),Wn=new GB(1<<8),C=hex;
  const bx=(x0,x1,z0,z1,y0,y1,side,top,lid=true)=>{if(x0>x1)[x0,x1]=[x1,x0];G.prism([[x0,-z0],[x1,-z0],[x1,-z1],[x0,-z1]],Math.max(y0,.32),y1,side,top,lid);};
  // a face parallel to a side (at z, facing sg) or to an end (at x, facing sg), 6 cm off the wall like a landmark's
  const strip=(B,x0,x1,y0,y1,z,sg,col)=>B.face([[x0,y0,z],[x1,y0,z],[x1,y1,z],[x0,y1,z]],[0,0,sg],col);
  const front=(B,x,z0,z1,y0,y1,sg,col)=>B.face([[x,y0,z0],[x,y0,z1],[x,y1,z1],[x,y1,z0]],[sg,0,0],col);
  const bogies=(hw,h0,h1,col,span)=>{for(const sg of [1,-1])bx(sg*span-1.3,sg*span+1.3,-hw,hw,h0,h1,col,col);};
  let len,bd,w;
  if(kind==='sfb'){const K={white:C('#E8E6E1'),white2:C('#D5D3CE'),red:C('#C8372D'),red2:C('#B32F27'),blue:C('#2F62B6'),win:C('#2C3540'),
      grey:C('#9EA2A6'),grey2:C('#8A8E92'),dark:C('#3A3C3F')};
    const L=nose?23.6:24;len=L+(nose?2.4:0);bd=L-8;w=3;
    bogies(1.2,.35,.9,K.dark,L/2-4);bx(-L/2+.3,L/2-.3,-1.4,1.4,.9,1.25,K.dark,K.dark);
    bx(-L/2,L/2,-1.5,1.5,1.25,3.6,K.white,K.white2);
    bx(-L/2+.2,L/2-.2,-1.3,1.3,3.6,4.1,K.red,K.white2);bx(-L/2+3,L/2-3,-.9,.9,4.1,4.35,K.white2,K.white2);
    for(const sg of [1,-1]){strip(G,-L/2,L/2,1.5,1.95,sg*1.56,sg,K.blue);
      strip(Wn,-L/2+(nose<0?3:1.5),L/2-(nose>0?3:1.5),2.3,3.3,sg*1.56,sg,K.win);}
    if(nose){const f=nose,X=d=>f*(L/2+d); // the cab and the stepped nose, red over grey, the windscreen
      bx(X(0),X(1.6),-1.4,1.4,1.25,3.5,K.grey,K.red);bx(X(1.6),X(2.4),-1.1,1.1,1.4,3.0,K.grey2,K.red2);
      bx(X(-.18),X(1.4),-1.3,1.3,3.5,4.0,K.red,K.red2);
      front(Wn,X(2.46),-.9,.9,2.1,2.9,f,K.win);
      for(const sg of [1,-1])strip(Wn,X(-.2),X(1.4),2.3,3.2,sg*1.46,sg,K.win);}}
  else if(kind==='adm'){const K={teal:C('#2A8C8E'),teal2:C('#227679'),yellow:C('#E2B13A'),cream:C('#E9E3D3'),win:C('#2C3540'),dark:C('#3A3C3F')};
    const L=16;len=L+.8;bd=L-6;w=2.6;
    bogies(.9,.35,.75,K.dark,L/2-3);bx(-L/2+.2,L/2-.2,-1.2,1.2,.75,1.05,K.dark,K.dark);
    bx(-L/2,L/2,-1.3,1.3,1.05,2.05,K.cream,K.cream,false);bx(-L/2,L/2,-1.3,1.3,2.05,2.5,K.yellow,K.yellow,false);
    bx(-L/2,L/2,-1.3,1.3,2.5,3.35,K.teal,K.teal2);bx(-L/2+.3,L/2-.3,-1,1,3.35,3.6,K.teal2,K.teal2);
    for(const sg of [1,-1])strip(Wn,-L/2+1.2,L/2-1.2,2.6,3.25,sg*1.36,sg,K.win);
    const f=nose,X=d=>f*(L/2+d); // the rounded cab: a shorter block, a yellow front under the windscreen
    bx(X(0),X(.8),-1.1,1.1,1.05,3.3,K.teal,K.teal2);front(G,X(.86),-.9,.9,1.5,2.4,f,K.yellow);front(Wn,X(.86),-.8,.8,2.5,3.1,f,K.win);}
  else if(kind==='loco'){const K={yellow:C('#D9B33C'),yellow2:C('#C9A535'),blue:C('#24406B'),win:C('#2C3540'),dark:C('#3A3C3F')};
    const L=18;len=L;bd=L-6;w=3;const f=nose||1,X=d=>f*d; // the long hood behind the cab, the cab, a short nose
    bogies(1.25,.35,1,K.dark,L/2-3.5);bx(-L/2+.2,L/2-.2,-1.45,1.45,1,1.7,K.blue,K.blue);
    bx(X(-L/2+.8),X(L/2-4.6),-1.1,1.1,1.7,3.9,K.yellow,K.yellow2);bx(X(-L/2+1.5),X(L/2-5.5),-.7,.7,3.9,4.2,K.yellow2,K.yellow2);
    bx(X(L/2-4.6),X(L/2-1.4),-1.4,1.4,1.7,4.2,K.yellow,K.yellow2);bx(X(L/2-1.4),X(L/2-.2),-1.3,1.3,1.7,2.9,K.yellow,K.yellow2);
    for(const sg of [1,-1]){strip(G,X(-L/2+.8),X(L/2-1.4),2.3,2.75,sg*1.46,sg,K.blue);strip(Wn,X(L/2-4.2),X(L/2-1.8),3.1,3.8,sg*1.46,sg,K.win);}
    front(Wn,X(L/2-1.34),-1,1,3.1,3.8,f,K.win);}
  else{const K={dark:C('#4A4744'),dark2:C('#3A3835'),log:C('#A8896A'),log2:C('#8F7257'),log3:C('#B9987A')}; // a stake wagon with logs
    const L=15;len=L;bd=L-5;w=2.8;
    bogies(1.1,.35,.85,K.dark2,L/2-2.8);bx(-L/2,L/2,-1.4,1.4,.85,1.35,K.dark,K.dark);
    for(let k=0;k<4;k++){const x=-L/2+1.2+k*(L-2.4)/3;for(const sg of [1,-1])bx(x-.25,x+.25,sg*1.1,sg*1.55,1.35,3.5,K.dark2,K.dark2);}
    bx(-L/2+.7,L/2-.7,-1.1,1.1,1.35,2.3,K.log,K.log2);bx(-L/2+.9,L/2-.9,-.85,.85,2.3,3.05,K.log2,K.log3);bx(-L/2+1.3,L/2-1.3,-.5,.5,3.05,3.5,K.log,K.log2);}
  return TRAIN.geo[key]={body:G.geo(),win:Wn.geo(),len,bd,w};}
// the point of a line's path at s (metres along it); beyond the ends, straight on along the end's direction
function railAt(P,s){const S=P.s,n=S.length;
  if(s<=0||s>=S[n-1]){const i=s<=0?0:n-1,j=s<=0?Math.min(n-1,8):Math.max(0,n-9),d=s<=0?-s:s-S[n-1],L=Math.hypot(P.x[i]-P.x[j],P.y[i]-P.y[j])||1;
    return {x:P.x[i]+(P.x[i]-P.x[j])/L*d,y:P.y[i]+(P.y[i]-P.y[j])/L*d,h:P.h[i]};}
  let lo=0,hi=n-1;while(hi-lo>1){const m=(lo+hi)>>1;if(S[m]<=s)lo=m;else hi=m;}
  const t=(s-S[lo])/((S[hi]-S[lo])||1);return {x:P.x[lo]+(P.x[hi]-P.x[lo])*t,y:P.y[lo]+(P.y[hi]-P.y[lo])*t,h:P.h[lo]+(P.h[hi]-P.h[lo])*t};}
// a train: its cars from head to tail on a line, dir (+1 toward growing s), s (the head's). trainTurn reverses it:
// in place (the Buscarril at its platform: the cars' order flips, the head moves to the other end) or off the map
// (the rake comes back the other way, the cabs facing forward: the noses flip, the order stays, so the locomotive
// still leads). trainPlace puts each car on the path, hidden when it is off the terrain, and moves the headlight.
function makeTrain(line,kind,kinds){const grp=new T.Group(),cars=kinds.map(([k,nose])=>{const c={kind:k,nose,obj:new T.Group()};
    c.body=new T.Mesh(undefined,matTrain);c.win=new T.Mesh(undefined,matTrainWin);c.obj.add(c.body,c.win);
    for(const m of [c.body,c.win])m.castShadow=m.receiveShadow=true;grp.add(c.obj);return c;});
  const t={line,kind,cars,grp,dir:1,s:0,v:0,run:null,shown:false,inView:false,mid:[0,0]};trainGeo(t);grp.visible=false;TRAIN.list.push(t);return t;}
function trainGeo(t){t.len=0;for(const c of t.cars){const g=trainCar(c.kind,c.nose);c.body.geometry=g.body;c.win.geometry=g.win;c.len=g.len;c.bd=g.bd;c.off=t.len;t.len+=g.len+TRAIN_GAP;}t.len-=TRAIN_GAP;}
function trainTurn(t,inPlace){if(inPlace){t.s-=t.dir*t.len;t.cars.reverse();}else for(const c of t.cars)c.nose=-c.nose;t.dir=-t.dir;trainGeo(t);}
function trainPlace(t){const P=RAILP[t.line],L=P.s[P.s.length-1];let any=false,mx=0,my=0;
  for(const c of t.cars){const sc=t.s-t.dir*(c.off+c.len/2),a=railAt(P,sc-c.bd/2),b=railAt(P,sc+c.bd/2),dx=b.x-a.x,dy=b.y-a.y,D=Math.hypot(dx,dy)||1;
    const x=(a.x+b.x)/2,y=(a.y+b.y)/2;c.obj.position.set(x,(a.h+b.h)/2,-y);c.obj.rotation.set(0,Math.atan2(dy,dx),Math.atan2(b.h-a.h,D),'YZX');
    c.obj.visible=sc>=0&&sc<=L&&inTerrain(x,y);any=any||c.obj.visible;mx+=x/t.cars.length;my+=y/t.cars.length;}
  t.grp.visible=any;t.mid=[mx,my];trainLight(t);}
function trainLight(t){if(!TRAIN.pts)return;const i=TRAIN.list.indexOf(t),A=TRAIN.pts.geometry.attributes.position,c=t.cars[0];
  if(t.grp.visible&&c.obj.visible){const h=railAt(RAILP[t.line],t.s+t.dir*.3);A.setXYZ(i,h.x,h.h+(c.kind==='adm'?2:c.kind==='loco'?3.3:1.9),-h.y);}
  else A.setXYZ(i,0,-500,0);A.needsUpdate=true;}
function trainHide(t){t.grp.visible=false;trainLight(t);}
// the trains and each line's timetable: runs {t, dir, from: the head's s on entry or 'park' (turn where it stands),
// stops [[the head's s, seconds]], to: the head's s on exit (hidden) or, with park, where it stays; after: seconds
// since the line was cleared, or since the previous run started when it goes the same way}
function trainsInit(){if(!RAILP.main||!RAILP.ramal)return;const t0=performance.now();
  const sfb=makeTrain('main','sfb',[['sfb',1],['sfb',0],['sfb',-1]]),adm=makeTrain('ramal','adm',[['adm',1],['adm',-1]]),
    carga=makeTrain('main','carga',[['loco',1],['wagon',0],['wagon',0],['wagon',0],['wagon',0],['wagon',0],['wagon',0]]);
  const LM=RAILP.main.s[RAILP.main.s.length-1],LR=RAILP.ramal.s[RAILP.ramal.s.length-1],ST=6210,PLAT=24;
  TRAIN.lines.main={i:0,t:0,live:0,clearAt:0,startAt:0,runs:[
    {t:sfb,dir:1,from:-5,stops:[[ST+sfb.len/2,25]],to:LM+sfb.len+5,vmax:28,acc:.5,after:0},
    {t:carga,dir:1,from:-5,stops:[],to:LM+carga.len+5,vmax:18,acc:.3,after:120},
    {t:sfb,dir:-1,from:LM+5,stops:[[ST-sfb.len/2,25]],to:-sfb.len-5,vmax:28,acc:.5,after:30},
    {t:carga,dir:-1,from:LM+5,stops:[],to:-carga.len-5,vmax:18,acc:.3,after:120}]};
  TRAIN.lines.ramal={i:0,t:0,live:0,clearAt:0,startAt:0,runs:[
    {t:adm,dir:1,from:'park',stops:[],to:LR+adm.len+5,vmax:14,acc:.4,after:40},
    {t:adm,dir:-1,from:LR+5,stops:[],to:PLAT,park:true,vmax:14,acc:.4,after:40}]};
  // the Buscarril starts parked at the platform; with reduced motion the sfb also stands under the shed
  adm.s=PLAT+adm.len;if(TRAIN.reduced)sfb.s=ST+sfb.len/2;
  const g=new T.BufferGeometry();g.setAttribute('position',new T.Float32BufferAttribute(new Float32Array(TRAIN.list.length*3),3));
  TRAIN.pts=new T.Points(g,glowMat());TRAIN.pts.visible=false;TRAIN.pts.frustumCulled=false;GLOWPTS.push(TRAIN.pts);scene.add(TRAIN.pts);
  for(const t of TRAIN.list){scene.add(t.grp);trainPlace(t);}
  if(!TRAIN.reduced){trainHide(sfb);trainHide(carga);}
  let verts=0,cars=0;for(const k in TRAIN.geo){verts+=TRAIN.geo[k].body.attributes.position.count+TRAIN.geo[k].win.attributes.position.count;}
  for(const t of TRAIN.list)cars+=t.cars.length;STREET.trains={cars,verts,ms:Math.round(performance.now()-t0)};
  window.__train=(line,s,kind,dir=1)=>{if(line==null){TRAIN.hold=false;for(const t of TRAIN.list)if(t.run||t===adm)trainPlace(t);dirty=true;return null;}
    TRAIN.hold=true;const t=TRAIN.list.find(t=>t.line===line&&(kind?t.kind===kind:true));if(!t)return null;
    for(const o of TRAIN.list)if(o!==t)trainHide(o);
    if(t.dir!==dir)trainTurn(t,false);t.s=s;t.v=0;trainPlace(t);dirty=true;return t.mid;};
  window.__trains=()=>TRAIN.list.map(t=>({line:t.line,kind:t.kind,dir:t.dir,s:Math.round(t.s),v:Math.round(t.v),len:Math.round(t.len),
    run:!!t.run,shown:t.grp.visible,inView:t.inView,mid:t.mid.map(Math.round)}));}
// the frame hook (loop): advance the timetable and the trains by dt seconds; true when the frame should be drawn
const TR_FR=new T.Frustum(),TR_M=new T.Matrix4(),TR_SPH=new T.Sphere();
function trainsTick(now){const dt=Math.min(.5,(now-TRAIN.last)/1000);TRAIN.last=now;if(TRAIN.reduced||TRAIN.hold||!TRAIN.list.length)return false;
  for(const k in TRAIN.lines){const Ln=TRAIN.lines[k];Ln.t+=dt;const n=Ln.runs.length,r=Ln.runs[Ln.i%n],prev=Ln.runs[(Ln.i+n-1)%n];
    if(r.t.run)continue;
    const ok=Ln.live===0?Ln.t-Ln.clearAt>=r.after:(prev.dir===r.dir&&prev.t!==r.t&&Ln.t-Ln.startAt>=r.after);if(!ok)continue;
    const t=r.t;if(r.from==='park'){if(t.dir!==r.dir)trainTurn(t,true);}else{if(t.dir!==r.dir)trainTurn(t,false);t.s=r.from;}
    t.v=0;t.run={...r,si:0,wait:0};Ln.startAt=Ln.t;Ln.i++;Ln.live++;}
  for(const t of TRAIN.list){const r=t.run;if(!r)continue;const Ln=TRAIN.lines[t.line];
    if(r.wait>0){r.wait-=dt;if(r.wait>0)continue;}
    // the speed: toward a stop (or where it parks), v² = 2 a d, never under a crawl; toward the exit, full speed
    const next=r.si<r.stops.length?r.stops[r.si][0]:r.to,d=Math.max(0,(next-t.s)*t.dir),brake=r.si<r.stops.length||r.park;
    const vt=brake?Math.max(.5,Math.min(r.vmax,Math.sqrt(2*r.acc*d))):r.vmax;t.v=Math.min(vt,t.v+r.acc*dt);
    let ds=t.v*dt;if(ds>=d){ds=d;t.v=0;
      if(r.si<r.stops.length){r.wait=r.stops[r.si][1];r.si++;}
      else{t.run=null;Ln.live--;if(!Ln.live)Ln.clearAt=Ln.t;}}
    t.s+=t.dir*ds;trainPlace(t);if(!t.run&&!r.park)trainHide(t);}
  // draw while a moving train is in the view (or just left it, or just appeared or vanished), at TRAIN_FPS
  TR_M.multiplyMatrices(cam.projectionMatrix,cam.matrixWorldInverse);TR_FR.setFromProjectionMatrix(TR_M);let draw=false;
  for(const t of TRAIN.list){let v=false;
    if(t.grp.visible&&t.run)for(const c of t.cars){if(!c.obj.visible)continue;TR_SPH.set(c.obj.position,c.len/2+4);if(TR_FR.intersectsSphere(TR_SPH)){v=true;break;}}
    if(v||t.inView)draw=true;t.inView=v;if(t.shown!==t.grp.visible){t.shown=t.grp.visible;if(t.inView||v)draw=true;}}
  if(draw&&now-TRAIN.drawn>=1000/TRAIN_FPS-2){TRAIN.drawn=now;return true;}return false;}
function trainsNight(v){matTrainWin.emissive.set(v?0x8C6A2E:0x000000);if(TRAIN.pts)TRAIN.pts.visible=v;}
// the frames the trains asked for: window.__trainFps() gives their rate over the last 2 s and the CPU time of one
// (the render calls; the GPU's time shows up as a lower rate), to measure on a real GPU with a train in the view
const TRAIN_FR=[];
function trainFrame(now,ms){TRAIN_FR.push(now);while(TRAIN_FR.length&&TRAIN_FR[0]<now-2000)TRAIN_FR.shift();TRAIN.ms=TRAIN.ms?TRAIN.ms*.9+ms*.1:ms;}
window.__trainFps=()=>({fps:TRAIN_FR.length/2,drawMs:+(TRAIN.ms||0).toFixed(1)});
