  // ==== hito: parque-rio-claro ====
  // Parque Río Claro, on the old Balneario Río Claro along the river's east bank, rebuilt by MINVU in two stages
  // (December 2020 and May 2023, 11 ha in all). Drawn on S in grid metres from OpenStreetMap, which was mapped after the
  // works (the Esri imagery still shows the site before them: car parks and a shed): the park w214960079 (also the
  // NOLOTS fence), the promenade w1186585362, the riverside walk w1134342796, the loop w1134342797 and the other
  // footways, the Ciclovía Río Claro w1087760193, the lawns w1414422143–5, w1414455441, w1414457308–9 and their flower
  // beds, the two playgrounds w1134342806–7, the water play w1134342799–800, the toilets w1134342804, a one-storey
  // building by the car park w1134342803, the two table-tennis shelters w1414455446–7, the car park w1414455442, the
  // fountains at the Alameda end w1087760195–6, the floating jetties w1087760192 (with the viewpoint at its end) and
  // w1087760199–207, the boat landing n7771379469, and the palms (Jubaea and Phoenix nodes with their heights). The
  // list of elements is MINVU's (playgrounds, one of them in the eucalyptus wood; water play; ciclovía; floating
  // jetties; kiosk plazas; toilets and services). The moored rowing boats come from photos on Wikimedia Commons (2005,
  // public domain; 2024, CC0). Approximate: everything above the ground (no photo of the renovated park has a free
  // licence): the buildings' heights, walls and roofs, the play equipment, the jetties' height over the water, the
  // number and colours of the boats; the eucalyptus wood is planted in TREES over the south part (the census marks
  // that block as built, so the city would only give it yard trees). No lights: there is no source for them.
  {const K={ground:C('#A3B06C'),grass:C('#5F9840'),grass2:C('#72AC4D'),bloom:C('#C77D8E'),
      pave:C('#D6CDBD'),plates:C('#C9C3B6'),dirt:C('#CDB98F'),cycle:C('#B3AEA4'),asph:C('#6E6A65'),line:C('#ECE7DC'),
      rubber:C('#B9573B'),rubber2:C('#4F7FA8'),splash:C('#D9D3C5'),wet:C('#7FB0C4'),jet:C('#E3EEF0'),stone:C('#C6BFAF'),water:C('#4F86B5'),
      wall:C('#D9D2C2'),wall2:C('#C9C3B6'),roof:C('#8F8A82'),white:C('#ECE7DC'),door:C('#5A4636'),glass:C('#3B4653'),
      wood:C('#9A7A55'),wood2:C('#86684A'),edge:C('#5E4732'),post:C('#3A3A3A'),steel:C('#707070'),red:C('#B8483A'),yellow:C('#D9A93B'),table:C('#3F6E5A')};
    const Q=a=>{const o=[];for(let i=0;i<a.length;i+=2)o.push([a[i],a[i+1]]);return o;};
    const area=q=>{let a=0;for(let i=0;i<q.length;i++){const p=q[i],r=q[(i+1)%q.length];a+=p[0]*r[1]-r[0]*p[1];}return a/2;};
    const shrink=(q,f)=>{const c=q.reduce((s,p)=>[s[0]+p[0]/q.length,s[1]+p[1]/q.length],[0,0]);return q.map(p=>[c[0]+(p[0]-c[0])*f,c[1]+(p[1]-c[1])*f]);};
    // the park's ground stops 8 m short of the water: the gravel strip along the shore lies at the same height (0.11)
    const shore=CLARO[0]||[],offShore=(p,d)=>{let best=1e9,q=null;
      for(let i=0;i<shore.length;i++){const a=shore[i],b=shore[(i+1)%shore.length],dx=b[0]-a[0],dy=b[1]-a[1];let t=((p[0]-a[0])*dx+(p[1]-a[1])*dy)/(dx*dx+dy*dy||1);t=t<0?0:t>1?1:t;
        const c=[a[0]+dx*t,a[1]+dy*t],e=Math.hypot(p[0]-c[0],p[1]-c[1]);if(e<best){best=e;q=c;}}
      const wet=inClaro(p[0],p[1]);if(!q||(best>=d&&!wet))return p;const s=(wet?-1:1)/(best||1);return [q[0]+(p[0]-q[0])*s*d,q[1]+(p[1]-q[1])*s*d];};
    const PARK=Q([-1537,720.5,-1536.5,713,-1535.5,696,-1534.5,659.5,-1534.5,627.5,-1535,612,-1537,604.5,-1536.5,602,-1538.5,574,-1539,566.5,-1539.5,560,-1541,546,-1498,543.5,-1392.5,545.5,-1311,550.5,-1214.5,557.5,-1200,558.5,-1192.5,624.5,-1317.5,639,-1297.5,680,-1414,733.5,-1344,879.5,-1331.5,917.5,-1323,916,-1319.5,936.5,-1315,983,-1379.5,1027,-1394,1024,-1406.5,1028,-1395.5,1075,-1424,1086,-1428.5,1088.5,-1434.5,1078,-1436,1066.5,-1442,1051,-1445.5,1042,-1447.5,1037.5,-1459,1015.5,-1463.5,1005.5,-1467.5,997,-1471,989.5,-1475,975,-1479.5,954,-1480,951.5,-1484,928,-1492.5,908.5,-1509.5,876.5,-1518,862,-1524,852,-1528,838.5,-1530.5,832,-1533,823,-1536.5,763,-1537,748]);
    const GRD=PARK.map(p=>offShore(p,8));NOLOTS.push(PARK);
    // footways [width, colour, line]: the promenade, the riverside walk (paving stones), the loop (concrete plates),
    // the dirt walk in the wood, the entrance from the Alameda end, the cross walks
    const WALKS=[[5,K.pave,[-1331,937,-1366,942.5,-1367,939.5,-1386.5,879.5,-1393.5,856,-1413.5,790.5,-1433,721,-1438.5,699.5,-1438.5,686,-1439,666,-1438,633.5,-1433,621.5,-1409.5,582]],
      [4,K.pave,[-1508.5,603.5,-1508,642.5,-1505.5,653,-1505.5,690.5,-1508,762.5,-1508.5,787.5,-1510,831,-1507,843.5,-1486.5,887,-1473,915.5,-1464,934,-1452.5,958,-1436,997,-1433.5,997,-1432.5,953.5,-1432.5,936,-1432,910.5]],
      [4,K.plates,[-1401.5,788,-1407.5,789,-1413.5,790.5,-1465.5,776,-1508,762.5,-1515.5,760.5,-1513,693,-1505.5,690.5,-1471,678,-1439,666,-1435,664.5,-1430,663]],
      [3.5,K.pave,[-1389.5,944.5,-1409.5,916,-1432,885,-1466,838,-1468,832.5,-1473,821.5,-1474,810,-1465.5,776,-1458.5,735,-1460.5,719,-1471,678,-1489,597.5,-1493,583.5,-1475.5,580.5,-1422.5,564.5,-1412,565.5,-1393,577]],
      [3,K.dirt,[-1508.5,603.5,-1489,597.5,-1425,578,-1416,578.5,-1409.5,582,-1400.5,586.5]],
      [4,K.pave,[-1400.5,586.5,-1382.5,594.5,-1365.5,601,-1343,607,-1319.5,610,-1303,609,-1282,605,-1258.5,595.5,-1240.5,581.5,-1221,561,-1214.5,557.5,-1208.5,557]],
      [3.5,K.pave,[-1361.5,927.5,-1366.5,935,-1367,939.5,-1389.5,944.5,-1399.5,946.5,-1432.5,953.5,-1452.5,958,-1471,961.5]],
      [3,K.pave,[-1473,915.5,-1454,902,-1432,885,-1393.5,856,-1390,853,-1384.5,849]],[3,K.pave,[-1409.5,916,-1432,910.5,-1454,902,-1486.5,887]],
      [3,K.pave,[-1473,821.5,-1476.5,821,-1481,819,-1508.5,787.5]],[3,K.pave,[-1464,934,-1432.5,936]]];
    const CYCLE=[-1361.5,927.5,-1367,927.5,-1369,924.5,-1390,853,-1407.5,789,-1429.5,719,-1433.5,698.5,-1435,664.5,-1434.5,633,-1431,624.5,-1412,590.5,-1405.5,593,-1352,613,-1343,616,-1337,617,-1329.5,618,-1321.5,617.5,-1239,606.5,-1228,604.5,-1221,602,-1215.5,598,-1212,591.5,-1211.5,584,-1214,559,-1208.5,559];
    const LAWNS=[[-1427.5,884,-1395.5,859.5,-1387.5,886.5,-1388,893.5,-1392,907.5,-1397,927,-1408.5,911],[-1431,949,-1402.5,943.5,-1400,941.5,-1399,938.5,-1412,922,-1430,914],
      [-1436.5,1001.5,-1436,1008,-1416,1007.5,-1402.5,951,-1431,956.5,-1431,978,-1430,978,-1430.5,1001.5],[-1397,855.5,-1416,790.5,-1461.5,778,-1469,811.5,-1468,819.5,-1465.5,830,-1462,837,-1429,881],
      [-1317,982.5,-1322,967,-1354,988,-1345,1002],[-1341.5,941,-1340.5,946.5,-1366,977.5,-1381.5,950,-1367.5,946.5]].map(Q);
    const BEDS=[Q([-1381.5,950,-1367.5,946.5,-1368.5,944,-1382,947.5]),Q([-1392,907.5,-1393.5,907,-1396,917.5,-1401,918.5,-1407,910,-1408.5,911,-1397,927]),ngon(-1403.7,889.3,4.6,12)];
    const PLAY=[Q([-1496.5,794,-1504.5,786,-1503,747.5,-1484.5,744]),Q([-1473.5,892,-1482.5,865.5,-1469.5,859,-1428,906,-1432,909])];
    const SPLASH=[Q([-1434.5,975,-1438,975,-1445,960,-1434,958]),Q([-1449,952,-1454,939.5,-1454,938,-1434,939,-1434,948.5])];
    const POOLS=[Q([-1235,580.5,-1225.5,571.5,-1223,571,-1218,593]),Q([-1242,574,-1229.5,562.5,-1231,561,-1249.5,563,-1252,566])];
    const CARS=Q([-1350,920.5,-1333,916.5,-1342,888.5,-1358,893.5]);
    const occPath=(a,w)=>{const p=Q(a);for(let i=0;i<p.length-1;i++){const [x0,y0]=p[i],[x1,y1]=p[i+1],L=Math.hypot(x1-x0,y1-y0);if(L<.1)continue;
      occMark(rotRect((x0+x1)/2,(y0+y1)/2,L+w,w+1.5,Math.atan2(y1-y0,x1-x0)));}};
    // a polygon cut into bands w wide across its longest side (half-plane clips: Sutherland-Hodgman), for two tones
    const half=(q,d,k,sg)=>{const o=[];for(let i=0;i<q.length;i++){const p=q[i],r=q[(i+1)%q.length],fp=(p[0]*d[0]+p[1]*d[1]-k)*sg,fr=(r[0]*d[0]+r[1]*d[1]-k)*sg;
      if(fp>=0)o.push(p);if(fp*fr<0){const t=fp/(fp-fr);o.push([p[0]+(r[0]-p[0])*t,p[1]+(r[1]-p[1])*t]);}}return o;};
    const bands=(fp,w)=>{let L0=0,d=[1,0];for(let i=0;i<fp.length;i++){const a=fp[i],b=fp[(i+1)%fp.length],l=Math.hypot(b[0]-a[0],b[1]-a[1]);if(l>L0){L0=l;d=[(b[0]-a[0])/l,(b[1]-a[1])/l];}}
      const pr=fp.map(p=>p[0]*d[0]+p[1]*d[1]),o=[];for(let k=Math.min(...pr);k<Math.max(...pr);k+=w)o.push(half(half(fp,d,k,1),d,k+w,-1));return o;};
    // ground, draped on the terrain (no pad: the park follows the river's terrace): park ground 0.11, lawns 0.13 (mown
    // in 4 m stripes), beds 0.145, walks 0.16, the ciclovía, play surfaces, water play, pools and the car park 0.175,
    // their details 0.19
    {const Lg=new GB(1<<14),lay=(q,o,c)=>{if(q.length>2)Lg.flat(q,o,c);};
      lay(GRD,.11,K.ground);LAWNS.forEach(q=>bands(q,4).forEach((b,n)=>lay(b,.13,n%2?K.grass2:K.grass)));BEDS.forEach(q=>lay(q,.145,K.bloom));
      for(const [w,c,a] of WALKS)ribbon(Lg,Q(a),w,.16,c);
      ribbon(Lg,Q(CYCLE),2.6,.175,K.cycle);
      // playgrounds: rubber in two colours with a band of the other every 4 m; water play: a pale pad with wet discs
      PLAY.forEach((q,i)=>{lay(q,.175,i?K.rubber2:K.rubber);const c=shrink(q,.55);lay(c,.19,i?K.rubber:K.rubber2);});
      SPLASH.forEach(q=>{lay(q,.175,K.splash);const c=q.reduce((s,p)=>[s[0]+p[0]/q.length,s[1]+p[1]/q.length],[0,0]);lay(ngon(c[0],c[1],2.6,12),.19,K.wet);});
      POOLS.forEach(q=>{lay(q,.175,K.stone);lay(shrink(q,.8),.19,K.water);});
      lay(CARS,.175,K.asph);for(let t=.12;t<.95;t+=.11){const a=[CARS[0][0]+(CARS[3][0]-CARS[0][0])*t,CARS[0][1]+(CARS[3][1]-CARS[0][1])*t],b=[CARS[1][0]+(CARS[2][0]-CARS[1][0])*t,CARS[1][1]+(CARS[2][1]-CARS[1][1])*t];
        lay(rotRect((a[0]*.7+b[0]*.3),(a[1]*.7+b[1]*.3),5,.4,Math.atan2(b[1]-a[1],b[0]-a[0])),.19,K.line);}
      const d=drape(Lg);S.dy=0;
      for(let t=0;t<d.ni;t+=3){const k=d.I[t]*3;S.face([0,1,2].map(j=>{const m=d.I[t+j]*3;return [d.P[m],d.P[m+1],d.P[m+2]];}),[0,1,0],[d.C[k],d.C[k+1],d.C[k+2]]);}}
    // the city's trees keep off the walks, lawns, play areas and buildings
    for(const [w,,a] of WALKS)occPath(a,w);occPath(CYCLE,2.6);[...LAWNS,...PLAY,...SPLASH,...POOLS,CARS].forEach(q=>occMark(q));
    // a building in its own frame: v along its longest side; walls, a white band at the top, a grey flat roof
    const hut=(fp,h,wall,doors)=>{let L=0,A=0;for(let i=0;i<fp.length;i++){const a=fp[i],b=fp[(i+1)%fp.length],l=Math.hypot(b[0]-a[0],b[1]-a[1]);if(l>L){L=l;A=Math.atan2(b[1]-a[1],b[0]-a[0]);}}
      const c=fp.reduce((s,p)=>[s[0]+p[0]/fp.length,s[1]+p[1]/fp.length],[0,0]),F=localFrame(c[0],c[1],A),{box,WU,WV,rect}=facade(S,F,K);
      const uv=fp.map(p=>{const dx=p[0]-c[0],dy=p[1]-c[1];return [dx*Math.sin(A)-dy*Math.cos(A),dx*Math.cos(A)+dy*Math.sin(A)];});
      const u1=Math.max(...uv.map(p=>Math.abs(p[0]))),v1=Math.max(...uv.map(p=>Math.abs(p[1])));occMark(fp);S.dy=groundMin(fp);
      box(-u1,-v1,u1,v1,.3,h-.03,wall,wall,false);box(-u1-.12,-v1-.12,u1+.12,v1+.12,h-.5,h+.1,K.white,K.white,false);S.flat(F.R(-u1,-v1,u1,v1),h,K.roof);
      for(const sg of [1,-1]){const w=WU(sg*u1,sg,.06);for(const s of doors)rect(w,s-.6,s+.6,.3,2.4,K.door);}
      for(const sg of [1,-1])rect(WV(sg*v1,sg,.06),-u1*.6,u1*.6,1,2.2,K.glass);};             // a window on each end
    hut(Q([-1436.5,608,-1428.5,612,-1415,585.5,-1423,581.5]),3.2,K.wall,[-11,-7,7,11]);   // toilets and services
    hut(Q([-1377,938.5,-1371,937,-1379,908.5,-1385,910]),3.4,K.wall2,[-10,-4,2,8]);        // building by the car park
    // table-tennis shelters: four posts, a flat roof, two green tables under it
    for(const fp of [Q([-1385,910,-1387.5,900.5,-1382,899,-1379,908.5]),Q([-1371,937,-1369,945,-1374.5,946.5,-1377,938.5])]){S.dy=groundMin(fp);occMark(fp);
      const sh=shrink(fp,.85);for(const p of sh)S.prism(rotRect(p[0],p[1],.3,.3),.3,3,K.steel,K.steel);S.prism(fp,3,3.25,K.white,K.roof);
      const c=fp.reduce((s,p)=>[s[0]+p[0]/4,s[1]+p[1]/4],[0,0]),a=Math.atan2(fp[1][1]-fp[0][1],fp[1][0]-fp[0][0]);
      for(const o of [-2.3,2.3])S.prism(rotRect(c[0]+Math.cos(a)*o,c[1]+Math.sin(a)*o,2.7,1.5,a),.75,.85,K.table,K.table);}
    // play equipment: towers with pyramid roofs, a slide, a swing frame (pixel-sized, on the rubber)
    {const tower=(x,y,a,col)=>{S.dy=E(x,y);S.prism(rotRect(x,y,2.2,2.2,a),.3,2.4,K.wood,K.wood2);S.prism(rotRect(x,y,2.4,2.4,a),2.4,2.6,K.white,K.white);pyramid(S,rotRect(x,y,2.6,2.6,a),2.6,1.6,col);
        const c=Math.cos(a),s=Math.sin(a);S.prism(rotRect(x+c*2.4,y+s*2.4,2.6,.9,a),.3,1.2,K.yellow,K.yellow);};
      const swing=(x,y,a)=>{S.dy=E(x,y);const c=Math.cos(a),s=Math.sin(a);for(const o of [-2.2,2.2])S.prism(rotRect(x+c*o,y+s*o,.3,1.6,a),.3,2.6,K.steel,K.steel);
        S.prism(rotRect(x,y,4.8,.3,a),2.6,2.85,K.red,K.red);for(const o of [-1,1])S.prism(rotRect(x+c*o,y+s*o,.6,.4,a),.7,.85,K.post,K.post);};
      tower(-1495,772,.2,K.red);swing(-1494,756,1.4);tower(-1462,880,.85,K.rubber2);tower(-1447,893,.85,K.red);swing(-1471,872,.85);}
    // water play: low jets on the wet discs
    SPLASH.forEach(q=>{const c=q.reduce((s,p)=>[s[0]+p[0]/q.length,s[1]+p[1]/q.length],[0,0]);S.dy=E(c[0],c[1]);for(const p of ngon(c[0],c[1],1.7,6))S.prism(rotRect(p[0],p[1],.35,.35),.3,1.1,K.jet,K.jet);});
    // palms (OSM heights; the young Jubaea are 4 m)
    [[-1409,941,4],[-1416,943,4],[-1425,943,4],[-1427,959,4],[-1419,959,4],[-1412,956,4],[-1410,962,4],[-1412,971,4],[-1414,982,4],[-1417,976,7],[-1425,969,11],[-1424,989,14],[-1428,986,14],[-1431,920,14]]
      .forEach(([x,y,h],i)=>{S.dy=E(x,y);palmS(x,y,Math.max(5,h),i*.7);});
    // floating jetties: a wooden deck half a metre over the water, in 2 m float modules of two tones across its longest
    // side, its edge darker and reaching under the water, bollards at the ends. The deck follows the water's surface
    // (the draped terrain plus 0.11), which climbs toward the bank in the shore cells: it is draped too
    {const WY=(x,y)=>E(x,y)+.11,post=(x,y,h)=>{S.dy=WY(x,y);S.prism(rotRect(x,y,.35,.35),.5,h,K.post,K.post);};
      const deck=fp=>{const Lg=new GB(1<<10);bands(fp,2).forEach((q,n)=>{if(q.length>2)Lg.flat(q,.61,n%2?K.wood2:K.wood);});const d=drape(Lg);S.dy=0;
        for(let t=0;t<d.ni;t+=3){const k=d.I[t]*3;S.face([0,1,2].map(j=>{const m=d.I[t+j]*3;return [d.P[m],d.P[m+1],d.P[m+2]];}),[0,1,0],[d.C[k],d.C[k+1],d.C[k+2]]);}
        const s=area(fp)>0?1:-1;for(let i=0;i<fp.length;i++){const a=fp[i],b=fp[(i+1)%fp.length],L=Math.hypot(b[0]-a[0],b[1]-a[1]);if(L<.05)continue;
          const nx=(b[1]-a[1])/L*s,ny=-(b[0]-a[0])/L*s,ha=WY(a[0],a[1]),hb=WY(b[0],b[1]);
          S.face([[a[0],ha-1.5,-a[1]],[b[0],hb-1.5,-b[1]],[b[0],hb+.5,-b[1]],[a[0],ha+.5,-a[1]]],[nx,0,-ny],K.edge);}};
      const MAIN=Q([-1537,604.5,-1546.5,611.5,-1544,613.5,-1542,611.5,-1539.5,613.5,-1542,615.5,-1540.5,617,-1543.5,619,-1545,617.5,-1549.5,622,-1551.5,620.5,-1546.5,616,-1549,614,-1559,621.5,-1558,622.5,-1572,636.5,-1576,633,-1563,618.5,-1560,620.5,-1536.5,602]);
      deck(MAIN);post(-1574,634.5,1.4);post(-1560.5,620,1.4);
      const D2=Q([-1498.5,968.5,-1494,973,-1481.5,960,-1483.5,958,-1479.5,954,-1480,951.5,-1485,956.5,-1486.5,955]);deck(D2);
      for(const a of [[-1524,852,-1534,858.5,-1537.5,860.5],[-1528,838.5,-1535,841.5,-1543.5,845.5,-1547.5,847.5],[-1528.5,867.5,-1534,858.5,-1539.5,848],[-1538.5,857,-1543.5,845.5,-1549,834],[-1535,841.5,-1540.5,829.5],
        [-1442,1051,-1449.5,1054.5,-1455,1057.5],[-1449.5,1069,-1455,1057.5,-1459,1046.5],[-1452,1049,-1449.5,1054.5]]){const p=Q(a);
        for(let i=0;i<p.length-1;i++){const [x0,y0]=p[i],[x1,y1]=p[i+1],L=Math.hypot(x1-x0,y1-y0);S.dy=WY((x0+x1)/2,(y0+y1)/2);S.prism(rotRect((x0+x1)/2,(y0+y1)/2,L+1,2,Math.atan2(y1-y0,x1-x0)),0,.5,K.edge,i%2?K.wood2:K.wood);}
        post(p[p.length-1][0],p[p.length-1][1],1.3);}}
    // rowing boats at the landing and on the pool above the bridge: open hulls in the balneario's colours
    {const hull=(x,y,a,col)=>{if(!inClaro(x,y))return;const c=Math.cos(a),s=Math.sin(a),P=([u,v])=>[x+u*c-v*s,y+u*s+v*c];
        const q=[[-2.2,-.75],[1.3,-.75],[2.4,0],[1.3,.75],[-2.2,.75]].map(P);S.dy=E(x,y)+.11;S.prism(q,0,.55,col,K.wood2);
        S.prism([[-1.9,-.45],[1.1,-.45],[1.9,0],[1.1,.45],[-1.9,.45]].map(P),.55,.6,K.wood2,K.wood2);S.prism([[-.3,-.75],[.3,-.75],[.3,.75],[-.3,.75]].map(P),.55,.7,col,col);};
      const BC=[C('#E8E2D6'),C('#3F6FA8'),C('#B8483A'),C('#4F8A5A'),C('#D9A93B')];
      [[-1546,688,0],[-1547,694,.05],[-1546.5,700,-.05],[-1547.5,706,0],[-1546,712,.1],[-1553,640,.8],[-1559,646,.75],
       [-1590,735,.8],[-1603,722,2],[-1585,760,1.2],[-1612,748,.3],[-1598,770,2.6]].forEach(([x,y,a],i)=>hull(x,y,a,BC[i%BC.length]));}
    // the eucalyptus wood over the south part (MINVU: «una zona de juegos en el bosque de eucaliptos»), tall round trees
    {const r=rng(4131);for(let n=0;n<900;n++){const x=-1540+r()*350,y=545+r()*260;
      if(!pip([x,y],GRD)||(y>725&&x>-1470)||occAt(x,y)||nearStreet(x,y,2))continue;TREES.push([x,y,1.35+r()*.5,r()]);}}
    MODELS['parque-rio-claro']={x:-1455,y:800,h:6};S.dy=0;}
