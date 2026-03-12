extends Node

const CELL_SIZE: int = 16
const SHORT_DISTANCE_THRESHOLD: float = 8.0
const MAX_SPIRAL_SEARCH: int = 3
const DAMAGE_ZONE_WEIGHT: float = 8.0
const LOS_PADDING: int = 1

var astar: AStarGrid2D = AStarGrid2D.new()
var grid_size: Vector2i = Vector2i.ZERO
var _room_size: Vector2 = Vector2.ZERO
var _door_cells: Array[Vector2i] = []


func setup_grid(p_room_size: Vector2, wall_rects: Array[Rect2], door_rects: Array[Rect2]) -> void:
	_room_size = p_room_size
	grid_size = Vector2i(ceili(p_room_size.x / CELL_SIZE), ceili(p_room_size.y / CELL_SIZE))

	astar = AStarGrid2D.new()
	astar.region = Rect2i(0, 0, grid_size.x, grid_size.y)
	astar.cell_size = Vector2(CELL_SIZE, CELL_SIZE)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_EUCLIDEAN
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_EUCLIDEAN
	astar.update()

	for rect in wall_rects:
		_mark_rect_solid(rect)

	_door_cells.clear()
	for rect in door_rects:
		var cells := _get_cells_in_rect(rect)
		for cell in cells:
			if _is_valid_cell(cell):
				astar.set_point_solid(cell, true)
				_door_cells.append(cell)


func add_obstacles(rects: Array[Rect2]) -> void:
	for rect in rects:
		_mark_rect_solid(rect)


func add_weighted_zone(rect: Rect2, weight: float) -> void:
	var cells := _get_cells_in_rect(rect)
	for cell in cells:
		if _is_valid_cell(cell) and not astar.is_point_solid(cell):
			astar.set_point_weight_scale(cell, weight)


func remove_weighted_zone(rect: Rect2) -> void:
	var cells := _get_cells_in_rect(rect)
	for cell in cells:
		if _is_valid_cell(cell) and not astar.is_point_solid(cell):
			astar.set_point_weight_scale(cell, 1.0)


func open_doors() -> void:
	for cell in _door_cells:
		if _is_valid_cell(cell):
			astar.set_point_solid(cell, false)


func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	if from.distance_to(to) < SHORT_DISTANCE_THRESHOLD:
		return PackedVector2Array()

	var from_cell := _world_to_cell(from)
	var to_cell := _world_to_cell(to)

	from_cell = _find_nearest_passable(from_cell)
	to_cell = _find_nearest_passable(to_cell)

	if from_cell == Vector2i(-1, -1) or to_cell == Vector2i(-1, -1):
		return PackedVector2Array()

	var raw_path := astar.get_point_path(from_cell, to_cell)
	if raw_path.is_empty():
		return PackedVector2Array()

	var world_path := PackedVector2Array()
	for point in raw_path:
		world_path.append(point + Vector2(CELL_SIZE / 2.0, CELL_SIZE / 2.0))

	var smoothed := _smooth_path(world_path)
	if smoothed.size() > 1:
		smoothed = smoothed.slice(1)
	return smoothed


func _world_to_cell(world_pos: Vector2) -> Vector2i:
	var cx := clampi(int(world_pos.x / CELL_SIZE), 0, grid_size.x - 1)
	var cy := clampi(int(world_pos.y / CELL_SIZE), 0, grid_size.y - 1)
	return Vector2i(cx, cy)


func _is_valid_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < grid_size.x and cell.y >= 0 and cell.y < grid_size.y


func _find_nearest_passable(cell: Vector2i) -> Vector2i:
	if _is_valid_cell(cell) and not astar.is_point_solid(cell):
		return cell

	for radius in range(1, MAX_SPIRAL_SEARCH + 1):
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				if abs(dx) != radius and abs(dy) != radius:
					continue
				var test := Vector2i(cell.x + dx, cell.y + dy)
				if _is_valid_cell(test) and not astar.is_point_solid(test):
					return test

	return Vector2i(-1, -1)


func _mark_rect_solid(rect: Rect2) -> void:
	var cells := _get_cells_in_rect(rect)
	for cell in cells:
		if _is_valid_cell(cell):
			astar.set_point_solid(cell, true)


func _get_cells_in_rect(rect: Rect2) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var start_x := maxi(int(rect.position.x / CELL_SIZE), 0)
	var start_y := maxi(int(rect.position.y / CELL_SIZE), 0)
	var end_x := mini(ceili(rect.end.x / CELL_SIZE), grid_size.x - 1)
	var end_y := mini(ceili(rect.end.y / CELL_SIZE), grid_size.y - 1)

	for x in range(start_x, end_x + 1):
		for y in range(start_y, end_y + 1):
			cells.append(Vector2i(x, y))
	return cells


func _smooth_path(path: PackedVector2Array) -> PackedVector2Array:
	if path.size() <= 2:
		return path

	var smoothed := PackedVector2Array()
	smoothed.append(path[0])

	var current_index: int = 0
	while current_index < path.size() - 1:
		var farthest := current_index + 1
		for check in range(path.size() - 1, current_index + 1, -1):
			if has_line_of_sight(path[current_index], path[check]):
				farthest = check
				break
		smoothed.append(path[farthest])
		current_index = farthest

	return smoothed


func has_line_of_sight(from: Vector2, to: Vector2) -> bool:
	var from_cell := _world_to_cell(from)
	var to_cell := _world_to_cell(to)

	var points := _bresenham_line(from_cell, to_cell)
	for point in points:
		if _is_valid_cell(point) and astar.is_point_solid(point):
			return false
		for dx in range(-LOS_PADDING, LOS_PADDING + 1):
			for dy in range(-LOS_PADDING, LOS_PADDING + 1):
				if dx == 0 and dy == 0:
					continue
				if abs(dx) + abs(dy) > LOS_PADDING:
					continue
				var neighbor := Vector2i(point.x + dx, point.y + dy)
				if _is_valid_cell(neighbor) and astar.is_point_solid(neighbor):
					return false
	return true


func _bresenham_line(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var points: Array[Vector2i] = []
	var dx := absi(to.x - from.x)
	var dy := absi(to.y - from.y)
	var sx := 1 if from.x < to.x else -1
	var sy := 1 if from.y < to.y else -1
	var err := dx - dy
	var x := from.x
	var y := from.y

	while true:
		points.append(Vector2i(x, y))
		if x == to.x and y == to.y:
			break
		var e2 := 2 * err
		if e2 > -dy:
			err -= dy
			x += sx
		if e2 < dx:
			err += dx
			y += sy

	return points
