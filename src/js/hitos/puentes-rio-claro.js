  // ==== hito: puentes-rio-claro ====
  // The two bridges over the Río Claro at the Alameda's west end, on S in grid metres. The Ruta K-60-J bridge (OSM
  // w111133067, from 4 Norte's end to the west bank; the map's street of that name between the same points stays off
  // the ground, s.bridge) and, 20 m south of it, the old bridge, closed (w203105753, w733122936 and w255707859,
  // bridge=abandoned; OSM leaves out 17 m over the west channel and so does the model, the cause is not documented).
  // From photos on Wikimedia Commons (2005, public domain; 2013, CC BY 2.0): the new one, a concrete deck with
  // sidewalks, parapets with red reflector posts and lamps with curved arms, on paired columns under a cap; the old one,
  // narrower, a balustrade on deep beams over wall piers. Approximate: the decks' heights (straight between the banks,
  // never under the terrain plus 0.3 m; the relief is exaggerated), the piers' spacing (25 and 20 m), the lamps' (35 m).
  // The new bridge's lamps glow (it is a lit road); the old one has none.
  {const K={asph:C('#57534F'),walk:C('#C9C3B6'),beam:C('#B3AEA4'),par:C('#D9D3C5'),red:C('#C8503A'),metal:C('#707070'),lamp:C('#F1E6C4'),
      old:C('#BDB8AD'),old2:C('#8F8A82'),oldBeam:C('#9C978E')};
    const Q=a=>{const o=[];for(let i=0;i<a.length;i+=2)o.push([a[i],a[i+1]]);return o;};
    const bridge=(pts,hw,hAt,o)=>deckBridge(S,K,pts,hw,hAt,o);
    // the Ruta K-60-J bridge, 13 m (the map's carriageway): 9 m of road, sidewalks, parapets
    {const a=[-1806.5,529],b=[-1349,540.5],ha=E(...a)+.144,hb=E(...b)+.144,L=Math.hypot(b[0]-a[0],b[1]-a[1]);
      streets.forEach(s=>{if(s.name==='Ruta K-60-J'&&s.pts.length===2&&Math.hypot(s.pts[0][0]-a[0],s.pts[0][1]-a[1])<4&&Math.hypot(s.pts[1][0]-b[0],s.pts[1][1]-b[1])<4)s.bridge=true;});
      bridge([a,b],6.5,p=>ha+(hb-ha)*Math.hypot(p.x-a[0],p.y-a[1])/L,{walk:4.5,beamD:1.4,beamCol:K.beam,pier:25,lamps:true});}
    // the old bridge, 8 m, in two parts on either side of the gap
    {const a=[-1809,516],b=[-1471.5,509],ha=E(...a)+.14,hb=E(...b)+.14,hAt=p=>ha+(hb-ha)*(p.x-a[0])/(b[0]-a[0]);
      bridge(Q([-1809,516,-1775.5,512.5,-1689.5,511]),4,hAt,{deck:K.old,balus:true,beamD:1.8,beamCol:K.oldBeam,pier:20});
      bridge(Q([-1672.5,510.5,-1631,510.5,-1471.5,509]),4,hAt,{deck:K.old,balus:true,beamD:1.8,beamCol:K.oldBeam,pier:20});}
    S.dy=0;}
