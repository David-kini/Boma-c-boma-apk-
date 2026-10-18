extends Node3D
## Personnage non joueur animé (modèles CC0 KayKit, déjà riggés, 75 à 95 animations).
## Joue une animation en boucle ; l'animation et l'affichage s'arrêtent quand le joueur
## est loin (économie de processeur et de GPU sur Android).

@export var model_path: String = ""
@export var animation: String = "Idle"
@export var active_distance: float = 70.0

var _ap: AnimationPlayer = null
var _model: Node3D = null
var _check: float = 0.0


func _ready() -> void:
	if not ResourceLoader.exists(model_path):
		push_warning("PNJ : modèle introuvable " + model_path)
		return
	_model = (load(model_path) as PackedScene).instantiate() as Node3D
	add_child(_model)
	_ap = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _ap != null and _ap.has_animation(animation):
		var anim: Animation = _ap.get_animation(animation)
		anim.loop_mode = Animation.LOOP_LINEAR
		_ap.play(animation)
		# départ décalé : les PNJ ne bougent pas tous en même temps
		_ap.seek(randf() * anim.length, true)
	_set_vis(self)


func _set_vis(n: Node) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).visibility_range_end = active_distance + 10.0
	for c in n.get_children():
		_set_vis(c)


func _process(delta: float) -> void:
	_check -= delta
	if _check > 0.0 or _ap == null:
		return
	_check = 0.5
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return
	var near: bool = cam.global_position.distance_to(global_position) < active_distance
	if near and not _ap.is_playing():
		_ap.play(animation)
	elif not near and _ap.is_playing():
		_ap.pause()
