extends RefCounted
## Sauvegarde de la progression (niveau, XP, arme, ailes) dans user://sauvegarde.cfg.

const PATH: String = "user://sauvegarde.cfg"


static func save(data: Dictionary) -> void:
	var cfg: ConfigFile = ConfigFile.new()
	for k in data:
		cfg.set_value("joueur", String(k), data[k])
	cfg.save(PATH)


static func load_data() -> Dictionary:
	var out: Dictionary = {}
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(PATH) != OK:
		return out
	for k in cfg.get_section_keys("joueur"):
		out[k] = cfg.get_value("joueur", k)
	return out
