  // ==== hito: cementerio ====
  // Cementerio General de Talca, on S. The ground is OpenStreetMap's cemetery w86933822 (the same polygon the land-use
  // layer draws generically: the use is skipped because this footprint is reserved in occ). Drawn in one frame, v along
  // the cemetery's long axis (NNE, 75.3°) and u across, origin at its middle (landmark.py frame cementerio 86933822
  // --origin -4 2120 --angle 75.3), the layout traced on the Esri imagery rotated into that frame (satellite.py marco):
  // the south wing at the entrance on Avenida 12 Norte (an octagonal pavilion, the chapel, a dome, three long galleries
  // of niches and rows of gabled mausoleums among cypresses and big trees), the cross wall at v = -107, the dense field
  // of graves behind it with its cross avenues, the wall at v = 59, the rows of niche walls beyond (the new patios, with
  // a building yard) and the big empty field at the north end with a few sheds. The entrance portico (five arches, yellow
  // stucco on a white plinth, a taller central block) and the yellow perimeter wall follow the photo File:TalcaCementerio
  // General.jpg (Wikimedia Commons, 2006, public domain). The Memorial de Detenidos Desaparecidos y Ejecutados (OSM
  // w925249831, the 21 m square the plaza fills): a round plaza with a stone wall and steps, a ring of red pillars and
  // the four tall columns with copper plaques in the middle, from the photos by StefiValenzuela (Commons, 2019-09-25,
  // CC BY-SA 4.0: Frontis, Memorial, Plazoleta, Estructuras de piedra… en Memorial de Detenidos Desaparecidos y Ejecutados
  // de Talca). The big white vault at u 72..80, v -156..-144 takes the look of the Regimiento de Infantería 16's mausoleum of 1903 (pyramid tower with a cross, a door between two columns; File:Mausoleo Regimiento de Infanteria.jpg, Commons 2019, CC BY-SA 4.0, Gonzalo Orellana Hidalgo); where the real one stands is unknown. Approximate: every grave (a field of identical rows, not the real tombs: ~2 m × 1 m, in two heights and a few
  // gabled vaults), the number and place of the mausoleums and trees (read from the imagery), the heights (no dated photo
  // of the interior), the roofs' colours, the pavilion and the dome (only seen from above), the yard's sheds and the
  // rubble. No lights: nothing says the cemetery is lit.
  // wallPath(pts, closed, h, w, wall, cap, gaps): a wall of thickness w along the grid points pts, on the left of its
  // direction, h high with a cap 0.3 m wider and 0.3 m taller, in pieces of ≤8 m on their lowest corner; gaps [x, y, r]
  // leave an opening r each side of the point. wallRing(ring, …) closes a ring with its wall on the inside (also used by
  // the regiment).
  const wallPath=(pts,closed,h,w,wall,cap,gaps=[],sg=1)=>{
    for(let i=0;i<pts.length-(closed?0:1);i++){const a=pts[i],b=pts[(i+1)%pts.length],L=Math.hypot(b[0]-a[0],b[1]-a[1]);if(L<.5)continue;
      const tx=(b[0]-a[0])/L,ty=(b[1]-a[1])/L,nx=-ty*sg,ny=tx*sg,cuts=[];
      for(const [gx,gy,gr] of gaps){const t=(gx-a[0])*tx+(gy-a[1])*ty,d=Math.abs((gx-a[0])*nx+(gy-a[1])*ny);if(d<gr+w&&t>-gr&&t<L+gr)cuts.push([t-gr,t+gr]);}
      cuts.sort((p,q)=>p[0]-q[0]);
      const P=(s,o)=>[a[0]+tx*s+nx*o,a[1]+ty*s+ny*o],run=(s,e)=>{if(e-s<.4)return;const n=Math.ceil((e-s)/8);
        for(let k=0;k<n;k++){const s0=s+(e-s)*k/n,s1=s+(e-s)*(k+1)/n,q=[P(s0,0),P(s1,0),P(s1,w),P(s0,w)];S.dy=groundMin(q);
          S.prism(q,.3,h,wall,wall,false);S.prism([P(s0,-.15),P(s1,-.15),P(s1,w+.15),P(s0,w+.15)],h,h+.3,cap,cap);}};
      let t=0;for(const [c0,c1] of cuts){if(c0>t)run(t,c0);t=Math.max(t,c1);}if(t<L)run(t,L);}
    S.dy=0;};
  const wallRing=(ring,h,w,wall,cap,gaps)=>{let A=0;for(let i=0;i<ring.length;i++){const p=ring[i],q=ring[(i+1)%ring.length];A+=p[0]*q[1]-q[0]*p[1];}wallPath(ring,true,h,w,wall,cap,gaps,A>0?1:-1);};
  // occFill(ring, margin): marks the ring's cells in occ, leaving margin m free along the map's streets (the land-use
  // layer's rule: the sidewalks, street trees and parked cars stay)
  const occFill=(ring,m)=>{let y0=1e9,y1=-1e9;for(const p of ring){y0=Math.min(y0,p[1]);y1=Math.max(y1,p[1]);}
    for(let gy=Math.max(0,Math.floor((y0-YMIN)/OC));gy<=Math.min(ocH-1,Math.floor((y1-YMIN)/OC));gy++){const cy=YMIN+(gy+.5)*OC,xs=pipRow(ring,cy,[]);
      for(let i=0;i+1<xs.length;i+=2)for(let gx=Math.max(0,Math.ceil((xs[i]-XMIN)/OC-.5));gx<=Math.min(ocW-1,Math.floor((xs[i+1]-XMIN)/OC-.5));gx++){
        if(occ.get(gx,gy)===1)continue;if(!nearStreet(XMIN+(gx+.5)*OC,cy,m))occ.set(gx,gy,1);}}};
  {const F=localFrame(-4,2120,75.3*Math.PI/180),{G,Gs,V,N3,R}=F;
    const K={soil:C('#BBA680'),field:C('#B39A74'),path:C('#DCD0B4'),wall:C('#DDC768'),wall2:C('#C9B25A'),white:C('#ECE7DC'),white2:C('#D3CDC0'),plinth:C('#C9C3B6'),
      grave:['#E8E4DA','#D3CFC5','#BDB8AE','#CFC2B2','#A8A49C'].map(C),niche:C('#D4CFC3'),niche2:C('#BFBAAE'),tile:C('#7E5240'),tile2:C('#6C4636'),
      zinc:C('#B5B8B5'),zinc2:C('#A3A7A5'),dark:C('#2C3540'),glass:C('#3B4653'),glass2:C('#2C3540'),cu:C('#3F6B5A'),cu2:C('#4D7C68'),
      red:C('#A8453D'),red2:C('#92382F'),stone:C('#D4BC94'),stone2:C('#C2A87F'),pink:C('#C99C8E'),copper:C('#6B4A3A'),brick:C('#D9BC74'),
      rubble:C('#9E9484'),scrub:C('#8A8456'),dirt:C('#A98D66')};
    K.gable=K.white2;
    const {box,WL,WV,rect,arch,roof}=facade(S,F,K);
    const RING=[-126.4,164.5,-96.6,192.1,-82.0,206.9,-54.4,240.2,-38.4,257.1,-4.8,257.4,101.0,260.6,99.8,200.8,99.5,150.4,99.3,133.2,93.0,125.5,92.9,103.9,99.1,98.5,99.2,50.1,98.3,-3.0,94.4,-3.2,94.8,-42.7,95.1,-80.9,94.6,-124.1,97.1,-163.0,97.4,-241.1,-11.9,-238.7,-12.2,-242.5,-33.1,-242.3,-33.2,-239.7,-130.6,-238.3,-129.4,-211.5,-125.8,-211.3,-125.1,-108.4,-125.2,-21.5,-125.1,26.3,-125.3,59.7,-126.3,135.1];
    const UV=[];for(let i=0;i<RING.length;i+=2)UV.push([RING[i],RING[i+1]]);const GR=Gs(UV);
    const inR=(u,v)=>pip([u,v],UV);
    occFill(GR,2.5);
    // the map's own tracks inside the walls (class 7, the cicloconecta graph: ~3 m off the paths seen on the imagery) are
    // drawn here as paths, not as asphalt (s.bridge: a street a landmark draws)
    streets.forEach(s=>{if(s.c===7&&s.pts.filter(p=>pip(p,GR)).length*2>=s.pts.length)s.bridge=true;});
    // ---- obstacles for the graves: [u0, v0, u1, v1]; free(): a rectangle inside the ring and off every obstacle
    const OB=[],ob=(u0,v0,u1,v1,m=0)=>{OB.push([u0-m,v0-m,u1+m,v1+m]);};
    const free=(u0,v0,u1,v1)=>inR(u0,v0)&&inR(u1,v0)&&inR(u1,v1)&&inR(u0,v1)&&!OB.some(o=>u0<o[2]&&u1>o[0]&&v0<o[3]&&v1>o[1]);
    const rr=rng(8611);
    // ---- the ground: soil under all (0.11), the empty field (0.12), the paths (0.13); draped on the terrain (no pad)
    // main avenue, cross avenues and the paths along the walls (u, v): the map's own tracks lie on them (class 7)
    const PATHS=[[[29.5,-241],[29.5,58]],[[29.5,60],[32,96],[40,103],[52,110],[63,111],[99,117]],[[-116,-206],[-116,-110],[93,-109]],[[-122,-141],[94,-141]],[[-122,-190],[94,-190]],
      [[-122,-11],[94,-9]],[[-112,55],[29,54]],[[-64,-106],[-64,58]],[[-20,-106],[-20,58]],[[62,-106],[62,58]],[[61,85],[93,85]],[[-60,100],[-60,200]]];
    const PW=[7,5,3,3,3,3.4,3,2.5,2.5,2.5,3,3];
    {const Lg=new GB(1<<15),lay=(q,o,c)=>{if(q.length>2)Lg.flat(q,o,c);};
      lay(GR,.11,K.soil);
      lay(Gs([[-58,98],[-26,100],[98,98],[98,258],[-4,257],[-38,257],[-54,240],[-82,207],[-96,192],[-110,178],[-110,98]]),.12,K.field);
      for(let i=0;i<PATHS.length;i++)ribbon(Lg,PATHS[i].map(p=>G(p[0],p[1])),PW[i],.13,K.path);
      // the memorial plaza: a stone ring and yellow brick inside
      const mc=[46.9,87.6];lay(Gs(ngon(mc[0],mc[1],10.4,24)),.13,K.stone2);lay(Gs(ngon(mc[0],mc[1],9.2,24)),.14,K.brick);
      const d=drape(Lg);S.dy=0;
      for(let t=0;t<d.ni;t+=3){const k=d.I[t]*3;S.face([0,1,2].map(j=>{const m=d.I[t+j]*3;return [d.P[m],d.P[m+1],d.P[m+2]];}),[0,1,0],[d.C[k],d.C[k+1],d.C[k+2]]);}}
    for(let i=0;i<PATHS.length;i++){const p=PATHS[i],w=PW[i]/2+.4;for(let j=0;j<p.length-1;j++){const a=p[j],b=p[j+1];ob(Math.min(a[0],b[0])-w,Math.min(a[1],b[1])-w,Math.max(a[0],b[0])+w,Math.max(a[1],b[1])+w);}}
    // ---- walls: the yellow perimeter (2.6 m; openings at the entrance portico and the east gate), the white cross walls
    wallRing(GR,2.6,.6,K.wall,K.white,[[...G(-22.6,-242),11.6],[...G(99,116),3.5]]);
    for(const v of [-107,59])wallPath(Gs([[-124.5,v],[94.5,v]]),false,2.3,.5,K.white2,K.white,[[...G(29.5,v),3.5],[...G(-64,v),1.8],[...G(-20,v),1.8],[...G(62,v),1.8]],-1);
    ob(-125,-108.2,95,-105.8);ob(-125,57.8,95,60.2);
    // east gate: two white piers
    for(const o of [-3.6,3.6]){const q=Gs([[96.8,116+o-.5],[100.4,116+o-.5],[100.4,116+o+.5],[96.8,116+o+.5]]);S.dy=groundMin(q);S.prism(q,.3,3.4,K.white,K.white);}
    S.dy=0;
    // ---- the entrance: a five-arch portico (u -33..-12, v -242.3..-231), the facade of the photo
    {const u0=-33,u1=-12,v0=-242.2,v1=-231,h=5.3,w=WV(v0,-1,.06),w2=WV(v0,-1,.1),w3=WV(v0,-1,.13);const q=R(u0,v0,u1,v1);S.dy=groundMin(q);
      box(u0,v0,u1,v1,.3,h,K.wall,K.wall,false);box(u0-.25,v0-.25,u1+.25,v1+.25,h,h+.35,K.white,K.white);box(-27,v0+1,-18,v1-1,h+.35,h+1.6,K.wall,K.white);
      rect(w,u0,u1,.3,1.0,K.plinth);
      for(let k=0;k<5;k++){const c=u0+2.6+k*4.2;arch(w2,c,3,.9,4.4,k===2?K.glass2:K.glass);}
      for(let k=0;k<=5;k++){const c=u0+.5+k*4.2;rect(w3,c-.45,c+.45,.3,h,K.white);}
      rect(w3,u0,u1,h-.7,h-.3,K.white);
      occMark(q);ob(u0-1,v0-1,u1+1,v1+1);}
    // a lower wing on the west of the portico, with its flat roof
    {const q=R(-47,-241,-33.2,-230);S.dy=groundMin(q);S.prism(q,.3,4.2,K.wall,K.zinc2);S.prism(R(-47.2,-241.2,-33,-229.8),4.2,4.5,K.white,K.white);ob(-48,-242,-33,-229);}
    // an octagonal pavilion (a radial roof seen from above) just inside the portico
    {const c=G(-17.5,-226),o=ngon(c[0],c[1],4.4,8);S.dy=groundMin(o);S.prism(o,.3,3.6,K.white,K.white,false);S.prism(ngon(c[0],c[1],4.8,8),3.6,3.9,K.white,K.white);pyramid(S,ngon(c[0],c[1],4.8,8),3.9,2.4,K.zinc);ob(-23,-232,-12,-220);}
    // the chapel: a hall with a tiled gable roof (u -5..24, v -226..-212) and its entrance towards the avenue
    {const q=R(-5,-226,24,-212);S.dy=groundMin(q);box(-5,-226,24,-212,.3,4.6,K.white,K.white,false);roof('u',-5,24,-226,-212,4.6,2.6,5);
      rect(WV(-226,-1,.06),5,15,.3,3.6,K.glass2);ob(-6,-227,25,-211);S.dy=0;}
    // the dome of a family mausoleum
    {const c=G(37.5,-220.5),o=ngon(c[0],c[1],4,8);S.dy=groundMin(o);S.prism(o,.3,4.2,K.white2,K.white2,false);S.prism(ngon(c[0],c[1],4.3,8),4.2,4.5,K.white,K.white);pyramid(S,ngon(c[0],c[1],4.3,8),4.5,3.2,K.cu);ob(32,-226,43,-215);}
    // three long galleries of niches along the west wall: low gabled buildings, ridge along u
    for(const [a,b,c,d] of [[-120,-221,-68,-213],[-122,-229.5,-70,-222],[-120,-237,-68,-230.5]]){const q=R(a,b,c,d);S.dy=groundMin(q);S.gable(q,.3,3.4,1.5,K.white2,K.tile);
      for(let s=a+3;s<c-1;s+=4)rect(WV(b,-1,.06),s,s+1.6,.5,2.8,K.glass2);ob(a-1,b-1,c+1,d+1);}
    // mausoleums with gabled roofs, ridge along v: two rows in the west, a row in the east
    const maus=(u0,v0,u1,v1,wall,col)=>{const q=Gs([[u0,v0],[u0,v1],[u1,v1],[u1,v0]]);S.dy=groundMin(q);S.gable(q,.3,3.4,(u1-u0)*.28,wall,col);ob(u0-.6,v0-.6,u1+.6,v1+.6);};
    for(const [u0,u1] of [[-110,-104],[-102.5,-96.5],[-95,-89],[-86,-80],[-71,-65]])maus(u0,-136,u1,-119,K.white2,K.tile);
    for(const [u0,u1] of [[-111,-105],[-102.5,-96.5],[-89,-81],[-79,-71],[-70,-62]])maus(u0,-160,u1,-143,K.white2,K.tile2);
    for(const [u0,u1] of [[65,72],[74,81],[82,88],[90,95.5]])maus(u0,-136,u1,-115,K.white2,K.tile);
    {const q=R(36,-157,50,-144);S.dy=groundMin(q);S.gable(q,.3,3.4,1.6,K.white2,K.tile2);ob(35,-158,51,-143);}
    // a white mausoleum with a pyramid-roofed tower, a cross and a door between two columns, as the Regimiento de Infantería 16's
    // of 1903 in the cemetery (File:Mausoleo Regimiento de Infanteria.jpg, Commons 2019, CC BY-SA 4.0, Gonzalo Orellana Hidalgo);
    // where that one stands is unknown: it takes the place of the big white vault seen on the imagery
    {const q=R(72,-156,80,-144);S.dy=groundMin(q);S.prism(q,.3,4.2,K.white,K.white);box(72.4,-156,79.6,-144.4,4.2,4.5,K.white2,K.white);
      box(73.6,-150,78.4,-145.2,4.5,6.4,K.white,K.white,false);pyramid(S,R(73.3,-150.3,78.7,-144.9),6.4,2.4,K.white2);
      box(75.7,-147.9,76.3,-147.3,8.8,10.8,K.white,K.white);box(75.1,-147.9,76.9,-147.3,9.7,10.3,K.white,K.white);
      const w=WV(-144,1,.06);rect(w,75,77,.3,3.2,K.dark);for(const c of [74.4,77.6])box(c-.35,-143.9,c+.35,-143.2,.3,3.4,K.white,K.white);ob(71,-157,81,-142);}
    // the dense field's frame: rows of graves along u. A run of up to five graves is one prism, each with its own top
    const tomb=(u0,v0,u1,v1,seed,pv,dens)=>{const r=rng(seed),pu=1.5,tw=1.1,tl=2.3;let row=0;
      for(let v=v0;v+tl<=v1;v+=pv,row++){const h=row%2?.6:.85;let run=[],u=u0;
        const flush=()=>{if(!run.length)return;const a=run[0],b=run[run.length-1]+tw,base=K.grave[row%2],q=R(a,v,b,v+tl);S.dy=groundMin(q);S.prism(q,.3,.3+h,shade(base,.8),base,false);
          for(const x of run){const col=r()<.14?K.grave[4]:r()<.5?K.grave[0]:K.grave[1];S.face(R(x,v,x+tw,v+tl).map(p=>[p[0],.3+h,-p[1]]),[0,1,0],col);}run=[];};
        for(;u+tw<=u1;u+=pu){if(r()>dens||!free(u,v,u+tw,v+tl)){flush();continue;}
          if(r()<.045&&free(u-.3,v-.3,u+2.3,v+3)){flush();const q=R(u,v,u+2.1,v+2.6);S.dy=groundMin(q);S.gable(q,.3,2.3,.9,r()<.5?K.stone:K.white,r()<.5?K.tile:K.tile2);ob(u-.3,v-.3,u+2.4,v+2.9);u+=1.5;continue;}
          run.push(u);if(run.length>=3+Math.floor(r()*3))flush();}
        flush();}S.dy=0;};
    // niche walls: four tiers (3.2 m), the long faces in two alternating tones by tier, a white coping on top
    const niche=(u0,v0,u1,v1)=>{const n=Math.max(1,Math.ceil((u1-u0)/14));ob(u0-1,v0-1,u1+1,v1+1); // pieces of ≤14 m, each on its own ground
      for(let k=0;k<n;k++){const a=u0+(u1-u0)*k/n,b=u0+(u1-u0)*(k+1)/n,q=R(a,v0,b,v1);S.dy=groundMin(q);S.prism(q,.3,3.2,K.niche,K.niche2,false);
        for(const [v,sg] of [[v0,-1],[v1,1]]){const w=WV(v,sg,.05);for(let t=0;t<4;t+=2)rect(w,a,b,.3+t*.8,.3+t*.8+.8,K.niche2);}
        S.prism(R(a-(k?0:.15),v0-.15,b+(k<n-1?0:.15),v1+.15),3.2,3.5,K.white,K.white);}};
    // new patios north of the wall at v = 59: four blocks of six niche walls, and two rows south of the memorial
    for(const [a,b] of [[-60,-44],[-41,-24],[-15,1.5],[5,24]])for(let v=68.5;v<98;v+=5.5)niche(a,v,b,v+1.9);
    for(const v of [64.5,67.5])niche(32,v,61,v+1.9);
    // the north-west field of niche walls: 23 rows, the upper ones following the diagonal wall
    for(let v=90,k=0;v<204;v+=4.5,k++){const a=v<160?-109:-100+Math.min(30,(v-160)*1.1),b=-66;if(b-a>8)niche(a,v,b,v+1.9);}
    // east: three columns of niches along v
    for(const u of [80.5,83.5,86.5])niche(u,29,u+1.9,49);
    // ---- the memorial: round plaza r 10.4 (the stone ring wall 1.4 m, steps and an opening on the south side),
    // a ring of red pillars, the four columns with copper plaques in the middle
    {const mc=[46.9,87.6],ring=ngon(mc[0],mc[1],9.8,24);
      for(let i=0;i<24;i++){const a=ring[i],b=ring[(i+1)%24],ang=Math.atan2(a[1]-mc[1],a[0]-mc[0]);if(Math.abs(ang+Math.PI/2)<.34)continue; // the south opening
        const m=[(a[0]+b[0])/2,(a[1]+b[1])/2],l=Math.hypot(b[0]-a[0],b[1]-a[1]),dx=(m[0]-mc[0])/9.8,dy=(m[1]-mc[1])/9.8;
        const q=[[a[0],a[1]],[b[0],b[1]],[b[0]-dx*.9,b[1]-dy*.9],[a[0]-dx*.9,a[1]-dy*.9]].map(p=>G(p[0],p[1]));S.dy=groundMin(q);S.prism(q,.3,1.7,K.stone,K.stone2);}
      for(let k=0;k<3;k++){const q=Gs([[mc[0]-2.8,mc[1]-10.6-k*.7+.7],[mc[0]+2.8,mc[1]-10.6-k*.7+.7],[mc[0]+2.8,mc[1]-10.6-k*.7],[mc[0]-2.8,mc[1]-10.6-k*.7]]);S.dy=groundMin(q);S.prism(q,.3,.3+.25*(3-k),K.stone2,K.stone);}
      for(let i=0;i<14;i++){const a=i/14*Math.PI*2+.2;if(Math.abs(a-1.5*Math.PI)<.5||Math.abs(a+.5*Math.PI)<.5)continue;
        const p=[mc[0]+Math.cos(a)*7.4,mc[1]+Math.sin(a)*7.4],q=Gs([[p[0]-.45,p[1]-.45],[p[0]+.45,p[1]-.45],[p[0]+.45,p[1]+.45],[p[0]-.45,p[1]+.45]]);
        S.dy=groundMin(q);S.prism(q,.3,i%3?4.4:3.8,K.red2,K.red);}
      const cs=Gs(ngon(mc[0],mc[1],3.4,8));S.dy=groundMin(cs);S.prism(cs,.3,1.1,K.stone,K.stone2);
      for(const [du,dv] of [[-.95,-.95],[.95,-.95],[-.95,.95],[.95,.95]]){const c=[mc[0]+du,mc[1]+dv],q=Gs([[c[0]-.7,c[1]-.7],[c[0]+.7,c[1]-.7],[c[0]+.7,c[1]+.7],[c[0]-.7,c[1]+.7]]);S.dy=groundMin(q);
        S.prism(q,1.1,6.6,K.pink,K.pink);const w=(sg,hz)=>hz?WL([c[0]-.7,c[1]+sg*.7],[c[0]+.7,c[1]+sg*.7],[0,sg],.06):WL([c[0]+sg*.7,c[1]-.7],[c[0]+sg*.7,c[1]+.7],[sg,0],.06);
        for(const sg of [-1,1])for(const hz of [0,1]){const ww=w(sg,hz);rect(ww,.15,1.25,1.8,5.2,K.copper);rect(ww,.15,1.25,5.5,6.3,K.copper);}}
      occMark(Gs(ngon(mc[0],mc[1],11,16)));ob(mc[0]-12,mc[1]-12.5,mc[0]+12,mc[1]+12);S.dy=0;}
    // ---- the yard of the new patios, a building pit and the north end: sheds, a wall lot, rubble
    {const shed=(a,b,c,d,wall,col,h=3.2)=>{const q=R(a,b,c,d);S.dy=groundMin(q);S.gable(q,.3,h,Math.min(1.6,(d-b)*.25),wall,col);ob(a-1,b-1,c+1,d+1);};
      shed(90,160,101,182,K.white,K.zinc,4.2);shed(77,132,99,142,K.white2,K.zinc2);shed(77,144,99,152,K.white2,K.zinc2);
      shed(-24,106,-14,114,K.white,K.zinc);shed(-8,112,14,120,K.white2,K.zinc2);shed(-12,121,2,127,K.white,K.zinc);shed(16,111,22,125,K.white2,K.zinc);
      shed(-103,60.5,-97,65,K.white,K.zinc);
      // heaps of rubble in the yard
      const r=rng(77);for(let i=0;i<26;i++){const u=-20+r()*50,v=104+r()*34,s=1.2+r()*2.4;if(u<-26||!inR(u,v)||!free(u-s,v-s,u+s,v+s))continue;const q=R(u-s,v-s*.8,u+s,v+s*.8);S.dy=groundMin(q);S.prism(q,.3,.3+s*.45,K.rubble,K.rubble);}
      // the walled lot at the north-west of the field
      wallPath(Gs([[-57,230],[-25,230],[-25,255],[-57,255]]),true,2.2,.5,K.white2,K.white,[],1);
      {const q=R(-56,231,-26,254);S.dy=groundMin(q);}ob(-58,229,-24,256);
      for(const p of [[-50,238],[-44,246],[-36,241],[-32,250],[-52,250]]){const q=R(p[0]-1.4,p[1]-1.4,p[0]+1.4,p[1]+1.4);S.dy=groundMin(q);S.prism(q,.3,1.3,K.scrub,K.scrub);}
      S.dy=0;}
    // ---- the graves, once every building, niche wall and path is in OB
    tomb(-124,-106,94,58,401,3,.96);                 // the dense field
    tomb(-124,-237,96,-109,402,3,.66);                // the south wing, among its buildings
    // ---- trees: masses of big round ones among the graves, cypresses (columnar, the poplars' model) along the avenue
    {const t=(u,v,s)=>{const p=G(u,v);if(inR(u,v)&&inTerrain(p[0],p[1])&&!OB.some(o=>u>o[0]&&u<o[2]&&v>o[1]&&v<o[3]))TREES.push([p[0],p[1],s,rr()]);};
      const mass=(cu,cv,rad,n,s0)=>{for(let i=0;i<n;i++){const a=rr()*Math.PI*2,d=Math.sqrt(rr())*rad;t(cu+Math.cos(a)*d,cv+Math.sin(a)*d,s0+rr()*.5);}};
      const field=(u0,v0,u1,v1,n,s0)=>{for(let i=0;i<n;i++)t(u0+rr()*(u1-u0),v0+rr()*(v1-v0),s0+rr()*.5);};
      mass(-20,-127,8,9,1.4);mass(-67,-172,12,16,1.4);mass(-37,-211,5,5,1.3);mass(25,-112,6,5,1.3);
      field(-123,-80,-2,-50,70,1.3);field(35,-80,94,-50,38,1.3);field(-123,-48,94,56,44,1.0);field(-52,-208,-4,-148,16,.9);field(62,-232,95,-160,10,1.0);
      for(const [u,v] of [[70,45],[88,18],[75,5],[93,38]])t(u,v,1.2);t(-44,159,1.2);
      for(const sd of [-1,1])for(let v=-236;v<56;v+=8.5){if(rr()<.2||(v>-110&&v<-105)||(v>55&&v<62))continue;const u=29.5+sd*6,p=G(u,v);if(inTerrain(p[0],p[1]))PO_FIELD.push([p[0],p[1],.75+rr()*.2,rr()*.2]);}}
    const m=G(0,0);MODELS['cementerio']={x:m[0],y:m[1],h:8};S.dy=0;}
