extends RefCounted
## Lieux construits du monde : arène, camp de départ, ruines, zone rocheuse,
## cœur de la forêt (arbre géant), volcan (lave, obsidienne), repaire du boss,
## zone des monstres, lac Miroir.
## Toutes les pièces d'un même lieu et d'un même matériau sont fusionnées en un seul
## maillage (SurfaceTool) : très peu d'appels de dessin, important pour Tecno Pop 7.
## Les collisions sont regroupées dans un seul StaticBody3D par lieu.

const WorldData = preload("res://scripts/world_data.gd")
const VIS_RANGE: float = 420.0

var data: RefCounted
var root: Node3D
var mats: Dictionary = {}
var g_name: String = ""
var g_batches: Dictionary = {}
var g_body: StaticBody3D
var g_extra: Array = []


func build(parent: Node3D, world_data: RefCounted) -> void:
	root = parent
	data = world_data
	_arena()
	_camp()
	_ruins()
	_rocks_zone()
	_forest_heart()
	_volcano()
	_boss_lair()
	_monster_zone()
	_lake()


# ------------------------------------------------------------ outils

func _mat(key: String) -> StandardMaterial3D:
	if mats.has(key):
		return mats[key] as StandardMaterial3D
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.roughness = 0.9
	var unshaded: bool = false
	match key:
		"stone_light":
			m.albedo_color = Color(0.62, 0.60, 0.57)
		"stone_dark":
			m.albedo_color = Color(0.45, 0.43, 0.42)
		"stone_ruin":
			m.albedo_color = Color(0.56, 0.53, 0.47)
		"gold":
			m.albedo_color = Color(0.88, 0.66, 0.20)
			m.metallic = 0.6
			m.roughness = 0.35
		"black":
			m.albedo_color = Color(0.08, 0.07, 0.10)
			m.roughness = 0.4
		"wood":
			m.albedo_color = Color(0.45, 0.30, 0.18)
		"cloth":
			m.albedo_color = Color(0.62, 0.16, 0.12)
		"bone":
			m.albedo_color = Color(0.88, 0.85, 0.75)
		"bark":
			m.albedo_color = Color(0.34, 0.24, 0.16)
		"leaf_magic":
			m.albedo_color = Color(0.12, 0.55, 0.50)
		"fire":
			m.albedo_color = Color(1.0, 0.58, 0.15)
			unshaded = true
		"lava":
			m.albedo_color = Color(1.0, 0.38, 0.05)
			unshaded = true
		"crystal_red":
			m.albedo_color = Color(0.95, 0.12, 0.18)
			unshaded = true
		"crystal_cyan":
			m.albedo_color = Color(0.35, 0.92, 1.0)
			unshaded = true
		"water":
			m.albedo_color = Color(0.18, 0.42, 0.58, 0.72)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.roughness = 0.1
			m.metallic = 0.3
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mats[key] = m
	return m


func _g(x: float, z: float) -> float:
	return data.height_at(x, z)


func _begin(group_name: String) -> void:
	g_name = group_name
	g_batches = {}
	g_extra = []
	g_body = StaticBody3D.new()
	g_body.name = "Collisions"


func _end() -> void:
	var holder: Node3D = Node3D.new()
	holder.name = g_name
	root.add_child(holder)
	for key in g_batches:
		var st: SurfaceTool = g_batches[key]
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = _mat(String(key))
		mi.visibility_range_end = VIS_RANGE
		holder.add_child(mi)
	if g_body.get_child_count() > 0:
		holder.add_child(g_body)
	else:
		g_body.free()
	for node in g_extra:
		holder.add_child(node)


func _add(mat: String, mesh: Mesh, xf: Transform3D) -> void:
	if not g_batches.has(mat):
		var st: SurfaceTool = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		g_batches[mat] = st
	(g_batches[mat] as SurfaceTool).append_from(mesh, 0, xf)


func _shape(shape: Shape3D, xf: Transform3D) -> void:
	var cs: CollisionShape3D = CollisionShape3D.new()
	cs.shape = shape
	cs.transform = xf
	g_body.add_child(cs)


## Boîte centrée sur pos. yaw : rotation autour de Y. extra : rotation supplémentaire.
func box(mat: String, size: Vector3, pos: Vector3, yaw: float = 0.0, collide: bool = true,
		extra: Basis = Basis.IDENTITY) -> void:
	var xf: Transform3D = Transform3D(Basis(Vector3.UP, yaw) * extra, pos)
	var m: BoxMesh = BoxMesh.new()
	m.size = size
	_add(mat, m, xf)
	if collide:
		var s: BoxShape3D = BoxShape3D.new()
		s.size = size
		_shape(s, xf)


## Cylindre (ou cône si rt = 0) centré sur pos.
func cyl(mat: String, rt: float, rb: float, h: float, pos: Vector3, seg: int = 10,
		collide: bool = true, basis: Basis = Basis.IDENTITY) -> void:
	var xf: Transform3D = Transform3D(basis, pos)
	var m: CylinderMesh = CylinderMesh.new()
	m.top_radius = rt
	m.bottom_radius = rb
	m.height = h
	m.radial_segments = seg
	m.rings = 1
	_add(mat, m, xf)
	if collide:
		var s: CylinderShape3D = CylinderShape3D.new()
		# cylindre : rayon réel ; cône : la moitié du rayon de base
		var full: bool = minf(rt, rb) > 0.0
		s.radius = maxf(maxf(rt, rb) * (1.0 if full else 0.5), 0.1)
		s.height = h
		_shape(s, xf)


func sphere(mat: String, r: float, pos: Vector3, seg: int = 8, rings: int = 5,
		scale: Vector3 = Vector3.ONE, collide: bool = false) -> void:
	var m: SphereMesh = SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = seg
	m.rings = rings
	_add(mat, m, Transform3D(Basis.from_scale(scale), pos))
	if collide:
		var s: SphereShape3D = SphereShape3D.new()
		s.radius = r * minf(scale.x, minf(scale.y, scale.z))
		_shape(s, Transform3D(Basis.IDENTITY, pos))


## Anneau plat posé au sol.
func ring(mat: String, r: float, thick: float, pos: Vector3) -> void:
	var m: TorusMesh = TorusMesh.new()
	m.inner_radius = r - thick * 0.5
	m.outer_radius = r + thick * 0.5
	m.rings = 48
	m.ring_segments = 4
	_add(mat, m, Transform3D(Basis.from_scale(Vector3(1.0, 0.3, 1.0)), pos))


func sign_label(text: String, pos: Vector3) -> void:
	var l: Label3D = Label3D.new()
	l.text = text
	l.position = pos
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = 40
	l.pixel_size = 0.009
	l.outline_size = 10
	l.modulate = Color(1.0, 0.86, 0.35)
	l.visibility_range_end = 90.0
	g_extra.append(l)


## Rotation Y pour que l'axe X local suive la direction (dx, dz).
func yaw_x(dir: Vector2) -> float:
	return atan2(-dir.y, dir.x)


# ------------------------------------------------------------ arène

func _arena() -> void:
	_begin("Arene")
	# sol en pierre (dessus à y = 0,1) et anneaux dorés
	cyl("stone_light", 47.0, 47.0, 0.3, Vector3(0.0, -0.05, 0.0), 48, true)
	ring("gold", 12.0, 0.5, Vector3(0.0, 0.1, 0.0))
	ring("gold", 30.0, 0.5, Vector3(0.0, 0.1, 0.0))
	# éclair doré au centre
	box("gold", Vector3(1.0, 0.06, 5.0), Vector3(-0.9, 0.12, -2.2), 0.45, false)
	box("gold", Vector3(3.2, 0.06, 0.9), Vector3(0.0, 0.12, 0.0), 0.0, false)
	box("gold", Vector3(1.0, 0.06, 5.0), Vector3(0.9, 0.12, 2.2), 0.45, false)
	var step: float = TAU / 16.0
	# 16 piliers avec base et chapiteau (plus hauts près des portes)
	for i in range(16):
		var a: float = step * (float(i) + 0.5)
		var p: Vector2 = Vector2(cos(a), sin(a)) * 50.0
		var near_gate: bool = i % 4 == 0 or i % 4 == 3
		var h: float = 12.0 if near_gate else 9.0
		box("stone_light", Vector3(3.0, 0.6, 3.0), Vector3(p.x, 0.3, p.y), -a)
		cyl("stone_light", 1.1, 1.3, h, Vector3(p.x, h * 0.5, p.y), 10, true)
		box("stone_light", Vector3(3.2, 0.8, 3.2), Vector3(p.x, h + 0.4, p.y), -a, false)
	# murs et gradins entre les piliers, 4 portes aux points cardinaux
	for i in range(16):
		if i % 4 == 0:
			continue
		var ac: float = step * float(i)
		var dir: Vector2 = Vector2(cos(ac), sin(ac))
		var rot: float = -(ac + PI * 0.5)
		var wp: Vector2 = dir * 49.04
		box("stone_dark", Vector3(17.0, 3.0, 1.2), Vector3(wp.x, 1.5, wp.y), rot)
		for t in range(3):
			var r: float = 53.0 + 3.5 * float(t)
			var ht: float = 1.2 * float(t + 1)
			var tp: Vector2 = dir * r
			var gy: float = _g(tp.x, tp.y) - 0.3
			box("stone_dark", Vector3(0.40 * r, ht + 0.3, 3.5), Vector3(tp.x, gy + (ht + 0.3) * 0.5, tp.y), rot)
	var signs: Array = [
		"Zone rocheuse\nForêt fantastique",
		"Plaine de départ\nLac Miroir · Zone des monstres",
		"Zone volcanique",
		"Ruines anciennes\nRepaire du boss",
	]
	for j in range(4):
		var a: float = float(j) * PI * 0.5
		var dir: Vector2 = Vector2(cos(a), sin(a))
		var rot: float = -(a + PI * 0.5)
		var gp: Vector2 = dir * 49.04
		# linteau et bannière de la porte
		box("stone_light", Vector3(21.0, 1.6, 2.4), Vector3(gp.x, 12.0, gp.y), rot)
		box("gold", Vector3(3.0, 5.0, 0.15), Vector3(gp.x, 8.7, gp.y), rot, false)
		box("black", Vector3(0.7, 3.6, 0.2), Vector3(gp.x, 8.9, gp.y), rot, false)
		# braseros de chaque côté
		for side in [-1.0, 1.0]:
			var a2: float = a + float(side) * 0.2
			var bp: Vector2 = Vector2(cos(a2), sin(a2)) * 54.0
			var by: float = _g(bp.x, bp.y)
			cyl("stone_dark", 0.5, 0.6, 1.4, Vector3(bp.x, by + 0.7, bp.y), 8, true)
			cyl("gold", 0.9, 0.5, 0.5, Vector3(bp.x, by + 1.65, bp.y), 10, false)
			sphere("fire", 0.55, Vector3(bp.x, by + 2.1, bp.y), 6, 4, Vector3(1.0, 1.5, 1.0))
		# panneau indicateur
		var sp: Vector2 = dir * 63.0
		var sy: float = _g(sp.x, sp.y)
		cyl("wood", 0.12, 0.12, 3.0, Vector3(sp.x, sy + 1.5, sp.y), 6, true)
		box("wood", Vector3(2.6, 0.7, 0.12), Vector3(sp.x, sy + 2.8, sp.y), rot, false)
		sign_label(String(signs[j]), Vector3(sp.x, sy + 3.6, sp.y))
	_end()


# ------------------------------------------------------------ camp de départ

func _camp() -> void:
	_begin("CampDeDepart")
	var c: Vector2 = WorldData.CAMP
	var gy: float = _g(c.x, c.y)
	# tente (pyramide à 4 côtés)
	cyl("cloth", 0.0, 2.4, 2.8, Vector3(c.x + 2.5, gy + 1.3, c.y + 2.0), 4, true)
	# feu de camp : bûches croisées + flamme
	var f: Vector2 = c + Vector2(-2.0, -1.0)
	var fy: float = _g(f.x, f.y)
	for k in range(3):
		var yaw: float = float(k) * PI / 3.0
		box("wood", Vector3(1.6, 0.25, 0.25), Vector3(f.x, fy + 0.15, f.y), yaw, false)
	sphere("fire", 0.45, Vector3(f.x, fy + 0.6, f.y), 6, 4, Vector3(1.0, 1.6, 1.0))
	# bancs en rondins
	box("wood", Vector3(2.2, 0.45, 0.5), Vector3(f.x, fy + 0.22, f.y + 2.2), 0.0, true)
	box("wood", Vector3(0.5, 0.45, 2.2), Vector3(f.x - 2.2, fy + 0.22, f.y), 0.0, true)
	# caisses
	box("wood", Vector3(0.9, 0.9, 0.9), Vector3(c.x + 5.0, gy + 0.45, c.y - 1.0), 0.3, true)
	box("wood", Vector3(0.7, 0.7, 0.7), Vector3(c.x + 5.2, gy + 1.25, c.y - 1.1), 0.9, true)
	_end()


# ------------------------------------------------------------ ruines

func _ruins() -> void:
	_begin("Ruines")
	var c: Vector2 = WorldData.ZONES["ruines"]["center"]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 5
	# temple central : plateforme, rampe, colonnes, autel
	var gy: float = _g(c.x, c.y)
	var top: float = gy + 0.9
	box("stone_ruin", Vector3(22.0, 3.0, 22.0), Vector3(c.x, top - 1.5, c.y))
	var ang: float = atan(0.9 / 6.0)
	box("stone_ruin", Vector3(6.0, 0.4, 6.2), Vector3(c.x, top - 0.6, c.y + 14.0), 0.0, true,
		Basis(Vector3.RIGHT, ang))
	for k in range(8):
		var a: float = float(k) * TAU / 8.0
		var p: Vector2 = c + Vector2(cos(a), sin(a)) * 8.5
		var h: float = 7.0 if k % 3 != 0 else rng.randf_range(2.0, 4.0)
		cyl("stone_ruin", 0.6, 0.7, h, Vector3(p.x, top + h * 0.5, p.y), 10, true)
	box("stone_dark", Vector3(2.5, 1.1, 1.4), Vector3(c.x, top + 0.55, c.y), 0.0, true)
	# salles en ruine (murs cassés)
	for _r in range(6):
		var ra: float = rng.randf() * TAU
		var rc: Vector2 = c + Vector2(cos(ra), sin(ra)) * rng.randf_range(30.0, 85.0)
		var yaw: float = rng.randf() * TAU
		for si in range(4):
			var side_yaw: float = yaw + float(si) * PI * 0.5
			for jj in range(3):
				if si == 0 and jj == 1:
					continue
				if rng.randf() < 0.3:
					continue
				var local: Vector3 = Basis(Vector3.UP, side_yaw) * Vector3(-3.33 + 3.33 * float(jj), 0.0, 5.0)
				var wx: float = rc.x + local.x
				var wz: float = rc.y + local.z
				var h: float = rng.randf_range(0.6, 3.5)
				box("stone_ruin", Vector3(3.2, h + 0.4, 0.8), Vector3(wx, _g(wx, wz) + h * 0.5 - 0.2, wz), side_yaw)
	# colonnes couchées
	var lying: Basis = Basis(Vector3(0.0, 0.0, 1.0), PI * 0.5)
	for _f in range(10):
		var a: float = rng.randf() * TAU
		var p: Vector2 = c + Vector2(cos(a), sin(a)) * rng.randf_range(15.0, 90.0)
		var b: Basis = Basis(Vector3.UP, rng.randf() * TAU) * lying
		cyl("stone_ruin", 0.7, 0.7, 6.0, Vector3(p.x, _g(p.x, p.y) + 0.55, p.y), 10, true, b)
	# colonnes debout cassées
	for _s in range(14):
		var a: float = rng.randf() * TAU
		var p: Vector2 = c + Vector2(cos(a), sin(a)) * rng.randf_range(15.0, 95.0)
		var h: float = rng.randf_range(1.5, 7.0)
		cyl("stone_ruin", 0.65, 0.75, h, Vector3(p.x, _g(p.x, p.y) + h * 0.5 - 0.2, p.y), 10, true)
	# arches
	for _a in range(3):
		var a: float = rng.randf() * TAU
		var p: Vector2 = c + Vector2(cos(a), sin(a)) * rng.randf_range(25.0, 80.0)
		var yaw: float = rng.randf() * TAU
		var t: Vector3 = Basis(Vector3.UP, yaw) * Vector3(3.0, 0.0, 0.0)
		var py: float = _g(p.x, p.y)
		cyl("stone_ruin", 0.6, 0.7, 6.0, Vector3(p.x + t.x, py + 2.8, p.y + t.z), 10, true)
		cyl("stone_ruin", 0.6, 0.7, 6.0, Vector3(p.x - t.x, py + 2.8, p.y - t.z), 10, true)
		box("stone_ruin", Vector3(8.0, 1.0, 1.4), Vector3(p.x, py + 6.3, p.y), yaw, true)
	_end()


# ------------------------------------------------------------ zone rocheuse

func _rocks_zone() -> void:
	_begin("ZoneRocheuse")
	var c: Vector2 = WorldData.ZONES["rochers"]["center"]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 11
	for _i in range(24):
		var a: float = rng.randf() * TAU
		var p: Vector2 = c + Vector2(cos(a), sin(a)) * rng.randf_range(5.0, 120.0)
		var s: float = rng.randf_range(1.5, 4.0)
		sphere("stone_dark", s, Vector3(p.x, _g(p.x, p.y) + s * 0.35, p.y), 7, 4,
			Vector3(1.0, rng.randf_range(0.6, 1.0), 1.0), true)
	# aiguilles rocheuses
	for _i in range(7):
		var a: float = rng.randf() * TAU
		var p: Vector2 = c + Vector2(cos(a), sin(a)) * rng.randf_range(10.0, 100.0)
		var h: float = rng.randf_range(10.0, 18.0)
		cyl("stone_dark", 0.5, 2.5, h, Vector3(p.x, _g(p.x, p.y) + h * 0.5 - 0.5, p.y), 7, true)
	# arche naturelle
	var ap: Vector2 = c + Vector2(-20.0, 10.0)
	var ay: float = _g(ap.x, ap.y)
	cyl("stone_dark", 1.4, 2.2, 9.0, Vector3(ap.x - 5.0, ay + 4.3, ap.y), 7, true)
	cyl("stone_dark", 1.4, 2.2, 9.0, Vector3(ap.x + 5.0, ay + 4.3, ap.y), 7, true)
	box("stone_dark", Vector3(13.0, 2.4, 3.2), Vector3(ap.x, ay + 9.4, ap.y), 0.0, true)
	_end()


# ------------------------------------------------------------ forêt

func _forest_heart() -> void:
	_begin("CoeurDeLaForet")
	var c: Vector2 = WorldData.ZONES["foret"]["center"]
	var gy: float = _g(c.x, c.y)
	# arbre géant
	cyl("bark", 2.2, 3.6, 24.0, Vector3(c.x, gy + 11.5, c.y), 12, true)
	for k in range(5):
		var a: float = float(k) * TAU / 5.0 + 0.3
		var d: Vector2 = Vector2(cos(a), sin(a))
		box("bark", Vector3(6.0, 1.2, 1.4), Vector3(c.x + d.x * 3.8, gy + 0.3, c.y + d.y * 3.8),
			yaw_x(d), true, Basis(Vector3(0.0, 0.0, 1.0), -0.25))
	sphere("leaf_magic", 10.0, Vector3(c.x, gy + 27.0, c.y), 10, 6, Vector3(1.0, 0.7, 1.0))
	sphere("leaf_magic", 7.0, Vector3(c.x + 7.0, gy + 23.0, c.y - 3.0), 9, 5, Vector3(1.0, 0.7, 1.0))
	sphere("leaf_magic", 6.5, Vector3(c.x - 6.0, gy + 24.0, c.y + 4.0), 9, 5, Vector3(1.0, 0.7, 1.0))
	# cristaux lumineux autour des racines
	for k in range(8):
		var a: float = float(k) * TAU / 8.0
		var p: Vector2 = c + Vector2(cos(a), sin(a)) * 10.0
		var tilt: Basis = Basis(Vector3(cos(a + PI * 0.5), 0.0, sin(a + PI * 0.5)), 0.3)
		cyl("crystal_cyan", 0.0, 0.6, 3.2, Vector3(p.x, _g(p.x, p.y) + 1.4, p.y), 4, false, tilt)
	_end()


# ------------------------------------------------------------ volcan

func _volcano() -> void:
	_begin("Volcan")
	var v: Vector2 = WorldData.VOLCANO_CENTER
	var lava_y: float = _g(v.x, v.y) + 2.5
	cyl("lava", 26.0, 26.0, 0.4, Vector3(v.x, lava_y, v.y), 32, false)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 17
	for _i in range(22):
		var a: float = rng.randf() * TAU
		var p: Vector2 = v + Vector2(cos(a), sin(a)) * rng.randf_range(50.0, 150.0)
		var h: float = rng.randf_range(4.0, 9.0)
		var r: float = rng.randf_range(0.8, 1.8)
		cyl("black", 0.0, r, h, Vector3(p.x, _g(p.x, p.y) + h * 0.5 - 0.5, p.y), 6, true)
	_end()


# ------------------------------------------------------------ repaire du boss

func _boss_lair() -> void:
	_begin("RepaireDuBoss")
	var c: Vector2 = WorldData.ZONES["boss"]["center"]
	var gy: float = _g(c.x, c.y)
	# dalle centrale et grand cristal rouge flottant
	cyl("stone_dark", 10.0, 10.5, 3.0, Vector3(c.x, gy - 1.4, c.y), 24, true)
	sphere("crystal_red", 2.0, Vector3(c.x, gy + 5.0, c.y), 4, 2, Vector3(1.0, 2.0, 1.0))
	# obélisques noirs surmontés de cristaux
	for k in range(10):
		var a: float = float(k) * TAU / 10.0
		var p: Vector2 = c + Vector2(cos(a), sin(a)) * 34.0
		var py: float = _g(p.x, p.y)
		cyl("black", 0.35, 1.5, 14.0, Vector3(p.x, py + 6.5, p.y), 4, true)
		sphere("crystal_red", 0.6, Vector3(p.x, py + 14.4, p.y), 4, 2, Vector3(1.0, 1.8, 1.0))
	# grande porte tournée vers les ruines
	var ruins: Vector2 = WorldData.ZONES["ruines"]["center"]
	var d: Vector2 = (ruins - c).normalized()
	var perp: Vector2 = Vector2(-d.y, d.x)
	var gc: Vector2 = c + d * 40.0
	var yaw: float = yaw_x(perp)
	for side in [-1.0, 1.0]:
		var tp: Vector2 = gc + perp * 9.0 * float(side)
		box("black", Vector3(4.0, 16.0, 4.0), Vector3(tp.x, _g(tp.x, tp.y) + 7.5, tp.y), yaw)
	var gcy: float = _g(gc.x, gc.y)
	box("black", Vector3(22.0, 3.0, 4.5), Vector3(gc.x, gcy + 16.5, gc.y), yaw)
	sphere("crystal_red", 1.0, Vector3(gc.x, gcy + 19.0, gc.y), 4, 2, Vector3(1.0, 1.6, 1.0))
	_end()


# ------------------------------------------------------------ zone des monstres

func _monster_zone() -> void:
	_begin("ZoneDesMonstres")
	var c: Vector2 = WorldData.ZONES["monstres"]["center"]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 21
	# squelettes géants (colonne + côtes)
	for _k in range(3):
		var a: float = rng.randf() * TAU
		var sc: Vector2 = c + Vector2(cos(a), sin(a)) * rng.randf_range(10.0, 60.0)
		var yaw: float = rng.randf() * TAU
		var axis: Vector3 = Basis(Vector3.UP, yaw) * Vector3(1.0, 0.0, 0.0)
		var lat: Vector3 = Basis(Vector3.UP, yaw) * Vector3(0.0, 0.0, 1.0)
		var sy: float = _g(sc.x, sc.y)
		cyl("bone", 0.35, 0.35, 14.0, Vector3(sc.x, sy + 0.4, sc.y), 6, true,
			Basis(Vector3.UP, yaw) * Basis(Vector3(0.0, 0.0, 1.0), PI * 0.5))
		for i in range(6):
			var off: Vector3 = axis * (-5.0 + 2.0 * float(i))
			for side in [-1.0, 1.0]:
				var pos: Vector3 = Vector3(sc.x, sy + 2.2, sc.y) + off + lat * 1.4 * float(side)
				var b: Basis = Basis(Vector3.UP, yaw) * Basis(Vector3(1.0, 0.0, 0.0), -0.5 * float(side))
				cyl("bone", 0.12, 0.2, 5.0, pos, 5, false, b)
	# pieux en bois
	for _k in range(16):
		var a: float = rng.randf() * TAU
		var p: Vector2 = c + Vector2(cos(a), sin(a)) * rng.randf_range(20.0, 110.0)
		box("wood", Vector3(0.25, 3.0, 0.25), Vector3(p.x, _g(p.x, p.y) + 1.1, p.y), rng.randf() * TAU,
			true, Basis(Vector3.RIGHT, 0.6))
	# cages
	for _k in range(4):
		var a: float = rng.randf() * TAU
		var p: Vector2 = c + Vector2(cos(a), sin(a)) * rng.randf_range(15.0, 80.0)
		var py: float = _g(p.x, p.y)
		for cx in [-1.2, 1.2]:
			for cz in [-1.2, 1.2]:
				cyl("wood", 0.1, 0.1, 3.0, Vector3(p.x + float(cx), py + 1.5, p.y + float(cz)), 5, true)
		box("wood", Vector3(2.8, 0.2, 2.8), Vector3(p.x, py + 3.0, p.y), 0.0, false)
		box("wood", Vector3(2.8, 0.2, 2.8), Vector3(p.x, py + 0.1, p.y), 0.0, false)
	_end()


# ------------------------------------------------------------ lac

func _lake() -> void:
	_begin("LacMiroir")
	var l: Vector2 = WorldData.LAKE_CENTER
	cyl("water", 63.0, 63.0, 0.05, Vector3(l.x, WorldData.WATER_LEVEL, l.y), 40, false)
	# ponton vers la plaine
	var dir: Vector2 = (Vector2(0.0, 140.0) - l).normalized()
	var pc: Vector2 = l + dir * (WorldData.LAKE_RADIUS - 2.0)
	var yaw: float = atan2(dir.x, dir.y)
	box("wood", Vector3(2.2, 0.2, 12.0), Vector3(pc.x, WorldData.WATER_LEVEL + 0.5, pc.y), yaw, true)
	for k in range(4):
		var t: float = -5.0 + float(k) * 3.3
		for side in [-1.0, 1.0]:
			var off: Vector3 = Basis(Vector3.UP, yaw) * Vector3(1.0 * float(side), 0.0, t)
			cyl("wood", 0.12, 0.12, 2.4, Vector3(pc.x + off.x, WorldData.WATER_LEVEL - 0.6, pc.y + off.z), 5, false)
	_end()
