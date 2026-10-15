  // ==== hito: juzgado-familia ====
  // Juzgado de Familia de Talca: the court's own building on 5 Oriente at 3 Norte, opened in August 2012 after the
  // 2010 earthquake ("de modernas y funcionales líneas", Supreme Court speech at the opening, pjud.cl). Drawn on S.
  // Plan from OpenStreetMap (w392091760, 6 levels; the corner to 3 Norte cut on the diagonal); frame from
  // landmark.py frame juzgado-familia 392091760: u east (5 Oriente), v north (3 Norte). Blue hipped metal roof from
  // the Esri imagery (date unknown). No photos found of the façades: they are drawn as a plain modern block (light
  // walls, a glazed ground floor, window bands between piers on the five upper floors, a low glazed entrance in
  // the cut corner), so colours, rhythm and the entrance are approximate; the height is OSM's six levels at ~3 m.
  {const F=localFrame(528.5,309.4,90.8*Math.PI/180),{G,Gs,V,N3,R}=F;
    const K={wall:C('#D9D2C2'),rim:C('#EEE8DA'),glass:C('#4D5D66'),glass2:C('#3B4653'),roof:C('#4A6496'),roof2:C('#3F5684'),
      flat:C('#8F8A82'),door:C('#5A4636'),white:C('#EEE8DA'),tile:C('#4A6496'),tile2:C('#3F5684')};
    const {box,WL,rect}=facade(S,F,K);
    const P=[[-11.37,-17.52],[9.36,-17.45],[8.46,3.14],[2.66,7.46],[2.43,12.19],[-11.36,12.26]];
    const fp=Gs(P);occMark(fp);
    S.dy=padAt(Math.min(...fp.map(p=>p[0])),Math.min(...fp.map(p=>p[1])),Math.max(...fp.map(p=>p[0])),Math.max(...fp.map(p=>p[1])));
    const TOP=19.2;S.prism(fp,0.3,TOP,K.wall,K.flat);
    // each side: plinth, glazed ground floor between piers, five floors of window bands between white piers,
    // white cornice. The diagonal corner is the entrance (below)
    for(let i=0;i<P.length;i++){const a=P[i],b=P[(i+1)%P.length],du=b[0]-a[0],dv=b[1]-a[1],L=Math.hypot(du,dv),out=[dv/L,-du/L];
      const w=WL(a,b,out),w2=WL(a,b,out,.09),w3=WL(a,b,out,.12);if(i===2)continue;
      rect(w2,0,L,TOP-.6,TOP,K.rim);rect(w,0,L,0.3,0.8,K.flat);
      const n=Math.max(1,Math.round(L/4)),d=L/n;
      for(let k=0;k<n;k++)rect(w,k*d+.4,(k+1)*d-.4,0.8,3.6,K.glass2);
      rect(w2,0,L,4,4.4,K.rim);
      for(let f=0;f<5;f++){const h=4.4+f*2.96;rect(w,.5,L-.5,h+.7,h+2.1,K.glass);}
      const m=Math.max(1,Math.round(L/1.8)),e=(L-1)/m;for(let k=0;k<=m;k++){const s=.5+k*e;rect(w3,s-.22,s+.22,4.4,TOP-.6,K.rim);}}
    // cut corner on 5 Oriente and 3 Norte: a two-storey glass entrance with a canopy, the floors above set on it
    {const a=P[2],b=P[3],du=b[0]-a[0],dv=b[1]-a[1],L=Math.hypot(du,dv),out=[dv/L,-du/L],w=WL(a,b,out),w2=WL(a,b,out,.09),w3=WL(a,b,out,.12);
      rect(w,0,L,0.3,7.3,K.glass2);rect(w2,0,L,7.3,7.8,K.rim);for(let f=0;f<4;f++){const h=7.8+f*2.85;rect(w,.4,L-.4,h+.6,h+2,K.glass);}
      rect(w2,0,L,TOP-.6,TOP,K.rim);rect(w3,L/2-1.2,L/2+1.2,0.3,3,K.door);
      const o=2.2,q=[[a[0],a[1]],[b[0],b[1]],[b[0]+out[0]*o,b[1]+out[1]*o],[a[0]+out[0]*o,a[1]+out[1]*o]];S.prism(Gs(q),3.4,3.75,K.rim,K.rim);}
    // blue hipped roof (satellite) behind a low rim
    pyramid(S,fp,TOP,3,K.roof);
    const c=G(-1.5,-3);MODELS['juzgado-familia']={x:c[0],y:c[1],h:24};S.dy=0;}
