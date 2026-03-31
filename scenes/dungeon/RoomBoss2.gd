extends "res://scenes/dungeon/RoomBoss.gd"

## Pillared Hall — 4 short wall pillars provide cover from Dire Gaze.

var ShortWallScene := preload("res://scenes/terrain/ShortWall.tscn")

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
	# 4 pillars in a diamond pattern around the arena center
	var pillar_positions: Array[Vector2] = [
		Vector2(550, 400),
		Vector2(1050, 400),
		Vector2(550, 650),
		Vector2(1050, 650),
	]
	for pos in pillar_positions:
		var pillar := ShortWallScene.instantiate()
		pillar.wall_size = Vector2(60, 60)
		pillar.global_position = pos
		add_child(pillar)
