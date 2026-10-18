extends RefCounted
## Données du monde : 1414 m x 1414 m (environ 2 km²), zones, relief et couleurs.
## Le relief est calculé par des fonctions de bruit : rien n'est stocké en mémoire.

const HALF: float = 707.0
const ARENA_RADIUS: float = 48.0
const VOLCANO_CENTER: Vector2 = Vector2(-400.0, 330.0)

## Zones : centre (x, z) et rayon en mètres. Elles serviront aux monstres, au boss
## et aux lieux secrets dans les phases suivantes.
const ZONES: Dictionary = {
	"arene": {"name": "Arène", "center": Vector2(0.0, 0.0), "radius": 55.0},
	"plaine": {"name": "Plaine de départ", "center": Vector2(0.0, 120.0), "radius": 240.0},
	"ruines": {"name": "Ruines anciennes", "center": Vector2(-60.0, -260.0), "radius": 120.0},
	"rochers": {"name": "Zone rocheuse", "center": Vector2(420.0, 60.0), "radius": 130.0},
	"foret": {"name": "Forêt fantastique", "center": Vector2(330.0, -330.0), "radius": 170.0},
	"volcan": {"name": "Zone volcanique", "center": Vector2(-400.0, 330.0), "radius": 170.0},
	"monstres": {"name": "Zone des monstres", "center": Vector2(300.0, 330.0), "radius": 140.0},
	"boss": {"name": "Repaire du boss", "center": Vector2(-430.0, -400.0), "radius": 90.0},
}

var n_hill: FastNoiseLite
var n_detail: FastNoiseLite
var n_ridge: FastNoiseLite
var n_color: FastNoiseLite


func _init() -> void:
	n_hill = _make_noise(1337, 0.0022, 3)
	n_detail = _make_noise(42, 0.02, 2)
	n_ridge = _make_noise(7, 0.004, 4)
	n_color = _make_noise(99, 0.05, 2)


func _make_noise(seed_value: int, freq: float, octaves: int) -> FastNoiseLite:
	var n: FastNoiseLite = FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.seed = seed_value
	n.frequency = freq
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = octaves
	return n


func height_at(x: float, z: float) -> float:
	var r: float = Vector2(x, z).length()
	var edge: float = maxf(absf(x), absf(z))
	# collines douces, presque aplaties autour de l'arène et de la plaine de départ
	var hills: float = n_hill.get_noise_2d(x, z) * 16.0 + n_detail.get_noise_2d(x, z) * 1.4
	var calm: float = 1.0 - smoothstep(70.0, 300.0, r)
	hills *= 1.0 - calm * 0.92
	# arène : sol parfaitement plat
	hills = lerpf(hills, 0.0, 1.0 - smoothstep(ARENA_RADIUS, ARENA_RADIUS + 40.0, r))
	# montagnes qui ferment la zone de jeu sur tout le pourtour
	var ridge: float = 0.5 + 0.5 * n_ridge.get_noise_2d(x, z)
	var mountains: float = smoothstep(500.0, 690.0, edge) * (50.0 + 170.0 * ridge)
	# volcan : cône avec cratère
	var vd: float = Vector2(x, z).distance_to(VOLCANO_CENTER)
	var cone: float = 75.0 * (1.0 - smoothstep(0.0, 160.0, vd))
	cone -= 28.0 * (1.0 - smoothstep(0.0, 38.0, vd))
	return hills + mountains + maxf(cone, 0.0)


func _zone_weight(key: String, x: float, z: float) -> float:
	var zone: Dictionary = ZONES[key]
	var c: Vector2 = zone["center"]
	var rad: float = float(zone["radius"])
	var d: float = Vector2(x, z).distance_to(c)
	return 1.0 - smoothstep(rad * 0.6, rad, d)


func color_at(x: float, z: float, h: float, ny: float) -> Color:
	var r: float = Vector2(x, z).length()
	var n: float = n_color.get_noise_2d(x, z) * 0.5 + 0.5
	var grass: Color = Color(0.26, 0.46, 0.19).lerp(Color(0.36, 0.56, 0.24), n)
	var rock: Color = Color(0.42, 0.40, 0.40).lerp(Color(0.30, 0.28, 0.30), n)
	var c: Color = grass
	var f: float = _zone_weight("foret", x, z)
	if f > 0.0:
		c = c.lerp(Color(0.12, 0.34, 0.24), f * 0.8)
	var v: float = _zone_weight("volcan", x, z)
	if v > 0.0:
		c = c.lerp(Color(0.20, 0.13, 0.13), v)
	var ro: float = _zone_weight("rochers", x, z)
	if ro > 0.0:
		c = c.lerp(rock, ro * 0.8)
	var slope: float = 1.0 - smoothstep(0.62, 0.86, ny)
	c = c.lerp(rock, slope)
	c = c.lerp(Color(0.85, 0.87, 0.92), smoothstep(150.0, 210.0, h) * (1.0 - slope * 0.5))
	var a: float = 1.0 - smoothstep(ARENA_RADIUS - 4.0, ARENA_RADIUS + 6.0, r)
	c = c.lerp(Color(0.52, 0.50, 0.50), a)
	return c


func zone_name_at(x: float, z: float) -> String:
	var best: String = "Terres sauvages"
	var best_score: float = 0.0
	for key in ZONES:
		var zone: Dictionary = ZONES[key]
		var c: Vector2 = zone["center"]
		var rad: float = float(zone["radius"])
		var inside: float = 1.0 - Vector2(x, z).distance_to(c) / rad
		if inside > best_score:
			best_score = inside
			best = String(zone["name"])
	return best
