extends Node3D
## Place les ennemis dans le monde et les fait réapparaître (40 s après leur mort,
## seulement si le joueur est loin, pour ne pas les voir surgir).

const Enemy = preload("res://scripts/enemy.gd")
const WorldData = preload("res://scripts/world_data.gd")
const SK: String = "res://Assets/Characters/Skeletons/"
const RESPAWN_TIME: float = 40.0

var world: Node3D = null
## [modèle, position x, z, pv, dégâts, vitesse, échelle, nom]
var slots: Array = []
var _alive: Dictionary = {}     # indice -> ennemi
var _dead_t: Dictionary = {}    # indice -> temps depuis la mort
var _check: float = 0.0


func setup(w: Node3D) -> void:
	world = w
	var m: Vector2 = WorldData.ZONES["monstres"]["center"]
	var ru: Vector2 = WorldData.ZONES["ruines"]["center"]
	var bo: Vector2 = WorldData.ZONES["boss"]["center"]
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
		# gardien du repaire (aperçu du boss) : grand, lent, très résistant
		["Skeleton_Warrior", bo + Vector2(0.0, 8.0), 400.0, 18.0, 2.6, 2.6, "Gardien du repaire"],
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
	e.set("model_path", SK + String(s[0]) + ".glb")
	e.set("max_hp", float(s[2]))
	e.set("damage", float(s[3]))
	e.set("speed", float(s[4]))
	e.set("model_scale", float(s[5]))
	e.set("display_name", String(s[6]))
	e.set("world", world)
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
		if float(_dead_t[i]) >= RESPAWN_TIME and Vector2(pp.x, pp.z).distance_to(sp) > 45.0:
			_spawn(i)
