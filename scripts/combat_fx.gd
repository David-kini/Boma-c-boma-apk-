extends RefCounted
## Effets de combat légers (aucune particule GPU : compatible téléphones faibles).
## - spark(...)  : éclat lumineux qui grossit puis disparaît (impact d'épée, éclair).
## - number(...) : chiffre de dégâts qui monte et s'efface.

static func _unshaded(c: Color) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = c
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


static func spark(parent: Node, pos: Vector3, color: Color = Color(0.5, 0.8, 1.0), size: float = 0.6) -> void:
	var root: Node3D = Node3D.new()
	root.position = pos
	parent.add_child(root)
	var core: MeshInstance3D = MeshInstance3D.new()
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 8
	sm.rings = 4
	core.mesh = sm
	core.material_override = _unshaded(color)
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(core)
	# rayons en étoile
	var rays: Array = []
	for k in range(6):
		var ray: MeshInstance3D = MeshInstance3D.new()
		var bm: BoxMesh = BoxMesh.new()
		bm.size = Vector3(0.05, 0.05, 1.0)
		ray.mesh = bm
		ray.material_override = _unshaded(Color(1.0, 1.0, 1.0, 0.9))
		ray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ray.rotation = Vector3(randf_range(-1.2, 1.2), randf() * TAU, 0.0)
		root.add_child(ray)
		rays.append(ray)
	root.scale = Vector3.ONE * size * 0.3
	var tw: Tween = root.create_tween()
	tw.set_parallel(true)
	tw.tween_property(root, "scale", Vector3.ONE * size, 0.16).set_ease(Tween.EASE_OUT)
	tw.tween_property(core.material_override, "albedo_color:a", 0.0, 0.22)
	for r in rays:
		tw.tween_property((r as MeshInstance3D).material_override, "albedo_color:a", 0.0, 0.2)
	tw.chain().tween_callback(root.queue_free)


static func number(parent: Node, pos: Vector3, value: int, color: Color = Color(1.0, 0.9, 0.3)) -> void:
	var l: Label3D = Label3D.new()
	l.text = str(value)
	l.position = pos
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.font_size = 64
	l.pixel_size = 0.006
	l.outline_size = 14
	l.modulate = color
	parent.add_child(l)
	var tw: Tween = l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position", pos + Vector3(randf_range(-0.3, 0.3), 1.0, 0.0), 0.7).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.7).set_delay(0.25)
	tw.chain().tween_callback(l.queue_free)
