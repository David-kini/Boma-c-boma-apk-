extends Node3D
## Scène principale : assemble le monde, le joueur, la caméra et le HUD.

const WORLD_SCENE: PackedScene = preload("res://scenes/World.tscn")
const PLAYER_SCENE: PackedScene = preload("res://scenes/Player.tscn")
const CAMERA_SCENE: PackedScene = preload("res://scenes/CameraRig.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/HUD.tscn")

var world: Node3D
var player: CharacterBody3D
var camera_rig: Node3D
var hud: CanvasLayer
var cinematic: Node3D


func _ready() -> void:
	world = WORLD_SCENE.instantiate() as Node3D
	add_child(world)

	player = PLAYER_SCENE.instantiate() as CharacterBody3D
	player.position = world.call("spawn_point")
	add_child(player)
	player.set("world", world)

	camera_rig = CAMERA_SCENE.instantiate() as Node3D
	camera_rig.position = player.position + Vector3(0.0, 1.5, 0.0)
	add_child(camera_rig)
	camera_rig.set("target", player)
	player.set("cam", camera_rig)
	world.set("follow", player)

	hud = HUD_SCENE.instantiate() as CanvasLayer
	add_child(hud)
	hud.call("setup", player, world)
	cinematic = load("res://scripts/cinematic.gd").new()
	cinematic.name = "Cinematique"
	add_child(cinematic)
	cinematic.call("setup", self)
	_dev_capture()


## Outil de développement : seulement si le jeu est lancé avec --capture=...
func _dev_capture() -> void:
	var args: Dictionary = {}
	for a in OS.get_cmdline_user_args():
		var s: String = a.trim_prefix("--")
		var kv: PackedStringArray = s.split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else ""
	if not args.has("capture") or args.has("title"):
		hud.call("show_title")      # écran titre (le jeu attend « JOUER »)
	if not args.has("capture"):
		return
	var cap: Node = load("res://scripts/dev_capture.gd").new()
	add_child(cap)
	cap.call("setup", player, camera_rig, args)
