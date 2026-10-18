extends RefCounted
## Décor posé sur chaque tuile de terrain proche : arbres, sapins, arbres morts,
## buissons, rochers, champignons lumineux, pics d'obsidienne, os.
## Chaque pièce utilise un MultiMesh : 1 appel de dessin par pièce et par tuile.
## Placement déterministe (même graine par tuile) : le décor est toujours le même.
## Densité réglée par la qualité graphique (Ultra très bas = 40 %).

const WorldData = preload("res://scripts/world_data.gd")

const CHUNK: float = 64.0
const BASE_CANDIDATES: int = 70
const DENSITY: Array = [0.4, 0.6, 1.0, 1.2]

const FOREST_LEAVES: Array = [
	Color(0.10, 0.50, 0.42), Color(0.42, 0.22, 0.58), Color(0.12, 0.40, 0.18), Color(0.20, 0.52, 0.62),
]
const GLOW_COLORS: Array = [Color(0.35, 0.95, 1.0), Color(0.75, 0.45, 1.0), Color(0.55, 1.0, 0.6)]

var data: RefCounted
var mat_lit: StandardMaterial3D
var mat_glow: StandardMaterial3D
## type -> {"parts": [[Mesh, glow: bool, Transform3D, color_key]], "collide": String,
##          "r": float, "h": float, "smin": float, "smax": float}
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
	types["tree"] = {
		"parts": [
			[_cyl(0.18, 0.30, 3.2, 6), false, _at(Vector3(0.0, 1.6, 0.0)), "bark"],
			[_sph(2.2, 3.8, 7, 4), false, _at(Vector3(0.0, 4.6, 0.0)), "leaf"],
			[_sph(1.5, 2.6, 6, 3), false, _at(Vector3(0.7, 5.9, 0.3)), "leaf"],
		],
		"collide": "cyl", "r": 0.35, "h": 4.0, "smin": 0.8, "smax": 1.45,
	}
	types["pine"] = {
		"parts": [
			[_cyl(0.15, 0.25, 2.5, 5), false, _at(Vector3(0.0, 1.25, 0.0)), "bark"],
			[_cyl(0.0, 2.0, 5.5, 7), false, _at(Vector3(0.0, 4.6, 0.0)), "pine"],
		],
		"collide": "cyl", "r": 0.3, "h": 4.0, "smin": 0.8, "smax": 1.5,
	}
	types["dead"] = {
		"parts": [
			[_cyl(0.06, 0.30, 5.0, 5), false, _at(Vector3(0.0, 2.5, 0.0)), "dead"],
			[_cyl(0.03, 0.12, 2.2, 4), false,
				Transform3D(Basis(Vector3(0.0, 0.0, 1.0), -0.9), Vector3(0.75, 3.4, 0.0)), "dead"],
			[_cyl(0.03, 0.10, 1.8, 4), false,
				Transform3D(Basis(Vector3(1.0, 0.0, 0.0), 0.8), Vector3(0.0, 2.6, 0.55)), "dead"],
		],
		"collide": "cyl", "r": 0.3, "h": 4.0, "smin": 0.8, "smax": 1.4,
	}
	types["bush"] = {
		"parts": [[_sph(0.9, 1.2, 6, 3), false, _at(Vector3(0.0, 0.4, 0.0)), "bush"]],
		"collide": "", "r": 0.0, "h": 0.0, "smin": 0.6, "smax": 1.3,
	}
	types["rock"] = {
		"parts": [[_sph(1.0, 1.4, 6, 3), false, _at(Vector3(0.0, 0.3, 0.0)), "rock"]],
		"collide": "sphere", "r": 0.9, "h": 1.4, "smin": 0.5, "smax": 2.2,
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
	types["bone"] = {
		"parts": [[_cyl(0.07, 0.07, 1.1, 5), false,
			Transform3D(Basis(Vector3(0.0, 0.0, 1.0), PI * 0.5), Vector3(0.0, 0.08, 0.0)), "bone"]],
		"collide": "", "r": 0.0, "h": 0.0, "smin": 0.7, "smax": 1.6,
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
		table.append(["tree", 0.035 * open + 0.80 * f])
		table.append(["mushroom", 0.18 * f])
		table.append(["bush", 0.06 * open])
		table.append(["dead", 0.18 * m + 0.05 * v])
		table.append(["bone", 0.10 * m])
	if not snow or rng.randf() < 0.3:
		table.append(["pine", 0.55 * mt * (1.0 - v)])
	table.append(["rock", 0.02 + 0.30 * ro + 0.05 * ru + 0.08 * mt])
	table.append(["spike", 0.12 * v + 0.05 * m])
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
		"bark":
			return Color(0.36 + j, 0.25 + j, 0.16)
		"leaf":
			if data.zone_weight("foret", x, z) > 0.3:
				return FOREST_LEAVES[rng.randi() % FOREST_LEAVES.size()]
			return Color(0.22 + j, 0.48 + j * 2.0, 0.16)
		"pine":
			return Color(0.10, 0.30 + j, 0.16)
		"dead":
			return Color(0.42 + j, 0.40 + j, 0.38 + j)
		"bush":
			return Color(0.20 + j, 0.42 + j * 2.0, 0.14)
		"rock":
			if data.zone_weight("volcan", x, z) > 0.3:
				return Color(0.18 + j, 0.15 + j, 0.15 + j)
			return Color(0.48 + j, 0.46 + j, 0.44 + j)
		"stem":
			return Color(0.90, 0.88, 0.80)
		"glow":
			return GLOW_COLORS[rng.randi() % GLOW_COLORS.size()]
		"obsidian":
			return Color(0.06, 0.05, 0.08)
		"bone":
			return Color(0.88, 0.85, 0.75)
	return Color(1.0, 1.0, 1.0)


func decorate(node: Node3D, k: Vector2i, collide: bool) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(k)
	var ox: float = k.x * CHUNK
	var oz: float = k.y * CHUNK
	var n: int = int(float(BASE_CANDIDATES) * float(DENSITY[GameSettings.quality]))
	var buckets: Dictionary = {}   # "type/indice" -> [mesh, glow, transforms, colors]
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
			sc = Vector3(s * rng.randf_range(0.8, 1.4), s * rng.randf_range(0.5, 1.0), s * rng.randf_range(0.8, 1.4))
		var basis: Basis = Basis(Vector3.UP, rng.randf() * TAU).scaled(sc)
		var base: Transform3D = Transform3D(basis, Vector3(x - ox, h - 0.1, z - oz))
		var parts: Array = def["parts"]
		for pi in range(parts.size()):
			var part: Array = parts[pi]
			var key: String = t + "/" + str(pi)
			if not buckets.has(key):
				buckets[key] = [part[0], part[1], [], []]
			var b: Array = buckets[key]
			(b[2] as Array).append(base * (part[2] as Transform3D))
			(b[3] as Array).append(_color(String(part[3]), x, z, rng))
		var ctype: String = def["collide"]
		if collide and ctype != "":
			if body == null:
				body = StaticBody3D.new()
				node.add_child(body)
			var cs: CollisionShape3D = CollisionShape3D.new()
			var r: float = float(def["r"]) * s
			var hh: float = float(def["h"]) * s
			if ctype == "sphere":
				var sp: SphereShape3D = SphereShape3D.new()
				sp.radius = r
				cs.shape = sp
				cs.position = base.origin + Vector3(0.0, 0.2 * s, 0.0)
			else:
				var cy: CylinderShape3D = CylinderShape3D.new()
				cy.radius = r
				cy.height = hh
				cs.shape = cy
				cs.position = base.origin + Vector3(0.0, hh * 0.5, 0.0)
			body.add_child(cs)
	for key in buckets:
		var b: Array = buckets[key]
		var xfs: Array = b[2]
		var cols: Array = b[3]
		var mm: MultiMesh = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = b[0] as Mesh
		mm.instance_count = xfs.size()
		for i in range(xfs.size()):
			mm.set_instance_transform(i, xfs[i])
			mm.set_instance_color(i, cols[i])
		var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = mat_glow if bool(b[1]) else mat_lit
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(mmi)
