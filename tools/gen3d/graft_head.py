"""Blender (bpy) : remplace la tête du héros par la nouvelle tête et ajoute les lunettes 3D.

  1. importe le corps (MainHero.glb) — le corps et l'armure ne sont pas modifiés, seule la
     tête d'origine (au-dessus du col) est supprimée ;
  2. importe la nouvelle tête (HeroHead.glb, déjà texturée), coupe le bas (t-shirt) sous
     le cou, la met à l'échelle et la place dans le col ;
  3. construit les lunettes (glasses.py) et les pose devant les yeux, branches vers les oreilles ;
  4. vérifie (jointure tête/col, dimensions) et enregistre : .blend, .glb (Godot), .fbx (Mixamo).
Repère Blender : Z = haut, le visage regarde vers -Y.
Usage : python graft_head.py -- corps.glb tete.glb dossier_sortie
"""
import json
import math
import os
import sys

import bpy  # noqa: I001
import bmesh
from mathutils import Vector
from mathutils.kdtree import KDTree

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import glasses  # noqa: E402

args = sys.argv[sys.argv.index("--") + 1:]
BODY, HEAD, OUT = args[0], args[1], args[2]
os.makedirs(OUT, exist_ok=True)
REPORT = {}

# tête d'origine (mesurée sur MainHero) : axe vertical en (x, y) et zone à remplacer
AXIS = Vector((0.0, -0.19))
Z_CUT = 1.615          # au-dessus : tête d'origine (sous : col et corps conservés)
R_CUT = 0.118          # rayon autour de l'axe (le col est plus large)
TOP_TO_NECK = 0.255    # hauteur sommet du crâne -> milieu du cou de la nouvelle tête (m)
Z_TOP = 1.815          # sommet du crâne


def import_glb(path, name):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in bpy.data.objects if o not in before and o.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for o in new:
        o.select_set(True)
    bpy.context.view_layer.objects.active = new[0]
    if len(new) > 1:
        bpy.ops.object.join()
    ob = bpy.context.active_object
    ob.parent = None
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    ob.name = name
    return ob


def world_verts(ob):
    return [ob.matrix_world @ v.co for v in ob.data.vertices]


bpy.ops.wm.read_factory_settings(use_empty=True)
# glTF crée des nœuds vides : on ne garde que les maillages
body = import_glb(BODY, "Corps")
for o in list(bpy.data.objects):
    if o.type != "MESH":
        bpy.data.objects.remove(o)

# ---------------------------------------------------------------- 1. retirer l'ancienne tête
bm = bmesh.new()
bm.from_mesh(body.data)
kill = [v for v in bm.verts if v.co.z > Z_CUT and (Vector((v.co.x, v.co.y)) - AXIS).length < R_CUT]
REPORT["sommets_tete_origine_supprimes"] = len(kill)
bmesh.ops.delete(bm, geom=kill, context="VERTS")
bm.to_mesh(body.data)
bm.free()
body.data.update()
# centre du cou côté corps (anneau du col juste sous la coupe)
ring = [v for v in world_verts(body) if Z_CUT - 0.06 < v.z < Z_CUT + 0.05 and (Vector((v.x, v.y)) - AXIS).length < 0.17]
neck_c = sum((Vector((v.x, v.y)) for v in ring), Vector((0, 0))) / max(1, len(ring))
REPORT["centre_col"] = [round(neck_c.x, 3), round(neck_c.y, 3)]

# ---------------------------------------------------------------- 2. nouvelle tête
head = import_glb(HEAD, "Tete")
for o in list(bpy.data.objects):
    if o.type != "MESH":
        bpy.data.objects.remove(o)
vs = world_verts(head)
zmin, zmax = min(v.z for v in vs), max(v.z for v in vs)
H = zmax - zmin


def slice_width(z, tol):
    s = [v for v in vs if abs(v.z - z) < tol]
    if len(s) < 6:
        return None
    return max(v.x for v in s) - min(v.x for v in s)


# le cou = la tranche la plus étroite dans la moitié basse (sous : t-shirt, au-dessus : mâchoire)
best = None
for i in range(8, 45):
    z = zmin + H * i / 100
    w = slice_width(z, H * 0.012)
    if w is not None and (best is None or w < best[1]):
        best = (z, w)
z_neck, w_neck = best
REPORT["cou_hauteur_relative"] = round((z_neck - zmin) / H, 3)
# on garde un bout de cou sous le point le plus étroit (il plonge dans le col)
z_keep = z_neck - 0.10 * (zmax - z_neck)
bm = bmesh.new()
bm.from_mesh(head.data)
bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < z_keep], context="VERTS")
bm.to_mesh(head.data)
bm.free()
head.data.update()
# échelle : sommet -> cou = TOP_TO_NECK
k = TOP_TO_NECK / (zmax - z_neck)
head.scale = (k, k, k)
bpy.context.view_layer.objects.active = head
bpy.ops.object.select_all(action="DESELECT")
head.select_set(True)
bpy.ops.object.transform_apply(scale=True)
vs = world_verts(head)
ztop = max(v.z for v in vs)
zn = min(v.z for v in vs) + (z_neck - z_keep) * k
# centre du cou de la tête -> centre du col
nk = [v for v in vs if abs(v.z - zn) < 0.012]
hc = sum((Vector((v.x, v.y)) for v in nk), Vector((0, 0))) / max(1, len(nk))
head.location = (neck_c.x - hc.x, neck_c.y - hc.y, Z_TOP - ztop)
bpy.ops.object.transform_apply(location=True)
vs = world_verts(head)
ztop = max(v.z for v in vs)
zn = ztop - TOP_TO_NECK
REPORT["tete_hauteur_m"] = round(ztop - min(v.z for v in vs), 3)
REPORT["tete_largeur_m"] = round(max(v.x for v in vs) - min(v.x for v in vs), 3)

# ---------------------------------------------------------------- 3. lunettes
# hauteur des yeux d'après la photo de face : centre des lunettes à 37 % sommet -> cou
zg = ztop - 0.373 * TOP_TO_NECK
band = [v for v in vs if abs(v.z - zg) < 0.008]
cx = (max(v.x for v in band) + min(v.x for v in band)) / 2
head_w = max(v.x for v in band) - min(v.x for v in band)
front = min(v.y for v in band if abs(v.x - cx) < 0.02)          # arête du nez entre les yeux
g = glasses.build_glasses()
sg = (head_w + 0.014) / 0.165
g.scale = (sg, sg, sg)
g.location = (cx, front - 0.004, zg)
bpy.ops.object.select_all(action="DESELECT")
g.select_set(True)
bpy.context.view_layer.objects.active = g
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
REPORT["lunettes_largeur_m"] = round(g.dimensions.x, 3)

# ---------------------------------------------------------------- 4. vérifications
kd = KDTree(len(body.data.vertices))
for i, v in enumerate(world_verts(body)):
    kd.insert(v, i)
kd.balance()
low = [v for v in vs if v.z < zn + 0.02]
gaps = [kd.find(v)[2] for v in low]
REPORT["jointure_ecart_max_cm"] = round(max(gaps) * 100, 1) if gaps else None
REPORT["jointure_ecart_moyen_cm"] = round(sum(gaps) / max(1, len(gaps)) * 100, 1)
# le bas du cou doit être dans le col : sommets du cou non cachés = au-dessus du col et loin du corps
REPORT["objets"] = [o.name for o in bpy.data.objects]
REPORT["triangles"] = {o.name: sum(len(p.vertices) - 2 for p in o.data.polygons) for o in bpy.data.objects if o.type == "MESH"}
allv = world_verts(body) + vs
REPORT["hauteur_totale_m"] = round(max(v.z for v in allv) - min(v.z for v in allv), 3)

# corps + tête = un seul maillage (2 matériaux) ; lunettes = objet séparé, rattaché au corps
bpy.ops.object.select_all(action="DESELECT")
body.select_set(True)
head.select_set(True)
bpy.context.view_layer.objects.active = body
bpy.ops.object.join()
hero = bpy.context.active_object
hero.name = "MainHero"
g.parent = hero

bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "MainHero_tete_corrigee.blend"))
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "MainHero.glb"), export_format="GLB")
bpy.ops.export_scene.fbx(filepath=os.path.join(OUT, "MainHero_pour_Mixamo.fbx"), path_mode="COPY", embed_textures=True,
                         object_types={"MESH"}, axis_forward="-Z", axis_up="Y")
json.dump(REPORT, open(os.path.join(OUT, "rapport_greffe.json"), "w"), indent=1, ensure_ascii=False)
print("RAPPORT", json.dumps(REPORT, ensure_ascii=False))
