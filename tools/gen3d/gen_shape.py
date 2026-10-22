"""Boma Choc — génération de la FORME 3D du héros avec Hunyuan3D-2, sur processeur (sans GPU).

Usage : python gen_shape.py MODE SORTIE
  MODE = v2      : modèle complet, image de face
         mv      : modèle multi-vues, face + dos
         mini    : petit modèle rapide, image de face
Résultat : SORTIE/shape_MODE.glb + aperçu des images détourées.
"""
import os
import sys
import time

import torch
from PIL import Image

MODE = sys.argv[1] if len(sys.argv) > 1 else "v2"
OUT = sys.argv[2] if len(sys.argv) > 2 else "out"
HERE = os.path.dirname(os.path.abspath(__file__))
INP = os.path.join(HERE, "input")
os.makedirs(OUT, exist_ok=True)
torch.set_num_threads(os.cpu_count() or 4)
t0 = time.time()


def log(*a):
    print(f"[{time.time() - t0:7.1f}s]", *a, flush=True)


from hy3dgen.rembg import BackgroundRemover  # noqa: E402
from hy3dgen.shapegen import Hunyuan3DDiTFlowMatchingPipeline  # noqa: E402

rembg = BackgroundRemover()


def prep(name):
    im = Image.open(os.path.join(INP, name)).convert("RGB")
    # l'image d'entrée du modèle fait 512 px : inutile de garder plus grand
    im.thumbnail((1024, 1024))
    cut = rembg(im)
    cut.save(os.path.join(OUT, f"detoure_{MODE}_{name}"))
    return cut


CFG = {
    "v2": ("tencent/Hunyuan3D-2", "hunyuan3d-dit-v2-0", 30, 5.0),
    "mv": ("tencent/Hunyuan3D-2mv", "hunyuan3d-dit-v2-mv", 30, 5.0),
    "mini": ("tencent/Hunyuan3D-2mini", "hunyuan3d-dit-v2-mini", 30, 5.0),
    # l'épée (créée à part, comme demandé)
    "epee": ("tencent/Hunyuan3D-2", "hunyuan3d-dit-v2-0", 30, 5.0),
    "epee_mv": ("tencent/Hunyuan3D-2mv", "hunyuan3d-dit-v2-mv", 30, 5.0),
    # la tête seule, à partir des gros plans (bien plus de détails sur le visage)
    "tete": ("tencent/Hunyuan3D-2", "hunyuan3d-dit-v2-0", 40, 5.5),
    "tete_mv": ("tencent/Hunyuan3D-2mv", "hunyuan3d-dit-v2-mv", 40, 5.5),
    # la tête à partir de TES VRAIES PHOTOS (lunettes retirées par deglass.py)
    "photo": ("tencent/Hunyuan3D-2", "hunyuan3d-dit-v2-0", 40, 5.5),
    "photo_mv": ("tencent/Hunyuan3D-2mv", "hunyuan3d-dit-v2-mv", 40, 5.5),
}
OCTREE = 384 if MODE.startswith(("tete", "photo")) else 256
repo, sub, steps, guid = CFG[MODE]
log("chargement", repo, sub)
pipe = Hunyuan3DDiTFlowMatchingPipeline.from_pretrained(repo, subfolder=sub, device="cpu", dtype=torch.float32)
log("modèle chargé")

if MODE == "mv":
    image = {"front": prep("1_face_avant.png"), "back": prep("3_dos.png")}
elif MODE == "tete":
    image = prep("tete_avant.png")
elif MODE == "tete_mv":
    image = {"front": prep("tete_avant.png"), "back": prep("tete_dos.png")}
elif MODE == "photo":
    image = prep("photo_face_sans_lunettes.png")
elif MODE == "photo_mv":
    # un seul profil photographié : l'autre côté est son miroir (visage presque symétrique)
    image = {"front": prep("photo_face_sans_lunettes.png"), "left": prep("photo_gauche_sans_lunettes.png"),
             "right": prep("photo_profil_miroir_sans_lunettes.png")}
elif MODE == "epee":
    image = prep("epee_avant.png")
elif MODE == "epee_mv":
    image = {"front": prep("epee_avant.png"), "left": prep("epee_cote.png"), "back": prep("epee_dos.png")}
else:
    image = prep("1_face_avant.png")
log("images prêtes")


def cb(step, t, outputs):
    log(f"étape {step + 1}/{steps}")


mesh = pipe(
    image=image,
    num_inference_steps=steps,
    guidance_scale=guid,
    octree_resolution=OCTREE,
    num_chunks=20000,
    generator=torch.manual_seed(1234),
    output_type="trimesh",
    callback=cb,
    callback_steps=1,
)[0]
log("forme générée :", len(mesh.vertices), "sommets", len(mesh.faces), "faces")
try:
    from hy3dgen.shapegen import DegenerateFaceRemover, FloaterRemover
    mesh = FloaterRemover()(mesh)
    mesh = DegenerateFaceRemover()(mesh)
    log("nettoyage :", len(mesh.faces), "faces")
except Exception as e:  # le nettoyage est facultatif
    log("nettoyage ignoré :", e)
path = os.path.join(OUT, f"shape_{MODE}.glb")
mesh.export(path)
log("enregistré", path, os.path.getsize(path), "octets")
