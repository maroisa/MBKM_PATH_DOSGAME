class_name BaseMinigame
extends Control
## Kelas induk modular untuk seluruh 5 minigame DOS/CMD (Retro Pixel Art 128-bit, 1-baris HUD, semat input).

@export var minigame_id: String = "mg1"

var _levels: Array[Dictionary] = []
var _current_index: int = 0
var _attempts_on_level: int = 0
var _level_solved: bool = false
var _level_started_unix: float = 0.0
var _level_elapsed_sec: float = 0.0
var _last_countdown_sec: int = 30
var _timeout_warned: bool = false
var _current_mode: AdaptiveLayout.LayoutMode = AdaptiveLayout.LayoutMode.WIDE_DESKTOP
var _input_pinned: bool = true

var _margin: MarginContainer
var _main_vbox: VBoxContainer
var _hud: HudBar
var _mission_panel: PanelContainer
var _mission_label: Label
var _feedback_box: PanelContainer
var _feedback_label: Label
var _scroll: ScrollContainer
var _content_root: VBoxContainer
var _output_root: VBoxContainer
var _unpinned_input_slot: VBoxContainer
var _input_root: VBoxContainer
var _pinned_input_panel: PanelContainer
var _pinned_input_scroll: TouchScrollContainer
var _pinned_input_slot: VBoxContainer
var _footer_panel: PanelContainer
var _footer_bar: HBoxContainer
var _footer_spacer: Control
var _pin_input_btn: Button
var _check_btn: Button
var _next_btn: Button
var _completion_backdrop: ColorRect
var _completion_overlay: PanelContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.create_theme()
	_levels = LevelsCatalog.get_levels(minigame_id)
	_current_index = _find_initial_level_index()
	_build_shell()
	_setup_content(_output_root)
	_setup_input(_input_root)
	set_input_pinned(true)
	GameConfig.exam_config_updated.connect(_on_exam_config_updated)
	get_viewport().size_changed.connect(_on_viewport_resized)
	_on_viewport_resized()
	_load_current_level()


func _exit_tree() -> void:
	if GameConfig.exam_config_updated.is_connected(_on_exam_config_updated):
		GameConfig.exam_config_updated.disconnect(_on_exam_config_updated)


func _on_exam_config_updated() -> void:
	if is_inside_tree():
		_refresh_hud()


func _find_initial_level_index() -> int:
	for i: int in range(_levels.size()):
		var lid: String = str(_levels[i].get("id", ""))
		if lid.is_empty() or (not GameSession.level_answered.has(lid) and not GameSession.level_best_scores.has(lid)):
			return i
	return _levels.size()


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

	# Area kerja tengah (Misi + Output di atas, Input di bawah dalam 1 ScrollContainer lega)
	_scroll = TouchScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.custom_minimum_size = Vector2(0.0, 120.0)
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
	_mission_label.add_theme_color_override("font_color", UiTheme.COL_INK_PRIMARY)
	m_top.add_child(_mission_label)

	_feedback_box = PanelContainer.new()
	_feedback_box.visible = false
	_feedback_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m_vbox.add_child(_feedback_box)

	_feedback_label = Label.new()
	_feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feedback_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_feedback_box.add_child(_feedback_label)

	# Area Output (selalu di atas input)
	_output_root = VBoxContainer.new()
	_output_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_output_root.add_theme_constant_override("separation", 10)
	_content_root.add_child(_output_root)

	# Slot Input di dalam ScrollContainer (saat tidak disematkan)
	_unpinned_input_slot = VBoxContainer.new()
	_unpinned_input_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_unpinned_input_slot.add_theme_constant_override("separation", 8)
	_content_root.add_child(_unpinned_input_slot)

	_input_root = VBoxContainer.new()
	_input_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input_root.add_theme_constant_override("separation", 8)
	_unpinned_input_slot.add_child(_input_root)

	# Dock Input Sticky (selalu diam di atas footer saat scroll game)
	_pinned_input_panel = PanelContainer.new()
	_pinned_input_panel.visible = false
	_pinned_input_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sticky_sb := StyleBoxFlat.new()
	sticky_sb.bg_color = Color(0.08, 0.09, 0.16, 0.96)
	sticky_sb.border_color = UiTheme.COL_GOLD
	sticky_sb.border_width_top = 2
	sticky_sb.border_width_left = 0
	sticky_sb.border_width_right = 0
	sticky_sb.border_width_bottom = 0
	sticky_sb.content_margin_top = 6.0
	sticky_sb.content_margin_bottom = 2.0
	sticky_sb.content_margin_left = 0.0
	sticky_sb.content_margin_right = 0.0
	_pinned_input_panel.add_theme_stylebox_override("panel", sticky_sb)
	_main_vbox.add_child(_pinned_input_panel)

	_pinned_input_scroll = TouchScrollContainer.new()
	_pinned_input_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pinned_input_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_pinned_input_panel.add_child(_pinned_input_scroll)

	var pin_pad := MarginContainer.new()
	pin_pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pin_pad.add_theme_constant_override("margin_right", 4)
	_pinned_input_scroll.add_child(pin_pad)

	_pinned_input_slot = VBoxContainer.new()
	_pinned_input_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pinned_input_slot.add_theme_constant_override("separation", 8)
	pin_pad.add_child(_pinned_input_slot)

	# Baris Bawah: Dock Aksi Sticky ([ KIRIM JAWABAN ] / [ LANJUT > ])
	_footer_panel = PanelContainer.new()
	_footer_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTheme.style_rpg_panel(_footer_panel, 10.0)
	_main_vbox.add_child(_footer_panel)

	_footer_bar = HBoxContainer.new()
	_footer_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_footer_bar.add_theme_constant_override("separation", 10)
	_footer_panel.add_child(_footer_bar)

	_pin_input_btn = Button.new()
	_pin_input_btn.visible = false
	_pin_input_btn.text = "TERSEMAT"
	_footer_bar.add_child(_pin_input_btn)

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
	_completion_backdrop.color = Color(0.06, 0.09, 0.11, 0.88)
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


func is_input_pinned() -> bool:
	return _input_pinned


func set_input_pinned(pinned: bool) -> void:
	if _input_root == null or _pinned_input_slot == null or _unpinned_input_slot == null:
		return
	_input_pinned = pinned
	var target_parent: Node = _pinned_input_slot if _input_pinned else _unpinned_input_slot
	if _input_root.get_parent() != target_parent:
		_input_root.reparent(target_parent, false)
	_unpinned_input_slot.visible = not _input_pinned
	_pinned_input_panel.visible = _input_pinned and _input_root.get_child_count() > 0
	_refresh_pin_button_ui()
	call_deferred("_update_pinned_dock_height")


func refresh_pinned_layout() -> void:
	if _input_pinned:
		call_deferred("_update_pinned_dock_height")


func _update_pinned_dock_height() -> void:
	if not is_inside_tree() or _pinned_input_panel == null or _pinned_input_scroll == null or _input_root == null:
		return
	if not _input_pinned:
		_pinned_input_panel.visible = false
		return
	_pinned_input_panel.visible = _input_root.get_child_count() > 0
	if not _pinned_input_panel.visible:
		return
	var vp := get_viewport()
	var vp_h: float = vp.get_visible_rect().size.y if vp != null else 720.0
	var max_dock_h: float = clampf(vp_h * 0.32, 96.0, 230.0) if vp_h < 700.0 else clampf(vp_h * 0.38, 110.0, 280.0)
	var needed_h: float = _input_root.get_combined_minimum_size().y + 4.0
	_pinned_input_scroll.custom_minimum_size = Vector2(0.0, clampf(needed_h, 76.0, max_dock_h))


func _refresh_pin_button_ui() -> void:
	if _pin_input_btn != null:
		# Area input sekarang selalu sticky otomatis di atas footer
		_pin_input_btn.visible = false


func _on_viewport_resized() -> void:
	UiTheme.apply_centered_margins(_margin, 980.0, 12)
	var vp_size := get_viewport().get_visible_rect().size
	_current_mode = AdaptiveLayout.detect_mode(vp_size)
	var is_comp := (_current_mode == AdaptiveLayout.LayoutMode.COMPACT_PORTRAIT)
	if _hud != null:
		_hud.set_compact_mode(is_comp)
	if _footer_spacer != null and _check_btn != null and _next_btn != null and _pin_input_btn != null:
		_footer_spacer.visible = not is_comp
		var flag: int = Control.SIZE_EXPAND_FILL if is_comp else Control.SIZE_SHRINK_END
		_check_btn.size_flags_horizontal = flag
		_next_btn.size_flags_horizontal = flag
		_pin_input_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		_check_btn.custom_minimum_size = Vector2(140.0 if is_comp else 240.0, 50.0)
		_next_btn.custom_minimum_size = Vector2(140.0 if is_comp else 240.0, 50.0)
		_check_btn.icon = null if is_comp else UiTheme.get_icon_2x("play", 2)
		_next_btn.icon = null if is_comp else UiTheme.get_icon_2x("play", 2)
		_refresh_pin_button_ui()
	_on_layout_mode_changed(_current_mode)
	call_deferred("_update_pinned_dock_height")


func _process(delta: float) -> void:
	if _level_solved or _current_index >= _levels.size():
		return
	_level_elapsed_sec += delta


static func compute_level_score(
	elapsed_sec: float,
	mistakes: int,
	retry_penalty: int,
	min_score: int,
	max_time_sec: float = 0.0,
	grace_sec: float = 0.0
) -> Dictionary:
	var safe_elapsed: float = maxf(0.0, elapsed_sec)
	var safe_min: int = clampi(min_score, 10, 100)
	var is_overtime: bool = false
	var time_pen: int = 0

	if max_time_sec > 0.0:
		var safe_limit: float = maxf(10.0, max_time_sec)
		var safe_grace: float = clampf(grace_sec, 0.0, safe_limit)
		is_overtime = safe_elapsed > safe_limit
		if safe_elapsed > safe_grace:
			var within_limit_over: float = minf(safe_elapsed, safe_limit) - safe_grace
			time_pen += int(floorf(within_limit_over / 2.0)) * 5
			if is_overtime:
				var overtime_sec: float = safe_elapsed - safe_limit
				time_pen += (1 + int(floorf(overtime_sec / 3.0))) * 5

	var mistake_pen: int = maxi(0, mistakes) * maxi(0, retry_penalty)
	var raw_poin: int = 100 - time_pen - mistake_pen
	var final_poin: int = maxi(safe_min, raw_poin)
	return {
		"poin": final_poin,
		"time_penalty": time_pen,
		"mistake_penalty": mistake_pen,
		"is_overtime": is_overtime,
	}


func _load_current_level() -> void:
	if _current_index >= _levels.size():
		set_process(false)
		_show_completion_summary()
		return
	var lv: Dictionary = _levels[_current_index]
	_attempts_on_level = 0
	_level_solved = false
	_level_started_unix = Time.get_unix_time_from_system()
	_level_elapsed_sec = 0.0
	_last_countdown_sec = 0
	_timeout_warned = false
	_mission_label.text = "Misi: " + str(lv.get("mission", ""))
	_feedback_box.visible = false
	_check_btn.visible = true
	_check_btn.disabled = false
	_check_btn.text = "KIRIM JAWABAN" if GameConfig.exam_blind_mode else "CEK JAWABAN"
	_next_btn.visible = false
	_refresh_hud()
	_load_level(lv)
	_refresh_pin_button_ui()
	call_deferred("_update_pinned_dock_height")
	set_process(true)
	_check_btn.grab_focus()


func _stage_number() -> int:
	var idx := GameSession.MG_IDS.find(minigame_id)
	return idx + 1 if idx >= 0 else 1


func _refresh_hud() -> void:
	var score_val: int = int(GameSession.mg_scores.get(minigame_id, 0))
	var show_score: bool = GameConfig.is_results_revealed_for(GameSession.test_mode)
	var mode_lbl: String = GameConfig.get_mode_label(GameSession.test_mode)
	var show_materi: bool = GameConfig.is_materi_allowed_for(GameSession.test_mode)
	_hud.configure(_stage_number(), _current_index, _levels.size(), score_val, show_score, mode_lbl, show_materi)


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
	var dur: float = maxf(1.0, maxf(_level_elapsed_sec, Time.get_unix_time_from_system() - _level_started_unix))
	var elapsed_for_score: float = maxf(_level_elapsed_sec, Time.get_unix_time_from_system() - _level_started_unix)

	var poin: int = 0
	var time_pen: int = 0
	var mistake_pen: int = 0
	if is_correct:
		var mistakes: int = maxi(0, _attempts_on_level - 1)
		var sc_info: Dictionary = compute_level_score(
			elapsed_for_score,
			mistakes,
			GameConfig.retry_penalty_per_mistake,
			GameConfig.min_score_on_solve,
			GameConfig.level_time_limit_sec,
			GameConfig.time_grace_sec
		)
		poin = int(sc_info.get("poin", GameConfig.min_score_on_solve))
		time_pen = int(sc_info.get("time_penalty", 0))
		mistake_pen = int(sc_info.get("mistake_penalty", 0))

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

	if GameConfig.exam_blind_mode:
		_level_solved = true
		set_process(false)
		AudioManager.play_block_place()
		show_info_feedback("Jawaban tersimpan! Tekan LANJUT untuk melanjutkan ke soal berikutnya.")
		_check_btn.visible = false
		_next_btn.visible = true
		_next_btn.text = "SELESAI STAGE >" if _current_index >= _levels.size() - 1 else "LANJUT >"
		_next_btn.grab_focus()
		_refresh_hud()
		return

	if is_correct:
		_level_solved = true
		set_process(false)
		AudioManager.play_success()
		var detail_parts: Array[String] = ["Poin: +%d" % poin, "Waktu: %ds" % int(roundf(dur))]
		if time_pen > 0:
			detail_parts.append("Penalti waktu: -%d" % time_pen)
		if mistake_pen > 0:
			detail_parts.append("Penalti salah: -%d" % mistake_pen)
		show_feedback(true, "%s (%s)" % [feedback_text, " | ".join(detail_parts)])
		_check_btn.visible = false
		_next_btn.visible = true
		_next_btn.text = "LIHAT HASIL >" if _current_index >= _levels.size() - 1 else "LANJUT >"
		_next_btn.grab_focus()
		_refresh_hud()
	else:
		AudioManager.play_error()
		show_feedback(false, feedback_text)
		UiTheme.shake_control(_mission_panel, 6.0)
		if not GameConfig.allow_retry:
			_level_solved = true
			set_process(false)
			_check_btn.visible = false
			_next_btn.visible = true
			_next_btn.grab_focus()


func _advance_level() -> void:
	_current_index += 1
	_load_current_level()


func _show_completion_summary() -> void:
	GameSession.mark_minigame_finished(minigame_id)
	TelemetryService.sync_session_now(true)
	AudioManager.play_stage_clear()

	for ch: Node in _completion_overlay.get_children():
		ch.queue_free()

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_completion_overlay.add_child(box)

	var h := Label.new()
	h.text = "STAGE %d SELESAI!" % _stage_number()
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiTheme.style_parchment_heading(h, 24, UiTheme.COL_INK_ACCENT)
	box.add_child(h)

	var revealed: bool = GameConfig.is_results_revealed_for(GameSession.test_mode)
	var mode_lbl: String = GameConfig.get_mode_label(GameSession.test_mode)
	var score_val: int = int(GameSession.mg_scores.get(minigame_id, 0))
	var star_row: HBoxContainer = null

	if revealed:
		var stars_center := CenterContainer.new()
		box.add_child(stars_center)

		star_row = UiTheme.make_star_row(score_val, true, 32)
		stars_center.add_child(star_row)

		var info := Label.new()
		info.text = "Skor Stage %d: %d / 100\nProgres tersimpan otomatis." % [_stage_number(), score_val]
		info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_theme_color_override("font_color", UiTheme.COL_INK_PRIMARY)
		box.add_child(info)
	else:
		var lock_center := CenterContainer.new()
		box.add_child(lock_center)
		lock_center.add_child(UiTheme.make_icon_rect("lock", 36))

		var info := Label.new()
		info.text = "Jawaban %s untuk Stage %d sudah tersimpan otomatis.\nNilai dan peringkat disembunyikan sampai dibuka oleh Admin." % [mode_lbl, _stage_number()]
		info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_theme_color_override("font_color", UiTheme.COL_INK_PRIMARY)
		box.add_child(info)

	var sync_lbl := Label.new()
	sync_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sync_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sync_lbl.add_theme_font_size_override("font_size", 13)
	sync_lbl.add_theme_color_override("font_color", UiTheme.COL_INK_INFO)
	sync_lbl.text = TelemetryService.get_status_label()
	box.add_child(sync_lbl)

	var btn_hub := Button.new()
	btn_hub.text = "PILIH STAGE LAIN"
	UiTheme.style_gold_button(btn_hub, "play", true)
	btn_hub.pressed.connect(func() -> void:
		AudioManager.play_click()
		SceneRouter.go_to_hub()
	)
	box.add_child(btn_hub)

	if revealed:
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
		btn_rep.text = "BUKA RAPOR AKHIR" if revealed else "STATUS PENGUMPULAN"
		UiTheme.style_blue_button(btn_rep, "report", true)
		btn_rep.pressed.connect(func() -> void:
			AudioManager.play_click()
			SceneRouter.go_to_report()
		)
		box.add_child(btn_rep)

	_completion_backdrop.visible = true
	if _margin != null:
		_margin.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
	UiTheme.pulse_control(_completion_overlay, 0.92, 0.18)
	if revealed and star_row != null:
		var stars_lit := UiTheme.compute_star_count(score_val, true)
		for i: int in range(star_row.get_child_count()):
			if i < stars_lit:
				UiTheme.pop_star(star_row.get_child(i) as Control, 0.10 * float(i))
				if DisplayServer.get_name() != "headless":
					get_tree().create_timer(0.10 * float(i), true, false, true).timeout.connect(func() -> void:
						AudioManager.play_star_pop(i)
					)
	btn_hub.grab_focus()


func _setup_content(_parent: VBoxContainer) -> void:
	pass


func _setup_input(_parent: VBoxContainer) -> void:
	pass


func _load_level(_level: Dictionary) -> void:
	pass


func _on_submit_pressed() -> void:
	pass


func _on_layout_mode_changed(_mode: AdaptiveLayout.LayoutMode) -> void:
	pass


func _get_buku_saku_tab() -> String:
	return ""
