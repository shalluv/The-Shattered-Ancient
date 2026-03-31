extends "res://scenes/dungeon/RoomMiniBoss.gd"

## Ambush — DireCaptain + 2 DireHounds, slow zones on flanks
## Fast enemies rush the player while flanks are slowed.

var SlowZoneScene := preload("res://scenes/terrain/SlowZone.tscn")
var DireHoundScene := preload("res://scenes/entities/enemies/DireHound.tscn")

@onready var player_spawn: Marker2D = $PlayerSpawnPoint
@onready var boss_spawn: Marker2D = $BossSpawnPoint
@onready var enemy_spawn_left: Marker2D = $EnemySpawnLeft
@onready var enemy_spawn_right: Marker2D = $EnemySpawnRight


func _get_spawn_position() -> Vector2:
	return player_spawn.global_position


func _spawn_enemies() -> void:
	captain_instance = DireCaptainScene.instantiate()
	captain_instance.global_position = boss_spawn.global_position
	entities.add_child(captain_instance)

	var hound_left := DireHoundScene.instantiate()
	hound_left.global_position = enemy_spawn_left.global_position
	entities.add_child(hound_left)

	var hound_right := DireHoundScene.instantiate()
	hound_right.global_position = enemy_spawn_right.global_position
	entities.add_child(hound_right)

	RunManager.set_room_enemy_count(3)
	captain_instance.captain_defeated.connect(_on_captain_defeated)
	_create_ambient_particles_colored(Color(0.0, 0.4, 0.545, 0.2))


func _spawn_terrain_zones() -> void:
	var slow_left := SlowZoneScene.instantiate()
	slow_left.global_position = Vector2(250, 400)
	add_child(slow_left)

	var slow_right := SlowZoneScene.instantiate()
	slow_right.global_position = Vector2(774, 400)
	add_child(slow_right)
