/* =============== terrain mesh + diorama cut =============== */
function terrainMesh(){
  const P=new Float32Array(EN_*3),C=new Float32Array(EN_*3),idx=[];
  const f0=PAL.field,sc=[hex('#8FA05E'),hex('#7E9153')],dry=hex('#A9A26C');
  for(let j=0;j<ENY;j++)for(let i=0;i<ENX;i++){const k=j*ENX+i,x=EX0+i*ES,y=EY0+j*ES;P[k*3]=x;P[k*3+1]=EH[k];P[k*3+2]=-y;
    const n=0.5+0.5*Math.sin(x*0.013+y*0.021)*Math.cos(x*0.007-y*0.011);const g=n>.5?sc[0]:sc[1];
    const hi=Math.max(0,Math.min(1,(ER[k]-120)/90))*0.6; // dry grass on the high ground
    const w=EW[k],f=0.94+0.12*n;for(let c=0;c<3;c++)C[k*3+c]=(f0[c]*(1-w)+(g[c]*(1-hi)+dry[c]*hi)*w)/255*f;}
  for(let j=0;j<ENY-1;j++)for(let i=0;i<ENX-1;i++){const a=j*ENX+i,b=a+1,c=a+ENX,d=c+1;idx.push(a,b,c,b,d,c);} // diagonal b-c, as in sampleTri()
  const g=new T.BufferGeometry();g.setAttribute('position',new T.BufferAttribute(P,3));g.setAttribute('normal',new T.BufferAttribute(ENRM,3));
  g.setAttribute('color',new T.BufferAttribute(C,3));g.setIndex(idx);
  const grp=new T.Group();grp.add(new T.Mesh(g,new T.MeshLambertMaterial({vertexColors:true})));
  // the cut sides of the diorama follow the terrain's profile: topsoil, soil, and a darker stratum near the base
  let lo=1e9;for(let k=0;k<EN_;k++)lo=Math.min(lo,EH[k]);const BOT=lo-45;
  const S=new GB(1<<12),soil=hex('#8A6A4C'),top=hex('#5E4630'),strat=hex('#6F5238');
  const edge=(pts,n)=>{for(let k=0;k<pts.length-1;k++){const [a,b]=[pts[k],pts[k+1]];const ha=E(a[0],a[1]),hb=E(b[0],b[1]);
      const q=(y0a,y0b,y1a,y1b,c)=>S.face([[a[0],y0a,-a[1]],[b[0],y0b,-b[1]],[b[0],y1b,-b[1]],[a[0],y1a,-a[1]]],n,c);
      q(ha-3,hb-3,ha,hb,top);q(BOT+16,BOT+16,ha-3,hb-3,soil);q(BOT+9,BOT+9,BOT+16,BOT+16,strat);q(BOT,BOT,BOT+9,BOT+9,soil);}};
  const X1=EX1,Y1=EY1,xs=[],ys=[];for(let i=0;i<ENX;i++)xs.push(EX0+i*ES);for(let j=0;j<ENY;j++)ys.push(EY0+j*ES);
  edge(xs.map(x=>[x,EY0]),[0,0,1]);edge(xs.map(x=>[x,Y1]),[0,0,-1]);edge(ys.map(y=>[EX0,y]),[-1,0,0]);edge(ys.map(y=>[X1,y]),[1,0,0]);
  grp.add(new T.Mesh(S.geo(),new T.MeshLambertMaterial({vertexColors:true,side:T.DoubleSide})));
  return grp;
}

