  // ==== hito: ucm-derecho ====
  // Universidad Católica del Maule, Campus San Miguel, on S. Every building is OpenStreetMap's (building=* ways and
  // multipolygons inside the campus w110778753), in one frame for the campus, from landmark.py frame ucm-derecho
  // 584278610 (the old cloister): v toward the campus's north side (NNE), u toward the athletics track. Heights from
  // building:levels where OSM has them (about 3.5 m a storey), otherwise read from the Esri imagery's shadows; roof
  // colours from the imagery. The imagery predates the Facultad de Ingeniería (w977018964) and Salas I (w1418118536),
  // drawn from OSM alone as plain blocks. Detail where the campus is recognisable: the one-storey cloister around the
  // Patio de las Palmeras and the Patio de los Naranjos (relation 8254810), its ranges under clay-tile gable roofs
  // over grey block walls with a red plinth (photos on Wikimedia Commons, Ucm 1.jpg 2005 public domain, Ucm 3.jpg
  // 2006 CC BY-SA 3.0); the two faculties by the north entrance under big hipped roofs; the Facultad de Ciencias
  // Sociales y Económicas, which teaches law (the marker goes there), with its blue roof strip and the domed rotunda
  // at its west end; the red roof of the Parque Tecnológico; the gym's ribbed roof; the athletics track. Approximate:
  // every height without building:levels, the cloister's split into ranges (traced from its outline), the rotunda's
  // size. Each building stands on its lowest corner (no pads: the campus slopes ~5 m in the model), and the lawns,
  // lots and track are draped on the terrain (the lawn just under the streets).
  {const F=localFrame(4106.6,-654.0,74.2*Math.PI/180),{G,Gs,V,N3,R}=F;
    const K={block:C('#B9B4A8'),block2:C('#ABA699'),plinth:C('#A9503B'),tile:C('#A35C42'),tile2:C('#8E4F3A'),wood:C('#6B5444'),
      white:C('#ECE7DC'),cream:C('#E6E1D3'),light:C('#E3E1DA'),grey:C('#C9C5BC'),glass:C('#4D5D66'),glass2:C('#3B4653'),dark:C('#2E2C2B'),
      roof:C('#C4BFB3'),roofW:C('#D8D6CE'),roofD:C('#5F6468'),roofB:C('#8A6A55'),metal:C('#9AA3A6'),metal2:C('#8C959A'),
      hall:C('#C3C9CB'),hall2:C('#AEB8BE'),red:C('#B5443A'),red2:C('#A23D34'),blue:C('#3E5C9A'),dome:C('#B8BDBF'),dome2:C('#A3A9AC'),
      beige:C('#D8CC9F'),atrium:C('#6F95B8'),green:C('#4F8A5E'),lawn:C('#8FA85A'),asph:C('#6E6A65'),track:C('#B9573B'),
      field:C('#6B9B45'),court:C('#4F7FA8')};
    const {box,WL,WV,WU,rect,roof}=facade(S,F,{...K,gable:K.wood}),roofM=facade(S,F,{...K,tile:K.hall,tile2:K.hall2,gable:K.grey}).roof;
    // walls of a counter-clockwise (u,v) ring, a white coping on top; slab adds the flat roof
    const walls=(ring,h0,h1,col,cop=K.white)=>{for(let i=0;i<ring.length;i++){const a=ring[i],b=ring[(i+1)%ring.length],L=Math.hypot(b[0]-a[0],b[1]-a[1]);
      if(L<.01)continue;const w=WL(a,b,[(b[1]-a[1])/L,-(b[0]-a[0])/L],0);
      S.face([w.q(0,h0),w.q(L,h0),w.q(L,h1-.5),w.q(0,h1-.5)],w.n,col);S.face([w.q(0,h1-.5),w.q(L,h1-.5),w.q(L,h1),w.q(0,h1)],w.n,cop);}};
    // a building on its lowest corner: walls, flat roof, storeys of windows (st) drawn as glazed bands
    const bld=(ring,h,wall,top,st=0,sh=3.5)=>{const q=Gs(ring);S.dy=groundMin(q);occMark(q);walls(ring,-2,h,wall);S.flat(q,h,top);
      for(let i=0;i<ring.length&&st;i++){const a=ring[i],b=ring[(i+1)%ring.length],L=Math.hypot(b[0]-a[0],b[1]-a[1]);if(L<4)continue;
        const w=WL(a,b,[(b[1]-a[1])/L,-(b[0]-a[0])/L]);for(let k=0;k<st;k++)rect(w,.9,L-.9,1.1+k*sh,2.5+k*sh,k%2?K.glass2:K.glass);}
      return S.dy;};
    // ground: the campus lawn between the blocks (0.10) and the streets (0.12 and up), so the campus roads still
    // show; above them the lots, the track and its infield, the tennis courts. Draped on the terrain: no pads here, so
    // E() is already the final terrain
    {const Lg=new GB(1<<12),lay=(ring,o,c)=>Lg.flat(Gs(ring),o,c);
      const CAMPUS=[[-78.5,-115.5],[59,-115.5],[59.5,-24],[93.5,-22],[166,-21.5],[236,-19],[252.5,-20],[244.5,-75],[241,-115],[395.5,-114.5],[397.5,240.5],[-77,233]];
      lay(CAMPUS,.11,K.lawn);NOLOTS.push(Gs(CAMPUS));lay([[59,-115.5],[241,-115],[244.5,-75],[252.5,-20],[236,-19],[166,-21.5],[93.5,-22],[59.5,-24]],.11,K.lawn);
      for(const r of [[[101.5,229],[99.5,217.5],[110.5,212.5],[135.5,213],[152.5,215.5],[222,213.5],[223,229]],[[23.5,215.5],[24,230],[-73.5,228],[-73.5,214.5]],
        [[-71,129.5],[-63,129.5],[-65,151],[-65,187],[-68.5,188],[-68.5,204.5],[-67,214.5],[-73.5,214.5]],[[-11,194],[-11,207],[-55,206],[-54.5,193]],
        [[371.5,224.5],[371.5,235],[246.5,234.5],[246.5,223.5]],[[-42,-70.5],[-9,-47],[-1.5,-43.5],[-2.5,-40.5],[-14,-34],[-43,-37]],
        [[231.5,-110],[257,-110],[256.5,-58.5],[243.5,-59]],[[85,95.5],[92,105],[91,157],[86.5,157],[84.5,152.5]],
        [[-78,94],[-78.5,-90],[-72,-90],[-71.5,1.5],[-63.5,2],[-63.5,56],[-61,58],[-61,82]]])lay(r,.155,K.asph);
      lay([[287,7.5],[290,-6],[296.5,-18],[306.5,-27.5],[319,-34],[332.5,-36.5],[346,-35.5],[358.5,-30],[369,-22],[377,-10.5],[381.5,2],[383.5,98.5],[379.5,111],[372,122.5],[361.5,131],[349,137],[336,138.5],[323,137],[311,132],[300.5,124],[293,113],[290.5,107]],.17,K.track);
      lay([[294.5,31],[294.5,9.5],[298,-2.5],[305,-13],[315,-21],[326.5,-25.5],[338.5,-26],[350.5,-23.5],[361,-17],[369,-8],[374,3],[376,97],[371.5,108.5],[363.5,118],[353.5,125],[341.5,128.5],[329.5,128.5],[318,125.5],[308,119],[300.5,110],[297.5,105]],.18,K.field);
      lay([[248,77.5],[249,113.5],[211,114.5],[210.5,80]],.17,K.white);lay([[247,78.5],[248,112.5],[212,113.5],[211.5,81]],.18,K.court);
      lay([[1.5,193],[2,158],[21.5,158.5],[21,193.5]],.17,K.track);
      const d=drape(Lg);S.dy=0;
      for(let t=0;t<d.ni;t+=3){const k=d.I[t]*3;S.face([0,1,2].map(j=>{const m=d.I[t+j]*3;return [d.P[m],d.P[m+1],d.P[m+2]];}),[0,1,0],[d.C[k],d.C[k+1],d.C[k+2]]);}}
    // the cloister: one-storey ranges under tile gable roofs (eaves 3.6 m), traced from the outline as rectangles
    // [u0, v0, u1, v1, ridge axis]; where two cross, the roofs simply intersect (ESTETICA §5)
    {const cl=Gs([[-64,-19],[-53,-19],[-53,-14],[-18,-13],[-18,-34],[-14,-34],[-14,-14],[6,-14],[6,-39],[16,-39],[16,-55],[19,-55],[19,-76],[2,-76],[2,-85],[43,-85],[43,-91],[52,-91],[52,14],[41,14],[41,28],[47,28],[47,62],[24,61],[24,54],[33,54],[33,37],[7,37],[7,30],[27,30],[27,16],[-13,16],[-13,7],[0,7],[0,-7],[-14,-7],[-14,53],[19,53],[19,58],[-50,58],[-50,53],[-17,53],[-17,-2],[-51,-2],[-51,56],[-64,56]]);
      S.dy=groundMin(cl);occMark(cl);
      for(const [u0,v0,u1,v1,ax] of [[2,-85,52,-76,'u'],[37,-91,52,14,'v'],[13,-44,37,-32,'u'],[16,-76,23,-44,'v'],[6,-39,12,2,'v'],[0,2,41,16,'u'],
        [-13,7,0,16,'u'],[-14,-14,6,-7,'u'],[27,16,41,28,'v'],[7,28,47,37,'u'],[33,37,47,62,'v'],[24,54,33,61,'u'],[-17,-2,-14,53,'v'],
        [-50,53,19,58,'u'],[-64,-19,-51,56,'v'],[-53,-14,-17,-2,'u'],[-18,-34,-14,-13,'v']]){
        const wd=ax==='u'?v1-v0:u1-u0,eave=wd<6?3:3.6;box(u0,v0,u1,v1,-2,eave,K.block,K.block,false);
        for(const w of [WV(v0,-1),WV(v1,1)])rect(w,u0,u1,-.3,.6,K.plinth);for(const w of [WU(u0,-1),WU(u1,1)])rect(w,v0,v1,-.3,.6,K.plinth);
        // small dark windows along the long sides, a door now and then
        const long=ax==='u'?[[WV(v0,-1,.09),u0,u1],[WV(v1,1,.09),u0,u1]]:[[WU(u0,-1,.09),v0,v1],[WU(u1,1,.09),v0,v1]];
        if(wd>=6)for(const [w,s0,s1] of long)for(let s=s0+2.5,k=0;s<s1-2;s+=4,k++)rect(w,s-.5,s+.5,k%5===2?.6:1.2,k%5===2?2.6:2.6,k%5===2?K.wood:K.glass2);
        roof(ax,ax==='u'?u0:v0,ax==='u'?u1:v1,ax==='u'?v0:u0,ax==='u'?v1:u1,eave,wd*.29,4);}}
    // north entrance: Ciencias Básicas (4 storeys) and Ciencias de la Salud, white blocks under big hipped roofs; the
    // Salud rotunda (w581439272)
    {bld([[27,170],[57,170],[56.5,181],[68,175.5],[67.5,220],[26.5,219.5]],14,K.light,K.roofW,4);pyramid(S,R(26,169.5,68.5,220.5),14,6,K.roofW);
      bld([[200,182.5],[207,188],[214.5,182.5],[214.5,179],[221.5,179],[222,213.5],[182.5,215],[182,207],[177,207],[177.5,215],[152.5,215.5],[151.5,181],[157.5,181],[157.5,170.5],[169.5,170],[170,180.5]],10.5,K.light,K.roofW,3);
      pyramid(S,R(181.5,178.5,222.5,215.5),10.5,6,K.roofW);
      bld([[196,182],[193.5,184],[192,187.5],[195.5,197.5],[185.5,202.5],[177,203.5],[176.5,180.5]],12,K.cream,K.dome,2);}
    // Aprendizaje Autónomo (dark roof), Edificio de Aulas (white and green roofs), library, the north-west halls
    bld([[69.5,178.5],[85,178],[89.5,182],[94.5,194.5],[109.5,194.5],[110.5,212.5],[99.5,217.5],[68,219]],11,K.grey,K.roofD,3);
    bld([[113.5,199],[114.5,173],[140.5,173.5],[140.5,183],[134.5,183],[135.5,213],[114.5,212.5]],11,K.light,K.roofW,3);S.quadXY(R(114.6,173.6,140.4,182.9),11.03,K.green);
    bld([[126.5,147.5],[116.5,144.5],[115.5,101],[122.5,100.5],[122.5,97.5],[132.5,97.5],[134,145.5]],8,K.light,K.roofW,2);S.quadXY(R(122,105,128,140),8.03,K.grey);
    bld([[-58.5,152.5],[-14,153],[-13.5,186],[-58.5,185]],7,K.grey,K.hall,0);roofM('u',-58.5,-14,152.5,186,7,2.2,6);
    bld([[-61,82],[-61,58],[-16.5,58],[-16.5,74],[-47,74],[-47,82]],6.5,K.grey,K.hall2,1,3);
    bld([[-37.5,82],[-37.5,125.5],[-67.5,125.5],[-67.5,94.5],[-61,94.5],[-61,82]],6.5,K.grey,K.hall,1,3);
    // gym: ribbed metal roof in bays of two tones
    {bld([[54.5,152],[54.5,133.5],[25.5,133],[26,95],[85,95.5],[84.5,152.5]],11,K.grey,K.metal,0);
      for(let u=26,k=0;u<84.5;u+=4.5,k++)S.quadXY(R(u,95.5,Math.min(84.5,u+4.5),u<54.5?133:152),11.03,k%2?K.metal2:K.metal);}
    // Educación: a long tile range; the smaller blocks around the cloister
    {bld([[3.5,153.5],[3.5,121],[0.5,120.5],[1.5,88],[4,88],[3.5,61.5],[14,61],[14.5,86.5],[20,87],[19.5,90.5],[15,90],[15,92.5],[12.5,92.5],[12,116],[16.5,116.5],[16,135],[20.5,135.5],[20.5,138.5],[15.5,139],[14.5,153.5]],4.5,K.block,K.tile,1);
      roof('v',61.5,153.5,2,14.5,4.5,2.6,4);}
    bld([[48,93],[47.5,61.5],[64,62],[63,93.5]],6,K.grey,K.roof,1);bld([[43.5,95],[43.5,91],[24,91],[24.5,80.5],[33.5,80],[33,61.5],[44.5,61.5],[45,85.5],[47.5,85.5],[48,95]],5,K.block,K.roofB,1);
    bld([[-14,30.5],[6,31],[7,29.5],[7.5,50.5],[-14,50.5]],6,K.light,K.roofW,1);bld([[79,77],[84.5,82],[85,90],[76.5,90],[71.5,86.5]],4,K.grey,K.roof,1);
    // Facultad de Ciencias Sociales y Económicas (law): three storeys, the blue roof strip along its west side, the
    // rotunda with a stepped silver dome at the west end
    {bld([[93.5,50],[90.5,50],[90.5,2],[70,2.5],[69.5,-9.5],[103,-9.5],[103.5,57],[93.5,57]],10.5,K.cream,K.roofW,3);
      S.quadXY(R(90.6,2.5,93.5,49.8),10.53,K.blue);S.quadXY(R(93.5,2.5,95.5,56.5),10.53,K.grey);
      const c=G(70,-3.5);[[5,0,11,K.cream],[5.4,11,11.6,K.white],[4.6,11.6,13,K.dome],[3.6,13,14.2,K.dome2],[2.2,14.2,15.2,K.dome],[.8,15.2,16.2,K.white]]
        .forEach(([r,h0,h1,col])=>S.prism(ngon(c[0],c[1],r,8,Math.PI/8),h0,h1,col,col));
      for(const [u,v] of [[97,57],[97,-9.5]])rect(WV(v,v>0?1:-1,.12),u-1.5,u+1.5,.3,3,K.glass2);
      const m=G(96,24);MODELS['ucm-derecho']={x:m[0],y:m[1],h:15};}
    // Parque Tecnológico: red hipped roof with a dark skylight
    bld([[115.5,54.5],[116,29.5],[159,30.5],[158.5,54],[143.5,53.5],[143.5,39.5],[128,39],[128,54.5]],11,K.light,K.red,3);
    pyramid(S,R(115,29,159.5,55),11,3.2,K.red);S.quadXY(R(131,38,144,46),11.03,K.red2);
    bld([[135,-16],[159.5,-16],[159.5,-7],[177,-7],[177,7],[135,6.5]],10.5,K.grey,K.roofD,3);
    bld([[116.5,-11.5],[128.5,-11.5],[128.5,11],[157,11],[157,20],[116.5,20]],7,K.cream,K.roofB,2);
    bld([[69.5,-21.5],[91,-21.5],[91,-16.5],[69.5,-16]],4,K.light,K.roofW,1);bld([[117.5,-56.5],[126,-56.5],[125.5,-31],[118,-31]],5,K.light,K.roof,1);
    bld([[143.5,77.5],[147,69.5],[164,78],[163,81],[183,90.5],[179.5,97.5],[158.5,87.5],[160,85]],4,K.light,K.roof,1);
    // the beige building by Av. San Miguel with its glazed atrium; Medicina and the finance offices in former houses
    bld([[76,-86],[84.5,-86],[84,-93],[116,-93.5],[116,-78.5],[122.5,-79],[122.5,-72.5],[128,-72.5],[128,-67],[121.5,-67],[121.5,-64],[115,-64],[115.5,-45],[109,-45],[109,-36.5],[100,-36.5],[99.5,-63.5],[89,-63],[89.5,-35.5],[73,-35],[72.5,-67.5],[76,-67.5],[76,-73.5],[79,-73.5],[79,-75.5],[76,-75.5]],8,K.cream,K.beige,2);
    pyramid(S,R(90,-80,106,-66),8,3,K.atrium);
    bld([[210.5,-58.5],[206,-59.5],[206,-82],[202.5,-82],[202.5,-101],[231.5,-101],[231.5,-90.5],[234.5,-90.5],[234.5,-82.5],[229.5,-82.5],[229.5,-62.5],[222,-62.5],[222,-48],[210.5,-47.5]],6.5,K.cream,K.roofB,2,3);
    bld([[134.5,-78.5],[136.5,-78.5],[136.5,-95.5],[148.5,-95.5],[148.5,-80],[154.5,-80],[154.5,-69.5],[146,-69.5],[146,-60],[134.5,-60]],4.5,K.cream,K.roofB,1);
    bld([[167.5,-89.5],[167.5,-98.5],[175,-98],[174.5,-73],[155.5,-73.5],[156,-90]],4.5,K.cream,K.roofB,1);
    // new east side: Ingeniería (4 storeys), Salas I, the architecture classrooms
    bld([[242,210.5],[229,210],[229,200.5],[244,201],[244,193],[373,194.5],[371.5,201],[367.5,206],[361,210],[354,210.5],[353.5,214],[242,212.5]],14,K.light,K.roof,4);
    bld([[272,-93.5],[364.5,-91.5],[364.5,-72.5],[369.5,-72.5],[369.5,-66.5],[365,-65.5],[364.5,-46.5],[271.5,-48]],4.5,K.light,K.roofW,1);
    for(const r of [[[238.5,146.5],[257,156.5],[253,163.5],[234.5,154]],[[209.5,141.5],[220.5,146.5],[217.5,153.5],[206,148.5]],[[227.5,142.5],[233.5,145.5],[228,157.5],[221.5,154.5]]])bld(r,3.5,K.grey,K.roofD,0);
    S.dy=0;}
