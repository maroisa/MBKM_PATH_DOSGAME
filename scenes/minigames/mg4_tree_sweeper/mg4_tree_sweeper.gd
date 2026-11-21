extends BaseMinigame
## Stage 4: Labirin Folder (TREE_SWEEPER) - Pohon direktori visual, DIR /a, & 2 syarat mutlak RD.

var _split_box: BoxContainer
var _tree_card: PanelContainer
var _status_lbl: Label
var _tree_rt: RichTextLabel
var _actions_flow: FlowContainer
var _log_lbl: Label

var _current_level: Dictionary = {}
var _tree_state: Dictionary = {}
var _current_path: Array[String] = []
var _revealed_dirs: Dictionary[String, bool] = {}
var _command_history: Array[String] = []


func _get_buku_saku_tab() -> String:
	return "berkas"


func _setup_content(parent: VBoxContainer) -> void:
	_split_box = BoxContainer.new()
	_split_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_split_box.add_theme_constant_override("separation", 12)
	parent.add_child(_split_box)

	var mono := UiTheme.make_mono_font()

	# Kiri/Atas: Pohon Direktori Visual Berwarna (Monitor Pixel)
	_tree_card = PanelContainer.new()
	_tree_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tree_card.custom_minimum_size = Vector2(0.0, 210.0)
	UiTheme.style_monitor_panel(_tree_card, 14.0)
	_split_box.add_child(_tree_card)

	var tree_v := VBoxContainer.new()
	tree_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tree_v.add_theme_constant_override("separation", 8)
	_tree_card.add_child(tree_v)

	_status_lbl = Label.new()
	_status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_lbl.add_theme_font_override("font", mono)
	_status_lbl.add_theme_font_size_override("font_size", 15)
	_status_lbl.add_theme_color_override("font_color", UiTheme.COL_GOLD_BRIGHT)
	tree_v.add_child(_status_lbl)

	_tree_rt = RichTextLabel.new()
	_tree_rt.mouse_filter = Control.MOUSE_FILTER_PASS
	_tree_rt.bbcode_enabled = true
	_tree_rt.fit_content = true
	_tree_rt.scroll_active = false
	_tree_rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tree_rt.add_theme_font_override("normal_font", mono)
	_tree_rt.add_theme_font_size_override("normal_font_size", 15)
	_tree_rt.add_theme_color_override("default_color", UiTheme.COL_TEXT_PRIMARY)
	tree_v.add_child(_tree_rt)

	# Kanan/Bawah: Dek Aksi DOS + Log Terminal
	var act_card := PanelContainer.new()
	act_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	act_card.custom_minimum_size = Vector2(0.0, 210.0)
	UiTheme.style_rpg_panel(act_card, 14.0)
	_split_box.add_child(act_card)

	var act_v := VBoxContainer.new()
	act_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	act_v.add_theme_constant_override("separation", 10)
	act_card.add_child(act_v)

	var act_title := Label.new()
	act_title.text = "AKSI TERMINAL (TAP PERINTAH)"
	act_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiTheme.style_parchment_heading(act_title, 16, UiTheme.COL_INK_ACCENT)
	act_v.add_child(act_title)

	_actions_flow = FlowContainer.new()
	_actions_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_actions_flow.add_theme_constant_override("h_separation", 8)
	_actions_flow.add_theme_constant_override("v_separation", 8)
	act_v.add_child(_actions_flow)

	var log_box := PanelContainer.new()
	log_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTheme.style_monitor_panel(log_box, 10.0)
	act_v.add_child(log_box)

	_log_lbl = Label.new()
	_log_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log_lbl.add_theme_font_override("font", mono)
	_log_lbl.add_theme_font_size_override("font_size", 14)
	_log_lbl.add_theme_color_override("font_color", UiTheme.COL_TEXT_SECONDARY)
	log_box.add_child(_log_lbl)


func _on_layout_mode_changed(mode: AdaptiveLayout.LayoutMode) -> void:
	if _split_box != null:
		_split_box.vertical = (mode == AdaptiveLayout.LayoutMode.COMPACT_PORTRAIT)


func _load_level(level: Dictionary) -> void:
	_current_level = level
	_tree_state = (level.get("tree", {}) as Dictionary).duplicate(true)
	_current_path.clear()
	for part: String in str(level.get("start_path", "D:")).split("\\", false):
		_current_path.append(part)
	_revealed_dirs.clear()
	_command_history.clear()

	_check_btn.text = "CEK STATUS"
	_log_lbl.text = "> Pilih perintah DOS di atas untuk menavigasi dan menyelesaikan misi."
	_log_lbl.add_theme_color_override("font_color", UiTheme.COL_TEXT_SECONDARY)
	_refresh_tree_and_actions()


func _path_str(parts: Array[String]) -> String:
	return "\\".join(parts)


func _get_node_at(parts: Array[String]) -> Dictionary:
	if parts.is_empty() or not _tree_state.has(parts[0]):
		return {}
	var cur: Dictionary = _tree_state[parts[0]] as Dictionary
	for i: int in range(1, parts.size()):
		var children: Dictionary = cur.get("children", {}) as Dictionary
		if not children.has(parts[i]):
			return {}
		cur = children[parts[i]] as Dictionary
	return cur


func _refresh_tree_and_actions() -> void:
	var cur_str: String = _path_str(_current_path)
	var par_moves: int = int(_current_level.get("par_moves", 3))
	_status_lbl.text = "Prompt: %s>   |   Langkah: %d (Par: %d)" % [cur_str, _command_history.size(), par_moves]

	var lines := PackedStringArray()
	for root_name: Variant in _tree_state.keys():
		var rname: String = str(root_name)
		_render_tree_node(rname, _tree_state[rname] as Dictionary, [rname], 0, lines)
	_tree_rt.text = "\n".join(lines)

	for ch: Node in _actions_flow.get_children():
		ch.queue_free()

	if _level_solved:
		return

	var mono := UiTheme.make_mono_font()
	var cur_node: Dictionary = _get_node_at(_current_path)
	var children: Dictionary = cur_node.get("children", {}) as Dictionary
	var files: Array = cur_node.get("files", []) as Array
	var hidden: Array = cur_node.get("hidden", []) as Array
	var is_revealed: bool = bool(_revealed_dirs.get(cur_str, false))

	if _current_path.size() > 1:
		var up_btn := Button.new()
		up_btn.text = "CD .."
		up_btn.add_theme_font_override("font", mono)
		UiTheme.style_chip_button(up_btn, false)
		up_btn.pressed.connect(_exec_cd_up)
		_actions_flow.add_child(up_btn)

	var dir_a_btn := Button.new()
	dir_a_btn.text = "DIR /a"
	dir_a_btn.add_theme_font_override("font", mono)
	UiTheme.style_blue_button(dir_a_btn, "", false)
	dir_a_btn.pressed.connect(_exec_dir_hidden)
	_actions_flow.add_child(dir_a_btn)

	for sub_k: Variant in children.keys():
		var sname: String = str(sub_k)
		var cd_btn := Button.new()
		cd_btn.text = "CD %s" % sname
		cd_btn.add_theme_font_override("font", mono)
		UiTheme.style_chip_button(cd_btn, false)
		cd_btn.pressed.connect(_exec_cd.bind(sname))
		_actions_flow.add_child(cd_btn)

		var rd_btn := Button.new()
		rd_btn.text = "RD %s" % sname
		rd_btn.add_theme_font_override("font", mono)
		UiTheme.style_blue_button(rd_btn, "", false)
		rd_btn.pressed.connect(_exec_rd_child.bind(sname))
		_actions_flow.add_child(rd_btn)

	var target_full: String = str(_current_level.get("target_folder_path", ""))
	if cur_str == target_full and _current_path.size() > 1:
		var self_rd := Button.new()
		self_rd.text = "RD %s" % _current_path[_current_path.size() - 1]
		self_rd.add_theme_font_override("font", mono)
		UiTheme.style_blue_button(self_rd, "", false)
		self_rd.pressed.connect(_exec_rd_while_inside)
		_actions_flow.add_child(self_rd)

	for f: Variant in files:
		var fname: String = str(f)
		var del_btn := Button.new()
		del_btn.text = "DEL %s" % fname
		del_btn.add_theme_font_override("font", mono)
		UiTheme.style_chip_button(del_btn, false)
		del_btn.pressed.connect(_exec_del.bind(fname, false))
		_actions_flow.add_child(del_btn)

	if is_revealed:
		for hf: Variant in hidden:
			var hname: String = str(hf)
			var h_del := Button.new()
			h_del.text = "DEL %s [HIDDEN]" % hname
			h_del.add_theme_font_override("font", mono)
			UiTheme.style_chip_button(h_del, true)
			h_del.pressed.connect(_exec_del.bind(hname, true))
			_actions_flow.add_child(h_del)


func _render_tree_node(
	node_name: String,
	node_dict: Dictionary,
	path_parts: Array[String],
	depth: int,
	out_lines: PackedStringArray
) -> void:
	var indent: String = "  ".repeat(depth)
	var branch: String = "|-- " if depth > 0 else ""
	var full_p: String = _path_str(path_parts)
	var cur_p: String = _path_str(_current_path)
	var target_p: String = str(_current_level.get("target_folder_path", ""))

	var safe_name: String = node_name.replace("[", "[lb]")
	var line: String = "%s%s[color=#FEE761][DIR][/color] [color=#FFF5E4]%s[/color]" % [indent, branch, safe_name]
	if full_p == cur_p:
		line += "  [color=#87E0FF]<-- POSISI KAMU[/color]"
	if full_p == target_p:
		line += "  [color=#FF8599][TARGET][/color]"
	out_lines.append(line)

	var file_indent: String = "  ".repeat(depth + 1)
	for f: Variant in node_dict.get("files", []) as Array:
		out_lines.append("%s|-- [color=#C0CBDC]%s[/color]" % [file_indent, str(f)])
	if bool(_revealed_dirs.get(full_p, false)):
		for hf: Variant in node_dict.get("hidden", []) as Array:
			out_lines.append("%s|-- [color=#FEE761]%s [HIDDEN][/color]" % [file_indent, str(hf)])

	var children: Dictionary = node_dict.get("children", {}) as Dictionary
	for ck: Variant in children.keys():
		var cname: String = str(ck)
		var next_parts: Array[String] = path_parts.duplicate()
		next_parts.append(cname)
		_render_tree_node(cname, children[cname] as Dictionary, next_parts, depth + 1, out_lines)


func _exec_cd(folder_name: String) -> void:
	AudioManager.play_click()
	_current_path.append(folder_name)
	_command_history.append("CD " + folder_name)
	_log_lbl.text = "> Masuk ke %s" % _path_str(_current_path)
	_log_lbl.add_theme_color_override("font_color", UiTheme.COL_TEXT_SECONDARY)
	_refresh_tree_and_actions()


func _exec_cd_up() -> void:
	AudioManager.play_click()
	if _current_path.size() <= 1:
		return
	_current_path.remove_at(_current_path.size() - 1)
	_command_history.append("CD ..")
	_log_lbl.text = "> Pindah ke %s" % _path_str(_current_path)
	_log_lbl.add_theme_color_override("font_color", UiTheme.COL_TEXT_SECONDARY)
	_refresh_tree_and_actions()


func _exec_dir_hidden() -> void:
	AudioManager.play_click()
	var p: String = _path_str(_current_path)
	_revealed_dirs[p] = true
	_command_history.append("DIR /a")
	var cur: Dictionary = _get_node_at(_current_path)
	var hcount: int = (cur.get("hidden", []) as Array).size()
	if hcount > 0:
		_log_lbl.text = "> DIR /a menemukan %d berkas tersembunyi [HIDDEN]!" % hcount
		_log_lbl.add_theme_color_override("font_color", UiTheme.COL_GOLD_BRIGHT)
		show_info_feedback("DIR /a menampilkan berkas tersembunyi di direktori aktif.")
	else:
		_log_lbl.text = "> DIR /a selesai: tidak ditemukan berkas tersembunyi di folder ini."
		_log_lbl.add_theme_color_override("font_color", UiTheme.COL_TEXT_SECONDARY)
	_refresh_tree_and_actions()


func _exec_del(filename: String, is_hidden: bool) -> void:
	AudioManager.play_click()
	var cur: Dictionary = _get_node_at(_current_path)
	var key: String = "hidden" if is_hidden else "files"
	var arr: Array = cur.get(key, []) as Array
	arr.erase(filename)
	_command_history.append("DEL " + filename)
	_log_lbl.text = "> Berkas %s berhasil dihapus." % filename
	_log_lbl.add_theme_color_override("font_color", UiTheme.COL_SUCCESS)
	_refresh_tree_and_actions()


func _exec_rd_while_inside() -> void:
	var cur_name: String = _current_path[_current_path.size() - 1]
	_command_history.append("RD " + cur_name)
	# Pesan error autentik DOS tanpa membocorkan perintah jawaban secara langsung
	var msg: String = "Gagal menghapus '%s': folder sedang digunakan oleh prompt aktif. Periksa posisimu terlebih dahulu." % cur_name
	_log_lbl.text = "[ERR] " + msg
	_log_lbl.add_theme_color_override("font_color", UiTheme.COL_ERROR)
	UiTheme.shake_control(_tree_card, 7.0)
	submit_attempt(" -> ".join(_command_history), "Keluar dari folder lalu RD %s" % cur_name, false, msg)
	_refresh_tree_and_actions()


func _exec_rd_child(child_name: String) -> void:
	var cur_node: Dictionary = _get_node_at(_current_path)
	var children: Dictionary = cur_node.get("children", {}) as Dictionary
	if not children.has(child_name):
		return
	var target_node: Dictionary = children[child_name] as Dictionary
	var has_files: bool = not (target_node.get("files", []) as Array).is_empty()
	var has_hidden: bool = not (target_node.get("hidden", []) as Array).is_empty()
	var has_subs: bool = not (target_node.get("children", {}) as Dictionary).is_empty()

	_command_history.append("RD " + child_name)

	if has_files or has_hidden or has_subs:
		# Pesan error autentik DOS tanpa langsung membocorkan perintah pemeriksaan/penghapusan
		var msg: String = "The directory is not empty. Folder '%s' masih memiliki isi sehingga tidak dapat dihapus dengan RD." % child_name
		_log_lbl.text = "[ERR] " + msg
		_log_lbl.add_theme_color_override("font_color", UiTheme.COL_ERROR)
		UiTheme.shake_control(_tree_card, 7.0)
		submit_attempt(" -> ".join(_command_history), "Kosongkan seluruh isi folder lalu RD " + child_name, false, msg)
		_refresh_tree_and_actions()
		return

	var full_deleted: String = _path_str(_current_path) + "\\" + child_name
	var target_full: String = str(_current_level.get("target_folder_path", ""))
	if full_deleted != target_full:
		var wrong_msg: String = "Folder '%s' bukan folder target misi. Periksa kembali instruksi pada kotak Misi." % child_name
		_log_lbl.text = "[ERR] " + wrong_msg
		_log_lbl.add_theme_color_override("font_color", UiTheme.COL_ERROR)
		UiTheme.shake_control(_tree_card, 7.0)
		submit_attempt(" -> ".join(_command_history), "Hapus " + target_full, false, wrong_msg)
		_refresh_tree_and_actions()
		return

	children.erase(child_name)
	_log_lbl.text = "[OK] Folder '%s' berhasil dihapus!" % child_name
	_log_lbl.add_theme_color_override("font_color", UiTheme.COL_SUCCESS)
	submit_attempt(
		" -> ".join(_command_history),
		"Hapus %s (Par %d langkah)" % [target_full, int(_current_level.get("par_moves", 3))],
		true,
		"Berhasil menghapus folder '%s' dalam %d langkah!" % [child_name, _command_history.size()]
	)
	_refresh_tree_and_actions()


func _on_submit_pressed() -> void:
	if not _level_solved:
		show_info_feedback("Folder target belum dihapus. Gunakan tombol aksi perintah DOS untuk menyelesaikan misi.")
