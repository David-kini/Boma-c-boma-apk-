extends Node2D
## Duel Éclair : un héros (ton visage) contre des vagues de monstres.
## Godot 4.3+, rendu GL Compatibility, tout est dessiné par le code.

const W: float = 960.0
const H: float = 540.0
const GY: float = 450.0
const FLOOR_Y: float = 423.0
const GRAV: float = 0.83
const JUMP_V: float = 17.4

const ATK: Dictionary = {
	"punch": {"start": 4, "active": 4, "rec": 9, "dmg": 7.0, "reach": 60.0, "hy1": -123.0, "hy2": -90.0, "kb": 4.8, "stun": 16, "stop": 3, "fy": 0.0, "lunge": 0.0},
	"kick": {"start": 8, "active": 5, "rec": 13, "dmg": 12.0, "reach": 87.0, "hy1": -99.0, "hy2": -45.0, "kb": 7.5, "stun": 22, "stop": 5, "fy": -72.0, "lunge": 0.0},
	"kick2": {"start": 5, "active": 4, "rec": 9, "dmg": 8.0, "reach": 90.0, "hy1": -129.0, "hy2": -84.0, "kb": 3.7, "stun": 20, "stop": 3, "fy": -99.0, "lunge": 0.0},
	"kick3": {"start": 5, "active": 4, "rec": 9, "dmg": 8.0, "reach": 90.0, "hy1": -60.0, "hy2": -9.0, "kb": 3.7, "stun": 20, "stop": 3, "fy": -21.0, "lunge": 0.0},
	"kick4": {"start": 9, "active": 6, "rec": 22, "dmg": 18.0, "reach": 105.0, "hy1": -120.0, "hy2": -51.0, "kb": 15.0, "stun": 30, "stop": 7, "fy": -78.0, "lunge": 21.0},
	"m_blob": {"start": 16, "active": 5, "rec": 34, "dmg": 8.0, "reach": 52.0, "hy1": -80.0, "hy2": -10.0, "kb": 5.0, "stun": 18, "stop": 3, "fy": 0.0, "lunge": 0.0},
	"m_skull": {"start": 10, "active": 5, "rec": 26, "dmg": 6.0, "reach": 56.0, "hy1": -130.0, "hy2": -60.0, "kb": 4.0, "stun": 14, "stop": 2, "fy": 0.0, "lunge": 0.0},
	"m_ogre": {"start": 26, "active": 7, "rec": 44, "dmg": 20.0, "reach": 110.0, "hy1": -170.0, "hy2": -30.0, "kb": 12.0, "stun": 26, "stop": 6, "fy": 0.0, "lunge": 0.0},
}
const CHAIN: Array = ["kick", "kick2", "kick3", "kick4"]

const MON: Dictionary = {
	"blob": {"hp": 45.0, "speed": 1.6, "fw": 34.0, "fh": 84.0, "atk": "m_blob"},
	"skull": {"hp": 35.0, "speed": 3.2, "fw": 28.0, "fh": 120.0, "atk": "m_skull"},
	"ogre": {"hp": 180.0, "speed": 1.3, "fw": 54.0, "fh": 200.0, "atk": "m_ogre"},
}
const WAVES: Array = [
	["blob", "blob"],
	["blob", "blob", "skull"],
	["skull", "skull", "skull", "blob"],
	["ogre", "blob", "blob"],
]

const BTN: Dictionary = {
	"left": Rect2(20, 420, 100, 100),
	"right": Rect2(130, 420, 100, 100),
	"jump": Rect2(20, 310, 210, 100),
	"punch": Rect2(740, 420, 100, 100),
	"kick": Rect2(850, 420, 100, 100),
	"block": Rect2(740, 310, 210, 100),
}
const BTN_LABEL: Dictionary = {
	"left": "<", "right": ">", "jump": "SAUT", "punch": "POING", "kick": "PIED", "block": "GARDE",
}
const KEYMAP: Dictionary = {
	KEY_LEFT: "left", KEY_A: "left", KEY_RIGHT: "right", KEY_D: "right",
	KEY_UP: "jump", KEY_W: "jump", KEY_SPACE: "jump",
	KEY_DOWN: "block", KEY_S: "block", KEY_L: "block",
	KEY_J: "punch", KEY_K: "kick",
}

const SKIN: Color = Color(0.93, 0.70, 0.62)
const SHIRT: Color = Color(0.96, 0.96, 0.97)
const VEST: Color = Color(0.30, 0.30, 0.33)
const PANT: Color = Color(0.11, 0.11, 0.15)
const PANT_D: Color = Color(0.07, 0.07, 0.10)
const DARK: Color = Color(0.05, 0.03, 0.10)
const INK: Color = Color(0.96, 0.93, 0.86)
const ACCENT: Color = Color(1.0, 0.54, 0.24)


class Fighter:
	var kind: String = "hero"
	var x: float = 0.0
	var y: float = 450.0
	var vx: float = 0.0
	var vy: float = 0.0
	var kx: float = 0.0
	var dir: int = 1
	var hp: float = 100.0
	var max_hp: float = 100.0
	var ghost: float = 100.0
	var st: String = "idle"
	var t: int = 0
	var atk: String = ""
	var atk_name: String = ""
	var done: bool = false
	var anim: int = 0
	var flash: int = 0
	var ko_t: int = 0
	var cc: int = 0
	var cc_t: int = 0
	var cool: int = 0
	var fw: float = 33.0
	var fh: float = 156.0
	var speed: float = 4.0


var hero: Fighter
var mons: Array = []
var queue: Array = []
var spawn_t: int = 0
var phase: String = "menu"
var phase_t: int = 0
var wave: int = 0
var kills: int = 0
var hitstop: int = 0
var shake: float = 0.0
var cam: Vector2 = Vector2.ZERO
var sparks: Array = []
var keys: Dictionary = {"left": false, "right": false, "block": false}
var buf: Dictionary = {"jump": 0, "punch": 0, "kick": 0}
var touches: Dictionary = {}
var face_tex: Texture2D = null
var arena_tex: Texture2D = null
var font: Font
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var bld_far: Array = []
var bld_near: Array = []
var wins: Array = []
var stars: Array = []
var palm_lines: Array = []


func _ready() -> void:
	font = ThemeDB.fallback_font
	if ResourceLoader.exists("res://assets/textures/face.png"):
		face_tex = load("res://assets/textures/face.png")
	if ResourceLoader.exists("res://assets/textures/arena.jpg"):
		arena_tex = load("res://assets/textures/arena.jpg")
	elif ResourceLoader.exists("res://assets/textures/arena.png"):
		arena_tex = load("res://assets/textures/arena.png")
	DisplayServer.screen_set_keep_on(true)
	build_bg()
	hero = new_hero()
	phase = "menu"


func new_hero() -> Fighter:
	var f: Fighter = Fighter.new()
	f.kind = "hero"
	f.x = 300.0
	f.y = GY
	f.dir = 1
	f.hp = 100.0
	f.max_hp = 100.0
	f.ghost = 100.0
	f.fw = 33.0
	f.fh = 156.0
	f.speed = 4.0
	return f


func start_game() -> void:
	hero = new_hero()
	kills = 0
	wave = 0
	sparks.clear()
	start_wave()


func start_wave() -> void:
	queue = (WAVES[wave] as Array).duplicate()
	mons.clear()
	spawn_t = 30
	phase = "intro"
	phase_t = 0
	hero.vx = 0.0
	hero.st = "idle"
	hero.atk = ""


func spawn_monster(kind: String) -> void:
	var s: Dictionary = MON[kind]
	var m: Fighter = Fighter.new()
	m.kind = kind
	var from_right: bool = (randi() % 2 == 0)
	m.x = (W - 60.0) if from_right else 60.0
	m.y = GY
	m.dir = -1 if from_right else 1
	m.hp = float(s["hp"])
	m.max_hp = m.hp
	m.ghost = m.hp
	m.speed = float(s["speed"])
	m.fw = float(s["fw"])
	m.fh = float(s["fh"])
	m.atk_name = String(s["atk"])
	m.cool = 40
	mons.append(m)


# ---------------------------------------------------------------- entrées

func press(k: String) -> void:
	if k == "left" or k == "right" or k == "block":
		keys[k] = true
	elif k == "jump" or k == "punch" or k == "kick":
		buf[k] = 8


func release(k: String) -> void:
	if keys.has(k):
		keys[k] = false


func button_at(p: Vector2) -> String:
	for k in BTN:
		var r: Rect2 = BTN[k]
		if r.grow(6.0).has_point(p):
			return String(k)
	return ""


func can_start() -> bool:
	return (phase == "menu" or phase == "gameover" or phase == "victory") and phase_t > 30


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t: InputEventScreenTouch = event as InputEventScreenTouch
		if t.pressed:
			if can_start():
				start_game()
				return
			var b: String = button_at(t.position)
			if b != "":
				touches[t.index] = b
				press(b)
		else:
			if touches.has(t.index):
				release(String(touches[t.index]))
				touches.erase(t.index)
	elif event is InputEventScreenDrag:
		var d: InputEventScreenDrag = event as InputEventScreenDrag
		var nb: String = button_at(d.position)
		var ob: String = String(touches.get(d.index, ""))
		if nb != ob:
			if ob != "":
				release(ob)
			if nb != "":
				touches[d.index] = nb
				press(nb)
			else:
				touches.erase(d.index)
	elif event is InputEventKey:
		var ke: InputEventKey = event as InputEventKey
		if ke.echo:
			return
		var act: String = String(KEYMAP.get(ke.physical_keycode, ""))
		if ke.pressed:
			if can_start():
				start_game()
				return
			if act != "":
				press(act)
		else:
			if act != "":
				release(act)


# ---------------------------------------------------------------- logique

func e_of(f: Fighter) -> float:
	if f.atk == "":
		return 0.0
	var a: Dictionary = ATK[f.atk]
	var s: int = int(a["start"])
	var ac: int = int(a["active"])
	var rc: int = int(a["rec"])
	var e: float
	if f.t < s:
		e = float(f.t) / float(s)
	elif f.t < s + ac:
		e = 1.0
	else:
		e = 1.0 - float(f.t - s - ac) / float(rc)
	return clampf(e, 0.0, 1.0)


func begin(f: Fighter, name_: String) -> void:
	f.atk = name_
	f.t = 0
	f.done = false
	f.st = "atk"


func physics(f: Fighter) -> void:
	f.x += f.vx
	if f.y < GY or f.vy < 0.0:
		f.vy += GRAV
		f.y += f.vy
		if f.y >= GY:
			f.y = GY
			if f.st == "ko" and f.vy > 4.5:
				f.vy = -f.vy * 0.3
			else:
				f.vy = 0.0
				f.vx = 0.0
				if f.st == "jump":
					f.st = "idle"
	f.x = clampf(f.x, 40.0, W - 40.0)


func nearest_monster() -> Fighter:
	var best: Fighter = null
	var bd: float = 99999.0
	for mm in mons:
		var m: Fighter = mm
		if m.st == "ko":
			continue
		var d: float = absf(m.x - hero.x)
		if d < bd:
			bd = d
			best = m
	return best


func upd_hero() -> void:
	var f: Fighter = hero
	f.anim += 1
	if f.flash > 0:
		f.flash -= 1
	if f.cc_t > 0:
		f.cc_t -= 1
		if f.cc_t == 0:
			f.cc = 0
	f.x += f.kx
	f.kx *= 0.84
	if absf(f.kx) < 0.05:
		f.kx = 0.0
	var air: bool = f.y < GY
	if f.st == "ko":
		f.ko_t += 1
		physics(f)
		return
	if f.st == "win":
		physics(f)
		return
	if f.st == "hit":
		f.t -= 1
		if f.t <= 0:
			f.st = "jump" if air else "idle"
		physics(f)
		return
	var want: int = int(keys["right"]) - int(keys["left"])
	if f.atk != "":
		var a: Dictionary = ATK[f.atk]
		f.t += 1
		if (not f.done) and f.t >= int(a["start"]) and f.t < int(a["start"]) + int(a["active"]):
			hit_check(f, mons)
		var ci: int = CHAIN.find(f.atk)
		if ci >= 0 and ci < CHAIN.size() - 1 and f.done and int(buf["kick"]) > 0:
			buf["kick"] = 0
			begin(f, String(CHAIN[ci + 1]))
			f.kx += f.dir * 4.5
			f.cc = ci + 2
			f.cc_t = 80
		elif f.t >= int(a["start"]) + int(a["active"]) + int(a["rec"]):
			f.atk = ""
			f.st = "jump" if air else "idle"
		if not air:
			f.vx = 0.0
		physics(f)
		return
	var tgt: Fighter = nearest_monster()
	if not air:
		if bool(keys["block"]):
			f.st = "block"
			f.vx = 0.0
			if tgt != null:
				f.dir = 1 if tgt.x > f.x else -1
		else:
			f.vx = want * f.speed
			f.st = "walk" if want != 0 else "idle"
			if want != 0:
				f.dir = want
			elif tgt != null:
				f.dir = 1 if tgt.x > f.x else -1
			if int(buf["jump"]) > 0:
				f.vy = -JUMP_V
				f.st = "jump"
				buf["jump"] = 0
	if f.st != "block":
		if int(buf["punch"]) > 0:
			begin(f, "punch")
			buf["punch"] = 0
		elif int(buf["kick"]) > 0:
			begin(f, "kick")
			buf["kick"] = 0
	physics(f)


func upd_mon(m: Fighter) -> void:
	m.anim += 1
	if m.flash > 0:
		m.flash -= 1
	m.x += m.kx
	m.kx *= 0.84
	if absf(m.kx) < 0.05:
		m.kx = 0.0
	if m.st == "ko":
		m.ko_t += 1
		physics(m)
		return
	if m.st == "hit":
		m.t -= 1
		if m.t <= 0:
			m.st = "idle"
		physics(m)
		return
	if m.cool > 0:
		m.cool -= 1
	var a: Dictionary = ATK[m.atk_name]
	if m.atk != "":
		m.t += 1
		if (not m.done) and m.t >= int(a["start"]) and m.t < int(a["start"]) + int(a["active"]):
			hit_check(m, [hero])
		if m.t >= int(a["start"]) + int(a["active"]) + int(a["rec"]):
			m.atk = ""
			m.st = "idle"
		m.vx = 0.0
		physics(m)
		return
	var dx: float = hero.x - m.x
	var dist: float = absf(dx)
	m.dir = 1 if dx >= 0.0 else -1
	var rng_: float = m.fw + float(a["reach"]) * 0.75 + hero.fw * 0.5
	if hero.st == "ko":
		m.vx = 0.0
		m.st = "idle"
	elif dist > rng_:
		m.vx = m.dir * m.speed
		m.st = "walk"
	else:
		m.vx = 0.0
		m.st = "idle"
		if m.cool <= 0:
			begin(m, m.atk_name)
			m.cool = randi_range(40, 90)
	physics(m)


func hit_check(a: Fighter, targets: Array) -> void:
	var A: Dictionary = ATK[a.atk]
	var reach: float = float(A["reach"])
	var x0: float
	var x1: float
	if a.dir > 0:
		x0 = a.x
		x1 = a.x + a.fw + reach
	else:
		x0 = a.x - a.fw - reach
		x1 = a.x
	var y0: float = a.y + float(A["hy1"])
	var y1: float = a.y + float(A["hy2"])
	var hit_any: bool = false
	for oo in targets:
		var o: Fighter = oo
		if o.st == "ko":
			continue
		var bx0: float = o.x - o.fw + 6.0
		var bx1: float = o.x + o.fw - 6.0
		var by0: float = o.y - o.fh
		var by1: float = o.y
		if x1 < bx0 or x0 > bx1 or y1 < by0 or y0 > by1:
			continue
		hit_any = true
		var blocked: bool = (o.st == "block" and o.y >= GY and o.dir == -a.dir)
		var px: float = clampf(o.x - a.dir * o.fw * 0.5, minf(x0, x1), maxf(x0, x1))
		var py: float = (maxf(y0, by0) + minf(y1, by1)) * 0.5
		var dmg: float = float(A["dmg"])
		if blocked:
			o.hp = maxf(1.0, o.hp - maxf(1.0, roundf(dmg * 0.12)))
			o.kx = a.dir * float(A["kb"]) * 0.7
			o.flash = 8
			spawn_sparks(px, py, Color(0.56, 0.83, 1.0), 6)
			hitstop = maxi(hitstop, 2)
		else:
			o.hp = maxf(0.0, o.hp - dmg)
			var armored: bool = (o.kind == "ogre" and o.atk != "" and a.atk != "kick4")
			if armored:
				o.kx = a.dir * 1.5
			else:
				o.atk = ""
				o.done = false
				o.kx = a.dir * float(A["kb"])
				o.st = "hit"
				o.t = int(A["stun"])
				o.vx = 0.0
				if o.y < GY:
					o.vy = minf(o.vy, -4.5)
			o.flash = 6
			spawn_sparks(px, py, Color(1.0, 0.82, 0.4), 10)
			hitstop = maxi(hitstop, int(A["stop"]))
			shake = maxf(shake, dmg * 1.2)
			if o == hero:
				Input.vibrate_handheld(25)
			if o.hp <= 0.0:
				ko_fighter(o, a)
	if hit_any:
		a.done = true


func ko_fighter(o: Fighter, a: Fighter) -> void:
	o.st = "ko"
	o.ko_t = 0
	o.vy = -9.0
	o.kx = a.dir * 7.5
	o.vx = 0.0
	o.atk = ""
	shake = maxf(shake, 14.0)
	if o != hero:
		kills += 1


func separate() -> void:
	var all: Array = [hero]
	all.append_array(mons)
	for i in range(all.size()):
		for j in range(i + 1, all.size()):
			var a: Fighter = all[i]
			var b: Fighter = all[j]
			if a.st == "ko" or b.st == "ko":
				continue
			if absf(a.y - b.y) > 80.0:
				continue
			var dx: float = b.x - a.x
			var mn: float = (a.fw + b.fw) * 0.8
			if absf(dx) < mn:
				var push: float = (mn - absf(dx)) * 0.5
				var sg: float = 1.0 if dx >= 0.0 else -1.0
				a.x = clampf(a.x - sg * push, 40.0, W - 40.0)
				b.x = clampf(b.x + sg * push, 40.0, W - 40.0)


func spawn_sparks(px: float, py: float, c: Color, n: int) -> void:
	if sparks.size() > 80:
		return
	for i in range(n):
		var ang: float = randf() * TAU
		var sp: float = 2.0 + randf() * 5.0
		sparks.append({"p": Vector2(px, py), "v": Vector2(cos(ang), sin(ang)) * sp - Vector2(0.0, 1.5), "l": 14 + randi() % 8, "c": c})
	sparks.append({"p": Vector2(px, py), "v": Vector2.ZERO, "l": 8, "c": Color.WHITE, "ring": true})


func _physics_process(_delta: float) -> void:
	if hitstop > 0:
		hitstop -= 1
		return
	phase_t += 1
	if phase == "menu":
		hero.anim += 1
	elif phase == "intro":
		upd_hero()
		if phase_t >= 100:
			phase = "fight"
			phase_t = 0
	elif phase == "fight":
		upd_hero()
		spawn_t -= 1
		if spawn_t <= 0 and queue.size() > 0:
			spawn_monster(String(queue.pop_front()))
			spawn_t = 80
		for mm in mons:
			upd_mon(mm)
		separate()
		for i in range(mons.size() - 1, -1, -1):
			var m: Fighter = mons[i]
			if m.st == "ko" and m.ko_t > 50:
				mons.remove_at(i)
		if hero.st == "ko" and hero.ko_t > 60:
			phase = "gameover"
			phase_t = 0
		elif queue.is_empty() and mons.is_empty():
			phase = "clear"
			phase_t = 0
			hero.atk = ""
			hero.vx = 0.0
	elif phase == "clear":
		upd_hero()
		if phase_t >= 130:
			wave += 1
			if wave >= WAVES.size():
				phase = "victory"
				phase_t = 0
				hero.st = "win"
				hero.atk = ""
			else:
				hero.hp = minf(hero.max_hp, hero.hp + 35.0)
				start_wave()
	else:
		if hero.st == "win":
			hero.anim += 1
	hero.ghost += (hero.hp - hero.ghost) * 0.06
	for mm in mons:
		var m2: Fighter = mm
		m2.ghost += (m2.hp - m2.ghost) * 0.08
	for i in range(sparks.size() - 1, -1, -1):
		var s: Dictionary = sparks[i]
		var v: Vector2 = s["v"]
		v.y += 0.3
		s["v"] = v
		s["p"] = (s["p"] as Vector2) + v
		s["l"] = int(s["l"]) - 1
		if int(s["l"]) <= 0:
			sparks.remove_at(i)
	for k in buf:
		if int(buf[k]) > 0:
			buf[k] = int(buf[k]) - 1


func _process(_delta: float) -> void:
	shake *= 0.88
	if shake > 0.4:
		cam = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake
	else:
		cam = Vector2.ZERO
	queue_redraw()


# ---------------------------------------------------------------- décor

func build_bg() -> void:
	rng.seed = 7
	var x: float = -10.0
	while x < W:
		var w: float = 36.0 + rng.randf() * 40.0
		var h: float = 60.0 + rng.randf() * 105.0
		bld_far.append(Rect2(x, FLOOR_Y - h, w, h))
		x += w + 3.0
	x = -10.0
	while x < W:
		var w2: float = 45.0 + rng.randf() * 50.0
		var h2: float = 40.0 + rng.randf() * 90.0
		bld_near.append(Rect2(x, FLOOR_Y - h2, w2, h2))
		var wy: float = FLOOR_Y - h2 + 9.0
		while wy < FLOOR_Y - 9.0:
			var wx: float = x + 8.0
			while wx < x + w2 - 9.0:
				if rng.randf() < 0.3:
					wins.append(Rect2(wx, wy, 4.5, 6.0))
				wx += 13.0
			wy += 15.0
		x += w2 + 4.0
	for i in range(55):
		stars.append(Vector2(rng.randf() * W, rng.randf() * 160.0))
	add_palm(90.0, FLOOR_Y + 6.0, 285.0, 39.0)
	add_palm(W - 78.0, FLOOR_Y + 6.0, 250.0, -36.0)
	add_palm(186.0, FLOOR_Y + 3.0, 165.0, -18.0)


func add_palm(px: float, py: float, h: float, lean: float) -> void:
	var p0: Vector2 = Vector2(px, py)
	var c1: Vector2 = Vector2(px + lean * 0.2, py - h * 0.6)
	var p2: Vector2 = Vector2(px + lean, py - h)
	var trunk: PackedVector2Array = PackedVector2Array()
	for i in range(13):
		var t: float = i / 12.0
		trunk.append(p0.lerp(c1, t).lerp(c1.lerp(p2, t), t))
	palm_lines.append({"pts": trunk, "w": 10.0})
	var angles: Array = [-2.9, -2.4, -1.9, -1.2, -0.7, -0.2]
	for an in angles:
		var a: float = float(an)
		var ctrl: Vector2 = p2 + Vector2(cos(a) * 45.0, sin(a) * 45.0 - 12.0)
		var endp: Vector2 = p2 + Vector2(cos(a) * 78.0, sin(a) * 33.0 + 33.0)
		var fr: PackedVector2Array = PackedVector2Array()
		for i in range(9):
			var t2: float = i / 8.0
			fr.append(p2.lerp(ctrl, t2).lerp(ctrl.lerp(endp, t2), t2))
		palm_lines.append({"pts": fr, "w": 6.0})


func xf(pos: Vector2, rot: float = 0.0, sc: Vector2 = Vector2.ONE) -> void:
	draw_set_transform(pos + cam, rot, sc)


func ellipse_pts(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var p: PackedVector2Array = PackedVector2Array()
	for i in range(20):
		var a: float = TAU * i / 20.0
		p.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return p


func draw_background() -> void:
	xf(Vector2.ZERO)
	if arena_tex != null:
		draw_texture_rect(arena_tex, Rect2(0, 0, W, H), false)
		draw_rect(Rect2(0, 0, W, H), Color(0.05, 0.03, 0.12, 0.2))
		return
	var top: Color = Color(0.11, 0.08, 0.25)
	var mid: Color = Color(0.35, 0.16, 0.44)
	var hor: Color = Color(1.0, 0.60, 0.29)
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(W, 0), Vector2(W, 200), Vector2(0, 200)]), PackedColorArray([top, top, mid, mid]))
	draw_polygon(PackedVector2Array([Vector2(0, 200), Vector2(W, 200), Vector2(W, FLOOR_Y), Vector2(0, FLOOR_Y)]), PackedColorArray([mid, mid, hor, hor]))
	for s in stars:
		draw_rect(Rect2(s as Vector2, Vector2(2, 2)), Color(1, 0.93, 0.82, 0.7))
	draw_circle(Vector2(W * 0.5, FLOOR_Y - 96.0), 93.0, Color(1.0, 0.82, 0.48))
	for r in bld_far:
		draw_rect(r as Rect2, Color(0.23, 0.11, 0.34))
	for r2 in bld_near:
		draw_rect(r2 as Rect2, Color(0.14, 0.07, 0.26))
	for wr in wins:
		draw_rect(wr as Rect2, Color(1.0, 0.81, 0.44, 0.85))
	for pl in palm_lines:
		var d: Dictionary = pl
		draw_polyline(d["pts"] as PackedVector2Array, Color(0.08, 0.04, 0.16), float(d["w"]))
	draw_rect(Rect2(0, FLOOR_Y, W, H - FLOOR_Y), Color(0.20, 0.13, 0.35))
	draw_rect(Rect2(0, FLOOR_Y + 40.0, W, H - FLOOR_Y - 40.0), Color(0.12, 0.08, 0.22))
	for i in range(17):
		var lx: float = (i / 16.0) * W * 1.6 - W * 0.3
		draw_line(Vector2(W * 0.5 + (lx - W * 0.5) * 0.25, FLOOR_Y), Vector2(lx, H), Color(1.0, 0.54, 0.24, 0.25), 1.5)
	draw_line(Vector2(0, FLOOR_Y), Vector2(W, FLOOR_Y), Color(1.0, 0.54, 0.24, 0.85), 4.0)


# ---------------------------------------------------------------- dessin des combattants

func seg(a: Vector2, b: Vector2, col: Color, w: float) -> void:
	draw_line(a, b, col, w)
	draw_circle(a, w * 0.5, col)
	draw_circle(b, w * 0.5, col)


func draw_shadow(f: Fighter) -> void:
	xf(Vector2.ZERO)
	var h: float = maxf(0.0, GY - f.y)
	var al: float = maxf(0.1, 0.4 - h / 520.0)
	draw_colored_polygon(ellipse_pts(Vector2(f.x, GY + 3.0), maxf(15.0, f.fw * 1.05 - h * 0.1), 9.0), Color(0.03, 0.01, 0.08, al))


func draw_hero(f: Fighter) -> void:
	draw_shadow(f)
	var st: String = f.st
	var bob: float = 0.0
	if st == "idle" or st == "block":
		bob = sin(f.anim * 0.14) * 2.2
	var lean: float = 0.0
	var hip_y: float = -69.0
	var rot: float = 0.0
	var lunge: float = 0.0
	var dy: float = 0.0
	var kick: float = 0.0
	var bend: float = 10.5
	var fF: Vector2 = Vector2(24, 0)
	var fB: Vector2 = Vector2(-21, 0)
	var hF: Vector2 = Vector2(36, -117)
	var hB: Vector2 = Vector2(21, -111)
	if st == "walk":
		var ph: float = f.anim * 0.22
		fF = Vector2(15.0 + sin(ph) * 22.0, -maxf(0.0, cos(ph)) * 12.0)
		fB = Vector2(-15.0 - sin(ph) * 22.0, -maxf(0.0, -cos(ph)) * 12.0)
	elif st == "jump":
		fF = Vector2(21, -42)
		fB = Vector2(-6, -27)
		hF = Vector2(39, -138)
		hB = Vector2(18, -144)
		lean = 3.0
	elif st == "block":
		hip_y = -60.0
		fF = Vector2(21, 0)
		fB = Vector2(-21, 0)
		hF = Vector2(27, -132)
		hB = Vector2(33, -108)
		lean = 4.5
		bend = 15.0
	elif st == "hit":
		lean = -12.0
		rot = -0.14
		hF = Vector2(-6, -105)
		hB = Vector2(-21, -123)
		fF = Vector2(12, 0)
		fB = Vector2(-27, 0)
	elif st == "win":
		hF = Vector2(30, -168)
		hB = Vector2(-9, -162)
		dy = -absf(sin(f.anim * 0.18)) * 10.0
	elif st == "ko":
		var k: float = minf(1.0, f.ko_t / 14.0)
		rot = -k * 1.5
		dy = -14.0 * k
		fF = Vector2(27, -6)
		fB = Vector2(-12, -12)
		hF = Vector2(21, -93)
		hB = Vector2(-15, -87)
	elif st == "atk":
		var A: Dictionary = ATK[f.atk]
		var e: float = e_of(f)
		var reach: float = float(A["reach"])
		fB = Vector2(-21, 0)
		if f.atk == "punch":
			lean = e * 7.5
			lunge = e * 12.0
			hF = Vector2(27.0 + e * (reach + 6.0), -111)
			hB = Vector2(21, -108)
			fF = Vector2(30, 0)
			bend = 12.0
		else:
			lean = -e * 10.5
			hF = Vector2(15, -117)
			hB = Vector2(-27, -126)
			fB = Vector2(-15, 0)
			kick = e
			lunge = e * float(A["lunge"])
			fF = Vector2(21.0 + e * (reach + 9.0), -9.0 + e * (float(A["fy"]) + 9.0))
	var hip: Vector2 = Vector2(0, hip_y + bob * 0.4)
	var sh: Vector2 = Vector2(lean, hip_y - 48.0 + bob)
	var head: Vector2 = Vector2(lean + 3.0, hip_y - 69.0 + bob)
	var kF: Vector2 = Vector2((hip.x + fF.x) * 0.5 + bend, (hip.y + fF.y) * 0.5)
	if kick > 0.0:
		kF = Vector2((hip.x + fF.x) * 0.5 + 4.0, (hip.y + fF.y) * 0.5 - 15.0 * kick)
	var kB: Vector2 = Vector2((hip.x + fB.x) * 0.5 + bend - 4.0, (hip.y + fB.y) * 0.5)
	var eF: Vector2 = Vector2((sh.x + hF.x) * 0.5 - 3.0, (sh.y + hF.y) * 0.5 + 13.5)
	var eB: Vector2 = Vector2((sh.x + hB.x) * 0.5 - 3.0, (sh.y + hB.y) * 0.5 + 13.5)
	var mod: Color = Color.WHITE
	if st == "hit" or f.flash > 0:
		mod = Color(1.0, 0.6, 0.6)
	elif st == "ko":
		mod = Color(0.75, 0.75, 0.8)
	xf(Vector2(f.x + lunge * f.dir, f.y + dy), rot * f.dir, Vector2(f.dir, 1))
	# jambe arrière, bras arrière
	seg(hip, kB, PANT_D * mod, 16.0)
	seg(kB, fB, PANT_D * mod, 15.0)
	draw_circle(fB, 9.0, DARK)
	seg(sh, eB, SHIRT * mod * Color(0.85, 0.85, 0.88), 14.0)
	seg(eB, hB, SKIN * mod, 12.0)
	draw_circle(hB, 9.0, SKIN * mod)
	# torse : gilet gris, chemise blanche, noeud papillon
	seg(hip, sh, VEST * mod, 33.0)
	seg(hip.lerp(sh, 0.15), sh.lerp(hip, 0.05), SHIRT * mod, 11.0)
	var nk: Vector2 = sh.lerp(head, 0.3)
	draw_colored_polygon(PackedVector2Array([nk, nk + Vector2(-13, -8), nk + Vector2(-13, 8)]), DARK)
	draw_colored_polygon(PackedVector2Array([nk, nk + Vector2(13, -8), nk + Vector2(13, 8)]), DARK)
	draw_circle(nk, 4.0, DARK)
	# jambe avant
	seg(hip, kF, PANT * mod, 16.0)
	seg(kF, fF, PANT * mod, 15.0)
	draw_circle(fF, 9.0, DARK)
	# tête : le visage de la photo
	var r: float = 22.0
	if face_tex != null:
		draw_texture_rect(face_tex, Rect2(head.x - r, head.y - r, r * 2.0, r * 2.0), false, mod)
	else:
		draw_circle(head, r, SKIN * mod)
		draw_circle(head + Vector2(9, -2), 3.0, DARK)
	# bras avant
	seg(sh, eF, SHIRT * mod, 14.0)
	seg(eF, hF, SKIN * mod, 12.0)
	draw_circle(hF, 9.5, SKIN * mod)
	if f.flash > 0 and st == "block":
		draw_arc(Vector2(21, -99), 51.0, -1.1, 1.1, 16, Color(0.56, 0.83, 1.0, 0.85), 5.0)


func mon_alpha(m: Fighter) -> float:
	if m.st == "ko":
		return 1.0 - clampf(float(m.ko_t) / 50.0, 0.0, 1.0)
	return 1.0


func draw_blob(m: Fighter) -> void:
	draw_shadow(m)
	var e: float = e_of(m)
	var a: float = mon_alpha(m)
	var sq: float = sin(m.anim * 0.12) * 0.07
	var w: float = m.fw * (1.0 + sq + e * 0.25)
	var h: float = 82.0 * (1.0 - sq - e * 0.1)
	if m.st == "ko":
		h *= 1.0 - clampf(m.ko_t / 14.0, 0.0, 0.6)
	var body: Color = Color(0.35, 0.82, 0.32, a)
	var dark: Color = Color(0.13, 0.42, 0.14, a)
	if m.st == "hit" or m.flash > 0:
		body = Color(1.0, 0.9, 0.9, a)
	xf(Vector2(m.x + e * 14.0 * m.dir, m.y), 0.0, Vector2(m.dir, 1))
	var pts: PackedVector2Array = PackedVector2Array()
	for i in range(25):
		var an: float = PI + PI * i / 24.0
		pts.append(Vector2(cos(an) * w, sin(an) * h))
	draw_colored_polygon(pts, body)
	draw_polyline(pts, dark, 4.0)
	draw_line(Vector2(-w, 0), Vector2(w, 0), dark, 4.0)
	var ey: float = -h * 0.62
	draw_circle(Vector2(14, ey), 10.0, Color(1, 1, 1, a))
	draw_circle(Vector2(-6, ey), 10.0, Color(1, 1, 1, a))
	draw_circle(Vector2(17, ey), 4.5, Color(0.1, 0.05, 0.1, a))
	draw_circle(Vector2(-3, ey), 4.5, Color(0.1, 0.05, 0.1, a))
	draw_line(Vector2(-16, ey - 15.0), Vector2(0, ey - 7.0), dark, 4.0)
	draw_line(Vector2(26, ey - 15.0), Vector2(8, ey - 7.0), dark, 4.0)
	var my: float = -h * 0.28
	draw_line(Vector2(-6, my), Vector2(28, my), dark, 3.0)
	for i in range(3):
		var tx: float = -2.0 + i * 10.0
		draw_colored_polygon(PackedVector2Array([Vector2(tx, my), Vector2(tx + 7, my), Vector2(tx + 3.5, my + 8.0 + e * 6.0)]), Color(1, 1, 1, a))


func draw_skull(m: Fighter) -> void:
	draw_shadow(m)
	var e: float = e_of(m)
	var a: float = mon_alpha(m)
	var fl: float = -14.0 + sin(m.anim * 0.15) * 6.0
	var rot: float = 0.0
	var dy: float = fl
	if m.st == "ko":
		rot = -minf(1.0, m.ko_t / 14.0) * 1.4
		dy = -6.0
	var cloak: Color = Color(0.30, 0.14, 0.42, a)
	var bone: Color = Color(0.95, 0.93, 0.84, a)
	if m.st == "hit" or m.flash > 0:
		cloak = Color(1.0, 0.9, 0.9, a)
	xf(Vector2(m.x + e * 18.0 * m.dir, m.y + dy), rot * m.dir, Vector2(m.dir, 1))
	draw_colored_polygon(PackedVector2Array([Vector2(-30, 0), Vector2(-34, -70), Vector2(0, -112), Vector2(34, -70), Vector2(30, 0), Vector2(14, -10), Vector2(0, 0), Vector2(-14, -10)]), cloak)
	var reach: float = float(ATK[m.atk_name]["reach"])
	var hand: Vector2 = Vector2(30.0 + e * reach * 0.8, -62.0 - e * 18.0)
	seg(Vector2(14, -70), hand, bone, 7.0)
	for i in range(3):
		draw_line(hand, hand + Vector2(10, -6.0 + i * 6.0), bone, 3.0)
	draw_circle(Vector2(4, -104), 24.0, bone)
	draw_rect(Rect2(-8, -86, 26, 12), bone)
	draw_circle(Vector2(-4, -106), 7.0, Color(0.08, 0.03, 0.1, a))
	draw_circle(Vector2(14, -106), 7.0, Color(0.08, 0.03, 0.1, a))
	draw_circle(Vector2(-4, -106), 3.5, Color(1.0, 0.2, 0.2, a))
	draw_circle(Vector2(14, -106), 3.5, Color(1.0, 0.2, 0.2, a))
	for i in range(4):
		draw_line(Vector2(-4.0 + i * 6.0, -86), Vector2(-4.0 + i * 6.0, -74), Color(0.2, 0.15, 0.2, a), 1.5)


func draw_ogre(m: Fighter) -> void:
	draw_shadow(m)
	var e: float = e_of(m)
	var a: float = mon_alpha(m)
	var bob: float = sin(m.anim * 0.08) * 3.0
	var rot: float = 0.0
	if m.st == "ko":
		rot = -minf(1.0, m.ko_t / 14.0) * 1.4
	var skin: Color = Color(0.46, 0.62, 0.30, a)
	var dark: Color = Color(0.22, 0.32, 0.14, a)
	var cloth: Color = Color(0.45, 0.25, 0.15, a)
	if m.st == "hit" or m.flash > 0:
		skin = Color(1.0, 0.9, 0.9, a)
	xf(Vector2(m.x, m.y), rot * m.dir, Vector2(m.dir, 1))
	draw_rect(Rect2(-34, -62, 28, 62), cloth)
	draw_rect(Rect2(6, -62, 28, 62), cloth)
	draw_colored_polygon(PackedVector2Array([Vector2(-48, -62), Vector2(-56, -150 + bob), Vector2(-20, -185 + bob), Vector2(30, -185 + bob), Vector2(58, -150 + bob), Vector2(48, -62)]), skin)
	draw_rect(Rect2(-48, -74, 96, 14), Color(0.3, 0.16, 0.1, a))
	draw_line(Vector2(-40, -62), Vector2(-52, -110), skin, 18.0)
	draw_circle(Vector2(10, -196.0 + bob), 26.0, skin)
	draw_circle(Vector2(20, -200.0 + bob), 5.0, Color(1.0, 0.9, 0.3, a))
	draw_circle(Vector2(4, -200.0 + bob), 5.0, Color(1.0, 0.9, 0.3, a))
	draw_line(Vector2(-4, -212.0 + bob), Vector2(26, -206.0 + bob), dark, 4.0)
	draw_colored_polygon(PackedVector2Array([Vector2(16, -182.0 + bob), Vector2(27, -182.0 + bob), Vector2(25, -164.0 + bob)]), Color(1, 1, 0.9, a))
	var ang: float = lerpf(-2.2, 0.7, e)
	var dv: Vector2 = Vector2(cos(ang), sin(ang))
	var shoulder: Vector2 = Vector2(30, -160.0 + bob)
	var hand: Vector2 = shoulder + dv * 46.0
	var club_end: Vector2 = hand + dv * 96.0
	draw_line(shoulder, hand, skin, 20.0)
	draw_line(hand - dv * 10.0, club_end, Color(0.4, 0.25, 0.12, a), 16.0)
	draw_circle(club_end, 20.0, Color(0.35, 0.2, 0.1, a))


func draw_monster(m: Fighter) -> void:
	if m.kind == "blob":
		draw_blob(m)
	elif m.kind == "skull":
		draw_skull(m)
	else:
		draw_ogre(m)
	if m.st != "ko":
		xf(Vector2.ZERO)
		var bw: float = 64.0 if m.kind != "ogre" else 110.0
		var top: float = m.y - m.fh - 26.0
		draw_rect(Rect2(m.x - bw * 0.5, top, bw, 7.0), DARK)
		draw_rect(Rect2(m.x - bw * 0.5, top, bw * m.hp / m.max_hp, 7.0), Color(0.94, 0.28, 0.44))


# ---------------------------------------------------------------- interface

func txt(s: String, pos: Vector2, size: int, col: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, w: float = -1.0, outline: int = 0) -> void:
	if outline > 0:
		draw_string_outline(font, pos, s, align, w, size, outline, DARK)
	draw_string(font, pos, s, align, w, size, col)


func draw_bar(pos: Vector2, w: float, h: float, hp: float, ghost: float, mx: float, col: Color) -> void:
	draw_rect(Rect2(pos, Vector2(w, h)), Color(0.05, 0.04, 0.11))
	draw_rect(Rect2(pos, Vector2(w * ghost / mx, h)), INK)
	draw_rect(Rect2(pos, Vector2(w * hp / mx, h)), col)
	draw_rect(Rect2(pos, Vector2(w * hp / mx, h * 0.4)), Color(1, 1, 1, 0.25))
	draw_rect(Rect2(pos, Vector2(w, h)), Color(0.26, 0.2, 0.48), false, 3.0)


func draw_hud() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_bar(Vector2(24, 18), 380.0, 26.0, hero.hp, hero.ghost, hero.max_hp, Color(0.18, 0.77, 0.71))
	txt("TOI", Vector2(28, 66), 22, INK)
	txt("VAGUE %d / %d" % [mini(wave + 1, WAVES.size()), WAVES.size()], Vector2(0, 40), 26, INK, HORIZONTAL_ALIGNMENT_CENTER, W, 5)
	txt("KO : %d" % kills, Vector2(W - 28, 40), 26, ACCENT, HORIZONTAL_ALIGNMENT_RIGHT, -1.0, 5)
	if hero.cc >= 2:
		var col: Color = Color(1.0, 0.35, 0.49) if hero.cc >= 4 else ACCENT
		txt("COMBO x%d" % hero.cc, Vector2(28, 108), 34, col, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 7)


func draw_buttons() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for k in BTN:
		var r: Rect2 = BTN[k]
		var on: bool = bool(keys.get(k, false)) or int(buf.get(k, 0)) > 0
		var fill: Color = Color(1.0, 0.54, 0.24, 0.55) if on else Color(0.14, 0.10, 0.26, 0.45)
		draw_rect(r, fill)
		draw_rect(r, Color(0.45, 0.38, 0.8, 0.7), false, 3.0)
		txt(String(BTN_LABEL[k]), Vector2(r.position.x, r.position.y + r.size.y * 0.5 + 9.0), 26, INK, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)


func draw_banner() -> void:
	var s: String = ""
	var col: Color = INK
	var size: int = 76
	var age: int = phase_t
	if phase == "intro":
		if phase_t < 70:
			s = "VAGUE %d" % (wave + 1)
		else:
			s = "COMBAT !"
			col = ACCENT
			age = phase_t - 70
	elif phase == "clear":
		s = "VAGUE VAINCUE"
		size = 60
	if s == "":
		return
	var k: float = minf(1.0, age / 9.0)
	col.a = minf(1.0, k * 1.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	txt(s, Vector2(0, 230), int(size * (1.5 - 0.5 * k)), col, HORIZONTAL_ALIGNMENT_CENTER, W, 10)


func draw_overlay() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_rect(Rect2(0, 0, W, H), Color(0.09, 0.07, 0.17, 0.78))
	if phase == "menu":
		txt("DUEL ÉCLAIR", Vector2(0, 190), 96, INK, HORIZONTAL_ALIGNMENT_CENTER, W, 14)
		txt("Un héros contre des vagues de monstres", Vector2(0, 245), 28, Color(0.73, 0.67, 0.82), HORIZONTAL_ALIGNMENT_CENTER, W)
		txt("Pied x4 = enchaînement. Garde pour parer.", Vector2(0, 285), 24, Color(0.73, 0.67, 0.82), HORIZONTAL_ALIGNMENT_CENTER, W)
		txt("Touche l'écran pour jouer", Vector2(0, 380), 40, ACCENT, HORIZONTAL_ALIGNMENT_CENTER, W, 8)
	elif phase == "gameover":
		txt("DÉFAITE", Vector2(0, 220), 110, Color(1.0, 0.35, 0.49), HORIZONTAL_ALIGNMENT_CENTER, W, 14)
		txt("Monstres vaincus : %d" % kills, Vector2(0, 280), 32, INK, HORIZONTAL_ALIGNMENT_CENTER, W)
		if phase_t > 30:
			txt("Touche l'écran pour rejouer", Vector2(0, 380), 36, ACCENT, HORIZONTAL_ALIGNMENT_CENTER, W, 8)
	elif phase == "victory":
		txt("VICTOIRE !", Vector2(0, 220), 110, ACCENT, HORIZONTAL_ALIGNMENT_CENTER, W, 14)
		txt("Monstres vaincus : %d" % kills, Vector2(0, 280), 32, INK, HORIZONTAL_ALIGNMENT_CENTER, W)
		if phase_t > 30:
			txt("Touche l'écran pour rejouer", Vector2(0, 380), 36, ACCENT, HORIZONTAL_ALIGNMENT_CENTER, W, 8)


func _draw() -> void:
	draw_background()
	var alive: Array = []
	var dead: Array = []
	for mm in mons:
		var m: Fighter = mm
		if m.st == "ko":
			dead.append(m)
		else:
			alive.append(m)
	for d in dead:
		draw_monster(d)
	for a in alive:
		draw_monster(a)
	draw_hero(hero)
	xf(Vector2.ZERO)
	for sp in sparks:
		var s: Dictionary = sp
		var p: Vector2 = s["p"]
		var c: Color = s["c"]
		var l: int = int(s["l"])
		if s.has("ring"):
			draw_arc(p, (8 - l) * 4.0 + 6.0, 0.0, TAU, 20, Color(1, 1, 1, l / 8.0), 4.0)
		else:
			draw_rect(Rect2(p - Vector2(2, 2), Vector2(4, 4)), Color(c.r, c.g, c.b, minf(1.0, l / 12.0)))
	if phase == "intro" or phase == "fight" or phase == "clear":
		draw_hud()
		draw_banner()
		draw_buttons()
	else:
		draw_overlay()
