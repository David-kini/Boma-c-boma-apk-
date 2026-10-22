extends Node3D
## Place les ennemis dans le monde et les fait réapparaître (40 s après leur mort,
## seulement si le joueur est loin, pour ne pas les voir surgir).

const Enemy = preload("res://scripts/enemy.gd")
const WorldData = preload("res://scripts/world_data.gd")
const SK: String = "res://Assets/Characters/Skeletons/"
const AD: String = "res://Assets/Characters/Adventurers/"
const RESPAWN_TIME: float = 25.0
const BOSS_RESPAWN: float = 120.0

## Types spéciaux (options passées à l'ennemi en plus des valeurs de base).
const BARBARE: Dictionary = {"path": AD + "Barbarian.glb", "weapon_path": "", "keep_props": ["2H_Axe", "Barbarian_Hat", "Barbarian_Cape"],
	"attack_anim": "2H_Melee_Attack_Chop", "hit_time": 0.7, "attack_time": 1.35, "attack_range": 2.2, "tint": Color(0.85, 0.7, 0.7)}
const ASSASSIN: Dictionary = {"path": AD + "Rogue.glb", "weapon_path": "", "keep_props": ["Knife", "Knife_Offhand", "Rogue_Cape"],
	"attack_anim": "Dualwield_Melee_Attack_Stab", "hit_time": 0.35, "attack_time": 0.75, "detect_radius": 20.0, "tint": Color(0.6, 0.6, 0.75)}
const SORCIER: Dictionary = {"path": AD + "Mage.glb", "weapon_path": "", "keep_props": ["2H_Staff", "Mage_Hat", "Mage_Cape"],
	"attack_anim": "2H_Melee_Attack_Chop", "ranged": true, "detect_radius": 18.0, "tint": Color(0.75, 0.6, 0.8),
	"fire_color": Color(1.0, 0.4, 0.1)}
const SPECTRE: Dictionary = {"path": SK + "Skeleton_Rogue.glb", "flying": true, "detect_radius": 22.0, "xp": 25}
const GARDIEN: Dictionary = {"path": AD + "Barbarian.glb", "weapon_path": "", "keep_props": ["2H_Axe", "Barbarian_Hat", "Barbarian_Cape"],
	"attack_anim": "2H_Melee_Attack_Chop", "hit_time": 1.05, "attack_time": 2.4, "attack_range": 4.0, "tint": Color(0.75, 0.8, 0.95),
	"is_boss": true, "boss_kind": "gardien", "detect_radius": 22.0, "xp": 500}
const REINE: Dictionary = {"path": AD + "Rogue.glb", "weapon_path": "", "keep_props": ["Knife", "Knife_Offhand", "Rogue_Cape"],
	"attack_anim": "Dualwield_Melee_Attack_Stab", "hit_time": 0.35, "attack_time": 0.8, "tint": Color(0.6, 0.95, 0.6), "ranged": true,
	"fire_color": Color(0.4, 1.0, 0.4), "is_boss": true, "boss_kind": "reine", "detect_radius": 24.0, "xp": 500}
const OMBRE: Dictionary = {"path": AD + "Rogue.glb", "weapon_path": "", "keep_props": ["Knife", "Knife_Offhand", "Rogue_Cape"],
	"attack_anim": "Dualwield_Melee_Attack_Stab", "hit_time": 0.4, "attack_time": 0.85, "tint": Color(0.35, 0.25, 0.5), "ranged": true,
	"fire_color": Color(0.6, 0.2, 1.0), "is_boss": true, "boss_kind": "ombre", "detect_radius": 22.0, "xp": 550}
const NUAGES: Dictionary = {"path": SK + "Skeleton_Mage.glb", "weapon_path": SK + "Weapons/Skeleton_Staff.gltf", "flying": true,
	"ranged": true, "fire_color": Color(0.5, 0.8, 1.0), "is_boss": true, "boss_kind": "nuages", "detect_radius": 45.0, "xp": 650}
const ROI: Dictionary = {"weapon_path": SK + "Weapons/Skeleton_Axe.gltf", "is_boss": true, "attack_range": 3.2,
	"hit_time": 0.55, "attack_time": 1.05, "detect_radius": 22.0, "xp": 600}

var world: Node3D = null
## [modèle, position x, z, pv, dégâts, vitesse, échelle, nom, (options)]
var slots: Array = []
var _alive: Dictionary = {}     # indice -> ennemi
var _dead_t: Dictionary = {}    # indice -> temps depuis la mort
var _check: float = 0.0


func setup(w: Node3D) -> void:
	world = w
	var m: Vector2 = WorldData.ZONES["monstres"]["center"]
	var ru: Vector2 = WorldData.ZONES["ruines"]["center"]
	var bo: Vector2 = WorldData.ZONES["boss"]["center"]
	var vo: Vector2 = WorldData.ZONES["volcan"]["center"] + Vector2(70.0, -55.0)
	var fo: Vector2 = WorldData.ZONES["foret"]["center"] + Vector2(-30.0, 28.0)
	var ro: Vector2 = WorldData.ZONES["rochers"]["center"] + Vector2(-30.0, 8.0)
	var pn: Vector2 = WorldData.ZONES["pins"]["center"]
	var bs: Vector2 = WorldData.ZONES["bois_sombre"]["center"]
	var mo: Vector2 = WorldData.PEAKS_CENTER + Vector2(5.0, 30.0)
	var vi: Vector2 = WorldData.VILLAGE
	var plan: Array = [
		["Skeleton_Warrior", m + Vector2(0.0, 30.0), 60.0, 8.0, 3.3, 1.3, "Squelette guerrier"],
		["Skeleton_Minion", m + Vector2(-8.0, 24.0), 40.0, 6.0, 3.8, 1.2, "Squelette"],
		["Skeleton_Rogue", m + Vector2(8.0, 24.0), 45.0, 7.0, 4.2, 1.25, "Squelette voleur"],
		["Skeleton_Minion", m + Vector2(-15.0, 0.0), 40.0, 6.0, 3.8, 1.2, "Squelette"],
		["Skeleton_Warrior", m + Vector2(14.0, -6.0), 60.0, 8.0, 3.3, 1.3, "Squelette guerrier"],
		["Skeleton_Mage", m + Vector2(0.0, -16.0), 50.0, 10.0, 3.0, 1.3, "Squelette mage"],
		["Skeleton_Minion", ru + Vector2(12.0, 18.0), 40.0, 6.0, 3.8, 1.2, "Squelette"],
		["Skeleton_Rogue", ru + Vector2(-16.0, 10.0), 45.0, 7.0, 4.2, 1.25, "Squelette voleur"],
		["Skeleton_Warrior", ru + Vector2(4.0, -20.0), 60.0, 8.0, 3.3, 1.3, "Squelette guerrier"],
		# le Roi Squelette, boss du repaire (3 phases)
		["Skeleton_Warrior", bo + Vector2(0.0, 8.0), 1200.0, 20.0, 2.8, 2.8, "Roi Squelette", ROI],
		["Skeleton_Warrior", bo + Vector2(-10.0, 22.0), 70.0, 9.0, 3.3, 1.3, "Garde royal"],
		["Skeleton_Warrior", bo + Vector2(10.0, 22.0), 70.0, 9.0, 3.3, 1.3, "Garde royal"],
		# zone volcanique : barbares (lents, très résistants, gros dégâts)
		["", vo, 160.0, 16.0, 2.9, 1.25, "Barbare", BARBARE],
		["", vo + Vector2(10.0, 8.0), 160.0, 16.0, 2.9, 1.25, "Barbare", BARBARE],
		["", vo + Vector2(-8.0, 12.0), 50.0, 10.0, 3.0, 1.2, "Sorcier", SORCIER],
		# forêt : assassins (très rapides, faibles)
		["", fo, 55.0, 7.0, 5.6, 1.15, "Assassin", ASSASSIN],
		["", fo + Vector2(8.0, -6.0), 55.0, 7.0, 5.6, 1.15, "Assassin", ASSASSIN],
		["", fo + Vector2(-9.0, -4.0), 55.0, 7.0, 5.6, 1.15, "Assassin", ASSASSIN],
		# zone rocheuse : sorciers (boules de feu à distance)
		["", ro, 50.0, 10.0, 3.0, 1.2, "Sorcier", SORCIER],
		["", ro + Vector2(9.0, 9.0), 50.0, 10.0, 3.0, 1.2, "Sorcier", SORCIER],
		["", ro + Vector2(-6.0, -10.0), 160.0, 16.0, 2.9, 1.25, "Barbare", BARBARE],
		# forêt de pins : voleurs et assassins embusqués
		["Skeleton_Rogue", pn + Vector2(20.0, 10.0), 45.0, 7.0, 4.2, 1.25, "Squelette voleur"],
		["Skeleton_Rogue", pn + Vector2(-18.0, 16.0), 45.0, 7.0, 4.2, 1.25, "Squelette voleur"],
		["", pn + Vector2(10.0, -22.0), 55.0, 7.0, 5.6, 1.15, "Assassin", ASSASSIN],
		["", pn + Vector2(-25.0, -12.0), 55.0, 7.0, 5.6, 1.15, "Assassin", ASSASSIN],
		["Skeleton_Warrior", pn + Vector2(30.0, -5.0), 60.0, 8.0, 3.3, 1.3, "Squelette guerrier"],
		# bois sombre : mages squelettes et sorciers
		["Skeleton_Mage", bs + Vector2(14.0, 6.0), 50.0, 10.0, 3.0, 1.3, "Squelette mage"],
		["Skeleton_Mage", bs + Vector2(-12.0, 10.0), 50.0, 10.0, 3.0, 1.3, "Squelette mage"],
		["", bs + Vector2(0.0, -16.0), 50.0, 10.0, 3.0, 1.2, "Sorcier", SORCIER],
		["Skeleton_Minion", bs + Vector2(18.0, -12.0), 40.0, 6.0, 3.8, 1.2, "Squelette"],
		["Skeleton_Minion", bs + Vector2(-16.0, -10.0), 40.0, 6.0, 3.8, 1.2, "Squelette"],
		# pics enneigés : barbares et sorcier au col
		["", mo + Vector2(0.0, 0.0), 160.0, 16.0, 2.9, 1.25, "Barbare", BARBARE],
		["", mo + Vector2(12.0, 8.0), 160.0, 16.0, 2.9, 1.25, "Barbare", BARBARE],
		["", mo + Vector2(-10.0, 12.0), 50.0, 10.0, 3.0, 1.2, "Sorcier", SORCIER],
		# renforts : ruines, zone des monstres, plaine, abords du village
		["Skeleton_Mage", ru + Vector2(-6.0, 26.0), 50.0, 10.0, 3.0, 1.3, "Squelette mage"],
		["Skeleton_Minion", ru + Vector2(24.0, -6.0), 40.0, 6.0, 3.8, 1.2, "Squelette"],
		["Skeleton_Warrior", m + Vector2(-20.0, 20.0), 60.0, 8.0, 3.3, 1.3, "Squelette guerrier"],
		["Skeleton_Rogue", m + Vector2(22.0, 8.0), 45.0, 7.0, 4.2, 1.25, "Squelette voleur"],
		["", m + Vector2(-4.0, -28.0), 160.0, 16.0, 2.9, 1.25, "Barbare", BARBARE],
		["Skeleton_Minion", Vector2(70.0, 60.0), 30.0, 5.0, 3.4, 1.2, "Squelette égaré"],
		["Skeleton_Minion", Vector2(-60.0, 60.0), 30.0, 5.0, 3.4, 1.2, "Squelette égaré"],
		["Skeleton_Rogue", Vector2(60.0, -70.0), 45.0, 7.0, 4.2, 1.25, "Squelette voleur"],
		["Skeleton_Warrior", Vector2(-70.0, -60.0), 60.0, 8.0, 3.3, 1.3, "Squelette guerrier"],
		["Skeleton_Minion", vi + Vector2(55.0, -20.0), 30.0, 5.0, 3.4, 1.2, "Squelette égaré"],
		["", Vector2(110.0, 30.0), 55.0, 7.0, 5.6, 1.15, "Assassin", ASSASSIN],
		# boss de région
		["", WorldData.PEAKS_CENTER + Vector2(5.0, 14.0), 900.0, 30.0, 2.4, 2.6, "Gardien des montagnes", GARDIEN],
		["", WorldData.ZONES["foret"]["center"] + Vector2(0.0, 12.0), 700.0, 12.0, 6.0, 1.6, "Reine de la forêt", REINE],
		["", WorldData.ZONES["bois_sombre"]["center"] + Vector2(0.0, 4.0), 800.0, 14.0, 5.0, 1.5, "Seigneur des ombres", OMBRE],
		["", WorldData.PEAKS_CENTER + Vector2(-10.0, -40.0), 900.0, 14.0, 6.0, 2.4, "Seigneur des nuages", NUAGES],
		# spectres ailés : ennemis volants (ils peuvent te frapper pendant le vol)
		["", Vector2(60.0, 30.0), 45.0, 7.0, 5.0, 1.15, "Spectre ailé", SPECTRE],
		["", mo + Vector2(-20.0, -10.0), 45.0, 7.0, 5.0, 1.15, "Spectre ailé", SPECTRE],
		["", mo + Vector2(25.0, -20.0), 45.0, 7.0, 5.0, 1.15, "Spectre ailé", SPECTRE],
		["", vo + Vector2(-20.0, 20.0), 45.0, 7.0, 5.0, 1.15, "Spectre ailé", SPECTRE],
		["", bo + Vector2(25.0, 30.0), 45.0, 7.0, 5.0, 1.15, "Spectre ailé", SPECTRE],
		["", WorldData.VILLAGE + Vector2(-20.0, 30.0), 45.0, 7.0, 5.0, 1.15, "Spectre ailé", SPECTRE],
		# deux squelettes égarés près de l'arène pour s'entraîner tout de suite
		["Skeleton_Minion", Vector2(30.0, 75.0), 30.0, 5.0, 3.4, 1.2, "Squelette égaré"],
		["Skeleton_Minion", Vector2(-28.0, 82.0), 30.0, 5.0, 3.4, 1.2, "Squelette égaré"],
	]
	slots = plan
	_add_packs()
	# les ennemis ne sont plus tous créés au départ : ils apparaissent par zone autour du joueur
	# (voir _process) et disparaissent quand on s'éloigne. Le monde reste léger.


# ================================================================ meutes supplémentaires
## Beaucoup plus d'ennemis : des meutes réparties dans toutes les zones (hors village et arène).
const PACK_TYPES: Dictionary = {
	"min": ["Skeleton_Minion", 40.0, 6.0, 3.8, 1.2, "Squelette"],
	"rog": ["Skeleton_Rogue", 45.0, 7.0, 4.2, 1.25, "Squelette voleur"],
	"war": ["Skeleton_Warrior", 60.0, 8.0, 3.3, 1.3, "Squelette guerrier"],
	"mag": ["Skeleton_Mage", 50.0, 10.0, 3.0, 1.3, "Squelette mage"],
	"bar": ["", 160.0, 16.0, 2.9, 1.25, "Barbare", "BARBARE"],
	"sor": ["", 50.0, 10.0, 3.0, 1.2, "Sorcier", "SORCIER"],
	"ass": ["", 55.0, 7.0, 5.6, 1.15, "Assassin", "ASSASSIN"],
	"spe": ["", 45.0, 7.0, 5.0, 1.15, "Spectre ailé", "SPECTRE"],
}
## [zone ou "peaks", rayon min, rayon max, types...]
const PACKS: Array = [
	["plaine", 10.0, 60.0, "min", "min", "rog", "war", "min", "rog"],
	["monstres", 8.0, 55.0, "war", "min", "rog", "mag", "min", "war", "bar", "mag"],
	["ruines", 8.0, 50.0, "min", "war", "mag", "rog", "min", "war"],
	["boss", 14.0, 60.0, "war", "war", "mag", "bar", "rog", "war"],
	["volcan", 10.0, 60.0, "bar", "sor", "bar", "sor", "spe", "bar"],
	["foret", 8.0, 55.0, "ass", "ass", "rog", "ass", "mag", "spe"],
	["rochers", 8.0, 55.0, "sor", "bar", "sor", "war", "rog", "sor"],
	["pins", 10.0, 60.0, "rog", "ass", "war", "ass", "rog", "min"],
	["bois_sombre", 8.0, 50.0, "mag", "sor", "min", "mag", "rog", "spe"],
	["peaks", 8.0, 55.0, "bar", "sor", "bar", "spe", "war", "bar"],
	["lac", 30.0, 70.0, "min", "rog", "min", "war"],
	["village", 55.0, 85.0, "min", "rog", "war", "min"],
	["arene", 75.0, 110.0, "min", "war", "rog", "min", "war", "mag"],
]


func _add_packs() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 20260
	for pk in PACKS:
		var key: String = String(pk[0])
		var center: Vector2 = WorldData.PEAKS_CENTER if key == "peaks" else WorldData.ZONES[key]["center"]
		for rep in range(2):           # chaque ligne de la liste est jouée 2 fois
			for ti in range(3, pk.size()):
				var tp: Array = PACK_TYPES[String(pk[ti])]
				var a: float = rng.randf() * TAU
				var r: float = rng.randf_range(float(pk[1]), float(pk[2]))
				var pos: Vector2 = center + Vector2(cos(a), sin(a)) * r
				if pos.distance_to(WorldData.VILLAGE) < 45.0 or pos.length() < 34.0:
					continue
				if absf(pos.x) > WorldData.HALF - 25.0 or absf(pos.y) > WorldData.HALF - 25.0:
					continue
				var row: Array = [tp[0], pos, tp[1], tp[2], tp[3], tp[4], tp[5]]
				if tp.size() > 6:
					row.append((_type_opts()[String(tp[6])] as Dictionary).duplicate())
				slots.append(row)


func _type_opts() -> Dictionary:
	return {"ASSASSIN": ASSASSIN, "BARBARE": BARBARE, "SORCIER": SORCIER, "SPECTRE": SPECTRE}


func _spawn(i: int) -> void:
	var e: CharacterBody3D = _make(slots[i])
	e.name = "Ennemi_%d" % i
	if not _is_boss_slot(i):
		# plus on avance dans les niveaux, plus les ennemis sont résistants
		var pls: Array = get_tree().get_nodes_in_group("player")
		if not pls.is_empty():
			e.set("max_hp", float(e.get("max_hp")) * (1.0 + 0.12 * float(pls[0].call("stage_index"))))
	add_child(e)
	_alive[i] = e
	_dead_t.erase(i)


## Crée un ennemi à partir d'une ligne [modèle, position, pv, dégâts, vitesse, échelle, nom, options].
func _make(s: Array) -> CharacterBody3D:
	var p: Vector2 = s[1]
	var e: CharacterBody3D = Enemy.new()
	var opt: Dictionary = s[7] if s.size() > 7 else {}
	e.set("model_path", String(opt.get("path", SK + String(s[0]) + ".glb")))
	e.set("max_hp", float(s[2]))
	e.set("damage", float(s[3]))
	e.set("speed", float(s[4]))
	e.set("model_scale", float(s[5]))
	e.set("display_name", String(s[6]))
	e.set("world", world)
	e.set("xp_value", int(opt.get("xp", int(float(s[2]) / 3.0))))
	for k in opt:
		if k == "keep_props":
			e.set(k, PackedStringArray(opt[k]))
		elif k != "path" and k != "xp":
			e.set(k, opt[k])
	e.position = Vector3(p.x, float(world.call("ground_height", p.x, p.y)) + 0.3, p.y)
	return e


## Chargement par zone : un ennemi n'existe que s'il est à moins de LOAD_DIST du joueur
## (les boss : un peu plus loin). Au-delà de UNLOAD_DIST il est retiré. Le nombre d'ennemis
## actifs est plafonné selon la qualité graphique (téléphones faibles).
const LOAD_DIST: float = 105.0
const UNLOAD_DIST: float = 150.0
const MAX_ACTIVE: Array = [18, 26, 40, 60]
var _unloaded: Dictionary = {}     # indices retirés par éloignement (pas tués)


## Boss d'un emplacement : vaincu ou pas encore au programme (niveau suivant) = absent.
func _boss_kind(i: int) -> String:
	var o: Dictionary = slots[i][7]
	var k: String = String(o.get("boss_kind", ""))
	return k if k != "" else "roi"


func _boss_blocked(i: int, pl: Node3D) -> bool:
	var kind: String = _boss_kind(i)
	if (pl.get("story") as Array).has("boss_" + kind):
		return true
	var stages: Array = pl.get("STAGES")
	var cur: int = int(pl.call("stage_index"))
	for k in range(stages.size()):
		if String(stages[k]["kind"]) == kind:
			return k > cur
	return false


func _is_boss_slot(i: int) -> bool:
	return slots[i].size() > 7 and bool((slots[i][7] as Dictionary).get("is_boss", false))


func _process(delta: float) -> void:
	_waves_process(delta)
	_check -= delta
	if _check > 0.0:
		return
	_check = 0.7
	var players: Array = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var pp: Vector3 = (players[0] as Node3D).global_position
	var pp2: Vector2 = Vector2(pp.x, pp.z)
	_dragon_check(players[0] as Node3D)
	var active: int = 0
	var want: Array = []              # [distance, indice] à créer
	for i in range(slots.size()):
		var sp: Vector2 = slots[i][1]
		var d: float = pp2.distance_to(sp)
		var boss: bool = _is_boss_slot(i)
		if boss and not _alive.has(i) and _boss_blocked(i, players[0] as Node3D):
			continue
		if _alive.has(i):
			if is_instance_valid(_alive[i]):
				var en: Node3D = _alive[i]
				var dd: float = pp2.distance_to(Vector2(en.global_position.x, en.global_position.z))
				var busy: bool = String(en.get("state")) != "idle" and String(en.get("state")) != "dead"
				if dd > UNLOAD_DIST * (1.6 if boss else 1.0) and not busy:
					en.queue_free()
					_alive.erase(i)
					_unloaded[i] = true
				else:
					active += 1
				continue
			_alive.erase(i)           # tué
			_unloaded.erase(i)
			_dead_t[i] = 0.0
		if _unloaded.has(i):
			if d < LOAD_DIST * (1.3 if boss else 1.0):
				want.append([d, i])
			continue
		if not _dead_t.has(i):
			_unloaded[i] = true       # jamais créé
			if d < LOAD_DIST * (1.3 if boss else 1.0):
				want.append([d, i])
			continue
		_dead_t[i] = float(_dead_t[i]) + _check
		var wait: float = BOSS_RESPAWN if boss else RESPAWN_TIME
		if float(_dead_t[i]) >= wait and d > 35.0:
			_dead_t.erase(i)
			_unloaded[i] = true
	want.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var cap: int = int(MAX_ACTIVE[clampi(GameSettings.quality, 0, 3)])
	var made: int = 0
	for w in want:
		var i2: int = int(w[1])
		if made >= 4:
			break
		if active >= cap and not _is_boss_slot(i2):
			break
		if _unloaded.has(i2) and float(w[0]) > 28.0:      # jamais devant le nez du joueur
			_unloaded.erase(i2)
			_spawn(i2)
			active += 1
			made += 1


# ================================================================ défi de l'arène (vagues)
## Se placer sur l'étoile dorée au centre de l'arène lance 5 vagues d'ennemis de plus en
## plus forts, qui arrivent par les 4 portes. Récompense à la fin. Sortir de l'arène arrête le défi.

const WAVES: Array = [
	[["Skeleton_Minion", 4, 40.0, 6.0, 3.8, 1.2, "Squelette"]],
	[["Skeleton_Rogue", 3, 45.0, 7.0, 4.2, 1.25, "Squelette voleur"], ["Skeleton_Minion", 2, 40.0, 6.0, 3.8, 1.2, "Squelette"]],
	[["Skeleton_Warrior", 2, 60.0, 8.0, 3.3, 1.3, "Squelette guerrier"], ["", 2, 55.0, 7.0, 5.6, 1.15, "Assassin", "ASSASSIN"],
		["Skeleton_Mage", 1, 50.0, 10.0, 3.0, 1.3, "Squelette mage"]],
	[["", 2, 160.0, 16.0, 2.9, 1.25, "Barbare", "BARBARE"], ["", 2, 50.0, 10.0, 3.0, 1.2, "Sorcier", "SORCIER"],
		["", 2, 45.0, 7.0, 5.0, 1.15, "Spectre ailé", "SPECTRE"]],
	[["Skeleton_Warrior", 1, 500.0, 18.0, 3.0, 2.2, "Champion de l'arène"], ["", 2, 55.0, 7.0, 5.6, 1.15, "Assassin", "ASSASSIN"],
		["Skeleton_Warrior", 2, 60.0, 8.0, 3.3, 1.3, "Squelette guerrier"]],
]
var wave: int = -1            # -1 = pas de défi en cours
var _wave_t: float = 0.0
var _wave_enemies: Array = []
var _wave_cd: float = 0.0


func _player() -> Node3D:
	var ps: Array = get_tree().get_nodes_in_group("player")
	return ps[0] as Node3D if not ps.is_empty() else null


func _say(text: String) -> void:
	var p: Node3D = _player()
	if p != null:
		p.emit_signal("announce", text)


func _waves_process(delta: float) -> void:
	var p: Node3D = _player()
	if p == null:
		return
	_wave_cd -= delta
	var r: float = Vector2(p.global_position.x, p.global_position.z).length()
	if wave < 0:
		if r < 3.4 and _wave_cd <= 0.0 and p.is_on_floor() and not bool(p.get("is_dead")):
			wave = 0
			_wave_t = 3.0
			_wave_enemies.clear()
			_say("DÉFI DE L'ARÈNE : vague 1 / 5 dans 3 s")
		return
	if bool(p.get("is_dead")) or r > 62.0:
		_say("Défi de l'arène abandonné")
		wave = -1
		_wave_cd = 20.0
		return
	if _wave_t > 0.0:
		_wave_t -= delta
		if _wave_t <= 0.0:
			_spawn_wave(wave)
		return
	var alive: int = 0
	for e in _wave_enemies:
		if is_instance_valid(e) and String(e.get("state")) != "dead":
			alive += 1
	if alive == 0:
		wave += 1
		if wave >= WAVES.size():
			_say("DÉFI RÉUSSI ! +100 or, +2 potions, +150 XP")
			p.call("add_item", "or", 100)
			p.call("add_item", "potion", 2)
			p.call("add_xp", 150)
			wave = -1
			_wave_cd = 60.0
		else:
			_wave_t = 4.0
			_say("Vague %d / %d dans 4 s" % [wave + 1, WAVES.size()])


func _spawn_wave(i: int) -> void:
	_say("VAGUE %d / %d !" % [i + 1, WAVES.size()])
	var opts: Dictionary = {"ASSASSIN": ASSASSIN, "BARBARE": BARBARE, "SORCIER": SORCIER, "SPECTRE": SPECTRE}
	var gate: int = 0
	for group in WAVES[i]:
		var g: Array = group
		for n in range(int(g[1])):
			var a: float = float(gate % 4) * PI * 0.5 + randf_range(-0.12, 0.12)
			gate += 1
			var pos: Vector2 = Vector2(cos(a), sin(a)) * 40.0
			var row: Array = [g[0], pos, g[2], g[3], g[4], g[5], g[6]]
			var o: Dictionary = {}
			if g.size() > 7:
				o = (opts[String(g[7])] as Dictionary).duplicate()
			o["detect_radius"] = 80.0
			row.append(o)
			var e: CharacterBody3D = _make(row)
			e.name = "Vague%d_%d" % [i, gate]
			add_child(e)
			_wave_enemies.append(e)
			load("res://scripts/combat_fx.gd").call("spark", self, e.position + Vector3(0.0, 1.0, 0.0), Color(0.7, 0.3, 1.0), 1.6)


# ================================================================ boss final
const DragonBoss = preload("res://scripts/dragon_boss.gd")
var dragon: Node3D = null


## Le Dragon des royaumes apparaît au-dessus de la Grande Arène une fois les 5 boss
## de région vaincus, tant qu'il n'a pas été battu.
func _dragon_check(pl: Node3D) -> void:
	var st: Array = pl.get("story")
	if not st.has("dragon_eveille") or st.has("boss_dragon"):
		return
	if dragon != null and is_instance_valid(dragon):
		return
	dragon = DragonBoss.new()
	dragon.set("world", world)
	add_child(dragon)
	dragon.global_position = Vector3(0.0, 40.0, 0.0)
