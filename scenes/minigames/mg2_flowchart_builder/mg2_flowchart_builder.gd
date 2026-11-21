extends BaseMinigame
## Stage 2: Rakit Flowchart (FLOW_BATCH) - Susun urutan blok langkah perintah DOS.

var _split_box: BoxContainer
var _flow_title_lbl: Label
var _flow_scroll: ScrollContainer
var _sim_log_lbl: Label
var _sim_scroll: ScrollContainer
var _seq_vbox: VBoxContainer
var _bank_flow: FlowContainer
var _crt_card: PanelContainer
var _flow_card: PanelContainer

var _current_level: Dictionary = {}
var _all_blocks: Array[String] = []
var _sequence: Array[String] = []


func _get_buku_saku_tab() -> String:
	return "berkas"


func _setup_content(parent: VBoxContainer) -> void:
	_split_box = BoxContainer.new()
	_split_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_split_box.add_theme_constant_override("separation", 12)
	parent.add_child(_split_box)

	# Panel Flowchart (tinggi terkunci dengan ScrollContainer internal agar tidak turun-turun saat tambah blok)
	_flow_card = PanelContainer.new()
	_flow_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_flow_card.custom_minimum_size = Vector2(0.0, 260.0)
	UiTheme.style_rpg_panel(_flow_card, 14.0)
	_split_box.add_child(_flow_card)

	var flow_v := VBoxContainer.new()
	flow_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow_v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	flow_v.add_theme_constant_override("separation", 6)
	_flow_card.add_child(flow_v)

	_flow_title_lbl = Label.new()
	_flow_title_lbl.text = "URUTAN FLOWCHART"
	_flow_title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiTheme.style_pixel_heading(_flow_title_lbl, 16, UiTheme.COL_GOLD_BRIGHT)
	flow_v.add_child(_flow_title_lbl)

	_flow_scroll = ScrollContainer.new()
	_flow_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_flow_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_flow_scroll.custom_minimum_size = Vector2(0.0, 200.0)
	_flow_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	flow_v.add_child(_flow_scroll)

	var flow_pad := MarginContainer.new()
	flow_pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow_pad.add_theme_constant_override("margin_right", 6)
	_flow_scroll.add_child(flow_pad)

	_seq_vbox = VBoxContainer.new()
	_seq_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_seq_vbox.add_theme_constant_override("separation", 4)
	flow_pad.add_child(_seq_vbox)

	# Panel Simulasi Monitor DOS
	_crt_card = PanelContainer.new()
	_crt_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_crt_card.custom_minimum_size = Vector2(0.0, 260.0)
	UiTheme.style_monitor_panel(_crt_card, 14.0)
	_split_box.add_child(_crt_card)

	var crt_v := VBoxContainer.new()
	crt_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	crt_v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	crt_v.add_theme_constant_override("separation", 8)
	_crt_card.add_child(crt_v)

	var crt_title := Label.new()
	crt_title.text = "SIMULASI MONITOR DOS"
	UiTheme.style_pixel_heading(crt_title, 16, UiTheme.COL_INFO)
	crt_v.add_child(crt_title)

	_sim_scroll = ScrollContainer.new()
	_sim_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sim_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_sim_scroll.custom_minimum_size = Vector2(0.0, 200.0)
	_sim_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	crt_v.add_child(_sim_scroll)

	_sim_log_lbl = Label.new()
	_sim_log_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sim_log_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sim_log_lbl.add_theme_font_override("font", UiTheme.make_mono_font())
	_sim_log_lbl.add_theme_font_size_override("font_size", 15)
	_sim_log_lbl.add_theme_color_override("font_color", UiTheme.COL_TEXT_PRIMARY)
	_sim_scroll.add_child(_sim_log_lbl)

	# Bank Blok
	var bank_card := PanelContainer.new()
	bank_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTheme.style_rpg_panel(bank_card, 14.0)
	parent.add_child(bank_card)

	var bank_v := VBoxContainer.new()
	bank_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bank_v.add_theme_constant_override("separation", 8)
	bank_card.add_child(bank_v)

	var bank_title := Label.new()
	bank_title.text = "BANK BLOK PERINTAH (TAP UNTUK MEMASANG)"
	bank_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiTheme.style_parchment_heading(bank_title, 16, UiTheme.COL_INK_ACCENT)
	bank_v.add_child(bank_title)

	_bank_flow = FlowContainer.new()
	_bank_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bank_flow.add_theme_constant_override("h_separation", 8)
	_bank_flow.add_theme_constant_override("v_separation", 8)
	bank_v.add_child(_bank_flow)


func _on_layout_mode_changed(mode: AdaptiveLayout.LayoutMode) -> void:
	var is_comp: bool = (mode == AdaptiveLayout.LayoutMode.COMPACT_PORTRAIT)
	if _split_box != null:
		_split_box.vertical = is_comp
	if _flow_card != null and _flow_scroll != null:
		var fh: float = 210.0 if is_comp else 260.0
		_flow_card.custom_minimum_size = Vector2(0.0, fh)
		_flow_scroll.custom_minimum_size = Vector2(0.0, fh - 58.0)
	if _crt_card != null and _sim_scroll != null:
		var ch: float = 160.0 if is_comp else 260.0
		_crt_card.custom_minimum_size = Vector2(0.0, ch)
		_sim_scroll.custom_minimum_size = Vector2(0.0, ch - 58.0)


func _load_level(level: Dictionary) -> void:
	_current_level = level
	_sequence.clear()
	_all_blocks.clear()

	var raw_blocks: Variant = level.get("blocks", [])
	if raw_blocks is Array:
		for b: Variant in raw_blocks as Array:
			_all_blocks.append(str(b))
	_all_blocks.shuffle()

	_sim_log_lbl.text = "%s\n> Susun blok langkah di Flowchart, lalu tekan CEK JAWABAN." % str(level.get("start_dir", "C:\\>"))
	_sim_log_lbl.add_theme_color_override("font_color", UiTheme.COL_TEXT_SECONDARY)
	_rebuild_ui_lists()


func _rebuild_ui_lists() -> void:
	for ch: Node in _seq_vbox.get_children():
		ch.queue_free()
	for ch: Node in _bank_flow.get_children():
		ch.queue_free()

	var mono := UiTheme.make_mono_font()
	var needed_count: int = (_current_level.get("answer_sequence", []) as Array).size()
	_flow_title_lbl.text = "URUTAN FLOWCHART (%d/%d)" % [_sequence.size(), needed_count]

	if _sequence.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "Belum ada langkah dipasang. Tap blok perintah di bawah (target %d langkah)." % needed_count
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_lbl.add_theme_color_override("font_color", UiTheme.COL_INK_SECONDARY)
		_seq_vbox.add_child(empty_lbl)
	else:
		for i: int in range(_sequence.size()):
			if i > 0:
				var arrow_lbl := Label.new()
				arrow_lbl.text = "v"
				arrow_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				arrow_lbl.add_theme_font_override("font", mono)
				arrow_lbl.add_theme_font_size_override("font_size", 14)
				arrow_lbl.add_theme_color_override("font_color", UiTheme.COL_INK_ACCENT)
				_seq_vbox.add_child(arrow_lbl)

			var step_text: String = _sequence[i]
			var row_panel := PanelContainer.new()
			row_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			UiTheme.style_monitor_panel(row_panel, 8.0)
			_seq_vbox.add_child(row_panel)

			var row := HBoxContainer.new()
			row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_theme_constant_override("separation", 6)
			row_panel.add_child(row)

			var lbl := Label.new()
			lbl.text = "%d. %s" % [i + 1, step_text]
			lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			lbl.add_theme_font_override("font", mono)
			lbl.add_theme_font_size_override("font_size", 15)
			lbl.add_theme_color_override("font_color", UiTheme.COL_TEXT_PRIMARY)
			row.add_child(lbl)

			var up_btn := Button.new()
			up_btn.text = "^"
			up_btn.tooltip_text = "Naikkan langkah"
			up_btn.disabled = (i == 0)
			UiTheme.style_blue_button(up_btn, "", true)
			up_btn.custom_minimum_size = Vector2(48.0, 48.0)
			up_btn.pressed.connect(_move_step.bind(i, -1))
			row.add_child(up_btn)

			var dn_btn := Button.new()
			dn_btn.text = "v"
			dn_btn.tooltip_text = "Turunkan langkah"
			dn_btn.disabled = (i == _sequence.size() - 1)
			UiTheme.style_blue_button(dn_btn, "", true)
			dn_btn.custom_minimum_size = Vector2(48.0, 48.0)
			dn_btn.pressed.connect(_move_step.bind(i, 1))
			row.add_child(dn_btn)

			var del_btn := Button.new()
			del_btn.text = "X"
			del_btn.tooltip_text = "Lepas blok ini"
			UiTheme.style_chip_button(del_btn, false)
			del_btn.custom_minimum_size = Vector2(48.0, 48.0)
			del_btn.pressed.connect(_remove_step.bind(i))
			row.add_child(del_btn)

	for blk: String in _all_blocks:
		if _sequence.has(blk):
			continue
		var b_btn := Button.new()
		b_btn.text = "+ " + blk
		b_btn.add_theme_font_override("font", mono)
		b_btn.add_theme_font_size_override("font_size", 15)
		UiTheme.style_chip_button(b_btn, false)
		b_btn.pressed.connect(_add_step.bind(blk))
		_bank_flow.add_child(b_btn)


func _add_step(step_text: String) -> void:
	AudioManager.play_click()
	_sequence.append(step_text)
	_rebuild_ui_lists()
	call_deferred("_scroll_flow_to_bottom")


func _scroll_flow_to_bottom() -> void:
	if is_instance_valid(_flow_scroll):
		var vbar: VScrollBar = _flow_scroll.get_v_scroll_bar()
		if vbar != null:
			_flow_scroll.scroll_vertical = int(vbar.max_value)


func _remove_step(idx: int) -> void:
	AudioManager.play_click()
	if idx >= 0 and idx < _sequence.size():
		_sequence.remove_at(idx)
		_rebuild_ui_lists()


func _move_step(idx: int, delta: int) -> void:
	AudioManager.play_click()
	var target: int = idx + delta
	if idx < 0 or idx >= _sequence.size() or target < 0 or target >= _sequence.size():
		return
	var tmp: String = _sequence[idx]
	_sequence[idx] = _sequence[target]
	_sequence[target] = tmp
	_rebuild_ui_lists()


func _on_submit_pressed() -> void:
	var ans_arr: Array[String] = []
	for item: Variant in _current_level.get("answer_sequence", []) as Array:
		ans_arr.append(str(item))

	var user_joined: String = " -> ".join(_sequence) if not _sequence.is_empty() else "(kosong)"
	var key_joined: String = " -> ".join(ans_arr)

	if _sequence == ans_arr:
		var lines := PackedStringArray()
		var cur_prompt: String = str(_current_level.get("start_dir", "C:\\>"))
		for step: String in _sequence:
			lines.append("%s %s" % [cur_prompt, step])
			if step.begins_with("CD ") and step != "CD ..":
				cur_prompt = cur_prompt.trim_suffix(">") + step.substr(3) + "\\>"
			elif step == "CD ..":
				cur_prompt = str(_current_level.get("start_dir", "C:\\>"))
		lines.append("[OK] Seluruh langkah eksekusi berhasil dijalankan!")
		_sim_log_lbl.text = "\n".join(lines)
		_sim_log_lbl.add_theme_color_override("font_color", UiTheme.COL_SUCCESS)
		submit_attempt(user_joined, key_joined, true, "Urutan flowchart tepat! Simulasi DOS sukses.")
	else:
		var diag: String = _diagnose_sequence(_sequence, ans_arr)
		_sim_log_lbl.text = "Urutan saat ini:\n%s\n\n[ERR] %s" % [user_joined, diag]
		_sim_log_lbl.add_theme_color_override("font_color", UiTheme.COL_ERROR)
		UiTheme.shake_control(_crt_card, 7.0)
		submit_attempt(user_joined, key_joined, false, diag)


static func _diagnose_sequence(user_seq: Array[String], ans_seq: Array[String]) -> String:
	if user_seq.is_empty():
		return "Flowchart masih kosong. Pasang blok perintah sesuai urutan misi."
	for blk: String in user_seq:
		if not ans_seq.has(blk):
			return "Blok '%s' adalah pengecoh atau tidak sesuai dengan misi!" % blk
	if user_seq.size() != ans_seq.size():
		return "Jumlah langkah baru %d dari %d langkah yang dibutuhkan." % [user_seq.size(), ans_seq.size()]
	for i: int in range(ans_seq.size()):
		if user_seq[i] != ans_seq[i]:
			return "Urutan langkah #%d belum tepat ('%s'). Periksa logika prasyarat sebelumnya." % [i + 1, user_seq[i]]
	return "Urutan belum tepat."
