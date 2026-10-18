extends Node3D
## Monde 3D : relief en tuiles (avec décor), ciel, soleil, lieux construits
## (landmarks.gd), murs invisibles aux limites (derrière les montagnes).

const WorldData = preload("res://scripts/world_data.gd")
const Terrain = preload("res://scripts/terrain.gd")
const Landmarks = preload("res://scripts/landmarks.gd")

var data: RefCounted
var terrain: Node3D
var sun: DirectionalLight3D
var env: Environment
var follow: Node3D = null


func _ready() -> void:
	data = WorldData.new()
	terrain = Terrain.new()
	terrain.name = "Terrain"
	add_child(terrain)
	terrain.call("setup", data)
	_build_environment()
	_build_boundary_walls()
	var lm: RefCounted = Landmarks.new()
	lm.call("build", self, data)
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
	env.fog_density = GameSettings.fog_density()
	if GameSettings.use_sky():
		env.background_mode = Environment.BG_SKY
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	else:
		# ciel remplacé par une couleur unie : moins coûteux
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.66, 0.78, 0.92)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.62, 0.68, 0.76)


func _build_environment() -> void:
	env = Environment.new()
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
