/* =============== pixel art =============== */
// The map is always drawn as pixel art (docs/PROYECTOS-SIMILARES.md, point 3). The scene is drawn at 1/k of the
// screen into a target with depth; a second pass draws its normals. A screen pass shows each low-resolution pixel as
// k x k screen pixels and
//  - outline 1: darkens the pixels of a surface whose neighbour is more than `edge` metres farther away (the
//    silhouette, one pixel wide, in a darker shade of the surface's own colour);
//  - outline 2: also the creases, where the normal turns on a surface at the same depth (ridges, wall corners);
//  - palette n: reduces the frame to n colours found in it (k-means), after the outlines.
// The art pixel is m = 0.5 m: k (screen pixels per art pixel, a whole number) follows the zoom and the screen's pixel
// ratio to keep it close; zoomed out, where a screen pixel is already larger, k is 1. The outlines thin out with the
// art pixel: creases up to 1 m (their pass costs a whole render), silhouettes up to 2 m, none beyond (in the initial
// view every distant tree turned into a dark dot). The low-resolution
// image is anchored to the world (the grid origin falls on a whole art pixel), so panning moves it in whole art
// pixels instead of making them crawl. For tools and comparisons: __pixelArt({m, k, outline, palette, edge, dark})
// changes it and returns the metres per art pixel; __pixelArt(null) turns it off (a plain render, as before).
let PA=null;
const paQuad=(()=>{const g=new T.PlaneGeometry(2,2);const m=new T.ShaderMaterial({
  uniforms:{tC:{value:null},tD:{value:null},tN:{value:null},res:{value:new T.Vector2()},off:{value:new T.Vector2()},k:{value:2},range:{value:1},edge:{value:1},
    dark:{value:.55},crease:{value:.8},uOut:{value:0},npal:{value:0},pal:{value:Array.from({length:64},()=>new T.Vector3())}},
  vertexShader:'void main(){gl_Position=vec4(position.xy,0.,1.);}',
  fragmentShader:`uniform sampler2D tC,tD,tN;uniform vec2 res,off;uniform float k,range,edge,dark,crease,uOut;uniform int npal;uniform vec3 pal[64];
    float D(vec2 p){return texture2D(tD,(p+.5)/res).x*range;}
    vec3 N(vec2 p){return texture2D(tN,(p+.5)/res).xyz*2.-1.;}
    void main(){
      vec2 p=floor((gl_FragCoord.xy-off)/k);vec4 c=texture2D(tC,(p+.5)/res);
      if(c.a>0.&&uOut>.5){float d=D(p);
        float far=max(max(D(p+vec2(1,0)),D(p-vec2(1,0))),max(D(p+vec2(0,1)),D(p-vec2(0,1))))-d;
        if(far>edge)c.rgb*=dark;
        else if(uOut>1.5){vec3 n=N(p);
          float t=min(dot(n,N(p+vec2(1,0))),dot(n,N(p+vec2(0,1))));
          if(t<.8)c.rgb*=crease;}}
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
function paRender(){const o=PA,a=paFit(o),sz=renderer.getDrawingBufferSize(new T.Vector2()),w=Math.ceil(sz.x/o.k)+1,h=Math.ceil(sz.y/o.k)+1;
  if(!o.rt||o.rt.width!==w||o.rt.height!==h){if(o.rt){o.rt.dispose();o.nt.dispose();}
    const opt={minFilter:T.NearestFilter,magFilter:T.NearestFilter};o.rt=new T.WebGLRenderTarget(w,h,opt);o.rt.depthTexture=new T.DepthTexture(w,h);o.rt.depthTexture.type=T.UnsignedIntType;
    o.nt=new T.WebGLRenderTarget(w,h,opt);}
  // the camera covers w x h art pixels of a metres, moved by a fraction of one so that the grid origin falls on a
  // whole art pixel; the screen pass moves back by that fraction (off, in screen pixels)
  const l=cam.left,rr=cam.right,t=cam.top,b=cam.bottom,v=new T.Vector3().applyMatrix4(cam.matrixWorldInverse);
  const fx=(v.x-l)/a-Math.floor((v.x-l)/a),fy=(v.y-b)/a-Math.floor((v.y-b)/a);
  cam.left=l+fx*a;cam.right=cam.left+w*a;cam.bottom=b+fy*a;cam.top=cam.bottom+h*a;cam.updateProjectionMatrix();
  for(const p of GLOWPTS)p.material.size=9/o.k; // the glows keep their size on screen
  renderer.setRenderTarget(o.rt);renderer.render(scene,cam);
  if(o.ol>1){const au=renderer.shadowMap.autoUpdate,lv=GLOWPTS.map(p=>p.visible),rv=ring.visible;renderer.shadowMap.autoUpdate=false;for(const p of GLOWPTS)p.visible=false;ring.visible=false;
    scene.overrideMaterial=paNorm;renderer.setRenderTarget(o.nt);renderer.render(scene,cam);scene.overrideMaterial=null;
    renderer.shadowMap.autoUpdate=au;GLOWPTS.forEach((p,i)=>p.visible=lv[i]);ring.visible=rv;}
  cam.left=l;cam.right=rr;cam.top=t;cam.bottom=b;cam.updateProjectionMatrix();
  const U=paQuad.m.uniforms;U.tC.value=o.rt.texture;U.tD.value=o.rt.depthTexture;U.tN.value=o.nt.texture;U.res.value.set(w,h);U.k.value=o.k;
  U.range.value=cam.far-cam.near;U.edge.value=o.edge;U.dark.value=o.dark;U.uOut.value=o.ol;U.off.value.set(fx*o.k,fy*o.k);
  const P=o.palette?paPalette(o.rt,Math.min(64,o.palette)):[];U.npal.value=P.length;P.forEach((c,i)=>U.pal.value[i].set(c[0],c[1],c[2]));
  renderer.setRenderTarget(null);renderer.render(paQuad.sc,paQuad.cam);}
window.__pixelArt=o=>{if(!o){PA=null;for(const p of GLOWPTS)p.material.size=9;dirty=true;return 0;}
  PA=Object.assign({k:2,m:0,outline:null,palette:0,dark:.55},o);if(o.k&&!o.m)PA.m=0;else if(!o.k&&!o.m)PA.m=0.5;
  PA.edgeAuto=o.edge===undefined;dirty=true;return paFit(PA);};
window.__pixelArt({m:0.5});

