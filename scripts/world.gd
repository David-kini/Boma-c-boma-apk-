extends Node3D
## Monde 3D : relief en tuiles (avec décor), ciel, soleil, lieux construits
## (landmarks.gd), murs invisibles aux limites (derrière les montagnes).

const WorldData = preload("res://scripts/world_data.gd")
const Terrain = preload("res://scripts/terrain.gd")
const Landmarks = preload("res://scripts/landmarks.gd")
const EnemySpawner = preload("res://scripts/enemy_spawner.gd")
const Weather = preload("res://scripts/weather.gd")

var data: RefCounted
var terrain: Node3D
var sun: DirectionalLight3D
var env: Environment
var follow: Node3D = null
var sky_mat: ShaderMaterial
var weather: Node3D


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
	var spawner: Node3D = EnemySpawner.new()
	spawner.name = "Ennemis"
	add_child(spawner)
	spawner.call("setup", self)
	terrain.call("build_around_now", spawn_point(), 1)
	GameSettings.quality_changed.connect(_apply_quality)
	_apply_quality(GameSettings.quality)
	weather = Weather.new()
	weather.name = "Meteo"
	add_child(weather)
	weather.call("setup", env, sun, sky_mat)


## Baisse de la lumière (0 = normale) : Éclipse du dragon.
func dim(v: float) -> void:
	if weather != null:
		weather.call("dim", v)


## Flash d'éclair (attaque finale, orage).
func flash(strength: float) -> void:
	if weather != null:
		weather.call("flash", strength)


func _process(delta: float) -> void:
	if follow != null:
		terrain.call("update", follow.global_position, delta)


func spawn_point() -> Vector3:
	return Vector3(0.0, ground_height(0.0, 30.0) + 1.5, 30.0)


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
	else:
		# ciel remplacé par une couleur unie : moins coûteux
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.66, 0.78, 0.92)


func _build_environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky: Sky = Sky.new()
	# ciel avec nuages (shader) ; image panoramique réelle si elle est présente
	var psm: ShaderMaterial = ShaderMaterial.new()
	psm.shader = load("res://shaders/sky_clouds.gdshader") as Shader
	var nt: NoiseTexture2D = NoiseTexture2D.new()
	nt.width = 512
	nt.height = 512
	nt.seamless = true
	nt.generate_mipmaps = true
	var fn: FastNoiseLite = FastNoiseLite.new()
	fn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	fn.frequency = 0.008
	fn.fractal_octaves = 5
	fn.fractal_gain = 0.55
	nt.noise = fn
	psm.set_shader_parameter("noise_tex", nt)
	const PANO: String = "res://Assets/Textures/Photo/ciel.jpg"
	if ResourceLoader.exists(PANO):
		psm.set_shader_parameter("pano_tex", load(PANO))
		psm.set_shader_parameter("use_pano", true)
	sky.sky_material = psm
	sky_mat = psm
	env.sky = sky
	# lumière ambiante de couleur fixe (celle calculée depuis le ciel fait des taches
	# sur les visages avec le rendu mobile)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.80, 0.80, 0.86)
	env.ambient_light_energy = 0.55
	# pas de reflets du ciel : évite des taches sur les visages (rendu mobile) et coûte moins
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 3.0
	env.tonemap_exposure = 0.95
	env.fog_enabled = true
	env.fog_light_color = Color(0.66, 0.78, 0.92)
	env.fog_density = 0.0016
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -35.0, 0.0)
	sun.light_energy = 1.05
	# ombres en 2 zones : très détaillées près de la caméra (visage, corps), plus
	# grossières au loin ; filtrage doux (réglage du projet)
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_split_1 = 0.08
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	sun.shadow_blur = 1.5
	sun.light_color = Color(1.0, 0.95, 0.86)
	add_child(sun)
	# lumière d'appoint chaude, opposée au soleil, sans ombre (visages jamais tout bleus)
	var fill: DirectionalLight3D = DirectionalLight3D.new()
	fill.name = "LumiereAppoint"
	fill.rotation_degrees = Vector3(-62.0, 150.0, 0.0)
	fill.light_energy = 0.30
	fill.light_color = Color(1.0, 0.85, 0.72)
	fill.shadow_enabled = false
	fill.light_specular = 0.0
	# n'éclaire que les personnages (couche 2) : sinon reflet blanc sur le sol brillant de l'arène
	fill.light_cull_mask = 2
	add_child(fill)


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
