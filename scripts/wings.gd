extends Node3D
## Ailes magiques (vol de 10 s). 4 modèles : ange (plumes blanches), demon (membranes
## noires et rouges), eclair (énergie bleue), or (plumes dorées).
## Construites en code (plumes = boîtes fines en éventail), battement animé, apparition
## et disparition progressives. Accrochées à l'os de la poitrine du héros (dans le dos).

const VARIANTS: Array = ["ange", "demon", "eclair", "or"]
const NAMES: Dictionary = {"ange": "Ailes d'ange", "demon": "Ailes de démon", "eclair": "Ailes d'éclair", "or": "Ailes d'or"}

var variant: String = "ange"
var deployed: bool = false
var _t: float = 0.0
var _roots: Array = []          # [Node3D, côté]
var _k: float = 0.0             # 0 = repliées, 1 = déployées


func _ready() -> void:
	visible = false
	scale = Vector3.ONE * 0.01
	rebuild(variant)


func _mat() -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	match variant:
		"ange":
			m.albedo_color = Color(0.97, 0.97, 1.0)
			m.roughness = 0.7
			m.rim_enabled = true
			m.rim = 0.4
		"demon":
			m.albedo_color = Color(0.12, 0.03, 0.05)
			m.roughness = 0.5
			m.rim_enabled = true
			m.rim = 0.5
			m.rim_tint = 0.0
		"eclair":
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			m.albedo_color = Color(0.15, 0.40, 1.0, 0.45)
		_:
			m.albedo_color = Color(0.95, 0.74, 0.28)
			m.metallic = 0.6
			m.roughness = 0.3
	return m


func _edge_mat() -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if variant == "demon":
		m.albedo_color = Color(0.75, 0.08, 0.10)
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	elif variant == "eclair":
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.albedo_color = Color(0.85, 0.95, 1.0, 0.9)
	else:
		m.albedo_color = Color(0.93, 0.72, 0.30)
		m.metallic = 0.5
		m.roughness = 0.3
	return m


func rebuild(v: String) -> void:
	variant = v if VARIANTS.has(v) else "ange"
	for c in get_children():
		c.queue_free()
	_roots.clear()
	var mat: StandardMaterial3D = _mat()
	var edge: StandardMaterial3D = _edge_mat()
	for side in [-1.0, 1.0]:
		var sx: float = float(side)
		var root: Node3D = Node3D.new()
		root.position = Vector3(0.07 * sx, 0.12, 0.12)
		add_child(root)
		_roots.append([root, sx])
		# deux rangées de plumes larges qui se chevauchent (grandes rémiges + couvertures)
		for row in range(2):
			var n: int = 9 if row == 0 else 6
			for k in range(n):
				var f: float = float(k) / float(n - 1)
				var a: float = lerpf(1.05, -0.45, f) if row == 0 else lerpf(0.95, 0.05, f)
				var length: float = (0.75 + 0.75 * sin(f * PI * 0.85)) if row == 0 else (0.45 + 0.25 * sin(f * PI))
				var w: float = (0.30 if variant == "demon" else 0.24) if row == 0 else 0.22
				var dir: Vector3 = Vector3(cos(a) * sx, sin(a), 0.32).normalized()
				var b: Basis = Basis(Quaternion(Vector3.UP, dir)) * Basis(Vector3.UP, 0.25 * sx)
				var feather: MeshInstance3D = MeshInstance3D.new()
				var bm: BoxMesh = BoxMesh.new()
				bm.size = Vector3(w, length, 0.02)
				feather.mesh = bm
				feather.material_override = mat
				feather.transform = Transform3D(b, dir * length * 0.5 + Vector3(0.0, 0.0, 0.01 * float(row)))
				feather.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				root.add_child(feather)
				if row == 0:
					# nervure (os pour le démon, dorée ou lumineuse pour les autres)
					var rib: MeshInstance3D = MeshInstance3D.new()
					var rm: BoxMesh = BoxMesh.new()
					rm.size = Vector3(0.025, length * 1.02, 0.03)
					rib.mesh = rm
					rib.material_override = edge
					rib.transform = Transform3D(b, dir * length * 0.5 + Vector3(0.0, 0.0, -0.006))
					rib.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					root.add_child(rib)


func set_deployed(on: bool) -> void:
	deployed = on
	if on:
		visible = true


func _process(delta: float) -> void:
	_k = move_toward(_k, 1.0 if deployed else 0.0, delta * 3.0)
	scale = Vector3.ONE * maxf(_k, 0.01)
	if _k <= 0.01 and not deployed:
		visible = false
		return
	_t += delta
	var flap: float = sin(_t * 7.0)
	for r in _roots:
		var root: Node3D = r[0]
		var sx: float = r[1]
		root.rotation = Vector3(0.0, sx * (0.25 + 0.30 * flap), sx * 0.30 * sin(_t * 7.0 + 0.6))
