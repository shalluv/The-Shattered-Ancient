extends "res://scenes/dungeon/RoomBase.gd"

const SHOP_FLOOR_COLOR: Color = Color(0.08, 0.06, 0.03)

const SHOP_ITEMS: Array[Dictionary] = [
	{"id": "mercenary_swordsman", "name": "Mercenary Swordsman", "cost": 30, "desc": "+3 Swordsmen", "category": "unit"},
	{"id": "hired_archer", "name": "Hired Archer", "cost": 35, "desc": "+3 Archers", "category": "unit"},
	{"id": "wandering_mage", "name": "Wandering Mage", "cost": 15, "desc": "+1 Mage", "category": "unit"},
	{"id": "holy_wanderer", "name": "Holy Wanderer", "cost": 30, "desc": "+1 Priest", "category": "unit"},
	{"id": "sharpened_blades", "name": "Sharpened Blades", "cost": 50, "desc": "All Swordsmen +1 damage this run", "category": "combat"},
	{"id": "enchanted_quiver", "name": "Enchanted Quiver", "cost": 40, "desc": "Archer cooldown -0.3s this run", "category": "combat"},
	{"id": "battle_standard", "name": "Battle Standard", "cost": 80, "desc": "All units survive 2 hits this run", "category": "combat"},
	{"id": "scouting_map", "name": "Scouting Map", "cost": 20, "desc": "Reveal all remaining room types", "category": "utility"},
	{"id": "war_chest", "name": "War Chest", "cost": 20, "desc": "+30 Gold immediately", "category": "utility"},
	{"id": "ancient_relic", "name": "Ancient Relic", "cost": 55, "desc": "+5 Radiant Ore Shards at end of run", "category": "utility"},
]

var shop_overlay: Control = null
var shop_cards: Array[Button] = []

@onready var player_spawn: Marker2D = $PlayerSpawnPoint


func _ready() -> void:
	floor_rect.color = SHOP_FLOOR_COLOR
	super()


func _get_spawn_position() -> Vector2:
	return player_spawn.global_position


func _spawn_enemies() -> void:
	RunManager.set_room_enemy_count(0)
	_create_merchant_stalls()
	_create_ambient_particles()
	call_deferred("_emit_room_cleared")


func _emit_room_cleared() -> void:
	RunManager.room_cleared.emit()


func _on_room_cleared() -> void:
	_unlock_doors()
	room_clear_particles.global_position = game_camera.global_position
	room_clear_particles.emitting = true
	_show_shop_ui()


func _create_merchant_stalls() -> void:
	var stall_positions: Array[Vector2] = [
		Vector2(200, 180), Vector2(400, 150), Vector2(600, 180), Vector2(300, 320),
	]
	for pos in stall_positions:
		# TODO: Replace with merchant stall art asset
		var stall := ColorRect.new()
		stall.size = Vector2(40, 24)
		stall.position = pos - Vector2(20, 12)
		stall.color = Color(0.35, 0.22, 0.1)
		entities.add_child(stall)

		var body := StaticBody2D.new()
		body.collision_layer = 8
		body.collision_mask = 0
		body.position = pos
		var shape := RectangleShape2D.new()
		shape.size = Vector2(40, 24)
		var col := CollisionShape2D.new()
		col.shape = shape
		body.add_child(col)
		entities.add_child(body)

	var stall_obstacles: Array[Rect2] = []
	for pos in stall_positions:
		stall_obstacles.append(Rect2(pos - Vector2(20, 12), Vector2(40, 24)))
	Pathfinder.add_obstacles(stall_obstacles)


func _create_ambient_particles() -> void:
	var ambient := GPUParticles2D.new()
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(room_size.x / 2.0, room_size.y / 2.0, 0)
	mat.direction = Vector3(0, -0.5, 0)
	mat.spread = 30.0
	mat.initial_velocity_min = 2.0
	mat.initial_velocity_max = 5.0
	mat.gravity = Vector3(0, 3, 0)
	mat.scale_min = 0.5
	mat.scale_max = 1.5
	mat.color = Color(1.0, 0.843, 0.0, 0.2)
	ambient.process_material = mat
	ambient.amount = 20
	ambient.lifetime = 3.0
	ambient.emitting = true
	ambient.position = room_size / 2.0
	add_child(ambient)


func _show_shop_ui() -> void:
	shop_overlay = Control.new()
	shop_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.7)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	shop_overlay.add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.offset_left = -400
	vbox.offset_top = -250
	vbox.offset_right = 400
	vbox.offset_bottom = 250
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 10)
	shop_overlay.add_child(vbox)

	var title := Label.new()
	title.text = "Merchant's Wares"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1.0, 0.843, 0.0))
	vbox.add_child(title)

	var gold_label := Label.new()
	gold_label.text = "Gold: %d" % RunManager.gold
	gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gold_label.add_theme_font_size_override("font_size", 20)
	gold_label.add_theme_color_override("font_color", Color(1.0, 0.843, 0.0, 0.8))
	gold_label.name = "GoldLabel"
	vbox.add_child(gold_label)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer)

	var items_pool := SHOP_ITEMS.duplicate()
	items_pool.shuffle()
	var selected_items: Array[Dictionary] = []
	for i in mini(4, items_pool.size()):
		selected_items.append(items_pool[i])

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 15)
	vbox.add_child(hbox)

	for item in selected_items:
		var card := _create_shop_card(item, gold_label)
		hbox.add_child(card)
		shop_cards.append(card)

	var leave_btn := Button.new()
	leave_btn.text = "Leave Shop"
	leave_btn.custom_minimum_size = Vector2(200, 40)
	leave_btn.pressed.connect(_on_leave_shop)
	leave_btn.button_down.connect(func() -> void:
		if not leave_btn.disabled: AudioManager.play_sfx("ui_click")
	)
	leave_btn.mouse_entered.connect(func() -> void:
		if not leave_btn.disabled: AudioManager.play_sfx("ui_hover")
	)
	vbox.add_child(leave_btn)

	hud_layer.add_child(shop_overlay)


func _create_shop_card(item: Dictionary, gold_label: Label) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(180, 180)

	var panel := VBoxContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_theme_constant_override("separation", 4)
	button.add_child(panel)

	var cat_color: Color
	match item["category"]:
		"unit":
			cat_color = Color(1.0, 0.843, 0.0)
		"combat":
			cat_color = Color(0.8, 0.2, 0.2)
		_:
			cat_color = Color(0.4, 0.7, 1.0)

	var border := ColorRect.new()
	border.custom_minimum_size = Vector2(160, 3)
	border.color = cat_color
	border.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(border)

	var name_lbl := Label.new()
	name_lbl.text = item["name"]
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", cat_color)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = item["desc"]
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(desc_lbl)

	var cost_lbl := Label.new()
	cost_lbl.text = "%dg" % item["cost"]
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_lbl.add_theme_font_size_override("font_size", 18)
	cost_lbl.add_theme_color_override("font_color", Color(1.0, 0.843, 0.0))
	cost_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(cost_lbl)

	if RunManager.gold < item["cost"]:
		button.disabled = true
		button.modulate.a = 0.5

	button.button_down.connect(func() -> void:
		if not button.disabled: AudioManager.play_sfx("ui_click")
	)
	button.mouse_entered.connect(func() -> void:
		if not button.disabled: AudioManager.play_sfx("ui_hover")
	)
	button.pressed.connect(_on_item_purchased.bind(item, button, gold_label))
	return button


func _on_item_purchased(item: Dictionary, button: Button, gold_label: Label) -> void:
	if not RunManager.spend_gold(item["cost"]):
		return

	AudioManager.play_sfx("shop_buy")
	_apply_item(item["id"])

	button.disabled = true
	button.modulate.a = 0.3

	gold_label.text = "Gold: %d" % RunManager.gold
	for card in shop_cards:
		if not card.disabled:
			var card_cost := _get_card_cost(card)
			if card_cost > RunManager.gold:
				card.disabled = true
				card.modulate.a = 0.5


func _get_card_cost(card: Button) -> int:
	var panel := card.get_child(0) as VBoxContainer
	if panel == null:
		return 999
	for child in panel.get_children():
		if child is Label:
			var txt: String = child.text
			if txt.ends_with("g") and txt.substr(0, txt.length() - 1).is_valid_int():
				return int(txt.substr(0, txt.length() - 1))
	return 999


func _apply_item(item_id: String) -> void:
	match item_id:
		"mercenary_swordsman":
			_spawn_shop_units("swordsman", 3)
		"hired_archer":
			_spawn_shop_units("archer", 3)
		"wandering_mage":
			_spawn_shop_units("mage", 1)
		"holy_wanderer":
			_spawn_shop_units("priest", 1)
		"sharpened_blades":
			RunManager.add_shop_buff("sharpened_blades")
			for unit in SwarmManager.units:
				if is_instance_valid(unit) and unit.has_method("get_unit_type"):
					if unit.get_unit_type() == "swordsman":
						unit.damage += 1
		"enchanted_quiver":
			RunManager.add_shop_buff("enchanted_quiver")
			for unit in SwarmManager.units:
				if is_instance_valid(unit) and unit.has_method("get_unit_type"):
					if unit.get_unit_type() == "archer" and "attack_cooldown" in unit:
						unit.attack_cooldown -= 0.3
		"battle_standard":
			RunManager.add_shop_buff("battle_standard")
			for unit in SwarmManager.units:
				if is_instance_valid(unit):
					unit.max_hp = max(unit.max_hp, 2)
					unit.current_hp = unit.max_hp
		"scouting_map":
			RunManager.add_shop_buff("scouting_map")
		"war_chest":
			RunManager.add_gold(30)
		"ancient_relic":
			RunManager.bonus_end_shards += 5


func _spawn_shop_units(unit_type: String, count: int) -> void:
	var scene_path: String = SwarmManager.get_unit_scene_path(unit_type)
	var unit_scene: PackedScene = load(scene_path)
	var center := SwarmManager.get_swarm_center()
	for i in count:
		var unit := unit_scene.instantiate()
		var offset := Vector2(randf_range(-30, 30), randf_range(-30, 30))
		unit.global_position = center + offset
		entities.add_child(unit)


func _on_leave_shop() -> void:
	if shop_overlay and is_instance_valid(shop_overlay):
		shop_overlay.queue_free()
		shop_overlay = null
