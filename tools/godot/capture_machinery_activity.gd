extends "res://tests/godot/machinery_runtime_test.gd"

class CaptureRemote extends RemoteWorldRuntime:
	func connect_host(_url: String, _invite: String) -> ServiceResult:
		return ServiceResult.success()
class CaptureClient extends FirstPlayableBootstrap:
	func _create_client_remote() -> RemoteWorldRuntime:
		return CaptureRemote.new()

var client: CaptureClient
var extractor: String
var directory: String = "res://var/captures/machinery-activity"


## Paid domain commands, actual client shell, genuine native stills, no sockets.
func finish() -> void:
	if DisplayServer.get_name() == "headless" or failures:
		push_error("Successful paid fixture and graphical renderer required")
		quit(1)
		return
	create_timer(45.0).timeout.connect(func() -> void: push_error("Native activity capture deadline"); quit(1))
	for module in production.capture_snapshot().value["machinery"]["mounts"]:
		if production.capture_snapshot().value["machinery"]["parts"][module]["kind"] == "extractor": extractor = production.capture_snapshot().value["machinery"]["mounts"][module]
	move([-6000, 0, -1000])
	command("machine_run", {"machine_id": extractor, "recipe": "extract.ice"})
	client = CaptureClient.new()
	root.add_child(client)
	client.set_process(false)
	client.set_process_unhandled_input(false)
	client._machinery_preview.set_process(false)
	_publish(production.observation(context).value)
	step(8)
	_publish(production.observation(context).value)
	check(client._machinery_preview._activity.state(extractor) == "running", "paid advancing observation drives actual shell")
	var habitat := client._habitat
	habitat.character.read_local_keyboard = false
	habitat.character.set_physics_process(false)
	habitat.activate_inspection(HabitatInspectionCamera.Mode.OVERVIEW)
	habitat.camera.set_process(false)
	var center: Vector3 = client._machinery_preview._activity_parts[extractor]["root"].global_position
	habitat.camera.position = center + Vector3(1.7, 1.7, -2.5)
	habitat.camera.look_at(center + Vector3(0, 0.4, 0))
	for id in client._machinery_preview._labels:
		client._machinery_preview._labels[id]["label"].visible = id == extractor
	root.size = Vector2i(1280, 900)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var snapshot: String = world.capture_world_snapshot_json().value
	client._machinery_preview._process(0.05)
	var drive: Node3D = client._machinery_preview._activity_parts[extractor]["rotors"][0]
	var first_pose: Transform3D = drive.transform
	await capture("running-a")
	client._machinery_preview._process(0.1)
	check(drive.transform != first_pose, "two real rendered phases differ")
	await capture("running-b")
	check(world.capture_world_snapshot_json().value == snapshot, "native render/motion leave canonical snapshot unchanged")
	var paused_world := WorldRuntime.new()
	paused_world.resource_carriers_enabled = true
	root.add_child(paused_world)
	check(paused_world.restore_world_snapshot_json(snapshot).is_success, "real checkpoint restart creates paused job")
	var paused_production: ProductionSimulationSystem = paused_world.get_simulation_system(ProductionSimulationSystem.SYSTEM_ID)
	_publish(paused_production.observation(context).value)
	check(client._machinery_preview._activity.state(extractor) == "paused", "restored pause visible in shell")
	var held: Transform3D = drive.transform
	client._machinery_preview._process(0.1)
	await capture("paused")
	check(drive.transform == held, "paused native drive frozen")
	paused_world.free()
	client._machinery_preview._process(1.0)
	await capture("unknown")
	check(drive.transform == held and client._machinery_preview._labels[extractor]["label"].text.contains("Motion unknown"), "expired visual evidence stays frozen and visibly unknown")
	await capture_refinery()
	client._remote.connection_closed.emit("Capture disconnect")
	check(client._machinery_preview._activity_parts.is_empty(), "shell disconnect clears activity geometry")
	await capture("disconnected")
	client.free()
	world.free()
	print("Native machinery activity: %d failures" % failures)
	quit(1 if failures else 0)


func capture_refinery() -> void:
	var workshop: Dictionary = production.capture_snapshot().value["machinery"]
	var refinery: String = ""
	var generator: String = ""
	var extraction_socket: String = ""
	var sockets: Array[String] = []
	for module in workshop["mounts"]:
		var kind: String = workshop["parts"][module]["kind"]
		if kind == "refinery": refinery = workshop["mounts"][module]
		if kind == "solar": generator = workshop["mounts"][module]
		if kind == "socket" and workshop["mounts"][module] == extractor: extraction_socket = module
	for module in workshop["mounts"]:
		if workshop["parts"][module]["kind"] == "socket" and workshop["mounts"][module] == refinery: sockets.append(module)
	command("machine_cancel", {"machine_id": extractor})
	command("machine_remove", {"machine_id": extractor, "item_id": "resource-canister-1", "socket_id": extraction_socket})
	move([0, 0, 0])
	var cable: String = craft("cable")
	move([-300, 0, -1100])
	command("machine_insert", {"machine_id": refinery, "item_id": "resource-canister-1", "socket_id": sockets[0]})
	command("machine_insert", {"machine_id": refinery, "item_id": "resource-canister-2", "socket_id": sockets[1]})
	move([-2050, 0, -2150])
	command("machine_wire", {"machine_id": generator, "other_id": refinery, "item_id": cable})
	step(120)
	command("machine_run", {"machine_id": refinery, "recipe": "refine.ice"})
	_publish(production.observation(context).value)
	step(8)
	_publish(production.observation(context).value)
	check(client._machinery_preview._activity.state(refinery) == "running", "paid finite refining earns pump motion")
	var center: Vector3 = client._machinery_preview._activity_parts[refinery]["root"].global_position
	client._habitat.camera.position = center + Vector3(1.8, 1.7, 2.5)
	client._habitat.camera.look_at(center + Vector3(0, 0.4, 0))
	for id in client._machinery_preview._labels:
		client._machinery_preview._labels[id]["label"].visible = id == refinery
	var snapshot: String = world.capture_world_snapshot_json().value
	client._machinery_preview._process(0.05)
	await capture("refinery-running")
	check(world.capture_world_snapshot_json().value == snapshot, "refinery cosmetic motion preserves canonical snapshot")


func _publish(observed: Dictionary) -> void:
	var record := {"inventory": inventory.own_inventory_observation(context, true).value, "production": observed, "tools": world.get_simulation_system(ToolSimulationSystem.SYSTEM_ID).observation(context).value, "world_items": inventory.world_inventory_observation(context).value, "terrain": {}, "position": [0, 950, 0], "players": []}
	check(client._remote._projection.accept_record(observed).is_success, "scoped production accepted by real projection")
	client._remote._observation = record.duplicate(true)
	client._remote.observation_received.emit(record)


func capture(label: String) -> void:
	# Let the real embedded viewport finish its resize/camera setup before readback.
	await create_timer(0.2).timeout
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(directory.path_join(label + ".png")) == OK, "unedited native still " + label)
