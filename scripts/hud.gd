extends CanvasLayer
## HUD : nom de zone, FPS / qualité / position, aide clavier (PC),
## commandes tactiles (hud_overlay.gd) et menu PARAMÈTRES (qualité graphique).
## Le menu met le jeu en pause. Ouverture : bouton MENU (tactile), Échap ou F1 (PC).

const Overlay = preload("res://scripts/hud_overlay.gd")

var player: Node3D = null
var world: Node3D = null
const Radar = preload("res://scripts/radar.gd")
var radar: Control
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
var xp_fill: ColorRect
var ulti_fill: ColorRect
var lvl_label: Label
var power_label: Label
var wings_button: Button
var weapon_button: Button
var weapon_desc: Label
var bow_button: Button
var coat_button: Button
var potion_button: Button
var inv_label: Label
var boss_root: Control
var boss_fill: ColorRect
var boss_name: Label
var title_screen: Control
var powers_panel: Control
var cine_root: Control
var cine_text: Label
var cine_who: Label
var cine_title_l: Label
var cine_sub_l: Label
var cine_fade_r: ColorRect
var _cine_hidden: Array = []
var _title_t: float = 0.0
var power_buttons: Array = []
var _combo_pop: float = 0.0
var _last_zone: String = ""
var _banner_t: float = 0.0
var _tick: float = 0.0


func setup(p: Node3D, w: Node3D) -> void:
	player = p
	radar.player = p
	world = w
	p.connect("hp_changed", _on_hp)
	p.connect("energy_changed", _on_energy)
	p.connect("combo_changed", _on_combo)
	p.connect("level_changed", _on_level)
	p.connect("announce", show_banner)
	p.connect("inventory_changed", _on_inventory)
	p.connect("ulti_changed", _on_ulti)
	_on_ulti(float(p.get("ulti")))
	_on_inventory(int(p.get("gold")), int(p.get("potions")))
	_on_level(int(p.get("level")), int(p.get("xp")), int(p.call("xp_needed")))
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


func _on_level(lv: int, xp: int, need: int) -> void:
	lvl_label.text = "Niv. %d" % lv
	xp_fill.size.x = 196.0 * clampf(float(xp) / float(need), 0.0, 1.0)


func _on_ulti(v: float) -> void:
	ulti_fill.size.x = 196.0 * clampf(v / 100.0, 0.0, 1.0)
	ulti_fill.color = Color(1.0, 0.85, 0.3) if v >= 100.0 else Color(0.75, 0.4, 1.0)


func _on_inventory(gold: int, potions: int) -> void:
	inv_label.text = "Or : %d    Potions : %d" % [gold, potions]


## Grand message au centre-haut (niveau, arme, pouvoirs).
func show_banner(text: String) -> void:
	zone_banner.text = text
	_banner_t = 3.0


func _on_combo(count: int) -> void:
	combo_label.visible = count >= 2
	combo_label.text = "COMBO x%d" % count
	_combo_pop = 0.15


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	zone_label = _make_label(Vector2(20.0, 86.0), 22)
	info_label = _make_label(Vector2(20.0, 116.0), 14)
	# barres de vie (vert/rouge) et d'énergie (or)
	hp_fill = _bar(Vector2(20.0, 14.0), Vector2(260.0, 22.0), Color(0.25, 0.85, 0.35))
	hp_text = _make_label(Vector2(26.0, 14.0), 15)
	en_fill = _bar(Vector2(20.0, 42.0), Vector2(200.0, 14.0), Color(1.0, 0.78, 0.2))
	xp_fill = _bar(Vector2(20.0, 60.0), Vector2(200.0, 8.0), Color(0.45, 0.85, 1.0))
	ulti_fill = _bar(Vector2(20.0, 72.0), Vector2(200.0, 8.0), Color(0.75, 0.4, 1.0))
	lvl_label = _make_label(Vector2(228.0, 40.0), 18)
	inv_label = _make_label(Vector2(20.0, 140.0), 16)
	inv_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.35))
	power_label = _make_label(Vector2(290.0, 14.0), 18)
	power_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.35))
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
	help_label.text = "ZQSD bouger · Maj courir · Espace sauter · C esquiver · J/clic : attaquer (5 coups) · F voler · T Transformation · G pouvoir · P choix du pouvoir · V téléport (maintenir = ciblage) · U attaque finale · R arme · H potion · Échap : menu"
	_build_boss_bar()
	radar = Radar.new()
	radar.name = "Radar"
	add_child(radar)
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
	_build_powers()
	_build_cine()
	_build_title()


## Barre de vie du boss en haut de l'écran (visible quand un boss est proche et actif).
func _build_boss_bar() -> void:
	boss_root = Control.new()
	boss_root.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	boss_root.offset_left = -260.0
	boss_root.offset_right = 260.0
	boss_root.offset_top = 150.0
	boss_root.offset_bottom = 190.0
	boss_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_root.visible = false
	add_child(boss_root)
	var bg: ColorRect = ColorRect.new()
	bg.position = Vector2(0.0, 22.0)
	bg.size = Vector2(520.0, 18.0)
	bg.color = Color(0.0, 0.0, 0.0, 0.6)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_root.add_child(bg)
	boss_fill = ColorRect.new()
	boss_fill.position = Vector2(2.0, 2.0)
	boss_fill.size = Vector2(516.0, 14.0)
	boss_fill.color = Color(0.8, 0.1, 0.15)
	boss_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(boss_fill)
	boss_name = Label.new()
	boss_name.size = Vector2(520.0, 22.0)
	boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_name.add_theme_font_size_override("font_size", 18)
	boss_name.add_theme_color_override("font_color", Color(1.0, 0.86, 0.35))
	boss_name.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0))
	boss_name.add_theme_constant_override("outline_size", 5)
	boss_root.add_child(boss_name)


## Écran titre : le jeu reste en pause jusqu'au bouton JOUER.
func _build_title() -> void:
	title_screen = Control.new()
	title_screen.name = "EcranTitre"
	title_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_screen.mouse_filter = Control.MOUSE_FILTER_STOP
	title_screen.visible = false
	add_child(title_screen)
	var dim: ColorRect = ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.02, 0.06, 0.82)
	title_screen.add_child(dim)
	var vb: VBoxContainer = VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vb.offset_left = -330.0
	vb.offset_right = 330.0
	vb.offset_top = -170.0
	vb.offset_bottom = 170.0
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 14)
	title_screen.add_child(vb)
	var t1: Label = Label.new()
	t1.text = "DUEL ÉCLAIR"
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t1.add_theme_font_size_override("font_size", 72)
	t1.add_theme_color_override("font_color", Color(1.0, 0.84, 0.3))
	t1.add_theme_color_override("font_outline_color", Color(0.15, 0.08, 0.0))
	t1.add_theme_constant_override("outline_size", 12)
	vb.add_child(t1)
	var t2: Label = Label.new()
	t2.text = "RISE OF LEGEND"
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t2.add_theme_font_size_override("font_size", 30)
	t2.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0))
	t2.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0))
	t2.add_theme_constant_override("outline_size", 6)
	vb.add_child(t2)
	var play: Button = Button.new()
	play.text = "JOUER"
	play.custom_minimum_size = Vector2(320.0, 64.0)
	play.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	play.add_theme_font_size_override("font_size", 30)
	play.pressed.connect(start_game)
	vb.add_child(play)
	var sub: Label = Label.new()
	sub.text = "Vaincs le Roi Squelette dans son repaire (nord-ouest)."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 16)
	vb.add_child(sub)
	var crash: String = String(Diagnostic.previous_crash)
	if crash != "":
		# rapport de la partie précédente interrompue (à envoyer en capture d'écran)
		var rep: Label = Label.new()
		rep.text = "La dernière partie s'est fermée d'un coup. Rapport :\n" + crash
		rep.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rep.custom_minimum_size = Vector2(660.0, 0.0)
		rep.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rep.add_theme_font_size_override("font_size", 14)
		rep.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45))
		vb.add_child(rep)


## Menu des pouvoirs : accessible pendant le combat (le temps est ralenti, pas arrêté).
func _build_powers() -> void:
	var Powers: GDScript = load("res://scripts/powers.gd")
	powers_panel = Control.new()
	powers_panel.name = "MenuPouvoirs"
	powers_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	powers_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	powers_panel.visible = false
	add_child(powers_panel)
	var dim: ColorRect = ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.02, 0.08, 0.45)
	powers_panel.add_child(dim)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	powers_panel.add_child(center)
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _solid_style())
	center.add_child(panel)
	var margin: MarginContainer = MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 10)
	panel.add_child(margin)
	var vb: VBoxContainer = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	margin.add_child(vb)
	var title: Label = Label.new()
	title.text = "POUVOIRS — choisis le pouvoir du bouton POUVOIR"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	vb.add_child(title)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 4)
	vb.add_child(grid)
	for i in range(int(Powers.call("count"))):
		var d: Dictionary = Powers.call("get_def", i)
		var b: Button = Button.new()
		b.custom_minimum_size = Vector2(360.0, 62.0)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 15)
		b.text = "%s\n%s\nPortée %s · durée %s · recharge %s s" % [d["name"], d["desc"], d["range"], d["time"], str(d["cd"])]
		b.pressed.connect(_on_power_chosen.bind(i))
		grid.add_child(b)
		power_buttons.append(b)
	var close: Button = Button.new()
	close.text = "Fermer"
	close.custom_minimum_size = Vector2(200.0, 40.0)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.add_theme_font_size_override("font_size", 18)
	close.pressed.connect(close_powers)
	vb.add_child(close)


## Fond sombre opaque et bordure dorée pour les menus (texte toujours lisible).
func _solid_style() -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.05, 0.10, 0.96)
	sb.border_color = Color(0.9, 0.75, 0.3)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	return sb


func open_powers() -> void:
	if player == null or title_screen.visible:
		return
	var cur: int = int(player.get("power_index"))
	for i in range(power_buttons.size()):
		var b: Button = power_buttons[i]
		b.modulate = Color(1.0, 0.9, 0.45) if i == cur else Color(1, 1, 1)
		b.text = ("▶ " if i == cur else "") + b.text.trim_prefix("▶ ")
	powers_panel.visible = true
	overlay.visible = false
	Engine.time_scale = 0.25


func close_powers() -> void:
	powers_panel.visible = false
	overlay.visible = true
	Engine.time_scale = 1.0


func _on_power_chosen(i: int) -> void:
	player.call("set_power", i)
	close_powers()


# ------------------------------------------------------------ cinématiques

func _build_cine() -> void:
	cine_root = Control.new()
	cine_root.name = "Cinematique"
	cine_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cine_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cine_root.visible = false
	add_child(cine_root)
	for top in [true, false]:
		var bar: ColorRect = ColorRect.new()
		bar.color = Color(0, 0, 0, 1)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
		if top:
			bar.offset_bottom = 60.0
		else:
			bar.offset_top = -90.0
		cine_root.add_child(bar)
	cine_fade_r = ColorRect.new()
	cine_fade_r.color = Color(0, 0, 0, 0)
	cine_fade_r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cine_fade_r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cine_root.add_child(cine_fade_r)
	cine_who = Label.new()
	cine_who.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	cine_who.offset_top = -86.0
	cine_who.offset_bottom = -62.0
	cine_who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cine_who.add_theme_font_size_override("font_size", 18)
	cine_who.add_theme_color_override("font_color", Color(1.0, 0.8, 0.35))
	cine_root.add_child(cine_who)
	cine_text = Label.new()
	cine_text.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	cine_text.offset_top = -62.0
	cine_text.offset_bottom = -8.0
	cine_text.offset_left = 60.0
	cine_text.offset_right = -60.0
	cine_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cine_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cine_text.add_theme_font_size_override("font_size", 20)
	cine_root.add_child(cine_text)
	cine_title_l = Label.new()
	cine_title_l.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	cine_title_l.offset_left = -500.0
	cine_title_l.offset_right = 500.0
	cine_title_l.offset_top = -70.0
	cine_title_l.offset_bottom = 10.0
	cine_title_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cine_title_l.add_theme_font_size_override("font_size", 64)
	cine_title_l.add_theme_color_override("font_color", Color(1.0, 0.84, 0.3))
	cine_title_l.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.0))
	cine_title_l.add_theme_constant_override("outline_size", 12)
	cine_root.add_child(cine_title_l)
	cine_sub_l = Label.new()
	cine_sub_l.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	cine_sub_l.offset_left = -500.0
	cine_sub_l.offset_right = 500.0
	cine_sub_l.offset_top = 14.0
	cine_sub_l.offset_bottom = 60.0
	cine_sub_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cine_sub_l.add_theme_font_size_override("font_size", 28)
	cine_sub_l.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	cine_sub_l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	cine_sub_l.add_theme_constant_override("outline_size", 6)
	cine_root.add_child(cine_sub_l)
	var skip: Button = Button.new()
	skip.text = "Passer ▶"
	skip.add_theme_font_size_override("font_size", 18)
	skip.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	skip.offset_left = -150.0
	skip.offset_right = -14.0
	skip.offset_top = 12.0
	skip.offset_bottom = 50.0
	skip.pressed.connect(func() -> void:
		var c: Node = get_parent().get("cinematic")
		if c != null:
			c.call("skip"))
	cine_root.add_child(skip)


func cine_begin() -> void:
	_cine_hidden.clear()
	for ch in get_children():
		if ch is CanvasItem and ch != cine_root and (ch as CanvasItem).visible:
			(ch as CanvasItem).visible = false
			_cine_hidden.append(ch)
	cine_root.visible = true
	cine_text.text = ""
	cine_who.text = ""
	cine_title_l.text = ""
	cine_sub_l.text = ""
	cine_fade_r.color.a = 0.0


func cine_end() -> void:
	cine_root.visible = false
	for ch in _cine_hidden:
		if is_instance_valid(ch):
			(ch as CanvasItem).visible = true
	_cine_hidden.clear()
	settings.visible = false
	powers_panel.visible = false
	title_screen.visible = false


func cine_line(who: String, text: String) -> void:
	cine_who.text = who
	cine_text.text = text


func cine_title(title: String, sub: String, dur: float) -> void:
	cine_title_l.text = title
	cine_sub_l.text = sub
	_title_t = dur


func cine_fade(alpha: float, time: float) -> void:
	var tw: Tween = cine_fade_r.create_tween()
	tw.tween_property(cine_fade_r, "color:a", alpha, time)


func show_title() -> void:
	title_screen.visible = true
	overlay.visible = false
	get_tree().paused = true


func start_game() -> void:
	title_screen.visible = false
	overlay.visible = true
	get_tree().paused = false
	Sfx.play("levelup")
	# première partie : cinématique d'introduction (passable)
	if player != null and not (player.get("story") as Array).has("intro_vue"):
		var c: Node = get_parent().get("cinematic")
		if c != null:
			c.call("play_intro")


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
	dim.color = Color(0.0, 0.0, 0.0, 0.30)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings.add_child(dim)

	# panneau à droite : le héros reste visible à gauche (aperçu de la personnalisation)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	center.offset_left = -440.0
	center.offset_top = 6.0
	center.offset_bottom = -6.0
	settings.add_child(center)

	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _solid_style())
	center.add_child(panel)
	var margin: MarginContainer = MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 12)
	panel.add_child(margin)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(400.0, minf(620.0, get_viewport().get_visible_rect().size.y - 40.0))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var vb: VBoxContainer = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 5)
	scroll.add_child(vb)

	var title: Label = Label.new()
	title.text = "MENU / PAUSE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
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
		b.custom_minimum_size = Vector2(380.0, 34.0)
		b.add_theme_font_size_override("font_size", 17)
		b.pressed.connect(_on_quality_button.bind(i))
		vb.add_child(b)
		quality_buttons.append(b)

	info_text = Label.new()
	info_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_text.custom_minimum_size = Vector2(380.0, 36.0)
	info_text.add_theme_font_size_override("font_size", 13)
	info_text.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	vb.add_child(info_text)

	var perso: Label = Label.new()
	perso.text = "Personnalisation"
	perso.add_theme_font_size_override("font_size", 18)
	vb.add_child(perso)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	vb.add_child(row)
	coat_button = Button.new()
	coat_button.custom_minimum_size = Vector2(187.0, 40.0)
	coat_button.add_theme_font_size_override("font_size", 17)
	coat_button.pressed.connect(_on_coat_button)
	row.add_child(coat_button)
	potion_button = Button.new()
	potion_button.custom_minimum_size = Vector2(187.0, 40.0)
	potion_button.add_theme_font_size_override("font_size", 17)
	potion_button.pressed.connect(_on_potion_button)
	row.add_child(potion_button)
	wings_button = Button.new()
	wings_button.custom_minimum_size = Vector2(380.0, 40.0)
	wings_button.add_theme_font_size_override("font_size", 20)
	wings_button.pressed.connect(_on_wings_button)
	vb.add_child(wings_button)
	weapon_button = Button.new()
	weapon_button.custom_minimum_size = Vector2(380.0, 40.0)
	weapon_button.add_theme_font_size_override("font_size", 20)
	weapon_button.pressed.connect(_on_weapon_button)
	vb.add_child(weapon_button)
	weapon_desc = Label.new()
	weapon_desc.custom_minimum_size = Vector2(380.0, 60.0)
	weapon_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	weapon_desc.add_theme_font_size_override("font_size", 18)
	weapon_desc.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55))
	weapon_desc.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	weapon_desc.add_theme_constant_override("outline_size", 6)
	vb.add_child(weapon_desc)
	bow_button = Button.new()
	bow_button.custom_minimum_size = Vector2(380.0, 40.0)
	bow_button.add_theme_font_size_override("font_size", 20)
	bow_button.pressed.connect(func() -> void:
		player.call("set_bow", not bool(player.get("bow_mode")))
		player.set("_bow_auto", false)
		_refresh_settings())
	vb.add_child(bow_button)
	var camfx: Button = Button.new()
	camfx.custom_minimum_size = Vector2(380.0, 36.0)
	camfx.add_theme_font_size_override("font_size", 17)
	camfx.text = "Effets de caméra : " + ("normaux" if GameSettings.cam_fx else "réduits")
	camfx.pressed.connect(func() -> void:
		GameSettings.set_cam_fx(not GameSettings.cam_fx)
		camfx.text = "Effets de caméra : " + ("normaux" if GameSettings.cam_fx else "réduits"))
	vb.add_child(camfx)
	var story: HBoxContainer = HBoxContainer.new()
	story.add_theme_constant_override("separation", 6)
	vb.add_child(story)
	var intro_b: Button = Button.new()
	intro_b.text = "Revoir l'introduction"
	intro_b.custom_minimum_size = Vector2(187.0, 34.0)
	intro_b.add_theme_font_size_override("font_size", 14)
	intro_b.pressed.connect(func() -> void:
		close_settings()
		get_parent().get("cinematic").call("play_intro"))
	story.add_child(intro_b)
	var end_b: Button = Button.new()
	end_b.name = "BoutonFin"
	end_b.text = "Voir la fin"
	end_b.custom_minimum_size = Vector2(187.0, 34.0)
	end_b.add_theme_font_size_override("font_size", 14)
	end_b.pressed.connect(func() -> void:
		if player != null and (player.get("story") as Array).has("fin_debloquee"):
			close_settings()
			get_parent().get("cinematic").call("play_ending")
		else:
			show_banner("Bats les 5 boss pour débloquer la fin (%d / 5)" % int(player.call("bosses_count"))))
	story.add_child(end_b)
	var pw: Button = Button.new()
	pw.text = "Pouvoirs…"
	pw.custom_minimum_size = Vector2(380.0, 40.0)
	pw.add_theme_font_size_override("font_size", 20)
	pw.pressed.connect(func() -> void:
		close_settings()
		open_powers())
	vb.add_child(pw)
	var resume: Button = Button.new()
	resume.text = "Reprendre"
	resume.custom_minimum_size = Vector2(380.0, 46.0)
	resume.add_theme_font_size_override("font_size", 22)
	resume.pressed.connect(close_settings)
	vb.add_child(resume)


func _on_wings_button() -> void:
	var variants: Array = ["ange", "demon", "eclair", "or"]
	var cur: String = String(player.get("wings_variant"))
	var nxt: String = variants[(variants.find(cur) + 1) % variants.size()]
	player.call("set_wings", nxt)
	_refresh_settings()


func _on_coat_button() -> void:
	var names: Array = ["Noir", "Bordeaux", "Bleu nuit", "Blanc"]
	var cur: String = String(player.get("coat_name"))
	player.call("set_coat", names[(names.find(cur) + 1) % names.size()])
	_refresh_settings()


func _on_potion_button() -> void:
	player.call("use_potion")
	_refresh_settings()


func _on_weapon_button() -> void:
	player.call("cycle_weapon")
	_refresh_settings()


func _refresh_settings() -> void:
	if player != null:
		var names: Dictionary = {"ange": "Ailes d'ange", "demon": "Ailes de démon", "eclair": "Ailes d'éclair", "or": "Ailes d'or"}
		wings_button.text = "Ailes : " + String(names.get(String(player.get("wings_variant")), "?"))
		var Weapons: GDScript = load("res://scripts/weapons.gd")
		var d: Dictionary = Weapons.call("get_def", int(player.get("weapon_index")))
		weapon_button.text = "Arme : " + String(d["name"]) + "  (Niv. %d)" % int(player.get("level"))
		bow_button.text = "Mode : " + ("ARC (touche B)" if bool(player.get("bow_mode")) else "ÉPÉE (touche B pour l'arc)")
		weapon_desc.text = "Dégâts x%.2f · Durée des pouvoirs x%.2f (niveau %d)\nPouvoir : %s" % [float(d["dmg"]), float(player.call("duration_mult")), int(player.get("level")), String(d.get("power", ""))]
		coat_button.text = "Manteau : " + String(player.get("coat_name"))
		potion_button.text = "Potion (%d) · Or %d" % [int(player.get("potions")), int(player.get("gold"))]
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
	# aperçu : les ailes s'affichent pendant que le menu est ouvert
	var w: Node = player.get("wings")
	if w != null:
		w.process_mode = Node.PROCESS_MODE_ALWAYS
		w.call("set_deployed", true)


func close_settings() -> void:
	settings.visible = false
	get_tree().paused = false
	var w: Node = player.get("wings")
	if w != null:
		w.process_mode = Node.PROCESS_MODE_INHERIT
		w.call("set_deployed", bool(player.get("is_flying")))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var ke: InputEventKey = event as InputEventKey
		if ke.pressed and not ke.echo and (ke.physical_keycode == KEY_ESCAPE or ke.physical_keycode == KEY_F1):
			if title_screen.visible:
				return
			if settings.visible:
				close_settings()
			else:
				open_settings()


# ------------------------------------------------------------ affichage

func _process(delta: float) -> void:
	if _title_t > 0.0:
		_title_t -= delta
		if _title_t <= 0.0:
			cine_title_l.text = ""
			cine_sub_l.text = ""
	radar.set_process(not cine_root.visible and not title_screen.visible)
	if cine_root.visible or title_screen.visible:
		radar.visible = false
	if cine_root.visible:
		return
	if GameInput.powers_menu_buffer > 0.0:
		GameInput.powers_menu_buffer = 0.0
		if powers_panel.visible:
			close_powers()
		elif not settings.visible:
			open_powers()
	if title_screen.visible:
		zone_banner.modulate.a = 0.0
		return
	# bannière de zone : apparaît 3 s puis s'efface
	if _banner_t > 0.0:
		_banner_t -= delta
		zone_banner.modulate.a = clampf(_banner_t, 0.0, 1.0)
	if _combo_pop > 0.0:
		_combo_pop -= delta
		combo_label.scale = Vector2.ONE * (1.0 + _combo_pop * 2.0)
	if player != null:
		ko_label.visible = bool(player.get("is_dead"))
		var txt: String = ""
		if bool(player.get("is_flying")):
			txt += "VOL %d s   " % int(ceil(float(player.get("fly_left"))))
		if bool(player.get("is_divine")):
			txt += "DIVIN %d s" % int(ceil(float(player.get("divine_left"))))
		elif float(player.get("energy")) >= float(player.get("max_energy")):
			txt += "Énergie pleine : DIVIN prêt !   "
		if float(player.get("ulti")) >= 100.0:
			txt += "ULTI prêt !"
		power_label.text = txt
		_update_boss_bar()
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
	var meteo: String = ""
	var wt: Node = world.get("weather")
	if wt != null:
		meteo = " · " + String(wt.call("weather_name"))
	info_label.text = "%d FPS · Qualité : %s%s · x %d  y %d  z %d" % [
		Engine.get_frames_per_second(), GameSettings.quality_name(), meteo,
		int(p.x), int(p.y), int(p.z)]


func _update_boss_bar() -> void:
	var show: bool = false
	for b in get_tree().get_nodes_in_group("boss"):
		var bn: Node3D = b as Node3D
		if String(bn.get("state")) == "dead" or String(bn.get("state")) == "idle":
			continue
		var far: float = 90.0 if String(bn.get("boss_kind")) == "dragon" else 40.0
		if bn.global_position.distance_to(player.global_position) > far:
			continue
		show = true
		var r: float = clampf(float(bn.get("hp")) / float(bn.get("max_hp")), 0.0, 1.0)
		boss_fill.size.x = 516.0 * r
		boss_name.text = "%s  —  phase %d" % [String(bn.get("display_name")), int(bn.get("phase"))]
		break
	boss_root.visible = show
