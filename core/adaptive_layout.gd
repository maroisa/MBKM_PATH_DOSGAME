class_name AdaptiveLayout
extends RefCounted
## Utilitas responsif lintas device (HP Portrait, Tablet, & Laptop/Desktop).

enum LayoutMode { COMPACT_PORTRAIT, MEDIUM_TABLET, WIDE_DESKTOP }


static func detect_mode(viewport_size: Vector2) -> LayoutMode:
	if viewport_size.x < 680.0 or (viewport_size.y > viewport_size.x * 1.05):
		return LayoutMode.COMPACT_PORTRAIT
	if viewport_size.x < 1024.0:
		return LayoutMode.MEDIUM_TABLET
	return LayoutMode.WIDE_DESKTOP


static func is_compact(viewport_size: Vector2) -> bool:
	return detect_mode(viewport_size) == LayoutMode.COMPACT_PORTRAIT


static func compute_grid_columns(viewport_size: Vector2, max_cols: int = 3) -> int:
	var mode: LayoutMode = detect_mode(viewport_size)
	match mode:
		LayoutMode.COMPACT_PORTRAIT:
			return 1
		LayoutMode.MEDIUM_TABLET:
			return mini(2, max_cols)
		_:
			return max_cols


static func apply_safe_area_margin(margin_node: MarginContainer, base_pad: int = 16) -> void:
	if not is_instance_valid(margin_node) or not margin_node.is_inside_tree():
		return
	var vp := margin_node.get_viewport()
	if vp == null:
		return
	var vp_size := vp.get_visible_rect().size
	var pad := 10 if is_compact(vp_size) else base_pad
	var safe := Rect2(DisplayServer.get_display_safe_area())
	var win := Rect2(Rect2i(DisplayServer.window_get_position(), DisplayServer.window_get_size()))
	var extra_top := 0
	var extra_bottom := 0
	if win.size.x > 0.0 and win.size.y > 0.0 and safe.size.x > 0.0 and safe.size.y > 0.0:
		var inner := safe.intersection(win)
		if inner.size.x > 0.0 and inner.size.y > 0.0:
			var scale_y := vp_size.y / win.size.y
			extra_top = maxi(0, int((inner.position.y - win.position.y) * scale_y))
			extra_bottom = maxi(0, int((win.end.y - inner.end.y) * scale_y))
	margin_node.add_theme_constant_override("margin_left", pad)
	margin_node.add_theme_constant_override("margin_right", pad)
	margin_node.add_theme_constant_override("margin_top", pad + extra_top)
	margin_node.add_theme_constant_override("margin_bottom", pad + extra_bottom)
