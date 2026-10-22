"""Nettoie la tête générée : enlève les lunettes fondues dans le relief (couches très minces
devant les yeux : verres, monture, branches), les débris, bouche les trous et lisse la zone
des yeux. Les vraies lunettes sont ensuite un objet 3D séparé (glasses.py).
Étape 1 (python + pymeshlab) : python clean_head.py prep shape.glb sortie.glb
Étape 2 (blender): python clean_head.py fix entree.glb sortie.glb   (avec le module bpy)
"""
import sys

MODE, SRC, DST = sys.argv[1:4]

if MODE == "prep":
    import fast_simplification
    import numpy as np
    import trimesh
    m = trimesh.load(SRC, force="mesh")
    v, f = fast_simplification.simplify(m.vertices.astype(np.float32), m.faces.astype(np.int32), 1 - 200000 / len(m.faces))
    m = trimesh.Trimesh(v, f, process=True)
    H = m.extents[1]
    # épaisseur locale : distance jusqu'à la paroi opposée, le long de la normale vers l'intérieur
    c, n = m.triangles_center, m.face_normals
    o = c - n * 1e-4
    loc, ri, _ = m.ray.intersects_location(o, -n, multiple_hits=False)
    th = np.full(len(c), np.inf)
    th[ri] = np.linalg.norm(loc - o[ri], axis=1)
    thin = th / H < 0.012          # verres et monture : < 1,2 % de la hauteur (oreilles : plus épaisses)
    m.update_faces(~thin)
    m.remove_unreferenced_vertices()
    parts = m.split(only_watertight=False)
    big = max(parts, key=lambda p: len(p.faces))
    # reconstruction de Poisson : surface fermée, referme les fentes laissées par les verres
    import os
    import pymeshlab
    tmp = DST + ".ply"
    big.export(tmp)
    ms = pymeshlab.MeshSet()
    ms.load_new_mesh(tmp)
    ms.compute_normal_per_vertex()
    ms.generate_surface_reconstruction_screened_poisson(depth=10, preclean=True)
    ms.meshing_remove_connected_component_by_face_number(mincomponentsize=5000)
    ms.save_current_mesh(tmp)
    big = trimesh.load(tmp)
    os.remove(tmp)
    big = max(big.split(only_watertight=False), key=lambda p: len(p.faces))   # garde la tête seule
    # lissage local de la zone des yeux (restes du pont et des tenons de la monture), avec un
    # fondu sur les bords de la zone pour ne pas laisser de marque
    vtx = big.vertices.copy()
    z0, z1 = vtx[:, 1].min(), vtx[:, 1].max()          # repère glTF : Y = haut, visage vers +Z
    zf, zb = vtx[:, 2].max(), vtx[:, 2].min()
    h = (vtx[:, 1] - z0) / (z1 - z0)
    d = (zf - vtx[:, 2]) / (zf - zb)
    def ramp(x, a, b):
        return np.clip((x - a) / (b - a), 0, 1)
    w = ramp(h, 0.46, 0.52) * (1 - ramp(h, 0.72, 0.78)) * (1 - ramp(d, 0.30, 0.40))
    idx = np.nonzero(w > 0)[0]
    nb = big.vertex_neighbors
    for _ in range(60):
        new = vtx.copy()
        for i in idx:
            new[i] = vtx[i] * (1 - 0.5 * w[i]) + vtx[nb[i]].mean(0) * 0.5 * w[i]
        vtx = new
    big.vertices = vtx
    print("sommets lissés (yeux) :", len(idx))
    big.export(DST)
    print("faces minces enlevées :", int(thin.sum()), "| morceaux jetés :", len(parts) - 1, "| faces :", len(big.faces))
else:
    import bpy  # noqa: I001
    import bmesh
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=SRC)
    ob = [o for o in bpy.data.objects if o.type == "MESH"][0]
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    # petits trous laissés par les lunettes (le grand trou du bas du cou est gardé : il sera dans le col)
    edges = [e for e in bm.edges if e.is_boundary]
    loops = []
    seen = set()
    for e in edges:
        if e in seen:
            continue
        stack, comp = [e], []
        while stack:
            x = stack.pop()
            if x in seen:
                continue
            seen.add(x)
            comp.append(x)
            for v in x.verts:
                for y in v.link_edges:
                    if y.is_boundary and y not in seen:
                        stack.append(y)
        loops.append(comp)
    loops.sort(key=len)
    # tous les trous, y compris le bas du cou : le remaillage en voxels a besoin d'un volume
    # fermé (le bas du cou est de toute façon coupé lors de la greffe, dans le col)
    small = loops
    for l in small:
        try:
            bmesh.ops.holes_fill(bm, edges=l, sides=0)
        except Exception as ex:
            print("trou non bouché :", len(l), ex)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    # lissage de la zone des yeux (restes de monture) : bande horizontale devant le visage
    zs = [v.co.z for v in bm.verts]
    z0, z1 = min(zs), max(zs)
    ys = [v.co.y for v in bm.verts]
    yfront = min(ys)
    band = [v for v in bm.verts if z0 + (z1 - z0) * 0.50 < v.co.z < z0 + (z1 - z0) * 0.66 and v.co.y < yfront + (max(ys) - yfront) * 0.35]
    for _ in range(60):
        bmesh.ops.smooth_vert(bm, verts=band, factor=0.5, use_axis_x=True, use_axis_y=True, use_axis_z=True)
    bm.to_mesh(ob.data)
    bm.free()
    print("trous bouchés :", len(small), "| sommets lissés (yeux) :", len(band))

    bpy.ops.export_scene.gltf(filepath=DST, export_format="GLB")
