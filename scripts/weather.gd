extends Node3D
## Météo changeante : soleil, nuageux, pluie, orage (éclairs + tonnerre), brouillard.
## Chaque météo dure 70 à 140 s ; transition douce de 10 s (lumière, brouillard, nuages,
## couleur du ciel, pluie). Pluie : particules CPU qui suivent le joueur (nombre adapté
## à la qualité graphique). Très léger : aucun shader ni particule GPU supplémentaire.

const PRESETS: Dictionary = {
	"soleil": {"name": "Ensoleillé", "sun": 1.05, "amb": 0.55, "fog": 1.0, "cover": 0.55, "dark": 0.0, "rain": 0.0,
		"top": Color(0.16, 0.36, 0.78), "hor": Color(0.68, 0.80, 0.94), "fogc": Color(0.66, 0.78, 0.92), "msg": "Le soleil revient"},
	"nuageux": {"name": "Nuageux", "sun": 0.72, "amb": 0.55, "fog": 1.4, "cover": 0.36, "dark": 0.25, "rain": 0.0,
		"top": Color(0.28, 0.42, 0.66), "hor": Color(0.70, 0.76, 0.84), "fogc": Color(0.68, 0.74, 0.82), "msg": "Le ciel se couvre"},
	"pluie": {"name": "Pluie", "sun": 0.38, "amb": 0.48, "fog": 2.4, "cover": 0.12, "dark": 0.55, "rain": 1.0,
		"top": Color(0.33, 0.38, 0.46), "hor": Color(0.55, 0.58, 0.63), "fogc": Color(0.52, 0.56, 0.62), "msg": "La pluie commence"},
	"orage": {"name": "Orage", "sun": 0.22, "amb": 0.40, "fog": 2.8, "cover": 0.02, "dark": 0.8, "rain": 1.4,
		"top": Color(0.18, 0.20, 0.27), "hor": Color(0.38, 0.40, 0.46), "fogc": Color(0.35, 0.38, 0.44), "msg": "Un orage éclate !"},
	"brouillard": {"name": "Brouillard", "sun": 0.6, "amb": 0.6, "fog": 5.0, "cover": 0.3, "dark": 0.2, "rain": 0.0,
		"top": Color(0.55, 0.62, 0.72), "hor": Color(0.82, 0.85, 0.88), "fogc": Color(0.80, 0.83, 0.87), "msg": "Le brouillard se lève"},
}
const NEXT: Dictionary = {
	"soleil": ["nuageux", "nuageux", "brouillard", "soleil"],
	"nuageux": ["pluie", "soleil", "orage", "pluie"],
	"pluie": ["orage", "nuageux", "nuageux", "soleil"],
	"orage": ["pluie", "nuageux"],
	"brouillard": ["soleil", "nuageux"],
}
const RAIN_AMOUNT: Array = [140, 220, 360, 520]
const TRANSITION: float = 10.0

var env: Environment
var sun: DirectionalLight3D
var sky_mat: ShaderMaterial
var current: String = "soleil"
var _from: Dictionary = {}
var _to: Dictionary = {}
var _k: float = 1.0               # avancement de la transition (0..1)
var _timer: float = 90.0
var _cur: Dictionary = {}         # valeurs actuelles
var _rain: CPUParticles3D
var _flash: float = 0.0
var _bolt_t: float = 6.0
var _thunder_delay: float = -1.0
var forced: bool = false


func setup(e: Environment, s: DirectionalLight3D, sm: ShaderMaterial) -> void:
	env = e
	sun = s
	sky_mat = sm
	_cur = PRESETS["soleil"].duplicate()
	_to = _cur
	_build_rain()
	GameSettings.quality_changed.connect(func(_l: int) -> void: _rain.amount = int(RAIN_AMOUNT[GameSettings.quality]))
	_apply(_cur)


## Change de météo (transition douce). instant = sans transition (outil de test).
func set_weather(w: String, instant: bool = false) -> void:
	if not PRESETS.has(w):
		return
	current = w
	_from = _cur.duplicate()
	_to = PRESETS[w]
	_k = 1.0 if instant else 0.0
	if instant:
		_cur = _to.duplicate()
		_apply(_cur)
	var ps: Array = get_tree().get_nodes_in_group("player")
	if not ps.is_empty() and not instant:
		ps[0].emit_signal("announce", String(_to["msg"]))


func weather_name() -> String:
	return String(PRESETS[current]["name"])


## Éclair : flash du ciel et de la lumière ambiante (aussi utilisé par l'attaque finale).
func flash(strength: float) -> void:
	_flash = maxf(_flash, strength)


func _build_rain() -> void:
	_rain = CPUParticles3D.new()
	_rain.name = "Pluie"
	_rain.amount = int(RAIN_AMOUNT[GameSettings.quality])
	_rain.lifetime = 0.9
	_rain.local_coords = false
	_rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_rain.emission_box_extents = Vector3(16.0, 0.5, 16.0)
	_rain.direction = Vector3(0.08, -1.0, 0.0)
	_rain.spread = 2.0
	_rain.gravity = Vector3.ZERO
	_rain.initial_velocity_min = 24.0
	_rain.initial_velocity_max = 28.0
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(0.035, 1.0)
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.82, 0.88, 0.96, 0.6)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	q.material = m
	_rain.mesh = q
	_rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rain.emitting = false
	add_child(_rain)


func _process(delta: float) -> void:
	# changement automatique
	if not forced:
		_timer -= delta
		if _timer <= 0.0:
			_timer = randf_range(70.0, 140.0)
			var opts: Array = NEXT[current]
			set_weather(String(opts[randi() % opts.size()]))
	if _k < 1.0:
		_k = minf(_k + delta / TRANSITION, 1.0)
		var e: float = smoothstep(0.0, 1.0, _k)
		for key in _to:
			var a: Variant = _from.get(key, _to[key])
			var b: Variant = _to[key]
			if b is float:
				_cur[key] = lerpf(float(a), float(b), e)
			elif b is Color:
				_cur[key] = (a as Color).lerp(b as Color, e)
			else:
				_cur[key] = b
	# éclairs pendant l'orage
	if current == "orage" and _k > 0.6:
		_bolt_t -= delta
		if _bolt_t <= 0.0:
			_bolt_t = randf_range(4.0, 11.0)
			flash(1.0)
			_thunder_delay = randf_range(0.3, 1.6)
			_sky_bolt()
	if _thunder_delay > 0.0:
		_thunder_delay -= delta
		if _thunder_delay <= 0.0:
			Sfx.play("thunder", randf_range(0.8, 1.0))
	_flash = maxf(_flash - delta * 3.0, 0.0)
	_apply(_cur)
	# pluie : suit le joueur
	var ps: Array = get_tree().get_nodes_in_group("player")
	var r: float = float(_cur.get("rain", 0.0))
	_rain.emitting = r > 0.05
	if not ps.is_empty():
		var p: Vector3 = (ps[0] as Node3D).global_position
		_rain.global_position = p + Vector3(0.0, 14.0, 0.0)
	Sfx.set_loop("rain", clampf(r, 0.0, 1.0))


func _apply(c: Dictionary) -> void:
	if sun != null:
		sun.light_energy = float(c["sun"]) * (1.0 + _flash * 1.5)
	if env != null:
		env.ambient_light_energy = float(c["amb"]) + _flash * 1.2
		env.fog_density = GameSettings.fog_density() * float(c["fog"])
		env.fog_light_color = c["fogc"]
		if env.background_mode == Environment.BG_COLOR:
			env.background_color = (c["hor"] as Color).lerp(Color(1, 1, 1), _flash * 0.5)
	if sky_mat != null:
		sky_mat.set_shader_parameter("cloud_cover", float(c["cover"]) + 0.0)
		sky_mat.set_shader_parameter("cloud_dark", float(c["dark"]))
		sky_mat.set_shader_parameter("top_color", c["top"])
		sky_mat.set_shader_parameter("horizon_color", c["hor"])
		sky_mat.set_shader_parameter("flash", _flash)


## Éclair visible dans le ciel, au loin, dans une direction au hasard.
func _sky_bolt() -> void:
	var ps: Array = get_tree().get_nodes_in_group("player")
	if ps.is_empty():
		return
	var p: Vector3 = (ps[0] as Node3D).global_position
	var a: float = randf() * TAU
	var d: float = randf_range(60.0, 140.0)
	var gp: Vector3 = p + Vector3(cos(a) * d, 0.0, sin(a) * d)
	var w: Node = get_parent()
	if w != null and w.has_method("ground_height"):
		gp.y = float(w.call("ground_height", gp.x, gp.z))
	load("res://scripts/combat_fx.gd").call("bolt", get_parent(), gp + Vector3(randf_range(-20.0, 20.0), 110.0, 0.0), gp, Color(0.8, 0.85, 1.0), 1.2)
