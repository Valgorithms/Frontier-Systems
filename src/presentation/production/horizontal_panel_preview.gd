extends Node3D
class_name HorizontalPanelPreview

signal panel_selected(panel_id: String)

## MIT first-party box geometry. Area3D picking adds no standing-floor collision.
var _panels: Dictionary = {}
var _ghost: MeshInstance3D
var _selected: String = ""


func observe(production: Dictionary) -> void:
	var surfaces: Array = []
	if production.get("schema_version") == 10 and HorizontalPanelObservation.valid(production.get("horizontal_panels"), production.get("state_revision")):
		surfaces = production["horizontal_panels"]["surfaces"]
	var retained: Dictionary = {}
	for surface in surfaces:
		var id: String = surface["surface_id"]
		retained[id] = true
		if not _panels.has(id):
			var area := Area3D.new()
			area.collision_layer = 0
			area.collision_mask = 0
			# Picking needs a layer, but Areas never provide body collision.
			area.collision_layer = 1
			var mesh: MeshInstance3D = _mesh(surface, Color("#739caa"))
			area.position = mesh.position
			mesh.position = Vector3.ZERO
			area.add_child(mesh)
			var collider := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = (mesh.mesh as BoxMesh).size
			collider.shape = shape
			area.add_child(collider)
			area.input_event.connect(func(_camera: Node, event: InputEvent, _position: Vector3, _normal: Vector3, _shape: int) -> void:
				if PlayerInputSettings.instance().accepts_gameplay_input() and event.is_action_pressed("world_select"): panel_selected.emit(id)
			)
			add_child(area)
			_panels[id] = area
	for id in _panels.keys():
		if retained.has(id): continue
		remove_child(_panels[id])
		_panels[id].queue_free()
		_panels.erase(id)
	if surfaces.is_empty(): present({}, "")


func present(candidate: Dictionary, selected_id: String) -> void:
	if is_instance_valid(_ghost):
		remove_child(_ghost)
		_ghost.queue_free()
		_ghost = null
	_selected = selected_id
	for id in _panels:
		var mesh := _panels[id].get_child(0) as MeshInstance3D
		(mesh.material_override as StandardMaterial3D).albedo_color = Color("#f1c75b") if id == selected_id else Color("#739caa")
	if candidate.is_empty() or not ConstructedRoomSurface.decode(candidate).is_success: return
	_ghost = _mesh(candidate, Color(0.25, 0.8, 0.9, 0.3))
	add_child(_ghost)


static func _mesh(surface: Dictionary, color: Color) -> MeshInstance3D:
	var bounds: Array = surface["bounds_millimetres"]
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(float(bounds[1] - bounds[0]) / 1000.0, 0.012, float(bounds[3] - bounds[2]) / 1000.0)
	mesh.mesh = box
	mesh.position = ProceduralWorldInventoryPreview.DISPLAY_ORIGIN + Vector3(float(bounds[0] + bounds[1]) / 2000.0, float(surface["height_millimetres"]) / 1000.0, float(bounds[2] + bounds[3]) / 2000.0)
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	if color.a < 1.0: material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material_override = material
	return mesh
