extends CharacterBody3D
## Joueur : marche, course, saut (coyote time + tampon), esquive (invincible),
## récupération après une chute, COMBAT : combo d'épée en 5 coups avec visée
## automatique, points de vie, énergie, mort et réapparition ; VOL magique de 10 s ;
## TRANSFORMATION DIVINE de 10 s ; 10 armes ; XP, niveaux et sauvegarde.
## Déplacement relatif à la caméra. Origine = pieds.

signal hp_changed(hp: float, max_hp: float)
signal energy_changed(energy: float, max_energy: float)
signal combo_changed(count: int)
signal level_changed(level: int, xp: int, need: int)
signal announce(text: String)
signal inventory_changed(gold: int, potions: int)

const PlayerRig = preload("res://scripts/player_rig.gd")
const Sword = preload("res://scripts/sword.gd")
const CombatFx = preload("res://scripts/combat_fx.gd")
const Wings = preload("res://scripts/wings.gd")
const DivineAura = preload("res://scripts/divine_aura.gd")
const Weapons = preload("res://scripts/weapons.gd")
const SaveGame = preload("res://scripts/save_game.gd")

## Combo : durée (s), instant du coup (fraction), dégâts, portée (m), angle (cos mini,
## -1 = tout autour), élan vers l'avant (m/s)
const ATTACKS: Array = [
	{"dur": 0.40, "hit": 0.42, "dmg": 10.0, "range": 2.7, "arc": 0.25, "lunge": 3.5},
	{"dur": 0.40, "hit": 0.42, "dmg": 12.0, "range": 2.7, "arc": 0.25, "lunge": 3.5},
	{"dur": 0.50, "hit": 0.52, "dmg": 16.0, "range": 3.0, "arc": 0.15, "lunge": 4.5},
	{"dur": 0.62, "hit": 0.45, "dmg": 26.0, "range": 3.3, "arc": -1.0, "lunge": 2.0},
	{"dur": 0.60, "hit": 0.50, "dmg": 32.0, "range": 3.8, "arc": -1.0, "lunge": 1.5, "aoe": true},
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
var aura: Node3D
var _autosave: float = 30.0
# --- inventaire et personnalisation
const POTION_HEAL: float = 50.0
var gold: int = 0
var potions: int = 1
var coat_name: String = "Noir"


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

	_update_timers(delta)
	_update_powers(delta)
	if is_dead:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		state = "dead"
		_dead_t -= delta
		if _dead_t <= 0.0:
			_respawn()
		return

	# attaque (combo)
	if GameInput.attack_buffer > 0.0 and _dodge_t <= 0.0 and _hurt_t <= 0.0:
		if _atk_i < 0:
			GameInput.consume_attack()
			_start_attack(_combo_next)
		elif _atk_t > _dur(_atk_i) * 0.35:
			GameInput.consume_attack()
			_atk_queued = true
	if _atk_i >= 0:
		_process_attack(delta)

	if is_flying:
		_fly_move(delta, wish, has_input)
		return

	# esquive (annule l'attaque en cours)
	if GameInput.dodge_buffer > 0.0 and _dodge_cd <= 0.0 and _dodge_t <= 0.0 \
			and _land_t <= 0.0 and (on_floor or _coyote > 0.0):
		GameInput.consume_dodge()
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
		var speed: float = RUN_SPEED if GameInput.wants_run() else WALK_SPEED
		if is_divine:
			speed *= 1.3
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
			Sfx.play("jump")

	move_and_slide()
	_update_blob()

	hspeed = Vector2(velocity.x, velocity.z).length()
	var air: bool = not is_on_floor()
	if _hurt_t > 0.0:
		state = "hurt"
	elif _atk_i >= 0:
		state = "attack"
	elif _dodge_t > 0.0:
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
	elif _atk_i >= 0 or _hurt_t > 0.0:
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
	if not _atk_hit and _atk_t >= dur * float(a["hit"]):
		_atk_hit = true
		_deal_hits(a)
	if _atk_t >= dur:
		var queued: bool = _atk_queued
		var nxt: int = (_atk_i + 1) % ATTACKS.size()
		_end_attack()
		if queued:
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
		if dist > float(a["range"]):
			continue
		if float(a["arc"]) > -1.0 and dist > 0.4 and fwd.dot(to_e.normalized()) < float(a["arc"]):
			continue
		en.call("take_damage", float(a["dmg"]) * _dmg_mult(), global_position)
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
		combo_changed.emit(combo_count)
		energy = minf(energy + 5.0 * float(hits), max_energy)
		energy_changed.emit(energy, max_energy)
		if cam != null:
			cam.call("shake", 0.35 if _atk_i == 3 else 0.15)


## Appelé par les ennemis.
func take_damage(amount: float, from_pos: Vector3) -> void:
	if invulnerable or is_dead:
		return
	if is_divine:
		amount *= 0.5
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
		energy = max_energy * maxf(divine_left / DIVINE_TIME, 0.0)
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
	_fly_cd = FLY_COOLDOWN
	wings.call("set_deployed", false)


func _ground_h() -> float:
	if world != null:
		return float(world.call("ground_height", global_position.x, global_position.z))
	return 0.0


## Vol : déplacement libre à altitude réglable (SAUT = monter, ESQ. = descendre).
func _fly_move(delta: float, wish: Vector3, has_input: bool) -> void:
	if GameInput.consume_jump():
		_fly_h = minf(_fly_h + 3.0, 30.0)
	if GameInput.consume_dodge():
		_fly_h = maxf(_fly_h - 3.0, 1.5)
	var spd: float = FLY_FAST if GameInput.wants_run() else FLY_SPEED
	if is_divine:
		spd *= 1.3
	var target: Vector3 = wish.normalized() * spd if has_input else Vector3.ZERO
	velocity.x = move_toward(velocity.x, target.x, 14.0 * delta)
	velocity.z = move_toward(velocity.z, target.z, 14.0 * delta)
	var want_y: float = _ground_h() + _fly_h + sin(Time.get_ticks_msec() * 0.003) * 0.25
	velocity.y = clampf((want_y - global_position.y) * 3.0, -9.0, 9.0)
	move_and_slide()
	_update_blob()
	hspeed = Vector2(velocity.x, velocity.z).length()
	state = "attack" if _atk_i >= 0 else "fly"
	if _atk_i < 0 and hspeed > 0.5:
		face_yaw = atan2(-velocity.x, -velocity.z)


func _start_divine() -> void:
	is_divine = true
	divine_left = DIVINE_TIME
	aura.call("set_active", true)
	_equip_weapon(weapon_index, true)
	Sfx.play("divine")
	announce.emit("TRANSFORMATION DIVINE !")
	if cam != null:
		cam.call("shake", 0.5)
	# onde de choc : dégâts et recul autour du héros
	for e in get_tree().get_nodes_in_group("enemies"):
		var en: Node3D = e as Node3D
		if en != null and String(en.get("state")) != "dead" and en.global_position.distance_to(global_position) < 6.0:
			en.call("take_damage", 35.0, global_position)
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
	_equip_weapon(weapon_index, false)


## Équipe l'arme n° i (forme et dégâts) ; en Transformation, la lame devient divine.
func _equip_weapon(i: int, divine_look: bool) -> void:
	weapon_index = clampi(i, 0, Weapons.count() - 1)
	var d: Dictionary = Weapons.get_def(weapon_index)
	var sw: Node3D = Sword.new()
	sw.name = "Arme"
	sw.set("element", "divin" if divine_look else String(d["element"]))
	sw.set("length_scale", float(d["len"]))
	sw.set("width_scale", float(d["width"]))
	rig.call("equip_weapon", sw)
	_set_layer(sw, 2)


func cycle_weapon() -> void:
	var n: int = Weapons.count()
	for step in range(1, n + 1):
		var j: int = (weapon_index + step) % n
		if int(Weapons.get_def(j)["level"]) <= level:
			if j != weapon_index:
				_equip_weapon(j, is_divine)
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
		"gold": gold, "potions": potions, "coat": coat_name})


func _load_progress() -> void:
	var d: Dictionary = SaveGame.load_data()
	level = int(d.get("level", 1))
	xp = int(d.get("xp", 0))
	weapon_index = int(d.get("weapon", 0))
	wings_variant = String(d.get("wings", "ange"))
	gold = int(d.get("gold", 0))
	potions = int(d.get("potions", 1))
	coat_name = String(d.get("coat", "Noir"))
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
