extends Control

signal boon_chosen

var hero_data: Dictionary = {}
var is_upgrade_mode: bool = false
var upgrade_options: Array = []

var card_buttons: Array[Button] = []
var card_borders: Array[ColorRect] = []


func _ready() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.offset_left = -350
	vbox.offset_top = -200
	vbox.offset_right = 350
	vbox.offset_bottom = 200
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(vbox)

	var title := Label.new()
	if is_upgrade_mode:
		title.text = "%s grows stronger" % hero_data.get("name", "Hero")
	else:
		title.text = "%s joins your cause" % hero_data.get("name", "Hero")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", hero_data.get("color", Color.WHITE))
	vbox.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 20)
	vbox.add_child(hbox)

	if is_upgrade_mode:
		for upgrade in upgrade_options:
			var card := _create_card(upgrade)
			hbox.add_child(card)
			card_buttons.append(card)
	else:
		var boons: Array = hero_data.get("boons", [])
		for i in boons.size():
			var boon: Dictionary = boons[i]
			var card := _create_card(boon)
			hbox.add_child(card)
			card_buttons.append(card)


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
		if not button.disabled: AudioManager.play_sfx("ui_click")
		button.pivot_offset = button.size / 2.0
		var tw := button.create_tween()
		tw.tween_property(button, "scale", Vector2(0.95, 0.95), 0.05)
	)
	button.button_up.connect(func() -> void:
		var tw := button.create_tween()
		tw.tween_property(button, "scale", Vector2.ONE, 0.05)
	)
	button.mouse_entered.connect(func() -> void:
		if not button.disabled: AudioManager.play_sfx("ui_hover")
	)


func _create_card(boon: Dictionary) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(200, 160)
	_style_button(button)

	var panel := VBoxContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.alignment = BoxContainer.ALIGNMENT_CENTER
	button.add_child(panel)

	var hero_color: Color = hero_data.get("color", Color.WHITE)

	var border := ColorRect.new()
	border.custom_minimum_size = Vector2(180, 4)
	border.color = hero_color
	border.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(border)
	card_borders.append(border)

	var name_label := Label.new()
	name_label.text = boon.get("name", "")
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", hero_color)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(name_label)

	var desc_label := Label.new()
	desc_label.text = boon.get("description", "")
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.add_theme_font_size_override("font_size", 14)
	desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(desc_label)

	button.mouse_entered.connect(func() -> void:
		border.color = hero_color.lightened(0.3)
	)
	button.mouse_exited.connect(func() -> void:
		border.color = hero_color
	)

	button.pressed.connect(_on_card_pressed.bind(boon))
	return button


func _on_card_pressed(boon: Dictionary) -> void:
	AudioManager.play_sfx("ui_click")
	RunManager.add_boon(boon["id"])

	if not is_upgrade_mode:
		RunManager.heroes_encountered_this_run.append(hero_data.get("id", ""))
		RunManager.set_hero_boon(hero_data.get("id", ""), boon["id"])

	for card in card_buttons:
		card.disabled = true
		card.modulate.a = 0.3

	var options: Array = upgrade_options if is_upgrade_mode else hero_data.get("boons", [])
	var boon_index: int = -1
	for i in options.size():
		if options[i]["id"] == boon["id"]:
			boon_index = i
			break
	if boon_index >= 0 and boon_index < card_buttons.size():
		var selected_card := card_buttons[boon_index]
		selected_card.modulate.a = 1.0
		selected_card.pivot_offset = selected_card.size / 2.0
		var scale_tw := selected_card.create_tween()
		scale_tw.tween_property(selected_card, "scale", Vector2(1.2, 1.2), 0.15)
		scale_tw.tween_property(selected_card, "scale", Vector2.ONE, 0.15)

	_play_burst_particles()

	await get_tree().create_timer(0.8).timeout
	boon_chosen.emit()
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
	mat.color = hero_data.get("color", Color.WHITE)
	particles.process_material = mat
	particles.amount = 30
	particles.lifetime = 0.8
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.emitting = true
	particles.position = size / 2.0
	add_child(particles)
