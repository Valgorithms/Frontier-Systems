extends SceneTree

var failures: int = 0


func _initialize() -> void:
	var input: Dictionary = layout()
	var before: Dictionary = input.duplicate(true)
	var result: ServiceResult = ConstructedDoorOpeningTopology.assess(input)
	check(result.is_success and result.value.status == "enclosure_with_unsealed_openings", "separate aperture completes rectangular band")
	check(result.is_success and result.value.interior_bounds_millimetres == [5100, 5900, -4500, -3500] and result.value.door_ids == ["door-own"], "stable own aperture identity and interior")
	check(input == before and not result.value.has("sealed") and not result.value.has("room_id") and not result.value.has("flow_area"), "detached diagnostic without authority")
	check(ConstructedRoomClosure.assess({"schema_version": 1, "production_revision": 7, "walls": input.walls, "surfaces": input.surfaces}).value.status == "open_or_unsupported", "old closure keeps doorway open")
	var changed: Dictionary = layout()
	changed.walls.boundaries.reverse()
	changed.surfaces.reverse()
	check(ConstructedDoorOpeningTopology.assess(changed).value == result.value, "deterministic order")
	check(ConstructedDoorOpeningTopology.assess(JSON.parse_string(JSON.stringify(input))).value == result.value, "integral JSON values decode")
	result.value.door_ids.clear()
	check(ConstructedDoorOpeningTopology.assess(input).value.door_ids == ["door-own"], "no cached mutable result")
	changed = layout()
	for wall in changed.walls.boundaries:
		for point in [wall.start_millimetres, wall.end_millimetres]:
			var x: int = point[0]
			point[0] = point[2] - 2000
			point[2] = x - 10000
	for surface in changed.surfaces:
		var b: Array = surface.bounds_millimetres
		surface.bounds_millimetres = [b[2] - 2000, b[3] - 2000, b[0] - 10000, b[1] - 10000]
	changed.openings[0] = {"door_id": "door-own", "position": [-6000, 0, -4050], "quarter_turn": 0}
	check(ConstructedDoorOpeningTopology.assess(changed).value.status == "enclosure_with_unsealed_openings", "transposed translated aperture")
	for mutation in ["no-door", "no-floor", "no-ceiling", "missing-wall", "offset", "gap", "unrelated-door"]:
		changed = layout()
		match mutation:
			"no-door": changed.openings.clear()
			"no-floor": changed.surfaces.remove_at(0)
			"no-ceiling": changed.surfaces.remove_at(1)
			"missing-wall": changed.walls.boundaries.remove_at(0)
			"offset": changed.openings[0].position[0] += 50
			"gap": changed.surfaces[0].bounds_millimetres[1] = 5850
			"unrelated-door": changed.openings[0].position[2] += 3000
		var assessed: ServiceResult = ConstructedDoorOpeningTopology.assess(changed)
		check(not assessed.is_success or assessed.value.status == "open_or_unsupported", mutation + " cannot complete enclosure")
	var invalids: Array = [null, [], {}, true]
	for field in ["schema_version", "production_revision", "walls", "surfaces", "openings"]:
		changed = layout(); changed.erase(field); invalids.append(changed)
	for value in [true, "7", 7.1, -1, INF, NAN]:
		changed = layout(); changed.production_revision = value; invalids.append(changed)
	changed = layout(); changed.production_revision = 8; invalids.append(changed)
	changed = layout(); changed.openings.append(changed.openings[0].duplicate(true)); invalids.append(changed)
	changed = layout(); changed.openings[0].door_id = "shared-a"; invalids.append(changed)
	for value in [true, 0.5, 2, -1, "1"]:
		changed = layout(); changed.openings[0].quarter_turn = value; invalids.append(changed)
	for position in [[5950, 50, -4000], [5951, 0, -4000], [INF, 0, 0], [0, 0], [100050, 0, 0]]:
		changed = layout(); changed.openings[0].position = position; invalids.append(changed)
	changed = layout(); changed.openings[0].sealed = true; invalids.append(changed)
	changed = layout(); changed.openings[0].position = [5050, 0, -4000]; invalids.append(changed)
	changed = layout(); changed.surfaces.append(changed.surfaces[0].duplicate(true)); invalids.append(changed)
	changed = layout(); changed.openings.resize(17); invalids.append(changed)
	for bad in invalids: check(not ConstructedDoorOpeningTopology.assess(bad).is_success, "malformed/overlapping/duplicate/stale descriptor rejects")
	print("Constructed doorway topology: %d failures" % failures)
	quit(1 if failures else 0)


func layout() -> Dictionary:
	return {"schema_version": 1, "production_revision": 7, "walls": {"schema_version": 1, "production_revision": 7, "boundaries": [
		{"wall_id": "shared-a", "start_millimetres": [5000, 0, -4550], "end_millimetres": [6000, 0, -4550], "height_millimetres": 2000, "thickness_millimetres": 100},
		{"wall_id": "shared-b", "start_millimetres": [5000, 0, -3450], "end_millimetres": [6000, 0, -3450], "height_millimetres": 2000, "thickness_millimetres": 100},
		{"wall_id": "shared-c", "start_millimetres": [5050, 0, -4500], "end_millimetres": [5050, 0, -3500], "height_millimetres": 2000, "thickness_millimetres": 100}]},
		"surfaces": [{"surface_id": "floor-own", "kind": "floor", "bounds_millimetres": [5000, 6000, -4500, -3500], "height_millimetres": 0}, {"surface_id": "ceiling-own", "kind": "ceiling", "bounds_millimetres": [5100, 5900, -4500, -3500], "height_millimetres": 2000}],
		"openings": [{"door_id": "door-own", "position": [5950, 0, -4000], "quarter_turn": 1}]}


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
