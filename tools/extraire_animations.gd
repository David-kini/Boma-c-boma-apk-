extends SceneTree
## Outil (exécution : godot --headless --script res://tools/extraire_animations.gd)
## Extrait la bibliothèque d'animations du squelette humanoïde KayKit (75+ animations)
## vers Assets/Animations, réutilisable par tous les personnages KayKit.

func _init() -> void:
	var sources: Dictionary = {
		"res://Assets/Characters/Adventurers/Knight.glb": "res://Assets/Animations/KayKit_Aventuriers.res",
		"res://Assets/Characters/Skeletons/Skeleton_Warrior.glb": "res://Assets/Animations/KayKit_Squelettes.res",
	}
	for src in sources:
		var scene: PackedScene = load(src)
		var root: Node = scene.instantiate()
		var ap: AnimationPlayer = root.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if ap == null:
			print("PAS D'ANIMATIONPLAYER : ", src)
			continue
		var lib: AnimationLibrary = ap.get_animation_library("")
		var err: int = ResourceSaver.save(lib, sources[src])
		print(src, " -> ", sources[src], " : ", lib.get_animation_list().size(), " animations, erreur=", err)
		var sk: Skeleton3D = root.find_child("*", true, false) as Skeleton3D
		root.free()
	quit()
