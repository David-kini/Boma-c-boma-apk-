extends CanvasLayer
## HUD : nom de zone, FPS / qualité / position, aide clavier (PC),
## commandes tactiles (hud_overlay.gd) et menu PARAMÈTRES (qualité graphique).
## Le menu met le jeu en pause. Ouverture : bouton MENU (tactile), Échap ou F1 (PC).

const Overlay = preload("res://scripts/hud_overlay.gd")

var player: Node3D = null
var world: Node3D = null
var zone_label: Label
var info_label: Label
var help_label: Label
var overlay: Control
var settings: Control
var info_text: Label
var quality_buttons: Array = []
var _tick: float = 0.0


func setup(p: Node3D, w: Node3D) -> void:
	player = p
	world = w


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	zone_label = _make_label(Vector2(20.0, 12.0), 26)
	info_label = _make_label(Vector2(20.0, 48.0), 15)
	help_label = _make_label(Vector2(20.0, 505.0), 14)
	help_label.visible = not DisplayServer.is_touchscreen_available()
	help_label.text = "ZQSD/WASD bouger · Maj courir · Espace sauter · C esquiver · flèches ou clic droit : caméra · Échap : paramètres"
	overlay = Overlay.new()
	overlay.name = "Commandes"
	add_child(overlay)
	_build_settings()


func _make_label(pos: Vector2, font_size: int) -> Label:
	var l: Label = Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	l.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0))
	l.add_theme_constant_override("outline_size", 5)
	add_child(l)
	return l


# ------------------------------------------------------------ paramètres

func _build_settings() -> void:
	settings = Control.new()
	settings.name = "Parametres"
	settings.set_anchors_preset(Control.PRESET_FULL_RECT)
	settings.mouse_filter = Control.MOUSE_FILTER_STOP
	settings.visible = false
	add_child(settings)

	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	settings.add_child(dim)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	settings.add_child(center)

	var panel: PanelContainer = PanelContainer.new()
	center.add_child(panel)
	var margin: MarginContainer = MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 18)
	panel.add_child(margin)
	var vb: VBoxContainer = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	margin.add_child(vb)

	var title: Label = Label.new()
	title.text = "PARAMÈTRES"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	vb.add_child(title)

	var sub: Label = Label.new()
	sub.text = "Qualité graphique"
	sub.add_theme_font_size_override("font_size", 18)
	vb.add_child(sub)

	var group: ButtonGroup = ButtonGroup.new()
	for i in range(GameSettings.QUALITY_NAMES.size()):
		var b: Button = Button.new()
		b.text = String(GameSettings.QUALITY_NAMES[i])
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(380.0, 50.0)
		b.add_theme_font_size_override("font_size", 22)
		b.pressed.connect(_on_quality_button.bind(i))
		vb.add_child(b)
		quality_buttons.append(b)

	info_text = Label.new()
	info_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_text.custom_minimum_size = Vector2(380.0, 44.0)
	info_text.add_theme_font_size_override("font_size", 15)
	info_text.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	vb.add_child(info_text)

	var resume: Button = Button.new()
	resume.text = "Reprendre"
	resume.custom_minimum_size = Vector2(380.0, 54.0)
	resume.add_theme_font_size_override("font_size", 22)
	resume.pressed.connect(close_settings)
	vb.add_child(resume)


func _refresh_settings() -> void:
	for i in range(quality_buttons.size()):
		var b: Button = quality_buttons[i]
		b.set_pressed_no_signal(i == GameSettings.quality)
	info_text.text = GameSettings.quality_info(GameSettings.quality)


func _on_quality_button(level: int) -> void:
	GameSettings.set_quality(level)
	_refresh_settings()


func open_settings() -> void:
	_refresh_settings()
	settings.visible = true
	get_tree().paused = true


func close_settings() -> void:
	settings.visible = false
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var ke: InputEventKey = event as InputEventKey
		if ke.pressed and not ke.echo and (ke.physical_keycode == KEY_ESCAPE or ke.physical_keycode == KEY_F1):
			if settings.visible:
				close_settings()
			else:
				open_settings()


# ------------------------------------------------------------ affichage

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
