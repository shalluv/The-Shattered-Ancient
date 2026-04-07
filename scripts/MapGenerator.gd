class_name MapGenerator
extends RefCounted

const TOTAL_ROWS: int = 10
const FUNNEL_ROWS: Array[int] = [0, 3, 7, 9]

const ROOM_POOLS: Dictionary = {
	1: [["combat_small", 60], ["village", 40]],
	2: [["combat_small", 40], ["village", 30], ["hero_room", 30]],
	4: [["shop", 40], ["combat_medium", 30], ["hero_room", 30]],
	5: [["combat_medium", 40], ["shop", 30], ["village", 30]],
	6: [["combat_medium", 40], ["village", 30], ["hero_room", 30]],
	8: [["combat_medium", 50], ["hero_room", 50]],
}

var hero_ids_used: Array[String] = []


func generate() -> MapData:
	for _attempt in 10:
		var map := _try_generate()
		if map and _validate(map):
			_debug_print(map)
			return map
	push_warning("MapGenerator: failed after 10 attempts, returning last attempt")
	return _try_generate()


func _try_generate() -> MapData:
	var map := MapData.new()
	var next_index: int = 0
	hero_ids_used = []

	var start := MapNodeData.new()
	start.node_index = next_index
	start.row = 0
	start.col = 1
	start.room_type = "start"
	start.is_visited = true
	start.is_current = true
	map.nodes.append(start)
	next_index += 1

	var prev_cols: Array[int] = [1]

	for row in range(1, TOTAL_ROWS):
		if row == 3 or row == 7:
			var node := MapNodeData.new()
			node.node_index = next_index
			node.row = row
			node.col = 1
			node.room_type = "mini_boss"
			node.offset = Vector2(randf_range(-5, 5), randf_range(-8, 8))
			map.nodes.append(node)
			next_index += 1
			prev_cols = [1]
			continue

		if row == 9:
			var node := MapNodeData.new()
			node.node_index = next_index
			node.row = row
			node.col = 1
			node.room_type = "boss"
			node.offset = Vector2(randf_range(-3, 3), randf_range(-5, 5))
			map.nodes.append(node)
			next_index += 1
			prev_cols = [1]
			continue

		var cols := _determine_columns(prev_cols, row)
		for col in cols:
			var node := MapNodeData.new()
			node.node_index = next_index
			node.row = row
			node.col = col
			var exclude: Array[String] = []
			if not _hero_available():
				exclude.append("hero_room")
			node.room_type = _pick_room_type(row, exclude)
			node.offset = Vector2(randf_range(-6, 6), randf_range(-10, 10))
			if node.room_type == "hero_room":
				node.room_data = _assign_hero()
			if node.room_type == "shop" and not MetaProgress.has_upgrade("unlock_shop"):
				node.room_type = "combat_medium"
			map.nodes.append(node)
			next_index += 1
		prev_cols = cols

	_wire_connections(map)
	map.player_node_index = 0
	map.visited_nodes = [0]
	return map


func _determine_columns(prev_cols: Array[int], _row: int) -> Array[int]:
	var cols: Array[int] = prev_cols.duplicate()

	if cols.size() == 1 and cols[0] == 1:
		cols = [0, 1, 2]
		return cols

	var roll := randf()
	if roll < 0.2 and cols.size() > 2:
		var merge_idx := randi() % (cols.size() - 1)
		cols.remove_at(merge_idx)
	elif roll > 0.8 and cols.size() < 3:
		var missing: Array[int] = []
		for c in [0, 1, 2]:
			if c not in cols:
				missing.append(c)
		if not missing.is_empty():
			cols.append(missing[randi() % missing.size()])

	if cols.size() < 2:
		var missing: Array[int] = []
		for c in [0, 1, 2]:
			if c not in cols:
				missing.append(c)
		if not missing.is_empty():
			cols.append(missing[randi() % missing.size()])

	cols.sort()
	return cols


func _hero_available() -> bool:
	var available := HeroData.get_available_heroes()
	for hero in available:
		if hero["id"] not in hero_ids_used:
			return true
	return false


func _pick_room_type(row: int, exclude_types: Array[String] = []) -> String:
	if not ROOM_POOLS.has(row):
		return "combat_small"
	var pool: Array = ROOM_POOLS[row]
	var total_weight: int = 0
	for entry in pool:
		if entry[0] not in exclude_types:
			total_weight += entry[1]
	if total_weight == 0:
		return "combat_small"
	var roll: int = randi() % total_weight
	var cumulative: int = 0
	for entry in pool:
		if entry[0] not in exclude_types:
			cumulative += entry[1]
			if roll < cumulative:
				return entry[0]
	return pool[0][0]


func _assign_hero() -> Dictionary:
	var available := HeroData.get_available_heroes()
	for hero in available:
		if hero["id"] not in hero_ids_used:
			hero_ids_used.append(hero["id"])
			return {"hero_id": hero["id"]}
	return {}


func _wire_connections(map: MapData) -> void:
	for row in range(0, TOTAL_ROWS - 1):
		var current_nodes := map.get_nodes_in_row(row)
		var next_nodes := map.get_nodes_in_row(row + 1)
		if current_nodes.is_empty() or next_nodes.is_empty():
			continue

		var is_current_funnel: bool = (row in FUNNEL_ROWS)
		var is_next_funnel: bool = ((row + 1) in FUNNEL_ROWS)

		if is_current_funnel or is_next_funnel:
			for cn in current_nodes:
				if not map.connections.has(cn.node_index):
					map.connections[cn.node_index] = []
				for nn in next_nodes:
					if nn.node_index not in map.connections[cn.node_index]:
						map.connections[cn.node_index].append(nn.node_index)
			continue

		for cn in current_nodes:
			if not map.connections.has(cn.node_index):
				map.connections[cn.node_index] = []
			var valid_targets: Array = []
			for nn in next_nodes:
				if abs(nn.col - cn.col) <= 1:
					valid_targets.append(nn)
			if valid_targets.is_empty():
				var closest: MapNodeData = next_nodes[0]
				for nn in next_nodes:
					if abs(nn.col - cn.col) < abs(closest.col - cn.col):
						closest = nn
				valid_targets.append(closest)

			valid_targets.shuffle()
			var connect_count: int = 1
			if valid_targets.size() > 1 and randf() < 0.25:
				connect_count = 2
			for i in mini(connect_count, valid_targets.size()):
				var target: MapNodeData = valid_targets[i]
				if target.node_index not in map.connections[cn.node_index]:
					map.connections[cn.node_index].append(target.node_index)

		for nn in next_nodes:
			var has_incoming: bool = false
			for cn in current_nodes:
				if map.connections.has(cn.node_index) and nn.node_index in map.connections[cn.node_index]:
					has_incoming = true
					break
			if not has_incoming:
				var closest: MapNodeData = current_nodes[0]
				for cn in current_nodes:
					if abs(cn.col - nn.col) < abs(closest.col - nn.col):
						closest = cn
				if not map.connections.has(closest.node_index):
					map.connections[closest.node_index] = []
				map.connections[closest.node_index].append(nn.node_index)


func _validate(map: MapData) -> bool:
	var start_node := map.get_nodes_in_row(0)
	if start_node.is_empty():
		return false
	var boss_node := map.get_nodes_in_row(9)
	if boss_node.is_empty():
		return false

	var visited: Dictionary = {}
	var queue: Array[int] = [start_node[0].node_index]
	visited[start_node[0].node_index] = true
	while not queue.is_empty():
		var current: int = queue.pop_front()
		if map.connections.has(current):
			for next_idx in map.connections[current]:
				if not visited.has(next_idx):
					visited[next_idx] = true
					queue.append(next_idx)

	for node in map.nodes:
		if not visited.has(node.node_index):
			return false
	return true


func _debug_print(map: MapData) -> void:
	print("=== RUN MAP ===")
	for row in range(TOTAL_ROWS - 1, -1, -1):
		var row_nodes := map.get_nodes_in_row(row)
		var line: String = "Row %d: " % row
		for node in row_nodes:
			var conns: String = ""
			if map.connections.has(node.node_index):
				var arr: Array = []
				for c in map.connections[node.node_index]:
					arr.append(str(c))
				conns = "→[" + ",".join(arr) + "]"
			line += "[%d|c%d|%s%s] " % [node.node_index, node.col, node.room_type, conns]
		print(line)
	print("===============")
