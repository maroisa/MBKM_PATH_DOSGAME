class_name TouchScrollContainer
extends ScrollContainer
## ScrollContainer responsif sentuhan penuh (HP/Tablet Web & Mobile) dengan drag dari tengah layar,
## inertia halus, dukungan nested ScrollContainer, dan pencegahan klik tombol tak sengaja saat menggeser.

const DRAG_DEADZONE_PX: float = 10.0
const MAX_INERTIA_SPEED: float = 2800.0
const MIN_INERTIA_SPEED: float = 45.0
const INERTIA_DECEL_BASE: float = 1800.0
const INERTIA_DECEL_FACTOR: float = 5.5
const FLICK_IDLE_CUTOFF_MSEC: int = 110
const EMULATED_RELEASE_SUPPRESS_MSEC: int = 180

var _touch_active: bool = false
var _touch_id: int = -1
var _is_dragging: bool = false
var _start_local_pos: Vector2 = Vector2.ZERO
var _last_local_pos: Vector2 = Vector2.ZERO
var _scroll_float_x: float = 0.0
var _scroll_float_y: float = 0.0
var _velocity_x: float = 0.0
var _velocity_y: float = 0.0
var _last_drag_msec: int = 0
var _decelerating: bool = false
var _pressed_button: BaseButton = null
var _suppress_emulated_release_until_msec: int = 0
var _default_h_scroll_mode: ScrollMode = ScrollContainer.SCROLL_MODE_DISABLED


func _ready() -> void:
	# Nonaktifkan touch-drag bawaan agar tidak terjadi double-scroll dengan handler sentuhan kustom;
	# roda mouse desktop, trackpad pan gesture, dan drag scrollbar samping tetap aktif secara native.
	scroll_deadzone = 10000
	_default_h_scroll_mode = horizontal_scroll_mode
	set_process(false)
	var router: Node = get_node_or_null("/root/SceneRouter")
	if router != null:
		if router.has_signal("pinch_zoom_started") and not router.is_connected("pinch_zoom_started", _on_pinch_zoom_started):
			router.connect("pinch_zoom_started", _on_pinch_zoom_started)
		if router.has_signal("zoom_changed") and not router.is_connected("zoom_changed", _on_zoom_changed):
			router.connect("zoom_changed", _on_zoom_changed)
	if get_viewport() != null and not get_viewport().size_changed.is_connected(_sync_zoom_horizontal_scroll):
		get_viewport().size_changed.connect(_sync_zoom_horizontal_scroll)
	_sync_zoom_horizontal_scroll()


func _on_pinch_zoom_started() -> void:
	_cancel_pressed_button()
	_reset_touch_state()


func _on_zoom_changed(_new_zoom: float) -> void:
	_sync_zoom_horizontal_scroll()


func _sync_zoom_horizontal_scroll() -> void:
	if not is_inside_tree() or get_viewport() == null:
		return
	var router: Node = get_node_or_null("/root/SceneRouter")
	var z: float = float(router.call("get_user_zoom")) if (router != null and router.has_method("get_user_zoom")) else 1.0
	var vp_w: float = get_viewport().get_visible_rect().size.x
	if _default_h_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED:
		if z > 1.05 and vp_w < 360.0:
			horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		else:
			horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			scroll_horizontal = 0


func _input(event: InputEvent) -> void:
	var router: Node = get_node_or_null("/root/SceneRouter")
	if router != null and router.has_method("is_pinch_zooming") and bool(router.call("is_pinch_zooming")):
		if _touch_active or _is_dragging or _pressed_button != null:
			_cancel_pressed_button()
			_reset_touch_state()
		return

	if not _is_interaction_enabled():
		if _touch_active or _is_dragging:
			_reset_touch_state()
		return

	if event is InputEventScreenTouch:
		_handle_screen_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event as InputEventScreenDrag)
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _is_dragging and mm.device == InputEvent.DEVICE_ID_EMULATION:
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.device == InputEvent.DEVICE_ID_EMULATION:
			if _is_dragging:
				get_viewport().set_input_as_handled()
			elif not mb.pressed and _suppress_emulated_release_until_msec > 0:
				var deadline_ms: int = _suppress_emulated_release_until_msec
				_suppress_emulated_release_until_msec = 0
				if Time.get_ticks_msec() <= deadline_ms:
					get_viewport().set_input_as_handled()


func _handle_screen_touch(ev: InputEventScreenTouch) -> void:
	if ev.pressed:
		if _touch_active and _touch_id != ev.index:
			# Jari kedua menyentuh layar: hentikan scroll 1-jari agar tidak bertabrakan dengan pinch-to-zoom.
			_cancel_pressed_button()
			_reset_touch_state()
			return
		var local_ev := make_input_local(ev) as InputEventScreenTouch
		if local_ev == null:
			return
		if not Rect2(Vector2.ZERO, size).has_point(local_ev.position):
			return
		if _is_point_on_scrollbar(ev):
			return

		_decelerating = false
		_velocity_x = 0.0
		_velocity_y = 0.0
		set_process(false)

		_touch_active = true
		_touch_id = ev.index
		_is_dragging = false
		_start_local_pos = local_ev.position
		_last_local_pos = local_ev.position
		_scroll_float_x = float(scroll_horizontal)
		_scroll_float_y = float(scroll_vertical)
		_last_drag_msec = Time.get_ticks_msec()
		_pressed_button = _find_button_under_touch(ev)
	else:
		if not _touch_active or ev.index != _touch_id:
			return
		var was_dragging: bool = _is_dragging
		var now_ms: int = Time.get_ticks_msec()
		var idle_ms: int = now_ms - _last_drag_msec
		var vx: float = _velocity_x if idle_ms <= FLICK_IDLE_CUTOFF_MSEC else 0.0
		var vy: float = _velocity_y if idle_ms <= FLICK_IDLE_CUTOFF_MSEC else 0.0

		_touch_active = false
		_touch_id = -1
		_is_dragging = false
		_pressed_button = null

		if was_dragging:
			_suppress_emulated_release_until_msec = now_ms + EMULATED_RELEASE_SUPPRESS_MSEC
			get_viewport().set_input_as_handled()
			if not ev.canceled:
				var can_h: bool = _is_horizontal_enabled() and absf(vx) >= MIN_INERTIA_SPEED
				var can_v: bool = _is_vertical_enabled() and absf(vy) >= MIN_INERTIA_SPEED
				if can_h or can_v:
					_velocity_x = clampf(vx, -MAX_INERTIA_SPEED, MAX_INERTIA_SPEED) if can_h else 0.0
					_velocity_y = clampf(vy, -MAX_INERTIA_SPEED, MAX_INERTIA_SPEED) if can_v else 0.0
					_scroll_float_x = float(scroll_horizontal)
					_scroll_float_y = float(scroll_vertical)
					_decelerating = true
					set_process(true)


func _handle_screen_drag(ev: InputEventScreenDrag) -> void:
	if not _touch_active or ev.index != _touch_id:
		return
	var local_ev := make_input_local(ev) as InputEventScreenDrag
	if local_ev == null:
		return

	var pos: Vector2 = local_ev.position
	var delta: Vector2 = pos - _last_local_pos
	var total: Vector2 = pos - _start_local_pos

	if not _is_dragging:
		var abs_x: float = absf(total.x)
		var abs_y: float = absf(total.y)
		var wants_v: bool = _is_vertical_enabled() and abs_y >= DRAG_DEADZONE_PX and (not _is_horizontal_enabled() or abs_y >= abs_x * 0.7)
		var wants_h: bool = _is_horizontal_enabled() and abs_x >= DRAG_DEADZONE_PX and (not _is_vertical_enabled() or abs_x >= abs_y * 0.7)
		if not wants_v and not wants_h:
			return

		var can_v: bool = wants_v and _can_scroll_vertical(-total.y)
		var can_h: bool = wants_h and _can_scroll_horizontal(-total.x)
		if not can_v and not can_h:
			# Biarkan TouchScrollContainer induk (outer) mengambil alih jika container ini tidak bisa scroll ke arah ini.
			return

		_is_dragging = true
		_scroll_float_x = float(scroll_horizontal)
		_scroll_float_y = float(scroll_vertical)
		_cancel_pressed_button()
		_cancel_ancestor_drags()
		delta = total

	var now_ms: int = Time.get_ticks_msec()
	var dt: float = maxf(0.004, float(now_ms - _last_drag_msec) / 1000.0)
	_last_drag_msec = now_ms
	_last_local_pos = pos

	if _is_vertical_enabled():
		var max_v: float = _get_max_v_scroll()
		if max_v > 0.5:
			_scroll_float_y = clampf(_scroll_float_y - delta.y, 0.0, max_v)
			scroll_vertical = int(roundf(_scroll_float_y))
			var inst_vy: float = delta.y / dt
			_velocity_y = lerpf(_velocity_y, inst_vy, 0.45)

	if _is_horizontal_enabled():
		var max_h: float = _get_max_h_scroll()
		if max_h > 0.5:
			_scroll_float_x = clampf(_scroll_float_x - delta.x, 0.0, max_h)
			scroll_horizontal = int(roundf(_scroll_float_x))
			var inst_vx: float = delta.x / dt
			_velocity_x = lerpf(_velocity_x, inst_vx, 0.45)

	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not _decelerating:
		set_process(false)
		return

	var still_moving: bool = false
	if absf(_velocity_y) >= 10.0 and _is_vertical_enabled():
		var max_v: float = _get_max_v_scroll()
		var next_y: float = clampf(_scroll_float_y - _velocity_y * delta, 0.0, max_v)
		if absf(next_y - _scroll_float_y) < 0.05 and (next_y <= 0.5 or next_y >= max_v - 0.5):
			_velocity_y = 0.0
		else:
			_scroll_float_y = next_y
			scroll_vertical = int(roundf(_scroll_float_y))
			var decel_y: float = maxf(INERTIA_DECEL_BASE, absf(_velocity_y) * INERTIA_DECEL_FACTOR)
			_velocity_y = move_toward(_velocity_y, 0.0, decel_y * delta)
			if absf(_velocity_y) >= 10.0:
				still_moving = true

	if absf(_velocity_x) >= 10.0 and _is_horizontal_enabled():
		var max_h: float = _get_max_h_scroll()
		var next_x: float = clampf(_scroll_float_x - _velocity_x * delta, 0.0, max_h)
		if absf(next_x - _scroll_float_x) < 0.05 and (next_x <= 0.5 or next_x >= max_h - 0.5):
			_velocity_x = 0.0
		else:
			_scroll_float_x = next_x
			scroll_horizontal = int(roundf(_scroll_float_x))
			var decel_x: float = maxf(INERTIA_DECEL_BASE, absf(_velocity_x) * INERTIA_DECEL_FACTOR)
			_velocity_x = move_toward(_velocity_x, 0.0, decel_x * delta)
			if absf(_velocity_x) >= 10.0:
				still_moving = true

	if not still_moving:
		_decelerating = false
		_velocity_x = 0.0
		_velocity_y = 0.0
		set_process(false)


func _reset_touch_state() -> void:
	_touch_active = false
	_touch_id = -1
	_is_dragging = false
	_decelerating = false
	_velocity_x = 0.0
	_velocity_y = 0.0
	_pressed_button = null
	set_process(false)


func _cancel_ancestor_drags() -> void:
	var p: Node = get_parent()
	while p != null:
		if p is TouchScrollContainer:
			(p as TouchScrollContainer)._reset_touch_state()
		p = p.get_parent()


func _is_interaction_enabled() -> bool:
	if not is_inside_tree() or not is_visible_in_tree():
		return false
	var cur: Node = self
	while cur != null:
		if cur is Control:
			if (cur as Control).mouse_behavior_recursive == Control.MOUSE_BEHAVIOR_DISABLED:
				return false
		cur = cur.get_parent()
	return true


func _is_vertical_enabled() -> bool:
	return vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED


func _is_horizontal_enabled() -> bool:
	return horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED


func _get_max_v_scroll() -> float:
	var vbar: VScrollBar = get_v_scroll_bar()
	if vbar == null:
		return 0.0
	return maxf(0.0, vbar.max_value - vbar.page)


func _get_max_h_scroll() -> float:
	var hbar: HScrollBar = get_h_scroll_bar()
	if hbar == null:
		return 0.0
	return maxf(0.0, hbar.max_value - hbar.page)


func _can_scroll_vertical(scroll_delta_y: float) -> bool:
	var max_v: float = _get_max_v_scroll()
	if max_v <= 1.0:
		return false
	if scroll_delta_y > 0.0:
		return float(scroll_vertical) < max_v - 1.0
	if scroll_delta_y < 0.0:
		return float(scroll_vertical) > 1.0
	return true


func _can_scroll_horizontal(scroll_delta_x: float) -> bool:
	var max_h: float = _get_max_h_scroll()
	if max_h <= 1.0:
		return false
	if scroll_delta_x > 0.0:
		return float(scroll_horizontal) < max_h - 1.0
	if scroll_delta_x < 0.0:
		return float(scroll_horizontal) > 1.0
	return true


func _is_point_on_scrollbar(ev: InputEventScreenTouch) -> bool:
	var vbar: VScrollBar = get_v_scroll_bar()
	if vbar != null and vbar.is_visible_in_tree():
		var vb_ev := vbar.make_input_local(ev) as InputEventScreenTouch
		if vb_ev != null and Rect2(Vector2.ZERO, vbar.size).has_point(vb_ev.position):
			return true
	var hbar: HScrollBar = get_h_scroll_bar()
	if hbar != null and hbar.is_visible_in_tree():
		var hb_ev := hbar.make_input_local(ev) as InputEventScreenTouch
		if hb_ev != null and Rect2(Vector2.ZERO, hbar.size).has_point(hb_ev.position):
			return true
	return false


func _find_button_under_touch(ev: InputEventScreenTouch) -> BaseButton:
	var found: BaseButton = null
	var stack: Array[Node] = [self]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		for ch: Node in cur.get_children():
			if ch is ScrollBar:
				continue
			if ch is Control:
				var ctrl := ch as Control
				if not ctrl.is_visible_in_tree():
					continue
				if ctrl is BaseButton:
					var btn := ctrl as BaseButton
					if not btn.disabled:
						var b_ev := btn.make_input_local(ev) as InputEventScreenTouch
						if b_ev != null and Rect2(Vector2.ZERO, btn.size).has_point(b_ev.position):
							found = btn
			stack.append(ch)
	return found


func _cancel_pressed_button() -> void:
	if _pressed_button != null and is_instance_valid(_pressed_button):
		if not _pressed_button.disabled:
			_pressed_button.disabled = true
			_pressed_button.disabled = false
		if _pressed_button.has_focus():
			_pressed_button.release_focus()
	_pressed_button = null
