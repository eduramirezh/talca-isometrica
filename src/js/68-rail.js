// The Ruta 5 and the railway, each in a function of its own so that they can be worked on apart from the streets.
// Ruta 5: above («Ruta 5», ruta5Base). Rail: below (railBase).
// The railway (docs/PLAN-TREN.md): the Línea Central (DATA.rail; broad gauge, electrified) and the ramal a
// Constitución (DATA.ramal; metre gauge), from OpenStreetMap through pipeline/railway.py, plus the yard tracks a
// landmark lays (RAIL_YARD: the station's). Each line is sampled every RS m along its smoothed axis, with a height
// profile T (the top of the ballast). On the ground the track is draped: ballast 0.2 (gravel on the Línea Central,
// earth on the ramal, as in the photos), sleepers 0.22 (concrete or wood; one every 1.4 m, 0.7 m wide: the real
// 0.6 m spacing would be noise at 0.5 m art pixels), rails 0.24, 0.4 m wide. Where a street passes under the line
// (DATA.railx type 0: OSM's bridge=yes on the rail or tunnel=yes on the street; 1 Norte, 2 Norte, 1 Sur, the Alameda,
// 6 Sur, 8 Sur and one north of the Lircay) the street cannot be lowered (the terrain is a 40 m mesh), so the line
// rises RAIL_HU m on an embankment with ramps of 1:RAIL_G and crosses it on a white deck with balustrades (the 1 Sur
// underpass, photos of 2014); lifts less than RAIL_FILL m apart are joined. The river bridges are hito blocks that
// register in RAIL_BR ({line, a, b, hb: the deck over the higher bank, draw(G, hAt)}): they lift the profile like a
// deck and are drawn here, on the final ground (railBase runs after the pads and before the city, so it can still
// mark occ). At a level crossing (types 1, 2) the ballast stops at the carriageway and the rails cross it on a panel;
// type 1 has barriers (raised) and St Andrew's crosses with lights. Catenary masts (DATA.rmast, OSM's) with their
// cantilevers on the Línea Central; signals (DATA.rsig) lit at night. The raised parts
// and everything standing are one mesh of their own (not draped), which casts shadows. RAILP keeps each line as a
// sampled path {x, y, s, h: the railhead's height, kind: 0 ground, 1 embankment, 2 deck, 3 bridge, 4 level crossing}
// for the train (window.__rail).
const RAIL_BR=[],RAIL_YARD=[],RAILP={};
const RAIL_HU=3,RAIL_G=16,RAIL_FILL=160,RS=0.7,RAIL_Y=0.2;
function railSample(pts,step){const P=[];let s=0;
  for(let i=0;i<pts.length-1;i++){const a=pts[i],b=pts[i+1],L=Math.hypot(b[0]-a[0],b[1]-a[1]);if(L<1e-6)continue;
    const n=Math.max(1,Math.round(L/step)),dx=(b[0]-a[0])/L,dy=(b[1]-a[1])/L;
    for(let k=P.length?1:0;k<=n;k++)P.push({x:a[0]+(b[0]-a[0])*k/n,y:a[1]+(b[1]-a[1])*k/n,dx,dy,nx:-dy,ny:dx,s:s+L*k/n});s+=L;}
  return P;}
function railBase(B){const t0=performance.now(),R=new GB(1<<16),RX=DATA.railx||[];
  const K={earth:hex('#A08D72'),bank:hex('#A4A273'),bank2:hex('#999767'),white:hex('#E6E1D6'),white2:hex('#CFC9BC'),gap:hex('#7E7A73'),
    panel:hex('#7A756D'),mast:hex('#A9A59C'),arm:hex('#6E7275'),head:hex('#2E2C2B'),red:hex('#C8503A'),post:hex('#ECE7DC'),box:hex('#8C8A84')};
  const LINES=[{k:'main',i:0,d:DATA.rail,g:(DATA.rgauge||[1.676])[0],bw:4.6,bal:PAL.ballast,sl:hex('#9C9486')},
    {k:'ramal',i:1,d:DATA.ramal,g:(DATA.rgauge||[0,1])[1],bw:3.4,bal:K.earth,sl:hex('#806B55')}];
  const V=(x,y,h)=>[x,h,-y],Q=(p,off,h)=>V(p.x+p.nx*off,p.y+p.ny*off,h);
  const near=(P,x,y,i0=0,i1=P.length-1)=>{let b=i0,bd=1e18;for(let i=i0;i<=i1;i++){const d=(P[i].x-x)**2+(P[i].y-y)**2;if(d<bd){bd=d;b=i;}}return b;};
  // the map street under a point: its direction and width
  const streetAt=(x,y)=>{const gx=Math.floor((x-XMIN)/SG),gy=Math.floor((y-YMIN)/SG);let s=null,bd=1e18;
    if(gx>=0&&gy>=0&&gx<sgW&&gy<sgH)for(const id of sgrid[gy*sgW+gx]){const q=segs[id],d=segDist2(x,y,q[0],q[1],q[2],q[3]);if(d<bd){bd=d;s=q;}}
    if(!s)return null;const L=Math.hypot(s[2]-s[0],s[3]-s[1])||1;return {ux:(s[2]-s[0])/L,uy:(s[3]-s[1])/L,w:s[4]*2};};
  const runs=(i0,i1,test)=>{const o=[];let a=-1;for(let i=i0;i<=i1+1;i++){const ok=i<=i1&&test(i);if(ok&&a<0)a=i;if(!ok&&a>=0){if(i-1>a)o.push([a,i-1]);a=-1;}}return o;};
  const poly=(P,a,b)=>{const o=[];for(let i=a;i<b;i+=6)o.push([P[i].x,P[i].y]);o.push([P[b].x,P[b].y]);return o;};
  // a sleeper across sample p (0.7 m along the line, the gauge plus 1 m across)
  const sleeperQ=(p,L)=>{const h=L.g/2+.5,u=.35;return [[p.x-p.dx*u-p.nx*h,p.y-p.dy*u-p.ny*h],[p.x+p.dx*u-p.nx*h,p.y+p.dy*u-p.ny*h],
    [p.x+p.dx*u+p.nx*h,p.y+p.dy*u+p.ny*h],[p.x-p.dx*u+p.nx*h,p.y-p.dy*u+p.ny*h]];};
  // a draped track over samples a..b: ballast, a sleeper every other sample, the rails; where xing(i) (a level
  // crossing) a panel on the carriageway instead of ballast and sleepers
  const flatTrack=(P,a,b,L,xing=()=>false)=>{
    for(const [c,d] of runs(a,b,i=>!xing(i)))ribbon(B,poly(P,c,d),L.bw,RAIL_Y,L.bal,false);
    for(const [c,d] of runs(a,b,xing))ribbon(B,poly(P,c,d),L.bw-.6,RAIL_Y-.01,K.panel,false);
    for(let i=a;i<=b;i+=2)if(!xing(i))B.quadXY(sleeperQ(P[i],L),RAIL_Y+.02,L.sl);
    for(const sd of [1,-1])sideRibbon(B,poly(P,a,b),sd,L.g/2-.2,.4,RAIL_Y+.04,PAL.rail);};
  const done=[];
  for(const L of LINES){if(!L.d||L.d.length<4)continue;
    const P=railSample(chaikin(dec(L.d),2),RS),N=P.length,hwD=L.bw/2+.5;
    // lifts: a deck over each street that passes under the line (two carriageways make one), and the river bridges
    const lifts=[];
    for(const [t,li,x,y] of RX){if(t||li!==L.i)continue;const p=P[near(P,x,y)],st=streetAt(x,y);if(!st)continue;
      const sn=Math.max(.35,Math.abs(p.dx*st.uy-p.dy*st.ux)),cs=Math.abs(p.dx*st.ux+p.dy*st.uy),half=(st.w/2+1.2)/sn+hwD*cs/sn+.5;
      lifts.push({s0:p.s-half,s1:p.s+half,H:E(x,y)+RAIL_HU,deck:true});}
    lifts.sort((a,b)=>a.s0-b.s0);
    for(let j=lifts.length-1;j>0;j--){const a=lifts[j-1],b=lifts[j];if(b.s0<=a.s1+3){a.s1=Math.max(a.s1,b.s1);a.H=Math.max(a.H,b.H);lifts.splice(j,1);}}
    for(const br of RAIL_BR)if(br.line===L.k){const ia=near(P,...br.a),ib=near(P,...br.b);
      lifts.push(br.lift={s0:Math.min(P[ia].s,P[ib].s),s1:Math.max(P[ia].s,P[ib].s),i0:Math.min(ia,ib),i1:Math.max(ia,ib),H:Math.max(E(...br.a),E(...br.b))+br.hb,br});}
    // the profile: the ground, the lifts with their ramps, and the gaps between close lifts filled
    const TH=new Float32Array(N),GR=new Float32Array(N),kind=new Uint8Array(N);
    for(let i=0;i<N;i++){const p=P[i],s=p.s,g=E(p.x,p.y);GR[i]=g;let t=g+RAIL_Y,Lh=-1e9,Rh=-1e9,k=0;
      for(const f of lifts){if(s>=f.s0&&s<=f.s1){t=Math.max(t,f.H);k=f.br?3:2;continue;}
        const d=s<f.s0?f.s0-s:s-f.s1;t=Math.max(t,f.H-d/RAIL_G);if(d<RAIL_FILL){if(s>f.s1)Lh=Math.max(Lh,f.H);else Rh=Math.max(Rh,f.H);}}
      TH[i]=Math.max(t,Math.min(Lh,Rh));kind[i]=k||(TH[i]>g+RAIL_Y+.04?1:0);}
    const LX=RX.filter(r=>r[0]&&r[1]===L.i);
    for(let i=0;i<N;i++)if(!kind[i]&&LX.some(r=>Math.hypot(P[i].x-r[2],P[i].y-r[3])<30)&&nearStreet(P[i].x,P[i].y,.3))kind[i]=4;
    // no lots or trees on the ramal (the main line's band is linesOcc's) nor on the embankments
    if(L.k!=='main')for(let i=0;i+6<N;i+=6)occBand([P[i].x,P[i].y],[P[i+6].x,P[i+6].y],4);
    for(let i=0;i+2<N;i+=2)if(kind[i]===1||kind[i]===2)occBand([P[i].x,P[i].y],[P[i+2].x,P[i+2].y],hwD+2+1.5*(TH[i]-GR[i]-RAIL_Y));
    // on the ground: draped; over a level crossing, rails on a panel and no ballast
    for(const [a,b] of runs(0,N-1,i=>kind[i]===0||kind[i]===4))flatTrack(P,a,b,L,i=>kind[i]===4);
    // raised: the embankment (top, shoulders, slopes in two tones every 4 m) or the deck over a street (ballast between
    // white parapets with balustrades: posts and gaps alternating every 0.7 m), and on both the sleepers and rails
    for(let i=0;i<N-1;i++){const ka=kind[i],kb=kind[i+1];if(!(ka&&ka!==4)&&!(kb&&kb!==4))continue;
      const a=P[i],b=P[i+1];if(!inTerrain(a.x,a.y))continue;const Ta=TH[i],Tb=TH[i+1],kk=ka===kb?ka:1;
      const top=(o0,o1,dh,col)=>R.face([Q(a,o0,Ta+dh),Q(b,o0,Tb+dh),Q(b,o1,Tb+dh),Q(a,o1,Ta+dh)],null,col);
      const side=(off,sg,d0,d1,col)=>R.face([Q(a,off,Ta+d0),Q(b,off,Tb+d0),Q(b,off,Tb+d1),Q(a,off,Ta+d1)],[a.nx*sg,0,-a.ny*sg],col);
      if(kk===1){top(-L.bw/2,L.bw/2,0,L.bal);const bc=Math.floor(a.s/4)%2?K.bank2:K.bank;
        for(const sg of [1,-1]){const o=sg*(L.bw/2+.6),ta=sg*(L.bw/2+.6+1.5*Math.max(0,Ta-GR[i]-RAIL_Y)+.3),tb=sg*(L.bw/2+.6+1.5*Math.max(0,Tb-GR[i+1]-RAIL_Y)+.3);
          top(sg*L.bw/2,o,0,bc);
          R.face([Q(a,o,Ta),Q(b,o,Tb),Q(b,tb,E(b.x+b.nx*tb,b.y+b.ny*tb)-.05),Q(a,ta,E(a.x+a.nx*ta,a.y+a.ny*ta)-.05)],null,bc);}}
      else if(kk===2){top(-hwD+.3,hwD-.3,0,L.bal);
        for(const sg of [1,-1]){side(sg*hwD,sg,-1.4,.15,K.white);side(sg*hwD,sg,.15,.85,i%2?K.gap:K.white);side(sg*hwD,sg,.85,1,K.white);
          side(sg*(hwD-.3),-sg,0,1,K.white2);top(sg*(hwD-.3),sg*hwD,1,K.white);}}
      for(const sg of [1,-1])top(sg*L.g/2-.2,sg*L.g/2+.2,.04,PAL.rail);
      if(i%2===0)R.face(sleeperQ(a,L).map(q=>V(q[0],q[1],Ta+.02)),[0,1,0],L.sl);}
    // the decks' abutments: white walls under each end, across the embankment
    for(const f of lifts)if(f.deck)for(const [s,sg] of [[f.s0,-1],[f.s1,1]]){const i=Math.min(N-1,Math.max(0,P.findIndex(p=>p.s>=s))),p=P[i];
      if(!inTerrain(p.x,p.y))continue;const q=rotRect(p.x+p.dx*sg*.5,p.y+p.dy*sg*.5,1,2*hwD+.6,Math.atan2(p.dy,p.dx));R.prism(q,groundMin(q)-.5,TH[i]-.02,K.white2,K.white);}
    // the river bridges, on the profile
    for(const f of lifts)if(f.br){const hAt=p=>TH[near(P,p.x,p.y,Math.max(0,f.i0-40),Math.min(N-1,f.i1+40))];f.br.draw(R,hAt);}
    const x=new Float32Array(N),y=new Float32Array(N),s=new Float32Array(N),h=new Float32Array(N);
    for(let i=0;i<N;i++){x[i]=P[i].x;y[i]=P[i].y;s[i]=P[i].s;h[i]=TH[i]+.04;}
    RAILP[L.k]={x,y,s,h,g:GR,kind,lifts:lifts.map(f=>({s0:f.s0,s1:f.s1,H:f.H,bridge:!!f.br}))};done.push({L,P,TH,kind,hwD});}
  // the catenary of the Línea Central: OSM's masts beside the track and a cantilever over it at 6.2 m; no contact wire
  // (~1.5 cm: drawn as one art pixel it broke into dashes, ESTETICA §2)
  const M=done.find(d=>d.L.k==='main');
  if(M&&DATA.rmast){const {P,TH,kind,L,hwD}=M;
    // none under the Ruta 5, which crosses over the line on its own bridge (its deck carries the wire there)
    const r5=dec(DATA.ruta5),underR5=m=>r5.some((q,j)=>j&&segDist2(m[0],m[1],r5[j-1][0],r5[j-1][1],q[0],q[1])<16*16);
    const ms=dec(DATA.rmast).filter(m=>inTerrain(m[0],m[1])&&!underR5(m)).map(m=>{const i=near(P,m[0],m[1]),p=P[i],min=kind[i]===2?hwD+.3:L.bw/2+.7;
      let off=(m[0]-p.x)*p.nx+(m[1]-p.y)*p.ny;if(Math.abs(off)<min)off=(off<0?-1:1)*min;return {i,off};}).sort((a,b)=>a.i-b.i);
    for(const m of ms){const p=P[m.i],t=TH[m.i],x=p.x+p.nx*m.off,y=p.y+p.ny*m.off,a=Math.atan2(p.dy,p.dx),sg=m.off<0?-1:1;
      R.prism(rotRect(x,y,.5,.5,a),Math.min(t,E(x,y))-.3,t+7.2,K.mast,K.mast);
      const ax=p.x-p.nx*sg*.8,ay=p.y-p.ny*sg*.8;R.prism(rotRect((x+ax)/2,(y+ay)/2,.4,Math.abs(m.off)+.8,a),t+6.2,t+6.6,K.arm,K.arm);}}
  // signals (OSM's light signals): a mast and a dark head with a red band, lit at night
  for(const [x0,y0] of DATA.rsig?dec(DATA.rsig):[]){if(!inTerrain(x0,y0))continue;let D=null,i=0,bd=1e18;
    for(const d of done){const j=near(d.P,x0,y0),e=(d.P[j].x-x0)**2+(d.P[j].y-y0)**2;if(e<bd){bd=e;D=d;i=j;}}
    if(!D)continue;const p=D.P[i],t=D.TH[i],min=D.L.bw/2+.8;let off=(x0-p.x)*p.nx+(y0-p.y)*p.ny;if(Math.abs(off)<min)off=(off<0?-1:1)*min;
    const x=p.x+p.nx*off,y=p.y+p.ny*off,a=Math.atan2(p.dy,p.dx);
    R.prism(rotRect(x,y,.35,.35,a),Math.min(t,E(x,y))-.3,t+4.2,K.mast,K.mast);R.prism(rotRect(x,y,.6,.7,a),t+4.2,t+5.7,K.head,K.head);
    R.prism(rotRect(x,y,.66,.76,a),t+5,t+5.4,K.red,K.head);GLOW.push(x,t+5.2,y);}
  // level crossings with barriers: on each approach, on the right of the road, a white post with a St Andrew's cross
  // and two red lights facing the traffic, and the barrier's box with its arm raised (red and white, 0.6 m bands)
  const LB=RX.filter(r=>r[0]===1),seen=new Set();
  for(const r of LB){if(seen.has(r))continue;const g=LB.filter(q=>Math.hypot(q[2]-r[2],q[3]-r[3])<15);g.forEach(q=>seen.add(q));
    const cx=g.reduce((a,q)=>a+q[2],0)/g.length,cy=g.reduce((a,q)=>a+q[3],0)/g.length,st=streetAt(cx,cy);if(!st)continue;
    const {ux,uy,w}=st,vx=-uy,vy=ux,ext=Math.max(...g.map(q=>Math.abs((q[2]-cx)*ux+(q[3]-cy)*uy)))+3.5,a=Math.atan2(uy,ux);
    for(const sg of [1,-1]){const x=cx+ux*sg*ext+vx*sg*(w/2+.9),y=cy+uy*sg*ext+vy*sg*(w/2+.9),e=E(x,y);
      R.prism(rotRect(x,y,.4,.4,a),e-.3,e+4.3,K.post,K.post);
      const F=(lv,lh,o)=>V(x+ux*sg*o+vx*lv,y+uy*sg*o+vy*lv,e+lh),nf=[ux*sg,0,-uy*sg];
      // the cross: two bars at 45 degrees, white on a red border
      for(const [hw,L,o,col] of [[.24,.95,.24,K.red],[.14,.85,.26,K.post]])for(const d of [1,-1]){const p0=-hw*d,p1=hw;
        R.face([F(-L+p0,3.55-L*d+p1,o),F(-L-p0,3.55-L*d-p1,o),F(L-p0,3.55+L*d-p1,o),F(L+p0,3.55+L*d+p1,o)],nf,col);}
      R.prism(rotRect(x+ux*sg*.3,y+uy*sg*.3,.3,1.6,a),e+2.2,e+2.8,K.head,K.head);
      for(const d of [-.5,.5])R.face([F(d-.2,2.3,.46),F(d+.2,2.3,.46),F(d+.2,2.7,.46),F(d-.2,2.7,.46)],nf,K.red);
      const bx=x+vx*sg*.8,by=y+vy*sg*.8;R.prism(rotRect(bx,by,.6,.7,a),e-.3,e+1.1,K.box,K.box);
      for(let k=0;k<10;k++)R.prism(rotRect(bx,by,.3,.3,a),e+1.1+k*.6,e+1.7+k*.6,k%2?K.post:K.red,K.post);}}
  // the station's yard tracks, draped
  for(const y of RAIL_YARD){const P=railSample(y.pts,RS);flatTrack(P,0,P.length-1,{...LINES[0],g:y.g||1.676});}
  if(R.nv){const m=new T.Mesh(R.geo(),matFlat);m.castShadow=m.receiveShadow=true;scene.add(m);}
  STREET.railVerts=R.nv;STREET.railMs=Math.round(performance.now()-t0);window.__rail=RAILP;}
// The girders of a rail bridge from a to b (grid metres), hw its half width, hAt(p) its deck's height, in palette K
// (steel, steel2): o.plates, the depth of plate girders under the deck, whose faces get stiffener panels in two tones;
// o.spans and o.h, half-through lattice girders above the deck on both sides, one per span (chords, verticals with
// wider end posts, an X of 0.45 m bars in each ~3.6 m panel, two tones by panel), outer and inner faces.
function railGirder(G,K,a,b,hw,hAt,o){const L=Math.hypot(b[0]-a[0],b[1]-a[1]),dx=(b[0]-a[0])/L,dy=(b[1]-a[1])/L,nx=-dy,ny=dx;
  const P=(t,off,dh)=>{const x=a[0]+dx*t+nx*off,y=a[1]+dy*t+ny*off;return [x,hAt({x:a[0]+dx*t,y:a[1]+dy*t})+dh,-y];};
  const pl=(off,sg)=>({r:(t0,t1,h0,h1,col)=>G.face([P(t0,off,h0),P(t1,off,h0),P(t1,off,h1),P(t0,off,h1)],[nx*sg,0,-ny*sg],col),
    q:(pts,col)=>G.face(pts.map(([t,h])=>P(t,off,h)),[nx*sg,0,-ny*sg],col)});
  for(const sd of [1,-1]){
    if(o.plates){const f=pl(sd*(hw+.06),sd),n=Math.max(2,Math.round(L/1.4));for(let k=0;k<n;k++)f.r(L*k/n,L*(k+1)/n,-o.plates+.05,-.05,k%2?K.steel2:K.steel);}
    if(o.spans){const sp=L/o.spans,h=o.h;
      for(let j=0;j<o.spans;j++){const t0=j*sp+.3,t1=(j+1)*sp-.3,np=Math.max(3,Math.round((t1-t0)/3.6)),pw=(t1-t0)/np;
        for(const [off,sg,bk] of [[sd*(hw+.06),sd,sd*(hw+.03)],[sd*(hw-.31),-sd,sd*(hw-.28)]]){const f=pl(off,sg),fb=pl(bk,sg);
          f.r(t0,t1,h-.5,h,K.steel);f.r(t0,t1,0,.6,K.steel);
          for(let k=0;k<=np;k++){const t=t0+k*pw,e=k%np?.25:.45;f.r(Math.max(t0,t-e),Math.min(t1,t+e),.6,h-.5,K.steel);}
          for(let k=0;k<np;k++){const u0=t0+k*pw,u1=u0+pw,c=k%2?K.steel2:K.steel;
            fb.q([[u0,.6],[u0+.45,.6],[u1,h-.5],[u1-.45,h-.5]],c);fb.q([[u1-.45,.6],[u1,.6],[u0+.45,h-.5],[u0,h-.5]],c);}}
        G.face([P(t0,sd*(hw+.06),h),P(t1,sd*(hw+.06),h),P(t1,sd*(hw-.31),h),P(t0,sd*(hw-.31),h)],[0,1,0],K.steel2);}}}}
// The piers and abutments of a rail bridge (same arguments as railGirder): o.spans-1 piers with cutwaters from the
// riverbed to under the beam (o.beamD), with a cap band in the second tone; an abutment at each end, outside the deck,
// from the ground to the deck; o.pillars, a stone pillar on each corner of the abutments, above the girders; o.cut,
// a bridge that goes on past b out of the commune: a pier there instead of the abutment.
function railPiers(G,K,a,b,hw,hAt,o){const L=Math.hypot(b[0]-a[0],b[1]-a[1]),dx=(b[0]-a[0])/L,dy=(b[1]-a[1])/L,nx=-dy,ny=dx;
  const at=(t,n)=>[a[0]+dx*t+nx*n,a[1]+dy*t+ny*n];
  const pier=t=>{const c=at(t,0),h=hAt({x:c[0],y:c[1]})-o.beamD,g=E(c[0],c[1]);if(h-g<1)return;
    const hex6=(r)=>[[-1.2*r,-hw-1],[0,-hw-2.4],[1.2*r,-hw-1],[1.2*r,hw+1],[0,hw+2.4],[-1.2*r,hw+1]].map(([lt,ln])=>at(t+lt,ln));
    G.prism(hex6(1),g-.6,h-.5,K.stone,K.stone);G.prism(hex6(1.12),h-.5,h-.05,K.stone2,K.stone2);};
  for(let k=1;k<o.spans;k++)pier(L*k/o.spans);
  for(const [t,sg] of [[0,-1],[L,1]]){if(o.cut&&t){pier(L-1.4);continue;}const q=[at(t,-hw-.8),at(t+sg*2.2,-hw-.8),at(t+sg*2.2,hw+.8),at(t,hw+.8)],c=at(t,0),h=hAt({x:c[0],y:c[1]});
    G.prism(q,groundMin(q)-.5,h-.02,K.stone,K.stone);
    if(o.pillars)for(const n of [-hw-.2,hw+.2]){const pc=at(t+sg*1.1,n),pq=rotRect(pc[0],pc[1],1.4,1.4,Math.atan2(dy,dx));
      G.prism(pq,h-.02,h+3.2,K.stone2,K.stone);G.prism(rotRect(pc[0],pc[1],1.7,1.7,Math.atan2(dy,dx)),h+3.2,h+3.6,K.stone,K.stone);}}}

