  // ==== hito: viejas-cochinas ====
  // Las Viejas Cochinas, the restaurant on the Río Claro's west bank across from the park (OSM node n3331425921, which
  // has no building). The plan is read from the Esri imagery beside the road: a long one-storey hall with a light zinc
  // gable roof, aligned with the road (frame at 72°, v along the hall), two small red-roofed wings on the yard side and
  // a gravel yard toward the river. Press (La Tercera, 2011, via De Buena Mesa): a cabin enlarged into a bungalow with
  // 54 tables and four wood fireplaces, moved back from the river after a flood in the late 1990s; hence the four
  // chimneys. There are no photos with a free licence: the walls, the windows and the chimneys' places are
  // approximate, and the model stays a plain block with the plan, height and roof of the imagery. On a pad, though it
  // is on the bank: its 40 m cell takes river nodes, and riversRelevel() puts them back. No lights.
  {const F=localFrame(-1696,788,72*Math.PI/180),{G,Gs,R}=F;
    const K={wall:C('#E3D9C4'),wall2:C('#D3CDC0'),tile:C('#C9CBC8'),tile2:C('#B3B6B3'),white:C('#ECE7DC'),gable:C('#E3D9C4'),
      door:C('#5A4636'),glass:C('#3B4653'),glass2:C('#2C3540'),brick:C('#8F4330'),gravel:C('#CDB98F')};
    const {box,WU,WV,rect,roof}=facade(S,F,K),red=facade(S,F,{...K,tile:C('#A35C42'),tile2:C('#8E4F3A'),gable:K.wall2});
    occMark(R(-5.8,-19.3,10.3,19.3));NOLOTS.push(R(-8,-26,30,16));
    // the pad (riversRelevel() puts the river's nodes back after it) and the gravel yard on it
    {const q=Gs([[-5.8,-19.3],[10.3,-19.3],[10.3,19.3],[-5.8,19.3]]),xs=q.map(p=>p[0]),ys=q.map(p=>p[1]);S.dy=padAt(Math.min(...xs),Math.min(...ys),Math.max(...xs),Math.max(...ys));}
    S.flat(R(10.3,-20,19,12),.3,K.gravel);occMark(R(10.3,-20,19,12));
    // the hall: walls stop 3 cm under the eaves, zinc roof in 4 m bays of two tones
    box(-5.5,-19,5.5,19,.3,3.17,K.wall,K.wall,false);roof('v',-19,19,-5.5,5.5,3.2,2.2,4);
    for(const [u,sg] of [[-5.5,-1],[5.5,1]]){const w=WU(u,sg,.06);
      for(let v=-17;v<=17;v+=4){if(sg>0&&((v>2&&v<12)||(v>-17&&v<-6)))continue;if(sg<0&&Math.abs(v)<2)continue;rect(w,v-.8,v+.8,1,2.2,K.glass);}}
    rect(WU(-5.5,-1,.06),-1.1,1.1,.3,2.5,K.door);
    for(const sg of [1,-1]){const w=WV(sg*19,sg,.06);rect(w,-3,-1.2,1,2.2,K.glass);rect(w,1.2,3,1,2.2,K.glass);}
    // the two wings on the yard side, red tile roofs whose ridges meet the hall
    for(const [v0,v1] of [[4,10],[-15,-8]]){box(5.5,v0,10,v1,.3,2.77,K.wall2,K.wall2,false);red.roof('u',5.5,10,v0,v1,2.8,1.4,2.25,[0,1]);
      rect(WU(10,1,.06),(v0+v1)/2-.6,(v0+v1)/2+.6,.3,2.3,K.door);}
    // four chimneys for the wood fireplaces on the road-side slope
    for(const v of [-14,-5,5,14]){box(-3.1,v-.5,-1.9,v+.5,3.6,6.4,K.brick,K.brick);box(-3.25,v-.65,-1.75,v+.65,6.4,6.6,K.white,K.white);}
    const m=G(2,0);MODELS['viejas-cochinas']={x:m[0],y:m[1],h:7};S.dy=0;}
