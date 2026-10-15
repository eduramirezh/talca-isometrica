/* =============== geometry builder =============== */
class GB{
  constructor(cap=1<<15){this.cap=cap;this.P=new Float32Array(cap*3);this.N=new Int8Array(cap*3);this.C=new Uint8Array(cap*3);this.icap=cap*2;this.I=new Uint32Array(this.icap);this.nv=0;this.ni=0;this.dy=0;}
  grow(v,i){if(this.nv+v>this.cap){let c=this.cap;while(this.nv+v>c)c*=2;const P=new Float32Array(c*3);P.set(this.P);this.P=P;const N=new Int8Array(c*3);N.set(this.N);this.N=N;const C=new Uint8Array(c*3);C.set(this.C);this.C=C;this.cap=c;}
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
const CUTS=[p=>(p[0]-EX0)/ES,p=>(p[1]-EY0)/ES,p=>(p[0]-EX0+p[1]-EY0)/ES];
function cutAt(q,f,k){const A=[],B=[];for(let i=0;i<q.length;i++){const p=q[i],r=q[(i+1)%q.length],fp=f(p),fr=f(r);
    if(fp<=k)A.push(p);if(fp>=k)B.push(p);
    if((fp<k&&fr>k)||(fp>k&&fr<k)){const t=(k-fp)/(fr-fp),m=[p[0]+(r[0]-p[0])*t,p[1]+(r[1]-p[1])*t];A.push(m);B.push(m);}}
  return [A,B];}
// drapeQ(G, q, off, col): one convex polygon q (grid metres, counter-clockwise), cut the same way, into G
function drapeQ(G,q,off,col){let polys=[q];
  for(const f of CUTS){const nxt=[];
    for(let q of polys){let lo=1e9,hi=-1e9;for(const p of q){const v=f(p);if(v<lo)lo=v;if(v>hi)hi=v;}
      for(let k=Math.floor(lo)+1;k<hi;k++){const [A,B]=cutAt(q,f,k);if(A.length>2)nxt.push(A);q=B;}
      if(q.length>2)nxt.push(q);}
    polys=nxt;}
  for(const q of polys){let cx=0,cy=0;for(const p of q){cx+=p[0];cy+=p[1];}
    const c=cellOf(cx/q.length,cy/q.length);if(c<0||!CM[c])continue;
    if(CM[c]===1)G.onGround(q,off,col);else for(const t of LIMT.get(c)){const r=clipTo(q,t);if(r.length>2)G.onGround(r,off,col);}}}
function drape(src){
  const out=new GB(src.nv*2);const P=src.P,C=src.C,I=src.I;
  for(let t=0;t<src.ni;t+=3){const a=I[t]*3,b=I[t+1]*3,c=I[t+2]*3;
    drapeQ(out,[[P[a],-P[a+2]],[P[b],-P[b+2]],[P[c],-P[c+2]]],P[a+1],[C[a],C[a+1],C[a+2]]);}
  return out;
}
// a stand-in for a GB that drapes each quad straight into G: flat strips (sideRibbon) cut as quads, not as two triangles
const draped=G=>({quadXY(q,y,col){let A=0;for(let i=0;i<q.length;i++){const p=q[i],r=q[(i+1)%q.length];A+=p[0]*r[1]-r[0]*p[1];}drapeQ(G,A<0?q.slice().reverse():q,y,col);}});

