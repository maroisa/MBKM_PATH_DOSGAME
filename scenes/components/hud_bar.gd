class_name HudBar
extends PanelContainer
## HUD 1 baris tipis khusus layar Minigame: [< MENU] | STAGE X (1/4) | SKOR | [? MATERI] | [SFX].

signal back_pressed
signal guide_pressed

var _row: HBoxContainer
var _back_btn: Button
var _info_box: BoxContainer
var _stage_lbl: Label
var _score_lbl: Label
var _guide_btn: Button
var _sfx_btn: Button

var _stage_num: int = 1
var _level_idx: int = 0
var _total_levels: int = 4
var _score_val: int = 0
var _is_compact: bool = false


func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTheme.style_header_panel(self, 8.0)

	_row = HBoxContainer.new()
	_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_row.add_theme_constant_override("separation", 6)
	add_child(_row)

	_back_btn = Button.new()
	_back_btn.text = "MENU"
	_back_btn.tooltip_text = "Kembali ke Peta Stage"
	UiTheme.style_blue_button(_back_btn, "back", true)
	_back_btn.custom_minimum_size = Vector2(96.0, UiTheme.MIN_TAP_HEIGHT)
	_back_btn.pressed.connect(func() -> void:
		AudioManager.play_click()
		back_pressed.emit()
	)
	_row.add_child(_back_btn)

	_info_box = BoxContainer.new()
	_info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_info_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_info_box.add_theme_constant_override("separation", 10)
	_row.add_child(_info_box)

	_stage_lbl = Label.new()
	_stage_lbl.text = "STAGE 1 (1/4)"
	_stage_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stage_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiTheme.style_pixel_heading(_stage_lbl, 16, UiTheme.COL_TEXT_PRIMARY)
	_info_box.add_child(_stage_lbl)

	_score_lbl = Label.new()
	_score_lbl.text = "SKOR: 0"
	_score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiTheme.style_pixel_heading(_score_lbl, 16, UiTheme.COL_GOLD_BRIGHT)
	_info_box.add_child(_score_lbl)

	_guide_btn = Button.new()
	_guide_btn.text = "MATERI"
	_guide_btn.tooltip_text = "Buka Buku Saku Materi DOS"
	UiTheme.style_blue_button(_guide_btn, "book", true)
	_guide_btn.custom_minimum_size = Vector2(106.0, UiTheme.MIN_TAP_HEIGHT)
	_guide_btn.pressed.connect(func() -> void:
		AudioManager.play_click()
		guide_pressed.emit()
	)
	_row.add_child(_guide_btn)

	_sfx_btn = Button.new()
	_sfx_btn.text = ""
	_sfx_btn.tooltip_text = "Aktifkan atau matikan efek suara"
	UiTheme.style_blue_button(_sfx_btn, "sound_on", false)
	_sfx_btn.custom_minimum_size = Vector2(52.0, UiTheme.MIN_TAP_HEIGHT)
	_sfx_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sfx_btn.pressed.connect(func() -> void:
		AudioManager.toggle_mute()
		_refresh_sfx_icon()
	)
	_row.add_child(_sfx_btn)


func _ready() -> void:
	if not AudioManager.mute_changed.is_connected(_on_mute_changed):
		AudioManager.mute_changed.connect(_on_mute_changed)
	_refresh_sfx_icon()


func configure(stage_number: int, level_idx: int, total_levels: int, score_val: int) -> void:
	_stage_num = maxi(1, stage_number)
	_level_idx = level_idx
	_total_levels = maxi(1, total_levels)
	_score_val = score_val
	_refresh_labels()


func set_compact_mode(compact: bool) -> void:
	_is_compact = compact
	_info_box.vertical = compact
	_info_box.add_theme_constant_override("separation", 2 if compact else 14)
	if compact:
		_back_btn.text = ""
		_back_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_back_btn.custom_minimum_size = Vector2(52.0, UiTheme.MIN_TAP_HEIGHT)
		_guide_btn.text = "?"
		_guide_btn.custom_minimum_size = Vector2(72.0, UiTheme.MIN_TAP_HEIGHT)
		_sfx_btn.custom_minimum_size = Vector2(52.0, UiTheme.MIN_TAP_HEIGHT)
	else:
		_back_btn.text = "MENU"
		_back_btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_back_btn.custom_minimum_size = Vector2(106.0, UiTheme.MIN_TAP_HEIGHT)
		_guide_btn.text = "MATERI"
		_guide_btn.custom_minimum_size = Vector2(124.0, UiTheme.MIN_TAP_HEIGHT)
		_sfx_btn.custom_minimum_size = Vector2(56.0, UiTheme.MIN_TAP_HEIGHT)
	_refresh_labels()


func _refresh_labels() -> void:
	var shown_lv := mini(_level_idx + 1, _total_levels)
	if _is_compact:
		_stage_lbl.text = "STG %d (%d/%d)" % [_stage_num, shown_lv, _total_levels]
		_score_lbl.text = "SKOR %d" % _score_val
	else:
		_stage_lbl.text = "STAGE %d (%d/%d)" % [_stage_num, shown_lv, _total_levels]
		_score_lbl.text = "SKOR: %d" % _score_val


func _on_mute_changed(_is_muted: bool) -> void:
	_refresh_sfx_icon()


func _refresh_sfx_icon() -> void:
	var ico_name := "sound_off" if AudioManager.muted else "sound_on"
	_sfx_btn.icon = UiTheme.get_icon_2x(ico_name, 2)
	_sfx_btn.tooltip_text = "Suara: OFF (Klik untuk nyalakan)" if AudioManager.muted else "Suara: ON (Klik untuk matikan)"


func get_initial_focus_control() -> Control:
	return _guide_btn
