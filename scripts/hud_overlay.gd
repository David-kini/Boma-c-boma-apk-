extends Control
## Commandes tactiles : joystick flottant (moitié gauche), glisser pour la caméra
## (moitié droite), boutons SAUT / ESQ. et Q (qualité graphique).
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
	set_anchors_preset(Control.PRESET_FULL_RECT)
	enabled = DisplayServer.is_touchscreen_available()


func _buttons() -> Dictionary:
	var s: Vector2 = size
	return {
		"jump": [Vector2(s.x - 120.0, s.y - 130.0), 56.0, "SAUT"],
		"dodge": [Vector2(s.x - 250.0, s.y - 80.0), 46.0, "ESQ."],
		"qual": [Vector2(s.x - 50.0, 50.0), 28.0, "Q"],
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


func _input(event: InputEvent) -> void:
	if not enabled:
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
	if bname == "jump":
		GameInput.jump_buffer = GameInput.BUFFER_TIME
	elif bname == "dodge":
		GameInput.dodge_buffer = GameInput.BUFFER_TIME
	elif bname == "qual":
		GameSettings.cycle_quality()


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
		draw_circle(center, rad, Color(1.0, 0.85, 0.3, 0.45 if on else 0.18))
		draw_arc(center, rad, 0.0, TAU, 32, Color(1.0, 0.85, 0.3, 0.8), 2.0)
		draw_string(font, center + Vector2(-rad, 7.0), String(def[2]),
				HORIZONTAL_ALIGNMENT_CENTER, rad * 2.0, 18, Color(1.0, 1.0, 1.0, 0.9))
