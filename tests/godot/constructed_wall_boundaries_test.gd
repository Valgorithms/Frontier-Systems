extends SceneTree

var failures: int = 0


func _initialize() -> void:
	var walls: Dictionary = {"wall-z": {"position": [-2000, 0, 2500], "quarter_turn": 0},
		"wall-a": {"position": [3000, 0, -1000], "quarter_turn": 1}}
	var before: Dictionary = walls.duplicate(true)
	var described: ServiceResult = ConstructedWallBoundaries.describe(walls, 42)
	check(described.is_success, "valid physical panels describe")
	if described.is_success:
		var entries: Array = described.value["boundaries"]
		check(described.value["production_revision"] == 42 and entries.size() == 2, "revision and count retained")
		check(entries[0]["wall_id"] == "wall-a" and entries[1]["wall_id"] == "wall-z", "stable ID order")
		check(entries[0]["start_millimetres"] == [3000, 0, -1500] and entries[0]["end_millimetres"] == [3000, 0, -500], "rotated panel spans Z")
		check(entries[1]["start_millimetres"] == [-2500, 0, 2500] and entries[1]["end_millimetres"] == [-1500, 0, 2500], "unrotated panel spans X")
		check(entries[0]["height_millimetres"] == 2000 and entries[0]["thickness_millimetres"] == 100, "physical dimensions in integer millimetres")
		var reversed: Dictionary = {"wall-a": walls["wall-a"], "wall-z": walls["wall-z"]}
		check(ConstructedWallBoundaries.describe(reversed, 42).value == described.value, "insertion order independent")
		check(ConstructedWallBoundaries.describe(JSON.parse_string(JSON.stringify(walls)), 42).value == described.value, "JSON numeric recovery stable")
		entries[0]["start_millimetres"][0] = 999
		check(walls == before, "returned geometry cannot mutate canonical input")
	check(ConstructedWallBoundaries.describe({}, 0).value["boundaries"].is_empty(), "empty registry grants no boundaries")
	var full: Dictionary = {}
	for index in range(32):
		full["panel-%02d" % index] = {"position": [index * 2000, 0, 0], "quarter_turn": 0}
	check(ConstructedWallBoundaries.describe(full, 0).is_success, "capacity boundary accepted")
	full["extra"] = {"position": [-2000, 0, 0], "quarter_turn": 0}
	check(not ConstructedWallBoundaries.describe(full, 0).is_success, "over capacity rejected")
	for revision in [-1, 1.5, "42", ProductionSimulationSystem.MAX_REVISION + 1]:
		check(not ConstructedWallBoundaries.describe(walls, revision).is_success, "invalid revision rejected")
	for invalid in [null, [], {"wall-a": {"position": [0, 1, 0], "quarter_turn": 0}},
		{"wall-a": {"position": [0, 0, 0], "quarter_turn": 2}},
		{"wall-a": {"position": [0, 0, 0], "quarter_turn": 0}, "wall-b": {"position": [0, 0, 0], "quarter_turn": 1}}]:
		check(not ConstructedWallBoundaries.describe(invalid, 0).is_success, "invalid or overlapping registry rejected")
	print("Constructed wall boundaries: %d failures" % failures)
	quit(1 if failures else 0)


func check(passed: bool, message: String) -> void:
	if passed: return
	failures += 1
	push_error(message)
