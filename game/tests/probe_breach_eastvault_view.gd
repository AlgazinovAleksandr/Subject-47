extends SceneTree

# Throwaway render probe (2026-09-23): is the EastVault flashlight cabinet's leaking beam
# noticeable from WardA? Needs a render target — run WITHOUT --headless.
#   Godot --path game --script res://tests/probe_breach_eastvault_view.gd
const SCENE := "res://scenes/level_6_breach.tscn"
const OUT := "/tmp/breach_eastvault/"
const VIEWS := [
	["wardA_doorway", Vector3(7.0, 0.1, 24.0)],
	["wardA_entry_from_atrium", Vector3(4.6, 0.1, 21.0)],
	["wardA_north", Vector3(7.0, 0.1, 29.0)],
]


func _initialize() -> void:
	change_scene_to_file(SCENE)
	_run.call_deferred()


func _run() -> void:
	await create_timer(1.8).timeout
	var level := current_scene
	preload("res://tests/lib/breach_hunt_fixture.gd").enter(level)
	var creature: Node = level.get("_creature")
	creature.set_process(false)
	creature.set_physics_process(false)
	level.set("_familiarization_t", -1000.0)
	var player: CharacterBody3D = level.get_node("Player")
	player.set("ai_active", true)
	var cabinet: Node3D = level.get("_flashlight_cabinet")
	var clue: Node = level.get("_flashlight_clue")
	var target := cabinet.global_position + Vector3(0, 1.0, 0)
	DirAccess.make_dir_recursive_absolute(OUT)
	for view in VIEWS:
		player.global_position = view[1]
		for phase in [["lit", 0.1], ["dark", 2.0]]:
			clue.set("_time", phase[1])
			player.call("ai_look_at", target)
			for i in 6:
				await process_frame
			clue.set("_time", phase[1])
			await RenderingServer.frame_post_draw
			var path: String = OUT + "%s_%s.png" % [view[0], phase[0]]
			root.get_texture().get_image().save_png(path)
			print("SHOT %s  dist=%.1f m" % [path, Vector2(view[1].x - target.x, view[1].z - target.z).length()])
	quit(0)
