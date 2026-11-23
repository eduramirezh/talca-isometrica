// ==== measured street profiles ====
// The avenues whose section was measured in photos (config/perfiles.json, completed by pipeline/perfiles.py into
// DATA.perfiles; today the Avenida Las Rastras): their axis (from OSM), sections (what lies on each side of the axis,
// from the inside out: lanes, a painted bike lane, shoulder, kerb, grass, dirt, sidewalk, a bike path at sidewalk
// level), the mouths of the side streets, poles, bus stops and rows of trees. The game draws them up close
// (modelo3d/modelos/las_rastras.gd, from the same file); here, what an art pixel of 0.5 m can show.
// At decode time (before 20-grids.js builds segs) each of the map's streets that is the avenue (d.calles: its index,
// stretch and lateral reach) becomes the axis from s0 to s1, shifted so that its ribbon and its lot margin (WALK_OUT)
// cover from a to b, one fence line to the other: the lots of the city start where the real fences stand, and its
// generic sidewalks, curbs, street trees, parked cars and lamps are left out (walk 0, s.perfil). perfilesBase() lays
// the bands over the ribbon in buildBase (draped with the rest of the ground: the startup's two stages need nothing
// else), plants the rows of trees (stage 0: TREES and PO_FIELD, like a landmark's) and puts the lamps of the poles in GLOW.
const PERF=[]; // {key, P (the axis), S (the station of each point), L (its length), d (DATA.perfiles[key])}
function pfAt(pf,s,d=0){s=Math.min(Math.max(s,0),pf.L);let i=0;while(i<pf.P.length-2&&pf.S[i+1]<s)i++;
  const a=pf.P[i],b=pf.P[i+1],L=(pf.S[i+1]-pf.S[i])||1,tx=(b[0]-a[0])/L,ty=(b[1]-a[1])/L,u=s-pf.S[i];
  return [a[0]+tx*u+ty*d,a[1]+ty*u-tx*d];}
// the axis from s0 to s1, d m to its right (mitred at its vertices: the offset stays d)
function pfTramo(pf,s0,s1,d=0){const out=[pfAt(pf,s0,d)],P=pf.P;
  for(let k=1;k<P.length-1;k++){if(pf.S[k]<=s0+0.5||pf.S[k]>=s1-0.5)continue;
    const L0=Math.hypot(P[k][0]-P[k-1][0],P[k][1]-P[k-1][1])||1,L1=Math.hypot(P[k+1][0]-P[k][0],P[k+1][1]-P[k][1])||1;
    const n0=[(P[k][1]-P[k-1][1])/L0,-(P[k][0]-P[k-1][0])/L0],n1=[(P[k+1][1]-P[k][1])/L1,-(P[k+1][0]-P[k][0])/L1];
    let mx=n0[0]+n1[0],my=n0[1]+n1[1];const m=Math.hypot(mx,my)||1;mx/=m;my/=m;const k2=Math.max(0.5,mx*n0[0]+my*n0[1]);
    out.push([P[k][0]+mx*d/k2,P[k][1]+my*d/k2]);}
  out.push(pfAt(pf,s1,d));return out;}
for(const key in DATA.perfiles||{}){const d=DATA.perfiles[key],P=dec(d.eje).map(([x,y])=>[x/10,y/10]),S=[0];
  for(let i=1;i<P.length;i++)S.push(S[i-1]+Math.hypot(P[i][0]-P[i-1][0],P[i][1]-P[i-1][1]));
  const pf={key,P,S,L:S[S.length-1],d};PERF.push(pf);
  for(const [i,s0,s1,a,b,name] of d.calles){const s=streets[i];
    if(!s||s.name!==name){console.warn(`perfil ${key}: la calle ${i} no es «${name}» (make perfiles)`);continue;}
    s.w=Math.max(1,b-a-2*WALK_OUT);s.walk=0;s.perfil=key;if(s1-s0>0.5)s.pts=pfTramo(pf,s0,s1,(a+b)/2);}}
function pfSec(pf,s){const X=pf.d.secciones;for(const x of X)if(s>=x.s[0]&&s<x.s[1])return x;return X[X.length-1];}
function pfBoca(pf,s,lado,r=0){return pf.d.bocas.some(b=>b[2]===lado&&s>=b[0]-r&&s<=b[1]+r);}
// how far the map's street reaches on one side at s (its lot margin)
function pfBorde(pf,s,lado){let m=0;for(const c of pf.d.calles)if(s>=c[1]-1&&s<=c[2]+1)m=Math.max(m,lado<0?-c[3]:c[4]);return m;}
// the bands on one side (-1 left, 1 right) at s: [type, d0, d1, extra], from the inside out, the last one to the fence
// or to the map street's edge, whichever is farther (modelo3d/modelos/las_rastras.gd bandas(): the same)
function pfBandas(pf,s,lado){const sec=pfSec(pf,s),out=[];let d=sec.centro==='bandejon'?(sec.bandejon||0)/2:0;
  for(const b of sec[lado<0?'O':'E']){out.push([b[0],d,d+b[1],b[2]||'']);d+=b[1];}
  out[out.length-1][2]=Math.max(d,pfBorde(pf,s,lado));return out;}
const PF_CALZADA=new Set(['pista','ciclo','berma']);
function perfilesBase(B){const st=STATS.perfiles={bands:0,trees:0,lamps:0};
  const K={pasto:PAL.lawn,tierra:hex('#BCA781'),vereda:WALK_K,ciclovia:hex('#6B92C2'),gris:hex('#8C8A86'),solera:CURB_K,
    amarilla:hex('#D8B23C'),ciclo:hex('#86A3C4'),maleza:hex('#A39A6E')};
  const band=(pf,sa,sb,d0,d1,y,col)=>{if(d1-d0<0.01)return;sideRibbon(B,pfTramo(pf,sa,sb,0),-1,d0,d1-d0,y,col);st.bands++;};
  for(const pf of PERF){const cuts=new Set([0,pf.L]);
    for(const x of pf.d.secciones)for(const v of x.s)cuts.add(Math.min(v,pf.L));
    for(const b of pf.d.bocas)for(const v of [b[0],b[1]])if(v>0&&v<pf.L)cuts.add(v);
    const cs=[...cuts].sort((p,q)=>p-q);
    for(let i=0;i+1<cs.length;i++){const sa=cs[i],sb=cs[i+1];if(sb-sa<0.05)continue;const sm=(sa+sb)/2,sec=pfSec(pf,sm);
      // the median: 1.5 m of dirt and weeds between concrete kerbs, open where a side street comes in
      if(sec.centro==='bandejon'&&!pfBoca(pf,sm,-1,2)&&!pfBoca(pf,sm,1,2)){const m=(sec.bandejon||0)/2;
        band(pf,sa,sb,-m,-m+CURB,Y_LAYER.curb,K.solera);band(pf,sa,sb,-m+CURB,m-CURB,Y_LAYER.curb,K.maleza);band(pf,sa,sb,m-CURB,m,Y_LAYER.curb,K.solera);}
      for(const lado of [-1,1]){const boca=pfBoca(pf,sm,lado);
        for(const [t,d0,d1,x] of pfBandas(pf,sm,lado)){if(t==='pista'||t==='berma'||(boca&&!PF_CALZADA.has(t)))continue;
          const span=lado<0?[-d1,-d0]:[d0,d1];
          if(t==='solera'){const c=x==='amarilla'?K.amarilla:K.solera;band(pf,sa,sb,...(lado<0?[-d0-CURB,-d0]:[d0,d0+CURB]),Y_LAYER.curb,c);continue;}
          if(t==='ciclo'){band(pf,sa,sb,...span,Y_LAYER.curb,K.ciclo);continue;}
          band(pf,sa,sb,...span,Y_LAYER.walk,t==='ciclovia'?(x==='azul'?K.ciclovia:K.gris):K[t]||K.tierra);}}}
    // the lamps of the poles: the head of the arm, 2.1 m over the carriageway and 7.9 m up (las_rastras.gd poste())
    for(const [x,y,nx,ny] of pf.d.postes){const hx=x+nx*2.1,hy=y+ny*2.1;if(!inTerrain(hx,hy))continue;GLOW.push(hx,E(x,y)+7.9,hy);st.lamps++;}
    // the rows of trees seen in the photos: Lombardy poplars, a eucalyptus wood (~25 m) and a row of street trees
    const r=rng(7349);
    for(const [x,y,esp] of pf.d.hileras){if(!inTerrain(x,y))continue;st.trees++;
      if(esp==='alamo')PO_FIELD.push([x,y,2.0+r()*0.3,r()]);
      else if(esp==='eucalipto')TREES.push([x,y,2.0+r()*0.4,0.15+r()*0.3]);
      else TREES.push([x,y,1.0+r()*0.15,r()]);}}}
