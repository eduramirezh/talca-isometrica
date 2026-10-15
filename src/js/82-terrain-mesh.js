/* =============== terrain mesh + diorama cut =============== */
// The terrain of the commune: the cells inside the limit share the grid's nodes; the cells it crosses add their
// commune part (LIMT clipped to each terrain triangle) with vertices of their own, on the same planes (E, the node
// colours and EN interpolated). The cut sides follow the limit and the terrain's profile along it.
function terrainMesh(){
  const P=[],C=[],N=[],idx=[];
  const f0=PAL.field,sc=[hex('#8FA05E'),hex('#7E9153')],dry=hex('#A9A26C'),CC=[new Float32Array(EN_),new Float32Array(EN_),new Float32Array(EN_)];
  for(let j=0;j<ENY;j++)for(let i=0;i<ENX;i++){const k=j*ENX+i,x=EX0+i*ES,y=EY0+j*ES;P.push(x,EH[k],-y);N.push(ENRM[k*3],ENRM[k*3+1],ENRM[k*3+2]);
    const n=0.5+0.5*Math.sin(x*0.013+y*0.021)*Math.cos(x*0.007-y*0.011);const g=n>.5?sc[0]:sc[1];
    const hi=Math.max(0,Math.min(1,(ER[k]-120)/90))*0.6; // dry grass on the high ground
    const w=EW[k],f=0.94+0.12*n;for(let c=0;c<3;c++){CC[c][k]=(f0[c]*(1-w)+(g[c]*(1-hi)+dry[c]*hi)*w)/255*f;C.push(CC[c][k]);}}
  let lo=1e9;
  for(let c=0;c<CM.length;c++){if(!CM[c])continue;const i=c%ECW,j=(c-i)/ECW,a=j*ENX+i,b=a+1,cc=a+ENX,d=cc+1;
    lo=Math.min(lo,EH[a],EH[b],EH[cc],EH[d]);
    if(CM[c]===1){idx.push(a,b,cc,b,d,cc);continue;} // diagonal b-c, as in sampleTri()
    const x0=EX0+i*ES,y0=EY0+j*ES,tris=[[[x0,y0],[x0+ES,y0],[x0,y0+ES]],[[x0+ES,y0],[x0+ES,y0+ES],[x0,y0+ES]]];
    for(const tt of tris)for(const t of LIMT.get(c)){const q=clipTo(t,tt);if(q.length<3)continue;const base=P.length/3;
      for(const [x,y] of q){const n=EN(x,y);P.push(x,E(x,y),-y);N.push(n[0],n[1],n[2]);for(let k=0;k<3;k++)C.push(sampleTri(CC[k],x,y));}
      for(let m=1;m<q.length-1;m++)idx.push(base,base+m,base+m+1);}}
  const g=new T.BufferGeometry();g.setAttribute('position',new T.Float32BufferAttribute(P,3));g.setAttribute('normal',new T.Float32BufferAttribute(N,3));
  g.setAttribute('color',new T.Float32BufferAttribute(C,3));g.setIndex(idx);
  const grp=new T.Group();grp.add(new T.Mesh(g,new T.MeshLambertMaterial({vertexColors:true})));
  // the cut sides: topsoil, soil, and a darker stratum near the base. Each edge of the limit is split where it crosses
  // the terrain's edges, so the top follows the surface exactly
  const BOT=lo-45,S=new GB(1<<14),soil=hex('#8A6A4C'),top=hex('#5E4630'),strat=hex('#6F5238');
  for(let k=0;k<LIM.length;k++){const A=LIM[k],B=LIM[(k+1)%LIM.length],L=Math.hypot(B[0]-A[0],B[1]-A[1]);if(L<1e-6)continue;
    const n=[(B[1]-A[1])/L,0,(B[0]-A[0])/L]; // outward: right of a counter-clockwise ring, (dy, -dx) in grid metres
    const pts=[0,...gridCuts(A,B,true),1].map(t=>[A[0]+(B[0]-A[0])*t,A[1]+(B[1]-A[1])*t]);
    for(let m=0;m<pts.length-1;m++){const a=pts[m],b=pts[m+1];const ha=E(a[0],a[1]),hb=E(b[0],b[1]);
      const q=(y0a,y0b,y1a,y1b,c)=>S.face([[a[0],y0a,-a[1]],[b[0],y0b,-b[1]],[b[0],y1b,-b[1]],[a[0],y1a,-a[1]]],n,c);
      q(ha-3,hb-3,ha,hb,top);q(BOT+16,BOT+16,ha-3,hb-3,soil);q(BOT+9,BOT+9,BOT+16,BOT+16,strat);q(BOT,BOT,BOT+9,BOT+9,soil);}}
  grp.add(new T.Mesh(S.geo(),new T.MeshLambertMaterial({vertexColors:true,side:T.DoubleSide})));
  return grp;
}
