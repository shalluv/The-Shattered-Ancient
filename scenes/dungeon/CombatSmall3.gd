extends "res://scenes/dungeon/RoomBase.gd"

const SPAWN_STAGGER_DELAY: float = 0.5
const WALL_COLOR: Color = Color("#1a2e1a")
const ARM_WIDTH: float = 200.0
const CENTER_SIZE: float = 200.0

var SlowZoneScene := preload("res://scenes/terrain/SlowZone.tscn")

@onready var player_spawn: Marker2D = $PlayerSpawnPoint
@onready var enemy_spawns_wave1: Array[Marker2D] = [
	$EnemySpawnPoint1, $EnemySpawnPoint2, $EnemySpawnPoint3
]
@onready var enemy_spawns_wave2: Array[Marker2D] = [
	$EnemySpawnPoint4, $EnemySpawnPoint5, $EnemySpawnPoint6
]

var wave_1_cleared: bool = false
var wave_difficulty: Dictionary = {}


func _ready() -> void:
	super._ready()
	_build_crossroads()
	_place_slow_zones()
	RunManager.enemies_remaining_changed.connect(_on_enemies_changed)


func _exit_tree() -> void:
	super._exit_tree()
	if RunManager.enemies_remaining_changed.is_connected(_on_enemies_changed):
		RunManager.enemies_remaining_changed.disconnect(_on_enemies_changed)


func _get_spawn_position() -> Vector2:
	return player_spawn.global_position


func _spawn_enemies() -> void:
	wave_difficulty = RunManager.get_room_difficulty()
	var hp: int = wave_difficulty.get("enemy_hp", 1)
	var dmg: int = wave_difficulty.get("enemy_damage", 1)
	RunManager.set_room_enemy_count(3)
	for i in 3:
		var enemy := DireGruntScene.instantiate()
		var spawn_pos: Vector2 = enemy_spawns_wave1[i].global_position
		enemy.global_position = spawn_pos
		enemy.enemy_hp = hp
		enemy.damage = dmg
		entities.add_child(enemy)
		_play_spawn_particles(spawn_pos)
		if i < 2:
			await get_tree().create_timer(SPAWN_STAGGER_DELAY).timeout


func _on_enemies_changed(count: int) -> void:
	if count <= 0 and not wave_1_cleared:
		wave_1_cleared = true
		RunManager.enemies_remaining_changed.disconnect(_on_enemies_changed)
		call_deferred("_spawn_wave_2")


func _spawn_wave_2() -> void:
	var hp: int = wave_difficulty.get("enemy_hp", 1)
	var dmg: int = wave_difficulty.get("enemy_damage", 1)
	RunManager.add_enemies(3)
	for i in 3:
		var enemy := DireGruntScene.instantiate()
		var spawn_pos: Vector2 = enemy_spawns_wave2[i].global_position
		enemy.global_position = spawn_pos
		enemy.enemy_hp = hp
		enemy.damage = dmg
		entities.add_child(enemy)
		_play_spawn_particles(spawn_pos)
		if i < 2:
			await get_tree().create_timer(SPAWN_STAGGER_DELAY).timeout


func _build_crossroads() -> void:
	var walls_node := $Walls
	var cx := room_size.x / 2.0
	var cy := room_size.y / 2.0
	var half_arm := ARM_WIDTH / 2.0


	var corners: Array[Dictionary] = [
		{"pos": Vector2((cx - half_arm) / 2.0, (cy - half_arm) / 2.0), "size": Vector2(cx - half_arm, cy - half_arm)},
		{"pos": Vector2(cx + half_arm + (room_size.x - cx - half_arm) / 2.0, (cy - half_arm) / 2.0), "size": Vector2(room_size.x - cx - half_arm, cy - half_arm)},
		{"pos": Vector2((cx - half_arm) / 2.0, cy + half_arm + (room_size.y - cy - half_arm) / 2.0), "size": Vector2(cx - half_arm, room_size.y - cy - half_arm)},
		{"pos": Vector2(cx + half_arm + (room_size.x - cx - half_arm) / 2.0, cy + half_arm + (room_size.y - cy - half_arm) / 2.0), "size": Vector2(room_size.x - cx - half_arm, room_size.y - cy - half_arm)},
	]

	var obstacle_rects: Array[Rect2] = []
	for corner in corners:
		var pos: Vector2 = corner["pos"]
		var csize: Vector2 = corner["size"]

		# TODO: Replace with crossroads wall art asset
		var visual := ColorRect.new()
		visual.position = pos - csize / 2.0
		visual.size = csize
		visual.color = WALL_COLOR
		visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(visual)

		_add_wall_body(walls_node, pos, csize)
		obstacle_rects.append(Rect2(pos - csize / 2.0, csize))

	Pathfinder.add_obstacles(obstacle_rects)


func _place_slow_zones() -> void:
	var cx := room_size.x / 2.0
	var cy := room_size.y / 2.0

	var left_slow := SlowZoneScene.instantiate()
	left_slow.zone_size = Vector2(100, 80)
	left_slow.global_position = Vector2(cx - 200, cy)
	add_child(left_slow)

	var right_slow := SlowZoneScene.instantiate()
	right_slow.zone_size = Vector2(100, 80)
	right_slow.global_position = Vector2(cx + 200, cy)
	add_child(right_slow)
