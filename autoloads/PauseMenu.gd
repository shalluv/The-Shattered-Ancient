extends Node

## Global pause menu – shows on ESC during gameplay.
## Registered as autoload "PauseMenu".

var _canvas_layer: CanvasLayer = null
var _overlay: ColorRect = null
var _panel: PanelContainer = null
var _is_open: bool = false
var _settings_instance: Control = null

const SETTINGS_SCENE := preload("res://scenes/ui/Settings.tscn")

# Scenes where the pause menu should NOT appear.
const EXCLUDED_SCENES: PackedStringArray = [
	"Lobby", "MetaUpgrades", "ArmyDraft", "GameOver",
	"PathChoice", "BoonSelection", "RunMapScreen", "MiniBossReward",
	"Settings",
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.layer = 150
	add_child(_canvas_layer)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _settings_instance and is_instance_valid(_settings_instance):
			_close_settings()
			get_viewport().set_input_as_handled()
			return
		if _is_open:
			_close()
		else:
			if _is_excluded_scene():
				return
			_open()
		get_viewport().set_input_as_handled()


func _is_excluded_scene() -> bool:
	var current := get_tree().current_scene
	if current == null:
		return true
	var scene_name := current.name
	for excluded in EXCLUDED_SCENES:
		if scene_name == excluded:
			return true
	return false


func _open() -> void:
	if _is_open:
		return
	_is_open = true
	get_tree().paused = true
	_build_ui()


func _close() -> void:
	if not _is_open:
		return
	_is_open = false
	get_tree().paused = false
	if _overlay and is_instance_valid(_overlay):
		_overlay.queue_free()
		_overlay = null
		_panel = null


# ── Build the pause overlay ────────────────────────────────

func _build_ui() -> void:
	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(0, 0, 0, 0.65)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas_layer.add_child(_overlay)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left = -220
	_panel.offset_top = -200
	_panel.offset_right = 220
	_panel.offset_bottom = 200

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.09, 0.12, 0.95)
	panel_style.border_color = Color(0.25, 0.27, 0.32)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(6)
	panel_style.set_content_margin_all(30)
	_panel.add_theme_stylebox_override("panel", panel_style)
	_overlay.add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	_panel.add_child(vbox)

	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.82, 0.78, 0.65))
	vbox.add_child(title)

	var sep := HSeparator.new()
	var sep_style := StyleBoxFlat.new()
	sep_style.bg_color = Color(0.25, 0.27, 0.32)
	sep_style.set_content_margin_all(0)
	sep.add_theme_stylebox_override("separator", sep_style)
	sep.add_theme_constant_override("separation", 12)
	vbox.add_child(sep)

	var resume_btn := _make_button("Resume")
	resume_btn.pressed.connect(_close)
	vbox.add_child(resume_btn)

	var settings_btn := _make_button("Settings")
	settings_btn.pressed.connect(_open_settings)
	vbox.add_child(settings_btn)

	var lobby_btn := _make_button("Back to Lobby")
	lobby_btn.pressed.connect(_on_lobby_pressed)
	vbox.add_child(lobby_btn)

	var quit_btn := _make_button("Quit Game")
	quit_btn.pressed.connect(_on_quit_pressed)
	vbox.add_child(quit_btn)

	_overlay.modulate.a = 0.0
	var tw := _overlay.create_tween()
	tw.tween_property(_overlay, "modulate:a", 1.0, 0.15)


func _make_button(label_text: String) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(260, 44)

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

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color(0.22, 0.24, 0.30)
	pressed.border_color = Color(0.50, 0.52, 0.58)
	pressed.set_border_width_all(1)
	pressed.set_corner_radius_all(4)
	pressed.set_content_margin_all(8)
	btn.add_theme_stylebox_override("pressed", pressed)

	btn.add_theme_color_override("font_color", Color(0.78, 0.76, 0.68))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.80))
	btn.add_theme_font_size_override("font_size", 18)

	btn.button_down.connect(func() -> void:
		if not btn.disabled: AudioManager.play_sfx("ui_click")
		btn.pivot_offset = btn.size / 2.0
		var tw := btn.create_tween()
		tw.tween_property(btn, "scale", Vector2(0.97, 0.97), 0.04)
	)
	btn.button_up.connect(func() -> void:
		var tw := btn.create_tween()
		tw.tween_property(btn, "scale", Vector2.ONE, 0.04)
	)
	btn.mouse_entered.connect(func() -> void:
		if not btn.disabled: AudioManager.play_sfx("ui_hover")
	)

	return btn


# ── Actions ─────────────────────────────────────────────────

func _open_settings() -> void:
	if _settings_instance and is_instance_valid(_settings_instance):
		return
	_settings_instance = SETTINGS_SCENE.instantiate()
	_settings_instance.process_mode = Node.PROCESS_MODE_ALWAYS
	_settings_instance.connect("settings_closed", _close_settings)
	_canvas_layer.add_child(_settings_instance)
	if _overlay:
		_overlay.visible = false


func _close_settings() -> void:
	if _settings_instance and is_instance_valid(_settings_instance):
		_settings_instance.queue_free()
		_settings_instance = null
	if _overlay:
		_overlay.visible = true


func _on_lobby_pressed() -> void:
	_close()
	SceneTransition.transition_to("res://scenes/lobby/Lobby.tscn")


func _on_quit_pressed() -> void:
	get_tree().quit()
