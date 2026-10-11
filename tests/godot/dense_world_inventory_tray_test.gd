extends "res://tests/godot/inventory_item_silhouettes_test.gd"

## Eight real items, including four paid builds; no grants, sockets or saves.
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
	for batch in range(10):
		move([-3000, 0, -1000])
		command("extract", {"deposit_id": "deposit.iron", "carrier_id": "resource-canister-1", "amount_milligrams": 1000000})
		move([0, 0, 0])
		command("unload_cargo", {"carrier_id": "resource-canister-1", "material": "ore.iron", "amount_milligrams": 1000000})
		command("process", {"recipe_id": "refine.iron"})
		step(120)
	for kind in ["equipment.canister", "equipment.crowbar", "equipment.extractor", "equipment.canister"]:
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
	for id in ["extractor-1", "backpack-2", "resource-canister-1"]:
		inventory_action("drop", id)
	observed = inventory.world_inventory_observation(context).value
	check(production.capture_snapshot().value["deposits"]["deposit.iron"] == 0, "finite source exhausted")
	check(world.capture_world_snapshot_json().is_success, "complete provenance validates")
	canonical = world.capture_world_snapshot_json().value
	await verify()
	await finish()

func verify() -> void:
	view = ProceduralWorldInventoryPreview.new()
	root.add_child(view)
	view.item_selected.connect(func(container: String, id: String) -> void: selected = container + ":" + id)
	view.pickup_requested.connect(func(container: String, id: String) -> void: pickup = container + ":" + id)
	check(view.observe(observed).is_success, "real dense paid observation")
	check(view._visible_items.size() == 8, "all eight real items exposed without pickup")
	await physics_frame
	await physics_frame
	var boxes: Array[AABB] = []
	var first_mesh: MeshInstance3D
	var obsolete_area: Area3D
	for key in view._visible_items:
		var entry: Dictionary = view._visible_items[key]
		var proxy: MeshInstance3D = entry["mesh"]
		var area: Area3D
		for child in view._rendered.get_children():
			if child is Area3D and child.position == proxy.position: area = child
		check(area != null and area.collision_layer == 4 and area.collision_mask == 0, "aligned original pick layer")
		var size: Vector3 = area.get_child(0).shape.size
		var box := AABB(proxy.position - size / 2, size)
		check(box.grow(0.0001).encloses(proxy.transform * proxy.mesh.get_aabb()), "mesh within pick envelope")
		for detail in proxy.get_children():
			check(box.grow(0.0001).encloses(proxy.transform * detail.transform * detail.mesh.get_aabb()), "silhouette within aligned pick envelope")
		for neighbor in boxes:
			check(not box.grow(0.02).intersects(neighbor), "dense pick envelopes have visible separation")
		boxes.append(box)
		check(absf(proxy.position.x - ProceduralWorldInventoryPreview.DISPLAY_ORIGIN.x) + size.x / 2 <= ProceduralWorldInventoryPreview.TRAY_SIZE.x / 2, "slot stays on tray width")
		check(absf(proxy.position.z - ProceduralWorldInventoryPreview.DISPLAY_ORIGIN.z) + size.z / 2 <= ProceduralWorldInventoryPreview.TRAY_SIZE.z / 2, "slot stays on tray depth")
		for offset in [Vector3.ZERO, Vector3(-size.x * 0.4, 0, 0), Vector3(size.x * 0.4, 0, 0)]:
			var point: Vector3 = proxy.global_position + offset
			var query := PhysicsRayQueryParameters3D.create(point + Vector3(0, 2, 0), point - Vector3(0, 1, 0), 4)
			query.collide_with_areas = true
			query.collide_with_bodies = false
			var hit: Dictionary = view.get_world_3d().direct_space_state.intersect_ray(query)
			check(not hit.is_empty() and hit["collider"] == area, "real center and edge rays pick exact dense item")
		var oblique := PhysicsRayQueryParameters3D.create(proxy.global_position + Vector3(0.1, 1.3, 2.0), proxy.global_position, 4)
		oblique.collide_with_areas = true
		oblique.collide_with_bodies = false
		var oblique_hit: Dictionary = view.get_world_3d().direct_space_state.intersect_ray(oblique)
		check(not oblique_hit.is_empty() and oblique_hit["collider"] == area, "oblique view picks every item through dense neighbors")
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		area.input_event.emit(null, click, proxy.global_position, Vector3.UP, 0)
		check(selected == entry["container_id"] + ":" + entry["item_id"] and pickup.is_empty(), "single click retains command identity")
		check(proxy.material_override.albedo_color == Color("#ffe066"), "selected silhouette highlights")
		if first_mesh != null:
			check(first_mesh.material_override.albedo_color != Color("#ffe066"), "neighbor highlight clears")
		click.double_click = true
		area.input_event.emit(null, click, proxy.global_position, Vector3.UP, 0)
		check(pickup == selected, "double click requests exact item without issuing command")
		pickup = ""
		first_mesh = proxy
		obsolete_area = area
	var rebuilds: int = view._rebuilds
	view.observe(observed.duplicate(true))
	check(view._rebuilds == rebuilds and first_mesh == view._visible_items[view._selected_key]["mesh"], "cache preserves dense anchors and selection")
	view.clear_selection()
	check(view._selected_key.is_empty() and first_mesh.material_override.albedo_color != Color("#ffe066"), "clear restores highlight")
	check(world.capture_world_snapshot_json().value == canonical, "dense layout and all picking preserve full canonical provenance")
	if "--dense-tray-stills" in OS.get_cmdline_user_args():
		await capture_dense_tray()
	inventory_action("pickup", paid_ids[2])
	view.observe(inventory.world_inventory_observation(context).value)
	check(view._visible_items.size() == 7 and not view._visible_items.has(JSON.stringify(["world.tray-1", paid_ids[2]])), "real pickup removes only exact paid item")
	canonical = world.capture_world_snapshot_json().value
	var empty := observed.duplicate(true)
	empty["containers"] = []
	view.observe(empty)
	selected = ""
	var stale_click := InputEventMouseButton.new()
	stale_click.button_index = MOUSE_BUTTON_LEFT
	stale_click.pressed = true
	obsolete_area.input_event.emit(null, stale_click, Vector3.ZERO, Vector3.UP, 0)
	check(selected.is_empty() and view._visible_items.is_empty() and view._selected_key.is_empty(), "stale queued pick cannot select retired item")
	await process_frame
	check(not is_instance_valid(obsolete_area), "old pick geometry freed")
	check(world.capture_world_snapshot_json().value == canonical, "cleanup preserves complete canonical ownership")

func capture_dense_tray() -> void:
	check(DisplayServer.get_name() != "headless", "stills require native renderer")
	if DisplayServer.get_name() == "headless": return
	view.visible = false
	var habitat := ProceduralHabitatPreview.new()
	root.add_child(habitat)
	habitat.character.set_navigation_enabled(false)
	habitat.character.set_physics_process(false)
	habitat.camera.set_process(false)
	habitat.world_inventory.labels_visible = false
	check(habitat.world_inventory.observe(observed).is_success, "actual dense observation in habitat")
	habitat.production.observe(world.production_observation(context).value)
	habitat.production.set_labels_visible(false)
	root.size = Vector2i(1280, 900)
	var center := ProceduralWorldInventoryPreview.DISPLAY_ORIGIN + Vector3(0, 0.8, 0)
	var directory := "res://var/captures/dense-tray/" + RenderingServer.get_current_rendering_method()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	for shot in [{"name": "front", "offset": Vector3(0.1, 1.3, 2.0)}, {"name": "top", "offset": Vector3(0, 2.4, 0.3)}]:
		habitat.camera.position = center + shot["offset"]
		habitat.camera.look_at(center)
		await create_timer(0.4).timeout
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(directory.path_join(shot["name"] + ".png")) == OK, "genuine dense still saved without removing neighbors")
	check(world.capture_world_snapshot_json().value == canonical, "native dense capture preserves canonical snapshot")
	habitat.free()
	view.visible = true

func finish() -> void:
	view.free()
	world.free()
	await process_frame
	print("Dense paid tray: %d failures" % failures)
	quit(1 if failures else 0)
