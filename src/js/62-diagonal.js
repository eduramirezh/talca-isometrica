// ==== the Diagonal ====
// The Diagonal (Avenida Isidoro del Solar), from the Plaza de Armas' north-west corner to 3 Poniente by the Alameda,
// modelled like a landmark (METODOLOGIA §9) on its median, "Alameda Isidoro del Solar" in OpenStreetMap (park
// w588773712; walks w364439680, w364439682, w364439684, paving stones) between the one-way carriageways of the map,
// which are OSM's (south-west w853028111, w564504069, w111123036; north-east w1022644658, w33885412, w853028112,
// w1022644659). Satellite (Esri) and photos on Commons (2011-2017, diagnostics/fotos/diagonal/indice.txt): a paved
// walk down the middle between planting strips with low shrubs, two rows of tall trees whose crowns close over the walk
// and reach the carriageways (a tunnel of green in the photos), lamps, and more trees in rows on the outer sidewalks
// (STREET_W). The median stops at the crossing streets. Flat layers draped into the ground at CURB_Y beside each other;
// shrubs and lamps on D. Approximate: the widths (carriageways 5.5 m, one lane and parking; the median is what is left,
// 4-9 m), the trees' spacing (7 m) and species, the shrubs, the lamps (every 30 m on the walk's edge; the flower beds
// of the Alameda end in 2013 are left out).
const DIAG={a:[-72,64],b:[-440,469],ne:[[-62,74],[-71,81],[-173,191],[-192,213],[-311,345],[-417,458]],cw:2.75,runs:[]};
(()=>{const [ax,ay]=DIAG.a,L=Math.hypot(DIAG.b[0]-ax,DIAG.b[1]-ay),tx=(DIAG.b[0]-ax)/L,ty=(DIAG.b[1]-ay)/L,nx=ty,ny=-tx;
  Object.assign(DIAG,{L,uv:(x,y)=>[(x-ax)*tx+(y-ay)*ty,(x-ax)*nx+(y-ay)*ny],P:(u,v)=>[ax+tx*u+nx*v,ay+ty*u+ny*v]});
  const ne=DIAG.ne.map(p=>DIAG.uv(...p)); // the north-east carriageway's axis in (u along the Diagonal, v towards it)
  DIAG.vNE=u=>{for(let i=0;i+1<ne.length;i++){const [u0,v0]=ne[i],[u1,v1]=ne[i+1];if((u-u0)*(u-u1)<=0)return v0+(v1-v0)*(u-u0)/((u1-u0)||1);}return null;};})();
// is (x, y) on the Diagonal's median (once diagonalBase has found its runs)?
function inMedian(x,y){const [u,v]=DIAG.uv(x,y);if(v<DIAG.cw||v>16)return false;
  for(const [u0,u1] of DIAG.runs)if(u>=u0&&u<=u1)return v<=DIAG.vNE(u)-DIAG.cw;return false;}
function diagonalBase(G,D){const B=draped(G),{P,cw,L}=DIAG,K={curb:hex('#E8E5DC'),bed:hex('#6F8748'),walk:hex('#CFC7B6'),walk2:hex('#C4BBA8'),
    shrub:hex('#4E6A36'),shrub2:hex('#5C7A3E'),iron:hex('#3B4240'),lamp:hex('#F1E6C4')},r=rng(4242);
  const cross=([x,y])=>{const gx=Math.floor((x-XMIN)/SG),gy=Math.floor((y-YMIN)/SG);if(gx<0||gy<0||gx>=sgW||gy>=sgH)return true;
    for(const id of sgrid[gy*sgW+gx]){const s=segs[id],st=streets[s[5]];if(st.c>=6||st.rows)continue;const R=s[4]+0.5;if(segDist2(x,y,s[0],s[1],s[2],s[3])<R*R)return true;}
    return occAt(x,y)===1;};
  const ok=u=>{const v1=DIAG.vNE(u);if(v1===null||v1-2*cw<4)return false;return !cross(P(u,cw+.3))&&!cross(P(u,v1-cw-.3))&&!cross(P(u,v1/2));};
  // runs of median between the crossing streets, their ends found by bisection
  let prev=ok(0),u0=0;const ST=2;
  for(let u=ST;u<=L+1e-6;u+=ST){const cur=ok(u);if(cur!==prev){let lo=u-ST,hi=u;for(let t=0;t<6;t++){const m=(lo+hi)/2;if(ok(m)===prev)lo=m;else hi=m;}
      if(prev){if(lo-u0>6)DIAG.runs.push([u0,lo]);}else u0=hi;}prev=cur;}
  if(prev&&L-u0>6)DIAG.runs.push([u0,L]);
  let nt=0;
  for(const [a,b] of DIAG.runs){const n=Math.ceil((b-a)/2.5),us=[...Array(n+1)].map((_,k)=>a+(b-a)*k/n);
    const m1=u=>DIAG.vNE(u)-cw,mid=u=>(cw+m1(u))/2;
    const strip=(u0,u1,f0,f1,col)=>B.quadXY([P(u0,f0(u0)),P(u1,f0(u1)),P(u1,f1(u1)),P(u0,f1(u0))],CURB_Y,col);
    for(let k=0;k<n;k++){const p=us[k],q=us[k+1],pi=Math.max(p,a+.5),qi=Math.min(q,b-.5);
      occMark([P(p,cw-.75),P(q,cw-.75),P(q,m1(q)+.75),P(p,m1(p)+.75)]);
      strip(p,q,()=>cw,()=>cw+.5,K.curb);strip(p,q,u=>m1(u)-.5,m1,K.curb);
      strip(pi,qi,()=>cw+.5,u=>mid(u)-1.2,K.bed);strip(pi,qi,u=>mid(u)+1.2,u=>m1(u)-.5,K.bed);
      strip(pi,qi,u=>mid(u)-1.2,u=>mid(u)+1.2,Math.floor(p/2.5)%2?K.walk:K.walk2);}
    for(const u of [a,b-.5])strip(u,u+.5,()=>cw+.5,u=>m1(u)-.5,K.curb);
    // two rows of trees, staggered, in the planting strips; shrubs between them; lamps on the walk's edge
    for(const [side,ph] of [[-1,0],[1,3.5]]){const bedC=u=>side<0?(cw+.5+mid(u)-1.2)/2:(mid(u)+1.2+m1(u)-.5)/2,bedW=u=>(m1(u)-cw-3.4)/2;
      for(let u=a+3+ph;u<b-2.5;u+=7){if(r()<.06)continue;const [x,y]=P(u+(r()-.5)*.8,side<0?Math.min(bedC(u),mid(u)-1.7):Math.max(bedC(u),mid(u)+1.7));TREES.push([x,y,1+r()*.35,.6+r()*.25]);nt++;}
      for(let u=a+6.5+ph;u<b-2.5;u+=7){const w=Math.max(.6,bedW(u)-.4),c=bedC(u),q=[P(u-.9,c-w/2),P(u+.9,c-w/2),P(u+.9,c+w/2),P(u-.9,c+w/2)];
        D.dy=Math.min(...q.map(p=>E(p[0],p[1])))+CURB_Y;D.prism(q,0,.55,K.shrub,K.shrub2);}}
    for(let u=a+12;u<b-4;u+=30){const [x,y]=P(u,mid(u)+1.45),q=rotRect(x,y,.3,.3),h=E(x,y)+CURB_Y;D.dy=h;
      D.prism(q,0,4.6,K.iron,K.iron);D.prism(rotRect(x,y,.9,.9),4.6,5,K.iron,K.lamp);GLOW.push(x,h+4.8,y);}}
  D.dy=0;Object.assign(STREET,{diagonal:DIAG.runs.length,diagTrees:nt});}
