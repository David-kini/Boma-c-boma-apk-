extends Node
## Journal de diagnostic (autoload Diagnostic). Toutes les 5 s, écrit l'état du jeu dans
## user://diagnostic.txt (mémoire, FPS, position...). À la fermeture normale ou mise en
## arrière-plan, note « fin normale ». Au lancement suivant, si la partie précédente
## s'est arrêtée sans cette mention, le rapport est affiché sur l'écran titre.

const PATH: String = "user://diagnostic.txt"

var previous_crash: String = ""   # rapport de la session interrompue (vide si tout va bien)
var _t: float = 0.0
var _start_ms: int = 0
var _peak_vram: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_start_ms = Time.get_ticks_msec()
	var f: FileAccess = FileAccess.open(PATH, FileAccess.READ)
	if f != null:
		var txt: String = f.get_as_text()
		f.close()
		if txt != "" and not txt.contains("FIN NORMALE"):
			previous_crash = txt
	_write("DÉMARRAGE")


func _process(delta: float) -> void:
	_t -= delta
	if _t <= 0.0:
		_t = 5.0
		_write("EN COURS")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST or what == NOTIFICATION_WM_CLOSE_REQUEST:
		# bouton Retour / fermeture : on sauvegarde puis on quitte proprement
		_save_and_clean()
		_write("FIN NORMALE")
		get_tree().quit()
	elif what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_PREDELETE:
		_save_and_clean()
		_write("FIN NORMALE")
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		# retour dans le jeu : ralenti remis à 1 et réglages graphiques réappliqués
		Engine.time_scale = 1.0
		GameSettings.call("_apply_engine")
		_write("REPRISE")


func _save_and_clean() -> void:
	Engine.time_scale = 1.0
	if not is_inside_tree():
		return
	var ps: Array = get_tree().get_nodes_in_group("player")
	if not ps.is_empty() and ps[0].has_method("save_progress"):
		ps[0].call("save_progress")


func _write(state: String) -> void:
	var vram: float = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0
	_peak_vram = maxf(_peak_vram, vram)
	var line: String = "%s | durée %d s | %d FPS | RAM %d Mo | VRAM %d Mo (max %d) | objets 3D %d | qualité %d" % [
		state, (Time.get_ticks_msec() - _start_ms) / 1000, Engine.get_frames_per_second(),
		int(OS.get_static_memory_usage() / 1048576), int(vram), int(_peak_vram),
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), int(GameSettings.quality)]
	var ps: Array = get_tree().get_nodes_in_group("player") if is_inside_tree() else []
	if not ps.is_empty():
		var p: Node3D = ps[0] as Node3D
		line += " | pos %d,%d | état %s | ennemis %d" % [int(p.global_position.x), int(p.global_position.z),
			String(p.get("state")), get_tree().get_nodes_in_group("enemies").size()]
	var f: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(line)
		f.close()
