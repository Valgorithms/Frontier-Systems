extends "res://tests/godot/observed_avatar_presentation_test.gd"

## Native stills of the same actual-world/actual-shell no-port fixture. No uploads.
func capture_pose(avatar: ObservedAvatarPresentation, label: String) -> void:
	check(DisplayServer.get_name() != "headless", "native renderer required for stills")
	var camera := Camera3D.new()
	client._habitat.add_child(camera)
	camera.global_position = avatar.global_position + Vector3(2.0, 0.9, 2.4)
	camera.look_at(avatar.global_position)
	camera.current = true
	for _frame in range(5): await process_frame
	await RenderingServer.frame_post_draw
	var directory: String = "res://var/captures/observed-avatar"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	check(client._habitat.get_viewport().get_texture().get_image().save_png(directory.path_join(label + ".png")) == OK, "native still saved")
	camera.free()
