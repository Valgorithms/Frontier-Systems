extends "res://tests/godot/client_inventory_shell_test.gd"

## Real shell, physics and existing injected transport. No sockets or new authority.
func run() -> void:
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
	var canonical: String = world.capture_world_snapshot_json().value
	var sent: int = remote.sent.size()
	check(body._mesh is LocalWalkerVisual and body._mesh.get_child_count() == 12, "complete original humanoid in actual shell")
	check(body._mesh.find_children("*", "CollisionObject3D", true, false).is_empty(), "visual has no collision or picking objects")
	var colliders: Array[Node] = body.find_children("*", "CollisionShape3D", false, false)
	check(colliders.size() == 1, "exactly one original collider")
	var shape: CapsuleShape3D = colliders[0].shape
	check(is_equal_approx(shape.radius, 0.3) and is_equal_approx(shape.height, 1.8) and colliders[0].transform == Transform3D.IDENTITY, "capsule dimensions and transform unchanged")
	check(body.collision_layer == 2 and body.collision_mask == 1 and is_equal_approx(body.floor_snap_length, 0.2), "collision filters and snap unchanged")
	body.set_navigation_enabled(true)
	body.set_camera_mode(LocalHabitatCharacter.CameraMode.FIRST_PERSON)
	await physics_frames(30)
	check(body.is_on_floor(), "actual shell floor supports unchanged body")
	check(not body._mesh.is_visible_in_tree() and body._arm.spring_length == 0.0, "first-person hides entire humanoid")
	for part: Node3D in body._mesh.get_children():
		check(not part.is_visible_in_tree(), "first-person child geometry hidden")
	var start: Vector3 = body.position
	body.set_motion_intent(Vector2(1, 0), false)
	await physics_frames(50)
	check(body.position.distance_to(start) > 0.1, "real local physics still moves")
	body.set_motion_intent(Vector2.ZERO, false)
	body.set_camera_mode(LocalHabitatCharacter.CameraMode.THIRD_PERSON)
	check(body._mesh.is_visible_in_tree() and body._arm.spring_length == 3.0, "third-person retains visibility and camera arm")
	for part: Node3D in body._mesh.get_children():
		check(part.is_visible_in_tree(), "third-person child geometry visible")
	await capture_body(body, "third-person")
	body.set_camera_mode(LocalHabitatCharacter.CameraMode.FIRST_PERSON)
	await capture_body(body, "first-person")
	check(world.capture_world_snapshot_json().value == canonical and remote.sent.size() == sent, "geometry and local physics leave canonical snapshot and command queue unchanged")
	body.set_navigation_enabled(false)
	check(not body.is_physics_processing(), "inspection release still disables navigation")
	client.free()
	world.free()
	if failures == 0: print("Local walker actual-shell humanoid and visibility invariants passed.")
	quit(0 if failures == 0 else 1)


func physics_frames(count: int) -> void:
	for _frame in range(count): await physics_frame


func capture_body(_body: LocalHabitatCharacter, _label: String) -> void:
	pass
