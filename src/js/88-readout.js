/* =============== readout (grid address) =============== */
const NS=DATA.lines.ns.slice().sort((a,b)=>a[1]-b[1]), OP=DATA.lines.op.slice().sort((a,b)=>a[1]-b[1]);
const baseOP=n=>{const [k,d]=n.split(' ');return d==='Poniente'?800-100*k:700+100*k;};
const baseNS=n=>{const [k,d]=n.split(' ');return d==='Sur'?1200-100*k:1100+100*k;};
function bracket(list,v){for(let i=0;i<list.length-1;i++)if(v>=list[i][1]&&v<list[i+1][1])return i;return -1;}
const KX=111320*Math.cos(35.4265*Math.PI/180),KY=110950,TH=5*Math.PI/180;
function toLL(x,y){const xr=x*Math.cos(-TH)-y*Math.sin(-TH),yr=x*Math.sin(-TH)+y*Math.cos(-TH);return [-35.42653+yr/KY,-71.666+xr/KX];}
const shortN=n=>n.replace(' Norte',' N').replace(' Sur',' S').replace(' Oriente',' Or.').replace(' Poniente',' Pon.');
function gridAddr(x,y){
  const i=bracket(NS,y),j=bracket(OP,x);
  if(i<0||j<0)return null;
  const dS=Math.min(Math.abs(y-NS[i][1]),Math.abs(y-NS[i+1][1])),dO=Math.min(Math.abs(x-OP[j][1]),Math.abs(x-OP[j+1][1]));
  const fx=(x-OP[j][1])/(OP[j+1][1]-OP[j][1]),fy=(y-NS[i][1])/(NS[i+1][1]-NS[i][1]);
  const between=`entre ${OP[j][0].split(' ')[0]} y ${OP[j+1][0]} · entre ${NS[i][0].split(' ')[0]} y ${NS[i+1][0]}`.replace(/entre (\d+) y (\d+ Oriente)/,'entre $1 y $2').replace(/1 y 1 Oriente/,'1 Poniente y 1 Oriente').replace(/1 y 1 Norte/,'1 Sur y 1 Norte');
  if(dS<=dO&&dS<22){const st=Math.abs(y-NS[i][1])<Math.abs(y-NS[i+1][1])?NS[i][0]:NS[i+1][0];const n=Math.round((baseOP(OP[j][0])+fx*100)/10)*10;return {a:`${st} ≈ ${n}`,b:between};}
  if(dO<22){const st=Math.abs(x-OP[j][1])<Math.abs(x-OP[j+1][1])?OP[j][0]:OP[j+1][0];const n=Math.round((baseNS(NS[i][0])+fy*100)/10)*10;return {a:`${st} ≈ ${n}`,b:between};}
  return {a:`Manzana ${shortN(OP[j][0])}–${shortN(OP[j+1][0])} / ${shortN(NS[i][0])}–${shortN(NS[i+1][0])}`,b:between};
}
let hoverPt=null,readoutDirty=true;
function updateReadout(){if(!readoutDirty)return;readoutDirty=false;const p=hoverPt?ground(hoverPt[0],hoverPt[1]):ground(W/2,H/2);if(!p)return;
  const ll=toLL(p[0],p[1]);const g=gridAddr(p[0],p[1]);const cc=`${ll[0].toFixed(5)}, ${ll[1].toFixed(5)} · ${Math.round(EV.z0+sampleTri(ER,p[0],p[1]))} m s. n. m.`;
  $('#ro-a').textContent=g?g.a:'Fuera del centro numerado';$('#ro-b').textContent=g?`${g.b} · ${cc}`:cc;}

