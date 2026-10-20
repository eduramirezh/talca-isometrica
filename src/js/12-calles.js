/* =============== streets as a graph: names, crossings, corners, routes =============== */
// The streets of DATA.streets (the road graph of cicloconecta and, in the countryside, of OSM) are polylines cut where
// another one ends, but not always where two cross: 3 Norte crosses 4 Poniente without a common vertex, and joined by
// their ends only the centre fell apart (the game of 96-completos.js found it: 130 of some 400 corners in one piece).
// The drawing does not mind (the sidewalks and crosswalks of 60-streets.js find the crossings by geometry), but what
// walks the streets as a graph does: roadGraph() nodes them, here, for the game, the search of corners (corners(),
// 92-panel.js) and the walking routes of the tours (roadPath()).
// streetName(s): the name to show. The placeholders of the source ("Calle sin nombre", 2,508 pieces, 105 of them of
// class 0-3, which the street labels used to show) are no name; "Calle 3½ Sur" and "Avenida 1 Oriente" are "3½ Sur"
// and "1 Oriente", as the labels already did for the whole numbers; the Alameda, "Alameda".
const NO_NAME=/^\s*(calle\s+)?sin\s+nombre\s*$/i;
function streetName(s){if(s.nm!==undefined)return s.nm;const n=s.name||'';
  return s.nm=NO_NAME.test(n)||!n.trim()?null:n.replace(/^(Calle|Avenida) (?=\d+½?\s)/,'').replace("Avenida Alameda Bernardo O'Higgins",'Alameda');}
// roadGraph(box, o): the streets of class <= o.cmax (5) with a point in box [x0, y0, x1, y1] (o.within: all their
// points; the others are cut there and leave a stub [inner point, next point out, width] for those of class <= 4),
// noded at every crossing of two segments and at every end that stops within 1.5 m of another (a T), each crossing one
// point that both streets take. Nodes nearer than o.merge metres are one (10 for the game: the corners of a traffic
// island, no ring shorter than its row). o.core: without dead ends (the 2-core) and only the largest connected part;
// o.main: only the largest connected part, with its dead ends; o.bridges: also the streets a landmark draws as a
// bridge. Edges: {a, b, pts, cum, len, name, c, w, bridge};
// nodes: {x, y, adj: [{e, fwd}]}.
function roadGraph(box,o={}){const t0=performance.now(),cmax=o.cmax??5,merge=o.merge??2;
  const [ax0,ay0,ax1,ay1]=box,inA=p=>p[0]>=ax0&&p[0]<=ax1&&p[1]>=ay0&&p[1]<=ay1,key=p=>Math.round(p[0]*2)+','+Math.round(p[1]*2);
  const near=p=>p[0]>=ax0-50&&p[0]<=ax1+50&&p[1]>=ay0-50&&p[1]<=ay1+50;
  const SS=streets.filter(s=>s.c<=cmax&&(o.bridges||!s.bridge)&&s.pts.length>1&&s.pts.some(near));
  const segs=[],cell=new Map();
  SS.forEach((s,si)=>{for(let i=0;i<s.pts.length-1;i++){const a=s.pts[i],b=s.pts[i+1],k=segs.length;segs.push([si,i,a,b]);
    for(let gx=Math.floor(Math.min(a[0],b[0])/50);gx<=Math.floor(Math.max(a[0],b[0])/50);gx++)for(let gy=Math.floor(Math.min(a[1],b[1])/50);gy<=Math.floor(Math.max(a[1],b[1])/50);gy++){
      const c=gx+','+gy;if(!cell.has(c))cell.set(c,[]);cell.get(c).push(k);}}});
  const cuts=SS.map(()=>[]),done=new Set();
  for(const ks of cell.values())for(let x=0;x<ks.length;x++)for(let y=x+1;y<ks.length;y++){const k1=ks[x],k2=ks[y],pk=k1*1e6+k2;if(done.has(pk))continue;done.add(pk);
    const [s1,i1,a,b]=segs[k1],[s2,i2,c,d]=segs[k2];if(s1===s2)continue;
    const rx=b[0]-a[0],ry=b[1]-a[1],sx=d[0]-c[0],sy=d[1]-c[1],den=rx*sy-ry*sx;if(Math.abs(den)<1e-9)continue;
    const t=((c[0]-a[0])*sy-(c[1]-a[1])*sx)/den,u=((c[0]-a[0])*ry-(c[1]-a[1])*rx)/den,e1=1.5/Math.hypot(rx,ry),e2=1.5/Math.hypot(sx,sy);
    if(t<-e1||t>1+e1||u<-e2||u>1+e2)continue;
    let P=[a[0]+rx*t,a[1]+ry*t];for(const q of [a,b,c,d])if(Math.hypot(q[0]-P[0],q[1]-P[1])<1.6){P=q;break;}
    cuts[s1].push([i1,P]);cuts[s2].push([i2,P]);}
  const pts=new Map(),addP=p=>{const k=key(p);if(!pts.has(k))pts.set(k,p);return k;};
  const nk=SS.map((s,si)=>{const n=new Set([addP(s.pts[0]),addP(s.pts[s.pts.length-1])]);for(const [,P] of cuts[si])n.add(addP(P));return n;});
  const par=new Map(),find=k=>{while(par.has(k)&&par.get(k)!==k)k=par.get(k);return k;};
  const NK=[...new Set(nk.flatMap(n=>[...n]))];
  if(merge>0){const ng=new Map(),cg=p=>[Math.floor(p[0]/merge),Math.floor(p[1]/merge)];
    for(const k of NK){const [cx,cy]=cg(pts.get(k)),c=cx+','+cy;if(!ng.has(c))ng.set(c,[]);ng.get(c).push(k);}
    for(const k of NK){const p=pts.get(k),[cx,cy]=cg(p);
      for(let gx=cx-1;gx<=cx+1;gx++)for(let gy=cy-1;gy<=cy+1;gy++)for(const q0 of ng.get(gx+','+gy)||[]){if(q0===k)continue;const q=pts.get(q0);
        if(Math.hypot(p[0]-q[0],p[1]-q[1])<merge){const r1=find(k),r2=find(q0);if(r1!==r2)par.set(r2,r1);}}}}
  const nodes=new Map(),node=k=>{const r=find(k);let n=nodes.get(r);if(!n){const p=pts.get(r);nodes.set(r,n={x:p[0],y:p[1],adj:[],k:r});}return n;};
  const edges=[],stubs=[];
  const add=(q,s)=>{
    if(!q.every(inA)){if(o.within){if(s.c<=4){if(inA(q[0]))stubs.push([q[0],q[1],swOf(s)]);if(inA(q[q.length-1]))stubs.push([q[q.length-1],q[q.length-2],swOf(s)]);}return;}
      if(!q.some(inA))return;}
    const a=node(key(q[0])),b=node(key(q[q.length-1]));q=q.slice();q[0]=[a.x,a.y];q[q.length-1]=[b.x,b.y];
    let L=0;const cum=[0];for(let i=1;i<q.length;i++){L+=Math.hypot(q[i][0]-q[i-1][0],q[i][1]-q[i-1][1]);cum.push(L);}
    if(a===b&&L<120||L<.5)return; // a ring inside a node
    edges.push({a,b,pts:q,cum,len:L,name:streetName(s),c:s.c,w:swOf(s),bridge:!!s.bridge});};
  SS.forEach((s,si)=>{const by=new Map();for(const [i,P] of cuts[si]){if(!by.has(i))by.set(i,[]);by.get(i).push(P);}
    const seq=[];for(let i=0;i<s.pts.length-1;i++){const a=s.pts[i];seq.push(a);for(const P of (by.get(i)||[]).sort((p,q)=>Math.hypot(p[0]-a[0],p[1]-a[1])-Math.hypot(q[0]-a[0],q[1]-a[1])))seq.push(P);}
    seq.push(s.pts[s.pts.length-1]);const q=[seq[0]];for(const v of seq.slice(1))if(key(v)!==key(q[q.length-1]))q.push(v);
    let cur=[q[0]];for(let j=1;j<q.length;j++){cur.push(q[j]);const k=key(q[j]);
      if(j===q.length-1||nk[si].has(k)&&find(k)!==find(key(cur[0]))){add(cur,s);cur=[q[j]];}}});
  for(const e of edges){e.a.adj.push({e,fwd:true});e.b.adj.push({e,fwd:false});}
  let N=[...nodes.values()].filter(n=>n.adj.length),E2=edges;
  if(o.core||o.main){ // o.core: without dead ends (a node with one street end left goes, with its street: a stub at
    // the other end's mouth); both: only the largest connected part
    const dead=new Set(),stack=o.core?N.filter(n=>n.adj.length<2):[];
    while(stack.length){const n=stack.pop();if(n.adj.length>=2||n.gone)continue;n.gone=true;
      for(const {e} of n.adj){if(dead.has(e))continue;dead.add(e);const m=e.a===n?e.b:e.a;m.adj=m.adj.filter(a=>a.e!==e);
        if(e.c<=4&&!m.gone){const p=e.a===m?e.pts[1]:e.pts[e.pts.length-2];stubs.push([[m.x,m.y],p,e.w]);}
        if(m.adj.length<2)stack.push(m);}}
    let best=null;const seen=new Set();
    for(const n of N){if(n.gone||seen.has(n))continue;const comp=[n];seen.add(n);
      for(let i=0;i<comp.length;i++)for(const {e} of comp[i].adj){const m=e.a===comp[i]?e.b:e.a;if(!seen.has(m)){seen.add(m);comp.push(m);}}
      if(!best||comp.length>best.length)best=comp;}
    const keep=new Set(best);N=best;E2=edges.filter(e=>!dead.has(e)&&keep.has(e.a)&&keep.has(e.b));}
  const ns=new Set(N.map(n=>n.k)),S2=stubs.filter(s=>ns.has(key(s[0])));
  let total=0;for(const e of E2)total+=e.len;
  return {nodes:N,edges:E2,stubs:S2,total,ms:Math.round(performance.now()-t0)};}
// a point at distance s along e, travelled forward (a -> b) or not
function edgeAt(e,fwd,s){const S=fwd?s:e.len-s,c=e.cum;let lo=0,hi=c.length-1;if(S<=0)return e.pts[0];if(S>=e.len)return e.pts[c.length-1];
  while(hi-lo>1){const m=(lo+hi)>>1;if(c[m]<=S)lo=m;else hi=m;}const t=(S-c[lo])/((c[hi]-c[lo])||1),a=e.pts[lo],b=e.pts[hi];
  return [a[0]+(b[0]-a[0])*t,a[1]+(b[1]-a[1])*t];}
// the point of the graph nearest to (x, y): its edge and the distance along it (forward)
function roadSnap(g,x,y){let best=null,bd=1e18;
  for(const e of g.edges){const P=e.pts;for(let i=0;i<P.length-1;i++){const a=P[i],b=P[i+1],dx=b[0]-a[0],dy=b[1]-a[1],L2=dx*dx+dy*dy||1;
    const t=Math.max(0,Math.min(1,((x-a[0])*dx+(y-a[1])*dy)/L2)),px=a[0]+dx*t,py=a[1]+dy*t,d=(px-x)**2+(py-y)**2;
    if(d<bd){bd=d;best={e,s:e.cum[i]+(e.cum[i+1]-e.cum[i])*t,p:[px,py],d:Math.sqrt(d)};}}}
  return best;}
// the shortest way along the streets from (x0, y0) to (x1, y1) (Dijkstra from the nearest point of each): {pts, len}
// (the walk from each point to its street included), or null if they are not connected
function roadPath(g,x0,y0,x1,y1){const A=roadSnap(g,x0,y0),B=roadSnap(g,x1,y1);if(!A||!B)return null;
  const sub=(e,s0,s1)=>{const o=[edgeAt(e,true,s0)];if(s0<s1){for(let i=0;i<e.cum.length;i++)if(e.cum[i]>s0&&e.cum[i]<s1)o.push(e.pts[i]);}
    else for(let i=e.cum.length-1;i>=0;i--)if(e.cum[i]<s0&&e.cum[i]>s1)o.push(e.pts[i]);o.push(edgeAt(e,true,s1));return o;};
  const fin=pts=>{pts.unshift([x0,y0]);pts.push([x1,y1]);let L=0;const q=[pts[0]];
    for(const p of pts.slice(1)){const l=q[q.length-1],d=Math.hypot(p[0]-l[0],p[1]-l[1]);if(d<.3)continue;L+=d;q.push(p);}return {pts:q,len:L};};
  if(A.e===B.e)return fin(sub(A.e,A.s,B.s));
  // Dijkstra over the nodes, from both ends of A's edge
  const dist=new Map(),prev=new Map(),H=[],push=(n,d)=>{H.push([d,n]);let i=H.length-1;while(i>0){const p=(i-1)>>1;if(H[p][0]<=H[i][0])break;[H[p],H[i]]=[H[i],H[p]];i=p;}};
  const pop=()=>{const t=H[0],l=H.pop();if(H.length){H[0]=l;let i=0;for(;;){const a=2*i+1,b=a+1;let m=i;if(a<H.length&&H[a][0]<H[m][0])m=a;if(b<H.length&&H[b][0]<H[m][0])m=b;if(m===i)break;[H[m],H[i]]=[H[i],H[m]];i=m;}}return t;};
  const relax=(n,d,p)=>{if(d<(dist.get(n)??1e18)){dist.set(n,d);prev.set(n,p);push(n,d);}};
  relax(A.e.a,A.s,{start:true});relax(A.e.b,A.e.len-A.s,{start:true});
  const goal=new Map([[B.e.a,B.s],[B.e.b,B.e.len-B.s]]);let bestEnd=null,bestD=1e18;
  while(H.length){const [d,n]=pop();if(d>(dist.get(n)??1e18))continue;if(d>=bestD)break;
    if(goal.has(n)&&d+goal.get(n)<bestD){bestD=d+goal.get(n);bestEnd=n;}
    for(const {e,fwd} of n.adj){if(e===A.e||e===B.e)continue;relax(fwd?e.b:e.a,d+e.len,{e,fwd,from:n});}}
  if(!bestEnd)return null;
  const chain=[];for(let n=bestEnd;;){const p=prev.get(n);if(p.start){chain.push({start:n});break;}chain.push(p);n=p.from;}chain.reverse();
  const first=chain[0].start,pts=sub(A.e,A.s,first===A.e.a?0:A.e.len);
  for(const st of chain.slice(1)){const P=st.fwd?st.e.pts:st.e.pts.slice().reverse();pts.push(...P.slice(1));}
  pts.push(...sub(B.e,bestEnd===B.e.a?0:B.e.len,B.s).slice(1));
  return fin(pts);}
// the corners of the streets named a and b (their names to show, compared without accents or case): the points where
// one of their segments crosses one of the other's (or ends within 3 m of it), one per 30 m, the nearest to the plaza first
function corners(a,b){const nm=s=>{const n=streetName(s);return n&&normName(n);},A=[],B=[];
  for(const s of streets){const n=nm(s);if(!n||s.c>6)continue;if(n===a)A.push(s);else if(n===b)B.push(s);}
  const out=[];for(const s of A)for(const t of B)for(let i=0;i<s.pts.length-1;i++)for(let j=0;j<t.pts.length-1;j++){
    const a0=s.pts[i],a1=s.pts[i+1],b0=t.pts[j],b1=t.pts[j+1],rx=a1[0]-a0[0],ry=a1[1]-a0[1],sx=b1[0]-b0[0],sy=b1[1]-b0[1],den=rx*sy-ry*sx;if(Math.abs(den)<1e-9)continue;
    const u=((b0[0]-a0[0])*sy-(b0[1]-a0[1])*sx)/den,v=((b0[0]-a0[0])*ry-(b0[1]-a0[1])*rx)/den,e1=3/Math.hypot(rx,ry),e2=3/Math.hypot(sx,sy);
    if(u<-e1||u>1+e1||v<-e2||v>1+e2)continue;const p=[a0[0]+rx*u,a0[1]+ry*u];if(!out.some(q=>Math.hypot(q[0]-p[0],q[1]-p[1])<30))out.push(p);}
  return out.sort((p,q)=>Math.hypot(...p)-Math.hypot(...q));}
function normName(s){return s.normalize('NFD').replace(/[̀-ͯ]/g,'').toLowerCase().replace(/\s+/g,' ').trim();}
