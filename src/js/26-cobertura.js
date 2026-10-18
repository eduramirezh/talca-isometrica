// ==== cobertura de CONAF ====
// The vegetation cover of CONAF's land-use cadastre (Maule, 2024 update): a class every 40 m (data/cobertura.json,
// pipeline/cobertura.py; DATA.cob). The slope rule of 25-terrain.js (EW, wildAt) finds the native forest and the scrub
// on the hills, but not the plantations and the feral woods of the plain (willow, acacia and blackberry along the
// esteros): each node of the relief takes the larger of its slope weight and its class's (COB_W), so the terrain's
// colour, the farmland parcels (buildBase skips wild ground), wildTrees() and the urban fringe follow both. EW is
// raised here, once, before anything reads it. cobTall(x,y): a plantation of eucalyptus or pine there (its trees are
// drawn as the poplar's column). Without DATA.cob nothing changes.
const COB=(()=>{const D=DATA.cob;if(!D)return null;const a=new Uint8Array(D.n[0]*D.n[1]);
  for(let i=0,p=0;i<D.c.length;i+=2){a.fill(D.c[i],p,p+D.c[i+1]);p+=D.c[i+1];}return {o:D.o,s:D.s,n:D.n,k:D.k,a};})();
const COB_W={'pradera':.14,'humedal':.3,'matorral-pradera':.45,'matorral':.6,'matorral-arborescente':.75,'nativo-abierto':.7,
  'nativo-semidenso':.9,'nativo-denso':1,'mixto':.9,'asilvestrada':.9,'plantacion':1,'plantacion-joven':.5};
const cobK=(x,y)=>{if(!COB)return -1;const i=Math.round((x-COB.o[0])/COB.s),j=Math.round((y-COB.o[1])/COB.s);
  return i<0||j<0||i>=COB.n[0]||j>=COB.n[1]?-1:COB.a[j*COB.n[0]+i];}; // the class index at the nearest node
const cobTall=(x,y)=>{const k=cobK(x,y);return k>=0&&COB.k[k].endsWith('-alta');};
if(COB){const W=COB.k.map(n=>COB_W[n.replace(/-alta$/,'')]||0);
  for(let j=0;j<ENY;j++)for(let i=0;i<ENX;i++){const k=cobK(EX0+i*ES,EY0+j*ES);if(k>0&&W[k]>EW[j*ENX+i])EW[j*ENX+i]=W[k];}}
