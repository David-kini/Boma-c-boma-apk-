extends SceneTree
## Outil : affiche la taille (boîte englobante) de chaque modèle de Assets/Environment.

func _aabb(n: Node, xf: Transform3D, acc: Array) -> void:
	var t: Transform3D = xf
	if n is Node3D:
		t = xf * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var b: AABB = t * (n as MeshInstance3D).mesh.get_aabb()
		acc[0] = b if acc[0] == null else (acc[0] as AABB).merge(b)
		acc[1] = int(acc[1]) + 1
	for c in n.get_children():
		_aabb(c, t, acc)

func _walk(dir: String) -> void:
	var d: DirAccess = DirAccess.open(dir)
	for f in d.get_files():
		if f.ends_with(".gltf") or f.ends_with(".glb"):
			var s: PackedScene = load(dir + "/" + f)
			var r: Node = s.instantiate()
			var acc: Array = [null, 0]
			_aabb(r, Transform3D.IDENTITY, acc)
			var b: AABB = acc[0]
			print("%s/%s taille=(%.2f, %.2f, %.2f) bas=%.2f maillages=%d" % [dir.get_file(), f, b.size.x, b.size.y, b.size.z, b.position.y, acc[1]])
			r.free()
	for sub in d.get_directories():
		_walk(dir + "/" + sub)

func _init() -> void:
	_walk("res://Assets/Environment")
	quit()
