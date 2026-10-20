/* =============== streets in the panel: search, street and corner cards, the tours' walking routes =============== */
// What the street graph of 12-calles.js gives the map besides the game:
//  - the search of the panel also finds streets (by their name to show, streetName) and corners ("1 Norte con 5
//    Oriente", also "y", "esquina", "/" or "&"): a street flies to its point nearest the plaza and lights all of it
//    (an amber ribbon on its axis, HL), a corner flies there with the ring; each opens a card with the places on that
//    street (the address of their card names it) or within 150 m of that corner;
//  - a tour draws its walking route along the streets, stop to stop (roadPath on a graph of the streets and paths of
//    class 0-7 with the bridges, built once for the box of the tours' stops: ~6,000 corners, ~0.1 s the first time),
//    as a dashed line in a bright wine, and the card says how far the stop is from the previous one and how long on foot
//    (80 m a minute). The route is a guide: it goes by the map's streets and paths, not by the real sidewalks.
// Nothing of this is in the startup: the meshes are made when asked for and leave the scene with the card.
const WALK_MPM=80; // metres per minute on foot
// the lines are drawn unlit (MeshBasic), a street in amber and a route in a bright wine, at least HL_W (ROUTE_W) metres
// wide and 3 art pixels: calleLod() (from loop(), with ART) makes them again when the art pixel changes by a quarter,
// or a far view would lose them under a pixel and the dark contour of the pixel art would eat a thin one
const matHL=new T.MeshBasicMaterial({color:0xF0B429,polygonOffset:true,polygonOffsetFactor:-2,polygonOffsetUnits:-6});
const matRoute=new T.MeshBasicMaterial({color:0xD23C64,polygonOffset:true,polygonOffsetFactor:-2,polygonOffsetUnits:-6});
const HL_W=5,ROUTE_W=4;
let HL=null,ROUTE=null,ROUTE_G=null,NAMES=null;
// the names to show, each with its streets: normName -> {n, list, c (the widest class), d (nearest to the plaza)}
function streetNames(){if(NAMES)return NAMES;NAMES=new Map();
  for(const s of streets){const n=streetName(s);if(!n||s.c>6)continue;const k=normName(n);let o=NAMES.get(k);if(!o)NAMES.set(k,o={n,list:[],c:9,d:1e9});
    o.list.push(s);o.c=Math.min(o.c,s.c);for(const p of s.pts)o.d=Math.min(o.d,Math.hypot(p[0],p[1]));}
  return NAMES;}
// the name a query means: the same, or the one that starts with it, or contains it; the widest and nearest first
function nameFor(q){const N=streetNames(),k=normName(q).replace(/^(calle|avenida|av\.?|pasaje|psje\.?)\s+/,'');if(N.has(k))return k;
  let best=null,bs=1e18;for(const [n,o] of N){const i=n.indexOf(k);if(i<0||(i>0&&!/[\s(]/.test(n[i-1])))continue;const sc=(i===0?0:1e6)+o.c*1e4+o.d;if(sc<bs){bs=sc;best=n;}}
  return best;}
// a ribbon of width w over the polylines, on the ground (dash: [on, off] metres; none: solid)
function routeRibbon(lines,w,dash,mat=matHL){const G=new GB(1<<12),col=[255,255,255];
  for(const P of lines){let acc=0;for(let i=0;i<P.length-1;i++){const a=P[i],b=P[i+1],L=Math.hypot(b[0]-a[0],b[1]-a[1]);if(L<.01)continue;
    const tx=(b[0]-a[0])/L,ty=(b[1]-a[1])/L,nx=-ty*w/2,ny=tx*w/2;
    for(let u=0;u<L-1e-6;){let on=true,step=Math.min(L-u,4);
      if(dash){const per=dash[0]+dash[1],ph=acc%per;on=ph<dash[0];step=Math.max(1e-3,Math.min(L-u,on?dash[0]-ph:per-ph));}
      if(on&&step>.05){const p0=[a[0]+tx*u,a[1]+ty*u],p1=[a[0]+tx*(u+step),a[1]+ty*(u+step)],h0=E(p0[0],p0[1])+.22,h1=E(p1[0],p1[1])+.22;
        G.face([[p0[0]-nx,h0,-(p0[1]-ny)],[p1[0]-nx,h1,-(p1[1]-ny)],[p1[0]+nx,h1,-(p1[1]+ny)],[p0[0]+nx,h0,-(p0[1]+ny)]],[0,1,0],col);}
      u+=step;acc+=step;}}}
  const m=new T.Mesh(G.geo(),mat);m.renderOrder=4;return m;}
const lineW=(w,art)=>Math.max(w,3*art);
function streetHL(lines){if(HL){scene.remove(HL.m);HL.m.geometry.dispose();HL=null;}if(lines){HL={lines,art:ART,m:routeRibbon(lines,lineW(HL_W,ART))};scene.add(HL.m);}dirty=true;}
// the lines again at the width the art pixel asks for
function calleLod(art){for(const L of [HL,ROUTE]){if(!L||Math.abs(Math.log(art/L.art))<Math.log(1.25))continue;L.art=art;const w=lineW(L===HL?HL_W:ROUTE_W,art);
  scene.remove(L.m);L.m.geometry.dispose();L.m=L===HL?routeRibbon(L.lines,w):routeRibbon(L.lines,w,[w*1.6,w*1.1],matRoute);scene.add(L.m);}}
// the places whose address names the street n (its normName)
function placesOn(n){const re=new RegExp('(^|[^0-9½])'+n.replace(/[.*+?^${}()|[\]\\]/g,'\\$&')+'(?![0-9a-z½])');return POIS.filter(p=>re.test(normName(p.a)));}
const fmtM=m=>m>=1000?(m/1000).toFixed(1).replace('.',',')+' km':Math.round(m/10)*10+' m';
// a card that is not a place's: a street or a corner
function placeCard(title,lab,addr,text,list){selId=null;tour=null;tourRoute(null);ring.material.color.set(cssVar('--wine')||'#7A1F3D');
  card.style.setProperty('--cc','var(--wine)');
  card.innerHTML=`<div class="in"><div class="top"><div><div class="cat">${esc(lab)}</div><h2>${esc(title)}</h2></div><button class="x" id="cx" aria-label="Cerrar ficha">×</button></div>
    ${addr?`<div class="addr">${esc(addr)}</div>`:''}<p>${esc(text)}</p>
    ${list.length?`<ul class="sub places">${list.map(p=>`<li><button data-id="${p.id}"><b>${esc(p.n)}</b> <span>${esc(p.a)}</span></button></li>`).join('')}</ul>`:''}</div>`;
  card.hidden=false;$('#cx').onclick=closeCard;card.querySelectorAll('.places button').forEach(b=>b.onclick=()=>select(b.dataset.id,true));
  try{history.replaceState(null,'',location.pathname+location.search);}catch(e){}}
function showStreet(n){const o=streetNames().get(n);if(!o)return;
  // its point nearest the plaza, and its length in the commune
  let best=null,bd=1e18,L=0;for(const s of o.list)for(let i=0;i<s.pts.length;i++){const p=s.pts[i],d=Math.hypot(p[0],p[1]);if(d<bd){bd=d;best=p;}
    if(i)L+=Math.hypot(p[0]-s.pts[i-1][0],p[1]-s.pts[i-1][1]);}
  const kind=o.list.some(s=>/^Avenida /.test(s.name))?'Avenida':o.c>=5?'Pasaje o calle local':'Calle';
  const pl=placesOn(n);ring.visible=false;
  placeCard(o.n,kind,null,`${fmtM(L)} de calzada en el mapa${o.list.length>1?`, en ${o.list.length} tramos`:''}. ${pl.length?`Lugares en ${o.n}:`:'Ningún lugar del mapa tiene su dirección en esta calle.'}`,pl);
  streetHL(o.list.map(s=>s.pts));const z=Math.max(view.zoom,4),f=framed(...lift(best[0],best[1]),z);flyTo(f[0],f[1],z);}
function showCorner(a,b,p){const A=streetNames().get(a),B=streetNames().get(b);streetHL(null);
  ring.visible=true;ring.position.set(p[0],E(p[0],p[1])+1,-p[1]);ring.userData.t0=performance.now();
  const pl=POIS.filter(q=>{const m=MODELS[q.id]||q;return Math.hypot(m.x-p[0],m.y-p[1])<150;});
  placeCard(`${A.n} con ${B.n}`,'Esquina',null,pl.length?'Lugares a menos de 150 m:':'Ningún lugar del mapa a menos de 150 m.',pl);
  const z=Math.max(view.zoom,5),f=framed(...lift(p[0],p[1]),z);flyTo(f[0],f[1],z);}
// the search's streets and corners, after the places (renderList)
function streetResults(q,host){if(q.length<3)return;const m=q.match(/^(.+?)\s+(?:con|y|esq\.?|esquina|&|\/)\s+(.+)$/)||q.match(/^(.+?)\s*[&\/]\s*(.+)$/);
  const items=[];
  if(m){const a=nameFor(m[1]),b=nameFor(m[2]);if(a&&b&&a!==b){const P=corners(a,b);const N=streetNames();
    P.slice(0,3).forEach((p,i)=>items.push({h:'Esquinas',n:`${N.get(a).n} con ${N.get(b).n}`,ad:P.length>1?`${i+1} de ${P.length}`:'Esquina',go:()=>showCorner(a,b,p)}));}}
  if(!items.length){const N=streetNames(),k=normName(q).replace(/^(calle|avenida|av\.?|pasaje|psje\.?)\s+/,'');
    [...N.entries()].filter(([n])=>{const i=n.indexOf(k);return i===0||i>0&&/[\s(]/.test(n[i-1]);}).sort((x,y)=>(x[0]===k?-1:0)-(y[0]===k?-1:0)||x[1].c-y[1].c||x[1].d-y[1].d)
      .slice(0,6).forEach(([n,o])=>items.push({h:'Calles',n:o.n,ad:o.d<50?'pasa por el centro':`a ${fmtM(o.d)} de la plaza`,go:()=>showStreet(n)}));}
  if(!items.length)return;const g=document.createElement('div');g.className='group';g.style.setProperty('--cc','var(--ink-2)');
  g.innerHTML=`<h3><i></i>${items[0].h}</h3><ul>${items.map((it,i)=>`<li><button data-i="${i}"><span class="nm">${esc(it.n)}</span><span class="ad">${esc(it.ad)}</span></button></li>`).join('')}</ul>`;
  g.querySelectorAll('button').forEach(b=>b.onclick=()=>{if(matchMedia('(max-width:760px)').matches)$('#panel').classList.add('folded');items[+b.dataset.i].go();});
  host.appendChild(g);}
// a tour's walking route: the legs between its stops ({pts, len}, cached on the tour), drawn while the tour runs
function tourLegs(k){const T0=PD.tours[k];if(T0.legs)return T0.legs;
  if(!ROUTE_G){let x0=1e9,y0=1e9,x1=-1e9,y1=-1e9;for(const t of Object.values(PD.tours))for(const id of t.s){const m=MODELS[id]||BYID[id];
      x0=Math.min(x0,m.x);y0=Math.min(y0,m.y);x1=Math.max(x1,m.x);y1=Math.max(y1,m.y);}
    ROUTE_G=roadGraph([x0-500,y0-500,x1+500,y1+500],{cmax:7,merge:2,bridges:true,main:true});}
  const at=id=>{const m=MODELS[id]||BYID[id];return [m.x,m.y];};
  return T0.legs=T0.s.map((id,i)=>i?roadPath(ROUTE_G,...at(T0.s[i-1]),...at(id)):null);}
function tourRoute(k){if(ROUTE&&ROUTE.k===k)return;if(ROUTE){scene.remove(ROUTE.m);ROUTE.m.geometry.dispose();ROUTE=null;dirty=true;}if(k==null)return;
  const lines=tourLegs(k).filter(Boolean).map(l=>l.pts),w=lineW(ROUTE_W,ART);ROUTE={k,lines,art:ART,m:routeRibbon(lines,w,[w*1.6,w*1.1],matRoute)};scene.add(ROUTE.m);dirty=true;}
// the card's line for stop i of tour k: how far from the previous stop
function legText(k,i){if(!i||!PD.tours[k].legs)return '';const l=PD.tours[k].legs[i];if(!l)return '';const min=Math.max(1,Math.round(l.len/WALK_MPM));
  return `Desde ${BYID[PD.tours[k].s[i-1]].n}: ${fmtM(l.len)} por las calles, unos ${min<60?min+' minutos':(min/60).toFixed(1).replace('.',',')+' horas'} a pie.`;}
window.__calles={names:()=>streetNames().size,find:q=>nameFor(q),corners:(a,b)=>corners(nameFor(a),nameFor(b)).map(p=>p.map(Math.round)),
  legs:k=>tourLegs(k).map(l=>l&&Math.round(l.len)),graph:()=>ROUTE_G&&{nodes:ROUTE_G.nodes.length,edges:ROUTE_G.edges.length,ms:ROUTE_G.ms},
  street:q=>{const n=nameFor(q);if(n)showStreet(n);return n;},corner:(a,b)=>{const A=nameFor(a),B=nameFor(b),P=corners(A,B);if(P[0])showCorner(A,B,P[0]);return P.length;}};
