class_name UiTheme
extends RefCounted
## Sistem Tema Retro Pixel Art 128-bit Dark Stardew-Craft (Endesga-32 palette, bingkai bevel ber-rivet emas, WCAG AA).

# Core #1: Deep Pixel Indigo & Carved Slate-Blue RPG Panels
const COL_BG_CANVAS := Color("#181425")
const COL_HEADER_BG := Color("#1F233A")
const COL_PANEL_BG := Color("#262B44")
const COL_PANEL_GOLD_BG := Color("#292F4B")
const COL_PANEL_BEVEL_HI := Color("#607294")
const COL_PANEL_BEVEL_SH := Color("#181B2B")
const COL_SLATE := Color("#3A4466")

# Core #2: Royal Pixel Blue & Deep CRT Ink
const COL_MONITOR_BG := Color("#12171D")
const COL_BLUE := Color("#2B59C3")
const COL_BLUE_HOVER := Color("#3366D9")
const COL_BLUE_PRESSED := Color("#1F449C")

# Single Deliberate Accent: Arcade Honey Gold
const COL_GOLD := Color("#FEAE34")
const COL_GOLD_BRIGHT := Color("#FEE761")
const COL_GOLD_PRESSED := Color("#E48E24")

# Text Neutrals (Warm Pixel Cream & Cool Silver)
const COL_TEXT_PRIMARY := Color("#FFF5E4")
const COL_TEXT_SECONDARY := Color("#C0CBDC")
const COL_TEXT_DARK := Color("#181425")
const COL_WHITE := Color("#FFFFFF")

# Semantic Status Only (selalu dipasangkan dengan label [OK]/[ERR]/[ALLOW]/[DENY]/[INFO])
const COL_SUCCESS := Color("#63C74D")
const COL_SUCCESS_BG := Color("#142B1D")
const COL_ERROR := Color("#FF8599")
const COL_ERROR_BG := Color("#3B1522")
const COL_INFO := Color("#87E0FF")
const COL_INFO_BG := Color("#1A2742")
const COL_WARN := Color("#FEE761")

# Panel & compatibility ink aliases (semua permukaan panel bernuansa gelap sehingga ink tetap terang & kontras tinggi)
const COL_INK_PRIMARY := COL_TEXT_PRIMARY
const COL_INK_SECONDARY := COL_TEXT_SECONDARY
const COL_INK_ACCENT := COL_GOLD_BRIGHT
const COL_INK_SUCCESS := COL_SUCCESS
const COL_INK_ERROR := COL_ERROR
const COL_INK_INFO := COL_INFO

const COL_SURFACE := COL_PANEL_BG
const COL_CRT_BG := COL_MONITOR_BG
const COL_BORDER := COL_PANEL_BEVEL_HI
const COL_BORDER_BRIGHT := COL_GOLD
const COL_TEXT_MUTED := COL_TEXT_SECONDARY
const COL_ACCENT_CYAN := COL_INFO
const COL_ACCENT_AMBER := COL_GOLD_BRIGHT
const COL_PS_YELLOW := COL_GOLD_BRIGHT
const COL_PS_NAVY := COL_BLUE

const ASSET_DIR := "res://assets/pixel_ui/"
const MIN_TAP_HEIGHT := 48

static var _tex_cache: Dictionary[String, Texture2D] = {}
static var _icon2x_cache: Dictionary[String, Texture2D] = {}
static var _pixel_font_cache: Font = null
static var _mono_font_cache: SystemFont = null


static func _load_tex(filename: String) -> Texture2D:
	if _tex_cache.has(filename):
		return _tex_cache[filename]
	var tex := load(ASSET_DIR + filename) as Texture2D
	if tex != null:
		_tex_cache[filename] = tex
	return tex


static func get_pixel_font() -> Font:
	if _pixel_font_cache == null:
		_pixel_font_cache = load(ASSET_DIR + "pixel_display.fnt") as Font
	return _pixel_font_cache


static func make_mono_font() -> SystemFont:
	if _mono_font_cache == null:
		var sf := SystemFont.new()
		sf.font_names = PackedStringArray(["Cascadia Mono", "Consolas", "DejaVu Sans Mono", "Liberation Mono", "monospace"])
		_mono_font_cache = sf
	return _mono_font_cache


static func get_icon_2x(icon_name: String, scale_factor: int = 2) -> Texture2D:
	var cache_key := "%s@%dx" % [icon_name, scale_factor]
	if _icon2x_cache.has(cache_key):
		return _icon2x_cache[cache_key]
	var fname := icon_name if icon_name.ends_with(".png") else ("ico_%s.png" % icon_name)
	var base_tex := _load_tex(fname)
	if base_tex == null:
		return null
	var img := base_tex.get_image()
	if img == null:
		return base_tex
	var copy_img := img.duplicate() as Image
	copy_img.resize(copy_img.get_width() * scale_factor, copy_img.get_height() * scale_factor, Image.INTERPOLATE_NEAREST)
	var out_tex := ImageTexture.create_from_image(copy_img)
	_icon2x_cache[cache_key] = out_tex
	return out_tex


static func make_icon_rect(icon_name: String, display_px: int = 32) -> TextureRect:
	var fname := icon_name if icon_name.ends_with(".png") else ("ico_%s.png" % icon_name)
	var tr := TextureRect.new()
	tr.texture = _load_tex(fname)
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = Vector2(display_px, display_px)
	tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


static func make_tiled_background() -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = _load_tex("bg_tile.png")
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.stretch_mode = TextureRect.STRETCH_TILE
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


static func make_9slice(
	filename: String,
	slice_margin: float = 9.0,
	pad_h: float = 12.0,
	pad_top: float = 10.0,
	pad_bottom: float = 10.0
) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = _load_tex(filename)
	sb.texture_margin_left = slice_margin
	sb.texture_margin_top = slice_margin
	sb.texture_margin_right = slice_margin
	sb.texture_margin_bottom = slice_margin
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	sb.content_margin_left = pad_h
	sb.content_margin_right = pad_h
	sb.content_margin_top = pad_top
	sb.content_margin_bottom = pad_bottom
	return sb


static func make_focus_box() -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = _load_tex("btn_focus.png")
	sb.texture_margin_left = 6.0
	sb.texture_margin_top = 6.0
	sb.texture_margin_right = 6.0
	sb.texture_margin_bottom = 6.0
	sb.expand_margin_left = 3.0
	sb.expand_margin_top = 3.0
	sb.expand_margin_right = 3.0
	sb.expand_margin_bottom = 3.0
	sb.draw_center = false
	return sb


static func make_box(
	bg: Color,
	border: Color,
	border_w: int = 2,
	radius: int = 0,
	pad: int = 10
) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	if pad > 0:
		sb.set_content_margin_all(pad)
	return sb


static func create_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 16

	t.set_color("font_color", "Label", COL_TEXT_PRIMARY)
	t.set_color("default_color", "RichTextLabel", COL_TEXT_PRIMARY)

	t.set_stylebox("panel", "PanelContainer", make_9slice("panel_rpg.png", 9.0, 14.0, 12.0, 12.0))

	# Default Button = Royal Pixel Blue tactile 3D button
	t.set_stylebox("normal", "Button", make_9slice("btn_blue_normal.png", 8.0, 12.0, 8.0, 11.0))
	t.set_stylebox("hover", "Button", make_9slice("btn_blue_hover.png", 8.0, 12.0, 8.0, 11.0))
	t.set_stylebox("pressed", "Button", make_9slice("btn_blue_pressed.png", 8.0, 12.0, 11.0, 8.0))
	t.set_stylebox("focus", "Button", make_focus_box())
	t.set_stylebox("disabled", "Button", make_box(Color("#1D2136"), Color("#3A4466"), 2, 0, 10))
	t.set_color("font_color", "Button", COL_WHITE)
	t.set_color("font_hover_color", "Button", COL_WHITE)
	t.set_color("font_pressed_color", "Button", COL_WHITE)
	t.set_color("font_focus_color", "Button", COL_WHITE)
	t.set_color("font_disabled_color", "Button", COL_TEXT_SECONDARY)
	t.set_font_size("font_size", "Button", 15)
	t.set_constant("h_separation", "Button", 8)

	# LineEdit = Recessed Dark CRT Input
	t.set_stylebox("normal", "LineEdit", make_9slice("input_box.png", 8.0, 12.0, 10.0, 10.0))
	t.set_stylebox("focus", "LineEdit", make_9slice("input_box_focus.png", 8.0, 12.0, 10.0, 10.0))
	t.set_color("font_color", "LineEdit", COL_TEXT_PRIMARY)
	t.set_color("font_placeholder_color", "LineEdit", COL_TEXT_SECONDARY)
	t.set_color("caret_color", "LineEdit", COL_GOLD_BRIGHT)
	t.set_font_size("font_size", "LineEdit", 16)

	# ProgressBar = Recessed monitor trough + glowing Gold fill
	var pb_bg := make_9slice("pb_track.png", 4.0, 0.0, 0.0, 0.0)
	var pb_fg := make_9slice("pb_fill.png", 4.0, 0.0, 0.0, 0.0)
	t.set_stylebox("background", "ProgressBar", pb_bg)
	t.set_stylebox("fill", "ProgressBar", pb_fg)

	return t


static func style_header_panel(panel: PanelContainer, pad: float = 8.0) -> void:
	panel.add_theme_stylebox_override("panel", make_9slice("panel_header.png", 9.0, pad, pad, pad + 3.0))


static func apply_centered_margins(margin_node: MarginContainer, max_width: float = 980.0, base_pad: int = 14) -> void:
	AdaptiveLayout.apply_safe_area_margin(margin_node, base_pad)
	if not is_instance_valid(margin_node) or not margin_node.is_inside_tree():
		return
	var vp := margin_node.get_viewport()
	if vp == null:
		return
	var vp_size := vp.get_visible_rect().size
	var pad_x: int = 10 if AdaptiveLayout.is_compact(vp_size) else base_pad
	var extra_x: int = maxi(0, int((vp_size.x - max_width) * 0.5))
	var final_x: int = maxi(pad_x, extra_x)
	margin_node.add_theme_constant_override("margin_left", final_x)
	margin_node.add_theme_constant_override("margin_right", final_x)


static func style_pixel_heading(
	lbl: Label,
	px_size: int = 16,
	col: Color = COL_GOLD_BRIGHT,
	with_shadow: bool = true
) -> void:
	var pf := get_pixel_font()
	if pf != null:
		lbl.add_theme_font_override("font", pf)
	lbl.add_theme_font_size_override("font_size", px_size)
	lbl.add_theme_color_override("font_color", col)
	if with_shadow:
		lbl.add_theme_color_override("font_shadow_color", COL_BG_CANVAS)
		lbl.add_theme_constant_override("shadow_offset_x", 0)
		lbl.add_theme_constant_override("shadow_offset_y", 2)
		lbl.add_theme_constant_override("shadow_outline_size", 2)
	else:
		lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
		lbl.add_theme_constant_override("shadow_offset_x", 0)
		lbl.add_theme_constant_override("shadow_offset_y", 0)
		lbl.add_theme_constant_override("shadow_outline_size", 0)


static func style_parchment_heading(lbl: Label, px_size: int = 16, col: Color = COL_GOLD_BRIGHT) -> void:
	style_pixel_heading(lbl, px_size, col, true)


static func style_gold_button(btn: Button, icon_name: String = "", use_pixel_font: bool = true) -> void:
	btn.custom_minimum_size = Vector2(maxf(btn.custom_minimum_size.x, 112.0), MIN_TAP_HEIGHT)
	btn.add_theme_stylebox_override("normal", make_9slice("btn_gold_normal.png", 8.0, 14.0, 9.0, 12.0))
	btn.add_theme_stylebox_override("hover", make_9slice("btn_gold_hover.png", 8.0, 14.0, 9.0, 12.0))
	btn.add_theme_stylebox_override("pressed", make_9slice("btn_gold_pressed.png", 8.0, 14.0, 12.0, 9.0))
	btn.add_theme_stylebox_override("focus", make_focus_box())
	btn.add_theme_color_override("font_color", COL_TEXT_DARK)
	btn.add_theme_color_override("font_hover_color", COL_TEXT_DARK)
	btn.add_theme_color_override("font_pressed_color", COL_TEXT_DARK)
	btn.add_theme_color_override("font_focus_color", COL_TEXT_DARK)
	if use_pixel_font and get_pixel_font() != null:
		btn.add_theme_font_override("font", get_pixel_font())
		btn.add_theme_font_size_override("font_size", 16)
	if not icon_name.is_empty():
		btn.icon = get_icon_2x(icon_name, 2)
		btn.expand_icon = false
	attach_button_feel(btn)


static func style_blue_button(btn: Button, icon_name: String = "", use_pixel_font: bool = false) -> void:
	btn.custom_minimum_size = Vector2(maxf(btn.custom_minimum_size.x, 48.0), MIN_TAP_HEIGHT)
	btn.add_theme_stylebox_override("normal", make_9slice("btn_blue_normal.png", 8.0, 12.0, 8.0, 11.0))
	btn.add_theme_stylebox_override("hover", make_9slice("btn_blue_hover.png", 8.0, 12.0, 8.0, 11.0))
	btn.add_theme_stylebox_override("pressed", make_9slice("btn_blue_pressed.png", 8.0, 12.0, 11.0, 8.0))
	btn.add_theme_stylebox_override("focus", make_focus_box())
	btn.add_theme_color_override("font_color", COL_WHITE)
	btn.add_theme_color_override("font_hover_color", COL_WHITE)
	btn.add_theme_color_override("font_pressed_color", COL_WHITE)
	btn.add_theme_color_override("font_focus_color", COL_WHITE)
	if use_pixel_font and get_pixel_font() != null:
		btn.add_theme_font_override("font", get_pixel_font())
		btn.add_theme_font_size_override("font_size", 16)
	if not icon_name.is_empty():
		btn.icon = get_icon_2x(icon_name, 2)
		btn.expand_icon = false
	attach_button_feel(btn)


static func style_primary_button(btn: Button) -> void:
	style_gold_button(btn, "", true)


static func style_secondary_button(btn: Button) -> void:
	style_blue_button(btn, "", false)


static func style_chip_button(btn: Button, selected: bool = false) -> void:
	btn.custom_minimum_size = Vector2(maxf(btn.custom_minimum_size.x, 64.0), MIN_TAP_HEIGHT)
	var norm_tex := "btn_chip_selected.png" if selected else "btn_chip_normal.png"
	var hov_tex := "btn_chip_selected.png" if selected else "btn_chip_hover.png"
	var prs_tex := "btn_blue_pressed.png" if selected else "btn_chip_pressed.png"
	btn.add_theme_stylebox_override("normal", make_9slice(norm_tex, 8.0, 12.0, 8.0, 11.0))
	btn.add_theme_stylebox_override("hover", make_9slice(hov_tex, 8.0, 12.0, 8.0, 11.0))
	btn.add_theme_stylebox_override("pressed", make_9slice(prs_tex, 8.0, 12.0, 11.0, 8.0))
	btn.add_theme_stylebox_override("focus", make_focus_box())
	var tc := COL_GOLD_BRIGHT if selected else COL_TEXT_PRIMARY
	btn.add_theme_color_override("font_color", tc)
	btn.add_theme_color_override("font_hover_color", COL_GOLD_BRIGHT if selected else COL_WHITE)
	btn.add_theme_color_override("font_pressed_color", tc)
	btn.add_theme_color_override("font_focus_color", tc)
	attach_button_feel(btn)


static func style_rpg_panel(panel: PanelContainer, pad: float = 14.0) -> void:
	panel.add_theme_stylebox_override("panel", make_9slice("panel_rpg.png", 9.0, pad, pad, pad))


static func style_monitor_panel(panel: PanelContainer, pad: float = 14.0) -> void:
	panel.add_theme_stylebox_override("panel", make_9slice("panel_monitor.png", 9.0, pad, pad, pad))


static func style_gold_panel(panel: PanelContainer, pad: float = 14.0) -> void:
	panel.add_theme_stylebox_override("panel", make_9slice("panel_gold.png", 9.0, pad, pad, pad))


static func style_feedback_panel(panel: PanelContainer, kind: String) -> void:
	var fname := "panel_feedback_info.png"
	if kind == "ok":
		fname = "panel_feedback_ok.png"
	elif kind == "err":
		fname = "panel_feedback_err.png"
	panel.add_theme_stylebox_override("panel", make_9slice(fname, 8.0, 12.0, 10.0, 10.0))


static func style_crt_panel(panel: PanelContainer) -> void:
	style_monitor_panel(panel, 14.0)


static func style_powershell_panel(panel: PanelContainer) -> void:
	style_gold_panel(panel, 14.0)


static func style_card_panel(panel: PanelContainer, _accent_border: Color = COL_PANEL_BEVEL_HI) -> void:
	style_rpg_panel(panel, 14.0)


static func compute_star_count(score_val: int, completed: bool) -> int:
	if score_val >= 90:
		return 3
	if score_val >= 70:
		return 2
	if score_val >= 40 or completed:
		return 1
	return 0


static func make_star_row(score_val: int, completed: bool, star_px: int = 24) -> HBoxContainer:
	var stars_lit := compute_star_count(score_val, completed)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 4)
	for i: int in range(3):
		var icon_id := "star_on" if i < stars_lit else "star_off"
		var tr := make_icon_rect(icon_id, star_px)
		hb.add_child(tr)
	return hb


static func attach_button_feel(btn: Button) -> void:
	btn.offset_transform_enabled = true
	if btn.has_meta("pixel_feel_wired"):
		return
	btn.set_meta("pixel_feel_wired", true)
	btn.pressed.connect(func() -> void:
		pulse_control(btn, 0.96, 0.11)
	)


static func pulse_control(ctrl: Control, start_scale: float = 0.97, dur: float = 0.13) -> void:
	if not is_instance_valid(ctrl) or not ctrl.is_inside_tree():
		return
	if ctrl.has_meta("_pulse_tw"):
		var old_tw: Variant = ctrl.get_meta("_pulse_tw")
		if old_tw is Tween and (old_tw as Tween).is_valid():
			(old_tw as Tween).kill()
	ctrl.offset_transform_enabled = true
	ctrl.offset_transform_scale = Vector2(start_scale, start_scale)
	var tw := ctrl.create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(ctrl, "offset_transform_scale", Vector2.ONE, dur) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	ctrl.set_meta("_pulse_tw", tw)


static func shake_control(ctrl: Control, amplitude: float = 8.0) -> void:
	if not is_instance_valid(ctrl) or not ctrl.is_inside_tree():
		return
	if ctrl.has_meta("_shake_tw"):
		var old_tw: Variant = ctrl.get_meta("_shake_tw")
		if old_tw is Tween and (old_tw as Tween).is_valid():
			(old_tw as Tween).kill()
	ctrl.offset_transform_enabled = true
	ctrl.offset_transform_position = Vector2.ZERO
	var tw := ctrl.create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(ctrl, "offset_transform_position", Vector2(amplitude, 0.0), 0.045)
	tw.tween_property(ctrl, "offset_transform_position", Vector2(-amplitude * 0.75, 0.0), 0.045)
	tw.tween_property(ctrl, "offset_transform_position", Vector2(amplitude * 0.45, 0.0), 0.045)
	tw.tween_property(ctrl, "offset_transform_position", Vector2(-amplitude * 0.2, 0.0), 0.04)
	tw.tween_property(ctrl, "offset_transform_position", Vector2.ZERO, 0.04)
	ctrl.set_meta("_shake_tw", tw)


static func pop_star(ctrl: Control, delay_sec: float = 0.0) -> void:
	if not is_instance_valid(ctrl) or not ctrl.is_inside_tree():
		return
	ctrl.offset_transform_enabled = true
	ctrl.offset_transform_scale = Vector2(0.2, 0.2)
	var tw := ctrl.create_tween()
	tw.set_ignore_time_scale(true)
	if delay_sec > 0.0:
		tw.tween_interval(delay_sec)
	tw.tween_property(ctrl, "offset_transform_scale", Vector2.ONE, 0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
