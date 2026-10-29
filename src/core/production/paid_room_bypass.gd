extends RefCounted
class_name PaidRoomBypass

## First-party manual metal bypass. No pump, force upgrade or electrical work.
const MASS: int = 200000
const BLUEPRINT: String = "door.manual.bypass.prototype"
const OPERATIONS: Array[String] = ["door_bypass_install", "door_bypass_open", "door_bypass_close", "door_bypass_recover"]


static func valid_blueprint(value: Variant) -> bool:
	if typeof(value) != TYPE_DICTIONARY or not ControlContractValidation.has_exact_fields(value, PackedStringArray(["schema_version", "blueprint_id", "revision", "materials", "assembly_energy_joules", "conductance_mol_per_second_kpa", "provenance"])): return false
	return ControlContractValidation.is_integer(value.schema_version, 1, 1) and value.blueprint_id == BLUEPRINT and ControlContractValidation.is_integer(value.revision, 1, 1) and typeof(value.materials) == TYPE_DICTIONARY and ControlContractValidation.has_exact_fields(value.materials, PackedStringArray(["plate"])) and ControlContractValidation.is_integer(value.materials.plate, MASS, MASS) and ControlContractValidation.is_integer(value.assembly_energy_joules, 0, 0) and typeof(value.conductance_mol_per_second_kpa) in [TYPE_INT, TYPE_FLOAT] and value.conductance_mol_per_second_kpa == ConstructedRoomPressure.CONDUCTANCE and value.provenance == "First-party MIT manual metal bypass prototype; passive isothermal bulk gas only."


static func valid(parts: Variant, doors: Dictionary) -> bool:
	if typeof(parts) != TYPE_DICTIONARY or parts.size() > PaidDoorGeometry.MAX_DOORS: return false
	var seen: Dictionary = {}
	for id in parts:
		var part: Variant = parts[id]
		if not doors.has(id) or typeof(part) != TYPE_DICTIONARY or not ControlContractValidation.has_exact_fields(part, PackedStringArray(["bypass_id", "blueprint_id", "blueprint_revision", "materials"])): return false
		if not ControlContractValidation.is_id(part.bypass_id) or not String(part.bypass_id).begins_with("room-bypass-") or seen.has(part.bypass_id) or part.blueprint_id != BLUEPRINT or not ControlContractValidation.is_integer(part.blueprint_revision, 1, 1): return false
		if typeof(part.materials) != TYPE_DICTIONARY or not ControlContractValidation.has_exact_fields(part.materials, PackedStringArray(["plate"])) or not ControlContractValidation.is_integer(part.materials.plate, MASS, MASS): return false
		seen[part.bypass_id] = true
	return true


static func mass(state: Dictionary) -> int:
	return state.get("room_bypasses", {}).size() * MASS


static func plan(state: Dictionary, door_id: String, actuator: ActuatorState, device: AccessControlledDeviceState, inventory: InventorySimulationSystem, context: AuthenticatedCommandContext, request: String, operation: String, pressure: PressureRoomOwner, access: AccessControlSystem) -> ServiceResult:
	var tool: ServiceResult = inventory.active_tool(context, "tool.crowbar")
	if not tool.is_success: return tool
	if pressure == null or actuator.mode != &"manual" or actuator.integrity <= 0.0 or actuator.latch_state != &"released" or not device.bypass_jobs.is_empty() or not device.tamper_events.is_empty() or actuator.override_actor_id != &"": return PaidDoorConstruction.failure("Usable manual hardware and cleared work are required.")
	var parts: Dictionary = state.get("room_bypasses", {}).duplicate(true)
	var candidate_pair: bool = false
	if pressure.room_area(door_id) == 0.0 and operation == "door_bypass_install":
		var authorized: ServiceResult = inventory.authorize(context, true)
		if authorized.is_success:
			var pair: ServiceResult = PaidChamber.candidate(state, String(context.principal_id), authorized.value)
			candidate_pair = pair.is_success and door_id in [pair.value.inner_door_id, pair.value.outer_door_id] and PaidChamber.closed_intact(actuator)
			if candidate_pair:
				for id in [pair.value.inner_door_id, pair.value.outer_door_id]:
					var other: AccessControlledDeviceState = access.devices.get(StringName(id))
					if other == null or pressure.room_area(id) != 0.0 or not PaidChamber.closed_intact(other.actuator(PaidDoorConstruction.actuator_id(id))): candidate_pair = false
	if operation == "door_bypass_install":
		if parts.has(door_id) or (pressure.room_area(door_id) == 0.0 and not candidate_pair) or actuator.position != 0.0 or int(state.store.plate) < MASS: return PaidDoorConstruction.failure("A closed commissioned door or a complete chamber pair with both seals fitted, plus 0.2 kg unreserved plate, is required.")
		parts[door_id] = {"bypass_id": "room-bypass-%s" % JSON.stringify([String(context.principal_id), request]).sha256_text().substr(0, 32), "blueprint_id": BLUEPRINT, "blueprint_revision": 1, "materials": {"plate": MASS}}
		state.store.plate -= MASS
	elif operation == "door_bypass_recover":
		# Decommissioning is allowed only after closing this valve; it drops only
		# the operational Pressure link, never the paid recoverable part.
		if not parts.has(door_id) or pressure.room_area(door_id) != 0.0 or ProductionSimulationSystem._mass(state.store) + ProductionSimulationSystem._reserved_mass(state) + MASS > ProductionSimulationSystem.MAX_MASS: return PaidDoorConstruction.failure("Decommission with the valve closed and make room for its 0.2 kg plate.")
		state.store.plate += MASS
		parts.erase(door_id)
	else:
		if not parts.has(door_id) or pressure.room_area(door_id) == 0.0: return PaidDoorConstruction.failure("Install a paid bypass on the commissioned door first.")
	if int(state.schema_version) >= 14:
		state.room_bypasses = parts
	elif parts.is_empty():
		state.erase("room_bypasses")
		state.schema_version = 12 if int(state.catalog_revision) == 2 else 11
	else:
		state.room_bypasses = parts
		state.schema_version = 13
	return ServiceResult.success()
