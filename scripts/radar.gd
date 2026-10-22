extends Control
## Radar rond (en haut à droite) : ennemis proches en rouge, boss en orange, plus une flèche
## qui montre où se trouve le prochain boss à vaincre, avec la distance en mètres.
## Le haut du radar = la direction où regarde la caméra.

const WorldData = preload("res://scripts/world_data.gd")
const R: float = 78.0              # rayon du radar à l'écran
const RANGE_M: float = 90.0        # portée du radar en mètres
## [clé de l'histoire, nom, position x, z]
const BOSSES: Array = [
	["boss_roi", "Roi Squelette", "boss", Vector2(0.0, 8.0)],
	["boss_ombre", "Seigneur des ombres", "bois_sombre", Vector2(0.0, 4.0)],
	["boss_reine", "Reine de la forêt", "foret", Vector2(0.0, 12.0)],
	["boss_gardien", "Gardien des montagnes", "peaks", Vector2(5.0, 14.0)],
	["boss_nuages", "Seigneur des nuages", "peaks", Vector2(-10.0, -40.0)],
]

var player: Node3D = null
var _font: Font = null
var _tick: float = 0.0
var _enemies: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -(R * 2.0 + 24.0)
	offset_right = -12.0
	offset_top = 12.0
	offset_bottom = R * 2.0 + 60.0
	_font = ThemeDB.fallback_font


func boss_pos(i: int) -> Vector2:
	var b: Array = BOSSES[i]
	var base: Vector2 = WorldData.PEAKS_CENTER if String(b[2]) == "peaks" else WorldData.ZONES[String(b[2])]["center"]
	return base + (b[3] as Vector2)


## Boss non vaincu le plus proche : [indice, distance] ou [-1, 0].
func nearest_boss() -> Array:
	if player == null:
		return [-1, 0.0]
	var st: Array = player.get("story")
	var pp: Vector2 = Vector2(player.global_position.x, player.global_position.z)
	var best: int = -1
	var bd: float = 1e9
	for i in range(BOSSES.size()):
		if st.has(String(BOSSES[i][0])):
			continue
		var d: float = pp.distance_to(boss_pos(i))
		if d < bd:
			bd = d
			best = i
	return [best, bd]


func _process(delta: float) -> void:
	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.3
		_enemies = get_tree().get_nodes_in_group("enemies")
	visible = player != null and not bool(player.get("is_dead"))
	if visible:
		queue_redraw()


func _draw() -> void:
	if player == null:
		return
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return
	var c: Vector2 = Vector2(R + 4.0, R + 4.0)
	var fwd: Vector2 = Vector2(-cam.global_transform.basis.z.x, -cam.global_transform.basis.z.z).normalized()
	var rgt: Vector2 = Vector2(cam.global_transform.basis.x.x, cam.global_transform.basis.x.z).normalized()
	draw_circle(c, R, Color(0.02, 0.04, 0.08, 0.55))
	draw_arc(c, R, 0.0, TAU, 48, Color(0.8, 0.7, 0.35, 0.9), 2.0)
	draw_arc(c, R * 0.5, 0.0, TAU, 32, Color(1, 1, 1, 0.12), 1.0)
	var pp: Vector2 = Vector2(player.global_position.x, player.global_position.z)
	# ennemis
	for e in _enemies:
		var en: Node3D = e as Node3D
		if en == null or not is_instance_valid(en) or String(en.get("state")) == "dead":
			continue
		var d: Vector2 = Vector2(en.global_position.x, en.global_position.z) - pp
		if d.length() > RANGE_M:
			continue
		var s: Vector2 = Vector2(d.dot(rgt), -d.dot(fwd)) * (R / RANGE_M)
		var boss: bool = bool(en.get("is_boss")) or String(en.get("boss_kind")) == "dragon"
		draw_circle(c + s, 5.0 if boss else 2.6, Color(1.0, 0.6, 0.1) if boss else Color(1.0, 0.2, 0.2, 0.9))
	# le joueur : petit triangle vers le haut
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -6), c + Vector2(5, 5), c + Vector2(-5, 5)]), Color(0.4, 1.0, 0.6))
	# flèche vers le boss à vaincre
	var nb: Array = nearest_boss()
	var txt: String = "Tous les boss vaincus"
	if int(nb[0]) >= 0:
		var tgt: Vector2 = boss_pos(int(nb[0]))
		var dv: Vector2 = tgt - pp
		var dist: float = dv.length()
		var s2: Vector2 = Vector2(dv.dot(rgt), -dv.dot(fwd)).normalized()
		var col: Color = Color(1.0, 0.75, 0.1)
		var tip: Vector2 = c + s2 * (R + 2.0) if dist * (R / RANGE_M) > R - 8.0 else c + Vector2(dv.dot(rgt), -dv.dot(fwd)) * (R / RANGE_M)
		if dist * (R / RANGE_M) > R - 8.0:
			var side: Vector2 = Vector2(-s2.y, s2.x)
			draw_colored_polygon(PackedVector2Array([tip + s2 * 4.0, tip - s2 * 12.0 + side * 9.0, tip - s2 * 12.0 - side * 9.0]), col)
		else:
			draw_circle(tip, 6.0, col)
		txt = "%s  %d m" % [String(BOSSES[int(nb[0])][1]), int(dist)]
	draw_string(_font, Vector2(-40.0, R * 2.0 + 22.0), txt, HORIZONTAL_ALIGNMENT_RIGHT, R * 2.0 + 44.0, 12, Color(1.0, 0.9, 0.5))
