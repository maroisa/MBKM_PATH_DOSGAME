extends Node
## Pengelola perpindahan scene, stack modal (Buku Saku & Leaderboard), dan zoom lintas perangkat (Desktop & HP).

signal zoom_changed(new_zoom: float)
signal pinch_zoom_started

const SCENE_LOGIN := "res://scenes/ui/login_screen.tscn"
const SCENE_HUB := "res://scenes/ui/main_hub.tscn"
const SCENE_REPORT := "res://scenes/ui/final_report.tscn"
const SCENE_BUKU_SAKU := "res://scenes/components/buku_saku_modal.tscn"
const SCENE_LEADERBOARD := "res://scenes/components/leaderboard_modal.tscn"

const ZOOM_MIN: float = 0.50
const ZOOM_MAX: float = 2.00
const ZOOM_STEP: float = 0.10
const ZOOM_DEFAULT: float = 1.00
const WEB_ZOOM_POLL_SEC: float = 0.033
const WEB_DPR_POLL_SEC: float = 0.25

var _modal_layer: CanvasLayer = null
var _active_modal: Control = null
var _last_focus_owner: Control = null

var _base_dpr: float = 1.0
var _user_zoom: float = ZOOM_DEFAULT
var _web_zoom_bridge_ready: bool = false
var _web_poll_accum: float = 0.0
var _web_dpr_accum: float = 0.0

var _touches: Dictionary[int, Vector2] = {}
var _is_pinching: bool = false
var _pinch_block_until_all_released: bool = false
var _pinch_cooldown_until_msec: int = 0
var _pinch_id_a: int = -1
var _pinch_id_b: int = -1
var _pinch_start_dist: float = 0.0
var _pinch_start_zoom: float = ZOOM_DEFAULT

var _zoom_toast_layer: CanvasLayer = null
var _zoom_toast_panel: PanelContainer = null
var _zoom_toast_lbl: Label = null
var _zoom_toast_tween: Tween = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_base_dpr = _read_system_dpr()
	_apply_scale_factor(false)
	var win := get_window()
	if win != null and not win.size_changed.is_connected(_on_window_resized):
		win.size_changed.connect(_on_window_resized)

	_modal_layer = CanvasLayer.new()
	_modal_layer.layer = 50
	add_child(_modal_layer)

	if DisplayServer.get_name() != "headless":
		_build_zoom_toast()

	if OS.has_feature("web"):
		_setup_web_zoom_bridge()
		set_process(true)
	else:
		set_process(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_clear_touch_state()


func _process(delta: float) -> void:
	if not _web_zoom_bridge_ready:
		return
	_web_poll_accum += delta
	_web_dpr_accum += delta

	if _web_poll_accum >= WEB_ZOOM_POLL_SEC:
		_web_poll_accum = 0.0
		_poll_web_zoom_bridge()

	if _web_dpr_accum >= WEB_DPR_POLL_SEC:
		_web_dpr_accum = 0.0
		_sync_system_dpr()


func _read_system_dpr() -> float:
	if DisplayServer.get_name() == "headless":
		return 1.0
	if OS.has_feature("web"):
		var raw_dpr: Variant = JavaScriptBridge.eval("window.devicePixelRatio || 1")
		if raw_dpr != null:
			return clampf(float(raw_dpr), 0.5, 4.0)
		return 1.0
	return clampf(DisplayServer.screen_get_scale(), 0.5, 4.0)


func _sync_system_dpr() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var next_dpr: float = _read_system_dpr()
	if absf(next_dpr - _base_dpr) > 0.01:
		_base_dpr = next_dpr
		_apply_scale_factor(false)


func _on_window_resized() -> void:
	if OS.has_feature("web"):
		_sync_system_dpr()


func _setup_web_zoom_bridge() -> void:
	var js := """
(function() {
	if (window.__dosZoomBridge) return true;
	var st = {
		pendingDelta: 0,
		resetRequested: false,
		currentZoom: 1.0,
		pinchActive: false,
		pinchBlocking: false,
		pinchJustStarted: false,
		pinchStartDist: 0,
		pinchStartZoom: 1.0,
		pinchTargetZoom: -1
	};
	window.__dosZoomBridge = st;

	function touchDist(t0, t1) {
		var dx = t1.clientX - t0.clientX;
		var dy = t1.clientY - t0.clientY;
		return Math.sqrt(dx * dx + dy * dy);
	}

	window.addEventListener('keydown', function(e) {
		if ((e.ctrlKey || e.metaKey) && !e.altKey) {
			if (e.key === '+' || e.key === '=' || e.code === 'Equal' || e.code === 'NumpadAdd') {
				e.preventDefault();
				e.stopImmediatePropagation();
				st.pendingDelta += 0.1;
			} else if (e.key === '-' || e.key === '_' || e.code === 'Minus' || e.code === 'NumpadSubtract') {
				e.preventDefault();
				e.stopImmediatePropagation();
				st.pendingDelta -= 0.1;
			} else if (e.key === '0' || e.code === 'Digit0' || e.code === 'Numpad0') {
				e.preventDefault();
				e.stopImmediatePropagation();
				st.resetRequested = true;
			}
		}
	}, { capture: true, passive: false });

	window.addEventListener('wheel', function(e) {
		if (e.ctrlKey || e.metaKey) {
			e.preventDefault();
			e.stopImmediatePropagation();
			var dy = e.deltaY || 0;
			if (e.deltaMode === 1) dy *= 32;
			else if (e.deltaMode === 2) dy *= 400;
			var step = 0;
			if (Math.abs(dy) >= 40) {
				step = dy < 0 ? 0.1 : -0.1;
			} else if (dy !== 0) {
				step = Math.max(-0.12, Math.min(0.12, -dy * 0.005));
			}
			st.pendingDelta += step;
		}
	}, { capture: true, passive: false });

	window.addEventListener('touchstart', function(e) {
		if (e.touches && e.touches.length >= 2) {
			st.pinchStartDist = Math.max(20, touchDist(e.touches[0], e.touches[1]));
			st.pinchStartZoom = st.currentZoom || 1.0;
			st.pinchTargetZoom = st.pinchStartZoom;
			if (!st.pinchActive) st.pinchJustStarted = true;
			st.pinchActive = true;
			st.pinchBlocking = true;
			if (e.cancelable) e.preventDefault();
			e.stopImmediatePropagation();
		} else if (st.pinchBlocking) {
			if (e.cancelable) e.preventDefault();
			e.stopImmediatePropagation();
		}
	}, { capture: true, passive: false });

	window.addEventListener('touchmove', function(e) {
		if (st.pinchActive && e.touches && e.touches.length >= 2) {
			var d = touchDist(e.touches[0], e.touches[1]);
			if (st.pinchStartDist > 1 && d > 10) {
				var nz = st.pinchStartZoom * (d / st.pinchStartDist);
				st.pinchTargetZoom = Math.max(0.5, Math.min(2.0, nz));
			}
			if (e.cancelable) e.preventDefault();
			e.stopImmediatePropagation();
		} else if (st.pinchBlocking) {
			if (e.cancelable) e.preventDefault();
			e.stopImmediatePropagation();
		}
	}, { capture: true, passive: false });

	function onTouchEnd(e) {
		if (!st.pinchBlocking) return;
		var n = e.touches ? e.touches.length : 0;
		if (n < 2) {
			st.pinchActive = false;
			if (st.pinchTargetZoom > 0 && Math.abs(st.pinchTargetZoom - 1.0) <= 0.03) {
				st.pinchTargetZoom = 1.0;
			}
		} else {
			st.pinchStartDist = Math.max(20, touchDist(e.touches[0], e.touches[1]));
			st.pinchStartZoom = st.currentZoom || 1.0;
		}
		if (n === 0) {
			st.pinchBlocking = false;
		}
		if (e.cancelable) e.preventDefault();
		e.stopImmediatePropagation();
	}
	window.addEventListener('touchend', onTouchEnd, { capture: true, passive: false });
	window.addEventListener('touchcancel', onTouchEnd, { capture: true, passive: false });

	return true;
})();
"""
	var ok: Variant = JavaScriptBridge.eval(js)
	_web_zoom_bridge_ready = bool(ok)


func _poll_web_zoom_bridge() -> void:
	var raw: Variant = JavaScriptBridge.eval(
		"(function(){ var s = window.__dosZoomBridge; if (!s) return ''; var d = s.pendingDelta; var r = s.resetRequested; var pz = s.pinchTargetZoom; var ps = s.pinchJustStarted; if (!r && !ps && pz < 0 && Math.abs(d) < 0.0001) return ''; s.pendingDelta = 0; s.resetRequested = false; s.pinchJustStarted = false; s.pinchTargetZoom = -1; return (r ? '1' : '0') + '|' + d.toFixed(4) + '|' + (ps ? '1' : '0') + '|' + (pz >= 0 ? pz.toFixed(4) : '-1'); })()"
	)
	if raw == null:
		return
	var txt: String = str(raw)
	if txt.is_empty():
		return
	var parts: PackedStringArray = txt.split("|")
	if parts.size() < 4:
		return
	if parts[2] == "1":
		_clear_touch_state()
		pinch_zoom_started.emit()
	if parts[0] == "1":
		reset_zoom(true)
	elif parts[3] != "-1":
		set_user_zoom(float(parts[3]), true)
	else:
		var delta_z: float = float(parts[1])
		if absf(delta_z) >= 0.0001:
			step_zoom(delta_z, true)


func get_user_zoom() -> float:
	return _user_zoom


func set_user_zoom(target_zoom: float, show_toast: bool = true) -> void:
	var clamped: float = snappedf(clampf(target_zoom, ZOOM_MIN, ZOOM_MAX), 0.01)
	var changed: bool = absf(clamped - _user_zoom) >= 0.005
	_user_zoom = clamped
	if _web_zoom_bridge_ready and OS.has_feature("web"):
		JavaScriptBridge.eval("if(window.__dosZoomBridge){window.__dosZoomBridge.currentZoom=%s;}" % str(_user_zoom))
	if changed:
		_apply_scale_factor(show_toast)
		zoom_changed.emit(_user_zoom)
	elif show_toast:
		_show_zoom_toast()


func step_zoom(delta: float, show_toast: bool = true) -> void:
	set_user_zoom(_user_zoom + delta, show_toast)


func reset_zoom(show_toast: bool = true) -> void:
	set_user_zoom(ZOOM_DEFAULT, show_toast)


func is_pinch_zooming() -> bool:
	return _is_pinching or _pinch_block_until_all_released or (Time.get_ticks_msec() <= _pinch_cooldown_until_msec)


func _apply_scale_factor(show_toast: bool) -> void:
	if DisplayServer.get_name() != "headless":
		var win := get_window()
		if win != null:
			var eff_scale: float = clampf(_base_dpr * _user_zoom, 0.4, 5.0)
			if absf(win.content_scale_factor - eff_scale) > 0.001:
				win.content_scale_factor = eff_scale
	if show_toast:
		_show_zoom_toast()


func _build_zoom_toast() -> void:
	_zoom_toast_layer = CanvasLayer.new()
	_zoom_toast_layer.layer = 90
	add_child(_zoom_toast_layer)

	var anchor_box := MarginContainer.new()
	anchor_box.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	anchor_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	anchor_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_box.add_theme_constant_override("margin_top", 12)
	anchor_box.add_theme_constant_override("margin_right", 12)
	_zoom_toast_layer.add_child(anchor_box)

	_zoom_toast_panel = PanelContainer.new()
	_zoom_toast_panel.visible = false
	_zoom_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTheme.style_monitor_panel(_zoom_toast_panel, 8.0)
	anchor_box.add_child(_zoom_toast_panel)

	_zoom_toast_lbl = Label.new()
	_zoom_toast_lbl.text = "ZOOM 100%"
	_zoom_toast_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTheme.style_pixel_heading(_zoom_toast_lbl, 14, UiTheme.COL_GOLD_BRIGHT, true)
	_zoom_toast_panel.add_child(_zoom_toast_lbl)


func _show_zoom_toast() -> void:
	if _zoom_toast_panel == null or _zoom_toast_lbl == null or not is_inside_tree():
		return
	var pct: int = int(roundf(_user_zoom * 100.0))
	_zoom_toast_lbl.text = "ZOOM %d%%" % pct
	_zoom_toast_panel.visible = true
	_zoom_toast_panel.modulate.a = 1.0
	if _zoom_toast_tween != null and _zoom_toast_tween.is_valid():
		_zoom_toast_tween.kill()
	_zoom_toast_tween = create_tween()
	_zoom_toast_tween.set_ignore_time_scale(true)
	_zoom_toast_tween.tween_interval(1.1)
	_zoom_toast_tween.tween_property(_zoom_toast_panel, "modulate:a", 0.0, 0.25)
	_zoom_toast_tween.tween_callback(func() -> void:
		if is_instance_valid(_zoom_toast_panel):
			_zoom_toast_panel.visible = false
	)


func _to_physical_pos(vp_pos: Vector2) -> Vector2:
	var win := get_window()
	var sf: float = win.content_scale_factor if (win != null and win.content_scale_factor > 0.0) else 1.0
	return vp_pos * sf


func _clear_touch_state() -> void:
	_touches.clear()
	_is_pinching = false
	_pinch_block_until_all_released = false
	_pinch_id_a = -1
	_pinch_id_b = -1
	_pinch_start_dist = 0.0


func _begin_pinch() -> void:
	var ids: Array = _touches.keys()
	ids.sort()
	if ids.size() < 2:
		return
	_pinch_id_a = int(ids[0])
	_pinch_id_b = int(ids[1])
	var pa: Vector2 = _touches[_pinch_id_a]
	var pb: Vector2 = _touches[_pinch_id_b]
	_pinch_start_dist = maxf(24.0, pa.distance_to(pb))
	_pinch_start_zoom = _user_zoom
	var was_pinching: bool = _is_pinching
	_is_pinching = true
	_pinch_block_until_all_released = true
	if not was_pinching:
		pinch_zoom_started.emit()


func _end_pinch() -> void:
	_is_pinching = false
	_pinch_id_a = -1
	_pinch_id_b = -1
	_pinch_start_dist = 0.0
	_pinch_cooldown_until_msec = Time.get_ticks_msec() + 240
	if absf(_user_zoom - ZOOM_DEFAULT) <= 0.03 and absf(_user_zoom - ZOOM_DEFAULT) > 0.001:
		reset_zoom(true)


func _input(event: InputEvent) -> void:
	# 1. Pinch-to-zoom 2 jari (native non-Web / fallback jika JS bridge tidak aktif)
	if not _web_zoom_bridge_ready and event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed and not st.canceled:
			_touches[st.index] = _to_physical_pos(st.position)
			if _touches.size() >= 2:
				_begin_pinch()
				get_viewport().set_input_as_handled()
			elif _pinch_block_until_all_released:
				get_viewport().set_input_as_handled()
		else:
			_touches.erase(st.index)
			if _is_pinching:
				if _touches.size() >= 2:
					_begin_pinch()
				else:
					_end_pinch()
				if _touches.is_empty():
					_pinch_block_until_all_released = false
				get_viewport().set_input_as_handled()
			elif _pinch_block_until_all_released:
				if _touches.is_empty():
					_pinch_block_until_all_released = false
					_pinch_cooldown_until_msec = Time.get_ticks_msec() + 220
				get_viewport().set_input_as_handled()
		return

	if not _web_zoom_bridge_ready and event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if _touches.has(sd.index):
			_touches[sd.index] = _to_physical_pos(sd.position)
		if _is_pinching and _touches.has(_pinch_id_a) and _touches.has(_pinch_id_b):
			var cur_dist: float = _touches[_pinch_id_a].distance_to(_touches[_pinch_id_b])
			if _pinch_start_dist > 1.0 and cur_dist > 10.0:
				var ratio: float = cur_dist / _pinch_start_dist
				set_user_zoom(_pinch_start_zoom * ratio, true)
			get_viewport().set_input_as_handled()
			return
		if _pinch_block_until_all_released:
			get_viewport().set_input_as_handled()
			return

	# Cegah klik mouse emulasi sisa dari gestur pinch
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.device == InputEvent.DEVICE_ID_EMULATION and is_pinch_zooming():
			get_viewport().set_input_as_handled()
			return
		if not _web_zoom_bridge_ready and mb.pressed and (mb.ctrl_pressed or mb.meta_pressed):
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				var fac_up: float = clampf(mb.factor if mb.factor > 0.0 else 1.0, 0.25, 2.0)
				step_zoom(ZOOM_STEP * fac_up, true)
				get_viewport().set_input_as_handled()
				return
			if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				var fac_dn: float = clampf(mb.factor if mb.factor > 0.0 else 1.0, 0.25, 2.0)
				step_zoom(-ZOOM_STEP * fac_dn, true)
				get_viewport().set_input_as_handled()
				return

	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if mm.device == InputEvent.DEVICE_ID_EMULATION and is_pinch_zooming():
			get_viewport().set_input_as_handled()
			return

	# 2. Trackpad pinch-to-zoom native (macOS / Windows Precision Touchpad)
	if event is InputEventMagnifyGesture:
		var mg := event as InputEventMagnifyGesture
		if mg.factor > 0.0:
			set_user_zoom(_user_zoom * clampf(mg.factor, 0.5, 2.0), true)
			get_viewport().set_input_as_handled()
		return

	# 3. Shortcut keyboard Desktop: Ctrl + / Ctrl - / Ctrl 0 (non-Web atau fallback jika bridge tidak aktif)
	if not _web_zoom_bridge_ready and event is InputEventKey:
		var ke := event as InputEventKey
		if ke.pressed and (ke.ctrl_pressed or ke.meta_pressed) and not ke.alt_pressed:
			if ke.keycode in [KEY_EQUAL, KEY_PLUS, KEY_KP_ADD] or ke.physical_keycode in [KEY_EQUAL, KEY_KP_ADD]:
				step_zoom(ZOOM_STEP, true)
				get_viewport().set_input_as_handled()
				return
			if ke.keycode in [KEY_MINUS, KEY_KP_SUBTRACT] or ke.physical_keycode in [KEY_MINUS, KEY_KP_SUBTRACT]:
				step_zoom(-ZOOM_STEP, true)
				get_viewport().set_input_as_handled()
				return
			if ke.keycode in [KEY_0, KEY_KP_0] or ke.physical_keycode in [KEY_0, KEY_KP_0]:
				reset_zoom(true)
				get_viewport().set_input_as_handled()
				return


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
	if bool(GameSession.mg_completed.get(mg_id, false)):
		return
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
	AudioManager.play_modal_open()
	return modal


func close_modal() -> void:
	if _active_modal != null and is_instance_valid(_active_modal):
		AudioManager.play_modal_close()
		_active_modal.queue_free()
	_active_modal = null
	var current_scene := get_tree().current_scene
	if current_scene is Control:
		(current_scene as Control).focus_behavior_recursive = Control.FOCUS_BEHAVIOR_INHERITED
		(current_scene as Control).mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_INHERITED
	if _last_focus_owner != null and is_instance_valid(_last_focus_owner) and _last_focus_owner.is_inside_tree():
		_last_focus_owner.grab_focus()
	_last_focus_owner = null
