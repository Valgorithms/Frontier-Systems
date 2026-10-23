extends VBoxContainer
class_name HorizontalPanelControls

signal preview_changed(candidate: Dictionary, selected_id: String)
signal observation_changed(production: Dictionary)

## Observation-only controls; host acceptance always comes through the queue.
var _world: WorldRuntime
var _record: Dictionary = {}
var _scope: Array = []
var _revision: int = -1
var _tick: int = -1
var _pending: String = ""
var _selected_id: String = ""
var _toggle := CheckButton.new()
var _details := VBoxContainer.new()
var _kind := OptionButton.new()
var _panels := OptionButton.new()
var _fields: Array[SpinBox] = []
var _status := Label.new()
var _result := Label.new()
var _build := Button.new()
var _remove := Button.new()


func configure(world: WorldRuntime) -> void:
	_world = world
	_toggle.text = "Floors / ceilings · paid boundary sheets"
	add_child(_toggle)
	add_child(_details)
	_details.visible = false
	_toggle.toggled.connect(func(open: bool) -> void:
		_details.visible = open
		_refresh()
	)
	visibility_changed.connect(_refresh)
	_kind.add_item("Floor · Y = 0 mm")
	_kind.add_item("Ceiling · Y = 2000 mm")
	_kind.item_selected.connect(func(_index: int) -> void: _refresh())
	_details.add_child(_kind)
	var grid := GridContainer.new()
	grid.columns = 2
	_details.add_child(grid)
	for title in ["X minimum (mm)", "Z minimum (mm)", "Width (mm)", "Depth (mm)"]:
		var label := Label.new()
		label.text = title
		grid.add_child(label)
		var field := SpinBox.new()
		field.min_value = -100500 if _fields.size() < 2 else 50
		field.max_value = 100450 if _fields.size() < 2 else 1000
		field.step = 50
		field.value = 0 if _fields.size() < 2 else 1000
		field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		field.get_line_edit().select_all_on_focus = true
		field.value_changed.connect(func(_value: float) -> void: _refresh())
		grid.add_child(field)
		_fields.append(field)
	_panels.fit_to_longest_item = false
	_details.add_child(_panels)
	_panels.item_selected.connect(func(index: int) -> void:
		_selected_id = _panels.get_item_metadata(index)
		_refresh()
	)
	for label in [_status, _result]:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_details.add_child(label)
	var actions := HFlowContainer.new()
	_details.add_child(actions)
	_build.text = "Place sheet"
	_remove.text = "Remove selected sheet"
	actions.add_child(_build)
	actions.add_child(_remove)
	_build.pressed.connect(_send.bind(true))
	_remove.pressed.connect(_send.bind(false))
	_world.command_completed.connect(func(command: SimulationCommand, result: ServiceResult) -> void:
		if String(command.command_id) != _pending: return
		_pending = ""
		_record.clear()
		observation_changed.emit({})
		_result.text = "Accepted. Waiting for fresh host state." if result.is_success else EngineeringFailureGuidance.describe(result, result.message)
		_refresh()
	)
	if world is RemoteWorldRuntime:
		(world as RemoteWorldRuntime).connection_closed.connect(func(_message: String) -> void:
			_pending = ""
			observe({})
			_result.text = "Disconnected. Reconnect to reconcile sheets before acting."
		)
	_refresh()


func observe(production: Dictionary) -> void:
	var scope: Array = [String(_world.world_id), String(_world.region_id)]
	if scope != _scope:
		_scope = scope
		_revision = -1
		_tick = -1
		_selected_id = ""
		_pending = ""
	_record.clear()
	_panels.clear()
	if not ControlContractValidation.is_integer(production.get("schema_version"), 10, 16) or not WorkstationResourceView.valid(production) or int(production["state_revision"]) < _revision or int(production["last_tick"]) < _tick:
		observation_changed.emit({})
		_refresh()
		return
	_revision = int(production["state_revision"])
	_tick = int(production["last_tick"])
	_record = production.duplicate(true)
	observation_changed.emit(_record.duplicate(true))
	for surface in _record["horizontal_panels"]["surfaces"]:
		_panels.add_item("%s · %s" % [surface["kind"].capitalize(), surface["surface_id"].right(12)])
		_panels.set_item_metadata(_panels.item_count - 1, surface["surface_id"])
		if surface["surface_id"] == _selected_id: _panels.select(_panels.item_count - 1)
	if not _has_selection():
		_selected_id = ""
		_panels.select(-1)
	_refresh()


func select_panel(id: String) -> void:
	if _record.is_empty(): return
	for index in range(_panels.item_count):
		if _panels.get_item_metadata(index) == id:
			_selected_id = id
			_panels.select(index)
			_toggle.button_pressed = true
			_refresh()
			return


func _has_selection() -> bool:
	for surface in _record.get("horizontal_panels", {}).get("surfaces", []):
		if surface["surface_id"] == _selected_id: return true
	return false


func _candidate() -> Dictionary:
	if _fields.size() != 4: return {}
	var x: int = roundi(_fields[0].value)
	var z: int = roundi(_fields[1].value)
	var surface: Dictionary = {"surface_id": "candidate", "kind": "floor" if _kind.selected == 0 else "ceiling", "bounds_millimetres": [x, x + roundi(_fields[2].value), z, z + roundi(_fields[3].value)], "height_millimetres": 0 if _kind.selected == 0 else 2000}
	var test: Dictionary = {"schema_version": 1, "surfaces": [surface], "can_operate": false, "closure": {"production_revision": 0, "status": "unavailable"}}
	return surface if HorizontalPanelObservation.valid(test, 0) else {}


func _refresh() -> void:
	_build.disabled = true
	_remove.disabled = true
	_panels.disabled = not _pending.is_empty() or _record.is_empty()
	if _record.is_empty():
		_status.text = "Sheets unavailable. Wait for current host observation."
		preview_changed.emit({}, "")
		return
	var candidate: Dictionary = _candidate()
	var observed: Dictionary = _record["horizontal_panels"]
	var bill: int = HorizontalPanelConstruction.bill(candidate["bounds_millimetres"]) if not candidate.is_empty() else 0
	_status.text = "%.4f kg plate · %.4f kg in shared stock.\nHost geometry: %s (revision %d).\nBoundary geometry only; no collision, support or airtightness." % [float(bill) / 1000000.0, float(_record["store"]["plate"]) / 1000000.0, observed["closure"]["status"].replace("_", " "), _revision]
	if candidate.is_empty(): _status.text += "\nChoose 50 mm grid bounds within ±100500 mm."
	if not _pending.is_empty(): _status.text += "\nWaiting for host."
	var active: bool = _pending.is_empty() and observed["can_operate"]
	_build.disabled = not active or candidate.is_empty() or bill > int(_record["store"]["plate"])
	_remove.disabled = not active or not _has_selection()
	preview_changed.emit(candidate if is_visible_in_tree() and _details.visible and _pending.is_empty() else {}, _selected_id if is_visible_in_tree() else "")


func _send(build: bool) -> void:
	if (_build.disabled if build else _remove.disabled) or _record.is_empty(): return
	if _scope != [String(_world.world_id), String(_world.region_id)]:
		observe({})
		return
	var payload: Dictionary = {"expected_revision": _revision}
	if build:
		var candidate: Dictionary = _candidate()
		if candidate.is_empty(): return
		for field in ["kind", "bounds_millimetres", "height_millimetres"]: payload[field] = candidate[field]
	else: payload["panel_id"] = _selected_id
	var command := ProductionDevelopmentCommand.new()
	command.command_id = StringName("panel-ui-%s" % _world.next_local_request_id())
	command.authenticated_context = AuthenticatedCommandContext.for_local_development(&"local-inventory-actor", _world.world_id, _world.region_id)
	command.operation = "panel_build" if build else "panel_remove"
	command.payload = payload
	var queued: ServiceResult = _world.enqueue_command(command)
	if queued.is_success: _pending = String(command.command_id)
	_result.text = "Waiting for host." if queued.is_success else EngineeringFailureGuidance.describe(queued, queued.message)
	_refresh()
