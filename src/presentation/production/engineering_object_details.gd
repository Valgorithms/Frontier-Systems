extends RefCounted
class_name EngineeringObjectDetails

## Original MIT primitive geometry. Local coordinates remain inside existing
## machine/wall collision envelopes; no state, picking, timers or physics here.
const STEEL: Color = Color("#9aadb5")
const DARK: Color = Color("#263a45")
const EXTRACTOR: Color = Color("#dca542")
const PROCESS: Color = Color("#64a8b0")

static func box(parent: Node3D, size: Vector3, offset: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = offset
	node.material_override = material(color)
	parent.add_child(node)
	return node

static func material(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.72
	result.metallic = 0.25
	return result

static func cylinder(parent: Node3D, offset: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	mesh.rings = 1
	node.mesh = mesh
	node.position = offset
	node.material_override = material(color)
	parent.add_child(node)
	return node

static func extractor(parent: Node3D) -> void:
	var details := Node3D.new()
	details.name = "ExtractorDetails"
	parent.add_child(details)
	# Twin rails and crosshead distinguish a working mast from storage vessels.
	for x in [-0.29, 0.29]:
		box(details, Vector3(0.09, 0.5, 0.16), Vector3(x, 0.64, 0), STEEL)
	box(details, Vector3(0.68, 0.09, 0.2), Vector3(0, 0.895, 0), EXTRACTOR)
	cylinder(details, Vector3(0, 0.66, 0), 0.085, 0.38, DARK)
	cylinder(details, Vector3(0, 0.83, 0), 0.15, 0.13, EXTRACTOR)
	for y in [0.49, 0.55, 0.61, 0.67]:
		cylinder(details, Vector3(0, y, 0), 0.125, 0.035, STEEL)
	box(details, Vector3(0.56, 0.05, 0.5), Vector3(0, 0.425, 0), DARK)

static func refinery(parent: Node3D) -> void:
	var details := Node3D.new()
	details.name = "RefineryDetails"
	parent.add_child(details)
	# A tall separator and shorter receiver create a distinct process silhouette.
	for vessel in [{"x": -0.2, "h": 0.46, "r": 0.15}, {"x": 0.2, "h": 0.3, "r": 0.12}]:
		var x: float = vessel["x"]
		var height: float = vessel["h"]
		var radius: float = vessel["r"]
		cylinder(details, Vector3(x, 0.4 + height / 2, 0), radius, height, PROCESS)
		for y in [0.42, 0.4 + height - 0.025]:
			cylinder(details, Vector3(x, y, 0), radius + 0.018, 0.035, STEEL)
		cylinder(details, Vector3(x, 0.4 + height + 0.025, 0), radius * 0.7, 0.05, DARK)
	box(details, Vector3(0.4, 0.055, 0.06), Vector3(0, 0.79, 0.19), STEEL)
	box(details, Vector3(0.055, 0.12, 0.06), Vector3(0.2, 0.755, 0.19), STEEL)
	box(details, Vector3(0.055, 0.18, 0.06), Vector3(-0.2, 0.705, 0.19), STEEL)

static func wall(parent: Node3D, panel: MeshInstance3D) -> void:
	var inset := BoxMesh.new()
	inset.size = Vector3(0.84, 1.8, 0.064)
	panel.mesh = inset
	panel.material_override = material(Color("#687f89"))
	var details := Node3D.new()
	details.name = "WallDetails"
	parent.add_child(details)
	for x in [-0.46, 0.46]:
		box(details, Vector3(0.08, 2, 0.1), Vector3(x, 0, 0), STEEL)
	for y in [-0.95, 0.95]:
		box(details, Vector3(0.84, 0.1, 0.1), Vector3(0, y, 0), STEEL)
	for side in [-1.0, 1.0]:
		for y in [-0.3, 0.3]:
			box(details, Vector3(0.84, 0.025, 0.012), Vector3(0, y, side * 0.038), DARK)
