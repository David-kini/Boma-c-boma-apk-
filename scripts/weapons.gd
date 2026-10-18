extends RefCounted
## Les 10 armes du jeu. Chaque arme se débloque au niveau indiqué.
## dmg : multiplicateur de dégâts ; speed : multiplicateur de durée des coups
## (< 1 = plus rapide) ; len / width : forme de la lame ; element : couleur et éclairs.

const LIST: Array = [
	{"name": "Épée Éclair", "element": "eclair", "dmg": 1.0, "speed": 1.0, "len": 1.0, "width": 1.0, "level": 1},
	{"name": "Lame Courte du Vent", "element": "glace", "dmg": 0.85, "speed": 0.8, "len": 0.7, "width": 0.85, "level": 2},
	{"name": "Lame de Feu", "element": "feu", "dmg": 1.15, "speed": 1.0, "len": 1.0, "width": 1.05, "level": 3},
	{"name": "Croc de Glace", "element": "glace", "dmg": 1.2, "speed": 1.0, "len": 1.05, "width": 0.9, "level": 4},
	{"name": "Lame Venimeuse", "element": "poison", "dmg": 1.25, "speed": 0.95, "len": 0.95, "width": 1.0, "level": 5},
	{"name": "Espadon du Tonnerre", "element": "eclair", "dmg": 1.6, "speed": 1.3, "len": 1.4, "width": 1.25, "level": 6},
	{"name": "Croc du Vide", "element": "vide", "dmg": 1.45, "speed": 1.0, "len": 1.1, "width": 1.0, "level": 7},
	{"name": "Lame Solaire", "element": "solaire", "dmg": 1.6, "speed": 1.0, "len": 1.15, "width": 1.1, "level": 8},
	{"name": "Lame des Ombres", "element": "ombre", "dmg": 1.8, "speed": 0.95, "len": 1.15, "width": 1.0, "level": 9},
	{"name": "Épée Divine", "element": "divin", "dmg": 2.1, "speed": 1.0, "len": 1.25, "width": 1.2, "level": 10},
]


static func count() -> int:
	return LIST.size()


static func get_def(i: int) -> Dictionary:
	return LIST[clampi(i, 0, LIST.size() - 1)]
