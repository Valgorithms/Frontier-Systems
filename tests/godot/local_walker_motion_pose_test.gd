extends "res://tests/godot/local_walker_visual_test.gd"

## Actual no-port shell and collision solver; deterministic ticks, no input transport.
func run() -> void:
	create_timer(25.0).timeout.connect(func() -> void: check(false, "Walker pose fixture deadline"); quit(1))
	OS.set_environment("FRONTIER_EVENT_URL", "")
	OS.set_environment("FRONTIER_EVENT_TOKEN", "")
	world = WorldRuntime.new()
	root.add_child(world)
	check(world.start_simulation().is_success, "real world starts")
	world.get_node("SimulationRunner").set_physics_process(false)
	context = AuthenticatedCommandContext.for_local_development(&"local-inventory-target", world.world_id, world.region_id)
	client = InventoryClient.new()
	root.add_child(client)
	client.set_process(false)
	remote = client._remote
	remote.set_process(false)
	remote.server_slot = 0
	observe_shell()
	var body: LocalHabitatCharacter = client._habitat.character
	var visual: LocalWalkerVisual = body._mesh
	var canonical: String = world.capture_world_snapshot_json().value
	var sent: int = remote.sent.size()
	body.position = Vector3(-4, 0.95, 0)
	body.rotation.y = -PI / 2.0
	body.set_navigation_enabled(true)
	body.set_physics_process(false)
	body.set_camera_mode(LocalHabitatCharacter.CameraMode.THIRD_PERSON)
	var camera_rig: Transform3D = body._rig.transform
	var camera_arm: Transform3D = body._arm.transform
	await ticks(body, 30)
	check(body.is_on_floor() and neutral(visual), "stationary grounded shell is neutral")
	body.set_motion_intent(Vector2(0, -1), false)
	var start: Vector3 = body.position
	await ticks(body, 8)
	check(body.position.x > start.x + 0.1 and not neutral(visual), "actual resolved horizontal travel swings limbs")
	var measured_phase: float = visual._phase
	var measured_start: Vector3 = body.global_position
	await ticks(body, 1)
	var measured_travel: Vector3 = body.global_position - measured_start
	measured_travel.y = 0.0
	check(is_equal_approx(visual._phase, fposmod(measured_phase + measured_travel.length() * TAU / LocalWalkerVisual.STRIDE_LENGTH, TAU)), "phase advances only by measured resolved distance")
	check(visual.transform == Transform3D.IDENTITY, "pose does not translate or rotate visual root")
	for limb: MeshInstance3D in visual._limbs:
		check(limb.transform.origin.is_finite() and limb.rotation.length() <= LocalWalkerVisual.MAX_SWING + 0.0001, "finite modest limb swing")
	check(not visual._limbs[0].transform.basis.is_equal_approx(visual._limbs[2].transform.basis), "arms and legs counter-swing")
	await ticks(body, 85)
	check(body.position.x < -1.1 and neutral(visual), "closed real barrier stops travel and returns neutral despite held intent")
	body.set_motion_intent(Vector2.ZERO, true)
	var standing: float = body.position.y
	await ticks(body, 5)
	check(body.position.y > standing + 0.05 and neutral(visual), "vertical jump stays neutral")
	body.set_motion_intent(Vector2(1, 0), false)
	await ticks(body, 2)
	check(not body.is_on_floor() and neutral(visual), "airborne horizontal travel stays neutral")
	body.set_motion_intent(Vector2.ZERO, false)
	await ticks(body, 100)
	check(body.is_on_floor() and neutral(visual), "landing without horizontal travel stays neutral")
	body.position = Vector3(-4, 0.95, 0)
	await ticks(body, 30)
	body.set_motion_intent(Vector2(0, -1), false)
	await ticks(body, 8)
	check(not neutral(visual), "walk resumes before corrections")
	body.position.x += 0.00001
	await ticks(body, 1)
	check(neutral(visual), "small external correction rebases neutral while input remains held")
	await ticks(body, 8)
	check(not neutral(visual), "resolved travel resumes after correction")
	body.position = Vector3(-4, 0.90, 0)
	await ticks(body, 1)
	check(neutral(visual), "teleport rebases neutral without animating its distance")
	await ticks(body, 8)
	check(not neutral(visual), "walk resumes after teleport")
	body.set_motion_intent(Vector2.ZERO, false)
	await ticks(body, 1)
	check(neutral(visual), "stopping actual travel immediately restores neutral")
	body.set_motion_intent(Vector2(0, -1), false)
	await ticks(body, 8)
	check(not neutral(visual), "walk resumes before first-person hiding")
	body.set_camera_mode(LocalHabitatCharacter.CameraMode.FIRST_PERSON)
	body.set_motion_intent(Vector2(0, -1), false)
	await ticks(body, 8)
	check(not neutral(visual) and not visual.is_visible_in_tree(), "walking geometry stays hidden in first person")
	body.set_navigation_enabled(false)
	check(neutral(visual) and not body.is_physics_processing(), "disabled navigation immediately neutralizes pose")
	var disabled_position: Vector3 = body.position
	body._physics_process(1.0 / 60.0)
	check(body.position == disabled_position and neutral(visual), "disabled tick has no travel or pose")
	body.set_camera_mode(LocalHabitatCharacter.CameraMode.FIRST_PERSON)
	check(not visual.is_visible_in_tree() and body._arm.spring_length == 0.0, "first person hides animated subtree")
	for child: Node3D in visual.get_children():
		check(not child.is_visible_in_tree(), "first-person geometry hidden")
	body.set_camera_mode(LocalHabitatCharacter.CameraMode.THIRD_PERSON)
	check(visual.is_visible_in_tree() and body._arm.spring_length == 3.0, "third person retains original arm")
	check(body._rig.transform == camera_rig and body._arm.transform == camera_arm, "pose leaves camera rig and arm transform unchanged")
	check(visual.find_children("*", "CollisionObject3D", true, false).is_empty(), "pose geometry has no collision objects")
	check(world.capture_world_snapshot_json().value == canonical and remote.sent.size() == sent, "all poses preserve canonical snapshot and transport queue")
	# Exercise the real rejected-movement correction with the existing injected adapter.
	body.set_navigation_enabled(true)
	body.set_physics_process(false)
	body.position = Vector3(-4, 0.90, 0)
	await ticks(body, 30)
	body.set_motion_intent(Vector2(0, -1), false)
	await ticks(body, 8)
	client._process(0.15)
	var request: SimulationCommand = client._movement_request
	check(request != null and not neutral(visual), "real movement request begins while walking")
	remote.command_completed.emit(request, ServiceResult.failure(&"movement_rejected", "Fixture correction"))
	await ticks(body, 1)
	check(neutral(visual), "real host rejection correction resets walking pose")
	check(world.capture_world_snapshot_json().value == canonical and remote.sent.size() == sent + 1, "pose adds no transport beyond explicit sampler request")
	visual.observe_motion(body.global_position, body.global_position, NAN, true)
	check(neutral(visual), "invalid visual sample remains neutral")
	client.free()
	world.free()
	if failures == 0: print("Local walker motion pose actual-shell scenarios passed; no sockets or graphical acceptance.")
	quit(0 if failures == 0 else 1)


func ticks(body: LocalHabitatCharacter, count: int) -> void:
	for _frame in range(count):
		await physics_frame
		body._physics_process(1.0 / Engine.physics_ticks_per_second)


func neutral(visual: LocalWalkerVisual) -> bool:
	for index in range(visual._limbs.size()):
		if not visual._limbs[index].transform.is_equal_approx(visual._neutral[index]): return false
	return is_zero_approx(visual._phase)
