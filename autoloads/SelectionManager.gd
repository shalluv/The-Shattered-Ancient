extends Node

const DRAG_THRESHOLD: float = 5.0
const FORMATION_SPACING: float = 15.0
const DOUBLE_CLICK_THRESHOLD: float = 0.4

var selected_units: Array[Node2D] = []
var is_dragging: bool = false
var drag_start_screen: Vector2 = Vector2.ZERO
var drag_current_screen: Vector2 = Vector2.ZERO
var drag_shift_held: bool = false

var control_groups: Dictionary = {}
var control_group_blueprints: Dictionary = {}
var last_click_time: float = 0.0
var last_click_unit: Node2D = null

var overlay_layer: CanvasLayer = null
var overlay_control: Control = null


func _ready() -> void:
	overlay_layer = CanvasLayer.new()
	overlay_layer.layer = 100
	add_child(overlay_layer)

	overlay_control = SelectionBoxOverlay.new()
	overlay_control.selection_manager = self
	overlay_layer.add_child(overlay_control)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion and is_dragging:
		drag_current_screen = event.position
		overlay_control.queue_redraw()

	if event.is_action_pressed("select_all"):
		_select_all_units()
	if event.is_action_pressed("select_all_other"):
		_select_all_other_units()
	if event.is_action_pressed("next_unit"):
		_cycle_unit(1)
	if event.is_action_pressed("prev_unit"):
		_cycle_unit(-1)
	if event.is_action_pressed("select_all_swordsman"):
		_select_all_of_unit_type("swordsman")
	if event.is_action_pressed("select_all_archer"):
		_select_all_of_unit_type("archer")
	if event.is_action_pressed("select_all_priest"):
		_select_all_of_unit_type("priest")
	if event.is_action_pressed("select_all_mage"):
		_select_all_of_unit_type("mage")

	# Control groups: Ctrl+key assigns, key recalls
	if event is InputEventKey and event.pressed and not event.echo:
		for group_id in range(1, 10):
			var action_name: String = "group_%d" % group_id
			if event.is_action_pressed(action_name):
				if event.ctrl_pressed:
					_assign_control_group(group_id)
				else:
					_recall_control_group(group_id)
				break


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		is_dragging = true
		drag_start_screen = event.position
		drag_current_screen = event.position
		drag_shift_held = event.shift_pressed

	elif event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if is_dragging:
			var drag_distance := drag_start_screen.distance_to(drag_current_screen)
			if drag_distance > DRAG_THRESHOLD:
				_box_select(drag_shift_held)
			else:
				_single_select(drag_start_screen, drag_shift_held)
			is_dragging = false
			overlay_control.queue_redraw()

	elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if not selected_units.is_empty():
			var world_pos := _screen_to_world(event.position)
			_command_move_formation(world_pos)
			if SwarmManager.swarm_core and SwarmManager.swarm_core.has_method("show_destination"):
				SwarmManager.swarm_core.show_destination(world_pos)


func _box_select(shift_held: bool = false) -> void:
	if not shift_held:
		_deselect_all()

	var start_world := _screen_to_world(drag_start_screen)
	var end_world := _screen_to_world(drag_current_screen)

	var rect := Rect2()
	rect.position = Vector2(min(start_world.x, end_world.x), min(start_world.y, end_world.y))
	rect.size = Vector2(abs(end_world.x - start_world.x), abs(end_world.y - start_world.y))

	for unit in SwarmManager.units:
		if is_instance_valid(unit) and rect.has_point(unit.global_position):
			if unit.has_method("select") and unit not in selected_units:
				unit.select()
				selected_units.append(unit)

	for unit in SwarmManager.reviving_units:
		if is_instance_valid(unit) and rect.has_point(unit.global_position):
			if unit.has_method("select") and unit not in selected_units:
				unit.select()
				selected_units.append(unit)


func _single_select(screen_pos: Vector2, shift_held: bool = false) -> void:
	var world_pos := _screen_to_world(screen_pos)
	var closest_unit: Node2D = null
	var closest_dist: float = 15.0

	for unit in SwarmManager.units:
		if is_instance_valid(unit):
			var dist := world_pos.distance_to(unit.global_position)
			if dist < closest_dist:
				closest_dist = dist
				closest_unit = unit

	for unit in SwarmManager.reviving_units:
		if is_instance_valid(unit):
			var dist := world_pos.distance_to(unit.global_position)
			if dist < closest_dist:
				closest_dist = dist
				closest_unit = unit

	if closest_unit:
		var now := Time.get_ticks_msec() / 1000.0
		if closest_unit == last_click_unit and (now - last_click_time) < DOUBLE_CLICK_THRESHOLD:
			_select_all_of_type(closest_unit)
			last_click_time = 0.0
			last_click_unit = null
			return
		last_click_time = now
		last_click_unit = closest_unit

		if shift_held:
			if closest_unit in selected_units:
				if closest_unit.has_method("deselect"):
					closest_unit.deselect()
				selected_units.erase(closest_unit)
			else:
				if closest_unit.has_method("select"):
					closest_unit.select()
					selected_units.append(closest_unit)
		else:
			_deselect_all()
			if closest_unit.has_method("select"):
				closest_unit.select()
				selected_units.append(closest_unit)
	else:
		last_click_time = 0.0
		last_click_unit = null
		if not shift_held:
			_deselect_all()


func _select_all_of_type(reference_unit: Node2D) -> void:
	_deselect_all()
	var target_type: String = ""
	if reference_unit.has_method("get_unit_type"):
		target_type = reference_unit.get_unit_type()

	var all_units: Array = SwarmManager.units.duplicate()
	all_units.append_array(SwarmManager.reviving_units)

	for unit in all_units:
		if not is_instance_valid(unit):
			continue
		var unit_type: String = ""
		if unit.has_method("get_unit_type"):
			unit_type = unit.get_unit_type()
		if unit_type == target_type and unit.has_method("select"):
			unit.select()
			selected_units.append(unit)


func _select_all_of_unit_type(target_type: String) -> void:
	_deselect_all()
	var all_units: Array = SwarmManager.units.duplicate()
	all_units.append_array(SwarmManager.reviving_units)
	for unit in all_units:
		if not is_instance_valid(unit):
			continue
		var unit_type: String = ""
		if unit.has_method("get_unit_type"):
			unit_type = unit.get_unit_type()
		if unit_type == target_type and unit.has_method("select"):
			unit.select()
			selected_units.append(unit)


func _select_all_units() -> void:
	_deselect_all()
	var all_units: Array = SwarmManager.units.duplicate()
	all_units.append_array(SwarmManager.reviving_units)
	for unit in all_units:
		if is_instance_valid(unit) and unit.has_method("select"):
			unit.select()
			selected_units.append(unit)


func _select_all_other_units() -> void:
	var current := selected_units.duplicate()
	_deselect_all()
	var all_units: Array = SwarmManager.units.duplicate()
	all_units.append_array(SwarmManager.reviving_units)
	for unit in all_units:
		if is_instance_valid(unit) and unit.has_method("select") and unit not in current:
			unit.select()
			selected_units.append(unit)


func _cycle_unit(direction: int) -> void:
	var all_units: Array = SwarmManager.units.duplicate()
	all_units.append_array(SwarmManager.reviving_units)
	# Remove invalid
	var valid: Array[Node2D] = []
	for u in all_units:
		if is_instance_valid(u):
			valid.append(u)
	if valid.is_empty():
		return

	var current_index: int = -1
	if selected_units.size() == 1:
		current_index = valid.find(selected_units[0])

	_deselect_all()
	var next_index: int = 0
	if current_index >= 0:
		next_index = (current_index + direction) % valid.size()
		if next_index < 0:
			next_index += valid.size()

	var unit := valid[next_index]
	if unit.has_method("select"):
		unit.select()
		selected_units.append(unit)


func _handle_key(event: InputEventKey) -> void:
	# Legacy fallback — control groups now handled via InputMap actions in _input()
	pass


func _assign_control_group(group_id: int) -> void:
	control_groups[group_id] = selected_units.duplicate()
	var blueprint: Dictionary = {}
	for unit in selected_units:
		if is_instance_valid(unit) and unit.has_method("get_unit_type"):
			var unit_type: String = unit.get_unit_type()
			blueprint[unit_type] = blueprint.get(unit_type, 0) + 1
	control_group_blueprints[group_id] = blueprint


func _recall_control_group(group_id: int) -> void:
	if group_id not in control_groups:
		return
	_deselect_all()
	var stored: Array = control_groups[group_id]
	var valid_units: Array[Node2D] = []
	for unit in stored:
		if is_instance_valid(unit) and unit.has_method("select"):
			valid_units.append(unit)

	if valid_units.is_empty() and group_id in control_group_blueprints:
		var blueprint: Dictionary = control_group_blueprints[group_id]
		var remaining_counts: Dictionary = blueprint.duplicate()
		for unit in SwarmManager.units:
			if not is_instance_valid(unit) or not unit.has_method("get_unit_type"):
				continue
			var unit_type: String = unit.get_unit_type()
			if unit_type in remaining_counts and remaining_counts[unit_type] > 0:
				valid_units.append(unit)
				remaining_counts[unit_type] -= 1

	for unit in valid_units:
		if unit.has_method("select"):
			unit.select()
			selected_units.append(unit)
	control_groups[group_id] = valid_units


func clear_selection() -> void:
	_deselect_all()


func _deselect_all() -> void:
	for unit in selected_units:
		if is_instance_valid(unit) and unit.has_method("deselect"):
			unit.deselect()
	selected_units.clear()


func _command_move_formation(center: Vector2) -> void:
	var valid_units: Array[Node2D] = []
	for u in selected_units:
		if is_instance_valid(u):
			valid_units.append(u)
	selected_units = valid_units

	var count := selected_units.size()
	if count == 0:
		return

	if count == 1:
		if selected_units[0].has_method("command_move"):
			selected_units[0].command_move(center)
		return

	var positions := _calculate_formation_positions(center, count)
	for i in count:
		if selected_units[i].has_method("command_move"):
			selected_units[i].command_move(positions[i])


func _calculate_formation_positions(center: Vector2, count: int) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	var ring_capacity: int = 6

	positions.append(center)
	var units_placed: int = 1

	var ring_index: int = 0
	while units_placed < count:
		ring_index += 1
		var radius: float = FORMATION_SPACING * ring_index
		var slots: int = ring_capacity * ring_index
		var angle_step: float = TAU / slots

		for slot in slots:
			if units_placed >= count:
				break
			var angle: float = angle_step * slot
			var pos := center + Vector2(cos(angle), sin(angle)) * radius
			positions.append(pos)
			units_placed += 1

	return positions


func _screen_to_world(screen_pos: Vector2) -> Vector2:
	var viewport := get_viewport()
	if not viewport:
		return screen_pos
	var canvas_transform := viewport.get_canvas_transform()
	return canvas_transform.affine_inverse() * screen_pos


class SelectionBoxOverlay extends Control:
	const BOX_FILL_COLOR: Color = Color(1.0, 0.843, 0.0, 0.3)
	const BOX_BORDER_COLOR: Color = Color(1.0, 0.843, 0.0, 0.8)

	var selection_manager: Node = null

	func _ready() -> void:
		set_anchors_preset(PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if not selection_manager or not selection_manager.is_dragging:
			return
		var start: Vector2 = selection_manager.drag_start_screen
		var end: Vector2 = selection_manager.drag_current_screen
		var rect := Rect2(start, end - start).abs()
		draw_rect(rect, BOX_FILL_COLOR)
		draw_rect(rect, BOX_BORDER_COLOR, false, 2.0)
