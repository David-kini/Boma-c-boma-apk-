extends CharacterBody3D
## Joueur : marche, course, saut (coyote time + tampon), esquive, récupération
## après une chute. Déplacement relatif à la caméra. Origine = pieds.

const PlayerRig = preload("res://scripts/player_rig.gd")
const Sword = preload("res://scripts/sword.gd")

const WALK_SPEED: float = 2.4
const RUN_SPEED: float = 6.2
const JUMP_VELOCITY: float = 8.0
const GRAVITY: float = 22.0
const MAX_FALL: float = 40.0
const DODGE_SPEED: float = 11.5
const DODGE_TIME: float = 0.35
const DODGE_COOLDOWN: float = 0.7
const HARD_LAND_SPEED: float = 13.0
const LAND_TIME: float = 0.4

var cam: Node3D = null
var world: Node3D = null
var rig: Node3D
var state: String = "idle"
var hspeed: float = 0.0
var invulnerable: bool = false
var debug_anim: String = ""             # outil de capture uniquement

var _coyote: float = 0.0
var _dodge_t: float = 0.0
var _dodge_cd: float = 0.0
var _dodge_dir: Vector3 = Vector3.ZERO
var _land_t: float = 0.0
var _fall_speed: float = 0.0
var _was_on_floor: bool = true
var face_yaw: float = 0.0


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.4
	floor_max_angle = deg_to_rad(52.0)
	var cs: CollisionShape3D = CollisionShape3D.new()
	var cap: CapsuleShape3D = CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.76
	cs.shape = cap
	cs.position = Vector3(0.0, 0.88, 0.0)
	add_child(cs)
	rig = PlayerRig.new()
	rig.name = "Rig"
	add_child(rig)
	var sword: Node3D = Sword.new()
	sword.name = "EpeeEclair"
	rig.call("equip_weapon", sword)


func _physics_process(delta: float) -> void:
	var on_floor: bool = is_on_floor()
	if on_floor:
		_coyote = 0.12
	else:
		_coyote = maxf(_coyote - delta, 0.0)
	_dodge_cd -= delta
	_land_t -= delta

	if not on_floor:
		velocity.y = maxf(velocity.y - GRAVITY * delta, -MAX_FALL)
		_fall_speed = maxf(_fall_speed, -velocity.y)
	else:
		if not _was_on_floor and _fall_speed > HARD_LAND_SPEED:
			_land_t = LAND_TIME
		_fall_speed = 0.0
	_was_on_floor = on_floor

	var mv: Vector2 = GameInput.get_move()
	var yaw: float = 0.0
	if cam != null:
		yaw = float(cam.get("yaw"))
	var wish: Vector3 = Basis(Vector3.UP, yaw) * Vector3(mv.x, 0.0, mv.y)
	wish.y = 0.0
	var has_input: bool = wish.length() > 0.1
	var facing: Vector3 = Vector3(-sin(face_yaw), 0.0, -cos(face_yaw))

	# esquive
	if GameInput.dodge_buffer > 0.0 and _dodge_cd <= 0.0 and _dodge_t <= 0.0 \
			and _land_t <= 0.0 and (on_floor or _coyote > 0.0):
		GameInput.consume_dodge()
		_dodge_t = DODGE_TIME
		_dodge_cd = DODGE_COOLDOWN
		_dodge_dir = wish.normalized() if has_input else facing

	if _dodge_t > 0.0:
		_dodge_t -= delta
		invulnerable = true
		var f: float = 0.5 + 0.5 * clampf(_dodge_t / DODGE_TIME, 0.0, 1.0)
		velocity.x = _dodge_dir.x * DODGE_SPEED * f
		velocity.z = _dodge_dir.z * DODGE_SPEED * f
	else:
		invulnerable = false
		var speed: float = RUN_SPEED if GameInput.wants_run() else WALK_SPEED
		var target: Vector3 = Vector3.ZERO
		if has_input:
			target = wish.normalized() * speed
		if _land_t > 0.0:
			target *= 0.3
		var accel: float = 28.0 if on_floor else 9.0
		velocity.x = move_toward(velocity.x, target.x, accel * delta)
		velocity.z = move_toward(velocity.z, target.z, accel * delta)
		# saut
		if GameInput.jump_buffer > 0.0 and _coyote > 0.0 and _land_t <= 0.0:
			GameInput.consume_jump()
			velocity.y = JUMP_VELOCITY
			_coyote = 0.0

	move_and_slide()

	hspeed = Vector2(velocity.x, velocity.z).length()
	var air: bool = not is_on_floor()
	if _dodge_t > 0.0:
		state = "dodge"
	elif _land_t > 0.0:
		state = "land"
	elif air:
		state = "jump" if velocity.y > 0.5 else "fall"
	elif hspeed > 4.3:
		state = "run"
	elif hspeed > 0.3:
		state = "walk"
	else:
		state = "idle"

	if _dodge_t > 0.0:
		face_yaw = atan2(-_dodge_dir.x, -_dodge_dir.z)
	elif hspeed > 0.5:
		face_yaw = atan2(-velocity.x, -velocity.z)

	# sécurité : si le joueur passe sous le terrain, on le remet en surface
	if world != null:
		var gh: float = float(world.call("ground_height", global_position.x, global_position.z))
		if global_position.y < gh - 8.0:
			global_position = Vector3(global_position.x, gh + 1.5, global_position.z)
			velocity = Vector3.ZERO


func _process(delta: float) -> void:
	rig.rotation.y = lerp_angle(rig.rotation.y, face_yaw, 1.0 - exp(-14.0 * delta))
	if debug_anim != "":
		rig.call("animate", delta, debug_anim, 6.2 if debug_anim == "run" else 2.4)
		return
	rig.call("animate", delta, state, hspeed)
