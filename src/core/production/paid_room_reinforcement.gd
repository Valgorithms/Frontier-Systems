extends RefCounted
class_name PaidRoomReinforcement

## Paid containment supplement. Condition is exclusively the linked Access
## actuator integrity and original seal condition; fitting never writes either.
const MASS: int = 4000000
const BLUEPRINT: String = "room.reinforcement.prototype"
const POLICY: String = "constructed-room.habitat.reinforced.v1"
const RETENTION_KPA: float = 110.0
const OPERATIONS: Array[String] = ["door_reinforcement_install", "door_reinforcement_recover"]


static func valid_blueprint(value: Variant) -> bool:
	if typeof(value) != TYPE_DICTIONARY or not ControlContractValidation.has_exact_fields(value, PackedStringArray(["schema_version", "blueprint_id", "revision", "materials", "assembly_energy_joules", "retention_kpa", "provenance"])): return false
	return ControlContractValidation.is_integer(value.schema_version, 1, 1) and value.blueprint_id == BLUEPRINT and ControlContractValidation.is_integer(value.revision, 1, 1) and typeof(value.materials) == TYPE_DICTIONARY and ControlContractValidation.has_exact_fields(value.materials, PackedStringArray(["plate"])) and ControlContractValidation.is_integer(value.materials.plate, MASS, MASS) and ControlContractValidation.is_integer(value.assembly_energy_joules, 0, 0) and typeof(value.retention_kpa) in [TYPE_INT, TYPE_FLOAT] and value.retention_kpa == RETENTION_KPA and value.provenance == "First-party MIT prototype game tuning; supported Access actuator and seal condition only; no physical certification."


static func valid(parts: Variant, doors: Dictionary) -> bool:
	if typeof(parts) != TYPE_DICTIONARY or parts.size() > PaidDoorGeometry.MAX_DOORS: return false
	var seen: Dictionary = {}
	for id in parts:
		var part: Variant = parts[id]
		if not doors.has(id) or doors[id].seal.is_empty() or typeof(part) != TYPE_DICTIONARY or not ControlContractValidation.has_exact_fields(part, PackedStringArray(["reinforcement_id", "blueprint_id", "blueprint_revision", "seal_id", "materials"])): return false
		if not ControlContractValidation.is_id(part.reinforcement_id) or not String(part.reinforcement_id).begins_with("room-reinforcement-") or seen.has(part.reinforcement_id) or part.blueprint_id != BLUEPRINT or not ControlContractValidation.is_integer(part.blueprint_revision, 1, 1) or part.seal_id != doors[id].seal.seal_id: return false
		if typeof(part.materials) != TYPE_DICTIONARY or not ControlContractValidation.has_exact_fields(part.materials, PackedStringArray(["plate"])) or not ControlContractValidation.is_integer(part.materials.plate, MASS, MASS): return false
		seen[part.reinforcement_id] = true
	return true


static func mass(state: Dictionary) -> int:
	return state.get("room_reinforcements", {}).size() * MASS


static func intact(actuator: ActuatorState) -> bool:
	return actuator != null and actuator.integrity == 1.0 and actuator.seal_condition == 1.0 and actuator.mode == &"manual" and actuator.latch_state == &"released"


static func plan(state: Dictionary, door_id: String, actuator: ActuatorState, device: AccessControlledDeviceState, inventory: InventorySimulationSystem, context: AuthenticatedCommandContext, request: String, operation: String, pressure: PressureRoomOwner) -> ServiceResult:
	var tool: ServiceResult = inventory.active_tool(context, "tool.crowbar")
	if not tool.is_success: return tool
	if pressure == null or actuator.mode != &"manual" or actuator.integrity <= 0.0 or actuator.latch_state != &"released" or not device.bypass_jobs.is_empty() or not device.tamper_events.is_empty() or actuator.override_actor_id != &"": return PaidDoorConstruction.failure("Usable manual hardware and cleared work are required.")
	var parts: Dictionary = state.get("room_reinforcements", {}).duplicate(true)
	if operation == "door_reinforcement_install":
		if parts.has(door_id) or pressure.room_area(door_id) == 0.0 or actuator.position != 0.0 or not intact(actuator) or state.doors[door_id].seal.is_empty() or int(state.store.plate) < MASS: return PaidDoorConstruction.failure("A closed intact commissioned room and 4 kg unreserved plate are required.")
		parts[door_id] = {"reinforcement_id": "room-reinforcement-%s" % JSON.stringify([String(context.principal_id), request]).sha256_text().substr(0, 32), "blueprint_id": BLUEPRINT, "blueprint_revision": 1, "seal_id": state.doors[door_id].seal.seal_id, "materials": {"plate": MASS}}
		state.store.plate -= MASS
	else:
		if not parts.has(door_id) or pressure.room_area(door_id) != 0.0 or ProductionSimulationSystem._mass(state.store) + ProductionSimulationSystem._reserved_mass(state) + MASS > ProductionSimulationSystem.MAX_MASS: return PaidDoorConstruction.failure("Open and decommission safely, then make room for 4 kg recovered plate.")
		state.store.plate += MASS
		parts.erase(door_id)
	state.room_reinforcements = parts
	if not state.has("room_bypasses"): state.room_bypasses = {}
	state.schema_version = maxi(int(state.schema_version), 14)
	return ServiceResult.success()
