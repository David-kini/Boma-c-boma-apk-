extends Node
## Outil de développement (inactif en jeu normal) : capture d'écran automatique.
## Usage : godot -- --capture=/chemin/image.png [--view=hero|front|side|back|arena|forest|ruins|boss|volcano|monsters|lake]
## [--quality=0..3] [--anim=idle|walk|run|jump|fall|dodge|land] [--frames=N]

var path: String = ""
var view: String = "hero"
var anim: String = ""
var frames: int = 90
var player: Node3D
var cam: Node3D
var _n: int = 0


func setup(p: Node3D, c: Node3D, args: Dictionary) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	player = p
	cam = c
	path = String(args.get("capture", ""))
	view = String(args.get("view", "hero"))
	anim = String(args.get("anim", ""))
	frames = int(args.get("frames", "90"))
	if args.has("quality"):
		GameSettings.set_quality(int(args["quality"]))
	var spots: Dictionary = {
		"arena": Vector2(0.0, 30.0), "forest": Vector2(185.0, -170.0), "ruins": Vector2(-25.0, -140.0),
		"boss": Vector2(-245.0, -240.0), "volcano": Vector2(-190.0, 165.0), "monsters": Vector2(175.0, 200.0),
		"lake": Vector2(85.0, 85.0), "rocks": Vector2(225.0, 30.0), "village": Vector2(-95.0, 150.0), "camp": Vector2(18.0, 92.0),
		"peaks": Vector2(60.0, -250.0), "pines": Vector2(-290.0, -10.0), "dark": Vector2(-150.0, -60.0),
	}
	if spots.has(view):
		var s: Vector2 = spots[view]
		var w: Node = player.get("world")
		var y: float = float(w.call("ground_height", s.x, s.y)) + 0.5
		player.global_position = Vector3(s.x, y, s.y)
		var target: Vector2 = Vector2.ZERO if view != "arena" else Vector2(0.0, -40.0)
		var targets: Dictionary = {"forest": Vector2(215.0, -200.0), "ruins": Vector2(-40.0, -170.0), "boss": Vector2(-275.0, -265.0),
			"volcano": Vector2(-255.0, 215.0), "monsters": Vector2(195.0, 225.0), "lake": Vector2(118.0, 118.0),
			"rocks": Vector2(255.0, 35.0), "village": Vector2(-105.0, 110.0), "camp": Vector2(9.0, 78.0),
			"peaks": Vector2(115.0, -320.0), "pines": Vector2(-330.0, -25.0), "dark": Vector2(-175.0, -85.0)}
		if targets.has(view):
			target = targets[view]
		var d: Vector2 = target - s
		cam.set("yaw", atan2(-d.x, -d.y))
		cam.set("pitch", -0.12)
	if args.has("at"):
		var xz: PackedStringArray = String(args["at"]).split(",")
		var wa: Node = player.get("world")
		var ax: float = float(xz[0])
		var az: float = float(xz[1])
		player.global_position = Vector3(ax, float(wa.call("ground_height", ax, az)) + 0.3, az)
		cam.global_position = player.global_position + Vector3(0.0, 1.5, 0.0)
	if view == "front" or view == "side" or view == "back":
		cam.set("pitch", -0.08)
		cam.set("distance", 2.6)
		var yaw: float = PI
		if view == "side":
			yaw = PI * 0.5
		elif view == "back":
			yaw = 0.0
		cam.set("yaw", yaw)
	cam.set("auto_align", false)
	if args.has("dist"):
		cam.set("distance", float(args["dist"]))
		(cam.get("spring") as SpringArm3D).spring_length = float(args["dist"])
	if args.has("pitch"):
		cam.set("pitch", float(args["pitch"]))
	if args.has("yaw"):
		cam.set("yaw", float(args["yaw"]))
	if args.has("pivot"):
		cam.set("pivot_height", float(args["pivot"]))
		cam.global_position = player.global_position + Vector3(0.0, float(args["pivot"]), 0.0)
	if args.has("noshadow"):
		var wn: Node = player.get("world")
		(wn.get("sun") as DirectionalLight3D).shadow_enabled = false
	if args.has("sbias"):
		var bb: PackedStringArray = String(args["sbias"]).split(",")
		var wb: Node = player.get("world")
		var sl: DirectionalLight3D = wb.get("sun") as DirectionalLight3D
		sl.shadow_bias = float(bb[0])
		sl.shadow_normal_bias = float(bb[1])
	if args.has("nofill"):
		var wf: Node = player.get("world")
		(wf.get_node("LumiereAppoint") as DirectionalLight3D).visible = false
	if args.has("nosun"):
		var wn2: Node = player.get("world")
		(wn2.get("sun") as DirectionalLight3D).visible = false
	if args.has("fov"):
		(cam.get("camera") as Camera3D).fov = float(args["fov"])
	if anim != "":
		player.set("debug_anim", anim)
	if args.has("level"):
		player.set("level", int(args["level"]))
	if args.has("weapon"):
		player.call("_equip_weapon", int(args["weapon"]), false)
	if args.has("weather"):
		var wt: Node = player.get("world").get("weather")
		wt.set("forced", true)
		wt.call("set_weather", String(args["weather"]), true)
	if args.has("ulti"):
		player.set("ulti", 100.0)
		GameInput.ulti_buffer = 1.0
	if args.has("coat"):
		player.call("set_coat", String(args["coat"]))
	if args.has("wings"):
		player.call("set_wings", String(args["wings"]))
	if args.has("fly"):
		GameInput.fly_buffer = 1.0
	if args.has("divine"):
		player.set("energy", 100.0)
		GameInput.divine_buffer = 1.0
	if args.has("menu"):
		_open_menu_at = 25
	shoot_at = int(args.get("shoot", "-1"))
	if args.has("power"):
		player.set("power_index", load("res://scripts/powers.gd").call("index_of", String(args["power"])))
	powers_menu_at = 25 if args.has("powersmenu") else -1
	tp_hold = args.has("tphold")
	hold_attack = args.has("holdattack")
	tp_at = int(args.get("tp", "-1"))
	autoattack = args.has("autoattack")
	report = args.has("report")


var autoattack: bool = false
var shoot_at: int = -1
var powers_menu_at: int = -1
var tp_hold: bool = false
var hold_attack: bool = false
var tp_at: int = -1
var _open_menu_at: int = -1
var report: bool = false
var _log_t: float = 0.0


func _report() -> void:
	var txt: String = "BILAN niv=%d xp=%d vol=%s divin=%s " % [int(player.get("level")), int(player.get("xp")), str(player.get("is_flying")), str(player.get("is_divine"))]
	txt += "pos=%s joueur pv=%d etat=%s combo=%d energie=%d | ennemis:" % [
		str(player.global_position.snapped(Vector3(0.1, 0.1, 0.1))), int(player.get("hp")), String(player.get("state")), int(player.get("combo_count")), int(player.get("energy"))]
	for e in get_tree().get_nodes_in_group("enemies"):
		var en: Node3D = e as Node3D
		if en.global_position.distance_to(player.global_position) < 25.0:
			var mdl: Node3D = en.get("_model") as Node3D
			txt += " [%s pv=%d %s d=%.1f pos=%s vis=%s]" % [String(en.get("display_name")), int(en.get("hp")), String(en.get("state")),
				en.global_position.distance_to(player.global_position), str(en.global_position.snapped(Vector3(0.1, 0.1, 0.1))),
				str(mdl.is_visible_in_tree()) if mdl != null else "?"]
	print(txt)


func _process(delta: float) -> void:
	if autoattack or report:
		if autoattack:
			GameInput.attack_buffer = GameInput.ATTACK_BUFFER
		_log_t -= delta
		if _log_t <= 0.0:
			_log_t = 1.0
			_report()
	_n += 1
	if _n == shoot_at:
		GameInput.shoot_buffer = 0.2
	if _n == tp_at:
		GameInput.tp_buffer = 0.2
	if hold_attack:
		GameInput.touch_attack_held = true
		if _n == 5:
			GameInput.attack_buffer = 0.3
	if tp_hold:
		GameInput.touch_tp_held = true
		if _n == 8:
			GameInput.tp_buffer = 0.2
	if _n == powers_menu_at:
		get_parent().get("hud").call("open_powers")
	if _n == _open_menu_at:
		get_parent().get("hud").call("open_settings")
	if _n == frames:
		var img: Image = get_viewport().get_texture().get_image()
		img.save_png(path)
		print("CAPTURE OK ", path, " ", img.get_size(), " appels=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			" triangles=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
			" vram=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576)
		get_tree().quit()
