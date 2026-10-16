  // ==== hito: torre-talca ====
  // Torre Talca, 1 Sur 865: twelve floors of offices and flats (c. 1990, by the age in rental listings) in the middle
  // of the block of 1 Norte, 1 Sur, 1 and 2 Oriente, set back from both streets; built on S in grid metres. Plan from
  // OpenStreetMap w310246574: a south wing 16 m wide and a narrower north part, set back 2.6 m on the west. Above the
  // ground, from a photo on Wikimedia Commons taken from the west (Talca downtown, 2007: the tower behind the Catedral's
  // spire) and the Esri imagery: white walls; the south wing with a ribbon of windows on every floor, in panes between
  // white piers; the north part's west wall blank but for a column of small windows by the corner; grey loggias on the
  // north face; a red plant room on a red roof and a billboard frame along the east edge (the white strip on the
  // imagery, ~18 m long; the photo shows its back). Approximate: the height (12 floors as tagged and in the listings,
  // 4.2 m + 11 × 3 m, which the photo's floors against the Catedral's 39 m tower agree with), the east and south faces
  // (no photos: the south wing's ribbons), the loggias and the billboard's size. Its face is unknown: it carries the
  // name of Trifolia (office 63 of the tower; a place of its own, whose card says the sign is the model's licence),
  // stretched along the whole east edge, with MODELS['trifolia'] on it. On the plaza's level
  // (MODELS[...].pad), with walls 10 m deep. Method: docs/METODOLOGIA.md §9.
  {const F=localFrame(0,0,Math.PI/2),{V,N3}=F,H=MODELS['plaza-de-armas'].pad;
    const K={wall:C('#ECE7DC'),white:C('#F4F0E6'),glass:C('#3B4653'),glass2:C('#2C3540'),grey:C('#9C9E9B'),roof:C('#A35C42'),
      red:C('#B04A3C'),red2:C('#93402F'),frame:C('#B9B7B0'),board:C('#D8D6CE'),metal:C('#707070')};
    const {box,WL,WU,WV,rect}=facade(S,F,K),TOP=37.2;
    const fp=[[152.6,-25.8],[168.6,-25.8],[168.6,-13.2],[167.6,-13.2],[167.6,-5.2],[155.2,-5.2],[155.2,-16.2],[152.6,-16.2]];
    occMark(fp);PADS.push([152.6,-25.8,168.6,-5.2,H]);S.dy=H;
    // the walls round the whole outline under one roof (no coplanar lids), a white coping on top
    fp.forEach((a,i)=>{const b=fp[(i+1)%fp.length],L=Math.hypot(b[0]-a[0],b[1]-a[1]),out=[(b[1]-a[1])/L,-(b[0]-a[0])/L];
      S.face([V(a[0],a[1],-10),V(b[0],b[1],-10),V(b[0],b[1],TOP),V(a[0],a[1],TOP)],N3(out[0],out[1]),K.wall);
      rect(WL(a,b,out,.09),0,L,TOP-.6,TOP,K.white);});
    S.flat(fp,TOP,K.roof);
    // floors: a glazed ground floor under a white band, then eleven floors of 3 m (two tones by floor)
    const FL=[];for(let k=0;k<11;k++){const f=4.2+k*3;FL.push([f+1,f+2.3]);}
    // ribbons: n panes between 0.9 m white piers on every floor
    const panes=(w,s0,s1,n)=>{const p=(s1-s0-.9*(n+1))/n;FL.forEach(([a,b],i)=>{for(let j=0;j<n;j++){const s=s0+.9+j*(p+.9);rect(w,s,s+p,a,b,i%2?K.glass2:K.glass);}});};
    const faces=[[WU(152.6,-1),WU(152.6,-1,.09),-25.8,-16.2,3],[WV(-25.8,-1),WV(-25.8,-1,.09),152.6,168.6,5],
      [WU(168.6,1),WU(168.6,1,.09),-25.8,-13.2,4],[WU(167.6,1),WU(167.6,1,.09),-13.2,-5.2,3],[WV(-16.2,1),WV(-16.2,1,.09),152.6,155.2,1]];
    for(const [w,wb,s0,s1,n] of faces){panes(w,s0,s1,n);rect(w,s0+.4,s1-.4,.4,3.4,K.glass2);rect(wb,s0,s1,3.7,4.2,K.white);}
    // the north part's west wall: blank but for a column of small windows by the south corner
    {const w=WU(155.2,-1),wb=WU(155.2,-1,.09);FL.forEach(([a,b],i)=>rect(w,-15.4,-14.2,a+.2,b,i%2?K.glass2:K.glass));
      rect(w,-15.6,-6,.4,3.4,K.glass2);rect(wb,-16.2,-5.2,3.7,4.2,K.white);}
    // the north face: a grey loggia frame on every floor with two dark openings
    {const w=WV(-5.2,1),wd=WV(-5.2,1,.09);FL.forEach(([a,b])=>{rect(w,155.8,167,a-.6,b+.4,K.grey);rect(wd,156.4,161.2,a,b,K.glass2);rect(wd,161.6,166.4,a,b,K.glass2);});
      rect(w,155.8,167,.4,3.4,K.glass2);rect(WV(-5.2,1,.12),155.2,167.6,3.7,4.2,K.white);}
    // roof: the red plant room, and the billboard on two legs along the east edge (back to the city, face to the east)
    box(158,-16,163.5,-9,TOP,42.6,K.red,K.red2);
    for(const v of [-23.5,-15.5,-7.5])box(166.6,v-.25,167.1,v+.25,TOP,40,K.metal,K.metal);
    box(166.6,-25.5,167.1,-5.5,40,45,K.frame,K.metal);
    rect(WU(167.1,1),-25.2,-5.8,40.4,44.6,K.white);
    // the billboard's face, read from the east (s = v grows to the north, to the reader's right): TRIFOLIA in grey,
    // one rect per run of cells in a row. Cells of 0.7 × 0.75 m: the default view sees the face at 45°, and narrower
    // strokes fall under one art pixel (the logo's leaves did not fit beside the name)
    {const w=WU(167.1,1,.12),cu=.7,ch=.75,G=C('#58585A');
      const GL={T:['###','.#.','.#.','.#.','.#.'],R:['##.','#.#','##.','#.#','#.#'],I:['#','#','#','#','#'],F:['###','#..','##.','#..','#..'],
        O:['###','#.#','#.#','#.#','###'],L:['#..','#..','#..','#..','###'],A:['.#.','#.#','###','#.#','#.#']};
      let s=-25.2+(19.4-27*cu)/2;
      for(const c of 'TRIFOLIA'){GL[c].forEach((r,i)=>{for(let j=0;j<r.length;){if(r[j]==='.'){j++;continue;}let e=j;while(r[e+1]==='#')e++;
        rect(w,s+j*cu,s+(e+1)*cu,44.375-(i+1)*ch,44.375-i*ch,G);j=e+1;}});s+=(GL[c][0].length+1)*cu;}}
    MODELS['torre-talca']={x:160.6,y:-15.5,h:45};MODELS['trifolia']={x:166.9,y:-15.2,h:45};S.dy=0;}
