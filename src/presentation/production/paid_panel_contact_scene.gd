extends Node3D
class_name PaidPanelContactScene

## Contact assistance only; canonical Inventory movement acceptance is unchanged.
const STALE_SECONDS: float = 0.5
var _remote: RemoteWorldRuntime
var _bodies: Dictionary = {}
var _boxes: Array = []
var _age: float = 0.0
var _scope: Array = []


func bind(remote: RemoteWorldRuntime) -> void:
	clear()
	if is_instance_valid(_remote):
		_remote.panel_contact_received.disconnect(_receive)
		_remote.panel_contact_cleared.disconnect(clear)
	_remote = remote
	if is_instance_valid(_remote):
		_remote.panel_contact_received.connect(_receive)
		_remote.panel_contact_cleared.connect(clear)


func _receive(envelope: Dictionary) -> void:
	if not is_instance_valid(_remote) or not _remote._authenticated or not _valid_transform():
		clear()
		return
	var decoded: ServiceResult = PaidPanelContactObservation.decode(envelope, _remote.world_id, _remote.region_id)
	if not decoded.is_success:
		clear()
		return
	_age = 0.0
	_scope = [_remote.world_id, _remote.region_id]
	var boxes: Array = decoded.value.geometry.boxes
	if boxes == _boxes: return
	clear()
	_scope = [_remote.world_id, _remote.region_id]
	_boxes = boxes.duplicate(true)
	for box in boxes:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var center: Array = box.center_millimetres
		var size: Array = box.size_millimetres
		body.position = ProceduralWorldInventoryPreview.DISPLAY_ORIGIN + Vector3(center[0], center[1], center[2]) / 1000.0
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(size[0], size[1], size[2]) / 1000.0
		collider.shape = shape
		body.add_child(collider)
		add_child(body)
		_bodies[box.surface_id] = body


func clear() -> void:
	for body in _bodies.values():
		# Immediately retire the physics RID, including inside a physics frame.
		PhysicsServer3D.body_set_space(body.get_rid(), RID())
		remove_child(body)
		body.queue_free()
	_bodies.clear()
	_boxes.clear()
	_age = 0.0


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= STALE_SECONDS or not _valid_transform() or not is_instance_valid(_remote) or not _remote._authenticated:
		clear()
	elif not _scope.is_empty() and _scope != [_remote.world_id, _remote.region_id]: clear()


func _valid_transform() -> bool:
	return is_inside_tree() and global_transform == Transform3D.IDENTITY


func _exit_tree() -> void:
	bind(null)
