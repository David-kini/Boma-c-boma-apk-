extends RefCounted
## Les 10 armes du jeu. Chaque arme se débloque au niveau indiqué.
## dmg : multiplicateur de dégâts ; speed : multiplicateur de durée des coups
## (< 1 = plus rapide) ; len / width : forme de la lame ; element : couleur et éclairs.

const LIST: Array = [
	{"name": "Épée Éclair", "power": "ÉCLAIR : chaque coup paralyse l'ennemi 1,8 s (bruit de tonnerre).", "element": "eclair", "dmg": 1.0, "speed": 1.0, "len": 1.0, "width": 1.0, "level": 1},
	{"name": "Lame Courte du Vent", "power": "GLACE : chaque coup gèle l'ennemi dans un bloc de glace. Très rapide.", "element": "glace", "dmg": 0.85, "speed": 0.8, "len": 0.7, "width": 0.85, "level": 2},
	{"name": "Lame de Feu", "power": "FEU : chaque coup enflamme l'ennemi, les flammes restent sur son corps 5 s.", "element": "feu", "dmg": 1.15, "speed": 1.0, "len": 1.0, "width": 1.05, "level": 3},
	{"name": "Croc de Glace", "power": "GLACE : gèle chaque ennemi touché, gros dégâts.", "element": "glace", "dmg": 1.2, "speed": 1.0, "len": 1.05, "width": 0.9, "level": 4},
	{"name": "Lame Venimeuse", "power": "POISON : le venin ronge l'ennemi pendant 6 s.", "element": "poison", "dmg": 1.25, "speed": 0.95, "len": 0.95, "width": 1.0, "level": 5},
	{"name": "Espadon du Tonnerre", "power": "TONNERRE : paralyse chaque ennemi touché, très gros dégâts, lent.", "element": "eclair", "dmg": 1.6, "speed": 1.3, "len": 1.4, "width": 1.25, "level": 6},
	{"name": "Croc du Vide", "power": "VIDE : chaque coup projette l'ennemi en l'air.", "element": "vide", "dmg": 1.45, "speed": 1.0, "len": 1.1, "width": 1.0, "level": 7},
	{"name": "Lame Solaire", "power": "SOLEIL : brûlure puissante qui reste sur le corps.", "element": "solaire", "dmg": 1.6, "speed": 1.0, "len": 1.15, "width": 1.1, "level": 8},
	{"name": "Épée du Démon", "power": "DÉMON (noire) : vole la vie des ennemis (soigne le héros), malédiction qui ronge.", "element": "ombre", "dmg": 1.8, "speed": 0.95, "len": 1.15, "width": 1.0, "level": 9},
	{"name": "Épée Divine", "power": "DIVIN : la foudre saute sur 2 autres ennemis proches, paralyse et brûle.", "element": "divin", "dmg": 2.1, "speed": 1.0, "len": 1.25, "width": 1.2, "level": 10},
]


static func count() -> int:
	return LIST.size()


static func get_def(i: int) -> Dictionary:
	return LIST[clampi(i, 0, LIST.size() - 1)]
