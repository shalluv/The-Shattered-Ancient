extends "res://scenes/dungeon/RoomBoss.gd"

## Open Arena — Classic boss fight with lava hazards, no cover.

var DamageZoneScene := preload("res://scenes/terrain/DamageZone.tscn")

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
	# Two damage zones flanking the arena
	var lava_left := DamageZoneScene.instantiate()
	lava_left.zone_size = Vector2(150, 150)
	lava_left.global_position = Vector2(350, 500)
	add_child(lava_left)

	var lava_right := DamageZoneScene.instantiate()
	lava_right.zone_size = Vector2(150, 150)
	lava_right.global_position = Vector2(1250, 500)
	add_child(lava_right)
