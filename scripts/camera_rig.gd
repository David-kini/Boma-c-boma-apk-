extends Node3D
## Caméra à la troisième personne : pivot qui suit le joueur + SpringArm3D
## (le bras raccourcit tout seul quand le terrain ou un mur gêne la vue).

const SENSITIVITY: float = 0.005
const PITCH_MIN: float = -1.25
const PITCH_MAX: float = 0.30
const PIVOT_HEIGHT: float = 1.5

var target: Node3D = null
var yaw: float = 0.0
var pitch: float = -0.28
var distance: float = 4.4
var spring: SpringArm3D
var camera: Camera3D


func _ready() -> void:
	spring = SpringArm3D.new()
	spring.spring_length = distance
	spring.margin = 0.3
	spring.collision_mask = 1
	add_child(spring)
	camera = Camera3D.new()
	camera.fov = 70.0
	camera.near = 0.1
	camera.far = GameSettings.view_distance()
	spring.add_child(camera)
	camera.current = true
	GameSettings.quality_changed.connect(_on_quality_changed)
	rotation = Vector3(pitch, yaw, 0.0)


func _on_quality_changed(_level: int) -> void:
	camera.far = GameSettings.view_distance()


func _process(delta: float) -> void:
	var d: Vector2 = GameInput.consume_cam()
	yaw -= d.x * SENSITIVITY
	pitch = clampf(pitch - d.y * SENSITIVITY, PITCH_MIN, PITCH_MAX)
	if target != null:
		var goal: Vector3 = target.global_position + Vector3(0.0, PIVOT_HEIGHT, 0.0)
		global_position = global_position.lerp(goal, 1.0 - exp(-20.0 * delta))
	rotation = Vector3(pitch, yaw, 0.0)
