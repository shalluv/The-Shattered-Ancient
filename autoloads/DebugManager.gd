extends Node

## Debug Manager for testing and development
## Enables quick access to all upgrades and room navigation

const DEBUG_ENABLED: bool = true  # Toggle this to enable/disable debug features

var debug_menu_visible: bool = false
var debug_panel: Control = null


func _ready() -> void:
	if not DEBUG_ENABLED:
		return
	set_process_input(true)


func _input(event: InputEvent) -> void:
	if not DEBUG_ENABLED:
		return
	
	# Press F12 to toggle debug menu
	if event is InputEventKey and event.pressed and event.keycode == KEY_F12:
		toggle_debug_menu()
		get_tree().root.set_input_as_handled()


func toggle_debug_menu() -> void:
	debug_menu_visible = !debug_menu_visible
	if debug_menu_visible:
		_create_debug_panel()
	else:
		_destroy_debug_panel()


func _create_debug_panel() -> void:
	if debug_panel:
		return
	
	debug_panel = Control.new()
	debug_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	debug_panel.custom_minimum_size = Vector2(0, 300)
	debug_panel.offset_bottom = 300
	get_tree().root.add_child(debug_panel)
	
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.8)
	debug_panel.add_child(bg)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 10
	vbox.offset_top = 10
	vbox.offset_right = -10
	vbox.offset_bottom = -10
	vbox.add_theme_constant_override("separation", 5)
	debug_panel.add_child(vbox)
	
	# Title
	var title = Label.new()
	title.text = "DEBUG MENU (F12 to close)"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color.YELLOW)
	vbox.add_child(title)
	
	# Separator
	var sep = ColorRect.new()
	sep.custom_minimum_size = Vector2(0, 2)
	sep.color = Color.YELLOW
	vbox.add_child(sep)
	
	# Upgrades Section
	var upgrades_label = Label.new()
	upgrades_label.text = "UPGRADES:"
	upgrades_label.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(upgrades_label)
	
	var hbox1 = HBoxContainer.new()
	hbox1.add_theme_constant_override("separation", 5)
	vbox.add_child(hbox1)
	
	var btn_unlock_all = Button.new()
	btn_unlock_all.text = "Unlock All Upgrades"
	btn_unlock_all.pressed.connect(unlock_all_upgrades)
	hbox1.add_child(btn_unlock_all)
	
	var btn_reset_upgrades = Button.new()
	btn_reset_upgrades.text = "Reset Upgrades"
	btn_reset_upgrades.pressed.connect(_on_reset_upgrades)
	hbox1.add_child(btn_reset_upgrades)
	
	# Shards Section
	var shards_label = Label.new()
	shards_label.text = "SHARDS:"
	shards_label.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(shards_label)
	
	var hbox2 = HBoxContainer.new()
	hbox2.add_theme_constant_override("separation", 5)
	vbox.add_child(hbox2)
	
	var btn_add_shards = Button.new()
	btn_add_shards.text = "Add 100 Shards"
	btn_add_shards.pressed.connect(func(): MetaProgress.add_shards(100))
	hbox2.add_child(btn_add_shards)
	
	var btn_max_shards = Button.new()
	btn_max_shards.text = "Add 9999 Shards"
	btn_max_shards.pressed.connect(func(): MetaProgress.add_shards(9999))
	hbox2.add_child(btn_max_shards)
	
	# Room Navigation Section
	var room_label = Label.new()
	room_label.text = "ROOMS:"
	room_label.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(room_label)
	
	var hbox3 = HBoxContainer.new()
	hbox3.add_theme_constant_override("separation", 5)
	vbox.add_child(hbox3)
	
	var btn_next_room = Button.new()
	btn_next_room.text = "Next Room"
	btn_next_room.pressed.connect(_on_next_room)
	hbox3.add_child(btn_next_room)
	
	var btn_jump_to_boss = Button.new()
	btn_jump_to_boss.text = "Jump to Boss"
	btn_jump_to_boss.pressed.connect(_on_jump_to_boss)
	hbox3.add_child(btn_jump_to_boss)
	
	# Room Picker Section
	var room_picker_label = Label.new()
	room_picker_label.text = "PICK ANY ROOM:"
	room_picker_label.add_theme_color_override("font_color", Color(0.8, 0.8, 1.0))
	vbox.add_child(room_picker_label)
	
	if RunManager.map_data:
		var room_grid = GridContainer.new()
		room_grid.columns = 5
		room_grid.add_theme_constant_override("h_separation", 3)
		room_grid.add_theme_constant_override("v_separation", 3)
		vbox.add_child(room_grid)
		
		for i in range(RunManager.map_data.nodes.size()):
			var node = RunManager.map_data.nodes[i]
			var room_btn = Button.new()
			room_btn.text = "%d" % i
			room_btn.custom_minimum_size = Vector2(40, 30)
			room_btn.pressed.connect(func(): jump_to_node(i))
			
			# Color code by room type
			var btn_color = Color.GRAY
			match node.room_type:
				"start": btn_color = Color.YELLOW
				"combat_small", "combat_medium": btn_color = Color(0.8, 0.2, 0.2)
				"village": btn_color = Color(0.2, 0.8, 0.2)
				"hero_room": btn_color = Color(0.5, 0.0, 0.8)
				"shop": btn_color = Color(1.0, 0.8, 0.0)
				"mini_boss": btn_color = Color(0.8, 0.0, 0.8)
				"boss": btn_color = Color(1.0, 0.0, 0.0)
			
			var style = StyleBoxFlat.new()
			style.bg_color = btn_color
			style.set_border_width_all(1)
			room_btn.add_theme_stylebox_override("normal", style)
			room_grid.add_child(room_btn)
	
	# Status
	var status_label = Label.new()
	status_label.text = "Upgrades: %d | Shards: %d | Room: %d" % [
		MetaProgress.unlocked_upgrades.size(),
		MetaProgress.radiant_ore_shards,
		RunManager.current_room_index
	]
	status_label.add_theme_color_override("font_color", Color.LIGHT_GREEN)
	vbox.add_child(status_label)


func _destroy_debug_panel() -> void:
	if debug_panel:
		debug_panel.queue_free()
		debug_panel = null


## Unlocks all available upgrades
func unlock_all_upgrades() -> void:
	var upgrades = UpgradeData.get_all_upgrades()
	for upgrade in upgrades:
		var upgrade_id: String = upgrade["id"]
		if not MetaProgress.has_upgrade(upgrade_id):
			MetaProgress.unlock_upgrade(upgrade_id)
	print("✓ All upgrades unlocked!")
	_update_debug_panel()


## Resets all upgrades
func _on_reset_upgrades() -> void:
	MetaProgress.unlocked_upgrades.clear()
	MetaProgress.save_progress()
	print("✓ All upgrades reset!")
	_update_debug_panel()


## Advances to the next room
func _on_next_room() -> void:
	if RunManager.map_data and RunManager.current_node_index < RunManager.map_data.nodes.size() - 1:
		RunManager.advance_to_node(RunManager.current_node_index + 1)
		print("→ Advanced to room %d" % RunManager.current_room_index)
		_transition_to_current_room()


## Jumps directly to boss room
func _on_jump_to_boss() -> void:
	if RunManager.map_data:
		# Find the boss node
		for i in range(RunManager.map_data.nodes.size()):
			var node = RunManager.map_data.nodes[i]
			if node.room_type == "boss":
				RunManager.advance_to_node(i)
				print("→ Jumped to BOSS room")
				_transition_to_current_room()
				return
		print("✗ Boss room not found in map")


## Navigate to any specific node by index
func jump_to_node(node_index: int) -> void:
	if RunManager.map_data and node_index < RunManager.map_data.nodes.size():
		RunManager.advance_to_node(node_index)
		print("→ Jumped to node %d (room %d)" % [node_index, RunManager.current_room_index])
		_transition_to_current_room()
	else:
		print("✗ Invalid node index: %d" % node_index)


## Quick shorthand to navigate to specific room types
func jump_to_room_type(room_type: String) -> void:
	if RunManager.map_data:
		for i in range(RunManager.map_data.nodes.size()):
			var node = RunManager.map_data.nodes[i]
			if node.room_type == room_type:
				RunManager.advance_to_node(i)
				print("→ Jumped to %s room" % room_type)
				_transition_to_current_room()
				return
		print("✗ Room type '%s' not found in map" % room_type)


func _transition_to_current_room() -> void:
	var scene_path = RunManager.get_room_scene_path()
	if scene_path:
		SceneTransition.transition_to(scene_path)


func _update_debug_panel() -> void:
	if debug_panel:
		_destroy_debug_panel()
		_create_debug_panel()


## Print available debug commands to console
func print_debug_help() -> void:
	print("""
DEBUG COMMANDS:
================
DebugManager.unlock_all_upgrades()        - Unlock all upgrades
DebugManager.jump_to_node(index)          - Jump to specific node (0-9)
DebugManager.jump_to_room_type("boss")    - Jump to room type (combat_small, combat_medium, village, hero_room, shop, mini_boss, boss)
DebugManager.jump_to_boss()               - Quick jump to boss
MetaProgress.add_shards(amount)           - Add shards
RunManager.current_room_index             - Check current room
RunManager.map_data.nodes                 - View all nodes in current map
""")
