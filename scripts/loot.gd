extends Node3D
## Objet à ramasser (butin des ennemis) : "potion" (soin) ou "or" (pièces).
## Flotte et tourne ; attiré vers le joueur à moins de 4,5 m, ramassé à son contact.
## Disparaît au bout de 60 s.

var kind: String = "or"
var amount: int = 1
var _t: float = 0.0
var _base_y: float = 0.0


func _ready() -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var m: StandardMaterial3D = StandardMaterial3D.new()
	if kind == "potion":
		var sm: SphereMesh = SphereMesh.new()
		sm.radius = 0.16
		sm.height = 0.34
		mi.mesh = sm
		m.albedo_color = Color(1.0, 0.15, 0.3)
		m.emission_enabled = true
		m.emission = Color(1.0, 0.1, 0.25)
		m.emission_energy_multiplier = 0.6
		var neck: MeshInstance3D = MeshInstance3D.new()
		var cm: CylinderMesh = CylinderMesh.new()
		cm.top_radius = 0.05
		cm.bottom_radius = 0.06
		cm.height = 0.12
		neck.mesh = cm
		neck.position = Vector3(0.0, 0.2, 0.0)
		var nm: StandardMaterial3D = StandardMaterial3D.new()
		nm.albedo_color = Color(0.85, 0.75, 0.6)
		neck.material_override = nm
		add_child(neck)
	else:
		var cyl: CylinderMesh = CylinderMesh.new()
		cyl.top_radius = 0.16
		cyl.bottom_radius = 0.16
		cyl.height = 0.04
		mi.mesh = cyl
		mi.rotation.x = PI * 0.5
		m.albedo_color = Color(1.0, 0.8, 0.2)
		m.metallic = 0.7
		m.roughness = 0.3
		m.emission_enabled = true
		m.emission = Color(1.0, 0.7, 0.1)
		m.emission_energy_multiplier = 0.4
	mi.material_override = m
	add_child(mi)


func _process(delta: float) -> void:
	if _t == 0.0:
		_base_y = position.y      # la position est fixée juste après l'ajout à la scène
	_t += delta
	position.y = _base_y + 0.5 + sin(_t * 3.0) * 0.12
	rotation.y += delta * 2.5
	if _t > 60.0:
		queue_free()
		return
	var ps: Array = get_tree().get_nodes_in_group("player")
	if ps.is_empty():
		return
	var p: Node3D = ps[0] as Node3D
	if bool(p.get("is_dead")):
		return
	var to: Vector3 = p.global_position + Vector3(0.0, 0.8, 0.0) - global_position
	var flat: float = Vector2(to.x, to.z).length()
	if flat < 1.4 and absf(to.y) < 2.5:
		p.call("add_item", kind, amount)
		queue_free()
	elif flat < 4.5 and absf(to.y) < 3.0:
		# aimant : le butin vole vers le joueur
		var step: Vector3 = Vector3(to.x, 0.0, to.z).normalized() * 7.0 * delta
		position += step
