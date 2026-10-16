"""Mide lo que cuesta un cuadro del mapa, pasada por pasada, en Chromium sin interfaz (SwiftShader).

  uv run --with "playwright==1.63" python tools/perf.py                      # teléfono: 390x844, densidad 2
  uv run --with "playwright==1.63" python tools/perf.py --size 1440x900 --dpr 1
  uv run --with "playwright==1.63" python tools/perf.py --view "estadio=__look(-560,1000,4)"   # vistas propias (repetible)

Para cada vista (JS que mueve la cámara, como en screenshot.py) da tres cuadros que pasan por el loop() real:
  refit   el mapa de sombras rehecho (fitShadow(true)): lo que cuesta un salto o un zoom grande
  pan     la mediana de seis desplazamientos de 6 px, uno por cuadro: sin sombras si la caja alcanza
  settle  el cuadro siguiente a que la cámara se detiene: solo con __pixelArt({crease:'normals'}), que salta la
          pasada de normales mientras la cámara se mueve (0: no hace falta un cuadro más)
cada uno como [ms, llamadas de dibujo, triángulos, veces que se dibujó el mapa de sombras], sumados sobre las pasadas
del cuadro (los triángulos no cuentan los del mapa de sombras), con la k y el contorno (ol) del pixel art. Cada medida
espera a la GPU (readPixels), así que los ms son de SwiftShader: sirven para comparar, no son los de un teléfono.
Usa window.__three (99-boot.js) y abre la página con open_page() de screenshot.py (una carga, ~1 min).
"""
import argparse, asyncio, json
from playwright.async_api import async_playwright
from screenshot import open_page

FRAME = r"""(async (look)=>{const {renderer}=__three;const gl=renderer.getContext(),px=new Uint8Array(4),SM=renderer.shadowMap;
 const render=renderer.render.bind(renderer),smr=SM.render.bind(SM);let ms=0,calls=0,tri=0,shadow=0;
 SM.render=(...a)=>{if(SM.needsUpdate)shadow++;smr(...a);};
 renderer.render=(s,c)=>{const t=performance.now();render(s,c);gl.readPixels(0,0,1,1,gl.RGBA,gl.UNSIGNED_BYTE,px);ms+=performance.now()-t;calls+=renderer.info.render.calls;tri+=renderer.info.render.triangles;};
 const frame=()=>new Promise(r=>requestAnimationFrame(r)),rest=()=>new Promise(r=>setTimeout(r,400));
 const take=()=>{const r=[Math.round(ms),calls,tri,shadow];ms=calls=tri=shadow=0;return r;};
 try{eval(look);await frame();await frame();await rest();await frame();await frame();take(); // new tiles uploaded, settled
  __three.fitShadow(true);__three.placeCam();await frame();const refit=take();await rest();await frame();take();
  const pans=[];for(let i=0;i<6;i++){__three.pan(6,0);await frame();pans.push(take());}
  await rest();await frame();const settle=take();pans.sort((a,b)=>a[0]-b[0]);
  return {refit,pan:pans[3],settle,k:__three.PA.k,ol:__three.PA.ol};}
 finally{renderer.render=render;SM.render=smr;}})"""

VIEWS = ['inicial=0', 'comuna=__look(3000,1000,0.12)', 'ciudad=__look(-60,30,1.5)', 'plaza-z4=__look(-60,30,4)', 'plaza-z14=__look(-60,30,14.2)']

async def main(a):
    async with async_playwright() as p:
        b, pg, logs = await open_page(p, a.size, dpr=a.dpr)
        print('[ms, llamadas, triángulos, mapas de sombra] por cuadro')
        for v in a.view or VIEWS:
            name, _, js = v.partition('=')
            print(name, json.dumps(await pg.evaluate(FRAME, js or '0')))
        for l in logs:
            if l.startswith(('ERROR:', 'error:')): print(l)
        await b.close()

if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('--size', default='390x844'); ap.add_argument('--dpr', type=float, default=2)
    ap.add_argument('--view', action='append', help='nombre=expresión JS que mueve la cámara (repetible)')
    asyncio.run(main(ap.parse_args()))
