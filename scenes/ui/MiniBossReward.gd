extends Control

signal reward_chosen

var entities_node: Node2D = null
var has_chosen: bool = false


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


func _ready() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.offset_left = -300
	vbox.offset_top = -150
	vbox.offset_right = 300
	vbox.offset_bottom = 150
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 15)
	add_child(vbox)

	var title := Label.new()
	title.text = "Victory! Choose your reward"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1.0, 0.843, 0.0))
	vbox.add_child(title)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 30)
	vbox.add_child(hbox)

	var counts := SwarmManager.get_unit_counts_by_type()
	var most_common_type: String = "swordsman"
	var most_count: int = 0
	for utype in counts:
		if utype.begins_with("champion_"):
			continue
		if counts[utype] > most_count:
			most_count = counts[utype]
			most_common_type = utype

	var card_a := Button.new()
	card_a.custom_minimum_size = Vector2(220, 120)
	var panel_a := VBoxContainer.new()
	panel_a.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel_a.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_a.alignment = BoxContainer.ALIGNMENT_CENTER
	card_a.add_child(panel_a)
	var label_a := Label.new()
	label_a.text = "+4 %s units" % most_common_type.capitalize()
	label_a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_a.add_theme_font_size_override("font_size", 18)
	label_a.add_theme_color_override("font_color", Color(1.0, 0.843, 0.0))
	label_a.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_a.add_child(label_a)
	card_a.pressed.connect(_on_units_chosen.bind(most_common_type))
	_style_button(card_a)
	hbox.add_child(card_a)

	var card_b := Button.new()
	card_b.custom_minimum_size = Vector2(220, 120)
	var panel_b := VBoxContainer.new()
	panel_b.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel_b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_b.alignment = BoxContainer.ALIGNMENT_CENTER
	card_b.add_child(panel_b)
	var label_b := Label.new()
	label_b.text = "+20 Gold"
	label_b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_b.add_theme_font_size_override("font_size", 18)
	label_b.add_theme_color_override("font_color", Color(1.0, 0.843, 0.0))
	label_b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_b.add_child(label_b)
	card_b.pressed.connect(_on_gold_chosen)
	_style_button(card_b)
	hbox.add_child(card_b)


func _on_units_chosen(unit_type: String) -> void:
	if has_chosen:
		return
	has_chosen = true
	if entities_node and is_instance_valid(entities_node):
		var scene_path: String = SwarmManager.get_unit_scene_path(unit_type)
		var unit_scene: PackedScene = load(scene_path)
		var center := SwarmManager.get_swarm_center()
		for i in 4:
			var unit := unit_scene.instantiate()
			var offset := Vector2(randf_range(-30, 30), randf_range(-30, 30))
			unit.global_position = center + offset
			entities_node.add_child(unit)
	_finish()


func _on_gold_chosen() -> void:
	if has_chosen:
		return
	has_chosen = true
	RunManager.add_gold(20)
	_finish()


func _finish() -> void:
	_play_burst_particles()
	await get_tree().create_timer(0.8).timeout
	reward_chosen.emit()
	queue_free()


func _play_burst_particles() -> void:
	var particles := GPUParticles2D.new()
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 0, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 80.0
	mat.initial_velocity_max = 160.0
	mat.gravity = Vector3(0, 50, 0)
	mat.scale_min = 2.0
	mat.scale_max = 4.0
	mat.color = Color(1.0, 0.843, 0.0)
	particles.process_material = mat
	particles.amount = 30
	particles.lifetime = 0.8
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.emitting = true
	particles.position = size / 2.0
	add_child(particles)
