/* =============== three setup =============== */
const canvas=$('#gl');
let renderer;
try{renderer=new T.WebGLRenderer({canvas,antialias:true,alpha:true,powerPreference:'high-performance'});}
catch(e){$('#err').hidden=false;$('#err').textContent='Este navegador no puede mostrar gráficos WebGL, que la maqueta necesita.';return;}
const DPR=Math.min(window.devicePixelRatio||1,2);
renderer.setPixelRatio(DPR);renderer.setClearColor(0x000000,0);
const scene=new T.Scene();
const cam=new T.OrthographicCamera(-1,1,1,-1,-30000,30000);
const HEMI_I=0.5,SUN_I=0.82;
const hemi=new T.HemisphereLight(0xF4F1E6,0x8E8A70,HEMI_I);scene.add(hemi);
const sun=new T.DirectionalLight(0xFFF3DD,SUN_I);scene.add(sun);scene.add(sun.target);
// The sun from the north-north-east, 45 degrees up, stronger than the sky: a roof, a sunlit wall and a wall in shade
// get three clear tones, as in a city-builder. From the initial view (from the south-east) the east walls are lit,
// the south walls in shade, and the shadows fall in front of those, where they are seen; from the north-east, as the
// sun was before, they fell behind the buildings. Buildings, landmarks and trees cast them; the shadow camera follows
// the view (fitShadow)
const SUND=new T.Vector3(0.36,0.707,-0.61).normalize();
const SMAP=Math.min(matchMedia('(max-width:760px)').matches?2048:4096,renderer.capabilities.maxTextureSize); // 64 MB at 4096
renderer.shadowMap.enabled=true;renderer.shadowMap.type=T.PCFShadowMap;
sun.castShadow=true;sun.shadow.mapSize.set(SMAP,SMAP);
const uni={uNight:{value:0},uWin:{value:0}};
function winMat(){const m=new T.MeshLambertMaterial({vertexColors:true});
  m.onBeforeCompile=sh=>{sh.uniforms.uNight=uni.uNight;sh.uniforms.uWin=uni.uWin;
    sh.vertexShader=sh.vertexShader.replace('#include <common>','#include <common>\nvarying vec3 vWP;varying vec3 vWN;').replace('#include <project_vertex>','#include <project_vertex>\nvWP=(modelMatrix*vec4(transformed,1.0)).xyz;vWN=normalize(mat3(modelMatrix)*objectNormal);');
    sh.fragmentShader=sh.fragmentShader.replace('#include <common>','#include <common>\nvarying vec3 vWP;varying vec3 vWN;uniform float uNight;uniform float uWin;').replace('#include <tonemapping_fragment>',`
      if(abs(vWN.y)<0.3 && vWP.y>1.0){
        vec2 t=normalize(vec2(-vWN.z,vWN.x));float u=dot(vWP.xz,t);float v=vWP.y-1.0;
        vec2 fr=vec2(fract(u/3.4),fract(v/3.0));
        float win=step(0.26,fr.x)*step(fr.x,0.74)*step(0.28,fr.y)*step(fr.y,0.80);
        float h=fract(sin(dot(vec2(floor(u/3.4),floor(v/3.0))+floor(vWP.xz*0.013)*7.0,vec2(12.9898,78.233)))*43758.5453);
        gl_FragColor.rgb=mix(gl_FragColor.rgb,gl_FragColor.rgb*0.70+vec3(0.03,0.05,0.08),win*uWin*(1.0-uNight));
        gl_FragColor.rgb+=win*step(0.58,h)*uNight*uWin*vec3(1.0,0.78,0.42)*0.95;
        gl_FragColor.rgb+=win*step(0.58,h)*uNight*(1.0-uWin)*vec3(1.0,0.78,0.42)*0.25;
      }
      #include <tonemapping_fragment>`);};
  return m;}
const matFlat=new T.MeshLambertMaterial({vertexColors:true});
// the Río Claro's water lies at the height of its shore strips and over the blocks: a depth offset of two steps keeps it
// on top wherever they meet (the bridge, 3 cm above, stays over it)
const matWater=new T.MeshLambertMaterial({vertexColors:true,polygonOffset:true,polygonOffsetFactor:-1,polygonOffsetUnits:-2});
const matBld=winMat();

