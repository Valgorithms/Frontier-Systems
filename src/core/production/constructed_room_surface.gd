extends RefCounted
class_name ConstructedRoomSurface

## Detached integer-mm rectangle value; never a paid construction record.
const MAX_COORDINATE: int = 100500
const FIELDS: Array[String] = ["surface_id", "kind", "bounds_millimetres", "height_millimetres"]


static func decode(input: Variant) -> ServiceResult:
	if typeof(input) != TYPE_DICTIONARY:
		return invalid()
	if not ControlContractValidation.has_exact_fields(input, PackedStringArray(FIELDS)):
		return invalid()
	if not ControlContractValidation.is_id(input.surface_id) or typeof(input.kind) != TYPE_STRING or input.kind not in ["floor", "ceiling"]:
		return invalid()
	if not ControlContractValidation.is_integer(input.height_millimetres, 0, 2000):
		return invalid()
	if int(input.height_millimetres) != (0 if input.kind == "floor" else 2000):
		return invalid()
	if typeof(input.bounds_millimetres) != TYPE_ARRAY or input.bounds_millimetres.size() != 4:
		return invalid()
	var bounds: Array[int] = []
	for number in input.bounds_millimetres:
		if not ControlContractValidation.is_integer(number, -MAX_COORDINATE, MAX_COORDINATE):
			return invalid()
		bounds.append(int(number))
	if bounds[0] >= bounds[1] or bounds[2] >= bounds[3]:
		return invalid()
	return ServiceResult.success({"surface_id": String(input.surface_id), "kind": String(input.kind),
		"bounds_millimetres": bounds, "height_millimetres": int(input.height_millimetres)})


static func invalid() -> ServiceResult:
	return ServiceResult.failure(&"invalid_room_surface", "Expected an identified bounded rectangle at floor 0 or ceiling 2000 mm.")
