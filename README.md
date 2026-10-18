# Duel Éclair — Rise of Legend (Phase 2 : monde 3D)

Godot 4.3+ (GL Compatibility), GDScript. Solo, hors ligne.

## Ouvrir / tester
1. Godot 4.3 ou plus → Importer → `project.godot` → F5.
2. Clavier : ZQSD/WASD bouger, Maj courir, Espace sauter, C esquiver, flèches ou clic droit : caméra, Échap ou F1 : Paramètres.
3. Tactile : joystick à gauche, glisser à droite = caméra, boutons SAUT / ESQ. / MENU (Paramètres).

## APK
Le workflow `.github/workflows/android.yml` exporte un APK debug 32 bits (armeabi-v7a, pour Tecno Pop 7) à chaque push sur `main`
(onglet Actions → artefact `DuelEclair-apk`). Export manuel : Projet → Exporter → Android.

## Héros et caméra (v0.4)
- Héros d'après le concept art : tête chauve avec le visage de la photo (texture recadrée, bords fondus), branches de lunettes dorées, chemise blanche, nœud papillon, gilet sombre à bordure et boutons dorés, long manteau noir à bordures et ourlet dorés, épaulières et brassards dorés, gants noirs, ceinture et boucle, pantalon, bottes à liseré doré.
- Corps en maillages skinnés (déformés par le Skeleton3D de 18 os) ; os du manteau animé (il vole en course, en saut et en chute).
- Épée d'éclair (sword.gd) : lame dentelée lumineuse, halo additif, garde dorée en ailes, gemme, éclairs animés ; variantes feu et divin prêtes.
- Caméra : suivi fluide, recentrage automatique derrière le héros, zoom à la molette, collision, secousse.
- Outil de test : `godot -- --capture=img.png --view=front|back|side|hero|forest|... --quality=0..3 --anim=run` (capture d'écran automatique, inactif en jeu normal).

## Environnement (v0.3)
- Arène : sol en pierre, anneaux et éclair dorés, 16 piliers, murs, gradins, 4 portes avec linteau, bannières, braseros et panneaux indicateurs.
- Camp de départ (tente, feu, bancs, caisses) ; chemins de terre entre les zones.
- Ruines : temple sur plateforme avec rampe, salles cassées, colonnes couchées, arches.
- Zone rocheuse : rochers, aiguilles, arche naturelle. Forêt fantastique : arbre géant, cristaux, arbres colorés, champignons lumineux.
- Volcan : lac de lave dans le cratère, pics d'obsidienne. Repaire du boss : obélisques, cristaux rouges, grande porte.
- Zone des monstres : squelettes géants, pieux, cages, os, arbres morts. Lac Miroir avec ponton. Sapins sur les montagnes.
- Décor par tuile (MultiMesh) dont la densité suit la qualité graphique ; lieux fusionnés par matériau (peu d'appels de dessin).
- Bannière du nom de zone à l'entrée de chaque zone.

## Contenu Phase 2
Monde 3D ≈ 1414 m × 1414 m en tuiles avec LOD, zones, arène, ruines, rochers, volcan, montagnes de bordure ;
personnage 3D à squelette (visage photo sur tête ellipsoïde), marche/course/saut/esquive/récupération de chute ;
caméra 3e personne (SpringArm3D) ; HUD tactile ; menu Paramètres avec 4 niveaux de qualité (Ultra très bas, Bas, Normal, Élevé — Ultra très bas par défaut sur téléphone).

## Provisoire / non testé
Code écrit sans pouvoir l'exécuter dans Godot : seule la syntaxe (gdparse) et les chemins ont été vérifiés.
Corps en formes simples, esquive = pose accroupie (pas de roulade), perfs sur Tecno Pop 7 non mesurées.
Combat, vol, transformation, monstres, armes, menus, sauvegarde : phases 3 à 6.
`legacy_2d/` = ancien prototype 2D (exclu de l'export).
