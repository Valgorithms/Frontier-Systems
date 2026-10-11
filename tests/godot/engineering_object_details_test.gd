extends "res://tests/godot/machinery_runtime_test.gd"

## Real finite-resource assembly and construction; no host, ports or saves.
var extractor_id: String
var refinery_id: String
var observed: Dictionary

func run() -> void:
	OS.set_environment("FRONTIER_EVENT_URL", "")
	OS.set_environment("FRONTIER_EVENT_TOKEN", "")
	world = WorldRuntime.new()
	world.resource_carriers_enabled = true
	root.add_child(world)
	world.command_completed.connect(func(_command: SimulationCommand, result: ServiceResult) -> void: last = result)
	check(world.start_simulation().is_success, "world starts")
	runner = world.get_node("SimulationRunner")
	runner.set_physics_process(false)
	production = world.get_simulation_system(ProductionSimulationSystem.SYSTEM_ID)
	inventory = world.get_simulation_system(InventorySimulationSystem.SYSTEM_ID)
	context = AuthenticatedCommandContext.for_local_development(&"local-inventory-actor", world.world_id, world.region_id)
	for batch in range(9):
		move([-3000, 0, -1000])
		command("extract", {"deposit_id": "deposit.iron", "carrier_id": "resource-canister-1", "amount_milligrams": 1000000})
		move([0, 0, 0])
		command("unload_cargo", {"carrier_id": "resource-canister-1", "material": "ore.iron", "amount_milligrams": 1000000})
		command("process", {"recipe_id": "refine.iron"})
		step(120)
	extractor_id = assemble("extractor", [900, 0, -1000])
	refinery_id = assemble("refinery", [-1100, 0, -1000])
	command("process", {"recipe_id": "craft.plate"})
	step(120)
	command("materialize_plate", {})
	move([-300, 0, -1100])
	command("wall_build", {"item_id": production.observation(context).value["components"][0], "position": [0, 0, -2300], "quarter_turn": 0})
	observed = production.observation(context).value
	finish()

func verify_details(node: Node3D, bounds: AABB) -> void:
	check(node.find_children("*", "CollisionObject3D", true, false).is_empty(), "details introduce no pick or collision bodies")
	check(node.find_children("*", "CollisionShape3D", true, false).is_empty(), "details introduce no shapes")
	for child in node.get_children():
		if not child is MeshInstance3D: continue
		var visual: MeshInstance3D = child
		var extent: AABB = visual.transform * visual.mesh.get_aabb()
		check(bounds.grow(0.0001).encloses(extent), "detail stays in original physical envelope")

func finish() -> void:
	var canonical: String = world.capture_world_snapshot_json().value
	var preview := MachineryPreview.new()
	root.add_child(preview)
	preview.observe(observed)
	check(preview.find_children("*", "StaticBody3D", true, false).size() == 2, "one settled body per real frame")
	for id in [extractor_id, refinery_id]:
		var body: Node3D = preview._labels[id]["label"].get_parent()
		var details: Node3D = body.get_node("ExtractorDetails" if id == extractor_id else "RefineryDetails")
		verify_details(details, AABB(Vector3(-0.4, -0.4, -0.4), Vector3(0.8, 1.35, 0.8)))
		var collision: CollisionShape3D
		for child in body.get_children():
			if child is CollisionShape3D: collision = child
		check(collision.shape.size == Vector3(0.8, 1.35, 0.8) and is_equal_approx(collision.position.y, 0.275), "original machine collision envelope retained")
	var production_view := ProceduralProductionPreview.new()
	root.add_child(production_view)
	production_view.observe(observed)
	var wall_id: String = observed["walls"].keys()[0]
	var wall: StaticBody3D = production_view._spatial_walls[wall_id]
	verify_details(wall.get_node("WallDetails"), AABB(-SpatialWallConstruction.SIZE / 2, SpatialWallConstruction.SIZE))
	check(wall.get_child(1).get_class() == "Node3D", "decoration follows panel")
	var collision: CollisionShape3D
	for child in wall.get_children():
		if child is CollisionShape3D: collision = child
	check(collision.shape.size == SpatialWallConstruction.SIZE, "original wall collision retained")
	var wall_instance: int = wall.get_instance_id()
	production_view.observe(observed)
	check(production_view._spatial_walls[wall_id].get_instance_id() == wall_instance, "unchanged wall observation retains geometry")
	var turned := observed.duplicate(true)
	turned["walls"] = {"turned": {"position": [0, 0, -2300], "quarter_turn": 1}}
	production_view.observe(turned)
	check(is_equal_approx(production_view._spatial_walls["turned"].rotation.y, PI / 2), "whole framed wall rotates with observed pose")
	production_view.observe({})
	preview.observe({})
	check(production_view._spatial_walls.is_empty() and preview._labels.is_empty(), "unavailable observations retire details and selection")
	check(world.capture_world_snapshot_json().value == canonical, "presentation lifecycle preserves full canonical snapshot")
	production_view.free()
	preview.free()
	world.free()
	print("Engineering object details: %d failures" % failures)
	quit(1 if failures else 0)
