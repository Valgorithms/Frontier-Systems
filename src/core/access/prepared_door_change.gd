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
var pressure_owner: PressureSystem
var pressure_before: Dictionary = {}
var pressure_after: Dictionary = {}


func _init(owner: AccessControlSystem, id: StringName, previous: AccessControlledDeviceState, after: Dictionary, remove: bool) -> void:
	_owner = owner
	_id = id
	_previous = previous
	_before = previous.to_record().duplicate(true) if previous != null else {}
	_after = after.duplicate(true)
	_remove = remove


## Every failure precedes the one affected-device write. No callbacks/restore.
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
	if _remove:
		if live == null: return denied()
		owner.devices.erase(_id)
	else:
		owner.devices[_id] = parsed.value
	# All decoding/CAS/capacity work precedes the first write. No callbacks/yield.
	if pressure_owner != null and not pressure_after.is_empty(): pressure_owner.install_prepared_room_state(pressure_after)
	return ServiceResult.success()


static func denied() -> ServiceResult:
	return ServiceResult.failure(&"door_commit_changed", "The prepared door change is stale, consumed or invalid.")
