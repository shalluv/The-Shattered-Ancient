extends Node2D

## A placeable wall obstacle with collision and pathfinding integration.
## Use in rooms like DamageZone/SlowZone — instantiate, set position, add_child.
##
## blocks_line_of_sight = true  (TallWall): fully solid, blocks movement + LOS + shooting
## blocks_line_of_sight = false (ShortWall): blocks movement, but archers can shoot over it

@export var wall_size: Vector2 = Vector2(120, 30)
@export var wall_color: Color = Color("#1a2e1a")
@export var blocks_line_of_sight: bool = true

const WALL_PATH_WEIGHT: float = 20.0

var _wall_body: StaticBody2D = null


func _ready() -> void:
	_create_visual()
	_create_collision()
	_register_obstacle()


func _create_visual() -> void:
	var visual := ColorRect.new()
	visual.size = wall_size
	visual.position = -wall_size / 2.0
	visual.color = wall_color
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(visual)


func _create_collision() -> void:
	_wall_body = StaticBody2D.new()
	_wall_body.collision_layer = 8  # walls layer
	_wall_body.collision_mask = 0

	var shape := RectangleShape2D.new()
	shape.size = wall_size

	var col := CollisionShape2D.new()
	col.shape = shape
	_wall_body.add_child(col)
	add_child(_wall_body)


func _register_obstacle() -> void:
	var rect := Rect2(global_position - wall_size / 2.0, wall_size)
	if blocks_line_of_sight:
		# Tall wall: fully solid — blocks pathing and line-of-sight
		Pathfinder.add_obstacles([rect])
	else:
		# Short wall: heavy weight so units path around, but LOS passes through
		Pathfinder.add_weighted_zone(rect, WALL_PATH_WEIGHT)

