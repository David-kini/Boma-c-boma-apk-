extends Node
## Entrées unifiées : clavier (PC) et commandes tactiles (HUD). Autoload : GameInput.
## Clavier : ZQSD/WASD bouger, Maj courir, Espace sauter, C esquiver, J/Entrée/clic gauche attaquer,
## flèches ou clic droit + souris pour la caméra, Échap ou F1 : paramètres (géré par le HUD).

const BUFFER_TIME: float = 0.15
const ATTACK_BUFFER: float = 0.35

var touch_move: Vector2 = Vector2.ZERO   # joystick virtuel (x droite, y bas)
var cam_delta: Vector2 = Vector2.ZERO    # glissement accumulé pour la caméra
var jump_buffer: float = 0.0
var dodge_buffer: float = 0.0
var attack_buffer: float = 0.0
var fly_buffer: float = 0.0       # bouton VOL / touche F
var divine_buffer: float = 0.0    # bouton DIVIN / touche T
var weapon_buffer: float = 0.0    # bouton ARME / touche R
var heal_buffer: float = 0.0      # bouton SOIN / touche H
var shoot_buffer: float = 0.0     # bouton POUVOIR / touche G : pouvoir sélectionné
var powers_menu_buffer: float = 0.0  # bouton POUVOIRS / touche P : choisir le pouvoir
var touch_tp_held: bool = false   # bouton TP maintenu : téléportation ciblée
var touch_attack_held: bool = false  # bouton ATTAQUE maintenu : frappe chargée
var tp_buffer: float = 0.0        # bouton TP / touche V : téléportation
var ulti_buffer: float = 0.0      # bouton ULTI / touche U : attaque finale
var touch_jump_held: bool = false # bouton SAUT maintenu (écran tactile)
var zoom_delta: float = 0.0              # >0 = éloigner la caméra


func _process(delta: float) -> void:
	if jump_buffer > 0.0:
		jump_buffer -= delta
	if dodge_buffer > 0.0:
		dodge_buffer -= delta
	if attack_buffer > 0.0:
		attack_buffer -= delta
	fly_buffer = maxf(fly_buffer - delta, 0.0)
	divine_buffer = maxf(divine_buffer - delta, 0.0)
	weapon_buffer = maxf(weapon_buffer - delta, 0.0)
	heal_buffer = maxf(heal_buffer - delta, 0.0)
	shoot_buffer = maxf(shoot_buffer - delta, 0.0)
	tp_buffer = maxf(tp_buffer - delta, 0.0)
	ulti_buffer = maxf(ulti_buffer - delta, 0.0)
	powers_menu_buffer = maxf(powers_menu_buffer - delta, 0.0)
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
			elif ke.physical_keycode == KEY_F:
				fly_buffer = BUFFER_TIME
			elif ke.physical_keycode == KEY_T:
				divine_buffer = BUFFER_TIME
			elif ke.physical_keycode == KEY_R:
				weapon_buffer = BUFFER_TIME
			elif ke.physical_keycode == KEY_H:
				heal_buffer = BUFFER_TIME
			elif ke.physical_keycode == KEY_G:
				shoot_buffer = BUFFER_TIME
			elif ke.physical_keycode == KEY_V:
				tp_buffer = BUFFER_TIME
			elif ke.physical_keycode == KEY_U:
				ulti_buffer = BUFFER_TIME
			elif ke.physical_keycode == KEY_P:
				powers_menu_buffer = BUFFER_TIME
			elif ke.physical_keycode == KEY_J or ke.physical_keycode == KEY_ENTER:
				attack_buffer = ATTACK_BUFFER
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and not DisplayServer.is_touchscreen_available():
			attack_buffer = ATTACK_BUFFER
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
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


## Bouton d'attaque maintenu (Frappe du dragon, Frappe du météore en vol).
func attack_held() -> bool:
	if touch_attack_held:
		return true
	if Input.is_physical_key_pressed(KEY_J) or Input.is_physical_key_pressed(KEY_ENTER):
		return true
	return not DisplayServer.is_touchscreen_available() and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)


## Bouton de téléportation maintenu (mode ciblage).
func tp_held() -> bool:
	return touch_tp_held or Input.is_physical_key_pressed(KEY_V)


## Saut maintenu (saut plus haut / saut long en course).
func jump_held() -> bool:
	return touch_jump_held or Input.is_physical_key_pressed(KEY_SPACE)


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


func consume_attack() -> bool:
	if attack_buffer > 0.0:
		attack_buffer = 0.0
		return true
	return false
