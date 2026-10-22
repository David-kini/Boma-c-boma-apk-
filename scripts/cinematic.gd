extends Node3D
## Cinématiques courtes (passables) : introduction « La chute du royaume » et fin.
## Caméra propre (Camera3D) animée par images-clés ; le héros est posé (poses du rig),
## les dialogues et le titre sont affichés par le HUD. Le contrôle revient au joueur à la fin.

const CombatFx = preload("res://scripts/combat_fx.gd")
const AD: String = "res://Assets/Characters/Adventurers/"

var main: Node = null
var player: Node3D = null
var world: Node3D = null
var hud: Node = null
var cam: Camera3D
var playing: String = ""
var _t: float = 0.0
var _keys: Array = []          # [temps, position, cible]
var _events: Array = []        # [temps, Callable]
var _ev_i: int = 0
var _length: float = 0.0
var _temp: Array = []          # nœuds créés pour la scène (supprimés à la fin)
var _movers: Array = []        # [nœud, départ, arrivée, t0, t1]
var _saved_sun: Vector3 = Vector3.ZERO


func setup(m: Node) -> void:
	main = m
	player = m.get("player")
	world = m.get("world")
	hud = m.get("hud")
	cam = Camera3D.new()
	cam.name = "CameraCinematique"
	cam.fov = 60.0
	cam.near = 0.05
	cam.far = 900.0
	add_child(cam)
	process_mode = Node.PROCESS_MODE_ALWAYS


# ------------------------------------------------------------ outils

func _key(t: float, pos: Vector3, look: Vector3) -> void:
	_keys.append([t, pos, look])


func _at(t: float, f: Callable) -> void:
	_events.append([t, f])


func _line(t: float, who: String, text: String, dur: float = 3.5) -> void:
	_at(t, func() -> void: hud.call("cine_line", who, text))
	_at(t + dur, func() -> void: hud.call("cine_line", "", ""))


func _g(x: float, z: float) -> float:
	return float(world.call("ground_height", x, z))


func _npc(path: String, pos: Vector3, look_at_pos: Vector3, anim: String, scale: float, keep: Array, tint: Color = Color(1, 1, 1)) -> Node3D:
	var n: Node3D = Node3D.new()
	var model: Node3D = (load(path) as PackedScene).instantiate() as Node3D
	n.add_child(model)
	model.scale = Vector3.ONE * scale
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m3: MeshInstance3D = mi as MeshInstance3D
		if not (m3.get_parent() is Skeleton3D) and not keep.has(String(m3.name)):
			m3.visible = false
		if tint != Color(1, 1, 1) and m3.mesh != null:
			for si in range(m3.mesh.get_surface_count()):
				var base: Material = m3.get_active_material(si)
				if base is StandardMaterial3D:
					var dm: StandardMaterial3D = (base as StandardMaterial3D).duplicate() as StandardMaterial3D
					dm.albedo_color = dm.albedo_color * tint
					m3.set_surface_override_material(si, dm)
	add_child(n)
	n.global_position = pos
	var d: Vector3 = look_at_pos - pos
	n.rotation.y = atan2(d.x, d.z)          # les modèles KayKit regardent vers +Z
	var ap: AnimationPlayer = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap != null and ap.has_animation(anim):
		ap.get_animation(anim).loop_mode = Animation.LOOP_LINEAR
		ap.play(anim)
	n.set_meta("ap", ap)
	_temp.append(n)
	return n


func _play_anim(n: Node3D, anim: String) -> void:
	var ap: AnimationPlayer = n.get_meta("ap", null)
	if ap != null and ap.has_animation(anim):
		ap.get_animation(anim).loop_mode = Animation.LOOP_LINEAR
		ap.play(anim, 0.2)


func _fire(pos: Vector3, s: float) -> void:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(1.0, 0.45, 0.1, 0.8)
	for k in range(3):
		var f: MeshInstance3D = MeshInstance3D.new()
		var sm: SphereMesh = SphereMesh.new()
		sm.radius = s * (1.0 - 0.25 * float(k))
		sm.height = sm.radius * 2.8
		sm.radial_segments = 6
		sm.rings = 4
		f.mesh = sm
		f.material_override = m
		f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(f)
		f.global_position = pos + Vector3(randf_range(-1.0, 1.0) * s, s * (0.8 + float(k)), randf_range(-1.0, 1.0) * s)
		_temp.append(f)
	var smoke: MeshInstance3D = MeshInstance3D.new()
	var sm2: SphereMesh = SphereMesh.new()
	sm2.radius = s * 2.0
	sm2.height = s * 4.0
	sm2.radial_segments = 6
	sm2.rings = 4
	smoke.mesh = sm2
	var ms: StandardMaterial3D = StandardMaterial3D.new()
	ms.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ms.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ms.albedo_color = Color(0.15, 0.13, 0.12, 0.45)
	smoke.material_override = ms
	smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(smoke)
	smoke.global_position = pos + Vector3(0.0, s * 6.0, 0.0)
	_temp.append(smoke)


func _begin(id: String) -> void:
	playing = id
	_t = 0.0
	_keys.clear()
	_events.clear()
	_movers.clear()
	_ev_i = 0
	cam.make_current()
	player.set_physics_process(false)
	player.velocity = Vector3.ZERO
	hud.call("cine_begin")
	Engine.time_scale = 1.0


func _finish() -> void:
	for n in _temp:
		if is_instance_valid(n):
			n.queue_free()
	_temp.clear()
	_reset_hero()
	var rig_cam: Camera3D = main.get("camera_rig").get("camera") as Camera3D
	rig_cam.make_current()
	main.get("camera_rig").global_position = player.global_position + Vector3(0.0, 1.5, 0.0)
	hud.call("cine_end")
	var w: Node = world.get("weather")
	if w != null:
		w.set("forced", false)
		w.call("dim", 0.0)
	if _saved_sun != Vector3.ZERO:
		(world.get("sun") as DirectionalLight3D).rotation_degrees = _saved_sun
		_saved_sun = Vector3.ZERO
	var was: String = playing
	playing = ""
	if was == "intro":
		player.call("mark_story", "intro_vue")
	elif was == "fin":
		player.call("mark_story", "fin_vue")


## Remet le héros debout et jouable, quelle que soit la façon dont la scène s'est arrêtée
## (fin normale ou bouton « Passer ») : plus de pose de méditation qui reste.
func _reset_hero() -> void:
	player.set("debug_anim", "")
	player.set("state", "idle")
	player.set("_pose_t", 0.0)
	player.set("_atk_i", -1)
	player.set("action", "")
	player.set("invulnerable", false)
	player.velocity = Vector3.ZERO
	var rg: Node3D = player.get("rig") as Node3D
	if rg != null:
		rg.rotation = Vector3(0.0, float(player.get("face_yaw")), 0.0)
		rg.position = Vector3.ZERO
		rg.call("animate", 0.0, "idle", 0.0)
	player.set_physics_process(true)
	player.set_process(true)
	Engine.time_scale = 1.0
	get_tree().paused = false


func skip() -> void:
	if playing != "":
		_finish()


func _process(delta: float) -> void:
	if playing == "":
		return
	_t += delta
	while _ev_i < _events.size() and _t >= float(_events[_ev_i][0]):
		(_events[_ev_i][1] as Callable).call()
		_ev_i += 1
		if playing == "":
			return
	# caméra : interpolation douce entre images-clés
	if _keys.size() > 0:
		var i: int = 0
		while i < _keys.size() - 1 and _t > float(_keys[i + 1][0]):
			i += 1
		var a: Array = _keys[i]
		var b: Array = _keys[mini(i + 1, _keys.size() - 1)]
		var span: float = maxf(float(b[0]) - float(a[0]), 0.001)
		var k: float = smoothstep(0.0, 1.0, clampf((_t - float(a[0])) / span, 0.0, 1.0))
		var pos: Vector3 = (a[1] as Vector3).lerp(b[1] as Vector3, k)
		var look: Vector3 = (a[2] as Vector3).lerp(b[2] as Vector3, k)
		cam.global_position = pos
		if pos.distance_to(look) > 0.01:
			cam.look_at(look, Vector3.UP)
	for mv in _movers:
		var n: Node3D = mv[0]
		if is_instance_valid(n):
			var kk: float = clampf((_t - float(mv[3])) / (float(mv[4]) - float(mv[3])), 0.0, 1.0)
			n.global_position = (mv[1] as Vector3).lerp(mv[2] as Vector3, kk)
	if _t >= _length:
		_finish()


# ------------------------------------------------------------ introduction

func play_intro() -> void:
	_begin("intro")
	_length = 23.0
	var hero: Vector3 = Vector3(0.0, 0.1, -6.0)
	player.global_position = hero
	player.set("face_yaw", PI)          # regarde vers +Z (la caméra arrive de face)
	(player.get("rig") as Node3D).rotation.y = PI
	player.set("debug_anim", "meditate")
	var w: Node = world.get("weather")
	if w != null:
		w.set("forced", true)
		w.call("set_weather", "soleil", true)
		w.call("dim", 0.3)
	# village en flammes
	var v: Vector2 = Vector2(-105.0, 110.0)
	for k in range(7):
		var a: float = float(k) / 7.0 * TAU
		var fp: Vector2 = v + Vector2(cos(a), sin(a)) * randf_range(8.0, 22.0)
		_fire(Vector3(fp.x, _g(fp.x, fp.y), fp.y), 1.6)
	# 1. survol du royaume : montagnes, forêt brumeuse, village qui brûle
	_key(0.0, Vector3(220.0, 120.0, -150.0), Vector3(115.0, 60.0, -320.0))
	_key(4.0, Vector3(40.0, 90.0, -40.0), Vector3(-175.0, 0.0, -85.0))
	_key(8.0, Vector3(-60.0, 45.0, 60.0), Vector3(-105.0, 5.0, 110.0))
	_line(0.5, "", "Le royaume de Boma vivait en paix, entouré de ses montagnes…", 3.5)
	_line(4.3, "", "… jusqu'au jour où des créatures sombres envahirent le village.", 3.5)
	# 2. la caméra descend vers l'arène, le temple du clan
	_key(11.0, Vector3(4.0, 3.0, 2.0), hero + Vector3(0.0, 0.8, 0.0))
	_line(8.4, "", "Dans la Grande Arène, le dernier gardien du clan médite.", 3.0)
	# 3. explosion, apparition du guerrier masqué
	var masked_pos: Vector3 = Vector3(0.0, 0.1, -11.0)
	_at(11.5, func() -> void:
		CombatFx.ring(self, masked_pos + Vector3(0.0, 0.2, 0.0), Color(1.0, 0.4, 0.1), 6.0, 0.5)
		for k2 in range(6):
			var a2: float = float(k2) / 6.0 * TAU
			CombatFx.spark(self, masked_pos + Vector3(cos(a2) * 2.0, 1.0, sin(a2) * 2.0), Color(1.0, 0.5, 0.2), 2.0)
		Sfx.play("ulti_boom", 0.8)
		var masked: Node3D = _npc(AD + "Rogue.glb", masked_pos, hero, "2H_Melee_Idle", 1.3, ["Knife", "Rogue_Cape"], Color(0.17, 0.15, 0.22))
		masked.name = "GuerrierMasque")
	_key(12.5, hero + Vector3(1.2, 1.6, 1.6), masked_pos + Vector3(0.0, 1.2, 0.0))
	_line(12.6, "Guerrier masqué", "« Le sceau est brisé. Ton clan n'a plus que quelques heures. »", 4.0)
	# 4. le héros saisit son épée et se relève ; gros plan sur les yeux, puis rotation
	_at(16.8, func() -> void:
		player.set("debug_anim", "guard")
		for k3 in range(5):
			CombatFx.spark(self, hero + Vector3(0.3, 1.2 + 0.2 * float(k3), -0.5 - 0.15 * float(k3)), Color(0.6, 0.85, 1.0), 0.5)
		Sfx.play("divine", 1.2))
	_key(16.6, hero + Vector3(1.2, 1.6, 1.6), masked_pos + Vector3(0.0, 1.2, 0.0))
	_key(17.4, hero + Vector3(0.15, 1.66, 0.95), hero + Vector3(0.0, 1.62, 0.0))
	_key(18.4, hero + Vector3(0.1, 1.66, 0.85), hero + Vector3(0.0, 1.62, 0.0))
	_key(19.6, hero + Vector3(2.6, 1.4, -1.0), hero + Vector3(0.0, 1.2, 0.0))
	_key(20.8, hero + Vector3(0.5, 1.8, -3.2), hero + Vector3(0.0, 1.1, 0.0))
	# 5. titre ; le guerrier masqué disparaît
	_at(19.8, func() -> void:
		hud.call("cine_title", "SHADOW NINJA", "LA GUERRE DES ROYAUMES", 3.0)
		for n in _temp:
			if is_instance_valid(n) and n.name == "GuerrierMasque":
				CombatFx.spark(self, n.global_position + Vector3(0.0, 1.0, 0.0), Color(0.5, 0.4, 0.7), 2.0)
				n.visible = false)
	_key(23.0, hero + Vector3(0.0, 2.6, -5.2), hero + Vector3(0.0, 1.2, 0.0))
	_at(22.6, func() -> void:
		player.set("face_yaw", 0.0)
		if w != null:
			w.call("dim", 0.0))


# ------------------------------------------------------------ fin

func play_ending() -> void:
	_begin("fin")
	_length = 36.0
	var hero: Vector3 = Vector3(0.0, 0.1, 10.0)
	player.global_position = hero
	player.set("face_yaw", 0.0)
	(player.get("rig") as Node3D).rotation.y = 0.0
	player.set("debug_anim", "plant")
	var w: Node = world.get("weather")
	if w != null:
		w.set("forced", true)
		w.call("set_weather", "soleil", true)
		w.call("flash", 1.0)
	# lever de soleil : soleil bas et chaud
	var sun: DirectionalLight3D = world.get("sun") as DirectionalLight3D
	_saved_sun = sun.rotation_degrees
	sun.rotation_degrees = Vector3(-12.0, -10.0, 0.0)
	_line(0.3, "", "Le dernier seigneur des ténèbres s'effondre. Les ombres quittent le royaume.", 3.6)
	# survol des montagnes, de la forêt et du village libérés
	_key(0.0, Vector3(150.0, 110.0, -180.0), Vector3(115.0, 50.0, -320.0))
	_key(4.0, Vector3(150.0, 70.0, -120.0), Vector3(215.0, 0.0, -200.0))
	_key(8.0, Vector3(-40.0, 40.0, 60.0), Vector3(-105.0, 5.0, 110.0))
	_line(4.2, "", "Les montagnes, la forêt et les villages sont libérés.", 3.4)
	# le héros, l'épée plantée dans le sol, regarde le soleil se lever
	_key(11.0, hero + Vector3(3.5, 1.4, 3.0), hero + Vector3(0.0, 1.0, 0.0))
	var child_start: Vector3 = hero + Vector3(-6.0, 0.0, 4.0)
	var child_end: Vector3 = hero + Vector3(-2.3, 0.0, 1.8)
	var kid: Node3D = _npc(AD + "Mage.glb", child_start, hero, "Walking_A", 0.75, ["Mage_Hat"])
	kid.visible = false
	_at(12.0, func() -> void:
		kid.visible = true
		_movers.append([kid, child_start, child_end, 12.0, 15.0]))
	_at(15.0, func() -> void: _play_anim(kid, "Idle"))
	_key(15.5, hero + Vector3(-0.2, 1.5, 3.2), (hero + child_end) * 0.5 + Vector3(0.0, 1.0, 0.0))
	_line(15.6, "Enfant", "« Maintenant que la guerre est terminée, qui protégera le royaume ? »", 3.8)
	_at(19.6, func() -> void: player.set("debug_anim", "guard"))
	_key(19.4, hero + Vector3(-0.2, 1.5, 3.2), (hero + child_end) * 0.5 + Vector3(0.0, 1.0, 0.0))
	_key(20.2, hero + Vector3(2.2, 1.6, -0.9), hero + Vector3(-0.6, 1.4, 0.4))
	_line(19.8, "Le héros", "« Tant qu'il existera des ténèbres, quelqu'un devra se dresser contre elles. »", 4.0)
	# il marche vers les montagnes ; la caméra s'éloigne
	_at(24.0, func() -> void:
		player.set("debug_anim", "walk")
		player.set("face_yaw", 0.0)
		_movers.append([player, hero, hero + Vector3(0.0, 0.0, -12.0), 24.0, 29.0]))
	_key(24.0, hero + Vector3(2.2, 1.6, -0.9), hero + Vector3(-0.6, 1.4, 0.4))
	_key(29.0, hero + Vector3(0.0, 9.0, 14.0), hero + Vector3(0.0, 1.0, -10.0))
	_at(28.0, func() -> void: hud.call("cine_fade", 1.0, 1.0))
	_at(29.2, func() -> void: hud.call("cine_title", "FIN", "MAIS LES OMBRES N'ONT PAS DISPARU.", 3.6))
	# scène supplémentaire : une silhouette ouvre les yeux dans un temple lointain
	var temple: Vector3 = Vector3(-175.0, 0.0, -85.0)
	temple.y = _g(temple.x, temple.z)
	var eyes: Array = []
	_at(32.8, func() -> void:
		hud.call("cine_fade", 0.0, 0.6)
		player.global_position = hero
		var shade: Node3D = _npc(AD + "Rogue.glb", temple + Vector3(0.0, 0.2, 0.0), temple + Vector3(0.0, 0.0, 6.0), "Idle", 1.4, ["Rogue_Cape"], Color(0.05, 0.04, 0.07))
		shade.name = "Silhouette"
		var em: StandardMaterial3D = StandardMaterial3D.new()
		em.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		em.albedo_color = Color(1.0, 0.1, 0.1)
		for side in [-1.0, 1.0]:
			var e: MeshInstance3D = MeshInstance3D.new()
			var sm: SphereMesh = SphereMesh.new()
			sm.radius = 0.07
			sm.height = 0.14
			e.mesh = sm
			e.material_override = em
			add_child(e)
			e.global_position = temple + Vector3(0.15 * float(side), 2.42, 0.55)
			e.scale = Vector3(1.0, 0.05, 1.0)
			eyes.append(e)
			_temp.append(e)
		if w != null:
			w.call("dim", 0.7))
	_key(32.79, hero + Vector3(0.0, 9.0, 14.0), hero + Vector3(0.0, 1.0, -10.0))
	_key(32.8, temple + Vector3(0.0, 2.2, 6.0), temple + Vector3(0.0, 1.9, 0.0))
	_key(35.5, temple + Vector3(0.0, 2.1, 3.2), temple + Vector3(0.0, 2.0, 0.0))
	_at(34.3, func() -> void:
		for e in eyes:
			if is_instance_valid(e):
				var tw: Tween = (e as Node3D).create_tween()
				tw.tween_property(e, "scale", Vector3.ONE, 0.5)
		Sfx.play("thunder", 0.6))
