/* =============== geometry builder =============== */
class GB{
  constructor(cap=1<<15){this.cap=cap;this.P=new Float32Array(cap*3);this.N=new Int8Array(cap*3);this.C=new Uint8Array(cap*3);this.icap=cap*2;this.I=new Uint32Array(this.icap);this.nv=0;this.ni=0;this.dy=0;this.lk=NaN;}
  // the run log (startup): k is the key of what is being emitted, in the order of a startup at once; each change of
  // k starts a run [k, first vertex, first index] in log, so that two builders filled in two stages can be tiled
  // together in that order (tiledParts)
  grow(v,i){if(this.k!==this.lk){(this.log||(this.log=[])).push(this.k||0,this.nv,this.ni);this.lk=this.k;}
    if(this.nv+v>this.cap){let c=this.cap;while(this.nv+v>c)c*=2;const P=new Float32Array(c*3);P.set(this.P);this.P=P;const N=new Int8Array(c*3);N.set(this.N);this.N=N;const C=new Uint8Array(c*3);C.set(this.C);this.C=C;this.cap=c;}
    if(this.ni+i>this.icap){let c=this.icap;while(this.ni+i>c)c*=2;const I=new Uint32Array(c);I.set(this.I);this.I=I;this.icap=c;}}
  face(pts,n,col){
    const a=pts[0],b=pts[1],c=pts[2];const ux=b[0]-a[0],uy=b[1]-a[1],uz=b[2]-a[2],vx=c[0]-a[0],vy=c[1]-a[1],vz=c[2]-a[2];
    if(!n){n=[uy*vz-uz*vy,uz*vx-ux*vz,ux*vy-uy*vx];const L=Math.hypot(n[0],n[1],n[2])||1;n=[n[0]/L,n[1]/L,n[2]/L];}
    else if((uy*vz-uz*vy)*n[0]+(uz*vx-ux*vz)*n[1]+(ux*vy-uy*vx)*n[2]<0)pts=pts.slice().reverse();
    this.grow(pts.length,(pts.length-2)*3);const base=this.nv;
    for(const p of pts){const k=this.nv*3;this.P[k]=p[0];this.P[k+1]=p[1]+this.dy;this.P[k+2]=p[2];this.N[k]=n[0]*127;this.N[k+1]=n[1]*127;this.N[k+2]=n[2]*127;this.C[k]=col[0];this.C[k+1]=col[1];this.C[k+2]=col[2];this.nv++;}
    for(let j=1;j<pts.length-1;j++){this.I[this.ni++]=base;this.I[this.ni++]=base+j;this.I[this.ni++]=base+j+1;}
  }
  flat(ring,y,col){ // ring local [x,y]
    let tris;try{tris=T.ShapeUtils.triangulateShape(ring.map(p=>new T.Vector2(p[0],p[1])),[]);}catch(e){return;}
    this.grow(ring.length,tris.length*3);const base=this.nv;
    for(const p of ring){const k=this.nv*3;this.P[k]=p[0];this.P[k+1]=y+this.dy;this.P[k+2]=-p[1];this.N[k]=0;this.N[k+1]=127;this.N[k+2]=0;this.C[k]=col[0];this.C[k+1]=col[1];this.C[k+2]=col[2];this.nv++;}
    for(const t of tris){const a=ring[t[0]],b=ring[t[1]],c=ring[t[2]];
      // want +Y facing: cross((b-a),(c-a)).y in XZ with Z=-y  => uz*vx-ux*vz
      const ux=b[0]-a[0],uz=-(b[1]-a[1]),vx=c[0]-a[0],vz=-(c[1]-a[1]);
      if(uz*vx-ux*vz>=0){this.I[this.ni++]=base+t[0];this.I[this.ni++]=base+t[1];this.I[this.ni++]=base+t[2];}
      else{this.I[this.ni++]=base+t[0];this.I[this.ni++]=base+t[2];this.I[this.ni++]=base+t[1];}}
  }
  quadXY(q,y,col){this.face(q.map(p=>[p[0],y,-p[1]]),[0,1,0],col);}
  // prism from base polygon q (local, any order convex), heights y0..y1, walls + top.
  // Walls that start at ground level (y0<=0.31) go 4 m deeper, so a building on a slope never floats.
  prism(q,y0,y1,wall,roof,top=true){
    const yw=y0<=0.31?y0-4:y0;let cx=0,cy=0;q.forEach(p=>{cx+=p[0];cy+=p[1];});cx/=q.length;cy/=q.length;
    for(let i=0;i<q.length;i++){const a=q[i],b=q[(i+1)%q.length];let nx=b[1]-a[1],ny=-(b[0]-a[0]);const L=Math.hypot(nx,ny)||1;nx/=L;ny/=L;
      if(nx*((a[0]+b[0])/2-cx)+ny*((a[1]+b[1])/2-cy)<0){nx=-nx;ny=-ny;}
      this.face([[a[0],yw,-a[1]],[b[0],yw,-b[1]],[b[0],y1,-b[1]],[a[0],y1,-a[1]]],[nx,0,-ny],wall);}
    if(top)this.face(q.map(p=>[p[0],y1,-p[1]]),[0,1,0],roof);
  }
  // gable: q = [front-left, front-right, back-right, back-left]; ridge parallel to front edge
  gable(q,y0,y1,rh,wall,roof){
    this.prism(q,y0,y1,wall,roof,false);
    const m0=[(q[0][0]+q[3][0])/2,(q[0][1]+q[3][1])/2],m1=[(q[1][0]+q[2][0])/2,(q[1][1]+q[2][1])/2];
    const P=(p,y)=>[p[0],y,-p[1]];const r2=shade(roof,.86);
    this.face([P(q[0],y1),P(q[1],y1),P(m1,y1+rh),P(m0,y1+rh)],null,roof);
    this.face([P(q[2],y1),P(q[3],y1),P(m0,y1+rh),P(m1,y1+rh)],null,r2);
    this.face([P(q[3],y1),P(q[0],y1),P(m0,y1+rh)],null,wall);
    this.face([P(q[1],y1),P(q[2],y1),P(m1,y1+rh)],null,wall);
  }
  // fix orientation of null-normal faces: ensure outward (up-ish) facing
  geo(){const g=new T.BufferGeometry();g.setAttribute('position',new T.BufferAttribute(this.P.slice(0,this.nv*3),3));g.setAttribute('normal',new T.BufferAttribute(this.N.slice(0,this.nv*3),3,true));g.setAttribute('color',new T.BufferAttribute(this.C.slice(0,this.nv*3),3,true));g.setIndex(new T.BufferAttribute(this.I.slice(0,this.ni),1));g.computeBoundingSphere();return g;}
}
// Tiles. A mesh over the whole commune is drawn whole in every pass (colour, normals, shadows): its bounding sphere
// is always in view. tiled(src, mat) cuts a GB (or an indexed BufferGeometry) into one mesh per TILE x TILE metres,
// each triangle in the tile of its centroid, so three.js leaves out the tiles the camera (or the shadow camera) does
// not see. A GB is consumed: its arrays are dropped. The copies in the JS heap are dropped too once uploaded (free):
// nothing reads them after the boot, and they doubled the memory a phone has to hold. Each tile takes one pass over its
// triangles: a vertex is copied the first time one of them uses it (stamp), into scratch arrays sized for the largest
// tile and reused, which are then sliced to the tile's size (a copy at memory speed); the bounding box grows during
// that pass and the sphere is three's computeBoundingSphere() over the same floats (centre of the box, farthest
// vertex), without a Vector3 per vertex. The cutting took ~0.45 s of the boot, now ~0.3 s.
// Strips. With the whole commune in view, 1 km tiles made ~1,500 draw calls per pass. Consecutive tiles of a column
// (up to STRIP, while they hold fewer than 65,536 vertices, so the indices stay 16-bit) share one vertex and one index
// buffer: each tile is a drawRange of it, and a strip mesh draws the whole run. stripLod() shows the strip instead
// of its tiles when its box lies entirely inside the view, where every one of them would be drawn anyway: the same
// triangles in the same order (a strip comes before its tiles and after the previous ones, and three.js draws the
// meshes of a material in the order they were made), so the image is the same, with no extra memory. Zoomed in, a
// strip is never entirely in view and nothing changes.
const TILE=1000,TILE_N=64,STRIP=4,STRIPS=[]; // tile keys: (tx+TILE_N)*2*TILE_N+(tz+TILE_N), the box of the commune is ±25 km at most
function dropArray(){this.array=null;}
function free(g){for(const k in g.attributes)g.attributes[k].onUpload(dropArray);if(g.index)g.index.onUpload(dropArray);return g;}
// The tiling of a layer is a generator that yields between tiles (tileGen, tiledPartsGen, instTiledGen): rest() runs
// it in slices with yield* (a whole layer at once was a task of up to 255 ms, a jolt while the map moved); the first
// stage drains it at once (drain). The same meshes either way
const drain=g=>{let r;do r=g.next();while(!r.done);return r.value;};
function tiled(src,mat,keep){
  const isGB=src instanceof GB,A=src.attributes;
  const grp=drain(tileGen([isGB?src:{P:A.position.array,N:A.normal.array,C:A.color.array,I:src.index.array,nv:A.position.array.length/3,ni:src.index.array.length}],null,null,mat));
  if(isGB&&!keep)src.P=src.N=src.C=src.I=null; // (keep: boot tiles it again with the rest, tiledParts)
  return grp;}
// tiledParts(gbs, mat): builders filled in two stages of the startup, tiled together with their triangles in the order
// of their runs' keys (GB.grow), which is the order of a startup at once: the same meshes, triangle for triangle
const tiledParts=(gbs,mat)=>drain(tiledPartsGen(gbs,mat));
function* tiledPartsGen(gbs,mat){const runs=[];
  gbs.forEach((g,p)=>{const L=g.log||[];for(let r=0;r<L.length;r+=3){const t0=L[r+2]/3,t1=(r+5<L.length?L[r+5]:g.ni)/3;if(t1>t0)runs.push([L[r],p,t0,t1]);}});
  runs.sort((a,b)=>a[0]-b[0]||a[1]-b[1]||a[2]-b[2]);
  let n=0;for(const r of runs)n+=r[3]-r[2];const sp=new Uint8Array(n),st=new Int32Array(n);n=0;
  for(const [,p,t0,t1] of runs){for(let t=t0;t<t1;t++){sp[n]=p;st[n++]=t;}if(t1-t0>YIELD_T)yield;}
  const grp=yield* tileGen(gbs,sp,st,mat);for(const g of gbs)g.P=g.N=g.C=g.I=null;return grp;}
// the tiles of parts ({P, N, C, I, nv, ni}): their triangles in the order sp/sq (part, triangle), or those of the one
// part in its order
const YIELD_T=1<<16; // triangles between yields in the passes over a whole layer
function* tileGen(parts,sp,sq,mat){
  const nt=sp?sp.length:parts[0].ni/3,np=parts.length,vo=new Int32Array(np+1);for(let p=0;p<np;p++)vo[p+1]=vo[p]+parts[p].nv;
  const P0=parts[0].P,N0=parts[0].N,C0=parts[0].C,nv=vo[np],norm=a=>!(a instanceof Float32Array);
  const NK=4*TILE_N*TILE_N,cnt=new Int32Array(NK),tid=new Int32Array(nt);
  for(let x=0;x<nt;x++){const Q=sp?parts[sp[x]]:parts[0],t=sp?sq[x]:x,P=Q.P,I=Q.I,a=I[3*t]*3,b=I[3*t+1]*3,c=I[3*t+2]*3;
    const k=(Math.floor((P[a]+P[b]+P[c])/(3*TILE))+TILE_N)*2*TILE_N+Math.floor((P[a+2]+P[b+2]+P[c+2])/(3*TILE))+TILE_N;tid[x]=k;cnt[k]++;if(x%YIELD_T===YIELD_T-1)yield;}
  const off=new Int32Array(NK+1);for(let k=0;k<NK;k++)off[k+1]=off[k]+cnt[k];
  const ord=new Int32Array(nt),at=off.slice(0,NK);for(let t=0;t<nt;t++)ord[at[tid[t]]++]=t;
  let mx=0;for(let k=0;k<NK;k++)if(cnt[k]>mx)mx=cnt[k];
  const VC=Math.max(65536,3*mx)+3*mx,grp=new T.Group(),stamp=new Int32Array(nv).fill(-1),idx=new Int32Array(nv),
    SP=new P0.constructor(VC*3),SN=new N0.constructor(VC*3),SC=new C0.constructor(VC*3),SI=new Uint32Array(STRIP*3*mx);
  // the strip being filled: sv vertices and si indices in the scratch arrays, st its tiles [start, count, sphere],
  // bx its box; the sphere of vertices b0..b1 around the centre of their box (x0..z1), as three computes it
  let sv=0,si=0,col=-1,st=[];const bx=new Float64Array(6),bxReset=()=>bx.set([Infinity,Infinity,Infinity,-Infinity,-Infinity,-Infinity]);bxReset();
  const sphere=(b0,b1,x0,y0,z0,x1,y1,z1)=>{const cx=(x0+x1)*0.5,cy=(y0+y1)*0.5,cz=(z0+z1)*0.5;let r2=0;
    for(let b=b0*3;b<b1*3;b+=3){const dx=cx-SP[b],dy=cy-SP[b+1],dz=cz-SP[b+2];r2=Math.max(r2,dx*dx+dy*dy+dz*dz);}
    return new T.Sphere(new T.Vector3(cx,cy,cz),Math.sqrt(r2));};
  const flush=()=>{if(!st.length)return;
    let I2;if(sv<65536){I2=new Uint16Array(si);I2.set(SI.subarray(0,si));}else I2=SI.slice(0,si);
    const pa=new T.BufferAttribute(SP.slice(0,sv*3),3),na=new T.BufferAttribute(SN.slice(0,sv*3),3,norm(N0)),ca=new T.BufferAttribute(SC.slice(0,sv*3),3,norm(C0)),ia=new T.BufferAttribute(I2,1);
    for(const a of [pa,na,ca,ia])a.onUpload(dropArray);
    const mesh=(s,n,sph)=>{const g=new T.BufferGeometry();g.setAttribute('position',pa);g.setAttribute('normal',na);g.setAttribute('color',ca);g.setIndex(ia);
      g.setDrawRange(s,n);g.boundingSphere=sph;const m=new T.Mesh(g,mat);grp.add(m);return m;};
    const c=st.length>1?mesh(0,si,sphere(0,sv,...bx)):null,f=st.map(t=>mesh(...t)); // the strip first: it draws before its tiles
    if(c){c.visible=false;STRIPS.push({c,f,box:new T.Box3(new T.Vector3(bx[0],bx[1],bx[2]),new T.Vector3(bx[3],bx[4],bx[5])),on:false});}
    sv=si=0;st=[];bxReset();};
  for(let k=0;k<NK;k++){if(!cnt[k])continue;
    const kc=Math.floor(k/(2*TILE_N));if(st.length&&(kc!==col||st.length>=STRIP))flush();col=kc;
    let base=sv,m=0,o=0,x0=Infinity,y0=Infinity,z0=Infinity,x1=-Infinity,y1=-Infinity,z1=-Infinity;
    for(let i=off[k],e=off[k+1];i<e;i++){const x=ord[i],Q=sp?parts[sp[x]]:parts[0],t3=3*(sp?sq[x]:x),I=Q.I,P=Q.P,N=Q.N,C=Q.C,o0=sp?vo[sp[x]]:0;
      for(let j=0;j<3;j++){const v=I[t3+j],g=o0+v;
        if(stamp[g]!==k){stamp[g]=k;idx[g]=m;const a=v*3,b=(base+m)*3;m++;
          const x=SP[b]=P[a],y=SP[b+1]=P[a+1],z=SP[b+2]=P[a+2];SN[b]=N[a];SN[b+1]=N[a+1];SN[b+2]=N[a+2];SC[b]=C[a];SC[b+1]=C[a+1];SC[b+2]=C[a+2];
          if(x<x0)x0=x;if(y<y0)y0=y;if(z<z0)z0=z;if(x>x1)x1=x;if(y>y1)y1=y;if(z>z1)z1=z;}
        SI[si+o++]=idx[g];}}
    if(base&&base+m>65535){const s0=si;flush(); // it does not fit: the strip so far is done, this tile starts the next
      SP.copyWithin(0,base*3,(base+m)*3);SN.copyWithin(0,base*3,(base+m)*3);SC.copyWithin(0,base*3,(base+m)*3);SI.copyWithin(0,s0,s0+o);base=0;}
    if(base)for(let i=si;i<si+o;i++)SI[i]+=base;
    st.push([si,o,sphere(base,base+m,x0,y0,z0,x1,y1,z1)]);sv=base+m;si+=o;
    bx[0]=Math.min(bx[0],x0);bx[1]=Math.min(bx[1],y0);bx[2]=Math.min(bx[2],z0);bx[3]=Math.max(bx[3],x1);bx[4]=Math.max(bx[4],y1);bx[5]=Math.max(bx[5],z1);yield;}
  flush();
  return grp;}
// before a frame: a strip entirely inside the camera's view replaces its tiles (Strips, above); __strips(false) keeps
// the tiles, to compare (tools/perf.py, tools/variants.py --diff)
const stripFr=new T.Frustum(),stripM=new T.Matrix4(),stripV=new T.Vector3();let stripsOn=true;
function stripLod(c){stripFr.setFromProjectionMatrix(stripM.multiplyMatrices(c.projectionMatrix,c.matrixWorldInverse));
  for(const S of STRIPS){const b=S.box;let on=stripsOn;
    for(const p of stripFr.planes){const n=p.normal;stripV.set(n.x>0?b.min.x:b.max.x,n.y>0?b.min.y:b.max.y,n.z>0?b.min.z:b.max.z);if(p.distanceToPoint(stripV)<0){on=false;break;}}
    if(on!==S.on){S.on=on;S.c.visible=on;for(const m of S.f)m.visible=!on;}}}
window.__strips=on=>{stripsOn=on!==false;dirty=true;};
// instTiled(geo, mat, list, set): an InstancedMesh per tile (trees, cars); set(item, m, col) writes an instance's
// matrix and colour. r128 never culls an InstancedMesh (frustumCulled false: it would test the sphere of a single
// tree at the grid origin), so the 215 thousand trees were drawn whole in every pass. Each tile's geometry shares
// geo's attributes and carries a bounding sphere around its own instances, and culling is turned back on. With far, a
// cheaper geometry for when the instances are a few pixels wide: each tile keeps both (userData.lod) and goes to LODS,
// which setLod() switches.
const LODS=[];
const instTiled=(...a)=>drain(instTiledGen(...a));
function* instTiledGen(geo,mat,list,set,far){
  const n=list.length,M=new Float32Array(n*16),Cl=new Float32Array(n*3),key=new Int32Array(n),m=new T.Matrix4(),col=new T.Color(),by=new Map();
  for(let i=0;i<n;i++){set(list[i],m,col);m.toArray(M,i*16);col.toArray(Cl,i*3);const e=m.elements;
    key[i]=(Math.floor(e[12]/TILE)+TILE_N)*2*TILE_N+Math.floor(e[14]/TILE)+TILE_N;if(!by.has(key[i]))by.set(key[i],[]);by.get(key[i]).push(i);if(i%8192===8191)yield;}
  if(!geo.boundingSphere)geo.computeBoundingSphere();const r0=geo.boundingSphere.center.length()+geo.boundingSphere.radius;
  const grp=new T.Group(),box=new T.Box3(),v=new T.Vector3(),share=src=>{const g=new T.BufferGeometry();for(const k in src.attributes)g.setAttribute(k,src.attributes[k]);if(src.index)g.setIndex(src.index);return g;};
  for(const ids of by.values()){const g=share(geo);
    const mesh=new T.InstancedMesh(g,mat,ids.length),IM=mesh.instanceMatrix.array,IC=new Float32Array(ids.length*3);let sc=1;box.makeEmpty();
    ids.forEach((i,j)=>{IM.set(M.subarray(i*16,i*16+16),j*16);IC.set(Cl.subarray(i*3,i*3+3),j*3);const e=M.subarray(i*16);
      box.expandByPoint(v.set(e[12],e[13],e[14]));sc=Math.max(sc,Math.hypot(e[0],e[1],e[2]),Math.hypot(e[4],e[5],e[6]),Math.hypot(e[8],e[9],e[10]));});
    mesh.instanceColor=new T.InstancedBufferAttribute(IC,3);g.boundingSphere=box.getBoundingSphere(new T.Sphere());g.boundingSphere.radius+=r0*sc;
    mesh.frustumCulled=true;mesh.instanceMatrix.onUpload(dropArray);mesh.instanceColor.onUpload(dropArray);grp.add(mesh);
    if(far){const f=share(far);f.boundingSphere=g.boundingSphere;mesh.userData.lod=[g,f];LODS.push(mesh);}yield;}
  return grp;}
// for gable faces built with n=null the computed normal must point outward & up; enforce upward y for roofs
const _face=GB.prototype.face;
GB.prototype.face=function(pts,n,col){
  if(!n){const a=pts[0],b=pts[1],c=pts[2];const ux=b[0]-a[0],uy=b[1]-a[1],uz=b[2]-a[2],vx=c[0]-a[0],vy=c[1]-a[1],vz=c[2]-a[2];
    let nx=uy*vz-uz*vy,ny=uz*vx-ux*vz,nz=ux*vy-uy*vx;const L=Math.hypot(nx,ny,nz)||1;nx/=L;ny/=L;nz/=L;
    // gable triangles are vertical: orient away from polygon center using stored hint
    if(this._c){let cx=0,cz=0;pts.forEach(p=>{cx+=p[0];cz+=p[2];});cx/=pts.length;cz/=pts.length;
      const up=Math.abs(ny)>.2?ny:0;const out=nx*(cx-this._c[0])+nz*(cz-this._c[1]);
      if((Math.abs(ny)>.2&&ny<0)||(Math.abs(ny)<=.2&&out<0)){nx=-nx;ny=-ny;nz=-nz;}}
    else if(ny<0){nx=-nx;ny=-ny;nz=-nz;}
    return _face.call(this,pts,[nx,ny,nz],col);}
  return _face.call(this,pts,n,col);};
const _gable=GB.prototype.gable;
GB.prototype.gable=function(q,y0,y1,rh,wall,roof){let cx=0,cy=0;q.forEach(p=>{cx+=p[0];cy+=p[1];});this._c=[cx/4,-cy/4];_gable.call(this,q,y0,y1,rh,wall,roof);this._c=null;};
// convex polygon q ([x,y] grid metres) laid on the terrain, `off` metres above it, with the terrain's normals
GB.prototype.onGround=function(q,off,col){
  this.grow(q.length,(q.length-2)*3);const base=this.nv;
  for(const p of q){const k=this.nv*3,n=EN(p[0],p[1]);this.P[k]=p[0];this.P[k+1]=E(p[0],p[1])+off;this.P[k+2]=-p[1];
    this.N[k]=n[0]*127;this.N[k+1]=n[1]*127;this.N[k+2]=n[2]*127;this.C[k]=col[0];this.C[k+1]=col[1];this.C[k+2]=col[2];this.nv++;}
  for(let j=1;j<q.length-1;j++){this.I[this.ni++]=base;this.I[this.ni++]=base+j;this.I[this.ni++]=base+j+1;}};
// drape(src): src holds flat ground layers (y = small layer offset). Each triangle is cut along the terrain mesh's
// edges (x and y grid lines and the cell diagonals), so every piece lies inside one terrain triangle and, raised by
// E(), stays coplanar with it: the layer offsets of a few centimetres keep working on any slope. A piece in a cell
// outside the commune is dropped (rivers and roads that run past the diorama's edge), and one in a cell the limit
// crosses is cut to the commune's part of the cell (LIMT).
function cutAt(q,f,k){const A=[],B=[];for(let i=0;i<q.length;i++){const p=q[i],r=q[(i+1)%q.length],fp=f(p),fr=f(r);
    if(fp<=k)A.push(p);if(fp>=k)B.push(p);
    if((fp<k&&fr>k)||(fp>k&&fr<k)){const t=(k-fp)/(fr-fp),m=[p[0]+(r[0]-p[0])*t,p[1]+(r[1]-p[1])*t];A.push(m);B.push(m);}}
  return [A,B];}
// the three cuts of drapeQ: x, y and the diagonal lines of the terrain mesh, in node units (cut 0, 1, 2)
const cutF=(c,p)=>c===0?(p[0]-EX0)/ES:c===1?(p[1]-EY0)/ES:(p[0]-EX0+p[1]-EY0)/ES;
// cutAt for cut c, with its values at q's points in fq (cutF), into A and B: q's part below k and above it
function cutAtF(q,fq,c,k,A,B){for(let i=0;i<q.length;i++){const i1=i+1<q.length?i+1:0,p=q[i],r=q[i1],fp=fq[i],fr=fq[i1];
    if(fp<=k)A.push(p);if(fp>=k)B.push(p);
    if((fp<k&&fr>k)||(fp>k&&fr<k)){const t=(k-fp)/(fr-fp),m=[p[0]+(r[0]-p[0])*t,p[1]+(r[1]-p[1])*t];A.push(m);B.push(m);}}}
// drapeQ(G, q, off, col): one convex polygon q (grid metres, counter-clockwise), cut the same way, into G
function drapeQ(G,q,off,col){let polys=[q];
  for(let c=0;c<3;c++){const nxt=[];
    for(let q of polys){let lo=1e9,hi=-1e9;for(const p of q){const v=cutF(c,p);if(v<lo)lo=v;if(v>hi)hi=v;}
      for(let k=Math.floor(lo)+1;k<hi;k++){const fq=q.map(p=>cutF(c,p)),A=[],B=[];cutAtF(q,fq,c,k,A,B);if(A.length>2)nxt.push(A);q=B;}
      if(q.length>2)nxt.push(q);}
    polys=nxt;}
  for(const q of polys){let cx=0,cy=0;for(const p of q){cx+=p[0];cy+=p[1];}
    const c=cellOf(cx/q.length,cy/q.length);if(c<0||!CM[c])continue;
    if(CM[c]===1)G.onGround(q,off,col);else for(const t of LIMT.get(c)){const r=clipTo(q,t);if(r.length>2)G.onGround(r,off,col);}}}
// Progressive startup (boot): STAGE is the box of grid metres [x0, y0, x1, y1] the first view needs; what lies outside
// it (a triangle of a ground layer, a land use, a sidewalk's trees) waits in a list for the rest of the generation,
// after the first frame. null: everything at once (outside the startup, or window.__STAGE=0 before the page loads).
let STAGE=null;
const boxIn=(x0,y0,x1,y1)=>!STAGE||(x1>=STAGE[0]&&x0<=STAGE[2]&&y1>=STAGE[1]&&y0<=STAGE[3]);
const polyIn=q=>{let x0=1e9,y0=1e9,x1=-1e9,y1=-1e9;for(const p of q){if(p[0]<x0)x0=p[0];if(p[0]>x1)x1=p[0];if(p[1]<y0)y0=p[1];if(p[1]>y1)y1=p[1];}return boxIn(x0,y0,x1,y1);};
// drape(src, later): the triangles of src outside STAGE go to later (their index and run), for drapeRest(src, later,
// out). The output's runs (GB.grow) count the switches between the two stages, in src's order: tiledParts puts the
// two halves back in that order. out.run and out.prev carry the count on to the strips draped into it (draped)
function drape(src,later){
  const out=new GB(later&&STAGE?1<<16:src.nv*2);const P=src.P,C=src.C,I=src.I;let run=0,prev=-1;
  for(let t=0;t<src.ni;t+=3){const a=I[t]*3,b=I[t+1]*3,c=I[t+2]*3,q=[[P[a],-P[a+2]],[P[b],-P[b+2]],[P[c],-P[c+2]]],d=later&&!polyIn(q)?1:0;
    if(d!==prev){run++;prev=d;}
    if(d){later.push(t,run);continue;}
    out.k=run;drapeQ(out,q,P[a+1],[C[a],C[a+1],C[a+2]]);}
  out.run=run;out.prev=-1;return out;
}
// later's pairs i0..i1 into out
function drapeRest(src,later,out,i0,i1){const P=src.P,C=src.C,I=src.I;
  for(let i=i0;i<i1;i++){const t=later[2*i],a=I[t]*3,b=I[t+1]*3,c=I[t+2]*3;out.k=later[2*i+1];drapeQ(out,[[P[a],-P[a+2]],[P[b],-P[b+2]],[P[c],-P[c+2]]],P[a+1],[C[a],C[a+1],C[a+2]]);}}
// a stand-in for a GB that drapes each quad straight into G: flat strips (sideRibbon) cut as quads, not as two triangles;
// with later, the quads outside STAGE wait there as [q, y, col, run] (drapeQ(G2, ...) after the first frame)
const draped=(G,later)=>({quadXY(q,y,col){let A=0;for(let i=0;i<q.length;i++){const p=q[i],r=q[(i+1)%q.length];A+=p[0]*r[1]-r[0]*p[1];}
  const o=A<0?q.slice().reverse():q,d=later&&!polyIn(o)?1:0;if(G.run===undefined){G.run=0;G.prev=-1;}if(d!==G.prev){G.run++;G.prev=d;}
  if(d)later.push([o,y,col,G.run]);else{G.k=G.run;drapeQ(G,o,y,col);}}});

