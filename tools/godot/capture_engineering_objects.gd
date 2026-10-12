extends "res://tests/godot/engineering_object_details_test.gd"

class CaptureRemote extends RemoteWorldRuntime:
	func connect_host(_url: String, _invite: String) -> ServiceResult:
		return ServiceResult.success()
class CaptureClient extends FirstPlayableBootstrap:
	func _create_client_remote() -> RemoteWorldRuntime:
		return CaptureRemote.new()

## Actual client shell and habitat; paid domain input, native render, no sockets.
func finish() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Graphical renderer required")
		quit(1)
		return
	var client := CaptureClient.new()
	root.add_child(client)
	client.set_process(false)
	client.set_process_unhandled_input(false)
	var record := {"inventory": inventory.own_inventory_observation(context, true).value, "production": observed, "tools": world.get_simulation_system(ToolSimulationSystem.SYSTEM_ID).observation(context).value, "world_items": inventory.world_inventory_observation(context).value, "terrain": {}, "position": [0, 950, 0], "players": []}
	check(client._remote._projection.accept_record(observed).is_success, "real observed projection accepted")
	client._remote._observation = record.duplicate(true)
	client._remote.observation_received.emit(record)
	check(client._remote._projection.accept_record(observed).is_success, "real observed projection accepted")
	client._remote._observation = record.duplicate(true)
	client._remote.observation_received.emit(record)
	var habitat := client._habitat
	habitat.character.read_local_keyboard = false
	habitat.character.set_physics_process(false)
	habitat.activate_inspection(HabitatInspectionCamera.Mode.OVERVIEW)
	habitat.camera.set_process(false)
	for label in client._machinery_preview._labels.values(): label["label"].visible = false
	habitat.production.set_labels_visible(false)
	root.size = Vector2i(1280, 900)
	var directory := "res://var/captures/engineering-objects/" + OS.get_environment("FRONTIER_CAPTURE_STAGE")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var wall: Node3D = habitat.production._spatial_walls.values()[0]
	var wall_center: Vector3 = wall.global_position
	for view in [{"name": "context", "eye": Vector3(-4, 4, -4), "target": Vector3(-6, 0.8, 0.5)}, {"name": "rear", "eye": Vector3(-8, 3.5, 4), "target": Vector3(-6, 0.8, 0.5)}, {"name": "wall", "eye": wall_center + Vector3(2, 1.5, 3), "target": wall_center}]:
		habitat.camera.position = view["eye"]
		habitat.camera.look_at(view["target"])
		await create_timer(0.4).timeout
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(directory.path_join(view["name"] + ".png")) == OK, "native capture")
	print("Native engineering capture: %d failures" % failures)
	client.free()
	world.free()
	quit(1 if failures else 0)
