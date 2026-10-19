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


## Éclair : zigzag lumineux entre deux points, disparaît en 0,3 s.
static func bolt(parent: Node, from: Vector3, to: Vector3, color: Color = Color(0.6, 0.85, 1.0), width: float = 0.25) -> void:
	var root: Node3D = Node3D.new()
	parent.add_child(root)
	var mat: StandardMaterial3D = _unshaded(color)
	var core_mat: StandardMaterial3D = _unshaded(Color(1.0, 1.0, 1.0, 1.0))
	var n: int = 7
	var prev: Vector3 = from
	var dir: Vector3 = to - from
	var side: Vector3 = dir.cross(Vector3.FORWARD if absf(dir.normalized().y) > 0.9 else Vector3.UP).normalized()
	var side2: Vector3 = dir.cross(side).normalized()
	for k in range(1, n + 1):
		var f: float = float(k) / float(n)
		var p: Vector3 = from + dir * f
		if k < n:
			var jit: float = dir.length() * 0.06
			p += side * randf_range(-jit, jit) + side2 * randf_range(-jit, jit)
		for layer in range(2):
			var seg: MeshInstance3D = MeshInstance3D.new()
			var bm: BoxMesh = BoxMesh.new()
			var w: float = width if layer == 0 else width * 0.35
			bm.size = Vector3(w, w, prev.distance_to(p))
			seg.mesh = bm
			seg.material_override = mat if layer == 0 else core_mat
			seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(seg)
			var segdir: Vector3 = (p - prev).normalized()
			seg.look_at_from_position((prev + p) * 0.5, p, Vector3.UP if absf(segdir.y) < 0.9 else Vector3.RIGHT)
		prev = p
	var tw: Tween = root.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.3)
	tw.tween_property(core_mat, "albedo_color:a", 0.0, 0.3)
	tw.chain().tween_callback(root.queue_free)


## Onde de choc : anneau qui s'agrandit au sol.
static func ring(parent: Node, pos: Vector3, color: Color, radius: float = 4.0, time: float = 0.4) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var tor: TorusMesh = TorusMesh.new()
	tor.inner_radius = 0.85
	tor.outer_radius = 1.0
	tor.rings = 32
	tor.ring_segments = 4
	mi.mesh = tor
	var m: StandardMaterial3D = _unshaded(color)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = pos
	mi.scale = Vector3(0.3, 0.3, 0.3)
	var tw: Tween = mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(radius, 0.4, radius), time).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, time)
	tw.chain().tween_callback(mi.queue_free)


## Image rémanente (téléportation) : silhouette lumineuse qui s'efface.
static func afterimage(parent: Node, pos: Vector3, color: Color) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var cap: CapsuleMesh = CapsuleMesh.new()
	cap.radius = 0.35
	cap.height = 1.8
	cap.radial_segments = 10
	cap.rings = 4
	mi.mesh = cap
	var m: StandardMaterial3D = _unshaded(Color(color.r, color.g, color.b, 0.6))
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = pos + Vector3(0.0, 0.9, 0.0)
	var tw: Tween = mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(0.2, 1.6, 0.2), 0.35)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.35)
	tw.chain().tween_callback(mi.queue_free)
