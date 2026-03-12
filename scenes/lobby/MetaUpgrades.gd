extends Control

var shard_label: Label = null
var grid: GridContainer = null
var card_panels: Dictionary = {}


func _ready() -> void:
	_build_background()
	_build_ui()
	MetaProgress.shards_changed.connect(_on_shards_changed)


func _build_background() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.04, 0.08, 1.0)
	add_child(bg)


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


func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 40
	root.offset_top = 30
	root.offset_right = -40
	root.offset_bottom = -30
	root.add_theme_constant_override("separation", 16)
	add_child(root)

	var top_bar := HBoxContainer.new()
	top_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	top_bar.add_theme_constant_override("separation", 30)
	root.add_child(top_bar)

	var title := Label.new()
	title.text = "Meta Upgrades"
	title.add_theme_color_override("font_color", Color(1.0, 0.843, 0.0, 1.0))
	title.add_theme_font_size_override("font_size", 32)
	top_bar.add_child(title)

	shard_label = Label.new()
	shard_label.text = "Shards: %d" % MetaProgress.radiant_ore_shards
	shard_label.add_theme_color_override("font_color", Color(1.0, 0.98, 0.804, 1.0))
	shard_label.add_theme_font_size_override("font_size", 20)
	top_bar.add_child(shard_label)

	var back_btn := Button.new()
	back_btn.text = "Back to Camp"
	back_btn.custom_minimum_size = Vector2(140, 35)
	back_btn.pressed.connect(_on_back_pressed)
	_style_button(back_btn)
	top_bar.add_child(back_btn)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)

	_build_upgrade_cards()


func _build_upgrade_cards() -> void:
	for child in grid.get_children():
		child.queue_free()
	card_panels.clear()

	var upgrades := UpgradeData.get_all_upgrades()
	for upgrade in upgrades:
		var card := _create_card(upgrade)
		grid.add_child(card)
		card_panels[upgrade["id"]] = card


func _create_card(upgrade: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(280, 140)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.18, 1.0)
	style.border_color = Color(0.3, 0.3, 0.4, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(12)

	var id: String = upgrade["id"]
	var owned: bool = MetaProgress.has_upgrade(id)

	if owned:
		style.bg_color = Color(0.15, 0.13, 0.05, 1.0)
		style.border_color = Color(1.0, 0.843, 0.0, 0.6)

	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var name_label := Label.new()
	name_label.text = upgrade["name"]
	name_label.add_theme_font_size_override("font_size", 20)
	if owned:
		name_label.add_theme_color_override("font_color", Color(1.0, 0.843, 0.0, 1.0))
	else:
		name_label.add_theme_color_override("font_color", Color(1.0, 0.98, 0.804, 1.0))
	vbox.add_child(name_label)

	var desc_label := Label.new()
	desc_label.text = upgrade["description"]
	desc_label.add_theme_font_size_override("font_size", 14)
	desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1.0))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc_label)

	var cost_label := Label.new()
	cost_label.add_theme_font_size_override("font_size", 16)

	if owned:
		cost_label.text = "OWNED"
		cost_label.add_theme_color_override("font_color", Color(1.0, 0.843, 0.0, 0.8))
		vbox.add_child(cost_label)
	else:
		cost_label.text = "Cost: %d shards" % upgrade["cost"]
		var prereq: String = upgrade.get("prerequisite", "")
		var prereq_met: bool = prereq == "" or MetaProgress.has_upgrade(prereq)
		var affordable: bool = MetaProgress.radiant_ore_shards >= upgrade["cost"]

		if not prereq_met:
			cost_label.add_theme_color_override("font_color", Color(0.5, 0.3, 0.3, 1.0))
			var prereq_data := UpgradeData.get_upgrade_by_id(prereq)
			cost_label.text += " (Requires: %s)" % prereq_data.get("name", prereq)
		elif affordable:
			cost_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5, 1.0))
		else:
			cost_label.add_theme_color_override("font_color", Color(0.6, 0.3, 0.3, 1.0))
		vbox.add_child(cost_label)

		var buy_btn := Button.new()
		buy_btn.text = "Unlock"
		buy_btn.custom_minimum_size = Vector2(100, 30)
		buy_btn.disabled = not (affordable and prereq_met)
		buy_btn.pressed.connect(_on_purchase.bind(id))
		_style_button(buy_btn)
		vbox.add_child(buy_btn)

	return panel


func _on_purchase(upgrade_id: String) -> void:
	if MetaProgress.purchase_upgrade(upgrade_id):
		_play_unlock_particles()
		_rebuild_cards()


func _rebuild_cards() -> void:
	_build_upgrade_cards()


func _play_unlock_particles() -> void:
	var particles := GPUParticles2D.new()
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 0, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 40.0
	mat.initial_velocity_max = 80.0
	mat.gravity = Vector3(0, 20, 0)
	mat.scale_min = 2.0
	mat.scale_max = 4.0
	mat.color = Color(1.0, 0.843, 0.0, 0.8)
	particles.process_material = mat
	particles.amount = 20
	particles.lifetime = 0.8
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.emitting = true
	particles.position = get_viewport_rect().size / 2.0
	add_child(particles)
	get_tree().create_timer(1.0).timeout.connect(particles.queue_free)


func _on_shards_changed(new_amount: int) -> void:
	if shard_label:
		shard_label.text = "Shards: %d" % new_amount


func _on_back_pressed() -> void:
	SceneTransition.transition_to("res://scenes/lobby/Lobby.tscn")
