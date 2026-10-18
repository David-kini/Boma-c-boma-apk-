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
