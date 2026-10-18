extends Node3D
## Tête 3D stylisée du héros, MODÉLISÉE (aucune photo collée).
## Référence : photo du joueur — crâne chauve et rond, teint albinos rosé, nez large,
## lèvres pleines, sourire, joues marquées, oreilles visibles, lunettes sans monture
## à verres teintés rose-violet avec barre dorée.
## Construction : sphère déformée (forme de crâne + mâchoire) puis "sculptée" par des
## bosses/creux gaussiens (arcades, orbites, nez, pommettes, joues, lèvres, menton).
## Couleurs de peau peintes par sommet (joues, lèvres, orbites). Yeux, paupières,
## sourcils, oreilles et lunettes sont de vrais volumes 3D.
## Repère : centre de la tête à l'origine, visage vers -Z, haut = +Y.

const RX: float = 0.088
const RY: float = 0.125
const RZ: float = 0.106
const RINGS: int = 56
const SEGS: int = 80

const SKIN: Color = Color(0.90, 0.68, 0.60)
const BLUSH: Color = Color(0.88, 0.52, 0.50)
const LIPS: Color = Color(0.78, 0.38, 0.40)
const SOCKET: Color = Color(0.82, 0.58, 0.54)
const BROW: Color = Color(0.93, 0.86, 0.68)
const IRIS: Color = Color(0.60, 0.67, 0.80)

## Sculpture : [x, y, sigma_x, sigma_y, amplitude] en mètres (tête de référence 0,08 x 0,115).
## Amplitude > 0 = bosse vers l'extérieur, < 0 = creux. "s" = symétrique (x et -x).
const FEATURES: Array = [
	["s", 0.033, 0.012, 0.016, 0.010, -0.012],   # orbites
	["s", 0.033, 0.033, 0.022, 0.006, 0.005],    # arcades sourcilières
	["c", 0.000, 0.030, 0.012, 0.010, 0.003],    # glabelle
	["c", 0.000, 0.004, 0.0070, 0.020, 0.013],   # arête du nez
	["c", 0.000, -0.022, 0.012, 0.010, 0.027],   # bout du nez (large)
	["s", 0.016, -0.027, 0.0075, 0.007, 0.013],  # ailes du nez
	["c", 0.000, -0.040, 0.010, 0.005, -0.002],  # sillon sous le nez
	["s", 0.050, -0.008, 0.016, 0.014, 0.006],   # pommettes
	["s", 0.040, -0.042, 0.015, 0.013, 0.009],   # joues (sourire)
	["c", 0.000, -0.052, 0.021, 0.0055, 0.008],  # lèvre supérieure
	["c", 0.000, -0.060, 0.023, 0.0025, -0.005], # ligne de la bouche
	["c", 0.000, -0.067, 0.018, 0.006, 0.009],   # lèvre inférieure (pleine)
	["s", 0.025, -0.056, 0.004, 0.004, -0.003],  # coins de la bouche (sourire)
	["c", 0.000, -0.094, 0.019, 0.012, 0.008],   # menton
	["s", 0.075, 0.030, 0.010, 0.020, -0.003],   # tempes
]

var _sx: float = RX / 0.08
var _sy: float = RY / 0.115


func _ready() -> void:
	_build_skin()
	_build_eyes()
	_build_brows()
	_build_mouth_nose()
	_build_ears()
	_build_glasses()


# ---------------------------------------------------------------- forme

func _gauss(x: float, y: float, cx: float, cy: float, sx: float, sy: float) -> float:
	var dx: float = (x - cx) / sx
	var dy: float = (y - cy) / sy
	return exp(-0.5 * (dx * dx + dy * dy))


## Déplacement (m) le long de la normale pour un point avant de coordonnées (x, y).
func _relief(x: float, y: float) -> float:
	var d: float = 0.0
	for f in FEATURES:
		var cx: float = float(f[1]) * _sx
		var cy: float = float(f[2]) * _sy
		var sx: float = float(f[3]) * _sx
		var sy: float = float(f[4]) * _sy
		var amp: float = float(f[5])
		d += amp * _gauss(x, y, cx, cy, sx, sy)
		if String(f[0]) == "s":
			d += amp * _gauss(x, y, -cx, cy, sx, sy)
	return d


## Forme de base : ellipsoïde avec mâchoire affinée, arrière du crâne bombé, visage aplati.
func _base(th: float, ph: float) -> Vector3:
	var p: Vector3 = Vector3(RX * sin(th) * cos(ph), RY * cos(th), RZ * sin(th) * sin(ph))
	if p.y < 0.0:
		var k: float = clampf(-p.y / RY, 0.0, 1.0)
		p.x *= 1.0 - 0.24 * k * k
		if p.z > 0.0:
			p.z *= 1.0 - 0.40 * k
	else:
		var up: float = p.y / RY
		p.x *= 1.0 + 0.07 * up * (1.0 - up)
		p.y *= 1.0 - 0.06 * up * up
		if p.z > 0.0:
			p.z *= 1.0 + 0.08 * up
	if p.z < 0.0:
		p.z *= 0.93
	return p


func _front_weight(p: Vector3) -> float:
	return smoothstep(0.0, 0.55, -p.z / RZ)


## Point final de la surface (forme + sculpture).
func _surface(th: float, ph: float) -> Vector3:
	var p: Vector3 = _base(th, ph)
	var n: Vector3 = Vector3(p.x / (RX * RX), p.y / (RY * RY), p.z / (RZ * RZ)).normalized()
	return p + n * _relief(p.x, p.y) * _front_weight(p)


## Point de la surface avant le plus proche de (x, y) (pour placer yeux, sourcils, lunettes).
func front_point(x: float, y: float) -> Vector3:
	var best: Vector3 = Vector3.ZERO
	var best_d: float = 1e9
	for i in range(RINGS + 1):
		var th: float = PI * float(i) / float(RINGS)
		for j in range(SEGS / 2, SEGS + 1):
			var ph: float = TAU * float(j) / float(SEGS)
			var b: Vector3 = _base(th, ph)
			if b.z > 0.0:
				continue
			var dd: float = (b.x - x) * (b.x - x) + (b.y - y) * (b.y - y)
			if dd < best_d:
				best_d = dd
				best = _surface(th, ph)
	return best


func _skin_color(p: Vector3) -> Color:
	var fw: float = _front_weight(p)
	var c: Color = SKIN
	var hollow: float = clampf(-_relief(p.x, p.y) * fw / 0.012, 0.0, 1.0)
	c = c.lerp(SOCKET.darkened(0.08), hollow * 0.5)
	var blush: float = (_gauss(p.x, p.y, 0.045 * _sx, -0.030 * _sy, 0.016, 0.014)
		+ _gauss(p.x, p.y, -0.045 * _sx, -0.030 * _sy, 0.016, 0.014)) * fw
	c = c.lerp(BLUSH, clampf(blush, 0.0, 1.0) * 0.55)
	var sock: float = (_gauss(p.x, p.y, 0.033 * _sx, 0.010 * _sy, 0.014, 0.010)
		+ _gauss(p.x, p.y, -0.033 * _sx, 0.010 * _sy, 0.014, 0.010)) * fw
	c = c.lerp(SOCKET, clampf(sock, 0.0, 1.0) * 0.45)
	var lip: float = maxf(_gauss(p.x, p.y, 0.0, -0.052 * _sy, 0.017, 0.0045),
		_gauss(p.x, p.y, 0.0, -0.067 * _sy, 0.015, 0.005)) * fw
	c = c.lerp(LIPS, clampf(lip * 1.3, 0.0, 1.0))
	var tip: float = _gauss(p.x, p.y, 0.0, -0.022 * _sy, 0.010, 0.008) * fw
	c = c.lerp(BLUSH, tip * 0.35)
	var nose_side: float = (_gauss(p.x, p.y, 0.022 * _sx, -0.020 * _sy, 0.005, 0.012)
		+ _gauss(p.x, p.y, -0.022 * _sx, -0.020 * _sy, 0.005, 0.012)) * fw
	c = c.lerp(SOCKET, nose_side * 0.35)
	return c


## Normale exacte de la surface (dérivées numériques), toujours orientée vers l'extérieur.
func _normal(th: float, ph: float, p: Vector3) -> Vector3:
	var e: float = 0.002
	if th < e or th > PI - e:
		return Vector3(0.0, signf(p.y), 0.0)
	var dth: Vector3 = _surface(th + e, ph) - _surface(th - e, ph)
	var dph: Vector3 = _surface(th, ph + e) - _surface(th, ph - e)
	var n: Vector3 = dth.cross(dph).normalized()
	if n.dot(p) < 0.0:
		n = -n
	return n


func _build_skin() -> void:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(RINGS + 1):
		var th: float = PI * float(i) / float(RINGS)
		for j in range(SEGS + 1):
			var ph: float = TAU * float(j) / float(SEGS)
			var p: Vector3 = _surface(th, ph)
			st.set_color(_skin_color(_base(th, ph)))
			st.set_normal(_normal(th, ph, p))
			st.add_vertex(p)
	for i in range(RINGS):
		for j in range(SEGS):
			var a: int = i * (SEGS + 1) + j
			var b: int = a + 1
			var c: int = a + SEGS + 1
			var d: int = c + 1
			for idx in [a, c, b, b, c, d]:
				st.add_index(idx)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Peau"
	mi.mesh = st.commit()
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.8
	m.metallic_specular = 0.15
	m.rim_enabled = true
	m.rim = 0.08
	m.rim_tint = 1.0
	m.disable_receive_shadows = true
	mi.material_override = m
	add_child(mi)


# ---------------------------------------------------------------- détails

func _mat(c: Color, rough: float = 0.6) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.disable_receive_shadows = true
	return m


func _sphere(r: float, seg: int = 12, rings: int = 8, hemi: bool = false) -> SphereMesh:
	var s: SphereMesh = SphereMesh.new()
	s.radius = r
	s.height = r if hemi else r * 2.0
	s.radial_segments = seg
	s.rings = rings
	s.is_hemisphere = hemi
	return s


func _add(mesh: Mesh, xf: Transform3D, mat: Material, node_name: String = "") -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.transform = xf
	mi.material_override = mat
	# les petits détails (yeux, lunettes, sourcils...) ne projettent pas d'ombre sur le visage
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if node_name != "":
		mi.name = node_name
	add_child(mi)
	return mi


func _build_eyes() -> void:
	var white: StandardMaterial3D = _mat(Color(0.97, 0.95, 0.93), 0.3)
	var iris: StandardMaterial3D = _mat(IRIS, 0.3)
	var pupil: StandardMaterial3D = _mat(Color(0.06, 0.05, 0.08), 0.2)
	var lash: StandardMaterial3D = _mat(Color(0.48, 0.36, 0.33), 0.8)
	var shine: StandardMaterial3D = _mat(Color(1.0, 1.0, 1.0), 0.1)
	shine.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for side in [-1.0, 1.0]:
		var sx: float = float(side)
		var s: Vector3 = front_point(0.033 * _sx * sx, 0.011 * _sy)
		var tilt: Basis = Basis(Vector3.UP, -0.30 * sx) * Basis(Vector3(0.0, 0.0, 1.0), 0.06 * sx)
		var c: Vector3 = s + Vector3(0.0, 0.0, 0.0015)
		# blanc de l'œil en amande (yeux plissés par le sourire)
		_add(_sphere(1.0, 16, 8), Transform3D(tilt * Basis.from_scale(Vector3(0.0128, 0.0062, 0.0055)), c), white, "Oeil")
		# iris, pupille, reflet
		var front: Vector3 = tilt * Vector3(0.0, 0.0, -1.0)
		var ic: Vector3 = c + front * 0.0046 + Vector3(0.0, 0.0006, 0.0)
		_add(_sphere(1.0, 14, 6), Transform3D(tilt * Basis.from_scale(Vector3(0.0050, 0.0050, 0.0016)), ic), iris)
		_add(_sphere(1.0, 10, 5), Transform3D(tilt * Basis.from_scale(Vector3(0.0022, 0.0022, 0.0010)), ic + front * 0.0010), pupil)
		_add(_sphere(1.0, 6, 4), Transform3D(tilt * Basis.from_scale(Vector3(0.0010, 0.0010, 0.0006)),
			ic + front * 0.0016 + tilt * Vector3(0.0016, 0.0016, 0.0)), shine)
		# ligne de cils (paupière supérieure) en 3 segments courbés
		for k in range(3):
			var kk: float = float(k - 1)
			var bm: BoxMesh = BoxMesh.new()
			bm.size = Vector3(0.0105, 0.0019, 0.0030)
			var lp: Vector3 = c + tilt * Vector3(0.0085 * kk, 0.0056 - 0.0016 * absf(kk), -0.0030)
			_add(bm, Transform3D(tilt * Basis(Vector3(0.0, 0.0, 1.0), -0.38 * kk), lp), lash)


func _build_brows() -> void:
	var mat: StandardMaterial3D = _mat(BROW.darkened(0.12), 0.8)
	for side in [-1.0, 1.0]:
		var sx: float = float(side)
		for k in range(3):
			var x: float = (0.020 + 0.011 * float(k)) * _sx * sx
			var y: float = (0.034 + 0.003 * float(k) - 0.004 * float(k * k) * 0.5) * _sy
			var p: Vector3 = front_point(x, y) + Vector3(0.0, 0.0, -0.0015)
			var bm: BoxMesh = BoxMesh.new()
			bm.size = Vector3(0.0128, 0.0042, 0.0035)
			var tilt: Basis = Basis(Vector3(0.0, 0.0, 1.0), (0.12 - 0.12 * float(k)) * sx) * Basis(Vector3.UP, 0.25 * sx * float(k))
			_add(bm, Transform3D(tilt, p), mat)


func _build_mouth_nose() -> void:
	var dark: StandardMaterial3D = _mat(Color(0.42, 0.20, 0.22), 0.8)
	var nostril: StandardMaterial3D = _mat(Color(0.55, 0.32, 0.30), 0.8)
	for side in [-1.0, 1.0]:
		var sx: float = float(side)
		var np: Vector3 = front_point(0.0085 * _sx * sx, -0.031 * _sy)
		_add(_sphere(1.0, 8, 5), Transform3D(Basis(Vector3.RIGHT, 0.5) * Basis.from_scale(Vector3(0.0042, 0.0018, 0.0030)),
			np + Vector3(0.0, -0.001, 0.003)), nostril)
	# sourire : 3 segments, coins relevés
	for k in range(3):
		var kk: float = float(k - 1)
		var x: float = 0.0105 * kk * _sx
		var y: float = (-0.0600 + 0.0035 * absf(kk)) * _sy
		var mp: Vector3 = front_point(x, y) + Vector3(0.0, 0.0, -0.0006)
		var bm: BoxMesh = BoxMesh.new()
		bm.size = Vector3(0.0125 if k == 1 else 0.0105, 0.0016, 0.0025)
		var yaw: float = 0.35 * kk
		_add(bm, Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3(0.0, 0.0, 1.0), 0.32 * kk), mp), dark)


func _build_ears() -> void:
	var skin: StandardMaterial3D = _mat(SKIN, 0.6)
	var inner: StandardMaterial3D = _mat(SKIN.lerp(BLUSH, 0.6), 0.7)
	for side in [-1.0, 1.0]:
		var sx: float = float(side)
		var base: Vector3 = Vector3(RX * 0.95 * sx, -0.008, 0.008)
		var rot: Basis = Basis(Vector3.UP, 0.30 * sx) * Basis(Vector3(0.0, 0.0, 1.0), -0.10 * sx)
		_add(_sphere(1.0, 14, 10), Transform3D(rot * Basis.from_scale(Vector3(0.0085, 0.029, 0.018)),
			base + Vector3(0.005 * sx, 0.0, 0.0)), skin, "Oreille")
		_add(_sphere(1.0, 12, 8), Transform3D(rot * Basis.from_scale(Vector3(0.004, 0.018, 0.010)),
			base + Vector3(0.0105 * sx, 0.003, -0.001)), inner)


func _build_glasses() -> void:
	var gold: StandardMaterial3D = _mat(Color(0.93, 0.72, 0.30), 0.25)
	gold.metallic = 0.6
	var lens: StandardMaterial3D = StandardMaterial3D.new()
	lens.albedo_color = Color(0.78, 0.52, 0.82, 0.42)
	lens.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	lens.roughness = 0.05
	lens.metallic = 0.3
	lens.rim_enabled = true
	lens.rim = 0.6
	var disc: CylinderMesh = CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0
	disc.height = 1.0
	disc.radial_segments = 28
	var eye_y: float = 0.011 * _sy
	var lens_z: float = front_point(0.0, eye_y).z - 0.013
	var bar_y: float = eye_y + 0.0155
	var outer_x: float = 0.0
	for side in [-1.0, 1.0]:
		var sx: float = float(side)
		var lx: float = 0.034 * _sx * sx
		var wrap: Basis = Basis(Vector3.UP, -0.22 * sx)
		var b: Basis = wrap * Basis(Vector3.RIGHT, PI * 0.5) * Basis.from_scale(Vector3(0.025, 0.0012, 0.0175))
		var lp: Vector3 = Vector3(lx, eye_y - 0.001, lens_z + 0.004 * absf(sx) + 0.0035)
		_add(disc, Transform3D(b, lp), lens, "Verre")
		outer_x = absf(lx) + 0.024
		# charnière dorée au coin extérieur
		var hinge: BoxMesh = BoxMesh.new()
		hinge.size = Vector3(0.008, 0.005, 0.004)
		_add(hinge, Transform3D(wrap, Vector3(outer_x * sx, bar_y - 0.002, lens_z + 0.010)), gold)
		# branche jusqu'à l'oreille
		var a: Vector3 = Vector3(outer_x * sx, bar_y - 0.002, lens_z + 0.012)
		var e: Vector3 = Vector3((RX * 0.97) * sx, bar_y - 0.006, 0.010)
		var mid: Vector3 = (a + e) * 0.5
		var dir: Vector3 = e - a
		var temple: BoxMesh = BoxMesh.new()
		temple.size = Vector3(0.0028, 0.0035, dir.length())
		var yaw: float = atan2(dir.x, dir.z)
		_add(temple, Transform3D(Basis(Vector3.UP, yaw), mid), gold)
		# plaquette de nez
		var pad: BoxMesh = BoxMesh.new()
		pad.size = Vector3(0.002, 0.004, 0.0015)
		_add(pad, Transform3D(Basis.IDENTITY, Vector3(0.010 * sx, eye_y - 0.008, lens_z + 0.008)), gold)
	# barre dorée supérieure (style sans monture de la photo)
	var bar: BoxMesh = BoxMesh.new()
	bar.size = Vector3(outer_x * 2.0, 0.0028, 0.0028)
	_add(bar, Transform3D(Basis.IDENTITY, Vector3(0.0, bar_y, lens_z + 0.002)), gold, "Barre")
