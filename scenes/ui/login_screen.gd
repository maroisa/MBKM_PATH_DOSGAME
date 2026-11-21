extends Control
## Layar 1: Title & Login Retro Pixel Art Modern Stardew Valley (manual numeric Absen + 1 fokus utama + 2 tombol cepat).

var _margin: MarginContainer
var _scroll: TouchScrollContainer
var _center_pad: MarginContainer
var _kb_spacer: Control
var _resume_panel: PanelContainer
var _resume_btn: Button
var _nama_input: LineEdit
var _selected_kelas: String = "PPLG A"
var _kelas_buttons: Dictionary[String, Button] = {}
var _absen_input: LineEdit
var _error_panel: PanelContainer
var _error_lbl: Label
var _start_btn: Button
var _status_footer_lbl: Label

var _active_input: LineEdit = null
var _user_editing_input: bool = false
var _last_kb_height: float = 0.0
var _kb_poll_accum: float = 0.0
var _max_vp_height: float = 0.0
var _last_vp_width: float = 0.0
var _scroll_tween: Tween = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.create_theme()
	if not GameConfig.class_options.is_empty():
		_selected_kelas = GameConfig.class_options[0]
	_build_ui()
	TelemetryService.sync_status_changed.connect(_on_sync_changed)
	get_viewport().size_changed.connect(_on_resized)
	_on_resized()
	_refresh_resume_state()
	_refresh_kelas_buttons()
	if is_instance_valid(_nama_input):
		_nama_input.grab_focus()
	set_process(OS.has_feature("web") or DisplayServer.is_touchscreen_available())


func _process(delta: float) -> void:
	if _active_input == null and _last_kb_height <= 0.5:
		return
	_kb_poll_accum += delta
	if _kb_poll_accum < 0.12:
		return
	_kb_poll_accum = 0.0
	_update_keyboard_avoidance()


func _build_ui() -> void:
	add_child(UiTheme.make_tiled_background())

	_margin = MarginContainer.new()
	_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_margin)

	_scroll = TouchScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_margin.add_child(_scroll)

	_center_pad = MarginContainer.new()
	_center_pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_center_pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_center_pad)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_theme_constant_override("separation", 12)
	_center_pad.add_child(col)

	# Judul Game Retro Pixel Art
	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 6)
	col.add_child(title_box)

	var title_row := HBoxContainer.new()
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.add_theme_constant_override("separation", 12)
	title_box.add_child(title_row)

	title_row.add_child(UiTheme.make_icon_rect("ico_terminal_big.png", 56))

	var title_lbl := Label.new()
	title_lbl.text = "DOS RESCUE"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiTheme.style_pixel_heading(title_lbl, 32, UiTheme.COL_GOLD_BRIGHT, true)
	title_row.add_child(title_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = "Media Belajar Interaktif Perintah DOS & Windows CMD"
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub_lbl.add_theme_font_size_override("font_size", 15)
	sub_lbl.add_theme_color_override("font_color", UiTheme.COL_TEXT_SECONDARY)
	title_box.add_child(sub_lbl)

	# Banner Sesi Tersimpan (muncul hanya jika ada sesi aktif)
	_resume_panel = PanelContainer.new()
	_resume_panel.visible = false
	_resume_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTheme.style_gold_panel(_resume_panel, 10.0)
	col.add_child(_resume_panel)

	_resume_btn = Button.new()
	_resume_btn.text = "LANJUTKAN"
	_resume_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_resume_btn.clip_text = true
	_resume_btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	UiTheme.style_blue_button(_resume_btn, "play", false)
	_resume_btn.custom_minimum_size = Vector2(0.0, UiTheme.MIN_TAP_HEIGHT)
	_resume_btn.pressed.connect(func() -> void:
		AudioManager.play_click()
		SceneRouter.go_to_hub()
	)
	_resume_panel.add_child(_resume_btn)

	# Kartu Kayu & Perkamen Utama: Form Identitas Ringkas
	var form_card := PanelContainer.new()
	form_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTheme.style_rpg_panel(form_card, 16.0)
	col.add_child(form_card)

	var form_v := VBoxContainer.new()
	form_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form_v.add_theme_constant_override("separation", 10)
	form_card.add_child(form_v)

	var form_hdr := Label.new()
	form_hdr.text = "IDENTITAS PESERTA"
	UiTheme.style_parchment_heading(form_hdr, 16, UiTheme.COL_INK_ACCENT)
	form_v.add_child(form_hdr)

	var nama_lbl := Label.new()
	nama_lbl.text = "Nama Lengkap"
	nama_lbl.add_theme_color_override("font_color", UiTheme.COL_INK_SECONDARY)
	form_v.add_child(nama_lbl)

	_nama_input = LineEdit.new()
	_nama_input.placeholder_text = "Ketik nama lengkapmu"
	_nama_input.custom_minimum_size = Vector2(160.0, UiTheme.MIN_TAP_HEIGHT)
	_nama_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_nama_input.focus_entered.connect(_on_input_focus_entered.bind(_nama_input))
	_nama_input.focus_exited.connect(_on_input_focus_exited.bind(_nama_input))
	_nama_input.gui_input.connect(_on_input_gui_input.bind(_nama_input))
	_nama_input.text_changed.connect(func(_t: String) -> void:
		_mark_user_editing(_nama_input)
	)
	_nama_input.text_submitted.connect(func(_t: String) -> void:
		if is_instance_valid(_absen_input):
			_user_editing_input = true
			_absen_input.grab_focus()
	)
	form_v.add_child(_nama_input)

	# 2 Tombol Kelas Besar: PPLG A & PPLG B saja
	var kelas_lbl := Label.new()
	kelas_lbl.text = "Pilih Kelas"
	kelas_lbl.add_theme_color_override("font_color", UiTheme.COL_INK_SECONDARY)
	form_v.add_child(kelas_lbl)

	var kelas_row := HBoxContainer.new()
	kelas_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kelas_row.add_theme_constant_override("separation", 10)
	form_v.add_child(kelas_row)

	for cls_name: String in GameConfig.class_options:
		var k_btn := Button.new()
		k_btn.text = cls_name
		k_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		k_btn.custom_minimum_size = Vector2(110.0, 52.0)
		if UiTheme.get_pixel_font() != null:
			k_btn.add_theme_font_override("font", UiTheme.get_pixel_font())
			k_btn.add_theme_font_size_override("font_size", 16)
		k_btn.pressed.connect(_on_select_kelas.bind(cls_name))
		kelas_row.add_child(k_btn)
		_kelas_buttons[cls_name] = k_btn

	# Ketik Nomor Absen Manual (1-99)
	var absen_title := Label.new()
	absen_title.text = "Nomor Absen (1-99)"
	absen_title.add_theme_color_override("font_color", UiTheme.COL_INK_SECONDARY)
	form_v.add_child(absen_title)

	_absen_input = LineEdit.new()
	_absen_input.placeholder_text = "Contoh: 12"
	_absen_input.max_length = 2
	_absen_input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	_absen_input.custom_minimum_size = Vector2(130.0, UiTheme.MIN_TAP_HEIGHT)
	_absen_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_absen_input.focus_entered.connect(_on_input_focus_entered.bind(_absen_input))
	_absen_input.focus_exited.connect(_on_input_focus_exited.bind(_absen_input))
	_absen_input.gui_input.connect(_on_input_gui_input.bind(_absen_input))
	_absen_input.text_changed.connect(_on_absen_text_changed)
	_absen_input.text_submitted.connect(func(_t: String) -> void:
		_on_start_pressed()
	)
	form_v.add_child(_absen_input)

	# Inline Error Validasi
	_error_panel = PanelContainer.new()
	_error_panel.visible = false
	UiTheme.style_feedback_panel(_error_panel, "err")
	form_v.add_child(_error_panel)

	_error_lbl = Label.new()
	_error_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_error_lbl.add_theme_color_override("font_color", UiTheme.COL_ERROR)
	_error_panel.add_child(_error_lbl)

	# 1 Tombol Emas Besar CTA
	_start_btn = Button.new()
	_start_btn.text = "MULAI MAIN"
	_start_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTheme.style_gold_button(_start_btn, "play", true)
	_start_btn.custom_minimum_size = Vector2(180.0, 56.0)
	_start_btn.pressed.connect(_on_start_pressed)
	form_v.add_child(_start_btn)

	# Tepat di bawah kartu: HANYA 2 tombol cepat [ PERINGKAT ] dan [ MATERI ]
	var quick_row := HBoxContainer.new()
	quick_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quick_row.add_theme_constant_override("separation", 10)
	col.add_child(quick_row)

	var lb_btn := Button.new()
	lb_btn.text = "PERINGKAT"
	lb_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTheme.style_blue_button(lb_btn, "trophy", true)
	lb_btn.custom_minimum_size = Vector2(120.0, 52.0)
	lb_btn.pressed.connect(func() -> void:
		AudioManager.play_click()
		SceneRouter.open_leaderboard()
	)
	quick_row.add_child(lb_btn)

	var book_btn := Button.new()
	book_btn.text = "MATERI"
	book_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTheme.style_blue_button(book_btn, "book", true)
	book_btn.custom_minimum_size = Vector2(120.0, 52.0)
	book_btn.pressed.connect(func() -> void:
		AudioManager.play_click()
		SceneRouter.open_buku_saku("")
	)
	quick_row.add_child(book_btn)

	# Catatan sinkronisasi ringkas di paling bawah (di atas latar gelap)
	_status_footer_lbl = Label.new()
	_status_footer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_footer_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_footer_lbl.add_theme_font_size_override("font_size", 13)
	_status_footer_lbl.add_theme_color_override("font_color", UiTheme.COL_TEXT_SECONDARY)
	_status_footer_lbl.text = "Kelas PPLG A & PPLG B | " + TelemetryService.get_status_label()
	col.add_child(_status_footer_lbl)

	# Spacer dinamis di bawah form agar input naik di atas keyboard HP saat mengetik
	_kb_spacer = Control.new()
	_kb_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_kb_spacer.custom_minimum_size = Vector2.ZERO
	col.add_child(_kb_spacer)


func _on_resized() -> void:
	AdaptiveLayout.apply_safe_area_margin(_margin, 14)
	var vp_size := get_viewport().get_visible_rect().size
	if absf(vp_size.x - _last_vp_width) > 40.0 or _max_vp_height <= 0.0:
		_last_vp_width = vp_size.x
		_max_vp_height = vp_size.y
	else:
		_max_vp_height = maxf(_max_vp_height, vp_size.y)
	if _center_pad != null:
		var side_pad := int(maxf(0.0, (vp_size.x - 540.0) * 0.5))
		_center_pad.add_theme_constant_override("margin_left", side_pad)
		_center_pad.add_theme_constant_override("margin_right", side_pad)
		_center_pad.add_theme_constant_override("margin_top", 8)
		_center_pad.add_theme_constant_override("margin_bottom", 8)
	if _active_input != null and _user_editing_input:
		call_deferred("_update_keyboard_avoidance")


func _on_input_focus_entered(input_ctrl: LineEdit) -> void:
	_active_input = input_ctrl
	if _user_editing_input:
		call_deferred("_update_keyboard_avoidance")


func _on_input_focus_exited(input_ctrl: LineEdit) -> void:
	if _active_input == input_ctrl:
		_active_input = null
	call_deferred("_check_clear_keyboard_avoidance")


func _on_input_gui_input(event: InputEvent, input_ctrl: LineEdit) -> void:
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		_mark_user_editing(input_ctrl)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and (_is_mobile_touch_device() or mb.device == InputEvent.DEVICE_ID_EMULATION):
			_mark_user_editing(input_ctrl)


func _mark_user_editing(input_ctrl: LineEdit) -> void:
	_active_input = input_ctrl
	_user_editing_input = true
	call_deferred("_update_keyboard_avoidance")


func _check_clear_keyboard_avoidance() -> void:
	if not is_inside_tree():
		return
	var owner_ctrl: Control = get_viewport().gui_get_focus_owner()
	if owner_ctrl == _nama_input or owner_ctrl == _absen_input:
		return
	_active_input = null
	_user_editing_input = false
	apply_keyboard_avoidance(0.0)


func _is_mobile_touch_device() -> bool:
	if DisplayServer.is_touchscreen_available():
		return true
	if OS.has_feature("web"):
		var is_mob: Variant = JavaScriptBridge.eval(
			"(function(){ return ('ontouchstart' in window) || (navigator.maxTouchPoints > 0); })()"
		)
		return bool(is_mob)
	return false


func _detect_virtual_keyboard_height() -> float:
	var vp := get_viewport()
	if vp == null:
		return 0.0
	var vp_size: Vector2 = vp.get_visible_rect().size
	var scale_f: float = 1.0
	var win := get_window()
	if win != null and win.content_scale_factor > 0.0:
		scale_f = win.content_scale_factor

	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		var native_kb: float = float(DisplayServer.virtual_keyboard_get_height()) / scale_f
		if native_kb > 60.0:
			return native_kb

	if OS.has_feature("web"):
		var raw_kb: Variant = JavaScriptBridge.eval(
			"(function(){ var ih = window.innerHeight || 0; var vv = window.visualViewport; if (!vv) return 0; return Math.max(0, Math.round(ih - vv.height - (vv.offsetTop || 0))); })()"
		)
		var web_kb: float = float(raw_kb) if raw_kb != null else 0.0
		if web_kb > 60.0:
			return web_kb
		# Jika browser sudah mengecilkan tinggi viewport sendiri (resizes-content), tidak perlu spacer ekstra.
		if _max_vp_height - vp_size.y > 100.0:
			return 0.0

	if _user_editing_input and _active_input != null and _is_mobile_touch_device():
		return clampf(vp_size.y * 0.42, 220.0, 380.0)
	return 0.0


func _update_keyboard_avoidance() -> void:
	if not is_inside_tree():
		return
	var kb_h: float = _detect_virtual_keyboard_height()
	apply_keyboard_avoidance(kb_h)


func apply_keyboard_avoidance(kb_height: float) -> void:
	if not is_inside_tree() or _kb_spacer == null or _scroll == null:
		return
	var clamped_h: float = maxf(0.0, kb_height)
	var changed: bool = absf(clamped_h - _last_kb_height) > 4.0
	_last_kb_height = clamped_h
	_kb_spacer.custom_minimum_size = Vector2(0.0, clamped_h + (20.0 if clamped_h > 0.0 else 0.0))
	if _active_input != null and is_instance_valid(_active_input) and (_user_editing_input or clamped_h > 0.0):
		if changed or clamped_h > 0.0 or (_max_vp_height - get_viewport().get_visible_rect().size.y > 100.0):
			_scroll_active_input_after_layout(clamped_h)


func _scroll_active_input_after_layout(kb_height: float) -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	_scroll_active_input_into_view(kb_height)


func _scroll_active_input_into_view(kb_height: float) -> void:
	if not is_inside_tree() or _active_input == null or not is_instance_valid(_active_input) or _scroll == null:
		return
	var vp_rect: Rect2 = get_viewport().get_visible_rect()
	var scroll_rect: Rect2 = _scroll.get_global_rect()
	var target_rect: Rect2 = _active_input.get_global_rect()
	var visible_bottom: float = minf(scroll_rect.end.y, vp_rect.end.y - kb_height - 20.0)
	var visible_top: float = scroll_rect.position.y + 16.0

	var vbar: VScrollBar = _scroll.get_v_scroll_bar()
	var max_v: int = int(maxf(0.0, vbar.max_value - vbar.page)) if vbar != null else 0
	var desired_v: int = _scroll.scroll_vertical

	if target_rect.end.y + 16.0 > visible_bottom:
		var push_up: float = (target_rect.end.y + 16.0) - visible_bottom
		desired_v = clampi(_scroll.scroll_vertical + int(ceilf(push_up)), 0, max_v)
	elif target_rect.position.y < visible_top:
		var pull_dn: float = visible_top - target_rect.position.y
		desired_v = maxi(0, _scroll.scroll_vertical - int(ceilf(pull_dn)))

	if desired_v == _scroll.scroll_vertical:
		return
	if _scroll_tween != null and _scroll_tween.is_valid():
		_scroll_tween.kill()
	if DisplayServer.get_name() == "headless":
		_scroll.scroll_vertical = desired_v
		return
	_scroll_tween = create_tween()
	_scroll_tween.set_ignore_time_scale(true)
	_scroll_tween.tween_property(_scroll, "scroll_vertical", desired_v, 0.18) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _on_sync_changed(_code: String, _msg: String) -> void:
	if is_inside_tree() and _status_footer_lbl != null:
		_status_footer_lbl.text = "Kelas PPLG A & PPLG B | " + TelemetryService.get_status_label()


func _refresh_resume_state() -> void:
	if GameSession.has_active_session():
		_resume_panel.visible = true
		_resume_btn.text = "LANJUTKAN: %s (%d/5)" % [
			GameSession.nama,
			GameSession.get_completed_minigame_count()
		]
	else:
		_resume_panel.visible = false


func _on_select_kelas(cls_name: String) -> void:
	AudioManager.play_click()
	_selected_kelas = cls_name
	_refresh_kelas_buttons()


func _refresh_kelas_buttons() -> void:
	for k: String in _kelas_buttons.keys():
		UiTheme.style_chip_button(_kelas_buttons[k], k == _selected_kelas)


func _on_absen_text_changed(raw: String) -> void:
	_mark_user_editing(_absen_input)
	var cleaned := _filter_digits(raw)
	if cleaned != raw:
		var col_idx: int = clampi(_absen_input.caret_column - (raw.length() - cleaned.length()), 0, cleaned.length())
		_absen_input.text = cleaned
		_absen_input.caret_column = col_idx


static func _filter_digits(raw: String) -> String:
	var out: String = ""
	for i: int in range(raw.length()):
		var ch: String = raw.substr(i, 1)
		if ch >= "0" and ch <= "9":
			out += ch
	return out


static func parse_valid_absen(raw: String) -> int:
	var trimmed: String = raw.strip_edges()
	if trimmed.is_empty() or not trimmed.is_valid_int():
		return -1
	var num: int = int(trimmed)
	if num < 1 or num > 99:
		return -1
	return num


func _on_start_pressed() -> void:
	AudioManager.play_click()
	var nama_val: String = _nama_input.text.strip_edges()
	if nama_val.length() < 2:
		_show_error("Isi Nama Lengkap minimal 2 huruf sebelum mulai main.")
		if is_instance_valid(_nama_input):
			_nama_input.grab_focus()
		return

	var absen_num: int = parse_valid_absen(_absen_input.text)
	if absen_num <= 0:
		_show_error("Isi Nomor Absen dengan angka 1 sampai 99.")
		if is_instance_valid(_absen_input):
			_absen_input.grab_focus()
		return

	_error_panel.visible = false
	GameSession.start_new_session(nama_val, _selected_kelas, str(absen_num))
	TelemetryService.send_session_start()
	SceneRouter.go_to_hub()


func _show_error(msg: String) -> void:
	AudioManager.play_error()
	_error_lbl.text = "[ERR] " + msg
	_error_panel.visible = true
	UiTheme.shake_control(_error_panel, 8.0)
