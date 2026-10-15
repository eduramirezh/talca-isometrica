/* =============== street level =============== */
// Sidewalks, curbs and crosswalks (docs/PROYECTOS-SIMILARES.md, point 4). The map's streets are wider than the real
// ones, so a sidewalk takes WALK[c] metres off the edge of its street's ribbon and goes on WALK_OUT metres past it, to
// where the lots of cityGen start (their slabs cover the rest). The curb is a light line of one art pixel (0.5 m) on the
// street side. A sidewalk runs along a street wherever a census block lies behind it, and stops at the carriageway
// of a crossing street (its own carriageway: the street minus its sidewalks), so the two sidewalks of a corner overlap
// in a square, in the same colour, and their curbs meet at a right angle. It also stops on what occupied the raster
// before the city (rivers and bridges, the Ruta 5, the rail, the landmarks). Heights: sidewalks 0.16, curbs and
// crosswalks 0.172 (streets 0.12-0.148; a 0.5 cm gap flickers). WALKS keeps the runs: the street trees and the parked
// cars go along them.
const WALK=[0,2,1.8,1.4,1.2,0.8,0,0],WALK_OUT=1.2,CURB=0.5,WALK_Y=0.16,CURB_Y=0.172;
const STREET={}; // counts for __stats
const WALKS=[]; // {si, side, pts (on the street's axis), hw, iw, bi (the block behind its middle)}
// is (x, y) on the carriageway of a street that crosses segment k (at more than ~37 degrees, not its neighbour)?
function onCrossing(x,y,k){const s0=segs[k],gx=Math.floor((x-XMIN)/SG),gy=Math.floor((y-YMIN)/SG);if(gx<0||gy<0||gx>=sgW||gy>=sgH)return false;
  const L0=Math.hypot(s0[2]-s0[0],s0[3]-s0[1])||1;
  for(const id of sgrid[gy*sgW+gx]){const s=segs[id];if(id===k)continue;const c=streets[s[5]].c;if(c>=6||streets[s[5]].bridge)continue;
    if(s[5]===s0[5]&&Math.abs(s[6]-s0[6])<=1)continue;
    const L=Math.hypot(s[2]-s[0],s[3]-s[1])||1;if(Math.abs(((s[2]-s[0])*(s0[2]-s0[0])+(s[3]-s[1])*(s0[3]-s0[1]))/L/L0)>0.8)continue;
    const r=s[4]-(walkOf(streets[s[5]])||-1);if(segDist2(x,y,s[0],s[1],s[2],s[3])<r*r)return true;}
  return false;}
// BLK: the cells of the occupancy raster inside a built census block or a park (a scanline fill of each block)
let BLK=null;
function blockMask(){BLK=new Uint8Array(ocW*ocH);
  for(const b of blocks){if(!b.built&&b.A>=40000)continue;const r=b.r; // not the open ground of the outskirts
    for(let gy=Math.max(0,Math.floor((b.bb[1]-YMIN)/OC));gy<=Math.min(ocH-1,Math.floor((b.bb[3]-YMIN)/OC));gy++){const cy=YMIN+(gy+.5)*OC,xs=[];
      for(let i=0,j=r.length-1;i<r.length;j=i++){const a=r[i],c=r[j];if((a[1]>cy)!==(c[1]>cy))xs.push(a[0]+(cy-a[1])*(c[0]-a[0])/(c[1]-a[1]));}
      xs.sort((p,q)=>p-q);
      for(let i=0;i+1<xs.length;i+=2)for(let gx=Math.max(0,Math.ceil((xs[i]-XMIN)/OC-.5));gx<=Math.min(ocW-1,Math.floor((xs[i+1]-XMIN)/OC-.5));gx++)BLK[gy*ocW+gx]=1;}}}
function walkRuns(){blockMask();
  let k0=0;
  streets.forEach((s,si)=>{const n=s.pts.length-1,k1=k0;k0+=n;if(!walkOf(s)||s.bridge)return;const hw=swOf(s)/2,iw=walkOf(s),P=s.pts;
    for(const side of [1,-1]){let run=null;
      const at=(i,u)=>{const a=P[i],b=P[i+1],L=Math.hypot(b[0]-a[0],b[1]-a[1])||1,tx=(b[0]-a[0])/L,ty=(b[1]-a[1])/L,nx=-ty*side,ny=tx*side;
        return (v)=>[a[0]+tx*u+nx*v,a[1]+ty*u+ny*v];};
      const behind=([x,y])=>{const gx=Math.floor((x-XMIN)/OC),gy=Math.floor((y-YMIN)/OC);return gx>=0&&gy>=0&&gx<ocW&&gy<ocH&&BLK[gy*ocW+gx]===1;};
      const ok=(i,u)=>{const p=at(i,u),m=p(hw+(WALK_OUT-iw)/2),o=p(hw+WALK_OUT-0.2);
        return occAt(o[0],o[1])!==1&&occAt(...p(hw-iw+0.2))!==1&&!inMedian(...p(hw-iw+0.6))&&behind(p(hw+5))&&!onCrossing(m[0],m[1],k1+i);};
      const close=()=>{if(run&&run.pts.length>1&&Math.hypot(run.pts[0][0]-run.pts[run.pts.length-1][0],run.pts[0][1]-run.pts[run.pts.length-1][1])>2)WALKS.push(run);run=null;};
      for(let i=0;i<n;i++){const a=P[i],b=P[i+1],L=Math.hypot(b[0]-a[0],b[1]-a[1]);if(L<0.01)continue;
        const steps=Math.max(1,Math.ceil(L/3.5));let prev=ok(i,0);
        if(prev){if(!run)run={si,side,pts:[a],hw,iw};else run.pts.push(a);}else if(run){run.pts.push(a);close();}
        for(let j=1;j<=steps;j++){const u=L*j/steps,cur=ok(i,u);
          if(cur!==prev){let lo=L*(j-1)/steps,hi=u;for(let t=0;t<6;t++){const mid=(lo+hi)/2;if(ok(i,mid)===prev)lo=mid;else hi=mid;}
            const e=at(i,prev?lo:hi)(0);if(prev){run.pts.push(e);close();}else run={si,side,pts:[e],hw,iw};}
          prev=cur;}}
      if(run)run.pts.push(P[n]);close();}});
  for(const w of WALKS){const p=w.pts[w.pts.length>>1],q=w.pts[(w.pts.length>>1)-1]||w.pts[1];
    const L=Math.hypot(p[0]-q[0],p[1]-q[1])||1,m=[(p[0]+q[0])/2+(-(p[1]-q[1])/L*w.side)*(w.hw+4),(p[1]+q[1])/2+((p[0]-q[0])/L*w.side)*(w.hw+4)];
    w.bi=blockAt(m[0],m[1]);}
}
// Crosswalks at the crossings of the central grid (within CROSS_R of the plaza, streets of class 1-4 at more than 60
// degrees): zebra bars along the street, 0.6 m wide every 1.2 m, across its carriageway, in line with the sidewalks of
// the crossing street. Only on arms that go on past the crossing (a T has three).
const CROSS_R=1000;
function crossings(B){const seen=new Set(),zeb=hex('#E4E0D6');let n=0;
  const arm=(x,y,tx,ty)=>{const gx=Math.floor((x-XMIN)/SG),gy=Math.floor((y-YMIN)/SG);if(gx<0||gy<0||gx>=sgW||gy>=sgH)return false;
    for(const id of sgrid[gy*sgW+gx]){const s=segs[id],L=Math.hypot(s[2]-s[0],s[3]-s[1])||1;if(streets[s[5]].c>5)continue;
      if(Math.abs(((s[2]-s[0])*tx+(s[3]-s[1])*ty)/L)>0.9&&segDist2(x,y,s[0],s[1],s[2],s[3])<s[4]*s[4])return true;}return false;};
  for(let cell=0;cell<sgrid.length;cell++){const ids=sgrid[cell];
    for(let p=0;p<ids.length;p++)for(let q=p+1;q<ids.length;q++){const A=segs[ids[p]],Bs=segs[ids[q]],cA=streets[A[5]].c,cB=streets[Bs[5]].c;
      if(cA<1||cA>4||cB<1||cB>4||A[5]===Bs[5])continue;
      const ax=A[2]-A[0],ay=A[3]-A[1],bx=Bs[2]-Bs[0],by=Bs[3]-Bs[1],LA=Math.hypot(ax,ay),LB=Math.hypot(bx,by),d=ax*by-ay*bx;
      if(LA<1||LB<1||Math.abs(d)/LA/LB<0.87)continue;
      const t=((Bs[0]-A[0])*by-(Bs[1]-A[1])*bx)/d,u=((Bs[0]-A[0])*ay-(Bs[1]-A[1])*ax)/d;
      if(t<-1/LA||t>1+1/LA||u<-1/LB||u>1+1/LB)continue;
      const x=A[0]+ax*t,y=A[1]+ay*t;if(Math.hypot(x,y)>CROSS_R)continue;
      const key=Math.round(x/4)+','+Math.round(y/4);if(seen.has(key))continue;seen.add(key);
      for(const [S,cS,O,cO,sx,sy] of [[A,cA,Bs,cB,ax/LA,ay/LA],[Bs,cB,A,cA,bx/LB,by/LB]]){ // the zebras across S, beside O
        const hwS=S[4],hwO=O[4],cw=hwS-walkOf(streets[S[5]])-0.3,nx=-sy,ny=sx;
        // distance along S from the crossing to O's sidewalk, measured on S (O may cross at an angle)
        const sin=Math.abs(d)/LA/LB,s0=(hwO-walkOf(streets[O[5]])+0.4)/sin;
        for(const dir of [1,-1]){const tx=sx*dir,ty=sy*dir;if(!arm(x+tx*(hwO+4),y+ty*(hwO+4),sx,sy))continue;
          const cx=x+tx*(s0+1.5),cy=y+ty*(s0+1.5);if(occAt(cx,cy)===1)continue;ZEB.push([cx,cy,tx,ty,cw]);
          for(let v=-cw+0.3;v<=cw-0.3+1e-6;v+=1.2){const P=(uu,vv)=>[x+tx*uu+nx*vv,y+ty*uu+ny*vv];
            B.quadXY([P(s0,v-0.3),P(s0+3,v-0.3),P(s0+3,v+0.3),P(s0,v+0.3)],CURB_Y,zeb);}
          n++;}}}}
  return n;}
// Street trees on the sidewalks, as Talca has them (pipeline/satellite.py on a few streets): rows along most avenues,
// irregular ones on the residential streets (a tree every 9-13 m, with gaps, on one side or both), few in the commercial
// centre and the industrial blocks. A run of sidewalk gets trees or not as a whole, all of one kind (one shade), with
// the trunk 0.7 m behind the curb; none within 6 m of its ends (the corners), on parks (they have their own) or where
// the canopy would reach a landmark. Their own rng, so the city stays as it was. Round trees, into cityGen's TR.
function streetTrees(){const out=[];
  for(const w of WALKS){const bi=w.bi;if(bi<0||!blocks[bi].built||bi===PLAZA_BI||ALAM.has(bi))continue;
    const s=streets[w.si],st=styleFor(bi),ave=s.c<=2||/^Avenida/.test(s.name||'');
    const [p,gap,slot,sc]=s.rows?[1,s.rows[0],.95,s.rows[1]]:ave?[.75,8.5,.9,.62]:st==='core'?[.3,8.5,.8,.5]:st==='house'||st==='apt'?[s.c>=5?.4:.55,11,.7,.5]:[.25,10,.7,.55];
    const r=rng(w.si*7919+(w.side>0?1:2)*104729+Math.round(w.pts[0][0]*7+w.pts[0][1]*3));if(r()>=p)continue;
    const kind=r(),size=sc+r()*.25,off=w.hw-w.iw+0.7,P=w.pts;let L=0;
    for(let i=0;i+1<P.length;i++)L+=Math.hypot(P[i+1][0]-P[i][0],P[i+1][1]-P[i][1]);
    if(L<14)continue;
    const n=Math.floor((L-12)/gap),u0=(L-n*gap)/2;
    for(let k=0,i=0,acc=0;k<=n;k++){const u=u0+k*gap;if(r()>=slot)continue;
      while(i+2<P.length&&acc+Math.hypot(P[i+1][0]-P[i][0],P[i+1][1]-P[i][1])<u){acc+=Math.hypot(P[i+1][0]-P[i][0],P[i+1][1]-P[i][1]);i++;}
      const a=P[i],b=P[i+1],l=Math.hypot(b[0]-a[0],b[1]-a[1])||1,tx=(b[0]-a[0])/l,ty=(b[1]-a[1])/l,nx=-ty*w.side,ny=tx*w.side,v=u-acc+(r()-.5)*1.2;
      const x=a[0]+tx*v+nx*off,y=a[1]+ty*v+ny*off;
      if(occAt(x,y)===1||occAt(x+nx*2.5,y+ny*2.5)===1||occAt(x-nx*2,y-ny*2)===1||inMedian(x,y))continue;
      out.push([x,y,size*(0.9+r()*.2),(kind+r()*.12)%1]);}}
  STREET.trees=out.length;return out;}
// Parked cars along the curbs, as the satellite shows them (pipeline/satellite.py at zoom 19 on the plaza, 3 Sur with
// 3 Oriente, a neighbourhood at (1300,-700) and the Diagonal): nearly unbroken rows on both sides of the streets around
// the plaza and along the Diagonal's outer curbs, long rows on one side or both in the rest of the centre, a car here
// and there in the neighbourhoods, fewer by the industrial blocks and the parks. Each run of sidewalk gets its own rate
// (by the block's style and the distance from the plaza, then varied per run, so one side can be full and the other
// empty); along it, slots of 5.6-6.2 m are filled by a two-state chain, so cars come in rows of 2-4 (longer in the
// centre) with gaps. On the carriageway, 0.05 m off the curb, facing the traffic's way (right-hand), pitched with the
// ground. None within 8 m of a run's ends (corners), on a zebra, on what occupied the raster before the city (rivers,
// the rail's crossings, landmarks), on the Alameda's park or the Diagonal's median; on carriageways narrower than 7 m,
// on one side only. Their own rng, so the city stays as it was. One InstancedMesh (carGeo), coloured per instance.
const ZEB=[]; // the crosswalks (crossings()): [x, y of the centre, tx, ty along the street, cw half the carriageway]
const CAR_COLS=[[.93,.93,.91,30],[.72,.74,.76,22],[.45,.47,.49,18],[.13,.13,.14,14],[.68,.13,.11,8],[.16,.23,.43,8]]; // white, silver, grey, black, red, dark blue; % of cars
function parkedCars(){const t0=performance.now(),out=[],zg=new Map(),ZC=50;
  for(const z of ZEB){const k=Math.floor(z[0]/ZC)+','+Math.floor(z[1]/ZC);(zg.get(k)||zg.set(k,[]).get(k)).push(z);}
  const onZebra=(x,y)=>{for(let i=-1;i<=1;i++)for(let j=-1;j<=1;j++)for(const [zx,zy,tx,ty,cw] of zg.get((Math.floor(x/ZC)+i)+','+(Math.floor(y/ZC)+j))||[]){
      const dx=x-zx,dy=y-zy;if(Math.abs(dx*tx+dy*ty)<4.2&&Math.abs(-dx*ty+dy*tx)<cw+1)return true;}return false;};
  const colW=CAR_COLS.reduce((a,c)=>a+c[3],0);
  for(const w of WALKS){const bi=w.bi;if(bi<0||ALAM.has(bi))continue;const s=streets[w.si],cw=w.hw-w.iw;
    if(cw*2<4.5)continue;
    const r=rng(w.si*6271+(w.side>0?1:2)*92821+Math.round(w.pts[0][0]*5+w.pts[0][1]*11)+31337);
    if(cw*2<7&&!s.rows&&(w.si%2?1:-1)!==w.side)continue; // narrow: one side
    const m=w.pts[w.pts.length>>1],dc=Math.hypot(m[0],m[1]),st=blocks[bi].built?styleFor(bi):'park',ave=s.c<=2||/^Avenida/.test(s.name||'');
    let p=s.rows||bi===PLAZA_BI?.7:st==='core'?(dc<450?.7:.5):st==='core2'?.25:ave?.15:st==='apt'?.2:st==='house'?.12:st==='ind'?.05:.08;
    p=Math.min(.9,p*(.4+1.2*r()));
    const a=p>.35?.85:.55,b=p*(1-a)/(1-p),g=st==='core'||s.rows?5.6:6.2,P=w.pts;let L=0;
    for(let i=0;i+1<P.length;i++)L+=Math.hypot(P[i+1][0]-P[i][0],P[i+1][1]-P[i][1]);
    if(L<16+g)continue;
    const n=Math.floor((L-16)/g),u0=8+(L-16-n*g)/2+g/2;let on=r()<p;
    for(let k=0,i=0,acc=0;k<n;k++){on=r()<(on?a:b);if(!on)continue;
      const u=u0+k*g+(r()-.5)*.5;
      while(i+2<P.length&&acc+Math.hypot(P[i+1][0]-P[i][0],P[i+1][1]-P[i][1])<u){acc+=Math.hypot(P[i+1][0]-P[i][0],P[i+1][1]-P[i][1]);i++;}
      const A=P[i],B=P[i+1],l=Math.hypot(B[0]-A[0],B[1]-A[1])||1,tx=(B[0]-A[0])/l,ty=(B[1]-A[1])/l,nx=-ty*w.side,ny=tx*w.side,v=u-acc,off=cw-.95;
      const x=A[0]+tx*v+nx*off,y=A[1]+ty*v+ny*off,van=r()<.07,len=(van?4.9:4.1+r()*.6)/4.5;
      const q=rotRect(x,y,4.5*len,1.8,Math.atan2(ty,tx));
      if(q.some(c=>occAt(c[0],c[1])===1||inMedian(c[0],c[1]))||onZebra(x,y))continue;
      let c=r()*colW,col=CAR_COLS[0];for(const cc of CAR_COLS){if((c-=cc[3])<0){col=cc;break;}}
      out.push([x,y,-tx*w.side,-ty*w.side,len,van?1.3:1,col,r()]);}}
  Object.assign(STREET,{cars:out.length,carMs:Math.round(performance.now()-t0)});return out;}
// a car, 4.5 x 1.8 m, in local x (forward), y (up), z: a body 0.8 m tall, and over it the cabin, its windows a band of
// one art pixel (0.5 m) in a dark tone and its roof in the body's colour (instanceColor multiplies the vertex colour)
function carGeo(){const P=[],N=[],C=[],I=[],W=[1,1,1],G=[.2,.23,.28];
  const quad=(a,b,c,d,n,col)=>{const o=P.length/3;for(const v of [a,b,c,d]){P.push(...v);N.push(...n);C.push(...col);}I.push(o,o+1,o+2,o,o+2,o+3);};
  const box=(x0,x1,y0,y1,z0,z1,side,top)=>{quad([x0,y0,z1],[x1,y0,z1],[x1,y1,z1],[x0,y1,z1],[0,0,1],side);quad([x1,y0,z0],[x0,y0,z0],[x0,y1,z0],[x1,y1,z0],[0,0,-1],side);
    quad([x1,y0,z1],[x1,y0,z0],[x1,y1,z0],[x1,y1,z1],[1,0,0],side);quad([x0,y0,z0],[x0,y0,z1],[x0,y1,z1],[x0,y1,z0],[-1,0,0],side);
    quad([x0,y1,z1],[x1,y1,z1],[x1,y1,z0],[x0,y1,z0],[0,1,0],top);};
  box(-2.25,2.25,0,.8,-.9,.9,W,W);box(-1.35,.85,.8,1.3,-.74,.74,G,W);
  const g=new T.BufferGeometry();g.setAttribute('position',new T.Float32BufferAttribute(P,3));g.setAttribute('normal',new T.Float32BufferAttribute(N,3));
  g.setAttribute('color',new T.Float32BufferAttribute(C,3));g.setIndex(I);return g;}
function instCars(list){
  const mesh=new T.InstancedMesh(carGeo(),new T.MeshLambertMaterial({vertexColors:true}),list.length);
  const m=new T.Matrix4(),q=new T.Quaternion(),e=new T.Euler(0,0,0,'YZX'),s=new T.Vector3(),p=new T.Vector3(),col=new T.Color();
  list.forEach(([x,y,dx,dy,len,hs,c,k],i)=>{const h=2.25*len,f=E(x+dx*h,y+dy*h),b=E(x-dx*h,y-dy*h);
    e.set(0,Math.atan2(dy,dx),Math.atan2(f-b,2*h));q.setFromEuler(e);s.set(len,hs,1);p.set(x,(f+b)/2+.13,-y);m.compose(p,q,s);mesh.setMatrixAt(i,m);
    const v=.96+k*.08;col.setRGB(c[0]*v,c[1]*v,c[2]*v);mesh.setColorAt(i,col);});
  mesh.instanceMatrix.needsUpdate=true;if(mesh.instanceColor)mesh.instanceColor.needsUpdate=true;
  return mesh;}
