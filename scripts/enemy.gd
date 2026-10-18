extends CharacterBody3D
## Ennemi squelette (modèle CC0 KayKit, riggé, animations incluses).
## États : repos -> poursuite -> attaque (préparation visible, coup, récupération)
##         touché (étourdi) -> mort. Barre de vie au-dessus de la tête.
## Il "dort" (aucun calcul) quand le joueur est à plus de 60 m.

signal died(enemy: Node)

const CombatFx = preload("res://scripts/combat_fx.gd")
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


func _ready() -> void:
	add_to_group("enemies")
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
	for a in ["Idle", "Idle_Combat", "Running_A", "Walking_D_Skeletons"]:
		if _ap != null and _ap.has_animation(a):
			_ap.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	_attach_weapon()
	_build_bar()
	_play("Idle")


func _attach_weapon() -> void:
	var sk: Skeleton3D = null
	for n in _model.find_children("*", "Skeleton3D", true, false):
		sk = n as Skeleton3D
		break
	if sk == null or sk.find_bone("handslot.r") < 0 or not ResourceLoader.exists(BLADE):
		return
	var att: BoneAttachment3D = BoneAttachment3D.new()
	sk.add_child(att)
	att.bone_name = "handslot.r"
	att.add_child((load(BLADE) as PackedScene).instantiate())


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
	_bar_root.visible = state != "dead" and r < 0.999


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
	if dist > SLEEP_DIST and state != "dead":
		if _ap != null and _ap.is_playing():
			_ap.pause()
		return
	if _ap != null and not _ap.is_playing() and state != "dead":
		_ap.play()
	if not is_on_floor():
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
			elif dist <= attack_range and _cooldown <= 0.0:
				state = "attack"
				_t = 0.0
				_hit_done = false
				_cur_anim = ""
				_play("1H_Melee_Attack_Chop", 0.1)
			else:
				_face(player.global_position, delta)
				var dir: Vector3 = Vector3(to_p.x, 0.0, to_p.z).normalized()
				hv = dir * speed if dist > attack_range * 0.8 else Vector3.ZERO
				_play("Running_A" if hv.length() > 0.1 else "Idle_Combat")
		"attack":
			if _t < 0.45:
				_face(player.global_position, delta, 6.0)
			if not _hit_done and _t >= 0.55:
				_hit_done = true
				var fwd: Vector3 = -global_transform.basis.z
				if dist <= attack_range + 0.6 and fwd.dot(Vector3(to_p.x, 0.0, to_p.z).normalized()) > 0.3:
					player.call("take_damage", damage, global_position)
			if _t >= 1.05:
				state = "chase"
				_cooldown = 1.1
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
		died.emit(self)
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
