extends RefCounted
class_name PaidDoorSeal

## Prototype reworkable metal gasket, not a pressure rating or gas connection.
const MASS: int = 200000
const BLUEPRINT: String = "door.manual.seal.prototype"


static func valid_blueprint(value: Variant) -> bool:
	if typeof(value) != TYPE_DICTIONARY or not ControlContractValidation.has_exact_fields(value, PackedStringArray(["schema_version", "blueprint_id", "revision", "materials", "provenance"])): return false
	return ControlContractValidation.is_integer(value.schema_version, 1, 1) and value.blueprint_id == BLUEPRINT and ControlContractValidation.is_integer(value.revision, 1, 1) and valid({"seal_id": "door-seal-blueprint", "blueprint_id": value.blueprint_id, "blueprint_revision": value.revision, "materials": value.materials}) and value.provenance == "First-party MIT reworkable metal gasket prototype; no pressure rating or tick wear."


static func valid(value: Variant) -> bool:
	if typeof(value) != TYPE_DICTIONARY: return false
	if value.is_empty(): return true
	return ControlContractValidation.has_exact_fields(value, PackedStringArray(["seal_id", "blueprint_id", "blueprint_revision", "materials"])) and ControlContractValidation.is_id(value.seal_id) and String(value.seal_id).begins_with("door-seal-") and value.blueprint_id == BLUEPRINT and ControlContractValidation.is_integer(value.blueprint_revision, 1, 1) and typeof(value.materials) == TYPE_DICTIONARY and ControlContractValidation.has_exact_fields(value.materials, PackedStringArray(["plate"])) and ControlContractValidation.is_integer(value.materials.plate, MASS, MASS)


static func mass(doors: Dictionary) -> int:
	var total: int = 0
	for door in doors.values():
		if not door.get("seal", {}).is_empty(): total += MASS
	return total


static func plan(state: Dictionary, door: Dictionary, actuator: ActuatorState, device: AccessControlledDeviceState, inventory: InventorySimulationSystem, context: AuthenticatedCommandContext, request: String, operation: String) -> ServiceResult:
	var tool: ServiceResult = inventory.active_tool(context, "tool.crowbar")
	if not tool.is_success: return tool
	if actuator.position != 0.0 or actuator.integrity <= 0.0 or actuator.mode != &"manual" or actuator.latch_state != &"released" or not device.bypass_jobs.is_empty() or not device.tamper_events.is_empty() or actuator.override_actor_id != &"": return PaidDoorConstruction.failure("Close the usable manual door and clear foreign work before fitting or recovering a seal.")
	if operation == "door_seal_install":
		if not door["seal"].is_empty() or int(state["store"]["plate"]) < MASS: return PaidDoorConstruction.failure("An absent seal and 0.2 kg processed plate are required.")
		door["seal"] = {"seal_id": "door-seal-%s" % JSON.stringify([String(context.principal_id), request]).sha256_text().substr(0, 32), "blueprint_id": BLUEPRINT, "blueprint_revision": 1, "materials": {"plate": MASS}}
		state["store"]["plate"] -= MASS
		# Explicit prototype gasket rework/repair; no other hardware is healed.
		actuator.seal_condition = 1.0
	else:
		if door["seal"].is_empty(): return PaidDoorConstruction.failure("Select an installed seal.")
		if ProductionSimulationSystem._mass(state["store"]) + ProductionSimulationSystem._reserved_mass(state) + MASS > ProductionSimulationSystem.MAX_MASS: return PaidDoorConstruction.failure("Receiving stock capacity is unavailable.")
		state["store"]["plate"] += MASS
		door["seal"] = {}
		actuator.seal_condition = 0.0
	return ServiceResult.success()
