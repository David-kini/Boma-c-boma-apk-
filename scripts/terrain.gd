extends Node3D
## Terrain en tuiles de 64 m chargées autour du joueur, avec 3 niveaux de détail.
## Collision (trimesh) uniquement sur les tuiles proches. Les tuiles lointaines sont
## déchargées : le monde de 2 km² n'est jamais entièrement en mémoire.

const WorldData = preload("res://scripts/world_data.gd")
const ChunkDecor = preload("res://scripts/chunk_decor.gd")

const CHUNK: float = 64.0
const SKIRT_DEPTH: float = 6.0            # jupe sous les bords : cache les fissures entre niveaux
const BUILD_INTERVAL: float = 0.10        # une tuile construite toutes les 0,1 s au maximum

var data: RefCounted
var decor: RefCounted
var material: StandardMaterial3D
var chunks: Dictionary = {}               # Vector2i -> {node, lod}
var view_chunks: int = 5
var max_index: int = 12
var _timer: float = 0.0
var _gen: int = 0                         # incrémenté à chaque changement de qualité


func setup(world_data: RefCounted) -> void:
	data = world_data
	decor = ChunkDecor.new(world_data)
	material = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	# texture de détail (herbe/terre, générée et libre de droits) projetée en coordonnées
	# monde, multipliée par les couleurs de zone du terrain
	material.albedo_texture = load("res://Assets/Textures/sol_detail.png") as Texture2D
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = Vector3(0.18, 0.18, 0.18)
	max_index = int(ceil(WorldData.HALF / CHUNK))
	view_chunks = GameSettings.view_chunks()
	GameSettings.quality_changed.connect(_on_quality_changed)


func _on_quality_changed(_level: int) -> void:
	view_chunks = GameSettings.view_chunks()
	_gen += 1


func _valid(k: Vector2i) -> bool:
	return k.x >= -max_index and k.x < max_index and k.y >= -max_index and k.y < max_index


func _lod_for(d: float, cur: int) -> int:
	var lod: int = 0
	if d > 3.6:
		lod = 2
	elif d > 1.6:
		lod = 1
	if cur == 0 and d <= 2.0:
		lod = 0
	elif cur == 1 and d > 1.2 and d <= 4.0:
		lod = 1
	elif cur == 2 and d > 3.2:
		lod = 2
	return lod


## Construit tout de suite les tuiles proches (au démarrage, avant de poser le joueur).
func build_around_now(p: Vector3, ring: int) -> void:
	var pc: Vector2i = Vector2i(floori(p.x / CHUNK), floori(p.z / CHUNK))
	for dz in range(-ring, ring + 1):
		for dx in range(-ring, ring + 1):
			var k: Vector2i = Vector2i(pc.x + dx, pc.y + dz)
			if _valid(k):
				_build(k, 0)


func update(p: Vector3, delta: float) -> void:
	_timer += delta
	var pf: Vector2 = Vector2(p.x, p.z) / CHUNK
	var pc: Vector2i = Vector2i(floori(pf.x), floori(pf.y))
	for key in chunks.keys():
		var kk: Vector2i = key
		if (Vector2(kk.x + 0.5, kk.y + 0.5) - pf).length() > float(view_chunks) + 1.5:
			_remove(kk)
	if _timer < BUILD_INTERVAL:
		return
	var best_d: float = 99999.0
	var best_k: Vector2i = Vector2i.ZERO
	var best_lod: int = 0
	var found: bool = false
	for dz in range(-view_chunks, view_chunks + 1):
		for dx in range(-view_chunks, view_chunks + 1):
			var k: Vector2i = Vector2i(pc.x + dx, pc.y + dz)
			if not _valid(k):
				continue
			var d: float = (Vector2(k.x + 0.5, k.y + 0.5) - pf).length()
			if d > float(view_chunks):
				continue
			var cur: int = -1
			var stale: bool = false
			if chunks.has(k):
				var entry: Dictionary = chunks[k]
				cur = int(entry["lod"])
				stale = int(entry["gen"]) != _gen
			var lod: int = _lod_for(d, cur)
			if cur == lod and not stale:
				continue
			if d < best_d:
				best_d = d
				best_k = k
				best_lod = lod
				found = true
	if found:
		_timer = 0.0
		_build(best_k, best_lod)


func _remove(k: Vector2i) -> void:
	if chunks.has(k):
		var entry: Dictionary = chunks[k]
		(entry["node"] as Node).queue_free()
		chunks.erase(k)


func _build(k: Vector2i, lod: int) -> void:
	_remove(k)
	var mesh: ArrayMesh = _make_mesh(k, GameSettings.lod_quads(lod))
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = Vector3(k.x * CHUNK, 0.0, k.y * CHUNK)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	if lod == 0:
		var body: StaticBody3D = StaticBody3D.new()
		var cs: CollisionShape3D = CollisionShape3D.new()
		cs.shape = mesh.create_trimesh_shape()
		body.add_child(cs)
		mi.add_child(body)
	# arbres, rochers... seulement sur les tuiles proches (pas sur les lointaines)
	if lod <= 1:
		decor.call("decorate", mi, k, lod == 0)
	chunks[k] = {"node": mi, "lod": lod, "gen": _gen}


func _make_mesh(k: Vector2i, quads: int) -> ArrayMesh:
	var step: float = CHUNK / float(quads)
	var ox: float = k.x * CHUNK
	var oz: float = k.y * CHUNK
	var n: int = quads + 1
	var w: int = n + 2
	# hauteurs avec une bordure d'un sommet, pour calculer les normales
	var hs: PackedFloat32Array = PackedFloat32Array()
	hs.resize(w * w)
	for iz in range(w):
		for ix in range(w):
			hs[iz * w + ix] = data.height_at(ox + (ix - 1) * step, oz + (iz - 1) * step)
	var verts: PackedVector3Array = PackedVector3Array()
	var norms: PackedVector3Array = PackedVector3Array()
	var cols: PackedColorArray = PackedColorArray()
	for iz in range(n):
		for ix in range(n):
			var gi: int = (iz + 1) * w + (ix + 1)
			var h: float = hs[gi]
			var nrm: Vector3 = Vector3(hs[gi - 1] - hs[gi + 1], 2.0 * step, hs[gi - w] - hs[gi + w]).normalized()
			verts.append(Vector3(ix * step, h, iz * step))
			norms.append(nrm)
			cols.append(data.color_at(ox + ix * step, oz + iz * step, h, nrm.y))
	var idx: PackedInt32Array = PackedInt32Array()
	for iz in range(quads):
		for ix in range(quads):
			var a: int = iz * n + ix
			var b: int = a + 1
			var c: int = a + n
			var d: int = c + 1
			idx.append_array(PackedInt32Array([a, b, c, b, d, c]))
	# jupes sur les 4 bords
	var e0: Array = []
	var e1: Array = []
	var e2: Array = []
	var e3: Array = []
	for i in range(n):
		e0.append(i)
		e1.append((n - 1) * n + i)
		e2.append(i * n)
		e3.append(i * n + (n - 1))
	for edge in [e0, e1, e2, e3]:
		var base: int = verts.size()
		for vi in edge:
			verts.append((verts[vi] as Vector3) - Vector3(0.0, SKIRT_DEPTH, 0.0))
			norms.append(norms[vi])
			cols.append(cols[vi])
		for i in range(n - 1):
			var t0: int = edge[i]
			var t1: int = edge[i + 1]
			idx.append_array(PackedInt32Array([t0, t1, base + i, t1, base + i + 1, base + i]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
