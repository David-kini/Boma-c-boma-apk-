extends Node3D
## Héros 3D (référence : concept art "héros à l'épée d'éclair").
## - Skeleton3D de 18 os, animé procéduralement (idle, marche, course, saut, chute,
##   esquive, réception) + os "coat" pour le mouvement du manteau.
## - Corps en MAILLAGES SKINNÉS (déformés par le squelette) : jambes/pantalon/bottes,
##   torse/chemise/ceinture, gilet ouvert, long manteau ouvert à bordures dorées, bras.
## - Pièces rigides attachées aux os : tête modélisée (hero_head.gd : visage sculpté,
##   yeux, oreilles, lunettes), col, nœud papillon, boutons, boucle, épaulières, brassards, gants, chaussures.
## - La tête est dans "head_slot" : remplaçable par un vrai modèle (replace_head).
## Le personnage regarde vers -Z, pieds à y = 0, taille ≈ 1,79 m.

const HeroHead = preload("res://scripts/hero_head.gd")
const SKIN: Color = Color(0.90, 0.68, 0.60)   # teint albinos (identique à hero_head.gd)
const SHIRT: Color = Color(0.95, 0.95, 0.96)
const VEST: Color = Color(0.13, 0.11, 0.10)
const COAT: Color = Color(0.07, 0.065, 0.075)
const PANTS: Color = Color(0.14, 0.14, 0.16)
const BOOT: Color = Color(0.05, 0.045, 0.05)
const BELT: Color = Color(0.36, 0.22, 0.12)
const GOLD: Color = Color(0.93, 0.70, 0.26)
const BLACK: Color = Color(0.04, 0.04, 0.05)
const HIPS_REST: Vector3 = Vector3(0.0, 0.95, 0.0)
const HEAD_RADII: Vector3 = Vector3(0.112, 0.134, 0.122)
const HEAD_CENTER_Y: float = 0.112

## [nom, parent, position locale de repos]
const BONE_DEF: Array = [
	["hips", "", Vector3(0.0, 0.95, 0.0)],
	["spine", "hips", Vector3(0.0, 0.10, 0.0)],
	["chest", "spine", Vector3(0.0, 0.20, 0.0)],
	["neck", "chest", Vector3(0.0, 0.24, 0.0)],
	["head", "neck", Vector3(0.0, 0.06, 0.0)],
	["arm_l", "chest", Vector3(-0.23, 0.18, 0.0)],
	["fore_l", "arm_l", Vector3(0.0, -0.30, 0.0)],
	["hand_l", "fore_l", Vector3(0.0, -0.27, 0.0)],
	["arm_r", "chest", Vector3(0.23, 0.18, 0.0)],
	["fore_r", "arm_r", Vector3(0.0, -0.30, 0.0)],
	["hand_r", "fore_r", Vector3(0.0, -0.27, 0.0)],
	["thigh_l", "hips", Vector3(-0.09, -0.02, 0.0)],
	["shin_l", "thigh_l", Vector3(0.0, -0.43, 0.0)],
	["foot_l", "shin_l", Vector3(0.0, -0.43, 0.0)],
	["thigh_r", "hips", Vector3(0.09, -0.02, 0.0)],
	["shin_r", "thigh_r", Vector3(0.0, -0.43, 0.0)],
	["foot_r", "shin_r", Vector3(0.0, -0.43, 0.0)],
	["coat", "hips", Vector3(0.0, -0.05, 0.0)],
]

const POSED: Array = [
	"spine", "chest", "neck", "head", "arm_l", "fore_l", "arm_r", "fore_r",
	"hand_r", "thigh_l", "shin_l", "thigh_r", "shin_r", "coat",
]

var skeleton: Skeleton3D
var head_slot: Node3D
var bone_idx: Dictionary = {}
var rest_global: Dictionary = {}
var attachments: Dictionary = {}
var materials: Dictionary = {}
var current: Dictionary = {}
var hips_y: float = 0.0
var phase: float = 0.0
var t: float = 0.0
var weapon: Node3D = null
var attack_kind: int = 0          # coup du combo en cours (0..3), réglé par player.gd
var attack_t: float = 0.0         # avancement du coup (0..1)

## Poses de départ et de fin de chaque coup (le geste passe de l'une à l'autre).
const ATTACK_POSES: Array = [
	[{"arm_r": Vector3(0.4, 0.0, 1.5), "fore_r": Vector3(0.5, 0.0, 0.0), "hand_r": Vector3(-0.6, 0.0, 0.0), "chest": Vector3(0.0, 0.55, 0.0), "spine": Vector3(-0.1, 0.0, 0.0)},
	 {"arm_r": Vector3(1.3, 0.0, -0.4), "fore_r": Vector3(0.1, 0.0, 0.0), "hand_r": Vector3(-1.0, 0.0, 0.0), "chest": Vector3(0.0, -0.6, 0.0), "spine": Vector3(-0.2, 0.0, 0.0)}],
	[{"arm_r": Vector3(1.2, 0.0, -0.6), "fore_r": Vector3(0.3, 0.0, 0.0), "hand_r": Vector3(-1.0, 0.0, 0.0), "chest": Vector3(0.0, -0.6, 0.0), "spine": Vector3(-0.15, 0.0, 0.0)},
	 {"arm_r": Vector3(0.5, 0.0, 1.5), "fore_r": Vector3(0.2, 0.0, 0.0), "hand_r": Vector3(-0.5, 0.0, 0.0), "chest": Vector3(0.0, 0.6, 0.0), "spine": Vector3(-0.2, 0.0, 0.0)}],
	[{"arm_r": Vector3(2.9, 0.0, 0.15), "fore_r": Vector3(0.4, 0.0, 0.0), "hand_r": Vector3(0.3, 0.0, 0.0), "chest": Vector3(0.1, 0.0, 0.0), "spine": Vector3(0.15, 0.0, 0.0)},
	 {"arm_r": Vector3(0.7, 0.0, 0.15), "fore_r": Vector3(0.1, 0.0, 0.0), "hand_r": Vector3(-1.2, 0.0, 0.0), "chest": Vector3(-0.15, 0.0, 0.0), "spine": Vector3(-0.35, 0.0, 0.0)}],
	[{"arm_r": Vector3(1.55, 0.0, 1.3), "fore_r": Vector3(0.05, 0.0, 0.0), "hand_r": Vector3(-1.3, 0.0, 0.0), "arm_l": Vector3(0.3, 0.0, -1.0), "spine": Vector3(-0.15, 0.0, 0.0)},
	 {"arm_r": Vector3(1.55, 0.0, 1.3), "fore_r": Vector3(0.05, 0.0, 0.0), "hand_r": Vector3(-1.3, 0.0, 0.0), "arm_l": Vector3(0.3, 0.0, -1.0), "spine": Vector3(-0.15, 0.0, 0.0)}],
]


func _ready() -> void:
	for b in POSED:
		current[b] = Vector3.ZERO
	_build_skeleton()
	_build_skinned_body()
	_build_rigid_parts()
	_build_head()


# ================================================================ squelette

func _build_skeleton() -> void:
	skeleton = Skeleton3D.new()
	skeleton.name = "Skeleton"
	add_child(skeleton)
	for def in BONE_DEF:
		var bname: String = def[0]
		var parent_name: String = def[1]
		var rest_pos: Vector3 = def[2]
		var idx: int = skeleton.add_bone(bname)
		bone_idx[bname] = idx
		var pg: Vector3 = Vector3.ZERO
		if parent_name != "":
			skeleton.set_bone_parent(idx, int(bone_idx[parent_name]))
			pg = rest_global[parent_name]
		rest_global[bname] = pg + rest_pos
		skeleton.set_bone_rest(idx, Transform3D(Basis.IDENTITY, rest_pos))
	skeleton.reset_bone_poses()


func _attach(bone: String) -> BoneAttachment3D:
	if attachments.has(bone):
		return attachments[bone] as BoneAttachment3D
	var a: BoneAttachment3D = BoneAttachment3D.new()
	a.name = "Att_" + bone
	skeleton.add_child(a)
	a.bone_name = bone
	attachments[bone] = a
	return a


## Point d'accroche pour les armes : "hand_r" ou "hand_l".
func get_hand_mount(bone: String) -> Node3D:
	return _attach(bone)


## Équipe une arme dans la main droite (lame vers l'avant et le bas).
func equip_weapon(w: Node3D) -> void:
	if weapon != null:
		weapon.queue_free()
	weapon = w
	var mount: Node3D = _attach("hand_r")
	mount.add_child(w)
	w.transform = Transform3D(Basis(Vector3.RIGHT, -1.93), Vector3(0.0, -0.06, -0.01))


# ================================================================ matériaux

func _mat(key: String) -> StandardMaterial3D:
	if materials.has(key):
		return materials[key] as StandardMaterial3D
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.disable_receive_shadows = true
	match key:
		"body":
			m.vertex_color_use_as_albedo = true
			m.roughness = 0.8
		"coat":
			m.vertex_color_use_as_albedo = true
			m.roughness = 0.55
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		"gold":
			m.albedo_color = GOLD
			m.metallic = 0.45
			m.roughness = 0.3
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		"lens":
			m.albedo_color = Color(0.80, 0.45, 0.80, 0.45)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.roughness = 0.1
			m.metallic = 0.4
		"skin":
			m.albedo_color = SKIN
			m.roughness = 0.7
		_:
			m.albedo_color = Color(key)
			m.roughness = 0.8
	materials[key] = m
	return m


# ================================================================ maillages skinnés

## Anneau de section : y, demi-largeur rx, demi-profondeur rz, os a -> b (poids w vers b),
## couleur, et options : "open" (ouverture avant en radians), "cx", "cz", "leg", "coat".
func R(y: float, rx: float, rz: float, a: String, b: String, w: float, col: Color,
		opts: Dictionary = {}) -> Dictionary:
	var d: Dictionary = {"y": y, "rx": rx, "rz": rz, "a": a, "b": b, "w": w, "col": col}
	d.merge(opts)
	return d


## Construit un tube (ou une coque ouverte à l'avant) le long des anneaux, de haut en bas.
## segs : nombre de divisions. edge : largeur (0..1) de la bordure colorée edge_col
## sur les bords de l'ouverture. side : -1 jambe/bras gauche, +1 droit (pour l'os "leg").
func _loft(rings: Array, segs: int, cap_top: bool, cap_bottom: bool, edge: float = 0.0,
		edge_col: Color = GOLD) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var us: Array = []
	for j in range(segs + 1):
		us.append(float(j) / float(segs))
	if edge > 0.0:
		# colonnes supplémentaires pour des bordures nettes
		us.append_array([edge * 0.98, edge, edge * 1.02, 1.0 - edge * 1.02, 1.0 - edge, 1.0 - edge * 0.98])
		us.sort()
	var cols: int = us.size()
	var vcount: int = 0
	for ri in range(rings.size()):
		var ring: Dictionary = rings[ri]
		var prev_r: Dictionary = rings[maxi(ri - 1, 0)]
		var next_r: Dictionary = rings[mini(ri + 1, rings.size() - 1)]
		var open: float = float(ring.get("open", 0.0))
		var a0: float = -PI * 0.5 + open
		var a1: float = -PI * 0.5 + TAU - open
		var cx: float = float(ring.get("cx", 0.0))
		var cz: float = float(ring.get("cz", 0.0))
		for u in us:
			var th: float = lerpf(a0, a1, float(u))
			var x: float = cx + float(ring["rx"]) * cos(th)
			var z: float = cz + float(ring["rz"]) * sin(th)
			var col: Color = ring["col"]
			if edge > 0.0 and (float(u) <= edge or float(u) >= 1.0 - edge):
				col = edge_col
			st.set_color(col)
			st.set_normal(_ring_normal(prev_r, next_r, ring, th, x, z))
			_set_skin(st, ring, x, z)
			st.add_vertex(Vector3(x, float(ring["y"]), z))
			vcount += 1
	for i in range(rings.size() - 1):
		for j in range(cols - 1):
			var a: int = i * cols + j
			var b: int = a + 1
			var c: int = a + cols
			var d: int = c + 1
			for idx in [a, c, b, b, c, d]:
				st.add_index(idx)
	if cap_top:
		var r0: Dictionary = rings[0]
		st.set_color(r0["col"])
		st.set_normal(Vector3.UP)
		_set_skin(st, r0, float(r0.get("cx", 0.0)), float(r0.get("cz", 0.0)))
		st.add_vertex(Vector3(float(r0.get("cx", 0.0)), float(r0["y"]), float(r0.get("cz", 0.0))))
		var ci: int = vcount
		vcount += 1
		for j in range(cols - 1):
			for idx in [ci, j, j + 1]:
				st.add_index(idx)
	if cap_bottom:
		var rl: Dictionary = rings[rings.size() - 1]
		st.set_color(rl["col"])
		st.set_normal(Vector3.DOWN)
		_set_skin(st, rl, float(rl.get("cx", 0.0)), float(rl.get("cz", 0.0)))
		st.add_vertex(Vector3(float(rl.get("cx", 0.0)), float(rl["y"]), float(rl.get("cz", 0.0))))
		var cb: int = vcount
		var base: int = (rings.size() - 1) * cols
		for j in range(cols - 1):
			for idx in [cb, base + j + 1, base + j]:
				st.add_index(idx)
	return st.commit()


func _ring_point(r: Dictionary, th: float) -> Vector3:
	var open: float = float(r.get("open", 0.0))
	return Vector3(float(r.get("cx", 0.0)) + float(r["rx"]) * cos(th), float(r["y"]),
		float(r.get("cz", 0.0)) + float(r["rz"]) * sin(th))


## Normale exacte d'un sommet d'anneau : tangente autour de l'anneau x direction entre
## anneaux voisins, orientée vers l'extérieur (loin de l'axe du tube).
func _ring_normal(prev_r: Dictionary, next_r: Dictionary, ring: Dictionary, th: float,
		x: float, z: float) -> Vector3:
	var t_around: Vector3 = Vector3(-float(ring["rx"]) * sin(th), 0.0, float(ring["rz"]) * cos(th))
	var t_down: Vector3 = _ring_point(next_r, th) - _ring_point(prev_r, th)
	if t_down.length() < 0.0001:
		t_down = Vector3(0.0, -1.0, 0.0)
	var n: Vector3 = t_around.cross(t_down).normalized()
	var out: Vector3 = Vector3(x - float(ring.get("cx", 0.0)), 0.0, z - float(ring.get("cz", 0.0)))
	if n.dot(out) < 0.0:
		n = -n
	return n


func _set_skin(st: SurfaceTool, ring: Dictionary, x: float, z: float) -> void:
	var weights: Dictionary = {}
	var w: float = float(ring["w"])
	var a: String = ring["a"]
	var b: String = ring["b"]
	weights[a] = 1.0 - w
	if b != "" and w > 0.0:
		weights[b] = float(weights.get(b, 0.0)) + w
	# manteau : les pans suivent un peu les cuisses et l'os "coat" (dos)
	var leg: float = float(ring.get("leg", 0.0))
	var coat: float = float(ring.get("coat", 0.0))
	var rx: float = float(ring["rx"])
	var rz: float = float(ring["rz"])
	var extra: Dictionary = {}
	if leg > 0.0:
		var side_w: float = leg * clampf(absf(x) / rx, 0.0, 1.0)
		extra["thigh_l" if x < 0.0 else "thigh_r"] = side_w
	if coat > 0.0:
		extra["coat"] = coat * clampf(z / rz, 0.0, 1.0)
	var total_extra: float = 0.0
	for k in extra:
		total_extra += float(extra[k])
	if total_extra > 0.95:
		for k in extra:
			extra[k] = float(extra[k]) * 0.95 / total_extra
		total_extra = 0.95
	for k in weights:
		weights[k] = float(weights[k]) * (1.0 - total_extra)
	for k in extra:
		weights[k] = float(weights.get(k, 0.0)) + float(extra[k])
	var bones: PackedInt32Array = PackedInt32Array()
	var ws: PackedFloat32Array = PackedFloat32Array()
	for k in weights:
		if bones.size() < 4:
			bones.append(int(bone_idx[k]))
			ws.append(float(weights[k]))
	while bones.size() < 4:
		bones.append(0)
		ws.append(0.0)
	st.set_bones(bones)
	st.set_weights(ws)


func _skinned(mesh: ArrayMesh, mat: String, node_name: String) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = _mat(mat)
	skeleton.add_child(mi)
	mi.skin = skeleton.create_skin_from_rest_transforms()


func _build_skinned_body() -> void:
	# ---- jambes (pantalon + bottes)
	for side in [-1.0, 1.0]:
		var s: String = "l" if side < 0.0 else "r"
		var x: float = 0.09 * float(side)
		var th: String = "thigh_" + s
		var sh: String = "shin_" + s
		var ft: String = "foot_" + s
		var o: Dictionary = {"cx": x}
		var legs: Array = [
			R(0.99, 0.100, 0.105, "hips", th, 0.2, PANTS, o),
			R(0.90, 0.096, 0.100, "hips", th, 0.8, PANTS, o),
			R(0.74, 0.082, 0.086, th, "", 0.0, PANTS, o),
			R(0.56, 0.068, 0.072, th, sh, 0.35, PANTS, o),
			R(0.48, 0.064, 0.068, th, sh, 0.85, PANTS, o),
			R(0.39, 0.061, 0.064, sh, "", 0.0, PANTS, o),
			R(0.39, 0.068, 0.072, sh, "", 0.0, BOOT, o),
			R(0.30, 0.064, 0.068, sh, "", 0.0, BOOT, o),
			R(0.20, 0.057, 0.062, sh, "", 0.0, BOOT, o),
			R(0.12, 0.055, 0.060, sh, ft, 0.5, BOOT, o),
			R(0.07, 0.056, 0.062, ft, "", 0.0, BOOT, o),
		]
		_skinned(_loft(legs, 14, false, true), "body", "Jambe_" + s)
	# ---- torse : chemise, ceinture, bassin
	var torso: Array = [
		R(1.535, 0.072, 0.068, "chest", "neck", 0.6, SHIRT),
		R(1.50, 0.150, 0.095, "chest", "", 0.0, SHIRT),
		R(1.44, 0.200, 0.112, "chest", "", 0.0, SHIRT),
		R(1.32, 0.190, 0.116, "chest", "", 0.0, SHIRT),
		R(1.20, 0.170, 0.110, "spine", "chest", 0.5, SHIRT),
		R(1.08, 0.155, 0.100, "spine", "", 0.0, SHIRT),
		R(1.045, 0.158, 0.102, "hips", "spine", 0.6, SHIRT),
		R(1.045, 0.163, 0.107, "hips", "spine", 0.6, BELT),
		R(0.99, 0.166, 0.109, "hips", "spine", 0.2, BELT),
		R(0.99, 0.166, 0.109, "hips", "", 0.0, PANTS),
		R(0.92, 0.170, 0.110, "hips", "", 0.0, PANTS),
		R(0.85, 0.150, 0.100, "hips", "", 0.0, PANTS),
	]
	_skinned(_loft(torso, 24, true, true), "body", "Torse")
	# ---- gilet ouvert en V, bordure dorée
	var vest: Array = [
		R(1.505, 0.152, 0.098, "chest", "neck", 0.2, VEST, {"open": 0.62}),
		R(1.47, 0.186, 0.108, "chest", "", 0.0, VEST, {"open": 0.52}),
		R(1.40, 0.206, 0.119, "chest", "", 0.0, VEST, {"open": 0.40}),
		R(1.30, 0.197, 0.123, "chest", "", 0.0, VEST, {"open": 0.20}),
		R(1.20, 0.178, 0.117, "spine", "chest", 0.5, VEST, {"open": 0.12}),
		R(1.10, 0.164, 0.108, "spine", "", 0.0, VEST, {"open": 0.12}),
		R(1.035, 0.168, 0.111, "hips", "spine", 0.6, VEST, {"open": 0.30}),
	]
	_skinned(_loft(vest, 26, false, false, 0.025), "coat", "Gilet")
	# ---- long manteau ouvert, bordures et ourlet dorés, pans qui suivent les jambes
	var coat: Array = [
		R(1.545, 0.100, 0.092, "chest", "neck", 0.3, COAT, {"open": 1.25}),
		R(1.495, 0.192, 0.118, "chest", "", 0.0, COAT, {"open": 0.88}),
		R(1.445, 0.228, 0.132, "chest", "", 0.0, COAT, {"open": 0.82}),
		R(1.32, 0.212, 0.132, "chest", "", 0.0, COAT, {"open": 0.80}),
		R(1.20, 0.192, 0.126, "spine", "chest", 0.5, COAT, {"open": 0.72}),
		R(1.08, 0.178, 0.118, "spine", "", 0.0, COAT, {"open": 0.66}),
		R(0.98, 0.186, 0.122, "hips", "spine", 0.2, COAT, {"open": 0.60}),
		R(0.85, 0.212, 0.150, "hips", "", 0.0, COAT, {"open": 0.55, "leg": 0.15, "coat": 0.10}),
		R(0.70, 0.245, 0.180, "hips", "", 0.0, COAT, {"open": 0.50, "leg": 0.30, "coat": 0.35}),
		R(0.55, 0.278, 0.210, "hips", "", 0.0, COAT, {"open": 0.46, "leg": 0.40, "coat": 0.60}),
		R(0.43, 0.298, 0.228, "hips", "", 0.0, COAT, {"open": 0.43, "leg": 0.45, "coat": 0.75}),
		R(0.43, 0.299, 0.229, "hips", "", 0.0, GOLD, {"open": 0.43, "leg": 0.45, "coat": 0.75}),
		R(0.37, 0.306, 0.234, "hips", "", 0.0, GOLD, {"open": 0.42, "leg": 0.47, "coat": 0.80}),
	]
	_skinned(_loft(coat, 30, false, false, 0.022), "coat", "Manteau")
	# ---- bras (chemise blanche)
	for side in [-1.0, 1.0]:
		var s: String = "l" if side < 0.0 else "r"
		var x: float = 0.23 * float(side)
		var ar: String = "arm_" + s
		var fo: String = "fore_" + s
		var o: Dictionary = {"cx": x}
		var arm: Array = [
			R(1.47, 0.060, 0.060, "chest", ar, 0.5, SHIRT, o),
			R(1.40, 0.062, 0.064, ar, "", 0.0, SHIRT, o),
			R(1.27, 0.056, 0.058, ar, "", 0.0, SHIRT, o),
			R(1.16, 0.050, 0.052, ar, fo, 0.5, SHIRT, o),
			R(1.10, 0.048, 0.050, fo, "", 0.0, SHIRT, o),
			R(0.98, 0.043, 0.045, fo, "", 0.0, SHIRT, o),
			R(0.89, 0.036, 0.038, fo, "hand_" + s, 0.3, SHIRT, o),
		]
		_skinned(_loft(arm, 12, true, true), "body", "Bras_" + s)
	# ---- cou
	var neck: Array = [
		R(1.63, 0.048, 0.050, "head", "", 0.0, SKIN),
		R(1.56, 0.054, 0.056, "neck", "head", 0.3, SKIN),
		R(1.50, 0.060, 0.060, "neck", "chest", 0.4, SKIN),
	]
	_skinned(_loft(neck, 12, false, false), "body", "Cou")


# ================================================================ pièces rigides

func _put(bone: String, mesh: Mesh, xf: Transform3D, mat: String) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.transform = xf
	mi.material_override = _mat(mat)
	_attach(bone).add_child(mi)
	return mi


## Position relative à l'os à partir d'une position "globale" de repos.
func _rel(bone: String, p: Vector3) -> Vector3:
	return p - (rest_global[bone] as Vector3)


func _sphere(r: float, seg: int = 10, rings: int = 6, hemi: bool = false) -> SphereMesh:
	var m: SphereMesh = SphereMesh.new()
	m.radius = r
	m.height = r if hemi else r * 2.0
	m.radial_segments = seg
	m.rings = rings
	m.is_hemisphere = hemi
	return m


func _cyl(rt: float, rb: float, h: float, seg: int = 10) -> CylinderMesh:
	var m: CylinderMesh = CylinderMesh.new()
	m.top_radius = rt
	m.bottom_radius = rb
	m.height = h
	m.radial_segments = seg
	m.rings = 1
	return m


func _boxm(size: Vector3) -> BoxMesh:
	var m: BoxMesh = BoxMesh.new()
	m.size = size
	return m


func _xf(basis: Basis, pos: Vector3) -> Transform3D:
	return Transform3D(basis, pos)


func _build_rigid_parts() -> void:
	var I: Basis = Basis.IDENTITY
	# col de chemise et nœud papillon
	_put("neck", _cyl(0.062, 0.068, 0.05, 12), _xf(I, _rel("neck", Vector3(0.0, 1.515, 0.0))), "#f2f2f4")
	var bow_y: float = 1.505
	var bow_z: float = -0.082
	_put("chest", _boxm(Vector3(0.026, 0.024, 0.02)), _xf(I, _rel("chest", Vector3(0.0, bow_y, bow_z))), "#0a0a0c")
	for side in [-1.0, 1.0]:
		var wing: Basis = Basis(Vector3(0.0, 0.0, 1.0), -PI * 0.5 * float(side))
		_put("chest", _cyl(0.0, 0.026, 0.055, 4), _xf(wing, _rel("chest", Vector3(0.033 * float(side), bow_y, bow_z))), "#0a0a0c")
	# boutons dorés du gilet
	for k in range(3):
		var y: float = 1.13 + 0.06 * float(k)
		var bone: String = "spine" if y < 1.2 else "chest"
		_put(bone, _sphere(0.009, 6, 4), _xf(I, _rel(bone, Vector3(0.0, y, -0.124 + 0.004 * float(k)))), "gold")
	# boucle de ceinture
	_put("hips", _boxm(Vector3(0.055, 0.042, 0.014)), _xf(I, _rel("hips", Vector3(0.0, 1.018, -0.112))), "gold")
	# épaulières dorées en plaques superposées (la gauche plus grande)
	for side in [-1.0, 1.0]:
		var s: String = "l" if side < 0.0 else "r"
		var k: float = 0.85 if side < 0.0 else 0.75
		var arm: String = "arm_" + s
		var sx: float = float(side)
		_put(arm, _sphere(1.0, 12, 5, true),
			_xf(Basis(Vector3(0.0, 0.0, 1.0), -0.25 * sx) * Basis.from_scale(Vector3(0.115, 0.08, 0.12) * k), Vector3(0.02 * sx, 0.03, 0.0)), "gold")
		_put(arm, _sphere(1.0, 12, 4, true),
			_xf(Basis(Vector3(0.0, 0.0, 1.0), -0.55 * sx) * Basis.from_scale(Vector3(0.10, 0.06, 0.11) * k), Vector3(0.05 * sx, -0.03, 0.0)), "gold")
		_put(arm, _sphere(1.0, 12, 4, true),
			_xf(Basis(Vector3(0.0, 0.0, 1.0), -0.8 * sx) * Basis.from_scale(Vector3(0.085, 0.05, 0.10) * k), Vector3(0.07 * sx, -0.085, 0.0)), "gold")
		if side < 0.0:
			for kk in range(2):
				var sp: Basis = Basis(Vector3(0.0, 0.0, 1.0), 0.6) * Basis(Vector3.RIGHT, -0.3 + 0.6 * float(kk))
				_put(arm, _cyl(0.0, 0.014, 0.07, 5), _xf(sp, Vector3(-0.06, 0.08, -0.03 + 0.06 * float(kk))), "gold")
		# brassards dorés et gants noirs
		var fo: String = "fore_" + s
		_put(fo, _cyl(0.058, 0.050, 0.17, 12), _xf(I, Vector3(0.0, -0.17, 0.0)), "gold")
		_put(fo, _cyl(0.0595, 0.0595, 0.02, 12), _xf(I, Vector3(0.0, -0.12, 0.0)), "#151515")
		var hd: String = "hand_" + s
		_put(hd, _sphere(1.0, 10, 6), _xf(I.scaled(Vector3(0.036, 0.055, 0.046)), Vector3(0.0, -0.045, -0.005)), "#0d0d0f")
		_put(hd, _cyl(0.014, 0.016, 0.05, 6), _xf(Basis(Vector3.RIGHT, -0.6), Vector3(-0.02 * sx, -0.03, -0.035)), "#0d0d0f")
		# bottes : pied et semelle, liseré doré au revers
		var ft: String = "foot_" + s
		_put(ft, _sphere(1.0, 10, 6), _xf(I.scaled(Vector3(0.062, 0.05, 0.13)), Vector3(0.0, -0.02, -0.05)), "#0c0b0c")
		_put(ft, _boxm(Vector3(0.12, 0.025, 0.27)), _xf(I, Vector3(0.0, -0.058, -0.045)), "#1a1410")
		var sh: String = "shin_" + s
		var trim: TorusMesh = TorusMesh.new()
		trim.inner_radius = 0.066
		trim.outer_radius = 0.076
		trim.rings = 16
		trim.ring_segments = 4
		_put(sh, trim, _xf(I.scaled(Vector3(1.0, 0.5, 1.0)), Vector3(0.0, -0.11, 0.0)), "gold")


# ================================================================ tête

func _build_head() -> void:
	head_slot = Node3D.new()
	head_slot.name = "TeteSlot"
	head_slot.position = Vector3(0.0, HEAD_CENTER_Y, 0.0)
	_attach("head").add_child(head_slot)
	_fill_default_head()


## Remplace la tête provisoire par un vrai modèle 3D (futur).
func replace_head(new_head: Node3D) -> void:
	for ch in head_slot.get_children():
		ch.queue_free()
	head_slot.add_child(new_head)


func _fill_default_head() -> void:
	# tête modélisée en 3D (sculptée d'après la photo, aucune photo collée)
	var head: Node3D = HeroHead.new()
	head.name = "TeteHeros"
	head_slot.add_child(head)


## Ellipsoïde. part : 0 = moitié avant (z < 0) avec UV de projection frontale,
## 1 = moitié arrière, 2 = entière.
func _ellipsoid(r: Vector3, part: int) -> ArrayMesh:
	var rings: int = 16
	var segs: int = 24
	var verts: PackedVector3Array = PackedVector3Array()
	var norms: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	for i in range(rings + 1):
		var th: float = PI * float(i) / float(rings)
		for j in range(segs + 1):
			var ph: float = TAU * float(j) / float(segs)
			var p: Vector3 = Vector3(r.x * sin(th) * cos(ph), r.y * cos(th), r.z * sin(th) * sin(ph))
			verts.append(p)
			norms.append(Vector3(p.x / (r.x * r.x), p.y / (r.y * r.y), p.z / (r.z * r.z)).normalized())
			uvs.append(Vector2(0.5 - p.x / (2.0 * r.x), 0.5 - p.y / (2.0 * r.y)))
	var idx: PackedInt32Array = PackedInt32Array()
	for i in range(rings):
		for j in range(segs):
			var a: int = i * (segs + 1) + j
			var b: int = a + 1
			var c: int = a + segs + 1
			var d: int = c + 1
			var zc: float = (verts[a].z + verts[b].z + verts[c].z + verts[d].z) * 0.25
			var front: bool = zc < 0.0
			if part == 0 and not front:
				continue
			if part == 1 and front:
				continue
			idx.append_array(PackedInt32Array([a, c, b, b, c, d]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


# ================================================================ animation

## state : idle, walk, run, jump, fall, dodge, land. speed : vitesse horizontale (m/s).
## Rotation positive autour de X = membre vers l'avant. Bras gauche vers l'extérieur = Z négatif.
func animate(delta: float, state: String, speed: float) -> void:
	t += delta
	var tg: Dictionary = {}
	for b in POSED:
		tg[b] = Vector3.ZERO
	var hy: float = 0.0
	match state:
		"attack":
			var poses: Array = ATTACK_POSES[clampi(attack_kind, 0, 3)]
			var a0: Dictionary = poses[0]
			var a1: Dictionary = poses[1]
			# préparation (pose de départ), coup rapide, puis maintien
			var e: float = smoothstep(0.18, 0.55, attack_t)
			for b in a0:
				tg[b] = (a0[b] as Vector3).lerp(a1[b] as Vector3, e)
			if attack_kind < 3:
				tg["arm_l"] = Vector3(0.5, 0.0, -0.4)
				tg["fore_l"] = Vector3(0.8, 0.0, 0.0)
			var right_lead: bool = attack_kind == 1
			tg["thigh_l"] = Vector3(-0.3 if right_lead else 0.45, 0.0, -0.06)
			tg["shin_l"] = Vector3(-0.2 if right_lead else -0.4, 0.0, 0.0)
			tg["thigh_r"] = Vector3(0.45 if right_lead else -0.3, 0.0, 0.08)
			tg["shin_r"] = Vector3(-0.4 if right_lead else -0.2, 0.0, 0.0)
			if attack_kind == 2:
				tg["thigh_l"] = Vector3(0.6, 0.0, -0.05)
				tg["shin_l"] = Vector3(-0.5, 0.0, 0.0)
				tg["thigh_r"] = Vector3(-0.4, 0.0, 0.08)
				hy = -0.08 * e
			elif attack_kind == 3:
				tg["thigh_l"] = Vector3(0.4, 0.0, -0.12)
				tg["thigh_r"] = Vector3(0.4, 0.0, 0.12)
				tg["shin_l"] = Vector3(-0.6, 0.0, 0.0)
				tg["shin_r"] = Vector3(-0.6, 0.0, 0.0)
				hy = -0.12
			tg["coat"] = Vector3(-0.35, 0.0, 0.0)
		"hurt":
			tg["spine"] = Vector3(0.25, 0.0, 0.0)
			tg["head"] = Vector3(-0.2, 0.0, 0.0)
			tg["arm_l"] = Vector3(0.3, 0.0, -0.5)
			tg["arm_r"] = Vector3(0.3, 0.0, 0.5)
			tg["coat"] = Vector3(0.2, 0.0, 0.0)
			hy = -0.05
		"dead":
			tg["thigh_l"] = Vector3(1.4, 0.0, -0.1)
			tg["thigh_r"] = Vector3(1.4, 0.0, 0.1)
			tg["shin_l"] = Vector3(-2.1, 0.0, 0.0)
			tg["shin_r"] = Vector3(-2.1, 0.0, 0.0)
			tg["spine"] = Vector3(0.5, 0.0, 0.0)
			tg["chest"] = Vector3(0.3, 0.0, 0.0)
			tg["head"] = Vector3(0.6, 0.0, 0.0)
			tg["arm_l"] = Vector3(-0.2, 0.0, -0.3)
			tg["arm_r"] = Vector3(-0.2, 0.0, 0.3)
			hy = -0.72
		"walk", "run":
			var rf: float = clampf((speed - 2.4) / 3.8, 0.0, 1.0)
			var amp: float = lerpf(0.5, 1.0, rf)
			phase += delta * speed * 2.2
			var s: float = sin(phase)
			var c: float = cos(phase)
			tg["thigh_l"] = Vector3(s * amp, 0.0, -0.03)
			tg["thigh_r"] = Vector3(-s * amp, 0.0, 0.03)
			tg["shin_l"] = Vector3(-(0.1 + maxf(c, 0.0) * amp * 1.1), 0.0, 0.0)
			tg["shin_r"] = Vector3(-(0.1 + maxf(-c, 0.0) * amp * 1.1), 0.0, 0.0)
			tg["arm_l"] = Vector3(-s * amp * 0.9, 0.0, -0.12)
			tg["fore_l"] = Vector3(0.3 + rf * 0.6, 0.0, 0.0)
			# bras droit : tient l'épée, balancement réduit, lame traînée en course
			tg["arm_r"] = Vector3(s * amp * 0.35 - rf * 0.25, 0.0, 0.18 + rf * 0.15)
			tg["fore_r"] = Vector3(0.35 + rf * 0.2, 0.0, 0.0)
			tg["hand_r"] = Vector3(-rf * 0.5, 0.0, 0.0)
			tg["spine"] = Vector3(-rf * 0.25, 0.0, 0.0)
			tg["chest"] = Vector3(0.0, s * 0.10 * amp, 0.0)
			tg["head"] = Vector3(rf * 0.20, -s * 0.05, 0.0)
			tg["coat"] = Vector3(-0.15 - rf * 0.5 + sin(phase * 2.0) * 0.07 * amp, 0.0, 0.0)
			hy = -absf(s) * 0.04 * amp
		"jump":
			tg["thigh_l"] = Vector3(0.7, 0.0, 0.0)
			tg["shin_l"] = Vector3(-1.1, 0.0, 0.0)
			tg["thigh_r"] = Vector3(-0.15, 0.0, 0.0)
			tg["shin_r"] = Vector3(-0.5, 0.0, 0.0)
			tg["arm_l"] = Vector3(0.9, 0.0, -0.4)
			tg["arm_r"] = Vector3(0.6, 0.0, 0.5)
			tg["spine"] = Vector3(-0.1, 0.0, 0.0)
			tg["coat"] = Vector3(-0.45, 0.0, 0.0)
		"fall":
			tg["thigh_l"] = Vector3(0.3, 0.0, 0.0)
			tg["thigh_r"] = Vector3(-0.2, 0.0, 0.0)
			tg["shin_l"] = Vector3(-0.4, 0.0, 0.0)
			tg["shin_r"] = Vector3(-0.4, 0.0, 0.0)
			tg["arm_l"] = Vector3(0.0, 0.0, -1.3)
			tg["arm_r"] = Vector3(0.0, 0.0, 1.1)
			tg["coat"] = Vector3(-0.8 + sin(t * 18.0) * 0.08, 0.0, 0.0)
		"dodge":
			tg["spine"] = Vector3(-0.6, 0.0, 0.0)
			tg["chest"] = Vector3(-0.2, 0.0, 0.0)
			tg["head"] = Vector3(0.5, 0.0, 0.0)
			tg["thigh_l"] = Vector3(1.1, 0.0, 0.0)
			tg["thigh_r"] = Vector3(1.1, 0.0, 0.0)
			tg["shin_l"] = Vector3(-1.8, 0.0, 0.0)
			tg["shin_r"] = Vector3(-1.8, 0.0, 0.0)
			tg["arm_l"] = Vector3(0.8, 0.0, 0.0)
			tg["arm_r"] = Vector3(0.8, 0.0, 0.0)
			tg["fore_l"] = Vector3(1.2, 0.0, 0.0)
			tg["fore_r"] = Vector3(1.2, 0.0, 0.0)
			tg["coat"] = Vector3(-0.6, 0.0, 0.0)
			hy = -0.30
		"land":
			tg["thigh_l"] = Vector3(0.9, 0.0, 0.0)
			tg["thigh_r"] = Vector3(0.9, 0.0, 0.0)
			tg["shin_l"] = Vector3(-1.5, 0.0, 0.0)
			tg["shin_r"] = Vector3(-1.5, 0.0, 0.0)
			tg["spine"] = Vector3(-0.3, 0.0, 0.0)
			tg["head"] = Vector3(0.3, 0.0, 0.0)
			tg["arm_l"] = Vector3(0.4, 0.0, -0.3)
			tg["arm_r"] = Vector3(0.4, 0.0, 0.3)
			tg["coat"] = Vector3(0.25, 0.0, 0.0)
			hy = -0.22
		_:
			# garde héroïque : jambes écartées, épée tenue basse vers l'avant
			var br: float = sin(t * 2.0)
			tg["chest"] = Vector3(br * 0.02, 0.0, 0.0)
			tg["thigh_l"] = Vector3(0.05, 0.0, -0.07)
			tg["thigh_r"] = Vector3(-0.05, 0.0, 0.07)
			tg["arm_l"] = Vector3(0.05, 0.0, -0.16)
			tg["fore_l"] = Vector3(0.25, 0.0, 0.0)
			tg["arm_r"] = Vector3(0.22, 0.0, 0.20)
			tg["fore_r"] = Vector3(0.30, 0.0, 0.0)
			tg["coat"] = Vector3(-0.04 + br * 0.02, 0.0, 0.0)
	var rate: float = 34.0 if state == "attack" else 16.0
	var k: float = 1.0 - exp(-rate * delta)
	for b in POSED:
		var cur: Vector3 = current[b]
		var goal: Vector3 = tg[b]
		cur = cur.lerp(goal, k)
		current[b] = cur
		skeleton.set_bone_pose_rotation(int(bone_idx[b]), Quaternion.from_euler(cur))
	hips_y = lerpf(hips_y, hy, k)
	skeleton.set_bone_pose_position(int(bone_idx["hips"]), HIPS_REST + Vector3(0.0, hips_y, 0.0))
