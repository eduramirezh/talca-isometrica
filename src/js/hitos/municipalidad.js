  // ==== hito: municipalidad ====
  // Municipalidad de Talca, 1 Norte 797, on the corner of 1 Oriente facing the plaza. Built on S. Plan from
  // OpenStreetMap: building w310186641 (25 × 25 m) and its forecourt w813330084 on 1 Norte; frame from the building's
  // west side (A 88.85°): u east, v north, the front at v = −12.45. Above the ground, from photos on Wikimedia Commons
  // (2018): a white modernist block of three floors raised on a terrace of rough grey stone with steps; a tall white
  // portal frames the glazed entrance and the window above it, a column of square windows each side; the top floor is
  // set back behind a ribbon of glass under a wide white eave with a wooden soffit; a hipped roof (light grey on the
  // satellite); a Canary palm and the flag in front. Approximate: the heights (~15 m to the eave, measured against the
  // front's width), the side and rear windows (no photos). On the plaza's level (MODELS[...].pad). Method: §9.
  {const F=localFrame(43.7,89.4,88.85*Math.PI/180),{G,R}=F,H=MODELS['plaza-de-armas'].pad;
    const K={white:C('#ECE9E2'),white2:C('#D9D5CB'),stone:C('#86827A'),stone2:C('#9A958B'),glass:C('#3B4653'),glass2:C('#2C3540'),
      door:C('#4D5D66'),roof:C('#C3C5C2'),step:C('#D9D3C5'),pave:C('#D3CABA'),band:C('#BFB4A2')};
    const {box,WU,WV,rect}=facade(S,F,K);
    occMark(R(-12.6,-12.5,12.6,12.5));occMark(R(-16,-21.5,15.8,-12.5));PADS.push([27.6,66,59.5,102.2,H]);S.dy=H;
    // forecourt: paving with darker bands, the stone terrace and its steps
    S.flat(R(-16,-21.5,15.8,-12.45),0.30,K.pave);for(let u=-14;u<15;u+=6)S.quadXY(R(u-.25,-21.5,u+.25,-12.45),0.33,K.band);
    box(-9.5,-15.6,9.5,-12.45,0.3,1.3,K.stone,K.stone2);
    box(1.5,-17.1,6.5,-16.4,0.3,0.6,K.step,K.step);box(1.5,-16.4,6.5,-15.6,0.3,0.95,K.step,K.step);
    // body: two floors of white wall over a stone plinth, the top floor set back behind a ribbon of glass
    box(-12.55,-12.45,12.55,12.45,-6,9.8,K.white,K.white);box(-11.6,-11.5,11.6,11.5,9.8,12.9,K.white2,K.white);
    const sides=[[o=>WV(-12.45,-1,o),-12.55,12.55],[o=>WU(12.55,1,o),-12.45,12.45],[o=>WV(12.45,1,o),-12.55,12.55],[o=>WU(-12.55,-1,o),-12.45,12.45]];
    const top=[o=>WV(-11.5,-1,o),o=>WU(11.6,1,o),o=>WV(11.5,1,o),o=>WU(-11.6,-1,o)];
    sides.forEach(([mk,s0,s1],i)=>{const w=mk(.06);rect(w,s0,s1,0.3,1.3,K.stone);
      for(let s=-10.8,k=0;s<10.7;s+=1.8,k++)rect(top[i](.06),s,s+1.8,10.2,12.5,k%2?K.glass2:K.glass);
      if(i===0)return;for(let s=s0+2.3;s<s1-1;s+=3.6)for(const h of [2.4,6.3]){rect(w,s-.95,s+.95,h-.2,h+2.2,K.white2);rect(mk(.12),s-.7,s+.7,h,h+2,K.glass);}});
    // the front: the portal (a white frame 0.4 m proud) round the doors and the window above, square windows each side
    box(-4.4,-12.85,4.4,-12.45,1.3,9.8,K.white,K.white);
    {const w=WV(-12.85,-1),wf=WV(-12.85,-1,.12);rect(w,-3.7,3.7,1.3,5.0,K.door);rect(wf,-3.7,3.7,5.0,5.6,K.white);rect(w,-3.7,3.7,5.6,9.2,K.glass);
      for(const u of [-1.2,1.2])rect(wf,u-.15,u+.15,5.6,9.2,K.white);
      const ws=WV(-12.45,-1),wsf=WV(-12.45,-1,.12);for(const u of [-8.4,8.4])for(const h of [2.4,6.3]){rect(ws,u-1.1,u+1.1,h-.25,h+2.25,K.white2);rect(wsf,u-.8,u+.8,h,h+2,K.glass);}}
    // eave: a white band all round, wider than the walls, and a hipped roof
    S.prism(R(-14.2,-14.1,14.2,14.1),12.9,14.5,K.white,K.white,false);pyramid(S,R(-14.2,-14.1,14.2,14.1),14.5,2.4,K.roof);
    {const g=G(0.8,-16.6);palmS(g[0],g[1],12.5,.3);}
    {const g=G(-7.4,-14.2);flagS(g[0],g[1],1.3,10.5);}
    MODELS.municipalidad={x:43.7,y:89.4,h:18};S.dy=0;}
