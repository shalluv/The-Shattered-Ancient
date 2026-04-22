extends Control

## Dota 2-style hotkey settings screen.
## Emits settings_closed when the player wants to go back.

signal settings_closed

var _listening_action: String = ""
var _listening_badge: Button = null
var _badges: Dictionary = {} # action -> Button
var _row_panels: Dictionary = {} # action -> PanelContainer
var _is_standalone: bool = false

var _hotkey_content: VBoxContainer = null
var _audio_content: VBoxContainer = null
var _hotkey_tab_btn: Button = null
var _audio_tab_btn: Button = null
var _hotkey_footer: HBoxContainer = null
var _sliders: Dictionary = {} # bus_name -> HSlider


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_is_standalone = (get_parent() == get_tree().root or get_parent() == get_tree().current_scene)
	_build_ui()


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
			target = "res://scenes/ui/MainMenu.tscn"
		SceneTransition.transition_to(target)
	else:
		settings_closed.emit()


# ── Build the full UI ───────────────────────────────────────

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.06, 0.07, 0.09, 0.97)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 60)
	margin.add_theme_constant_override("margin_right", 60)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 40)
	add_child(margin)

	var outer_vbox := VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 12)
	margin.add_child(outer_vbox)

	# Header
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 0)
	outer_vbox.add_child(header)

	var title := Label.new()
	title.text = "SETTINGS"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.82, 0.78, 0.65))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var back_btn := _make_back_button()
	back_btn.pressed.connect(_go_back)
	back_btn.button_down.connect(func() -> void:
		if not back_btn.disabled: AudioManager.play_sfx("ui_click")
	)
	back_btn.mouse_entered.connect(func() -> void:
		if not back_btn.disabled: AudioManager.play_sfx("ui_hover")
	)
	header.add_child(back_btn)

	# Tab bar
	var tab_bar := HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 0)
	outer_vbox.add_child(tab_bar)

	_hotkey_tab_btn = _make_tab_button("HOTKEYS", true)
	_hotkey_tab_btn.pressed.connect(_switch_to_hotkeys)
	_hotkey_tab_btn.button_down.connect(func() -> void:
		if not _hotkey_tab_btn.disabled: AudioManager.play_sfx("ui_click")
	)
	_hotkey_tab_btn.mouse_entered.connect(func() -> void:
		if not _hotkey_tab_btn.disabled: AudioManager.play_sfx("ui_hover")
	)
	tab_bar.add_child(_hotkey_tab_btn)

	_audio_tab_btn = _make_tab_button("AUDIO", false)
	_audio_tab_btn.pressed.connect(_switch_to_audio)
	_audio_tab_btn.button_down.connect(func() -> void:
		if not _audio_tab_btn.disabled: AudioManager.play_sfx("ui_click")
	)
	_audio_tab_btn.mouse_entered.connect(func() -> void:
		if not _audio_tab_btn.disabled: AudioManager.play_sfx("ui_hover")
	)
	tab_bar.add_child(_audio_tab_btn)

	# Header separator
	var header_sep := HSeparator.new()
	var hs_style := StyleBoxFlat.new()
	hs_style.bg_color = Color(0.22, 0.24, 0.28)
	hs_style.set_content_margin_all(0)
	header_sep.add_theme_stylebox_override("separator", hs_style)
	header_sep.add_theme_constant_override("separation", 8)
	outer_vbox.add_child(header_sep)

	# ── HOTKEYS content ──
	var hotkey_scroll := ScrollContainer.new()
	hotkey_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hotkey_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer_vbox.add_child(hotkey_scroll)

	_hotkey_content = VBoxContainer.new()
	_hotkey_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hotkey_content.add_theme_constant_override("separation", 24)
	hotkey_scroll.add_child(_hotkey_content)

	for category in SettingsManager.ACTION_CATEGORIES:
		_build_category(_hotkey_content, category, SettingsManager.ACTION_CATEGORIES[category])

	# Hotkey footer
	var footer_spacer := Control.new()
	footer_spacer.custom_minimum_size = Vector2(0, 10)
	outer_vbox.add_child(footer_spacer)

	_hotkey_footer = HBoxContainer.new()
	_hotkey_footer.alignment = BoxContainer.ALIGNMENT_END
	outer_vbox.add_child(_hotkey_footer)

	var reset_btn := _make_action_button("Reset to Defaults")
	reset_btn.pressed.connect(_on_reset_pressed)
	reset_btn.button_down.connect(func() -> void:
		if not reset_btn.disabled: AudioManager.play_sfx("ui_click")
	)
	reset_btn.mouse_entered.connect(func() -> void:
		if not reset_btn.disabled: AudioManager.play_sfx("ui_hover")
	)
	_hotkey_footer.add_child(reset_btn)

	# ── AUDIO content ──
	_audio_content = VBoxContainer.new()
	_audio_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_audio_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_audio_content.add_theme_constant_override("separation", 24)
	_audio_content.visible = false
	outer_vbox.add_child(_audio_content)

	_build_audio_panel()


# ── Category section ────────────────────────────────────────

func _build_category(parent: VBoxContainer, cat_name: String, actions: Array) -> void:
	var header := Label.new()
	header.text = cat_name
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	parent.add_child(header)

	var sep := HSeparator.new()
	var sep_style := StyleBoxFlat.new()
	sep_style.bg_color = Color(0.18, 0.20, 0.24)
	sep_style.set_content_margin_all(0)
	sep.add_theme_stylebox_override("separator", sep_style)
	sep.add_theme_constant_override("separation", 4)
	parent.add_child(sep)

	# Two-column layout
	var columns_box := HBoxContainer.new()
	columns_box.add_theme_constant_override("separation", 16)
	columns_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(columns_box)

	var left_col := VBoxContainer.new()
	left_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_col.add_theme_constant_override("separation", 2)
	columns_box.add_child(left_col)

	var right_col := VBoxContainer.new()
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_col.add_theme_constant_override("separation", 2)
	columns_box.add_child(right_col)

	for i in actions.size():
		var action: String = actions[i][0]
		var label_text: String = actions[i][1]
		var target_col := left_col if i % 2 == 0 else right_col
		_build_keybind_row(target_col, action, label_text)


func _build_keybind_row(parent: VBoxContainer, action: String, label_text: String) -> void:
	var row_panel := PanelContainer.new()
	row_panel.custom_minimum_size = Vector2(0, 38)

	var row_style := StyleBoxFlat.new()
	row_style.bg_color = Color(0.11, 0.12, 0.15)
	row_style.border_color = Color(0.18, 0.20, 0.24)
	row_style.set_border_width_all(1)
	row_style.set_corner_radius_all(2)
	row_style.set_content_margin_all(0)
	row_style.content_margin_left = 12
	row_style.content_margin_right = 8
	row_panel.add_theme_stylebox_override("panel", row_style)

	row_panel.mouse_entered.connect(func() -> void:
		row_style.bg_color = Color(0.15, 0.17, 0.22)
		row_panel.queue_redraw()
	)
	row_panel.mouse_exited.connect(func() -> void:
		row_style.bg_color = Color(0.11, 0.12, 0.15)
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
	name_label.add_theme_color_override("font_color", Color(0.72, 0.72, 0.72))
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(name_label)

	var badge := Button.new()
	badge.custom_minimum_size = Vector2(80, 30)
	badge.text = SettingsManager.get_event_text(action)
	badge.pressed.connect(_on_badge_pressed.bind(action, badge))
	badge.button_down.connect(func() -> void:
		if not badge.disabled: AudioManager.play_sfx("ui_click")
	)
	badge.mouse_entered.connect(func() -> void:
		if not badge.disabled: AudioManager.play_sfx("ui_hover")
	)
	_style_badge(badge, false)
	hbox.add_child(badge)
	_badges[action] = badge


func _style_badge(badge: Button, is_listening: bool) -> void:
	var bg_color: Color
	var border_color: Color
	var font_color: Color

	if is_listening:
		bg_color = Color(0.20, 0.22, 0.30)
		border_color = Color(0.55, 0.55, 0.70)
		font_color = Color(1.0, 0.95, 0.70)
	else:
		bg_color = Color(0.16, 0.17, 0.22)
		border_color = Color(0.28, 0.30, 0.36)
		font_color = Color(0.85, 0.85, 0.85)

	var normal := StyleBoxFlat.new()
	normal.bg_color = bg_color
	normal.border_color = border_color
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(3)
	normal.set_content_margin_all(4)
	badge.add_theme_stylebox_override("normal", normal)

	var hover := StyleBoxFlat.new()
	hover.bg_color = bg_color.lightened(0.08)
	hover.border_color = border_color.lightened(0.15)
	hover.set_border_width_all(1)
	hover.set_corner_radius_all(3)
	hover.set_content_margin_all(4)
	badge.add_theme_stylebox_override("hover", hover)

	var pressed_sb := StyleBoxFlat.new()
	pressed_sb.bg_color = bg_color.lightened(0.12)
	pressed_sb.border_color = border_color.lightened(0.2)
	pressed_sb.set_border_width_all(1)
	pressed_sb.set_corner_radius_all(3)
	pressed_sb.set_content_margin_all(4)
	badge.add_theme_stylebox_override("pressed", pressed_sb)

	badge.add_theme_color_override("font_color", font_color)
	badge.add_theme_color_override("font_hover_color", font_color.lightened(0.1))
	badge.add_theme_font_size_override("font_size", 14)


# ── Widget builders ─────────────────────────────────────────

func _make_back_button() -> Button:
	var btn := Button.new()
	btn.text = "✕"
	btn.custom_minimum_size = Vector2(40, 40)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	normal.set_content_margin_all(0)
	btn.add_theme_stylebox_override("normal", normal)
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.2, 0.2, 0.25)
	hover.set_corner_radius_all(4)
	hover.set_content_margin_all(0)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.4, 0.4))
	btn.add_theme_font_size_override("font_size", 22)
	return btn


func _make_tab_button(label_text: String, active: bool) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(120, 36)

	var style := StyleBoxFlat.new()
	if active:
		style.bg_color = Color(0.14, 0.15, 0.19)
		style.border_color = Color(0.30, 0.32, 0.38)
	else:
		style.bg_color = Color(0.08, 0.09, 0.12)
		style.border_color = Color(0.18, 0.20, 0.24)
	style.set_border_width_all(1)
	style.border_width_bottom = 0
	style.set_corner_radius_all(0)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.set_content_margin_all(8)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)

	var font_c := Color(0.82, 0.78, 0.65) if active else Color(0.45, 0.45, 0.45)
	btn.add_theme_color_override("font_color", font_c)
	btn.add_theme_color_override("font_hover_color", font_c.lightened(0.1))
	btn.add_theme_font_size_override("font_size", 14)
	return btn


func _make_action_button(label_text: String) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(180, 38)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.13, 0.14, 0.18)
	normal.border_color = Color(0.28, 0.30, 0.36)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)
	normal.set_content_margin_all(8)
	btn.add_theme_stylebox_override("normal", normal)

	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.18, 0.20, 0.26)
	hover.border_color = Color(0.45, 0.48, 0.55)
	hover.set_border_width_all(1)
	hover.set_corner_radius_all(4)
	hover.set_content_margin_all(8)
	btn.add_theme_stylebox_override("hover", hover)

	var pressed_sb := StyleBoxFlat.new()
	pressed_sb.bg_color = Color(0.22, 0.24, 0.30)
	pressed_sb.border_color = Color(0.50, 0.52, 0.58)
	pressed_sb.set_border_width_all(1)
	pressed_sb.set_corner_radius_all(4)
	pressed_sb.set_content_margin_all(8)
	btn.add_theme_stylebox_override("pressed", pressed_sb)

	btn.add_theme_color_override("font_color", Color(0.70, 0.68, 0.58))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.80))
	btn.add_theme_font_size_override("font_size", 14)
	return btn


# ── Tab switching ──────────────────────────────────────────

func _switch_to_hotkeys() -> void:
	_hotkey_content.get_parent().visible = true
	_hotkey_footer.visible = true
	_hotkey_footer.get_parent().get_child(_hotkey_footer.get_index() - 1).visible = true
	_audio_content.visible = false
	_update_tab_style(_hotkey_tab_btn, true)
	_update_tab_style(_audio_tab_btn, false)


func _switch_to_audio() -> void:
	_hotkey_content.get_parent().visible = false
	_hotkey_footer.visible = false
	_hotkey_footer.get_parent().get_child(_hotkey_footer.get_index() - 1).visible = false
	_audio_content.visible = true
	_update_tab_style(_hotkey_tab_btn, false)
	_update_tab_style(_audio_tab_btn, true)


func _update_tab_style(btn: Button, active: bool) -> void:
	var style := StyleBoxFlat.new()
	if active:
		style.bg_color = Color(0.14, 0.15, 0.19)
		style.border_color = Color(0.30, 0.32, 0.38)
	else:
		style.bg_color = Color(0.08, 0.09, 0.12)
		style.border_color = Color(0.18, 0.20, 0.24)
	style.set_border_width_all(1)
	style.border_width_bottom = 0
	style.set_corner_radius_all(0)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.set_content_margin_all(8)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	var font_c := Color(0.82, 0.78, 0.65) if active else Color(0.45, 0.45, 0.45)
	btn.add_theme_color_override("font_color", font_c)
	btn.add_theme_color_override("font_hover_color", font_c.lightened(0.1))


# ── Audio panel ────────────────────────────────────────────

func _build_audio_panel() -> void:
	var volume_header := Label.new()
	volume_header.text = "VOLUME"
	volume_header.add_theme_font_size_override("font_size", 18)
	volume_header.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	_audio_content.add_child(volume_header)

	var sep := HSeparator.new()
	var sep_style := StyleBoxFlat.new()
	sep_style.bg_color = Color(0.18, 0.20, 0.24)
	sep_style.set_content_margin_all(0)
	sep.add_theme_stylebox_override("separator", sep_style)
	sep.add_theme_constant_override("separation", 4)
	_audio_content.add_child(sep)

	_build_volume_slider("Overall", "Master")
	_build_volume_slider("Music", "Music")
	_build_volume_slider("SFX", "SFX")


func _build_volume_slider(label_text: String, bus_name: String) -> void:
	var row_panel := PanelContainer.new()
	row_panel.custom_minimum_size = Vector2(0, 48)

	var row_style := StyleBoxFlat.new()
	row_style.bg_color = Color(0.11, 0.12, 0.15)
	row_style.border_color = Color(0.18, 0.20, 0.24)
	row_style.set_border_width_all(1)
	row_style.set_corner_radius_all(2)
	row_style.set_content_margin_all(0)
	row_style.content_margin_left = 16
	row_style.content_margin_right = 16
	row_panel.add_theme_stylebox_override("panel", row_style)

	row_panel.mouse_entered.connect(func() -> void:
		row_style.bg_color = Color(0.15, 0.17, 0.22)
		row_panel.queue_redraw()
	)
	row_panel.mouse_exited.connect(func() -> void:
		row_style.bg_color = Color(0.11, 0.12, 0.15)
		row_panel.queue_redraw()
	)
	_audio_content.add_child(row_panel)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	row_panel.add_child(hbox)

	var name_label := Label.new()
	name_label.text = label_text
	name_label.custom_minimum_size = Vector2(100, 0)
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", Color(0.72, 0.72, 0.72))
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(name_label)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.value = AudioManager.get_bus_volume(bus_name) * 100.0
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(200, 0)

	var slider_style := StyleBoxFlat.new()
	slider_style.bg_color = Color(0.2, 0.22, 0.28)
	slider_style.set_corner_radius_all(4)
	slider_style.set_content_margin_all(0)
	slider_style.content_margin_top = 12
	slider_style.content_margin_bottom = 12
	slider.add_theme_stylebox_override("slider", slider_style)

	var grabber_style := StyleBoxFlat.new()
	grabber_style.bg_color = Color(0.35, 0.38, 0.48)
	grabber_style.set_corner_radius_all(4)
	grabber_style.set_content_margin_all(0)
	grabber_style.content_margin_top = 12
	grabber_style.content_margin_bottom = 12
	slider.add_theme_stylebox_override("grabber_area", grabber_style)

	var grabber_hl := StyleBoxFlat.new()
	grabber_hl.bg_color = Color(0.45, 0.48, 0.58)
	grabber_hl.set_corner_radius_all(4)
	grabber_hl.set_content_margin_all(0)
	grabber_hl.content_margin_top = 12
	grabber_hl.content_margin_bottom = 12
	slider.add_theme_stylebox_override("grabber_area_highlight", grabber_hl)

	hbox.add_child(slider)
	_sliders[bus_name] = slider

	var value_label := Label.new()
	value_label.text = "%d" % int(slider.value)
	value_label.custom_minimum_size = Vector2(40, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_font_size_override("font_size", 15)
	value_label.add_theme_color_override("font_color", Color(0.82, 0.78, 0.65))
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(value_label)

	slider.value_changed.connect(func(val: float) -> void:
		AudioManager.set_bus_volume(bus_name, val / 100.0)
		value_label.text = "%d" % int(val)
	)


# ── Keybinding logic ───────────────────────────────────────

func _on_badge_pressed(action: String, badge: Button) -> void:
	if _listening_action != "":
		_cancel_listening()

	_listening_action = action
	_listening_badge = badge
	badge.text = "..."
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
