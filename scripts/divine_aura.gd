extends Node3D
## Aura de la Transformation Divine : enveloppe dorée qui pulse, anneau tournant au sol,
## étincelles qui montent en boucle. Uniquement des maillages simples (léger sur mobile).

var _t: float = 0.0
var _shell: MeshInstance3D
var _ring: MeshInstance3D
var _sparks: Array = []
var active: bool = false
var _k: float = 0.0


func _add_mat(c: Color) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = c
	return m


func _ready() -> void:
	visible = false
	_shell = MeshInstance3D.new()
	var cap: CapsuleMesh = CapsuleMesh.new()
	cap.radius = 0.62
	cap.height = 2.3
	cap.radial_segments = 16
	cap.rings = 6
	_shell.mesh = cap
	_shell.position = Vector3(0.0, 1.0, 0.0)
	_shell.material_override = _add_mat(Color(1.0, 0.75, 0.2, 0.18))
	_shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_shell)
	_ring = MeshInstance3D.new()
	var tor: TorusMesh = TorusMesh.new()
	tor.inner_radius = 0.85
	tor.outer_radius = 1.0
	tor.rings = 32
	tor.ring_segments = 4
	_ring.mesh = tor
	_ring.position = Vector3(0.0, 0.05, 0.0)
	_ring.scale = Vector3(1.0, 0.2, 1.0)
	_ring.material_override = _add_mat(Color(1.0, 0.85, 0.35, 0.8))
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = 0.05
	sm.height = 0.1
	sm.radial_segments = 6
	sm.rings = 3
	var smat: StandardMaterial3D = _add_mat(Color(1.0, 0.95, 0.6, 1.0))
	for i in range(10):
		var s: MeshInstance3D = MeshInstance3D.new()
		s.mesh = sm
		s.material_override = smat
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(s)
		_sparks.append([s, randf() * TAU, randf(), randf_range(0.35, 0.75)])


func set_active(on: bool) -> void:
	active = on
	if on:
		visible = true


func _process(delta: float) -> void:
	_k = move_toward(_k, 1.0 if active else 0.0, delta * 3.0)
	if _k <= 0.0:
		visible = false
		return
	_t += delta
	var pulse: float = 0.14 + 0.08 * sin(_t * 8.0)
	(_shell.material_override as StandardMaterial3D).albedo_color.a = pulse * _k
	_shell.scale = Vector3.ONE * (1.0 + 0.04 * sin(_t * 8.0))
	_ring.rotation.y = _t * 3.0
	(_ring.material_override as StandardMaterial3D).albedo_color.a = 0.8 * _k
	for sp in _sparks:
		var node: MeshInstance3D = sp[0]
		var h: float = fmod(float(sp[2]) + _t * 0.6, 1.0)
		var a: float = float(sp[1]) + _t * 1.5
		var r: float = float(sp[3])
		node.position = Vector3(cos(a) * r, h * 2.3, sin(a) * r)
		node.scale = Vector3.ONE * (1.0 - h) * _k
