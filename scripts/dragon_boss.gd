extends Node3D
## Boss final : le Dragon des royaumes (modèle CC0 Quaternius « Ultimate Monsters »).
## Combat au-dessus de la Grande Arène (la forteresse) :
## - « tour » : vole en cercle et crache des boules de feu (touchent aussi en vol) ;
## - « perché » : se pose sur une tour et lance des attaques de zone (cercles rouges
##   au sol qui explosent 1,2 s après) — c'est le moment de l'attaquer ;
## - « piqué » (dès la phase 2) : plonge sur le héros, onde de choc à l'impact ;
## - phase 3 : plus rapide, plus de zones de feu, pluie de météores.
## v0.16 : corps complet construit en code autour du modèle (cou, corps, 4 pattes
## griffues, queue articulée, piques dorsales, yeux de braise, écailles sombres) et
## nouvelles attaques : souffle de feu, griffes (piqué), rafale d'ailes, météores.
## Compatible avec les attaques du héros (groupe « enemies », take_damage, etc.).

signal died(enemy: Node)

const CombatFx = preload("res://scripts/combat_fx.gd")
const Projectile = preload("res://scripts/projectile.gd")
const MODEL: String = "res://Assets/Characters/Monsters/Dragon.gltf"
const SCALE: float = 4.0
const ARENA_R: float = 26.0
const FLY_H: float = 16.0
const LAND_H: float = 7.2
const EYE_POS: Vector3 = Vector3(1.25, 2.55, -0.45)   # mètres, repère de l'os Head (Y = avant, Z = bas)
const MOUTH_POS: Vector3 = Vector3(0.0, 3.3, 1.1)      # hauteur de la tête quand les pattes touchent le sol

var display_name: String = "Dragon des royaumes"
var max_hp: float = 2400.0
var hp: float = 2400.0
var damage: float = 18.0
var state: String = "idle"
var phase: int = 1
var is_boss: bool = true
var flying: bool = true
var boss_kind: String = "dragon"
var hit_radius: float = 6.0
var preview: bool = false      # outil d'aperçu : animation seule, sans IA
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
var _skel: Skeleton3D
var _torso_bone: int = -1
var _rest_torso_y: float = 0.0
var _body: Node3D               # cou, corps, pattes, queue (suit l'os « Torso »)
var _legs: Array = []           # [pivot hanche, pivot genou, avant?]
var _tail: Array = []           # segments de queue (Node3D chaînés)
var _leg_goal: float = 0.9      # 0,9 = repliées en vol ; 0 = posées ; -0,8 = griffes en avant
var _leg_a: float = 0.9
var _mouth: Node3D
var _eyes: Array = []
var _breath: CPUParticles3D
var _breath_t: float = 0.0      # > 0 : souffle de feu en cours
var _breath_warn: float = 0.0   # > 0 : la gueule s'illumine avant le souffle
var _breath_tick: float = 0.0
var _breath_dir: Vector3 = Vector3.FORWARD
var _gust_cd: float = 4.0
var _meteor_cd: float = 8.0
var _cycle: int = 0


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
	_dress()


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
		out.append(Vector3(cos(a) * 46.0, top + 7.5, sin(a) * 46.0))
	return out


func _face(p: Vector3, delta: float, rate: float = 3.0) -> void:
	var d: Vector3 = p - global_position
	if Vector2(d.x, d.z).length() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(-d.x, -d.z), 1.0 - exp(-rate * delta))


func _process(delta: float) -> void:
	if preview:
		_t += delta
		_animate_body(delta)
		return
	if player == null:
		var ps: Array = get_tree().get_nodes_in_group("player")
		if ps.is_empty():
			return
		player = ps[0] as Node3D
	_t += delta
	_update_zones(delta)
	_animate_body(delta)
	_update_breath(delta)
	_update_meteors(delta)
	if state == "dead":
		global_position.y = move_toward(global_position.y, _g(global_position.x, global_position.z) + LAND_H - 2.5, 12.0 * delta)
		_leg_goal = 0.0
		_animate_body(delta)
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
			_leg_goal = 0.9
			_shot_t -= delta
			if _shot_t <= 0.0 and _breath_t <= 0.0 and _breath_warn <= 0.0:
				_shot_t = 1.6 / spd
				# une fois sur trois : souffle de feu au lieu d'une boule de feu
				_cycle += 1
				if _cycle % 3 == 0:
					_start_breath(pp)
				else:
					_fireball(pp)
			_try_gust(pp, delta)
			_try_meteors(pp, delta)
			if _mode_t <= 0.0 and _breath_t <= 0.0:
				if phase >= 2 and randf() < 0.45:
					_start_dive()
				else:
					_start_perch()
		"vers_tour":
			_play("Fast_Flying")
			_leg_goal = 0.25
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
			_leg_goal = 0.0
			_face(pp, delta, 3.0)
			_try_gust(pp, delta)
			_try_meteors(pp, delta)
			_shot_t -= delta
			if _shot_t <= 0.0 and _breath_t <= 0.0 and _breath_warn <= 0.0:
				_shot_t = 1.4 / spd
				_cycle += 1
				if _cycle % 2 == 0:
					# souffle de feu depuis la tour, balayé vers le héros
					_start_breath(pp)
					_shot_t = 3.2 / spd
				else:
					_zone_volley(pp)
			if _mode_t <= 0.0 and _breath_t <= 0.0:
				_mode = "tour"
				_mode_t = 7.0
		"pique":
			_play("Fast_Flying")
			var to_t: Vector3 = _dive_target - global_position
			_leg_goal = -0.8 if not _dive_hit else 0.0
			if not _dive_hit:
				global_position = global_position.move_toward(_dive_target, 40.0 * spd * delta)
				_face(_dive_target, delta, 8.0)
				if to_t.length() < 1.0:
					_dive_hit = true
					CombatFx.ring(get_parent(), _dive_target + Vector3(0.0, 0.2, 0.0), Color(1.0, 0.4, 0.15), 6.0, 0.4)
					Sfx.play("ulti_boom", 0.7)
					var d: float = Vector2(pp.x - _dive_target.x, pp.z - _dive_target.z).length()
					if d < 6.0 and pp.y - _g(pp.x, pp.z) < 4.0:
						# griffes : gros dégâts et projeté au loin
						player.call("take_damage", damage * 1.8, global_position)
						_shove(pp - _dive_target, 14.0, 6.0)
					_claw_marks(Vector3(_dive_target.x, _g(_dive_target.x, _dive_target.z) + 0.08, _dive_target.z))
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


## Attaques de zone : cercles rouges près du héros, explosion après 1,2 s.
func _zone_volley(pp: Vector3) -> void:
	var n: int = 2 if phase == 1 else (3 if phase == 2 else 5)
	for k in range(n):
		var off: Vector3 = Vector3(randf_range(-6.0, 6.0), 0.0, randf_range(-6.0, 6.0)) if k > 0 else Vector3.ZERO
		var zp: Vector3 = pp + off
		zp.y = _g(zp.x, zp.z) + 0.1
		_add_zone(zp)
	_play("Headbutt")
	_cur = ""


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
	_dive_target = Vector3(pp.x, _g(pp.x, pp.z) + LAND_H, pp.z)
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
		for m in _meteors:
			if is_instance_valid(m[0]):
				m[0].queue_free()
		_meteors.clear()
		_breath_t = 0.0
		_breath_warn = 0.0
		_breath.emitting = false
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


# ------------------------------------------------------------ apparence (v0.16)

func _mat(c: Color, rough: float = 0.75, emit: Color = Color.BLACK) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	if emit != Color.BLACK:
		m.emission_enabled = true
		m.emission = emit
		m.emission_energy_multiplier = 2.2
	return m


func _part(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _sph(r: float) -> SphereMesh:
	var m: SphereMesh = SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 12
	m.rings = 6
	return m


func _cone(r: float, h: float, seg: int = 8) -> CylinderMesh:
	var m: CylinderMesh = CylinderMesh.new()
	m.top_radius = 0.0
	m.bottom_radius = r
	m.height = h
	m.radial_segments = seg
	m.rings = 1
	return m


func _cyl(r1: float, r2: float, h: float) -> CylinderMesh:
	var m: CylinderMesh = CylinderMesh.new()
	m.top_radius = r1
	m.bottom_radius = r2
	m.height = h
	m.radial_segments = 10
	m.rings = 1
	return m


## Écailles plus sombres, yeux de braise, et un vrai corps de dragon derrière la tête :
## cou, torse, ventre clair, 4 pattes griffues, queue articulée et piques dorsales.
func _dress() -> void:
	# écailles rouge sombre : teinte du matériau d'origine (texture atlas conservée)
	for g in _model.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = g as MeshInstance3D
		for i in range(mi.get_surface_override_material_count()):
			var src: Material = mi.get_active_material(i)
			if src is StandardMaterial3D:
				var m: StandardMaterial3D = (src as StandardMaterial3D).duplicate()
				m.albedo_color = Color(0.78, 0.36, 0.3)
				mi.set_surface_override_material(i, m)
	_skel = _model.find_child("Skeleton3D", true, false) as Skeleton3D
	if _skel != null:
		_torso_bone = _skel.find_bone("Torso")
		if _torso_bone >= 0:
			_rest_torso_y = _skel.get_bone_global_rest(_torso_bone).origin.y
	var skin: StandardMaterial3D = _mat(Color(0.5, 0.15, 0.1))
	var belly: StandardMaterial3D = _mat(Color(0.86, 0.55, 0.3))
	var bone: StandardMaterial3D = _mat(Color(0.92, 0.88, 0.8), 0.5)
	var ember: StandardMaterial3D = _mat(Color(1.0, 0.75, 0.2), 0.3, Color(1.0, 0.45, 0.05))
	ember.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_body = Node3D.new()
	add_child(_body)
	# cou (relie la tête au torse), torse, ventre
	_part(_body, _cyl(1.5, 1.9, 4.2), skin, Vector3(0.0, -1.9, 2.6), Vector3(deg_to_rad(62.0), 0.0, 0.0))
	_part(_body, _sph(1.0), skin, Vector3(0.0, -2.6, 6.3), Vector3.ZERO, Vector3(2.5, 2.2, 3.9))
	_part(_body, _sph(1.0), belly, Vector3(0.0, -3.3, 5.9), Vector3.ZERO, Vector3(2.0, 1.7, 3.4))
	# piques dorsales
	for k in range(5):
		var z: float = 3.6 + float(k) * 1.45
		var y: float = -0.6 - absf(float(k) - 2.0) * 0.18
		_part(_body, _cone(0.42, 1.3 - float(k) * 0.12, 6), bone, Vector3(0.0, y, z), Vector3(deg_to_rad(-25.0), 0.0, 0.0))
	# pattes : avant (sous le cou) et arrière (sous le torse)
	for leg in [[-1.9, 4.1, true], [1.9, 4.1, true], [-2.2, 8.0, false], [2.2, 8.0, false]]:
		var hip: Node3D = Node3D.new()
		hip.position = Vector3(float(leg[0]), -3.6, float(leg[1]))
		_body.add_child(hip)
		var big: float = 1.0 if bool(leg[2]) else 1.2
		_part(hip, _sph(0.85 * big), skin, Vector3(0.0, -0.6, 0.0), Vector3.ZERO, Vector3(1.0, 1.5, 1.1))
		var knee: Node3D = Node3D.new()
		knee.position = Vector3(0.0, -1.7 * big, 0.0)
		hip.add_child(knee)
		_part(knee, _cyl(0.55 * big, 0.4 * big, 2.0 * big), skin, Vector3(0.0, -0.95 * big, 0.0))
		# pied et 3 griffes vers l'avant
		_part(knee, _sph(0.6 * big), skin, Vector3(0.0, -2.0 * big, -0.25), Vector3.ZERO, Vector3(1.0, 0.55, 1.4))
		for c in [-0.32, 0.0, 0.32]:
			_part(knee, _cone(0.24 * big, 1.2 * big, 5), bone, Vector3(float(c) * big, -2.15 * big, -1.05 * big),
				Vector3(deg_to_rad(-100.0), 0.0, 0.0))
		_legs.append([hip, knee, bool(leg[2])])
	# queue : 7 segments chaînés qui ondulent, pointe en fer de lance
	var parent: Node3D = _body
	var pos: Vector3 = Vector3(0.0, -2.4, 9.6)
	for k in range(7):
		var seg: Node3D = Node3D.new()
		seg.position = pos
		parent.add_child(seg)
		var r: float = lerpf(1.35, 0.28, float(k) / 6.0)
		_part(seg, _cyl(r * 0.8, r, 2.0), skin, Vector3(0.0, 0.0, 1.0), Vector3(deg_to_rad(90.0), 0.0, 0.0))
		if k % 2 == 0:
			_part(seg, _cone(r * 0.45, r * 1.1, 5), bone, Vector3(0.0, r * 0.9, 0.9), Vector3(deg_to_rad(-30.0), 0.0, 0.0))
		_tail.append(seg)
		parent = seg
		pos = Vector3(0.0, -0.12, 1.9)
	_part(parent, _cone(0.9, 1.8, 4), bone, Vector3(0.0, 0.0, 2.6), Vector3(deg_to_rad(90.0), 0.0, 0.0), Vector3(1.0, 1.0, 0.25))
	# yeux de braise (sur la tête : suivent l'animation via l'os « Head »)
	var head: Node3D = _body
	if _skel != null and _skel.find_bone("Head") >= 0:
		var ba: BoneAttachment3D = BoneAttachment3D.new()
		ba.bone_name = "Head"
		_skel.add_child(ba)
		head = Node3D.new()
		head.scale = Vector3.ONE / SCALE
		ba.add_child(head)
	_head = head
	for sx in [-1.0, 1.0]:
		var e: MeshInstance3D = _part(head, _sph(0.5), ember, EYE_POS * Vector3(sx, 1.0, 1.0), Vector3(0.0, 0.38 * sx, 0.0), Vector3(1.25, 0.5, 0.55))
		_eyes.append(e)
	_mouth = Node3D.new()
	_mouth.position = MOUTH_POS
	head.add_child(_mouth)
	# souffle de feu (particules légères, coupées par défaut)
	_breath = CPUParticles3D.new()
	_breath.emitting = false
	_breath.amount = 70
	_breath.lifetime = 0.7
	_breath.local_coords = false
	_breath.direction = Vector3(0.0, 0.0, -1.0)
	_breath.spread = 11.0
	_breath.initial_velocity_min = 24.0
	_breath.initial_velocity_max = 32.0
	_breath.gravity = Vector3(0.0, 2.0, 0.0)
	_breath.scale_amount_min = 1.0
	_breath.scale_amount_max = 2.2
	var curve: Curve = Curve.new()
	curve.add_point(Vector2(0.0, 0.4))
	curve.add_point(Vector2(0.5, 1.0))
	curve.add_point(Vector2(1.0, 1.6))
	_breath.scale_amount_curve = curve
	var grad: Gradient = Gradient.new()
	grad.set_color(0, Color(1.0, 0.95, 0.6, 1.0))
	grad.set_color(1, Color(0.6, 0.08, 0.02, 0.0))
	grad.add_point(0.35, Color(1.0, 0.5, 0.1, 0.9))
	_breath.color_ramp = grad
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(1.0, 1.0)
	var fm: StandardMaterial3D = StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	fm.vertex_color_use_as_albedo = true
	# flamme ronde et douce (dégradé radial) au lieu d'un carré
	var gt: GradientTexture2D = GradientTexture2D.new()
	gt.width = 32
	gt.height = 32
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	var gg: Gradient = Gradient.new()
	gg.set_color(0, Color(1, 1, 1, 1))
	gg.set_color(1, Color(1, 1, 1, 0))
	gt.gradient = gg
	fm.albedo_texture = gt
	q.material = fm
	_breath.mesh = q
	_mouth.add_child(_breath)


var _head: Node3D


## Le corps suit l'os « Torso » de l'animation ; pattes et queue bougent selon le mode.
func _animate_body(delta: float) -> void:
	if _body == null:
		return
	var bob: float = 0.0
	if _skel != null and _torso_bone >= 0:
		bob = (_skel.get_bone_global_pose(_torso_bone).origin.y - _rest_torso_y) * SCALE
	_body.position = Vector3(0.0, bob * 0.7, 0.0)
	_leg_a = lerpf(_leg_a, _leg_goal, 1.0 - exp(-4.0 * delta))
	for l in _legs:
		var hip: Node3D = l[0]
		var knee: Node3D = l[1]
		var front: bool = l[2]
		var sw: float = sin(_t * 3.0 + (0.0 if front else 1.6)) * 0.08
		# _leg_a : 0,9 repliées vers l'arrière, 0 posées, négatif = tendues en avant
		hip.rotation.x = -_leg_a * (1.1 if front else 0.9) + sw
		knee.rotation.x = absf(_leg_a) * 0.9 if _leg_a > 0.0 else -_leg_a * 0.4
	var spd: float = 2.4 if _mode == "tour" or _mode == "pique" else 1.4
	for i in range(_tail.size()):
		var seg: Node3D = _tail[i]
		seg.rotation.y = sin(_t * spd - float(i) * 0.55) * 0.16
		seg.rotation.x = 0.05 + sin(_t * spd * 0.7 - float(i) * 0.4) * 0.05
	var glow: float = 1.0 + (2.5 if _breath_warn > 0.0 or _breath_t > 0.0 else 0.0) + 0.3 * sin(_t * 6.0)
	for e in _eyes:
		((e as MeshInstance3D).material_override as StandardMaterial3D).emission_energy_multiplier = 2.0 * glow


# ------------------------------------------------------------ nouvelles attaques

## Souffle de feu : la gueule et les yeux s'illuminent 0,7 s, puis un jet de flammes
## de 2 s qui balaie lentement vers le héros. Dégâts réguliers dans un cône étroit.
func _start_breath(target: Vector3) -> void:
	_breath_warn = 0.7
	_breath_dir = (target - _mouth.global_position).normalized()
	Sfx.play("ulti_charge", 0.6)
	_play("Headbutt")
	_cur = ""


func _update_breath(delta: float) -> void:
	if _breath_warn > 0.0:
		_breath_warn -= delta
		if _breath_warn <= 0.0:
			_breath_t = 2.0
			_breath.emitting = true
			Sfx.play("fly", 0.5)
	if _breath_t <= 0.0:
		return
	_breath_t -= delta
	if player != null:
		var want: Vector3 = (player.global_position + Vector3(0.0, 0.8, 0.0) - _mouth.global_position).normalized()
		_breath_dir = _breath_dir.slerp(want, 1.0 - exp(-1.3 * delta)).normalized()
	# oriente l'émetteur : axe -Z du nœud vers la direction du souffle
	var up: Vector3 = Vector3.UP if absf(_breath_dir.y) < 0.95 else Vector3.FORWARD
	_breath.global_transform = Transform3D(Basis.looking_at(_breath_dir, up), _mouth.global_position)
	_breath_tick -= delta
	if _breath_tick <= 0.0 and player != null:
		_breath_tick = 0.25
		var to_p: Vector3 = player.global_position + Vector3(0.0, 0.8, 0.0) - _mouth.global_position
		var dist: float = to_p.length()
		if dist < 26.0 and _breath_dir.dot(to_p / maxf(dist, 0.01)) > cos(deg_to_rad(13.0)):
			player.call("take_damage", damage * 0.35, _mouth.global_position)
	if _breath_t <= 0.0:
		_breath.emitting = false


## Rafale d'ailes : si le héros est tout près, un battement repousse violemment.
func _try_gust(pp: Vector3, delta: float) -> void:
	_gust_cd -= delta
	if _gust_cd > 0.0:
		return
	var d: Vector3 = pp - global_position
	if Vector2(d.x, d.z).length() < 11.0 and absf(d.y) < 9.0:
		_gust_cd = 6.0 if phase < 3 else 4.0
		CombatFx.ring(get_parent(), global_position + Vector3(0.0, -2.0, 0.0), Color(0.9, 0.85, 0.7), 11.0, 0.45)
		CombatFx.ring(get_parent(), global_position + Vector3(0.0, -2.5, 0.0), Color(1, 1, 1, 0.7), 7.0, 0.3)
		Sfx.play("fly", 0.35)
		player.emit_signal("announce", "Rafale d'ailes !")
		player.call("take_damage", damage * 0.5, global_position)
		_shove(d, 18.0, 5.0)
		var cam: Node = player.get("cam")
		if cam != null:
			cam.call("shake", 0.3)


## Pluie de météores (phase 3) : 6 boules de feu tombent du ciel sur des cercles rouges.
var _meteors: Array = []        # [boule, cible, temps]


func _try_meteors(pp: Vector3, delta: float) -> void:
	_meteor_cd -= delta
	if phase < 3 or _meteor_cd > 0.0:
		return
	_meteor_cd = 11.0
	player.emit_signal("announce", "Pluie de météores !")
	Sfx.play("thunder", 0.9)
	for k in range(6):
		var off: Vector3 = Vector3.ZERO if k == 0 else Vector3(randf_range(-9.0, 9.0), 0.0, randf_range(-9.0, 9.0))
		var tp: Vector3 = pp + off
		tp.y = _g(tp.x, tp.z) + 0.1
		var delay: float = 1.3 + float(k) * 0.25
		_add_zone(tp, delay, 3.2)
		var b: MeshInstance3D = _part(get_parent(), _sph(0.9), _mat(Color(1.0, 0.6, 0.2), 0.3, Color(1.0, 0.35, 0.05)), tp + Vector3(0.0, 40.0, 0.0))
		(b.material_override as StandardMaterial3D).shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_meteors.append([b, tp, delay])


func _update_meteors(delta: float) -> void:
	for m in _meteors.duplicate():
		var mr: Array = m
		mr[2] = float(mr[2]) - delta
		var b: MeshInstance3D = mr[0]
		if not is_instance_valid(b):
			_meteors.erase(m)
			continue
		var tp: Vector3 = mr[1]
		b.global_position = tp + Vector3(2.0, 40.0, 0.0) * clampf(float(mr[2]) / 1.3, 0.0, 1.0)
		if float(mr[2]) <= 0.0:
			b.queue_free()
			_meteors.erase(m)


## Projette le héros (et l'arrête s'il vole bas) : direction horizontale + petite hauteur.
func _shove(dir: Vector3, force: float, up: float) -> void:
	if player == null:
		return
	var h: Vector3 = Vector3(dir.x, 0.0, dir.z)
	if h.length() < 0.1:
		h = Vector3(randf() - 0.5, 0.0, randf() - 0.5)
	h = h.normalized() * force
	player.set("velocity", Vector3(h.x, up, h.z))


## Traces de griffes au sol après le piqué (3 entailles qui s'effacent).
func _claw_marks(p: Vector3) -> void:
	var yaw: float = rotation.y
	for k in [-1.0, 0.0, 1.0]:
		var bx: MeshInstance3D = _part(get_parent(), BoxMesh.new(), _mat(Color(0.15, 0.05, 0.03)), p)
		(bx.mesh as BoxMesh).size = Vector3(0.35, 0.05, 5.0)
		bx.rotation.y = yaw + float(k) * 0.12
		bx.global_position = p + Basis(Vector3.UP, yaw) * Vector3(float(k) * 1.1, 0.0, 0.0)
		var tw: Tween = bx.create_tween()
		tw.tween_interval(4.0)
		tw.tween_property(bx, "scale", Vector3(0.01, 1.0, 1.0), 1.0)
		tw.tween_callback(bx.queue_free)
