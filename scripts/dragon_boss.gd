extends Node3D
## Boss final : le Dragon des royaumes (modèle CC0 Quaternius « Ultimate Monsters »).
## Combat au-dessus de la Grande Arène (la forteresse) :
## - « tour » : vole en cercle et crache des boules de feu (touchent aussi en vol) ;
## - « perché » : se pose sur une tour et lance des attaques de zone (cercles rouges
##   au sol qui explosent 1,2 s après) — c'est le moment de l'attaquer ;
## - « piqué » (dès la phase 2) : plonge sur le héros, onde de choc à l'impact ;
## - phase 3 : plus rapide, plus de zones de feu.
## Compatible avec les attaques du héros (groupe « enemies », take_damage, etc.).

signal died(enemy: Node)

const CombatFx = preload("res://scripts/combat_fx.gd")
const Projectile = preload("res://scripts/projectile.gd")
const MODEL: String = "res://Assets/Characters/Monsters/Dragon.gltf"
const SCALE: float = 4.0
const ARENA_R: float = 26.0
const FLY_H: float = 14.0

var display_name: String = "Dragon des royaumes"
var max_hp: float = 2400.0
var hp: float = 2400.0
var damage: float = 18.0
var state: String = "idle"
var phase: int = 1
var is_boss: bool = true
var flying: bool = true
var boss_kind: String = "dragon"
var hit_radius: float = 5.0
var world: Node3D = null
var player: Node3D = null
var _model: Node3D
var _ap: AnimationPlayer
var _t: float = 0.0
var _mode: String = "tour"
var _mode_t: float = 6.0
var _shot_t: float = 1.5
var _orbit_a: float = 0.0
var _perch: Vector3 = Vector3.ZERO
var _zones: Array = []          # [anneau, position, temps restant]
var _dive_target: Vector3 = Vector3.ZERO
var _dive_hit: bool = false
var _cur: String = ""


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("boss")
	hp = max_hp
	_model = (load(MODEL) as PackedScene).instantiate() as Node3D
	_model.scale = Vector3.ONE * SCALE
	_model.position = Vector3(0.0, -2.35 * SCALE, 0.0)
	_model.rotation.y = PI
	add_child(_model)
	_ap = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for a in ["Flying_Idle", "Fast_Flying"]:
		if _ap != null and _ap.has_animation(a):
			_ap.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	_play("Flying_Idle")
	for mi in _model.find_children("*", "GeometryInstance3D", true, false):
		(mi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _play(a: String) -> void:
	if _ap != null and _ap.has_animation(a) and _cur != a:
		_cur = a
		_ap.play(a, 0.2)


func _g(x: float, z: float) -> float:
	return float(world.call("ground_height", x, z)) if world != null else 0.0


func _towers() -> Array:
	var out: Array = []
	for i in range(8):
		var a: float = TAU / 8.0 * (float(i) + 0.5)
		var h: float = 22.0 + 6.0 * float(i % 2)
		var tx: float = cos(a) * 54.0
		var tz: float = sin(a) * 54.0
		var top: float = minf(_g(tx, tz), 0.0) - 1.0 + 2.0 + h
		# accroché au sommet de la tour, côté arène (la flèche reste derrière lui)
		out.append(Vector3(cos(a) * 47.0, top + 4.0, sin(a) * 47.0))
	return out


func _face(p: Vector3, delta: float, rate: float = 3.0) -> void:
	var d: Vector3 = p - global_position
	if Vector2(d.x, d.z).length() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(-d.x, -d.z), 1.0 - exp(-rate * delta))


func _process(delta: float) -> void:
	if player == null:
		var ps: Array = get_tree().get_nodes_in_group("player")
		if ps.is_empty():
			return
		player = ps[0] as Node3D
	_t += delta
	_update_zones(delta)
	if state == "dead":
		global_position.y = move_toward(global_position.y, _g(global_position.x, global_position.z) + 2.0, 12.0 * delta)
		if _t > 5.0:
			queue_free()
		return
	var pp: Vector3 = player.global_position
	if state == "idle":
		# attend au-dessus de l'arène ; se réveille quand le héros approche
		global_position = global_position.lerp(Vector3(0.0, 40.0, 0.0), 1.0 - exp(-0.5 * delta))
		rotation.y += delta * 0.3
		if Vector2(pp.x, pp.z).length() < 70.0 and not bool(player.get("is_dead")):
			state = "fight"
			_mode = "tour"
			_mode_t = 6.0
			player.emit_signal("announce", "LE DRAGON DES ROYAUMES ATTAQUE !")
			Sfx.play("thunder", 0.6)
		return
	if bool(player.get("is_dead")) or Vector2(pp.x, pp.z).length() > 110.0:
		state = "idle"
		return
	var spd: float = 1.0 if phase == 1 else (1.25 if phase == 2 else 1.55)
	_mode_t -= delta
	match _mode:
		"tour":
			_play("Fast_Flying")
			_orbit_a += delta * 0.35 * spd
			var want: Vector3 = Vector3(cos(_orbit_a) * ARENA_R, FLY_H + sin(_t * 0.7) * 2.5, sin(_orbit_a) * ARENA_R)
			global_position = global_position.lerp(want, 1.0 - exp(-1.5 * delta))
			_face(pp, delta, 4.0)
			_shot_t -= delta
			if _shot_t <= 0.0:
				_shot_t = 1.6 / spd
				_fireball(pp)
			if _mode_t <= 0.0:
				if phase >= 2 and randf() < 0.45:
					_start_dive()
				else:
					_start_perch()
		"vers_tour":
			_play("Fast_Flying")
			global_position = global_position.move_toward(_perch, 26.0 * spd * delta)
			_face(_perch, delta, 5.0)
			if global_position.distance_to(_perch) < 0.5:
				_mode = "perche"
				_mode_t = 5.5
				_shot_t = 0.6
				Sfx.play("ulti_boom", 0.5)
				player.emit_signal("announce", "Le dragon se pose sur une tour : attaque-le !")
		"perche":
			_play("Flying_Idle")
			_face(pp, delta, 3.0)
			_shot_t -= delta
			if _shot_t <= 0.0:
				_shot_t = 1.4 / spd
				# attaques de zone : cercles rouges près du héros, explosion après 1,2 s
				var n: int = 2 if phase == 1 else (3 if phase == 2 else 5)
				for k in range(n):
					var off: Vector3 = Vector3(randf_range(-6.0, 6.0), 0.0, randf_range(-6.0, 6.0)) if k > 0 else Vector3.ZERO
					var zp: Vector3 = pp + off
					zp.y = _g(zp.x, zp.z) + 0.1
					_add_zone(zp)
				_play("Headbutt")
				_cur = ""
			if _mode_t <= 0.0:
				_mode = "tour"
				_mode_t = 7.0
		"pique":
			_play("Fast_Flying")
			var to_t: Vector3 = _dive_target - global_position
			if not _dive_hit:
				global_position = global_position.move_toward(_dive_target, 40.0 * spd * delta)
				_face(_dive_target, delta, 8.0)
				if to_t.length() < 1.0:
					_dive_hit = true
					CombatFx.ring(get_parent(), _dive_target + Vector3(0.0, 0.2, 0.0), Color(1.0, 0.4, 0.15), 6.0, 0.4)
					Sfx.play("ulti_boom", 0.7)
					var d: float = Vector2(pp.x - _dive_target.x, pp.z - _dive_target.z).length()
					if d < 6.0 and absf(pp.y - _dive_target.y) < 3.0:
						player.call("take_damage", damage * 1.8, global_position)
					var cam: Node = player.get("cam")
					if cam != null:
						cam.call("shake", 0.45)
					_mode_t = 1.2
			else:
				# reste un instant au sol (vulnérable), puis remonte
				if _mode_t <= 0.0:
					global_position.y = move_toward(global_position.y, FLY_H, 14.0 * delta)
					if global_position.y > FLY_H - 1.0:
						_mode = "tour"
						_mode_t = 6.0


func _start_perch() -> void:
	var tw: Array = _towers()
	var pp: Vector3 = player.global_position
	var best: Vector3 = tw[0]
	for t in tw:
		if (t as Vector3).distance_to(pp) < best.distance_to(pp):
			best = t
	_perch = best
	_mode = "vers_tour"


func _start_dive() -> void:
	var pp: Vector3 = player.global_position
	_dive_target = Vector3(pp.x, _g(pp.x, pp.z) + 3.0, pp.z)
	_dive_hit = false
	_mode = "pique"
	_add_zone(Vector3(pp.x, _g(pp.x, pp.z) + 0.1, pp.z), 0.0, 6.0)   # zone du piqué annoncée
	player.emit_signal("announce", "Le dragon plonge !")


func _fireball(target: Vector3) -> void:
	var pr: Node3D = Projectile.new()
	pr.set("damage", damage * 0.8)
	pr.set("color", Color(1.0, 0.45, 0.1))
	pr.set("world", world)
	pr.set("hits_flying", true)
	pr.set("speed", 18.0)
	var from: Vector3 = global_position + Vector3(0.0, -0.5, 0.0) + (-global_transform.basis.z) * 3.0
	pr.set("dir", (target + Vector3(0.0, 1.0, 0.0) - from).normalized())
	get_parent().add_child(pr)
	pr.global_position = from


## Zone d'attaque annoncée au sol (cercle rouge qui se remplit), explose à la fin.
func _add_zone(p: Vector3, life: float = 1.2, r: float = 3.5) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var tor: TorusMesh = TorusMesh.new()
	tor.inner_radius = 0.85
	tor.outer_radius = 1.0
	tor.rings = 32
	tor.ring_segments = 4
	mi.mesh = tor
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1.0, 0.15, 0.1, 0.85)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().add_child(mi)
	mi.global_position = p
	mi.scale = Vector3(r, 0.2, r)
	_zones.append([mi, p, life, r])


func _update_zones(delta: float) -> void:
	for z in _zones.duplicate():
		var zr: Array = z
		zr[2] = float(zr[2]) - delta
		var mi: MeshInstance3D = zr[0]
		if float(zr[2]) <= 0.0:
			if is_instance_valid(mi):
				mi.queue_free()
			_zones.erase(z)
			if float(zr[3]) < 5.0:
				# explosion de feu
				var p: Vector3 = zr[1]
				CombatFx.ring(get_parent(), p + Vector3(0.0, 0.2, 0.0), Color(1.0, 0.45, 0.1), float(zr[3]), 0.3)
				CombatFx.spark(get_parent(), p + Vector3(0.0, 0.8, 0.0), Color(1.0, 0.5, 0.15), 1.6)
				Sfx.play("lightning", 0.7)
				if player != null:
					var pp: Vector3 = player.global_position
					if Vector2(pp.x - p.x, pp.z - p.z).length() < float(zr[3]) and pp.y - p.y < 2.5:
						player.call("take_damage", damage, p)
		elif is_instance_valid(mi):
			(mi.material_override as StandardMaterial3D).albedo_color.a = 0.5 + 0.5 * sin(_t * 18.0)


# ------------------------------------------------------------ interface « ennemi »

func take_damage(amount: float, _from_pos: Vector3) -> void:
	if state == "dead":
		return
	if state == "idle":
		state = "fight"
	hp -= amount
	CombatFx.number(get_parent(), global_position + Vector3(0.0, 2.5, 0.0), int(round(amount)))
	CombatFx.spark(get_parent(), global_position, Color(1.0, 0.7, 0.4), 1.4)
	var r: float = hp / max_hp
	var np: int = 3 if r < 0.3 else (2 if r < 0.6 else 1)
	if np > phase:
		phase = np
		player.emit_signal("announce", "Le dragon entre en furie !" if phase == 3 else "Le dragon change de tactique : il plonge !")
	if hp <= 0.0:
		state = "dead"
		_t = 0.0
		_play("Death")
		Sfx.play("enemy_die", 0.5)
		Sfx.play("thunder", 0.8)
		for z in _zones:
			if is_instance_valid(z[0]):
				z[0].queue_free()
		_zones.clear()
		remove_from_group("enemies")
		if player != null:
			player.call("add_xp", 1500)
			player.call("add_item", "or", 300)
			player.call("celebrate")
			player.call("boss_defeated", "dragon")
		died.emit(self)


func knockback(_dir: Vector3, _force: float) -> void:
	pass


func launch(_vy: float) -> void:
	pass


func air_hold(_t2: float) -> void:
	pass


func slam_down() -> void:
	pass


func _illusions_alive() -> int:
	return 0
