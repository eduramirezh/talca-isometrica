  // ==== hito: estadio ====
  // Estadio Fiscal, built on S (no window shader: terrace risers are vertical faces). The layout is OpenStreetMap's
  // (pitch w815575960, track r11198725, bowl w1073859992, site w1417437668, the four lighting masts, the entrances), in
  // a frame centred on the pitch: u across it (+ toward the east stand), v along it (+ toward 5 Norte). The point in
  // pois.py is the address, on the bowl's east side, so the model is not centred on it. Pixel-art cues: stepped rows
  // in two tones, stairways, mowing stripes, lines drawn wider than real so they survive at 1 m/px. Roofs, seats and
  // masts follow photos from 2021–2025 (Wikimedia Commons) and StadiumDB on the 2017 works; the Esri imagery predates
  // them. Approximate: the north end's height and the black seats' pattern. Method: docs/METODOLOGIA.md §9.
  {const X=-780.8,Y=684.8,A=64.8*Math.PI/180,HL=42.9; // HL: half the track's straight
    const {G,Gs,V,N3,R}=localFrame(X,Y,A);
    const K={apron:C('#86A35A'),track:C('#B9573B'),lane:C('#E9DDC6'),infield:C('#6B9B45'),grassA:C('#5F9840'),grassB:C('#72AC4D'),
      line:C('#F3F0E6'),seat:C('#B4372C'),seat2:C('#2F2B2B'),riser:C('#B9B2A3'),aisle:C('#E2B33C'),
      wall:C('#D9D2C2'),rim:C('#EEE8DA'),door:C('#4A3F3A'),roof:C('#F0EFE9'),rib:C('#D8D6CE'),truss:C('#7A5B48'),
      glass:C('#4D5D66'),mast:C('#707070'),panel:C('#3E3C3A'),lamp:C('#FFF4C8'),hockey:C('#3E6D9C')};
    // oval of the track's shape: semicircles of radius r centred at v=±HL
    const oval=(r,n=24)=>{const o=[];for(let i=0;i<=n;i++){const t=Math.PI*i/n;o.push([r*Math.cos(t),HL+r*Math.sin(t)]);}
      for(let i=0;i<=n;i++){const t=Math.PI+Math.PI*i/n;o.push([r*Math.cos(t),-HL+r*Math.sin(t)]);}return o;};
    const ovalStrip=(r0,r1,y,col)=>{const a=oval(r0),b=oval(r1);for(let i=0;i<a.length;i++){const j=(i+1)%a.length;
      S.face([V(...a[i],y),V(...a[j],y),V(...b[j],y),V(...b[i],y)],[0,1,0],col);}};
    const arc=(cu,cv,r0,r1,y,col,n=32)=>{for(let i=0;i<n;i++){const t0=i/n*Math.PI*2,t1=(i+1)/n*Math.PI*2,c0=Math.cos(t0),s0=Math.sin(t0),c1=Math.cos(t1),s1=Math.sin(t1);
      S.face([V(cu+r0*c0,cv+r0*s0,y),V(cu+r0*c1,cv+r0*s1,y),V(cu+r1*c1,cv+r1*s1,y),V(cu+r1*c0,cv+r1*s0,y)],[0,1,0],col);}};
    const frame=(u0,v0,u1,v1,y,w)=>{for(const q of [R(u0,v0,u1,v0+w),R(u0,v1-w,u1,v1),R(u0,v0,u0+w,v1),R(u1-w,v0,u1,v1)])S.quadXY(q,y,K.line);};
    // footprint: the bowl's outer edge plus the main stand's strip, as in the OSM site outline; it levels the ground
    // and keeps the procedural city and the park trees off it
    const site=[];for(let t=180;t<=360;t+=6){const r=Math.PI*t/180;site.push([81*Math.cos(r),-HL+81*Math.sin(r)]);}
    for(let t=0;t<=140;t+=6){const r=Math.PI*t/180,w=Math.max(0,Math.cos(r));site.push([(59+22*w)*Math.cos(r),HL+(59+22*w)*Math.sin(r)]);}
    site.push([-61,71],[-80,70]);
    const HOCKEY=[[126.5,-84.2],[114.7,-46.9],[95.6,-53.0],[107.5,-90.3]]; // paved hockey pitch w391604115, by the Alameda
    const fp=Gs(site),hk=Gs(HOCKEY),all=fp.concat(hk);occMark(fp);occMark(hk);
    // the whole fenced sports complex (w89069046: stadium, pool, courts) gets trees but no procedural houses
    NOLOTS.push([[-829,803],[-888,660],[-884,613],[-889,571],[-850,570],[-836,555],[-640,552],[-523,554],[-461,685],[-463,688],[-632,749],[-656,751]]);
    S.dy=padAt(Math.min(...all.map(p=>p[0])),Math.min(...all.map(p=>p[1])),Math.max(...all.map(p=>p[0])),Math.max(...all.map(p=>p[1])));
    // ground: apron, 400 m track (8 lanes of 1.22 m, a line every second lane), infield, pitch with mowing stripes
    S.flat(fp,0.30,K.apron);S.flat(oval(46.4).map(p=>G(...p)),0.33,K.track);
    ovalStrip(36.2,36.7,0.36,K.lane);for(const k of [2,4,6])ovalStrip(36.2+1.22*k-.15,36.2+1.22*k+.15,0.36,K.lane);ovalStrip(46.0,46.4,0.36,K.lane);
    S.flat(oval(36.2).map(p=>G(...p)),0.36,K.infield);
    for(let k=0;k<10;k++)S.quadXY(R(-33.5,-52.85+k*10.57,33.5,-52.85+(k+1)*10.57),0.39,k%2?K.grassA:K.grassB);
    const lw=0.5;frame(-33.5,-52.85,33.5,52.85,0.42,lw);S.quadXY(R(-33.5,-lw/2,33.5,lw/2),0.42,K.line);arc(0,0,9.15-lw/2,9.15+lw/2,0.42,K.line);
    S.quadXY(R(-.6,-.6,.6,.6),0.43,K.line);
    for(const sg of [1,-1]){const g0=sg*52.85,g1=sg*(52.85-16.5),a0=sg*(52.85-5.5);
      frame(-20.15,Math.min(g0,g1),20.15,Math.max(g0,g1),0.42,lw);frame(-9.16,Math.min(g0,a0),9.16,Math.max(g0,a0),0.42,lw);
      S.quadXY(R(-.5,sg*41.85-.5,.5,sg*41.85+.5),0.43,K.line);
      const gv=sg*(52.85+.3);for(const gu of [-3.66,3.66])S.prism(R(gu-.2,gv-.2,gu+.2,gv+.2),0.42,2.6,K.line,K.line);
      S.prism(R(-3.86,gv-.2,3.86,gv+.2),2.3,2.65,K.line,K.line);}
    // stepped stands: pts = inner edge [u, v, outward normal u, v, depth, top height, curve]; n rows climb from a
    // parapet at FRONT to the top, then a rim. Red seats with yellow stairways every 16 m, black rows woven into the
    // curves (photos on Wikimedia Commons, 2021–2025). roof: the PVC membrane canopy that since the 2017 works covers
    // the east stand and both ends, on columns behind the top row, in 12 m bays, short of the front rows
    const FRONT=1.4;
    const stand=(pts,n,roof)=>{let s=0,bay=-1;
      const P=(p,o,h)=>V(p[0]+p[2]*o,p[1]+p[3]*o,h);
      for(let i=0;i<pts.length-1;i++){const a=pts[i],b=pts[i+1],L=Math.hypot(b[0]-a[0],b[1]-a[1]);
        const nm=N3((a[2]+b[2])/2,(a[3]+b[3])/2),ni=[-nm[0],0,-nm[2]],aisle=(s+L/2)%16<2.2;s+=L;
        S.face([P(a,0,-1),P(b,0,-1),P(b,0,FRONT),P(a,0,FRONT)],ni,K.wall);
        let ya0=FRONT,yb0=FRONT;
        for(let k=0;k<n;k++){const ya=FRONT+(a[5]-FRONT)*(k+1)/n,yb=FRONT+(b[5]-FRONT)*(k+1)/n;
          const oa0=a[4]*k/n,oa1=a[4]*(k+1)/n,ob0=b[4]*k/n,ob1=b[4]*(k+1)/n;
          const top=aisle?K.aisle:a[6]&&k%3===2?K.seat2:K.seat;
          S.face([P(a,oa0,ya0),P(b,ob0,yb0),P(b,ob0,yb),P(a,oa0,ya)],ni,K.riser);
          S.face([P(a,oa0,ya),P(b,ob0,yb),P(b,ob1,yb),P(a,oa1,ya)],[0,1,0],top);ya0=ya;yb0=yb;}
        const da=a[4],db=b[4];
        S.face([P(a,da-.5,ya0),P(b,db-.5,yb0),P(b,db-.5,yb0+1),P(a,da-.5,ya0+1)],ni,K.wall);
        S.face([P(a,da-.5,ya0+1),P(b,db-.5,yb0+1),P(b,db,yb0+1),P(a,da,ya0+1)],[0,1,0],K.rim);
        S.face([P(a,da,-1),P(b,db,-1),P(b,db,yb0+1),P(a,da,ya0+1)],nm,K.wall);
        if(roof){const bi=Math.floor((s-L/2)/12),ha=a[5]+5.5,hb=b[5]+5.5,fa=a[5]+4.2,fb=b[5]+4.2;
          if(bi!==bay){bay=bi;const c=[a[0]+a[2]*(da+.4),a[1]+a[3]*(da+.4)];S.prism(R(c[0]-.35,c[1]-.35,c[0]+.35,c[1]+.35),0.3,ha,K.mast,K.mast);}
          S.face([P(a,da+.8,ha),P(b,db+.8,hb),P(b,3,fb),P(a,3,fa)],null,bi%2?K.rib:K.roof);
          S.face([P(a,3,fa-.7),P(b,3,fb-.7),P(b,3,fb),P(a,3,fa)],ni,K.truss);
          S.face([P(a,da+.8,ha-.7),P(b,db+.8,hb-.7),P(b,db+.8,hb),P(a,da+.8,ha)],nm,K.truss);}}
      for(const [p,q] of [[pts[0],pts[1]],[pts[pts.length-1],pts[pts.length-2]]]){const tn=N3(p[0]-q[0],p[1]-q[1]);
        let y0=FRONT;S.face([P(p,0,-1),P(p,p[4]/n,-1),P(p,p[4]/n,y0),P(p,0,y0)],tn,K.wall);
        for(let k=0;k<n;k++){const y=FRONT+(p[5]-FRONT)*(k+1)/n;S.face([P(p,p[4]*k/n,-1),P(p,p[4]*(k+1)/n,-1),P(p,p[4]*(k+1)/n,y),P(p,p[4]*k/n,y)],tn,K.wall);}
        S.face([P(p,p[4]-.5,-1),P(p,p[4],-1),P(p,p[4],p[5]+1),P(p,p[4]-.5,p[5]+1)],tn,K.wall);}};
    // the bowl, one continuous stand: south curve (by the Alameda), east stand, low north curve that thins out
    // toward the gate between it and the main stand, where the service road from 5 Norte comes in
    const bowl=[];
    for(let t=188;t<360;t+=4){const r=Math.PI*t/180,c=Math.cos(r),s=Math.sin(r);bowl.push([60*c,-HL+60*s,c,s,20,10,1]);}
    for(let v=-HL;v<HL;v+=3.3)bowl.push([60,v,1,0,20,10,0]);
    for(let t=0;t<=140;t+=4){const r=Math.PI*t/180,c=Math.cos(r),s=Math.sin(r),w=Math.max(0,c),ri=50+10*w;bowl.push([ri*c,HL+ri*s,c,s,8+12*w,3.5+6.5*w,1]);}
    stand(bowl,10,true);
    // entrances on the south curve's back wall (OSM entrance nodes)
    for(const t of [297.4,274,259]){const r=Math.PI*t/180,c=Math.cos(r),s=Math.sin(r),ro=80.08;
      S.face([V(ro*c-1.6*s,-HL+ro*s+1.6*c,-1),V(ro*c+1.6*s,-HL+ro*s-1.6*c,-1),V(ro*c+1.6*s,-HL+ro*s-1.6*c,3),V(ro*c-1.6*s,-HL+ro*s+1.6*c,3)],N3(c,s),K.door);}
    // main stand (west): rows under a roof that covers all of it since 2017, press level glazed toward the pitch
    const main=[];for(let v=-50;v<=62;v+=4)main.push([-50,v,-1,0,20,11,0]);stand(main,10,false);
    S.prism(R(-78,-52,-70.5,64),0.3,18.4,K.wall,K.rim);S.face([V(-70.45,-50,12.5),V(-70.45,62,12.5),V(-70.45,62,15.5),V(-70.45,-50,15.5)],N3(1,0),K.glass);
    for(let v=-54,k=0;v<64;v+=4,k++)S.face([V(-79,v,19.2),V(-79,v+4,19.2),V(-48.5,v+4,17.4),V(-48.5,v,17.4)],null,k%2?K.rib:K.roof);
    S.face([V(-48.5,-54,16.6),V(-48.5,64,16.6),V(-48.5,64,17.4),V(-48.5,-54,17.4)],N3(1,0),K.truss);
    for(const sg of [-54,64])S.face([V(-79,sg,18.4),V(-48.5,sg,16.6),V(-48.5,sg,17.4),V(-79,sg,19.2)],N3(0,Math.sign(sg)),K.truss);
    // lighting masts (OSM man_made=mast, tower:type=lighting): a lamp panel facing the centre spot; they glow at night
    for(const [mu,mv] of [[57.6,69.8],[59.0,-72.0],[-57.5,72.0],[-58.9,-74.2]]){const H=38,L=Math.hypot(mu,mv),fu=-mu/L,fv=-mv/L,tu=-fv,tv=fu;
      S.prism(R(mu-.7,mv-.7,mu+.7,mv+.7),0.3,H,K.mast,K.mast);
      const pu=mu+fu*1.2,pv=mv+fv*1.2;S.prism(Gs([[pu-tu*4,pv-tv*4],[pu+tu*4,pv+tv*4],[pu+tu*4+fu*.8,pv+tv*4+fv*.8],[pu-tu*4+fu*.8,pv-tv*4+fv*.8]]),H-2,H+3.5,K.panel,K.panel);
      const fu2=pu+fu*.85,fv2=pv+fv*.85;
      for(let i=0;i<4;i++)for(let j=0;j<3;j++){const c=-3+i*2,h=H-1.2+j*1.7;
        S.face([V(fu2+tu*(c-.7),fv2+tv*(c-.7),h),V(fu2+tu*(c+.7),fv2+tv*(c+.7),h),V(fu2+tu*(c+.7),fv2+tv*(c+.7),h+1.1),V(fu2+tu*(c-.7),fv2+tv*(c-.7),h+1.1)],N3(fu,fv),K.lamp);}
      const g=G(fu2+fu*2.5,fv2+fv*2.5);GLOW.push(g[0],S.dy+H+1,g[1]);}
    // hockey pitch: white border, blue court
    S.quadXY(hk,0.33,K.line);{const c=hk.reduce((a,p)=>[a[0]+p[0]/4,a[1]+p[1]/4],[0,0]);S.quadXY(hk.map(p=>[c[0]+(p[0]-c[0])*.93,c[1]+(p[1]-c[1])*.93]),0.36,K.hockey);}
    MODELS.estadio={x:X,y:Y,h:20};S.dy=0;}
