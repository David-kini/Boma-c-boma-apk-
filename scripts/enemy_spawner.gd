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
	for i in range(slots.size()):
		_spawn(i)


func _spawn(i: int) -> void:
	var e: CharacterBody3D = _make(slots[i])
	e.name = "Ennemi_%d" % i
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


func _process(delta: float) -> void:
	_waves_process(delta)
	_check -= delta
	if _check > 0.0:
		return
	_check = 1.0
	var players: Array = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var pp: Vector3 = (players[0] as Node3D).global_position
	_dragon_check(players[0] as Node3D)
	for i in range(slots.size()):
		if _alive.has(i) and is_instance_valid(_alive[i]):
			continue
		_alive.erase(i)
		_dead_t[i] = float(_dead_t.get(i, 0.0)) + 1.0
		var sp: Vector2 = slots[i][1]
		var wait: float = BOSS_RESPAWN if slots[i].size() > 7 and bool((slots[i][7] as Dictionary).get("is_boss", false)) else RESPAWN_TIME
		if float(_dead_t[i]) >= wait and Vector2(pp.x, pp.z).distance_to(sp) > 35.0:
			_spawn(i)


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
