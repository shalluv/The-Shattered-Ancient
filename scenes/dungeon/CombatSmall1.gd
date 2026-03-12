extends "res://scenes/dungeon/RoomBase.gd"

const SPAWN_STAGGER_DELAY: float = 0.5
const WALL_COLOR: Color = Color("#1a2e1a")
const CHOKEPOINT_Y: float = 270.0
const CHOKEPOINT_HEIGHT: float = 80.0
const GAP_WIDTH: float = 80.0

var SlowZoneScene := preload("res://scenes/terrain/SlowZone.tscn")

@onready var player_spawn: Marker2D = $PlayerSpawnPoint
@onready var enemy_spawns: Array[Marker2D] = [
	$EnemySpawnPoint1, $EnemySpawnPoint2, $EnemySpawnPoint3,
	$EnemySpawnPoint4, $EnemySpawnPoint5
]


func _ready() -> void:
	super._ready()
	_build_chokepoint()
	_place_slow_zone()


func _get_spawn_position() -> Vector2:
	return player_spawn.global_position


func _spawn_enemies() -> void:
	var difficulty: Dictionary = RunManager.get_room_difficulty()
	var count: int = difficulty.get("enemy_count", 5)
	var hp: int = difficulty.get("enemy_hp", 1)
	var dmg: int = difficulty.get("enemy_damage", 1)
	RunManager.set_room_enemy_count(count)
	for i in count:
		var enemy := DireGruntScene.instantiate()
		var spawn_pos: Vector2 = enemy_spawns[i % enemy_spawns.size()].global_position
		enemy.global_position = spawn_pos
		enemy.enemy_hp = hp
		enemy.damage = dmg
		entities.add_child(enemy)
		_play_spawn_particles(spawn_pos)
		if i < count - 1:
			await get_tree().create_timer(SPAWN_STAGGER_DELAY).timeout


func _build_chokepoint() -> void:
	var walls_node := $Walls
	var center_x := room_size.x / 2.0
	var gap_half := GAP_WIDTH / 2.0

	var left_width := center_x - gap_half
	# TODO: Replace with chokepoint wall art asset
	var left_visual := ColorRect.new()
	left_visual.position = Vector2(0, CHOKEPOINT_Y)
	left_visual.size = Vector2(left_width, CHOKEPOINT_HEIGHT)
	left_visual.color = WALL_COLOR
	left_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(left_visual)
	_add_wall_body(walls_node, Vector2(left_width / 2.0, CHOKEPOINT_Y + CHOKEPOINT_HEIGHT / 2.0), Vector2(left_width, CHOKEPOINT_HEIGHT))

	var right_x := center_x + gap_half
	var right_width := room_size.x - right_x
	# TODO: Replace with chokepoint wall art asset
	var right_visual := ColorRect.new()
	right_visual.position = Vector2(right_x, CHOKEPOINT_Y)
	right_visual.size = Vector2(right_width, CHOKEPOINT_HEIGHT)
	right_visual.color = WALL_COLOR
	right_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(right_visual)
	_add_wall_body(walls_node, Vector2(right_x + right_width / 2.0, CHOKEPOINT_Y + CHOKEPOINT_HEIGHT / 2.0), Vector2(right_width, CHOKEPOINT_HEIGHT))

	var obstacle_rects: Array[Rect2] = [
		Rect2(Vector2(0, CHOKEPOINT_Y), Vector2(left_width, CHOKEPOINT_HEIGHT)),
		Rect2(Vector2(right_x, CHOKEPOINT_Y), Vector2(right_width, CHOKEPOINT_HEIGHT)),
	]
	Pathfinder.add_obstacles(obstacle_rects)


func _place_slow_zone() -> void:
	var slow_zone := SlowZoneScene.instantiate()
	slow_zone.zone_size = Vector2(GAP_WIDTH + 20, CHOKEPOINT_HEIGHT)
	slow_zone.global_position = Vector2(room_size.x / 2.0, CHOKEPOINT_Y + CHOKEPOINT_HEIGHT / 2.0)
	add_child(slow_zone)
