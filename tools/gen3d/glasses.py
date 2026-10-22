"""Blender (bpy) : construit les lunettes du héros en 3D, objet séparé.

D'après les photos : verres sans cerclage, rectangulaires aux coins arrondis, teintés violet
(couleur unie semi-transparente) ; double barre dorée au-dessus ; pont doré ; charnières dorées
ouvragées ; branches en bois rouge avec bague et embout dorés.
Repère Blender : Z = haut, le visage regarde vers -Y. Origine = centre du pont, plan des verres
en y = 0, branches vers +Y. Unités : mètres.
Usage : python glasses.py sortie.glb   (ou importé par graft_head.py : build_glasses())
"""
import math
import sys

import bpy  # noqa: I001 (bpy doit être importé avant bmesh)
import bmesh
from mathutils import Vector

LENS_W, LENS_H = 0.060, 0.043      # un verre
BRIDGE = 0.017                     # écart entre les verres
TEMPLE_L = 0.135                   # longueur des branches
WRAP = math.radians(7)             # verres légèrement tournés vers l'arrière sur les côtés


def mat(name, color, metal=0.0, rough=0.5, alpha=1.0):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = (*color, 1.0)
    b.inputs["Metallic"].default_value = metal
    b.inputs["Roughness"].default_value = rough
    if alpha < 1.0:
        b.inputs["Alpha"].default_value = alpha
        try:
            m.surface_render_method = "BLENDED"
        except Exception:
            m.blend_method = "BLEND"
    return m


def lens_outline(n=10):
    """Contour d'un verre : rectangle aux coins arrondis, bas légèrement arrondi vers le nez."""
    w, h, r = LENS_W, LENS_H, 0.011
    pts = []
    corners = [(w / 2 - r, h / 2 - r, 0), (-w / 2 + r, h / 2 - r, 90), (-w / 2 + r * 1.6, -h / 2 + r * 1.6, 180),
               (w / 2 - r * 1.2, -h / 2 + r * 1.2, 270)]
    for cx, cz, a0 in corners:
        rr = r * (1.6 if a0 == 180 else (1.2 if a0 == 270 else 1.0))
        for i in range(n + 1):
            a = math.radians(a0 + 90 * i / n)
            pts.append((cx + rr * math.cos(a), cz + rr * math.sin(a)))
    return pts


def make_lens(side):
    me = bpy.data.meshes.new("Verre")
    bm = bmesh.new()
    pts = lens_outline()
    vs = [bm.verts.new((x * side, 0.0, z)) for x, z in pts]
    f = bm.faces.new(vs if side > 0 else list(reversed(vs)))
    bmesh.ops.triangulate(bm, faces=[f])
    ext = bmesh.ops.extrude_face_region(bm, geom=bm.faces[:])
    for v in [e for e in ext["geom"] if isinstance(e, bmesh.types.BMVert)]:
        v.co.y += 0.0018
    bm.to_mesh(me)
    ob = bpy.data.objects.new("Verre", me)
    bpy.context.collection.objects.link(ob)
    ob.location = (side * (BRIDGE / 2 + LENS_W / 2), 0.0, 0.0)
    ob.rotation_euler = (0.0, 0.0, -side * WRAP)
    return ob


def tube(name, a, b, r, m, seg=8):
    a, b = Vector(a), Vector(b)
    d = b - a
    bpy.ops.mesh.primitive_cylinder_add(vertices=seg, radius=r, depth=d.length, location=(a + b) / 2)
    ob = bpy.context.active_object
    ob.name = name
    ob.rotation_mode = "QUATERNION"
    ob.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d.normalized())
    ob.data.materials.append(m)
    return ob


def build_glasses():
    gold = mat("Monture_or", (1.0, 0.72, 0.30), metal=1.0, rough=0.25)
    wood = mat("Branche_bois", (0.45, 0.10, 0.05), metal=0.0, rough=0.45)
    glass = mat("Verres_violets", (0.12, 0.05, 0.18), metal=0.0, rough=0.35, alpha=0.80)
    parts = []
    for side in (-1, 1):
        ln = make_lens(side)
        ln.data.materials.append(glass)
        parts.append(ln)
    top = LENS_H / 2 + 0.002
    half = BRIDGE / 2 + LENS_W
    # double barre au-dessus des verres
    parts.append(tube("Barre_haut", (-half * 0.7, -0.001, top + 0.003), (half * 0.7, -0.001, top + 0.003), 0.0011, gold))
    parts.append(tube("Barre_basse", (-BRIDGE * 1.6, -0.001, top - 0.004), (BRIDGE * 1.6, -0.001, top - 0.004), 0.0010, gold))
    # pont : petit arc doré entre les verres
    prev = None
    for i in range(9):
        t = i / 8
        x = (t - 0.5) * BRIDGE * 1.4
        z = 0.004 + 0.004 * math.sin(math.pi * t)
        p = (x, -0.002, z)
        if prev:
            parts.append(tube("Pont", prev, p, 0.0010, gold))
        prev = p
    # charnières ouvragées + branches
    for side in (-1, 1):
        hx = side * (half + 0.003)
        hinge_front = (hx, 0.0, LENS_H * 0.18)
        bpy.ops.mesh.primitive_uv_sphere_add(segments=10, ring_count=6, radius=0.0045, location=hinge_front)
        h = bpy.context.active_object
        h.name = "Charniere"
        h.scale = (0.8, 1.4, 1.2)
        h.data.materials.append(gold)
        parts.append(h)
        a = (hx + side * 0.002, 0.004, LENS_H * 0.18)
        b = (hx + side * 0.012, TEMPLE_L, LENS_H * 0.05)
        parts.append(tube("Embout_or", a, (a[0] + side * 0.002, 0.022, a[2] - 0.001), 0.0026, gold))
        parts.append(tube("Branche", (a[0] + side * 0.002, 0.022, a[2] - 0.001), b, 0.0028, wood))
        ring_y = 0.050
        k = ring_y / TEMPLE_L
        rp = (a[0] + (b[0] - a[0]) * k, ring_y, a[2] + (b[2] - a[2]) * k)
        parts.append(tube("Bague_or", (rp[0], rp[1] - 0.003, rp[2]), (rp[0], rp[1] + 0.003, rp[2]), 0.0033, gold))
        # branche courbée derrière l'oreille
        parts.append(tube("Branche_fin", b, (b[0], b[1] + 0.025, b[2] - 0.022), 0.0026, wood))
    bpy.ops.object.select_all(action="DESELECT")
    for p in parts:
        p.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    g = bpy.context.active_object
    g.name = "Lunettes"
    # origine = centre du pont (sinon elle resterait sur le premier verre et décalerait tout)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.context.scene.cursor.location = (0.0, 0.0, 0.0)
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    return g


if __name__ == "__main__":
    out = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else sys.argv[1]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    g = build_glasses()
    print("Lunettes :", len(g.data.vertices), "sommets", tuple(round(d, 3) for d in g.dimensions))
    try:
        bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_vertex_color="NONE")
    except TypeError:
        bpy.ops.export_scene.gltf(filepath=out, export_format="GLB")
    print("OK", out)
