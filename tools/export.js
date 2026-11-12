// tools/export.py inyecta este archivo en la página cargada con window.__KEEP (las mallas conservan sus arreglos) y
// llama a __exGeom (las mallas de una caja, para el glTF) o a __exHeight (la altura máxima de todo lo dibujado, para
// el STL). No es parte del sitio: usa lo que la página expone en window.__three y window.__export.
(() => {
  const T = THREE, X = window.__export, scene = window.__three.scene;
  // Las mallas de la escena: cada una con su capa (el nombre del grupo más cercano: suelo, edificios, arboles…; otros
  // si no tiene), sin las franjas (dibujan lo mismo que sus teselas), los puntos de luz ni el anillo de selección.
  // Los árboles y autos instanciados, con la geometría de cerca (userData.lod[0]).
  function meshes(skip) {
    scene.updateMatrixWorld(true);
    const out = [];
    const walk = (o, cat) => {
      if (o.name) { cat = o.name; if (skip.has(cat)) return; }
      if (o.isMesh && !o.userData.strip && !(o.material && o.material.isMeshBasicMaterial)) {
        const geo = o.isInstancedMesh && o.userData.lod ? o.userData.lod[0] : o.geometry;
        if (geo && geo.attributes.position && geo.attributes.position.array) out.push({ o, geo, cat, win: o.material === X.matBld });
      }
      for (const c of o.children) walk(c, cat);
    };
    walk(scene, 'otros');
    return out;
  }
  // los triángulos de una malla en el mundo: cb(índices de vértice a, b, c) sobre su drawRange; cada instancia con su
  // matriz (inst(i) la pone en m antes de sus triángulos)
  function tris(geo, cb) {
    const I = geo.index ? geo.index.array : null, n = I ? I.length : geo.attributes.position.count;
    const s = Math.max(0, geo.drawRange.start), e = Math.min(n, s + (isFinite(geo.drawRange.count) ? geo.drawRange.count : n));
    for (let t = s - s % 3; t + 2 < e; t += 3) I ? cb(I[t], I[t + 1], I[t + 2]) : cb(t, t + 1, t + 2);
  }
  const srgb = c => c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
  const b64 = a => { const u = new Uint8Array(a.buffer, a.byteOffset, a.byteLength); let s = '';
    for (let i = 0; i < u.length; i += 0x8000) s += String.fromCharCode.apply(null, u.subarray(i, i + 0x8000)); return btoa(s); };
  class Out { // un acumulador que crece: Float32 o Uint32
    constructor(C) { this.C = C; this.a = new C(1 << 16); this.n = 0; }
    push(...v) { if (this.n + v.length > this.a.length) { const b = new this.C(this.a.length * 2 + v.length); b.set(this.a); this.a = b; }
      for (const x of v) this.a[this.n++] = x; }
    get v() { return this.a.subarray(0, this.n); } }

  // __exGeom([x0,y0,x1,y1], {skip}): por capa, posiciones, normales, colores (lineales, como pide glTF: la página dibuja
  // los suyos tal cual en la pantalla, que es sRGB) e índices. Los triángulos que cruzan el borde de la caja se cortan
  // en él (Sutherland–Hodgman, interpolando normal y color); un árbol o auto entra entero si su centro cae en la caja.
  window.__exGeom = (box, o = {}) => {
    const [x0, y0, x1, y1] = box, skip = new Set(o.skip || []), layers = {};
    const L = (cat, win) => layers[cat] || (layers[cat] = { P: new Out(Float32Array), N: new Out(Float32Array), C: new Out(Float32Array), I: new Out(Uint32Array), nv: 0, win });
    const m = new T.Matrix4(), mi = new T.Matrix4(), nm = new T.Matrix3(), v = new T.Vector3(), w = new T.Vector3(), col = new T.Color();
    let ntri = 0;
    const sph = new T.Sphere();
    for (const { o: obj, geo, cat, win } of meshes(skip)) {
      // una tesela de la página que no toca la caja (su esfera; los instanciados la tienen alrededor de sus instancias)
      if (geo.boundingSphere) { sph.copy(geo.boundingSphere).applyMatrix4(obj.matrixWorld); const c = sph.center, r = sph.radius;
        if (c.x + r < x0 || c.x - r > x1 || -c.z + r < y0 || -c.z - r > y1) continue; }
      const A = geo.attributes, P = A.position.array, N = A.normal && A.normal.array, Cc = A.color && A.color.array;
      const nN = A.normal && A.normal.normalized ? (N instanceof Int8Array ? 127 : 32767) : 1;
      const nC = A.color && A.color.normalized ? (Cc instanceof Uint8Array ? 255 : 65535) : 1;
      const lay = L(cat, win);
      const count = obj.isInstancedMesh ? obj.count : 1;
      for (let i = 0; i < count; i++) {
        let tint = [1, 1, 1];
        if (obj.isInstancedMesh) {
          if (!obj.instanceMatrix.array) continue;
          mi.fromArray(obj.instanceMatrix.array, i * 16); m.multiplyMatrices(obj.matrixWorld, mi);
          const e = m.elements; if (e[12] < x0 || e[12] >= x1 || -e[14] < y0 || -e[14] >= y1) continue;
          if (obj.instanceColor && obj.instanceColor.array) tint = Array.from(obj.instanceColor.array.subarray(i * 3, i * 3 + 3));
        } else m.copy(obj.matrixWorld);
        const ident = m.equals(new T.Matrix4());
        nm.getNormalMatrix(m);
        // el vértice k de la malla en el mundo: [x, y, z, nx, ny, nz, r, g, b]
        const vert = k => {
          v.set(P[3 * k], P[3 * k + 1], P[3 * k + 2]); if (!ident) v.applyMatrix4(m);
          if (N) { w.set(N[3 * k] / nN, N[3 * k + 1] / nN, N[3 * k + 2] / nN); if (!ident) w.applyMatrix3(nm); w.normalize(); } else w.set(0, 1, 0);
          if (Cc) col.setRGB(Cc[3 * k] / nC * tint[0], Cc[3 * k + 1] / nC * tint[1], Cc[3 * k + 2] / nC * tint[2]); else col.setRGB(...tint);
          return [v.x, v.y, v.z, w.x, w.y, w.z, col.r, col.g, col.b];
        };
        const seen = new Map(); // vértices enteros ya escritos (los triángulos que no se cortan los comparten)
        const emit = q => { const l = Math.hypot(q[3], q[4], q[5]) || 1; lay.P.push(q[0], q[1], q[2]); lay.N.push(q[3] / l, q[4] / l, q[5] / l); lay.C.push(srgb(q[6]), srgb(q[7]), srgb(q[8])); return lay.nv++; };
        const keep = k => { let j = seen.get(k); if (j === undefined) { j = emit(vert(k)); seen.set(k, j); } return j; };
        // los planos de la caja en el mundo: x = X, y = -Z
        const planes = [q => q[0] - x0, q => x1 - q[0], q => -q[2] - y0, q => y1 + q[2]];
        tris(geo, (a, b, c) => {
          const va = vert(a), vb = vert(b), vc = vert(c);
          let inside = true;
          for (const f of planes) { const da = f(va), db = f(vb), dc = f(vc); if (da < 0 && db < 0 && dc < 0) return; if (da < 0 || db < 0 || dc < 0) inside = false; }
          if (obj.isInstancedMesh || inside) { lay.I.push(keep(a), keep(b), keep(c)); ntri++; return; }
          let poly = [va, vb, vc];
          for (const f of planes) {
            const nxt = [];
            for (let k = 0; k < poly.length; k++) {
              const p = poly[k], q = poly[(k + 1) % poly.length], dp = f(p), dq = f(q);
              if (dp >= 0) nxt.push(p);
              if ((dp >= 0) !== (dq >= 0)) { const t = dp / (dp - dq); nxt.push(p.map((x, j) => x + (q[j] - x) * t)); }
            }
            poly = nxt; if (poly.length < 3) return;
          }
          const ids = poly.map(emit);
          for (let k = 1; k + 1 < ids.length; k++) { lay.I.push(ids[0], ids[k], ids[k + 1]); ntri++; }
        });
      }
    }
    const res = { box, tris: ntri, layers: {} };
    // los arreglos quedan en la página: tools/export.py los pide por trozos (__exChunk), uno grande cortaba la conexión
    window.__exBuf = {};
    for (const [k, l] of Object.entries(layers)) if (l.I.n) {
      res.layers[k] = { win: l.win, nv: l.nv, ni: l.I.n };
      window.__exBuf[k] = { P: l.P.v, N: l.N.v, C: l.C.v, I: l.I.v };
    }
    // los lugares de la caja, para el JSON de al lado
    res.pois = X.PD.pois.filter(p => p.x >= x0 && p.x < x1 && p.y >= y0 && p.y < y1).map(p => ({ id: p.id, nombre: p.n, cat: p.c, lat: p.lat, lon: p.lon, x: p.x, y: p.y, h: +X.E(p.x, p.y).toFixed(2) }));
    return res;
  };

  // el trozo [o, o + n) en bytes del arreglo a de la capa k, en base64
  window.__exChunk = (k, a, o, n) => { const v = window.__exBuf[k][a]; return b64(new Uint8Array(v.buffer, v.byteOffset + o, Math.min(n, v.byteLength - o))); };
  window.__exLen = (k, a) => window.__exBuf[k][a].byteLength;

  // __exHeight([x0,y0,x1,y1], c, {skip}): la altura más alta de lo dibujado en cada nodo de una grilla de c metros
  // (nx+1 × ny+1, fila a fila desde y0), y si cada celda está en la comuna (inTerrain en su centro). Cada triángulo
  // marca los nodos que cubre con su altura ahí; sus aristas, los nodos por los que pasan (así cuentan los muros y lo
  // angosto). Un nodo sin nada (fuera de lo dibujado) toma el suelo E(x, y).
  window.__exHeight = (box, c, o = {}) => {
    const [x0, y0, x1, y1] = box, skip = new Set(o.skip || []);
    const nx = Math.round((x1 - x0) / c), ny = Math.round((y1 - y0) / c), W = nx + 1, H = new Float32Array(W * (ny + 1)).fill(-Infinity);
    const m = new T.Matrix4(), mi = new T.Matrix4(), v = new T.Vector3();
    const put = (i, j, h) => { if (i >= 0 && i <= nx && j >= 0 && j <= ny) { const k = j * W + i; if (h > H[k]) H[k] = h; } };
    let ntri = 0;
    for (const { o: obj, geo } of meshes(skip)) {
      const P = geo.attributes.position.array, count = obj.isInstancedMesh ? obj.count : 1;
      for (let n = 0; n < count; n++) {
        if (obj.isInstancedMesh) {
          if (!obj.instanceMatrix.array) continue;
          mi.fromArray(obj.instanceMatrix.array, n * 16); m.multiplyMatrices(obj.matrixWorld, mi);
          const e = m.elements; if (e[12] < x0 - 20 || e[12] > x1 + 20 || -e[14] < y0 - 20 || -e[14] > y1 + 20) continue;
        } else m.copy(obj.matrixWorld);
        const ident = m.equals(new T.Matrix4());
        // en coordenadas de la grilla de nodos: (i, j, h)
        const g = k => { v.set(P[3 * k], P[3 * k + 1], P[3 * k + 2]); if (!ident) v.applyMatrix4(m); return [(v.x - x0) / c, (-v.z - y0) / c, v.y]; };
        tris(geo, (a, b, cc) => {
          const A = g(a), B = g(b), C = g(cc);
          const i0 = Math.ceil(Math.min(A[0], B[0], C[0])), i1 = Math.floor(Math.max(A[0], B[0], C[0])), j0 = Math.ceil(Math.min(A[1], B[1], C[1])), j1 = Math.floor(Math.max(A[1], B[1], C[1]));
          if (i1 < -1 || i0 > nx + 1 || j1 < -1 || j0 > ny + 1) return;
          ntri++;
          const d = (B[0] - A[0]) * (C[1] - A[1]) - (C[0] - A[0]) * (B[1] - A[1]);
          if (Math.abs(d) > 1e-9) for (let j = Math.max(0, j0); j <= Math.min(ny, j1); j++) for (let i = Math.max(0, i0); i <= Math.min(nx, i1); i++) {
            const u = ((B[0] - i) * (C[1] - j) - (C[0] - i) * (B[1] - j)) / d, vv = ((C[0] - i) * (A[1] - j) - (A[0] - i) * (C[1] - j)) / d, ww = 1 - u - vv;
            if (u >= -1e-6 && vv >= -1e-6 && ww >= -1e-6) put(i, j, u * A[2] + vv * B[2] + ww * C[2]);
          }
          for (const [p, q] of [[A, B], [B, C], [C, A]]) {
            const L = Math.max(Math.abs(q[0] - p[0]), Math.abs(q[1] - p[1])), s = Math.max(1, Math.ceil(L * 2));
            for (let k = 0; k <= s; k++) { const t = k / s; put(Math.round(p[0] + (q[0] - p[0]) * t), Math.round(p[1] + (q[1] - p[1]) * t), p[2] + (q[2] - p[2]) * t); }
          }
        });
      }
    }
    for (let j = 0; j <= ny; j++) for (let i = 0; i <= nx; i++) { const k = j * W + i; if (H[k] === -Infinity) H[k] = X.E(x0 + i * c, y0 + j * c); }
    const M = new Uint8Array(nx * ny);
    for (let j = 0; j < ny; j++) for (let i = 0; i < nx; i++) M[j * nx + i] = X.inTerrain(x0 + (i + 0.5) * c, y0 + (j + 0.5) * c) ? 1 : 0;
    return { nx, ny, c, tris: ntri, H: b64(H), M: b64(M) };
  };
})();
