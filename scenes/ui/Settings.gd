extends Control

## Hotkey settings screen. Used standalone (from the Lobby) and embedded
## inside the in-game pause menu. Standalone mode shows the full mystic
## background; embedded mode uses a subtle dark backdrop so the gameplay
## stays visible behind the pause menu.

signal settings_closed

const MysticBackground = preload("res://scenes/ui/MysticBackground.gd")

const GOLD := Color(0.85, 0.7, 0.3, 1.0)
const GOLD_BRIGHT := Color(1.0, 0.92, 0.65, 1.0)
const GOLD_SOFT := Color(0.78, 0.74, 0.60, 1.0)
const PARCHMENT := Color(0.94, 0.92, 0.84, 1.0)
const PANEL_DARK := Color(0.08, 0.09, 0.12, 0.92)

var _listening_action: String = ""
var _listening_badge: Button = null
var _badges: Dictionary = {}
var _row_panels: Dictionary = {}
var _is_standalone: bool = false
var _ui_root: Control = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_is_standalone = (get_parent() == get_tree().root or get_parent() == get_tree().current_scene)
	_build_ui()
	_animate_fade_in()


func _unhandled_input(event: InputEvent) -> void:
	if _listening_action != "":
		if event is InputEventKey and event.pressed:
			if event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE:
				_cancel_listening()
				get_viewport().set_input_as_handled()
				return
			SettingsManager.rebind_action(_listening_action, event)
			_finish_listening()
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and event.pressed:
			SettingsManager.rebind_action(_listening_action, event)
			_finish_listening()
			get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_cancel") and _is_standalone:
		_go_back()
		get_viewport().set_input_as_handled()


func _go_back() -> void:
	if _is_standalone:
		var target := SceneTransition.previous_scene_path
		if target == "" or target == scene_file_path:
			target = "res://scenes/lobby/Lobby.tscn"
		SceneTransition.transition_to(target)
	else:
		settings_closed.emit()


# ── Build the full UI ───────────────────────────────────────

func _build_ui() -> void:
	_build_background()

	_ui_root = Control.new()
	_ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ui_root)

	if _is_standalone:
		_build_title()

	_build_main_panel()
	_build_button_bar()


func _build_background() -> void:
	if _is_standalone:
		var bg := MysticBackground.new()
		bg.show_rune_circle = false
		add_child(bg)
	else:
		var bg := ColorRect.new()
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.color = Color(0.04, 0.05, 0.08, 0.92)
		add_child(bg)


func _build_title() -> void:
	var title_container := VBoxContainer.new()
	title_container.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title_container.offset_left = -400
	title_container.offset_right = 400
	title_container.offset_top = 30
	title_container.offset_bottom = 140
	title_container.alignment = BoxContainer.ALIGNMENT_CENTER
	title_container.add_theme_constant_override("separation", 4)
	title_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_root.add_child(title_container)

	var kicker := Label.new()
	kicker.text = "— A T T U N E M E N T —"
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kicker.add_theme_color_override("font_color", Color(0.7, 0.65, 0.50, 0.7))
	kicker.add_theme_font_size_override("font_size", 16)
	kicker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_container.add_child(kicker)

	var title := Label.new()
	title.text = "BINDINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", GOLD_BRIGHT)
	title.add_theme_font_size_override("font_size", 42)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_container.add_child(title)

	var ornament := TitleOrnamentDrawer.new()
	ornament.custom_minimum_size = Vector2(400, 18)
	ornament.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ornament.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_container.add_child(ornament)


class TitleOrnamentDrawer extends Control:
	func _draw() -> void:
		var gold := Color(0.85, 0.7, 0.3, 0.6)
		var cx: float = size.x / 2.0
		var cy: float = size.y / 2.0
		draw_line(Vector2(cx - 150, cy), Vector2(cx + 150, cy), gold, 1.0, true)
		var pts := PackedVector2Array([
			Vector2(cx, cy - 5), Vector2(cx + 5, cy),
			Vector2(cx, cy + 5), Vector2(cx - 5, cy),
		])
		draw_colored_polygon(pts, gold)
		draw_circle(Vector2(cx - 150, cy), 2.5, gold)
		draw_circle(Vector2(cx + 150, cy), 2.5, gold)
		for offset in [-80.0, -40.0, 40.0, 80.0]:
			draw_line(Vector2(cx + offset, cy - 3), Vector2(cx + offset, cy + 3), Color(gold, 0.4), 1.0)


# ── Main panel ─────────────────────────────────────────────

func _build_main_panel() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	if _is_standalone:
		panel.offset_left = 80
		panel.offset_right = -80
		panel.offset_top = 170
		panel.offset_bottom = -110
	else:
		panel.offset_left = 80
		panel.offset_right = -80
		panel.offset_top = 60
		panel.offset_bottom = -110

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = PANEL_DARK
	panel_style.border_color = Color(0.55, 0.50, 0.35, 0.55)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(6)
	panel_style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", panel_style)
	_ui_root.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	# Embedded mode: small inline title since we don't have the big top title
	if not _is_standalone:
		var inline_title := Label.new()
		inline_title.text = "BINDINGS"
		inline_title.add_theme_color_override("font_color", GOLD_BRIGHT)
		inline_title.add_theme_font_size_override("font_size", 24)
		vbox.add_child(inline_title)

		var sub_div := DividerDrawer.new()
		sub_div.custom_minimum_size = Vector2(0, 4)
		vbox.add_child(sub_div)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 22)
	scroll.add_child(content)

	for category in SettingsManager.ACTION_CATEGORIES:
		_build_category(content, category, SettingsManager.ACTION_CATEGORIES[category])


# ── Category section ────────────────────────────────────────

func _build_category(parent: VBoxContainer, cat_name: String, actions: Array) -> void:
	var header_box := HBoxContainer.new()
	header_box.add_theme_constant_override("separation", 10)
	parent.add_child(header_box)

	var diamond := DiamondMarkDrawer.new()
	diamond.custom_minimum_size = Vector2(10, 10)
	diamond.color = GOLD
	header_box.add_child(diamond)

	var header := Label.new()
	header.text = cat_name.to_upper()
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", GOLD_SOFT)
	header_box.add_child(header)

	var divider := DividerDrawer.new()
	divider.custom_minimum_size = Vector2(0, 4)
	parent.add_child(divider)

	var columns_box := HBoxContainer.new()
	columns_box.add_theme_constant_override("separation", 18)
	columns_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(columns_box)

	var left_col := VBoxContainer.new()
	left_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_col.add_theme_constant_override("separation", 4)
	columns_box.add_child(left_col)

	var right_col := VBoxContainer.new()
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_col.add_theme_constant_override("separation", 4)
	columns_box.add_child(right_col)

	for i in actions.size():
		var action: String = actions[i][0]
		var label_text: String = actions[i][1]
		var target_col := left_col if i % 2 == 0 else right_col
		_build_keybind_row(target_col, action, label_text)


func _build_keybind_row(parent: VBoxContainer, action: String, label_text: String) -> void:
	var row_panel := PanelContainer.new()
	row_panel.custom_minimum_size = Vector2(0, 40)

	var row_style := StyleBoxFlat.new()
	row_style.bg_color = Color(0.10, 0.11, 0.14, 0.55)
	row_style.border_color = Color(0.40, 0.35, 0.22, 0.4)
	row_style.set_border_width_all(1)
	row_style.set_corner_radius_all(4)
	row_style.set_content_margin_all(0)
	row_style.content_margin_left = 14
	row_style.content_margin_right = 8
	row_panel.add_theme_stylebox_override("panel", row_style)

	row_panel.mouse_entered.connect(func() -> void:
		row_style.bg_color = Color(0.16, 0.16, 0.20, 0.7)
		row_style.border_color = Color(0.65, 0.55, 0.28, 0.6)
		row_panel.queue_redraw()
	)
	row_panel.mouse_exited.connect(func() -> void:
		row_style.bg_color = Color(0.10, 0.11, 0.14, 0.55)
		row_style.border_color = Color(0.40, 0.35, 0.22, 0.4)
		row_panel.queue_redraw()
	)
	parent.add_child(row_panel)
	_row_panels[action] = row_panel

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	row_panel.add_child(hbox)

	var name_label := Label.new()
	name_label.text = label_text
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", PARCHMENT)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(name_label)

	var badge := Button.new()
	badge.custom_minimum_size = Vector2(96, 30)
	badge.text = SettingsManager.get_event_text(action)
	badge.pressed.connect(_on_badge_pressed.bind(action, badge))
	_style_badge(badge, false)
	hbox.add_child(badge)
	_badges[action] = badge


func _style_badge(badge: Button, is_listening: bool) -> void:
	var bg_color: Color
	var border_color: Color
	var font_color: Color

	if is_listening:
		bg_color = Color(0.20, 0.18, 0.12, 0.95)
		border_color = Color(1.0, 0.85, 0.40, 0.95)
		font_color = GOLD_BRIGHT
	else:
		bg_color = Color(0.06, 0.07, 0.10, 0.95)
		border_color = Color(0.55, 0.50, 0.35, 0.7)
		font_color = GOLD_SOFT

	var normal := StyleBoxFlat.new()
	normal.bg_color = bg_color
	normal.border_color = border_color
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(3)
	normal.set_content_margin_all(4)
	badge.add_theme_stylebox_override("normal", normal)

	var hover := StyleBoxFlat.new()
	hover.bg_color = bg_color.lightened(0.06)
	hover.border_color = Color(0.85, 0.7, 0.3, 0.9)
	hover.set_border_width_all(1)
	hover.set_corner_radius_all(3)
	hover.set_content_margin_all(4)
	badge.add_theme_stylebox_override("hover", hover)

	var pressed_sb := StyleBoxFlat.new()
	pressed_sb.bg_color = bg_color.lightened(0.10)
	pressed_sb.border_color = Color(1.0, 0.85, 0.40, 0.95)
	pressed_sb.set_border_width_all(1)
	pressed_sb.set_corner_radius_all(3)
	pressed_sb.set_content_margin_all(4)
	badge.add_theme_stylebox_override("pressed", pressed_sb)

	badge.add_theme_color_override("font_color", font_color)
	badge.add_theme_color_override("font_hover_color", GOLD_BRIGHT)
	badge.add_theme_font_size_override("font_size", 14)


# ── Bottom button bar ──────────────────────────────────────

func _build_button_bar() -> void:
	var bar_panel := PanelContainer.new()
	bar_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar_panel.offset_top = -90
	bar_panel.offset_bottom = 0

	var bar_style := StyleBoxFlat.new()
	bar_style.bg_color = Color(0.06, 0.07, 0.10, 0.95)
	bar_style.border_color = Color(0.45, 0.38, 0.20, 0.5)
	bar_style.border_width_top = 1
	bar_style.set_content_margin_all(0)
	bar_style.content_margin_top = 20
	bar_style.content_margin_bottom = 20
	bar_style.content_margin_left = 40
	bar_style.content_margin_right = 40
	bar_panel.add_theme_stylebox_override("panel", bar_style)
	_ui_root.add_child(bar_panel)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 20)
	bar_panel.add_child(hbox)

	var reset_btn := Button.new()
	reset_btn.text = "Reset to Defaults"
	reset_btn.custom_minimum_size = Vector2(180, 48)
	reset_btn.pressed.connect(_on_reset_pressed)
	_style_button(reset_btn)
	hbox.add_child(reset_btn)

	var back_btn := Button.new()
	back_btn.text = "Back" if not _is_standalone else "Back to Camp"
	back_btn.custom_minimum_size = Vector2(180, 48)
	back_btn.pressed.connect(_go_back)
	_style_button(back_btn)
	hbox.add_child(back_btn)


# ── Generic gold button styling ────────────────────────────

func _style_button(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.14, 0.13, 0.18, 0.9)
	normal.border_color = Color(0.55, 0.50, 0.35, 0.6)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)
	normal.set_content_margin_all(8)
	button.add_theme_stylebox_override("normal", normal)

	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.20, 0.18, 0.25, 0.95)
	hover.border_color = Color(0.75, 0.65, 0.30, 0.8)
	hover.set_border_width_all(1)
	hover.set_corner_radius_all(4)
	hover.set_content_margin_all(8)
	button.add_theme_stylebox_override("hover", hover)

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color(0.10, 0.09, 0.14, 0.95)
	pressed.border_color = Color(0.75, 0.65, 0.30, 0.8)
	pressed.set_border_width_all(1)
	pressed.set_corner_radius_all(4)
	pressed.set_content_margin_all(8)
	button.add_theme_stylebox_override("pressed", pressed)

	button.add_theme_color_override("font_color", Color(0.78, 0.74, 0.60))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.92, 0.65))
	button.add_theme_color_override("font_pressed_color", Color(0.9, 0.82, 0.55))
	button.add_theme_font_size_override("font_size", 17)

	button.button_down.connect(func() -> void:
		button.pivot_offset = button.size / 2.0
		var tw := button.create_tween()
		tw.tween_property(button, "scale", Vector2(0.95, 0.95), 0.05)
	)
	button.button_up.connect(func() -> void:
		var tw := button.create_tween()
		tw.tween_property(button, "scale", Vector2.ONE, 0.05)
	)


# ── Drawers ────────────────────────────────────────────────

class DividerDrawer extends Control:
	func _draw() -> void:
		var gold := Color(0.55, 0.50, 0.35, 0.5)
		var cy: float = size.y / 2.0
		draw_line(Vector2(0, cy), Vector2(size.x, cy), gold, 1.0)


class DiamondMarkDrawer extends Control:
	var color: Color = Color.WHITE
	func _draw() -> void:
		var c := size / 2.0
		var s: float = min(size.x, size.y) / 2.0 - 1.0
		var pts := PackedVector2Array([
			c + Vector2(0, -s),
			c + Vector2(s, 0),
			c + Vector2(0, s),
			c + Vector2(-s, 0),
		])
		draw_colored_polygon(pts, color)


# ── Fade in ────────────────────────────────────────────────

func _animate_fade_in() -> void:
	if _ui_root == null:
		return
	_ui_root.modulate.a = 0.0
	var tw := _ui_root.create_tween()
	tw.tween_property(_ui_root, "modulate:a", 1.0, 0.5).set_ease(Tween.EASE_OUT)


# ── Keybinding logic ───────────────────────────────────────

func _on_badge_pressed(action: String, badge: Button) -> void:
	if _listening_action != "":
		_cancel_listening()

	_listening_action = action
	_listening_badge = badge
	badge.text = "press a key…"
	_style_badge(badge, true)

	var tw := badge.create_tween()
	tw.set_loops()
	tw.tween_property(badge, "modulate:a", 0.5, 0.4)
	tw.tween_property(badge, "modulate:a", 1.0, 0.4)


func _finish_listening() -> void:
	if _listening_badge and is_instance_valid(_listening_badge):
		_listening_badge.modulate.a = 1.0
		_listening_badge.text = SettingsManager.get_event_text(_listening_action)
		_style_badge(_listening_badge, false)
	_listening_action = ""
	_listening_badge = null


func _cancel_listening() -> void:
	if _listening_badge and is_instance_valid(_listening_badge):
		_listening_badge.modulate.a = 1.0
		_listening_badge.text = SettingsManager.get_event_text(_listening_action)
		_style_badge(_listening_badge, false)
	_listening_action = ""
	_listening_badge = null


func _on_reset_pressed() -> void:
	SettingsManager.reset_to_defaults()
	for action in _badges:
		var badge: Button = _badges[action]
		badge.text = SettingsManager.get_event_text(action)
		_style_badge(badge, false)
