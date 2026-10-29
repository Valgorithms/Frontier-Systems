extends RefCounted
class_name PreparedChamberRecoveryChange

## Server-only decoded publication. No normal intent receipt is consumed on a
## rejection. Every helper, allocation and authorization precedes the first swap.
var _fence: ChamberRecoveryOwnerFence
var _production_after: Dictionary
var _pressure_after: Dictionary
var _inventory_after: Dictionary
var _contexts_after: Dictionary
var _context: AuthenticatedCommandContext
var _mode: String
var _consumed: bool = false


func commit(production: ProductionSimulationSystem, pressure: PressureRoomOwner, inventory: InventorySimulationSystem, access: AccessControlSystem) -> ServiceResult:
	if _consumed: return ChamberRecoveryRecords.denied()
	_consumed = true
	if production == null or pressure == null or inventory == null or access == null or _fence == null: return ChamberRecoveryRecords.denied()
	var admission: ServiceResult = ChamberRecoveryPreparation.admit(production, _context, _mode)
	if not admission.is_success: return admission
	var result: ServiceResult = ServiceResult.success()
	var taken: ServiceResult = _fence.take(production, pressure, inventory, access)
	if not taken.is_success: return taken
	# No callbacks, decoding, hashing, validation, signals, restore or allocation
	# after this boundary. Access and Inventory are fenced but pure steps do not
	# mutate them. Candidates and all nested object graphs were detached/decoded.
	pressure.install_prepared_room_state(_pressure_after)
	if not _inventory_after.is_empty():
		inventory._owner = _inventory_after.owner
		inventory._world_storage = _inventory_after.world_storage
	production._state = _production_after
	production._chamber_recovery_contexts = _contexts_after
	return result
