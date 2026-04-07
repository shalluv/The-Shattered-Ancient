extends Control

signal room_selected(room_type: String, node_index: int)

const NODE_SIZE: float = 48.0
const NODE_BORDER_SIZE: float = 52.0
const VERTICAL_SPACING: float = 90.0
const HORIZONTAL_SPACING: float = 180.0
const TOP_MARGIN: float = 60.0
const BOTTOM_MARGIN: float = 80.0

const ROOM_COLORS: Dictionary = {
	"start": Color("#FFD700"),
	"combat_small": Color("#8B0000"),
	"combat_medium": Color("#CC0000"),
	"village": Color("#228B22"),
	"hero_room": Color("#4B0082"),
	"shop": Color("#DAA520"),
	"mini_boss": Color("#8B008B"),
	"boss": Color("#FF0000"),
}

const ROOM_LABELS: Dictionary = {
	"start": "S",
	"combat_small": "C",
	"combat_medium": "C+",
	"village": "V",
	"hero_room": "H",
	"shop": "$",
	"mini_boss": "MB",
	"boss": "B",
}

var selected_node_index: int = -1
var node_controls: Dictionary = {}
var line_nodes: Array = []
var map_container: Control = null
var enter_button: Button = null
var room_name_label: Label = null
var title_label: Label = null
var current_pulse_particles: GPUParticles2D = null


func _ready() -> void:
	if not RunManager.map_data:
		RunManager.generate_new_map()
	_build_ui()
	_render_map()
	_scroll_to_current()


func _build_ui() -> void:
	title_label = Label.new()
	title_label.text = "CHOOSE YOUR PATH"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.add_theme_color_override("font_color", Color("#FFD700"))
	title_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title_label.offset_top = 10
	title_label.offset_bottom = 45
	add_child(title_label)

	map_container = Control.new()
	var map_height: float = TOP_MARGIN + (9 * VERTICAL_SPACING) + BOTTOM_MARGIN + 40
	map_container.clip_contents = false
	map_container.custom_minimum_size = Vector2(size.x, map_height)
	map_container.size = Vector2(size.x, map_height)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_top = 50
	scroll.offset_bottom = -90
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.name = "MapScroll"
	add_child(scroll)
	scroll.add_child(map_container)

	var bottom_panel := Control.new()
	bottom_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_panel.offset_top = -85
	add_child(bottom_panel)

	var bottom_bg := ColorRect.new()
	bottom_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bottom_bg.color = Color(0.05, 0.08, 0.05, 0.9)
	bottom_panel.add_child(bottom_bg)

	room_name_label = Label.new()
	room_name_label.text = ""
	room_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	room_name_label.add_theme_font_size_override("font_size", 20)
	room_name_label.add_theme_color_override("font_color", Color(0.94, 0.92, 0.84))
	room_name_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	room_name_label.offset_top = 8
	room_name_label.offset_bottom = 35
	bottom_panel.add_child(room_name_label)

	enter_button = Button.new()
	enter_button.text = "ENTER ROOM"
	enter_button.custom_minimum_size = Vector2(200, 40)
	enter_button.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	enter_button.offset_top = -50
	enter_button.offset_bottom = -10
	enter_button.offset_left = -100
	enter_button.offset_right = 100
	enter_button.visible = false
	enter_button.pressed.connect(_on_enter_pressed)
	_style_button(enter_button)
	bottom_panel.add_child(enter_button)


func _render_map() -> void:
	for child in line_nodes:
		if is_instance_valid(child):
			child.queue_free()
	line_nodes.clear()
	node_controls.clear()

	var map: MapData = RunManager.map_data
	if not map:
		return

	var center_x: float = size.x / 2.0

	_draw_connections(map, center_x)

	for node in map.nodes:
		_create_node_control(node, center_x)

	_update_node_states()


func _get_node_position(node: MapNodeData, center_x: float) -> Vector2:
	var base_y: float = TOP_MARGIN + (9 - node.row) * VERTICAL_SPACING
	var base_x: float = center_x + (node.col - 1) * HORIZONTAL_SPACING
	return Vector2(base_x, base_y) + node.offset


func _draw_connections(map: MapData, center_x: float) -> void:
	var reachable: Array[int] = map.get_reachable_nodes()
	for from_idx in map.connections:
		var from_node := map.get_node_by_index(from_idx)
		if not from_node:
			continue
		var from_pos := _get_node_position(from_node, center_x)
		for to_idx in map.connections[from_idx]:
			var to_node := map.get_node_by_index(to_idx)
			if not to_node:
				continue
			var to_pos := _get_node_position(to_node, center_x)

			var line := Line2D.new()
			line.add_point(from_pos)
			line.add_point(to_pos)

			var is_active_path: bool = from_idx == map.player_node_index and to_idx in reachable
			var is_traversed: bool = from_idx in map.visited_nodes and to_idx in map.visited_nodes
			if is_active_path:
				line.default_color = Color("#ffffff")
				line.width = 4.0
			elif is_traversed:
				line.default_color = Color("#FFD700")
				line.width = 3.0
			else:
				line.default_color = Color("#808080")
				line.width = 2.0
			line.z_index = 0
			map_container.add_child(line)
			line_nodes.append(line)


func _create_node_control(node: MapNodeData, center_x: float) -> void:
	var pos := _get_node_position(node, center_x)

	var container := Control.new()
	container.position = Vector2(pos.x - NODE_SIZE / 2.0, pos.y - NODE_SIZE / 2.0)
	container.size = Vector2(NODE_SIZE, NODE_SIZE)
	container.mouse_filter = Control.MOUSE_FILTER_STOP

	var border := ColorRect.new()
	border.position = Vector2(-2, -2)
	border.size = Vector2(NODE_BORDER_SIZE, NODE_BORDER_SIZE)
	border.color = Color("#1a2e1a")
	border.name = "Border"
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(border)

	# TODO: Replace with room type art asset
	var main := ColorRect.new()
	main.position = Vector2.ZERO
	main.size = Vector2(NODE_SIZE, NODE_SIZE)
	main.color = ROOM_COLORS.get(node.room_type, Color.WHITE)
	main.name = "Main"
	main.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(main)

	var label := Label.new()
	label.text = ROOM_LABELS.get(node.room_type, "?")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = Vector2.ZERO
	label.size = Vector2(NODE_SIZE, NODE_SIZE)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(label)

	container.gui_input.connect(_on_node_input.bind(node.node_index))
	container.mouse_entered.connect(_on_node_hover.bind(node.node_index, true))
	container.mouse_exited.connect(_on_node_hover.bind(node.node_index, false))

	map_container.add_child(container)
	node_controls[node.node_index] = container


func _update_node_states() -> void:
	var map: MapData = RunManager.map_data
	if not map:
		return

	var reachable := map.get_reachable_nodes()

	for idx in node_controls:
		var container: Control = node_controls[idx]
		var node := map.get_node_by_index(idx)
		if not node:
			continue
		var border: ColorRect = container.get_node("Border")
		var main: ColorRect = container.get_node("Main")

		if node.is_visited and not node.is_current:
			main.color = Color("#2a2a2a")
			border.color = Color("#1a2e1a")
			container.modulate.a = 1.0
			container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		elif node.is_current:
			main.color = ROOM_COLORS.get(node.room_type, Color.WHITE)
			border.color = Color.WHITE
			container.modulate.a = 1.0
			container.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_add_current_particles(container)
		elif idx in reachable:
			main.color = ROOM_COLORS.get(node.room_type, Color.WHITE)
			border.color = Color("#1a2e1a")
			container.modulate.a = 0.6
			container.mouse_filter = Control.MOUSE_FILTER_STOP
		else:
			main.color = ROOM_COLORS.get(node.room_type, Color.WHITE)
			border.color = Color("#1a2e1a")
			container.modulate.a = 0.6
			container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if selected_node_index >= 0 and node_controls.has(selected_node_index):
		var sel_container: Control = node_controls[selected_node_index]
		var sel_border: ColorRect = sel_container.get_node("Border")
		sel_border.color = Color.WHITE
		sel_container.modulate.a = 1.0


func _add_current_particles(container: Control) -> void:
	if current_pulse_particles and is_instance_valid(current_pulse_particles):
		current_pulse_particles.queue_free()
	var particles := GPUParticles2D.new()
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 0, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 5.0
	mat.initial_velocity_max = 15.0
	mat.gravity = Vector3(0, 0, 0)
	mat.scale_min = 1.0
	mat.scale_max = 2.0
	mat.color = Color("#FFD700")
	particles.process_material = mat
	particles.amount = 8
	particles.lifetime = 1.5
	particles.one_shot = false
	particles.emitting = true
	particles.position = Vector2(NODE_SIZE / 2.0, NODE_SIZE / 2.0)
	container.add_child(particles)
	current_pulse_particles = particles


func _on_node_input(event: InputEvent, idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var map: MapData = RunManager.map_data
		if not map:
			return
		var reachable := map.get_reachable_nodes()
		if idx in reachable:
			_select_node(idx)


func _on_node_hover(idx: int, entered: bool) -> void:
	if not node_controls.has(idx):
		return
	var map: MapData = RunManager.map_data
	if not map:
		return
	var reachable := map.get_reachable_nodes()
	if idx not in reachable:
		return

	var container: Control = node_controls[idx]
	if entered and idx != selected_node_index:
		container.modulate.a = 0.9
		container.scale = Vector2(1.08, 1.08)
		container.pivot_offset = Vector2(NODE_SIZE / 2.0, NODE_SIZE / 2.0)
	elif not entered and idx != selected_node_index:
		container.modulate.a = 0.6
		container.scale = Vector2.ONE


func _select_node(idx: int) -> void:
	if selected_node_index == idx:
		return

	if selected_node_index >= 0 and node_controls.has(selected_node_index):
		var old: Control = node_controls[selected_node_index]
		old.modulate.a = 0.6
		old.scale = Vector2.ONE
		var old_border: ColorRect = old.get_node("Border")
		old_border.color = Color("#1a2e1a")

	selected_node_index = idx
	_update_node_states()

	var map: MapData = RunManager.map_data
	var node := map.get_node_by_index(idx)
	if node:
		var display_name := _get_room_display_name(node.room_type, node.room_data)
		room_name_label.text = display_name
		enter_button.visible = true
		room_selected.emit(node.room_type, idx)


func _get_room_display_name(room_type: String, room_data: Dictionary) -> String:
	match room_type:
		"combat_small":
			return "Combat (Small)"
		"combat_medium":
			return "Combat (Medium)"
		"village":
			return "Village"
		"hero_room":
			var hero_id: String = room_data.get("hero_id", "")
			if hero_id != "":
				var hero := HeroData.get_hero_by_id(hero_id)
				return "Hero: %s" % hero.get("name", hero_id)
			return "Hero Encounter"
		"shop":
			return "Shop"
		"mini_boss":
			return "Mini Boss"
		"boss":
			return "BOSS"
	return room_type


func _on_enter_pressed() -> void:
	if selected_node_index < 0:
		return
	_play_confirm_particles()
	RunManager.advance_to_node(selected_node_index)
	var scene_path := RunManager.get_room_scene_path()
	SceneTransition.transition_to(scene_path)


func _play_confirm_particles() -> void:
	if not node_controls.has(selected_node_index):
		return
	var container: Control = node_controls[selected_node_index]
	var particles := GPUParticles2D.new()
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 0, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 40.0
	mat.initial_velocity_max = 80.0
	mat.gravity = Vector3(0, 0, 0)
	mat.scale_min = 2.0
	mat.scale_max = 4.0
	mat.color = Color("#FFD700")
	particles.process_material = mat
	particles.amount = 20
	particles.lifetime = 0.5
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.emitting = true
	particles.position = Vector2(NODE_SIZE / 2.0, NODE_SIZE / 2.0)
	container.add_child(particles)


func _scroll_to_current() -> void:
	var map: MapData = RunManager.map_data
	if not map:
		return
	var current_node := map.get_node_by_index(map.player_node_index)
	if not current_node:
		return
	var scroll: ScrollContainer = get_node("MapScroll")
	if not scroll:
		return
	var target_y: float = TOP_MARGIN + (9 - current_node.row) * VERTICAL_SPACING
	var scroll_target: float = target_y - scroll.size.y / 2.0
	scroll_target = clampf(scroll_target, 0, map_container.size.y - scroll.size.y)
	await get_tree().process_frame
	scroll.scroll_vertical = int(scroll_target)


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


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_M:
		_render_map()
