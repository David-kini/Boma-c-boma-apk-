extends Node
## Réglages globaux (qualité graphique). Autoload : GameSettings.
## 4 niveaux : 0 Ultra très bas, 1 Bas, 2 Normal, 3 Élevé.

signal quality_changed(level: int)

const QUALITY_NAMES: Array = ["Ultra très bas", "Bas", "Normal", "Élevé"]
const QUALITY_INFO: Array = [
	"Résolution 3D 50 %, 30 FPS, vue courte, sans ombres. Pour téléphones faibles.",
	"Résolution 3D 75 %, 30 FPS, vue moyenne, sans ombres.",
	"Résolution 100 %, 60 FPS, ombres proches.",
	"Résolution 100 %, 60 FPS, vue lointaine, ombres étendues.",
]
const VIEW_CHUNKS: Array = [2, 3, 5, 7]
const VIEW_DISTANCE: Array = [220.0, 320.0, 560.0, 900.0]
const SHADOW_DISTANCE: Array = [0.0, 0.0, 45.0, 90.0]
const RENDER_SCALE: Array = [0.5, 0.75, 1.0, 1.0]
const MAX_FPS: Array = [30, 30, 60, 60]
const FOG_DENSITY: Array = [0.0045, 0.003, 0.0016, 0.0011]
const USE_SKY: Array = [true, true, true, true]   # ciel léger (2 lectures de texture)
## nombre de carrés par tuile de terrain : [proche, moyen, loin]
const LOD_QUADS: Array = [[8, 4, 4], [16, 8, 4], [24, 12, 6], [32, 16, 8]]
const CONFIG_PATH: String = "user://settings.cfg"

var quality: int = 2


func _ready() -> void:
	quality = 0 if OS.has_feature("mobile") else 2
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(CONFIG_PATH) == OK:
		quality = clampi(int(cfg.get_value("graphics", "quality", quality)), 0, 3)
	_apply_engine()


func set_quality(level: int) -> void:
	quality = clampi(level, 0, 3)
	var cfg: ConfigFile = ConfigFile.new()
	cfg.load(CONFIG_PATH)
	cfg.set_value("graphics", "quality", quality)
	cfg.save(CONFIG_PATH)
	_apply_engine()
	quality_changed.emit(quality)


func cycle_quality() -> void:
	set_quality((quality + 1) % 4)


func _apply_engine() -> void:
	Engine.max_fps = int(MAX_FPS[quality])
	get_viewport().scaling_3d_scale = float(RENDER_SCALE[quality])


func quality_name() -> String:
	return String(QUALITY_NAMES[quality])


func quality_info(level: int) -> String:
	return String(QUALITY_INFO[level])


func view_chunks() -> int:
	return int(VIEW_CHUNKS[quality])


func view_distance() -> float:
	return float(VIEW_DISTANCE[quality])


func shadow_distance() -> float:
	return float(SHADOW_DISTANCE[quality])


func fog_density() -> float:
	return float(FOG_DENSITY[quality])


func use_sky() -> bool:
	return bool(USE_SKY[quality])


func lod_quads(lod: int) -> int:
	var q: Array = LOD_QUADS[quality]
	return int(q[lod])
