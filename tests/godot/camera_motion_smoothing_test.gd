extends "res://tests/godot/world_pointer_picking_test.gd"

## Actual integrated camera with recording transport, no sockets.
## Headless cannot expose captured mouse mode: inject only that external-effect gate.
class CameraFixtureControls extends PlayerInputSettings:
	func _ready() -> void:
		_reset_map()
	func can_navigate(owner: Node) -> bool:
		if DisplayServer.get_name() != "headless":
			return super.can_navigate(owner)
		return is_instance_valid(_owner) and _owner == owner and not rebinding and not _suspended and not Input.is_action_pressed("ui_cursor") and not _gui_has_focus(owner)
func run() -> void:
	create_timer(20.0).timeout.connect(func() -> void: check(false, 'Camera fixture deadline'); quit(1))
	OS.set_environment("FRONTIER_EVENT_URL", "")
	OS.set_environment("FRONTIER_EVENT_TOKEN", "")
	var original_controls: PlayerInputSettings = PlayerInputSettings.instance()
	root.remove_child(original_controls)
	var fixture_controls := CameraFixtureControls.new()
	fixture_controls.name = "PlayerControls"
	root.add_child(fixture_controls)
	root.size = Vector2i(1440, 900)
	world = WorldRuntime.new()
	root.add_child(world)
	check(world.start_simulation().is_success, "canonical fixture starts")
	world.get_node("SimulationRunner").set_physics_process(false)
	canonical = world.capture_world_snapshot_json().value
	client = PointerClient.new()
	root.add_child(client)
	client.set_process(false)
	remote = client._remote
	remote.set_process(false)
	viewport = client._habitat.get_viewport()
	var body: LocalHabitatCharacter = client._habitat.character
	body.read_local_keyboard = false
	body.set_physics_process(false)
	body.set_process(false)
	root.gui_release_focus()
	var endpoints: Array[Vector2] = []
	for mode in [LocalHabitatCharacter.CameraMode.FIRST_PERSON, LocalHabitatCharacter.CameraMode.THIRD_PERSON]:
		client._habitat.activate_character(mode)
		body.set_physics_process(false)
		for cadence in [[1.0 / 30.0], [1.0 / 60.0], [0.011, 0.027, 0.019, 0.043]]:
			body.rotation.y = TAU - 0.02
			body._rig.rotation = Vector3.ZERO
			body._pitch = 0.0
			body._view_yaw = body.rotation.y
			var pose: Vector3 = body.position
			var press := InputEventMouseButton.new()
			press.button_index = MOUSE_BUTTON_RIGHT
			press.pressed = true
			body._unhandled_input(press)
			check(PlayerInputSettings.instance().can_navigate(body), "actual camera owns navigation")
			var before: Vector3 = body._camera.global_basis.z
			var turn := InputEventMouseMotion.new()
			turn.relative = Vector2(-40, 25)
			body._input(turn)
			check(body._camera.global_basis.z.is_equal_approx(before), "input preserves displayed direction until frame evaluation")
			check(absf(angle_difference(TAU - 0.02, body.rotation.y) - 0.12) < 0.00001, "body yaw retains immediate movement direction across wrap")
			var previous_error: float = 1.0
			var elapsed: float = 0.0
			var index: int = 0
			while elapsed < 0.5 - 0.000001:
				var delta: float = minf(cadence[index % cadence.size()], 0.5 - elapsed)
				body._process(delta)
				var error: float = absf(angle_difference(body.rotation.y + body._rig.rotation.y, body._view_yaw)) + absf(body._rig.rotation.x - body._pitch)
				check(is_finite(error) and error <= previous_error + 0.000001, "finite monotonic look convergence without overshoot")
				previous_error = error
				elapsed += delta
				index += 1
			endpoints.append(Vector2(body._rig.rotation.y, body._rig.rotation.x))
			check(previous_error < 0.00001 and body.position == pose, "look settles without moving the body")
			var displayed: Vector3 = body._camera.global_basis.z
			body._process(NAN)
			body._process(-1.0)
			turn.relative = Vector2(INF, NAN)
			body._input(turn)
			check(body._camera.global_basis.z.is_equal_approx(displayed), "invalid delta and mouse input cannot poison camera")
			turn.relative = Vector2(40, -25)
			body._input(turn)
			body._process(0.01)
			var released: Transform3D = body._camera.global_transform
			press.pressed = false
			body._input(press)
			body._process(0.1)
			check(body._camera.global_transform.is_equal_approx(released) and not body._looking, "release discards residual look without a camera jump")
			press.pressed = true
			body._unhandled_input(press)
			body._input(turn)
			body._process(0.01)
			released = body._camera.global_transform
			body._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
			body._process(0.1)
			check(body._camera.global_transform.is_equal_approx(released) and not PlayerInputSettings.instance().can_navigate(body), "focus loss freezes view and releases navigation")
		for endpoint in endpoints:
			check(endpoint.distance_to(endpoints[0]) < 0.00001, "30/60/variable delta endpoints agree at equal elapsed time")
		var hold := InputEventMouseButton.new()
		hold.button_index = MOUSE_BUTTON_RIGHT
		hold.pressed = true
		body._unhandled_input(hold)
		var pending_turn := InputEventMouseMotion.new()
		pending_turn.relative = Vector2(50, 10)
		body._input(pending_turn)
		body._process(0.01)
		var frozen: Transform3D = body._camera.global_transform
		PlayerInputSettings.instance().suspend_navigation(true)
		body._process(0.05)
		PlayerInputSettings.instance().suspend_navigation(false)
		body._unhandled_input(hold)
		body._process(0.05)
		check(body._camera.global_transform.is_equal_approx(frozen), "settings suspension discards pending look before recapture")
		body.set_motion_intent(Vector2(0, -1), false)
		var moving_from: Vector3 = body.position
		body._physics_process(1.0 / 60.0)
		check(body.position.is_finite() and body.position.distance_to(moving_from) > 0.01, "actual local movement still advances under smoothed camera")
		body.set_motion_intent(Vector2.ZERO, false)
		body.release_controls()
		# Real scene pick proxy in front of the displayed camera, using existing ray helper.
		await settle()
		var camera: Camera3D = body._camera
		var target := Area3D.new()
		target.collision_layer = 4
		target.position = camera.global_position - camera.global_basis.z * 1.0
		var shape := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = 0.01
		shape.shape = sphere
		target.add_child(shape)
		client._habitat.add_child(target)
		await physics_frame
		await physics_frame
		var center: Vector2 = Vector2(viewport.size) / 2.0
		check(camera.unproject_position(target.global_position).distance_to(center) < 0.1, "visible target stays centered after released turn")
		check(WorldSelectionInput.ray_target(camera, center).get("collider") == target, "selection ray uses displayed camera rather than unsmoothed body intent")
		target.free()
	unchanged("camera frames/modes/release/picking")
	client.free()
	world.free()
	PlayerInputSettings.instance().release_all()
	fixture_controls.free()
	root.add_child(original_controls)
	print("Camera smoothing: %d failures; integrated socket-free client, no graphical acceptance" % failures)
	quit(1 if failures else 0)
