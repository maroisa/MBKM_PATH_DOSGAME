class_name BaseMinigame
extends Control
## Kelas induk modular untuk seluruh 5 minigame DOS/CMD (Retro Pixel Art 128-bit, 1-baris HUD).

@export var minigame_id: String = "mg1"

var _levels: Array[Dictionary] = []
var _current_index: int = 0
var _attempts_on_level: int = 0
var _level_solved: bool = false
var _level_started_unix: float = 0.0
var _current_mode: AdaptiveLayout.LayoutMode = AdaptiveLayout.LayoutMode.WIDE_DESKTOP

var _margin: MarginContainer
var _main_vbox: VBoxContainer
var _hud: HudBar
var _mission_panel: PanelContainer
var _mission_label: Label
var _feedback_box: PanelContainer
var _feedback_label: Label
var _hint_btn: Button
var _scroll: ScrollContainer
var _content_root: VBoxContainer
var _footer_panel: PanelContainer
var _footer_bar: HBoxContainer
var _footer_spacer: Control
var _reset_btn: Button
var _check_btn: Button
var _next_btn: Button
var _completion_backdrop: ColorRect
var _completion_overlay: PanelContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.create_theme()
	_levels = LevelsCatalog.get_levels(minigame_id)
	_build_shell()
	_setup_content(_content_root)
	get_viewport().size_changed.connect(_on_viewport_resized)
	_on_viewport_resized()
	_load_current_level()


func _build_shell() -> void:
	add_child(UiTheme.make_tiled_background())

	_margin = MarginContainer.new()
	_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_margin)

	_main_vbox = VBoxContainer.new()
	_main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_main_vbox.add_theme_constant_override("separation", 8)
	_margin.add_child(_main_vbox)

	# 1 Baris HUD Tipis di Atas (>= 80% layar lega untuk soal & blok!)
	_hud = HudBar.new()
	_hud.back_pressed.connect(func() -> void:
		SceneRouter.go_to_hub()
	)
	_hud.guide_pressed.connect(func() -> void:
		SceneRouter.open_buku_saku(_get_buku_saku_tab())
	)
	_main_vbox.add_child(_hud)

	# Area kerja tengah (Misi + Monitor/Puzzle + Dek Blok dalam 1 ScrollContainer lega)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_main_vbox.add_child(_scroll)

	var inner_pad := MarginContainer.new()
	inner_pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner_pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner_pad.add_theme_constant_override("margin_right", 4)
	_scroll.add_child(inner_pad)

	_content_root = VBoxContainer.new()
	_content_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_root.add_theme_constant_override("separation", 10)
	inner_pad.add_child(_content_root)

	# Kotak Misi Ringkas + Feedback Inline
	_mission_panel = PanelContainer.new()
	_mission_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTheme.style_rpg_panel(_mission_panel, 12.0)
	_content_root.add_child(_mission_panel)

	var m_vbox := VBoxContainer.new()
	m_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m_vbox.add_theme_constant_override("separation", 8)
	_mission_panel.add_child(m_vbox)

	var m_top := BoxContainer.new()
	m_top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m_top.add_theme_constant_override("separation", 8)
	m_vbox.add_child(m_top)

	_mission_label = Label.new()
	_mission_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mission_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mission_label.add_theme_font_size_override("font_size", 16)
	_mission_label.add_theme_color_override("font_color", UiTheme.COL_TEXT_PRIMARY)
	m_top.add_child(_mission_label)

	_hint_btn = Button.new()
	_hint_btn.text = "PETUNJUK"
	_hint_btn.visible = false
	UiTheme.style_blue_button(_hint_btn, "book", true)
	_hint_btn.pressed.connect(_on_hint_pressed)
	m_top.add_child(_hint_btn)

	_feedback_box = PanelContainer.new()
	_feedback_box.visible = false
	_feedback_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m_vbox.add_child(_feedback_box)

	_feedback_label = Label.new()
	_feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feedback_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_feedback_box.add_child(_feedback_label)

	# Baris Bawah: Dock Aksi Maksimal 2 Tombol ([ ULANG ] + [ CEK JAWABAN ] / [ LANJUT > ])
	_footer_panel = PanelContainer.new()
	_footer_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTheme.style_rpg_panel(_footer_panel, 10.0)
	_main_vbox.add_child(_footer_panel)

	_footer_bar = HBoxContainer.new()
	_footer_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_footer_bar.add_theme_constant_override("separation", 10)
	_footer_panel.add_child(_footer_bar)

	_reset_btn = Button.new()
	_reset_btn.text = "ULANG"
	UiTheme.style_blue_button(_reset_btn, "", true)
	_reset_btn.custom_minimum_size = Vector2(112.0, 50.0)
	_reset_btn.pressed.connect(func() -> void:
		AudioManager.play_click()
		_on_reset_level_pressed()
	)
	_footer_bar.add_child(_reset_btn)

	_footer_spacer = Control.new()
	_footer_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_footer_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_footer_bar.add_child(_footer_spacer)

	_check_btn = Button.new()
	_check_btn.text = "CEK JAWABAN"
	UiTheme.style_gold_button(_check_btn, "play", true)
	_check_btn.custom_minimum_size = Vector2(220.0, 50.0)
	_check_btn.pressed.connect(func() -> void:
		AudioManager.play_click()
		_on_submit_pressed()
	)
	_footer_bar.add_child(_check_btn)

	_next_btn = Button.new()
	_next_btn.text = "LANJUT >"
	_next_btn.visible = false
	UiTheme.style_gold_button(_next_btn, "play", true)
	_next_btn.custom_minimum_size = Vector2(220.0, 50.0)
	_next_btn.pressed.connect(func() -> void:
		AudioManager.play_click()
		_advance_level()
	)
	_footer_bar.add_child(_next_btn)

	# Overlay Penyelesaian Stage (1 fokus dengan bintang & chime)
	_completion_backdrop = ColorRect.new()
	_completion_backdrop.color = Color(0.05, 0.04, 0.09, 0.85)
	_completion_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_completion_backdrop.visible = false
	add_child(_completion_backdrop)

	var comp_center := CenterContainer.new()
	comp_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_completion_backdrop.add_child(comp_center)

	_completion_overlay = PanelContainer.new()
	_completion_overlay.custom_minimum_size = Vector2(320.0, 260.0)
	UiTheme.style_gold_panel(_completion_overlay, 18.0)
	comp_center.add_child(_completion_overlay)


func _on_viewport_resized() -> void:
	UiTheme.apply_centered_margins(_margin, 980.0, 12)
	var vp_size := get_viewport().get_visible_rect().size
	_current_mode = AdaptiveLayout.detect_mode(vp_size)
	var is_comp := (_current_mode == AdaptiveLayout.LayoutMode.COMPACT_PORTRAIT)
	if _hud != null:
		_hud.set_compact_mode(is_comp)
	if _footer_spacer != null and _check_btn != null and _next_btn != null and _reset_btn != null:
		_footer_spacer.visible = not is_comp
		var flag: int = Control.SIZE_EXPAND_FILL if is_comp else Control.SIZE_SHRINK_END
		_check_btn.size_flags_horizontal = flag
		_next_btn.size_flags_horizontal = flag
		_reset_btn.custom_minimum_size = Vector2(92.0 if is_comp else 120.0, 50.0)
		_check_btn.custom_minimum_size = Vector2(140.0 if is_comp else 240.0, 50.0)
		_next_btn.custom_minimum_size = Vector2(140.0 if is_comp else 240.0, 50.0)
		_check_btn.icon = null if is_comp else UiTheme.get_icon_2x("play", 2)
		_next_btn.icon = null if is_comp else UiTheme.get_icon_2x("play", 2)
	_on_layout_mode_changed(_current_mode)


func _load_current_level() -> void:
	if _current_index >= _levels.size():
		_show_completion_summary()
		return
	var lv: Dictionary = _levels[_current_index]
	_attempts_on_level = 0
	_level_solved = false
	_level_started_unix = Time.get_unix_time_from_system()
	_mission_label.text = "Misi: " + str(lv.get("mission", ""))
	_hint_btn.visible = false
	_feedback_box.visible = false
	_check_btn.visible = true
	_check_btn.disabled = false
	_check_btn.text = "CEK JAWABAN"
	_reset_btn.visible = true
	_next_btn.visible = false
	_refresh_hud()
	_load_level(lv)
	_check_btn.grab_focus()


func _stage_number() -> int:
	var idx := GameSession.MG_IDS.find(minigame_id)
	return idx + 1 if idx >= 0 else 1


func _refresh_hud() -> void:
	var score_val: int = int(GameSession.mg_scores.get(minigame_id, 0))
	_hud.configure(_stage_number(), _current_index, _levels.size(), score_val)


func show_feedback(is_ok: bool, text: String) -> void:
	_feedback_box.visible = true
	UiTheme.style_feedback_panel(_feedback_box, "ok" if is_ok else "err")
	_feedback_label.add_theme_color_override("font_color", UiTheme.COL_SUCCESS if is_ok else UiTheme.COL_ERROR)
	_feedback_label.text = ("[OK] " if is_ok else "[ERR] ") + text
	if is_ok:
		UiTheme.pulse_control(_feedback_box, 0.96, 0.14)
	else:
		UiTheme.shake_control(_feedback_box, 8.0)


func show_info_feedback(text: String) -> void:
	_feedback_box.visible = true
	UiTheme.style_feedback_panel(_feedback_box, "info")
	_feedback_label.add_theme_color_override("font_color", UiTheme.COL_INFO)
	_feedback_label.text = "[INFO] " + text
	UiTheme.pulse_control(_feedback_box, 0.98, 0.12)


func submit_attempt(jawaban_siswa: String, kunci_jawaban: String, is_correct: bool, feedback_text: String) -> void:
	if _level_solved:
		return
	_attempts_on_level += 1
	var lv: Dictionary = _levels[_current_index]
	var lid: String = str(lv.get("id", ""))
	var dur: float = maxf(1.0, Time.get_unix_time_from_system() - _level_started_unix)

	var poin: int = 0
	if is_correct:
		var mistakes: int = maxi(0, _attempts_on_level - 1)
		poin = maxi(GameConfig.min_score_on_solve, 100 - mistakes * GameConfig.retry_penalty_per_mistake)

	var entry: Dictionary = GameSession.record_attempt(
		minigame_id,
		lid,
		str(lv.get("mission", "")),
		jawaban_siswa,
		kunci_jawaban,
		is_correct,
		_attempts_on_level,
		poin,
		dur
	)
	TelemetryService.send_level_log(entry)

	if is_correct:
		_level_solved = true
		AudioManager.play_success()
		show_feedback(true, "%s (Poin: +%d)" % [feedback_text, poin])
		_check_btn.visible = false
		_reset_btn.visible = false
		_next_btn.visible = true
		_next_btn.text = "LIHAT HASIL >" if _current_index >= _levels.size() - 1 else "LANJUT >"
		_next_btn.grab_focus()
		_refresh_hud()
	else:
		AudioManager.play_error()
		show_feedback(false, feedback_text)
		UiTheme.shake_control(_mission_panel, 6.0)
		if _attempts_on_level >= GameConfig.hint_after_mistakes:
			_hint_btn.visible = true
		if not GameConfig.allow_retry:
			_level_solved = true
			_check_btn.visible = false
			_reset_btn.visible = false
			_next_btn.visible = true
			_next_btn.grab_focus()


func _on_hint_pressed() -> void:
	AudioManager.play_click()
	if _current_index < _levels.size():
		var hint_txt: String = str(_levels[_current_index].get("hint", ""))
		show_info_feedback("Petunjuk Guru: " + hint_txt)


func _advance_level() -> void:
	_current_index += 1
	_load_current_level()


func _show_completion_summary() -> void:
	GameSession.mark_minigame_finished(minigame_id)
	TelemetryService.send_session_finish()
	AudioManager.play_stage_clear()

	for ch: Node in _completion_overlay.get_children():
		ch.queue_free()

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_completion_overlay.add_child(box)

	var h := Label.new()
	h.text = "STAGE %d SELESAI!" % _stage_number()
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiTheme.style_pixel_heading(h, 24, UiTheme.COL_GOLD_BRIGHT)
	box.add_child(h)

	var score_val: int = int(GameSession.mg_scores.get(minigame_id, 0))
	var stars_center := CenterContainer.new()
	box.add_child(stars_center)

	var star_row := UiTheme.make_star_row(score_val, true, 32)
	stars_center.add_child(star_row)

	var info := Label.new()
	info.text = "Skor Stage %d: %d / 100\nProgres tersimpan otomatis." % [_stage_number(), score_val]
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_theme_color_override("font_color", UiTheme.COL_TEXT_PRIMARY)
	box.add_child(info)

	var btn_hub := Button.new()
	btn_hub.text = "PILIH STAGE LAIN"
	UiTheme.style_gold_button(btn_hub, "play", true)
	btn_hub.pressed.connect(func() -> void:
		AudioManager.play_click()
		SceneRouter.go_to_hub()
	)
	box.add_child(btn_hub)

	var btn_lb := Button.new()
	btn_lb.text = "LIHAT PERINGKAT"
	UiTheme.style_blue_button(btn_lb, "trophy", true)
	btn_lb.pressed.connect(func() -> void:
		AudioManager.play_click()
		SceneRouter.open_leaderboard()
	)
	box.add_child(btn_lb)

	if GameSession.get_completed_minigame_count() >= GameSession.MG_IDS.size():
		var btn_rep := Button.new()
		btn_rep.text = "BUKA RAPOR AKHIR"
		UiTheme.style_blue_button(btn_rep, "report", true)
		btn_rep.pressed.connect(func() -> void:
			AudioManager.play_click()
			SceneRouter.go_to_report()
		)
		box.add_child(btn_rep)

	_completion_backdrop.visible = true
	UiTheme.pulse_control(_completion_overlay, 0.92, 0.18)
	var stars_lit := UiTheme.compute_star_count(score_val, true)
	for i: int in range(star_row.get_child_count()):
		if i < stars_lit:
			UiTheme.pop_star(star_row.get_child(i) as Control, 0.08 * float(i))
	btn_hub.grab_focus()


func _setup_content(_parent: VBoxContainer) -> void:
	pass


func _load_level(_level: Dictionary) -> void:
	pass


func _on_reset_level_pressed() -> void:
	_load_current_level()


func _on_submit_pressed() -> void:
	pass


func _on_layout_mode_changed(_mode: AdaptiveLayout.LayoutMode) -> void:
	pass


func _get_buku_saku_tab() -> String:
	return ""
