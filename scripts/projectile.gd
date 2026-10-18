extends Node3D
## Boule de feu lancée par les sorciers (et le boss). Avance en ligne droite,
## touche le joueur à moins de 0,8 m, disparaît au bout de 3 s ou au contact du sol.

const CombatFx = preload("res://scripts/combat_fx.gd")

var dir: Vector3 = Vector3.FORWARD
var speed: float = 13.0
var damage: float = 10.0
var color: Color = Color(1.0, 0.45, 0.1)
var world: Node3D = null
var _life: float = 3.0


func _ready() -> void:
	var core: MeshInstance3D = MeshInstance3D.new()
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = 0.28
	sm.height = 0.56
	sm.radial_segments = 10
	sm.rings = 5
	core.mesh = sm
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = color
	core.material_override = m
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(core)
	var halo: MeshInstance3D = MeshInstance3D.new()
	var hm: SphereMesh = SphereMesh.new()
	hm.radius = 0.5
	hm.height = 1.0
	hm.radial_segments = 10
	hm.rings = 5
	halo.mesh = hm
	var m2: StandardMaterial3D = m.duplicate() as StandardMaterial3D
	m2.albedo_color = Color(color.r, color.g * 0.6, color.b * 0.3, 0.35)
	halo.material_override = m2
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(halo)


func _process(delta: float) -> void:
	_life -= delta
	global_position += dir * speed * delta
	rotation.y += delta * 8.0
	var ps: Array = get_tree().get_nodes_in_group("player")
	if not ps.is_empty():
		var p: Node3D = ps[0] as Node3D
		if p.global_position.distance_to(global_position - Vector3(0.0, 1.0, 0.0)) < 0.9:
			p.call("take_damage", damage, global_position)
			_explode()
			return
	var ground: float = -1000.0
	if world != null:
		ground = float(world.call("ground_height", global_position.x, global_position.z))
	if _life <= 0.0 or global_position.y < ground:
		_explode()


func _explode() -> void:
	CombatFx.spark(get_parent(), global_position, color, 1.0)
	queue_free()
