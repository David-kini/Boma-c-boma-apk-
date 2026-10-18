# Duel Éclair (projet Godot 4)

Un héros (ton visage) contre 4 vagues de monstres : blobs, crânes rapides, puis un ogre.
Jeu 2D en paysage, commandes tactiles, rendu GL Compatibility (léger, pour Tecno Pop 7).

## Ouvrir le projet
1. Installe **Godot 4.3 ou plus récent** (version standard, pas .NET) : https://godotengine.org/download
2. Lance Godot, clique **Importer**, choisis le fichier `project.godot` de ce dossier.
3. Appuie sur **F5** pour jouer sur PC.

Clavier : flèches ou ZQSD (WASD) pour bouger, Espace saut, J poing, K pied, L garde.
La souris simule le toucher : clique sur les boutons à l'écran.

## Combos
- **Pied x4** enchaîne : coup de pied, coup haut, balayage bas, finisher qui projette.
- Chaque coup doit toucher pour continuer l'enchaînement.
- **Garde** bloque presque tout (dégâts réduits) si tu fais face à l'attaquant.

## Changer le visage ou le décor
- **Visage** : remplace `face.png` (image carrée, visage centré, fond transparent ou rond).
- **Décor** : ajoute une photo `arena.jpg` (ou `arena.png`) à la racine du projet. Elle remplace le décor dessiné. Format paysage 16:9, sol visible en bas.

## Exporter en APK (à faire sur ton PC)
1. Installe **JDK 17** et le **SDK Android** (Android Studio ou outils en ligne de commande).
2. Godot : **Éditeur > Paramètres de l'éditeur > Export > Android** : indique le chemin du SDK, du JDK et crée un keystore de debug.
3. **Projet > Installer le modèle d'exportation** (Export templates), puis **Projet > Exporter > Ajouter... > Android**.
4. Coche **Export With Debug**, clique **Exporter le projet** : tu obtiens un `.apk` à copier sur le téléphone.

## Limites actuelles
- Pas de son (à ajouter ensuite).
- Le visage est une image plate collée sur un corps dessiné.
- Non testé sur Godot ici : si Godot affiche une erreur au lancement, copie le message et envoie-le-moi.
