extends Node3D
## Épée 3D (référence : épée d'éclair du concept art).
## Lame longue à bords dentelés (maillage généré), halo additif, garde dorée en ailes,
## gemme, poignée noire à bagues dorées, pommeau. Éclairs animés le long de la lame.
## element : "eclair" (bleu), "feu" (rouge-orange), "divin" (or) — pour les futures armes.
## Origine = centre de la poignée ; la lame pointe vers +Y.

const BLADE_START: float = 0.15
const BLADE_LEN: float = 1.15
const ARC_INTERVAL: float = 0.07

const ELEMENTS: Dictionary = {
	"eclair": {"core": Color(0.55, 0.80, 1.0), "glow": Color(0.10, 0.35, 1.0, 0.30), "arc": Color(0.75, 0.90, 1.0)},
	"feu": {"core": Color(1.0, 0.65, 0.30), "glow": Color(1.0, 0.30, 0.05, 0.30), "arc": Color(1.0, 0.6, 0.2)},
	"divin": {"core": Color(1.0, 0.90, 0.55), "glow": Color(1.0, 0.70, 0.15, 0.30), "arc": Color(1.0, 0.92, 0.6)},
}

@export var element: String = "eclair"
var arcs_enabled: bool = true
var _arc_mesh: ImmediateMesh
var _arc_mi: MeshInstance3D
var _arc_t: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	var e: Dictionary = ELEMENTS.get(element, ELEMENTS["eclair"])
	_build_blade(e)
	_build_hilt(e)
	_arc_mesh = ImmediateMesh.new()
	_arc_mi = MeshInstance3D.new()
	_arc_mi.mesh = _arc_mesh
	_arc_mi.material_override = _unshaded(e["arc"], true)
	_arc_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_arc_mi)


func _unshaded(c: Color, additive: bool) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if additive:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.no_depth_test = false
	return m


func _gold() -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = Color(0.93, 0.70, 0.26)
	m.metallic = 0.45
	m.roughness = 0.3
	return m


## Demi-largeur de la lame à la position t (0 = garde, 1 = pointe) : bords en zigzag.
func _half_width(tt: float) -> float:
	var w: float = 0.075 * (1.0 - 0.30 * tt)
	var zig: float = absf(fposmod(tt * 7.0, 1.0) - 0.5) * 2.0
	w += 0.022 * zig * (1.0 - tt)
	w *= 1.0 - smoothstep(0.82, 1.0, tt)
	return maxf(w, 0.002)


func _blade_mesh(scale_w: float, thick: float) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n: int = 28
	for i in range(n + 1):
		var tt: float = float(i) / float(n)
		var y: float = BLADE_START + tt * BLADE_LEN
		var w: float = _half_width(tt) * scale_w
		var th: float = thick * (1.0 - tt * 0.6)
		# section en losange : bord droit, arête avant, bord gauche, arête arrière
		st.add_vertex(Vector3(w, y, 0.0))
		st.add_vertex(Vector3(0.0, y, -th))
		st.add_vertex(Vector3(-w, y, 0.0))
		st.add_vertex(Vector3(0.0, y, th))
	for i in range(n):
		for j in range(4):
			var a: int = i * 4 + j
			var b: int = i * 4 + (j + 1) % 4
			var c: int = a + 4
			var d: int = b + 4
			for idx in [a, b, c, b, d, c]:
				st.add_index(idx)
	st.generate_normals()
	return st.commit()


func _build_blade(e: Dictionary) -> void:
	var core: MeshInstance3D = MeshInstance3D.new()
	core.name = "Lame"
	core.mesh = _blade_mesh(1.0, 0.014)
	core.material_override = _unshaded(e["core"], false)
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(core)
	var glow: MeshInstance3D = MeshInstance3D.new()
	glow.name = "Halo"
	glow.mesh = _blade_mesh(1.6, 0.025)
	glow.material_override = _unshaded(e["glow"], true)
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(glow)


func _add(mesh: Mesh, xf: Transform3D, mat: Material) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.transform = xf
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _build_hilt(e: Dictionary) -> void:
	var gold: StandardMaterial3D = _gold()
	var dark: StandardMaterial3D = StandardMaterial3D.new()
	dark.albedo_color = Color(0.06, 0.05, 0.06)
	dark.roughness = 0.6
	# poignée
	var grip: CylinderMesh = CylinderMesh.new()
	grip.top_radius = 0.018
	grip.bottom_radius = 0.02
	grip.height = 0.24
	grip.radial_segments = 8
	_add(grip, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 0.0)), dark)
	for y in [-0.08, 0.0, 0.08]:
		var band: CylinderMesh = CylinderMesh.new()
		band.top_radius = 0.022
		band.bottom_radius = 0.022
		band.height = 0.012
		band.radial_segments = 8
		_add(band, Transform3D(Basis.IDENTITY, Vector3(0.0, float(y), 0.0)), gold)
	# pommeau
	var pom: SphereMesh = SphereMesh.new()
	pom.radius = 0.032
	pom.height = 0.064
	pom.radial_segments = 8
	pom.rings = 5
	_add(pom, Transform3D(Basis.IDENTITY, Vector3(0.0, -0.14, 0.0)), gold)
	var spike: CylinderMesh = CylinderMesh.new()
	spike.top_radius = 0.0
	spike.bottom_radius = 0.016
	spike.height = 0.05
	spike.radial_segments = 5
	_add(spike, Transform3D(Basis(Vector3.RIGHT, PI), Vector3(0.0, -0.185, 0.0)), gold)
	# garde : bloc central + ailes (3 plumes de chaque côté)
	var block: BoxMesh = BoxMesh.new()
	block.size = Vector3(0.09, 0.06, 0.05)
	_add(block, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.14, 0.0)), gold)
	for side in [-1.0, 1.0]:
		var sx: float = float(side)
		for k in range(3):
			var length: float = 0.17 - 0.04 * float(k)
			var ang: float = (0.35 + 0.35 * float(k)) * sx
			var feather: BoxMesh = BoxMesh.new()
			feather.size = Vector3(length, 0.022, 0.018)
			var b: Basis = Basis(Vector3(0.0, 0.0, 1.0), ang)
			var dir: Vector3 = b * Vector3(sx, 0.0, 0.0)
			_add(feather, Transform3D(b, Vector3(0.04 * sx, 0.15 + 0.01 * float(k), 0.0) + dir * length * 0.5), gold)
		var tip: CylinderMesh = CylinderMesh.new()
		tip.top_radius = 0.0
		tip.bottom_radius = 0.016
		tip.height = 0.06
		tip.radial_segments = 4
		_add(tip, Transform3D(Basis(Vector3(0.0, 0.0, 1.0), -0.3 * sx - PI * 0.5 * sx),
			Vector3(0.21 * sx, 0.20, 0.0)), gold)
	# gemme (couleur de l'élément) des deux côtés de la garde
	var gem: SphereMesh = SphereMesh.new()
	gem.radius = 0.02
	gem.height = 0.04
	gem.radial_segments = 4
	gem.rings = 2
	for z in [-0.028, 0.028]:
		_add(gem, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.145, float(z))), _unshaded(e["glow"].lightened(0.3), false))


func _process(delta: float) -> void:
	if not arcs_enabled:
		return
	_arc_t -= delta
	if _arc_t > 0.0:
		return
	_arc_t = ARC_INTERVAL
	_rebuild_arcs()


## Éclairs : 3 rubans en zigzag le long des bords de la lame, redessinés 14 fois par seconde.
func _rebuild_arcs() -> void:
	_arc_mesh.clear_surfaces()
	_arc_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for _a in range(3):
		var side: float = -1.0 if _rng.randf() < 0.5 else 1.0
		var t0: float = _rng.randf_range(0.0, 0.5)
		var t1: float = minf(t0 + _rng.randf_range(0.25, 0.5), 0.95)
		var steps: int = 8
		var prev: Vector3 = Vector3.ZERO
		for i in range(steps + 1):
			var tt: float = lerpf(t0, t1, float(i) / float(steps))
			var w: float = _half_width(tt)
			var p: Vector3 = Vector3(side * (w + _rng.randf_range(-0.01, 0.06)), BLADE_START + tt * BLADE_LEN,
				_rng.randf_range(-0.02, 0.02))
			if i > 0:
				var wd: float = 0.006
				_arc_mesh.surface_add_vertex(prev + Vector3(0.0, 0.0, -wd))
				_arc_mesh.surface_add_vertex(prev + Vector3(0.0, 0.0, wd))
				_arc_mesh.surface_add_vertex(p + Vector3(0.0, 0.0, -wd))
				_arc_mesh.surface_add_vertex(prev + Vector3(0.0, 0.0, wd))
				_arc_mesh.surface_add_vertex(p + Vector3(0.0, 0.0, wd))
				_arc_mesh.surface_add_vertex(p + Vector3(0.0, 0.0, -wd))
				_arc_mesh.surface_add_vertex(prev + Vector3(-wd, 0.0, 0.0))
				_arc_mesh.surface_add_vertex(prev + Vector3(wd, 0.0, 0.0))
				_arc_mesh.surface_add_vertex(p + Vector3(-wd, 0.0, 0.0))
				_arc_mesh.surface_add_vertex(prev + Vector3(wd, 0.0, 0.0))
				_arc_mesh.surface_add_vertex(p + Vector3(wd, 0.0, 0.0))
				_arc_mesh.surface_add_vertex(p + Vector3(-wd, 0.0, 0.0))
			prev = p
	_arc_mesh.surface_end()
