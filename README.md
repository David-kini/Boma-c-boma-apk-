# Duel Éclair — Rise of Legend (Phase 2 : monde 3D)

Godot 4.3+ (GL Compatibility), GDScript. Solo, hors ligne.

## Ouvrir / tester
1. Godot 4.3 ou plus → Importer → `project.godot` → F5.
2. Clavier : ZQSD/WASD bouger, Maj courir, Espace sauter, C esquiver, flèches ou clic droit : caméra, Échap ou F1 : Paramètres.
3. Tactile : joystick à gauche, glisser à droite = caméra, boutons SAUT / ESQ. / MENU (Paramètres).

## APK
Le workflow `.github/workflows/android.yml` exporte un APK debug 32 bits (armeabi-v7a, pour Tecno Pop 7) à chaque push sur `main`
(onglet Actions → artefact `DuelEclair-apk`). Export manuel : Projet → Exporter → Android.

## Ennemis, boss, inventaire (v0.9)
- 7 types d'ennemis : squelette, guerrier, voleur, mage (zones des monstres et ruines),
  **Barbare** (lent, très résistant, hache à deux mains — zone volcanique),
  **Assassin** (très rapide, deux dagues — forêt), **Sorcier** (boules de feu à distance — zone rocheuse).
  Modèles CC0 KayKit Adventurers, accessoires triés, teinte ennemie.
- **Boss : le Roi Squelette** (repaire, nord-ouest) : 1200 PV, couronne d'or, barre de vie en haut de l'écran.
  Phase 2 (< 60 %) : invoque des serviteurs, plus rapide. Phase 3 (< 30 %) : furie. Dès la phase 2,
  onde de choc annoncée par un cercle rouge au sol (s'éloigner !). 600 XP, réapparaît après 2 min.
- Butin : pièces d'or et potions (30 %, 3 pour le boss), attirés vers le joueur.
  Potion = +50 PV : touche **H** ou bouton **SOIN**. Or et potions sauvegardés.
- Écran titre (JOUER), couleur du manteau dans le menu (Noir, Bordeaux, Bleu nuit, Blanc), sauvegardée.

## Pouvoirs, armes, progression (v0.8, phases 4-5)
- 5e coup du combo : frappe montante + éclair tout autour (32 dégâts).
- Vol magique de 10 s (VOL / F) : SAUT = monter, ESQ. = descendre ; recharge 5 s ; 4 ailes (ange, démon, éclair, or) animées.
- Transformation Divine de 10 s (DIVIN / T, énergie pleine) : aura dorée, onde de choc, dégâts x2, vitesse x1,3, dégâts reçus /2, lame divine.
- 10 armes (ARME / R), débloquées du niveau 1 au niveau 10 (forme, élément, dégâts, vitesse).
- XP gagnée sur les ennemis, niveaux (+10 PV max par niveau), sauvegarde automatique (user://sauvegarde.cfg).
- Sons synthétisés (aucun fichier requis) ; tes sons/musique dans Assets/Audio les remplacent.
- Menu pause : qualité, ailes, arme, avec aperçu du héros.

## Combat (v0.7, phase 3)
- Combo d'épée en 4 coups (taille, revers, coup vertical, tour complet) avec visée automatique, élan, traînée électrique, éclats d'impact, chiffres de dégâts, secousse de caméra.
- Héros : 120 PV (régénération hors combat), énergie gagnée en frappant (servira à la Transformation Divine), esquive invincible, K.O. puis retour au camp.
- Ennemis squelettes KayKit (IA : repos, poursuite, attaque avec préparation visible, touché, mort) avec barre de vie ; réapparition 40 s après la mort quand le joueur est loin ; Gardien du repaire (400 PV) en aperçu du boss.
- Commandes : bouton ATTAQUE (tactile), J / Entrée / clic gauche (PC).

## Ressources 3D CC0 (v0.6)
- Modèles KayKit (CC0) intégrés : arbres, rochers, nuages, village de Boma (maisons, taverne, moulin, puits, marché, forge, église, tour), camp (tente, tonneaux, caisses), cimetière (crypte, tombes, portail, lanternes), torches, bannières, coffre, nénuphars.
- Personnages riggés et animés CC0 : aventuriers (PNJ) et squelettes (futurs ennemis) ; bibliothèques d'animations extraites dans `Assets/Animations`.
- Textures de sol et de pierre stylisées (générées, libres) projetées en coordonnées monde.
- Organisation : `Assets/Textures`, `Assets/Characters`, `Assets/Animations`, `Assets/Environment` (+ `Licenses`, `Reference`). Détails et sources : `Assets/README_ASSETS.md`.
- Sauvegarde avant modification : tag git `sauvegarde-avant-assets`.

## Visage 3D et éclairage (v0.5)
- Tête entièrement modélisée (hero_head.gd), plus de photo collée : crâne chauve, teint albinos, nez large, lèvres pleines, sourire, joues, oreilles, yeux en amande (iris, pupille, reflet, cils), sourcils clairs, narines, lunettes sans monture (verres teintés, barre et branches dorées).
- Normales calculées exactement (tête et corps) ; ombres du soleil en 2 zones avec filtrage doux ; ombre douce sous les pieds à toutes les qualités ; lumière ambiante fixe et lumière d'appoint chaude ; pas de reflets du ciel (taches sur mobile, coûteux).

## Héros et caméra (v0.4)
- Héros d'après le concept art : tête modélisée (voir v0.5), chemise blanche, nœud papillon, gilet sombre à bordure et boutons dorés, long manteau noir à bordures et ourlet dorés, épaulières et brassards dorés, gants noirs, ceinture et boucle, pantalon, bottes à liseré doré.
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
