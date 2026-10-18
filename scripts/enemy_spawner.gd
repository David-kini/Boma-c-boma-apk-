extends Node3D
## Place les ennemis dans le monde et les fait réapparaître (40 s après leur mort,
## seulement si le joueur est loin, pour ne pas les voir surgir).

const Enemy = preload("res://scripts/enemy.gd")
const WorldData = preload("res://scripts/world_data.gd")
const SK: String = "res://Assets/Characters/Skeletons/"
const AD: String = "res://Assets/Characters/Adventurers/"
const RESPAWN_TIME: float = 40.0
const BOSS_RESPAWN: float = 120.0

## Types spéciaux (options passées à l'ennemi en plus des valeurs de base).
const BARBARE: Dictionary = {"path": AD + "Barbarian.glb", "weapon_path": "", "keep_props": ["2H_Axe", "Barbarian_Hat", "Barbarian_Cape"],
	"attack_anim": "2H_Melee_Attack_Chop", "hit_time": 0.7, "attack_time": 1.35, "attack_range": 2.2, "tint": Color(0.85, 0.7, 0.7)}
const ASSASSIN: Dictionary = {"path": AD + "Rogue.glb", "weapon_path": "", "keep_props": ["Knife", "Knife_Offhand", "Rogue_Cape"],
	"attack_anim": "Dualwield_Melee_Attack_Stab", "hit_time": 0.35, "attack_time": 0.75, "detect_radius": 20.0, "tint": Color(0.6, 0.6, 0.75)}
const SORCIER: Dictionary = {"path": AD + "Mage.glb", "weapon_path": "", "keep_props": ["2H_Staff", "Mage_Hat", "Mage_Cape"],
	"attack_anim": "2H_Melee_Attack_Chop", "ranged": true, "detect_radius": 18.0, "tint": Color(0.75, 0.6, 0.8),
	"fire_color": Color(1.0, 0.4, 0.1)}
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
	var vo: Vector2 = WorldData.ZONES["volcan"]["center"] + Vector2(110.0, -90.0)
	var fo: Vector2 = WorldData.ZONES["foret"]["center"] + Vector2(-45.0, 40.0)
	var ro: Vector2 = WorldData.ZONES["rochers"]["center"] + Vector2(-45.0, 10.0)
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
		# deux squelettes égarés près de l'arène pour s'entraîner tout de suite
		["Skeleton_Minion", Vector2(30.0, 75.0), 30.0, 5.0, 3.4, 1.2, "Squelette égaré"],
		["Skeleton_Minion", Vector2(-28.0, 82.0), 30.0, 5.0, 3.4, 1.2, "Squelette égaré"],
	]
	slots = plan
	for i in range(slots.size()):
		_spawn(i)


func _spawn(i: int) -> void:
	var s: Array = slots[i]
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
	e.name = "Ennemi_%d" % i
	e.position = Vector3(p.x, float(world.call("ground_height", p.x, p.y)) + 0.3, p.y)
	add_child(e)
	_alive[i] = e
	_dead_t.erase(i)


func _process(delta: float) -> void:
	_check -= delta
	if _check > 0.0:
		return
	_check = 1.0
	var players: Array = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var pp: Vector3 = (players[0] as Node3D).global_position
	for i in range(slots.size()):
		if _alive.has(i) and is_instance_valid(_alive[i]):
			continue
		_alive.erase(i)
		_dead_t[i] = float(_dead_t.get(i, 0.0)) + 1.0
		var sp: Vector2 = slots[i][1]
		var wait: float = BOSS_RESPAWN if slots[i].size() > 7 and bool((slots[i][7] as Dictionary).get("is_boss", false)) else RESPAWN_TIME
		if float(_dead_t[i]) >= wait and Vector2(pp.x, pp.z).distance_to(sp) > 45.0:
			_spawn(i)
