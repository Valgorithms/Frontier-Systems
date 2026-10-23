extends SceneTree

var failures: int = 0


func _initialize() -> void:
	var fixture: Dictionary = rectangle()
	var before: Dictionary = fixture.duplicate(true)
	var result: ServiceResult = ConstructedRoomTopology.assess(fixture)
	check(result.is_success and result.value.status == "closed_wall_perimeter", "exact butt joins close mathematical perimeter")
	check(result.value.interior_bounds_millimetres == [100, 1900, 50, 2050], "interior follows physical inner faces")
	check(result.value.required_surfaces == ["floor", "ceiling"] and not result.value.has("room_id") and not result.value.has("sealed"), "no complete enclosure claim without surfaces")
	check(fixture == before, "assessment preserves input")
	var detached: Array = result.value.interior_bounds_millimetres
	detached[0] = -999
	check(ConstructedRoomTopology.assess(fixture).value.interior_bounds_millimetres[0] == 100, "results detached and uncached")
	var reversed: Dictionary = fixture.duplicate(true)
	reversed.boundaries.reverse()
	for panel in reversed.boundaries:
		var a: Array = panel.start_millimetres
		panel.start_millimetres = panel.end_millimetres
		panel.end_millimetres = a
	check(ConstructedRoomTopology.assess(reversed).value == ConstructedRoomTopology.assess(fixture).value, "insertion and endpoint order independent")
	check(ConstructedRoomTopology.assess(JSON.parse_string(JSON.stringify(fixture))).value == ConstructedRoomTopology.assess(fixture).value, "JSON integer-valued floats accepted")
	var rotated: Dictionary = fixture.duplicate(true)
	for panel in rotated.boundaries:
		for point in [panel.start_millimetres, panel.end_millimetres]:
			var x: int = point[0]
			point[0] = point[2]
			point[2] = x
	check(ConstructedRoomTopology.assess(rotated).value.status == "closed_wall_perimeter", "transposed cap orientation supported")
	var shifted: Dictionary = fixture.duplicate(true)
	for item in shifted.boundaries:
		for point in [item.start_millimetres, item.end_millimetres]:
			point[0] -= 10000
			point[2] -= 10000
	check(ConstructedRoomTopology.assess(shifted).value.interior_bounds_millimetres == [-9900, -8100, -9950, -7950], "negative translated geometry retains exact inner faces")
	var segmented: Dictionary = fixture.duplicate(true)
	segmented.boundaries[0].end_millimetres[0] = 1000
	segmented.boundaries.append(panel("cap-extension", [1000, 0, 0], [2000, 0, 0]))
	check(ConstructedRoomTopology.assess(segmented).value.status == "closed_wall_perimeter", "collinear contiguous segments cover side")
	segmented.boundaries[0].end_millimetres[0] = 999
	check(open_result(segmented), "one millimetre gap fails closed")
	var full_rectangle: Dictionary = rectangle()
	full_rectangle.boundaries.remove_at(0)
	for index in range(29):
		var start: int = index * 60
		var end: int = (index + 1) * 60 if index < 28 else 2000
		full_rectangle.boundaries.append(panel("segment-%d" % index, [start, 0, 0], [end, 0, 0]))
	check(ConstructedRoomTopology.assess(full_rectangle).value.status == "closed_wall_perimeter", "32 panel closed coverage accepted")
	full_rectangle.boundaries[3].end_millimetres[0] -= 1
	check(open_result(full_rectangle), "capacity boundary still detects 1 mm gap")
	for index in range(4):
		var missing: Dictionary = fixture.duplicate(true)
		missing.boundaries.remove_at(index)
		check(open_result(missing), "each absent wall fails closed")
	check(open_result({"schema_version": 1, "production_revision": 0, "boundaries": []}), "empty input is open")
	var unsupported: Dictionary = fixture.duplicate(true)
	unsupported.boundaries.append(panel("interior", [500, 0, 1000], [1500, 0, 1000]))
	check(open_result(unsupported), "interior partition unsupported")
	unsupported = fixture.duplicate(true)
	unsupported.boundaries.append(panel("branch", [2000, 0, 0], [2500, 0, 0]))
	check(open_result(unsupported), "external extension unsupported")
	var invalids: Array = [null, [], {}, {"schema_version": true, "production_revision": 0, "boundaries": []}]
	for field in ["schema_version", "production_revision", "boundaries"]:
		var missing: Dictionary = fixture.duplicate(true)
		missing.erase(field)
		invalids.append(missing)
	for value in [-1, 1.5, "1", true, INF, NAN, 9007199254740001]:
		var bad: Dictionary = fixture.duplicate(true)
		bad.production_revision = value
		invalids.append(bad)
	for value in [null, {}, "x"]:
		var bad: Dictionary = fixture.duplicate(true)
		bad.boundaries = value
		invalids.append(bad)
	for value in [null, [], {}, {"wall_id": "x"}]:
		var bad: Dictionary = fixture.duplicate(true)
		bad.boundaries[0] = value
		invalids.append(bad)
	for value in [null, [0, 0], [true, 0, 0], [0.1, 0, 0], [INF, 0, 0], [NAN, 0, 0], [100501, 0, 0], [-100501, 0, 0], [0, 1, 0], [0, 0, 2100], [1, 0, 1], [2000, 0, 0]]:
		var bad: Dictionary = fixture.duplicate(true)
		bad.boundaries[0].start_millimetres = value
		invalids.append(bad)
	for field in ["height_millimetres", "thickness_millimetres"]:
		for value in [0, -1, 100.5, "100", true, INF, NAN]:
			var bad: Dictionary = fixture.duplicate(true)
			bad.boundaries[0][field] = value
			invalids.append(bad)
	for value in ["", " ", true, "x".repeat(129), "north"]:
		var bad: Dictionary = fixture.duplicate(true)
		bad.boundaries[1].wall_id = value
		invalids.append(bad)
	var extra: Dictionary = fixture.duplicate(true)
	extra.sealed = true
	invalids.append(extra)
	extra = fixture.duplicate(true)
	extra.boundaries[0].sealed = true
	invalids.append(extra)
	extra = fixture.duplicate(true)
	extra.boundaries.append(panel("duplicate-solid", [0, 0, 0], [2000, 0, 0]))
	invalids.append(extra)
	extra = fixture.duplicate(true)
	extra.boundaries.append(panel("cross", [1000, 0, -100], [1000, 0, 300]))
	invalids.append(extra)
	extra = fixture.duplicate(true)
	extra.boundaries.append(panel("collinear-overlap", [500, 0, 0], [2500, 0, 0]))
	invalids.append(extra)
	for bad in invalids:
		check(not ConstructedRoomTopology.assess(bad).is_success, "malformed, duplicate or intersecting descriptors rejected")
	var capacity: Dictionary = {"schema_version": 1, "production_revision": 9007199254740000, "boundaries": []}
	for index in range(32):
		capacity.boundaries.append(panel("panel-%d" % index, [index * 1000, 0, 0], [index * 1000 + 500, 0, 0]))
	check(open_result(capacity), "32 panel capacity accepted but open")
	capacity.boundaries.append(panel("extra", [-2000, 0, 0], [-1000, 0, 0]))
	check(not ConstructedRoomTopology.assess(capacity).is_success, "33 panel capacity rejected")
	var extremes: Dictionary = {"schema_version": 1, "production_revision": 0, "boundaries": [panel("extreme", [-100500, 0, 100500], [100500, 0, 100500])]}
	check(open_result(extremes), "exact coordinate limits accepted without overflow")
	var canonical: Dictionary = {"north": {"position": [500, 0, 0], "quarter_turn": 0},
		"south": {"position": [500, 0, 1000], "quarter_turn": 0},
		"west": {"position": [-100, 0, 500], "quarter_turn": 1},
		"east": {"position": [1100, 0, 500], "quarter_turn": 1}}
	var described: ServiceResult = ConstructedWallBoundaries.describe(canonical, 12)
	check(described.is_success and open_result(described.value), "legacy 100 mm layout's 50 mm corner gaps grant no enclosure")
	print("Constructed room topology: %d failures" % failures)
	quit(1 if failures else 0)


func rectangle() -> Dictionary:
	# Synthetic variable-span descriptors; paid fixed-panel construction is tested separately.
	return {"schema_version": 1, "production_revision": 42, "boundaries": [
		panel("north", [0, 0, 0], [2000, 0, 0]), panel("south", [0, 0, 2100], [2000, 0, 2100]),
		panel("west", [50, 0, 50], [50, 0, 2050]), panel("east", [1950, 0, 50], [1950, 0, 2050])]}


func panel(id: String, a: Array, b: Array) -> Dictionary:
	return {"wall_id": id, "start_millimetres": a, "end_millimetres": b, "height_millimetres": 2000, "thickness_millimetres": 100}


func open_result(input: Dictionary) -> bool:
	var result: ServiceResult = ConstructedRoomTopology.assess(input)
	return result.is_success and result.value.status == "open_or_unsupported" and result.value.interior_bounds_millimetres.is_empty()


func check(passed: bool, message: String) -> void:
	if passed: return
	failures += 1
	push_error(message)
