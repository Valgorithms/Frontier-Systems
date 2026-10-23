extends RefCounted
class_name DoorContactObservation


static func valid_items(value: Variant) -> bool:
	if typeof(value) != TYPE_DICTIONARY or not ControlContractValidation.has_exact_fields(value, PackedStringArray(["schema_version", "control_epoch", "doors"])): return false
	if not ControlContractValidation.is_integer(value.schema_version, 1, 1) or not ControlContractValidation.is_integer(value.control_epoch, -1, ProductionSimulationSystem.MAX_REVISION) or typeof(value.doors) != TYPE_ARRAY or value.doors.size() > PaidDoorGeometry.MAX_DOORS: return false
	var previous: String = ""
	for d in value.doors:
		if typeof(d) != TYPE_DICTIONARY or not ControlContractValidation.has_exact_fields(d, PackedStringArray(["door_id", "position", "quarter_turn", "opened"])) or not ControlContractValidation.is_id(d.door_id) or not String(d.door_id).begins_with("door-") or typeof(d.opened) != TYPE_BOOL: return false
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
