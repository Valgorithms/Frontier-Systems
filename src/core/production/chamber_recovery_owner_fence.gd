extends RefCounted
class_name ChamberRecoveryOwnerFence

## Ephemeral all-owner admission fence for the forthcoming prepared gas/energy
## transaction. Taking this fence never publishes candidates or changes receipts.
## The caller must finish all decoding/cross-validation before taking it, and
## publish directly without callbacks/yields after a successful take.
var _production: ProductionSimulationSystem
var _pressure: PressureRoomOwner
var _inventory: InventorySimulationSystem
var _access: AccessControlSystem
var _records: Array[Dictionary] = []
var _generations: Array[int] = []
var _consumed: bool = false
var _access_tick: int = 0


static func capture(production: ProductionSimulationSystem, pressure: PressureRoomOwner, inventory: InventorySimulationSystem, access: AccessControlSystem) -> ServiceResult:
	if production == null or pressure == null or inventory == null or access == null: return denied()
	var fence := ChamberRecoveryOwnerFence.new()
	fence._production = production
	fence._pressure = pressure
	fence._inventory = inventory
	fence._access = access
	for owner in [production, pressure, inventory, access]:
		var captured: ServiceResult = owner.capture_snapshot()
		if not captured.is_success: return denied()
		fence._records.append(captured.value.duplicate(true))
	fence._generations = [production.collision_restore_generation(), pressure.room_restore_generation(), inventory.controller_restore_generation(), access.restore_generation()]
	fence._access_tick = access.current_tick
	return ServiceResult.success(fence)


## A failed take consumes only this ephemeral value, never canonical receipts.
func take(production: ProductionSimulationSystem, pressure: PressureRoomOwner, inventory: InventorySimulationSystem, access: AccessControlSystem) -> ServiceResult:
	if _consumed: return denied()
	_consumed = true
	if production != _production or pressure != _pressure or inventory != _inventory or access != _access: return denied()
	if not is_instance_valid(production) or not is_instance_valid(pressure) or not is_instance_valid(inventory) or not is_instance_valid(access): return denied()
	if _generations != [production.collision_restore_generation(), pressure.room_restore_generation(), inventory.controller_restore_generation(), access.restore_generation()]: return denied()
	if access.current_tick != _access_tick: return denied()
	var index: int = 0
	for owner in [production, pressure, inventory, access]:
		var captured: ServiceResult = owner.capture_snapshot()
		if not captured.is_success or captured.value != _records[index]: return denied()
		index += 1
	return ServiceResult.success()


static func denied() -> ServiceResult:
	return ServiceResult.failure(&"chamber_recovery_owner_changed", "The recovery preparation is stale, consumed or unavailable.")
