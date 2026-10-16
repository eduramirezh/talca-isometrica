/* =============== pixel art =============== */
// The map is always drawn as pixel art (docs/PROYECTOS-SIMILARES.md, point 3). The scene is drawn at 1/k of the
// screen into a target with depth. A screen pass shows each low-resolution pixel as k x k screen pixels and
//  - outline 1: darkens the pixels of a surface whose neighbour is more than `edge` metres farther away (the
//    silhouette, one pixel wide, in a darker shade of the surface's own colour);
//  - outline 2: also the creases, where the normal turns on a surface at the same depth (ridges, wall corners): the
//    normals come from the depth itself. The camera is orthographic, so a plane has a depth that is linear on the
//    screen; each pixel takes the slope of its own surface in x and y from the one-sided difference whose line goes on
//    through the next pixel (the other one crosses the crease), and a crease is where the normal of a pixel and of its
//    neighbour above or to the right make an angle whose cosine is under `fold` (0.8, about 37 degrees), the same test
//    as the normals pass this replaced (a whole second render, ~45 % of a still frame at zoom 4; it is still there
//    for comparison: crease:'normals'). For the slopes to be exact, that render's near and far hug what the view can
//    hold (depthSpan); a crease from depth needs a surface two art pixels wide, so the stairs of a landmark or the
//    facets of a small tree can differ by a pixel from the normals pass;
//  - palette n: reduces the frame to n colours found in it (k-means), after the outlines.
// The art pixel is m = 0.5 m: k (screen pixels per art pixel, a whole number) follows the zoom and the screen's pixel
// ratio to keep it close; zoomed out, where a screen pixel is already larger, k is 1. The outlines thin out with the
// art pixel: creases up to 1 m, silhouettes up to 2 m, none beyond (in the initial
// view every distant tree turned into a dark dot). The low-resolution
// image is anchored to the world (the grid origin falls on a whole art pixel), so panning moves it in whole art
// pixels instead of making them crawl. For tools and comparisons: __pixelArt({m, k, outline, palette, edge, dark,
// fold, crease, span}) changes it and returns the metres per art pixel (crease:'normals' draws the creases with the
// normals pass, span:false keeps the camera's own near and far); __pixelArt(null) turns it off (a plain render).
// paRender(lite), while the camera moves (loop), leaves out the normals pass and its creases; the creases from depth
// cost nothing and stay.
let PA=null;
const paQuad=(()=>{const g=new T.PlaneGeometry(2,2);const m=new T.ShaderMaterial({
  uniforms:{tC:{value:null},tD:{value:null},tN:{value:null},res:{value:new T.Vector2()},off:{value:new T.Vector2()},k:{value:2},range:{value:1},edge:{value:1},cDepth:{value:1},fold:{value:.8},art:{value:.5},
    dark:{value:.55},crease:{value:.8},uOut:{value:0},npal:{value:0},pal:{value:Array.from({length:64},()=>new T.Vector3())}},
  vertexShader:'void main(){gl_Position=vec4(position.xy,0.,1.);}',
  fragmentShader:`uniform sampler2D tC,tD,tN;uniform vec2 res,off;uniform float k,range,edge,dark,crease,uOut,cDepth,fold,art;uniform int npal;uniform vec3 pal[64];
    float D(vec2 p){return texture2D(tD,(p+.5)/res).x*range;}
    // the depth slope of p's own surface along e: of the two one-sided differences, the one whose line goes on
    // through the next pixel on that side (a crease or an edge next to p bends the other)
    float S(vec2 p,vec2 e,float d){float l=D(p-e),r=D(p+e);return abs(D(p-2.*e)-2.*l+d)<abs(d-2.*r+D(p+2.*e))?d-l:r-d;}
    vec3 M(vec2 p){float d=D(p);return normalize(vec3(S(p,vec2(1,0),d),S(p,vec2(0,1),d),art));}
    vec3 N(vec2 p){return texture2D(tN,(p+.5)/res).xyz*2.-1.;}
    void main(){
      vec2 p=floor((gl_FragCoord.xy-off)/k);vec4 c=texture2D(tC,(p+.5)/res);
      if(c.a>0.&&uOut>.5){float d=D(p);
        float far=max(max(D(p+vec2(1,0)),D(p-vec2(1,0))),max(D(p+vec2(0,1)),D(p-vec2(0,1))))-d;
        if(far>edge)c.rgb*=dark;
        else if(uOut>1.5&&cDepth>.5){vec3 n=M(p);
          if(min(dot(n,M(p+vec2(1,0))),dot(n,M(p+vec2(0,1))))<fold)c.rgb*=crease;}
        else if(uOut>1.5){vec3 n=N(p);
          if(min(dot(n,N(p+vec2(1,0))),dot(n,N(p+vec2(0,1))))<fold)c.rgb*=crease;}}
      if(c.a>0.&&npal>0){float bd=1e9;vec3 b=c.rgb;
        for(int i=0;i<64;i++){if(i>=npal)break;vec3 q=pal[i]-c.rgb;float r=(pal[i].r+c.r)*.5;float dd=(2.+r)*q.r*q.r+4.*q.g*q.g+(3.-r)*q.b*q.b;if(dd<bd){bd=dd;b=pal[i];}}
        c.rgb=b;}
      gl_FragColor=c;}`,depthTest:false,depthWrite:false});
  const q=new T.Mesh(g,m);q.frustumCulled=false;const sc=new T.Scene();sc.add(q);return {sc,m,cam:new T.Camera()};})();
const paNorm=new T.MeshNormalMaterial();
// n colours for the frame's pixels: k-means (k-means++ seeding with a fixed seed) over a sample of the opaque ones
function paPalette(rt,n){const w=rt.width,h=rt.height,buf=new Uint8Array(w*h*4);renderer.readRenderTargetPixels(rt,0,0,w,h,buf);
  const S=[];for(let i=0;i<w*h;i+=5)if(buf[i*4+3]>0)S.push([buf[i*4]/255,buf[i*4+1]/255,buf[i*4+2]/255]);if(!S.length)return [];
  const r=rng(7),d2=(a,b)=>(a[0]-b[0])**2+(a[1]-b[1])**2+(a[2]-b[2])**2;const C=[S[Math.floor(r()*S.length)].slice()];
  const md=S.map(p=>d2(p,C[0]));
  while(C.length<n){let t=0;for(const v of md)t+=v;let x=r()*t,i=0;for(;i<S.length-1&&x>md[i];i++)x-=md[i];C.push(S[i].slice());for(let j=0;j<S.length;j++)md[j]=Math.min(md[j],d2(S[j],S[i]));}
  const A=new Int32Array(S.length);
  for(let it=0;it<12;it++){const sum=C.map(()=>[0,0,0,0]);
    S.forEach((p,j)=>{let b=0,bd=1e9;for(let c=0;c<C.length;c++){const v=d2(p,C[c]);if(v<bd){bd=v;b=c;}}A[j]=b;const s=sum[b];s[0]+=p[0];s[1]+=p[1];s[2]+=p[2];s[3]++;});
    sum.forEach((s,c)=>{if(s[3])C[c]=[s[0]/s[3],s[1]/s[3],s[2]/s[3]];});}
  return C;}
function paFit(o){const sz=renderer.getDrawingBufferSize(new T.Vector2()),mpp=(cam.top-cam.bottom)/sz.y;
  if(o.m)o.k=Math.max(1,Math.round(o.m/mpp));const a=o.k*mpp;
  // a surface seen at 30 degrees changes depth by ~1.7 m per metre of screen: the edge is above that
  if(o.edgeAuto)o.edge=Math.max(1.2,3*a);o.ol=o.outline==null?(a<=1?2:a<=2?1:0):o.outline;return a;}
// near and far of the camera around what the view can hold: the frustum's corners at the lowest point of the scene
// (the foot of the diorama's sides, under the lowest terrain) and above the highest (the Cerro's statue, towers). The
// depth texture has 24 bits: over the camera's own ±30 km a step is 3.6 mm, too coarse for the slopes the creases
// are read from zoomed in; over this span it is a few hundredths of a millimetre at zoom 14
const DSV=new T.Vector3(),DSF=new T.Vector3();
function depthSpan(){const M=cam.matrixWorld;DSF.setFromMatrixColumn(M,2).negate();let n=1e9,f=-1e9;
  for(const x of [cam.left,cam.right])for(const y of [cam.bottom,cam.top]){DSV.set(x,y,0).applyMatrix4(M);
    for(const h of [ELO-60,EHI+250]){const t=(h-DSV.y)/DSF.y;n=Math.min(n,t);f=Math.max(f,t);}}
  return [n-10,f+10];}
function paRender(lite){const o=PA,a=paFit(o),sz=renderer.getDrawingBufferSize(new T.Vector2()),w=Math.ceil(sz.x/o.k)+1,h=Math.ceil(sz.y/o.k)+1;
  const opt={minFilter:T.NearestFilter,magFilter:T.NearestFilter};
  if(!o.rt||o.rt.width!==w||o.rt.height!==h){if(o.rt)o.rt.dispose();if(o.nt){o.nt.dispose();o.nt=null;}
    o.rt=new T.WebGLRenderTarget(w,h,opt);o.rt.depthTexture=new T.DepthTexture(w,h);o.rt.depthTexture.type=T.UnsignedIntType;}
  // the camera covers w x h art pixels of a metres, moved by a fraction of one so that the grid origin falls on a
  // whole art pixel; the screen pass moves back by that fraction (off, in screen pixels)
  const l=cam.left,rr=cam.right,t=cam.top,b=cam.bottom,v=new T.Vector3().applyMatrix4(cam.matrixWorldInverse);
  const fx=(v.x-l)/a-Math.floor((v.x-l)/a),fy=(v.y-b)/a-Math.floor((v.y-b)/a);
  cam.left=l+fx*a;cam.right=cam.left+w*a;cam.bottom=b+fy*a;cam.top=cam.bottom+h*a;
  const n0=cam.near,f0=cam.far,dn=o.span===false?[n0,f0]:depthSpan();cam.near=dn[0];cam.far=dn[1];cam.updateProjectionMatrix();
  const range=cam.far-cam.near,dc=o.crease!=='normals';
  for(const p of GLOWPTS)p.material.size=9/o.k; // the glows keep their size on screen
  renderer.setRenderTarget(o.rt);renderer.render(scene,cam);
  if(o.ol>1&&!lite&&!dc){if(!o.nt)o.nt=new T.WebGLRenderTarget(w,h,opt); // the normals' target, only for crease:'normals'
const lv=GLOWPTS.map(p=>p.visible),rv=ring.visible;for(const p of GLOWPTS)p.visible=false;ring.visible=false; // (the colour pass drew the shadow map, if due)
    scene.overrideMaterial=paNorm;renderer.setRenderTarget(o.nt);renderer.render(scene,cam);scene.overrideMaterial=null;
    GLOWPTS.forEach((p,i)=>p.visible=lv[i]);ring.visible=rv;}
  cam.left=l;cam.right=rr;cam.top=t;cam.bottom=b;cam.near=n0;cam.far=f0;cam.updateProjectionMatrix();
  const U=paQuad.m.uniforms;U.tC.value=o.rt.texture;U.tD.value=o.rt.depthTexture;U.tN.value=o.nt?o.nt.texture:null;U.res.value.set(w,h);U.k.value=o.k;
  U.range.value=range;U.edge.value=o.edge;U.dark.value=o.dark;U.uOut.value=lite&&!dc?Math.min(o.ol,1):o.ol;U.off.value.set(fx*o.k,fy*o.k);
  U.cDepth.value=dc?1:0;U.fold.value=o.fold;U.art.value=a;
  const P=o.palette?paPalette(o.rt,Math.min(64,o.palette)):[];U.npal.value=P.length;P.forEach((c,i)=>U.pal.value[i].set(c[0],c[1],c[2]));
  renderer.setRenderTarget(null);renderer.render(paQuad.sc,paQuad.cam);}
window.__pixelArt=o=>{if(!o){PA=null;for(const p of GLOWPTS)p.material.size=9;dirty=true;return 0;}
  PA=Object.assign({k:2,m:0,outline:null,palette:0,dark:.55,crease:'depth',fold:.8},o);if(o.k&&!o.m)PA.m=0;else if(!o.k&&!o.m)PA.m=0.5;
  PA.edgeAuto=o.edge===undefined;dirty=true;return paFit(PA);};
window.__pixelArt({m:0.5});

