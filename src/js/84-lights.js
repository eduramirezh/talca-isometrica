/* =============== street lights (night) =============== */
function lamps(){
  const pts=[];for(let i=0;i<GLOW.length;i+=3)pts.push(GLOW[i],GLOW[i+1],-GLOW[i+2]);
  for(let i=0;i<ALAM_LAMPS.length;i+=2){const x=ALAM_LAMPS[i],y=ALAM_LAMPS[i+1];pts.push(x,E(x,y)+4.6,-y);}
  streets.forEach(s=>{if(s.c>3)return;let acc=0;for(let i=0;i<s.pts.length-1;i++){const a=s.pts[i],b=s.pts[i+1];const L=Math.hypot(b[0]-a[0],b[1]-a[1]);let u=(35-acc%35);while(u<L){const t=u/L;const x=a[0]+(b[0]-a[0])*t,y=a[1]+(b[1]-a[1])*t;if(inTerrain(x,y)&&urbanAt(x,y))pts.push(x,E(x,y)+6,-y);u+=35;}acc+=L;}});
  const g=new T.BufferGeometry();g.setAttribute('position',new T.Float32BufferAttribute(pts,3));
  const p=new T.Points(g,glowMat());p.visible=false;GLOWPTS.push(p);return p;
}
// the glow of a night light, a sprite of 9 screen pixels (paRender divides it by k); GLOWPTS: every Points that
// uses it (the street lamps, the trains' headlights), toggled together by the pixel art
const GLOWPTS=[];
function glowMat(){const c=document.createElement('canvas');c.width=c.height=32;const x=c.getContext('2d');const gr=x.createRadialGradient(16,16,0,16,16,16);gr.addColorStop(0,'rgba(255,225,150,1)');gr.addColorStop(.35,'rgba(255,200,110,.5)');gr.addColorStop(1,'rgba(255,190,90,0)');x.fillStyle=gr;x.fillRect(0,0,32,32);
  return new T.PointsMaterial({size:9,sizeAttenuation:false,map:new T.CanvasTexture(c),transparent:true,depthWrite:false,blending:T.AdditiveBlending});}

/* =============== selection ring =============== */
const ring=new T.Mesh(new T.RingGeometry(0.8,1,48),new T.MeshBasicMaterial({color:0x7A1F3D,transparent:true,opacity:.9,depthWrite:false}));
ring.rotation.x=-Math.PI/2;ring.visible=false;ring.renderOrder=5;scene.add(ring);

