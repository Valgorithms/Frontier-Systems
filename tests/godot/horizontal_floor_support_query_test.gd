extends SceneTree

var failures: int = 0
var request: Dictionary = {"schema_version": 1, "expected_production_revision": 7, "footprint_millimetres": [100, 900, 100, 900], "foot_height_millimetres": 0, "vertical_tolerance_millimetres": 10}


func _initialize() -> void:
	var floor_panel: Dictionary = panel("floor.a", [0, 1000, 0, 1000])
	var surfaces: Array = [floor_panel]
	check(support(surfaces), "interior supported")
	request.footprint_millimetres = [0, 1000, 0, 1000]
	check(support(surfaces), "exact closed boundaries supported")
	request.footprint_millimetres = [1000, 1100, 0, 100]
	check(not support(surfaces), "edge-only contact unsupported")
	request.footprint_millimetres = [950, 1050, 100, 200]
	check(not support(surfaces), "partial overhang unsupported")
	request.footprint_millimetres = [100, 900, 100, 900]
	var adjacent: Array = [panel("floor.a", [0, 500, 0, 1000]), panel("floor.b", [500, 1000, 0, 1000])]
	check(support(adjacent), "adjacent tiles jointly cover footprint")
	var before: Array = adjacent.duplicate(true)
	var request_before: Dictionary = request.duplicate(true)
	var first: ServiceResult = HorizontalFloorSupportQuery.query(request, adjacent, 7)
	adjacent.reverse()
	check(first.value == HorizontalFloorSupportQuery.query(request, adjacent, 7).value, "order deterministic")
	adjacent.reverse()
	check(adjacent == before and request == request_before, "caller inputs unchanged")
	var restored: Array = JSON.parse_string(JSON.stringify(adjacent))
	check(first.value == HorizontalFloorSupportQuery.query(request, restored, 7).value, "restored equivalent descriptors")
	check(not support([panel("floor.a", [0, 450, 0, 1000]), panel("floor.b", [500, 1000, 0, 1000])]), "50mm thin interior gap rejects despite covered corners")
	check(not support([panel("floor.a", [0, 1000, 0, 450]), panel("floor.b", [0, 1000, 500, 1000])]), "Z gap rejects")
	check(not HorizontalFloorSupportQuery.query(request, [floor_panel, panel("floor.b", [500, 1000, 0, 1000])], 7).is_success, "overlap fails closed")
	check(not HorizontalFloorSupportQuery.query(request, [floor_panel, floor_panel], 7).is_success, "duplicate IDs rejected")
	check(not support([]), "absent or removed panels unsupported")
	var ceiling: Dictionary = panel("ceiling.a", [0, 1000, 0, 1000])
	ceiling.kind = "ceiling"
	ceiling.height_millimetres = 2000
	check(not support([ceiling]), "ceiling not floor")
	check(support([ceiling, floor_panel]), "ceiling and floor can share XZ")
	for height in [-1, 11, 2000]:
		request.foot_height_millimetres = height
		check(not support(surfaces), "vertical rejection %s" % height)
	request.foot_height_millimetres = 10
	check(support(surfaces), "tolerance inclusive")
	request.foot_height_millimetres = 0
	for field in request:
		var bad: Dictionary = request.duplicate(true)
		bad[field] = true
		check(not HorizontalFloorSupportQuery.query(bad, surfaces, 7).is_success, "boolean rejected %s" % field)
	for footprint in [[0, 0, 0, 100], [100, 0, 0, 100], [0, 2001, 0, 100], [-100501, 0, 0, 100], [0, 1.5, 0, 100], [0, NAN, 0, 100], [0, INF, 0, 100], [0, 100]]:
		var bad: Dictionary = request.duplicate(true)
		bad.footprint_millimetres = footprint
		check(not HorizontalFloorSupportQuery.query(bad, surfaces, 7).is_success, "bad footprint rejected")
	for tolerance in [-1, 101, 0.5, NAN, INF]:
		var bad: Dictionary = request.duplicate(true)
		bad.vertical_tolerance_millimetres = tolerance
		check(not HorizontalFloorSupportQuery.query(bad, surfaces, 7).is_success, "bad tolerance rejected")
	for revision in [6, 8, -1, true, NAN, INF]:
		check(not HorizontalFloorSupportQuery.query(request, surfaces, revision).is_success, "bad/stale revision rejected")
	for change in [{"kind": "wall"}, {"height_millimetres": 2000}, {"bounds_millimetres": [0, 1050, 0, 1000]}, {"bounds_millimetres": [0, 999, 0, 1000]}, {"bounds_millimetres": [0, NAN, 0, 1000]}, {"extra": true}]:
		var bad: Dictionary = floor_panel.duplicate(true)
		bad.merge(change, true)
		check(not HorizontalFloorSupportQuery.query(request, [bad], 7).is_success, "bad descriptor rejected")
	var many: Array = []
	for i in range(65): many.append(panel("floor.%s" % i, [i * 100, i * 100 + 50, 0, 50]))
	check(not HorizontalFloorSupportQuery.query(request, many, 7).is_success, "panel budget enforced")
	many.pop_back()
	var bounded: ServiceResult = HorizontalFloorSupportQuery.query(request, many, 7)
	check(bounded.is_success and bounded.value.profiling.inspected_surfaces == 64 and bounded.value.profiling.sweep_strips <= 129, "maximum budget valid and bounded")
	var fixture := {"request": request, "supported": first.value, "unsupported": HorizontalFloorSupportQuery.query(request, [], 7).value}
	var file: FileAccess = FileAccess.open("res://var/horizontal-floor-support-fixture.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(fixture))
	file.close()
	print("Horizontal floor support scenarios: %s failures" % failures)
	quit(0 if failures == 0 else 1)


func panel(id: String, bounds: Array) -> Dictionary:
	# Exercise the actual canonical descriptor projection, without inventing stock.
	return HorizontalPanelConstruction.descriptor(id, {"kind": "floor", "bounds_millimetres": bounds, "height_millimetres": 0})


func support(surfaces: Array) -> bool:
	var result: ServiceResult = HorizontalFloorSupportQuery.query(request, surfaces, 7)
	check(result.is_success, "valid query succeeds")
	return result.is_success and result.value.supported


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
