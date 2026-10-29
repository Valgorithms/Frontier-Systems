extends RefCounted
class_name PaidPanelContactObservation

## Read-only contact assistance. Decoding cannot authenticate a connection.
const MAX_INTEGER: int = 9007199254740000


static func decode(value: Variant, world: StringName, region: StringName) -> ServiceResult:
	if typeof(value) != TYPE_DICTIONARY or not ControlContractValidation.has_exact_fields(value, PackedStringArray(["schema_version", "world_id", "region_id", "sequence", "inventory_restore", "production_restore", "geometry"])): return invalid()
	if not ControlContractValidation.is_integer(value.schema_version, 1, 1) or value.world_id != String(world) or value.region_id != String(region): return invalid()
	for field in ["sequence", "inventory_restore", "production_restore"]:
		if not ControlContractValidation.is_integer(value[field], 1 if field == "sequence" else 0, MAX_INTEGER): return invalid()
	var geometry: Variant = value.geometry
	if typeof(geometry) != TYPE_DICTIONARY or not ControlContractValidation.has_exact_fields(geometry, PackedStringArray(["schema_version", "world_id", "region_id", "coordinate_frame", "production_revision", "production_tick", "inventory_tick", "boxes", "profiling"])): return invalid()
	if not ControlContractValidation.is_integer(geometry.schema_version, 1, 1) or geometry.world_id != String(world) or geometry.region_id != String(region) or geometry.coordinate_frame != "station_millimetres": return invalid()
	for field in ["production_revision", "production_tick", "inventory_tick"]:
		if not ControlContractValidation.is_integer(geometry[field], 0, MAX_INTEGER): return invalid()
	if typeof(geometry.boxes) != TYPE_ARRAY or geometry.boxes.size() > 64: return invalid()
	if typeof(geometry.profiling) != TYPE_DICTIONARY or not ControlContractValidation.has_exact_fields(geometry.profiling, PackedStringArray(["inspected_panels"])) or not ControlContractValidation.is_integer(geometry.profiling.inspected_panels, geometry.boxes.size(), geometry.boxes.size()): return invalid()
	var panels: Dictionary = {}
	var previous: String = ""
	for box in geometry.boxes:
		if typeof(box) != TYPE_DICTIONARY or not ControlContractValidation.has_exact_fields(box, PackedStringArray(["surface_id", "kind", "center_millimetres", "size_millimetres"])): return invalid()
		if not ControlContractValidation.is_id(box.surface_id) or typeof(box.kind) != TYPE_STRING or box.kind not in ["floor", "ceiling"]: return invalid()
		if not previous.is_empty() and String(box.surface_id) <= previous: return invalid()
		previous = box.surface_id
		for field in ["center_millimetres", "size_millimetres"]:
			if typeof(box[field]) != TYPE_ARRAY or box[field].size() != 3: return invalid()
			for coordinate in box[field]:
				if not ControlContractValidation.is_integer(coordinate, -101000, 101000): return invalid()
		var center: Array = box.center_millimetres
		var size: Array = box.size_millimetres
		if center[1] != (-6 if box.kind == "floor" else 2006) or size[1] != 12: return invalid()
		if size[0] < 50 or size[0] > 1000 or size[2] < 50 or size[2] > 1000: return invalid()
		for axis in [0, 2]:
			if int(size[axis]) % 50 != 0 or (2 * int(center[axis]) - int(size[axis])) % 100 != 0: return invalid()
		var bounds: Array = [int(center[0]) - int(size[0]) / 2, int(center[0]) + int(size[0]) / 2, int(center[2]) - int(size[2]) / 2, int(center[2]) + int(size[2]) / 2]
		# Canonical paid validation enforces exact bounds, grid, overlap and capacity.
		panels[box.surface_id] = {"kind": box.kind, "bounds_millimetres": bounds, "height_millimetres": 0 if box.kind == "floor" else 2000, "blueprint_id": HorizontalPanelConstruction.BLUEPRINT, "blueprint_revision": 1, "principal_id": "contact.validation", "materials": {"plate": int(size[0]) * int(size[2])}}
	if not HorizontalPanelConstruction.valid(panels): return invalid()
	var normalized: Dictionary = value.duplicate(true)
	for field in ["schema_version", "sequence", "inventory_restore", "production_restore"]: normalized[field] = int(normalized[field])
	for field in ["schema_version", "production_revision", "production_tick", "inventory_tick"]: normalized.geometry[field] = int(normalized.geometry[field])
	for box in normalized.geometry.boxes:
		for field in ["center_millimetres", "size_millimetres"]:
			for axis in range(3): box[field][axis] = int(box[field][axis])
	return ServiceResult.success(normalized)


static func invalid() -> ServiceResult:
	return ServiceResult.failure(&"invalid_panel_contact", "Expected complete bounded contact geometry in the authenticated scope.")
