extends MeshInstance3D
class_name LocalWalkerVisual

## Original MIT neutral humanoid. Disposable geometry only, no pose or authority.
func _ready() -> void:
	name = "LocalWalkerVisual"
	var suit := StandardMaterial3D.new()
	suit.albedo_color = Color("#6cb8c5")
	suit.roughness = 0.85
	var trim := StandardMaterial3D.new()
	trim.albedo_color = Color("#294856")
	trim.roughness = 0.85
	var torso := BoxMesh.new()
	torso.size = Vector3(0.40, 0.62, 0.28)
	mesh = torso
	material_override = suit
	_part("Neck", Vector3(0.14, 0.08, 0.14), Vector3(0, 0.35, 0), trim)
	_part("Head", Vector3(0.30, 0.30, 0.28), Vector3(0, 0.54, 0), suit)
	_part("Visor", Vector3(0.23, 0.10, 0.02), Vector3(0, 0.56, -0.15), trim)
	_part("Pelvis", Vector3(0.34, 0.18, 0.26), Vector3(0, -0.36, 0), trim)
	for side in [-1.0, 1.0]:
		var suffix: String = "Left" if side < 0 else "Right"
		_part("Arm" + suffix, Vector3(0.12, 0.57, 0.14), Vector3(side * 0.28, 0.015, 0), suit)
		_part("Glove" + suffix, Vector3(0.13, 0.12, 0.15), Vector3(side * 0.28, -0.33, 0), trim)
		_part("Leg" + suffix, Vector3(0.14, 0.37, 0.18), Vector3(side * 0.10, -0.625, 0), suit)
		_part("Boot" + suffix, Vector3(0.16, 0.09, 0.24), Vector3(side * 0.10, -0.855, -0.03), trim)


func _part(part_name: String, dimensions: Vector3, location: Vector3, material: Material) -> void:
	var part := MeshInstance3D.new()
	part.name = part_name
	var box := BoxMesh.new()
	box.size = dimensions
	part.mesh = box
	part.material_override = material
	part.position = location
	add_child(part)
