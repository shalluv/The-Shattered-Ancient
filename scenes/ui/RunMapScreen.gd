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

const ROOM_ICONS: Dictionary = {
	"start": preload("res://art/ui/map/start-icon.aseprite"),
	"combat_small": preload("res://art/ui/map/combat-small-icon.aseprite"),
	"combat_medium": preload("res://art/ui/map/combat-medium-icon.aseprite"),
	"village": preload("res://art/ui/map/village-icon.aseprite"),
	"hero_room": preload("res://art/ui/map/hero-icon.aseprite"),
	"shop": preload("res://art/ui/map/shop-icon.aseprite"),
	"mini_boss": preload("res://art/ui/map/miniboss-icon.aseprite"),
	"boss": preload("res://art/ui/map/boss-icon.aseprite"),
}

var selected_node_index: int = -1
var node_controls: Dictionary = {}
var line_nodes: Array = []
var map_container: Control = null
var ui_root: Control = null
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
	ui_root = Control.new()
	ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui_root)

	# Header
	var header := VBoxContainer.new()
	header.set_anchors_preset(Control.PRESET_TOP_WIDE)
	header.offset_left = 40
	header.offset_right = -40
	header.offset_top = 16
	header.offset_bottom = 120
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_theme_constant_override("separation", 4)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(header)

	title_label = Label.new()
	title_label.text = "THE SHATTERED MAP"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.70, 1.0))
	title_label.add_theme_font_size_override("font_size", 34)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(title_label)

	var subtitle := Label.new()
	subtitle.text = "Choose your next path through the run"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color(0.72, 0.74, 0.82, 0.9))
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(subtitle)

	# Map panel
	var map_panel := PanelContainer.new()
	map_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	map_panel.offset_left = 30
	map_panel.offset_right = -30
	map_panel.offset_top = 110
	map_panel.offset_bottom = -150
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.07, 0.10, 0.16, 0.88)
	panel_style.border_color = Color(0.75, 0.65, 0.38, 0.35)
	panel_style.border_width_top = 1
	panel_style.border_width_bottom = 1
	panel_style.border_width_left = 1
	panel_style.border_width_right = 1
	panel_style.set_corner_radius_all(10)
	panel_style.set_content_margin_all(12)
	map_panel.add_theme_stylebox_override("panel", panel_style)
	ui_root.add_child(map_panel)

	var scroll := ScrollContainer.new()
	scroll.name = "MapScroll"
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 0
	scroll.offset_right = 0
	scroll.offset_top = 0
	scroll.offset_bottom = 0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	map_panel.add_child(scroll)

	map_container = Control.new()
	map_container.clip_contents = false
	var viewport_width: float = max(get_viewport_rect().size.x, 1024.0)
	var map_width: float = max(viewport_width - 120.0, 520.0)
	var map_height: float = TOP_MARGIN + (9 * VERTICAL_SPACING) + BOTTOM_MARGIN + 40
	map_container.custom_minimum_size = Vector2(map_width, map_height)
	map_container.size = Vector2(map_width, map_height)
	scroll.add_child(map_container)

	# Legend panel
	var legend_panel := PanelContainer.new()
	legend_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	legend_panel.offset_left = -300
	legend_panel.offset_right = -40
	legend_panel.offset_top = 120
	legend_panel.offset_bottom = 260
	var legend_style := StyleBoxFlat.new()
	legend_style.bg_color = Color(0.08, 0.10, 0.14, 0.92)
	legend_style.border_color = Color(0.60, 0.55, 0.35, 0.4)
	legend_style.border_width_top = 1
	legend_style.border_width_bottom = 1
	legend_style.border_width_left = 1
	legend_style.border_width_right = 1
	legend_style.set_corner_radius_all(8)
	legend_style.set_content_margin_all(12)
	legend_panel.add_theme_stylebox_override("panel", legend_style)
	ui_root.add_child(legend_panel)

	var legend_vbox := VBoxContainer.new()
	legend_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	legend_vbox.add_theme_constant_override("separation", 6)
	legend_panel.add_child(legend_vbox)

	var legend_title := Label.new()
	legend_title.text = "Room"
	legend_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	legend_title.add_theme_color_override("font_color", Color(0.97, 0.92, 0.68, 1.0))
	legend_title.add_theme_font_size_override("font_size", 16)
	legend_vbox.add_child(legend_title)

	var legend_order := ["start", "combat_small", "combat_medium", "village", "hero_room", "shop", "mini_boss", "boss"]
	for room_type in legend_order:
		var legend_row := HBoxContainer.new()
		legend_row.add_theme_constant_override("separation", 8)
		legend_vbox.add_child(legend_row)

		var legend_icon := TextureRect.new()
		legend_icon.texture = ROOM_ICONS.get(room_type, null)
		legend_icon.custom_minimum_size = Vector2(20, 20)
		legend_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		legend_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		legend_row.add_child(legend_icon)

		var legend_line := Label.new()
		legend_line.text = room_type.capitalize().replace("_", " ")
		legend_line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		legend_line.add_theme_color_override("font_color", Color(0.88, 0.86, 0.78, 0.92))
		legend_line.add_theme_font_size_override("font_size", 13)
		legend_row.add_child(legend_line)

	# Bottom panel
	var bottom_panel := Control.new()
	bottom_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_panel.offset_left = 30
	bottom_panel.offset_right = -30
	bottom_panel.offset_top = -140
	bottom_panel.offset_bottom = -20
	add_child(bottom_panel)

	var bottom_bg := ColorRect.new()
	bottom_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bottom_bg.color = Color(0.04, 0.06, 0.08, 0.88)
	bottom_panel.add_child(bottom_bg)

	var bottom_hbox := HBoxContainer.new()
	bottom_hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	bottom_hbox.offset_left = 20
	bottom_hbox.offset_right = -20
	bottom_hbox.offset_top = 20
	bottom_hbox.offset_bottom = -20
	bottom_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_hbox.add_theme_constant_override("separation", 18)
	bottom_panel.add_child(bottom_hbox)

	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 6)
	bottom_hbox.add_child(info_vbox)

	room_name_label = Label.new()
	room_name_label.text = "Select a reachable room to continue"
	room_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	room_name_label.add_theme_font_size_override("font_size", 18)
	room_name_label.add_theme_color_override("font_color", Color(0.93, 0.92, 0.82, 1.0))
	info_vbox.add_child(room_name_label)

	var hint_label := Label.new()
	hint_label.text = "Only highlighted paths are available. Click to preview."
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	hint_label.add_theme_font_size_override("font_size", 14)
	hint_label.add_theme_color_override("font_color", Color(0.72, 0.74, 0.78, 0.9))
	info_vbox.add_child(hint_label)

	enter_button = Button.new()
	enter_button.text = "ENTER ROOM"
	enter_button.custom_minimum_size = Vector2(200, 46)
	enter_button.visible = false
	enter_button.pressed.connect(_on_enter_pressed)
	enter_button.button_down.connect(func() -> void:
		if not enter_button.disabled: AudioManager.play_sfx("ui_click")
	)
	enter_button.mouse_entered.connect(func() -> void:
		if not enter_button.disabled: AudioManager.play_sfx("ui_hover")
	)
	_style_button(enter_button)
	bottom_hbox.add_child(enter_button)


func _render_map() -> void:
	selected_node_index = -1
	room_name_label.text = "Select a reachable room to continue"
	enter_button.visible = false

	for child in line_nodes:
		if is_instance_valid(child):
			child.queue_free()
	line_nodes.clear()
	node_controls.clear()

	var map: MapData = RunManager.map_data
	if not map:
		return

	var center_x: float = map_container.custom_minimum_size.x / 2.0

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

	var main := TextureRect.new()
	main.position = Vector2.ZERO
	main.size = Vector2(NODE_SIZE, NODE_SIZE)
	main.texture = ROOM_ICONS.get(node.room_type, null)
	main.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	main.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	main.name = "Main"
	main.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(main)

	var ring := Panel.new()
	ring.name = "Ring"
	ring.position = Vector2(-2, -2)
	ring.size = Vector2(NODE_BORDER_SIZE, NODE_BORDER_SIZE)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ring_style := StyleBoxFlat.new()
	ring_style.bg_color = Color(0, 0, 0, 0)
	ring_style.border_color = Color.WHITE
	ring_style.border_width_top = 2
	ring_style.border_width_bottom = 2
	ring_style.border_width_left = 2
	ring_style.border_width_right = 2
	ring_style.set_corner_radius_all(int(NODE_BORDER_SIZE / 2.0))
	ring.add_theme_stylebox_override("panel", ring_style)
	ring.visible = false
	container.add_child(ring)

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
		var main: TextureRect = container.get_node("Main")
		var ring: Panel = container.get_node("Ring")

		if node.is_visited and not node.is_current:
			main.modulate = Color("#2a2a2a")
			ring.visible = false
			container.modulate.a = 1.0
			container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		elif node.is_current:
			main.modulate = Color.WHITE
			ring.visible = true
			_set_ring_color(ring, Color.WHITE)
			container.modulate.a = 1.0
			container.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_add_current_particles(container)
		elif idx in reachable:
			main.modulate = Color.WHITE
			ring.visible = false
			container.modulate.a = 0.6
			container.mouse_filter = Control.MOUSE_FILTER_STOP
		else:
			main.modulate = Color.WHITE
			ring.visible = false
			container.modulate.a = 0.6
			container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if selected_node_index >= 0 and node_controls.has(selected_node_index):
		var sel_container: Control = node_controls[selected_node_index]
		var sel_ring: Panel = sel_container.get_node("Ring")
		sel_ring.visible = true
		_set_ring_color(sel_ring, Color.WHITE)
		sel_container.modulate.a = 1.0


func _set_ring_color(ring: Panel, color: Color) -> void:
	var style: StyleBoxFlat = ring.get_theme_stylebox("panel")
	if style:
		style.border_color = color


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
		AudioManager.play_sfx("ui_hover")
		container.modulate.a = 0.9
		container.scale = Vector2(1.08, 1.08)
		container.pivot_offset = Vector2(NODE_SIZE / 2.0, NODE_SIZE / 2.0)
	elif not entered and idx != selected_node_index:
		container.modulate.a = 0.6
		container.scale = Vector2.ONE


func _select_node(idx: int) -> void:
	if selected_node_index == idx:
		return

	AudioManager.play_sfx("ui_click")

	if selected_node_index >= 0 and node_controls.has(selected_node_index):
		var old: Control = node_controls[selected_node_index]
		old.modulate.a = 0.6
		old.scale = Vector2.ONE
		var old_ring: Panel = old.get_node("Ring")
		old_ring.visible = false

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
	var scroll := find_child("MapScroll", true, false) as ScrollContainer
	if not scroll:
		return
	var current_control: Control = node_controls.get(current_node.node_index)
	if not current_control:
		return

	await get_tree().process_frame
	await get_tree().process_frame

	var v_bar := scroll.get_v_scroll_bar()
	var node_center_y: float = current_control.position.y + current_control.size.y / 2.0
	var scroll_target: float = node_center_y - scroll.size.y / 2.0
	var max_scroll: float = v_bar.max_value - scroll.size.y if v_bar else map_container.size.y - scroll.size.y
	scroll.scroll_vertical = int(clampf(scroll_target, 0, max(0.0, max_scroll)))


func _style_button(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.14, 0.13, 0.18, 0.92)
	normal.border_color = Color(0.62, 0.54, 0.32, 0.75)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(6)
	normal.set_content_margin_all(10)
	button.add_theme_stylebox_override("normal", normal)

	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.22, 0.20, 0.28, 0.96)
	hover.border_color = Color(0.86, 0.75, 0.42, 0.95)
	hover.set_border_width_all(1)
	hover.set_corner_radius_all(6)
	hover.set_content_margin_all(10)
	button.add_theme_stylebox_override("hover", hover)

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color(0.18, 0.16, 0.23, 0.96)
	pressed.border_color = Color(0.95, 0.80, 0.40, 0.95)
	pressed.set_border_width_all(1)
	pressed.set_corner_radius_all(6)
	pressed.set_content_margin_all(10)
	button.add_theme_stylebox_override("pressed", pressed)

	button.add_theme_color_override("font_color", Color(0.95, 0.90, 0.70, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.96, 0.82, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(0.96, 0.88, 0.64, 1.0))
	button.add_theme_font_size_override("font_size", 16)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_M:
		_render_map()
