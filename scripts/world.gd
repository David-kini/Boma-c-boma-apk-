extends Node3D
## Monde 3D : relief en tuiles, ciel, soleil, arène circulaire, ruines, rochers,
## murs invisibles aux limites (derrière les montagnes).

const WorldData = preload("res://scripts/world_data.gd")
const Terrain = preload("res://scripts/terrain.gd")

var data: RefCounted
var terrain: Node3D
var sun: DirectionalLight3D
var follow: Node3D = null


func _ready() -> void:
	data = WorldData.new()
	terrain = Terrain.new()
	terrain.name = "Terrain"
	add_child(terrain)
	terrain.call("setup", data)
	_build_environment()
	_build_boundary_walls()
	_build_arena()
	_build_ruins()
	_build_rocks()
	terrain.call("build_around_now", spawn_point(), 1)
	GameSettings.quality_changed.connect(_apply_quality)
	_apply_quality(GameSettings.quality)


func _process(delta: float) -> void:
	if follow != null:
		terrain.call("update", follow.global_position, delta)


func spawn_point() -> Vector3:
	return Vector3(0.0, ground_height(0.0, 70.0) + 1.5, 70.0)


func ground_height(x: float, z: float) -> float:
	return data.height_at(x, z)


func zone_name(x: float, z: float) -> String:
	return data.zone_name_at(x, z)


func _apply_quality(_level: int) -> void:
	var dist: float = GameSettings.shadow_distance()
	sun.shadow_enabled = dist > 0.0
	sun.directional_shadow_max_distance = maxf(dist, 1.0)


func _build_environment() -> void:
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky: Sky = Sky.new()
	var psm: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	psm.sky_top_color = Color(0.20, 0.38, 0.80)
	psm.sky_horizon_color = Color(0.66, 0.78, 0.92)
	psm.ground_horizon_color = Color(0.66, 0.78, 0.92)
	psm.ground_bottom_color = Color(0.25, 0.30, 0.38)
	sky.sky_material = psm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.66, 0.78, 0.92)
	env.fog_density = 0.0016
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -35.0, 0.0)
	sun.light_energy = 1.25
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.light_color = Color(1.0, 0.96, 0.88)
	add_child(sun)


func _build_boundary_walls() -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "LimitesDuMonde"
	var half: float = WorldData.HALF
	var specs: Array = [
		[Vector3(0.0, 150.0, half + 2.0), Vector3(half * 2.0 + 20.0, 400.0, 4.0)],
		[Vector3(0.0, 150.0, -half - 2.0), Vector3(half * 2.0 + 20.0, 400.0, 4.0)],
		[Vector3(half + 2.0, 150.0, 0.0), Vector3(4.0, 400.0, half * 2.0 + 20.0)],
		[Vector3(-half - 2.0, 150.0, 0.0), Vector3(4.0, 400.0, half * 2.0 + 20.0)],
	]
	for s in specs:
		var cs: CollisionShape3D = CollisionShape3D.new()
		var box: BoxShape3D = BoxShape3D.new()
		box.size = s[1]
		cs.shape = box
		cs.position = s[0]
		body.add_child(cs)
	add_child(body)


func _stone_material(c: Color) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	return m


func _add_pillar(parent: Node3D, pos: Vector2, h: float, r: float, mat: Material) -> void:
	var gy: float = data.height_at(pos.x, pos.y)
	var body: StaticBody3D = StaticBody3D.new()
	body.position = Vector3(pos.x, gy + h * 0.5 - 0.3, pos.y)
	var mi: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = r * 0.9
	cm.bottom_radius = r
	cm.height = h
	mi.mesh = cm
	mi.material_override = mat
	body.add_child(mi)
	var cs: CollisionShape3D = CollisionShape3D.new()
	var sh: CylinderShape3D = CylinderShape3D.new()
	sh.radius = r
	sh.height = h
	cs.shape = sh
	body.add_child(cs)
	parent.add_child(body)


func _build_arena() -> void:
	var arena: Node3D = Node3D.new()
	arena.name = "Arene"
	add_child(arena)
	var mat: StandardMaterial3D = _stone_material(Color(0.62, 0.60, 0.58))
	var count: int = 16
	for i in range(count):
		var a: float = TAU * float(i) / float(count)
		var h: float = 9.0 if i % 2 == 0 else 6.5
		_add_pillar(arena, Vector2(cos(a), sin(a)) * (WorldData.ARENA_RADIUS + 2.0), h, 1.3, mat)


func _build_ruins() -> void:
	var ruins: Node3D = Node3D.new()
	ruins.name = "Ruines"
	add_child(ruins)
	var mat: StandardMaterial3D = _stone_material(Color(0.50, 0.48, 0.46))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 5
	var zone: Dictionary = WorldData.ZONES["ruines"]
	var c: Vector2 = zone["center"]
	for i in range(16):
		var a: float = rng.randf() * TAU
		var d: float = rng.randf() * 90.0
		_add_pillar(ruins, c + Vector2(cos(a), sin(a)) * d, rng.randf_range(3.0, 8.0), rng.randf_range(0.8, 1.4), mat)


func _build_rocks() -> void:
	var rocks: Node3D = Node3D.new()
	rocks.name = "Rochers"
	add_child(rocks)
	var mat: StandardMaterial3D = _stone_material(Color(0.40, 0.38, 0.38))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 11
	var zone: Dictionary = WorldData.ZONES["rochers"]
	var c: Vector2 = zone["center"]
	for i in range(24):
		var a: float = rng.randf() * TAU
		var d: float = rng.randf() * 120.0
		var p: Vector2 = c + Vector2(cos(a), sin(a)) * d
		var s: float = rng.randf_range(1.5, 4.0)
		var body: StaticBody3D = StaticBody3D.new()
		body.position = Vector3(p.x, data.height_at(p.x, p.y) + s * 0.4, p.y)
		var mi: MeshInstance3D = MeshInstance3D.new()
		var sm: SphereMesh = SphereMesh.new()
		sm.radius = s
		sm.height = s * 2.0
		mi.mesh = sm
		mi.material_override = mat
		body.add_child(mi)
		var cs: CollisionShape3D = CollisionShape3D.new()
		var ss: SphereShape3D = SphereShape3D.new()
		ss.radius = s
		cs.shape = ss
		body.add_child(cs)
		rocks.add_child(body)
