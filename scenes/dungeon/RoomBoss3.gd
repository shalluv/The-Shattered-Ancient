extends "res://scenes/dungeon/RoomBoss.gd"

## Gauntlet — Tall walls create a central corridor, slow zones on flanks.

var TallWallScene := preload("res://scenes/terrain/TallWall.tscn")
var SlowZoneScene := preload("res://scenes/terrain/SlowZone.tscn")

@onready var player_spawn: Marker2D = $PlayerSpawnPoint
@onready var boss_spawn: Marker2D = $BossSpawnPoint


func _get_spawn_position() -> Vector2:
	return player_spawn.global_position


func _spawn_enemies() -> void:
	boss_instance = DireAncientScene.instantiate()
	boss_instance.global_position = boss_spawn.global_position
	entities.add_child(boss_instance)
	RunManager.set_room_enemy_count(1)

	boss_instance.boss_defeated.connect(_on_boss_defeated)
	_boss_entry_sequence()


func _spawn_terrain_zones() -> void:
	# Two tall walls creating a corridor down the center
	var wall_left := TallWallScene.instantiate()
	wall_left.wall_size = Vector2(30, 400)
	wall_left.global_position = Vector2(450, 500)
	add_child(wall_left)

	var wall_right := TallWallScene.instantiate()
	wall_right.wall_size = Vector2(30, 400)
	wall_right.global_position = Vector2(1150, 500)
	add_child(wall_right)

	# Slow zones behind the walls
	var slow_left := SlowZoneScene.instantiate()
	slow_left.zone_size = Vector2(200, 300)
	slow_left.global_position = Vector2(250, 500)
	add_child(slow_left)

	var slow_right := SlowZoneScene.instantiate()
	slow_right.zone_size = Vector2(200, 300)
	slow_right.global_position = Vector2(1350, 500)
	add_child(slow_right)
