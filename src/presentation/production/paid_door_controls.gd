extends VBoxContainer
class_name PaidDoorControls

var _world: WorldRuntime
var _record: Dictionary = {}
var _pending: String = ""
var _selected: String = ""
var _scope: Array = []
var _age: float = 0.0
var _toggle := CheckButton.new()
var _details := VBoxContainer.new()
var _x := SpinBox.new()
var _z := SpinBox.new()
var _turn := CheckButton.new()
var _doors := OptionButton.new()
var _status := Label.new()
var _buttons: Array[Button] = []


func configure(world: WorldRuntime) -> void:
	_world = world
	_toggle.text = "Manual doors · 2 kg plate and paid floor"
	add_child(_toggle)
	add_child(_details)
	_details.visible = false
	_toggle.toggled.connect(func(open: bool) -> void: _details.visible = open)
	for field in [_x, _z]:
		field.min_value = -100000
		field.max_value = 100000
		field.step = 50
		_details.add_child(field)
	_x.prefix = "Frame X mm: "
	_z.prefix = "Frame Z mm: "
	_turn.text = "Rotate 90 degrees"
	_details.add_child(_turn)
	_details.add_child(_doors)
	_doors.item_selected.connect(func(index: int) -> void: _selected = _doors.get_item_metadata(index))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.text = "Requires a paid 1 m square floor under the full swing. Stand outside the swing, within 1.5 m of the frame. Equip a usable crowbar to move it. No pressure seal."
	_details.add_child(_status)
	for operation in ["door_build", "door_open", "door_close", "door_remove"]:
		var button := Button.new()
		button.text = {"door_build": "Build manual door", "door_open": "Pry selected door open", "door_close": "Pry selected door closed", "door_remove": "Disassemble selected closed door"}[operation]
		button.disabled = true
		button.pressed.connect(_send.bind(operation))
		_details.add_child(button)
		_buttons.append(button)
	world.command_completed.connect(func(command: SimulationCommand, result: ServiceResult) -> void:
		if String(command.command_id) != _pending: return
		_pending = ""
		_record.clear()
		_status.text = "Door command accepted. Wait for current host state." if result.is_success else result.message
	)
	if world is RemoteWorldRuntime:
		(world as RemoteWorldRuntime).panel_contact_cleared.connect(func() -> void: _record.clear(); _pending = ""; _selected = "")


func _process(delta: float) -> void:
	_age += delta
	if _age < 0.2 or not is_instance_valid(_world): return
	_age = 0.0
	var scope: Array = [_world.world_id, _world.region_id]
	if scope != _scope: _record.clear(); _selected = ""; _pending = ""; _scope = scope
	var context := AuthenticatedCommandContext.for_local_development(&"local-inventory-actor", _world.world_id, _world.region_id)
	var observed: ServiceResult = _world.production_observation(context)
	_record.clear()
	if observed.is_success and observed.value.get("schema_version") == 11 and WorkstationResourceView.valid(observed.value): _record = observed.value
	_doors.clear()
	for door in _record.get("paid_doors", {}).get("doors", []):
		_doors.add_item("%s · %s" % [String(door.door_id).right(8), "open" if door.opened else "closed"])
		_doors.set_item_metadata(_doors.item_count - 1, door.door_id)
		if _selected == door.door_id: _doors.select(_doors.item_count - 1)
	if _doors.item_count > 0 and _selected.is_empty(): _selected = _doors.get_item_metadata(0)
	var enabled: bool = not _record.is_empty() and _pending.is_empty() and _record.get("paid_doors", {}).get("can_operate", false) and _record.get("paid_doors", {}).get("control_epoch", -1) >= 0
	for index in range(_buttons.size()): _buttons[index].disabled = not enabled or (index > 0 and not _record.paid_doors.doors.any(func(d: Dictionary) -> bool: return d.door_id == _selected)) if not _record.is_empty() else true


func _send(operation: String) -> void:
	if _record.is_empty() or not _pending.is_empty() or _scope != [_world.world_id, _world.region_id]: return
	var command := ProductionDevelopmentCommand.new()
	command.command_id = _world.next_local_request_id()
	command.operation = operation
	command.payload = {"expected_revision": _record.state_revision, "control_epoch": _record.paid_doors.control_epoch}
	if operation == "door_build":
		command.payload.merge({"position": [roundi(_x.value), 0, roundi(_z.value)], "quarter_turn": 1 if _turn.button_pressed else 0})
	else: command.payload["door_id"] = _selected
	command.authenticated_context = AuthenticatedCommandContext.for_local_development(&"local-inventory-actor", _world.world_id, _world.region_id)
	_pending = String(command.command_id)
	var queued: ServiceResult = _world.enqueue_command(command)
	if not queued.is_success: _pending = ""; _status.text = queued.message
