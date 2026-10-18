/* =============== categories =============== */
const CATS={
  tribunales:{n:'Tribunales',ic:'M10 3v13M5 16h10M4 6h12M4 6l-2.5 5a2.5 2.5 0 0 0 5 0zM16 6l-2.5 5a2.5 2.5 0 0 0 5 0z'},
  fiscalia:{n:'Fiscalía y defensa',ic:'M10 2.5l6 2.5v4.5c0 3.8-2.6 6.4-6 8-3.4-1.6-6-4.2-6-8V5z'},
  notarial:{n:'Notarial y registral',ic:'M7 2.5h6v4l2 2v2H5v-2l2-2zM4 13h12v2.5H4zM6 17.5h8'},
  academia:{n:'Academia y gremio',ic:'M2 7l8-3.5L18 7l-8 3.5zM5.5 9v4.5c2.5 2 6.5 2 9 0V9M18 7v5'},
  gobierno:{n:'Gobierno y control',ic:'M2.5 7.5L10 3l7.5 4.5zM4.5 8.5v6M8 8.5v6M12 8.5v6M15.5 8.5v6M2.5 16.5h15'},
  penitenciario:{n:'Penitenciario',ic:'M4 3h12v14H4zM8 3v14M12 3v14'},
  historia:{n:'Historia legal',ic:'M5 3h9.5a2 2 0 0 1 0 4H14v8.5a2 2 0 0 1-2 2H4.5a2 2 0 0 1 0-4H6V5a2 2 0 0 1 2-2M8 8h4M8 11h4'},
  ciudad:{n:'Hitos de la ciudad',ic:'M10 2l2.3 4.9 5.2.6-3.9 3.6 1.1 5.2L10 13.7l-4.7 2.6 1.1-5.2L2.5 7.5l5.2-.6z'},
  // Monumentos Históricos (CMN) and Inmuebles de Conservación Histórica (PRC 2011); places of other categories that are
  // heritage list it in cs
  patrimonio:{n:'Patrimonio',ic:'M2.5 17.5h15M4 17.5V9.5a6 6 0 0 1 12 0v8M7.5 17.5v-7a2.5 2.5 0 0 1 5 0v7'}
};
const LEGAL=['tribunales','fiscalia','notarial','academia','gobierno','penitenciario','historia'];
const CITYCATS=['ciudad','patrimonio'];
const cssVar=n=>getComputedStyle(document.documentElement).getPropertyValue(n).trim();
const icon=c=>`<svg viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linejoin="round" stroke-linecap="round" aria-hidden="true"><path d="${CATS[c].ic}"/></svg>`;
const POIS=PD.pois; const BYID={}; POIS.forEach(p=>BYID[p.id]=p);
const enabled=new Set(Object.keys(CATS));

