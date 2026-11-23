// ==== street lights (night) ====
// where a landmark puts its own street lamps (they go in GLOW): [[x0, y0, x1, y1], street-name regex], the generic
// ones of those streets left out (hitos/calles-plaza.js)
const LAMP_SKIP=[];
// streetLamps(): the street lamps, one every 35 m along the main streets (class 3 or less) in the urban area, on the
// axis: [x, y, tx, ty (along the street), the half carriageway (curb to axis), its number along the street, the
// street's class]. The page draws only their glow (no posts); the game (tools/export.js __exLamps) stands a post at the curb.
// A street of a measured profile (s.perfil) has its own, on its poles (perfilesBase, in GLOW)
function streetLamps(){const out=[];
  streets.forEach(s=>{if(s.c>3||s.perfil)return;const cw=swOf(s)/2-walkOf(s);let acc=0,n=0;for(let i=0;i<s.pts.length-1;i++){const a=s.pts[i],b=s.pts[i+1];const L=Math.hypot(b[0]-a[0],b[1]-a[1]);let u=(35-acc%35);while(u<L){const t=u/L;const x=a[0]+(b[0]-a[0])*t,y=a[1]+(b[1]-a[1])*t;if(inTerrain(x,y)&&urbanAt(x,y)&&!LAMP_SKIP.some(([bx,re])=>re.test(s.name||'')&&x>=bx[0]&&x<=bx[2]&&y>=bx[1]&&y<=bx[3]))out.push([x,y,(b[0]-a[0])/L,(b[1]-a[1])/L,cw,n++,s.c]);u+=35;}acc+=L;}});
  return out;}
function lamps(){
  const pts=[];for(let i=0;i<GLOW.length;i+=3)pts.push(GLOW[i],GLOW[i+1],-GLOW[i+2]);
  for(let i=0;i<ALAM_LAMPS.length;i+=2){const x=ALAM_LAMPS[i],y=ALAM_LAMPS[i+1];pts.push(x,E(x,y)+4.6,-y);}
  for(const [x,y] of streetLamps())pts.push(x,E(x,y)+6,-y);
  const g=new T.BufferGeometry();g.setAttribute('position',new T.Float32BufferAttribute(pts,3));
  const p=new T.Points(g,glowMat());p.visible=false;GLOWPTS.push(p);return p;
}
// the glow of a night light, a sprite of 9 screen pixels (paRender divides it by k); GLOWPTS: every Points that
// uses it (the street lamps, the trains' headlights), toggled together by the pixel art
const GLOWPTS=[];
function glowMat(){const c=document.createElement('canvas');c.width=c.height=32;const x=c.getContext('2d');const gr=x.createRadialGradient(16,16,0,16,16,16);gr.addColorStop(0,'rgba(255,225,150,1)');gr.addColorStop(.35,'rgba(255,200,110,.5)');gr.addColorStop(1,'rgba(255,190,90,0)');x.fillStyle=gr;x.fillRect(0,0,32,32);
  return new T.PointsMaterial({size:9,sizeAttenuation:false,map:new T.CanvasTexture(c),transparent:true,depthWrite:false,blending:T.AdditiveBlending});}

// ==== selection ring ====
const selRing=new T.Mesh(new T.RingGeometry(0.8,1,48),new T.MeshBasicMaterial({color:0x7A1F3D,transparent:true,opacity:.9,depthWrite:false}));
selRing.rotation.x=-Math.PI/2;selRing.visible=false;selRing.renderOrder=5;scene.add(selRing);
// the pulse: RING_PULSES rings that grow and fade after select() (it sets userData.t0), then the ring hides. Every pulse
// frame redraws the whole scene (the pixel-art pass), so ringTick() asks for one at RING_FPS, like trainsTick(), and
// only while it pulses: an open card used to keep the map drawing at the display's rate for as long as it stayed open
const RING_MS=1800,RING_PULSES=3,RING_FPS=18;
function ringTick(now){if(!selRing.visible)return false;const u=selRing.userData,e=now-(u.t0||0);
  if(e>=RING_MS*RING_PULSES){selRing.visible=false;return true;}
  const t=(e%RING_MS)/RING_MS,s=18+t*38;selRing.scale.set(s,s,s);selRing.material.opacity=0.85*(1-t);
  if(now-(u.drawn||0)<1000/RING_FPS-2)return false;u.drawn=now;return true;}

