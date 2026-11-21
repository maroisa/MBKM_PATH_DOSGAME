extends Control
## Modal Buku Saku Materi DOS Retro Pixel Art 128-bit (6 tab teraudit dalam monitor pixel).

var _sections: Array[Dictionary] = []
var _margin: MarginContainer
var _tabs_flow: FlowContainer
var _tab_buttons: Dictionary[String, Button] = {}
var _title_lbl: Label
var _summary_lbl: Label
var _blocks_vbox: VBoxContainer
var _close_btn: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.create_theme()
	_sections = BukuSakuData.get_sections()
	_build_ui()
	get_viewport().size_changed.connect(_on_resized)
	_on_resized()
	if not _sections.is_empty():
		_select_index(0)
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

	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UiTheme.style_rpg_panel(card, 14.0)
	_margin.add_child(card)

	var root_vbox := VBoxContainer.new()
	root_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_theme_constant_override("separation", 10)
	card.add_child(root_vbox)

	var header := HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_theme_constant_override("separation", 8)
	root_vbox.add_child(header)

	header.add_child(UiTheme.make_icon_rect("book", 32))

	var h_title := Label.new()
	h_title.text = "BUKU SAKU MATERI DOS"
	h_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiTheme.style_parchment_heading(h_title, 16, UiTheme.COL_INK_ACCENT)
	header.add_child(h_title)

	_close_btn = Button.new()
	_close_btn.text = "TUTUP"
	UiTheme.style_gold_button(_close_btn, "", true)
	_close_btn.custom_minimum_size = Vector2(96.0, UiTheme.MIN_TAP_HEIGHT)
	_close_btn.pressed.connect(func() -> void:
		AudioManager.play_click()
		SceneRouter.close_modal()
	)
	header.add_child(_close_btn)

	_tabs_flow = FlowContainer.new()
	_tabs_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tabs_flow.add_theme_constant_override("h_separation", 6)
	_tabs_flow.add_theme_constant_override("v_separation", 6)
	root_vbox.add_child(_tabs_flow)

	for i: int in range(_sections.size()):
		var sec: Dictionary = _sections[i]
		var sid: String = str(sec.get("id", ""))
		var btn := Button.new()
		btn.text = str(sec.get("tab", sid))
		UiTheme.style_chip_button(btn, false)
		btn.pressed.connect(_on_tab_pressed.bind(i))
		_tabs_flow.add_child(btn)
		_tab_buttons[sid] = btn

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_vbox.add_child(scroll)

	var body_pad := MarginContainer.new()
	body_pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_pad.add_theme_constant_override("margin_right", 6)
	scroll.add_child(body_pad)

	var body_vbox := VBoxContainer.new()
	body_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_vbox.add_theme_constant_override("separation", 10)
	body_pad.add_child(body_vbox)

	_title_lbl = Label.new()
	_title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title_lbl.add_theme_font_size_override("font_size", 18)
	_title_lbl.add_theme_color_override("font_color", UiTheme.COL_INK_PRIMARY)
	body_vbox.add_child(_title_lbl)

	_summary_lbl = Label.new()
	_summary_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary_lbl.add_theme_font_size_override("font_size", 15)
	_summary_lbl.add_theme_color_override("font_color", UiTheme.COL_INK_SECONDARY)
	body_vbox.add_child(_summary_lbl)

	_blocks_vbox = VBoxContainer.new()
	_blocks_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_blocks_vbox.add_theme_constant_override("separation", 8)
	body_vbox.add_child(_blocks_vbox)


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


func select_tab_by_id(tab_id: String) -> void:
	for i: int in range(_sections.size()):
		if str(_sections[i].get("id", "")) == tab_id:
			_select_index(i)
			return


func _on_tab_pressed(idx: int) -> void:
	AudioManager.play_click()
	_select_index(idx)


func _select_index(idx: int) -> void:
	if idx < 0 or idx >= _sections.size():
		return
	var sec: Dictionary = _sections[idx]
	var active_id: String = str(sec.get("id", ""))
	for sid: String in _tab_buttons.keys():
		UiTheme.style_chip_button(_tab_buttons[sid], sid == active_id)

	_title_lbl.text = str(sec.get("title", ""))
	_summary_lbl.text = str(sec.get("summary", ""))

	for ch: Node in _blocks_vbox.get_children():
		ch.queue_free()

	var mono := UiTheme.make_mono_font()
	var blocks: Variant = sec.get("blocks", [])
	if blocks is Array:
		for blk: Variant in blocks as Array:
			if not (blk is Dictionary):
				continue
			var bdict := blk as Dictionary
			var p := PanelContainer.new()
			p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			UiTheme.style_monitor_panel(p, 12.0)
			_blocks_vbox.add_child(p)

			var bv := VBoxContainer.new()
			bv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			bv.add_theme_constant_override("separation", 6)
			p.add_child(bv)

			var bh := Label.new()
			bh.text = str(bdict.get("heading", ""))
			bh.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			bh.add_theme_color_override("font_color", UiTheme.COL_GOLD_BRIGHT)
			bh.add_theme_font_size_override("font_size", 16)
			bv.add_child(bh)

			var bb := Label.new()
			bb.text = str(bdict.get("body", ""))
			bb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			bb.add_theme_font_override("font", mono)
			bb.add_theme_font_size_override("font_size", 15)
			bb.add_theme_color_override("font_color", UiTheme.COL_TEXT_PRIMARY)
			bv.add_child(bb)
