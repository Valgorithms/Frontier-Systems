extends RefCounted
class_name InventoryItemSilhouettes

## Original MIT primitive geometry. Display roles only, never capabilities/contents.
## Every part shares the proxy material so local selection highlights the whole item.
static func apply(proxy: MeshInstance3D, definition_id: String) -> void:
	match definition_id:
		"item.crowbar.prototype", "item.crowbar.fabricated":
			proxy.mesh = _box(Vector3(0.29, 0.035, 0.035))
			_part(proxy, _box(Vector3(0.08, 0.035, 0.035)), Vector3(-0.145, 0, 0.018), Vector3(0, 0.5, 0))
			_part(proxy, _box(Vector3(0.045, 0.025, 0.035)), Vector3(-0.177, 0, 0.042))
			_part(proxy, _box(Vector3(0.055, 0.018, 0.035)), Vector3(0.167, 0, -0.008), Vector3(0, 0.25, 0))
		"item.extractor.prototype", "item.extractor.fabricated":
			proxy.mesh = _box(Vector3(0.19, 0.075, 0.10))
			_part(proxy, _cylinder(0.037, 0.10), Vector3(0.11, 0.018, 0), Vector3(0, 0, PI / 2))
			_part(proxy, _cylinder(0.045, 0.025), Vector3(0.07, 0.018, 0), Vector3(0, 0, PI / 2))
			_part(proxy, _box(Vector3(0.045, 0.075, 0.07)), Vector3(-0.055, -0.042, 0))
		"item.resource-canister.prototype", "item.resource-canister.fabricated":
			proxy.mesh = _cylinder(0.066, 0.22)
			_part(proxy, _cylinder(0.076, 0.025), Vector3(0, -0.125, 0))
			_part(proxy, _cylinder(0.071, 0.025), Vector3(0, 0.105, 0))
			_part(proxy, _cylinder(0.035, 0.03), Vector3(0, 0.133, 0))


static func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


static func _cylinder(radius: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	return mesh


static func _part(proxy: MeshInstance3D, mesh: Mesh, location: Vector3, angles: Vector3 = Vector3.ZERO) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = proxy.material_override
	instance.position = location
	instance.rotation = angles
	proxy.add_child(instance)
