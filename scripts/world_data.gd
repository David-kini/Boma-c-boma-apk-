extends RefCounted
## Données du monde : 1414 m x 1414 m (environ 2 km²), zones, relief, chemins, lac et couleurs.
## Le relief est calculé par des fonctions de bruit : rien n'est stocké en mémoire.

const HALF: float = 707.0
const ARENA_RADIUS: float = 48.0
const VOLCANO_CENTER: Vector2 = Vector2(-400.0, 330.0)
const LAKE_CENTER: Vector2 = Vector2(170.0, 170.0)
const LAKE_RADIUS: float = 55.0
const WATER_LEVEL: float = -1.0
const SPAWN: Vector2 = Vector2(0.0, 70.0)
const CAMP: Vector2 = Vector2(9.0, 78.0)

## Zones : centre (x, z) et rayon en mètres.
const ZONES: Dictionary = {
	"arene": {"name": "Arène", "center": Vector2(0.0, 0.0), "radius": 55.0},
	"plaine": {"name": "Plaine de départ", "center": Vector2(0.0, 120.0), "radius": 240.0},
	"lac": {"name": "Lac Miroir", "center": Vector2(170.0, 170.0), "radius": 75.0},
	"ruines": {"name": "Ruines anciennes", "center": Vector2(-60.0, -260.0), "radius": 120.0},
	"rochers": {"name": "Zone rocheuse", "center": Vector2(420.0, 60.0), "radius": 130.0},
	"foret": {"name": "Forêt fantastique", "center": Vector2(330.0, -330.0), "radius": 170.0},
	"volcan": {"name": "Zone volcanique", "center": Vector2(-400.0, 330.0), "radius": 170.0},
	"monstres": {"name": "Zone des monstres", "center": Vector2(300.0, 330.0), "radius": 140.0},
	"boss": {"name": "Repaire du boss", "center": Vector2(-430.0, -400.0), "radius": 90.0},
}

## Chemins de terre : segments [départ, arrivée].
const PATHS: Array = [
	[Vector2(0.0, 48.0), Vector2(0.0, 140.0)],
	[Vector2(0.0, 140.0), Vector2(280.0, 310.0)],
	[Vector2(0.0, 140.0), Vector2(115.0, 150.0)],
	[Vector2(0.0, -48.0), Vector2(-60.0, -250.0)],
	[Vector2(-60.0, -250.0), Vector2(-395.0, -385.0)],
	[Vector2(48.0, 0.0), Vector2(400.0, 55.0)],
	[Vector2(34.0, -34.0), Vector2(310.0, -310.0)],
	[Vector2(-48.0, 0.0), Vector2(-320.0, 260.0)],
]

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
	# collines : douces dans la plaine, plus fortes ailleurs
	var hills: float = n_hill.get_noise_2d(x, z) * 16.0 + n_detail.get_noise_2d(x, z) * 1.4
	var calm: float = 1.0 - smoothstep(70.0, 300.0, r)
	hills *= 1.0 - calm * 0.72
	# chemins légèrement aplanis
	var pd: float = path_distance(x, z)
	hills *= 0.55 + 0.45 * smoothstep(2.0, 12.0, pd)
	# arène : sol parfaitement plat
	hills = lerpf(hills, 0.0, 1.0 - smoothstep(ARENA_RADIUS, ARENA_RADIUS + 40.0, r))
	# lac : cuvette peu profonde
	var ld: float = Vector2(x, z).distance_to(LAKE_CENTER)
	var lake: float = 1.0 - smoothstep(LAKE_RADIUS * 0.45, LAKE_RADIUS * 1.15, ld)
	hills = lerpf(hills, -2.4, lake)
	# montagnes qui ferment la zone de jeu sur tout le pourtour
	var ridge: float = 0.5 + 0.5 * n_ridge.get_noise_2d(x, z)
	var mountains: float = smoothstep(500.0, 690.0, edge) * (50.0 + 170.0 * ridge)
	# volcan : cône avec cratère
	var vd: float = Vector2(x, z).distance_to(VOLCANO_CENTER)
	var cone: float = 75.0 * (1.0 - smoothstep(0.0, 160.0, vd))
	cone -= 28.0 * (1.0 - smoothstep(0.0, 38.0, vd))
	return hills + mountains + maxf(cone, 0.0)


## Normale approchée du terrain (composante verticale : 1 = plat, 0 = mur).
func slope_ny(x: float, z: float) -> float:
	var e: float = 1.5
	var dx: float = height_at(x + e, z) - height_at(x - e, z)
	var dz: float = height_at(x, z + e) - height_at(x, z - e)
	return Vector3(-dx, 2.0 * e, -dz).normalized().y


func path_distance(x: float, z: float) -> float:
	var p: Vector2 = Vector2(x, z)
	var best: float = 99999.0
	for seg in PATHS:
		var a: Vector2 = seg[0]
		var b: Vector2 = seg[1]
		var q: Vector2 = Geometry2D.get_closest_point_to_segment(p, a, b)
		best = minf(best, p.distance_to(q))
	return best


func zone_weight(key: String, x: float, z: float) -> float:
	var zone: Dictionary = ZONES[key]
	var c: Vector2 = zone["center"]
	var rad: float = float(zone["radius"])
	var d: float = Vector2(x, z).distance_to(c)
	return 1.0 - smoothstep(rad * 0.6, rad, d)


## Endroits où l'on ne pose pas de décor aléatoire (arène, chemins, lac, lieux construits).
func is_reserved(x: float, z: float) -> bool:
	var p: Vector2 = Vector2(x, z)
	if p.length() < ARENA_RADIUS + 16.0:
		return true
	if p.distance_to(LAKE_CENTER) < LAKE_RADIUS * 1.15:
		return true
	if p.distance_to(CAMP) < 12.0 or p.distance_to(SPAWN) < 8.0:
		return true
	if p.distance_to(ZONES["boss"]["center"]) < 46.0:
		return true
	if p.distance_to(ZONES["ruines"]["center"]) < 18.0:
		return true
	if p.distance_to(ZONES["foret"]["center"]) < 15.0:
		return true
	if p.distance_to(VOLCANO_CENTER) < 40.0:
		return true
	return path_distance(x, z) < 4.5


func color_at(x: float, z: float, h: float, ny: float) -> Color:
	var r: float = Vector2(x, z).length()
	var n: float = n_color.get_noise_2d(x, z) * 0.5 + 0.5
	var grass: Color = Color(0.26, 0.46, 0.19).lerp(Color(0.38, 0.58, 0.24), n)
	var rock: Color = Color(0.42, 0.40, 0.40).lerp(Color(0.30, 0.28, 0.30), n)
	var c: Color = grass
	var f: float = zone_weight("foret", x, z)
	if f > 0.0:
		c = c.lerp(Color(0.10, 0.32, 0.26).lerp(Color(0.20, 0.22, 0.34), n), f * 0.85)
	var m: float = zone_weight("monstres", x, z)
	if m > 0.0:
		c = c.lerp(Color(0.46, 0.39, 0.24).lerp(Color(0.36, 0.30, 0.20), n), m)
	var v: float = zone_weight("volcan", x, z)
	if v > 0.0:
		c = c.lerp(Color(0.20, 0.13, 0.13).lerp(Color(0.12, 0.10, 0.10), n), v)
	var bo: float = zone_weight("boss", x, z)
	if bo > 0.0:
		c = c.lerp(Color(0.17, 0.11, 0.20), bo)
	var ru: float = zone_weight("ruines", x, z)
	if ru > 0.0:
		c = c.lerp(Color(0.40, 0.46, 0.25), ru * 0.6)
	var ro: float = zone_weight("rochers", x, z)
	if ro > 0.0:
		c = c.lerp(rock, ro * 0.8)
	# chemins de terre
	var pd: float = path_distance(x, z)
	c = c.lerp(Color(0.52, 0.43, 0.30), (1.0 - smoothstep(2.5, 4.5, pd)) * 0.9)
	# sable autour du lac
	var ld: float = Vector2(x, z).distance_to(LAKE_CENTER)
	c = c.lerp(Color(0.74, 0.68, 0.50), 1.0 - smoothstep(LAKE_RADIUS * 0.9, LAKE_RADIUS * 1.25, ld))
	# pentes rocheuses, neige en altitude
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
