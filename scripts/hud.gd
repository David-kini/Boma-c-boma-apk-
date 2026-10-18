extends CanvasLayer
## HUD de la phase 2 : nom de zone, FPS / qualité / position, aide clavier (PC),
## commandes tactiles (hud_overlay.gd). Barres de vie / énergie : phase 3.

const Overlay = preload("res://scripts/hud_overlay.gd")

var player: Node3D = null
var world: Node3D = null
var zone_label: Label
var info_label: Label
var help_label: Label
var overlay: Control
var _tick: float = 0.0


func setup(p: Node3D, w: Node3D) -> void:
	player = p
	world = w


func _ready() -> void:
	layer = 10
	zone_label = _make_label(Vector2(20.0, 12.0), 26)
	info_label = _make_label(Vector2(20.0, 48.0), 15)
	help_label = _make_label(Vector2(20.0, 505.0), 14)
	help_label.visible = not DisplayServer.is_touchscreen_available()
	help_label.text = "ZQSD/WASD bouger · Maj courir · Espace sauter · C esquiver · flèches ou clic droit : caméra · F1 qualité"
	overlay = Overlay.new()
	overlay.name = "Commandes"
	add_child(overlay)


func _make_label(pos: Vector2, font_size: int) -> Label:
	var l: Label = Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	l.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0))
	l.add_theme_constant_override("outline_size", 5)
	add_child(l)
	return l


func _process(delta: float) -> void:
	_tick -= delta
	if _tick > 0.0 or player == null or world == null:
		return
	_tick = 0.25
	var p: Vector3 = player.global_position
	zone_label.text = String(world.call("zone_name", p.x, p.z))
	info_label.text = "%d FPS · Qualité : %s · x %d  y %d  z %d" % [
		Engine.get_frames_per_second(), GameSettings.quality_name(),
		int(p.x), int(p.y), int(p.z)]
