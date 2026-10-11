extends "res://tests/godot/local_walker_visual_test.gd"

## Internal genuine stills from the existing local camera in the actual shell.
func capture_body(body: LocalHabitatCharacter, label: String) -> void:
	check(DisplayServer.get_name() != "headless", "native renderer required")
	for _frame in range(5): await process_frame
	await RenderingServer.frame_post_draw
	check(body._camera.current, "capture uses unchanged local camera")
	var directory: String = "res://var/captures/local-walker"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	check(body.get_viewport().get_texture().get_image().save_png(directory.path_join(label + ".png")) == OK, "local camera still saved")
