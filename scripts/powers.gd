extends RefCounted
## Liste des pouvoirs choisis dans le menu POUVOIRS. Le bouton POUVOIR (touche G)
## déclenche le pouvoir sélectionné. Chaque pouvoir : effet visuel, portée, durée et
## temps de recharge propres (le changement modifie vraiment les capacités du héros).

const LIST: Array = [
	{"id": "vague", "name": "Vague d'énergie", "short": "VAGUE", "cd": 0.6,
		"desc": "Lance une vague tranchante de la couleur de l'arme. Traverse 3 ennemis.", "range": "22 m", "time": "instantané"},
	{"id": "tp", "name": "Téléportation offensive", "short": "TÉLÉP.", "cd": 2.5,
		"desc": "Apparaît derrière l'ennemi le plus proche et frappe. Enchaînable 3 fois.", "range": "14 m", "time": "instantané"},
	{"id": "zone", "name": "Frappe de zone", "short": "ZONE", "cd": 6.0,
		"desc": "La zone s'affiche au sol, puis onde de choc : plus forte au centre, repousse.", "range": "5 m autour", "time": "0,4 s"},
	{"id": "vol", "name": "Vol temporaire", "short": "VOL", "cd": 5.0,
		"desc": "Vol de 10 s au-dessus des toits ; les ennemis au sol ne peuvent plus te toucher.", "range": "60 m de haut", "time": "10 s"},
	{"id": "eclair", "name": "Attaque éclair", "short": "ÉCLAIR", "cd": 4.0,
		"desc": "Fonce comme l'éclair sur 10 m et tranche tout sur son passage.", "range": "10 m", "time": "0,15 s"},
	{"id": "bouclier", "name": "Bouclier énergétique", "short": "BOUCL.", "cd": 14.0,
		"desc": "Sphère d'énergie qui absorbe jusqu'à 60 dégâts.", "range": "sur soi", "time": "6 s"},
	{"id": "combo", "name": "Combo ninja", "short": "COMBO", "cd": 10.0,
		"desc": "6 coups éclairs en passant d'un ennemi à l'autre par téléportation.", "range": "9 m", "time": "1,2 s"},
]


static func count() -> int:
	return LIST.size()


static func get_def(i: int) -> Dictionary:
	return LIST[clampi(i, 0, LIST.size() - 1)]


static func index_of(id: String) -> int:
	for i in range(LIST.size()):
		if String(LIST[i]["id"]) == id:
			return i
	return 0
