extends BaseMinigame
## Stage 1: Lengkapi Perintah DOS (CMD_PATCH.EXE) - Output di atas, input slot & dek blok di bawah (bisa disematkan).

var _crt_panel: PanelContainer
var _cmd_preview_lbl: Label
var _crt_log_lbl: Label
var _prompt_lbl: Label
var _tokens_flow: FlowContainer
var _choices_flow: FlowContainer

var _current_level: Dictionary = {}
var _slot_values: Array[String] = []
var _slot_buttons: Dictionary[int, Button] = {}
var _selected_slot: int = -1


func _get_buku_saku_tab() -> String:
	return "berkas"


func _setup_content(parent: VBoxContainer) -> void:
	# OUTPUT (di atas): Monitor Terminal DOS
	_crt_panel = PanelContainer.new()
	_crt_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTheme.style_monitor_panel(_crt_panel, 14.0)
	parent.add_child(_crt_panel)

	var crt_v := VBoxContainer.new()
	crt_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	crt_v.add_theme_constant_override("separation", 8)
	_crt_panel.add_child(crt_v)

	var out_title := Label.new()
	out_title.text = "OUTPUT TERMINAL DOS"
	UiTheme.style_pixel_heading(out_title, 16, UiTheme.COL_INFO)
	crt_v.add_child(out_title)

	var mono := UiTheme.make_mono_font()

	_cmd_preview_lbl = Label.new()
	_cmd_preview_lbl.text = "C:\\>"
	_cmd_preview_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_cmd_preview_lbl.add_theme_font_override("font", mono)
	_cmd_preview_lbl.add_theme_font_size_override("font_size", 17)
	_cmd_preview_lbl.add_theme_color_override("font_color", UiTheme.COL_SUCCESS)
	crt_v.add_child(_cmd_preview_lbl)

	_crt_log_lbl = Label.new()
	_crt_log_lbl.text = "> Menunggu perintah diisi..."
	_crt_log_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_crt_log_lbl.add_theme_font_override("font", mono)
	_crt_log_lbl.add_theme_font_size_override("font_size", 15)
	_crt_log_lbl.add_theme_color_override("font_color", UiTheme.COL_TEXT_SECONDARY)
	crt_v.add_child(_crt_log_lbl)


func _setup_input(parent: VBoxContainer) -> void:
	# INPUT (di bawah, bisa disematkan): Slot Perintah + Dek Pilihan Blok
	var deck_card := PanelContainer.new()
	deck_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTheme.style_rpg_panel(deck_card, 14.0)
	parent.add_child(deck_card)

	var deck_v := VBoxContainer.new()
	deck_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deck_v.add_theme_constant_override("separation", 10)
	deck_card.add_child(deck_v)

	var guide_lbl := Label.new()
	guide_lbl.text = "Cara main: 1) Ketuk kotak slot kosong di bawah  2) Pilih blok perintah yang tepat  3) Tekan KIRIM JAWABAN." if GameConfig.exam_blind_mode else "Cara main: 1) Ketuk kotak slot kosong di bawah  2) Pilih blok perintah yang tepat  3) Tekan CEK JAWABAN."
	guide_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guide_lbl.add_theme_font_size_override("font_size", 14)
	guide_lbl.add_theme_color_override("font_color", UiTheme.COL_TEXT_SECONDARY)
	deck_v.add_child(guide_lbl)

	var cmd_row := FlowContainer.new()
	cmd_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cmd_row.add_theme_constant_override("h_separation", 8)
	cmd_row.add_theme_constant_override("v_separation", 8)
	deck_v.add_child(cmd_row)

	var mono := UiTheme.make_mono_font()

	_prompt_lbl = Label.new()
	_prompt_lbl.text = "C:\\>"
	_prompt_lbl.custom_minimum_size = Vector2(0, UiTheme.MIN_TAP_HEIGHT)
	_prompt_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt_lbl.add_theme_font_override("font", mono)
	_prompt_lbl.add_theme_font_size_override("font_size", 18)
	_prompt_lbl.add_theme_color_override("font_color", UiTheme.COL_SUCCESS)
	cmd_row.add_child(_prompt_lbl)

	_tokens_flow = FlowContainer.new()
	_tokens_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tokens_flow.add_theme_constant_override("h_separation", 8)
	_tokens_flow.add_theme_constant_override("v_separation", 8)
	cmd_row.add_child(_tokens_flow)

	var deck_title := Label.new()
	deck_title.text = "DEK BLOK PERINTAH (TAP UNTUK MEMASANG)"
	deck_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiTheme.style_parchment_heading(deck_title, 16, UiTheme.COL_INK_ACCENT)
	deck_v.add_child(deck_title)

	_choices_flow = FlowContainer.new()
	_choices_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_choices_flow.add_theme_constant_override("h_separation", 10)
	_choices_flow.add_theme_constant_override("v_separation", 10)
	deck_v.add_child(_choices_flow)


func _load_level(level: Dictionary) -> void:
	_current_level = level
	_prompt_lbl.text = str(level.get("prompt_dir", "C:\\>"))
	_crt_log_lbl.text = "> Pilih slot kosong di bawah lalu ketuk blok perintah untuk melengkapi."
	_crt_log_lbl.add_theme_color_override("font_color", UiTheme.COL_TEXT_SECONDARY)

	_slot_values.clear()
	_slot_buttons.clear()
	_selected_slot = -1

	for ch: Node in _tokens_flow.get_children():
		ch.queue_free()
	for ch: Node in _choices_flow.get_children():
		ch.queue_free()

	var mono := UiTheme.make_mono_font()
	var tokens: Variant = level.get("tokens", [])
	if tokens is Array:
		var arr := tokens as Array
		for i: int in range(arr.size()):
			var tok: Dictionary = arr[i] as Dictionary
			var txt: String = str(tok.get("text", ""))
			var editable: bool = bool(tok.get("editable", false))

			if editable:
				_slot_values.append("")
				var btn := Button.new()
				btn.text = ""
				btn.tooltip_text = "Ketuk untuk memilih slot jawaban"
				btn.add_theme_font_override("font", mono)
				btn.add_theme_font_size_override("font_size", 17)
				btn.pressed.connect(_on_slot_pressed.bind(i))
				_tokens_flow.add_child(btn)
				_slot_buttons[i] = btn
				if _selected_slot == -1:
					_selected_slot = i
			else:
				_slot_values.append(txt)
				var lbl_box := PanelContainer.new()
				UiTheme.style_monitor_panel(lbl_box, 10.0)
				var lbl := Label.new()
				lbl.text = txt
				lbl.add_theme_font_override("font", mono)
				lbl.add_theme_font_size_override("font_size", 17)
				lbl.add_theme_color_override("font_color", UiTheme.COL_INK_PRIMARY)
				lbl_box.add_child(lbl)
				_tokens_flow.add_child(lbl_box)

	var choices: Variant = level.get("choices", [])
	if choices is Array:
		var answers_to_avoid: Array = []
		if tokens is Array:
			for tk: Variant in tokens as Array:
				if tk is Dictionary and bool((tk as Dictionary).get("editable", false)):
					answers_to_avoid.append(str((tk as Dictionary).get("answer", "")))
		var shuffled: Array[String] = LevelsCatalog.shuffled_choices(choices as Array, answers_to_avoid)
		for c_str: String in shuffled:
			var c_btn := Button.new()
			c_btn.text = c_str
			c_btn.add_theme_font_override("font", mono)
			c_btn.add_theme_font_size_override("font_size", 16)
			UiTheme.style_chip_button(c_btn, false)
			c_btn.pressed.connect(_on_choice_pressed.bind(c_str))
			_choices_flow.add_child(c_btn)

	_refresh_slot_styles()
	_refresh_command_preview()
	refresh_pinned_layout()


func _refresh_command_preview() -> void:
	var parts := PackedStringArray()
	for v: String in _slot_values:
		parts.append("____" if v.strip_edges().is_empty() else v)
	_cmd_preview_lbl.text = "%s %s" % [_prompt_lbl.text, " ".join(parts)]


func _on_slot_pressed(idx: int) -> void:
	if _level_solved:
		return
	AudioManager.play_click()
	_selected_slot = idx
	_refresh_slot_styles()


func _on_choice_pressed(choice_text: String) -> void:
	if _level_solved:
		return
	AudioManager.play_block_place()
	if _selected_slot == -1 or not _slot_buttons.has(_selected_slot):
		return
	_slot_values[_selected_slot] = choice_text
	var active_btn: Button = _slot_buttons[_selected_slot]
	active_btn.text = choice_text
	UiTheme.pulse_control(active_btn, 0.94, 0.12)

	var keys: Array = _slot_buttons.keys()
	keys.sort()
	if keys.size() > 1:
		var pos: int = keys.find(_selected_slot)
		var next_empty: int = -1
		for offset: int in range(1, keys.size()):
			var cand: int = int(keys[(pos + offset) % keys.size()])
			if _slot_values[cand].strip_edges().is_empty():
				next_empty = cand
				break
		if next_empty != -1:
			_selected_slot = next_empty
		elif pos >= 0:
			_selected_slot = int(keys[(pos + 1) % keys.size()])
	_refresh_slot_styles()
	_refresh_command_preview()
	refresh_pinned_layout()


func _refresh_slot_styles() -> void:
	for idx: int in _slot_buttons.keys():
		var btn: Button = _slot_buttons[idx]
		var is_sel: bool = (idx == _selected_slot)
		var is_empty: bool = _slot_values[idx].strip_edges().is_empty()
		btn.custom_minimum_size = Vector2(96.0, UiTheme.MIN_TAP_HEIGHT)
		if is_sel:
			UiTheme.style_chip_button(btn, true)
		elif is_empty:
			btn.add_theme_stylebox_override("normal", UiTheme.make_box(UiTheme.COL_MONITOR_BG, UiTheme.COL_GOLD, 2, 0, 10))
			btn.add_theme_stylebox_override("hover", UiTheme.make_box(UiTheme.COL_BLUE, UiTheme.COL_GOLD_BRIGHT, 2, 0, 10))
			btn.add_theme_stylebox_override("pressed", UiTheme.make_box(UiTheme.COL_BLUE_PRESSED, UiTheme.COL_GOLD_BRIGHT, 2, 0, 10))
			btn.add_theme_stylebox_override("focus", UiTheme.make_focus_box())
			btn.add_theme_color_override("font_color", UiTheme.COL_TEXT_PRIMARY)
			UiTheme.attach_button_feel(btn)
		else:
			UiTheme.style_chip_button(btn, false)


func _on_submit_pressed() -> void:
	var tokens: Variant = _current_level.get("tokens", [])
	var first_empty_slot: int = -1
	if tokens is Array:
		var check_arr := tokens as Array
		for i: int in range(check_arr.size()):
			var tok: Dictionary = check_arr[i] as Dictionary
			if bool(tok.get("editable", false)) and _slot_values[i].strip_edges().is_empty():
				first_empty_slot = i
				break

	if first_empty_slot != -1:
		_selected_slot = first_empty_slot
		_refresh_slot_styles()
		var empty_msg: String = "Slot jawaban masih kosong! Pilih blok perintah di bawah terlebih dahulu."
		_crt_log_lbl.text = "> [INFO] " + empty_msg
		_crt_log_lbl.add_theme_color_override("font_color", UiTheme.COL_INFO)
		UiTheme.shake_control(_crt_panel, 6.0)
		show_info_feedback(empty_msg)
		return

	var user_cmd: String = " ".join(_slot_values)
	var key_parts: Array[String] = []
	var all_correct: bool = true
	var wrong_reason: String = ""

	if tokens is Array:
		var arr := tokens as Array
		for i: int in range(arr.size()):
			var tok: Dictionary = arr[i] as Dictionary
			if bool(tok.get("editable", false)):
				var ans: String = str(tok.get("answer", ""))
				key_parts.append(ans)
				if _slot_values[i] != ans:
					all_correct = false
					var wmap: Variant = _current_level.get("wrong_messages", {})
					if wmap is Dictionary and (wmap as Dictionary).has(_slot_values[i]):
						wrong_reason = str((wmap as Dictionary)[_slot_values[i]])
			else:
				key_parts.append(str(tok.get("text", "")))

	var key_cmd: String = " ".join(key_parts)
	if GameConfig.exam_blind_mode:
		_crt_log_lbl.text = "%s %s\n> Jawaban dikirim dan tersimpan ke sistem." % [_prompt_lbl.text, user_cmd]
		_crt_log_lbl.add_theme_color_override("font_color", UiTheme.COL_INFO)
		submit_attempt(user_cmd, key_cmd, all_correct, "")
		return

	if all_correct:
		var ok_out: String = str(_current_level.get("success_output", "Perintah berhasil dijalankan."))
		_crt_log_lbl.text = "%s %s\n%s" % [_prompt_lbl.text, user_cmd, ok_out]
		_crt_log_lbl.add_theme_color_override("font_color", UiTheme.COL_SUCCESS)
		submit_attempt(user_cmd, key_cmd, true, "Sintaks DOS tepat dan berhasil dieksekusi!")
	else:
		if wrong_reason.is_empty():
			wrong_reason = "Perintah '%s' belum sesuai dengan misi atau sintaks Windows DOS." % user_cmd
		_crt_log_lbl.text = "%s %s\n[ERR] %s" % [_prompt_lbl.text, user_cmd, wrong_reason]
		_crt_log_lbl.add_theme_color_override("font_color", UiTheme.COL_ERROR)
		UiTheme.shake_control(_crt_panel, 7.0)
		submit_attempt(user_cmd, key_cmd, false, wrong_reason)
