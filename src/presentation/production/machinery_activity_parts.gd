extends RefCounted
class_name MachineryActivityParts

## Original MIT cosmetic geometry. No collision, physics, authority or persistence.
## The enclosing presentation owns lifetime. All motion stays inside frame bounds.
static func build(parent: Node3D, fitted: Array) -> Dictionary:
	var root := Node3D.new()
	root.name = "ObservedActivityParts"
	parent.add_child(root)
	var rotors: Array[Node3D] = []
	if fitted.has("extractor"):
		var rotor := Node3D.new()
		rotor.name = "ExtractorDrive"
		rotor.position = Vector3(0, 0.65, 0)
		root.add_child(rotor)
		for angle in [0.0, TAU / 3.0, TAU * 2.0 / 3.0]:
			var vane: MeshInstance3D = _box(rotor, Vector3(0.11, 0.04, 0.05), Vector3(0.13 * cos(angle), 0, 0.13 * sin(angle)), Color(0.9, 0.65, 0.2))
			vane.rotation.y = -angle
		rotor.set_meta("axis", Vector3.UP)
		rotors.append(rotor)
	if fitted.has("refinery"):
		var rotor := Node3D.new()
		rotor.name = "RefineryPumpDrive"
		rotor.position = Vector3(0, 0.6, 0.29)
		root.add_child(rotor)
		_box(rotor, Vector3(0.18, 0.035, 0.035), Vector3.ZERO, Color(0.7, 0.8, 0.85))
		_box(rotor, Vector3(0.035, 0.18, 0.035), Vector3.ZERO, Color(0.4, 0.65, 0.7))
		rotor.set_meta("axis", Vector3.BACK)
		rotors.append(rotor)
	var indicator: MeshInstance3D = _box(root, Vector3(0.13, 0.045, 0.018), Vector3(0.22, 0.22, -0.345), Color(0.65, 0.4, 0.7))
	indicator.name = "ActivityIndicator"
	var material: StandardMaterial3D = indicator.material_override
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return {"root": root, "rotors": rotors, "indicator": indicator}


static func present(parts: Dictionary, phase: float, color: Color) -> void:
	if not is_finite(phase): return
	for rotor in parts["rotors"]:
		rotor.basis = Basis(rotor.get_meta("axis"), phase)
	var material: StandardMaterial3D = parts["indicator"].material_override
	material.albedo_color = color


static func _box(parent: Node3D, size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.position = at
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	visual.material_override = material
	parent.add_child(visual)
	return visual
