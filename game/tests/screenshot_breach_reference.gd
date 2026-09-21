extends SceneTree

func _initialize() -> void:
	change_scene_to_file("res://scenes/level_6_breach.tscn")
	_run.call_deferred()

func _run() -> void:
	await create_timer(2.0).timeout
	var level: Node = current_scene
	level.set_process(false)
	var creature: Node = level.get("_creature")
	creature.set_process(false)
	var body: Node3D = creature.get("_body")
	body.global_position = Vector3(0, 0, 14)
	body.rotation.y = PI
	var player: Node3D = level.get_node("Player")
	player.set("ai_active", true)
	player.global_position = Vector3(0, 0.1, 12.4)
	player.call("ai_look_at", Vector3(0, 1.65, 14))
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("/tmp/breach_attack")
	root.get_texture().get_image().save_png("/tmp/breach_attack/model_reference.png")
	quit(0)
