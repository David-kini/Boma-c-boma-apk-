extends Node3D
## Arc : l'épée transformée. Même élément (couleur, pouvoir) que l'épée d'origine.
## Origine = poignée ; l'arc s'étire vers +Y comme la lame.

const Sword = preload("res://scripts/sword.gd")
@export var element: String = "eclair"


func _mat(c: Color, add: bool) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if add:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	return m


func _ready() -> void:
	var e: Dictionary = Sword.ELEMENTS.get(element, Sword.ELEMENTS["eclair"])
	var core: Color = e["core"]
	var glow: Color = e["glow"]
	var arm_m: StandardMaterial3D = _mat(core, false)
	var glow_m: StandardMaterial3D = _mat(Color(glow.r, glow.g, glow.b, 0.5), true)
	var n: int = 10
	# branches : arc de cercle en C (bombé vers l'avant, -Z)
	var prev: Vector3 = Vector3.ZERO
	for k in range(n + 1):
		var t: float = float(k) / float(n)
		var a: float = lerpf(-1.1, 1.1, t)
		var p: Vector3 = Vector3(0.0, sin(a) * 0.62, -(cos(a) - 0.45) * 0.34)
		if k > 0:
			_seg(prev, p, 0.035, arm_m)
			_seg(prev, p, 0.07, glow_m)
		prev = p
	# corde
	var top: Vector3 = Vector3(0.0, sin(1.1) * 0.62, -(cos(1.1) - 0.45) * 0.34)
	var bot: Vector3 = Vector3(0.0, -sin(1.1) * 0.62, -(cos(1.1) - 0.45) * 0.34)
	_seg(bot, top, 0.008, _mat(Color(1, 1, 1, 0.9), false))
	# poignée
	_seg(Vector3(0.0, -0.08, -0.15), Vector3(0.0, 0.08, -0.15), 0.045, _mat(Color(0.15, 0.1, 0.08), false))


func _seg(a: Vector3, b: Vector3, r: float, m: Material) -> void:
	var d: Vector3 = b - a
	if d.length() < 0.001:
		return
	var mi: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = d.length()
	cm.radial_segments = 6
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = (a + b) / 2.0
	mi.basis = Basis(Quaternion(Vector3.UP, d.normalized()))
	add_child(mi)
