extends Control
## Layar 1: Title & Login Retro Pixel Art Modern Stardew Valley
## (Dropdown siswa ter-style dari JSON roster PPLG A + validasi 1x percobaan langsung ke Google Sheets).

var _margin: MarginContainer
var _scroll: TouchScrollContainer
var _center_pad: MarginContainer
var _kb_spacer: Control
var _resume_panel: PanelContainer
var _resume_btn: Button
var _mode_banner_panel: PanelContainer
var _mode_banner_title_lbl: Label
var _mode_banner_sub_lbl: Label
var _book_btn: Button
var _last_fetched_mode: String = ""

var _selected_kelas: String = "PPLG A"
var _kelas_buttons: Dictionary[String, Button] = {}

# Mode Dropdown Roster (aktif otomatis jika kelas punya daftar di students_roster.json)
var _dropdown_section: VBoxContainer
var _student_dropdown_btn: Button
var _dropdown_arrow_lbl: Label
var _selected_meta_lbl: Label
var _selected_student: Dictionary = {}

# Mode Manual Fallback (aktif bila kelas belum memiliki roster di JSON, mis. PPLG B)
var _manual_section: VBoxContainer
var _nama_input: LineEdit
var _absen_input: LineEdit

# Overlay Dropdown Retro Pixel
var _dropdown_backdrop: ColorRect
var _dropdown_panel: PanelContainer
var _dropdown_title_lbl: Label
var _dropdown_search: LineEdit
var _dropdown_scroll: TouchScrollContainer
var _dropdown_list_vbox: VBoxContainer
var _dropdown_close_btn: Button
var _dropdown_open: bool = false

var _error_panel: PanelContainer
var _error_lbl: Label
var _start_btn: Button
var _status_footer_lbl: Label
var _is_verifying_login: bool = false

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
	TelemetryService.leaderboard_updated.connect(_on_leaderboard_updated)
	TelemetryService.student_check_completed.connect(_on_student_check_completed)
	GameConfig.roster_reloaded.connect(_on_roster_reloaded)
	GameConfig.exam_config_updated.connect(_on_exam_config_updated)
	get_viewport().size_changed.connect(_on_resized)
	_on_resized()
	_refresh_exam_mode_ui()
	_refresh_resume_state()
	_refresh_kelas_buttons()
	_refresh_identity_mode()
	if is_instance_valid(_start_btn):
		_start_btn.grab_focus()
	if DisplayServer.get_name() != "headless" and GameConfig.has_valid_apps_script_url():
		_last_fetched_mode = GameConfig.active_test_mode
		TelemetryService.fetch_remote_exam_config()
		TelemetryService.fetch_leaderboard()
	set_process(OS.has_feature("web") or DisplayServer.is_touchscreen_available())


func _exit_tree() -> void:
	if TelemetryService.sync_status_changed.is_connected(_on_sync_changed):
		TelemetryService.sync_status_changed.disconnect(_on_sync_changed)
	if TelemetryService.leaderboard_updated.is_connected(_on_leaderboard_updated):
		TelemetryService.leaderboard_updated.disconnect(_on_leaderboard_updated)
	if TelemetryService.student_check_completed.is_connected(_on_student_check_completed):
		TelemetryService.student_check_completed.disconnect(_on_student_check_completed)
	if GameConfig.roster_reloaded.is_connected(_on_roster_reloaded):
		GameConfig.roster_reloaded.disconnect(_on_roster_reloaded)
	if GameConfig.exam_config_updated.is_connected(_on_exam_config_updated):
		GameConfig.exam_config_updated.disconnect(_on_exam_config_updated)


func _unhandled_input(event: InputEvent) -> void:
	if _dropdown_open and event.is_action_pressed("ui_cancel"):
		_close_student_dropdown()
		get_viewport().set_input_as_handled()


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

	# Banner Mode Ujian Aktif (Pre-Test / Post-Test dikontrol Admin via Spreadsheet)
	_mode_banner_panel = PanelContainer.new()
	_mode_banner_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTheme.style_monitor_panel(_mode_banner_panel, 10.0)
	col.add_child(_mode_banner_panel)

	var mb_v := VBoxContainer.new()
	mb_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mb_v.add_theme_constant_override("separation", 3)
	_mode_banner_panel.add_child(mb_v)

	_mode_banner_title_lbl = Label.new()
	_mode_banner_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mode_banner_title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiTheme.style_pixel_heading(_mode_banner_title_lbl, 16, UiTheme.COL_GOLD_BRIGHT, true)
	mb_v.add_child(_mode_banner_title_lbl)

	_mode_banner_sub_lbl = Label.new()
	_mode_banner_sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mode_banner_sub_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mode_banner_sub_lbl.add_theme_font_size_override("font_size", 13)
	_mode_banner_sub_lbl.add_theme_color_override("font_color", UiTheme.COL_TEXT_SECONDARY)
	mb_v.add_child(_mode_banner_sub_lbl)

	# Banner Sesi Tersimpan (muncul hanya jika ada sesi aktif yang belum selesai)
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

	# Kartu Utama: Form Identitas Peserta
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

	# 1. Pilih Kelas terlebih dahulu agar daftar dropdown otomatis menyesuaikan kelas
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
		k_btn.custom_minimum_size = Vector2(96.0, 52.0)
		if UiTheme.get_pixel_font() != null:
			k_btn.add_theme_font_override("font", UiTheme.get_pixel_font())
			k_btn.add_theme_font_size_override("font_size", 16)
		k_btn.pressed.connect(_on_select_kelas.bind(cls_name))
		kelas_row.add_child(k_btn)
		_kelas_buttons[cls_name] = k_btn

	# 2A. Bagian Dropdown Roster Siswa (ber-style Retro Pixel untuk kelas dengan daftar JSON, mis. PPLG A)
	_dropdown_section = VBoxContainer.new()
	_dropdown_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dropdown_section.add_theme_constant_override("separation", 6)
	form_v.add_child(_dropdown_section)

	var dd_lbl := Label.new()
	dd_lbl.text = "Absen & Nama Siswa"
	dd_lbl.add_theme_color_override("font_color", UiTheme.COL_INK_SECONDARY)
	_dropdown_section.add_child(dd_lbl)

	var dd_wrap := Control.new()
	dd_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dd_wrap.custom_minimum_size = Vector2(180.0, 52.0)
	_dropdown_section.add_child(dd_wrap)

	_student_dropdown_btn = Button.new()
	_student_dropdown_btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_student_dropdown_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_student_dropdown_btn.clip_text = true
	_student_dropdown_btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_student_dropdown_btn.custom_minimum_size = Vector2(180.0, 52.0)
	_style_dropdown_trigger(_student_dropdown_btn, false)
	_student_dropdown_btn.pressed.connect(_open_student_dropdown)
	dd_wrap.add_child(_student_dropdown_btn)

	_dropdown_arrow_lbl = Label.new()
	_dropdown_arrow_lbl.text = "v"
	_dropdown_arrow_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dropdown_arrow_lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	_dropdown_arrow_lbl.offset_left = -36.0
	_dropdown_arrow_lbl.offset_right = -12.0
	_dropdown_arrow_lbl.offset_top = -12.0
	_dropdown_arrow_lbl.offset_bottom = 12.0
	_dropdown_arrow_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dropdown_arrow_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiTheme.style_pixel_heading(_dropdown_arrow_lbl, 14, UiTheme.COL_GOLD_BRIGHT, true)
	dd_wrap.add_child(_dropdown_arrow_lbl)

	_selected_meta_lbl = Label.new()
	_selected_meta_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_selected_meta_lbl.add_theme_font_override("font", UiTheme.make_mono_font())
	_selected_meta_lbl.add_theme_font_size_override("font_size", 13)
	_selected_meta_lbl.add_theme_color_override("font_color", UiTheme.COL_TEXT_SECONDARY)
	_dropdown_section.add_child(_selected_meta_lbl)

	# 2B. Bagian Input Manual Fallback (dipakai bila kelas belum ada daftar JSON, mis. PPLG B)
	_manual_section = VBoxContainer.new()
	_manual_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_manual_section.add_theme_constant_override("separation", 8)
	form_v.add_child(_manual_section)

	var nama_lbl := Label.new()
	nama_lbl.text = "Nama Lengkap"
	nama_lbl.add_theme_color_override("font_color", UiTheme.COL_INK_SECONDARY)
	_manual_section.add_child(nama_lbl)

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
	_manual_section.add_child(_nama_input)

	var absen_title := Label.new()
	absen_title.text = "Nomor Absen (1-99)"
	absen_title.add_theme_color_override("font_color", UiTheme.COL_INK_SECONDARY)
	_manual_section.add_child(absen_title)

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
	_manual_section.add_child(_absen_input)

	# Inline Error / Info Validasi
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

	# Tepat di bawah kartu: 2 tombol cepat [ PERINGKAT ] dan [ MATERI ]
	var quick_row := HBoxContainer.new()
	quick_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quick_row.add_theme_constant_override("separation", 10)
	col.add_child(quick_row)

	var lb_btn := Button.new()
	lb_btn.text = "PERINGKAT"
	lb_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTheme.style_blue_button(lb_btn, "trophy", true)
	lb_btn.custom_minimum_size = Vector2(110.0, 52.0)
	lb_btn.pressed.connect(func() -> void:
		AudioManager.play_click()
		SceneRouter.open_leaderboard()
	)
	quick_row.add_child(lb_btn)

	_book_btn = Button.new()
	_book_btn.text = "MATERI"
	_book_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTheme.style_blue_button(_book_btn, "book", true)
	_book_btn.custom_minimum_size = Vector2(110.0, 52.0)
	_book_btn.pressed.connect(func() -> void:
		AudioManager.play_click()
		SceneRouter.open_buku_saku("")
	)
	quick_row.add_child(_book_btn)

	# Catatan sinkronisasi ringkas di paling bawah
	_status_footer_lbl = Label.new()
	_status_footer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_footer_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_footer_lbl.add_theme_font_size_override("font_size", 13)
	_status_footer_lbl.add_theme_color_override("font_color", UiTheme.COL_TEXT_SECONDARY)
	_status_footer_lbl.text = "1 Siswa = 1x Percobaan (Validasi Spreadsheet) | " + TelemetryService.get_status_label()
	col.add_child(_status_footer_lbl)

	# Spacer dinamis di bawah form agar input naik di atas keyboard HP saat mengetik
	_kb_spacer = Control.new()
	_kb_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_kb_spacer.custom_minimum_size = Vector2.ZERO
	col.add_child(_kb_spacer)

	# Overlay Dropdown Retro Pixel (tampil di atas layar saat tombol dropdown diklik)
	_build_dropdown_overlay()


func _build_dropdown_overlay() -> void:
	_dropdown_backdrop = ColorRect.new()
	_dropdown_backdrop.color = Color(0.06, 0.08, 0.12, 0.86)
	_dropdown_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dropdown_backdrop.visible = false
	_dropdown_backdrop.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
			_close_student_dropdown()
		elif ev is InputEventScreenTouch and (ev as InputEventScreenTouch).pressed:
			_close_student_dropdown()
	)
	add_child(_dropdown_backdrop)

	var center_box := CenterContainer.new()
	center_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dropdown_backdrop.add_child(center_box)

	_dropdown_panel = PanelContainer.new()
	_dropdown_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	UiTheme.style_gold_panel(_dropdown_panel, 14.0)
	center_box.add_child(_dropdown_panel)

	var dd_v := VBoxContainer.new()
	dd_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dd_v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dd_v.add_theme_constant_override("separation", 10)
	_dropdown_panel.add_child(dd_v)

	var hdr := HBoxContainer.new()
	hdr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_theme_constant_override("separation", 8)
	dd_v.add_child(hdr)

	_dropdown_title_lbl = Label.new()
	_dropdown_title_lbl.text = "PILIH SISWA"
	_dropdown_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dropdown_title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_dropdown_title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiTheme.style_parchment_heading(_dropdown_title_lbl, 16, UiTheme.COL_GOLD_BRIGHT)
	hdr.add_child(_dropdown_title_lbl)

	_dropdown_close_btn = Button.new()
	_dropdown_close_btn.text = "TUTUP"
	UiTheme.style_gold_button(_dropdown_close_btn, "", true)
	_dropdown_close_btn.custom_minimum_size = Vector2(86.0, UiTheme.MIN_TAP_HEIGHT)
	_dropdown_close_btn.pressed.connect(_close_student_dropdown)
	hdr.add_child(_dropdown_close_btn)

	_dropdown_search = LineEdit.new()
	_dropdown_search.placeholder_text = "Cari nama atau nomor absen..."
	_dropdown_search.custom_minimum_size = Vector2(160.0, UiTheme.MIN_TAP_HEIGHT)
	_dropdown_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dropdown_search.text_changed.connect(func(q: String) -> void:
		_populate_dropdown_items(q)
	)
	dd_v.add_child(_dropdown_search)

	var list_well := PanelContainer.new()
	list_well.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_well.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UiTheme.style_monitor_panel(list_well, 8.0)
	dd_v.add_child(list_well)

	_dropdown_scroll = TouchScrollContainer.new()
	_dropdown_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dropdown_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dropdown_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_well.add_child(_dropdown_scroll)

	var list_pad := MarginContainer.new()
	list_pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_pad.add_theme_constant_override("margin_right", 6)
	_dropdown_scroll.add_child(list_pad)

	_dropdown_list_vbox = VBoxContainer.new()
	_dropdown_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dropdown_list_vbox.add_theme_constant_override("separation", 6)
	list_pad.add_child(_dropdown_list_vbox)


func _style_dropdown_trigger(btn: Button, selected: bool) -> void:
	var norm_sb := UiTheme.make_box(
		Color("#182238") if selected else UiTheme.COL_MONITOR_BG,
		UiTheme.COL_GOLD if selected else UiTheme.COL_PANEL_BEVEL_HI,
		2,
		0,
		10
	)
	norm_sb.content_margin_left = 14.0
	norm_sb.content_margin_right = 40.0
	var hov_sb := UiTheme.make_box(Color("#1D2A44"), UiTheme.COL_GOLD_BRIGHT, 2, 0, 10)
	hov_sb.content_margin_left = 14.0
	hov_sb.content_margin_right = 40.0
	var prs_sb := UiTheme.make_box(UiTheme.COL_BLUE_PRESSED, UiTheme.COL_GOLD_BRIGHT, 2, 0, 10)
	prs_sb.content_margin_left = 14.0
	prs_sb.content_margin_right = 40.0
	btn.add_theme_stylebox_override("normal", norm_sb)
	btn.add_theme_stylebox_override("hover", hov_sb)
	btn.add_theme_stylebox_override("pressed", prs_sb)
	btn.add_theme_stylebox_override("focus", UiTheme.make_focus_box())
	btn.add_theme_font_override("font", UiTheme.make_mono_font())
	btn.add_theme_font_size_override("font_size", 15)
	var tc: Color = UiTheme.COL_GOLD_BRIGHT if selected else UiTheme.COL_TEXT_SECONDARY
	btn.add_theme_color_override("font_color", tc)
	btn.add_theme_color_override("font_hover_color", UiTheme.COL_TEXT_PRIMARY)
	btn.add_theme_color_override("font_pressed_color", UiTheme.COL_GOLD_BRIGHT)
	btn.add_theme_color_override("font_focus_color", tc)
	UiTheme.attach_button_feel(btn)


func _refresh_identity_mode() -> void:
	var has_roster: bool = GameConfig.has_roster_for_class(_selected_kelas)
	if _dropdown_section != null:
		_dropdown_section.visible = has_roster
	if _manual_section != null:
		_manual_section.visible = not has_roster
	if has_roster:
		_update_dropdown_trigger_display()
	else:
		_selected_student.clear()


func _update_dropdown_trigger_display() -> void:
	if _student_dropdown_btn == null or _selected_meta_lbl == null:
		return
	if _selected_student.is_empty():
		_student_dropdown_btn.text = "-- Pilih Absen & Nama (%s) --" % _selected_kelas
		_style_dropdown_trigger(_student_dropdown_btn, false)
		var total_n: int = GameConfig.get_students_for_class(_selected_kelas).size()
		_selected_meta_lbl.text = "Tersedia %d siswa %s | 1 siswa = 1 kali percobaan." % [total_n, _selected_kelas]
		_selected_meta_lbl.add_theme_color_override("font_color", UiTheme.COL_TEXT_SECONDARY)
	else:
		var abs_n: int = int(_selected_student.get("absen", 0))
		var s_nama: String = str(_selected_student.get("nama", ""))
		var s_nis: String = str(_selected_student.get("nis", ""))
		_student_dropdown_btn.text = "%02d - %s" % [abs_n, s_nama]
		_style_dropdown_trigger(_student_dropdown_btn, true)
		var is_used: bool = TelemetryService.is_student_marked_used(_selected_kelas, s_nama, str(abs_n))
		if is_used:
			_selected_meta_lbl.text = "[TERPAKAI] Absen %02d | NIS %s — Sudah tercatat di Spreadsheet." % [abs_n, s_nis]
			_selected_meta_lbl.add_theme_color_override("font_color", UiTheme.COL_ERROR)
		else:
			_selected_meta_lbl.text = "Absen: %02d  |  NIS: %s  |  Kelas: %s" % [abs_n, s_nis, _selected_kelas]
			_selected_meta_lbl.add_theme_color_override("font_color", UiTheme.COL_INFO)


func _open_student_dropdown() -> void:
	if _is_verifying_login:
		return
	AudioManager.play_modal_open()
	_dropdown_open = true
	_dropdown_search.text = ""
	var roster: Array[Dictionary] = GameConfig.get_students_for_class(_selected_kelas)
	_dropdown_title_lbl.text = "PILIH SISWA — %s (%d)" % [_selected_kelas, roster.size()]
	_populate_dropdown_items("")
	_dropdown_backdrop.visible = true
	if _dropdown_arrow_lbl != null:
		_dropdown_arrow_lbl.text = "^"
	_update_dropdown_panel_size()
	UiTheme.pulse_control(_dropdown_panel, 0.94, 0.14)
	if is_instance_valid(_dropdown_close_btn):
		_dropdown_close_btn.grab_focus()


func _close_student_dropdown() -> void:
	if not _dropdown_open:
		return
	AudioManager.play_modal_close()
	_dropdown_open = false
	_dropdown_backdrop.visible = false
	if _dropdown_arrow_lbl != null:
		_dropdown_arrow_lbl.text = "v"
	if is_instance_valid(_student_dropdown_btn):
		_student_dropdown_btn.grab_focus()


func _populate_dropdown_items(query: String) -> void:
	for ch: Node in _dropdown_list_vbox.get_children():
		_dropdown_list_vbox.remove_child(ch)
		ch.queue_free()

	var q: String = query.strip_edges().to_lower()
	var roster: Array[Dictionary] = GameConfig.get_students_for_class(_selected_kelas)
	var mono := UiTheme.make_mono_font()
	var shown_count: int = 0
	var sel_absen: int = int(_selected_student.get("absen", -1))

	for st: Dictionary in roster:
		var abs_n: int = int(st.get("absen", 0))
		var s_nama: String = str(st.get("nama", ""))
		var s_nis: String = str(st.get("nis", ""))
		var abs_padded: String = "%02d" % abs_n
		if not q.is_empty():
			var hit: bool = s_nama.to_lower().contains(q) or str(abs_n).contains(q) or abs_padded.contains(q) or s_nis.contains(q)
			if not hit:
				continue
		shown_count += 1
		var is_sel: bool = (abs_n == sel_absen and not _selected_student.is_empty())
		var is_used: bool = TelemetryService.is_student_marked_used(_selected_kelas, s_nama, str(abs_n))

		var row_btn := Button.new()
		row_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row_btn.clip_text = true
		row_btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row_btn.custom_minimum_size = Vector2(140.0, UiTheme.MIN_TAP_HEIGHT)
		row_btn.add_theme_font_override("font", mono)
		row_btn.add_theme_font_size_override("font_size", 14)
		row_btn.text = "[%02d] %s%s" % [abs_n, s_nama, "  [TERPAKAI]" if is_used else ""]

		if is_sel:
			UiTheme.style_chip_button(row_btn, true)
		elif is_used:
			row_btn.add_theme_stylebox_override("normal", UiTheme.make_box(UiTheme.COL_ERROR_BG, UiTheme.COL_ERROR, 2, 0, 10))
			row_btn.add_theme_stylebox_override("hover", UiTheme.make_box(Color("#4E1C2D"), UiTheme.COL_ERROR, 2, 0, 10))
			row_btn.add_theme_stylebox_override("pressed", UiTheme.make_box(UiTheme.COL_ERROR_BG, UiTheme.COL_GOLD, 2, 0, 10))
			row_btn.add_theme_stylebox_override("focus", UiTheme.make_focus_box())
			row_btn.add_theme_color_override("font_color", UiTheme.COL_ERROR)
			row_btn.add_theme_color_override("font_hover_color", UiTheme.COL_WHITE)
			UiTheme.attach_button_feel(row_btn)
		else:
			UiTheme.style_chip_button(row_btn, false)

		row_btn.pressed.connect(_on_student_picked.bind(st))
		_dropdown_list_vbox.add_child(row_btn)

	if shown_count == 0:
		var empty_lbl := Label.new()
		empty_lbl.text = "Tidak ada siswa cocok dengan pencarian \"%s\"." % query.strip_edges()
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_color_override("font_color", UiTheme.COL_TEXT_SECONDARY)
		_dropdown_list_vbox.add_child(empty_lbl)


func _on_student_picked(student: Dictionary) -> void:
	_selected_student = student.duplicate()
	AudioManager.play_block_place()
	_dropdown_open = false
	_dropdown_backdrop.visible = false
	if _dropdown_arrow_lbl != null:
		_dropdown_arrow_lbl.text = "v"
	_error_panel.visible = false
	_update_dropdown_trigger_display()
	var s_nama: String = str(_selected_student.get("nama", ""))
	var s_absen: String = str(int(_selected_student.get("absen", 0)))
	if TelemetryService.is_student_marked_used(_selected_kelas, s_nama, s_absen):
		_show_error("Nama \"%s\" (Absen %s) sudah dipakai di Spreadsheet. Hubungi guru jika ingin mengulang." % [s_nama, s_absen])
	if is_instance_valid(_start_btn):
		_start_btn.grab_focus()


func select_student_by_absen(absen_num: int) -> bool:
	for st: Dictionary in GameConfig.get_students_for_class(_selected_kelas):
		if int(st.get("absen", 0)) == absen_num:
			_selected_student = st.duplicate()
			_update_dropdown_trigger_display()
			return true
	return false


func _update_dropdown_panel_size() -> void:
	if _dropdown_panel == null or get_viewport() == null:
		return
	var vp_size := get_viewport().get_visible_rect().size
	var panel_w: float = clampf(vp_size.x - 28.0, 280.0, 560.0)
	var panel_h: float = clampf(vp_size.y * 0.78, 280.0, 520.0)
	_dropdown_panel.custom_minimum_size = Vector2(panel_w, panel_h)


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
	_update_dropdown_panel_size()
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
		var zoom_f: float = maxf(0.5, SceneRouter.get_user_zoom())
		var web_kb: float = (float(raw_kb) / zoom_f) if raw_kb != null else 0.0
		if web_kb > 60.0:
			return web_kb
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
		_status_footer_lbl.text = "1 Siswa = 1x Percobaan (Validasi Spreadsheet) | " + TelemetryService.get_status_label()


func _on_leaderboard_updated(_status: String, _data: Dictionary, _msg: String) -> void:
	if not is_inside_tree():
		return
	if GameConfig.has_roster_for_class(_selected_kelas):
		_update_dropdown_trigger_display()
		if _dropdown_open:
			_populate_dropdown_items(_dropdown_search.text)


func _on_roster_reloaded() -> void:
	if not is_inside_tree():
		return
	_refresh_identity_mode()
	if _dropdown_open:
		_populate_dropdown_items(_dropdown_search.text)


func _on_exam_config_updated() -> void:
	if not is_inside_tree():
		return
	_refresh_exam_mode_ui()
	_refresh_resume_state()
	if GameConfig.has_roster_for_class(_selected_kelas):
		_update_dropdown_trigger_display()
		if _dropdown_open:
			_populate_dropdown_items(_dropdown_search.text)
	if DisplayServer.get_name() != "headless" and GameConfig.has_valid_apps_script_url():
		if _last_fetched_mode != GameConfig.active_test_mode:
			_last_fetched_mode = GameConfig.active_test_mode
			TelemetryService.fetch_leaderboard(true)


func _refresh_exam_mode_ui() -> void:
	var mode_lbl: String = GameConfig.get_mode_label()
	var is_post: bool = (GameConfig.active_test_mode == "POSTTEST")
	var revealed: bool = GameConfig.is_results_revealed_for()
	if _mode_banner_title_lbl != null:
		_mode_banner_title_lbl.text = "MODE AKTIF: %s" % mode_lbl
		_mode_banner_title_lbl.add_theme_color_override("font_color", UiTheme.COL_SUCCESS if is_post else UiTheme.COL_GOLD_BRIGHT)
	if _mode_banner_sub_lbl != null:
		if revealed:
			_mode_banner_sub_lbl.text = "1 Siswa = 1x Percobaan  |  Hasil & peringkat telah dibuka oleh Admin."
		else:
			_mode_banner_sub_lbl.text = "1 Siswa = 1x Percobaan  |  Nilai & peringkat disembunyikan sampai dibuka Admin."
	if _book_btn != null:
		_book_btn.visible = GameConfig.is_materi_allowed_for()


func _refresh_resume_state() -> void:
	if GameSession.has_active_session() and GameSession.test_mode == GameConfig.active_test_mode:
		var done_cnt: int = GameSession.get_completed_minigame_count()
		_resume_panel.visible = true
		_resume_btn.text = "LANJUTKAN %s: %s (%d/5)" % [GameConfig.get_mode_label(GameSession.test_mode), GameSession.nama, done_cnt]
	else:
		_resume_panel.visible = false


func _on_select_kelas(cls_name: String) -> void:
	if _is_verifying_login:
		return
	AudioManager.play_click()
	if _selected_kelas != cls_name:
		_selected_kelas = cls_name
		_selected_student.clear()
		_error_panel.visible = false
	_refresh_kelas_buttons()
	_refresh_identity_mode()


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
	if _is_verifying_login:
		return
	AudioManager.play_click()

	var nama_val: String = ""
	var absen_str: String = ""

	if GameConfig.has_roster_for_class(_selected_kelas):
		if _selected_student.is_empty():
			_show_error("Pilih Absen & Nama Siswa kelas %s dari dropdown terlebih dahulu." % _selected_kelas)
			if is_instance_valid(_student_dropdown_btn):
				_student_dropdown_btn.grab_focus()
			return
		nama_val = str(_selected_student.get("nama", "")).strip_edges()
		absen_str = str(int(_selected_student.get("absen", 0)))
	else:
		nama_val = _nama_input.text.strip_edges()
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
		absen_str = str(absen_num)

	# Validasi 1 siswa = 1 kali percobaan langsung ke Google Spreadsheets
	if GameConfig.has_valid_apps_script_url() and DisplayServer.get_name() != "headless":
		_is_verifying_login = true
		_start_btn.disabled = true
		_start_btn.text = "MEMERIKSA DATA..."
		_show_info("Memverifikasi nama di Spreadsheet...")
		TelemetryService.check_student_eligibility(nama_val, _selected_kelas, absen_str)
		return

	_begin_verified_session(nama_val, _selected_kelas, absen_str)


func _on_student_check_completed(allowed: bool, exists: bool, message: String, payload: Dictionary) -> void:
	if not is_inside_tree():
		return
	_is_verifying_login = false
	if is_instance_valid(_start_btn):
		_start_btn.disabled = false
		_start_btn.text = "MULAI MAIN"

	if not allowed:
		var err_txt: String = message
		if err_txt.is_empty():
			if exists:
				err_txt = "Nama \"%s\" (Absen %s) sudah dipakai dan tercatat di Spreadsheet. Hubungi guru jika ingin mengulang." % [
					str(payload.get("nama", "")),
					str(payload.get("absen", "")),
				]
			else:
				err_txt = "Gagal memverifikasi nama ke Spreadsheet. Periksa koneksi lalu coba lagi."
		_show_error(err_txt)
		_update_dropdown_trigger_display()
		return

	_begin_verified_session(
		str(payload.get("nama", "")),
		str(payload.get("kelas", _selected_kelas)),
		str(payload.get("absen", ""))
	)


func _begin_verified_session(nama_val: String, kelas_val: String, absen_str: String) -> void:
	_error_panel.visible = false
	GameSession.start_new_session(nama_val, kelas_val, absen_str, GameConfig.active_test_mode)
	TelemetryService.mark_student_used_locally(kelas_val, nama_val, absen_str)
	TelemetryService.send_session_start()
	SceneRouter.go_to_hub()


func _show_info(msg: String) -> void:
	UiTheme.style_feedback_panel(_error_panel, "info")
	_error_lbl.add_theme_color_override("font_color", UiTheme.COL_INFO)
	_error_lbl.text = "[INFO] " + msg
	_error_panel.visible = true


func _show_error(msg: String) -> void:
	AudioManager.play_error()
	UiTheme.style_feedback_panel(_error_panel, "err")
	_error_lbl.add_theme_color_override("font_color", UiTheme.COL_ERROR)
	_error_lbl.text = "[ERR] " + msg
	_error_panel.visible = true
	UiTheme.shake_control(_error_panel, 8.0)
