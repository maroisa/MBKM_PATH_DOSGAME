extends Control
## Layar 2: Peta Stage / Menu Utama Retro Pixel Art 128-bit (1 Top Bar, 1 Strip Info, 5 Kartu Stage).

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
var _top_box: BoxContainer
var _left_row: HBoxContainer
var _exit_btn: Button
var _identity_lbl: Label
var _nav_row: HBoxContainer
var _lb_btn: Button
var _book_btn: Button
var _rep_btn: Button
var _sfx_btn: Button

var _personal_rank_lbl: Label
var _personal_stats_lbl: Label
var _progress_bar: ProgressBar

var _stages_grid: GridContainer
var _stage5_slot: VBoxContainer
var _first_action_btn: Button = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.create_theme()
	_build_ui()
	TelemetryService.sync_status_changed.connect(_on_sync_changed)
	TelemetryService.leaderboard_updated.connect(_on_leaderboard_updated)
	AudioManager.mute_changed.connect(_on_mute_changed)
	get_viewport().size_changed.connect(_on_resized)
	_on_resized()
	_refresh_summary()
	TelemetryService.fetch_leaderboard()
	if _first_action_btn != null and is_instance_valid(_first_action_btn):
		_first_action_btn.grab_focus()


func _build_ui() -> void:
	add_child(UiTheme.make_tiled_background())

	_margin = MarginContainer.new()
	_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_margin)

	var win_v := VBoxContainer.new()
	win_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	win_v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	win_v.add_theme_constant_override("separation", 10)
	_margin.add_child(win_v)

	# 1 Top Bar Ringkas (tanpa duplikasi di bawah)
	var top_panel := PanelContainer.new()
	top_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTheme.style_header_panel(top_panel, 8.0)
	win_v.add_child(top_panel)

	_top_box = BoxContainer.new()
	_top_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_top_box.add_theme_constant_override("separation", 8)
	top_panel.add_child(_top_box)

	_left_row = HBoxContainer.new()
	_left_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_left_row.add_theme_constant_override("separation", 8)
	_top_box.add_child(_left_row)

	_exit_btn = Button.new()
	_exit_btn.text = "KELUAR"
	_exit_btn.tooltip_text = "Kembali ke layar masuk / ganti siswa"
	UiTheme.style_blue_button(_exit_btn, "back", true)
	_exit_btn.custom_minimum_size = Vector2(116.0, UiTheme.MIN_TAP_HEIGHT)
	_exit_btn.pressed.connect(func() -> void:
		AudioManager.play_click()
		SceneRouter.go_to_login()
	)
	_left_row.add_child(_exit_btn)

	_identity_lbl = Label.new()
	_identity_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_identity_lbl.custom_minimum_size = Vector2(80.0, 0.0)
	_identity_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_identity_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_identity_lbl.add_theme_font_size_override("font_size", 16)
	_identity_lbl.add_theme_color_override("font_color", UiTheme.COL_TEXT_PRIMARY)
	_left_row.add_child(_identity_lbl)

	_nav_row = HBoxContainer.new()
	_nav_row.add_theme_constant_override("separation", 6)
	_top_box.add_child(_nav_row)

	_lb_btn = Button.new()
	_lb_btn.text = "PERINGKAT"
	UiTheme.style_blue_button(_lb_btn, "trophy", false)
	_lb_btn.pressed.connect(func() -> void:
		AudioManager.play_click()
		SceneRouter.open_leaderboard()
	)
	_nav_row.add_child(_lb_btn)

	_book_btn = Button.new()
	_book_btn.text = "MATERI"
	UiTheme.style_blue_button(_book_btn, "book", false)
	_book_btn.pressed.connect(func() -> void:
		AudioManager.play_click()
		SceneRouter.open_buku_saku("")
	)
	_nav_row.add_child(_book_btn)

	_rep_btn = Button.new()
	_rep_btn.text = "RAPOR"
	UiTheme.style_blue_button(_rep_btn, "report", false)
	_rep_btn.pressed.connect(func() -> void:
		AudioManager.play_click()
		SceneRouter.go_to_report()
	)
	_nav_row.add_child(_rep_btn)

	_sfx_btn = Button.new()
	_sfx_btn.text = "SFX"
	_sfx_btn.tooltip_text = "Aktifkan atau matikan efek suara"
	UiTheme.style_blue_button(_sfx_btn, "sound_on", false)
	_sfx_btn.pressed.connect(func() -> void:
		AudioManager.toggle_mute()
		_refresh_sfx_btn()
	)
	_nav_row.add_child(_sfx_btn)
	_refresh_sfx_btn()

	# Konten utama dalam ScrollContainer vertikal (zero horizontal overflow)
	var scroll := TouchScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	win_v.add_child(scroll)

	var body_pad := MarginContainer.new()
	body_pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_pad.add_theme_constant_override("margin_right", 4)
	scroll.add_child(body_pad)

	var body_v := VBoxContainer.new()
	body_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_v.add_theme_constant_override("separation", 12)
	body_pad.add_child(body_v)

	# 1 Strip Info Mandiri Siswa (bingkai emas, bebas duplikasi tombol)
	var info_card := PanelContainer.new()
	info_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTheme.style_gold_panel(info_card, 14.0)
	body_v.add_child(info_card)

	var info_v := VBoxContainer.new()
	info_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_v.add_theme_constant_override("separation", 8)
	info_card.add_child(info_v)

	var rank_row := HBoxContainer.new()
	rank_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rank_row.add_theme_constant_override("separation", 10)
	info_v.add_child(rank_row)

	rank_row.add_child(UiTheme.make_icon_rect("trophy", 32))

	_personal_rank_lbl = Label.new()
	_personal_rank_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_personal_rank_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiTheme.style_parchment_heading(_personal_rank_lbl, 16, UiTheme.COL_INK_PRIMARY)
	rank_row.add_child(_personal_rank_lbl)

	_personal_stats_lbl = Label.new()
	_personal_stats_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_personal_stats_lbl.add_theme_font_size_override("font_size", 15)
	_personal_stats_lbl.add_theme_color_override("font_color", UiTheme.COL_INK_SECONDARY)
	info_v.add_child(_personal_stats_lbl)

	_progress_bar = ProgressBar.new()
	_progress_bar.mouse_filter = Control.MOUSE_FILTER_PASS
	_progress_bar.min_value = 0.0
	_progress_bar.max_value = 5.0
	_progress_bar.show_percentage = false
	_progress_bar.custom_minimum_size = Vector2(100.0, 20.0)
	_progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_v.add_child(_progress_bar)

	# 5 Kartu Stage Besar (STAGE 1 s.d. STAGE 5)
	_stages_grid = GridContainer.new()
	_stages_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stages_grid.add_theme_constant_override("h_separation", 12)
	_stages_grid.add_theme_constant_override("v_separation", 12)
	body_v.add_child(_stages_grid)

	_stage5_slot = VBoxContainer.new()
	_stage5_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_v.add_child(_stage5_slot)

	var metas: Array[Dictionary] = LevelsCatalog.get_minigames_meta()
	var next_highlighted: bool = false
	for i: int in range(metas.size()):
		var meta: Dictionary = metas[i]
		var mg_id: String = str(meta.get("id", ""))
		var done: bool = bool(GameSession.mg_completed.get(mg_id, false))
		var is_next: bool = (not done) and (not next_highlighted)
		if is_next:
			next_highlighted = true
		var card := _create_stage_card(meta, is_next)
		if i < 4:
			_stages_grid.add_child(card)
		else:
			_stage5_slot.add_child(card)


func _create_stage_card(meta: Dictionary, is_next: bool) -> PanelContainer:
	var mg_id: String = str(meta.get("id", ""))
	var done: bool = bool(GameSession.mg_completed.get(mg_id, false))
	var score_val: int = int(GameSession.mg_scores.get(mg_id, 0))
	var lv_done: int = int(GameSession.mg_levels_done.get(mg_id, 0))
	var lv_total: int = LevelsCatalog.get_levels(mg_id).size()

	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if is_next:
		UiTheme.style_gold_panel(card, 14.0)
	else:
		UiTheme.style_rpg_panel(card, 14.0)

	var root_v := VBoxContainer.new()
	root_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_v.add_theme_constant_override("separation", 10)
	card.add_child(root_v)

	# Baris atas kartu: Ikon Pixel 32x32 + Judul Stage + Materi
	var head_row := HBoxContainer.new()
	head_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head_row.add_theme_constant_override("separation", 12)
	root_v.add_child(head_row)

	var icon_box := PanelContainer.new()
	icon_box.custom_minimum_size = Vector2(48.0, 48.0)
	icon_box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	UiTheme.style_monitor_panel(icon_box, 6.0)
	head_row.add_child(icon_box)

	var ico_name: String = STAGE_ICONS.get(mg_id, "terminal")
	icon_box.add_child(UiTheme.make_icon_rect(ico_name, 32))

	var text_v := VBoxContainer.new()
	text_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_v.add_theme_constant_override("separation", 4)
	head_row.add_child(text_v)

	var title_lbl := Label.new()
	title_lbl.text = STAGE_LABELS.get(mg_id, str(meta.get("title", "")))
	title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var title_col: Color = UiTheme.COL_INK_ACCENT if is_next else (UiTheme.COL_INK_SUCCESS if done else UiTheme.COL_INK_PRIMARY)
	UiTheme.style_parchment_heading(title_lbl, 16, title_col)
	text_v.add_child(title_lbl)

	var topics_lbl := Label.new()
	topics_lbl.text = str(meta.get("topics", ""))
	topics_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	topics_lbl.add_theme_font_override("font", UiTheme.make_mono_font())
	topics_lbl.add_theme_font_size_override("font_size", 14)
	topics_lbl.add_theme_color_override("font_color", UiTheme.COL_INK_SECONDARY)
	text_v.add_child(topics_lbl)

	# Baris bawah kartu: Bintang & Skor + 1 Tombol Aksi Jelas
	var bottom_row := HBoxContainer.new()
	bottom_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_row.add_theme_constant_override("separation", 10)
	root_v.add_child(bottom_row)

	var stat_v := VBoxContainer.new()
	stat_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stat_v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stat_v.add_theme_constant_override("separation", 4)
	bottom_row.add_child(stat_v)

	stat_v.add_child(UiTheme.make_star_row(score_val, done, 24))

	var score_lbl := Label.new()
	var status_tag: String = "[SELESAI]" if done else ("[%d/%d]" % [lv_done, lv_total] if lv_done > 0 else "[BARU]")
	score_lbl.text = "Skor: %d/100  %s" % [score_val, status_tag]
	score_lbl.add_theme_font_size_override("font_size", 14)
	score_lbl.add_theme_color_override("font_color", UiTheme.COL_INK_SUCCESS if done else UiTheme.COL_INK_SECONDARY)
	stat_v.add_child(score_lbl)

	var play_btn := Button.new()
	play_btn.text = "ULANG" if done else "MAIN"
	play_btn.custom_minimum_size = Vector2(124.0, 50.0)
	if is_next:
		UiTheme.style_gold_button(play_btn, "play", true)
	else:
		UiTheme.style_blue_button(play_btn, "" if done else "play", true)
	play_btn.pressed.connect(func() -> void:
		AudioManager.play_click()
		SceneRouter.start_minigame(mg_id)
	)
	bottom_row.add_child(play_btn)

	if _first_action_btn == null and (is_next or mg_id == "mg1"):
		_first_action_btn = play_btn

	return card


func _refresh_summary() -> void:
	var shown_nama: String = GameSession.nama if not GameSession.nama.is_empty() else "Tamu"
	var shown_kelas: String = GameSession.kelas if not GameSession.kelas.is_empty() else "PPLG"
	_identity_lbl.text = "%s (%s)" % [shown_nama, shown_kelas]

	var done_cnt: int = GameSession.get_completed_minigame_count()
	_progress_bar.value = float(done_cnt)

	var local_avg: float = float(GameSession.get_total_score()) / 5.0
	var lb: Dictionary = TelemetryService.cached_leaderboard
	var my_info: Dictionary = lb.get("my_info", {}) as Dictionary
	var found: bool = bool(my_info.get("found", false)) and int(my_info.get("overall_rank", 0)) > 0

	if found:
		var o_rank: int = int(my_info.get("overall_rank", 0))
		var o_tot: int = int(my_info.get("overall_total", 0))
		var c_rank: int = int(my_info.get("class_rank", 0))
		var c_tot: int = int(my_info.get("class_total", 0))
		var s_avg: float = float(my_info.get("rata_rata", local_avg))
		if c_rank > 0 and c_tot > 0:
			_personal_rank_lbl.text = "Kamu rank %d dari %d Peserta (%s: #%d/%d)" % [o_rank, o_tot, shown_kelas, c_rank, c_tot]
		else:
			_personal_rank_lbl.text = "Kamu rank %d dari %d Peserta" % [o_rank, o_tot]
		_personal_stats_lbl.text = "Rata-rata: %.1f  |  Progres: %d/5 Stage" % [s_avg, done_cnt]
	else:
		_personal_rank_lbl.text = "Kamu rank - dari - Peserta"
		_personal_stats_lbl.text = "Rata-rata: %.1f  |  Progres: %d/5 Stage" % [local_avg, done_cnt]


func _refresh_sfx_btn() -> void:
	var ico_name: String = "sound_off" if AudioManager.muted else "sound_on"
	_sfx_btn.icon = UiTheme.get_icon_2x(ico_name, 2)
	var is_comp: bool = get_viewport() != null and AdaptiveLayout.is_compact(get_viewport().get_visible_rect().size)
	_sfx_btn.text = "" if is_comp else ("OFF" if AudioManager.muted else "SFX")


func _on_mute_changed(_is_muted: bool) -> void:
	if is_inside_tree():
		_refresh_sfx_btn()


func _on_sync_changed(_code: String, _msg: String) -> void:
	if is_inside_tree():
		_refresh_summary()


func _on_leaderboard_updated(_status: String, _data: Dictionary, _msg: String) -> void:
	if is_inside_tree():
		_refresh_summary()


func _on_resized() -> void:
	UiTheme.apply_centered_margins(_margin, 980.0, 14)
	var vp_size := get_viewport().get_visible_rect().size
	var is_comp: bool = AdaptiveLayout.is_compact(vp_size)
	var is_narrow_bar: bool = vp_size.x < 860.0

	if _top_box != null:
		_top_box.vertical = is_narrow_bar
	if _stages_grid != null:
		_stages_grid.columns = 1 if is_comp else 2

	if _sfx_btn != null and _left_row != null and _nav_row != null:
		var target_parent: Node = _left_row if is_comp else _nav_row
		if _sfx_btn.get_parent() != target_parent:
			_sfx_btn.reparent(target_parent)

	if _exit_btn != null:
		if is_comp:
			_exit_btn.text = ""
			_exit_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_exit_btn.custom_minimum_size = Vector2(52.0, UiTheme.MIN_TAP_HEIGHT)
		else:
			_exit_btn.text = "KELUAR"
			_exit_btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
			_exit_btn.custom_minimum_size = Vector2(116.0, UiTheme.MIN_TAP_HEIGHT)

	if _lb_btn != null and _book_btn != null and _rep_btn != null and _sfx_btn != null:
		if is_comp:
			_lb_btn.text = "RANK"
			_book_btn.text = "MATERI"
			_rep_btn.text = "RAPOR"
			for b: Button in [_lb_btn, _book_btn, _rep_btn]:
				b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				b.add_theme_font_size_override("font_size", 13)
				b.add_theme_constant_override("h_separation", 4)
				b.add_theme_stylebox_override("normal", UiTheme.make_9slice("btn_blue_normal.png", 8.0, 6.0, 8.0, 11.0))
				b.add_theme_stylebox_override("hover", UiTheme.make_9slice("btn_blue_hover.png", 8.0, 6.0, 8.0, 11.0))
				b.add_theme_stylebox_override("pressed", UiTheme.make_9slice("btn_blue_pressed.png", 8.0, 6.0, 11.0, 8.0))
				b.custom_minimum_size = Vector2(72.0, UiTheme.MIN_TAP_HEIGHT)
			_sfx_btn.custom_minimum_size = Vector2(52.0, UiTheme.MIN_TAP_HEIGHT)
			_sfx_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_sfx_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
		else:
			_lb_btn.text = "PERINGKAT"
			_book_btn.text = "MATERI"
			_rep_btn.text = "RAPOR"
			for b: Button in [_lb_btn, _book_btn, _rep_btn]:
				b.size_flags_horizontal = Control.SIZE_SHRINK_END
				b.add_theme_font_size_override("font_size", 14)
				b.add_theme_constant_override("h_separation", 8)
				b.add_theme_stylebox_override("normal", UiTheme.make_9slice("btn_blue_normal.png", 8.0, 12.0, 8.0, 11.0))
				b.add_theme_stylebox_override("hover", UiTheme.make_9slice("btn_blue_hover.png", 8.0, 12.0, 8.0, 11.0))
				b.add_theme_stylebox_override("pressed", UiTheme.make_9slice("btn_blue_pressed.png", 8.0, 12.0, 11.0, 8.0))
				b.custom_minimum_size = Vector2(104.0, UiTheme.MIN_TAP_HEIGHT)
			_sfx_btn.custom_minimum_size = Vector2(86.0, UiTheme.MIN_TAP_HEIGHT)
			_sfx_btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
			_sfx_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
		_refresh_sfx_btn()
