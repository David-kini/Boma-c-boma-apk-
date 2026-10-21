"""Blender (sans interface) : convertit MainHero.glb en MainHero.fbx pour Mixamo.
Usage : blender -b -P to_fbx.py -- entree.glb sortie.fbx"""
import sys

import bpy

a = sys.argv[sys.argv.index("--") + 1:]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=a[0])
bpy.ops.export_scene.fbx(filepath=a[1], path_mode="COPY", embed_textures=True, apply_unit_scale=True,
                         axis_forward="-Z", axis_up="Y", object_types={"MESH"})
print("FBX OK", a[1])
