# Duel Éclair — Rise of Legend (Phase 2 : monde 3D)

Godot 4.3+ (GL Compatibility), GDScript. Solo, hors ligne.

## Ouvrir / tester
1. Godot 4.3 ou plus → Importer → `project.godot` → F5.
2. Clavier : ZQSD/WASD bouger, Maj courir, Espace sauter, C esquiver, flèches ou clic droit : caméra, Échap ou F1 : Paramètres.
3. Tactile : joystick à gauche, glisser à droite = caméra, boutons SAUT / ESQ. / MENU (Paramètres).

## APK
Le workflow `.github/workflows/android.yml` exporte un APK debug 32 bits (armeabi-v7a, pour Tecno Pop 7) à chaque push sur `main`
(onglet Actions → artefact `DuelEclair-apk`). Export manuel : Projet → Exporter → Android.

## Contenu Phase 2
Monde 3D ≈ 1414 m × 1414 m en tuiles avec LOD, zones, arène, ruines, rochers, volcan, montagnes de bordure ;
personnage 3D à squelette (visage photo sur tête ellipsoïde), marche/course/saut/esquive/récupération de chute ;
caméra 3e personne (SpringArm3D) ; HUD tactile ; menu Paramètres avec 4 niveaux de qualité (Ultra très bas, Bas, Normal, Élevé — Ultra très bas par défaut sur téléphone).

## Provisoire / non testé
Code écrit sans pouvoir l'exécuter dans Godot : seule la syntaxe (gdparse) et les chemins ont été vérifiés.
Corps en formes simples, esquive = pose accroupie (pas de roulade), perfs sur Tecno Pop 7 non mesurées.
Combat, vol, transformation, monstres, armes, menus, sauvegarde : phases 3 à 6.
`legacy_2d/` = ancien prototype 2D (exclu de l'export).
