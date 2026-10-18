extends Node3D
## Caméra à la troisième personne :
## - pivot qui suit le joueur avec un léger retard (fluide), plus lent en hauteur (sauts) ;
## - SpringArm3D : le bras raccourcit tout seul quand un mur ou le terrain gêne ;
## - recentrage automatique derrière le héros quand il court et que l'on ne touche
##   pas la caméra pendant 1,5 s ;
## - zoom (molette sur PC) ; secousse (shake) pour les coups (phase combat).

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


## Secousse de caméra (0,1 = légère, 0,5 = forte).
func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func _process(delta: float) -> void:
	var d: Vector2 = GameInput.consume_cam()
	if d.length() > 0.5:
		_idle_t = 0.0
	else:
		_idle_t += delta
	yaw -= d.x * SENSITIVITY
	pitch = clampf(pitch - d.y * SENSITIVITY, PITCH_MIN, PITCH_MAX)
	distance = clampf(distance + GameInput.consume_zoom(), DIST_MIN, DIST_MAX)
	if target != null:
		var goal: Vector3 = target.global_position + Vector3(0.0, pivot_height, 0.0)
		var p: Vector3 = global_position
		var kxz: float = 1.0 - exp(-14.0 * delta)
		var ky: float = 1.0 - exp(-7.0 * delta)
		global_position = Vector3(lerpf(p.x, goal.x, kxz), lerpf(p.y, goal.y, ky), lerpf(p.z, goal.z, kxz))
		# recentrage automatique derrière le héros en mouvement
		var spd: float = float(target.get("hspeed"))
		if auto_align and _idle_t > AUTO_ALIGN_DELAY and spd > 1.0:
			var fy: float = float(target.get("face_yaw"))
			yaw = lerp_angle(yaw, fy, 1.0 - exp(-1.2 * delta))
	spring.spring_length = lerpf(spring.spring_length, distance, 1.0 - exp(-8.0 * delta))
	# secousse : décalage de l'image (ne touche pas à la position gérée par le SpringArm3D)
	if _shake > 0.001:
		camera.h_offset = _rng.randf_range(-1.0, 1.0) * _shake * 0.15
		camera.v_offset = _rng.randf_range(-1.0, 1.0) * _shake * 0.15
		_shake = maxf(_shake - delta * 2.5, 0.0)
	else:
		camera.h_offset = 0.0
		camera.v_offset = 0.0
	rotation = Vector3(pitch, yaw, 0.0)
