extends BaseMinigame
## Stage 5: Studio Layar & .BAT (CRT_CONFIG) - DIR flags, Layar/Sistem, PROMPT, & Skrip .BAT.

var _screens_box: BoxContainer
var _live_card: PanelContainer
var _target_lbl: Label
var _live_lbl: Label
var _match_lbl: Label
var _empty_tokens_lbl: Label
var _assembled_flow: FlowContainer
var _tokens_flow: FlowContainer

var _current_level: Dictionary = {}
var _selected_tokens: Array[String] = []


func _get_buku_saku_tab() -> String:
	var mode: String = str(_current_level.get("mode", "dir_flags"))
	if mode == "prompt" or mode == "batch":
		return "batch"
	return "eksplorasi"


func _setup_content(parent: VBoxContainer) -> void:
	_screens_box = BoxContainer.new()
	_screens_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_screens_box.add_theme_constant_override("separation", 12)
	parent.add_child(_screens_box)

	var mono := UiTheme.make_mono_font()

	# Layar Target (Monitor Pixel - HANYA OUTPUT, tanpa input perintah!)
	var target_card := PanelContainer.new()
	target_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	target_card.custom_minimum_size = Vector2(0.0, 156.0)
	UiTheme.style_monitor_panel(target_card, 14.0)
	_screens_box.add_child(target_card)

	var t_v := VBoxContainer.new()
	t_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t_v.add_theme_constant_override("separation", 8)
	target_card.add_child(t_v)

	var t_head := Label.new()
	t_head.text = "TARGET OUTPUT LAYAR"
	UiTheme.style_pixel_heading(t_head, 16, UiTheme.COL_GOLD_BRIGHT)
	t_v.add_child(t_head)

	_target_lbl = Label.new()
	_target_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_target_lbl.add_theme_font_override("font", mono)
	_target_lbl.add_theme_font_size_override("font_size", 15)
	_target_lbl.add_theme_color_override("font_color", UiTheme.COL_SUCCESS)
	t_v.add_child(_target_lbl)

	# Layar Live Preview (Monitor Pixel)
	_live_card = PanelContainer.new()
	_live_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_live_card.custom_minimum_size = Vector2(0.0, 156.0)
	UiTheme.style_monitor_panel(_live_card, 14.0)
	_screens_box.add_child(_live_card)

	var l_v := VBoxContainer.new()
	l_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l_v.add_theme_constant_override("separation", 8)
	_live_card.add_child(l_v)

	var l_head := Label.new()
	l_head.text = "LIVE PREVIEW OUTPUT"
	UiTheme.style_pixel_heading(l_head, 16, UiTheme.COL_INFO)
	l_v.add_child(l_head)

	_live_lbl = Label.new()
	_live_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_live_lbl.add_theme_font_override("font", mono)
	_live_lbl.add_theme_font_size_override("font_size", 15)
	_live_lbl.add_theme_color_override("font_color", UiTheme.COL_TEXT_PRIMARY)
	l_v.add_child(_live_lbl)

	# Rakit Token (Panel RPG)
	var build_card := PanelContainer.new()
	build_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTheme.style_rpg_panel(build_card, 14.0)
	parent.add_child(build_card)

	var b_v := VBoxContainer.new()
	b_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_v.add_theme_constant_override("separation", 8)
	build_card.add_child(b_v)

	var b_top := HBoxContainer.new()
	b_top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_top.add_theme_constant_override("separation", 8)
	b_v.add_child(b_top)

	var b_head := Label.new()
	b_head.text = "PERINTAH TERPASANG"
	b_head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiTheme.style_pixel_heading(b_head, 16, UiTheme.COL_INFO)
	b_top.add_child(b_head)

	_match_lbl = Label.new()
	_match_lbl.text = "[BELUM COCOK]"
	_match_lbl.add_theme_font_override("font", mono)
	_match_lbl.add_theme_font_size_override("font_size", 14)
	_match_lbl.add_theme_color_override("font_color", UiTheme.COL_TEXT_SECONDARY)
	b_top.add_child(_match_lbl)

	_empty_tokens_lbl = Label.new()
	_empty_tokens_lbl.text = "Belum ada token dipasang. Tap token di bawah untuk menyusun perintah."
	_empty_tokens_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_empty_tokens_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty_tokens_lbl.add_theme_font_size_override("font_size", 14)
	_empty_tokens_lbl.add_theme_color_override("font_color", UiTheme.COL_TEXT_SECONDARY)
	b_v.add_child(_empty_tokens_lbl)

	_assembled_flow = FlowContainer.new()
	_assembled_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_assembled_flow.add_theme_constant_override("h_separation", 8)
	_assembled_flow.add_theme_constant_override("v_separation", 8)
	b_v.add_child(_assembled_flow)

	var d_head := Label.new()
	d_head.text = "DEK TOKEN PARAMETER & BATCH"
	d_head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiTheme.style_pixel_heading(d_head, 16, UiTheme.COL_GOLD_BRIGHT)
	b_v.add_child(d_head)

	_tokens_flow = FlowContainer.new()
	_tokens_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tokens_flow.add_theme_constant_override("h_separation", 8)
	_tokens_flow.add_theme_constant_override("v_separation", 8)
	b_v.add_child(_tokens_flow)


func _on_layout_mode_changed(mode: AdaptiveLayout.LayoutMode) -> void:
	if _screens_box != null:
		_screens_box.vertical = (mode == AdaptiveLayout.LayoutMode.COMPACT_PORTRAIT)


func _load_level(level: Dictionary) -> void:
	_current_level = level
	_selected_tokens.clear()

	var target_arr: Array = level.get("target_lines", []) as Array
	var t_lines := PackedStringArray()
	for ln: Variant in target_arr:
		t_lines.append(str(ln))
	_target_lbl.text = "\n".join(t_lines)

	for ch: Node in _tokens_flow.get_children():
		ch.queue_free()

	var mono := UiTheme.make_mono_font()
	for tok: Variant in level.get("tokens", []) as Array:
		var t_str: String = str(tok)
		var btn := Button.new()
		btn.text = t_str
		btn.add_theme_font_override("font", mono)
		btn.add_theme_font_size_override("font_size", 15)
		UiTheme.style_chip_button(btn, false)
		btn.pressed.connect(_on_token_tap.bind(t_str))
		_tokens_flow.add_child(btn)

	_refresh_live_preview()


func _on_token_tap(tok_str: String) -> void:
	AudioManager.play_click()
	if _selected_tokens.has(tok_str) or _selected_tokens.size() >= 8:
		return
	_selected_tokens.append(tok_str)
	_refresh_live_preview()


func _on_remove_token(idx: int) -> void:
	AudioManager.play_click()
	if idx >= 0 and idx < _selected_tokens.size():
		_selected_tokens.remove_at(idx)
		_refresh_live_preview()


func _refresh_live_preview() -> void:
	for ch: Node in _assembled_flow.get_children():
		ch.queue_free()

	var mono := UiTheme.make_mono_font()
	var is_empty: bool = _selected_tokens.is_empty()
	_empty_tokens_lbl.visible = is_empty
	_assembled_flow.visible = not is_empty

	if not is_empty:
		for i: int in range(_selected_tokens.size()):
			var b := Button.new()
			b.text = _selected_tokens[i] + " x"
			b.add_theme_font_override("font", mono)
			UiTheme.style_chip_button(b, true)
			b.pressed.connect(_on_remove_token.bind(i))
			_assembled_flow.add_child(b)

	var lines: PackedStringArray = simulate_crt_output(_current_level, _selected_tokens)
	_live_lbl.text = "\n".join(lines)

	var expected_lines := PackedStringArray()
	for ln: Variant in _current_level.get("target_lines", []) as Array:
		expected_lines.append(str(ln))
	var is_match: bool = (lines == expected_lines)
	_match_lbl.text = "[COCOK]" if is_match else "[BELUM COCOK]"
	_match_lbl.add_theme_color_override("font_color", UiTheme.COL_SUCCESS if is_match else UiTheme.COL_TEXT_SECONDARY)


static func simulate_crt_output(level: Dictionary, chosen: Array[String]) -> PackedStringArray:
	var mode: String = str(level.get("mode", "dir_flags"))
	var out := PackedStringArray()

	if mode == "dir_flags":
		if not chosen.has("DIR"):
			out.append("(Tambahkan perintah DIR terlebih dahulu)")
			return out
		var files: Array = (level.get("sample_files", []) as Array).duplicate(true)
		if chosen.has("/o-s"):
			files.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["size"]) > int(b["size"]))
		elif chosen.has("/os"):
			files.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["size"]) < int(b["size"]))
		elif chosen.has("/on"):
			files.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a["name"]) < str(b["name"]))

		var bare: bool = chosen.has("/b")
		var wide: bool = chosen.has("/w")
		if wide:
			var names := PackedStringArray()
			for f: Variant in files:
				names.append("[%s]" % str((f as Dictionary)["name"]))
			out.append("  ".join(names))
		else:
			for f: Variant in files:
				var fd := f as Dictionary
				if bare:
					out.append(str(fd["name"]))
				else:
					out.append("%-12s %8d bytes" % [str(fd["name"]), int(fd["size"])])
		return out

	if mode == "screen_info":
		if not chosen.has("CLS"):
			out.append("C:\\> [ERR] LOG SAMPAH LAMA MASIH MEMENUHI LAYAR...")
			out.append("C:\\> [ERR] BUFFER PENUH - BERSIHKAN LAYAR DULU!")
		for tok: String in chosen:
			match tok:
				"VER":
					out.append("Microsoft Windows [Version 10.0.22631]")
				"VOL":
					out.append("Volume in drive D is DATA_SMK")
					out.append("Volume Serial Number is 4A2C-99F1")
				"DATE":
					out.append("The current date is: Sat 11/21/2026")
				"TIME":
					out.append("The current time is: 14:30:00.00")
				"DIR":
					out.append("Directory of D:\\DATA (2 File(s))")
		if out.is_empty():
			out.append("(Layar bersih - tambahkan perintah info sistem)")
		return out

	if mode == "prompt":
		if chosen.is_empty() or chosen[0] != "PROMPT":
			out.append("(Mulai dengan blok PROMPT terlebih dahulu)")
			return out
		var base_p: String = str(level.get("base_path", "D:\\TUGAS"))
		var rendered: String = ""
		for i: int in range(1, chosen.size()):
			var t: String = chosen[i]
			match t:
				"$_":
					rendered += "\n"
				"$P":
					rendered += base_p
				"$G":
					rendered += ">"
				"$L":
					rendered += "<"
				"$T":
					rendered += "14:30:00"
				"$D":
					rendered += "11/21/2026"
				"$V":
					rendered += "Windows 10"
				"$$":
					rendered += "$"
				_:
					rendered += t
		for line: String in rendered.split("\n"):
			out.append(line)
		return out

	if mode == "batch":
		var echo_hidden: bool = false
		if chosen.is_empty():
			out.append("(Belum ada baris skrip .BAT)")
			return out
		for tok: String in chosen:
			if tok == "@ECHO OFF":
				echo_hidden = true
				continue
			if tok == "ECHO ON":
				echo_hidden = false
				continue
			if not echo_hidden:
				out.append("C:\\> " + tok)
			if tok == "CLS":
				out.clear()
			elif tok.begins_with("ECHO "):
				out.append(tok.substr(5))
			elif tok == "PAUSE":
				out.append("Press any key to continue . . .")
			elif tok == "DATE":
				out.append("The current date is: Sat 11/21/2026")
			elif tok == "TIME":
				out.append("The current time is: 14:30:00.00")
		return out

	return out


func _on_submit_pressed() -> void:
	var target_arr: Array = _current_level.get("target_lines", []) as Array
	var expected_lines := PackedStringArray()
	for ln: Variant in target_arr:
		expected_lines.append(str(ln))

	var live_lines: PackedStringArray = simulate_crt_output(_current_level, _selected_tokens)
	var ans_arr: Array[String] = []
	for t: Variant in _current_level.get("answer_tokens", []) as Array:
		ans_arr.append(str(t))

	var user_joined: String = " ".join(_selected_tokens) if not _selected_tokens.is_empty() else "(kosong)"
	var key_joined: String = " ".join(ans_arr)

	var matches_output: bool = (live_lines == expected_lines)
	var matches_tokens: bool = (_selected_tokens == ans_arr)
	if matches_output or matches_tokens:
		submit_attempt(user_joined, key_joined, true, "Tampilan layar terminal 100% cocok dengan target!")
	else:
		var reason: String = "Tampilan Live Preview belum sama dengan Target Output. Cek kembali urutan atau parameter."
		UiTheme.shake_control(_live_card, 7.0)
		submit_attempt(user_joined, key_joined, false, reason)
