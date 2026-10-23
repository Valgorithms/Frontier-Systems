extends SceneTree

var failures: int = 0


func _initialize() -> void:
	var fixture: Dictionary = room()
	var before: Dictionary = fixture.duplicate(true)
	var result: ServiceResult = ConstructedRoomClosure.assess(fixture)
	check(result.is_success and result.value.status == "geometrically_closed", "actual fixed-panel perimeter plus explicit surfaces closes geometry")
	check(result.value.interior_bounds_millimetres == [5100, 6900, -4500, -3500], "uses paid-layout inner wall faces")
	check(fixture == before and not result.value.has("sealed") and not result.value.has("room_id"), "no mutation or canonical seal claim")
	var reordered: Dictionary = fixture.duplicate(true)
	reordered.surfaces.reverse()
	reordered.walls.boundaries.reverse()
	check(ConstructedRoomClosure.assess(reordered).value == result.value, "stable IDs and order-independent result")
	check(ConstructedRoomClosure.assess(JSON.parse_string(JSON.stringify(fixture))).value == result.value, "JSON round trip")
	result.value.surface_ids.clear()
	check(ConstructedRoomClosure.assess(fixture).value.surface_ids.size() == 3, "detached uncached output")
	for index in range(3):
		var missing: Dictionary = room()
		missing.surfaces.remove_at(index)
		check(is_open(missing), "each missing tile prevents closure")
	var gap: Dictionary = room()
	gap.surfaces[0].bounds_millimetres[1] -= 1
	check(is_open(gap), "one mm gap fails closed")
	gap = room()
	gap.surfaces[0].bounds_millimetres[0] -= 1
	check(is_open(gap), "overhang cannot count as coverage")
	gap = room()
	gap.walls.boundaries.remove_at(0)
	check(is_open(gap), "missing actual wall fails closed")
	gap = room()
	gap.surfaces = []
	check(is_open(gap), "empty surfaces valid open")
	gap.walls.boundaries = []
	check(is_open(gap), "empty walls valid open")
	# Translation and transpose exercise X/Z independently, including negative coordinates.
	var translated: Dictionary = room()
	for wall in translated.walls.boundaries:
		for point in [wall.start_millimetres, wall.end_millimetres]:
			var x: int = point[0]
			point[0] = point[2] - 1000
			point[2] = x - 10000
	for surface in translated.surfaces:
		var b: Array = surface.bounds_millimetres
		surface.bounds_millimetres = [b[2] - 1000, b[3] - 1000, b[0] - 10000, b[1] - 10000]
	check(ConstructedRoomClosure.assess(translated).value.status == "geometrically_closed", "translated transposed tiling")
	var invalids: Array = [null, [], {}, true]
	for field in ["schema_version", "production_revision", "walls", "surfaces"]:
		var bad: Dictionary = room()
		bad.erase(field)
		invalids.append(bad)
	for value in [-1, 1.5, true, "1", INF, NAN, 9007199254740001]:
		var bad: Dictionary = room()
		bad.production_revision = value
		invalids.append(bad)
	var stale: Dictionary = room()
	stale.production_revision += 1
	invalids.append(stale)
	stale = room()
	stale.sealed = true
	invalids.append(stale)
	for value in [null, {}, "x"]:
		var bad: Dictionary = room()
		bad.surfaces = value
		invalids.append(bad)
	for value in [null, {}, [], true]:
		var bad: Dictionary = room()
		bad.surfaces[0] = value
		invalids.append(bad)
	for field in ConstructedRoomSurface.FIELDS:
		var bad: Dictionary = room()
		bad.surfaces[0].erase(field)
		invalids.append(bad)
	for field in ["surface_id", "kind", "height_millimetres", "bounds_millimetres"]:
		for value in [null, {}, [], true, INF, NAN, "", 0.5]:
			var bad: Dictionary = room()
			bad.surfaces[0][field] = value
			invalids.append(bad)
	for bounds in [[5100, 5100, -4500, -3500], [6900, 5100, -4500, -3500], [5100, 6000, -3500, -4500], [5100, 6000, -4500], [5100.1, 6000, -4500, -3500], [true, 6000, -4500, -3500], [-100501, 6000, -4500, -3500], [5100, 100501, -4500, -3500], [NAN, 6000, -4500, -3500]]:
		var bad: Dictionary = room()
		bad.surfaces[0].bounds_millimetres = bounds
		invalids.append(bad)
	for id in [" ", "x".repeat(129), "floor-b"]:
		var bad: Dictionary = room()
		bad.surfaces[0].surface_id = id
		invalids.append(bad)
	for height in [1, 2000]:
		var bad: Dictionary = room()
		bad.surfaces[0].height_millimetres = height
		invalids.append(bad)
	stale = room()
	stale.surfaces[2].height_millimetres = 0
	invalids.append(stale)
	stale = room()
	stale.surfaces[0].paid = true
	invalids.append(stale)
	stale = room()
	stale.surfaces[0].bounds_millimetres[1] += 1
	invalids.append(stale)
	# Equal total area with a gap and overlap must fail (area alone is insufficient).
	stale = room()
	stale.surfaces[0].bounds_millimetres = [5100, 6100, -4500, -3500]
	stale.surfaces[1].bounds_millimetres = [6000, 6800, -4500, -3500]
	invalids.append(stale)
	stale = room()
	stale.walls.boundaries[0].height_millimetres = 1999
	invalids.append(stale)
	for bad in invalids:
		check(not ConstructedRoomClosure.assess(bad).is_success, "malformed, overlapping or stale descriptor rejected")
	var capacity: Dictionary = room()
	capacity.surfaces = [surface("ceiling", "ceiling", [5100, 6900, -4500, -3500])]
	for index in range(63):
		capacity.surfaces.append(surface("tile-%d" % index, "floor", [5100 + index, 5101 + index if index < 62 else 6900, -4500, -3500]))
	capacity.production_revision = 9007199254740000
	capacity.walls.production_revision = capacity.production_revision
	check(ConstructedRoomClosure.assess(capacity).value.status == "geometrically_closed", "64 surfaces and maximum revision accepted")
	capacity.surfaces.append(surface("extra", "floor", [0, 1, 0, 1]))
	check(not ConstructedRoomClosure.assess(capacity).is_success, "65 surfaces rejected")
	check(ConstructedRoomSurface.decode(surface("limits", "floor", [-100500, 100500, -100500, 100500])).is_success, "exact coordinate bounds accepted")
	print("Constructed room closure: %d failures" % failures)
	quit(1 if failures else 0)


func room() -> Dictionary:
	# Same fixed panel positions as paid_wall_perimeter_test; descriptors do not pay for surfaces.
	var records: Dictionary = {}
	var placements: Array = [[5500, -4550, 0], [6500, -4550, 0], [5500, -3450, 0], [6500, -3450, 0], [5050, -4000, 1], [6950, -4000, 1]]
	for index in range(placements.size()):
		var p: Array = placements[index]
		records["wall-%d" % index] = {"position": [p[0], 0, p[1]], "quarter_turn": p[2]}
	return {"schema_version": 1, "production_revision": 42, "walls": ConstructedWallBoundaries.describe(records, 42).value,
		"surfaces": [surface("floor-a", "floor", [5100, 6000, -4500, -3500]), surface("floor-b", "floor", [6000, 6900, -4500, -3500]), surface("ceiling", "ceiling", [5100, 6900, -4500, -3500])]}


func surface(id: String, kind: String, bounds: Array) -> Dictionary:
	return {"surface_id": id, "kind": kind, "bounds_millimetres": bounds, "height_millimetres": 0 if kind == "floor" else 2000}


func is_open(input: Dictionary) -> bool:
	var result: ServiceResult = ConstructedRoomClosure.assess(input)
	return result.is_success and result.value.status == "open_or_unsupported"


func check(passed: bool, message: String) -> void:
	if passed:
		return
	failures += 1
	push_error(message)
