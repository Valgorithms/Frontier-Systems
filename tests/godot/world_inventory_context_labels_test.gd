extends "res://tests/godot/dense_world_inventory_tray_test.gd"

## Real paid dense fixture in the actual shell; adapter opens no ports or saves.
class LabelRemote extends RemoteWorldRuntime:
	var sent: Array[SimulationCommand] = []
	func connect_host(_url: String, _invite: String) -> ServiceResult:
		return ServiceResult.success()
	func enqueue_command(request: SimulationCommand) -> ServiceResult:
		sent.append(request)
		return ServiceResult.success()

class LabelClient extends FirstPlayableBootstrap:
	func _create_client_remote() -> RemoteWorldRuntime:
		return LabelRemote.new()

var client: LabelClient
var remote: LabelRemote
var pointer_started: bool = false

func settle() -> void:
	for _frame in range(8): await physics_frame

func deliver() -> void:
	var record: Dictionary = {
		"inventory": inventory.own_inventory_observation(context, true).value,
		"production": world.production_observation(context).value,
		"tools": world.get_simulation_system(ToolSimulationSystem.SYSTEM_ID).observation(context).value,
		"world_items": inventory.world_inventory_observation(context).value,
		"position": [0, 950, 0], "players": [], "terrain": {}
	}
	remote._observation = record.duplicate(true)
	check(remote._projection.accept_record(record["production"]).is_success, "real production projection validates")
	remote.observation_received.emit(record)
	remote.observation_received.emit(record)

func motion(point: Vector2) -> void:
	root.notify_mouse_exited()
	root.notify_mouse_entered()
	pointer_started = true
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	root.push_input(event, true)
	if DisplayServer.get_name() != "headless": Input.warp_mouse(point)
	await settle()

func verify() -> void:
	create_timer(40).timeout.connect(func() -> void: check(false, "context label deadline"); quit(1))
	PlayerInputSettings.instance()._reset_map()
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1440, 900)
	client = LabelClient.new()
	root.add_child(client)
	client.set_process(false)
	remote = client._remote
	remote.set_process(false)
	remote.server_slot = 0
	deliver()
	client._habitat.character.read_local_keyboard = false
	client._habitat.character.set_physics_process(false)
	client._habitat.activate_inspection(HabitatInspectionCamera.Mode.OVERVIEW)
	var camera: Camera3D = client._habitat.camera
	camera.set_process(false)
	view = client._habitat.world_inventory
	var panel: PlayerInventoryPanel = client._inventory_panel
	# Exercise the actual opt-in captions setting; default remains quiet.
	for control in client.find_children("*", "CheckButton", true, false):
		if control.text == "Show world captions": control.button_pressed = true
	view.item_selected.connect(func(container_id: String, id: String) -> void: selected = container_id + ":" + id)
	view.pickup_requested.connect(func(container_id: String, id: String) -> void: pickup = container_id + ":" + id)
	await settle()
	check(view._visible_items.size() == 8, "all eight real paid/fixture items remain exposed")
	for label in view._tray_labels.values(): check(not label.visible, "unfocused tray has no persistent card")
	var entry: Dictionary = view._visible_items[JSON.stringify(["world.tray-1", paid_ids[0]])]
	var area: Area3D = entry["area"]
	var mesh: MeshInstance3D = entry["mesh"]
	camera.position = mesh.global_position + Vector3(0, 0.7, 1.0)
	camera.look_at(mesh.global_position)
	await settle()
	var viewport: SubViewport = view.get_viewport()
	var container: SubViewportContainer = viewport.get_parent()
	var point: Vector2 = camera.unproject_position(mesh.global_position)
	check(WorldSelectionInput.ray_target(camera, point).get("collider") == area, "camera inside habitat sees exact target without through-wall picking")
	var origin: Vector3 = camera.project_ray_origin(point)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + camera.project_ray_normal(point) * 50, 4)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	check(view.get_world_3d().direct_space_state.intersect_ray(query).get("collider") == area, "original collider reached through real camera ray")
	var geometry: Array = []
	for item in view._visible_items.values():
		geometry.append([item["mesh"].get_instance_id(), item["mesh"].transform, item["area"].get_instance_id(), item["area"].transform, item["area"].get_child(0).shape.size])
	var rebuilds: int = view._rebuilds
	await snap("unfocused")
	point = container.global_position + point * container.size / Vector2(viewport.size)
	await motion(point)
	# Headless has no OS pointer position for continuous hover; check the same
	# native signal seam after the real ray assertion. Native stills require it.
	if DisplayServer.get_name() == "headless": area.mouse_entered.emit()
	check(view._hovered_key == JSON.stringify(["world.tray-1", paid_ids[0]]), "Area3D hover retains exact identity (native OS pointer in graphical mode)")
	check(view._selection_label.visible and view._selection_label._lines[0].text == "Canister: " + paid_ids[0], "observed role and exact short identity on hover")
	check(view._selected_key.is_empty() and selected.is_empty() and pickup.is_empty() and remote.sent.is_empty(), "hover selects nothing and queues no intent")
	check(not view._tray_labels["world.tray-1"].visible, "ordinary tray identity does not duplicate the item card or cover neighbors")
	await snap("hover")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = point
	click.global_position = point
	click.pressed = true
	root.push_input(click, true)
	click = click.duplicate()
	click.pressed = false
	root.push_input(click, true)
	await settle()
	check(selected == "world.tray-1:" + paid_ids[0] and pickup.is_empty(), "ordinary click emits exact selection only")
	# World selection has its own identity card; overlay selection is independent.
	for index in range(panel._world_items.item_count):
		if panel._world_items.get_item_metadata(index)["item_id"] == paid_ids[0]:
			panel._world_items.select(index)
	panel._inspect_world()
	var pending_before: Dictionary = panel._pending_world.duplicate(true)
	var details_before: String = panel._world_details.text
	area.mouse_exited.emit()
	check(view._hovered_key.is_empty() and view._selection_label.target == mesh, "selection outlives hover exit")
	var neighbor: Area3D = view._visible_items[JSON.stringify(["world.tray-1", paid_ids[1]])]["area"]
	neighbor.mouse_entered.emit()
	check(view._selection_label.target == mesh and view._selected_key == JSON.stringify(["world.tray-1", paid_ids[0]]), "incidental neighbor hover never retargets selected identity")
	neighbor.mouse_exited.emit()
	check(panel._world_details.text == details_before and panel._pending_world == pending_before, "label transition preserves observed details and pending context")
	check(panel._world_details.text.contains("nested contents") and panel._world_details.text.contains(paid_ids[0]), "overlay preserves exact identity and unobserved contents uncertainty")
	for extent in [Vector2i(640, 720), Vector2i(1440, 900)]:
		root.size = extent
		await settle()
		view._selection_label._process(0)
		check(view._selection_label.visible, "context identity visible in resized real shell")
		check(viewport.get_visible_rect().encloses(Rect2(view._selection_label._card.position, view._selection_label._card.size)), "context identity bounded within real narrow viewport")
		for line in view._selection_label._lines:
			check(view._selection_label._card.get_global_rect().encloses(line.get_global_rect()), "all identity rows bounded by opaque card")
		await snap("selected-%d" % extent.x)
	view.labels_visible = false
	await settle()
	check(not view._selection_label.visible and not view._tray_labels["world.tray-1"].visible, "label setting hides every context without geometry changes")
	view.labels_visible = true
	view.clear_selection()
	check(view._selection_label.target == null and not view._selection_label.visible and not view._tray_labels["world.tray-1"].visible, "explicit reset clears hover and selection context")
	var current_geometry: Array = []
	for item in view._visible_items.values():
		current_geometry.append([item["mesh"].get_instance_id(), item["mesh"].transform, item["area"].get_instance_id(), item["area"].transform, item["area"].get_child(0).shape.size])
	check(geometry == current_geometry and view._rebuilds == rebuilds, "context visibility retains exact mesh/collider instances, transforms and shapes")
	check(world.capture_world_snapshot_json().value == canonical and remote.sent.is_empty(), "all label and native selection operations preserve canonical state")
	# Same command signal remains; real panel keeps pending/outcome uncertainty.
	click.pressed = true
	click.double_click = true
	area.input_event.emit(camera, click, mesh.global_position, Vector3.UP, 0)
	check(pickup == "world.tray-1:" + paid_ids[0] and remote.sent.size() == 1 and remote.sent[0].payload["item_id"] == paid_ids[0], "double click queues exactly the existing pickup with stable IDs")
	# Independently queue the real panel action to check pending recovery copy.
	panel._world_action("pickup")
	var waiting: String = panel._result.text
	view.clear_selection()
	area.mouse_entered.emit()
	check(panel._result.text == waiting and not panel._pending_world.is_empty(), "context changes preserve real pending receipt")
	remote.connection_closed.emit("fixture disconnect")
	await settle()
	area.mouse_entered.emit()
	check(view._selected_key.is_empty() and view._hovered_key.is_empty() and not view._selection_label.visible, "disconnect retires identity; stale native hover cannot restore it")
	check(panel._result.text.to_lower().contains("unknown") and panel._pending_world.is_empty(), "pending disconnect retains outcome uncertainty")
	await snap("disconnect")
	deliver()
	await settle()
	check(view._selected_key.is_empty() and not view._selection_label.visible, "fresh same observation cannot restore old selection")
	area.mouse_entered.emit()
	check(view._selection_label.target == mesh, "fresh observation permits new hover without geometry rebuild")
	# Valid replacement/removal and queued events retire transient hover.
	var updated := observed.duplicate(true)
	updated["containers"][0]["distance_millimetres"] += 1
	view.observe(updated)
	area.mouse_entered.emit()
	check(view._hovered_key.is_empty() and view._selection_label.target == null, "old area hover ignored after valid rebuild")
	updated["containers"] = []
	view.observe(updated)
	check(view._visible_items.is_empty() and view._tray_labels.is_empty() and view._selection_label.target == null, "unavailable valid scope clears context")
	check(InventorySelectionLabel.observed_role("item.unknown") == "Item", "unknown definition never infers capabilities or contents")
	check(world.capture_world_snapshot_json().value == canonical, "pending/disconnect/rebuild operations never mutate canonical owner")

func snap(name: String) -> void:
	if not OS.get_cmdline_user_args().has("--context-label-stills"): return
	check(DisplayServer.get_name() != "headless", "stills require native renderer")
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var directory := "res://var/ci/context-label-stills"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	check(root.get_texture().get_image().save_png(directory.path_join(name + ".png")) == OK, "native real-shell internal still")

func finish() -> void:
	client.free()
	world.free()
	PlayerInputSettings.instance()._reset_map()
	await process_frame
	print("Paid actual-shell context labels: %d failures; no ports, saves or human acceptance" % failures)
	quit(1 if failures else 0)
