extends Node
## Réglages globaux (qualité graphique). Autoload : GameSettings.

signal quality_changed(level: int)

const QUALITY_NAMES: Array = ["Bas", "Moyen", "Élevé"]
const VIEW_CHUNKS: Array = [3, 5, 7]
const VIEW_DISTANCE: Array = [320.0, 560.0, 900.0]
const SHADOW_DISTANCE: Array = [0.0, 45.0, 90.0]
const CONFIG_PATH: String = "user://settings.cfg"

var quality: int = 0


func _ready() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(CONFIG_PATH) == OK:
		quality = clampi(int(cfg.get_value("graphics", "quality", 0)), 0, 2)


func set_quality(level: int) -> void:
	quality = clampi(level, 0, 2)
	var cfg: ConfigFile = ConfigFile.new()
	cfg.load(CONFIG_PATH)
	cfg.set_value("graphics", "quality", quality)
	cfg.save(CONFIG_PATH)
	quality_changed.emit(quality)


func cycle_quality() -> void:
	set_quality((quality + 1) % 3)


func quality_name() -> String:
	return String(QUALITY_NAMES[quality])


func view_chunks() -> int:
	return int(VIEW_CHUNKS[quality])


func view_distance() -> float:
	return float(VIEW_DISTANCE[quality])


func shadow_distance() -> float:
	return float(SHADOW_DISTANCE[quality])
