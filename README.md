# Duel Éclair — Rise of Legend (Phase 2 : monde 3D)

Godot 4.3+ (GL Compatibility), GDScript. Solo, hors ligne.

## Ouvrir / tester
1. Godot 4.3 ou plus → Importer → `project.godot` → F5.
2. Clavier : ZQSD/WASD bouger, Maj courir, Espace sauter, C esquiver, flèches ou clic droit : caméra, Échap ou F1 : Paramètres.
3. Tactile : joystick à gauche, glisser à droite = caméra, boutons SAUT / ESQ. / MENU (Paramètres).

## APK
Le workflow `.github/workflows/android.yml` exporte un APK debug 32 bits (armeabi-v7a, pour Tecno Pop 7) à chaque push sur `main`
(onglet Actions → artefact `DuelEclair-apk`). Export manuel : Projet → Exporter → Android.

## Dragon amélioré : corps, pattes, nouvelles attaques (v0.16)
- Le modèle Quaternius n'est qu'une tête ailée : un vrai corps est construit en code
  autour de lui (cou, torse, ventre clair, 4 pattes griffues, queue articulée de
  7 segments qui ondule, piques dorsales). Il suit l'animation de la tête.
- Écailles rouge sombre et yeux de braise lumineux (plus brillants avant le souffle).
- Pattes : repliées en vol, posées sur la tour, tendues griffes en avant pendant le piqué.
- Souffle de feu : la gueule s'illumine 0,7 s, puis jet de flammes de 2 s qui suit
  lentement le héros (dégâts réguliers dans un cône étroit : esquive sur le côté).
- Griffes : le piqué projette le héros au loin et laisse 3 entailles au sol.
- Rafale d'ailes : si le héros reste collé au dragon, battement qui le repousse.
- Pluie de météores (phase 3) : 6 boules de feu tombent sur des cercles rouges.
- Testé : combat complet (3 phases, souffle, rafales, piqués, météores, mort, fin).

## Boss final : le Dragon des royaumes (v0.15)
- Modèle « Dragon » du pack CC0 Ultimate Monsters (Quaternius), récupéré depuis le Drive
  (Assets/Characters/Monsters/Dragon.gltf, animations de vol, coup de tête, mort).
- Apparaît au-dessus de la Grande Arène (la forteresse) quand les 5 boss sont vaincus.
- Vole en cercle et crache des boules de feu (elles touchent aussi le héros en vol).
- Se pose au sommet d'une des 8 tours et lance des attaques de zone : cercles rouges au
  sol qui explosent après 1,2 s. C'est le moment de voler / se téléporter jusqu'à lui.
- Phase 2 (60 %) : piqués sur le héros avec onde de choc ; reste un instant au sol.
- Phase 3 (30 %) : plus rapide, plus de zones de feu.
- Grande cible : les coups d'épée, tirs et ondes de choc le touchent sur tout son corps,
  à condition d'être à sa hauteur (vol, tour, ou pendant son piqué).
- La caméra lève les yeux pour le garder dans le cadre. Sa défaite lance la fin.
- Testé : apparition, 4 comportements, 3 phases, mort, cinématique de fin.

## Scénario « Shadow Ninja », étape 2 : boss de région et cinématiques (v0.14)
- Gardien des montagnes (Pics enneigés) : coups lents et lourds, zone d'impact rouge
  affichée au sol pendant la préparation, longue récupération (moment pour attaquer).
- Reine de la forêt (Forêt fantastique) : se téléporte d'un arbre à l'autre, lance des
  dagues, crée des illusions identiques (elles disparaissent au premier coup).
- Seigneur des ombres (Bois sombre) : apparaît derrière le héros et frappe ; en phase 2
  et 3, enchaîne 3 apparitions-frappes ; tirs d'ombre.
- Seigneur des nuages (au-dessus des Pics) : combat aérien en 3 phases (observation :
  tirs à distance ; affrontement : se rapproche ; dernière phase : plus rapide).
- Victoire contre un boss : courte célébration ; les 5 boss vaincus (avec le Roi
  Squelette) réveillent le Dragon des royaumes (v0.15). Progression sauvegardée.
- Cinématique d'introduction « La chute du royaume » (23 s, passable) au premier
  lancement ; cinématique de fin (36 s) avec scène supplémentaire ; les deux se revoient
  depuis le menu.

## Scénario « Shadow Ninja », étape 1 : combos, combat aérien, caméra (v0.13)
- Architecture réutilisable : scripts/combos.gd décrit chaque technique (condition,
  séquence d'entrées, dégâts, portée, recharge, coût) ; player.gd les exécute dans une
  machine à états « action » (une seule technique à la fois, sans conflit d'animation).
- Combos au sol : Danse de l'épée (A, A, A : caméra latérale, pivot, frappe verticale au
  ralenti), Frappe du dragon (maintenir ATTAQUE puis relâcher), Tempête ninja (A, A, ESQ, A),
  Exécution aérienne (sauter près d'un ennemi puis A : il est projeté en l'air),
  Fantôme des ténèbres (TP, A, A, ESQ).
- En vol : Dragon céleste (A), Frappe du météore (maintenir A : zone visée, plongeon),
  Pluie de lames (POUVOIR : cibles marquées puis piqué).
- Ultime : Éclipse du dragon (lumière qui baisse, téléportation au-dessus de la cible,
  frappe descendante, onde de 7 m qui repousse).
- Caméra cinématique : exploration, combat (rapprochée), vol (suit l'altitude), boss
  (cadre les deux), défaite (recul) ; ralentis brefs, orbite courte, vue plongeante ;
  option « Effets de caméra : réduits » dans le menu.

## Combat ninja, pouvoirs, monde resserré (v0.12)
- Monde réduit à 920 m x 920 m (lieux rapprochés) ; nouveaux lieux : Pics enneigés
  (sommets, sanctuaire, tour de guet), Forêt de pins (dense, camp de bûcherons), Bois sombre
  (cercle de pierres et cristaux), Vallée rocheuse avec falaises et 2 grottes traversables.
- Environ 55 ennemis (au lieu de 23), réapparition en 25 s ; Spectres ailés (ennemis volants).
- Défi de l'arène : se placer sur l'étoile centrale lance 5 vagues (récompense à la fin).
- Épéiste acrobate : garde de combat quand un ennemi est proche, coups qui avancent, coup
  sauté, coup circulaire, salto + impact au sol, roulade (esquive), attaque plongeante
  depuis les hauteurs, course sur les murs et rebond mural, course rapide (sprint).
- Menu POUVOIRS (bouton POUV. / touche P, le temps ralentit) : vague d'énergie,
  téléportation offensive, frappe de zone, vol, attaque éclair, bouclier, combo ninja ;
  le bouton POUVOIR (touche G) lance le pouvoir choisi (recharge affichée sur le bouton).
- Téléportation : appui court = rapide ; maintenu = ciblage (zone d'arrivée + ennemi visé),
  relâcher = téléportation + frappe de zone. Jamais dans un mur ni hors du monde.
- Vol : jusqu'à 60 m (au-dessus des tours), redescente en douceur, intouchable par les
  ennemis au sol (seuls les spectres ailés peuvent attaquer en l'air).
- Zones d'effet réduites et affichées au sol, dégâts plus forts au centre.

## Sauts, pouvoirs de combat, météo, sons (v0.11)
- Saut : appui court = saut normal ; maintenir = saut plus haut (2,6 m) ; maintenir en
  courant = SAUT LONG (11 m, contre 6 m sans) ; appuyer en l'air = DOUBLE SAUT avec salto.
- TIR (touche G) : vague d'énergie de la couleur de l'arme, visée auto, traverse 3 ennemis.
- TP (touche V) : téléportation derrière l'ennemi + coup puissant, enchaînable 3 fois
  (téléportation, téléportation, téléportation), puis le combo continue. Sans cible : bond de 7 m.
- ULTI (touche U) : attaque finale « Jugement de la foudre » quand la jauge violette est
  pleine (elle se remplit en frappant) : le héros s'élève, 4 vagues d'éclairs, onde de choc.
- Météo changeante toutes les 1 à 2 min : ensoleillé, nuageux, pluie, orage (éclairs et
  tonnerre), brouillard ; transitions douces ; pluie légère adaptée au téléphone.
- Nouveaux sons : double saut, saut long, tir, téléportation, tonnerre, charge et explosion
  de l'ultime, pluie en boucle ; impact d'épée plus percutant.

## Grande Arène et textures photo (v0.10)
- Nouvelle arène inspirée du concept art : sol de dalles sombres polies (effet mouillé)
  avec incrustations d'or (cercles, rayons, runes, étoile), 8 tours gothiques à flèches
  dorées, arcades, 4 grandes portes, 8 statues encapuchonnées tenant un cristal bleu,
  aqueduc à deux étages, 6 îles flottantes avec tours et cascades.
- Vraies textures photo CC0 (ambientCG Ground037 et Rock023) pour le terrain, la pierre
  des bâtiments et les îles (Assets/Textures/Photo, voir LICENCES.txt).
- Ciel avec nuages qui défilent (aussi en Ultra très bas). Une image de ciel réelle
  peut être ajoutée : Assets/Textures/Photo/ciel.jpg (panorama), utilisée automatiquement.
- Stabilité : mémoire des textures divisée par 4 (95 Mo -> 37 Mo de mémoire vidéo).
  Rapport de diagnostic : si le jeu se ferme brutalement, l'écran titre affiche au
  lancement suivant l'état du jeu au moment de la fermeture.
- Le joueur apparaît maintenant au centre de l'arène.

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

## v0.17 (non compilée, en attente de l'ordre « compiler »)
- **Radar** rond en haut à droite (ennemis en rouge, boss en orange) + **flèche vers le prochain boss** avec la distance.
- **Chargement par zone** : les ennemis n'existent que dans un rayon de 105 m autour du joueur (plafond selon la qualité), les lieux lointains sont endormis. Beaucoup plus d'ennemis (meutes dans toutes les zones).
- **Pouvoirs d'épée à chaque coup** : glace = gèle, éclair = paralyse (tonnerre), feu = brûlure dont les flammes restent sur le corps, poison, vide = projection en l'air, Épée du Démon (noire) = vol de vie, Épée Divine = foudre qui saute sur 2 ennemis. Les coups repoussent plus fort les ennemis.
- Menu : fond sombre lisible, pouvoir de l'arme affiché, défilement.
- Surchauffe : une épée utilisée 30 coups d'affilée est remplacée automatiquement par la suivante débloquée.
- Attaque spéciale au ralenti : au 5e coup du combo près d'un ennemi, il est projeté dans le ciel, le héros le rejoint, le frappe 5 fois en vol puis redescend (onde de choc).
- Correctifs : remise à zéro complète du héros après la scène d'intro (plus de pose assise), fermeture propre (bouton Retour sauvegarde et quitte, ralenti remis à 1).
