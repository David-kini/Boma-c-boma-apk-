extends Node
## Sons du jeu. Autoload : Sfx.  Utilisation : Sfx.play("hit")
## Si un fichier Assets/Audio/<nom>.ogg ou .wav existe, il est utilisé ; sinon un son
## court est synthétisé au démarrage (aucun fichier nécessaire, très léger).
## Musique : Assets/Audio/musique.ogg (jouée en boucle si présente).

const NAMES: Array = ["swing", "hit", "lightning", "jump", "levelup", "fly", "divine", "hurt", "enemy_die",
	"jump2", "longjump", "shoot", "teleport", "thunder", "ulti_charge", "ulti_boom", "rain"]
const LOOPS: Array = ["rain"]
const RATE: int = 22050

var streams: Dictionary = {}
var _players: Array = []
var _next: int = 0
var volume_db: float = -6.0
var _loops: Dictionary = {}       # nom -> AudioStreamPlayer en boucle


func _ready() -> void:
	for i in range(8):
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	for n in NAMES:
		streams[n] = _load_or_make(String(n))
	var music_path: String = "res://Assets/Audio/musique.ogg"
	if ResourceLoader.exists(music_path):
		var mp: AudioStreamPlayer = AudioStreamPlayer.new()
		mp.stream = load(music_path)
		mp.volume_db = -14.0
		add_child(mp)
		mp.play()


func play(sound: String, pitch: float = 1.0) -> void:
	if not streams.has(sound):
		return
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = streams[sound]
	p.pitch_scale = pitch * randf_range(0.94, 1.06)
	p.volume_db = volume_db
	p.play()


## Son d'ambiance en boucle (pluie) : volume 0..1, 0 = arrêt.
func set_loop(sound: String, level: float) -> void:
	if not streams.has(sound):
		return
	var p: AudioStreamPlayer = _loops.get(sound, null)
	if level <= 0.01:
		if p != null and p.playing:
			p.stop()
		return
	if p == null:
		p = AudioStreamPlayer.new()
		p.stream = streams[sound]
		add_child(p)
		_loops[sound] = p
	p.volume_db = volume_db - 10.0 + linear_to_db(clampf(level, 0.01, 1.0))
	if not p.playing:
		p.play()


func _load_or_make(n: String) -> AudioStream:
	for ext in [".ogg", ".wav"]:
		var path: String = "res://Assets/Audio/" + n + ext
		if ResourceLoader.exists(path):
			return load(path) as AudioStream
	return _synth(n)


## Synthèse simple : bruit filtré / sinus avec enveloppe.
func _synth(n: String) -> AudioStreamWAV:
	var dur: float = 0.25
	match n:
		"swing": dur = 0.22
		"hit": dur = 0.18
		"lightning": dur = 0.45
		"jump": dur = 0.2
		"levelup": dur = 0.7
		"fly": dur = 0.5
		"divine": dur = 0.9
		"hurt": dur = 0.25
		"enemy_die": dur = 0.4
		"jump2": dur = 0.3
		"longjump": dur = 0.45
		"shoot": dur = 0.35
		"teleport": dur = 0.4
		"thunder": dur = 2.2
		"ulti_charge": dur = 0.9
		"ulti_boom": dur = 1.2
		"rain": dur = 2.0
	var count: int = int(dur * RATE)
	var data: PackedByteArray = PackedByteArray()
	data.resize(count * 2)
	var lp: float = 0.0
	var lp2: float = 0.0
	var phase: float = 0.0
	var phase2: float = 0.0
	for i in range(count):
		var t: float = float(i) / RATE
		var u: float = t / dur
		var env: float = (1.0 - u) * minf(1.0, t * 200.0)
		var v: float = 0.0
		var noise: float = randf_range(-1.0, 1.0)
		match n:
			"swing":
				var cut: float = lerpf(0.05, 0.5, sin(u * PI))
				lp += (noise - lp) * cut
				v = lp * 1.4
			"hit":
				phase += TAU * lerpf(170.0, 55.0, u) / RATE
				lp += (noise - lp) * 0.3
				var snap: float = noise * maxf(0.0, 1.0 - t * 60.0)
				v = sin(phase) * 0.8 + lp * 0.5 + snap * 0.9
				env = pow(1.0 - u, 2.0)
			"lightning":
				lp += (noise - lp) * 0.6
				v = lp * (0.6 + 0.4 * sign(sin(t * 90.0)))
				env = pow(1.0 - u, 1.5)
			"jump":
				phase += TAU * lerpf(220.0, 480.0, u) / RATE
				v = sin(phase) * 0.5
			"levelup":
				var notes: Array = [523.0, 659.0, 784.0, 1046.0]
				var f: float = notes[mini(int(u * 4.0), 3)]
				phase += TAU * f / RATE
				v = sin(phase) * 0.45 + sin(phase * 2.0) * 0.15
				env = 1.0 - fmod(u * 4.0, 1.0) * 0.6
			"fly":
				var cut2: float = 0.08 + 0.1 * sin(u * PI * 6.0)
				lp += (noise - lp) * cut2
				v = lp * 2.0
			"divine":
				phase += TAU * lerpf(200.0, 800.0, u) / RATE
				lp += (noise - lp) * 0.2
				v = sin(phase) * 0.4 + sin(phase * 1.5) * 0.2 + lp * 0.2
				env = sin(u * PI)
			"hurt":
				phase += TAU * lerpf(300.0, 140.0, u) / RATE
				v = (1.0 if sin(phase) > 0.0 else -1.0) * 0.35
			"enemy_die":
				phase += TAU * lerpf(400.0, 80.0, u) / RATE
				lp += (noise - lp) * 0.25
				v = sin(phase) * 0.4 + lp * 0.4
			"jump2":
				# double saut : sifflement montant + souffle
				phase += TAU * lerpf(300.0, 900.0, u) / RATE
				lp += (noise - lp) * lerpf(0.05, 0.4, u)
				v = sin(phase) * 0.35 + lp * 0.6
				env = sin(u * PI)
			"longjump":
				# saut long : grand souffle d'air
				var cut3: float = lerpf(0.04, 0.25, sin(u * PI))
				lp += (noise - lp) * cut3
				phase += TAU * lerpf(180.0, 260.0, u) / RATE
				v = lp * 1.6 + sin(phase) * 0.15
				env = sin(u * PI) * (1.0 - u * 0.4)
			"shoot":
				# vague d'énergie : zap descendant + crépitement
				phase += TAU * lerpf(1400.0, 300.0, u) / RATE
				phase2 += TAU * lerpf(700.0, 150.0, u) / RATE
				lp += (noise - lp) * 0.5
				v = sin(phase) * 0.35 + sin(phase2) * 0.25 + lp * 0.3 * (1.0 if sin(t * 260.0) > 0.0 else 0.2)
				env = pow(1.0 - u, 1.5)
			"teleport":
				# téléportation : balayage rapide aller-retour, scintillant
				var f2: float = lerpf(200.0, 1600.0, sin(u * PI))
				phase += TAU * f2 / RATE
				phase2 += TAU * f2 * 1.5 / RATE
				v = (sin(phase) * 0.35 + sin(phase2) * 0.2) * (0.6 + 0.4 * sin(t * 90.0))
				env = sin(u * PI)
			"thunder":
				# tonnerre : craquement puis grondement grave
				lp += (noise - lp) * 0.06
				lp2 += (lp - lp2) * 0.08
				var crack: float = noise * maxf(0.0, 1.0 - t * 8.0)
				v = lp2 * 6.0 * (0.7 + 0.3 * sin(t * 7.0)) + crack * 0.8
				env = minf(1.0, t * 30.0) * pow(1.0 - u, 1.2)
			"ulti_charge":
				# charge de l'attaque finale : montée électrique
				phase += TAU * lerpf(80.0, 600.0, u * u) / RATE
				lp += (noise - lp) * 0.3
				v = sin(phase) * 0.4 + sin(phase * 2.01) * 0.2 + lp * 0.25 * u
				env = minf(1.0, u * 3.0) * (1.0 - smoothstep(0.85, 1.0, u))
			"ulti_boom":
				# explosion finale : coup grave + souffle
				phase += TAU * lerpf(90.0, 30.0, u) / RATE
				lp += (noise - lp) * 0.12
				v = sin(phase) * 0.8 + lp * 1.2
				env = pow(1.0 - u, 2.0)
			"rain":
				# pluie : bruit doux et gouttes, en boucle
				lp += (noise - lp) * 0.35
				lp2 += (lp - lp2) * 0.5
				var drop: float = 0.0
				if randf() < 0.002:
					drop = randf_range(0.3, 0.8)
				v = (lp - lp2) * 1.5 + drop * noise
				env = 1.0
		var s: int = int(clampf(v * env, -1.0, 1.0) * 26000.0)
		data.encode_s16(i * 2, s)
	var w: AudioStreamWAV = AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if LOOPS.has(n):
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = count
	return w
