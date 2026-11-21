extends Node
## Pengelola perpindahan scene dan stack modal (Buku Saku & Leaderboard).

const SCENE_LOGIN := "res://scenes/ui/login_screen.tscn"
const SCENE_HUB := "res://scenes/ui/main_hub.tscn"
const SCENE_REPORT := "res://scenes/ui/final_report.tscn"
const SCENE_BUKU_SAKU := "res://scenes/components/buku_saku_modal.tscn"
const SCENE_LEADERBOARD := "res://scenes/components/leaderboard_modal.tscn"

var _modal_layer: CanvasLayer = null
var _active_modal: Control = null
var _last_focus_owner: Control = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_dpi_scale()
	_modal_layer = CanvasLayer.new()
	_modal_layer.layer = 50
	add_child(_modal_layer)


func _apply_dpi_scale() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var win := get_window()
	if win == null:
		return
	var dpr: float = 1.0
	if OS.has_feature("web"):
		var raw_dpr: Variant = JavaScriptBridge.eval("window.devicePixelRatio || 1")
		if raw_dpr != null:
			dpr = clampf(float(raw_dpr), 1.0, 3.0)
	else:
		dpr = clampf(DisplayServer.screen_get_scale(), 1.0, 3.0)
	win.content_scale_factor = dpr


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _active_modal != null and is_instance_valid(_active_modal):
		close_modal()
		get_viewport().set_input_as_handled()


func go_to_login() -> void:
	close_modal()
	get_tree().change_scene_to_file(SCENE_LOGIN)


func go_to_hub() -> void:
	close_modal()
	get_tree().change_scene_to_file(SCENE_HUB)


func go_to_report() -> void:
	close_modal()
	get_tree().change_scene_to_file(SCENE_REPORT)


func start_minigame(mg_id: String) -> void:
	close_modal()
	for meta: Dictionary in LevelsCatalog.get_minigames_meta():
		if str(meta.get("id", "")) == mg_id:
			var path: String = str(meta.get("scene_path", ""))
			if not path.is_empty():
				get_tree().change_scene_to_file(path)
				return
	push_error("SceneRouter: minigame id tidak ditemukan: %s" % mg_id)


func open_buku_saku(default_tab_id: String = "") -> void:
	var modal := _open_modal_scene(SCENE_BUKU_SAKU)
	if modal != null and not default_tab_id.is_empty() and modal.has_method("select_tab_by_id"):
		modal.call("select_tab_by_id", default_tab_id)


func open_leaderboard() -> void:
	_open_modal_scene(SCENE_LEADERBOARD)


func _open_modal_scene(scene_path: String) -> Control:
	if _active_modal != null and is_instance_valid(_active_modal):
		close_modal()
	var vp := get_viewport()
	if vp != null:
		_last_focus_owner = vp.gui_get_focus_owner()
	var current_scene := get_tree().current_scene
	if current_scene is Control:
		(current_scene as Control).focus_behavior_recursive = Control.FOCUS_BEHAVIOR_DISABLED
		(current_scene as Control).mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED

	var modal_scene := load(scene_path) as PackedScene
	if modal_scene == null:
		push_error("SceneRouter: gagal memuat modal: %s" % scene_path)
		return null
	var modal := modal_scene.instantiate() as Control
	_active_modal = modal
	_modal_layer.add_child(modal)
	return modal


func close_modal() -> void:
	if _active_modal != null and is_instance_valid(_active_modal):
		_active_modal.queue_free()
	_active_modal = null
	var current_scene := get_tree().current_scene
	if current_scene is Control:
		(current_scene as Control).focus_behavior_recursive = Control.FOCUS_BEHAVIOR_INHERITED
		(current_scene as Control).mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_INHERITED
	if _last_focus_owner != null and is_instance_valid(_last_focus_owner) and _last_focus_owner.is_inside_tree():
		_last_focus_owner.grab_focus()
	_last_focus_owner = null
