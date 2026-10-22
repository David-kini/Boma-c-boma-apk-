extends Node3D
## Démon spectral : une créature presque transparente, issue des ailes / de l'Épée du Démon,
## qui fonce sur un ennemi, le frappe, puis se dissipe. Maillages simples (léger sur mobile).

const CombatFx = preload("res://scripts/combat_fx.gd")
var target: Node3D = null
var damage: float = 30.0
var _t: float = 0.0
var _struck: bool = false
var _mats: Array = []
var _wl: MeshInstance3D
var _wr: MeshInstance3D
var _start: Vector3 = Vector3.ZERO
var start_pos: Vector3 = Vector3.ZERO


func _mat(c: Color) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = c
	_mats.append(m)
	return m


func _part(mesh: Mesh, m: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _ready() -> void:
	var body_m: StandardMaterial3D = _mat(Color(0.55, 0.04, 0.10, 0.30))
	var wing_m: StandardMaterial3D = _mat(Color(0.35, 0.02, 0.08, 0.22))
	var eye_m: StandardMaterial3D = _mat(Color(1.0, 0.85, 0.2, 0.9))
	var cap: CapsuleMesh = CapsuleMesh.new()
	cap.radius = 0.38
	cap.height = 1.7
	cap.radial_segments = 10
	cap.rings = 4
	_part(cap, body_m, Vector3(0.0, 1.0, 0.0))
	var head: SphereMesh = SphereMesh.new()
	head.radius = 0.3
	head.height = 0.6
	head.radial_segments = 10
	head.rings = 5
	_part(head, body_m, Vector3(0.0, 2.0, 0.0))
	for sx in [-1.0, 1.0]:
		var horn: CylinderMesh = CylinderMesh.new()
		horn.top_radius = 0.0
		horn.bottom_radius = 0.07
		horn.height = 0.5
		horn.radial_segments = 6
		_part(horn, body_m, Vector3(0.18 * sx, 2.3, 0.0), Vector3(0.0, 0.0, -0.45 * sx))
		var eye: SphereMesh = SphereMesh.new()
		eye.radius = 0.05
		eye.height = 0.1
		eye.radial_segments = 6
		eye.rings = 3
		_part(eye, eye_m, Vector3(0.11 * sx, 2.05, -0.26))
		# bras griffus
		var arm: CylinderMesh = CylinderMesh.new()
		arm.top_radius = 0.08
		arm.bottom_radius = 0.03
		arm.height = 1.1
		arm.radial_segments = 6
		_part(arm, body_m, Vector3(0.5 * sx, 1.1, -0.3), Vector3(-0.9, 0.0, 0.25 * sx))
	var wing: PrismMesh = PrismMesh.new()
	wing.size = Vector3(1.9, 1.6, 0.04)
	_wl = _part(wing, wing_m, Vector3(-1.1, 1.5, 0.3), Vector3(0.0, 0.0, 1.9))
	_wr = _part(wing, wing_m, Vector3(1.1, 1.5, 0.3), Vector3(0.0, 0.0, -1.9))
	scale = Vector3.ONE * 0.2
	_start = start_pos
	global_position = start_pos
	if target != null and is_instance_valid(target):
		look_at(Vector3(target.global_position.x, global_position.y, target.global_position.z), Vector3.UP)
		rotate_y(PI)


func _process(delta: float) -> void:
	_t += delta
	var fl: float = sin(_t * 18.0) * 0.35
	_wl.rotation.z = 1.9 + fl
	_wr.rotation.z = -1.9 - fl
	var tp: Vector3 = target.global_position if target != null and is_instance_valid(target) else global_position
	if _t < 0.3:
		# il surgit en grandissant puis fonce sur l'ennemi
		var k: float = _t / 0.3
		scale = Vector3.ONE * lerpf(0.2, 1.4, smoothstep(0.0, 1.0, k))
		global_position = _start.lerp(tp + Vector3(0.0, 0.2, 0.0) - (tp - _start).normalized() * 1.2, smoothstep(0.0, 1.0, k))
		_face(tp)
	elif not _struck:
		_struck = true
		if target != null and is_instance_valid(target) and String(target.get("state")) != "dead":
			target.call("take_damage", damage, global_position)
			if target.has_method("apply_element"):
				target.call("apply_element", "ombre")
			if target.has_method("knockback") and not bool(target.get("is_boss")):
				target.call("knockback", target.global_position - global_position, 12.0)
			CombatFx.spark(get_parent(), tp + Vector3(0.0, 1.0, 0.0), Color(0.9, 0.1, 0.2), 1.6)
			CombatFx.ring(get_parent(), tp + Vector3(0.0, 0.3, 0.0), Color(0.8, 0.05, 0.15, 0.8), 3.0, 0.3)
			Sfx.play("hit", 0.7)
	elif _t > 0.5:
		# se dissipe en montant
		var f: float = clampf((_t - 0.5) / 0.5, 0.0, 1.0)
		global_position.y += delta * 2.5
		for m in _mats:
			var c: Color = (m as StandardMaterial3D).albedo_color
			c.a *= (1.0 - f * 0.3)
			(m as StandardMaterial3D).albedo_color = c
		scale = Vector3.ONE * (1.4 + f * 0.6)
		if f >= 1.0:
			queue_free()


func _face(p: Vector3) -> void:
	var d: Vector3 = p - global_position
	d.y = 0.0
	if d.length() > 0.05:
		rotation.y = atan2(-d.x, -d.z) + PI
