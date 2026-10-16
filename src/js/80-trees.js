/* =============== trees (instanced) =============== */
function treeGeo(kind){
  const g1=kind==='poplar'?new T.CylinderGeometry(0.01,1.6,9,6,1):new T.IcosahedronGeometry(3.2,0);
  if(kind!=='poplar'){g1.scale(1,1.05,1);g1.translate(0,5.4,0);}else g1.translate(0,7.2,0);
  const g2=new T.CylinderGeometry(0.3,0.4,kind==='poplar'?3:2.8,5,1);g2.translate(0,kind==='poplar'?1.5:1.4,0);
  const a=g1.index?g1.toNonIndexed():g1,b=g2.index?g2.toNonIndexed():g2;
  const n=a.attributes.position.count+b.attributes.position.count;
  const P=new Float32Array(n*3),N=new Float32Array(n*3),C=new Float32Array(n*3);
  P.set(a.attributes.position.array);P.set(b.attributes.position.array,a.attributes.position.count*3);
  a.computeVertexNormals();b.computeVertexNormals();
  N.set(a.attributes.normal.array);N.set(b.attributes.normal.array,a.attributes.position.count*3);
  const cg=kind==='poplar'?[.42,.56,.28]:[.40,.54,.27],cb=[.42,.33,.25];
  for(let i=0;i<n;i++){const c=i<a.attributes.position.count?cg:cb;C.set(c,i*3);}
  const g=new T.BufferGeometry();g.setAttribute('position',new T.BufferAttribute(P,3));g.setAttribute('normal',new T.BufferAttribute(N,3));g.setAttribute('color',new T.BufferAttribute(C,3));return g;
}
// The far tree: where an art pixel is LOD_A metres or more a tree is two to four pixels wide, and its 40 triangles (44
// a poplar) cost as much as all the buildings. It is drawn as a bipyramid of the crown's size reaching down to the
// ground (n sides: 10 triangles for the round tree, 4 for the poplar's cone, without a trunk).
const LOD_A=2;
function treeFar(kind){const P=[],C=[],cg=kind==='poplar'?[.42,.56,.28]:[.40,.54,.27],n=kind==='poplar'?4:5,
    [r,ym,yt,yb]=kind==='poplar'?[1.8,2.7,11.7,1.2]:[3.5,5.4,8.8,1.2];
  for(let i=0;i<n;i++){const a=i/n*2*Math.PI,b=(i+1)/n*2*Math.PI,A=[r*Math.cos(a),ym,r*Math.sin(a)],B=[r*Math.cos(b),ym,r*Math.sin(b)];
    P.push(...A,0,yt,0,...B);if(kind!=='poplar')P.push(...B,0,yb,0,...A);}
  for(let i=0;i<P.length/3;i++)C.push(...cg);
  const g=new T.BufferGeometry();g.setAttribute('position',new T.Float32BufferAttribute(P,3));g.setAttribute('color',new T.Float32BufferAttribute(C,3));g.computeVertexNormals();return g;}
// near or far trees for an art pixel of a metres (a=null: back to choosing by a; __lod('near'|'far') holds one, for
// tools/variants.py)
let lodFar=null,lodHold=null;
function setLod(a){const far=lodHold?lodHold==='far':a>=LOD_A;if(far===lodFar)return;lodFar=far;for(const m of LODS)m.geometry=m.userData.lod[far?1:0];shDirty=true;}
window.__lod=v=>{lodHold=v||null;lodFar=null;dirty=true;};
function instTrees(list,kind,yfn){list=list.filter(t=>inTerrain(t[0],t[1])); // only in the commune
  const q=new T.Quaternion(),s=new T.Vector3(),p=new T.Vector3(),Y=new T.Vector3(0,1,0);
  return instTiled(treeGeo(kind),new T.MeshLambertMaterial({vertexColors:true}),list,(t,m,col)=>{const sc=t[2];s.set(sc,sc*(0.9+t[3]*0.3),sc);p.set(t[0],E(t[0],t[1])+0.1,-t[1]);q.setFromAxisAngle(Y,t[3]*6);m.compose(p,q,s);
    const v=0.82+t[3]*0.36;col.setRGB(v*(0.96+0.08*Math.sin(t[3]*40)),v,v*(0.9+0.1*Math.cos(t[3]*23)));},treeFar(kind));
}

