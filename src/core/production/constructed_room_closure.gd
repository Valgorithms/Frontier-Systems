extends RefCounted
class_name ConstructedRoomClosure

## Pure composition, no state/tick/seal owner. Validate raw descriptors every call.
const MAX_SURFACES: int = 64
const MAX_REVISION: int = 9007199254740000


static func assess(input: Variant) -> ServiceResult:
	if typeof(input) != TYPE_DICTIONARY:
		return invalid()
	if not ControlContractValidation.has_exact_fields(input, PackedStringArray(["schema_version", "production_revision", "walls", "surfaces"])):
		return invalid()
	if not ControlContractValidation.is_integer(input.schema_version, 1, 1) or not ControlContractValidation.is_integer(input.production_revision, 0, MAX_REVISION):
		return invalid()
	var topology: ServiceResult = ConstructedRoomTopology.assess(input.walls)
	if not topology.is_success:
		return invalid()
	if int(input.production_revision) != int(topology.value.production_revision):
		return invalid()
	if typeof(input.surfaces) != TYPE_ARRAY or input.surfaces.size() > MAX_SURFACES:
		return invalid()
	var ids: Dictionary = {}
	var surfaces: Array[Dictionary] = []
	for raw in input.surfaces:
		var decoded: ServiceResult = ConstructedRoomSurface.decode(raw)
		if not decoded.is_success:
			return invalid()
		var surface: Dictionary = decoded.value
		if ids.has(surface.surface_id):
			return invalid()
		ids[surface.surface_id] = true
		for other in surfaces:
			if surface.kind == other.kind and overlaps(surface.bounds_millimetres, other.bounds_millimetres):
				return invalid()
		surfaces.append(surface)
	var bounds: Array = topology.value.interior_bounds_millimetres
	var missing: Array[String] = ["floor", "ceiling"]
	if not bounds.is_empty():
		for kind in ["floor", "ceiling"]:
			if covers(surfaces, kind, bounds):
				missing.erase(kind)
	var stable_ids: Array = ids.keys()
	stable_ids.sort()
	return ServiceResult.success({"schema_version": 1, "production_revision": int(input.production_revision),
		"status": "geometrically_closed" if not bounds.is_empty() and missing.is_empty() else "open_or_unsupported",
		"interior_bounds_millimetres": bounds.duplicate(), "missing_surfaces": missing, "surface_ids": stable_ids})


static func overlaps(a: Array, b: Array) -> bool:
	return maxi(a[0], b[0]) < mini(a[1], b[1]) and maxi(a[2], b[2]) < mini(a[3], b[3])


static func covers(surfaces: Array[Dictionary], kind: String, bounds: Array) -> bool:
	# Non-overlapping rectangles wholly inside the target cover it iff areas match.
	# Integer products are <= 40,401,000,000 mm2, safely within int64.
	var area: int = 0
	for surface in surfaces:
		if surface.kind != kind:
			continue
		var b: Array = surface.bounds_millimetres
		if b[0] < bounds[0] or b[1] > bounds[1] or b[2] < bounds[2] or b[3] > bounds[3]:
			return false
		area += (int(b[1]) - int(b[0])) * (int(b[3]) - int(b[2]))
	return area == (int(bounds[1]) - int(bounds[0])) * (int(bounds[3]) - int(bounds[2]))


static func invalid() -> ServiceResult:
	return ServiceResult.failure(&"invalid_room_closure", "Expected revision-matched v1 walls and at most 64 unique non-overlapping floor/ceiling rectangles.")
