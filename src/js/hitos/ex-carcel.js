  // ==== hito: ex-carcel ====
  // Ex Cárcel Pública de Talca (CCP Talca, 4 Norte 550; the clinic at 520 is part of it), the whole block between
  // 3 and 4 Norte, 2 and 3 Poniente; built on S. There has been a prison here since 1864; the present compound was
  // rebuilt in reinforced concrete after the 1928 earthquake (1930, architect Luis Nieto), got two cell pavilions in
  // 1953 (likely the two long two-storey ones) and later works (Municipalidad de Talca, «Origen y evolución de la
  // Cárcel Pública en Talca»). It was still in use in 2024–2025; with La Laguna open (2025) the State has said it will
  // release the site for a civic centre. Nothing is demolished: this is the compound as it stands in Google Street
  // View (2013, 2024) and current Google and Esri imagery. Plan from OpenStreetMap (prison w111123020, buildings
  // w952226028–37), in the frame of landmark.py frame ex-carcel 111123020 (v north, u east), clipped to the map's
  // block. What is seen: a 7.5 m concrete perimeter wall painted cream with pilasters and coiled wire on top, guard
  // towers at the corners (SW on a chamfer, SE darker), the one-storey Gendarmería-green front on the Alameda with a
  // taller entrance block and hipped roofs, a barrel-vaulted hall, the two-storey pavilions, a hipped ring around a
  // court, a covered court with a blue roof, sheds and yards. Approximate: the NE and NW towers (not seen), the
  // entrance block's place along the front, the sheds on the west side (not in OSM), heights (OSM levels). The
  // towers' night lights are licence. Method: docs/METODOLOGIA.md §9.
  {const F=localFrame(-253.1,409.9,89.2*Math.PI/180),{G,Gs,V,N3,R}=F;
    const K={wall:C('#D5C79E'),pil:C('#BDB6A3'),wire:C('#4A4C4E'),tower:C('#B7B2A6'),tower2:C('#5A5E62'),win:C('#3B4653'),
      green:C('#7DB85C'),green2:C('#4F8545'),upper:C('#AEB8A8'),white:C('#ECE7DC'),door:C('#4A3F3A'),
      tile:C('#B6BBBA'),tile2:C('#A5AAA9'),rust:C('#94634A'),rust2:C('#835841'),metal:C('#9EA3A3'),metal2:C('#8D9292'),
      blue:C('#8FAEC4'),blue2:C('#7F9EB5'),conc:C('#CFC8B8'),yard:C('#CDBF9F'),pave:C('#BDB7AB'),gable:C('#CFC8B8')};
    const {box,WL,WV,WU,rect}=facade(S,F,K);
    const U0=-49.5,U1=53,V0=-58,VN=38.5,VF=61; // walls west/east/south/north; the frontage runs to the sidewalk
    const site=Gs([[U0,V0],[U1,V0],[U1,VF],[U0,VF]]);
    occMark(site);NOLOTS.push(site);
    S.dy=padAt(Math.min(...site.map(p=>p[0])),Math.min(...site.map(p=>p[1])),Math.max(...site.map(p=>p[0])),Math.max(...site.map(p=>p[1])));
    // hipped roof over an axis-aligned (u,v) rectangle, eaves at h, ridge rh higher, in two tones
    const hip=(u0,v0,u1,v1,h,rh,c1,c2)=>{const o=.4;u0-=o;v0-=o;u1+=o;v1+=o;const h0=h-.25;
      if(u1-u0>=v1-v0){const d=(v1-v0)/2,vm=(v0+v1)/2;
        S.face([V(u0,v0,h0),V(u1,v0,h0),V(u1-d,vm,h+rh),V(u0+d,vm,h+rh)],null,c1);S.face([V(u1,v1,h0),V(u0,v1,h0),V(u0+d,vm,h+rh),V(u1-d,vm,h+rh)],null,c1);
        S.face([V(u0,v1,h0),V(u0,v0,h0),V(u0+d,vm,h+rh)],null,c2);S.face([V(u1,v0,h0),V(u1,v1,h0),V(u1-d,vm,h+rh)],null,c2);}
      else{const d=(u1-u0)/2,um=(u0+u1)/2;
        S.face([V(u0,v1,h0),V(u0,v0,h0),V(um,v0+d,h+rh),V(um,v1-d,h+rh)],null,c1);S.face([V(u1,v0,h0),V(u1,v1,h0),V(um,v1-d,h+rh),V(um,v0+d,h+rh)],null,c1);
        S.face([V(u0,v0,h0),V(u1,v0,h0),V(um,v0+d,h+rh)],null,c2);S.face([V(u1,v1,h0),V(u0,v1,h0),V(um,v1-d,h+rh)],null,c2);}};
    // gable roof with the ridge along v (sheds and pavilions): bays in two tones, gable ends in concrete
    const shed=(u0,v0,u1,v1,h,rh,c1,c2)=>{const um=(u0+u1)/2,o=.4;for(let v=v0,k=0;v<v1-1e-6;v+=6,k++){const e=Math.min(v+6,v1),c=k%2?c2:c1;
        S.face([V(u0-o,v,h-.2),V(u0-o,e,h-.2),V(um,e,h+rh),V(um,v,h+rh)],null,c);S.face([V(u1+o,e,h-.2),V(u1+o,v,h-.2),V(um,v,h+rh),V(um,e,h+rh)],null,c);}
      S.face([V(u0,v0,h),V(u1,v0,h),V(um,v0,h+rh)],N3(0,-1),K.gable);S.face([V(u1,v1,h),V(u0,v1,h),V(um,v1,h+rh)],N3(0,1),K.gable);};
    // the yards inside the wall, the parking strip in front
    S.quadXY(R(U0,V0,U1,57),0.32,K.yard);S.quadXY(R(U0,57,U1,VF),0.32,K.pave);
    // perimeter wall: cream, pilasters every ~8 m outside, coiled wire on top; the SW corner is chamfered
    const CH=5,T=.8,HW=7.5,ring=[[U0,V0+CH],[U0+CH,V0],[U1,V0],[U1,VN],[U0,VN]];
    for(let i=0;i<ring.length;i++){const a=ring[i],b=ring[(i+1)%ring.length],L=Math.hypot(b[0]-a[0],b[1]-a[1]),du=(b[0]-a[0])/L,dv=(b[1]-a[1])/L,nu=dv,nv=-du;
      const q=[[a[0],a[1]],[b[0],b[1]],[b[0]-nu*T,b[1]-nv*T],[a[0]-nu*T,a[1]-nv*T]];S.prism(Gs(q),0.3,HW,K.wall,K.pil);
      const qw=[[a[0]-nu*.1,a[1]-nv*.1],[b[0]-nu*.1,b[1]-nv*.1],[b[0]-nu*(T-.1),b[1]-nv*(T-.1)],[a[0]-nu*(T-.1),a[1]-nv*(T-.1)]];S.prism(Gs(qw),HW,HW+.45,K.wire,K.wire);
      if(i===4)continue; // the north side stands behind the front buildings
      const w=WL(a,b,[nu,nv],.25);const n=Math.max(1,Math.round(L/8));for(let k=1;k<n;k++){const s=k*L/n;rect(w,s-.45,s+.45,0.3,HW,K.pil);}
      rect(WL(a,b,[nu,nv],.06),0,L,0.3,1.0,K.pil);}
    // guard towers: a shaft, a cabin with a band of windows, a hipped cap
    const tower=(u,v,sh)=>{box(u-1.7,v-1.7,u+1.7,v+1.7,0.3,8.2,sh,sh);box(u-1.5,v-1.5,u+1.5,v+1.5,8.2,10.6,K.tower,K.tower);
      for(const [sg,ax] of [[-1,'v'],[1,'v'],[-1,'u'],[1,'u']]){const w=ax==='v'?WV(v+sg*1.5,sg):WU(u+sg*1.5,sg);rect(w,(ax==='v'?u:v)-1.1,(ax==='v'?u:v)+1.1,8.9,10,K.win);}
      pyramid(S,R(u-1.9,v-1.9,u+1.9,v+1.9),10.6,1.4,K.metal2);const g=G(u,v);GLOW.push(g[0],S.dy+11,g[1]);};
    tower(U0+2.2,V0+2.2,K.tower);tower(U1-1.2,V0+1.2,K.tower2);tower(U1-1.2,VN-1.2,K.tower);tower(U0+1.2,VN-1.2,K.tower);
    // front on the Alameda: one storey in Gendarmería green with a dark plinth, framed barred windows, hipped roofs;
    // the entrance block stands two storeys, its upper floor grey-green, with three tall bays and a stepped cornice
    const front=(u0,v0,u1,v1,h,roof,roof2)=>{box(u0,v0,u1,v1,0.3,h,K.green,roof,false);hip(u0,v0,u1,v1,h,1.6,roof,roof2);
      const w=WV(v1,1);rect(w,u0,u1,0.3,1.1,K.green2);rect(WV(v1,1,.09),u0,u1,h-.4,h,K.white);
      for(let u=u0+2.2;u<u1-1.5;u+=3.6){rect(WV(v1,1,.09),u-.95,u+.95,1.5,3.1,K.white);rect(WV(v1,1,.12),u-.75,u+.75,1.7,2.9,K.win);}
      for(const [x,sg] of [[u0,-1],[u1,1]]){rect(WU(x,sg),v0,v1,0.3,1.1,K.green2);rect(WU(x,sg,.09),v0,v1,h-.4,h,K.white);}};
    front(U0,43,-33,57,4.4,K.rust,K.rust2);front(-32,44,6,57,4.6,K.tile,K.tile2);front(10,43,21,50,4.2,K.tile,K.tile2);
    front(21,41,51,55,4.2,K.tile,K.tile2);box(-6,40,6,44,0.3,4.6,K.green,K.metal);
    {const u0=-19,u1=-7,v0=51,v1=57.6;box(u0,v0,u1,v1,0.3,8.2,K.green,K.metal);box(u0-.3,v0-.3,u1+.3,v1+.3,8.2,8.7,K.white,K.white);
      box(u0+1,v1-1,u1-1,v1+.2,8.7,9.2,K.white,K.white);
      const w=WV(v1,1),w2=WV(v1,1,.09),w3=WV(v1,1,.12);rect(w,u0,u1,4.6,8.2,K.upper);rect(w,u0,u1,0.3,1.1,K.green2);
      for(const [a,b] of [[u0+1,u0+3.6],[u0+4.7,u1-4.7],[u1-3.6,u1-1]]){rect(w2,a-.3,b+.3,0.3,6.6,K.white);rect(w3,a,b,0.3,6.3,K.door);}
      for(const u of [u0+2.3,(u0+u1)/2,u1-2.3])rect(w3,u-.6,u+.6,7,7.9,K.win);
      for(const [x,sg] of [[u0,-1],[u1,1]])rect(WU(x,sg),v0,v1,4.6,8.2,K.upper);
      for(const u of [u0+1.4,u1-1.4])box(u-.2,v1+.6,u+.2,v1+1,0.3,9.5,K.pil,K.pil);}
    // inside: the barrel-vaulted hall (OSM 028) with its lower foot to the south-west
    {const u0=-26,u1=-14,v0=-22,v1=34,h=5.5,r=(u1-u0)/2,um=(u0+u1)/2;box(u0,v0,u1,v1,0.3,h,K.conc,K.conc,false);
      const arc=[];for(let i=0;i<=8;i++){const t=Math.PI*i/8;arc.push([um-r*Math.cos(t),h+3.6*Math.sin(t)]);}
      for(let i=0;i<8;i++){const [ua,ha]=arc[i],[ub,hb]=arc[i+1];S.face([V(ua,v0,ha),V(ua,v1,ha),V(ub,v1,hb),V(ub,v0,hb)],null,i%2?K.metal2:K.metal);}
      for(const [v,sg] of [[v0,-1],[v1,1]])S.face(arc.map(([u,hh])=>V(u,v,hh)),N3(0,sg),K.conc);
      for(const u of [u0,u1])for(let v=v0+3;v<v1-2;v+=4)rect(WU(u,u===u0?-1:1,.06),v-.8,v+.8,2.4,4.4,K.win);
      box(-48,-36,-13,-22,0.3,4,K.conc,K.metal);}
    // sheds along the west wall (imagery, not in OSM), the south block (031), the pavilions (029, 030)
    box(-47.5,-20,-28,8,0.3,4,K.conc,K.metal,false);shed(-47.5,-20,-28,8,4,1.2,K.rust,K.rust2);
    box(-47.5,10,-28,36,0.3,4,K.conc,K.tile,false);shed(-47.5,10,-28,36,4,1.2,K.tile,K.tile2);
    box(-45,-50,-5,-36.5,0.3,3.8,K.conc,K.metal);
    for(const [u0,u1,c1,c2] of [[-4.7,4.5,K.rust,K.rust2],[4.5,19.6,K.metal,K.metal2]]){const v0=u0<0?-49.5:-49,v1=u0<0?-11.5:4;
      box(u0,v0,u1,v1,0.3,7,K.conc,K.conc,false);shed(u0,v0,u1,v1,7,1.4,c1,c2);
      for(const [u,sg] of [[u0,-1],[u1,1]])for(let v=v0+2.5;v<v1-1.5;v+=3.5)for(const f of [1.8,4.8])rect(WU(u,sg),v-.6,v+.6,f,f+1.1,K.win);}
    // the hipped ring around a court (032), the covered court (033) and the east shed (034)
    box(-2,23,26,38,0.3,4.5,K.conc,K.tile,false);hip(-2,23,26,38,4.5,2,K.tile,K.tile2);
    box(16,9,26,23,0.3,4.5,K.conc,K.tile,false);hip(16,9,26,23,4.5,2,K.tile,K.tile2);
    box(28,8,46,36,0.3,6,K.conc,K.blue,false);shed(28,8,46,36,6,1.2,K.blue,K.blue2);
    box(29,-29,48,6.5,0.3,5,K.conc,K.metal,false);shed(29,-29,48,6.5,5,1.3,K.metal,K.metal2);
    const c=G(2,-8);MODELS['ex-carcel']={x:c[0],y:c[1],h:12};S.dy=0;}
