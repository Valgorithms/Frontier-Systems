extends VBoxContainer
class_name TimedCanisterControls

## Compact projection consumer. Host revalidates scope, epochs and both revisions.
var _world: WorldRuntime
var _record: Dictionary = {}
var _pending: String = ""
var _selected_id: String = ""
var _scope: Array = []
var _revision: int = -1
var _reservation_revision: int = -1
var _epoch: int = -1
var _toggle := CheckButton.new()
var _details := VBoxContainer.new()
var _jobs := OptionButton.new()
var _status := Label.new()
var _result := Label.new()
var _buttons: Dictionary = {}


func configure(world: WorldRuntime) -> void:
	_world = world
	_toggle.text = "Timed canister · 1 kg iron"
	_toggle.toggled.connect(func(open: bool) -> void: _details.visible = open)
	add_child(_toggle)
	add_child(_details)
	_details.visible = false
	_jobs.fit_to_longest_item = false
	_jobs.item_selected.connect(func(index: int) -> void:
		_selected_id = _jobs.get_item_metadata(index)
		_refresh()
	)
	_details.add_child(_jobs)
	for label in [_status, _result]:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_details.add_child(label)
	var actions := HFlowContainer.new()
	_details.add_child(actions)
	var titles: Dictionary = {"reserve": "Start", "interrupt": "Pause", "resume": "Resume", "cancel": "Cancel", "complete": "Complete"}
	for operation in titles:
		var button := Button.new()
		button.text = titles[operation]
		button.pressed.connect(_send.bind(operation))
		actions.add_child(button)
		_buttons[operation] = button
	_world.command_completed.connect(func(command: SimulationCommand, result: ServiceResult) -> void:
		if String(command.command_id) != _pending: return
		_pending = ""
		_result.text = ("Canister " + command.operation.trim_prefix("canister_") + " accepted. Refreshing host state.") if result.is_success else EngineeringFailureGuidance.describe(result, result.message)
		# Do not reuse the pre-ack projection for a new action.
		_record.clear()
		_refresh()
	)
	if world is RemoteWorldRuntime:
		(world as RemoteWorldRuntime).connection_closed.connect(func(_message: String) -> void:
			_pending = ""
			observe({})
			_result.text = "Connection closed. Reconnect to reconcile the host job before acting."
		)
	_refresh()


func observe(production: Dictionary) -> void:
	var scope: Array = [String(_world.world_id), String(_world.region_id)]
	if scope != _scope:
		_scope = scope
		_revision = -1
		_reservation_revision = -1
		_epoch = -1
		_selected_id = ""
	_record.clear()
	if not ControlContractValidation.is_integer(production.get("schema_version"), 9, 17) or not ControlContractValidation.is_integer(production.get("state_revision"), 0, ProductionSimulationSystem.MAX_REVISION) or int(production["state_revision"]) < _revision or not TimedCanisterConstruction.valid_observation(production.get("timed_canister")):
		_refresh()
		return
	var observed: Dictionary = production["timed_canister"]
	if int(observed["revision"]) < _reservation_revision or int(observed["control_epoch"]) < _epoch:
		_refresh()
		return
	_revision = int(production["state_revision"])
	_reservation_revision = int(observed["revision"])
	_epoch = int(observed["control_epoch"])
	_record = production.duplicate(true)
	_jobs.clear()
	for id in _record["timed_canister"]["jobs"]:
		_jobs.add_item("%s · %s" % [id.right(12), _record["timed_canister"]["jobs"][id]["state"]])
		_jobs.set_item_metadata(_jobs.item_count - 1, id)
		if id == _selected_id: _jobs.select(_jobs.item_count - 1)
	if not _record["timed_canister"]["jobs"].has(_selected_id):
		_selected_id = ""
		# Prefer an unfinished job when opening or reconnecting.
		for index in range(_jobs.item_count):
			var id: String = _jobs.get_item_metadata(index)
			if _selected_id.is_empty() or _record["timed_canister"]["jobs"][id]["state"] in ["active", "paused", "ready"]:
				_selected_id = id
				_jobs.select(index)
	_refresh()


func _refresh() -> void:
	for button in _buttons.values(): button.disabled = true
	_jobs.disabled = not _pending.is_empty() or _record.is_empty()
	if _record.is_empty():
		_status.text = "Timed canister state unavailable. Wait for current host observation."
		return
	var observed: Dictionary = _record["timed_canister"]
	var job: Dictionary = observed["jobs"].get(_selected_id, {})
	_status.text = "120 work ticks at 60 Hz; reserves 1 kg refined iron. Complete creates an empty canister."
	if not job.is_empty(): _status.text = "%s · %d / 120 work ticks" % [job["state"].capitalize(), int(job["progress_ticks"])]
	if not observed["can_operate"]: _status.text += "\nApproach the workbench with a conscious body and a free hand."
	if not _pending.is_empty():
		_status.text += "\nWaiting for host."
		return
	_buttons["reserve"].disabled = not observed["can_start"]
	if not observed["can_operate"] or job.is_empty(): return
	_buttons["interrupt"].disabled = job["state"] not in ["active", "ready"]
	_buttons["resume"].disabled = job["state"] != "paused"
	_buttons["cancel"].disabled = job["state"] not in ["active", "paused", "ready"]
	_buttons["complete"].disabled = job["state"] != "ready"


func _send(operation: String) -> void:
	if not _buttons.has(operation) or _buttons[operation].disabled or _record.is_empty() or not _pending.is_empty(): return
	if _scope != [String(_world.world_id), String(_world.region_id)]:
		observe({})
		return
	var request: String = "canister-ui-%s" % _world.next_local_request_id()
	var observed: Dictionary = _record["timed_canister"]
	var command := ProductionDevelopmentCommand.new()
	command.command_id = StringName(request)
	command.authenticated_context = AuthenticatedCommandContext.for_local_development(&"local-inventory-actor", _world.world_id, _world.region_id)
	command.operation = "canister_" + operation
	command.payload = {"expected_revision": _record["state_revision"], "expected_reservation_revision": observed["revision"], "control_epoch": observed["control_epoch"], "job_id": request if operation == "reserve" else _selected_id}
	var queued: ServiceResult = _world.enqueue_command(command)
	if queued.is_success:
		_pending = request
		if operation == "reserve": _selected_id = request
	_result.text = "Waiting for host: " + _buttons[operation].text if queued.is_success else EngineeringFailureGuidance.describe(queued, queued.message)
	_refresh()
