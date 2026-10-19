extends Control
## Commandes tactiles : joystick flottant (moitié gauche), glisser pour la caméra
## (moitié droite), boutons ATTAQUE / SAUT / ESQ. / VOL / DIVIN / ARME et MENU.
## Affiché seulement si un écran tactile est disponible.

const JOY_RADIUS: float = 90.0

var enabled: bool = false
var joy_id: int = -1
var joy_center: Vector2 = Vector2.ZERO
var joy_vec: Vector2 = Vector2.ZERO
var cam_id: int = -1
var btn_touch: Dictionary = {}
var pressed: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	enabled = DisplayServer.is_touchscreen_available()


func _buttons() -> Dictionary:
	var s: Vector2 = size
	return {
		"attack": [Vector2(s.x - 125.0, s.y - 125.0), 64.0, "ATTAQUE"],
		"jump": [Vector2(s.x - 275.0, s.y - 75.0), 44.0, "SAUT"],
		"dodge": [Vector2(s.x - 95.0, s.y - 275.0), 44.0, "ESQ."],
		"fly": [Vector2(s.x - 245.0, s.y - 205.0), 40.0, "VOL"],
		"divine": [Vector2(s.x - 400.0, s.y - 72.0), 40.0, "DIVIN"],
		"weapon": [Vector2(s.x - 58.0, 125.0), 30.0, "ARME"],
		"heal": [Vector2(s.x - 58.0, 195.0), 30.0, "SOIN"],
		"shoot": [Vector2(s.x - 210.0, s.y - 305.0), 42.0, _power_label()],
		"powers": [Vector2(s.x - 58.0, 265.0), 30.0, "POUV."],
		"tp": [Vector2(s.x - 390.0, s.y - 195.0), 38.0, "TP"],
		"ulti": [Vector2(s.x - 335.0, s.y - 320.0), 40.0, "ULTI"],
		"menu": [Vector2(s.x - 58.0, 50.0), 34.0, "MENU"],
	}


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_reset()


func _reset() -> void:
	joy_id = -1
	cam_id = -1
	joy_vec = Vector2.ZERO
	btn_touch.clear()
	pressed.clear()
	GameInput.touch_move = Vector2.ZERO
	GameInput.touch_jump_held = false
	GameInput.touch_tp_held = false
	GameInput.touch_attack_held = false


func _input(event: InputEvent) -> void:
	if not enabled or get_tree().paused:
		return
	if event is InputEventScreenTouch:
		var te: InputEventScreenTouch = event as InputEventScreenTouch
		if te.pressed:
			_touch_down(te.index, te.position)
		else:
			_touch_up(te.index)
	elif event is InputEventScreenDrag:
		var de: InputEventScreenDrag = event as InputEventScreenDrag
		_touch_drag(de.index, de.position, de.relative)


func _touch_down(idx: int, pos: Vector2) -> void:
	var btns: Dictionary = _buttons()
	for bname in btns:
		var def: Array = btns[bname]
		var center: Vector2 = def[0]
		var rad: float = float(def[1])
		if pos.distance_to(center) <= rad * 1.25:
			btn_touch[idx] = bname
			pressed[bname] = true
			_press(String(bname))
			return
	if joy_id == -1 and pos.x < size.x * 0.45 and pos.y > size.y * 0.25:
		joy_id = idx
		joy_center = pos
		joy_vec = Vector2.ZERO
	elif cam_id == -1:
		cam_id = idx


func _press(bname: String) -> void:
	if bname == "attack":
		GameInput.attack_buffer = GameInput.ATTACK_BUFFER
	elif bname == "jump":
		GameInput.jump_buffer = GameInput.BUFFER_TIME
	elif bname == "dodge":
		GameInput.dodge_buffer = GameInput.BUFFER_TIME
	elif bname == "fly":
		GameInput.fly_buffer = GameInput.BUFFER_TIME
	elif bname == "divine":
		GameInput.divine_buffer = GameInput.BUFFER_TIME
	elif bname == "weapon":
		GameInput.weapon_buffer = GameInput.BUFFER_TIME
	elif bname == "heal":
		GameInput.heal_buffer = GameInput.BUFFER_TIME
	elif bname == "shoot":
		GameInput.shoot_buffer = GameInput.BUFFER_TIME
	elif bname == "powers":
		_reset()
		get_parent().call("open_powers")
	elif bname == "tp":
		GameInput.tp_buffer = GameInput.BUFFER_TIME
	elif bname == "ulti":
		GameInput.ulti_buffer = GameInput.BUFFER_TIME
	elif bname == "menu":
		_reset()
		get_parent().call("open_settings")


func _touch_up(idx: int) -> void:
	if idx == joy_id:
		joy_id = -1
		joy_vec = Vector2.ZERO
		GameInput.touch_move = Vector2.ZERO
	elif idx == cam_id:
		cam_id = -1
	elif btn_touch.has(idx):
		pressed[btn_touch[idx]] = false
		btn_touch.erase(idx)


func _touch_drag(idx: int, pos: Vector2, rel: Vector2) -> void:
	if idx == joy_id:
		joy_vec = ((pos - joy_center) / JOY_RADIUS).limit_length(1.0)
		GameInput.touch_move = joy_vec
	elif idx == cam_id:
		GameInput.cam_delta += rel * 0.7


func _process(_delta: float) -> void:
	GameInput.touch_jump_held = bool(pressed.get("jump", false))
	GameInput.touch_tp_held = bool(pressed.get("tp", false))
	GameInput.touch_attack_held = bool(pressed.get("attack", false))
	if enabled:
		queue_redraw()


func _draw() -> void:
	if not enabled:
		return
	var white: Color = Color(1.0, 1.0, 1.0, 0.55)
	var base: Vector2 = joy_center if joy_id != -1 else Vector2(130.0, size.y - 130.0)
	draw_circle(base, JOY_RADIUS, Color(1.0, 1.0, 1.0, 0.10))
	draw_arc(base, JOY_RADIUS, 0.0, TAU, 40, white, 2.0)
	draw_circle(base + joy_vec * JOY_RADIUS * 0.7, 34.0, Color(1.0, 1.0, 1.0, 0.35))
	var font: Font = ThemeDB.fallback_font
	var btns: Dictionary = _buttons()
	for bname in btns:
		var def: Array = btns[bname]
		var center: Vector2 = def[0]
		var rad: float = float(def[1])
		var on: bool = bool(pressed.get(bname, false))
		if (bname == "divine" and _divine_ready()) or (bname == "ulti" and _ulti_ready()):
			on = fmod(Time.get_ticks_msec() * 0.004, 2.0) < 1.0
		draw_circle(center, rad, Color(1.0, 0.85, 0.3, 0.45 if on else 0.18))
		draw_arc(center, rad, 0.0, TAU, 32, Color(1.0, 0.85, 0.3, 0.8), 2.0)
		draw_string(font, center + Vector2(-rad, 7.0), String(def[2]),
				HORIZONTAL_ALIGNMENT_CENTER, rad * 2.0, 18, Color(1.0, 1.0, 1.0, 0.9))


func _divine_ready() -> bool:
	var ps: Array = get_tree().get_nodes_in_group("player")
	if ps.is_empty():
		return false
	var p: Node = ps[0]
	return float(p.get("energy")) >= float(p.get("max_energy")) and not bool(p.get("is_divine"))


func _ulti_ready() -> bool:
	var ps: Array = get_tree().get_nodes_in_group("player")
	if ps.is_empty():
		return false
	return float(ps[0].get("ulti")) >= 100.0


## Libellé du bouton POUVOIR : nom court du pouvoir choisi, ou temps de recharge.
func _power_label() -> String:
	var ps: Array = get_tree().get_nodes_in_group("player") if is_inside_tree() else []
	if ps.is_empty():
		return "POUV."
	var p: Node = ps[0]
	var cd: float = float(p.get("power_cd"))
	if cd > 0.05:
		return "%.1f" % cd
	return String(p.call("power_short"))
