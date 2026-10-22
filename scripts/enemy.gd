extends CharacterBody3D
## Ennemi (modèles CC0 KayKit riggés : squelettes, barbare, assassin, sorcier, boss).
## Corps à corps ou à distance (boules de feu). Le boss a 3 phases : invocations puis
## onde de choc annoncée par un cercle rouge au sol. Lâche de l'or et des potions.
## États : repos -> poursuite -> attaque (préparation visible, coup, récupération)
##         touché (étourdi) -> mort. Barre de vie au-dessus de la tête.
## Il "dort" (aucun calcul) quand le joueur est à plus de 60 m.

signal died(enemy: Node)

const CombatFx = preload("res://scripts/combat_fx.gd")
const Projectile = preload("res://scripts/projectile.gd")
const Loot = preload("res://scripts/loot.gd")
const BLADE: String = "res://Assets/Characters/Skeletons/Weapons/Skeleton_Blade.gltf"
const GRAVITY: float = 22.0
const SLEEP_DIST: float = 60.0

@export var model_path: String = "res://Assets/Characters/Skeletons/Skeleton_Warrior.glb"
@export var max_hp: float = 60.0
@export var damage: float = 8.0
@export var speed: float = 3.3
@export var detect_radius: float = 16.0
@export var attack_range: float = 1.8
@export var model_scale: float = 1.3
@export var display_name: String = "Squelette"
@export var xp_value: int = 10
@export var weapon_path: String = BLADE
@export var attack_anim: String = "1H_Melee_Attack_Chop"
@export var hit_time: float = 0.55          # instant du coup dans l'animation (s)
@export var attack_time: float = 1.05       # durée totale de l'attaque (s)
@export var ranged: bool = false            # sorcier : boules de feu à distance
@export var is_boss: bool = false
@export var fire_color: Color = Color(1.0, 0.45, 0.1)
## Modèles aventuriers : ils portent tous leurs accessoires ; on ne garde que ceux-ci.
@export var keep_props: PackedStringArray = PackedStringArray()
@export var tint: Color = Color(1, 1, 1)   # teinte "ennemie" (assombrit le modèle)
## Ennemi volant (ailes de démon) : vole à la hauteur du joueur et peut le frapper en vol.
@export var flying: bool = false
## Boss de région : "" (Roi Squelette), "gardien", "reine", "ombre", "nuages".
@export var boss_kind: String = ""
@export var illusion: bool = false          # illusion de la Reine de la forêt

var hp: float = 60.0
var state: String = "idle"
var player: Node3D = null
var world: Node3D = null          # pour la hauteur exacte du terrain (sécurité)
var _t: float = 0.0
var _hit_done: bool = false
var _cooldown: float = 0.0
var _ap: AnimationPlayer = null
var _model: Node3D = null
var _bar_fg: MeshInstance3D = null
var _bar_root: Node3D = null
var _cur_anim: String = ""
var phase: int = 1
var _special_cd: float = 4.0
var _ring: MeshInstance3D = null
var _air_hold: float = 0.0     # maintenu en l'air (combo d'exécution aérienne)
var _illusions: Array = []
var _blinks: int = 0           # Seigneur des ombres : frappes éclairs restantes
var _tele: MeshInstance3D = null
var _tele_pos: Vector3 = Vector3.ZERO


func _ready() -> void:
	add_to_group("enemies")
	if is_boss:
		add_to_group("boss")
	hp = max_hp
	collision_layer = 4
	collision_mask = 1 | 2 | 4
	var cs: CollisionShape3D = CollisionShape3D.new()
	var cap: CapsuleShape3D = CapsuleShape3D.new()
	cap.radius = 0.38 * model_scale / 1.3
	cap.height = 1.7 * model_scale / 1.3
	cs.shape = cap
	cs.position = Vector3(0.0, cap.height * 0.5, 0.0)
	add_child(cs)
	_model = (load(model_path) as PackedScene).instantiate() as Node3D
	_model.rotation.y = PI          # les modèles glTF regardent vers +Z, nous vers -Z
	_model.scale = Vector3.ONE * model_scale
	add_child(_model)
	_ap = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for a in ["Idle", "Idle_Combat", "Running_A", "Running_B", "Walking_D_Skeletons", "2H_Melee_Idle"]:
		if _ap != null and _ap.has_animation(a):
			_ap.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	_attach_weapon()
	if flying:
		_attach_wings()
	_build_bar()
	_play("Idle")


func _attach_weapon() -> void:
	var sk: Skeleton3D = null
	for n in _model.find_children("*", "Skeleton3D", true, false):
		sk = n as Skeleton3D
		break
	if sk == null or sk.find_bone("handslot.r") < 0:
		return
	if not keep_props.is_empty():
		for mi in _model.find_children("*", "MeshInstance3D", true, false):
			var m3: MeshInstance3D = mi as MeshInstance3D
			if m3.get_parent() is Skeleton3D:
				continue          # corps
			if not keep_props.has(String(m3.name)):
				m3.visible = false
	if tint != Color(1, 1, 1):
		for mi2 in _model.find_children("*", "MeshInstance3D", true, false):
			var g: MeshInstance3D = mi2 as MeshInstance3D
			if g.mesh == null:
				continue
			for si in range(g.mesh.get_surface_count()):
				var base: Material = g.get_active_material(si)
				if base is StandardMaterial3D:
					var dm: StandardMaterial3D = (base as StandardMaterial3D).duplicate() as StandardMaterial3D
					dm.albedo_color = dm.albedo_color * tint
					g.set_surface_override_material(si, dm)
	if weapon_path != "" and ResourceLoader.exists(weapon_path):
		var att: BoneAttachment3D = BoneAttachment3D.new()
		sk.add_child(att)
		att.bone_name = "handslot.r"
		att.add_child((load(weapon_path) as PackedScene).instantiate())
	if is_boss and boss_kind == "" and sk.find_bone("head") >= 0:
		# couronne dorée du Roi Squelette
		var ha: BoneAttachment3D = BoneAttachment3D.new()
		sk.add_child(ha)
		ha.bone_name = "head"
		var gold: StandardMaterial3D = StandardMaterial3D.new()
		gold.albedo_color = Color(1.0, 0.78, 0.2)
		gold.metallic = 0.7
		gold.roughness = 0.3
		gold.emission_enabled = true
		gold.emission = Color(0.6, 0.4, 0.05)
		var band: MeshInstance3D = MeshInstance3D.new()
		var cm: CylinderMesh = CylinderMesh.new()
		cm.top_radius = 0.42
		cm.bottom_radius = 0.38
		cm.height = 0.18
		band.mesh = cm
		band.material_override = gold
		band.position = Vector3(0.0, 0.85, 0.0)
		ha.add_child(band)
		for k in range(6):
			var a: float = float(k) / 6.0 * TAU
			var spike: MeshInstance3D = MeshInstance3D.new()
			var sp: CylinderMesh = CylinderMesh.new()
			sp.top_radius = 0.0
			sp.bottom_radius = 0.09
			sp.height = 0.28
			sp.radial_segments = 4
			spike.mesh = sp
			spike.material_override = gold
			spike.position = Vector3(cos(a) * 0.38, 1.05, sin(a) * 0.38)
			ha.add_child(spike)


func _attach_wings() -> void:
	var sk: Skeleton3D = null
	for n in _model.find_children("*", "Skeleton3D", true, false):
		sk = n as Skeleton3D
		break
	if sk == null:
		return
	var bone: String = "chest" if sk.find_bone("chest") >= 0 else ("spine" if sk.find_bone("spine") >= 0 else "")
	if bone == "":
		return
	var att: BoneAttachment3D = BoneAttachment3D.new()
	sk.add_child(att)
	att.bone_name = bone
	var w: Node3D = load("res://scripts/wings.gd").new()
	w.set("variant", "demon")
	w.position = Vector3(0.0, 0.1, -0.25)
	w.rotation.y = PI
	w.set("size_mult", 0.55)
	att.add_child(w)
	w.call("set_deployed", true)
	for a in ["Jump_Idle"]:
		if _ap != null and _ap.has_animation(a):
			_ap.get_animation(a).loop_mode = Animation.LOOP_LINEAR


func _bar_mat(c: Color) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.no_depth_test = true
	m.render_priority = 1
	return m


func _build_bar() -> void:
	_bar_root = Node3D.new()
	_bar_root.position = Vector3(0.0, 2.35 * model_scale / 1.3, 0.0)
	add_child(_bar_root)
	var bg: MeshInstance3D = MeshInstance3D.new()
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(0.9, 0.11)
	bg.mesh = q
	bg.material_override = _bar_mat(Color(0.05, 0.05, 0.06, 0.85))
	_bar_root.add_child(bg)
	_bar_fg = MeshInstance3D.new()
	var q2: QuadMesh = QuadMesh.new()
	q2.size = Vector2(0.86, 0.075)
	_bar_fg.mesh = q2
	var fm: StandardMaterial3D = _bar_mat(Color(0.9, 0.15, 0.15))
	fm.render_priority = 2
	_bar_fg.material_override = fm
	_bar_root.add_child(_bar_fg)
	_bar_root.visible = false


func _update_bar() -> void:
	var r: float = clampf(hp / max_hp, 0.0, 1.0)
	# la barre rétrécit depuis la droite (décalage en espace caméra via le billboard)
	(_bar_fg.mesh as QuadMesh).size = Vector2(0.86 * maxf(r, 0.001), 0.075)
	(_bar_fg.mesh as QuadMesh).center_offset = Vector3(-0.43 * (1.0 - r), 0.0, 0.0)
	_bar_root.visible = state != "dead" and r < 0.999 and not is_boss


func _play(anim: String, blend: float = 0.15) -> void:
	if _ap == null:
		return
	if not _ap.has_animation(anim):
		# les modèles Aventuriers n'ont pas « Idle_Combat » : garde à deux mains ou repos
		if anim == "Idle_Combat":
			anim = "2H_Melee_Idle" if _ap.has_animation("2H_Melee_Idle") else "Idle"
		if not _ap.has_animation(anim) or _cur_anim == anim:
			return
	if _cur_anim == anim:
		return
	_cur_anim = anim
	_ap.play(anim, blend)


func _face(target: Vector3, delta: float, rate: float = 10.0) -> void:
	var d: Vector3 = target - global_position
	if Vector2(d.x, d.z).length() < 0.01:
		return
	var want: float = atan2(-d.x, -d.z)
	rotation.y = lerp_angle(rotation.y, want, 1.0 - exp(-rate * delta))


func _physics_process(delta: float) -> void:
	if player == null:
		var ps: Array = get_tree().get_nodes_in_group("player")
		if ps.size() > 0:
			player = ps[0] as Node3D
		return
	var to_p: Vector3 = player.global_position - global_position
	var dist: float = Vector2(to_p.x, to_p.z).length()
	# joueur en vol au-dessus : les ennemis au sol ne peuvent pas l'atteindre
	var out_of_reach: bool = to_p.y > 1.6 and bool(player.get("is_flying")) and not flying
	if dist > SLEEP_DIST and state != "dead":
		if _ap != null and _ap.is_playing():
			_ap.pause()
		return
	if state != "dead" and _status_tick(delta):
		return
	if _ap != null and not _ap.is_playing() and state != "dead":
		_ap.play()
	if state == "launched":
		if _air_hold > 0.0:
			_air_hold -= delta
			velocity.y = 0.0
		else:
			velocity.y -= GRAVITY * delta
	elif flying and state != "dead":
		# vol : reste à 3,5 m du sol au repos, suit l'altitude du joueur en poursuite
		var gh0: float = float(world.call("ground_height", global_position.x, global_position.z)) if world != null else 0.0
		var want_y: float = gh0 + 3.5
		if state != "idle":
			want_y = maxf(gh0 + 1.2, player.global_position.y + 0.3)
		if boss_kind == "nuages":
			# combat dans les nuages : très haut au repos, au-dessus du héros en combat
			want_y = gh0 + 40.0 if state == "idle" else maxf(gh0 + 25.0, player.global_position.y + 2.5)
		want_y += sin(Time.get_ticks_msec() * 0.003 + float(get_instance_id() % 7)) * 0.3
		velocity.y = clampf((want_y - global_position.y) * 2.5, -8.0, 8.0)
	elif not is_on_floor():
		velocity.y -= GRAVITY * delta
	_t += delta
	_cooldown -= delta
	var hv: Vector3 = Vector3.ZERO
	var player_dead: bool = bool(player.get("is_dead"))
	match state:
		"idle":
			_play("Idle")
			if dist < detect_radius and not player_dead:
				state = "chase"
		"chase":
			if player_dead or dist > detect_radius * 1.8:
				state = "idle"
			elif is_boss and (boss_kind == "" or boss_kind == "gardien") and phase >= 2 and _special_cd <= 0.0 and dist < 9.0:
				_start_slam()
			elif boss_kind != "" and _boss_ai(delta, to_p, dist):
				pass
			elif out_of_reach:
				pass        # il regarde le joueur voler au-dessus de lui, sans pouvoir frapper
			elif ranged and dist <= 13.0 and dist > attack_range and _cooldown <= 0.0:
				state = "cast"
				_t = 0.0
				_hit_done = false
				_cur_anim = ""
				_play("Spellcast_Shoot", 0.1)
			elif dist <= attack_range and _cooldown <= 0.0:
				state = "attack"
				_t = 0.0
				_hit_done = false
				_cur_anim = ""
				_play(attack_anim, 0.1)
			else:
				_face(player.global_position, delta)
				var dir: Vector3 = Vector3(to_p.x, 0.0, to_p.z).normalized()
				var keep: float = 9.0 if ranged else attack_range * 0.8
				if boss_kind == "nuages":
					keep = 16.0 if phase == 1 else attack_range * 0.8
				hv = dir * speed if dist > keep else Vector3.ZERO
				if flying:
					_play("Jump_Idle" if _ap != null and _ap.has_animation("Jump_Idle") else "Idle_Combat")
				else:
					_play("Running_A" if hv.length() > 0.1 else "Idle_Combat")
		"attack":
			if _t < 0.45:
				_face(player.global_position, delta, 6.0)
			if boss_kind == "gardien" and _tele == null and not _hit_done:
				# coup lent et lourd : la zone d'impact s'affiche au sol pendant la préparation
				_tele_pos = global_position + (-global_transform.basis.z) * 2.6
				_tele = MeshInstance3D.new()
				var tor: TorusMesh = TorusMesh.new()
				tor.inner_radius = 0.85
				tor.outer_radius = 1.0
				tor.rings = 32
				tor.ring_segments = 4
				_tele.mesh = tor
				var tm: StandardMaterial3D = StandardMaterial3D.new()
				tm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				tm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				tm.albedo_color = Color(1.0, 0.15, 0.1, 0.85)
				_tele.material_override = tm
				get_parent().add_child(_tele)
				_tele.global_position = _tele_pos + Vector3(0.0, 0.15, 0.0)
			if _tele != null and not _hit_done:
				var kk: float = clampf(_t / hit_time, 0.0, 1.0)
				_tele.scale = Vector3(3.0 * kk, 0.2, 3.0 * kk)
			if not _hit_done and _t >= hit_time:
				_hit_done = true
				if boss_kind == "gardien":
					if _tele != null:
						_tele.queue_free()
						_tele = null
					CombatFx.ring(get_parent(), _tele_pos + Vector3(0.0, 0.2, 0.0), Color(1.0, 0.4, 0.2), 3.0, 0.3)
					Sfx.play("ulti_boom", 0.7)
					var pd2: float = Vector2(player.global_position.x - _tele_pos.x, player.global_position.z - _tele_pos.z).length()
					if pd2 < 3.0 and absf(to_p.y) < 2.0:
						player.call("take_damage", damage, global_position)
				else:
					var fwd: Vector3 = -global_transform.basis.z
					if dist <= attack_range + 0.6 and absf(to_p.y) < 1.6 and fwd.dot(Vector3(to_p.x, 0.0, to_p.z).normalized()) > 0.3:
						player.call("take_damage", damage, global_position)
				pass
			if _t >= attack_time:
				state = "chase"
				_cooldown = 1.1 if not is_boss else 0.6
		"cast":
			_face(player.global_position, delta, 8.0)
			if not _hit_done and _t >= 0.6:
				_hit_done = true
				_shoot()
			if _t >= 1.2:
				state = "chase"
				_cooldown = 2.2
				if boss_kind == "nuages":
					_cooldown = [2.2, 3.0, 1.2][clampi(phase - 1, 0, 2)]
		"slam":
			_update_slam(delta)
		"launched":
			# projeté en l'air : sans défense jusqu'à retomber
			velocity.x = move_toward(velocity.x, 0.0, 6.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 6.0 * delta)
			if _t > 0.35 and is_on_floor() and _air_hold <= 0.0:
				state = "hit"
				_t = 0.2
		"hit":
			velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
			if _t >= 0.4:
				state = "chase"
		"dead":
			velocity.x = 0.0
			velocity.z = 0.0
			if _t > 3.5:
				queue_free()
	_special_cd -= delta
	if state != "hit" and state != "launched":
		velocity.x = hv.x
		velocity.z = hv.z
	move_and_slide()
	# sécurité : si le sol n'a pas encore sa collision, on suit la hauteur du terrain
	if world != null:
		var gh: float = float(world.call("ground_height", global_position.x, global_position.z))
		if global_position.y < gh - 0.3:
			global_position.y = gh
			velocity.y = 0.0



# ================================================================ pouvoirs des épées (statuts)
## gel : immobile dans un bloc de glace ; para : paralysé par l'éclair ; feu / poison : dégâts
## dans le temps, les flammes restent sur le corps. Les boss subissent des durées réduites.
var _st: Dictionary = {}
var _st_fx: Dictionary = {}
var _immune: float = 0.0
var _dot_t: float = 0.0
var _spark_t: float = 0.0
var _poison_stacks: int = 0
var _vent_held: bool = false
var _pull_t: float = 0.0
var _pull_pos: Vector3 = Vector3.ZERO
var _pull_lifted: bool = false
var _pull_age: float = 0.0
var _vent_t: float = 0.0


func has_status(k: String) -> bool:
	return _st.has(k)


func apply_element(el: String) -> void:
	if state == "dead" or illusion:
		return
	match el:
		"glace":
			_set_status("gel", 2.2)
		"eclair":
			_set_status("para", 1.8)
		"feu", "solaire":
			_set_status("feu", 5.0)
		"poison", "ombre":
			_set_status("poison", 6.0)
		"vent":
			if not is_boss:
				launch(9.0)
				_vent_held = false
				_set_status("vent", 1.6)
		"vide":
			launch(7.0)
		"divin":
			_set_status("para", 1.4)
			_set_status("feu", 4.0)


func _set_status(k: String, dur: float) -> void:
	if (k == "gel" or k == "para") and (_immune > 0.0 or _st.has("gel") or _st.has("para")):
		return
	if is_boss:
		dur *= 0.35
	if player != null and player.has_method("duration_mult"):
		dur *= float(player.call("duration_mult"))
	if k == "poison":
		# chaque blessure empoisonnée s'ajoute : le venin ronge de plus en plus vite
		_poison_stacks = mini(_poison_stacks + 1, 6)
	_st[k] = dur
	var pos: Vector3 = global_position + Vector3(0.0, 1.0 * model_scale / 1.3, 0.0)
	var sc: float = model_scale / 1.3
	if not _st_fx.has(k):
		var fx: Node3D = Node3D.new()
		add_child(fx)
		_st_fx[k] = fx
		match k:
			"gel":
				var mi: MeshInstance3D = MeshInstance3D.new()
				var bm: BoxMesh = BoxMesh.new()
				bm.size = Vector3(1.1, 2.0, 1.1) * sc
				mi.mesh = bm
				var m: StandardMaterial3D = StandardMaterial3D.new()
				m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				m.albedo_color = Color(0.6, 0.9, 1.0, 0.55)
				m.emission_enabled = true
				m.emission = Color(0.3, 0.7, 1.0)
				m.emission_energy_multiplier = 0.6
				mi.material_override = m
				mi.position = Vector3(0.0, 0.95 * sc, 0.0)
				fx.add_child(mi)
				CombatFx.ring(get_parent(), global_position + Vector3(0.0, 0.2, 0.0), Color(0.6, 0.9, 1.0), 2.0, 0.3)
				Sfx.play("teleport", 1.8)
			"feu", "poison":
				var col: Color = Color(1.0, 0.45, 0.1) if k == "feu" else Color(0.45, 1.0, 0.25)
				for i in range(5):
					var f: MeshInstance3D = MeshInstance3D.new()
					var sm: SphereMesh = SphereMesh.new()
					sm.radius = 0.17 * sc
					sm.height = 0.5 * sc
					sm.radial_segments = 6
					sm.rings = 3
					f.mesh = sm
					f.material_override = CombatFx._unshaded(col)
					var a: float = float(i) / 5.0 * TAU
					f.position = Vector3(cos(a) * 0.32 * sc, (0.35 + 0.28 * i) * sc, sin(a) * 0.32 * sc)
					fx.add_child(f)
			"para":
				CombatFx.spark(get_parent(), pos, Color(0.8, 0.9, 1.0), 1.4)
				Sfx.play("lightning", 1.2)
	if k == "para":
		CombatFx.bolt(get_parent(), pos + Vector3(0.0, 2.5, 0.0), pos, Color(0.8, 0.9, 1.0), 0.18)


func _clear_status() -> void:
	for k in _st_fx:
		if is_instance_valid(_st_fx[k]):
			(_st_fx[k] as Node).queue_free()
	_st_fx.clear()
	_st.clear()


## Avance les statuts. Renvoie true si l'ennemi est bloqué (gel / paralysie).
func _status_tick(delta: float) -> bool:
	_immune = maxf(_immune - delta, 0.0)
	if _pull_t > 0.0 and state != "dead":
		_pull_t -= delta
		if not _pull_lifted:
			_pull_lifted = true
			launch(7.0)
		_pull_age += delta
		state = "launched"
		_air_hold = 0.3 if _pull_age > 0.4 else 0.0     # d'abord il monte, puis il flotte
		var d: Vector3 = _pull_pos - global_position
		d.y = 0.0
		var dist: float = d.length()
		var dir: Vector3 = d / maxf(dist, 0.01)
		var tang: Vector3 = Vector3(-dir.z, 0.0, dir.x)
		var inward: float = 9.0 if dist > 3.5 else -2.0
		velocity.x = dir.x * inward + tang.x * 6.0
		velocity.z = dir.z * inward + tang.z * 6.0
		if _model != null:
			_model.rotation.y += 11.0 * delta
		if _pull_t <= 0.0:
			_pull_lifted = false
			_pull_age = 0.0
			if _model != null:
				_model.rotation.y = PI
	_immune = _immune
	if _st.is_empty():
		return false
	var locked: bool = false
	var sc: float = model_scale / 1.3
	for k in _st.keys():
		_st[k] = float(_st[k]) - delta
		if float(_st[k]) <= 0.0:
			_st.erase(k)
			if k == "poison":
				_poison_stacks = 0
			if k == "vent" and _model != null:
				_model.rotation.y = PI
				_vent_t = 0.0
			if _st_fx.has(k):
				if k == "gel":
					CombatFx.spark(get_parent(), global_position + Vector3(0.0, 1.0 * sc, 0.0), Color(0.8, 0.95, 1.0), 1.3)
					Sfx.play("hit", 1.4)
				if is_instance_valid(_st_fx[k]):
					(_st_fx[k] as Node).queue_free()
				_st_fx.erase(k)
			if k == "gel" or k == "para":
				_immune = 0.9
				if _ap != null and state != "dead":
					_ap.play()
	if _st.has("gel") or _st.has("para"):
		locked = true
	# flammes qui vacillent sur le corps
	for k in ["feu", "poison"]:
		if _st_fx.has(k) and is_instance_valid(_st_fx[k]):
			var fx: Node3D = _st_fx[k]
			for i in range(fx.get_child_count()):
				var c: Node3D = fx.get_child(i)
				var w: float = 0.8 + 0.5 * sin(Time.get_ticks_msec() * 0.016 + float(i) * 1.7)
				c.scale = Vector3(w, 0.8 + w, w)
	if _st.has("feu") or _st.has("poison"):
		_dot_t -= delta
		if _dot_t <= 0.0:
			_dot_t = 0.5
			var dmg: float = 0.0
			if _st.has("feu"):
				dmg += 5.0 if not is_boss else 8.0
			if _st.has("poison"):
				dmg += (3.0 if not is_boss else 4.0) * float(maxi(_poison_stacks, 1))
			take_damage(dmg, global_position, true)
			if state == "dead":
				return false
	if _st.has("vent") and _model != null:
		# valse : l'ennemi tourne sur lui-même, suspendu en l'air, avec des anneaux de vent
		_vent_t += delta
		_model.rotation.y += 13.0 * delta
		if not _vent_held and _vent_t > 0.3 and state == "launched":
			_vent_held = true
			air_hold(0.9)
		_spark_t -= delta
		if _spark_t <= 0.0:
			_spark_t = 0.18
			CombatFx.ring(get_parent(), global_position + Vector3(0.0, 0.4, 0.0), Color(0.8, 1.0, 0.9, 0.7), 1.4, 0.3)
			CombatFx.spark(get_parent(), global_position + Vector3(0.0, 1.0, 0.0), Color(0.85, 1.0, 0.95), 0.6)
	if _st.has("para"):
		_spark_t -= delta
		if _spark_t <= 0.0:
			_spark_t = 0.22
			var a: float = randf() * TAU
			CombatFx.spark(get_parent(), global_position + Vector3(cos(a) * 0.5 * sc, randf_range(0.2, 1.8) * sc, sin(a) * 0.5 * sc), Color(0.8, 0.9, 1.0), 0.6)
	if locked:
		if _ap != null:
			_ap.pause()
		if not is_on_floor() and not flying:
			velocity.y -= GRAVITY * delta
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
	return locked



## Appelé par l'épée du joueur. dot = dégâts dans le temps (brûlure, poison) : sans recul ni étincelle.
func take_damage(amount: float, from_pos: Vector3, dot: bool = false) -> void:
	if state == "dead":
		return
	if illusion:
		# fausse Reine : disparaît dans un nuage de feuilles, sans butin
		CombatFx.spark(get_parent(), global_position + Vector3(0.0, 1.2, 0.0), Color(0.4, 1.0, 0.5), 1.5)
		Sfx.play("teleport", 1.5)
		queue_free()
		return
	hp -= amount
	var head: Vector3 = global_position + Vector3(0.0, 1.5 * model_scale / 1.3, 0.0)
	if dot:
		CombatFx.number(get_parent(), head + Vector3(0.0, 0.5, 0.0), int(round(amount)), Color(1.0, 0.55, 0.15))
	else:
		CombatFx.spark(get_parent(), head + Vector3(0.0, -0.3, 0.0), Color(0.45, 0.75, 1.0), 0.9)
		CombatFx.number(get_parent(), head + Vector3(0.0, 0.5, 0.0), int(round(amount)))
	_update_bar()
	if hp > 0.0 and dot:
		if is_boss:
			_check_phase()
		return
	if hp <= 0.0:
		_clear_status()
		state = "dead"
		_t = 0.0
		_cur_anim = ""
		_play("Death_A", 0.1)
		collision_layer = 0
		collision_mask = 1
		_bar_root.visible = false
		Sfx.play("enemy_die")
		_drop_loot()
		if _ring != null:
			_ring.queue_free()
			_ring = null
		if player != null and player.has_method("add_xp"):
			player.call("add_xp", xp_value)
			CombatFx.number(get_parent(), head + Vector3(0.0, 0.9, 0.0), xp_value, Color(0.5, 1.0, 0.6))
		died.emit(self)
		for il in _illusions:
			if is_instance_valid(il):
				il.queue_free()
		if is_boss and player != null and player.has_method("celebrate"):
			player.call("celebrate")
			player.call("boss_defeated", boss_kind)
		return
	if is_boss:
		_check_phase()
		return
	if state == "slam" or state == "cast" or state == "launched":
		return
	state = "hit"
	_t = 0.0
	_cur_anim = ""
	_play("Hit_A", 0.05)
	var push: Vector3 = global_position - from_pos
	push.y = 0.0
	var knock: Vector3 = push.normalized() * 9.0
	velocity.x = knock.x
	velocity.z = knock.z
	velocity.y = 3.5      # petit saut : l'ennemi est propulsé en arrière


## Aspiré par le Seigneur des tempêtes : monte en l'air, tourne autour de lui en tournoyant.
func pull_toward(pos: Vector3) -> void:
	if state == "dead" or is_boss or illusion:
		return
	_pull_pos = pos
	_pull_t = 0.25


## Recul puissant (fin de combo).
func knockback(dir: Vector3, force: float) -> void:
	if state == "dead" or is_boss:
		return
	dir.y = 0.0
	state = "hit"
	_t = 0.0
	var k: Vector3 = dir.normalized() * force
	velocity = Vector3(k.x, force * 0.35, k.z)


## Projection en l'air (frappe ascendante de l'exécution aérienne).
func launch(vy: float) -> void:
	if state == "dead" or is_boss or flying:
		return
	state = "launched"
	_t = 0.0
	_cur_anim = ""
	_play("Hit_A", 0.05)
	velocity = Vector3(0.0, vy, 0.0)


func air_hold(t: float) -> void:
	if state == "launched":
		_air_hold = t


## Coup descendant : renvoie l'ennemi au sol.
func slam_down() -> void:
	if state == "launched":
		_air_hold = 0.0
		velocity.y = -22.0


# ================================================================ distance, boss, butin

func _shoot() -> void:
	if player == null:
		return
	var count: int = 1
	if boss_kind == "nuages":
		count = [3, 3, 5][clampi(phase - 1, 0, 2)]
	var from: Vector3 = global_position + Vector3(0.0, 1.4 * model_scale / 1.3, 0.0)
	var target: Vector3 = player.global_position + Vector3(0.0, 1.0, 0.0)
	var base_dir: Vector3 = (target - from).normalized()
	for k in range(count):
		var spread: float = (float(k) - float(count - 1) * 0.5) * 0.16
		var pr: Node3D = Projectile.new()
		pr.set("damage", damage)
		pr.set("color", fire_color)
		pr.set("world", world)
		pr.set("hits_flying", flying or is_boss)
		pr.set("dir", base_dir.rotated(Vector3.UP, spread))
		if boss_kind == "nuages":
			pr.set("speed", 16.0)
		get_parent().add_child(pr)
		pr.global_position = from


func _check_phase() -> void:
	var r: float = hp / max_hp
	var new_phase: int = 3 if r < 0.3 else (2 if r < 0.6 else 1)
	if new_phase > phase:
		phase = new_phase
		speed *= 1.6 if (boss_kind == "nuages" and phase == 3) else 1.2
		_special_cd = 1.5
		if boss_kind == "":
			_summon(2 if phase == 2 else 3)
			if player != null:
				var hud_msg: String = "Le Roi Squelette appelle ses serviteurs !" if phase == 2 else "Le Roi Squelette entre en furie !"
				player.emit_signal("announce", hud_msg)
		else:
			if boss_kind == "nuages" and phase == 2:
				ranged = true
				attack_range = 3.5
			if boss_kind == "reine":
				_special_cd = 0.2
			if player != null:
				player.emit_signal("announce", String(BOSS_NAMES_PHASE[boss_kind][phase - 1]))


func _summon(n: int) -> void:
	for k in range(n):
		var e: CharacterBody3D = load("res://scripts/enemy.gd").new()
		e.set("model_path", "res://Assets/Characters/Skeletons/Skeleton_Minion.glb")
		e.set("max_hp", 35.0)
		e.set("damage", 6.0)
		e.set("speed", 3.8)
		e.set("model_scale", 1.2)
		e.set("display_name", "Serviteur")
		e.set("xp_value", 8)
		e.set("world", world)
		var a: float = float(k) / float(n) * TAU
		get_parent().add_child(e)
		e.global_position = global_position + Vector3(cos(a) * 4.0, 0.5, sin(a) * 4.0)
		CombatFx.spark(get_parent(), e.global_position + Vector3(0.0, 1.0, 0.0), Color(0.6, 0.2, 1.0), 1.4)


## Onde de choc : un cercle rouge grandit 1,3 s au sol, puis frappe tout ce qui est dedans.
func _start_slam() -> void:
	state = "slam"
	_t = 0.0
	_hit_done = false
	_cur_anim = ""
	_play("2H_Melee_Attack_Spin" if _ap != null and _ap.has_animation("2H_Melee_Attack_Spin") else attack_anim, 0.1)
	_ring = MeshInstance3D.new()
	var tor: TorusMesh = TorusMesh.new()
	tor.inner_radius = 0.9
	tor.outer_radius = 1.0
	tor.rings = 48
	tor.ring_segments = 4
	_ring.mesh = tor
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1.0, 0.1, 0.1, 0.8)
	_ring.material_override = m
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().add_child(_ring)
	_ring.global_position = global_position + Vector3(0.0, 0.15, 0.0)
	_ring.scale = Vector3(0.5, 0.15, 0.5)


func _update_slam(_delta: float) -> void:
	const RADIUS: float = 7.0
	if _ring != null:
		var k: float = clampf(_t / 1.3, 0.0, 1.0)
		_ring.scale = Vector3(RADIUS * k, 0.15, RADIUS * k)
	if not _hit_done and _t >= 1.3:
		_hit_done = true
		if _ring != null:
			_ring.queue_free()
			_ring = null
		for k in range(10):
			var a: float = float(k) / 10.0 * TAU
			CombatFx.spark(get_parent(), global_position + Vector3(cos(a) * RADIUS * 0.8, 0.4, sin(a) * RADIUS * 0.8), Color(1.0, 0.25, 0.15), 1.6)
		Sfx.play("lightning", 0.6)
		if player != null:
			var d: float = Vector2(player.global_position.x - global_position.x, player.global_position.z - global_position.z).length()
			var dy: float = player.global_position.y - global_position.y
			if d < RADIUS and dy < 2.5:
				player.call("take_damage", damage * 1.6, global_position)
			var cam: Node = player.get("cam")
			if cam != null:
				cam.call("shake", 0.5)
	if _t >= 1.9:
		state = "chase"
		_special_cd = 6.0 if phase == 2 else 4.0


func _drop_loot() -> void:
	var gold: int = randi_range(1, 4) * (20 if is_boss else 1)
	_spawn_loot("or", gold, Vector3(0.4, 0.0, 0.0))
	var potions: int = 3 if is_boss else (1 if randf() < 0.3 else 0)
	for k in range(potions):
		_spawn_loot("potion", 1, Vector3(-0.4, 0.0, 0.5 * float(k)))


func _spawn_loot(kind: String, amount: int, off: Vector3) -> void:
	var l: Node3D = Loot.new()
	l.set("kind", kind)
	l.set("amount", amount)
	get_parent().add_child(l)
	l.global_position = global_position + off


# ================================================================ boss de région
# boss_kind : "gardien" (Gardien des montagnes), "reine" (Reine de la forêt),
# "ombre" (Seigneur des ombres), "nuages" (Seigneur des nuages, combat aérien).

const BOSS_NAMES_PHASE: Dictionary = {
	"gardien": ["", "Le Gardien frappe le sol de rage !", "Le Gardien entre en furie !"],
	"reine": ["", "La Reine crée des illusions : trouve la vraie !", "La Reine se démultiplie !"],
	"ombre": ["", "Le Seigneur des ombres imite tes techniques !", "Le Seigneur des ombres devient insaisissable !"],
	"nuages": ["", "Affrontement : le Seigneur des nuages approche !", "Dernière phase : il devient plus rapide !"],
}


## Comportement spécial du boss pendant la poursuite. Renvoie true s'il a agi cette image.
func _boss_ai(_delta: float, to_p: Vector3, dist: float) -> bool:
	match boss_kind:
		"reine":
			# se déplace d'un arbre à l'autre (téléportation) et crée des illusions
			if _special_cd <= 0.0:
				_special_cd = 5.5 if phase < 3 else 3.5
				var a: float = randf() * TAU
				var r: float = randf_range(7.0, 12.0)
				var dest: Vector3 = player.global_position + Vector3(cos(a) * r, 0.0, sin(a) * r)
				if world != null:
					dest.y = float(world.call("ground_height", dest.x, dest.z)) + 0.2
				CombatFx.spark(get_parent(), global_position + Vector3(0.0, 1.2, 0.0), Color(0.4, 1.0, 0.5), 1.4)
				global_position = dest
				CombatFx.spark(get_parent(), global_position + Vector3(0.0, 1.2, 0.0), Color(0.4, 1.0, 0.5), 1.4)
				if phase >= 2 and _illusions_alive() == 0:
					_make_illusions(2 if phase == 2 else 3)
				return true
		"ombre":
			# apparaît derrière le héros et frappe aussitôt (comme sa téléportation)
			if _special_cd <= 0.0 and dist < 18.0:
				# enchaînement : en phase 2 et 3, 3 apparitions-frappes rapprochées
				if _blinks > 0:
					_blinks -= 1
				else:
					_blinks = 2 if phase >= 2 else 0
				_special_cd = 0.6 if _blinks > 0 else (4.5 if phase == 1 else (3.0 if phase == 2 else 2.0))
				var back: Vector3 = Vector3(sin(float(player.get("face_yaw"))), 0.0, cos(float(player.get("face_yaw"))))
				CombatFx.afterimage(get_parent(), global_position, Color(0.5, 0.2, 0.8))
				var dest2: Vector3 = player.global_position + back * 1.6
				if world != null:
					dest2.y = maxf(dest2.y, float(world.call("ground_height", dest2.x, dest2.z)))
				global_position = dest2
				_face(player.global_position, 1.0, 999.0)
				state = "attack"
				_t = hit_time * 0.6         # attaque rapide : moins de préparation
				_hit_done = false
				_cur_anim = ""
				_play(attack_anim, 0.05)
				Sfx.play("teleport", 0.7)
				return true
		"nuages":
			# phase 1 : reste à distance et tire ; phase 2 : se rapproche ; phase 3 : plus rapide
			pass
	return false


func _illusions_alive() -> int:
	var n: int = 0
	for e in _illusions:
		if is_instance_valid(e) and String(e.get("state")) != "dead":
			n += 1
	return n


## Illusions de la Reine : identiques, fragiles (disparaissent au premier coup), sans butin.
func _make_illusions(n: int) -> void:
	_illusions.clear()
	for k in range(n):
		var e: CharacterBody3D = load("res://scripts/enemy.gd").new()
		e.set("model_path", model_path)
		e.set("keep_props", keep_props)
		e.set("weapon_path", weapon_path)
		e.set("tint", tint)
		e.set("max_hp", 1.0)
		e.set("damage", damage * 0.4)
		e.set("speed", speed)
		e.set("model_scale", model_scale)
		e.set("display_name", display_name)
		e.set("attack_anim", attack_anim)
		e.set("hit_time", hit_time)
		e.set("attack_time", attack_time)
		e.set("illusion", true)
		e.set("xp_value", 0)
		e.set("world", world)
		e.set("detect_radius", 40.0)
		get_parent().add_child(e)
		var a: float = float(k) / float(n) * TAU + randf()
		var p: Vector3 = global_position + Vector3(cos(a) * 5.0, 0.0, sin(a) * 5.0)
		if world != null:
			p.y = float(world.call("ground_height", p.x, p.z)) + 0.2
		e.global_position = p
		_illusions.append(e)
		CombatFx.spark(get_parent(), p + Vector3(0.0, 1.2, 0.0), Color(0.4, 1.0, 0.5), 1.2)
