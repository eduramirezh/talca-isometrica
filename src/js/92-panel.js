/* =============== selection / card =============== */
let selId=null,tour=null;
const card=$('#card');
function esc(s){return String(s).replace(/[&<>"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));}
function select(id,fly){const p=BYID[id];if(!p)return;selId=id;
  if(tour&&PD.tours[tour.k].s[tour.i]!==id){const idx=PD.tours[tour.k].s.indexOf(id);if(idx<0)tour=null;else tour.i=idx;}
  const m=MODELS[id];ring.visible=true;ring.position.set(m?m.x:p.x,E(m?m.x:p.x,m?m.y:p.y)+1,-(m?m.y:p.y));ring.userData.t0=performance.now();ring.material.color.set(cssVar('--c-'+p.c)||'#7A1F3D');
  renderCard(p);
  if(fly){const z=p.id==='cerro-la-virgen'?2.2:p.id.startsWith('utalca')?2.4:Math.max(view.zoom,4.2);const f=framed(...lift(m?m.x:p.x,m?m.y:p.y),z);flyTo(f[0],f[1],z);}
  try{history.replaceState(null,'','#'+id);}catch(e){}
  document.querySelectorAll('#list li button').forEach(b=>b.classList.toggle('sel',b.dataset.id===id));
  dirty=true;}
function closeCard(){selId=null;tour=null;card.hidden=true;ring.visible=false;dirty=true;try{history.replaceState(null,'',location.pathname+location.search);}catch(e){}document.querySelectorAll('#list li button.sel').forEach(b=>b.classList.remove('sel'));}
function renderCard(p){
  card.style.setProperty('--cc',`var(--c-${p.c})`);
  // the category says what kind of institution a place is; «Hitos de la ciudad» says nothing the name and the map don't
  const lab=[tour&&PD.tours[tour.k].n,[p.c,...p.cs].filter(c=>c!=='ciudad').map(c=>CATS[c].n).join(' · ')].filter(Boolean).map(esc).join(' · ');
  // a Mapcarta source is an OSM object (mapcarta.com/W123 is way 123): the OSM button opens it and the source is not listed
  const mc=p.src.find(s=>/mapcarta\.com\/(es\/)?[NWR]\d+$/.test(s[1])),oid=mc&&mc[1].split('/').pop(),srcs=p.src.filter(s=>s!==mc);
  const osm=oid?`https://www.openstreetmap.org/${{N:'node',W:'way',R:'relation'}[oid[0]]}/${oid.slice(1)}`:`https://www.openstreetmap.org/?mlat=${p.lat}&mlon=${p.lon}#map=18/${p.lat}/${p.lon}`;
  // an issue on the repository, already titled and with the place, for corrections from people who are not developers
  const issue='https://github.com/eduramirezh/talca-isometrica/issues/new?title='+encodeURIComponent(`Corrección: ${p.n}`)+'&body='+
    encodeURIComponent(`Lugar: ${p.n} (#${p.id})\nDirección en el mapa: ${p.a}\n\nQué está mal:\n\n\nFuente (una página oficial, una foto fechada o el objeto de OpenStreetMap):\n`);
  let tn='';
  if(tour){const T0=PD.tours[tour.k];const n=T0.s.length;tn=`<div class="tournav"><button class="btn ghost" id="tprev" ${tour.i===0?'disabled':''}>Anterior</button><div class="prog"><i style="width:${((tour.i+1)/n*100).toFixed(1)}%"></i></div><span>${tour.i+1}/${n}</span><button class="btn" id="tnext">${tour.i===n-1?'Terminar':'Siguiente'}</button></div>`;}
  card.innerHTML=`<div class="in">
    <div class="top"><div>${lab?`<div class="cat">${lab}</div>`:''}<h2>${esc(p.n)}</h2></div><button class="x" id="cx" aria-label="Cerrar ficha">×</button></div>
    <div class="addr">${esc(p.a)}</div>
    <p>${esc(p.d)}</p>
    ${p.sub?`<ul class="sub">${p.sub.map(s=>`<li>${esc(s)}</li>`).join('')}</ul>`:''}
    ${p.f?`<div class="fact">${esc(p.f)}</div>`:''}
    ${srcs.length?`<div class="src">Fuentes: ${srcs.map(s=>`<a href="${esc(s[1])}" target="_blank" rel="noopener">${esc(s[0])}</a>`).join(' · ')}</div>`:''}
    <div class="actions"><button class="btn ghost" id="cz">Acercar</button><a class="btn ghost" href="${osm}" target="_blank" rel="noopener">Ver en OpenStreetMap</a></div>
    <a class="report" href="${issue}" target="_blank" rel="noopener">Reportar un error en este lugar</a>
    ${tn}</div>`;
  card.hidden=false;
  $('#cx').onclick=closeCard;$('#cz').onclick=()=>{const m=MODELS[p.id];const t=lift(m?m.x:p.x,m?m.y:p.y);flyTo(t[0],t[1],Math.max(view.zoom*1.6,6));};
  if(tour){$('#tprev').onclick=()=>stepTour(-1);$('#tnext').onclick=()=>stepTour(1);}
}
function startTour(k){tour={k,i:0};select(PD.tours[k].s[0],true);}
function stepTour(d){const s=PD.tours[tour.k].s;const i=tour.i+d;if(i>=s.length){closeCard();flyTo(420,260,0.9);return;}tour.i=Math.max(0,i);select(s[tour.i],true);}

/* =============== panel =============== */
function buildPanel(){
  const counts={};POIS.forEach(p=>{counts[p.c]=(counts[p.c]||0)+1;});
  const mk=(c,host)=>{const b=document.createElement('button');b.className='chip';b.style.setProperty('--cc',`var(--c-${c})`);b.setAttribute('aria-pressed','true');b.innerHTML=`<i></i>${CATS[c].n} <b>${counts[c]||0}</b>`;
    b.onclick=()=>{if(enabled.has(c))enabled.delete(c);else enabled.add(c);b.setAttribute('aria-pressed',enabled.has(c));renderList();dirty=true;};host.appendChild(b);};
  LEGAL.forEach(c=>mk(c,$('#chips-legal')));mk('ciudad',$('#chips-city'));
  $('#q').addEventListener('input',renderList);
  renderList();
  // tours
  const pr=$('#p-rutas');pr.innerHTML='';Object.entries(PD.tours).forEach(([k,t])=>{const d=document.createElement('div');d.className='tour';
    d.innerHTML=`<p class="eyebrow">${t.s.length} paradas</p><h3>${esc(t.n)}</h3><p>${esc(t.d)}</p><ol>${t.s.map(id=>`<li>${esc(BYID[id].n)}</li>`).join('')}</ol><div><button class="btn">Comenzar recorrido</button></div>`;
    d.querySelector('button').onclick=()=>{if(matchMedia('(max-width:760px)').matches)$('#panel').classList.add('folded');startTour(k);};pr.appendChild(d);});
  // tabs
  document.querySelectorAll('.tabs [role=tab]').forEach(t=>t.onclick=()=>{document.querySelectorAll('.tabs [role=tab]').forEach(u=>{u.setAttribute('aria-selected',u===t);$('#'+u.dataset.pane).hidden=u!==t;});$('#panel').classList.remove('folded');});
  $('#fold').onclick=()=>{$('#panel').classList.toggle('folded');};
  if(matchMedia('(max-width:760px)').matches)$('#panel').classList.add('folded');
}
function norm(s){return s.normalize('NFD').replace(/[̀-ͯ]/g,'').toLowerCase();}
function renderList(){
  const q=norm($('#q').value.trim());const host=$('#list');host.innerHTML='';
  [...LEGAL,'ciudad'].forEach(c=>{const items=POIS.filter(p=>p.c===c&&enabled.has(c)&&(!q||norm(p.n+' '+p.a+' '+(p.sub||[]).join(' ')).includes(q)));if(!items.length)return;
    const g=document.createElement('div');g.className='group';g.style.setProperty('--cc',`var(--c-${c})`);
    g.innerHTML=`<h3><i></i>${CATS[c].n}</h3><ul>${items.map(p=>`<li><button data-id="${p.id}" class="${p.id===selId?'sel':''}"><span class="nm">${esc(p.n)}</span><span class="ad">${esc(p.a)}</span></button></li>`).join('')}</ul>`;
    g.querySelectorAll('button').forEach(b=>b.onclick=()=>{tour=null;if(matchMedia('(max-width:760px)').matches)$('#panel').classList.add('folded');select(b.dataset.id,true);});host.appendChild(g);});
  if(!host.children.length)host.innerHTML='<p style="color:var(--ink-3);margin:0">Sin resultados. Pruebe con otra palabra o active más capas.</p>';
}

/* =============== day / night =============== */
let night=false,lampPts=null;
function setNight(v){night=v;$('#night').setAttribute('aria-pressed',v);$('#stage').classList.toggle('night',v);
  uni.uNight.value=v?1:0;hemi.intensity=v?0.55:HEMI_I;hemi.color.set(v?0x8C9CD0:0xF4F1E6);hemi.groundColor.set(v?0x2A3048:0x8E8A70);sun.intensity=v?0.22:SUN_I;sun.color.set(v?0x9DB0E0:0xFFF3DD);sun.castShadow=!v;
  if(lampPts)lampPts.visible=v;trainsNight(v);shDirty=dirty=true;}
$('#night').onclick=()=>setNight(!night);
$('#streets').onclick=()=>{showStreets=!showStreets;$('#streets').setAttribute('aria-pressed',showStreets);dirty=true;};


