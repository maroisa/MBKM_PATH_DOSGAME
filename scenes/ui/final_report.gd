extends Control
## Layar Rapor Akhir Retro Pixel Art 128-bit: Auto-Sync Google Sheets, Scorecard, Rekap Stage 1-5, & CSV.

const STAGE_ICONS: Dictionary[String, String] = {
	"mg1": "terminal",
	"mg2": "play",
	"mg3": "lock",
	"mg4": "folder",
	"mg5": "report",
}

const STAGE_LABELS: Dictionary[String, String] = {
	"mg1": "STAGE 1: Debugger Sintaks",
	"mg2": "STAGE 2: Rakit Flowchart",
	"mg3": "STAGE 3: Filter Wildcard",
	"mg4": "STAGE 4: Labirin Folder",
	"mg5": "STAGE 5: Studio Layar & .BAT",
}

var _margin: MarginContainer
var _back_btn: Button
var _new_btn: Button
var _sfx_btn: Button
var _summary_split: BoxContainer
var _summary_lbl: Label
var _rank_lbl: Label
var _avg_score_lbl: Label
var _avg_stars_slot: HBoxContainer
var _sync_status_lbl: Label
var _action_box: PanelContainer
var _action_msg_lbl: Label
var _scores_box: VBoxContainer
var _logs_box: VBoxContainer
var _csv_btn: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.create_theme()
	_build_ui()
	TelemetryService.sync_status_changed.connect(_on_sync_changed)
	TelemetryService.leaderboard_updated.connect(_on_leaderboard_updated)
	AudioManager.mute_changed.connect(_on_mute_changed)
	get_viewport().size_changed.connect(_on_resized)
	_on_resized()
	_populate_report()
	# Auto-kirim hasil terbaru ke Google Sheets saat Rapor dibuka (jika URL Web App valid).
	if GameSession.has_active_session() and GameConfig.has_valid_apps_script_url():
		TelemetryService.send_session_finish()
		TelemetryService.flush_pending_queue()
	TelemetryService.fetch_leaderboard()
	if _csv_btn != null:
		_csv_btn.grab_focus()


func _build_ui() -> void:
	add_child(UiTheme.make_tiled_background())

	_margin = MarginContainer.new()
	_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_margin)

	var main_v := VBoxContainer.new()
	main_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_v.add_theme_constant_override("separation", 10)
	_margin.add_child(main_v)

	# 1 Top Bar Ringkas dengan aksen rel emas
	var top_panel := PanelContainer.new()
	top_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTheme.style_header_panel(top_panel, 8.0)
	main_v.add_child(top_panel)

	var top_row := HBoxContainer.new()
	top_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_theme_constant_override("separation", 8)
	top_panel.add_child(top_row)

	_back_btn = Button.new()
	_back_btn.text = "MENU"
	_back_btn.tooltip_text = "Kembali ke Peta Stage"
	UiTheme.style_blue_button(_back_btn, "back", true)
	_back_btn.custom_minimum_size = Vector2(104.0, UiTheme.MIN_TAP_HEIGHT)
	_back_btn.pressed.connect(func() -> void:
		AudioManager.play_click()
		if GameSession.has_active_session():
			SceneRouter.go_to_hub()
		else:
			SceneRouter.go_to_login()
	)
	top_row.add_child(_back_btn)

	var hdr_lbl := Label.new()
	hdr_lbl.text = "RAPOR HASIL"
	hdr_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hdr_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiTheme.style_pixel_heading(hdr_lbl, 16, UiTheme.COL_GOLD_BRIGHT)
	top_row.add_child(hdr_lbl)

	_new_btn = Button.new()
	_new_btn.text = "SISWA BARU"
	UiTheme.style_blue_button(_new_btn, "", false)
	_new_btn.custom_minimum_size = Vector2(112.0, UiTheme.MIN_TAP_HEIGHT)
	_new_btn.pressed.connect(func() -> void:
		AudioManager.play_click()
		GameSession.clear_session()
		SceneRouter.go_to_login()
	)
	top_row.add_child(_new_btn)

	_sfx_btn = Button.new()
	_sfx_btn.text = ""
	_sfx_btn.tooltip_text = "Aktifkan atau matikan efek suara"
	UiTheme.style_blue_button(_sfx_btn, "sound_on", false)
	_sfx_btn.custom_minimum_size = Vector2(52.0, UiTheme.MIN_TAP_HEIGHT)
	_sfx_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sfx_btn.pressed.connect(func() -> void:
		AudioManager.toggle_mute()
		_refresh_sfx_icon()
	)
	top_row.add_child(_sfx_btn)
	_refresh_sfx_icon()

	# Konten Rapor
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_v.add_child(scroll)

	var inner_pad := MarginContainer.new()
	inner_pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner_pad.add_theme_constant_override("margin_right", 4)
	scroll.add_child(inner_pad)

	var inner_v := VBoxContainer.new()
	inner_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner_v.add_theme_constant_override("separation", 12)
	inner_pad.add_child(inner_v)

	# Panel Ringkasan & Scorecard Nilai Akhir (bingkai emas)
	var sum_card := PanelContainer.new()
	UiTheme.style_gold_panel(sum_card, 16.0)
	inner_v.add_child(sum_card)

	var sum_outer := VBoxContainer.new()
	sum_outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sum_outer.add_theme_constant_override("separation", 10)
	sum_card.add_child(sum_outer)

	_summary_split = BoxContainer.new()
	_summary_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_summary_split.add_theme_constant_override("separation", 14)
	sum_outer.add_child(_summary_split)

	var left_v := VBoxContainer.new()
	left_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_v.add_theme_constant_override("separation", 6)
	_summary_split.add_child(left_v)

	var rank_row := HBoxContainer.new()
	rank_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rank_row.add_theme_constant_override("separation", 10)
	left_v.add_child(rank_row)

	rank_row.add_child(UiTheme.make_icon_rect("trophy", 32))

	_rank_lbl = Label.new()
	_rank_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rank_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiTheme.style_pixel_heading(_rank_lbl, 16, UiTheme.COL_GOLD_BRIGHT)
	rank_row.add_child(_rank_lbl)

	_summary_lbl = Label.new()
	_summary_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary_lbl.add_theme_font_size_override("font_size", 15)
	_summary_lbl.add_theme_color_override("font_color", UiTheme.COL_TEXT_PRIMARY)
	left_v.add_child(_summary_lbl)

	_sync_status_lbl = Label.new()
	_sync_status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sync_status_lbl.add_theme_font_size_override("font_size", 14)
	_sync_status_lbl.add_theme_color_override("font_color", UiTheme.COL_INFO)
	left_v.add_child(_sync_status_lbl)

	# Blok Scorecard Nilai Rata-rata di kanan/bawah
	var score_box := PanelContainer.new()
	score_box.custom_minimum_size = Vector2(180.0, 92.0)
	score_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UiTheme.style_monitor_panel(score_box, 12.0)
	_summary_split.add_child(score_box)

	var sb_v := VBoxContainer.new()
	sb_v.alignment = BoxContainer.ALIGNMENT_CENTER
	sb_v.add_theme_constant_override("separation", 6)
	score_box.add_child(sb_v)

	var avg_cap := Label.new()
	avg_cap.text = "RATA-RATA"
	avg_cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	avg_cap.add_theme_font_size_override("font_size", 13)
	avg_cap.add_theme_color_override("font_color", UiTheme.COL_TEXT_SECONDARY)
	sb_v.add_child(avg_cap)

	_avg_score_lbl = Label.new()
	_avg_score_lbl.text = "0.0"
	_avg_score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiTheme.style_pixel_heading(_avg_score_lbl, 24, UiTheme.COL_SUCCESS)
	sb_v.add_child(_avg_score_lbl)

	var stars_c := CenterContainer.new()
	sb_v.add_child(stars_c)
	_avg_stars_slot = HBoxContainer.new()
	stars_c.add_child(_avg_stars_slot)

	var btn_flow := FlowContainer.new()
	btn_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_flow.add_theme_constant_override("h_separation", 10)
	btn_flow.add_theme_constant_override("v_separation", 8)
	sum_outer.add_child(btn_flow)

	var retry_sync_btn := Button.new()
	retry_sync_btn.text = "SINKRON SHEETS"
	UiTheme.style_blue_button(retry_sync_btn, "play", true)
	retry_sync_btn.custom_minimum_size = Vector2(168.0, 50.0)
	retry_sync_btn.pressed.connect(_on_retry_sync)
	btn_flow.add_child(retry_sync_btn)

	_csv_btn = Button.new()
	_csv_btn.text = "UNDUH CSV"
	UiTheme.style_gold_button(_csv_btn, "report", true)
	_csv_btn.custom_minimum_size = Vector2(156.0, 50.0)
	_csv_btn.pressed.connect(_on_export_csv)
	btn_flow.add_child(_csv_btn)

	_action_box = PanelContainer.new()
	_action_box.visible = false
	UiTheme.style_feedback_panel(_action_box, "info")
	sum_outer.add_child(_action_box)

	_action_msg_lbl = Label.new()
	_action_msg_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_action_msg_lbl.add_theme_color_override("font_color", UiTheme.COL_INFO)
	_action_box.add_child(_action_msg_lbl)

	# Rekap Skor Stage 1 - 5
	var sc_card := PanelContainer.new()
	UiTheme.style_rpg_panel(sc_card, 14.0)
	inner_v.add_child(sc_card)

	_scores_box = VBoxContainer.new()
	_scores_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scores_box.add_theme_constant_override("separation", 8)
	sc_card.add_child(_scores_box)

	# Log Jawaban Detail
	var log_card := PanelContainer.new()
	UiTheme.style_rpg_panel(log_card, 14.0)
	inner_v.add_child(log_card)

	_logs_box = VBoxContainer.new()
	_logs_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_logs_box.add_theme_constant_override("separation", 8)
	log_card.add_child(_logs_box)


func _populate_report() -> void:
	var my_info: Dictionary = TelemetryService.cached_leaderboard.get("my_info", {}) as Dictionary
	var found: bool = bool(my_info.get("found", false)) and int(my_info.get("overall_rank", 0)) > 0
	if found:
		_rank_lbl.text = "Kamu rank %d dari %d Peserta (%s: #%d/%d)" % [
			int(my_info.get("overall_rank", 0)),
			int(my_info.get("overall_total", 0)),
			GameSession.kelas,
			int(my_info.get("class_rank", 0)),
			int(my_info.get("class_total", 0))
		]
	else:
		_rank_lbl.text = "Kamu rank - dari - Peserta"

	var avg_val: float = float(GameSession.get_total_score()) / 5.0
	var done_cnt: int = GameSession.get_completed_minigame_count()
	_summary_lbl.text = (
		"Nama: %s | Kelas: %s | Absen: %s\n"
		+ "Progres: %d/5 Stage | Durasi: %d detik"
	) % [
		GameSession.nama if not GameSession.nama.is_empty() else "-",
		GameSession.kelas if not GameSession.kelas.is_empty() else "-",
		GameSession.absen if not GameSession.absen.is_empty() else "-",
		done_cnt,
		GameSession.get_elapsed_seconds()
	]
	_sync_status_lbl.text = "Sinkronisasi Sheets: " + TelemetryService.get_status_label()

	_avg_score_lbl.text = "%.1f" % avg_val
	for ch: Node in _avg_stars_slot.get_children():
		ch.queue_free()
	_avg_stars_slot.add_child(UiTheme.make_star_row(int(roundf(avg_val)), done_cnt > 0, 24))

	for ch: Node in _scores_box.get_children():
		ch.queue_free()
	var sh := Label.new()
	sh.text = "REKAP SKOR STAGE 1 - 5"
	UiTheme.style_pixel_heading(sh, 16, UiTheme.COL_GOLD_BRIGHT)
	_scores_box.add_child(sh)

	for meta: Dictionary in LevelsCatalog.get_minigames_meta():
		var mg_id: String = str(meta.get("id", ""))
		var done: bool = bool(GameSession.mg_completed.get(mg_id, false))
		var sc: int = int(GameSession.mg_scores.get(mg_id, 0))

		var row_card := PanelContainer.new()
		row_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UiTheme.style_monitor_panel(row_card, 10.0)
		_scores_box.add_child(row_card)

		var hb := HBoxContainer.new()
		hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_theme_constant_override("separation", 10)
		row_card.add_child(hb)

		hb.add_child(UiTheme.make_icon_rect(STAGE_ICONS.get(mg_id, "terminal"), 24))

		var name_lbl := Label.new()
		name_lbl.text = STAGE_LABELS.get(mg_id, str(meta.get("title", "")))
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_lbl.add_theme_color_override("font_color", UiTheme.COL_TEXT_PRIMARY)
		hb.add_child(name_lbl)

		hb.add_child(UiTheme.make_star_row(sc, done, 20))

		var sc_lbl := Label.new()
		sc_lbl.text = "%d/100" % sc
		sc_lbl.custom_minimum_size = Vector2(68.0, 0.0)
		sc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		sc_lbl.add_theme_font_override("font", UiTheme.make_mono_font())
		sc_lbl.add_theme_color_override("font_color", UiTheme.COL_SUCCESS if done else UiTheme.COL_TEXT_SECONDARY)
		hb.add_child(sc_lbl)

	for ch: Node in _logs_box.get_children():
		ch.queue_free()
	var lh := Label.new()
	lh.text = "LOG JAWABAN DETAIL"
	UiTheme.style_pixel_heading(lh, 16, UiTheme.COL_GOLD_BRIGHT)
	_logs_box.add_child(lh)

	if GameSession.attempt_logs.is_empty():
		var empty_panel := PanelContainer.new()
		UiTheme.style_monitor_panel(empty_panel, 12.0)
		_logs_box.add_child(empty_panel)

		var empty_lbl := Label.new()
		empty_lbl.text = "Belum ada riwayat jawaban tercatat. Kembali ke Menu dan selesaikan minimal 1 soal agar log muncul di sini."
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_lbl.add_theme_color_override("font_color", UiTheme.COL_TEXT_SECONDARY)
		empty_panel.add_child(empty_lbl)
		return

	var mono := UiTheme.make_mono_font()
	for i: int in range(GameSession.attempt_logs.size()):
		var entry: Dictionary = GameSession.attempt_logs[i]
		var is_ok: bool = str(entry.get("hasil", "")) == "BENAR"
		var p := PanelContainer.new()
		UiTheme.style_monitor_panel(p, 10.0)
		_logs_box.add_child(p)

		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_theme_constant_override("separation", 4)
		p.add_child(v)

		var tag_lbl := Label.new()
		tag_lbl.text = "#%d [%s] %s | Percobaan #%d | Poin: %d" % [
			i + 1,
			"OK" if is_ok else "ERR",
			str(entry.get("level_id", "")),
			int(entry.get("percobaan_ke", 1)),
			int(entry.get("poin", 0))
		]
		tag_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tag_lbl.add_theme_font_override("font", mono)
		tag_lbl.add_theme_font_size_override("font_size", 14)
		tag_lbl.add_theme_color_override("font_color", UiTheme.COL_SUCCESS if is_ok else UiTheme.COL_ERROR)
		v.add_child(tag_lbl)

		var body_lbl := Label.new()
		body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body_lbl.add_theme_font_override("font", mono)
		body_lbl.add_theme_font_size_override("font_size", 14)
		body_lbl.add_theme_color_override("font_color", UiTheme.COL_TEXT_PRIMARY)
		body_lbl.text = "Jawaban: %s\nKunci  : %s" % [
			str(entry.get("jawaban_siswa", "")),
			str(entry.get("kunci_jawaban", ""))
		]
		v.add_child(body_lbl)


func _refresh_sfx_icon() -> void:
	_sfx_btn.icon = UiTheme.get_icon_2x("sound_off" if AudioManager.muted else "sound_on", 2)


func _on_mute_changed(_is_muted: bool) -> void:
	if is_inside_tree():
		_refresh_sfx_icon()


func _on_retry_sync() -> void:
	AudioManager.play_click()
	TelemetryService.send_session_finish()
	TelemetryService.flush_pending_queue()
	var kind: String = "err" if GameConfig.is_spreadsheet_edit_url() else "info"
	_show_action_message(TelemetryService.last_message, kind)


func _on_export_csv() -> void:
	AudioManager.play_click()
	var msg: String = TelemetryService.export_csv_report()
	_show_action_message(msg, "ok")


func _show_action_message(msg: String, kind: String) -> void:
	_action_box.visible = true
	UiTheme.style_feedback_panel(_action_box, kind)
	var tc: Color = UiTheme.COL_SUCCESS if kind == "ok" else (UiTheme.COL_ERROR if kind == "err" else UiTheme.COL_INFO)
	var tag: String = "[OK] " if kind == "ok" else ("[ERR] " if kind == "err" else "[INFO] ")
	_action_msg_lbl.add_theme_color_override("font_color", tc)
	_action_msg_lbl.text = tag + msg
	UiTheme.pulse_control(_action_box, 0.97, 0.12)


func _on_sync_changed(code: String, msg: String) -> void:
	if is_inside_tree():
		_sync_status_lbl.text = "Sinkronisasi Sheets: " + TelemetryService.get_status_label()
		if code == "SYNCED":
			_show_action_message(msg, "ok")
		elif code == "INVALID_URL":
			_show_action_message(msg, "err")
		elif code == "OFFLINE_QUEUED":
			_show_action_message(msg, "info")


func _on_leaderboard_updated(_status: String, _data: Dictionary, _msg: String) -> void:
	if is_inside_tree():
		_populate_report()


func _on_resized() -> void:
	UiTheme.apply_centered_margins(_margin, 980.0, 14)
	var is_comp: bool = AdaptiveLayout.is_compact(get_viewport().get_visible_rect().size)
	if _summary_split != null:
		_summary_split.vertical = is_comp
	if _back_btn != null:
		if is_comp:
			_back_btn.text = ""
			_back_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_back_btn.custom_minimum_size = Vector2(52.0, UiTheme.MIN_TAP_HEIGHT)
		else:
			_back_btn.text = "MENU"
			_back_btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
			_back_btn.custom_minimum_size = Vector2(104.0, UiTheme.MIN_TAP_HEIGHT)
	if _new_btn != null:
		_new_btn.text = "BARU" if is_comp else "SISWA BARU"
		_new_btn.custom_minimum_size = Vector2(72.0 if is_comp else 112.0, UiTheme.MIN_TAP_HEIGHT)
