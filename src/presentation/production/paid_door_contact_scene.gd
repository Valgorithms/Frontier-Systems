extends Node3D
class_name PaidDoorContactScene

## First-party ordinary box meshes. Display/contact assistance has no authority.
var _remote: RemoteWorldRuntime
var _boxes: Array = []
var _age: float = 0.0


func bind(remote: RemoteWorldRuntime) -> void:
	clear()
	if is_instance_valid(_remote):
		_remote.door_contact_received.disconnect(_receive)
		_remote.panel_contact_cleared.disconnect(clear)
	_remote = remote
	if is_instance_valid(remote):
		remote.door_contact_received.connect(_receive)
		remote.panel_contact_cleared.connect(clear)


func _receive(record: Dictionary) -> void:
	if not is_instance_valid(_remote) or not _remote._authenticated or global_transform != Transform3D.IDENTITY: clear(); return
	var decoded: ServiceResult = DoorContactObservation.decode(record, _remote.world_id, _remote.region_id)
	if not decoded.is_success: clear(); return
	_age = 0.0
	if decoded.value.boxes == _boxes: return
	clear()
	_boxes = decoded.value.boxes.duplicate(true)
	for box in _boxes:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		body.position = ProceduralWorldInventoryPreview.DISPLAY_ORIGIN + SpatialWallConstruction.point(box.center_millimetres) / 1000.0
		var shape := BoxShape3D.new()
		shape.size = SpatialWallConstruction.point(box.size_millimetres) / 1000.0
		var collider := CollisionShape3D.new()
		collider.shape = shape
		body.add_child(collider)
		var mesh := MeshInstance3D.new()
		var geometry := BoxMesh.new()
		geometry.size = shape.size
		mesh.mesh = geometry
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.35, 0.48, 0.54) if box.role == 3 else Color(0.16, 0.22, 0.25)
		mesh.material_override = material
		body.add_child(mesh)
		add_child(body)


func clear() -> void:
	for body in get_children():
		PhysicsServer3D.body_set_space(body.get_rid(), RID())
		remove_child(body)
		body.queue_free()
	_boxes.clear()
	_age = 0.0


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= 0.5 or global_transform != Transform3D.IDENTITY or not is_instance_valid(_remote) or not _remote._authenticated: clear()


func _exit_tree() -> void:
	bind(null)
