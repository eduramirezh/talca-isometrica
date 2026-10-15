  // ==== hito: estacion ====
  // Estación de Talca (1929, reinforced concrete; restored 2017), on the east side of 11 Oriente, with the Plaza
  // Estación in front; drawn on S. Plan from OpenStreetMap: station building w435220677 (a one-storey range with a
  // central pavilion toward the plaza and a small annex at its south end), the concrete train shed w435101367 along
  // its east side over the first platform and track, the long open platform w474659928 to the south. Frame from
  // landmark.py frame estacion 435220677: X=1498.8, Y=-217.0, A=89.3°, v along the building (north), u toward the
  // tracks (east). Elevations from photos on Wikimedia Commons: the front in 2017 and 2024 (white wings with grey
  // pilasters and wooden windows, a grey pavilion with three doors and a stepped attic, steps along the front), the
  // shed in 1929, 2004, 2014, 2017 and 2024 (concrete frames: an arcade on the sides, a big arch at each end, a
  // lantern along the ridge). Tracks (railBase draws them all): the main line is OSM's (DATA.rail, ~u 18-20: the
  // shed's track, between the open platform and the shed); two yard tracks east of it follow the OSM yard, simplified to
  // straight, approximate lengths (RAIL_YARD); the ramal a Constitución (DATA.ramal) starts at its buffer stop just south
  // of the building (OSM n4330545413, u 8.6, v -30) and runs down the open platform's west face, as in OSM: the ramal's
  // trains leave from that face and the main line's from the east one. Approximate: heights (from the photos'
  // proportions), the roofs' colours (Esri imagery), the annex.
  // The pavilion's wall lamps (seen in the photos) glow at night.
  {const F=localFrame(1498.8,-217,89.3*Math.PI/180),{G,Gs,V,N3,R}=F;
    const K={white:C('#ECE7DC'),grey:C('#A4A9AA'),grey2:C('#8E9394'),wood:C('#8A4A2E'),glass:C('#3B4653'),glass2:C('#2C3540'),
      tile:C('#9CA1A3'),tile2:C('#8D9294'),gable:C('#ECE7DC'),conc:C('#B9B4AA'),conc2:C('#CAC5BB'),void:C('#45423E'),
      sroof:C('#767A7C'),sroof2:C('#6A6E70'),pave:C('#CFC7B0'),step:C('#D9D3C5'),step2:C('#C6BFAF'),plat:C('#C8C2B4'),
      edge:C('#E2B33C'),ballast:PAL.ballast,rail:PAL.rail,buffer:C('#B4372C')};
    const {box,WL,WV,WU,rect,arch,roof}=facade(S,F,K);
    const shed=facade(S,F,{...K,tile:K.sroof,tile2:K.sroof2,gable:K.conc,white:K.conc2});
    const core=R(-14,-60,41,80);occMark(core);occMark(R(9,-252,22,-60));occMark(R(31,-130,41,120));
    const pad=padAt(Math.min(...core.map(p=>p[0])),Math.min(...core.map(p=>p[1])),Math.max(...core.map(p=>p[0])),Math.max(...core.map(p=>p[1])));S.dy=pad;
    // forecourt and steps along the front
    S.quadXY(R(-14,-25,-3.5,33),0.3,K.pave);
    for(let k=0;k<3;k++)box(-6+k*.8,-19,-2.4,33,0.3,0.5+k*.2,K.step2,k%2?K.step2:K.step);
    // the range: white walls on a grey plinth, grey pilasters, wooden windows, a white cornice, a grey iron roof
    const FL=0.9,EAV=5.5;box(-2.5,-19,11,33,0.3,EAV,K.white,K.white,false);box(-7,-25,11,-19,0.3,4.6,K.white,K.tile2);
    roof('v',-19.4,33.4,-2.5,11,EAV,2,6,[1,1]);
    const wing=(a,b,out)=>{const w=WL(a,b,out),wb=WL(a,b,out,.09),wp=WL(a,b,out,.12),n=Math.max(1,Math.round(w.L/4.4)),bw=w.L/n;
      rect(w,0,w.L,0.3,FL+.3,K.grey2);rect(wb,0,w.L,EAV-.5,EAV,K.white);
      for(let k=0;k<=n;k++)rect(wp,Math.max(0,k*bw-.35),Math.min(w.L,k*bw+.35),0.3,EAV-.5,K.grey);
      for(let k=0;k<n;k++){const c=(k+.5)*bw;rect(w,c-1.1,c+1.1,FL+.8,FL+3.4,K.wood);rect(wb,c-.8,c+.8,FL+1.1,FL+3.1,k%2?K.glass2:K.glass);}};
    wing([-2.5,-19],[-2.5,0],[-1,0]);wing([-2.5,14],[-2.5,33],[-1,0]);wing([-2.5,33],[11,33],[0,1]);wing([-7,-25],[11,-25],[0,-1]);wing([-7,-19],[-7,-25],[-1,0]);
    // central pavilion: grey, three tall doors under transoms, a white cornice and a stepped attic
    box(-3.5,0,6,14,0.3,7.6,K.grey,K.tile2);pyramid(S,R(-3.8,-.3,6.3,14.3),7.6,1.8,K.tile);
    {const w=WV(0,-1),wu=WU(-3.5,-1),wb=WU(-3.5,-1,.09),wp=WU(-3.5,-1,.12);rect(wu,0,14,0.3,FL+.3,K.grey2);rect(wb,0,14,7,7.6,K.white);
      for(const c of [2.4,7,11.6]){rect(wb,c-1.5,c+1.5,FL+.3,FL+5,K.white);rect(wp,c-1.2,c+1.2,FL+.3,FL+3.5,K.wood);rect(wp,c-1.2,c+1.2,FL+3.8,FL+4.7,K.glass);}
      for(const [hw,h0,h1] of [[5,7.6,8.3],[3.4,8.3,9],[1.8,9,9.7]]){box(-3.5,7-hw,-2.3,7+hw,h0,h1,K.grey,K.grey2);rect(WU(-3.5,-1,.09),7-hw,7+hw,h1-.3,h1,K.white);}
      for(const c of [2.4,7,11.6]){const g=G(-4.2,c);GLOW.push(g[0],S.dy+FL+5.4,g[1]);}}
    // the train shed: concrete frames every 6.2 m, an arcade on the free sides, a big arch at each end, an iron roof
    // with a lantern along the ridge
    const S0=-50,S1=74,SU0=11,SU1=30,SE=7.5;
    box(SU0,S0,SU1,S1,0.3,SE,K.conc,K.conc,false);shed.roof('v',S0,S1,SU0,SU1,SE,4,6.2,[1,1]);
    box(18.4,S0+.5,22.6,S1-.5,10,13.2,K.conc,K.sroof2);shed.roof('v',S0+.5,S1-.5,18.4,22.6,13.2,.8,6.2,[1,1]);
    {const n=20,bw=(S1-S0)/n;
      for(const [u,sg,ranges] of [[SU1,1,[[S0,S1]]],[SU0,-1,[[S0,-25],[33,S1]]]]){const w=WU(u,sg),wp=WU(u,sg,.12);
        for(let k=0;k<n;k++){const c=S0+(k+.5)*bw;if(!ranges.some(([a,b])=>c>a&&c<b))continue;arch(w,c,4.2,FL,6.2,K.void);}
        for(let k=0;k<=n;k++){const s=S0+k*bw;if(ranges.some(([a,b])=>s>=a-1&&s<=b+1))rect(wp,Math.max(S0,s-.4),Math.min(S1,s+.4),0.3,SE,K.conc2);}
        rect(WU(u,sg,.09),S0,S1,SE-.5,SE,K.conc2);}
      for(const [v,sg] of [[S0,-1],[S1,1]]){const w=WV(v,sg);arch(w,20.5,13,0.3,10.4,K.void);
        rect(WV(v,sg,.12),SU0,SU0+1.2,0.3,SE,K.conc2);rect(WV(v,sg,.12),SU1-1.2,SU1,0.3,SE,K.conc2);
        for(const u of [19.4,21.6])rect(WV(v+sg*.5,sg),u-.5,u+.5,10.6,12.6,K.glass);}
      for(const sg of [-1,1])for(let k=0;k<n;k++){const c=S0+(k+.5)*bw;rect(WU(sg<0?18.4:22.6,sg),c-1.6,c+1.6,10.8,12.6,k%2?K.glass2:K.glass);}}
    // tracks: the yard's two (broad gauge) go to railBase, which lays them on the final ground like the lines; the
    // open platform south of the shed with its yellow edge, in short pieces that follow the ground outside the pad;
    // buffer stops at the yard tracks' ends and at the ramal's
    const ES2=40,near=(v)=>v>-60-ES2&&v<80+ES2;
    const piece=(v0,v1,fn)=>{const vm=(v0+v1)/2,g=G(20,vm);S.dy=near(vm)?Math.max(pad,E(g[0],g[1])):E(g[0],g[1]);fn(v0,v1);S.dy=pad;};
    RAIL_YARD.push({pts:Gs([[33.5,-130],[33.5,120]]),g:1.676},{pts:Gs([[38.5,-110],[38.5,110]]),g:1.676});
    for(const [u,v,w] of [[33.5,-130.4,2.2],[33.5,120.4,2.2],[38.5,-110.4,2.2],[38.5,110.4,2.2],[8.6,-29.5,1.6]])piece(v,v,()=>box(u-w/2,v-.4,u+w/2,v+.4,0.3,1.4,K.buffer,K.white));
    for(let v=-242;v<S0-1e-6;v+=24){const e=Math.min(S0,v+24);piece(v,e,(a,b)=>{box(10,a,17.4,b,0.3,1.0,K.plat,K.plat);S.quadXY(R(17.4,a,18,b),1.0,K.edge);box(17.4,a,18,b,0.3,0.99,K.plat,K.plat,false);});}
    const c=G(10,8);MODELS.estacion={x:c[0],y:c[1],h:16};S.dy=0;}
