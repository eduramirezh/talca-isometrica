/* =============== la culebrita de completos =============== */
// A game of Snake on the map: a row of completos (the hot dogs of Talca's carritos) runs along the real streets of the
// centre, from the carritos of 5 Oriente. The row eats ingredients (tomate, palta, mayo, chucrut) laid on the streets:
// each one adds a completo at the tail with that topping; tomate, palta and mayo in a row make an italiano (bonus), and
// tomate, chucrut and mayo a completo completo. The row dies when its head runs into its own body.
// The board is the street graph of the map (streets, classes 0-5; not the paths or tracks, nor the streets that a
// landmark draws as a bridge) inside SNK_AREA, from 4 Poniente to 10 Oriente and from the Piduco to 9 Norte, noded at
// every crossing by roadGraph() (12-calles.js), nodes nearer than 10 m merged, without dead ends (the 2-core: a pasaje
// without exit would need a U-turn) and only its largest connected part. The streets that leave the board, or the dead ends that
// were cut, have a red and white barrier at their mouth (streets of class 4 or wider; the pasajes, no: there are
// hundreds). So the row never hits a wall: at a corner it takes the turn asked for, or goes on as straight as it can.
// Controls: a turn is asked for before the corner and taken at the next one where it can be (relative: ← → or A D, the
// buttons; absolute: a swipe toward the street wanted, in the screen's terms, from the camera's azimuth). The camera
// follows the head (the user can still zoom and turn the view); the canvas' drag is the swipe while playing.
// The completos are meshes of their own (a cached geometry per topping, like the train cars), placed every frame along
// the trail of the head at SNK_SP metres from each other and turned with the tangent between their two ends; they do
// not cast shadows (the shadow map would be drawn every frame, the cost of a refit on a phone): a dark translucent
// blob under each, as under the floating ingredients. Sizes: a completo is 10 m long and 4.2 m wide, a giant one,
// so that the toppings are above the art pixel (ESTETICA §2), and drawn 1.6 times that (SNK_SC: 16 m by 6.7 m)
// so that they read among the buildings and the street trees do not hide them; the ingredients, 2.2 times (SNK_ISC),
// each over a mustard ring that pulses on the street. The camera starts at SNK_ZOOM. At night the completos glow a
// little (matSnk's emissive), or the row is lost in the dark streets. The loop draws every frame while the game runs.
// For tools: window.__snk.start(seed), .state(), .auto(true) (an autopilot that steers toward the nearest
// ingredient), .run(seconds) (advances without drawing: a long row for a capture), .stop().
const SNK_AREA=[-700,-800,1300,1000],SNK_SC=1.6,SNK_SP=17,SNK_ZOOM=MOB?12:18,SNK_V0=30,SNK_VMAX=68,SNK_DV=1.1,SNK_FOOD=3,SNK_EAT=11,SNK_HIT=5.2,SNK_ISC=2.2;
const SNK_KINDS=['tomate','palta','mayo','chucrut'];
const SNK_NAMES={tomate:'Tomate',palta:'Palta',mayo:'Mayo',chucrut:'Chucrut'};
const SNK={on:false,g:null,run:false,dead:false,paused:false,len:3,score:0,eaten:0,last:[],segs:[],food:[],q:[],t:0,
  e:null,fwd:true,s:0,D:0,trail:[],v:SNK_V0,hx:0,hy:0,head:[0,1],cam:null,auto:false,rng:Math.random,grp:null,barriers:null,best:0};
try{SNK.best=+localStorage.getItem('talca-culebrita-record')||0;}catch(e){}
const matSnk=new T.MeshLambertMaterial({vertexColors:true});
const matRing=new T.MeshBasicMaterial({color:0xE3B23C,transparent:true,opacity:.85,depthWrite:false,side:T.DoubleSide});
const matBlob=new T.MeshBasicMaterial({color:0x1A1410,transparent:true,opacity:.24,depthWrite:false,polygonOffset:true,polygonOffsetFactor:-2,polygonOffsetUnits:-4});

// ---- the board: the street graph ----
function snkGraph(){return SNK.g||(SNK.g=roadGraph(SNK_AREA,{cmax:5,merge:10,within:true,core:true}));}
const snkAt=edgeAt; // 12-calles.js
// the unit direction at which e leaves a node (forward or not), over its first 10 m
function snkOut(e,fwd){const a=snkAt(e,fwd,0),b=snkAt(e,fwd,Math.min(10,e.len));const L=Math.hypot(b[0]-a[0],b[1]-a[1])||1;return [(b[0]-a[0])/L,(b[1]-a[1])/L];}
function snkIn(e,fwd){const a=snkAt(e,fwd,Math.max(0,e.len-10)),b=snkAt(e,fwd,e.len);const L=Math.hypot(b[0]-a[0],b[1]-a[1])||1;return [(b[0]-a[0])/L,(b[1]-a[1])/L];}

// ---- the models: a completo (a topping per ingredient; the head with eyes) and the ingredients ----
const SNK_GEO={};
function snkGeo(kind){if(SNK_GEO[kind])return SNK_GEO[kind];const G=new GB(1<<11),C=hex;
  const K={bun:C('#D79A4C'),bun2:C('#C3823A'),crumb:C('#EBCF98'),vie:C('#B4503A'),vie2:C('#9C4230'),
    tom:C('#D23A2C'),tom2:C('#B22E24'),pal:C('#7FA83F'),pal2:C('#6A9334'),mayo:C('#F2EEDD'),mayo2:C('#E2DCC6'),
    chu:C('#E3D27E'),chu2:C('#CDBA62'),eye:C('#F7F5EE'),pupil:C('#1E1C1B'),tooth:C('#2A1D18')};
  // local frame: x along the row (the head's front at +x), z across (three.js' z), y up; bx takes x and z ranges
  const bx=(x0,x1,z0,z1,y0,y1,side,top)=>G.prism([[x0,-z0],[x1,-z0],[x1,-z1],[x0,-z1]],y0,y1,side,top);
  if(kind==='palta'||kind==='tomate'||kind==='mayo'||kind==='chucrut'||kind==='italiano'||kind==='cabeza'){
    // the bread: a long loaf, stepped at the ends, with two lips up the sides of the sausage
    bx(-4.4,4.4,-2.1,2.1,.34,1.5,K.bun,K.bun2);bx(-4.9,-4.4,-1.6,1.6,.4,1.4,K.bun,K.bun2);bx(4.4,4.9,-1.6,1.6,.4,1.4,K.bun,K.bun2);
    for(const sg of [1,-1]){bx(-4.2,4.2,sg*1.15,sg*2.1,1.5,2.55,K.bun,K.bun);bx(-3.4,3.4,sg*1.25,sg*1.95,2.55,2.85,K.bun2,K.bun2);}
    // the sausage, sticking out of both ends
    bx(-5.5,5.5,-1.05,1.05,1.3,2.45,K.vie,K.vie2);bx(-5.9,-5.5,-.7,.7,1.45,2.25,K.vie2,K.vie2);bx(5.5,5.9,-.7,.7,1.45,2.25,K.vie2,K.vie2);
    const top=(x0,x1,col,col2,h=2.85)=>bx(x0,x1,-1.15,1.15,2.45,h,col,col2);
    const k=kind==='cabeza'?'italiano':kind;
    if(k==='palta')top(-3.8,3.8,K.pal2,K.pal);
    else if(k==='tomate'){for(let i=0;i<6;i++){const x=-3.6+i*1.25;bx(x,x+1.05,-1.1,0,2.45,i%2?2.95:3.15,K.tom2,i%2?K.tom2:K.tom);bx(x+.1,x+1.15,0,1.1,2.45,i%2?3.15:2.95,K.tom2,i%2?K.tom:K.tom2);}}
    else if(k==='mayo'){top(-3.8,3.8,K.mayo2,K.mayo,2.75);for(let i=0;i<4;i++){const x=-3.3+i*1.9;bx(x,x+.8,-1.25,1.25,2.75,3.05,K.mayo2,K.mayo);}}
    else if(k==='chucrut'){top(-3.8,3.8,K.chu2,K.chu,2.8);for(let i=0;i<5;i++){const x=-3.4+i*1.55;bx(x,x+.6,i%2?-1.1:-.2,i%2?.2:1.1,2.8,3.1,K.chu2,K.chu2);}}
    else{ // italiano: palta under, tomate in the middle, mayo across
      top(-3.8,3.8,K.pal2,K.pal);for(let i=0;i<3;i++){const x=-3.2+i*2.3;bx(x,x+1.1,-.9,.9,2.85,3.25,K.tom2,K.tom);}
      for(let i=0;i<3;i++){const x=-2.05+i*2.3;bx(x,x+.7,-1.25,1.25,2.85,3.15,K.mayo2,K.mayo);}}
    if(kind==='cabeza'){ // two eyes on the front of the bread and a dark mouth on the sausage's tip
      for(const sg of [1,-1]){bx(3.2,4.4,sg*.25,sg*1.6,2.85,4.1,K.eye,K.eye);bx(4.1,4.5,sg*.55,sg*1.2,3.2,3.85,K.pupil,K.pupil);}
      G.face([[5.92,1.6,-.45],[5.92,1.6,.45],[5.92,2.0,.45],[5.92,2.0,-.45]],[1,0,0],K.tooth);}}
  else if(kind==='i-tomate'){ // a tomato: a stepped red ball with its green calyx
    bx(-1.9,1.9,-1.9,1.9,.6,3.4,K.tom,K.tom);bx(-1.5,1.5,-1.5,1.5,.35,3.8,K.tom2,K.tom);bx(-2.2,2.2,-1.3,1.3,1.1,2.9,K.tom2,K.tom2);bx(-1.3,1.3,-2.2,2.2,1.1,2.9,K.tom2,K.tom2);
    bx(-.9,.9,-.35,.35,3.8,4.1,K.pal2,K.pal2);bx(-.35,.35,-.9,.9,3.8,4.1,K.pal2,K.pal2);bx(-.25,.25,-.25,.25,4.1,4.7,K.pal2,K.pal);}
  else if(kind==='i-palta'){ // half an avocado, face up: dark skin, light flesh, the brown seed
    const sk=C('#3F5E2A'),fl=C('#C9D77A'),fl2=C('#A9C25A'),seed=C('#7A4A2A');
    bx(-2.6,2.2,-1.8,1.8,.4,1.9,sk,sk);bx(-2.2,1.8,-2.2,2.2,.4,1.9,sk,sk);bx(-2.4,2.0,-1.6,1.6,1.9,2.4,fl2,fl);bx(-2.0,1.6,-2.0,2.0,1.9,2.3,fl2,fl);
    bx(-1.3,.5,-.9,.9,2.3,3.1,seed,seed);G.face([[-1.3,3.1,-.9],[.5,3.1,-.9],[.5,3.1,.9],[-1.3,3.1,.9]],[0,1,0],C('#8E5934'));}
  else if(kind==='i-mayo'){ // a squeeze bottle of mayonnaise: white, a yellow label, a red cap
    const wh=C('#F4F1E6'),wh2=C('#DEDAD0'),lab=C('#E3B93A'),cap=C('#C8322B');
    bx(-1.2,1.2,-1.2,1.2,.4,4.6,wh2,wh);bx(-1.27,1.27,-1.27,1.27,1.6,3.2,lab,lab);bx(-.8,.8,-.8,.8,4.6,5.4,wh2,wh);bx(-.5,.5,-.5,.5,5.4,6.3,cap,cap);}
  else if(kind==='i-chucrut'){ // a jar of sauerkraut: glass, pale strands, a red lid
    const gl=C('#BFD3D6'),gl2=C('#A8BEC2'),lid=C('#B83A30');
    bx(-1.5,1.5,-1.5,1.5,.4,3.6,gl2,gl);bx(-1.53,1.53,-1.53,1.53,.7,3.0,K.chu2,K.chu2);bx(-1.6,1.6,-1.6,1.6,3.6,4.2,lid,lid);
    for(let i=0;i<3;i++)bx(-1.58,1.58,-.9+i*.8,-.6+i*.8,1.2+i*.5,1.6+i*.5,K.chu,K.chu);}
  return SNK_GEO[kind]=G.geo();}
function snkBlob(w,l){const g=new T.PlaneGeometry(l,w);g.rotateX(-Math.PI/2);const m=new T.Mesh(g,matBlob);m.renderOrder=2;return m;}
function snkSeg(kind){const o=new T.Group(),m=new T.Mesh(snkGeo(kind),matSnk),b=snkBlob(4.8*SNK_SC,11*SNK_SC);m.scale.setScalar(SNK_SC);o.add(m);o.userData={m,kind,blob:b};SNK.grp.add(o,b);return o;}

// ---- the barriers at the board's edge ----
function snkBarriers(g){const G=new GB(1<<14),C=hex,red=C('#C8372D'),red2=C('#A92C24'),wh=C('#EEEBE3'),wh2=C('#D9D5CB'),leg=C('#5A5755');
  for(const [p,q,w] of g.stubs){const dx=q[0]-p[0],dy=q[1]-p[1],L=Math.hypot(dx,dy);if(L<1)continue;const ux=dx/L,uy=dy/L,nx=-uy,ny=ux;
    const d=Math.min(9,L*.5),cx=p[0]+ux*d,cy=p[1]+uy*d,hw=Math.max(3,w/2-.5);
    const q4=(a0,a1,b0,b1)=>[[cx+ux*a0+nx*b0,cy+uy*a0+ny*b0],[cx+ux*a1+nx*b0,cy+uy*a1+ny*b0],[cx+ux*a1+nx*b1,cy+uy*a1+ny*b1],[cx+ux*a0+nx*b1,cy+uy*a0+ny*b1]];
    G.dy=E(cx,cy);
    for(const sg of [1,-1])G.prism(q4(-.3,.3,sg*hw-.3,sg*hw+.3),.32,1.4,leg,leg);
    const n=Math.max(2,Math.round(2*hw/1.2));for(let i=0;i<n;i++){const b0=-hw+2*hw*i/n,b1=-hw+2*hw*(i+1)/n;G.prism(q4(-.3,.3,b0,b1),1.4,2.2,i%2?wh2:red2,i%2?wh:red);}}
  G.dy=0;const m=new T.Mesh(G.geo(),matSnk);m.receiveShadow=true;return m;}

// ---- the game ----
const SNK_RING=new T.RingGeometry(.82,1,32);
function snkSpawn(){const g=SNK.g;let tries=0;
  while(tries++<400){let r=SNK.rng()*g.total,e=g.edges[0];for(const x of g.edges){if(r<x.len){e=x;break;}r-=x.len;}
    if(e.len<14)continue;const s=7+SNK.rng()*(e.len-14),p=snkAt(e,true,s),dh=Math.hypot(p[0]-SNK.hx,p[1]-SNK.hy);
    if(dh<110||dh>(tries<200?520:1e9))continue;
    if(SNK.food.some(f=>Math.hypot(f.x-p[0],f.y-p[1])<60))continue;
    if(snkNearBody(p[0],p[1],14,0))continue;
    const k=SNK_KINDS[Math.floor(SNK.rng()*SNK_KINDS.length)],o=new T.Mesh(snkGeo('i-'+k),matSnk),b=snkBlob(5*SNK_ISC,5*SNK_ISC);
    o.scale.setScalar(SNK_ISC);const rg=new T.Mesh(SNK_RING,matRing);rg.rotation.x=-Math.PI/2;rg.renderOrder=3;
    SNK.grp.add(o,b,rg);const z=E(p[0],p[1]);b.position.set(p[0],z+.25,-p[1]);rg.position.set(p[0],z+.3,-p[1]);o.position.set(p[0],z+2,-p[1]);
    SNK.food.push({k,x:p[0],y:p[1],z,o,b,r:rg,ph:SNK.rng()*6});return;}}
// a point of the body at odometer d (the head is at SNK.D)
function snkBody(d){const tr=SNK.trail,n=tr.length;if(!n||d>=tr[n-1][2]){const l=n?tr[n-1]:[SNK.hx,SNK.hy,SNK.D],k=(SNK.D-l[2])>1e-6?(d-l[2])/(SNK.D-l[2]):1;
    return [l[0]+(SNK.hx-l[0])*k,l[1]+(SNK.hy-l[1])*k];}
  if(d<=tr[0][2])return [tr[0][0],tr[0][1]];let lo=0,hi=n-1;while(hi-lo>1){const m=(lo+hi)>>1;if(tr[m][2]<=d)lo=m;else hi=m;}
  const a=tr[lo],b=tr[hi],t=(d-a[2])/((b[2]-a[2])||1);return [a[0]+(b[0]-a[0])*t,a[1]+(b[1]-a[1])*t];}
// is (x, y) within r of the body, leaving out its first `skip` metres behind the head?
function snkNearBody(x,y,r,skip){const L=SNK.len*SNK_SP;for(let d=skip;d<=L;d+=2){const p=snkBody(SNK.D-d);if((p[0]-x)**2+(p[1]-y)**2<r*r)return true;}return false;}
// the corner: which street the head takes at node n, arriving along h. Commands: {t:'L'|'R'} turn, {t:'A',v:[x,y]} toward
function snkChoose(n,h){const cand=[];for(const a of n.adj){if(a.e===SNK.e&&a.fwd!==SNK.fwd&&(a.e.a!==a.e.b))continue;const d=snkOut(a.e,a.fwd);
    cand.push({a,d,th:Math.atan2(h[0]*d[1]-h[1]*d[0],h[0]*d[0]+h[1]*d[1])});}
  if(!cand.length)return null;
  const straight=cand.reduce((b,c)=>Math.abs(c.th)<Math.abs(b.th)?c:b);
  if(SNK.auto&&!SNK.q.length){const f=snkNearestFood();if(f){let bc=null,bs=1e18;
      for(const c of cand){const e=c.a.e,o=c.a.fwd?e.b:e.a;let s=Math.hypot(o.x-f.x,o.y-f.y)-.5*Math.hypot(n.x-f.x,n.y-f.y);
        for(let u=6;u<=Math.min(e.len,60);u+=5){const p=snkAt(e,c.a.fwd,u);if(snkNearBody(p[0],p[1],6,SNK_SP*1.5)){s+=1e6/u;break;}}if(snkNearBody(o.x,o.y,8,SNK_SP*1.5))s+=5e3;
        if(s<bs){bs=s;bc=c;}}if(bc)return bc.a;}}
  while(SNK.q.length){const c=SNK.q[0];let pick=null;
    if(c.t==='L'){for(const x of cand)if(x.th>.45&&x.th<2.9&&(!pick||Math.abs(x.th-Math.PI/2)<Math.abs(pick.th-Math.PI/2)))pick=x;}
    else if(c.t==='R'){for(const x of cand)if(x.th<-.45&&x.th>-2.9&&(!pick||Math.abs(x.th+Math.PI/2)<Math.abs(pick.th+Math.PI/2)))pick=x;}
    else{let bd=Math.cos(1.0);for(const x of cand){const dt=x.d[0]*c.v[0]+x.d[1]*c.v[1];if(dt>bd){bd=dt;pick=x;}}}
    if(pick){SNK.q.shift();snkHint();return pick.a;}
    if(--c.ttl<=0){SNK.q.shift();snkHint();continue;}break;}
  return straight.a;}
function snkNearestFood(){let b=null,bd=1e18;for(const f of SNK.food){const d=(f.x-SNK.hx)**2+(f.y-SNK.hy)**2;if(d<bd){bd=d;b=f;}}return b;}
// the head moves ds metres; the trail keeps every vertex it passes, with its odometer
function snkMove(ds){while(ds>0){const e=SNK.e,rem=e.len-SNK.s,st=Math.min(ds,rem),s0=SNK.s,s1=s0+st;
    const verts=SNK.fwd?e.cum.map((c,i)=>[c,i]):e.cum.map((c,i)=>[e.len-c,i]).reverse();
    for(const [c,i] of verts)if(c>s0+1e-6&&c<=s1+1e-6)SNK.trail.push([e.pts[i][0],e.pts[i][1],SNK.D+c-s0]);
    SNK.s=s1;SNK.D+=st;ds-=st;const p=snkAt(e,SNK.fwd,SNK.s);SNK.hx=p[0];SNK.hy=p[1];
    if(SNK.s>=e.len-1e-6){const n=SNK.fwd?e.b:e.a,h=snkIn(e,SNK.fwd),a=snkChoose(n,h);if(!a){snkDie('Calle sin salida');return;}
      SNK.e=a.e;SNK.fwd=a.fwd;SNK.s=0;}}
  const keepD=SNK.D-(SNK.len+3)*SNK_SP;let k=0;while(k<SNK.trail.length-2&&SNK.trail[k+1][2]<keepD)k++;if(k)SNK.trail.splice(0,k);}
function snkStep(dt){if(!SNK.run||SNK.dead||SNK.paused||SNK.frozen)return;SNK.t+=dt;
  SNK.v=Math.min(SNK_VMAX,SNK_V0+SNK.eaten*SNK_DV);let ds=SNK.v*dt;
  while(ds>0&&!SNK.dead){const st=Math.min(ds,2);snkMove(st);ds-=st; // in steps of 2 m: no ingredient or crossing is jumped over
    for(let i=SNK.food.length-1;i>=0;i--){const f=SNK.food[i];if(Math.hypot(f.x-SNK.hx,f.y-SNK.hy)<SNK_EAT)snkEat(i);}
    if(snkNearBody(SNK.hx,SNK.hy,SNK_HIT,SNK_SP*1.6))snkDie('¡Te mordiste la cola!');}}
function snkEat(i){const f=SNK.food[i];SNK.food.splice(i,1);SNK.grp.remove(f.o,f.b,f.r);
  SNK.len++;SNK.eaten++;SNK.score+=10;SNK.last.push(f.k);if(SNK.last.length>3)SNK.last.shift();
  const seg=snkSeg(f.k);SNK.segs.push(seg);let msg=`+10 ${SNK_NAMES[f.k]}`;
  const L=[...SNK.last].sort().join();
  if(L==='mayo,palta,tomate'){SNK.score+=40;msg='¡Italiano! +50';SNK.last=[];}
  else if(L==='chucrut,mayo,tomate'){SNK.score+=40;msg='¡Completo completo! +50';SNK.last=[];}
  snkPop(msg,f.x,f.y,f.z+6);snkSpawn();snkHud();}
function snkDie(why){if(SNK.dead)return;SNK.dead=true;SNK.run=false;
  const rec=SNK.score>SNK.best;if(rec){SNK.best=SNK.score;try{localStorage.setItem('talca-culebrita-record',SNK.best);}catch(e){}}
  snkHud();if(!SNK.headless)snkMsg('over',why,rec);}
// the meshes where the game state says
function snkPlace(now){const segs=SNK.segs;
  for(let i=0;i<segs.length;i++){const o=segs[i],c=SNK.D-5.9*SNK_SC-i*SNK_SP,a=snkBody(c-4.6*SNK_SC),b=snkBody(c+4.6*SNK_SC),x=(a[0]+b[0])/2,y=(a[1]+b[1])/2;
    const dx=b[0]-a[0],dy=b[1]-a[1],D=Math.hypot(dx,dy)||1,za=E(a[0],a[1]),zb=E(b[0],b[1]);
    o.position.set(x,(za+zb)/2+.05,-y);o.rotation.set(0,Math.atan2(dy,dx),Math.atan2(zb-za,D),'YZX');
    const bl=o.userData.blob;bl.position.set(x,(za+zb)/2+.25,-y);bl.rotation.set(0,Math.atan2(dy,dx),0);}
  for(const f of SNK.food){const t=now/1000+f.ph;f.o.position.y=f.z+2+Math.sin(t*2.6)*1.6;f.o.rotation.y=t*1.4;
    const u=(t%1.6)/1.6;f.r.scale.setScalar(7+u*9);f.r.visible=u<.85;}
  matSnk.emissive.setRGB(...(night?[.32,.24,.16]:[0,0,0]));}
function snkStart(seed){const g=snkGraph();if(!SNK.on)SNK.prev={...view};snkStop(true);
  SNK.rng=seed!=null?rng(seed):Math.random;
  if(!SNK.grp){SNK.grp=new T.Group();scene.add(SNK.grp);SNK.barriers=snkBarriers(g);scene.add(SNK.barriers);}
  SNK.grp.visible=SNK.barriers.visible=true;
  // the start: on 5 Oriente, the edge nearest the carritos (MODELS), heading north
  const M=MODELS['carritos-5-oriente']||{x:560,y:-250};let be=g.edges[0],bd=1e18;
  for(const e of g.edges){if(e.len<45)continue;const m=snkAt(e,true,e.len/2),d=(m[0]-M.x)**2+(m[1]-M.y)**2+(/5 Oriente/.test(e.name||'')?0:4e4);if(d<bd){bd=d;be=e;}}
  const up=be.pts[be.pts.length-1][1]>be.pts[0][1];
  Object.assign(SNK,{e:be,fwd:up,s:Math.min(be.len-4,3*SNK_SP+8),D:0,len:3,score:0,eaten:0,last:[],q:[],t:0,dead:false,paused:false,v:SNK_V0});
  // the trail behind the head: back along its street, straight on past its start
  const p0=snkAt(be,SNK.fwd,0),p1=snkAt(be,SNK.fwd,Math.min(10,be.len)),L0=Math.hypot(p1[0]-p0[0],p1[1]-p0[1])||1;
  SNK.D=SNK.s+SNK_SP*6;SNK.trail=[[p0[0]-(p1[0]-p0[0])/L0*SNK_SP*6,p0[1]-(p1[1]-p0[1])/L0*SNK_SP*6,0]];
  const verts=SNK.fwd?be.cum.map((c,i)=>[c,i]):be.cum.map((c,i)=>[be.len-c,i]).reverse();
  for(const [c,i] of verts)if(c<=SNK.s)SNK.trail.push([be.pts[i][0],be.pts[i][1],SNK_SP*6+c]);
  const h=snkAt(be,SNK.fwd,SNK.s);SNK.hx=h[0];SNK.hy=h[1];SNK.head=snkOut(be,SNK.fwd);
  SNK.segs=[snkSeg('cabeza'),snkSeg('italiano'),snkSeg('italiano')];
  for(let i=0;i<SNK_FOOD;i++)snkSpawn();
  SNK.on=true;SNK.run=false;SNK.cam=null;view.zoom=Math.max(view.zoom,SNK_ZOOM);snkPlace(performance.now());snkUI(true);snkHud();snkHint();dirty=true;}
function snkGo(){if(!SNK.on)return;if(SNK.dead)snkStart();SNK.run=true;SNK.paused=false;snkMsg(null);dirty=true;}
function snkStop(keep){if(SNK.grp){for(const o of SNK.segs)SNK.grp.remove(o,o.userData.blob);for(const f of SNK.food)SNK.grp.remove(f.o,f.b,f.r);}
  SNK.segs=[];SNK.food=[];SNK.run=false;if(keep)return;SNK.on=false;if(SNK.grp)SNK.grp.visible=SNK.barriers.visible=false;snkUI(false);snkMsg(null);dirty=true;
  const v=SNK.prev;if(v){SNK.prev=null;flyTo(v.tx,v.ty,v.zoom,v.az);}} // back to the view before the game
function snkPause(v){if(!SNK.on||SNK.dead||!SNK.run&&!SNK.paused)return;SNK.paused=v;SNK.run=!v;snkMsg(v?'pause':null);}
let snkLast=0;
// every frame from loop(): the state, the meshes, the camera on the head; true: draw
function snkTick(now){const dt=Math.min(.25,(now-(snkLast||now))/1000);snkLast=now;if(!SNK.on)return false;
  snkStep(dt);snkPlace(now);
  if(SNK.frozen)return true; // a still frame (__snk.freeze): the camera is free for __look
  // the camera on the ground point ahead of the head (up to a fifth of the view's narrower side), eased
  const la=Math.min(SNK.v*1.2,.2*BASEH/view.zoom*Math.min(1,W/H)),tgt=[SNK.hx+SNK.head[0]*la,SNK.hy+SNK.head[1]*la];
  const hd=snkOut(SNK.e,SNK.fwd);SNK.head[0]+=(hd[0]-SNK.head[0])*Math.min(1,dt*3);SNK.head[1]+=(hd[1]-SNK.head[1])*Math.min(1,dt*3);
  if(!SNK.cam)SNK.cam=tgt.slice();else{const k=Math.min(1,dt*4);SNK.cam[0]+=(tgt[0]-SNK.cam[0])*k;SNK.cam[1]+=(tgt[1]-SNK.cam[1])*k;}
  const [tx,ty]=lift(SNK.cam[0],SNK.cam[1]);view.tx=tx;view.ty=ty;placeCam();
  const nm=SNK.e&&SNK.e.name;if(nm!==SNK.nm){SNK.nm=nm;const c=$('#snk-c');c.textContent=nm?'por '+nm:'';c.hidden=!nm;} // the street of the head
  snkArrow();return true;}

// ---- the page: HUD, messages, controls ----
const snkEl=$('#snk');
function snkUI(on){$('#app').classList.toggle('juego',on);snkEl.hidden=!on;if(on){closeCard();ring.visible=false;snkMsg('start');}}
function snkHud(){$('#snk-n').textContent=SNK.len;$('#snk-p').textContent=SNK.score;$('#snk-r').textContent=SNK.best;}
function snkHint(){const c=SNK.q[0];$('#snk-l').classList.toggle('on',!!c&&c.t==='L');$('#snk-rt').classList.toggle('on',!!c&&c.t==='R');}
function snkMsg(kind,why,rec){const m=$('#snk-msg');if(!kind){m.hidden=true;return;}m.hidden=false;
  const esc2=s=>esc(s);
  if(kind==='start')m.innerHTML=`<h2>La culebrita de completos</h2>
    <p>Una fila de completos sale de los carritos de 5 Oriente y recorre las calles del centro de Talca. Junta tomate, palta, mayo y chucrut: cada ingrediente suma un completo a la fila. Tomate, palta y mayo seguidos arman un italiano, que da puntos extra.</p>
    <p>No choques con tu propia fila. Las barreras rojas cierran las calles que salen del juego.</p>
    <ul><li><b>Doblar:</b> flechas ← → (o A y D), o los botones de abajo. Se dobla en la próxima esquina.</li><li><b>En el teléfono:</b> también puedes deslizar el dedo hacia la calle que quieres.</li><li><b>Pausa:</b> espacio. <b>Salir:</b> Esc.</li></ul>
    <div class="acts"><button class="btn" id="snk-go">Jugar</button><button class="btn ghost" id="snk-x2">Volver al mapa</button></div>`;
  else if(kind==='pause')m.innerHTML=`<h2>Pausa</h2><p>${SNK.len} completos · ${SNK.score} puntos</p>
    <div class="acts"><button class="btn" id="snk-go">Seguir</button><button class="btn ghost" id="snk-x2">Volver al mapa</button></div>`;
  else m.innerHTML=`<h2>${esc2(why)}</h2><p>Juntaste ${SNK.len} completos y ${SNK.score} puntos.${rec?' ¡Es tu récord!':` Tu récord es ${SNK.best}.`}</p>
    <div class="acts"><button class="btn" id="snk-go">Otra vez</button><button class="btn ghost" id="snk-x2">Volver al mapa</button></div>`;
  $('#snk-go').onclick=()=>kind==='pause'?snkPause(false):snkGo();$('#snk-x2').onclick=()=>snkStop();
  setTimeout(()=>{const b=$('#snk-go');if(b&&!m.hidden)b.focus();},0);}
function snkPop(t,x,y,h){const e=document.createElement('div');e.className='snk-pop';e.textContent=t;const [px,py]=proj(x,y,h);
  e.style.left=px+'px';e.style.top=py+'px';snkEl.appendChild(e);setTimeout(()=>e.remove(),1300);}
// the arrow at the edge of the screen toward the nearest ingredient, when none is in the view
function snkArrow(){const a=$('#snk-a');let best=null,bd=1e18,inView=false;
  for(const f of SNK.food){const [px,py]=proj(f.x,f.y,f.z+2);if(px>20&&px<W-20&&py>20&&py<H-20){inView=true;break;}const d=(f.x-SNK.hx)**2+(f.y-SNK.hy)**2;if(d<bd){bd=d;best=[px,py,f];}}
  if(inView||!best||!SNK.run){a.hidden=true;return;}
  const cx=W/2,cy=H/2,dx=best[0]-cx,dy=best[1]-cy,m=56,k=Math.min((cx-m)/Math.abs(dx||1e-6),(cy-m)/Math.abs(dy||1e-6));
  a.hidden=false;a.style.left=(cx+dx*k)+'px';a.style.top=(cy+dy*k)+'px';a.style.setProperty('--r',Math.atan2(dy,dx)+'rad');
  $('#snk-ad').textContent=Math.round(Math.sqrt(bd)/10)*10+' m';a.title=SNK_NAMES[best[2].k];}
function snkCmd(c){if(!SNK.on||SNK.dead)return;if(!SNK.run&&!SNK.paused){snkGo();}
  if(c.t==='A'){const h=SNK.head;if(c.v[0]*h[0]+c.v[1]*h[1]<-.8)return;} // backward: no U-turns
  c.ttl=c.t==='A'?2:3;if(SNK.q.length>=2)SNK.q.shift();SNK.q.push(c);snkHint();}
// the screen's direction (dx right, dy down, pixels) as a ground direction, with the view's azimuth and tilt
function snkScreenDir(dx,dy){const az=view.az,c=Math.cos(az),s=Math.sin(az),u=-dy/Math.sin(EL);const x=dx*c-u*s,y=dx*s+u*c,L=Math.hypot(x,y)||1;return [x/L,y/L];}
(function(){const st=$('#stage');let sw=null;
  // while playing, the canvas' drag is a swipe (capture: the map's own pan never sees it)
  st.addEventListener('pointerdown',e=>{if(!SNK.on)return;e.stopPropagation();sw=[e.clientX,e.clientY,e.pointerId];},true);
  st.addEventListener('pointermove',e=>{if(!SNK.on)return;e.stopPropagation();if(!sw||sw[2]!==e.pointerId)return;const dx=e.clientX-sw[0],dy=e.clientY-sw[1];
    if(Math.hypot(dx,dy)>28){snkCmd({t:'A',v:snkScreenDir(dx,dy)});sw=null;}},true);
  for(const ev of ['pointerup','pointercancel'])st.addEventListener(ev,e=>{if(!SNK.on)return;e.stopPropagation();sw=null;},true);
  st.addEventListener('dblclick',e=>{if(SNK.on)e.stopPropagation();},true);
  window.addEventListener('keydown',e=>{const tg=e.target instanceof Element?e.target:document.body;if(!SNK.on||tg.closest('input'))return;const k=e.key;let h=true;
    if(k==='ArrowLeft'||k==='a'||k==='A')snkCmd({t:'L'});else if(k==='ArrowRight'||k==='d'||k==='D')snkCmd({t:'R'});
    else if(k==='ArrowUp'||k==='ArrowDown'||k==='w'||k==='s'||k==='W'||k==='S'){}
    else if(k===' '||k==='p'||k==='P'){if(tg.closest('button'))return;if(SNK.paused)snkPause(false);else if(SNK.run)snkPause(true);else snkGo();}
    else if(k==='Enter'){if(tg.closest('button'))return;if(!SNK.run&&!SNK.paused)snkGo();else h=false;}
    else if(k==='Escape'){if(SNK.run)snkPause(true);else snkStop();}else h=false;
    if(h){e.preventDefault();e.stopPropagation();}},true);
  document.addEventListener('visibilitychange',()=>{if(document.hidden&&SNK.run)snkPause(true);});
  $('#snk-l').onclick=()=>snkCmd({t:'L'});$('#snk-rt').onclick=()=>snkCmd({t:'R'});
  $('#snk-pz').onclick=()=>SNK.paused?snkPause(false):snkPause(true);$('#snk-x').onclick=()=>snkStop();
  $('#game').onclick=()=>SNK.on?snkStop():snkStart();})();
window.__snk={start:s=>{snkStart(s);snkGo();return __snk.state();},stop:()=>snkStop(),auto:v=>{SNK.auto=v!==false;},
  freeze:v=>{SNK.frozen=v!==false;},over:()=>snkDie('¡Te mordiste la cola!'), // a still frame for a capture; the end screen
  // advance t seconds without drawing (an autopilot row for a capture); the head is kept away from the trail's end
  run:(t,fps=30)=>{SNK.headless=true;const fz=SNK.frozen;SNK.frozen=false;for(let i=0;i<t*fps&&!SNK.dead;i++)snkStep(1/fps);SNK.headless=false;SNK.head=snkOut(SNK.e,SNK.fwd);SNK.cam=null;snkTick(performance.now());SNK.frozen=fz;dirty=true;return __snk.state();},
  state:()=>{const g=snkGraph();return {on:SNK.on,run:SNK.run,dead:SNK.dead,len:SNK.len,score:SNK.score,best:SNK.best,v:Math.round(SNK.v),head:[Math.round(SNK.hx),Math.round(SNK.hy)],
    street:SNK.e&&SNK.e.name,food:SNK.food.map(f=>[f.k,Math.round(f.x),Math.round(f.y)]),graph:{nodes:g.nodes.length,edges:g.edges.length,km:Math.round(g.total/100)/10,barriers:g.stubs.length,ms:g.ms}};}};
