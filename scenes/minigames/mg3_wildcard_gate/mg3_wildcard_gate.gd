extends BaseMinigame
## Stage 3: Filter Wildcard (GATE_LOCK.EXE) - Puzzle analisis pola wildcard * dan ?.

var _crt_card: PanelContainer
var _header_lbl: Label
var _lists_split: BoxContainer
var _allow_vbox: VBoxContainer
var _deny_vbox: VBoxContainer
var _cmd_preview_lbl: Label
var _preview_status_lbl: Label
var _empty_pattern_lbl: Label
var _assembled_flow: FlowContainer
var _tokens_flow: FlowContainer

var _current_level: Dictionary = {}
var _assembled_tokens: Array[String] = []


func _get_buku_saku_tab() -> String:
	return "wildcard"


func _setup_content(parent: VBoxContainer) -> void:
	_crt_card = PanelContainer.new()
	_crt_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTheme.style_monitor_panel(_crt_card, 14.0)
	parent.add_child(_crt_card)

	var crt_v := VBoxContainer.new()
	crt_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	crt_v.add_theme_constant_override("separation", 6)
	_crt_card.add_child(crt_v)

	var mono := UiTheme.make_mono_font()

	_header_lbl = Label.new()
	_header_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_header_lbl.add_theme_font_override("font", mono)
	_header_lbl.add_theme_font_size_override("font_size", 15)
	_header_lbl.add_theme_color_override("font_color", UiTheme.COL_GOLD_BRIGHT)
	crt_v.add_child(_header_lbl)

	var rule_lbl := Label.new()
	rule_lbl.text = "Aturan Wildcard:   * = banyak karakter bebas   |   ? = TEPAT 1 karakter"
	rule_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rule_lbl.add_theme_font_override("font", mono)
	rule_lbl.add_theme_font_size_override("font_size", 14)
	rule_lbl.add_theme_color_override("font_color", UiTheme.COL_INFO)
	crt_v.add_child(rule_lbl)

	# 2 Kolom jelas: TARGET LOLOS [ALLOW] vs HARUS DITOLAK [DENY]
	_lists_split = BoxContainer.new()
	_lists_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lists_split.add_theme_constant_override("separation", 12)
	crt_v.add_child(_lists_split)

	var allow_col := VBoxContainer.new()
	allow_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	allow_col.add_theme_constant_override("separation", 6)
	_lists_split.add_child(allow_col)

	var allow_hdr := Label.new()
	allow_hdr.text = "TARGET LOLOS [ALLOW]"
	UiTheme.style_pixel_heading(allow_hdr, 16, UiTheme.COL_SUCCESS)
	allow_col.add_child(allow_hdr)

	_allow_vbox = VBoxContainer.new()
	_allow_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_allow_vbox.add_theme_constant_override("separation", 4)
	allow_col.add_child(_allow_vbox)

	var deny_col := VBoxContainer.new()
	deny_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deny_col.add_theme_constant_override("separation", 4)
	_lists_split.add_child(deny_col)

	var deny_hdr := Label.new()
	deny_hdr.text = "HARUS DITOLAK [DENY]"
	UiTheme.style_pixel_heading(deny_hdr, 16, UiTheme.COL_ERROR)
	deny_col.add_child(deny_hdr)

	_deny_vbox = VBoxContainer.new()
	_deny_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_deny_vbox.add_theme_constant_override("separation", 4)
	deny_col.add_child(_deny_vbox)

	# Panel Rakit Pola Wildcard
	var input_card := PanelContainer.new()
	input_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTheme.style_rpg_panel(input_card, 14.0)
	parent.add_child(input_card)

	var in_v := VBoxContainer.new()
	in_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	in_v.add_theme_constant_override("separation", 10)
	input_card.add_child(in_v)

	var preview_box := PanelContainer.new()
	preview_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTheme.style_monitor_panel(preview_box, 10.0)
	in_v.add_child(preview_box)

	var pv := VBoxContainer.new()
	pv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pv.add_theme_constant_override("separation", 4)
	preview_box.add_child(pv)

	_cmd_preview_lbl = Label.new()
	_cmd_preview_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_cmd_preview_lbl.add_theme_font_override("font", mono)
	_cmd_preview_lbl.add_theme_font_size_override("font_size", 18)
	_cmd_preview_lbl.add_theme_color_override("font_color", UiTheme.COL_GOLD_BRIGHT)
	pv.add_child(_cmd_preview_lbl)

	_preview_status_lbl = Label.new()
	_preview_status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preview_status_lbl.add_theme_font_size_override("font_size", 14)
	_preview_status_lbl.add_theme_color_override("font_color", UiTheme.COL_TEXT_SECONDARY)
	pv.add_child(_preview_status_lbl)

	# Label kosong diletakkan di luar FlowContainer agar TIDAK membungkus vertikal per karakter!
	_empty_pattern_lbl = Label.new()
	_empty_pattern_lbl.text = "Tap ubin di bawah untuk menyusun pola wildcard. Tap ubin terpasang untuk menghapus."
	_empty_pattern_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_empty_pattern_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty_pattern_lbl.add_theme_font_size_override("font_size", 14)
	_empty_pattern_lbl.add_theme_color_override("font_color", UiTheme.COL_INK_SECONDARY)
	in_v.add_child(_empty_pattern_lbl)

	_assembled_flow = FlowContainer.new()
	_assembled_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_assembled_flow.add_theme_constant_override("h_separation", 8)
	_assembled_flow.add_theme_constant_override("v_separation", 8)
	in_v.add_child(_assembled_flow)

	var tok_title := Label.new()
	tok_title.text = "UBIN WILDCARD & POTONGAN NAMA"
	tok_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiTheme.style_parchment_heading(tok_title, 16, UiTheme.COL_INK_ACCENT)
	in_v.add_child(tok_title)

	_tokens_flow = FlowContainer.new()
	_tokens_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tokens_flow.add_theme_constant_override("h_separation", 8)
	_tokens_flow.add_theme_constant_override("v_separation", 8)
	in_v.add_child(_tokens_flow)


func _on_layout_mode_changed(mode: AdaptiveLayout.LayoutMode) -> void:
	if _lists_split != null:
		_lists_split.vertical = (mode == AdaptiveLayout.LayoutMode.COMPACT_PORTRAIT)


func _load_level(level: Dictionary) -> void:
	_current_level = level
	_assembled_tokens.clear()
	_header_lbl.text = str(level.get("header", "GATE_LOCK.EXE"))

	for ch: Node in _tokens_flow.get_children():
		ch.queue_free()

	var mono := UiTheme.make_mono_font()
	var tokens: Variant = level.get("tokens", [])
	if tokens is Array:
		for tok: Variant in tokens as Array:
			var t_str: String = str(tok)
			var btn := Button.new()
			btn.text = t_str
			btn.add_theme_font_override("font", mono)
			btn.add_theme_font_size_override("font_size", 16)
			UiTheme.style_chip_button(btn, false)
			btn.pressed.connect(_on_token_tap.bind(t_str))
			_tokens_flow.add_child(btn)

	_refresh_pattern_ui()


func _on_token_tap(tok_str: String) -> void:
	AudioManager.play_click()
	if _assembled_tokens.size() >= 10:
		return
	_assembled_tokens.append(tok_str)
	_refresh_pattern_ui()


func _on_remove_assembled(idx: int) -> void:
	AudioManager.play_click()
	if idx >= 0 and idx < _assembled_tokens.size():
		_assembled_tokens.remove_at(idx)
		_refresh_pattern_ui()


func _current_pattern() -> String:
	return "".join(_assembled_tokens)


func _refresh_pattern_ui() -> void:
	var pattern: String = _current_pattern()
	var prefix: String = str(_current_level.get("command_prefix", "DIR"))
	var suffix: String = str(_current_level.get("command_suffix", ""))
	var show_pat: String = pattern if not pattern.is_empty() else "[ ... ]"
	var cmd_text: String = "%s %s" % [prefix, show_pat]
	if not suffix.is_empty():
		cmd_text += " " + suffix
	_cmd_preview_lbl.text = "FILTER: " + cmd_text

	for ch: Node in _assembled_flow.get_children():
		ch.queue_free()

	var mono := UiTheme.make_mono_font()
	var is_empty: bool = _assembled_tokens.is_empty()
	_empty_pattern_lbl.visible = is_empty
	_assembled_flow.visible = not is_empty

	if not is_empty:
		for i: int in range(_assembled_tokens.size()):
			var b := Button.new()
			b.text = _assembled_tokens[i] + " x"
			b.add_theme_font_override("font", mono)
			UiTheme.style_chip_button(b, true)
			b.pressed.connect(_on_remove_assembled.bind(i))
			_assembled_flow.add_child(b)

	_rebuild_files_lists(pattern)


func _rebuild_files_lists(pattern: String) -> void:
	for ch: Node in _allow_vbox.get_children():
		ch.queue_free()
	for ch: Node in _deny_vbox.get_children():
		ch.queue_free()

	var allow_arr: Array = _current_level.get("allow_files", []) as Array
	var deny_arr: Array = _current_level.get("deny_files", []) as Array
	var has_pat: bool = not pattern.is_empty()

	var eval: Dictionary = WildcardMatcher.evaluate_filter(pattern, allow_arr, deny_arr)
	var mono := UiTheme.make_mono_font()

	for f: Variant in allow_arr:
		var fname: String = str(f)
		var matched: bool = has_pat and WildcardMatcher.matches(pattern, fname)
		_allow_vbox.add_child(_make_file_badge(fname, true, has_pat, matched, mono))

	for f: Variant in deny_arr:
		var fname: String = str(f)
		var matched: bool = has_pat and WildcardMatcher.matches(pattern, fname)
		_deny_vbox.add_child(_make_file_badge(fname, false, has_pat, matched, mono))

	if not has_pat:
		_preview_status_lbl.text = "Live Filter: belum ada pola terpasang."
		_preview_status_lbl.add_theme_color_override("font_color", UiTheme.COL_TEXT_SECONDARY)
	elif bool(eval.get("perfect", false)):
		_preview_status_lbl.text = "[OK] Semua [ALLOW] cocok dan semua [DENY] tertolak! Siap diperiksa."
		_preview_status_lbl.add_theme_color_override("font_color", UiTheme.COL_SUCCESS)
	else:
		var missed: int = (eval.get("allow_missed", []) as Array).size()
		var leaked: int = (eval.get("deny_leaked", []) as Array).size()
		_preview_status_lbl.text = "Live Filter: %d file [ALLOW] belum kena, %d file [DENY] ikut lolos." % [missed, leaked]
		_preview_status_lbl.add_theme_color_override("font_color", UiTheme.COL_WARN)


func _make_file_badge(fname: String, is_allow: bool, has_pat: bool, matched: bool, mono: Font) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var status_note: String = ""
	var border_col: Color = UiTheme.COL_SUCCESS if is_allow else UiTheme.COL_ERROR
	var bg_col: Color = UiTheme.COL_MONITOR_BG
	var text_col: Color = UiTheme.COL_SUCCESS if is_allow else UiTheme.COL_ERROR

	if has_pat:
		if is_allow and matched:
			status_note = "[COCOK]"
			bg_col = UiTheme.COL_SUCCESS_BG
			border_col = UiTheme.COL_SUCCESS
		elif is_allow and not matched:
			status_note = "[LEWAT]"
			border_col = UiTheme.COL_WARN
			text_col = UiTheme.COL_WARN
		elif not is_allow and matched:
			status_note = "[BOCOR]"
			bg_col = UiTheme.COL_ERROR_BG
			border_col = UiTheme.COL_ERROR
		else:
			status_note = "[AMAN]"
			border_col = UiTheme.COL_SLATE
			text_col = UiTheme.COL_TEXT_SECONDARY

	p.add_theme_stylebox_override("panel", UiTheme.make_box(bg_col, border_col, 2, 0, 5))
	var hb := HBoxContainer.new()
	hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_theme_constant_override("separation", 8)
	p.add_child(hb)

	var name_lbl := Label.new()
	name_lbl.text = fname
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.add_theme_font_override("font", mono)
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_color", UiTheme.COL_TEXT_PRIMARY)
	hb.add_child(name_lbl)

	if not status_note.is_empty():
		var st_lbl := Label.new()
		st_lbl.text = status_note
		st_lbl.add_theme_font_override("font", mono)
		st_lbl.add_theme_font_size_override("font_size", 14)
		st_lbl.add_theme_color_override("font_color", text_col)
		hb.add_child(st_lbl)
	return p


func _on_submit_pressed() -> void:
	var pattern: String = _current_pattern()
	var ans_pattern: String = str(_current_level.get("answer_pattern", ""))
	var allow_arr: Array = _current_level.get("allow_files", []) as Array
	var deny_arr: Array = _current_level.get("deny_files", []) as Array
	var eval: Dictionary = WildcardMatcher.evaluate_filter(pattern, allow_arr, deny_arr)

	if bool(eval.get("perfect", false)):
		submit_attempt(pattern, ans_pattern, true, "Pola '%s' menyaring tepat seluruh berkas [ALLOW]!" % pattern)
	else:
		var reason: String = ""
		if pattern.is_empty():
			reason = "Pola masih kosong. Susun ubin wildcard terlebih dahulu."
		else:
			var leaked: Array = eval.get("deny_leaked", []) as Array
			var missed: Array = eval.get("allow_missed", []) as Array
			if not leaked.is_empty():
				reason = "Pola '%s' meloloskan file [DENY] seperti '%s'." % [pattern, str(leaked[0])]
			elif not missed.is_empty():
				reason = "Pola '%s' melewatkan file [ALLOW] seperti '%s'." % [pattern, str(missed[0])]
		UiTheme.shake_control(_crt_card, 7.0)
		submit_attempt(pattern, ans_pattern, false, reason)
