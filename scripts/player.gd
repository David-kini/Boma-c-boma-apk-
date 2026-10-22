extends CharacterBody3D
## Joueur : marche, course, saut (coyote time + tampon), esquive (invincible),
## récupération après une chute, COMBAT : combo d'épée en 5 coups avec visée
## automatique, points de vie, énergie, mort et réapparition ; VOL magique de 10 s ;
## TRANSFORMATION DIVINE de 10 s ; 10 armes ; XP, niveaux et sauvegarde.
## Saut : simple, DOUBLE saut (salto) en l'air, saut plus haut en maintenant, SAUT LONG
## en maintenant pendant la course. TIR : vague d'énergie à distance. TP : téléportation
## derrière l'ennemi + coup (enchaînable 3 fois). ULTI : attaque finale (pluie d'éclairs).
## Déplacement relatif à la caméra. Origine = pieds.

signal hp_changed(hp: float, max_hp: float)
signal energy_changed(energy: float, max_energy: float)
signal combo_changed(count: int)
signal level_changed(level: int, xp: int, need: int)
signal announce(text: String)
signal inventory_changed(gold: int, potions: int)
signal ulti_changed(value: float)

const PlayerRig = preload("res://scripts/player_rig.gd")
const Sword = preload("res://scripts/sword.gd")
const CombatFx = preload("res://scripts/combat_fx.gd")
const Wings = preload("res://scripts/wings.gd")
const DivineAura = preload("res://scripts/divine_aura.gd")
const SpiritDemon = preload("res://scripts/spirit_demon.gd")
const Bow = preload("res://scripts/bow.gd")
const Weapons = preload("res://scripts/weapons.gd")
const SaveGame = preload("res://scripts/save_game.gd")
const PlayerShot = preload("res://scripts/player_shot.gd")
const Powers = preload("res://scripts/powers.gd")
const Combos = preload("res://scripts/combos.gd")

## Combo : durée (s), instant du coup (fraction), dégâts, portée (m), angle (cos mini,
## -1 = tout autour), élan vers l'avant (m/s)
const ATTACKS: Array = [
	{"dur": 0.40, "hit": 0.42, "dmg": 10.0, "range": 2.7, "arc": 0.25, "lunge": 5.5},
	{"dur": 0.40, "hit": 0.42, "dmg": 12.0, "range": 2.7, "arc": 0.25, "lunge": 5.5},
	{"dur": 0.52, "hit": 0.55, "dmg": 16.0, "range": 3.0, "arc": 0.15, "lunge": 6.5},      # coup sauté
	{"dur": 0.62, "hit": 0.45, "dmg": 26.0, "range": 3.3, "arc": -1.0, "lunge": 4.0},      # coup circulaire
	{"dur": 0.80, "hit": 0.50, "dmg": 32.0, "range": 3.6, "arc": -1.0, "lunge": 3.0, "aoe": true},  # salto + impact
]
const FLY_TIME: float = 10.0
const FLY_COOLDOWN: float = 5.0
const FLY_SPEED: float = 8.5
const FLY_FAST: float = 12.0
const DIVINE_TIME: float = 10.0
const AIM_RADIUS: float = 6.0

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
const DOUBLE_JUMP_VELOCITY: float = 7.6
const JUMP_HOLD_MAX: float = 0.28      # durée max où maintenir le saut le prolonge
const LONG_JUMP_SPEED: float = 11.5    # vitesse horizontale du saut long
const FLIP_TIME: float = 0.45
const SHOT_COOLDOWN: float = 0.55
const TP_RANGE: float = 14.0
const TP_COOLDOWN: float = 2.5
const TP_CHAIN: int = 3
const ULTI_MAX: float = 100.0
const ULTI_TIME: float = 1.7
const SPRINT_SPEED: float = 8.8
const PLUNGE_RADIUS: float = 4.0
const ZONE_RADIUS: float = 5.0
const TP_AIM_RANGE: float = 18.0
const TP_STRIKE_RADIUS: float = 4.0
const ULTI_RADIUS: float = 10.0
const METEOR_RADIUS: float = 4.5
const ECLIPSE_RADIUS: float = 7.0

var cam: Node3D = null
var world: Node3D = null
var rig: Node3D
var state: String = "idle"
var hspeed: float = 0.0
var invulnerable: bool = false
var debug_anim: String = ""             # outil de capture uniquement
var blob: MeshInstance3D

var _coyote: float = 0.0
var _dodge_t: float = 0.0
var _dodge_cd: float = 0.0
var _dodge_dir: Vector3 = Vector3.ZERO
var _land_t: float = 0.0
var _fall_speed: float = 0.0
var _was_on_floor: bool = true
var face_yaw: float = 0.0

# --- combat
var max_hp: float = 120.0
var hp: float = 120.0
var max_energy: float = 100.0
var energy: float = 0.0
var is_dead: bool = false
var combo_count: int = 0
var _atk_i: int = -1            # coup en cours (-1 = aucun)
var _atk_t: float = 0.0
var _atk_hit: bool = false
var _atk_queued: bool = false
var _combo_next: int = 0        # prochain coup du combo
var _combo_reset: float = 0.0
var _combo_timer: float = 0.0
var _hurt_t: float = 0.0
var _dead_t: float = 0.0
var _since_hit: float = 99.0

# --- vol, transformation, armes, progression
var level: int = 1
var xp: int = 0
var weapon_index: int = 0
var wings_variant: String = "ange"
var is_flying: bool = false
var fly_left: float = 0.0
var _fly_cd: float = 0.0
var _fly_h: float = 5.0          # altitude visée au-dessus du sol
var wings: Node3D
var is_divine: bool = false
var divine_left: float = 0.0
var divine_total: float = 10.0
var aura: Node3D
var _autosave: float = 30.0
# --- inventaire et personnalisation
const POTION_HEAL: float = 50.0
var gold: int = 0
var potions: int = 1
var coat_name: String = "Noir"
# --- saut, tir, téléportation, ultime
var _jumps: int = 0
var _jump_hold: float = 0.0
var _holding_jump: bool = false
var long_jump: bool = false
var _flip_t: float = 0.0
var _shot_cd: float = 0.0
var _pose_t: float = 0.0          # pose d'attaque hors combo (tir, téléportation)
var _pose_dur: float = 0.3
var _pose_kind: int = 1
var _tp_cd: float = 0.0
var _tp_chain: int = 0
var _tp_window: float = 0.0
var _tp_last: Node3D = null
var ulti: float = 0.0
var ulti_t: float = -1.0          # >= 0 pendant l'attaque finale
var _ulti_strikes: int = 0
var _ulti_y: float = 0.0
var _glide: bool = false
var _plunge: bool = false
var _run_t: float = 0.0
var _wall_t: float = 0.0
var _wallrun: bool = false
var _near_t: float = 0.0
var _enemy_near: bool = false
# --- pouvoirs
var power_index: int = 0
var power_cd: float = 0.0
var _zone_t: float = -1.0
var _dash_t: float = 0.0
var _dash_dir: Vector3 = Vector3.ZERO
var _dash_from: Vector3 = Vector3.ZERO
var _dash_hit: Array = []
var _shield_t: float = 0.0
var _shield_hp: float = 0.0
var shield: MeshInstance3D = null
var _combo_left: int = 0
var _combo_tick: float = 0.0
# --- téléportation ciblée
var _tp_press: bool = false
var _tp_hold: float = 0.0
var _tp_aiming: bool = false
var _aim_point: Vector3 = Vector3.ZERO
var _aim_dest: Vector3 = Vector3.ZERO
var _aim_target: Node3D = null
var _aim_ring: MeshInstance3D = null
var _aim_mark: MeshInstance3D = null
# --- techniques (machine à états « action »)
var action: String = ""
var _act_t: float = 0.0
var _act: Dictionary = {}
var _hist: Array = []
var _tech_cd: Dictionary = {}
var _charge_t: float = 0.0
var _air_press: bool = false
# --- histoire : cinématiques vues, boss vaincus
var story: Array = []
const ALL_BOSSES: Array = ["roi", "gardien", "reine", "ombre", "nuages"]


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1 | 4
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
	_load_progress()
	rig.call("set_coat_color", coat_name)
	add_child(rig)
	_equip_weapon(weapon_index, false)
	wings = Wings.new()
	wings.name = "Ailes"
	wings.set("variant", wings_variant)
	(rig.call("get_hand_mount", "chest") as Node3D).add_child(wings)
	aura = DivineAura.new()
	aura.name = "AuraDivine"
	add_child(aura)
	_set_layer(rig, 2)
	_build_blob_shadow()


## Couche de rendu 2 = personnages (éclairés par leur propre lumière, voir world.gd).
func _set_layer(node: Node, layer_bit: int) -> void:
	if node is VisualInstance3D:
		(node as VisualInstance3D).layers = layer_bit
	for ch in node.get_children():
		_set_layer(ch, layer_bit)


## Ombre douce sous les pieds (tous niveaux de qualité, très peu coûteuse).
func _build_blob_shadow() -> void:
	var grad: Gradient = Gradient.new()
	grad.set_color(0, Color(0.0, 0.0, 0.0, 0.55))
	grad.set_color(1, Color(0.0, 0.0, 0.0, 0.0))
	var tex: GradientTexture2D = GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = tex
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(1.2, 1.2)
	blob = MeshInstance3D.new()
	blob.name = "OmbreDouce"
	blob.mesh = plane
	blob.material_override = mat
	blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	blob.top_level = true
	add_child(blob)


func _update_blob() -> void:
	var from: Vector3 = global_position + Vector3(0.0, 0.5, 0.0)
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + Vector3(0.0, -30.0, 0.0), 1)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		blob.visible = false
		return
	blob.visible = true
	var hp: Vector3 = hit["position"]
	var h: float = global_position.y - hp.y
	var k: float = clampf(1.0 - h / 6.0, 0.2, 1.0)
	blob.global_position = hp + Vector3(0.0, 0.03, 0.0)
	blob.scale = Vector3(k, 1.0, k)


func _physics_process(delta: float) -> void:
	var on_floor: bool = is_on_floor()
	if on_floor:
		_coyote = 0.12
	else:
		_coyote = maxf(_coyote - delta, 0.0)
	_dodge_cd -= delta
	_land_t -= delta

	if not on_floor:
		var g: float = GRAVITY
		# saut maintenu : gravité réduite pendant la montée (saut plus haut)
		if _holding_jump:
			if GameInput.jump_held() and velocity.y > 0.0 and _jump_hold < JUMP_HOLD_MAX:
				_jump_hold += delta
				g *= 0.42
			else:
				if velocity.y > 0.0 and _jump_hold < 0.08:
					velocity.y *= 0.82     # simple tapotement : saut normal
				_holding_jump = false
		velocity.y = maxf(velocity.y - g * delta, -MAX_FALL)
		if _glide:
			velocity.y = maxf(velocity.y, -4.5)
		_fall_speed = maxf(_fall_speed, -velocity.y)
	else:
		if not _was_on_floor and _fall_speed > HARD_LAND_SPEED and not long_jump and _atk_i != 4 and not _plunge:
			_land_t = LAND_TIME
		_glide = false
		_wall_t = 0.0
		if not _was_on_floor:
			_jumps = 0
			long_jump = false
			_flip_t = 0.0
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

	_update_timers(delta)
	_update_powers(delta)
	_update_giant(delta)
	_flip_t -= delta
	_pose_t -= delta
	if ulti_t >= 0.0 and not is_dead:
		_process_ulti(delta)
		return
	if action != "" and not is_dead:
		_process_action(delta, on_floor, wish, has_input)
		return
	if is_dead:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		state = "dead"
		_dead_t -= delta
		if _dead_t <= 0.0:
			_respawn()
		return

	# bascule épée / arc (touche B, bouton du menu)
	if GameInput.bow_buffer > 0.0:
		GameInput.bow_buffer = 0.0
		_bow_auto = false
		set_bow(not bow_mode)
		announce.emit("ARC : " + String(Weapons.get_def(weapon_index)["name"]) if bow_mode else "Retour à l'épée")
	# mode arc : chaque attaque tire une flèche d'énergie qui garde le pouvoir de l'arme
	if bow_mode and (GameInput.attack_buffer > 0.0 or GameInput.attack_held()) and _dodge_t <= 0.0 and _hurt_t <= 0.0 and _shot_cd <= 0.0 and action == "":
		GameInput.consume_attack()
		_shoot()
		_shot_cd = 0.28 if not is_divine else 0.18
		return
	# attaque (combo)
	if not bow_mode and GameInput.attack_buffer > 0.0 and _dodge_t <= 0.0 and _hurt_t <= 0.0:
		if _atk_i < 0 and not _plunge:
			GameInput.consume_attack()
			_push_input("A")
			var seq: String = Combos.match_sequence(_hist, Time.get_ticks_msec())
			var air_t: Node3D = null if on_floor or is_flying else _aerial_target()
			if is_flying:
				# en vol : appui court = Dragon céleste, maintenu = Frappe du météore
				_air_press = true
				_charge_t = 0.0
			elif seq == "tempete" and _tech_ready("tempete") and _nearest_enemy(8.0) != null:
				_start_action("tempete", {"target": _nearest_enemy(8.0)})
				_hist.clear()
				return
			elif air_t != null and _tech_ready("aerienne"):
				_start_action("aerienne", {"target": air_t})
				return
			elif not on_floor and not is_flying and global_position.y - _ground_h() > 2.5:
				_start_plunge()
			elif on_floor and not is_flying and _combo_next == 4 and _tech_ready("aerienne") and _ground_launch_target() != null:
				_start_action("aerienne", {"target": _ground_launch_target()})
				return
			else:
				_start_attack(_combo_next)
		elif _atk_t > _dur(_atk_i) * 0.35:
			GameInput.consume_attack()
			_push_input("A")
			_atk_queued = true
	# attaque en vol (décidée au relâchement ou après 0,35 s de maintien)
	if _air_press:
		if not is_flying:
			_air_press = false
		elif GameInput.attack_held():
			_charge_t += delta
			if _charge_t > 0.35:
				_air_press = false
				if _tech_ready("meteore"):
					_start_action("meteore")
					return
		else:
			_air_press = false
			var tgc: Node3D = _nearest_enemy(12.0)
			if tgc != null and _tech_ready("celeste"):
				_start_action("celeste", {"target": tgc})
				return
			_start_attack(_combo_next)
	# Frappe du dragon : ATTAQUE maintenue au sol
	if on_floor and not is_flying and GameInput.attack_held() and not _air_press:
		_charge_t += delta
		if _charge_t > 0.35 and _tech_ready("dragon"):
			_charge_t = 0.0
			_start_action("charge")
			return
	elif not _air_press:
		_charge_t = 0.0
	if _atk_i >= 0:
		_process_attack(delta)
	# attaque à distance, téléportation, attaque finale
	_update_shield(delta)
	if _dash_t > 0.0:
		_process_dash(delta)
		return
	if _combo_left > 0:
		_process_combo(delta)
		return
	if _zone_t >= 0.0:
		_zone_t -= delta
		if _zone_t < 0.0:
			_zone_impact()
	if GameInput.shoot_buffer > 0.0 and _dodge_t <= 0.0 and _hurt_t <= 0.0:
		GameInput.shoot_buffer = 0.0
		if power_cd <= 0.0:
			use_power(facing)
	# téléportation : appui court = téléportation rapide ; maintenu = ciblage puis frappe de zone
	if GameInput.tp_buffer > 0.0 and _hurt_t <= 0.0 and not _tp_press:
		GameInput.tp_buffer = 0.0
		_tp_press = true
		_tp_hold = 0.0
	if _tp_press:
		if GameInput.tp_held():
			_tp_hold += delta
			if _tp_hold > 0.25:
				_update_tp_aim(delta, wish, has_input)
				move_and_slide()
				state = "guard"
				return
		else:
			_tp_press = false
			if _tp_aiming:
				_teleport_aimed()
			else:
				_teleport(facing)
				_push_input("T")
	if GameInput.ulti_buffer > 0.0:
		GameInput.ulti_buffer = 0.0
		if ulti >= ULTI_MAX:
			_start_ulti()
			return
		announce.emit("Attaque finale : jauge %d %%" % int(ulti))

	if is_flying:
		_fly_move(delta, wish, has_input)
		return
	if _plunge:
		_process_plunge(on_floor)
		return

	# esquive (annule l'attaque en cours)
	if GameInput.dodge_buffer > 0.0 and _dodge_cd <= 0.0 and _dodge_t <= 0.0 \
			and _land_t <= 0.0 and (on_floor or _coyote > 0.0):
		GameInput.consume_dodge()
		_push_input("D")
		if Combos.match_sequence(_hist, Time.get_ticks_msec()) == "fantome" and _tech_ready("fantome") and _nearest_enemy(10.0) != null:
			_hist.clear()
			_start_action("fantome")
			return
		_end_attack()
		_dodge_t = DODGE_TIME
		_dodge_cd = DODGE_COOLDOWN
		_dodge_dir = wish.normalized() if has_input else facing

	if _dodge_t > 0.0:
		_dodge_t -= delta
		invulnerable = true
		var f: float = 0.5 + 0.5 * clampf(_dodge_t / DODGE_TIME, 0.0, 1.0)
		velocity.x = _dodge_dir.x * DODGE_SPEED * f
		velocity.z = _dodge_dir.z * DODGE_SPEED * f
	elif _hurt_t > 0.0:
		invulnerable = false
		velocity.x = move_toward(velocity.x, 0.0, 18.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 18.0 * delta)
	elif _atk_i >= 0:
		invulnerable = false
		# élan vers l'avant au début du coup, presque immobile ensuite
		var a: Dictionary = ATTACKS[_atk_i]
		var lunge: float = float(a["lunge"]) if _atk_t < 0.15 else 0.0
		var fwd: Vector3 = Vector3(-sin(face_yaw), 0.0, -cos(face_yaw))
		var mv_slow: Vector3 = wish.normalized() * 0.8 if has_input else Vector3.ZERO
		velocity.x = fwd.x * lunge + mv_slow.x
		velocity.z = fwd.z * lunge + mv_slow.z
	else:
		invulnerable = false
		# course, puis course rapide (sprint) après 1 s de course continue
		if GameInput.wants_run() and has_input and on_floor:
			_run_t += delta
		elif on_floor:
			_run_t = 0.0
		var speed: float = RUN_SPEED if GameInput.wants_run() else WALK_SPEED
		if GameInput.wants_run():
			speed = lerpf(RUN_SPEED, SPRINT_SPEED, smoothstep(1.0, 1.6, _run_t))
		if is_divine:
			speed *= 1.3
		var target: Vector3 = Vector3.ZERO
		if has_input:
			target = wish.normalized() * speed
		if _land_t > 0.0:
			target *= 0.3
		_ground_move(delta, target, wish, has_input, on_floor)

	move_and_slide()
	_update_blob()

	hspeed = Vector2(velocity.x, velocity.z).length()
	var air: bool = not is_on_floor()
	if _hurt_t > 0.0:
		state = "hurt"
	elif _atk_i >= 0 or _pose_t > 0.0:
		state = "attack"
	elif _dodge_t > 0.0:
		state = "dodge"
	elif _land_t > 0.0:
		state = "land"
	elif air and _wallrun:
		state = "wallrun"
	elif air and _flip_t > 0.0:
		state = "flip"
	elif air and long_jump:
		state = "longjump"
	elif air:
		state = "jump" if velocity.y > 0.5 else "fall"
	elif hspeed > 4.3:
		state = "run"
	elif hspeed > 0.3:
		state = "walk"
	else:
		state = "guard" if _enemy_near else "idle"
	_near_t -= delta
	if _near_t <= 0.0:
		_near_t = 0.3
		_enemy_near = _nearest_enemy(11.0) != null

	if _dodge_t > 0.0:
		face_yaw = atan2(-_dodge_dir.x, -_dodge_dir.z)
	elif _atk_i >= 0 or _hurt_t > 0.0 or _pose_t > 0.0:
		pass
	elif hspeed > 0.5:
		face_yaw = atan2(-velocity.x, -velocity.z)

	# sécurité : si le joueur passe sous le terrain, on le remet en surface
	if world != null:
		var gh: float = float(world.call("ground_height", global_position.x, global_position.z))
		if global_position.y < gh - 8.0:
			global_position = Vector3(global_position.x, gh + 1.5, global_position.z)
			velocity = Vector3.ZERO


func _process(delta: float) -> void:
	var spin: float = 0.0
	if _atk_i == 3:
		# coup final : tour complet sur soi-même
		var tt: float = clampf(_atk_t / _dur(3), 0.0, 1.0)
		spin = TAU * ease(tt, 0.5)
	if spin != 0.0:
		rig.rotation.y = face_yaw + spin
	else:
		rig.rotation.y = lerp_angle(rig.rotation.y, face_yaw, 1.0 - exp(-14.0 * delta))
	# salto avant du double saut, tourné autour des hanches
	var flip: float = 0.0
	var pivot: float = 0.95
	if _flip_t > 0.0:
		flip = -TAU * ease(1.0 - _flip_t / FLIP_TIME, -1.6)
	elif _atk_i == 4 and _atk_t < 0.3:
		flip = -TAU * ease(clampf(_atk_t / 0.3, 0.0, 1.0), -1.6)     # salto avant avant l'impact
	elif _dodge_t > 0.0:
		flip = -TAU * ease(1.0 - _dodge_t / DODGE_TIME, -1.4)      # roulade
		pivot = 0.5
	rig.rotation.x = flip
	rig.position = Vector3(0.0, pivot, 0.0) - rig.basis * Vector3(0.0, pivot, 0.0)
	if debug_anim != "":
		if debug_anim.begins_with("attack"):
			rig.set("attack_kind", int(debug_anim.substr(6, 1)))
			rig.set("attack_t", float(debug_anim.substr(8)) if debug_anim.length() > 8 else 0.5)
			rig.call("animate", delta, "attack", 0.0)
			return
		rig.call("animate", delta, debug_anim, 6.2 if debug_anim == "run" else 2.4)
		return
	if _atk_i >= 0:
		rig.set("attack_kind", _atk_i)
		rig.set("attack_t", clampf(_atk_t / _dur(_atk_i), 0.0, 1.0))
	elif _pose_t > 0.0:
		rig.set("attack_kind", _pose_kind)
		rig.set("attack_t", clampf(1.0 - _pose_t / _pose_dur, 0.0, 1.0))
	if ulti_t >= 0.0:
		rig.call("animate", delta, "ultimate", 0.0)
		return
	rig.call("animate", delta, state, hspeed)


# ================================================================ combat

func _update_timers(delta: float) -> void:
	_hurt_t -= delta
	_since_hit += delta
	if _atk_i < 0:
		_combo_reset -= delta
		if _combo_reset <= 0.0:
			_combo_next = 0
	if combo_count > 0:
		_combo_timer -= delta
		if _combo_timer <= 0.0:
			combo_count = 0
			combo_changed.emit(0)
	# régénération hors combat
	if not is_dead and _since_hit > 6.0 and hp < max_hp:
		hp = minf(hp + 4.0 * delta, max_hp)
		hp_changed.emit(hp, max_hp)


## Ennemi normal tout proche (pas un boss, pas un volant) pour la projection vers le ciel.
func _ground_launch_target() -> Node3D:
	var t: Node3D = _nearest_enemy(6.0)
	if t == null or bool(t.get("is_boss")) or bool(t.get("flying")) or not t.has_method("launch"):
		return null
	return t


func _nearest_enemy(radius: float) -> Node3D:
	var best: Node3D = null
	var best_d: float = radius
	for e in get_tree().get_nodes_in_group("enemies"):
		var en: Node3D = e as Node3D
		if en == null or String(en.get("state")) == "dead":
			continue
		var d: float = en.global_position.distance_to(global_position)
		if d < best_d:
			best_d = d
			best = en
	return best


func _start_attack(i: int) -> void:
	_atk_i = i
	_atk_t = 0.0
	_atk_hit = false
	_atk_queued = false
	# visée automatique vers l'ennemi le plus proche (pratique au tactile)
	var target: Node3D = _nearest_enemy(AIM_RADIUS)
	if target != null:
		var d: Vector3 = target.global_position - global_position
		face_yaw = atan2(-d.x, -d.z)
	var w: Node = rig.get("weapon")
	if w != null:
		w.set("trail_on", true)
	Sfx.play("swing", 1.0 + 0.08 * float(i))
	# Danse de l'épée : léger mouvement latéral de caméra sur les 2 premiers coups,
	# le 2e coup pivote vers un ennemi situé derrière
	if cam != null and i < 2:
		cam.call("lateral", 0.35 if i == 0 else -0.35, 0.3)
	if i == 1:
		var back: Vector3 = Vector3(sin(face_yaw), 0.0, cos(face_yaw))
		for en in _enemies_near(global_position, 4.0):
			var de: Vector3 = en.global_position - global_position
			de.y = 0.0
			if de.normalized().dot(back) > 0.4:
				face_yaw = atan2(-de.x, -de.z)
				break
	# acrobaties : coup sauté, salto du coup final, suspension pendant les coups aériens
	if is_on_floor():
		if i == 2:
			velocity.y = 4.5
		elif i == 4:
			velocity.y = 7.0
	elif not is_flying:
		velocity.y = maxf(velocity.y, 2.5)


func _end_attack() -> void:
	if _atk_i >= 0:
		_combo_next = (_atk_i + 1) % ATTACKS.size()
		_combo_reset = 0.6
	_atk_i = -1
	var w: Node = rig.get("weapon")
	if w != null:
		w.set("trail_on", false)


func _process_attack(delta: float) -> void:
	var a: Dictionary = ATTACKS[_atk_i]
	_atk_t += delta
	var dur: float = _dur(_atk_i)
	if _atk_i == 4 and not is_flying:
		# coup final : salto puis plongeon, l'impact se produit en touchant le sol
		if not _atk_hit:
			if _atk_t >= 0.3 and not is_on_floor():
				velocity.y = minf(velocity.y, -16.0)
			if (_atk_t >= 0.3 and is_on_floor()) or _atk_t >= dur:
				_atk_hit = true
				_deal_hits(a)
				CombatFx.ring(get_parent(), global_position + Vector3(0.0, 0.15, 0.0), _weapon_color(), float(a["range"]), 0.35)
	elif not _atk_hit and _atk_t >= dur * float(a["hit"]):
		_atk_hit = true
		_deal_hits(a)
		if _atk_i == 2 and cam != null:
			cam.call("slow_mo", 0.14, 0.4)       # frappe verticale finale de la Danse de l'épée
	if _atk_t >= dur:
		var queued: bool = _atk_queued
		var nxt: int = (_atk_i + 1) % ATTACKS.size()
		_end_attack()
		if queued:
			if nxt == 4 and is_on_floor() and not is_flying and _tech_ready("aerienne") and _ground_launch_target() != null:
				_start_action("aerienne", {"target": _ground_launch_target()})
			else:
				_start_attack(nxt)


func _deal_hits(a: Dictionary) -> void:
	var fwd: Vector3 = Vector3(-sin(face_yaw), 0.0, -cos(face_yaw))
	var hits: int = 0
	for e in get_tree().get_nodes_in_group("enemies"):
		var en: Node3D = e as Node3D
		if en == null or String(en.get("state")) == "dead":
			continue
		var to_e: Vector3 = en.global_position - global_position
		to_e.y = 0.0
		var dist: float = to_e.length()
		var hr: float = _hit_r(en)
		if hr > 0.0:
			# grande cible (dragon) : portée élargie mais il faut être à sa hauteur
			if absf(en.global_position.y - global_position.y) > hr + 2.5:
				continue
			dist = maxf(0.0, dist - hr)
		if dist > float(a["range"]) * (1.0 + (giant_k - 1.0) * 0.6):
			continue
		if float(a["arc"]) > -1.0 and dist > 0.4 and fwd.dot(to_e.normalized()) < float(a["arc"]):
			continue
		var falloff: float = 1.0
		if a.has("aoe"):
			falloff = lerpf(1.3, 0.7, clampf(dist / float(a["range"]), 0.0, 1.0))
		en.call("take_damage", float(a["dmg"]) * _dmg_mult() * falloff, global_position)
		_apply_sword_power(en)
		hits += 1
	if a.has("aoe"):
		# 5e coup : éclair qui frappe tout autour
		for k in range(6):
			var ang: float = float(k) / 6.0 * TAU
			CombatFx.spark(get_parent(), global_position + Vector3(cos(ang) * 2.2, 0.4, sin(ang) * 2.2),
				Color(0.5, 0.8, 1.0) if not is_divine else Color(1.0, 0.85, 0.35), 1.3)
		Sfx.play("lightning")
		if cam != null:
			cam.call("shake", 0.45)
	if hits > 0:
		Sfx.play("hit")
		combo_count += hits
		_combo_timer = 2.2
		_weapon_wear(hits)
		combo_changed.emit(combo_count)
		energy = minf(energy + 5.0 * float(hits), max_energy)
		energy_changed.emit(energy, max_energy)
		add_ulti(4.0 * float(hits))
		if cam != null:
			cam.call("shake", 0.35 if _atk_i == 3 else 0.15)


## Pouvoir de l'épée équipée, appliqué à chaque coup : glace = gèle, éclair = paralyse (avec
## le bruit du tonnerre), feu = brûle (les flammes restent sur le corps), poison, vide = propulse
## en l'air, divin = foudre + feu. Chaque coup repousse aussi l'ennemi.
func _apply_sword_power(en: Node3D) -> void:
	if not is_instance_valid(en) or String(en.get("state")) == "dead" or not en.has_method("apply_element"):
		return
	var el: String = String(Weapons.get_def(weapon_index)["element"])
	var frozen: bool = bool(en.call("has_status", "gel")) or bool(en.call("has_status", "para"))
	if (el == "divin" or is_divine) and not en.get("is_boss"):
		# Épée Divine / forme divine : chacun des 5 coups propulse l'ennemi
		en.call("knockback", en.global_position - global_position, 13.0 + 1.5 * float(maxi(_atk_i, 0)))
	elif not frozen and not en.get("is_boss") and _atk_i >= 2:
		var dir: Vector3 = en.global_position - global_position
		en.call("knockback", dir, 11.0 if _atk_i >= 3 else 7.0)
	if el == "ombre":
		# Épée du Démon : vol de vie
		hp = minf(hp + 4.0, max_hp)
		hp_changed.emit(hp, max_hp)
		CombatFx.spark(get_parent(), global_position + Vector3(0.0, 1.2, 0.0), Color(0.9, 0.1, 0.2), 0.8)
	elif el == "divin":
		# Épée Divine : la foudre saute sur 2 autres ennemis proches
		var n: int = 0
		for o in _enemies_near(en.global_position, 8.0):
			if o == en or n >= 2 or not o.has_method("apply_element"):
				continue
			n += 1
			CombatFx.bolt(get_parent(), en.global_position + Vector3(0.0, 1.5, 0.0), o.global_position + Vector3(0.0, 1.2, 0.0), Color(1.0, 0.9, 0.5), 0.2)
			o.call("take_damage", 18.0 * _dmg_mult(), en.global_position)
			o.call("apply_element", "divin")
	if el == "vent":
		# tourbillon : les ennemis voisins valsent aussi
		for o in _enemies_near(en.global_position, 3.2):
			if o != en and o.has_method("apply_element"):
				o.call("apply_element", "vent")
	en.call("apply_element", el)


## Appelé par les ennemis.
func take_damage(amount: float, from_pos: Vector3) -> void:
	if invulnerable or is_dead:
		return
	if is_divine:
		amount *= 0.5
	if _shield_t > 0.0 and _shield_hp > 0.0:
		var absorbed: float = minf(amount, _shield_hp)
		_shield_hp -= absorbed
		amount -= absorbed
		CombatFx.spark(get_parent(), global_position + Vector3(0.0, 1.2, 0.0), Color(0.4, 0.8, 1.0), 0.9)
		Sfx.play("hit", 1.6)
		if amount <= 0.0:
			return
	Sfx.play("hurt")
	hp = maxf(hp - amount, 0.0)
	_since_hit = 0.0
	hp_changed.emit(hp, max_hp)
	CombatFx.spark(get_parent(), global_position + Vector3(0.0, 1.2, 0.0), Color(1.0, 0.3, 0.25), 0.7)
	CombatFx.number(get_parent(), global_position + Vector3(0.0, 2.1, 0.0), int(round(amount)), Color(1.0, 0.35, 0.3))
	if cam != null:
		cam.call("shake", 0.3)
	_end_attack()
	if hp <= 0.0:
		is_dead = true
		_dead_t = 3.0
		if action != "":
			_end_action()
		if cam != null:
			cam.call("defeat", true)
		_stop_fly()
		_stop_divine()
		combo_count = 0
		combo_changed.emit(0)
		return
	_hurt_t = 0.3
	var push: Vector3 = global_position - from_pos
	push.y = 0.0
	var k: Vector3 = push.normalized() * 6.0
	velocity.x = k.x
	velocity.z = k.z


func _respawn() -> void:
	is_dead = false
	if cam != null:
		cam.call("defeat", false)
	hp = max_hp
	hp_changed.emit(hp, max_hp)
	if world != null:
		global_position = world.call("spawn_point")
	velocity = Vector3.ZERO


# ================================================================ pouvoirs

func _dur(i: int) -> float:
	var d: float = float(ATTACKS[i]["dur"]) * float(Weapons.get_def(weapon_index)["speed"])
	return d * (0.85 if is_divine else 1.0)


func _dmg_mult() -> float:
	return float(Weapons.get_def(weapon_index)["dmg"]) * (2.0 if is_divine else 1.0)


func _update_powers(delta: float) -> void:
	_fly_cd -= delta
	_shot_cd -= delta
	_tp_cd -= delta
	for k in _tech_cd:
		_tech_cd[k] = float(_tech_cd[k]) - delta
	power_cd = maxf(power_cd - delta, 0.0)
	_demon_spirit(delta)
	_update_hot(delta)
	for wk in _wear.keys():
		_wear[wk] = maxf(float(_wear[wk]) - delta * 1.2, 0.0)
	if _tp_window > 0.0:
		_tp_window -= delta
		if _tp_window <= 0.0:
			_tp_chain = 0
			_tp_cd = TP_COOLDOWN
	_autosave -= delta
	if _autosave <= 0.0:
		_autosave = 30.0
		save_progress()
	if is_dead:
		return
	# vol (bouton VOL / touche F) : démarre ou s'arrête
	if GameInput.fly_buffer > 0.0:
		GameInput.fly_buffer = 0.0
		if is_flying:
			_stop_fly()
		elif _fly_cd <= 0.0:
			_start_fly()
		else:
			announce.emit("Vol disponible dans %d s" % int(ceil(_fly_cd)))
	if is_flying:
		fly_left -= delta
		if fly_left <= 0.0:
			_stop_fly()
	# transformation (bouton DIVIN / touche T) : énergie pleine nécessaire
	if GameInput.divine_buffer > 0.0:
		GameInput.divine_buffer = 0.0
		if not is_divine and energy >= max_energy:
			_start_divine()
		elif not is_divine:
			announce.emit("Énergie insuffisante : frappe des ennemis (%d %%)" % int(energy / max_energy * 100.0))
	if is_divine:
		divine_left -= delta
		energy = max_energy * maxf(divine_left / divine_total, 0.0)
		energy_changed.emit(energy, max_energy)
		if divine_left <= 0.0:
			_stop_divine()
	# changement d'arme (bouton ARME / touche R)
	if GameInput.weapon_buffer > 0.0:
		GameInput.weapon_buffer = 0.0
		cycle_weapon()
	# potion de soin (bouton SOIN / touche H)
	if GameInput.heal_buffer > 0.0:
		GameInput.heal_buffer = 0.0
		use_potion()


func _start_fly() -> void:
	is_flying = true
	fly_left = FLY_TIME
	var gh: float = _ground_h()
	_fly_h = maxf(global_position.y - gh + 5.0, 5.0)
	velocity.y = 7.0
	wings.call("set_deployed", true)
	_end_attack()
	Sfx.play("fly")
	announce.emit("Vol magique : 10 s")


func _stop_fly() -> void:
	if not is_flying:
		return
	is_flying = false
	_glide = true          # redescente en douceur jusqu'au sol (ou un toit)
	_fly_cd = FLY_COOLDOWN
	wings.call("set_deployed", false)


func _ground_h() -> float:
	if world != null:
		return float(world.call("ground_height", global_position.x, global_position.z))
	return 0.0


## Vol : déplacement libre à altitude réglable (SAUT = monter, ESQ. = descendre).
func _fly_move(delta: float, wish: Vector3, has_input: bool) -> void:
	# SAUT = monter (jusqu'à 60 m : au-dessus des tours et des constructions), ESQ. = descendre
	if GameInput.consume_jump():
		_fly_h = minf(_fly_h + 4.0, 60.0)
	if GameInput.jump_held():
		_fly_h = minf(_fly_h + 9.0 * delta, 60.0)
	if GameInput.consume_dodge():
		_fly_h = maxf(_fly_h - 4.0, 1.5)
	var spd: float = FLY_FAST if GameInput.wants_run() else FLY_SPEED
	if is_divine:
		spd *= 1.3
	var target: Vector3 = wish.normalized() * spd if has_input else Vector3.ZERO
	velocity.x = move_toward(velocity.x, target.x, 14.0 * delta)
	velocity.z = move_toward(velocity.z, target.z, 14.0 * delta)
	var want_y: float = _ground_h() + _fly_h + sin(Time.get_ticks_msec() * 0.003) * 0.25
	velocity.y = clampf((want_y - global_position.y) * 3.0, -9.0, 11.0)
	move_and_slide()
	_update_blob()
	hspeed = Vector2(velocity.x, velocity.z).length()
	state = "attack" if _atk_i >= 0 else "fly"
	if _atk_i < 0 and hspeed > 0.5:
		face_yaw = atan2(-velocity.x, -velocity.z)


# ---------------------------------------------------------------- formes divines géantes
## Chaque épée a sa propre forme divine : le héros devient un géant, aura aux couleurs de
## l'élément, et le pouvoir de l'épée frappe en continu tout autour de lui.
const FORMS: Dictionary = {
	"feu": {"name": "GÉANT DE FEU", "k": 2.6, "main": Color(1.0, 0.35, 0.05, 0.2), "ring": Color(1.0, 0.5, 0.1, 0.85), "spark": Color(1.0, 0.6, 0.15)},
	"vent": {"name": "SEIGNEUR DES TEMPÊTES", "time": 60.0, "k": 2.5, "main": Color(0.4, 1.0, 0.7, 0.2), "ring": Color(0.8, 1.0, 0.9, 0.85), "spark": Color(0.9, 1.0, 0.95)},
	"glace": {"name": "GÉANT DE GLACE", "k": 2.5, "main": Color(0.5, 0.85, 1.0, 0.2), "ring": Color(0.7, 0.95, 1.0, 0.85), "spark": Color(0.85, 1.0, 1.0)},
	"eclair": {"name": "TITAN DE L'ÉCLAIR", "k": 2.5, "main": Color(0.3, 0.5, 1.0, 0.2), "ring": Color(0.7, 0.85, 1.0, 0.9), "spark": Color(0.9, 0.95, 1.0)},
	"poison": {"name": "COLOSSE VENIMEUX", "k": 2.4, "main": Color(0.3, 0.9, 0.2, 0.2), "ring": Color(0.5, 1.0, 0.3, 0.85), "spark": Color(0.7, 1.0, 0.4)},
	"vide": {"name": "GÉANT DU VIDE", "k": 2.7, "main": Color(0.5, 0.15, 0.9, 0.22), "ring": Color(0.7, 0.4, 1.0, 0.85), "spark": Color(0.8, 0.55, 1.0)},
	"solaire": {"name": "GÉANT SOLAIRE", "k": 2.8, "main": Color(1.0, 0.7, 0.1, 0.22), "ring": Color(1.0, 0.85, 0.3, 0.9), "spark": Color(1.0, 0.9, 0.5)},
	"ombre": {"name": "SEIGNEUR DÉMON GÉANT", "k": 3.0, "main": Color(0.5, 0.0, 0.05, 0.3), "ring": Color(1.0, 0.1, 0.15, 0.9), "spark": Color(1.0, 0.25, 0.25)},
	"divin": {"name": "DIEU GÉANT", "k": 3.2, "main": Color(1.0, 0.75, 0.2, 0.22), "ring": Color(1.0, 0.85, 0.35, 0.9), "spark": Color(1.0, 0.95, 0.6)},
}
var giant_k: float = 1.0
var _giant_target: float = 1.0
var _form_pulse: float = 0.0


## La durée des pouvoirs (gel, paralysie, brûlure, poison, vent) et des formes divines
## augmente avec le niveau : +8 % par niveau, jusqu'à ×3.
func duration_mult() -> float:
	return clampf(1.0 + 0.08 * float(level - 1), 1.0, 3.0)


func _form_element() -> String:
	return String(Weapons.get_def(weapon_index)["element"])


func _form() -> Dictionary:
	return FORMS.get(_form_element(), FORMS["divin"])


## Grandit / rapetisse en douceur, aura à l'échelle, caméra qui recule, pouvoir de la forme.
func _update_giant(delta: float) -> void:
	if not is_equal_approx(giant_k, _giant_target):
		giant_k = move_toward(giant_k, _giant_target, delta * (1.1 if _giant_target > giant_k else 2.0))
		if rig != null:
			rig.scale = Vector3.ONE * giant_k
		aura.scale = Vector3.ONE * giant_k
		if cam != null:
			cam.set("size_mult", pow(giant_k, 0.55))
	if is_divine and giant_k > 1.5 and _form_element() == "vent":
		# Seigneur des tempêtes : les ennemis sont aspirés autour de lui et valsent
		for e in get_tree().get_nodes_in_group("enemies"):
			var en2: Node3D = e as Node3D
			if en2 != null and en2.has_method("pull_toward") and en2.global_position.distance_to(global_position) < 22.0:
				en2.call("pull_toward", global_position)
	if is_divine and giant_k > 1.5:
		_form_pulse -= delta
		if _form_pulse <= 0.0:
			_form_pulse = 0.7
			var el: String = _form_element()
			var f: Dictionary = _form()
			var r: float = 3.2 * giant_k
			CombatFx.ring(get_parent(), global_position + Vector3(0.0, 0.2, 0.0), f["ring"], r, 0.5)
			for en in _enemies_near(global_position, r):
				if en.has_method("apply_element"):
					en.call("take_damage", 8.0 * _dmg_mult(), global_position)
					en.call("apply_element", el)
					if not bool(en.get("is_boss")):
						en.call("knockback", en.global_position - global_position, 6.0)


func _start_giant() -> void:
	var f: Dictionary = _form()
	_giant_target = float(f["k"])
	aura.call("set_theme", f["main"], f["ring"], f["spark"])
	announce.emit(String(f["name"]) + " !")
	if cam != null:
		cam.call("slow_mo", 1.4, 0.35)
		cam.call("shake", 0.8)
	for k in range(14):
		var ang: float = float(k) / 14.0 * TAU
		CombatFx.spark(get_parent(), global_position + Vector3(cos(ang) * 4.0, 0.4, sin(ang) * 4.0), f["spark"], 2.2)
	CombatFx.ring(get_parent(), global_position + Vector3(0.0, 0.2, 0.0), f["ring"], 14.0, 0.8)
	CombatFx.ring(get_parent(), global_position + Vector3(0.0, 0.5, 0.0), Color(1, 1, 1, 0.8), 8.0, 0.5)
	Sfx.play("ulti_boom", 0.6)


func _start_divine() -> void:
	is_divine = true
	divine_total = float(_form().get("time", DIVINE_TIME)) * duration_mult()
	divine_left = divine_total
	aura.call("set_active", true)
	_equip_weapon(weapon_index, true)
	Sfx.play("divine")
	_start_giant()
	if cam != null:
		cam.call("shake", 0.5)
	# onde de choc : dégâts et recul autour du héros
	for e in get_tree().get_nodes_in_group("enemies"):
		var en: Node3D = e as Node3D
		if en != null and String(en.get("state")) != "dead" and en.global_position.distance_to(global_position) < 6.0 * _giant_target:
			en.call("take_damage", 35.0, global_position)
			if en.has_method("knockback"):
				en.call("knockback", en.global_position - global_position, 14.0)
	for k in range(8):
		var ang: float = float(k) / 8.0 * TAU
		CombatFx.spark(get_parent(), global_position + Vector3(cos(ang) * 3.0, 0.5, sin(ang) * 3.0), Color(1.0, 0.8, 0.3), 1.5)


func _stop_divine() -> void:
	if not is_divine:
		return
	is_divine = false
	divine_left = 0.0
	energy = 0.0
	energy_changed.emit(energy, max_energy)
	aura.call("set_active", false)
	_giant_target = 1.0
	_equip_weapon(weapon_index, false)


## Équipe l'arme n° i (forme et dégâts) ; en Transformation, la lame devient divine.
func _equip_weapon(i: int, divine_look: bool) -> void:
	weapon_index = clampi(i, 0, Weapons.count() - 1)
	var d: Dictionary = Weapons.get_def(weapon_index)
	var sw: Node3D = Sword.new()
	sw.name = "Arme"
	sw.set("element", String(d["element"]))
	sw.set("length_scale", float(d["len"]))
	sw.set("width_scale", float(d["width"]))
	rig.call("equip_weapon", sw)
	_set_layer(sw, 2)


## Ailes de démon ou Épée du Démon : un démon spectral presque transparent surgit de tes ailes
## et frappe l'ennemi le plus proche (toutes les 3,5 s, 2 s en forme divine).
var _demon_cd: float = 2.0


func _demon_spirit(delta: float) -> void:
	if is_dead or action != "" or ulti_t >= 0.0:
		return
	if wings_variant != "demon" and _form_element() != "ombre":
		return
	_demon_cd -= delta
	if _demon_cd > 0.0:
		return
	var t: Node3D = _nearest_enemy(14.0)
	if t == null:
		return
	_demon_cd = 2.0 if is_divine else 3.5
	var d: Node3D = SpiritDemon.new()
	d.set("target", t)
	d.set("damage", 28.0 * _dmg_mult())
	d.set("start_pos", global_position + Vector3(0.0, 1.5, 0.0) + Vector3(sin(face_yaw), 0.0, cos(face_yaw)) * 1.0)
	get_parent().add_child(d)
	Sfx.play("teleport", 0.6)
	announce.emit("Démon des ailes !")


## Une épée trop utilisée surchauffe : après WEAR_MAX coups elle est remplacée automatiquement
## par la suivante débloquée. L'usure de toutes les armes redescend avec le temps.
const WEAR_MAX: float = 30.0
const HOT_TIME: float = 14.0
var _wear: Dictionary = {}
var _hot: Dictionary = {}          # arme -> secondes de refroidissement restantes
var bow_mode: bool = false         # l'épée est devenue un arc (garde son pouvoir)
var _bow_auto: bool = false


func _weapon_wear(hits: int) -> void:
	if is_divine or bow_mode:
		return
	_wear[weapon_index] = float(_wear.get(weapon_index, 0.0)) + float(hits)
	var w: float = float(_wear[weapon_index])
	if w >= WEAR_MAX:
		_wear[weapon_index] = 0.0
		_hot[weapon_index] = HOT_TIME
		var old: int = weapon_index
		cycle_weapon()
		if weapon_index != old:
			announce.emit("%s surchauffe → %s" % [String(Weapons.get_def(old)["name"]), String(Weapons.get_def(weapon_index)["name"])])
		else:
			# toutes les épées sont chaudes : l'arme actuelle devient un arc
			_bow_auto = true
			set_bow(true)
			announce.emit("Toutes les épées surchauffent : ARC %s" % String(Weapons.get_def(weapon_index)["name"]))
	elif w >= WEAR_MAX * 0.8 and int(w) % 2 == 0:
		announce.emit("%s chauffe..." % String(Weapons.get_def(weapon_index)["name"]))


func _update_hot(delta: float) -> void:
	for k in _hot.keys():
		_hot[k] = float(_hot[k]) - delta
		if float(_hot[k]) <= 0.0:
			_hot.erase(k)
	if bow_mode and _bow_auto and not _hot.has(weapon_index):
		_bow_auto = false
		set_bow(false)
		announce.emit("%s refroidie : retour à l'épée" % String(Weapons.get_def(weapon_index)["name"]))


## L'épée devient un arc (même élément, même pouvoir) ou redevient une épée.
func set_bow(on: bool) -> void:
	bow_mode = on
	if on:
		var d: Dictionary = Weapons.get_def(weapon_index)
		var b: Node3D = Bow.new()
		b.name = "Arme"
		b.set("element", String(d["element"]))
		rig.call("equip_weapon", b)
		_set_layer(b, 2)
	else:
		_equip_weapon(weapon_index, is_divine)


func cycle_weapon() -> void:
	var n: int = Weapons.count()
	for step in range(1, n + 1):
		var j: int = (weapon_index + step) % n
		if int(Weapons.get_def(j)["level"]) <= level and not _hot.has(j):
			if j != weapon_index:
				_equip_weapon(j, is_divine)
				if bow_mode:
					set_bow(true)
				announce.emit(String(Weapons.get_def(j)["name"]))
				save_progress()
			return


func set_wings(v: String) -> void:
	wings_variant = v
	wings.call("rebuild", v)
	save_progress()


func xp_needed() -> int:
	return 50 * level


func add_xp(amount: int) -> void:
	xp += amount
	var leveled: bool = false
	while xp >= xp_needed():
		xp -= xp_needed()
		level += 1
		leveled = true
		max_hp += 10.0
		hp = max_hp
		energy = minf(energy + 30.0, max_energy)
		var msg: String = "NIVEAU %d !" % level
		for wd in Weapons.LIST:
			if int(wd["level"]) == level:
				msg += "  Nouvelle arme : " + String(wd["name"])
		announce.emit(msg)
	if leveled:
		Sfx.play("levelup")
		hp_changed.emit(hp, max_hp)
		energy_changed.emit(energy, max_energy)
		save_progress()
	level_changed.emit(level, xp, xp_needed())


func save_progress() -> void:
	SaveGame.save({"level": level, "xp": xp, "weapon": weapon_index, "wings": wings_variant,
		"gold": gold, "potions": potions, "coat": coat_name, "power": power_index, "story": story})


func _load_progress() -> void:
	var d: Dictionary = SaveGame.load_data()
	level = int(d.get("level", 1))
	xp = int(d.get("xp", 0))
	weapon_index = int(d.get("weapon", 0))
	wings_variant = String(d.get("wings", "ange"))
	gold = int(d.get("gold", 0))
	potions = int(d.get("potions", 1))
	coat_name = String(d.get("coat", "Noir"))
	power_index = int(d.get("power", 0))
	story = Array(d.get("story", []))
	max_hp = 120.0 + 10.0 * float(level - 1)
	hp = max_hp
	if int(Weapons.get_def(weapon_index)["level"]) > level:
		weapon_index = 0


# ================================================================ inventaire

func add_item(kind: String, amount: int) -> void:
	if kind == "potion":
		potions += amount
		announce.emit("+%d potion de soin" % amount)
	else:
		gold += amount
		announce.emit("+%d or" % amount)
	Sfx.play("levelup", 1.6)
	inventory_changed.emit(gold, potions)


func use_potion() -> void:
	if is_dead:
		return
	if potions <= 0:
		announce.emit("Aucune potion")
		return
	if hp >= max_hp:
		announce.emit("PV déjà au maximum")
		return
	potions -= 1
	hp = minf(hp + POTION_HEAL, max_hp)
	hp_changed.emit(hp, max_hp)
	inventory_changed.emit(gold, potions)
	CombatFx.spark(get_parent(), global_position + Vector3(0.0, 1.0, 0.0), Color(0.3, 1.0, 0.4), 1.2)
	CombatFx.number(get_parent(), global_position + Vector3(0.0, 2.0, 0.0), int(POTION_HEAL), Color(0.3, 1.0, 0.4))
	save_progress()


func set_coat(name: String) -> void:
	coat_name = name
	rig.call("set_coat_color", name)
	_set_layer(rig, 2)
	save_progress()


## Déplacement au sol / en l'air hors combat : saut, double saut, saut long.
func _ground_move(delta: float, target: Vector3, wish: Vector3, has_input: bool, on_floor: bool) -> void:
	var accel: float = 28.0 if on_floor else 9.0
	if long_jump and not on_floor:
		# saut long : on garde l'élan, contrôle léger
		var keep: Vector3 = wish.normalized() if has_input else Vector3(velocity.x, 0.0, velocity.z).normalized()
		target = keep * LONG_JUMP_SPEED
		accel = 5.0
	velocity.x = move_toward(velocity.x, target.x, accel * delta)
	velocity.z = move_toward(velocity.z, target.z, accel * delta)
	# saut long : bouton maintenu pendant la course
	var hs: float = Vector2(velocity.x, velocity.z).length()
	if _holding_jump and not long_jump and _jumps == 1 and _jump_hold > 0.13 and hs > 4.0 and has_input:
		long_jump = true
		var ld: Vector3 = wish.normalized()
		velocity.x = ld.x * LONG_JUMP_SPEED
		velocity.z = ld.z * LONG_JUMP_SPEED
		velocity.y = maxf(velocity.y, 6.5)
		Sfx.play("longjump")
		CombatFx.ring(get_parent(), global_position + Vector3(0.0, 0.1, 0.0), Color(0.6, 0.85, 1.0, 0.8), 2.5, 0.35)
	# course sur le mur : en l'air, contre un mur, saut maintenu -> on monte le long du mur
	_wallrun = false
	if not on_floor and is_on_wall() and has_input:
		var n: Vector3 = get_wall_normal()
		if wish.normalized().dot(-n) > 0.3 and GameInput.jump_held() and _wall_t < 0.6:
			_wall_t += delta
			_wallrun = true
			velocity.y = 6.5
			velocity.x = -n.x * 1.5
			velocity.z = -n.z * 1.5
			face_yaw = atan2(n.x, n.z)
	# saut / double saut / rebond mural
	if GameInput.jump_buffer > 0.0 and _land_t <= 0.0 and not on_floor and is_on_wall() and _coyote <= 0.0:
		GameInput.consume_jump()
		var wn: Vector3 = get_wall_normal()
		velocity = Vector3(wn.x * 8.5, 9.0, wn.z * 8.5)
		face_yaw = atan2(-wn.x, -wn.z)
		_jumps = 1
		_wall_t = 0.0
		_flip_t = FLIP_TIME
		_holding_jump = false
		Sfx.play("jump2", 1.1)
		CombatFx.ring(get_parent(), global_position + Vector3(0.0, 1.0, 0.0) - wn * 0.3, Color(0.7, 0.9, 1.0, 0.8), 1.2, 0.25)
	if GameInput.jump_buffer > 0.0 and _land_t <= 0.0:
		if _coyote > 0.0:
			GameInput.consume_jump()
			velocity.y = JUMP_VELOCITY
			_coyote = 0.0
			_jumps = 1
			_holding_jump = true
			_jump_hold = 0.0
			Sfx.play("jump")
		elif not on_floor and _jumps < 2:
			GameInput.consume_jump()
			_double_jump(wish, has_input)


# ================================================================ saut, tir, téléportation, ultime

func _double_jump(wish: Vector3, has_input: bool) -> void:
	velocity.y = DOUBLE_JUMP_VELOCITY
	_jumps = 2
	_holding_jump = true
	_jump_hold = JUMP_HOLD_MAX * 0.5
	_flip_t = FLIP_TIME
	if has_input:
		# on peut changer de direction au double saut
		var sp: float = maxf(Vector2(velocity.x, velocity.z).length(), RUN_SPEED * 0.8)
		var d: Vector3 = wish.normalized()
		velocity.x = d.x * sp
		velocity.z = d.z * sp
	Sfx.play("jump2")
	CombatFx.ring(get_parent(), global_position + Vector3(0.0, 0.2, 0.0), Color(0.7, 0.9, 1.0, 0.8), 1.8, 0.3)


func _weapon_color() -> Color:
	var el: String = String(Weapons.get_def(weapon_index)["element"])
	var e: Dictionary = Sword.ELEMENTS.get(el, Sword.ELEMENTS["eclair"])
	return e["core"]


## Attaque à distance : vague d'énergie de la couleur de l'arme, visée automatique.
func _shoot() -> void:
	_end_attack()
	_shot_cd = SHOT_COOLDOWN * (0.7 if is_divine else 1.0)
	var target: Node3D = _nearest_enemy(22.0)
	var dir: Vector3 = Vector3(-sin(face_yaw), 0.0, -cos(face_yaw))
	if target != null:
		var d: Vector3 = target.global_position + Vector3(0.0, 0.9, 0.0) - (global_position + Vector3(0.0, 1.1, 0.0))
		dir = d.normalized()
		face_yaw = atan2(-d.x, -d.z)
	var shot: Node3D = PlayerShot.new()
	shot.set("dir", dir)
	shot.set("damage", 14.0 * _dmg_mult())
	shot.set("color", _weapon_color())
	shot.set("shooter", self)
	get_parent().add_child(shot)
	shot.global_position = global_position + Vector3(0.0, 1.1, 0.0) + dir * 0.8
	_pose_kind = 1
	_pose_dur = 0.32
	_pose_t = _pose_dur
	Sfx.play("shoot")


## Appelé par une flèche / vague d'énergie : applique le pouvoir de l'arme à l'ennemi touché.
func apply_power(en: Node3D) -> void:
	_apply_sword_power(en)


## Appelé par la vague d'énergie quand elle touche.
func on_ranged_hit() -> void:
	Sfx.play("hit", 1.2)
	combo_count += 1
	_combo_timer = 2.2
	combo_changed.emit(combo_count)
	energy = minf(energy + 3.0, max_energy)
	energy_changed.emit(energy, max_energy)
	add_ulti(3.0)


## Téléportation : derrière l'ennemi le plus proche + coup puissant, enchaînable
## 3 fois de suite (vers un autre ennemi si possible). Sans cible : bond de 7 m.
func _teleport(facing: Vector3) -> void:
	var chaining: bool = _tp_window > 0.0 and _tp_chain < TP_CHAIN
	if not chaining and _tp_cd > 0.0:
		announce.emit("Téléportation dans %d s" % int(ceil(_tp_cd)))
		return
	_end_attack()
	var col: Color = _weapon_color()
	CombatFx.afterimage(get_parent(), global_position, col)
	CombatFx.spark(get_parent(), global_position + Vector3(0.0, 1.0, 0.0), col, 1.2)
	var target: Node3D = null
	var best: float = TP_RANGE
	for e in get_tree().get_nodes_in_group("enemies"):
		var en: Node3D = e as Node3D
		if en == null or String(en.get("state")) == "dead":
			continue
		var dd: float = en.global_position.distance_to(global_position)
		if en == _tp_last and _tp_chain > 0:
			dd += 6.0          # préfère un autre ennemi pendant un enchaînement
		if dd < best:
			best = dd
			target = en
	if target != null:
		var tp: Vector3 = target.global_position
		var away: Vector3 = tp - global_position
		away.y = 0.0
		away = away.normalized() if away.length() > 0.1 else -facing
		var dest: Vector3 = tp + away * 1.3
		dest = _safe_dest(dest)
		global_position = dest
		velocity = Vector3.ZERO
		var look: Vector3 = tp - dest
		face_yaw = atan2(-look.x, -look.z)
		rig.rotation.y = face_yaw
		target.call("take_damage", 28.0 * _dmg_mult(), dest)
		CombatFx.bolt(get_parent(), dest + Vector3(0.0, 14.0, 0.0), dest + Vector3(0.0, 0.2, 0.0), col, 0.22)
		CombatFx.spark(get_parent(), tp + Vector3(0.0, 1.0, 0.0), col, 1.4)
		_tp_last = target
		_tp_chain += 1
		_tp_window = 1.3
		if _tp_chain >= TP_CHAIN:
			_tp_window = 0.01
		combo_count += 1
		_combo_timer = 2.2
		combo_changed.emit(combo_count)
		energy = minf(energy + 6.0, max_energy)
		energy_changed.emit(energy, max_energy)
		add_ulti(6.0)
		# enchaîne sur le 3e coup du combo
		_combo_next = 2
		_combo_reset = 1.0
		_pose_kind = 2
		_pose_dur = 0.3
		_pose_t = _pose_dur
		if cam != null:
			cam.call("shake", 0.3)
		Sfx.play("teleport")
		Sfx.play("hit", 0.9)
	else:
		# bond vers l'avant, arrêté avant les obstacles
		var from: Vector3 = global_position + Vector3(0.0, 1.0, 0.0)
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + facing * 7.0, 1)
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
		var dist: float = 7.0
		if not hit.is_empty():
			dist = maxf(from.distance_to(hit["position"]) - 0.7, 0.0)
		global_position = _safe_dest(global_position + facing * dist)
		_tp_cd = 1.2
		Sfx.play("teleport", 1.15)
	CombatFx.afterimage(get_parent(), global_position, col)


func _ground_at(p: Vector3) -> float:
	if world != null:
		return float(world.call("ground_height", p.x, p.z))
	return p.y


func add_ulti(v: float) -> void:
	if ulti_t >= 0.0:
		return
	var was_full: bool = ulti >= ULTI_MAX
	ulti = minf(ulti + v, ULTI_MAX)
	ulti_changed.emit(ulti)
	if not was_full and ulti >= ULTI_MAX:
		announce.emit("ATTAQUE FINALE PRÊTE !")
		Sfx.play("levelup", 1.3)


## Attaque finale : le héros s'élève, puis 4 vagues d'éclairs frappent tous les ennemis
## à moins de 16 m, et une onde de choc termine l'attaque.
func _start_ulti() -> void:
	# l'attaque finale est maintenant l'Éclipse du dragon (combos.gd)
	_stop_fly()
	ulti = 0.0
	ulti_changed.emit(ulti)
	_start_action("eclipse")
	if cam != null:
		cam.call("orbit", 0.75, 2.2)
	Sfx.play("ulti_charge")
	CombatFx.ring(get_parent(), global_position + Vector3(0.0, 0.15, 0.0), Color(1.0, 0.85, 0.4, 0.9), ECLIPSE_RADIUS, 0.75)



func _process_ulti(delta: float) -> void:
	ulti_t += delta
	invulnerable = true
	state = "attack"
	# monte de 2,5 m puis reste suspendu
	var want: float = _ulti_y + 2.5 * smoothstep(0.0, 0.4, ulti_t) * (1.0 - smoothstep(1.45, ULTI_TIME, ulti_t))
	global_position.y = lerpf(global_position.y, want, 1.0 - exp(-10.0 * delta))
	velocity = Vector3.ZERO
	var times: Array = [0.45, 0.75, 1.05, 1.35]
	if _ulti_strikes < times.size() and ulti_t >= float(times[_ulti_strikes]):
		_ulti_strikes += 1
		var col: Color = Color(1.0, 0.9, 0.5) if is_divine else Color(0.6, 0.85, 1.0)
		var n: int = 0
		for e in get_tree().get_nodes_in_group("enemies"):
			var en: Node3D = e as Node3D
			if en == null or String(en.get("state")) == "dead":
				continue
			var udist: float = Vector2(en.global_position.x - global_position.x, en.global_position.z - global_position.z).length()
			if udist > ULTI_RADIUS:
				continue
			var p: Vector3 = en.global_position
			CombatFx.bolt(get_parent(), p + Vector3(randf_range(-2.0, 2.0), 22.0, randf_range(-2.0, 2.0)), p + Vector3(0.0, 0.3, 0.0), col, 0.35)
			CombatFx.spark(get_parent(), p + Vector3(0.0, 1.0, 0.0), col, 1.6)
			en.call("take_damage", 45.0 * _dmg_mult() * lerpf(1.3, 0.7, udist / ULTI_RADIUS), global_position)
			n += 1
			if n >= 10:
				break
		if n == 0:
			# aucun ennemi : éclairs décoratifs autour du héros
			for k in range(3):
				var a: float = randf() * TAU
				var gp: Vector3 = global_position + Vector3(cos(a) * 6.0, 0.0, sin(a) * 6.0)
				gp.y = _ground_at(gp)
				CombatFx.bolt(get_parent(), gp + Vector3(0.0, 22.0, 0.0), gp, col, 0.35)
		Sfx.play("thunder", 1.3)
		if cam != null:
			cam.call("shake", 0.5)
		if world != null and world.has_method("flash"):
			world.call("flash", 0.6)
		if _ulti_strikes == times.size():
			CombatFx.ring(get_parent(), Vector3(global_position.x, _ulti_y + 0.2, global_position.z), col, ULTI_RADIUS, 0.5)
			Sfx.play("ulti_boom")
	if ulti_t >= ULTI_TIME:
		ulti_t = -1.0
		invulnerable = false


## Attaque plongeante : depuis les hauteurs, le héros fonce vers le sol épée en avant ;
## à l'impact, onde de choc (rayon 4 m, plus forte au centre).
func _start_plunge() -> void:
	_end_attack()
	_plunge = true
	_glide = false
	velocity = Vector3(-sin(face_yaw) * 3.0, -26.0, -cos(face_yaw) * 3.0)
	invulnerable = true
	Sfx.play("swing", 0.7)
	var target: Node3D = _nearest_enemy(8.0)
	if target != null:
		var d: Vector3 = target.global_position - global_position
		d.y = 0.0
		face_yaw = atan2(-d.x, -d.z)
		velocity.x = d.x * 1.2
		velocity.z = d.z * 1.2


func _process_plunge(on_floor: bool) -> void:
	state = "plunge"
	move_and_slide()
	_update_blob()
	if on_floor or is_on_floor():
		_plunge = false
		invulnerable = false
		_land_t = 0.2
		var col: Color = _weapon_color()
		CombatFx.ring(get_parent(), global_position + Vector3(0.0, 0.15, 0.0), col, PLUNGE_RADIUS, 0.4)
		for k in range(6):
			var ang: float = float(k) / 6.0 * TAU
			CombatFx.spark(get_parent(), global_position + Vector3(cos(ang) * 2.0, 0.3, sin(ang) * 2.0), col, 1.1)
		var hits: int = 0
		for e in get_tree().get_nodes_in_group("enemies"):
			var en: Node3D = e as Node3D
			if en == null or String(en.get("state")) == "dead":
				continue
			var dd: float = Vector2(en.global_position.x - global_position.x, en.global_position.z - global_position.z).length()
			if dd < PLUNGE_RADIUS and absf(en.global_position.y - global_position.y) < 2.5:
				en.call("take_damage", 30.0 * _dmg_mult() * lerpf(1.4, 0.7, dd / PLUNGE_RADIUS), global_position)
				hits += 1
		if hits > 0:
			on_ranged_hit()
		Sfx.play("ulti_boom", 1.6)
		if cam != null:
			cam.call("shake", 0.45)


# ================================================================ pouvoirs (menu POUVOIRS)

func power_short() -> String:
	return String(Powers.get_def(power_index)["short"])


func set_power(i: int) -> void:
	power_index = clampi(i, 0, Powers.count() - 1)
	announce.emit("Pouvoir : " + String(Powers.get_def(power_index)["name"]))
	save_progress()


## Déclenche le pouvoir choisi (bouton POUVOIR / touche G).
func use_power(facing: Vector3) -> void:
	if is_flying and _tech_ready("pluie"):
		if not _enemies_near(global_position, 12.0, 14.0).is_empty():
			_start_action("pluie")
			return
	if power_cd > 0.0:
		return
	var d: Dictionary = Powers.get_def(power_index)
	var cd: float = float(d["cd"])
	match String(d["id"]):
		"vague":
			_shoot()
		"tp":
			_teleport(facing)
			cd = 0.3
		"zone":
			_start_zone()
		"vol":
			if is_flying:
				_stop_fly()
			elif _fly_cd <= 0.0:
				_start_fly()
			else:
				announce.emit("Vol disponible dans %d s" % int(ceil(_fly_cd)))
				return
		"eclair":
			_start_dash(facing)
		"bouclier":
			_start_shield()
		"combo":
			_end_attack()
			_combo_left = 6
			_combo_tick = 0.0
			Sfx.play("teleport", 1.3)
	power_cd = cd * (0.7 if is_divine else 1.0)


## Frappe de zone : la zone (5 m) s'affiche au sol pendant 0,4 s, puis onde de choc.
func _start_zone() -> void:
	_end_attack()
	_zone_t = 0.4
	CombatFx.ring(get_parent(), global_position + Vector3(0.0, 0.12, 0.0), Color(1.0, 0.35, 0.2, 0.9), ZONE_RADIUS, 0.4)
	_pose_kind = 4
	_pose_dur = 0.5
	_pose_t = _pose_dur
	if is_on_floor():
		velocity.y = 5.0
	Sfx.play("ulti_charge", 1.8)


func _zone_impact() -> void:
	var col: Color = _weapon_color()
	CombatFx.ring(get_parent(), global_position + Vector3(0.0, 0.15, 0.0), col, ZONE_RADIUS, 0.35)
	CombatFx.ring(get_parent(), global_position + Vector3(0.0, 0.3, 0.0), Color(1, 1, 1, 0.8), ZONE_RADIUS * 0.6, 0.25)
	for k in range(8):
		var ang: float = float(k) / 8.0 * TAU
		CombatFx.spark(get_parent(), global_position + Vector3(cos(ang) * 2.5, 0.3, sin(ang) * 2.5), col, 1.2)
	var hits: int = 0
	for e in get_tree().get_nodes_in_group("enemies"):
		var en: Node3D = e as Node3D
		if en == null or String(en.get("state")) == "dead":
			continue
		var dd: float = Vector2(en.global_position.x - global_position.x, en.global_position.z - global_position.z).length()
		if dd < ZONE_RADIUS and absf(en.global_position.y - global_position.y) < 3.0:
			en.call("take_damage", 40.0 * _dmg_mult() * lerpf(1.4, 0.6, dd / ZONE_RADIUS), global_position)
			hits += 1
	if hits > 0:
		on_ranged_hit()
	Sfx.play("ulti_boom", 1.3)
	if cam != null:
		cam.call("shake", 0.5)


## Attaque éclair : ruée de 10 m en 0,15 s, invincible, tranche tout sur le passage.
func _start_dash(facing: Vector3) -> void:
	_end_attack()
	var dir: Vector3 = facing
	var target: Node3D = _nearest_enemy(10.0)
	if target != null:
		dir = target.global_position - global_position
		dir.y = 0.0
		dir = dir.normalized()
	face_yaw = atan2(-dir.x, -dir.z)
	_dash_dir = dir
	_dash_t = 0.15
	_dash_from = global_position
	_dash_hit.clear()
	CombatFx.afterimage(get_parent(), global_position, _weapon_color())
	Sfx.play("teleport", 0.8)
	Sfx.play("lightning", 1.4)


func _process_dash(delta: float) -> void:
	_dash_t -= delta
	invulnerable = true
	velocity = _dash_dir * 66.0
	velocity.y = 0.0
	move_and_slide()
	_update_blob()
	state = "attack"
	_pose_kind = 1
	_pose_dur = 0.25
	_pose_t = 0.12
	for e in get_tree().get_nodes_in_group("enemies"):
		var en: Node3D = e as Node3D
		if en == null or _dash_hit.has(en) or String(en.get("state")) == "dead":
			continue
		if en.global_position.distance_to(global_position) < 1.9:
			_dash_hit.append(en)
			en.call("take_damage", 35.0 * _dmg_mult(), global_position - _dash_dir)
			CombatFx.spark(get_parent(), en.global_position + Vector3(0.0, 1.0, 0.0), _weapon_color(), 1.3)
			on_ranged_hit()
	if _dash_t <= 0.0:
		velocity = Vector3.ZERO
		invulnerable = false
		CombatFx.bolt(get_parent(), _dash_from + Vector3(0.0, 1.0, 0.0), global_position + Vector3(0.0, 1.0, 0.0), _weapon_color(), 0.3)
		CombatFx.afterimage(get_parent(), global_position, _weapon_color())


## Bouclier énergétique : 6 s, absorbe 60 dégâts.
func _start_shield() -> void:
	_shield_t = 6.0
	_shield_hp = 60.0
	if shield == null:
		shield = MeshInstance3D.new()
		var sm: SphereMesh = SphereMesh.new()
		sm.radius = 1.15
		sm.height = 2.3
		sm.radial_segments = 16
		sm.rings = 8
		shield.mesh = sm
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.albedo_color = Color(0.35, 0.7, 1.0, 0.22)
		m.rim_enabled = true
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		shield.material_override = m
		shield.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		shield.position = Vector3(0.0, 0.95, 0.0)
		add_child(shield)
	shield.visible = true
	Sfx.play("divine", 1.5)
	announce.emit("Bouclier énergétique : 6 s")


func _update_shield(delta: float) -> void:
	if _shield_t <= 0.0:
		return
	_shield_t -= delta
	if shield != null:
		var pulse: float = 1.0 + sin(Time.get_ticks_msec() * 0.01) * 0.03
		shield.scale = Vector3.ONE * pulse
		(shield.material_override as StandardMaterial3D).albedo_color.a = 0.14 + 0.1 * (_shield_hp / 60.0)
	if _shield_t <= 0.0 or _shield_hp <= 0.0:
		_shield_t = 0.0
		if shield != null:
			shield.visible = false


## Combo ninja : 6 coups, téléportation d'un ennemi à l'autre toutes les 0,2 s.
func _process_combo(delta: float) -> void:
	_combo_tick -= delta
	invulnerable = true
	velocity = Vector3.ZERO
	move_and_slide()
	state = "attack"
	if _combo_tick > 0.0:
		return
	_combo_tick = 0.2
	_combo_left -= 1
	var col: Color = _weapon_color()
	var best: Node3D = null
	var best_d: float = 9.0
	for e in get_tree().get_nodes_in_group("enemies"):
		var en: Node3D = e as Node3D
		if en == null or String(en.get("state")) == "dead":
			continue
		var dd: float = en.global_position.distance_to(global_position) + (4.0 if en == _tp_last else 0.0)
		if dd < best_d:
			best_d = dd
			best = en
	_pose_kind = [0, 1, 2, 3, 0, 1][_combo_left % 6]
	_pose_dur = 0.2
	_pose_t = 0.2
	Sfx.play("swing", 1.1 + 0.05 * float(_combo_left))
	if best != null:
		CombatFx.afterimage(get_parent(), global_position, col)
		var side: float = 1.0 if _combo_left % 2 == 0 else -1.0
		var to_e: Vector3 = best.global_position - global_position
		to_e.y = 0.0
		var perp: Vector3 = Vector3(-to_e.z, 0.0, to_e.x).normalized() * side
		var dest: Vector3 = _safe_dest(best.global_position + perp * 1.3)
		global_position = dest
		var look: Vector3 = best.global_position - dest
		face_yaw = atan2(-look.x, -look.z)
		rig.rotation.y = face_yaw
		best.call("take_damage", 14.0 * _dmg_mult(), dest)
		CombatFx.spark(get_parent(), best.global_position + Vector3(0.0, 1.0, 0.0), col, 1.0)
		_tp_last = best
		on_ranged_hit()
	else:
		# aucun ennemi : tourbillon d'épée sur place
		CombatFx.ring(get_parent(), global_position + Vector3(0.0, 0.8, 0.0), col, 2.5, 0.2)
	if _combo_left <= 0:
		invulnerable = false
		_combo_next = 3
		_combo_reset = 0.8


## Position d'arrivée sûre : posée sur le sol ou un toit, jamais dans un mur ni hors du monde.
func _safe_dest(to: Vector3) -> Vector3:
	var lim: float = 450.0
	to.x = clampf(to.x, -lim, lim)
	to.z = clampf(to.z, -lim, lim)
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var cap: CapsuleShape3D = CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.6
	var q: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	q.shape = cap
	q.collision_mask = 1
	var from: Vector3 = global_position
	for k in range(7):
		var f: float = 1.0 - float(k) / 7.0
		var p: Vector3 = from.lerp(to, f)
		# surface d'appui : rayon vers le bas (sol ou toit)
		var rq: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(p + Vector3(0.0, 6.0, 0.0), p + Vector3(0.0, -30.0, 0.0), 1)
		var hit: Dictionary = space.intersect_ray(rq)
		var gy: float = _ground_at(p)
		if not hit.is_empty():
			gy = maxf(gy, float((hit["position"] as Vector3).y))
		p.y = gy + 0.05
		q.transform = Transform3D(Basis.IDENTITY, p + Vector3(0.0, 0.95, 0.0))
		if space.intersect_shape(q, 1).is_empty():
			return p
	return global_position


## Téléportation ciblée (bouton TP maintenu) : marqueur d'arrivée + ennemi visé.
func _update_tp_aim(delta: float, wish: Vector3, has_input: bool) -> void:
	if not _tp_aiming:
		_tp_aiming = true
		var yaw: float = float(cam.get("yaw")) if cam != null else face_yaw
		_aim_point = global_position + Vector3(-sin(yaw), 0.0, -cos(yaw)) * 8.0
		_build_aim_markers()
		announce.emit("Ciblage : relâche pour te téléporter")
	if has_input:
		_aim_point += wish.normalized() * 14.0 * delta
	var off: Vector3 = _aim_point - global_position
	off.y = 0.0
	if off.length() > TP_AIM_RANGE:
		_aim_point = global_position + off.normalized() * TP_AIM_RANGE
	_aim_target = null
	var best: float = 4.5
	for e in get_tree().get_nodes_in_group("enemies"):
		var en: Node3D = e as Node3D
		if en == null or String(en.get("state")) == "dead":
			continue
		var dd: float = Vector2(en.global_position.x - _aim_point.x, en.global_position.z - _aim_point.z).length()
		if dd < best:
			best = dd
			_aim_target = en
	var dest: Vector3 = _aim_point
	if _aim_target != null:
		var away: Vector3 = _aim_target.global_position - global_position
		away.y = 0.0
		dest = _aim_target.global_position + away.normalized() * 1.3
	_aim_dest = _safe_dest(dest)
	_aim_ring.visible = true
	_aim_ring.global_position = _aim_dest + Vector3(0.0, 0.12, 0.0)
	_aim_ring.rotation.y += delta * 3.0
	_aim_mark.visible = _aim_target != null
	if _aim_target != null:
		_aim_mark.global_position = _aim_target.global_position + Vector3(0.0, 2.9 + sin(Time.get_ticks_msec() * 0.008) * 0.15, 0.0)
	velocity.x = 0.0
	velocity.z = 0.0


func _build_aim_markers() -> void:
	if _aim_ring != null:
		return
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(0.4, 0.85, 1.0, 0.9)
	m.no_depth_test = true
	_aim_ring = MeshInstance3D.new()
	var tor: TorusMesh = TorusMesh.new()
	tor.inner_radius = TP_STRIKE_RADIUS - 0.15
	tor.outer_radius = TP_STRIKE_RADIUS
	tor.rings = 40
	tor.ring_segments = 4
	_aim_ring.mesh = tor
	_aim_ring.material_override = m
	_aim_ring.scale = Vector3(1.0, 0.2, 1.0)
	_aim_ring.top_level = true
	_aim_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_aim_ring)
	var m2: StandardMaterial3D = m.duplicate() as StandardMaterial3D
	m2.albedo_color = Color(1.0, 0.25, 0.2, 0.95)
	_aim_mark = MeshInstance3D.new()
	var cone: CylinderMesh = CylinderMesh.new()
	cone.top_radius = 0.45
	cone.bottom_radius = 0.0
	cone.height = 0.7
	cone.radial_segments = 4
	_aim_mark.mesh = cone
	_aim_mark.material_override = m2
	_aim_mark.top_level = true
	_aim_mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_aim_mark)
	_aim_ring.visible = false
	_aim_mark.visible = false


func _hide_aim() -> void:
	_tp_aiming = false
	if _aim_ring != null:
		_aim_ring.visible = false
		_aim_mark.visible = false


## Relâchement du bouton TP en mode ciblage : téléportation + frappe de zone à l'arrivée.
func _teleport_aimed() -> void:
	_hide_aim()
	if _tp_cd > 0.0 and not (_tp_window > 0.0 and _tp_chain < TP_CHAIN):
		announce.emit("Téléportation dans %d s" % int(ceil(_tp_cd)))
		return
	_end_attack()
	var col: Color = _weapon_color()
	CombatFx.afterimage(get_parent(), global_position, col)
	global_position = _aim_dest
	velocity = Vector3.ZERO
	if _aim_target != null and is_instance_valid(_aim_target):
		var look: Vector3 = _aim_target.global_position - _aim_dest
		face_yaw = atan2(-look.x, -look.z)
		rig.rotation.y = face_yaw
	CombatFx.bolt(get_parent(), _aim_dest + Vector3(0.0, 18.0, 0.0), _aim_dest + Vector3(0.0, 0.2, 0.0), col, 0.3)
	CombatFx.ring(get_parent(), _aim_dest + Vector3(0.0, 0.15, 0.0), col, TP_STRIKE_RADIUS, 0.35)
	CombatFx.ring(get_parent(), _aim_dest + Vector3(0.0, 0.3, 0.0), Color(1, 1, 1, 0.8), TP_STRIKE_RADIUS * 0.6, 0.25)
	var hits: int = 0
	for e in get_tree().get_nodes_in_group("enemies"):
		var en: Node3D = e as Node3D
		if en == null or String(en.get("state")) == "dead":
			continue
		var dd: float = Vector2(en.global_position.x - _aim_dest.x, en.global_position.z - _aim_dest.z).length()
		if dd < TP_STRIKE_RADIUS and absf(en.global_position.y - _aim_dest.y) < 3.0:
			en.call("take_damage", 32.0 * _dmg_mult() * lerpf(1.4, 0.7, dd / TP_STRIKE_RADIUS), _aim_dest)
			CombatFx.spark(get_parent(), en.global_position + Vector3(0.0, 1.0, 0.0), col, 1.2)
			hits += 1
	if hits > 0:
		on_ranged_hit()
		add_ulti(4.0 * float(hits))
	_tp_cd = TP_COOLDOWN
	_combo_next = 2
	_combo_reset = 1.0
	_pose_kind = 4
	_pose_dur = 0.35
	_pose_t = _pose_dur
	Sfx.play("teleport")
	Sfx.play("ulti_boom", 1.7)
	if cam != null:
		cam.call("shake", 0.45)


# ================================================================ techniques (combos.gd)
# Machine à états « action » : une seule technique exclusive à la fois (charge, frappe du
# dragon, tempête ninja, exécution aérienne, fantôme, dragon céleste, pluie de lames,
# météore, éclipse, célébration). Pendant une action, la marche, le saut, l'esquive et
# les autres attaques sont bloqués ; certaines actions peuvent être interrompues par ESQ.

## Cible de l'action en cours (null si elle a disparu, ex. illusion détruite).
func _act_target() -> Node3D:
	var v: Variant = _act.get("target", null)
	if v == null or not is_instance_valid(v):
		return null
	return v as Node3D


func _push_input(letter: String) -> void:
	_hist.append([letter, Time.get_ticks_msec()])
	if _hist.size() > 6:
		_hist.pop_front()


func _tech_ready(id: String) -> bool:
	return float(_tech_cd.get(id, 0.0)) <= 0.0


func _tech_used(id: String) -> void:
	var d: Dictionary = Combos.get_def(id)
	_tech_cd[id] = float(d.get("cd", 0.0))


func _tdmg(id: String) -> float:
	return float(Combos.get_def(id).get("dmg", 10.0)) * _dmg_mult()


func _start_action(id: String, data: Dictionary = {}) -> void:
	_end_attack()
	action = id
	_act_t = 0.0
	_act = data
	_act["step"] = 0
	_tech_used(id)
	var d: Dictionary = Combos.get_def(id)
	if not d.is_empty() and id != "celebrate":
		announce.emit(String(d["name"]))


func _end_action() -> void:
	action = ""
	_act = {}
	invulnerable = false
	_hide_aim()


func _strike(en: Node3D, dmg: float, from: Vector3, col: Color) -> void:
	if en == null or not is_instance_valid(en) or String(en.get("state")) == "dead":
		return
	en.call("take_damage", dmg, from)
	CombatFx.spark(get_parent(), en.global_position + Vector3(0.0, 1.0, 0.0), col, 1.1)
	on_ranged_hit()


## Rayon de corps d'une grande cible (0 pour les ennemis normaux).
func _hit_r(en: Node) -> float:
	var v: Variant = en.get("hit_radius")
	return float(v) if v != null else 0.0


func _enemies_near(pos: Vector3, r: float, max_dy: float = 3.0) -> Array:
	var out: Array = []
	for e in get_tree().get_nodes_in_group("enemies"):
		var en: Node3D = e as Node3D
		if en == null or String(en.get("state")) == "dead":
			continue
		var hr: float = _hit_r(en)
		var dd: float = Vector2(en.global_position.x - pos.x, en.global_position.z - pos.z).length() - hr
		if dd < r and absf(en.global_position.y - pos.y) < max_dy + hr:
			out.append(en)
	return out


## Onde de choc limitée à la zone : dégâts plus forts au centre, recul optionnel.
func _shockwave(pos: Vector3, r: float, dmg: float, push: float, col: Color) -> int:
	CombatFx.ring(get_parent(), pos + Vector3(0.0, 0.15, 0.0), col, r, 0.35)
	CombatFx.ring(get_parent(), pos + Vector3(0.0, 0.3, 0.0), Color(1, 1, 1, 0.8), r * 0.6, 0.25)
	var n: int = 0
	for en in _enemies_near(pos, r):
		var dd: float = Vector2(en.global_position.x - pos.x, en.global_position.z - pos.z).length()
		en.call("take_damage", dmg * lerpf(1.4, 0.6, dd / r), pos)
		if push > 0.0:
			en.call("knockback", en.global_position - pos, push)
		n += 1
	if n > 0:
		on_ranged_hit()
	return n


func _face_to(p: Vector3) -> void:
	var d: Vector3 = p - global_position
	if Vector2(d.x, d.z).length() > 0.05:
		face_yaw = atan2(-d.x, -d.z)
		rig.rotation.y = face_yaw


func _set_pose(kind: int, dur: float) -> void:
	_pose_kind = kind
	_pose_dur = dur
	_pose_t = dur


func _process_action(delta: float, on_floor: bool, wish: Vector3, has_input: bool) -> void:
	_act_t += delta
	var t: float = _act_t
	var col: Color = _weapon_color()
	var step: int = int(_act.get("step", 0))
	match action:
		"charge":
			# Frappe du dragon : posture, énergie qui se concentre, caméra qui se rapproche
			velocity.x = 0.0
			velocity.z = 0.0
			state = "guard"
			if cam != null:
				cam.call("zoom_pulse", lerpf(1.0, 0.68, clampf(t / 0.6, 0.0, 1.0)), 0.2)
			if fmod(t, 0.09) < delta:
				var a: float = t * 9.0
				var hand: Vector3 = global_position + Vector3(cos(a) * 0.5, 1.4 + sin(t * 5.0) * 0.3, sin(a) * 0.5)
				CombatFx.spark(get_parent(), hand, col, 0.18 + 0.22 * clampf(t / 0.6, 0.0, 1.0))
			if GameInput.dodge_buffer > 0.0:
				_end_action()
				return
			if not GameInput.attack_held():
				if t >= 0.45:
					var tg: Node3D = _nearest_enemy(9.0)
					action = "dragon_rush"
					_act_t = 0.0
					_act = {"target": tg, "step": 0, "from": global_position}
					Sfx.play("teleport", 0.7)
				else:
					_end_action()
				return
			move_and_slide()
		"dragon_rush":
			var tg2: Node3D = _act_target()
			invulnerable = true
			if step == 0:
				var dir: Vector3 = Vector3(-sin(face_yaw), 0.0, -cos(face_yaw))
				if tg2 != null and is_instance_valid(tg2):
					dir = tg2.global_position - global_position
					dir.y = 0.0
					_face_to(tg2.global_position)
				var close: bool = tg2 != null and is_instance_valid(tg2) and Vector2(dir.x, dir.z).length() < 1.7
				if close or t > 0.32 or tg2 == null:
					_act["step"] = 1
					_set_pose(2, 0.35)
					if tg2 != null:
						_strike(tg2, _tdmg("dragon"), global_position, col)
					_shockwave(global_position + Vector3(-sin(face_yaw), 0.0, -cos(face_yaw)) * 1.2, 3.0, _tdmg("dragon") * 0.4, 6.0, col)
					Sfx.play("ulti_boom", 1.4)
					if cam != null:
						cam.call("shake", 0.4)
						cam.call("slow_mo", 0.12, 0.4)
					_act_t = 0.0
				else:
					var v: Vector3 = dir.normalized() * 34.0
					velocity = Vector3(v.x, velocity.y, v.z)
					state = "longjump"
					if fmod(t, 0.05) < delta:
						CombatFx.afterimage(get_parent(), global_position, col)
			else:
				velocity.x = 0.0
				velocity.z = 0.0
				state = "attack"
				if t > 0.3:
					_end_action()
			move_and_slide()
		"tempete":
			# Tempête ninja : téléportation derrière l'ennemi, 4 frappes rapides, recul final
			invulnerable = true
			velocity = Vector3.ZERO
			state = "attack"
			var tg3: Node3D = _act_target()
			if step == 0:
				if tg3 != null:
					var away: Vector3 = tg3.global_position - global_position
					away.y = 0.0
					CombatFx.afterimage(get_parent(), global_position, col)
					global_position = _safe_dest(tg3.global_position + away.normalized() * 1.3)
					_face_to(tg3.global_position)
					Sfx.play("teleport", 1.2)
				_act["step"] = 1
			elif step <= 4 and t >= 0.12 * float(step):
				_set_pose([0, 1, 0, 1][step - 1], 0.12)
				Sfx.play("swing", 1.3 + 0.05 * float(step))
				_strike(tg3, _tdmg("tempete"), global_position, col)
				_act["step"] = step + 1
			elif step == 5 and t >= 0.66:
				_set_pose(3, 0.3)
				_strike(tg3, _tdmg("tempete") * 2.0, global_position, col)
				for en in _enemies_near(global_position, 3.5):
					en.call("knockback", en.global_position - global_position, 12.0)
				Sfx.play("hit", 0.8)
				if cam != null:
					cam.call("shake", 0.3)
				_act["step"] = 6
			elif step == 6 and t >= 0.9:
				_end_action()
				return
			move_and_slide()
		"aerienne":
			# Exécution aérienne (au ralenti) : l'ennemi est projeté vers le ciel, le héros le
			# rejoint en volant, le frappe plusieurs fois en l'air, puis redescend d'un coup.
			var tg4: Node3D = _act_target()
			if GameInput.dodge_buffer > 0.0:
				_end_action()
				return
			invulnerable = true
			state = "attack"
			velocity.x = 0.0
			velocity.z = 0.0
			if step == 0:
				_set_pose(2, 0.35)
				_strike(tg4, _tdmg("aerienne"), global_position, col)
				if tg4 != null and is_instance_valid(tg4):
					tg4.call("launch", 14.0)
				velocity.y = 14.0
				Sfx.play("swing", 0.7)
				Sfx.play("teleport", 0.8)
				CombatFx.ring(get_parent(), global_position + Vector3(0.0, 0.2, 0.0), col, 3.0, 0.3)
				if cam != null:
					cam.call("slow_mo", 0.9, 0.3)
					cam.call("zoom_pulse", 0.85, 0.6)
				_act["step"] = 1
			elif step == 1 and t >= 0.5:
				if tg4 != null and is_instance_valid(tg4):
					tg4.call("air_hold", 1.4)
					# rejoint la cible dans le ciel
					var side: Vector3 = (global_position - tg4.global_position)
					side.y = 0.0
					CombatFx.afterimage(get_parent(), global_position, col)
					global_position = tg4.global_position + side.normalized() * 1.2
					_face_to(tg4.global_position)
				velocity.y = 0.0
				_set_pose(0, 0.15)
				_strike(tg4, _tdmg("aerienne"), global_position, col)
				Sfx.play("swing", 1.1)
				_act["step"] = 2
			elif step >= 2 and step <= 5:
				velocity.y = 0.0
				if tg4 != null and is_instance_valid(tg4):
					_face_to(tg4.global_position)
				if t >= 0.5 + 0.18 * float(step - 1):
					_set_pose(step % 2, 0.12)
					_strike(tg4, _tdmg("aerienne"), global_position, col)
					if tg4 != null and is_instance_valid(tg4):
						CombatFx.afterimage(get_parent(), global_position, col)
						CombatFx.bolt(get_parent(), global_position + Vector3(0.0, 1.0, 0.0), tg4.global_position + Vector3(0.0, 1.0, 0.0), col, 0.15)
					Sfx.play("swing", 1.2 + 0.07 * float(step))
					_act["step"] = step + 1
			elif step == 6:
				velocity.y = 0.0
				if t >= 1.55:
					_set_pose(4, 0.4)
					_strike(tg4, _tdmg("aerienne") * 1.8, global_position, col)
					if tg4 != null and is_instance_valid(tg4):
						tg4.call("slam_down")
					velocity.y = -20.0
					Sfx.play("ulti_boom", 1.2)
					if cam != null:
						cam.call("slow_mo", 0.5, 0.2)
					_act["step"] = 7
			elif step == 7:
				velocity.y = -20.0
				if is_on_floor() or t > 2.6:
					_shockwave(global_position, 3.5, _tdmg("aerienne"), 8.0, col)
					if cam != null:
						cam.call("shake", 0.5)
					_end_action()
					return
			move_and_slide()
		"fantome":
			# Fantôme des ténèbres : 4 apparitions, une frappe à chacune, la dernière repousse
			invulnerable = true
			velocity = Vector3.ZERO
			state = "attack"
			if step < 4 and t >= 0.22 * float(step):
				var best: Node3D = null
				var best_d: float = 10.0
				for e in get_tree().get_nodes_in_group("enemies"):
					var en: Node3D = e as Node3D
					if en == null or String(en.get("state")) == "dead":
						continue
					var dd: float = en.global_position.distance_to(global_position) + (5.0 if en == _tp_last else 0.0)
					if dd < best_d:
						best_d = dd
						best = en
				if best == null:
					_end_action()
					return
				CombatFx.afterimage(get_parent(), global_position, Color(0.4, 0.2, 0.7))
				var ang: float = float(step) * 2.1
				global_position = _safe_dest(best.global_position + Vector3(cos(ang), 0.0, sin(ang)) * 1.3)
				_face_to(best.global_position)
				_tp_last = best
				_set_pose(step % 4, 0.2)
				Sfx.play("teleport", 1.4)
				if step < 3:
					_strike(best, _tdmg("fantome"), global_position, Color(0.6, 0.3, 1.0))
				else:
					_strike(best, _tdmg("fantome") * 1.5, global_position, Color(0.6, 0.3, 1.0))
					for en2 in _enemies_near(global_position, 3.5):
						en2.call("knockback", en2.global_position - global_position, 11.0)
					CombatFx.ring(get_parent(), global_position + Vector3(0.0, 0.2, 0.0), Color(0.6, 0.3, 1.0), 3.5, 0.3)
				_act["step"] = step + 1
				if step + 1 >= 4:
					_act["end"] = t + 0.3
			if _act.has("end") and t >= float(_act["end"]):
				_end_action()
				return
			move_and_slide()
		"celeste":
			# Dragon céleste (en vol) : frappe diagonale, projection, pivot, seconde frappe
			var tg5: Node3D = _act_target()
			invulnerable = true
			state = "attack"
			if tg5 == null or not is_instance_valid(tg5) or String(tg5.get("state")) == "dead":
				_end_action()
				return
			var to_t: Vector3 = tg5.global_position + Vector3(0.0, 0.8, 0.0) - (global_position + Vector3(0.0, 0.9, 0.0))
			if step == 0 or step == 2:
				if to_t.length() < 1.6 or t > 0.4:
					_set_pose(1 if step == 0 else 2, 0.25)
					_strike(tg5, _tdmg("celeste") * (1.0 if step == 0 else 0.8), global_position, col)
					var side2: Vector3 = Vector3(-to_t.z, 0.0, to_t.x).normalized() * (1.0 if step == 0 else -1.0)
					tg5.call("knockback", side2, 7.0)
					Sfx.play("swing", 1.1)
					if cam != null:
						cam.call("shake", 0.2)
					_act["step"] = step + 1
					_act_t = 0.0
					velocity = Vector3.ZERO
				else:
					velocity = to_t.normalized() * 30.0
					_face_to(tg5.global_position)
			elif step == 1:
				# pivot en plein vol
				velocity = Vector3.ZERO
				face_yaw += delta * 14.0
				if t > 0.3:
					_act["step"] = 2
					_act_t = 0.0
			else:
				_end_action()
				return
			move_and_slide()
		"pluie":
			# Pluie de lames (en vol) : immobile, marque les cibles, les frappe, finit en piqué
			invulnerable = true
			velocity = Vector3.ZERO
			state = "attack"
			var marks: Array = _act.get("marks", [])
			if step == 0:
				var targets: Array = _enemies_near(global_position, 12.0, 14.0)
				targets = targets.slice(0, 6)
				_act["targets"] = targets
				for en in targets:
					var mk: MeshInstance3D = MeshInstance3D.new()
					var cone: CylinderMesh = CylinderMesh.new()
					cone.top_radius = 0.4
					cone.bottom_radius = 0.0
					cone.height = 0.6
					cone.radial_segments = 4
					mk.mesh = cone
					var mm: StandardMaterial3D = StandardMaterial3D.new()
					mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
					mm.albedo_color = Color(1.0, 0.3, 0.25)
					mm.no_depth_test = true
					mk.material_override = mm
					en.add_child(mk)
					mk.position = Vector3(0.0, 3.0, 0.0)
					marks.append(mk)
				_act["marks"] = marks
				_act["step"] = 1
				Sfx.play("ulti_charge", 1.5)
			else:
				var targets2: Array = _act.get("targets", [])
				var idx: int = step - 1
				if t >= 0.3 + 0.18 * float(idx) and idx < targets2.size():
					var raw: Variant = targets2[idx]
					var en3: Node3D = raw as Node3D if is_instance_valid(raw) else null
					if en3 != null and String(en3.get("state")) != "dead":
						CombatFx.afterimage(get_parent(), global_position, col)
						var ang2: float = float(idx) * 2.4
						global_position = en3.global_position + Vector3(cos(ang2) * 1.3, 0.6, sin(ang2) * 1.3)
						_face_to(en3.global_position)
						_set_pose(idx % 4, 0.18)
						_strike(en3, _tdmg("pluie"), global_position, col)
						Sfx.play("swing", 1.2 + 0.05 * float(idx))
					_act["step"] = step + 1
				elif idx >= targets2.size() and t >= 0.3 + 0.18 * float(idx) + 0.1:
					for mk2 in marks:
						if is_instance_valid(mk2):
							mk2.queue_free()
					_end_action()
					_stop_fly()
					global_position.y += 2.0
					_start_plunge()
					return
			move_and_slide()
		"meteore":
			# Frappe du météore : montée, visée d'une zone au sol, plongeon, onde limitée à la zone
			state = "guard" if step == 0 else "plunge"
			if step == 0:
				var want_y: float = float(_act.get("y0", global_position.y)) + 6.0
				velocity = Vector3(0.0, clampf((want_y - global_position.y) * 4.0, -4.0, 14.0), 0.0)
				if not _act.has("aim"):
					_act["y0"] = global_position.y
					var tg6: Node3D = _nearest_enemy(16.0)
					var aim0: Vector3 = global_position + Vector3(-sin(face_yaw), 0.0, -cos(face_yaw)) * 8.0
					if tg6 != null:
						aim0 = tg6.global_position
					_act["aim"] = aim0
					_build_aim_markers()
				var aim: Vector3 = _act["aim"]
				if has_input:
					aim += wish.normalized() * 12.0 * delta
				aim.y = _ground_at(aim)
				_act["aim"] = aim
				_aim_ring.visible = true
				_aim_ring.scale = Vector3(METEOR_RADIUS / TP_STRIKE_RADIUS, 0.2, METEOR_RADIUS / TP_STRIKE_RADIUS)
				_aim_ring.global_position = aim + Vector3(0.0, 0.15, 0.0)
				if cam != null:
					cam.call("zoom_pulse", 0.8, 0.2)
				if fmod(t, 0.08) < delta:
					CombatFx.spark(get_parent(), global_position + Vector3(0.0, 1.5, 0.0), col, 0.5)
				if not GameInput.attack_held() and t > 0.25:
					_act["step"] = 1
					_act_t = 0.0
					_stop_fly()
					_glide = false
					invulnerable = true
					if cam != null:
						cam.call("dive", 0.7)
					Sfx.play("swing", 0.6)
				move_and_slide()
			else:
				var aim2: Vector3 = _act["aim"]
				var to_a: Vector3 = aim2 - global_position
				velocity = to_a.normalized() * 34.0
				_face_to(aim2)
				move_and_slide()
				if is_on_floor() or to_a.length() < 1.0 or t > 1.5:
					_aim_ring.visible = false
					_aim_ring.scale = Vector3(1.0, 0.2, 1.0)
					_shockwave(global_position, METEOR_RADIUS, _tdmg("meteore"), 7.0, col)
					Sfx.play("ulti_boom", 1.1)
					if cam != null:
						cam.call("shake", 0.5)
						cam.call("slow_mo", 0.15, 0.35)
					_land_t = 0.15
					_end_action()
					return
		"eclipse":
			# Éclipse du dragon : épée levée, lumière qui baisse, téléportation au-dessus de la
			# cible principale, frappe descendante, onde de lumière qui repousse
			invulnerable = true
			if step == 0:
				state = "attack"
				velocity = Vector3.ZERO
				if world != null and world.has_method("dim"):
					world.call("dim", clampf(t / 0.5, 0.0, 1.0) * 0.55)
				if fmod(t, 0.06) < delta:
					var a2: float = t * 12.0
					CombatFx.spark(get_parent(), global_position + Vector3(cos(a2) * 0.45, 2.3 + sin(t * 7.0) * 0.2, sin(a2) * 0.45),
						Color(1.0, 0.85, 0.4), 0.45)
				if t >= 0.75:
					var tg7: Node3D = _nearest_enemy(15.0)
					var above: Vector3 = global_position + Vector3(0.0, 6.0, 0.0)
					if tg7 != null:
						above = tg7.global_position + Vector3(0.0, 6.0, 0.0)
					CombatFx.afterimage(get_parent(), global_position, Color(1.0, 0.85, 0.4))
					global_position = above
					_act["step"] = 1
					_act_t = 0.0
					Sfx.play("teleport", 0.9)
				move_and_slide()
			elif step == 1:
				state = "plunge"
				velocity = Vector3(0.0, -30.0, 0.0)
				move_and_slide()
				if is_on_floor() or t > 1.0:
					var gold: Color = Color(1.0, 0.85, 0.4)
					_shockwave(global_position, ECLIPSE_RADIUS, _tdmg("eclipse"), 12.0, gold)
					CombatFx.ring(get_parent(), global_position + Vector3(0.0, 0.5, 0.0), Color(1, 1, 1, 0.9), ECLIPSE_RADIUS * 1.2, 0.5)
					CombatFx.bolt(get_parent(), global_position + Vector3(0.0, 25.0, 0.0), global_position, gold, 0.6)
					Sfx.play("ulti_boom")
					Sfx.play("thunder", 1.4)
					if cam != null:
						cam.call("shake", 0.55)
						cam.call("slow_mo", 0.18, 0.35)
					if world != null and world.has_method("flash"):
						world.call("flash", 0.7)
					_act["step"] = 2
					_act_t = 0.0
			else:
				state = "land"
				velocity = Vector3.ZERO
				if world != null and world.has_method("dim"):
					world.call("dim", maxf(0.55 - t * 1.5, 0.0))
				move_and_slide()
				if t > 0.4:
					if world != null and world.has_method("dim"):
						world.call("dim", 0.0)
					_end_action()
					return
		"celebrate":
			state = "attack"
			velocity = Vector3.ZERO
			move_and_slide()
			if t > 1.8:
				_end_action()
				return
		_:
			_end_action()
	_update_blob()


## Victoire contre un boss : courte célébration (épée levée, caméra qui tourne).
func celebrate() -> void:
	if is_dead:
		return
	_start_action("celebrate")
	announce.emit("VICTOIRE !")
	Sfx.play("levelup", 0.9)
	if cam != null:
		cam.call("orbit", 1.8, 1.4)


func _aerial_target() -> Node3D:
	for en in _enemies_near(global_position, 3.6, 2.6):
		if not bool(en.get("is_boss")) and not bool(en.get("flying")):
			return en
	return null


# ================================================================ histoire

func mark_story(flag: String) -> void:
	if not story.has(flag):
		story.append(flag)
		save_progress()


func bosses_count() -> int:
	var n: int = 0
	for b in ALL_BOSSES:
		if story.has("boss_" + String(b)):
			n += 1
	return n


# ---------------------------------------------------------------- niveaux (un boss par niveau)
## Niveau 1 : Roi Squelette (repaire), 2 : Seigneur des ombres (bois sombre), 3 : Reine de la forêt,
## 4 : Gardien des montagnes (pics), 5 : Seigneur des nuages (ciel), 6 : Dragon des royaumes (arène).
const STAGES: Array = [
	{"kind": "roi", "name": "Roi Squelette", "terrain": "Repaire du boss"},
	{"kind": "ombre", "name": "Seigneur des ombres", "terrain": "Bois sombre"},
	{"kind": "reine", "name": "Reine de la forêt", "terrain": "Forêt fantastique"},
	{"kind": "gardien", "name": "Gardien des montagnes", "terrain": "Pics enneigés"},
	{"kind": "nuages", "name": "Seigneur des nuages", "terrain": "Ciel des pics"},
	{"kind": "dragon", "name": "Dragon des royaumes", "terrain": "Grande Arène"},
]


## Niveau actuel (0 = premier boss) : le premier boss de la liste pas encore vaincu.
func stage_index() -> int:
	for i in range(STAGES.size()):
		if not story.has("boss_" + String(STAGES[i]["kind"])):
			return i
	return STAGES.size()


## Appelé à la mort d'un boss : après les 5 boss de région, le Dragon des royaumes
## apparaît au-dessus de la Grande Arène ; sa défaite débloque et lance la fin.
func boss_defeated(kind: String) -> void:
	var k: String = kind if kind != "" else "roi"
	mark_story("boss_" + k)
	if k == "dragon":
		announce.emit("Le Dragon des royaumes est vaincu !")
		if not story.has("fin_debloquee"):
			mark_story("fin_debloquee")
			var t: SceneTreeTimer = get_tree().create_timer(3.0)
			t.timeout.connect(func() -> void:
				var c: Node = get_parent().get("cinematic")
				if c != null:
					c.call("play_ending"))
		return
	announce.emit("Boss vaincus : %d / 5" % bosses_count())
	var ns: int = stage_index()
	if ns < STAGES.size() - 1:
		var t3: SceneTreeTimer = get_tree().create_timer(2.5)
		t3.timeout.connect(func() -> void:
			announce.emit("NIVEAU %d : %s (%s)" % [ns + 1, String(STAGES[ns]["name"]), String(STAGES[ns]["terrain"])]))
	if bosses_count() >= ALL_BOSSES.size() and not story.has("dragon_eveille"):
		mark_story("dragon_eveille")
		var t2: SceneTreeTimer = get_tree().create_timer(3.0)
		t2.timeout.connect(func() -> void:
			announce.emit("Le Dragon des royaumes apparaît au-dessus de la Grande Arène !"))
