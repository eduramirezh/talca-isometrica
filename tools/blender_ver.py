"""Abre en Blender lo que exporta tools/export.py (glb o STL), listo para mirar.

  /Applications/Blender.app/Contents/MacOS/Blender --python tools/blender_ver.py -- shots/export/centro.glb
  /Applications/Blender.app/Contents/MacOS/Blender --python tools/blender_ver.py -- shots/export/centro.stl
  /Applications/Blender.app/Contents/MacOS/Blender -b --python tools/blender_ver.py -- shots/export/centro.glb --png shots/export/blender.png

Empieza de una escena vacía, importa el archivo y deja la vista 3D en sombreado sólido con los colores por vértice
(COLOR_0 del glb) y luz plana, que los muestra como son (la de estudio los oscurece; Z cambia el sombreado), el recorte lejano
a 20 km (la caja es de 1 km o más; Blender corta a 1 km) y la cámara encuadrando todo. Un STL viene en milímetros
con Z arriba: se ve gris. Con --png (y -b, sin interfaz) dibuja una vista isométrica con Workbench y sale: sirve para
revisar sin abrir la ventana. Corre con el Python de Blender: no importa nada del repo.
"""
import math, sys
import bpy
from mathutils import Vector

args = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
if not args:
    sys.exit('uso: Blender --python tools/blender_ver.py -- <archivo.glb|.stl> [--png salida.png]')
path = args[0]
png = args[args.index('--png') + 1] if '--png' in args else None

bpy.ops.wm.read_factory_settings(use_empty=True)
if path.lower().endswith('.stl'):
    bpy.ops.wm.stl_import(filepath=path)
else:
    bpy.ops.import_scene.gltf(filepath=path)

objs = [o for o in bpy.context.scene.objects if o.type == 'MESH']
lo = Vector((min(v[i] for o in objs for v in (o.matrix_world @ Vector(c) for c in o.bound_box)) for i in range(3)))
hi = Vector((max(v[i] for o in objs for v in (o.matrix_world @ Vector(c) for c in o.bound_box)) for i in range(3)))
center, size = (lo + hi) / 2, max(hi - lo)
# los colores del glb son lineales y deben verse como en la página: sin la curva de AgX (la de Blender por omisión,
# que los oscurece y les quita saturación)
bpy.context.scene.view_settings.view_transform = 'Standard'
print(f'blender_ver: {len(objs)} mallas, caja {tuple(round(v, 1) for v in lo)} – {tuple(round(v, 1) for v in hi)}')


def shade(sh):  # el glb con sus colores tal cual (la luz de estudio los oscurece); el STL, gris, con luz para leer la forma
    stl = path.lower().endswith('.stl')
    sh.light = 'STUDIO' if stl else 'FLAT'
    sh.color_type = 'MATERIAL' if stl else 'VERTEX'
    sh.show_cavity = False


if png:  # sin interfaz: una cámara ortográfica isométrica y Workbench
    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_WORKBENCH'
    shade(sc.display.shading)
    sc.render.resolution_x, sc.render.resolution_y = 1600, 1000
    cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam'))
    sc.collection.objects.link(cam); sc.camera = cam
    cam.data.type, cam.data.ortho_scale, cam.data.clip_end = 'ORTHO', size * 1.1, size * 20
    d = Vector((1, -1, 1)).normalized()  # desde el sureste, como la página
    cam.location = center + d * size * 3
    cam.rotation_euler = (-d).to_track_quat('-Z', 'Y').to_euler()
    sc.render.filepath = png
    bpy.ops.render.render(write_still=True)
    print('blender_ver ->', png)
    sys.exit(0)


def setup():
    for win in bpy.context.window_manager.windows:
        for area in win.screen.areas:
            if area.type != 'VIEW_3D':
                continue
            sp = area.spaces.active
            shade(sp.shading)
            sp.clip_start, sp.clip_end = 1, 20000
            region = next(r for r in area.regions if r.type == 'WINDOW')
            with bpy.context.temp_override(window=win, area=area, region=region):
                bpy.ops.view3d.view_all(center=False)
    return None


bpy.app.timers.register(setup, first_interval=0.5)
