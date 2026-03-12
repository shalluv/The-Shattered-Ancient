extends Node2D

signal group_defeated
signal attack_reflected(attacker: Node)

const ANCHOR_SPEED: float = 45.0
const FORMATION_SPACING: float = 32.0
const AGGRO_RANGE: float = 120.0
const PATH_RECALC_INTERVAL: float = 0.4
const PATH_RECALC_TARGET_DRIFT: float = 30.0
const WAYPOINT_THRESHOLD: float = 12.0

var SpearwallUnitScene := preload("res://scenes/entities/enemies/SpearwallUnit.tscn")

var anchor_position: Vector2 = Vector2.ZERO
var spearwall_units: Array[Node2D] = []
var formation_angle: float = 0.0
var current_path: PackedVector2Array = PackedVector2Array()
var path_index: int = 0
var path_recalc_timer: float = 0.0
var last_pathed_target: Vector2 = Vector2.ZERO


func _ready() -> void:
	anchor_position = global_position
	path_recalc_timer = randf() * PATH_RECALC_INTERVAL

	var offsets: Array[Vector2] = [
		Vector2(-FORMATION_SPACING, 0),
		Vector2(0, 0),
		Vector2(FORMATION_SPACING, 0)
	]

	for i in 3:
		var unit := SpearwallUnitScene.instantiate() as CharacterBody2D
		unit.group = self
		unit.formation_offset = offsets[i]
		unit.global_position = anchor_position + offsets[i]
		unit.target_position = unit.global_position
		get_parent().call_deferred("add_child", unit)
		spearwall_units.append(unit)


func _physics_process(delta: float) -> void:
	var living: Array[Node2D] = []
	for unit in spearwall_units:
		if is_instance_valid(unit) and not unit.is_dying:
			living.append(unit)
	if living.is_empty():
		return

	var target := SwarmManager.get_swarm_center()
	var dist_to_target := anchor_position.distance_to(target)

	if dist_to_target > AGGRO_RANGE:
		formation_angle = anchor_position.direction_to(target).angle()
		_update_unit_positions(living)
		return

	path_recalc_timer -= delta
	var target_drift := target.distance_to(last_pathed_target)
	if current_path.is_empty() or path_recalc_timer <= 0.0 or target_drift > PATH_RECALC_TARGET_DRIFT:
		current_path = Pathfinder.find_path(anchor_position, target)
		path_index = 0
		_advance_path_index()
		last_pathed_target = target
		path_recalc_timer = PATH_RECALC_INTERVAL

	if not _follow_path(delta):
		var dir := anchor_position.direction_to(target)
		anchor_position += dir * ANCHOR_SPEED * delta

	formation_angle = anchor_position.direction_to(target).angle()
	_update_unit_positions(living)


func _follow_path(delta: float) -> bool:
	if current_path.is_empty() or path_index >= current_path.size():
		return false
	var waypoint := current_path[path_index]
	var dist := anchor_position.distance_to(waypoint)
	if dist <= WAYPOINT_THRESHOLD:
		path_index += 1
		if path_index >= current_path.size():
			return false
		waypoint = current_path[path_index]
	var dir := anchor_position.direction_to(waypoint)
	anchor_position += dir * ANCHOR_SPEED * delta
	return true


func _advance_path_index() -> void:
	while path_index < current_path.size() - 1:
		var to_waypoint := current_path[path_index] - anchor_position
		var to_next := current_path[path_index + 1] - anchor_position
		if to_next.length() < to_waypoint.length():
			path_index += 1
		else:
			break


func _update_unit_positions(living: Array[Node2D]) -> void:
	var facing := Vector2.from_angle(formation_angle)
	var perpendicular := facing.rotated(PI / 2.0)
	for unit in living:
		if not unit.is_attached:
			continue
		var rotated_offset: Vector2 = perpendicular * unit.formation_offset.x + facing * unit.formation_offset.y
		unit.target_position = anchor_position + rotated_offset
		unit.facing_direction = facing


func on_unit_died(unit: Node2D) -> void:
	spearwall_units.erase(unit)
	var living: Array[Node2D] = []
	for u in spearwall_units:
		if is_instance_valid(u) and not u.is_dying:
			living.append(u)

	if living.size() <= 1:
		for survivor in living:
			survivor.detach()
		group_defeated.emit()
		queue_free()


func get_formation_facing() -> Vector2:
	return Vector2.from_angle(formation_angle)
