extends Node3D
class_name ProceduralWorldInventoryPreview

## Native placeholder art derived from scoped storage observations, not physical items.
signal item_selected(container_id: String, item_id: String)
signal pickup_requested(container_id: String, item_id: String)
const MAX_VISIBLE_ITEMS_PER_CONTAINER: int = 8
# Two items per original-size bay preserve habitat rim/support decoration.
const TRAY_COLUMNS: int = 4
const TRAY_COLUMN_PITCH: float = 0.46
const TRAY_ROW_PITCH: float = 0.7
const TRAY_BAY_PITCH: float = 1.1
const TRAY_BAY_SIZE := Vector3(1.0, 0.08, 0.6)
const TRAY_SIZE := Vector3(2.1, 0.08, 1.3)
const DISPLAY_ORIGIN := Vector3(-6.0, 0.0, 2.0)
var _record: Dictionary = {"schema_version": 2, "inventory_revision": 0, "containers": []}
var _rendered: Node3D
var _visible_items: Dictionary = {}
var _selected_key: String = ""
var _hovered_key: String = ""
var _tray_labels: Dictionary = {}
var _label_observation_available: bool = true
var _rebuilds: int = 0
var player_facing_labels: bool = false
var skip_machine_roots: bool = false
var _selection_label: InventorySelectionLabel
var labels_visible: bool = true:
	set(value):
		labels_visible = value
		_highlight()


func _ready() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_selection_label = InventorySelectionLabel.new()
	layer.add_child(_selection_label)
	_highlight()


func observe(record: Dictionary) -> ServiceResult:
	# Bootstrap uses an empty record to withdraw the disconnected projection.
	# Preserve the existing invalid-record geometry contract, but retire identity.
	if record.is_empty():
		_label_observation_available = false
		clear_selection()
	var validated: ServiceResult = WorldStorageObservation.from_record(record)
	if not validated.is_success:
		return validated
	var next: Dictionary = validated.value.to_record()
	_label_observation_available = true
	var changed: bool = JSON.stringify(next["containers"]) != JSON.stringify(_record["containers"])
	_record = next
	if changed:
		_rebuild()
	else:
		_highlight()
	return ServiceResult.success()


func presentation_snapshot() -> Dictionary:
	return {"containers": _record["containers"].size(), "visible_items": _visible_items.size(), "selected_key": _selected_key, "rebuilds": _rebuilds}


func _rebuild() -> void:
	if _rendered != null:
		remove_child(_rendered)
		_rendered.queue_free()
	_rendered = Node3D.new()
	add_child(_rendered)
	_visible_items.clear()
	_tray_labels.clear()
	_hovered_key = ""
	_rebuilds += 1
	for container in _record["containers"]:
		# The machinery adapter renders these physical roots as assemblies, not trays.
		if skip_machine_roots and String(container["container_id"]).begins_with("machine-root-"): continue
		var coords: Array = container["position_millimetres"]
		var origin: Vector3 = DISPLAY_ORIGIN + Vector3(float(coords[0]), float(coords[1]), float(coords[2])) / 1000.0
		for row in range(2):
			for bay in range(2):
				_box(_rendered, TRAY_BAY_SIZE, origin + Vector3((float(bay) - 0.5) * TRAY_BAY_PITCH, 0.7, (float(row) - 0.5) * TRAY_ROW_PITCH), Color("#788a96"))
		var label := WorldContextLabel.new()
		label.position = origin + Vector3(0, 0.7, 0)
		# Identity is already in the single item card. Reserve tray context for
		# essential overflow rather than covering neighboring proxies twice.
		if container["items"].size() > MAX_VISIBLE_ITEMS_PER_CONTAINER:
			label.text = "Storage tray [%s]\n%d more items available in overlay" % [container["container_id"], container["items"].size() - MAX_VISIBLE_ITEMS_PER_CONTAINER]
		_rendered.add_child(label)
		_tray_labels[String(container["container_id"])] = label
		label.visible = false
		for index in range(mini(container["items"].size(), MAX_VISIBLE_ITEMS_PER_CONTAINER)):
			var item: Dictionary = container["items"][index]
			var dimensions := Vector3(0.15, 0.15, 0.15)
			var color := Color("#b4c7d4")
			if item["definition_id"] in ["item.crowbar.prototype", "item.crowbar.fabricated"]:
				dimensions = Vector3(0.4, 0.04, 0.04)
				color = Color("#bdc8d0")
			elif item["definition_id"] in ["item.backpack.prototype", "item.backpack.fabricated"]:
				dimensions = Vector3(0.25, 0.3, 0.2)
				color = Color("#6a986b")
			elif item["definition_id"] in ["item.pouch.prototype", "item.pouch.fabricated"]:
				dimensions = Vector3(0.18, 0.12, 0.12)
				color = Color("#bba064")
			elif item["definition_id"] in ["item.resource-canister.prototype", "item.resource-canister.fabricated"]:
				dimensions = Vector3(0.16, 0.3, 0.16)
				color = Color("#79b4c2")
			elif item["definition_id"] == "item.plate.prototype":
				dimensions = Vector3(0.4, 0.035, 0.3)
				color = Color("#b9c2ce")
			elif item["definition_id"] in ["item.extractor.prototype", "item.extractor.fabricated"]:
				dimensions = Vector3(0.32, 0.16, 0.12)
				color = Color("#dfa645")
			var location: Vector3 = origin + Vector3((float((index % TRAY_COLUMNS) / 2) - 0.5) * TRAY_BAY_PITCH + (float(index % 2) - 0.5) * TRAY_COLUMN_PITCH, 0.75 + dimensions.y / 2.0, (float(index / TRAY_COLUMNS) - 0.5) * TRAY_ROW_PITCH)
			var mesh: MeshInstance3D = _box(_rendered, dimensions, location, color)
			InventoryItemSilhouettes.apply(mesh, item["definition_id"])
			var key: String = JSON.stringify([container["container_id"], item["item_id"]])
			_visible_items[key] = {"mesh": mesh, "color": color, "item_id": item["item_id"], "definition_id": item["definition_id"], "container_id": container["container_id"], "distance": container["distance_millimetres"]}
			var area := Area3D.new()
			area.position = location
			area.collision_layer = 4
			area.collision_mask = 0
			area.input_ray_pickable = true
			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = dimensions.max(Vector3(0.12, 0.12, 0.12))
			shape.shape = box
			area.add_child(shape)
			area.input_event.connect(_on_item_input.bind(container["container_id"], item["item_id"]))
			_visible_items[key]["area"] = area
			area.mouse_entered.connect(_on_item_hover.bind(key, true, area))
			area.mouse_exited.connect(_on_item_hover.bind(key, false, area))
			_rendered.add_child(area)
	if not _visible_items.has(_selected_key):
		_selected_key = ""
	_highlight()


## Local visual selection only; never changes observed storage or queues an intent.
func clear_selection() -> void:
	_selected_key = ""
	_hovered_key = ""
	_highlight()


## Native hover is transient presentation; no selection or pickup signal is emitted.
func _on_item_hover(key: String, entered: bool, area: Area3D) -> void:
	if not _label_observation_available or not _visible_items.has(key) or _visible_items[key]["area"] != area:
		return
	if entered:
		_hovered_key = key
	elif _hovered_key == key:
		_hovered_key = ""
	_highlight()


func _on_item_input(_camera: Node, event: InputEvent, _position: Vector3, _normal: Vector3, _shape: int, container_id: String, item_id: String) -> void:
	var key: String = JSON.stringify([container_id, item_id])
	if not _visible_items.has(key) or not PlayerInputSettings.instance().accepts_gameplay_input() or not event.is_action_pressed("world_select"):
		return
	_selected_key = key
	_highlight()
	item_selected.emit(container_id, item_id)
	if not event is InputEventMouseButton or event.double_click:
		pickup_requested.emit(container_id, item_id)


func _highlight() -> void:
	var context_key: String = _selected_key if _visible_items.has(_selected_key) else _hovered_key
	var context_root: String = String(_visible_items[context_key]["container_id"]) if _visible_items.has(context_key) else ""
	for id in _tray_labels:
		_tray_labels[id].visible = labels_visible and _label_observation_available and id == context_root and not _tray_labels[id].text.is_empty()
	for key in _visible_items:
		var entry: Dictionary = _visible_items[key]
		var material: StandardMaterial3D = entry["mesh"].material_override
		material.albedo_color = Color("#ffe066") if key == _selected_key else entry["color"]
	if _selection_label != null:
		_selection_label.target = null
		_selection_label.enabled = labels_visible and _label_observation_available
		if _visible_items.has(context_key):
			var selected: Dictionary = _visible_items[context_key]
			_selection_label.select_proxy(selected["mesh"], selected["item_id"], selected["container_id"], selected["distance"], selected["definition_id"])
		else:
			_selection_label.visible = false


func _box(parent: Node3D, dimensions: Vector3, location: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.8
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = location
	parent.add_child(instance)
	return instance
