extends Node3D
## Personnage 3D procédural : Skeleton3D (16 os) + pièces de corps attachées aux os
## (BoneAttachment3D). Le visage (photo) est projeté sur une tête ellipsoïdale 3D.
## La tête est dans un conteneur "head_slot" : on pourra la remplacer par un vrai
## modèle 3D (replace_head) sans toucher au reste.
## Le personnage regarde vers -Z (avant de Godot), ses pieds sont à y = 0.

const FACE_PATH: String = "res://assets/textures/face.png"
const SKIN: Color = Color(0.95, 0.88, 0.84)
const HAIR: Color = Color(0.93, 0.93, 0.91)
const SHIRT: Color = Color(0.96, 0.96, 0.97)
const VEST: Color = Color(0.22, 0.22, 0.24)
const BLACK: Color = Color(0.06, 0.06, 0.07)
const HIPS_REST: Vector3 = Vector3(0.0, 0.95, 0.0)
const HEAD_RADII: Vector3 = Vector3(0.10, 0.115, 0.11)

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
]

## Os animés par rotation (les autres restent en pose de repos).
const POSED: Array = [
	"spine", "chest", "neck", "head", "arm_l", "fore_l", "arm_r", "fore_r",
	"thigh_l", "shin_l", "thigh_r", "shin_r",
]

var skeleton: Skeleton3D
var head_slot: Node3D
var bone_idx: Dictionary = {}
var attachments: Dictionary = {}
var materials: Dictionary = {}
var current: Dictionary = {}
var hips_y: float = 0.0
var phase: float = 0.0
var t: float = 0.0


func _ready() -> void:
	for b in POSED:
		current[b] = Vector3.ZERO
	_build_skeleton()
	_build_body()
	_build_head()


# ---------------------------------------------------------------- squelette

func _build_skeleton() -> void:
	skeleton = Skeleton3D.new()
	skeleton.name = "Skeleton"
	add_child(skeleton)
	for def in BONE_DEF:
		var bname: String = def[0]
		var parent_name: String = def[1]
		var idx: int = skeleton.add_bone(bname)
		bone_idx[bname] = idx
		if parent_name != "":
			skeleton.set_bone_parent(idx, int(bone_idx[parent_name]))
		var rest_pos: Vector3 = def[2]
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


## Point d'accroche pour les armes (phase 3) : "hand_r" ou "hand_l".
func get_hand_mount(bone: String) -> Node3D:
	return _attach(bone)


func _mat(c: Color) -> StandardMaterial3D:
	var key: String = c.to_html()
	if materials.has(key):
		return materials[key] as StandardMaterial3D
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.85
	materials[key] = m
	return m


func _put(bone: String, mesh: Mesh, offset: Vector3, c: Color) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = offset
	mi.material_override = _mat(c)
	_attach(bone).add_child(mi)


func _box(bone: String, size: Vector3, offset: Vector3, c: Color) -> void:
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size
	_put(bone, bm, offset, c)


func _capsule(bone: String, radius: float, height: float, offset: Vector3, c: Color) -> void:
	var cm: CapsuleMesh = CapsuleMesh.new()
	cm.radius = radius
	cm.height = height
	cm.radial_segments = 10
	cm.rings = 4
	_put(bone, cm, offset, c)


# ------------------------------------------------------------------- corps

func _build_body() -> void:
	_box("hips", Vector3(0.34, 0.20, 0.20), Vector3(0.0, -0.02, 0.0), BLACK)
	_box("spine", Vector3(0.32, 0.22, 0.19), Vector3(0.0, 0.10, 0.0), SHIRT)
	_box("chest", Vector3(0.38, 0.30, 0.21), Vector3(0.0, 0.12, 0.0), SHIRT)
	for k in range(2):
		var sx: float = -1.0 + 2.0 * float(k)
		# gilet gris foncé : deux panneaux, la chemise reste visible au centre
		_box("spine", Vector3(0.12, 0.21, 0.195), Vector3(sx * 0.10, 0.10, 0.0), VEST)
		_box("chest", Vector3(0.14, 0.29, 0.215), Vector3(sx * 0.12, 0.12, 0.0), VEST)
		# ailes du nœud papillon
		_box("chest", Vector3(0.05, 0.04, 0.02), Vector3(sx * 0.04, 0.26, -0.11), BLACK)
	_box("chest", Vector3(0.03, 0.035, 0.025), Vector3(0.0, 0.26, -0.11), BLACK)
	_capsule("neck", 0.045, 0.12, Vector3(0.0, 0.03, 0.0), SKIN)
	for side in ["l", "r"]:
		_capsule("thigh_" + side, 0.075, 0.46, Vector3(0.0, -0.215, 0.0), BLACK)
		_capsule("shin_" + side, 0.06, 0.46, Vector3(0.0, -0.215, 0.0), BLACK)
		_box("foot_" + side, Vector3(0.12, 0.07, 0.27), Vector3(0.0, -0.035, -0.05), BLACK)
		_capsule("arm_" + side, 0.05, 0.32, Vector3(0.0, -0.15, 0.0), SHIRT)
		_capsule("fore_" + side, 0.045, 0.30, Vector3(0.0, -0.14, 0.0), SHIRT)
		_box("hand_" + side, Vector3(0.08, 0.10, 0.05), Vector3(0.0, -0.05, 0.0), SKIN)


# ------------------------------------------------------------------- tête

func _build_head() -> void:
	head_slot = Node3D.new()
	head_slot.name = "TeteSlot"
	head_slot.position = Vector3(0.0, HEAD_RADII.y, 0.0)
	_attach("head").add_child(head_slot)
	_fill_default_head()


## Remplace la tête provisoire par un vrai modèle 3D (futur).
func replace_head(new_head: Node3D) -> void:
	for ch in head_slot.get_children():
		ch.queue_free()
	head_slot.add_child(new_head)


func _fill_default_head() -> void:
	var skull: MeshInstance3D = MeshInstance3D.new()
	skull.mesh = _ellipsoid(HEAD_RADII * 0.97, 2)
	skull.material_override = _mat(SKIN)
	head_slot.add_child(skull)
	var hair: MeshInstance3D = MeshInstance3D.new()
	hair.mesh = _ellipsoid(HEAD_RADII * 1.03, 1)
	hair.material_override = _mat(HAIR)
	head_slot.add_child(hair)
	var face: MeshInstance3D = MeshInstance3D.new()
	face.mesh = _ellipsoid(HEAD_RADII, 0)
	var fm: StandardMaterial3D = StandardMaterial3D.new()
	fm.roughness = 1.0
	if ResourceLoader.exists(FACE_PATH):
		fm.albedo_texture = load(FACE_PATH) as Texture2D
		fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		fm.alpha_scissor_threshold = 0.5
	else:
		fm.albedo_color = SKIN
	face.material_override = fm
	head_slot.add_child(face)


## Ellipsoïde. part : 0 = moitié avant (z < 0) avec UV de projection frontale,
## 1 = moitié arrière, 2 = entière.
func _ellipsoid(r: Vector3, part: int) -> ArrayMesh:
	var rings: int = 14
	var segs: int = 20
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


# --------------------------------------------------------------- animation

## state : idle, walk, run, jump, fall, dodge, land. speed : vitesse horizontale (m/s).
## Une rotation positive autour de X balance un membre vers l'avant.
func animate(delta: float, state: String, speed: float) -> void:
	t += delta
	var tg: Dictionary = {}
	for b in POSED:
		tg[b] = Vector3.ZERO
	var hy: float = 0.0
	match state:
		"walk", "run":
			var rf: float = clampf((speed - 2.4) / 3.8, 0.0, 1.0)
			var amp: float = lerpf(0.5, 1.0, rf)
			phase += delta * speed * 2.2
			var s: float = sin(phase)
			var c: float = cos(phase)
			tg["thigh_l"] = Vector3(s * amp, 0.0, 0.0)
			tg["thigh_r"] = Vector3(-s * amp, 0.0, 0.0)
			tg["shin_l"] = Vector3(-(0.1 + maxf(c, 0.0) * amp * 1.1), 0.0, 0.0)
			tg["shin_r"] = Vector3(-(0.1 + maxf(-c, 0.0) * amp * 1.1), 0.0, 0.0)
			tg["arm_l"] = Vector3(-s * amp * 0.9, 0.0, -0.08)
			tg["arm_r"] = Vector3(s * amp * 0.9, 0.0, 0.08)
			tg["fore_l"] = Vector3(0.3 + rf * 0.6, 0.0, 0.0)
			tg["fore_r"] = Vector3(0.3 + rf * 0.6, 0.0, 0.0)
			tg["spine"] = Vector3(-rf * 0.25, 0.0, 0.0)
			tg["chest"] = Vector3(0.0, s * 0.10 * amp, 0.0)
			tg["head"] = Vector3(rf * 0.20, -s * 0.05, 0.0)
			hy = -absf(s) * 0.04 * amp
		"jump":
			tg["thigh_l"] = Vector3(0.7, 0.0, 0.0)
			tg["shin_l"] = Vector3(-1.1, 0.0, 0.0)
			tg["thigh_r"] = Vector3(-0.15, 0.0, 0.0)
			tg["shin_r"] = Vector3(-0.5, 0.0, 0.0)
			tg["arm_l"] = Vector3(0.9, 0.0, -0.4)
			tg["arm_r"] = Vector3(0.9, 0.0, 0.4)
			tg["spine"] = Vector3(-0.1, 0.0, 0.0)
		"fall":
			tg["thigh_l"] = Vector3(0.3, 0.0, 0.0)
			tg["thigh_r"] = Vector3(-0.2, 0.0, 0.0)
			tg["shin_l"] = Vector3(-0.4, 0.0, 0.0)
			tg["shin_r"] = Vector3(-0.4, 0.0, 0.0)
			tg["arm_l"] = Vector3(0.0, 0.0, -1.3)
			tg["arm_r"] = Vector3(0.0, 0.0, 1.3)
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
			hy = -0.22
		_:
			tg["chest"] = Vector3(sin(t * 2.0) * 0.02, 0.0, 0.0)
			tg["arm_l"] = Vector3(0.0, 0.0, -0.10)
			tg["arm_r"] = Vector3(0.0, 0.0, 0.10)
			tg["fore_l"] = Vector3(0.15, 0.0, 0.0)
			tg["fore_r"] = Vector3(0.15, 0.0, 0.0)
	var k: float = 1.0 - exp(-16.0 * delta)
	for b in POSED:
		var cur: Vector3 = current[b]
		var goal: Vector3 = tg[b]
		cur = cur.lerp(goal, k)
		current[b] = cur
		skeleton.set_bone_pose_rotation(int(bone_idx[b]), Quaternion.from_euler(cur))
	hips_y = lerpf(hips_y, hy, k)
	skeleton.set_bone_pose_position(int(bone_idx["hips"]), HIPS_REST + Vector3(0.0, hips_y, 0.0))
