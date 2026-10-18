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
var zone_banner: Label
var hp_fill: ColorRect
var en_fill: ColorRect
var hp_text: Label
var combo_label: Label
var ko_label: Label
var _combo_pop: float = 0.0
var _last_zone: String = ""
var _banner_t: float = 0.0
var _tick: float = 0.0


func setup(p: Node3D, w: Node3D) -> void:
	player = p
	world = w
	p.connect("hp_changed", _on_hp)
	p.connect("energy_changed", _on_energy)
	p.connect("combo_changed", _on_combo)
	_on_hp(float(p.get("hp")), float(p.get("max_hp")))
	_on_energy(float(p.get("energy")), float(p.get("max_energy")))


func _bar(pos: Vector2, size: Vector2, col: Color) -> ColorRect:
	var bg: ColorRect = ColorRect.new()
	bg.position = pos
	bg.size = size
	bg.color = Color(0.0, 0.0, 0.0, 0.55)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var fill: ColorRect = ColorRect.new()
	fill.position = Vector2(2.0, 2.0)
	fill.size = size - Vector2(4.0, 4.0)
	fill.color = col
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(fill)
	return fill


func _on_hp(v: float, m: float) -> void:
	hp_fill.size.x = 256.0 * clampf(v / m, 0.0, 1.0)
	hp_fill.color = Color(0.85, 0.15, 0.15) if v / m < 0.3 else Color(0.25, 0.85, 0.35)
	hp_text.text = "%d / %d" % [int(ceil(v)), int(m)]


func _on_energy(v: float, m: float) -> void:
	en_fill.size.x = 196.0 * clampf(v / m, 0.0, 1.0)


func _on_combo(count: int) -> void:
	combo_label.visible = count >= 2
	combo_label.text = "COMBO x%d" % count
	_combo_pop = 0.15


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	zone_label = _make_label(Vector2(20.0, 76.0), 22)
	info_label = _make_label(Vector2(20.0, 106.0), 14)
	# barres de vie (vert/rouge) et d'énergie (or)
	hp_fill = _bar(Vector2(20.0, 14.0), Vector2(260.0, 22.0), Color(0.25, 0.85, 0.35))
	hp_text = _make_label(Vector2(26.0, 14.0), 15)
	en_fill = _bar(Vector2(20.0, 42.0), Vector2(200.0, 14.0), Color(1.0, 0.78, 0.2))
	combo_label = _make_label(Vector2(0.0, 0.0), 34)
	combo_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	combo_label.offset_left = -300.0
	combo_label.offset_right = -40.0
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	combo_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	combo_label.visible = false
	ko_label = _make_label(Vector2(0.0, 0.0), 56)
	ko_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	ko_label.offset_left = -300.0
	ko_label.offset_right = 300.0
	ko_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ko_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.25))
	ko_label.text = "K.O. — retour au camp..."
	ko_label.visible = false
	help_label = _make_label(Vector2(20.0, 505.0), 14)
	help_label.visible = not DisplayServer.is_touchscreen_available()
	help_label.text = "ZQSD bouger · Maj courir · Espace sauter · C esquiver · J ou clic gauche : attaquer (4 coups) · clic droit/flèches : caméra · Échap : paramètres"
	zone_banner = Label.new()
	zone_banner.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	zone_banner.offset_top = 95.0
	zone_banner.offset_bottom = 150.0
	zone_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	zone_banner.add_theme_font_size_override("font_size", 40)
	zone_banner.add_theme_color_override("font_color", Color(1.0, 0.86, 0.35))
	zone_banner.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0))
	zone_banner.add_theme_constant_override("outline_size", 8)
	zone_banner.modulate.a = 0.0
	add_child(zone_banner)
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
	settings.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings.mouse_filter = Control.MOUSE_FILTER_STOP
	settings.visible = false
	add_child(settings)

	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.65)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings.add_child(dim)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	# bannière de zone : apparaît 3 s puis s'efface
	if _banner_t > 0.0:
		_banner_t -= delta
		zone_banner.modulate.a = clampf(_banner_t, 0.0, 1.0)
	if _combo_pop > 0.0:
		_combo_pop -= delta
		combo_label.scale = Vector2.ONE * (1.0 + _combo_pop * 2.0)
	if player != null:
		ko_label.visible = bool(player.get("is_dead"))
	_tick -= delta
	if _tick > 0.0 or player == null or world == null:
		return
	_tick = 0.25
	var p: Vector3 = player.global_position
	var zname: String = String(world.call("zone_name", p.x, p.z))
	zone_label.text = zname
	if zname != _last_zone:
		_last_zone = zname
		zone_banner.text = zname
		_banner_t = 3.0
	info_label.text = "%d FPS · Qualité : %s · x %d  y %d  z %d" % [
		Engine.get_frames_per_second(), GameSettings.quality_name(),
		int(p.x), int(p.y), int(p.z)]
