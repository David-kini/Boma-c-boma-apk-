extends RefCounted
## Catalogue des techniques (combos et capacités). Chaque technique définit :
## - "when"   : condition d'activation (séquence de touches ou situation),
## - "seq"    : séquence d'entrées (A = attaque, D = esquive, T = téléportation, J = saut),
## - "window" : délai max (s) pour enchaîner la séquence,
## - "dmg"    : dégâts de base (multipliés par l'arme et la Transformation),
## - "range"  : portée (m), "cd" : recharge (s), "cost" : énergie ultime consommée.
## L'exécution (animation, déplacements, effets, caméra) est faite par player.gd
## dans la machine à états « action » : une seule action exclusive à la fois.

const LIST: Array = [
	{"id": "danse", "name": "Danse de l'épée", "when": "3 attaques", "seq": ["A", "A", "A"], "window": 1.6,
		"dmg": 16.0, "range": 3.0, "cd": 0.0, "cost": 0.0,
		"desc": "Avance, coupe horizontale, pivot et frappe opposée, saut et frappe verticale (ralenti)."},
	{"id": "dragon", "name": "Frappe du dragon", "when": "maintenir ATTAQUE puis relâcher", "seq": [], "window": 0.0,
		"dmg": 45.0, "range": 9.0, "cd": 3.0, "cost": 0.0,
		"desc": "Posture, l'énergie se concentre, ruée vers l'ennemi, frappe et onde de 3 m."},
	{"id": "tempete", "name": "Tempête ninja", "when": "attaque, attaque, esquive, attaque", "seq": ["A", "A", "D", "A"], "window": 2.2,
		"dmg": 10.0, "range": 8.0, "cd": 4.0, "cost": 0.0,
		"desc": "Esquive, téléportation derrière l'ennemi, 4 frappes rapides, coup qui repousse."},
	{"id": "aerienne", "name": "Exécution aérienne", "when": "sauter près d'un ennemi puis attaquer", "seq": [], "window": 0.0,
		"dmg": 12.0, "range": 3.5, "cd": 3.0, "cost": 0.0,
		"desc": "Frappe ascendante qui projette l'ennemi, 2 frappes en l'air, coup descendant."},
	{"id": "fantome", "name": "Fantôme des ténèbres", "when": "téléportation, attaque, attaque, esquive", "seq": ["T", "A", "A", "D"], "window": 2.5,
		"dmg": 16.0, "range": 10.0, "cd": 6.0, "cost": 0.0,
		"desc": "Disparaît et réapparaît près de chaque ennemi pour frapper, la dernière frappe repousse."},
	{"id": "celeste", "name": "Dragon céleste", "when": "en vol : attaque", "seq": [], "window": 0.0,
		"dmg": 22.0, "range": 12.0, "cd": 1.2, "cost": 0.0,
		"desc": "Fonce sur l'ennemi en frappe diagonale, le projette, pivote et frappe encore."},
	{"id": "pluie", "name": "Pluie de lames", "when": "en vol : POUVOIR", "seq": [], "window": 0.0,
		"dmg": 18.0, "range": 12.0, "cd": 8.0, "cost": 0.0,
		"desc": "S'immobilise, marque les ennemis proches, les frappe tour à tour, finit en piqué."},
	{"id": "meteore", "name": "Frappe du météore", "when": "en vol : maintenir ATTAQUE puis relâcher", "seq": [], "window": 0.0,
		"dmg": 40.0, "range": 4.5, "cd": 6.0, "cost": 0.0,
		"desc": "Monte, vise une zone au sol, plonge et frappe : onde de choc limitée à la zone."},
	{"id": "eclipse", "name": "Éclipse du dragon", "when": "ULTI (jauge pleine)", "seq": [], "window": 0.0,
		"dmg": 60.0, "range": 7.0, "cd": 0.0, "cost": 100.0,
		"desc": "Épée levée, la lumière baisse, téléportation au-dessus de la cible, frappe et onde de lumière."},
]


static func get_def(id: String) -> Dictionary:
	for d in LIST:
		if String(d["id"]) == id:
			return d
	return {}


## Renvoie l'id de la technique dont la séquence termine l'historique (ou "").
## history : [[lettre, temps_ms], ...] du plus ancien au plus récent.
static func match_sequence(history: Array, now_ms: int) -> String:
	for d in LIST:
		var seq: Array = d["seq"]
		if seq.is_empty() or history.size() < seq.size():
			continue
		var ok: bool = true
		var start: int = history.size() - seq.size()
		for k in range(seq.size()):
			if String(history[start + k][0]) != String(seq[k]):
				ok = false
				break
		if ok and now_ms - int(history[start][1]) <= int(float(d["window"]) * 1000.0):
			return String(d["id"])
	return ""
