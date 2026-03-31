extends "res://scenes/dungeon/RoomMiniBoss.gd"

## Warlord — DireCaptain + grunt/hound mix, single damage zone
## The classic brute-force mini boss fight.

var DamageZoneScene := preload("res://scenes/terrain/DamageZone.tscn")
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

	var use_hound := randf() < 0.5
	var hound_side := randi() % 2

	if use_hound and hound_side == 0:
		var hound := DireHoundScene.instantiate()
		hound.global_position = enemy_spawn_left.global_position
		entities.add_child(hound)
	else:
		var grunt_left := DireGruntScene.instantiate()
		grunt_left.global_position = enemy_spawn_left.global_position
		entities.add_child(grunt_left)

	if use_hound and hound_side == 1:
		var hound := DireHoundScene.instantiate()
		hound.global_position = enemy_spawn_right.global_position
		entities.add_child(hound)
	else:
		var grunt_right := DireGruntScene.instantiate()
		grunt_right.global_position = enemy_spawn_right.global_position
		entities.add_child(grunt_right)

	RunManager.set_room_enemy_count(3)
	captain_instance.captain_defeated.connect(_on_captain_defeated)
	_create_ambient_particles_colored(Color(0.545, 0.0, 0.0, 0.2))


func _spawn_terrain_zones() -> void:
	var damage_zone := DamageZoneScene.instantiate()
	damage_zone.global_position = boss_spawn.global_position + Vector2(0, 80)
	add_child(damage_zone)
