extends RefCounted
## Décor posé sur chaque tuile de terrain proche.
## - Modèles 3D CC0 (KayKit, Assets/Environment) : arbres, bosquets, sapins, arbres morts,
##   rochers, tombes, os et crânes.
## - Pièces générées : buissons, champignons lumineux (forêt fantastique), pics d'obsidienne.
## Chaque pièce de modèle utilise un MultiMesh : 1 appel de dessin par pièce et par tuile.
## Placement déterministe (même graine par tuile). Densité réglée par la qualité graphique.

const WorldData = preload("res://scripts/world_data.gd")
const ModelLibrary = preload("res://scripts/model_library.gd")

const CHUNK: float = 64.0
const BASE_CANDIDATES: int = 70
const DENSITY: Array = [0.4, 0.6, 1.0, 1.2]
const NAT: String = "res://Assets/Environment/Medieval/Nature/"
const HAL: String = "res://Assets/Environment/Halloween/"

const GLOW_COLORS: Array = [Color(0.35, 0.95, 1.0), Color(0.75, 0.45, 1.0), Color(0.55, 1.0, 0.6)]

var data: RefCounted
var mat_lit: StandardMaterial3D
var mat_glow: StandardMaterial3D
## type -> {"models": [chemins] OU "parts": [[Mesh, glow, Transform3D, couleur]],
##          "collide": "cyl"|"sphere"|"", "r", "h", "smin", "smax"}
var types: Dictionary = {}


func _init(world_data: RefCounted) -> void:
	data = world_data
	mat_lit = StandardMaterial3D.new()
	mat_lit.vertex_color_use_as_albedo = true
	mat_lit.roughness = 0.95
	mat_glow = StandardMaterial3D.new()
	mat_glow.vertex_color_use_as_albedo = true
	mat_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_make_types()


func _cyl(rt: float, rb: float, h: float, seg: int) -> CylinderMesh:
	var c: CylinderMesh = CylinderMesh.new()
	c.top_radius = rt
	c.bottom_radius = rb
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	c.cap_bottom = false
	return c


func _sph(r: float, h: float, seg: int, rings: int) -> SphereMesh:
	var s: SphereMesh = SphereMesh.new()
	s.radius = r
	s.height = h
	s.radial_segments = seg
	s.rings = rings
	return s


func _at(p: Vector3) -> Transform3D:
	return Transform3D(Basis.IDENTITY, p)


func _make_types() -> void:
	types["tree"] = {"models": [NAT + "tree_single_A.gltf", NAT + "tree_single_A.gltf", NAT + "tree_single_B.gltf"],
		"collide": "cyl", "r": 0.35, "h": 4.0, "smin": 4.2, "smax": 6.0}
	types["grove"] = {"models": [NAT + "trees_A_large.gltf", NAT + "trees_A_medium.gltf", NAT + "trees_A_small.gltf"],
		"collide": "cyl", "r": 0.8, "h": 4.0, "smin": 3.2, "smax": 4.6}
	types["pine"] = {"models": [NAT + "trees_B_small.gltf", NAT + "trees_B_medium.gltf"],
		"collide": "cyl", "r": 0.6, "h": 4.0, "smin": 4.5, "smax": 6.0}
	types["dead"] = {"models": [HAL + "tree_dead_large.gltf", HAL + "tree_dead_medium.gltf",
		HAL + "tree_dead_small.gltf", HAL + "tree_dead_large_decorated.gltf"],
		"collide": "cyl", "r": 0.25, "h": 4.0, "smin": 1.0, "smax": 1.5}
	types["rock"] = {"models": [NAT + "rock_single_A.gltf", NAT + "rock_single_B.gltf",
		NAT + "rock_single_C.gltf", NAT + "rock_single_D.gltf", NAT + "rock_single_E.gltf"],
		"collide": "sphere", "r": 0.12, "h": 0.2, "smin": 5.0, "smax": 14.0}
	types["grave"] = {"models": [HAL + "gravestone.gltf", HAL + "gravemarker_A.gltf", HAL + "grave_A.gltf"],
		"collide": "", "r": 0.0, "h": 0.0, "smin": 0.9, "smax": 1.2}
	types["bone"] = {"models": [HAL + "bone_A.gltf", HAL + "bone_B.gltf", HAL + "skull.gltf", HAL + "ribcage.gltf"],
		"collide": "", "r": 0.0, "h": 0.0, "smin": 0.8, "smax": 1.3}
	types["bush"] = {
		"parts": [[_sph(0.9, 1.2, 6, 3), false, _at(Vector3(0.0, 0.4, 0.0)), "bush"]],
		"collide": "", "r": 0.0, "h": 0.0, "smin": 0.6, "smax": 1.3,
	}
	types["mushroom"] = {
		"parts": [
			[_cyl(0.06, 0.09, 0.5, 5), false, _at(Vector3(0.0, 0.25, 0.0)), "stem"],
			[_sph(0.32, 0.28, 6, 3), true, _at(Vector3(0.0, 0.55, 0.0)), "glow"],
		],
		"collide": "", "r": 0.0, "h": 0.0, "smin": 0.7, "smax": 2.0,
	}
	types["spike"] = {
		"parts": [[_cyl(0.0, 0.8, 3.5, 5), false, _at(Vector3(0.0, 1.6, 0.0)), "obsidian"]],
		"collide": "cyl", "r": 0.5, "h": 3.0, "smin": 0.6, "smax": 1.8,
	}


## Choisit le type de décor pour un point (ou "" = rien).
func _pick(x: float, z: float, h: float, rng: RandomNumberGenerator) -> String:
	if absf(x) > WorldData.HALF - 4.0 or absf(z) > WorldData.HALF - 4.0:
		return ""
	if data.is_reserved(x, z):
		return ""
	var f: float = data.zone_weight("foret", x, z)
	var m: float = data.zone_weight("monstres", x, z)
	var v: float = data.zone_weight("volcan", x, z)
	var ro: float = data.zone_weight("rochers", x, z)
	var ru: float = data.zone_weight("ruines", x, z)
	var edge: float = maxf(absf(x), absf(z))
	var mt: float = smoothstep(470.0, 600.0, edge)
	var open: float = (1.0 - f) * (1.0 - m) * (1.0 - v) * (1.0 - mt) * (1.0 - ro)
	var snow: bool = h > 150.0
	var flat: bool = data.slope_ny(x, z) > 0.8
	var table: Array = []
	if flat and not snow:
		table.append(["tree", 0.030 * open + 0.30 * f])
		table.append(["grove", 0.008 * open + 0.42 * f])
		table.append(["mushroom", 0.18 * f])
		table.append(["bush", 0.06 * open])
		table.append(["dead", 0.16 * m + 0.05 * v])
		table.append(["bone", 0.07 * m])
		table.append(["grave", 0.05 * m])
	if not snow or rng.randf() < 0.3:
		table.append(["pine", 0.50 * mt * (1.0 - v)])
	table.append(["rock", 0.02 + 0.30 * ro + 0.05 * ru + 0.08 * mt])
	table.append(["spike", 0.12 * v + 0.03 * m])
	var roll: float = rng.randf()
	var acc: float = 0.0
	for entry in table:
		acc += float(entry[1])
		if roll < acc:
			return String(entry[0])
	return ""


func _color(key: String, x: float, z: float, rng: RandomNumberGenerator) -> Color:
	var j: float = rng.randf_range(-0.05, 0.05)
	match key:
		"bush":
			return Color(0.20 + j, 0.42 + j * 2.0, 0.14)
		"stem":
			return Color(0.90, 0.88, 0.80)
		"glow":
			return GLOW_COLORS[rng.randi() % GLOW_COLORS.size()]
		"obsidian":
			return Color(0.06, 0.05, 0.08)
	return Color(1.0, 1.0, 1.0)


func decorate(node: Node3D, k: Vector2i, collide: bool) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(k)
	var ox: float = k.x * CHUNK
	var oz: float = k.y * CHUNK
	var n: int = int(float(BASE_CANDIDATES) * float(DENSITY[GameSettings.quality]))
	var buckets: Dictionary = {}   # clé -> [mesh, glow(-1 = matériaux du modèle), transforms, couleurs]
	var body: StaticBody3D = null
	for _i in range(n):
		var x: float = ox + rng.randf() * CHUNK
		var z: float = oz + rng.randf() * CHUNK
		var h: float = data.height_at(x, z)
		var t: String = _pick(x, z, h, rng)
		if t == "":
			continue
		var def: Dictionary = types[t]
		var s: float = rng.randf_range(float(def["smin"]), float(def["smax"]))
		var sc: Vector3 = Vector3(s, s, s)
		if t == "rock":
			sc = Vector3(s * rng.randf_range(0.8, 1.3), s * rng.randf_range(0.8, 1.6), s * rng.randf_range(0.8, 1.3))
		var basis: Basis = Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(sc)
		var base: Transform3D = Transform3D(basis, Vector3(x - ox, h - 0.1, z - oz))
		if def.has("models"):
			var models: Array = def["models"]
			var path: String = models[rng.randi() % models.size()]
			var parts: Array = ModelLibrary.parts(path)
			for pi in range(parts.size()):
				var part: Array = parts[pi]
				var key: String = path + "/" + str(pi)
				if not buckets.has(key):
					buckets[key] = [part[0], -1, [], []]
				(buckets[key][2] as Array).append(base * (part[1] as Transform3D))
		else:
			var plist: Array = def["parts"]
			for pi in range(plist.size()):
				var part: Array = plist[pi]
				var key: String = t + "/" + str(pi)
				if not buckets.has(key):
					buckets[key] = [part[0], 1 if bool(part[1]) else 0, [], []]
				(buckets[key][2] as Array).append(base * (part[2] as Transform3D))
				(buckets[key][3] as Array).append(_color(String(part[3]), x, z, rng))
		var ctype: String = def["collide"]
		if collide and ctype != "":
			if body == null:
				body = StaticBody3D.new()
				node.add_child(body)
			var cs: CollisionShape3D = CollisionShape3D.new()
			var r: float = float(def["r"]) * s
			if ctype == "sphere":
				var sp: SphereShape3D = SphereShape3D.new()
				sp.radius = maxf(r, 0.3)
				cs.shape = sp
				cs.position = base.origin + Vector3(0.0, sp.radius * 0.4, 0.0)
			else:
				var cy: CylinderShape3D = CylinderShape3D.new()
				cy.radius = maxf(r, 0.2)
				cy.height = 4.0
				cs.shape = cy
				cs.position = base.origin + Vector3(0.0, 2.0, 0.0)
			body.add_child(cs)
	for key in buckets:
		var b: Array = buckets[key]
		var xfs: Array = b[2]
		var cols: Array = b[3]
		var mode: int = int(b[1])
		var mm: MultiMesh = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = mode >= 0
		mm.mesh = b[0] as Mesh
		mm.instance_count = xfs.size()
		for i in range(xfs.size()):
			mm.set_instance_transform(i, xfs[i])
			if mode >= 0:
				mm.set_instance_color(i, cols[i])
		var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
		mmi.multimesh = mm
		if mode == 1:
			mmi.material_override = mat_glow
		elif mode == 0:
			mmi.material_override = mat_lit
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(mmi)
