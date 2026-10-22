"""Corrige le col du manteau du héros : à la génération, la couleur de peau de l'ancienne tête a
été projetée sur l'intérieur du grand col (taches orangées autour de la tête). On repeint ces
zones en cuir noir, à l'identique du reste du manteau. Le corps et l'armure ne bougent pas :
seule la texture change, et uniquement sur le col (au-dessus des épaules, près de la tête).
Usage : python fix_collar.py MainHero.glb sortie.glb
"""
import sys

import cv2
import numpy as np
import trimesh
from PIL import Image, ImageDraw

src, dst = sys.argv[1], sys.argv[2]
m = trimesh.load(src, force="mesh", process=False)
tex = np.asarray(m.visual.material.baseColorTexture.convert("RGB")).copy()
H, W = tex.shape[:2]
v = m.vertices                      # glTF : Y = haut, le visage regarde vers +Z
uv = m.visual.uv
c = v[m.faces].mean(1)
# col : au-dessus des épaules (y > 1,50 m) et à moins de 30 cm de l'axe de la tête
axis = np.array([0.0, 0.19])        # (x, z) de l'axe de l'ancienne tête
r = np.hypot(c[:, 0] - axis[0], c[:, 2] - axis[1])
sel = np.nonzero((c[:, 1] > 1.50) & (r < 0.30) & (c[:, 2] > 0.02))[0]   # dos exclu : dragon doré
region = Image.new("L", (W, H), 0)
d = ImageDraw.Draw(region)
for fi in sel:
    t = uv[m.faces[fi]]
    d.polygon([(float(x * W), float((1 - y) * H)) for x, y in t], fill=255)
region = np.asarray(region) > 0
hsv = cv2.cvtColor(tex, cv2.COLOR_RGB2HSV)
# peau : rose-orangé, moyennement saturée et claire (l'or est plus jaune et plus saturé)
hh, ss, vv = hsv[:, :, 0].astype(int), hsv[:, :, 1].astype(int), hsv[:, :, 2].astype(int)
skin = ((hh <= 14) | (hh >= 168)) & (ss > 35) & (ss < 175) & (vv > 110)
skin = cv2.dilate(skin.astype(np.uint8), np.ones((5, 5), np.uint8)) > 0
fix = region & skin
# cuir noir : couleur médiane des zones sombres du col, avec le grain d'origine (luminosité)
dark = region & (hsv[:, :, 2] < 70)
leather = np.median(tex[dark], axis=0) if dark.sum() > 50 else np.array([18, 16, 20])
lum = cv2.GaussianBlur(cv2.cvtColor(tex, cv2.COLOR_RGB2GRAY).astype(np.float32), (0, 0), 1.0) / 255.0
var = 0.6 + 0.8 * (lum - lum[fix].mean() if fix.any() else 0)
new = np.clip(leather[None, None, :] * var[:, :, None], 0, 255)
soft = cv2.GaussianBlur(fix.astype(np.float32), (0, 0), 1.5)[:, :, None]
out = (tex * (1 - soft) + new * soft).astype(np.uint8)
print("texels du col repeints :", int(fix.sum()), "| couleur cuir :", leather.astype(int).tolist())
m.visual.material.baseColorTexture = Image.fromarray(out)
m.export(dst)
print("OK", dst)
