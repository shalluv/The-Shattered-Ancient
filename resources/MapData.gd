class_name MapData
extends Resource

var nodes: Array = []
var connections: Dictionary = {}
var player_node_index: int = 0
var visited_nodes: Array[int] = [0]


func get_node_by_index(idx: int) -> MapNodeData:
	for node in nodes:
		if node.node_index == idx:
			return node
	return null


func get_nodes_in_row(row: int) -> Array:
	var result: Array = []
	for node in nodes:
		if node.row == row:
			result.append(node)
	return result


func get_reachable_nodes() -> Array[int]:
	var result: Array[int] = []
	if not connections.has(player_node_index):
		return result
	for target_idx in connections[player_node_index]:
		result.append(target_idx)
	return result


func mark_visited(idx: int) -> void:
	if idx not in visited_nodes:
		visited_nodes.append(idx)
	var node := get_node_by_index(idx)
	if node:
		node.is_visited = true


func set_player_position(idx: int) -> void:
	var old_node := get_node_by_index(player_node_index)
	if old_node:
		old_node.is_current = false
	player_node_index = idx
	var new_node := get_node_by_index(idx)
	if new_node:
		new_node.is_current = true
