extends Node
## Entrées unifiées : clavier (PC) et commandes tactiles (HUD). Autoload : GameInput.
## Clavier : ZQSD/WASD bouger, Maj courir, Espace sauter, C esquiver,
## flèches ou clic droit + souris pour la caméra, Échap ou F1 : paramètres (géré par le HUD).

const BUFFER_TIME: float = 0.15

var touch_move: Vector2 = Vector2.ZERO   # joystick virtuel (x droite, y bas)
var cam_delta: Vector2 = Vector2.ZERO    # glissement accumulé pour la caméra
var jump_buffer: float = 0.0
var dodge_buffer: float = 0.0
var zoom_delta: float = 0.0              # >0 = éloigner la caméra


func _process(delta: float) -> void:
	if jump_buffer > 0.0:
		jump_buffer -= delta
	if dodge_buffer > 0.0:
		dodge_buffer -= delta
	var k: Vector2 = Vector2(
		float(Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_LEFT)),
		float(Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_UP))
	)
	cam_delta += k * 260.0 * delta


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var ke: InputEventKey = event as InputEventKey
		if ke.pressed and not ke.echo:
			if ke.physical_keycode == KEY_SPACE:
				jump_buffer = BUFFER_TIME
			elif ke.physical_keycode == KEY_C:
				dodge_buffer = BUFFER_TIME
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_delta -= 0.4
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_delta += 0.4
	elif event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		if (mm.button_mask & MOUSE_BUTTON_MASK_RIGHT) != 0:
			cam_delta += mm.relative


func get_move() -> Vector2:
	if touch_move.length() > 0.08:
		return touch_move
	var v: Vector2 = Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	)
	return v.limit_length(1.0)


func wants_run() -> bool:
	if touch_move.length() > 0.08:
		return touch_move.length() > 0.65
	return Input.is_physical_key_pressed(KEY_SHIFT)


func consume_jump() -> bool:
	if jump_buffer > 0.0:
		jump_buffer = 0.0
		return true
	return false


func consume_dodge() -> bool:
	if dodge_buffer > 0.0:
		dodge_buffer = 0.0
		return true
	return false


func consume_cam() -> Vector2:
	var d: Vector2 = cam_delta
	cam_delta = Vector2.ZERO
	return d


func consume_zoom() -> float:
	var z: float = zoom_delta
	zoom_delta = 0.0
	return z
