  // ==== hito: cruces ====
  // The furniture of the junctions measured in photos (config/cruces.json -> pipeline/perfiles.py -> DATA.cruces; today
  // Las Rastras with San Miguel), what an art pixel of 0.5 m can show: the Canary palms (a fan palm, a thinner one), the
  // billboards on their steel legs, the brand banners and the fences along the corners (hedge, wall, boards, a green
  // mesh as a pale screen). The ground is 12-perfiles.js's; signals, poles, cables, signs and railings, under a pixel,
  // are the 3D's (modelo3d/modelos/entorno/cruce.gd). Each object stands on E() at its foot (no pads here).
  {const K={...KH,leg:C('#A9ADB0'),frame:C('#4A4C4E'),red:C('#C8402F')};
    for(const k in DATA.cruces||{})for(const o of DATA.cruces[k].objetos){const [t]=o;
      if(t==='cerco'){const [,forma,alto,col,r]=o;if(forma==='tubo'||forma==='defensa')continue;
        const c=C('#'+col),w=forma==='seto'?.8:.3,top=forma==='malla'?shade(c,1.25):c;
        for(let i=0;i+3<r.length;i+=2){const ax=r[i],ay=r[i+1],bx=r[i+2],by=r[i+3],L=Math.hypot(bx-ax,by-ay);if(L<.05)continue;
          S.dy=Math.min(E(ax,ay),E(bx,by));S.prism(rotRect((ax+bx)/2,(ay+by)/2,L,w,Math.atan2(by-ay,bx-ax)),0.3,0.27+alto,top,top);}
        continue;}
      const [,x,y,a,q]=o;if(!inTerrain(x,y))continue;S.dy=E(x,y);
      if(t==='palmera'){const h=(q.alto||12)*(q.forma==='abanico'?.85:1)-1;palmS(x,y,h,a);}
      else if(t==='letrero'){const W=q.ancho||4,H=q.alto||2.5,b=q.base||3,c0=C('#'+(q.colores||['e8e4da'])[0]),c1=C('#'+((q.colores||[])[1]||'4a4c4e'));
        const u=[-Math.sin(a),Math.cos(a)],legs=W>3?[-W*.3,W*.3]:[0];
        for(const l of legs)S.prism(rotRect(x+u[0]*l,y+u[1]*l,.4,.4,a),0.3,b+.2,q.pie==='rojo'?K.red:K.leg,K.leg);
        S.prism(rotRect(x,y,.4,W,a),b,b+H*.28,c1,K.frame);S.prism(rotRect(x,y,.4,W,a),b+H*.28,b+H,c0,K.frame);}
      else if(t==='bandera'){S.prism(rotRect(x+Math.cos(a)*.45,y+Math.sin(a)*.45,.9,.3,a+Math.PI/2),(q.alto||6)-3,(q.alto||6)-.2,C('#'+(q.color||'2e8b3e')),C('#'+(q.color||'2e8b3e')));}}
    S.dy=0;}
