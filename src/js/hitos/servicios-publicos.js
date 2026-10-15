  // ==== hito: servicios-publicos ====
  // Edificio de los Servicios Públicos (c. 1930, Monumento Histórico since 2008), across 1 Oriente from the plaza, built
  // on S in grid metres. Plan from OpenStreetMap: w214849867 plus the Tesorería's corner w191869528 (one building, one
  // façade on 1 Oriente), with the light wells cut into its north and south sides. Above the ground, from photos on
  // Wikimedia Commons (2012, 2022): Art Deco in greige concrete, a symmetric front on 1 Oriente of four floors with a
  // five-floor central block, pilasters in pairs rising above the parapet in steps, a dark plinth, a canopy over the
  // doors, and a covered atrium under a skylight (2024, interior). Approximate: the side and rear façades (no photos:
  // the front's window rhythm), the floor heights (~3.7 m), the skylight's size. It stands on the plaza's level
  // (MODELS[...].pad); its walls go 10 m down, as the Casa de la Independencia's lower pad tilts the ground to its
  // north-east. The Antigua Intendencia (w275506476) to its north is not modelled. Method: docs/METODOLOGIA.md §9.
  {const F=localFrame(0,0,Math.PI/2),H=MODELS['plaza-de-armas'].pad;
    const K={wall:C('#B9B3A5'),pil:C('#CBC6B9'),plinth:C('#6E6C66'),glass:C('#3B4653'),glass2:C('#2C3540'),door:C('#4A3F3A'),
      flat:C('#8F8A82'),sky:C('#A9B2B5'),canopy:C('#5B5A55')};
    const {box,WU,WV,rect}=facade(S,F,K);
    occMark([[72.4,-28.5],[113.7,-28.3],[113.7,28.1],[72.3,27.6]]);PADS.push([72.4,-28.5,113.7,28.1,H]);S.dy=H;
    const F4=[[2,3.8],[5.6,7.5],[9.3,11.2],[13,14.8]],F5=F4.concat([[16.7,18.5]]),bays=(w,s0,s1,fl,wd=1.5,step=3.4,skip)=>{
      const n=Math.max(1,Math.round((s1-s0)/step)),st=(s1-s0)/n;
      for(let k=0;k<n;k++){const s=s0+st*(k+.5);if(skip&&skip(s))continue;fl.forEach(([a,b],i)=>rect(w,s-wd/2,s+wd/2,a,b,i%2?K.glass2:K.glass));}};
    // masses: the front wing on 1 Oriente, the central block a floor higher, the rear round the atrium
    box(72.5,-28.4,84,27.5,-6,15.8,K.wall,K.flat);box(84,-23.8,100.5,23.5,-6,15.8,K.wall,K.flat);box(100.5,-28.2,113.6,28,-6,15.8,K.wall,K.flat);
    box(72.5,-8,86,8,-6,19.6,K.wall,K.flat);box(88,-9,104,9,15.8,17.3,K.glass2,K.sky);
    // the front: plinth, windows in bays, doors under a canopy, pilasters in pairs with stepped tops
    {const w=WU(72.5,-1),wp=WU(72.5,-1,.12);rect(w,-28.4,27.5,0.3,1.4,K.plinth);rect(wp,-28.4,-8,15.2,15.8,K.pil);rect(wp,8,27.5,15.2,15.8,K.pil);
      bays(w,-27.6,-9.2,F4);bays(w,9.2,26.7,F4);bays(w,-6.6,6.6,F5,2.2,4.4,s=>false);rect(WU(72.5,-1,.12),-3.4,3.4,0.3,4.3,K.door);
      box(70.7,-5,72.5,5,4.4,4.9,K.canopy,K.canopy);
      for(const s of [-8,-6.6,6.6,8])box(72.05,s-.35,72.5,s+.35,1.4,20.6,K.pil,K.pil),box(72.15,s-.2,72.5,s+.2,20.6,21.4,K.pil,K.pil);
      for(const s of [-27.9,-21.7,-15.5,-9.3,9.3,15.5,21.7,27])box(72.15,s-.3,72.5,s+.3,1.4,16.5,K.pil,K.pil),box(72.25,s-.15,72.5,s+.15,16.5,17,K.pil,K.pil);}
    // the other sides: plinth and windows in the front's rhythm
    for(const [w,s0,s1] of [[WV(27.5,1),72.5,84],[WV(23.5,1),84,100.5],[WV(28,1),100.5,113.6],[WV(-28.4,-1),72.5,84],
      [WV(-23.8,-1),84,100.5],[WV(-28.2,-1),100.5,113.6],[WU(113.6,1),-28.2,28]]){rect(w,s0,s1,0.3,1.4,K.plinth);bays(w,s0+.6,s1-.6,F4);}
    MODELS['servicios-publicos']={x:93,y:0,h:22};S.dy=0;}
