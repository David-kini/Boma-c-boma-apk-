extends Node3D
## Vague d'énergie tirée par l'épée (attaque à distance). Croissant lumineux de la
## couleur de l'arme, vole tout droit, traverse jusqu'à 3 ennemis (une fois chacun).

const CombatFx = preload("res://scripts/combat_fx.gd")

var dir: Vector3 = Vector3.FORWARD
var speed: float = 26.0
var damage: float = 14.0
var color: Color = Color(0.55, 0.8, 1.0)
var shooter: Node = null
var _life: float = 0.95
var _hit: Array = []


func _ready() -> void:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(color.r, color.g, color.b, 0.85)
	# croissant : 9 segments épais en arc de cercle, légèrement incliné
	var holder: Node3D = Node3D.new()
	holder.rotation.z = 0.35
	add_child(holder)
	for k in range(9):
		var a: float = lerpf(-1.15, 1.15, float(k) / 8.0)
		var seg: MeshInstance3D = MeshInstance3D.new()
		var bm: BoxMesh = BoxMesh.new()
		var thick: float = 0.34 * (1.0 - absf(a) / 1.35)
		bm.size = Vector3(0.42, thick, 0.16)
		seg.mesh = bm
		seg.material_override = m
		seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		seg.position = Vector3(sin(a) * 1.1, 0.0, -cos(a) * 1.1 + 1.1)
		seg.rotation.y = -a
		holder.add_child(seg)
	# halo lumineux (toujours face à la caméra)
	var grad: Gradient = Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	var gt: GradientTexture2D = GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 64
	gt.height = 64
	var gm: StandardMaterial3D = m.duplicate() as StandardMaterial3D
	gm.albedo_texture = gt
	gm.albedo_color = Color(color.r, color.g, color.b, 0.9)
	gm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var glow: MeshInstance3D = MeshInstance3D.new()
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(2.6, 1.6)
	glow.mesh = q
	glow.material_override = gm
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(glow)
	var core: StandardMaterial3D = m.duplicate() as StandardMaterial3D
	core.albedo_color = Color(1.0, 1.0, 1.0, 0.9)
	var c: MeshInstance3D = MeshInstance3D.new()
	var cb: BoxMesh = BoxMesh.new()
	cb.size = Vector3(1.4, 0.08, 0.08)
	c.mesh = cb
	c.material_override = core
	c.position = Vector3(0.0, 0.0, 0.05)
	holder.add_child(c)
	look_at(global_position + dir, Vector3.UP)


func _process(delta: float) -> void:
	_life -= delta
	global_position += dir * speed * delta
	scale = Vector3.ONE * (1.0 + (0.95 - _life) * 0.6)
	for e in get_tree().get_nodes_in_group("enemies"):
		var en: Node3D = e as Node3D
		if en == null or _hit.has(en) or String(en.get("state")) == "dead":
			continue
		var hrv: Variant = en.get("hit_radius")
		var hr: float = float(hrv) if hrv != null else 0.0
		var d: Vector3 = en.global_position + Vector3(0.0, 0.9 if hr == 0.0 else 0.0, 0.0) - global_position
		if d.length() < 1.4 + hr:
			_hit.append(en)
			en.call("take_damage", damage, global_position - dir)
			CombatFx.spark(get_parent(), global_position, color, 0.9)
			if shooter != null:
				shooter.call("on_ranged_hit")
				if shooter.has_method("apply_power"):
					shooter.call("apply_power", en)
			if _hit.size() >= 3:
				queue_free()
				return
	if _life <= 0.0:
		CombatFx.spark(get_parent(), global_position, color, 0.6)
		queue_free()
