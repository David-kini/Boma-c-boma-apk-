# Ressources 3D du projet

Toutes les ressources tierces sont sous licence **CC0** (domaine public : usage commercial
autorisé, aucune attribution obligatoire). Les licences d'origine sont copiées dans `Licenses/`.

| Dossier | Contenu | Source | Licence |
|---|---|---|---|
| `Environment/Medieval/Nature` | arbres, bosquets, rochers, montagnes, nuages, nénuphars | [KayKit Medieval Hexagon Pack](https://github.com/KayKit-Game-Assets/KayKit-Medieval-Hexagon-Pack-1.0) (Kay Lousberg) | CC0 |
| `Environment/Medieval/Buildings` | maisons, taverne, moulin, puits, marché, forge, église, tour, clôtures | idem | CC0 |
| `Environment/Medieval/Props` | tente, tonneaux, caisses, râtelier, cible, brouette | idem | CC0 |
| `Environment/Halloween` | arbres morts, tombes, crypte, portail, lanternes, os, crânes, cercueil | [KayKit Halloween Bits](https://github.com/KayKit-Game-Assets/KayKit-Halloween-Bits-1.0) | CC0 |
| `Environment/Dungeon` | torches, bannières, coffre, éboulis, épée brisée | [KayKit Dungeon Remastered](https://github.com/KayKit-Game-Assets/KayKit-Dungeon-Remastered-1.0) | CC0 |
| `Characters/Adventurers` | Chevalier, Barbare, Mage, Voleuse (riggés, 76 animations) | [KayKit Adventurers](https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0) | CC0 |
| `Characters/Skeletons` | 4 squelettes + armes (riggés, 95 animations) — futurs ennemis | [KayKit Skeletons](https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Skeletons-1.0) | CC0 |
| `Animations` | bibliothèques d'animations extraites (outil `tools/extraire_animations.gd`) | KayKit | CC0 |
| `Textures/sol_detail.png`, `dalles_pierre.png`, `pierre_brute.png` | textures stylisées générées pour ce projet | création originale | libre |

Le héros (corps, visage, manteau, épée) est entièrement créé par code dans `scripts/`
(`player_rig.gd`, `hero_head.gd`, `sword.gd`).

Formats : glTF 2.0 (`.gltf` + `.bin`, ou `.glb`), importés nativement par Godot 4.
Poids : 18 à 860 triangles par élément de décor, environ 6 000 par personnage animé.

## Textures photo (v0.10) — CC0
- Assets/Textures/Photo/herbe_ground037.jpg — ambientCG Ground037 (CC0)
- Assets/Textures/Photo/roche_rock023.jpg — ambientCG Rock023 (CC0)
Détails : Assets/Textures/Photo/LICENCES.txt. Textures des modèles KayKit réduites à 256 px.
