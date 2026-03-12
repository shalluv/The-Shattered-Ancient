extends Control

@onready var path_a_button: Button = $VBoxContainer/HBoxContainer/PathAButton
@onready var path_b_button: Button = $VBoxContainer/HBoxContainer/PathBButton
@onready var room_label: Label = $VBoxContainer/RoomLabel

var options: Dictionary = {}


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
	options = RunManager.get_room_options_for_current_index()

	room_label.text = "Room %d / %d" % [RunManager.current_room_index + 1, RunManager.TOTAL_ROOMS]

	if not options.is_empty():
		_configure_door(path_a_button.get_node("PathAPanel"), options.get("a", {}))
		_configure_door(path_b_button.get_node("PathBPanel"), options.get("b", {}))

	path_a_button.pressed.connect(_on_path_a_pressed)
	path_b_button.pressed.connect(_on_path_b_pressed)

	_style_button(path_a_button)
	_style_button(path_b_button)


func _configure_door(panel: VBoxContainer, room_data: Dictionary) -> void:
	var door_rect: ColorRect = panel.get_node("DoorRect")
	var label: Label = panel.get_node("Label")
	var desc: Label = panel.get_node("Desc")

	var room_type: String = room_data.get("type", "combat")
	match room_type:
		"combat":
			door_rect.color = Color(0.6, 0.1, 0.1)
			label.text = "Combat Arena"
			desc.text = "Dire Grunts await"
		"village":
			door_rect.color = Color(0.2, 0.4, 0.2)
			label.text = "Village Crossing"
			desc.text = "Neutrals to recruit"
		"hero":
			var hero_id: String = room_data.get("hero_id", "")
			var hero := HeroData.get_hero_by_id(hero_id)
			if not hero.is_empty():
				door_rect.color = hero["color"]
				label.text = hero["name"]
				desc.text = "Hero awaits"
			else:
				door_rect.color = Color(0.5, 0.5, 0.5)
				label.text = "Hero Room"
				desc.text = "Hero awaits"
		"shop":
			door_rect.color = Color(0.6, 0.5, 0.1)
			label.text = "Merchant's Shop"
			desc.text = "Spend gold on upgrades"
		"miniboss":
			door_rect.color = Color(0.7, 0.1, 0.1)
			label.text = "Dire Captain"
			desc.text = "Mini boss awaits"


func _on_path_a_pressed() -> void:
	RunManager.chosen_path = 0
	RunManager.set_chosen_room_data(options.get("a", {}))
	SceneTransition.transition_to(RunManager.get_room_scene_path())


func _on_path_b_pressed() -> void:
	RunManager.chosen_path = 1
	RunManager.set_chosen_room_data(options.get("b", {}))
	SceneTransition.transition_to(RunManager.get_room_scene_path())
