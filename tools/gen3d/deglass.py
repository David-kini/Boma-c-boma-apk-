"""Enlève les lunettes des photos du visage (avant la génération 3D de la tête).

Les lunettes seront un objet 3D séparé : il ne faut pas qu'elles soient fondues dans le
relief ni peintes sur la peau. Méthode (sans GPU) :
  - verres teintés : on corrige la teinte (transfert de couleur Lab vers la peau voisine),
    ce qui garde les yeux et les paupières visibles à travers ;
  - monture fine (barre, pont, charnières, branche) : reconstruction par inpainting.
Les zones sont décrites à la main pour ces photos (coordonnées en pixels).
Usage : python deglass.py dossier_entree dossier_sortie
"""
import os
import sys

import cv2
import numpy as np

INP, OUT = sys.argv[1], sys.argv[2]
os.makedirs(OUT, exist_ok=True)

ZONES = {
    "photo_face.png": {
        "verres": [
            [(125, 232), (300, 232), (306, 300), (292, 345), (255, 373), (170, 369), (120, 346), (106, 300), (110, 255)],
            [(360, 232), (556, 238), (562, 272), (546, 332), (510, 370), (420, 377), (380, 357), (364, 320), (357, 262)],
        ],
        "peau": [(150, 395, 260, 450), (380, 395, 500, 450)],   # rectangles de joue (référence de couleur)
        "monture": {
            "lignes": [((195, 226), (475, 229), 9), ((292, 276), (378, 274), 8), ((297, 268), (300, 330), 6),
                       ((372, 268), (370, 330), 6)],
            "taches": [[(76, 258), (132, 258), (134, 316), (76, 316)], [(532, 258), (592, 258), (592, 318), (532, 318)]],
        },
    },
    "photo_gauche.png": {
        "verres": [[(36, 238), (132, 243), (162, 330), (152, 396), (110, 404), (38, 391), (14, 340), (10, 270)]],
        "peau": [(170, 400, 300, 470)],
        "monture": {
            "lignes": [((150, 262), (330, 246), 24), ((330, 246), (495, 234), 22), ((495, 234), (530, 236), 14)],
            "taches": [[(140, 240), (220, 240), (222, 292), (140, 292)], [(0, 300), (40, 300), (40, 380), (0, 380)]],
        },
    },
}
ZONES["photo_droite.png"] = ZONES["photo_gauche.png"]   # même cadrage, même côté du visage


def poly_mask(shape, polys):
    m = np.zeros(shape[:2], np.uint8)
    for p in polys:
        cv2.fillPoly(m, [np.array(p, np.int32)], 255)
    return m


for name, z in ZONES.items():
    path = os.path.join(INP, name)
    if not os.path.exists(path):
        continue
    im = cv2.imread(path)
    lab = cv2.cvtColor(im, cv2.COLOR_BGR2LAB).astype(np.float32)
    lens = poly_mask(im.shape, z["verres"]) > 0
    skin = np.zeros(im.shape[:2], bool)
    for x0, y0, x1, y1 in z["peau"]:
        skin[y0:y1, x0:x1] = True
    # transfert de couleur : moyenne/écart-type du verre -> ceux de la peau (L un peu plus sombre :
    # la zone des yeux est naturellement plus ombrée)
    out = lab.copy()
    for c in range(3):
        ls, lsd = lab[lens, c].mean(), lab[lens, c].std() + 1e-6
        ss, ssd = lab[skin, c].mean(), lab[skin, c].std() + 1e-6
        if c == 0:
            # luminosité : on garde le dessin des yeux, un peu plus sombre que la joue (zone d'ombre)
            gain = float(np.clip(ssd / lsd, 0.8, 1.3))
            val = (lab[:, :, 0] - ls) * gain + ss - 12.0
        else:
            # couleur : celle de la peau, avec 30 % des variations d'origine
            val = (lab[:, :, c] - ls) * 0.3 + ss
        out[:, :, c] = np.where(lens, val, lab[:, :, c])
    fixed = cv2.cvtColor(np.clip(out, 0, 255).astype(np.uint8), cv2.COLOR_LAB2BGR)
    # bord du verre adouci (évite une marque nette)
    soft = cv2.GaussianBlur(lens.astype(np.float32), (0, 0), 6.0)[:, :, None]
    blend = (fixed * soft + im * (1 - soft)).astype(np.uint8)
    # monture : inpainting des barres, du pont, des charnières, de la branche et du contour des verres
    frame = np.zeros(im.shape[:2], np.uint8)
    for (a, b, t) in z["monture"]["lignes"]:
        cv2.line(frame, a, b, 255, t)
    for p in z["monture"]["taches"]:
        cv2.fillPoly(frame, [np.array(p, np.int32)], 255)
    edge = cv2.morphologyEx(lens.astype(np.uint8) * 255, cv2.MORPH_GRADIENT, np.ones((5, 5), np.uint8))
    frame = cv2.bitwise_or(frame, edge)
    res = cv2.inpaint(blend, frame, 6, cv2.INPAINT_TELEA)
    cv2.imwrite(os.path.join(OUT, name.replace(".png", "_sans_lunettes.png")), res)
    print("OK", name)
