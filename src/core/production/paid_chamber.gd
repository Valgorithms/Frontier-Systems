extends RefCounted
class_name PaidChamber

## Narrow first-party logical pressure connection, not spatial atmosphere.
const MASS: int = 6000000
const POLICY: String = "constructed-chamber.habitat-exterior.prototype.v1"
const OPERATIONS: Array[String] = ["door_chamber_kit_install", "door_chamber_kit_recover", "door_chamber_commission", "door_chamber_decommission"]
const INNER: String = "habitat_main"
const OUTER: String = "exterior_reservoir"
const VOLUME: float = 3.6
const RETENTION_KPA: float = 110.0


static func assess(geometry: Dictionary) -> ServiceResult:
	if not ControlContractValidation.has_exact_fields(geometry, PackedStringArray(["walls", "panels", "doors"])): return denied()
	if typeof(geometry.walls) != TYPE_DICTIONARY or typeof(geometry.panels) != TYPE_DICTIONARY or typeof(geometry.doors) != TYPE_DICTIONARY: return denied()
	if not SpatialWallConstruction.valid(geometry.walls) or not HorizontalPanelConstruction.valid(geometry.panels) or not PaidDoorGeometry.valid(geometry.doors, geometry.panels) or geometry.doors.size() != 2: return denied()
	var walls: ServiceResult = ConstructedWallBoundaries.describe(geometry.walls, 0)
	if not walls.is_success: return denied()
	var surfaces: Array[Dictionary] = []
	for id in geometry.panels: surfaces.append(HorizontalPanelConstruction.descriptor(id, geometry.panels[id]))
	var openings: Array[Dictionary] = []
	var inner: String = ""
	var outer: String = ""
	for id in geometry.doors:
		var door: Dictionary = geometry.doors[id]
		if door.quarter_turn != 1: return denied()
		if door.position == [5050, 0, -4000]: inner = id
		elif door.position == [6950, 0, -4000]: outer = id
		else: return denied()
		openings.append({"door_id": id, "position": door.position.duplicate(), "quarter_turn": door.quarter_turn})
	var result: ServiceResult = ConstructedDoorOpeningTopology.assess({"schema_version": 1, "production_revision": 0, "walls": walls.value, "surfaces": surfaces, "openings": openings})
	if not result.is_success or result.value.status != "enclosure_with_unsealed_openings" or result.value.interior_bounds_millimetres != [5100, 6900, -4500, -3500] or inner.is_empty() or outer.is_empty(): return denied()
	return ServiceResult.success({"inner_door_id": inner, "outer_door_id": outer})


static func candidate(production: Dictionary, principal: String, body: String) -> ServiceResult:
	return assess(ConstructedRoomPressure.geometry(production, principal, body))


static func valid_kits(value: Variant, production: Dictionary) -> bool:
	if typeof(value) != TYPE_DICTIONARY or value.size() > 1: return false
	for id in value:
		var kit: Variant = value[id]
		if typeof(kit) != TYPE_DICTIONARY or not ControlContractValidation.has_exact_fields(kit, PackedStringArray(["schema_version", "kit_id", "inner_door_id", "outer_door_id", "inner_seal_id", "outer_seal_id", "materials", "policy_id"])): return false
		if not ControlContractValidation.is_integer(kit.schema_version, 1, 1) or kit.policy_id != POLICY or kit.inner_door_id != id or kit.outer_door_id == id or typeof(kit.materials) != TYPE_DICTIONARY or kit.materials != {"plate": MASS}: return false
		for field in ["kit_id", "inner_door_id", "outer_door_id", "inner_seal_id", "outer_seal_id"]:
			if not ControlContractValidation.is_id(kit[field]): return false
		if not ControlContractValidation.is_integer(kit.materials.plate, MASS, MASS): return false
		if not ControlContractValidation.is_id(kit.kit_id) or not String(kit.kit_id).begins_with("chamber-kit-"): return false
		var doors: Dictionary = production.get("doors", {})
		if not doors.has(id) or not doors.has(kit.outer_door_id): return false
		var inner: Dictionary = doors[id]
		var outer: Dictionary = doors[kit.outer_door_id]
		if inner.principal_id != outer.principal_id or inner.body_id != outer.body_id: return false
		for boundary in [id, kit.outer_door_id]:
			if not production.get("room_bypasses", {}).has(boundary) or production.get("room_reinforcements", {}).has(boundary): return false
		if inner.seal.is_empty() or outer.seal.is_empty() or inner.seal.seal_id != kit.inner_seal_id or outer.seal.seal_id != kit.outer_seal_id: return false
		var pair: ServiceResult = candidate(production, inner.principal_id, inner.body_id)
		if not pair.is_success or pair.value.inner_door_id != id or pair.value.outer_door_id != kit.outer_door_id: return false
	return true


static func kit_for(production: Dictionary, door: String) -> Dictionary:
	for kit in production.get("chamber_kits", {}).values():
		if door in [kit.inner_door_id, kit.outer_door_id]: return kit
	return {}


static func valid_record(value: Variant) -> bool:
	if typeof(value) != TYPE_DICTIONARY or not ControlContractValidation.has_exact_fields(value, PackedStringArray(["schema_version", "policy_id", "volume_id", "sensor_id", "principal_id", "body_id", "world_id", "region_id", "inner_door_id", "outer_door_id", "inner_endpoint", "outer_endpoint", "geometry"])): return false
	if not ControlContractValidation.is_integer(value.schema_version, 1, 1) or value.policy_id != POLICY or value.region_id != "local-habitat" or value.inner_endpoint != INNER or value.outer_endpoint != OUTER: return false
	for field in ["volume_id", "sensor_id", "principal_id", "body_id", "world_id", "inner_door_id", "outer_door_id"]:
		if not ControlContractValidation.is_id(value[field]): return false
	if not String(value.volume_id).begins_with("paid-chamber-") or value.sensor_id != "%s-sensor" % value.volume_id or typeof(value.geometry) != TYPE_DICTIONARY: return false
	var pair: ServiceResult = assess(value.geometry)
	if not pair.is_success or pair.value.inner_door_id != value.inner_door_id or pair.value.outer_door_id != value.outer_door_id: return false
	for door in value.geometry.doors.values():
		if door.principal_id != value.principal_id or door.body_id != value.body_id or door.seal.is_empty(): return false
	return true


static func actuator(access: Dictionary, id: String) -> ActuatorState:
	for record in access.get("devices", []):
		if record.get("device_id") != id: continue
		var parsed: ServiceResult = AccessControlledDeviceState.from_record(record)
		return parsed.value.actuator(PaidDoorConstruction.actuator_id(id)) if parsed.is_success else null
	return null


static func closed_intact(target: ActuatorState) -> bool:
	return target != null and target.position == 0.0 and target.integrity == 1.0 and target.seal_condition == 1.0 and target.mode == &"manual" and target.latch_state == &"released"


static func retained(target: ActuatorState, difference: float) -> bool:
	return closed_intact(target) and difference <= RETENTION_KPA + ConstructedRoomPressure.TOLERANCE_KPA


static func links(chamber: Dictionary, valves: Dictionary, production: Dictionary, access: Dictionary, inventory: Dictionary) -> ServiceResult:
	if not valid_kits(production.get("chamber_kits", {}), production): return denied()
	if chamber.is_empty(): return PaidDoorConstruction.links(production, access, inventory)
	if not valid_record(chamber) or ConstructedRoomPressure.geometry(production, chamber.principal_id, chamber.body_id) != chamber.geometry: return denied()
	var kit: Dictionary = kit_for(production, chamber.inner_door_id)
	if kit.is_empty() or kit.outer_door_id != chamber.outer_door_id: return denied()
	var areas: Dictionary = {}
	var opened: int = 0
	var flowing: int = 0
	for id in [chamber.inner_door_id, chamber.outer_door_id]:
		if not production.get("room_bypasses", {}).has(id) or not valves.has(id) or typeof(valves[id]) != TYPE_BOOL or production.get("room_reinforcements", {}).has(id): return denied()
		var target: ActuatorState = actuator(access, id)
		if target == null: return denied()
		opened += 1 if target.position != 0.0 else 0
		flowing += 1 if valves[id] else 0
		areas[id] = ConstructedRoomPressure.AREA
	if opened > 1 or flowing > 1 or (opened > 0 and flowing > 0): return denied()
	return PaidDoorConstruction.links(production, access, inventory, areas)


static func denied() -> ServiceResult:
	return ServiceResult.failure(&"paid_chamber_denied", "A complete owned paid chamber pair, isolated boundaries and current authority are required.")


static func plan(state: Dictionary, inventory: InventorySimulationSystem, access: AccessControlSystem, context: AuthenticatedCommandContext, request: String, operation: String, payload: Dictionary, pressure: PressureRoomOwner) -> ServiceResult:
	if not ControlContractValidation.has_exact_fields(payload, PackedStringArray(["expected_revision", "control_epoch", "door_id"])) or pressure == null: return denied()
	var authorized: ServiceResult = inventory.authorize(context, true)
	var tool: ServiceResult = inventory.active_tool(context, "tool.crowbar")
	if not authorized.is_success or not tool.is_success: return denied()
	var geometry: Dictionary = ConstructedRoomPressure.geometry(state, String(context.principal_id), authorized.value)
	var pair: ServiceResult = assess(geometry)
	if not pair.is_success or payload.door_id != pair.value.inner_door_id: return denied()
	var ids: Array = [pair.value.inner_door_id, pair.value.outer_door_id]
	var devices: Dictionary = {}
	for id in ids:
		var door: Dictionary = state.doors[id]
		var current: AccessControlledDeviceState = access.devices.get(StringName(id))
		if current == null or not PaidDoorConstruction.valid_device(id, door, current.to_record(), pressure.room_area(id)): return denied()
		var device: AccessControlledDeviceState = AccessControlledDeviceState.from_record(current.to_record()).value
		if not closed_intact(device.actuator(PaidDoorConstruction.actuator_id(id))) or not device.bypass_jobs.is_empty() or not device.tamper_events.is_empty() or device.actuator(PaidDoorConstruction.actuator_id(id)).override_actor_id != &"": return denied()
		if not PaidDoorConstruction.reachable(inventory, context, door.position).is_success: return denied()
		if not PaidDoorConstruction.unoccupied(door, inventory.capture_snapshot().value, state): return denied()
		if state.get("room_reinforcements", {}).has(id): return denied()
		devices[id] = device
	var kits: Dictionary = state.get("chamber_kits", {}).duplicate(true)
	var inner: String = ids[0]
	var outer: String = ids[1]
	if operation == "door_chamber_kit_install":
		if not kits.is_empty() or pressure.room_area(inner) != 0.0 or pressure.room_area(outer) != 0.0 or int(state.store.plate) < MASS: return denied()
		for id in ids:
			if not state.get("room_bypasses", {}).has(id): return denied()
		kits[inner] = {"schema_version": 1, "kit_id": "chamber-kit-%s" % JSON.stringify([String(context.principal_id), request]).sha256_text().substr(0, 32), "inner_door_id": inner, "outer_door_id": outer, "inner_seal_id": state.doors[inner].seal.seal_id, "outer_seal_id": state.doors[outer].seal.seal_id, "materials": {"plate": MASS}, "policy_id": POLICY}
		state.store.plate -= MASS
	elif operation == "door_chamber_kit_recover":
		if not kits.has(inner) or pressure.room_area(inner) != 0.0 or ProductionSimulationSystem._mass(state.store) + ProductionSimulationSystem._reserved_mass(state) + MASS > ProductionSimulationSystem.MAX_MASS: return denied()
		state.store.plate += MASS
		kits.erase(inner)
	else:
		if not kits.has(inner): return denied()
		for id in ids:
			if not state.get("room_bypasses", {}).has(id) or pressure.room_valve_open(id): return denied()
			if operation == "door_chamber_decommission" and pressure.room_difference(id) * 1000.0 * ConstructedRoomPressure.AREA > AccessControlSystem.PROTOTYPE_MANUAL_FORCE_NEWTONS: return denied()
			devices[id].actuator(PaidDoorConstruction.actuator_id(id)).effective_pressure_area_m2 = ConstructedRoomPressure.AREA if operation == "door_chamber_commission" else 0.0
	state.chamber_kits = kits
	state.schema_version = 15
	if not state.has("room_reinforcements"): state.room_reinforcements = {}
	var prepared := PreparedDoorChange.new(access, StringName(inner), access.devices[StringName(inner)], devices[inner].to_record(), false)
	var staged: ServiceResult = prepared.stage_device(StringName(outer), devices[outer].to_record())
	return ServiceResult.success(prepared) if staged.is_success else staged
