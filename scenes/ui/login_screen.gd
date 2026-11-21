extends Control
## Layar 1: Title & Login Retro Pixel Art Modern Stardew Valley (manual numeric Absen + 1 fokus utama + 2 tombol cepat).

var _margin: MarginContainer
var _center_pad: MarginContainer
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


func _build_ui() -> void:
	add_child(UiTheme.make_tiled_background())

	_margin = MarginContainer.new()
	_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_margin)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_margin.add_child(scroll)

	_center_pad = MarginContainer.new()
	_center_pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_center_pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(_center_pad)

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

	var nama_row := HBoxContainer.new()
	nama_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nama_row.add_theme_constant_override("separation", 8)
	form_v.add_child(nama_row)

	_nama_input = LineEdit.new()
	_nama_input.placeholder_text = "Ketik nama lengkapmu"
	_nama_input.custom_minimum_size = Vector2(160.0, UiTheme.MIN_TAP_HEIGHT)
	_nama_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_nama_input.text_submitted.connect(func(_t: String) -> void:
		if is_instance_valid(_absen_input):
			_absen_input.grab_focus()
	)
	nama_row.add_child(_nama_input)

	if OS.has_feature("web"):
		var web_prompt_btn := Button.new()
		web_prompt_btn.text = "Ketik HP"
		web_prompt_btn.tooltip_text = "Buka kotak ketik browser jika keyboard HP tidak muncul"
		UiTheme.style_blue_button(web_prompt_btn, "", false)
		web_prompt_btn.pressed.connect(_on_web_prompt_nama)
		nama_row.add_child(web_prompt_btn)

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

	var absen_row := HBoxContainer.new()
	absen_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	absen_row.add_theme_constant_override("separation", 8)
	form_v.add_child(absen_row)

	_absen_input = LineEdit.new()
	_absen_input.placeholder_text = "Contoh: 12"
	_absen_input.max_length = 2
	_absen_input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	_absen_input.custom_minimum_size = Vector2(130.0, UiTheme.MIN_TAP_HEIGHT)
	_absen_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_absen_input.text_changed.connect(_on_absen_text_changed)
	_absen_input.text_submitted.connect(func(_t: String) -> void:
		_on_start_pressed()
	)
	absen_row.add_child(_absen_input)

	if OS.has_feature("web"):
		var web_absen_btn := Button.new()
		web_absen_btn.text = "Ketik HP"
		web_absen_btn.tooltip_text = "Ketik nomor absen lewat dialog browser jika keyboard HP tidak muncul"
		UiTheme.style_blue_button(web_absen_btn, "", false)
		web_absen_btn.pressed.connect(_on_web_prompt_absen)
		absen_row.add_child(web_absen_btn)

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


func _on_resized() -> void:
	AdaptiveLayout.apply_safe_area_margin(_margin, 14)
	var vp_size := get_viewport().get_visible_rect().size
	if _center_pad != null:
		var side_pad := int(maxf(0.0, (vp_size.x - 540.0) * 0.5))
		_center_pad.add_theme_constant_override("margin_left", side_pad)
		_center_pad.add_theme_constant_override("margin_right", side_pad)
		_center_pad.add_theme_constant_override("margin_top", 8)
		_center_pad.add_theme_constant_override("margin_bottom", 8)


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


func _on_web_prompt_nama() -> void:
	if not OS.has_feature("web"):
		return
	var escaped: String = _nama_input.text.replace("'", "\\'")
	var res: Variant = JavaScriptBridge.eval("window.prompt('Masukkan Nama Lengkap Siswa:', '%s');" % escaped)
	if res != null:
		var s: String = str(res).strip_edges()
		if not s.is_empty():
			_nama_input.text = s


func _on_web_prompt_absen() -> void:
	if not OS.has_feature("web"):
		return
	var escaped: String = _absen_input.text.replace("'", "\\'")
	var res: Variant = JavaScriptBridge.eval("window.prompt('Masukkan Nomor Absen (1-99):', '%s');" % escaped)
	if res != null:
		var cleaned: String = _filter_digits(str(res).strip_edges()).substr(0, 2)
		if not cleaned.is_empty():
			_absen_input.text = cleaned


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
