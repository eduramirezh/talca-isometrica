  // ==== hito: memorial-firma ====
  // Memorial Firma de la Independencia (Pamela Galleguillos, 2016; OSM node 7597212247), in the Municipalidad's
  // forecourt by the palm: a life-size bronze O'Higgins standing at a table with turned legs, leaning over the act with
  // a quill (photo on Wikimedia Commons, 2017). At this scale it is a few pixels: the table's stone top, the figure
  // leaning east over it. On the plaza's level (MODELS[...].pad), on the forecourt the Municipalidad paves.
  {const H=MODELS['plaza-de-armas'].pad,x=44.9,y=71.7,bz=C('#8A6A48'),bz2=C('#6F5439'),top=C('#A8A69E');S.dy=H;
    for(const [dx,dy] of [[-.45,-.25],[.45,-.25],[-.45,.25],[.45,.25]])S.prism(rotRect(x+.3+dx,y+dy,.18,.18),0.3,0.95,bz,bz);
    S.prism(rotRect(x+.3,y,1.3,.75),0.95,1.08,top,top);
    S.prism(rotRect(x-.7,y,.45,.4),0.3,1.0,bz2,bz2);S.prism(rotRect(x-.55,y,.5,.45),1.0,1.55,bz,bz);S.prism(rotRect(x-.3,y,.3,.3),1.42,1.75,bz,bz);
    MODELS['memorial-firma']={x,y,h:3};S.dy=0;}
