extends RefCounted
## Lieux construits du monde : arène, camp de départ, ruines, zone rocheuse,
## cœur de la forêt (arbre géant), volcan (lave, obsidienne), repaire du boss,
## zone des monstres, lac Miroir.
## Toutes les pièces d'un même lieu et d'un même matériau sont fusionnées en un seul
## maillage (SurfaceTool) : très peu d'appels de dessin, important pour Tecno Pop 7.
## Les collisions sont regroupées dans un seul StaticBody3D par lieu.

const WorldData = preload("res://scripts/world_data.gd")
const ModelLibrary = preload("res://scripts/model_library.gd")
const MED: String = "res://Assets/Environment/Medieval/"
const HAL: String = "res://Assets/Environment/Halloween/"
const DUN: String = "res://Assets/Environment/Dungeon/"
const NPC = preload("res://scripts/npc.gd")
const CHR: String = "res://Assets/Characters/"
const ROCK_PHOTO: String = "res://Assets/Textures/Photo/roche_rock023.jpg"
const Floater = preload("res://scripts/floater.gd")
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
	_village()
	_models_extra()
	# nuages : dessinés par le ciel (shaders/sky_clouds.gdshader)
	_npcs()


# ------------------------------------------------------------ outils

func _mat(key: String) -> Material:
	if mats.has(key):
		return mats[key] as Material
	if key == "arena_floor":
		var sm: ShaderMaterial = ShaderMaterial.new()
		sm.shader = load("res://shaders/arena_floor.gdshader") as Shader
		sm.set_shader_parameter("tex_rock", load(ROCK_PHOTO))
		mats[key] = sm
		return sm
	if key == "waterfall":
		var wm: ShaderMaterial = ShaderMaterial.new()
		wm.shader = load("res://shaders/waterfall.gdshader") as Shader
		mats[key] = wm
		return wm
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
		"castle":
			# pierre de château : vraie texture photo CC0 (Rock023), teinte claire bleutée
			m.albedo_color = Color(0.70, 0.71, 0.76)
			m.albedo_texture = load(ROCK_PHOTO) as Texture2D
			m.uv1_triplanar = true
			m.uv1_world_triplanar = true
			m.uv1_scale = Vector3(0.16, 0.16, 0.16)
		"castle_dark":
			m.albedo_color = Color(0.40, 0.40, 0.46)
			m.albedo_texture = load(ROCK_PHOTO) as Texture2D
			m.uv1_triplanar = true
			m.uv1_world_triplanar = true
			m.uv1_scale = Vector3(0.2, 0.2, 0.2)
		"statue":
			m.albedo_color = Color(0.30, 0.31, 0.35)
			m.albedo_texture = load(ROCK_PHOTO) as Texture2D
			m.uv1_triplanar = true
			m.uv1_world_triplanar = true
			m.uv1_scale = Vector3(0.5, 0.5, 0.5)
			m.roughness = 0.6
		"crystal_blue":
			m.albedo_color = Color(0.35, 0.75, 1.0)
			unshaded = true
		"glow_blue":
			m.albedo_color = Color(0.25, 0.55, 1.0, 0.35)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
			unshaded = true
		"island_rock":
			m.albedo_color = Color(0.42, 0.36, 0.31)
			m.albedo_texture = load(ROCK_PHOTO) as Texture2D
			m.uv1_triplanar = true
			m.uv1_world_triplanar = false
			m.uv1_scale = Vector3(0.06, 0.06, 0.06)
		"island_grass":
			m.albedo_color = Color(0.55, 0.72, 0.40)
			m.albedo_texture = load("res://Assets/Textures/Photo/herbe_ground037.jpg") as Texture2D
			m.uv1_triplanar = true
			m.uv1_world_triplanar = false
			m.uv1_scale = Vector3(0.12, 0.12, 0.12)
		"floor_tiles":
			m.albedo_color = Color(0.70, 0.68, 0.64)
			m.albedo_texture = load("res://Assets/Textures/dalles_pierre.png") as Texture2D
			m.uv1_triplanar = true
			m.uv1_world_triplanar = true
			m.uv1_scale = Vector3(0.22, 0.22, 0.22)
	if key == "stone_light" or key == "stone_dark" or key == "stone_ruin":
		# pierre : vraie texture photo CC0 (Rock023), projetée en coordonnées monde
		m.albedo_texture = load(ROCK_PHOTO) as Texture2D
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3(0.35, 0.35, 0.35)
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
	# --- sol : dalles sombres polies + incrustations d'or (shader), dessus à y = 0,1
	cyl("arena_floor", 47.0, 47.0, 0.3, Vector3(0.0, -0.05, 0.0), 64, true)
	# marche dorée en bordure du sol
	cyl("gold", 47.6, 47.9, 0.36, Vector3(0.0, -0.15, 0.0), 64, false)
	# --- 8 tours gothiques autour, portes aux 4 points cardinaux
	for i in range(8):
		var a: float = TAU / 8.0 * (float(i) + 0.5)
		var tp: Vector2 = Vector2(cos(a), sin(a)) * 54.0
		_gothic_tower(Vector3(tp.x, minf(_g(tp.x, tp.y), 0.0) - 1.0, tp.y), 22.0 + 6.0 * float(i % 2), -a)
	# --- arcades entre les tours (3 arches par côté), sauf aux portes
	for i in range(8):
		var a0: float = TAU / 8.0 * (float(i) + 0.5)
		var a1: float = TAU / 8.0 * (float(i) + 1.5)
		for k in range(4):
			var am: float = lerpf(a0, a1, (float(k) + 0.5) / 4.0)
			var mid: bool = k == 1 or k == 2
			var rr: float = 52.5
			var cp: Vector2 = Vector2(cos(am), sin(am)) * rr
			var yaw: float = -(am + PI * 0.5)
			var is_gate: bool = (i % 2 == 1) and mid
			if is_gate and k == 1:
				# grande porte : une seule arche haute centrée sur l'axe cardinal
				var ag: float = TAU / 8.0 * (float(i) + 1.0)
				var gp: Vector2 = Vector2(cos(ag), sin(ag)) * rr
				arch("castle", Vector3(gp.x, 0.0, gp.y), 9.0, 10.0, 3.0, -(ag + PI * 0.5), 2.2)
				continue
			if is_gate:
				continue
			arch("castle", Vector3(cp.x, 0.0, cp.y), 6.0, 7.0, 2.4, yaw, 1.8)
	# --- statues encapuchonnées tenant un cristal bleu, face au centre
	for i in range(8):
		var a2: float = TAU / 8.0 * (float(i) + 0.5)
		var sp: Vector2 = Vector2(cos(a2), sin(a2)) * 42.5
		_hooded_statue(Vector3(sp.x, 0.1, sp.y), a2)
	# --- panneaux indicateurs devant les portes
	var signs: Array = [
		"Zone rocheuse\nForêt fantastique",
		"Plaine de départ\nLac Miroir · Zone des monstres",
		"Zone volcanique",
		"Ruines anciennes\nRepaire du boss",
	]
	for j in range(4):
		var aj: float = float(j) * PI * 0.5
		var dir: Vector2 = Vector2(cos(aj), sin(aj))
		var sgp: Vector2 = dir * 63.0
		var sy: float = _g(sgp.x, sgp.y)
		cyl("wood", 0.12, 0.12, 3.0, Vector3(sgp.x, sy + 1.5, sgp.y), 6, true)
		box("wood", Vector3(2.6, 0.7, 0.12), Vector3(sgp.x, sy + 2.8, sgp.y), -(aj + PI * 0.5), false)
		sign_label(String(signs[j]), Vector3(sgp.x, sy + 3.6, sgp.y))
	_end()
	_arena_backdrop()


## Arche en pierre : ouverture de largeur w, piliers de hauteur h, profondeur d.
## pos = centre au sol. yaw : rotation (l'arche s'étend le long de l'axe X local).
func arch(mat: String, pos: Vector3, w: float, h: float, d: float, yaw: float, pw: float = 1.5) -> void:
	var b: Basis = Basis(Vector3.UP, yaw)
	var ax: Vector3 = b * Vector3.RIGHT
	var base_y: float = pos.y if pos.y > 0.0 else minf(_g(pos.x, pos.z), 0.0) - 1.5
	var y0: float = pos.y
	var top: float = y0 + h + w * 0.5 + 1.2
	for side in [-1.0, 1.0]:
		var pp: Vector3 = pos + ax * (w * 0.5 + pw * 0.5) * float(side)
		var ph: float = top - base_y
		box(mat, Vector3(pw, ph, d), Vector3(pp.x, base_y + ph * 0.5, pp.z), yaw)
		# chapiteau
		box(mat, Vector3(pw + 0.4, 0.5, d + 0.3), Vector3(pp.x, y0 + h, pp.z), yaw, false)
	# voussoirs en demi-cercle
	var n: int = 9
	var rad: float = w * 0.5
	for k in range(n):
		var t0: float = PI * float(k) / float(n)
		var t1: float = PI * float(k + 1) / float(n)
		var tm: float = (t0 + t1) * 0.5
		var cpos: Vector3 = pos + ax * (cos(tm) * (rad + 0.35)) + Vector3(0.0, h + sin(tm) * (rad + 0.35), 0.0)
		cpos.y = y0 + h + sin(tm) * (rad + 0.35)
		var seg_len: float = (rad + 0.7) * (t1 - t0) * 1.08
		var rot: Basis = Basis(Vector3.FORWARD, tm - PI * 0.5)
		box(mat, Vector3(seg_len, 0.7, d), cpos, yaw, false, rot)
	# remplissage au-dessus de l'arche (écoinçons) et corniche
	for side in [-1.0, 1.0]:
		var fp: Vector3 = pos + ax * (rad * 0.62) * float(side)
		box(mat, Vector3(rad * 0.76, rad * 0.5 + 0.5, d * 0.9), Vector3(fp.x, y0 + h + rad * 0.78 + 0.45, fp.z), yaw, false)
	box(mat, Vector3(w + pw * 2.0 + 0.2, 0.8, d + 0.4), Vector3(pos.x, top, pos.z), yaw, false)
	# créneaux
	for c in range(-2, 3):
		var cp: Vector3 = pos + ax * (float(c) * (w + pw * 2.0) / 5.0)
		box(mat, Vector3(0.9, 0.9, d * 0.6), Vector3(cp.x, top + 0.85, cp.z), yaw, false)


## Tour gothique : base carrée, étage, flèche pointue dorée, 4 tourelles d'angle.
func _gothic_tower(base: Vector3, h: float, yaw: float) -> void:
	var b: Basis = Basis(Vector3.UP, yaw)
	box("castle", Vector3(7.0, 2.0, 7.0), base + Vector3(0.0, 1.0, 0.0), yaw)
	box("castle", Vector3(6.0, h, 6.0), base + Vector3(0.0, 2.0 + h * 0.5, 0.0), yaw)
	# bandeaux et fenêtres en ogive (sombres) sur les 4 faces
	for lvl in range(3):
		var y: float = base.y + 2.0 + h * (0.3 + 0.25 * float(lvl))
		box("castle_dark", Vector3(6.4, 0.4, 6.4), Vector3(base.x, y + 2.2, base.z), yaw, false)
		for f in range(4):
			var n: Vector3 = b * Basis(Vector3.UP, float(f) * PI * 0.5) * Vector3(0.0, 0.0, 3.02)
			box("black", Vector3(1.0, 2.6, 0.1), Vector3(base.x + n.x, y, base.z + n.z), yaw + float(f) * PI * 0.5, false)
			cyl("black", 0.0, 0.55, 0.8, Vector3(base.x + n.x, y + 1.6, base.z + n.z), 4, false,
				Basis(Vector3.UP, yaw + float(f) * PI * 0.5 + PI * 0.25) * Basis.from_scale(Vector3(1.0, 1.0, 0.15)))
	var top: float = base.y + 2.0 + h
	box("castle", Vector3(7.2, 1.0, 7.2), Vector3(base.x, top + 0.5, base.z), yaw, false)
	box("castle", Vector3(4.6, 5.0, 4.6), Vector3(base.x, top + 3.5, base.z), yaw, false)
	cyl("castle_dark", 0.0, 3.6, 11.0, Vector3(base.x, top + 11.5, base.z), 4, false, Basis(Vector3.UP, yaw + PI * 0.25))
	cyl("gold", 0.0, 0.35, 3.0, Vector3(base.x, top + 18.4, base.z), 6, false)
	sphere("gold", 0.35, Vector3(base.x, top + 17.0, base.z), 6, 4)
	for cx in [-1.0, 1.0]:
		for cz in [-1.0, 1.0]:
			var o: Vector3 = b * Vector3(3.3 * float(cx), 0.0, 3.3 * float(cz))
			cyl("castle", 0.6, 0.7, 4.0, Vector3(base.x + o.x, top + 3.0, base.z + o.z), 8, false)
			cyl("castle_dark", 0.0, 0.85, 3.0, Vector3(base.x + o.x, top + 6.5, base.z + o.z), 6, false)


## Statue de moine encapuchonné (pierre sombre) qui tient un cristal bleu lumineux.
func _hooded_statue(pos: Vector3, a: float) -> void:
	var inward: Vector3 = Vector3(-cos(a), 0.0, -sin(a))
	var yaw: float = atan2(inward.x, inward.z)
	box("castle", Vector3(3.0, 1.6, 3.0), pos + Vector3(0.0, 0.8, 0.0), yaw)
	box("gold", Vector3(3.1, 0.15, 3.1), pos + Vector3(0.0, 1.55, 0.0), yaw, false)
	var p: Vector3 = pos + Vector3(0.0, 1.6, 0.0)
	# robe, épaules, capuche
	cyl("statue", 0.75, 1.25, 4.2, p + Vector3(0.0, 2.1, 0.0), 10, true)
	sphere("statue", 0.95, p + Vector3(0.0, 4.15, 0.0), 10, 6, Vector3(1.05, 0.55, 0.8))
	sphere("statue", 0.62, p + Vector3(0.0, 4.75, 0.0) + inward * 0.05, 10, 6, Vector3(1.0, 1.15, 1.05))
	cyl("statue", 0.0, 0.5, 0.7, p + Vector3(0.0, 5.2, 0.0) - inward * 0.25, 8, false,
		Basis(inward.cross(Vector3.UP).normalized(), -0.5))
	# visage dans l'ombre de la capuche
	sphere("black", 0.4, p + Vector3(0.0, 4.68, 0.0) + inward * 0.32, 8, 5, Vector3(1.0, 1.1, 0.5))
	# bras repliés devant la poitrine et cristal
	var front: Vector3 = p + inward * 0.85 + Vector3(0.0, 3.25, 0.0)
	sphere("statue", 0.5, front, 8, 5, Vector3(1.5, 0.6, 0.8))
	var cp: Vector3 = front + inward * 0.25 + Vector3(0.0, 0.85, 0.0)
	sphere("crystal_blue", 0.42, cp, 4, 2, Vector3(0.75, 1.5, 0.75))
	var halo: MeshInstance3D = MeshInstance3D.new()
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(2.6, 2.6)
	halo.mesh = q
	halo.material_override = _mat("glow_blue")
	halo.position = cp
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	halo.visibility_range_end = 160.0
	g_extra.append(halo)


## Décor lointain de l'arène : aqueduc à arches et îles flottantes avec cascades.
func _arena_backdrop() -> void:
	_begin("Arene_Decor")
	# aqueduc derrière la porte nord (deux étages d'arches)
	for k in range(9):
		var x: float = -64.0 + 16.0 * float(k)
		var z: float = -118.0
		arch("castle", Vector3(x, 0.0, z), 10.0, 14.0, 4.0, 0.0, 3.0)
		arch("castle", Vector3(x, 22.0, z), 10.0, 6.0, 3.4, 0.0, 3.0)
	_end()
	var islands: Array = [
		[Vector2(-150.0, -170.0), 85.0, 26.0], [Vector2(140.0, -210.0), 110.0, 34.0],
		[Vector2(230.0, -40.0), 70.0, 20.0], [Vector2(-230.0, 20.0), 95.0, 28.0],
		[Vector2(40.0, -300.0), 130.0, 40.0], [Vector2(-60.0, 230.0), 80.0, 18.0],
	]
	for i in range(islands.size()):
		var d: Array = islands[i]
		var c: Vector2 = d[0]
		_floating_island(Vector3(c.x, float(d[1]), c.y), float(d[2]), i)


func _floating_island(pos: Vector3, r: float, idx: int) -> void:
	var node: Node3D = Floater.new()
	node.name = "IleFlottante_%d" % idx
	node.position = pos
	root.add_child(node)
	var saved: Node3D = root
	root = node
	_begin("Ile")
	# roche (cône renversé irrégulier), dessus herbeux, petite tour et cascade
	cyl("island_rock", r, r * 0.25, r * 1.1, Vector3(0.0, -r * 0.55, 0.0), 9, false)
	cyl("island_rock", r * 0.55, r * 0.05, r * 0.9, Vector3(r * 0.25, -r * 1.3, r * 0.1), 7, false)
	cyl("island_grass", r * 1.02, r, 1.2, Vector3(0.0, 0.5, 0.0), 12, false)
	var th: float = r * 1.1
	cyl("castle", r * 0.14, r * 0.17, th, Vector3(-r * 0.2, th * 0.5 + 1.0, -r * 0.15), 8, false)
	cyl("castle_dark", 0.0, r * 0.22, r * 0.6, Vector3(-r * 0.2, th + 1.0 + r * 0.3, -r * 0.15), 8, false)
	cyl("gold", 0.0, r * 0.03, r * 0.15, Vector3(-r * 0.2, th + 1.0 + r * 0.66, -r * 0.15), 6, false)
	cyl("castle", r * 0.09, r * 0.1, th * 0.6, Vector3(r * 0.35, th * 0.3 + 1.0, r * 0.2), 8, false)
	cyl("castle_dark", 0.0, r * 0.14, r * 0.4, Vector3(r * 0.35, th * 0.6 + 1.0 + r * 0.2, r * 0.2), 8, false)
	_end()
	for ch in node.get_children():
		for mi in ch.get_children():
			if mi is MeshInstance3D:
				(mi as MeshInstance3D).visibility_range_end = 1200.0
				(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# cascade qui tombe du bord
	var wf: MeshInstance3D = MeshInstance3D.new()
	var q: QuadMesh = QuadMesh.new()
	var fall: float = r * 2.6
	q.size = Vector2(r * 0.22, fall)
	wf.mesh = q
	wf.material_override = _mat("waterfall")
	var ea: float = float(idx) * 1.7
	wf.position = Vector3(cos(ea) * r * 0.98, 0.9 - fall * 0.5, sin(ea) * r * 0.98)
	wf.rotation.y = -ea + PI * 0.5
	wf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	wf.visibility_range_end = 1200.0
	node.add_child(wf)
	root = saved


# ------------------------------------------------------------ camp de départ

func _camp() -> void:
	_begin("CampDeDepart")
	var c: Vector2 = WorldData.CAMP
	var gy: float = _g(c.x, c.y)
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
	_end()
	# modèles KayKit (CC0) : tente, tonneaux, caisses, râtelier, cible
	var props: Array = [
		["tent", Vector2(3.0, 2.5), 0.4, 5.5], ["barrel", Vector2(5.5, -1.0), 0.0, 5.0],
		["barrel", Vector2(6.3, -0.2), 0.5, 5.0], ["crate_A_big", Vector2(5.0, 0.6), 0.3, 5.0],
		["crate_B_small", Vector2(5.1, 0.6), 0.8, 5.0], ["weaponrack", Vector2(-4.5, 2.0), 1.2, 5.0],
		["target", Vector2(-6.0, -4.0), 2.6, 5.0], ["resource_lumber", Vector2(0.0, 5.5), 0.2, 4.0],
		["sack", Vector2(4.2, 4.0), 0.0, 5.0], ["flag_blue", Vector2(-2.0, 5.0), 0.0, 6.0],
	]
	for pr in props:
		var o: Vector2 = pr[1]
		var pp: Vector2 = c + o
		var col: String = "box" if String(pr[0]) != "flag_blue" and String(pr[0]) != "sack" else ""
		ModelLibrary.place(root, MED + "Props/" + String(pr[0]) + ".gltf",
			Vector3(pp.x, _g(pp.x, pp.y) - 0.05, pp.y), float(pr[2]), float(pr[3]), col)


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


# ------------------------------------------------------------ modèles 3D CC0 (KayKit)

## Village de Boma : maisons autour d'une place avec puits et marché.
func _village() -> void:
	var holder: Node3D = Node3D.new()
	holder.name = "VillageDeBoma"
	root.add_child(holder)
	var c: Vector2 = WorldData.VILLAGE
	var b: String = MED + "Buildings/"
	var plan: Array = [
		["building_well_blue", 0.0, 0.0, 6.0], ["building_market_blue", 0.0, -13.0, 6.0],
		["building_tavern_blue", 18.0, -6.0, 6.0], ["building_home_A_blue", 16.0, 12.0, 6.5],
		["building_home_B_blue", 3.0, 20.0, 6.0], ["building_home_A_blue", -13.0, 17.0, 6.5],
		["building_blacksmith_blue", -19.0, 1.0, 6.0], ["building_home_B_blue", -15.0, -16.0, 6.0],
		["building_church_blue", 4.0, -30.0, 6.5], ["building_windmill_blue", -32.0, -22.0, 7.0],
		["building_tower_A_blue", 32.0, 22.0, 6.0], ["building_home_A_blue", 27.0, -22.0, 6.0],
	]
	for item in plan:
		var px: float = c.x + float(item[1])
		var pz: float = c.y + float(item[2])
		# chaque bâtiment regarde vers la place
		var yaw: float = atan2(c.x - px, c.y - pz) if (absf(float(item[1])) + absf(float(item[2]))) > 0.1 else 0.0
		ModelLibrary.place(holder, b + String(item[0]) + ".gltf", Vector3(px, _g(px, pz) - 0.05, pz), yaw, float(item[3]), "box")
	# clôtures en bois autour des jardins
	for k in range(64):
		var a: float = float(k) / 64.0 * TAU
		if k % 16 == 8:
			continue
		var fp: Vector2 = c + Vector2(cos(a), sin(a)) * 40.0
		ModelLibrary.place(holder, b + "fence_wood_straight.gltf", Vector3(fp.x, _g(fp.x, fp.y), fp.y), -a, 3.2, "box")
	# accessoires de la place
	var p: String = MED + "Props/"
	var deco: Array = [["barrel", 4.0, -6.0], ["barrel", 5.0, -5.0], ["crate_A_big", -5.0, -7.0],
		["crate_long_A", -6.0, 6.0], ["wheelbarrow", 7.0, 5.0], ["bucket_water", 2.5, 1.5], ["sack", -3.0, 8.0]]
	for d in deco:
		var dx: float = c.x + float(d[1])
		var dz: float = c.y + float(d[2])
		ModelLibrary.place(holder, p + String(d[0]) + ".gltf", Vector3(dx, _g(dx, dz) - 0.03, dz), float(d[1]), 5.0, "box")


func _models_extra() -> void:
	var holder: Node3D = Node3D.new()
	holder.name = "DecorsModeles"
	root.add_child(holder)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 31
	# --- zone des monstres : cimetière avec crypte, portail, lanternes, cercueils
	var m: Vector2 = WorldData.ZONES["monstres"]["center"]
	ModelLibrary.place(holder, HAL + "crypt.gltf", Vector3(m.x, _g(m.x, m.y) - 0.1, m.y - 25.0), 0.0, 1.3, "box")
	ModelLibrary.place(holder, HAL + "arch_gate.gltf", Vector3(m.x, _g(m.x, m.y + 40.0), m.y + 40.0), 0.0, 1.5, "")
	for k in range(10):
		var fx: float = m.x - 22.0 + float(k) * 4.4
		if k == 4 or k == 5:
			continue
		var path: String = HAL + ("fence_broken.gltf" if k % 3 == 0 else "fence.gltf")
		ModelLibrary.place(holder, path, Vector3(fx, _g(fx, m.y + 40.0), m.y + 40.0), 0.0, 1.0, "box")
	for k in range(26):
		var a: float = rng.randf() * TAU
		var d: float = rng.randf_range(6.0, 38.0)
		var gp: Vector2 = m + Vector2(cos(a), sin(a)) * d
		var g: Array = ["gravestone", "grave_A", "grave_B", "gravemarker_A"]
		ModelLibrary.place(holder, HAL + String(g[k % 4]) + ".gltf", Vector3(gp.x, _g(gp.x, gp.y) - 0.05, gp.y),
			rng.randf_range(-0.3, 0.3), 1.0, "box")
	for k in range(6):
		var a: float = float(k) / 6.0 * TAU
		var lp: Vector2 = m + Vector2(cos(a), sin(a)) * 30.0
		ModelLibrary.place(holder, HAL + "post_lantern.gltf", Vector3(lp.x, _g(lp.x, lp.y), lp.y), -a, 1.0, "box")
	ModelLibrary.place(holder, HAL + "coffin.gltf", Vector3(m.x + 8.0, _g(m.x + 8.0, m.y - 10.0), m.y - 10.0), 0.4, 1.0, "box")
	ModelLibrary.place(holder, HAL + "shrine_candles.gltf", Vector3(m.x - 6.0, _g(m.x - 6.0, m.y - 14.0), m.y - 14.0), 0.0, 1.2, "box")
	# --- repaire du boss : poteaux à crânes, piliers, autel à bougies
	var bo: Vector2 = WorldData.ZONES["boss"]["center"]
	for k in range(8):
		var a: float = float(k) / 8.0 * TAU + 0.2
		var sp: Vector2 = bo + Vector2(cos(a), sin(a)) * 22.0
		ModelLibrary.place(holder, HAL + "post_skull.gltf", Vector3(sp.x, _g(sp.x, sp.y), sp.y), -a + PI * 0.5, 1.2, "box")
	for k in range(4):
		var a: float = float(k) / 4.0 * TAU + PI * 0.25
		var pp: Vector2 = bo + Vector2(cos(a), sin(a)) * 13.0
		ModelLibrary.place(holder, HAL + "pillar.gltf", Vector3(pp.x, _g(pp.x, pp.y), pp.y), a, 1.4, "box")
	ModelLibrary.place(holder, HAL + "shrine_candles.gltf", Vector3(bo.x + 4.0, _g(bo.x, bo.y) + 0.1, bo.y), 0.0, 1.4, "box")
	# --- ruines : éboulis, coffre au trésor, épée brisée, torches
	var ru: Vector2 = WorldData.ZONES["ruines"]["center"]
	for k in range(4):
		var a: float = rng.randf() * TAU
		var rp: Vector2 = ru + Vector2(cos(a), sin(a)) * rng.randf_range(30.0, 70.0)
		ModelLibrary.place(holder, DUN + "rubble_large.glb", Vector3(rp.x, _g(rp.x, rp.y) - 0.2, rp.y), rng.randf() * TAU, 1.2, "box")
	var top: float = _g(ru.x, ru.y) + 0.9
	ModelLibrary.place(holder, DUN + "chest.glb", Vector3(ru.x, top, ru.y + 2.0), PI, 1.0, "box")
	ModelLibrary.place(holder, DUN + "sword_shield_broken.glb", Vector3(ru.x - 3.0, top + 0.8, ru.y - 3.0), 0.6, 1.0, "")
	for k in range(4):
		var a: float = float(k) / 4.0 * TAU + PI * 0.25
		var tp: Vector2 = ru + Vector2(cos(a), sin(a)) * 10.0
		ModelLibrary.place(holder, DUN + "torch_lit.glb", Vector3(tp.x, top + 0.4, tp.y), 0.0, 1.5, "")
	# --- arène : torches de part et d'autre des 4 grandes portes
	for j in range(4):
		var aj: float = float(j) * PI * 0.5
		for side in [-1.0, 1.0]:
			var tp: Vector2 = Vector2(cos(aj + float(side) * 0.11), sin(aj + float(side) * 0.11)) * 47.0
			ModelLibrary.place(holder, DUN + "torch_lit.glb", Vector3(tp.x, 0.1, tp.y), 0.0, 1.6, "")
	# --- lac : nénuphars et plantes d'eau
	var l: Vector2 = WorldData.LAKE_CENTER
	for k in range(40):
		var a: float = rng.randf() * TAU
		var d: float = sqrt(rng.randf()) * WorldData.LAKE_RADIUS * 0.85
		var wp: Vector2 = l + Vector2(cos(a), sin(a)) * d
		var path: String = MED + "Nature/" + ("waterlily_A.gltf" if k % 3 != 0 else "waterlily_B.gltf")
		if k % 5 == 0:
			path = MED + "Nature/waterplant_A.gltf"
		ModelLibrary.place(holder, path, Vector3(wp.x, WorldData.WATER_LEVEL + 0.03, wp.y), rng.randf() * TAU, 6.0, "", 150.0)


## Nuages KayKit dans le ciel.
func _clouds() -> void:
	var holder: Node3D = Node3D.new()
	holder.name = "Nuages"
	root.add_child(holder)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 77
	for k in range(26):
		var x: float = rng.randf_range(-650.0, 650.0)
		var z: float = rng.randf_range(-650.0, 650.0)
		var path: String = MED + "Nature/" + ("cloud_big.gltf" if k % 2 == 0 else "cloud_small.gltf")
		var cl: Node3D = ModelLibrary.place(holder, path, Vector3(x, rng.randf_range(120.0, 170.0), z),
			rng.randf() * TAU, rng.randf_range(10.0, 18.0), "", 1000.0)
		for ch in cl.get_children():
			(ch as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Personnages animés CC0 (KayKit) : aventuriers au camp et au village, squelettes
## (futurs ennemis) dans la zone des monstres.
func _npc(path: String, anim: String, p: Vector2, yaw: float, scale: float = 1.3) -> void:
	var n: Node3D = NPC.new()
	n.set("model_path", path)
	n.set("animation", anim)
	n.name = path.get_file().get_basename()
	n.position = Vector3(p.x, _g(p.x, p.y), p.y)
	n.rotation.y = yaw
	n.scale = Vector3(scale, scale, scale)
	root.add_child(n)


func _npcs() -> void:
	var c: Vector2 = WorldData.CAMP
	var f: Vector2 = c + Vector2(-2.0, -1.0)
	_npc(CHR + "Adventurers/Rogue.glb", "Sit_Floor_Idle", f + Vector2(1.6, 1.2), PI + 0.9)
	_npc(CHR + "Adventurers/Knight.glb", "Idle", c + Vector2(-5.5, 3.5), -0.6)
	var v: Vector2 = WorldData.VILLAGE
	_npc(CHR + "Adventurers/Barbarian.glb", "Cheer", v + Vector2(4.0, 4.0), PI * 0.8)
	_npc(CHR + "Adventurers/Mage.glb", "Spellcasting", v + Vector2(-5.0, -3.0), 0.7)
	_npc(CHR + "Adventurers/Knight.glb", "Idle", v + Vector2(10.0, -10.0), -2.3)
	# les squelettes sont maintenant de vrais ennemis (enemy_spawner.gd)
