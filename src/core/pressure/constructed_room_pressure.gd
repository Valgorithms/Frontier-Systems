extends RefCounted
class_name ConstructedRoomPressure

## Server policy, not a material certification or spatial ambient map.
const POLICY: String = "constructed-room.habitat.prototype.v1"
const AREA: float = 1.71
const RETENTION_KPA: float = 0.5
const TOLERANCE_KPA: float = 1e-9
const CONDUCTANCE: float = 1.0
const HABITAT_VOLUME: float = 1000.0


static func geometry(state: Dictionary, principal: String, body: String) -> Dictionary:
	var panels: Dictionary = {}
	var doors: Dictionary = {}
	for id in state.get("panels", {}):
		if state.panels[id].principal_id == principal: panels[id] = state.panels[id].duplicate(true)
	for id in state.get("doors", {}):
		if state.doors[id].principal_id == principal and state.doors[id].body_id == body: doors[id] = state.doors[id].duplicate(true)
	return {"walls": state.get("walls", {}).duplicate(true), "panels": panels, "doors": doors}


static func assess(value: Dictionary) -> ServiceResult:
	if not ControlContractValidation.has_exact_fields(value, PackedStringArray(["walls", "panels", "doors"])) or typeof(value.walls) != TYPE_DICTIONARY or typeof(value.panels) != TYPE_DICTIONARY or typeof(value.doors) != TYPE_DICTIONARY: return denied()
	if not SpatialWallConstruction.valid(value.walls) or not HorizontalPanelConstruction.valid(value.panels) or not PaidDoorGeometry.valid(value.doors, value.panels) or value.doors.size() != 1: return denied()
	var walls: ServiceResult = ConstructedWallBoundaries.describe(value.walls, 0)
	if not walls.is_success: return denied()
	var surfaces: Array[Dictionary] = []
	for id in value.panels: surfaces.append(HorizontalPanelConstruction.descriptor(id, value.panels[id]))
	var openings: Array[Dictionary] = []
	for id in value.doors:
		openings.append({"door_id": id, "position": value.doors[id].position.duplicate(), "quarter_turn": value.doors[id].quarter_turn})
	var result: ServiceResult = ConstructedDoorOpeningTopology.assess({"schema_version": 1, "production_revision": 0, "walls": walls.value, "surfaces": surfaces, "openings": openings})
	if not result.is_success or result.value.status != "enclosure_with_unsealed_openings": return denied()
	var bounds: Array = result.value.interior_bounds_millimetres
	var volume: float = float(int(bounds[1]) - int(bounds[0])) * float(int(bounds[3]) - int(bounds[2])) * 2000.0 / 1e9
	if not is_finite(volume) or volume <= 0.0 or volume > HABITAT_VOLUME - 1.0: return denied()
	return ServiceResult.success(volume)


static func valid_room(value: Variant) -> bool:
	if typeof(value) != TYPE_DICTIONARY or not ControlContractValidation.has_exact_fields(value, PackedStringArray(["schema_version", "policy_id", "volume_id", "sensor_id", "principal_id", "body_id", "world_id", "region_id", "door_id", "geometry"])): return false
	if not ControlContractValidation.is_integer(value.schema_version, 1, 2) or value.policy_id != (PaidRoomReinforcement.POLICY if int(value.schema_version) == 2 else POLICY) or value.region_id != "local-habitat": return false
	for field in ["volume_id", "sensor_id", "principal_id", "body_id", "world_id", "door_id"]:
		if not ControlContractValidation.is_id(value[field]): return false
	if not String(value.volume_id).begins_with("constructed-room-") or value.sensor_id != "%s-sensor" % value.volume_id or typeof(value.geometry) != TYPE_DICTIONARY: return false
	var assessment: ServiceResult = assess(value.geometry)
	if not assessment.is_success or not value.geometry.doors.has(value.door_id): return false
	var door: Dictionary = value.geometry.doors[value.door_id]
	return door.principal_id == value.principal_id and door.body_id == value.body_id and not door.seal.is_empty()


static func retained(actuator: ActuatorState, difference: float, reinforced: bool = false) -> bool:
	return actuator != null and actuator.position == 0.0 and actuator.integrity == 1.0 and actuator.mode == &"manual" and actuator.latch_state == &"released" and actuator.seal_condition == 1.0 and difference <= (PaidRoomReinforcement.RETENTION_KPA if reinforced else RETENTION_KPA) + TOLERANCE_KPA


static func validate_links(rooms: Dictionary, production: Dictionary, access: Dictionary, inventory: Dictionary = {}) -> ServiceResult:
	if not PaidRoomReinforcement.valid(production.get("room_reinforcements", {}), production.get("doors", {})): return denied()
	var areas: Dictionary = {}
	if rooms.size() > 1: return denied()
	for room in rooms.values():
		if not valid_room(room) or geometry(production, room.principal_id, room.body_id) != room.geometry: return denied()
		if (room.policy_id == PaidRoomReinforcement.POLICY) != production.get("room_reinforcements", {}).has(room.door_id): return denied()
		areas[room.door_id] = AREA
	return PaidDoorConstruction.links(production, access, inventory, areas)


static func denied() -> ServiceResult:
	return ServiceResult.failure(&"constructed_pressure_denied", "A current complete owned single-door enclosure and matching commissioned pressure policy are required.")
