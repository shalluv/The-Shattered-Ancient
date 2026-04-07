extends Control

var shard_label: Label = null
var dialogue_label: Label = null
var campfire: GPUParticles2D = null
var campfire_flicker_timer: float = 0.0


func _ready() -> void:
	_build_background()
	_build_campfire()
	_build_merchant()
	_build_ui()


func _process(delta: float) -> void:
	if campfire:
		campfire_flicker_timer -= delta
		if campfire_flicker_timer <= 0.0:
			campfire.amount = randi_range(20, 30)
			campfire_flicker_timer = 0.2


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


func _build_background() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.08, 0.05, 1.0)
	add_child(bg)


func _build_campfire() -> void:
	campfire = GPUParticles2D.new()
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 20.0
	mat.initial_velocity_min = 15.0
	mat.initial_velocity_max = 40.0
	mat.gravity = Vector3(0, -10, 0)
	mat.scale_min = 2.0
	mat.scale_max = 5.0
	mat.color = Color(1.0, 0.6, 0.1, 0.8)
	campfire.process_material = mat
	campfire.amount = 25
	campfire.lifetime = 1.5
	campfire.position = Vector2(350, 400)
	add_child(campfire)


func _build_merchant() -> void:
	# TODO: Replace with Merchant art asset
	var merchant := ColorRect.new()
	merchant.color = Color("#8B6914")
	merchant.size = Vector2(60, 80)
	merchant.position = Vector2(650, 320)
	add_child(merchant)

	var merchant_label := Label.new()
	merchant_label.text = "Merchant"
	merchant_label.position = Vector2(640, 300)
	merchant_label.add_theme_color_override("font_color", Color(0.94, 0.92, 0.84, 1.0))
	merchant_label.add_theme_font_size_override("font_size", 14)
	add_child(merchant_label)


func _build_ui() -> void:
	var panel := VBoxContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -200
	panel.offset_top = -180
	panel.offset_right = 200
	panel.offset_bottom = 180
	panel.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_theme_constant_override("separation", 14)
	add_child(panel)

	var title := Label.new()
	title.text = "Merchant Camp"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(1.0, 0.843, 0.0, 1.0))
	title.add_theme_font_size_override("font_size", 32)
	panel.add_child(title)

	shard_label = Label.new()
	shard_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shard_label.add_theme_color_override("font_color", Color(1.0, 0.98, 0.804, 1.0))
	shard_label.add_theme_font_size_override("font_size", 20)
	shard_label.text = "Radiant Ore Shards: %d" % MetaProgress.radiant_ore_shards
	panel.add_child(shard_label)

	shard_label.pivot_offset = Vector2(200, 12)
	var shard_pulse := shard_label.create_tween()
	shard_pulse.set_loops()
	shard_pulse.tween_property(shard_label, "scale", Vector2(1.05, 1.05), 0.8)
	shard_pulse.tween_property(shard_label, "scale", Vector2.ONE, 0.8)

	dialogue_label = Label.new()
	dialogue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_label.custom_minimum_size = Vector2(380, 0)
	dialogue_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.6, 1.0))
	dialogue_label.add_theme_font_size_override("font_size", 16)
	var trigger := _get_dialogue_trigger()
	dialogue_label.text = "\"" + DialogueManager.get_line(trigger) + "\""
	panel.add_child(dialogue_label)

	var full_text: String = dialogue_label.text
	dialogue_label.visible_ratio = 0.0
	var char_count: int = full_text.length()
	var type_duration: float = float(char_count) / 40.0
	var type_tw := dialogue_label.create_tween()
	type_tw.tween_property(dialogue_label, "visible_ratio", 1.0, type_duration)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	panel.add_child(spacer)

	var begin_btn := Button.new()
	begin_btn.text = "Begin New Run"
	begin_btn.custom_minimum_size = Vector2(200, 40)
	begin_btn.pressed.connect(_on_begin_pressed)
	_style_button(begin_btn)
	panel.add_child(begin_btn)

	var upgrades_btn := Button.new()
	upgrades_btn.text = "Upgrades"
	upgrades_btn.custom_minimum_size = Vector2(200, 40)
	upgrades_btn.pressed.connect(_on_upgrades_pressed)
	_style_button(upgrades_btn)
	panel.add_child(upgrades_btn)

	var settings_btn := Button.new()
	settings_btn.text = "Settings"
	settings_btn.custom_minimum_size = Vector2(200, 40)
	settings_btn.pressed.connect(_on_settings_pressed)
	_style_button(settings_btn)
	panel.add_child(settings_btn)

	var title_btn := Button.new()
	title_btn.text = "Back to Title"
	title_btn.custom_minimum_size = Vector2(200, 40)
	title_btn.pressed.connect(_on_title_pressed)
	_style_button(title_btn)
	panel.add_child(title_btn)


func _get_dialogue_trigger() -> String:
	if RunManager.run_end_trigger != "":
		return RunManager.run_end_trigger
	if MetaProgress.runs_completed == 0:
		return "first_visit"
	return "first_visit"


func _on_begin_pressed() -> void:
	RunManager.start_run()
	SceneTransition.transition_to("res://scenes/ui/ArmyDraft.tscn")


func _on_upgrades_pressed() -> void:
	SceneTransition.transition_to("res://scenes/lobby/MetaUpgrades.tscn")


func _on_settings_pressed() -> void:
	SceneTransition.transition_to("res://scenes/ui/Settings.tscn")


func _on_title_pressed() -> void:
	SceneTransition.transition_to("res://scenes/ui/MainMenu.tscn")
