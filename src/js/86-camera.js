/* =============== camera =============== */
const EL=Math.PI/6;
const MOB=matchMedia('(max-width:760px)').matches;
const view=MOB?{tx:250,ty:-150,zoom:0.8,az:Math.PI/4}:{tx:420,ty:260,zoom:0.62,az:Math.PI/4};
let W=1,H=1,dirty=true;
const BASEH=3200;
function placeCam(){
  const h=BASEH/view.zoom, a=W/H;cam.left=-h*a/2;cam.right=h*a/2;cam.top=h/2;cam.bottom=-h/2;
  const D=8000;cam.position.set(view.tx+Math.sin(view.az)*Math.cos(EL)*D,Math.sin(EL)*D,-view.ty+Math.cos(view.az)*Math.cos(EL)*D);
  cam.up.set(0,1,0);cam.lookAt(view.tx,0,-view.ty);cam.updateProjectionMatrix();cam.updateMatrixWorld();
  readoutDirty=true;
  const ppm=H/h; uni.uWin.value=Math.max(0,Math.min(1,(ppm-1.2)/1.6));
  fitShadow();dirty=true;
}
// The shadow camera covers the ground the view shows, from the terrain's lowest point to 60 m over its highest. In
// the light's frame a caster and its shadow share x and y, so those bounds are enough across; along the light it
// reaches 400 m toward the sun for what stands outside the view. Its centre moves in whole texels, so the edges of the
// shadows do not shimmer while panning. The bias is a normal offset of about a texel and a half (world metres).
const SLX=new T.Vector3().crossVectors(new T.Vector3(0,1,0),SUND).normalize(),SLY=new T.Vector3().crossVectors(SUND,SLX);
function fitShadow(){
  const o=new T.Vector3(),d=new T.Vector3(),v=new T.Vector3();let x0=1e9,x1=-1e9,y0=1e9,y1=-1e9,z0=1e9,z1=-1e9;
  for(const sx of [-1,1])for(const sy of [-1,1]){o.set(sx,sy,-1).unproject(cam);d.set(sx,sy,1).unproject(cam).sub(o).normalize();
    for(const h of [ELO-5,EHI+60]){v.copy(d).multiplyScalar((h-o.y)/d.y).add(o);
      const px=v.dot(SLX),py=v.dot(SLY),pz=v.dot(SUND);x0=Math.min(x0,px);x1=Math.max(x1,px);y0=Math.min(y0,py);y1=Math.max(y1,py);z0=Math.min(z0,pz);z1=Math.max(z1,pz);}}
  const hx=Math.ceil((x1-x0)/2/8)*8,hy=Math.ceil((y1-y0)/2/8)*8,tx=2*hx/SMAP,ty=2*hy/SMAP;
  const cx=Math.round((x0+x1)/2/tx)*tx,cy=Math.round((y0+y1)/2/ty)*ty;
  sun.target.position.copy(SLX).multiplyScalar(cx).addScaledVector(SLY,cy).addScaledVector(SUND,z0);
  sun.position.copy(sun.target.position).addScaledVector(SUND,z1-z0+400);sun.target.updateMatrixWorld();
  const c=sun.shadow.camera;c.left=-hx;c.right=hx;c.bottom=-hy;c.top=hy;c.near=1;c.far=z1-z0+420;c.updateProjectionMatrix();
  sun.shadow.normalBias=1.5*Math.max(tx,ty);sun.shadow.bias=-0.0002;
}
function resize(){W=canvas.clientWidth;H=canvas.clientHeight;renderer.setSize(W,H,false);placeCam();}
function wpp(){return (BASEH/view.zoom)/H;}
function pan(dx,dy){const R=new T.Vector3().setFromMatrixColumn(cam.matrixWorld,0);const U=new T.Vector3().setFromMatrixColumn(cam.matrixWorld,1);U.y=0;U.normalize();const k=wpp();
  const mx=-R.x*dx*k+U.x*dy*k/Math.sin(EL),mz=-R.z*dx*k+U.z*dy*k/Math.sin(EL);view.tx+=mx;view.ty-=mz;clampView();placeCam();}
function clampView(){view.tx=Math.max(XMIN,Math.min(XMAX,view.tx));view.ty=Math.max(YMIN,Math.min(YMAX,view.ty));view.zoom=Math.max(0.35,Math.min(26,view.zoom));}
const ray=new T.Raycaster(),plane=new T.Plane(new T.Vector3(0,1,0),0);
// the camera aims at the y=0 plane; planeAt() is where a screen point meets it (zoom anchoring, which only needs
// a stable reference), ground() is where it meets the terrain (readout, rotation centre)
function planeAt(px,py){const v=new T.Vector2(px/W*2-1,-(py/H)*2+1);ray.setFromCamera(v,cam);const o=new T.Vector3();return ray.ray.intersectPlane(plane,o)?[o.x,-o.z]:null;}
let EHI=0,ELO=0,cerroMesh=null;
function ground(px,py){const v=new T.Vector2(px/W*2-1,-(py/H)*2+1);ray.setFromCamera(v,cam);const o=ray.ray.origin,d=ray.ray.direction;if(d.y>=0)return null;
  const at=t=>[o.x+d.x*t,-(o.z+d.z*t)],above=t=>{const p=at(t);return o.y+d.y*t-E(p[0],p[1]);};
  let t0=(EHI+1-o.y)/d.y;const t1=(ELO-1-o.y)/d.y,st=ES/2/Math.max(0.2,Math.hypot(d.x,d.z));
  for(let t=t0+st;t<=t1+st;t+=st){if(above(t)<=0){let a=t-st,b=t;for(let k=0;k<20;k++){const m=(a+b)/2;if(above(m)>0)a=m;else b=m;}return at(b);}}
  return at(t1);}
// screen-equivalent point on the y=0 plane of the terrain point (x,y): aim the camera there to centre it
function lift(x,y,az=view.az){const h=E(x,y)/Math.tan(EL);return [x-Math.sin(az)*h,y+Math.cos(az)*h];}
function zoomAt(f,px,py){const g0=px!=null?planeAt(px,py):null;view.zoom*=f;clampView();placeCam();if(g0){const g1=planeAt(px,py);if(g1){view.tx+=g0[0]-g1[0];view.ty+=g0[1]-g1[1];clampView();placeCam();}}}
let anim=null;
function ease(t){return t<.5?4*t*t*t:1-Math.pow(-2*t+2,3)/2;}
function framed(x,y,z){ // shift target so (x,y) lands in the free area between panel and card (mobile: between readout and card)
  const mob=matchMedia('(max-width:760px)').matches;const h=BASEH/z;const k=h/H;
  let ox=0,oy=0;
  if(mob){const top=$('#readout').getBoundingClientRect().bottom,bot=card.hidden?$('#panel').getBoundingClientRect().top:card.getBoundingClientRect().top;
    oy=(bot-top>60?(top+bot)/2:top+30)-H/2;}
  else{const pan=$('#panel');const L=pan.classList.contains('folded')?0:pan.getBoundingClientRect().right;const Rr=W-450;ox=(L+Rr)/2-W/2;}
  const c=Math.cos(view.az),s=Math.sin(view.az);
  // camera right vector on ground (world X,Z) = (cos az, -sin az); ground-up (away from camera) = (-sin az, -cos az)
  const rx=c,rz=-s,ux=-s,uz=-c;const d=oy*k/Math.sin(EL); // oy<0 puts the place above centre, so the target moves toward the camera
  const wx=-ox*k*rx+d*ux,wz=-ox*k*rz+d*uz;
  return [x+wx,y-wz];
}
function flyTo(x,y,z,az){const s={tx:view.tx,ty:view.ty,zoom:view.zoom,az:view.az},e={tx:x,ty:y,zoom:z??view.zoom,az:az??view.az};const t0=performance.now();
  const dur=matchMedia('(prefers-reduced-motion: reduce)').matches?1:1100;
  anim=now=>{let t=Math.min(1,(now-t0)/dur);const k=ease(t);const lz=Math.log(s.zoom)+(Math.log(e.zoom)-Math.log(s.zoom))*k;
    const hop=Math.sin(Math.PI*k)*Math.min(0.9,Math.hypot(e.tx-s.tx,e.ty-s.ty)/2500);
    view.tx=s.tx+(e.tx-s.tx)*k;view.ty=s.ty+(e.ty-s.ty)*k;view.zoom=Math.exp(lz-hop);view.az=s.az+(e.az-s.az)*k;placeCam();if(t>=1)anim=null;};}

/* =============== input =============== */
const ptrs=new Map();let lastPinch=0,moved=0;
canvas.addEventListener('pointerdown',e=>{canvas.setPointerCapture(e.pointerId);ptrs.set(e.pointerId,[e.clientX,e.clientY]);moved=0;anim=null;canvas.classList.add('drag');if(ptrs.size===2){const [a,b]=[...ptrs.values()];lastPinch=Math.hypot(a[0]-b[0],a[1]-b[1]);}});
canvas.addEventListener('pointermove',e=>{const rect=canvas.getBoundingClientRect();hoverPt=[e.clientX-rect.left,e.clientY-rect.top];readoutDirty=true;
  if(!ptrs.has(e.pointerId))return;const p=ptrs.get(e.pointerId);const dx=e.clientX-p[0],dy=e.clientY-p[1];ptrs.set(e.pointerId,[e.clientX,e.clientY]);
  if(ptrs.size===1){pan(dx,dy);moved+=Math.abs(dx)+Math.abs(dy);}
  else if(ptrs.size===2){const [a,b]=[...ptrs.values()];const d=Math.hypot(a[0]-b[0],a[1]-b[1]);if(lastPinch){zoomAt(d/lastPinch,(a[0]+b[0])/2-rect.left,(a[1]+b[1])/2-rect.top);}lastPinch=d;moved+=10;}});
const up=e=>{ptrs.delete(e.pointerId);if(ptrs.size<2)lastPinch=0;if(!ptrs.size)canvas.classList.remove('drag');};
canvas.addEventListener('pointerup',up);canvas.addEventListener('pointercancel',up);
canvas.addEventListener('wheel',e=>{e.preventDefault();anim=null;const rect=canvas.getBoundingClientRect();const f=Math.exp(-e.deltaY*(e.deltaMode===1?0.05:0.0016));zoomAt(f,e.clientX-rect.left,e.clientY-rect.top);},{passive:false});
canvas.addEventListener('dblclick',e=>{const rect=canvas.getBoundingClientRect();zoomAt(1.8,e.clientX-rect.left,e.clientY-rect.top);});
window.addEventListener('keydown',e=>{if(e.target.closest('input'))return;const k=e.key;let h=true;
  if(k==='ArrowLeft')pan(120,0);else if(k==='ArrowRight')pan(-120,0);else if(k==='ArrowUp')pan(0,120);else if(k==='ArrowDown')pan(0,-120);
  else if(k==='+'||k==='=')zoomAt(1.4,W/2,H/2);else if(k==='-'||k==='_')zoomAt(1/1.4,W/2,H/2);
  else if(k==='q'||k==='Q')rotate(-1);else if(k==='e'||k==='E')rotate(1);else if(k==='Escape'){closeCard();}else h=false;if(h)e.preventDefault();});
function turnTo(az){const g=ground(W/2,H/2);const t=g?lift(g[0],g[1],az):[view.tx,view.ty];flyTo(t[0],t[1],view.zoom,az);} // turn around the terrain point in the centre
function rotate(dir){turnTo(Math.round((view.az-Math.PI/4)/(Math.PI/2))*(Math.PI/2)+Math.PI/4+dir*Math.PI/2);}
$('#zin').onclick=()=>zoomAt(1.5,W/2,H/2);$('#zout').onclick=()=>zoomAt(1/1.5,W/2,H/2);
$('#rl').onclick=()=>rotate(-1);$('#rr').onclick=()=>rotate(1);
$('#compass').onclick=()=>turnTo(Math.PI/4);

