extends RefCounted
class_name ConstructedRoomTopology

## Pure assessment of detached v1 wall descriptors. No state, tick or seal owner.
## Only a rectangular wall band with exact butt contact is supported.
const MAX_PANELS: int = 32
const MAX_COORDINATE: int = 100500


static func assess(input: Variant) -> ServiceResult:
	if typeof(input) != TYPE_DICTIONARY:
		return invalid()
	if not ControlContractValidation.has_exact_fields(input, PackedStringArray(["schema_version", "production_revision", "boundaries"])):
		return invalid()
	if not ControlContractValidation.is_integer(input.schema_version, 1, 1) or not ControlContractValidation.is_integer(input.production_revision, 0, 9007199254740000):
		return invalid()
	if typeof(input.boundaries) != TYPE_ARRAY or input.boundaries.size() > MAX_PANELS:
		return invalid()
	var boxes: Array = []
	var ids: Dictionary = {}
	for panel in input.boundaries:
		if typeof(panel) != TYPE_DICTIONARY:
			return invalid()
		if not ControlContractValidation.has_exact_fields(panel, PackedStringArray(["wall_id", "start_millimetres", "end_millimetres", "height_millimetres", "thickness_millimetres"])):
			return invalid()
		if not ControlContractValidation.is_id(panel.wall_id) or ids.has(panel.wall_id):
			return invalid()
		ids[panel.wall_id] = true
		if not valid_point(panel.start_millimetres) or not valid_point(panel.end_millimetres):
			return invalid()
		if not ControlContractValidation.is_integer(panel.height_millimetres, 2000, 2000) or not ControlContractValidation.is_integer(panel.thickness_millimetres, 100, 100):
			return invalid()
		var a: Array = panel.start_millimetres
		var b: Array = panel.end_millimetres
		# All walls stand on y=0; reversed endpoints are harmless.
		if a[1] != 0 or b[1] != 0 or (a[0] == b[0]) == (a[2] == b[2]):
			return invalid()
		var along_x: bool = a[2] == b[2]
		var box: Array = [mini(int(a[0]), int(b[0])) - (0 if along_x else 50), maxi(int(a[0]), int(b[0])) + (0 if along_x else 50),
			mini(int(a[2]), int(b[2])) - (50 if along_x else 0), maxi(int(a[2]), int(b[2])) + (50 if along_x else 0), along_x]
		for other in boxes:
			if maxi(box[0], other[0]) < mini(box[1], other[1]) and maxi(box[2], other[2]) < mini(box[3], other[3]):
				return invalid()
		boxes.append(box)
	var bounds: Array = []
	if boxes.size() >= 4:
		var exterior: Array = [boxes[0][0], boxes[0][1], boxes[0][2], boxes[0][3]]
		for box in boxes:
			exterior = [mini(exterior[0], box[0]), maxi(exterior[1], box[1]), mini(exterior[2], box[2]), maxi(exterior[3], box[3])]
		if rectangular_band(boxes, exterior, false) or rectangular_band(boxes, exterior, true):
			bounds = [exterior[0] + 100, exterior[1] - 100, exterior[2] + 100, exterior[3] - 100]
	return ServiceResult.success({"schema_version": 1, "production_revision": int(input.production_revision),
		"status": "closed_wall_perimeter" if not bounds.is_empty() else "open_or_unsupported",
		"interior_bounds_millimetres": bounds, "required_surfaces": ["floor", "ceiling"]})


static func valid_point(value: Variant) -> bool:
	if typeof(value) != TYPE_ARRAY or value.size() != 3:
		return false
	for number in value:
		if not ControlContractValidation.is_integer(number, -MAX_COORDINATE, MAX_COORDINATE):
			return false
	return true


## One orientation uses full-width X caps and Z sides between their inner faces.
## The transpose supports full-depth Z caps. Mixed or overlapping joins fail closed.
static func rectangular_band(boxes: Array, exterior: Array, transpose: bool) -> bool:
	var e: Array = [exterior[2], exterior[3], exterior[0], exterior[1]] if transpose else exterior
	if e[1] - e[0] <= 200 or e[3] - e[2] <= 200:
		return false
	var sides: Array = [[], [], [], []]
	for original in boxes:
		var b: Array = [original[2], original[3], original[0], original[1], not original[4]] if transpose else original
		if b[4] and b[2] == e[2] and b[3] == e[2] + 100:
			sides[0].append([b[0], b[1]])
		elif b[4] and b[2] == e[3] - 100 and b[3] == e[3]:
			sides[1].append([b[0], b[1]])
		elif not b[4] and b[0] == e[0] and b[1] == e[0] + 100:
			sides[2].append([b[2], b[3]])
		elif not b[4] and b[0] == e[1] - 100 and b[1] == e[1]:
			sides[3].append([b[2], b[3]])
		else:
			return false
	return covers(sides[0], e[0], e[1]) and covers(sides[1], e[0], e[1]) and covers(sides[2], e[2] + 100, e[3] - 100) and covers(sides[3], e[2] + 100, e[3] - 100)


static func covers(intervals: Array, start: int, end: int) -> bool:
	intervals.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var cursor: int = start
	for interval in intervals:
		if interval[0] != cursor or interval[1] > end:
			return false
		cursor = interval[1]
	return cursor == end


static func invalid() -> ServiceResult:
	return ServiceResult.failure(&"invalid_room_topology", "Expected bounded v1 descriptors with unique IDs, ground-level axis-aligned non-overlapping panels of height 2000 and thickness 100 mm.")
