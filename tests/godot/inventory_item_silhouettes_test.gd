extends "res://tests/godot/machinery_runtime_test.gd"

## Finite extraction/refining and paid construction, real physics, no sockets/saves.
var paid_ids: Array[String] = []
var view: ProceduralWorldInventoryPreview
var observed: Dictionary
var canonical: String
var selected: String = ""
var pickup: String = ""

func run() -> void:
	OS.set_environment("FRONTIER_EVENT_URL", "")
	OS.set_environment("FRONTIER_EVENT_TOKEN", "")
	world = WorldRuntime.new()
	world.resource_carriers_enabled = true
	root.add_child(world)
	world.command_completed.connect(func(_request: SimulationCommand, result: ServiceResult) -> void: last = result)
	check(world.start_simulation().is_success, "real world starts")
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
	for kind in ["equipment.canister", "equipment.crowbar", "equipment.extractor"]:
		var before: Dictionary = production.capture_snapshot().value
		command("machine_craft", {"kind": kind})
		var id: String = ""
		for candidate in production.capture_snapshot().value["structures"]:
			if not before["structures"].has(candidate): id = candidate
		check(not id.is_empty(), "paid physical " + kind)
		paid_ids.append(id)
		var bill: int = production.machine_blueprint(kind).value["materials"]["iron"]
		check(production.capture_snapshot().value["store"]["iron"] == before["store"]["iron"] - bill, "exact paid material bill")
		inventory_action("drop", id)
	observed = inventory.world_inventory_observation(context).value
	check(production.capture_snapshot().value["deposits"]["deposit.iron"] == 1000000, "finite source consumed")
	check(world.capture_world_snapshot_json().is_success, "complete provenance validates")
	canonical = world.capture_world_snapshot_json().value
	await verify()
	await finish()

func inventory_action(operation: String, id: String) -> void:
	sequence += 1
	var request := InventoryDevelopmentCommand.new()
	request.command_id = StringName("silhouette-%d" % sequence)
	request.authenticated_context = context
	request.operation = "world"
	request.payload = {"operation": operation, "item_id": id, "world_container_id": "world.tray-1", "destination_container_id": "body.human-2" if operation == "pickup" else "", "slot_id": "", "expected_revision": inventory.capture_snapshot().value["owner"]["state_revision"]}
	check(world.enqueue_command(request).is_success, "inventory action queues")
	step()
	check(last.is_success, "%s: %s" % [operation, last.message])

func verify() -> void:
	view = ProceduralWorldInventoryPreview.new()
	root.add_child(view)
	view.item_selected.connect(func(container: String, id: String) -> void: selected = container + ":" + id)
	view.pickup_requested.connect(func(container: String, id: String) -> void: pickup = container + ":" + id)
	check(view.observe(observed).is_success, "actual paid world observation")
	await physics_frame
	await physics_frame
	var dimensions: Array[Vector3] = [Vector3(0.16, 0.3, 0.16), Vector3(0.4, 0.04, 0.04), Vector3(0.32, 0.16, 0.12)]
	for index in range(paid_ids.size()):
		var id: String = paid_ids[index]
		var entry: Dictionary = view._visible_items[JSON.stringify(["world.tray-1", id])]
		var proxy: MeshInstance3D = entry["mesh"]
		check(proxy.get_child_count() == 3, "role silhouette has bounded three parts")
		var envelope := AABB(-dimensions[index].max(Vector3(0.12, 0.12, 0.12)) / 2, dimensions[index].max(Vector3(0.12, 0.12, 0.12)))
		check(envelope.grow(0.0001).encloses(proxy.mesh.get_aabb()), "proxy remains within original pick envelope")
		for child in proxy.get_children():
			check(child is MeshInstance3D and child.material_override == proxy.material_override, "mesh-only details share highlight")
			check(envelope.grow(0.0001).encloses(child.transform * child.mesh.get_aabb()), "detail stays inside original envelope: %s %s" % [id, child.transform * child.mesh.get_aabb()])
		var area: Area3D
		for child in view._rendered.get_children():
			if child is Area3D and child.position == proxy.position: area = child
		check(area != null and area.collision_layer == 4 and area.collision_mask == 0, "original picking layer retained")
		check(area.get_child(0).shape.size == envelope.size, "original picking dimensions retained")
		var point: Vector3 = proxy.global_position + Vector3(-0.04 if index == 1 else 0.04, 0, 0)
		var query := PhysicsRayQueryParameters3D.create(point + Vector3(0, 1, 0), point - Vector3(0, 1, 0), 4)
		query.collide_with_areas = true
		query.collide_with_bodies = false
		var hit: Dictionary = view.get_world_3d().direct_space_state.intersect_ray(query)
		check(not hit.is_empty() and hit["collider"] == area, "real physics ray reaches original item area")
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		area.input_event.emit(null, click, point, Vector3.UP, 0)
		check(selected == "world.tray-1:" + id and pickup.is_empty(), "single click emits stable identity only")
		check(proxy.material_override.albedo_color == Color("#ffe066"), "whole silhouette highlights")
		click.double_click = true
		area.input_event.emit(null, click, point, Vector3.UP, 0)
		check(pickup == "world.tray-1:" + id, "double click requests exact existing item")
		pickup = ""
	var rebuilds: int = view._rebuilds
	view.observe(observed.duplicate(true))
	check(view._rebuilds == rebuilds, "unchanged observation retains geometry")
	check(world.capture_world_snapshot_json().value == canonical, "all presentation and pick operations preserve complete canonical snapshot")
	inventory_action("pickup", paid_ids[2])
	view.observe(inventory.world_inventory_observation(context).value)
	check(not view._visible_items.has(JSON.stringify(["world.tray-1", paid_ids[2]])), "real pickup retires silhouette")
	canonical = world.capture_world_snapshot_json().value
	var empty := observed.duplicate(true)
	empty["containers"] = []
	view.observe(empty)
	check(view._visible_items.is_empty() and view._selected_key.is_empty(), "unavailable observation retires details and selection")
	check(world.capture_world_snapshot_json().value == canonical, "cleanup preserves canonical ownership and provenance")

func finish() -> void:
	view.free()
	world.free()
	await process_frame
	print("Paid item silhouettes: %d failures" % failures)
	quit(1 if failures else 0)
