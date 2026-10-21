"""Boma Choc — texture du héros par projection des images de référence (sans GPU).

La forme vient de Hunyuan3D-2 (gen_shape.py). Ici :
  1. réduction du maillage (Android) ;
  2. orientation automatique : on cherche l'angle où la silhouette du modèle
     ressemble le plus à chaque image (face, dos, 3/4 gauche, 3/4 droite) ;
  3. dépliage UV (xatlas) ;
  4. pour chaque texel : couleur = mélange des images qui le voient (test de
     profondeur), pondéré par l'orientation de la surface ; le gros plan du visage
     est projeté en priorité sur la tête (si on le retrouve dans l'image de face) ;
  5. zones jamais vues : couleur du texel visible le plus proche ;
  6. export MainHero.glb (1,80 m, pieds au sol, regard vers +Z) + rapport.

Usage : python tex_project.py shape.glb dossier_images sortie [nb_faces]
"""
import json
import math
import os
import sys
import time

import cv2
import fast_simplification
import numpy as np
import trimesh
import xatlas
from PIL import Image
from scipy import ndimage

T0 = time.time()
REPORT = {}


def log(*a):
    print(f"[{time.time() - T0:7.1f}s]", *a, flush=True)


SHAPE, INP, OUT = sys.argv[1], sys.argv[2], sys.argv[3]
TARGET_FACES = int(sys.argv[4]) if len(sys.argv) > 4 else 24000
TEX = 1024
os.makedirs(OUT, exist_ok=True)

# ------------------------------------------------------------------ maillage
sc = trimesh.load(SHAPE, force="mesh")
v = np.asarray(sc.vertices, dtype=np.float64)
f = np.asarray(sc.faces, dtype=np.int64)
log("maillage d'origine :", len(v), "sommets,", len(f), "faces")
if len(f) > TARGET_FACES:
    v, f = fast_simplification.simplify(v.astype(np.float32), f.astype(np.int32), 1.0 - TARGET_FACES / len(f))
    v = v.astype(np.float64)
    f = f.astype(np.int64)
m = trimesh.Trimesh(v, f, process=True)
# garde la plus grosse pièce + celles d'au moins 2 % (enlève les débris)
parts = m.split(only_watertight=False)
if len(parts) > 1:
    big = max(len(p.faces) for p in parts)
    m = trimesh.util.concatenate([p for p in parts if len(p.faces) >= 0.02 * big])
log("maillage réduit :", len(m.vertices), "sommets,", len(m.faces), "faces")
REPORT["faces"] = int(len(m.faces))

# normalisation : hauteur 1,80 m, pieds à y = 0, centré en x/z
lo, hi = m.bounds
s = 1.8 / (hi[1] - lo[1])
m.apply_translation(-np.array([(lo[0] + hi[0]) / 2, lo[1], (lo[2] + hi[2]) / 2]))
m.apply_scale(s)


def roty(deg):
    a = math.radians(deg)
    c, si = math.cos(a), math.sin(a)
    return np.array([[c, 0, si], [0, 1, 0], [-si, 0, c]])


# ------------------------------------------------------------------ images
def load_view(name, maxh=1024):
    p = os.path.join(INP, name)
    if not os.path.exists(p):
        return None
    im = Image.open(p).convert("RGB")
    if im.height > maxh:
        im = im.resize((int(im.width * maxh / im.height), maxh), Image.LANCZOS)
    rgb = np.asarray(im).astype(np.float32) / 255.0
    try:
        from rembg import new_session, remove
        cut = remove(im, session=_session())
        alpha = np.asarray(cut)[:, :, 3] > 128
    except Exception as e:  # sans rembg : seuil sur la luminosité du fond sombre
        log("rembg indisponible :", e)
        alpha = rgb.max(axis=2) > 0.12
    # garde la plus grande tache (enlève les morceaux d'épée des vues voisines)
    n, lab, stats, _ = cv2.connectedComponentsWithStats(alpha.astype(np.uint8), 8)
    if n > 1:
        k = 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))
        alpha = lab == k
    alpha = ndimage.binary_fill_holes(alpha)
    ys, xs = np.nonzero(alpha)
    return {"name": name, "rgb": rgb, "mask": alpha, "bbox": (xs.min(), ys.min(), xs.max(), ys.max())}


_S = []


def _session():
    if not _S:
        from rembg import new_session
        _S.append(new_session("u2net"))
    return _S[0]


views = {
    "face": load_view("1_face_avant.png"),
    "gauche": load_view("2_gauche.png"),
    "dos": load_view("3_dos.png"),
    "droite": load_view("4_droite.png"),
}
views = {k: vv for k, vv in views.items() if vv is not None}
log("vues chargées :", list(views))

# ------------------------------------------------------------------ silhouettes et orientation
PTS = m.sample(40000)


def silhouette(yaw, w=96, h=192):
    p = PTS @ roty(yaw).T
    x, y = p[:, 0], p[:, 1]
    x0, x1, y0, y1 = x.min(), x.max(), y.min(), y.max()
    sc_ = (h - 1) / (y1 - y0)
    img = np.zeros((h, w), np.uint8)
    xi = ((x - (x0 + x1) / 2) * sc_ + w / 2).astype(int)
    yi = ((y1 - y) * sc_).astype(int)
    ok = (xi >= 0) & (xi < w) & (yi >= 0) & (yi < h)
    img[yi[ok], xi[ok]] = 1
    img = cv2.morphologyEx(img, cv2.MORPH_CLOSE, np.ones((5, 5), np.uint8))
    return img > 0


def mask_norm(vw, w=96, h=192):
    x0, y0, x1, y1 = vw["bbox"]
    crop = vw["mask"][y0:y1 + 1, x0:x1 + 1].astype(np.uint8)
    sc_ = (h - 1) / crop.shape[0]
    cw = max(1, int(crop.shape[1] * sc_))
    r = cv2.resize(crop, (cw, h), interpolation=cv2.INTER_NEAREST)
    out = np.zeros((h, w), np.uint8)
    if cw >= w:
        a = (cw - w) // 2
        out[:] = r[:, a:a + w]
    else:
        a = (w - cw) // 2
        out[:, a:a + cw] = r
    return out > 0


def iou(a, b):
    return (a & b).sum() / max(1, (a | b).sum())


fm = mask_norm(views["face"])
base_scores = {yaw: iou(silhouette(yaw), fm) for yaw in range(0, 360, 15)}
BASE = max(base_scores, key=base_scores.get)
log("orientation de face :", BASE, "° (score %.3f)" % base_scores[BASE])
YAW = {"face": BASE}
if "dos" in views:
    dm = mask_norm(views["dos"])
    sc_d = {d: iou(silhouette(BASE + 180 + d), dm) for d in range(-30, 31, 10)}
    YAW["dos"] = BASE + 180 + max(sc_d, key=sc_d.get)
for side in ("gauche", "droite"):
    if side in views:
        sm = mask_norm(views[side])
        sc_s = {d: iou(silhouette(BASE + d), sm) for d in list(range(-110, -14, 5)) + list(range(15, 111, 5))}
        YAW[side] = BASE + max(sc_s, key=sc_s.get)
        REPORT["score_" + side] = round(float(max(sc_s.values())), 3)
log("angles retenus :", YAW)
REPORT["angles"] = {k: int(a - BASE) for k, a in YAW.items()}
REPORT["score_face"] = round(float(base_scores[BASE]), 3)

# le modèle final regarde vers +Z : on applique l'orientation de face
m.apply_transform(trimesh.transformations.rotation_matrix(math.radians(BASE), [0, 1, 0]))
for k in YAW:
    YAW[k] -= BASE

# ------------------------------------------------------------------ dépliage UV
log("dépliage UV…")
vmap, faces_uv, uvs = xatlas.parametrize(m.vertices.astype(np.float32), m.faces.astype(np.uint32))
V = m.vertices[vmap]
N = m.vertex_normals[vmap]
F = faces_uv.astype(np.int64)
UV = uvs.astype(np.float64)
log("UV :", len(V), "sommets")


def raster(tri, W, H, depth=None):
    """Rasterise des triangles 2D (F,3,2) en pixels. Renvoie (face, bary) par pixel
    (et un z-buffer si depth (F,3) est donné : garde le plus grand z = le plus proche)."""
    fid = np.full((H, W), -1, np.int64)
    bary = np.zeros((H, W, 3), np.float32)
    zb = np.full((H, W), -np.inf, np.float32) if depth is not None else None
    x0 = np.clip(np.floor(tri[:, :, 0].min(1)).astype(int), 0, W - 1)
    x1 = np.clip(np.ceil(tri[:, :, 0].max(1)).astype(int), 0, W - 1)
    y0 = np.clip(np.floor(tri[:, :, 1].min(1)).astype(int), 0, H - 1)
    y1 = np.clip(np.ceil(tri[:, :, 1].max(1)).astype(int), 0, H - 1)
    for i in range(len(tri)):
        if x1[i] < x0[i] or y1[i] < y0[i]:
            continue
        xs, ys = np.meshgrid(np.arange(x0[i], x1[i] + 1) + 0.5, np.arange(y0[i], y1[i] + 1) + 0.5)
        (ax, ay), (bx, by), (cx, cy) = tri[i]
        den = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
        if abs(den) < 1e-12:
            continue
        l0 = ((by - cy) * (xs - cx) + (cx - bx) * (ys - cy)) / den
        l1 = ((cy - ay) * (xs - cx) + (ax - cx) * (ys - cy)) / den
        l2 = 1 - l0 - l1
        inside = (l0 >= -1e-4) & (l1 >= -1e-4) & (l2 >= -1e-4)
        if not inside.any():
            continue
        yy = (ys[inside] - 0.5).astype(int)
        xx = (xs[inside] - 0.5).astype(int)
        b = np.stack([l0[inside], l1[inside], l2[inside]], 1)
        if depth is not None:
            z = b @ depth[i]
            closer = z > zb[yy, xx]
            yy, xx, b, z = yy[closer], xx[closer], b[closer], z[closer]
            zb[yy, xx] = z
        fid[yy, xx] = i
        bary[yy, xx] = b
    return fid, bary, zb


# texels : position 3D et normale
log("rasterisation UV…")
tri_uv = np.stack([UV[F][:, :, 0] * TEX, (1 - UV[F][:, :, 1]) * TEX], -1)
tfid, tbary, _ = raster(tri_uv, TEX, TEX)
covered = tfid >= 0
cf = tfid[covered]
cb = tbary[covered]
P = (V[F[cf]] * cb[:, :, None]).sum(1)
NN = (N[F[cf]] * cb[:, :, None]).sum(1)
NN /= np.linalg.norm(NN, axis=1, keepdims=True) + 1e-9
log("texels couverts :", int(covered.sum()))

acc = np.zeros((len(P), 3), np.float64)
wsum = np.zeros(len(P), np.float64)


def bilinear(img, x, y):
    H, W = img.shape[:2]
    x = np.clip(x - 0.5, 0, W - 1.001)
    y = np.clip(y - 0.5, 0, H - 1.001)
    x0 = x.astype(int)
    y0 = y.astype(int)
    fx = (x - x0)[:, None]
    fy = (y - y0)[:, None]
    a = img[y0, x0] * (1 - fx) + img[y0, x0 + 1] * fx
    b = img[y0 + 1, x0] * (1 - fx) + img[y0 + 1, x0 + 1] * fx
    return a * (1 - fy) + b * fy


def project_view(key, weight, rgb=None, region=None):
    """Projette la vue `key` (ou une image `rgb` alignée sur elle) sur les texels."""
    vw = views[key]
    R = roty(YAW[key])
    pv = V @ R.T
    pt = P @ R.T
    nt = NN @ R.T
    img = vw["rgb"] if rgb is None else rgb
    H, W = vw["mask"].shape
    x0b, y0b, x1b, y1b = vw["bbox"]
    # alignement : boîte du modèle projeté -> boîte de la silhouette de l'image
    mx0, mx1 = pv[:, 0].min(), pv[:, 0].max()
    my0, my1 = pv[:, 1].min(), pv[:, 1].max()
    k = (y1b - y0b) / (my1 - my0)
    cxm, cxi = (mx0 + mx1) / 2, (x0b + x1b) / 2

    def to_px(q):
        return np.stack([(q[:, 0] - cxm) * k + cxi, (my1 - q[:, 1]) * k + y0b], 1)

    tri = to_px(pv.reshape(-1, 3))[F]
    _, _, zb = raster(tri, W, H, depth=pv[:, 2][F])
    px = to_px(pt)
    xi = np.clip(px[:, 0].astype(int), 0, W - 1)
    yi = np.clip(px[:, 1].astype(int), 0, H - 1)
    zt = pt[:, 2]
    vis = zt >= zb[yi, xi] - 0.02
    facing = np.clip(nt[:, 2], 0, 1)
    ok = vis & vw["mask"][yi, xi] & (facing > 0.15)
    if region is not None:
        ok &= region(px)
    w = weight * facing ** 2 * ok
    if rgb is not None and rgb.shape[:2] != (H, W):
        raise ValueError("image non alignée")
    col = bilinear(img, px[:, 0], px[:, 1])
    acc[:] += col * w[:, None]
    wsum[:] += w
    log(f"vue {key} : {int(ok.sum())} texels")
    return to_px, ok


WEIGHTS = {"face": 1.0, "dos": 1.0, "gauche": 0.6, "droite": 0.6}
for key in views:
    project_view(key, WEIGHTS[key])

# ------------------------------------------------------------------ gros plan du visage
face_ok = False
try:
    close = load_view("visage_avant.png", maxh=900)
    fr = views["face"]
    g_front = cv2.cvtColor((fr["rgb"] * 255).astype(np.uint8), cv2.COLOR_RGB2GRAY)
    g_close = cv2.cvtColor((close["rgb"] * 255).astype(np.uint8), cv2.COLOR_RGB2GRAY)
    # zone de recherche : le quart haut de la silhouette
    x0b, y0b, x1b, y1b = fr["bbox"]
    top = g_front[y0b:y0b + int((y1b - y0b) * 0.22), x0b:x1b + 1]
    # visage du gros plan : partie haute du sujet (tête)
    cx0, cy0, cx1, cy1 = close["bbox"]
    head = g_close[cy0:cy0 + int((cy1 - cy0) * 0.62), cx0:cx1 + 1]
    best = (-1, None, None)
    for scl in np.linspace(0.08, 0.6, 40):
        tpl = cv2.resize(head, (max(8, int(head.shape[1] * scl)), max(8, int(head.shape[0] * scl))))
        if tpl.shape[0] >= top.shape[0] or tpl.shape[1] >= top.shape[1]:
            continue
        r = cv2.matchTemplate(top, tpl, cv2.TM_CCOEFF_NORMED)
        _, mx, _, loc = cv2.minMaxLoc(r)
        if mx > best[0]:
            best = (mx, scl, loc)
    REPORT["visage_score"] = round(float(best[0]), 3)
    log("recherche du visage : score %.3f" % best[0])
    if best[0] > 0.45:
        mx, scl, (lx, ly) = best
        # image du gros plan ré-échantillonnée dans le repère de l'image de face
        Hf, Wf = fr["mask"].shape
        M = np.float32([[scl, 0, x0b + lx - cx0 * scl], [0, scl, y0b + ly - cy0 * scl]])
        warped = cv2.warpAffine(close["rgb"], M, (Wf, Hf), flags=cv2.INTER_LINEAR)
        wmask = cv2.warpAffine(close["mask"].astype(np.uint8), M, (Wf, Hf), flags=cv2.INTER_NEAREST) > 0
        fx0, fy0 = x0b + lx, y0b + ly
        fx1, fy1 = fx0 + head.shape[1] * scl, fy0 + head.shape[0] * scl * 0.85

        def in_face(px):
            xi = np.clip(px[:, 0].astype(int), 0, Wf - 1)
            yi = np.clip(px[:, 1].astype(int), 0, Hf - 1)
            return (px[:, 0] > fx0) & (px[:, 0] < fx1) & (px[:, 1] > fy0) & (px[:, 1] < fy1) & wmask[yi, xi]

        project_view("face", 6.0, rgb=warped, region=in_face)
        face_ok = True
except Exception as e:
    log("gros plan du visage ignoré :", e)
REPORT["visage_projete"] = face_ok

# ------------------------------------------------------------------ assemblage de la texture
tex = np.zeros((TEX, TEX, 3), np.float32)
seen = np.zeros((TEX, TEX), bool)
col = acc / np.maximum(wsum, 1e-9)[:, None]
have = wsum > 1e-6
ys, xs = np.nonzero(covered)
tex[ys[have], xs[have]] = col[have]
seen[ys[have], xs[have]] = True
REPORT["texels_vus_pct"] = round(100.0 * have.mean(), 1)
log("texels vus : %.1f %%" % (100.0 * have.mean()))
# zones jamais vues et marges entre îlots : couleur du texel vu le plus proche
_, (iy, ix) = ndimage.distance_transform_edt(~seen, return_indices=True)
tex = tex[iy, ix]
tex_img = Image.fromarray((np.clip(tex, 0, 1) * 255).astype(np.uint8))
tex_img.save(os.path.join(OUT, "MainHero_albedo.png"))

# ------------------------------------------------------------------ export
mat = trimesh.visual.material.PBRMaterial(name="MainHero", baseColorTexture=tex_img, metallicFactor=0.15,
                                          roughnessFactor=0.65)
out = trimesh.Trimesh(V, F, visual=trimesh.visual.TextureVisuals(uv=UV, material=mat), process=False)
out.export(os.path.join(OUT, "MainHero.glb"))
REPORT["glb_octets"] = os.path.getsize(os.path.join(OUT, "MainHero.glb"))
REPORT["duree_s"] = round(time.time() - T0)
json.dump(REPORT, open(os.path.join(OUT, "rapport_texture.json"), "w"), indent=1, ensure_ascii=False)
log("terminé :", REPORT)
