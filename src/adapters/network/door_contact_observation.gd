extends RefCounted
class_name DoorContactObservation


static func valid_items(value: Variant) -> bool:
	if typeof(value) != TYPE_DICTIONARY or not ControlContractValidation.has_exact_fields(value, PackedStringArray(["schema_version", "control_epoch", "can_operate", "doors"])): return false
	if typeof(value.can_operate) != TYPE_BOOL: return false
	if not ControlContractValidation.is_integer(value.schema_version, 1, 6) or not ControlContractValidation.is_integer(value.control_epoch, -1, ProductionSimulationSystem.MAX_REVISION) or typeof(value.doors) != TYPE_ARRAY or value.doors.size() > PaidDoorGeometry.MAX_DOORS: return false
	var previous: String = ""
	for d in value.doors:
		var fields := PackedStringArray(["door_id", "position", "quarter_turn", "opened"])
		if int(value.schema_version) >= 2: fields.append_array(["seal_installed", "seal_condition"])
		if int(value.schema_version) >= 3: fields.append("pressure_room")
		if int(value.schema_version) >= 4: fields.append_array(["bypass_installed", "bypass_open"])
		if int(value.schema_version) >= 5: fields.append_array(["reinforcement_installed", "reinforcement_intact"])
		if int(value.schema_version) >= 6: fields.append_array(["chamber_kit_installed", "chamber"])
		if typeof(d) != TYPE_DICTIONARY or not ControlContractValidation.has_exact_fields(d, fields) or not ControlContractValidation.is_id(d.door_id) or not String(d.door_id).begins_with("door-") or typeof(d.opened) != TYPE_BOOL: return false
		if int(value.schema_version) >= 5 and (typeof(d.reinforcement_installed) != TYPE_BOOL or typeof(d.reinforcement_intact) != TYPE_BOOL or (d.reinforcement_intact and (not d.reinforcement_installed or not d.seal_installed or d.seal_condition != 1.0))): return false
		if int(value.schema_version) >= 2:
			if int(value.schema_version) >= 4 and (typeof(d.bypass_installed) != TYPE_BOOL or typeof(d.bypass_open) != TYPE_BOOL): return false
			if typeof(d.seal_installed) != TYPE_BOOL or typeof(d.seal_condition) not in [TYPE_INT, TYPE_FLOAT]: return false
			if not is_finite(float(d.seal_condition)) or float(d.seal_condition) < 0.0 or float(d.seal_condition) > 1.0 or (not d.seal_installed and d.seal_condition != 0.0): return false
		if int(value.schema_version) >= 3:
			if typeof(d.pressure_room) != TYPE_DICTIONARY: return false
			if int(value.schema_version) >= 4 and d.bypass_open and (not d.bypass_installed or d.pressure_room.is_empty()): return false
			if not d.pressure_room.is_empty():
				if not d.seal_installed or not ControlContractValidation.has_exact_fields(d.pressure_room, PackedStringArray(["volume_m3", "pressure_kpa", "ambient_pressure_kpa", "leaking"])) or typeof(d.pressure_room.leaking) != TYPE_BOOL: return false
				for key in ["volume_m3", "pressure_kpa", "ambient_pressure_kpa"]:
					if typeof(d.pressure_room[key]) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(d.pressure_room[key])) or float(d.pressure_room[key]) < 0.0: return false
				if d.pressure_room.volume_m3 <= 0.0 or d.pressure_room.volume_m3 > 999.0: return false
		if int(value.schema_version) >= 6 and (typeof(d.chamber_kit_installed) != TYPE_BOOL or not valid_chamber(d.chamber, d.door_id)): return false
		if String(d.door_id) <= previous or not SpatialWallConstruction.valid_pose({"position": d.position, "quarter_turn": d.quarter_turn}): return false
		previous = d.door_id
	return true


static func decode(value: Variant, world: StringName, region: StringName) -> ServiceResult:
	if typeof(value) != TYPE_DICTIONARY or not ControlContractValidation.has_exact_fields(value, PackedStringArray(["schema_version", "world_id", "region_id", "sequence", "inventory_restore", "production_restore", "production_revision", "production_tick", "inventory_tick", "boxes"])): return invalid()
	if not ControlContractValidation.is_integer(value.schema_version, 1, 1) or value.world_id != String(world) or value.region_id != String(region): return invalid()
	for field in ["sequence", "inventory_restore", "production_restore", "production_revision", "production_tick", "inventory_tick"]:
		if not ControlContractValidation.is_integer(value[field], 1 if field == "sequence" else 0, PaidPanelContactObservation.MAX_INTEGER): return invalid()
	if typeof(value.boxes) != TYPE_ARRAY or value.boxes.size() > 64 or value.boxes.size() % 4 != 0: return invalid()
	var previous: String = ""
	for first in range(0, value.boxes.size(), 4):
		var group: Dictionary = {}
		for role in range(4):
			var b: Variant = value.boxes[first + role]
			if typeof(b) != TYPE_DICTIONARY or not ControlContractValidation.has_exact_fields(b, PackedStringArray(["door_id", "role", "position", "quarter_turn", "opened", "center_millimetres", "size_millimetres"])): return invalid()
			if not ControlContractValidation.is_id(b.door_id) or not String(b.door_id).begins_with("door-") or not ControlContractValidation.is_integer(b.role, role, role) or typeof(b.opened) != TYPE_BOOL: return invalid()
			if not SpatialWallConstruction.valid_pose({"position": b.position, "quarter_turn": b.quarter_turn}): return invalid()
			if role == 0:
				if String(b.door_id) <= previous: return invalid()
				previous = b.door_id
				group = b
			elif b.door_id != group.door_id or b.position != group.position or b.quarter_turn != group.quarter_turn or b.opened != group.opened: return invalid()
			var expected: Dictionary = PaidDoorGeometry.solids(b, b.opened)[role]
			for field in ["center_millimetres", "size_millimetres"]:
				if typeof(b[field]) != TYPE_ARRAY or b[field].size() != 3: return invalid()
				for axis in range(3):
					if not ControlContractValidation.is_integer(b[field][axis], -101000, 101000) or b[field][axis] != expected[field][axis]: return invalid()
	return ServiceResult.success(value.duplicate(true))


static func invalid() -> ServiceResult:
	return ServiceResult.failure(&"invalid_door_contact", "Expected complete bounded door frame and leaf geometry in the current scope.")


static func valid_chamber(value: Variant, door_id: String) -> bool:
	if typeof(value) != TYPE_DICTIONARY: return false
	if value.is_empty(): return true
	if not ControlContractValidation.has_exact_fields(value, PackedStringArray(["inner_door_id", "outer_door_id", "side", "habitat_pressure_kpa", "chamber_pressure_kpa", "exterior_pressure_kpa", "inner_bypass_open", "outer_bypass_open"])): return false
	if not ControlContractValidation.is_id(value.inner_door_id) or not ControlContractValidation.is_id(value.outer_door_id) or value.inner_door_id == value.outer_door_id or door_id not in [value.inner_door_id, value.outer_door_id]: return false
	if value.side != ("inner" if door_id == value.inner_door_id else "outer") or typeof(value.inner_bypass_open) != TYPE_BOOL or typeof(value.outer_bypass_open) != TYPE_BOOL or (value.inner_bypass_open and value.outer_bypass_open): return false
	for field in ["habitat_pressure_kpa", "chamber_pressure_kpa", "exterior_pressure_kpa"]:
		if typeof(value[field]) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value[field])) or float(value[field]) < 0.0: return false
	return true
