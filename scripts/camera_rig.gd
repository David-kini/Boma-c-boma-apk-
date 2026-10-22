extends Node3D
## Caméra à la troisième personne :
## - pivot qui suit le joueur avec un léger retard (fluide), plus lent en hauteur (sauts) ;
## - SpringArm3D : le bras raccourcit tout seul quand un mur ou le terrain gêne ;
## - recentrage automatique derrière le héros quand il court et que l'on ne touche
##   pas la caméra pendant 1,5 s ;
## - zoom (molette sur PC) ; secousse (shake) pour les coups (phase combat).
## - CAMÉRA CINÉMATIQUE adaptée à la situation (sans retirer le contrôle au joueur) :
##   exploration (3e personne), combat (léger rapprochement), vol (suit l'altitude, recule),
##   boss (recule et cadre le héros et le boss), défaite (recul) ; effets ponctuels :
##   décalage latéral, zoom de préparation, vue plongeante, orbite courte (ultime/victoire),
##   ralenti bref. Option « effets de caméra réduits » : pas de ralenti ni d'orbite,
##   secousses atténuées.

const SENSITIVITY: float = 0.005
const PITCH_MIN: float = -1.2
const PITCH_MAX: float = 0.35
const DIST_MIN: float = 1.2
const DIST_MAX: float = 7.0
const AUTO_ALIGN_DELAY: float = 1.5

var target: Node3D = null
var yaw: float = 0.0
var pitch: float = -0.22
var distance: float = 4.2
var auto_align: bool = true
var pivot_height: float = 1.5
var spring: SpringArm3D
var camera: Camera3D
var _idle_t: float = 0.0
var _shake: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var mode: String = "explore"
var _dist_mult: float = 1.0
var size_mult: float = 1.0       # héros géant (forme divine) : la caméra recule
var _pivot_add: float = 0.0
var _lateral: float = 0.0
var _lateral_goal: float = 0.0
var _lateral_t: float = 0.0
var _zoom_mult: float = 1.0          # zoom ponctuel (préparation d'une frappe)
var _zoom_t: float = 0.0
var _dive_t: float = 0.0             # vue plongeante
var _orbit_t: float = 0.0
var _orbit_speed: float = 0.0
var _slow_end_ms: int = 0
var _defeat: bool = false


func _ready() -> void:
	spring = SpringArm3D.new()
	spring.spring_length = distance
	spring.margin = 0.3
	spring.collision_mask = 1
	add_child(spring)
	camera = Camera3D.new()
	camera.fov = 65.0
	camera.near = 0.05
	camera.far = GameSettings.view_distance()
	spring.add_child(camera)
	camera.current = true
	GameSettings.quality_changed.connect(_on_quality_changed)
	rotation = Vector3(pitch, yaw, 0.0)


func _on_quality_changed(_level: int) -> void:
	camera.far = GameSettings.view_distance()


## Secousse de caméra (0,1 = légère, 0,5 = forte), limitée et atténuée si effets réduits.
func shake(amount: float) -> void:
	var k: float = 1.0 if GameSettings.cam_fx else 0.35
	_shake = minf(maxf(_shake, amount * k), 0.55)


## Décalage latéral bref (combos au sol).
func lateral(amount: float, time: float = 0.35) -> void:
	_lateral_goal = amount
	_lateral_t = time


## Rapprochement progressif (préparation) : mult < 1 = plus près.
func zoom_pulse(mult: float, time: float) -> void:
	_zoom_mult = mult
	_zoom_t = time


## Vue plongeante (frappe du météore).
func dive(time: float) -> void:
	_dive_t = time


## Courte orbite cinématique autour du héros (ultime, victoire).
func orbit(time: float, speed: float = 1.6) -> void:
	if not GameSettings.cam_fx:
		return
	_orbit_t = time
	_orbit_speed = speed


## Ralenti bref (réservé aux moments importants), en temps réel.
func slow_mo(real_time: float, scale: float = 0.35) -> void:
	if not GameSettings.cam_fx:
		return
	Engine.time_scale = scale
	_slow_end_ms = Time.get_ticks_msec() + int(real_time * 1000.0)


func defeat(on: bool) -> void:
	_defeat = on


func _process(delta: float) -> void:
	var d: Vector2 = GameInput.consume_cam()
	if d.length() > 0.5:
		_idle_t = 0.0
	else:
		_idle_t += delta
	yaw -= d.x * SENSITIVITY
	pitch = clampf(pitch - d.y * SENSITIVITY, PITCH_MIN, PITCH_MAX)
	distance = clampf(distance + GameInput.consume_zoom(), DIST_MIN, DIST_MAX)
	# fin du ralenti (en temps réel, indépendant du ralenti lui-même)
	if _slow_end_ms > 0 and Time.get_ticks_msec() >= _slow_end_ms:
		_slow_end_ms = 0
		Engine.time_scale = 1.0
	var rd: float = delta / maxf(Engine.time_scale, 0.05)    # delta réel
	_update_mode(rd)
	if target != null:
		var goal: Vector3 = target.global_position + Vector3(0.0, (pivot_height + _pivot_add) * pow(size_mult, 1.3), 0.0)
		var p: Vector3 = global_position
		var kxz: float = 1.0 - exp(-14.0 * delta)
		var ky: float = 1.0 - exp(-7.0 * delta)
		global_position = Vector3(lerpf(p.x, goal.x, kxz), lerpf(p.y, goal.y, ky), lerpf(p.z, goal.z, kxz))
		# recentrage automatique derrière le héros en mouvement
		var spd: float = float(target.get("hspeed"))
		if auto_align and _idle_t > AUTO_ALIGN_DELAY and spd > 1.0:
			var fy: float = float(target.get("face_yaw"))
			yaw = lerp_angle(yaw, fy, 1.0 - exp(-1.2 * delta))
	# orbite et vue plongeante
	if _orbit_t > 0.0:
		_orbit_t -= rd
		yaw += _orbit_speed * rd
	var pitch_view: float = pitch
	if _dive_t > 0.0:
		_dive_t -= rd
		pitch_view = lerpf(pitch, -0.95, 0.8)
	_zoom_t -= rd
	var zm: float = _zoom_mult if _zoom_t > 0.0 else 1.0
	var want_len: float = distance * _dist_mult * zm * size_mult
	spring.spring_length = lerpf(spring.spring_length, want_len, 1.0 - exp(-6.0 * rd))
	_lateral_t -= rd
	if _lateral_t <= 0.0:
		_lateral_goal = 0.0
	_lateral = lerpf(_lateral, _lateral_goal, 1.0 - exp(-8.0 * rd))
	# secousse : décalage de l'image (ne touche pas à la position gérée par le SpringArm3D)
	if _shake > 0.001:
		camera.h_offset = _lateral + _rng.randf_range(-1.0, 1.0) * _shake * 0.15
		camera.v_offset = _rng.randf_range(-1.0, 1.0) * _shake * 0.15
		_shake = maxf(_shake - rd * 2.5, 0.0)
	else:
		camera.h_offset = _lateral
		camera.v_offset = 0.0
	rotation = Vector3(pitch_view, yaw, 0.0)


## Choisit le cadrage selon la situation du héros.
func _update_mode(rd: float) -> void:
	if target == null:
		return
	var m: String = "explore"
	var boss: Node3D = null
	for b in get_tree().get_nodes_in_group("boss"):
		var bn: Node3D = b as Node3D
		var st: String = String(bn.get("state"))
		var far: float = 70.0 if String(bn.get("boss_kind")) == "dragon" else 35.0
		if st != "dead" and st != "idle" and bn.global_position.distance_to(target.global_position) < far:
			boss = bn
			break
	var gh: float = 0.0
	var w: Node = target.get("world")
	if w != null:
		gh = float(w.call("ground_height", target.global_position.x, target.global_position.z))
	if _defeat:
		m = "defeat"
	elif boss != null:
		m = "boss"
	elif bool(target.get("is_flying")) or target.global_position.y - gh > 4.0:
		m = "air"
	elif bool(target.get("_enemy_near")):
		m = "combat"
	mode = m
	var dm: float = 1.0
	var pa: float = 0.0
	match m:
		"combat":
			dm = 0.86
		"air":
			dm = 1.35
			pa = 0.8
		"boss":
			dm = 1.45
			pa = 0.6
			# garde le boss dans le cadre : tourne doucement pour qu'il soit devant le héros
			if _idle_t > 0.8 and boss != null:
				var to_b: Vector3 = boss.global_position - target.global_position
				var want: float = atan2(-to_b.x, -to_b.z)
				yaw = lerp_angle(yaw, want, 1.0 - exp(-1.5 * rd))
				# boss volant (dragon) : la caméra lève les yeux pour le garder visible
				if to_b.y > 5.0:
					dm = 2.0
					var up: float = clampf(atan2(to_b.y, Vector2(to_b.x, to_b.z).length()) * 0.7, 0.0, PITCH_MAX)
					pitch = lerpf(pitch, up, 1.0 - exp(-1.2 * rd))
		"defeat":
			dm = 2.0
			pa = 1.0
	_dist_mult = lerpf(_dist_mult, dm, 1.0 - exp(-3.0 * rd))
	_pivot_add = lerpf(_pivot_add, pa, 1.0 - exp(-3.0 * rd))
