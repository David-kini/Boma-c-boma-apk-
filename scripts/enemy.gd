extends CharacterBody3D
## Ennemi (modèles CC0 KayKit riggés : squelettes, barbare, assassin, sorcier, boss).
## Corps à corps ou à distance (boules de feu). Le boss a 3 phases : invocations puis
## onde de choc annoncée par un cercle rouge au sol. Lâche de l'or et des potions.
## États : repos -> poursuite -> attaque (préparation visible, coup, récupération)
##         touché (étourdi) -> mort. Barre de vie au-dessus de la tête.
## Il "dort" (aucun calcul) quand le joueur est à plus de 60 m.

signal died(enemy: Node)

const CombatFx = preload("res://scripts/combat_fx.gd")
const Projectile = preload("res://scripts/projectile.gd")
const Loot = preload("res://scripts/loot.gd")
const BLADE: String = "res://Assets/Characters/Skeletons/Weapons/Skeleton_Blade.gltf"
const GRAVITY: float = 22.0
const SLEEP_DIST: float = 60.0

@export var model_path: String = "res://Assets/Characters/Skeletons/Skeleton_Warrior.glb"
@export var max_hp: float = 60.0
@export var damage: float = 8.0
@export var speed: float = 3.3
@export var detect_radius: float = 16.0
@export var attack_range: float = 1.8
@export var model_scale: float = 1.3
@export var display_name: String = "Squelette"
@export var xp_value: int = 10
@export var weapon_path: String = BLADE
@export var attack_anim: String = "1H_Melee_Attack_Chop"
@export var hit_time: float = 0.55          # instant du coup dans l'animation (s)
@export var attack_time: float = 1.05       # durée totale de l'attaque (s)
@export var ranged: bool = false            # sorcier : boules de feu à distance
@export var is_boss: bool = false
@export var fire_color: Color = Color(1.0, 0.45, 0.1)
## Modèles aventuriers : ils portent tous leurs accessoires ; on ne garde que ceux-ci.
@export var keep_props: PackedStringArray = PackedStringArray()
@export var tint: Color = Color(1, 1, 1)   # teinte "ennemie" (assombrit le modèle)
## Ennemi volant (ailes de démon) : vole à la hauteur du joueur et peut le frapper en vol.
@export var flying: bool = false

var hp: float = 60.0
var state: String = "idle"
var player: Node3D = null
var world: Node3D = null          # pour la hauteur exacte du terrain (sécurité)
var _t: float = 0.0
var _hit_done: bool = false
var _cooldown: float = 0.0
var _ap: AnimationPlayer = null
var _model: Node3D = null
var _bar_fg: MeshInstance3D = null
var _bar_root: Node3D = null
var _cur_anim: String = ""
var phase: int = 1
var _special_cd: float = 4.0
var _ring: MeshInstance3D = null


func _ready() -> void:
	add_to_group("enemies")
	if is_boss:
		add_to_group("boss")
	hp = max_hp
	collision_layer = 4
	collision_mask = 1 | 2 | 4
	var cs: CollisionShape3D = CollisionShape3D.new()
	var cap: CapsuleShape3D = CapsuleShape3D.new()
	cap.radius = 0.38 * model_scale / 1.3
	cap.height = 1.7 * model_scale / 1.3
	cs.shape = cap
	cs.position = Vector3(0.0, cap.height * 0.5, 0.0)
	add_child(cs)
	_model = (load(model_path) as PackedScene).instantiate() as Node3D
	_model.rotation.y = PI          # les modèles glTF regardent vers +Z, nous vers -Z
	_model.scale = Vector3.ONE * model_scale
	add_child(_model)
	_ap = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for a in ["Idle", "Idle_Combat", "Running_A", "Running_B", "Walking_D_Skeletons", "2H_Melee_Idle"]:
		if _ap != null and _ap.has_animation(a):
			_ap.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	_attach_weapon()
	if flying:
		_attach_wings()
	_build_bar()
	_play("Idle")


func _attach_weapon() -> void:
	var sk: Skeleton3D = null
	for n in _model.find_children("*", "Skeleton3D", true, false):
		sk = n as Skeleton3D
		break
	if sk == null or sk.find_bone("handslot.r") < 0:
		return
	if not keep_props.is_empty():
		for mi in _model.find_children("*", "MeshInstance3D", true, false):
			var m3: MeshInstance3D = mi as MeshInstance3D
			if m3.get_parent() is Skeleton3D:
				continue          # corps
			if not keep_props.has(String(m3.name)):
				m3.visible = false
	if tint != Color(1, 1, 1):
		for mi2 in _model.find_children("*", "MeshInstance3D", true, false):
			var g: MeshInstance3D = mi2 as MeshInstance3D
			if g.mesh == null:
				continue
			for si in range(g.mesh.get_surface_count()):
				var base: Material = g.mesh.surface_get_material(si)
				if base is StandardMaterial3D:
					var dm: StandardMaterial3D = (base as StandardMaterial3D).duplicate() as StandardMaterial3D
					dm.albedo_color = dm.albedo_color * tint
					g.set_surface_override_material(si, dm)
	if weapon_path != "" and ResourceLoader.exists(weapon_path):
		var att: BoneAttachment3D = BoneAttachment3D.new()
		sk.add_child(att)
		att.bone_name = "handslot.r"
		att.add_child((load(weapon_path) as PackedScene).instantiate())
	if is_boss and sk.find_bone("head") >= 0:
		# couronne dorée du Roi Squelette
		var ha: BoneAttachment3D = BoneAttachment3D.new()
		sk.add_child(ha)
		ha.bone_name = "head"
		var gold: StandardMaterial3D = StandardMaterial3D.new()
		gold.albedo_color = Color(1.0, 0.78, 0.2)
		gold.metallic = 0.7
		gold.roughness = 0.3
		gold.emission_enabled = true
		gold.emission = Color(0.6, 0.4, 0.05)
		var band: MeshInstance3D = MeshInstance3D.new()
		var cm: CylinderMesh = CylinderMesh.new()
		cm.top_radius = 0.42
		cm.bottom_radius = 0.38
		cm.height = 0.18
		band.mesh = cm
		band.material_override = gold
		band.position = Vector3(0.0, 0.85, 0.0)
		ha.add_child(band)
		for k in range(6):
			var a: float = float(k) / 6.0 * TAU
			var spike: MeshInstance3D = MeshInstance3D.new()
			var sp: CylinderMesh = CylinderMesh.new()
			sp.top_radius = 0.0
			sp.bottom_radius = 0.09
			sp.height = 0.28
			sp.radial_segments = 4
			spike.mesh = sp
			spike.material_override = gold
			spike.position = Vector3(cos(a) * 0.38, 1.05, sin(a) * 0.38)
			ha.add_child(spike)


func _attach_wings() -> void:
	var sk: Skeleton3D = null
	for n in _model.find_children("*", "Skeleton3D", true, false):
		sk = n as Skeleton3D
		break
	if sk == null:
		return
	var bone: String = "chest" if sk.find_bone("chest") >= 0 else ("spine" if sk.find_bone("spine") >= 0 else "")
	if bone == "":
		return
	var att: BoneAttachment3D = BoneAttachment3D.new()
	sk.add_child(att)
	att.bone_name = bone
	var w: Node3D = load("res://scripts/wings.gd").new()
	w.set("variant", "demon")
	w.position = Vector3(0.0, 0.1, -0.25)
	w.rotation.y = PI
	w.set("size_mult", 0.55)
	att.add_child(w)
	w.call("set_deployed", true)
	for a in ["Jump_Idle"]:
		if _ap != null and _ap.has_animation(a):
			_ap.get_animation(a).loop_mode = Animation.LOOP_LINEAR


func _bar_mat(c: Color) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.no_depth_test = true
	m.render_priority = 1
	return m


func _build_bar() -> void:
	_bar_root = Node3D.new()
	_bar_root.position = Vector3(0.0, 2.35 * model_scale / 1.3, 0.0)
	add_child(_bar_root)
	var bg: MeshInstance3D = MeshInstance3D.new()
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(0.9, 0.11)
	bg.mesh = q
	bg.material_override = _bar_mat(Color(0.05, 0.05, 0.06, 0.85))
	_bar_root.add_child(bg)
	_bar_fg = MeshInstance3D.new()
	var q2: QuadMesh = QuadMesh.new()
	q2.size = Vector2(0.86, 0.075)
	_bar_fg.mesh = q2
	var fm: StandardMaterial3D = _bar_mat(Color(0.9, 0.15, 0.15))
	fm.render_priority = 2
	_bar_fg.material_override = fm
	_bar_root.add_child(_bar_fg)
	_bar_root.visible = false


func _update_bar() -> void:
	var r: float = clampf(hp / max_hp, 0.0, 1.0)
	# la barre rétrécit depuis la droite (décalage en espace caméra via le billboard)
	(_bar_fg.mesh as QuadMesh).size = Vector2(0.86 * maxf(r, 0.001), 0.075)
	(_bar_fg.mesh as QuadMesh).center_offset = Vector3(-0.43 * (1.0 - r), 0.0, 0.0)
	_bar_root.visible = state != "dead" and r < 0.999 and not is_boss


func _play(anim: String, blend: float = 0.15) -> void:
	if _ap == null or not _ap.has_animation(anim) or _cur_anim == anim:
		return
	_cur_anim = anim
	_ap.play(anim, blend)


func _face(target: Vector3, delta: float, rate: float = 10.0) -> void:
	var d: Vector3 = target - global_position
	if Vector2(d.x, d.z).length() < 0.01:
		return
	var want: float = atan2(-d.x, -d.z)
	rotation.y = lerp_angle(rotation.y, want, 1.0 - exp(-rate * delta))


func _physics_process(delta: float) -> void:
	if player == null:
		var ps: Array = get_tree().get_nodes_in_group("player")
		if ps.size() > 0:
			player = ps[0] as Node3D
		return
	var to_p: Vector3 = player.global_position - global_position
	var dist: float = Vector2(to_p.x, to_p.z).length()
	# joueur en vol au-dessus : les ennemis au sol ne peuvent pas l'atteindre
	var out_of_reach: bool = to_p.y > 1.6 and bool(player.get("is_flying")) and not flying
	if dist > SLEEP_DIST and state != "dead":
		if _ap != null and _ap.is_playing():
			_ap.pause()
		return
	if _ap != null and not _ap.is_playing() and state != "dead":
		_ap.play()
	if flying and state != "dead":
		# vol : reste à 3,5 m du sol au repos, suit l'altitude du joueur en poursuite
		var gh0: float = float(world.call("ground_height", global_position.x, global_position.z)) if world != null else 0.0
		var want_y: float = gh0 + 3.5
		if state != "idle":
			want_y = maxf(gh0 + 1.2, player.global_position.y + 0.3)
		want_y += sin(Time.get_ticks_msec() * 0.003 + float(get_instance_id() % 7)) * 0.3
		velocity.y = clampf((want_y - global_position.y) * 2.5, -8.0, 8.0)
	elif not is_on_floor():
		velocity.y -= GRAVITY * delta
	_t += delta
	_cooldown -= delta
	var hv: Vector3 = Vector3.ZERO
	var player_dead: bool = bool(player.get("is_dead"))
	match state:
		"idle":
			_play("Idle")
			if dist < detect_radius and not player_dead:
				state = "chase"
		"chase":
			if player_dead or dist > detect_radius * 1.8:
				state = "idle"
			elif is_boss and phase >= 2 and _special_cd <= 0.0 and dist < 9.0:
				_start_slam()
			elif out_of_reach:
				pass        # il regarde le joueur voler au-dessus de lui, sans pouvoir frapper
			elif ranged and dist <= 13.0 and dist > attack_range and _cooldown <= 0.0:
				state = "cast"
				_t = 0.0
				_hit_done = false
				_cur_anim = ""
				_play("Spellcast_Shoot", 0.1)
			elif dist <= attack_range and _cooldown <= 0.0:
				state = "attack"
				_t = 0.0
				_hit_done = false
				_cur_anim = ""
				_play(attack_anim, 0.1)
			else:
				_face(player.global_position, delta)
				var dir: Vector3 = Vector3(to_p.x, 0.0, to_p.z).normalized()
				var keep: float = 9.0 if ranged else attack_range * 0.8
				hv = dir * speed if dist > keep else Vector3.ZERO
				if flying:
					_play("Jump_Idle" if _ap != null and _ap.has_animation("Jump_Idle") else "Idle_Combat")
				else:
					_play("Running_A" if hv.length() > 0.1 else "Idle_Combat")
		"attack":
			if _t < 0.45:
				_face(player.global_position, delta, 6.0)
			if not _hit_done and _t >= hit_time:
				_hit_done = true
				var fwd: Vector3 = -global_transform.basis.z
				if dist <= attack_range + 0.6 and absf(to_p.y) < 1.6 and fwd.dot(Vector3(to_p.x, 0.0, to_p.z).normalized()) > 0.3:
					player.call("take_damage", damage, global_position)
			if _t >= attack_time:
				state = "chase"
				_cooldown = 1.1 if not is_boss else 0.6
		"cast":
			_face(player.global_position, delta, 8.0)
			if not _hit_done and _t >= 0.6:
				_hit_done = true
				_shoot()
			if _t >= 1.2:
				state = "chase"
				_cooldown = 2.2
		"slam":
			_update_slam(delta)
		"hit":
			velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
			if _t >= 0.4:
				state = "chase"
		"dead":
			velocity.x = 0.0
			velocity.z = 0.0
			if _t > 3.5:
				queue_free()
	_special_cd -= delta
	if state != "hit":
		velocity.x = hv.x
		velocity.z = hv.z
	move_and_slide()
	# sécurité : si le sol n'a pas encore sa collision, on suit la hauteur du terrain
	if world != null:
		var gh: float = float(world.call("ground_height", global_position.x, global_position.z))
		if global_position.y < gh - 0.3:
			global_position.y = gh
			velocity.y = 0.0


## Appelé par l'épée du joueur.
func take_damage(amount: float, from_pos: Vector3) -> void:
	if state == "dead":
		return
	hp -= amount
	var head: Vector3 = global_position + Vector3(0.0, 1.5 * model_scale / 1.3, 0.0)
	CombatFx.spark(get_parent(), head + Vector3(0.0, -0.3, 0.0), Color(0.45, 0.75, 1.0), 0.9)
	CombatFx.number(get_parent(), head + Vector3(0.0, 0.5, 0.0), int(round(amount)))
	_update_bar()
	if hp <= 0.0:
		state = "dead"
		_t = 0.0
		_cur_anim = ""
		_play("Death_A", 0.1)
		collision_layer = 0
		collision_mask = 1
		_bar_root.visible = false
		Sfx.play("enemy_die")
		_drop_loot()
		if _ring != null:
			_ring.queue_free()
			_ring = null
		if player != null and player.has_method("add_xp"):
			player.call("add_xp", xp_value)
			CombatFx.number(get_parent(), head + Vector3(0.0, 0.9, 0.0), xp_value, Color(0.5, 1.0, 0.6))
		died.emit(self)
		return
	if is_boss:
		_check_phase()
		return
	if state == "slam" or state == "cast":
		return
	state = "hit"
	_t = 0.0
	_cur_anim = ""
	_play("Hit_A", 0.05)
	var push: Vector3 = global_position - from_pos
	push.y = 0.0
	var knock: Vector3 = push.normalized() * 5.0
	velocity.x = knock.x
	velocity.z = knock.z


# ================================================================ distance, boss, butin

func _shoot() -> void:
	if player == null:
		return
	var pr: Node3D = Projectile.new()
	pr.set("damage", damage)
	pr.set("color", fire_color)
	pr.set("world", world)
	var from: Vector3 = global_position + Vector3(0.0, 1.4 * model_scale / 1.3, 0.0)
	var target: Vector3 = player.global_position + Vector3(0.0, 1.0, 0.0)
	pr.set("dir", (target - from).normalized())
	get_parent().add_child(pr)
	pr.global_position = from


func _check_phase() -> void:
	var r: float = hp / max_hp
	var new_phase: int = 3 if r < 0.3 else (2 if r < 0.6 else 1)
	if new_phase > phase:
		phase = new_phase
		speed *= 1.2
		_summon(2 if phase == 2 else 3)
		_special_cd = 1.5
		if player != null:
			var hud_msg: String = "Le Roi Squelette appelle ses serviteurs !" if phase == 2 else "Le Roi Squelette entre en furie !"
			player.emit_signal("announce", hud_msg)


func _summon(n: int) -> void:
	for k in range(n):
		var e: CharacterBody3D = load("res://scripts/enemy.gd").new()
		e.set("model_path", "res://Assets/Characters/Skeletons/Skeleton_Minion.glb")
		e.set("max_hp", 35.0)
		e.set("damage", 6.0)
		e.set("speed", 3.8)
		e.set("model_scale", 1.2)
		e.set("display_name", "Serviteur")
		e.set("xp_value", 8)
		e.set("world", world)
		var a: float = float(k) / float(n) * TAU
		get_parent().add_child(e)
		e.global_position = global_position + Vector3(cos(a) * 4.0, 0.5, sin(a) * 4.0)
		CombatFx.spark(get_parent(), e.global_position + Vector3(0.0, 1.0, 0.0), Color(0.6, 0.2, 1.0), 1.4)


## Onde de choc : un cercle rouge grandit 1,3 s au sol, puis frappe tout ce qui est dedans.
func _start_slam() -> void:
	state = "slam"
	_t = 0.0
	_hit_done = false
	_cur_anim = ""
	_play("2H_Melee_Attack_Spin" if _ap != null and _ap.has_animation("2H_Melee_Attack_Spin") else attack_anim, 0.1)
	_ring = MeshInstance3D.new()
	var tor: TorusMesh = TorusMesh.new()
	tor.inner_radius = 0.9
	tor.outer_radius = 1.0
	tor.rings = 48
	tor.ring_segments = 4
	_ring.mesh = tor
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1.0, 0.1, 0.1, 0.8)
	_ring.material_override = m
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().add_child(_ring)
	_ring.global_position = global_position + Vector3(0.0, 0.15, 0.0)
	_ring.scale = Vector3(0.5, 0.15, 0.5)


func _update_slam(_delta: float) -> void:
	const RADIUS: float = 7.0
	if _ring != null:
		var k: float = clampf(_t / 1.3, 0.0, 1.0)
		_ring.scale = Vector3(RADIUS * k, 0.15, RADIUS * k)
	if not _hit_done and _t >= 1.3:
		_hit_done = true
		if _ring != null:
			_ring.queue_free()
			_ring = null
		for k in range(10):
			var a: float = float(k) / 10.0 * TAU
			CombatFx.spark(get_parent(), global_position + Vector3(cos(a) * RADIUS * 0.8, 0.4, sin(a) * RADIUS * 0.8), Color(1.0, 0.25, 0.15), 1.6)
		Sfx.play("lightning", 0.6)
		if player != null:
			var d: float = Vector2(player.global_position.x - global_position.x, player.global_position.z - global_position.z).length()
			var dy: float = player.global_position.y - global_position.y
			if d < RADIUS and dy < 2.5:
				player.call("take_damage", damage * 1.6, global_position)
			var cam: Node = player.get("cam")
			if cam != null:
				cam.call("shake", 0.5)
	if _t >= 1.9:
		state = "chase"
		_special_cd = 6.0 if phase == 2 else 4.0


func _drop_loot() -> void:
	var gold: int = randi_range(1, 4) * (20 if is_boss else 1)
	_spawn_loot("or", gold, Vector3(0.4, 0.0, 0.0))
	var potions: int = 3 if is_boss else (1 if randf() < 0.3 else 0)
	for k in range(potions):
		_spawn_loot("potion", 1, Vector3(-0.4, 0.0, 0.5 * float(k)))


func _spawn_loot(kind: String, amount: int, off: Vector3) -> void:
	var l: Node3D = Loot.new()
	l.set("kind", kind)
	l.set("amount", amount)
	get_parent().add_child(l)
	l.global_position = global_position + off
