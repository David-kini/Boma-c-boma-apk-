extends RefCounted
## Bibliothèque de modèles 3D (Assets/...) : chaque fichier .gltf/.glb est chargé une
## seule fois ; ses maillages (avec leurs matériaux et transformations) sont mis en cache.
## - parts(path)  : liste [Mesh, Transform3D] pour les MultiMesh du décor.
## - place(...)   : pose un modèle dans le monde avec une collision simple (boîte ou
##                  cylindre) et une distance d'affichage maximale (économise le GPU).

static var _cache: Dictionary = {}
static var _aabbs: Dictionary = {}


static func parts(path: String) -> Array:
	if _cache.has(path):
		return _cache[path]
	var out: Array = []
	var box: Array = [null]
	if ResourceLoader.exists(path):
		var ps: PackedScene = load(path) as PackedScene
		if ps != null:
			var root: Node = ps.instantiate()
			_collect(root, Transform3D.IDENTITY, out, box)
			root.free()
	else:
		push_warning("Modèle introuvable : " + path)
	_cache[path] = out
	_aabbs[path] = box[0] if box[0] != null else AABB(Vector3(-0.5, 0.0, -0.5), Vector3.ONE)
	return out


static func _collect(n: Node, xf: Transform3D, out: Array, box: Array) -> void:
	var t: Transform3D = xf
	if n is Node3D:
		t = xf * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var m: Mesh = (n as MeshInstance3D).mesh
		out.append([m, t])
		var b: AABB = t * m.get_aabb()
		box[0] = b if box[0] == null else (box[0] as AABB).merge(b)
	for c in n.get_children():
		_collect(c, t, out, box)


static func aabb(path: String) -> AABB:
	parts(path)
	return _aabbs[path]


## Pose un modèle. collide : "box", "cyl" (tronc), "" (aucune).
static func place(parent: Node3D, path: String, pos: Vector3, yaw: float, scale: float,
		collide: String = "box", vis: float = 350.0) -> Node3D:
	var holder: Node3D = Node3D.new()
	holder.name = path.get_file().get_basename()
	holder.position = pos
	holder.rotation.y = yaw
	holder.scale = Vector3(scale, scale, scale)
	for p in parts(path):
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = p[0] as Mesh
		mi.transform = p[1] as Transform3D
		mi.visibility_range_end = vis
		holder.add_child(mi)
	parent.add_child(holder)
	if collide != "":
		var b: AABB = aabb(path)
		var body: StaticBody3D = StaticBody3D.new()
		body.position = pos
		body.rotation.y = yaw
		var cs: CollisionShape3D = CollisionShape3D.new()
		var center: Vector3 = (b.position + b.size * 0.5) * scale
		if collide == "cyl":
			var cy: CylinderShape3D = CylinderShape3D.new()
			cy.radius = maxf(minf(b.size.x, b.size.z) * 0.18 * scale, 0.25)
			cy.height = b.size.y * scale
			cs.shape = cy
			cs.position = Vector3(0.0, cy.height * 0.5, 0.0)
		else:
			var bx: BoxShape3D = BoxShape3D.new()
			bx.size = b.size * scale * 0.9
			cs.shape = bx
			cs.position = center
		body.add_child(cs)
		parent.add_child(body)
	return holder
