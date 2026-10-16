  // ==== hito: talca-country-club ====
  // Talca Country Club, a nine-hole golf course in the north-east (OSM w101587762, leisure=golf_course: only its
  // outline; the roads "Talca Country Club" w282386735 and neighbours are in the map's streets). Replaces the generic
  // «golf» land use (config/usos.json, entry 63), which is skipped because NOLOTS and occ cover the outline.
  // Everything inside the outline is read from the Esri imagery (undated: summer, high sun), because OSM has nothing
  // there and Commons has no photo of the course or its buildings:
  //  - pipeline/golf.py classifies the imagery in 3 m cells into data/golf.json (DATA.golf): the mown turf (the
  //    fairways, greens and tees, as merged rectangles) and the crowns (a tree every 6 m where a cell is dark: crowns
  //    and their shadows, which sit glued to them, so the crowns are approximate);
  //  - read by hand from the same imagery (satellite.py punto … --calles; the grid's 50 m lines, ±5 m): the ten greens
  //    (nine holes and a practice green), their bunkers, the five ponds, the tennis courts, the club's buildings
  //    and the two pools. Which building is the clubhouse is a guess: the red-tile house with its annex (3823-3844,
  //    838-864) on the approach, a dark-roofed building (3880-3916, 923-960) at the end of the road. Hole numbers,
  //    tees and the real fairways' extent are not modelled (the turf is whatever the imagery shows mown).
  // Approximate: every height (houses 6.3 m, the big building 7.5 m), the roofs' colours (red tile and dark slate from
  // the imagery), the tennis courts' size (a parallelogram read from the imagery) and their lines (not drawn), the
  // water's colour (the ponds read grey-green). No lights: none documented. The land is draped on the terrain (no pad:
  // the course lies on the terrace's slope); the buildings stand on their lowest corner.
  {const D=DATA.golf,K={rough:C('#8E9A58'),turf:C('#86AE58'),turf2:C('#7BA44F'),collar:C('#8DB65C'),green:C('#9DC76A'),sand:C('#E2D4A6'),pond:C('#6B8A86'),rim:C('#B7A57A'),
      clay:C('#B5643F'),clay2:C('#A55A38'),line:C('#F1EEE4'),flag:C('#C23B32'),wall:C('#E4DCC8'),wall2:C('#D3CBB7'),tile:C('#A35C42'),tile2:C('#8E4F3A'),slate:C('#4F5359'),slate2:C('#464A50'),
      pool:C('#4E8FA6'),pool2:C('#5E9F6A'),tan:C('#C8A97C'),white:C('#ECE7DC')},
      RING=[[3617,1212],[3691,1176],[3746,1154],[3769,1159],[3798,1177],[3887,1185],[3922,1190],[3959,1180],[3992,1168],[4010,1163],[4013,1164],[4069,1186],[4136,1244],[4149,1255],[4204,1254],[4257,1249],[4333,1228],[4309,1166],[4280,1138],[4264,1121],[4244,1104],[4218,1088],[4185,1063],[4167,1044],[4149,1029],[4070,991],[4012,966],[3981,964],[3952,959],[3931,952],[3921,914],[3915,865],[3918,836],[3905,809],[3887,792],[3862,784],[3839,778],[3804,775],[3774,772],[3758,771],[3680,733],[3663,755],[3622,800],[3595,821],[3585,827],[3522,869],[3498,882],[3487,887],[3472,904],[3272,1054],[3264,1061],[3277,1103],[3297,1142],[3308,1167],[3318,1169],[3357,1189],[3404,1208],[3462,1227],[3499,1222]],
      GREENS=[[3311,1133,9],[3441,1192,9],[3922,1170,11],[4016,1071,9],[3805,1007,9],[3789,930,10],[3660,924,9],[3697,963,11],[3772,868,9],[4292,1210,9],[3800,859,6]],
      BUNKERS=[[3304,1122],[3456,1204],[3914,1164],[3921,1149],[4024,1064],[3777,926],[3795,926],[3655,912],[3666,934],[3700,965],[3768,869],[4306,1208]],
      PONDS=[[[3595,943],[3636,949],[3641,941],[3634,907],[3625,914],[3607,919],[3595,931]],ngon(3334,1126,15,12),ngon(3415,1177,8,10),ngon(3859,1162,12,10),ngon(3885,982,12,10)],
      HOUSES=[[[3823,860],[3837,859],[3844,843],[3827,838]],[[3811,860],[3821,864],[3825,854],[3814,851]],[[3700,814],[3715,820],[3710,801],[3698,802]],[[3880,953],[3899,960],[3916,944],[3902,923],[3885,928]]],
      TENNIS=[[[3607,849],[3695,823],[3687,792],[3601,823]],[[3635,796],[3671,787],[3664,772],[3635,785]],[[3671,784],[3686,780],[3676,759],[3664,758]]];
    NOLOTS.push(RING);occMark(RING);
    // the ground, draped on the terrain: rough 0.11, turf in mown bands 0.12, ponds' banks 0.13, collars, ponds 0.14, greens
    // 0.15, bunkers and courts 0.16
    {const Lg=new GB(1<<15),[ox,oy]=D.o,c=D.c;
      Lg.flat(RING,.11,K.rough);
      for(const [j,i0,i1,n] of D.turf)Lg.flat([[ox+i0*c,oy+j*c],[ox+(i1+1)*c,oy+j*c],[ox+(i1+1)*c,oy+(j+n)*c],[ox+i0*c,oy+(j+n)*c]],.12,(j>>2)&1?K.turf2:K.turf);
      for(const p of PONDS){const m=p.reduce((s,q)=>[s[0]+q[0]/p.length,s[1]+q[1]/p.length],[0,0]);Lg.flat(p.map(q=>[m[0]+(q[0]-m[0])*1.25,m[1]+(q[1]-m[1])*1.25]),.13,K.rim);Lg.flat(p,.14,K.pond);}
      for(const [x,y,r] of GREENS){Lg.flat(ngon(x,y,r+1.6,14),.14,K.collar);Lg.flat(ngon(x,y,r,14),.15,K.green);}
      for(const [x,y] of BUNKERS)Lg.flat(ngon(x,y,3.4,10),.16,K.sand);
      TENNIS.forEach((q,k)=>{Lg.flat(q,.16,k%2?K.clay2:K.clay);});
      const d=drape(Lg);S.dy=0;
      for(let t=0;t<d.ni;t+=3){const k=d.I[t]*3;S.face([0,1,2].map(j=>{const m=d.I[t+j]*3;return [d.P[m],d.P[m+1],d.P[m+2]];}),[0,1,0],[d.C[k],d.C[k+1],d.C[k+2]]);}}
    // the trees: the crowns of data/golf.json, jittered inside their 6 m cell
    // (thinned to 60 %, none on a green, a bunker, a pond or by a building: the imagery's crowns come with their shadows)
    {const r=rng(5151),clear=(x,y)=>GREENS.some(([a,b,R])=>Math.hypot(x-a,y-b)<R+5)||BUNKERS.some(([a,b])=>Math.hypot(x-a,y-b)<7)||
        PONDS.some(p=>p.some(q=>Math.hypot(x-q[0],y-q[1])<9))||HOUSES.some(q=>q.some(p=>Math.hypot(x-p[0],y-p[1])<10))||TENNIS.some(q=>pip([x,y],q));
      for(const [x,y,s] of D.trees){const px=x+(r()-.5)*3,py=y+(r()-.5)*3,k=r();if(k>.6||!inTerrain(px,py)||clear(px,py))continue;TREES.push([px,py,s*.75+r()*.25,r()]);}}
    // a flag on each green
    for(const [x,y] of GREENS){const q=[[x-.25,y-.25],[x+.25,y-.25],[x+.25,y+.25],[x-.25,y+.25]];S.dy=groundMin(q);S.prism(q,.32,2.6,K.white,K.flag);}
    // buildings, each on its lowest corner: a hipped roof on a box
    const house=(q,h,wall,roof,rh)=>{S.dy=groundMin(q);S.prism(q,.32,h,wall,roof,false);pyramid(S,q,h,rh,roof);};
    house(HOUSES[0],6.3,K.wall,K.tile,2.6);                  // the red-tile house
    house(HOUSES[1],3.6,K.wall2,K.tan,1.2);                  // its annex
    house(HOUSES[2],5.8,K.wall,K.tile2,2.4);                 // the house by the tennis courts
    house(HOUSES[3],7.5,K.wall2,K.slate,2.8);                // the dark-roofed building
    // the pools, on the ground
    {const Lg=new GB(1<<8);Lg.flat([[3696,798],[3704,800],[3700,781],[3695,782]],.17,K.pool);Lg.flat([[3837,888],[3846,900],[3849,893],[3839,883]],.17,K.pool2);
      const d=drape(Lg);S.dy=0;for(let t=0;t<d.ni;t+=3){const k=d.I[t]*3;S.face([0,1,2].map(j=>{const m=d.I[t+j]*3;return [d.P[m],d.P[m+1],d.P[m+2]];}),[0,1,0],[d.C[k],d.C[k+1],d.C[k+2]]);}}
    MODELS['talca-country-club']={x:3835,y:852,h:10};S.dy=0;}
