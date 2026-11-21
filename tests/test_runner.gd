# Peluncur uji headless untuk Godot 4.7.
# Jalankan:
#   godot --headless --path . --script res://tests/test_runner.gd
extends SceneTree


func _initialize() -> void:
	await process_frame
	var suite_script := load("res://tests/test_suite.gd") as Script
	if suite_script == null:
		push_error("FAIL: gagal memuat res://tests/test_suite.gd")
		quit(1)
		return
	var suite: Node = suite_script.new() as Node
	root.add_child(suite)
	var failed: int = await suite.run_all_tests()
	suite.queue_free()
	await process_frame
	quit(1 if failed > 0 else 0)
