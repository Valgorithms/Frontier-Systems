extends RefCounted
class_name PreparedDoorChange

## Server-only, short-lived compare-and-swap value. Never sent or persisted.
var _owner: AccessControlSystem
var _id: StringName
var _previous: AccessControlledDeviceState
var _before: Dictionary
var _after: Dictionary
var _remove: bool
var _consumed: bool = false
var pressure_owner: PressureRoomOwner
var pressure_before: Dictionary = {}
var pressure_after: Dictionary = {}
var _paired: Dictionary = {}


## Stage all additional existing devices before commit. No owner writes here.
func stage_device(id: StringName, after: Dictionary) -> ServiceResult:
	if _consumed or id == _id or _paired.has(id): return denied()
	var live: AccessControlledDeviceState = _owner.devices.get(id)
	var parsed: ServiceResult = AccessControlledDeviceState.from_record(after)
	if live == null or not parsed.is_success or parsed.value.device_id != id: return denied()
	_paired[id] = {"previous": live, "before": live.to_record().duplicate(true), "after": after.duplicate(true)}
	return ServiceResult.success()


func project_access(record: Dictionary) -> Dictionary:
	var result: Dictionary = record.duplicate(true)
	var found: bool = false
	for index in range(result.devices.size() - 1, -1, -1):
		var id := StringName(result.devices[index].device_id)
		if id == _id:
			found = true
			if _remove: result.devices.remove_at(index)
			else: result.devices[index] = _after.duplicate(true)
		elif _paired.has(id): result.devices[index] = _paired[id].after.duplicate(true)
	if not found and not _remove: result.devices.append(_after.duplicate(true))
	return result


func _init(owner: AccessControlSystem, id: StringName, previous: AccessControlledDeviceState, after: Dictionary, remove: bool) -> void:
	_owner = owner
	_id = id
	_previous = previous
	_before = previous.to_record().duplicate(true) if previous != null else {}
	_after = after.duplicate(true)
	_remove = remove


## Every failure precedes all affected-device writes. No callbacks/restore.
func commit(owner: AccessControlSystem) -> ServiceResult:
	if _consumed or owner != _owner: return denied()
	_consumed = true
	if pressure_owner != null:
		var captured: ServiceResult = pressure_owner.capture_snapshot()
		if not captured.is_success or captured.value != pressure_before: return denied()
	var live: AccessControlledDeviceState = owner.devices.get(_id)
	if live != _previous or (live != null and live.to_record() != _before): return denied()
	if live == null and owner.devices.size() >= AccessControlSystem.MAX_DEVICES: return denied()
	var parsed: ServiceResult
	if not _remove:
		parsed = AccessControlledDeviceState.from_record(_after)
		if not parsed.is_success or parsed.value.device_id != _id: return denied()
	var paired_decoded: Dictionary = {}
	for id in _paired:
		var stage: Dictionary = _paired[id]
		var current: AccessControlledDeviceState = owner.devices.get(id)
		if current != stage.previous or current == null or current.to_record() != stage.before: return denied()
		var decoded: ServiceResult = AccessControlledDeviceState.from_record(stage.after)
		if not decoded.is_success or decoded.value.device_id != id: return denied()
		paired_decoded[id] = decoded.value
	if _remove and live == null: return denied()
	if _remove:
		owner.devices.erase(_id)
	else:
		owner.devices[_id] = parsed.value
	for id in paired_decoded: owner.devices[id] = paired_decoded[id]
	# All decoding/CAS/capacity work precedes the first write. No callbacks/yield.
	if pressure_owner != null and not pressure_after.is_empty(): pressure_owner.install_prepared_room_state(pressure_after)
	return ServiceResult.success()


static func denied() -> ServiceResult:
	return ServiceResult.failure(&"door_commit_changed", "The prepared door change is stale, consumed or invalid.")
