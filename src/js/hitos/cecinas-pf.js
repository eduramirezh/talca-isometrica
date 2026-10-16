  // ==== hito: cecinas-pf ====
  // Planta de Cecinas PF (PF Alimentos, Productos Fernández), the food plant on the east side of the Ruta 5 Sur's service
  // road; drawn on S. Plan from OpenStreetMap: the lot w297781219 (landuse=industrial, man_made=works), the long hall
  // w853342226 (landuse by tag: building=industrial) and the new Plant 4's outline w853342238 (the only two buildings OSM
  // has there). The rest was traced by hand from the Esri imagery (satellite.py punto … --calles, ±3 m): the production
  // halls in the north and their annexes, the green-roofed shed, the boiler tower, the staff car park, the wetland strip
  // along the highway, the truck yard with its oval loop, the dark asphalt yard, the silo, the offices, the tanks and the
  // row of trailers. Sources for what the plant is: Amunategui Barreau's page «PF/Talca Industrial Complex» (a 89,107 m²
  // lot on the highway; Plant 3 finished, Plant 4 of 6,093 m² and the laboratory-and-canteen of 1,173 m² «completed
  // 2012»; the page is not clear if they were still on site) and The Clinic (2025: six plants, all in Talca). There is no
  // free photo of the plant (Commons has none), so none of the walls' colours or heights is from one: the roofs are what
  // the imagery shows (flat white and grey membrane with plant on them; the green shed's roof dark grey-blue).
  // Approximate: every height (halls 13-16 m, the tower 16 m), the wall colour, and Plant 4: the imagery shows its
  // steel frame without roof or walls (the imagery is from the construction, before the page's 2012), so it is drawn
  // finished on OSM's outline (a grey hall with the same sheet roof as the long hall). The long hall's roof bands and
  // the hvac boxes on every roof are generic. The whole plant stands on one levelled pad (the real one is graded;
  // the terrain falls 13 m from Plant 4 to the north end); the construction site south of the north block and the sports pitches
  // east of the lot are not drawn (the generic «industrial» use, entry 101, is skipped under the whole lot). No lights: none documented.
  {const K={wall:C('#D9D6CE'),wall2:C('#C9C6BD'),white:C('#ECE7DC'),roof:C('#E1DED5'),roof2:C('#CFCCC3'),roof3:C('#BDBAB2'),slate:C('#5E6E74'),slate2:C('#566569'),
      pave:C('#A39F97'),dirt:C('#BDAF93'),dirt2:C('#B3A585'),asph:C('#6C6864'),park:C('#77736E'),wet:C('#5C7C45'),wet2:C('#4E6E3A'),tank:C('#E2B33C'),silo:C('#D7D3CA'),
      trailer:C('#E6E4DE'),hvac:C('#8F8C86'),glass:C('#3B4653'),
      car:['#E8E6E0','#2F3133','#9A9DA0','#B4372C','#3E6D9C','#CFCBC1','#6E7276'].map(C),cab:['#B4372C','#3E6D9C','#2F3133'].map(C)};
    const r=rng(9411);
    const ccw=ring=>{let A=0;for(let i=0;i<ring.length;i++){const p=ring[i],q=ring[(i+1)%ring.length];A+=p[0]*q[1]-q[0]*p[1];}return A<0?ring.slice().reverse():ring;};
    // walls of a counter-clockwise ring, a white cornice, a flat roof; the hvac boxes on the roof are placed by n and spacing
    const slab=(ring,h,wall,roof,hv=0)=>{ring=ccw(ring);
      for(let i=0;i<ring.length;i++){const a=ring[i],b=ring[(i+1)%ring.length],L=Math.hypot(b[0]-a[0],b[1]-a[1]);if(L<.01)continue;
        const nx=(b[1]-a[1])/L,ny=-(b[0]-a[0])/L,P=(p,y)=>[p[0],y,-p[1]],N=[nx,0,-ny];
        S.face([P(a,.3),P(b,.3),P(b,h-.5),P(a,h-.5)],N,i%2?wall:shade(wall,.93));S.face([P(a,h-.5),P(b,h-.5),P(b,h),P(a,h)],N,K.white);}
      S.flat(ring,h,roof);
      if(hv){let x0=1e9,y0=1e9,x1=-1e9,y1=-1e9;for(const p of ring){x0=Math.min(x0,p[0]);x1=Math.max(x1,p[0]);y0=Math.min(y0,p[1]);y1=Math.max(y1,p[1]);}
        for(let k=0,t=0;k<hv*8&&t<hv;k++){const x=x0+r()*(x1-x0),y=y0+r()*(y1-y0);if(!pipXY(x,y,ring)||[[2,2],[-2,2],[2,-2],[-2,-2]].some(([dx,dy])=>!pipXY(x+dx*1.6,y+dy*1.6,ring)))continue;
          const q=[[x-1.6,y-1.2],[x+1.6,y-1.2],[x+1.6,y+1.2],[x-1.6,y+1.2]];S.prism(q,h,h+1.2+r()*.8,K.hvac,K.wall2);t++;}}};
    const IND=[[3297,1270],[3280,1208],[3262,1155],[3308,1167],[3297,1142],[3277,1103],[3264,1061],[3194,1106],[3176,1115],[3127,1001],[3043,1026],[3082,1203],[3112,1308],[3127,1375],[3147,1433],[3212,1616],[3220,1619],[3238,1630],[3360,1611],[3333,1443],[3297,1270]];
    NOLOTS.push(IND);occMark(IND);
    // one pad for the whole plant (the real one is a graded platform; the terrain falls 13 m from Plant 4 to the north end)
    // and its paved lot
    const pad=padAt(3120,1175,3335,1632);S.dy=pad;
    const LOT=[[3112,1330],[3127,1375],[3147,1433],[3212,1616],[3220,1619],[3238,1630],[3360,1611],[3333,1443],[3320,1335]];
    S.flat(ccw(LOT),.3,K.pave);
    S.flat(ccw([[3150,1170],[3290,1165],[3296,1300],[3168,1305]]),.3,K.pave);                                        // the paving around Plant 4
    S.flat(ccw([[3265,1593],[3322,1572],[3331,1543],[3329,1524],[3313,1508],[3286,1508],[3267,1528]]),.33,K.dirt);   // the truck yard's oval loop (bare earth)
    S.flat(ccw([[3226,1426],[3290,1422],[3288,1382],[3249,1352],[3231,1360]]),.33,K.asph);                           // the dark asphalt yard
    S.flat(ccw([[3158,1617],[3191,1617],[3189,1594],[3180,1576],[3178,1552],[3159,1535],[3152,1518],[3142,1483],[3132,1448],[3126,1416],[3118,1415],[3120,1449],[3132,1487],[3145,1527],[3157,1550],[3164,1572],[3166,1592]]),.33,K.wet);
    S.flat(ccw([[3143,1438],[3182,1441],[3186,1421],[3184,1387],[3143,1384]]),.33,K.park);                           // the staff car park
    for(let y=1389;y<1437;y+=4.6)for(const x of [3148,3152.2,3156.4,3160.6,3170,3174.2,3178.4]){if(r()<.28)continue;
      const q=[[x-.95,y-2.1],[x+.95,y-2.1],[x+.95,y+2.1],[x-.95,y+2.1]],c=K.car[Math.floor(r()*K.car.length)];S.prism(q,.34,1.5,c,c);}
    // the halls (OSM's long hall, then the hand-traced ones): [ring, height, wall, roof, hvac boxes]
    for(const [ring,h,w,ro,hv] of [
      [[[3215,1598],[3269,1589],[3269,1573],[3215,1583]],13,K.wall,K.roof,2],                                          // the north hall's flange
      [[[3215,1583],[3265,1569],[3261,1535],[3226,1524],[3204,1524],[3206,1547]],14,K.wall,K.roof,5],                // the main production hall
      [[[3252,1529],[3288,1528],[3288,1513],[3254,1511]],10,K.wall2,K.roof3,2],                                       // the grey wing
      [[[3226,1524],[3252,1529],[3254,1510],[3224,1516]],11,K.wall,K.roof2,2],
      [[[3172,1498],[3183,1514],[3205,1509],[3205,1482],[3176,1485]],16,K.wall,K.roof2,3],                            // the tower (boiler house)
      [[[3168,1450],[3171,1477],[3190,1479],[3198,1456]],9,K.wall2,K.roof3,2],
      [[[3240,1501],[3270,1500],[3269,1482],[3245,1480]],10,K.wall2,K.roof2,3],                                       // the process building
      [[[3295,1488],[3312,1488],[3306,1452],[3292,1453]],8,K.wall,K.roof,1],
      [[[3232,1623],[3300,1616],[3301,1601],[3232,1609]],9,K.wall2,K.slate,0],                                         // the green shed
      [[[3302,1615],[3329,1613],[3329,1600],[3302,1601]],8,K.wall,K.roof,1]]){slab(ring,h,w,ro,hv);}
    // the long hall (w853342226), its roof in bands of two tones across its length
    {const A=[[3177,1340],[3211,1485]],B=[[3213,1331],[3247,1477]],n=22,at=(E,t)=>[E[0][0]+(E[1][0]-E[0][0])*t,E[0][1]+(E[1][1]-E[0][1])*t];
      slab([[3211,1485],[3247,1477],[3213,1331],[3177,1340]],13,K.wall,K.roof,0);
      for(let k=0;k<n;k++){const t0=k/n,t1=(k+1)/n;S.quadXY(ccw([at(A,t0),at(B,t0),at(B,t1),at(A,t1)]),13.03,k%2?K.roof2:K.roof);}
      for(const t of [.25,.55,.8]){const m=[(at(A,t)[0]+at(B,t)[0])/2,(at(A,t)[1]+at(B,t)[1])/2];S.prism([[m[0]-3,m[1]-1.5],[m[0]+3,m[1]-1.5],[m[0]+3,m[1]+1.5],[m[0]-3,m[1]+1.5]],13,14.4,K.hvac,K.wall2);}}
    // the tanks (four yellow cylinders, drawn as boxes), the trailers and the small buildings; the north block's tower is above
    for(let k=0;k<4;k++){const x=3267+k*2.7;S.prism([[x-1,1556-4.5],[x+1,1556-4.5],[x+1,1556+4.5],[x-1,1556+4.5]],.34,2.4,K.tank,K.tank);}
    // Plant 4 (OSM w853342238), finished: its roof in bands across, shrunk toward the centre so they stay inside the L
    {const P4=[[3214,1296],[3281,1281],[3257,1175],[3156,1197],[3173,1276],[3208,1268]];slab(P4,14,K.wall2,K.roof,6);
      const L=(a,b,t)=>[a[0]+(b[0]-a[0])*t,a[1]+(b[1]-a[1])*t],W=[3156,1197],Ee=[3257,1175],W2=[3173,1276],E2=[3281,1281];
      for(let k=0;k<24;k++){const q=[L(W,Ee,k/24),L(W,Ee,(k+1)/24),L(W2,E2,(k+1)/24),L(W2,E2,k/24)],c=[(q[0][0]+q[2][0])/2,(q[0][1]+q[2][1])/2],
          qs=q.map(p=>[c[0]+(p[0]-c[0])*.97,c[1]+(p[1]-c[1])*.9]);
        if(qs.every(p=>pipXY(p[0],p[1],P4)))S.quadXY(ccw(qs),14.03,k%2?K.roof2:K.roof);}}
    for(const [x,y] of [[3220,1335],[3225,1335],[3229,1334],[3234,1333],[3239,1333],[3244,1333],[3249,1332]]){const q=[[x-1.3,y-15],[x+1.3,y-15],[x+1.3,y-1],[x-1.3,y-1]];
      S.prism(q,.5,3.6,K.trailer,K.trailer);const cq=[[x-1.25,y-18],[x+1.25,y-18],[x+1.25,y-15.2],[x-1.25,y-15.2]];S.prism(cq,.5,3.1,K.cab[Math.floor(r()*3)],K.white);}
    for(const q of [[[3277,1324],[3291,1324],[3291,1313],[3278,1312]],[[3134,1359],[3147,1358],[3148,1346],[3134,1347]],[[3131,1341],[3144,1343],[3144,1331],[3132,1329]]]){S.prism(q,.32,5,K.wall,K.roof2);}
    S.prism(ngon(3279,1303,5.4,10),.32,12,K.silo,K.roof2);
    MODELS['cecinas-pf']={x:3235,y:1535,h:18};S.dy=0;}
