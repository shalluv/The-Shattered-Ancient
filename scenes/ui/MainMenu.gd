extends Control

@onready var begin_button: Button = $VBoxContainer/BeginButton
@onready var settings_button: Button = $VBoxContainer/SettingsButton
@onready var quit_button: Button = $VBoxContainer/QuitButton


func _ready() -> void:
	begin_button.pressed.connect(_on_begin_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	_style_button(begin_button)
	_style_button(settings_button)
	_style_button(quit_button)
	_setup_particles()
	_setup_version_label()


func _style_button(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.15, 0.15, 0.2)
	normal.border_color = Color(0.3, 0.3, 0.4)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)
	button.add_theme_stylebox_override("normal", normal)

	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.25, 0.25, 0.35)
	hover.border_color = Color(0.5, 0.5, 0.6)
	hover.set_border_width_all(1)
	hover.set_corner_radius_all(4)
	button.add_theme_stylebox_override("hover", hover)

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color(0.25, 0.25, 0.35)
	pressed.border_color = Color(0.5, 0.5, 0.6)
	pressed.set_border_width_all(1)
	pressed.set_corner_radius_all(4)
	button.add_theme_stylebox_override("pressed", pressed)

	button.button_down.connect(func() -> void:
		button.pivot_offset = button.size / 2.0
		var tw := button.create_tween()
		tw.tween_property(button, "scale", Vector2(0.95, 0.95), 0.05)
	)
	button.button_up.connect(func() -> void:
		var tw := button.create_tween()
		tw.tween_property(button, "scale", Vector2.ONE, 0.05)
	)


func _setup_version_label() -> void:
	var version := Label.new()
	version.text = "v0.10"
	version.add_theme_font_size_override("font_size", 14)
	version.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	version.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	version.position = Vector2(-60, -30)
	add_child(version)


func _on_begin_pressed() -> void:
	SceneTransition.transition_to("res://scenes/lobby/Lobby.tscn")


func _on_settings_pressed() -> void:
	SceneTransition.transition_to("res://scenes/ui/Settings.tscn")


func _on_quit_pressed() -> void:
	get_tree().quit()


func _setup_particles() -> void:
	var particles := GPUParticles2D.new()
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 30.0
	mat.initial_velocity_min = 10.0
	mat.initial_velocity_max = 25.0
	mat.gravity = Vector3(0, 0, 0)
	mat.scale_min = 1.0
	mat.scale_max = 2.5
	mat.color = Color(1.0, 0.843, 0.0, 0.4)
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(512, 384, 0)
	particles.process_material = mat
	particles.amount = 30
	particles.lifetime = 6.0
	particles.position = Vector2(512, 384)
	add_child(particles)
