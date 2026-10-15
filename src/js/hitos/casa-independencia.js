  // ==== hito: casa-independencia ====
  // Casa de la Independencia (Museo O'Higginiano y de Bellas Artes), 1 Norte 875 at 2 Oriente: a one-storey colonial
  // house round two courtyards, built on S. Plan from OpenStreetMap w214849869 (the outline, with the recesses on its
  // west side and the annex to the north-west); the courtyards and the wings between them from the Esri imagery (the
  // outline has no holes). Frame: origin at the south-west corner, u along 1 Norte (A 90.92°), v north. Above the
  // ground, from a photo on Wikimedia Commons of the 2 Oriente side (2022): oxblood walls with a darker plinth,
  // barred windows and plank doors, clay-tile roofs on exposed rafters (the dark band under the eaves). Hipped roofs
  // as on the imagery. Approximate: the wings' widths (±1 m), the eave height (~4.4 m), the 1 Norte front and the
  // courtyard walls (no photos: the side's rhythm), the trees in the courtyards. Method: docs/METODOLOGIA.md §9.
  {const F=localFrame(147.1,70.5,90.92*Math.PI/180),{G,Gs,V,N3,R}=F;
    const K={wall:C('#A23B32'),wall2:C('#8F332B'),plinth:C('#7A2B25'),rafter:C('#4A2E26'),tile:C('#AE6446'),tile2:C('#97573D'),
      vano:C('#2E2C2B'),door:C('#4A3426'),patio:C('#CDBB9C'),grass:C('#6E9A48'),trunk:C('#6E5B48'),leaf:C('#5A8A3E'),leaf2:C('#4C7835')};
    const {box,WU,WV,rect}=facade(S,F,K);
    const fp=[[147.1,70.5],[184.3,71.1],[183.7,113.5],[163.1,113.2],[162.9,125],[147.2,124.8],[147.3,114.6],[152.6,114.7],[152.8,98.8],
      [147.6,98.8],[147.8,85.3],[153.8,85.4],[153.8,80],[146.9,79.9]];
    occMark(fp);S.dy=padAt(146.9,70.5,184.3,125);
    // hipped roof over a rectangle: eaves o m out and k·o lower, ridge along the longer side, the long slopes in one
    // tone and the hips in the other
    const hip=(u0,v0,u1,v1,h,k=.47,o=.6)=>{u0-=o;v0-=o;u1+=o;v1+=o;const w=u1-u0,d=v1-v0,r=Math.min(w,d)/2,t=h+r*k-o*k,e=h-o*k,um=(u0+u1)/2,vm=(v0+v1)/2;
      const f=(q,c)=>S.face(q,null,c);
      if(w>=d){const a=V(u0+r,vm,t),b=V(u1-r,vm,t);f([V(u0,v0,e),V(u1,v0,e),b,a],K.tile);f([V(u1,v1,e),V(u0,v1,e),a,b],K.tile);
        f([V(u0,v1,e),V(u0,v0,e),a],K.tile2);f([V(u1,v0,e),V(u1,v1,e),b],K.tile2);}
      else{const a=V(um,v0+r,t),b=V(um,v1-r,t);f([V(u0,v1,e),V(u0,v0,e),a,b],K.tile);f([V(u1,v0,e),V(u1,v1,e),b,a],K.tile);
        f([V(u0,v0,e),V(u1,v0,e),a],K.tile2);f([V(u1,v1,e),V(u0,v1,e),b],K.tile2);}};
    // wings round the south courtyard (u 11.5–27, v 8.3–20.5) and the north one (u 15–30.5, v 26–38.8); walls to 4.4 m
    const HW=4.4,wings=[[0,0,37.2,8.3],[0,8.3,11.5,20.5],[27,8.3,37.2,20.5],[0,20.5,37.2,26],[5.6,26,15,42.7],[30.5,26,37.2,42.7],[15,38.8,30.5,42.7]];
    // walls (the west wing's walls step back round the recess on its outer side, OSM), then the roofs
    for(const [u0,v0,u1,v1] of wings)if(u0||v0!==8.3)box(u0,v0,u1,v1,0.3,HW,K.wall,K.wall,false);
    for(const [u0,v0,u1,v1] of [[0,8.3,11.5,9.4],[6.7,9.4,11.5,14.9],[0,14.9,11.5,20.5],[0.6,26,5.6,28.3]])box(u0,v0,u1,v1,0.3,HW,K.wall,K.wall,false);
    box(0.1,42.7,15.9,54.3,0.3,4.0,K.wall2,K.wall2,false);
    for(const [u0,v0,u1,v1] of wings)hip(u0,v0,u1,v1,HW);hip(0.1,42.7,15.9,54.3,4.0);
    // courtyards: brick paving and a tree in the south one, lawn and trees in the north one (trees as on the imagery)
    S.flat(R(11.5,8.3,27,20.5),0.32,K.patio);S.flat(R(15,26,30.5,38.8),0.32,K.grass);S.flat(R(21.8,26,23.8,38.8),0.35,K.patio);
    const tree=(u,v,s)=>{const g=G(u,v);S.prism(ngon(g[0],g[1],.35,6),0.3,2.6*s,K.trunk,K.trunk);
      S.prism(ngon(g[0],g[1],2.4*s,8,Math.PI/8),2.6*s,5*s,K.leaf2,K.leaf);pyramid(S,ngon(g[0],g[1],2.4*s,8,Math.PI/8),5*s,1.6*s,K.leaf);};
    tree(19.5,14.5,1);tree(18.5,32,1.15);tree(27,34.5,1);
    // outside walls: plinth, the rafters' shadow under the eaves, barred windows and plank doors
    const outer=[[o=>WV(0,-1,o),0,37.2],[o=>WU(37.2,1,o),0,42.7],[o=>WV(42.7,1,o),15.9,37.2],[o=>WU(0,-1,o),0,9.4],[o=>WV(54.3,1,o),0.1,15.9]];
    for(const [mk,s0,s1] of outer){const w=mk(.06);rect(w,s0,s1,0.3,0.8,K.plinth);rect(mk(.09),s0,s1,3.95,HW,K.rafter);}
    {const w=WV(0,-1),wd=WV(0,-1,.12);for(const u of [3.5,8,12.5,24.7,29.2,33.7])rect(w,u-.55,u+.55,1.2,3.0,K.vano);
      rect(wd,17.3,19.9,0.3,3.3,K.door);rect(w,16.9,20.3,3.3,3.6,K.plinth);}
    {const w=WU(37.2,1),wd=WU(37.2,1,.12);for(const v of [3.5,8,12.5,17,21.5,26,30.5])rect(w,v-.55,v+.55,1.2,3.0,K.vano);
      for(const v of [34.2,36.4])rect(w,v-.4,v+.4,2.2,3.0,K.vano);rect(wd,38.6,40.4,0.3,3.2,K.door);}
    // courtyard walls: doors along the galleries
    for(const [mk,s0,s1] of [[o=>WV(8.3,1,o),11.5,27],[o=>WV(20.5,-1,o),11.5,27],[o=>WU(11.5,1,o),8.3,20.5],[o=>WU(27,-1,o),8.3,20.5],
      [o=>WV(26,1,o),15,30.5],[o=>WV(38.8,-1,o),15,30.5],[o=>WU(15,1,o),26,38.8],[o=>WU(30.5,-1,o),26,38.8]]){const w=mk(.06);
      rect(w,s0,s1,0.3,0.8,K.plinth);for(let s=s0+2.5;s<s1-1.5;s+=4)rect(mk(.12),s-.6,s+.6,0.3,2.8,K.door);}
    const c=G(18.6,21.4);MODELS['casa-independencia']={x:c[0],y:c[1],h:9};S.dy=0;}
