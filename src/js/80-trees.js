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
function instTrees(list,kind,yfn){list=list.filter(t=>inTerrain(t[0],t[1])); // only in the commune
  const mesh=new T.InstancedMesh(treeGeo(kind),new T.MeshLambertMaterial({vertexColors:true}),list.length);
  const m=new T.Matrix4(),q=new T.Quaternion(),s=new T.Vector3(),p=new T.Vector3(),col=new T.Color();
  list.forEach((t,i)=>{const sc=t[2];s.set(sc,sc*(0.9+t[3]*0.3),sc);p.set(t[0],E(t[0],t[1])+0.1,-t[1]);q.setFromAxisAngle(new T.Vector3(0,1,0),t[3]*6);m.compose(p,q,s);mesh.setMatrixAt(i,m);
    const v=0.82+t[3]*0.36;col.setRGB(v*(0.96+0.08*Math.sin(t[3]*40)),v,v*(0.9+0.1*Math.cos(t[3]*23)));mesh.setColorAt(i,col);});
  mesh.instanceMatrix.needsUpdate=true;if(mesh.instanceColor)mesh.instanceColor.needsUpdate=true;
  return mesh;
}

