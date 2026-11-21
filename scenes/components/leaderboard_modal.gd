extends Control
## Modal Papan Peringkat Retro Pixel Art 128-bit (Top 10 Keseluruhan, PPLG A, PPLG B + Info Pribadi).

var _active_scope: String = "overall"
var _lb_data: Dictionary = {}
var _lb_status: String = "IDLE"
var _lb_message: String = ""

var _margin: MarginContainer
var _hdr_box: BoxContainer
var _scope_buttons: Dictionary[String, Button] = {}
var _personal_rank_lbl: Label
var _personal_detail_lbl: Label
var _status_lbl: Label
var _rows_vbox: VBoxContainer
var _close_btn: Button
var _refresh_btn: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.create_theme()
	_build_ui()
	TelemetryService.leaderboard_updated.connect(_on_leaderboard_updated)
	get_viewport().size_changed.connect(_on_resized)
	_on_resized()
	if not TelemetryService.cached_leaderboard.is_empty():
		_lb_data = TelemetryService.cached_leaderboard
		_lb_status = "LOADED"
		_render()
	TelemetryService.fetch_leaderboard()
	if is_instance_valid(_close_btn):
		_close_btn.grab_focus()


func _build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.06, 0.09, 0.11, 0.88)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	_margin = MarginContainer.new()
	_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_margin)

	var win := PanelContainer.new()
	win.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	win.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UiTheme.style_rpg_panel(win, 14.0)
	_margin.add_child(win)

	var root_v := VBoxContainer.new()
	root_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_v.add_theme_constant_override("separation", 10)
	win.add_child(root_v)

	# Header
	_hdr_box = BoxContainer.new()
	_hdr_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hdr_box.add_theme_constant_override("separation", 8)
	root_v.add_child(_hdr_box)

	var title_row := HBoxContainer.new()
	title_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_theme_constant_override("separation", 8)
	_hdr_box.add_child(title_row)

	title_row.add_child(UiTheme.make_icon_rect("trophy", 32))

	var title := Label.new()
	title.text = "PAPAN PERINGKAT"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiTheme.style_parchment_heading(title, 16, UiTheme.COL_INK_ACCENT)
	title_row.add_child(title)

	var hdr_btns := HBoxContainer.new()
	hdr_btns.add_theme_constant_override("separation", 8)
	_hdr_box.add_child(hdr_btns)

	_refresh_btn = Button.new()
	_refresh_btn.text = "MUAT ULANG"
	UiTheme.style_blue_button(_refresh_btn, "", true)
	_refresh_btn.custom_minimum_size = Vector2(118.0, UiTheme.MIN_TAP_HEIGHT)
	_refresh_btn.pressed.connect(func() -> void:
		AudioManager.play_click()
		TelemetryService.fetch_leaderboard()
	)
	hdr_btns.add_child(_refresh_btn)

	_close_btn = Button.new()
	_close_btn.text = "TUTUP"
	UiTheme.style_gold_button(_close_btn, "", true)
	_close_btn.custom_minimum_size = Vector2(96.0, UiTheme.MIN_TAP_HEIGHT)
	_close_btn.pressed.connect(func() -> void:
		AudioManager.play_click()
		SceneRouter.close_modal()
	)
	hdr_btns.add_child(_close_btn)

	# Panel Info Mandiri Siswa (bingkai emas)
	var personal_card := PanelContainer.new()
	personal_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTheme.style_gold_panel(personal_card, 12.0)
	root_v.add_child(personal_card)

	var pv := VBoxContainer.new()
	pv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pv.add_theme_constant_override("separation", 4)
	personal_card.add_child(pv)

	_personal_rank_lbl = Label.new()
	_personal_rank_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiTheme.style_parchment_heading(_personal_rank_lbl, 16, UiTheme.COL_INK_PRIMARY)
	pv.add_child(_personal_rank_lbl)

	_personal_detail_lbl = Label.new()
	_personal_detail_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_personal_detail_lbl.add_theme_font_size_override("font_size", 14)
	_personal_detail_lbl.add_theme_color_override("font_color", UiTheme.COL_INK_SECONDARY)
	pv.add_child(_personal_detail_lbl)

	# Filter tab sesuai kelas peserta: Keseluruhan 1-10 + kelas milik peserta saja (PPLG A atau PPLG B)
	var scope_flow := FlowContainer.new()
	scope_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scope_flow.add_theme_constant_override("h_separation", 8)
	scope_flow.add_theme_constant_override("v_separation", 6)
	root_v.add_child(scope_flow)

	var allowed_scopes: Array[Array] = [["overall", "Keseluruhan 1-10"]]
	var user_scope: String = _get_user_class_scope()
	if user_scope == "pplga":
		allowed_scopes.append(["pplga", "PPLG A"])
	elif user_scope == "pplgb":
		allowed_scopes.append(["pplgb", "PPLG B"])

	for pair: Array in allowed_scopes:
		var sid: String = str(pair[0])
		var sname: String = str(pair[1])
		var btn := Button.new()
		btn.text = sname
		UiTheme.style_chip_button(btn, sid == _active_scope)
		btn.pressed.connect(_on_scope_selected.bind(sid))
		scope_flow.add_child(btn)
		_scope_buttons[sid] = btn

	_status_lbl = Label.new()
	_status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_lbl.add_theme_font_size_override("font_size", 14)
	_status_lbl.add_theme_color_override("font_color", UiTheme.COL_INK_SECONDARY)
	root_v.add_child(_status_lbl)

	# Daftar Top 10
	var scroll := TouchScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_v.add_child(scroll)

	var pad_box := MarginContainer.new()
	pad_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad_box.add_theme_constant_override("margin_right", 6)
	scroll.add_child(pad_box)

	_rows_vbox = VBoxContainer.new()
	_rows_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows_vbox.add_theme_constant_override("separation", 6)
	pad_box.add_child(_rows_vbox)

	_render()


func _on_resized() -> void:
	if _margin == null or get_viewport() == null:
		return
	var vp_size := get_viewport().get_visible_rect().size
	var is_comp: bool = AdaptiveLayout.is_compact(vp_size)
	var pad_y: int = 10 if is_comp else 24
	var pad_x: int = 10 if is_comp else maxi(24, int((vp_size.x - 940.0) * 0.5))
	_margin.add_theme_constant_override("margin_left", pad_x)
	_margin.add_theme_constant_override("margin_right", pad_x)
	_margin.add_theme_constant_override("margin_top", pad_y)
	_margin.add_theme_constant_override("margin_bottom", pad_y)
	if _hdr_box != null:
		_hdr_box.vertical = is_comp


func _get_user_class_scope() -> String:
	if not GameSession.has_active_session():
		return ""
	var norm: String = GameSession.kelas.to_upper().replace(" ", "")
	if norm == "PPLGB":
		return "pplgb"
	if norm == "PPLGA":
		return "pplga"
	return ""


func _scope_class_label(scope_id: String) -> String:
	if scope_id == "pplgb":
		return "PPLG B"
	if scope_id == "pplga":
		return "PPLG A"
	return "Keseluruhan"


func _on_scope_selected(scope_id: String) -> void:
	if not _scope_buttons.has(scope_id):
		return
	AudioManager.play_click()
	_active_scope = scope_id
	_render()


func _on_leaderboard_updated(status: String, data: Dictionary, message: String) -> void:
	if not is_inside_tree():
		return
	_lb_status = status
	_lb_data = data
	_lb_message = message
	_render()


func _render() -> void:
	if not _scope_buttons.has(_active_scope):
		_active_scope = "overall"
	for sid: String in _scope_buttons.keys():
		UiTheme.style_chip_button(_scope_buttons[sid], sid == _active_scope)
	_render_personal_card()
	_render_top10_table()


func _render_personal_card() -> void:
	var my_info: Dictionary = _lb_data.get("my_info", {}) as Dictionary
	var local_avg: float = 0.0
	var done_mods: int = 0
	for mg_id: String in GameSession.MG_IDS:
		if int(GameSession.mg_levels_done.get(mg_id, 0)) > 0:
			local_avg += float(GameSession.mg_scores.get(mg_id, 0))
			done_mods += 1
	local_avg = local_avg / float(maxi(1, done_mods))

	var is_class_scope: bool = (_active_scope == "pplga" or _active_scope == "pplgb")
	var scope_label: String = _scope_class_label(_active_scope)

	if not GameSession.has_active_session():
		var total_all: int = int(_lb_data.get("total_overall", 0))
		var total_txt: String = str(total_all) if total_all > 0 else "-"
		_personal_rank_lbl.text = "Kamu rank - dari %s Peserta (Keseluruhan)" % total_txt
		_personal_detail_lbl.text = "Isi Nama, Kelas (PPLG A / B), dan Absen di layar masuk agar peringkat pribadimu tercatat."
		return

	var o_rank: int = int(my_info.get("overall_rank", 0))
	var o_total: int = int(my_info.get("overall_total", 0))
	var c_rank: int = int(my_info.get("class_rank", 0))
	var c_total: int = int(my_info.get("class_total", 0))
	var s_avg: float = float(my_info.get("rata_rata", local_avg))
	var found_overall: bool = bool(my_info.get("found", false)) and o_rank > 0
	var found_class: bool = bool(my_info.get("found", false)) and c_rank > 0

	if is_class_scope:
		if found_class:
			_personal_rank_lbl.text = "Kamu rank %d dari %d Peserta (%s)" % [c_rank, c_total, scope_label]
			_personal_detail_lbl.text = "%s (Absen %s) | Keseluruhan: rank %d dari %d | Rata-rata: %.2f" % [
				GameSession.nama,
				GameSession.absen,
				o_rank,
				o_total,
				s_avg
			]
		else:
			var cls_tot_key: String = "total_pplgb" if _active_scope == "pplgb" else "total_pplga"
			var cls_tot: int = int(_lb_data.get(cls_tot_key, 0))
			_personal_rank_lbl.text = "Kamu rank - dari %s Peserta (%s)" % [str(cls_tot) if cls_tot > 0 else "-", scope_label]
			_personal_detail_lbl.text = "%s (%s, Absen %s) | Rata-rata lokal: %.2f (%d/5 stage)." % [
				GameSession.nama,
				GameSession.kelas,
				GameSession.absen,
				local_avg,
				done_mods
			]
	else:
		if found_overall:
			_personal_rank_lbl.text = "Kamu rank %d dari %d Peserta (Keseluruhan)" % [o_rank, o_total]
			_personal_detail_lbl.text = "%s (Absen %s) | %s: rank %d dari %d | Rata-rata: %.2f" % [
				GameSession.nama,
				GameSession.absen,
				GameSession.kelas,
				c_rank,
				c_total,
				s_avg
			]
		else:
			var o_tot: int = int(_lb_data.get("total_overall", 0))
			_personal_rank_lbl.text = "Kamu rank - dari %s Peserta (Keseluruhan)" % (str(o_tot) if o_tot > 0 else "-")
			_personal_detail_lbl.text = "%s (%s, Absen %s) | Rata-rata lokal: %.2f (%d/5 stage)." % [
				GameSession.nama,
				GameSession.kelas,
				GameSession.absen,
				local_avg,
				done_mods
			]


func _render_top10_table() -> void:
	for ch: Node in _rows_vbox.get_children():
		ch.queue_free()

	if _lb_status == "LOADING":
		_status_lbl.text = "[INFO] Memuat papan peringkat terbaru dari Google Sheets..."
		_status_lbl.add_theme_color_override("font_color", UiTheme.COL_INK_INFO)
	elif _lb_status == "ERROR":
		_status_lbl.text = "[ERR] " + _lb_message
		_status_lbl.add_theme_color_override("font_color", UiTheme.COL_INK_ERROR)
	elif _lb_status == "NO_URL":
		_status_lbl.text = "[INFO] " + _lb_message
		_status_lbl.add_theme_color_override("font_color", UiTheme.COL_INK_INFO)
	elif _active_scope == "overall":
		_status_lbl.text = "Top 10 Peringkat Keseluruhan (PPLG A + PPLG B) berdasarkan rata-rata skor tertinggi."
		_status_lbl.add_theme_color_override("font_color", UiTheme.COL_INK_SECONDARY)
	else:
		_status_lbl.text = "Top 10 Peringkat Kelas %s berdasarkan rata-rata skor tertinggi." % _scope_class_label(_active_scope)
		_status_lbl.add_theme_color_override("font_color", UiTheme.COL_INK_SECONDARY)

	var key_map: Dictionary[String, String] = {
		"overall": "overall_top10",
		"pplga": "pplga_top10",
		"pplgb": "pplgb_top10",
	}
	var rows: Variant = _lb_data.get(key_map.get(_active_scope, "overall_top10"), [])
	if not (rows is Array) or (rows as Array).is_empty():
		var state_panel := PanelContainer.new()
		UiTheme.style_monitor_panel(state_panel, 14.0)
		_rows_vbox.add_child(state_panel)

		var state_lbl := Label.new()
		state_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if _lb_status == "NO_URL":
			state_lbl.add_theme_color_override("font_color", UiTheme.COL_INFO)
			state_lbl.text = "Mode Lokal Aktif: URL Google Apps Script belum diisi di data/game_config.json. Pasang URL Web App lalu tekan MUAT ULANG untuk menampilkan Top 10 kelas."
		elif _lb_status == "LOADING":
			state_lbl.add_theme_color_override("font_color", UiTheme.COL_TEXT_PRIMARY)
			state_lbl.text = "Sedang menghubungi Google Sheets untuk mengambil daftar peringkat 10 besar..."
		elif _lb_status == "ERROR":
			state_lbl.add_theme_color_override("font_color", UiTheme.COL_ERROR)
			state_lbl.text = "Koneksi papan peringkat gagal. Periksa internet lalu tekan tombol MUAT ULANG di atas."
		else:
			state_lbl.add_theme_color_override("font_color", UiTheme.COL_TEXT_SECONDARY)
			state_lbl.text = "Belum ada peserta pada kategori ini. Selesaikan minimal 1 stage lalu tekan MUAT ULANG."
		state_panel.add_child(state_lbl)
		return

	var mono := UiTheme.make_mono_font()
	for r: Variant in rows as Array:
		if not (r is Dictionary):
			continue
		var rd := r as Dictionary
		var r_rank: int = int(rd.get("rank", 0))
		var r_nama: String = str(rd.get("nama", ""))
		var r_kelas: String = str(rd.get("kelas", ""))
		var r_poin: float = float(rd.get("poin", 0.0))
		var is_me: bool = (
			GameSession.has_active_session()
			and r_nama.to_lower() == GameSession.nama.to_lower()
			and r_kelas.to_lower() == GameSession.kelas.to_lower()
		)

		var row_card := PanelContainer.new()
		row_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if is_me:
			UiTheme.style_gold_panel(row_card, 10.0)
		else:
			UiTheme.style_monitor_panel(row_card, 10.0)
		_rows_vbox.add_child(row_card)

		var hb := HBoxContainer.new()
		hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_theme_constant_override("separation", 10)
		row_card.add_child(hb)

		if r_rank == 1:
			hb.add_child(UiTheme.make_icon_rect("trophy", 24))
		elif r_rank <= 3:
			hb.add_child(UiTheme.make_icon_rect("star_on", 24))

		var rank_lbl := Label.new()
		rank_lbl.text = "#%d" % r_rank
		rank_lbl.custom_minimum_size = Vector2(40.0, 0.0)
		if is_me:
			UiTheme.style_parchment_heading(rank_lbl, 16, UiTheme.COL_INK_ACCENT)
		else:
			UiTheme.style_pixel_heading(rank_lbl, 16, UiTheme.COL_GOLD_BRIGHT if r_rank <= 3 else UiTheme.COL_INFO, true)
		hb.add_child(rank_lbl)

		var name_lbl := Label.new()
		name_lbl.text = "%s (%s)%s" % [r_nama, r_kelas, " [KAMU]" if is_me else ""]
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_lbl.add_theme_color_override("font_color", UiTheme.COL_INK_PRIMARY if is_me else UiTheme.COL_TEXT_PRIMARY)
		hb.add_child(name_lbl)

		var score_lbl := Label.new()
		score_lbl.text = "%.2f" % r_poin
		score_lbl.add_theme_font_override("font", mono)
		score_lbl.add_theme_font_size_override("font_size", 15)
		score_lbl.add_theme_color_override("font_color", UiTheme.COL_INK_SUCCESS if is_me else UiTheme.COL_SUCCESS)
		hb.add_child(score_lbl)
