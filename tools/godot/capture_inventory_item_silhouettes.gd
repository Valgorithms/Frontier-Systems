extends "res://tests/godot/inventory_item_silhouettes_test.gd"

## Native stills in actual habitat using the same paid no-port domain fixture.
func finish() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Native renderer required")
		quit(1)
		return
	inventory_action("pickup", "resource-canister-2")
	inventory_action("pickup", paid_ids[0])
	inventory_action("drop", paid_ids[2])
	inventory_action("drop", paid_ids[0])
	observed = inventory.world_inventory_observation(context).value
	view.free()
	var habitat := ProceduralHabitatPreview.new()
	root.add_child(habitat)
	habitat.character.set_navigation_enabled(false)
	habitat.character.set_physics_process(false)
	habitat.camera.set_process(false)
	habitat.world_inventory.labels_visible = false
	check(habitat.world_inventory.observe(observed).is_success, "current paid observation rendered in habitat")
	habitat.production.observe(world.production_observation(context).value)
	habitat.production.set_labels_visible(false)
	canonical = world.capture_world_snapshot_json().value
	root.size = Vector2i(1280, 900)
	var directory := "res://var/captures/item-silhouettes/" + RenderingServer.get_current_rendering_method()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var proxy: MeshInstance3D = habitat.world_inventory._visible_items[JSON.stringify(["world.tray-1", paid_ids[1]])]["mesh"]
	var center: Vector3 = proxy.global_position + Vector3(0.17, 0.06, 0)
	for shot in [{"name": "habitat", "offset": Vector3(0.8, 0.85, 1.3)}, {"name": "tools", "offset": Vector3(0.1, 0.6, 0.65)}, {"name": "top", "offset": Vector3(0.0, 0.95, 0.15)}]:
		habitat.camera.position = center + shot["offset"]
		habitat.camera.look_at(center)
		await create_timer(0.4).timeout
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(directory.path_join(shot["name"] + ".png")) == OK, "native still saved")
	check(world.capture_world_snapshot_json().value == canonical, "native rendering preserves complete canonical snapshot")
	print("Native paid item silhouettes: %d failures" % failures)
	habitat.free()
	world.free()
	await process_frame
	quit(1 if failures else 0)
