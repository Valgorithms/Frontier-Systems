extends RefCounted
class_name ConstructedDoorOpeningTopology

## Internal v1 diagnostic. Aperture intervals complement walls, never solid walls.
## No cached state, pressure area, seal, room identity or mutation authority.
static func assess(input: Variant) -> ServiceResult:
	if typeof(input) != TYPE_DICTIONARY or not ControlContractValidation.has_exact_fields(input, PackedStringArray(["schema_version", "production_revision", "walls", "surfaces", "openings"])):
		return invalid()
	if not ControlContractValidation.is_integer(input.schema_version, 1, 1) or not ControlContractValidation.is_integer(input.production_revision, 0, ConstructedRoomClosure.MAX_REVISION): return invalid()
	var wall_check: ServiceResult = ConstructedRoomTopology.assess(input.walls)
	if not wall_check.is_success or int(wall_check.value.production_revision) != int(input.production_revision): return invalid()
	# Reuse strict surface validation without claiming that apertures are walls.
	var surface_check: ServiceResult = ConstructedRoomClosure.assess({"schema_version": 1, "production_revision": input.production_revision, "walls": input.walls, "surfaces": input.surfaces})
	if not surface_check.is_success or typeof(input.openings) != TYPE_ARRAY or input.openings.size() > PaidDoorGeometry.MAX_DOORS: return invalid()
	var walls: Array = []
	var apertures: Array = []
	var ids: Dictionary = {}
	for wall in input.walls.boundaries:
		ids[wall.wall_id] = true
		walls.append(band(wall.start_millimetres, wall.end_millimetres))
	var door_ids: Array[String] = []
	for opening in input.openings:
		if typeof(opening) != TYPE_DICTIONARY or not ControlContractValidation.has_exact_fields(opening, PackedStringArray(["door_id", "position", "quarter_turn"])): return invalid()
		if not ControlContractValidation.is_id(opening.door_id) or ids.has(opening.door_id) or not SpatialWallConstruction.valid_pose({"position": opening.position, "quarter_turn": opening.quarter_turn}): return invalid()
		ids[opening.door_id] = true
		door_ids.append(String(opening.door_id))
		var a: Array = opening.position.duplicate()
		var b: Array = opening.position.duplicate()
		var axis: int = 0 if int(opening.quarter_turn) == 0 else 2
		a[axis] -= 500
		b[axis] += 500
		apertures.append(band(a, b))
	var pieces: Array = walls + apertures
	for index in range(pieces.size()):
		for previous in range(index):
			if ConstructedRoomClosure.overlaps(pieces[index], pieces[previous]): return invalid()
	var bounds: Array = []
	if not walls.is_empty() and not apertures.is_empty():
		var exterior: Array = pieces[0].slice(0, 4)
		for piece in pieces:
			exterior = [mini(exterior[0], piece[0]), maxi(exterior[1], piece[1]), mini(exterior[2], piece[2]), maxi(exterior[3], piece[3])]
		if complements(walls, apertures, exterior, false) or complements(walls, apertures, exterior, true):
			bounds = [exterior[0] + 100, exterior[1] - 100, exterior[2] + 100, exterior[3] - 100]
	var surfaces: Array[Dictionary] = []
	for raw in input.surfaces:
		var surface: Dictionary = ConstructedRoomSurface.decode(raw).value
		if bounds.is_empty(): continue
		var b: Array = surface.bounds_millimetres
		var clipped: Array = [maxi(b[0], bounds[0]), mini(b[1], bounds[1]), maxi(b[2], bounds[2]), mini(b[3], bounds[3])]
		if clipped[0] >= clipped[1] or clipped[2] >= clipped[3]: continue
		surface.bounds_millimetres = clipped
		surfaces.append(surface)
	var complete: bool = not bounds.is_empty() and ConstructedRoomClosure.covers(surfaces, "floor", bounds) and ConstructedRoomClosure.covers(surfaces, "ceiling", bounds)
	door_ids.sort()
	if bounds.is_empty(): door_ids.clear()
	return ServiceResult.success({"schema_version": 1, "production_revision": int(input.production_revision), "status": "enclosure_with_unsealed_openings" if complete else "open_or_unsupported", "interior_bounds_millimetres": bounds, "door_ids": door_ids})


static func band(a: Array, b: Array) -> Array:
	var along_x: bool = a[2] == b[2]
	return [mini(int(a[0]), int(b[0])) - (0 if along_x else 50), maxi(int(a[0]), int(b[0])) + (0 if along_x else 50), mini(int(a[2]), int(b[2])) - (50 if along_x else 0), maxi(int(a[2]), int(b[2])) + (50 if along_x else 0), along_x]


## Each side has separate solid and aperture intervals. Their exact disjoint
## union must span the side; no aperture can fill a corner or an interior wall.
static func complements(walls: Array, apertures: Array, exterior: Array, transpose: bool) -> bool:
	var e: Array = [exterior[2], exterior[3], exterior[0], exterior[1]] if transpose else exterior
	if e[1] - e[0] <= 200 or e[3] - e[2] <= 200: return false
	var solids: Array = [[], [], [], []]
	var holes: Array = [[], [], [], []]
	for kind in range(2):
		for original in (walls if kind == 0 else apertures):
			var b: Array = [original[2], original[3], original[0], original[1], not original[4]] if transpose else original
			var side: int = -1
			var interval: Array = []
			if b[4] and b[2] == e[2] and b[3] == e[2] + 100: side = 0; interval = [b[0], b[1]]
			elif b[4] and b[2] == e[3] - 100 and b[3] == e[3]: side = 1; interval = [b[0], b[1]]
			elif not b[4] and b[0] == e[0] and b[1] == e[0] + 100: side = 2; interval = [b[2], b[3]]
			elif not b[4] and b[0] == e[1] - 100 and b[1] == e[1]: side = 3; interval = [b[2], b[3]]
			else: return false
			if kind == 1 and side < 2 and (interval[0] < e[0] + 100 or interval[1] > e[1] - 100): return false
			if kind == 0: solids[side].append(interval)
			else: holes[side].append(interval)
	for side in range(4):
		var start: int = int(e[0] if side < 2 else e[2] + 100)
		var end: int = int(e[1] if side < 2 else e[3] - 100)
		if not ConstructedRoomTopology.covers(solids[side] + holes[side], start, end): return false
	return true


static func invalid() -> ServiceResult:
	return ServiceResult.failure(&"invalid_door_opening_topology", "Expected revision-matched bounded v1 walls, surfaces and unique ground-level doorway apertures.")
